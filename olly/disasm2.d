/*
 * OllyDbg Disassembling Engine v2.01
 *
 * Copyright (c) 2007-2013 Oleh Yuschuk, ollydbg@t-online.de
 *
 * This code is part of the OllyDbg Disassembler v2.01
 *
 * Disassembling engine is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 3 of the License, or (at
 * your option) any later version.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * This is a fast disassembler that can be used to determine the length of
 * the binary 80x86 32-bit command and its attributes, to convert it to the
 * human-readable text form, highlight its operands, and create hexadecimal
 * dump of the binary command.
 *
 * It is a stripped down version of the disassembler used by OllyDbg 2.01.
 * It can't analyse and comment the contents of the operands, or predict the
 * results of the command execution. Analysis-dependent features are not
 * included, too. Most other features are kept.
 *
 * Disassembler supports integer, FPU, MMX, 3DNow, SSE1-SSE4.1 and AVX
 * instructions. 64-bit mode, AVX2, FMA and XOP are not (yet) supported.
 *
 * This code is reentrant (thread-safe, feature not available in the original
 * OllyDbg code).
 */
module iv.olly.disasm2;

enum TEXTLEN   = 256; // Max length of text string
enum SHORTNAME = 32;  // Max length of short or module name

enum NOPERAND   = 4;      // Maximal allowed number of operands
enum NREG       = 8;      // Number of registers (of any type)
enum NSEG       = 6;      // Number of valid segment registers
enum MAXCMDSIZE = 16;     // Maximal length of valid 80x86 command
enum NEGLIMIT   = -16384; // Limit to decode offsets as negative
enum DECLIMIT   = 16384;  // Limit to decode constants as decimal


// CMDMASK can be used to balance between the necessary memory size and the disassembly time.
enum CMDMASK = 0x3FFF; // Search mask for Disassembler, 2**n-1
enum NCHAIN = 44300; // Max allowed number of chain links

// Registers.
enum REG_UNDEF = -1; // Codes of general purpose registers
enum REG_EAX = 0;
enum REG_ECX = 1;
enum REG_EDX = 2;
enum REG_EBX = 3;
enum REG_ESP = 4;
enum REG_EBP = 5;
enum REG_ESI = 6;
enum REG_EDI = 7;

enum REG_AL = 0; // Symbolic indices of 8-bit registers
enum REG_CL = 1;
enum REG_DL = 2;
enum REG_BL = 3;
enum REG_AH = 4;
enum REG_CH = 5;
enum REG_DH = 6;
enum REG_BH = 7;

enum SEG_UNDEF = -1; // Codes of segment/selector registers
enum SEG_ES = 0;
enum SEG_CS = 1;
enum SEG_SS = 2;
enum SEG_DS = 3;
enum SEG_FS = 4;
enum SEG_GS = 5;

// Command highlighting.
enum DRAW_PLAIN =     '.'; //0x0000000C      // Plain commands
enum DRAW_JUMP =      '>'; //0x0000000D      // Unconditional jump commands
enum DRAW_CJMP =      '?'; //0x0000000E      // Conditional jump commands
enum DRAW_PUSHPOP =   '='; //0x0000000F      // PUSH/POP commands
enum DRAW_CALL =      '@'; //0x00000010      // CALL commands
enum DRAW_RET =       '<'; //0x00000011      // RET commands
enum DRAW_FPU =       '1'; //0x00000012      // FPU, MMX, 3DNow! and SSE commands
enum DRAW_SUSPECT =   '!'; //0x00000013      // Bad, system and privileged commands
// Operand highlighting.
enum DRAW_IREG =      'R'; //0x00000018      // General purpose registers
enum DRAW_FREG =      'F'; //0x00000019      // FPU, MMX and SSE registers
enum DRAW_SYSREG =    'S'; //0x0000001A      // Segment and system registers
enum DRAW_STKMEM =    'K'; //0x0000001B      // Memory accessed over ESP or EBP
enum DRAW_MEM =       'M'; //0x0000001C      // Any other memory
enum DRAW_CONST =     'C'; //0x0000001E      // Constant

enum D_NONE =         0x00000000;      // No special features
// General type of command, only one is allowed.
enum D_CMDTYPE =      0x0000001F;      // Mask to extract type of command
enum   D_CMD =        0x00000000;      // Ordinary (none of listed below)
enum   D_MOV =        0x00000001;      // Move to or from integer register
enum   D_MOVC =       0x00000002;      // Conditional move to integer register
enum   D_SETC =       0x00000003;      // Conditional set integer register
enum   D_TEST =       0x00000004;      // Used to test data (CMP, TEST, AND...)
enum   D_STRING =     0x00000005;      // String command with REPxxx prefix
enum   D_JMP =        0x00000006;      // Unconditional near jump
enum   D_JMPFAR =     0x00000007;      // Unconditional far jump
enum   D_JMC =        0x00000008;      // Conditional jump on flags
enum   D_JMCX =       0x00000009;      // Conditional jump on (E)CX (and flags)
enum   D_PUSH =       0x0000000A;      // PUSH exactly 1 (d)word of data
enum   D_POP =        0x0000000B;      // POP exactly 1 (d)word of data
enum   D_CALL =       0x0000000C;      // Plain near call
enum   D_CALLFAR =    0x0000000D;      // Far call
enum   D_INT =        0x0000000E;      // Interrupt
enum   D_RET =        0x0000000F;      // Plain near return from call
enum   D_RETFAR =     0x00000010;      // Far return or IRET
enum   D_FPU =        0x00000011;      // FPU command
enum   D_MMX =        0x00000012;      // MMX instruction, incl. SSE extensions
enum   D_3DNOW =      0x00000013;      // 3DNow! instruction
enum   D_SSE =        0x00000014;      // SSE instruction
enum   D_IO =         0x00000015;      // Accesses I/O ports
enum   D_SYS =        0x00000016;      // Legal but useful in system code only
enum   D_PRIVILEGED = 0x00000017;      // Privileged (non-Ring3) command
enum   D_AVX =        0x00000018;      // AVX instruction
enum   D_XOP =        0x00000019;      // AMD instruction with XOP prefix
enum   D_DATA =       0x0000001C;      // Data recognized by Analyser
enum   D_PSEUDO =     0x0000001D;      // Pseudocommand, for search models only
enum   D_PREFIX =     0x0000001E;      // Standalone prefix
enum   D_BAD =        0x0000001F;      // Bad or unrecognized command
// Additional parts of the command.
enum D_SIZE01 =       0x00000020;      // Bit 0x01 in last cmd is data size
enum D_POSTBYTE =     0x00000040;      // Command continues in postbyte
// For string commands, either long or short form can be selected.
enum D_LONGFORM =     0x00000080;      // Long form of string command
// Decoding of some commands depends on data or address size.
enum D_SIZEMASK =     0x00000F00;      // Mask for data/address size dependence
enum   D_DATA16 =     0x00000100;      // Requires 16-bit data size
enum   D_DATA32 =     0x00000200;      // Requires 32-bit data size
enum   D_ADDR16 =     0x00000400;      // Requires 16-bit address size
enum   D_ADDR32 =     0x00000800;      // Requires 32-bit address size
// Prefixes that command may, must or must not possess.
enum D_MUSTMASK =     0x0000F000;      // Mask for fixed set of prefixes
enum   D_NOMUST =     0x00000000;      // No obligatory prefixes (default)
enum   D_MUST66 =     0x00001000;      // (SSE,AVX) Requires 66, no F2 or F3
enum   D_MUSTF2 =     0x00002000;      // (SSE,AVX) Requires F2, no 66 or F3
enum   D_MUSTF3 =     0x00003000;      // (SSE,AVX) Requires F3, no 66 or F2
enum   D_MUSTNONE =   0x00004000;      // (MMX,SSE,AVX) Requires no 66, F2, F3
enum   D_NEEDF2 =     0x00005000;      // (SSE,AVX) Requires F2, no F3
enum   D_NEEDF3 =     0x00006000;      // (SSE,AVX) Requires F3, no F2
enum   D_NOREP =      0x00007000;      // Must not include F2 or F3
enum   D_MUSTREP =    0x00008000;      // Must include F3 (REP)
enum   D_MUSTREPE =   0x00009000;      // Must include F3 (REPE)
enum   D_MUSTREPNE =  0x0000A000;      // Must include F2 (REPNE)
enum D_LOCKABLE =     0x00010000;      // Allows for F0 (LOCK, memory only)
enum D_BHINT =        0x00020000;      // Allows for branch hints (2E, 3E)
// Decoding of some commands with ModRM-SIB depends whether register or memory.
enum D_MEMORY =       0x00040000;      // Mod field must indicate memory
enum D_REGISTER =     0x00080000;      // Mod field must indicate register
// Side effects caused by command.
enum D_FLAGMASK =     0x00700000;      // Mask to extract modified flags
enum   D_NOFLAGS =    0x00000000;      // Flags S,Z,P,O,C remain unchanged
enum   D_ALLFLAGS =   0x00100000;      // Modifies flags S,Z,P,O,C
enum   D_FLAGZ =      0x00200000;      // Modifies flag Z only
enum   D_FLAGC =      0x00300000;      // Modifies flag C only
enum   D_FLAGSCO =    0x00400000;      // Modifies flag C and O only
enum   D_FLAGD =      0x00500000;      // Modifies flag D only
enum   D_FLAGSZPC =   0x00600000;      // Modifies flags Z, P and C only (FPU)
enum   D_NOCFLAG =    0x00700000;      // S,Z,P,O modified, C unaffected
enum D_FPUMASK =      0x01800000;      // Mask for effects on FPU stack
enum   D_FPUSAME =    0x00000000;      // Doesn't rotate FPU stack (default)
enum   D_FPUPOP =     0x00800000;      // Pops FPU stack
enum   D_FPUPOP2 =    0x01000000;      // Pops FPU stack twice
enum   D_FPUPUSH =    0x01800000;      // Pushes FPU stack
enum D_CHGESP =       0x02000000;      // Command indirectly modifies ESP
// Command features.
enum D_HLADIR =       0x04000000;      // Nonstandard order of operands in HLA
enum D_WILDCARD =     0x08000000;      // Mnemonics contains W/D wildcard ('*')
enum D_COND =         0x10000000;      // Conditional (action depends on flags)
enum D_USESCARRY =    0x20000000;      // Uses Carry flag
enum D_USEMASK =      0xC0000000;      // Mask to detect unusual commands
enum   D_RARE =       0x40000000;      // Rare or obsolete in Win32 apps
enum   D_SUSPICIOUS = 0x80000000;      // Suspicious command
enum   D_UNDOC =      0xC0000000;      // Undocumented command

// Extension of D_xxx.
enum DX_ZEROMASK =    0x00000003;      // How to decode FLAGS.Z flag
enum   DX_JE =        0x00000001;      // JE, JNE instead of JZ, JNZ
enum   DX_JZ =        0x00000002;      // JZ, JNZ instead of JE, JNE
enum DX_CARRYMASK =   0x0000000C;      // How to decode FLAGS.C flag
enum   DX_JB =        0x00000004;      // JAE, JB instead of JC, JNC
enum   DX_JC =        0x00000008;      // JC, JNC instead of JAE, JB
enum DX_RETN =        0x00000010;      // The mnemonics is RETN
enum DX_VEX =         0x00000100;      // Requires VEX prefix
enum DX_VLMASK =      0x00000600;      // Mask to extract VEX operand length
enum   DX_LSHORT =    0x00000000;      // 128-bit only
enum   DX_LBOTH =     0x00000200;      // Both 128- and 256-bit versions
enum   DX_LLONG =     0x00000400;      // 256-bit only
enum   DX_IGNOREL =   0x00000600;      // Ignore VEX.L
enum DX_NOVREG =      0x00000800;      // VEX.vvvv must be set to all 1's
enum DX_VWMASK =      0x00003000;      // Mask to extract VEX.W
enum   DX_W0 =        0x00001000;      // VEX.W must be 0
enum   DX_W1 =        0x00002000;      // VEX.W must be 1
enum DX_LEADMASK =    0x00070000;      // Mask to extract leading opcode bytes
enum   DX_LEAD0F =    0x00000000;      // Implied 0F leading byte (default)
enum   DX_LEAD38 =    0x00010000;      // Implied 0F 38 leading opcode bytes
enum   DX_LEAD3A =    0x00020000;      // Implied 0F 3A leading opcode bytes
enum DX_WONKYTRAP =   0x00800000;      // Don't single-step this command
enum DX_TYPEMASK =    0xFF000000;      // Precised command type mask
enum   DX_ADD =       0x01000000;      // The command is integer ADD
enum   DX_SUB =       0x02000000;      // The command is integer SUB
enum   DX_LEA =       0x03000000;      // The command is LEA
enum   DX_NOP =       0x04000000;      // The command is NOP

//enum DX_LVEX = (DX_VEX|DX_LBOTH);
//enum DX_GVEX = (DX_VEX|DX_LLONG);

// Type of operand, only one is allowed. Size of SSE operands is given for the
// case of 128-bit operations and usually doubles for 256-bit AVX commands. If
// B_NOVEXSIZE is set, memory may double but XMM registers are not promoted to
// YMM.
enum B_ARGMASK =      0x000000FF;      // Mask to extract type of argument
enum   B_NONE =       0x00000000;      // Operand absent
enum   B_AL =         0x00000001;      // Register AL
enum   B_AH =         0x00000002;      // Register AH
enum   B_AX =         0x00000003;      // Register AX
enum   B_CL =         0x00000004;      // Register CL
enum   B_CX =         0x00000005;      // Register CX
enum   B_DX =         0x00000006;      // Register DX
enum   B_DXPORT =     0x00000007;      // Register DX as I/O port address
enum   B_EAX =        0x00000008;      // Register EAX
enum   B_EBX =        0x00000009;      // Register EBX
enum   B_ECX =        0x0000000A;      // Register ECX
enum   B_EDX =        0x0000000B;      // Register EDX
enum   B_ACC =        0x0000000C;      // Accumulator (AL/AX/EAX)
enum   B_STRCNT =     0x0000000D;      // Register CX or ECX as REPxx counter
enum   B_DXEDX =      0x0000000E;      // Register DX or EDX in DIV/MUL
enum   B_BPEBP =      0x0000000F;      // Register BP or EBP in ENTER/LEAVE
enum   B_REG =        0x00000010;      // 8/16/32-bit register in Reg
enum   B_REG16 =      0x00000011;      // 16-bit register in Reg
enum   B_REG32 =      0x00000012;      // 32-bit register in Reg
enum   B_REGCMD =     0x00000013;      // 16/32-bit register in last cmd byte
enum   B_REGCMD8 =    0x00000014;      // 8-bit register in last cmd byte
enum   B_ANYREG =     0x00000015;      // Reg field is unused, any allowed
enum   B_INT =        0x00000016;      // 8/16/32-bit register/memory in ModRM
enum   B_INT8 =       0x00000017;      // 8-bit register/memory in ModRM
enum   B_INT16 =      0x00000018;      // 16-bit register/memory in ModRM
enum   B_INT32 =      0x00000019;      // 32-bit register/memory in ModRM
enum   B_INT1632 =    0x0000001A;      // 16/32-bit register/memory in ModRM
enum   B_INT64 =      0x0000001B;      // 64-bit integer in ModRM, memory only
enum   B_INT128 =     0x0000001C;      // 128-bit integer in ModRM, memory only
enum   B_IMMINT =     0x0000001D;      // 8/16/32-bit int at immediate addr
enum   B_INTPAIR =    0x0000001E;      // Two signed 16/32 in ModRM, memory only
enum   B_SEGOFFS =    0x0000001F;      // 16:16/16:32 absolute address in memory
enum   B_STRDEST =    0x00000020;      // 8/16/32-bit string dest, [ES:(E)DI]
enum   B_STRDEST8 =   0x00000021;      // 8-bit string destination, [ES:(E)DI]
enum   B_STRSRC =     0x00000022;      // 8/16/32-bit string source, [(E)SI]
enum   B_STRSRC8 =    0x00000023;      // 8-bit string source, [(E)SI]
enum   B_XLATMEM =    0x00000024;      // 8-bit memory in XLAT, [(E)BX+AL]
enum   B_EAXMEM =     0x00000025;      // Reference to memory addressed by [EAX]
enum   B_LONGDATA =   0x00000026;      // Long data in ModRM, mem only
enum   B_ANYMEM =     0x00000027;      // Reference to memory, data unimportant
enum   B_STKTOP =     0x00000028;      // 16/32-bit int top of stack
enum   B_STKTOPFAR =  0x00000029;      // Top of stack (16:16/16:32 far addr)
enum   B_STKTOPEFL =  0x0000002A;      // 16/32-bit flags on top of stack
enum   B_STKTOPA =    0x0000002B;      // 16/32-bit top of stack all registers
enum   B_PUSH =       0x0000002C;      // 16/32-bit int push to stack
enum   B_PUSHRET =    0x0000002D;      // 16/32-bit push of return address
enum   B_PUSHRETF =   0x0000002E;      // 16:16/16:32-bit push of far retaddr
enum   B_PUSHA =      0x0000002F;      // 16/32-bit push all registers
enum   B_EBPMEM =     0x00000030;      // 16/32-bit int at [EBP]
enum   B_SEG =        0x00000031;      // Segment register in Reg
enum   B_SEGNOCS =    0x00000032;      // Segment register in Reg, but not CS
enum   B_SEGCS =      0x00000033;      // Segment register CS
enum   B_SEGDS =      0x00000034;      // Segment register DS
enum   B_SEGES =      0x00000035;      // Segment register ES
enum   B_SEGFS =      0x00000036;      // Segment register FS
enum   B_SEGGS =      0x00000037;      // Segment register GS
enum   B_SEGSS =      0x00000038;      // Segment register SS
enum   B_ST =         0x00000039;      // 80-bit FPU register in last cmd byte
enum   B_ST0 =        0x0000003A;      // 80-bit FPU register ST0
enum   B_ST1 =        0x0000003B;      // 80-bit FPU register ST1
enum   B_FLOAT32 =    0x0000003C;      // 32-bit float in ModRM, memory only
enum   B_FLOAT64 =    0x0000003D;      // 64-bit float in ModRM, memory only
enum   B_FLOAT80 =    0x0000003E;      // 80-bit float in ModRM, memory only
enum   B_BCD =        0x0000003F;      // 80-bit BCD in ModRM, memory only
enum   B_MREG8x8 =    0x00000040;      // MMX register as 8 8-bit integers
enum   B_MMX8x8 =     0x00000041;      // MMX reg/memory as 8 8-bit integers
enum   B_MMX8x8DI =   0x00000042;      // MMX 8 8-bit integers at [DS:(E)DI]
enum   B_MREG16x4 =   0x00000043;      // MMX register as 4 16-bit integers
enum   B_MMX16x4 =    0x00000044;      // MMX reg/memory as 4 16-bit integers
enum   B_MREG32x2 =   0x00000045;      // MMX register as 2 32-bit integers
enum   B_MMX32x2 =    0x00000046;      // MMX reg/memory as 2 32-bit integers
enum   B_MREG64 =     0x00000047;      // MMX register as 1 64-bit integer
enum   B_MMX64 =      0x00000048;      // MMX reg/memory as 1 64-bit integer
enum   B_3DREG =      0x00000049;      // 3DNow! register as 2 32-bit floats
enum   B_3DNOW =      0x0000004A;      // 3DNow! reg/memory as 2 32-bit floats
enum   B_XMM0I32x4 =  0x0000004B;      // XMM0 as 4 32-bit integers
enum   B_XMM0I64x2 =  0x0000004C;      // XMM0 as 2 64-bit integers
enum   B_XMM0I8x16 =  0x0000004D;      // XMM0 as 16 8-bit integers
enum   B_SREGF32x4 =  0x0000004E;      // SSE register as 4 32-bit floats
enum   B_SREGF32L =   0x0000004F;      // Low 32-bit float in SSE register
enum   B_SREGF32x2L = 0x00000050;      // Low 2 32-bit floats in SSE register
enum   B_SSEF32x4 =   0x00000051;      // SSE reg/memory as 4 32-bit floats
enum   B_SSEF32L =    0x00000052;      // Low 32-bit float in SSE reg/memory
enum   B_SSEF32x2L =  0x00000053;      // Low 2 32-bit floats in SSE reg/memory
enum   B_SREGF64x2 =  0x00000054;      // SSE register as 2 64-bit floats
enum   B_SREGF64L =   0x00000055;      // Low 64-bit float in SSE register
enum   B_SSEF64x2 =   0x00000056;      // SSE reg/memory as 2 64-bit floats
enum   B_SSEF64L =    0x00000057;      // Low 64-bit float in SSE reg/memory
enum   B_SREGI8x16 =  0x00000058;      // SSE register as 16 8-bit sigints
enum   B_SSEI8x16 =   0x00000059;      // SSE reg/memory as 16 8-bit sigints
enum   B_SSEI8x16DI = 0x0000005A;      // SSE 16 8-bit sigints at [DS:(E)DI]
enum   B_SSEI8x8L =   0x0000005B;      // Low 8 8-bit ints in SSE reg/memory
enum   B_SSEI8x4L =   0x0000005C;      // Low 4 8-bit ints in SSE reg/memory
enum   B_SSEI8x2L =   0x0000005D;      // Low 2 8-bit ints in SSE reg/memory
enum   B_SREGI16x8 =  0x0000005E;      // SSE register as 8 16-bit sigints
enum   B_SSEI16x8 =   0x0000005F;      // SSE reg/memory as 8 16-bit sigints
enum   B_SSEI16x4L =  0x00000060;      // Low 4 16-bit ints in SSE reg/memory
enum   B_SSEI16x2L =  0x00000061;      // Low 2 16-bit ints in SSE reg/memory
enum   B_SREGI32x4 =  0x00000062;      // SSE register as 4 32-bit sigints
enum   B_SREGI32L =   0x00000063;      // Low 32-bit sigint in SSE register
enum   B_SREGI32x2L = 0x00000064;      // Low 2 32-bit sigints in SSE register
enum   B_SSEI32x4 =   0x00000065;      // SSE reg/memory as 4 32-bit sigints
enum   B_SSEI32x2L =  0x00000066;      // Low 2 32-bit sigints in SSE reg/memory
enum   B_SREGI64x2 =  0x00000067;      // SSE register as 2 64-bit sigints
enum   B_SSEI64x2 =   0x00000068;      // SSE reg/memory as 2 64-bit sigints
enum   B_SREGI64L =   0x00000069;      // Low 64-bit sigint in SSE register
enum   B_EFL =        0x0000006A;      // Flags register EFL
enum   B_FLAGS8 =     0x0000006B;      // Flags (low byte)
enum   B_OFFSET =     0x0000006C;      // 16/32 const offset from next command
enum   B_BYTEOFFS =   0x0000006D;      // 8-bit sxt const offset from next cmd
enum   B_FARCONST =   0x0000006E;      // 16:16/16:32 absolute address constant
enum   B_DESCR =      0x0000006F;      // 16:32 descriptor in ModRM
enum   B_1 =          0x00000070;      // Immediate constant 1
enum   B_CONST8 =     0x00000071;      // Immediate 8-bit constant
enum   B_CONST8_2 =   0x00000072;      // Immediate 8-bit const, second in cmd
enum   B_CONST16 =    0x00000073;      // Immediate 16-bit constant
enum   B_CONST =      0x00000074;      // Immediate 8/16/32-bit constant
enum   B_CONSTL =     0x00000075;      // Immediate 16/32-bit constant
enum   B_SXTCONST =   0x00000076;      // Immediate 8-bit sign-extended to size
enum   B_CR =         0x00000077;      // Control register in Reg
enum   B_CR0 =        0x00000078;      // Control register CR0
enum   B_DR =         0x00000079;      // Debug register in Reg
enum   B_FST =        0x0000007A;      // FPU status register
enum   B_FCW =        0x0000007B;      // FPU control register
enum   B_MXCSR =      0x0000007C;      // SSE media control and status register
enum   B_SVEXF32x4 =  0x0000007D;      // SSE reg in VEX as 4 32-bit floats
enum   B_SVEXF32L =   0x0000007E;      // Low 32-bit float in SSE in VEX
enum   B_SVEXF64x2 =  0x0000007F;      // SSE reg in VEX as 2 64-bit floats
enum   B_SVEXF64L =   0x00000080;      // Low 64-bit float in SSE in VEX
enum   B_SVEXI8x16 =  0x00000081;      // SSE reg in VEX as 16 8-bit sigints
enum   B_SVEXI16x8 =  0x00000082;      // SSE reg in VEX as 8 16-bit sigints
enum   B_SVEXI32x4 =  0x00000083;      // SSE reg in VEX as 4 32-bit sigints
enum   B_SVEXI64x2 =  0x00000084;      // SSE reg in VEX as 2 64-bit sigints
enum   B_SIMMI8x16 =  0x00000085;      // SSE reg in immediate 8-bit constant
// Type modifiers, used for interpretation of contents, only one is allowed.
enum B_MODMASK =      0x000F0000;      // Mask to extract type modifier
enum   B_NONSPEC =    0x00000000;      // Non-specific operand
enum   B_UNSIGNED =   0x00010000;      // Decode as unsigned decimal
enum   B_SIGNED =     0x00020000;      // Decode as signed decimal
enum   B_BINARY =     0x00030000;      // Decode as binary (full hex) data
enum   B_BITCNT =     0x00040000;      // Bit count
enum   B_SHIFTCNT =   0x00050000;      // Shift count
enum   B_COUNT =      0x00060000;      // General-purpose count
enum   B_NOADDR =     0x00070000;      // Not an address
enum   B_JMPCALL =    0x00080000;      // Near jump/call/return destination
enum   B_JMPCALLFAR = 0x00090000;      // Far jump/call/return destination
enum   B_STACKINC =   0x000A0000;      // Unsigned stack increment/decrement
enum   B_PORT =       0x000B0000;      // I/O port
enum   B_ADDR =       0x000F0000;      // Used internally
// Validity markers.
enum B_MEMORY =       0x00100000;      // Memory only, reg version different
enum B_REGISTER =     0x00200000;      // Register only, mem version different
enum B_MEMONLY =      0x00400000;      // Warn if operand in register
enum B_REGONLY =      0x00800000;      // Warn if operand in memory
enum B_32BITONLY =    0x01000000;      // Warn if 16-bit operand
enum B_NOESP =        0x02000000;      // ESP is not allowed
// Miscellaneous options.
enum B_NOVEXSIZE =    0x04000000;      // Always 128-bit SSE in 256-bit AVX
enum B_SHOWSIZE =     0x08000000;      // Always show argument size in disasm
enum B_CHG =          0x10000000;      // Changed, old contents is not used
enum B_UPD =          0x20000000;      // Modified using old contents
enum B_PSEUDO =       0x40000000;      // Pseoudooperand, not in assembler cmd
enum B_NOSEG =        0x80000000;      // Don't add offset of selector

// Location of operand, only one bit is allowed.
enum OP_SOMEREG =     0x000000FF;      // Mask for any kind of register
enum   OP_REGISTER =  0x00000001;      // Operand is a general-purpose register
enum   OP_SEGREG =    0x00000002;      // Operand is a segment register
enum   OP_FPUREG =    0x00000004;      // Operand is a FPU register
enum   OP_MMXREG =    0x00000008;      // Operand is a MMX register
enum   OP_3DNOWREG =  0x00000010;      // Operand is a 3DNow! register
enum   OP_SSEREG =    0x00000020;      // Operand is a SSE register
enum   OP_CREG =      0x00000040;      // Operand is a control register
enum   OP_DREG =      0x00000080;      // Operand is a debug register
enum OP_MEMORY =      0x00000100;      // Operand is in memory
enum OP_CONST =       0x00000200;      // Operand is an immediate constant
// Additional operand properties.
enum OP_PORT =        0x00000400;      // Used to access I/O port
enum OP_OTHERREG =    0x00000800;      // Special register like EFL or MXCSR
enum OP_INVALID =     0x00001000;      // Invalid operand, like reg in mem-only
enum OP_PSEUDO =      0x00002000;      // Pseudooperand (not in mnenonics)
enum OP_MOD =         0x00004000;      // Command may change/update operand
enum OP_MODREG =      0x00008000;      // Memory, but modifies reg (POP,MOVSD)
enum OP_IMPORT =      0x00020000;      // Value imported from different module
enum OP_SELECTOR =    0x00040000;      // Includes immediate selector
// Additional properties of memory address.
enum OP_INDEXED =     0x00080000;      // Memory address contains registers
enum OP_OPCONST =     0x00100000;      // Memory address contains constant
enum OP_ADDR16 =      0x00200000;      // 16-bit memory address
enum OP_ADDR32 =      0x00400000;      // Explicit 32-bit memory address

enum DAMODE_MASM =    0;               // MASM assembling/disassembling style
enum DAMODE_IDEAL =   1;               // IDEAL assembling/disassembling style
enum DAMODE_HLA =     2;               // HLA assembling/disassembling style
enum DAMODE_ATT =     3;               // AT&T disassembling style

enum NUM_STYLE =     0x0003;           // Mask to extract hex style
enum   NUM_STD =     0x0000;           // 123, 12345678h, 0ABCD1234h
enum   NUM_X =       0x0001;           // 123, 0x12345678, 0xABCD1234
enum   NUM_OLLY =    0x0002;           // 123., 12345678, 0ABCD1234
enum NUM_LONG =      0x0010;           // 00001234h instead of 1234h
enum NUM_DECIMAL =   0x0020;           // 123 instead of 7Bh if under DECLIMIT

// Disassembling options.
enum DA_TEXT =        0x00000001;      // Decode command to text and comment
enum   DA_HILITE =    0x00000002;      // Use syntax highlighting
enum   DA_JZ =        0x00000004;      // JZ, JNZ instead of JE, JNE
enum   DA_JC =        0x00000008;      // JC, JNC instead of JAE, JB
enum DA_DUMP =        0x00000020;      // Dump command to hexadecimal text
enum DA_PSEUDO =      0x00000400;      // List pseudooperands

// Disassembling errors.
enum DAE_NOERR =      0x00000000;      // No errors
enum DAE_BADCMD =     0x00000001;      // Unrecognized command
enum DAE_CROSS =      0x00000002;      // Command crosses end of memory block
enum DAE_MEMORY =     0x00000004;      // Register where only memory allowed
enum DAE_REGISTER =   0x00000008;      // Memory where only register allowed
enum DAE_LOCK =       0x00000010;      // LOCK prefix is not allowed
enum DAE_BADSEG =     0x00000020;      // Invalid segment register
enum DAE_SAMEPREF =   0x00000040;      // Two prefixes from the same group
enum DAE_MANYPREF =   0x00000080;      // More than 4 prefixes
enum DAE_BADCR =      0x00000100;      // Invalid CR register
enum DAE_INTERN =     0x00000200;      // Internal error

// Disassembling warnings.
enum DAW_NOWARN =     0x00000000;      // No warnings
enum DAW_DATASIZE =   0x00000001;      // Superfluous data size prefix
enum DAW_ADDRSIZE =   0x00000002;      // Superfluous address size prefix
enum DAW_SEGPREFIX =  0x00000004;      // Superfluous segment override prefix
enum DAW_REPPREFIX =  0x00000008;      // Superfluous REPxx prefix
enum DAW_DEFSEG =     0x00000010;      // Segment prefix coincides with default
enum DAW_JMP16 =      0x00000020;      // 16-bit jump, call or return
enum DAW_FARADDR =    0x00000040;      // Far jump or call
enum DAW_SEGMOD =     0x00000080;      // Modifies segment register
enum DAW_PRIV =       0x00000100;      // Privileged command
enum DAW_IO =         0x00000200;      // I/O command
enum DAW_SHIFT =      0x00000400;      // Shift out of range 1..31
enum DAW_LOCK =       0x00000800;      // Command with valid LOCK prefix
enum DAW_STACK =      0x00001000;      // Unaligned stack operation
enum DAW_NOESP =      0x00002000;      // Suspicious use of stack pointer
enum DAW_RARE =       0x00004000;      // Rare, seldom used command
enum DAW_NONCLASS =   0x00008000;      // Non-standard or non-documented code
enum DAW_INTERRUPT =  0x00010000;      // Interrupt command

// List of prefixes.
enum PF_SEGMASK =     0x0000003F;      // Mask for segment override prefixes
enum   PF_ES =        0x00000001;      // 0x26, ES segment override
enum   PF_CS =        0x00000002;      // 0x2E, CS segment override
enum   PF_SS =        0x00000004;      // 0x36, SS segment override
enum   PF_DS =        0x00000008;      // 0x3E, DS segment override
enum   PF_FS =        0x00000010;      // 0x64, FS segment override
enum   PF_GS =        0x00000020;      // 0x65, GS segment override
enum PF_DSIZE =       0x00000040;      // 0x66, data size override
enum PF_ASIZE =       0x00000080;      // 0x67, address size override
enum PF_LOCK =        0x00000100;      // 0xF0, bus lock
enum PF_REPMASK =     0x00000600;      // Mask for repeat prefixes
enum   PF_REPNE =     0x00000200;      // 0xF2, REPNE prefix
enum   PF_REP =       0x00000400;      // 0xF3, REP/REPE prefix
enum PF_BYTE =        0x00000800;      // Size bit in command, used in cmdexec
enum PF_MUSTMASK =    D_MUSTMASK;      // Necessary prefixes, used in t_asmmod
enum PF_VEX2 =        0x00010000;      // 2-byte VEX prefix
enum PF_VEX3 =        0x00020000;      // 3-byte VEX prefix
// Useful shortcuts.
enum PF_66 =          PF_DSIZE;        // Alternative names for SSE prefixes
enum PF_F2 =          PF_REPNE;
enum PF_F3 =          PF_REP;
enum PF_HINT =        (PF_CS|PF_DS);   // Alternative names for branch hints
enum   PF_NOTTAKEN =  PF_CS;
enum   PF_TAKEN =     PF_DS;
enum PF_VEX =         (PF_VEX2|PF_VEX3);

// Disassembler configuration
struct DAConfig {
  uint disasmmode = DAMODE_IDEAL;     // Main style, one of DAMODE_xxx
  uint memmode = NUM_X|NUM_DECIMAL;   // Constant part of address, NUM_xxx
  uint jmpmode = NUM_X|NUM_LONG;      // Jump/call destination, NUM_xxx
  uint binconstmode = NUM_X|NUM_LONG; // Binary constants, NUM_xxx
  uint constmode = NUM_X|NUM_DECIMAL; // Numeric constants, NUM_xxx
  bool lowercase = true;              // Force lowercase display
  bool tabarguments = false;          // Tab between mnemonic and arguments
  bool extraspace = false;            // Extra space between arguments
  bool useretform = false;            // Use RET instead of RETN
  bool shortstringcmds = true;        // Use short form of string commands
  bool putdefseg = false;             // Display default segments in listing
  bool showmemsize = false;           // Always show memory size
  bool shownear = false;              // Show NEAR modifiers
  bool ssesizemode = false;           // How to decode size of SSE operands
  bool jumphintmode = false;          // How to decode jump hints (true: prefix with '+' or '-')
  ubyte sizesens = 0;                 // How to decode size-sensitive mnemonics (0,1,2)
  bool simplifiedst = false;          // How to decode top of FPU stack
  bool hiliteoperands = true;         // Highlight operands
}

// Description of disassembled operand
struct AsmOperand {
  // Description of operand.
  uint features;      // Operand features, set of OP_xxx
  uint arg;           // Operand type, set of B_xxx
  uint opsize;        // Total size of data, bytes
  int granularity;    // Size of element (opsize exc. MMX/SSE)
  int reg;            // REG_xxx (also ESP in POP) or REG_UNDEF
  uint uses;          // List of used regs (not in address!)
  uint modifies;      // List of modified regs (not in addr!)
  // Description of memory address.
  int seg;            // Selector (SEG_xxx)
  ubyte[NREG] scale;  // Scales of registers in memory address
  uint aregs;         // List of registers used in address
  uint opconst;       // Constant or const part of address
  uint selector;      // Immediate selector in far jump/call
  // Textual decoding.
  char[TEXTLEN] text; // Operand, decoded to text

  @property inout(char)[] str () inout nothrow @trusted @nogc { foreach (immutable idx; 0..text.length) if (text.ptr[idx] == 0) return text[0..idx]; return text[]; }
}

// Note that used registers are those which contents is necessary to create
// result. Modified registers are those which value is changed. For example,
// command MOV EAX,[EBX+ECX] uses EBX and ECX and modifies EAX. Command
// ADD ESI,EDI uses ESI and EDI and modifies ESI.
// Disassembled command
struct DisasmData {
  uint ip;                 // Address of first command byte
  uint size;               // Full length of command, bytes
  uint cmdtype;            // Type of command, D_xxx
  uint exttype;            // More features, set of DX_xxx
  uint prefixes;           // List of prefixes, set of PF_xxx
  uint nprefix;            // Number of prefixes, including SSE2
  int memfixup;            // Offset of first 4-byte fixup or -1
  int immfixup;            // Offset of second 4-byte fixup or -1
  uint errors;             // Set of DAE_xxx
  uint warnings;           // Set of DAW_xxx
  uint uses;               // List of used registers
  uint modifies;           // List of modified registers
  uint memconst;           // Constant in memory address or 0
  uint stackinc;           // Data size in ENTER/RETN/RETF
  AsmOperand[NOPERAND] op; // Operands
  char[TEXTLEN] dump;      // Hex dump of the command
  char[TEXTLEN] result;    // Fully decoded command as text
  char[TEXTLEN] mask;      // Mask to highlight result
  int masksize;            // Length of mask corresponding to result

