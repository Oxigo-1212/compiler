#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

#include "parser.hpp"
#include <cstdio>
#include <fstream>
#include <iterator>
#include <sstream>
#include <unistd.h>

struct yy_buffer_state;
extern yy_buffer_state *yy_scan_bytes(const char *bytes, int length);
extern void yy_delete_buffer(yy_buffer_state *buffer);
extern int yylex_destroy();

struct ParseResult {
  int status;
  int syntaxErrors;
  int lexicalErrors;
  std::string diagnostics;
};

static ParseResult parse(const std::string &source) {
  astRoot.reset();
  syntaxErrors = 0;
  resetLexer();

  // Capture the production diagnostics without adding a test-only logging API.
  auto capture = std::tmpfile();
  REQUIRE(capture != nullptr);
  const int saved = dup(fileno(stderr));
  REQUIRE(saved >= 0);
  std::fflush(stderr);
  REQUIRE(dup2(fileno(capture), fileno(stderr)) >= 0);
  auto buffer = yy_scan_bytes(source.data(), static_cast<int>(source.size()));
  const int status = yyparse();
  yy_delete_buffer(buffer);
  yylex_destroy();
  std::fflush(stderr);
  const int restored = dup2(saved, fileno(stderr));
  close(saved);
  REQUIRE(restored >= 0);

  std::rewind(capture);
  std::string diagnostics;
  char chunk[1024];
  while (const auto size = std::fread(chunk, 1, sizeof(chunk), capture)) {
    diagnostics.append(chunk, size);
  }
  std::fclose(capture);
  return {status, syntaxErrors, lexicalErrors, diagnostics};
}

static const AstNode &parseValid(const std::string &source) {
  const auto result = parse(source);
  INFO(result.diagnostics);
  REQUIRE(result.status == 0);
  REQUIRE(result.syntaxErrors == 0);
  REQUIRE(result.lexicalErrors == 0);
  REQUIRE(astRoot != nullptr);
  return *astRoot;
}

static const AstNode &child(const AstNode &node, std::size_t index) {
  return *node.children.at(index);
}

static std::string readFile(const char *path) {
  std::ifstream input(path);
  REQUIRE(input.good());
  return {std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>()};
}

static int count(const std::string &text, const std::string &word) {
  int matches = 0;
  for (auto position = text.find(word); position != std::string::npos;
       position = text.find(word, position + word.size())) {
    ++matches;
  }
  return matches;
}

TEST_CASE("valid UPL programs construct a program AST") {
  const std::vector<std::string> sources = {
      "begin end", readFile("tests/grammar_valid.src"), readFile("tests/lexer_sample.src"),
      "begin int abc123=001; bool flag=false; print(1+2*3+4); end",
      "begin if (true) then { if (false) then {} else {} } else {} end",
      "begin int i; for (i=0; 2>i; i=i+1) {} end // EOF comment",
      "begin /* multiline\ncomment */ print((1+2)*3==9); end",
      // Declaration and type checks belong to a separate semantic stage.
      "begin x=true+1; end"};
  for (const auto &source : sources) {
    INFO(source);
    CHECK(parseValid(source).kind == "Program");
  }
}

TEST_CASE("invalid syntax and lexical input are rejected") {
  const std::vector<std::string> sources = {
      "", "begin", "begin end print(1);", "int x;",
      "begin int x=; end", "begin print(1) end",
      "begin if (true) {} end", "begin do {} while (true) end",
      "begin for (;;) {} end", "begin print(1>2>3); end",
      "begin print(1>=2==true); end", "begin int a1b; end",
      "begin int _x; end", "begin int a_b; end", "begin int 1abc; end",
      "begin int x=1.5; end", "begin print(\"hello\"); end",
      "begin print(1-2); end", "begin print(1/2); end",
      "begin print(1<2); end", "begin print(1!=2); end",
      "begin /* unterminated", "begin int begin; end"};
  for (const auto &source : sources) {
    INFO(source);
    const auto result = parse(source);
    CHECK((result.status != 0 || result.syntaxErrors != 0 || result.lexicalErrors != 0));
    CHECK_FALSE(result.diagnostics.empty());
  }
}

