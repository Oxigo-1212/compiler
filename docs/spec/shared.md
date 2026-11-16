# Shared rules

Rules used by more than one group. Each entry lists its users.

## let

Source: `@doc: let` in `src/specs/parser.y`

Used by: `Item` (global `let`) and `Stmt` (local `let`).

### Definition

`let ID : Type = Expr ;` or `let mut ID : Type = Expr ;`. The type annotation and initial value are both required. Used both at top level and inside blocks.

### Intention

Type annotation required for now; inference and static type checking come later (project requirement). Required initialiser: not yet reviewed.

### AST representation (2026-11-16)

`struct Let { name: String, tpe: Type, value: Expr, mutability: Mut }`, shared by `Stmt::Declaration(Let)` and `ItemKind::Let(Let)`. The `Let` rule returns `Let`, and each parent wraps it. A shared struct, not `ItemKind::Let(Stmt)`, so a top-level item can only hold a declaration (learner decision, same reason as `Block`).

Since: 2026-11-11

## block

Source: `@doc: block` in `src/specs/parser.y`

Used by: `Function` and `Impl` bodies, `If` branches, loop bodies in `LoopStmt`, and `BlockLike` (a block is itself an expression). It contains `Stmts`.

### Definition

`{ Stmts }` or `{ Stmts SimpleOperation }`. A statement is a `Let`, an expression followed by `;`, a block-like expression, a loop statement, an assignment, a nested function, or a lone `;`. The grammar allows a final `SimpleOperation` without `;`, as in `{ x = 1; 0 }`; the block action makes it the block's value (the tail), see AST representation below.

A trailing `if` (as in `{ if b { 1 } else { 2 } }`) parses as a statement, not as the tail. Learner decision: a trailing `if` should be the block's value, because `if` is an expression. It is implemented at the AST stage, not in the grammar: when building a block node, a last statement that is an `if` (or block) with no `;` becomes the tail (learner decision). Doing it in the grammar would cause a reduce/reduce conflict.

### Intention

`{ }` is a block, replacing `begin ... end`; its value is the last line without `;` (learner decision, from `if` being an expression).

### AST representation (2026-11-15)

Implemented. A block is a list of statements plus a separate **tail**: the final expression with no `;`, which is the block's value.

```rust
struct Block { stmts: Vec<Stmt>, tail: Option<Box<Expr>> }   // tail None: no value
Expr::Block(Block)   // a block used as a value
```

`Block` is a separate struct (2026-11-16) so a function body can be typed `Block`: the type guarantees the body is a block, so the semantic pass does not have to check it (learner decision, for strictness). The `Block` rule returns `Block`; `if` branches, loop bodies and `BlockLike` wrap it in `Expr::Block`.

The tail is a separate field, not the last list item, so the parser answers "what is this block's value?" once and every later pass reads the field (learner decision, over rustc's one-list form). `{ }` has an empty list and no tail. A block's scope is not stored: name resolution opens a scope when it enters a `Block` node.

An expression in the list is wrapped in a statement variant (an *expression statement*), because a `Vec` holds one type. Two variants record whether a `;` followed, as in rustc (learner decision):

| Source | Variant | Value |
|---|---|---|
| `f();` | `Stmt::Semi(e)` | Discarded |
| `if a { g(); }`, `{ ... }` (block-like, no `;`) | `Stmt::Expr(e)` | Discarded in the middle; at the end, moved into the tail |
| Final `SimpleOperation` (`{ x = 1; 0 }`) | — | Becomes the tail directly |

The block action builds the tail: for `{ Stmts SimpleOperation }` the tail is the `SimpleOperation`; for `{ Stmts }` a last `Stmt::Expr` is moved into the tail, otherwise the tail is `None`. A `;` after a block-like parses as a separate empty statement, so `{ if a {1} else {2}; }` has no tail.

`Stmt::Empty` represents a lone `;`. `Stmt::Item` holds a nested item, such as a function declared inside a block. Open, for the type checker: whether a block-like in the middle of a block may have a value (Rust requires none).

Since: 2026-11-11

## type

Source: `@doc: type` in `src/specs/parser.y`

Used by: `Param`, `StructFields`, `Let`, and the `->` return type of `Function`.

### Definition

`Type` is `int`, `bool`, `str`, a name (`ID`, for example a struct name), or an array type `[Type, INTEGER]` such as `[int, 3]` or `[[int, 2], 4]`. No generics or references yet.

### Intention

Not yet reviewed.

Since: 2026-11-11
