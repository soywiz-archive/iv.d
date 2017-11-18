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
module blkdump is aliced;

import iv.vfs.io;
import btcblk;


// ////////////////////////////////////////////////////////////////////////// //
// rev???.dat: magic[4], version[4], hash[32]


// ////////////////////////////////////////////////////////////////////////// //
bool isAsciiScript (const(ubyte)[] script) {
  if (script.length < 1) return false;
  foreach (immutable ubyte b; script) {
    if (b < 32) {
      if (b != 13 && b != 10 && b != 9) return false;
    } else if (b >= 127) {
      return false;
    }
  }
  return true;
}


string s2a (const(ubyte)[] script) {
  string res;
  res.reserve(script.length);
  foreach (char ch; cast(const(char)[])script) {
    if (ch < ' ' || ch >= 127) ch = '.';
    res ~= ch;
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
bool parseBlock (ref MemBuffer mbuf) {
  import std.range : enumerate;
  auto blk = BtcBlock(mbuf);
  // read block header
  auto hdr = blk.header;
  //hdr.bits = 0x1d001234;
  writeln("version: ", hdr.ver);
  writeln("time: ", hdr.time);
  writeln("prev: ", hdr.prev.bin2hex);
  writeln("root: ", hdr.root.bin2hex);
  //writeln("bits: ", hdr.bits2str);
  writeln("bits: ", hdr.decodeBits.bin2hex);
  //writeln("bits: ", hdr.bits);
  //writefln("bits: 0x%08x", hdr.bits);
  //assert(hdr.zero == 0);
  foreach (immutable tidx, const ref tx; blk[].enumerate) {
    writeln("transaction #", tidx, "; version is ", tx.ver, "; inputs: ", tx.incount, "; outputs: ", tx.outcount, "; lock=", tx.locktime);
    if (tx.incount > 0) {
      writeln(" -- inputs --");
      foreach (immutable vidx, const ref txin; tx.inputs.enumerate) {
        writeln("  #", vidx, ": vout=", txin.vout, "; seq=", txin.seq, "; script_length=", txin.script.length, "; id=", txin.id.bin2hex);
        //if (isAsciiScript(v.script)) writeln("      ", cast(const(char)[])v.script);
        //if (v.script > 8) writeln("      ", s2a(v.script));
      }
    }
    if (tx.outcount > 0) {
      writeln(" -- outputs --");
      foreach (immutable vidx, const ref txout; tx.outputs.enumerate) {
        writeln("  #", vidx, ": value=", txout.value, "; script_length=", txout.script.length);
        //if (isAsciiScript(v.script)) writeln("      ", cast(const(char)[])v.script);
        //if (v.script > 67) writeln("      ", s2a(v.script));
      }
    }
  }
  //writeln(fl.position-8);
  return true;
}



void main (string[] args) {
  assert(args.length > 1);
  auto fl = MMapFile(args[1]);
  auto mbuf = MemBuffer(fl[]);
  while (!mbuf.empty) {
    if (!parseBlock(mbuf)) break;
  }
}