  @property inout(char)[] dumpstr () inout nothrow @trusted @nogc { foreach (immutable idx; 0..dump.length) if (dump.ptr[idx] == 0) return dump[0..idx]; return dump[]; }
  @property inout(char)[] resstr () inout nothrow @trusted @nogc { foreach (immutable idx; 0..result.length) if (result.ptr[idx] == 0) return result[0..idx]; return result[]; }
  @property inout(char)[] maskstr () inout nothrow @trusted @nogc { return (masksize >= 0 && masksize < mask.length ? mask[0..masksize] : null); }
}


// ////////////////////////////////////////////////////////////////////////// //
private:
// Description of 80x86 command
struct AsmInstrDsc {
  string name;        // Symbolic name for this command
  uint cmdtype;       // Command's features, set of D_xxx
  uint exttype;       // More features, set of DX_xxx
  uint length;        // Length of main code (before ModRM/SIB)
  uint mask;          // Mask for first 4 bytes of the command
  uint code;          // Compare masked bytes with this
  uint postbyte;      // Postbyte
  uint[NOPERAND] arg; // Types of arguments, set of B_xxx
}


immutable AsmInstrDsc[1394] asmInstrTable = [
  AsmInstrDsc("PAUSE\0",D_SSE|D_MUSTF3,0,1,0x000000FF,0x00000090,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD,DX_NOP,1,0x000000FF,0x00000090,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD|D_UNDOC,DX_NOP,2,0x0000FFFF,0x0000190F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD|D_UNDOC,DX_NOP,2,0x0000FFFF,0x00001A0F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD|D_UNDOC,DX_NOP,2,0x0000FFFF,0x00001B0F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD|D_UNDOC,DX_NOP,2,0x0000FFFF,0x00001C0F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD|D_UNDOC,DX_NOP,2,0x0000FFFF,0x00001D0F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD|D_UNDOC,DX_NOP,2,0x0000FFFF,0x00001E0F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_CMD,DX_NOP,2,0x0000FFFF,0x00001F0F,0x00,[B_INT,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("MONITOR\0",D_SYS|D_RARE,0,3,0x00FFFFFF,0x00C8010F,0x00,[B_EAXMEM|B_PSEUDO,B_ECX|B_BINARY|B_PSEUDO,B_EDX|B_BINARY|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MWAIT\0",D_SYS|D_RARE,0,3,0x00FFFFFF,0x00C9010F,0x00,[B_EAX|B_BINARY|B_PSEUDO,B_ECX|B_BINARY|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CLAC\0",D_SYS|D_RARE,0,3,0x00FFFFFF,0x00CA010F,0x00,[B_EAX|B_BINARY|B_PSEUDO,B_ECX|B_BINARY|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("STAC\0",D_SYS|D_RARE,0,3,0x00FFFFFF,0x00CB010F,0x00,[B_EAX|B_BINARY|B_PSEUDO,B_ECX|B_BINARY|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("AAA\0",D_CMD|D_ALLFLAGS|D_RARE,0,1,0x000000FF,0x00000037,0x00,[B_AL|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("AAD\0",D_CMD|D_ALLFLAGS|D_RARE,0,2,0x0000FFFF,0x00000AD5,0x00,[B_AX|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("AAD\0",D_CMD|D_ALLFLAGS|D_RARE,0,1,0x000000FF,0x000000D5,0x00,[B_AX|B_UPD|B_PSEUDO,B_CONST8|B_UNSIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("AAM\0",D_CMD|D_ALLFLAGS|D_RARE,0,2,0x0000FFFF,0x00000AD4,0x00,[B_AX|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("AAM\0",D_CMD|D_ALLFLAGS|D_RARE,0,1,0x000000FF,0x000000D4,0x00,[B_AX|B_UPD|B_PSEUDO,B_CONST8|B_UNSIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("AAS\0",D_CMD|D_ALLFLAGS|D_RARE,0,1,0x000000FF,0x0000003F,0x00,[B_AL|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("ADC\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000000FE,0x00000014,0x00,[B_ACC|B_UPD,B_CONST|B_NOADDR,B_NONE,B_NONE]),
  AsmInstrDsc("ADC\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000038FE,0x00001080,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_CONST|B_NOADDR,B_NONE,B_NONE]),
  AsmInstrDsc("ADC\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000038FE,0x00001082,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_SXTCONST,B_NONE,B_NONE]),
  AsmInstrDsc("ADC\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000000FE,0x00000010,0x00,[B_INT|B_UPD,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("ADC\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000000FE,0x00000012,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("ADD\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JB|DX_ADD,1,0x000000FE,0x00000004,0x00,[B_ACC|B_UPD,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("ADD\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB|DX_ADD,1,0x000038FE,0x00000080,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("ADD\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB|DX_ADD,1,0x000038FE,0x00000082,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_SXTCONST,B_NONE,B_NONE]),
  AsmInstrDsc("ADD\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB|DX_ADD,1,0x000000FE,0x00000000,0x00,[B_INT|B_UPD,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("ADD\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JB|DX_ADD,1,0x000000FE,0x00000002,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("AND\0",D_TEST|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000024,0x00,[B_ACC|B_BINARY|B_UPD,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("AND\0",D_TEST|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ,1,0x000038FE,0x00002080,0x00,[B_INT|B_BINARY|B_SHOWSIZE|B_UPD,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("AND\0",D_TEST|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ,1,0x000038FE,0x00002082,0x00,[B_INT|B_BINARY|B_SHOWSIZE|B_UPD,B_SXTCONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("AND\0",D_TEST|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000020,0x00,[B_INT|B_BINARY|B_UPD,B_REG|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("AND\0",D_TEST|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000022,0x00,[B_REG|B_BINARY|B_UPD,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("ARPL\0",D_SYS|D_FLAGZ|D_RARE,0,1,0x000000FF,0x00000063,0x00,[B_INT16|B_UPD,B_REG16,B_NONE,B_NONE]),
  AsmInstrDsc("BOUND\0",D_CMD|D_RARE,0,1,0x000000FF,0x00000062,0x00,[B_REG|B_SIGNED,B_INTPAIR|B_MEMONLY,B_NONE,B_NONE]),
  AsmInstrDsc("BSF\0",D_CMD|D_ALLFLAGS,DX_JZ,2,0x0000FFFF,0x0000BC0F,0x00,[B_REG|B_CHG,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("BSR\0",D_CMD|D_NOREP|D_ALLFLAGS,DX_JZ,2,0x0000FFFF,0x0000BD0F,0x00,[B_REG|B_CHG,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("BSWAP\0",D_CMD,0,2,0x0000F8FF,0x0000C80F,0x00,[B_REGCMD|B_32BITONLY|B_NOESP|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("BT\0",D_TEST|D_ALLFLAGS,DX_JC,2,0x0000FFFF,0x0000A30F,0x00,[B_INT|B_BINARY,B_REG|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BT\0",D_TEST|D_ALLFLAGS,DX_JC,2,0x0038FFFF,0x0020BA0F,0x00,[B_INT|B_BINARY|B_SHOWSIZE,B_CONST8|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BTC\0",D_CMD|D_LOCKABLE|D_ALLFLAGS,DX_JC,2,0x0000FFFF,0x0000BB0F,0x00,[B_INT|B_BINARY|B_NOESP|B_UPD,B_REG|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BTC\0",D_CMD|D_LOCKABLE|D_ALLFLAGS,DX_JC,2,0x0038FFFF,0x0038BA0F,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BTR\0",D_CMD|D_LOCKABLE|D_ALLFLAGS,DX_JC,2,0x0000FFFF,0x0000B30F,0x00,[B_INT|B_BINARY|B_NOESP|B_UPD,B_REG|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BTR\0",D_CMD|D_LOCKABLE|D_ALLFLAGS,DX_JC,2,0x0038FFFF,0x0030BA0F,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BTS\0",D_CMD|D_LOCKABLE|D_ALLFLAGS,DX_JC,2,0x0000FFFF,0x0000AB0F,0x00,[B_INT|B_BINARY|B_NOESP|B_UPD,B_REG|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("BTS\0",D_CMD|D_LOCKABLE|D_ALLFLAGS,DX_JC,2,0x0038FFFF,0x0028BA0F,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_BITCNT,B_NONE,B_NONE]),
  AsmInstrDsc("CALL\0",D_CALL|D_CHGESP,0,1,0x000000FF,0x000000E8,0x00,[B_OFFSET|B_JMPCALL,B_PUSHRET|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CALL\0",D_CALL|D_CHGESP,0,1,0x000038FF,0x000010FF,0x00,[B_INT|B_JMPCALL,B_PUSHRET|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CALL\0",D_CALLFAR|D_CHGESP|D_RARE,0,1,0x000000FF,0x0000009A,0x00,[B_FARCONST|B_JMPCALLFAR,B_PUSHRETF|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CALL\0",D_CALLFAR|D_CHGESP|D_RARE,0,1,0x000038FF,0x000018FF,0x00,[B_SEGOFFS|B_JMPCALLFAR|B_MEMONLY,B_PUSHRETF|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CBW\0",D_CMD|D_DATA16,0,1,0x000000FF,0x00000098,0x00,[B_AX|B_UPD|B_PSEUDO,B_AL|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CBW\0",D_CMD|D_DATA16,0,1,0x000000FF,0x00000098,0x00,[B_AX|B_UPD|B_PSEUDO,B_AL,B_NONE,B_NONE]),
  AsmInstrDsc("CDQ\0",D_CMD|D_DATA32,0,1,0x000000FF,0x00000099,0x00,[B_EDX|B_CHG|B_PSEUDO,B_EAX|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CDQ\0",D_CMD|D_DATA32,0,1,0x000000FF,0x00000099,0x00,[B_EDX|B_CHG|B_PSEUDO,B_EAX,B_NONE,B_NONE]),
  AsmInstrDsc("CLC\0",D_CMD|D_FLAGC,0,1,0x000000FF,0x000000F8,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CLD\0",D_CMD|D_FLAGD,0,1,0x000000FF,0x000000FC,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CLFLUSH\0",D_CMD|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0038AE0F,0x00,[B_ANYMEM|B_MEMONLY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CLI\0",D_CMD|D_RARE,0,1,0x000000FF,0x000000FA,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CLTS\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000060F,0x00,[B_CR0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CMC\0",D_CMD|D_FLAGC,0,1,0x000000FF,0x000000F5,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVO\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x0000400F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNO\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x0000410F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVB\0",D_MOVC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000420F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVC\0",D_MOVC|D_COND|D_USESCARRY,DX_JC,2,0x0000FFFF,0x0000420F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNAE\0",D_MOVC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000420F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVAE\0",D_MOVC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000430F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNB\0",D_MOVC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000430F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNC\0",D_MOVC|D_COND|D_USESCARRY,DX_JC,2,0x0000FFFF,0x0000430F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVE\0",D_MOVC|D_COND,DX_JE,2,0x0000FFFF,0x0000440F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVZ\0",D_MOVC|D_COND,DX_JZ,2,0x0000FFFF,0x0000440F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNE\0",D_MOVC|D_COND,DX_JE,2,0x0000FFFF,0x0000450F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNZ\0",D_MOVC|D_COND,DX_JZ,2,0x0000FFFF,0x0000450F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVBE\0",D_MOVC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000460F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNA\0",D_MOVC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000460F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVA\0",D_MOVC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000470F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNBE\0",D_MOVC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000470F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVS\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x0000480F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNS\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x0000490F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVPE\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004A0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVP\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004A0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVPO\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004B0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNP\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004B0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVL\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004C0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNGE\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004C0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVGE\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004D0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNL\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004D0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVLE\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004E0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNG\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004E0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVG\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004F0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVNLE\0",D_MOVC|D_COND,0,2,0x0000FFFF,0x00004F0F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMP\0",D_TEST|D_SIZE01|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,1,0x000000FE,0x0000003C,0x00,[B_ACC,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("CMP\0",D_TEST|D_SIZE01|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,1,0x000038FE,0x00003880,0x00,[B_INT|B_SHOWSIZE,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("CMP\0",D_TEST|D_SIZE01|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,1,0x000038FE,0x00003882,0x00,[B_INT|B_SHOWSIZE,B_SXTCONST,B_NONE,B_NONE]),
  AsmInstrDsc("CMP\0",D_TEST|D_SIZE01|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,1,0x000000FE,0x00000038,0x00,[B_INT,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("CMP\0",D_TEST|D_SIZE01|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,1,0x000000FE,0x0000003A,0x00,[B_REG,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("CMPXCHG\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,2,0x0000FEFF,0x0000B00F,0x00,[B_INT|B_UPD,B_REG,B_ACC|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("CMPXCHG8B\0",D_CMD|D_LOCKABLE|D_MEMORY|D_ALLFLAGS,DX_JE|DX_JB,2,0x0038FFFF,0x0008C70F,0x00,[B_INT64|B_MEMONLY|B_UPD,B_EAX|B_UPD|B_PSEUDO,B_EDX|B_UPD|B_PSEUDO,B_EBX|B_PSEUDO]),
  AsmInstrDsc("CPUID\0",D_CMD,0,2,0x0000FFFF,0x0000A20F,0x00,[B_EAX|B_CHG|B_PSEUDO,B_EBX|B_CHG|B_PSEUDO,B_ECX|B_CHG|B_PSEUDO,B_EDX|B_CHG|B_PSEUDO]),
  AsmInstrDsc("CWD\0",D_CMD|D_DATA16,0,1,0x000000FF,0x00000099,0x00,[B_DX|B_CHG|B_PSEUDO,B_AX|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CWD\0",D_CMD|D_DATA16,0,1,0x000000FF,0x00000099,0x00,[B_DX|B_CHG|B_PSEUDO,B_AX,B_NONE,B_NONE]),
  AsmInstrDsc("CWDE\0",D_CMD|D_DATA32,0,1,0x000000FF,0x00000098,0x00,[B_EAX|B_UPD|B_PSEUDO,B_AX|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CWDE\0",D_CMD|D_DATA32,0,1,0x000000FF,0x00000098,0x00,[B_EAX|B_UPD|B_PSEUDO,B_AX,B_NONE,B_NONE]),
  AsmInstrDsc("DAA\0",D_CMD|D_ALLFLAGS|D_USESCARRY|D_RARE,DX_JC,1,0x000000FF,0x00000027,0x00,[B_AL|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("DAS\0",D_CMD|D_ALLFLAGS|D_USESCARRY|D_RARE,DX_JC,1,0x000000FF,0x0000002F,0x00,[B_AL|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("DEC\0",D_CMD|D_SIZE01|D_LOCKABLE|D_NOCFLAG,DX_JZ,1,0x000038FE,0x000008FE,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("DEC\0",D_CMD|D_NOCFLAG,DX_JZ,1,0x000000F8,0x00000048,0x00,[B_REGCMD|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("DIV\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000030F6,0x00,[B_INT8|B_SHOWSIZE,B_AX|B_UPD|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("DIV\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000030F7,0x00,[B_INT1632|B_UNSIGNED|B_NOESP|B_SHOWSIZE,B_DXEDX|B_UPD|B_PSEUDO,B_ACC|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("EMMS\0",D_CMD,0,2,0x0000FFFF,0x0000770F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("ENTER\0",D_CMD|D_CHGESP,0,1,0x000000FF,0x000000C8,0x00,[B_CONST16|B_STACKINC,B_CONST8_2|B_UNSIGNED,B_PUSH|B_CHG|B_PSEUDO,B_BPEBP|B_CHG|B_PSEUDO]),
  AsmInstrDsc("WAIT\0",D_CMD,0,1,0x000000FF,0x0000009B,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FWAIT\0",D_CMD,0,1,0x000000FF,0x0000009B,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("HLT\0",D_PRIVILEGED|D_RARE,0,1,0x000000FF,0x000000F4,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("IDIV\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000038F6,0x00,[B_INT8|B_SIGNED|B_SHOWSIZE,B_AX|B_UPD|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("IDIV\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000038F7,0x00,[B_INT1632|B_SIGNED|B_NOESP|B_SHOWSIZE,B_DXEDX|B_UPD|B_PSEUDO,B_ACC|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("IMUL\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000028F6,0x00,[B_AX|B_UPD|B_PSEUDO,B_INT8|B_SIGNED|B_SHOWSIZE,B_AL|B_SIGNED|B_PSEUDO,B_NONE]),
  AsmInstrDsc("IMUL\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000028F7,0x00,[B_DXEDX|B_CHG|B_PSEUDO,B_ACC|B_UPD|B_PSEUDO,B_INT1632|B_SIGNED|B_NOESP|B_SHOWSIZE,B_NONE]),
  AsmInstrDsc("IMUL\0",D_CMD|D_ALLFLAGS,0,2,0x0000FFFF,0x0000AF0F,0x00,[B_REG|B_UPD,B_INT|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("IMUL\0",D_CMD|D_ALLFLAGS,0,1,0x000000FF,0x0000006B,0x00,[B_REG|B_CHG,B_INT|B_NOESP,B_SXTCONST,B_NONE]),
  AsmInstrDsc("IMUL\0",D_CMD|D_ALLFLAGS,0,1,0x000000FF,0x00000069,0x00,[B_REG|B_CHG,B_INT|B_NOESP,B_CONST|B_SIGNED,B_NONE]),
  AsmInstrDsc("IN\0",D_IO|D_SIZE01|D_RARE,0,1,0x000000FE,0x000000E4,0x00,[B_ACC|B_CHG,B_CONST8|B_PORT,B_NONE,B_NONE]),
  AsmInstrDsc("IN\0",D_IO|D_SIZE01|D_RARE,0,1,0x000000FE,0x000000EC,0x00,[B_ACC|B_CHG,B_DXPORT|B_PORT,B_NONE,B_NONE]),
  AsmInstrDsc("INC\0",D_CMD|D_SIZE01|D_LOCKABLE|D_NOCFLAG,DX_JZ,1,0x000038FE,0x000000FE,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INC\0",D_CMD|D_NOCFLAG,DX_JZ,1,0x000000F8,0x00000040,0x00,[B_REGCMD|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INT\0",D_INT,0,1,0x000000FF,0x000000CD,0x00,[B_CONST8,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INT3\0",D_INT|D_RARE,0,1,0x000000FF,0x000000CC,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INTO\0",D_INT|D_RARE,0,1,0x000000FF,0x000000CE,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INT1\0",D_INT|D_UNDOC,0,1,0x000000FF,0x000000F1,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("ICEBP\0",D_INT|D_UNDOC,0,1,0x000000FF,0x000000F1,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INVD\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000080F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INVLPG\0",D_PRIVILEGED|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0038010F,0x00,[B_ANYMEM|B_MEMONLY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("IRET*\0",D_RETFAR|D_ALLFLAGS|D_CHGESP|D_WILDCARD|D_RARE,0,1,0x000000FF,0x000000CF,0x00,[B_STKTOPFAR|B_JMPCALLFAR|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JO\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x00000070,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JO\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x0000800F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNO\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x00000071,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNO\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x0000810F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JB\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,1,0x000000FF,0x00000072,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JC\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JC,1,0x000000FF,0x00000072,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNAE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,1,0x000000FF,0x00000072,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JB\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000820F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JC\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JC,2,0x0000FFFF,0x0000820F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNAE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000820F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JAE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,1,0x000000FF,0x00000073,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNB\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,1,0x000000FF,0x00000073,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNC\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JC,1,0x000000FF,0x00000073,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JAE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000830F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNB\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000830F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNC\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,DX_JC,2,0x0000FFFF,0x0000830F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JE\0",D_JMC|D_BHINT|D_COND,DX_JE,1,0x000000FF,0x00000074,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JZ\0",D_JMC|D_BHINT|D_COND,DX_JZ,1,0x000000FF,0x00000074,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JE\0",D_JMC|D_BHINT|D_COND,DX_JE,2,0x0000FFFF,0x0000840F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JZ\0",D_JMC|D_BHINT|D_COND,DX_JZ,2,0x0000FFFF,0x0000840F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNE\0",D_JMC|D_BHINT|D_COND,DX_JE,1,0x000000FF,0x00000075,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNZ\0",D_JMC|D_BHINT|D_COND,DX_JZ,1,0x000000FF,0x00000075,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNE\0",D_JMC|D_BHINT|D_COND,DX_JE,2,0x0000FFFF,0x0000850F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNZ\0",D_JMC|D_BHINT|D_COND,DX_JZ,2,0x0000FFFF,0x0000850F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JBE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,1,0x000000FF,0x00000076,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNA\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,1,0x000000FF,0x00000076,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JBE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000860F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNA\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000860F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JA\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,1,0x000000FF,0x00000077,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNBE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,1,0x000000FF,0x00000077,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JA\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000870F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNBE\0",D_JMC|D_BHINT|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000870F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JS\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x00000078,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JS\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x0000880F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNS\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x00000079,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNS\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x0000890F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JPE\0",D_JMC|D_BHINT|D_COND|D_RARE,0,1,0x000000FF,0x0000007A,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JP\0",D_JMC|D_BHINT|D_COND|D_RARE,0,1,0x000000FF,0x0000007A,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JPE\0",D_JMC|D_BHINT|D_COND|D_RARE,0,2,0x0000FFFF,0x00008A0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JP\0",D_JMC|D_BHINT|D_COND|D_RARE,0,2,0x0000FFFF,0x00008A0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JPO\0",D_JMC|D_BHINT|D_COND|D_RARE,0,1,0x000000FF,0x0000007B,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNP\0",D_JMC|D_BHINT|D_COND|D_RARE,0,1,0x000000FF,0x0000007B,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JPO\0",D_JMC|D_BHINT|D_COND|D_RARE,0,2,0x0000FFFF,0x00008B0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNP\0",D_JMC|D_BHINT|D_COND|D_RARE,0,2,0x0000FFFF,0x00008B0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JL\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007C,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNGE\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007C,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JL\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008C0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNGE\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008C0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JGE\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007D,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNL\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007D,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JGE\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008D0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNL\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008D0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JLE\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007E,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNG\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007E,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JLE\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008E0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNG\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008E0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JG\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007F,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNLE\0",D_JMC|D_BHINT|D_COND,0,1,0x000000FF,0x0000007F,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JG\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008F0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JNLE\0",D_JMC|D_BHINT|D_COND,0,2,0x0000FFFF,0x00008F0F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JCXZ\0",D_JMCX|D_ADDR16|D_BHINT,0,1,0x000000FF,0x000000E3,0x00,[B_CX|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("JECXZ\0",D_JMCX|D_ADDR32|D_BHINT,0,1,0x000000FF,0x000000E3,0x00,[B_ECX|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("JMP\0",D_JMP,0,1,0x000000FF,0x000000EB,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JMP\0",D_JMP,0,1,0x000000FF,0x000000E9,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JMP\0",D_JMP,0,1,0x000038FF,0x000020FF,0x00,[B_INT|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JMP\0",D_JMPFAR|D_SUSPICIOUS,0,1,0x000000FF,0x000000EA,0x00,[B_FARCONST|B_JMPCALLFAR,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JMP\0",D_JMPFAR|D_RARE,0,1,0x000038FF,0x000028FF,0x00,[B_SEGOFFS|B_JMPCALLFAR|B_MEMONLY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("LAHF\0",D_CMD,0,1,0x000000FF,0x0000009F,0x00,[B_AH|B_CHG|B_PSEUDO,B_FLAGS8|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("LAR\0",D_CMD|D_FLAGZ|D_RARE,DX_JZ,2,0x0000FFFF,0x0000020F,0x00,[B_REG|B_BINARY|B_NOESP|B_CHG,B_INT|B_BINARY|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("LDS\0",D_CMD|D_RARE,0,1,0x000000FF,0x000000C5,0x00,[B_SEGDS|B_CHG|B_PSEUDO,B_REG|B_BINARY|B_CHG,B_SEGOFFS|B_MEMONLY,B_NONE]),
  AsmInstrDsc("LES\0",D_CMD|D_RARE,0,1,0x000000FF,0x000000C4,0x00,[B_SEGES|B_CHG|B_PSEUDO,B_REG|B_BINARY|B_CHG,B_SEGOFFS|B_MEMONLY,B_NONE]),
  AsmInstrDsc("LFS\0",D_CMD|D_RARE,0,2,0x0000FFFF,0x0000B40F,0x00,[B_SEGFS|B_CHG|B_PSEUDO,B_REG|B_BINARY|B_CHG,B_SEGOFFS|B_MEMONLY,B_NONE]),
  AsmInstrDsc("LGS\0",D_CMD|D_RARE,0,2,0x0000FFFF,0x0000B50F,0x00,[B_SEGGS|B_CHG|B_PSEUDO,B_REG|B_BINARY|B_CHG,B_SEGOFFS|B_MEMONLY,B_NONE]),
  AsmInstrDsc("LSS\0",D_CMD|D_RARE,0,2,0x0000FFFF,0x0000B20F,0x00,[B_SEGSS|B_CHG|B_PSEUDO,B_REG|B_BINARY|B_CHG,B_SEGOFFS|B_MEMONLY,B_NONE]),
  AsmInstrDsc("LEA\0",D_CMD|D_HLADIR,DX_LEA,1,0x000000FF,0x0000008D,0x00,[B_REG|B_BINARY|B_CHG,B_ANYMEM|B_MEMONLY|B_NOSEG,B_NONE,B_NONE]),
  AsmInstrDsc("LEAVE\0",D_CMD|D_CHGESP,0,1,0x000000FF,0x000000C9,0x00,[B_BPEBP|B_CHG|B_PSEUDO,B_EBPMEM|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("LGDT\0",D_PRIVILEGED|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0010010F,0x00,[B_DESCR|B_MEMONLY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("LIDT\0",D_PRIVILEGED|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0018010F,0x00,[B_DESCR|B_MEMONLY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("LLDT\0",D_PRIVILEGED|D_RARE,0,2,0x0038FFFF,0x0010000F,0x00,[B_INT16|B_NOESP,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("LMSW\0",D_PRIVILEGED|D_RARE,0,2,0x0038FFFF,0x0030010F,0x00,[B_CR0|B_UPD|B_PSEUDO,B_INT16|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("LOOP\0",D_JMCX|D_ADDR32,0,1,0x000000FF,0x000000E2,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPD\0",D_JMCX|D_ADDR32,0,1,0x000000FF,0x000000E2,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPW\0",D_JMCX|D_ADDR16,0,1,0x000000FF,0x000000E2,0x00,[B_CX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPZ\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E1,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPDZ\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E1,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPWZ\0",D_JMCX|D_ADDR16|D_COND,0,1,0x000000FF,0x000000E1,0x00,[B_CX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPE\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E1,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPDE\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E1,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPWE\0",D_JMCX|D_ADDR16|D_COND,0,1,0x000000FF,0x000000E1,0x00,[B_CX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPNZ\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E0,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPDNZ\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E0,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPWNZ\0",D_JMCX|D_ADDR16|D_COND,0,1,0x000000FF,0x000000E0,0x00,[B_CX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPNE\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E0,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPDNE\0",D_JMCX|D_ADDR32|D_COND,0,1,0x000000FF,0x000000E0,0x00,[B_ECX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LOOPWNE\0",D_JMCX|D_ADDR16|D_COND,0,1,0x000000FF,0x000000E0,0x00,[B_CX|B_UPD|B_PSEUDO,B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE]),
  AsmInstrDsc("LSL\0",D_SYS|D_FLAGZ|D_RARE,0,2,0x0000FFFF,0x0000030F,0x00,[B_REG|B_NOESP|B_CHG,B_INT|B_BINARY|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("LTR\0",D_PRIVILEGED|D_RARE,0,2,0x0038FFFF,0x0018000F,0x00,[B_INT16|B_NOESP,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV|D_SIZE01,0,1,0x000000FE,0x00000088,0x00,[B_INT|B_CHG,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV|D_SIZE01,0,1,0x000000FE,0x0000008A,0x00,[B_REG|B_CHG,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_CMD|D_REGISTER|D_RARE,0,1,0x0000C0FF,0x0000C08C,0x00,[B_INT|B_REGISTER|B_NOESP|B_CHG,B_SEG,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_CMD|D_MEMORY|D_RARE,0,1,0x000000FF,0x0000008C,0x00,[B_INT16|B_MEMORY|B_CHG,B_SEG,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_CMD|D_RARE,0,1,0x000000FF,0x0000008E,0x00,[B_SEGNOCS|B_CHG,B_INT|B_REGISTER|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_CMD|D_RARE,0,1,0x000000FF,0x0000008E,0x00,[B_SEGNOCS|B_CHG,B_INT16|B_MEMORY|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV|D_SIZE01,0,1,0x000000FE,0x000000A0,0x00,[B_ACC|B_CHG,B_IMMINT,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV|D_SIZE01,0,1,0x000000FE,0x000000A2,0x00,[B_IMMINT|B_CHG,B_ACC,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV,0,1,0x000000F8,0x000000B0,0x00,[B_REGCMD8|B_CHG,B_CONST8,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV,0,1,0x000000F8,0x000000B8,0x00,[B_REGCMD|B_NOESP|B_CHG,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_MOV|D_SIZE01,0,1,0x000038FE,0x000000C6,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_CHG,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000220F,0x00,[B_CR|B_CHG,B_INT32|B_BINARY|B_REGONLY|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000200F,0x00,[B_INT32|B_BINARY|B_REGONLY|B_NOESP|B_CHG,B_CR,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000230F,0x00,[B_DR|B_CHG,B_INT32|B_BINARY|B_REGONLY|B_NOESP,B_NONE,B_NONE]),
  AsmInstrDsc("MOV\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000210F,0x00,[B_INT32|B_BINARY|B_REGONLY|B_NOESP|B_CHG,B_DR,B_NONE,B_NONE]),
  AsmInstrDsc("MOVSX\0",D_MOV,0,2,0x0000FFFF,0x0000BE0F,0x00,[B_REG|B_NOESP|B_CHG,B_INT8|B_SIGNED|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("MOVSX\0",D_MOV,0,2,0x0000FFFF,0x0000BF0F,0x00,[B_REG32|B_NOESP|B_CHG,B_INT16|B_SIGNED|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("MOVZX\0",D_MOV,0,2,0x0000FFFF,0x0000B60F,0x00,[B_REG|B_NOESP|B_CHG,B_INT8|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("MOVZX\0",D_MOV,0,2,0x0000FFFF,0x0000B70F,0x00,[B_REG32|B_NOESP|B_CHG,B_INT16|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("MUL\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000020F6,0x00,[B_AX|B_UPD|B_PSEUDO,B_AL|B_PSEUDO,B_INT8|B_UNSIGNED|B_SHOWSIZE,B_NONE]),
  AsmInstrDsc("MUL\0",D_CMD|D_ALLFLAGS,0,1,0x000038FF,0x000020F7,0x00,[B_DXEDX|B_CHG|B_PSEUDO,B_ACC|B_UPD|B_PSEUDO,B_INT1632|B_UNSIGNED|B_NOESP|B_SHOWSIZE,B_NONE]),
  AsmInstrDsc("NEG\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000018F6,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOT\0",D_CMD|D_SIZE01|D_LOCKABLE,0,1,0x000038FE,0x000010F6,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("OR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JB,1,0x000000FE,0x0000000C,0x00,[B_ACC|B_BINARY|B_UPD,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("OR\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB,1,0x000038FE,0x00000880,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("OR\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB,1,0x000038FE,0x00000882,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_SXTCONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("OR\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB,1,0x000000FE,0x00000008,0x00,[B_INT|B_BINARY|B_NOESP|B_UPD,B_REG|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("OR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JB,1,0x000000FE,0x0000000A,0x00,[B_REG|B_BINARY|B_NOESP|B_UPD,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("OUT\0",D_IO|D_SIZE01|D_RARE,0,1,0x000000FE,0x000000E6,0x00,[B_CONST8|B_PORT,B_ACC,B_NONE,B_NONE]),
  AsmInstrDsc("OUT\0",D_IO|D_SIZE01|D_RARE,0,1,0x000000FE,0x000000EE,0x00,[B_DXPORT|B_PORT,B_ACC,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP,0,1,0x000038FF,0x0000008F,0x00,[B_INT|B_SHOWSIZE|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP,0,1,0x000000F8,0x00000058,0x00,[B_REGCMD|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP|D_RARE,0,1,0x000000FF,0x0000001F,0x00,[B_SEGDS|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP|D_RARE,0,1,0x000000FF,0x00000007,0x00,[B_SEGES|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP|D_RARE,DX_JB,1,0x000000FF,0x00000017,0x00,[B_SEGSS|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP|D_RARE,0,2,0x0000FFFF,0x0000A10F,0x00,[B_SEGFS|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POP\0",D_POP|D_CHGESP|D_RARE,0,2,0x0000FFFF,0x0000A90F,0x00,[B_SEGGS|B_CHG,B_STKTOP|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("POPA*\0",D_CMD|D_CHGESP|D_WILDCARD,0,1,0x000000FF,0x00000061,0x00,[B_STKTOPA|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("POPF*\0",D_POP|D_ALLFLAGS|D_CHGESP|D_WILDCARD,0,1,0x000000FF,0x0000009D,0x00,[B_EFL|B_CHG|B_PSEUDO,B_STKTOPEFL|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP,0,1,0x000038FF,0x000030FF,0x00,[B_INT|B_SHOWSIZE,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP,0,1,0x000000F8,0x00000050,0x00,[B_REGCMD,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP,0,1,0x000000FF,0x0000006A,0x00,[B_SXTCONST|B_SHOWSIZE,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP,0,1,0x000000FF,0x00000068,0x00,[B_CONSTL|B_SHOWSIZE,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP|D_RARE,0,1,0x000000FF,0x0000000E,0x00,[B_SEGCS,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP|D_RARE,0,1,0x000000FF,0x00000016,0x00,[B_SEGSS,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP|D_RARE,0,1,0x000000FF,0x0000001E,0x00,[B_SEGDS,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP|D_RARE,0,1,0x000000FF,0x00000006,0x00,[B_SEGES,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP|D_RARE,0,2,0x0000FFFF,0x0000A00F,0x00,[B_SEGFS,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSH\0",D_PUSH|D_CHGESP|D_RARE,0,2,0x0000FFFF,0x0000A80F,0x00,[B_SEGGS,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("PUSHA*\0",D_CMD|D_CHGESP|D_WILDCARD,0,1,0x000000FF,0x00000060,0x00,[B_PUSHA|B_CHG|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PUSHF*\0",D_PUSH|D_CHGESP|D_WILDCARD,DX_JB,1,0x000000FF,0x0000009C,0x00,[B_EFL|B_PSEUDO,B_PUSH|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("RCL\0",D_CMD|D_SIZE01|D_FLAGSCO|D_USESCARRY,DX_JC,1,0x000038FE,0x000010D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("RCL\0",D_CMD|D_SIZE01|D_FLAGSCO|D_USESCARRY,DX_JC,1,0x000038FE,0x000010D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("RCL\0",D_CMD|D_SIZE01|D_FLAGSCO|D_USESCARRY,DX_JC,1,0x000038FE,0x000010C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("RCR\0",D_CMD|D_SIZE01|D_FLAGSCO|D_USESCARRY,DX_JC,1,0x000038FE,0x000018D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("RCR\0",D_CMD|D_SIZE01|D_FLAGSCO|D_USESCARRY,DX_JC,1,0x000038FE,0x000018D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("RCR\0",D_CMD|D_SIZE01|D_FLAGSCO|D_USESCARRY,DX_JC,1,0x000038FE,0x000018C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("ROL\0",D_CMD|D_SIZE01|D_FLAGSCO,DX_JC,1,0x000038FE,0x000000D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("ROL\0",D_CMD|D_SIZE01|D_FLAGSCO,DX_JC,1,0x000038FE,0x000000D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("ROL\0",D_CMD|D_SIZE01|D_FLAGSCO,DX_JC,1,0x000038FE,0x000000C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("ROR\0",D_CMD|D_SIZE01|D_FLAGSCO,DX_JC,1,0x000038FE,0x000008D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("ROR\0",D_CMD|D_SIZE01|D_FLAGSCO,DX_JC,1,0x000038FE,0x000008D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("ROR\0",D_CMD|D_SIZE01|D_FLAGSCO,DX_JC,1,0x000038FE,0x000008C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("RDMSR\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000320F,0x00,[B_EDX|B_BINARY|B_CHG|B_PSEUDO,B_EAX|B_BINARY|B_CHG|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("RDPMC\0",D_SYS|D_RARE,0,2,0x0000FFFF,0x0000330F,0x00,[B_EDX|B_BINARY|B_CHG|B_PSEUDO,B_EAX|B_BINARY|B_CHG|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("RDTSC\0",D_SYS|D_RARE,0,2,0x0000FFFF,0x0000310F,0x00,[B_EDX|B_BINARY|B_CHG|B_PSEUDO,B_EAX|B_BINARY|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("RDTSCP\0",D_SYS|D_RARE,0,3,0x00FFFFFF,0x00F9010F,0x00,[B_EDX|B_BINARY|B_CHG|B_PSEUDO,B_EAX|B_BINARY|B_CHG|B_PSEUDO,B_ECX|B_BINARY|B_CHG|B_PSEUDO,B_NONE]),
  AsmInstrDsc("RETN\0",D_RET|D_NOREP|D_CHGESP,DX_RETN,1,0x000000FF,0x000000C3,0x00,[B_STKTOP|B_JMPCALL|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("RET\0",D_RET|D_NOREP|D_CHGESP,0,1,0x000000FF,0x000000C3,0x00,[B_STKTOP|B_JMPCALL|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("RETN\0",D_RET|D_MUSTREP|D_CHGESP,DX_RETN,1,0x000000FF,0x000000C3,0x00,[B_STKTOP|B_JMPCALL|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("RET\0",D_RET|D_MUSTREP|D_CHGESP,0,1,0x000000FF,0x000000C3,0x00,[B_STKTOP|B_JMPCALL|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("RETN\0",D_RET|D_CHGESP,DX_RETN,1,0x000000FF,0x000000C2,0x00,[B_STKTOP|B_JMPCALL|B_PSEUDO,B_CONST16|B_STACKINC,B_NONE,B_NONE]),
  AsmInstrDsc("RET\0",D_RET|D_CHGESP,0,1,0x000000FF,0x000000C2,0x00,[B_STKTOP|B_JMPCALL|B_PSEUDO,B_CONST16|B_STACKINC,B_NONE,B_NONE]),
  AsmInstrDsc("RETF\0",D_RETFAR|D_CHGESP|D_RARE,0,1,0x000000FF,0x000000CB,0x00,[B_STKTOPFAR|B_JMPCALLFAR|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("RETF\0",D_RETFAR|D_CHGESP|D_RARE,0,1,0x000000FF,0x000000CA,0x00,[B_STKTOPFAR|B_JMPCALLFAR|B_PSEUDO,B_CONST16|B_STACKINC,B_NONE,B_NONE]),
  AsmInstrDsc("RSM\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000AA0F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SAHF\0",D_CMD|D_ALLFLAGS,0,1,0x000000FF,0x0000009E,0x00,[B_AH|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SHL\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000020D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SHL\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000020D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SHL\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000020C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAL\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000020D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAL\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000020D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAL\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000020C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAL\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_UNDOC,DX_JZ|DX_JC,1,0x000038FE,0x000030D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAL\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_UNDOC,DX_JZ|DX_JC,1,0x000038FE,0x000030D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAL\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_UNDOC,DX_JZ|DX_JC,1,0x000038FE,0x000030C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SALC\0",D_CMD|D_ALLFLAGS|D_UNDOC,DX_JZ|DX_JC,1,0x000000FF,0x000000D6,0x00,[B_AL|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SHR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000028D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SHR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000028D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SHR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000028C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000038D0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_1|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000038D2,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CL|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SAR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JC,1,0x000038FE,0x000038C0,0x00,[B_INT|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST8|B_SHIFTCNT,B_NONE,B_NONE]),
  AsmInstrDsc("SBB\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000000FE,0x0000001C,0x00,[B_ACC|B_UPD,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("SBB\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000038FE,0x00001880,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("SBB\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000038FE,0x00001882,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_SXTCONST,B_NONE,B_NONE]),
  AsmInstrDsc("SBB\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000000FE,0x00000018,0x00,[B_INT|B_UPD,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("SBB\0",D_CMD|D_SIZE01|D_ALLFLAGS|D_USESCARRY,DX_JZ|DX_JB,1,0x000000FE,0x0000001A,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("SETO\0",D_SETC|D_COND,0,2,0x0000FFFF,0x0000900F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNO\0",D_SETC|D_COND,0,2,0x0000FFFF,0x0000910F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETB\0",D_SETC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000920F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETC\0",D_SETC|D_COND|D_USESCARRY,DX_JC,2,0x0000FFFF,0x0000920F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNAE\0",D_SETC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000920F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETAE\0",D_SETC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000930F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNB\0",D_SETC|D_COND|D_USESCARRY,DX_JB,2,0x0000FFFF,0x0000930F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNC\0",D_SETC|D_COND|D_USESCARRY,DX_JC,2,0x0000FFFF,0x0000930F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETE\0",D_SETC|D_COND,DX_JE,2,0x0000FFFF,0x0000940F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETZ\0",D_SETC|D_COND,DX_JZ,2,0x0000FFFF,0x0000940F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNE\0",D_SETC|D_COND,DX_JE,2,0x0000FFFF,0x0000950F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNZ\0",D_SETC|D_COND,DX_JZ,2,0x0000FFFF,0x0000950F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETBE\0",D_SETC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000960F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNA\0",D_SETC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000960F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETA\0",D_SETC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000970F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNBE\0",D_SETC|D_COND|D_USESCARRY,0,2,0x0000FFFF,0x0000970F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETS\0",D_SETC|D_COND,0,2,0x0000FFFF,0x0000980F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNS\0",D_SETC|D_COND,0,2,0x0000FFFF,0x0000990F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETPE\0",D_SETC|D_COND|D_RARE,0,2,0x0000FFFF,0x00009A0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETP\0",D_SETC|D_COND|D_RARE,0,2,0x0000FFFF,0x00009A0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETPO\0",D_SETC|D_COND|D_RARE,0,2,0x0000FFFF,0x00009B0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNP\0",D_SETC|D_COND|D_RARE,0,2,0x0000FFFF,0x00009B0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETL\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009C0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNGE\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009C0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETGE\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009D0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNL\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009D0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETLE\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009E0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNG\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009E0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETG\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009F0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SETNLE\0",D_SETC|D_COND,0,2,0x0000FFFF,0x00009F0F,0x00,[B_INT8|B_CHG,B_ANYREG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SGDT\0",D_SYS|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0000010F,0x00,[B_DESCR|B_MEMONLY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SIDT\0",D_SYS|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0008010F,0x00,[B_DESCR|B_MEMONLY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SHLD\0",D_CMD|D_ALLFLAGS,DX_JZ|DX_JC,2,0x0000FFFF,0x0000A40F,0x00,[B_INT|B_NOESP|B_UPD,B_REG,B_CONST8|B_SHIFTCNT,B_NONE]),
  AsmInstrDsc("SHLD\0",D_CMD|D_ALLFLAGS,DX_JZ|DX_JC,2,0x0000FFFF,0x0000A50F,0x00,[B_INT|B_NOESP|B_UPD,B_REG,B_CL|B_SHIFTCNT,B_NONE]),
  AsmInstrDsc("SHRD\0",D_CMD|D_ALLFLAGS,DX_JZ|DX_JC,2,0x0000FFFF,0x0000AC0F,0x00,[B_INT|B_NOESP|B_UPD,B_REG,B_CONST8|B_SHIFTCNT,B_NONE]),
  AsmInstrDsc("SHRD\0",D_CMD|D_ALLFLAGS,DX_JZ|DX_JC,2,0x0000FFFF,0x0000AD0F,0x00,[B_INT|B_NOESP|B_UPD,B_REG,B_CL|B_SHIFTCNT,B_NONE]),
  AsmInstrDsc("SLDT\0",D_SYS|D_RARE,0,2,0x0038FFFF,0x0000000F,0x00,[B_INT|B_NOESP|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SMSW\0",D_SYS|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0020010F,0x00,[B_INT16|B_MEMONLY|B_CHG,B_CR0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SMSW\0",D_SYS|D_REGISTER|D_RARE,0,2,0x0038FFFF,0x0020010F,0x00,[B_INT|B_REGONLY|B_NOESP|B_CHG,B_CR0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("STC\0",D_CMD|D_FLAGC,0,1,0x000000FF,0x000000F9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("STD\0",D_CMD|D_FLAGD,0,1,0x000000FF,0x000000FD,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("STI\0",D_CMD|D_RARE,0,1,0x000000FF,0x000000FB,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("STMXCSR\0",D_CMD|D_MEMORY,0,2,0x0038FFFF,0x0018AE0F,0x00,[B_INT32|B_BINARY|B_MEMONLY|B_NOESP|B_SHOWSIZE|B_CHG,B_MXCSR|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("STR\0",D_SYS|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0008000F,0x00,[B_INT16|B_MEMONLY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("STR\0",D_SYS|D_REGISTER|D_RARE,0,2,0x0038FFFF,0x0008000F,0x00,[B_INT|B_REGONLY|B_NOESP|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SUB\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JB|DX_SUB,1,0x000000FE,0x0000002C,0x00,[B_ACC|B_UPD,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("SUB\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB|DX_SUB,1,0x000038FE,0x00002880,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_CONST,B_NONE,B_NONE]),
  AsmInstrDsc("SUB\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB|DX_SUB,1,0x000038FE,0x00002882,0x00,[B_INT|B_SHOWSIZE|B_UPD,B_SXTCONST,B_NONE,B_NONE]),
  AsmInstrDsc("SUB\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ|DX_JB|DX_SUB,1,0x000000FE,0x00000028,0x00,[B_INT|B_UPD,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("SUB\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ|DX_JB|DX_SUB,1,0x000000FE,0x0000002A,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("SYSENTER\0",D_SYS|D_RARE,0,2,0x0000FFFF,0x0000340F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SYSEXIT\0",D_SYS|D_ALLFLAGS|D_SUSPICIOUS,0,2,0x0000FFFF,0x0000350F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("TEST\0",D_TEST|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x000000A8,0x00,[B_ACC|B_BINARY,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("TEST\0",D_TEST|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000038FE,0x000000F6,0x00,[B_INT|B_BINARY|B_SHOWSIZE,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("TEST\0",D_TEST|D_SIZE01|D_ALLFLAGS|D_UNDOC,DX_JZ,1,0x000038FE,0x000008F6,0x00,[B_INT|B_BINARY|B_SHOWSIZE,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("TEST\0",D_TEST|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000084,0x00,[B_INT|B_BINARY,B_REG|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("TEST\0",D_TEST|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000084,0x00,[B_REG|B_BINARY,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("UD1\0",D_CMD|D_UNDOC,0,2,0x0000FFFF,0x0000B90F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("UD2\0",D_CMD,0,2,0x0000FFFF,0x00000B0F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VERR\0",D_CMD|D_FLAGZ|D_RARE,0,2,0x0038FFFF,0x0020000F,0x00,[B_INT16|B_NOESP,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VERW\0",D_CMD|D_FLAGZ|D_RARE,0,2,0x0038FFFF,0x0028000F,0x00,[B_INT16|B_NOESP,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("WBINVD\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000090F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("WRMSR\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000300F,0x00,[B_EDX|B_BINARY|B_PSEUDO,B_EAX|B_BINARY|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("XADD\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JE|DX_JB,2,0x0000FEFF,0x0000C00F,0x00,[B_INT|B_UPD,B_REG|B_CHG,B_NONE,B_NONE]),
  AsmInstrDsc("XCHG\0",D_MOV|D_LOCKABLE,0,1,0x000000F8,0x00000090,0x00,[B_ACC|B_CHG,B_REGCMD|B_CHG,B_NONE,B_NONE]),
  AsmInstrDsc("XCHG\0",D_MOV,0,1,0x000000F8,0x00000090,0x00,[B_REGCMD|B_CHG,B_ACC|B_CHG,B_NONE,B_NONE]),
  AsmInstrDsc("XCHG\0",D_MOV|D_SIZE01|D_LOCKABLE,0,1,0x000000FE,0x00000086,0x00,[B_INT|B_CHG,B_REG|B_CHG,B_NONE,B_NONE]),
  AsmInstrDsc("XCHG\0",D_MOV|D_SIZE01|D_LOCKABLE,0,1,0x000000FE,0x00000086,0x00,[B_REG|B_CHG,B_INT|B_CHG,B_NONE,B_NONE]),
  AsmInstrDsc("XLAT\0",D_CMD,0,1,0x000000FF,0x000000D7,0x00,[B_AL|B_CHG|B_PSEUDO,B_XLATMEM,B_NONE,B_NONE]),
  AsmInstrDsc("XLATB\0",D_CMD,0,1,0x000000FF,0x000000D7,0x00,[B_AL|B_UPD|B_PSEUDO,B_XLATMEM|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("XOR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000034,0x00,[B_ACC|B_BINARY|B_UPD,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("XOR\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ,1,0x000038FE,0x00003080,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_CONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("XOR\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ,1,0x000038FE,0x00003082,0x00,[B_INT|B_BINARY|B_NOESP|B_SHOWSIZE|B_UPD,B_SXTCONST|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("XOR\0",D_CMD|D_SIZE01|D_LOCKABLE|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000030,0x00,[B_INT|B_BINARY|B_UPD,B_REG|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("XOR\0",D_CMD|D_SIZE01|D_ALLFLAGS,DX_JZ,1,0x000000FE,0x00000032,0x00,[B_REG|B_BINARY|B_UPD,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("CMPS\0",D_CMD|D_SIZE01|D_LONGFORM|D_NOREP|D_ALLFLAGS|D_HLADIR,DX_JE|DX_JB,1,0x000000FE,0x000000A6,0x00,[B_STRSRC|B_SHOWSIZE,B_STRDEST|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CMPSB\0",D_CMD|D_NOREP|D_ALLFLAGS,DX_JE|DX_JB,1,0x000000FF,0x000000A6,0x00,[B_STRSRC8|B_PSEUDO,B_STRDEST8|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CMPS*\0",D_CMD|D_NOREP|D_ALLFLAGS|D_WILDCARD,DX_JE|DX_JB,1,0x000000FF,0x000000A7,0x00,[B_STRSRC|B_PSEUDO,B_STRDEST|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("CMPS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPE|D_ALLFLAGS|D_HLADIR,0,1,0x000000FE,0x000000A6,0x00,[B_STRSRC|B_SHOWSIZE,B_STRDEST|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("CMPSB\0",D_STRING|D_MUSTREPE|D_ALLFLAGS,0,1,0x000000FF,0x000000A6,0x00,[B_STRSRC8|B_PSEUDO,B_STRDEST8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("CMPS*\0",D_STRING|D_MUSTREPE|D_ALLFLAGS|D_WILDCARD,0,1,0x000000FF,0x000000A7,0x00,[B_STRSRC|B_PSEUDO,B_STRDEST|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("CMPS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_ALLFLAGS|D_HLADIR,0,1,0x000000FE,0x000000A6,0x00,[B_STRSRC|B_SHOWSIZE,B_STRDEST|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("CMPSB\0",D_STRING|D_MUSTREPNE|D_ALLFLAGS,0,1,0x000000FF,0x000000A6,0x00,[B_STRSRC8|B_PSEUDO,B_STRDEST8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("CMPS*\0",D_STRING|D_MUSTREPNE|D_ALLFLAGS|D_WILDCARD,0,1,0x000000FF,0x000000A7,0x00,[B_STRSRC|B_PSEUDO,B_STRDEST|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("LODS\0",D_CMD|D_SIZE01|D_LONGFORM|D_NOREP,0,1,0x000000FE,0x000000AC,0x00,[B_ACC|B_CHG|B_PSEUDO,B_STRSRC|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("LODSB\0",D_CMD|D_NOREP,0,1,0x000000FF,0x000000AC,0x00,[B_AL|B_CHG|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("LODS*\0",D_CMD|D_NOREP|D_WILDCARD,0,1,0x000000FF,0x000000AD,0x00,[B_ACC|B_CHG|B_PSEUDO,B_STRSRC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("LODS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREP|D_RARE,0,1,0x000000FE,0x000000AC,0x00,[B_ACC|B_CHG|B_PSEUDO,B_STRSRC|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("LODSB\0",D_STRING|D_MUSTREP|D_RARE,0,1,0x000000FF,0x000000AC,0x00,[B_AL|B_CHG|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("LODS*\0",D_STRING|D_MUSTREP|D_WILDCARD|D_RARE,0,1,0x000000FF,0x000000AD,0x00,[B_ACC|B_CHG|B_PSEUDO,B_STRSRC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("LODS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_UNDOC,0,1,0x000000FE,0x000000AC,0x00,[B_ACC|B_CHG|B_PSEUDO,B_STRSRC|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("LODSB\0",D_STRING|D_MUSTREPNE|D_UNDOC,0,1,0x000000FF,0x000000AC,0x00,[B_AL|B_CHG|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("LODS*\0",D_STRING|D_MUSTREPNE|D_WILDCARD|D_UNDOC,0,1,0x000000FF,0x000000AD,0x00,[B_ACC|B_CHG|B_PSEUDO,B_STRSRC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVS\0",D_CMD|D_SIZE01|D_LONGFORM|D_NOREP,0,1,0x000000FE,0x000000A4,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_STRSRC|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("MOVSB\0",D_CMD|D_NOREP,0,1,0x000000FF,0x000000A4,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("MOVS*\0",D_CMD|D_NOREP|D_WILDCARD,0,1,0x000000FF,0x000000A5,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_STRSRC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("MOVS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREP,0,1,0x000000FE,0x000000A4,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_STRSRC|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVSB\0",D_STRING|D_MUSTREP,0,1,0x000000FF,0x000000A4,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVS*\0",D_STRING|D_MUSTREP|D_WILDCARD,0,1,0x000000FF,0x000000A5,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_STRSRC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_UNDOC,0,1,0x000000FE,0x000000A4,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_STRSRC|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVSB\0",D_STRING|D_MUSTREPNE|D_UNDOC,0,1,0x000000FF,0x000000A4,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVS*\0",D_STRING|D_MUSTREPNE|D_WILDCARD|D_UNDOC,0,1,0x000000FF,0x000000A5,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_STRSRC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("SCAS\0",D_CMD|D_SIZE01|D_LONGFORM|D_NOREP|D_ALLFLAGS,DX_JE|DX_JB,1,0x000000FE,0x000000AE,0x00,[B_STRDEST|B_SHOWSIZE,B_ACC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SCASB\0",D_CMD|D_NOREP|D_ALLFLAGS,DX_JE|DX_JB,1,0x000000FF,0x000000AE,0x00,[B_STRDEST8|B_PSEUDO,B_AL|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SCAS*\0",D_CMD|D_NOREP|D_ALLFLAGS|D_WILDCARD,DX_JE|DX_JB,1,0x000000FF,0x000000AF,0x00,[B_STRDEST|B_PSEUDO,B_ACC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SCAS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPE|D_ALLFLAGS,0,1,0x000000FE,0x000000AE,0x00,[B_STRDEST|B_SHOWSIZE,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("SCASB\0",D_STRING|D_MUSTREPE|D_ALLFLAGS,0,1,0x000000FF,0x000000AE,0x00,[B_STRDEST8|B_PSEUDO,B_AL|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("SCAS*\0",D_STRING|D_MUSTREPE|D_ALLFLAGS|D_WILDCARD,0,1,0x000000FF,0x000000AF,0x00,[B_STRDEST|B_PSEUDO,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("SCAS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_ALLFLAGS,0,1,0x000000FE,0x000000AE,0x00,[B_STRDEST|B_SHOWSIZE,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("SCASB\0",D_STRING|D_MUSTREPNE|D_ALLFLAGS,0,1,0x000000FF,0x000000AE,0x00,[B_STRDEST8|B_PSEUDO,B_AL|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("SCAS*\0",D_STRING|D_MUSTREPNE|D_ALLFLAGS|D_WILDCARD,0,1,0x000000FF,0x000000AF,0x00,[B_STRDEST|B_PSEUDO,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("STOS\0",D_CMD|D_SIZE01|D_LONGFORM|D_NOREP,0,1,0x000000FE,0x000000AA,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_ACC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("STOSB\0",D_CMD|D_NOREP,0,1,0x000000FF,0x000000AA,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_AL|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("STOS*\0",D_CMD|D_NOREP|D_WILDCARD,0,1,0x000000FF,0x000000AB,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_ACC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("STOS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREP,0,1,0x000000FE,0x000000AA,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("STOSB\0",D_STRING|D_MUSTREP,0,1,0x000000FF,0x000000AA,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_AL|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("STOS*\0",D_STRING|D_MUSTREP|D_WILDCARD,0,1,0x000000FF,0x000000AB,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("STOS\0",D_STRING|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_UNDOC,0,1,0x000000FE,0x000000AA,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("STOSB\0",D_STRING|D_MUSTREPNE|D_UNDOC,0,1,0x000000FF,0x000000AA,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_AL|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("STOS*\0",D_STRING|D_MUSTREPNE|D_WILDCARD|D_UNDOC,0,1,0x000000FF,0x000000AB,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_ACC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("INS\0",D_IO|D_SIZE01|D_LONGFORM|D_NOREP|D_RARE,0,1,0x000000FE,0x0000006C,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_DXPORT|B_PORT,B_NONE,B_NONE]),
  AsmInstrDsc("INSB\0",D_IO|D_NOREP|D_RARE,0,1,0x000000FF,0x0000006C,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_DXPORT|B_PORT|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("INS*\0",D_IO|D_NOREP|D_WILDCARD|D_RARE,0,1,0x000000FF,0x0000006D,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_DXPORT|B_PORT|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("INS\0",D_IO|D_SIZE01|D_LONGFORM|D_MUSTREP|D_RARE,0,1,0x000000FE,0x0000006C,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_DXPORT|B_PORT,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("INSB\0",D_IO|D_MUSTREP|D_RARE,0,1,0x000000FF,0x0000006C,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_DXPORT|B_PORT|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("INS*\0",D_IO|D_MUSTREP|D_WILDCARD|D_RARE,0,1,0x000000FF,0x0000006D,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_DXPORT|B_PORT|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("INS\0",D_IO|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_UNDOC,0,1,0x000000FE,0x0000006C,0x00,[B_STRDEST|B_SHOWSIZE|B_CHG,B_DXPORT|B_PORT,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("INSB\0",D_IO|D_MUSTREPNE|D_UNDOC,0,1,0x000000FF,0x0000006C,0x00,[B_STRDEST8|B_CHG|B_PSEUDO,B_DXPORT|B_PORT|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("INS*\0",D_IO|D_MUSTREPNE|D_WILDCARD|D_UNDOC,0,1,0x000000FF,0x0000006D,0x00,[B_STRDEST|B_CHG|B_PSEUDO,B_DXPORT|B_PORT|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("OUTS\0",D_IO|D_SIZE01|D_LONGFORM|D_NOREP|D_RARE,0,1,0x000000FE,0x0000006E,0x00,[B_DXPORT|B_PORT,B_STRSRC|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("OUTSB\0",D_IO|D_NOREP|D_RARE,0,1,0x000000FF,0x0000006E,0x00,[B_DXPORT|B_PORT|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("OUTS*\0",D_IO|D_NOREP|D_WILDCARD|D_RARE,0,1,0x000000FF,0x0000006F,0x00,[B_DXPORT|B_PORT|B_PSEUDO,B_STRSRC|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("OUTS\0",D_IO|D_SIZE01|D_LONGFORM|D_MUSTREP|D_RARE,0,1,0x000000FE,0x0000006E,0x00,[B_DXPORT|B_PORT,B_STRSRC|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("OUTSB\0",D_IO|D_MUSTREP|D_RARE,0,1,0x000000FF,0x0000006E,0x00,[B_DXPORT|B_PORT|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("OUTS*\0",D_IO|D_MUSTREP|D_WILDCARD|D_RARE,0,1,0x000000FF,0x0000006F,0x00,[B_DXPORT|B_PORT|B_PSEUDO,B_STRSRC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("OUTS\0",D_IO|D_SIZE01|D_LONGFORM|D_MUSTREPNE|D_UNDOC,0,1,0x000000FE,0x0000006E,0x00,[B_DXPORT|B_PORT,B_STRSRC|B_SHOWSIZE,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("OUTSB\0",D_IO|D_MUSTREPNE|D_UNDOC,0,1,0x000000FF,0x0000006E,0x00,[B_DXPORT|B_PORT|B_PSEUDO,B_STRSRC8|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("OUTS*\0",D_IO|D_MUSTREPNE|D_WILDCARD|D_UNDOC,0,1,0x000000FF,0x0000006F,0x00,[B_DXPORT|B_PORT|B_PSEUDO,B_STRSRC|B_PSEUDO,B_STRCNT|B_UPD|B_PSEUDO,B_NONE]),
  AsmInstrDsc("MOVBE\0",D_CMD|D_NOREP,0,3,0x00FFFFFF,0x00F0380F,0x00,[B_REG|B_CHG,B_INT|B_MEMONLY,B_NONE,B_NONE]),
  AsmInstrDsc("MOVBE\0",D_CMD|D_NOREP,0,3,0x00FFFFFF,0x00F1380F,0x00,[B_INT|B_MEMONLY|B_CHG,B_REG,B_NONE,B_NONE]),
  AsmInstrDsc("XGETBV\0",D_SYS|D_MUSTNONE|D_RARE,0,3,0x00FFFFFF,0x00D0010F,0x00,[B_EAX|B_CHG|B_PSEUDO,B_EDX|B_CHG|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("XSETBV\0",D_PRIVILEGED|D_MUSTNONE|D_RARE,0,3,0x00FFFFFF,0x00D1010F,0x00,[B_EAX|B_PSEUDO,B_EDX|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("XRSTOR\0",D_SYS|D_MUSTNONE|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0028AE0F,0x00,[B_ANYMEM|B_MEMONLY,B_EAX|B_PSEUDO,B_EDX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("XSAVE\0",D_SYS|D_MUSTNONE|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0020AE0F,0x00,[B_ANYMEM|B_MEMONLY|B_CHG,B_EAX|B_PSEUDO,B_EDX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("F2XM1\0",D_FPU,0,2,0x0000FFFF,0x0000F0D9,0x00,[B_ST0|B_CHG|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FABS\0",D_FPU,0,2,0x0000FFFF,0x0000E1D9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FCHS\0",D_FPU,0,2,0x0000FFFF,0x0000E0D9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FCLEX\0",D_FPU,0,2,0x0000FFFF,0x0000E2DB,0x00,[B_FST|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMPP\0",D_FPU|D_FPUPOP2,0,2,0x0000FFFF,0x0000D9DE,0x00,[B_ST0|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FCOS\0",D_FPU,0,2,0x0000FFFF,0x0000FFD9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FDECSTP\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000F6D9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FINCSTP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000F7D9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FINIT\0",D_FPU,0,2,0x0000FFFF,0x0000E3DB,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLD1\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000E8D9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDL2T\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000E9D9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDL2E\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000EAD9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDPI\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000EBD9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDLG2\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000ECD9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDLN2\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000EDD9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDZ\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000EED9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FNOP\0",D_FPU,0,2,0x0000FFFF,0x0000D0D9,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FPATAN\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000F3D9,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FPREM\0",D_FPU,0,2,0x0000FFFF,0x0000F8D9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FPREM1\0",D_FPU,0,2,0x0000FFFF,0x0000F5D9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FPTAN\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000F2D9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FRNDINT\0",D_FPU,0,2,0x0000FFFF,0x0000FCD9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FSCALE\0",D_FPU,0,2,0x0000FFFF,0x0000FDD9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSIN\0",D_FPU,0,2,0x0000FFFF,0x0000FED9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FSINCOS\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000FBD9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FSQRT\0",D_FPU,0,2,0x0000FFFF,0x0000FAD9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FSTSW\0",D_FPU,0,2,0x0000FFFF,0x0000E0DF,0x00,[B_AX|B_CHG,B_FST|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FTST\0",D_FPU,0,2,0x0000FFFF,0x0000E4D9,0x00,[B_ST0|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOMPP\0",D_FPU|D_FPUPOP2,0,2,0x0000FFFF,0x0000E9DA,0x00,[B_ST0|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FXAM\0",D_FPU,0,2,0x0000FFFF,0x0000E5D9,0x00,[B_ST0|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FXTRACT\0",D_FPU|D_FPUPUSH,0,2,0x0000FFFF,0x0000F4D9,0x00,[B_ST0|B_UPD|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FYL2X\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000F1D9,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FYL2XP1\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000F9D9,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FENI\0",D_FPU|D_RARE,0,2,0x0000FFFF,0x0000E0DB,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FDISI\0",D_FPU|D_RARE,0,2,0x0000FFFF,0x0000E1DB,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FADD\0",D_FPU,0,2,0x0000F8FF,0x0000C0D8,0x00,[B_ST0|B_UPD,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FADD\0",D_FPU,0,2,0x0000F8FF,0x0000C0DC,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FADDP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000C0DE,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FADDP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000C1DE,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVB\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000C0DA,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVE\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000C8DA,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVBE\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000D0DA,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVU\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000D8DA,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVNB\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000C0DB,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVNE\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000C8DB,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVNBE\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000D0DB,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVNU\0",D_FPU|D_COND,0,2,0x0000F8FF,0x0000D8DB,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCOM\0",D_FPU,0,2,0x0000F8FF,0x0000D0D8,0x00,[B_ST0|B_PSEUDO,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCOM\0",D_FPU,0,2,0x0000FFFF,0x0000D1D8,0x00,[B_ST0|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000D8D8,0x00,[B_ST0|B_PSEUDO,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000D9D8,0x00,[B_ST0|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMI\0",D_FPU|D_FLAGSZPC,0,2,0x0000F8FF,0x0000F0DB,0x00,[B_ST0,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMIP\0",D_FPU|D_FLAGSZPC|D_FPUPOP,0,2,0x0000F8FF,0x0000F0DF,0x00,[B_ST0,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOMI\0",D_FPU|D_FLAGSZPC,0,2,0x0000F8FF,0x0000E8DB,0x00,[B_ST0,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOMIP\0",D_FPU|D_FLAGSZPC|D_FPUPOP,0,2,0x0000F8FF,0x0000E8DF,0x00,[B_ST0,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FDIV\0",D_FPU,0,2,0x0000F8FF,0x0000F0D8,0x00,[B_ST0|B_UPD,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FDIV\0",D_FPU,0,2,0x0000F8FF,0x0000F8DC,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000F8DE,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000F9DE,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVR\0",D_FPU,0,2,0x0000F8FF,0x0000F8D8,0x00,[B_ST0|B_UPD,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVR\0",D_FPU,0,2,0x0000F8FF,0x0000F0DC,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVRP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000F0DE,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVRP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000F1DE,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FFREE\0",D_FPU,0,2,0x0000F8FF,0x0000C0DD,0x00,[B_ST,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FFREEP\0",D_FPU|D_FPUPOP|D_UNDOC,0,2,0x0000F8FF,0x0000C0DF,0x00,[B_ST,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLD\0",D_FPU|D_FPUPUSH,0,2,0x0000F8FF,0x0000C0D9,0x00,[B_ST,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FMUL\0",D_FPU,0,2,0x0000F8FF,0x0000C8D8,0x00,[B_ST0|B_UPD,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FMUL\0",D_FPU,0,2,0x0000F8FF,0x0000C8DC,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FMULP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000C8DE,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FMULP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000C9DE,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FST\0",D_FPU,0,2,0x0000F8FF,0x0000D0DD,0x00,[B_ST|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSTP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000D8DD,0x00,[B_ST|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSUB\0",D_FPU,0,2,0x0000F8FF,0x0000E0D8,0x00,[B_ST0|B_UPD,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FSUB\0",D_FPU,0,2,0x0000F8FF,0x0000E8DC,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000E8DE,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000E9DE,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBR\0",D_FPU,0,2,0x0000F8FF,0x0000E8D8,0x00,[B_ST0|B_UPD,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBR\0",D_FPU,0,2,0x0000F8FF,0x0000E0DC,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBRP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000E0DE,0x00,[B_ST|B_UPD,B_ST0,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBRP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000E1DE,0x00,[B_ST1|B_UPD|B_PSEUDO,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOM\0",D_FPU,0,2,0x0000F8FF,0x0000E0DD,0x00,[B_ST0|B_PSEUDO,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOM\0",D_FPU,0,2,0x0000FFFF,0x0000E1DD,0x00,[B_ST0|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOMP\0",D_FPU|D_FPUPOP,0,2,0x0000F8FF,0x0000E8DD,0x00,[B_ST0|B_PSEUDO,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FUCOMP\0",D_FPU|D_FPUPOP,0,2,0x0000FFFF,0x0000E9DD,0x00,[B_ST0|B_PSEUDO,B_ST1|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FXCH\0",D_FPU,0,2,0x0000F8FF,0x0000C8D9,0x00,[B_ST0|B_CHG|B_PSEUDO,B_ST|B_CHG,B_NONE,B_NONE]),
  AsmInstrDsc("FXCH\0",D_FPU,0,2,0x0000FFFF,0x0000C9D9,0x00,[B_ST0|B_CHG|B_PSEUDO,B_ST1|B_CHG|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FADD\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000000D8,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FADD\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000000DC,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIADD\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000000DA,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIADD\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000000DE,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FBLD\0",D_FPU|D_MEMORY|D_FPUPUSH|D_RARE,0,1,0x000038FF,0x000020DF,0x00,[B_BCD|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FBSTP\0",D_FPU|D_MEMORY|D_FPUPOP|D_RARE,0,1,0x000038FF,0x000030DF,0x00,[B_BCD|B_MEMORY|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FCOM\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010D8,0x00,[B_ST0|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FCOM\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010DC,0x00,[B_ST0|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018D8,0x00,[B_ST0|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FCOMP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018DC,0x00,[B_ST0|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FDIV\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000030D8,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FDIV\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000030DC,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIDIV\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000030DA,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIDIV\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000030DE,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000038D8,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FDIVR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000038DC,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIDIVR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000038DA,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIDIVR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000038DE,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FICOM\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010DE,0x00,[B_ST0|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FICOM\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010DA,0x00,[B_ST0|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FICOMP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018DE,0x00,[B_ST0|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FICOMP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018DA,0x00,[B_ST0|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FILD\0",D_FPU|D_MEMORY|D_FPUPUSH,0,1,0x000038FF,0x000000DF,0x00,[B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FILD\0",D_FPU|D_MEMORY|D_FPUPUSH,0,1,0x000038FF,0x000000DB,0x00,[B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FILD\0",D_FPU|D_MEMORY|D_FPUPUSH,0,1,0x000038FF,0x000028DF,0x00,[B_INT64|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FIST\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010DF,0x00,[B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FIST\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010DB,0x00,[B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FISTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018DF,0x00,[B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FISTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018DB,0x00,[B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FISTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000038DF,0x00,[B_INT64|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FISTTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000008DF,0x00,[B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FISTTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000008DB,0x00,[B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FISTTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000008DD,0x00,[B_INT64|B_SIGNED|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FLD\0",D_FPU|D_MEMORY|D_FPUPUSH,0,1,0x000038FF,0x000000D9,0x00,[B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLD\0",D_FPU|D_MEMORY|D_FPUPUSH,0,1,0x000038FF,0x000000DD,0x00,[B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLD\0",D_FPU|D_MEMORY|D_FPUPUSH,0,1,0x000038FF,0x000028DB,0x00,[B_FLOAT80|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FLDCW\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000028D9,0x00,[B_FCW|B_CHG|B_PSEUDO,B_INT16|B_BINARY|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("FLDENV\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000020D9,0x00,[B_LONGDATA|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FMUL\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000008D8,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FMUL\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000008DC,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIMUL\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000008DA,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FIMUL\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000008DE,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FRSTOR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000020DD,0x00,[B_LONGDATA|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FSAVE\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000030DD,0x00,[B_LONGDATA|B_MEMORY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FST\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010D9,0x00,[B_FLOAT32|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FST\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000010DD,0x00,[B_FLOAT64|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018D9,0x00,[B_FLOAT32|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000018DD,0x00,[B_FLOAT64|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSTP\0",D_FPU|D_MEMORY|D_FPUPOP,0,1,0x000038FF,0x000038DB,0x00,[B_FLOAT80|B_MEMORY|B_SHOWSIZE|B_CHG,B_ST0|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSTCW\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000038D9,0x00,[B_INT16|B_BINARY|B_MEMORY|B_CHG,B_FCW|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSTENV\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000030D9,0x00,[B_LONGDATA|B_MEMORY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FSTSW\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000038DD,0x00,[B_INT16|B_BINARY|B_MEMORY|B_CHG,B_FST|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("FSUB\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000020D8,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FSUB\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000020DC,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FISUB\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000020DA,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FISUB\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000020DE,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000028D8,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT32|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FSUBR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000028DC,0x00,[B_ST0|B_UPD|B_PSEUDO,B_FLOAT64|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FISUBR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000028DA,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT32|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FISUBR\0",D_FPU|D_MEMORY,0,1,0x000038FF,0x000028DE,0x00,[B_ST0|B_UPD|B_PSEUDO,B_INT16|B_SIGNED|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("FSETPM\0",D_FPU|D_UNDOC,0,2,0x0000FFFF,0x0000E4DB,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("ADDPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000580F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VADDPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000058,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("ADDPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000580F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VADDPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000058,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("ADDSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000580F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VADDSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000058,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("ADDSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000580F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VADDSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000058,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("ADDSUBPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D00F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VADDSUBPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000D0,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("ADDSUBPS\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000D00F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VADDSUBPS\0",D_AVX|D_MUSTF2,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000D0,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("ANDPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000540F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VANDPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000054,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("ANDPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000540F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VANDPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000054,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("ANDNPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000550F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VANDNPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000055,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("ANDNPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000550F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VANDNPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000055,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("CMP*PD\0",D_SSE|D_POSTBYTE|D_MUST66|D_WILDCARD,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VCMP*PD\0",D_AVX|D_POSTBYTE|D_MUST66|D_WILDCARD,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000C2,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("CMPPD\0",D_SSE|D_MUST66|D_SUSPICIOUS,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_CONST8,B_NONE]),
  AsmInstrDsc("VCMPPD\0",D_AVX|D_MUST66|D_SUSPICIOUS,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000C2,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_CONST8]),
  AsmInstrDsc("CMP*PS\0",D_SSE|D_POSTBYTE|D_MUSTNONE|D_WILDCARD,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VCMP*PS\0",D_AVX|D_POSTBYTE|D_MUSTNONE|D_WILDCARD,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000C2,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("CMPPS\0",D_SSE|D_MUSTNONE|D_SUSPICIOUS,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_CONST8,B_NONE]),
  AsmInstrDsc("VCMPPS\0",D_AVX|D_MUSTNONE|D_SUSPICIOUS,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000C2,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_CONST8]),
  AsmInstrDsc("CMP*SD\0",D_SSE|D_POSTBYTE|D_MUSTF2|D_WILDCARD,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VCMP*SD\0",D_AVX|D_POSTBYTE|D_MUSTF2|D_WILDCARD,DX_VEX|DX_IGNOREL,1,0x000000FF,0x000000C2,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("CMPSD\0",D_SSE|D_MUSTF2|D_SUSPICIOUS,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF64L|B_UPD,B_SVEXF64L,B_CONST8,B_NONE]),
  AsmInstrDsc("VCMPSD\0",D_AVX|D_MUSTF2|D_SUSPICIOUS,DX_VEX|DX_IGNOREL,1,0x000000FF,0x000000C2,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_CONST8]),
  AsmInstrDsc("CMP*SS\0",D_SSE|D_POSTBYTE|D_MUSTF3|D_WILDCARD,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VCMP*SS\0",D_AVX|D_POSTBYTE|D_MUSTF3|D_WILDCARD,DX_VEX|DX_IGNOREL,1,0x000000FF,0x000000C2,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("CMPSS\0",D_SSE|D_MUSTF3|D_SUSPICIOUS,0,2,0x0000FFFF,0x0000C20F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_CONST8,B_NONE]),
  AsmInstrDsc("VCMPSS\0",D_AVX|D_MUSTF3|D_SUSPICIOUS,DX_VEX|DX_IGNOREL,1,0x000000FF,0x000000C2,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_CONST8]),
  AsmInstrDsc("COMISD\0",D_SSE|D_MUST66|D_ALLFLAGS,0,2,0x0000FFFF,0x00002F0F,0x00,[B_SREGF64L,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VCOMISD\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002F,0x00,[B_SREGF64L,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("COMISS\0",D_SSE|D_MUSTNONE|D_ALLFLAGS,0,2,0x0000FFFF,0x00002F0F,0x00,[B_SREGF32L,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VCOMISS\0",D_AVX|D_MUSTNONE|D_ALLFLAGS,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002F,0x00,[B_SREGF32L,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("CVTDQ2PD\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000E60F,0x00,[B_SREGF64x2|B_CHG,B_SSEI32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTDQ2PD\0",D_AVX|D_MUSTF3|D_REGISTER,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x000000E6,0x00,[B_SREGF64x2|B_CHG,B_SSEI32x2L|B_REGISTER|B_NOVEXSIZE|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTDQ2PD\0",D_AVX|D_MUSTF3|D_MEMORY,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x000000E6,0x00,[B_SREGF64x2|B_CHG,B_SSEI32x2L|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CVTDQ2PS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00005B0F,0x00,[B_SREGF32x4|B_CHG,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTDQ2PS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000005B,0x00,[B_SREGF32x4|B_CHG,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPD2DQ\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000E60F,0x00,[B_SREGI32x2L|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTPD2DQ\0",D_AVX|D_MUSTF2,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x000000E6,0x00,[B_SREGI32x2L|B_NOVEXSIZE|B_CHG,B_SSEF64x2|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPD2PI\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00002D0F,0x00,[B_MREG32x2|B_SIGNED|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPD2PS\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00005A0F,0x00,[B_SREGF32x2L|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTPD2PS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000005A,0x00,[B_SREGF32x2L|B_NOVEXSIZE|B_CHG,B_SSEF64x2|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPI2PD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00002A0F,0x00,[B_SREGF64x2|B_CHG,B_MMX32x2|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPI2PS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00002A0F,0x00,[B_SREGF32x2L|B_CHG,B_MMX32x2|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPS2DQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00005B0F,0x00,[B_SREGI32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTPS2DQ\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000005B,0x00,[B_SREGI32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPS2PD\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00005A0F,0x00,[B_SREGF64x2|B_CHG,B_SSEF32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTPS2PD\0",D_AVX|D_MUSTNONE|D_REGISTER,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000005A,0x00,[B_SREGF64x2|B_CHG,B_SSEF32x2L|B_REGISTER|B_NOVEXSIZE|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTPS2PD\0",D_AVX|D_MUSTNONE|D_MEMORY,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000005A,0x00,[B_SREGF64x2|B_CHG,B_SSEF32x2L|B_MEMORY|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CVTPS2PI\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00002D0F,0x00,[B_MREG32x2|B_CHG,B_SSEF32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("CVTSD2SI\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00002D0F,0x00,[B_REG32|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTSD2SI\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002D,0x00,[B_REG32|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("CVTSD2SS\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00005A0F,0x00,[B_SREGF32L|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTSD2SS\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005A,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("CVTSI2SD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00002A0F,0x00,[B_SREGF64L|B_CHG,B_INT32|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTSI2SD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000002A,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_INT32|B_SIGNED,B_NONE]),
  AsmInstrDsc("CVTSI2SS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00002A0F,0x00,[B_SREGF32L|B_CHG,B_INT32|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTSI2SS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000002A,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_INT32|B_SIGNED,B_NONE]),
  AsmInstrDsc("CVTSS2SD\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00005A0F,0x00,[B_SREGF64L|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTSS2SD\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005A,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("CVTSS2SI\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00002D0F,0x00,[B_REG32|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTSS2SI\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002D,0x00,[B_REG32|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("CVTTPD2PI\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00002C0F,0x00,[B_MREG32x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("CVTTPD2DQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E60F,0x00,[B_SREGI32x2L|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTTPD2DQ\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x000000E6,0x00,[B_SREGI32x2L|B_NOVEXSIZE|B_CHG,B_SSEF64x2|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CVTTPS2DQ\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00005B0F,0x00,[B_SREGI32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTTPS2DQ\0",D_AVX|D_MUSTF3,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000005B,0x00,[B_SREGI32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("CVTTPS2PI\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00002C0F,0x00,[B_MREG32x2|B_CHG,B_SSEF32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("CVTTSD2SI\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00002C0F,0x00,[B_REG32|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTTSD2SI\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002C,0x00,[B_REG32|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("CVTTSS2SI\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00002C0F,0x00,[B_REG32|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTTSS2SI\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002C,0x00,[B_REG32|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("DIVPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00005E0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VDIVPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005E,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("DIVPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00005E0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VDIVPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005E,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("DIVSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00005E0F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VDIVSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005E,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("DIVSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00005E0F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VDIVSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005E,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("HADDPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00007C0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VHADDPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000007C,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("HADDPS\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00007C0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VHADDPS\0",D_AVX|D_MUSTF2,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000007C,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("HSUBPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00007D0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VHSUBPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000007D,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("HSUBPS\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00007D0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VHSUBPS\0",D_AVX|D_MUSTF2,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000007D,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("LDDQU\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000F00F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VLDDQU\0",D_AVX|D_MUSTF2,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x000000F0,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("LDMXCSR\0",D_CMD|D_MEMORY,0,2,0x0038FFFF,0x0010AE0F,0x00,[B_MXCSR|B_CHG|B_PSEUDO,B_INT32|B_BINARY|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VLDMXCSR\0",D_CMD|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000038FF,0x000010AE,0x00,[B_MXCSR|B_CHG|B_PSEUDO,B_INT32|B_BINARY|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VSTMXCSR\0",D_CMD|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000038FF,0x000018AE,0x00,[B_INT32|B_BINARY|B_MEMONLY|B_NOESP|B_SHOWSIZE|B_CHG,B_MXCSR|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("MASKMOVDQU\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00C0FFFF,0x00C0F70F,0x00,[B_SSEI8x16DI|B_UPD|B_PSEUDO,B_SREGI8x16|B_BINARY,B_SSEI8x16|B_REGISTER,B_NONE]),
  AsmInstrDsc("VMASKMOVDQU\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x0000C0FF,0x0000C0F7,0x00,[B_SSEI8x16DI|B_UPD|B_PSEUDO,B_SREGI8x16|B_BINARY,B_SSEI8x16|B_REGISTER,B_NONE]),
  AsmInstrDsc("MASKMOVQ\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00C0FFFF,0x00C0F70F,0x00,[B_MMX8x8DI|B_UPD|B_PSEUDO,B_MREG8x8,B_MMX8x8|B_REGISTER,B_NONE]),
  AsmInstrDsc("MAXPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00005F0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMAXPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005F,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("MAXPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00005F0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMAXPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005F,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("MAXSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00005F0F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMAXSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005F,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("MAXSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00005F0F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMAXSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005F,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("MFENCE\0",D_SSE,0,3,0x00FFFFFF,0x00F0AE0F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("MINPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00005D0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMINPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005D,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("MINPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00005D0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMINPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005D,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("MINSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00005D0F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMINSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005D,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("MINSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00005D0F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMINSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005D,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("MOVAPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000280F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVAPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000028,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVAPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000290F,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVAPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000029,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVAPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000280F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVAPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000028,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVAPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000290F,0x00,[B_SSEF32x4|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVAPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000029,0x00,[B_SSEF32x4|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x00006E0F,0x00,[B_MREG32x2|B_CHG,B_INT32,B_NONE,B_NONE]),
  AsmInstrDsc("MOVD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x00007E0F,0x00,[B_INT32|B_CHG,B_MREG32x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00006E0F,0x00,[B_SREGI32x2L|B_CHG,B_INT32,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x0000006E,0x00,[B_SREGI32x2L|B_CHG,B_INT32,B_NONE,B_NONE]),
  AsmInstrDsc("MOVD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00007E0F,0x00,[B_INT32|B_CHG,B_SREGI32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x0000007E,0x00,[B_INT32|B_CHG,B_SREGI32L,B_NONE,B_NONE]),
  AsmInstrDsc("MOVDDUP\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000120F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVDDUP\0",D_AVX|D_MUSTF2,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000012,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVDQA\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00006F0F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVDQA\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000006F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVDQA\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00007F0F,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVDQA\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000007F,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVDQU\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00006F0F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVDQU\0",D_AVX|D_MUSTF3,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000006F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVDQU\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00007F0F,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVDQU\0",D_AVX|D_MUSTF3,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000007F,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVDQ2Q\0",D_MMX|D_MUSTF2|D_REGISTER,0,2,0x00C0FFFF,0x00C0D60F,0x00,[B_MREG32x2|B_CHG,B_SSEI32x2L|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("MOVHLPS\0",D_SSE|D_MUSTNONE|D_REGISTER,0,2,0x00C0FFFF,0x00C0120F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVHLPS\0",D_AVX|D_MUSTNONE|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000C0FF,0x0000C012,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4|B_REGISTER,B_NONE]),
  AsmInstrDsc("MOVHPD\0",D_SSE|D_MUST66|D_MEMORY,0,2,0x0000FFFF,0x0000160F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64L|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVHPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000016,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64L|B_MEMORY,B_NONE]),
  AsmInstrDsc("MOVHPD\0",D_SSE|D_MUST66|D_MEMORY,0,2,0x0000FFFF,0x0000170F,0x00,[B_SSEF64L|B_MEMORY|B_UPD,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVHPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000017,0x00,[B_SSEF64L|B_MEMORY|B_UPD,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVHPS\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x0000160F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x2L|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVHPS\0",D_AVX|D_MUSTNONE|D_MEMORY,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000016,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x2L|B_MEMORY,B_NONE]),
  AsmInstrDsc("MOVHPS\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x0000170F,0x00,[B_SSEF32x2L|B_MEMORY|B_UPD,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVHPS\0",D_AVX|D_MUSTNONE|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000017,0x00,[B_SSEF32x2L|B_MEMORY|B_UPD,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVLHPS\0",D_SSE|D_MUSTNONE|D_REGISTER,0,2,0x00C0FFFF,0x00C0160F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x2L|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVLHPS\0",D_AVX|D_MUSTNONE|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000C0FF,0x0000C016,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x2L|B_REGISTER,B_NONE]),
  AsmInstrDsc("MOVLPD\0",D_SSE|D_MUST66|D_MEMORY,0,2,0x0000FFFF,0x0000120F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVLPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000012,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64L|B_MEMORY,B_NONE]),
  AsmInstrDsc("MOVLPD\0",D_SSE|D_MUST66|D_MEMORY,0,2,0x0000FFFF,0x0000130F,0x00,[B_SSEF64L|B_MEMORY|B_UPD,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVLPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000013,0x00,[B_SSEF64L|B_MEMORY|B_UPD,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("MOVLPS\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x0000120F,0x00,[B_SREGF32x2L|B_UPD,B_SSEF32x2L|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVLPS\0",D_AVX|D_MUSTNONE|D_MEMORY,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000012,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x2L|B_MEMORY,B_NONE]),
  AsmInstrDsc("MOVLPS\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x0000130F,0x00,[B_SSEF32x2L|B_MEMORY|B_UPD,B_SREGF32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVLPS\0",D_AVX|D_MUSTNONE|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000013,0x00,[B_SSEF32x2L|B_MEMORY|B_UPD,B_SREGF32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("MOVMSKPD\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00C0FFFF,0x00C0500F,0x00,[B_REG32|B_CHG,B_SSEF64x2|B_REGONLY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVMSKPD\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x0000C0FF,0x0000C050,0x00,[B_REG32|B_CHG,B_SSEF64x2|B_REGONLY,B_NONE,B_NONE]),
  AsmInstrDsc("MOVMSKPS\0",D_SSE|D_MUSTNONE|D_REGISTER,0,2,0x00C0FFFF,0x00C0500F,0x00,[B_REG32|B_CHG,B_SSEF32x4|B_REGONLY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVMSKPS\0",D_AVX|D_MUSTNONE|D_REGISTER,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x0000C0FF,0x0000C050,0x00,[B_REG32|B_CHG,B_SSEF32x4|B_REGONLY,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTDQ\0",D_SSE|D_MUST66|D_MEMORY,0,2,0x0000FFFF,0x0000E70F,0x00,[B_SSEI8x16|B_MEMORY|B_CHG,B_SREGI8x16|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVNTDQ\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x000000E7,0x00,[B_SSEI8x16|B_MEMORY|B_CHG,B_SREGI8x16|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTI\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x0000C30F,0x00,[B_INT32|B_MEMORY|B_CHG,B_REG32,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTPD\0",D_SSE|D_MUST66|D_MEMORY,0,2,0x0000FFFF,0x00002B0F,0x00,[B_SSEF64x2|B_MEMORY|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVNTPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000002B,0x00,[B_SSEF64x2|B_MEMORY|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTPS\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x00002B0F,0x00,[B_SSEF32x4|B_MEMORY|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVNTPS\0",D_AVX|D_MUSTNONE|D_MEMORY,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x0000002B,0x00,[B_SSEF32x4|B_MEMORY|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTQ\0",D_MMX|D_MUSTNONE|D_MEMORY,0,2,0x0000FFFF,0x0000E70F,0x00,[B_MMX64|B_MEMORY|B_CHG,B_MREG64,B_NONE,B_NONE]),
  AsmInstrDsc("MOVQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x00006F0F,0x00,[B_MREG64|B_CHG,B_MMX64,B_NONE,B_NONE]),
  AsmInstrDsc("MOVQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x00007F0F,0x00,[B_MMX64|B_CHG,B_MREG64,B_NONE,B_NONE]),
  AsmInstrDsc("MOVQ\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00007E0F,0x00,[B_SREGF64L|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVQ\0",D_AVX|D_MUSTF3,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x0000007E,0x00,[B_SREGF64L|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("MOVQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D60F,0x00,[B_SSEF64L|B_CHG,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x000000D6,0x00,[B_SSEF64L|B_CHG,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("MOVQ2DQ\0",D_MMX|D_MUSTF3|D_REGISTER,0,2,0x00C0FFFF,0x00C0D60F,0x00,[B_SREGF64L|B_UPD,B_MMX8x8|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("MOVSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000100F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSD\0",D_AVX|D_MUSTF2|D_MEMORY,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x00000010,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSD\0",D_AVX|D_MUSTF2|D_REGISTER,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000010,0x00,[B_SREGF64L|B_UPD,B_SVEXF64x2,B_SSEF64L,B_NONE]),
  AsmInstrDsc("MOVSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000110F,0x00,[B_SSEF64L|B_UPD,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSD\0",D_AVX|D_MUSTF2|D_MEMORY,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x00000011,0x00,[B_SSEF64L|B_UPD,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSD\0",D_AVX|D_MUSTF2|D_REGISTER,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000011,0x00,[B_SSEF64L|B_UPD,B_SVEXF64x2,B_SREGF64L,B_NONE]),
  AsmInstrDsc("MOVSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000100F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSS\0",D_AVX|D_MUSTF3|D_MEMORY,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x00000010,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSS\0",D_AVX|D_MUSTF3|D_REGISTER,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000010,0x00,[B_SREGF32L|B_UPD,B_SVEXF32x4,B_SSEF32L,B_NONE]),
  AsmInstrDsc("MOVSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000110F,0x00,[B_SSEF32L|B_UPD,B_SREGF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSS\0",D_AVX|D_MUSTF3|D_MEMORY,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x00000011,0x00,[B_SSEF32L|B_UPD,B_SREGF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSS\0",D_AVX|D_MUSTF3|D_REGISTER,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000011,0x00,[B_SSEF32L|B_UPD,B_SVEXF32x4,B_SREGF32L,B_NONE]),
  AsmInstrDsc("MOVSHDUP\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000160F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSHDUP\0",D_AVX|D_MUSTF3,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000016,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVSLDUP\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000120F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVSLDUP\0",D_AVX|D_MUSTF3,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000012,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVUPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000100F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVUPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000010,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVUPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000110F,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVUPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000011,0x00,[B_SSEF64x2|B_CHG,B_SREGF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("MOVUPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000100F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVUPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000010,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MOVUPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000110F,0x00,[B_SSEF32x4|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVUPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000011,0x00,[B_SSEF32x4|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("MULPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000590F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VMULPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000059,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("MULPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000590F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VMULPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000059,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("MULSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000590F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VMULSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000059,0x00,[B_SREGF64L|B_UPD,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("MULSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000590F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VMULSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000059,0x00,[B_SREGF32L|B_UPD,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("ORPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000560F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VORPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000056,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("ORPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000560F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VORPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000056,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("PACKSSWB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000630F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PACKSSWB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000630F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPACKSSWB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000063,0x00,[B_SREGI8x16|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PACKSSDW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x00006B0F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PACKSSDW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00006B0F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPACKSSDW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x0000006B,0x00,[B_SREGI16x8|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PACKUSWB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000670F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PACKUSWB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000670F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPACKUSWB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000067,0x00,[B_SREGI8x16|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PADDB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000FC0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PADDW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000FD0F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PADDD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000FE0F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PADDB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000FC0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000FC,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PADDW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000FD0F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000FD,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PADDD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000FE0F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000FE,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PADDQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D40F,0x00,[B_MREG64|B_UPD,B_MMX64,B_NONE,B_NONE]),
  AsmInstrDsc("PADDQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D40F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D4,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PADDSB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000EC0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PADDSW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000ED0F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PADDSB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000EC0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000EC,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PADDSW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000ED0F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000ED,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PADDUSB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000DC0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PADDUSW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000DD0F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PADDUSB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000DC0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDUSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000DC,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PADDUSW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000DD0F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPADDUSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000DD,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PAND\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000DB0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PAND\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000DB0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPAND\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000DB,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PANDN\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000DF0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PANDN\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000DF0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPANDN\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000DF,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PAVGB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E00F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PAVGW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E30F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PAVGB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E00F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPAVGB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E0,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PAVGW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E30F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPAVGW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E3,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PCMPEQB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000740F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PCMPEQW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000750F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PCMPEQD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000760F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PCMPEQB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000740F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPEQB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000074,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PCMPEQW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000750F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPEQW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000075,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PCMPEQD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000760F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPEQD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000076,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PCMPGTB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000640F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PCMPGTW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000650F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PCMPGTD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000660F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PCMPGTB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000640F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPGTB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000064,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PCMPGTW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000650F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPGTW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000065,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PCMPGTD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000660F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPGTD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000066,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PEXTRW\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00C0FFFF,0x00C0C50F,0x00,[B_REG32|B_CHG,B_MMX16x4|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PEXTRW\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00C0FFFF,0x00C0C50F,0x00,[B_REG32|B_CHG,B_SSEI16x8|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("VPEXTRW\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x0000C0FF,0x0000C0C5,0x00,[B_REG32|B_CHG,B_SSEI16x8|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PINSRW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000C40F,0x00,[B_MREG16x4|B_UPD,B_INT16,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PINSRW\0",D_MMX|D_MUSTNONE,0,2,0x00C0FFFF,0x00C0C40F,0x00,[B_MREG16x4|B_UPD,B_INT32|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PINSRW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000C40F,0x00,[B_SREGI16x8|B_UPD,B_INT16,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("VPINSRW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000C4,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_INT16,B_CONST8|B_COUNT]),
  AsmInstrDsc("PINSRW\0",D_SSE|D_MUST66,0,2,0x00C0FFFF,0x00C0C40F,0x00,[B_SREGI16x8|B_UPD,B_INT32|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("VPINSRW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x0000C0FF,0x0000C0C4,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_INT32|B_REGISTER,B_CONST8|B_COUNT]),
  AsmInstrDsc("PMADDWD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F50F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMADDWD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F50F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMADDWD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F5,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMAXSW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000EE0F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMAXSW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000EE0F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMAXSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000EE,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMAXUB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000DE0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PMAXUB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000DE0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPMAXUB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000DE,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PMINSW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000EA0F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMINSW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000EA0F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMINSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000EA,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMINUB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000DA0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PMINUB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000DA0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPMINUB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000DA,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PMOVMSKB\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00C0FFFF,0x00C0D70F,0x00,[B_REG32|B_CHG,B_MMX8x8|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVMSKB\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00C0FFFF,0x00C0D70F,0x00,[B_REG32|B_CHG,B_SSEI8x16|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVMSKB\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x0000C0FF,0x0000C0D7,0x00,[B_REG32|B_CHG,B_SSEI8x16|B_REGISTER,B_NONE,B_NONE]),
  AsmInstrDsc("PMULHUW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E40F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMULHUW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E40F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULHUW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E4,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMULHW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E50F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMULHW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E50F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULHW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E5,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMULLW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D50F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMULLW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D50F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULLW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D5,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMULUDQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F40F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PMULUDQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F40F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULUDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F4,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("POR\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000EB0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("POR\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000EB0F,0x00,[B_SREGI8x16|B_BINARY|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPOR\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000EB,0x00,[B_SREGI8x16|B_BINARY|B_UPD,B_SVEXI8x16|B_BINARY,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PSADBW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F60F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PSADBW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F60F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPSADBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F6,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PSHUFD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000700F,0x00,[B_SREGI32x4|B_CHG,B_SSEI32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPSHUFD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000070,0x00,[B_SREGI32x4|B_CHG,B_SSEI32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PSHUFHW\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000700F,0x00,[B_SREGI16x8|B_CHG,B_SSEI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPSHUFHW\0",D_AVX|D_MUSTF3,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000070,0x00,[B_SREGI16x8|B_CHG,B_SSEI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PSHUFLW\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000700F,0x00,[B_SREGI16x8|B_CHG,B_SSEI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPSHUFLW\0",D_AVX|D_MUSTF2,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000070,0x00,[B_SREGI16x8|B_CHG,B_SSEI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PSHUFW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000700F,0x00,[B_MREG16x4|B_CHG,B_MMX16x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PSLLDQ\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00F8730F,0x00,[B_SSEI8x16|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLDQ\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000F873,0x00,[B_SVEXI8x16|B_UPD,B_SSEI8x16|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSLLW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F10F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSLLW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F10F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F1,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PSLLW\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00F0710F,0x00,[B_MMX16x4|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSLLW\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00F0710F,0x00,[B_SSEI16x8|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLW\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000F071,0x00,[B_SVEXI16x8|B_UPD,B_SSEI16x8|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSLLD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F20F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PSLLD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F20F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F2,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PSLLD\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00F0720F,0x00,[B_MMX32x2|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSLLD\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00F0720F,0x00,[B_SSEI32x4|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLD\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000F072,0x00,[B_SVEXI32x4|B_UPD,B_SSEI32x4|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSLLQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F30F,0x00,[B_MREG64|B_UPD,B_MMX64,B_NONE,B_NONE]),
  AsmInstrDsc("PSLLQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F30F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F3,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PSLLQ\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00F0730F,0x00,[B_MMX64|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSLLQ\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00F0730F,0x00,[B_SSEI64x2|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSLLQ\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000F073,0x00,[B_SVEXI64x2|B_UPD,B_SSEI64x2|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSRAW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E10F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSRAW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E10F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRAW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E1,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PSRAW\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00E0710F,0x00,[B_MMX16x4|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSRAW\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00E0710F,0x00,[B_SSEI16x8|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRAW\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000E071,0x00,[B_SVEXI16x8|B_UPD,B_SSEI16x8|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSRAD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E20F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PSRAD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E20F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRAD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E2,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PSRAD\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00E0720F,0x00,[B_MMX32x2|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSRAD\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00E0720F,0x00,[B_SSEI32x4|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRAD\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000E072,0x00,[B_SVEXI32x4|B_UPD,B_SSEI32x4|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSRLDQ\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00D8730F,0x00,[B_SSEI8x16|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLDQ\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000D873,0x00,[B_SVEXI8x16|B_UPD,B_SSEI8x16|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSRLW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D10F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSRLW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D10F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D1,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PSRLW\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00D0710F,0x00,[B_MMX16x4|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSRLW\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00D0710F,0x00,[B_SSEI16x8|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLW\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000D071,0x00,[B_SVEXI16x8|B_UPD,B_SSEI16x8|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSRLD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D20F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PSRLD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D20F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D2,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PSRLD\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00D0720F,0x00,[B_MMX32x2|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSRLD\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00D0720F,0x00,[B_SSEI32x4|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLD\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000D072,0x00,[B_SVEXI32x4|B_UPD,B_SSEI32x4|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSRLQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D30F,0x00,[B_MREG64|B_UPD,B_MMX64,B_NONE,B_NONE]),
  AsmInstrDsc("PSRLQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D30F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D3,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PSRLQ\0",D_MMX|D_MUSTNONE|D_REGISTER,0,2,0x00F8FFFF,0x00D0730F,0x00,[B_MMX64|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("PSRLQ\0",D_SSE|D_MUST66|D_REGISTER,0,2,0x00F8FFFF,0x00D0730F,0x00,[B_SSEI64x2|B_REGISTER|B_UPD,B_CONST8|B_COUNT,B_NONE,B_NONE]),
  AsmInstrDsc("VPSRLQ\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT,1,0x0000F8FF,0x0000D073,0x00,[B_SVEXI64x2|B_UPD,B_SSEI64x2|B_REGISTER,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("PSUBB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F80F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000F90F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000FA0F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F80F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F8,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PSUBW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000F90F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000F9,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PSUBD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000FA0F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000FA,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PSUBQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000FB0F,0x00,[B_MREG64|B_UPD,B_MMX64,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000FB0F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000FB,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PSUBSB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E80F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBSW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000E90F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBSB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E80F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E8,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PSUBSW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000E90F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000E9,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PSUBUSB\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D80F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBUSW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000D90F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSUBUSB\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D80F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBUSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D8,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PSUBUSW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000D90F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPSUBUSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000D9,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PUNPCKHBW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000680F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PUNPCKHBW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000680F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKHBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000068,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PUNPCKHWD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000690F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PUNPCKHWD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000690F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKHWD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000069,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PUNPCKHDQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x00006A0F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PUNPCKHDQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00006A0F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKHDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x0000006A,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PUNPCKHQDQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00006D0F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKHQDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x0000006D,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PUNPCKLBW\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000600F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PUNPCKLBW\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000600F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKLBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000060,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("PUNPCKLWD\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000610F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PUNPCKLWD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000610F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKLWD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000061,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PUNPCKLDQ\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000620F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PUNPCKLDQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000620F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKLDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x00000062,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PUNPCKLQDQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00006C0F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPUNPCKLQDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x0000006C,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PXOR\0",D_MMX|D_MUSTNONE,0,2,0x0000FFFF,0x0000EF0F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PXOR\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000EF0F,0x00,[B_SREGI8x16|B_BINARY|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VPXOR\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT,1,0x000000FF,0x000000EF,0x00,[B_SREGI8x16|B_BINARY|B_UPD,B_SVEXI8x16|B_BINARY,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("RCPPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000530F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VRCPPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000053,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("RCPSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000530F,0x00,[B_SREGF32L|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VRCPSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000053,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L|B_CHG,B_SSEF32L,B_NONE]),
  AsmInstrDsc("RSQRTPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000520F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VRSQRTPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000052,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("RSQRTSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000520F,0x00,[B_SREGF32L|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VRSQRTSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000052,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("SHUFPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000C60F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VSHUFPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000C6,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_CONST8|B_BINARY]),
  AsmInstrDsc("SHUFPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000C60F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VSHUFPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x000000C6,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_CONST8|B_BINARY]),
  AsmInstrDsc("SQRTPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000510F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VSQRTPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000051,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("SQRTPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000510F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VSQRTPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH|DX_NOVREG,1,0x000000FF,0x00000051,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("SQRTSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000510F,0x00,[B_SREGF64L|B_CHG,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VSQRTSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000051,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("SQRTSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x0000510F,0x00,[B_SREGF32L|B_CHG,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VSQRTSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x00000051,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("SUBPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x00005C0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VSUBPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005C,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("SUBPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x00005C0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VSUBPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x0000005C,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("SUBSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00005C0F,0x00,[B_SREGF64L|B_UPD,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VSUBSD\0",D_AVX|D_MUSTF2,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005C,0x00,[B_SREGF64L|B_UPD,B_SVEXF64L,B_SSEF64L,B_NONE]),
  AsmInstrDsc("SUBSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00005C0F,0x00,[B_SREGF32L|B_UPD,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VSUBSS\0",D_AVX|D_MUSTF3,DX_VEX|DX_IGNOREL,1,0x000000FF,0x0000005C,0x00,[B_SREGF32L|B_UPD,B_SVEXF32L,B_SSEF32L,B_NONE]),
  AsmInstrDsc("UNPCKHPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000150F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VUNPCKHPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000015,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("UNPCKHPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000150F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VUNPCKHPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000015,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("UNPCKLPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000140F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VUNPCKLPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000014,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("UNPCKLPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000140F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VUNPCKLPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000014,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("UCOMISD\0",D_SSE|D_MUST66|D_ALLFLAGS,0,2,0x0000FFFF,0x00002E0F,0x00,[B_SREGF64L,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("VUCOMISD\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002E,0x00,[B_SREGF64L,B_SSEF64L,B_NONE,B_NONE]),
  AsmInstrDsc("UCOMISS\0",D_SSE|D_MUSTNONE|D_ALLFLAGS,0,2,0x0000FFFF,0x00002E0F,0x00,[B_SREGF32L,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("VUCOMISS\0",D_AVX|D_MUSTNONE|D_ALLFLAGS,DX_VEX|DX_IGNOREL|DX_NOVREG,1,0x000000FF,0x0000002E,0x00,[B_SREGF32L,B_SSEF32L,B_NONE,B_NONE]),
  AsmInstrDsc("XORPD\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000570F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VXORPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000057,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_NONE]),
  AsmInstrDsc("XORPS\0",D_SSE|D_MUSTNONE,0,2,0x0000FFFF,0x0000570F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VXORPS\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LBOTH,1,0x000000FF,0x00000057,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_NONE]),
  AsmInstrDsc("FXRSTOR\0",D_SSE|D_MEMORY,0,2,0x0038FFFF,0x0008AE0F,0x00,[B_LONGDATA|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FXSAVE\0",D_SSE|D_MEMORY,0,2,0x0038FFFF,0x0000AE0F,0x00,[B_LONGDATA|B_MEMORY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("LFENCE\0",D_SSE,0,3,0x00FFFFFF,0x00E8AE0F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PREFETCHT0\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0038FFFF,0x0008180F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PREFETCHT1\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0038FFFF,0x0010180F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PREFETCHT2\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0038FFFF,0x0018180F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PREFETCHNTA\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0038FFFF,0x0000180F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("NOP\0",D_SSE|D_MUSTNONE|D_MEMORY|D_UNDOC,DX_NOP,2,0x0020FFFF,0x0020180F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PREFETCH\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0038FFFF,0x00000D0F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PREFETCHW\0",D_SSE|D_MUSTNONE|D_MEMORY,0,2,0x0038FFFF,0x00080D0F,0x00,[B_ANYMEM|B_MEMORY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SFENCE\0",D_SSE,0,3,0x00FFFFFF,0x00F8AE0F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("BLENDPD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000D3A0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VBLENDPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_LEAD3A,1,0x000000FF,0x0000000D,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_CONST8|B_BINARY]),
  AsmInstrDsc("BLENDPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000C3A0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VBLENDPS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_LEAD3A,1,0x000000FF,0x0000000C,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_CONST8|B_BINARY]),
  AsmInstrDsc("BLENDVPD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0015380F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_XMM0I64x2,B_NONE]),
  AsmInstrDsc("BLENDVPD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0015380F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_XMM0I64x2|B_PSEUDO,B_NONE]),
  AsmInstrDsc("VBLENDVPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD3A,1,0x000000FF,0x0000004B,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_SIMMI8x16]),
  AsmInstrDsc("BLENDVPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0014380F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_XMM0I32x4,B_NONE]),
  AsmInstrDsc("BLENDVPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0014380F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_XMM0I32x4|B_PSEUDO,B_NONE]),
  AsmInstrDsc("VBLENDVPS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD3A,1,0x000000FF,0x0000004A,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_SIMMI8x16]),
  AsmInstrDsc("CRC32\0",D_CMD|D_NEEDF2,0,3,0x00FFFFFF,0x00F0380F,0x00,[B_REG32|B_NOADDR|B_UPD,B_INT8|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("CRC32\0",D_CMD|D_NEEDF2,0,3,0x00FFFFFF,0x00F1380F,0x00,[B_REG32|B_NOADDR|B_UPD,B_INT1632|B_NOADDR|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("DPPD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00413A0F,0x00,[B_SREGF64x2|B_UPD,B_SSEF64x2,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VDPPD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000041,0x00,[B_SREGF64x2|B_UPD,B_SVEXF64x2,B_SSEF64x2,B_CONST8|B_BINARY]),
  AsmInstrDsc("DPPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00403A0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VDPPS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_LEAD3A,1,0x000000FF,0x00000040,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32x4,B_CONST8|B_BINARY]),
  AsmInstrDsc("EXTRACTPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00173A0F,0x00,[B_INT32|B_CHG,B_SREGF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VEXTRACTPS\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000017,0x00,[B_INT32|B_CHG,B_SREGF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("INSERTPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00213A0F,0x00,[B_SREGF32x4|B_UPD,B_SSEF32L,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VINSERTPS\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000021,0x00,[B_SREGF32x4|B_UPD,B_SVEXF32x4,B_SSEF32L,B_CONST8|B_BINARY]),
  AsmInstrDsc("MOVNTDQA\0",D_SSE|D_MUST66|D_MEMORY,0,3,0x00FFFFFF,0x002A380F,0x00,[B_SREGI8x16|B_BINARY|B_CHG,B_SSEI8x16|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VMOVNTDQA\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x0000002A,0x00,[B_SREGI8x16|B_BINARY|B_CHG,B_SSEI8x16|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("MPSADBW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00423A0F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VMPSADBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000042,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_CONST8|B_BINARY]),
  AsmInstrDsc("PACKUSDW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x002B380F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPACKUSDW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000002B,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4|B_UPD,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PBLENDVB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0010380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_XMM0I8x16,B_NONE]),
  AsmInstrDsc("PBLENDVB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0010380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_XMM0I8x16|B_PSEUDO,B_NONE]),
  AsmInstrDsc("VPBLENDVB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_W0|DX_LEAD3A,1,0x000000FF,0x0000004C,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16,B_SIMMI8x16]),
  AsmInstrDsc("PBLENDW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000E3A0F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPBLENDW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x0000000E,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_CONST8|B_BINARY]),
  AsmInstrDsc("PCLMULLQLQDQ\0",D_SSE|D_POSTBYTE|D_MUST66,0,3,0x00FFFFFF,0x00443A0F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPCLMULLQLQDQ\0",D_AVX|D_POSTBYTE|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000044,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PCLMULHQLQDQ\0",D_SSE|D_POSTBYTE|D_MUST66,0,3,0x00FFFFFF,0x00443A0F,0x01,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPCLMULHQLQDQ\0",D_AVX|D_POSTBYTE|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000044,0x01,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PCLMULLQHDQ\0",D_SSE|D_POSTBYTE|D_MUST66,0,3,0x00FFFFFF,0x00443A0F,0x10,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPCLMULLQHDQ\0",D_AVX|D_POSTBYTE|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000044,0x10,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PCLMULHQHDQ\0",D_SSE|D_POSTBYTE|D_MUST66,0,3,0x00FFFFFF,0x00443A0F,0x11,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPCLMULHQHDQ\0",D_AVX|D_POSTBYTE|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000044,0x11,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PCLMULQDQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00443A0F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPCLMULQDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x00000044,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_CONST8|B_BINARY]),
  AsmInstrDsc("PCMPEQQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0029380F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPEQQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000029,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PCMPESTRI\0",D_SSE|D_MUST66|D_ALLFLAGS,0,3,0x00FFFFFF,0x00613A0F,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPCMPESTRI\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000061,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PCMPESTRM\0",D_SSE|D_MUST66|D_ALLFLAGS,0,3,0x00FFFFFF,0x00603A0F,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPCMPESTRM\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000060,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PCMPISTRI\0",D_SSE|D_MUST66|D_ALLFLAGS,0,3,0x00FFFFFF,0x00633A0F,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPCMPISTRI\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000063,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PCMPISTRM\0",D_SSE|D_MUST66|D_ALLFLAGS,0,3,0x00FFFFFF,0x00623A0F,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPCMPISTRM\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000062,0x00,[B_SREGI8x16,B_SSEI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PCMPGTQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0037380F,0x00,[B_SREGI64x2|B_UPD,B_SSEI64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VPCMPGTQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000037,0x00,[B_SREGI64x2|B_UPD,B_SVEXI64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("PEXTRB\0",D_SSE|D_MUST66|D_MEMORY,0,3,0x00FFFFFF,0x00143A0F,0x00,[B_INT8|B_MEMORY|B_CHG,B_SREGI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PEXTRB\0",D_SSE|D_MUST66|D_REGISTER,0,3,0x00FFFFFF,0x00143A0F,0x00,[B_INT32|B_REGISTER|B_CHG,B_SREGI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPEXTRB\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT|DX_NOVREG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000014,0x00,[B_INT8|B_MEMORY|B_CHG,B_SREGI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPEXTRB\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT|DX_NOVREG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000014,0x00,[B_INT32|B_REGISTER|B_CHG,B_SREGI8x16,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PEXTRD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00163A0F,0x00,[B_INT32|B_CHG,B_SREGI32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPEXTRD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000016,0x00,[B_INT32|B_CHG,B_SREGI32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PEXTRW\0",D_SSE|D_MUST66|D_MEMORY,0,3,0x00FFFFFF,0x00153A0F,0x00,[B_INT16|B_MEMORY|B_CHG,B_SREGI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PEXTRW\0",D_SSE|D_MUST66|D_REGISTER,0,3,0x00FFFFFF,0x00153A0F,0x00,[B_INT32|B_REGISTER|B_CHG,B_SREGI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPEXTRW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000015,0x00,[B_INT16|B_CHG,B_SREGI16x8,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("PHMINPOSUW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0041380F,0x00,[B_SREGI16x8|B_CHG,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPHMINPOSUW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000041,0x00,[B_SREGI16x8|B_CHG,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("PINSRB\0",D_SSE|D_MUST66|D_MEMORY,0,3,0x00FFFFFF,0x00203A0F,0x00,[B_SREGI8x16|B_UPD,B_INT8|B_MEMORY,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPINSRB\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LSHORT|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000020,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_INT8|B_MEMORY,B_CONST8|B_BINARY]),
  AsmInstrDsc("PINSRB\0",D_SSE|D_MUST66|D_REGISTER,0,3,0x00FFFFFF,0x00203A0F,0x00,[B_SREGI8x16|B_UPD,B_INT32|B_REGISTER,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPINSRB\0",D_AVX|D_MUST66|D_REGISTER,DX_VEX|DX_LSHORT|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000020,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_INT32|B_REGISTER,B_CONST8|B_BINARY]),
  AsmInstrDsc("PINSRD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00223A0F,0x00,[B_SREGI32x4|B_UPD,B_INT32,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VPINSRD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000022,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_INT32,B_CONST8|B_BINARY]),
  AsmInstrDsc("PMAXSB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x003C380F,0x00,[B_SREGI8x16|B_SIGNED|B_UPD,B_SSEI8x16|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMAXSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000003C,0x00,[B_SREGI8x16|B_SIGNED|B_UPD,B_SVEXI8x16|B_SIGNED,B_SSEI8x16|B_SIGNED,B_NONE]),
  AsmInstrDsc("PMAXSD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x003D380F,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMAXSD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000003D,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SVEXI32x4|B_SIGNED,B_SSEI32x4|B_SIGNED,B_NONE]),
  AsmInstrDsc("PMAXUD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x003F380F,0x00,[B_SREGI32x4|B_UNSIGNED|B_UPD,B_SSEI32x4|B_UNSIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMAXUD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000003F,0x00,[B_SREGI32x4|B_UNSIGNED|B_UPD,B_SVEXI32x4|B_UNSIGNED,B_SSEI32x4|B_UNSIGNED,B_NONE]),
  AsmInstrDsc("PMAXUW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x003E380F,0x00,[B_SREGI16x8|B_UNSIGNED|B_UPD,B_SSEI16x8|B_UNSIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMAXUW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000003E,0x00,[B_SREGI16x8|B_UNSIGNED|B_UPD,B_SVEXI16x8|B_UNSIGNED,B_SSEI16x8|B_UNSIGNED,B_NONE]),
  AsmInstrDsc("PMINSB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0038380F,0x00,[B_SREGI8x16|B_SIGNED|B_UPD,B_SSEI8x16|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMINSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000038,0x00,[B_SREGI8x16|B_SIGNED|B_UPD,B_SVEXI8x16|B_SIGNED,B_SSEI8x16|B_SIGNED,B_NONE]),
  AsmInstrDsc("PMINSD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0039380F,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMINSD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000039,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SVEXI32x4|B_SIGNED,B_SSEI32x4|B_SIGNED,B_NONE]),
  AsmInstrDsc("PMINUD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x003B380F,0x00,[B_SREGI32x4|B_UNSIGNED|B_UPD,B_SSEI32x4|B_UNSIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMINUD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000003B,0x00,[B_SREGI32x4|B_UNSIGNED|B_UPD,B_SVEXI32x4|B_UNSIGNED,B_SSEI32x4|B_UNSIGNED,B_NONE]),
  AsmInstrDsc("PMINUW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x003A380F,0x00,[B_SREGI16x8|B_UNSIGNED|B_UPD,B_SSEI16x8|B_UNSIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMINUW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000003A,0x00,[B_SREGI16x8|B_UNSIGNED|B_UPD,B_SVEXI16x8|B_UNSIGNED,B_SSEI16x8|B_UNSIGNED,B_NONE]),
  AsmInstrDsc("PMOVSXBW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0020380F,0x00,[B_SREGI16x8|B_SIGNED|B_CHG,B_SSEI8x8L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVSXBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000020,0x00,[B_SREGI16x8|B_SIGNED|B_CHG,B_SSEI8x8L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVSXBD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0021380F,0x00,[B_SREGI32x4|B_SIGNED|B_CHG,B_SSEI8x4L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVSXBD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000021,0x00,[B_SREGI32x4|B_SIGNED|B_CHG,B_SSEI8x4L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVSXBQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0022380F,0x00,[B_SREGI64x2|B_SIGNED|B_CHG,B_SSEI8x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVSXBQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000022,0x00,[B_SREGI64x2|B_SIGNED|B_CHG,B_SSEI8x2L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVSXWD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0023380F,0x00,[B_SREGI32x4|B_SIGNED|B_CHG,B_SSEI16x4L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVSXWD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000023,0x00,[B_SREGI32x4|B_SIGNED|B_CHG,B_SSEI16x4L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVSXWQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0024380F,0x00,[B_SREGI64x2|B_SIGNED|B_CHG,B_SSEI16x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVSXWQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000024,0x00,[B_SREGI64x2|B_SIGNED|B_CHG,B_SSEI16x2L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVSXDQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0025380F,0x00,[B_SREGI64x2|B_SIGNED|B_CHG,B_SSEI32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVSXDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000025,0x00,[B_SREGI64x2|B_SIGNED|B_CHG,B_SSEI32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVZXBW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0030380F,0x00,[B_SREGI16x8|B_CHG,B_SSEI8x8L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVZXBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000030,0x00,[B_SREGI16x8|B_CHG,B_SSEI8x8L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVZXBD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0031380F,0x00,[B_SREGI32x4|B_CHG,B_SSEI8x4L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVZXBD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000031,0x00,[B_SREGI32x4|B_CHG,B_SSEI8x4L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVZXBQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0032380F,0x00,[B_SREGI64x2|B_CHG,B_SSEI8x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVZXBQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000032,0x00,[B_SREGI64x2|B_CHG,B_SSEI8x2L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVZXWD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0033380F,0x00,[B_SREGI32x4|B_CHG,B_SSEI16x4L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVZXWD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000033,0x00,[B_SREGI32x4|B_CHG,B_SSEI16x4L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVZXWQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0034380F,0x00,[B_SREGI64x2|B_CHG,B_SSEI16x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVZXWQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000034,0x00,[B_SREGI64x2|B_CHG,B_SSEI16x2L,B_NONE,B_NONE]),
  AsmInstrDsc("PMOVZXDQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0035380F,0x00,[B_SREGI64x2|B_CHG,B_SSEI32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("VPMOVZXDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000035,0x00,[B_SREGI64x2|B_CHG,B_SSEI32x2L,B_NONE,B_NONE]),
  AsmInstrDsc("PMULDQ\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0028380F,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULDQ\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000028,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SVEXI32x4|B_SIGNED,B_SSEI32x4|B_SIGNED,B_NONE]),
  AsmInstrDsc("PMULLD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0040380F,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULLD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000040,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SVEXI32x4|B_SIGNED,B_SSEI32x4|B_SIGNED,B_NONE]),
  AsmInstrDsc("PTEST\0",D_SSE|D_MUST66|D_ALLFLAGS,0,3,0x00FFFFFF,0x0017380F,0x00,[B_SREGI32x4,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPTEST\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LBOTH|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x00000017,0x00,[B_SREGI32x4,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("ROUNDPD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00093A0F,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VROUNDPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000009,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("ROUNDPS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00083A0F,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VROUNDPS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x00000008,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("ROUNDSD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000B3A0F,0x00,[B_SREGF64L|B_CHG,B_SSEF64L,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VROUNDSD\0",D_AVX|D_MUST66,DX_VEX|DX_IGNOREL|DX_LEAD3A,1,0x000000FF,0x0000000B,0x00,[B_SREGF64L|B_CHG,B_SVEXF64L,B_SSEF64L,B_CONST8|B_BINARY]),
  AsmInstrDsc("ROUNDSS\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000A3A0F,0x00,[B_SREGF32L|B_CHG,B_SSEF32L,B_CONST8|B_BINARY,B_NONE]),
  AsmInstrDsc("VROUNDSS\0",D_AVX|D_MUST66,DX_VEX|DX_IGNOREL|DX_LEAD3A,1,0x000000FF,0x0000000A,0x00,[B_SREGF32L|B_CHG,B_SVEXF32L,B_SSEF32L,B_CONST8|B_BINARY]),
  AsmInstrDsc("PABSB\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x001C380F,0x00,[B_MREG8x8|B_UNSIGNED|B_CHG,B_MMX8x8|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PABSB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x001C380F,0x00,[B_SREGI8x16|B_UNSIGNED|B_CHG,B_SSEI8x16|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPABSB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x0000001C,0x00,[B_SREGI8x16|B_UNSIGNED|B_CHG,B_SSEI8x16|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PABSW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x001D380F,0x00,[B_MREG16x4|B_UNSIGNED|B_CHG,B_MMX16x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PABSW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x001D380F,0x00,[B_SREGI16x8|B_UNSIGNED|B_CHG,B_SSEI16x8|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPABSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x0000001D,0x00,[B_SREGI16x8|B_UNSIGNED|B_CHG,B_SSEI16x8|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PABSD\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x001E380F,0x00,[B_MREG32x2|B_UNSIGNED|B_CHG,B_MMX32x2|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PABSD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x001E380F,0x00,[B_SREGI32x4|B_UNSIGNED|B_CHG,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPABSD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x0000001E,0x00,[B_SREGI32x4|B_UNSIGNED|B_CHG,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PALIGNR\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x000F3A0F,0x00,[B_MREG8x8|B_BINARY|B_UPD,B_MMX8x8|B_BINARY,B_CONST8|B_UNSIGNED,B_NONE]),
  AsmInstrDsc("PALIGNR\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000F3A0F,0x00,[B_SREGI8x16|B_BINARY|B_UPD,B_SSEI8x16|B_BINARY,B_CONST8|B_UNSIGNED,B_NONE]),
  AsmInstrDsc("VPALIGNR\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD3A,1,0x000000FF,0x0000000F,0x00,[B_SREGI8x16|B_BINARY|B_UPD,B_SVEXI8x16|B_BINARY,B_SSEI8x16|B_BINARY,B_CONST8|B_UNSIGNED]),
  AsmInstrDsc("PHADDW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0001380F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PHADDW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0001380F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPHADDW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000001,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PHADDD\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0002380F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PHADDD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0002380F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPHADDD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000002,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PHSUBW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0005380F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PHSUBW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0005380F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPHSUBW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000005,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PHSUBD\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0006380F,0x00,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("PHSUBD\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0006380F,0x00,[B_SREGI32x4|B_UPD,B_SSEI32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VPHSUBD\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000006,0x00,[B_SREGI32x4|B_UPD,B_SVEXI32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("PHADDSW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0003380F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PHADDSW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0003380F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPHADDSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000003,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PHSUBSW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0007380F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PHSUBSW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0007380F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPHSUBSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000007,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PMADDUBSW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0004380F,0x00,[B_MREG8x8|B_UNSIGNED|B_UPD,B_MMX8x8|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PMADDUBSW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0004380F,0x00,[B_SREGI8x16|B_UNSIGNED|B_UPD,B_SSEI8x16|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPMADDUBSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000004,0x00,[B_SREGI8x16|B_UNSIGNED|B_UPD,B_SVEXI8x16|B_UNSIGNED,B_SSEI8x16|B_SIGNED,B_NONE]),
  AsmInstrDsc("PMULHRSW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x000B380F,0x00,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PMULHRSW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000B380F,0x00,[B_SREGI16x8|B_UPD,B_SSEI16x8,B_NONE,B_NONE]),
  AsmInstrDsc("VPMULHRSW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000000B,0x00,[B_SREGI16x8|B_UPD,B_SVEXI16x8,B_SSEI16x8,B_NONE]),
  AsmInstrDsc("PSHUFB\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0000380F,0x00,[B_MREG8x8|B_UPD,B_MMX8x8|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("PSHUFB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0000380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("VPSHUFB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000000,0x00,[B_SREGI8x16|B_UPD,B_SVEXI8x16,B_SSEI8x16|B_BINARY,B_NONE]),
  AsmInstrDsc("PSIGNB\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0008380F,0x00,[B_MREG8x8|B_SIGNED|B_UPD,B_MMX8x8|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PSIGNB\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0008380F,0x00,[B_SREGI8x16|B_SIGNED|B_UPD,B_SSEI8x16|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPSIGNB\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000008,0x00,[B_SREGI8x16|B_SIGNED|B_UPD,B_SVEXI8x16|B_SIGNED,B_SSEI8x16|B_SIGNED,B_NONE]),
  AsmInstrDsc("PSIGNW\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x0009380F,0x00,[B_MREG16x4|B_SIGNED|B_UPD,B_MMX16x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PSIGNW\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x0009380F,0x00,[B_SREGI16x8|B_SIGNED|B_UPD,B_SSEI16x8|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPSIGNW\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x00000009,0x00,[B_SREGI16x8|B_SIGNED|B_UPD,B_SVEXI16x8|B_SIGNED,B_SSEI16x8|B_SIGNED,B_NONE]),
  AsmInstrDsc("PSIGND\0",D_MMX|D_MUSTNONE,0,3,0x00FFFFFF,0x000A380F,0x00,[B_MREG32x2|B_SIGNED|B_UPD,B_MMX32x2|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PSIGND\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x000A380F,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SSEI32x4|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("VPSIGND\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x0000000A,0x00,[B_SREGI32x4|B_SIGNED|B_UPD,B_SVEXI32x4|B_SIGNED,B_SSEI32x4|B_SIGNED,B_NONE]),
  AsmInstrDsc("VBROADCASTSS\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD38,1,0x000000FF,0x00000018,0x00,[B_SREGF32x4|B_CHG,B_SSEF32L|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VBROADCASTSD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LLONG|DX_NOVREG|DX_W0|DX_LEAD38,1,0x000000FF,0x00000019,0x00,[B_SREGF64x2|B_CHG,B_SSEF64L|B_MEMORY,B_NONE,B_NONE]),
  AsmInstrDsc("VBROADCASTF128\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LLONG|DX_NOVREG|DX_W0|DX_LEAD38,1,0x000000FF,0x0000001A,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2|B_MEMORY|B_NOVEXSIZE|B_SHOWSIZE,B_NONE,B_NONE]),
  AsmInstrDsc("VEXTRACTF128\0",D_AVX|D_MUST66,DX_VEX|DX_LLONG|DX_NOVREG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000019,0x00,[B_SSEF64x2|B_NOVEXSIZE|B_SHOWSIZE|B_CHG,B_SREGF64x2,B_CONST8,B_NONE]),
  AsmInstrDsc("VINSERTF128\0",D_AVX|D_MUST66,DX_VEX|DX_LLONG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000018,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2|B_NOVEXSIZE|B_SHOWSIZE,B_CONST8]),
  AsmInstrDsc("VMASKMOVPS\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD38,1,0x000000FF,0x0000002C,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEF32x4|B_MEMORY,B_NONE]),
  AsmInstrDsc("VMASKMOVPS\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD38,1,0x000000FF,0x0000002E,0x00,[B_SSEF32x4|B_MEMORY|B_CHG,B_SVEXF32x4,B_SREGF32x4,B_NONE]),
  AsmInstrDsc("VMASKMOVPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD38,1,0x000000FF,0x0000002D,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2|B_MEMORY,B_NONE]),
  AsmInstrDsc("VMASKMOVPD\0",D_AVX|D_MUST66|D_MEMORY,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD38,1,0x000000FF,0x0000002F,0x00,[B_SSEF64x2|B_MEMORY|B_CHG,B_SVEXF64x2,B_SREGF64x2,B_NONE]),
  AsmInstrDsc("VPERMILPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD38,1,0x000000FF,0x0000000D,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEI64x2,B_NONE]),
  AsmInstrDsc("VPERMILPD\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000005,0x00,[B_SREGF64x2|B_CHG,B_SSEF64x2,B_CONST8,B_NONE]),
  AsmInstrDsc("VPERMILPS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_W0|DX_LEAD38,1,0x000000FF,0x0000000C,0x00,[B_SREGF32x4|B_CHG,B_SVEXF32x4,B_SSEI32x4,B_NONE]),
  AsmInstrDsc("VPERMILPS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000004,0x00,[B_SREGF32x4|B_CHG,B_SSEF32x4,B_CONST8,B_NONE]),
  AsmInstrDsc("VPERM2F128\0",D_AVX|D_MUST66,DX_VEX|DX_LLONG|DX_W0|DX_LEAD3A,1,0x000000FF,0x00000006,0x00,[B_SREGF64x2|B_CHG,B_SVEXF64x2,B_SSEF64x2,B_CONST8]),
  AsmInstrDsc("VTESTPS\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD38,1,0x000000FF,0x0000000E,0x00,[B_SREGF32x4,B_SSEF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("VTESTPD\0",D_AVX|D_MUST66|D_ALLFLAGS,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD38,1,0x000000FF,0x0000000F,0x00,[B_SREGF64x2,B_SSEF64x2,B_NONE,B_NONE]),
  AsmInstrDsc("VZEROALL\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LLONG|DX_NOVREG,1,0x000000FF,0x00000077,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VZEROUPPER\0",D_AVX|D_MUSTNONE,DX_VEX|DX_LSHORT|DX_NOVREG,1,0x000000FF,0x00000077,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("AESDEC\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00DE380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VAESDEC\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x000000DE,0x00,[B_SREGI8x16|B_CHG,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("AESDECLAST\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00DF380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VAESDECLAST\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x000000DF,0x00,[B_SREGI8x16|B_CHG,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("AESENC\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00DC380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VAESENC\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x000000DC,0x00,[B_SREGI8x16|B_CHG,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("AESENCLAST\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00DD380F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VAESENCLAST\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_LEAD38,1,0x000000FF,0x000000DD,0x00,[B_SREGI8x16|B_CHG,B_SVEXI8x16,B_SSEI8x16,B_NONE]),
  AsmInstrDsc("AESIMC\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00DB380F,0x00,[B_SREGI8x16|B_CHG,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("VAESIMC\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD38,1,0x000000FF,0x000000DB,0x00,[B_SREGI8x16|B_CHG,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("AESKEYGENASSIST\0",D_SSE|D_MUST66,0,3,0x00FFFFFF,0x00DF3A0F,0x00,[B_SREGI8x16|B_CHG,B_SSEI8x16,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("VAESKEYGENASSIST\0",D_AVX|D_MUST66,DX_VEX|DX_LSHORT|DX_NOVREG|DX_LEAD3A,1,0x000000FF,0x000000DF,0x00,[B_SREGI8x16|B_CHG,B_SSEI8x16,B_CONST8|B_COUNT,B_NONE]),
  AsmInstrDsc("VCVTPH2PS\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD38,1,0x000000FF,0x00000013,0x00,[B_SREGF32x4|B_CHG,B_SSEI16x4L,B_NONE,B_NONE]),
  AsmInstrDsc("VCVTPS2PH\0",D_AVX|D_MUST66,DX_VEX|DX_LBOTH|DX_NOVREG|DX_W0|DX_LEAD3A,1,0x000000FF,0x0000001D,0x00,[B_SSEI16x4L|B_CHG,B_SREGF32x4,B_NONE,B_NONE]),
  AsmInstrDsc("LZCNT\0",D_CMD|D_NEEDF3|D_ALLFLAGS,0,2,0x0000FFFF,0x0000BD0F,0x00,[B_REG|B_CHG,B_INT|B_BINARY,B_NONE,B_NONE]),
  AsmInstrDsc("POPCNT\0",D_CMD|D_NEEDF3|D_ALLFLAGS,0,2,0x0000FFFF,0x0000B80F,0x00,[B_REG|B_CHG,B_INT|B_NOADDR,B_NONE,B_NONE]),
  AsmInstrDsc("EXTRQ\0",D_SSE|D_MUST66,0,2,0x0038FFFF,0x0000780F,0x00,[B_SSEI8x16|B_REGONLY|B_UPD,B_CONST8|B_COUNT,B_CONST8_2|B_COUNT,B_NONE]),
  AsmInstrDsc("EXTRQ\0",D_SSE|D_MUST66,0,2,0x0000FFFF,0x0000790F,0x00,[B_SREGI8x16|B_UPD,B_SSEI8x2L|B_REGONLY,B_NONE,B_NONE]),
  AsmInstrDsc("INSERTQ\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000780F,0x00,[B_SREGI8x16|B_REGONLY|B_UPD,B_SSEI8x8L,B_CONST8|B_COUNT,B_CONST8_2|B_COUNT]),
  AsmInstrDsc("INSERTQ\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x0000790F,0x00,[B_SREGI8x16|B_REGONLY|B_UPD,B_SSEI8x16,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTSD\0",D_SSE|D_MUSTF2,0,2,0x0000FFFF,0x00002B0F,0x00,[B_SSEF64L|B_MEMONLY|B_CHG,B_SREGF64L,B_NONE,B_NONE]),
  AsmInstrDsc("MOVNTSS\0",D_SSE|D_MUSTF3,0,2,0x0000FFFF,0x00002B0F,0x00,[B_SSEF32L|B_MEMONLY|B_CHG,B_SREGF32L,B_NONE,B_NONE]),
  AsmInstrDsc("INVEPT\0",D_PRIVILEGED|D_MUST66|D_MEMORY|D_RARE,0,3,0x00FFFFFF,0x0080380F,0x00,[B_REG32,B_INT128,B_NONE,B_NONE]),
  AsmInstrDsc("INVVPID\0",D_PRIVILEGED|D_MUST66|D_MEMORY|D_RARE,0,3,0x00FFFFFF,0x0081380F,0x00,[B_REG32,B_INT128,B_NONE,B_NONE]),
  AsmInstrDsc("VMCALL\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00C1010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMCLEAR\0",D_PRIVILEGED|D_MUST66|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0030C70F,0x00,[B_INT64|B_MEMONLY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMLAUNCH\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00C2010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMFUNC\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00D4010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("XEND\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00D5010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("XTEST\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00D6010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMRESUME\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00C3010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMPTRLD\0",D_PRIVILEGED|D_MUSTNONE|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0030C70F,0x00,[B_INT64|B_MEMONLY,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMPTRST\0",D_PRIVILEGED|D_MUSTNONE|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0038C70F,0x00,[B_INT64|B_MEMONLY|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMREAD\0",D_PRIVILEGED|D_MUSTNONE|D_RARE,0,2,0x0000FFFF,0x0000780F,0x00,[B_INT32|B_CHG,B_REG32,B_NONE,B_NONE]),
  AsmInstrDsc("VMWRITE\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000790F,0x00,[B_REG32,B_INT32,B_NONE,B_NONE]),
  AsmInstrDsc("VMXOFF\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00C4010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMXON\0",D_PRIVILEGED|D_MUSTF3|D_MEMORY|D_RARE,0,2,0x0038FFFF,0x0030C70F,0x00,[B_INT64,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("GETSEC\0",D_PRIVILEGED|D_RARE,0,2,0x0000FFFF,0x0000370F,0x00,[B_EAX|B_UPD|B_PSEUDO,B_EBX|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE]),
  AsmInstrDsc("FEMMS\0",D_CMD,0,2,0x0000FFFF,0x00000E0F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("PAVGUSB\0",D_MMX|D_POSTBYTE|D_MUSTNONE,0,2,0x0000FFFF,0x00000F0F,0xBF,[B_MREG8x8|B_UPD,B_MMX8x8,B_NONE,B_NONE]),
  AsmInstrDsc("PF2ID\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x1D,[B_MREG32x2|B_CHG,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFACC\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xAE,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFADD\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x9E,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFCMPEQ\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xB0,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFCMPGE\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x90,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFCMPGT\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xA0,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFMAX\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xA4,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFMIN\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x94,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFMUL\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xB4,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFRCP\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x96,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFRCPIT1\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xA6,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFRCPIT2\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xB6,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFRSQIT1\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xA7,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFRSQRT\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x97,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFSUB\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x9A,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFSUBR\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0xAA,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PI2FD\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x0D,[B_3DREG|B_UPD,B_MMX32x2|B_SIGNED,B_NONE,B_NONE]),
  AsmInstrDsc("PMULHRW\0",D_MMX|D_POSTBYTE|D_MUSTNONE,0,2,0x0000FFFF,0x00000F0F,0xB7,[B_MREG16x4|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PF2IW\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x1C,[B_MREG32x2|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFNACC\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x8A,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PFPNACC\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x8E,[B_3DREG|B_UPD,B_3DNOW,B_NONE,B_NONE]),
  AsmInstrDsc("PI2FW\0",D_3DNOW|D_POSTBYTE,0,2,0x0000FFFF,0x00000F0F,0x0C,[B_3DREG|B_UPD,B_MMX16x4,B_NONE,B_NONE]),
  AsmInstrDsc("PSWAPD\0",D_MMX|D_POSTBYTE|D_MUSTNONE,0,2,0x0000FFFF,0x00000F0F,0xBB,[B_MREG32x2|B_UPD,B_MMX32x2,B_NONE,B_NONE]),
  AsmInstrDsc("SYSCALL\0",D_SYS|D_RARE,0,2,0x0000FFFF,0x0000050F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SYSRET\0",D_SYS|D_ALLFLAGS|D_SUSPICIOUS,0,2,0x0000FFFF,0x0000070F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CLGI\0",D_PRIVILEGED,0,3,0x00FFFFFF,0x00DD010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("STGI\0",D_PRIVILEGED,0,3,0x00FFFFFF,0x00DC010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("INVLPGA\0",D_PRIVILEGED|D_RARE,0,3,0x00FFFFFF,0x00DF010F,0x00,[B_EAX|B_PSEUDO,B_ECX|B_PSEUDO,B_NONE,B_NONE]),
  AsmInstrDsc("SKINIT\0",D_PRIVILEGED,0,3,0x00FFFFFF,0x00DE010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMLOAD\0",D_PRIVILEGED,0,3,0x00FFFFFF,0x00DA010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMMCALL\0",D_SYS|D_SUSPICIOUS,0,3,0x00FFFFFF,0x00D9010F,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMRUN\0",D_PRIVILEGED,0,3,0x00FFFFFF,0x00D8010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("VMSAVE\0",D_PRIVILEGED,0,3,0x00FFFFFF,0x00DB010F,0x00,[B_EAX|B_PSEUDO,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("ES:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x00000026,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CS:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x0000002E,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SS:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x00000036,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("DS:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x0000003E,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("FS:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x00000064,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("GS:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x00000065,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("DATASIZE:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x00000066,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("ADDRSIZE:\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x00000067,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("LOCK\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x000000F0,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("REPNE\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x000000F2,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("REPNZ\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x000000F2,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("REP\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x000000F3,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("REPE\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x000000F3,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("REPZ\0",D_PREFIX|D_SUSPICIOUS,0,1,0x000000FF,0x000000F3,0x00,[B_NONE,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JCC\0",D_PSEUDO|D_BHINT|D_COND,0,1,0x000000F0,0x00000070,0x00,[B_BYTEOFFS|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("JCC\0",D_PSEUDO|D_BHINT|D_COND,0,2,0x0000F0FF,0x0000800F,0x00,[B_OFFSET|B_JMPCALL,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("SETCC\0",D_PSEUDO|D_COND,0,2,0x0038F0FF,0x0000900F,0x00,[B_INT8|B_SHOWSIZE|B_CHG,B_NONE,B_NONE,B_NONE]),
  AsmInstrDsc("CMOVCC\0",D_PSEUDO|D_COND,0,2,0x0000F0FF,0x0000400F,0x00,[B_REG|B_UPD,B_INT,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVCC\0",D_PSEUDO|D_COND,0,2,0x0000E0FF,0x0000C0DA,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
  AsmInstrDsc("FCMOVCC\0",D_PSEUDO|D_COND,0,2,0x0000E0FF,0x0000C0DB,0x00,[B_ST0|B_CHG,B_ST,B_NONE,B_NONE]),
];


// ////////////////////////////////////////////////////////////////////////// //
// ///////////////////////////// SYMBOLIC NAMES ///////////////////////////// //

// 8-bit register names, sorted by 'natural' index (as understood by CPU, not
// in the alphabetical order as some 'programmers' prefer).
immutable string[NREG] regname8 = ["AL", "CL", "DL", "BL", "AH", "CH", "DH", "BH"];

// 16-bit register names.
immutable string[NREG] regname16 = ["AX", "CX", "DX", "BX", "SP", "BP", "SI", "DI"];

// 32-bit register names.
immutable string[NREG] regname32 = ["EAX", "ECX", "EDX", "EBX", "ESP", "EBP", "ESI", "EDI"];

// Names of segment registers.
immutable string[NREG] segname = ["ES", "CS", "SS", "DS", "FS", "GS", "SEG6:", "SEG7:"];

// Names of FPU registers, classical form.
immutable string[NREG] fpulong = ["ST(0)", "ST(1)", "ST(2)", "ST(3)", "ST(4)", "ST(5)", "ST(6)", "ST(7)"];

// Names of FPU registers, short form.
immutable string[NREG] fpushort = ["ST0", "ST1", "ST2", "ST3", "ST4", "ST5", "ST6", "ST7"];

// Names of MMX/3DNow! registers.
immutable string[NREG] mmxname = ["MM0", "MM1", "MM2", "MM3", "MM4", "MM5", "MM6", "MM7"];

// Names of 128-bit SSE registers.
immutable string[NREG] sse128 = ["XMM0", "XMM1", "XMM2", "XMM3", "XMM4", "XMM5", "XMM6", "XMM7"];

// Names of 256-bit SSE registers.
immutable string[NREG] sse256 = ["YMM0", "YMM1", "YMM2", "YMM3", "YMM4", "YMM5", "YMM6", "YMM7"];

// Names of control registers.
immutable string[NREG] crname = ["CR0", "CR1", "CR2", "CR3", "CR4", "CR5", "CR6", "CR7"];

// Names of debug registers.
immutable string[NREG] drname = ["DR0", "DR1", "DR2", "DR3", "DR4", "DR5", "DR6", "DR7"];

// Declarations for data types. Depending on ssesizemode, name of 16-byte data type (DQWORD)
// may be changed to XMMWORD and that of 32-bit type (QQWORD) to YMMWORD.
immutable string[33] sizename = [
  null,     "BYTE", "WORD",  null,
  "DWORD",  null,   "FWORD", null,
  "QWORD",  null,   "TBYTE", null,
  null,     null,   null,    null,
  "DQWORD", null,   null,    null,
  null,     null,   null,    null,
  null,     null,   null,    null,
  null,     null,   null,    null,
  "QQWORD",
];

// Keywords for immediate data. HLA uses sizename[] instead of sizekey[].
immutable string[33] sizekey = [
  null,  "DB", "DW", null,
  "DD",  null, "DF", null,
  "DQ",  null, "DT", null,
  null,  null, null, null,
  "DDQ", null, null, null,
  null,  null, null, null,
  null,  null, null, null,
  null,  null, null, null,
  "DQQ",
];

// Keywords for immediate data in AT&T format.
immutable string[33] sizeatt = [
  null,     ".BYTE", ".WORD",  null,
  ".LONG",  null,    ".FWORD", null,
  ".QUAD",  null,    ".TBYTE", null,
  null,     null,    null,     null,
  ".DQUAD", null,    null,     null,
  null,     null,    null,     null,
  null,     null,    null,     null,
  null,     null,    null,     null,
  ".QQUAD",
];

// Comparison predicates in SSE [0..7] and VEX commands [0..31].
immutable string[32] ssepredicate = [
  "EQ",       "LT",       "LE",       "UNORD",
  "NEQ",      "NLT",      "NLE",      "ORD",
  "EQ_UQ",    "NGE",      "NGT",      "FALSE",
  "NEQ_OQ",   "GE",       "GT",       "TRUE",
  "EQ_OS",    "LT_OQ",    "LE_OQ",    "UNORD_S",
  "NEQ_US",   "NLT_UQ",   "NLE_UQ",   "ORD_S",
  "EQ_US",    "NGE_UQ",   "NGT_UQ",   "FALSE_OS",
  "NEQ_OS",   "GE_OQ",    "GT_OQ",    "TRUE_US",
];


// ////////////////////////////////////////////////////////////////////////// //
// ////////////////////////////// DISASSEMBLER ////////////////////////////// //

// Intermediate disassembler data
struct t_imdata {
  DisasmData* da;                  // Result of disassembly
  uint damode;               // Disassembling mode, set of DA_xxx
  const(DAConfig)* config;              // Disassembler configuration
  const(char)[] delegate (uint addr) decodeaddress;
  uint prefixlist;           // List of command's prefixes, PF_xxx
  int ssesize;              // Size of SSE operands (16/32 bytes)
  uint immsize1;             // Size of first immediate constant
  uint immsize2;             // Size of second immediate constant
  uint mainsize;             // Size of command with prefixes
  uint modsize;              // Size of ModRegRM/SIB bytes
  uint dispsize;             // Size of address offset
  int usesdatasize;         // May have data size prefix
  int usesaddrsize;         // May have address size prefix
  int usessegment;          // May have segment override prefix
}

// ////////////////////////////////////////////////////////////////////////// //
// /////////////////////////// SERVICE FUNCTIONS //////////////////////////// //

// Nibble-to-hexdigit table, uppercase
immutable string hexcharu = "0123456789ABCDEF";

// Nibble-to-hexdigit table, lowercase
immutable string hexcharl = "0123456789abcdef";

private __gshared char[256] cvtlower;

private void tstrlwr (char[] s) {
  foreach (ref char ch; s) {
    import std.ascii : toLower;
    ch = ch.toLower;
  }
}

// Copies at most n-1 wide characters from src to dest and assures that dest is
// null-terminated. Slow but reliable. Returns number of copied characters, not
// including the terminal null. Attention, does not check that input parameters
// are correct!
private int Tstrcopy (char* dest, int n, const(char)* src) {
  int i;
  if (n <= 0) return 0;
  for (i = 0; i < n-1; ++i) {
    if (*src == '\0') break;
    *dest++ = *src++;
  }
  *dest = '\0';
  return i;
}

// Copies at most n-1 wide characters from src to dest and assures that dest is
// null-terminated. If lowercase is 1, simultaneously converts it to lower
// case. Slow but reliable. Returns number of copied characters, not including
// the terminal null. Attention, does not check that input parameters are
// correct!
private int Tcopycase (char* dest, int n, const(char)* src, int lowercase) {
  int i;
  if (n <= 0)
    return 0;
  for (i = 0; i < n-1; i++) {
    if (*src == '\0') break;
    if (lowercase)
      *dest++ = cvtlower[*src++];        // Much faster than call to tolower()
    else
      *dest++ = *src++;
  }
  *dest = '\0';
  return i;
}


// Dumps ncode bytes of code to the string s. Returns length of resulting text,
// characters, not including terminal zero. Attention, does not check that
// input parameters are correct or that s has sufficient length!
private int Thexdump (char* s, const(ubyte)* code, int ncode, int lowercase) {
  int d, n;
  immutable(char)* hexchar = (lowercase ? hexcharl.ptr : hexcharu.ptr);
  n = 0;
  while (ncode > 0) {
    d = *code++;
    s[n++] = hexchar[(d>>4)&0x0F];
    s[n++] = hexchar[d&0x0F];
    --ncode;
  }
  s[n] = '\0';
  return n;
}

// Converts unsigned 1-, 2- or 4-byte number to hexadecimal text, according to
// the specified mode and type of argument. String s must be at least SHORTNAME
// characters long. Returns length of resulting text in characters, not
// including the terminal zero.
private int Hexprint (int size, char* s, uint u, const(t_imdata)* im, uint arg) {
  int i, k, ndigit, lastdigit;
  uint nummode, mod;
  char[SHORTNAME] buf;
  immutable(char)* hexchar;
  if (size == 1)
    u &= 0x000000FF;                     // 8-bit number
  else if (size == 2)
    u &= 0x0000FFFF;                     // 16-bit number
  else
    size = 4;                            // Correct possible errors
  mod = arg&B_MODMASK;
  if (mod == B_ADDR)
    nummode = im.config.memmode;
  else if (mod == B_JMPCALL || mod == B_JMPCALLFAR)
    nummode = im.config.jmpmode;
  else if (mod == B_BINARY)
    nummode = im.config.binconstmode;
  else
    nummode = im.config.constmode;
  hexchar = (im.config.lowercase?hexcharl.ptr:hexcharu.ptr);
  buf[SHORTNAME-1] = '\0';
  k = SHORTNAME-1;
  if ((nummode&NUM_DECIMAL) != 0 && (mod == B_SIGNED || mod == B_UNSIGNED ||
    (u < DECLIMIT && mod != B_BINARY && mod != B_JMPCALL && mod != B_JMPCALLFAR))
  ) {
    // Decode as decimal unsigned number.
    if ((nummode&NUM_STYLE) == NUM_OLLY && u >= 10)
      buf[--k] = '.';                 // Period marks decimals in OllyDbg
    do {
      buf[--k] = hexchar[u%10];
      u /= 10;
    } while (u != 0); }
  else {
    // Decode as hexadecimal number.
    if (nummode&NUM_LONG)            // 2, 4 or 8 significant digits
      ndigit = size*2;
    else
      ndigit = 1;
    if ((nummode&NUM_STYLE) == NUM_STD)
      buf[--k] = 'h';
    for (i = 0; i < ndigit || u != 0; i++) {
      lastdigit = u&0x0F;
      buf[--k] = hexchar[lastdigit];
      u = (u>>4)&0x0FFFFFFF; }
    if ((nummode&NUM_STYLE) == NUM_X) {
      buf[--k] = 'x';
      buf[--k] = '0'; }
    else if (lastdigit >= 10 &&
      ((nummode&NUM_STYLE) != NUM_OLLY || i < (mod == B_BINARY ? size*2 : 8)))
    {
      buf[--k] = '0';
    }
  }
  return Tstrcopy(s, SHORTNAME, buf.ptr+k);
}


// ////////////////////////////////////////////////////////////////////////// //
// ////////////////////// INTERNAL DISASSEMBLER TABLES ////////////////////// //
private:
// Element of command chain
struct t_chain {
  immutable(AsmInstrDsc)* pcmd; // Pointer to command descriptor or null
  t_chain* pnext; // Pointer to next element in chain
}

// ModRM byte decoding
struct t_modrm {
  uint size;             // Total size with SIB and disp, bytes
  t_modrm* psib;         // Pointer to SIB table or null
  uint dispsize;         // Size of displacement or 0 if none
  uint features;         // Operand features, set of OP_xxx
  int reg;               // Register index or REG_UNDEF
  int defseg;            // Default selector (SEG_xxx)
  ubyte[NREG] scale;     // Scales of registers in memory address
  uint aregs;            // List of registers used in address
  int basereg;           // Register used as base or REG_UNDEF
  char[SHORTNAME] ardec; // Register part of address, INTEL fmt
  char[SHORTNAME] aratt; // Register part of address, AT&T fmt
}

__gshared t_chain* cmdchain;            // Commands sorted by first CMDMASK bits
__gshared t_modrm[256] modrm16;         // 16-bit ModRM decodings
__gshared t_modrm[256] modrm32;         // 32-bit ModRM decodings without SIB
__gshared t_modrm[256] sib0;            // ModRM-SIB decodings with Mod=00
__gshared t_modrm[256] sib1;            // ModRM-SIB decodings with Mod=01
__gshared t_modrm[256] sib2;            // ModRM-SIB decodings with Mod=10

// Initializes disassembler tables. Call this function once during startup.
// Returns 0 on success and -1 if initialization was unsuccessful. In the last
// case, continuation is not possible and program must terminate.
private void Preparedisasm () {
  import core.stdc.stdlib : malloc;
  import core.stdc.string : memset;
  int n, c, reg, sreg, scale, nchain;
  uint u, code, mask;
  //immutable(AsmInstrDsc)* pcmd;
  t_chain* pchain;
  t_modrm* pmrm, psib;

  void tsp (char[] arr, string s) {
    if (s.length > arr.length) assert(0, "wtf?!");
    arr[] = 0;
    arr[0..s.length] = s[];
  }

  // sort command descriptors into command chains by first CMDMASK bits.
  cmdchain = cast(t_chain*)malloc(NCHAIN*t_chain.sizeof);
  if (cmdchain is null) assert(0, "out of memory"); // Low memory
  memset(cmdchain, 0, NCHAIN*t_chain.sizeof);
  nchain = CMDMASK+1; // number of command chains
  foreach (immutable ref pcc; asmInstrTable) {
    auto pcmd = &pcc;
    if ((pcmd.cmdtype&D_CMDTYPE) == D_PSEUDO) continue; // Pseudocommand, for search models only
    code = pcmd.code;
    mask = pcmd.mask&CMDMASK;
    for (u = 0; u < CMDMASK+1; ++u) {
      if (((u^code)&mask) != 0) continue; // Command has different first bytes
      pchain = cmdchain+u;
      while (pchain.pcmd !is null && pchain.pnext !is null) pchain = pchain.pnext; // Walk chain to the end
      if (pchain.pcmd is null) {
        pchain.pcmd = pcmd;
      } else if (nchain >= NCHAIN) {
        assert(0, "too many commands in disasm"); // Too many commands
      } else {
        pchain.pnext = cmdchain+nchain; // Prolongate chain
        pchain = pchain.pnext;
        pchain.pcmd = pcmd;
        ++nchain;
      }
    }
  }
  // Prepare 16-bit ModRM decodings.
  memset(modrm16.ptr, 0, modrm16.sizeof);
  for (c = 0x00, pmrm = modrm16.ptr; c <= 0xFF; ++c, ++pmrm) {
    reg = c&0x07;
    if ((c&0xC0) == 0xC0) {
      // Register in ModRM.
      pmrm.size = 1;
      pmrm.features = 0; // Register, its type as yet unknown
      pmrm.reg = reg;
      pmrm.defseg = SEG_UNDEF;
      pmrm.basereg = REG_UNDEF;
    } else if ((c&0xC7) == 0x06) {
      // Special case of immediate address.
      pmrm.size = 3;
      pmrm.dispsize = 2;
      pmrm.features = OP_MEMORY|OP_OPCONST|OP_ADDR16;
      pmrm.reg = REG_UNDEF;
      pmrm.defseg = SEG_DS;
      pmrm.basereg = REG_UNDEF;
    } else {
      pmrm.features = OP_MEMORY|OP_INDEXED|OP_ADDR16;
      if ((c&0xC0) == 0x40) {
        pmrm.dispsize = 1;
        pmrm.features |= OP_OPCONST;
      } else if ((c&0xC0) == 0x80) {
        pmrm.dispsize = 2;
        pmrm.features |= OP_OPCONST;
      }
      pmrm.size = pmrm.dispsize+1;
      pmrm.reg = REG_UNDEF;
      final switch (reg) {
        case 0:
          pmrm.scale[REG_EBX] = 1;
          pmrm.scale[REG_ESI] = 1;
          pmrm.defseg = SEG_DS;
          tsp(pmrm.ardec[], "BX+SI");
          tsp(pmrm.aratt[], "%BX, %SI");
          pmrm.aregs = (1<<REG_EBX)|(1<<REG_ESI);
          pmrm.basereg = REG_ESI;
          break;
        case 1:
          pmrm.scale[REG_EBX] = 1;
          pmrm.scale[REG_EDI] = 1;
          pmrm.defseg = SEG_DS;
          tsp(pmrm.ardec[], "BX+DI");
          tsp(pmrm.aratt[], "%BX, %DI");
          pmrm.aregs = (1<<REG_EBX)|(1<<REG_EDI);
          pmrm.basereg = REG_EDI;
          break;
        case 2:
          pmrm.scale[REG_EBP] = 1;
          pmrm.scale[REG_ESI] = 1;
          pmrm.defseg = SEG_SS;
          tsp(pmrm.ardec[], "BP+SI");
          tsp(pmrm.aratt[], "%BP, %SI");
          pmrm.aregs = (1<<REG_EBP)|(1<<REG_ESI);
          pmrm.basereg = REG_ESI;
          break;
        case 3:
          pmrm.scale[REG_EBP] = 1;
          pmrm.scale[REG_EDI] = 1;
          pmrm.defseg = SEG_SS;
          tsp(pmrm.ardec[], "BP+DI");
          tsp(pmrm.aratt[], "%BP, %DI");
          pmrm.aregs = (1<<REG_EBP)|(1<<REG_EDI);
          pmrm.basereg = REG_EDI;
          break;
        case 4:
          pmrm.scale[REG_ESI] = 1;
          pmrm.defseg = SEG_DS;
          tsp(pmrm.ardec[], "SI");
          tsp(pmrm.aratt[], "%SI");
          pmrm.aregs = (1<<REG_ESI);
          pmrm.basereg = REG_ESI;
          break;
        case 5:
          pmrm.scale[REG_EDI] = 1;
          pmrm.defseg = SEG_DS;
          tsp(pmrm.ardec[], "DI");
          tsp(pmrm.aratt[], "%DI");
          pmrm.aregs = (1<<REG_EDI);
          pmrm.basereg = REG_EDI;
          break;
        case 6:
          pmrm.scale[REG_EBP] = 1;
          pmrm.defseg = SEG_SS;
          tsp(pmrm.ardec[], "BP");
          tsp(pmrm.aratt[], "%BP");
          pmrm.aregs = (1<<REG_EBP);
          pmrm.basereg = REG_EBP;
          break;
        case 7:
          pmrm.scale[REG_EBX] = 1;
          pmrm.defseg = SEG_DS;
          tsp(pmrm.ardec[], "BX");
          tsp(pmrm.aratt[], "%BX");
          pmrm.aregs = (1<<REG_EBX);
          pmrm.basereg = REG_EBX;
        break;
      }
    }
  }
  // Prepare 32-bit ModRM decodings without SIB.
  memset(modrm32.ptr, 0, modrm32.sizeof);
  for (c = 0x00, pmrm = modrm32.ptr; c <= 0xFF; ++c, ++pmrm) {
    reg = c&0x07;
    if ((c&0xC0) == 0xC0) {
      // Register in ModRM.
      pmrm.size = 1;
      pmrm.features = 0; // Register, its type as yet unknown
      pmrm.reg = reg;
      pmrm.defseg = SEG_UNDEF;
      pmrm.basereg = REG_UNDEF;
    } else if ((c&0xC7) == 0x05) {
      // Special case of 32-bit immediate address.
      pmrm.size = 5;
      pmrm.dispsize = 4;
      pmrm.features = OP_MEMORY|OP_OPCONST;
      pmrm.reg = REG_UNDEF;
      pmrm.defseg = SEG_DS;
      pmrm.basereg = REG_UNDEF;
    } else {
      // Regular memory address.
      pmrm.features = OP_MEMORY;
      pmrm.reg = REG_UNDEF;
      if ((c&0xC0) == 0x40) {
        pmrm.dispsize = 1; // 8-bit sign-extended displacement
        pmrm.features |= OP_OPCONST;
      } else if ((c&0xC0) == 0x80) {
        pmrm.dispsize = 4; // 32-bit displacement
        pmrm.features |= OP_OPCONST;
      }
      if (reg == REG_ESP) {
        // SIB byte follows, decode with sib32.
             if ((c&0xC0) == 0x00) pmrm.psib = sib0.ptr;
        else if ((c&0xC0) == 0x40) pmrm.psib = sib1.ptr;
        else pmrm.psib = sib2.ptr;
        pmrm.basereg = REG_UNDEF;
      } else {
        pmrm.size = 1+pmrm.dispsize;
        pmrm.features |= OP_INDEXED;
        pmrm.defseg = (reg == REG_EBP ? SEG_SS : SEG_DS);
        pmrm.scale[reg] = 1;
        tsp(pmrm.ardec, regname32[reg]);
        pmrm.aratt[0] = '%';
        tsp(pmrm.aratt[1..$]/*, SHORTNAME-1*/, regname32[reg]);
        pmrm.aregs = (1<<reg);
        pmrm.basereg = reg;
      }
    }
  }
  // Prepare 32-bit ModRM decodings with SIB, case Mod=00: usually no disp.
  memset(sib0.ptr, 0, sib0.sizeof);
  for (c = 0x00, psib = sib0.ptr; c <= 0xFF; ++c, ++psib) {
    psib.features = OP_MEMORY;
    psib.reg = REG_UNDEF;
    reg = c&0x07;
    sreg = (c>>3)&0x07;
         if ((c&0xC0) == 0x00) scale = 1;
    else if ((c&0xC0) == 0x40) scale = 2;
    else if ((c&0xC0) == 0x80) scale = 4;
    else scale = 8;
    if (sreg != REG_ESP) {
      psib.scale[sreg] = cast(ubyte)scale;
      n = Tstrcopy(psib.ardec.ptr, SHORTNAME, regname32[sreg].ptr);
      psib.aregs = (1<<sreg);
      psib.features |= OP_INDEXED;
      if (scale > 1) {
        psib.ardec[n++] = '*';
        psib.ardec[n++] = cast(char)('0'+scale);
        psib.ardec[n] = '\0';
      }
    } else {
      n = 0;
    }
    if (reg == REG_EBP) {
      psib.size = 6;
      psib.dispsize = 4;
      psib.features |= OP_OPCONST;
      psib.defseg = SEG_DS;
      psib.basereg = REG_UNDEF;
    } else {
      psib.size = 2;
      psib.defseg = (reg == REG_ESP || reg == REG_EBP ? SEG_SS : SEG_DS);
      psib.scale[reg]++;
      psib.features |= OP_INDEXED;
      if (n != 0) psib.ardec[n++] = '+';
      Tstrcopy(psib.ardec.ptr+n, SHORTNAME-n, regname32[reg].ptr);
      psib.aregs |= (1<<reg);
      psib.basereg = reg;
    }
    if (reg != REG_EBP) {
      psib.aratt[0] = '%';
      n = 1;
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, regname32[reg].ptr);
    } else {
      n = 0;
    }
    if (sreg != REG_ESP) {
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, ", %");
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, regname32[sreg].ptr);
      if (scale > 1) {
        psib.aratt[n++] = ',';
        psib.aratt[n++] = cast(char)('0'+scale);
        psib.aratt[n] = '\0';
      }
    }
  }
  // Prepare 32-bit ModRM decodings with SIB, case Mod=01: 8-bit displacement.
  memset(sib1.ptr, 0, sib1.sizeof);
  for (c = 0x00, psib = sib1.ptr; c <= 0xFF; c++, psib++) {
    psib.features = OP_MEMORY|OP_INDEXED|OP_OPCONST;
    psib.reg = REG_UNDEF;
    reg = c&0x07;
    sreg = (c>>3)&0x07;
         if ((c&0xC0) == 0) scale = 1;
    else if ((c&0xC0) == 0x40) scale = 2;
    else if ((c&0xC0) == 0x80) scale = 4;
    else scale = 8;
    psib.size = 3;
    psib.dispsize = 1;
    psib.defseg = (reg == REG_ESP || reg == REG_EBP ? SEG_SS : SEG_DS);
    psib.scale[reg] = 1;
    psib.basereg = reg;
    psib.aregs = (1<<reg);
    if (sreg != REG_ESP) {
      psib.scale[sreg] += cast(ubyte)scale;
      n = Tstrcopy(psib.ardec.ptr, SHORTNAME, regname32[sreg].ptr);
      psib.aregs |= (1<<sreg);
      if (scale > 1) {
        psib.ardec[n++] = '*';
        psib.ardec[n++] = cast(char)('0'+scale);
      }
    } else {
      n = 0;
    }
    if (n != 0) psib.ardec[n++] = '+';
    Tstrcopy(psib.ardec.ptr+n, SHORTNAME-n, regname32[reg].ptr);
    psib.aratt[0] = '%'; n = 1;
    n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, regname32[reg].ptr);
    if (sreg != REG_ESP) {
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, ", %");
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, regname32[sreg].ptr);
      if (scale > 1) {
        psib.aratt[n++] = ',';
        psib.aratt[n++] = cast(char)('0'+scale);
        psib.aratt[n] = '\0';
      }
    }
  }
  // Prepare 32-bit ModRM decodings with SIB, case Mod=10: 32-bit displacement.
  memset(sib2.ptr, 0, sib2.sizeof);
  for (c = 0x00, psib = sib2.ptr; c <= 0xFF; c++, psib++) {
    psib.features = OP_MEMORY|OP_INDEXED|OP_OPCONST;
    psib.reg = REG_UNDEF;
    reg = c&0x07;
    sreg = (c>>3)&0x07;
         if ((c&0xC0) == 0) scale = 1;
    else if ((c&0xC0) == 0x40) scale = 2;
    else if ((c&0xC0) == 0x80) scale = 4;
    else scale = 8;
    psib.size = 6;
    psib.dispsize = 4;
    psib.defseg = (reg == REG_ESP || reg == REG_EBP ? SEG_SS : SEG_DS);
    psib.scale[reg] = 1;
    psib.basereg = reg;
    psib.aregs = (1<<reg);
    if (sreg != REG_ESP) {
      psib.scale[sreg] += cast(ubyte)scale;
      n = Tstrcopy(psib.ardec.ptr, SHORTNAME, regname32[sreg].ptr);
      psib.aregs |= (1<<sreg);
      if (scale > 1) {
        psib.ardec[n++] = '*';
        psib.ardec[n++] = cast(char)('0'+scale);
      }
    } else {
      n = 0;
    }
    if (n != 0) psib.ardec[n++] = '+';
    Tstrcopy(psib.ardec.ptr+n, SHORTNAME-n, regname32[reg].ptr);
    psib.aratt[0] = '%'; n = 1;
    n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, regname32[reg].ptr);
    if (sreg != REG_ESP) {
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, ", %");
      n += Tstrcopy(psib.aratt.ptr+n, SHORTNAME-n, regname32[sreg].ptr);
      if (scale > 1) {
        psib.aratt[n++] = ',';
        psib.aratt[n++] = cast(char)('0'+scale);
        psib.aratt[n] = '\0';
      }
    }
  }
  // Fill lowercase conversion table. This table replaces tolower(). When
  // compiled with Borland C++ Builder, spares significant time.
  for (c = 0; c < 256; ++c) {
    import std.ascii : toLower;
    cvtlower[c] = toLower(cast(char)c);
  }
}

// Frees resources allocated by Preparedisasm(). Call this function once
// during shutdown after disassembling service is no longer necessary.
void Finishdisasm () {
  import core.stdc.stdlib : free;
  if (cmdchain !is null) {
    free(cmdchain);
    cmdchain = null;
  }
}

shared static this () { Preparedisasm(); }
shared static ~this () { Finishdisasm(); }


////////////////////////////////////////////////////////////////////////////////
////////////////////////////// AUXILIARY ROUTINES //////////////////////////////

// Given index of byte register, returns index of 32-bit container.
private int Byteregtodwordreg (int bytereg) {
  if (bytereg < 0 || bytereg >= NREG) return REG_UNDEF;
  if (bytereg >= 4) return bytereg-4;
  return bytereg;
}

// Checks prefix override flags and generates warnings if prefix is superfluous.
// Returns index of segment register. Note that Disasm() assures that two
// segment override bits in im.prefixlist can't be set simultaneously.
private int Getsegment (t_imdata *im, int arg, int defseg) {
  if ((im.prefixlist&PF_SEGMASK) == 0) return defseg; // Optimization for most frequent case
  switch (im.prefixlist&PF_SEGMASK) {
    case PF_ES:
      if (defseg == SEG_ES) im.da.warnings |= DAW_DEFSEG;
      if (arg&B_NOSEG) im.da.warnings |= DAW_SEGPREFIX;
      return SEG_ES;
    case PF_CS:
      if (defseg == SEG_CS) im.da.warnings |= DAW_DEFSEG;
      if (arg&B_NOSEG) im.da.warnings |= DAW_SEGPREFIX;
      return SEG_CS;
    case PF_SS:
      if (defseg == SEG_SS) im.da.warnings |= DAW_DEFSEG;
      if (arg&B_NOSEG) im.da.warnings |= DAW_SEGPREFIX;
      return SEG_SS;
    case PF_DS:
      if (defseg == SEG_DS) im.da.warnings |= DAW_DEFSEG;
      if (arg&B_NOSEG) im.da.warnings |= DAW_SEGPREFIX;
      return SEG_DS;
    case PF_FS:
      if (defseg == SEG_FS) im.da.warnings |= DAW_DEFSEG;
      if (arg&B_NOSEG) im.da.warnings |= DAW_SEGPREFIX;
      return SEG_FS;
    case PF_GS:
      if (defseg == SEG_GS) im.da.warnings |= DAW_DEFSEG;
      if (arg&B_NOSEG) im.da.warnings |= DAW_SEGPREFIX;
      return SEG_GS;
    default: return defseg; // Most frequent case of default segment
  }
}

private bool decodeAddr (t_imdata* im, char[] buf, uint addr) {
  if (im.decodeaddress is null) return false;
  auto name = im.decodeaddress(addr);
  if (name.length == 0) return false;
  if (name.length > buf.length-1) name = name[0..buf.length-1];
  buf[0..name.length] = name[];
  buf[name.length] = 0;
  return true;
}


// Decodes generalized memory address to text.
private void Memaddrtotext (t_imdata* im, int arg, int datasize, int seg, const(char)* regpart, int constpart, char* s) {
  int n;
  char[TEXTLEN] label = void;
  if (im.config.disasmmode == DAMODE_ATT) {
    // AT&T memory address syntax is so different from Intel that I process it
    // separately from the rest.
    n = 0;
    if ((arg&B_MODMASK) == B_JMPCALL) s[n++] = '*';
    // On request, I show only explicit segments.
    if ((im.config.putdefseg && (arg&B_NOSEG) == 0) || (im.prefixlist&PF_SEGMASK) != 0) {
      s[n++] = '%';
      n += Tcopycase(s+n, TEXTLEN-n, segname[seg].ptr, im.config.lowercase);
      s[n++] = ':';
    }
    // Add constant part (offset).
    if (constpart < 0 && constpart > NEGLIMIT) {
      s[n++] = '-';
      n += Hexprint((im.prefixlist&PF_ASIZE?2:4), s+n, -constpart, im, B_ADDR);
    } else if (constpart != 0) {
      if (seg != SEG_FS && seg != SEG_GS && decodeAddr(im, label[], constpart)) {
        n += Tstrcopy(s+n, TEXTLEN-n, label.ptr);
      } else {
        n += Hexprint((im.prefixlist&PF_ASIZE ? 2 : 4), s+n, constpart, im, B_ADDR);
      }
    }
    // Add register part of address, may be absent.
    if (regpart[0] != '\0') {
      n += Tstrcopy(s+n, TEXTLEN-n, "(");
      n += Tcopycase(s+n, TEXTLEN-n, regpart, im.config.lowercase);
      n += Tstrcopy(s+n, TEXTLEN-n, ")");
    }
  } else {
    // Mark far and near jump/call addresses.
    if ((arg&B_MODMASK) == B_JMPCALLFAR) {
      n = Tcopycase(s, TEXTLEN, "FAR ", im.config.lowercase);
    } else if (im.config.shownear && (arg&B_MODMASK) == B_JMPCALL) {
      n = Tcopycase(s, TEXTLEN, "NEAR ", im.config.lowercase);
    } else {
      n = 0;
    }
    if (im.config.disasmmode != DAMODE_MASM) {
      s[n++] = '[';
      if ((im.prefixlist&PF_ASIZE) != 0 && regpart[0] == '\0') {
        n += Tcopycase(s+n, TEXTLEN-n, "SMALL ", im.config.lowercase);
      }
    }
    // If operand is longer than 32 bytes or of type B_ANYMEM (memory contents
    // unimportant), its size is not displayed. Otherwise, bit B_SHOWSIZE
    // indicates that explicit operand's size can't be omitted.
    if (datasize <= 32 && (arg&B_ARGMASK) != B_ANYMEM && (im.config.showmemsize != 0 || (arg&B_SHOWSIZE) != 0)) {
      if (im.config.disasmmode == DAMODE_HLA) n += Tcopycase(s+n, TEXTLEN-n, "TYPE ", im.config.lowercase);
      if ((arg&B_ARGMASK) == B_INTPAIR && im.config.disasmmode == DAMODE_IDEAL) {
        // If operand is a pair of integers (BOUND), Borland in IDEAL mode
        // expects size of single integer, whereas MASM requires size of the
        // whole pair.
        n += Tcopycase(s+n, TEXTLEN-n, sizename[datasize/2].ptr, im.config.lowercase);
        s[n++] = ' ';
      } else if (datasize == 16 && im.config.ssesizemode == 1) {
        n += Tcopycase(s+n, TEXTLEN-n, "XMMWORD ", im.config.lowercase);
      } else if (datasize == 32 && im.config.ssesizemode == 1) {
        n += Tcopycase(s+n, TEXTLEN-n, "YMMWORD ", im.config.lowercase);
      } else {
        n += Tcopycase(s+n, TEXTLEN-n, sizename[datasize].ptr, im.config.lowercase);
        s[n++] = ' ';
      }
      if (im.config.disasmmode == DAMODE_MASM) n += Tcopycase(s+n, TEXTLEN-n, "PTR ", im.config.lowercase);
    }
    // On request, I show only explicit segments.
    if ((im.config.putdefseg && (arg&B_NOSEG) == 0) || (im.prefixlist&PF_SEGMASK) != 0) {
      n += Tcopycase(s+n, TEXTLEN-n, segname[seg].ptr, im.config.lowercase);
      s[n++] = ':';
    }
    if (im.config.disasmmode == DAMODE_MASM) {
      s[n++] = '[';
      if ((im.prefixlist&PF_ASIZE) != 0 && regpart[0] == '\0') n += Tcopycase(s+n, TEXTLEN-n, "SMALL ", im.config.lowercase);
    }
    // Add register part of address, may be absent.
    if (regpart[0] != '\0') n += Tcopycase(s+n, TEXTLEN-n, regpart, im.config.lowercase);
    if (regpart[0] != '\0' && constpart < 0 && constpart > NEGLIMIT) {
      s[n++] = '-';
      n += Hexprint((im.prefixlist&PF_ASIZE ? 2 : 4), s+n, -constpart, im, B_ADDR);
    } else if (constpart != 0 || regpart[0] == '\0') {
      if (regpart[0] != '\0') s[n++] = '+';
      if (seg != SEG_FS && seg != SEG_GS && decodeAddr(im, label[], constpart)) {
        n += Tstrcopy(s+n, TEXTLEN-n, label.ptr);
      } else {
        n += Hexprint((im.prefixlist&PF_ASIZE?2:4), s+n, constpart, im, B_ADDR);
      }
    }
    n += Tstrcopy(s+n, TEXTLEN-n, "]");
  }
  s[n] = '\0';
}

// Service function, returns granularity of MMX, 3DNow! and SSE operands.
private int Getgranularity (uint arg) {
  int granularity;
  switch (arg&B_ARGMASK) {
    case B_MREG8x8:    // MMX register as 8 8-bit integers
    case B_MMX8x8:     // MMX reg/memory as 8 8-bit integers
    case B_MMX8x8DI:   // MMX 8 8-bit integers at [DS:(E)DI]
    case B_XMM0I8x16:  // XMM0 as 16 8-bit integers
    case B_SREGI8x16:  // SSE register as 16 8-bit sigints
    case B_SVEXI8x16:  // SSE reg in VEX as 16 8-bit sigints
    case B_SIMMI8x16:  // SSE reg in immediate 8-bit constant
    case B_SSEI8x16:   // SSE reg/memory as 16 8-bit sigints
    case B_SSEI8x16DI: // SSE 16 8-bit sigints at [DS:(E)DI]
    case B_SSEI8x8L:   // Low 8 8-bit ints in SSE reg/memory
    case B_SSEI8x4L:   // Low 4 8-bit ints in SSE reg/memory
    case B_SSEI8x2L:   // Low 2 8-bit ints in SSE reg/memory
      granularity = 1;
      break;
    case B_MREG16x4:   // MMX register as 4 16-bit integers
    case B_MMX16x4:    // MMX reg/memory as 4 16-bit integers
    case B_SREGI16x8:  // SSE register as 8 16-bit sigints
    case B_SVEXI16x8:  // SSE reg in VEX as 8 16-bit sigints
    case B_SSEI16x8:   // SSE reg/memory as 8 16-bit sigints
    case B_SSEI16x4L:  // Low 4 16-bit ints in SSE reg/memory
    case B_SSEI16x2L:  // Low 2 16-bit ints in SSE reg/memory
      granularity = 2;
      break;
    case B_MREG32x2:   // MMX register as 2 32-bit integers
    case B_MMX32x2:    // MMX reg/memory as 2 32-bit integers
    case B_3DREG:      // 3DNow! register as 2 32-bit floats
    case B_3DNOW:      // 3DNow! reg/memory as 2 32-bit floats
    case B_SREGF32x4:  // SSE register as 4 32-bit floats
    case B_SVEXF32x4:  // SSE reg in VEX as 4 32-bit floats
    case B_SREGF32L:   // Low 32-bit float in SSE register
    case B_SVEXF32L:   // Low 32-bit float in SSE in VEX
    case B_SREGF32x2L: // Low 2 32-bit floats in SSE register
    case B_SSEF32x4:   // SSE reg/memory as 4 32-bit floats
    case B_SSEF32L:    // Low 32-bit float in SSE reg/memory
    case B_SSEF32x2L:  // Low 2 32-bit floats in SSE reg/memory
      granularity = 4;
      break;
    case B_XMM0I32x4:  // XMM0 as 4 32-bit integers
    case B_SREGI32x4:  // SSE register as 4 32-bit sigints
    case B_SVEXI32x4:  // SSE reg in VEX as 4 32-bit sigints
    case B_SREGI32L:   // Low 32-bit sigint in SSE register
    case B_SREGI32x2L: // Low 2 32-bit sigints in SSE register
    case B_SSEI32x4:   // SSE reg/memory as 4 32-bit sigints
    case B_SSEI32x2L:  // Low 2 32-bit sigints in SSE reg/memory
      granularity = 4;
      break;
    case B_MREG64:     // MMX register as 1 64-bit integer
    case B_MMX64:      // MMX reg/memory as 1 64-bit integer
    case B_XMM0I64x2:  // XMM0 as 2 64-bit integers
    case B_SREGF64x2:  // SSE register as 2 64-bit floats
    case B_SVEXF64x2:  // SSE reg in VEX as 2 64-bit floats
    case B_SREGF64L:   // Low 64-bit float in SSE register
    case B_SVEXF64L:   // Low 64-bit float in SSE in VEX
    case B_SSEF64x2:   // SSE reg/memory as 2 64-bit floats
    case B_SSEF64L:    // Low 64-bit float in SSE reg/memory
      granularity = 8;
      break;
    case B_SREGI64x2:  // SSE register as 2 64-bit sigints
    case B_SVEXI64x2:  // SSE reg in VEX as 2 64-bit sigints
    case B_SSEI64x2:   // SSE reg/memory as 2 64-bit sigints
    case B_SREGI64L:   // Low 64-bit sigint in SSE register
      granularity = 8;
      break;
    default:
      granularity = 1; // Treat unknown ops as string of bytes
    break;
  }
  return granularity;
}


// ////////////////////////////////////////////////////////////////////////// //
// /////////////////////// OPERAND DECODING ROUTINES //////////////////////// //

// Decodes 8/16/32-bit integer register operand. ATTENTION, calling routine
// must set usesdatasize and usesaddrsize by itself!
private void Operandintreg (t_imdata* im, uint datasize, int index, AsmOperand* op) {
  int n, reg32;
  op.features = OP_REGISTER;
  op.opsize = op.granularity = datasize;
  op.reg = index;
  op.seg = SEG_UNDEF;
  // Add container register to lists of used and modified registers.
  reg32 = (datasize == 1 ? Byteregtodwordreg(index) : index);
  if ((op.arg&B_CHG) == 0) {
    op.uses = (1<<reg32);
    im.da.uses |= (1<<reg32);
  }
  if (op.arg&(B_CHG|B_UPD)) {
    op.modifies = (1<<reg32);
    im.da.modifies |= (1<<reg32);
  }
  // Warn if ESP is misused.
  if ((op.arg&B_NOESP) != 0 && reg32 == REG_ESP) im.da.warnings |= DAW_NOESP;
  // Decode name of integer register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) {
      if ((op.arg&B_MODMASK) == B_JMPCALL) op.text[n++] = '*';
      op.text[n++] = '%';
    }
    // Most frequent case first
         if (datasize == 4) Tcopycase(op.text.ptr+n, TEXTLEN-n, regname32[index].ptr, im.config.lowercase);
    else if (datasize == 1) Tcopycase(op.text.ptr+n, TEXTLEN-n, regname8[index].ptr, im.config.lowercase);
    else Tcopycase(op.text.ptr+n, TEXTLEN-n, regname16[index].ptr, im.config.lowercase); // 16-bit registers are seldom
  }
}

// Decodes 16/32-bit memory address in ModRM/SIB bytes. Returns full length of
// address (ModRM+SIB+displacement) in bytes, 0 if ModRM indicates register
// operand and -1 on error. ATTENTION, calling routine must set usesdatasize,
// granularity (preset to datasize) and reg together with OP_MODREG by itself!
private int Operandmodrm (t_imdata* im, uint datasize, const(ubyte)* cmd, uint cmdsize, AsmOperand* op) {
  import core.stdc.string : memcpy;
  char* ardec;
  t_modrm* pmrm;
  if (cmdsize == 0) { im.da.errors |= DAE_CROSS; return -1; } // Command crosses end of memory block
  // Decode ModRM/SIB. Most of the work is already done in Preparedisasm(), we
  // only need to find corresponding t_modrm.
  if (im.prefixlist&PF_ASIZE) {
    // 16-bit address
    pmrm = modrm16.ptr+cmd[0];
    im.modsize = 1;
  } else {
    pmrm = modrm32.ptr+cmd[0];
    if (pmrm.psib is null) {
      im.modsize = 1; // No SIB byte
    } else {
      if (cmdsize < 2) { im.da.errors |= DAE_CROSS; return -1; } // Command crosses end of memory block
      pmrm = pmrm.psib+cmd[1];
      im.modsize = 2; // Both ModRM and SIB
    }
  }
  // Check whether ModRM indicates register operand and immediately return if
  // true. As a side effect, modsize is already set.
  if ((cmd[0]&0xC0) == 0xC0) return 0;
  // Operand in memory.
  op.opsize = datasize;
  op.granularity = datasize; // Default, may be overriden later
  op.reg = REG_UNDEF;
  im.usesaddrsize = 1; // Address size prefix is meaningful
  im.usessegment = 1; // Segment override prefix is meaningful
  // Fetch precalculated t_modrm fields.
  op.features = pmrm.features;
  memcpy(op.scale.ptr, pmrm.scale.ptr, 8);
  op.aregs = pmrm.aregs;
  im.da.uses |= pmrm.aregs; // Mark registers used to form address
  // Get displacement, if any.
  im.dispsize = pmrm.dispsize;
  if (pmrm.dispsize != 0) {
    if (cmdsize < pmrm.size) { im.da.errors |= DAE_CROSS; return -1; } // Command crosses end of memory block
    if (pmrm.dispsize == 1) {
      // 8-bit displacement is sign-extended
      op.opconst = im.da.memconst = cast(byte)cmd[im.modsize];
    } else if (pmrm.dispsize == 4) {
      // 32-bit full displacement
      im.da.memfixup = im.mainsize+im.modsize; // Possible 32-bit fixup
      op.opconst = im.da.memconst = *cast(uint*)(cmd+im.modsize);
    } else {
      // 16-bit displacement, very rare
      op.opconst = im.da.memconst = *cast(ushort*)(cmd+im.modsize);
    }
  }
  // Get segment.
  op.seg = Getsegment(im, op.arg, pmrm.defseg);
  // Warn if memory contents is 16-bit jump/call destination.
  if (datasize == 2 && (op.arg&B_MODMASK) == B_JMPCALL) im.da.warnings |= DAW_JMP16;
  // Decode memory operand to text, if requested.
  if (im.damode&DA_TEXT) {
    ardec = (im.config.disasmmode == DAMODE_ATT ? pmrm.aratt.ptr : pmrm.ardec.ptr);
    Memaddrtotext(im, op.arg, datasize, op.seg, ardec, op.opconst, op.text.ptr);
  }
  return pmrm.size;
}

// Decodes 16/32-bit immediate address (used only for 8/16/32-bit memory-
// accumulator moves). ATTENTION, calling routine must set usesdatasize by
// itself!
private void Operandimmaddr (t_imdata* im, uint datasize, const(ubyte)* cmd, uint cmdsize, AsmOperand* op) {
  im.dispsize = (im.prefixlist&PF_ASIZE ? 2 : 4);
  if (cmdsize < im.dispsize) { im.da.errors |= DAE_CROSS; return; } // Command crosses end of memory block
  op.features = OP_MEMORY|OP_OPCONST;
  op.opsize = op.granularity = datasize;
  op.reg = REG_UNDEF;
  im.usesaddrsize = 1; // Address size prefix is meaningful
  im.usessegment = 1; // Segment override prefix is meaningful
  // 32-bit immediate address?
  if (im.dispsize == 4) {
    // 32-bit address means possible fixup, calculate offset.
    im.da.memfixup = im.mainsize;
    op.opconst = im.da.memconst = *cast(uint*)cmd;
  } else {
    // 16-bit immediate address, very rare
    op.opconst = im.da.memconst = *cast(ushort*)cmd;
    op.features |= OP_ADDR16;
  }
  // Get segment.
  op.seg = Getsegment(im, op.arg, SEG_DS);
  // Decode memory operand to text, if requested.
  if (im.damode&DA_TEXT) Memaddrtotext(im, op.arg, datasize, op.seg, "", op.opconst, op.text.ptr);
}

// Decodes simple register address ([reg16] or [reg32]). Flag changesreg must
// be 0 if register remains unchanged and 1 if it changes. If fixseg is set to
// SEG_UNDEF, assumes overridable DS:, otherwise assumes fixsegment that cannot
// be overriden with segment prefix. If fixaddrsize is 2 or 4, assumes 16- or
// 32-bit addressing only, otherwise uses default. ATTENTION, calling routine
// must set usesdatasize by itself!
private void Operandindirect (t_imdata* im, int index, int changesreg, int fixseg, int fixaddrsize, uint datasize, AsmOperand* op) {
  int n;
  uint originallist;
  char[SHORTNAME] ardec;
  op.features = OP_MEMORY|OP_INDEXED;
  if (changesreg) {
    op.features |= OP_MODREG;
    op.reg = index;
    im.da.modifies |= (1<<index);
  } else {
    op.reg = REG_UNDEF;
  }
  if (fixaddrsize == 2) {
    op.features |= OP_ADDR16;
  } else if (fixaddrsize == 0) {
    // Address size prefix is meaningful
    im.usesaddrsize = 1;
    if (im.prefixlist&PF_ASIZE) {
      op.features |= OP_ADDR16;
      fixaddrsize = 2;
    }
  }
  // Get segment.
  if (fixseg == SEG_UNDEF) {
    op.seg = Getsegment(im, op.arg, SEG_DS);
    im.usessegment = 1; // Segment override prefix is meaningful
  } else {
    op.seg = fixseg;
  }
  op.opsize = datasize;
  op.granularity = datasize; // Default, may be overriden later
  op.scale[index] = 1;
  op.aregs = (1<<index);
  im.da.uses |= (1<<index);
  // Warn if memory contents is 16-bit jump/call destination.
  if (datasize == 2 && (op.arg&B_MODMASK) == B_JMPCALL) im.da.warnings |= DAW_JMP16;
  // Decode source operand to text, if requested.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) { ardec[0] = '%'; n = 1; } else n = 0;
    if (fixaddrsize == 2) {
      Tstrcopy(ardec.ptr+n, SHORTNAME-n, regname16[index].ptr);
    } else {
      Tstrcopy(ardec.ptr+n, SHORTNAME-n, regname32[index].ptr);
    }
    if (fixseg == SEG_UNDEF) {
      Memaddrtotext(im, op.arg, datasize, op.seg, ardec.ptr, 0, op.text.ptr);
    } else {
      originallist = im.prefixlist;
      im.prefixlist &= ~PF_SEGMASK;
      Memaddrtotext(im, op.arg, datasize, op.seg, ardec.ptr, 0, op.text.ptr);
      im.prefixlist = originallist;
    }
  }
}

// Decodes XLAT source address ([(E)BX+AL]). Note that I set scale of EAX to 1,
// which is not exactly true. ATTENTION, calling routine must set usesdatasize
// by itself!
private void Operandxlat (t_imdata* im, AsmOperand* op) {
  immutable(char)* ardec;
  op.features = OP_MEMORY|OP_INDEXED;
  if (im.prefixlist&PF_ASIZE) op.features |= OP_ADDR16;
  im.usesaddrsize = 1; // Address size prefix is meaningful
  im.usessegment = 1; // Segment override prefix is meaningful
  op.opsize = 1;
  op.granularity = 1;
  op.reg = REG_UNDEF;
  // Get segment.
  op.seg = Getsegment(im, op.arg, SEG_DS);
  op.scale[REG_EAX] = 1; // This is not correct!
  op.scale[REG_EBX] = 1;
  op.aregs = (1<<REG_EAX)|(1<<REG_EBX);
  im.da.uses |= op.aregs;
  // Decode address to text, if requested.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      ardec = (im.prefixlist&PF_ASIZE ? "%BX, %AL" : "%EBX, %AL");
    } else {
      ardec = (im.prefixlist&PF_ASIZE ? "BX+AL" : "EBX+AL");
    }
    Memaddrtotext(im, op.arg, 1, op.seg, ardec, 0, op.text.ptr);
  }
}

// Decodes stack pushes of any size, including implicit return address in
// CALLs. ATTENTION, calling routine must set usesdatasize by itself!
private void Operandpush (t_imdata* im, uint datasize, AsmOperand* op) {
  int n, addrsize;
  uint originallist;
  char[SHORTNAME] ardec;
  op.features = OP_MEMORY|OP_INDEXED|OP_MODREG;
  op.reg = REG_ESP;
  op.aregs = (1<<REG_ESP);
  im.da.modifies |= op.aregs;
  im.usesaddrsize = 1; // Address size prefix is meaningful
  if (im.prefixlist&PF_ASIZE) {
    op.features |= OP_ADDR16;
    addrsize = 2;
  } else {
    addrsize = 4; // Flat model!
  }
  op.seg = SEG_SS;
  if ((op.arg&B_ARGMASK) == B_PUSHA) {
    im.da.uses = 0xFF; // Uses all general registers
    op.opsize = datasize*8;
  } else if ((op.arg&B_ARGMASK) == B_PUSHRETF) {
    im.da.uses |= op.aregs;
    op.opsize = datasize*2;
  } else {
    im.da.uses |= op.aregs;
    // Warn if memory contents is 16-bit jump/call destination.
    if (datasize == 2 && (op.arg&B_MODMASK) == B_JMPCALL) im.da.warnings |= DAW_JMP16;
    op.opsize = datasize;
  }
  op.opconst = -cast(int)op.opsize; // ESP is predecremented
  op.granularity = datasize; // Default, may be overriden later
  op.scale[REG_ESP] = 1;
  // Decode source operand to text, if requested.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) { ardec[0] = '%'; n = 1; } else n = 0;
    if (addrsize == 2) {
      Tstrcopy(ardec.ptr+n, SHORTNAME-n, regname16[REG_ESP].ptr);
    } else {
      Tstrcopy(ardec.ptr+n, SHORTNAME-n, regname32[REG_ESP].ptr);
    }
    originallist = im.prefixlist;
    im.prefixlist &= ~PF_SEGMASK;
    Memaddrtotext(im, op.arg, datasize, op.seg, ardec.ptr, 0, op.text.ptr);
    im.prefixlist = originallist;
  }
}

// Decodes segment register.
private void Operandsegreg (t_imdata* im, int index, AsmOperand* op) {
  int n;
  op.features = OP_SEGREG;
  if (index >= NSEG) {
    op.features |= OP_INVALID; // Invalid segment register
    im.da.errors |= DAE_BADSEG;
  }
  op.opsize = op.granularity = 2;
  op.reg = index;
  op.seg = SEG_UNDEF; // Because this is not a memory address
  if (op.arg&(B_CHG|B_UPD)) im.da.warnings |= DAW_SEGMOD; // Modifies segment register
  // Decode name of segment register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '%';
    Tcopycase(op.text.ptr+n, TEXTLEN-n, segname[index].ptr, im.config.lowercase);
  }
}

// Decodes FPU register operand.
private void Operandfpureg (t_imdata* im, int index, AsmOperand* op) {
  op.features = OP_FPUREG;
  op.opsize = op.granularity = 10;
  op.reg = index;
  op.seg = SEG_UNDEF; // Because this is not a memory address
  // Decode name of FPU register.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      if (im.config.simplifiedst && index == 0) {
        Tcopycase(op.text.ptr, TEXTLEN, "%ST", im.config.lowercase);
      } else {
        op.text[0] = '%';
        Tcopycase(op.text.ptr+1, TEXTLEN-1, fpushort[index].ptr, im.config.lowercase);
      }
    } else if (im.config.simplifiedst && index == 0) {
      Tcopycase(op.text.ptr, TEXTLEN, "ST", im.config.lowercase);
    } else if (im.config.disasmmode != DAMODE_HLA) {
      Tcopycase(op.text.ptr, TEXTLEN, fpulong[index].ptr, im.config.lowercase);
    } else {
      Tcopycase(op.text.ptr, TEXTLEN, fpushort[index].ptr, im.config.lowercase);
    }
  }
}

// Decodes MMX register operands. ATTENTION, does not set correct granularity!
private void Operandmmxreg (t_imdata* im, int index, AsmOperand* op) {
  int n;
  op.features = OP_MMXREG;
  op.opsize = 8;
  op.granularity = 4; // Default, correct it later!
  op.reg = index;
  op.seg = SEG_UNDEF;
  // Decode name of MMX/3DNow! register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '%';
    Tcopycase(op.text.ptr+n, TEXTLEN-n, mmxname[index].ptr, im.config.lowercase);
  }
}

// Decodes 3DNow! register operands. ATTENTION, does not set correct
// granularity!
private void Operandnowreg (t_imdata* im, int index, AsmOperand* op) {
  int n;
  op.features = OP_3DNOWREG;
  op.opsize = 8;
  op.granularity = 4; // Default, correct it later!
  op.reg = index;
  op.seg = SEG_UNDEF;
  // Decode name of MMX/3DNow! register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '%';
    Tcopycase(op.text.ptr+n, TEXTLEN-n, mmxname[index].ptr, im.config.lowercase);
  }
}

// Decodes SSE register operands. ATTENTION, does not set correct granularity!
private void Operandssereg (t_imdata* im, int index, AsmOperand* op) {
  int n;
  op.features = OP_SSEREG;
  op.opsize = (op.arg&B_NOVEXSIZE ? 16 : im.ssesize);
  op.granularity = 4; // Default, correct it later!
  op.reg = index;
  op.seg = SEG_UNDEF;
  // Note that some rare SSE commands may use Reg without ModRM.
  if (im.modsize == 0) im.modsize = 1;
  // Decode name of SSE register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '%';
    if (op.opsize == 32) {
      Tcopycase(op.text.ptr+n, TEXTLEN-n, sse256[index].ptr, im.config.lowercase);
    } else {
      Tcopycase(op.text.ptr+n, TEXTLEN-n, sse128[index].ptr, im.config.lowercase);
    }
  }
}

// Decodes flag register EFL.
private void Operandefl (t_imdata* im, uint datasize, AsmOperand* op) {
  op.features = OP_OTHERREG;
  op.opsize = op.granularity = datasize;
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  // Decode name of register.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      Tcopycase(op.text.ptr, TEXTLEN, "%EFL", im.config.lowercase);
    } else {
      Tcopycase(op.text.ptr, TEXTLEN, "EFL", im.config.lowercase);
    }
  }
}

// Decodes 8/16/32-bit immediate jump/call offset relative to EIP of next
// command.
private void Operandoffset (t_imdata* im, uint offsetsize, uint datasize, const(ubyte)* cmd, uint cmdsize, uint offsaddr, AsmOperand* op) {
  int n;
  char[TEXTLEN] label;
  if (cmdsize < offsetsize) { im.da.errors |= DAE_CROSS; return; } // Command crosses end of memory block
  op.features = OP_CONST;
  op.opsize = op.granularity = datasize; // NOT offsetsize!
  im.immsize1 = offsetsize;
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  offsaddr += offsetsize;
  if (offsetsize == 1) {
    // Sign-extandable constant
    op.opconst = *cast(byte*)cmd+offsaddr;
  } else if (offsetsize == 2) {
    // 16-bit immediate offset, rare
    op.opconst = *cast(ushort*)cmd+offsaddr;
  } else {
    // 32-bit immediate offset
    op.opconst = *cast(uint*)cmd+offsaddr;
  }
  if (datasize == 2) { op.opconst &= 0x0000FFFF; im.da.warnings |= DAW_JMP16; } // Practically unused in Win32 code
  im.usesdatasize = 1;
  // Decode address of destination to text, if requested.
  if (im.damode&DA_TEXT) {
    if (offsetsize == 1 && im.config.disasmmode != DAMODE_HLA && im.config.disasmmode != DAMODE_ATT) {
      n = Tcopycase(op.text.ptr, TEXTLEN, "SHORT ", im.config.lowercase);
    } else {
      n = 0;
    }
    if (datasize == 4) {
      if (decodeAddr(im, label[], op.opconst)) {
        Tstrcopy(op.text.ptr+n, TEXTLEN-n, label.ptr);
      } else {
        if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '$';
        Hexprint(4, op.text.ptr+n, op.opconst, im, op.arg);
      }
    } else {
      if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '$';
      Hexprint(2, op.text.ptr+n, op.opconst, im, op.arg);
    }
  }
}

// Decodes 16:16/16:32-bit immediate absolute far jump/call address.
private void Operandimmfaraddr (t_imdata* im, uint datasize, const(ubyte)* cmd, uint cmdsize, AsmOperand* op) {
  int n;
  if (cmdsize < datasize+2) { im.da.errors |= DAE_CROSS; return; } // Command crosses end of memory block
  op.features = OP_CONST|OP_SELECTOR;
  op.opsize = datasize+2;
  op.granularity = datasize; // Attention, non-standard case!
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  im.immsize1 = datasize;
  im.immsize2 = 2;
  if (datasize == 2) {
    op.opconst = *cast(ushort*)cmd;
    im.da.warnings |= DAW_JMP16; // Practically unused in Win32 code
  } else {
    op.opconst = *cast(uint*)cmd;
    im.da.immfixup = im.mainsize;
  }
  op.selector = *cast(ushort*)(cmd+datasize);
  im.usesdatasize = 1;
  // Decode address of destination to text, if requested.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      op.text[0] = '$';
      n = 1;
    } else {
      n = Tcopycase(op.text.ptr, TEXTLEN, "FAR ", im.config.lowercase);
    }
    n += Hexprint(2, op.text.ptr+n, op.selector, im, op.arg);
    op.text[n++] = ':';
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '$';
    Hexprint(4, op.text.ptr+n, op.opconst, im, op.arg);
  }
}

// Decodes immediate constant 1 used in shift operations.
private void Operandone (t_imdata *im, AsmOperand *op) {
  op.features = OP_CONST;
  op.opsize = op.granularity = 1; // Just to make it defined
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  op.opconst = 1;
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      Tstrcopy(op.text.ptr, TEXTLEN, "$1");
    } else {
      Tstrcopy(op.text.ptr, TEXTLEN, "1");
    }
  }
}

// Decodes 8/16/32-bit immediate constant (possibly placed after ModRegRM-SIB-
// Disp combination). Constant is nbytes long in the command and extends to
// constsize bytes. If constant is a count, it deals with data of size datasize.
// ATTENTION, calling routine must set usesdatasize by itself!
private void Operandimmconst (t_imdata* im, uint nbytes, uint constsize, uint datasize, const(ubyte)* cmd, uint cmdsize, int issecond, AsmOperand* op) {
  int n;
  uint u, mod;
  char[TEXTLEN] label;
  if (cmdsize < im.modsize+im.dispsize+nbytes+(issecond?im.immsize1:0)) { im.da.errors |= DAE_CROSS; return; } // Command crosses end of memory block
  op.features = OP_CONST;
  op.opsize = op.granularity = constsize;
  cmd += im.modsize+im.dispsize;
  if (issecond == 0) {
    im.immsize1 = nbytes; // First constant
  } else {
    im.immsize2 = nbytes; // Second constant (ENTER only)
    cmd += im.immsize1;
  }
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  if (nbytes == 4) {
    // 32-bit immediate constant
    op.opconst = *cast(uint*)cmd;
    im.da.immfixup = im.mainsize+im.modsize+im.dispsize+(issecond ? im.immsize1 : 0);
  } else if (nbytes == 1) {
    // 8-byte constant, maybe sign-extendable
    op.opconst = *cast(byte*)cmd;
  } else {
    // 16-bite immediate constant, rare
    op.opconst = *cast(ushort*)cmd;
  }
       if (constsize == 1) op.opconst &= 0x000000FF;
  else if (constsize == 2) op.opconst &= 0x0000FFFF;
  switch (op.arg&B_MODMASK) {
    case B_BITCNT: // Constant is a bit count
      if ((datasize == 4 && op.opconst > 31) || (datasize == 1 && op.opconst > 7) || (datasize == 2 && op.opconst > 15)) im.da.warnings |= DAW_SHIFT;
      break;
    case B_SHIFTCNT: // Constant is a shift count
      if (op.opconst == 0 || (datasize == 4 && op.opconst > 31) || (datasize == 1 && op.opconst > 7) || (datasize == 2 && op.opconst > 15)) im.da.warnings |= DAW_SHIFT;
      break;
    case B_STACKINC: // Stack increment must be DWORD-aligned
      if ((op.opconst&0x3) != 0) im.da.warnings |= DAW_STACK;
      im.da.stackinc = op.opconst;
      break;
    default: break;
  }
  if (im.damode&DA_TEXT) {
    mod = op.arg&B_MODMASK;
    n = 0;
    if (constsize == 1) {
      // 8-bit constant
      if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '$';
      Hexprint(1, op.text.ptr+n, op.opconst, im, op.arg);
    } else if (constsize == 4) {
      // 32-bit constant
      if ((mod == B_NONSPEC || mod == B_JMPCALL || mod == B_JMPCALLFAR) && decodeAddr(im, label[], op.opconst)) {
        Tstrcopy(op.text.ptr+n, TEXTLEN-n, label.ptr);
      } else {
        if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '$';
        if (mod != B_UNSIGNED && mod != B_BINARY && mod != B_PORT && cast(int)op.opconst < 0 && (mod == B_SIGNED || cast(int)op.opconst > NEGLIMIT)) {
          op.text[n++] = '-'; u = -cast(int)op.opconst;
        } else {
          u = op.opconst;
        }
        Hexprint(4, op.text.ptr+n, u, im, op.arg);
      }
    } else {
      // 16-bit constant
      if (im.config.disasmmode == DAMODE_ATT) {
        op.text[n++] = '$';
      } else if ((op.arg&B_SHOWSIZE) != 0) {
        n += Tcopycase(op.text.ptr+n, TEXTLEN-n, sizename[constsize].ptr, im.config.lowercase);
        n += Tstrcopy(op.text.ptr+n, TEXTLEN-n, " ");
      }
      Hexprint(2, op.text.ptr+n, op.opconst, im, op.arg);
    }
  }
}

// Decodes contrtol register operands.
private void Operandcreg (t_imdata* im, int index, AsmOperand* op) {
  int n;
  op.features = OP_CREG;
  op.opsize = op.granularity = 4;
  op.reg = index;
  op.seg = SEG_UNDEF;
  // Decode name of control register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '%';
    Tcopycase(op.text.ptr+n, TEXTLEN-n, crname[index].ptr, im.config.lowercase);
  }
  // Some control registers are physically absent.
  if (index != 0 && index != 2 && index != 3 && index != 4) im.da.errors |= DAE_BADCR;
}

// Decodes debug register operands.
private void Operanddreg (t_imdata* im, int index, AsmOperand* op) {
  int n;
  op.features = OP_DREG;
  op.opsize = op.granularity = 4;
  op.reg = index;
  op.seg = SEG_UNDEF;
  // Decode name of debug register.
  if (im.damode&DA_TEXT) {
    n = 0;
    if (im.config.disasmmode == DAMODE_ATT) op.text[n++] = '%';
    Tcopycase(op.text.ptr+n, TEXTLEN-n, drname[index].ptr, im.config.lowercase);
  }
}

// Decodes FPU status register FST.
private void Operandfst (t_imdata* im, AsmOperand* op) {
  op.features = OP_OTHERREG;
  op.opsize = op.granularity = 2;
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  // Decode name of register.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      Tcopycase(op.text.ptr, TEXTLEN, "%FST", im.config.lowercase);
    } else {
      Tcopycase(op.text.ptr, TEXTLEN, "FST", im.config.lowercase);
    }
  }
}

// Decodes FPU control register FCW.
private void Operandfcw (t_imdata* im, AsmOperand* op) {
  op.features = OP_OTHERREG;
  op.opsize = op.granularity = 2;
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  // Decode name of register.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      Tcopycase(op.text.ptr, TEXTLEN, "%FCW", im.config.lowercase);
    } else {
      Tcopycase(op.text.ptr, TEXTLEN, "FCW", im.config.lowercase);
    }
  }
}

// Decodes SSE control register MXCSR.
private void Operandmxcsr (t_imdata* im, AsmOperand* op) {
  op.features = OP_OTHERREG;
  op.opsize = op.granularity = 4;
  op.reg = REG_UNDEF;
  op.seg = SEG_UNDEF;
  // Decode name of register.
  if (im.damode&DA_TEXT) {
    if (im.config.disasmmode == DAMODE_ATT) {
      Tcopycase(op.text.ptr, TEXTLEN, "%MXCSR", im.config.lowercase);
    } else {
      Tcopycase(op.text.ptr, TEXTLEN, "MXCSR", im.config.lowercase);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// public API

// Disassembles first command in the binary code of given length at given
// address. Assumes that address and data size attributes of all participating
// segments are 32 bit (flat model). Returns length of the command or 0 in case
// of severe error.
public uint disasm (const(void)[] codearr, uint ip, DisasmData* da, int damode, const(DAConfig)* config, scope const(char)[] delegate (uint addr) decodeaddress=null) {
  import core.stdc.string : memset;
  int i, j, k, q, noperand, nout, enclose, vexreg, success, cfill, ofill;
  uint m, n, u, prefix, prefixmask, code, arg, cmdtype, datasize;
  uint type, vex, vexlead;
  t_imdata im;
  const(t_chain)* pchain;
  immutable(AsmInstrDsc)* pcmd;
  const(t_modrm)* pmrm;
  AsmOperand *op;
  AsmOperand pseudoop;
  static DAConfig defconfig; // default one
  const(ubyte)* cmd = cast(const(ubyte)*)codearr.ptr;
  static if (codearr.length.sizeof > 4) {
    uint cmdsize = (codearr.length > uint.max ? uint.max : cast(uint)codearr.length);
  } else {
    uint cmdsize = codearr.length;
  }
  // Verify input parameters.
  if (cmdsize == 0 || da is null || cmdchain is null) return 0; // Error in parameters or uninitialized
  // Initialize DisasmData structure that receives results of disassembly. This
  // structure is very large, memset() or several memset()'s would take much,
  // much longer.
  da.ip = ip;
  da.memfixup = da.immfixup = -1;
  da.errors = DAE_NOERR;
  da.warnings = DAW_NOWARN;
  da.uses = 0;
  da.modifies = 0;
  da.memconst = 0;
  da.stackinc = 0;
  for (i = 0, op = da.op.ptr; i < NOPERAND; ++i, ++op) {
    op.features = 0;
    op.arg = 0;
    op.opsize = op.granularity = 0;
    op.reg = REG_UNDEF;
    op.uses = 0;
    op.modifies = 0;
    op.seg = SEG_UNDEF;
    (cast(uint*)op.scale)[0] = 0;
    (cast(uint*)op.scale)[1] = 0;
    op.aregs = 0;
    op.opconst = 0;
    op.selector = 0;
    op.text[] = 0;
  }
  da.dump[] = 0;
  da.result[] = 0;
  da.masksize = 0;
  // Prepare intermediate data. This data allows to keep Disasm() reentrant
  // (thread-safe).
  im.da = da;
  im.damode = damode;
  if (config is null) {
    im.config = config = &defconfig; // Use default configuration
  } else {
    im.config = config;
  }
  im.decodeaddress = decodeaddress;
  im.prefixlist = 0;
  im.ssesize = 16; // Default
  im.immsize1 = im.immsize2 = 0;
  // Correct 80x86 command may contain up to 4 prefixes belonging to different
  // prefix groups. If Disasm() detects second prefix from the same group, it
  // flushes first prefix in the sequence as a pseudocommand. (This is not
  // quite true; all CPUs that I have tested accept repeating prefixes. Still,
  // who will place superfluous and possibly nonportable prefixes into the
  // code?)
  for (n = 0; ; ++n) {
    if (n >= cmdsize) {
      // Command crosses end of memory block
      n = 0;
      im.prefixlist = 0; // Decode as standalone prefix
      break;
    }
    // Note that some CPUs treat REPx and LOCK as belonging to the same group.
    switch (cmd[n]) {
      case 0x26: prefix = PF_ES; prefixmask = PF_SEGMASK; break;
      case 0x2E: prefix = PF_CS; prefixmask = PF_SEGMASK; break;
      case 0x36: prefix = PF_SS; prefixmask = PF_SEGMASK; break;
      case 0x3E: prefix = PF_DS; prefixmask = PF_SEGMASK; break;
      case 0x64: prefix = PF_FS; prefixmask = PF_SEGMASK; break;
      case 0x65: prefix = PF_GS; prefixmask = PF_SEGMASK; break;
      case 0x66: prefix = prefixmask = PF_DSIZE; break;
      case 0x67: prefix = prefixmask = PF_ASIZE; break;
      case 0xF0: prefix = prefixmask = PF_LOCK; break;
      case 0xF2: prefix = PF_REPNE; prefixmask = PF_REPMASK; break;
      case 0xF3: prefix = PF_REP; prefixmask = PF_REPMASK; break;
      default: prefix = 0; break;
    }
    if (prefix == 0) break;
    if (im.prefixlist&prefixmask) { da.errors |= DAE_SAMEPREF; break; } // Two prefixes from the same group
    im.prefixlist |= prefix;
  }
  // There may be VEX prefix preceding command body. Yes, VEX is supported in
  // the 32-bit mode! And even in the 16-bit, but who cares?
  vex = 0;
  vexlead = 0;
  if (cmdsize >= n+3 && (*cast(ushort*)(cmd+n)&0xC0FE) == 0xC0C4) {
    // VEX is not compatible with LOCK, 66, F2 and F3 prefixes. VEX is not
    // compatible with REX, too, but REX prefixes are missing in 32-bit mode.
    if (im.prefixlist&(PF_LOCK|PF_66|PF_F2|PF_F3)) {
      da.errors |= DAE_SAMEPREF; // Incompatible prefixes
    } else {
      if (cmd[n] == 0xC5) {
        // 2-byte VEX prefix.
        im.prefixlist |= PF_VEX2;
        vex = cmd[n+1];
        vexlead = DX_VEX|DX_LEAD0F;
        n += 2;
      } else {
        // 3-byte VEX prefix.
        im.prefixlist |= PF_VEX3;
        vex = cmd[n+2]+(cmd[n+1]<<8); // Note the order of the bytes!
        switch (vex&0x1F00) {
          case 0x0100: vexlead = DX_VEX|DX_LEAD0F; n += 3; break;
          case 0x0200: vexlead = DX_VEX|DX_LEAD38; n += 3; break;
          case 0x0300: vexlead = DX_VEX|DX_LEAD3A; n += 3; break;
          default: vex = 0; break; // Unsupported VEX, decode as LES
        }
      }
      if (vex != 0) {
        // Get size of operands.
        if (vex&0x0004) im.ssesize = 32; // 256-bit SSE operands
        // Get register encoded in VEX prefix.
        vexreg = (~vex>>3)&0x07;
        // Check for SIMD prefix.
        switch (vex&0x03) {
          case 0x0001: im.prefixlist |= PF_66; break;
          case 0x0002: im.prefixlist |= PF_F3; break;
          case 0x0003: im.prefixlist |= PF_F2; break;
          default:
        }
      }
    }
    if (n >= cmdsize) { n = 0; vex = 0; im.prefixlist = 0; /*Decode as LES*/ } // Command crosses end of memory block
  }
  // We have gathered all prefixes, including those that are integral part of
  // the SSE command.
  if (n > 4 || (da.errors&DAE_SAMEPREF) != 0) {
    if (n > 4) da.errors |= DAE_MANYPREF;
    n = 0; im.prefixlist = 0; // Decode as standalone prefix
  }
  da.prefixes = im.prefixlist;
  da.nprefix = n;
  // Fetch first 4 bytes of the command and find start of command chain in the
  // command table.
  if (cmdsize >= n+uint.sizeof) {
    code = *cast(uint*)(cmd+n); // Optimization for most frequent case
  } else {
    code = cmd[n];
    if (cmdsize > n+1) (cast(ubyte*)&code)[1] = cmd[n+1];
    if (cmdsize > n+2) (cast(ubyte*)&code)[2] = cmd[n+2];
    if (cmdsize > n+3) (cast(ubyte*)&code)[3] = cmd[n+3];
  }
  // Walk chain and search for matching command. Command is matched if:
  // (1) code bits allowed in mask coincide in command and descriptor;
  // (2) when command type contains D_MEMORY, ModRegRM byte must indicate
  //     memory, and when type contains D_REGISTER, Mod must indicate register;
  // (3) when bits D_DATAxx or D_ADDRxx are set, size of data and/or code must
  //     match these bits;
  // (4) field D_MUSTMASK must match gathered prefixes;
  // (5) presence or absence of VEX prefix must be matched by DX_VEX. If VEX
  //     is present, implied leading bytes must match vexlead and bit L must
  //     match DX_VLMASK;
  // (6) if short form of string commands is requested, bit D_LONGFORM must be
  //     cleared, or segment override prefix other that DS:, or address size
  //     prefix must be present;
  // (7) when bit D_POSTBYTE is set, byte after ModRegRM/SIB/offset must match
  //     postbyte. Note that all postbyted commands include memory address in
  //     ModRegRM form and do not include immediate constants;
  // (8) if alternative forms of conditional commands are requested, command
  //     is conditional, and it is marked as DX_ZEROMASK or DX_CARRYMASK,
  //     check whether these bits match damode. (Conditional branch on flag
  //     Z!=0 can be disassembled either as JZ or JE. First form is preferrable
  //     after SUB or DEC; second form is more natural after CMP);
  // (9) if command has mnemonics RETN but alternative form RET is expected,
  //     skip it - RET will follow.
  success = 0;
  for (pchain = cmdchain+(code&CMDMASK); ; pchain = pchain.pnext) {
    if (pchain is null || pchain.pcmd is null) break; // End of chain, no match
    pcmd = pchain.pcmd;
    if (((code^pcmd.code)&pcmd.mask) != 0) continue; // (1) Different code bits
    cmdtype = pcmd.cmdtype;
    if ((damode&DA_TEXT) != 0) {
      if ((pcmd.exttype&DX_RETN) != 0 && config.useretform != 0) continue; // (9) RET form of near return expected
      if ((cmdtype&D_COND) != 0 && (pcmd.exttype&(DX_ZEROMASK|DX_CARRYMASK)) != 0) {
        if ((damode&DA_JZ) != 0 && (pcmd.exttype&DX_ZEROMASK) == DX_JE) continue; // (8) Wait for DX_JZ
        if ((damode&DA_JC) != 0 && (pcmd.exttype&DX_CARRYMASK) == DX_JB) continue; // (8) Wait for DX_JC
      }
    }
    if ((pcmd.exttype&(DX_VEX|DX_LEADMASK)) != vexlead) continue; // (5) Unmatched VEX prefix
    if (pcmd.exttype&DX_VEX) {
      if (((pcmd.exttype&DX_VLMASK) == DX_LSHORT && (vex&0x04) != 0) || ((pcmd.exttype&DX_VLMASK) == DX_LLONG && (vex&0x04) == 0)) continue; // (5) Unmatched VEX.L
    }
    if ((cmdtype&(D_MEMORY|D_REGISTER|D_LONGFORM|D_SIZEMASK|D_MUSTMASK|D_POSTBYTE)) == 0) { success = 1; break; } // Optimization for most frequent case
    switch (cmdtype&D_MUSTMASK) {
      case D_MUST66: // (4) (SSE) Requires 66, no F2 or F3
        if ((im.prefixlist&(PF_66|PF_F2|PF_F3)) != PF_66) continue;
        break;
      case D_MUSTF2: // (4) (SSE) Requires F2, no 66 or F3
        if ((im.prefixlist&(PF_66|PF_F2|PF_F3)) != PF_F2) continue;
        break;
      case D_MUSTF3: // (4) (SSE) Requires F3, no 66 or F2
        if ((im.prefixlist&(PF_66|PF_F2|PF_F3)) != PF_F3) continue;
        break;
      case D_MUSTNONE: // (4) (MMX, SSE) Requires no 66, F2, F3
        if ((im.prefixlist&(PF_66|PF_F2|PF_F3)) != 0) continue;
        break;
      case D_NEEDF2: // (4) (SSE) Requires F2, no F3
        if ((im.prefixlist&(PF_F2|PF_F3)) != PF_F2) continue;
        break;
      case D_NEEDF3: // (4) (SSE) Requires F3, no F2
        if ((im.prefixlist&(PF_F2|PF_F3)) != PF_F3) continue;
        break;
      case D_NOREP: // (4) Must not include F2 or F3
        if ((im.prefixlist&(PF_REP|PF_REPNE)) != 0) continue;
        break;
      case D_MUSTREP: // (4) Must include F3 (REP)
      case D_MUSTREPE: // (4) Must include F3 (REPE)
        if ((im.prefixlist&PF_REP) == 0) continue;
        break;
      case D_MUSTREPNE: // (4) Must include F2 (REPNE)
        if ((im.prefixlist&PF_REPNE) == 0) continue;
        break;
      default: break;
    }
    if ((cmdtype&D_DATA16) != 0 && (im.prefixlist&PF_DSIZE) == 0) continue; // (3) 16-bit data expected
    if ((cmdtype&D_DATA32) != 0 && (im.prefixlist&PF_DSIZE) != 0) continue; // (3) 32-bit data expected
    if ((cmdtype&D_ADDR16) != 0 && (im.prefixlist&PF_ASIZE) == 0) continue; // (3) 16-bit address expected
    if ((cmdtype&D_ADDR32) != 0 && (im.prefixlist&PF_ASIZE) != 0) continue; // (3) 32-bit address expected
    if ((cmdtype&D_LONGFORM) != 0 && config.shortstringcmds != 0 && (im.prefixlist&(PF_ES|PF_CS|PF_SS|PF_FS|PF_GS|PF_ASIZE)) == 0) continue; // (6) Short form of string cmd expected
    if (cmdtype&D_MEMORY) {
      // (2) Command expects operand in memory (Mod in ModRegRM is not 11b).
      if (n+pcmd.length >= cmdsize) break; // Command longer than available code
      if ((cmd[n+pcmd.length]&0xC0) == 0xC0) continue;
    } else if (cmdtype&D_REGISTER) {
      // (2) Command expects operand in register (Mod in ModRegRM is 11b).
      if (n+pcmd.length >= cmdsize) break; // Command longer than available code
      if ((cmd[n+pcmd.length]&0xC0) != 0xC0) continue;
    }
    if (cmdtype&D_POSTBYTE) {
      // Command expects postbyte after ModRegRM/SIB/offset as part of the
      // code. If command is longer than available code, immediately report
      // match - error will be reported elsewhere.
      m = n+pcmd.length; // Offset to ModRegRM byte
      if (m >= cmdsize) break; // Command longer than available code
      if (im.prefixlist&PF_ASIZE) {
        m += modrm16[cmd[m]].size; // 16-bit address
      } else {
        pmrm = modrm32.ptr+cmd[m];
        if (pmrm.psib is null) {
          m += pmrm.size; // 32-bit address without SIB
        } else if (m+1 >= cmdsize) {
          break; // Command longer than available code
        } else {
          m += pmrm.psib[cmd[m+1]].size; // 32-bit address with SIB
        }
      }
      if (m >= cmdsize) break; // Command longer than available code
      // Asterisk in SSE and AVX commands means comparison predicate. Check for predefined range.
      if (cmd[m] == cast(ubyte)pcmd.postbyte || ((cmdtype&D_WILDCARD) != 0 && cmd[m] < (pcmd.exttype & DX_VEX ? 32 : 8))) {
        im.immsize1 = 1; // (7) Interprete postbyte as imm const
      } else {
        continue; // (7)
      }
    }
    success = 1;
    break; // Perfect match, command found
  }
  // If command is bad but preceded with prefixes, decode first prefix as
  // standalone. In this case, list of command's prefixes is empty.
  if (success == 0) {
    pcmd = null;
    if (im.prefixlist != 0) {
      n = 0;
      da.nprefix = 0;
      da.prefixes = im.prefixlist = 0;
      code = cmd[n]&CMDMASK;
      for (pchain = cmdchain+code; ; pchain = pchain.pnext) {
        if (pchain is null || pchain.pcmd is null) { pcmd = null; break; } // End of chain, no match
        pcmd = pchain.pcmd;
        if ((pcmd.cmdtype&D_CMDTYPE) != D_PREFIX) continue;
        if (((code^pcmd.code)&pcmd.mask) == 0) {
          cmdtype = pcmd.cmdtype;
          da.errors |= DAE_BADCMD;
          break;
        }
      }
    }
    // If matching command is still not found, report error and return one byte
    // as a command length.
    if (pcmd is null) {
      if (damode&DA_DUMP) Thexdump(da.dump.ptr, cmd, 1, config.lowercase);
      if (damode&DA_TEXT) {
             if (config.disasmmode == DAMODE_HLA) j = Tcopycase(da.result.ptr, TEXTLEN, sizename[1].ptr, config.lowercase);
        else if (config.disasmmode == DAMODE_ATT) j = Tcopycase(da.result.ptr, TEXTLEN, sizeatt[1].ptr, config.lowercase);
        else j = Tcopycase(da.result.ptr, TEXTLEN, sizekey[1].ptr, config.lowercase);
        j += Tstrcopy(da.result.ptr+j, TEXTLEN-j, " ");
        Thexdump(da.result.ptr+j, cmd, 1, config.lowercase);
      }
      da.size = 1;
      da.nprefix = 0;
      da.prefixes = 0;
      da.cmdtype = D_BAD;
      da.exttype = 0;
      da.errors |= DAE_BADCMD; // Unrecognized command
      if (damode&DA_HILITE) {
        import core.stdc.string : strlen;
        da.masksize = strlen(da.result.ptr);
        memset(da.mask.ptr, DRAW_SUSPECT, da.masksize);
      }
      return 1;
    }
  }
  // Exclude prefixes that are integral part of the command from the list of
  // prefixes. First comparison optimizes for the most frequent case of no
  // obligatory prefixes.
  if (cmdtype&(D_SIZEMASK|D_MUSTMASK)) {
    switch (cmdtype&D_MUSTMASK) {
      case D_MUST66: // (SSE) Requires 66, no F2 or F3
      case D_MUSTF2: // (SSE) Requires F2, no 66 or F3
      case D_MUSTF3: // (SSE) Requires F3, no 66 or F2
        im.prefixlist &= ~(PF_66|PF_F2|PF_F3);
        break;
      case D_NEEDF2: // (SSE) Requires F2, no F3
      case D_NEEDF3: // (SSE) Requires F3, no F2
        im.prefixlist &= ~(PF_F2|PF_F3);
        break;
      default: break;
    }
    if (cmdtype&D_DATA16) im.prefixlist &= ~PF_DSIZE; // Must include data size prefix
    if (cmdtype&D_ADDR16) im.prefixlist &= ~PF_ASIZE; // Must include address size prefix
  }
  // Prepare for disassembling.
  im.modsize = 0; // Size of ModRegRM/SIB bytes
  im.dispsize = 0; // Size of address offset
  im.usesdatasize = 0;
  im.usesaddrsize = 0;
  im.usessegment = 0;
  da.cmdtype = cmdtype;
  da.exttype = pcmd.exttype;
  n += pcmd.length; // Offset of ModRegRM or imm constant
  if (n > cmdsize) { da.errors |= DAE_CROSS; goto error; } // Command crosses end of memory block
  im.mainsize = n; // Size of command with prefixes
  // Set default data size (note that many commands and operands override it).
  if ((cmdtype&D_SIZE01) != 0 && (cmd[n-1]&0x01) == 0) {
    if (im.prefixlist&PF_DSIZE) da.warnings |= DAW_DATASIZE; // Superfluous data size prefix
    datasize = 1;
  } else if (im.prefixlist&PF_DSIZE) {
    datasize = 2;
  } else {
    datasize = 4;
  }
  // Process operands.
  noperand = 0;
  for (i = 0; i < NOPERAND; i++) {
    arg = pcmd.arg[i];
    if ((arg&B_ARGMASK) == B_NONE) break; // Optimization for most frequent case
    // If pseudooperands to be skipped, I process them nevertheless. Such
    // operands may contain important information.
    if ((arg&B_PSEUDO) != 0 && (damode&DA_PSEUDO) == 0) {
      op = &pseudoop; // Request to skip pseudooperands
    } else {
      op = da.op.ptr+noperand++;
    }
    op.arg = arg;
    switch (arg&B_ARGMASK) {
      case B_AL: // Register AL
        Operandintreg(&im, 1, REG_AL, op);
        break;
      case B_AH: // Register AH
        Operandintreg(&im, 1, REG_AH, op);
        break;
      case B_AX: // Register AX
        Operandintreg(&im, 2, REG_EAX, op);
        break;
      case B_CL: // Register CL
        Operandintreg(&im, 1, REG_CL, op);
        break;
      case B_CX: // Register CX
        Operandintreg(&im, 2, REG_ECX, op);
        break;
      case B_DX: // Register DX
        Operandintreg(&im, 2, REG_EDX, op);
        break;
      case B_DXPORT: // Register DX as I/O port address
        Operandintreg(&im, 2, REG_EDX, op);
        op.features |= OP_PORT;
        break;
      case B_EAX: // Register EAX
        Operandintreg(&im, 4, REG_EAX, op);
        break;
      case B_EBX: // Register EBX
        Operandintreg(&im, 4, REG_EBX, op);
        break;
      case B_ECX: // Register ECX
        Operandintreg(&im, 4, REG_ECX, op);
        break;
      case B_EDX: // Register EDX
        Operandintreg(&im, 4, REG_EDX, op);
        break;
      case B_ACC: // Accumulator (AL/AX/EAX)
        Operandintreg(&im, datasize, REG_EAX, op);
        im.usesdatasize = 1;
        break;
      case B_STRCNT: // Register CX or ECX as REPxx counter
        Operandintreg(&im, (im.prefixlist&PF_ASIZE?2:4), REG_ECX, op);
        im.usesaddrsize = 1;
        break;
      case B_DXEDX: // Register DX or EDX in DIV/MUL
        Operandintreg(&im, datasize, REG_EDX, op);
        im.usesdatasize = 1;
        break;
      case B_BPEBP: // Register BP or EBP in ENTER/LEAVE
        Operandintreg(&im, datasize, REG_EBP, op);
        im.usesdatasize = 1;
        break;
      case B_REG: // 8/16/32-bit register in Reg
        // Note that all commands that use B_REG have also another operand
        // that requires ModRM, so we don't need to set modsize here.
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandintreg(&im, datasize, (cmd[n]>>3)&0x07, op);
          im.usesdatasize = 1;
        }
        break;
      case B_REG16: // 16-bit register in Reg
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandintreg(&im, 2, (cmd[n]>>3)&0x07, op);
        }
        break;
      case B_REG32: // 32-bit register in Reg
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandintreg(&im, 4, (cmd[n]>>3)&0x07, op);
        }
        break;
      case B_REGCMD: // 16/32-bit register in last cmd byte
        Operandintreg(&im, datasize, cmd[n-1]&0x07, op);
        im.usesdatasize = 1;
        break;
      case B_REGCMD8: // 8-bit register in last cmd byte
        Operandintreg(&im, 1, cmd[n-1]&0x07, op);
        break;
      case B_ANYREG: // Reg field is unused, any allowed
        break;
      case B_INT: // 8/16/32-bit register/memory in ModRM
      case B_INT1632: // 16/32-bit register/memory in ModRM
        k = Operandmodrm(&im, datasize, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandintreg(&im, datasize, cmd[n]&0x07, op);
        im.usesdatasize = 1;
        break;
      case B_INT8: // 8-bit register/memory in ModRM
        k = Operandmodrm(&im, 1, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandintreg(&im, 1, cmd[n]&0x07, op);
        break;
      case B_INT16: // 16-bit register/memory in ModRM
        k = Operandmodrm(&im, 2, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandintreg(&im, 2, cmd[n]&0x07, op);
        break;
      case B_INT32: // 32-bit register/memory in ModRM
        k = Operandmodrm(&im, 4, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandintreg(&im, 4, cmd[n]&0x07, op);
        break;
      case B_INT64: // 64-bit integer in ModRM, memory only
        k = Operandmodrm(&im, 8, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as 32-bit register and set error.
          Operandintreg(&im, 4, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
          //break;
        }
        break;
      case B_INT128: // 128-bit integer in ModRM, memory only
        k = Operandmodrm(&im, 16, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as 32-bit register and set error.
          Operandintreg(&im, 4, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
          //break;
        }
        break;
      case B_IMMINT: // 8/16/32-bit int at immediate addr
        Operandimmaddr(&im, datasize, cmd+n, cmdsize-n, op);
        im.usesdatasize = 1;
        break;
      case B_INTPAIR: // Two signed 16/32 in ModRM, memory only
        k = Operandmodrm(&im, 2*datasize, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        op.granularity = datasize;
        if (k == 0) {
          // Register is not allowed, decode as register and set error.
          Operandintreg(&im, datasize, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
          //break;
        }
        im.usesdatasize = 1;
        break;
      case B_SEGOFFS: // 16:16/16:32 absolute address in memory
        k = Operandmodrm(&im, datasize+2, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode and set error.
          Operandintreg(&im, datasize, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
          //break;
        }
        im.usesdatasize = 1;
        break;
      case B_STRDEST: // 8/16/32-bit string dest, [ES:(E)DI]
        Operandindirect(&im, REG_EDI, 1, SEG_ES, 0, datasize, op);
        im.usesdatasize = 1;
        break;
      case B_STRDEST8: // 8-bit string destination, [ES:(E)DI]
        Operandindirect(&im, REG_EDI, 1, SEG_ES, 0, 1, op);
        break;
      case B_STRSRC: // 8/16/32-bit string source, [(E)SI]
        Operandindirect(&im, REG_ESI, 1, SEG_UNDEF, 0, datasize, op);
        im.usesdatasize = 1;
        break;
      case B_STRSRC8: // 8-bit string source, [(E)SI]
        Operandindirect(&im, REG_ESI, 1, SEG_UNDEF, 0, 1, op);
        break;
      case B_XLATMEM: // 8-bit memory in XLAT, [(E)BX+AL]
        Operandxlat(&im, op);
        break;
      case B_EAXMEM: // Reference to memory addressed by [EAX]
        Operandindirect(&im, REG_EAX, 0, SEG_UNDEF, 4, 1, op);
        break;
      case B_LONGDATA: // Long data in ModRM, mem only
        k = Operandmodrm(&im, 256, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        op.granularity = 1; // Just a trick
        if (k == 0) {
          // Register is not allowed, decode and set error.
          Operandintreg(&im, 4, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
          //break;
        }
        im.usesdatasize = 1; // Caveat user
        break;
      case B_ANYMEM: // Reference to memory, data unimportant
        k = Operandmodrm(&im, 1, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode and set error.
          Operandintreg(&im, 4, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
        }
        break;
      case B_STKTOP: // 16/32-bit int top of stack
        Operandindirect(&im, REG_ESP, 1, SEG_SS, 0, datasize, op);
        im.usesdatasize = 1;
        break;
      case B_STKTOPFAR: // Top of stack (16:16/16:32 far addr)
        Operandindirect(&im, REG_ESP, 1, SEG_SS, 0, datasize*2, op);
        op.granularity = datasize;
        im.usesdatasize = 1;
        break;
      case B_STKTOPEFL: // 16/32-bit flags on top of stack
        Operandindirect(&im, REG_ESP, 1, SEG_SS, 0, datasize, op);
        im.usesdatasize = 1;
        break;
      case B_STKTOPA: // 16/32-bit top of stack all registers
        Operandindirect(&im, REG_ESP, 1, SEG_SS, 0, datasize*8, op);
        op.granularity = datasize;
        op.modifies = da.modifies = 0xFF;
        im.usesdatasize = 1;
        break;
      case B_PUSH:     // 16/32-bit int push to stack
      case B_PUSHRET:  // 16/32-bit push of return address
      case B_PUSHRETF: // 16:16/16:32-bit push of far retaddr
      case B_PUSHA:    // 16/32-bit push all registers
        Operandpush(&im, datasize, op);
        im.usesdatasize = 1;
        break;
      case B_EBPMEM: // 16/32-bit int at [EBP]
        Operandindirect(&im, REG_EBP, 1, SEG_SS, 0, datasize, op);
        im.usesdatasize = 1;
        break;
      case B_SEG: // Segment register in Reg
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandsegreg(&im, (cmd[n]>>3)&0x07, op);
        }
        break;
      case B_SEGNOCS: // Segment register in Reg, but not CS
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          k = (cmd[n]>>3)&0x07;
          Operandsegreg(&im, k, op);
          if (k == SEG_SS) da.exttype |= DX_WONKYTRAP;
          if (k == SEG_CS) {
            op.features |= OP_INVALID;
            da.errors |= DAE_BADSEG;
          }
        }
        break;
      case B_SEGCS: // Segment register CS
        Operandsegreg(&im, SEG_CS, op);
        break;
      case B_SEGDS: // Segment register DS
        Operandsegreg(&im, SEG_DS, op);
        break;
      case B_SEGES: // Segment register ES
        Operandsegreg(&im, SEG_ES, op);
        break;
      case B_SEGFS: // Segment register FS
        Operandsegreg(&im, SEG_FS, op);
        break;
      case B_SEGGS: // Segment register GS
        Operandsegreg(&im, SEG_GS, op);
        break;
      case B_SEGSS: // Segment register SS
        Operandsegreg(&im, SEG_SS, op);
        break;
      case B_ST: // 80-bit FPU register in last cmd byte
        Operandfpureg(&im, cmd[n-1]&0x07, op);
        break;
      case B_ST0: // 80-bit FPU register ST0
        Operandfpureg(&im, 0, op);
        break;
      case B_ST1: // 80-bit FPU register ST1
        Operandfpureg(&im, 1, op);
        break;
      case B_FLOAT32: // 32-bit float in ModRM, memory only
        k = Operandmodrm(&im, 4, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as FPU register and set error.
          Operandfpureg(&im, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
        }
        break;
      case B_FLOAT64: // 64-bit float in ModRM, memory only
        k = Operandmodrm(&im, 8, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as FPU register and set error.
          Operandfpureg(&im, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
        }
        break;
      case B_FLOAT80: // 80-bit float in ModRM, memory only
        k = Operandmodrm(&im, 10, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as FPU register and set error.
          Operandfpureg(&im, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
        }
        break;
      case B_BCD: // 80-bit BCD in ModRM, memory only
        k = Operandmodrm(&im, 10, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as FPU register and set error.
          Operandfpureg(&im, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
        }
        break;
      case B_MREG8x8:  // MMX register as 8 8-bit integers
      case B_MREG16x4: // MMX register as 4 16-bit integers
      case B_MREG32x2: // MMX register as 2 32-bit integers
      case B_MREG64:   // MMX register as 1 64-bit integer
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandmmxreg(&im, (cmd[n]>>3)&0x07, op);
          op.granularity = Getgranularity(arg);
        }
        break;
      case B_MMX8x8:  // MMX reg/memory as 8 8-bit integers
      case B_MMX16x4: // MMX reg/memory as 4 16-bit integers
      case B_MMX32x2: // MMX reg/memory as 2 32-bit integers
      case B_MMX64:   // MMX reg/memory as 1 64-bit integer
        k = Operandmodrm(&im, 8, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandmmxreg(&im, cmd[n]&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_MMX8x8DI: // MMX 8 8-bit integers at [DS:(E)DI]
        Operandindirect(&im, REG_EDI, 0, SEG_UNDEF, 0, 8, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_3DREG: // 3DNow! register as 2 32-bit floats
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandnowreg(&im, (cmd[n]>>3)&0x07, op);
          op.granularity = 4;
        }
        break;
      case B_3DNOW: // 3DNow! reg/memory as 2 32-bit floats
        k = Operandmodrm(&im, 8, cmd+n, cmdsize-n, op);
        if (k < 0) break;                // Error in address
        if (k == 0) Operandnowreg(&im, cmd[n]&0x07, op);
        op.granularity = 4;
        break;
      case B_SREGF32x4:  // SSE register as 4 32-bit floats
      case B_SREGF32L:   // Low 32-bit float in SSE register
      case B_SREGF32x2L: // Low 2 32-bit floats in SSE register
      case B_SREGF64x2:  // SSE register as 2 64-bit floats
      case B_SREGF64L:   // Low 64-bit float in SSE register
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandssereg(&im, (cmd[n]>>3)&0x07, op);
          op.granularity = Getgranularity(arg);
        }
        break;
      case B_SVEXF32x4: // SSE reg in VEX as 4 32-bit floats
      case B_SVEXF32L:  // Low 32-bit float in SSE in VEX
      case B_SVEXF64x2: // SSE reg in VEX as 2 64-bit floats
      case B_SVEXF64L:  // Low 64-bit float in SSE in VEX
        Operandssereg(&im, vexreg, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEF32x4: // SSE reg/memory as 4 32-bit floats
      case B_SSEF64x2: // SSE reg/memory as 2 64-bit floats
        k = Operandmodrm(&im, (arg&B_NOVEXSIZE ? 16 : im.ssesize), cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEF32L: // Low 32-bit float in SSE reg/memory
        k = Operandmodrm(&im, 4, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op); // Operand in SSE register
        op.granularity = 4;
        break;
      case B_SSEF32x2L: // Low 2 32-bit floats in SSE reg/memory
        k = Operandmodrm(&im, (arg&B_NOVEXSIZE ? 16 : im.ssesize)/2, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op); // Operand in SSE register
        op.granularity = 4;
        break;
      case B_SSEF64L: // Low 64-bit float in SSE reg/memory
        k = Operandmodrm(&im, 8, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op); // Operand in SSE register
        op.granularity = 8;
        break;
      case B_XMM0I32x4: // XMM0 as 4 32-bit integers
      case B_XMM0I64x2: // XMM0 as 2 64-bit integers
      case B_XMM0I8x16: // XMM0 as 16 8-bit integers
        Operandssereg(&im, 0, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SREGI8x16:  // SSE register as 16 8-bit sigints
      case B_SREGI16x8:  // SSE register as 8 16-bit sigints
      case B_SREGI32x4:  // SSE register as 4 32-bit sigints
      case B_SREGI64x2:  // SSE register as 2 64-bit sigints
      case B_SREGI32L:   // Low 32-bit sigint in SSE register
      case B_SREGI32x2L: // Low 2 32-bit sigints in SSE register
      case B_SREGI64L:   // Low 64-bit sigint in SSE register
        if (n >= cmdsize) {
          da.errors |= DAE_CROSS; // Command crosses end of memory block
        } else {
          Operandssereg(&im, (cmd[n]>>3)&0x07, op);
          op.granularity = Getgranularity(arg);
        }
        break;
      case B_SVEXI8x16: // SSE reg in VEX as 16 8-bit sigints
      case B_SVEXI16x8: // SSE reg in VEX as 8 16-bit sigints
      case B_SVEXI32x4: // SSE reg in VEX as 4 32-bit sigints
      case B_SVEXI64x2: // SSE reg in VEX as 2 64-bit sigints
        Operandssereg(&im, vexreg, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEI8x16: // SSE reg/memory as 16 8-bit sigints
      case B_SSEI16x8: // SSE reg/memory as 8 16-bit sigints
      case B_SSEI32x4: // SSE reg/memory as 4 32-bit sigints
      case B_SSEI64x2: // SSE reg/memory as 2 64-bit sigints
        k = Operandmodrm(&im, (arg&B_NOVEXSIZE ? 16 : im.ssesize), cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEI8x8L:  // Low 8 8-bit ints in SSE reg/memory
      case B_SSEI16x4L: // Low 4 16-bit ints in SSE reg/memory
      case B_SSEI32x2L: // Low 2 32-bit sigints in SSE reg/memory
        k = Operandmodrm(&im, (arg&B_NOVEXSIZE ? 16 : im.ssesize)/2, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEI8x4L:  // Low 4 8-bit ints in SSE reg/memory
      case B_SSEI16x2L: // Low 2 16-bit ints in SSE reg/memory
        k = Operandmodrm(&im, 4, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEI8x2L: // Low 2 8-bit ints in SSE reg/memory
        k = Operandmodrm(&im, 2, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) Operandssereg(&im, cmd[n]&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_SSEI8x16DI: // SSE 16 8-bit sigints at [DS:(E)DI]
        Operandindirect(&im, REG_EDI, 0, SEG_UNDEF, 0, (arg&B_NOVEXSIZE ? 16 : im.ssesize), op);
        op.granularity = 1;
        break;
      case B_EFL: // Flags register EFL
        Operandefl(&im, 4, op);
        break;
      case B_FLAGS8: // Flags (low byte)
        Operandefl(&im, 1, op);
        break;
      case B_OFFSET: // 16/32 const offset from next command
        Operandoffset(&im, datasize, datasize, cmd+n, cmdsize-n, da.ip+n, op);
        break;
      case B_BYTEOFFS: // 8-bit sxt const offset from next cmd
        Operandoffset(&im, 1, datasize, cmd+n, cmdsize-n, da.ip+n, op);
        break;
      case B_FARCONST: // 16:16/16:32 absolute address constant
        Operandimmfaraddr(&im, datasize, cmd+n, cmdsize-n, op);
        break;
      case B_DESCR: // 16:32 descriptor in ModRM
        k = Operandmodrm(&im, 6, cmd+n, cmdsize-n, op);
        if (k < 0) break; // Error in address
        if (k == 0) {
          // Register is not allowed, decode as 32-bit register and set error.
          Operandintreg(&im, 4, cmd[n]&0x07, op);
          op.features |= OP_INVALID;
          da.errors |= DAE_MEMORY;
        }
        break;
      case B_1: // Immediate constant 1
        Operandone(&im, op);
        break;
      case B_CONST8: // Immediate 8-bit constant
        Operandimmconst(&im, 1, 1, datasize, cmd+n, cmdsize-n, 0, op);
        if (arg&B_PORT) op.features |= OP_PORT;
        break;
      case B_SIMMI8x16: // SSE reg in immediate 8-bit constant
        if (cmdsize-n < im.modsize+im.dispsize+1) { da.errors |= DAE_CROSS; break; } // Command crosses end of memory block
        im.immsize1 = 1;
        Operandssereg(&im, (cmd[n+im.modsize+im.dispsize]>>4)&0x07, op);
        op.granularity = Getgranularity(arg);
        break;
      case B_CONST8_2: // Immediate 8-bit const, second in cmd
        Operandimmconst(&im, 1, 1, datasize, cmd+n, cmdsize-n, 1, op);
        break;
      case B_CONST16: // Immediate 16-bit constant
        Operandimmconst(&im, 2, 2, datasize, cmd+n, cmdsize-n, 0, op);
        break;
      case B_CONST:  // Immediate 8/16/32-bit constant
      case B_CONSTL: // Immediate 16/32-bit constant
        Operandimmconst(&im, datasize, datasize, datasize, cmd+n, cmdsize-n, 0, op);
        im.usesdatasize = 1;
        break;
      case B_SXTCONST: // Immediate 8-bit sign-extended to size
        Operandimmconst(&im, 1, datasize, datasize, cmd+n, cmdsize-n, 0, op);
        im.usesdatasize = 1;
        break;
      case B_CR: // Control register in Reg
        Operandcreg(&im, (cmd[n]>>3)&0x07, op);
        break;
      case B_CR0: // Control register CR0
        Operandcreg(&im, 0, op);
        break;
      case B_DR:                       // Debug register in Reg
        Operanddreg(&im, (cmd[n]>>3)&0x07, op);
        break;
      case B_FST: // FPU status register
        Operandfst(&im, op);
        break;
      case B_FCW: // FPU control register
        Operandfcw(&im, op);
        break;
      case B_MXCSR: // SSE media control and status register
        Operandmxcsr(&im, op);
        break;
      default: // Internal error
        da.errors |= DAE_INTERN;
        break;
    }
    if ((arg&B_32BITONLY) != 0 && op.opsize != 4) da.warnings |= DAW_NONCLASS;
    if ((arg&B_MODMASK) == B_JMPCALLFAR) da.warnings |= DAW_FARADDR;
    if (arg&B_PSEUDO) op.features |= OP_PSEUDO;
    if (arg&(B_CHG|B_UPD)) op.features |= OP_MOD;
  }
  // Optimization for most frequent case
  if (im.prefixlist != 0) {
    // If LOCK prefix is present, report error if prefix is not allowed by
    // command and warning otherwise. Application code usually doesn't need
    // atomic bus access.
    if ((im.prefixlist&PF_LOCK) != 0) { if ((cmdtype&D_LOCKABLE) == 0) da.errors |= DAE_LOCK; else da.warnings |= DAW_LOCK; }
    // Warn if data size prefix is present but not used by command.
    if ((im.prefixlist&PF_DSIZE) != 0 && im.usesdatasize == 0 && (pcmd.exttype&DX_TYPEMASK) != DX_NOP) da.warnings |= DAW_DATASIZE;
    // Warn if address size prefix is present but not used by command.
    if ((im.prefixlist&PF_ASIZE) != 0 && im.usesaddrsize == 0) da.warnings |= DAW_ADDRSIZE;
    // Warn if segment override prefix is present but command doesn't access
    // memory. Prefixes CS: and DS: are also used as branch hints in
    // conditional branches.
    if ((im.prefixlist&PF_SEGMASK) != 0 && im.usessegment == 0) { if ((cmdtype&D_BHINT) == 0 || (im.prefixlist&PF_HINT) == 0) da.warnings |= DAW_SEGPREFIX; }
    // Warn if REPxx prefix is present but not used by command. Attention,
    // Intel frequently uses these prefixes for different means!
    if (im.prefixlist&PF_REPMASK) {
      if (((im.prefixlist&PF_REP) != 0 && (cmdtype&D_MUSTMASK) != D_MUSTREP && (cmdtype&D_MUSTMASK) != D_MUSTREPE) ||
          ((im.prefixlist&PF_REPNE) != 0 && (cmdtype&D_MUSTMASK) != D_MUSTREPNE))
      {
        da.warnings |= DAW_REPPREFIX;
      }
    }
  }
  // Warn on unaligned stack, I/O and privileged commands.
  switch (cmdtype&D_CMDTYPE) {
    case D_PUSH: if (datasize == 2) da.warnings |= DAW_STACK; break;
    case D_INT: da.warnings |= DAW_INTERRUPT; break;
    case D_IO: da.warnings |= DAW_IO; break;
    case D_PRIVILEGED: da.warnings |= DAW_PRIV; break;
    default:
  }
  // Warn on system, privileged  and undocumented commands.
  if ((cmdtype&D_USEMASK) != 0) {
    if ((cmdtype&D_USEMASK) == D_RARE || (cmdtype&D_USEMASK) == D_SUSPICIOUS) da.warnings |= DAW_RARE;
    if ((cmdtype&D_USEMASK) == D_UNDOC) da.warnings |= DAW_NONCLASS;
  }
  // If command implicitly changes ESP, it uses and modifies this register.
  if (cmdtype&D_CHGESP) {
    da.uses |= (1<<REG_ESP);
    da.modifies |= (1<<REG_ESP);
  }
error:
  // Prepare hex dump, if requested. As maximal size of command is limited to
  // MAXCMDSIZE = 16 bytes, string can't overflow.
  if (damode&DA_DUMP) {
    if (da.errors&DAE_CROSS) {
      // Incomplete command
      Thexdump(da.dump.ptr, cmd, cmdsize, config.lowercase);
    } else {
      j = 0;
      // Dump prefixes. REPxx is treated as prefix and separated from command
      // with semicolon; prefixes 66, F2 and F3 that are part of SSE command
      // are glued with command's body - well, at least if there are no other
      // prefixes inbetween.
      for (u = 0; u < da.nprefix; ++u) {
        j += Thexdump(da.dump.ptr+j, cmd+u, 1, config.lowercase);
        if (cmd[u] == 0x66 && (cmdtype&D_MUSTMASK) == D_MUST66) continue;
        if (cmd[u] == 0xF2 && ((cmdtype&D_MUSTMASK) == D_MUSTF2 || (cmdtype&D_MUSTMASK) == D_NEEDF2)) continue;
        if (cmd[u] == 0xF3 && ((cmdtype&D_MUSTMASK) == D_MUSTF3 || (cmdtype&D_MUSTMASK) == D_NEEDF3)) continue;
        if ((im.prefixlist&(PF_VEX2|PF_VEX3)) != 0 && u == da.nprefix-2) continue;
        if ((im.prefixlist&PF_VEX3) != 0 && u == da.nprefix-3) continue;
        da.dump[j++] = ':';
      }
      // Dump body of the command, including ModRegRM and SIB bytes.
      j += Thexdump(da.dump.ptr+j, cmd+u, im.mainsize+im.modsize-u, config.lowercase);
      // Dump displacement, if any, separated with space from command's body.
      if (im.dispsize > 0) {
        da.dump[j++] = ' ';
        j += Thexdump(da.dump.ptr+j, cmd+im.mainsize+im.modsize, im.dispsize, config.lowercase);
      }
      // Dump immediate constants, if any.
      if (im.immsize1 > 0) {
        da.dump[j++] = ' ';
        j += Thexdump(da.dump.ptr+j, cmd+im.mainsize+im.modsize+im.dispsize, im.immsize1, config.lowercase);
      }
      if (im.immsize2 > 0) {
        da.dump[j++] = ' ';
        Thexdump(da.dump.ptr+j, cmd+im.mainsize+im.modsize+im.dispsize+im.immsize1, im.immsize2, config.lowercase);
      }
    }
  }
  // Prepare disassembled command. There are many options that control look
  // and feel of disassembly, so the procedure is a bit, errr, boring.
  if (damode&DA_TEXT) {
    if (da.errors&DAE_CROSS) {
      // Incomplete command
      q = Tstrcopy(da.result.ptr, TEXTLEN, "???");
      if (damode&DA_HILITE) {
        memset(da.mask.ptr, DRAW_SUSPECT, q);
        da.masksize = q;
      }
    } else {
      j = 0;
      // If LOCK and/or REPxx prefix is present, prepend it to the command.
      // Such cases are rare, first comparison makes small optimization.
      if (im.prefixlist&(PF_LOCK|PF_REPMASK)) {
        if (im.prefixlist&PF_LOCK) j = Tcopycase(da.result.ptr, TEXTLEN, "LOCK ", config.lowercase);
             if (im.prefixlist&PF_REPNE) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "REPNE ", config.lowercase);
        else if (im.prefixlist&PF_REP) {
          if ((cmdtype&D_MUSTMASK) == D_MUSTREPE) {
            j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "REPE ", config.lowercase);
          } else {
            j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "REP ", config.lowercase);
          }
        }
      }
      // If there is a branch hint, prefix jump mnemonics with '+' (taken) or
      // '-' (not taken), or use pseudoprefixes BHT/BHNT. I don't know how MASM
      // indicates hints.
      if (cmdtype&D_BHINT) {
        if (config.jumphintmode == 0) {
               if (im.prefixlist&PF_TAKEN) da.result[j++] = '+';
          else if (im.prefixlist&PF_NOTTAKEN) da.result[j++] = '-';
        } else {
               if (im.prefixlist&PF_TAKEN) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "BHT ", config.lowercase);
          else if (im.prefixlist&PF_NOTTAKEN) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "BHNT ", config.lowercase);
        }
      }
      // Get command mnemonics. If mnemonics contains asterisk, it must be
      // replaced by W, D or none according to sizesens. Asterisk in SSE and
      // AVX commands means comparison predicate.
      if (cmdtype&D_WILDCARD) {
        for (i = 0; ; ++i) {
               if (pcmd.name[i] == '\0') break;
          else if (pcmd.name[i] != '*') da.result[j++] = pcmd.name[i];
          else if (cmdtype&D_POSTBYTE) j += Tstrcopy(da.result.ptr+j, TEXTLEN-j, ssepredicate[cmd[im.mainsize+im.modsize+im.dispsize]].ptr);
          else if (datasize == 4 && (config.sizesens == 0 || config.sizesens == 1)) da.result[j++] = 'D';
          else if (datasize == 2 && (config.sizesens == 1 || config.sizesens == 2)) da.result[j++] = 'W';
        }
        da.result[j] = '\0';
        if (config.lowercase) tstrlwr(da.result);
      } else {
        j += Tcopycase(da.result.ptr+j, TEXTLEN-j, pcmd.name.ptr, config.lowercase);
        if (config.disasmmode == DAMODE_ATT && im.usesdatasize != 0) {
          // AT&T mnemonics are suffixed with the operand's size.
          if ((cmdtype&D_CMDTYPE) != D_CMD &&
              (cmdtype&D_CMDTYPE) != D_MOV &&
              (cmdtype&D_CMDTYPE) != D_MOVC &&
              (cmdtype&D_CMDTYPE) != D_TEST &&
              (cmdtype&D_CMDTYPE) != D_STRING &&
              (cmdtype&D_CMDTYPE) != D_PUSH &&
              (cmdtype&D_CMDTYPE) != D_POP) {}
          else if (datasize == 1) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "B", config.lowercase);
          else if (datasize == 2) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "W", config.lowercase);
          else if (datasize == 4) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "L", config.lowercase);
          else if (datasize == 8) j += Tcopycase(da.result.ptr+j, TEXTLEN-j, "Q", config.lowercase);
        }
      }
      if (damode&DA_HILITE) {
        type = cmdtype&D_CMDTYPE;
        if (da.errors != 0) {
          cfill = DRAW_SUSPECT;
        } else {
          switch (cmdtype&D_CMDTYPE) {
            case D_JMP:                  // Unconditional near jump
            case D_JMPFAR:               // Unconditional far jump
              cfill = DRAW_JUMP; break;
            case D_JMC:                  // Conditional jump on flags
            case D_JMCX:                 // Conditional jump on (E)CX (and flags)
              cfill = DRAW_CJMP; break;
            case D_PUSH:                 // PUSH exactly 1 (d)word of data
            case D_POP:                  // POP exactly 1 (d)word of data
              cfill = DRAW_PUSHPOP; break;
            case D_CALL:                 // Plain near call
            case D_CALLFAR:              // Far call
            case D_INT:                  // Interrupt
              cfill = DRAW_CALL; break;
            case D_RET:                  // Plain near return from call
            case D_RETFAR:               // Far return or IRET
              cfill = DRAW_RET; break;
            case D_FPU:                  // FPU command
            case D_MMX:                  // MMX instruction, incl. SSE extensions
            case D_3DNOW:                // 3DNow! instruction
            case D_SSE:                  // SSE instruction
            case D_AVX:                  // AVX instruction
              cfill = DRAW_FPU; break;
            case D_IO:                   // Accesses I/O ports
            case D_SYS:                  // Legal but useful in system code only
            case D_PRIVILEGED:           // Privileged (non-Ring3) command
              cfill = DRAW_SUSPECT; break;
            default:
              cfill = DRAW_PLAIN;
            break;
          }
        }
        memset(da.mask.ptr, cfill, j);
        da.masksize = j;
      }
      // Add decoded operands. In HLA mode, order of operands is inverted
      // except for comparison commands (marked with bit D_HLADIR) and
      // arguments are enclosed in parenthesis (except for immediate jumps).
      // In AT&T mode, order of operands is always inverted. Operands of type
      // B_PSEUDO are implicit and don't appear in text.
      if (config.disasmmode == DAMODE_HLA && (pcmd.arg[0]&B_ARGMASK) != B_OFFSET && (pcmd.arg[0]&B_ARGMASK) != B_BYTEOFFS && (pcmd.arg[0]&B_ARGMASK) != B_FARCONST) {
        enclose = 1; // Enclose operand list in parenthesis
      } else {
        enclose = 0;
      }
      if ((damode&DA_HILITE) != 0 && config.hiliteoperands != 0) cfill = DRAW_PLAIN;
      nout = 0;
      for (i = 0; i < noperand; ++i) {
        if ((config.disasmmode == DAMODE_HLA && (cmdtype&D_HLADIR) == 0) || config.disasmmode == DAMODE_ATT) {
          k = noperand-1-i; // Inverted (HLA/AT&T) order of operands
        } else {
          k = i; // Direct (Intel's) order of operands
        }
        arg = da.op[k].arg;
        if ((arg&B_ARGMASK) == B_NONE || (arg&B_PSEUDO) != 0) continue; // Empty or implicit operand
        q = j;
        if (nout == 0) {
          // Spaces between mnemonic and first operand.
          da.result[j++] = ' ';
          if (config.tabarguments) { for ( ; j < 8; ++j) da.result[j] = ' '; }
          if (enclose) {
            da.result[j++] = '(';
            if (config.extraspace) da.result[j++] = (' ');
          }
        } else {
          // Comma and optional space between operands.
          da.result[j++] = ',';
          if (config.extraspace) da.result[j++] = ' ';
        }
        if (damode&DA_HILITE) {
          memset(da.mask.ptr+q, cfill, j-q);
          da.masksize = j;
        }
        // Operand itself.
        q = j;
        op = da.op.ptr+k;
        j += Tstrcopy(da.result.ptr+j, TEXTLEN-j-10, op.text.ptr);
        if (damode&DA_HILITE) {
               if (config.hiliteoperands == 0) ofill = cfill;
          else if (op.features&OP_REGISTER) ofill = DRAW_IREG;
          else if (op.features&(OP_FPUREG|OP_MMXREG|OP_3DNOWREG|OP_SSEREG)) ofill = DRAW_FREG;
          else if (op.features&(OP_SEGREG|OP_CREG|OP_DREG)) ofill = DRAW_SYSREG;
          else if (op.features&OP_MEMORY) { if (op.scale[REG_ESP] != 0 || op.scale[REG_EBP] != 0) ofill = DRAW_STKMEM; else ofill = DRAW_MEM; }
          else if (op.features&OP_CONST) ofill = DRAW_CONST;
          else ofill = cfill;
          memset(da.mask.ptr+q, ofill, j-q);
          da.masksize = j;
        }
        ++nout;
      }
      // All arguments added, close list.
      if (enclose && nout != 0) {
        q = j;
        if (config.extraspace) da.result[j++] = ' ';
        da.result[j++] = ')';
        if (damode&DA_HILITE) {
          memset(da.mask.ptr+q, cfill, j-q);
          da.masksize = j;
        }
      }
      da.result[j] = '\0';
    }
  }
  // Calculate total size of command.
  if (da.errors&DAE_CROSS) {
    // Incomplete command
    n = cmdsize;
  } else {
    n += im.modsize+im.dispsize+im.immsize1+im.immsize2;
  }
  da.size = n;
  return n;
}

// Given error and warning lists, returns pointer to the string describing
// relatively most severe error or warning, or null if there are no errors or
// warnings.
public string disErrMessage (uint errors, uint warnings) {
  if (errors == 0 && warnings == 0) return null;

  if (errors&DAE_BADCMD) return "Unknown command";
  if (errors&DAE_CROSS) return "Command crosses end of memory block";
  if (errors&DAE_MEMORY) return "Illegal use of register";
  if (errors&DAE_REGISTER) return "Memory address is not allowed";
  if (errors&DAE_LOCK) return "LOCK prefix is not allowed";
  if (errors&DAE_BADSEG) return "Invalid segment register";
  if (errors&DAE_SAMEPREF) return "Two prefixes from the same group";
  if (errors&DAE_MANYPREF) return "More than 4 prefixes";
  if (errors&DAE_BADCR) return "Invalid CR register";
  if (errors&DAE_INTERN) return "Internal OllyDbg error";

  if (warnings&DAW_DATASIZE) return "Superfluous operand size prefix";
  if (warnings&DAW_ADDRSIZE) return "Superfluous address size prefix";
  if (warnings&DAW_SEGPREFIX) return "Superfluous segment override prefix";
  if (warnings&DAW_REPPREFIX) return "Superfluous REPxx prefix";
  if (warnings&DAW_DEFSEG) return "Explicit default segment register";
  if (warnings&DAW_JMP16) return "16-bit jump, call or return";
  if (warnings&DAW_FARADDR) return "Far jump or call";
  if (warnings&DAW_SEGMOD) return "Modification of segment register";
  if (warnings&DAW_PRIV) return "Privileged instruction";
  if (warnings&DAW_IO) return "I/O command";
  if (warnings&DAW_SHIFT) return "Shift out of range";
  if (warnings&DAW_LOCK) return "Command uses (valid) LOCK prefix";
  if (warnings&DAW_STACK) return "Unaligned stack operation";
  if (warnings&DAW_NOESP) return "Suspicious use of stack pointer";
  if (warnings&DAW_NONCLASS) return "Undocumented instruction or encoding";

  return null;
}
