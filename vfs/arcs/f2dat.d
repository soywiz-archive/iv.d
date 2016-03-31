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
module iv.vfs.arcs.f2dat;

import iv.vfs : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
shared static this () {
  vfsRegisterDetector(new F2DatDetector());
}


// ////////////////////////////////////////////////////////////////////////// //
private final class F2DatDetector : VFSDriverDetector {
  override VFSDriver tryOpen (VFile fl) {
    try {
      auto pak = new F2DatArchiveImpl(fl);
      return new VFSDriverF2Dat(pak);
    } catch (Exception) {}
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverF2Dat : VFSDriver {
private:
  F2DatArchiveImpl pak;

public:
  this (F2DatArchiveImpl apak) {
    if (apak is null) throw new VFSException("wtf?!");
    pak = apak;
  }

  /// doesn't do any security checks, 'cause i don't care
  override VFile tryOpen (const(char)[] fname) {
    static import core.stdc.stdio;
    if (fname.length == 0) return VFile.init;
    try {
      return pak.fopen(fname);
    } catch (Exception) {}
    return VFile.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private final class F2DatArchiveImpl {
protected:
  static struct FileInfo {
    bool packed;
    ulong pksize;
    ulong size;
    ulong ofs; // offset in .DAT
    string name; // with path
  }

  // for dir range
  public static struct DirEntry {
    string name;
    ulong size;
  }

protected:
  VFile st;
  FileInfo[] dir;
  bool mNormNames; // true: convert names to lower case, do case-insensitive comparison (ASCII only)

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    auto stpos = dir[idx].ofs;
    auto size = dir[idx].size;
    auto pksize = dir[idx].pksize;
    VFSZLibMode mode = (dir[idx].packed ? VFSZLibMode.ZLib : VFSZLibMode.Raw);
    return wrapZLibStreamRO(st, mode, size, stpos, pksize);
  }

public:
  this (VFile fl, bool anormNames=true) {
    mNormNames = anormNames;
    open(fl);
    st = fl;
  }

  final @property auto files () {
    static struct Range {
    private:
      F2DatArchiveImpl me;
      usize curindex;

    nothrow @safe @nogc:
      this (F2DatArchiveImpl ame, usize aidx=0) { me = ame; curindex = aidx; }

    public:
      @property bool empty () const { return (curindex >= me.dir.length); }
      @property DirEntry front () const {
        return DirEntry(
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].name : null),
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].size : 0));
      }
      @property Range save () { return Range(me, curindex); }
      void popFront () { if (curindex < me.dir.length) ++curindex; }
      @property usize length () const { return me.dir.length; }
      @property usize position () const { return curindex; } // current position
      @property void position (usize np) { curindex = np; }
      void rewind () { curindex = 0; }
    }
    return Range(this);
  }

  VFile fopen (ref in DirEntry de) {
    static bool strequ() (const(char)[] s0, const(char)[] s1) {
      if (s0.length != s1.length) return false;
      foreach (immutable idx, char ch; s0) {
        char c1 = s1[idx];
        if (ch >= 'A' && ch <= 'Z') ch += 32; // poor man's `toLower()`
        if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man's `toLower()`
        if (ch != c1) return false;
      }
      return true;
    }

    foreach_reverse (immutable idx, ref fi; dir) {
      if (mNormNames) {
        if (strequ(fi.name, de.name)) return wrap(idx);
      } else {
        if (fi.name == de.name) return wrap(idx);
      }
    }

    throw new VFSNamedException!"F2DatArchive"("file not found");
  }

  VFile fopen (const(char)[] fname) {
    DirEntry de;
    de.name = cast(string)fname; // it's safe here
    return fopen(de);
  }

private:
  void cleanup () {
    dir.length = 0;
  }

  void open (VFile fl) {
    debug(f2datarc) import std.stdio : writeln, writefln;
    scope(failure) cleanup();

    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"F2DatArchive"("file too big");
    // check it
    if (flsize < 8) throw new VFSNamedException!"F2DatArchive"("invalid DAT file");
    fl.seek(flsize-8);
    auto dirSize = fl.readNum!uint;
    auto datSize = fl.readNum!uint;
    if (dirSize < 17 || datSize != flsize || dirSize > datSize-4) throw new VFSNamedException!"F2DatArchive"("invalid DAT file");
    debug(f2datarc) writefln("dir at: 0x%08x", datSize-4-dirSize);
    // read directory
    fl.seek(datSize-4-dirSize);
    char[2048] nbuf;
    while (dirSize >= 17) {
      FileInfo fi;
      dirSize -= 17;
      auto nlen = fl.readNum!uint;
      if (nlen == 0 || nlen > dirSize || nlen > 2048) throw new VFSNamedException!"F2DatArchive"("invalid DAT file directory");
      char[] name;
      {
        usize nbpos = 0;
        fl.rawReadExact(nbuf[0..nlen]);
        dirSize -= nlen;
        name = new char[](nlen);
        foreach (char ch; nbuf[0..nlen]) {
               if (ch == 0) break;
          else if (ch == '\\') ch = '/';
          else if (ch == '/') ch = '_';
          if (ch == '/' && (nbpos == 0 || name.ptr[nbpos-1] == '/')) continue;
          name.ptr[nbpos++] = ch;
        }
        name = name[0..nbpos];
        if (name.length && name[$-1] == '/') name = null;
      }
      fi.packed = (fl.readNum!ubyte() != 0);
      fi.size = fl.readNum!uint;
      fi.pksize = fl.readNum!uint;
      fi.ofs = fl.readNum!uint;
      // some sanity checks
      if (fi.size > 0 && fi.ofs >= datSize-4-dirSize) throw new VFSNamedException!"F2DatArchive"("invalid DAT file directory");
      if (fi.size >= datSize) throw new VFSNamedException!"F2DatArchive"("invalid DAT file directory");
      if (fi.ofs+fi.size > datSize-4-dirSize) throw new VFSNamedException!"F2DatArchive"("invalid DAT file directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir ~= fi;
      }
    }
    debug(f2datarc) writeln(dir.length, " files found");
  }
}
