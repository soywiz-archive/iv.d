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
module mkziptest is aliced;

import iv.strex;
import iv.vfs.io;
import iv.vfs.writers.zip;


void main (string[] args) {
  auto method = ZipWriter.Method.Deflate;

  for (usize idx = 1; idx < args.length;) {
    string arg = args[idx];
    if (arg == "--") {
      import std.algorithm : remove;
      args = args.remove(idx);
      break;
    }
    if (arg.length == 0) {
      import std.algorithm : remove;
      args = args.remove(idx);
      continue;
    }
    if (arg[0] == '-') {
      switch (arg) {
        case "--lzma": method = ZipWriter.Method.Lzma; break;
        case "--store": method = ZipWriter.Method.Store; break;
        case "--deflate": method = ZipWriter.Method.Deflate; break;
        default: writeln("invalid argument: '", arg, "'"); throw new Exception("boom");
      }
      import std.algorithm : remove;
      args = args.remove(idx);
      continue;
    }
    ++idx;
  }

  if (args.length < 2) {
    writeln("usage: mkziptest arc.zip [files...]");
    throw new Exception("boom");
  }

  auto fo = VFile(args[1], "w");

  auto zw = new ZipWriter(fo);
  scope(failure) if (zw.isOpen) zw.abort();

  if (args.length == 2) {
    vfsRegister!"first"(new VFSDriverDiskListed(".", true)); // data dir, will be looked last
    foreach (const ref de; vfsAllFiles()) {
      if (de.name.endsWithCI(".zip")) continue;
      writeln(de.name);
      zw.pack(VFile(de.name), de.name, ZipFileTime(de.modtime), method);
    }
  } else {
    foreach (string fname; args[2..$]) {
      import std.file;
      import std.datetime;
      writeln(fname);
      zw.pack(VFile(fname), fname, ZipFileTime(fname.timeLastModified.toUTC.toUnixTime()), method);
    }
  }

  zw.finish();
}
