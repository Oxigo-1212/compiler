# Modules

Purpose: defines how a UPL program is split into modules and files, how paths name items in other modules, and which names other modules may use.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-23.

This page has no `@doc:` tag of its own. Its rules span several grammar rules (`Path`, `Visibility`, `Use`, `Export`, `Mod`) and the loader, which is not built yet. The grammar rules themselves are in [items.md](items.md) and [types.md](types.md).

Sections:

- [Module layout](#module-layout)
- [Paths](#paths)
- [Visibility](#visibility)
- [Imports and exports](#imports-and-exports)

## Module layout

### Rules

- **Root.** The command line names the root file, `main.upl`. Its module is the root of the tree.
- **Manifests.** Each folder has one `mod.upl` file. It holds only `mod` lines and lists the modules of that folder. Code files hold no `mod` lines. Keeping all module declarations in one file per folder puts the module structure of each folder in one known place, apart from the code.
- **Root children.** `src/mod.upl`, beside `main.upl`, declares the children of the root module. It does not list `main.upl`, which the command line already names.
- **Folder modules.** `mod X;` in a parent's `mod.upl` loads the folder `X/` through `X/mod.upl`. `X/mod.upl` must contain the self-entry `mod X;`, which loads `X/X.upl`. That file holds the items of `X` itself, so its items have the path `X::Item`, not `X::X::Item`. Every other `mod Y;` line in `X/mod.upl` declares a child of `X`.
- **Leaf modules.** `mod Y;` loads `Y.upl` when the folder has no `Y/` directory.
- **One layout per meaning.** A module has exactly one possible layout, so there is no second way to write the same module.
- **Undeclared files.** A file that no `mod` line declares is not part of the program and is ignored.
- **The loader enforces file kinds.** It knows each file's name after parsing. In `mod.upl`, every item must be a `mod` line. In any other file, no item may be a `mod` line.

### Example

```
src/
├── mod.upl            mod util;  mod human;
├── main.upl           fn main() { .. }
├── util.upl           pub fn dist() -> int { .. }
└── human/
    ├── mod.upl        mod human;  mod organs;
    ├── human.upl      pub struct Human { .. }
    └── organs.upl     pub struct Heart { .. }
```

Module tree:

```
root (main.upl)
├── util     (util.upl)
└── human    (human/human.upl)
    └── organs (human/organs.upl)
```

| `mod` line | Written in | Loads | Adds a path segment |
|:---|:---|:---|:---|
| `mod util;` | `src/mod.upl` | `src/util.upl` | `util` |
| `mod human;` | `src/mod.upl` | `src/human/mod.upl` | `human` |
| `mod human;` (self-entry) | `src/human/mod.upl` | `src/human/human.upl` | none: `human::Human` |
| `mod organs;` | `src/human/mod.upl` | `src/human/organs.upl` | `human::organs` |

### Layout errors

| Layout found for `mod util;` | Result |
|:---|:---|
| `util.upl` only | Leaf module |
| `util/mod.upl` with the self-entry, and `util/util.upl` | Folder module |
| `util.upl` and `util/` both exist | Error. The message names both paths and says to move `util.upl` to `util/util.upl` and create `util/mod.upl`. |
| `util/` without `util/mod.upl` | Error |
| `util/mod.upl` without the self-entry `mod util;` | Error |
| `util/mod.upl` with the self-entry, but no `util/util.upl` | Error: declared file not found |
| Neither file nor folder | Error: declared file not found |

Because each `mod` line maps to one file path, built from the parent's folder and the declared name, no two `mod` lines can load the same file. Each line also loads a file one folder deeper, or the folder's own `X.upl`, so loading always ends.

## Paths

- **Absolute paths.** A path that starts with the keyword `root` is resolved from the root module: `root::util::dist`.
- **Relative paths.** Any other path is resolved from the current module, the module of the file that contains it.
- **`root` position.** `root` may only be the first segment. The grammar rejects `a::root::b`.
- **No parent keyword.** UPL has no `super`. A path to a sibling or parent module is written in full from `root`, such as `root::human::organs::Heart`. The cost is longer paths, which also have to change when an enclosing module is renamed.
- **One path rule.** Paths in `use`, `export`, types and expressions all follow the same rule.
- **Storage.** The AST stores `root` as an ordinary first segment: `root::util::dist` becomes `segments: ["root", "util", "dist"]`. `Path` needs no new field.

From `src/human/organs.upl` (module `human::organs`):

| Written | Starts at | Result |
|:---|:---|:---|
| `Heart` | `organs`' table | found |
| `util::dist` | `organs`' table | not found: `util` is not a child of `organs` |
| `root::util::dist` | root | found |

## Visibility

### Rule

- **Default.** Every name is private unless it is marked `pub`.
- **`pub` names.** A `pub` name can be used from any module, provided every module on the path to it can be used from there too.
- **Private names.** A private name can be used in the module that declares it and in every module below that module, at any depth.
- **Direction.** Access only flows downward. A parent cannot use the private names of its children.
- **Where `pub` may appear:** on items (functions, structs, `const`, `static`), on `mod` lines in `mod.upl`, on struct fields and on methods. A top-level `let` is never `pub`: a variable shared with other modules is a `const` or a `static`.
- **Checked per segment.** The check runs on every segment of a path, not only the last one.

The subtree may use private names because a child module is usually split out of a parent that grew too large, and the child still needs the parent's internal code.

### Example

`organs` is declared without `pub` in `human/mod.upl`, and `Heart` is `pub`:

| Code in | Uses | Result | Reason |
|:---|:---|:---|:---|
| `human/human.upl` | `organs::Heart` | allowed | `organs` is declared in `human` |
| a module under `human` | `root::human::organs::Heart` | allowed | the module is under `human` |
| `main.upl` | `root::human::organs::Heart` | error: `organs` is private | `main` is not under `human` |

### AST representation

Visibility is an enum, and the private case is the default.

A wrapper struct goes around each node that can carry `pub`. Existing structs stay unchanged, and passes that only need the node read `.node`.

```rust
pub enum Visibility { Private, Pub }
pub struct Vis<T> { vis: Visibility, node: T }

ItemKind::Function(Vis<Function>)
ItemKind::Struct(Vis<Struct>)
ItemKind::Const(Vis<Let>)
ItemKind::Static(Vis<Let>)
ItemKind::Mod(Vis<String>)
Impl   { methods: Vec<Vis<Function>>, .. }
Struct { field: Vec<Vis<Field>>, .. }
```

`impl`, `use`, `export` and top-level `let` carry no visibility. An `impl` introduces no name of its own. A `use` is always private, an `export` is always public, and a top-level `let` is always private. `pub` on a function inside a block is a syntax error.

## Imports and exports

### Keywords

| Keyword | Meaning | Example |
|:---|:---|:---|
| `pub` | Makes a definition public. | `pub struct Circle { .. }` |
| `use` | Imports a name as a private alias for the importing module. | `use root::util::dist;` |
| `export` | Re-exports a name: the alias becomes a public item of the module where the line is written. | `export organs::Heart;` in `human.upl` gives `root::human::Heart` |
| `as` | Renames the alias in `use` or `export`. | `use root::util::dist as d;` |

- **`pub use` does not exist.** Re-exports have one spelling, `export`, so each keyword has one meaning.
- **Import only what is visible.** A `use` or `export` can only name something that the visibility rule lets the importing module use.
- **No new symbol.** An alias is a new entry in the importing module's item table, pointing at an existing definition.
- **Key of the alias.** The alias is keyed by the `as` name if there is one, and by the path's last segment otherwise.

### Why `export` exists

`export` separates where an item is defined from where other modules find it:

- **Hidden file layout.** A module can keep its child modules private and still offer chosen items under its own path.
- **Stable paths.** An item can move to another file, and only the `export` line changes.

### AST representation

```rust
ItemKind::Use(Path, Option<String>)     // use a::b;     use a::b as c;     None: key = last segment
ItemKind::Export(Path, Option<String>)  // export a::b;  export a::b as c;
```

### Clashes

Not yet decided: if an alias has the same name as another item or alias in the same module, it is an error: "name defined more than once". `as` gives the programmer a way to fix it. The candidate rule follows Rust (errors E0252 and E0255).

Not yet decided: whether a `use` may import a whole module, as in `use root::util;` followed by `util::dist()`.
