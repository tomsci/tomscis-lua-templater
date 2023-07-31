
example2 = [[
<ul>
{% for a in ipairs(bar.cheese()) do writef("<li>%s</li>\n", a) end %}
</ul>
]]

bar = {
    cheese = function() return { 1, 2, 3, 4 } end
}

example3 = [[
{% for _, post in ipairs(site.allposts) do %}
    {% for _, paragraph in ipairs(post) do %}
        <li> {{paragraph}} </li>
    {% end %}
{% end %}
]]

example4 = [[
{%
for post in site.posts() do
    for _, paragraph in ipairs(post) do %}
        <li> {{paragraph}} </li>
    {% end %}
{% end %}
]]

example5 = [[
1. Some text.
2.
3.
4.
5.{% include "header.txt" %}
6. Some more text. {%warning("Should be line 6")%}
]]

example6 = [[

{% for post in site.posts() do %}
Unterminated code block...
]]

function makeArrayIterator(array)
    local function iterator(state)
        state.index = state.index + 1
        return state.array[state.index]
    end
    local state = { array = array, index = 0 }
    return iterator, state
end

function countNewlines(text)
    -- Is there a better way to do this?
    local result = 0
    for _ in text:gmatch("\n") do
        result = result + 1
    end
    return result
end


if readFile == nil then
    function readFile(path)
        local f<close>, err = io.open(path, "r")
        if f then
            local result = f:read("a")
            return result
        else
            return nil, err
        end
    end
end

function dbg(...)
    io.stdout:write(string.format(...))
end

function dump(...)
    require("init_dump")
    -- That will overwrite this impl
    return dump(...)
end

json = setmetatable({
    dictHintMetatable = {},
    null = function() end, -- Magic placeholder
    dict = function(val)
        return setmetatable(val or {}, json.dictHintMetatable)
    end,
    encode = function(val)
        return dump(val, "json")
    end,
}, {
    __call = function(json, val)
        return json.encode(val)
    end
})

local _context

function makeSandbox()
    local env = {}
    setmetatable(env, {
        __index = {
            -- Globals
            assert = assert,
            debug = {
                traceback = debug.traceback,
            },
            error = error,
            ipairs = ipairs,
            math = math,
            next = next,
            os = {
                date = os.date,
                time = os.time,
            },
            pairs = pairs,
            pcall = pcall,
            rawequal = rawequal,
            rawget = rawget,
            rawlen = rawlen,
            rawset = rawset,
            select = select,
            string = string,
            table = table,
            tonumber = tonumber,
            tostring = tostring,
            type = type,
            utf8 = utf8,
            xpcall = xpcall,

            -- Our helpers
            json = json,

            -- Test
            -- bar = bar,
            -- posts = posts,
        }
    })
    if _context then
        for k, v in pairs(_context) do
            env[k] = v
        end
    end
    return env
end

function setContext(newContext)
    _context = newContext
end

function parseFile(filename)
    local text = readFile(filename)
    return parse(filename, text)
end

