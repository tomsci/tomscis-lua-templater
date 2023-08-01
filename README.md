# templater.lua syntax

Templates are a combination of text (which is copied verbatim to the output) and various types of special block which are evaluated.

## Code blocks

These are the core of the templater. Code blocks are written in [Lua 5.4](https://www.lua.org/manual/5.4/manual.html) and can make use of any of the APIs described below. Crucially, code blocks may be fragments of Lua that are not by themselves a complete Lua block, and these may be combined with text and other blocks to form a valid Lua block. Such blocks can include control structures (such as loops) which can make text blocks appear in the output multiple times.

Code blocks are written as `{% ... %}` and can span multiple lines. They do not expand to anything, unless they contain code which calls `write()`.  All code blocks in a given parse operation share an environment, meaning a block may refer to a variable constructed by an earlier code block. Variables are not shared between parse operations.

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

The same rules apply for what is acceptable for `someLuaExpressionOrValue` as for [`write(val)`](#writeval) (ie it will error if the value is `nil`, etc).

## Comment blocks

These are written as `{# anything #}` and are ignored by the parser. Comment blocks can span multiple lines and can contain expression blocks and code blocks (which are ignored), but not other comment blocks.

Within a code block, the normal Lua comment block syntax can also be used:

```
{% -- This is a Lua comment within a code block

--[[
This is multiline Lua comment.
]]
%}
```

## Text blocks

Anything that isn't delimited by one of the above block sequences is considered a text block, including whitespace and newlines. Text blocks appearing between a partial code block and the code block which completes it are combined in-place within the code, at any other time text blocks are copied unchanged to the output.

To escape a sequence that might otherwise be interpreted as a block delimiter, wrap in an expression block that evaluates a Lua string, for example:

```
{{"{%"}} Not actually a code block %}

{{"{{"}} Not actually an expression block }}
```

Note it is easiest to escape just the starting block delimeter, as the ending delimiters do not need escaping in a text block.

## "Macro-style" code blocks

By combining a function definition with a partial code block it is possible to declare something that behaves a lot like a macro in other templating languages. For example:

```
{% function mymacro(arg1, arg2)
    -- Maybe do something with args, then terminate this code block without
    -- ending the function, to make this a partial code block which can be
    -- combined with some text and expression blocks...
%}
    Arg 1 is: {{arg1}}
    Arg 2 is: {{arg2}}

{# ...and now end the function, which completes the partial code block and
thereby completes the definition of 'mymacro()' #}

{% end %}

...

{% mymacro("hello", 123) %}
```

The `mymacro()` code block above expands to:

```
    Arg 1 is: hello
    Arg 2 is: 123
```

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
* `rawequal`
* `rawget`
* `rawlen`
* `rawset`
* `select`
* `string`
* `table`
* `tonumber`
* `tostring`
* `type`
* `utf8`

### `dump(val)`

Returns a string representation of `val` which can be of any type, expanding data structures as much as possible.

### `eval(text, [pathHint])`

Evaluates `text` and expands any special blocks. Does not return anything, the results of the evaluation (if any) are output directly.

Optionally, a `pathHint` may be supplied. This is used in error messages.

Example:

```
{% var = "me!" %}
{% eval("Hello from {{ var }}") %}

--> Hello from me!
```

### `include(path)`

Includes another template file into this template, as if the contents of the file at `path` were passed to `eval()`.

Example:

`{% include "header.html" %}`

Note the above example uses the "syntactic sugar" convenience form for a [Lua function call](https://www.lua.org/manual/5.4/manual.html#3.4.10), it could equally have been written `include("header.html")`.

### `json(val)`

Returns `val` converted to a JSON string. `val` can be any non-recursive Lua data structure containing only types representable in JSON. Empty tables are assumed to be arrays - to force a table to interpreted as a dict if empty, wrap it in a call to `json.dict()`.

Example:

`{{ json { a = "foo", b = "bar" } }}` returns (modulo whitespace) `{ "a": "foo", "b": "bar" }`

Note the above example uses the "syntactic sugar" convenience form for a [Lua function call](https://www.lua.org/manual/5.4/manual.html#3.4.10), it could equally have been written `json({ a = "foo", b = "bar" })`.

`{% foo = {}; write(json(foo)) %}` results in `[]`

`{% foo = json.dict {}; write(json(foo)) %}` results in `{}`

### `warning(format, ...)`

Emits a warning message (which does not appear in the output).

Example:

`{% warning("TODO fix this template") %}`

### `write(val)`

This is the most fundamental primitive which converts `val` to a string (if necessary, using [`tostring`](https://www.lua.org/manual/5.4/manual.html#pdf-tostring)) and writes it to the output. An error is raised if `val` evaluates to `nil`, or to a `table` or `userdata` without an explicit `__tostring` metamethod.

Example:

`{% write("Hello world!") %}`

### `writef(format, ...)`

Writes a format string to the output according to the rules of [`string.format`](https://www.lua.org/manual/5.4/manual.html#pdf-string.format). Equivalent to `write(string.format(format, ...))`.

Example:

`{% writef("Hello %s!\n", "world") %}`
