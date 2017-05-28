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
// simple extfs for midnight commander
/* add the following to mc.ext:
# wad, pak, abuse .spe
regex/\.([Ww][Aa][Dd]|[Pp][Aa][Kk]|[Ss][Pp][Ee])$
  Open=%cd %p/uwad://
  View=%view{ascii} /opt/mc/libexec/mc/extfs.d/uwad list %f
*/
import iv.vfs.io;

import iv.vfs.arc.abuse;
import iv.vfs.arc.arcanum;
import iv.vfs.arc.arcz;
import iv.vfs.arc.bsa;
import iv.vfs.arc.dfwad; // just get lost
//import iv.vfs.arc.dunepak; no signature
//import iv.vfs.arc.f2dat; // no signature
//import iv.vfs.arc.toeedat; // conflicts with arcanum
import iv.vfs.arc.wad2;

import iv.strex;
import iv.utfutil;

version = dfwad_deep_scan;


// ////////////////////////////////////////////////////////////////////////// //
uint getfmodtime (const(char)[] fname) {
  import core.sys.posix.sys.stat;
  import std.internal.cstring : tempCString;
  stat_t st;
  if (stat(fname.tempCString, &st) != 0) return 0;
  return st.st_mtime/*.tv_sec*/;
}


const(char)[] removeExtension (const(char)[] fn) {
  foreach_reverse (immutable cidx, char ch; fn) {
    if (ch == '/') break;
    if (ch == '.') { fn = fn[0..cidx]; break; }
  }
  return fn;
}


