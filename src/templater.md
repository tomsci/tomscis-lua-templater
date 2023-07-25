# templater.lua syntax

Templates are a combination of text (which is copied verbatim to the output) and various types of special block which are evaluated.

## Code blocks

These are the core of the templater. Code blocks are written in [Lua 5.4](https://www.lua.org/manual/5.4/manual.html) and can make use of any of the APIs described below. Crucially, code blocks may be fragments of Lua that are not by themselves a complete Lua block, and these may be combined with text and other blocks to form a valid Lua block. Such blocks can include control structures (such as loops).

Code blocks are written as `{% ... %}` and can span multiple lines. All code blocks in a given file share an environment, meaning a block may refer to a variable constructed by an earlier code block. Variables are not shared between files.

For example, a simple code block would be:

```
{% write("Hello world!") %}
```

Which will add the text `Hello world!` to the output.

An example which combines a partial code block with text to form a for loop (note, this example also uses an expression block to evaluate `i`, explained below):

```
{% for i in ipairs{1,2,3,4} do %}
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

## Expression blocks

These are written as `{{ someLuaExpressionOrValue }}` and expand to the result of evaluating any variable or Lua statement valid in the current context. They are a convenience for `{% write(someLuaExpressionOrValue) %}`. Expression blocks can span multiple lines, although generally a code block might be a better choice at that point.

## Comment blocks

These are written as `{# anything #}` and are ignored by the parser. Comment blocks can span multiple lines and can contain expression blocks and code blocks (which are ignored), but not other comment blocks.

## API

There is no "special" syntax other than the block types described above. Everything else is just a Lua API which can be called inside code and expression blocks, and as such these APIs all conform to standard Lua syntax.

### `write(val)`

This is the most fundamental primitive which casts `val` to a string (if necessary, using `tostring`) and writes it to the output.

Example:

`{% write("Hello world!") %}`

### `writef(format, ...)`

Writes a format string to the output. Convenience for `write(string.format(format, ...))`.

Example:

`{% writef("Hello %s!\n", "world") %}`

### `json(val)`

Returns `val` converted to JSON. `val` can be any non-recursive Lua data structure containing only types representable in JSON.

Example:

`{{ json({ a = "foo", b = "bar" }) }}`

### `include(path)`

Includes another template file into this template immediately after the current code block (for this reason, it's a good idea to not put anything else in a code block which contains an `include`). The contents of `path` will be evaluated as if they were part of the current file, and thus may contain text, code blocks etc.

Example:

`{% include "header.html" %}`

Note the above example uses the "syntactic sugar" convenience form for a [Lua function call](https://www.lua.org/manual/5.4/manual.html#3.4.10), it could equally have been written `include("header.html")`.
