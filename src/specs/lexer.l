%option noyywrap
%option yylineno

%{
#include <cstdio>
#include <cstdlib>
#include <string>

enum Token {
    TOK_EOF = 0,
    TOK_IDENTIFIER = 256,
    TOK_NUMBER,
    TOK_STRING,

    TOK_VAL,
    TOK_RETURN,
    TOK_IF,
    TOK_ELSE,

    TOK_EQUAL_EQUAL,
    TOK_NOT_EQUAL,
    TOK_LESS_EQUAL,
    TOK_GREATER_EQUAL
};

std::string tokenText;
%}

DIGIT       [0-9]
IDENT_START [a-zA-Z_]
IDENT_CHAR  [a-zA-Z0-9_]

%%

[ \t\r]+                       ;
\n                             ;

"//".*                         ;

"val"                          { return TOK_VAL; }
"return"                       { return TOK_RETURN; }
"if"                           { return TOK_IF; }
"else"                         { return TOK_ELSE; }

{IDENT_START}{IDENT_CHAR}*     {
                                   tokenText = yytext;
                                   return TOK_IDENTIFIER;
                               }

{DIGIT}+(\.{DIGIT}+)?          {
                                   tokenText = yytext;
                                   return TOK_NUMBER;
                               }

\"([^\"\\]|\\.)*\"             {
                                   tokenText = yytext;
                                   return TOK_STRING;
                               }

"=="                           { return TOK_EQUAL_EQUAL; }
"!="                           { return TOK_NOT_EQUAL; }
"<="                           { return TOK_LESS_EQUAL; }
">="                           { return TOK_GREATER_EQUAL; }

"+"                            { return '+'; }
"-"                            { return '-'; }
"*"                            { return '*'; }
"/"                            { return '/'; }
"="                            { return '='; }
"!"                            { return '!'; }
"<"                            { return '<'; }
">"                            { return '>'; }
"("                            { return '('; }
")"                            { return ')'; }
"{"                            { return '{'; }
"}"                            { return '}'; }
","                            { return ','; }
";"                            { return ';'; }

.                              {
                                   std::fprintf(
                                       stderr,
                                       "Unexpected character '%s' on line %d\n",
                                       yytext,
                                       yylineno
                                   );
                                   std::exit(EXIT_FAILURE);
                               }

%%