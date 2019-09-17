/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// used as mixin(import("test.d"));

void doTest(int sz, string HashName) (string str, ulong hh) {
  import std.stdio;

  enum HashStruct = HashName;
  enum HashFn = cast(char)(HashName[0]+32)~HashName[1..$]~sz.stringof;
  enum HashRes = ".result"~sz.stringof;

  if (mixin(HashFn~"(str)") != hh) {
    writeln(HashFn, sz, " fucked!");
    assert(0);
  }
  foreach_reverse (immutable len; 0..str.length) {
    {
      auto hs = mixin(HashStruct~"()");
      hs.put(str[0..len]);
      foreach (immutable pos; len..str.length) hs.put(str[pos]);
      auto res = mixin("hs"~HashRes);
      if (res != hh) {
        writeln(HashStruct, sz, "(", len, ") fucked!");
        assert(0);
      }
    }
    {
      auto h0 = mixin(HashFn~"(str[0..len])");
      auto h1 = mixin(HashStruct~"()");
      foreach (immutable pos; 0..len) h1.put(str[pos]);
      if (mixin("h1"~HashRes) != h0) {
        writeln(HashStruct, sz, "ByOne(", len, ") fucked!");
        assert(0);
      }
    }
  }
}
