import std.stdio;

import iv.glob;


void main () {
  foreach (ref Glob.Item it; Glob("*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }
}
