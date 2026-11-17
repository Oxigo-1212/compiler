# Items

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-17.

Level 4: items. An item is anything at the top level of a file, outside every block. The rules are in `src/specs/parser.y`.

Sections:

- [Program](#program)
- [Function](#function)
- [Self parameter](#self-parameter)
- [Struct](#struct)
- [Impl](#impl)
- [Use and mod](#use-and-mod)

## Program

### Intuition

A program is a list of items. Every item is a declaration, an import or a module: it names something, and it runs nothing. Code that runs is inside a function body.

### Definition

```rust
Item -> Result<ItemKind, ()>:
      Function { Ok(ItemKind::Function($1?)) }
    | Struct { Ok(ItemKind::Struct($1?)) }
    | Impl { Ok(ItemKind::Impl($1?)) }
    | Use { Ok(ItemKind::Use($1?)) }
    | Mod { Ok(ItemKind::Mod($1?)) }
    | Let { Ok(ItemKind::Let($1?)) }
    ;
ItemList -> Result<Vec<ItemKind>, ()>:
      ItemList Item { ... push ... }
    | Item { Ok(vec![$1?]) }
    ;
Program -> Result<Vec<ItemKind>, ()>:
      ItemList { $1 }
    ;
```

- A program is one or more items. An empty file is a syntax error.
- Statements and expressions are not items. A file with `x = 1;`, `print(x);` or `while c { }` at the top level is a syntax error. They are allowed only inside a block, see [Statement](statements.md#statement).

### Example

```text
use a::b;
mod util;
struct P { x: int }
impl P { fn get(self) -> int { self.x } }
let limit: int = 10;
fn main() { }
```

### Notions used

- **`Function`**, **`Struct`**, **`Impl`**, **`Use`**, **`Mod`**: see the sections below.
- **`Let`** at the top level is a global variable. See [Let](statements.md#let).

### Design reasons

- The top level holds declarations, imports and modules, not a fixed `begin ... end` block.
- `ItemList: ItemList Item | Item` is left-recursive, which suits an LR parser (one that reads left to right and builds the tree bottom-up): the list is reduced one item at a time.

### AST representation (2026-11-16)

`Program` returns `Vec<ItemKind>`, where `ItemKind` is `Function`, `Struct`, `Impl`, `Use(Path)`, `Mod(String)` or `Let`. `main.rs` prints this tree with `{:#?}`.

Since: 2026-11-11

## Function

### Intuition

A function is a named block of code with parameters and an optional return type. It is an item, not a statement, but it may also be declared inside a block.

### Definition

```rust
Function -> Result<Function, ()>:
      'fn' 'ID' '(' Params ')' Block { ... return_type: None ... }
    | 'fn' 'ID' '(' Params ')' '->' Type Block { ... return_type: Some($7?) ... }
    ;
Param -> Result<Parameter, ()>:
      'ID' ':' Type { Ok(Parameter::new(...)) }
    ;
```

- Parameters are `ID : Type`, separated by commas, with an optional trailing comma. The list may be empty.
- `-> Type` before the block is optional.
- `Params` also accepts `self` as the first parameter, see [Self parameter](#self-parameter).

### Example

```text
fn main() { }
fn add(a: int, b: int) -> int { a + b }
fn outer() {
    fn helper() -> int { 1 }   // nested function
    helper();
}
```

### Notions used

- **`Block`** is the function body. See [Block](expressions.md#block).
- **`Type`** is a parameter type or the return type. See [Type](types.md#type).

### Design reasons

- A function is an item, not a statement, as in rustc.
- Functions may also be declared inside a block, Rust style. The inner function is visible only in that block and cannot use the outer function's local variables. The grammar has `Stmt -> Function` for this.

### AST representation (2026-11-16)

```rust
enum ItemKind { Function(Function), ... }
struct Function {
    name: String,                // linking uses to definitions is name resolution's job
    self_param: SelfParam,       // enum SelfParam { Not, Value }
    parameters: Vec<Parameter>,  // struct Parameter { name: String, return_type: Type }
    return_type: Option<Type>,   // None: no `-> Type`
    body: Block,
}
Stmt::Item(ItemKind)             // a nested item inside a block
```

- The name is a `String`, because a definition is one name, not a `Path`.
- `self` is a separate field, not a parameter, so one field tells a method apart from a static function.
- The body is typed `Block`, see [Block](expressions.md#block).
- `Params` returns `(SelfParam, Vec<Parameter>)`, because the grammar finds `self` there.
- The parameter's type field is named `return_type` in `src/ast.rs`, although it holds the parameter's type.

Limit: names have no span, so an error cannot point at a definition.

Since: 2026-11-11

## Self parameter

### Intuition

A method is a function that works on a struct value. It gets that value through `self`, its first parameter. A function without `self` is static.

### Definition

```rust
Params -> Result<(SelfParam, Vec<Parameter>), ()>:
      /* empty */ { Ok((SelfParam::Not, vec![])) }
    | ParamList { ... } | ParamList ',' { ... }
    | 'self' { Ok((SelfParam::Value, vec![])) }
    | 'self' ',' { ... }
    | 'self' ',' ParamList { ... } | 'self' ',' ParamList ',' { ... }
    ;
```

- `self` may be the first parameter, and only the first.
- Inside the body, `self` is an expression, see [Primary](operations.md#primary).
- A static function is called through its path, as in `P::new()`.

### Example

```text
impl P {
    fn get(self) -> int { self.x }
    fn set(self, v: int) { self.x = v; }
    fn new() -> P { .{ x: 0 } }        // static
}
```

### Design reasons

- Rust-style `self`, so a method can read and change its own struct.
- Static functions called through `P::method()` already parse. Their meaning is not designed yet.

Since: 2026-11-11

## Struct

### Intuition

A struct declares a new type made of named, typed fields.

### Definition

```rust
StructFields -> Result<Vec<Field>, ()>:
      StructFields ',' 'ID' ':' Type { ... push ... }
    | 'ID' ':' Type { Ok(vec![Field::new(...)]) }
    ;
Struct -> Result<Struct, ()>:
      'struct' 'ID' '{' StructFields '}' { ... }
    | 'struct' 'ID' '{' StructFields ',' '}' { ... }
    | 'struct' 'ID' '{' '}' { ... vec![] ... }
    ;
```

- Fields are `ID : Type`, separated by commas.
- A trailing comma is allowed.
- An empty body `{ }` is allowed.

### Example

```text
struct P { x: int, y: bool }
struct E { }
```

### Design reasons

- The empty struct is a separate alternative, so the field list is never empty. This keeps a leading comma, as in `struct P { , x: int }`, a syntax error.
- The trailing comma: not yet reviewed.

### AST representation (2026-11-16)

`ItemKind::Struct(Struct { field: Vec<Field>, id })`, with `Field { id, field_type }`.

- `Field` is its own type, not a reused `Parameter`, so fields can later gain visibility (`pub`, deferred) without changing parameters.
- `struct E {}` stores an empty `Vec`, not an `Option`.
- A field in a declaration has a type and no value, unlike `FieldInit` in a [struct literal](operations.md#struct-literal).
- The struct does not hold its methods, see [Impl](#impl).

Since: 2026-11-11

## Impl

### Intuition

An `impl` adds methods to a type that is declared elsewhere.

### Definition

```rust
Functions -> Result<Vec<Function>, ()>:
      /* empty */ { Ok(vec![]) }
    | Functions Function { ... push ... }
    ;
Impl -> Result<Impl, ()>:
      'impl' 'ID' '{' Functions '}' { Ok(Impl::new(...)) }
    ;
```

An impl holds zero or more functions.

### Example

```text
impl P {
    fn get(self) -> int { self.x }
}
```

### Design reasons

`impl` is a separate item, not part of the struct:

- The parser builds one item at a time, so it cannot attach an impl to its struct.
- An impl may come before its struct, and a type may have several impls.
- `impl Q` without `struct Q` must be reported as an error.

Name resolution links an impl to its type by name.

### AST representation (2026-11-16)

`ItemKind::Impl(Impl { methods: Vec<Function>, id })`. Methods reuse the `Function` struct. `id` is the type name.

Since: 2026-11-11

## Use and mod

### Intuition

`use` imports a name from another module. `mod` declares a module whose contents live in another file.

### Definition

```rust
Use -> Result<Path, ()>:
      'use' Path ';' { $2 }
    ;
Mod -> Result<String, ()>:
      'mod' 'ID' ';' { convert_lexeme($lexer, $2) }
    ;
```

Inline modules, as in `mod m { items }`, are a syntax error.

### Example

```text
use a::b;
mod util;
mod m { }     // syntax error
```

### Design reasons

- There are no inline modules (since 2026-11-16). Each module is one file, as a Go package is one directory.
- Finding and parsing the file for `mod m;` is left for when the compiler handles more than one file.
- `use`: not yet reviewed.

### AST representation (2026-11-16)

- `ItemKind::Use(Path)`. Linking the path to what it names is name resolution's job.
- `ItemKind::Mod(String)`: the module name only.

Since: 2026-11-11
