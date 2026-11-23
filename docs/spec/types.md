# Types

Purpose: defines how types are written in UPL and the abstract syntax tree (AST) node they build.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-23.

Types are not a level of their own: they are written in `let`, parameters, struct fields and return types. The rule is in `src/specs/parser.y`.

## Type

### Intuition

A type says what kind of value a name holds: a number, a boolean, a string, a struct or an array.

### Definition

```rust
Type -> Result<Type, ()>:
      'int' { Ok(Type::Int32) }
    | 'bool' { Ok(Type::Bool) }
    | 'str' { Ok(Type::Str) }
    | Path { Ok(Type::Name($1?)) }
    | '[' Type ',' 'INTEGER' ']' { Ok(Type::Array(Box::new(elem), size)) }
    ;
```

- `Path` is a type name, for example a struct name. It may be a path into another module, such as `root::geo::Point`, and follows the same rules as every other path, see [Paths](modules.md#paths).
- `[Type, INTEGER]` is an array type with an element type and a fixed size. Array types nest.
- There are no generics or references yet.

A type is used by `Let`, by parameters (`Param`), by struct fields (`StructFields`) and by the `->` return type of a function.

### Example

```text
int    bool    str    P    root::geo::Point    [int, 3]    [[int, 2], 4]
```

### Design reasons

- A type name is a `Path`, not a single name, so a struct from another module can be named in place without a `use` (since 2026-11-23).
- Other choices: not yet reviewed.

### AST representation

`enum Type { Int32, Bool, Str, Name(Path), Array(Box<Type>, u64), Void }`. The `Box` breaks the recursion, because a type cannot contain itself directly. The parser never produces `Void`.

Since: 2026-11-11
