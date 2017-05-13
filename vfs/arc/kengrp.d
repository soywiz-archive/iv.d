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
module iv.vfs.arc.kengrp;

import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"KenGrp");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverKenGrp : VFSDriver {
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
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new /*VFSNamedException!"KenGrpArchive"*/VFSExceptionArc("file too big");
    char[12] sign;
    fl.rawReadExact(sign[]);
    if (sign != "KenSilverman") throw new /*VFSNamedException!"KenGrpArchive"*/VFSExceptionArc("not a KenGrp file");
    auto flCount = fl.readNum!uint;
    if (flCount == 0) return;
    if (flCount > 0x3fff_ffff) throw new /*VFSNamedException!"KenGrpArchive"*/VFSExceptionArc("invalid archive file");
    // read directory
    uint curfofs = (flCount+1)*16;
    char[12] nbuf;
    while (flCount-- > 0) {
      FileInfo fi;
      fl.rawReadExact(nbuf[0..12]);
      fi.ofs = curfofs;
      fi.size = fl.readNum!uint;
      curfofs += fi.size;
      char[] name;
      {
        name = new char[](prefixpath.length+12+8); // arbitrary
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
        foreach (char ch; nbuf[]) {
          if (ch == 0) break;
          if (ch == '\\' || ch == '/') ch = '^'; // arbitrary replacement
          if (ch >= 'A' && ch <= 'Z') ch += 32; // original GRPs has all names uppercased
          name.ptr[nbpos++] = ch;
        }
        name = name[0..nbpos];
        if (name.length && name[$-1] == '/') name = null;
      }
      // some sanity checks
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new /*VFSNamedException!"KenGrpArchive"*/VFSExceptionArc("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new /*VFSNamedException!"KenGrpArchive"*/VFSExceptionArc("invalid archive directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir.arrayAppendUnsafe(fi);
      }
    }
    buildNameHashTable();
  }
}
