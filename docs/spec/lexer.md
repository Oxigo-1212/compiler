# Tokens

Purpose: defines how the lexer cuts UPL source text into tokens.

Reader: developers of the UPL compiler frontend.

Updated: 2026-11-17.

Level 0: the lexer. The lexer cuts the source text into tokens, and the parser reads only tokens. The rules are in `src/specs/lexer.l`.

How the lexer picks a rule: it takes the longest match, and when two rules match the same length, the earlier rule wins.

## Skipped text

### Intuition

Some text is only for the reader: spaces, line breaks and comments. The lexer drops it, so the parser never sees it.

### Definition

```text
[ \t\r\n]+       ;    // space, tab, line breaks
\/\/[^\r\n]*     ;    // `//` comment, until the end of the line
/\*(?s:.)*?\*/   ;    // `/* ... */` comment
```

A rule with `;` instead of a token name produces no token.

- Block comments do not nest: the first `*/` ends the comment.
- An unclosed `/*` is not a lexer error. It lexes as `/` then `*`, and the parser reports the error.

### Example

```text
let x: int = 1;   // this comment is dropped
/* so is this one */
```

### Design reasons

Not yet reviewed.

Since: 2026-11-11

## Keywords

### Intuition

A keyword is a word that the language reserves for itself, so it cannot be used as a name.

### Definition

```text
let mut fn int bool true false if else while loop for in
return break continue struct impl use mod self str
pub root export as const static
```

Each keyword is its own token. The keyword rules come before the `ID` rule, so on a tie the keyword wins: `let` is a keyword, but `letter` is an `ID`, because `letter` is the longer match.

### Design reasons

Not yet reviewed.

Since: 2026-11-11

## Names and integers

### Intuition

A name (`ID`) labels a variable, function, field or type. An integer (`INTEGER`) is a number written in the source.

### Definition

```text
[A-Za-z_][A-Za-z0-9_]*   "ID"
[0-9]+                   "INTEGER"
```

- A name starts with a letter or `_`, followed by letters, digits or `_`.
- An integer is one or more digits, with no sign. In `-5`, the `-` is a separate operator token.

### Example

```text
x   _tmp   point2   my_var     // ID
0   42     1000                // INTEGER
```

### Design reasons

The name rule is wider than the original UPL rule `[A-Za-z]+[0-9]*`: here `_` and digits may appear anywhere after the first character. Other choices: not yet reviewed.

Since: 2026-11-11

## Operators

### Intuition

Operators and punctuation are the symbols between names and values: `+`, `==`, `(`, `;` and so on.

### Definition

| Kind | Tokens |
|:---|:---|
| Two characters | `== != >= <= && \|\| -> :: ..` |
| One character | `= > < ! + - * / % . , ( ) { } [ ] ; :` |

Because the lexer takes the longest match, `==` is one token, not two `=` tokens.

### Design reasons

Not yet reviewed.

Since: 2026-11-11

## Strings

### Intuition

A string is text written between double quotes. A backslash writes a character that cannot be typed directly, such as a newline.

### Definition

```text
"([^"\\\n]|\\.)*"   "STRING"
```

- A string is text between double quotes, on one line.
- The lexer accepts a backslash followed by any character. It does not decide which escapes are valid.
- An unclosed `"`, or a line break inside the string, is a lexer error.

The parser's `'STRING'` action decodes the token with `unescape` (after the second `%%` in `src/specs/parser.y`). It removes the quotes and turns each escape into one character:

| Escape | Becomes |
|:---|:---|
| `\n` | newline |
| `\t` | tab |
| `\\` | one backslash |
| `\"` | a double quote |
| anything else | error: `unknown escape \q` |

### Example

```text
"hello"
"line one\nline two"
"she said \"hi\""
```

### Notions used

- **`Literal::Str`** is the AST node for a string. It always holds the decoded text, never the quotes or the raw escapes, so later passes must not decode it again. A newline is one character (byte 10) in the stored string; Rust's `{:?}` only displays it as `\n`.

### Design reasons

- Strings follow Go and Java: one built-in, immutable `str` type with no references. Rust instead has three: `str`, `&str` and `String`.
- Escapes are decoded in the parser, as rustc does, not kept raw as Go does.
- Strings created at run time will need a garbage collector, or memory that is never freed. That runtime decision is not made yet.

Since: 2026-11-11
