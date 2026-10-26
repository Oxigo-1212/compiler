%grmtools { allow_wholeline_comments }
%%
// ignore expressions
[ \t\r\n]+    ;
\/\/[^\r\n]*  ;
/\*(?s:.)*?\*/ ;

let    "let"
fn     "fn"
int    "int"
bool   "bool"
true   "true"
false  "false"
if     "if"
else   "else"
do     "do"
while  "while"
for    "for"
print  "print"
struct "struct"
,      ","

[A-Za-z]+[0-9]*  "ID"
[0-9]+           "INTEGER"

==  "=="
>=  ">="
=   "="
>   ">"
\+  "+"
\*  "*"
\(  "("
\)  ")"
\{  "{"
\}  "}"
;   ";"
:   ":"
