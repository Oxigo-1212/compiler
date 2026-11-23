use lrlex::DefaultLexerTypes;
use lrpar::{LexError, LexParseError, Lexeme, NonStreamingLexer, ParseRepair, Span};

// @doc: error-report
/// An error found while compiling, stored as plain values so later passes
/// can create one without going through lrpar.
pub enum CompileError {
    Lex { line: usize, col: usize, text: String },
    /// `repairs`: lrpar's repair sequences, one string each, in lrpar's wording.
    Parse { line: usize, col: usize, found: String, repairs: Vec<String> },
}

impl CompileError {
    /// The only place that reads lrpar's error API.
    pub fn from_lrpar(
        e: &LexParseError<u32, DefaultLexerTypes<u32>>,
        lexer: &dyn NonStreamingLexer<DefaultLexerTypes<u32>>,
        input: &str,
    ) -> CompileError {
        match e {
            LexParseError::LexError(le) => {
                let start = le.span().start();
                let ((line, col), _) = lexer.line_col(le.span());
                // lrlex reports an empty span, so take the character at the start.
                let text = input[start..].chars().next().map(String::from).unwrap_or_default();
                CompileError::Lex { line, col, text }
            }
            LexParseError::ParseError(pe) => {
                let span: Span = pe.lexeme().span();
                let ((line, col), _) = lexer.line_col(span);
                let found = match lexer.span_str(span) {
                    "" => "end of file".to_string(),
                    s => format!("'{s}'"),
                };
                let repairs = pe.repairs().iter().map(|seq| repair_text(seq, lexer)).collect();
                CompileError::Parse { line, col, found, repairs }
            }
        }
    }

    /// Prints the error in rustc style: message, location, source line, marker.
    pub fn report(&self, path: &str, input: &str) {
        let (line, col, message) = match self {
            CompileError::Lex { line, col, text } => {
                (*line, *col, format!("unknown character '{text}'"))
            }
            CompileError::Parse { line, col, found, .. } => {
                (*line, *col, format!("unexpected {found}"))
            }
        };
        let source = input.lines().nth(line - 1).unwrap_or("");
        let gutter = " ".repeat(line.to_string().len());
        eprintln!("error: {message}");
        eprintln!("{gutter}--> {path}:{line}:{col}");
        eprintln!("{gutter} |");
        eprintln!("{line} | {source}");
        // ponytail: counts characters, so tabs in the source line misplace the `^`.
        eprintln!("{gutter} | {}^", " ".repeat(col - 1));
        if let CompileError::Parse { repairs, .. } = self {
            if !repairs.is_empty() {
                eprintln!("{gutter} = help: possible fixes:");
                for (i, r) in repairs.iter().enumerate() {
                    eprintln!("{gutter}         {}: {r}", i + 1);
                }
            }
        }
    }
}

/// One repair sequence as text, worded like lrpar's own `pp`
/// (lrpar-0.15.0/src/lib/parser.rs): consecutive Deletes are merged.
fn repair_text(
    seq: &[ParseRepair<lrlex::DefaultLexeme<u32>, u32>],
    lexer: &dyn NonStreamingLexer<DefaultLexerTypes<u32>>,
) -> String {
    let mut steps = Vec::new();
    let mut i = 0;
    while i < seq.len() {
        match &seq[i] {
            ParseRepair::Delete(l) => {
                let start = l.span().start();
                let mut end = l.span().end();
                i += 1;
                while let Some(ParseRepair::Delete(next)) = seq.get(i) {
                    if next.span().start() != end {
                        break;
                    }
                    end = next.span().end();
                    i += 1;
                }
                let t = lexer.span_str(Span::new(start, end)).replace('\n', "\\n");
                steps.push(format!("Delete {t}"));
            }
            ParseRepair::Insert(tok) => {
                steps.push(format!("Insert {}", crate::parser_y::token_epp(*tok).unwrap_or("?")));
                i += 1;
            }
            ParseRepair::Shift(l) => {
                steps.push(format!("Shift {}", lexer.span_str(l.span()).replace('\n', "\\n")));
                i += 1;
            }
        }
    }
    steps.join(", ")
}
