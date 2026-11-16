# UPL grammar in plain words

One sentence per rule, from the whole program down to single tokens. Each link goes to the full Definition and Intention in `docs/spec/`, which are traced to the source by `@doc` tags.

## Program and items

- **Program** — A program is a list of one or more items; an empty file is an error. [items](spec/items.md#items)
- **Function** — `fn name(params) -> Type { body }` declares a function; the return type is optional, and a function may also be declared inside a block. [function](spec/items.md#function)
- **Self parameter** — A function whose first parameter is `self` is a method; without it the function is static. [method-self](spec/items.md#method-self)
- **Struct** — `struct Name { field: Type, ... }` declares a struct type with zero or more typed fields. [struct](spec/items.md#struct)
- **Impl, use, mod** — `impl Name { fns }` adds methods to a type, `use a::b;` imports a name, and `mod m;` declares a module stored in another file. [impl-use-mod](spec/items.md#impl-use-mod)

## Shared by items and statements

- **Let** — `let name: Type = value;` declares a variable with a required type and value; `let mut` makes it changeable. [let](spec/shared.md#let)
- **Block** — `{ ... }` holds statements, and its last expression without `;` is the block's value. [block](spec/shared.md#block)
- **Type** — A type is `int`, `bool`, `str`, a struct name, or a fixed-size array such as `[int, 3]`. [type](spec/shared.md#type)

## Statements

- **Loops** — `while`, `loop`, `for x in range`, `break` and `continue` are statements and produce no value. [loop-stmt](spec/statements.md#loop-stmt)
- **Assignment** — `a, b = 1, 2;` stores each value into the target at the same position, and is a statement, not a value. [assign](spec/statements.md#assign)

## Expressions

- **Block-like** — `if` and `{ }` blocks need no `;` when used as a statement and are never operands. [block-like](spec/expressions.md#block-like)
- **If** — `if cond { } else { }` is an expression, with optional `else` and `else if` chains. [if](spec/expressions.md#if)
- **Simple operations** — Other expressions are operator expressions, a range `a..b`, or `return` with an optional value. [simple-op](spec/expressions.md#simple-op)
- **Precedence** — Operators bind from loosest to tightest: `..`, `||`, `&&`, comparisons, `+ -`, `* / %`, unary `- !`, then calls, fields and indexing. [expr-precedence](spec/expressions.md#expr-precedence)
- **Postfix and primary** — The smallest expressions are names, literals, `self` and parentheses, followed by any number of calls `f()`, fields `.x` and indexes `[i]`. [postfix-primary](spec/expressions.md#postfix-primary)
- **Struct literal** — `.{ x: 1, y: 2 }` creates a struct value whose type comes from the context. [struct-literal](spec/expressions.md#struct-literal)
- **Array literal** — `[1, 2, 3]` creates an array value with at least one element. [array-literal](spec/expressions.md#array-literal)

## Tokens

- **Skipped text** — Whitespace, `//` line comments and `/* */` block comments are ignored. [lex-skip](spec/lexer.md#lex-skip)
- **Keywords** — Words such as `fn`, `let` and `if` are reserved and can't be used as names. [lex-keywords](spec/lexer.md#lex-keywords)
- **Names and integers** — A name is letters, digits and `_` not starting with a digit, and an integer is a run of digits. [lex-ident-int](spec/lexer.md#lex-ident-int)
- **Operators** — The symbols are one- or two-character tokens such as `+`, `==`, `->` and `::`. [lex-operators](spec/lexer.md#lex-operators)
- **Strings** — A string is text between double quotes on one line, with backslash escapes. [lex-string](spec/lexer.md#lex-string)
