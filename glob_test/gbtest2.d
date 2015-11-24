import std.stdio;

import iv.glob;


void main () {
  foreach (string name; Glob("*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln("[", name, "]");
  }
  foreach (uint idx, string name; Glob("*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", name, "]");
  }
  foreach (const(char)[] name; Glob("*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln("[", name, "]");
  }
  foreach (const char[] name; Glob("*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln("[", name, "]");
  }
  foreach (char[] name; Glob("*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln("[", name, "]");
  }
}
