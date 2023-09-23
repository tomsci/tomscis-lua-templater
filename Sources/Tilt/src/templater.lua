-- Copyright (c) 2023 Tom Sutcliffe
-- See LICENSE file for license information.

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

local function tappend(tbl, val)
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
        }
    })
    return env
end


function render(filename, text, env, globalIncludes)
    if env == nil then
        env = makeSandbox()
    end
    local result = { n = 0 }
    local ctx = {
        includes = { [filename] = true},
        sources = {},
        result = result,
        frame = { env = env },
    }
    ctx.frames = { ctx.frame }

    local write = function(text)
        assertf(text ~= nil, 2, "Cannot write() a nil value")
        tappend(result, checkedToString(text))
    end
    env.write = write

    env.writef = function(...)
        write(string.format(...))
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
        doRender(pathHint, text, ctx, getLocals())
    end

    local function doInclude(path, locals)
        local newText = assertf(readFile(path), 2, "Failed to open file %s", path)
        ctx.includes[path] = true
        doRender(path, newText, ctx, locals)
    end

    env.include = function(path)
        doInclude(path, getLocals())
    end

    env.render = function(path, text)
        local result = { n = 0 }
        local locals = getLocals()
        local origWrite = write
        local customWriteFn = function(text)
            tappend(result, text)
        end
        locals.write = customWriteFn
        if text == nil then
            text = assertf(readFile(path), 2, "Failed to open file %s", path)
            ctx.includes[path] = true
        end
        write = customWriteFn
        doRender(path, text, ctx, locals)
        write = origWrite
        return table.concat(result)
    end

    local function errorHandler(err)
        -- Walk the stack to find the first source matching anything in sources, and get the line number from there
        local errLine, errFile, errText
        local pos = 2
        while true do
            local info = debug.getinfo(pos, "lS")
            if not info then
                break
            end
            local sourceFile = info.source:match("^@(.*)")
            local found = nil
            for _, source in ipairs(ctx.sources) do
                if source.filename == sourceFile then
                    found = source.text
                    break
                end
            end
            -- if sourceFile and ctx.includes[sourceFile] then
            if found then
                errLine = info.currentline
                errFile = sourceFile
                errText = getLine(found, errLine)
                break
            end
            pos = pos + 1
        end

        if errLine then
            local msg = string.format("%s\n>>> %s:%d: %s", err, errFile, errLine, errText)
            return debug.traceback(msg, 2)
        else
            return debug.traceback(err, 2)
        end
    end

    if globalIncludes then
        local ok, err = xpcall(function()
            for i, path in ipairs(globalIncludes) do
                doInclude(path, nil)
            end
        end, errorHandler)
        if not ok then error(err, 0) end
    end

    local ok, err = xpcall(doRender, errorHandler, filename, text, ctx)
    if not ok then
        error(err, 0)
    end

    return table.concat(ctx.result), ctx.includes
end

function doRender(filename, text, ctx, locals)
    if filename == nil then
        filename = string.format("<eval#%d>", #ctx.sources + 1)
    end
    table.insert(ctx.sources, { filename = filename, text = text })
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
        local stringPos, stringEndPos, neqs = text:find("%[(=*)%[", pos)
        local commentPos = text:find("--", pos, true)
        local max = math.maxinteger
        local blockPos = math.min(codePos or max, exprPos or max, stringPos or max)
        if commentPos and stringPos and commentPos == stringPos - 2 and commentPos < blockPos then
            blockPos = commentPos
        end

        if blockPos ~= max and blockPos > pos then
            textBlock(text:sub(pos, blockPos - 1))
            pos = blockPos
            return true
        end

        if exprPos == blockPos then
            -- {{ expression }}
            local endPos = parseAssert(text:find("}}", exprPos + 2, true), "Unterminated {{")
            codeBlock(string.format(" write(%s) ", text:sub(exprPos + 2, endPos - 1)))
            pos = endPos + 2
            return true
        end

        if codePos == blockPos then
            -- {% code %}
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

        if stringPos == blockPos or commentPos == blockPos then
            -- [[ escaped text ]] or [=[ escaped text ]=] etc
            local endSeq = string.format("]%s]", neqs)
            local endPos = parseAssert(text:find(endSeq, stringEndPos + 1, true), "Missing "..endSeq)
            local blockContents = text:sub(stringEndPos + 1, endPos - 1)
            if blockPos == commentPos then
                -- Comment block, just have to balance line numbers
                local numLines = countNewlines(blockContents)
                addCode(string.rep("\n", numLines - 1))
            else
                if blockContents:sub(1, 1) == "\n" then
                    -- Eat leading newline
                    addCode("\n")
                    textBlock(blockContents:sub(2))
                else
                    textBlock(blockContents)
                end
            end
            pos = endPos + #endSeq
            return true
        end

        -- Shouldn't ever happen
        assertf(blockPos == max, 1, "Unhandled blockPos %d pos %d", blockPos, pos)

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
