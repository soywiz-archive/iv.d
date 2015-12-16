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

import core.runtime : Runtime;
import std.stdio;
import std.string;

import iv.zymosis;


private ZymCPU z80;
private ubyte[65536] memory, memsave;


class MyZ80 : ZymCPU {
  this () {
    super();
    contended = true;
  }

  @trusted override ubyte memRead (ushort addr, MemIO mio) {
    if (mio != MemIO.Other) {
      writefln("%5d MR %04x %02x", tstates, addr, memory[addr]);
    }
    return memory[addr];
  }

  @trusted override void memWrite (ushort addr, ubyte value, MemIO mio) {
    if (mio != MemIO.Other) {
      writefln("%5d MW %04x %02x", tstates, addr, value);
    }
    memory[addr] = value;
  }

  override ubyte portRead (ushort port, PortIO pio) {
    if (pio != PortIO.INTERNAL) {
      writefln("%5d PR %04x %02x", tstates, port, port>>8);
    }
    return port>>8;
  }

  override void portWrite (ushort port, ubyte value, PortIO pio) {
    if (pio != PortIO.INTERNAL) {
      writefln("%5d PW %04x %02x", tstates, port, value);
    }
  }

  override void memContention (ushort addr, int atstates, MemIO mio, MemIOReq mreq) {
    writefln("%5d MC %04x", tstates, addr);
    tstates += atstates;
  }

  override void portContention (ushort port, int atstates, bool doIN, bool early) {
    if (early) {
      if ((port&0xc000) == 0x4000) writefln("%5d PC %04x", tstates, port);
    } else {
      if (port&0x0001) {
        if ((port&0xc000) == 0x4000) {
          for (int f = 0; f < 3; ++f) writefln("%5d PC %04x", tstates+f, port);
        }
      } else {
        writefln("%5d PC %04x", tstates, port);
      }
    }
    tstates += atstates;
  }
}


// null: error or done
private string read_test (ref File fl) {
  ubyte i, r;
  int i1, i2, im, hlt, ts;
  ushort af, bc, de, hl, afx, bcx, dex, hlx, ix, iy, sp, pc;
  bool done = true;
  int ch;
  string s;
  // read test description, skipping empty lines (useless)
  while (!fl.eof) {
    s = fl.readln().strip();
    if (s.length > 0) { done = false; break; }
  }
  if (fl.eof || done) return null;
  // read data for CPU
  z80.reset();
  z80.evenM1 = false;
  // registers
  fl.readf(" %x %x %x %x %x %x %x %x %x %x %x %x", &af, &bc, &de, &hl, &afx, &bcx, &dex, &hlx, &ix, &iy, &sp, &pc);
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
  // more registers and state
  fl.readf(" %x %x %d %d %d %d %d", &i, &r, &i1, &i2, &im, &hlt, &ts);
  //writefln(":%02x %02x %d %d %d %d %d", i, r, i1, i2, im, hlt, ts);
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
  // read memory
  for (;;) {
    static import std.conv;
    int iv;
    ushort addr;
    try {
      fl.readf(" %x ", &iv);
    } catch (std.conv.ConvException e) {
      fl.readf(" %d ", &iv);
      //writeln(" eaddr=", iv);
      break;
    }
    //writeln("iv=", iv);
    if (iv < 0) break;
    addr = cast(ushort)iv;
    for (;;) {
      try {
        fl.readf(" %x ", &iv);
      } catch (std.conv.ConvException e) {
        fl.readf(" %d ", &iv);
        //writeln(" eiv=", iv);
        break;
      }
      //writeln(" byte=", iv);
      if (iv < 0) break;
      memory[addr++] = cast(ubyte)iv;
    }
  }
  for (int f = 0; f < 65536; ++f) memsave[f] = memory[f];
  return s;
}


private void dump_state () {
  writefln("%04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x",
    z80.AF, z80.BC, z80.DE, z80.HL, z80.AFx, z80.BCx, z80.DEx, z80.HLx, z80.IX, z80.IY, z80.SP, z80.PC);
  writefln("%02x %02x %d %d %d %d %d", z80.I, z80.R, z80.IFF1, z80.IFF2, z80.IM, z80.halted, z80.tstates);
  for (int f = 0; f < 65536; ++f) {
    if (memory[f] != memsave[f]) {
      writef("%04x ", cast(ushort)f);
      while (f < 65536 && memory[f] != memsave[f]) writef("%02x ", memory[f++]);
      writeln("-1");
      --f;
    }
  }
  writeln();
}


void main (string[] args) {
  version(DigitalMars) Runtime.traceHandlerAllowTrace = 1;
  string finame = "testdata/tests.in";
  if (args.length > 1) finame = args[1];
  z80 = new MyZ80();
  auto fl = File(finame, "r");
  int count = 0;
  stderr.writeln("running tests...");
  for (;;) {
    string title = read_test(fl);
    if (title is null) break;
    writeln(title);
    z80.exec();
    dump_state();
    ++count;
  }
  stderr.writefln("%d tests complete.", count);
}
