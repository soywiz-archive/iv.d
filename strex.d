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
// some string operations: quoting, `indexOf()` for non-utf8
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


/// convert integral number to number with commas
char[] intWithCommas(T) (char[] dest, T nn, char comma=',') if (__traits(isIntegral, T)) {
  static if (__traits(isUnsigned, T)) {
    enum neg = false;
    alias n = nn;
  } else {
    bool neg = (nn < 0);
    static if (T.sizeof < 8) {
      long n = nn;
      if (neg) n = -n;
      if (n < 0) n = T.max;
    } else {
      alias n = nn;
      if (neg) n = -n;
      if (n < 0) n = T.max; //FIXME
    }
  }
  char[256] buf = void;
  int bpos = cast(int)buf.length;
  int leftToComma = 3;
  do {
    if (leftToComma-- == 0) { buf[--bpos] = comma; leftToComma = 2; }
    buf[--bpos] = cast(char)('0'+n%10);
  } while ((n /= 10) != 0);
  if (neg) buf[--bpos] = '-';
  auto len = buf.length-bpos;
  if (dest is null) dest = new char[](len);
  if (len > dest.length) len = dest.length;
  dest[0..len] = buf[bpos..bpos+len];
  return dest[0..len];
}

char[] intWithCommas(T) (T nn, char comma=',') if (__traits(isIntegral, T)) { return intWithCommas(null, nn, comma); }


char tolower (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= 'A' && ch <= 'Z' ? cast(char)(ch-'A'+'a') : ch); }
char toupper (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= 'a' && ch <= 'z' ? cast(char)(ch-'a'+'A') : ch); }

bool islower (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= 'a' && ch <= 'z'); }
bool isupper (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= 'A' && ch <= 'Z'); }

