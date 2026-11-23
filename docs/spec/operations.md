# Operations

Purpose: defines the operation rules of UPL and the abstract syntax tree (AST) nodes they build.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-17.

Level 1: operations. An operation is an expression that does not end in a block: a value, or operators applied to values. The rules are in `src/specs/parser.y`.

The operation rules form a chain. Each rule is built from the rule to its right:

```text
SimpleOperation → BinaryOperation → UnaryOperation → Postfix → Primary
   (.. return)       (+ * < && ...)       (- !)       (call . [])  (atoms)
     loosest                                                      tightest
```

An operator can come before its operand (prefix: `-x`), between two operands (infix: `a + b`) or after its operand (postfix: `f(x)`, `p.x`, `a[0]`).

Sections:

- [Primary](#primary)
- [Struct literal](#struct-literal)
- [Array literal](#array-literal)
- [Postfix](#postfix)
- [Unary operation](#unary-operation)
- [Binary operation](#binary-operation)
- [Simple operation](#simple-operation)

## Primary

### Intuition

A primary is an atom: a complete value that needs no operator, such as a name, a number or a literal. Every other operation is built on top of primaries.

### Definition

```rust
Primary -> Result<Expr, ()>:
      Path { Ok(Expr::Path($1?)) }
    | 'INTEGER' { ... Literal::Int ... }
    | 'STRING' { ... Literal::Str ... }
    | 'true' { Ok(Expr::Lit(Literal::Bool(true))) }
    | 'false' { Ok(Expr::Lit(Literal::Bool(false))) }
    | 'self' { Ok(Expr::SelfValue) }
    | '(' Expr ')' { $2 }
    | '.' '{' FieldInits '}' | '.' '{' FieldInits ',' '}' | '.' '{' '}'   // struct literals
    | '[' ElementList ']' | '[' ElementList ',' ']'                       // array literals
    ;
```

| Group | Alternatives | Example |
|:---|:---|:---|
| Names | `Path`, `'self'` | `x`, `a::b`, `self` |
| Literals | `'INTEGER'`, `'STRING'`, `'true'`, `'false'` | `42`, `"hi"`, `true` |
| Grouping | `'(' Expr ')'` | `(a + b)` |
| Struct literals | `'.' '{' FieldInits '}'` and variants | `.{ x: 3 }` |
| Array literals | `'[' ElementList ']'` and variants | `[1, 2, 3]` |

`( Expr )` turns any expression back into an atom. This is how parentheses override precedence: in `(a + b) * c`, `(a + b)` is one primary. The parentheses leave no AST node, because the action passes the inner value up.

### Example

```text
x        a::b      self
42       "hi"      true
(a + b)  .{ x: 3 } [1, 2, 3]
```

### Notions used

- **`Path`** is a name, or names joined by `::`, such as `a::b`. A path may start with the keyword `root`, as in `root::util::dist`, and `root` may only be the first segment. `root` is stored as an ordinary first segment. The path also stores its position (a span) for error messages.
- **`'STRING'`** is a string token. See [Strings](lexer.md#strings).
- **`FieldInits`** and **`ElementList`** are the contents of a struct literal and an array literal. See [Struct literal](#struct-literal) and [Array literal](#array-literal).

### Design reasons

- Literals and names are at the bottom of the chain, so they can appear wherever an expression can: `[1, 2][0]`, `.{ x: 3 }.x`.
- Every name, including a plain variable `x`, is stored as `Expr::Path`. The parser has no scopes, so it cannot know whether a name is a variable, a function or a type. Name resolution decides that later, as in rustc.
- Other choices: not yet reviewed.

### AST representation

Each alternative holds only what is written at that spot in the source, without punctuation:

| Alternative | Source | Data |
|:---|:---|:---|
| `'INTEGER'` | `42` | the value |
| `'STRING'` | `"hi"` | the decoded text |
| `'true'`, `'false'` | `true` | the boolean |
| `'self'` | `self` | nothing: only "self appears here" |

A literal carries no name. In `let x: int = 42;` the name `x` belongs to the `Let` node, and the literal `42` holds only its value. The same literal could appear in `f(42)` or `[42]`, with no name at all:

```text
Let { name: "x", tpe: Int32, value: Lit(Int(42)), mutability: Not }
```

`self` carries no data, because the parser cannot know which object it refers to. That depends on the call (`p.get()` or `q.get()`) at run time. A later pass checks that `self` is inside a method and gives it the type of that `impl`'s struct.

Since: 2026-11-11 (explanation added 2026-11-13)

## Struct literal

### Intuition

A struct literal creates a struct value by giving a value to each field.

### Definition

```rust
FieldInits -> Result<Vec<FieldInit>, ()>:
      FieldInit { Ok(vec![$1?]) }
    | FieldInits ',' FieldInit { ... push ... }
    ;
FieldInit -> Result<FieldInit, ()>:
      'ID' ':' Expr { Ok(FieldInit::new(...)) }
    ;
```

The literal itself is the `Primary` alternative `'.' '{' FieldInits '}'`, see [Primary](#primary).

- A trailing comma is allowed.
- `.{ }` is the value of a struct with no fields.
- The literal names no type. Its type comes from the context, such as a `let` annotation, a parameter type or a return type. The type checker must supply it.

### Example

```text
let p: P = .{ x: 3, y: true };
let e: E = .{ };
```

### Design reasons

- Field access (`p.x`) and calls (`P::new()`) need a value that already exists, so the language needs one built-in way to create a value. Constructors are built on top of it.
- The leading `.` follows Zig. It does not clash with blocks or other syntax: `.{ }` is a struct literal, `{ }` is a block.
- Fields are written Rust style, `x: 3`, the same way as in a struct declaration.
- Empty structs are allowed (reviewed 2026-11-14). In Rust they serve as namespaces, marker types and trait carriers. The last two need traits or generics.

### AST representation

`Expr::FieldInits(Vec<FieldInit>)`. Each `FieldInit` always has a name, a value and a span.

- `.{ }` is an empty `Vec`. "No fields" is stored in the container, never as an empty element, so no field of `FieldInit` is optional.
- The trailing comma leaves no trace: `.{ x: 3 }` and `.{ x: 3, }` give the same node.

Since: 2026-11-11

## Array literal

### Intuition

An array literal creates an array value by listing its elements in order.

### Definition

```rust
ElementList -> Result<Vec<Expr>, ()>:
      Expr { Ok(vec![$1?]) }
    | ElementList ',' Expr { ... push ... }
    ;
```

The literal itself is the `Primary` alternative `'[' ElementList ']'`, see [Primary](#primary).

- An array literal has at least one element. `[]` is a syntax error.
- A trailing comma is allowed: `[1, 2,]` gives the same node as `[1, 2]`. `[,]` and `[1,,2]` are syntax errors.
- The type checker, not the parser, checks that the element count matches the type.

### Example

```text
let a: [int, 3] = [1, 2, 3];
let m: [[int, 2], 2] = [[1, 2], [3, 4],];
```

### Design reasons

- The literal follows Rust.
- Elements use their own `ElementList` rule instead of sharing `ArgList` with calls, so each rule is named for what it means.
- The trailing comma is for editing, not for error detection: every line of a multi-line list has the same shape, so an edit or a diff touches one line.
- `[]` is forbidden in the grammar. Zero-length collections will use a planned vector type. The type `[int, 0]` is invalid too, but the grammar accepts it, so the type checker must reject it.
- Not storing the size in the node: not yet reviewed.

### AST representation

`Expr::Array(Vec<Expr>)`. `ElementList` only collects the elements; `Primary` wraps them in `Expr::Array`.

- The rule is left-recursive and each step pushes to the end, so the vector keeps source order.
- Each element is a full `Expr` tree, so `[a + 1, [2, 3]]` nests.
- No size is stored: the element count is the vector's length.

Since: 2026-11-11

## Postfix

### Intuition

A postfix operation is applied after a value: call it, take one of its fields, or index into it.

### Definition

```rust
Postfix -> Result<Expr, ()>:
      Postfix '(' Args ')' { Ok(Expr::Call(...)) }
    | Postfix '.' 'ID' { Ok(Expr::Field(...)) }
    | Postfix '[' Expr ']' { Ok(Expr::Index(...)) }
    | Primary { $1 }
    ;
Args -> Result<Vec<Expr>, ()>:
      /* empty */ { Ok(vec![]) }
    | ArgList { Ok($1?) }
    | ArgList ',' { Ok($1?) }
    ;
```

| Form | Alternative | Example | AST node |
|:---|:---|:---|:---|
| Call | `Postfix '(' Args ')'` | `f(1, 2)` | `Expr::Call(callee, args)` |
| Field | `Postfix '.' 'ID'` | `p.x` | `Expr::Field(object, name)` |
| Index | `Postfix '[' Expr ']'` | `a[0]` | `Expr::Index(array, index)` |

- Call arguments may be empty and allow a trailing comma.
- The rule is left-recursive, so postfix forms chain from left to right, and each one applies to the result so far.
- Postfix binds tighter than every other operator: `-a.b` is `-(a.b)`, and `x + f(y)` is `x + (f(y))`.
- A method call `p.get()` has no rule of its own. It is a field access followed by a call.

### Example

`a::b(i)[0].c` is the path `a::b`, called with `i`, indexed with `0`, then field `c`:

```text
Field .c
  └─ Index [0]
       └─ Call (i)
            └─ Path a::b
```

### Notions used

- **`Primary`** is the value the postfix forms apply to. See [Primary](#primary).

### Design reasons

Not yet reviewed.

Since: 2026-11-11

## Unary operation

### Intuition

A unary operation applies one operator to one value: `-x` negates a number, `!b` negates a boolean.

### Definition

```rust
UnaryOperation -> Result<Expr, ()>:
      '-' UnaryOperation { Ok(Expr::Unary(UnOp::Neg, Box::new($2?))) }
    | '!' UnaryOperation { Ok(Expr::Unary(UnOp::Not, Box::new($2?))) }
    | Postfix { $1 }
    ;
```

Unary operators can repeat, as in `!!b` or `- -x`. They bind tighter than every binary operator and looser than postfix: `-a + b` is `(-a) + b`, and `-a.b` is `-(a.b)`.

### Example

```text
-x    !done    -f(1)    !!b
```

### Design reasons

Not yet reviewed.

Since: 2026-11-11

## Binary operation

### Intuition

A binary operation combines two values with an operator between them, such as `a + b` or `x < y`. Precedence decides which operator applies first when several appear together.

### Definition

```rust
%left '||'
%left '&&'
%nonassoc '==' '!=' '<' '<=' '>' '>='
%left '+' '-'
%left '*' '/' '%'

BinaryOperation -> Result<Expr, ()>:
      BinaryOperation '||' BinaryOperation { Ok(Expr::Binary(..., BinOp::Or, ...)) }
    | ... one alternative per operator ...
    | UnaryOperation { $1 }
    ;
```

The `%left` and `%nonassoc` lines at the top of `parser.y` set the binary levels. A later line binds tighter. All levels, from the loosest to the tightest:

| Level | Operators | Grouping |
|:---|:---|:---|
| 1 | `..` (see [Simple operation](#simple-operation)) | does not chain |
| 2 | `\|\|` | left |
| 3 | `&&` | left |
| 4 | `== != < <= > >=` | does not chain |
| 5 | `+ -` | left |
| 6 | `* / %` | left |
| 7 | unary `- !` | |
| 8 | postfix: call, field, index | |

Comparisons are `%nonassoc`, so `a < b < c` is a syntax error.

### Example

```text
a + b * c          // a + (b * c)
a - b - c          // (a - b) - c
x < y && y < z     // (x < y) && (y < z)
a < b < c          // syntax error
```

### Design reasons

- `*` above `+`, and comparisons that do not chain, come from the original UPL requirements.
- Other levels: not yet reviewed.

### AST representation

`Expr::Binary(left, op, right)`, with `BinOp` one of `Or And Eq Ne Lt Le Gt Ge Add Sub Mul Div Rem`. The tree shape already encodes precedence, so the node stores no level.

Since: 2026-11-11

## Simple operation

### Intuition

A simple operation is the top of the operation chain: a binary operation, a range, or a `return`. It is every expression that does not end in a block.

### Definition

```rust
SimpleOperation -> Result<Expr, ()>:
      BinaryOperation { $1 }
    | BinaryOperation '..' BinaryOperation { Ok(Expr::Range(...)) }
    | 'return' { Ok(Expr::Return(None)) }
    | 'return' BinaryOperation { Ok(Expr::Return(Some(...))) }
    ;
```

- A range `a .. b` does not chain: `a .. b .. c` is a syntax error.
- `return` may have a value or not.
- `break`, `continue` and assignment are not operations. They are statements, see [Loops](statements.md#loops) and [Assignment](statements.md#assignment).

### Example

```text
a + 1
0 .. n
return
return x * 2
```

### Notions used

- **`BinaryOperation`** is the level below. See [Binary operation](#binary-operation).

### Design reasons

Not yet reviewed.

Since: 2026-11-11
