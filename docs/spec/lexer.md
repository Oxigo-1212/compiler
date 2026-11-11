# Lexer tokens

Rules in `src/specs/lexer.l`. These produce tokens; they are not grammar symbols.

## lex-skip

Source: `@doc: lex-skip` in `src/specs/lexer.l`

### Definition

Whitespace (`[ \t\r\n]+`), `//` line comments and `/* ... */` block comments produce no token. Block comments do not nest; the first `*/` ends them.

An unclosed `/*` is not a lexer error: it lexes as `/` then `*` and fails in the parser.

### Intention

Not yet reviewed.

Since: 2026-11-11

## lex-keywords

Source: `@doc: lex-keywords` in `src/specs/lexer.l`

### Definition

Reserved words: `let mut fn int bool true false if else while loop for in return break continue struct impl use mod self str`.

lrlex picks the longest match; on a tie the earlier rule wins. Keywords are listed before `ID`, so `let` is a keyword but `letter` is an `ID`.

### Intention

Not yet reviewed.

Since: 2026-11-11

## lex-ident-int

Source: `@doc: lex-ident-int` in `src/specs/lexer.l`

### Definition

`ID` is `[A-Za-z_][A-Za-z0-9_]*`. `INTEGER` is `[0-9]+` (no sign; `-` is a separate operator token).

This is wider than the old UPL rule `[A-Za-z]+[0-9]*`: `_` and digits may appear anywhere after the first character.

### Intention

Not yet reviewed.

Since: 2026-11-11

## lex-operators

Source: `@doc: lex-operators` in `src/specs/lexer.l`

### Definition

Two-character operators: `== != >= <= && || -> :: ..`. One-character tokens: `= > < ! + - * / % . , ( ) { } [ ] ; :`.

Longest match means `==` is one token, not two `=`.

### Intention

Not yet reviewed.

Since: 2026-11-11

## lex-string

Source: `@doc: lex-string` in `src/specs/lexer.l`

### Definition

`STRING` is `"([^"\\\n]|\\.)*"`: text between double quotes, on one line. A backslash followed by any character is accepted (`\"`, `\\`, `\n`); which escapes are valid is checked later. An unclosed `"` or a line break inside a literal is a lexing error.

### Intention

Strings follow Go and Java: one built-in, immutable `str` type with no references, because it is simpler than Rust's `str`/`&str`/`String` (learner decision). Strings created at run time will need a garbage collector or unfreed memory; that is a runtime decision for later.

Since: 2026-11-11
