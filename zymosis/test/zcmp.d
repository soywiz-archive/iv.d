import iv.vfs.io;


string[] readTest (VFile fl) {
  while (!fl.eof) {
    string s = fl.readln;
    if (s.length != 0) {
      string[] res;
      for (;;) {
        res ~= s;
        if (fl.eof) return res;
        s = fl.readln;
        if (s.length == 0) return res;
      }
    }
  }
  return null;
}


void dumbDiff (string[] s0, string[] s1) {
  import std.algorithm : levenshteinDistanceAndPath, EditOp;
  auto dd = levenshteinDistanceAndPath(s0, s1);
  usize pos0 = 0, pos1 = 0;
  usize opidx = 0;
  while (opidx < dd[1].length) {
    immutable op = dd[1][opidx];
    int len = 1;
    while (opidx+len < dd[1].length && dd[1][opidx+len] == op) ++len;
    opidx += len;
    final switch (op) {
      case EditOp.none:
        foreach (immutable idx; pos0..pos0+len) writeln("  ", s0[idx]);
        pos0 += len;
        pos1 += len;
        break;
      case EditOp.substitute:
        foreach (immutable idx; pos0..pos0+len) writeln("- ", s0[idx]);
        foreach (immutable idx; pos1..pos1+len) writeln("+ ", s1[idx]);
        pos0 += len;
        pos1 += len;
        break;
      case EditOp.insert:
        foreach (immutable idx; pos1..pos1+len) writeln("+ ", s1[idx]);
        pos1 += len;
        break;
      case EditOp.remove:
        foreach (immutable idx; pos0..pos0+len) writeln("- ", s0[idx]);
        pos0 += len;
        break;
    }
  }
  assert(pos0 == s0.length);
  assert(pos1 == s1.length);
}


int main (string[] args) {
  version(rdmd) if (args.length == 1) args ~= "z10.out";
  if (args.length == 2) args ~= "testdata/tests.expected";
  if (args.length != 3) { writeln("args?!"); return 1; }

  auto f0 = VFile(args[1]);
  auto f1 = VFile(args[2]);
  string curtest = null;
  bool waitingTestName = true;

  bool checkTests (string[] t0, string[] t1) {
    if (t0.length != t1.length) return false;
    foreach (immutable idx, string s; t0) if (s != t1[idx]) return false;
    return true;
  }

  int res = 0;

  while (!f0.eof) {
    auto t0 = f0.readTest;
    auto t1 = f1.readTest;
    if (t0 is null) {
      if (t1 !is null) assert(0, "fuck");
      break;
    }
    if (!checkTests(t0, t1)) {
      if (t0.length != t1.length) {
        if (t0[0] != t1[0]) assert(0, "fuck");
        writeln("=== FAILED TEST: ", t0[0], " (", t0.length, ":", t1.length, ") ===");
        dumbDiff(t1, t0);
        res = 1;
      }
    }
  }

  return res;
}
