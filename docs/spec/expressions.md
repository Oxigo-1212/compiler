# Expressions

Purpose: defines the expression rules of UPL and the abstract syntax tree (AST) nodes they build.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-17.

Level 2: expressions. An expression is anything that gives a value: an operation, an `if` or a block. The rules are in `src/specs/parser.y`.

## Expression

### Intuition

An expression computes a value. Most expressions are operations, such as `a + b`. Some end in a block and give the value of that block, such as `if c { 1 } else { 2 }`.

### Definition

```rust
Expr -> Result<Expr, ()>:
      BlockLike { $1 }
    | SimpleOperation { $1 }
    ;
```

### Example

```text
a + b                     // SimpleOperation
if c { 1 } else { 2 }     // BlockLike
{ let t: int = a; t * 2 } // BlockLike
```

### Notions used

- **`SimpleOperation`** is an expression that does not end in a block. See [Operations](operations.md).
- **`BlockLike`** is an `if` or a `{ }` block. See [Block-like](#block-like).

Since: 2026-11-11

## Block-like

### Intuition

A block-like expression ends with `}`. The `}` already shows where it ends, so it needs no `;` when it stands as a statement.

### Definition

```rust
BlockLike -> Result<Expr, ()>:
      If { $1 }
    | Block { Ok(Expr::Block($1?)) }
    ;
```

- As a statement, a block-like needs no `;`.
- A block-like is never an operand: `if a {} - x` parses as two statements, not as a subtraction.
- Loops are not block-like expressions. They are statements, see [Loops](statements.md#loops).

### Example

```text
if a { f(); }     // statement, no `;`
{ g(); }          // nested block, no `;`
if a {} - x       // two parts: the statement `if a {}`, then `-x`
```

### Design reasons

- Keeping block-like expressions out of operator positions removes a grammar ambiguity in `if a {} -x`.
- Other choices: not yet reviewed.

Since: 2026-11-11

## If

### Intuition

`if` chooses between two blocks by a condition. Because `if` is an expression, the chosen block's value is the value of the whole `if`.

### Definition

<<<<<<< HEAD
```rust
If -> Result<Expr, ()>:
      'if' Expr Block { Ok(Expr::If(cond, then, None)) }
    | 'if' Expr Block 'else' Block { Ok(Expr::If(cond, then, Some(else_block))) }
    | 'if' Expr Block 'else' If { Ok(Expr::If(cond, then, Some(else_if))) }
    ;
```
=======
Expressions that are not block-like: a binary expression, range `a .. b` (does not chain), `return` with optional value. `break`, `continue` and assignment are statements, see [loop-stmt](statements.md#loop-stmt) and [assign](statements.md#assign).
>>>>>>> main

- `else` is optional.
- `else If` gives `else if` chains.
- The condition needs no parentheses and no `then`.

### Example

```text
if x > 0 { f(x); }
let m: int = if a > b { a } else { b };
if x < 0 { neg(); } else if x == 0 { zero(); } else { pos(); }
```

### Notions used

- **`Block`** is a `{ }` list of statements with an optional value at the end. See [Block](#block).

### Design reasons

- `if` is an expression, as in Rust, so it can give a value.
- Planned type-checker rule: an `if` without `else` that is used as a value must have type `bool`, and gives `false` when the condition is false. Any other type is a compile error, and the fix is to add `else`. As a statement, an `if` without `else` is always allowed.
- Dropping `then` and the parentheses: not yet reviewed.

### AST representation

`Expr::If(condition, then_branch, else_branch)`. Each branch is a `Block` wrapped as `Expr::Block`. `else_branch` is `None` when there is no `else`; for `else if`, it holds the inner `Expr::If`.

Since: 2026-11-11

## Block

### Intuition

A block is a list of statements between `{` and `}`. Its value is the last expression without a `;`, if there is one. Because a block holds statements, a block is where the expression level contains the statement level again.

### Definition

<<<<<<< HEAD
```rust
Block -> Result<Block, ()>:
      '{' Stmts '}' { ... a last Stmt::Expr becomes the tail ... }
    | '{' Stmts SimpleOperation '}' { Ok(Block::new($2?, Some(Box::new($3?)))) }
    ;
```
=======
From lowest to highest: `..`, `||`, `&&`, comparisons `== != < <= > >=`, `+ -`, `* / %`, unary `- !`, postfix. The `%left`/`%nonassoc` lines set the binary levels; later lines bind tighter. Comparisons are `%nonassoc`, so `a < b < c` is a syntax error.
>>>>>>> main

- `{ Stmts SimpleOperation }` gives a block whose value is the final `SimpleOperation`, as in `{ x = 1; 0 }`.
- A trailing `if` or block, as in `{ if b { 1 } else { 2 } }`, parses as a statement, not as the final value. The block action then moves it into the value slot. This happens while building the AST, because doing it in the grammar would cause a reduce/reduce conflict.
- A `;` after a block-like is a separate empty statement, so `{ if a { 1 } else { 2 }; }` has no value.

A block is used by function and impl bodies, `if` branches, loop bodies and `BlockLike`.

### Example

```text
{ }                          // no statements, no value
{ f(); g(); }                // no value
{ x = 1; 0 }                 // value: 0
{ if b { 1 } else { 2 } }    // value: the if
```

### Notions used

- **`Stmts`** is a list of zero or more statements. See [Statement](statements.md#statement).
- **`SimpleOperation`** is an expression that does not end in a block. See [Simple operation](operations.md#simple-operation).

### Design reasons

<<<<<<< HEAD
- `{ }` replaces `begin ... end` from the original UPL.
- The value is the last line without `;`. Because `if` is an expression, a trailing `if` gives the block its value.
- Open, for the type checker: whether a block-like in the middle of a block may have a value. Rust requires that it has none.
=======
These rules are the bottom of the expression chain. Each level is built from the one to its right:

```text
SimpleOperation → BinaryOperation → UnaryOperation → Postfix → Primary
   (= .. return)    (+ * < && ...)       (- !)       (call . [])  (atoms)
     loosest                                                      tightest
```

**Operator positions.** An operator can come before its operand (prefix: `-x`, `!b`, rule `UnaryOperation`), between two operands (infix: `a + b`, rule `BinaryOperation`), or after its operand (postfix: rule `Postfix`).

**Postfix** has three forms, applied after a value:

| Form | Alternative | Example |
|:---|:---|:---|
| Call | `Postfix '(' Args ')'` | `f(1, 2)` |
| Field | `Postfix '.' 'ID'` | `p.x` |
| Index | `Postfix '[' Expr ']'` | `a[0]` |

The rule is left-recursive, so postfix forms chain left to right, each applying to the result so far. `a::b(i)[0].c` is the path `a::b`, called with `i`, indexed with `0`, then field `c`:

```text
Field .c
  └─ Index [0]
       └─ Call (i)
            └─ Path a::b
```

Postfix binds tightest of all operators: `-a.b` is `-(a.b)`, and `x + f(y)` is `x + (f(y))`. A method call `p.get()` has no rule of its own: it is a field access followed by a call.

**Primary** holds the atoms: complete values that need no operator.

| Group | Alternatives | Example |
|:---|:---|:---|
| Names | `Path`, `'self'` | `x`, `a::b`, `self` |
| Literals | `'INTEGER'`, `'STRING'`, `'true'`, `'false'` | `42`, `"hi"` ([lex-string](lexer.md#lex-string)), `true` |
| Grouping | `'(' Expr ')'` | `(a + b)` |
| Struct literals | `'.' '{' FieldInits '}'` and variants | `.{ x: 3 }` ([struct-literal](expressions.md#struct-literal)) |
| Array literals | `'[' ElementList ']'` and variants | `[1, 2, 3]` ([array-literal](expressions.md#array-literal)) |

`( Expr )` turns any expression back into an atom, which is how parentheses override precedence: in `(a + b) * c`, `(a + b)` is one primary. The parentheses leave no AST node; the action passes the inner value up. Call arguments (`Args`) allow a trailing comma and may be empty.

**What a primary carries into the AST.** Each alternative holds only what is written at that spot in the source, minus punctuation:

| Alternative | Source | Data |
|:---|:---|:---|
| `'INTEGER'` | `42` | the value |
| `'STRING'` | `"hi"` | the text |
| `'true'`, `'false'` | `true` | the boolean |
| `'self'` | `self` | nothing: only "self appears here" |

A literal carries no name. In `let x: int = 42;` the name `x` belongs to the `Let` node, and the literal `42` holds only its value; the same literal could appear in `f(42)` or `[42]` with no name at all:

```text
Let { name: "x", ty: Int32, value: Int(42) }
```

`self` carries no data because the parser cannot know which object it refers to (that depends on the call, `p.get()` vs `q.get()`, at run time). A later pass checks that `self` is inside a method and gives it that `impl`'s struct type. Position (where a literal is, for error messages) is a span, like `Path`'s span: location, not a name.
>>>>>>> main

### AST representation (2026-11-15)

<<<<<<< HEAD
A block is a list of statements plus a separate **tail**: the final expression with no `;`, which is the block's value.

```rust
struct Block { stmts: Vec<Stmt>, tail: Option<Box<Expr>> }   // tail None: no value
Expr::Block(Block)   // a block used as a value
```
=======
Placing literals and names at the bottom lets them appear anywhere an expression can (`[1, 2][0]`, `.{ x: 3 }.x`). Every name, including a plain variable `x`, is stored as `Expr::Path`: the parser has no scopes, so it cannot know whether a name is a variable, function or type; name resolution decides that later (learner decision, like rustc). Other choices: not yet reviewed.

Since: 2026-11-11 (explanation added 2026-11-13)
>>>>>>> main

- `Block` is a separate struct (2026-11-16), so a function body can be typed `Block`. The type guarantees that the body is a block, and the semantic pass does not have to check it. `if` branches, loop bodies and `BlockLike` wrap it in `Expr::Block`.
- The tail is a separate field, not the last list item, so the parser answers "what is this block's value?" once, and every later pass reads the field. rustc instead keeps one list and treats its last item as the value.
- `{ }` has an empty list and no tail.
- A block's scope is not stored. Name resolution opens a scope when it enters a `Block` node.

An expression inside the list is wrapped in a statement variant, because a `Vec` holds one type. Two variants record whether a `;` followed, as in rustc:

| Source | Variant | Value |
|:---|:---|:---|
| `f();` | `Stmt::Semi(e)` | Discarded |
| `if a { g(); }`, `{ ... }` (block-like, no `;`) | `Stmt::Expr(e)` | Discarded in the middle; at the end, moved into the tail |
| Final `SimpleOperation` (`{ x = 1; 0 }`) | — | Becomes the tail directly |

#### Why the tail has two paths

<<<<<<< HEAD
A block-like expression ends in `}`, so it needs no `;`, even in the middle of a block. When the parser reads one, it cannot yet tell whether more statements follow. It stores the expression as `Stmt::Expr`, and the block action moves it into the tail if it turns out to be last.

Any other expression, such as `a - b`, needs a `;` in the middle of a block. Without a `;`, the only valid place for it is the end, so the grammar puts it in the tail slot at once, and it never becomes `Stmt::Expr`.

| Source | `stmts` | `tail` |
|:---|:---|:---|
| `{ a + b; a - b }` | `Semi(a + b)` | `a - b` (grammar tail slot) |
| `{ a + b; if c {1} else {2} }` | `Semi(a + b)` | the `if` (moved from `Stmt::Expr`) |
| `{ if c {1} else {2} x }` | `Expr(if ...)` | `x` |
| `{ { f(); } }` | (empty) | the inner block (moved from `Stmt::Expr`) |
| `{ a - b c }` | — | syntax error: `a - b` is not last and has no `;` |
=======
**AST.** `Expr::FieldInits(Vec<FieldInit>)`; each `FieldInit` always has a name, a value and a span. `.{ }` is an empty `Vec`: "no fields" lives in the container, never as an empty element, so no field of `FieldInit` is optional. The trailing comma leaves no trace, so `.{ x: 3 }` and `.{ x: 3, }` give the same node.

### Intention

Field access (`p.x`) and calls (`P::new()`) need an existing value, so the language needs one built-in way to create one; constructors are built on top of it (learner decision). The leading `.` follows Zig: it doesn't clash with blocks or other syntax (`.{ }` vs `{ }`), and the learner found it the only plausible form for struct initialisation; fields use Rust style `x: 3`, matching struct declarations (learner decision). Empty structs kept after the learner questioned them (2026-11-14); in Rust they serve as namespaces, marker types and trait carriers, the last two need traits or generics.

Since: 2026-11-11

## array-literal

Source: `@doc: array-literal` in `src/specs/parser.y`

### Definition

`[Expr, ...]` creates an array value, for example `let a: [int, 3] = [1, 2, 3];`. At least one element; trailing comma allowed. `[]` is a syntax error. Matching the element count to the type is left to the type checker.

**AST.** `Expr::Array(Vec<Expr>)`. `ElementList` only collects elements (`Result<Vec<Expr>, ()>`); `Primary` wraps them in `Expr::Array`. The rule is left-recursive and each step pushes to the end, so the vector keeps source order, and each element is a full `Expr` tree (`[a + 1, [2, 3]]` nests). No size is stored; the element count is the vector's length.

**Trailing comma.** `[1, 2,]` gives the same node as `[1, 2]`. It is for convenience, not error detection: every line of a multi-line list has the same shape, so edits and diffs touch one line. `[,]` and `[1,,2]` remain syntax errors.

### Intention

Rust-style literal, chosen by the learner. Elements use their own `ElementList` rule rather than sharing `ArgList` with calls: the grammar should read by meaning (learner decision). Empty `[]` is forbidden in the grammar (learner decision). The type `[int, 0]` is invalid; zero-length collections will use a vector type, planned (learner decision). The grammar still accepts `[int, 0]`; the type checker must reject it. Not storing the size in the node: learner choice, reason not yet reviewed.
>>>>>>> main

Since: 2026-11-11
