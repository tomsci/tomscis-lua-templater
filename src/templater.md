# templater.lua syntax

Templates are a combination of text (which is copied verbatim to the output) and various types of special block which are evaluated.

## Code blocks

These are the core of the templater. Code blocks are written in [Lua 5.4](https://www.lua.org/manual/5.4/manual.html) and can make use of any of the APIs described below. Crucially, code blocks may be fragments of Lua that are not by themselves a complete Lua block, and these may be combined with text and other blocks to form a valid Lua block. Such blocks can include control structures (such as loops) which can make text blocks appear in the output multiple times.

Code blocks are written as `{% ... %}` and can span multiple lines. They do not expand to anything, unless they contain code which calls `write()`.  All code blocks in a given file share an environment, meaning a block may refer to a variable constructed by an earlier code block. Variables are not shared between files.

For example, a simple code block would be:

```
{% write("Hello world!") %}
```

Which will add the text `Hello world!` to the output.

An example which combines a partial code block with text to form a for loop (note, this example also uses an expression block to evaluate `i`, explained below):

```
{% for i = 1, 4 do %}
    <li>{{ i }}</li>
{% end %}
```

This expands to:
```
    <li>1</li>
    <li>2</li>
    <li>3</li>
    <li>4</li>
```

The evaluation of partial code blocks is deferred until a code block that completes them is encountered, at which point the accumulated code and text is evaluated. An error will be raised if a file fails to complete any partial code blocks.

An error will be returned if a code block fails to parse for any reason other than it being a partial block, or if there is any error raised when the block is executed.

## Expression blocks

These are written as `{{ someLuaExpressionOrValue }}` (whitespace optional) and expand to the result of evaluating any variable or Lua statement valid in the current context. They are equivalent to a code block like `{% write(someLuaExpressionOrValue) %}`. Expression blocks can span multiple lines, although generally a code block might be a better choice at that point.

An error will be returned if the expression evaluates to `nil` (because that is how [`write(nil)`](#writeval) behaves).

## Comment blocks

These are written as `{# anything #}` and are ignored by the parser. Comment blocks can span multiple lines and can contain expression blocks and code blocks (which are ignored), but not other comment blocks.

## Text blocks

Anything that isn't delimited by one of the above block sequences is considered a text block, including whitespace and newlines. Text blocks appearing between a partial code block and the code block which completes it are combined in-place within the code, at any other time text blocks are copied unchanged to the output.

## API

There is no "special" syntax other than the block types described above. Everything else is just a Lua API which can be called inside code and expression blocks, and as such these APIs all conform to standard Lua syntax.

### Standard Lua functions

A sandboxed subset of the [standard Lua functions](https://www.lua.org/manual/5.4/contents.html#index) are available:

* `assert`
* `debug.traceback`
* `error`
* `ipairs`
* `math`
* `next`
* `os.date`, `os.time`
* `pairs`
* `pcall`
* `select`
* `string`
* `table`
* `tostring`
* `type`
* `utf8`


### `write(val)`

This is the most fundamental primitive which converts `val` to a string (if necessary, using [`tostring`](https://www.lua.org/manual/5.4/manual.html#pdf-tostring)) and writes it to the output. An error is raised if `val` evaluates to `nil`.

Example:

`{% write("Hello world!") %}`

### `writef(format, ...)`

Writes a format string to the output according to the rules of [`string.format`](https://www.lua.org/manual/5.4/manual.html#pdf-string.format). Equivalent to `write(string.format(format, ...))`.

Example:

`{% writef("Hello %s!\n", "world") %}`

### `json(val)`

Returns `val` converted to a JSON string. `val` can be any non-recursive Lua data structure containing only types representable in JSON. Empty tables are assumed to be arrays - to force a table to interpreted as a dict if empty, wrap it in a call to `json.dict()`.

Example:

`{{ json { a = "foo", b = "bar" } }}` returns (modulo whitespace) `{ "a": "foo", "b": "bar" }`

Note the above example uses the "syntactic sugar" convenience form for a [Lua function call](https://www.lua.org/manual/5.4/manual.html#3.4.10), it could equally have been written `json({ a = "foo", b = "bar" })`.

`{% foo = {}; write(json(foo)) %}` results in `[]`

`{% foo = json.dict {}; write(json(foo)) %}` results in `{}`

### `include(path)`

Includes another template file into this template immediately after the current code block (for this reason, it's a good idea to not put anything else in a code block which contains an `include`). The contents of `path` will be evaluated as if they were part of the current file, and thus may contain text, code blocks etc.

Example:

`{% include "header.html" %}`

Note the above example uses the "syntactic sugar" convenience form for a [Lua function call](https://www.lua.org/manual/5.4/manual.html#3.4.10), it could equally have been written `include("header.html")`.
