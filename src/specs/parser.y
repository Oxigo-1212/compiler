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
												| Path { Ok(Type::Name($1?)) }
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
		// `root` may only be the first segment: the path is then resolved from the root module.
		| 'root' '::' 'ID' {
						let mut p = Path::new(convert_lexeme($lexer, $1)?, $span);
						p.add_path(convert_lexeme($lexer, $3)?, $span);
						Ok(p)
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
ArgList -> Result<Vec<Expr>, ()>:
      Expr { Ok(vec![$1?]) }
    | ArgList ',' Expr { 
													let mut vec_expr = $1?;
													vec_expr.push($3?);
													Ok(vec_expr)
											 }
    ;
Args -> Result<Vec<Expr>, ()>:
      /* empty */ { Ok(vec![]) }
    | ArgList { Ok($1?) }
    | ArgList ',' { Ok($1?) }
    ;
// `[]` is forbidden: an array literal has at least one element.
// @doc: array-literal
// Array elements; separate from ArgList (call arguments) by meaning.
ElementList -> Result<Vec<Expr>, ()>:
      Expr { Ok(vec![$1?]) }
    | ElementList ',' Expr {
															let mut array = $1?;
															array.push($3?);
															Ok(array)
													 }
    ;

Primary -> Result<Expr, ()>:
      Path { Ok(Expr::Path($1?)) }  // every name is a Path; name resolution decides what it means
    | 'INTEGER' { Ok(Expr::Lit(Literal::Int(convert_number($lexer, $1)?))) }
    | 'STRING' { Ok(Expr::Lit(Literal::Str(unescape(convert_lexeme($lexer, $1)?)?)))}  
    | 'true' { Ok(Expr::Lit(Literal::Bool(true))) }
    | 'false' { Ok(Expr::Lit(Literal::Bool(false))) }
    | 'self' { Ok(Expr::SelfValue($span)) }
    | '(' Expr ')' { $2 }
    | '.' '{' FieldInits '}' { Ok(Expr::FieldInits($3?)) }
    | '.' '{' FieldInits ',' '}' { Ok(Expr::FieldInits($3?)) }
    | '.' '{' '}' { Ok(Expr::FieldInits(vec![])) }
    | '[' ElementList ']' { Ok(Expr::Array($2?)) }
    | '[' ElementList ',' ']' { Ok(Expr::Array($2?)) }
    ;

// ---- operators ----
// @doc: postfix-primary
Postfix -> Result<Expr, ()>:
      Postfix '(' Args ')' { Ok(Expr::Call(Box::new($1?), $3?)) }
    | Postfix '.' 'ID' { Ok(Expr::Field(Box::new($1?), convert_lexeme($lexer, $3)?)) }
    | Postfix '[' Expr ']' { Ok(Expr::Index(Box::new($1?), Box::new($3?))) }
    | Primary { $1 }
    ;
UnaryOperation -> Result<Expr, ()>:
      '-' UnaryOperation { Ok(Expr::Unary(UnOp::Neg, Box::new($2?))) }
    | '!' UnaryOperation { Ok(Expr::Unary(UnOp::Not, Box::new($2?))) }
    | Postfix { $1 }
    ;
// @doc: expr-precedence
BinaryOperation -> Result<Expr, ()>:
      BinaryOperation '||' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Or, Box::new($3?))) }
    | BinaryOperation '&&' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::And, Box::new($3?))) }
    | BinaryOperation '==' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Eq, Box::new($3?))) }
    | BinaryOperation '!=' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Ne, Box::new($3?))) }
    | BinaryOperation '<' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Lt, Box::new($3?))) }
    | BinaryOperation '<='  BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Le, Box::new($3?))) }
    | BinaryOperation '>' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Gt, Box::new($3?))) }
    | BinaryOperation '>=' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Ge, Box::new($3?))) }
    | BinaryOperation '+' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Add, Box::new($3?))) }
    | BinaryOperation '-' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Sub, Box::new($3?))) }
    | BinaryOperation '*' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Mul, Box::new($3?))) }
    | BinaryOperation '/' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Div, Box::new($3?))) }
    | BinaryOperation '%' BinaryOperation { Ok(Expr::Binary(Box::new($1?), BinOp::Rem, Box::new($3?))) }
    | UnaryOperation { $1 }
    ;
