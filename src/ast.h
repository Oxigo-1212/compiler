#pragma once

#include <memory>
#include <ostream>
#include <string>
#include <vector>

struct AstNode {
  std::string kind;
  std::string value;
  int line;
  int column;
  std::vector<std::unique_ptr<AstNode>> children;
};

void printAst(std::ostream &out, const AstNode &node, int depth = 0);
