#include "diagnostic.h"

#include <cstdio>
#include <vector>

static std::string currentFile;
static std::vector<std::string> sourceLines;

void diagInit(std::string filename, const std::string &source) {
  currentFile = std::move(filename);
  sourceLines.clear();

  std::string::size_type start = 0;
  while (start <= source.size()) {
    auto end = source.find_first_of("\r\n", start);
    if (end == std::string::npos) {
      sourceLines.push_back(source.substr(start));
      break;
    }
    sourceLines.push_back(source.substr(start, end - start));
    if (source[end] == '\r' && end + 1 < source.size() &&
        source[end + 1] == '\n') {
      start = end + 2;
    } else {
      start = end + 1;
    }
  }
}

void diagReset() {
  currentFile.clear();
  sourceLines.clear();
}

void diagEmit(int line, int col, const char *message) {
  std::fprintf(stderr, "%s:%d:%d: error: %s\n", currentFile.c_str(), line, col,
               message);

  if (line < 1 || line > static_cast<int>(sourceLines.size())) return;

  const auto &src = sourceLines[line - 1];

  // Compute gutter width from the line number.
  int digits = 0;
  for (int n = line; n > 0; n /= 10) ++digits;
  if (digits < 4) digits = 4;

  std::fprintf(stderr, " %*d | %s\n", digits, line, src.c_str());
  std::fprintf(stderr, " %*s | ", digits, "");
  for (int i = 1; i < col && i <= static_cast<int>(src.size()); ++i) {
    std::fputc(src[i - 1] == '\t' ? '\t' : ' ', stderr);
  }
  std::fputc('^', stderr);
  std::fputc('\n', stderr);
}
