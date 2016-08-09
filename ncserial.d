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
// very simple serializer
// WARNING! do not use for disk and other sensitive serialization,
//          as format may change without notice! at least version it!
module iv.ncserial;
private:

import iv.vfs : usize;
import iv.vfs.augs;


// ////////////////////////////////////////////////////////////////////////// //
public enum NCIgnore; // ignore this field
public struct NCName { string name; } // rename this field


enum NCEntryType : ubyte {
  End    = 0x00, // WARNING! SHOULD BE ZERO!
  Bool   = 0x10,
  Char   = 0x20,
  Int    = 0x30,
  Uint   = 0x40,
  Float  = 0x50,
  Struct = 0x60,
  Array  = 0x70,
  Dict   = 0x80,
}


// ////////////////////////////////////////////////////////////////////////// //
public void ncser(T, ST) (auto ref ST fl, in ref T v) if (!is(T == class) && isWriteableStream!ST) {
  import std.traits : Unqual;

  void writeTypeHeader(T) () {
    alias UT = Unqual!T;
    static if (is(UT : V[], V)) {
      enum dc = dimensionCount!UT;
      static assert(dc <= 255, "too many array dimenstions");
      fl.writeNum!ubyte(NCEntryType.Array);
      fl.writeNum!ubyte(cast(ubyte)dc);
      writeTypeHeader!(arrayElementType!UT);
    } else static if (is(UT : K[V], K, V)) {
      fl.writeNum!ubyte(NCEntryType.Dict);
      writeTypeHeader!(Unqual!K);
      writeTypeHeader!(Unqual!V);
    } else static if (is(UT == bool)) {
      fl.writeNum!ubyte(NCEntryType.Bool);
    } else static if (is(UT == char) || is(UT == wchar) || is(UT == dchar)) {
      fl.writeNum!ubyte(cast(ubyte)(NCEntryType.Char|UT.sizeof));
    } else static if (__traits(isIntegral, UT)) {
      static if (__traits(isUnsigned, UT)) {
        fl.writeNum!ubyte(cast(ubyte)(NCEntryType.Uint|UT.sizeof));
      } else {
        fl.writeNum!ubyte(cast(ubyte)(NCEntryType.Int|UT.sizeof));
      }
    } else static if (__traits(isFloating, UT)) {
      fl.writeNum!ubyte(cast(ubyte)(NCEntryType.Float|UT.sizeof));
    } else static if (is(UT == struct)) {
      static assert(UT.stringof.length <= 255, "struct name too long: "~UT.stringof);
      fl.writeNum!ubyte(NCEntryType.Struct);
      fl.writeNum!ubyte(cast(ubyte)UT.stringof.length);
      fl.rawWriteExact(UT.stringof[]);
    } else {
      static assert(0, "can't serialize type '"~T.stringof~"'");
    }
  }

  void serData(T) (in ref T v) {
    alias UT = arrayElementType!T;
    static if (is(T : V[], V)) {
      // array
      void writeMArray(AT) (AT arr) {
        fl.writeXInt(arr.length);
        static if (isMultiDimArray!AT) {
          foreach (const a2; arr) writeMArray(a2);
        } else {
          foreach (const ref it; arr) serData(it);
        }
      }
      writeMArray(v);
    } else static if (is(T : V[K], K, V)) {
      // associative array
      fl.writeXInt(v.length);
      foreach (const kv; v.byKeyValue) {
        serData(kv.key);
        serData(kv.value);
      }
    } else static if (is(UT == bool)) {
      fl.writeNum!ubyte(cast(ubyte)v);
    } else static if (__traits(isIntegral, UT) || __traits(isFloating, UT)) {
      fl.writeNum!UT(v);
    } else static if (is(UT == struct)) {
      import std.traits : FieldNameTuple, getUDAs, hasUDA;
      foreach (string fldname; FieldNameTuple!UT) {
        static if (!hasUDA!(__traits(getMember, UT, fldname), NCIgnore)) {
          enum names = getUDAs!(__traits(getMember, UT, fldname), NCName);
          static if (names.length) enum xname = names[0].name; else enum xname = fldname;
          static assert(xname.length <= 255, "struct '"~UT.stringof~"': field name too long: "~xname);
          fl.writeNum!ubyte(cast(ubyte)xname.length);
          fl.rawWriteExact(xname[]);
          fl.ncser(__traits(getMember, v, fldname));
        }
      }
      fl.writeNum!ubyte(NCEntryType.End);
    } else {
      static assert(0, "can't serialize type '"~T.stringof~"'");
    }
  }

  writeTypeHeader!T;
  serData(v);
}


