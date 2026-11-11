use std::io::Read;

use lrlex::{lrlex_mod, DefaultLexeme, LexerDef};
use lrpar::{lrpar_mod, Lexeme, Lexer, NonStreamingLexer};

lrlex_mod!("specs/lexer.l");
lrpar_mod!("specs/parser.y");

fn main() {
    let mut input = String::new();
    std::io::stdin().read_to_string(&mut input).unwrap();
    let lexerdef = lexer_l::lexerdef();

    // `--tokens` dumps the token stream instead of parsing.
    if std::env::args().any(|a| a == "--tokens") {
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
        return;
    }

    let lexer = lexerdef.lexer(&input);
    let errs = parser_y::parse(&lexer);
    for e in &errs {
        eprintln!("{}", e.pp(&lexer, &parser_y::token_epp));
    }
    if errs.is_empty() {
        println!("ok");
    } else {
        std::process::exit(1);
    }
}
