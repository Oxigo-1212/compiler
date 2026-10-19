%{
#include <cstdio>
#include "ast.h"
#include "diagnostic.h"

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
    /**
    * Creates an AST node with source location, optional value, and child nodes.
    *
    * @param kind Node classification stored in the AST.
    * @param location Source location associated with the node.
    * @param value Optional textual value for the node.
    * @param children Child nodes transferred to the created node.
    * @return A newly allocated AST node.
    */
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

%token <text> IDENTIFIER "identifier"
%token <text> CONSTANT "integer literal"
%token BEGIN "begin" END "end"
%token INT "int" BOOL "bool"
%token TRUE "true" FALSE "false"
%token IF "if" THEN "then" ELSE "else"
%token DO "do" WHILE "while" FOR "for" PRINT "print"
%token EQ_OP "==" NE_OP "!=" LE_OP "<=" GE_OP ">="
%token AND_OP "&&" OR_OP "||"

%type <node> program statements statement block declaration assignment
%type <node> if_statement do_statement for_statement for_init
%type <node> expression sum product primary
%type <keyword> type comparison
%destructor { delete $$; } <node> <text>

%%

program
    : BEGIN statements END {
        $2->kind = "Program";
        $2->line = @1.first_line;
        $2->column = @1.first_column;
        astRoot.reset($2);
        $$ = nullptr;
      }
    | BEGIN statements error END {
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
    | PRINT '(' expression ')' terminator { $$ = node("Print", @1, "", {$3}); }
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
    : type IDENTIFIER {
        $$ = node("Declaration", @1, $1, {node("Identifier", @2, std::move(*$2))});
        delete $2;
      }
    | type IDENTIFIER '=' expression {
        $$ = node("Declaration", @1, $1, {node("Identifier", @2, std::move(*$2)), $4});
        delete $2;
      }
    ;

type
    : INT { $$ = "int"; }
    | BOOL { $$ = "bool"; }
    ;

assignment
    : IDENTIFIER '=' expression {
        $$ = node("Assignment", @1, "", {node("Identifier", @1, std::move(*$1)), $3});
        delete $1;
      }
    ;

if_statement
    : IF '(' expression ')' THEN block { $$ = node("If", @1, "", {$3, $6}); }
    | IF '(' expression ')' THEN block ELSE block {
        $$ = node("If", @1, "", {$3, $6, $8});
      }
    ;

do_statement
    : DO block WHILE '(' expression ')' terminator {
        $$ = node("DoWhile", @1, "", {$2, $5});
      }
    ;

for_statement
    : FOR '(' for_init ';' expression ';' assignment ')' block {
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
    | GE_OP { $$ = ">="; }
    | EQ_OP { $$ = "=="; }
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
    : IDENTIFIER { $$ = node("Identifier", @1, std::move(*$1)); delete $1; }
    | CONSTANT { $$ = node("Integer", @1, std::move(*$1)); delete $1; }
    | TRUE { $$ = node("Boolean", @1, "true"); }
    | FALSE { $$ = node("Boolean", @1, "false"); }
    | '(' expression ')' { $$ = $2; }
    ;

%%

/**
 * Records and reports a syntax error emitted by the parser.
 *
 * @param message Description of the syntax error.
 */
void yyerror(const char *message) {
    ++syntaxErrors;
    diagEmit(yylloc.first_line, yylloc.first_column, message);
}
