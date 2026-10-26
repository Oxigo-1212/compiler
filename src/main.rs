use std::io::Read;

use lrlex::{lrlex_mod, DefaultLexeme, LexerDef};
use lrpar::{Lexeme, Lexer, NonStreamingLexer};

lrlex_mod!("specs/lexer.l");

fn main() {
    let mut input = String::new();
    std::io::stdin().read_to_string(&mut input).unwrap();
    let lexerdef = lexer_l::lexerdef();
    let lexer = lexerdef.lexer(&input);
    for item in lexer.iter() {
        match item {
            Ok(l) => {
                let l: DefaultLexeme = l;
                let name = lexerdef.get_rule_by_id(l.tok_id()).name().unwrap_or("?");
                println!("{name:12} {:?}", lexer.span_str(l.span()));
            }
            Err(e) => eprintln!("lex error: {e}"),
        }
    }
}
