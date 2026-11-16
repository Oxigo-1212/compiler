# Items

Rules that derive from `Item`, the top-level declarations.

## items

Source: `@doc: items` in `src/specs/parser.y`

### Definition

`Program: ItemList;` A program is one or more items. `Item` is `Function | Struct | Impl | Use | Mod | Let`. An empty file is a syntax error.

### Intention

The top level holds declarations, imports and modules, not a fixed `begin ... end` block (learner decision). `ItemList: ItemList Item | Item` is left-recursive, which suits an LR parser.

### AST representation (2026-11-16)

`Program` returns `Vec<ItemKind>`, where `ItemKind` is `Function`, `Struct`, `Impl`, `Use(Path)`, `Mod(String)` or `Let`. `main.rs` prints this tree with `{:#?}`.

Since: 2026-11-11

## function

Source: `@doc: function` in `src/specs/parser.y`

### Definition

`fn ID ( Params ) Block`, optionally with `-> Type` before the block. Parameters are `ID : Type`, comma-separated, with an optional trailing comma; the list may be empty.

### Intention

A function is an **item**, not a statement (learner decision, following rustc). Functions may also be declared inside a block, Rust style: the inner function is visible only in that block and cannot use the outer function's local variables (learner decision). The grammar has `Stmt -> Function` for this.

### AST representation (2026-11-16)

```rust
enum ItemKind { Function(Function) }
struct Function {
    name: String,                // like let; linking uses to definitions is name resolution's job
    self_param: SelfParam,       // enum SelfParam { Not, Value }
    parameters: Vec<Parameter>,  // struct Parameter { name: String, tpe: Type }
    return_type: Option<Type>,   // None: no `-> Type`
    body: Block,
}
Stmt::Item(ItemKind)             // a nested item inside a block
```

Learner decisions: name as `String` (a definition is one name, not a `Path`); `self` as a separate enum field, not a parameter, for readability; `body: Block`; fields built through `Function::new` and `Parameter::new`. `Params` returns `(SelfParam, Vec<Parameter>)`, because the grammar finds `self` there. `Program` returns `Vec<ItemKind>`. Struct, impl, use, mod and top-level `let` items still return `Err(())`, so a program using them prints `error: could not build AST`. Known cost: names have no span, so errors cannot point at a definition yet.

Since: 2026-11-11

## struct

Source: `@doc: struct` in `src/specs/parser.y`

### Definition

`struct ID { fields }` with fields `ID : Type`, comma-separated. A trailing comma and an empty body `{ }` are allowed.

### Intention

The empty struct is a separate alternative so the field list never has to be empty, which avoids accepting a leading comma (learner decision). The trailing comma alternative was not yet reviewed.

### AST representation (2026-11-16)

`ItemKind::Struct(Struct { field: Vec<Field>, id })`, with `Field { id, field_type }`. Learner decisions: `Field` is its own type, not a reused `Parameter`, so fields can later gain visibility (`pub`, deferred) without touching parameters; `struct E {}` stores an empty `Vec`, not an `Option`; a definition field has a type and no value, unlike `FieldInit` in a struct literal. The struct does not hold its impl: see [impl-use-mod](#impl-use-mod).

Since: 2026-11-11

## impl-use-mod

Source: `@doc: impl-use-mod` in `src/specs/parser.y`

### Definition

`impl ID { functions }` holds zero or more functions. `use Path ;` imports a path like `a::b`. `mod ID ;` declares a module whose contents live in another file. Inline modules (`mod ID { items }`) are a syntax error.

### Intention

`impl` is a separate item, not part of the struct (learner decision). The parser builds one item at a time, so it cannot attach an impl to its struct; an impl may also come before its struct, a type may have several impls, and `impl Q` without `struct Q` must be reported. Name resolution links an impl to its type by name. No inline modules: the learner finds them counterintuitive (decision 2026-11-16, like Go packages). Finding and parsing the file for `mod m;` is left for when the compiler handles more than one file. `use`: not yet reviewed.

### AST representation (2026-11-16)

`ItemKind::Impl(Impl { methods: Vec<Function>, id })`. Methods reuse the `Function` struct; `id` is the type name. `ItemKind::Use(Path)`; linking the path to what it names is name resolution's job. `ItemKind::Mod(String)`: the id only.

Since: 2026-11-11

## method-self

Source: `@doc: method-self` in `src/specs/parser.y`

### Definition

`self` may be the first parameter of a function: `fn get(self) -> int { self.x }`, `fn set(self, v: int) { ... }`. It can't appear in any other position. Inside the body, `self` is an expression. A function without `self` is static and is called through its path, as in `P::new()`.

### Intention

Rust-style `self`, so a method can read and change its own struct (learner decision). Static functions via `P::method()` parse already; their meaning is not designed yet.

Since: 2026-11-11
