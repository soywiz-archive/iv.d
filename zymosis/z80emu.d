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
module iv.zymosis.z80emu;

//version = Zymosis_Like_FUSE;
//version = Zymosis_Testing; // to use with FUSE testing suite
//version = Zymosis_Check_Contention;

version(Zymosis_Testing) pragma(msg, "Zymosis: building test version");
version(Zymosis_Like_FUSE) pragma(msg, "Zymosis: building simplified SCF/CCF");
version(Zymosis_Check_Contention) pragma(msg, "Zymosis: do some sanity checks for contention tables");


// ////////////////////////////////////////////////////////////////////////// //
public class ZymCPU {
public:
  ///
  static struct MemPage {
    //enum Size = 4096; /// in page
    enum Size = 16384; /// in page
    ubyte* mem; /// pointer to Size bytes
    bool contended; /// is this page contended?
    bool rom; /// read-only?
    bool writeHook; /// call write hook before something was written to this page
  }

public:
  /// flag masks
  enum Z80Flags {
    C = 0x01, /// carry flag
    N = 0x02, /// add/substract flag (0: last was add, 1: last was sub)
    PV = 0x04, /// parity/overflow flag
    F3 = 0x08,
    H = 0x10, /// half-carry flag
    F5 = 0x20,
    Z = 0x40, /// zero flag
    S = 0x80, /// sign flag

    F35 = F3|F5,
    S35 = S|F35
  }

  /// Previous instruction type.
  enum EIDDR {
    LdIorR = -1, /// LD A,I or LD A,R
    Normal, /// normal instruction
    BlockInt /// EI/FD/DD (they blocks /INT)
  }

  /// register pair
  union RegPair {
  align(1):
    ushort w;
   version(LittleEndian) {
    struct { align(1): ubyte c, b; }
    struct { align(1): ubyte e, d; }
    struct { align(1): ubyte l, h; }
    struct { align(1): ubyte f, a; }
    struct { align(1): ubyte xl, xh; }
    struct { align(1): ubyte yl, yh; }
   }
   version(BigEndian) {
    struct { align(1): ubyte b, c; }
    struct { align(1): ubyte d, e; }
    struct { align(1): ubyte h, l; }
    struct { align(1): ubyte a, f; }
    struct { align(1): ubyte xh, xl; }
    struct { align(1): ubyte yh, yl; }
   }
   alias w this; // allow to use RegPair as ushort
  }

private:
  RegPair* DD; // pointer to current HL/IX/IY (inside this class) for the current command
  ubyte mIM; // Interrupt Mode (0-2)

public:
  MemPage[65536/MemPage.Size+1] mem; /// machine memory; MUST be initialized before executing anything
  bool[65536] bpmap; /// breakpoint map; breakpoint hook will be called if this is true; no autoreset
  ubyte[] ulacont; /// contention for memory access, with mreq; indexed by `tstates`
  ubyte[] ulacontport; /// contention for memory access operation, without mreq; indexed by `tstates`
  RegPair BC, DE, HL, AF, IX, IY; /// registers
  RegPair BCx, DEx, HLx, AFx; /// alternate registers
  RegPair MEMPTR; /// special MEMPTR register
  ubyte I, R; /// C.O.: I and R registers respectively
  ushort SP; /// stack pointer
  ushort PC; /// program counter
  ushort prevPC; /// first byte of the previous (before last) executed command
  ushort lastPC; /// first byte of the last executed command
  bool IFF1, IFF2; /// interrupt flip-flops
  /** is CPU halted? main progam must manually reset this flag when it's appropriate
    * Zymosis will automatically reset it in intr() and nmi(). */
  bool halted;
  int tstates; /// t-states passed from previous interrupt (0-...)
  int nextEventTS = -1; /// zym_exec() will exit when tstates>=nextEventTS
  /** previous instruction type.
    * Zymosis will reset this flag to Normal only if it executed at least one instruction. */
  EIDDR prevWasEIDDR;
  bool prevOpChangedFlags; /// did previous instruction affected F? used to better emulate SCF/CCF.
  bool evenM1; /// emulate 128K/Scorpion M1 contention?
  bool bpHit; /// will be set if execution loop was stopped by breakpoint; autoreset

public:
  /**
   * Page execute hook. Will be called before opcode fetching and tstate changing.
   * Ideal place to switch ROMs.
   *
   * PC is current instruction address (to be fetched). Entering page `mpage`.
   */
  void execHook () nothrow @trusted @nogc {}

  /// this will be called before writing occurs
  void memWriteHook (ushort addr, ubyte b) nothrow @trusted @nogc {}

  /**
   * Breakpoint hook
   *
   * PC is current instruction address (to be fetched). Return `true` to break emulation loop.
   */
  bool checkBreakpoint () nothrow @trusted @nogc { return false; }

  version(Zymosis_Testing) {
    /*
     * Will be called when port contention is necessary.
     * Function must increase z80.tstates by at least 'atstates' arg.
     *
     * Default: tstates += atstates;
     *
     * Params:
     *  port = port address
     *  atstates = how much tstates we should spend (always 1 when 'early' is set and 2 otherwise)
     *  doIN = true, if this is 'IN' instruction and false if this is 'OUT' instruction
     *  early = true, if doing 'early' port contention (yes, ZX Spectrum port contention is complex)
     *
     * Returns:
     *  nothing
     */
    void portContention (ushort port, int atstates, bool doIN, bool early) nothrow @trusted @nogc { tstates += atstates; }

    void memContention (ushort addr, bool mreq) nothrow @trusted @nogc {}
    void memReading (ushort addr) nothrow @trusted @nogc {}
    void memWriting (ushort addr, ubyte b) nothrow @trusted @nogc {}
  }

  /**
   * Read byte from emulated port.
   *
   * Params:
   *  addr = port address
   *
   * Returns:
   *  readed byte from emulated port
   */
  abstract ubyte portRead (ushort port) nothrow @trusted @nogc;

  /**
   * Write byte to emulated port.
   *
   * Params:
   *  addr = port address
   *  value = byte to store
   *
   * Returns:
   *  Nothing
   */
  abstract void portWrite (ushort port, ubyte value) nothrow @trusted @nogc;

  /// get byte from memory, don't trigger any breakpoints or such
  public final ubyte memPeekB (ushort addr) nothrow @trusted @nogc {
    pragma(inline, true);
    return mem.ptr[addr/MemPage.Size].mem[addr%MemPage.Size];
  }

  /// set byte in memory, don't trigger any breakpoints or such, but respect ROM
  public final void memPokeB (ushort addr, ubyte b) nothrow @trusted @nogc {
    pragma(inline, true);
    if (!mem.ptr[addr/MemPage.Size].rom) mem.ptr[addr/MemPage.Size].mem[addr%MemPage.Size] = b;
  }

  /**
   * This function will be called on invalid ED command (so-called 'trap command').
   * CPU's PC will point to the next instruction (use origpc to inspect trap code).
   *
   * trapCode=0xFB: .SLT trap
   *  HL: address to load;
   *  A: A --> level number
   *  return: CARRY complemented --> error
   *
   * Params:
   *   trapCode = actual trap code
   *
   * Returns:
   *   'stop emulation' flag (return true to stop emulation loop immediately)
   */
  bool trapED (ubyte trapCode) nothrow @trusted @nogc { return false; }

  /**
   * This function will be called *AFTER* RETI command executed, iff changed and return address set.
   *
   * Params:
   *  opcode = actual opcode (there is more than one RETI in Z80)
   *
   * Returns:
   *   'stop emulation' flag (return true to stop emulation loop immediately)
   */
  bool trapRETI (ubyte opcode) nothrow @trusted @nogc { return false; }

  /**
   * This function will be called *AFTER* RETN command executed, iff changed and return address set.
   *
   * Params:
   *  opcode = actual opcode (there is more than one RETI in Z80)
   *
   * Returns:
   *   'stop emulation' flag (return true to stop emulation loop immediately)
   */
  bool trapRETN (ubyte opcode) nothrow @trusted @nogc { return false; }


  // ////////////////////////////////////////////////////////////////////// //
  ///
  this () {
    evenM1 = false;
    bpHit = false;
    tstates = 0;
    reset(true);
  }

  /** "Soft" reset: clear only absolutely necessary things. */
  void softReset () {
    PC = prevPC = lastPC = 0;
    DD = &HL;
    MEMPTR = 0;
    I = R = 0;
    IFF1 = IFF2 = false;
    mIM = 0;
    halted = false;
    prevWasEIDDR = EIDDR.Normal;
    bpHit = false;
    setupMemory();
  }

  /** Reset emulated CPU. Will NOT reset tstate counter. */
  void reset (bool poweron=false) {
    //TODO: don't touch IX and IY values?
    BC = DE = HL = AF = SP = IX = IY = (poweron ? 0xFFFF: 0);
    BCx = DEx = HLx = AFx = (poweron ? 0xFFFF: 0);
    softReset();
  }

  /** This will be called before reset seqience is complete. */
  abstract void setupMemory ();

// ////////////////////////////////////////////////////////////////////////// //
final:
  @property ubyte IM () const pure nothrow @safe @nogc { pragma(inline, true); return mIM; } /** get Interrupt Mode (0-2) */
  @property void IM (in ubyte v) pure nothrow @safe @nogc { pragma(inline, true); mIM = (v > 2 ? 0 : v); } /** set Interrupt Mode (0-2) */

  /** increment R register. note that Z80 never changes the high bit of R. */
  void incR () pure nothrow @safe @nogc { pragma(inline, true); R = ((R+1)&0x7f)|(R&0x80); }

