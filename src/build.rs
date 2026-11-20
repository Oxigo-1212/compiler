use lrlex::CTLexerBuilder;

fn main() {
    CTLexerBuilder::new() //builder pattern
        .lrpar_config(|ctp| {
            ctp.grammar_in_src_dir("specs/parser.y")
                .unwrap()
        })
    .lexer_in_src_dir("specs/lexer.l")
        .unwrap()
        .build()
        .unwrap();
}
