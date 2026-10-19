%option noyywrap

%{
#undef BEGIN
#define BEGIN(state) ((yy_start) = 1 + 2 * (state))

#include <string>
#include "parser.hpp"
#include "diagnostic.h"

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
    diagEmit(yylloc.first_line, yylloc.first_column, message);
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

"begin"                        { return BEGIN; }
"end"                          { return END; }
"int"                          { return INT; }
"bool"                         { return BOOL; }
"true"                         { return TRUE; }
"false"                        { return FALSE; }
"if"                           { return IF; }
"then"                         { return THEN; }
"else"                         { return ELSE; }
"do"                           { return DO; }
"while"                        { return WHILE; }
"for"                          { return FOR; }
"print"                        { return PRINT; }

{IDENTIFIER}                   {
                                   yylval.text = new std::string(yytext, yyleng);
                                   return IDENTIFIER;
                               }

{DIGIT}+                       {
                                   yylval.text = new std::string(yytext, yyleng);
                                   return CONSTANT;
                               }

[a-zA-Z0-9_]+                  {
                                   return lexicalError(("invalid identifier '" + std::string(yytext) + "'").c_str());
                               }

"=="                           { return EQ_OP; }
"!="                           { return NE_OP; }
"<="                           { return LE_OP; }
">="                           { return GE_OP; }
"&&"                           { return AND_OP; }
"||"                           { return OR_OP; }

"+"                            { return '+'; }
"-"                            { return '-'; }
"*"                            { return '*'; }
"/"                            { return '/'; }
"%"                            { return '%'; }
"="                            { return '='; }
"!"                            { return '!'; }
"<"                            { return '<'; }
">"                            { return '>'; }
"("                            { return '('; }
")"                            { return ')'; }
"{"                            { return '{'; }
"}"                            { return '}'; }
";"                            { return ';'; }
","                            { return ','; }

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
