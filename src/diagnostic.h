#pragma once

#include <string>

/// Stores the source filename and text so that subsequent calls to diagEmit can
/// print the offending source line together with a caret, GCC-style.
///
///   file.upl:3:11: error: unexpected character '@'
///       3 |     int x=@;
///         |           ^
void diagInit(std::string filename, const std::string &source);

/// Resets the stored filename and source lines.
void diagReset();

/// Emits a GCC-style diagnostic to stderr.
void diagEmit(int line, int col, const char *message);
