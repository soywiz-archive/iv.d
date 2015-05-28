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
module iv.hash.joaathash;
// Bob Jenkins' One-At-A-Time hash function


/**
 * 32-bit implementation of joaat
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
public struct JoaatHash {
public:
  enum has64bit = false;
  enum has32bit = true;

private:
  uint seed; // initial seed value; MUST BE FIRST
  uint hash; // current value
  ulong totallen;

public:
@trusted:
nothrow:
@nogc:
  /// construct state with seed
  this (uint aseed) { hash = seed = aseed; }

  /// reset state
  void reset () { totallen = 0; hash = seed; }

  /// reset state
  void reset (uint aseed) { totallen = 0; hash = seed = aseed; }

  /// process data block
  void put(T) (scope const(T)[] data...) if (T.sizeof == 1) {
    if (data.length == 0) return; // nothing to do
    if (totallen == 0) hash = seed;
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    if (totallen+len < totallen) assert(0, "FastHash: too much data"); // overflow
    totallen += len;
    auto h = hash;
    foreach (immutable _; 0..len) {
      h += *bytes++;
      h += (h<<10);
      h ^= (h>>6);
    }
    hash = h;
  }

  /// finalize a hash (i.e. return current result).
  /// note that you can continue putting data, as this is not destructive
  @property uint result32 () const {
    uint h = hash;
    if (totallen == 0) h = seed;
    ulong len = totallen;
    while (len != 0) {
      h += len&0xff;
      h += (h<<10);
      h ^= (h>>6);
      len >>= 8;
    }
    h += (h<<3);
    h ^= (h>>11);
    h += (h<<15);
    return h;
  }

  uint finish32 () { auto res = result32; reset(); return res; }
}


/**
 * 32-bit implementation of joaathash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
uint joaatHash32(T) (const(T)[] buf, uint seed=0) @trusted nothrow @nogc if (T.sizeof == 1) {
  auto hh = JoaatHash(seed);
  hh.put(buf);
  return hh.result32;
}


unittest {
  static assert(joaatHash32("Alice & Miriel") == 0x17fa5136U);

  /*{
    import std.stdio;
    writefln("0x%08xU", joaatHash32("Alice & Miriel"));
  }*/

  mixin(import("test.d"));
  doTest!(32, "JoaatHash")("Alice & Miriel", 0x17fa5136U);
}
