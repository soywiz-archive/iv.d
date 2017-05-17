// simple library for dealing with Ogg container
module zogg_test /*is aliced*/;

import iv.alice;
import zogg;


// ////////////////////////////////////////////////////////////////////////// //
import iv.cmdcon;
import iv.vfs;


//enum FileName = "/tmp/03/linda_karandashi_i_spichki.opus";
enum FileName = "/tmp/03/melodie_128.opus";


// ////////////////////////////////////////////////////////////////////////// //
import iv.encoding;

void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  //testOgg0();
  OggStream ost;
  ost.setup(VFile(args[1]));

  conwriteln("packet size: ", ost.packetLength);
  conwriteln("packet gran: ", ost.packetGranule);

  assert(ost.packetBos);
  assert(ost.packetBop);
  assert(ost.packetEop);
  if (ost.packetLength < 19) assert(0);
  enum OpusSign = "OpusHead";
  if (cast(char[])ost.packetData[0..OpusSign.length] != OpusSign) assert(0);
  assert(ost.packetData[8] == 1); // version

  conwriteln("bos: ", ost.packetBos);
  conwriteln("bop: ", ost.packetBop);
  conwriteln("eop: ", ost.packetEop);
  conwriteln("channels: ", ost.packetData[9]);
  conwriteln("pre-skip: ", ost.getMemInt!ushort(ost.packetData.ptr+10));
  conwriteln("rate: ", ost.getMemInt!uint(ost.packetData.ptr+12));
  conwriteln("gain: ", ost.getMemInt!ushort(ost.packetData.ptr+16));
  conwriteln("channel map: ", ost.packetData[18]);

  if (!ost.loadPacket()) assert(0);
  conwriteln("packet size: ", ost.packetLength);
  conwriteln("packet gran: ", ost.packetGranule);
  conwriteln("bos: ", ost.packetBos);
  conwriteln("bop: ", ost.packetBop);
  conwriteln("eop: ", ost.packetEop);

  /+
  enum VorbisSign = "vorbis";
  uint srate = 0;

  // first three packets should have granule of zero
  // granules are in samples (not multiplied by channel), and is set to last complete sample on this page
  // granule might be ulong.max for a page that has no packet end
  {
    //conwriteln(ost.ogg.seglen[0..ost.ogg.segments]);
    //assert(ost.ogg.length == 58); // per spec
    assert(ost.bos); // per spec
    assert(ost.granulepos == 0); // per spec
    auto ptype = ost.readNum!ubyte;
    conwriteln("packet type : ", ptype);
    assert(ptype == 1);
    foreach (char ch; VorbisSign) {
      assert(!ost.atPacketEnd);
      assert(ost.readNum!char == ch);
    }
    // version: 0
    // channels and sample rate must be >0
    // valid block shifts: [6..13]; bs0 should be <= bs1
    // framing bit must be nonzero
    assert(!ost.atPacketEnd);
    conwriteln("version     : ", ost.readNum!uint);
    assert(!ost.atPacketEnd);
    conwriteln("channels    : ", ost.readNum!ubyte);
    assert(!ost.atPacketEnd);
    srate = ost.readNum!uint;
    conwriteln("sample rate : ", srate);
    assert(srate > 0 && srate <= 192000); // no, really
    assert(!ost.atPacketEnd);
    conwriteln("max rate    : ", ost.readNum!uint);
    assert(!ost.atPacketEnd);
    conwriteln("nom rate    : ", ost.readNum!uint);
    assert(!ost.atPacketEnd);
    conwriteln("min rate    : ", ost.readNum!uint);
    assert(!ost.atPacketEnd);
    ubyte bss = ost.readNum!ubyte;
    conwriteln("block size 0: ", 1<<(bss&0x0f));
    conwriteln("block size 1: ", 1<<((bss>>4)&0x0f));
    //conwriteln(ost.bytesRead);
    assert(!ost.atPacketEnd);
    conwriteln("framing flag: ", ost.readNum!ubyte);
    //conwriteln(ost.bytesRead);
    conwriteln("end-of-packet: ", ost.atPacketEnd);
    conwriteln("end-of-page  : ", ost.atPageEnd);
    assert(ost.atPacketEnd == true);
    assert(ost.atPageEnd == true);
  }

  {
    auto ptype = ost.readNum!ubyte;
    conwriteln("packet type: ", ptype);
    assert(ptype == 3);
    assert(!ost.bos); // per spec
    assert(ost.granulepos == 0); // per spec
    foreach (char ch; VorbisSign) {
      assert(!ost.atPacketEnd);
      assert(ost.readNum!(char, true) == ch);
    }
    char[] vendor;
    vendor.length = ost.readNum!(uint, true);
    foreach (ref char ch; vendor) ch = ost.readNum!(char, true);
    conwriteln("vendor: <", vendor.recodeToKOI8, ">");
    auto cmtcount = ost.readNum!(uint, true);
    foreach (immutable _; 0..cmtcount) {
      char[] str;
      str.assumeSafeAppend;
      str.length = ost.readNum!(uint, true);
      foreach (ref char ch; str) ch = ost.readNum!(char, true);
      conwriteln("  <", str.recodeToKOI8, ">");
    }
    conwriteln("framing flag: ", ost.readNum!(ubyte, true));
    assert(ost.atPacketEnd == true);
  }

  //conwriteln("*: bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit, "; datapos=", ost.datapos, "; pgdatalength=", ost.pgdatalength, "; eopk=", ost.atPacketEnd, "; sgl=", ost.seglen[0..ost.segments], "; curseg=", ost.curseg, "; csp=", ost.cursegpos);
  {
    auto ptype = ost.readNum!ubyte;
    conwriteln("packet type: ", ptype);
    assert(ptype == 5);
    assert(!ost.bos); // per spec
    assert(ost.granulepos == 0); // per spec
    //conwriteln("0: bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit, "; datapos=", ost.datapos, "; pgdatalength=", ost.pgdatalength, "; eopk=", ost.atPacketEnd, "; sgl=", ost.seglen[0..ost.segments], "; curseg=", ost.curseg, "; csp=", ost.cursegpos);
    foreach (char ch; VorbisSign) {
      assert(!ost.atPacketEnd);
      assert(ost.readNum!char == ch);
    }
    //conwriteln("1: bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit, "; datapos=", ost.datapos, "; pgdatalength=", ost.pgdatalength, "; eopk=", ost.atPacketEnd, "; sgl=", ost.seglen[0..ost.segments], "; curseg=", ost.curseg, "; csp=", ost.cursegpos);
    ost.finishPacket();
    //conwriteln("2: bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit, "; datapos=", ost.datapos, "; pgdatalength=", ost.pgdatalength, "; eopk=", ost.atPacketEnd, "; sgl=", ost.seglen[0..ost.segments], "; curseg=", ost.curseg, "; csp=", ost.cursegpos);
    assert(ost.atPacketEnd == true);
    assert(!ost.eos);
  }
  //conwriteln("3: bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit, "; datapos=", ost.datapos, "; pgdatalength=", ost.pgdatalength, "; eopk=", ost.atPacketEnd, "; sgl=", ost.seglen[0..ost.segments], "; curseg=", ost.curseg, "; csp=", ost.cursegpos);
  assert(ost.atPageEnd == true); // per spec

  {
    // scan the file
    ulong maxgranule = 0;
    for (;;) {
      ubyte ptype;
      if (ost.read(&ptype, 1) != 1) break;
      auto gran = ost.granulepos;
      //conwriteln("0: gran=", gran, "; ptype=", ptype, "; bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit);
      //ost.finishPacket();
      ost.finishPage();
      //conwriteln("1: gran=", gran, "; ptype=", ptype, "; bytesRead=", ost.bytesRead, "; newpos=", ost.newpos, "; eof=", ost.eofhit);
      if (/*ost.atPageEnd && (ptype&0x01) == 0 &&*/ cast(long)gran > 0) {
        maxgranule = gran;
        //auto secs = maxgranule/srate;
        //conwritefln!"%s:%02s"(secs/60, secs%60);
      }
    }
    {
      auto secs = maxgranule/srate;
      conwritefln!"%s:%02s"(secs/60, secs%60);
    }
  }
  +/
}
