%grmtools{yacckind: Grmtools}
%start Program
// @doc: expr-precedence
%left '||'
%left '&&'
%nonassoc '==' '!=' '<' '<=' '>' '>='
%left '+' '-'
%left '*' '/' '%'
%%
// Rules are ordered bottom-up: primitives first, Program last.

// ---- types ----
// @doc: type
Type -> Result<Type, ()>: 'int' { Ok(Type::Int32) }
												| 'bool'{ Ok(Type::Bool) }
												| 'str' { Ok(Type::Str) }
												| 'ID'  { 
																	Ok(Type::Name(convert_lexeme($lexer, $1)?))
																}
												| '[' Type ',' 'INTEGER' ']'{ 
																											let type_elem = $2?; 
																											let size = convert_number($lexer, $4)?;
																											Ok(Type::Array(Box::new(type_elem), size))
																										};

// ---- primitives ----
Path -> Result<Path , ()>: 
		'ID' { 
						Ok(Path::new(convert_lexeme($lexer, $1)?, $span))
				 } 
		| Path '::' 'ID'{
		let mut p = $1?; p.add_path(convert_lexeme($lexer, $3)?, $span);
		Ok(p)
		};
// @doc: struct-literal
FieldInits -> ():
      FieldInit { }
    | FieldInits ',' FieldInit { }
    ;
FieldInit -> ():
      'ID' ':' Expr { }
    ;
ArgList -> ():
      Expr { }
    | ArgList ',' Expr { }
    ;
Args -> ():
      /* empty */ { }
    | ArgList { }
    | ArgList ',' { }
    ;
// `[]` is forbidden: an array literal has at least one element.
// @doc: array-literal
// Array elements; separate from ArgList (call arguments) by meaning.
ElementList -> ():
      Expr { }
    | ElementList ',' Expr { }
    ;

Primary -> Result<Expr, ()>:
      Path { Err(()) }  // TODO: Var vs one-segment Path not decided
    | 'INTEGER' { Ok(Expr::Lit(Literal::Int(convert_number($lexer, $1)?))) }
    | 'STRING' { Err(()) }  // TODO: keep or strip quotes, decode escapes
    | 'true' { Ok(Expr::Lit(Literal::Bool(true))) }
    | 'false' { Ok(Expr::Lit(Literal::Bool(false))) }
    | 'self' { Ok(Expr::SelfValue) }
    | '(' Expr ')' { Err(()) }  // TODO: return $2 once Expr returns Expr
    | '.' '{' FieldInits '}' { Err(()) }
    | '.' '{' FieldInits ',' '}' { Err(()) }
    | '.' '{' '}' { Err(()) }
    | '[' ElementList ']' { Err(()) }
    | '[' ElementList ',' ']' { Err(()) }
    ;

// ---- operators ----
// @doc: postfix-primary
Postfix -> ():
      Postfix '(' Args ')' { }
    | Postfix '.' 'ID' { }
    | Postfix '[' Expr ']' { }
    | Primary { }
    ;
UnaryOperation -> ():
      '-' UnaryOperation { }
    | '!' UnaryOperation { }
    | Postfix { }
    ;
// @doc: expr-precedence
BinaryOperation -> ():
      BinaryOperation '||' BinaryOperation { }
    | BinaryOperation '&&' BinaryOperation { }
    | BinaryOperation '==' BinaryOperation { }
    | BinaryOperation '!=' BinaryOperation { }
    | BinaryOperation '<' BinaryOperation { }
    | BinaryOperation '<=' BinaryOperation { }
    | BinaryOperation '>' BinaryOperation { }
    | BinaryOperation '>=' BinaryOperation { }
    | BinaryOperation '+' BinaryOperation { }
    | BinaryOperation '-' BinaryOperation { }
    | BinaryOperation '*' BinaryOperation { }
    | BinaryOperation '/' BinaryOperation { }
    | BinaryOperation '%' BinaryOperation { }
    | UnaryOperation { }
    ;
// @doc: simple-op
SimpleOperation -> ():
      BinaryOperation { }
    | BinaryOperation '=' Expr { }
    | BinaryOperation '..' BinaryOperation { }
    | 'return' { }
    | 'return' BinaryOperation { }
    ;

