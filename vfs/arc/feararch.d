/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.vfs.arc.feararch /*is aliced*/;

import iv.alice;
import iv.vfs.types : Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"FearArch");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverFearArch : VFSDriver {
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
    if (propname == "arcname") return VFSVariant("arch00");
    if (propname == "packed") return VFSVariant(false);
    if (propname == "pksize") return VFSVariant(dir[idx].size);
    if (propname == "offset") return VFSVariant(dir[idx].ofs);
    if (propname == "size") return VFSVariant(dir[idx].size);
    return VFSVariant();
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    import core.stdc.stdlib : malloc, free;

    char* namesec = null;
    uint namesecsize;
    scope(exit) if (namesec !is null) free(namesec);

    fl.seek(0);
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign == "LTAX" || sign == "XATL") throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("compressed archives aren't supported");
    if (sign == "RATL") throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("big-endian archives aren't supported");
    if (sign != "LTAR") throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("invalid archive format");

    auto ver = fl.readNum!uint;
    if (ver != 3) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("invalid archive version");

    namesecsize = fl.readNum!uint;
    auto dircount = fl.readNum!uint;
    auto filecount = fl.readNum!uint;
    immutable unk0 = fl.readNum!uint; // 1
    immutable unk1 = fl.readNum!uint; // 0
    immutable unk2 = fl.readNum!uint; // 0/1?
    //conwriteln("unknowns: ", unk0, ",", unk1, ",", unk2);
    ubyte[16] hash;
    fl.rawReadExact(hash[]);
    //conwriteln("dirs: ", dircount, "; files: ", filecount, "; nss=", namesecsize);

    //auto ofs = fl.tell+namesecsize+filecount*(4+8+8+8+4)/*+dircount*(4+4+4+4)*/;
    //conwritefln!"dirs offset: 0x%08x"(cast(uint)ofs);

    if (namesecsize > int.max/8) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("name section too big");
    if (filecount > int.max/16) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("too many files");
    if (dircount > int.max/16) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("too many directories");

    // load names
    namesec = cast(char*)malloc(namesecsize);
    if (namesec is null) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("out of memory");
    fl.rawReadExact(namesec[0..namesecsize]);
    foreach (ref char ch; namesec[0..namesecsize]) if (ch == '\\') ch = '/'; // 'cause why not?

    const(char)[] getNameAt (uint ofs) {
      if (ofs >= namesecsize) return "";
      auto eofs = ofs;
      while (eofs < namesecsize && namesec[eofs]) ++eofs;
      return namesec[ofs..eofs];
    }

    // load files
    static struct FileRec {
      int idx;
      uint nameofs;
      long ofs;
      long pksize;
      long size;
      uint zip;
    }
    FileRec[] files;
    //files.unsafeArraySetLength(filecount);
    //files.length = filecount;
    files.arraySetLengthUnsafe(filecount);
    scope(exit) delete files;
    foreach (immutable idx, ref FileRec fr; files) {
      fr.idx = cast(uint)idx;
      fr.nameofs = fl.readNum!uint;
      fr.ofs = fl.readNum!long;
      fr.pksize = fl.readNum!long;
      fr.size = fl.readNum!long;
      fr.zip = fl.readNum!uint;
      //conwriteln("FILE: idx=", idx, "; name=[", getNameAt(fr.nameofs), "]; ofs=", fr.ofs, "; pksize=", fr.pksize, "; size=", fr.size, "; zip=", fr.zip);
      if (fr.pksize != fr.size) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("packed files aren't supported yet");
      if (fr.zip != 0) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("compressed files aren't supported yet");
    }

    // load dirs
    static struct DirRec {
      int idx;
      uint nameofs;
      uint subdircount;
      uint nextdir;
      uint flcount;
      uint flfirst;
    }
    DirRec[] dirs;
    //dirs.unsafeArraySetLength(dircount);
    //dirs.length = dircount;
    dirs.arraySetLengthUnsafe(dircount);
    scope(exit) delete dirs;
    uint totalfiles = 0;
    foreach (immutable idx, ref DirRec dr; dirs) {
      dr.idx = cast(uint)idx;
      dr.nameofs = fl.readNum!uint;
      dr.subdircount = fl.readNum!uint;
      dr.nextdir = fl.readNum!uint;
      dr.flcount = fl.readNum!uint;
      dr.flfirst = totalfiles;
      if (dr.flcount > filecount) { /*conwriteln("flc=", dr.flcount, "; filecount=", filecount);*/ throw new Exception("invalid dir record"); }
      totalfiles += dr.flcount;
      if (totalfiles > filecount) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("invalid directory table");
      //conwriteln("DIR: idx=", idx, "; name=[", getNameAt(dr.nameofs), "]; sdc=", dr.subdircount, "; nd=", dr.nextdir, "; flc=", dr.flcount, "; flfirst=", dr.flfirst);
    }
    if (totalfiles > filecount) throw new /*VFSNamedException!"FearArchArchive"*/VFSExceptionArc("invalid directory table");

    foreach (const ref DirRec dr; dirs) {
      if (dr.flcount == 0) continue;
      auto dirname = getNameAt(dr.nameofs);
      while (dirname.length && dirname.ptr[0] == '/') dirname = dirname[1..$];
      while (dirname.length && dirname[$-1] == '/') dirname = dirname[0..$-1];
      foreach (const ref FileRec fr; files[dr.flfirst..dr.flfirst+dr.flcount]) {
        auto flname = getNameAt(fr.nameofs);
        while (flname.length && flname.ptr[0] == '/') flname = flname[1..$];
        while (flname.length && flname[$-1] == '/') flname = flname[0..$-1];
        if (flname.length == 0) continue; // just in case
        FileInfo fi;
        fi.ofs = fr.ofs;
        fi.size = fr.size;
        // build name
        char[] name;
        name.length = prefixpath.length+dirname.length+flname.length+2;
        name[0..prefixpath.length] = prefixpath[];
        uint npos = cast(uint)prefixpath.length;
        if (dirname.length > 0) {
          name[npos..npos+dirname.length] = dirname[];
          npos += cast(uint)dirname.length;
          if (dirname[$-1] != '/') name[npos++] = '/';
        }
        name[npos..npos+flname.length] = flname[];
        npos += cast(uint)flname.length;
        name = name[0..npos];
        fi.name = cast(string)name; // it is safe to cast here
        dir.arrayAppendUnsafe(fi);
      }
    }
    buildNameHashTable();
  }
}
