# Items

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-23.

Level 4: items. An item is anything at the top level of a file, outside every block. The rules are in `src/specs/parser.y`.

Sections:

- [Program](#program)
- [Function](#function)
- [Self parameter](#self-parameter)
- [Struct](#struct)
- [Impl](#impl)
- [Visibility](#visibility)
- [Use, export and mod](#use-export-and-mod)
- [Const and static](#const-and-static)

## Program

### Intuition

A program is a list of items. Every item is a declaration, an import or a module: it names something, and it runs nothing. Code that runs is inside a function body.

### Definition

```rust
Item -> Result<ItemKind, ()>:
      Visibility Function { Ok(ItemKind::Function(Vis::new($1?, $2?))) }
    | Visibility Struct { ... }
    | Impl { Ok(ItemKind::Impl($1?)) }
    | Use { ... ItemKind::Use(path, alias) ... }
    | Export { ... ItemKind::Export(path, alias) ... }
    | Visibility Mod { ... }
    | Let { Ok(ItemKind::Let($1?)) }
    | Visibility Const { ... }
    | Visibility Static { ... }
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
export a::c as d;
struct P { x: int }
impl P { pub fn get(self) -> int { self.x } }
let base: int = 1;
pub const LIMIT: int = 10;
fn main() { }
```

### Notions used

- **`Function`**, **`Struct`**, **`Impl`**, **`Use`**, **`Export`**, **`Mod`**, **`Visibility`**: see the sections below.
- **`Let`** at the top level is a private module variable. See [Let](statements.md#let). **`Const`** and **`Static`**: see [Const and static](#const-and-static).

### Design reasons

- The top level holds declarations, imports and modules, not a fixed `begin ... end` block.
- `ItemList: ItemList Item | Item` is left-recursive, which suits an LR parser (one that reads left to right and builds the tree bottom-up): the list is reduced one item at a time.

### AST representation (2026-11-16)

`Program` returns `Vec<ItemKind>`. `main.rs` prints this tree with `{:#?}`.

```rust
enum ItemKind {
    Function(Vis<Function>),
    Struct(Vis<Struct>),
    Impl(Impl),
    Use(Path, Option<String>),
    Export(Path, Option<String>),
    Mod(Vis<String>),
    Let(Let),
    Const(Vis<Let>),
    Static(Vis<Let>),
}
```

The node types are described in the sections below.

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

<<<<<<< HEAD
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
- A nested function cannot be `pub`: nothing outside its block can reach it, so `pub fn` inside a block is a syntax error. Its AST node is always `Vis { vis: Private, .. }`.
=======
A function is an **item**, not a statement (learner decision, following rustc). Functions may also be declared inside a block, Rust style: the inner function is visible only in that block and cannot use the outer function's local variables (learner decision). The grammar has `Stmt -> Function` for this.
>>>>>>> main

### AST representation (2026-11-16)

```rust
<<<<<<< HEAD
enum ItemKind { Function(Vis<Function>), ... }
struct Function {
    name: String,                // linking uses to definitions is name resolution's job
    self_param: SelfParam,       // enum SelfParam { Not, Value }
    parameters: Vec<Parameter>,  // struct Parameter { name: String, return_type: Type }
=======
enum ItemKind { Function(Function) }
struct Function {
    name: String,                // like let; linking uses to definitions is name resolution's job
    self_param: SelfParam,       // enum SelfParam { Not, Value }
    parameters: Vec<Parameter>,  // struct Parameter { name: String, tpe: Type }
>>>>>>> main
    return_type: Option<Type>,   // None: no `-> Type`
    body: Block,
}
Stmt::Item(ItemKind)             // a nested item inside a block
```

<<<<<<< HEAD
- The name is a `String`, because a definition is one name, not a `Path`.
- `self` is a separate field, not a parameter, so one field tells a method apart from a static function.
- The body is typed `Block`, see [Block](expressions.md#block).
- `Params` returns `(SelfParam, Vec<Parameter>)`, because the grammar finds `self` there.
- The parameter's type field is named `return_type` in `src/ast.rs`, although it holds the parameter's type.

Limit: names have no span, so an error cannot point at a definition.
=======
Learner decisions: name as `String` (a definition is one name, not a `Path`); `self` as a separate enum field, not a parameter, for readability; `body: Block`; fields built through `Function::new` and `Parameter::new`. `Params` returns `(SelfParam, Vec<Parameter>)`, because the grammar finds `self` there. `Program` returns `Vec<ItemKind>`. Struct, impl, use, mod and top-level `let` items still return `Err(())`, so a program using them prints `error: could not build AST`. Known cost: names have no span, so errors cannot point at a definition yet.
>>>>>>> main

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

### AST representation (2026-11-16)

`ItemKind::Struct(Struct { field: Vec<Field>, id })`, with `Field { id, field_type }`. Learner decisions: `Field` is its own type, not a reused `Parameter`, so fields can later gain visibility (`pub`, deferred) without touching parameters; `struct E {}` stores an empty `Vec`, not an `Option`; a definition field has a type and no value, unlike `FieldInit` in a struct literal. The struct does not hold its impl: see [impl-use-mod](#impl-use-mod).

Since: 2026-11-11

## Struct

### Intuition

A struct declares a new type made of named, typed fields.

### Definition

<<<<<<< HEAD
```rust
StructFields -> Result<Vec<Vis<Field>>, ()>:
      StructFields ',' Visibility 'ID' ':' Type { ... push ... }
    | Visibility 'ID' ':' Type { Ok(vec![Vis::new($1?, Field::new(...))]) }
    ;
Struct -> Result<Struct, ()>:
      'struct' 'ID' '{' StructFields '}' { ... }
    | 'struct' 'ID' '{' StructFields ',' '}' { ... }
    | 'struct' 'ID' '{' '}' { ... vec![] ... }
    ;
```
=======
`impl ID { functions }` holds zero or more functions. `use Path ;` imports a path like `a::b`. `mod ID ;` declares a module whose contents live in another file. Inline modules (`mod ID { items }`) are a syntax error.
>>>>>>> main

- Fields are `ID : Type`, separated by commas. A field may be marked `pub`, see [Visibility](#visibility).
- A trailing comma is allowed.
- An empty body `{ }` is allowed.

<<<<<<< HEAD
### Example

```text
struct P { pub x: int, y: bool }
struct E { }
```

### Design reasons

- The empty struct is a separate alternative, so the field list is never empty. This keeps a leading comma, as in `struct P { , x: int }`, a syntax error.
- The trailing comma: not yet reviewed.

### AST representation (2026-11-16)

`ItemKind::Struct(Vis<Struct>)`, with `Struct { field: Vec<Vis<Field>>, id }` and `Field { id, field_type }`.

- `Field` is its own type, not a reused `Parameter`, so fields carry visibility (`Vis<Field>`) without changing parameters.
- `struct E {}` stores an empty `Vec`, not an `Option`.
- A field in a declaration has a type and no value, unlike `FieldInit` in a [struct literal](operations.md#struct-literal).
- The struct does not hold its methods, see [Impl](#impl).
=======
`impl` is a separate item, not part of the struct (learner decision). The parser builds one item at a time, so it cannot attach an impl to its struct; an impl may also come before its struct, a type may have several impls, and `impl Q` without `struct Q` must be reported. Name resolution links an impl to its type by name. No inline modules: the learner finds them counterintuitive (decision 2026-11-16, like Go packages). Finding and parsing the file for `mod m;` is left for when the compiler handles more than one file. `use`: not yet reviewed.

### AST representation (2026-11-16)

`ItemKind::Impl(Impl { methods: Vec<Function>, id })`. Methods reuse the `Function` struct; `id` is the type name. `ItemKind::Use(Path)`; linking the path to what it names is name resolution's job. `ItemKind::Mod(String)`: the id only.
>>>>>>> main

Since: 2026-11-11

## Impl

### Intuition

An `impl` adds methods to a type that is declared elsewhere.

### Definition

```rust
Functions -> Result<Vec<Vis<Function>>, ()>:
      /* empty */ { Ok(vec![]) }
    | Functions Visibility Function { ... push ... }
    ;
Impl -> Result<Impl, ()>:
      'impl' 'ID' '{' Functions '}' { Ok(Impl::new(...)) }
    ;
```

An impl holds zero or more functions. Each method may be marked `pub`. The `impl` itself takes no `pub`, because it introduces no name of its own.

### Example

```text
impl P {
    pub fn get(self) -> int { self.x }
    fn helper(self) { }
}
```

### Design reasons

`impl` is a separate item, not part of the struct:

- The parser builds one item at a time, so it cannot attach an impl to its struct.
- An impl may come before its struct, and a type may have several impls.
- `impl Q` without `struct Q` must be reported as an error.

Name resolution links an impl to its type by name.

### AST representation (2026-11-16)

`ItemKind::Impl(Impl { methods: Vec<Vis<Function>>, id })`. Methods reuse the `Function` struct. `id` is the type name.

Since: 2026-11-11

## Visibility

### Intuition

A name is private to its module unless it is marked `pub`. A private name can be used in its own module and in every module below it. The full rule is in [Visibility](modules.md#visibility).

### Definition

```rust
Visibility -> Result<Visibility, ()>:
      /* empty */ { Ok(Visibility::Private) }
    | 'pub' { Ok(Visibility::Pub) }
    ;
```

`Visibility` comes before a top-level `fn`, `struct`, `const`, `static` or `mod`, before a method in an `impl`, and before a struct field. It is not accepted before `impl`, `use`, `export`, a top-level `let`, or a function inside a block.

### Example

```text
pub fn walk() { }
pub struct P { pub x: int, y: int }
impl P { pub fn get(self) -> int { self.x } }
pub mod organs;
pub impl P { }        // syntax error
pub use a::b;         // syntax error: use `export`
pub let x: int = 1;   // syntax error: use `const` or `static`
```

### Design reasons

- Private is the default, so making a name public is always written out.
- `impl` takes no `pub`, because it adds methods to a type and introduces no name.
- `use` is always private and `export` is always public, so `pub` on them would have no meaning.
- A nested function cannot be reached from outside its block, so `pub` on it would have no meaning.
- A top-level `let` is never `pub`. A variable shared with other modules is a `const` or a `static`, as in Rust, so a name that other modules can use is marked as a constant or as one program-wide location.

### AST representation (2026-11-23)

```rust
enum Visibility { Private, Pub }
struct Vis<T> { vis: Visibility, node: T }
```

A node that can be `pub` is wrapped in `Vis<T>`. The wrapped types keep their fields, and passes that only need the node read `node`.

Since: 2026-11-23

## Use, export and mod

### Intuition

`use` imports a name from another module as a private alias. `export` re-exports a name, so it becomes a public item of the module that writes the line. `mod` declares a module whose contents live in another file.

### Definition

```rust
Use -> Result<(Path, Option<String>), ()>:
      'use' Path ';' { Ok(($2?, None)) }
    | 'use' Path 'as' 'ID' ';' { Ok(($2?, Some(...))) }
    ;
Export -> Result<(Path, Option<String>), ()>:
      'export' Path ';' { Ok(($2?, None)) }
    | 'export' Path 'as' 'ID' ';' { Ok(($2?, Some(...))) }
    ;
Mod -> Result<String, ()>:
      'mod' 'ID' ';' { convert_lexeme($lexer, $2) }
    ;
```

- `as ID` renames the alias. Without it, the alias is the path's last segment.
- Inline modules, as in `mod m { items }`, are a syntax error.
- `mod` lines belong only in `mod.upl` files. The grammar accepts them in any file. The loader, which is not built yet, will reject them elsewhere, see [Module layout](modules.md#module-layout).

### Example

```text
use root::util::dist;
use root::util::dist as d;
export organs::Heart;
mod util;
mod m { }     // syntax error
```

### Design reasons

- There are no inline modules (since 2026-11-16). Each module is one file, or a folder with a `mod.upl`.
- Re-exports have one keyword, `export`, and `pub use` does not exist, so each keyword has one meaning.
- The rules for paths, aliases and modules are in [Modules](modules.md).

### AST representation (2026-11-23)

- `ItemKind::Use(Path, Option<String>)` and `ItemKind::Export(Path, Option<String>)`. The `Option` holds the `as` name. Linking the path to what it names is name resolution's job.
- `ItemKind::Mod(Vis<String>)`: the module name and its visibility.

Since: 2026-11-11

## Const and static

### Intuition

`const` and `static` declare module-level variables that may be `pub`. A `const` never changes. A `static` is one location for the whole program, and `static mut` may be changed.

### Definition

```rust
Const -> Result<Let, ()>:
      'const' 'ID' ':' Type '=' Expr ';' { ... Mut::Not ... }
    ;
Static -> Result<Let, ()>:
      'static' 'ID' ':' Type '=' Expr ';' { ... Mut::Not ... }
    | 'static' 'mut' 'ID' ':' Type '=' Expr ';' { ... Mut::Mut ... }
    ;
```

- A type and a value are required, as for `let`.
- `const mut` is a syntax error.
- `const` and `static` are items only. Inside a block they are a syntax error.

### Example

```text
pub const MAX: int = 10;
pub static COUNT: int = 0;
static mut N: int = 1;
const mut X: int = 1;    // syntax error
```

### Design reasons

- Only `const` and `static` may be `pub`, so every module-level name that other modules can use is marked as a constant or as one program-wide location.
- Whether a `const` is copied into each use, and how writes to a `static mut` are checked: not yet designed.

### AST representation (2026-11-23)

`ItemKind::Const(Vis<Let>)` and `ItemKind::Static(Vis<Let>)`. Both reuse the `Let` struct (name, type, value, mutability). A `const` always has `Mut::Not`.

Since: 2026-11-23