TEST_CASE("expression AST preserves precedence parentheses and left associativity") {
  const auto &root = parseValid("begin print(1+2*3==7); end");
  const auto &comparison = child(child(root, 0), 0);
  CHECK(comparison.kind == "Binary");
  CHECK(comparison.value == "==");
  const auto &addition = child(comparison, 0);
  CHECK(addition.value == "+");
  CHECK(child(addition, 1).value == "*");
  CHECK(child(child(addition, 1), 0).value == "2");

  const auto &parenthesized = child(child(parseValid("begin print((1+2)*3); end"), 0), 0);
  CHECK(parenthesized.value == "*");
  CHECK(child(parenthesized, 0).value == "+");
  for (const auto &operation : {std::string("+"), std::string("*")}) {
    const auto &expression = child(child(parseValid("begin print(1" + operation + "2" + operation + "3); end"), 0), 0);
    CHECK(expression.value == operation);
    CHECK(child(expression, 0).value == operation);
    CHECK(child(expression, 1).value == "3");
  }
}

TEST_CASE("AST contains declarations assignments branches loops and literals") {
  const auto &root = parseValid(readFile("tests/grammar_valid.src"));
  const std::vector<std::string> kinds = {
      "Declaration", "Declaration", "Declaration", "If", "DoWhile", "For", "Print"};
  REQUIRE(root.children.size() == kinds.size());
  for (std::size_t i = 0; i < kinds.size(); ++i) {
    CHECK(child(root, i).kind == kinds[i]);
  }
  const auto &declaration = child(root, 0);
  CHECK(declaration.value == "int");
  CHECK(child(declaration, 0).kind == "Identifier");
  CHECK(child(declaration, 0).value == "x");
  CHECK(child(declaration, 1).kind == "Integer");
  CHECK(child(declaration, 1).value == "0");
  CHECK(declaration.line == 2);
  CHECK(declaration.column == 5);

  const auto &branch = child(root, 3);
  REQUIRE(branch.children.size() == 3);
  CHECK(child(branch, 0).value == "a");
  CHECK(child(branch, 1).kind == "Block");
  CHECK(child(child(branch, 1), 0).kind == "Print");
  const auto &assignment = child(child(branch, 2), 0);
  CHECK(assignment.kind == "Assignment");
  CHECK(child(assignment, 0).value == "x");
  CHECK(child(child(root, 4), 0).kind == "Block");
  CHECK(child(child(root, 4), 1).kind == "Binary");
  const auto &loop = child(root, 5);
  REQUIRE(loop.children.size() == 4);
  CHECK(child(loop, 0).kind == "Declaration");
  CHECK(child(loop, 1).kind == "Binary");
  CHECK(child(loop, 2).kind == "Assignment");
  CHECK(child(loop, 3).kind == "Block");
  CHECK(child(child(child(root, 6), 0), 1).value == "true");

  const auto &optional = parseValid("begin int x; bool a=false; if (a) then {} end");
  CHECK(child(optional, 0).children.size() == 1);
  CHECK(child(child(optional, 1), 1).value == "false");
  CHECK(child(optional, 2).children.size() == 2);
  const auto &assigned = parseValid("begin int i; for (i=0; 1>i; i=i+1) {} end");
  CHECK(child(child(assigned, 1), 0).kind == "Assignment");
}

TEST_CASE("locations survive comments all newline styles and repeated parses") {
  for (const auto &newline : {std::string("\n"), std::string("\r\n"), std::string("\r")}) {
    const auto &root = parseValid("begin" + newline + "/* multi" + newline +
                                 "line */" + newline + "  int abc123=001;" + newline + "end");
    const auto &declaration = child(root, 0);
    CHECK(declaration.line == 4);
    CHECK(declaration.column == 3);
    CHECK(child(declaration, 0).value == "abc123");
    CHECK(child(declaration, 1).value == "001");
  }
}

