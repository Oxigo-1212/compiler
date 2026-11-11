# Statements

Rules that derive from `Stmt`.

## loop-stmt

Source: `@doc: loop-stmt` in `src/specs/parser.y`

### Definition

`LoopStmt` is `while Expr Block`, `loop Block`, `for ID in Expr Block`, `break ;` or `continue ;`. These are statements only: they need no `;` (except `break` and `continue`) and cannot appear where an expression is expected, so `let x: int = while true { };` is a syntax error.

### Intention

Loops are iteration, so they return no value. `break` and `continue` return nothing either, and the language has no `break value` feature (learner decision). `return` stays an expression, see [simple-op](expressions.md#simple-op).

Since: 2026-11-11
