# Errors

How the compiler reports lexer and parser errors. Not part of the grammar.

## error-report

Source: `@doc: error-report` in `src/error.rs`

Used by: `main` in `src/main.rs`, for every entry in the `errs` list returned by `parser_y::parse`.

### Definition

Each lexer or parser error is converted to a `CompileError` and printed to stderr in rustc style. The compiler then exits with code 1.

```
error: unexpected '}'
 --> parse.upl:1:28
  |
1 | fn main() { let x: int = 2 }
  |                            ^
  = help: possible fixes:
          1: Insert ;
```

- **Lexer error** (no token rule matches): `error: unknown character '$'`, with no fixes listed.
- **Parser error** (the tokens don't fit the grammar): `error: unexpected <token>`, or `unexpected end of file`. Then lrpar's repair sequences, one per line, in lrpar's own words: `Insert <token>`, `Delete <text>`, `Shift <text>` (keep this token). Consecutive deletes are merged, as in lrpar's `pp`. When lrpar finds no repair, the `help` lines are left out.

The `-->` line and the `^` show where lrpar *noticed* the error. For a missing `;` at the end of a line, this is the next token, often on the next line.

### Intention

The rustc layout shows the error in its source line, so it is easy to find.

The message reports only what lrpar found. lrpar owns the parsing and error recovery, so any rule we add on top is a guess about its results. For that reason the compiler does not:

- name one "expected" token. lrpar often finds several repairs of equal cost, and picking one misleads. `for i in range 1..3` once printed `expected '%'`.
- add context such as "in this `for` loop" from the nearest keyword. That keyword can belong to a different statement.

### Representation (2026-11-17)

```rust
enum CompileError {
    Lex   { line, col, text: String },
    Parse { line, col, found: String, repairs: Vec<String> },
}
```

The variants hold plain values only. `CompileError::from_lrpar` is the only code that reads lrpar's error API (`span`, `lexeme`, `repairs`, `line_col`, `span_str`). `report` prints any `CompileError` without using lrpar, so later passes such as type checking can create and print errors the same way.

Known limits: a tab in the source line moves the `^` to the wrong place. When lrpar gives every repair the same cost, the list can be long (14 fixes for `range 1..3`), and lrpar doesn't rank them.

Since: 2026-11-17