TEST_CASE("syntax recovery reports independent errors across statements and blocks") {
  struct Case { std::string source; int errors; std::vector<int> lines; };
  const std::vector<Case> cases = {
      {readFile("tests/grammar_errors.src"), 2, {2, 3}},
      {"begin\nint x=1\nint y=;\nprint(2+);\nend", 3, {3, 4}},
      {"begin\nif (true) then {\nint x=1+\n}\nprint(1+);\nend", 2, {4, 5}},
      {"begin\nif (true) then {\nprint(1)\n}\nprint(2+);\nend", 2, {4, 5}},
      {"begin\nint x=;\ndo {\nprint(1+);\n} while (true);\nprint(2+);\nend", 3, {2, 4, 6}},
      {"begin\nprint(1)\nend", 1, {3}},
      {readFile("tests/parser_recovery.src"), 3, {3, 5}}};
  for (const auto &test : cases) {
    const auto result = parse(test.source);
    INFO(result.diagnostics);
    CHECK(result.syntaxErrors == test.errors);
    CHECK(count(result.diagnostics, "Syntax error") == test.errors);
    for (int line : test.lines) {
      CHECK(result.diagnostics.find("line " + std::to_string(line) + ", column") != std::string::npos);
    }
  }
  const auto result = parse(readFile("tests/grammar_errors.src"));
  CHECK(result.diagnostics.find("line 2, column 11:") != std::string::npos);
  CHECK(result.diagnostics.find("line 3, column 13:") != std::string::npos);
}

TEST_CASE("lexical errors recover and unterminated comments point to their start") {
  const auto result = parse("begin\nint a1b;\nprint(1+);\n@;\nprint(2);\nend");
  INFO(result.diagnostics);
  CHECK(result.lexicalErrors == 2);
  CHECK(result.syntaxErrors == 1);
  for (int line : {2, 3, 4}) {
    CHECK(result.diagnostics.find("line " + std::to_string(line) + ", column") != std::string::npos);
  }
  const auto unclosed = parse("begin\n  /* unclosed\ncomment");
  CHECK(unclosed.lexicalErrors == 1);
  CHECK(unclosed.diagnostics.find("Lexical error at line 2, column 3: unterminated block comment") != std::string::npos);
  CHECK(parseValid("begin end").children.empty());
}

TEST_CASE("error-prone sample reports twelve errors and reaches the final statement") {
  const auto result = parse(readFile("tests/error_prone.src"));
  INFO(result.diagnostics);
  CHECK(result.status == 0); // Bison finishes recovery; the CLI rejects the error counts.
  CHECK(result.syntaxErrors == 9);
  CHECK(result.lexicalErrors == 3);
  CHECK(count(result.diagnostics, "Syntax error") == 9);
  CHECK(count(result.diagnostics, "Lexical error") == 3);
  for (int line : {7, 9, 10, 13, 16, 21, 23, 26, 29, 30, 31, 32}) {
    CHECK(result.diagnostics.find("line " + std::to_string(line) + ", column") != std::string::npos);
  }
  REQUIRE(astRoot != nullptr);
  REQUIRE_FALSE(astRoot->children.empty());
  const auto &last = *astRoot->children.back();
  CHECK(last.kind == "Print");
  REQUIRE(last.children.size() == 1);
  CHECK(child(last, 0).value == "12345");
}

TEST_CASE("AST JSON escapes strings") {
  const AstNode node{"Identifier", "a\"\n\t\\", 1, 1, {}};
  std::ostringstream output;
  printAst(output, node);
  CHECK(output.str() == "{\"kind\": \"Identifier\", \"value\": \"a\\\"\\u000a\\u0009\\\\\", \"line\": 1, \"column\": 1, \"children\": []}");
}
