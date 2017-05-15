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
module zytest is aliced;

//import core.runtime : Runtime;
//import std.string;

import iv.vfs.io;
import iv.cmdcon;
import iv.strex;
import iv.zymosis;

version(Zymosis_Testing) {} else static assert(0, "use -version=Zymosis_Testing to run test suite");

ZymCPU z80;
ubyte[65536] memory, memsave;


class MyZ80 : ZymCPU {
  this () {
    super();
  }

  override void setupMemory () {
    foreach (immutable idx; 0..65536/MemPage.Size) {
      mem[idx] = MemPage.default;
      mem[idx].mem = memory.ptr+idx*MemPage.Size;
    }
    //foreach (immutable idx; 0..16384/MemPage.Size) mem[idx].rom = true;
    //foreach (immutable idx; 0x4000..0x5B00) mem[idx/MemPage.Size].writeHook = true;
  }

  override void memContention (ushort addr, bool mreq) nothrow @trusted @nogc {
    conwritefln!"%5s MC %04x"(tstates, addr);
  }

  override void memReading (ushort addr) nothrow @trusted @nogc {
    conwritefln!"%5s MR %04x %02x"(tstates, addr, memory[addr]);
  }

  override void memWriting (ushort addr, ubyte b) nothrow @trusted @nogc {
    conwritefln!"%5s MW %04x %02x"(tstates, addr, b);
  }

  override ubyte portRead (ushort port) nothrow @trusted @nogc {
    conwritefln!"%5s PR %04x %02x"(tstates, port, port>>8);
    return port>>8;
  }

  override void portWrite (ushort port, ubyte value) nothrow @trusted @nogc {
    conwritefln!"%5s PW %04x %02x"(tstates, port, value);
  }

  override void portContention (ushort port, int atstates, bool doIN, bool early) nothrow @trusted @nogc {
    if (early) {
      if ((port&0xc000) == 0x4000) conwritefln!"%5s PC %04x"(tstates, port);
    } else {
      if (port&0x0001) {
        if ((port&0xc000) == 0x4000) {
          foreach (int f; 0..3) conwritefln!"%5s PC %04x"(tstates+f, port);
        }
      } else {
        conwritefln!"%5s PC %04x"(tstates, port);
      }
    }
    tstates += atstates;
  }
}


// null: error or done
private string read_test (VFile fl) {
  ubyte i, r;
  int i1, i2, im, hlt, ts;
  ushort af, bc, de, hl, afx, bcx, dex, hlx, ix, iy, sp, pc, memptr;
  bool done = true;
  int ch;
  string s;
  // read test description, skipping empty lines (useless)
  while (!fl.eof) {
    s = fl.readln().xstrip();
    if (s.length > 0) { done = false; break; }
  }
  if (fl.eof || done) return null;
  // read data for CPU
  z80.reset();
  z80.evenM1 = false;
  // registers
  fl.readf(" %x %x %x %x %x %x %x %x %x %x %x %x %x", &af, &bc, &de, &hl, &afx, &bcx, &dex, &hlx, &ix, &iy, &sp, &pc, &memptr);
  //writefln(":%04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x", af, bc, de, hl, afx, bcx, dex, hlx, ix, iy, sp, pc);
  z80.AF = af;
  z80.BC = bc;
  z80.DE = de;
  z80.HL = hl;
  z80.AFx = afx;
  z80.BCx = bcx;
  z80.DEx = dex;
  z80.HLx = hlx;
  z80.IX = ix;
  z80.IY = iy;
  z80.SP = sp;
  z80.PC = pc;
  z80.MEMPTR = memptr;
  // more registers and state
  fl.readf(" %x %x %s %s %s %s %s", &i, &r, &i1, &i2, &im, &hlt, &ts);
  //writefln(":%02x %02x %s %s %s %s %s", i, r, i1, i2, im, hlt, ts);
  z80.I = i;
  z80.R = r;
  z80.IFF1 = (i1 != 0);
  z80.IFF2 = (i2 != 0);
  z80.IM = cast(ubyte)im;
  z80.tstates = 0;
  z80.nextEventTS = ts;
  // prepare momory
  for (int f = 0; f < 65536; f += 4) {
    memory[f+0] = 0xde;
    memory[f+1] = 0xad;
    memory[f+2] = 0xbe;
    memory[f+3] = 0xef;
  }

  int readint () {
    char ch;
    bool neg;
    int res;
    for (;;) {
      if (fl.rawRead((&ch)[0..1]).length != 1) throw new Exception("out of data");
      if (ch >= ' ') break;
    }
    if (ch == '-') {
      neg = true;
      if (fl.rawRead((&ch)[0..1]).length != 1) throw new Exception("out of data");
    }
    for (;;) {
           if (ch >= '0' && ch <= '9') res = res*16+ch-'0';
      else if (ch >= 'A' && ch <= 'F') res = res*16+ch-'A'+10;
      else if (ch >= 'a' && ch <= 'f') res = res*16+ch-'a'+10;
      else {
        //{ import std.stdio; writeln("ch=", cast(ubyte)ch); }
        if (ch > ' ') throw new Exception("invalid data");
        break;
      }
      if (fl.rawRead((&ch)[0..1]).length == 0) break;
    }
    if (neg) res = -res;
    return res;
  }

  // read memory
  for (;;) {
    static import std.conv;
    int iv;
    ushort addr;
    /*
    try {
      fl.readf(" %x ", &iv);
    } catch (std.conv.ConvException e) {
      fl.readf(" %s ", &iv);
      //writeln(" eaddr=", iv);
      break;
    }
    */
    iv = readint();
    //writeln("iv=", iv);
    if (iv < 0) break;
    addr = cast(ushort)iv;
    for (;;) {
      /*
      try {
        fl.readf(" %x ", &iv);
      } catch (std.conv.ConvException e) {
        fl.readf(" %s ", &iv);
        //writeln(" eiv=", iv);
        break;
      }
      */
      iv = readint();
      //writeln(" byte=", iv);
      if (iv < 0) break;
      memory[addr++] = cast(ubyte)iv;
    }
  }
  for (int f = 0; f < 65536; ++f) memsave[f] = memory[f];
  return s;
}


private void dump_state () {
  conwritefln!"%04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x"(
    z80.AF, z80.BC, z80.DE, z80.HL, z80.AFx, z80.BCx, z80.DEx, z80.HLx, z80.IX, z80.IY, z80.SP, z80.PC, z80.MEMPTR);
  conwritefln!"%02x %02x %s %s %s %s %s"(z80.I, z80.R, (z80.IFF1 ? 1 : 0), (z80.IFF2 ? 1 : 0), z80.IM, (z80.halted ? 1 : 0), z80.tstates);
  for (int f = 0; f < 65536; ++f) {
    if (memory[f] != memsave[f]) {
      conwritef!"%04x "(cast(ushort)f);
      while (f < 65536 && memory[f] != memsave[f]) conwritef!"%02x "(memory[f++]);
      conwriteln("-1");
      --f;
    }
  }
  conwriteln();
}


void main (string[] args) {
  //version(DigitalMars) Runtime.traceHandlerAllowTrace = 1;
  string finame = "testdata/tests.in";
  if (args.length > 1) finame = args[1];
  z80 = new MyZ80();
  auto fl = VFile(finame);
  int count = 0;
  { import core.stdc.stdio; stderr.fprintf("running tests...\n"); }
  for (;;) {
    string title = read_test(fl);
    if (title is null) break;
    writeln(title);
    z80.exec();
    dump_state();
    ++count;
  }
  { import core.stdc.stdio; stderr.fprintf("%d tests complete.\n", count); }
}
