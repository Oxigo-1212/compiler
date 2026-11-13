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

### Intention

Placing literals and names at the bottom lets them appear anywhere an expression can (`[1, 2][0]`, `.{ x: 3 }.x`). Whether a plain variable `x` becomes a one-segment `Path` or a separate `Var` node in the AST is not decided yet. Other choices: not yet reviewed.

Since: 2026-11-11 (explanation added 2026-11-13)

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

Rust-style literal, chosen by the learner. Elements use their own `ElementList` rule rather than sharing `ArgList` with calls: the grammar should read by meaning (learner decision). Empty `[]` is forbidden in the grammar (learner decision). The type `[int, 0]` is invalid; zero-length collections will use a vector type, planned (learner decision). The grammar still accepts `[int, 0]`; the type checker must reject it.

Since: 2026-11-11
