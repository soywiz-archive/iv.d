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
module iv.strex /*is aliced*/;


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


version(test_strex) unittest {
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


string detab (const(char)[] s, uint tabSize=8) {
  assert(tabSize > 0);

  import std.array : appender;
  auto res = appender!string();
  uint col = 0;

  foreach (char ch; s) {
    if (ch == '\n' || ch == '\r') {
      col = 0;
    } else if (ch == '\t') {
      auto spins = tabSize-col%tabSize;
      col += spins;
      while (spins-- > 1) res.put(' ');
      ch = ' ';
    } else {
      ++col;
    }
    res.put(ch);
  }

  return res.data;
}


version(test_strex) unittest {
  assert(detab(" \n\tx", 9) == " \n         x");
  assert(detab("  ab\t asdf ") == "  ab     asdf ");
}


auto byLine(T) (T s) if (is(T : const(char)[])) {
  static struct Range(T) {
  nothrow @safe @nogc:
  private:
    T s;
    size_t llen, npos;
    this (T as) { s = as; popFront(); }
  public:
    @property bool empty () const { pragma(inline, true); return (s.length == 0); }
    @property T front () const { pragma(inline, true); return cast(T)s[0..llen]; } // fuckin' const!
    auto save () const @trusted { Range!T res = void; res.s = s; res.llen = llen; res.npos = npos; return res; }
    void popFront () @trusted {
      s = s[npos..$];
      llen = npos = 0;
      while (npos < s.length) {
        if (s.ptr[npos] == '\r') {
          llen = npos;
          if (s.length-npos > 1 && s.ptr[npos+1] == '\n') ++npos;
          ++npos;
          return;
        }
        if (s.ptr[npos] == '\n') {
          llen = npos;
          ++npos;
          return;
        }
        ++npos;
      }
      llen = npos;
    }
  }
  return Range!T(s);
}

/*
version(test_strex) unittest {
  enum s = q{
       import std.stdio;
       void main() {
           writeln("Hello");
       }
    };
    enum ugly = q{
import std.stdio;
void main() {
    writeln("Hello");
}
};

  foreach (auto line; s.byLine) {
    import std.stdio;
    writeln("LN: [", line, "]");
  }

  foreach (auto line; ugly.byLine) {
    import std.stdio;
    writeln("LN: [", line, "]");
  }
}
*/

// string should be detabbed!
string outdentAll (const(char)[] s) {
  import std.array : appender;
  // first calculate maximum indent spaces
  uint maxspc = uint.max;
  foreach (/*auto*/ line; s.byLine) {
    uint col = 0;
    while (col < line.length && line.ptr[col] <= ' ') {
      if (line.ptr[col] == '\t') assert(0, "can't outdent shit with tabs");
      ++col;
    }
    if (col >= line.length) continue; // empty line, don't care
    if (col < maxspc) maxspc = col;
    if (col == 0) break; // nothing to do anymore
  }

  auto res = appender!string();
  foreach (/*auto*/ line; s.byLine) {
    uint col = 0;
    while (col < line.length && line.ptr[col] <= ' ') ++col;
    if (col < line.length) {
      // non-empty line
      res.put(line[maxspc..$]);
    }
    res.put('\n');
  }

  return res.data;
}


version(test_strex) unittest {
    enum pretty = q{
       import std.stdio;
       void main() {
           writeln("Hello");
       }
    }.outdentAll;

    enum ugly = q{
import std.stdio;
void main() {
    writeln("Hello");
}

};

  import std.stdio;
  assert(pretty == ugly);
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
