/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
// very simple (de)serializer to json-like text format
module iv.egtui.txtser is aliced;

static import iv.txtser;
public import iv.txtser : SRZIgnore, SRZName, SRZNonDefaultOnly;
private import iv.vfs.pred;

public void txtser(T, ST) (auto ref ST fl, in auto ref T v, int indent=0) if (!is(T == class) && isWriteableStream!ST) { iv.txtser.txtser(v, fl, indent); }
public void txtunser(T, ST) (auto ref ST fl, out T v) if (!is(T == class) && isReadableStream!ST) { iv.txtser.txtunser(v, fl); }
