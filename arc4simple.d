/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 1, September 2015
 *
 * Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
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
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 1. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 2. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0 and 1 of this license.
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
 * License: IVPLv1
 */
module iv.arc4simple is aliced;


// ///////////////////////////////////////////////////////////////////////// //
struct ARC4Codec {
  ubyte[256] m; // permutation table
  ubyte x, y; // permutation indicies

@trusted:
nothrow:
@nogc:
  this (const(void)[] key, usize skipBytes=4096) => reinit(key, skipBytes);

  void reinit (const(void)[] key, usize skipBytes=4096) {
    assert(key.length > 0);
    auto keybytes = cast(const ubyte *)key.ptr;
    x = y = 0;
    foreach (auto f; 0..256) m[f] = cast(ubyte)f;
    // create permutation table
    usize kidx = 0;
    ubyte c = 0;
    foreach (auto f; 0..256) {
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
    auto data = cast(ubyte *)buf.ptr;
    foreach (; 0..len) {
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
unittest {
  import std.algorithm;
  import iv.writer;
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
