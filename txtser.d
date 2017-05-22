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
// very simple (de)serializer to json-like text format
module iv.txtser /*is aliced*/;
private:

import std.range : ElementEncodingType, isInputRange, isOutputRange;
import std.traits : Unqual;
import iv.alice;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public enum SRZIgnore; // ignore this field
public struct SRZName { string name; } // rename this field
public enum SRZNonDefaultOnly; // write only if it has non-default value


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
public void txtunser(bool ignoreUnknown=false, T, ST) (out T v, auto ref ST fl)
if (!is(T == class) && (isReadableStream!ST || (isInputRange!ST && is(Unqual!(ElementEncodingType!ST) == char))))
{
  import std.traits : Unqual;

  char curCh = ' ', peekCh = ' ';
  int linenum;

  void nextChar () {
    if (curCh == '\n') ++linenum;
    if (peekCh) {
      curCh = peekCh;
      static if (isReadableStream!ST) {
        if (fl.rawRead((&peekCh)[0..1]).length) {
          if (peekCh == 0) peekCh = ' ';
        } else {
          peekCh = 0;
        }
      } else {
        if (!fl.empty) {
          peekCh = fl.front;
          fl.popFront;
          if (peekCh == 0) peekCh = ' ';
        } else {
          peekCh = 0;
        }
      }
    } else {
      curCh = peekCh = 0;
    }
  }

  void skipBlanks () {
    while (curCh) {
      if ((curCh == '/' && peekCh == '/') || curCh == '#') {
        while (curCh && curCh != '\n') nextChar();
      } else if (curCh == '/' && peekCh == '*') {
        nextChar();
        nextChar();
        while (curCh) {
          if (curCh == '*' && peekCh == '/') {
            nextChar();
            nextChar();
            break;
          }
        }
      } else if (curCh == '/' && peekCh == '+') {
        nextChar();
        nextChar();
        int level = 1;
        while (curCh) {
          if (curCh == '+' && peekCh == '/') {
            nextChar();
            nextChar();
            if (--level == 0) break;
          } else if (curCh == '/' && peekCh == '+') {
            nextChar();
            nextChar();
            ++level;
          }
        }
      } else if (curCh > ' ') {
        break;
      } else {
        nextChar();
      }
    }
  }

  void error (string msg) { import std.conv : to; throw new Exception(msg~" around line "~linenum.to!string); }

  void expectChar (char ch) {
    skipBlanks();
    if (curCh != ch) error("'"~ch~"' expected");
    nextChar();
  }

  void skipComma () {
    skipBlanks();
    if (curCh == ',') nextChar();
  }

  static bool isGoodIdChar (char ch) pure nothrow @safe @nogc {
    return
      (ch >= '0' && ch <= '9') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_' || ch == '-' || ch == '+' || ch == '.';
  }

  static int digitInBase (char ch, int base=10) pure nothrow @trusted @nogc {
    pragma(inline, true);
    return
      base >= 1 && ch >= '0' && ch < '0'+base ? ch-'0' :
      base > 10 && ch >= 'A' && ch < 'A'+base-10 ? ch-'A'+10 :
      base > 10 && ch >= 'a' && ch < 'a'+base-10 ? ch-'a'+10 :
      -1;
  }

  // buffer for identifier reading
  char[64] buf = 0;
  int bpos = 0;

  const(char)[] expectId(bool allowquoted=false) () {
    bpos = 0;
    skipBlanks();
    static if (allowquoted) {
      if (curCh == '"') {
        nextChar();
        while (curCh != '"') {
          if (curCh == '\\') error("simple string expected");
          if (bpos >= buf.length) error("identifier or number too long");
          buf[bpos++] = curCh;
          nextChar();
        }
        if (curCh != '"') error("simple string expected");
        nextChar();
        return buf[0..bpos];
      }
    }
    if (!isGoodIdChar(curCh)) error("identifier or number expected");
    while (isGoodIdChar(curCh)) {
      if (bpos >= buf.length) error("identifier or number too long");
      buf[bpos++] = curCh;
      nextChar();
    }
    return buf[0..bpos];
  }

  static if (ignoreUnknown) void skipData(bool fieldname) () {
    skipBlanks();
    // string?
    if (curCh == '"' || curCh == '\'') {
      char eq = curCh;
      nextChar();
      while (curCh != eq) {
        char ch = curCh;
        if (ch == 0) error("unterminated string");
        nextChar();
        if (ch == '\\') nextChar();
      }
      expectChar(eq);
      return;
    }
    static if (!fieldname) {
      // array?
      if (curCh == '[') {
        nextChar();
        for (;;) {
          skipBlanks();
          if (curCh == 0) error("unterminated array");
          if (curCh == ']') break;
          skipData!false();
          skipComma();
        }
        expectChar(']');
        return;
      }
      // dictionary?
      if (curCh == '{') {
        nextChar();
        for (;;) {
          skipBlanks();
          if (curCh == 0) error("unterminated array");
          if (curCh == '}') break;
          skipData!true(); // field name
          skipBlanks();
          expectChar(':');
          skipData!false();
          skipComma();
        }
        expectChar('}');
        return;
      }
    }
    // identifier
    if (!isGoodIdChar(curCh)) error("invalid identifier");
    while (isGoodIdChar(curCh)) nextChar();
  }

  void unserData(T) (out T v) {
    static if (is(T : const(char)[])) {
      // quoted string
      static if (__traits(isStaticArray, T)) {
        usize dpos = 0;
        void put (const(char)[] s...) {
          if (s.length) {
            if (v.length-dpos < s.length) error("value too long");
            v[dpos..dpos+s.length] = s[];
            dpos += s.length;
          }
        }
      } else {
        void put (const(char)[] s...) { if (s.length) v ~= s; }
      }
      skipBlanks();
      // `null` is empty string
      if (curCh != '"' && curCh != '\'') {
        if (!isGoodIdChar(curCh)) error("string expected");
        char[] ss;
        while (isGoodIdChar(curCh)) {
          ss ~= curCh;
          nextChar();
        }
        if (ss != "null") foreach (char ch; ss) put(ch);
      } else {
        // not a null
        assert(curCh == '"' || curCh == '\'');
        char eq = curCh;
        nextChar();
        while (curCh != eq) {
          if (curCh == 0) error("unterminated string");
          if (curCh == '\\') {
            nextChar();
            switch (curCh) {
              case '0': // oops, octal
                uint ucc = 0;
                foreach (immutable _; 0..4) {
                  int dig = digitInBase(curCh, 10);
                  if (dig < 0) break;
                  if (dig > 7) error("invalid octal escape");
                  ucc = ucc*8+dig;
                  nextChar();
                }
                if (ucc > 255) error("invalid octal escape");
                put(cast(char)ucc);
                break;
              case '1': .. case '9': // decimal
                uint ucc = 0;
                foreach (immutable _; 0..3) {
                  int dig = digitInBase(curCh, 10);
                  if (dig < 0) break;
                  ucc = ucc*10+dig;
                  nextChar();
                }
                if (ucc > 255) error("invalid decimal escape");
                put(cast(char)ucc);
                break;
              case 'e': put('\x1b'); nextChar(); break;
              case 'r': put('\r'); nextChar(); break;
              case 'n': put('\n'); nextChar(); break;
              case 't': put('\t'); nextChar(); break;
              case '"': case '\\': case '\'': put(curCh); nextChar(); break;
              case 'x':
              case 'X':
                if (digitInBase(peekCh, 16) < 0) error("invalid hex escape");
                nextChar(); // skip 'x'
                if (digitInBase(curCh, 16) < 0 || digitInBase(peekCh, 16) < 0) error("invalid hex escape");
                put(cast(char)(digitInBase(curCh, 16)*16+digitInBase(peekCh, 16)));
                nextChar();
                nextChar();
                break;
              case 'u':
              case 'U':
                if (digitInBase(peekCh, 16) < 0) error("invalid unicode escape");
                uint ucc = 0;
                nextChar(); // skip 'u'
                foreach (immutable _; 0..4) {
                  if (digitInBase(curCh, 16) < 0) break;
                  ucc = ucc*16+digitInBase(curCh, 16);
                  nextChar();
                }
                {
                  char[4] buf = 0;
                  auto len = utf8Encode(buf[], cast(dchar)ucc);
                  assert(len != 0);
                  if (len < 0) error("invalid utf-8 escape");
                  //{ import core.stdc.stdio; printf("ucc=%u 0x%04X; len=%d; [0]=%u; [1]=%u; [2]=%u; [3]=%u\n", ucc, ucc, len, cast(uint)buf[0], cast(uint)buf[1], cast(uint)buf[2], cast(uint)buf[3]); assert(0); }
                  put(buf[0..len]);
                }
                break;
              default: error("invalid escape");
            }
          } else {
            put(curCh);
            nextChar();
          }
        }
        expectChar(eq);
      }
    } else static if (is(T : V[], V)) {
      // array
      skipBlanks();
      if (curCh == '{') {
        // only one element
        static if (__traits(isStaticArray, T)) {
          if (v.length == 0) error("array too small");
        } else {
          v.length += 1;
        }
        unserData(v[0]);
      } else if (curCh == 'n') {
        // this should be 'null'
        nextChar(); if (curCh != 'u') error("'null' expected");
        nextChar(); if (curCh != 'l') error("'null' expected");
        nextChar(); if (curCh != 'l') error("'null' expected");
        nextChar(); if (isGoodIdChar(curCh)) error("'null' expected");
        static if (__traits(isStaticArray, T)) if (v.length != 0) error("static array too big");
      } else {
        expectChar('[');
        static if (__traits(isStaticArray, T)) {
          foreach (ref it; v) {
            skipBlanks();
            if (curCh == ']') break;
            unserData(it);
            skipComma();
          }
        } else {
          for (;;) {
            skipBlanks();
            if (curCh == ']') break;
            v.length += 1;
            unserData(v[$-1]);
            skipComma();
          }
        }
        expectChar(']');
      }
    } else static if (is(T : V[K], K, V)) {
      // associative array
      K key = void;
      V value = void;
      expectChar('{');
      for (;;) {
        skipBlanks();
        if (curCh == '}') break;
        unserData(key);
        expectChar(':');
        skipBlanks();
        // `null`?
        if (curCh == 'n' && peekCh == 'u') {
          auto id = expectId;
          if (id != "null") error("`null` expected");
          continue; // skip null key
        } else {
          unserData(value);
        }
        skipComma();
        v[key] = value;
      }
      expectChar('}');
    } else static if (isCharType!T) {
      import std.conv : to;
      auto id = expectId;
      try {
        v = id.to!uint.to!T;
      } catch (Exception e) {
        error("type conversion error for type '"~T.stringof~"' ("~id.idup~")");
      }
    } else static if (isSimpleType!T) {
      import std.conv : to;
      auto id = expectId;
      // try bool->int conversions
      static if ((is(T : ulong) || is(T : real)) && is(typeof((){v=0;}))  && is(typeof((){v=1;}))) {
        // char, int, etc.
        if (id == "true") { v = 1; return; }
        if (id == "false") { v = 0; return; }
      }
      try {
        v = id.to!T;
      } catch (Exception e) {
        error("type conversion error for type '"~T.stringof~"' ("~id.idup~")");
      }
    } else static if (is(T == struct)) {
      // struct
      import std.traits : FieldNameTuple, getUDAs, hasUDA;

      skipBlanks();
      if (curCh != '{') {
        auto nm = expectId!true();
        if (nm != (Unqual!T).stringof) error("'"~(Unqual!T).stringof~"' struct expected, but got '"~nm.idup~"'");
        expectChar(':');
      }
      expectChar('{');

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
        while (curCh != '}') {
          if (curCh == 0) break;
          auto name = expectId!true();
          expectChar(':');
          tryAllFields(name);
          skipComma();
        }
      } else {
        foreach (immutable idx, string fldname; FieldNameTuple!T) {
          static if (!hasUDA!(__traits(getMember, T, fldname), SRZIgnore)) {
            skipBlanks();
            if (curCh == '}') break;
            auto name = expectId!true();
            expectChar(':');
            if (!tryField!(idx, fldname)(name)) tryAllFields(name);
            skipComma();
          }
        }
      }

      expectChar('}');
    }
  }

  // load first chars
  nextChar();
  nextChar();
  linenum = 1;

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
