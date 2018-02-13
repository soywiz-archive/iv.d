/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
/// very simple (de)serializer to json-like text format
module iv.txtser /*is aliced*/;
private:

import std.range : ElementEncodingType, isInputRange, isOutputRange;
import std.traits : Unqual;
import iv.alice;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public enum SRZIgnore; /// ignore this field
public struct SRZName { string name; } /// rename this field
public enum SRZNonDefaultOnly; /// write only if it has non-default value


// ////////////////////////////////////////////////////////////////////////// //
template arrayElementType(T) {
  private import std.traits : isArray, Unqual;
  static if (isArray!T) {
    alias arrayElementType = arrayElementType!(typeof(T.init[0]));
  } else static if (is(typeof(T))) {
    alias arrayElementType = Unqual!(typeof(T));
  } else {
    alias arrayElementType = Unqual!T;
  }
}
static assert(is(arrayElementType!string == char));

template isSimpleType(T) {
  private import std.traits : Unqual;
  private alias UT = Unqual!T;
  enum isSimpleType = __traits(isIntegral, UT) || __traits(isFloating, UT) || is(UT == bool);
}

template isCharType(T) {
  private import std.traits : Unqual;
  private alias UT = Unqual!T;
  enum isCharType = is(UT == char) || is(UT == wchar) || is(UT == dchar);
}


