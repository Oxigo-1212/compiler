# UPL frontend spec

Purpose: index of the UPL frontend spec, and how its sections are laid out.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-17.

The spec is ordered by the levels of the language, from tokens up to items. Each level contains the one below it, see [Levels of the language](../grammar.md#levels-of-the-language).

| Level | File | Sections |
|:---|:---|:---|
| 0. Tokens | [lexer.md](lexer.md) | Skipped text, Keywords, Names and integers, Operators, Strings |
| 1. Operations | [operations.md](operations.md) | Primary, Struct literal, Array literal, Postfix, Unary operation, Binary operation, Simple operation |
| 2. Expressions | [expressions.md](expressions.md) | Expression, Block-like, If, Block |
| 3. Statements | [statements.md](statements.md) | Statement, Let, Loops, Assignment |
| 4. Items | [items.md](items.md) | Program, Function, Self parameter, Struct, Impl, Use and mod |
| Types | [types.md](types.md) | Type |

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
Each entry has a **Definition** (what the code accepts or does) and an **Intention** (why). "Not yet reviewed" means no design reason has been recorded yet. Update only the entries you changed in a session.

Error messages: [errors.md](errors.md) describes how lexer and parser errors are reported. It is the only spec file that documents code outside the grammar (`src/error.rs`).

Theory: [ast.md](ast.md) explains what the AST is (structure without notation, before meaning), with the example `a + b * c`.

| Tag | File |
|:---|:---|
| [lex-skip](lexer.md#lex-skip) | `lexer.md` |
| [lex-keywords](lexer.md#lex-keywords) | `lexer.md` |
| [lex-ident-int](lexer.md#lex-ident-int) | `lexer.md` |
| [lex-operators](lexer.md#lex-operators) | `lexer.md` |
| [lex-string](lexer.md#lex-string) | `lexer.md` |
| [items](items.md#items) | `items.md` |
| [function](items.md#function) | `items.md` |
| [struct](items.md#struct) | `items.md` |
| [impl-use-mod](items.md#impl-use-mod) | `items.md` |
| [loop-stmt](statements.md#loop-stmt) | `statements.md` |
| [block-like](expressions.md#block-like) | `expressions.md` |
| [if](expressions.md#if) | `expressions.md` |
| [simple-op](expressions.md#simple-op) | `expressions.md` |
| [expr-precedence](expressions.md#expr-precedence) | `expressions.md` |
| [struct-literal](expressions.md#struct-literal) | `expressions.md` |
| [array-literal](expressions.md#array-literal) | `expressions.md` |
| [method-self](items.md#method-self) | `items.md` |
| [postfix-primary](expressions.md#postfix-primary) | `expressions.md` |
| [let](shared.md#let) | `shared.md` |
| [block](shared.md#block) | `shared.md` |
| [type](shared.md#type) | `shared.md` |
| [error-report](errors.md#error-report) | `errors.md` |

## Drift check

Prints any tag that is in the code but has no `## <tag>` heading, or the other way round. No output means they match.

```sh
comm -3 <(grep -rhoE "@doc: [a-z-]+" src/ | cut -d' ' -f2 | sort -u) \
        <(grep -hE "^## [a-z-]+$" docs/spec/*.md | grep -v README | cut -d' ' -f2 | sort -u)
```

The same check for the one-sentence summary in [`docs/grammar.md`](../grammar.md): prints any grammar tag (from `src/specs/`) that has no `#<tag>` link there, or a link to a tag that does not exist.

```sh
comm -3 <(grep -rhoE "@doc: [a-z-]+" src/specs/ | cut -d' ' -f2 | sort -u) \
        <(grep -oE "\.md#[a-z-]+\)" docs/grammar.md | sed -E 's/.*#([a-z-]+)\)/\1/' | sort -u)
```
