#!/usr/bin/env lua

require("templater")

local function assertEquals(a, b)
    if a ~= b then
        error(string.format("%s not equal to %s", a, b))
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

local function parse(template)
    return _ENV.parse(currentTestName, template)
end

local function assertParseError(text, expected)
    local ok, err = pcall(parse, text)
    assert(not ok)
    assertEquals(err, expected)
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
    assertEquals(parse(template), expected)
end

function test_unterminated_codeblock()
    local template = [[
1.
2. {% write("hello")
]]
    assertParseError(template, "test_unterminated_codeblock:2: Unterminated {%")
end

function test_code_err()
    local template = [[
1.
2. {% woop woop %}
]]
    -- Yes, code errors currently give you two locations
    assertParseError(template, "test_code_err:3: test_code_err:3: syntax error near 'woop'")
end

function test_nil_value()
    assertParseError("{{somethingThatsNil}}", "test_nil_value:1: Cannot write() a nil value")
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
    assertEquals(parse(template), expected)
end

function test_comment()
    local template = [[
Some text
Then {# a comment that's {% awkward {{nope}} #} & more text.
]]
    local expected = [[
Some text
Then  & more text.
]]
    assertEquals(parse(template), expected)
end

function main()
    for _, name in ipairs(tests) do
        io.stdout:write(string.format("Running %s\n", name))
        currentTestName = name
        _ENV[name]()
    end
end
main()