// @doc: simple-op
SimpleOperation -> Result<Expr, ()>:
      BinaryOperation { $1 }
    | BinaryOperation '..' BinaryOperation { Ok(Expr::Range(Box::new($1?), Box::new($3?)))}
    | 'return' { Ok(Expr::Return(None)) }
    | 'return' BinaryOperation { Ok(Expr::Return(Some(Box::new($2?)))) }
    ;

// ---- expressions ----
// @doc: if
If -> Result<Expr, ()>:
      'if' Expr Block { Ok(Expr::If(Box::new($2?), Box::new(Expr::Block($3?)), None)) }
    | 'if' Expr Block 'else' Block { Ok(Expr::If(Box::new($2?), Box::new(Expr::Block($3?)), Some(Box::new(Expr::Block($5?))))) }
    | 'if' Expr Block 'else' If { Ok(Expr::If(Box::new($2?), Box::new(Expr::Block($3?)), Some(Box::new($5?)))) }
    ;
// @doc: block-like
// BlockLike expressions need no ';' as statements and are never operands,
// which keeps `if a {} -x` from being ambiguous.
BlockLike -> Result<Expr, ()>:
      If { $1 }
    | Block { Ok(Expr::Block($1?)) }
    ;
Expr -> Result<Expr, ()>:
      BlockLike { $1 }
    | SimpleOperation { $1 }
    ;

// ---- statements ----
// @doc: let
Let -> Result<Let, ()>:
      'let' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(convert_lexeme($lexer, $2)?, $4?, $6?, Mut::Not, $span)) }
    | 'let' 'mut' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(convert_lexeme($lexer, $3)?, $5?, $7?, Mut::Mut, $span)) }
    ;
// @doc: loop-stmt
// Loops and loop jumps are statements: they produce no value.
While -> Result<Stmt, ()>:
      'while' Expr Block { Ok(Stmt::While(Box::new($2?), Box::new(Expr::Block($3?)))) }
    ;
Loop -> Result<Stmt, ()>:
      'loop' Block { Ok(Stmt::Loop(Box::new(Expr::Block($2?)))) }
    ;
For -> Result<Stmt, ()>:
      'for' 'ID' 'in' Expr Block { Ok(Stmt::For(convert_lexeme($lexer, $2)?, $span, Box::new($4?), Box::new(Expr::Block($5?)))) }
    ;
LoopStmt -> Result<Stmt, ()>:
      While { $1 }
    | Loop { $1 }
    | For { $1 }
    | 'break' ';' { Ok(Stmt::Break) }
    | 'continue' ';' { Ok(Stmt::Continue) }
    ;
// @doc: assign
// Assignment is a statement, not an expression: `a = b = 1` is a syntax error.
// Go-style lists: `a, b = b, a`. Counts are checked later, not here.
Targets -> Result<Vec<Expr>, ()>:
      Postfix { Ok(vec![$1?]) }
    | Targets ',' Postfix {
                            let mut targets = $1?;
                            targets.push($3?);
                            Ok(targets)
                          }
    ;
Values -> Result<Vec<Expr>, ()>:
      Expr { Ok(vec![$1?]) }
    | Values ',' Expr {
                        let mut values = $1?;
                        values.push($3?);
                        Ok(values)
                      }
    ;
