import iv.hash.fasthash;
import iv.hash.joaat;
import iv.hash.murhash;

import iv.pxclock;
import iv.vfs.io;

/*
    TESTHASH(x86, 32, 1234, "Hello, world!", "faf6cdb3");
    TESTHASH(x86, 32, 4321, "Hello, world!", "bf505788");
    TESTHASH(x86, 32, 1234, "xxxxxxxxxxxxxxxxxxxxxxxxxxxx", "8905ac28");
    TESTHASH(x86, 32, 1234, "", "0f2cc00b");
*/

void doHash(T, bool norand=false) (scope const(void)[] buf, uint eta, uint seed=0) if (is(T == struct)) {
  T hash;
  if (seed) hash.reset(seed);
  static if (norand) {
    hash.put(buf);
  } else {
    while (buf.length > 0) {
      import std.random : uniform;
      auto len = uniform!"[]"(0, buf.length);
      hash.put(buf[0..len]);
      buf = buf[len..$];
    }
  }
  auto h = hash.finish32();
  if (h != eta) assert(0, T.stringof~" failed "~(norand ? "initial " : "")~"streaming test");
}


void doTest(T) (scope const(void)[] buf, uint eta, uint seed=0) if (is(T == struct)) {
  enum Tries = 100000;
  write(T.stringof, ": ");
  auto stt = clockMilli();
  doHash!(T, true)(buf, eta, seed);
  foreach (immutable _; 0..Tries) doHash!T(buf, eta, seed);
  auto ett = clockMilli()-stt;
  writeln(Tries, " times took ", ett, " milliseconds");
}


void main () {
  //doTest!JoaatHash();
  //doTest!FastHash();
  doTest!MurHash("Hello, world!", 0xfaf6cdb3U, 1234);
  doTest!MurHash("Hello, world!", 0xbf505788U, 4321);
  doTest!MurHash("xxxxxxxxxxxxxxxxxxxxxxxxxxxx", 0x8905ac28U, 1234);
  doTest!MurHash("", 0x0f2cc00bU, 1234);
}
