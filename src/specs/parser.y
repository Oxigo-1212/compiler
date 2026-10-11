%{
#include <cstdio>
#include "ast.h"

extern int yylex();
void yyerror(const char *message);
int syntaxErrors = 0;
std::unique_ptr<AstNode> astRoot;
%}

%code requires {
#include "ast.h"
}

%code provides {
extern int syntaxErrors;
extern int lexicalErrors;
extern std::unique_ptr<AstNode> astRoot;
void resetLexer();
}

%code {
static AstNode *node(const char *kind, const YYLTYPE &location,
                     std::string value = "",
                     std::initializer_list<AstNode *> children = {}) {
    auto result = new AstNode{kind, std::move(value), location.first_line,
                              location.first_column, {}};
    for (auto child : children) {
        result->children.emplace_back(child);
    }
    return result;
}
}

%locations
%define parse.error detailed
%define parse.lac full
%expect 0
%start program

%union {
    AstNode *node;
    std::string *text;
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
%destructor { delete $$; } <node> <text>

%%

program
    : TOK_BEGIN statements TOK_END {
        $2->kind = "Program";
        $2->line = @1.first_line;
        $2->column = @1.first_column;
        astRoot.reset($2);
        $$ = nullptr;
      }
    | TOK_BEGIN statements error TOK_END {
        delete $2;
        $$ = nullptr;
        yyerrok;
      }
    ;

statements
    : %empty { $$ = node("Block", @$); }
    | statements statement { $1->children.emplace_back($2); $$ = $1; }
    ;

statement
    : declaration terminator { $$ = $1; }
    | assignment terminator { $$ = $1; }
    | if_statement { $$ = $1; }
    | do_statement { $$ = $1; }
    | for_statement { $$ = $1; }
    | TOK_PRINT '(' expression ')' terminator { $$ = node("Print", @1, "", {$3}); }
    // Synchronize at a statement terminator to report subsequent errors.
    | error ';' { $$ = node("Error", @1); yyerrok; }
    ;

terminator
    : ';'
    // Report a missing semicolon at the next boundary without discarding it.
    | %empty { yyerror("expected ';' after statement"); }
    ;

block
    : '{' statements '}' {
        $$ = $2;
        $$->line = @1.first_line;
        $$->column = @1.first_column;
      }
    | '{' statements error '}' {
        $$ = $2;
        $$->line = @1.first_line;
        $$->column = @1.first_column;
        $$->children.emplace_back(node("Error", @3));
        yyerrok;
      }
    ;

declaration
    : type TOK_IDENTIFIER {
        $$ = node("Declaration", @1, $1, {node("Identifier", @2, std::move(*$2))});
        delete $2;
      }
    | type TOK_IDENTIFIER '=' expression {
        $$ = node("Declaration", @1, $1, {node("Identifier", @2, std::move(*$2)), $4});
        delete $2;
      }
    ;

type
    : TOK_INT { $$ = "int"; }
    | TOK_BOOL { $$ = "bool"; }
    ;

assignment
    : TOK_IDENTIFIER '=' expression {
        $$ = node("Assignment", @1, "", {node("Identifier", @1, std::move(*$1)), $3});
        delete $1;
      }
    ;

if_statement
    : TOK_IF '(' expression ')' TOK_THEN block { $$ = node("If", @1, "", {$3, $6}); }
    | TOK_IF '(' expression ')' TOK_THEN block TOK_ELSE block {
        $$ = node("If", @1, "", {$3, $6, $8});
      }
    ;

do_statement
    : TOK_DO block TOK_WHILE '(' expression ')' terminator {
        $$ = node("DoWhile", @1, "", {$2, $5});
      }
    ;

for_statement
    : TOK_FOR '(' for_init ';' expression ';' assignment ')' block {
        $$ = node("For", @1, "", {$3, $5, $7, $9});
      }
    ;

for_init
    : declaration { $$ = $1; }
    | assignment { $$ = $1; }
    ;

expression
    : sum { $$ = $1; }
    | sum comparison sum { $$ = node("Binary", @2, $2, {$1, $3}); }
    ;

comparison
    : '>' { $$ = ">"; }
    | TOK_GREATER_EQUAL { $$ = ">="; }
    | TOK_EQUAL_EQUAL { $$ = "=="; }
    ;

sum
    : product { $$ = $1; }
    | sum '+' product { $$ = node("Binary", @2, "+", {$1, $3}); }
    ;

product
    : primary { $$ = $1; }
    | product '*' primary { $$ = node("Binary", @2, "*", {$1, $3}); }
    ;

primary
    : TOK_IDENTIFIER { $$ = node("Identifier", @1, std::move(*$1)); delete $1; }
    | TOK_NUMBER { $$ = node("Integer", @1, std::move(*$1)); delete $1; }
    | TOK_TRUE { $$ = node("Boolean", @1, "true"); }
    | TOK_FALSE { $$ = node("Boolean", @1, "false"); }
    | '(' expression ')' { $$ = $2; }
    ;

%%

void yyerror(const char *message) {
    ++syntaxErrors;
    std::fprintf(stderr, "Syntax error at line %d, column %d: %s\n",
                 yylloc.first_line, yylloc.first_column, message);
}
