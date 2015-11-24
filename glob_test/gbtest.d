import std.stdio;

import iv.glob;


void main () {
  writeln("====================");
  foreach (Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }

  writeln("====================");
  foreach (uint idx, ref Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", it.name, "]");
  }

  writeln("====================");
  foreach_reverse (Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }

  writeln("====================");
  foreach_reverse (uint idx, ref Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", it.name, "]");
  }

  auto it = Glob("*")[0];
  writeln("[0]=", it.name);
}
