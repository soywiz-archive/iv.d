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
module iv.vfs.arcs.dfwad;

import iv.vfs : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
shared static this () {
  vfsRegisterDetector(new DFWadDetector());
}


// ////////////////////////////////////////////////////////////////////////// //
private final class DFWadDetector : VFSDriverDetector {
  override VFSDriver tryOpen (VFile fl) {
    try {
      auto pak = new DFWadArchiveImpl(fl);
      return new VFSDriverDFWad(pak);
    } catch (Exception) {}
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverDFWad : VFSDriver {
private:
  DFWadArchiveImpl pak;

public:
  this (DFWadArchiveImpl apak) {
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
private final class DFWadArchiveImpl {
protected:
  static struct FileInfo {
    ulong pksize;
    ulong ofs; // offset in archive
    string name; // with path
  }

  // for dir range
  public static struct DirEntry {
    string name;
  }

protected:
  VFile st;
  FileInfo[] dir;
  bool mNormNames; // true: convert names to lower case, do case-insensitive comparison (ASCII only)

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    auto stpos = dir[idx].ofs;
    auto size = -1;
    auto pksize = dir[idx].pksize;
    VFSZLibMode mode = VFSZLibMode.ZLib;
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
      DFWadArchiveImpl me;
      usize curindex;

    nothrow @safe @nogc:
      this (DFWadArchiveImpl ame, usize aidx=0) { me = ame; curindex = aidx; }

    public:
      @property bool empty () const { return (curindex >= me.dir.length); }
      @property DirEntry front () const {
        return DirEntry((curindex < me.dir.length ? me.dir[cast(usize)curindex].name : null));
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
    import iv.vfs.koi8 : koi8StrCaseEqu;
    foreach_reverse (immutable idx, ref fi; dir) {
      if (mNormNames) {
        if (koi8StrCaseEqu(fi.name, de.name)) return wrap(idx);
      } else {
        if (fi.name == de.name) return wrap(idx);
      }
    }
    throw new VFSNamedException!"DFWadArchive"("file not found");
  }

  VFile fopen (const(char)[] fname) {
    DirEntry de;
    de.name = cast(string)fname; // it's safe here
    return fopen(de);
  }

private:
  void open (VFile fl) {
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"DFWadArchive"("file too big");
    // check it
    if (flsize < 8) throw new VFSNamedException!"DFWadArchive"("invalid archive file");

    char[6] sign;
    fl.rawReadExact(sign[]);
    if (sign != "DFWAD\x01") throw new VFSNamedException!"DFWadArchive"("invalid archive file");

    uint count = fl.readNum!ushort;
    //{ import core.stdc.stdio : printf; printf("dfwad: count=%u\n", cast(uint)count); }
    // read directory
    char[17] dirbuf;
    char[] path; // current path
    char[16] nbuf;
    while (count--) {
      FileInfo fi;
      fl.rawReadExact(nbuf[]);
      fi.ofs = fl.readNum!uint;
      fi.pksize = fl.readNum!uint;
      if (fi.ofs == 0 && fi.pksize == 0) path = null; // new path
      char[] name;
      {
        import iv.vfs.koi8 : win2koi8;
        name = new char[](nbuf.length+path.length+2);
        if (path.length) name[0..path.length] = path[];
        usize nbpos = path.length;
        foreach (char ch; nbuf[]) {
               if (ch == 0) break;
          else if (ch == '\\') ch = '/';
          else if (ch == '/') ch = '_';
          if (ch == '/' && (nbpos == 0 || name.ptr[nbpos-1] == '/')) continue;
          name.ptr[nbpos++] = win2koi8(ch);
        }
        if (fi.ofs == 0 && fi.pksize == 0 && nbpos > 0 && name[nbpos-1] != '/') name.ptr[nbpos++] = '/';
        name = name[0..nbpos];
        if (fi.ofs == 0 && fi.pksize == 0) {
          // new path
          if (name == "/") name = null;
          assert(name.length <= dirbuf.length);
          if (name.length) {
            dirbuf[0..name.length] = name[];
            path = dirbuf[0..name.length];
          } else {
            path = null;
          }
          //{ import core.stdc.stdio : printf; printf("NEWDIR: [%.*s]\n", cast(uint)path.length, path.ptr); }
          continue;
        } else {
          // normal file
          if (name.length && name[$-1] == '/') name = null;
        }
      }
      // some sanity checks
      if (fi.pksize > 0 && fi.ofs >= flsize) throw new VFSNamedException!"DFWadArchive"("invalid archive file directory");
      if (fi.pksize >= flsize) throw new VFSNamedException!"DFWadArchive"("invalid archive file directory");
      if (fi.ofs+fi.pksize > flsize) throw new VFSNamedException!"DFWadArchive"("invalid archive file directory");
      if (name.length) {
        //{ import core.stdc.stdio : printf; printf("[%.*s]\n", cast(uint)name.length, name.ptr); }
        fi.name = cast(string)name; // it's safe here
        dir ~= fi;
      }
    }
    debug(dfwadarc) { import std.stdio; writeln(dir.length, " files found"); }
  }
}