// @doc: stmt
Stmt -> Result<Stmt, ()>:
      Let { Ok(Stmt::Declaration($1?)) }
    | SimpleOperation ';' { Ok(Stmt::Semi($1?)) }
    | BlockLike { Ok(Stmt::Expr($1?)) }
    | LoopStmt { $1 }
    // nested fn: no access to outer locals; no `pub`, since nothing outside the block can reach it
    | Function { Ok(Stmt::Item(ItemKind::Function(Vis::new(Visibility::Private, $1?)))) }
    | Targets '=' Values ';' { Ok(Stmt::Assign($1?, $3?)) }
    | ';' { Ok(Stmt::Empty) }
    ;
Stmts -> Result<Vec<Stmt>, ()>:
      /* empty */ { Ok(vec![]) }
    | Stmts Stmt {
                   let mut stmts = $1?;
                   stmts.push($2?);
                   Ok(stmts)
                 }
    ;
// @doc: block
// A block ends with an optional value expression (no ';').
Block -> Result<Block, ()>:
      '{' Stmts '}' {
                      // A trailing block-like without `;` (Stmt::Expr) is the block's value.
                      let mut stmts = $2?;
                      let tail = match stmts.pop() {
                          Some(Stmt::Expr(e)) => Some(Box::new(e)),
                          Some(other) => { stmts.push(other); None }
                          None => None,
                      };
                      Ok(Block::new(stmts, tail))
                    }
    | '{' Stmts SimpleOperation '}' { Ok(Block::new($2?, Some(Box::new($3?)))) }
    ;

// ---- items ----
// @doc: method-self
// `self` may only be the first parameter; a function without it is static.
Param -> Result<Parameter, ()>:
      'ID' ':' Type { Ok(Parameter::new(convert_lexeme($lexer, $1)?, $3?, $span)) }
    ;
ParamList -> Result<Vec<Parameter>, ()>:
      Param { Ok(vec![$1?]) }
    | ParamList ',' Param {
                            let mut params = $1?;
                            params.push($3?);
                            Ok(params)
                          }
    ;
Params -> Result<(SelfParam, Vec<Parameter>), ()>:
      /* empty */ { Ok((SelfParam::Not, vec![])) }
    | ParamList { Ok((SelfParam::Not, $1?)) }
    | ParamList ',' { Ok((SelfParam::Not, $1?)) }
    | 'self' { Ok((SelfParam::Value($1.map_err(|_| ())?.span()), vec![])) }
    | 'self' ',' { Ok((SelfParam::Value($1.map_err(|_| ())?.span()), vec![])) }
    | 'self' ',' ParamList { Ok((SelfParam::Value($1.map_err(|_| ())?.span()), $3?)) }
    | 'self' ',' ParamList ',' { Ok((SelfParam::Value($1.map_err(|_| ())?.span()), $3?)) }
    ;
// @doc: function
Function -> Result<Function, ()>:
      'fn' 'ID' '(' Params ')' Block {
                                       let (self_param, params) = $4?;
                                       Ok(Function::new(convert_lexeme($lexer, $2)?, self_param, params, None, $6?))
                                     }
    | 'fn' 'ID' '(' Params ')' '->' Type Block {
                                                 let (self_param, params) = $4?;
                                                 Ok(Function::new(convert_lexeme($lexer, $2)?, self_param, params, Some($7?), $8?))
                                               }
    ;
// @doc: struct
StructFields -> Result<Vec<Vis<Field>>, ()>:
      StructFields ',' Visibility 'ID' ':' Type {
                                                  let mut fields = $1?;
                                                  fields.push(Vis::new($3?, Field::new(convert_lexeme($lexer, $4)?, $6?)));
                                                  Ok(fields)
                                                }
    | Visibility 'ID' ':' Type { Ok(vec![Vis::new($1?, Field::new(convert_lexeme($lexer, $2)?, $4?))]) }
    ;
