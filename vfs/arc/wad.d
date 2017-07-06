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
module iv.vfs.arc.wad /*is aliced*/;

import iv.alice;
import iv.vfs.types : Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"Wad");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverWad : VFSDriver {
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
    if (propname == "arcname") return VFSVariant("wad");
    if (propname == "packed") return VFSVariant(false);
    if (propname == "pksize") return VFSVariant(dir[idx].size);
    if (propname == "offset") return VFSVariant(dir[idx].ofs);
    if (propname == "size") return VFSVariant(dir[idx].size);
    return VFSVariant();
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    static immutable string[18] mapfiles = [
      "things", "linedefs", "sidedefs", "vertexes", "segs", "ssectors", "nodes", "sectors", "reject", "blockmap",
      "behavior", "scripts", "textmap", "znodes", "dialogue", "endmap", "gl_pvs", "gl_level"];
    static bool isMapPart (const(char)[] s) {
      foreach (immutable idx, char ch; s) if (ch == 0) { s = s[0..idx]; break; }
      if (s.length > 8) return false; // wtf?!
      char[8] nm;
      auto len = s.length;
      foreach (immutable idx, char ch; s) {
        if (ch >= 'A' && ch <= 'Z') ch += 32; // original WADs has all names uppercased
        nm[idx] = ch;
      }
      foreach (string nn; mapfiles) if (nn == nm[0..len]) return true;
      return false;
    }
    static bool isMapName (const(char)[] s) {
      foreach (immutable idx, char ch; s) if (ch == 0) { s = s[0..idx]; break; }
      int spos = 0;
      bool skipNum () {
        if (spos >= s.length) return false;
        if (s[spos] >= '0' && s[spos] <= '9') { ++spos; return true; }
        return false;
      }
      // ExMx?
      if (s.length >= 4 && s[0] == 'E') {
        spos = 1; // skip 'E'
        if (!skipNum) return false; // should be at least one
        skipNum(); // allow two-digit episodes
        if (spos >= s.length || s[spos] != 'M') return false;
        ++spos;
        if (!skipNum) return false; // should be at least one
        skipNum(); // allow two-digit maps
        return (spos >= s.length);
      }
      // MAPxx
      if (s.length >= 5 && s[0..3] == "MAP") {
        spos = 3;
        while (spos < s.length) { if (!skipNum) return false; }
        return (spos >= s.length);
      }
      return false;
    }
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new /*VFSNamedException!"WadArchive"*/VFSExceptionArc("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "IWAD" && sign != "PWAD") throw new /*VFSNamedException!"WadArchive"*/VFSExceptionArc("not a WAD file");
    auto flCount = fl.readNum!uint;
    auto dirOfs = fl.readNum!uint;
    if (flCount == 0) return;
    if (flCount > 0x3fff_ffff || dirOfs >= flsize || dirOfs+flCount*16 > flsize) throw new /*VFSNamedException!"WadArchive"*/VFSExceptionArc("invalid archive file");
    //{ import core.stdc.stdio; printf("[%.*s]\n", 4, sign.ptr); }
    // read directory
    fl.seek(dirOfs);
    char[8] nbuf;
    string lastSeenMap; // last seen map header (ExMx or MAPxx, lowercased, serves as directory name)
    string curPath; // for start/end lumps
    while (flCount-- > 0) {
      FileInfo fi;
      fi.ofs = fl.readNum!uint;
      fi.size = fl.readNum!uint;
      fl.rawReadExact(nbuf[0..8]);
      //{ import core.stdc.stdio; printf("[%.*s] %u %u\n", 8, nbuf.ptr, cast(uint)fi.ofs, cast(uint)fi.size); }
      // some idiotic old tools loves to create empty space in directory
      if (nbuf[0] == 0) {
        // this shit cannot be accessed anyway
        continue;
      }
      bool mapPart = false;
      // check for map lumps
      if (isMapName(nbuf[])) {
        mapPart = true;
        // this is map header, remember it, and add "map header file" (doom legacy keeps scripts there)
        if (fi.size == 0) fi.ofs = 0;
        char[] s;
        foreach (char ch; nbuf) {
          if (ch == 0) break;
          if (ch >= 'A' && ch <= 'Z') ch += 32; // original WADs has all names uppercased
          s.arrayAppendUnsafe(ch);
        }
        s.arrayAppendUnsafe('/');
        lastSeenMap = cast(string)s; // it is safe to cast here
        nbuf[] = "HEADER\x00\x00"; // replace header name
      } else if (isMapPart(nbuf[])) {
        mapPart = true;
      } else {
        // check for special marker lumps
        // convert name to lower case, 'cause why not?
        int ep = 0;
        while (ep < nbuf.length && nbuf.ptr[ep]) {
          auto ch = nbuf.ptr[ep];
          if (ch >= 'A' && ch <= 'Z') nbuf.ptr[ep] += 32;
          ++ep;
        }
        const(char)[] lname = nbuf[0..ep];
        if (lname.length == 0) lname = "ghost-of-kain";
        // "*_START"
        if (lname.length > 6 && lname[$-6..$] == "_start") {
          if (lname == "p_start") { curPath = "patches/"; continue; }
          if (lname == "p1_start") { curPath = "patches/"; continue; }
          if (lname == "p2_start") { curPath = "patches/"; continue; }
          if (lname == "p3_start") { curPath = "patches/"; continue; }
          if (lname == "s_start") { curPath = "sprites/"; continue; }
          if (lname == "ss_start") { curPath = "psprites/"; continue; }
          if (lname == "f_start") { curPath = "flats/"; continue; }
          if (lname == "f1_start") { curPath = "flats/"; continue; }
          if (lname == "f2_start") { curPath = "flats/"; continue; }
          if (lname == "f3_start") { curPath = "flats/"; continue; }
          if (lname == "ff_start") { curPath = "pflats/"; continue; }
          if (lname == "tx_start") { curPath = "textures/"; continue; }
          if (lname == "hi_start") { curPath = "hitextures/"; continue; }
          // unknown
          curPath = lname[0..$-6].idup~"/";
          continue;
        }
        // "*_END"
        if (lname.length > 4 && lname[$-4..$] == "_end") {
          // here we should check for correct name, but meh...
          curPath = null;
          continue;
        }
      }
      char[] name;
      {
        name = new char[](prefixpath.length+8+(mapPart ? lastSeenMap.length : curPath.length)+8); // arbitrary
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
        if (mapPart) {
          if (lastSeenMap.length) { name[nbpos..nbpos+lastSeenMap.length] = lastSeenMap; nbpos += lastSeenMap.length; }
        } else {
          if (curPath.length) { name[nbpos..nbpos+curPath.length] = curPath; nbpos += curPath.length; }
        }
        foreach (char ch; nbuf[]) {
          import iv.vfs.koi8;
          if (ch == 0) break;
          if (ch == '\\') ch = '#'; // arbitrary replacement
          if (ch == '/') ch = '~'; // arbitrary replacement
          if (ch >= 'A' && ch <= 'Z') ch += 32; // original WADs has all names uppercased
          ch = koi8from866Table.ptr[cast(ubyte)ch];
          //if (ch == '/' && (nbpos == 0 || name.ptr[nbpos-1] == '/')) continue;
          name.ptr[nbpos++] = ch;
        }
        name = name[0..nbpos];
        if (name.length && name[$-1] == '/') name = null;
      }
      // some sanity checks
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new /*VFSNamedException!"WadArchive"*/VFSExceptionArc("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new /*VFSNamedException!"WadArchive"*/VFSExceptionArc("invalid archive directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir.arrayAppendUnsafe(fi);
      }
    }
    buildNameHashTable();
  }
}
