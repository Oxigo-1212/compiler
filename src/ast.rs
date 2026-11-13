use lrpar::Span;
pub enum Type {
    Int32,
    Bool,
    Str,
    Name(String),
    Array(Box<Type>, u64) // The box breaks the recursion of the type. Type can't contain itself.
}
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

pub enum Literal {
    Int(u64),
    Bool(bool),
    Str(String),
}
pub enum Expr {
    Lit(Literal),
    SelfValue
}
