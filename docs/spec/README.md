# UPL frontend spec

Docs are grouped by the grammar symbol each rule derives from. Each `## <tag>` heading documents one `@doc:` tag in the source. Find the code for a tag with:

```sh
grep -rn "@doc: <tag>" src/
```

Each entry has a **Definition** (what the code accepts or does) and an **Intention** (why). "Not yet reviewed" means no design reason has been recorded yet. Update only the entries you changed in a session.

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

## Drift check

Prints any tag that is in the code but has no `## <tag>` heading, or the other way round. No output means they match.

```sh
comm -3 <(grep -rhoE "@doc: [a-z-]+" src/ | cut -d' ' -f2 | sort -u) \
        <(grep -hE "^## [a-z-]+$" docs/spec/*.md | grep -v README | cut -d' ' -f2 | sort -u)
```