function parse(filename, text)
    local inprogress = nil
    local pos = 1
    local lineNumber = 1 -- refers to start of inprogress, if set
    local result = { n = 0 }
    local includes = {}
    local warnings = {}

    local env = makeSandbox()

    local function parseError(fmt, ...)
        local msg
        if select("#", ...) == 0 then
            msg = fmt
        else
            msg = string.format(fmt, ...)
        end
        error(string.format("%s:%d: %s", filename, lineNumber, msg), 0)
    end

    local function parseAssert(cond, fmt, ...)
        if cond then
            return cond
        else
            parseError(fmt, ...)
        end
    end

    local write = function(text)
        parseAssert(text ~= nil, "Cannot write() a nil value")
        result.n = result.n + 1
        result[result.n] = text
    end
    local writef = function(...)
        write(string.format(...))
    end
    env.write = write
    env.writef = writef
    local warning = function(format, ...)
        local line = debug.getinfo(2, "l").currentline
        local str = string.format("%s:%d: "..format, filename, line, ...)
        table.insert(warnings, str)
        io.stderr:write(str.."\n")
    end
    env.warning = warning
    env.file = function(newPath, newLine)
        dbg("FILE: %s:%d\n", newPath, newLine)
        filename = newPath
        lineNumber = newLine
    end

    env.eval = function(newText)
        text = text:sub(1, pos - 1)..newText..text:sub(pos)
    end

    env.include = function(path)
        local newText = parseAssert(readFile(path), "Failed to open file %s", path)
        local origFileDirective = string.format('{%% file(%q, %d) %%}', filename, lineNumber)
        local newFileDirective = string.format('{%% file(%q, 1) %%}', path)
        env.eval(newFileDirective..newText..origFileDirective)
        includes[path] = true
    end

    env.video = function(path)
        warning("video API is not implemented yet")
        writef("TODO: video(%q)", path)
    end

    -- Does not use or modify pos. Updates lineNumber on exit.
    local function textBlock(txt)
        -- dbg("[TEXT:%d]%s[/TEXT]\n", lineNumber, txt)
        if inprogress then
            inprogress = string.format("%s write(%q) ", inprogress, txt)
            -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
        else
            write(txt)
            lineNumber = lineNumber + countNewlines(txt)
        end
    end

    -- Note, pos must be updated before calls to codeBlock because this fn can
    -- modify text (thanks to the include API). Updates lineNumber.
    local function codeBlock(code)
        -- dbg("[CODE:%d]%s[/CODE]\n", lineNumber, code)
        local toEval = inprogress and inprogress..code or code
        local evalName = string.format("=%s", filename)
        -- Make line numbers in Lua errors correct by injecting newlines into the load data
        local fn, err = load(string.rep("\n", lineNumber - 1)..toEval, evalName, "t", env)
        if fn == nil then
            if err:match("<eof>$") then
                inprogress = toEval
                -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
            else
                parseError(err)
            end
        else
            inprogress = nil
            local prevLineNumber = lineNumber
            fn()
            -- This check is in case a file() directive has overridden the line number.
            if lineNumber == prevLineNumber then
                lineNumber = lineNumber + countNewlines(toEval)
            end
        end
    end

    local function nextBlock()
        local codePos = text:find("{%", pos, true)
        local exprPos = text:find("{{", pos, true)
        local commentPos = text:find("{#", pos, true)
        if exprPos and exprPos < (codePos or math.maxinteger) and exprPos < (commentPos or math.maxinteger) then
            -- {{ expression }}
            if exprPos > pos then
                textBlock(text:sub(pos, exprPos - 1))
                pos = exprPos
                return true
            end
            local endPos = assert(text:find("}}", exprPos + 2, true), "Unterminated {{")
            codeBlock(string.format(" write(%s) ", text:sub(exprPos + 2, endPos - 1)))
            pos = endPos + 2
            return true
        end

        if commentPos and commentPos < (codePos or math.maxinteger) then
            -- {# comment #}
            if commentPos > pos then
                textBlock(text:sub(pos, commentPos - 1))
                pos = commentPos
                return true
            end
            local endPos = parseAssert(text:find("#}", pos, true), "Unterminated {#")
            lineNumber = lineNumber + countNewlines(text:sub(pos, endPos - 1))
            pos = endPos + 2
            return true
        end

        if codePos then
            -- {% code %}
            if codePos > pos then
                textBlock(text:sub(pos, codePos - 1))
                pos = codePos
                return true
            end
            pos = codePos + 2
            local endPos = parseAssert(text:find("%}", pos, true), "Unterminated {%")
            local code = text:sub(pos, endPos - 1)
            pos = endPos + 2
            codeBlock(code)
            if text:sub(pos, pos) == "\n" then
                -- Skip first newline after a code block
                pos = pos + 1
                lineNumber = lineNumber + 1
            end
            return true
        end

        -- Reaching here, there's nothing but possibly text to the end of the doc
        assert(not inprogress, "Unterminated code block")
        if pos <= #text then
            textBlock(text:sub(pos))
            pos = #text + 1
            return true
        else
            return false
        end
    end

    while nextBlock() do 
        -- Just keep looping
    end
    return table.concat(result), includes, warnings
end

-- parse(example2)
-- parse(example3)
-- parse(example4)
-- print(json({a = "hel\\lo"}))
-- parse("example5", example5)
-- parse(example6)
