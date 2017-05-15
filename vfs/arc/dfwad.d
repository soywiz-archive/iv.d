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
module iv.vfs.arc.dfwad is aliced;

import iv.vfs.types : Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"DFWad");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverDFWad : VFSDriver {
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long pksize;
    long ofs; // offset in archive
    long size = -1;
    string name; // with path
  }

  /** query various file properties; driver-specific.
   * properties of interest:
   *   "packed" -- is file packed?
   *   "offset" -- offset in wad
   */
  public override VFSVariant stat (usize idx, const(char)[] propname) {
    if (idx >= dir.length) return VFSVariant();
    if (propname == "packed") return VFSVariant(true);
    if (propname == "offset") return VFSVariant(dir[idx].ofs);
    return VFSVariant();
  }

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    auto stpos = dir[idx].ofs;
    auto size = -1;
    auto pksize = dir[idx].pksize;
    VFSZLibMode mode = VFSZLibMode.ZLib;
    return wrapZLibStreamRO(st, mode, size, stpos, pksize, dir[idx].name);
  }

  void open (VFile fl, const(char)[] prefixpath) {
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new /*VFSNamedException!"DFWadArchive"*/VFSExceptionArc("file too big");
    // check it
    if (flsize < 8) throw new /*VFSNamedException!"DFWadArchive"*/VFSExceptionArc("invalid archive file");

    char[6] sign;
    fl.rawReadExact(sign[]);
    if (sign != "DFWAD\x01") throw new /*VFSNamedException!"DFWadArchive"*/VFSExceptionArc("invalid archive file");

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
      char[] name;
      {
        import iv.vfs.koi8 : win2koi8;
        name = new char[](prefixpath.length+nbuf.length+path.length+2);
        usize nbpos = prefixpath.length;
        if (fi.ofs == 0 && fi.pksize == 0) {
          nbpos = 0;
        } else {
          if (nbpos) name[0..nbpos] = prefixpath[];
          if (path.length) { name[nbpos..nbpos+path.length] = path[]; nbpos += path.length; }
        }
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
      if (fi.pksize > 0 && fi.ofs >= flsize) throw new /*VFSNamedException!"DFWadArchive"*/VFSExceptionArc("invalid archive file directory");
      if (fi.pksize >= flsize) throw new /*VFSNamedException!"DFWadArchive"*/VFSExceptionArc("invalid archive file directory");
      if (fi.ofs+fi.pksize > flsize) throw new /*VFSNamedException!"DFWadArchive"*/VFSExceptionArc("invalid archive file directory");
      if (name.length) {
        //{ import core.stdc.stdio : printf; printf("[%.*s]\n", cast(uint)name.length, name.ptr); }
        fi.name = cast(string)name; // it's safe here
        dir.arrayAppendUnsafe(fi);
      }
    }
    debug(dfwadarc) { import std.stdio; writeln(dir.length, " files found"); }
    buildNameHashTable();
  }
}
