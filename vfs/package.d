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
module iv.vfs;

static if (!is(typeof(object.usize))) {
  package alias usize = size_t;
} else {
  package import object : usize;
}

static if (!is(typeof(object.ssize))) {
       static if (usize.sizeof == 8) package alias ssize = long;
  else static if (usize.sizeof == 4) package alias ssize = int;
  else static assert(0, "wtf?!");
} else {
  package import object : ssize;
}


private import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;
public enum Seek : int {
  Set = SEEK_SET,
  Cur = SEEK_CUR,
  End = SEEK_END,
}


public import iv.vfs.error;
public import iv.vfs.augs;
public import iv.vfs.vfile;
public import iv.vfs.main;
public import iv.vfs.arcs;
