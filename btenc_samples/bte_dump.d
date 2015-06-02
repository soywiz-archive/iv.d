/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module dump;

import iv.btenc;


void dump (ref Field fld, string indent="") {
  import iv.strex : quote;
  import std.stdio : writeln;
  if (fld.type == Field.Type.UInt) {
    writeln(indent, "uint:<", fld.vuint, ">");
  } else if (fld.type == Field.Type.Str) {
    writeln(indent, "str:<#", fld.vstr.length, ":", quote(fld.vstr), ">");
  } else if (fld.type == Field.Type.List) {
    writeln(indent, "LIST");
    indent ~= " ";
    string ii = indent~" ";
    foreach (immutable idx; 0..fld.vlist.length) {
      writeln(indent, "#", idx);
      dump(fld.vlist[idx], ii);
    }
  } else if (fld.type == Field.Type.Dict) {
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
  auto nfo = Field.load(args[1]);
  dump(nfo);
}
