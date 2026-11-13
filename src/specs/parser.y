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
FieldInits -> Result<Vec<FieldInit>, ()>:
      FieldInit {  Ok(vec![$1?])  }
    | FieldInits ',' FieldInit {
																let mut vf = $1?; 
																vf.push($3?);
																Ok(vf)
															 }
    ;
FieldInit -> Result<FieldInit, ()>:
      'ID' ':' Expr { Ok(FieldInit::new(convert_lexeme($lexer, $1)?, $span, $3?)) }
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
      Path { Ok(Expr::Path($1?)) }  // every name is a Path; name resolution decides what it means
    | 'INTEGER' { Ok(Expr::Lit(Literal::Int(convert_number($lexer, $1)?))) }
    | 'STRING' { Ok(Expr::Lit(Literal::Str(unescape(convert_lexeme($lexer, $1)?)?)))}  
    | 'true' { Ok(Expr::Lit(Literal::Bool(true))) }
    | 'false' { Ok(Expr::Lit(Literal::Bool(false))) }
    | 'self' { Ok(Expr::SelfValue) }
    | '(' Expr ')' { $2 }
    | '.' '{' FieldInits '}' { Err(()) }
    | '.' '{' FieldInits ',' '}' { Err(()) }
    | '.' '{' '}' { Err(()) }
    | '[' ElementList ']' { Err(()) }
    | '[' ElementList ',' ']' { Err(()) }
    ;

// ---- operators ----
// @doc: postfix-primary
Postfix -> Result<Expr, ()>:
      Postfix '(' Args ')' { Err(()) }  // TODO: Call
    | Postfix '.' 'ID' { Err(()) }  // TODO: Field
    | Postfix '[' Expr ']' { Err(()) }  // TODO: Index
    | Primary { $1 }
    ;
UnaryOperation -> Result<Expr, ()>:
      '-' UnaryOperation { Err(()) }  // TODO: Unary
    | '!' UnaryOperation { Err(()) }  // TODO: Unary
    | Postfix { $1 }
    ;
// @doc: expr-precedence
BinaryOperation -> Result<Expr, ()>:
      BinaryOperation '||' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '&&' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '==' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '!=' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '<' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '<=' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '>' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '>=' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '+' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '-' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '*' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '/' BinaryOperation { Err(()) }  // TODO: Binary
    | BinaryOperation '%' BinaryOperation { Err(()) }  // TODO: Binary
    | UnaryOperation { $1 }
    ;
// @doc: simple-op
SimpleOperation -> Result<Expr, ()>:
      BinaryOperation { $1 }
    | BinaryOperation '=' Expr { Err(()) }  // TODO: Assign
    | BinaryOperation '..' BinaryOperation { Err(()) }  // TODO: Range
    | 'return' { Err(()) }  // TODO: Return
    | 'return' BinaryOperation { Err(()) }  // TODO: Return
    ;

// ---- expressions ----
// @doc: if
If -> Result<Expr, ()>:
      'if' Expr Block { Err(()) }  // TODO: If
    | 'if' Expr Block 'else' Block { Err(()) }  // TODO: If
    | 'if' Expr Block 'else' If { Err(()) }  // TODO: If
    ;
// @doc: block-like
// BlockLike expressions need no ';' as statements and are never operands,
// which keeps `if a {} -x` from being ambiguous.
BlockLike -> Result<Expr, ()>:
      If { $1 }
    | Block { $1 }
    ;
Expr -> Result<Expr, ()>:
      BlockLike { $1 }
    | SimpleOperation { $1 }
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
Block -> Result<Expr, ()>:
      '{' Stmts '}' { Err(()) }  // TODO: Block
    | '{' Stmts SimpleOperation '}' { Err(()) }  // TODO: Block
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
use crate::ast::{Type, Path, Expr, Literal, FieldInit};
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
// Turns a STRING token's text into its value: drops the surrounding quotes and
// translates escapes. Contract: Literal::Str always holds this decoded text.
fn unescape(raw: String) -> Result<String, ()> {
    let inner = &raw[1..raw.len() - 1];   // drop the surrounding quotes
    let mut out = String::new();
    let mut chars = inner.chars();

    while let Some(c) = chars.next() {
        if c == BACKSLASH {
            let escaped = chars.next().ok_or(())?;   // the char after the backslash
            out.push(translate_escape(escaped)?);
        } else {
            out.push(c);
        }
    }
    Ok(out)
}

const BACKSLASH: char = '\\';   // Rust writes one backslash as '\\'

// `\n` → newline, `\t` → tab, `\\` → backslash, `\"` → quote. Anything else is an error.
fn translate_escape(c: char) -> Result<char, ()> {
    match c {
        'n' => Ok('\n'),
        't' => Ok('\t'),
        '\\' => Ok('\\'),
        '"' => Ok('"'),
        other => {
            eprintln!("unknown escape \\{other}");
            Err(())
        }
    }
}
