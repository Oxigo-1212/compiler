# UPL frontend spec

Purpose: index of the UPL frontend spec, and how its sections are laid out.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-23.

The spec is ordered by the levels of the language, from tokens up to items. Each level contains the one below it, see [Levels of the language](../grammar.md#levels-of-the-language).

| Level | File | Sections |
|:---|:---|:---|
| 0. Tokens | [lexer.md](lexer.md) | Skipped text, Keywords, Names and integers, Operators, Strings |
| 1. Operations | [operations.md](operations.md) | Primary, Struct literal, Array literal, Postfix, Unary operation, Binary operation, Simple operation |
| 2. Expressions | [expressions.md](expressions.md) | Expression, Block-like, If, Block |
| 3. Statements | [statements.md](statements.md) | Statement, Let, Loops, Assignment |
| 4. Items | [items.md](items.md) | Program, Function, Self parameter, Struct, Impl, Visibility, Use export and mod, Const and static |
| Types | [types.md](types.md) | Type |
| Modules | [modules.md](modules.md) | Module layout, Paths, Visibility, Imports and exports |

Theory: [ast.md](ast.md) explains what the AST is (structure without notation, before meaning), with the example `a + b * c`. [sdt.md](sdt.md) explains how the grammar actions build the AST, and why that translation is S-attributed.

## Layout of a section

Each section describes one grammar rule, or a few rules that work together. Its subsections come in this order, and a subsection with nothing to say is left out:

1. **Intuition**: the idea behind the rule, in plain words.
2. **Definition**: the rule as written in `src/specs/parser.y` or `src/specs/lexer.l`, then what it accepts. Long actions are shortened to `{ ... }`.
3. **Example**: source text that the rule accepts or rejects.
4. **Notions used**: the other rules this rule uses, with links.
5. **Design reasons**: why the rule is this way. "Not yet reviewed" means no reason has been recorded yet.
6. **AST representation**: the node the rule builds. A date in the heading is when that node was designed.

Each section ends with **Since**, the date the rule was added.

## Finding the code

A section names its grammar rules, such as `If` or `BinaryOperation`. Find a rule with:

```sh
grep -n "^If ->" src/specs/parser.y
```

When code changes, update only the sections it affects.

## Source tags

Each spec section is marked in the source with a comment `// @doc: <tag>` above the rules it describes. The table maps every tag to its section.

| Tag | Section |
|:---|:---|
| `lex-skip` | [Skipped text](lexer.md#skipped-text) |
| `lex-keywords` | [Keywords](lexer.md#keywords) |
| `lex-ident-int` | [Names and integers](lexer.md#names-and-integers) |
| `lex-operators` | [Operators](lexer.md#operators) |
| `lex-string` | [Strings](lexer.md#strings) |
| `postfix-primary` | [Primary](operations.md#primary), [Postfix](operations.md#postfix) |
| `struct-literal` | [Struct literal](operations.md#struct-literal) |
| `array-literal` | [Array literal](operations.md#array-literal) |
| `expr-precedence` | [Binary operation](operations.md#binary-operation) |
| `simple-op` | [Simple operation](operations.md#simple-operation) |
| `block-like` | [Block-like](expressions.md#block-like) |
| `if` | [If](expressions.md#if) |
| `block` | [Block](expressions.md#block) |
| `stmt` | [Statement](statements.md#statement) |
| `let` | [Let](statements.md#let) |
| `loop-stmt` | [Loops](statements.md#loops) |
| `assign` | [Assignment](statements.md#assignment) |
| `items` | [Program](items.md#program) |
| `function` | [Function](items.md#function) |
| `method-self` | [Self parameter](items.md#self-parameter) |
| `struct` | [Struct](items.md#struct) |
| `visibility` | [Visibility](items.md#visibility) |
| `impl-use-mod` | [Impl](items.md#impl), [Use, export and mod](items.md#use-export-and-mod) |
| `const-static` | [Const and static](items.md#const-and-static) |
| `type` | [Type](types.md#type) |
| `error-report` | [error-report](errors.md#error-report) |

Error messages: [errors.md](errors.md) describes how lexer and parser errors are reported, from `src/error.rs`.

## Drift check

Prints any tag that is in the source but not in the table above, or the other way round. No output means they match.

```sh
comm -3 <(grep -rhoE "@doc: [a-z-]+" src/ | cut -d' ' -f2 | sort -u) \
        <(grep -oE '^\| `[a-z-]+`' docs/spec/README.md | tr -d '|` ' | sort -u)
```