// ---- expressions ----
// @doc: if
If -> ():
      'if' Expr Block { }
    | 'if' Expr Block 'else' Block { }
    | 'if' Expr Block 'else' If { }
    ;
// @doc: block-like
// BlockLike expressions need no ';' as statements and are never operands,
// which keeps `if a {} -x` from being ambiguous.
BlockLike -> ():
      If { }
    | Block { }
    ;
Expr -> ():
      BlockLike { }
    | SimpleOperation { }
    ;

// ---- statements ----
// @doc: let
Let -> ():
      'let' 'ID' ':' Type '=' Expr ';' { }
    | 'let' 'mut' 'ID' ':' Type '=' Expr ';' { }
    ;
// @doc: loop-stmt
// Loops and loop jumps are statements: they produce no value.
While -> ():
      'while' Expr Block { }
    ;
Loop -> ():
      'loop' Block { }
    ;
For -> ():
      'for' 'ID' 'in' Expr Block { }
    ;
LoopStmt -> ():
      While { }
    | Loop { }
    | For { }
    | 'break' ';' { }
    | 'continue' ';' { }
    ;
// @doc: block
// A block ends with an optional value expression (no ';').
Stmt -> ():
      Let { }
    | SimpleOperation ';' { }
    | BlockLike { }
    | LoopStmt { }
    | ';' { }
    ;
Stmts -> ():
      /* empty */ { }
    | Stmts Stmt { }
    ;
Block -> ():
      '{' Stmts '}' { }
    | '{' Stmts SimpleOperation '}' { }
    ;

// ---- items ----
// @doc: method-self
// `self` may only be the first parameter; a function without it is static.
Param -> ():
      'ID' ':' Type { }
    ;
ParamList -> ():
      Param { }
    | ParamList ',' Param { }
    ;
Params -> ():
      /* empty */ { }
    | ParamList { }
    | ParamList ',' { }
    | 'self' { }
    | 'self' ',' { }
    | 'self' ',' ParamList { }
    | 'self' ',' ParamList ',' { }
    ;
// @doc: function
Function -> ():
      'fn' 'ID' '(' Params ')' Block { }
    | 'fn' 'ID' '(' Params ')' '->' Type Block { }
    ;
// @doc: struct
StructFields -> ():
      StructFields ',' 'ID' ':' Type { }
    | 'ID' ':' Type { }
    ;
Struct -> ():
      'struct' 'ID' '{' StructFields '}' { }
    | 'struct' 'ID' '{' StructFields ',' '}' { }
    | 'struct' 'ID' '{' '}' { }
    ;
// @doc: impl-use-mod
Functions -> ():
      /* empty */ { }
    | Functions Function { }
    ;
Impl -> ():
      'impl' 'ID' '{' Functions '}' { }
    ;
Use -> ():
      'use' Path ';' { }
    ;
Mod -> ():
      'mod' 'ID' ';' { }
    | 'mod' 'ID' '{' ItemList '}' { }
    | 'mod' 'ID' '{' '}' { }
    ;

// ---- program ----
// @doc: items
Item -> ():
      Function { }
    | Struct { }
    | Impl { }
    | Use { }
    | Mod { }
    | Let { }
    ;
ItemList -> ():
      ItemList Item { }
    | Item { }
    ;
Program -> ():
      ItemList { }
    ;
%%
use crate::ast::{Type, Path, Expr, Literal};
use lrlex::{DefaultLexeme, DefaultLexerTypes};
use lrpar::NonStreamingLexer; // Lexeme is already imported by the generated parser

fn convert_lexeme(lexer: &dyn NonStreamingLexer<DefaultLexerTypes>, //interface
									tok: Result<DefaultLexeme, DefaultLexeme>) -> Result<String, ()> {
				let tok = tok.map_err(|_| ())?;
				Ok(lexer.span_str(tok.span()).to_string())
}
fn convert_number(lexer: &dyn NonStreamingLexer<DefaultLexerTypes>,
									tok: Result<DefaultLexeme, DefaultLexeme>) -> Result<u64, ()>{
							convert_lexeme(lexer, tok)?.parse::<u64>().map_err(|_| ())
}
