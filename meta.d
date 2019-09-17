/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
// various "metaprogramming" utilities
// some of 'em duplicates functionality of `std.traits` and other such
// modules, to avoid importing the whole phobos. sorry.
module iv.meta is aliced;


// ////////////////////////////////////////////////////////////////////////// //
/** this is character buffer that can be used to build strings in CTFE.
 *
 * doing naive string concatenation in CTFE leads to excessive memory
 * consuming and slowdowns ('cause compiler allocates a new string each
 * time, and old one stays in memory forever). by using this simple
 * buffer, we can cut CTFE code generation times and memory consumption
 * by magnitutes (no, really!).
 *
 * it is better to create non-resizeable buffers. the easiest (albeit
 * stupid ;-) way to do that is to increase initial buffer size until
 * compilation succeeds. sorry, there is no `ctfeWrite()` in Aliced
 * yet. i'm working on it.
 */
public struct CTFECharBuffer(bool allowResize) {
  // i see no reason to hide this
  char[] buf;
  uint bufpos = 0;

  /// create buffer with the given size
  this (uint maxsize) { buf.length = maxsize; }

  static if (allowResize) {
    /// put something into the buffer
    void put (const(char)[] s...) nothrow @trusted {
      if (s.length == 0) return;
      if (buf.length-bufpos < s.length) {
        //FIXME: overflows
        uint newsz = cast(uint)(s.length-(buf.length-bufpos));
        if (buf.length < 65536) newsz += cast(uint)buf.length*2; else newsz += 65536;
        buf.length = newsz;
      }
      assert(buf.length-bufpos >= s.length);
      buf[bufpos..bufpos+s.length] = s[];
      bufpos += cast(uint)s.length;
    }
  } else {
    /// put something into the buffer
    void put (const(char)[] s...) nothrow @trusted @nogc {
      if (s.length == 0) return;
      if (buf.length-bufpos < s.length) assert(0, "out of buffer");
      buf[bufpos..bufpos+s.length] = s[];
      bufpos += cast(uint)s.length;
    }
  }

  /// put lo-cased ASCII char into the buffer
  void putLoCased() (char ch) nothrow @trusted {
    if (ch >= 'A' && ch <= 'Z') ch += 32;
    put(ch);
  }

  /// put string with lo-cased first char into the buffer
  void putStrLoCasedFirst() (const(char)[] s...) nothrow @trusted {
    if (s.length == 0) return;
    putLoCased(s[0]);
    put(s[1..$]);
  }

  /// put string into the buffer with all chars lo-cased
  void putStrLoCased() (const(char)[] s...) nothrow @trusted {
    if (s.length == 0) return;
    foreach (char ch; s) {
      if (ch >= 'A' && ch <= 'Z') ch += 32;
      put(ch);
    }
  }

  /// get buffer as string.
  /// WARNING! don't modify buffer after this! i won't put any guards here.
  @property string asString () const nothrow @trusted @nogc => cast(string)buf[0..bufpos];
}


// ////////////////////////////////////////////////////////////////////////// //
/// removes all qualifiers, if any, from type `T`
template Unqual(T) {
       static if (is(T U ==          immutable U)) alias Unqual = U;
  else static if (is(T U == shared inout const U)) alias Unqual = U;
  else static if (is(T U == shared inout       U)) alias Unqual = U;
  else static if (is(T U == shared       const U)) alias Unqual = U;
  else static if (is(T U == shared             U)) alias Unqual = U;
  else static if (is(T U ==        inout const U)) alias Unqual = U;
  else static if (is(T U ==        inout       U)) alias Unqual = U;
  else static if (is(T U ==              const U)) alias Unqual = U;
  else alias Unqual = T;
}


// ////////////////////////////////////////////////////////////////////////// //
/// is `T` char, wchar, or dchar? can ignore qualifiers if `unqual` is `true`.
template isAnyCharType(T, bool unqual=false) {
  static if (unqual) private alias UT = Unqual!T; else private alias UT = T;
  enum isAnyCharType = is(UT == char) || is(UT == wchar) || is(UT == dchar);
}


// ////////////////////////////////////////////////////////////////////////// //
/// is `T` wchar, or dchar? can ignore qualifiers if `unqual` is `true`.
template isWideCharType(T, bool unqual=false) {
  static if (unqual) private alias UT = Unqual!T; else private alias UT = T;
  enum isWideCharType = is(UT == wchar) || is(UT == dchar);
}
