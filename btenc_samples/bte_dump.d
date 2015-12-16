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
module dump;

import iv.btenc;


void dump (ref BTField fld, string indent="") {
  import iv.strex : quote;
  import std.stdio : writeln;
  if (fld.type == BTField.Type.UInt) {
    writeln(indent, "uint:<", fld.vuint, ">");
  } else if (fld.type == BTField.Type.Str) {
    writeln(indent, "str:<#", fld.vstr.length, ":", quote(fld.vstr), ">");
  } else if (fld.type == BTField.Type.List) {
    writeln(indent, "LIST");
    indent ~= " ";
    string ii = indent~" ";
    foreach (immutable idx; 0..fld.vlist.length) {
      writeln(indent, "#", idx);
      dump(fld.vlist[idx], ii);
    }
  } else if (fld.type == BTField.Type.Dict) {
    writeln(indent, "DICT");
    indent ~= " ";
    string ii = indent~" ";
    foreach (string k; fld.vdict.byKey) {
      writeln(indent, "[#", k.length, ":", quote(k), "]");
      dump(fld.vdict[k], ii);
    }
  } else {
    assert(0);
  }
}


void main (string[] args) {
  if (args.length != 2) assert(0);
  auto nfo = BTField.load(args[1]);
  dump(nfo);
}
