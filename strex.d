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
module iv.strex;


/// quote string: append double quotes, screen all special chars;
/// so quoted string forms valid D string literal.
/// allocates.
string quote (string s) {
  import std.array : appender;
  import std.format : formatElement, FormatSpec;
  auto res = appender!string();
  FormatSpec!char fspc; // defaults to 's'
  formatElement(res, s, fspc);
  return res.data;
}


ptrdiff_t indexOf (const(void)[] hay, const(void)[] need, size_t stIdx=0) pure @trusted nothrow @nogc {
  if (hay.length <= stIdx || need.length == 0 ||
      need.length > hay.length-stIdx
  ) {
    return -1;
  } else {
    import iv.strex : memmem;
    auto res = memmem(hay.ptr+stIdx, hay.length-stIdx, need.ptr, need.length);
    return (res !is null ? cast(ptrdiff_t)(res-hay.ptr) : -1);
  }
}


ptrdiff_t indexOf (const(void)[] hay, ubyte ch, size_t stIdx=0) pure @trusted nothrow @nogc {
  return indexOf(hay, (&ch)[0..1], stIdx);
}


unittest {
  assert(indexOf("Alice & Miriel", " & ") == 5);
  assert(indexOf("Alice & Miriel", " &!") == -1);
  assert(indexOf("Alice & Miriel", "Alice & Miriel was here!") == -1);
  assert(indexOf("Alice & Miriel", '&') == 6);
  char ch = ' ';
  assert(indexOf("Alice & Miriel", ch) == 5);

  assert(indexOf("Alice & Miriel", "i") == 2);
  assert(indexOf("Alice & Miriel", "i", 6) == 9);
  assert(indexOf("Alice & Miriel", "i", 12) == -1);

  assert(indexOf("Alice & Miriel", "Miriel", 8) == 8);
  assert(indexOf("Alice & Miriel", "Miriel", 9) == -1);
}

extern(C):
@system:
nothrow:
@nogc:
pure inout(void)* memmem (inout(void)* haystack, size_t haystacklen, inout(void)* needle, size_t needlelen);
