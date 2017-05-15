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
module dumpdht is aliced;

import iv.btenc;


void main () {
  auto nfo = BTField.load("rtorrent.dht_cache");
  auto nodes = nfo["/nodes"];
  foreach (string id; nodes.vdict.byKey) {
    auto ni = id in nodes.vdict;
    auto ipnode = "i" in *ni;
    auto portnode = "p" in *ni;
    if (ipnode !is null && portnode !is null) {
      import std.stdio : writefln;
      uint ip = cast(uint)ipnode.vuint;
      ushort port = cast(ushort)portnode.vuint;
      writefln("%s.%s.%s.%s:%s", (ip>>24)&0xff, (ip>>16)&0xff, (ip>>8)&0xff, ip&0xff, port);
    }
  }
}
