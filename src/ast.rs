use lrpar::Span;
#[derive(Debug)]
pub enum Type {
    Int32,
    Bool,
    Str,
    Name(String),
    Array(Box<Type>, u64), // The box breaks the recursion of the type. Type can't contain itself.
    Void
}
#[derive(Debug)]
pub struct Path {
    segments: Vec<String>,
    pos: Span
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

#[derive(Debug)]
pub enum Literal {
    Int(u64),
    Bool(bool),
    Str(String),
}
#[derive(Debug)]
pub enum Expr {
    Lit(Literal),
    SelfValue,
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
    name: String,
    value: Expr,
    pos: Span
}


impl FieldInit {
    pub fn new(lexeme: String, span: Span, expr: Expr) -> Self {
        FieldInit { name: lexeme, value: expr, pos: span  }
    }
}

#[derive(Debug)]
pub enum Stmt {
    Declaration(Let), // let mut x: int = 1;
    While(Box<Expr>, Box<Expr>),          // condition, body: while c { }
    Loop(Box<Expr>),                      // body: loop { }
    For(String, Box<Expr>, Box<Expr>),    // variable, iterable, body: for i in 0..n { }
    Break,                                // break;
    Continue,                             // continue;
    Semi(Expr),  // expression with `;`: f(); value discarded
    Expr(Expr),  // block-like without `;`: if a { } — becomes the tail if last
    Empty,       // lone `;`
    Item(ItemKind), // nested item: fn h() {} inside a block
    Assign(Vec<Expr>, Vec<Expr>), // targets, values matched by index: a, b = b, a;
}

#[derive(Debug)]
pub struct Block {
    stmts: Vec<Stmt>,
    tail: Option<Box<Expr>>, // None: block has no value
}

impl Block {
    pub fn new(stmts: Vec<Stmt>, tail: Option<Box<Expr>>) -> Self {
        Block { stmts, tail }
    }
}

#[derive(Debug)]
pub struct Let {
    name: String,
    tpe: Type,
    value: Expr,
    mutability: Mut,
}

impl Let {
    pub fn new(name: String, tpe: Type, value: Expr, mutability: Mut) -> Self {
        Let { name, tpe, value, mutability }
    }
}

#[derive(Debug)]
pub enum Mut { Not, Mut }

#[derive(Debug)]
pub enum ItemKind {
    Function(Function),
    Struct(Struct),
    Impl(Impl),
    Use(Path),   // use a::b;
    Mod(String), // mod m; contents live in another file (no inline modules)
    Let(Let),    // top-level let
}

// Whether a function takes `self` as its first parameter (a method) or not (static).
#[derive(Debug)]
pub enum SelfParam { Not, Value }

#[derive(Debug)]
pub struct Parameter {
    name: String,
    return_type: Type,
}

impl Parameter {
    pub fn new(name: String, return_type: Type) -> Self {
        Parameter { name, return_type }
    }
}

#[derive(Debug)]
pub struct Function {
    name: String,
    self_param: SelfParam,
    parameters: Vec<Parameter>,
    return_type: Option<Type>, // None: no `-> Type`, returns no value
    body: Block,
}

impl Function {
    pub fn new(name: String, self_param: SelfParam, parameters: Vec<Parameter>,
               return_type: Option<Type>, body: Block) -> Self {
        Function { name, self_param, parameters, return_type, body }
    }
}

#[derive(Debug)]
pub struct Field {
    id: String,
    field_type: Type,
}

impl Field {
    pub fn new(id: String, field_type: Type) -> Self {
        Field { id, field_type }
    }
}
#[derive(Debug)]
pub struct Struct {
    field: Vec<Field>, // empty for `struct E {}`
    id: String,
}

impl Struct {
    pub fn new(id: String, field: Vec<Field>) -> Self {
        Struct { field, id }
    }
}

#[derive(Debug)]
pub struct Impl {
    methods: Vec<Function>,
    id: String, // the type name; name resolution links it to its struct
}

impl Impl {
    pub fn new(id: String, methods: Vec<Function>) -> Self {
        Impl { methods, id }
    }
}
