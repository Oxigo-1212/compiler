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

    TOK_BEGIN,
    TOK_END,
    TOK_INT,
    TOK_BOOL,
    TOK_TRUE,
    TOK_FALSE,
    TOK_IF,
    TOK_THEN,
    TOK_ELSE,
    TOK_DO,
    TOK_WHILE,
    TOK_FOR,
    TOK_PRINT,

    TOK_EQUAL_EQUAL,
    TOK_NOT_EQUAL,
    TOK_LESS_EQUAL,
    TOK_GREATER_EQUAL
};

std::string tokenText;
%}

DIGIT       [0-9]
IDENT_START [a-zA-Z_]
IDENTIFIER  {IDENT_START}({IDENT_START}|{DIGIT})*

%x BLOCK_COMMENT

%%

[ \t\r]+                       ;
\n                             ;

"//"[^\r\n]*                   ;
"/*"                           { BEGIN(BLOCK_COMMENT); }
<BLOCK_COMMENT>"*/"           { BEGIN(INITIAL); }
<BLOCK_COMMENT>\n             ;
<BLOCK_COMMENT>.              ;
<BLOCK_COMMENT><<EOF>>        {
                                   std::fprintf(
                                       stderr,
                                       "Error: unterminated block comment at line %d\n",
                                       yylineno
                                   );
                                   std::exit(EXIT_FAILURE);
                               }

"begin"                        { return TOK_BEGIN; }
"end"                          { return TOK_END; }
"int"                          { return TOK_INT; }
"bool"                         { return TOK_BOOL; }
"true"                         { return TOK_TRUE; }
"false"                        { return TOK_FALSE; }
"if"                           { return TOK_IF; }
"then"                         { return TOK_THEN; }
"else"                         { return TOK_ELSE; }
"do"                           { return TOK_DO; }
"while"                        { return TOK_WHILE; }
"for"                          { return TOK_FOR; }
"print"                        { return TOK_PRINT; }

{IDENTIFIER}                   {
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