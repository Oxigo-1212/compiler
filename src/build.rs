use lrlex::CTLexerBuilder;

fn main() {
    CTLexerBuilder::new()
        .lexer_in_src_dir("specs/lexer.l")
        .unwrap()
        .build()
        .unwrap();
}