  /**
   * Execute emulated CPU instructions.
   * This function will execute Z80 code until tstates reaches nextEventTS
   * or at least tscount tstates passed.
   * Note that it can spend more that tscount states and slightly miss
   * nextEventTS so tstates will be >= nextEventTS.
   *
   * WARNING: don't decrease tstates value in callbacks, or everything
   *          will be really bad!
   *
   * Params:
   *  tscount = how much tstates we should spend executing;
   *            pass -1 to execute until nextEventTS reached
   *
   * Returns:
   *  number of tstates actually spent
   */
  int exec (int tscount=-1) nothrow @trusted @nogc {
    static bool isRepeated (ushort opc) pure nothrow @safe @nogc { pragma(inline, true); return ((opc&0x10) != 0); }
    static bool isBackward (ushort opc) pure nothrow @safe @nogc { pragma(inline, true); return ((opc&0x08) != 0); }
    ubyte opcode;
    bool gotDD, trueCC;
    int disp;
    ubyte tmpB, tmpC, rsrc, rdst;
    ushort tmpW;
    int tstart = tstates;
    bool prevOpChangedFlagsXX;
    bpHit = false;

    bool doCond (ubyte code) {
      final switch (code&0x07) {
        case 0: return (AF.f&Z80Flags.Z) == 0;
        case 1: return (AF.f&Z80Flags.Z) != 0;
        case 2: return (AF.f&Z80Flags.C) == 0;
        case 3: return (AF.f&Z80Flags.C) != 0;
        case 4: return (AF.f&Z80Flags.PV) == 0;
        case 5: return (AF.f&Z80Flags.PV) != 0;
        case 6: return (AF.f&Z80Flags.S) == 0;
        case 7: return (AF.f&Z80Flags.S) != 0;
      }
      assert(0);
    }

    //FIXME: call enter/leave hooks here too?
    ubyte fetchOpcodeExt () nothrow @trusted @nogc {
      //pragma(inline, true);
      contention(PC, 4, true);
      //contention(((I<<8)|R), 2, false); // memory refresh
      // it doesn't really matter when R is incremented here
      incR();
      return peekb(PC++);
    }

    // main loop
    while ((nextEventTS < 0 || tstates < nextEventTS) && (tscount < 0 || tstates-tstart <= tscount)) {
      // process enter/leave hooks
      execHook();
      // process breakpoints
      if (bpmap[PC] && checkBreakpoint()) { bpHit = true; return tstates-tstart; }
      // read opcode -- OCR(4)
      // t1: setting /MREQ & /RD
      // t2: memory read
      // t3, t4: decode command, increment R
      // Woody: The Z80 places IR on to the address bus during T3+T4 of opcode fetch (M1) cycles for DRAM refresh,
      //        then if following cycles have internal operations before placing another address on the address bus
      //        then the ULA continues to see IR and contends as normal as it would with any other register paired address.
      // it doesn't matter if we will really emulate IR here, 'cause T1 contention should end up in "non-contended" state
      contention(PC, 4, true);
      //contention(((I<<8)|R), 2, false); // memory refresh
      if (evenM1 && (tstates&0x01)) ++tstates;
      // read opcode
      prevPC = lastPC;
      lastPC = PC;
      opcode = peekb(PC);
      version(Zymosis_Run_Log) { { import core.stdc.stdio; stderr.fprintf("PC=%04X; OP:%02X; tstates=%d\n", PC, opcode, tstates); } }
      ++PC;
      incR();
      prevOpChangedFlagsXX = prevOpChangedFlags;
      prevOpChangedFlags = false;
      prevWasEIDDR = EIDDR.Normal;
      disp = 0;
      gotDD = false;
      DD = &HL;
      if (halted) { --PC; continue; }
      // check for I[XY] prefix
      if (opcode == 0xdd || opcode == 0xfd) {
        //TODO: generate this table in compile time
        static immutable uint[8] withIndexBmp = [0x00,0x700000,0x40404040,0x40bf4040,0x40404040,0x40404040,0x0800,0x00];
        // IX/IY prefix
        DD = (opcode == 0xdd ? &IX : &IY);
        // read opcode -- OCR(4)
        opcode = fetchOpcodeExt();
        // test if this instruction have (HL)
        if (withIndexBmp[opcode>>5]&(1<<(opcode&0x1f))) {
          // 3rd byte is always DISP here
          disp = peekb_3ts_args();
          if (disp > 127) disp -= 256;
          ++PC;
          MEMPTR = (cast(int)DD.w+disp)&0xffff;
        } else if (opcode == 0xdd && opcode == 0xfd) {
          // double prefix; restart main loop
          prevWasEIDDR = EIDDR.BlockInt;
          prevOpChangedFlags = prevOpChangedFlagsXX; // dunno
          continue;
        }
        gotDD = true;
      }
      // ED-prefixed instructions
      if (opcode == 0xed) {
        DD = &HL; // а нас -- рать!
        // read opcode -- OCR(4)
        opcode = fetchOpcodeExt();
        switch (opcode) {
          // LDI, LDIR, LDD, LDDR
          case 0xa0: case 0xb0: case 0xa8: case 0xb8:
            tmpB = peekb_3ts(HL);
            pokeb_3ts(DE, tmpB);
            // MWR(5)
            contention_by1ts(DE, 2);
            --BC;
            tmpB = (tmpB+AF.a)&0xff;
            prevOpChangedFlags = true;
            AF.f = // BOO! FEAR THE MIGHTY BITS!
              (tmpB&Z80Flags.F3)|(AF.f&(Z80Flags.C|Z80Flags.Z|Z80Flags.S))|
              (BC != 0 ? Z80Flags.PV : 0)|
              (tmpB&0x02 ? Z80Flags.F5 : 0);
            if (isRepeated(opcode)) {
              if (BC != 0) {
                // IOP(5)
                contention_by1ts(DE, 5);
                // do it again
                PC -= 2;
                MEMPTR = (PC+1)&0xffff;
              }
            }
            if (!isBackward(opcode)) { ++HL; ++DE; } else { --HL; --DE; }
            break;
          // CPI, CPIR, CPD, CPDR
          case 0xa1: case 0xb1: case 0xa9: case 0xb9:
            // MEMPTR
            if (isRepeated(opcode) && (!(BC == 1 || memPeekB(HL) == AF.a))) {
              MEMPTR = cast(ushort)(lastPC+1);
            } else {
              MEMPTR = cast(ushort)(MEMPTR+(isBackward(opcode) ? -1 : 1));
            }
            tmpB = peekb_3ts(HL);
            // IOP(5)
            contention_by1ts(HL, 5);
            --BC;
            prevOpChangedFlags = true;
            AF.f = // BOO! FEAR THE MIGHTY BITS!
              Z80Flags.N|
              (AF.f&Z80Flags.C)|
              (BC != 0 ? Z80Flags.PV : 0)|
              (cast(int)(AF.a&0x0f)-cast(int)(tmpB&0x0f) < 0 ? Z80Flags.H : 0);
            tmpB = (cast(int)AF.a-cast(int)tmpB)&0xff;
            AF.f |= (tmpB == 0 ? Z80Flags.Z : 0)|(tmpB&Z80Flags.S);
            if (AF.f&Z80Flags.H) tmpB = (cast(ushort)tmpB-1)&0xff;
            AF.f |= (tmpB&Z80Flags.F3)|(tmpB&0x02 ? Z80Flags.F5 : 0);
            if (isRepeated(opcode)) {
              // repeated
              if ((AF.f&(Z80Flags.Z|Z80Flags.PV)) == Z80Flags.PV) {
                // IOP(5)
                contention_by1ts(HL, 5);
                // do it again
                PC -= 2;
              }
            }
            if (isBackward(opcode)) --HL; else ++HL;
            break;
          // OUTI, OTIR, OUTD, OTDR
          case 0xa3: case 0xb3: case 0xab: case 0xbb:
            --BC.b;
            // fallthru
            goto case 0xa2;
          // INI, INIR, IND, INDR
          case 0xa2: case 0xb2: case 0xaa: case 0xba:
            MEMPTR = cast(ushort)(BC+(isBackward(opcode) ? -1 : 1));
            // OCR(5)
            contention_by1ts_ir(1);
            if (opcode&0x01) {
              // OUT*
              tmpB = peekb_3ts(HL); // MRD(3)
              port_write(BC, tmpB);
              tmpW = cast(ushort)(HL+(isBackward(opcode) ? -1 : 1));
              tmpC = (tmpB+tmpW)&0xff;
            } else {
              // IN*
              tmpB = port_read(BC);
              pokeb_3ts(HL, tmpB); // MWR(3)
              --BC.b;
              if (isBackward(opcode)) tmpC = (cast(int)tmpB+cast(int)BC.c-1)&0xff; else tmpC = (tmpB+BC.c+1)&0xff;
            }
            prevOpChangedFlags = true;
            AF.f =
              (tmpB&0x80 ? Z80Flags.N : 0)|
              (tmpC < tmpB ? Z80Flags.H|Z80Flags.C : 0)|
              tblParity.ptr[(tmpC&0x07)^BC.b]|
              tblSZ53.ptr[BC.b];
            if (isRepeated(opcode)) {
              // repeating commands
              if (BC.b != 0) {
                ushort a = (opcode&0x01 ? BC : HL);
                // IOP(5)
                contention_by1ts(a, 5);
                // do it again
                PC -= 2;
              }
            }
            if (isBackward(opcode)) --HL; else ++HL;
            break;
          // not strings, but some good instructions anyway
          default:
            if ((opcode&0xc0) == 0x40) {
              // 0x40...0x7f
              final switch (opcode&0x07) {
                // IN r8,(C)
                case 0:
                  MEMPTR = cast(ushort)(BC+1);
                  tmpB = port_read(BC);
                  prevOpChangedFlags = true;
                  AF.f = tblSZP53.ptr[tmpB]|(AF.f&Z80Flags.C);
                  final switch ((opcode>>3)&0x07) {
                    case 0: BC.b = tmpB; break;
                    case 1: BC.c = tmpB; break;
                    case 2: DE.d = tmpB; break;
                    case 3: DE.e = tmpB; break;
                    case 4: HL.h = tmpB; break;
                    case 5: HL.l = tmpB; break;
                    case 6: break; // 6 affects only flags
                    case 7: AF.a = tmpB; break;
                  }
                  break;
                // OUT (C),r8
                case 1:
                  MEMPTR = cast(ushort)(BC+1);
                  final switch ((opcode>>3)&0x07) {
                    case 0: tmpB = BC.b; break;
                    case 1: tmpB = BC.c; break;
                    case 2: tmpB = DE.d; break;
                    case 3: tmpB = DE.e; break;
                    case 4: tmpB = HL.h; break;
                    case 5: tmpB = HL.l; break;
                    case 6: tmpB = 0; break; // 0 on NMOS, 255 on CMOS
                    case 7: tmpB = AF.a; break;
                  }
                  port_write(BC, tmpB);
                  break;
                // SBC HL,rr/ADC HL,rr
                case 2:
                  // IOP(4),IOP(3)
                  contention_by1ts_ir(7);
                  switch ((opcode>>4)&0x03) {
                    case 0: tmpW = BC; break;
                    case 1: tmpW = DE; break;
                    case 2: tmpW = HL; break;
                    default: tmpW = SP; break;
                  }
                  HL = (opcode&0x08 ? ADC_DD(tmpW, HL) : SBC_DD(tmpW, HL));
                  break;
                // LD (nn),rr/LD rr,(nn)
                case 3:
                  tmpW = getpcw(0);
                  MEMPTR = (tmpW+1)&0xffff;
                  if (opcode&0x08) {
                    // LD rr,(nn)
                    final switch ((opcode>>4)&0x03) {
                      case 0: BC = peekw_6ts(tmpW); break;
                      case 1: DE = peekw_6ts(tmpW); break;
                      case 2: HL = peekw_6ts(tmpW); break;
                      case 3: SP = peekw_6ts(tmpW); break;
                    }
                  } else {
                    // LD (nn),rr
                    final switch ((opcode>>4)&0x03) {
                      case 0: pokew_6ts(tmpW, BC); break;
                      case 1: pokew_6ts(tmpW, DE); break;
                      case 2: pokew_6ts(tmpW, HL); break;
                      case 3: pokew_6ts(tmpW, SP); break;
                    }
                  }
                  break;
                // NEG
                case 4:
                  tmpB = AF.a;
                  AF.a = 0;
                  SUB_A(tmpB);
                  break;
                // RETI/RETN
                case 5:
                  // RETI: 0x4d, 0x5d, 0x6d, 0x7d
                  // RETN: 0x45, 0x55, 0x65, 0x75
                  IFF1 = IFF2;
                  MEMPTR = PC = pop_6ts();
                  if (opcode&0x08) {
                    // RETI
                    if (trapRETI(opcode)) return tstates-tstart;
                  } else {
                    // RETN
                    if (trapRETN(opcode)) return tstates-tstart;
                  }
                  break;
                // IM n
                case 6:
                  switch (opcode) {
                    case 0x56: case 0x76: mIM = 1; break;
                    case 0x5e: case 0x7e: mIM = 2; break;
                    default: mIM = 0; break;
                  }
                  break;
                // specials
                case 7:
                  final switch (opcode) {
                    // LD I,A
                    case 0x47:
                      // OCR(5)
                      contention_by1ts_ir(1);
                      I = AF.a;
                      break;
                    // LD R,A
                    case 0x4f:
                      // OCR(5)
                      contention_by1ts_ir(1);
                      R = AF.a;
                      break;
                    // LD A,I
                    case 0x57: LD_A_IR(I); break;
                    // LD A,R
                    case 0x5f: LD_A_IR(R); break;
                    // RRD
                    case 0x67: RRD_A(); break;
                    // RLD
                    case 0x6F: RLD_A(); break;
                  }
              }
            } else {
              // slt and other traps
              if (trapED(opcode)) return tstates-tstart;
            }
            break;
        }
        continue;
      } // 0xed done
      // CB-prefixed instructions
      if (opcode == 0xcb) {
        // shifts and bit operations
        // read opcode -- OCR(4)
        if (!gotDD) {
          opcode = fetchOpcodeExt();
        } else {
          contention(PC, 3, true);
          //FIXME: call enter/leave hooks here too?
          opcode = peekb(PC);
          contention_by1ts_pc(2, true);
          ++PC;
        }
        if (gotDD) {
          tmpW = cast(ushort)(cast(int)DD.w+disp);
          tmpB = peekb_3ts(tmpW);
          contention_by1ts(tmpW, 1);
          MEMPTR = tmpW; //???MEMPTR
        } else {
          final switch (opcode&0x07) {
            case 0: tmpB = BC.b; break;
            case 1: tmpB = BC.c; break;
            case 2: tmpB = DE.d; break;
            case 3: tmpB = DE.e; break;
            case 4: tmpB = HL.h; break;
            case 5: tmpB = HL.l; break;
            case 6: tmpB = peekb_3ts(HL); contention(HL, 1, false); MEMPTR = HL; /*???MEMPTR*/ break;
            case 7: tmpB = AF.a; break;
          }
        }
        switch ((opcode>>3)&0x1f) {
          case 0: tmpB = RLC(tmpB); break;
          case 1: tmpB = RRC(tmpB); break;
          case 2: tmpB = RL(tmpB); break;
          case 3: tmpB = RR(tmpB); break;
          case 4: tmpB = SLA(tmpB); break;
          case 5: tmpB = SRA(tmpB); break;
          case 6: tmpB = SLL(tmpB); break;
          case 7: tmpB = SLR(tmpB); break;
          default:
            final switch ((opcode>>6)&0x03) {
              case 1: BIT((opcode>>3)&0x07, tmpB, gotDD, ((opcode&0x07) == 6)); break;
              case 2: tmpB &= ~(1<<((opcode>>3)&0x07)); break; // RES
              case 3: tmpB |= (1<<((opcode>>3)&0x07)); break; // SET
            }
            break;
        }
        if ((opcode&0xc0) != 0x40) {
          // BITs are not welcome here
          if (gotDD) {
            // tmpW was set earlier
            if ((opcode&0x07) != 6) pokeb_3ts(tmpW, tmpB);
          }
          final switch (opcode&0x07) {
            case 0: BC.b = tmpB; break;
            case 1: BC.c = tmpB; break;
            case 2: DE.d = tmpB; break;
            case 3: DE.e = tmpB; break;
            case 4: HL.h = tmpB; break;
            case 5: HL.l = tmpB; break;
            case 6: pokeb_3ts(cast(ushort)(cast(int)DD.w+disp), tmpB); break;
            case 7: AF.a = tmpB; break;
          }
        }
        continue;
      } // 0xcb done
      // normal things
      final switch (opcode&0xc0) {
        // 0x00..0x3F
        case 0x00:
          final switch (opcode&0x07) {
            // misc,DJNZ,JR,JR cc
            case 0:
              if (opcode&0x30) {
                // branches
                if (opcode&0x20) {
                  // JR cc
                  trueCC = doCond((opcode>>3)&0x03);
                } else {
                  // DJNZ/JR
                  if ((opcode&0x08) == 0) {
                    // DJNZ
                    // OCR(5)
                    contention_by1ts_ir(1);
                    --BC.b;
                    trueCC = (BC.b != 0);
                  } else {
                    // JR
                    trueCC = true;
                  }
                }
                //???disp = peekb_3ts_args(); // FUSE reads it only if condition was taken
                if (trueCC) {
                  // execute branch (relative)
                  disp = peekb_3ts_args(); // FUSE reads it only if condition was taken
                  // IOP(5)
                  if (disp > 127) disp -= 256; // convert to int8_t
                  contention_by1ts_pc(5, false);
                  ++PC;
                  PC += disp;
                  MEMPTR = PC;
                } else {
                  peekb_3ts_args_noread(); // FUSE reads it only if condition was taken
                  ++PC;
                }
              } else {
                // EX AF,AF' or NOP
                if (opcode != 0) exafaf();
              }
              break;
            // LD rr,nn/ADD HL,rr
            case 1:
              if (opcode&0x08) {
                // ADD HL,rr
                // IOP(4),IOP(3)
                contention_by1ts_ir(7);
                final switch ((opcode>>4)&0x03) {
                  case 0: DD.w = ADD_DD(BC, DD.w); break;
                  case 1: DD.w = ADD_DD(DE, DD.w); break;
                  case 2: DD.w = ADD_DD(DD.w, DD.w); break;
                  case 3: DD.w = ADD_DD(SP, DD.w); break;
                }
              } else {
                // LD rr,nn
                tmpW = getpcw(0);
                final switch ((opcode>>4)&0x03) {
                  case 0: BC = tmpW; break;
                  case 1: DE = tmpW; break;
                  case 2: DD.w = tmpW; break;
                  case 3: SP = tmpW; break;
                }
              }
              break;
            // LD xxx,xxx
            case 2:
              final switch ((opcode>>3)&0x07) {
                // LD (BC),A
                case 0: pokeb_3ts(BC, AF.a); MEMPTR.l = (BC.c+1)&0xff; MEMPTR.h = AF.a; break;
                // LD A,(BC)
                case 1: AF.a = peekb_3ts(BC); MEMPTR = (BC+1)&0xffff; break;
                // LD (DE),A
                case 2: pokeb_3ts(DE, AF.a); MEMPTR.l = (DE.e+1)&0xff; MEMPTR.h = AF.a; break;
                // LD A,(DE)
                case 3: AF.a = peekb_3ts(DE); MEMPTR = (DE+1)&0xffff; break;
                // LD (nn),HL
                case 4:
                  tmpW = getpcw(0);
                  MEMPTR = (tmpW+1)&0xffff;
                  pokew_6ts(tmpW, DD.w);
                  break;
                // LD HL,(nn)
                case 5:
                  tmpW = getpcw(0);
                  MEMPTR = (tmpW+1)&0xffff;
                  DD.w = peekw_6ts(tmpW);
                  break;
                // LD (nn),A
                case 6:
                  tmpW = getpcw(0);
                  MEMPTR.l = (tmpW+1)&0xff;
                  MEMPTR.h = AF.a;
                  pokeb_3ts(tmpW, AF.a);
                  break;
                // LD A,(nn)
                case 7:
                  tmpW = getpcw(0);
                  MEMPTR = (tmpW+1)&0xffff;
                  AF.a = peekb_3ts(tmpW);
                  break;
              }
              break;
            // INC rr/DEC rr
            case 3:
              // OCR(6)
              contention_by1ts_ir(2);
              if (opcode&0x08) {
                // DEC
                final switch ((opcode>>4)&0x03) {
                  case 0: --BC; break;
                  case 1: --DE; break;
                  case 2: --DD.w; break;
                  case 3: --SP; break;
                }
              } else {
                // INC
                final switch ((opcode>>4)&0x03) {
                  case 0: ++BC; break;
                  case 1: ++DE; break;
                  case 2: ++DD.w; break;
                  case 3: ++SP; break;
                }
              }
              break;
            // INC r8
            case 4:
              final switch ((opcode>>3)&0x07) {
                case 0: BC.b = INC8(BC.b); break;
                case 1: BC.c = INC8(BC.c); break;
                case 2: DE.d = INC8(DE.d); break;
                case 3: DE.e = INC8(DE.e); break;
                case 4: DD.h = INC8(DD.h); break;
                case 5: DD.l = INC8(DD.l); break;
                case 6:
                  if (gotDD) { --PC; contention_by1ts_pc(5, false); ++PC; }
                  tmpW = cast(ushort)(cast(int)DD.w+disp);
                  tmpB = peekb_3ts(tmpW);
                  contention_by1ts(tmpW, 1);
                  tmpB = INC8(tmpB);
                  pokeb_3ts(tmpW, tmpB);
                  break;
                case 7: AF.a = INC8(AF.a); break;
              }
              break;
            // DEC r8
            case 5:
              final switch ((opcode>>3)&0x07) {
                case 0: BC.b = DEC8(BC.b); break;
                case 1: BC.c = DEC8(BC.c); break;
                case 2: DE.d = DEC8(DE.d); break;
                case 3: DE.e = DEC8(DE.e); break;
                case 4: DD.h = DEC8(DD.h); break;
                case 5: DD.l = DEC8(DD.l); break;
                case 6:
                  if (gotDD) { --PC; contention_by1ts_pc(5, false); ++PC; }
                  tmpW = cast(ushort)(cast(int)DD.w+disp);
                  tmpB = peekb_3ts(tmpW);
                  contention_by1ts(tmpW, 1);
                  tmpB = DEC8(tmpB);
                  pokeb_3ts(tmpW, tmpB);
                  break;
                case 7: AF.a = DEC8(AF.a); break;
              }
              break;
            // LD r8,n
            case 6:
              tmpB = peekb_3ts_args();
              ++PC;
              final switch ((opcode>>3)&0x07) {
                case 0: BC.b = tmpB; break;
                case 1: BC.c = tmpB; break;
                case 2: DE.d = tmpB; break;
                case 3: DE.e = tmpB; break;
                case 4: DD.h = tmpB; break;
                case 5: DD.l = tmpB; break;
                case 6:
                  if (gotDD) { --PC; contention_by1ts_pc(2, false); ++PC; }
                  tmpW = cast(ushort)(cast(int)DD.w+disp);
                  pokeb_3ts(tmpW, tmpB);
                  break;
                case 7: AF.a = tmpB; break;
              }
              break;
            // swim-swim-hungry
            case 7:
              final switch ((opcode>>3)&0x07) {
                case 0: RLCA(); break;
                case 1: RRCA(); break;
                case 2: RLA(); break;
                case 3: RRA(); break;
                case 4: DAA(); break;
                case 5: // CPL
                  AF.a ^= 0xff;
                  prevOpChangedFlags = true;
                  AF.f = (AF.a&Z80Flags.F35)|(Z80Flags.N|Z80Flags.H)|(AF.f&(Z80Flags.C|Z80Flags.PV|Z80Flags.Z|Z80Flags.S));
                  break;
                case 6: // SCF
                  version(Zymosis_Testing) {
                    enum fff = 0;
                  } else {
                    version(Zymosis_Like_FUSE)
                      enum fff = 0;
                    else
                      ubyte fff = (prevOpChangedFlagsXX ? 0 : AF.f);
                  }
                  AF.f = (AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S))|((AF.a|fff)&Z80Flags.F35)|Z80Flags.C;
                  prevOpChangedFlags = true;
                  break;
                case 7: // CCF
                  version(Zymosis_Testing) {
                    enum fff = 0;
                  } else {
                    version(Zymosis_Like_FUSE)
                      enum fff = 0;
                    else
                      ubyte fff = (prevOpChangedFlagsXX ? 0 : AF.f);
                  }
                  tmpB = AF.f&Z80Flags.C;
                  AF.f = (AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S))|((AF.a|fff)&Z80Flags.F35);
                  AF.f |= tmpB ? Z80Flags.H : Z80Flags.C;
                  prevOpChangedFlags = true;
                  break;
                /* SCF/CCF:
                 * Patrik Rak however later discovered that the way how the flags 5 and 3 are affected after SCF/CCF actually depends on
                 * the previous instruction completed. In case of genuine Zilog CPU, if an instruction modifies the flags, the immediately
                 * following SCF/CCF does move of bits 5 and 3 from A to F, whereas if an instruction doesn't modify the flags (and after
                 * interrupt), the SCF/CCF does OR of bits 5 and 3 from A to F. In case of NEC and other clones, it is similar, except that
                 * instead of OR it does AND with some unknown value, making the result unreliable. */
              }
              break;
          }
          break;
        // 0x40..0x7F: LD r8,r8
        case 0x40:
          if (opcode == 0x76) { halted = true; --PC; continue; } // HALT
          rsrc = (opcode&0x07);
          rdst = ((opcode>>3)&0x07);
          final switch (rsrc) {
            case 0: tmpB = BC.b; break;
            case 1: tmpB = BC.c; break;
            case 2: tmpB = DE.d; break;
            case 3: tmpB = DE.e; break;
            case 4: tmpB = (gotDD && rdst == 6 ? HL.h : DD.h); break;
            case 5: tmpB = (gotDD && rdst == 6 ? HL.l : DD.l); break;
            case 6:
              if (gotDD) { --PC; contention_by1ts_pc(5, false); ++PC; }
              tmpW = cast(ushort)(cast(int)DD.w+disp);
              tmpB = peekb_3ts(tmpW);
              break;
            case 7: tmpB = AF.a; break;
          }
          final switch (rdst) {
            case 0: BC.b = tmpB; break;
            case 1: BC.c = tmpB; break;
            case 2: DE.d = tmpB; break;
            case 3: DE.e = tmpB; break;
            case 4: if (gotDD && rsrc == 6) HL.h = tmpB; else DD.h = tmpB; break;
            case 5: if (gotDD && rsrc == 6) HL.l = tmpB; else DD.l = tmpB; break;
            case 6:
              if (gotDD) { --PC; contention_by1ts_pc(5, false); ++PC; }
              tmpW = cast(ushort)(cast(int)DD.w+disp);
              pokeb_3ts(tmpW, tmpB);
              break;
            case 7: AF.a = tmpB; break;
          }
          break;
        // 0x80..0xBF: ALU A,r8
        case 0x80:
          final switch (opcode&0x07) {
            case 0: tmpB = BC.b; break;
            case 1: tmpB = BC.c; break;
            case 2: tmpB = DE.d; break;
            case 3: tmpB = DE.e; break;
            case 4: tmpB = DD.h; break;
            case 5: tmpB = DD.l; break;
            case 6:
              if (gotDD) { --PC; contention_by1ts_pc(5, false); ++PC; }
              tmpW = cast(ushort)(cast(int)DD.w+disp);
              tmpB = peekb_3ts(tmpW);
              break;
            case 7: tmpB = AF.a; break;
          }
          final switch ((opcode>>3)&0x07) {
            case 0: ADD_A(tmpB); break;
            case 1: ADC_A(tmpB); break;
            case 2: SUB_A(tmpB); break;
            case 3: SBC_A(tmpB); break;
            case 4: AND_A(tmpB); break;
            case 5: XOR_A(tmpB); break;
            case 6: OR_A(tmpB); break;
            case 7: CP_A(tmpB); break;
          }
          break;
        // 0xC0..0xFF
        case 0xC0:
          final switch (opcode&0x07) {
            // RET cc
            case 0:
              contention_by1ts_ir(1);
              trueCC = doCond((opcode>>3)&0x07);
              if (trueCC) MEMPTR = PC = pop_6ts();
              break;
            // POP rr/special0
            case 1:
              if (opcode&0x08) {
                // special 0
                final switch ((opcode>>4)&0x03) {
                  // RET
                  case 0: MEMPTR = PC = pop_6ts(); break;
                  // EXX
                  case 1: exx(); break;
                  // JP (HL)
                  case 2: PC = DD.w; break;
                  // LD SP,HL
                  case 3:
                    // OCR(6)
                    contention_by1ts_ir(2);
                    SP = DD.w;
                    break;
                }
              } else {
                // POP rr
                tmpW = pop_6ts();
                final switch ((opcode>>4)&0x03) {
                  case 0: BC = tmpW; break;
                  case 1: DE = tmpW; break;
                  case 2: DD.w = tmpW; break;
                  case 3: AF = tmpW; break;
                }
              }
              break;
            // JP cc,nn
            case 2:
              trueCC = doCond((opcode>>3)&0x07);
              MEMPTR = getpcw_cc(0, trueCC);
              //MEMPTR = getpcw(0);
              if (trueCC) PC = MEMPTR;
              break;
            // special1/special3
            case 3:
              final switch ((opcode>>3)&0x07) {
                // JP nn
                case 0: MEMPTR = PC = getpcw(0); break;
                // OUT (n),A
                case 2:
                  tmpW = peekb_3ts_args();
                  ++PC;
                  MEMPTR.l = (tmpW+1)&0xff;
                  MEMPTR.h = AF.a;
                  tmpW |= AF.a<<8;
                  port_write(tmpW, AF.a);
                  break;
                // IN A,(n)
                case 3:
                  tmpB = peekb_3ts_args();
                  tmpW = cast(ushort)((AF.a<<8)|tmpB);
                  ++PC;
                  MEMPTR = (tmpW+1)&0xffff;
                  AF.a = port_read(tmpW);
                  break;
                // EX (SP),HL
                case 4:
                  // SRL(3),SRH(4)
                  tmpW = peekw_6ts(SP);
                  contention_by1ts((SP+1)&0xffff, 1);
                  // SWL(3),SWH(5)
                  pokew_6ts_inverted(SP, DD.w);
                  contention_by1ts(SP, 2);
                  MEMPTR = DD.w = tmpW;
                  break;
                // EX DE,HL
                case 5:
                  tmpW = DE;
                  DE = HL;
                  HL = tmpW;
                  break;
                // DI
                case 6: IFF1 = IFF2 = 0; break;
                // EI
                case 7: IFF1 = IFF2 = 1; prevWasEIDDR = EIDDR.BlockInt; break;
              }
              break;
            // CALL cc,nn
            case 4:
              trueCC = doCond((opcode>>3)&0x07);
              MEMPTR = getpcw_cc((trueCC ? 1 : 0), trueCC);
              if (trueCC) {
                push_6ts(PC);
                PC = MEMPTR;
              }
              break;
            // PUSH rr/special2
            case 5:
              if (opcode&0x08) {
                if (((opcode>>4)&0x03) == 0) {
                  // CALL
                  MEMPTR = tmpW = getpcw(1);
                  push_6ts(PC);
                  PC = tmpW;
                }
              } else {
                // PUSH rr
                // OCR(5)
                contention_by1ts_ir(1);
                switch ((opcode>>4)&0x03) {
                  case 0: tmpW = BC; break;
                  case 1: tmpW = DE; break;
                  case 2: tmpW = DD.w; break;
                  default: tmpW = AF; break;
                }
                push_6ts(tmpW);
              }
              break;
            // ALU A,n
            case 6:
              tmpB = peekb_3ts_args();
              ++PC;
              final switch ((opcode>>3)&0x07) {
                case 0: ADD_A(tmpB); break;
                case 1: ADC_A(tmpB); break;
                case 2: SUB_A(tmpB); break;
                case 3: SBC_A(tmpB); break;
                case 4: AND_A(tmpB); break;
                case 5: XOR_A(tmpB); break;
                case 6: OR_A(tmpB); break;
                case 7: CP_A(tmpB); break;
              }
              break;
            // RST nnn
            case 7:
              // OCR(5)
              contention_by1ts_ir(1);
              push_6ts(PC);
              MEMPTR = PC = opcode&0x38;
              break;
          }
          break;
      } // end switch
    }
    return tstates-tstart;
  }

  /**
   * Execute one instruction.
   * WARNING: this function ignores z80.nextEventTS.
   *
   * Params:
   *  none
   *
   * Returns:
   *  number of tstates spent
   */
  int execStep () {
    int one = nextEventTS;
    nextEventTS = -1;
    int res = exec(1);
    nextEventTS = one;
    return res;
  }

  /** Execute at least 'atstates' t-states; return real number of executed t-states.
   * WARNING: this function ignores z80.nextEventTS.
   *
   * Params:
   *  atstates = minimum tstates to spend
   *
   * Returns:
   *  number of tstates actually spent
   */
  int execTS (in int atstates) {
    if (atstates > 0) {
      int one = nextEventTS;
      nextEventTS = -1;
      int res = exec();
      nextEventTS = one;
      return res;
    }
    return 0;
  }

  /** Initiate maskable interrupt (if interrupts are enabled).
   *  May change z80.tstates.
   *
   * Params:
   *  none
   *
   * Returns:
   *  number of tstates taken by interrupt initiation or 0 if interrupts was disabled/ignored
   */
  int intr () {
    int ots = tstates;
    prevOpChangedFlags = false;
    if (prevWasEIDDR == EIDDR.LdIorR) { prevWasEIDDR = EIDDR.Normal; AF.f &= ~Z80Flags.PV; } // Z80 bug, NMOS only
    if (prevWasEIDDR == EIDDR.BlockInt || !IFF1) return 0; // not accepted
    if (halted) { halted = false; ++PC; }
    IFF1 = IFF2 = false; // disable interrupts
    final switch (mIM&0x03) {
      case 3: /* ??? */ /*IM = 0;*/ /* fallthru */ goto case 0;
      case 0: // take instruction from the bus (for now we assume that reading from bus always returns 0xff)
        // with a CALL nnnn on the data bus, it takes 19 cycles:
        // M1 cycle: 7 T to acknowledge interrupt (where exactly data bus reading occures?)
        // M2 cycle: 3 T to read low byte of 'nnnn' from data bus
        // M3 cycle: 3 T to read high byte of 'nnnn' and decrement SP
        // M4 cycle: 3 T to write high byte of PC to the stack and decrement SP
        // M5 cycle: 3 T to write low byte of PC and jump to 'nnnn'
        // BUT! FUSE says this:
        // Only the first byte is provided directly to the Z80: all remaining bytes
        // of the instruction are fetched from memory using PC, which is incremented as normal.
        tstates += 6;
        // fallthru
        goto case 1;
      case 1: // just do RST #38
        incR();
        tstates += 7; // M1 cycle: 7 T to acknowledge interrupt and decrement SP
        // M2 cycle: 3 T states write high byte of PC to the stack and decrement SP
        // M3 cycle: 3 T states write the low byte of PC and jump to #0038
        push_6ts(PC);
        MEMPTR = PC = 0x38;
        break;
      case 2:
        incR();
        tstates += 7; // M1 cycle: 7 T to acknowledge interrupt and decrement SP
        // M2 cycle: 3 T states write high byte of PC to the stack and decrement SP
        // M3 cycle: 3 T states write the low byte of PC
        push_6ts(PC);
        // M4 cycle: 3 T to read high byte from the interrupt vector
        // M5 cycle: 3 T to read low byte from bus and jump to interrupt routine
        ushort a = ((cast(ushort)I)<<8)|0xff;
        MEMPTR = PC = peekw_6ts(a);
        break;
    }
    return tstates-ots; // accepted
  }

  /** Initiate non-maskable interrupt.
   * May change z80.tstates.
   *
   * Params:
   *  none
   *
   * Returns:
   *  number of tstates taken by interrupt initiation or 0 if interrupts was disabled/ignored
   */
  int nmi () {
    int ots = tstates;
    prevOpChangedFlags = false;
    if (prevWasEIDDR == EIDDR.LdIorR) { prevWasEIDDR = EIDDR.Normal; AF.f &= ~Z80Flags.PV; } // emulate Z80 bug with interrupted LD A,I/R, NMOS only
    if (prevWasEIDDR == EIDDR.BlockInt || !IFF1) return 0; // not accepted
    /*prevWasEIDDR = EIDDR.Normal;*/ // don't care
    if (halted) { halted = false; ++PC; }
    incR();
    IFF1 = false; // IFF2 is not changed
    tstates += 5; // M1 cycle: 5 T states to do an opcode read and decrement SP
    // M2 cycle: 3 T states write high byte of PC to the stack and decrement SP
    // M3 cycle: 3 T states write the low byte of PC and jump to #0066
    push_6ts(PC);
    MEMPTR = PC = 0x66;
    return tstates-ots;
  }

  /** Pop 16-bit word from stack without contention and breakpoint triggering. Changes SP.
   *
   * Params:
   *  none
   *
   * Returns:
   *  popped word
   */
  ushort pop () nothrow @trusted @nogc {
    ushort res = memPeekB(SP++);
    res |= memPeekB(SP++)<<8;
    return res;
  }

  /** Push 16-bit word to stack without contention and breakpoint triggering. Changes SP.
   *
   * Params:
   *  value = word to push
   *
   * Returns:
   *  nothing
   */
  void push (ushort value) nothrow @trusted @nogc {
    memPokeB(--SP, (value>>8)&0xff);
    memPokeB(--SP, value&0xff);
  }

  /** Execute EXX command. */
  void exx () @safe nothrow @nogc {
    ushort t = BC; BC = BCx; BCx = t;
    t = DE; DE = DEx; DEx = t;
    t = HL; HL = HLx; HLx = t;
  }

  /** Execute EX AF,AF' command. */
  void exafaf () @safe nothrow @nogc {
    ushort t = AF; AF = AFx; AFx = t;
  }

