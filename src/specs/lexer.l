%option noyywrap reentrant bison-bridge bison-locations noinput nounput
%option extra-type="struct LexerState *"

%{
#include "parser.h"

static void locateToken(YYLTYPE *location, const char *text, int length, struct LexerState *state) {
    location->first_line = state->line;
    location->first_column = state->column;
    for (int i = 0; i < length; ++i) {
        location->last_line = state->line;
        location->last_column = state->column;
        if (text[i] == '\r') {
            ++state->line;
            state->column = 1;
        } else if (text[i] == '\n') {
            if (!state->after_carriage_return) ++state->line;
            state->column = 1;
        } else {
            ++state->column;
        }
        state->after_carriage_return = text[i] == '\r';
    }
}

static int lexicalError(struct LexerState *state, YYLTYPE *location, const char *message, const char *text) {
    upl_diagnostic(state->context, 1, location->first_line, location->first_column, message, text);
    return YYerror; // The diagnostic is already emitted; let Bison recover.
}

#define YY_USER_ACTION locateToken(yylloc, yytext, yyleng, yyextra);
%}

DIGIT       [0-9]
LETTER      [a-zA-Z]
IDENTIFIER  {LETTER}+{DIGIT}*

%x BLOCK_COMMENT

%%

[ \t\r\n]+                    ;

"//"[^\r\n]*                   ;
"/*"                           { yyextra->comment_line = yylloc->first_line;
                                 yyextra->comment_column = yylloc->first_column;
                                 BEGIN(BLOCK_COMMENT); }
<BLOCK_COMMENT>"*/"           { BEGIN(INITIAL); }
<BLOCK_COMMENT>\n             ;
<BLOCK_COMMENT>.              ;
<BLOCK_COMMENT><<EOF>>        {
                                   BEGIN(INITIAL);
                                   yylloc->first_line = yyextra->comment_line;
                                   yylloc->first_column = yyextra->comment_column;
                                   return lexicalError(yyextra, yylloc, "unterminated block comment", NULL);
                               }
<INITIAL><<EOF>>               {
                                   *yylloc = (YYLTYPE){yyextra->line, yyextra->column, yyextra->line, yyextra->column};
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
                                   yylval->text = malloc((size_t)yyleng + 1);
                                   if (!yylval->text) YY_FATAL_ERROR("out of memory copying token");
                                   memcpy(yylval->text, yytext, (size_t)yyleng + 1);
                                   return TOK_IDENTIFIER;
                               }

{DIGIT}+                       {
                                   yylval->text = malloc((size_t)yyleng + 1);
                                   if (!yylval->text) YY_FATAL_ERROR("out of memory copying token");
                                   memcpy(yylval->text, yytext, (size_t)yyleng + 1);
                                   return TOK_NUMBER;
                               }

[a-zA-Z0-9_]+                  {
                                   return lexicalError(yyextra, yylloc, "invalid identifier", yytext);
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
                                   return lexicalError(yyextra, yylloc, "unexpected character", yytext);
                               }

%%
