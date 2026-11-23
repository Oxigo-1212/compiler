# UPL grammar in plain words

One sentence per rule, from the whole program down to single tokens. Each link goes to the full section in `docs/spec/`.

## Levels of the language

The grammar has four levels. Each level contains the one below it.

```
Item        fn, struct, impl, use, export, mod, let, const, static   (top level of a file)
  └─ Function body = Block
       └─ Stmt     let, expr;, if/block, loops, assign, nested fn, ;
            └─ Expr        BlockLike | SimpleOperation
                 ├─ SimpleOperation   binary, unary, range, return
                 └─ BlockLike         if, { ... }
                       └─ Block ── contains Stmts again
```

1. **Operation.** `SimpleOperation` is a binary or unary operation, a range `a..b`, or `return`.
2. **Expression.** `Expr` is `SimpleOperation | BlockLike`. A block-like is an `if` or a `{ }` block.
3. **Statement.** A statement is one step inside a block. Most statements wrap an expression: `SimpleOperation ';'` is `Stmt::Semi`, and a block-like without `;` is `Stmt::Expr`. `let`, loops and assignment are also statements.
4. **Item.** An item is a declaration at the top level of a file. Statements reach the top level only inside an item, through a function body. A statement or expression on its own at the top level is a syntax error.

The levels are recursive, not a strict ladder:

- A block is an expression that holds statements, so an expression can contain statements.
- A statement can hold an item: a function declared inside a block (`Stmt -> Function`).
- `let` is both an item (top level) and a statement (inside a block). Both use one `Let` struct.

## Program and items

- **Program** — A program is a list of one or more items, the declarations at the top level of a file; statements and expressions are not allowed there, and an empty file is an error. [Program](spec/items.md#program)
- **Function** — `fn name(params) -> Type { body }` declares a function; the return type is optional, and a function may also be declared inside a block. [Function](spec/items.md#function)
- **Self parameter** — A function whose first parameter is `self` is a method; without it the function is static. [Self parameter](spec/items.md#self-parameter)
- **Struct** — `struct Name { field: Type, ... }` declares a struct type with zero or more typed fields. [Struct](spec/items.md#struct)
- **Visibility** — `pub` before a top-level item, a method or a field makes it public; without `pub` it is private to its module and the modules below it. A top-level `let` is never public. [Visibility](spec/items.md#visibility)
- **Const and static** — `const X: T = v;` declares a module-level constant and `static [mut] X: T = v;` one program-wide location; both may be `pub`. [Const and static](spec/items.md#const-and-static)
- **Impl, use, export, mod** — `impl Name { fns }` adds methods to a type, `use a::b;` imports a name, `export a::b;` re-exports it, `as` renames either, and `mod m;` declares a module stored in another file. [Impl](spec/items.md#impl), [Use, export and mod](spec/items.md#use-export-and-mod)

## Statements

- **Statement** — A statement is one step inside a block, such as a declaration, an assignment, a loop or an expression followed by `;`, and gives no value. [Statement](spec/statements.md#statement)
- **Let** — `let name: Type = value;` declares a variable with a required type and value; `let mut` makes it changeable. [Let](spec/statements.md#let)
- **Loops** — `while`, `loop`, `for x in range`, `break` and `continue` are statements and produce no value. [Loops](spec/statements.md#loops)
- **Assignment** — `a, b = 1, 2;` stores each value into the target at the same position, and is a statement, not a value. [Assignment](spec/statements.md#assignment)

## Expressions

- **Block-like** — `if` and `{ }` blocks need no `;` when used as a statement and are never operands. [Block-like](spec/expressions.md#block-like)
- **If** — `if cond { } else { }` is an expression, with optional `else` and `else if` chains. [If](spec/expressions.md#if)
- **Block** — `{ ... }` holds statements, and its last expression without `;` is the block's value. [Block](spec/expressions.md#block)
## Operations

- **Simple operations** — Other expressions are operator expressions, a range `a..b`, or `return` with an optional value. [Simple operation](spec/operations.md#simple-operation)
- **Precedence** — Operators bind from loosest to tightest: `..`, `||`, `&&`, comparisons, `+ -`, `* / %`, unary `- !`, then calls, fields and indexing. [Binary operation](spec/operations.md#binary-operation)
- **Postfix and primary** — The smallest expressions are names, literals, `self` and parentheses, followed by any number of calls `f()`, fields `.x` and indexes `[i]`. [Primary](spec/operations.md#primary), [Postfix](spec/operations.md#postfix)
- **Struct literal** — `.{ x: 1, y: 2 }` creates a struct value whose type comes from the context. [Struct literal](spec/operations.md#struct-literal)
- **Array literal** — `[1, 2, 3]` creates an array value with at least one element. [Array literal](spec/operations.md#array-literal)

## Types

- **Type** — A type is `int`, `bool`, `str`, a struct name or path such as `root::geo::Point`, or a fixed-size array such as `[int, 3]`. [Type](spec/types.md#type)

## Tokens

- **Skipped text** — Whitespace, `//` line comments and `/* */` block comments are ignored. [Skipped text](spec/lexer.md#skipped-text)
- **Keywords** — Words such as `fn`, `let` and `if` are reserved and can't be used as names. [Keywords](spec/lexer.md#keywords)
- **Names and integers** — A name is letters, digits and `_` not starting with a digit, and an integer is a run of digits. [Names and integers](spec/lexer.md#names-and-integers)
- **Operators** — The symbols are one- or two-character tokens such as `+`, `==`, `->` and `::`. [Operators](spec/lexer.md#operators)
- **Strings** — A string is text between double quotes on one line, with backslash escapes. [Strings](spec/lexer.md#strings)