// ////////////////////////////////////////////////////////////////////////// //
///
public void txtser(T, ST) (in auto ref T v, auto ref ST fl, int indent=0, bool skipstname=false)
if (!is(T == class) && (isWriteableStream!ST || isOutputRange!(ST, char)))
{
  enum Indent = 2;

  void xput (const(char)[] s...) {
    if (s.length == 0) return;
    static if (isWriteableStream!ST) {
      fl.rawWrite(s[]);
    } else {
      static if (is(typeof(fl.put(s)))) {
        fl.put(s);
      } else {
        foreach (char ch; s) fl.put(ch);
      }
    }
  }

  void quote (const(char)[] s) {
    static immutable string hexd = "0123456789abcdef";
    xput('"');
    bool goodString = true;
    foreach (char ch; s) if (ch < ' ' || ch == 127 || ch == '"' || ch == '\\') { goodString = false; break; }
    if (goodString) {
      // easy deal
      xput(s);
    } else {
      // hard time
      usize pos = 0;
      while (pos < s.length) {
        auto epos = pos;
        while (epos < s.length) {
          auto ch = s.ptr[epos];
          if (ch < ' ' || ch == 127 || ch == '"' || ch == '\\') break;
          ++epos;
        }
        if (epos > pos) {
          xput(s[pos..epos]);
          pos = epos;
        }
        if (pos < s.length) {
          auto ch = s.ptr[pos++];
          if (ch < ' ' || ch == 127 || ch == '"' || ch == '\\') {
            switch (ch) {
              case '\x1b': xput(`\e`); break;
              case '\r': xput(`\r`); break;
              case '\n': xput(`\n`); break;
              case '\t': xput(`\t`); break;
              case '"': case '\\': xput(`\`); xput(ch); break;
              default:
                xput(`\x`);
                xput(hexd[(ch>>4)&0x0f]);
                xput(hexd[ch&0x0f]);
                break;
            }
          } else {
            xput(ch);
          }
        }
      }
    }
    xput('"');
  }

  void newline () {
    xput('\n');
    foreach (immutable _; 0..indent) xput(' ');
  }

  void serData(bool skipstructname=false, T) (in ref T v) {
    alias UT = arrayElementType!T;
    static if (is(T : const(char)[])) {
      // string
      static if (is(T == string) || is(T == const(char)[])) {
        if (v.ptr is null) xput("null"); else quote(v);
      } else {
        quote(v);
      }
    } else static if (is(T : V[], V)) {
      // array
      if (v.length) {
        xput("[");
        indent += Indent;
        foreach (immutable idx, const ref it; v) {
          if (idx == 0 || (v.length >= 56 && idx%42 == 41)) newline();
          serData!true(it);
          if (idx != v.length-1) xput(",");
        }
        indent -= Indent;
        newline;
        xput("]");
      } else {
        xput("[]");
      }
    } else static if (is(T : V[K], K, V)) {
      // associative array
      if (v.length) {
        xput("{");
        indent += Indent;
        auto len = v.length;
        foreach (const kv; v.byKeyValue) {
          newline;
          serData!true(kv.key);
          xput(": ");
          serData!true(kv.value);
          if (--len) xput(",");
        }
        indent -= Indent;
        newline;
        xput("}");
      } else {
        xput("{}");
      }
    } else static if (isCharType!UT) {
      import std.conv : to;
      xput((cast(uint)v).to!string);
    } else static if (isSimpleType!UT) {
      import std.conv : to;
      xput(v.to!string);
    } else static if (is(UT == struct)) {
      import std.traits : FieldNameTuple, getUDAs, hasUDA;
      static if (skipstructname) {
        xput("{");
      } else {
        xput(UT.stringof);
        xput(": {");
      }
      indent += Indent;
      bool needComma = false;
      foreach (string fldname; FieldNameTuple!UT) {
        static if (!hasUDA!(__traits(getMember, UT, fldname), SRZIgnore)) {
          enum names = getUDAs!(__traits(getMember, UT, fldname), SRZName);
          static if (names.length) enum xname = names[0].name; else enum xname = fldname;
          static assert(xname.length <= 255, "struct '"~UT.stringof~"': field name too long: "~xname);
          static if (hasUDA!(__traits(getMember, UT, fldname), SRZNonDefaultOnly)) {
            if (__traits(getMember, v, fldname) == __traits(getMember, v, fldname).init) continue;
          }
          if (needComma) xput(",");
          newline;
          xput(xname);
          xput(": ");
          serData!true(__traits(getMember, v, fldname));
          needComma = true;
        }
      }
      indent -= Indent;
      newline;
      xput("}");
    } else {
      static assert(0, "can't serialize type '"~T.stringof~"'");
    }
  }

  if (skipstname) serData!true(v); else serData(v);
}


// ////////////////////////////////////////////////////////////////////////// //
///
public enum isGoodSerParser(T) = is(typeof((inout int=0) {
  auto t = T.init;
  char ch = t.curch;
  ch = t.peek;
  t.skipChar();
  bool b = t.eot;
  t.skipBlanks();
  int l = t.line;
  int c = t.col;
  const(char)[] s = t.expectId!true();
  s = t.expectId!false;
  b = T.isGoodIdChar(' ');
  t.expectChar('!');
  int d = T.digitInBase('1', 10);
  t.error("message");
  t.parseString!true(delegate (char ch) {});
  t.parseString!false(delegate (char ch) {});
}));


///
public struct TxtSerParser(ST) if (isReadableStream!ST || (isInputRange!ST && is(Unqual!(ElementEncodingType!ST) == char))) {
private:
  ST st;
  int eotflag; // 0: not; 1: at peek; -1: at front; -2: done
  // buffer for identifier reading
  char[128] buf = 0;
  int bpos = 0;
  static if (isReadableStream!ST) {
    enum AsStream = true;
    char[256] rdbuf = 0;
    uint rdpos, rdused;
  } else {
    enum AsStream = false;
  }

public:
  int line, col;
  char curch, peek;

public:
  this() (auto ref ST stream) {
    st = stream;
    // load first chars
    skipChar();
    skipChar();
    line = 1;
    col = 1;
  }

  void error (string msg) { import std.conv : to; throw new Exception(msg~" around line "~line.to!string~", column "~col.to!string); }

  @property bool eot () const pure nothrow @safe @nogc { pragma(inline, true); return (eotflag < -1); }

  void skipChar () {
    if (eotflag < 0) { curch = peek = 0; eotflag = -2; return; }
    if (curch == '\n') { ++line; col = 1; } else ++col;
    curch = peek;
    if (eotflag > 0) { eotflag = -1; peek = 0; return; }
    // read next char to `peek`
    static if (AsStream) {
      if (rdpos >= rdused) {
        auto read = st.rawRead(rdbuf[]);
        if (read.length == 0) {
          peek = 0;
          eotflag = 1;
          return;
        }
        rdpos = 0;
        rdused = cast(uint)read.length;
      }
      assert(rdpos < rdused);
      peek = rdbuf.ptr[rdpos++];
    } else {
      if (!st.empty) {
        peek = st.front;
        st.popFront;
      } else {
        peek = 0;
        eotflag = 1;
      }
    }
  }

  void skipBlanks () {
    while (!eot) {
      if ((curch == '/' && peek == '/') || curch == '#') {
        while (!eot && curch != '\n') skipChar();
      } else if (curch == '/' && peek == '*') {
        skipChar();
        skipChar();
        while (!eot) {
          if (curch == '*' && peek == '/') {
            skipChar();
            skipChar();
            break;
          }
        }
      } else if (curch == '/' && peek == '+') {
        skipChar();
        skipChar();
        int level = 1;
        while (!eot) {
          if (curch == '+' && peek == '/') {
            skipChar();
            skipChar();
            if (--level == 0) break;
          } else if (curch == '/' && peek == '+') {
            skipChar();
            skipChar();
            ++level;
          }
        }
      } else if (curch > ' ') {
        break;
      } else {
        skipChar();
      }
    }
  }

  void expectChar (char ch) {
    skipBlanks();
    if (eot || curch != ch) error("'"~ch~"' expected");
    skipChar();
  }

  const(char)[] expectId(bool allowQuoted=false) () {
    bpos = 0;
    skipBlanks();
    static if (allowQuoted) {
      if (!eot && curch == '"') {
        skipChar();
        while (!eot && curch != '"') {
          if (curch == '\\') error("simple string expected");
          if (bpos >= buf.length) error("identifier or number too long");
          buf.ptr[bpos++] = curch;
          skipChar();
        }
        if (eot || curch != '"') error("simple string expected");
        skipChar();
        return buf[0..bpos];
      }
    }
    if (!isGoodIdChar(curch)) error("identifier or number expected");
    while (isGoodIdChar(curch)) {
      if (bpos >= buf.length) error("identifier or number too long");
      buf[bpos++] = curch;
      skipChar();
    }
    return buf[0..bpos];
  }

  // `curch` is opening quote
  void parseString(bool allowEscapes) (scope void delegate (char ch) put) {
    assert(put !is null);
    if (eot) error("unterminated string");
    char qch = curch;
    skipChar();
    while (!eot && curch != qch) {
      static if (allowEscapes) if (curch == '\\') {
        skipChar();
        if (eot) error("unterminated string");
        switch (curch) {
          case '0': // oops, octal
            uint ucc = 0;
            foreach (immutable _; 0..4) {
              if (eot) error("unterminated string");
              int dig = digitInBase(curch, 10);
              if (dig < 0) break;
              if (dig > 7) error("invalid octal escape");
              ucc = ucc*8+dig;
              skipChar();
            }
            if (ucc > 255) error("invalid octal escape");
            put(cast(char)ucc);
            break;
          case '1': .. case '9': // decimal
            uint ucc = 0;
            foreach (immutable _; 0..3) {
              if (eot) error("unterminated string");
              int dig = digitInBase(curch, 10);
              if (dig < 0) break;
              ucc = ucc*10+dig;
              skipChar();
            }
            if (ucc > 255) error("invalid decimal escape");
            put(cast(char)ucc);
            break;
          case 'e': put('\x1b'); skipChar(); break;
          case 'r': put('\r'); skipChar(); break;
          case 'n': put('\n'); skipChar(); break;
          case 't': put('\t'); skipChar(); break;
          case '"': case '\\': case '\'': put(curch); skipChar(); break;
          case 'x':
          case 'X':
            if (eot) error("unterminated string");
            if (digitInBase(peek, 16) < 0) error("invalid hex escape");
            skipChar(); // skip 'x'
            if (eot) error("unterminated string");
            if (digitInBase(curch, 16) < 0 || digitInBase(peek, 16) < 0) error("invalid hex escape");
            put(cast(char)(digitInBase(curch, 16)*16+digitInBase(peek, 16)));
            skipChar();
            skipChar();
            break;
          case 'u':
          case 'U':
            if (digitInBase(peek, 16) < 0) error("invalid unicode escape");
            uint ucc = 0;
            skipChar(); // skip 'u'
            foreach (immutable _; 0..4) {
              if (eot) error("unterminated string");
              if (digitInBase(curch, 16) < 0) break;
              ucc = ucc*16+digitInBase(curch, 16);
              skipChar();
            }
            char[4] buf = void;
            auto len = utf8Encode(buf[], cast(dchar)ucc);
            assert(len != 0);
            if (len < 0) error("invalid utf-8 escape");
            foreach (char ch; buf[0..len]) put(ch);
            break;
          default: error("invalid escape");
        }
        continue;
      }
      // normal char
      put(curch);
      skipChar();
    }
    if (eot || curch != qch) error("unterminated string");
    skipChar();
  }

static pure nothrow @safe @nogc:
  bool isGoodIdChar (char ch) {
    pragma(inline, true);
    return
      (ch >= '0' && ch <= '9') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_' || ch == '-' || ch == '+' || ch == '.';
  }

  int digitInBase (char ch, int base) {
    pragma(inline, true);
    return
      base >= 1 && ch >= '0' && ch < '0'+base ? ch-'0' :
      base > 10 && ch >= 'A' && ch < 'A'+base-10 ? ch-'A'+10 :
      base > 10 && ch >= 'a' && ch < 'a'+base-10 ? ch-'a'+10 :
      -1;
  }
}


static assert(isGoodSerParser!(TxtSerParser!VFile));


// ////////////////////////////////////////////////////////////////////////// //
///
public void txtunser(bool ignoreUnknown=false, T, ST) (out T v, auto ref ST fl)
if (!is(T == class) && (isReadableStream!ST || (isInputRange!ST && is(Unqual!(ElementEncodingType!ST) == char))))
{
  auto par = TxtSerParser!ST(fl);
  txtunser!ignoreUnknown(v, par);
}


///
public void txtunser(bool ignoreUnknown=false, T, ST) (out T v, auto ref ST par) if (!is(T == class) && isGoodSerParser!ST) {
  import std.traits : Unqual;

  void skipComma () {
    par.skipBlanks();
    if (par.curch == ',') par.skipChar();
  }

  static if (ignoreUnknown) void skipData(bool fieldname) () {
    par.skipBlanks();
    // string?
    if (par.curch == '"' || par.curch == '\'') {
      par.parseString!(!fieldname)(delegate (char ch) {});
      return;
    }
    static if (!fieldname) {
      // array?
      if (par.curch == '[') {
        par.skipChar();
        for (;;) {
          par.skipBlanks();
          if (par.eot) par.error("unterminated array");
          if (par.curch == ']') break;
          skipData!false();
          skipComma();
        }
        par.expectChar(']');
        return;
      }
      // dictionary?
      if (par.curch == '{') {
        par.skipChar();
        for (;;) {
          par.skipBlanks();
          if (par.eot) par.error("unterminated array");
          if (par.curch == '}') break;
          skipData!true(); // field name
          par.skipBlanks();
          par.expectChar(':');
          skipData!false();
          skipComma();
        }
        par.expectChar('}');
        return;
      }
    }
    // identifier
    if (par.eot || !par.isGoodIdChar(par.curch)) par.error("invalid identifier");
    while (!par.eot && par.isGoodIdChar(par.curch)) par.skipChar();
  }

  void unserData(T) (out T v) {
    if (par.eot) par.error("data expected");
    static if (is(T : const(char)[])) {
      // quoted string
      static if (__traits(isStaticArray, T)) {
        usize dpos = 0;
        void put (char ch) {
          if (v.length-dpos < 1) par.error("value too long");
          v.ptr[dpos++] = ch;
        }
      } else {
        void put (char ch) { v ~= ch; }
      }
      par.skipBlanks();
      // `null` is empty string
      if (par.curch != '"' && par.curch != '\'') {
        if (!par.isGoodIdChar(par.curch)) par.error("string expected");
        char[] ss;
        while (par.isGoodIdChar(par.curch)) {
          ss ~= par.curch;
          par.skipChar();
        }
        if (ss != "null") foreach (char ch; ss) put(ch);
      } else {
        // not a null
        assert(par.curch == '"' || par.curch == '\'');
        par.parseString!true(&put);
      }
    } else static if (is(T : V[], V)) {
      // array
      par.skipBlanks();
      if (par.curch == '{') {
        // only one element
        static if (__traits(isStaticArray, T)) {
          if (v.length == 0) par.error("array too small");
        } else {
          v.length += 1;
        }
        unserData(v[0]);
      } else if (par.curch == 'n') {
        // this should be 'null'
        par.skipChar(); if (!par.eot && par.curch != 'u') par.error("'null' expected");
        par.skipChar(); if (!par.eot && par.curch != 'l') par.error("'null' expected");
        par.skipChar(); if (!par.eot && par.curch != 'l') par.error("'null' expected");
        par.skipChar(); if (!par.eot && par.isGoodIdChar(par.curch)) par.error("'null' expected");
        static if (__traits(isStaticArray, T)) if (v.length != 0) par.error("static array too big");
      } else {
        par.expectChar('[');
        static if (__traits(isStaticArray, T)) {
          foreach (ref it; v) {
            par.skipBlanks();
            if (par.eot || par.curch == ']') break;
            unserData(it);
            skipComma();
          }
        } else {
          for (;;) {
            par.skipBlanks();
            if (par.eot || par.curch == ']') break;
            v.length += 1;
            unserData(v[$-1]);
            skipComma();
          }
        }
        par.expectChar(']');
      }
    } else static if (is(T : V[K], K, V)) {
      // associative array
      K key = void;
      V value = void;
      par.expectChar('{');
      for (;;) {
        par.skipBlanks();
        if (par.eot || par.curch == '}') break;
        unserData(key);
        par.expectChar(':');
        par.skipBlanks();
        // `null`?
        if (par.curch == 'n' && par.peek == 'u') {
          par.skipChar(); // skip 'n'
          par.skipChar(); if (!par.eot && par.curch != 'l') par.error("'null' expected");
          par.skipChar(); if (!par.eot && par.curch != 'l') par.error("'null' expected");
          par.skipChar(); if (!par.eot && par.isGoodIdChar(par.curch)) par.error("'null' expected");
          continue; // skip null value
        } else {
          unserData(value);
        }
        skipComma();
        v[key] = value;
      }
      par.expectChar('}');
    } else static if (isCharType!T) {
      import std.conv : to;
      auto id = par.expectId;
      try {
        v = id.to!uint.to!T;
      } catch (Exception e) {
        par.error("type conversion error for type '"~T.stringof~"' ("~id.idup~")");
      }
    } else static if (isSimpleType!T) {
      import std.conv : to;
      auto id = par.expectId;
      // try bool->int conversions
      static if ((is(T : ulong) || is(T : real)) && is(typeof((){v=0;})) && is(typeof((){v=1;}))) {
        // char, int, etc.
        if (id == "true") { v = 1; return; }
        if (id == "false") { v = 0; return; }
      }
      try {
        v = id.to!T;
      } catch (Exception e) {
        par.error("type conversion error for type '"~T.stringof~"' ("~id.idup~")");
      }
    } else static if (is(T == struct)) {
      // struct
      import std.traits : FieldNameTuple, getUDAs, hasUDA;

      par.skipBlanks();
      if (par.curch != '{') {
        auto nm = par.expectId!true();
        if (nm != (Unqual!T).stringof) par.error("'"~(Unqual!T).stringof~"' struct expected, but got '"~nm.idup~"'");
        par.expectChar(':');
      }
      par.expectChar('{');

      ulong[(FieldNameTuple!T.length+ulong.sizeof-1)/ulong.sizeof] fldseen = 0;

      bool tryField(uint idx, string fldname) (const(char)[] name) {
        static if (hasUDA!(__traits(getMember, T, fldname), SRZName)) {
          enum names = getUDAs!(__traits(getMember, T, fldname), SRZName);
        } else {
          alias tuple(T...) = T;
          enum names = tuple!(SRZName(fldname));
        }
        foreach (immutable xname; names) {
          if (xname.name == name) {
            if (fldseen[idx/8]&(1UL<<(idx%8))) throw new Exception(`duplicate field value for '`~fldname~`'`);
            fldseen[idx/8] |= 1UL<<(idx%8);
            unserData(__traits(getMember, v, fldname));
            return true;
          }
        }
        return false;
      }

      void tryAllFields (const(char)[] name) {
        foreach (immutable idx, string fldname; FieldNameTuple!T) {
          static if (!hasUDA!(__traits(getMember, T, fldname), SRZIgnore)) {
            if (tryField!(idx, fldname)(name)) return;
          }
        }
        static if (ignoreUnknown) {
          skipData!false();
        } else {
          throw new Exception("unknown field '"~name.idup~"'");
        }
      }

      // let's hope that fields are in order (it is nothing wrong with seeing 'em in wrong order, though)
      static if (ignoreUnknown) {
        while (par.curch != '}') {
          if (par.curch == 0) break;
          auto name = par.expectId!true();
          par.expectChar(':');
          tryAllFields(name);
          skipComma();
        }
      } else {
        foreach (immutable idx, string fldname; FieldNameTuple!T) {
          static if (!hasUDA!(__traits(getMember, T, fldname), SRZIgnore)) {
            par.skipBlanks();
            if (par.curch == '}') break;
            auto name = par.expectId!true();
            par.expectChar(':');
            if (!tryField!(idx, fldname)(name)) tryAllFields(name);
            skipComma();
          }
        }
      }

      par.expectChar('}');
    }
  }

  unserData(v);
}


// ////////////////////////////////////////////////////////////////////////// //
private static bool isValidDC (dchar c) pure nothrow @safe @nogc { pragma(inline, true); return (c < 0xD800 || (c > 0xDFFF && c <= 0x10FFFF)); } /// is given codepoint valid?

/// returns -1 on error (out of room in `s`, for example), or bytes taken
private int utf8Encode(dchar replacement='\uFFFD') (char[] s, dchar c) pure nothrow @trusted @nogc {
  static assert(isValidDC(replacement), "invalid replacement char");
  if (!isValidDC(c)) c = replacement;
  if (c <= 0x7F) {
    if (s.length < 1) return -1;
    s.ptr[0] = cast(char)c;
    return 1;
  } else {
    char[4] buf;
    ubyte len;
    if (c <= 0x7FF) {
      buf.ptr[0] = cast(char)(0xC0|(c>>6));
      buf.ptr[1] = cast(char)(0x80|(c&0x3F));
      len = 2;
    } else if (c <= 0xFFFF) {
      buf.ptr[0] = cast(char)(0xE0|(c>>12));
      buf.ptr[1] = cast(char)(0x80|((c>>6)&0x3F));
      buf.ptr[2] = cast(char)(0x80|(c&0x3F));
      len = 3;
    } else if (c <= 0x10FFFF) {
      buf.ptr[0] = cast(char)(0xF0|(c>>18));
      buf.ptr[1] = cast(char)(0x80|((c>>12)&0x3F));
      buf.ptr[2] = cast(char)(0x80|((c>>6)&0x3F));
      buf.ptr[3] = cast(char)(0x80|(c&0x3F));
      len = 4;
    } else {
      assert(0, "wtf?!");
    }
    if (s.length < len) return -1;
    s[0..len] = buf[0..len];
    return len;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
version(egserial_test) unittest {
  version(no_vfs) import std.stdio; else { import iv.vfs.io; import iv.vfs.streams; }

  version(no_vfs) static struct InRng {
    char[] src;
    @property char front () { return src[0]; }
    @property bool empty () { return (src.length == 0); }
    void popFront () { src = src[1..$]; }
  }

  char[] s2s(T) (in auto ref T v) {
    version(no_vfs) {
      char[] res;
      static struct OutRng {
        char[]* dest;
        //void put (const(char)[] ch...) { *dest ~= ch; }
        void put (char ch) { *dest ~= ch; }
      }
      auto or = OutRng(&res);
      v.txtser(or);
      return res;
    } else {
      ubyte[] res;
      auto buf = MemoryStreamRWRef(res);
      {
        auto fl = wrapStream(buf);
        v.txtser(fl);
      }
      return cast(char[])*buf.bytes;
    }
  }

  // ////////////////////////////////////////////////////////////////////////// //
  static struct AssemblyInfo {
    uint id;
    string name;
    @SRZIgnore uint ignoreme;
  }

  static struct ReplyAsmInfo {
    @SRZName("command") @SRZName("xcommand") ubyte cmd;
    @SRZName("values") AssemblyInfo[][2] list;
    uint[string] dict;
    @SRZNonDefaultOnly bool fbool;
    char[3] ext;
  }


  // ////////////////////////////////////////////////////////////////////////// //
  void test0 () {
    ReplyAsmInfo ri;
    ri.cmd = 42;
    ri.list[0] ~= AssemblyInfo(665, "limbo");
    ri.list[1] ~= AssemblyInfo(69, "pleasure");
    ri.dict["foo"] = 42;
    ri.dict["boo"] = 665;
    //ri.fbool = true;
    ri.ext = "elf";
    auto srs = s2s(ri);
    writeln(srs);
    {
      ReplyAsmInfo xf;
      version(no_vfs) {
        xf.txtunser(InRng(srs));
      } else {
        xf.txtunser(wrapMemoryRO(srs));
      }
      //assert(fl.tell == fl.size);
      assert(xf.cmd == 42);
      assert(xf.list.length == 2);
      assert(xf.list[0].length == 1);
      assert(xf.list[1].length == 1);
      assert(xf.list[0][0].id == 665);
      assert(xf.list[0][0].name == "limbo");
      assert(xf.list[1][0].id == 69);
      assert(xf.list[1][0].name == "pleasure");
      assert(xf.dict.length == 2);
      assert(xf.dict["foo"] == 42);
      assert(xf.dict["boo"] == 665);
      //assert(xf.fbool == true);
      assert(xf.fbool == false);
      assert(xf.ext == "elf");
    }
  }

  /*void main ()*/ {
    test0();
    write("string: ");
    "Alice".txtser(stdout);
    writeln;
  }

  {
    import std.utf : byChar;
    static struct Boo {
      int n = -1;
    }
    Boo boo;
    boo.txtunser("{ n:true }".byChar);
    writeln(boo.n);
  }

  /*{
    long[94] n;
    foreach (immutable idx, ref v; n) v = idx;
    n.txtser(stdout);
  }*/
}
