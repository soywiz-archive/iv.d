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

import btcblock;
import btcscript;


//version = dump_scripts;


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
    writeln("transaction #", tidx, "; version is ", tx.ver, "; inputs: ", tx.incount, "; outputs: ", tx.outcount, "; lock=", tx.locktime, "; datalen=", tx.data.length, "; txid=", tx.txid.bin2hex);
    if (tx.incount > 0) {
      writeln(" -- inputs --");
      foreach (immutable vidx, const ref txin; tx.inputs.enumerate) {
        writeln("  #", vidx, ": vout=", txin.vout, "; seq=", txin.seq, "; script_length=", txin.script.length, "; id=", txin.id.bin2hex);
        version(dump_scripts) {
          const(ubyte)[] sc = txin.script;
          if (sc.length) {
            uint ofs = 0;
            while (sc.length) {
              writefln("    %04X: %s", ofs, btsDecodeOne(sc));
              sc = sc[btsOpSize(sc)..$];
            }
          }
        }
      }
    }
    if (tx.outcount > 0) {
      writeln(" -- outputs --");
      foreach (immutable vidx, const ref txout; tx.outputs.enumerate) {
        writeln("  #", vidx, ": value=", txout.value, "; script_length=", txout.script.length);
        version(dump_scripts) {
          const(ubyte)[] sc = txout.script;
          if (sc.length) {
            uint ofs = 0;
            while (sc.length) {
              writefln("    %04X: %s", ofs, btsDecodeOne(sc));
              sc = sc[btsOpSize(sc)..$];
            }
          }
        }
      }
    }
  }
  //writeln(fl.position-8);
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
import core.time;

void main (string[] args) {
  assert(args.length > 1);
  auto fl = MMapFile(args[1]);
  auto mbuf = MemBuffer(fl[]);
  auto stt = MonoTime.currTime;
  int count = 0, total = 0;
  while (!mbuf.empty) {
    if (!parseBlock(mbuf)) break;
    ++total;
    if (++count >= 1024) {
      count = 0;
      auto ctt = MonoTime.currTime;
      if ((ctt-stt).total!"msecs" >= 1000) {
        stderr.write("\r", total, " blocks processed...");
        stt = ctt;
      }
    }
  }
  stderr.writeln("\r", total, " blocks processed...");
}
