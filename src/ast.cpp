#include "ast.h"

static void printString(std::ostream &out, const std::string &value) {
  constexpr char hex[] = "0123456789abcdef";
  out << '"';
  for (unsigned char character : value) {
    if (character == '"' || character == '\\') {
      out << '\\' << static_cast<char>(character);
    } else if (character < 0x20) {
      out << "\\u00" << hex[character >> 4] << hex[character & 0xf];
    } else {
      out << static_cast<char>(character);
    }
  }
  out << '"';
}

void printAst(std::ostream &out, const AstNode &node, int depth) {
  const std::string indent(depth * 2, ' ');
  out << indent << "{\"kind\": ";
  printString(out, node.kind);
  out << ", \"value\": ";
  printString(out, node.value);
  out << ", \"line\": " << node.line << ", \"column\": " << node.column
      << ", \"children\": [";
  for (std::size_t i = 0; i < node.children.size(); ++i) {
    out << (i == 0 ? "\n" : ",\n");
    printAst(out, *node.children[i], depth + 1);
  }
  if (!node.children.empty()) {
    out << '\n' << indent;
  }
  out << "]}";
}
