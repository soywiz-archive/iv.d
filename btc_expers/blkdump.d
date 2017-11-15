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
bool parseBlock (MMapFile fl, ref uint ofs) {
  if (ofs >= fl.size) return false;
  auto fldata = fl[ofs..$];
  auto bdata = BtcBlock.getPackedData(fldata);
  ofs += BtcBlock.packedDataSize(fldata);
  auto blk = BtcBlock(bdata);
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
  auto txc = blk.txcount;
  //writeln("txc=", txc);
  foreach (immutable tidx; 0..txc) {
    auto txofs = blk.txofs(tidx);
    writeln("transaction #", tidx, "; version is ", blk.txver(txofs), "; inputs: ", blk.icount(txofs), "; outputs: ", blk.ocount(txofs), "; lock=", blk.locktime(txofs));
    if (blk.icount(txofs)) {
      writeln(" -- inputs --");
      foreach (immutable vidx; 0..blk.icount(txofs)) {
        auto v = blk.getInput(txofs, vidx);
        writeln("  #", vidx, ": vout=", v.vout, "; seq=", v.seq, "; script_length=", v.script.length, "; id=", v.id.bin2hex);
        //if (isAsciiScript(v.script)) writeln("      ", cast(const(char)[])v.script);
        //if (v.script > 8) writeln("      ", s2a(v.script));
      }
    }
    if (blk.ocount(txofs)) {
      writeln(" -- outputs --");
      foreach (immutable vidx; 0..blk.ocount(txofs)) {
        auto v = blk.getOutput(txofs, vidx);
        writeln("  #", vidx, ": value=", v.value, "; script_length=", v.script.length);
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
  uint ofs = 0;
  for (;;) {
    if (!parseBlock(fl, ofs)) break;
  }
}
