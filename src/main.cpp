#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include "ast.h"
#include "diagnostic.h"
#include "parser.hpp"

struct yy_buffer_state;
extern yy_buffer_state *yy_scan_bytes(const char *bytes, int length);
extern void yy_delete_buffer(yy_buffer_state *buffer);
extern int yylex_destroy();

int main(int argc, char *argv[]) {
  if (argc < 2) {
    std::fprintf(stderr, "compiler: fatal error: no input files\n");
    return 1;
  }

  const std::string arg = argv[1];
  std::string filename;
  std::string source;

  if (arg == "-") {
    filename = "<stdin>";
    std::ostringstream ss;
    ss << std::cin.rdbuf();
    source = ss.str();
  } else {
    filename = arg;
    std::ifstream file(filename);
    if (!file) {
      std::fprintf(stderr, "compiler: error: %s: no such file or directory\n",
                   filename.c_str());
      return 1;
    }
    std::ostringstream ss;
    ss << file.rdbuf();
    source = ss.str();
  }

  diagInit(filename, source);
  resetLexer();

  auto *buffer =
      yy_scan_bytes(source.data(), static_cast<int>(source.size()));
  const int result = yyparse();
  yy_delete_buffer(buffer);
  yylex_destroy();

  if (result != 0 || syntaxErrors != 0 || lexicalErrors != 0 || !astRoot) {
    return 1;
  }
  printAst(std::cout, *astRoot);
  std::cout << '\n';
  return 0;
}
