# Shared rules

Rules used by more than one group. Each entry lists its users.

## let

Source: `@doc: let` in `src/specs/parser.y`

Used by: `Item` (global `let`) and `Stmt` (local `let`).

### Definition

`let ID : Type = Expr ;` or `let mut ID : Type = Expr ;`. The type annotation and initial value are both required. Used both at top level and inside blocks.

### Intention

Type annotation required for now; inference and static type checking come later (project requirement). Required initialiser: not yet reviewed.

Since: 2026-11-11

## block

Source: `@doc: block` in `src/specs/parser.y`

Used by: `Function` and `Impl` bodies, `If` branches, loop bodies in `LoopStmt`, and `BlockLike` (a block is itself an expression). It contains `Stmts`.

### Definition

`{ Stmts }` or `{ Stmts SimpleOperation }`. A statement is a `Let`, an expression followed by `;`, a block-like expression, a loop statement, or a lone `;`. The grammar allows a final `SimpleOperation` without `;`, as in `{ x = 1; 0 }`. Treating it as the block's value is planned for the AST stage; the grammar only checks the shape.

A trailing `if` (as in `{ if b { 1 } else { 2 } }`) parses as a statement, not as the tail. Learner decision: a trailing `if` should be the block's value, because `if` is an expression. It is implemented at the AST stage, not in the grammar: when building a block node, a last statement that is an `if` (or block) with no `;` becomes the tail (learner decision). Doing it in the grammar would cause a reduce/reduce conflict.

### Intention

`{ }` is a block, replacing `begin ... end`; its value is the last line without `;` (learner decision, from `if` being an expression).

Since: 2026-11-11

## type

Source: `@doc: type` in `src/specs/parser.y`

Used by: `Param`, `StructFields`, `Let`, and the `->` return type of `Function`.

### Definition

`Type` is `int`, `bool`, `str`, a name (`ID`, for example a struct name), or an array type `[Type, INTEGER]` such as `[int, 3]` or `[[int, 2], 4]`. No generics or references yet.

### Intention

Not yet reviewed.

Since: 2026-11-11
