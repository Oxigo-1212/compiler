# Statements

Purpose: defines the statement rules of UPL and the abstract syntax tree (AST) nodes they build.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-17.

Level 3: statements. A statement is one step inside a block. The rules are in `src/specs/parser.y`.

## Statement

### Intuition

A statement is one step inside a block: it does something, such as declaring a variable, assigning a value or running a loop. It gives no value to the code around it. The one exception is a block-like expression at the end of a block, which becomes the block's value.

### Definition

```rust
Stmt -> Result<Stmt, ()>:
      Let { Ok(Stmt::Declaration($1?)) }
    | SimpleOperation ';' { Ok(Stmt::Semi($1?)) }
    | BlockLike { Ok(Stmt::Expr($1?)) }
    | LoopStmt { $1 }
    | Function { Ok(Stmt::Item(ItemKind::Function(Vis::new(Visibility::Private, $1?)))) }  // nested fn: no `pub`
    | Targets '=' Values ';' { Ok(Stmt::Assign($1?, $3?)) }
    | ';' { Ok(Stmt::Empty) }
    ;
```

Each alternative is one kind of statement:

| Alternative | Kind of statement | AST node |
|:---|:---|:---|
| `Let` | Variable declaration | `Stmt::Declaration(Let)` |
| `SimpleOperation ';'` | Expression whose value is discarded | `Stmt::Semi(Expr)` |
| `BlockLike` | `if` or block, with no `;` | `Stmt::Expr(Expr)` |
| `LoopStmt` | Loop, `break` or `continue` | `Stmt::While`, `Stmt::Loop`, `Stmt::For`, `Stmt::Break`, `Stmt::Continue` |
| `Function` | Function declared inside a block | `Stmt::Item(ItemKind::Function(Vis<Function>))`, always `Private` |
| `Targets '=' Values ';'` | Assignment | `Stmt::Assign(Vec<Expr>, Vec<Expr>)` |
| `';'` | Empty statement | `Stmt::Empty` |

### Example

```text
fn main() {
    let mut x: int = 0;          // Let
    x = x + 1;                   // Targets '=' Values ';'
    f(x);                        // SimpleOperation ';'
    if x > 0 { f(x); }           // BlockLike
    while x < 10 { x = x + 1; }  // LoopStmt
    fn helper() { }              // Function
    ;                            // ';'
}
```

### Notions used

