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

Assignment is an action, not a value: `3` is an expression, `x = 3` is not (learner decision). Lists follow Go: value `i` goes to target `i`, and the counts must be equal (learner decision). An index without a partner is a semantic error, so `a, b = 1` and `a, b = 1, 2, 3` are rejected. Broadcast (one value copied to every target) was dropped on 2026-11-16.

### AST representation (2026-11-16)

`Stmt::Assign(targets, values)`, both `Vec<Expr>`, kept exactly as written (Go's `AssignStmt` does the same). The parser does not pair them up: pairing in the action would hide a count mismatch from the later pass and break swaps.

Checked by a later semantic pass, not here:
- each target is a place (variable, field or index; `f() = 1` parses);
- `targets.len() == values.len()`.

Evaluation order (for code generation): evaluate all values first, then store them into the targets left to right, so `a, b = b, a` swaps. Storing pair by pair would give `a = b; b = a` and both would end up equal.

Since: 2026-11-15
