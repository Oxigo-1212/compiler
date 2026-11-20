mod ast;
mod error;

use error::CompileError;

use lrlex::{lrlex_mod, DefaultLexeme, LexerDef};
use lrpar::{lrpar_mod, Lexeme, Lexer, NonStreamingLexer};

lrlex_mod!("specs/lexer.l");
lrpar_mod!("specs/parser.y");

const USAGE: &str = "usage: compiler <file.upl> [-o <output>] [--ast] [--tokens]
  -o <output>  output file name (not used yet: no code generation)
  --ast        print the syntax tree
  --tokens     print the token stream instead of parsing";

fn usage() -> ! {
    eprintln!("{USAGE}"); // print the USAGE message for miss input.
    std::process::exit(1);
}

fn main() {
    let mut path: Option<String> = None;
    let mut _output: Option<String> = None;
    let mut print_ast = false;
    let mut print_tokens = false;

    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--ast" => print_ast = true,
            "--tokens" => print_tokens = true,
            "-o" => _output = Some(args.next().unwrap_or_else(|| usage())), // if there is missing input for the file compiler file.UPL than this will return the usage above.
            _ if arg.starts_with('-') => usage(),
            _ if std::path::Path::new(&arg).extension() != Some("upl".as_ref()) => usage(),
            _ if path.is_none() => path = Some(arg),
            _ => usage(), // a second source file
        }
    }
    let path = path.unwrap_or_else(|| usage());
    let input = std::fs::read_to_string(&path).unwrap_or_else(|e| {
        eprintln!("{path}: {e}");
        std::process::exit(1);
    });
    let lexerdef = lexer_l::lexerdef();

    if print_tokens {
        let lexer = lexerdef.lexer(&input);
        for item in lexer.iter() {
            match item {
                Ok(l) => { let l: DefaultLexeme = l;
                    let name = lexerdef.get_rule_by_id(l.tok_id()).name().unwrap_or("?");
                    println!("{name:12} {:?}", lexer.span_str(l.span()));
                }
                Err(e) => eprintln!("{path}: lex error: {e}"),
            }
        }
        return;
    }

    let lexer = lexerdef.lexer(&input);
    let (result, errs) = parser_y::parse(&lexer); for e in &errs {
        CompileError::from_lrpar(e, &lexer, &input).report(&path, &input);
    }
    match result {
        Some(Ok(tree)) if errs.is_empty() => {
            if print_ast {
                println!("{tree:#?}");
            }
            // TODO: code generation; write the result to `_output` (default name undecided).
        }
        Some(Err(())) => {
            eprintln!("{path}: error: could not build AST");
            std::process::exit(1);
        }
        // Syntax errors (already printed above), or the parser gave up (None).
        _ => std::process::exit(1),
    }
}
