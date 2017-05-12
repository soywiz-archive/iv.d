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

import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arcs.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"Q1Pak");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverQ1Pak : VFSDriver {
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
  }

  /** query various file properties; driver-specific.
   * properties of interest:
   *   "packed" -- is file packed?
   *   "pksize" -- packed file size (for archives)
   *   "offset" -- offset in wad
   *   "size"   -- file size (so we can get size without opening the file)
   */
  public override VFSVariant stat (usize idx, const(char)[] propname) {
    if (idx >= dir.length) return VFSVariant();
    if (propname == "packed") return VFSVariant(false);
    if (propname == "pksize") return VFSVariant(dir[idx].size);
    if (propname == "offset") return VFSVariant(dir[idx].ofs);
    if (propname == "size") return VFSVariant(dir[idx].size);
    return VFSVariant();
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    debug(q1pakarc) import std.stdio : writeln, writefln;
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new /*VFSNamedException!"Q1PakArchive"*/VFSExceptionArc("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "PACK" && sign != "SPAK") throw new /*VFSNamedException!"Q1PakArchive"*/VFSExceptionArc("not a PAK file");
    uint direlsize = (sign[0] == 'S' ? 128 : 64);
    auto dirOfs = fl.readNum!uint;
    auto dirSize = fl.readNum!uint;
    if (dirSize%direlsize != 0 || dirSize >= flsize || dirOfs >= flsize || dirOfs+dirSize > flsize) throw new /*VFSNamedException!"Q1PakArchive"*/VFSExceptionArc("invalid PAK file");
    debug(q1pakarc) writefln("dir at: 0x%08x", dirOfs);
    // read directory
    fl.seek(dirOfs);
    char[120] nbuf;
    while (dirSize >= direlsize) {
      FileInfo fi;
      dirSize -= direlsize;
      char[] name;
      {
        fl.rawReadExact(nbuf[0..direlsize-8]);
        name = new char[](prefixpath.length+direlsize-8);
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
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
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new /*VFSNamedException!"Q1PakArchive"*/VFSExceptionArc("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new /*VFSNamedException!"Q1PakArchive"*/VFSExceptionArc("invalid archive directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir.arrayAppendUnsafe(fi);
      }
    }
    debug(q1pakarc) writeln(dir.length, " files found");
    buildNameHashTable();
  }
}
