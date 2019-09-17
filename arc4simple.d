/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.arc4simple /*is aliced*/;
import iv.alice;


// ///////////////////////////////////////////////////////////////////////// //
struct ARC4Codec {
  ubyte[256] m; // permutation table
  ubyte x, y; // permutation indicies

nothrow @trusted @nogc:
  this (const(void)[] key, usize skipBytes=4096) { reinit(key, skipBytes); }

  void reinit (const(void)[] key, usize skipBytes=4096) {
    assert(key.length > 0);
    auto keybytes = cast(const ubyte*)key.ptr;
    x = y = 0;
    foreach (immutable f; 0..256) m[f] = cast(ubyte)f;
    // create permutation table
    usize kidx = 0;
    ubyte c = 0;
    foreach (immutable f; 0..256) {
      auto kc = keybytes[kidx];
      auto a = m[f];
      c = (c+a+kc)&0xff;
      m[f] = m[c];
      m[c] = a;
      if (++kidx == key.length) kidx = 0;
    }
    // discard first bytes
    while (skipBytes--) {
      x = (x+1)&0xff;
      auto a = m[x];
      y = (y+a)&0xff;
      m[x] = m[y];
      m[y] = a;
    }
  }

  void processBuffer(T) (T[] buf) {
    usize len = T.sizeof*buf.length;
    auto data = cast(ubyte*)buf.ptr;
    foreach (immutable _; 0..len) {
      x = (x+1)&0xff;
      auto a = m[x];
      y = (y+a)&0xff;
      auto bt = (m[x] = m[y]);
      m[y] = a;
      *data++ ^= m[(a+bt)&0xff];
    }
  }
}


// ///////////////////////////////////////////////////////////////////////// //
version(arc4_tests) unittest {
  import std.algorithm;
  import std.stdio;
  writeln("unittest: arc4");
  enum ubyte[] sourceData = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];
  enum ubyte[] encodedData = [51,27,44,79,153,231,133,220,143,156,178,63,31,238,28,138];
  auto data = sourceData.dup;
  {
    auto a4 = ARC4Codec("asspole");
    a4.processBuffer(data);
    assert(equal(encodedData, data));
  }
  {
    auto a4 = ARC4Codec("asspole");
    a4.processBuffer(data);
    assert(equal(sourceData, data));
  }
}
