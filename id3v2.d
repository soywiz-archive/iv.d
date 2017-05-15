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
module iv.id3v2 is aliced;

// ////////////////////////////////////////////////////////////////////////// //
//version = id3v2_debug;

import iv.utfutil;
import iv.vfs;
version(id3v2_debug) import iv.vfs.io;


// ////////////////////////////////////////////////////////////////////////// //
struct ID3v2 {
  string artist;
  string album;
  string title;
  string contentTitle;
  string subTitle;
  string year;

  // scan file for ID3v2 tags and parse 'em
  // returns `false` if no tag found
  // throws if tag is invalid (i.e. found, but inparseable)
  // fl position is undefined after return/throw
  // if `doscan` is `false`, assume that fl position is at the tag
  bool scanParse(bool doscan=true) (VFile fl) {
    ubyte[] rdbuf;
    int rbpos, rbused;
    bool rbeof;
    rdbuf.length = 8192;
    scope(exit) delete rdbuf;

    uint availData () nothrow @trusted @nogc { return rbused-rbpos; }

    // returns 'false' if there is no more data at all (i.e. eof)
    bool fillBuffer () {
      if (rbeof) return false;
      if (rbpos >= rbused) rbpos = rbused = 0;
      while (rbused < rdbuf.length) {
        auto rd = fl.rawRead(rdbuf[rbused..$]);
        if (rd.length == 0) break; // no more data
        rbused += cast(uint)rd.length;
      }
      if (rbpos >= rbused) { rbeof = true; return false; }
      assert(rbpos < rbused);
      return true;
    }

    bool shiftFillBuffer (uint bytesToLeft) {
      if (bytesToLeft > rbused-rbpos) assert(0, "ID3v2 scanner internal error");
      if (rbeof) return false;
      if (bytesToLeft > 0) {
        uint xmpos = rbused-bytesToLeft;
        assert(xmpos < rbused);
        if (xmpos > 0) {
          // shift bytes we want to keep
          import core.stdc.string : memmove;
          memmove(rdbuf.ptr, rdbuf.ptr+xmpos, bytesToLeft);
        }
      }
      rbpos = 0;
      rbused = bytesToLeft;
      return fillBuffer();
    }

    ubyte getByte () {
      if (!fillBuffer()) throw new Exception("out of ID3v2 data");
      return rdbuf.ptr[rbpos++];
    }

    ubyte flags;
    uint wholesize;
    ubyte verhi, verlo;
    // scan
    fillBuffer(); // initial fill
    scanloop: for (;;) {
      import core.stdc.string : memchr;
      if (rbeof || availData < 10) return false; // alas
      if (rdbuf.ptr[0] == 'I' && rdbuf.ptr[1] == 'D' && rdbuf.ptr[2] == '3' && rdbuf.ptr[3] <= 3 && rdbuf.ptr[4] != 0xff) {
        // check flags
        do {
          flags = rdbuf.ptr[5];
          if (flags&0b11111) break;
          wholesize = 0;
          foreach (immutable bpos; 6..10) {
            ubyte b = rdbuf.ptr[bpos];
            if (b&0x80) break; // oops
            wholesize = (wholesize<<7)|b;
          }
          verhi = rdbuf.ptr[3];
          verlo = rdbuf.ptr[4];
          rbpos = 10;
          break scanloop;
        } while (0);
      }
      static if (!doscan) {
        return false;
      } else {
        auto fptr = memchr(rdbuf.ptr+1, 'I', availData-1);
        uint pos = (fptr !is null ? cast(uint)(fptr-rdbuf.ptr) : availData);
        shiftFillBuffer(availData-pos);
      }
    }

    bool flagUnsync = ((flags*0x80) != 0);
    bool flagExtHeader = ((flags*0x40) != 0);
    //bool flagExperimental = ((flags*0x20) != 0);

    version(id3v2_debug) writeln("ID3v2 found! version is 2.", verhi, ".", verlo, "; size: ", wholesize, "; flags (shifted): ", flags>>5);

    bool lastByteWasFF = false; // used for unsync

    T getUInt(T) () if (is(T == ubyte) || is(T == ushort) || is(T == uint)) {
      if (wholesize < T.sizeof) throw new Exception("out of ID3v2 data");
      uint res;
      foreach (immutable n; 0..T.sizeof) {
        ubyte b = getByte;
        if (flagUnsync) {
          if (lastByteWasFF && b == 0) {
            if (wholesize < 1) throw new Exception("out of ID3v2 data");
            b = getByte;
            --wholesize;
          }
          lastByteWasFF = (b == 0xff);
        }
        res = (res<<8)|b;
        --wholesize;
      }
      return cast(T)res;
    }

    // skip extended header
    if (flagExtHeader) {
      uint ehsize = getUInt!uint;
      while (ehsize-- > 0) getUInt!ubyte;
    }

    // read frames
    readloop: while (wholesize >= 8) {
      char[4] tag = void;
      foreach (ref char ch; tag[]) {
        ch = cast(char)getByte;
        --wholesize;
        if (!((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z'))) break readloop; // oops
      }
      lastByteWasFF = false;
      uint tagsize = getUInt!uint;
      if (tagsize >= wholesize) break; // ooops
      if (wholesize-tagsize < 2) break; // ooops
      ushort tagflags = getUInt!ushort;
      version(id3v2_debug) writeln("TAG: ", tag[]);
      if ((tagflags&0b000_11111_000_11111) != 0) goto skiptag;
      if (tagflags&0x80) goto skiptag; // compressed
      if (tagflags&0x40) goto skiptag; // encrypted
      if (tag.ptr[0] == 'T') {
        // text tag
        if (tagsize < 1) goto skiptag;
        string* deststr = null;
             if (tag == "TALB") deststr = &album;
        else if (tag == "TIT1") deststr = &contentTitle;
        else if (tag == "TIT2") deststr = &title;
        else if (tag == "TIT3") deststr = &subTitle;
        else if (tag == "TPE1") deststr = &artist;
        else if (tag == "TYER") deststr = &year;
        if (deststr is null) goto skiptag; // not interesting
        --tagsize;
        ubyte encoding = getUInt!ubyte; // 0: iso-8859-1; 1: unicode
        if (encoding > 1) throw new Exception("invalid ID3v2 text encoding");
        if (encoding == 0) {
          // iso-8859-1
          char[] str;
          str.reserve(tagsize);
          auto osize = wholesize;
          while (osize-wholesize < tagsize) str ~= cast(char)getUInt!ubyte;
          if (osize-wholesize > tagsize) throw new Exception("invalid ID3v2 text content");
          foreach (immutable cidx, char ch; str) if (ch == 0) { str = str[0..cidx]; break; }
          //FIXME
          char[] s2;
          s2.reserve(str.length*4);
          foreach (char ch; str) {
            char[4] buf = void;
            auto len = utf8Encode(buf[], cast(dchar)ch);
            assert(len > 0);
            s2 ~= buf[0..len];
          }
          delete str;
          *deststr = cast(string)s2; // it is safe to cast here
        } else {
          if (tagsize < 2) goto skiptag; // no room for BOM
          //$FF FE or $FE FF
          auto osize = wholesize;
          ubyte b0 = getUInt!ubyte;
          ubyte b1 = getUInt!ubyte;
          bool bige;
          bool utf8 = false;
          if (osize-wholesize > tagsize) throw new Exception("invalid ID3v2 text content");
          if (b0 == 0xff) {
            if (b1 != 0xfe) throw new Exception("invalid ID3v2 text content");
            bige = false;
          } else if (b0 == 0xfe) {
            if (b1 != 0xff) throw new Exception("invalid ID3v2 text content");
            bige = true;
          } else if (b0 == 0xef) {
            if (b1 != 0xbb) throw new Exception("invalid ID3v2 text content");
            if (tagsize < 3) throw new Exception("invalid ID3v2 text content");
            b1 = getUInt!ubyte;
            if (b1 != 0xbf) throw new Exception("invalid ID3v2 text content");
            // utf-8 (just in case)
            utf8 = true;
          }
          char[4] buf = void;
          char[] str;
          str.reserve(tagsize);
          while (osize-wholesize < tagsize) {
            if (!utf8) {
              b0 = getUInt!ubyte;
              b1 = getUInt!ubyte;
              dchar dch = cast(dchar)(bige ? b0*256+b1 : b1*256+b0);
              if (dch > dchar.max) dch = '\uFFFD';
              auto len = utf8Encode(buf[], dch);
              assert(len > 0);
              str ~= buf[0..len];
            } else {
              str ~= cast(char)getUInt!ubyte;
            }
          }
          if (osize-wholesize > tagsize) throw new Exception("invalid ID3v2 text content");
          foreach (immutable cidx, char ch; str) if (ch == 0) { str = str[0..cidx]; break; }
          *deststr = cast(string)str; // it is safe to cast here
        }
        continue;
      }
    skiptag:
      wholesize -= tagsize;
      foreach (immutable _; 0..tagsize) getByte();
    }

    return true;
  }
}