// ////////////////////////////////////////////////////////////////////////// //
// try to guess targa by validating some header fields
bool guessTarga (const(ubyte)[] buf) {
  if (buf.length < 45) return false; // minimal 1x1 tga
  immutable ubyte idlength = buf.ptr[0];
  immutable ubyte bColorMapType = buf.ptr[1];
  immutable ubyte type = buf.ptr[2];
  immutable ushort wColorMapFirstEntryIndex = cast(ushort)(buf.ptr[3]|(buf.ptr[4]<<8));
  immutable ushort wColorMapLength = cast(ushort)(buf.ptr[5]|(buf.ptr[6]<<8));
  immutable ubyte bColorMapEntrySize = buf.ptr[7];
  immutable ushort wOriginX = cast(ushort)(buf.ptr[8]|(buf.ptr[9]<<8));
  immutable ushort wOriginY = cast(ushort)(buf.ptr[10]|(buf.ptr[11]<<8));
  immutable ushort wImageWidth = cast(ushort)(buf.ptr[12]|(buf.ptr[13]<<8));
  immutable ushort wImageHeight = cast(ushort)(buf.ptr[14]|(buf.ptr[15]<<8));
  immutable ubyte bPixelDepth = buf.ptr[16];
  immutable ubyte bImageDescriptor = buf.ptr[17];
  if (wImageWidth < 1 || wImageHeight < 1 || wImageWidth > 32000 || wImageHeight > 32000) return false; // arbitrary limit
  immutable uint pixelsize = (bPixelDepth>>3);
  switch (type) {
    case 2: // truecolor, raw
    case 10: // truecolor, rle
      switch (pixelsize) {
        case 2: case 3: case 4: break;
        default: return false;
      }
      break;
    case 1: // paletted, raw
    case 9: // paletted, rle
      if (pixelsize != 1) return false;
      break;
    case 3: // b/w, raw
    case 11: // b/w, rle
      if (pixelsize != 1 && pixelsize != 2) return false;
      break;
    default: // invalid type
      return false;
  }
  // check for valid colormap
  switch (bColorMapType) {
    case 0:
      if (wColorMapFirstEntryIndex != 0 || wColorMapLength != 0) return 0;
      break;
    case 1:
      if (bColorMapEntrySize != 15 && bColorMapEntrySize != 16 && bColorMapEntrySize != 24 && bColorMapEntrySize != 32) return false;
      if (wColorMapLength == 0) return false;
      break;
    default: // invalid colormap type
      return false;
  }
  if (((bImageDescriptor>>6)&3) != 0) return false;
  // this *looks* like a tga
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/*
AAAAAAA NNN OOOOOOOO GGGGGGGG SSSSSSSS DATETIME [PATH/]FILENAME [-> [PATH/]FILENAME[/]]]

where (things in [] are optional):

AAAAAAA  is the permission string like in ls -l
NNN      is the number of links
OOOOOOOO is the owner (either UID or name)
GGGGGGGG is the group (either GID or name)
SSSSSSSS is the file size
FILENAME is the filename
PATH     is the path from the archive's root without the leading slash (/)
DATETIME has one of the following formats:
      Mon DD hh:mm, Mon DD YYYY, Mon DD YYYY hh:mm, MM-DD-YYYY hh:mm

            where Mon is a three letter English month name, DD is day
            1-31, MM is month 01-12, YYYY is four digit year, hh hour is
            and mm is minute.

If the -> [PATH/]FILENAME part is present, it means:

If permissions start with an l (ell), then it is the name that symlink
points to. (If this PATH starts with a MC vfs prefix, then it is a symlink
somewhere to the other virtual filesystem (if you want to specify path from
the local root, use local:/path_name instead of /path_name, since /path_name
means from root of the archive listed).

If permissions do not start with l, but number of links is greater than one,
then it says that this file should be a hardlinked with the other file.
*/
// archivename
void doList(bool extended=false) (string[] args) {
  if (args.length != 1) assert(0, "'list' command expect one arg");
  vfsAddPak(args[0], "\x00");

  auto arctime = getfmodtime(args[0]);

  vfsForEachFile((in ref de) {
    //writefln("%10s %10s  %s", de.size, de.stat("pksize").get!long, de.name);
    if (de.name.length < 2 || de.name[0] != '\x00') return;
    //AAAAAAA NNN OOOOOOOO GGGGGGGG SSSSSSSS DATETIME [PATH/]FILENAME [-> [PATH/]FILENAME[/]]]
    auto timevar = de.stat("modtime");
    uint timev = (timevar.isInteger ? timevar.get!uint : arctime);
    import core.stdc.time;
    char[1024] tbuf;
    auto tm = localtime(cast(int*)&timev);
    auto len = strftime(tbuf.ptr, tbuf.length, "%m/%d/%Y %H:%M:%S", tm);
    long size = de.size;
    string name = de.name[1..$]/*.recode("utf-8", "koi8-u")*/;
    // fix all-upper
    bool allupper = true;
    foreach (char ch; name) if (koi8toupperTable[ch] != ch) { allupper = false; break; }
    if (allupper) {
      string t;
      foreach (char ch; name) t ~= koi8tolowerTable[ch];
      name = t;
    }

    if (size < 0) {
      // brain-damaged dfwad
      size = 0;
      version(dfwad_deep_scan) {
        try {
          auto fl = VFile(de.name);
          size = fl.size;
          do {
            char[1024] xbuf;
            // try text
            if (name == "interscript" || name == "text/anim") {
              bool good = true;
              iniloop: for (;;) {
                auto rd = fl.rawRead(xbuf[]);
                if (rd.length == 0) break;
                foreach (char ch; rd) {
                  if (ch < ' ') {
                    if (ch != '\t' && ch != '\n' && ch != '\r') { good = false; break iniloop; }
                  } else if (ch == 127) { good = false; break iniloop; }
                }
              }
              if (good) { name ~= ".ini"; break; }
            }
            if (size > 6) {
              auto buf = xbuf[0..6];
              fl.seek(0);
              fl.rawReadExact(buf[]);
              if (buf == "DFWAD\x01") { name ~= ".wad"; break; }
              if (buf[] == "\x89PNG\x0d\x0a") { name ~= ".png"; break; }
              if (buf[0..4] == "OggS") { name ~= ".ogg"; break; }
              if (buf[0..4] == "fLaC") { name ~= ".flac"; break; }
              if (buf[0..4] == "RIFF" && size > 16) {
                fl.rawReadExact(xbuf[0..10]);
                if (xbuf[2..10] == "WAVEfmt ") { name ~= ".wav"; break; }
              }
              if (buf[0..4] == "MAP\x01") { name ~= ".map"; break; }
              if (buf[0..4] == "ID3\x02") { name ~= ".mp3"; break; }
              if (buf[0..4] == "ID3\x03") { name ~= ".mp3"; break; }
              if (buf[0..4] == "ID3\x04") { name ~= ".mp3"; break; }
              if (buf[0..4] == "IMPM") { name ~= ".it"; break; } // impulse tracker
              if (buf[0..4] == "MThd") { name ~= ".mid"; break; }
            }
            if (size > 16) {
              auto buf = xbuf[0..16];
              fl.seek(0);
              fl.rawReadExact(buf[]);
              if (buf == "Extended Module:") { name ~= ".xm"; break; }
            }
            if (size > 18) {
              auto buf = xbuf[0..18];
              fl.seek(-18, Seek.End);
              fl.rawReadExact(buf[]);
              if (buf == "TRUEVISION-XFILE\x2e\x00") { name ~= ".tga"; break; }
            }
            if (size > 1024) {
              auto buf = xbuf[0..640];
              fl.seek(-640, Seek.End);
              fl.rawReadExact(buf[]);
              if (buf.indexOf("LAME3.") >= 0) { name ~= ".mp3"; break; }
              if (buf[$-128..$-128+3] == "TAG") { name ~= ".mp3"; break; }
            }
            // try hard to guess targa
            if (size >= 45) {
              auto buf = cast(ubyte[])xbuf[0..45];
              fl.seek(0);
              fl.rawReadExact(buf[]);
              if (guessTarga(buf[])) { name ~= ".tga"; break; }
            }
          } while (false);
        } catch (Exception e) {}
      }
    }

    /*
    auto arcname = de.stat("arcname");
    if (arcname.isString && arcname.get!string == "dfwad") {
      // fix all-upper
      string t;
      foreach (char ch; name) t ~= koi8tolowerTable[ch];
      name = t;
    }
    */
    static if (!extended) {
      writefln("-rw-r--r--    1 1000     100      %8s %s %s", size, tbuf[0..len], name);
    } else {
      writefln("[%s] -rw-r--r--    1 1000     100      %8s %s %s", de.stat("arcname"), size, tbuf[0..len], name);
    }
  });
}


// ////////////////////////////////////////////////////////////////////////// //
// archivename storedfilename extractto
void doExtract (string[] args) {
  auto buf = new ubyte[](1024*1024);

  if (args.length != 3) assert(0, "'copyout' command expect three args");
  vfsAddPak(args[0], "\x00");
  VFile fi;
  try {
    fi = VFile("\x00"~args[1]);
  } catch (Exception e) {
    version(dfwad_deep_scan) {
      // try w/o extension
      fi = VFile("\x00"~args[1].removeExtension);
    } else {
      throw e;
    }
  }
  auto fo = VFile(args[2], "w");
  for (;;) {
    auto rd = fi.rawRead(buf);
    if (rd.length == 0) break;
    fo.rawWriteExact(rd);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
int main (string[] args) {
  //if (args.length == 1) args ~= ["list", "Twzone.wad"];

  if (args.length == 1) assert(0, "command?");

  switch (args[1]) {
    case "list": // list archivename
      doList(args[2..$]);
      return 0;
    case "list_ex": // list archivename
      doList!true(args[2..$]);
      return 0;
    case "copyout": // copyout archivename storedfilename extractto
      doExtract(args[2..$]);
      return 0;
    case "copyin": // copyin archivename storedfilename sourcefile
    case "rm": // rm archivename storedfilename
    case "mkdir": // mkdir archivename dirname
    case "rmdir": // rmdir archivename dirname
    case "run": // ???
      return -1; // not implemented
    default: assert(0, "invalid command: '"~args[1]~"'");
  }
  return -1;
}
