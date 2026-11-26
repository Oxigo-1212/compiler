# Symbol table

Purpose: defines what the symbol table of the UPL compiler is, and what it links.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-26.

This page has no `@doc:` tag of its own. The symbol table is a phase after parsing, and it is not built yet. It reads the AST described in [items.md](items.md), [statements.md](statements.md) and [operations.md](operations.md).

Sections:

- [Definition](#definition)
- [Scopes inside a function body](#scopes-inside-a-function-body)

## Definition

### Intuition

Every name in a program appears in one of two roles:

| Role | What it does | Examples |
|:---|:---|:---|
| **Declaration** | Introduces a name and says what it is. | `let h`, the parameter `w: int`, `for i`, `fn area`, `struct Point`, `const MAX`, `static`, `mod geo` |
| **Use** | Refers to a name declared somewhere else. | `h` in `w * h`, `area(2)`, `Point` in `let p: Point` |

The **symbol table** links each use to the declaration it refers to. It records each link once, so later phases, such as type checking and code generation, read the link instead of looking the name up again.

### Identity of a declaration

A link points at a declaration, so each declaration needs an identity. There are two kinds of declaration, and each has its own kind of identity:

| Declaration | Identity | Rust type | AST nodes |
|:---|:---|:---|:---|
| [Item](items.md) | Definition id (`DefId`): the index of the item in the program's list of items | `usize` | `ItemKind`, `Stmt::Item` |
| Local binding | The source range (span) of its declaration | `lrpar::Span` | `Let`, `Parameter`, `Stmt::For`, `SelfParam::Value` |

- An item can be named from other functions, modules and files, and every later phase refers to it. It needs one id that all of them share.
- A local binding can be named only inside its own function. The span of its declaration is unique within a file, so it needs no counter. A span is made by the parser, so its uniqueness follows from the source text.
- A use is identified by its own span. `Path`, `Expr::SelfValue` and the local declarations carry a span in the AST for this reason.

### Outputs

The symbol table produces a map from each use to what it refers to. Its key is the span of the use. Later phases keep and read it after name resolution has finished.

The value says what kind of declaration the use refers to, and carries its identity:

```rust
type DefId = usize;

struct Def {
    id: DefId,
    def_kind: DefKind,
    span: Span,
}

enum Res {
    Local(Span),   // a local binding: parameter, `let` in a block, `for` variable, `self`
    Item(DefId),   // an item: `fn` (top level or nested), `struct`, `const`, `static`, top-level `let`
    Err,           // unresolved name; an error is also recorded in `errors`
}
defs: Vec<Def>                  // arena of item definitions, indexed by DefId
results: HashMap<Span, Res>     // span of a use → what it refers to
errors: Vec<CompileError>       // all unresolved-name errors collected during the walk
```

- The variant follows the kind of declaration, not the place where it is written. A `fn` declared inside a block is `Item`, although only that block can see it. The scope decides who can see a name, and the variant decides how its declaration is identified.
- Parameters, `let` in a block, `for` variables and `self` share `Local`. They are all identified by a span and visible only inside their function.
- Each item's metadata (`DefKind` and declaration `Span`) lives once in `defs: Vec<Def>`, indexed by `DefId`. `Function`, `Struct` and `Let` carry a `Span` in `src/ast.rs` so diagnostics can point back to the declaration.
- When a name cannot be resolved, the resolver records `Res::Err` in `results` and pushes an error onto `errors`, then continues walking so one run reports every unresolved name.

### What it does not do

| Not its job | Done by | Reason |
|:---|:---|:---|
| Types, such as "`x` is an `int`" | Type checking | Type checking needs the links first. |
| Fields and methods, such as `p.x` and `p.len()` | Type checking | Which `x` is meant depends on the type of `p`. |
| Values and memory | Code generation and run time | The symbol table works at compile time only. |

### Design reasons

- **Declarations and uses are linked once.** Without the stored links, each later phase would repeat the lookup, and the scopes the lookup needs no longer exist after name resolution.
- **Two kinds of identity.** Items are reachable from the whole program and need a shared id. Local bindings are reachable only from their own function, and their span already identifies them.
- **Links are stored beside the AST, not inside it.** The AST holds facts read from the source text. Links are worked out by a later phase, so they are stored in a separate map keyed by spans the AST already has.

Since: 2026-11-24

## Scopes inside a function body

### Scope stack and module table

While walking a function body, the resolver stores active lexical scopes in a last-in, first-out (LIFO) stack (`Vec<Scope>`). Entering a function parameter list or a `Block` pushes a `Scope`; leaving it pops that `Scope`.

```rust
enum Namespace {
    Type,   // `struct`, `mod`
    Value,  // `fn`, `let`, `const`, `static`, local bindings
}

struct Scope {
    locals: HashMap<String, Span>,                 // local binding name -> declaration Span (always Value)
    items: HashMap<(String, Namespace), DefId>,    // nested item (name, namespace) -> DefId
    is_fn_boundary: bool,                          // true on a function's parameter scope
}
```

The enclosing module's item table (`HashMap<(String, Namespace), DefId>`) is stored outside the stack. It is populated before body resolution starts, never popped, and searched after the stack.

### Namespaces

Names are split into two namespaces so type names and value names do not collide:

- **`Namespace::Type`:** Holds `struct` and `mod` declarations. A type lookup skips `Scope.locals` and searches only `Scope.items` and the module's item table.
- **`Namespace::Value`:** Holds `fn`, `const`, `static`, top-level `let`, and all local bindings. Because every local binding is a value, `Scope.locals` needs no `Namespace` key.

### Nested items in a block

Entering a `Block` runs a pre-pass over `block.stmts` before walking any statement or nested function body:

1. **Push a scope:** Push a `Scope` with empty `locals`, empty `items`, and `is_fn_boundary: false`.
2. **Pre-pass `Stmt::Item`:** Register every `Stmt::Item` in `block.stmts` into `Scope.items` (error on duplicate names in the same block). Do not walk item bodies during this loop.
3. **Walk statements in order:** Resolve each statement, adding `Stmt::Declaration` names to `Scope.locals` after resolving their initializers, and walking nested function bodies.
4. **Resolve the tail and pop:** Resolve `block.tail` if present, then pop the `Scope`.

### Function boundary and `self`

Name lookup walks the scope stack from top to bottom, then checks the module's item table:

- **Before a function boundary:** Lookup checks `Scope.locals` first, then `Scope.items`.
- **Past a function boundary:** Once lookup crosses a `Scope` with `is_fn_boundary: true`, it skips `Scope.locals` in all outer scopes and checks only `Scope.items` and the module's item table.
- **`self` as a local binding:** A method's `SelfParam::Value(Span)` is entered into the function's parameter scope as a local binding named `"self"`. Plain lookup plus the boundary rule rejects `self` outside a method and inside a nested function.

### Lookup algorithm

`lookup(name: &str, ns: Namespace) -> Option<Res>` resolves a single-segment name in this order:

1. **Initialize boundary flag:** Set `crossed_fn_boundary = false`.
2. **Walk `scopes` from top to bottom:** For each `scope` in `scopes.iter().rev()`:
   - If `ns == Namespace::Value` and `!crossed_fn_boundary`, check `scope.locals.get(name)`. If found, return `Some(Res::Local(span))`.
   - Check `scope.items.get(&(name, ns))`. If found, return `Some(Res::Item(def_id))`.
   - If `scope.is_fn_boundary`, set `crossed_fn_boundary = true`.
3. **Check the module item table:** Check `global_items.get(&(name, ns))`. If found, return `Some(Res::Item(def_id))`.
4. **Return unresolved:** Return `None`. The caller records `Res::Err` in `results` and pushes a `CompileError` onto `errors`.

### AST walk rules

Each AST node in `src/ast.rs` is walked in this order:

| AST node | Scope push / pop | Declarations | Lookups and child order |
|:---|:---|:---|:---|
| `Function` | Push `Scope { is_fn_boundary: true }`; pop after `body` | If `self_param` is `SelfParam::Value(span)`, insert `"self" -> span` into `locals`. For each `Parameter`, resolve `param.return_type` (`Type`), then insert `param.name -> param.span` into `locals`. | Resolve `return_type` (`Type`) if `Some`, then walk `body` (`Block`). |
| `Block` | Push `Scope { is_fn_boundary: false }`; pop after `tail` | Pre-pass `stmts`: for each `Stmt::Item`, push a `Def` onto `defs` and insert `(name, ns) -> def_id` into `items` (error on duplicate). | Walk `stmts` in order, then walk `tail` if `Some`. |
| `Stmt::Declaration(Let)` | None | After resolving `value`, insert `let.name -> let.span` into the top `Scope.locals` (overwrites any earlier local with the same name in the same block). | Resolve `let.tpe` (`Type`), then resolve `let.value` (`Expr`), then declare `let.name`. |
| `Stmt::For(var, span, iter, body)` | Push `Scope { is_fn_boundary: false }` before `body`; pop after `body` | Insert `var -> span` into the new `Scope.locals`. | Resolve `iter` (`Expr`) in the outer scope first, then push scope, declare `var`, and walk `body`. |
| `Stmt::Item(ItemKind::Function(vis_fn))` | Handled by `Function` | Already registered in `Block` pre-pass. | Walk `vis_fn.node` (`Function`). |
| `Expr::Path(path)` | None | None | Look up `path.segments[0]` in `Namespace::Value`; store `Res` (or `Res::Err`) at `results[path.pos]`. Multi-segment paths are handled in module resolution. |
| `Expr::SelfValue(span)` | None | None | Look up `"self"` in `Namespace::Value`; store `Res` (or `Res::Err`) at `results[span]`. |
| `Expr::Field(base, _field)` | None | None | Walk `base` only. Field and method lookup belongs to type checking. |
| `Type::Name(path)` | None | None | Look up `path.segments[0]` in `Namespace::Type`; store `Res` (or `Res::Err`) at `results[path.pos]`. |
| `Expr::If`, `Stmt::While`, `Stmt::Loop`, other `Expr`/`Stmt` | None (nested `Block` nodes push their own scopes) | None | Walk child expressions and statements in source order. |

### Test cases

Automated tests are deferred to a later pass; the initial implementation is only required to compile cleanly. Once tests are added, they must cover these cases:

- **Parameter and shadowing:** In `fn f(x: int) { let x: int = x; x; }`, the initializer `x` resolves to the parameter `Span`, and the trailing `x` resolves to the `let` `Span`.
- **Duplicate parameters:** `fn f(x: int, x: int) {}` records a duplicate-name error.
- **Nested `fn` and function boundary:** A nested `fn` resolves calls to itself and sibling nested functions (`Res::Item`), while referencing an outer `let` or outer parameter records `Res::Err`.
- **`self` binding:** `self` in a method resolves to `SelfParam::Value(span)`; `self` in a free `fn` or nested `fn` records `Res::Err`.
- **Namespaces:** `struct P {}` and `fn P() {}` coexist; `Type::Name(P)` resolves to the struct's `DefId`, and `Expr::Path(P)` resolves to the function's `DefId`.
- **Error collection:** Two unresolved names in one function produce two `Res::Err` entries in `results` and two entries in `errors`.

### Design reasons

- **Block pre-pass instead of block modules.** Modules in UPL exist only as files and folders declared through `mod.upl` (see [Module layout](modules.md#module-layout)), and blocks contain only nested `fn` items without `use`, `mod`, or `pub`. Creating anonymous block modules would break that file-only module invariant and require an extra AST walk before body resolution.
- **Separate `locals` and `items` maps per `Scope`.** Crossing a function boundary must hide outer locals while keeping outer items visible. Keeping the maps separate also lets a `let` written after a nested `fn` shadow that name for later statements without overwriting the `fn` entry seen by sibling nested functions.
- **`self` in the scope stack.** Storing `self` in the method's parameter scope catches invalid `self` uses during name resolution instead of deferring scope checks to type checking.

Since: 2026-11-25
