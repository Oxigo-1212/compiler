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

```rust
If -> Result<Expr, ()>:
      'if' Expr Block { Ok(Expr::If(cond, then, None)) }
    | 'if' Expr Block 'else' Block { Ok(Expr::If(cond, then, Some(else_block))) }
    | 'if' Expr Block 'else' If { Ok(Expr::If(cond, then, Some(else_if))) }
    ;
```

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

```rust
Block -> Result<Block, ()>:
      '{' Stmts '}' { ... a last Stmt::Expr becomes the tail ... }
    | '{' Stmts SimpleOperation '}' { Ok(Block::new($2?, Some(Box::new($3?)))) }
    ;
```

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

- `{ }` replaces `begin ... end` from the original UPL.
- The value is the last line without `;`. Because `if` is an expression, a trailing `if` gives the block its value.
- Open, for the type checker: whether a block-like in the middle of a block may have a value. Rust requires that it has none.

### AST representation (2026-11-15)

A block is a list of statements plus a separate **tail**: the final expression with no `;`, which is the block's value.

```rust
struct Block { stmts: Vec<Stmt>, tail: Option<Box<Expr>> }   // tail None: no value
Expr::Block(Block)   // a block used as a value
```

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

A block-like expression ends in `}`, so it needs no `;`, even in the middle of a block. When the parser reads one, it cannot yet tell whether more statements follow. It stores the expression as `Stmt::Expr`, and the block action moves it into the tail if it turns out to be last.

Any other expression, such as `a - b`, needs a `;` in the middle of a block. Without a `;`, the only valid place for it is the end, so the grammar puts it in the tail slot at once, and it never becomes `Stmt::Expr`.

| Source | `stmts` | `tail` |
|:---|:---|:---|
| `{ a + b; a - b }` | `Semi(a + b)` | `a - b` (grammar tail slot) |
| `{ a + b; if c {1} else {2} }` | `Semi(a + b)` | the `if` (moved from `Stmt::Expr`) |
| `{ if c {1} else {2} x }` | `Expr(if ...)` | `x` |
| `{ { f(); } }` | (empty) | the inner block (moved from `Stmt::Expr`) |
| `{ a - b c }` | — | syntax error: `a - b` is not last and has no `;` |

Since: 2026-11-11
