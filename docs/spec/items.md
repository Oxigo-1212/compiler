# Items

Rules that derive from `Item`, the top-level declarations.

## items

Source: `@doc: items` in `src/specs/parser.y`

### Definition

`Program: ItemList;` A program is one or more items. `Item` is `Function | Struct | Impl | Use | Mod | Let`. An empty file is a syntax error.

### Intention

The top level holds declarations, imports and modules, not a fixed `begin ... end` block (learner decision). `ItemList: ItemList Item | Item` is left-recursive, which suits an LR parser.

Since: 2026-11-11

## function

Source: `@doc: function` in `src/specs/parser.y`

### Definition

`fn ID ( Params ) Block`, optionally with `-> Type` before the block. Parameters are `ID : Type`, comma-separated, with an optional trailing comma; the list may be empty.

### Intention

Not yet reviewed.

Since: 2026-11-11

## struct

Source: `@doc: struct` in `src/specs/parser.y`

### Definition

`struct ID { fields }` with fields `ID : Type`, comma-separated. A trailing comma and an empty body `{ }` are allowed.

### Intention

The empty struct is a separate alternative so the field list never has to be empty, which avoids accepting a leading comma (learner decision). The trailing comma alternative was not yet reviewed.

Since: 2026-11-11

## impl-use-mod

Source: `@doc: impl-use-mod` in `src/specs/parser.y`

### Definition

`impl ID { functions }` holds zero or more functions. `use Path ;` imports a path like `a::b`. `mod ID ;` declares a module; `mod ID { items }` defines one inline (may be empty).

### Intention

Not yet reviewed.

Since: 2026-11-11

## method-self

Source: `@doc: method-self` in `src/specs/parser.y`

### Definition

`self` may be the first parameter of a function: `fn get(self) -> int { self.x }`, `fn set(self, v: int) { ... }`. It can't appear in any other position. Inside the body, `self` is an expression. A function without `self` is static and is called through its path, as in `P::new()`.

### Intention

Rust-style `self`, so a method can read and change its own struct (learner decision). Static functions via `P::method()` parse already; their meaning is not designed yet.

Since: 2026-11-11