// ////////////////////////////////////////////////////////////////////////// //
public void ncunser(T, ST) (auto ref ST fl, out T v) if (!is(T == class) && isReadableStream!ST) {
  import std.traits : Unqual;

  void checkTypeId(T) () {
    static if (is(T : V[], V)) {
      if (fl.readNum!ubyte != NCEntryType.Array) throw new Exception(`invalid stream (array expected)`);
      if (fl.readNum!ubyte != dimensionCount!T) throw new Exception(`invalid stream (dimension count)`);
      checkTypeId!(arrayElementType!T);
    } else static if (is(T : K[V], K, V)) {
      if (fl.readNum!ubyte != NCEntryType.Dict) throw new Exception(`invalid stream (dict expected)`);
      checkTypeId!(Unqual!K);
      checkTypeId!(Unqual!V);
    } else static if (is(T == bool)) {
      if (fl.readNum!ubyte != NCEntryType.Bool) throw new Exception(`invalid stream (bool expected)`);
    } else static if (is(T == char) || is(T == wchar) || is(T == dchar)) {
      if (fl.readNum!ubyte != (NCEntryType.Char|T.sizeof)) throw new Exception(`invalid stream (char expected)`);
    } else static if (__traits(isIntegral, T)) {
      static if (__traits(isUnsigned, T)) {
        if (fl.readNum!ubyte != (NCEntryType.Uint|T.sizeof)) throw new Exception(`invalid stream (int expected)`);
      } else {
        if (fl.readNum!ubyte != (NCEntryType.Int|T.sizeof)) throw new Exception(`invalid stream (int expected)`);
      }
    } else static if (__traits(isFloating, T)) {
      if (fl.readNum!ubyte != (NCEntryType.Float|T.sizeof)) throw new Exception(`invalid stream (float expected)`);
    } else static if (is(T == struct)) {
      char[255] cbuf = void;
      static assert(T.stringof.length <= 255, "struct name too long: "~T.stringof);
      if (fl.readNum!ubyte != NCEntryType.Struct) throw new Exception(`invalid stream (struct expected)`);
      if (fl.readNum!ubyte != T.stringof.length) throw new Exception(`invalid stream (struct name length)`);
      fl.rawReadExact(cbuf[0..T.stringof.length]);
      if (cbuf[0..T.stringof.length] != T.stringof) throw new Exception(`invalid stream (struct name)`);
    } else {
      static assert(0, "can't unserialize type '"~T.stringof~"'");
    }
  }

  void unserData(T) (out T v) {
    static if (is(T : V[], V)) {
      void readMArray(AT) (out AT arr) {
        auto llen = fl.readXInt!usize;
        if (llen == 0) return;
        static if (__traits(isStaticArray, AT)) {
          if (arr.length != llen) throw new Exception(`invalid stream (array size)`);
          static if (isMultiDimArray!AT) {
            foreach (ref a2; arr) readMArray(a2);
          } else {
            foreach (ref it; arr) unserData(it);
          }
        } else {
          static if (isMultiDimArray!AT) {
            foreach (ref a2; arr) readMArray(a2);
          } else {
            auto narr = new arrayElementType!AT[](llen);
            foreach (ref it; narr) unserData(it);
            arr = cast(AT)narr;
          }
        }
      }
      readMArray(v);
    } else static if (is(T : V[K], K, V)) {
      K key = void;
      V value = void;
      foreach (immutable _; 0..fl.readXInt!usize) {
        unserData(key);
        unserData(value);
        v[key] = value;
      }
    } else static if (is(T == bool)) {
      v = fl.readNum!ubyte != 0;
    } else static if (__traits(isIntegral, T) || __traits(isFloating, T)) {
      v = fl.readNum!T;
    } else static if (is(T == struct)) {
      import std.traits : FieldNameTuple, getUDAs, hasUDA;

      ulong[(FieldNameTuple!T.length+ulong.sizeof-1)/ulong.sizeof] fldseen = 0;

      void tryField (const(char)[] name) {
        alias tuple(T...) = T;
        bool found = false;
        foreach (immutable idx, string fldname; FieldNameTuple!T) {
          static if (!hasUDA!(__traits(getMember, T, fldname), NCIgnore)) {
            static if (hasUDA!(__traits(getMember, T, fldname), NCName)) {
              enum names = getUDAs!(__traits(getMember, T, fldname), NCName);
            } else {
              enum names = tuple!(NCName(fldname));
            }
            foreach (immutable xname; names) {
              if (xname.name == name) {
                if (fldseen[idx/8]&(1UL<<(idx%8))) throw new Exception(`duplicate field value for '`~xname.name~`'`);
                fldseen[idx/8] |= 1UL<<(idx%8);
                fl.ncunser(__traits(getMember, v, fldname));
                found = true;
                break;
              }
            }
            if (found) break;
          }
        }
        if (!found) throw new Exception("unknown field '"~name.idup~"'");
      }

      for (;;) {
        char[255] cbuf = void;
        auto nlen = fl.readNum!ubyte;
        if (nlen == NCEntryType.End) break;
        fl.rawReadExact(cbuf[0..nlen]);
        tryField(cbuf[0..nlen]);
      }

      foreach (immutable idx, string fldname; FieldNameTuple!T) {
        static if (!hasUDA!(__traits(getMember, T, fldname), NCIgnore)) {
          if ((fldseen[idx/8]&(1UL<<(idx&0x07))) == 0) throw new Exception(`value for field '`~fldname~`' not found`);
        }
      }
    }
  }

  checkTypeId!T;
  unserData(v);
}


