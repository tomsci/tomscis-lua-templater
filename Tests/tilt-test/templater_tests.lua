#!/usr/bin/env lua

-- Copyright (c) 2023 Tom Sutcliffe
-- See LICENSE file for license information.

if not pcall(require, "templater") then
    -- Support for being run from the shell
    package.path = "../../Sources/Tilt/src/?.lua"
    require("templater")
end

local readFileData = {}
function readFile(name)
    return assert(readFileData[name])
end

local function assertEquals(a, b)
    if a ~= b then
        error(string.format("%s not equal to %s", dump(a, "quoted_long"), dump(b, "quoted_long")))
    end
end

local currentTestName
local tests = {}
setmetatable(_ENV, { __newindex = function(env, name, val)
    if name:match("^test_") and type(val) == "function" then
        table.insert(tests, name)
    end
    rawset(env, name, val)
end})

local function render(template)
    return _ENV.render(currentTestName, template)
end

local function assertParseError(text, expected)
    local ok, err = pcall(render, text)
    assert(not ok, "Parse was expected to error but didn't!")
    if err:sub(1, #expected + 1) ~= expected.."\n" then
        error(string.format("%s does not start with %s", dump(err, "quoted_long"), dump(expected, "quoted_long")))
    end
end

function test_simple()
    local template = [[
Line 1
This is {% writef("line %d\n", 2) %}
Line 3
]]
    local expected = [[
Line 1
This is line 2
Line 3
]]
    assertEquals(render(template), expected)
end

function test_unterminated_codeblock()
    local template = [[
1.
2. {% write("hello")
]]
    assertParseError(template, "test_unterminated_codeblock:2: Unterminated {%")
end

function test_incomplete_partial_codeblock()
    local template = [[
1.
2. {% function foo() %}
]]
    assertParseError(template, "test_incomplete_partial_codeblock:3: 'end' expected (to close 'function' at line 2) near <eof>")
end

function test_code_err()
    local template = [[
1.
2. {% woop woop %}
]]
    assertParseError(template, "test_code_err:2: syntax error near 'woop'")
end

function test_nil_value()
    assertParseError("{{somethingThatsNil}}", "test_nil_value:1: Cannot write() a nil value\
>>> test_nil_value:1: {{somethingThatsNil}}")
end

function test_example_1()
    local template = [[
<ul>
{% testData = { 11, 22, 33, 44 } %}
{% for _, val in ipairs(testData) do %}
    <li>{{ val }}</li>
{% end %}
</ul>
]]
    local expected = [[
<ul>
    <li>11</li>
    <li>22</li>
    <li>33</li>
    <li>44</li>
</ul>
]]
    assertEquals(render(template), expected)
end

function test_comment()
    local template = [===[
Some text
Then --[=[ a comment that's ]] awkward {{nope}} ]=] & more text.
]===]
    local expected = [[
Some text
Then  & more text.
]]
    assertEquals(render(template), expected)
end

function test_line_numbers()
    local template = [[
1. text
2. {%
-- 3
-- 4
-- 5 %}
6. {{
"line 7"
}} 8
9 {% for i = 1, 1 do %}

{% end %}
{{ 12
]]
    assertParseError(template, "test_line_numbers:12: Unterminated {{")
end

function test_simple_include()
    readFileData = {
        blah = [[
First line of blah
{% whereami() %}.
]]
    }

    local template = [[
line
{% include "blah" %}
3. {% whereami() %}.
]]
    local expected = [[
line
First line of blah
blah:2.
3. test_simple_include:3.
]]
    assertEquals(render(template), expected)
end

function test_partial_include()
    -- An include inside a partial code block
    readFileData = {
        blah = [[
First line of blah
{% whereami() %}.
]]
    }

    local template = [[
{% function foo() %}
    Start of foo
    {% include "blah" %}
    More foo
{% end %}
6. {% whereami() %}.
7. {% foo() %}
]]
    local expected = [[
6. test_partial_include:6.
7.     Start of foo
    First line of blah
blah:2.
    More foo
]]
    assertEquals(render(template), expected)
end

function test_eval()
    local template = [=[
Hello {% eval("world") %}.
Hello {% eval([[
world
{% whereami() %]].."}") %}
]=]
    local expected = [[
Hello world.
Hello world
<eval#3>:2]]
    assertEquals(render(template), expected)
end

function test_dump()
    local template = "{{ dump({11,22}) }}"
    local expected = [[
{
  11,
  22,
}]]
    assertEquals(render(template), expected)
end

function test_render()
    readFileData = {
        blah = [[
First line of blah
{% whereami() %}.
]]
    }

    local template = [[
line
{% local foo = render("blah") %}
foo is {{ foo }}
]]
    local expected = [[
line
foo is First line of blah
blah:2.

]]
    assertEquals(render(template), expected)
end

function test_escapes()
    local template = '{{ "{%" }} something {{ "%}" }}'
    local expected = '{% something %}'
    assertEquals(render(template), expected)
end

function test_string_blocks()
    local template = "This is [[{%escaped%}]]"
    local expected = "This is {%escaped%}"
    assertEquals(render(template), expected)

    local template = "This is [=[{%escaped%}]=]."
    local expected = "This is {%escaped%}."
    assertEquals(render(template), expected)

    local template = "This is [[{{}}]]."
    local expected = "This is {{}}."
    assertEquals(render(template), expected)

    -- Check we skip leading newlines
    local template = "This is [[\n{{}}]]."
    local expected = "This is {{}}."
    assertEquals(render(template), expected)

    -- Literal [[]]
    local template = "This is [=[[[]=][=[]]]=]"
    local expected = "This is [[]]"
    assertEquals(render(template), expected)

    -- Check leading newline in long-string block doesn't mess up line numbers
    local template = [=[
long text [[
{% error("not code") %}
]]
{% whereami() %}
]=]
    local expected = [[
long text {% error("not code") %}

test_string_blocks:4]]
    assertEquals(render(template), expected)
end


function runTest(name)
    io.stdout:write(string.format("Running %s\n", name))
    currentTestName = name
    _ENV[name]()
end

function main()
    for _, name in ipairs(tests) do
        runTest(name)
    end
end
main()
-- runTest"test_incomplete_partial_codeblock"

--     site = {
--         allposts = {
--             { "1Para1", "1Para2", "1Para3" },
--             { "2Para1", "2Para2", "2Para3" },
--             { "3Para1", "3Para2", "3Para3" },
--         },
--     }
