%code requires {
#include "bridge.h"
}

%code provides {
int yylex(YYSTYPE *value, YYLTYPE *location, void *scanner);
void yyerror(YYLTYPE *location, void *scanner, struct ParseContext *context, const char *message);
}

%code {
#include <stdarg.h>
#include <stdlib.h>

static struct AstNode *node(const char *kind, YYLTYPE location, const char *value) {
    return upl_node(kind, value, location.first_line, location.first_column);
}

static struct AstNode *children(struct AstNode *parent, int count, ...) {
    va_list list;
    va_start(list, count);
    for (int i = 0; i < count; ++i) {
        upl_append(parent, va_arg(list, struct AstNode *));
    }
    va_end(list);
    return parent;
}
}

%locations
%define api.pure full
%parse-param {void *scanner} {struct ParseContext *context}
%lex-param {void *scanner}
%define parse.error detailed
%define parse.lac full
%expect 0
%start program

%union {
    struct AstNode *node;
    char *text;
    const char *keyword;
}

%token <text> TOK_IDENTIFIER "identifier"
%token <text> TOK_NUMBER "integer literal"
%token TOK_BEGIN "begin" TOK_END "end"
%token TOK_INT "int" TOK_BOOL "bool"
%token TOK_TRUE "true" TOK_FALSE "false"
%token TOK_IF "if" TOK_THEN "then" TOK_ELSE "else"
%token TOK_DO "do" TOK_WHILE "while" TOK_FOR "for" TOK_PRINT "print"
%token TOK_EQUAL_EQUAL "==" TOK_GREATER_EQUAL ">="

%type <node> program statements statement block declaration assignment
%type <node> if_statement do_statement for_statement for_init
%type <node> expression sum product primary
%type <keyword> type comparison
%destructor { upl_free($$); } <node>
%destructor { free($$); } <text>

%%

program
    : TOK_BEGIN statements TOK_END {
        upl_program(context, $2, @1.first_line, @1.first_column);
        $$ = NULL;
      }
    | TOK_BEGIN statements error TOK_END {
        upl_free($2);
        $$ = NULL;
        yyerrok;
      }
    ;

statements
    : %empty { $$ = node("Block", @$, ""); }
    | statements statement { upl_append($1, $2); $$ = $1; }
    ;

statement
    : declaration terminator { $$ = $1; }
    | assignment terminator { $$ = $1; }
    | if_statement { $$ = $1; }
    | do_statement { $$ = $1; }
    | for_statement { $$ = $1; }
    | TOK_PRINT '(' expression ')' terminator { $$ = children(node("Print", @1, ""), 1, $3); }
    // Synchronize at a statement terminator to report subsequent errors.
    | error ';' { $$ = node("Error", @1, ""); yyerrok; }
    ;

terminator
    : ';'
    // Report a missing semicolon at the next boundary without discarding it.
    | %empty { yyerror(&yylloc, scanner, context, "expected ';' after statement"); }
    ;

block
    : '{' statements '}' {
        $$ = $2;
        upl_locate($$, @1.first_line, @1.first_column);
      }
    | '{' statements error '}' {
        $$ = $2;
        upl_locate($$, @1.first_line, @1.first_column);
        upl_append($$, node("Error", @3, ""));
        yyerrok;
      }
    ;

declaration
    : type TOK_IDENTIFIER {
        $$ = children(node("Declaration", @1, $1), 1, node("Identifier", @2, $2));
        free($2);
      }
    | type TOK_IDENTIFIER '=' expression {
        $$ = children(node("Declaration", @1, $1), 2, node("Identifier", @2, $2), $4);
        free($2);
      }
    ;

type
    : TOK_INT { $$ = "int"; }
    | TOK_BOOL { $$ = "bool"; }
    ;

assignment
    : TOK_IDENTIFIER '=' expression {
        $$ = children(node("Assignment", @1, ""), 2, node("Identifier", @1, $1), $3);
        free($1);
      }
    ;

if_statement
    : TOK_IF '(' expression ')' TOK_THEN block { $$ = children(node("If", @1, ""), 2, $3, $6); }
    | TOK_IF '(' expression ')' TOK_THEN block TOK_ELSE block {
        $$ = children(node("If", @1, ""), 3, $3, $6, $8);
      }
    ;

do_statement
    : TOK_DO block TOK_WHILE '(' expression ')' terminator {
        $$ = children(node("DoWhile", @1, ""), 2, $2, $5);
      }
    ;

for_statement
    : TOK_FOR '(' for_init ';' expression ';' assignment ')' block {
        $$ = children(node("For", @1, ""), 4, $3, $5, $7, $9);
      }
    ;

for_init
    : declaration { $$ = $1; }
    | assignment { $$ = $1; }
    ;

expression
    : sum { $$ = $1; }
    | sum comparison sum { $$ = children(node("Binary", @2, $2), 2, $1, $3); }
    ;

comparison
    : '>' { $$ = ">"; }
    | TOK_GREATER_EQUAL { $$ = ">="; }
    | TOK_EQUAL_EQUAL { $$ = "=="; }
    ;

sum
    : product { $$ = $1; }
    | sum '+' product { $$ = children(node("Binary", @2, "+"), 2, $1, $3); }
    ;

product
    : primary { $$ = $1; }
    | product '*' primary { $$ = children(node("Binary", @2, "*"), 2, $1, $3); }
    ;

primary
    : TOK_IDENTIFIER { $$ = node("Identifier", @1, $1); free($1); }
    | TOK_NUMBER { $$ = node("Integer", @1, $1); free($1); }
    | TOK_TRUE { $$ = node("Boolean", @1, "true"); }
    | TOK_FALSE { $$ = node("Boolean", @1, "false"); }
    | '(' expression ')' { $$ = $2; }
    ;

%%

void yyerror(YYLTYPE *location, void *scanner, struct ParseContext *context, const char *message) {
    (void)scanner;
    upl_diagnostic(context, 0, location->first_line, location->first_column, message, NULL);
}
