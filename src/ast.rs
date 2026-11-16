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
    Block(Vec<Stmt>, Option<Box<Expr>>),          // statements, tail (None: block has no value)
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
    Declaration(String, Type, Expr, Mut), // name, type, value, mutability: let mut x: int = 1;
    While(Box<Expr>, Box<Expr>),          // condition, body: while c { }
    Loop(Box<Expr>),                      // body: loop { }
    For(String, Box<Expr>, Box<Expr>),    // variable, iterable, body: for i in 0..n { }
    Break,                                // break;
    Continue,                             // continue;
    Semi(Expr),  // expression with `;`: f(); value discarded
    Expr(Expr),  // block-like without `;`: if a { } — becomes the tail if last
    Empty,       // lone `;`
    Assign(Vec<Expr>, Vec<Expr>), // targets, values matched by index: a, b = b, a;
}

#[derive(Debug)]
pub enum Mut { Not, Mut }
