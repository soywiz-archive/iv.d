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
module iv.strex;


/// quote string: append double quotes, screen all special chars;
/// so quoted string forms valid D string literal.
/// allocates.
string quote (const(char)[] s) {
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
    //import iv.strex : memmem;
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

@system:
nothrow:
@nogc:
pure:
version(linux) {
  extern(C) inout(void)* memmem (inout(void)* haystack, size_t haystacklen, inout(void)* needle, size_t needlelen);
} else {
  inout(void)* memmem (inout(void)* haystack, size_t haystacklen, inout(void)* needle, size_t needlelen) {
    auto h = cast(const(ubyte)*)haystack;
    auto n = cast(const(ubyte)*)needle;
    // size_t is unsigned
    if (needlelen > haystacklen) return null;
    foreach (immutable i; 0..haystacklen-needlelen+1) {
      import core.stdc.string : memcmp;
      if (memcmp(h+i, n, needlelen) == 0) return cast(void*)(h+i);
    }
    return null;
  }
}
