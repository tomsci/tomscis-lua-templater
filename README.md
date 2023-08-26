# Tomsci's InContext Lua Templater (or "Tilt" for short)

A lightweight templating engine designed to be embedded in a website builder such as InContext.

Tilt templates are a combination of text (which is copied verbatim to the output) and various types of special block which are evaluated.

## Code blocks

These are the core of the templater. Code blocks are written in [Lua 5.4](https://www.lua.org/manual/5.4/manual.html) and can make use of any of the APIs described below. Code blocks can be interleaved with text and other blocks. Code blocks can include control structures (such as loops) which can make text blocks appear in the output multiple times.

Code blocks are written as `{% ... %}` and can span multiple lines. They do not expand to anything, unless they contain code which (directly or indirectly) calls [`write()`](#writeval).  All code blocks in a given template render share an environment, meaning a block may refer to a variable constructed by an earlier code block. Variables are not shared between renders.

Code blocks do not need to form value Lua blocks - they can be snippets of code providing that they evaluate to a valid Lua block when combined with the subsequent code blocks. Such snippets are referred to as 'partial' code blocks.

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

An error will be returned if the combined code, text etc blocks fail to parse, or if there is any error raised by any of the code blocks.

## Expression blocks

These are written as `{{ someLuaExpressionOrValue }}` (whitespace optional) and expand to the result of evaluating any variable or Lua statement valid in the current context. They are equivalent to a code block like `{% write(someLuaExpressionOrValue) %}`. Expression blocks can span multiple lines, although generally a code block might be a better choice at that point.

The same rules apply for what is acceptable for `someLuaExpressionOrValue` as for [`write(val)`](#writeval) (ie it will error if the value is `nil`, etc).

## Long-string blocks

To escape any number of other block declarations, you can wrap them in a long-string block, modeled after Lua's [long literal](https://www.lua.org/manual/5.4/manual.html#3.1) string syntax, the contents of which are copied to the output with no further expansion. This is useful when including examples of Tilt template syntax in a template, for example.

```
This is normal text.

[[
This is a long-string block so this {% isn't code %}.
]]
```

outputs:

```
This is normal text.

This is a long-string block so this {% isn't code %}.

```

As with Lua's long literals, any number of `=` characters can be put between the square brackets, if you need to escape something which itself contains a closing long literal sequence such as `]]` (or `]=]`, etc):

```
[=[
write([[Getting tricky now are we?]])
]=]
```

In keeping with the Lua syntax, if the first character of a long-string block is a newline, it is skipped.

To include a literal `[[` or `]]` sequence (or `[=[`, etc), use `[=[[[]=]`/`[=[]]]=]`, or an expression block with a string in, like `{{ "[[" }}`

## Comment blocks

These are written in the same way as Lua long comments `--[[ comment ]]` and are ignored by the parser. Comment blocks can span multiple lines and can contain any type of block (all of which are ignored) which doesn't contain the comment end delimiter. The same long literal logic applies as with long-string blocks, so to comment out something which contains `[[` or `]]`, use a delimiter with more equals signs such as `--[=[ comment with [[]] in! ]=]`.

Within a code block, the normal Lua comment syntax can also be used.

```

--[[ This is a comment block ]]

--[=[
This is a multiline comment block which comments out a code block and a long-string block.

{% This code block is ignored because it's in a comment block %}

This string block is also ignored: [[ ]].

End of multiline comment block: ]=]

{% -- This is a single-line Lua comment within a code block

--[[
This is multiline long Lua comment within a code block.
]]
%}
```

Note that `--` on its own in a text block without a following `[`, does _not_ introduce a single-line comment. As such, `--` does not need escaping in text blocks unless it forms part of a comment block delimiter (in which case, enclose it in a long-string block with a different number of `=`).

## Text blocks

Anything that isn't delimited by one of the above block sequences is considered a text block, including whitespace and newlines. Text blocks appearing between a partial code block and the code block which completes it are combined in-place within the code, at any other time text blocks are copied unchanged to the output.

## "Macro-style" code blocks

By combining a function definition with a partial code block it is possible to declare something that behaves a lot like a macro in other templating languages. For example:

```
{%
function mymacro(arg1, arg2)
    -- Maybe do something with args, then terminate this code block without
    -- ending the function, to make this a partial code block which can be
    -- combined with some text and expression blocks...
%}
    Arg 1 is: {{arg1}}
    Arg 2 is: {{arg2}}

{%
    -- ...and now end the function, which completes the partial code block and
    -- thereby completes the definition of 'mymacro()'
end
%}

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

* [`assert`](https://www.lua.org/manual/5.4/manual.html#pdf-assert)
* [`debug.traceback`](https://www.lua.org/manual/5.4/manual.html#pdf-debug.traceback)
* [`error`](https://www.lua.org/manual/5.4/manual.html#pdf-error)
* [`ipairs`](https://www.lua.org/manual/5.4/manual.html#pdf-ipairs)
* [`math`](https://www.lua.org/manual/5.4/manual.html#6.7)
* [`next`](https://www.lua.org/manual/5.4/manual.html#pdf-next)
* [`os.date`](https://www.lua.org/manual/5.4/manual.html#pdf-os.date), [`os.time`](https://www.lua.org/manual/5.4/manual.html#pdf-os.time)
* [`pairs`](https://www.lua.org/manual/5.4/manual.html#pdf-pairs)
* [`pcall`](https://www.lua.org/manual/5.4/manual.html#pdf-pcall)
* [`rawequal`](https://www.lua.org/manual/5.4/manual.html#pdf-rawequal)
* [`rawget`](https://www.lua.org/manual/5.4/manual.html#pdf-rawget)
* [`rawlen`](https://www.lua.org/manual/5.4/manual.html#pdf-rawlen)
* [`rawset`](https://www.lua.org/manual/5.4/manual.html#pdf-rawset)
* [`select`](https://www.lua.org/manual/5.4/manual.html#pdf-select)
* [`string`](https://www.lua.org/manual/5.4/manual.html#6.4)
* [`table`](https://www.lua.org/manual/5.4/manual.html#6.6)
* [`tonumber`](https://www.lua.org/manual/5.4/manual.html#pdf-tonumber)
* [`tostring`](https://www.lua.org/manual/5.4/manual.html#pdf-tostring)
* [`type`](https://www.lua.org/manual/5.4/manual.html#pdf-type)
* [`utf8`](https://www.lua.org/manual/5.4/manual.html#6.5)

### `dump(val)`

Returns a string representation of `val` which can be of any type, expanding data structures as much as possible.

### `eval(text, [pathHint])`

Evaluates `text` and expands any special blocks. Does not return anything, the results of the evaluation (if any) are output directly.

Optionally, a `pathHint` may be supplied. This is used in error messages.

`text` shares the same environment (ie, variables) as the caller, with one additional nuance: `local` variables in scope at the call site are _also_ visible to `text`, however assigning to such a variable inside `text` will not alter what the original `local` variable is set to (whereas if the original was not `local`, it would).

Example:

```
{% var = "me!" %}
{% eval("Hello from {{ var }}") %}

--> Hello from me!
```

### `include(path)`

Includes another template file into this template, as if the contents of the file at `path` were passed to [`eval()`](#evaltext-pathhint).

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

### `render([path], [text])`

Like [`include(path)`](#includepath) or [`eval(text)`](#evaltext-pathhint) but the resulting data is returned as a result rather than being written to the output. If only `path` is specified, the text to render is read from `path`. If `text` is specified, behaves like [`eval()`](#evaltext-pathhint) and `path` is considered a hint solely for error messages. At least one of `path` or `text` must be specified.

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
