example = [[
<ul>
{% for a in ipairs(bar.cheese()) do %}
    <li>{% write(a) %}</li>
{% end %}
</ul>
]]

example2 = [[
<ul>
{% for a in ipairs(bar.cheese()) do writef("<li>%s</li>\n", a) end %}
</ul>
]]

bar = {
    cheese = function() return { 1, 2, 3, 4 } end
}

example3 = [[
{% for _, post in ipairs(posts) do %}
    {% for _, paragraph in ipairs(post) do %}
        <li> {{paragraph}} </li>
    {% end %}
{% end %}
]]

example4 = [[
{%
for _, post in ipairs(posts) do
    for _, paragraph in ipairs(post) do %}
        <li> {{paragraph}} </li>
    {% end %}
{% end %}
]]

posts = {
    { "1Para1", "1Para2", "1Para3" },
    { "2Para1", "2Para2", "2Para3" },
    { "3Para1", "3Para2", "3Para3" },
}

function write(arg)
    io.stdout:write(tostring(arg))
end

function writef(...)
    io.stdout:write(string.format(...))
end

function dbg(...)
    io.stdout:write(string.format(...))
end

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

            -- Stuff from native side
            site = site,

            -- Test
            bar = bar,
            posts = posts,
        }
    })
    return env
end

function parse(text)
    local inprogress = nil
    local env = makeSandbox()
    local function textBlock(txt)
        -- dbg("[TEXT]%s[/TEXT]\n", txt)
        if inprogress then
            inprogress = string.format("%s write[=[\n%s]=] ", inprogress, txt)
            -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
        else
            write(txt)
        end
    end
    local function codeBlock(code)
        -- dbg("[CODE]%s[/CODE]\n", code)
        local toEval = inprogress and inprogress..code or code
        local fn, err = load(toEval, "=example", "t", env)
        if fn == nil then
            if err:match("<eof>$") then
                inprogress = toEval
                -- dbg("[INPROGRESS]%s[/INPROGRESS]\n", inprogress)
            else
                error(err)
            end
        else
            inprogress = nil
            fn()
        end
    end

    local pos = 1
    local function nextBlock()
        local codePos = text:find("{%", pos, true)
        local exprPos = text:find("{{", pos, true)
        if exprPos and (codePos == nil or codePos > exprPos) then
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

        if codePos then
            -- {% code %}
            if codePos > pos then
                textBlock(text:sub(pos, codePos - 1))
                pos = codePos
                return true
            end
            local endPos = assert(text:find("%}", codePos + 2, true), "Unterminated {%")
            codeBlock(text:sub(codePos + 2, endPos - 1))
            pos = endPos + 2
            if text:sub(pos, pos) == "\n" then
                -- Skip first newline after a code block
                pos = pos + 1
            end
            return true
        end

        -- Reaching here, there's nothing but text to the end of the doc
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
end

-- parse(example)
-- parse(example2)
-- parse(example3)
parse(example4)
