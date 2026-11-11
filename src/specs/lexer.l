%grmtools { allow_wholeline_comments }
%%
// @doc: lex-skip
// ignore expressions
[ \t\r\n]+    ;
\/\/[^\r\n]*  ;
/\*(?s:.)*?\*/ ;

// @doc: lex-keywords
// keywords (listed before ID so they win length ties)
let      "let"
mut      "mut"
fn       "fn"
int      "int"
bool     "bool"
true     "true"
false    "false"
if       "if"
else     "else"
while    "while"
loop     "loop"
for      "for"
in       "in"
return   "return"
break    "break"
continue "continue"
struct   "struct"
impl     "impl"
use      "use"
mod      "mod"
self     "self"
str      "str"

// @doc: lex-ident-int
[A-Za-z_][A-Za-z0-9_]*  "ID"
[0-9]+                  "INTEGER"

// @doc: lex-string
"([^"\\\n]|\\.)*"     "STRING"

// @doc: lex-operators
// multi-character operators
==   "=="
!=   "!="
>=   ">="
\<=  "<="
&&   "&&"
\|\| "||"
->   "->"
::   "::"
\.\. ".."

// @doc: lex-operators
// single-character operators and punctuation
=    "="
>    ">"
\<   "<"
!    "!"
\+   "+"
-    "-"
\*   "*"
\/   "/"
%    "%"
\.   "."
,    ","
\(   "("
\)   ")"
\{   "{"
\}   "}"
\[   "["
\]   "]"
;    ";"
:    ":"