Struct -> Result<Struct, ()>:
      'struct' 'ID' '{' StructFields '}' { Ok(Struct::new(convert_lexeme($lexer, $2)?, $4?)) }
    | 'struct' 'ID' '{' StructFields ',' '}' { Ok(Struct::new(convert_lexeme($lexer, $2)?, $4?)) }
    | 'struct' 'ID' '{' '}' { Ok(Struct::new(convert_lexeme($lexer, $2)?, vec![])) }
    ;
// @doc: visibility
// No `pub`: the name is private to its module and the modules below it.
Visibility -> Result<Visibility, ()>:
      /* empty */ { Ok(Visibility::Private) }
    | 'pub' { Ok(Visibility::Pub) }
    ;
// @doc: impl-use-mod
Functions -> Result<Vec<Vis<Function>>, ()>:
      /* empty */ { Ok(vec![]) }
    | Functions Visibility Function {
                                      let mut methods = $1?;
                                      methods.push(Vis::new($2?, $3?));
                                      Ok(methods)
                                    }
    ;
Impl -> Result<Impl, ()>:
      'impl' 'ID' '{' Functions '}' { Ok(Impl::new(convert_lexeme($lexer, $2)?, $4?)) }
    ;
// The alias is None when there is no `as`: the name is then the path's last segment.
Use -> Result<(Path, Option<String>), ()>:
      'use' Path ';' { Ok(($2?, None)) }
    | 'use' Path 'as' 'ID' ';' { Ok(($2?, Some(convert_lexeme($lexer, $4)?))) }
    ;
Export -> Result<(Path, Option<String>), ()>:
      'export' Path ';' { Ok(($2?, None)) }
    | 'export' Path 'as' 'ID' ';' { Ok(($2?, Some(convert_lexeme($lexer, $4)?))) }
    ;
// @doc: const-static
// Module-level variables that may be `pub`. Both reuse the Let struct.
Const -> Result<Let, ()>:
      'const' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(convert_lexeme($lexer, $2)?, $4?, $6?, Mut::Not, $span)) }
    ;
Static -> Result<Let, ()>:
      'static' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(convert_lexeme($lexer, $2)?, $4?, $6?, Mut::Not, $span)) }
    | 'static' 'mut' 'ID' ':' Type '=' Expr ';' { Ok(Let::new(convert_lexeme($lexer, $3)?, $5?, $7?, Mut::Mut, $span)) }
    ;
// No inline modules (`mod m { .. }`): a module's contents always live in another file.
Mod -> Result<String, ()>:
      'mod' 'ID' ';' { convert_lexeme($lexer, $2) }
    ;

// ---- program ----
// @doc: items
Item -> Result<ItemKind, ()>:
      Visibility Function { Ok(ItemKind::Function(Vis::new($1?, $2?))) }
    | Visibility Struct { Ok(ItemKind::Struct(Vis::new($1?, $2?))) }
    | Impl { Ok(ItemKind::Impl($1?)) }
    | Use { let (path, alias) = $1?; Ok(ItemKind::Use(path, alias)) }
    | Export { let (path, alias) = $1?; Ok(ItemKind::Export(path, alias)) }
    | Visibility Mod { Ok(ItemKind::Mod(Vis::new($1?, $2?))) }
    | Let { Ok(ItemKind::Let($1?)) }   // a top-level let is never pub; use const or static
    | Visibility Const { Ok(ItemKind::Const(Vis::new($1?, $2?))) }
    | Visibility Static { Ok(ItemKind::Static(Vis::new($1?, $2?))) }
    ;
ItemList -> Result<Vec<ItemKind>, ()>:
      ItemList Item {
                      let mut items = $1?;
                      items.push($2?);
                      Ok(items)
                    }
    | Item { Ok(vec![$1?]) }
    ;
Program -> Result<Vec<ItemKind>, ()>:
      ItemList { $1 }
    ;
%%
use crate::ast::{Type, Path, Expr, Literal, FieldInit, UnOp, BinOp, Stmt, Mut, Block, ItemKind, SelfParam, Parameter, Function, Field, Struct, Impl, Let, Vis, Visibility};
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
