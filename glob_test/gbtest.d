import std.stdio;

import iv.glob;


void main () {
  writeln("====================");
  foreach (auto it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }

  writeln("====================");
  foreach (auto idx, ref it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", it.name, "]");
  }

  writeln("====================");
  foreach_reverse (auto it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }

  writeln("====================");
  foreach_reverse (auto idx, ref it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", it.name, "]");
  }

  auto it = Glob("*")[0];
  writeln("[0]=", it.name);
}
