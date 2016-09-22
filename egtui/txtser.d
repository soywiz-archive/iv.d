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
// very simple serializer to json-like text format
module iv.egtui.txtser;
private:

import iv.vfs.io;


// ////////////////////////////////////////////////////////////////////////// //
public enum SRZIgnore; // ignore this field
public struct SRZName { string name; } // rename this field
public enum SRZNonDefaultOnly; // write only if it has non-default value


// ////////////////////////////////////////////////////////////////////////// //
template isSimpleType(T) {
  private import std.traits : Unqual;
  private alias UT = Unqual!T;
  enum isSimpleType = __traits(isIntegral, UT) || __traits(isFloating, UT) || is(UT == bool);
}


// ////////////////////////////////////////////////////////////////////////// //
public void txtser(T, ST) (auto ref ST fl, in auto ref T v, int indent=0) if (!is(T == class) && isWriteableStream!ST) {
  enum Indent = 2;

  void quote (const(char)[] s) {
    static immutable string hexd = "0123456789abcdef";
    fl.write('"');
    bool goodString = true;
    foreach (char ch; s) if (ch < ' ' || ch == 127 || ch == '"' || ch == '\\') { goodString = false; break; }
    if (goodString) {
      // easy deal
      fl.write(s);
    } else {
      // hard time
      //FIXME: make it faster
      foreach (char ch; s) {
        if (ch < ' ' || ch == 127 || ch == '"' || ch == '\\') {
          switch (ch) {
            case '\x1b': fl.write(`\e`); break;
            case '\r': fl.write(`\r`); break;
            case '\n': fl.write(`\n`); break;
            case '\t': fl.write(`\t`); break;
            case '"': case '\\': fl.write(`\`, ch); break;
            default:
              fl.write(`\x`);
              fl.write(hexd[(ch>>4)&0x0f]);
              fl.write(hexd[ch&0x0f]);
              break;
          }
        } else {
          fl.write(ch);
        }
      }
    }
    fl.write('"');
  }

  void newline () {
    fl.writeln;
    foreach (immutable _; 0..indent) fl.write(' ');
  }

  void serData(T) (in ref T v) {
    alias UT = arrayElementType!T;
    static if (is(T : const(char)[])) {
      // string
      quote(v);
    } else static if (is(T : V[], V)) {
      // array
      void writeMArray(AT) (AT arr) {
        fl.write("[ // ", arr.length);
        indent += Indent;
        foreach (const ref it; arr) {
          newline();
          serData(it);
          fl.write(",");
        }
        indent -= Indent;
        newline;
        fl.write("]");
      }
      writeMArray(v);
    } else static if (is(T : V[K], K, V)) {
      // associative array
      fl.write("{ // ", v.length);
      indent += Indent;
      foreach (const kv; v.byKeyValue) {
        newline;
        serData(kv.key);
        fl.write(": ");
        serData(kv.value);
        fl.write(",");
      }
      indent -= Indent;
      newline;
      fl.write("}");
    } else static if (isSimpleType!UT) {
      // simple type
      fl.write(v);
    } else static if (is(UT == struct)) {
      // struct
      import std.traits : FieldNameTuple, getUDAs, hasUDA;
      fl.write(UT.stringof, ": {");
      indent += Indent;
      foreach (string fldname; FieldNameTuple!UT) {
        static if (!hasUDA!(__traits(getMember, UT, fldname), SRZIgnore)) {
          enum names = getUDAs!(__traits(getMember, UT, fldname), SRZName);
          static if (names.length) enum xname = names[0].name; else enum xname = fldname;
          static assert(xname.length <= 255, "struct '"~UT.stringof~"': field name too long: "~xname);
          static if (hasUDA!(__traits(getMember, UT, fldname), SRZNonDefaultOnly)) {
            if (__traits(getMember, v, fldname) == __traits(getMember, v, fldname).init) continue;
          }
          newline;
          fl.write(xname, ": ");
          serData(__traits(getMember, v, fldname));
          fl.write(",");
        }
      }
      indent -= Indent;
      newline;
      fl.write("}");
    } else {
      static assert(0, "can't serialize type '"~T.stringof~"'");
    }
  }

  serData(v);
}


// ////////////////////////////////////////////////////////////////////////// //
public void txtunser(T, ST) (auto ref ST fl, out T v) if (!is(T == class) && isReadableStream!ST) {
  import std.traits : Unqual;

  char curCh = ' ', peekCh = ' ';
  int linenum;

  void nextChar () {
    if (curCh == '\n') ++linenum;
    if (peekCh) {
      curCh = peekCh;
      if (fl.rawRead((&peekCh)[0..1]).length) {
        if (peekCh == 0) peekCh = ' ';
      } else {
        peekCh = 0;
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

  const(char)[] expectId () {
    bpos = 0;
    skipBlanks();
    if (!isGoodIdChar(curCh)) error("identifier or number expected");
    while (isGoodIdChar(curCh)) {
      if (bpos >= buf.length) error("identifier or number too long");
      buf[bpos++] = curCh;
      nextChar();
    }
    return buf[0..bpos];
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
        void put (const(char)[] s...) {
          if (s.length) v ~= s;
        }
      }
      skipBlanks();
      if (curCh != '"') error("string expected");
      nextChar();
      while (curCh != '"') {
        if (curCh < ' ') error("invalid string");
        if (curCh == '"') break;
        if (curCh == '\\') {
          nextChar();
          switch (curCh) {
            case 'e': put('\x1b'); nextChar(); break;
            case 'r': put('\r'); nextChar(); break;
            case 'n': put('\n'); nextChar(); break;
            case 't': put('\t'); nextChar(); break;
            case '"': case '\\': put(curCh); nextChar(); break;
            case 'x':
              nextChar();
              if (digitInBase(curCh, 16) < 0 || digitInBase(peekCh, 16) < 0) error("invalid hex escape");
              put(cast(char)(digitInBase(curCh, 16)*16+digitInBase(peekCh, 16)));
              nextChar();
              nextChar();
              break;
            default: error("invalid escape");
          }
        } else {
          put(curCh);
          nextChar();
        }
      }
      expectChar('"');
    } else static if (is(T : V[], V)) {
      // array
      void readMArray(AT) (out AT arr) {
        expectChar('[');
        static if (__traits(isStaticArray, AT)) {
          //arr[] = arr[0].init; // clear it
          foreach (ref it; arr) {
            skipBlanks();
            if (curCh == ']') break;
            unserData(it);
            skipComma();
          }
        } else {
          for (;;) {
            skipBlanks();
            if (curCh == ']') break;
            arr.length += 1;
            //readMArray(arr[$-1]);
            unserData(arr[$-1]);
            skipComma();
          }
        }
        expectChar(']');
      }
      readMArray(v);
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
        unserData(value);
        skipComma();
        v[key] = value;
      }
      expectChar('}');
    } else static if (isSimpleType!T) {
      // simple type
      import std.conv : to;
      auto id = expectId;
      try {
        v = id.to!T;
      } catch (Exception e) {
        error("type conversion error for type '"~T.stringof~"' ("~id.idup~")");
      }
    } else static if (is(T == struct)) {
      // struct
      import std.traits : FieldNameTuple, getUDAs, hasUDA;

      {
        auto nm = expectId();
        if (nm != (Unqual!T).stringof) error("'"~(Unqual!T).stringof~"' struct expected, but got '"~nm.idup~"'");
      }
      expectChar(':');
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
        throw new Exception("unknown field '"~name.idup~"'");
      }

      // let's hope that fields are in order (it is nothing wrong with seeing 'em in wrong order, though)
      foreach (immutable idx, string fldname; FieldNameTuple!T) {
        static if (!hasUDA!(__traits(getMember, T, fldname), SRZIgnore)) {
          skipBlanks();
          if (curCh == '}') break;
          auto name = expectId();
          expectChar(':');
          if (!tryField!(idx, fldname)(name)) tryAllFields(name);
          skipComma();
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


// ////////////////////////////////////////////////////////////////////////// //
version(egserial_test) unittest {
  import iv.vfs;

  import iv.vfs.streams;

  char[] s2s(T) (in auto ref T v) {
    ubyte[] res;
    auto buf = MemoryStreamRWRef(res);
    {
      auto fl = wrapStream(buf);
      fl.txtser(v);
    }
    return cast(char[])*buf.bytes;
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
    ri.list[0] ~= AssemblyInfo(666, "hell");
    ri.list[1] ~= AssemblyInfo(69, "fuck");
    ri.dict["foo"] = 42;
    ri.dict["boo"] = 666;
    //ri.fbool = true;
    ri.ext = "elf";
    auto srs = s2s(ri);
    writeln(srs);
    {
      ReplyAsmInfo xf;
      wrapMemoryRO(srs).txtunser(xf);
      //assert(fl.tell == fl.size);
      assert(xf.cmd == 42);
      assert(xf.list.length == 2);
      assert(xf.list[0].length == 1);
      assert(xf.list[1].length == 1);
      assert(xf.list[0][0].id == 666);
      assert(xf.list[0][0].name == "hell");
      assert(xf.list[1][0].id == 69);
      assert(xf.list[1][0].name == "fuck");
      assert(xf.dict.length == 2);
      assert(xf.dict["foo"] == 42);
      assert(xf.dict["boo"] == 666);
      //assert(xf.fbool == true);
      assert(xf.fbool == false);
      assert(xf.ext == "elf");
    }
  }

  /*void main ()*/ {
    test0();
    write("string: ");
    stdout.txtser("Alice");
    writeln;
  }
}