use std::collections::HashMap;

use lrpar::Span;

use crate::{ast::ItemKind, error::CompileError};

type DefId = usize;

pub enum DefKind {
    Fn,
    Struct,
    Const,
    Static,
    TopLevelLet,
    Use,
    Export,
    Mod,
}
#[derive(Debug,
    Clone, Copy, PartialEq, Eq, Hash)]
pub enum Namespaces {
    Type,
    Value
}

struct Def {
    id: DefId,
    def_kind: DefKind,
    span: Span
}

enum Res {
    Local(Span),
    Item(DefId),
    Err
}

struct Resolver {
    defs: Vec<Def>,
    global_item: HashMap<(String, Namespaces), DefId>,
    scopes: Vec<Scope>,
    results: HashMap<Span, Res>,
    errors: Vec<CompileError>
}

struct Scope {
    locals: HashMap<String, Span>,
    items: HashMap<(String, Namespaces), DefId>,
    is_fn_boundary: bool
}
