
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
    local i = 1
    local nextLinePos = 1
    for line, pos in text:gmatch("(.-)\n()") do
        if i == num then
            return line
        end
        i = i + 1
        nextLinePos = pos
    end
    if i == num and nextLinePos <= #text then
        return text:sub(nextLinePos)
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

function assertf(cond, lvl, fmt, ...)
    if not cond then
        error(string.format(fmt, ...), lvl == 0 and 0 or lvl + 1)
    end
    return cond
end

function errorf(lvl, fmt, ...)
    error(string.format(fmt, ...), lvl == 0 and 0 or lvl + 1)
end

function checkedToString(val)
    local t = type(val)
    if t == "userdata" or t == "table" then
        -- It's an error if it doesn't have a metatable with a __tostring
        if getmetatable(val).__tostring == nil then
            errorf(3, "Cannot stringify a raw table or userdata %s", dump(val))
        end
    end
    return tostring(val)
end

function tappend(tbl, val)
    local n = tbl.n + 1
    tbl.n = n
    tbl[n] = val
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
        includes = { [filename] = text},
        result = result,
        frames = {},
        frame = { env = env },
    }

    env.write = function(text)
        assertf(text ~= nil, 2, "Cannot write() a nil value")
        tappend(result, checkedToString(text))
    end

    env.writef = function(...)
        env.write(string.format(...))
    end

    env.warning = function(format, ...)
        local info = debug.getinfo(2, "lS")
        local line = info.currentline
        local str = string.format("%s:%d: Warning: "..format, info.short_src, info.currentline, ...)
        if printWarning then
            printWarning(str)
        else
            io.stderr:write(str.."\n")
        end
    end

    env.whereami = function()
        local info = debug.getinfo(2, "lS")
        env.writef("%s:%d", info.short_src, info.currentline)
    end

    env.video = function(path)
        env.warning("video API is not implemented yet")
        env.writef("TODO: video(%q)", path)
    end

    -- Should only be called by include() and eval() (or things similarly one level away from user code)
    local function getLocals()
        local results = {}
        local i = 2 -- Upvalue 1 will always be _ENV, so skip that
        local f = debug.getinfo(3, "f").func
        while true do
            local name, val = debug.getupvalue(f, i)
            if name then
                -- dbg("upvalue %s %s\n", name, val)
                result[name] = val
                i = i + 1
            else
                break
            end
        end
        local i = 1
        while true do
            local name, val = debug.getlocal(3, i)
            if name then
                -- dbg("local %s %s\n", name, val)
                results[name] = val
                i = i + 1
            else
                break
            end
        end
        return results
    end

    env.eval = function(text, pathHint)
        doParse(pathHint or "<eval>", text, ctx, getLocals())
    end

    env.include = function(path)
        local newText = assertf(readFile(path), 2, "Failed to open file %s", path)
        ctx.includes[path] = newText
        doParse(path, newText, ctx, getLocals())
    end

    local errorHandler = function(err)
        -- Walk the stack to find the first source matching anything in includes, and get the line number from there
        local errLine, errFile, errText
        local pos = 2
        while true do
            local info = debug.getinfo(pos, "lS")
            if not info then
                break
            end
            local sourceFile = info.source:match("^@(.*)")
            if sourceFile and ctx.includes[sourceFile] then
                errLine = info.currentline
                errFile = sourceFile
                errText = ctx.includes[sourceFile]
                break
            end
            pos = pos + 1
        end

        if errLine then
            local msg = string.format("%s\n>>> %s:%d: %s", err, errFile, errLine, getLine(errText, errLine))
            return debug.traceback(msg, 2)
        else
            return debug.traceback(err, 2)
        end
    end
    local ok, err = xpcall(doParse, errorHandler, filename, text, ctx)
    if not ok then
        error(err, 0)
    end

    return table.concat(ctx.result), ctx.includes
end

function doParse(filename, text, ctx, locals)
    local pos = 1
    local frame = {
        fileName = filename,
        lineNumber = 1,
    }
    local parentEnv = ctx.frame.env
    if locals then
        frame.env = setmetatable(locals, {
            __index = parentEnv,
            __newindex = function(_, name, val)
                parentEnv[name] = val
            end
        })
    else
        frame.env = parentEnv
    end
    table.insert(ctx.frames, frame)
    ctx.frame = frame
    local env = frame.env -- convenience
    local codeFrags = { n = 0 }

    local function parseAssert(cond, msg)
        if cond then
            return cond
        else
            error(string.format("%s:%d: %s", frame.fileName, frame.lineNumber, msg), 0)
        end
    end

    local function addCode(code)
        tappend(codeFrags, code)
        frame.lineNumber = frame.lineNumber + countNewlines(code)
    end

    -- Does not use or modify pos. Updates frame.lineNumber on exit.
    local function textBlock(txt)
        -- dbg("[TEXT:%d]%s[/TEXT]\n", frame.lineNumber, txt)
        addCode(string.format(" write(%q) ", txt))
    end

    -- Does not use or modify pos. Updates frame.lineNumber on exit.
    local function codeBlock(block)
        -- dbg("[CODE:%d]%s[/CODE]\n", frame.lineNumber, code)
        addCode(block)
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
            local endPos = parseAssert(text:find("}}", exprPos + 2, true), "Unterminated {{")
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
            local numLines = countNewlines(text:sub(pos, endPos - 1))
            addCode(string.rep("\n", numLines - 1))
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
                addCode("\n")
                pos = pos + 1
            end
            return true
        end

        -- Reaching here, there's nothing but possibly text to the end of the doc
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

    -- Actually evaluate text's code
    local code = table.concat(codeFrags)
    -- dbg("Code for %s is:\n%s", frame.fileName, code)
    local evalName = string.format("@%s", frame.fileName)
    local fn, err = load(code, evalName, "t", env)
    if fn == nil then
        error(err, 0)
    else
        fn()
    end

    -- Pop our frame from the stack
    local lastFrame = #ctx.frames
    table.remove(ctx.frames, lastFrame)
    ctx.frame = ctx.frames[lastFrame - 1]
end
