# Expressions

Rules that derive from `Expr`.

## block-like

Source: `@doc: block-like` in `src/specs/parser.y`

### Definition

`BlockLike` is `If | Block`. Loops are statements, see [loop-stmt](statements.md#loop-stmt). As a statement it needs no `;`. It is never an operand: `if a {} - x` parses as two statements, not a subtraction.

### Intention

Keeping block-like expressions out of operator positions removes a grammar ambiguity. Not yet reviewed.

Since: 2026-11-11

## if

Source: `@doc: if` in `src/specs/parser.y`

### Definition

`if Expr Block`, optionally `else Block` or `else If` (giving `else if` chains). No parentheses or `then` are required. Loops are not expressions, see [loop-stmt](statements.md#loop-stmt).

### Intention

`if` is an expression, Rust-style, chosen after weighing benefits against cost (learner decision). Planned type-checker rule (learner decision): an `if` without `else` used as a value must have type `bool`, and gives `false` when the condition is false; any other type is a compile error (add `else`). As a statement it is always allowed. Dropping `then` and parentheses: not yet reviewed.

Since: 2026-11-11

## simple-op

Source: `@doc: simple-op` in `src/specs/parser.y`

### Definition

Expressions that are not block-like: a binary expression, assignment `a = e` (right-associative, so `a = b = 1`), range `a .. b` (does not chain), `return` with optional value. `break` and `continue` are statements, see [loop-stmt](statements.md#loop-stmt).

### Intention

Not yet reviewed.

Since: 2026-11-11

## expr-precedence

Source: `@doc: expr-precedence` in `src/specs/parser.y`

### Definition

From lowest to highest: `=`, `..`, `||`, `&&`, comparisons `== != < <= > >=`, `+ -`, `* / %`, unary `- !`, postfix. The `%left`/`%nonassoc` lines set the binary levels; later lines bind tighter. Comparisons are `%nonassoc`, so `a < b < c` is a syntax error.

This tag marks two places: the precedence declarations at the top, and the `BinaryOperation` rule.

### Intention

`*` above `+` and non-chaining comparisons come from the original UPL requirements. Other levels: not yet reviewed.

Since: 2026-11-11

## postfix-primary

Source: `@doc: postfix-primary` in `src/specs/parser.y`

### Definition

Unary `-` and `!` apply to a postfix expression. Postfix forms chain left to right: call `f(args)`, field `.ID`, index `[Expr]`, as in `a::b(i)[0].c`. Primary is a path `a::b`, an integer, a string (`STRING`, see [lex-string](lexer.md#lex-string)), `true`, `false`, `self`, `( Expr )`, or a literal ([struct-literal](expressions.md#struct-literal), [array-literal](expressions.md#array-literal)). Arguments allow a trailing comma.

### Intention

Not yet reviewed.

Since: 2026-11-11

## struct-literal

Source: `@doc: struct-literal` in `src/specs/parser.y`

### Definition

`.{ ID: Expr, ... }` creates a struct value, for example `let p: P = .{ x: 3, y: true };`. A trailing comma is allowed. `.{ }` is the value of a struct with no fields. The literal names no type: its type comes from context (a `let` annotation, parameter or return type), which the type checker must supply.

### Intention

Field access (`p.x`) and calls (`P::new()`) need an existing value, so the language needs one built-in way to create one; constructors are built on top of it (learner decision). The leading `.` follows Zig: it doesn't clash with blocks or other syntax (`.{ }` vs `{ }`), and the learner found it the only plausible form for struct initialisation; fields use Rust style `x: 3`, matching struct declarations (learner decision).

Since: 2026-11-11

## array-literal

Source: `@doc: array-literal` in `src/specs/parser.y`

### Definition

`[Expr, ...]` creates an array value, for example `let a: [int, 3] = [1, 2, 3];`. At least one element; trailing comma allowed. `[]` is a syntax error. Matching the element count to the type is left to the type checker.

### Intention

Rust-style literal, chosen by the learner. Empty `[]` is forbidden in the grammar (learner decision). The type `[int, 0]` is invalid; zero-length collections will use a vector type, planned (learner decision). The grammar still accepts `[int, 0]`; the type checker must reject it.

Since: 2026-11-11
