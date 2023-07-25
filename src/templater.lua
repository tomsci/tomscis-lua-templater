
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
6. Some more text.
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

if site == nil then
    site = {
        allposts = {
            { "1Para1", "1Para2", "1Para3" },
            { "2Para1", "2Para2", "2Para3" },
            { "3Para1", "3Para2", "3Para3" },
        },
    }
    function site.posts()
        return makeArrayIterator(site.allposts)
    end
end

function dbg(...)
    io.stdout:write(string.format(...))
end

function warning(...)
    io.stderr:write(string.format(...))
end

json = setmetatable({
    dictHintMetatable = {},
    null = function() end, -- Magic placeholder
    dict = function(val)
        return setmetatable(val or {}, json.dictHintMetatable)
    end,
    encode = function(val)
        if dump == nil then
            require("init_dump")
        end
        return dump(val, "json")
    end,
}, {
    __call = function(json, val)
        return json.encode(val)
    end
})

function makeSandbox()
    local env = {}
    setmetatable(env, {
        __index = {
            -- Globals
            ipairs = ipairs,
            pairs = pairs,
            next = next,
            pcall = pcall,
            print = print,
            error = error,
            assert = assert,
            string = string,
            table = table,
            math = math,
            utf8 = utf8,
            os = {
                date = os.date,
                time = os.time,
            },
            -- Our helpers
            write = write,
            writef = writef,
            dump = dump,
            json = json,

            -- Stuff from native side
            site = site,

            -- Test
            bar = bar,
            posts = posts,
        }
    })
    return env
end

function parse(filename, text)
    local inprogress = nil
    local pos = 1
    local lineNumber = 1 -- refers to start of inprogress, if set
    local result = {}

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
        table.insert(result, text)
    end
    env.write = write
    env.writef = function(...)
        table.insert(result, string.format(...))
    end

    env.file = function(newPath, newLine)
        -- dbg("FILE: %s:%d\n", newPath, newLine)
        filename = newPath
        lineNumber = newLine
    end

    env.include = function(path)
        -- We should probably implement some caching here at some point
        local f<close> = parseAssert(io.open(path, "r"), "Failed to open file %s", path)
        local newText = f:read("a")
        local origFileDirective = string.format('{%%file("%s", %d)%%}', filename, lineNumber)
        local newFileDirective = string.format('{%%file("%s", 1)%%}', path)
        text = text:sub(1, pos - 1)..newFileDirective..newText..origFileDirective..text:sub(pos)
    end

    local function textBlock(txt)
        -- dbg("[TEXT]%s[/TEXT]\n", txt)
        if inprogress then
            -- In order to make the inprogress line count match, we have to use
            -- a long string here, and because long strings eat prefixed
            -- newline chars, we have to manually add that back to the output
            -- if necessary.
            if txt:match("^\n") then
                inprogress = string.format("%s write('\\n'..[=[%s]=]) ", inprogress, txt)
            else
                inprogress = string.format("%s write[=[%s]=] ", inprogress, txt)
            end
            -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
        else
            write(txt)
            lineNumber = lineNumber + countNewlines(txt)
        end
    end

    -- Note, pos must be updated before calls to codeBlock because this fn can
    -- modify text (thanks to the include API)
    local function codeBlock(code)
        -- dbg("[CODE]%s[/CODE]\n", code)
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
            lineNumber = lineNumber + countNewlines(toEval)
            fn()
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
            if text:sub(pos, pos) == "\n" then
                -- Skip first newline after a code block
                pos = pos + 1
                lineNumber = lineNumber + 1
            end
            codeBlock(code)
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
    return table.concat(result)
end

-- parse(example2)
-- parse(example3)
-- parse(example4)
-- print(json({a = "hel\\lo"}))
-- parse(example5)
-- parse(example6)
