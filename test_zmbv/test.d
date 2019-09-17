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
module zmbv_test /*is aliced*/;

import core.stdc.stdlib : malloc, free;
import core.stdc.string : memset, memcpy, memcmp;
import std.exception;
import std.getopt;
import std.path;
import std.stdio;
import std.string;

import iv.alice;
import iv.zmbv;


private:
////////////////////////////////////////////////////////////////////////////////
// each KeyframeInterval frame will be key one
enum KeyframeInterval = 300;


////////////////////////////////////////////////////////////////////////////////
string inname, outname;
File flScreen;
int screenCount;
ubyte[256*3] curPal = void;
ubyte[320*240] curScreen = void;
int frameNo;
bool thisIsKeyframe;
uint[] idxarray;

Codec.Compression cpr = Codec.Compression.ZLib;
int complevel = -1;


////////////////////////////////////////////////////////////////////////////////
void openVPF () {
  uint scc;
  flScreen = File(inname, "r");
  flScreen.rawRead((&scc)[0..1]);
  if (scc == 0) throw new Exception("invalid screen cound!");
  screenCount = scc;
  writefln("%s screens found", screenCount);
  frameNo = 0;
}


void closeVPF () {
  if (flScreen.isOpen) flScreen.close();
}


////////////////////////////////////////////////////////////////////////////////
// 4 bytes: screen count
// 768+320*240: screen
bool nextScreen () {
  if (frameNo < screenCount) {
    flScreen.rawRead(curPal);
    flScreen.rawRead(curScreen);
    ++frameNo;
    return true;
  }
  return false;
}


////////////////////////////////////////////////////////////////////////////////
void encodeScreens (void delegate (const(void)[] buf) writer) {
  auto zc = new Encoder(320, 240, Codec.bpp2format(8), complevel, cpr);
  auto zd = new Decoder(320, 240);
  scope(exit) { zc.clear(); zd.clear(); }
  frameNo = 0;
  uint oldprc = 999;
  while (nextScreen()) {
    thisIsKeyframe = ((frameNo-1)%KeyframeInterval == 0);
    zc.prepareFrame((thisIsKeyframe ? zc.PrepareFlags.Keyframe : zc.PrepareFlags.None), curPal);
    foreach (/*auto*/ y; 0..240) zc.encodeLine(curScreen[y*320..(y+1)*320]);
    auto written = zc.finishFrame();
    writer(written);
    zd.decodeFrame(written);
    ubyte fb = (cast(ubyte[])written)[0];
    if (fb&0x01) {
      enforce(zd.paletteChanged);
    } else {
      enforce(((fb&0x02) != 0) == zd.paletteChanged);
    }
    enforce(zd.palette == curPal);
    foreach (/*auto*/ y; 0..240) {
      auto line = zd.line(y);
      if (curScreen[y*320..(y+1)*320] != line[]) {
        writeln("\nframe ", frameNo, "; line ", y);
        foreach (/*auto*/ x; 0..320) {
          if (curScreen[y*320+x] != line[x]) {
            writefln(" x=%3s; orig=0x%02x; unp=0x%02x", x, curScreen[y*320+x], line[x]);
          }
        }
        assert(0);
      }
    }
    uint prc = 100*frameNo/screenCount;
    if (prc != oldprc) {
      stdout.writef("\r[%s/%s] %s%%", frameNo, screenCount, prc);
      stdout.flush();
      oldprc = prc;
    }
  }
  stdout.writefln("\r[%s/%s] %s%%", frameNo, screenCount, 100);
}


////////////////////////////////////////////////////////////////////////////////
void encodeScreensToBin () {
  auto fo = File(outname, "w");

  void writer (const(void)[] buf) {
    if (thisIsKeyframe) idxarray ~= cast(uint)fo.tell;
    uint size = cast(uint)buf.length;
    fo.rawWrite((&size)[0..1]);
    fo.rawWrite(buf);
  }

  uint scc = screenCount;
  // frame count
  fo.rawWrite((&scc)[0..1]);
  // idxarray count
  scc = 0;
  fo.rawWrite((&scc)[0..1]);
  // idxarray offset
  fo.rawWrite((&scc)[0..1]);
  encodeScreens(&writer);
  // write idxarray
  auto ipos = fo.tell;
  fo.rawWrite(idxarray);
  // update header
  fo.seek(4);
  scc = cast(uint)idxarray.length;
  fo.rawWrite((&scc)[0..1]);
  scc = cast(uint)ipos;
  fo.rawWrite((&scc)[0..1]);
}


////////////////////////////////////////////////////////////////////////////////
void main (string[] args) {
  getopt(args,
    std.getopt.config.caseSensitive,
    std.getopt.config.bundling,
    "z", &complevel,
    "Z", (string opt) { cpr = Codec.Compression.None; },
  );
  if (complevel > 9) throw new Exception("invalid compression level");
  if (args.length < 2) throw new Exception("input file name missing");
  if (args.length > 3) throw new Exception("too many file names");
  inname = args[1];
  if (args.length < 3) {
    outname = inname.setExtension(".zmbv");
  } else {
    outname = args[2].defaultExtension(".zmbv");
  }
  writefln("using compression level %s", complevel);
  openVPF();
  encodeScreensToBin();
  closeVPF();
}
