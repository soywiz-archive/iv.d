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
module iv.vfs.arcs.abuse;

import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
private import iv.vfs.arcs.internal : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"AbuseSpec");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverAbuseSpec : VFSDriver {
  private import iv.vfs.arcs.internal : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
    string link; // linked name or null
  }

  VFile wrap (usize idx) {
    if (dir[idx].link.length != 0) {
      return vfsOpenFile(dir[idx].link);
    } else {
      return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name);
    }
  }

  void open (VFile fl, const(char)[] prefixpath) {
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"AbuseSpecArchive"("file too big");
    char[512] nbuf;
    fl.rawReadExact(nbuf[0..8]);
    if (nbuf[0..8] != "SPEC1.0\0") throw new VFSNamedException!"AbuseSpecArchive"("invalid signature");
    // read directory
    uint count = fl.readNum!ushort;
    //{ import core.stdc.stdio : printf; printf("abuse: %u files\n", count); }
    while (count-- > 0) {
      ubyte type = fl.readNum!ubyte;
      if (type > SPEC_MAX_TYPE) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
      ubyte nlen = fl.readNum!ubyte;
      //{ import core.stdc.stdio : printf; printf("  type=%u; nlen=%u\n", cast(uint)type, cast(uint)nlen); }
      if (nlen == 0) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
      char[] name;
      {
        fl.rawReadExact(nbuf[0..nlen]);
        name = new char[](prefixpath.length+nlen+dirs[type].length);
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
        if (dirs[type].length) { name[nbpos..nbpos+dirs[type].length] = dirs[type][]; nbpos += dirs[type].length; }
        foreach (char ch; nbuf[0..nlen]) {
          if (ch == 0) break;
          if (ch == '\\' || ch == '/' || ch > 127) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
          name.ptr[nbpos++] = ch;
        }
        if (nbpos == 0) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
        name = name[0..nbpos];
        //{ import core.stdc.stdio : printf; printf("abuse: [%.*s]\n", cast(uint)name.length, name.ptr); }
      }
      ubyte flags = fl.readNum!ubyte;
      FileInfo fi;
      fi.name = cast(string)name; // it's safe here
      if (flags&0x01) {
        // link
        nlen = fl.readNum!ubyte;
        if (nlen == 0) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
        fl.rawReadExact(nbuf[0..nlen]);
        name = new char[](nlen);
        usize nbpos = 0;
        foreach (char ch; nbuf[0..nlen]) {
          if (ch == 0) break;
          if (ch == '\\') ch = '/';
          if (ch > 127) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
          name.ptr[nbpos++] = ch;
        }
        if (nbpos == 0) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
        name = name[0..nbpos];
        fi.link = cast(string)name; // it's safe here
      } else {
        fi.size = fl.readNum!uint;
        fi.ofs = fl.readNum!uint;
        // sanity checks
        if (fi.size > flsize || fi.ofs > flsize || fi.size+fi.ofs > flsize) throw new VFSNamedException!"AbuseSpecArchive"("invalid directory");
      }
      dir.arrayAppendUnsafe(fi);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:

enum {
  SPEC_INVALID_TYPE = 0,
  SPEC_COLOR_TABLE = 1,
  SPEC_PALETTE = 2,
  /* Empty slot */
  SPEC_IMAGE = 4,
  SPEC_FORETILE = 5,
  SPEC_BACKTILE = 6,
  SPEC_CHARACTER = 7,
  SPEC_MORPH_POINTS_8 = 8,
  SPEC_MORPH_POINTS_16 = 9,
  SPEC_GRUE_OBJS = 10,
  SPEC_EXTERN_SFX = 11,
  SPEC_DMX_MUS = 12,
  SPEC_PATCHED_MORPH = 13,
  SPEC_NORMAL_FILE = 14,
  SPEC_COMPRESS1_FILE = 15,
  SPEC_VECTOR_IMAGE = 16,
  SPEC_LIGHT_LIST = 17,
  SPEC_GRUE_FGMAP = 18,
  SPEC_GRUE_BGMAP = 19,
  SPEC_DATA_ARRAY = 20,
  SPEC_CHARACTER2 = 21,
  SPEC_PARTICLE = 22,
  SPEC_EXTERNAL_LCACHE = 23,
  //
  SPEC_MAX_TYPE = 23,
}


immutable string[SPEC_MAX_TYPE+1] dirs = [
  "bad/",
  "colortabel/",
  "pal/",
  "empty/",
  "img/",
  "foretile/",
  "backtile/",
  "character/",
  "morph8/",
  "morph16/",
  "grue/",
  "esfx/",
  "dmxmus/",
  "morphpatch/",
  "", // normal file
  "cz1/", // compressed
  "vimg/",
  "lights/",
  "foregrue/",
  "backgrue/",
  "data/",
  "character2/",
  "particle/",
  "ecache/",
];
