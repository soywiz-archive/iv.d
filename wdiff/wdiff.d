// simple and free spellchecker
// simple word difference algorithm (found somewhere in teh internets, dunno whose it is)
module wdiff /*is aliced*/;
import iv.alice;


struct DiffEngine {
  int[] dmat;
  int d0, d1; // "virtual dimensions"

  int opIndex (int x, int y) {
    pragma(inline, true);
    return (x >= 0 && y >= 0 && x < d0 && y < d1 ? dmat[y*d0+x] : 0);
  }

  void opIndexAssign (int v, int x, int y) {
    pragma(inline, true);
    if (x >= 0 && y >= 0 && x < d0 && y < d1) dmat[y*d0+x] = v;
  }

  // ad0 and ad1: maximum string lengthes
  void setup (int ad0, int ad1) {
    assert(ad0 > 0 && ad1 > 0);
    ++ad0;
    ++ad1;
    if (dmat.length < ad0*ad1) dmat.length = ad0*ad1;
    d0 = ad0;
    d1 = ad1;
    foreach (int n; 0..ad0) this[n, 0] = n;
    foreach (int n; 0..ad1) this[0, n] = n;
  }

  // compare str0 and str1, return "difference count"
  int diffCount (const(char)[] str0, const(char)[] str1) {
    int l0 = cast(int)str0.length;
    int l1 = cast(int)str1.length;
    setup(l0, l1);
    foreach (int i1; 1..l0+1) {
      foreach (int i2; 1..l1+1) {
        if (str0.ptr[i1-1] == str1.ptr[i2-1]) {
          this[i1, i2] = this[i1-1, i2-1];
        } else {
          import std.algorithm : min;
          this[i1, i2] = min(this[i1-1, i2], this[i1, i2-1], this[i1-1, i2-1])+1;
        }
      }
    }
    return this[l0, l1];
  }
}


void main () {
  import std.stdio;
  DiffEngine de;
  writeln(de.diffCount(n"хуй", n"хой"));
  writeln(de.diffCount(n"аббат", n"пиздюк"));
  writeln(de.diffCount(n"ебала", n"ебалайка"));
  writeln(de.diffCount(n"поц", n"поцы"));
  writeln(de.diffCount(n"поц", n"пцоы"));
}
