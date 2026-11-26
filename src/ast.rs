use lrpar::Span;

#[derive(Debug)]
pub enum Type {
    Int32,
    Bool,
    Str,
    Name(Path), // a struct, possibly in another module: Point, root::geo::Point
    Array(Box<Type>, u64), // The box breaks the recursion of the type. Type can't contain itself.
    Void
}

#[derive(Debug)]
pub struct Path {
    pub segments: Vec<String>,
    pub pos: Span
}

#[derive(Debug)]
pub enum Literal {
    Int(u64),
    Bool(bool),
    Str(String),
}

#[derive(Debug)]
pub enum Expr {
    Lit(Literal),
    SelfValue(Span),
    Path(Path),
    FieldInits(Vec<FieldInit>),
    Array(Vec<Expr>),
    Call(Box<Expr>, Vec<Expr>),   // callee, arguments: f(1, 2)
    Field(Box<Expr>, String),     // object, field name: p.x
    Index(Box<Expr>, Box<Expr>),  // array, index: a[0]
    Unary(UnOp, Box<Expr>),       // operator, operand: -x, !b
    Binary(Box<Expr>, BinOp, Box<Expr>), // left, operator, right: a + b
    Range(Box<Expr>, Box<Expr>),
    Return(Option<Box<Expr>>),
    If(Box<Expr>, Box<Expr>, Option<Box<Expr>>), // condition, then-branch, else-branch (None: no else)
    Block(Block),                                 // { stmts; tail }
}

#[derive(Debug)]
pub enum BinOp {
    Or,  // ||
    And, // &&
    Eq,  // ==
    Ne,  // !=
    Lt,  // <
    Le,  // <=
    Gt,  // >
    Ge,  // >=
    Add, // +
    Sub, // -
    Mul, // *
    Div, // /
    Rem, // %
}

#[derive(Debug)]
pub enum UnOp {
    Neg, // -x
    Not, // !b
}

#[derive(Debug)]
pub struct FieldInit {
    pub name: String,
    pub value: Expr,
    pub pos: Span
}

#[derive(Debug)]
pub enum Stmt {
    Declaration(Let), // let mut x: int = 1;
    While(Box<Expr>, Box<Expr>),          // condition, body: while c { }
    Loop(Box<Expr>),                      // body: loop { }
    For(String, Span, Box<Expr>, Box<Expr>), // variable, its span, iterable, body: for i in 0..n { }
    Break,                                // break;
    Continue,                             // continue;
    Semi(Expr),  // expression with `;`: f(); value discarded
    Expr(Expr),  // nested block or `if` without `;`: { } / if a { } — becomes the tail if last
    Empty,       // lone `;`
    Item(ItemKind), // nested item: fn h() {} inside a block
    Assign(Vec<Expr>, Vec<Expr>), // targets, values matched by index: a, b = b, a;
}

#[derive(Debug)]
pub struct Block {
    pub stmts: Vec<Stmt>,
    pub tail: Option<Box<Expr>>, // None: block has no value
}

#[derive(Debug)]
pub struct Let {
    pub name: String,
    pub tpe: Type,
    pub value: Expr,
    pub mutability: Mut,
    pub span: Span
}

#[derive(Debug)]
pub enum Mut { Not, Mut }

#[derive(Debug)]
pub enum ItemKind {
    Function(Vis<Function>),
    Struct(Vis<Struct>),
    Impl(Impl),                     // no visibility: an impl introduces no name
    Use(Path, Option<String>),      // use a::b;  use a::b as c;  (None: alias = last segment)
    Export(Path, Option<String>),   // export a::b;  export a::b as c;  re-exports into this module
    Mod(Vis<String>),               // mod m; only in mod.upl; contents live in another file
    Let(Let),                       // top-level let: always private, so no Vis
    Const(Vis<Let>),                // const X: int = 1;  never changes (mutability always Not)
    Static(Vis<Let>),               // static [mut] X: int = 1;  one location for the whole program
}

// Whether a name may be used outside the module that declares it. Default: Private.
#[derive(Debug)]
pub enum Visibility { Private, Pub }

// A node that can be marked `pub`. Passes that only need the node read `node`.
#[derive(Debug)]
pub struct Vis<T> {
    pub vis: Visibility,
    pub node: T,
}

// Whether a function takes `self` as its first parameter (a method) or not (static).
#[derive(Debug)]
pub enum SelfParam { Not, Value(Span) } // Span: the `self` token in the parameter list

#[derive(Debug)]
pub struct Parameter {
    pub name: String,
    pub return_type: Type,
    pub span: Span,
}

#[derive(Debug)]
pub struct Function {
    pub name: String,
    pub self_param: SelfParam,
    pub parameters: Vec<Parameter>,
    pub return_type: Option<Type>, // None: no `-> Type`, returns no value
    pub body: Block,
    pub span: Span
}

#[derive(Debug)]
pub struct Field {
    pub id: String,
    pub field_type: Type,
}

#[derive(Debug)]
pub struct Struct {
    pub field: Vec<Vis<Field>>, // empty for `struct E {}`
    pub id: String,
    pub span: Span,
}

#[derive(Debug)]
pub struct Impl {
    pub methods: Vec<Vis<Function>>,
    pub id: String, // the type name; name resolution links it to its struct
}

impl<T> Vis<T> {
    pub fn new(vis: Visibility, node: T) -> Self {
        Vis { vis, node }
    }
}

impl Path {
    pub fn new(lexeme: String, span: Span) -> Self {
        Path { segments: vec![lexeme], pos: span }
    }
    pub fn add_path(&mut self, lexeme: String, span: Span) {
        self.segments.push(lexeme);
        self.pos = span;
    }
}

impl FieldInit {
    pub fn new(lexeme: String, span: Span, expr: Expr) -> Self {
        FieldInit { name: lexeme, value: expr, pos: span  }
    }
}

impl Block {
    pub fn new(stmts: Vec<Stmt>, tail: Option<Box<Expr>>) -> Self {
        Block { stmts, tail }
    }
}

impl Let {
    pub fn new(name: String, tpe: Type, value: Expr, mutability: Mut, span: Span) -> Self {
        Let { name, tpe, value, mutability, span }
    }
}

impl Parameter {
    pub fn new(name: String, return_type: Type, span: Span) -> Self {
        Parameter { name, return_type, span }
    }
}

impl Function {
    pub fn new(name: String, self_param: SelfParam, parameters: Vec<Parameter>,
               return_type: Option<Type>, body: Block, span: Span) -> Self {
        Function { name, self_param, parameters, return_type, body, span }
    }
}

impl Field {
    pub fn new(id: String, field_type: Type) -> Self {
        Field { id, field_type }
    }
}

impl Struct {
    pub fn new(id: String, field: Vec<Vis<Field>>, span: Span) -> Self {
        Struct { field, id, span }
    }
}

impl Impl {
    pub fn new(id: String, methods: Vec<Vis<Function>>) -> Self {
        Impl { methods, id }
    }
}
