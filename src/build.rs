use cfgrammar::yacc::YaccKind;
use lrlex::CTLexerBuilder;

fn main() {
    CTLexerBuilder::new()
        .lrpar_config(|ctp| {
            ctp.yacckind(YaccKind::Original(cfgrammar::yacc::YaccOriginalActionKind::NoAction))
                .grammar_in_src_dir("specs/parser.y")
                .unwrap()
        })
        .lexer_in_src_dir("specs/lexer.l")
        .unwrap()
        .build()
        .unwrap();
}
