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

//import iv.encoding;


// ////////////////////////////////////////////////////////////////////////// //
uint getfmodtime (const(char)[] fname) {
  import core.sys.posix.sys.stat;
  import std.internal.cstring : tempCString;
  stat_t st;
  if (stat(fname.tempCString, &st) != 0) return 0;
  return st.st_mtime/*.tv_sec*/;
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
void doList (string[] args) {
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
    if (size < 0) {
      // brain-damaged dfwad
      size = 0;
    }
    writefln("-rw-r--r--    1 1000     100      %8s %s %s", size, tbuf[0..len], de.name[1..$]/*.recode("utf-8", "koi8-u")*/);
  });
}


// ////////////////////////////////////////////////////////////////////////// //
// archivename storedfilename extractto
void doExtract (string[] args) {
  auto buf = new ubyte[](1024*1024);

  if (args.length != 3) assert(0, "'copyout' command expect three args");
  vfsAddPak(args[0], "\x00");
  auto fi = VFile("\x00"~args[1]);
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
