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
module iv.vfs.arcs.wad;

import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
private import iv.vfs.arcs.internal : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"Wad");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverWad : VFSDriver {
  private import iv.vfs.arcs.internal : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    static immutable string[16] mapfiles = [
      "things", "linedefs", "sidedefs", "vertexes", "segs", "ssectors", "nodes", "sectors", "reject", "blockmap",
      "behavior", "scripts", "textmap", "znodes", "dialogue", "endmap"];
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
      // ExMx?
      if (s.length == 4) {
        if (s[0] != 'E' || s[2] != 'M') return false;
        if (s[1] < '0' || s[1] > '9') return false;
        if (s[3] < '0' || s[3] > '9') return false;
        return true;
      }
      // MAPxx
      if (s.length == 5) {
        if (s[0..3] != "MAP") return false;
        foreach (char ch; s[3..$]) if (ch < '0' || ch > '9') return false;
        return true;
      }
      return false;
    }
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"WadArchive"("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "IWAD" && sign != "PWAD") throw new VFSNamedException!"WadArchive"("not a WAD file");
    auto flCount = fl.readNum!uint;
    auto dirOfs = fl.readNum!uint;
    if (flCount == 0) return;
    if (flCount > 0x3fff_ffff || dirOfs >= flsize || dirOfs+flCount*16 > flsize) throw new VFSNamedException!"WadArchive"("invalid archive file");
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
          s ~= ch;
        }
        s ~= '/';
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
          if (ch == 0) break;
          if (ch == '\\') ch = '#'; // arbitrary replacement
          if (ch == '/') ch = '~'; // arbitrary replacement
          if (ch >= 'A' && ch <= 'Z') ch += 32; // original WADs has all names uppercased
          //if (ch == '/' && (nbpos == 0 || name.ptr[nbpos-1] == '/')) continue;
          name.ptr[nbpos++] = ch;
        }
        name = name[0..nbpos];
        if (name.length && name[$-1] == '/') name = null;
      }
      // some sanity checks
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new VFSNamedException!"WadArchive"("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new VFSNamedException!"WadArchive"("invalid archive directory");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir ~= fi;
      }
    }
  }
}