protected nothrow @trusted @nogc:
  /* ************************************************************************** */
  /* simulate contented memory access */
  /* (tstates = tstates+contention+atstates)*cnt */
  /* (ushort addr, int tstates, MemIO mio) */
  final void contention (ushort addr, int cnt, bool mreq) {
    version(Zymosis_Testing) memContention(addr, mreq);
    if (mem.ptr[addr/MemPage.Size].contended) {
      auto cc = (mreq ? ulacont : ulacontport);
      if (tstates >= 0 && tstates < cc.length) {
        tstates += cc.ptr[tstates];
        //{ import core.stdc.stdio; printf("CT: #%04X ts:%u; (%u)\n", cast(uint)PC, cast(uint)(tstates-3), cast(uint)ulacont.ptr[tstates-3]); }
        version(Zymosis_Check_Contention) if (cc.ptr[tstates] != 0) assert(0, "intertal error: contention tables are wrong");
      }
    }
    tstates += cnt;
  }

  final void contention_by1ts (ushort addr, int cnt, bool mreq=true) {
    if (mem.ptr[addr/MemPage.Size].contended) {
      auto cc = (mreq ? ulacont : ulacontport);
      while (cnt-- > 0) {
        version(Zymosis_Testing) memContention(addr, mreq);
        if (tstates >= 0 && tstates < cc.length) {
          tstates += cc.ptr[tstates];
          version(Zymosis_Check_Contention) if (cc.ptr[tstates] != 0) assert(0, "intertal error: contention tables are wrong");
        }
        ++tstates;
      }
    } else {
      version(Zymosis_Testing) {
        while (cnt-- > 0) {
          memContention(addr, mreq);
          ++tstates;
        }
      } else {
        tstates += cnt;
      }
    }
  }

  final void contention_by1ts_ir (int cnt) { contention_by1ts(((I<<8)|R), cnt, false); }
  final void contention_by1ts_pc (int cnt, bool mreq) { contention_by1ts(PC, cnt, mreq); }

  /* ************************************************************************** */
  version(Zymosis_Testing) {} else {
    // port contention:
    //   Ports with A0 low are contended at the 2nd T-state
    //   Ports with A0 high are uncontended
    //   Ports with a high byte between 0x40 and 0x7F comply with 1 and 2 above, but are additionally contended:
    //       If A0 is low, the 1st T-state is also contended, 3rd and 4th are not.
    //       If A0 is high, all T-states are contended
    //   Reading the floating bus returns the second attribute byte of fetched pair (the last byte fetched), or 0xFF.
    final void doPortOp(bool lateio) (ushort port, scope void delegate () nothrow @trusted @nogc doio) nothrow @trusted @nogc {
      bool ulaPort = ((port&0x01) == 0);
      if (mem.ptr[port/MemPage.Size].contended) {
        // the port looks like contended memory address
        // first tstate is contended
        if (tstates >= 0 && tstates < ulacontport.length) tstates += ulacontport.ptr[tstates]; ++tstates;
        static if (!lateio) doio();
        // second tstate is contended
        if (tstates >= 0 && tstates < ulacontport.length) tstates += ulacontport.ptr[tstates]; ++tstates;
        // here port i/o occurs, at third tstate
        //static if (lateio) doio();
        // third and fourth tstates are contended for non-ULA ports
        if (!ulaPort && tstates >= 0 && tstates < ulacontport.length) tstates += ulacontport.ptr[tstates]; ++tstates;
        if (!ulaPort && tstates >= 0 && tstates < ulacontport.length) tstates += ulacontport.ptr[tstates];
        static if (lateio) doio(); // and FUSE says that it is here
        ++tstates;
      } else {
        // the port doesn't look like contended memory address
        // first tstate is not contended
        ++tstates;
        static if (!lateio) doio();
        // second tstate is contended for all ULA ports
        if (ulaPort && tstates >= 0 && tstates < ulacontport.length) tstates += ulacontport.ptr[tstates]; ++tstates;
        // here port i/o occurs, at third tstate
        //static if (lateio) doio();
        // third and fourth tstates are not contended
        //tstates += 2;
        ++tstates;
        static if (lateio) doio(); // and FUSE says that it is here
        ++tstates;
      }
    }
  }

  ubyte port_read (ushort port) {
    ubyte value;
    version(Zymosis_Testing) {
      portContention(port, 1, true, true); /* early */
      value = portRead(port);
      portContention(port, 2, true, false); /* normal */
      ++tstates;
    } else {
      doPortOp!true(port, () { value = portRead(port); });
    }
    return value;
  }

  void port_write (ushort port, ubyte value) {
    version(Zymosis_Testing) {
      portContention(port, 1, false, true); /* early */
      portWrite(port, value);
      portContention(port, 2, false, false); /* normal */
      ++tstates;
    } else {
      doPortOp!false(port, () { portWrite(port, value); });
    }
  }

  // ////////////////////////////////////////////////////////////////////////// //
  //TODO: memory breakpoints
  ubyte peekb (ushort addr) {
    pragma(inline, true);
    version(Zymosis_Testing) memReading(addr);
    return mem.ptr[addr/MemPage.Size].mem[addr%MemPage.Size];
  }

  void pokeb (ushort addr, ubyte b) {
    version(Zymosis_Testing) memWriting(addr, b);
    if (auto mpg = mem.ptr+addr/MemPage.Size) {
      if (!mpg.rom) {
        if (mpg.writeHook) memWriteHook(addr, b);
        mpg.mem[addr%MemPage.Size] = b;
      }
    }
  }

  // t1: setting /MREQ & /RD
  // t2: memory read
  ubyte peekb_3ts (ushort addr) {
    pragma(inline, true);
    version(Zymosis_Testing) {} else pragma(inline, true);
    contention(addr, 3, true);
    return peekb(addr);
  }

  void peekb_3ts_args_noread () {
    version(Zymosis_Testing) {} else pragma(inline, true);
    contention(PC, 3, false); //FIXME???
  }

  ubyte peekb_3ts_args () {
    pragma(inline, true);
    version(Zymosis_Testing) {} else pragma(inline, true);
    contention(PC, 3, true);
    return peekb(PC);
  }

  // t1: setting /MREQ & /WR
  // t2: memory write
  void pokeb_3ts (ushort addr, ubyte b) {
    //pragma(inline, true);
    contention(addr, 3, true);
    pokeb(addr, b);
  }

  ushort peekw_6ts (ushort addr) {
    version(Zymosis_Testing) {} else pragma(inline, true);
    ushort res = peekb_3ts(addr++);
    res |= peekb_3ts(addr)<<8;
    return res;
  }

  void pokew_6ts (ushort addr, ushort value) {
    //pragma(inline, true);
    pokeb_3ts(addr, value&0xff);
    pokeb_3ts((addr+1)&0xffff, (value>>8)&0xff);
  }

  void pokew_6ts_inverted (ushort addr, ushort value) {
    //pragma(inline, true);
    pokeb_3ts((addr+1)&0xffff, (value>>8)&0xff);
    pokeb_3ts(addr, value&0xff);
  }

  ushort getpcw (int wait1) {
    //pragma(inline, true);
    ushort res = peekb_3ts_args();
    ++PC;
    res |= peekb_3ts_args()<<8;
    if (wait1) contention_by1ts(PC, wait1, true);
    ++PC;
    return res;
  }

  ushort getpcw_cc (int wait1, bool truecc) {
    //pragma(inline, true);
    peekb_3ts_args_noread();
    version(Zymosis_Testing) {
      if (truecc) memReading(PC);
      ushort res = memPeekB(PC++);
    } else {
      ushort res = peekb(PC++);
    }
    peekb_3ts_args_noread();
    version(Zymosis_Testing) {
      if (truecc) memReading(PC);
      res |= memPeekB(PC)<<8;
    } else {
      res |= peekb(PC)<<8;
    }
    if (wait1) contention_by1ts_pc(wait1, true);
    ++PC;
    return res;
  }

  ushort pop_6ts () {
    pragma(inline, true);
    ushort res = peekb_3ts(SP++);
    res |= peekb_3ts(SP++)<<8;
    return res;
  }

  // 3 T states write high byte of PC to the stack and decrement SP
  // 3 T states write the low byte of PC and jump to #0066
  void push_6ts (ushort value) {
    //pragma(inline, true);
    pokeb_3ts(--SP, (value>>8)&0xff);
    pokeb_3ts(--SP, value&0xff);
  }

  // you are not expected to understand the following bitmess
  // the only thing you want to know that IT WORKS; just believe me and testing suite
 nothrow @trusted @nogc {
  void ADC_A (ubyte b) {
    pragma(inline, true);
    ushort newv, o = AF.a;
    AF.a = (newv = cast(ushort)(o+b+(AF.f&Z80Flags.C)))&0xff; // Z80Flags.C is 0x01, so it's safe
    prevOpChangedFlags = true;
    AF.f =
      tblSZ53.ptr[newv&0xff]|
      (newv > 0xff ? Z80Flags.C : 0)|
      ((o^(~b))&(o^newv)&0x80 ? Z80Flags.PV : 0)|
      ((o&0x0f)+(b&0x0f)+(AF.f&Z80Flags.C) >= 0x10 ? Z80Flags.H : 0);
  }

  void SBC_A (ubyte b) {
    pragma(inline, true);
    ushort newv, o = AF.a;
    AF.a = (newv = (cast(int)o-cast(int)b-cast(int)(AF.f&Z80Flags.C))&0xffff)&0xff; // Z80Flags.C is 0x01, so it's safe
    prevOpChangedFlags = true;
    AF.f =
      Z80Flags.N|
      tblSZ53.ptr[newv&0xff]|
      (newv > 0xff ? Z80Flags.C : 0)|
      ((o^b)&(o^newv)&0x80 ? Z80Flags.PV : 0)|
      (cast(int)(o&0x0f)-cast(int)(b&0x0f)-cast(int)(AF.f&Z80Flags.C) < 0 ? Z80Flags.H : 0);
  }

  void ADD_A (ubyte b) {
    pragma(inline, true);
    AF.f &= ~Z80Flags.C;
    ADC_A(b);
  }

  void SUB_A (ubyte b) {
    pragma(inline, true);
    AF.f &= ~Z80Flags.C;
    SBC_A(b);
  }

  void CP_A (ubyte b) {
    pragma(inline, true);
    ubyte o = AF.a, newv = (cast(int)o-cast(int)b)&0xff;
    prevOpChangedFlags = true;
    AF.f =
      Z80Flags.N|
      (newv&Z80Flags.S)|
      (b&Z80Flags.F35)|
      (newv == 0 ? Z80Flags.Z : 0)|
      (o < b ? Z80Flags.C : 0)|
      ((o^b)&(o^newv)&0x80 ? Z80Flags.PV : 0)|
      (cast(int)(o&0x0f)-cast(int)(b&0x0f) < 0 ? Z80Flags.H : 0);
  }

  void AND_A (ubyte b) { pragma(inline, true); AF.f = tblSZP53.ptr[AF.a &= b]|Z80Flags.H; prevOpChangedFlags = true; }
  void OR_A (ubyte b) { pragma(inline, true); AF.f = tblSZP53.ptr[AF.a |= b]; prevOpChangedFlags = true; }
  void XOR_A (ubyte b) { pragma(inline, true); AF.f = tblSZP53.ptr[AF.a ^= b]; prevOpChangedFlags = true; }

  // carry unchanged
  ubyte DEC8 (ubyte b) {
    pragma(inline, true);
    prevOpChangedFlags = true;
    AF.f &= Z80Flags.C;
    AF.f |= Z80Flags.N|
      (b == 0x80 ? Z80Flags.PV : 0)|
      (b&0x0f ? 0 : Z80Flags.H)|
      tblSZ53.ptr[(cast(int)b-1)&0xff];
    return (cast(int)b-1)&0xff;
  }

  // carry unchanged
  ubyte INC8 (ubyte b) {
    pragma(inline, true);
    prevOpChangedFlags = true;
    AF.f &= Z80Flags.C;
    AF.f |=
      (b == 0x7f ? Z80Flags.PV : 0)|
      ((b+1)&0x0f ? 0 : Z80Flags.H )|
      tblSZ53.ptr[(b+1)&0xff];
    return ((b+1)&0xff);
  }

  // cyclic, carry reflects shifted bit
  void RLCA () {
    pragma(inline, true);
    ubyte c = ((AF.a>>7)&0x01);
    AF.a = cast(ubyte)((AF.a<<1)|c);
    prevOpChangedFlags = true;
    AF.f = cast(ubyte)(c|(AF.a&Z80Flags.F35)|(AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S)));
  }

  // cyclic, carry reflects shifted bit
  void RRCA () {
    pragma(inline, true);
    ubyte c = (AF.a&0x01);
    AF.a = cast(ubyte)((AF.a>>1)|(c<<7));
    prevOpChangedFlags = true;
    AF.f = cast(ubyte)(c|(AF.a&Z80Flags.F35)|(AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S)));
  }

  // cyclic thru carry
  void RLA () {
    pragma(inline, true);
    ubyte c = ((AF.a>>7)&0x01);
    AF.a = cast(ubyte)((AF.a<<1)|(AF.f&Z80Flags.C));
    prevOpChangedFlags = true;
    AF.f = cast(ubyte)(c|(AF.a&Z80Flags.F35)|(AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S)));
  }

  // cyclic thru carry
  void RRA () {
    pragma(inline, true);
    ubyte c = (AF.a&0x01);
    AF.a = (AF.a>>1)|((AF.f&Z80Flags.C)<<7);
    prevOpChangedFlags = true;
    AF.f = c|(AF.a&Z80Flags.F35)|(AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S));
  }

  // cyclic thru carry
  ubyte RL (ubyte b) {
    pragma(inline, true);
    ubyte c = (b>>7)&Z80Flags.C;
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b = ((b<<1)&0xff)|(AF.f&Z80Flags.C))]|c;
    return b;
  }

  ubyte RR (ubyte b) {
    pragma(inline, true);
    ubyte c = (b&0x01);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b = (b>>1)|((AF.f&Z80Flags.C)<<7))]|c;
    return b;
  }

  // cyclic, carry reflects shifted bit
  ubyte RLC (ubyte b) {
    pragma(inline, true);
    ubyte c = ((b>>7)&Z80Flags.C);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b = ((b<<1)&0xff)|c)]|c;
    return b;
  }

  // cyclic, carry reflects shifted bit
  ubyte RRC (ubyte b) {
    pragma(inline, true);
    ubyte c = (b&0x01);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b = cast(ubyte)((b>>1)|(c<<7)))]|c;
    return b;
  }

  ubyte SLA (ubyte b) {
    pragma(inline, true);
    ubyte c = ((b>>7)&0x01);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b <<= 1)]|c;
    return b;
  }

  ubyte SRA (ubyte b) {
    pragma(inline, true);
    ubyte c = (b&0x01);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b = (b>>1)|(b&0x80))]|c;
    return b;
  }

  ubyte SLL (ubyte b) {
    pragma(inline, true);
    ubyte c = ((b>>7)&0x01);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b = cast(ubyte)((b<<1)|0x01))]|c;
    return b;
  }

  ubyte SLR (ubyte b) {
    pragma(inline, true);
    ubyte c = (b&0x01);
    prevOpChangedFlags = true;
    AF.f = tblSZP53.ptr[(b >>= 1)]|c;
    return b;
  }

  static immutable ubyte[8] hct = [ 0, Z80Flags.H, Z80Flags.H, Z80Flags.H, 0, 0, 0, Z80Flags.H ];

  // ddvalue+value
  ushort ADD_DD (ushort value, ushort ddvalue) {
    pragma(inline, true);
    uint res = cast(uint)value+cast(uint)ddvalue;
    ubyte b = ((value&0x0800)>>11)|((ddvalue&0x0800)>>10)|((res&0x0800)>>9);
    MEMPTR = (ddvalue+1)&0xffff;
    prevOpChangedFlags = true;
    AF.f =
      (AF.f&(Z80Flags.PV|Z80Flags.Z|Z80Flags.S))|
      (res > 0xffff ? Z80Flags.C : 0)|
      ((res>>8)&Z80Flags.F35)|
      hct.ptr[b];
    return cast(ushort)res;
  }

  // ddvalue+value
  ushort ADC_DD (ushort value, ushort ddvalue) {
    pragma(inline, true);
    ubyte c = (AF.f&Z80Flags.C);
    uint newv = cast(uint)value+cast(uint)ddvalue+cast(uint)c;
    ushort res = newv&0xffff;
    MEMPTR = (ddvalue+1)&0xffff;
    prevOpChangedFlags = true;
    AF.f =
      ((res>>8)&Z80Flags.S35)|
      (res == 0 ? Z80Flags.Z : 0)|
      (newv > 0xffff ? Z80Flags.C : 0)|
      ((value^((~ddvalue)&0xffff))&(value^newv)&0x8000 ? Z80Flags.PV : 0)|
      ((value&0x0fff)+(ddvalue&0x0fff)+c >= 0x1000 ? Z80Flags.H : 0);
    return res;
  }

  // ddvalue-value
  ushort SBC_DD (ushort value, ushort ddvalue) {
    //pragma(inline, true);
    ubyte tmpB = AF.a;
    MEMPTR = (ddvalue+1)&0xffff;
    AF.a = ddvalue&0xff;
    SBC_A(value&0xff);
    ushort res = AF.a;
    AF.a = (ddvalue>>8)&0xff;
    SBC_A((value>>8)&0xff);
    res |= (AF.a<<8);
    AF.a = tmpB;
    AF.f = (res ? AF.f&(~Z80Flags.Z) : AF.f|Z80Flags.Z);
    return res;
  }

  void BIT (ubyte bit, ubyte num, bool gotDD, bool mptr) {
    pragma(inline, true);
    prevOpChangedFlags = true;
    AF.f =
      Z80Flags.H|
      (AF.f&Z80Flags.C)|
      ((gotDD /*|| mptr*/ ? MEMPTR.h : num)&Z80Flags.F35)|
      (num&(1<<bit) ? 0 : Z80Flags.PV|Z80Flags.Z)|
      (num&((1<<bit)&Z80Flags.S))
      /*(bit == 7 ? num&Z80Flags.S : 0)*/;
    //if (mptr) AF.f = (AF.f&~Z80Flags.F35)|(MEMPTR.h&Z80Flags.F35);
  }

  void DAA () {
    //pragma(inline, true);
    ubyte tmpI = 0, tmpC = (AF.f&Z80Flags.C), tmpA = AF.a;
    if ((AF.f&Z80Flags.H) || (tmpA&0x0f) > 9) tmpI = 6;
    if (tmpC != 0 || tmpA > 0x99) tmpI |= 0x60;
    if (tmpA > 0x99) tmpC = Z80Flags.C;
    if (AF.f&Z80Flags.N) SUB_A(tmpI); else ADD_A(tmpI);
    prevOpChangedFlags = true;
    AF.f = (AF.f&~(Z80Flags.C|Z80Flags.PV))|tmpC|tblParity.ptr[AF.a];
  }
 } // //

  void RRD_A () {
    //pragma(inline, true);
    ubyte tmpB = peekb_3ts(HL);
    //IOP(4)
    MEMPTR = (HL+1)&0xffff;
    contention_by1ts(HL, 4, true);
    pokeb_3ts(HL, cast(ubyte)((AF.a<<4)|(tmpB>>4)));
    AF.a = (AF.a&0xf0)|(tmpB&0x0f);
    prevOpChangedFlags = true;
    AF.f = (AF.f&Z80Flags.C)|tblSZP53.ptr[AF.a];
  }

  void RLD_A () {
    //pragma(inline, true);
    ubyte tmpB = peekb_3ts(HL);
    //IOP(4)
    MEMPTR = (HL+1)&0xffff;
    contention_by1ts(HL, 4, true);
    pokeb_3ts(HL, cast(ubyte)((tmpB<<4)|(AF.a&0x0f)));
    AF.a = (AF.a&0xf0)|(tmpB>>4);
    prevOpChangedFlags = true;
    AF.f = (AF.f&Z80Flags.C)|tblSZP53.ptr[AF.a];
  }

  void LD_A_IR (ubyte ir) {
    pragma(inline, true);
    AF.a = ir;
    prevWasEIDDR = EIDDR.LdIorR;
    contention_by1ts_ir(1);
    prevOpChangedFlags = true;
    AF.f = tblSZ53.ptr[AF.a]|(AF.f&Z80Flags.C)|(IFF2 ? Z80Flags.PV : 0);
  }