- **`Let`** declares a named variable with a type and a first value: `let x: int = 0;`. See [Let](#let).
- **`SimpleOperation`** is an expression that does not end in a block, such as `f(x)`, `a + b` or `return x`. It needs `;` to become a statement. See [Simple operation](operations.md#simple-operation).
- **`BlockLike`** is an `if` or a `{ }` block. It ends with `}`, so it needs no `;`. See [Block-like](expressions.md#block-like).
- **`LoopStmt`** repeats a block or jumps out of one. See [Loops](#loops).
- **`Function`** declares a function. See [Function](items.md#function).
- **`Targets` and `Values`** are the two comma-separated lists of an assignment. See [Assignment](#assignment).

### Design reasons

- `SimpleOperation` needs `;` but `BlockLike` does not. The closing `}` already marks where a block-like ends.
- The `;` is part of the `SimpleOperation ';'` rule, so `f();` is one `Stmt::Semi`. A `;` after a block-like is a separate `Stmt::Empty`. That is why `{ if a { 1 } else { 2 }; }` has no tail value. See [Block](expressions.md#block).
- A function inside a block is visible only in that block and cannot use the outer function's local variables, as in Rust.

Since: 2026-11-11

## Let

### Intuition

`let` gives a name to a value, with a type. Without `mut` the variable cannot change; with `mut` it can be assigned again. `let` is the one rule that is both a statement (inside a block) and an item (at the top level of a file).

### Definition

```rust
Let -> Result<Let, ()>:
      'let' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(name, tpe, value, Mut::Not, $span)) }
    | 'let' 'mut' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(name, tpe, value, Mut::Mut, $span)) }
    ;
```

The type annotation and the first value are both required.

### Example

```text
let x: int = 1;
let mut name: str = "a";
let p: P = .{ x: 3 };
```

### Notions used

- **`Type`** is the variable's type. See [Type](types.md#type).
- **`Expr`** is the first value. See [Expression](expressions.md#expression).

### Design reasons

- The type annotation is a project requirement until type inference exists. Inference and static type checking are planned.
- The required first value: not yet reviewed.

### AST representation (2026-11-16)

```rust
struct Let { name: String, tpe: Type, value: Expr, mutability: Mut, span: Span }   // enum Mut { Not, Mut }
Stmt::Declaration(Let)   // inside a block
ItemKind::Let(Let)       // at the top level
```

`span` is the source range of the whole declaration, from `let` to `;`. Name resolution uses it as the identity of the declaration, so each use of `x` can record which `let` it refers to.

The `Let` rule returns `Let`, and each parent wraps it. The struct is shared, not stored as `ItemKind::Let(Stmt)`, so the type guarantees that a top-level item holds a declaration. `Block` is a separate struct for the same reason.

Since: 2026-11-11

## Loops

### Intuition

A loop runs a block again and again. A loop is a statement because it has no value to give: the body's value is thrown away on each pass, and the body may run zero times.

### Definition

```rust
While -> Result<Stmt, ()>:
      'while' Expr Block { Ok(Stmt::While(Box::new($2?), Box::new(Expr::Block($3?)))) }
    ;
Loop -> Result<Stmt, ()>:
      'loop' Block { Ok(Stmt::Loop(Box::new(Expr::Block($2?)))) }
    ;
For -> Result<Stmt, ()>:
      'for' 'ID' 'in' Expr Block { Ok(Stmt::For(convert_lexeme($lexer, $2)?, $span, Box::new($4?), Box::new(Expr::Block($5?)))) }
    ;
LoopStmt -> Result<Stmt, ()>:
      While { $1 }
    | Loop { $1 }
    | For { $1 }
    | 'break' ';' { Ok(Stmt::Break) }
    | 'continue' ';' { Ok(Stmt::Continue) }
    ;
```

- `while` repeats its block while the condition is true.
- `loop` repeats its block until a `break`.
- `for` gives the name `ID` to each element of the `Expr` in turn, then runs the block.
- `break` leaves the loop. `continue` skips to the next pass.

Loops need no `;`, but `break` and `continue` do. A loop cannot appear where an expression is expected, so `let x: int = while true { };` is a syntax error.

### Example

```text
while x < 10 { x = x + 1; }
loop { break; }
for i in 0 .. 3 { f(i); }
```

### Notions used

- **`Block`** is a `{ }` list of statements, with an optional value at the end. See [Block](expressions.md#block).
- **`Expr`** is any expression. In `while`, it is the condition. In `for`, it is the thing being walked over, such as the range `0 .. 3`. See [Expression](expressions.md#expression).
- **`ID`** is a name token. See [Names and integers](lexer.md#names-and-integers).

### Design reasons

- There is no `break value` feature, so `break` and `continue` give no value either.
- `return` stays an expression. See [Simple operation](operations.md#simple-operation).

### AST representation (2026-11-15)

`Stmt::While(cond, body)`, `Stmt::Loop(body)`, `Stmt::For(name, span, iterable, body)`, `Stmt::Break` and `Stmt::Continue`.

- The body is the whole `Block`, wrapped as `Expr::Block`. The loop ignores the body's tail value.
- The `for` variable is a `String`, like the name in `let`. The `Span` after it covers the whole loop. Name resolution uses it as the identity of the variable, in the same way as the span of `Let`.

Not checked by the parser: that `break` and `continue` are inside a loop, and whether a loop body may have a tail value.

Since: 2026-11-11

## Assignment

### Intuition

An assignment stores new values into places that already exist, such as a variable, a field or an array element. It is an action, not a value: `3` is an expression, but `x = 3` is not.

### Definition

```rust
Targets -> Result<Vec<Expr>, ()>:
      Postfix { Ok(vec![$1?]) }
    | Targets ',' Postfix { ... push ... }
    ;
Values -> Result<Vec<Expr>, ()>:
      Expr { Ok(vec![$1?]) }
    | Values ',' Expr { ... push ... }
    ;
```

The statement itself is the `Stmt` alternative `Targets '=' Values ';'`, see [Statement](#statement).

- The left side is a `Postfix`, so `a + c = b` is a syntax error.
- Assignment is a statement, so `a = b = 1` is a syntax error.
- The grammar accepts any number of targets and values. A later pass checks that the counts match.

### Example

```text
x = 1;
p.x = 3;
a, b = b, a;    // swap
```

### Notions used

- **`Postfix`** is a value followed by calls, fields or indexes, such as `p.x` or `v[0]`. The places you can store into have this shape. See [Postfix](operations.md#postfix).
- **`Expr`** is any expression. See [Expression](expressions.md#expression).

### Design reasons

- The lists follow Go: value `i` goes into target `i`.
- The counts must be equal. A target or value with no partner is an error, so `a, b = 1` and `a, b = 1, 2, 3` are rejected. Copying one value into every target (broadcast) was dropped on 2026-11-16.

### AST representation (2026-11-16)

`Stmt::Assign(targets, values)`, both `Vec<Expr>`, kept exactly as written. Go's `AssignStmt` does the same. The parser does not pair targets with values: pairing them would hide a count mismatch from the later pass and break swaps.

Checked by a later semantic pass, not by the parser:

- each target is a place (a variable, field or index), since `f() = 1` parses;
- `targets.len() == values.len()`.

Evaluation order, for code generation: evaluate all the values first, then store them into the targets from left to right. This makes `a, b = b, a` swap. Storing pair by pair would run `a = b; b = a`, and both would end up equal.

Since: 2026-11-15
