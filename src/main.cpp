#include <iostream>
#include "parser.hpp"

int main() {
  const int result = yyparse();
  if (result != 0 || syntaxErrors != 0 || lexicalErrors != 0 || !astRoot) {
    return 1;
  }
  printAst(std::cout, *astRoot);
  std::cout << '\n';
  return 0;
}