// ////////////////////////////////////////////////////////////////////////// //
// opcode info interface
public:
  /// conditions for various jump instructions
  enum ZOICond {
    None = -1, ///
    NZ, Z, ///
    NC, C, ///
    PO, PE, ///
    P, M, ///
    BCNZ, BNZ, ///
    RETI, RETN ///
  }

  /// indirect memory access type
  enum ZOIMemIO : int {
    None = -666, ///
    SP = -6, ///
    BC = -5, ///
    DE = -4, ///
    IY = -3, ///
    IX = -2, ///
    HL = -1 ///
  }

  /// indirect jump type
  enum ZOIJump : int {
    None = -666, ///
    RET = -4, ///
    IY = -3, ///
    IX = -2, ///
    HL = -1 ///
  }

  /// port i/o type
  enum ZOIPortIO : int {
    None = -666, ///
    BC = -1, ///
    BCM1 = -2 /// (B-1)C, for OUT*
  }

  /// stack access type
  enum ZOIStack {
    None = -666, ///
    BC = 0, DE, HL, AF, IX, IY, PC ///
  }

  enum ZOIDisp { None = 0xffff }

  /// opcode info
  struct ZOInfo {
    int len = 0; /// instruction length
    bool memrwword = false; /// true: reading word
    int memread = ZOIMemIO.None; /// ZOIMemIO or addr
    int memwrite = ZOIMemIO.None; /// ZOIMemIO or addr
    int jump = ZOIJump.None; /// ZOIJump or addr
    ZOICond cond = ZOICond.None; /// ZOICond
    int portread = ZOIPortIO.None; /// ZOIPortIO or addr; if addr is specified, high byte must be taken from A
    int portwrite = ZOIPortIO.None; /// ZOIPortIO or addr; if addr is specified, high byte must be taken from A
    ZOIStack push = ZOIStack.None; /// ZOIStack; CALL/RST will set ZOIStack.PC
    ZOIStack pop = ZOIStack.None; /// ZOIStack; RET will set ZOIStack.PC
    int disp = ZOIDisp.None; /// for (IX+n) / (IY+n), else ZOIDisp.None
    int trap = -1; /// slt and other trap opcode or -1
  }

  /// Get opcode information. Useful for debuggers.
  final void opcodeInfo (ref ZOInfo nfo, ushort pc) nothrow @trusted @nogc {
    static bool isRepeated() (ushort opc) pure nothrow @safe @nogc { pragma(inline, true); return ((opc&0x10) != 0); }

    ushort orgpc = pc;
    int ixy = -1; // 0: ix; 1: iy
    int disp = 0;
    bool gotDD = false;
    nfo = nfo.init;

    ubyte memReadPC () nothrow @trusted @nogc { immutable ubyte b = mem.ptr[pc/MemPage.Size].mem[pc%MemPage.Size]; ++pc; return b; }
    ushort readPCW () nothrow @trusted @nogc { ushort res = memReadPC; res |= memReadPC<<8; return res; }

    ubyte opcode = memReadPC;
    if (opcode == 0xdd || opcode == 0xfd) {
      static immutable uint[8] withIndexBmp = [0x00u,0x700000u,0x40404040u,0x40bf4040u,0x40404040u,0x40404040u,0x0800u,0x00u];
      // IX/IY prefix
      ixy = (opcode == 0xfd ? 1 : 0); // just in case, hehe
      //opcode = memRead(pc++, MemIO.Other);
      opcode = memReadPC;
      if (withIndexBmp[opcode>>5]&(1<<(opcode&0x1f))) {
        // 3rd byte is always DISP here
        disp = memReadPC;
        if (disp > 127) disp -= 256; // convert to int8_t
        nfo.disp = disp;
        nfo.memread = (ixy ? ZOIMemIO.IY : ZOIMemIO.IX);
      } else if (opcode == 0xdd && opcode == 0xfd) {
        // double prefix
        nfo.len = 1;
        return;
      }
      gotDD = 1;
    }
    // instructions
    if (opcode == 0xed) {
      ixy = 0; // а нас -- рать!
      opcode = memReadPC;
      switch (opcode) {
        // LDI, LDIR, LDD, LDDR
        case 0xa0: case 0xb0: case 0xa8: case 0xb8:
          nfo.memwrite = ZOIMemIO.DE;
          goto case;
        // CPI, CPIR, CPD, CPDR
        case 0xa1: case 0xb1: case 0xa9: case 0xb9:
          nfo.memread = ZOIMemIO.HL;
          if (isRepeated(opcode)) { nfo.cond = ZOICond.BNZ; nfo.jump = orgpc; }
          break;
        // INI, INIR, IND, INDR
        case 0xa2: case 0xb2: case 0xaa: case 0xba:
          goto case;
        // OUTI, OTIR, OUTD, OTDR
        case 0xa3: case 0xb3: case 0xab: case 0xbb:
          if (opcode&0x01) nfo.portwrite = ZOIPortIO.BCM1; else nfo.portread = ZOIPortIO.BC;
          if (isRepeated(opcode)) { nfo.cond = ZOICond.BNZ; nfo.jump = orgpc; }
          break;
        // not strings, but some good instructions anyway
        default: // traps
          if ((opcode&0xc0) == 0x40) {
            switch (opcode&0x07) {
              // IN r8,(C)
              case 0: nfo.portread = ZOIPortIO.BC; break;
              // OUT (C),r8
              case 1: nfo.portwrite = ZOIPortIO.BC; break;
              // SBC HL,rr/ADC HL,rr
              /*case 2: break;*/
              // LD (nn),rr/LD rr,(nn)
              case 3:
                if (opcode&0x08) nfo.memread = readPCW; else nfo.memwrite = readPCW;
                nfo.memrwword = true;
                break;
              // NEG
              /*case 4: break;*/
              // RETI/RETN
              case 5:
                nfo.jump = ZOIJump.RET;
                nfo.pop = ZOIStack.PC;
                nfo.cond = (opcode&0x08 ? ZOICond.RETI : ZOICond.RETN);
                nfo.memread = ZOIMemIO.SP;
                nfo.memrwword = true;
                break;
              // IM n
              /*case 6: break;*/
              // specials
              case 7:
                switch (opcode) {
                  // LD I,A
                  /*case 0x47: break;*/
                  // LD R,A
                  /*case 0x4f: break;*/
                  // LD A,I
                  /*case 0x57: break;*/
                  // LD A,R
                  /*case break;*/
                  // RRD
                  case 0x67:
                  // RLD
                  case 0x6F:
                    nfo.memread = nfo.memwrite = ZOIMemIO.HL;
                    break;
                  default:
                }
                break;
              default:
            }
          } else {
            nfo.trap = opcode;
          }
          break;
      }
      // 0xed done
    } else if (opcode == 0xcb) {
      // shifts and bit operations
      //opcode = memRead(pc++, MemIO.Other);
      opcode = memReadPC;
      if (!gotDD && (opcode&0x07) == 6) nfo.memread = nfo.memwrite = ZOIMemIO.HL;
      if ((opcode&0xc0) != 0x40) {
        if (gotDD) nfo.memwrite = nfo.memread; // all except BIT writes back
      } else {
        nfo.memwrite = ZOIMemIO.None;
      }
      // 0xcb done
    } else {
      // normal things
      final switch (opcode&0xc0) {
        // 0x00..0x3F
        case 0x00:
          switch (opcode&0x07) {
            // misc,DJNZ,JR,JR cc
            case 0:
              if (opcode&0x30) {
                // branches
                     if (opcode&0x20) nfo.cond = cast(ZOICond)((opcode>>3)&0x03); // JR cc
                else if ((opcode&0x08) == 0) nfo.cond = ZOICond.BNZ; // DJNZ ; else -- JR
                //disp = memRead(pc++, MemIO.Other);
                disp = memReadPC;
                if (disp > 127) disp -= 256; // convert to byte
                nfo.jump = (pc+disp)&0xffff;
              } // else EX AF,AF' or NOP
              break;
            // LD rr,nn/ADD HL,rr
            case 1:
              if (!(opcode&0x08)) pc = (pc+2)&0xffff;
              break;
            // LD xxx,xxx
            case 2:
              final switch ((opcode>>3)&0x07) {
                // LD (BC),A
                case 0: nfo.memwrite = ZOIMemIO.BC; break;
                // LD A,(BC)
                case 1: nfo.memread = ZOIMemIO.BC; break;
                // LD (DE),A
                case 2: nfo.memwrite = ZOIMemIO.DE; break;
                // LD A,(DE)
                case 3: nfo.memread = ZOIMemIO.DE; break;
                // LD (nn),HL
                case 4:
                  nfo.memwrite = readPCW;
                  nfo.memrwword = true;
                  break;
                // LD HL,(nn)
                case 5:
                  nfo.memread = readPCW;
                  nfo.memrwword = true;
                  break;
                // LD (nn),A
                case 6:
                  nfo.memwrite = readPCW;
                  break;
                // LD A,(nn)
                case 7:
                  nfo.memread = readPCW;
                  break;
              }
              break;
            // INC rr/DEC rr
            /*case 3: break;*/
            // INC r8
            case 4:
              goto case;
            // DEC r8
            case 5:
              if (((opcode>>3)&0x07) == 6) {
                // (HL) or (IXY+n)
                if (gotDD) nfo.memwrite = nfo.memread;
                else nfo.memwrite = nfo.memread = ZOIMemIO.HL;
              }
              break;
            // LD r8,n
            case 6:
              ++pc;
              if (((opcode>>3)&0x07) == 6) {
                if (!gotDD) nfo.memwrite = ZOIMemIO.HL;
                else { nfo.memwrite = nfo.memread; nfo.memread = ZOIMemIO.None; }
              }
              break;
            // swim-swim-hungry
            /*case 7: break;*/
            default:
          }
          break;
        // 0x40..0x7F: LD r8,r8
        case 0x40:
          if (opcode != 0x76) {
            if (!gotDD && (opcode&0x07) == 6) nfo.memread = ZOIMemIO.HL;
            if (((opcode>>3)&0x07) == 6) { nfo.memwrite = (gotDD ? nfo.memread : ZOIMemIO.HL); nfo.memread = ZOIMemIO.None; }
          }
          break;
        // 0x80..0xBF: ALU A,r8
        case 0x80:
          if (!gotDD && (opcode&0x07) == 6) nfo.memread = ZOIMemIO.HL;
          break;
        // 0xC0..0xFF
        case 0xC0:
          final switch (opcode&0x07) {
            // RET cc
            case 0:
              nfo.jump = ZOIJump.RET;
              nfo.pop = ZOIStack.PC;
              nfo.cond = cast(ZOICond)((opcode>>3)&0x07);
              nfo.memread = ZOIMemIO.SP;
              nfo.memrwword = true;
              break;
            // POP rr/special0
            case 1:
              if (opcode&0x08) {
                // special 0
                switch ((opcode>>4)&0x03) {
                  // RET
                  case 0:
                    nfo.jump = ZOIJump.RET;
                    nfo.pop = ZOIStack.PC;
                    nfo.memread = ZOIMemIO.SP;
                    nfo.memrwword = true;
                    break;
                  // EXX
                  /*case 1: break;*/
                  // JP (HL)
                  case 2:
                    nfo.jump = (ixy < 0 ? ZOIJump.HL : (ixy ? ZOIJump.IY : ZOIJump.IX));
                    break;
                  // LD SP,HL
                  /*case 3: break;*/
                  default:
                }
              } else {
                // POP rr
                nfo.memread = ZOIMemIO.SP;
                nfo.memrwword = true;
                final switch ((opcode>>4)&0x03) {
                  case 0: nfo.pop = ZOIStack.BC; break;
                  case 1: nfo.pop = ZOIStack.DE; break;
                  case 2: nfo.pop = (ixy < 0 ? ZOIStack.HL : (ixy ? ZOIStack.IY : ZOIStack.IX)); break;
                  case 3: nfo.pop = ZOIStack.AF; break;
                }
              }
              break;
            // JP cc,nn
            case 2:
              nfo.jump = readPCW;
              nfo.cond = cast(ZOICond)((opcode>>3)&0x07);
              break;
            // special1/special3
            case 3:
              switch ((opcode>>3)&0x07) {
                // JP nn
                case 0:
                  nfo.jump = readPCW;
                  break;
                // OUT (n),A
                case 2:
                  //nfo.portwrite = memRead(pc++, MemIO.Other);
                  nfo.portwrite = memReadPC;
                  break;
                // IN A,(n)
                case 3:
                  //nfo.portread = memRead(pc++, MemIO.Other);
                  nfo.portread = memReadPC;
                  break;
                // EX (SP),HL
                case 4:
                  nfo.memread = nfo.memwrite = ZOIMemIO.SP;
                  nfo.memrwword = true;
                  break;
                // EX DE,HL
                /*case 5: break;*/
                // DI
                /*case 6: break;*/
                // EI
                /*case 7: break;*/
                default:
              }
              break;
            // CALL cc,nn
            case 4:
              nfo.jump = readPCW;
              nfo.push = ZOIStack.PC;
              nfo.cond = cast(ZOICond)((opcode>>3)&0x07);
              nfo.memwrite = ZOIMemIO.SP;
              nfo.memrwword = true;
              break;
            // PUSH rr/special2
            case 5:
              if (opcode&0x08) {
                if (((opcode>>4)&0x03) == 0) {
                  // CALL
                  nfo.jump = readPCW;
                  nfo.push = ZOIStack.PC;
                  nfo.memwrite = ZOIMemIO.SP;
                  nfo.memrwword = true;
                }
              } else {
                // PUSH rr
                nfo.memwrite = ZOIMemIO.SP;
                nfo.memrwword = true;
                final switch ((opcode>>4)&0x03) {
                  case 0: nfo.push = ZOIStack.BC; break;
                  case 1: nfo.push = ZOIStack.DE; break;
                  case 2: nfo.push = (ixy >= 0 ? (ixy ? ZOIStack.IY : ZOIStack.IX) : ZOIStack.HL); break;
                  case 3: nfo.push = ZOIStack.AF; break;
                }
              }
              break;
            // ALU A,n
            case 6:
              ++pc;
              break;
            // RST nnn
            case 7:
              nfo.jump = (opcode&0x38);
              nfo.push = ZOIStack.PC;
              nfo.memwrite = ZOIMemIO.SP;
              nfo.memrwword = true;
              break;
          }
          break;
      }
    }
    nfo.len = (pc >= orgpc ? pc-orgpc : pc+0x10000-orgpc);
  }

