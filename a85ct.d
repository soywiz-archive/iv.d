/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.a85ct is aliced;


// very slow and enifficient ascii85 decoder
string decodeAscii85(T) (const(T)[] src) {
  static immutable uint[5] pow85 = [85*85*85*85u, 85*85*85u, 85*85u, 85u, 1u];
  auto data = cast(const(ubyte)[])src;
  uint tuple = 0;
  int count = 0;
  string res = "";

  void decodeTuple (int bytes) @safe nothrow {
    while (bytes-- > 0) {
      res ~= (tuple>>24)&0xff;
      tuple <<= 8;
    }
  }

  foreach (immutable b; data) {
    if (b <= 32 || b > 126) continue; // skip blanks
    if (b == 'z') {
      // zero tuple
      if (count != 0) return null; // alas
      res ~= "\0\0\0\0";
    } else {
      if (b < '!' || b > 'u') return null; // alas
      tuple += (b-'!')*pow85[count++];
      if (count == 5) {
        decodeTuple(4);
        tuple = 0;
        count = 0;
      }
    }
  }
  // write last (possibly incomplete) tuple
  if (count > 1) {
    tuple += pow85[--count];
    decodeTuple(count);
  }
  return res;
}


string encodeAscii85(T) (const(T)[] src, int width=76) {
  auto data = cast(const(ubyte)[])src;
  uint tuple = 0;
  int count = 0, pos = 0;
  string res;

  void encodeTuple () @safe nothrow {
    int tmp = 5;
    ubyte[5] buf;
    size_t bpos = 0;
    do {
      buf[bpos++] = tuple%85;
      tuple /= 85;
    } while (--tmp > 0);
    tmp = count;
    do {
      if (width > 0 && pos >= width) { res ~= '\n'; pos = 0; }
      res ~= cast(char)(buf[--bpos]+'!');
      ++pos;
    } while (tmp-- > 0);
  }

  foreach (immutable b; data) {
    switch (count++) {
      case 0: tuple |= b<<24; break;
      case 1: tuple |= b<<16; break;
      case 2: tuple |= b<<8; break;
      case 3:
        tuple |= b;
        if (tuple == 0) {
          // special case
          if (width > 0 && pos >= width) { res ~= '\n'; pos = 0; }
          res ~= 'z';
          ++pos;
        } else {
          encodeTuple();
        }
        tuple = 0;
        count = 0;
        break;
      default: assert(0);
    }
  }
  if (count > 0) encodeTuple();
  return res;
}


// for mixin
template a85enc(string s) {
  private static enum qstr(string s) = s.stringof;
  enum a85enc = qstr!(encodeAscii85(s, 0));
}


// fox mixin
template a85dec(string s) {
  private static enum qstr(string s) = s.stringof;
  enum a85dec = qstr!(decodeAscii85(s));
}


version(none) {
enum e = encodeAscii85("One, two, Freddy's coming for you");
enum s = decodeAscii85(`:Ms_p+EVgG/0IE&ARo=s-Z^D?Df'3+B-:f)EZfXGFT`);

void main () {
  import iv.writer;
  writeln(s);
  writeln(decodeAscii85(e) == s);
}
}
