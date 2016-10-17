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
import std.stdio;

import iv.vfs;

void main () {
  vfsRegister!"first"(new VFSDriverDiskListed("data")); // data dir, will be looked last
  vfsAddPak("data/base.pk3"); // disk name, will not be looked in VFS

  {
    auto fl = vfsOpenFile("./ztest00.d"); // disk name, will not be looked in VFS -- due to "./"
    writeln(fl.size);
    fl.seek(1);
    char[4] s;
    fl.rawReadExact(s[]);
    writeln(s);
    fl.close();
  }

  {
    auto fl = vfsOpenFile("shaders/srscanlines.frag");
    writeln(fl.size);
    writeln(fl.tell);
    fl.seek(1);
    char[4] s;
    fl.rawReadExact(s[]);
    writeln(s);
    writeln(fl.tell);
    fl.close();
  }

  {
    auto fl = vfsOpenFile("playpal.pal");
    writeln(fl.size);
    writeln(fl.tell);
    fl.seek(1);
    ubyte[3] s;
    fl.rawReadExact(s[]);
    writeln(fl.tell);
    assert(s[] == [0, 0, 7]);
    fl.close();
  }
}
