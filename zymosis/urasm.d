/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * URASM: Z80 assembler/disassembler engine v0.0.2b
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
module iv.zymosis.urasm;

//version = urasm_test;


// ////////////////////////////////////////////////////////////////////////// //
enum URMnemo {
  ADC,  ADD,  AND,  BIT,
  CALL, CCF,  CP,   CPD,
  CPDR, CPI,  CPIR, CPL,
  DAA,  DEC,  DI,   DJNZ,
  EI,   EX,   EXX,  HALT,
  IM,   IN,   INC,  IND,
  INDR, INI,  INIR, JP,
  JR,   LD,   LDD,  LDDR,
  LDI,  LDIR, NEG,  NOP,
  OR,   OTDR, OTIR, OUT,
  OUTD, OUTI, POP,  PUSH,
  RES,  RET,  RETI, RETN,
  RL,   RLA,  RLC,  RLCA,
  RLD,  RR,   RRA,  RRC,
  RRCA, RRD,  RST,  SBC,
  SCF,  SET,  SLA,  SLI,
  SLL,  SRA,  SRL,  SUB,
  XOR,  XSLT, NOPX, NOPY,
}

// all possible operands
// there are so many for proper assembling
// (i wanted to do a simple table lookup w/o special cases, so all special cases were encoded as various operand types)
enum UROpType {
  NONE,
  IMM8,   // immediate constant
  IMM16,  // immediate constant
  ADDR16, // immediate address (JP/CALL)
  ADDR8,  // immediate address (JR/DJNZ)
  MEM16,  // immediate memory (nnnn)
  // 8 bit registers (bits 0-2 of opcode)
  R8,     // B,C,D,E,H,L,(HL),A
  R8NOM, // B,C,D,E,H,L,A (no (HL) )
  // 8 bit registers (bits 3-5 of opcode)
  R83,    // B,C,D,E,H,L,(HL),A
  R83NOM,// B,C,D,E,H,L,A (no (HL) )
  // for port i/o
  PORTC,  // (C)
  PORTIMM,// (nn)
  // special 8 bit registers
  R8XH,  // XH
  R8XL,  // XL
  R8YH,  // YH
  R8YL,  // YL
  R8A,   // A
  R8R,   // R
  R8I,   // I
  // 16 bit registers (bits 4-5 of opcode)
  R16,    // BC,DE,HL,SP
  // 16 bit registers (bits 4-5 of opcode)
  R16A,   // BC,DE,HL,AF
  // AF & AF' for EX AF,AF'
  R16AF,  // AF
  R16AFX, // AF'
  R16BC,  // BC
  R16DE,  // DE
  R16HL,  // HL
  R16IX,  // IX
  R16IY,  // IY
  R16SP,  // SP
  MSP,    // (SP)
  MBC,    // (BC)
  MDE,    // (DE)
  MHL,    // (HL)
  MIX,    // (IX+disp)
  MIY,    // (IY+disp)
  MIX0,   // (IX)
  MIY0,   // (IY)
  // JR condition (bits 3-4 of opcode)
  JRCOND,
  // conditions (bits 3-5 of opcode)
  COND,
  // CB opcodes -- bit numbers (bits 3-5 of opcode)
  BITN,   // 0..7
  // RST address (bits 3-5 of opcode <-- (address shr 3))
  RSTDEST,
  // IM operands
  IM0,   // not necessary for IM, denotes any 0
  IM1,   // not necessary for IM, denotes any 1
  IM2    // not necessary for IM, denotes any 2
  //IM01   // undocumented IM 0/1
}

// ////////////////////////////////////////////////////////////////////////// //
alias URFindLabelByAddrCB = const(char)[] delegate (ushort addr);
alias URGetByteCB = ubyte delegate (ushort addr);


///
struct URDisState {
public:
  bool decimal; /// use decimal numbers in output?

private:
  char[128] buf;
  uint bufpos;
  const(char)[] mnem;
  const(char)[][3] ops; // operands
  int iidx = -1;

public:
  void clear () pure nothrow @trusted @nogc { bufpos = 0; mnem = null; ops[] = null; iidx = 0; }

  @property bool valid () const pure nothrow @trusted @nogc { pragma(inline, true); return (bufpos > 0); }

  /// get disassembled text; mnemonic delimited by '\t'
  const(char)[] getbuf () const pure nothrow @trusted @nogc { pragma(inline, true); return buf[0..bufpos]; }

  /// get mnemonic text
  const(char)[] getmnemo () const pure nothrow @trusted @nogc { pragma(inline, true); return mnem; }

  /// get operand text
  const(char)[] getop (int idx) const pure nothrow @trusted @nogc { pragma(inline, true); return (idx >= 0 && idx < 3 ? ops.ptr[idx] : null); }

  /// get instruction index into `URInstructionsTable`
  int itableidx () const pure nothrow @trusted @nogc { pragma(inline, true); return iidx; }

private:
  void resetbuf () nothrow @trusted @nogc { bufpos = 0; }

  void put (const(char)[] s...) nothrow @trusted @nogc {
    if (s.length > buf.length) s = s[0..buf.length];
    if (bufpos+cast(uint)s.length > buf.length) s = s[0..buf.length-bufpos];
    if (s.length == 0) return;
    buf[bufpos..bufpos+s.length] = s[];
    bufpos += cast(uint)s.length;
  }

  void putnum(T) (string fmt, T n) nothrow @trusted @nogc {
    import core.stdc.stdio : snprintf;
    if (fmt.length > 32) assert(0, "wtf?!");
    char[33] fmtbuf = 0;
    char[33] destbuf = 0;
    fmtbuf[0..fmt.length] = fmt[];
    static if (T.sizeof <= 4) {
      static if (__traits(isUnsigned, T)) {
        auto len = snprintf(destbuf.ptr, destbuf.length, fmtbuf.ptr, cast(uint)n);
      } else {
        auto len = snprintf(destbuf.ptr, destbuf.length, fmtbuf.ptr, cast(int)n);
      }
    } else {
      static assert(0, "wtf?!");
    }
    if (len < 0) assert(0, "wtf?!");
    put(destbuf[0..len]);
  }

  void putxnum(T) (string fmth, string fmtd, T n) nothrow @trusted @nogc {
    putnum!T((decimal ? fmtd : fmth), n);
  }
}


static immutable string[URMnemo.max+1] URMnemonics = [
  "ADC", "ADD", "AND", "BIT", "CALL","CCF", "CP",  "CPD",
  "CPDR","CPI", "CPIR","CPL", "DAA", "DEC", "DI",  "DJNZ",
  "EI",  "EX",  "EXX", "HALT","IM",  "IN",  "INC", "IND",
  "INDR","INI", "INIR","JP",  "JR",  "LD",  "LDD", "LDDR",
  "LDI", "LDIR","NEG", "NOP", "OR",  "OTDR","OTIR","OUT",
  "OUTD","OUTI","POP", "PUSH","RES", "RET", "RETI","RETN",
  "RL",  "RLA", "RLC", "RLCA","RLD", "RR",  "RRA", "RRC",
  "RRCA","RRD", "RST", "SBC", "SCF", "SET", "SLA", "SLI",
  "SLL", "SRA", "SRL", "SUB", "XOR", "XSLT","NOPX","NOPY",
];

// various things...
static immutable string[8] URRegs8 = ["B","C","D","E","H","L","(HL)","A"];
static immutable string[4] URRegs16 = ["BC","DE","HL","SP"];
static immutable string[4] URRegs16a = ["BC","DE","HL","AF"];
static immutable string[8] URCond = ["NZ","Z","NC","C","PO","PE","P","M"];

///
struct URAsmCmdInfo {
  URMnemo mnemo; ///
  uint code; /// Z80 machine code
  uint mask; /// mask (for disassembler)
  UROpType[3] ops; ///
}

