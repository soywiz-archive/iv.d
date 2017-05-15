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
module iv.follin.ftrick is aliced;

import iv.follin.cmacro;

version = follin_use_float_trick;


version(follin_use_float_trick) {
  //k8: actually, this is only marginally faster than using `lrintf()`, but...
  align(1) union TrickyFloatUnion {
  align(1):
    float f;
    int i;
  }
  enum declfcvar(string name) = "TrickyFloatUnion "~name~" = void;";
  static assert(TrickyFloatUnion.i.sizeof == 4 && TrickyFloatUnion.f.sizeof == 4);
  // add (1<<23) to convert to int, then divide by 2^SHIFT, then add 0.5/2^SHIFT to round
  //#define check_endianness()
  enum MAGIC(string SHIFT) = q{(1.5f*(1<<(23-${SHIFT}))+0.5f/(1<<${SHIFT}))}.cmacroFixVars!("SHIFT")(SHIFT);
  enum ADDEND(string SHIFT) = q{(((150-${SHIFT})<<23)+(1<<22))}.cmacroFixVars!("SHIFT")(SHIFT);
  enum FAST_SCALED_FLOAT_TO_INT(string x, string s) = q{temp.f = (${x})+${MAGIC}; int v = temp.i-${ADDEND};}
    .cmacroFixVars!("x", "s", "MAGIC", "ADDEND")(x, s, MAGIC!(s), ADDEND!(s));
} else {
  enum declfcvar(string name) = "{}";
  template FAST_SCALED_FLOAT_TO_INT(string x, string s) {
    static assert(s == "15");
    enum FAST_SCALED_FLOAT_TO_INT = q{import core.stdc.math : lrintf; int v = lrintf((${x})*32768.0f);}.cmacroFixVars!"x"(x);
  }
}
