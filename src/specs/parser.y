%grmtools{yacckind: Original(NoAction)}
%start Program
// @doc: expr-precedence
%left '||'
%left '&&'
%nonassoc '==' '!=' '<' '<=' '>' '>='
%left '+' '-'
%left '*' '/' '%'
%%
Program: ItemList;

// @doc: items
// ---- items ----
ItemList: ItemList Item | Item;
Item: Function | Struct | Impl | Use | Mod | Let;

// @doc: function
Function: 'fn' 'ID' '(' Params ')' Block
        | 'fn' 'ID' '(' Params ')' '->' Type Block;
// @doc: method-self
// `self` may only be the first parameter; a function without it is static.
Params: | ParamList | ParamList ','
      | 'self' | 'self' ',' | 'self' ',' ParamList | 'self' ',' ParamList ',';
ParamList: Param | ParamList ',' Param;
Param: 'ID' ':' Type;

// @doc: struct
Struct: 'struct' 'ID' '{' StructFields '}'
      | 'struct' 'ID' '{' StructFields ',' '}'
      | 'struct' 'ID' '{' '}';
StructFields: StructFields ',' 'ID' ':' Type | 'ID' ':' Type;

// @doc: impl-use-mod
Impl: 'impl' 'ID' '{' Functions '}';
Functions: | Functions Function;

Use: 'use' Path ';';
Mod: 'mod' 'ID' ';' | 'mod' 'ID' '{' ItemList '}' | 'mod' 'ID' '{' '}';

// @doc: type
Type: 'int' | 'bool' | 'str' | 'ID' | '[' Type ',' 'INTEGER' ']';

// ---- statements ----
// @doc: let
Let: 'let' 'ID' ':' Type '=' Expr ';'
   | 'let' 'mut' 'ID' ':' Type '=' Expr ';';

// @doc: block
// A block ends with an optional value expression (no ';').
Block: '{' Stmts '}' | '{' Stmts SimpleOperation '}';
Stmts: | Stmts Stmt;
Stmt: Let | SimpleOperation ';' | BlockLike | LoopStmt | ';';

// ---- expressions ----
// @doc: block-like
// BlockLike expressions need no ';' as statements and are never operands,
// which keeps `if a {} -x` from being ambiguous. 
Expr: BlockLike | SimpleOperation;
BlockLike: If | Block;
// @doc: if
If: 'if' Expr Block
  | 'if' Expr Block 'else' Block
  | 'if' Expr Block 'else' If;
// @doc: loop-stmt
// Loops and loop jumps are statements: they produce no value.
LoopStmt: While | Loop | For | 'break' ';' | 'continue' ';';
While: 'while' Expr Block;
Loop: 'loop' Block;
For: 'for' 'ID' 'in' Expr Block;

// @doc: simple-op
SimpleOperation: BinaryOperation
      | BinaryOperation '=' Expr
      | BinaryOperation '..' BinaryOperation
      | 'return' | 'return' BinaryOperation;

// @doc: expr-precedence
BinaryOperation: BinaryOperation '||' BinaryOperation | BinaryOperation '&&' BinaryOperation
      | BinaryOperation '==' BinaryOperation | BinaryOperation '!=' BinaryOperation
      | BinaryOperation '<' BinaryOperation | BinaryOperation '<=' BinaryOperation
      | BinaryOperation '>' BinaryOperation | BinaryOperation '>=' BinaryOperation
      | BinaryOperation '+' BinaryOperation | BinaryOperation '-' BinaryOperation
      | BinaryOperation '*' BinaryOperation | BinaryOperation '/' BinaryOperation | BinaryOperation '%' BinaryOperation
      | UnaryOperation;
// @doc: postfix-primary
UnaryOperation: '-' UnaryOperation | '!' UnaryOperation | Postfix;
Postfix: Postfix '(' Args ')' | Postfix '.' 'ID' | Postfix '[' Expr ']' | Primary;
// @doc: array-literal
// `[]` is forbidden: an array literal has at least one element.
Primary: Path | 'INTEGER' | 'STRING' | 'true' | 'false' | 'self' | '(' Expr ')'
       | '.' '{' FieldInits '}' | '.' '{' FieldInits ',' '}' | '.' '{' '}'
       | '[' ArgList ']' | '[' ArgList ',' ']';
// @doc: struct-literal
FieldInits: FieldInit | FieldInits ',' FieldInit;
FieldInit: 'ID' ':' Expr;
Path: 'ID' | Path '::' 'ID';
Args: | ArgList | ArgList ',';
ArgList: Expr | ArgList ',' Expr;
%%