// ////////////////////////////////////////////////////////////////////////// //
template isMultiDimArray(T) {
  private import std.range.primitives : hasLength;
  private import std.traits : isArray, isNarrowString;
  static if (isArray!T) {
    alias DT = typeof(T.init[0]);
    static if (hasLength!DT || isNarrowString!DT) {
      enum isMultiDimArray = true;
    } else {
      enum isMultiDimArray = false;
    }
  } else {
    enum isMultiDimArray = false;
  }
}
static assert(isMultiDimArray!(string[]) == true);
static assert(isMultiDimArray!string == false);
static assert(isMultiDimArray!(int[int]) == false);


template dimensionCount(T) {
  private import std.range.primitives : hasLength;
  private import std.traits : isArray, isNarrowString;
  static if (isArray!T) {
    alias DT = typeof(T.init[0]);
    static if (hasLength!DT || isNarrowString!DT) {
      enum dimensionCount = 1+dimensionCount!DT;
    } else {
      enum dimensionCount = 1;
    }
  } else {
    enum dimensionCount = 0;
  }
}
static assert(dimensionCount!string == 1);
static assert(dimensionCount!(int[int]) == 0);


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
version(ncserial_test) unittest {
  import iv.vfs;

  // ////////////////////////////////////////////////////////////////////////// //
  static struct AssemblyInfo {
    uint id;
    string name;
    @NCIgnore uint ignoreme;
  }

  static struct ReplyAsmInfo {
    @NCName("command") @NCName("xcommand") ubyte cmd;
    @NCName("values") AssemblyInfo[][2] list;
    uint[string] dict;
  }


  // ////////////////////////////////////////////////////////////////////////// //
  {
    ReplyAsmInfo ri;
    ri.cmd = 42;
    ri.list[0] ~= AssemblyInfo(666, "hell");
    ri.list[1] ~= AssemblyInfo(69, "fuck");
    ri.dict["foo"] = 42;
    ri.dict["boo"] = 666;
    {
      auto fl = VFile("z00.bin", "w");
      fl.ncser(ri);
    }
    {
      ReplyAsmInfo xf;
      auto fl = VFile("z00.bin");
      fl.ncunser(xf);
      assert(fl.tell == fl.size);
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
    }
  }
}
