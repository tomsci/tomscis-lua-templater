
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

function getLine(text, num)
    local i = 0
    for line in text:gmatch("(.-)\n") do
        i = i + 1
        if i == num then
            return line
        end
    end
    return nil
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

function assertf(cond, fmt, ...)
    if not cond then
        error(string.format(fmt, ...), 2)
    end
    return cond
end

function errorf(fmt, ...)
    error(string.format(fmt, ...), 2)
end

function checkedToString(val)
    local t = type(val)
    if t == "userdata" or t == "table" then
        -- It's an error if it doesn't have a metatable with a __tostring
        if getmetatable(val).__tostring == nil then
            errorf("Cannot stringify a raw table or userdata %s", dump(val))
        end
    end
    return tostring(val)
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
            dump = function(...) return _G.dump(...) end,
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
    -- print("setContext", dump(newContext))
    _context = newContext
end

function parseFile(filename)
    local text = readFile(filename)
    return parse(filename, text)
end

function parse(filename, text)
    local env = makeSandbox()
    local result = { n = 0 }
    local ctx = {
        includes = {},
        warnings = {},
        result = result,
        env = env,
    }

    -- Note, parseError/parseAssert are only for errors in parsing blocks, and
    -- should not be used by any of the APIs in env (ie things called from
    -- code blocks).
    local function parseError(fmt, ...)
        local msg
        if select("#", ...) == 0 then
            msg = fmt
        else
            msg = string.format(fmt, ...)
        end
        error(string.format("%s:%d: %s", ctx.fileName, ctx.lineNumber, msg), 0)
    end
    ctx.parseError = parseError

    local function parseAssert(cond, fmt, ...)
        if cond then
            return cond
        else
            parseError(fmt, ...)
        end
    end
    ctx.parseAssert = parseAssert

    env.write = function(text)
        assert(text ~= nil, "Cannot write() a nil value")
        result.n = result.n + 1
        result[result.n] = checkedToString(text)
    end

    env.writef = function(...)
        env.write(string.format(...))
    end

    env.warning = function(format, ...)
        local line = debug.getinfo(2, "l").currentline
        local str = string.format("%s:%d: "..format, ctx.fileName, line, ...)
        table.insert(ctx.warnings, str)
        io.stderr:write(str.."\n")
    end

    env.whereami = function()
        env.writef("%s:%d", ctx.fileName, ctx.lineNumber)
    end

    env.video = function(path)
        env.warning("video API is not implemented yet")
        env.writef("TODO: video(%q)", path)
    end

    env.eval = function(text, pathHint)
        doParse(pathHint or "<eval>", text, ctx)
    end

    env.include = function(path)
        local newText = assertf(readFile(path), "Failed to open file %s", path)
        ctx.includes[path] = true
        env.eval(newText, path)
    end

    local errorHandler = function(err)
        -- Walk the stack to find a source matching @ctx.filename, and get the line number from there
        local errLine
        local expectedSource = "@"..ctx.fileName
        local pos = 2
        while true do
            local info = debug.getinfo(pos, "lS")
            if not info then
                break
            elseif info.source == expectedSource then
                errLine = info.currentline
                break
            end
            pos = pos + 1
        end

        if errLine then
            local msg = string.format("%s\n>>> %s:%d: %s", err, ctx.fileName, errLine, getLine(ctx.text, errLine))
            return debug.traceback(msg, 2)
        else
            return debug.traceback(err, 2)
        end
    end
    local ok, err = xpcall(doParse, errorHandler, filename, text, ctx)
    if not ok then
        error(err, 0)
    end

    return table.concat(ctx.result), ctx.includes, ctx.warnings
end

function doParse(filename, text, ctx)
    local inprogress = nil
    local pos = 1
    local prevFile, prevLine, prevText = ctx.fileName, ctx.lineNumber, ctx.text
    ctx.fileName = filename
    ctx.lineNumber = 1 -- refers to start of inprogress, if set
    ctx.text = text
    local env = ctx.env -- convenience

    -- Does not use or modify pos. Updates ctx.lineNumber on exit.
    local function textBlock(txt)
        -- dbg("[TEXT:%d]%s[/TEXT]\n", ctx.lineNumber, txt)
        if inprogress then
            inprogress = string.format("%s write(%q) ", inprogress, txt)
            -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
        else
            env.write(txt)
            ctx.lineNumber = ctx.lineNumber + countNewlines(txt)
        end
    end

    -- Does not use or modify pos. Updates ctx.lineNumber on exit.
    local function codeBlock(code)
        -- dbg("[CODE:%d]%s[/CODE]\n", ctx.lineNumber, code)
        local toEval = inprogress and inprogress..code or code
        local evalName = string.format("@%s", ctx.fileName)
        -- Make line numbers in Lua errors correct by injecting newlines into the load data
        local fn, err = load(string.rep("\n", ctx.lineNumber - 1)..toEval, evalName, "t", env)
        if fn == nil then
            if err:match("<eof>$") then
                inprogress = toEval
                -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
            else
                ctx.parseError(err)
            end
        else
            inprogress = nil
            local prevLineNumber = ctx.lineNumber
            fn()
            assert(ctx.lineNumber == prevLineNumber, "Context line number changed by code block!") -- juuuust in case
            ctx.lineNumber = ctx.lineNumber + countNewlines(toEval)
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
            local endPos = ctx.parseAssert(text:find("}}", exprPos + 2, true), "Unterminated {{")
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
            local endPos = ctx.parseAssert(text:find("#}", pos, true), "Unterminated {#")
            ctx.lineNumber = ctx.lineNumber + countNewlines(text:sub(pos, endPos - 1))
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
            local endPos = ctx.parseAssert(text:find("%}", pos, true), "Unterminated {%")
            local code = text:sub(pos, endPos - 1)
            pos = endPos + 2
            codeBlock(code)
            if text:sub(pos, pos) == "\n" then
                -- Skip first newline after a code block
                pos = pos + 1
                ctx.lineNumber = ctx.lineNumber + 1
            end
            return true
        end

        -- Reaching here, there's nothing but possibly text to the end of the doc
        ctx.parseAssert(not inprogress, "Incomplete partial code block")
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

    -- Restore these to their previous values on exit
    ctx.fileName = prevFile
    ctx.lineNumber = prevLine
    ctx.text = prevText
end