bool isalpha (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')); }
bool isdigit (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= '0' && ch <= '9'); }
bool isalnum (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')); }
bool isxdigit (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f') || (ch >= '0' && ch <= '9')); }

int digitInBase (char ch, int base=10) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return
    ch >= '0' && ch <= '9' && ch-'0' < base ? ch-'0' :
    base > 10 && ch >= 'A' && ch < 'Z' && ch-'A'+10 < base ? ch-'A'+10 :
    base > 10 && ch >= 'a' && ch < 'z' && ch-'a'+10 < base ? ch-'a'+10 :
    -1;
}


alias atof = atofd!float; /// very simple atof/atod converter. accepts exponents. returns NaN on error.
alias atod = atofd!double; /// very simple atof/atod converter. accepts exponents. returns NaN on error.

/// very simple atof/atod converter. accepts exponents.
/// returns NaN on error.
T atofd(T) (const(char)[] str) pure nothrow @trusted @nogc if (is(T == float) || is(T == double)) {
  if (str.length == 0) return T.nan; // oops

  const(char)[] s = str;
  double res = 0.0, sign = 1.0;
  bool hasIntPart = false, hasFracPart = false;

  char peekChar () nothrow @trusted @nogc { pragma(inline, true); return (s.length ? s.ptr[0] : '\0'); }
  void skipChar () nothrow @trusted @nogc { pragma(inline, true); if (s.length > 0) s = s[1..$]; }
  char getChar () nothrow @trusted @nogc { char ch = 0; if (s.length > 0) { ch = s.ptr[0]; s = s[1..$]; } return ch; }

  // optional sign
  switch (peekChar) {
    case '-': sign = -1; goto case;
    case '+': skipChar(); break;
    default: break;
  }

  // integer part
  if (isdigit(peekChar)) {
    hasIntPart = true;
    while (isdigit(peekChar)) res = res*10.0+(getChar()-'0');
  }

  // fractional part.
  if (peekChar == '.') {
    skipChar(); // skip '.'
    if (isdigit(peekChar)) {
      hasFracPart = true;
      int divisor = 1;
      long num = 0;
      while (isdigit(peekChar)) {
        divisor *= 10;
        num = num*10+(getChar()-'0');
      }
      res += cast(double)num/divisor;
    }
  }

  // valid number should have integer or fractional part
  if (!hasIntPart && !hasFracPart) return T.nan;

  // optional exponent
  if (peekChar == 'e' || peekChar == 'E') {
    skipChar(); // skip 'E'
    // optional sign
    bool epositive = true;
    switch (peekChar) {
      case '-': epositive = false; goto case;
      case '+': skipChar(); break;
      default: break;
    }
    int expPart = 0;
    while (isdigit(peekChar)) expPart = expPart*10+(getChar()-'0');
    if (epositive) {
      foreach (immutable _; 0..expPart) res *= 10.0;
    } else {
      foreach (immutable _; 0..expPart) res /= 10.0;
    }
  }

  return cast(T)(res*sign);
}


// ascii only
bool strEquCI (const(char)[] s0, const(char)[] s1) pure nothrow @trusted @nogc {
  if (s0.length != s1.length) return false;
  foreach (immutable idx, char c0; s0) {
    if (__ctfe) {
      if (c0.tolower != s1[idx].tolower) return false;
    } else {
      if (c0.tolower != s1.ptr[idx].tolower) return false;
    }
  }
  return true;
}


// ascii only
int strCmpCI (const(char)[] s0, const(char)[] s1) pure nothrow @trusted @nogc {
  auto slen = s0.length;
  if (slen > s1.length) slen = s1.length;
  char c1;
  foreach (immutable idx, char c0; s0[0..slen]) {
    c0 = c0.tolower;
    if (__ctfe) {
      c1 = s1[idx].tolower;
    } else {
      c1 = s1.ptr[idx].tolower;
    }
    if (c0 < c1) return -1;
    if (c0 > c1) return 1;
  }
  if (s0.length < s1.length) return -1;
  if (s0.length > s1.length) return 1;
  return 0;
  /+
  if (s0.length < s1.length) return -1;
  if (s0.length > s1.length) return 1;
  char c1;
  foreach (immutable idx, char c0; s0) {
    c0 = c0.tolower;
    if (__ctfe) {
      c1 = s1[idx].tolower;
    } else {
      c1 = s1.ptr[idx].tolower;
    }
    if (c0 < c1) return -1;
    if (c0 > c1) return 1;
  }
  return 0;
  +/
}


inout(char)[] xstrip (inout(char)[] s) pure nothrow @trusted @nogc {
  while (s.length && s.ptr[0] <= ' ') s = s[1..$];
  while (s.length && s[$-1] <= ' ') s = s[0..$-1];
  return s;
}


inout(char)[] xstripleft (inout(char)[] s) pure nothrow @trusted @nogc {
  while (s.length && s.ptr[0] <= ' ') s = s[1..$];
  return s;
}


inout(char)[] xstripright (inout(char)[] s) pure nothrow @trusted @nogc {
  while (s.length && s[$-1] <= ' ') s = s[0..$-1];
  return s;
}


bool startsWith (const(char)[] str, const(char)[] pat) pure nothrow @trusted @nogc {
  import core.stdc.string : memcmp;
  if (pat.length > str.length) return false;
  return (memcmp(str.ptr, pat.ptr, pat.length) == 0);
}


bool endsWith (const(char)[] str, const(char)[] pat) pure nothrow @trusted @nogc {
  import core.stdc.string : memcmp;
  if (pat.length > str.length) return false;
  return (memcmp(str.ptr+str.length-pat.length, pat.ptr, pat.length) == 0);
}


bool startsWithCI (const(char)[] str, const(char)[] pat) pure nothrow @trusted @nogc {
  if (pat.length > str.length) return false;
  auto s = cast(const(char)*)str.ptr;
  auto p = cast(const(char)*)pat.ptr;
  foreach (immutable _; 0..pat.length) if (tolower(*s++) != tolower(*p++)) return false;
  return true;
}


bool endsWithCI (const(char)[] str, const(char)[] pat) pure nothrow @trusted @nogc {
  if (pat.length > str.length) return false;
  auto s = cast(const(char)*)str.ptr+str.length-pat.length;
  auto p = cast(const(char)*)pat.ptr;
  foreach (immutable _; 0..pat.length) if (tolower(*s++) != tolower(*p++)) return false;
  return true;
}


ptrdiff_t indexOf (const(char)[] hay, const(char)[] need, size_t stIdx=0) pure nothrow @trusted @nogc {
  if (hay.length <= stIdx || need.length == 0 || need.length > hay.length-stIdx) {
    return -1;
  } else {
    auto res = cast(char*)memmem(hay.ptr+stIdx, hay.length-stIdx, need.ptr, need.length);
    return (res !is null ? cast(ptrdiff_t)(res-hay.ptr) : -1);
  }
}

ptrdiff_t indexOf (const(char)[] hay, char ch, size_t stIdx=0) pure nothrow @trusted @nogc {
  return indexOf(hay, (&ch)[0..1], stIdx);
}


ptrdiff_t lastIndexOf (const(char)[] hay, const(char)[] need, size_t stIdx=0) pure nothrow @trusted @nogc {
  if (hay.length <= stIdx || need.length == 0 || need.length > hay.length-stIdx) {
    return -1;
  } else {
    auto res = cast(char*)memrmem(hay.ptr+stIdx, hay.length-stIdx, need.ptr, need.length);
    return (res !is null ? cast(ptrdiff_t)(res-hay.ptr) : -1);
  }
}

ptrdiff_t lastIndexOf (const(char)[] hay, char ch, size_t stIdx=0) pure nothrow @trusted @nogc {
  return lastIndexOf(hay, (&ch)[0..1], stIdx);
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

  assert(lastIndexOf("Alice & Miriel", "i") == 11);
  assert(lastIndexOf("Alice & Miriel", "i", 6) == 11);
  assert(lastIndexOf("Alice & Miriel", "i", 11) == 11);
  assert(lastIndexOf("Alice & Miriel", "i", 12) == -1);

  assert(lastIndexOf("iiii", "ii") == 2);
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

  foreach (/+auto+/ line; s.byLine) {
    import std.stdio;
    writeln("LN: [", line, "]");
  }

  foreach (/+auto+/ line; ugly.byLine) {
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


pure nothrow @system @nogc:
version(linux) {
  extern(C) inout(void)* memmem (inout(void)* haystack, size_t haystacklen, inout(void)* needle, size_t needlelen);
  extern(C) inout(void)* memrchr (inout(void)* s, int ch, size_t slen);
} else {
  inout(void)* memmem (inout(void)* haystack, size_t haystacklen, inout(void)* needle, size_t needlelen) {
    // size_t is unsigned
    if (needlelen > haystacklen || needlelen == 0) return null;
    auto h = cast(const(ubyte)*)haystack;
    auto n = cast(const(ubyte)*)needle;
    foreach (immutable i; 0..haystacklen-needlelen+1) {
      import core.stdc.string : memcmp;
      if (memcmp(h+i, n, needlelen) == 0) return cast(typeof(return))(h+i);
    }
    return null;
  }

  inout(void)* memrchr (inout(void)* haystack, int ch, size_t haystacklen) {
    // size_t is unsigned
    if (haystacklen == 0) return null;
    auto h = cast(const(ubyte)*)haystack;
    ch &= 0xff;
    foreach_reverse (immutable idx, ubyte v; h[0..haystacklen]) {
      if (v == ch) return cast(typeof(return))(h+idx);
    }
    return null;
  }
}

inout(void)* memrmem (inout(void)* haystack, size_t haystacklen, inout(void)* needle, size_t needlelen) {
  if (needlelen > haystacklen) return null;
  auto h = cast(const(ubyte)*)haystack;
  const(ubyte)* res = null;
  // size_t is unsigned
  if (needlelen > haystacklen || needlelen == 0) return null;
  version(none) {
    size_t pos = 0;
    while (pos < haystacklen-needlelen+1) {
      auto ff = memmem(haystack+pos, haystacklen-pos, needle, needlelen);
      if (ff is null) break;
      res = cast(const(ubyte)*)ff;
      pos = cast(size_t)(res-haystack)+1;
    }
    return cast(void*)res;
  } else {
    auto n = cast(const(ubyte)*)needle;
    size_t len = haystacklen-needlelen+1;
    while (len > 0) {
      import core.stdc.string : memcmp;
      auto ff = cast(const(ubyte)*)memrchr(haystack, *n, len);
      if (ff is null) break;
      if (memcmp(ff, needle, needlelen) == 0) return cast(void*)ff;
      //if (ff is h) break;
      len = cast(size_t)(ff-cast(ubyte*)haystack);
    }
    return null;
  }
}
