%option noyywrap

%{
#include <cstdio>
#include <string>
#include "parser.hpp"

int lexicalErrors = 0;
static int sourceLine = 1;
static int sourceColumn = 1;
static bool afterCarriageReturn = false;
static YYLTYPE commentStart;

static void locateToken() {
    yylloc.first_line = sourceLine;
    yylloc.first_column = sourceColumn;
    for (int i = 0; i < yyleng; ++i) {
        yylloc.last_line = sourceLine;
        yylloc.last_column = sourceColumn;
        if (yytext[i] == '\r') {
            ++sourceLine;
            sourceColumn = 1;
        } else if (yytext[i] == '\n') {
            if (!afterCarriageReturn) ++sourceLine;
            sourceColumn = 1;
        } else {
            ++sourceColumn;
        }
        afterCarriageReturn = yytext[i] == '\r';
    }
}

static int lexicalError(const char *message) {
    ++lexicalErrors;
    std::fprintf(stderr, "Lexical error at line %d, column %d: %s\n",
                 yylloc.first_line, yylloc.first_column, message);
    return YYerror; // The diagnostic is already emitted; let Bison recover.
}

#define YY_USER_ACTION locateToken();
%}

DIGIT       [0-9]
LETTER      [a-zA-Z]
IDENTIFIER  {LETTER}+{DIGIT}*

%x BLOCK_COMMENT

%%

[ \t\r\n]+                    ;

"//"[^\r\n]*                   ;
"/*"                           { commentStart = yylloc; BEGIN(BLOCK_COMMENT); }
<BLOCK_COMMENT>"*/"           { BEGIN(INITIAL); }
<BLOCK_COMMENT>\n             ;
<BLOCK_COMMENT>.              ;
<BLOCK_COMMENT><<EOF>>        {
                                   BEGIN(INITIAL);
                                   yylloc = commentStart;
                                   return lexicalError("unterminated block comment");
                               }
<INITIAL><<EOF>>               {
                                   yylloc = {sourceLine, sourceColumn, sourceLine, sourceColumn};
                                   return 0;
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
                                   yylval.text = new std::string(yytext, yyleng);
                                   return TOK_IDENTIFIER;
                               }

{DIGIT}+                       {
                                   yylval.text = new std::string(yytext, yyleng);
                                   return TOK_NUMBER;
                               }

[a-zA-Z0-9_]+                  {
                                   return lexicalError(("invalid identifier '" + std::string(yytext) + "'").c_str());
                               }

"=="                           { return TOK_EQUAL_EQUAL; }
">="                           { return TOK_GREATER_EQUAL; }

"+"                            { return '+'; }
"*"                            { return '*'; }
"="                            { return '='; }
">"                            { return '>'; }
"("                            { return '('; }
")"                            { return ')'; }
"{"                            { return '{'; }
"}"                            { return '}'; }
";"                            { return ';'; }

.                              {
                                   return lexicalError(("unexpected character '" + std::string(yytext) + "'").c_str());
                               }

%%

void resetLexer() {
    sourceLine = 1;
    sourceColumn = 1;
    afterCarriageReturn = false;
    lexicalErrors = 0;
    BEGIN(INITIAL);
}
