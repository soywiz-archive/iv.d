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
module base58_test is aliced;

import iv.base58;
import iv.vfs.io;


void main () {
  enum keystr = "0C28FCA386C7A227600B2FE50B7CAE11EC86D3BF1FBE471BE89827E19D72AA1D";
  immutable ubyte[$] keybin = cast(immutable(ubyte)[])x"0C28FCA386C7A227600B2FE50B7CAE11EC86D3BF1FBE471BE89827E19D72AA1D";
  enum hexstr = "800C28FCA386C7A227600B2FE50B7CAE11EC86D3BF1FBE471BE89827E19D72AA1D507A5B8D";
  immutable ubyte[$] bindata = cast(immutable(ubyte)[])x"800C28FCA386C7A227600B2FE50B7CAE11EC86D3BF1FBE471BE89827E19D72AA1D507A5B8D";
  enum encetha = "5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ";

  auto checkenc = base58EncodeCheck(0x80, keybin);
  writeln(checkenc);
  assert(checkenc == encetha);

  ubyte pfxbyte;
  auto dec = base58DecodeCheck(checkenc);
  writeln(dec[0], "; len=", dec.length);
  assert(dec[1..$] == keybin[]);

  auto encdata = base58Encode(bindata);
  writeln(encdata);
  assert(encdata == encetha);

  auto decbin = base58Decode(encdata);
  writeln(decbin.length);
  string xst;
  foreach (immutable ubyte v; decbin[]) { import std.format : format; xst ~= "%02X".format(v); }
  writeln(xst);
  writeln(hexstr);
  assert(xst == hexstr);
}