// ////////////////////////////////////////////////////////////////////////// //
// simple disasm
public:
  /// disassembled opcode
  struct ZDisop {
    int len; /// instruction length
    char[128] disbuf; /// buffer that holds disassembled text
    const(char)[] mnemo; /// points into disbuf
    const(char)[][3] args; /// points into disbuf
    // disassembler options
    bool decimal; /// use decimal numbers instead of #XXXX
    bool locase; /// use lower-cased text
  }

  /// Disassemble command
  final void disasm (ref ZDisop nfo, ushort pc) nothrow @trusted @nogc {
    ubyte memReadPC () nothrow @trusted @nogc { /*pragma(inline, true);*/ immutable ubyte b = mem.ptr[pc/MemPage.Size].mem[pc%MemPage.Size]; ++pc; return b; }
    ushort memReadPCW () nothrow @trusted @nogc {
      ushort w = mem.ptr[pc/MemPage.Size].mem[pc%MemPage.Size];
      ++pc;
      w |= mem.ptr[pc/MemPage.Size].mem[pc%MemPage.Size]<<8;
      ++pc;
      return w;
    }

    uint stpc = pc;
    scope(exit) nfo.len = (pc < stpc ? pc+0x10000-stpc : pc-stpc);

    bool gotDD;
    int disp;
    string DD = "HL";

    nfo.len = 0;
    nfo.mnemo = null;
    nfo.args[] = null;
    uint dbpos = 0;
    uint dbstpos = 0;
    ubyte curarg = 0;

    void endMnemo () {
      if (nfo.mnemo.length) assert(0, "internal error");
      nfo.mnemo = nfo.disbuf[0..dbpos];
      dbstpos = dbpos;
    }

    void endArg () {
      if (curarg >= nfo.args.length) assert(0, "internal error");
      nfo.args[curarg++] = nfo.disbuf[dbstpos..dbpos];
      dbstpos = dbpos;
    }

    void putKeepCase (const(char)[] s...) nothrow @trusted @nogc {
      assert(s.length <= 1024);
      if (dbpos+s.length > nfo.disbuf.length) s = s[0..nfo.disbuf.length-dbpos];
      if (s.length) {
        nfo.disbuf[dbpos..dbpos+s.length] = s[];
        dbpos += cast(uint)s.length;
      }
    }

    void put (const(char)[] s...) nothrow @trusted @nogc {
      assert(s.length <= 1024);
      if (dbpos+s.length > nfo.disbuf.length) s = s[0..nfo.disbuf.length-dbpos];
      foreach (char ch; s) {
        if (nfo.locase) {
          if (ch >= 'A' && ch <= 'Z') ch += 32;
        } else {
          if (ch >= 'a' && ch <= 'z') ch -= 32;
        }
        nfo.disbuf.ptr[dbpos++] = ch;
      }
    }

    void putMnemo (string s) nothrow @trusted @nogc {
      put(s);
      endMnemo();
    }

    void putArg (string s) nothrow @trusted @nogc {
      put(s);
      endArg();
    }

    void putUIntDec (uint n) nothrow @trusted @nogc {
      char[16] buf = void;
      uint bpos = cast(uint)buf.length;
      do { buf.ptr[--bpos] = cast(char)('0'+n%10); } while ((n /= 10) != 0);
      put(buf[bpos..$]);
    }

    void putUIntHex (uint n, int len) nothrow @trusted @nogc {
      char[16] buf = void;
      uint bpos = cast(uint)buf.length;
      do { buf.ptr[--bpos] = cast(char)('0'+n%16+(n%16 > 9 ? 7 : 0)); } while ((n /= 16) != 0);
      while (buf.length-bpos < len) buf.ptr[--bpos] = '0';
      buf.ptr[--bpos] = '#';
      put(buf[bpos..$]);
    }

    void putUInt (uint n, int len) nothrow @trusted @nogc {
      if (nfo.decimal) putUIntDec(n); else putUIntHex(n, len);
    }

    void putDisp (int n) nothrow @trusted @nogc {
      if (n < 0) {
        put("-");
        putUIntDec(-n);
      } else {
        put("+");
        putUIntDec(n);
      }
    }

    void putCC (uint n) {
      final switch (n) {
        case 0: putArg("NZ"); break;
        case 1: putArg("Z"); break;
        case 2: putArg("NC"); break;
        case 3: putArg("C"); break;
        case 4: putArg("PO"); break;
        case 5: putArg("PE"); break;
        case 6: putArg("P"); break;
        case 7: putArg("M"); break;
      }
    }

    void putR8(string hlspec=null) (uint n) {
      final switch (n) {
        case 0: putArg("B"); break;
        case 1: putArg("C"); break;
        case 2: putArg("D"); break;
        case 3: putArg("E"); break;
        case 4: putArg("H"); break;
        case 5: putArg("L"); break;
        case 6:
          static if (hlspec.length) {
            putArg(hlspec);
          } else {
            put("(");
            put(DD);
            if (gotDD) putDisp(disp);
            put(")");
          }
          break;
        case 7: putArg("A"); break;
      }
    }

    void putR16SP(string hlspec=null) (uint n) {
      final switch (n) {
        case 0: putArg("BC"); break;
        case 1: putArg("DE"); break;
        case 2: static if (hlspec.length) putArg(hlspec); else putArg(DD); break;
        case 3: putArg("SP"); break;
      }
    }

    void putR16AF(string hlspec=null) (uint n) {
      final switch (n) {
        case 0: putArg("BC"); break;
        case 1: putArg("DE"); break;
        case 2: static if (hlspec.length) putArg(hlspec); else putArg(DD); break;
        case 3: putArg("AF"); break;
      }
    }

    ubyte opcode = memReadPC;
    disp = 0;
    gotDD = false;
    //DD = &HL;
    // check for I[XY] prefix
    if (opcode == 0xdd || opcode == 0xfd) {
      //TODO: generate this table in compile time
      static immutable uint[8] withIndexBmp = [0x00,0x700000,0x40404040,0x40bf4040,0x40404040,0x40404040,0x0800,0x00];
      // IX/IY prefix
      DD = (opcode == 0xdd ? "IX" : "IY");
      // read opcode -- OCR(4)
      opcode = memReadPC;
      // test if this instruction have (HL)
      if (withIndexBmp[opcode>>5]&(1<<(opcode&0x1f))) {
        // 3rd byte is always DISP here
        disp = memReadPC;
        if (disp > 127) disp -= 256;
      } else if (opcode == 0xdd && opcode == 0xfd) {
        // double prefix; put special NOP
        --pc; // rollback for correct length
        putMnemo("NOP");
        if (opcode == 0xdd) putArg("#DD"); else putArg("#FD");
        return;
      }
      gotDD = true;
    }
    // ED-prefixed instructions
    if (opcode == 0xed) {
      DD = "HL"; // а нас -- рать!
      // read opcode -- OCR(4)
      opcode = memReadPC;
      switch (opcode) {
        // LDI, LDIR, LDD, LDDR
        case 0xa0: putMnemo("LDI"); return;
        case 0xb0: putMnemo("LDIR"); return;
        case 0xa8: putMnemo("LDD"); return;
        case 0xb8: putMnemo("LDDR"); return;
        // CPI, CPIR, CPD, CPDR
        case 0xa1: putMnemo("CPI"); return;
        case 0xb1: putMnemo("CPIR"); return;
        case 0xa9: putMnemo("CPD"); return;
        case 0xb9: putMnemo("CPDR"); return;
        // OUTI, OTIR, OUTD, OTDR
        case 0xa3: putMnemo("OUTI"); return;
        case 0xb3: putMnemo("OTIR"); return;
        case 0xab: putMnemo("OUTD"); return;
        case 0xbb: putMnemo("OTDR"); return;
        // INI, INIR, IND, INDR
        case 0xa2: putMnemo("INI"); return;
        case 0xb2: putMnemo("INIR"); return;
        case 0xaa: putMnemo("IND"); return;
        case 0xba: putMnemo("INDR"); return;
        // not strings, but some good instructions anyway
        default:
          if ((opcode&0xc0) == 0x40) {
            // 0x40...0x7f
            final switch (opcode&0x07) {
              case 0: // IN r8,(C)
              case 1: // OUT (C),r8
                if (opcode&0x07) { putMnemo("OUT"); putArg("(C)"); } else putMnemo("IN");
                if (opcode&0x07) putR8!"0"((opcode>>3)&0x07); else putR8!"F"((opcode>>3)&0x07); // 0 on NMOS, 255 on CMOS
                if ((opcode&0x07) == 0) putArg("(C)");
                return;
              // SBC HL,rr/ADC HL,rr
              case 2:
                putMnemo(opcode&0x08 ? "ADC" : "SBC");
                putArg("HL");
                putR16SP!"HL"((opcode>>4)&0x03);
                return;
              // LD (nn),rr/LD rr,(nn)
              case 3:
                putMnemo("LD");
                if ((opcode&0x08) == 0) {
                  // LD (nn),rr
                  put("(");
                  putUInt(memReadPC, 4);
                  put(")");
                  endArg();
                }
                putR16SP!"HL"((opcode>>4)&0x03);
                if ((opcode&0x08) != 0) {
                  // LD rr,(nn)
                  put("(");
                  putUInt(memReadPC, 4);
                  put(")");
                  endArg();
                }
                return;
              // NEG
              case 4:
                putMnemo("NEG");
                return;
              // RETI/RETN
              case 5:
                // RETI: 0x4d, 0x5d, 0x6d, 0x7d
                // RETN: 0x45, 0x55, 0x65, 0x75
                if (opcode&0x08) putMnemo("RETI"); else putMnemo("RETN");
                return;
              // IM n
              case 6:
                putMnemo("IM");
                switch (opcode) {
                  case 0x56: case 0x76: putArg("1"); break;
                  case 0x5e: case 0x7e: putArg("2"); break;
                  default: putArg("0"); break;
                }
                return;
              // specials
              case 7:
                final switch (opcode) {
                  case 0x47: // LD I,A
                    putMnemo("LD");
                    putArg("I");
                    putArg("A");
                    return;
                  case 0x4f: // LD R,A
                    putMnemo("LD");
                    putArg("R");
                    putArg("A");
                    return;
                  case 0x57: // LD A,I
                    putMnemo("LD");
                    putArg("A");
                    putArg("I");
                    return;
                  case 0x5f: // LD A,R
                    putMnemo("LD");
                    putArg("A");
                    putArg("R");
                    return;
                  case 0x67: // RRD
                    putMnemo("RRD");
                    return;
                  case 0x6F: // RLD
                    putMnemo("RLD");
                    return;
                }
            }
          } else {
            // slt and other traps
            if (opcode == 0xFB) {
              putMnemo("TSLT");
            } else {
              putMnemo("TRAP");
              putUIntHex(opcode, 2);
              endArg();
            }
          }
          return;
      }
      // NOP
      putMnemo("NOP");
      putArg("#ED");
      putUIntHex(opcode, 2);
      endArg();
      return;
    } // 0xed done
    // CB-prefixed instructions
    if (opcode == 0xcb) {
      // shifts and bit operations
      // read opcode
      opcode = memReadPC;
      // mnemonics
      switch ((opcode>>3)&0x1f) {
        case 0: putMnemo("RLC"); break;
        case 1: putMnemo("RRC"); break;
        case 2: putMnemo("RL"); break;
        case 3: putMnemo("RR"); break;
        case 4: putMnemo("SLA"); break;
        case 5: putMnemo("SRA"); break;
        case 6: putMnemo("SLL"); break;
        case 7: putMnemo("SLR"); break;
        default:
          final switch ((opcode>>6)&0x03) {
            case 1: putMnemo("BIT"); break;
            case 2: putMnemo("RES"); break;
            case 3: putMnemo("SET"); break;
          }
          putUIntDec((opcode>>3)&0x07);
          endArg();
          break;
      }
      // R8X arg
      if (gotDD) {
        put("(");
        put(DD);
        putDisp(disp);
        put(")");
        endArg();
      } else {
        putR8!"(HL)"(opcode&0x07);
      }
      // possible extra operand
      if ((opcode&0xc0) != 0x40) {
        // BITs are not welcome here
        putR8(opcode&0x07);
      }
      return;
    } // 0xcb done
    // normal things
    final switch (opcode&0xc0) {
      // 0x00..0x3F
      case 0x00:
        final switch (opcode&0x07) {
          // misc,DJNZ,JR,JR cc
          case 0:
            if (opcode&0x30) {
              // branches
              if (opcode&0x20) {
                // JR cc
                putMnemo("JR");
                putCC((opcode>>3)&0x03);
              } else {
                // DJNZ/JR
                putMnemo(opcode&0x08 ? "JR" : "DJNZ");
              }
              disp = memReadPC;
              if (disp > 127) disp -= 256; // convert to int8_t
              ushort addr = cast(ushort)(pc+disp);
              putUInt(addr, 4);
              endArg();
            } else {
              // EX AF,AF' or NOP
              if (opcode != 0) {
                putMnemo("EX");
                putArg("AF");
                putArg("AF'");
              } else {
                putMnemo("NOP");
              }
            }
            return;
          // LD rr,nn/ADD HL,rr
          case 1:
            if (opcode&0x08) {
              // ADD HL,rr
              putMnemo("ADD");
              putArg(DD);
              putR16SP((opcode>>4)&0x03);
            } else {
              // LD rr,nn
              putMnemo("LD");
              putR16SP((opcode>>4)&0x03);
              putUInt(memReadPCW, 4);
              endArg();
            }
            return;
          // LD xxx,xxx
          case 2:
            putMnemo("LD");
            final switch ((opcode>>3)&0x07) {
              // LD (BC),A
              case 0: putArg("(BC)"); putArg("A"); break;
              // LD A,(BC)
              case 1: putArg("A"); putArg("(BC)"); break;
              // LD (DE),A
              case 2: putArg("(DE)"); putArg("A"); break;
              // LD A,(DE)
              case 3: putArg("A"); putArg("(DE)"); break;
              // LD (nn),HL
              case 4: put("("); putUInt(memReadPCW, 4); put(")"); endArg(); put(DD); endArg(); break;
              // LD HL,(nn)
              case 5: put(DD); endArg(); put("("); putUInt(memReadPCW, 4); put(")"); endArg(); break;
              // LD (nn),A
              case 6: put("("); putUInt(memReadPCW, 4); put(")"); endArg(); putArg("A"); break;
              // LD A,(nn)
              case 7: putArg("A"); put("("); putUInt(memReadPCW, 4); put(")"); endArg(); break;
            }
            return;
          // INC rr/DEC rr
          case 3:
            putMnemo(opcode&0x08 ? "DEC" : "INC");
            putR16SP((opcode>>4)&0x03);
            return;
          // INC/DEC r8; LD r8,n
          case 4: // INC r8
          case 5: // DEC r8
          case 6: // LD r8,n
            final switch (opcode&0x07) {
              case 4: putMnemo("INC"); break;
              case 5: putMnemo("DEC"); break;
              case 6: putMnemo("LD"); break;
            }
            final switch ((opcode>>3)&0x07) {
              case 0: putArg("B"); break;
              case 1: putArg("C"); break;
              case 2: putArg("D"); break;
              case 3: putArg("E"); break;
              case 4: if (gotDD) put(DD); putArg("H"); endArg(); break;
              case 5: if (gotDD) put(DD); putArg("L"); endArg(); break;
              case 6:
                put("(");
                put(DD);
                if (gotDD) putDisp(disp);
                put(")");
                endArg();
                break;
              case 7: putArg("A"); break;
            }
            // LD?
            if ((opcode&0x07) == 6) {
              putUInt(memReadPC, 2);
              endArg();
            }
            return;
          // swim-swim-hungry
          case 7:
            final switch ((opcode>>3)&0x07) {
              case 0: putMnemo("RLCA"); break;
              case 1: putMnemo("RRCA"); break;
              case 2: putMnemo("RLA"); break;
              case 3: putMnemo("RRA"); break;
              case 4: putMnemo("DAA"); break;
              case 5: putMnemo("CPL"); break;
              case 6: putMnemo("SCF"); break;
              case 7: putMnemo("CCF"); break;
            }
            return;
        }
        assert(0);
      // 0x40..0x7F: LD r8,r8
      case 0x40:
        if (opcode == 0x76) { putMnemo("HALT"); return; }
        putMnemo("LD");
        immutable ubyte rsrc = (opcode&0x07);
        immutable ubyte rdst = ((opcode>>3)&0x07);
        final switch (rsrc) {
          case 0: putArg("B"); break;
          case 1: putArg("C"); break;
          case 2: putArg("D"); break;
          case 3: putArg("E"); break;
          case 4: if (gotDD && rdst != 6) put(DD); put("H"); endArg(); break;
          case 5: if (gotDD && rdst != 6) put(DD); put("L"); endArg(); break;
          case 6:
            put("(");
            put(DD);
            if (gotDD) putDisp(disp);
            put(")");
            endArg();
            break;
          case 7: putArg("A"); break;
        }
        final switch (rdst) {
          case 0: putArg("B"); break;
          case 1: putArg("C"); break;
          case 2: putArg("D"); break;
          case 3: putArg("E"); break;
          case 4: if (gotDD && rsrc != 6) put(DD); put("H"); endArg(); break;
          case 5: if (gotDD && rsrc != 6) put(DD); put("L"); endArg(); break;
          case 6:
            put("(");
            put(DD);
            if (gotDD) putDisp(disp);
            put(")");
            endArg();
            break;
          case 7: putArg("A"); break;
        }
        return;
      // 0x80..0xBF: ALU A,r8
      case 0x80:
        final switch ((opcode>>3)&0x07) {
          case 0: putMnemo("ADD"); putArg("A"); break;
          case 1: putMnemo("ADC"); putArg("A"); break;
          case 2: putMnemo("SUB"); putArg("A"); break;
          case 3: putMnemo("SBC"); putArg("A"); break;
          case 4: putMnemo("AND"); break;
          case 5: putMnemo("XOR"); break;
          case 6: putMnemo("OR"); break;
          case 7: putMnemo("CP"); break;
        }
        //putArg("A");
        putR8(opcode&0x07);
        return;
      // 0xC0..0xFF
      case 0xC0:
        final switch (opcode&0x07) {
          // RET cc
          case 0:
            putMnemo("RET");
            putCC((opcode>>3)&0x07);
            break;
          // POP rr/special0
          case 1:
            if (opcode&0x08) {
              // special 0
              final switch ((opcode>>4)&0x03) {
                // RET
                case 0: putMnemo("RET"); break;
                // EXX
                case 1: putMnemo("EXX"); break;
                // JP (HL)
                case 2: putMnemo("JP"); put("("); put(DD); put(")"); endArg(); break;
                // LD SP,HL
                case 3: putMnemo("LD"); putArg("SP"); put(DD); endArg(); break;
              }
            } else {
              // POP rr
              putMnemo("POP");
              putR16AF((opcode>>4)&0x03);
            }
            break;
          // JP cc,nn
          case 2:
            putMnemo("JP");
            putCC((opcode>>3)&0x07);
            putUInt(memReadPCW, 4);
            endArg();
            break;
          // special1/special3
          case 3:
            final switch ((opcode>>3)&0x07) {
              // JP nn
              case 0: putMnemo("JP"); putUInt(memReadPCW, 4); endArg(); break;
              // OUT (n),A
              case 2: putMnemo("OUT"); put("("); putUInt(memReadPC, 2); put(")"); endArg(); putArg("A"); break;
              // IN A,(n)
              case 3: putMnemo("IN"); putArg("A"); put("("); putUInt(memReadPC, 2); put(")"); endArg(); break;
              // EX (SP),HL
              case 4: putMnemo("EX"); putArg("(SP)"); put(DD); endArg(); break;
              // EX DE,HL
              case 5: putMnemo("EX"); putArg("DE"); putArg("HL"); break;
              // DI
              case 6: putMnemo("DI"); break;
              // EI
              case 7: putMnemo("EI"); break;
            }
            break;
          // CALL cc,nn
          case 4:
            putMnemo("CALL");
            putCC((opcode>>3)&0x07);
            putUInt(memReadPCW, 4);
            endArg();
            break;
          // PUSH rr/special2
          case 5:
            if (opcode&0x08) {
              if (((opcode>>4)&0x03) == 0) {
                // CALL
                putMnemo("CALL");
                putUInt(memReadPCW, 4);
                endArg();
              }
            } else {
              // PUSH rr
              putMnemo("PUSH");
              putR16AF((opcode>>4)&0x03);
            }
            break;
          // ALU A,n
          case 6:
            final switch ((opcode>>3)&0x07) {
              case 0: putMnemo("ADD"); putArg("A"); break;
              case 1: putMnemo("ADC"); putArg("A"); break;
              case 2: putMnemo("SUB"); putArg("A"); break;
              case 3: putMnemo("SBC"); putArg("A"); break;
              case 4: putMnemo("AND"); break;
              case 5: putMnemo("XOR"); break;
              case 6: putMnemo("OR"); break;
              case 7: putMnemo("CP"); break;
            }
            //putArg("A");
            putUInt(memReadPC, 2);
            endArg();
            break;
          // RST nnn
          case 7:
            putMnemo("RST");
            putUInt(opcode&0x38, 2);
            break;
        }
        break;
    } // end switch
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// build tables through CTFE
private immutable ubyte[256] tblParity = (){
  ubyte[256] t;
  foreach (immutable f; 0..256) {
    int n, p;
    for (n = f, p = 0; n != 0; n >>= 1) p ^= n&0x01;
    t[f] = (p ? 0 : ZymCPU.Z80Flags.PV);
  }
  return t;
}();

private immutable ubyte[256] tblSZ53 = (){
  ubyte[256] t;
  foreach (immutable f; 0..256) t[f] = (f&ZymCPU.Z80Flags.S35);
  t[0] |= ZymCPU.Z80Flags.Z;
  return t;
}();

private immutable ubyte[256] tblSZP53 = (){
  ubyte[256] t;
  foreach (immutable f; 0..256) {
    int n, p;
    for (n = f, p = 0; n != 0; n >>= 1) p ^= n&0x01;
    t[f] = (f&ZymCPU.Z80Flags.S35)|(p ? 0 : ZymCPU.Z80Flags.PV);
  }
  t[0] |= ZymCPU.Z80Flags.Z;
  return t;
}();