// the longest matches must come first (for disassembler)
// solid-masked must come first (for disassembler)
// assembler searches the table from the last command
// disassembler searches the table from the first command
// heh, i spent a whole night creating this shit! %-)
static immutable URAsmCmdInfo[358] URInstructionsTable = [
  URAsmCmdInfo(URMnemo.NOPX, 0x000000DDU, 0x00000000U, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.NOPY, 0x000000FDU, 0x00000000U, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  // DD/CB opcodes (special)
  // RLC (IX+d)
  URAsmCmdInfo(URMnemo.RLC, 0x0600CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // RRC (IX+d)
  URAsmCmdInfo(URMnemo.RRC, 0x0E00CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // RL (IX+d)
  URAsmCmdInfo(URMnemo.RL, 0x1600CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // RR (IX+d)
  URAsmCmdInfo(URMnemo.RR, 0x1E00CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SLA (IX+d)
  URAsmCmdInfo(URMnemo.SLA, 0x2600CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SRA (IX+d)
  URAsmCmdInfo(URMnemo.SRA, 0x2E00CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SLL (IX+d)
  URAsmCmdInfo(URMnemo.SLL, 0x3600CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SLI (IX+d)
  URAsmCmdInfo(URMnemo.SLI, 0x3600CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SRL (IX+d)
  URAsmCmdInfo(URMnemo.SRL, 0x3E00CBDDU, 0xFF00FFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // RES n,(IX+d)
  URAsmCmdInfo(URMnemo.RES, 0x8600CBDDU, 0xC700FFFFU, [UROpType.BITN, UROpType.MIX, UROpType.NONE]),
  // SET n,(IX+d)
  URAsmCmdInfo(URMnemo.SET, 0xC600CBDDU, 0xC700FFFFU, [UROpType.BITN, UROpType.MIX, UROpType.NONE]),
  // FD/CB opcodes (special)
  // RLC (IY+d)
  URAsmCmdInfo(URMnemo.RLC, 0x0600CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // RRC (IY+d)
  URAsmCmdInfo(URMnemo.RRC, 0x0E00CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // RL (IY+d)
  URAsmCmdInfo(URMnemo.RL, 0x1600CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // RR (IY+d)
  URAsmCmdInfo(URMnemo.RR, 0x1E00CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SLA (IY+d)
  URAsmCmdInfo(URMnemo.SLA, 0x2600CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SRA (IY+d)
  URAsmCmdInfo(URMnemo.SRA, 0x2E00CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SLL (IY+d)
  URAsmCmdInfo(URMnemo.SLL, 0x3600CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SLI (IY+d)
  URAsmCmdInfo(URMnemo.SLI, 0x3600CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SRL (IY+d)
  URAsmCmdInfo(URMnemo.SRL, 0x3E00CBFDU, 0xFF00FFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // RES n,(IY+d)
  URAsmCmdInfo(URMnemo.RES, 0x8600CBFDU, 0xC700FFFFU, [UROpType.BITN, UROpType.MIY, UROpType.NONE]),
  // SET n,(IY+d)
  URAsmCmdInfo(URMnemo.SET, 0xC600CBFDU, 0xC700FFFFU, [UROpType.BITN, UROpType.MIY, UROpType.NONE]),

  // DD/CB opcodes
  // RLC (IX+d),r8
  URAsmCmdInfo(URMnemo.RLC, 0x0000CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // RRC (IX+d),r8
  URAsmCmdInfo(URMnemo.RRC, 0x0800CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // RL (IX+d),r8
  URAsmCmdInfo(URMnemo.RL, 0x1000CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // RR (IX+d),r8
  URAsmCmdInfo(URMnemo.RR, 0x1800CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // SLA (IX+d),r8
  URAsmCmdInfo(URMnemo.SLA, 0x2000CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // SRA (IX+d),r8
  URAsmCmdInfo(URMnemo.SRA, 0x2800CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // SLL (IX+d),r8
  URAsmCmdInfo(URMnemo.SLL, 0x3000CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // SLI (IX+d),r8
  URAsmCmdInfo(URMnemo.SLI, 0x3000CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // SRL (IX+d),r8
  URAsmCmdInfo(URMnemo.SRL, 0x3800CBDDU, 0xF800FFFFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // BIT n,(IX+d)
  URAsmCmdInfo(URMnemo.BIT, 0x4600CBDDU, 0xC700FFFFU, [UROpType.BITN, UROpType.MIX, UROpType.NONE]),
  // BIT n,(IX+d),r8
  URAsmCmdInfo(URMnemo.BIT, 0x4000CBDDU, 0xC000FFFFU, [UROpType.BITN, UROpType.MIX, UROpType.R8NOM]),
  // RES n,(IX+d),r8
  URAsmCmdInfo(URMnemo.RES, 0x8000CBDDU, 0xC000FFFFU, [UROpType.BITN, UROpType.MIX, UROpType.R8NOM]),
  // SET n,(IX+d),r8
  URAsmCmdInfo(URMnemo.SET, 0xC000CBDDU, 0xC000FFFFU, [UROpType.BITN, UROpType.MIX, UROpType.R8NOM]),
  // FD/CB opcodes
  // RLC (IY+d),r8
  URAsmCmdInfo(URMnemo.RLC, 0x0000CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // RRC (IY+d),r8
  URAsmCmdInfo(URMnemo.RRC, 0x0800CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // RL (IY+d),r8
  URAsmCmdInfo(URMnemo.RL, 0x1000CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // RR (IY+d),r8
  URAsmCmdInfo(URMnemo.RR, 0x1800CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // SLA (IY+d),r8
  URAsmCmdInfo(URMnemo.SLA, 0x2000CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // SRA (IY+d),r8
  URAsmCmdInfo(URMnemo.SRA, 0x2800CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // SLL (IY+d),r8
  URAsmCmdInfo(URMnemo.SLL, 0x3000CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // SLI (IY+d),r8
  URAsmCmdInfo(URMnemo.SLI, 0x3000CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // SRL (IY+d),r8
  URAsmCmdInfo(URMnemo.SRL, 0x3800CBFDU, 0xF800FFFFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),
  // BIT n,(IY+d)
  URAsmCmdInfo(URMnemo.BIT, 0x4600CBFDU, 0xC700FFFFU, [UROpType.BITN, UROpType.MIY, UROpType.NONE]),
  // BIT n,(IY+d),r8
  URAsmCmdInfo(URMnemo.BIT, 0x4000CBFDU, 0xC000FFFFU, [UROpType.BITN, UROpType.MIY, UROpType.R8NOM]),
  // RES n,(IY+d),r8
  URAsmCmdInfo(URMnemo.RES, 0x8000CBFDU, 0xC000FFFFU, [UROpType.BITN, UROpType.MIY, UROpType.R8NOM]),
  // SET n,(IY+d),r8
  URAsmCmdInfo(URMnemo.SET, 0xC000CBFDU, 0xC000FFFFU, [UROpType.BITN, UROpType.MIY, UROpType.R8NOM]),
  // standard CB opcodes
  // RLC r8
  URAsmCmdInfo(URMnemo.RLC, 0x00CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // RRC r8
  URAsmCmdInfo(URMnemo.RRC, 0x08CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // RL r8
  URAsmCmdInfo(URMnemo.RL, 0x10CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // RR r8
  URAsmCmdInfo(URMnemo.RR, 0x18CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SLA r8
  URAsmCmdInfo(URMnemo.SLA, 0x20CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SRA r8
  URAsmCmdInfo(URMnemo.SRA, 0x28CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SLL r8
  URAsmCmdInfo(URMnemo.SLL, 0x30CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SLI r8
  URAsmCmdInfo(URMnemo.SLI, 0x30CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SRL r8
  URAsmCmdInfo(URMnemo.SRL, 0x38CBU, 0xF8FFU, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // BIT n,r8
  URAsmCmdInfo(URMnemo.BIT, 0x40CBU, 0xC0FFU, [UROpType.BITN, UROpType.R8, UROpType.NONE]),
  // RES n,r8
  URAsmCmdInfo(URMnemo.RES, 0x80CBU, 0xC0FFU, [UROpType.BITN, UROpType.R8, UROpType.NONE]),
  // SET n,r8
  URAsmCmdInfo(URMnemo.SET, 0xC0CBU, 0xC0FFU, [UROpType.BITN, UROpType.R8, UROpType.NONE]),

  // some ED opcodes
  // traps
  URAsmCmdInfo(URMnemo.XSLT, 0xFBEDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  // ED string instructions
  URAsmCmdInfo(URMnemo.LDI, 0xA0EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.LDIR, 0xB0EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.CPI, 0xA1EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.CPIR, 0xB1EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.INI, 0xA2EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.INIR, 0xB2EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.OUTI, 0xA3EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.OTIR, 0xB3EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.LDD, 0xA8EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.LDDR, 0xB8EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.CPD, 0xA9EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.CPDR, 0xB9EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.IND, 0xAAEDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.INDR, 0xBAEDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.OUTD, 0xABEDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.OTDR, 0xBBEDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),

  // ED w/o operands
  URAsmCmdInfo(URMnemo.RRD, 0x67EDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RLD, 0x6FEDU, 0xFFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),

  // IN (C)
  URAsmCmdInfo(URMnemo.IN, 0x70EDU, 0xFFFFU, [UROpType.PORTC, UROpType.NONE, UROpType.NONE]),
  // OUT (C),0
  URAsmCmdInfo(URMnemo.OUT, 0x71EDU, 0xFFFFU, [UROpType.PORTC, UROpType.IM0, UROpType.NONE]),

  // LD I,A
  URAsmCmdInfo(URMnemo.LD, 0x47EDU, 0xFFFFU, [UROpType.R8I, UROpType.R8A, UROpType.NONE]),
  // LD A,I
  URAsmCmdInfo(URMnemo.LD, 0x57EDU, 0xFFFFU, [UROpType.R8A, UROpType.R8I, UROpType.NONE]),
  // LD R,A
  URAsmCmdInfo(URMnemo.LD, 0x4FEDU, 0xFFFFU, [UROpType.R8R, UROpType.R8A, UROpType.NONE]),
  // LD A,R
  URAsmCmdInfo(URMnemo.LD, 0x5FEDU, 0xFFFFU, [UROpType.R8A, UROpType.R8R, UROpType.NONE]),
  // IM 0/1
  //(.mnemo=UT_IM,   .code=0x4EEDU, .mask=0xFFFFU, .ops={UO_IM01, UO_NONE, UO_NONE}},

  // ED w/o operands
  URAsmCmdInfo(URMnemo.RETN, 0x45EDU, 0xCFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RETI, 0x4DEDU, 0xCFFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),

  // SBC HL,r16
  URAsmCmdInfo(URMnemo.SBC, 0x42EDU, 0xCFFFU, [UROpType.R16HL, UROpType.R16, UROpType.NONE]),
  // ADC HL,r16
  URAsmCmdInfo(URMnemo.ADC, 0x4AEDU, 0xCFFFU, [UROpType.R16HL, UROpType.R16, UROpType.NONE]),
  // LD (nnnn),r16
  URAsmCmdInfo(URMnemo.LD, 0x43EDU, 0xCFFFU, [UROpType.MEM16, UROpType.R16, UROpType.NONE]),
  // LD r16,(nnnn)
  URAsmCmdInfo(URMnemo.LD, 0x4BEDU, 0xCFFFU, [UROpType.R16, UROpType.MEM16, UROpType.NONE]),

  // ED w/o operands
  URAsmCmdInfo(URMnemo.NEG, 0x44EDU, 0xC7FFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),

  // IN r8,(C)
  URAsmCmdInfo(URMnemo.IN, 0x40EDU, 0xC7FFU, [UROpType.R83NOM, UROpType.PORTC, UROpType.NONE]),
  // OUT (C),r8
  URAsmCmdInfo(URMnemo.OUT, 0x41EDU, 0xC7FFU, [UROpType.PORTC, UROpType.R83NOM, UROpType.NONE]),

  // IM 2
  URAsmCmdInfo(URMnemo.IM, 0x5EEDU, 0xDFFFU, [UROpType.IM2, UROpType.NONE, UROpType.NONE]),
  // IM 1
  URAsmCmdInfo(URMnemo.IM, 0x56EDU, 0xDFFFU, [UROpType.IM1, UROpType.NONE, UROpType.NONE]),
  // IM 0
  URAsmCmdInfo(URMnemo.IM, 0x46EDU, 0xD7FFU, [UROpType.IM0, UROpType.NONE, UROpType.NONE]),

  // LD SP,IX
  URAsmCmdInfo(URMnemo.LD, 0xF9DDU, 0xFFFFU, [UROpType.R16SP, UROpType.R16IX, UROpType.NONE]),
  // LD SP,IY
  URAsmCmdInfo(URMnemo.LD, 0xF9FDU, 0xFFFFU, [UROpType.R16SP, UROpType.R16IY, UROpType.NONE]),

  // EX (SP),IX
  URAsmCmdInfo(URMnemo.EX, 0xE3DDU, 0xFFFFU, [UROpType.MSP, UROpType.R16IX, UROpType.NONE]),
  // EX IX,(SP) (ditto)
  URAsmCmdInfo(URMnemo.EX, 0xE3DDU, 0xFFFFU, [UROpType.R16IX, UROpType.MSP, UROpType.NONE]),
  // EX (SP),IY
  URAsmCmdInfo(URMnemo.EX, 0xE3FDU, 0xFFFFU, [UROpType.MSP, UROpType.R16IY, UROpType.NONE]),
  // EX IY,(SP) (ditto)
  URAsmCmdInfo(URMnemo.EX, 0xE3FDU, 0xFFFFU, [UROpType.R16IY, UROpType.MSP, UROpType.NONE]),

  // JP (IX)
  URAsmCmdInfo(URMnemo.JP, 0xE9DDU, 0xFFFFU, [UROpType.MIX0, UROpType.NONE, UROpType.NONE]),
  // JP (IY)
  URAsmCmdInfo(URMnemo.JP, 0xE9FDU, 0xFFFFU, [UROpType.MIY0, UROpType.NONE, UROpType.NONE]),
  // JP IX
  URAsmCmdInfo(URMnemo.JP, 0xE9DDU, 0xFFFFU, [UROpType.R16IX, UROpType.NONE, UROpType.NONE]),
  // JP IY
  URAsmCmdInfo(URMnemo.JP, 0xE9FDU, 0xFFFFU, [UROpType.R16IY, UROpType.NONE, UROpType.NONE]),

  // POP IX
  URAsmCmdInfo(URMnemo.POP, 0xE1DDU, 0xFFFFU, [UROpType.R16IX, UROpType.NONE, UROpType.NONE]),
  // PUSH IX
  URAsmCmdInfo(URMnemo.PUSH, 0xE5DDU, 0xFFFFU, [UROpType.R16IX, UROpType.NONE, UROpType.NONE]),
  // POP IY
  URAsmCmdInfo(URMnemo.POP, 0xE1FDU, 0xFFFFU, [UROpType.R16IY, UROpType.NONE, UROpType.NONE]),
  // PUSH IY
  URAsmCmdInfo(URMnemo.PUSH, 0xE5FDU, 0xFFFFU, [UROpType.R16IY, UROpType.NONE, UROpType.NONE]),

  // ADD A,(IX+d)
  URAsmCmdInfo(URMnemo.ADD, 0x86DDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // ADD (IX+d)
  URAsmCmdInfo(URMnemo.ADD, 0x86DDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // ADC A,(IX+d)
  URAsmCmdInfo(URMnemo.ADC, 0x8EDDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // ADC (IX+d)
  URAsmCmdInfo(URMnemo.ADC, 0x8EDDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SUB (IX+d)
  URAsmCmdInfo(URMnemo.SUB, 0x96DDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // SUB A,(IX+d)
  URAsmCmdInfo(URMnemo.SUB, 0x96DDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // SBC A,(IX+d)
  URAsmCmdInfo(URMnemo.SBC, 0x9EDDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // SBC (IX+d)
  URAsmCmdInfo(URMnemo.SBC, 0x9EDDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // AND (IX+d)
  URAsmCmdInfo(URMnemo.AND, 0xA6DDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // AND A,(IX+d)
  URAsmCmdInfo(URMnemo.AND, 0xA6DDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // XOR (IX+d)
  URAsmCmdInfo(URMnemo.XOR, 0xAEDDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // XOR A,(IX+d)
  URAsmCmdInfo(URMnemo.XOR, 0xAEDDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // OR (IX+d)
  URAsmCmdInfo(URMnemo.OR, 0xB6DDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // OR A,(IX+d)
  URAsmCmdInfo(URMnemo.OR, 0xB6DDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // CP (IX+d)
  URAsmCmdInfo(URMnemo.CP, 0xBEDDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // CP A,(IX+d)
  URAsmCmdInfo(URMnemo.CP, 0xBEDDU, 0xFFFFU, [UROpType.R8A, UROpType.MIX, UROpType.NONE]),
  // ADD A,(IY+d)
  URAsmCmdInfo(URMnemo.ADD, 0x86FDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // ADD (IY+d)
  URAsmCmdInfo(URMnemo.ADD, 0x86FDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // ADC A,(IY+d)
  URAsmCmdInfo(URMnemo.ADC, 0x8EFDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // ADC (IY+d)
  URAsmCmdInfo(URMnemo.ADC, 0x8EFDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SUB (IY+d)
  URAsmCmdInfo(URMnemo.SUB, 0x96FDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // SUB A,(IY+d)
  URAsmCmdInfo(URMnemo.SUB, 0x96FDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // SBC A,(IY+d)
  URAsmCmdInfo(URMnemo.SBC, 0x9EFDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // SBC (IY+d)
  URAsmCmdInfo(URMnemo.SBC, 0x9EFDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // AND (IY+d)
  URAsmCmdInfo(URMnemo.AND, 0xA6FDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // AND A,(IY+d)
  URAsmCmdInfo(URMnemo.AND, 0xA6FDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // XOR (IY+d)
  URAsmCmdInfo(URMnemo.XOR, 0xAEFDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // XOR A,(IY+d)
  URAsmCmdInfo(URMnemo.XOR, 0xAEFDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // OR (IY+d)
  URAsmCmdInfo(URMnemo.OR, 0xB6FDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // OR A,(IY+d)
  URAsmCmdInfo(URMnemo.OR, 0xB6FDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // CP (IY+d)
  URAsmCmdInfo(URMnemo.CP, 0xBEFDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // CP A,(IY+d)
  URAsmCmdInfo(URMnemo.CP, 0xBEFDU, 0xFFFFU, [UROpType.R8A, UROpType.MIY, UROpType.NONE]),
  // ADD A,XH
  URAsmCmdInfo(URMnemo.ADD, 0x84DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // ADD XH
  URAsmCmdInfo(URMnemo.ADD, 0x84DDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // ADC A,XH
  URAsmCmdInfo(URMnemo.ADC, 0x8CDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // ADC XH
  URAsmCmdInfo(URMnemo.ADC, 0x8CDDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // SUB XH
  URAsmCmdInfo(URMnemo.SUB, 0x94DDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // SUB A,XH
  URAsmCmdInfo(URMnemo.SUB, 0x94DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // SBC A,XH
  URAsmCmdInfo(URMnemo.SBC, 0x9CDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // SBC XH
  URAsmCmdInfo(URMnemo.SBC, 0x9CDDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // AND XH
  URAsmCmdInfo(URMnemo.AND, 0xA4DDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // AND A,XH
  URAsmCmdInfo(URMnemo.AND, 0xA4DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // XOR XH
  URAsmCmdInfo(URMnemo.XOR, 0xACDDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // XOR A,XH
  URAsmCmdInfo(URMnemo.XOR, 0xACDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // OR XH
  URAsmCmdInfo(URMnemo.OR, 0xB4DDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // OR A,XH
  URAsmCmdInfo(URMnemo.OR, 0xB4DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // CP XH
  URAsmCmdInfo(URMnemo.CP, 0xBCDDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // CP A,XH
  URAsmCmdInfo(URMnemo.CP, 0xBCDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XH, UROpType.NONE]),
  // ADD A,XL
  URAsmCmdInfo(URMnemo.ADD, 0x85DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // ADD XL
  URAsmCmdInfo(URMnemo.ADD, 0x85DDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // ADC A,XL
  URAsmCmdInfo(URMnemo.ADC, 0x8DDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // ADC XL
  URAsmCmdInfo(URMnemo.ADC, 0x8DDDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // SUB XL
  URAsmCmdInfo(URMnemo.SUB, 0x95DDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // SUB A,XL
  URAsmCmdInfo(URMnemo.SUB, 0x95DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // SBC A,XL
  URAsmCmdInfo(URMnemo.SBC, 0x9DDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // SBC XL
  URAsmCmdInfo(URMnemo.SBC, 0x9DDDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // AND XL
  URAsmCmdInfo(URMnemo.AND, 0xA5DDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // AND A,XL
  URAsmCmdInfo(URMnemo.AND, 0xA5DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // XOR XL
  URAsmCmdInfo(URMnemo.XOR, 0xADDDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // XOR A,XL
  URAsmCmdInfo(URMnemo.XOR, 0xADDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // OR XL
  URAsmCmdInfo(URMnemo.OR, 0xB5DDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // OR A,XL
  URAsmCmdInfo(URMnemo.OR, 0xB5DDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // CP XL
  URAsmCmdInfo(URMnemo.CP, 0xBDDDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // CP A,XL
  URAsmCmdInfo(URMnemo.CP, 0xBDDDU, 0xFFFFU, [UROpType.R8A, UROpType.R8XL, UROpType.NONE]),
  // ADD A,YH
  URAsmCmdInfo(URMnemo.ADD, 0x84FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // ADD YH
  URAsmCmdInfo(URMnemo.ADD, 0x84FDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // ADC A,YH
  URAsmCmdInfo(URMnemo.ADC, 0x8CFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // ADC YH
  URAsmCmdInfo(URMnemo.ADC, 0x8CFDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // SUB YH
  URAsmCmdInfo(URMnemo.SUB, 0x94FDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // SUB A,YH
  URAsmCmdInfo(URMnemo.SUB, 0x94FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // SBC A,YH
  URAsmCmdInfo(URMnemo.SBC, 0x9CFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // SBC YH
  URAsmCmdInfo(URMnemo.SBC, 0x9CFDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // AND YH
  URAsmCmdInfo(URMnemo.AND, 0xA4FDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // AND A,YH
  URAsmCmdInfo(URMnemo.AND, 0xA4FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // XOR YH
  URAsmCmdInfo(URMnemo.XOR, 0xACFDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // XOR A,YH
  URAsmCmdInfo(URMnemo.XOR, 0xACFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // OR YH
  URAsmCmdInfo(URMnemo.OR, 0xB4FDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // OR A,YH
  URAsmCmdInfo(URMnemo.OR, 0xB4FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // CP YH
  URAsmCmdInfo(URMnemo.CP, 0xBCFDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // CP A,YH
  URAsmCmdInfo(URMnemo.CP, 0xBCFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YH, UROpType.NONE]),
  // ADD A,YL
  URAsmCmdInfo(URMnemo.ADD, 0x85FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // ADD YL
  URAsmCmdInfo(URMnemo.ADD, 0x85FDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // ADC A,YL
  URAsmCmdInfo(URMnemo.ADC, 0x8DFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // ADC YL
  URAsmCmdInfo(URMnemo.ADC, 0x8DFDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // SUB YL
  URAsmCmdInfo(URMnemo.SUB, 0x95FDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // SUB A,YL
  URAsmCmdInfo(URMnemo.SUB, 0x95FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // SBC A,YL
  URAsmCmdInfo(URMnemo.SBC, 0x9DFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // SBC YL
  URAsmCmdInfo(URMnemo.SBC, 0x9DFDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // AND YL
  URAsmCmdInfo(URMnemo.AND, 0xA5FDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // AND A,YL
  URAsmCmdInfo(URMnemo.AND, 0xA5FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // XOR YL
  URAsmCmdInfo(URMnemo.XOR, 0xADFDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // XOR A,YL
  URAsmCmdInfo(URMnemo.XOR, 0xADFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // OR YL
  URAsmCmdInfo(URMnemo.OR, 0xB5FDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // OR A,YL
  URAsmCmdInfo(URMnemo.OR, 0xB5FDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),
  // CP YL
  URAsmCmdInfo(URMnemo.CP, 0xBDFDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // CP A,YL
  URAsmCmdInfo(URMnemo.CP, 0xBDFDU, 0xFFFFU, [UROpType.R8A, UROpType.R8YL, UROpType.NONE]),

  // LD XH,XH
  URAsmCmdInfo(URMnemo.LD, 0x64DDU, 0xFFFFU, [UROpType.R8XH, UROpType.R8XH, UROpType.NONE]),
  // LD XH,XL
  URAsmCmdInfo(URMnemo.LD, 0x65DDU, 0xFFFFU, [UROpType.R8XH, UROpType.R8XL, UROpType.NONE]),
  // LD XL,XH
  URAsmCmdInfo(URMnemo.LD, 0x6CDDU, 0xFFFFU, [UROpType.R8XL, UROpType.R8XH, UROpType.NONE]),
  // LD XL,XL
  URAsmCmdInfo(URMnemo.LD, 0x6DDDU, 0xFFFFU, [UROpType.R8XL, UROpType.R8XL, UROpType.NONE]),
  // LD YH,YH
  URAsmCmdInfo(URMnemo.LD, 0x64FDU, 0xFFFFU, [UROpType.R8YH, UROpType.R8YH, UROpType.NONE]),
  // LD YH,YL
  URAsmCmdInfo(URMnemo.LD, 0x65FDU, 0xFFFFU, [UROpType.R8YH, UROpType.R8YL, UROpType.NONE]),
  // LD YL,YH
  URAsmCmdInfo(URMnemo.LD, 0x6CFDU, 0xFFFFU, [UROpType.R8YL, UROpType.R8YH, UROpType.NONE]),
  // LD YL,YL
  URAsmCmdInfo(URMnemo.LD, 0x6DFDU, 0xFFFFU, [UROpType.R8YL, UROpType.R8YL, UROpType.NONE]),

  // LD (nnnn),IX
  URAsmCmdInfo(URMnemo.LD, 0x22DDU, 0xFFFFU, [UROpType.MEM16, UROpType.R16IX, UROpType.NONE]),
  // LD IX,(nnnn)
  URAsmCmdInfo(URMnemo.LD, 0x2ADDU, 0xFFFFU, [UROpType.R16IX, UROpType.MEM16, UROpType.NONE]),
  // LD (nnnn),IY
  URAsmCmdInfo(URMnemo.LD, 0x22FDU, 0xFFFFU, [UROpType.MEM16, UROpType.R16IY, UROpType.NONE]),
  // LD IY,(nnnn)
  URAsmCmdInfo(URMnemo.LD, 0x2AFDU, 0xFFFFU, [UROpType.R16IY, UROpType.MEM16, UROpType.NONE]),

  // LD IX,nnnn
  URAsmCmdInfo(URMnemo.LD, 0x21DDU, 0xFFFFU, [UROpType.R16IX, UROpType.IMM16, UROpType.NONE]),
  // LD IY,nnnn
  URAsmCmdInfo(URMnemo.LD, 0x21FDU, 0xFFFFU, [UROpType.R16IY, UROpType.IMM16, UROpType.NONE]),

  // INC IX
  URAsmCmdInfo(URMnemo.INC, 0x23DDU, 0xFFFFU, [UROpType.R16IX, UROpType.NONE, UROpType.NONE]),
  // DEC IX
  URAsmCmdInfo(URMnemo.DEC, 0x2BDDU, 0xFFFFU, [UROpType.R16IX, UROpType.NONE, UROpType.NONE]),
  // INC IY
  URAsmCmdInfo(URMnemo.INC, 0x23FDU, 0xFFFFU, [UROpType.R16IY, UROpType.NONE, UROpType.NONE]),
  // DEC IY
  URAsmCmdInfo(URMnemo.DEC, 0x2BFDU, 0xFFFFU, [UROpType.R16IY, UROpType.NONE, UROpType.NONE]),

  // INC (IX+d)
  URAsmCmdInfo(URMnemo.INC, 0x34DDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // DEC (IX+d)
  URAsmCmdInfo(URMnemo.DEC, 0x35DDU, 0xFFFFU, [UROpType.MIX, UROpType.NONE, UROpType.NONE]),
  // LD (IX+d),nn
  URAsmCmdInfo(URMnemo.LD, 0x36DDU, 0xFFFFU, [UROpType.MIX, UROpType.IMM8, UROpType.NONE]),
  // INC (IY+d)
  URAsmCmdInfo(URMnemo.INC, 0x34FDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // DEC (IY+d)
  URAsmCmdInfo(URMnemo.DEC, 0x35FDU, 0xFFFFU, [UROpType.MIY, UROpType.NONE, UROpType.NONE]),
  // LD (IY+d),nn
  URAsmCmdInfo(URMnemo.LD, 0x36FDU, 0xFFFFU, [UROpType.MIY, UROpType.IMM8, UROpType.NONE]),

  // INC XH
  URAsmCmdInfo(URMnemo.INC, 0x24DDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // DEC XH
  URAsmCmdInfo(URMnemo.DEC, 0x25DDU, 0xFFFFU, [UROpType.R8XH, UROpType.NONE, UROpType.NONE]),
  // INC XL
  URAsmCmdInfo(URMnemo.INC, 0x2CDDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // DEC XL
  URAsmCmdInfo(URMnemo.DEC, 0x2DDDU, 0xFFFFU, [UROpType.R8XL, UROpType.NONE, UROpType.NONE]),
  // INC YH
  URAsmCmdInfo(URMnemo.INC, 0x24FDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // DEC YH
  URAsmCmdInfo(URMnemo.DEC, 0x25FDU, 0xFFFFU, [UROpType.R8YH, UROpType.NONE, UROpType.NONE]),
  // INC YL
  URAsmCmdInfo(URMnemo.INC, 0x2CFDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),
  // DEC YL
  URAsmCmdInfo(URMnemo.DEC, 0x2DFDU, 0xFFFFU, [UROpType.R8YL, UROpType.NONE, UROpType.NONE]),

  // LD XH,nn
  URAsmCmdInfo(URMnemo.LD, 0x26DDU, 0xFFFFU, [UROpType.R8XH, UROpType.IMM8, UROpType.NONE]),
  // LD XL,nn
  URAsmCmdInfo(URMnemo.LD, 0x2EDDU, 0xFFFFU, [UROpType.R8XL, UROpType.IMM8, UROpType.NONE]),
  // LD YH,nn
  URAsmCmdInfo(URMnemo.LD, 0x26FDU, 0xFFFFU, [UROpType.R8YH, UROpType.IMM8, UROpType.NONE]),
  // LD YL,nn
  URAsmCmdInfo(URMnemo.LD, 0x2EFDU, 0xFFFFU, [UROpType.R8YL, UROpType.IMM8, UROpType.NONE]),

  // ADD IX,BC
  URAsmCmdInfo(URMnemo.ADD, 0x09DDU, 0xFFFFU, [UROpType.R16IX, UROpType.R16BC, UROpType.NONE]),
  // ADD IX,DE
  URAsmCmdInfo(URMnemo.ADD, 0x19DDU, 0xFFFFU, [UROpType.R16IX, UROpType.R16DE, UROpType.NONE]),
  // ADD IX,IX
  URAsmCmdInfo(URMnemo.ADD, 0x29DDU, 0xFFFFU, [UROpType.R16IX, UROpType.R16IX, UROpType.NONE]),
  // ADD IX,SP
  URAsmCmdInfo(URMnemo.ADD, 0x39DDU, 0xFFFFU, [UROpType.R16IX, UROpType.R16SP, UROpType.NONE]),
  // ADD IY,BC
  URAsmCmdInfo(URMnemo.ADD, 0x09FDU, 0xFFFFU, [UROpType.R16IY, UROpType.R16BC, UROpType.NONE]),
  // ADD IY,DE
  URAsmCmdInfo(URMnemo.ADD, 0x19FDU, 0xFFFFU, [UROpType.R16IY, UROpType.R16DE, UROpType.NONE]),
  // ADD IY,IY
  URAsmCmdInfo(URMnemo.ADD, 0x29FDU, 0xFFFFU, [UROpType.R16IY, UROpType.R16IY, UROpType.NONE]),
  // ADD IY,SP
  URAsmCmdInfo(URMnemo.ADD, 0x39FDU, 0xFFFFU, [UROpType.R16IY, UROpType.R16SP, UROpType.NONE]),

  // LD XH,r8
  URAsmCmdInfo(URMnemo.LD, 0x60DDU, 0xF8FFU, [UROpType.R8XH, UROpType.R8NOM, UROpType.NONE]),
  // LD XL,r8
  URAsmCmdInfo(URMnemo.LD, 0x68DDU, 0xF8FFU, [UROpType.R8XL, UROpType.R8NOM, UROpType.NONE]),
  // LD (IX+d),r8
  URAsmCmdInfo(URMnemo.LD, 0x70DDU, 0xF8FFU, [UROpType.MIX, UROpType.R8NOM, UROpType.NONE]),
  // LD YH,r8
  URAsmCmdInfo(URMnemo.LD, 0x60FDU, 0xF8FFU, [UROpType.R8YH, UROpType.R8NOM, UROpType.NONE]),
  // LD YL,r8
  URAsmCmdInfo(URMnemo.LD, 0x68FDU, 0xF8FFU, [UROpType.R8YL, UROpType.R8NOM, UROpType.NONE]),
  // LD (IY+d),r8
  URAsmCmdInfo(URMnemo.LD, 0x70FDU, 0xF8FFU, [UROpType.MIY, UROpType.R8NOM, UROpType.NONE]),

  // LD r8,XH
  URAsmCmdInfo(URMnemo.LD, 0x44DDU, 0xC7FFU, [UROpType.R83NOM, UROpType.R8XH, UROpType.NONE]),
  // LD r8,XL
  URAsmCmdInfo(URMnemo.LD, 0x45DDU, 0xC7FFU, [UROpType.R83NOM, UROpType.R8XL, UROpType.NONE]),
  // LD r8,(IX+d)
  URAsmCmdInfo(URMnemo.LD, 0x46DDU, 0xC7FFU, [UROpType.R83NOM, UROpType.MIX, UROpType.NONE]),

  // LD r8,YH
  URAsmCmdInfo(URMnemo.LD, 0x44FDU, 0xC7FFU, [UROpType.R83NOM, UROpType.R8YH, UROpType.NONE]),
  // LD r8,YL
  URAsmCmdInfo(URMnemo.LD, 0x45FDU, 0xC7FFU, [UROpType.R83NOM, UROpType.R8YL, UROpType.NONE]),
  // LD r8,(IY+d)
  URAsmCmdInfo(URMnemo.LD, 0x46FDU, 0xC7FFU, [UROpType.R83NOM, UROpType.MIY, UROpType.NONE]),

  // instructions w/o operands or with unchangeable operands
  URAsmCmdInfo(URMnemo.NOP, 0x00U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RLCA, 0x07U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RRCA, 0x0FU, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RLA, 0x17U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RRA, 0x1FU, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.DAA, 0x27U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.CPL, 0x2FU, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.SCF, 0x37U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.CCF, 0x3FU, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.HALT, 0x76U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.RET, 0xC9U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.EXX, 0xD9U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.DI, 0xF3U, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  URAsmCmdInfo(URMnemo.EI, 0xFBU, 0xFFU, [UROpType.NONE, UROpType.NONE, UROpType.NONE]),
  // LD SP,HL
  URAsmCmdInfo(URMnemo.LD, 0xF9U, 0xFFU, [UROpType.R16SP, UROpType.R16HL, UROpType.NONE]),
  // EX AF,AF'
  URAsmCmdInfo(URMnemo.EX, 0x08U, 0xFFU, [UROpType.R16AF, UROpType.R16AFX, UROpType.NONE]),
  // EX AF',AF (ditto)
  URAsmCmdInfo(URMnemo.EX, 0x08U, 0xFFU, [UROpType.R16AFX, UROpType.R16AF, UROpType.NONE]),
  // EX (SP),HL
  URAsmCmdInfo(URMnemo.EX, 0xE3U, 0xFFU, [UROpType.MSP, UROpType.R16HL, UROpType.NONE]),
  // EX HL,(SP) (ditto)
  URAsmCmdInfo(URMnemo.EX, 0xE3U, 0xFFU, [UROpType.R16HL, UROpType.MSP, UROpType.NONE]),
  // EX DE,HL
  URAsmCmdInfo(URMnemo.EX, 0xEBU, 0xFFU, [UROpType.R16DE, UROpType.R16HL, UROpType.NONE]),
  // EX HL,DE (ditto)
  URAsmCmdInfo(URMnemo.EX, 0xEBU, 0xFFU, [UROpType.R16HL, UROpType.R16DE, UROpType.NONE]),
  // JP (HL)
  URAsmCmdInfo(URMnemo.JP, 0xE9U, 0xFFU, [UROpType.MHL, UROpType.NONE, UROpType.NONE]),
  // JP HL
  URAsmCmdInfo(URMnemo.JP, 0xE9U, 0xFFU, [UROpType.R16HL, UROpType.NONE, UROpType.NONE]),
  // JP nnnn
  URAsmCmdInfo(URMnemo.JP, 0xC3U, 0xFFU, [UROpType.ADDR16, UROpType.NONE, UROpType.NONE]),
  // CALL nnnn
  URAsmCmdInfo(URMnemo.CALL, 0xCDU, 0xFFU, [UROpType.ADDR16, UROpType.NONE, UROpType.NONE]),
  // OUT (n),A
  URAsmCmdInfo(URMnemo.OUT, 0xD3U, 0xFFU, [UROpType.PORTIMM, UROpType.R8A, UROpType.NONE]),
  // IN A,(n)
  URAsmCmdInfo(URMnemo.IN, 0xDBU, 0xFFU, [UROpType.R8A, UROpType.PORTIMM, UROpType.NONE]),

  // ADD A,nn
  URAsmCmdInfo(URMnemo.ADD, 0xC6U, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // ADD nn (ditto)
  URAsmCmdInfo(URMnemo.ADD, 0xC6U, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // ADC A,nn
  URAsmCmdInfo(URMnemo.ADC, 0xCEU, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // ADC nn (ditto)
  URAsmCmdInfo(URMnemo.ADC, 0xCEU, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // SUB nn
  URAsmCmdInfo(URMnemo.SUB, 0xD6U, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // SUB A,nn (ditto)
  URAsmCmdInfo(URMnemo.SUB, 0xD6U, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // SBC A,nn
  URAsmCmdInfo(URMnemo.SBC, 0xDEU, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // SBC nn (ditto)
  URAsmCmdInfo(URMnemo.SBC, 0xDEU, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // AND nn
  URAsmCmdInfo(URMnemo.AND, 0xE6U, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // AND A,nn (ditto)
  URAsmCmdInfo(URMnemo.AND, 0xE6U, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // XOR nn
  URAsmCmdInfo(URMnemo.XOR, 0xEEU, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // XOR A,nn (ditto)
  URAsmCmdInfo(URMnemo.XOR, 0xEEU, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // OR nn
  URAsmCmdInfo(URMnemo.OR, 0xF6U, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // OR A,nn (ditto)
  URAsmCmdInfo(URMnemo.OR, 0xF6U, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // CP nn
  URAsmCmdInfo(URMnemo.CP, 0xFEU, 0xFFU, [UROpType.IMM8, UROpType.NONE, UROpType.NONE]),
  // CP A,nn (ditto)
  URAsmCmdInfo(URMnemo.CP, 0xFEU, 0xFFU, [UROpType.R8A, UROpType.IMM8, UROpType.NONE]),
  // LD (BC),A
  URAsmCmdInfo(URMnemo.LD, 0x02U, 0xFFU, [UROpType.MBC, UROpType.R8A, UROpType.NONE]),
  // LD (DE),A
  URAsmCmdInfo(URMnemo.LD, 0x12U, 0xFFU, [UROpType.MDE, UROpType.R8A, UROpType.NONE]),
  // LD A,(BC)
  URAsmCmdInfo(URMnemo.LD, 0x0AU, 0xFFU, [UROpType.R8A, UROpType.MBC, UROpType.NONE]),
  // LD A,(DE)
  URAsmCmdInfo(URMnemo.LD, 0x1AU, 0xFFU, [UROpType.R8A, UROpType.MDE, UROpType.NONE]),
  // LD (nnnn),HL
  URAsmCmdInfo(URMnemo.LD, 0x22U, 0xFFU, [UROpType.MEM16, UROpType.R16HL, UROpType.NONE]),
  // LD HL,(nnnn)
  URAsmCmdInfo(URMnemo.LD, 0x2AU, 0xFFU, [UROpType.R16HL, UROpType.MEM16, UROpType.NONE]),
  // LD (nnnn),A
  URAsmCmdInfo(URMnemo.LD, 0x32U, 0xFFU, [UROpType.MEM16, UROpType.R8A, UROpType.NONE]),
  // LD A,(nnnn)
  URAsmCmdInfo(URMnemo.LD, 0x3AU, 0xFFU, [UROpType.R8A, UROpType.MEM16, UROpType.NONE]),
  // DJNZ d
  URAsmCmdInfo(URMnemo.DJNZ, 0x10U, 0xFFU, [UROpType.ADDR8, UROpType.NONE, UROpType.NONE]),
  // JR d
  URAsmCmdInfo(URMnemo.JR, 0x18U, 0xFFU, [UROpType.ADDR8, UROpType.NONE, UROpType.NONE]),

  // ADD HL,r16
  URAsmCmdInfo(URMnemo.ADD, 0x09U, 0xCFU, [UROpType.R16HL, UROpType.R16, UROpType.NONE]),

  // ADD A,r8
  URAsmCmdInfo(URMnemo.ADD, 0x80U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // ADD r8
  URAsmCmdInfo(URMnemo.ADD, 0x80U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // ADC A,r8
  URAsmCmdInfo(URMnemo.ADC, 0x88U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // ADC r8
  URAsmCmdInfo(URMnemo.ADC, 0x88U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SUB r8
  URAsmCmdInfo(URMnemo.SUB, 0x90U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // SUB A,r8
  URAsmCmdInfo(URMnemo.SUB, 0x90U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // SBC A,r8
  URAsmCmdInfo(URMnemo.SBC, 0x98U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // SBC r8
  URAsmCmdInfo(URMnemo.SBC, 0x98U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // AND r8
  URAsmCmdInfo(URMnemo.AND, 0xA0U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // AND A,r8
  URAsmCmdInfo(URMnemo.AND, 0xA0U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // XOR r8
  URAsmCmdInfo(URMnemo.XOR, 0xA8U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // XOR A,r8
  URAsmCmdInfo(URMnemo.XOR, 0xA8U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // OR r8
  URAsmCmdInfo(URMnemo.OR, 0xB0U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // OR A,r8
  URAsmCmdInfo(URMnemo.OR, 0xB0U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),
  // CP r8
  URAsmCmdInfo(URMnemo.CP, 0xB8U, 0xF8U, [UROpType.R8, UROpType.NONE, UROpType.NONE]),
  // CP A,r8
  URAsmCmdInfo(URMnemo.CP, 0xB8U, 0xF8U, [UROpType.R8A, UROpType.R8, UROpType.NONE]),

  // JR cc,d
  URAsmCmdInfo(URMnemo.JR, 0x20U, 0xE7U, [UROpType.JRCOND, UROpType.ADDR8, UROpType.NONE]),

  // POP r16
  URAsmCmdInfo(URMnemo.POP, 0xC1U, 0xCFU, [UROpType.R16A, UROpType.NONE, UROpType.NONE]),
  // PUSH r16
  URAsmCmdInfo(URMnemo.PUSH, 0xC5U, 0xCFU, [UROpType.R16A, UROpType.NONE, UROpType.NONE]),
  // RET cc
  URAsmCmdInfo(URMnemo.RET, 0xC0U, 0xC7U, [UROpType.COND, UROpType.NONE, UROpType.NONE]),
  // JP cc,nnnn
  URAsmCmdInfo(URMnemo.JP, 0xC2U, 0xC7U, [UROpType.COND, UROpType.ADDR16, UROpType.NONE]),
  // CALL cc,nnnn
  URAsmCmdInfo(URMnemo.CALL, 0xC4U, 0xC7U, [UROpType.COND, UROpType.ADDR16, UROpType.NONE]),
  // RST n
  URAsmCmdInfo(URMnemo.RST, 0xC7U, 0xC7U, [UROpType.RSTDEST, UROpType.NONE, UROpType.NONE]),

  // INC r8
  URAsmCmdInfo(URMnemo.INC, 0x04U, 0xC7U, [UROpType.R83, UROpType.NONE, UROpType.NONE]),
  // DEC r8
  URAsmCmdInfo(URMnemo.DEC, 0x05U, 0xC7U, [UROpType.R83, UROpType.NONE, UROpType.NONE]),
  // LD r8,nn
  URAsmCmdInfo(URMnemo.LD, 0x06U, 0xC7U, [UROpType.R83, UROpType.IMM8, UROpType.NONE]),

  // LD r16,nnnn
  URAsmCmdInfo(URMnemo.LD, 0x01U, 0xCFU, [UROpType.R16, UROpType.IMM16, UROpType.NONE]),
  // INC r16
  URAsmCmdInfo(URMnemo.INC, 0x03U, 0xCFU, [UROpType.R16, UROpType.NONE, UROpType.NONE]),
  // DEC r16
  URAsmCmdInfo(URMnemo.DEC, 0x0BU, 0xCFU, [UROpType.R16, UROpType.NONE, UROpType.NONE]),

  // LD r8,r8
  URAsmCmdInfo(URMnemo.LD, 0x40U, 0xC0U, [UROpType.R83, UROpType.R8, UROpType.NONE]),

  // syntetics
  // LD BC,BC
  URAsmCmdInfo(URMnemo.LD, 0x4940U, 0xFFFFU, [UROpType.R16BC, UROpType.R16BC, UROpType.NONE]),
  // LD BC,DE
  URAsmCmdInfo(URMnemo.LD, 0x4B42U, 0xFFFFU, [UROpType.R16BC, UROpType.R16DE, UROpType.NONE]),
  // LD BC,HL
  URAsmCmdInfo(URMnemo.LD, 0x4D44U, 0xFFFFU, [UROpType.R16BC, UROpType.R16HL, UROpType.NONE]),
  // LD DE,BC
  URAsmCmdInfo(URMnemo.LD, 0x5950U, 0xFFFFU, [UROpType.R16DE, UROpType.R16BC, UROpType.NONE]),
  // LD DE,DE
  URAsmCmdInfo(URMnemo.LD, 0x5B52U, 0xFFFFU, [UROpType.R16DE, UROpType.R16DE, UROpType.NONE]),
  // LD DE,HL
  URAsmCmdInfo(URMnemo.LD, 0x5D54U, 0xFFFFU, [UROpType.R16DE, UROpType.R16HL, UROpType.NONE]),
  // LD HL,BC
  URAsmCmdInfo(URMnemo.LD, 0x6960U, 0xFFFFU, [UROpType.R16HL, UROpType.R16BC, UROpType.NONE]),
  // LD HL,DE
  URAsmCmdInfo(URMnemo.LD, 0x6B62U, 0xFFFFU, [UROpType.R16HL, UROpType.R16DE, UROpType.NONE]),
  // LD HL,HL
  URAsmCmdInfo(URMnemo.LD, 0x6D64U, 0xFFFFU, [UROpType.R16HL, UROpType.R16HL, UROpType.NONE]),
];


// instructions unaffected by DD/FF prefixes
// this table used by disassembler (we don't want to eat prefixes)
static immutable ubyte[256] URIgnoreDDFDTable = [
  1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,
  1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,
  1,1,1,1,0,0,0,1,1,0,1,1,1,1,1,1,
  1,1,1,1,0,0,0,1,1,1,1,1,0,0,0,1,
  1,1,1,1,0,0,0,1,1,1,1,1,0,0,0,1,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,1,0,1,1,1,1,0,0,0,1,
  1,1,1,1,0,0,0,1,1,1,1,1,0,0,0,1,
  1,1,1,1,0,0,0,1,1,1,1,1,0,0,0,1,
  1,1,1,1,0,0,0,1,1,1,1,1,0,0,0,1,
  1,1,1,1,0,0,0,1,1,1,1,1,0,0,0,1,
  1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,0,1,0,1,0,1,1,1,0,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,
];


private:
// ////////////////////////////////////////////////////////////////////////// //
// disassembler

private bool isDDSensitive (uint c) pure nothrow @trusted @nogc { pragma(inline, true); return (URIgnoreDDFDTable.ptr[c&0xff] != 0); }

// opc: opcode
// nextW: next 2 bytes (after opcode)
// idx: I? displacement
void urdisOp2Str (ref URDisState ctx, int op, ushort addr, ubyte opc, ushort nextW, int idx, scope URFindLabelByAddrCB findLabel) {
  import core.stdc.stdio : sprintf;
  //int add, ismem = 0;
  bool ismem = false;
  switch (op) {
    case UROpType.NONE: break;
    case UROpType.IMM8: ctx.putxnum("#%02X", "%u", nextW&0xFF); break;
    case UROpType.IMM16: ctx.putxnum("#%04X", "%u", nextW); break;
    case UROpType.ADDR8:
      addr += 2;
      nextW &= 0xFFU;
      int add = (nextW < 128 ? nextW : (cast(int)nextW)-256);
      addr += add;
      nextW = addr;
      goto case;
    case UROpType.ADDR16:
      if (findLabel !is null) {
        auto lbl = findLabel(nextW);
        if (lbl.length) { ctx.put(lbl); break; }
        lbl = findLabel(cast(ushort)(nextW-1));
        if (lbl.length) { ctx.put(lbl); ctx.put("-1"); break; }
        lbl = findLabel(cast(ushort)(nextW-2));
        if (lbl.length) { ctx.put(lbl); ctx.put("-2"); break; }
        lbl = findLabel(cast(ushort)(nextW+1));
        if (lbl.length) { ctx.put(lbl); ctx.put("+1"); break; }
        lbl = findLabel(cast(ushort)(nextW+2));
        if (lbl.length) { ctx.put(lbl); ctx.put("+2"); break; }
      }
      ctx.putxnum("#%04X", "%u", nextW);
      break;
    case UROpType.MEM16:
      ismem = true;
      ctx.put("(");
      goto case UROpType.ADDR16;
    case UROpType.R8:
    case UROpType.R8NOM:
      ctx.put(URRegs8.ptr[opc&0x07UL]);
      break;
    case UROpType.R83:
    case UROpType.R83NOM:
      ctx.put(URRegs8.ptr[(opc>>3)&0x07UL]);
      break;
    case UROpType.PORTC: ctx.put("(C)"); break;
    case UROpType.PORTIMM: ctx.putxnum("(#%02X)", "(%u)", nextW&0xFF); break;
    case UROpType.R8XH: ctx.put("XH"); break;
    case UROpType.R8XL: ctx.put("XL"); break;
    case UROpType.R8YH: ctx.put("YH"); break;
    case UROpType.R8YL: ctx.put("YL"); break;
    case UROpType.R8A: ctx.put("A"); break;
    case UROpType.R8R: ctx.put("R"); break;
    case UROpType.R8I: ctx.put("I"); break;
    case UROpType.R16: ctx.put(URRegs16.ptr[(opc>>4)&0x03UL]); break;
    case UROpType.R16A: ctx.put(URRegs16a.ptr[(opc>>4)&0x03UL]); break;
    case UROpType.R16AF: ctx.put("AF"); break;
    case UROpType.R16AFX: ctx.put("AF'"); break;
    case UROpType.R16BC: ctx.put("BC"); break;
    case UROpType.R16DE: ctx.put("DE"); break;
    case UROpType.R16HL: ctx.put("HL"); break;
    case UROpType.R16IX: ctx.put("IX"); break;
    case UROpType.R16IY: ctx.put("IY"); break;
    case UROpType.R16SP: ctx.put("SP"); break;
    case UROpType.MSP: ctx.put("(SP)"); break;
    case UROpType.MBC: ctx.put("(BC)"); break;
    case UROpType.MDE: ctx.put("(DE)"); break;
    case UROpType.MHL: ctx.put("(HL)"); break;
    case UROpType.MIX0: ctx.put("(IX)"); break;
    case UROpType.MIY0: ctx.put("(IY)"); break;
    case UROpType.MIX:
      ctx.put("(IX");
      if (idx > 0) ctx.put("+");
      ctx.putnum("%d", idx);
      ctx.put(")");
      break;
    case UROpType.MIY:
      ctx.put("(IY");
      if (idx > 0) ctx.put("+");
      ctx.putnum("%d", idx);
      ctx.put(")");
      break;
    case UROpType.JRCOND: ctx.put(URCond.ptr[(opc>>3)&0x03U]); break;
    case UROpType.COND: ctx.put(URCond.ptr[(opc>>3)&0x07U]); break;
    case UROpType.BITN: ctx.putnum("%u", (opc>>3)&0x07U); break;
    case UROpType.RSTDEST: ctx.putxnum("#%02X", "%u", opc&0x38U); break;
    case UROpType.IM0: ctx.put("0"); break;
    case UROpType.IM1: ctx.put("1"); break;
    case UROpType.IM2: ctx.put("2"); break;
    default: assert(0); // we should never come here
  }
  if (ismem) ctx.put(")");
}


/// find the corresponding record in URInstructionsTable
public int urDisassembleFind (ref URDisState ctx, ushort addr, scope URGetByteCB getByte) {
  ubyte[8] buf;
  if (getByte is null) return -1;
  foreach (immutable n, ref ubyte b; buf[]) b = getByte(cast(ushort)(addr+n));
  if (buf.ptr[0] == 0xDDU || buf.ptr[0] == 0xFDU) {
    // dummy prefix
    if (isDDSensitive(buf.ptr[1])) return (buf.ptr[0] == 0xDDU ? 0 : 1);
  }
  uint ci = buf.ptr[0]|(buf.ptr[1]<<8)|(buf.ptr[2]<<16)|(buf.ptr[3]<<24);
  for (int opn = 0; opn < URInstructionsTable.length; ++opn) {
    // find command
    while (opn < URInstructionsTable.length && (ci&URInstructionsTable.ptr[opn].mask) != URInstructionsTable.ptr[opn].code) ++opn;
    if (opn >= URInstructionsTable.length) return (buf.ptr[0] == 0xEDU ? -2 : -1);
    // skip prefixes, determine command length
    uint f = URInstructionsTable.ptr[opn].mask;
    uint c = URInstructionsTable.ptr[opn].code;
    int bpos = 0;
    for (;; ++bpos) {
      if ((f&0xFFUL) != 0xFFUL) break;
      ubyte b = c&0xFFUL;
      if (b != 0xFDU && b != 0xDDU && b != 0xEDU && b != 0xCBU) break;
      f >>= 8;
      c >>= 8;
    }
    // are there any operands?
    if (URInstructionsTable.ptr[opn].ops.ptr[0] == UROpType.NONE) return opn;
    // is this CB-prefixed?
    if ((URInstructionsTable.ptr[opn].code&0xFFFFUL) == 0xCBDDUL ||
        (URInstructionsTable.ptr[opn].code&0xFFFFUL) == 0xCBFDUL) ++bpos; // skip displacement
    ubyte opc = buf.ptr[bpos];
    // do operands
    foreach (immutable n; 0..4) {
      if (n == 4) return cast(int)opn;
      auto op = URInstructionsTable.ptr[opn].ops.ptr[n];
      if (op == UROpType.NONE) return cast(int)opn;
      // check for valid operand
      if (op == UROpType.R8NOM) {
        if ((opc&0x07U) == 6) break; // bad (HL)
      }
      if (op == UROpType.R83NOM) {
        if (((opc>>3)&0x07U) == 6) break; // bad (HL)
      }
    }
  }
  return -1;
}


/// length of the instruction with the given record (returned from `urDisassembleFind()`)
public int urDisassembleLength (int idx) {
  if (idx == -2) return 2;
  if (idx < 0 || idx >= URInstructionsTable.length) return 1;
  if (idx < 2) return 1;
  int res = 0;
  uint m = URInstructionsTable.ptr[idx].mask;
  uint c = URInstructionsTable.ptr[idx].code;
  // I?/CB?
  //if ((m&0xFFFFUL) == 0xFFFFUL && (c&0xFF00UL) == 0xCBUL && ((c&0xFFUL) == 0xDDUL || (c&0xFFUL) == 0xFDUL)) return 4;
  // skip prefixes, determine command length
  for (;;) {
    ubyte b;
    if ((m&0xFFUL) != 0xFFUL) break;
    b = c&0xFFUL;
    if (b != 0xFDU && b != 0xDDU && b != 0xEDU && b != 0xCBU) break;
    m >>= 8;
    c >>= 8; ++res;
  }
  // is this CB-prefixed?
  if ((URInstructionsTable.ptr[idx].code&0xFFFFUL) == 0xCBDDUL ||
      (URInstructionsTable.ptr[idx].code&0xFFFFUL) == 0xCBFDUL) m >>= 8;
  // count opcodes
  while (m != 0) { m >>= 8; ++res; }
  // process operands
  oploop: foreach (immutable n; 0..3) {
    auto op = URInstructionsTable.ptr[idx].ops.ptr[n];
    switch (op) {
      case UROpType.NONE: break oploop;
      // command with displacement
      case UROpType.MIX: case UROpType.MIY: ++res; break;
      // command has immediate operand
      case UROpType.IMM8: case UROpType.ADDR8: case UROpType.PORTIMM: ++res; break;
      case UROpType.IMM16: case UROpType.ADDR16: case UROpType.MEM16: res += 2; break;
      default: break;
    }
  }
  return res;
}


/// disassemble one command, return command length or <0 on error
public int urDisassembleOne (ref URDisState ctx, ushort addr, scope URGetByteCB getByte, scope URFindLabelByAddrCB findLabel=null) {
  ubyte[8] buf;
  int res, idx = 0;
  uint ci, f, c;
  ubyte opc;
  int bpos, opn, op;
  ushort nextW;

  ctx.clear();
  ctx.resetbuf();
  scope(failure) ctx.clear();

  if (getByte is null) return -1;
  foreach (immutable n, ref ubyte b; buf[]) b = getByte(cast(ushort)(addr+n));

  if (buf.ptr[0] == 0xDDU || buf.ptr[0] == 0xFDU) {
    // dummy prefix
    if (isDDSensitive(buf.ptr[1])) {
      ctx.iidx = (buf.ptr[0] == 0xDDU ? 0 : 1);
      ctx.put(URMnemonics.ptr[buf.ptr[0] == 0xDDU ? URMnemo.NOPX : URMnemo.NOPY]);
      ctx.mnem = ctx.buf[0..ctx.bufpos];
      return 1;
    }
    // take possible I? displacement
    idx = cast(byte)buf.ptr[2];
  }
  ci = buf.ptr[0]|(buf.ptr[1]<<8)|(buf.ptr[2]<<16)|(buf.ptr[3]<<24);
  for (opn = 0; opn < URInstructionsTable.length; ++opn) {
    res = 0;
    ctx.resetbuf();
    // find command
    for (; opn < URInstructionsTable.length && (ci&URInstructionsTable.ptr[opn].mask) != URInstructionsTable.ptr[opn].code; ++opn) {}
    if (opn >= URInstructionsTable.length) {
      ctx.iidx = -1;
      ctx.put("DB\t");
      ctx.mnem = ctx.buf[0..ctx.bufpos-1];
      auto opstp = ctx.bufpos;
      if (buf.ptr[0] == 0xEDU) {
        ctx.putxnum("#%02X,", "%u,", buf.ptr[0]);
        ctx.ops[0] = ctx.buf[opstp..ctx.bufpos-1];
        opstp = ctx.bufpos;
        ctx.putxnum("#%02X", "%u", buf.ptr[1]);
        ctx.ops[1] = ctx.buf[opstp..ctx.bufpos];
        return 2;
      } else {
        ctx.putxnum("#%02X", "%u", buf.ptr[0]);
        ctx.ops[0] = ctx.buf[opstp..ctx.bufpos];
        return 1;
      }
    }
    // skip prefixes, determine command length
    f = URInstructionsTable.ptr[opn].mask;
    c = URInstructionsTable.ptr[opn].code;
    for (bpos = 0; ; ++bpos) {
      if ((f&0xFFUL) != 0xFFUL) break;
      ubyte b = c&0xFFUL;
      if (b != 0xFDU && b != 0xDDU && b != 0xEDU && b != 0xCBU) break;
      f >>= 8;
      c >>= 8;
      ++res;
    }
    // is this CB-prefixed?
    if ((URInstructionsTable.ptr[opn].code&0xFFFFUL) == 0xCBDDUL ||
        (URInstructionsTable.ptr[opn].code&0xFFFFUL) == 0xCBFDUL) f >>= 8;
    while (f != 0) { f >>= 8; ++res; }
    // copy mnemonics
    ctx.iidx = opn;
    ctx.put(URMnemonics.ptr[URInstructionsTable.ptr[opn].mnemo]);
    ctx.mnem = ctx.buf[0..ctx.bufpos];
    // are there any operands?
    if (URInstructionsTable.ptr[opn].ops.ptr[0] == UROpType.NONE) return res;
    // is this CB-prefixed?
    if (((URInstructionsTable.ptr[opn].code&0xFFFFUL) == 0xCBDDUL) ||
        ((URInstructionsTable.ptr[opn].code&0xFFFFUL) == 0xCBFDUL)) {
      ++bpos; // skip displacement
    } else {
      if ((URInstructionsTable.ptr[opn].ops.ptr[0] == UROpType.MIX || URInstructionsTable.ptr[opn].ops.ptr[0] == UROpType.MIY) &&
          URInstructionsTable.ptr[opn].ops.ptr[1] == UROpType.IMM8 &&
          URInstructionsTable.ptr[opn].ops.ptr[2] == UROpType.NONE) ++bpos; // skip displacement
    }
    opc = buf.ptr[bpos++];
    nextW = cast(ushort)(buf.ptr[bpos]|(buf.ptr[bpos+1]<<8));
    // do operands
    foreach (immutable n; 0..4) {
      if (n == 3) return res;
      op = URInstructionsTable.ptr[opn].ops.ptr[n];
      if (op == UROpType.NONE) return res;
      // check for valid operand
      if (op == UROpType.R8NOM) {
        if ((opc&0x07U) == 6) break; // bad (HL)
      }
      if (op == UROpType.R83NOM) {
        if (((opc>>3)&0x07U) == 6) break; // bad (HL)
      }
      // command with displacement?
      if (op == UROpType.MIX || op == UROpType.MIY) ++res;
      // command has immediate operand?
      if (op == UROpType.IMM8 || op == UROpType.ADDR8 || op == UROpType.PORTIMM) ++res;
      if (op == UROpType.IMM16 || op == UROpType.ADDR16 || op == UROpType.MEM16) res += 2;
      // add delimiter
      ctx.put(n ? "," : "\t");
      // decode operand
      auto opstp = ctx.bufpos;
      urdisOp2Str(ctx, op, addr, opc, nextW, idx, findLabel);
      ctx.ops[n] = ctx.buf[opstp..ctx.bufpos];
    }
  }
  return -1;
}


// ////////////////////////////////////////////////////////////////////////// //
///
public struct URAsmParser {
private:
  const(char)[] text;
  uint textpos;

pure nothrow @trusted @nogc:
  this (const(char)[] atext) { text = atext; }
  void setup (const(char)[] atext) { text = atext; }
  URAsmParser opSlice (uint lo, uint hi) pure const {
    if (hi <= lo || lo >= text.length) return URAsmParser.init;
    if (hi > text.length) hi = cast(uint)text.length;
    return URAsmParser(text[lo..hi]);
  }
  @property uint tell () pure const { pragma(inline, true); return textpos; }
  void seek (uint pos) pure { pragma(inline, true); if (pos > text.length) pos = cast(uint)text.length; textpos = pos; }
  URAsmParser slice (uint len) pure const {
    if (len > text.length) len = cast(uint)text.length;
    if (textpos >= text.length) return URAsmParser.init;
    if (text.length-textpos < len) len = cast(uint)text.length-textpos;
    return URAsmParser(text[textpos..textpos+len]);
  }
  @property bool empty () const { pragma(inline, true); return (textpos >= text.length); }
  @property bool eol () const { pragma(inline, true); return (textpos >= text.length || text.ptr[textpos] == ':' || text.ptr[textpos] == ';'); }
  @property char front () const { pragma(inline, true); return (textpos < text.length ? text.ptr[textpos] : '\x00'); }
  @property char ahead () const { pragma(inline, true); return (textpos+1 < text.length ? text.ptr[textpos+1] : '\x00'); }
  @property char peek (uint ofs) const { pragma(inline, true); return (ofs < text.length && textpos+ofs < text.length ? text.ptr[textpos+ofs] : '\x00'); }
  void popFront () { if (textpos < text.length) ++textpos; }
  void skipBlanks () { while (textpos < text.length && text.ptr[textpos] <= ' ') ++textpos; }

static:
  char tolower (char ch) { pragma(inline, true); return (ch >= 'A' && ch <= 'Z' ? cast(char)(ch+32) : ch); }
  char toupper (char ch) { pragma(inline, true); return (ch >= 'a' && ch <= 'z' ? cast(char)(ch-32) : ch); }
  bool isdigit (char ch) { pragma(inline, true); return (ch >= '0' && ch <= '9'); }
  bool isalpha (char ch) { pragma(inline, true); return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z'); }
  bool isalnum (char ch) { pragma(inline, true); return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9'); }

  int digitInBase (char ch, int base=10) {
    pragma(inline, true);
    return
      ch >= '0' && ch <= '9' && ch-'0' < base ? ch-'0' :
      base > 10 && ch >= 'A' && ch < 'Z' && ch-'A'+10 < base ? ch-'A'+10 :
      base > 10 && ch >= 'a' && ch < 'z' && ch-'a'+10 < base ? ch-'a'+10 :
      -1;
  }

  bool strEquCI (const(char)[] s0, const(char)[] s1) {
    if (s0.length != s1.length) return false;
    foreach (immutable idx, char c0; s0) {
      if (c0 >= 'a' && c0 <= 'z') c0 -= 32;
      char c1 = s1.ptr[idx];
      if (c1 >= 'a' && c1 <= 'z') c1 -= 32;
      if (c0 != c1) return false;
    }
    return true;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
///
public bool delegate (const(char)[] lbl) nothrow @trusted @nogc urIsValidLabelName;

static this () { import std.functional : toDelegate; urIsValidLabelName = toDelegate(&urIsValidLabelNameDef); }

///
public bool urIsValidLabelNameDef (const(char)[] lbl) nothrow @trusted @nogc {
  if (lbl.length == 0) return false;
  if (URAsmParser.isalpha(lbl.ptr[0])) {
    foreach (char ch; lbl[1..$]) {
      if (ch < 128 && !URAsmParser.isalnum(ch) && ch != '$' && ch != '.' && ch != '_' && ch != '@') return false;
    }
    foreach (string s; URMnemonics) if (URAsmParser.strEquCI(s, lbl)) return false;
    foreach (string s; URRegs8) if (URAsmParser.strEquCI(s, lbl)) return false;
    foreach (string s; URRegs16) if (URAsmParser.strEquCI(s, lbl)) return false;
    foreach (string s; URRegs16a) if (URAsmParser.strEquCI(s, lbl)) return false;
    foreach (string s; URCond) if (URAsmParser.strEquCI(s, lbl)) return false;
    if (URAsmParser.strEquCI("DB", lbl)) return false;
    if (URAsmParser.strEquCI("DW", lbl)) return false;
    if (URAsmParser.strEquCI("DS", lbl)) return false;
    if (URAsmParser.strEquCI("DZ", lbl)) return false;
    if (URAsmParser.strEquCI("DEFB", lbl)) return false;
    if (URAsmParser.strEquCI("DEFW", lbl)) return false;
    if (URAsmParser.strEquCI("DEFS", lbl)) return false;
    if (URAsmParser.strEquCI("DEFZ", lbl)) return false;
    if (URAsmParser.strEquCI("DEFM", lbl)) return false;
    if (URAsmParser.strEquCI("ORG", lbl)) return false;
    if (URAsmParser.strEquCI("ENT", lbl)) return false;
  } else {
    if (lbl.ptr[0] != '$' && lbl.ptr[0] != '.' && lbl.ptr[0] != '_' && lbl.ptr[0] != '@') return false;
    foreach (char ch; lbl[1..$]) {
      if (ch < 128 && !URAsmParser.isalnum(ch) && ch != '$' && ch != '.' && ch != '_' && ch != '@') return false;
    }
  }
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/// fixup types
public enum URAsmFixup {
  None, ///
  Word, ///
  LoByte, ///
  HiByte, ///
}


public int delegate (const(char)[] lbl, ushort addr, out bool defined, out URAsmFixup fixtype) urFindLabelByNameFn; ///

/// pr is right after '(', spaces skipped; should parse all args and stop on closing ')'
public void delegate (const(char)[] lbl, ref URAsmParser pr, out URExprValue res, ushort addr) urCallFunctionFn;

/// get "special value" started with '*' or '=', pr is right after valtype, spaces skipped; should parse whole name
public void delegate (char valtype, ref URAsmParser pr, out URExprValue res, ushort addr) urGetValueFn;


enum URAsmExprError {
  None,
  Eos,
  Div0,
  Parens,
  Number,
  String,
  Label,
  Term,
  Func,
  Type,
  Marg,
  Fixup,
  Mem,
  Oper,
}

static immutable string[URAsmExprError.max+1] URAsmExprErrorMsg = [
  "no error",
  "unexpected end of text",
  "division by zero",
  "unbalanced parentheses",
  "invalid number",
  "invalid string",
  "invalid label",
  "term expected",
  "function expected",
  "invalid type",
  "invalid special argument",
  "invalid fixup",
  "invalid memory access",
  "invalid operand",
];

void EERROR (URAsmExprError code) { throw new Exception("urasm expression error: "~URAsmExprErrorMsg[code]); }


// ////////////////////////////////////////////////////////////////////////// //
/// expression parser
public struct URExprValue {
  int val; ///
  char[] str; /// null: non-string value; val is set for strings too
  URAsmFixup fixuptype; /// can be changed only by low() and high()
  bool defined = true;

  @property bool isString () const pure nothrow @trusted @nogc { pragma(inline, true); return (str !is null); } ///

  void clear () pure nothrow @trusted @nogc { val = 0; str = null; fixuptype = URAsmFixup.None; defined = true; } ///
}

struct URAOperand {
  UROpType type; // deduced type
  char[] s; // string value, if any
  int v; // expression value or index
  bool defined; // expression defined?
  URAsmFixup fixuptype;

  string toString () const {
    import std.format : format;
    return "<%s>: v=%d; defined=%s".format(type, v, defined);
  }
}


struct ExprInfo {
  ushort addr; // current address
  bool defined; // true: all used labels are defined
  bool logDone;
  bool logRes;
}


// do math; op0 is the result
alias ExprDoItFn = void function (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei);

struct ExprOperator {
  char sn; // short name or 0
  string ln; // long name or null if `sn`!=0
  int prio; // priority
  ExprDoItFn doer;
}


void propagateFixup (ref URExprValue op0, ref URExprValue op1) {
  if (op0.fixuptype == URAsmFixup.None) {
    op0.fixuptype = op1.fixuptype;
  } else if (op0.fixuptype == URAsmFixup.Word) {
    if (op1.fixuptype != URAsmFixup.None) op0.fixuptype = op1.fixuptype;
  } else if (op1.fixuptype != URAsmFixup.None && op0.fixuptype != op1.fixuptype) {
    op1.clear;
    op0.clear;
    EERROR(URAsmExprError.Fixup);
  }
}


void mdoBitNot (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) {
  op0.val = ~op0.val;
  op0.fixuptype = URAsmFixup.None;
}
void mdoLogNot (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) {
  op0.val = !op0.val;
  op0.fixuptype = URAsmFixup.None;
}
void mdoBitAnd (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) {
  op0.val &= op1.val;
  if (op1.val == 0) op0.fixuptype = URAsmFixup.None;
  else if (op0.fixuptype != URAsmFixup.None) {
    switch (op1.val) {
      case 0x00ff: op0.fixuptype = (op0.fixuptype == URAsmFixup.Word ? URAsmFixup.LoByte : URAsmFixup.None); break;
      case 0xff00: op0.fixuptype = (op0.fixuptype == URAsmFixup.Word ? URAsmFixup.HiByte : URAsmFixup.None); break;
      default: break;
    }
  } else {
    propagateFixup(op0, op1);
  }
}
void mdoBitOr (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val |= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoBitXor (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val ^= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLShift (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val <<= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoRShift (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val >>= op1.val; }
void mdoMul (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val *= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoDiv (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { if (op1.val == 0) EERROR(URAsmExprError.Div0); op0.val /= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoMod (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { if (op1.val == 0) EERROR(URAsmExprError.Div0); op0.val %= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoAdd (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val += op1.val; propagateFixup(op0, op1); }
void mdoSub (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val -= op1.val; propagateFixup(op0, op1); }
void mdoLogLess (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val = op0.val < op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLogGreat (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val = op0.val > op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLogEqu (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val = op0.val == op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLogNEqu (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val = op0.val != op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLogLEqu (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val = op0.val >= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLogGEqu (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { op0.val = op0.val >= op1.val; op0.fixuptype = URAsmFixup.None; }
void mdoLogAnd (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { ei.logRes = op0.val = (op0.val && op1.val); if (!op0.val) ei.logDone = 1; op0.fixuptype = URAsmFixup.None; }
void mdoLogOr (ref URExprValue op0, ref URExprValue op1, ref ExprInfo ei) { ei.logRes = op0.val = (op0.val || op1.val); if (op0.val) ei.logDone = 1; op0.fixuptype = URAsmFixup.None; }


// priority level 1 -- opertiors like "." and "[]", function calls
// priority level 2 -- unary opertiors like "!" and "~"
// short forms must be put before long
// priorities must be sorted
static immutable ExprOperator[23] operators = [
  ExprOperator('~', null, 2, &mdoBitNot),
  ExprOperator('!', null, 2, &mdoLogNot),
  //
  ExprOperator(0, "<<", 3, &mdoLShift),
  ExprOperator(0, ">>", 3, &mdoRShift),
  //
  ExprOperator('&', null, 4, &mdoBitAnd),
  //
  ExprOperator('|', null, 5, &mdoBitOr),
  ExprOperator('^', null, 5, &mdoBitXor),
  //
  ExprOperator('*', null, 6, &mdoMul),
  ExprOperator('/', null, 6, &mdoDiv),
  ExprOperator('%', null, 6, &mdoMod),
  //
  ExprOperator('+', null, 7, &mdoAdd),
  ExprOperator('-', null, 7, &mdoSub),
  //
  ExprOperator(0, "&&", 8, &mdoLogAnd),
  //
  ExprOperator(0, "||", 9, &mdoLogOr),
  //
  ExprOperator('<', null, 10, &mdoLogLess),
  ExprOperator('>', null, 10, &mdoLogGreat),
  ExprOperator('=', null, 10, &mdoLogEqu),
  ExprOperator(0, "==", 10, &mdoLogEqu),
  ExprOperator(0, "!=", 10, &mdoLogNEqu),
  ExprOperator(0, "<>", 10, &mdoLogNEqu),
  ExprOperator(0, "<=", 10, &mdoLogLEqu),
  ExprOperator(0, ">=", 10, &mdoLogGEqu),
  ExprOperator(0, null, -1, null),
];
enum UnaryPriority = 2;
enum MaxPriority = operators[$-2].prio;
// WARNING! keep this in sync with operator table!
enum LogAndPriority = 8;
enum LogOrPriority  = 9;


///////////////////////////////////////////////////////////////////////////////
// expression parser engine

// quote is not skipped
void parseStr (ref URAsmParser pr, ref URExprValue res) {
  int base, f, n;
  char[] rstr;
  if (pr.empty) EERROR(URAsmExprError.Eos);
  char qch = pr.front;
  pr.popFront();
  for (;;) {
    if (pr.empty) EERROR(URAsmExprError.Eos);
    char ch = pr.front;
    pr.popFront();
    if (ch == '\\') {
      if (pr.empty) EERROR(URAsmExprError.Eos);
      ch = pr.front;
      pr.popFront();
      switch (ch) {
        case 'a': rstr ~= '\a'; break;
        case 'b': rstr ~= '\b'; break;
        case 'e': rstr ~= '\x1b'; break;
        case 'f': rstr ~= '\f'; break;
        case 'n': rstr ~= '\n'; break;
        case 'r': rstr ~= '\r'; break;
        case 't': rstr ~= '\t'; break;
        case 'v': rstr ~= '\v'; break;
        case 'z': rstr ~= '\0'; break;
        case 'x': case 'X': // hex
          base = 16;
          f = 2;
         donum:
          if (pr.empty) EERROR(URAsmExprError.Eos);
          for (n = 0; f > 0; --f) {
            if (pr.empty) break;
            int d = URAsmParser.digitInBase(pr.front, base);
            if (d < 0) break;
            n *= base;
            n += d;
          }
          rstr ~= cast(char)n;
          break;
        case '0': // octal
          base = 8;
          f = 4;
          goto donum;
        case '1': .. case '9': // decimal
          base = 10;
          f = 3;
          goto donum;
        default: rstr ~= ch; break; // others
      }
    } else {
      if (ch == qch) break;
      rstr ~= ch;
    }
  }
  if (rstr.length == 0) { rstr.length = 1; rstr.length = 0; } // so it won't be null
  res.str = rstr;
}


void parseNumber (ref URAsmParser pr, ref URExprValue res) {
  int n = 0, base = 0, nhex = 0;
  bool wantTrailingH = false;
  if (pr.empty) EERROR(URAsmExprError.Eos);
  res.val = 0;
  char ch = pr.front;
  switch (ch) {
    case '0':
      // this can be 0x prefix
      switch (pr.ahead) {
        case '0': .. case '9': EERROR(URAsmExprError.Number); assert(0); // no octals
        case 'B': case 'b': base = 2; pr.popFront(); pr.popFront(); break;
        case 'O': case 'o': base = 8; pr.popFront(); pr.popFront(); break;
        case 'D': case 'd': base = 10; pr.popFront(); pr.popFront(); break;
        case 'X': case 'x': base = 16; pr.popFront(); pr.popFront(); break;
        default: break;
      }
      break;
    case '%': base = 2; pr.popFront(); break;
    case '#': case '$': base = 16; pr.popFront(); break;
    case '&':
      switch (pr.ahead) {
        case 'B': case 'b': base = 2; pr.popFront(); pr.popFront(); break;
        case 'O': case 'o': base = 8; pr.popFront(); pr.popFront(); break;
        case 'D': case 'd': base = 10; pr.popFront(); pr.popFront(); break;
        case 'X': case 'x': base = 16; pr.popFront(); pr.popFront(); break;
        case 'H': case 'h': base = 16; pr.popFront(); pr.popFront(); break;
        default: EERROR(URAsmExprError.Number); // no octals
      }
      break;
    default: break;
  }
  // if base != 0, parse in dec and in hex, and check last char
  if (pr.empty) EERROR(URAsmExprError.Eos);
  if (URAsmParser.digitInBase(pr.front, (base ? base : 16)) < 0) EERROR(URAsmExprError.Number);
  while (!pr.empty) {
    int d;
    ch = pr.front;
    if (ch == '_') { pr.popFront(); continue; }
    if (base) {
      d = URAsmParser.digitInBase(ch, base);
      if (d < 0) break;
      n = n*base+d;
    } else {
      if (wantTrailingH) {
        d = URAsmParser.digitInBase(ch, 16);
        if (d < 0) break;
        nhex = nhex*16+d;
      } else {
        d = URAsmParser.digitInBase(ch, 10);
        if (d < 0) {
          d = URAsmParser.digitInBase(ch, 16);
          if (d < 0) break;
          wantTrailingH = true;
          nhex = nhex*16+d;
        } else {
          n = n*10+d;
          nhex = nhex*16+d;
        }
      }
    }
    pr.popFront();
  }
  if (base == 0) {
    if (wantTrailingH) {
      if (pr.empty || (pr.front != 'H' && pr.front != 'h')) EERROR(URAsmExprError.Number);
      n = nhex;
    } else {
      if (!pr.empty && (pr.front == 'H' || pr.front == 'h')) { n = nhex; pr.popFront(); }
    }
  }
  res.val = n;
}


void getAddr (const(char)[] lbl, ref URExprValue res, ref ExprInfo ei) {
  if (urFindLabelByNameFn is null) EERROR(URAsmExprError.Label);
  res.fixuptype = URAsmFixup.None;
  res.val = urFindLabelByNameFn(lbl, ei.addr, res.defined, res.fixuptype);
  if (!res.defined) ei.defined = false;
}


// throw on invalid label, or return slice of `dbuf`
char[] readLabelName (char[] dbuf, ref URAsmParser pr) {
  uint dbpos = 0;
  while (!pr.empty) {
    char ch = pr.front;
    if (URAsmParser.isalnum(ch) || ch == '$' || ch == '.' || ch == '_' || ch == '@' || ch >= 128) {
      if (dbpos >= dbuf.length) EERROR(URAsmExprError.Label);
      dbuf[dbpos++] = ch;
      pr.popFront();
    } else {
      break;
    }
  }
  if (dbpos < 1 || !urIsValidLabelName(dbuf[0..dbpos])) EERROR(URAsmExprError.Label);
  return dbuf[0..dbpos];
}


void term (ref URAsmParser pr, ref URExprValue res, ref ExprInfo ei) {
  res.str = null;
  pr.skipBlanks();
  if (pr.empty) EERROR(URAsmExprError.Eos);
  char ch = pr.front;
  switch (ch) {
    case '[': case '(':
      pr.popFront();
      ch = (ch == '[' ? ']' : ')');
      expression(pr, res, ei);
      if (pr.empty) EERROR(URAsmExprError.Eos);
      if (pr.front != ch) EERROR(URAsmExprError.Parens);
      pr.popFront();
      break;
    case '0': .. case '9': case '#': case '%':
      parseNumber(pr, res);
      break;
    case '$':
      if (URAsmParser.digitInBase(pr.ahead, 16) >= 0) {
        parseNumber(pr, res);
      } else {
        res.val = ei.addr;
        res.fixuptype = URAsmFixup.Word;
        pr.popFront();
      }
      break;
    case '&':
      switch (pr.ahead) {
        case 'H': case 'h':
        case 'O': case 'o':
        case 'B': case 'b':
        case 'D': case 'd':
          parseNumber(pr, res);
          return;
        default: break;
      }
      goto default;
    case '"': // char or 2 chars
    case '\'': // char or 2 reversed chars
      res.val = 0;
      parseStr(pr, res);
      if (res.str.length == 1) {
        res.val = cast(ubyte)res.str[0];
      } else if (res.str.length >= 2) {
        res.val = (cast(ubyte)res.str[0])<<(ch == '"' ? 0 : 8);
        res.val |= (cast(ubyte)res.str[1])<<(ch == '"' ? 8 : 0);
      }
      break;
    case ';':
    case ':':
      EERROR(URAsmExprError.Term);
      assert(0);
    case ')':
    case ']':
      return;
    case '=':
    case '*':
      pr.popFront();
      if (pr.empty || pr.front <= ' ' || pr.eol) EERROR(URAsmExprError.Marg);
      if (urGetValueFn !is null) {
        urGetValueFn(ch, pr, res, ei.addr);
      } else {
        EERROR(URAsmExprError.Marg);
      }
      break;
    default:
      char[64] lblbuf;
      auto lbl = readLabelName(lblbuf[], pr);
      if (lbl is null) EERROR(URAsmExprError.Label);
      pr.skipBlanks();
      if (!pr.empty && pr.front == '(') {
        // function call
        pr.popFront();
        pr.skipBlanks();
        if (urCallFunctionFn !is null) {
          urCallFunctionFn(lbl, pr, res, ei.addr);
          pr.skipBlanks();
          if (!pr.empty && pr.front == ')') { pr.popFront(); break; }
        }
        EERROR(URAsmExprError.Func);
      } else {
        // just a label
        if (!ei.logDone) getAddr(lbl, res, ei);
      }
      break;
  }
}


const(ExprOperator)* getOperator (int prio, ref URAsmParser pr, ref ExprInfo ei) {
  if (pr.empty) return null;
  char opc = pr.front;
  int oplen = 1;
  const(ExprOperator)* res = operators.ptr, cur;
  for (cur = res, res = null; cur.prio >= 0; ++cur) {
    if (cur.sn) {
      if (oplen > 1) continue;
      if (opc == cur.sn) res = cur;
    } else {
      int l = cast(int)cur.ln.length;
      if (l < oplen) continue;
      bool ok = true;
      foreach (immutable idx; 0..l) if (pr.peek(idx) != cur.ln[idx]) { ok = false; break; }
      if (ok) { res = cur; oplen = l; }
    }
  }
  if (res !is null && res.prio != prio) res = null;
  if (res) foreach (immutable _; 0..oplen) pr.popFront(); // eat operator
  return res;
}


void checkNotStr (ref URExprValue res, ref URExprValue o1) {
  if ((res.str !is null && res.str.length > 2) || (o1.str !is null && o1.str.length > 2)) {
    o1.clear();
    res.clear();
    EERROR(URAsmExprError.Type);
  }
}


void expressionDo (int prio, ref URAsmParser pr, ref URExprValue res, ref ExprInfo ei) {
  const(ExprOperator)* op;
  URExprValue o1;
  pr.skipBlanks();
  if (pr.empty) EERROR(URAsmExprError.Eos);
  if (pr.front == ')' || pr.front == ']') return;
  if (prio <= 0) { term(pr, res, ei); return; }
  o1.clear();
  if (prio == UnaryPriority) {
    bool wasIt = false;
    for (;;) {
      pr.skipBlanks();
      if ((op = getOperator(prio, pr, ei)) is null) break;
      expressionDo(prio, pr, res, ei);
      if (!ei.logDone) {
        checkNotStr(res, o1);
        op.doer(res, o1, ei);
      } else {
        res.fixuptype = URAsmFixup.None;
        res.val = ei.logRes;
      }
      wasIt = true;
    }
    if (!wasIt) expressionDo(prio-1, pr, res, ei);
    return;
  }
  // first operand
  expressionDo(prio-1, pr, res, ei);
  // go on
  bool old = ei.logDone;
  for (;;) {
    pr.skipBlanks();
    if (pr.empty || pr.front == ';' || pr.front == ':' || pr.front == ')' || pr.front == ']') break;
    if ((op = getOperator(prio, pr, ei)) is null) break;
    if (!ei.logDone) {
      switch (prio) {
        case LogAndPriority: // &&
          if (!res.val) { ei.logDone = true; ei.logRes = 0; }
          break;
        case LogOrPriority: // ||
          if (res.val) { ei.logDone = true; ei.logRes = (res.val != 0); }
          break;
        default: break;
      }
    }
    expressionDo(prio-1, pr, o1, ei); // second operand
    if (!ei.logDone) {
      checkNotStr(res, o1);
      op.doer(res, o1, ei);
      o1.clear();
    } else {
      res.fixuptype = URAsmFixup.None;
      res.val = ei.logRes;
    }
  }
  ei.logDone = old;
}


void expression (ref URAsmParser pr, ref URExprValue res, ref ExprInfo ei) {
  bool neg = false;
  pr.skipBlanks();
  if (pr.empty) EERROR(URAsmExprError.Eos);
  switch (pr.front) {
    case '-': neg = true; pr.popFront(); break;
    case '+': neg = false; pr.popFront(); break;
    default: break;
  }
  if (pr.empty) EERROR(URAsmExprError.Eos);
  expressionDo(MaxPriority, pr, res, ei);
  if (neg) res.val = -(res.val);
  pr.skipBlanks(); // for convenience
}


public void urExpressionEx (ref URAsmParser pr, ref URExprValue res, ushort addr) {
  ExprInfo ei;
  res.clear();
  if (pr.empty) EERROR(URAsmExprError.Eos);
  ei.addr = addr;
  ei.defined = true;
  ei.logDone = false;
  ei.logRes = 0;
  expression(pr, res, ei);
  res.defined = ei.defined;
}


public int urExpression (ref URAsmParser pr, ushort addr, out bool defined, out URAsmFixup fixuptype) {
  URExprValue res;
  defined = true;
  fixuptype = URAsmFixup.None;
  urExpressionEx(pr, res, addr);
  fixuptype = res.fixuptype;
  defined = res.defined;
  if (res.str !is null && res.str.length > 2) EERROR(URAsmExprError.Type);
  return res.val;
}


// ////////////////////////////////////////////////////////////////////////// //
// operand parser

// possible types:
//   UROpType.MHL
//   UROpType.MDE
//   UROpType.MBC
//   UROpType.MSP
//   UROpType.MIX
//   UROpType.MIY
//   UROpType.MIX0  ; no displacement
//   UROpType.MIY0  ; no displacement
//   UROpType.MEM16
//   UROpType.R8I
//   UROpType.R8R
//   UROpType.R8: v is 8-bit register index; warning: v==1 may be UROpType.COND(3)
//   UROpType.COND: v is condition index (warning: v==3 may be UROpType.R8(1))
//   UROpType.R16HL
//   UROpType.R16DE
//   UROpType.R16BC
//   UROpType.R16AF
//   UROpType.R16SP
//   UROpType.R16IX
//   UROpType.R16IY
//   UROpType.R16AFX
//   UROpType.R8XH
//   UROpType.R8YH
//   UROpType.R8XL
//   UROpType.R8YL
//   UROpType.IMM16
// trailing blanks skipped
void urNextOperand (ref URAsmParser pr, out URAOperand op, ushort addr) {
  op.defined = true;
  pr.skipBlanks();
  if (pr.eol) return;
  op.fixuptype = URAsmFixup.None;

  UROpType ot = UROpType.NONE;
  // memory access?
  if (pr.front == '(') {
    pr.popFront();
    pr.skipBlanks();
    if (pr.empty) EERROR(URAsmExprError.Mem);
    // (C) is special
    if ((pr.front == 'C' || pr.front == 'c') && (pr.ahead <= ' ' || pr.ahead == ')')) {
      op.type = UROpType.PORTC;
      pr.popFront();
      pr.skipBlanks();
      if (pr.empty || pr.front != ')') EERROR(URAsmExprError.Mem);
      pr.popFront();
      return;
    }
    // check registers
    bool doPop = true;
         if ((pr.front == 'H' || pr.front == 'h') && (pr.ahead == 'L' || pr.ahead == 'l')) ot = UROpType.MHL;
    else if ((pr.front == 'D' || pr.front == 'd') && (pr.ahead == 'E' || pr.ahead == 'e')) ot = UROpType.MDE;
    else if ((pr.front == 'B' || pr.front == 'b') && (pr.ahead == 'C' || pr.ahead == 'c')) ot = UROpType.MBC;
    else if ((pr.front == 'S' || pr.front == 's') && (pr.ahead == 'P' || pr.ahead == 'p')) ot = UROpType.MSP;
    else if ((pr.front == 'I' || pr.front == 'i') && (pr.ahead == 'X' || pr.ahead == 'x'|| pr.ahead == 'Y' || pr.ahead == 'y')) {
      doPop = false;
      ot = (pr.ahead == 'X' || pr.ahead == 'x' ? UROpType.MIX : UROpType.MIY);
      pr.popFront();
      pr.popFront();
      pr.skipBlanks();
      if (pr.empty) EERROR(URAsmExprError.Mem);
      if (pr.front == '+' || pr.front == '-') {
        // expression
        op.v = urExpression(pr, addr, op.defined, op.fixuptype);
        if (op.defined) {
          if (op.v < byte.min || op.v > byte.max) EERROR(URAsmExprError.Mem);
        } else {
          op.v = 1;
        }
      } else {
        ot = (ot == UROpType.MIX ? UROpType.MIX0 : UROpType.MIY0);
      }
    } else {
      // expression
      doPop = false;
      op.v = urExpression(pr, addr, op.defined, op.fixuptype);
      ot = UROpType.MEM16;
    }
    if (ot == UROpType.NONE) EERROR(URAsmExprError.Mem);
    if (doPop) { pr.popFront(); pr.popFront(); }
    pr.skipBlanks();
    //conwriteln("empty=", pr.empty);
    //conwriteln("front=", pr.front);
    if (pr.empty || pr.front != ')') EERROR(URAsmExprError.Mem);
    pr.popFront();
    op.type = ot;
    pr.skipBlanks();
    return;
  }

  // registers?
  uint tklen = 0;

  void doCheck (string tk, UROpType type, int vv=0) {
    foreach (immutable idx, char ch; tk[]) {
      char pc = pr.peek(cast(uint)idx);
      if (pc >= 'a' && pc <= 'z') pc -= 32;
      if (pc != ch) return;
    }
    ot = type;
    tklen = cast(uint)tk.length;
    op.v = vv;
  }

  doCheck("I", UROpType.R8I);
  doCheck("R", UROpType.R8R);

  doCheck("B", UROpType.R8, 0);
  doCheck("C", UROpType.R8, 1); //WARNING! this may be condition as well
  doCheck("D", UROpType.R8, 2);
  doCheck("E", UROpType.R8, 3);
  doCheck("H", UROpType.R8, 4);
  doCheck("L", UROpType.R8, 5);
  doCheck("A", UROpType.R8, 7);

  doCheck("Z", UROpType.COND, 1);
  //doCheck("C", UROpType.COND, 3);
  doCheck("P", UROpType.COND, 6);
  doCheck("M", UROpType.COND, 7);

  doCheck("NZ", UROpType.COND, 0);
  doCheck("NC", UROpType.COND, 2);
  doCheck("PO", UROpType.COND, 4);
  doCheck("PE", UROpType.COND, 5);

  doCheck("HL", UROpType.R16HL);
  doCheck("DE", UROpType.R16DE);
  doCheck("BC", UROpType.R16BC);
  doCheck("AF", UROpType.R16AF);
  doCheck("SP", UROpType.R16SP);
  doCheck("IX", UROpType.R16IX);
  doCheck("IY", UROpType.R16IY);
  doCheck("XH", UROpType.R8XH);
  doCheck("YH", UROpType.R8YH);
  doCheck("XL", UROpType.R8XL);
  doCheck("YL", UROpType.R8YL);

  doCheck("AF'", UROpType.R16AFX);
  doCheck("AFX", UROpType.R16AFX);
  doCheck("IXH", UROpType.R8XH);
  doCheck("IYH", UROpType.R8YH);
  doCheck("IXL", UROpType.R8XL);
  doCheck("IYL", UROpType.R8YL);

  if (ot != UROpType.NONE) {
    // got register or another reserved thing?
    char ch = pr.peek(tklen);
    if (ch == ';' || ch == ':' || ch == ',' || ch <= ' ') {
      op.type = ot;
      foreach (immutable _; 0..tklen) pr.popFront();
      pr.skipBlanks();
      return;
    }
  }

  // expression
  op.v = urExpression(pr, addr, op.defined, op.fixuptype);
  op.type = UROpType.IMM16;
  pr.skipBlanks();
}


// ////////////////////////////////////////////////////////////////////////// //
// assembler
bool urIsValidOp (ref URAOperand op, ushort addr, int opt) {
  if (opt == UROpType.NONE) return (op.type == UROpType.NONE);
  if (op.type == UROpType.NONE) return false;
  final switch (opt) {
    case UROpType.IMM8:
      if (op.type != UROpType.IMM16) return false;
      if (op.v < byte.min || op.v > ubyte.max) return false;
      return true;
    case UROpType.IMM16:
      if (op.type != UROpType.IMM16) return false;
      if (op.v < short.min || op.v > ushort.max) return false;
      return true;
    case UROpType.ADDR16:
      if (op.type != UROpType.IMM16) return false;
      if (op.v < short.min || op.v > ushort.max) return false;
      return true;
    case UROpType.ADDR8:
      if (op.type != UROpType.IMM16) return false;
      if (op.v < short.min || op.v > ushort.max) return false;
      if (op.defined) {
        int dist = op.v-(addr+2);
        if (dist < byte.min || dist > byte.max) return false;
      }
      return true;
    case UROpType.MEM16:
      if (op.type != UROpType.MEM16) return false;
      return true;
    case UROpType.R8:
    case UROpType.R83:
      if (op.type == UROpType.MHL) { op.v = 6; return true; } // (HL) is ok here
      goto case;
    case UROpType.R8NOM:
    case UROpType.R83NOM:
      // fix "C" condition
      if (op.type == UROpType.COND && op.v == 3) { op.type = UROpType.R8; op.v = 1; }
      if (op.type != UROpType.R8) return false;
      return true;
    case UROpType.PORTC:
      return (op.type == UROpType.PORTC);
    case UROpType.PORTIMM:
      if (op.type != UROpType.MEM16) return false; // mem, 'cause (n)
      if (op.defined && (op.v < ubyte.min || op.v > ubyte.max)) return false;
      return true;
    case UROpType.R8XH:
    case UROpType.R8XL:
    case UROpType.R8YH:
    case UROpType.R8YL:
    case UROpType.R8R:
    case UROpType.R8I:
    case UROpType.R16AF:
    case UROpType.R16AFX:
    case UROpType.R16BC:
    case UROpType.R16DE:
    case UROpType.R16HL:
    case UROpType.R16IX:
    case UROpType.R16IY:
    case UROpType.R16SP:
    case UROpType.MSP:
    case UROpType.MBC:
    case UROpType.MDE:
    case UROpType.MHL:
    case UROpType.MIX0:
    case UROpType.MIY0:
      return (op.type == opt);
    case UROpType.R8A:
      return (op.type == UROpType.R8 && op.v == 7);
    case UROpType.R16:
      if (op.type == UROpType.R16BC) { op.v = 0; return true; }
      if (op.type == UROpType.R16DE) { op.v = 1; return true; }
      if (op.type == UROpType.R16HL) { op.v = 2; return true; }
      if (op.type == UROpType.R16SP) { op.v = 3; return true; }
      return false;
    case UROpType.R16A:
      if (op.type == UROpType.R16BC) { op.v = 0; return true; }
      if (op.type == UROpType.R16DE) { op.v = 1; return true; }
      if (op.type == UROpType.R16HL) { op.v = 2; return true; }
      if (op.type == UROpType.R16AF) { op.v = 3; return true; }
      return false;
    case UROpType.MIX:
      if (op.type != UROpType.MIX && op.type != UROpType.MIX0) return false;
      if (op.defined && (op.v < byte.min || op.v > byte.max)) return false;
      return true;
    case UROpType.MIY:
      if (op.type != UROpType.MIY && op.type != UROpType.MIY0) return false;
      if (op.defined && (op.v < byte.min || op.v > byte.max)) return false;
      return true;
    case UROpType.JRCOND:
      // fix "C" condition
      if (op.type == UROpType.R8 && op.v == 1) { op.type = UROpType.COND; op.v = 3; }
      if (op.type != UROpType.COND) return false;
      return (op.v >= 0 && op.v <= 3);
    case UROpType.COND:
      // fix "C" condition
      if (op.type == UROpType.R8 && op.v == 1) { op.type = UROpType.COND; op.v = 3; }
      return (op.type == UROpType.COND);
    case UROpType.BITN:
      if (op.type != UROpType.IMM16) return false;
      if (op.v < 0 || op.v > 7) return false;
      return true;
    case UROpType.RSTDEST:
      if (op.type != UROpType.IMM16) return false;
      if (op.v < 0 || op.v > 0x38 || (op.v&0x07) != 0) return false;
      return true;
    case UROpType.IM0:
      if (op.type != UROpType.IMM16) return false;
      if (op.v != 0) return false;
      return true;
    case UROpType.IM1:
      if (op.type != UROpType.IMM16) return false;
      if (op.v != 1) return false;
      return true;
    case UROpType.IM2:
      if (op.type != UROpType.IMM16) return false;
      if (op.v != 2) return false;
      return true;
  }
  return false;
}


/// buffer to keep assembled code
public struct URAsmBuf {
  ubyte[] dest; /// can be of any length, will grow
  URAsmFixup[] dfixs; /// fixups
  uint destused;
  ubyte[] code; /// result of `urAssembleOne()` call, always slice of `dest`
  URAsmFixup[] fixup; /// result of `urAssembleOne()` call, always slice of `dfixs`

  void reset () pure nothrow @safe @nogc { destused = 0; code = null; fixup = null; }

  void putByte (ubyte v, URAsmFixup fix=URAsmFixup.None) pure nothrow @safe {
    if (destused >= dest.length) dest.length += 64; // way too much! ;-)
    if (destused >= dfixs.length) dfixs.length += 64; // way too much! ;-)
    dest[destused] = v;
    dfixs[destused] = fix;
    ++destused;
    code = dest[0..destused];
    fixup = dfixs[0..destused];
  }

  void putWord (ushort v, URAsmFixup fix=URAsmFixup.None) pure nothrow @safe {
    putByte(v&0xff, fix);
    putByte((v>>8)&0xff, URAsmFixup.None);
  }
}


/// understands comments
void urAssembleOne (ref URAsmBuf dbuf, ref URAsmParser pr, ushort addr) {
  char[6] mnem;
  int tkn;
  URAOperand[3] ops;
  const(URAsmCmdInfo)* cm;

  dbuf.reset();

  void doOperand (int idx, ref uint code) {
    const(URAOperand)* op = ops.ptr+idx;
    switch (cm.ops[idx]) {
      case UROpType.IMM8:
      case UROpType.PORTIMM:
        if (op.fixuptype != URAsmFixup.None) {
          if (op.fixuptype == URAsmFixup.Word) throw new Exception("invalid fixup");
        }
        dbuf.putByte(op.v&0xFFU, op.fixuptype);
        break;
      case UROpType.ADDR8:
        if (op.defined) {
          int dist = op.v-(addr+2);
          if (dist < byte.min || dist > byte.max) throw new Exception("invalid jr destination");
          dbuf.putByte(dist&0xff);
        } else {
          dbuf.putByte(0);
        }
        break;
      case UROpType.IMM16:
      case UROpType.ADDR16:
      case UROpType.MEM16:
        dbuf.putWord(op.v&0xFFFFU, op.fixuptype);
        break;
      case UROpType.R8:
      case UROpType.R8NOM:
        code |= op.v&0xFFU;
        break;
      case UROpType.RSTDEST:
        code |= op.v&0b111000;
        break;
      case UROpType.JRCOND:
      case UROpType.COND:
      case UROpType.BITN:
      case UROpType.R83:
      case UROpType.R83NOM:
        code |= (op.v&0xFFU)<<3;
        break;
      case UROpType.R16:
      case UROpType.R16A:
        code |= (op.v&0xFFU)<<4;
        break;
      case UROpType.MIX:
      case UROpType.MIY:
        dbuf.putByte(cast(ubyte)op.v);
        break;
      default: break;
    }
  }

  void genCode (void) {
    cmdloop: for (int pos = cast(int)URInstructionsTable.length-1; pos >= 0; --pos) {
      if (tkn != URInstructionsTable.ptr[pos].mnemo) continue;
      foreach (immutable oprn, ref op; ops[]) {
        if (!urIsValidOp(op, addr, URInstructionsTable.ptr[pos].ops.ptr[oprn])) continue cmdloop;
      }
      // command found, generate code
      cm = URInstructionsTable.ptr+pos;
      uint code = cm.code;
      uint mask = cm.mask;
      if ((code&0xFFFFU) == 0xCBDDU || (code&0xFFFFU) == 0xCBFDU) {
        // special commands
        // emit unmasked code
        dbuf.putByte(code&0xFFU);
        dbuf.putByte(0xCB);
        dbuf.putByte(0);
        dbuf.putByte(0);
        foreach (immutable oprn; 0..3) {
          if (cm.ops[oprn] == UROpType.MIX || cm.ops[oprn] == UROpType.MIY) {
            if (ops[oprn].defined && (ops[oprn].v < byte.min || ops[oprn].v > byte.max)) throw new Exception("invalid displacement");
            if (ops[oprn].defined) dbuf.dest[dbuf.destused-2] = cast(ubyte)ops[oprn].v;
            break;
          }
        }
        auto ccpos = dbuf.destused-1;
        //len = 4;
        code >>= 24;
        mask >>= 24;
        if ((mask&0xFFU) != 0xFFU) {
          foreach (immutable oprn; 0..3) if (cm.ops[oprn] != UROpType.MIX && cm.ops[oprn] != UROpType.MIY) doOperand(oprn, code);
        }
        dbuf.dest[ccpos] = cast(ubyte)code;
        // that's all
        return;
      } else {
        // normal commands
        // emit unmasked code
        while ((mask&0xFFU) == 0xFFU) {
          dbuf.putByte(code&0xFFU);
          code >>= 8;
          mask >>= 8;
        }
        //ASSERT((code&0xFFFFFF00UL) == 0);
        if (mask == 0) {
          //ASSERT(len > 0);
          code = dbuf.dest[--dbuf.destused];
        }
        uint ccpos = dbuf.destused;
        dbuf.putByte(0);
        doOperand(0, code);
        doOperand(1, code);
        doOperand(2, code);
        dbuf.dest[ccpos] = cast(ubyte)code;
        // that's all
        return;
      }
    }
    throw new Exception("invalid instruction");
  }

  void doPushPop () {
    bool first = true;
    for (;;) {
      pr.skipBlanks();
      if (pr.eol) {
        if (first) throw new Exception("invalid operand");
        break;
      } else if (!first) {
        if (pr.empty || pr.front != ',') throw new Exception("invalid operand");
        pr.popFront();
        pr.skipBlanks();
        if (pr.eol) throw new Exception("invalid operand");
      }
      ops[] = URAOperand.init;
      urNextOperand(pr, ops[0], addr);
      genCode();
      first = false;
    }
  }

  void dorep (int opcnt) {
    bool first = true;
    for (;;) {
      pr.skipBlanks();
      if (pr.eol) {
        if (first) throw new Exception("invalid operand");
        break;
      } else if (!first) {
        if (pr.empty || pr.front != ',') throw new Exception("invalid operand");
        pr.popFront();
        pr.skipBlanks();
        if (pr.eol) throw new Exception("invalid operand");
      }
      ops[] = URAOperand.init;
      foreach (immutable c; 0..opcnt) {
        if (c != 0) {
          pr.skipBlanks();
          if (pr.empty || pr.front != ',') throw new Exception("invalid operand");
          pr.popFront();
          pr.skipBlanks();
          if (pr.eol) throw new Exception("invalid operand");
        }
        urNextOperand(pr, ops[c], addr);
      }
      // shifts has special (I?+n),r8 forms
      if (opcnt == 1 && tkn != URMnemo.INC && tkn != URMnemo.DEC) {
        if (ops[0].type == UROpType.MIX || ops[0].type == UROpType.MIY || ops[0].type == UROpType.MIX0 || ops[0].type == UROpType.MIY0) {
          if (!first) throw new Exception("invalid operand mix");
          pr.skipBlanks();
          if (!pr.empty && pr.front == ',') urNextOperand(pr, ops[1], addr);
          pr.skipBlanks();
          if (!pr.eol) throw new Exception("invalid operand");
          genCode();
          return;
        }
      }
      genCode();
      first = false;
    }
  }

  for (;;) {
    pr.skipBlanks();
    if (pr.empty || pr.front == ';') return;
    if (URAsmParser.isalpha(pr.front)) break;
    if (pr.front == ':') { pr.popFront(); continue; }
    throw new Exception("invalid instruction");
  }

  //if (expr[0] == ':') { if (errpos) *errpos = expr; return 0; }
  // get mnemonics
  int mmlen = 0;
  while (!pr.empty) {
    char ch = pr.front;
    if (ch >= 'a' && ch <= 'z') ch -= 32;
    if (ch >= 'A' && ch <= 'Z') {
      if (mmlen > mnem.length) throw new Exception("invalid instruction");
      mnem[mmlen++] = ch;
      pr.popFront();
    } else {
      break;
    }
  }
  if (mmlen == 0) throw new Exception("invalid instruction");
  if (!pr.empty && pr.front > ' ' && pr.front != ';' && pr.front != ':') throw new Exception("invalid instruction");

  // find it
  for (tkn = 0; tkn <= URMnemo.max; ++tkn) if (mnem[0..mmlen] == URMnemonics.ptr[tkn]) break;
  if (tkn > URMnemo.max) throw new Exception("invalid instruction");

  switch (tkn) {
    // special for PUSH and POP
    case URMnemo.POP:
    case URMnemo.PUSH:
      return doPushPop();
    // special for LD
    case URMnemo.LD:
      return dorep(2);
    // special for RR/RL
    case URMnemo.INC:
    case URMnemo.DEC:
    case URMnemo.RL:
    case URMnemo.RR:
    case URMnemo.SRL:
    case URMnemo.SRA:
    case URMnemo.SLA:
    case URMnemo.SLI:
    case URMnemo.SLL:
      return dorep(1);
    default:
  }

  pr.skipBlanks();

  foreach (immutable ci, ref URAOperand op; ops[]) {
    pr.skipBlanks();
    if (pr.eol) break;
    if (ci != 0) {
      if (pr.empty || pr.front != ',') throw new Exception("invalid operand");
      pr.popFront();
      pr.skipBlanks();
      if (pr.eol) throw new Exception("invalid operand");
    }
    urNextOperand(pr, op, addr);
    //conwriteln("op #", ci, ": ", op.toString, "  <", pr.text[pr.textpos..$], ">");
  }

  pr.skipBlanks();
  if (!pr.eol) throw new Exception("invalid operand");

  genCode();
}


// ////////////////////////////////////////////////////////////////////////// //
version(urasm_test) {
import iv.cmdcon;
import iv.vfs.io;


void testOne (string xname) {
  conwriteln("=== ", xname, " ===");
  ubyte[] eta;
  {
    auto fi = VFile("_urtests/"~xname~"_0000.bin");
    eta.length = cast(uint)fi.size;
    fi.rawReadExact(eta[]);
  }
  ushort addr = 0;
  //ubyte[] res;
  foreach (string s; VFile("_urtests/"~xname~".asm").byLineCopy) {
    //conwritefln!"%04X: %s: %s"(addr, addr, s);
    URAsmBuf abuf;
    auto pr = URAsmParser(s);
    urAssembleOne(abuf, pr, addr);
    pr.skipBlanks();
    if (!pr.empty && pr.front != ';') assert(0, "extra text");
    foreach (immutable idx, ubyte b; abuf.code) {
      if (b != eta[addr+idx]) {
        conwritefln!"%04X: %02X %02X"(addr+idx, eta[addr+idx], b);
        assert(0, "fucked");
      }
    }
    //res ~= db;
    addr += abuf.code.length;
  }
  //auto fo = VFile("zres.bin", "w");
  //fo.rawWriteExact(res);
}


void main () {
  version(none) {
    ubyte[16] buf;
    auto db = urAssembleOne(buf[], "ex af,afx", 0);
    conwriteln("len=", db.length);

    URDisState dis;
    ushort addr = 0;
    while (addr < db.length) {
      auto len = urDisassembleOne(dis, addr, (ushort addr) => buf[addr&0x0f]);
      conwriteln("dlen=", len);
      conwriteln("  ", dis.getbuf);
      addr += len;
    }
  } else {
    testOne("allb_smp");
    testOne("undoc");
  }
}
}
