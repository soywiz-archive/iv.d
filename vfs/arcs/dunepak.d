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
module iv.vfs.arcs.dunepak;

import iv.vfs : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
shared static this () {
  vfsRegisterDetector(new DunePakDetector());
}


// ////////////////////////////////////////////////////////////////////////// //
private final class DunePakDetector : VFSDriverDetector {
  override VFSDriver tryOpen (VFile fl) {
    try {
      auto pak = new DunePakArchiveImpl(fl);
      return new VFSDriverDunePak(pak);
    } catch (Exception) {}
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverDunePak : VFSDriver {
private:
  DunePakArchiveImpl pak;

public:
  this (DunePakArchiveImpl apak) {
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
private final class DunePakArchiveImpl {
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
      DunePakArchiveImpl me;
      usize curindex;

    nothrow @safe @nogc:
      this (DunePakArchiveImpl ame, usize aidx=0) { me = ame; curindex = aidx; }

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

    throw new VFSNamedException!"DunePakArchive"("file not found");
  }

  VFile fopen (const(char)[] fname) {
    DirEntry de;
    de.name = cast(string)fname; // it's safe here
    return fopen(de);
  }

private:
  void open (VFile fl) {
    debug(dunepakarc) import std.stdio : writeln, writefln;

    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"DunePakArchive"("file too big");
    // read directory
    uint prevofs = uint.max;
    char[12] nbuf;
    for (;;) {
      auto ofs = fl.readNum!uint;
      if (ofs == 0) break;
      if (ofs >= flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      char[] name;
      {
        usize nbpos = 0;
        char ch;
        for (;;) {
          fl.rawReadExact((&ch)[0..1]);
          if (ch == 0) break;
          if (nbpos > 12) throw new VFSNamedException!"DunePakArchive"("invalid directory");
          if (ch == '\\' || ch == '/' || ch > 127) throw new VFSNamedException!"DunePakArchive"("invalid directory");
          nbuf.ptr[nbpos++] = ch;
        }
        if (nbpos == 0) throw new VFSNamedException!"DunePakArchive"("invalid directory");
        name = new char[](nbpos);
        name[] = nbuf[0..nbpos];
      }
      debug(dunepakarc) writefln("[%s]: ofs=0x%08x", name, ofs);
      FileInfo fi;
      fi.ofs = ofs;
      if (prevofs != uint.max) {
        if (dir[$-1].ofs > ofs) throw new VFSNamedException!"DunePakArchive"("invalid directory");
        dir[$-1].size = ofs-dir[$-1].ofs;
        // some sanity checks
        if (dir[$-1].size > 0 && dir[$-1].ofs >= flsize || dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
        if (dir[$-1].ofs+dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      }
      fi.name = cast(string)name; // it's safe here
      dir ~= fi;
      prevofs = ofs;
    }
    if (dir.length) {
      // fix last file
      if (dir[$-1].ofs > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      dir[$-1].size = flsize-dir[$-1].ofs;
      // some sanity checks
      if (dir[$-1].size > 0 && dir[$-1].ofs >= flsize || dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      if (dir[$-1].ofs+dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
    }
    debug(dunepakarc) writeln(dir.length, " files found");
  }
}
