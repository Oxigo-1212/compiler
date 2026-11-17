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

Theory: [ast.md](ast.md) explains what the AST is (structure without notation, before meaning), with the example `a + b * c`.

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
