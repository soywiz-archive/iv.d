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
module iv.vfs.arcs.q1pak;

import iv.vfs : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
shared static this () {
  vfsRegisterDetector(new Q1PakDetector());
}


// ////////////////////////////////////////////////////////////////////////// //
private final class Q1PakDetector : VFSDriverDetector {
  override VFSDriver tryOpen (VFile fl) {
    try {
      auto pak = new Q1PakArchiveImpl(fl);
      return new VFSDriverQ1Pak(pak);
    } catch (Exception) {}
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverQ1Pak : VFSDriver {
private:
  Q1PakArchiveImpl pak;

public:
  this (Q1PakArchiveImpl apak) {
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
private final class Q1PakArchiveImpl {
protected:
  static struct FileInfo {
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

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size); }

public:
  this (VFile fl, bool anormNames=true) {
    mNormNames = anormNames;
    open(fl);
    st = fl;
  }

  final @property auto files () {
    static struct Range {
    private:
      Q1PakArchiveImpl me;
      usize curindex;

    nothrow @safe @nogc:
      this (Q1PakArchiveImpl ame, usize aidx=0) { me = ame; curindex = aidx; }

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

    throw new VFSNamedException!"Q1PakArchive"("file not found");
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
    debug(q1pakarc) import std.stdio : writeln, writefln;
    scope(failure) cleanup();

    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"Q1PakArchive"("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "PACK" && sign != "SPAK") throw new VFSNamedException!"Q1PakArchive"("not a PAK file");
    uint direlsize = (sign[0] == 'S' ? 128 : 64);
    auto dirOfs = fl.readNum!uint;
    auto dirSize = fl.readNum!uint;
    if (dirSize%direlsize != 0 || dirSize >= flsize || dirOfs >= flsize || dirOfs+dirSize > flsize) throw new VFSNamedException!"Q1PakArchive"("invalid PAK file");
    debug(q1pakarc) writefln("dir at: 0x%08x", dirOfs);
    // read directory
    fl.seek(dirOfs);
    char[120] nbuf;
    while (dirSize >= direlsize) {
      FileInfo fi;
      dirSize -= direlsize;
      char[] name;
      {
        usize nbpos = 0;
        fl.rawReadExact(nbuf[0..direlsize-8]);
        name = new char[](direlsize-8);
        foreach (char ch; nbuf[0..direlsize-8]) {
          if (ch == 0) break;
          if (ch == '\\') ch = '/';
          if (ch == '/' && (nbpos == 0 || name.ptr[nbpos-1] == '/')) continue;
          name.ptr[nbpos++] = ch;
        }
        name = name[0..nbpos];
        if (name.length && name[$-1] == '/') name = null;
      }
      fi.ofs = fl.readNum!uint;
      fi.size = fl.readNum!uint;
      // some sanity checks
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new VFSNamedException!"Q1PakArchive"("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new VFSNamedException!"Q1PakArchive"("invalid archive directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir ~= fi;
      }
    }
    debug(q1pakarc) writeln(dir.length, " files found");
  }
}
