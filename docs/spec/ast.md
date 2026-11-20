# Abstract syntax tree (AST)

This page explains what the AST is and how it differs from the grammar. It is a theory page: it has no `@doc:` tag in the source.

**Abstract syntax tree (AST) = structure without notation, before meaning.**

An AST represents a program's **structure** (which constructs it uses and how they nest), independent of its **notation** (concrete syntax) and before any **meaning** (semantics) is assigned.

## Concrete syntax and abstract syntax

| | Concrete syntax | Abstract syntax |
|:---|:---|:---|
| Describes | **How** the program is written: its notation | **What** the program is built from: its structure |
| Includes | Keywords, punctuation, parentheses, `;`, precedence levels, chains of grammar rules | Constructs and their nesting |
| Defined by | The grammar, `src/specs/parser.y` | The AST types, `src/ast.rs` |
| Example | `1 + 2 * 3` and `1 + (2 * 3)` are different texts | Both have the same abstract syntax |

The AST is neither the grammar nor the meaning:

- **Not the grammar.** The grammar is the concrete syntax. The AST is what is left when the grammar's notation is removed.
- **Not the meaning.** The AST does not know which declaration `a` refers to, what type it has, or what value it holds. Name resolution, type checking and later passes add that.

## Example: `a + b * c`

The same expression at each stage, from text to AST.

### 1. Tokens (lexer)

A flat list. It has no nesting, so it does not say what `*` applies to.

```text
ID(a)   '+'   ID(b)   '*'   ID(c)
```

### 2. Parse tree (concrete syntax)

One node for every grammar rule the parser used. With the UPL grammar, each name passes through the whole chain of expression rules:

```text
BinaryOperation
├── BinaryOperation
│   └── UnaryOperation
│       └── Postfix
│           └── Primary
│               └── Path
│                   └── ID  a
├── '+'
└── BinaryOperation
    ├── BinaryOperation
    │   └── UnaryOperation ─ Postfix ─ Primary ─ Path ─ ID  b
    ├── '*'
    └── BinaryOperation
        └── UnaryOperation ─ Postfix ─ Primary ─ Path ─ ID  c
```

Concrete syntax shows *how* the text matched the grammar: every rule, every token.

### 3. AST (abstract syntax)

Only the constructs and how they nest:

```text
Binary(+)
├── Path[a]
└── Binary(*)
    ├── Path[b]
    └── Path[c]
```

As a Rust value (with `Path { segments: [...] }` shortened to `Path[...]`):

```rust
Expr::Binary(
    Box::new(Expr::Path(Path[a])),
    BinOp::Add,
    Box::new(Expr::Binary(
        Box::new(Expr::Path(Path[b])),
        BinOp::Mul,
        Box::new(Expr::Path(Path[c])),
    )),
)
```

### What changed between 2 and 3

| Parse tree | AST | Why |
|:---|:---|:---|
| `UnaryOperation → Postfix → Primary → Path → ID` for each name | `Path[a]` | The chain only encoded precedence levels. It adds no structure |
| `'+'` and `'*'` tokens as separate children | The operator stored in the node: `Binary(+)` | The operator is part of the construct, not a child |
| 22 nodes (6 per name, 2 `BinaryOperation`s, 2 operator tokens) | 5 nodes | Notation removed, structure kept |

The AST still says that `b * c` is computed first and its result is the right operand of `+`. That fact is in the **shape**: `Binary(*)` is a child of `Binary(+)`. The precedence declarations (`%left`) and the rule chain were needed to *find* that shape; once found, the AST keeps the shape and drops the machinery.

## Why the AST exists

Every later stage reads the AST instead of the text:

| Stage | Question it answers using the AST |
|:---|:---|
| Name resolution | Which declaration does each `Path` refer to? |
| Type checking | Does each construct make sense for its types? |
| TAC generation | Which instructions compute each construct? |

The text is parsed once. Each later stage is a traversal of the tree.

Since: 2026-11-13
