# Statements

Rules that derive from `Stmt`.

## loop-stmt

Source: `@doc: loop-stmt` in `src/specs/parser.y`

### Definition

`LoopStmt` is `while Expr Block`, `loop Block`, `for ID in Expr Block`, `break ;` or `continue ;`. These are statements only: they need no `;` (except `break` and `continue`) and cannot appear where an expression is expected, so `let x: int = while true { };` is a syntax error.

### Intention

Loops are iteration, so they return no value. `break` and `continue` return nothing either, and the language has no `break value` feature (learner decision). `return` stays an expression, see [simple-op](expressions.md#simple-op).

### AST representation (2026-11-15)

`Stmt::While(cond, body)`, `Stmt::Loop(body)`, `Stmt::For(name, iterable, body)`, `Stmt::Break`, `Stmt::Continue`. The body is the whole `Block` expression; the loop ignores its tail value (learner decision). The `for` variable is a `String`, like the name in `let`. Not checked here: that `break`/`continue` appear inside a loop, and whether a body may have a tail value.

Since: 2026-11-11

## assign

Source: `@doc: assign` in `src/specs/parser.y`

### Definition

`Targets = Values ;` where `Targets` is one or more `Postfix` and `Values` is one or more `Expr`, both comma-separated: `x = 1;`, `p.x = 3;`, `a, b = b, a;`. The left side is `Postfix`, so `a + c = b` is a syntax error. Assignment is a statement, so `a = b = 1` is a syntax error. The grammar accepts any counts on each side.

### Intention

Assignment is an action, not a value: `3` is an expression, `x = 3` is not (learner decision). Lists follow Go: values pair up with targets, and one value is copied to every target (`a, b = 1`, learner decision). A later pass must check that each target is a place (variable, field or index; `f() = 1` parses) and the counts: valid only when there is one value or as many values as targets; any other count is a semantic error (learner decision). Open: whether a broadcast value is evaluated once, and how broadcast fits future multi-return functions.

Since: 2026-11-15
