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
private import iv.vfs.arcs : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"F2Dat");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverF2Dat : VFSDriver {
  private import iv.vfs.arcs : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    bool packed;
    long pksize;
    long size;
    long ofs; // offset in archive
    string name; // with path
  }

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    auto stpos = dir[idx].ofs;
    auto size = dir[idx].size;
    auto pksize = dir[idx].pksize;
    VFSZLibMode mode = (dir[idx].packed ? VFSZLibMode.ZLib : VFSZLibMode.Raw);
    return wrapZLibStreamRO(st, mode, size, stpos, pksize);
  }

  void open (VFile fl, const(char)[] prefixpath) {
    debug(f2datarc) import std.stdio : writeln, writefln;
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"F2DatArchive"("file too big");
    // check it
    if (flsize < 8) throw new VFSNamedException!"F2DatArchive"("invalid archive");
    fl.seek(flsize-8);
    auto dirSize = fl.readNum!uint;
    auto datSize = fl.readNum!uint;
    if (dirSize < 17 || datSize != flsize || dirSize > datSize-4) throw new VFSNamedException!"F2DatArchive"("invalid archive");
    debug(f2datarc) writefln("dir at: 0x%08x", datSize-4-dirSize);
    // read directory
    fl.seek(datSize-4-dirSize);
    char[2048] nbuf;
    while (dirSize >= 17) {
      FileInfo fi;
      dirSize -= 17;
      auto nlen = fl.readNum!uint;
      if (nlen == 0 || nlen > dirSize || nlen > 2048) throw new VFSNamedException!"F2DatArchive"("invalid archive directory");
      char[] name;
      {
        fl.rawReadExact(nbuf[0..nlen]);
        dirSize -= nlen;
        name = new char[](prefixpath.length+nlen);
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
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
      if (fi.pksize > 0 && fi.ofs >= datSize-4-dirSize) throw new VFSNamedException!"F2DatArchive"("invalid archive directory");
      if (fi.pksize >= datSize) throw new VFSNamedException!"F2DatArchive"("invalid archive directory");
      if (fi.ofs+fi.pksize > datSize-4-dirSize) throw new VFSNamedException!"F2DatArchive"("invalid archive directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir ~= fi;
      }
    }
    debug(f2datarc) writeln(dir.length, " files found");
  }
}
