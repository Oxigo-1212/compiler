# Syntax-directed translation (SDT)

Purpose: explains how the parser builds the abstract syntax tree (AST), and why that translation is S-attributed.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-20.

This is a theory page: it has no `@doc:` tag in the source.

**Syntax-directed translation (SDT) = a grammar where each rule carries an action that computes a value.**

In UPL the value of every rule is an AST node. The actions are the `{ ... }` blocks in `src/specs/parser.y`, and the node types are in `src/ast.rs`.

## Attributes

An **attribute** is a value attached to a grammar symbol. Here it is the value an action returns, such as an `Expr` or a `Type`.

| Kind | Where its value comes from |
|:---|:---|
| Synthesized | The children of the symbol: the symbols on the right-hand side of its rule |
| Inherited | The parent of the symbol, or a sibling to its left |

An SDT is **S-attributed** when it uses only synthesized attributes.

## The UPL translation is S-attributed

grmtools runs an action once, when the parser reduces that rule. Inside an action, only these values are available:

| Name in the action | What it is | Kind |
|:---|:---|:---|
| `$1`, `$2`, … | The values already built for the right-hand-side symbols | Synthesized |
| `$span` | The source range the rule covers, taken from its children | Synthesized |
| `$lexer` | The token text, read-only | Input, not an attribute |

No value can flow down from a parent or across from a sibling:

- grmtools has no mid-rule actions. An action is always at the end of a rule.
- When a child is reduced, its parent does not exist yet.
- The grammar has no `%parse-param`, so actions share no mutable state.

An action may change a child's value before returning it, as `Path` does with `let mut p = $1?; p.add_path(...)`. The result still comes only from the children, so it is synthesized.

## Example: `a + b * c`

The parser reduces the innermost rules first. Each action builds its node from the nodes of its children:

1. `Path -> 'ID'` builds `Path[a]`, `Path[b]` and `Path[c]` from the tokens.
2. `BinaryOperation -> BinaryOperation '*' BinaryOperation` builds `Binary(*)` from `$1` = `Path[b]` and `$3` = `Path[c]`.
3. `BinaryOperation -> BinaryOperation '+' BinaryOperation` builds `Binary(+)` from `$1` = `Path[a]` and `$3` = `Binary(*)`.

Values move only upward, from the leaves to the root. The full tree is in [ast.md](ast.md#example-a--b--c).

## Limits

- **Side effects.** `translate_escape` prints an unknown escape with `eprintln!`. This is a diagnostic. It does not change any attribute.
- **Context from above.** Some checks need a value that flows down, such as the expected type of a struct literal `.{ x: 3 }`. Those checks cannot be done in the actions. They belong to a later pass over the AST.

Since: 2026-11-13
