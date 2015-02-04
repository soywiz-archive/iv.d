/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
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

  foreach (/*auto*/b; data) {
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

  foreach (/*auto*/b; data) {
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


version(none) {
enum e = encodeAscii85("One, two, Freddy's coming for you");
enum s = decodeAscii85(`:Ms_p+EVgG/0IE&ARo=s-Z^D?Df'3+B-:f)EZfXGFT`);

void main () {
  import iv.writer;
  writeln(s);
  writeln(decodeAscii85(e) == s);
}
}
