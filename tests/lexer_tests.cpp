#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

#include "diagnostic.h"
#include "parser.hpp"

#include <string>
#include <vector>

struct yy_buffer_state;
extern yy_buffer_state *yy_scan_bytes(const char *bytes, int length);
extern void yy_delete_buffer(yy_buffer_state *buffer);
extern int yylex();
extern int yylex_destroy();

struct Token {
  int kind;
  std::string text;
  int line;
  int column;
};

static std::vector<Token> lex(const std::string &source) {
  resetLexer();
  diagInit("<test>", source);
  auto *buffer = yy_scan_bytes(source.data(), static_cast<int>(source.size()));

  std::vector<Token> tokens;
  for (int kind = yylex(); kind != 0; kind = yylex()) {
    std::string text;
    if (kind == IDENTIFIER || kind == CONSTANT) {
      text = *yylval.text;
      delete yylval.text;
    }
    tokens.push_back({kind, text, yylloc.first_line, yylloc.first_column});
  }

  yy_delete_buffer(buffer);
  yylex_destroy();
  return tokens;
}

TEST_CASE("lexer recognizes keywords identifiers literals and punctuation") {
  const auto tokens = lex("begin int value123=001; bool flag=true; print(value123>=1); end");

  const std::vector<int> expected = {
      BEGIN, INT, IDENTIFIER, '=', CONSTANT, ';',
      BOOL, IDENTIFIER, '=', TRUE, ';',
      PRINT, '(', IDENTIFIER, GE_OP, CONSTANT, ')', ';',
      END};

  REQUIRE(tokens.size() == expected.size());
  for (std::size_t index = 0; index < expected.size(); ++index) {
    CHECK(tokens[index].kind == expected[index]);
  }

  CHECK(tokens[2].text == "value123");
  CHECK(tokens[4].text == "001");
  CHECK(tokens[7].text == "flag");
  CHECK(tokens[13].text == "value123");
  CHECK(tokens[15].text == "1");
  CHECK(lexicalErrors == 0);
}

TEST_CASE("lexer skips comments and preserves locations across CRLF newlines") {
  const auto tokens = lex(
      "begin x123=001;\r\n"
      "// a line comment\r\n"
      "/* block\r\n"
      "comment */ bool flag>=true");

  REQUIRE(tokens.size() == 9);
  CHECK(tokens[0].kind == BEGIN);
  CHECK(tokens[0].line == 1);
  CHECK(tokens[0].column == 1);

  CHECK(tokens[1].kind == IDENTIFIER);
  CHECK(tokens[1].text == "x123");
  CHECK(tokens[1].line == 1);
  CHECK(tokens[1].column == 7);

  CHECK(tokens[3].kind == CONSTANT);
  CHECK(tokens[3].text == "001");
  CHECK(tokens[3].line == 1);
  CHECK(tokens[3].column == 12);

  CHECK(tokens[5].kind == BOOL);
  CHECK(tokens[5].line == 4);
  CHECK(tokens[5].column == 12);

  CHECK(tokens[6].kind == IDENTIFIER);
  CHECK(tokens[6].text == "flag");
  CHECK(tokens[6].line == 4);
  CHECK(tokens[6].column == 17);

  CHECK(tokens[7].kind == GE_OP);
  CHECK(tokens[7].line == 4);
  CHECK(tokens[7].column == 21);
  CHECK(lexicalErrors == 0);
}

TEST_CASE("lexer reports invalid identifiers and unexpected characters") {
  const auto tokens = lex("a1b _name @");

  REQUIRE(tokens.size() == 3);
  for (const auto &token : tokens) {
    CHECK(token.kind == YYerror);
  }

  CHECK(tokens[0].line == 1);
  CHECK(tokens[0].column == 1);
  CHECK(tokens[1].line == 1);
  CHECK(tokens[1].column == 5);
  CHECK(tokens[2].line == 1);
  CHECK(tokens[2].column == 11);
  CHECK(lexicalErrors == 3);
}

TEST_CASE("lexer recognizes compound and arithmetic operators like ANSI C") {
  const auto tokens = lex("!= <= && || - / % ! < ,");
  const std::vector<int> expected = {
      NE_OP, LE_OP, AND_OP, OR_OP, '-', '/', '%', '!', '<', ','};

  REQUIRE(tokens.size() == expected.size());
  for (std::size_t i = 0; i < expected.size(); ++i) {
    CHECK(tokens[i].kind == expected[i]);
  }
  CHECK(lexicalErrors == 0);
}
