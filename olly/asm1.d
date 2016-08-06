// Free Disassembler and Assembler -- Header file
//
// Copyright (C) 2001 Oleh Yuschuk
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
module iv.olly.asm1;


/// Model to search for assembler command
public struct AsmModel {
  ubyte[ASMMAXCMDSIZE] code; /// Binary code
  ubyte[ASMMAXCMDSIZE] mask; /// Mask for binary code (0: bit ignored)
  int length;             /// Length of code, bytes (0: empty)
  int jmpsize;            /// Offset size if relative jump
  int jmpoffset;          /// Offset relative to IP
  int jmppos;             /// Position of jump offset in command
}

/// Assembler options
public struct AsmOptions {
  bool ideal = true;    /// Force IDEAL decoding mode
  bool sizesens = true; /// How to decode size-sensitive mnemonics
}


// ////////////////////////////////////////////////////////////////////////// //
private:

enum PSEUDOOP = 128; // Base for pseudooperands
enum TEXTLEN = 256; // Maximal length of text string

// Special command features.
enum {
  WW = 0x01, // Bit W (size of operand)
  SS = 0x02, // Bit S (sign extention of immediate)
  WS = 0x03, // Bits W and S
  W3 = 0x08, // Bit W at position 3
  CC = 0x10, // Conditional jump
  FF = 0x20, // Forced 16-bit size
  LL = 0x40, // Conditional loop
  PR = 0x80, // Protected command
  WP = 0x81, // I/O command with bit W
}

// All possible types of operands in 80x86. A bit more than you expected, he?
enum {
  NNN, // No operand
  REG, // Integer register in Reg field
  RCM, // Integer register in command byte
  RG4, // Integer 4-byte register in Reg field
  RAC, // Accumulator (AL/AX/EAX, implicit)
  RAX, // AX (2-byte, implicit)
  RDX, // DX (16-bit implicit port address)
  RCL, // Implicit CL register (for shifts)
  RS0, // Top of FPU stack (ST(0), implicit)
  RST, // FPU register (ST(i)) in command byte
  RMX, // MMX register MMx
  R3D, // 3DNow! register MMx
  MRG, // Memory/register in ModRM byte
  MR1, // 1-byte memory/register in ModRM byte
  MR2, // 2-byte memory/register in ModRM byte
  MR4, // 4-byte memory/register in ModRM byte
  RR4, // 4-byte memory/register (register only)
  MR8, // 8-byte memory/MMX register in ModRM
  RR8, // 8-byte MMX register only in ModRM
  MRD, // 8-byte memory/3DNow! register in ModRM
  RRD, // 8-byte memory/3DNow! (register only)
  MRJ, // Memory/reg in ModRM as JUMP target
  MMA, // Memory address in ModRM byte for LEA
  MML, // Memory in ModRM byte (for LES)
  MMS, // Memory in ModRM byte (as SEG:OFFS)
  MM6, // Memory in ModRm (6-byte descriptor)
  MMB, // Two adjacent memory locations (BOUND)
  MD2, // Memory in ModRM (16-bit integer)
  MB2, // Memory in ModRM (16-bit binary)
  MD4, // Memory in ModRM byte (32-bit integer)
  MD8, // Memory in ModRM byte (64-bit integer)
  MDA, // Memory in ModRM byte (80-bit BCD)
  MF4, // Memory in ModRM byte (32-bit float)
  MF8, // Memory in ModRM byte (64-bit float)
  MFA, // Memory in ModRM byte (80-bit float)
  MFE, // Memory in ModRM byte (FPU environment)
  MFS, // Memory in ModRM byte (FPU state)
  MFX, // Memory in ModRM byte (ext. FPU state)
  MSO, // Source in string op's ([ESI])
  MDE, // Destination in string op's ([EDI])
  MXL, // XLAT operand ([EBX+AL])
  IMM, // Immediate data (8 or 16/32)
  IMU, // Immediate unsigned data (8 or 16/32)
  VXD, // VxD service
  IMX, // Immediate sign-extendable byte
  C01, // Implicit constant 1 (for shifts)
  IMS, // Immediate byte (for shifts)
  IM1, // Immediate byte
  IM2, // Immediate word (ENTER/RET)
  IMA, // Immediate absolute near data address
  JOB, // Immediate byte offset (for jumps)
  JOW, // Immediate full offset (for jumps)
  JMF, // Immediate absolute far jump/call addr
  SGM, // Segment register in ModRM byte
  SCM, // Segment register in command byte
  CRX, // Control register CRx
  DRX, // Debug register DRx
}

// Pseudooperands (implicit operands, never appear in assembler commands). Must
// have index equal to or exceeding PSEUDOOP.
enum {
  PRN = PSEUDOOP, // Near return address
  PRF, // Far return address
  PAC, // Accumulator (AL/AX/EAX)
  PAH, // AH (in LAHF/SAHF commands)
  PFL, // Lower byte of flags (in LAHF/SAHF)
  PS0, // Top of FPU stack (ST(0))
  PS1, // ST(1)
  PCX, // CX/ECX
  PDI, // EDI (in MMX extentions)
}

struct AsmAddrDec {
  int defseg;
  string descr;
}

struct AsmInstrData {
  uint mask;              // Mask for first 4 bytes of the command
  uint code;              // Compare masked bytes with this
  ubyte len;              // Length of the main command code
  ubyte bits;             // Special bits within the command
  ubyte arg1, arg2, arg3; // Types of possible arguments
  ubyte type;             // C_xxx + additional information
  string name;            // Symbolic name for this command
}


// ////////////////////////////////////////////////////////////////////////// //
// ///////////////// ASSEMBLER, DISASSEMBLER AND EXPRESSIONS //////////////// //
public enum ASMMAXCMDSIZE = 16; // Maximal length of 80x86 command
public enum ASMMAXCALSIZE = 8; // Max length of CALL without prefixes
public enum ASMNMODELS = 8; // Number of assembler search models

// Indexes of general-purpose registers in t_reg.
enum {
  REG_EAX,
  REG_ECX,
  REG_EDX,
  REG_EBX,
  REG_ESP,
  REG_EBP,
  REG_ESI,
  REG_EDI,
}

// Indexes of segment/selector registers
enum {
  SEG_UNDEF = -1,
  SEG_ES,
  SEG_CS,
  SEG_SS,
  SEG_DS,
  SEG_FS,
  SEG_GS,
}

enum C_TYPEMASK = 0xF0; // Mask for command type
enum   C_CMD = 0x00; // Ordinary instruction
enum   C_PSH = 0x10; // 1-word PUSH instruction
enum   C_POP = 0x20; // 1-word POP instruction
enum   C_MMX = 0x30; // MMX instruction
enum   C_FLT = 0x40; // FPU instruction
enum   C_JMP = 0x50; // JUMP instruction
enum   C_JMC = 0x60; // Conditional JUMP instruction
enum   C_CAL = 0x70; // CALL instruction
enum   C_RET = 0x80; // RET instruction
enum   C_FLG = 0x90; // Changes system flags
enum   C_RTF = 0xA0; // C_JMP and C_FLG simultaneously
enum   C_REP = 0xB0; // Instruction with REPxx prefix
enum   C_PRI = 0xC0; // Privileged instruction
enum   C_DAT = 0xD0; // Data (address) doubleword
enum   C_NOW = 0xE0; // 3DNow! instruction
enum   C_BAD = 0xF0; // Unrecognized command
enum C_RARE = 0x08; // Rare command, seldom used in programs
enum C_SIZEMASK = 0x07; // MMX data size or special flag
enum   C_EXPL = 0x01; // (non-MMX) Specify explicit memory size

// ////////////////////////////////////////////////////////////////////////// //
// Initialized constant data structures used by all programs from assembler
// package. Contain names of register, register combinations or commands and
// their properties.

immutable string[9][3] regname = [
  ["AL", "CL", "DL", "BL", "AH", "CH", "DH", "BH", "R8" ],
  ["AX", "CX", "DX", "BX", "SP", "BP", "SI", "DI", "R16"],
  ["EAX","ECX","EDX","EBX","ESP","EBP","ESI","EDI","R32"],
];

immutable string[8] segname = ["ES","CS","SS","DS","FS","GS","SEG?","SEG?"];

immutable string[11] sizename = [
  "(0-BYTE)", "BYTE", "WORD", "(3-BYTE)",
  "DWORD", "(5-BYTE)", "FWORD", "(7-BYTE)",
  "QWORD", "(9-BYTE)", "TBYTE"
];

immutable AsmAddrDec[8] addr16 = [
  AsmAddrDec(SEG_DS,"BX+SI"),
  AsmAddrDec(SEG_DS,"BX+DI"),
  AsmAddrDec(SEG_SS,"BP+SI"),
  AsmAddrDec(SEG_SS,"BP+DI"),
  AsmAddrDec(SEG_DS,"SI"),
  AsmAddrDec(SEG_DS,"DI"),
  AsmAddrDec(SEG_SS,"BP"),
  AsmAddrDec(SEG_DS,"BX"),
];

immutable AsmAddrDec[8] addr32 = [
  AsmAddrDec(SEG_DS,"EAX"),
  AsmAddrDec(SEG_DS,"ECX"),
  AsmAddrDec(SEG_DS,"EDX"),
  AsmAddrDec(SEG_DS,"EBX"),
  AsmAddrDec(SEG_SS,""),
  AsmAddrDec(SEG_SS,"EBP"),
  AsmAddrDec(SEG_DS,"ESI"),
  AsmAddrDec(SEG_DS,"EDI"),
];

immutable string[9] fpuname = ["ST0","ST1","ST2","ST3","ST4","ST5","ST6","ST7","FPU"];
immutable string[9] mmxname = ["MM0","MM1","MM2","MM3","MM4","MM5","MM6","MM7","MMX"];
immutable string[9] crname = ["CR0","CR1","CR2","CR3","CR4","CR5","CR6","CR7","CRX"];
immutable string[9] drname = ["DR0","DR1","DR2","DR3","DR4","DR5","DR6","DR7","DRX"];

// List of available processor commands with decoding, types of parameters and
// other useful information. Last element has field mask=0. If mnemonic begins
// with ampersand ('&'), its mnemonic decodes differently depending on operand
// size (16 or 32 bits). If mnemonic begins with dollar ('$'), this mnemonic
// depends on address size. Semicolon (':') separates 16-bit form from 32-bit,
// asterisk ('*') will be substituted by either W (16), D (32) or none (16/32)
// character. If command is of type C_MMX or C_NOW, or if type contains C_EXPL
// (=0x01), Disassembler must specify explicit size of memory operand.
immutable AsmInstrData[585] asmInstrs = [
  AsmInstrData(0x0000FF, 0x000090, 1,00,  NNN,NNN,NNN, C_CMD+0,        "NOP\0"),
  AsmInstrData(0x0000FE, 0x00008A, 1,WW,  REG,MRG,NNN, C_CMD+0,        "MOV\0"),
  AsmInstrData(0x0000F8, 0x000050, 1,00,  RCM,NNN,NNN, C_PSH+0,        "PUSH\0"),
  AsmInstrData(0x0000FE, 0x000088, 1,WW,  MRG,REG,NNN, C_CMD+0,        "MOV\0"),
  AsmInstrData(0x0000FF, 0x0000E8, 1,00,  JOW,NNN,NNN, C_CAL+0,        "CALL\0"),
  AsmInstrData(0x0000FD, 0x000068, 1,SS,  IMM,NNN,NNN, C_PSH+0,        "PUSH\0"),
  AsmInstrData(0x0000FF, 0x00008D, 1,00,  REG,MMA,NNN, C_CMD+0,        "LEA\0"),
  AsmInstrData(0x0000FF, 0x000074, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JE,JZ\0"),
  AsmInstrData(0x0000F8, 0x000058, 1,00,  RCM,NNN,NNN, C_POP+0,        "POP\0"),
  AsmInstrData(0x0038FC, 0x000080, 1,WS,  MRG,IMM,NNN, C_CMD+1,        "ADD\0"),
  AsmInstrData(0x0000FF, 0x000075, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JNZ,JNE\0"),
  AsmInstrData(0x0000FF, 0x0000EB, 1,00,  JOB,NNN,NNN, C_JMP+0,        "JMP\0"),
  AsmInstrData(0x0000FF, 0x0000E9, 1,00,  JOW,NNN,NNN, C_JMP+0,        "JMP\0"),
  AsmInstrData(0x0000FE, 0x000084, 1,WW,  MRG,REG,NNN, C_CMD+0,        "TEST\0"),
  AsmInstrData(0x0038FE, 0x0000C6, 1,WW,  MRG,IMM,NNN, C_CMD+1,        "MOV\0"),
  AsmInstrData(0x0000FE, 0x000032, 1,WW,  REG,MRG,NNN, C_CMD+0,        "XOR\0"),
  AsmInstrData(0x0000FE, 0x00003A, 1,WW,  REG,MRG,NNN, C_CMD+0,        "CMP\0"),
  AsmInstrData(0x0038FC, 0x003880, 1,WS,  MRG,IMM,NNN, C_CMD+1,        "CMP\0"),
  AsmInstrData(0x0038FF, 0x0010FF, 1,00,  MRJ,NNN,NNN, C_CAL+0,        "CALL\0"),
  AsmInstrData(0x0000FF, 0x0000C3, 1,00,  PRN,NNN,NNN, C_RET+0,        "RETN,RET\0"),
  AsmInstrData(0x0000F0, 0x0000B0, 1,W3,  RCM,IMM,NNN, C_CMD+0,        "MOV\0"),
  AsmInstrData(0x0000FE, 0x0000A0, 1,WW,  RAC,IMA,NNN, C_CMD+0,        "MOV\0"),
  AsmInstrData(0x00FFFF, 0x00840F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JE,JZ\0"),
  AsmInstrData(0x0000F8, 0x000040, 1,00,  RCM,NNN,NNN, C_CMD+0,        "INC\0"),
  AsmInstrData(0x0038FE, 0x0000F6, 1,WW,  MRG,IMU,NNN, C_CMD+1,        "TEST\0"),
  AsmInstrData(0x0000FE, 0x0000A2, 1,WW,  IMA,RAC,NNN, C_CMD+0,        "MOV\0"),
  AsmInstrData(0x0000FE, 0x00002A, 1,WW,  REG,MRG,NNN, C_CMD+0,        "SUB\0"),
  AsmInstrData(0x0000FF, 0x00007E, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JLE,JNG\0"),
  AsmInstrData(0x00FFFF, 0x00850F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JNZ,JNE\0"),
  AsmInstrData(0x0000FF, 0x0000C2, 1,00,  IM2,PRN,NNN, C_RET+0,        "RETN\0"),
  AsmInstrData(0x0038FF, 0x0030FF, 1,00,  MRG,NNN,NNN, C_PSH+1,        "PUSH\0"),
  AsmInstrData(0x0038FC, 0x000880, 1,WS,  MRG,IMU,NNN, C_CMD+1,        "OR\0"),
  AsmInstrData(0x0038FC, 0x002880, 1,WS,  MRG,IMM,NNN, C_CMD+1,        "SUB\0"),
  AsmInstrData(0x0000F8, 0x000048, 1,00,  RCM,NNN,NNN, C_CMD+0,        "DEC\0"),
  AsmInstrData(0x00FFFF, 0x00BF0F, 2,00,  REG,MR2,NNN, C_CMD+1,        "MOVSX\0"),
  AsmInstrData(0x0000FF, 0x00007C, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JL,JNGE\0"),
  AsmInstrData(0x0000FE, 0x000002, 1,WW,  REG,MRG,NNN, C_CMD+0,        "ADD\0"),
  AsmInstrData(0x0038FC, 0x002080, 1,WS,  MRG,IMU,NNN, C_CMD+1,        "AND\0"),
  AsmInstrData(0x0000FE, 0x00003C, 1,WW,  RAC,IMM,NNN, C_CMD+0,        "CMP\0"),
  AsmInstrData(0x0038FF, 0x0020FF, 1,00,  MRJ,NNN,NNN, C_JMP+0,        "JMP\0"),
  AsmInstrData(0x0038FE, 0x0010F6, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "NOT\0"),
  AsmInstrData(0x0038FE, 0x0028C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "SHR\0"),
  AsmInstrData(0x0000FE, 0x000038, 1,WW,  MRG,REG,NNN, C_CMD+0,        "CMP\0"),
  AsmInstrData(0x0000FF, 0x00007D, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JGE,JNL\0"),
  AsmInstrData(0x0000FF, 0x00007F, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JG,JNLE\0"),
  AsmInstrData(0x0038FE, 0x0020C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "SHL\0"),
  AsmInstrData(0x0000FE, 0x00001A, 1,WW,  REG,MRG,NNN, C_CMD+0,        "SBB\0"),
  AsmInstrData(0x0038FE, 0x0018F6, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "NEG\0"),
  AsmInstrData(0x0000FF, 0x0000C9, 1,00,  NNN,NNN,NNN, C_CMD+0,        "LEAVE\0"),
  AsmInstrData(0x0000FF, 0x000060, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "&PUSHA*\0"),
  AsmInstrData(0x0038FF, 0x00008F, 1,00,  MRG,NNN,NNN, C_POP+1,        "POP\0"),
  AsmInstrData(0x0000FF, 0x000061, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "&POPA*\0"),
  AsmInstrData(0x0000F8, 0x000090, 1,00,  RAC,RCM,NNN, C_CMD+0,        "XCHG\0"),
  AsmInstrData(0x0000FE, 0x000086, 1,WW,  MRG,REG,NNN, C_CMD+0,        "XCHG\0"),
  AsmInstrData(0x0000FE, 0x000000, 1,WW,  MRG,REG,NNN, C_CMD+0,        "ADD\0"),
  AsmInstrData(0x0000FE, 0x000010, 1,WW,  MRG,REG,NNN, C_CMD+C_RARE+0, "ADC\0"),
  AsmInstrData(0x0000FE, 0x000012, 1,WW,  REG,MRG,NNN, C_CMD+C_RARE+0, "ADC\0"),
  AsmInstrData(0x0000FE, 0x000020, 1,WW,  MRG,REG,NNN, C_CMD+0,        "AND\0"),
  AsmInstrData(0x0000FE, 0x000022, 1,WW,  REG,MRG,NNN, C_CMD+0,        "AND\0"),
  AsmInstrData(0x0000FE, 0x000008, 1,WW,  MRG,REG,NNN, C_CMD+0,        "OR\0"),
  AsmInstrData(0x0000FE, 0x00000A, 1,WW,  REG,MRG,NNN, C_CMD+0,        "OR\0"),
  AsmInstrData(0x0000FE, 0x000028, 1,WW,  MRG,REG,NNN, C_CMD+0,        "SUB\0"),
  AsmInstrData(0x0000FE, 0x000018, 1,WW,  MRG,REG,NNN, C_CMD+C_RARE+0, "SBB\0"),
  AsmInstrData(0x0000FE, 0x000030, 1,WW,  MRG,REG,NNN, C_CMD+0,        "XOR\0"),
  AsmInstrData(0x0038FC, 0x001080, 1,WS,  MRG,IMM,NNN, C_CMD+C_RARE+1, "ADC\0"),
  AsmInstrData(0x0038FC, 0x001880, 1,WS,  MRG,IMM,NNN, C_CMD+C_RARE+1, "SBB\0"),
  AsmInstrData(0x0038FC, 0x003080, 1,WS,  MRG,IMU,NNN, C_CMD+1,        "XOR\0"),
  AsmInstrData(0x0000FE, 0x000004, 1,WW,  RAC,IMM,NNN, C_CMD+0,        "ADD\0"),
  AsmInstrData(0x0000FE, 0x000014, 1,WW,  RAC,IMM,NNN, C_CMD+C_RARE+0, "ADC\0"),
  AsmInstrData(0x0000FE, 0x000024, 1,WW,  RAC,IMU,NNN, C_CMD+0,        "AND\0"),
  AsmInstrData(0x0000FE, 0x00000C, 1,WW,  RAC,IMU,NNN, C_CMD+0,        "OR\0"),
  AsmInstrData(0x0000FE, 0x00002C, 1,WW,  RAC,IMM,NNN, C_CMD+0,        "SUB\0"),
  AsmInstrData(0x0000FE, 0x00001C, 1,WW,  RAC,IMM,NNN, C_CMD+C_RARE+0, "SBB\0"),
  AsmInstrData(0x0000FE, 0x000034, 1,WW,  RAC,IMU,NNN, C_CMD+0,        "XOR\0"),
  AsmInstrData(0x0038FE, 0x0000FE, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "INC\0"),
  AsmInstrData(0x0038FE, 0x0008FE, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "DEC\0"),
  AsmInstrData(0x0000FE, 0x0000A8, 1,WW,  RAC,IMU,NNN, C_CMD+0,        "TEST\0"),
  AsmInstrData(0x0038FE, 0x0020F6, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "MUL\0"),
  AsmInstrData(0x0038FE, 0x0028F6, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "IMUL\0"),
  AsmInstrData(0x00FFFF, 0x00AF0F, 2,00,  REG,MRG,NNN, C_CMD+0,        "IMUL\0"),
  AsmInstrData(0x0000FF, 0x00006B, 1,00,  REG,MRG,IMX, C_CMD+C_RARE+0, "IMUL\0"),
  AsmInstrData(0x0000FF, 0x000069, 1,00,  REG,MRG,IMM, C_CMD+C_RARE+0, "IMUL\0"),
  AsmInstrData(0x0038FE, 0x0030F6, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "DIV\0"),
  AsmInstrData(0x0038FE, 0x0038F6, 1,WW,  MRG,NNN,NNN, C_CMD+1,        "IDIV\0"),
  AsmInstrData(0x0000FF, 0x000098, 1,00,  NNN,NNN,NNN, C_CMD+0,        "&CBW:CWDE\0"),
  AsmInstrData(0x0000FF, 0x000099, 1,00,  NNN,NNN,NNN, C_CMD+0,        "&CWD:CDQ\0"),
  AsmInstrData(0x0038FE, 0x0000D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "ROL\0"),
  AsmInstrData(0x0038FE, 0x0008D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "ROR\0"),
  AsmInstrData(0x0038FE, 0x0010D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "RCL\0"),
  AsmInstrData(0x0038FE, 0x0018D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "RCR\0"),
  AsmInstrData(0x0038FE, 0x0020D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "SHL\0"),
  AsmInstrData(0x0038FE, 0x0028D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "SHR\0"),
  AsmInstrData(0x0038FE, 0x0038D0, 1,WW,  MRG,C01,NNN, C_CMD+1,        "SAR\0"),
  AsmInstrData(0x0038FE, 0x0000D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "ROL\0"),
  AsmInstrData(0x0038FE, 0x0008D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "ROR\0"),
  AsmInstrData(0x0038FE, 0x0010D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "RCL\0"),
  AsmInstrData(0x0038FE, 0x0018D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "RCR\0"),
  AsmInstrData(0x0038FE, 0x0020D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "SHL\0"),
  AsmInstrData(0x0038FE, 0x0028D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "SHR\0"),
  AsmInstrData(0x0038FE, 0x0038D2, 1,WW,  MRG,RCL,NNN, C_CMD+1,        "SAR\0"),
  AsmInstrData(0x0038FE, 0x0000C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "ROL\0"),
  AsmInstrData(0x0038FE, 0x0008C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "ROR\0"),
  AsmInstrData(0x0038FE, 0x0010C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "RCL\0"),
  AsmInstrData(0x0038FE, 0x0018C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "RCR\0"),
  AsmInstrData(0x0038FE, 0x0038C0, 1,WW,  MRG,IMS,NNN, C_CMD+1,        "SAR\0"),
  AsmInstrData(0x0000FF, 0x000070, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JO\0"),
  AsmInstrData(0x0000FF, 0x000071, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JNO\0"),
  AsmInstrData(0x0000FF, 0x000072, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JB,JC\0"),
  AsmInstrData(0x0000FF, 0x000073, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JNB,JNC\0"),
  AsmInstrData(0x0000FF, 0x000076, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JBE,JNA\0"),
  AsmInstrData(0x0000FF, 0x000077, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JA,JNBE\0"),
  AsmInstrData(0x0000FF, 0x000078, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JS\0"),
  AsmInstrData(0x0000FF, 0x000079, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JNS\0"),
  AsmInstrData(0x0000FF, 0x00007A, 1,CC,  JOB,NNN,NNN, C_JMC+C_RARE+0, "JPE,JP\0"),
  AsmInstrData(0x0000FF, 0x00007B, 1,CC,  JOB,NNN,NNN, C_JMC+C_RARE+0, "JPO,JNP\0"),
  AsmInstrData(0x0000FF, 0x0000E3, 1,00,  JOB,NNN,NNN, C_JMC+C_RARE+0, "$JCXZ:JECXZ\0"),
  AsmInstrData(0x00FFFF, 0x00800F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JO\0"),
  AsmInstrData(0x00FFFF, 0x00810F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JNO\0"),
  AsmInstrData(0x00FFFF, 0x00820F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JB,JC\0"),
  AsmInstrData(0x00FFFF, 0x00830F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JNB,JNC\0"),
  AsmInstrData(0x00FFFF, 0x00860F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JBE,JNA\0"),
  AsmInstrData(0x00FFFF, 0x00870F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JA,JNBE\0"),
  AsmInstrData(0x00FFFF, 0x00880F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JS\0"),
  AsmInstrData(0x00FFFF, 0x00890F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JNS\0"),
  AsmInstrData(0x00FFFF, 0x008A0F, 2,CC,  JOW,NNN,NNN, C_JMC+C_RARE+0, "JPE,JP\0"),
  AsmInstrData(0x00FFFF, 0x008B0F, 2,CC,  JOW,NNN,NNN, C_JMC+C_RARE+0, "JPO,JNP\0"),
  AsmInstrData(0x00FFFF, 0x008C0F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JL,JNGE\0"),
  AsmInstrData(0x00FFFF, 0x008D0F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JGE,JNL\0"),
  AsmInstrData(0x00FFFF, 0x008E0F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JLE,JNG\0"),
  AsmInstrData(0x00FFFF, 0x008F0F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JG,JNLE\0"),
  AsmInstrData(0x0000FF, 0x0000F8, 1,00,  NNN,NNN,NNN, C_CMD+0,        "CLC\0"),
  AsmInstrData(0x0000FF, 0x0000F9, 1,00,  NNN,NNN,NNN, C_CMD+0,        "STC\0"),
  AsmInstrData(0x0000FF, 0x0000F5, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "CMC\0"),
  AsmInstrData(0x0000FF, 0x0000FC, 1,00,  NNN,NNN,NNN, C_CMD+0,        "CLD\0"),
  AsmInstrData(0x0000FF, 0x0000FD, 1,00,  NNN,NNN,NNN, C_CMD+0,        "STD\0"),
  AsmInstrData(0x0000FF, 0x0000FA, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "CLI\0"),
  AsmInstrData(0x0000FF, 0x0000FB, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "STI\0"),
  AsmInstrData(0x0000FF, 0x00008C, 1,FF,  MRG,SGM,NNN, C_CMD+C_RARE+0, "MOV\0"),
  AsmInstrData(0x0000FF, 0x00008E, 1,FF,  SGM,MRG,NNN, C_CMD+C_RARE+0, "MOV\0"),
  AsmInstrData(0x0000FE, 0x0000A6, 1,WW,  MSO,MDE,NNN, C_CMD+1,        "CMPS\0"),
  AsmInstrData(0x0000FE, 0x0000AC, 1,WW,  MSO,NNN,NNN, C_CMD+1,        "LODS\0"),
  AsmInstrData(0x0000FE, 0x0000A4, 1,WW,  MDE,MSO,NNN, C_CMD+1,        "MOVS\0"),
  AsmInstrData(0x0000FE, 0x0000AE, 1,WW,  MDE,PAC,NNN, C_CMD+1,        "SCAS\0"),
  AsmInstrData(0x0000FE, 0x0000AA, 1,WW,  MDE,PAC,NNN, C_CMD+1,        "STOS\0"),
  AsmInstrData(0x00FEFF, 0x00A4F3, 1,WW,  MDE,MSO,PCX, C_REP+1,        "REP MOVS\0"),
  AsmInstrData(0x00FEFF, 0x00ACF3, 1,WW,  MSO,PAC,PCX, C_REP+C_RARE+1, "REP LODS\0"),
  AsmInstrData(0x00FEFF, 0x00AAF3, 1,WW,  MDE,PAC,PCX, C_REP+1,        "REP STOS\0"),
  AsmInstrData(0x00FEFF, 0x00A6F3, 1,WW,  MDE,MSO,PCX, C_REP+1,        "REPE CMPS\0"),
  AsmInstrData(0x00FEFF, 0x00AEF3, 1,WW,  MDE,PAC,PCX, C_REP+1,        "REPE SCAS\0"),
  AsmInstrData(0x00FEFF, 0x00A6F2, 1,WW,  MDE,MSO,PCX, C_REP+1,        "REPNE CMPS\0"),
  AsmInstrData(0x00FEFF, 0x00AEF2, 1,WW,  MDE,PAC,PCX, C_REP+1,        "REPNE SCAS\0"),
  AsmInstrData(0x0000FF, 0x0000EA, 1,00,  JMF,NNN,NNN, C_JMP+C_RARE+0, "JMP\0"),
  AsmInstrData(0x0038FF, 0x0028FF, 1,00,  MMS,NNN,NNN, C_JMP+C_RARE+1, "JMP\0"),
  AsmInstrData(0x0000FF, 0x00009A, 1,00,  JMF,NNN,NNN, C_CAL+C_RARE+0, "CALL\0"),
  AsmInstrData(0x0038FF, 0x0018FF, 1,00,  MMS,NNN,NNN, C_CAL+C_RARE+1, "CALL\0"),
  AsmInstrData(0x0000FF, 0x0000CB, 1,00,  PRF,NNN,NNN, C_RET+C_RARE+0, "RETF\0"),
  AsmInstrData(0x0000FF, 0x0000CA, 1,00,  IM2,PRF,NNN, C_RET+C_RARE+0, "RETF\0"),
  AsmInstrData(0x00FFFF, 0x00A40F, 2,00,  MRG,REG,IMS, C_CMD+0,        "SHLD\0"),
  AsmInstrData(0x00FFFF, 0x00AC0F, 2,00,  MRG,REG,IMS, C_CMD+0,        "SHRD\0"),
  AsmInstrData(0x00FFFF, 0x00A50F, 2,00,  MRG,REG,RCL, C_CMD+0,        "SHLD\0"),
  AsmInstrData(0x00FFFF, 0x00AD0F, 2,00,  MRG,REG,RCL, C_CMD+0,        "SHRD\0"),
  AsmInstrData(0x00F8FF, 0x00C80F, 2,00,  RCM,NNN,NNN, C_CMD+C_RARE+0, "BSWAP\0"),
  AsmInstrData(0x00FEFF, 0x00C00F, 2,WW,  MRG,REG,NNN, C_CMD+C_RARE+0, "XADD\0"),
  AsmInstrData(0x0000FF, 0x0000E2, 1,LL,  JOB,PCX,NNN, C_JMC+0,        "$LOOP*\0"),
  AsmInstrData(0x0000FF, 0x0000E1, 1,LL,  JOB,PCX,NNN, C_JMC+0,        "$LOOP*E\0"),
  AsmInstrData(0x0000FF, 0x0000E0, 1,LL,  JOB,PCX,NNN, C_JMC+0,        "$LOOP*NE\0"),
  AsmInstrData(0x0000FF, 0x0000C8, 1,00,  IM2,IM1,NNN, C_CMD+0,        "ENTER\0"),
  AsmInstrData(0x0000FE, 0x0000E4, 1,WP,  RAC,IM1,NNN, C_CMD+C_RARE+0, "IN\0"),
  AsmInstrData(0x0000FE, 0x0000EC, 1,WP,  RAC,RDX,NNN, C_CMD+C_RARE+0, "IN\0"),
  AsmInstrData(0x0000FE, 0x0000E6, 1,WP,  IM1,RAC,NNN, C_CMD+C_RARE+0, "OUT\0"),
  AsmInstrData(0x0000FE, 0x0000EE, 1,WP,  RDX,RAC,NNN, C_CMD+C_RARE+0, "OUT\0"),
  AsmInstrData(0x0000FE, 0x00006C, 1,WP,  MDE,RDX,NNN, C_CMD+C_RARE+1, "INS\0"),
  AsmInstrData(0x0000FE, 0x00006E, 1,WP,  RDX,MDE,NNN, C_CMD+C_RARE+1, "OUTS\0"),
  AsmInstrData(0x00FEFF, 0x006CF3, 1,WP,  MDE,RDX,PCX, C_REP+C_RARE+1, "REP INS\0"),
  AsmInstrData(0x00FEFF, 0x006EF3, 1,WP,  RDX,MDE,PCX, C_REP+C_RARE+1, "REP OUTS\0"),
  AsmInstrData(0x0000FF, 0x000037, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "AAA\0"),
  AsmInstrData(0x0000FF, 0x00003F, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "AAS\0"),
  AsmInstrData(0x00FFFF, 0x000AD4, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "AAM\0"),
  AsmInstrData(0x0000FF, 0x0000D4, 1,00,  IM1,NNN,NNN, C_CMD+C_RARE+0, "AAM\0"),
  AsmInstrData(0x00FFFF, 0x000AD5, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "AAD\0"),
  AsmInstrData(0x0000FF, 0x0000D5, 1,00,  IM1,NNN,NNN, C_CMD+C_RARE+0, "AAD\0"),
  AsmInstrData(0x0000FF, 0x000027, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "DAA\0"),
  AsmInstrData(0x0000FF, 0x00002F, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "DAS\0"),
  AsmInstrData(0x0000FF, 0x0000F4, 1,PR,  NNN,NNN,NNN, C_PRI+C_RARE+0, "HLT\0"),
  AsmInstrData(0x0000FF, 0x00000E, 1,00,  SCM,NNN,NNN, C_PSH+C_RARE+0, "PUSH\0"),
  AsmInstrData(0x0000FF, 0x000016, 1,00,  SCM,NNN,NNN, C_PSH+C_RARE+0, "PUSH\0"),
  AsmInstrData(0x0000FF, 0x00001E, 1,00,  SCM,NNN,NNN, C_PSH+C_RARE+0, "PUSH\0"),
  AsmInstrData(0x0000FF, 0x000006, 1,00,  SCM,NNN,NNN, C_PSH+C_RARE+0, "PUSH\0"),
  AsmInstrData(0x00FFFF, 0x00A00F, 2,00,  SCM,NNN,NNN, C_PSH+C_RARE+0, "PUSH\0"),
  AsmInstrData(0x00FFFF, 0x00A80F, 2,00,  SCM,NNN,NNN, C_PSH+C_RARE+0, "PUSH\0"),
  AsmInstrData(0x0000FF, 0x00001F, 1,00,  SCM,NNN,NNN, C_POP+C_RARE+0, "POP\0"),
  AsmInstrData(0x0000FF, 0x000007, 1,00,  SCM,NNN,NNN, C_POP+C_RARE+0, "POP\0"),
  AsmInstrData(0x0000FF, 0x000017, 1,00,  SCM,NNN,NNN, C_POP+C_RARE+0, "POP\0"),
  AsmInstrData(0x00FFFF, 0x00A10F, 2,00,  SCM,NNN,NNN, C_POP+C_RARE+0, "POP\0"),
  AsmInstrData(0x00FFFF, 0x00A90F, 2,00,  SCM,NNN,NNN, C_POP+C_RARE+0, "POP\0"),
  AsmInstrData(0x0000FF, 0x0000D7, 1,00,  MXL,NNN,NNN, C_CMD+C_RARE+1, "XLAT\0"),
  AsmInstrData(0x00FFFF, 0x00BE0F, 2,00,  REG,MR1,NNN, C_CMD+1,        "MOVSX\0"),
  AsmInstrData(0x00FFFF, 0x00B60F, 2,00,  REG,MR1,NNN, C_CMD+1,        "MOVZX\0"),
  AsmInstrData(0x00FFFF, 0x00B70F, 2,00,  REG,MR2,NNN, C_CMD+1,        "MOVZX\0"),
  AsmInstrData(0x0000FF, 0x00009B, 1,00,  NNN,NNN,NNN, C_CMD+0,        "WAIT\0"),
  AsmInstrData(0x0000FF, 0x00009F, 1,00,  PAH,PFL,NNN, C_CMD+C_RARE+0, "LAHF\0"),
  AsmInstrData(0x0000FF, 0x00009E, 1,00,  PFL,PAH,NNN, C_CMD+C_RARE+0, "SAHF\0"),
  AsmInstrData(0x0000FF, 0x00009C, 1,00,  NNN,NNN,NNN, C_PSH+0,        "&PUSHF*\0"),
  AsmInstrData(0x0000FF, 0x00009D, 1,00,  NNN,NNN,NNN, C_FLG+0,        "&POPF*\0"),
  AsmInstrData(0x0000FF, 0x0000CD, 1,00,  IM1,NNN,NNN, C_CAL+C_RARE+0, "INT\0"),
  AsmInstrData(0x0000FF, 0x0000CC, 1,00,  NNN,NNN,NNN, C_CAL+C_RARE+0, "INT3\0"),
  AsmInstrData(0x0000FF, 0x0000CE, 1,00,  NNN,NNN,NNN, C_CAL+C_RARE+0, "INTO\0"),
  AsmInstrData(0x0000FF, 0x0000CF, 1,00,  NNN,NNN,NNN, C_RTF+C_RARE+0, "&IRET*\0"),
  AsmInstrData(0x00FFFF, 0x00900F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETO\0"),
  AsmInstrData(0x00FFFF, 0x00910F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETNO\0"),
  AsmInstrData(0x00FFFF, 0x00920F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETB,SETC\0"),
  AsmInstrData(0x00FFFF, 0x00930F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETNB,SETNC\0"),
  AsmInstrData(0x00FFFF, 0x00940F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETE,SETZ\0"),
  AsmInstrData(0x00FFFF, 0x00950F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETNE,SETNZ\0"),
  AsmInstrData(0x00FFFF, 0x00960F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETBE,SETNA\0"),
  AsmInstrData(0x00FFFF, 0x00970F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETA,SETNBE\0"),
  AsmInstrData(0x00FFFF, 0x00980F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETS\0"),
  AsmInstrData(0x00FFFF, 0x00990F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETNS\0"),
  AsmInstrData(0x00FFFF, 0x009A0F, 2,CC,  MR1,NNN,NNN, C_CMD+C_RARE+0, "SETPE,SETP\0"),
  AsmInstrData(0x00FFFF, 0x009B0F, 2,CC,  MR1,NNN,NNN, C_CMD+C_RARE+0, "SETPO,SETNP\0"),
  AsmInstrData(0x00FFFF, 0x009C0F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETL,SETNGE\0"),
  AsmInstrData(0x00FFFF, 0x009D0F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETGE,SETNL\0"),
  AsmInstrData(0x00FFFF, 0x009E0F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETLE,SETNG\0"),
  AsmInstrData(0x00FFFF, 0x009F0F, 2,CC,  MR1,NNN,NNN, C_CMD+0,        "SETG,SETNLE\0"),
  AsmInstrData(0x38FFFF, 0x20BA0F, 2,00,  MRG,IM1,NNN, C_CMD+C_RARE+1, "BT\0"),
  AsmInstrData(0x38FFFF, 0x28BA0F, 2,00,  MRG,IM1,NNN, C_CMD+C_RARE+1, "BTS\0"),
  AsmInstrData(0x38FFFF, 0x30BA0F, 2,00,  MRG,IM1,NNN, C_CMD+C_RARE+1, "BTR\0"),
  AsmInstrData(0x38FFFF, 0x38BA0F, 2,00,  MRG,IM1,NNN, C_CMD+C_RARE+1, "BTC\0"),
  AsmInstrData(0x00FFFF, 0x00A30F, 2,00,  MRG,REG,NNN, C_CMD+C_RARE+1, "BT\0"),
  AsmInstrData(0x00FFFF, 0x00AB0F, 2,00,  MRG,REG,NNN, C_CMD+C_RARE+1, "BTS\0"),
  AsmInstrData(0x00FFFF, 0x00B30F, 2,00,  MRG,REG,NNN, C_CMD+C_RARE+1, "BTR\0"),
  AsmInstrData(0x00FFFF, 0x00BB0F, 2,00,  MRG,REG,NNN, C_CMD+C_RARE+1, "BTC\0"),
  AsmInstrData(0x0000FF, 0x0000C5, 1,00,  REG,MML,NNN, C_CMD+C_RARE+0, "LDS\0"),
  AsmInstrData(0x0000FF, 0x0000C4, 1,00,  REG,MML,NNN, C_CMD+C_RARE+0, "LES\0"),
  AsmInstrData(0x00FFFF, 0x00B40F, 2,00,  REG,MML,NNN, C_CMD+C_RARE+0, "LFS\0"),
  AsmInstrData(0x00FFFF, 0x00B50F, 2,00,  REG,MML,NNN, C_CMD+C_RARE+0, "LGS\0"),
  AsmInstrData(0x00FFFF, 0x00B20F, 2,00,  REG,MML,NNN, C_CMD+C_RARE+0, "LSS\0"),
  AsmInstrData(0x0000FF, 0x000063, 1,00,  MRG,REG,NNN, C_CMD+C_RARE+0, "ARPL\0"),
  AsmInstrData(0x0000FF, 0x000062, 1,00,  REG,MMB,NNN, C_CMD+C_RARE+0, "BOUND\0"),
  AsmInstrData(0x00FFFF, 0x00BC0F, 2,00,  REG,MRG,NNN, C_CMD+C_RARE+0, "BSF\0"),
  AsmInstrData(0x00FFFF, 0x00BD0F, 2,00,  REG,MRG,NNN, C_CMD+C_RARE+0, "BSR\0"),
  AsmInstrData(0x00FFFF, 0x00060F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "CLTS\0"),
  AsmInstrData(0x00FFFF, 0x00400F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVO\0"),
  AsmInstrData(0x00FFFF, 0x00410F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVNO\0"),
  AsmInstrData(0x00FFFF, 0x00420F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVB,CMOVC\0"),
  AsmInstrData(0x00FFFF, 0x00430F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVNB,CMOVNC\0"),
  AsmInstrData(0x00FFFF, 0x00440F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVE,CMOVZ\0"),
  AsmInstrData(0x00FFFF, 0x00450F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVNE,CMOVNZ\0"),
  AsmInstrData(0x00FFFF, 0x00460F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVBE,CMOVNA\0"),
  AsmInstrData(0x00FFFF, 0x00470F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVA,CMOVNBE\0"),
  AsmInstrData(0x00FFFF, 0x00480F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVS\0"),
  AsmInstrData(0x00FFFF, 0x00490F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVNS\0"),
  AsmInstrData(0x00FFFF, 0x004A0F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVPE,CMOVP\0"),
  AsmInstrData(0x00FFFF, 0x004B0F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVPO,CMOVNP\0"),
  AsmInstrData(0x00FFFF, 0x004C0F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVL,CMOVNGE\0"),
  AsmInstrData(0x00FFFF, 0x004D0F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVGE,CMOVNL\0"),
  AsmInstrData(0x00FFFF, 0x004E0F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVLE,CMOVNG\0"),
  AsmInstrData(0x00FFFF, 0x004F0F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVG,CMOVNLE\0"),
  AsmInstrData(0x00FEFF, 0x00B00F, 2,WW,  MRG,REG,NNN, C_CMD+C_RARE+0, "CMPXCHG\0"),
  AsmInstrData(0x38FFFF, 0x08C70F, 2,00,  MD8,NNN,NNN, C_CMD+C_RARE+1, "CMPXCHG8B\0"),
  AsmInstrData(0x00FFFF, 0x00A20F, 2,00,  NNN,NNN,NNN, C_CMD+0,        "CPUID\0"),
  AsmInstrData(0x00FFFF, 0x00080F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "INVD\0"),
  AsmInstrData(0x00FFFF, 0x00020F, 2,00,  REG,MRG,NNN, C_CMD+C_RARE+0, "LAR\0"),
  AsmInstrData(0x00FFFF, 0x00030F, 2,00,  REG,MRG,NNN, C_CMD+C_RARE+0, "LSL\0"),
  AsmInstrData(0x38FFFF, 0x38010F, 2,PR,  MR1,NNN,NNN, C_CMD+C_RARE+0, "INVLPG\0"),
  AsmInstrData(0x00FFFF, 0x00090F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "WBINVD\0"),
  AsmInstrData(0x38FFFF, 0x10010F, 2,PR,  MM6,NNN,NNN, C_CMD+C_RARE+0, "LGDT\0"),
  AsmInstrData(0x38FFFF, 0x00010F, 2,00,  MM6,NNN,NNN, C_CMD+C_RARE+0, "SGDT\0"),
  AsmInstrData(0x38FFFF, 0x18010F, 2,PR,  MM6,NNN,NNN, C_CMD+C_RARE+0, "LIDT\0"),
  AsmInstrData(0x38FFFF, 0x08010F, 2,00,  MM6,NNN,NNN, C_CMD+C_RARE+0, "SIDT\0"),
  AsmInstrData(0x38FFFF, 0x10000F, 2,PR,  MR2,NNN,NNN, C_CMD+C_RARE+0, "LLDT\0"),
  AsmInstrData(0x38FFFF, 0x00000F, 2,00,  MR2,NNN,NNN, C_CMD+C_RARE+0, "SLDT\0"),
  AsmInstrData(0x38FFFF, 0x18000F, 2,PR,  MR2,NNN,NNN, C_CMD+C_RARE+0, "LTR\0"),
  AsmInstrData(0x38FFFF, 0x08000F, 2,00,  MR2,NNN,NNN, C_CMD+C_RARE+0, "STR\0"),
  AsmInstrData(0x38FFFF, 0x30010F, 2,PR,  MR2,NNN,NNN, C_CMD+C_RARE+0, "LMSW\0"),
  AsmInstrData(0x38FFFF, 0x20010F, 2,00,  MR2,NNN,NNN, C_CMD+C_RARE+0, "SMSW\0"),
  AsmInstrData(0x38FFFF, 0x20000F, 2,00,  MR2,NNN,NNN, C_CMD+C_RARE+0, "VERR\0"),
  AsmInstrData(0x38FFFF, 0x28000F, 2,00,  MR2,NNN,NNN, C_CMD+C_RARE+0, "VERW\0"),
  AsmInstrData(0xC0FFFF, 0xC0220F, 2,PR,  CRX,RR4,NNN, C_CMD+C_RARE+0, "MOV\0"),
  AsmInstrData(0xC0FFFF, 0xC0200F, 2,00,  RR4,CRX,NNN, C_CMD+C_RARE+0, "MOV\0"),
  AsmInstrData(0xC0FFFF, 0xC0230F, 2,PR,  DRX,RR4,NNN, C_CMD+C_RARE+0, "MOV\0"),
  AsmInstrData(0xC0FFFF, 0xC0210F, 2,PR,  RR4,DRX,NNN, C_CMD+C_RARE+0, "MOV\0"),
  AsmInstrData(0x00FFFF, 0x00310F, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "RDTSC\0"),
  AsmInstrData(0x00FFFF, 0x00320F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "RDMSR\0"),
  AsmInstrData(0x00FFFF, 0x00300F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "WRMSR\0"),
  AsmInstrData(0x00FFFF, 0x00330F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "RDPMC\0"),
  AsmInstrData(0x00FFFF, 0x00AA0F, 2,PR,  NNN,NNN,NNN, C_RTF+C_RARE+0, "RSM\0"),
  AsmInstrData(0x00FFFF, 0x000B0F, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "UD2\0"),
  AsmInstrData(0x00FFFF, 0x00340F, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "SYSENTER\0"),
  AsmInstrData(0x00FFFF, 0x00350F, 2,PR,  NNN,NNN,NNN, C_CMD+C_RARE+0, "SYSEXIT\0"),
  AsmInstrData(0x0000FF, 0x0000D6, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "SALC\0"),
  // FPU instructions. Never change the order of instructions!
  AsmInstrData(0x00FFFF, 0x00F0D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "F2XM1\0"),
  AsmInstrData(0x00FFFF, 0x00E0D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FCHS\0"),
  AsmInstrData(0x00FFFF, 0x00E1D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FABS\0"),
  AsmInstrData(0x00FFFF, 0x00E2DB, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FCLEX\0"),
  AsmInstrData(0x00FFFF, 0x00E3DB, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FINIT\0"),
  AsmInstrData(0x00FFFF, 0x00F6D9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FDECSTP\0"),
  AsmInstrData(0x00FFFF, 0x00F7D9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FINCSTP\0"),
  AsmInstrData(0x00FFFF, 0x00E4D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FTST\0"),
  AsmInstrData(0x00FFFF, 0x00FAD9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FSQRT\0"),
  AsmInstrData(0x00FFFF, 0x00FED9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FSIN\0"),
  AsmInstrData(0x00FFFF, 0x00FFD9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FCOS\0"),
  AsmInstrData(0x00FFFF, 0x00FBD9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FSINCOS\0"),
  AsmInstrData(0x00FFFF, 0x00F2D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FPTAN\0"),
  AsmInstrData(0x00FFFF, 0x00F3D9, 2,00,  PS0,PS1,NNN, C_FLT+0,        "FPATAN\0"),
  AsmInstrData(0x00FFFF, 0x00F8D9, 2,00,  PS1,PS0,NNN, C_FLT+0,        "FPREM\0"),
  AsmInstrData(0x00FFFF, 0x00F5D9, 2,00,  PS1,PS0,NNN, C_FLT+0,        "FPREM1\0"),
  AsmInstrData(0x00FFFF, 0x00F1D9, 2,00,  PS0,PS1,NNN, C_FLT+0,        "FYL2X\0"),
  AsmInstrData(0x00FFFF, 0x00F9D9, 2,00,  PS0,PS1,NNN, C_FLT+0,        "FYL2XP1\0"),
  AsmInstrData(0x00FFFF, 0x00FCD9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FRNDINT\0"),
  AsmInstrData(0x00FFFF, 0x00E8D9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLD1\0"),
  AsmInstrData(0x00FFFF, 0x00E9D9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLDL2T\0"),
  AsmInstrData(0x00FFFF, 0x00EAD9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLDL2E\0"),
  AsmInstrData(0x00FFFF, 0x00EBD9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLDPI\0"),
  AsmInstrData(0x00FFFF, 0x00ECD9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLDLG2\0"),
  AsmInstrData(0x00FFFF, 0x00EDD9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLDLN2\0"),
  AsmInstrData(0x00FFFF, 0x00EED9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FLDZ\0"),
  AsmInstrData(0x00FFFF, 0x00FDD9, 2,00,  PS0,PS1,NNN, C_FLT+0,        "FSCALE\0"),
  AsmInstrData(0x00FFFF, 0x00D0D9, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FNOP\0"),
  AsmInstrData(0x00FFFF, 0x00E0DF, 2,FF,  RAX,NNN,NNN, C_FLT+0,        "FSTSW\0"),
  AsmInstrData(0x00FFFF, 0x00E5D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FXAM\0"),
  AsmInstrData(0x00FFFF, 0x00F4D9, 2,00,  PS0,NNN,NNN, C_FLT+0,        "FXTRACT\0"),
  AsmInstrData(0x00FFFF, 0x00D9DE, 2,00,  PS0,PS1,NNN, C_FLT+0,        "FCOMPP\0"),
  AsmInstrData(0x00FFFF, 0x00E9DA, 2,00,  PS0,PS1,NNN, C_FLT+0,        "FUCOMPP\0"),
  AsmInstrData(0x00F8FF, 0x00C0DD, 2,00,  RST,NNN,NNN, C_FLT+0,        "FFREE\0"),
  AsmInstrData(0x00F8FF, 0x00C0DA, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVB\0"),
  AsmInstrData(0x00F8FF, 0x00C8DA, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVE\0"),
  AsmInstrData(0x00F8FF, 0x00D0DA, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVBE\0"),
  AsmInstrData(0x00F8FF, 0x00D8DA, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVU\0"),
  AsmInstrData(0x00F8FF, 0x00C0DB, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVNB\0"),
  AsmInstrData(0x00F8FF, 0x00C8DB, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVNE\0"),
  AsmInstrData(0x00F8FF, 0x00D0DB, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVNBE\0"),
  AsmInstrData(0x00F8FF, 0x00D8DB, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCMOVNU\0"),
  AsmInstrData(0x00F8FF, 0x00F0DB, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCOMI\0"),
  AsmInstrData(0x00F8FF, 0x00F0DF, 2,00,  RS0,RST,NNN, C_FLT+0,        "FCOMIP\0"),
  AsmInstrData(0x00F8FF, 0x00E8DB, 2,00,  RS0,RST,NNN, C_FLT+0,        "FUCOMI\0"),
  AsmInstrData(0x00F8FF, 0x00E8DF, 2,00,  RS0,RST,NNN, C_FLT+0,        "FUCOMIP\0"),
  AsmInstrData(0x00F8FF, 0x00C0D8, 2,00,  RS0,RST,NNN, C_FLT+0,        "FADD\0"),
  AsmInstrData(0x00F8FF, 0x00C0DC, 2,00,  RST,RS0,NNN, C_FLT+0,        "FADD\0"),
  AsmInstrData(0x00F8FF, 0x00C0DE, 2,00,  RST,RS0,NNN, C_FLT+0,        "FADDP\0"),
  AsmInstrData(0x00F8FF, 0x00E0D8, 2,00,  RS0,RST,NNN, C_FLT+0,        "FSUB\0"),
  AsmInstrData(0x00F8FF, 0x00E8DC, 2,00,  RST,RS0,NNN, C_FLT+0,        "FSUB\0"),
  AsmInstrData(0x00F8FF, 0x00E8DE, 2,00,  RST,RS0,NNN, C_FLT+0,        "FSUBP\0"),
  AsmInstrData(0x00F8FF, 0x00E8D8, 2,00,  RS0,RST,NNN, C_FLT+0,        "FSUBR\0"),
  AsmInstrData(0x00F8FF, 0x00E0DC, 2,00,  RST,RS0,NNN, C_FLT+0,        "FSUBR\0"),
  AsmInstrData(0x00F8FF, 0x00E0DE, 2,00,  RST,RS0,NNN, C_FLT+0,        "FSUBRP\0"),
  AsmInstrData(0x00F8FF, 0x00C8D8, 2,00,  RS0,RST,NNN, C_FLT+0,        "FMUL\0"),
  AsmInstrData(0x00F8FF, 0x00C8DC, 2,00,  RST,RS0,NNN, C_FLT+0,        "FMUL\0"),
  AsmInstrData(0x00F8FF, 0x00C8DE, 2,00,  RST,RS0,NNN, C_FLT+0,        "FMULP\0"),
  AsmInstrData(0x00F8FF, 0x00D0D8, 2,00,  RST,PS0,NNN, C_FLT+0,        "FCOM\0"),
  AsmInstrData(0x00F8FF, 0x00D8D8, 2,00,  RST,PS0,NNN, C_FLT+0,        "FCOMP\0"),
  AsmInstrData(0x00F8FF, 0x00E0DD, 2,00,  RST,PS0,NNN, C_FLT+0,        "FUCOM\0"),
  AsmInstrData(0x00F8FF, 0x00E8DD, 2,00,  RST,PS0,NNN, C_FLT+0,        "FUCOMP\0"),
  AsmInstrData(0x00F8FF, 0x00F0D8, 2,00,  RS0,RST,NNN, C_FLT+0,        "FDIV\0"),
  AsmInstrData(0x00F8FF, 0x00F8DC, 2,00,  RST,RS0,NNN, C_FLT+0,        "FDIV\0"),
  AsmInstrData(0x00F8FF, 0x00F8DE, 2,00,  RST,RS0,NNN, C_FLT+0,        "FDIVP\0"),
  AsmInstrData(0x00F8FF, 0x00F8D8, 2,00,  RS0,RST,NNN, C_FLT+0,        "FDIVR\0"),
  AsmInstrData(0x00F8FF, 0x00F0DC, 2,00,  RST,RS0,NNN, C_FLT+0,        "FDIVR\0"),
  AsmInstrData(0x00F8FF, 0x00F0DE, 2,00,  RST,RS0,NNN, C_FLT+0,        "FDIVRP\0"),
  AsmInstrData(0x00F8FF, 0x00C0D9, 2,00,  RST,NNN,NNN, C_FLT+0,        "FLD\0"),
  AsmInstrData(0x00F8FF, 0x00D0DD, 2,00,  RST,PS0,NNN, C_FLT+0,        "FST\0"),
  AsmInstrData(0x00F8FF, 0x00D8DD, 2,00,  RST,PS0,NNN, C_FLT+0,        "FSTP\0"),
  AsmInstrData(0x00F8FF, 0x00C8D9, 2,00,  RST,PS0,NNN, C_FLT+0,        "FXCH\0"),
  AsmInstrData(0x0038FF, 0x0000D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FADD\0"),
  AsmInstrData(0x0038FF, 0x0000DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FADD\0"),
  AsmInstrData(0x0038FF, 0x0000DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FIADD\0"),
  AsmInstrData(0x0038FF, 0x0000DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FIADD\0"),
  AsmInstrData(0x0038FF, 0x0020D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FSUB\0"),
  AsmInstrData(0x0038FF, 0x0020DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FSUB\0"),
  AsmInstrData(0x0038FF, 0x0020DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FISUB\0"),
  AsmInstrData(0x0038FF, 0x0020DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FISUB\0"),
  AsmInstrData(0x0038FF, 0x0028D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FSUBR\0"),
  AsmInstrData(0x0038FF, 0x0028DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FSUBR\0"),
  AsmInstrData(0x0038FF, 0x0028DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FISUBR\0"),
  AsmInstrData(0x0038FF, 0x0028DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FISUBR\0"),
  AsmInstrData(0x0038FF, 0x0008D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FMUL\0"),
  AsmInstrData(0x0038FF, 0x0008DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FMUL\0"),
  AsmInstrData(0x0038FF, 0x0008DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FIMUL\0"),
  AsmInstrData(0x0038FF, 0x0008DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FIMUL\0"),
  AsmInstrData(0x0038FF, 0x0010D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FCOM\0"),
  AsmInstrData(0x0038FF, 0x0010DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FCOM\0"),
  AsmInstrData(0x0038FF, 0x0018D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FCOMP\0"),
  AsmInstrData(0x0038FF, 0x0018DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FCOMP\0"),
  AsmInstrData(0x0038FF, 0x0030D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FDIV\0"),
  AsmInstrData(0x0038FF, 0x0030DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FDIV\0"),
  AsmInstrData(0x0038FF, 0x0030DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FIDIV\0"),
  AsmInstrData(0x0038FF, 0x0030DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FIDIV\0"),
  AsmInstrData(0x0038FF, 0x0038D8, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FDIVR\0"),
  AsmInstrData(0x0038FF, 0x0038DC, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FDIVR\0"),
  AsmInstrData(0x0038FF, 0x0038DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FIDIVR\0"),
  AsmInstrData(0x0038FF, 0x0038DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FIDIVR\0"),
  AsmInstrData(0x0038FF, 0x0020DF, 1,00,  MDA,NNN,NNN, C_FLT+C_RARE+1, "FBLD\0"),
  AsmInstrData(0x0038FF, 0x0030DF, 1,00,  MDA,PS0,NNN, C_FLT+C_RARE+1, "FBSTP\0"),
  AsmInstrData(0x0038FF, 0x0010DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FICOM\0"),
  AsmInstrData(0x0038FF, 0x0010DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FICOM\0"),
  AsmInstrData(0x0038FF, 0x0018DE, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FICOMP\0"),
  AsmInstrData(0x0038FF, 0x0018DA, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FICOMP\0"),
  AsmInstrData(0x0038FF, 0x0000DF, 1,00,  MD2,NNN,NNN, C_FLT+1,        "FILD\0"),
  AsmInstrData(0x0038FF, 0x0000DB, 1,00,  MD4,NNN,NNN, C_FLT+1,        "FILD\0"),
  AsmInstrData(0x0038FF, 0x0028DF, 1,00,  MD8,NNN,NNN, C_FLT+1,        "FILD\0"),
  AsmInstrData(0x0038FF, 0x0010DF, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FIST\0"),
  AsmInstrData(0x0038FF, 0x0010DB, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FIST\0"),
  AsmInstrData(0x0038FF, 0x0018DF, 1,00,  MD2,PS0,NNN, C_FLT+1,        "FISTP\0"),
  AsmInstrData(0x0038FF, 0x0018DB, 1,00,  MD4,PS0,NNN, C_FLT+1,        "FISTP\0"),
  AsmInstrData(0x0038FF, 0x0038DF, 1,00,  MD8,PS0,NNN, C_FLT+1,        "FISTP\0"),
  AsmInstrData(0x0038FF, 0x0000D9, 1,00,  MF4,NNN,NNN, C_FLT+1,        "FLD\0"),
  AsmInstrData(0x0038FF, 0x0000DD, 1,00,  MF8,NNN,NNN, C_FLT+1,        "FLD\0"),
  AsmInstrData(0x0038FF, 0x0028DB, 1,00,  MFA,NNN,NNN, C_FLT+1,        "FLD\0"),
  AsmInstrData(0x0038FF, 0x0010D9, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FST\0"),
  AsmInstrData(0x0038FF, 0x0010DD, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FST\0"),
  AsmInstrData(0x0038FF, 0x0018D9, 1,00,  MF4,PS0,NNN, C_FLT+1,        "FSTP\0"),
  AsmInstrData(0x0038FF, 0x0018DD, 1,00,  MF8,PS0,NNN, C_FLT+1,        "FSTP\0"),
  AsmInstrData(0x0038FF, 0x0038DB, 1,00,  MFA,PS0,NNN, C_FLT+1,        "FSTP\0"),
  AsmInstrData(0x0038FF, 0x0028D9, 1,00,  MB2,NNN,NNN, C_FLT+0,        "FLDCW\0"),
  AsmInstrData(0x0038FF, 0x0038D9, 1,00,  MB2,NNN,NNN, C_FLT+0,        "FSTCW\0"),
  AsmInstrData(0x0038FF, 0x0020D9, 1,00,  MFE,NNN,NNN, C_FLT+0,        "FLDENV\0"),
  AsmInstrData(0x0038FF, 0x0030D9, 1,00,  MFE,NNN,NNN, C_FLT+0,        "FSTENV\0"),
  AsmInstrData(0x0038FF, 0x0020DD, 1,00,  MFS,NNN,NNN, C_FLT+0,        "FRSTOR\0"),
  AsmInstrData(0x0038FF, 0x0030DD, 1,00,  MFS,NNN,NNN, C_FLT+0,        "FSAVE\0"),
  AsmInstrData(0x0038FF, 0x0038DD, 1,00,  MB2,NNN,NNN, C_FLT+0,        "FSTSW\0"),
  AsmInstrData(0x38FFFF, 0x08AE0F, 2,00,  MFX,NNN,NNN, C_FLT+0,        "FXRSTOR\0"),
  AsmInstrData(0x38FFFF, 0x00AE0F, 2,00,  MFX,NNN,NNN, C_FLT+0,        "FXSAVE\0"),
  AsmInstrData(0x00FFFF, 0x00E0DB, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FENI\0"),
  AsmInstrData(0x00FFFF, 0x00E1DB, 2,00,  NNN,NNN,NNN, C_FLT+0,        "FDISI\0"),
  // MMX instructions. Length of MMX operand fields (in bytes) is added to the
  // type, length of 0 means 8-byte MMX operand.
  AsmInstrData(0x00FFFF, 0x00770F, 2,00,  NNN,NNN,NNN, C_MMX+0,        "EMMS\0"),
  AsmInstrData(0x00FFFF, 0x006E0F, 2,00,  RMX,MR4,NNN, C_MMX+0,        "MOVD\0"),
  AsmInstrData(0x00FFFF, 0x007E0F, 2,00,  MR4,RMX,NNN, C_MMX+0,        "MOVD\0"),
  AsmInstrData(0x00FFFF, 0x006F0F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "MOVQ\0"),
  AsmInstrData(0x00FFFF, 0x007F0F, 2,00,  MR8,RMX,NNN, C_MMX+0,        "MOVQ\0"),
  AsmInstrData(0x00FFFF, 0x00630F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PACKSSWB\0"),
  AsmInstrData(0x00FFFF, 0x006B0F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PACKSSDW\0"),
  AsmInstrData(0x00FFFF, 0x00670F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PACKUSWB\0"),
  AsmInstrData(0x00FFFF, 0x00FC0F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PADDB\0"),
  AsmInstrData(0x00FFFF, 0x00FD0F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PADDW\0"),
  AsmInstrData(0x00FFFF, 0x00FE0F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PADDD\0"),
  AsmInstrData(0x00FFFF, 0x00F80F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PSUBB\0"),
  AsmInstrData(0x00FFFF, 0x00F90F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PSUBW\0"),
  AsmInstrData(0x00FFFF, 0x00FA0F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PSUBD\0"),
  AsmInstrData(0x00FFFF, 0x00EC0F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PADDSB\0"),
  AsmInstrData(0x00FFFF, 0x00ED0F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PADDSW\0"),
  AsmInstrData(0x00FFFF, 0x00E80F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PSUBSB\0"),
  AsmInstrData(0x00FFFF, 0x00E90F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PSUBSW\0"),
  AsmInstrData(0x00FFFF, 0x00DC0F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PADDUSB\0"),
  AsmInstrData(0x00FFFF, 0x00DD0F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PADDUSW\0"),
  AsmInstrData(0x00FFFF, 0x00D80F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PSUBUSB\0"),
  AsmInstrData(0x00FFFF, 0x00D90F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PSUBUSW\0"),
  AsmInstrData(0x00FFFF, 0x00DB0F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "PAND\0"),
  AsmInstrData(0x00FFFF, 0x00DF0F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "PANDN\0"),
  AsmInstrData(0x00FFFF, 0x00740F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PCMPEQB\0"),
  AsmInstrData(0x00FFFF, 0x00750F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PCMPEQW\0"),
  AsmInstrData(0x00FFFF, 0x00760F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PCMPEQD\0"),
  AsmInstrData(0x00FFFF, 0x00640F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PCMPGTB\0"),
  AsmInstrData(0x00FFFF, 0x00650F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PCMPGTW\0"),
  AsmInstrData(0x00FFFF, 0x00660F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PCMPGTD\0"),
  AsmInstrData(0x00FFFF, 0x00F50F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PMADDWD\0"),
  AsmInstrData(0x00FFFF, 0x00E50F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PMULHW\0"),
  AsmInstrData(0x00FFFF, 0x00D50F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PMULLW\0"),
  AsmInstrData(0x00FFFF, 0x00EB0F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "POR\0"),
  AsmInstrData(0x00FFFF, 0x00F10F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PSLLW\0"),
  AsmInstrData(0x38FFFF, 0x30710F, 2,00,  MR8,IM1,NNN, C_MMX+2,        "PSLLW\0"),
  AsmInstrData(0x00FFFF, 0x00F20F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PSLLD\0"),
  AsmInstrData(0x38FFFF, 0x30720F, 2,00,  MR8,IM1,NNN, C_MMX+4,        "PSLLD\0"),
  AsmInstrData(0x00FFFF, 0x00F30F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "PSLLQ\0"),
  AsmInstrData(0x38FFFF, 0x30730F, 2,00,  MR8,IM1,NNN, C_MMX+0,        "PSLLQ\0"),
  AsmInstrData(0x00FFFF, 0x00E10F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PSRAW\0"),
  AsmInstrData(0x38FFFF, 0x20710F, 2,00,  MR8,IM1,NNN, C_MMX+2,        "PSRAW\0"),
  AsmInstrData(0x00FFFF, 0x00E20F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PSRAD\0"),
  AsmInstrData(0x38FFFF, 0x20720F, 2,00,  MR8,IM1,NNN, C_MMX+4,        "PSRAD\0"),
  AsmInstrData(0x00FFFF, 0x00D10F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PSRLW\0"),
  AsmInstrData(0x38FFFF, 0x10710F, 2,00,  MR8,IM1,NNN, C_MMX+2,        "PSRLW\0"),
  AsmInstrData(0x00FFFF, 0x00D20F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PSRLD\0"),
  AsmInstrData(0x38FFFF, 0x10720F, 2,00,  MR8,IM1,NNN, C_MMX+4,        "PSRLD\0"),
  AsmInstrData(0x00FFFF, 0x00D30F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "PSRLQ\0"),
  AsmInstrData(0x38FFFF, 0x10730F, 2,00,  MR8,IM1,NNN, C_MMX+0,        "PSRLQ\0"),
  AsmInstrData(0x00FFFF, 0x00680F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PUNPCKHBW\0"),
  AsmInstrData(0x00FFFF, 0x00690F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PUNPCKHWD\0"),
  AsmInstrData(0x00FFFF, 0x006A0F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PUNPCKHDQ\0"),
  AsmInstrData(0x00FFFF, 0x00600F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PUNPCKLBW\0"),
  AsmInstrData(0x00FFFF, 0x00610F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PUNPCKLWD\0"),
  AsmInstrData(0x00FFFF, 0x00620F, 2,00,  RMX,MR8,NNN, C_MMX+4,        "PUNPCKLDQ\0"),
  AsmInstrData(0x00FFFF, 0x00EF0F, 2,00,  RMX,MR8,NNN, C_MMX+0,        "PXOR\0"),
  // AMD extentions to MMX command set (including Athlon/PIII extentions).
  AsmInstrData(0x00FFFF, 0x000E0F, 2,00,  NNN,NNN,NNN, C_MMX+0,        "FEMMS\0"),
  AsmInstrData(0x38FFFF, 0x000D0F, 2,00,  MD8,NNN,NNN, C_MMX+0,        "PREFETCH\0"),
  AsmInstrData(0x38FFFF, 0x080D0F, 2,00,  MD8,NNN,NNN, C_MMX+0,        "PREFETCHW\0"),
  AsmInstrData(0x00FFFF, 0x00F70F, 2,00,  RMX,RR8,PDI, C_MMX+1,        "MASKMOVQ\0"),
  AsmInstrData(0x00FFFF, 0x00E70F, 2,00,  MD8,RMX,NNN, C_MMX+0,        "MOVNTQ\0"),
  AsmInstrData(0x00FFFF, 0x00E00F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PAVGB\0"),
  AsmInstrData(0x00FFFF, 0x00E30F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PAVGW\0"),
  AsmInstrData(0x00FFFF, 0x00C50F, 2,00,  RR4,RMX,IM1, C_MMX+2,        "PEXTRW\0"),
  AsmInstrData(0x00FFFF, 0x00C40F, 2,00,  RMX,MR2,IM1, C_MMX+2,        "PINSRW\0"),
  AsmInstrData(0x00FFFF, 0x00EE0F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PMAXSW\0"),
  AsmInstrData(0x00FFFF, 0x00DE0F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PMAXUB\0"),
  AsmInstrData(0x00FFFF, 0x00EA0F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PMINSW\0"),
  AsmInstrData(0x00FFFF, 0x00DA0F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PMINUB\0"),
  AsmInstrData(0x00FFFF, 0x00D70F, 2,00,  RG4,RR8,NNN, C_MMX+1,        "PMOVMSKB\0"),
  AsmInstrData(0x00FFFF, 0x00E40F, 2,00,  RMX,MR8,NNN, C_MMX+2,        "PMULHUW\0"),
  AsmInstrData(0x38FFFF, 0x00180F, 2,00,  MD8,NNN,NNN, C_MMX+0,        "PREFETCHNTA\0"),
  AsmInstrData(0x38FFFF, 0x08180F, 2,00,  MD8,NNN,NNN, C_MMX+0,        "PREFETCHT0\0"),
  AsmInstrData(0x38FFFF, 0x10180F, 2,00,  MD8,NNN,NNN, C_MMX+0,        "PREFETCHT1\0"),
  AsmInstrData(0x38FFFF, 0x18180F, 2,00,  MD8,NNN,NNN, C_MMX+0,        "PREFETCHT2\0"),
  AsmInstrData(0x00FFFF, 0x00F60F, 2,00,  RMX,MR8,NNN, C_MMX+1,        "PSADBW\0"),
  AsmInstrData(0x00FFFF, 0x00700F, 2,00,  RMX,MR8,IM1, C_MMX+2,        "PSHUFW\0"),
  AsmInstrData(0xFFFFFF, 0xF8AE0F, 2,00,  NNN,NNN,NNN, C_MMX+0,        "SFENCE\0"),
  // AMD 3DNow! instructions (including Athlon extentions).
  AsmInstrData(0x00FFFF, 0xBF0F0F, 2,00,  RMX,MR8,NNN, C_NOW+1,        "PAVGUSB\0"),
  AsmInstrData(0x00FFFF, 0x9E0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFADD\0"),
  AsmInstrData(0x00FFFF, 0x9A0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFSUB\0"),
  AsmInstrData(0x00FFFF, 0xAA0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFSUBR\0"),
  AsmInstrData(0x00FFFF, 0xAE0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFACC\0"),
  AsmInstrData(0x00FFFF, 0x900F0F, 2,00,  RMX,MRD,NNN, C_NOW+4,        "PFCMPGE\0"),
  AsmInstrData(0x00FFFF, 0xA00F0F, 2,00,  RMX,MRD,NNN, C_NOW+4,        "PFCMPGT\0"),
  AsmInstrData(0x00FFFF, 0xB00F0F, 2,00,  RMX,MRD,NNN, C_NOW+4,        "PFCMPEQ\0"),
  AsmInstrData(0x00FFFF, 0x940F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFMIN\0"),
  AsmInstrData(0x00FFFF, 0xA40F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFMAX\0"),
  AsmInstrData(0x00FFFF, 0x0D0F0F, 2,00,  R3D,MR8,NNN, C_NOW+4,        "PI2FD\0"),
  AsmInstrData(0x00FFFF, 0x1D0F0F, 2,00,  RMX,MRD,NNN, C_NOW+4,        "PF2ID\0"),
  AsmInstrData(0x00FFFF, 0x960F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFRCP\0"),
  AsmInstrData(0x00FFFF, 0x970F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFRSQRT\0"),
  AsmInstrData(0x00FFFF, 0xB40F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFMUL\0"),
  AsmInstrData(0x00FFFF, 0xA60F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFRCPIT1\0"),
  AsmInstrData(0x00FFFF, 0xA70F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFRSQIT1\0"),
  AsmInstrData(0x00FFFF, 0xB60F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFRCPIT2\0"),
  AsmInstrData(0x00FFFF, 0xB70F0F, 2,00,  RMX,MR8,NNN, C_NOW+2,        "PMULHRW\0"),
  AsmInstrData(0x00FFFF, 0x1C0F0F, 2,00,  RMX,MRD,NNN, C_NOW+4,        "PF2IW\0"),
  AsmInstrData(0x00FFFF, 0x8A0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFNACC\0"),
  AsmInstrData(0x00FFFF, 0x8E0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PFPNACC\0"),
  AsmInstrData(0x00FFFF, 0x0C0F0F, 2,00,  R3D,MR8,NNN, C_NOW+4,        "PI2FW\0"),
  AsmInstrData(0x00FFFF, 0xBB0F0F, 2,00,  R3D,MRD,NNN, C_NOW+4,        "PSWAPD\0"),
  // Some alternative mnemonics for Assembler, not used by Disassembler (so implicit pseudooperands are not marked).
  AsmInstrData(0x0000FF, 0x0000A6, 1,00,  NNN,NNN,NNN, C_CMD+0,        "CMPSB\0"),
  AsmInstrData(0x00FFFF, 0x00A766, 2,00,  NNN,NNN,NNN, C_CMD+0,        "CMPSW\0"),
  AsmInstrData(0x0000FF, 0x0000A7, 1,00,  NNN,NNN,NNN, C_CMD+0,        "CMPSD\0"),
  AsmInstrData(0x0000FF, 0x0000AC, 1,00,  NNN,NNN,NNN, C_CMD+0,        "LODSB\0"),
  AsmInstrData(0x00FFFF, 0x00AD66, 2,00,  NNN,NNN,NNN, C_CMD+0,        "LODSW\0"),
  AsmInstrData(0x0000FF, 0x0000AD, 1,00,  NNN,NNN,NNN, C_CMD+0,        "LODSD\0"),
  AsmInstrData(0x0000FF, 0x0000A4, 1,00,  NNN,NNN,NNN, C_CMD+0,        "MOVSB\0"),
  AsmInstrData(0x00FFFF, 0x00A566, 2,00,  NNN,NNN,NNN, C_CMD+0,        "MOVSW\0"),
  AsmInstrData(0x0000FF, 0x0000A5, 1,00,  NNN,NNN,NNN, C_CMD+0,        "MOVSD\0"),
  AsmInstrData(0x0000FF, 0x0000AE, 1,00,  NNN,NNN,NNN, C_CMD+0,        "SCASB\0"),
  AsmInstrData(0x00FFFF, 0x00AF66, 1,00,  NNN,NNN,NNN, C_CMD+0,        "SCASW\0"),
  AsmInstrData(0x0000FF, 0x0000AF, 1,00,  NNN,NNN,NNN, C_CMD+0,        "SCASD\0"),
  AsmInstrData(0x0000FF, 0x0000AA, 1,00,  NNN,NNN,NNN, C_CMD+0,        "STOSB\0"),
  AsmInstrData(0x00FFFF, 0x00AB66, 2,00,  NNN,NNN,NNN, C_CMD+0,        "STOSW\0"),
  AsmInstrData(0x0000FF, 0x0000AB, 1,00,  NNN,NNN,NNN, C_CMD+0,        "STOSD\0"),
  AsmInstrData(0x00FFFF, 0x00A4F3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP MOVSB\0"),
  AsmInstrData(0xFFFFFF, 0xA5F366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REP MOVSW\0"),
  AsmInstrData(0x00FFFF, 0x00A5F3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP MOVSD\0"),
  AsmInstrData(0x00FFFF, 0x00ACF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP LODSB\0"),
  AsmInstrData(0xFFFFFF, 0xADF366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REP LODSW\0"),
  AsmInstrData(0x00FFFF, 0x00ADF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP LODSD\0"),
  AsmInstrData(0x00FFFF, 0x00AAF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP STOSB\0"),
  AsmInstrData(0xFFFFFF, 0xABF366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REP STOSW\0"),
  AsmInstrData(0x00FFFF, 0x00ABF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP STOSD\0"),
  AsmInstrData(0x00FFFF, 0x00A6F3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPE CMPSB\0"),
  AsmInstrData(0xFFFFFF, 0xA7F366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REPE CMPSW\0"),
  AsmInstrData(0x00FFFF, 0x00A7F3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPE CMPSD\0"),
  AsmInstrData(0x00FFFF, 0x00AEF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPE SCASB\0"),
  AsmInstrData(0xFFFFFF, 0xAFF366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REPE SCASW\0"),
  AsmInstrData(0x00FFFF, 0x00AFF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPE SCASD\0"),
  AsmInstrData(0x00FFFF, 0x00A6F2, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPNE CMPSB\0"),
  AsmInstrData(0xFFFFFF, 0xA7F266, 2,00,  NNN,NNN,NNN, C_REP+0,        "REPNE CMPSW\0"),
  AsmInstrData(0x00FFFF, 0x00A7F2, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPNE CMPSD\0"),
  AsmInstrData(0x00FFFF, 0x00AEF2, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPNE SCASB\0"),
  AsmInstrData(0xFFFFFF, 0xAFF266, 2,00,  NNN,NNN,NNN, C_REP+0,        "REPNE SCASW\0"),
  AsmInstrData(0x00FFFF, 0x00AFF2, 1,00,  NNN,NNN,NNN, C_REP+0,        "REPNE SCASD\0"),
  AsmInstrData(0x0000FF, 0x00006C, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "INSB\0"),
  AsmInstrData(0x00FFFF, 0x006D66, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "INSW\0"),
  AsmInstrData(0x0000FF, 0x00006D, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "INSD\0"),
  AsmInstrData(0x0000FF, 0x00006E, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "OUTSB\0"),
  AsmInstrData(0x00FFFF, 0x006F66, 2,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "OUTSW\0"),
  AsmInstrData(0x0000FF, 0x00006F, 1,00,  NNN,NNN,NNN, C_CMD+C_RARE+0, "OUTSD\0"),
  AsmInstrData(0x00FFFF, 0x006CF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP INSB\0"),
  AsmInstrData(0xFFFFFF, 0x6DF366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REP INSW\0"),
  AsmInstrData(0x00FFFF, 0x006DF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP INSD\0"),
  AsmInstrData(0x00FFFF, 0x006EF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP OUTSB\0"),
  AsmInstrData(0xFFFFFF, 0x6FF366, 2,00,  NNN,NNN,NNN, C_REP+0,        "REP OUTSW\0"),
  AsmInstrData(0x00FFFF, 0x006FF3, 1,00,  NNN,NNN,NNN, C_REP+0,        "REP OUTSD\0"),
  AsmInstrData(0x0000FF, 0x0000E1, 1,00,  JOB,NNN,NNN, C_JMC+0,        "$LOOP*Z\0"),
  AsmInstrData(0x0000FF, 0x0000E0, 1,00,  JOB,NNN,NNN, C_JMC+0,        "$LOOP*NZ\0"),
  AsmInstrData(0x0000FF, 0x00009B, 1,00,  NNN,NNN,NNN, C_CMD+0,        "FWAIT\0"),
  AsmInstrData(0x0000FF, 0x0000D7, 1,00,  NNN,NNN,NNN, C_CMD+0,        "XLATB\0"),
  AsmInstrData(0x00FFFF, 0x00C40F, 2,00,  RMX,RR4,IM1, C_MMX+2,        "PINSRW\0"),
  AsmInstrData(0x00FFFF, 0x0020CD, 2,00,  VXD,NNN,NNN, C_CAL+C_RARE+0, "VxDCall\0"),
  // Pseudocommands used by Assembler for masked search only.
  AsmInstrData(0x0000F0, 0x000070, 1,CC,  JOB,NNN,NNN, C_JMC+0,        "JCC\0"),
  AsmInstrData(0x00F0FF, 0x00800F, 2,CC,  JOW,NNN,NNN, C_JMC+0,        "JCC\0"),
  AsmInstrData(0x00F0FF, 0x00900F, 2,CC,  MR1,NNN,NNN, C_CMD+1,        "SETCC\0"),
  AsmInstrData(0x00F0FF, 0x00400F, 2,CC,  REG,MRG,NNN, C_CMD+0,        "CMOVCC\0"),
];

// ////////////////////////////////////////////////////////////////////////// //
// Scanner modes.
enum SA_NAME   = 0x0001; // Don't try to decode labels
enum SA_IMPORT = 0x0002; // Allow import pseudolabel

// Types of input tokens reported by scanner.
enum SCAN_EOL =       0;   // End of line
enum SCAN_REG8 =      1;   // 8-bit register
enum SCAN_REG16 =     2;   // 16-bit register
enum SCAN_REG32 =     3;   // 32-bit register
enum SCAN_SEG =       4;   // Segment register
enum SCAN_FPU =       5;   // FPU register
enum SCAN_MMX =       6;   // MMX register
enum SCAN_CR =        7;   // Control register
enum SCAN_DR =        8;   // Debug register
enum SCAN_OPSIZE =    9;   // Operand size modifier
enum SCAN_JMPSIZE =   10;  // Jump size modifier
enum SCAN_LOCAL =     11;  // Address on stack in form LOCAL.decimal
enum SCAN_ARG =       12;  // Address on stack in form ARG.decimal
enum SCAN_PTR =       20;  // PTR in MASM addressing statements
enum SCAN_REP =       21;  // REP prefix
enum SCAN_REPE =      22;  // REPE prefix
enum SCAN_REPNE =     23;  // REPNE prefix
enum SCAN_LOCK =      24;  // LOCK prefix
enum SCAN_NAME =      25;  // Command or label
enum SCAN_ICONST =    26;  // Hexadecimal constant
enum SCAN_DCONST =    27;  // Decimal constant
enum SCAN_OFS =       28;  // Undefined constant
enum SCAN_FCONST =    29;  // Floating-point constant
enum SCAN_EIP =       30;  // Register EIP
enum SCAN_SIGNED =    31;  // Keyword "SIGNED" (in expressions)
enum SCAN_UNSIGNED =  32;  // Keyword "UNSIGNED" (in expressions)
enum SCAN_CHAR =      33;  // Keyword "CHAR" (in expressions)
enum SCAN_FLOAT =     34;  // Keyword "FLOAT" (in expressions)
enum SCAN_DOUBLE =    35;  // Keyword "DOUBLE" (in expressions)
enum SCAN_FLOAT10 =   36;  // Keyword "FLOAT10" (in expressions)
enum SCAN_STRING =    37;  // Keyword "STRING" (in expressions)
enum SCAN_UNICODE =   38;  // Keyword "UNICODE" (in expressions)
enum SCAN_MSG =       39;  // Pseudovariable MSG (in expressions)

enum SCAN_SYMB =      64;  // Any other character
enum SCAN_IMPORT =    65;  // Import pseudolabel
enum SCAN_ERR =       255; // Definitely bad item

// Definition used by Assembler to report command matching errors.
enum MA_JMP = 0x0001; // Invalid jump size modifier
enum MA_NOP = 0x0002; // Wrong number of operands
enum MA_TYP = 0x0004; // Bad operand type
enum MA_NOS = 0x0008; // Explicit operand size expected
enum MA_SIZ = 0x0010; // Bad operand size
enum MA_DIF = 0x0020; // Different operand sizes
enum MA_SEG = 0x0040; // Invalid segment register
enum MA_RNG = 0x0080; // Constant out of expected range

struct AsmOperand {
  int type;      // Operand type, see beginning of file
  int size;      // Operand size or 0 if yet unknown
  int index;     // Index or other register
  int scale;     // Scale
  int base;      // Base register if present
  int offset;    // Immediate value or offset
  int anyoffset; // Offset is present but undefined
  int segment;   // Segment in address if present
  int jmpmode;   // Specified jump size
}

struct AsmScanData {
  char[4096] acommand; // 0-terminated copy
  const(char)* asmcmd; // Pointer to 0-terminated source line
  int scan;            // Type of last scanned element
  int prio;            // Priority of operation (0: highest)
  char[TEXTLEN] sdata; // Last scanned name (depends on type)
  int idata;           // Last scanned value
  real fdata;          // Floating-point number
  string asmerror;     // Explanation of last error, or null

  void skipBlanks () nothrow @nogc {
    while (*asmcmd > 0 && *asmcmd <= ' ') ++asmcmd;
  }
}

private template S2toI(string s) if (s.length == 2) {
  enum S2toI = cast(int)s[0]|((cast(int)s[1])<<8);
}

// Simple and slightly recursive scanner shared by Assemble(). The scanner is
// straightforward and ineffective, but high speed is not a must here. As
// input, it uses global pointer to source line asmcmd. On exit, it fills in
// global variables scan, prio, sdata, idata and/or fdata. If some error is
// detected, asmerror points to error message, otherwise asmerror remains
// unchanged.
private void strupr (char* s) {
  import core.stdc.ctype : toupper;
  while (*s) {
    *s = cast(char)toupper(*s);
    ++s;
  }
}

private void strcpyx (char* d, const(char)[] s) {
  import core.stdc.string : memcpy;
  if (d is null) return;
  if (s.length == 0) {
    *d = 0;
  } else {
    memcpy(d, s.ptr, s.length);
    d[s.length] = 0;
  }
}

private void xstrcpy (char[] d, const(char)* s) {
  if (d.length == 0) return;
  uint pos;
  if (s !is null) {
    while (*s) {
      if (pos >= d.length) break;
      d.ptr[pos++] = *s++;
    }
  }
  if (pos < d.length) d.ptr[pos] = 0;
}

private void xstrcpyx (char[] d, const(char)[] s) {
  if (d.length == 0) return;
  uint pos;
  foreach (char ch; s) {
    if (ch == 0 || pos >= d.length) break;
    d.ptr[pos++] = ch;
  }
  if (pos < d.length) d.ptr[pos] = 0;
}

private int strnicmp (const(char)* s0, const(char)* s1, int len) {
  import core.stdc.ctype : toupper;
  if (len < 1) return 0;
  while (len-- > 0) {
    int c0 = toupper(*s0++);
    int c1 = toupper(*s1++);
    if (c0 != c1) return (c0 < c1 ? -1 : 1);
    if (c0 == 0) return -1;
    if (c1 == 0) return 1;
  }
  return 0;
}

private void scanasm (ref AsmScanData scdata, int mode) {
  import core.stdc.ctype : isalpha, isalnum, isdigit, toupper, isxdigit;
  import core.stdc.string : strcmp, strcpy;

  int i, j, base, maxdigit;
  int decimal, hex;
  real floating, divisor;
  char[TEXTLEN] s;
  const(char)* pcmd;

  scdata.sdata[0] = '\0';
  scdata.idata = 0;
  if (scdata.asmcmd is null) { scdata.asmerror = "null input line"; scdata.scan = SCAN_ERR; return; }
  scdata.skipBlanks(); // Skip leading spaces
  if (*scdata.asmcmd == '\0' || *scdata.asmcmd == ';') { scdata.scan = SCAN_EOL; return; } // Empty line
  if (isalpha(*scdata.asmcmd) || *scdata.asmcmd == '_' || *scdata.asmcmd == '@') {
    // Some keyword or identifier
    scdata.sdata[0] = *scdata.asmcmd++;
    i = 1;
    while ((isalnum(*scdata.asmcmd) || *scdata.asmcmd == '_' || *scdata.asmcmd == '@') && i < scdata.sdata.sizeof) scdata.sdata[i++] = *scdata.asmcmd++;
    if (i >= scdata.sdata.sizeof) { scdata.asmerror = "Too long identifier"; scdata.scan = SCAN_ERR; return; }
    scdata.sdata[i] = '\0';
    scdata.skipBlanks(); // Skip trailing spaces
    strcpy(s.ptr, scdata.sdata.ptr); strupr(s.ptr);
    // j == 8 means "any register"
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, regname[0][j].ptr) != 0) continue;
      // 8-bit register
      scdata.idata = j;
      scdata.scan = SCAN_REG8;
      return;
    }
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, regname[1][j].ptr) != 0) continue;
      // 16-bit register
      scdata.idata = j;
      scdata.scan = SCAN_REG16;
      return;
    }
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, regname[2][j].ptr) != 0) continue;
      // 32-bit register
      scdata.idata = j;
      scdata.scan = SCAN_REG32;
      return;
    }
    for (j = 0; j < 6; ++j) {
      if (strcmp(s.ptr, segname[j].ptr) != 0) continue;
      // Segment register
      scdata.idata = j;
      scdata.scan = SCAN_SEG;
      scdata.skipBlanks(); // Skip trailing spaces
      return;
    }
    if (strcmp(s.ptr, "ST") == 0) {
      // FPU register
      pcmd = scdata.asmcmd;
      scanasm(scdata, SA_NAME);
      if (scdata.scan != SCAN_SYMB || scdata.idata != '(') {
        // Undo last scan
        scdata.asmcmd = pcmd;
        scdata.idata = 0;
        scdata.scan = SCAN_FPU;
        return;
      }
      scanasm(scdata, SA_NAME);
      j = scdata.idata;
      if ((scdata.scan != SCAN_ICONST && scdata.scan != SCAN_DCONST) || scdata.idata < 0 || scdata.idata > 7) {
        scdata.asmerror = "FPU registers have indexes 0 to 7";
        scdata.scan = SCAN_ERR;
        return;
      }
      scanasm(scdata, SA_NAME);
      if (scdata.scan != SCAN_SYMB || scdata.idata != ')') {
        scdata.asmerror = "Closing parenthesis expected";
        scdata.scan = SCAN_ERR;
        return;
      }
      scdata.idata = j; scdata.scan = SCAN_FPU;
      return;
    }
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, fpuname[j].ptr) != 0) continue;
      // FPU register (alternative coding)
      scdata.idata = j;
      scdata.scan = SCAN_FPU;
      return;
    }
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, mmxname[j].ptr) != 0) continue;
      // MMX register
      scdata.idata = j;
      scdata.scan = SCAN_MMX;
      return;
    }
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, crname[j].ptr) != 0) continue;
      // Control register
      scdata.idata = j;
      scdata.scan = SCAN_CR;
      return;
    }
    for (j = 0; j <= 8; ++j) {
      if (strcmp(s.ptr, drname[j].ptr) != 0) continue;
      // Debug register
      scdata.idata = j;
      scdata.scan = SCAN_DR;
      return;
    }
    for (j = 0; j < sizename.length; ++j) {
      if (strcmp(s.ptr, sizename[j].ptr) != 0) continue;
      pcmd = scdata.asmcmd;
      scanasm(scdata, SA_NAME);
      if (scdata.scan != SCAN_PTR) scdata.asmcmd = pcmd; // Fetch non-functional "PTR"
      // Operand (data) size in bytes
      scdata.idata = j;
      scdata.scan = SCAN_OPSIZE;
      return;
    }
    if (strcmp(s.ptr, "EIP") == 0) { scdata.scan = SCAN_EIP; scdata.idata = 0; return; } // Register EIP
    if (strcmp(s.ptr, "SHORT") == 0) { scdata.scan = SCAN_JMPSIZE; scdata.idata = 1; return; } // Relative jump has 1-byte offset
    if (strcmp(s.ptr, "LONG") == 0) { scdata.scan = SCAN_JMPSIZE; scdata.idata = 2; return; } // Relative jump has 4-byte offset
    if (strcmp(s.ptr, "NEAR") == 0) { scdata.scan = SCAN_JMPSIZE; scdata.idata = 4; return; } // Jump within same code segment
    if (strcmp(s.ptr, "FAR") == 0) { scdata.scan = SCAN_JMPSIZE; scdata.idata = 8; return; } // Jump to different code segment
    if (strcmp(s.ptr, "LOCAL") == 0 && *scdata.asmcmd == '.') {
      ++scdata.asmcmd;
      scdata.skipBlanks(); // Skip trailing spaces
      if (!isdigit(*scdata.asmcmd)) {
        scdata.asmerror = "Integer number expected";
        scdata.scan = SCAN_ERR;
        return;
      }
      while (isdigit(*scdata.asmcmd)) scdata.idata = scdata.idata*10+(*scdata.asmcmd++)-'0'; // LOCAL index is decimal number!
      scdata.scan = SCAN_LOCAL;
      return;
    }
    if (strcmp(s.ptr, "ARG") == 0 && *scdata.asmcmd == '.') {
      ++scdata.asmcmd;
      scdata.skipBlanks(); // Skip trailing spaces
      if (!isdigit(*scdata.asmcmd)) {
        scdata.asmerror = "Integer number expected";
        scdata.scan = SCAN_ERR;
        return;
      }
      while (isdigit(*scdata.asmcmd)) scdata.idata = scdata.idata*10+(*scdata.asmcmd++)-'0'; // ARG index is decimal number!
      scdata.scan = SCAN_ARG;
      return;
    }
    if (strcmp(s.ptr, "REP") == 0) { scdata.scan = SCAN_REP; return; } // REP prefix
    if (strcmp(s.ptr, "REPE") == 0 || strcmp(s.ptr, "REPZ") == 0) { scdata.scan = SCAN_REPE; return; } // REPE prefix
    if (strcmp(s.ptr, "REPNE") == 0 || strcmp(s.ptr, "REPNZ") == 0) { scdata.scan = SCAN_REPNE; return; } // REPNE prefix
    if (strcmp(s.ptr, "LOCK") == 0) { scdata.scan = SCAN_LOCK; return; } // LOCK prefix
    if (strcmp(s.ptr, "PTR") == 0) { scdata.scan = SCAN_PTR; return; } // PTR in MASM addressing statements
    if (strcmp(s.ptr, "CONST") == 0 || strcmp(s.ptr, "OFFSET") == 0) { scdata.scan = SCAN_OFS; return; } // Present but undefined offset/constant
    if (strcmp(s.ptr, "SIGNED") == 0) { scdata.scan = SCAN_SIGNED; return; } // Keyword "SIGNED" (in expressions)
    if (strcmp(s.ptr, "UNSIGNED") == 0) { scdata.scan = SCAN_UNSIGNED; return; } // Keyword "UNSIGNED" (in expressions)
    if (strcmp(s.ptr, "CHAR") == 0) { scdata.scan = SCAN_CHAR; return; } // Keyword "CHAR" (in expressions)
    if (strcmp(s.ptr, "FLOAT") == 0) { scdata.scan = SCAN_FLOAT; return; } // Keyword "FLOAT" (in expressions)
    if (strcmp(s.ptr, "DOUBLE") == 0) { scdata.scan = SCAN_DOUBLE; return; } // Keyword "DOUBLE" (in expressions)
    if (strcmp(s.ptr, "FLOAT10") == 0) { scdata.scan = SCAN_FLOAT10; return; } // Keyword "FLOAT10" (in expressions)
    if (strcmp(s.ptr, "STRING") == 0) { scdata.scan = SCAN_STRING; return; } // Keyword "STRING" (in expressions)
    if (strcmp(s.ptr, "UNICODE") == 0) { scdata.scan = SCAN_UNICODE; return; } // Keyword "UNICODE" (in expressions)
    if (strcmp(s.ptr, "MSG") == 0) { scdata.scan = SCAN_MSG; return; } // Pseudovariable MSG (in expressions)
    if (mode&SA_NAME) { scdata.idata = i; scdata.scan = SCAN_NAME; return; } // Don't try to decode symbolic label
    scdata.asmerror = "Unknown identifier";
    scdata.scan = SCAN_ERR;
    return;
  } else if (isdigit(*scdata.asmcmd)) {
    // Constant
    base = 0;
    maxdigit = 0;
    decimal = hex = 0;
    floating = 0;
    if (scdata.asmcmd[0] == '0' && toupper(scdata.asmcmd[1]) == 'X') { base = 16; scdata.asmcmd += 2; } // Force hexadecimal number
    for (;;) {
      if (isdigit(*scdata.asmcmd)) {
        decimal = decimal*10+(*scdata.asmcmd)-'0';
        floating = floating*10.0+(*scdata.asmcmd)-'0';
        hex = hex*16+(*scdata.asmcmd)-'0';
        if (maxdigit == 0) maxdigit = 9;
        ++scdata.asmcmd;
      } else if (isxdigit(*scdata.asmcmd)) {
        hex = hex*16+toupper(*scdata.asmcmd++)-'A'+10;
        maxdigit = 15;
      } else {
        break;
      }
    }
    if (maxdigit == 0) {
      scdata.asmerror = "Hexadecimal digits after 0x... expected";
      scdata.scan = SCAN_ERR;
      return;
    }
    if (toupper(*scdata.asmcmd) == 'H') {
      // Force hexadecimal number
      if (base == 16) {
        scdata.asmerror = "Please don't mix 0xXXXX and XXXXh forms";
        scdata.scan = SCAN_ERR;
        return;
      }
      ++scdata.asmcmd;
      scdata.idata = hex;
      scdata.scan = SCAN_ICONST;
      scdata.skipBlanks();
      return;
    }
    if (*scdata.asmcmd == '.') {                // Force decimal number
      if (base == 16 || maxdigit > 9) { scdata.asmerror = "Not a decimal number"; scdata.scan = SCAN_ERR; return; }
      ++scdata.asmcmd;
      if (isdigit(*scdata.asmcmd) || toupper(*scdata.asmcmd) == 'E') {
        divisor = 1;
        // Floating-point number
        while (isdigit(*scdata.asmcmd)) {
          divisor /= 10.0;
          floating += divisor*(*scdata.asmcmd-'0');
          ++scdata.asmcmd;
        }
        if (toupper(*scdata.asmcmd) == 'E') {
          ++scdata.asmcmd;
          if (*scdata.asmcmd == '-') { base = -1; scdata.asmcmd++; } else base = 1;
          if (!isdigit(*scdata.asmcmd)) { scdata.asmerror = "Invalid exponent"; scdata.scan = SCAN_ERR; return; }
          decimal = 0;
          while (isdigit(*scdata.asmcmd)) { if (decimal < 65536) decimal = decimal*10+(*scdata.asmcmd++)-'0'; }
          //floating *= pow10l(decimal*base);
          real dx = 1;
          if (base == -1) {
            while (decimal-- > 0) dx /= 10;
          } else {
            assert(base == 1);
            while (decimal-- > 0) dx *= 10;
          }
          floating *= dx;
        }
        scdata.fdata = floating;
        scdata.scan = SCAN_FCONST;
        return;
      } else {
        scdata.idata = decimal;
        scdata.scan = SCAN_DCONST;
        scdata.skipBlanks();
        return;
      }
    }
    // Default is hexadecimal
    scdata.idata = hex;
    scdata.scan = SCAN_ICONST;
    scdata.skipBlanks();
    return;
  } else if (*scdata.asmcmd == '\'') {
    // Character constant
    ++scdata.asmcmd;
    if (*scdata.asmcmd == '\0' || (*scdata.asmcmd == '\\' && scdata.asmcmd[1] == '\0'))  { scdata.asmerror = "Unterminated character constant"; scdata.scan = SCAN_ERR; return; }
    if (*scdata.asmcmd == '\'') { scdata.asmerror = "Empty character constant"; scdata.scan = SCAN_ERR; return; }
    if (*scdata.asmcmd == '\\') ++scdata.asmcmd;
    scdata.idata = *scdata.asmcmd++;
    if (*scdata.asmcmd != '\'')  { scdata.asmerror = "Unterminated character constant"; scdata.scan = SCAN_ERR; return; }
    ++scdata.asmcmd;
    scdata.skipBlanks();
    scdata.scan = SCAN_ICONST;
    return;
  } else {
    // Any other character or combination
    scdata.idata = scdata.sdata[0] = *scdata.asmcmd++;
    scdata.sdata[1] = scdata.sdata[2] = '\0';
    if (scdata.idata == '|' && *scdata.asmcmd == '|') {
      // '||'
      scdata.idata = S2toI!("||");
      scdata.prio = 10;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '&' && *scdata.asmcmd == '&') {
      // '&&'
      scdata.idata = S2toI!("&&");
      scdata.prio = 9;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '=' && *scdata.asmcmd == '=') {
      // '=='
      scdata.idata = S2toI!("==");
      scdata.prio = 5;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '!' && *scdata.asmcmd == '=') {
      // '!='
      scdata.idata = S2toI!("!=");
      scdata.prio = 5;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '<' && *scdata.asmcmd == '=') {
      // '<='
      scdata.idata = S2toI!("<=");
      scdata.prio = 4;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '>' && *scdata.asmcmd == '=') {
      // '>='
      scdata.idata = S2toI!(">=");
      scdata.prio = 4;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '<' && *scdata.asmcmd == '<') {
      // '<<'
      scdata.idata = S2toI!("<<");
      scdata.prio = 3;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '>' && *scdata.asmcmd == '>') {
      // '>>'
      scdata.idata = S2toI!(">>");
      scdata.prio = 3;
      scdata.sdata[1] = *scdata.asmcmd++;
    } else if (scdata.idata == '|') {
      // '|'
      scdata.prio = 8;
    } else if (scdata.idata == '^') {
      // '^'
      scdata.prio = 7;
    } else if (scdata.idata == '&') {
      // '&'
      scdata.prio = 6;
    } else if (scdata.idata == '<') {
      if (*scdata.asmcmd == '&') {
        // Import pseudolabel (for internal use)
        if ((mode&SA_IMPORT) == 0) { scdata.asmerror = "Syntax error"; scdata.scan = SCAN_ERR; return; }
        ++scdata.asmcmd;
        i = 0;
        while (*scdata.asmcmd != '\0' && *scdata.asmcmd != '>') {
          scdata.sdata[i++] = *scdata.asmcmd++;
          if (i >= scdata.sdata.sizeof) { scdata.asmerror = "Too long import name"; scdata.scan = SCAN_ERR; return; }
        }
        if (*scdata.asmcmd != '>') { scdata.asmerror = "Unterminated import name"; scdata.scan = SCAN_ERR; return; }
        ++scdata.asmcmd;
        scdata.sdata[i] = '\0';
        scdata.scan = SCAN_IMPORT;
        return;
      } else {
        // '<'
        scdata.prio = 4;
      }
    } else if (scdata.idata == '>') {
      // '>'
      scdata.prio = 4;
    } else if (scdata.idata == '+') {
      // '+'
      scdata.prio = 2;
    } else if (scdata.idata == '-') {
      // '-'
      scdata.prio = 2;
    } else if (scdata.idata == '*') {
      // '*'
      scdata.prio = 1;
    } else if (scdata.idata == '/') {
      // '/'
      scdata.prio = 1;
    } else if (scdata.idata == '%') {
      // '%'
      scdata.prio = 1;
    } else if (scdata.idata == ']') {
      pcmd = scdata.asmcmd;
      scanasm(scdata, SA_NAME);
      if (scdata.scan != SCAN_SYMB || scdata.idata != '[') {
        scdata.idata = ']';
        scdata.asmcmd = pcmd;
        scdata.prio = 0;
      } else {
        // Translate '][' to '+'
        scdata.idata = '+';
        scdata.prio = 2;
      }
    } else {
      // Any other character
      scdata.prio = 0;
    }
    scdata.scan = SCAN_SYMB;
    return;
  }
}

// Fetches one complete operand from the input line and fills in structure op
// with operand's data. Expects that first token of the operand is already
// scanned. Supports operands in generalized form (for example, R32 means any
// of general-purpose 32-bit integer registers).
private void Parseasmoperand (ref AsmScanData scdata, ref AsmOperand op) {
  int i, j, bracket, sign, xlataddr;
  int reg;
  int[9] r;
  int offset;
  if (scdata.scan == SCAN_EOL || scdata.scan == SCAN_ERR) return; // No or bad operand
  // Jump or call address may begin with address size modifier(s) SHORT, LONG,
  // NEAR and/or FAR. Not all combinations are allowed. After operand is
  // completely parsed, this function roughly checks whether modifier is
  // allowed. Exact check is done in Assemble().
  if (scdata.scan == SCAN_JMPSIZE) {
    j = 0;
    while (scdata.scan == SCAN_JMPSIZE) {
      // Fetch all size modifiers
      j |= scdata.idata;
      scanasm(scdata, 0);
    }
    if (((j&0x03) == 0x03) || // Mixed SHORT and LONG
        ((j&0x0C) == 0x0C) || // Mixed NEAR and FAR
        ((j&0x09) == 0x09))   // Mixed FAR and SHORT
    {
      scdata.asmerror = "Invalid combination of jump address modifiers";
      scdata.scan = SCAN_ERR;
      return;
    }
    if ((j&0x08) == 0) j |= 0x04; // Force NEAR if not FAR
    op.jmpmode = j;
  }
  // Simple operands are either register or constant, their processing is
  // obvious and straightforward.
  if (scdata.scan == SCAN_REG8 || scdata.scan == SCAN_REG16 || scdata.scan == SCAN_REG32) {
    // Integer general-purpose register
    op.type = REG;
    op.index = scdata.idata;
         if (scdata.scan == SCAN_REG8) op.size = 1;
    else if (scdata.scan == SCAN_REG16) op.size = 2;
    else op.size = 4;
  } else if (scdata.scan == SCAN_FPU) {
    // FPU register
    op.type = RST;
    op.index = scdata.idata;
  } else if (scdata.scan == SCAN_MMX) {
    // MMX or 3DNow! register
    op.type = RMX;
    op.index = scdata.idata;
  } else if (scdata.scan == SCAN_CR) {
    // Control register
    op.type = CRX;
    op.index = scdata.idata;
  } else if (scdata.scan == SCAN_DR) {
    // Debug register
    op.type = DRX;
    op.index = scdata.idata;
  } else if (scdata.scan == SCAN_SYMB && scdata.idata == '-') {
    // Negative constant
    scanasm(scdata, 0);
    if (scdata.scan != SCAN_ICONST && scdata.scan != SCAN_DCONST && scdata.scan != SCAN_OFS) {
      scdata.asmerror = "Integer number expected";
      scdata.scan = SCAN_ERR;
      return;
    }
    op.type = IMM;
    op.offset = -scdata.idata;
    if (scdata.scan == SCAN_OFS) op.anyoffset = 1;
  } else if (scdata.scan == SCAN_SYMB && scdata.idata == '+') {
    // Positive constant
    scanasm(scdata, 0);
    if (scdata.scan != SCAN_ICONST && scdata.scan != SCAN_DCONST && scdata.scan != SCAN_OFS) {
      scdata.asmerror = "Integer number expected";
      scdata.scan = SCAN_ERR;
      return;
    }
    op.type = IMM;
    op.offset = scdata.idata;
    if (scdata.scan == SCAN_OFS) op.anyoffset = 1;
  } else if (scdata.scan == SCAN_ICONST || scdata.scan == SCAN_DCONST || scdata.scan == SCAN_OFS) {
    j = scdata.idata;
    if (scdata.scan == SCAN_OFS) op.anyoffset = 1;
    scanasm(scdata, 0);
    if (scdata.scan == SCAN_SYMB && scdata.idata == ':') {
      // Absolute long address (seg:offset)
      scanasm(scdata, 0);
      if (scdata.scan != SCAN_ICONST && scdata.scan != SCAN_DCONST && scdata.scan != SCAN_OFS) {
        scdata.asmerror = "Integer address expected";
        scdata.scan = SCAN_ERR;
        return;
      }
      op.type = JMF;
      op.offset = scdata.idata;
      op.segment = j;
      if (scdata.scan == SCAN_OFS) op.anyoffset = 1;
    } else {
      // Constant without sign
      op.type = IMM;
      op.offset = j;
      return; // Next token already scanned
    }
  } else if (scdata.scan == SCAN_FCONST) {
    scdata.asmerror = "Floating-point numbers are not allowed in command";
    scdata.scan = SCAN_ERR;
    return;
  } else if (scdata.scan == SCAN_SEG || scdata.scan == SCAN_OPSIZE || (scdata.scan == SCAN_SYMB && scdata.idata == '[')) {
    // Segment register or address
    bracket = 0;
    if (scdata.scan == SCAN_SEG) {
      j = scdata.idata; scanasm(scdata, 0);
      if (scdata.scan != SCAN_SYMB || scdata.idata != ':') {
        // Segment register as operand
        op.type = SGM;
        op.index = j;
        return; // Next token already scanned
      }
      op.segment = j;
      scanasm(scdata, 0);
    }
    // Scan 32-bit address. This parser does not support 16-bit addresses.
    // First of all, get size of operand (optional), segment register (optional)
    // and opening bracket (required).
    for (;;) {
      if (scdata.scan == SCAN_SYMB && scdata.idata == '[') {
        // Bracket
        if (bracket) { scdata.asmerror = "Only one opening bracket allowed"; scdata.scan = SCAN_ERR; return; }
        bracket = 1;
      } else if (scdata.scan == SCAN_OPSIZE) {
        // Size of operand
        if (op.size != 0) { scdata.asmerror = "Duplicated size modifier"; scdata.scan = SCAN_ERR; return; }
        op.size = scdata.idata;
      } else if (scdata.scan == SCAN_SEG) {
        // Segment register
        if (op.segment != SEG_UNDEF) { scdata.asmerror = "Duplicated segment register"; scdata.scan = SCAN_ERR; return; }
        op.segment = scdata.idata; scanasm(scdata, 0);
        if (scdata.scan != SCAN_SYMB || scdata.idata != ':') { scdata.asmerror = "Semicolon expected"; scdata.scan = SCAN_ERR; return; }
      } else if (scdata.scan == SCAN_ERR) {
        return;
      } else {
        // None of expected address elements
        break;
      }
      scanasm(scdata, 0);
    }
    if (bracket == 0) { scdata.asmerror = "Address expression requires brackets"; scdata.scan = SCAN_ERR; return; }
    // Assembling a 32-bit address may be a kind of nigthmare, due to a large
    // number of allowed forms. Parser collects immediate offset in op.offset
    // and count for each register in array r[]. Then it decides whether this
    // combination is valid and determines scale, index and base. Assemble()
    // will use these numbers to select address form (with or without SIB byte,
    // 8- or 32-bit offset, use segment prefix or not). As a useful side effect
    // of this technique, one may specify, for example, [EAX*5] which will
    // correctly assemble to [EAX*4+EAX].
    //for (i = 0; i <= 8; ++i) r[i] = 0;
    r[] = 0;
    sign = '+'; // Default sign for the first operand
    xlataddr = 0;
    // Get SIB and offset
    for (;;) {
      if (scdata.scan == SCAN_SYMB && (scdata.idata == '+' || scdata.idata == '-')) { sign = scdata.idata; scanasm(scdata, 0); }
      if (scdata.scan == SCAN_ERR) return;
      if (sign == '?') { scdata.asmerror = "Syntax error"; scdata.scan = SCAN_ERR; return; }
      // Register AL appears as part of operand of (seldom used) command XLAT.
      if (scdata.scan == SCAN_REG8 && scdata.idata == REG_EAX) {
        if (sign == '-') { scdata.asmerror = "Unable to subtract register"; scdata.scan = SCAN_ERR; return; }
        if (xlataddr != 0) { scdata.asmerror = "Too many registers"; scdata.scan = SCAN_ERR; return; }
        xlataddr = 1;
        scanasm(scdata, 0);
      } else if (scdata.scan == SCAN_REG16) {
        scdata.asmerror = "Sorry, 16-bit addressing is not supported";
        scdata.scan = SCAN_ERR;
        return;
      } else if (scdata.scan == SCAN_REG32) {
        if (sign == '-') { scdata.asmerror = "Unable to subtract register"; scdata.scan = SCAN_ERR; return; }
        reg = scdata.idata; scanasm(scdata, 0);
        if (scdata.scan == SCAN_SYMB && scdata.idata == '*') {
          // Try index*scale
          scanasm(scdata, 0);
          if (scdata.scan == SCAN_ERR) return;
          if (scdata.scan == SCAN_OFS) { scdata.asmerror = "Undefined scale is not allowed"; scdata.scan = SCAN_ERR; return; }
          if (scdata.scan != SCAN_ICONST && scdata.scan != SCAN_DCONST) { scdata.asmerror = "Syntax error"; scdata.scan = SCAN_ERR; return; }
          if (scdata.idata == 6 || scdata.idata == 7 || scdata.idata > 9) { scdata.asmerror = "Invalid scale"; scdata.scan = SCAN_ERR; return; }
          r[reg] += scdata.idata;
          scanasm(scdata, 0);
        } else {
          // Simple register
          ++r[reg];
        }
      } else if (scdata.scan == SCAN_LOCAL) {
        ++r[REG_EBP];
        op.offset -= scdata.idata*4;
        scanasm(scdata, 0);
      } else if (scdata.scan == SCAN_ARG) {
        ++r[REG_EBP];
        op.offset += (scdata.idata+1)*4;
        scanasm(scdata, 0);
      } else if (scdata.scan == SCAN_ICONST || scdata.scan == SCAN_DCONST) {
        offset = scdata.idata;
        scanasm(scdata, 0);
        if (scdata.scan == SCAN_SYMB && scdata.idata == '*') {
          // Try scale*index
          scanasm(scdata, 0);
          if (scdata.scan == SCAN_ERR) return;
          if (sign == '-') { scdata.asmerror = "Unable to subtract register"; scdata.scan = SCAN_ERR; return; }
          if (scdata.scan == SCAN_REG16) { scdata.asmerror = "Sorry, 16-bit addressing is not supported"; scdata.scan = SCAN_ERR; return; }
          if (scdata.scan != SCAN_REG32) { scdata.asmerror = "Syntax error"; scdata.scan = SCAN_ERR; return; }
          if (offset == 6 || offset == 7 || offset > 9) { scdata.asmerror = "Invalid scale"; scdata.scan = SCAN_ERR; return; }
          r[scdata.idata] += offset;
          scanasm(scdata, 0);
        } else {
          if (sign == '-') op.offset -= offset; else op.offset += offset;
        }
      } else if (scdata.scan == SCAN_OFS) {
        scanasm(scdata, 0);
        if (scdata.scan == SCAN_SYMB && scdata.idata == '*') { scdata.asmerror = "Undefined scale is not allowed"; scdata.scan = SCAN_ERR; return; }
        op.anyoffset = 1;
      } else {
        // None of expected address elements
        break;
      }
      if (scdata.scan == SCAN_SYMB && scdata.idata == ']') break;
      sign = '?';
    }
    if (scdata.scan == SCAN_ERR) return;
    if (scdata.scan != SCAN_SYMB || scdata.idata != ']') { scdata.asmerror = "Syntax error"; scdata.scan = SCAN_ERR; return; }
    // Process XLAT address separately.
    if (xlataddr != 0) {
      // XLAT address in form [EBX+AX]
      // Check which registers used
      for (i = 0; i <= 8; ++i) {
        if (i == REG_EBX) continue;
        if (r[i] != 0) break;
      }
      if (i <= 8 || r[REG_EBX] != 1 || op.offset != 0 || op.anyoffset != 0) { scdata.asmerror = "Invalid address"; scdata.scan = SCAN_ERR; return; }
      op.type = MXL;
    } else {
      // Determine scale, index and base.
      j = 0; // Number of used registers
      for (i = 0; i <= 8; ++i) {
        if (r[i] == 0) continue; // Unused register
        if (r[i] == 3 || r[i] == 5 || r[i] == 9) {
          if (op.index >= 0 || op.base >= 0) { scdata.asmerror = (j == 0 ? "Invalid scale" : "Too many registers"); scdata.scan = SCAN_ERR; return; }
          op.index = op.base = i;
          op.scale = r[i]-1;
        } else if (r[i] == 2 || r[i] == 4 || r[i] == 8) {
          if (op.index >= 0) { scdata.asmerror = (j <= 1 ? "Only one register may be scaled" : "Too many registers"); scdata.scan = SCAN_ERR; return; }
          op.index = i;
          op.scale = r[i];
        } else if (r[i] == 1) {
               if (op.base < 0) op.base = i;
          else if (op.index < 0) { op.index = i; op.scale = 1; }
          else { scdata.asmerror = "Too many registers"; scdata.scan = SCAN_ERR; return; }
        } else {
          scdata.asmerror = "Invalid scale";
          scdata.scan = SCAN_ERR;
          return;
        }
        ++j;
      }
      op.type = MRG;
    }
  } else {
    scdata.asmerror = "Unrecognized operand";
    scdata.scan = SCAN_ERR;
    return;
  }
  // In general, address modifier is allowed only with address expression which
  // is a constant, a far address or a memory expression. More precise check
  // will be done later in Assemble().
  if (op.jmpmode != 0 && op.type != IMM && op.type != JMF && op.type != MRG) {
    scdata.asmerror = "Jump address modifier is not allowed";
    scdata.scan = SCAN_ERR;
    return;
  }
  scanasm(scdata, 0); // Fetch next token from input line
}


/** Parse and assemble x86 instruction.
 *
 * This function assembles text into 32-bit 80x86 machine code. It supports imprecise
 * operands (for example, R32 stays for any general-purpose 32-bit register).
 * This allows to search for incomplete commands. Command is precise when all
 * significant bytes in model.mask are 0xFF. Some commands have more than one
 * decoding. By calling Assemble() with attempt=0, 1... and constsize=0, 1, 2, 3
 * one gets also alternative variants (bit 0x1 of constsize is responsible for
 * size of address constant and bit 0x2 - for immediate data). However, only one
 * address form is generated ([EAX*2], but not [EAX+EAX]; [EBX+EAX] but not
 * [EAX+EBX]; [EAX] will not use SIB byte; no DS: prefix and so on).
 *
 * Returns number of bytes in assembled code or non-positive number in case of
 * detected error. This number is the negation of the offset in the input text
 * where the error encountered.
 */
public int assemble(const(char)[] cmdstr, uint ip, AsmModel* model, in AsmOptions opts, uint attempt, uint constsize, char[] errtext) {
  import core.stdc.stdio : snprintf;
  import core.stdc.string : memcpy, memset, strcpy, strcmp, strlen;
  int i, j, k, namelen, nameok, arg, match, datasize, addrsize, bytesize, minop, maxop;
  int rep, lock, segment, jmpsize, jmpmode, longjump;
  int hasrm, hassib, dispsize, immsize;
  int anydisp, anyimm, anyjmp;
  int l, displacement, immediate, jmpoffset;
  char[32] name = 0;
  const(char)* nameend;
  ubyte[ASMMAXCMDSIZE] tcode;
  ubyte[ASMMAXCMDSIZE] tmask;
  AsmOperand[3] aop; // Up to 3 operands allowed
  AsmOperand* op;
  immutable(AsmInstrData)* pd;
  AsmScanData scdata;

  if (model !is null) model.length = 0;
  if (model is null || cmdstr.length > scdata.acommand.length-1) {
    // Error in parameters
    if (errtext !is null) xstrcpy(errtext, "Internal OLLYASM error");
    return 0;
  }
  scdata.acommand[] = 0;
  scdata.acommand[0..cmdstr.length] = cmdstr;
  scdata.asmcmd = scdata.acommand.ptr;
  rep = lock = 0;
  errtext[0] = '\0';
  scanasm(scdata, SA_NAME);
  if (scdata.scan == SCAN_EOL) return 0; // End of line, nothing to assemble
  // Fetch all REPxx and LOCK prefixes
  for (;;) {
    if (scdata.scan == SCAN_REP || scdata.scan == SCAN_REPE || scdata.scan == SCAN_REPNE) {
      if (rep != 0) { xstrcpy(errtext, "Duplicated REP prefix"); goto error; }
      rep = scdata.scan;
    } else if (scdata.scan == SCAN_LOCK) {
      if (lock != 0) { xstrcpy(errtext, "Duplicated LOCK prefix"); goto error; }
      lock = scdata.scan;
    } else {
      // No more prefixes
      break;
    }
    scanasm(scdata, SA_NAME);
  }
  if (scdata.scan != SCAN_NAME || scdata.idata > 16) { xstrcpy(errtext, "Command mnemonic expected"); goto error; }
  nameend = scdata.asmcmd;
  strupr(scdata.sdata.ptr);
  // Prepare full mnemonic (including repeat prefix, if any).
       if (rep == SCAN_REP) snprintf(name.ptr, name.length, "REP %s", scdata.sdata.ptr);
  else if (rep == SCAN_REPE) snprintf(name.ptr, name.length, "REPE %s", scdata.sdata.ptr);
  else if (rep == SCAN_REPNE) snprintf(name.ptr, name.length, "REPNE %s", scdata.sdata.ptr);
  else strcpy(name.ptr, scdata.sdata.ptr);
  scanasm(scdata, 0);
  // Parse command operands (up to 3). Note: jump address is always the first
  // (and only) operand in actual command set.
  for (i = 0; i < 3; ++i) {
    aop[i].type = NNN;          // No operand
    aop[i].size = 0;            // Undefined size
    aop[i].index = -1;          // No index
    aop[i].scale = 0;           // No scale
    aop[i].base = -1;           // No base
    aop[i].offset = 0;          // No offset
    aop[i].anyoffset = 0;       // No offset
    aop[i].segment = SEG_UNDEF; // No segment
    aop[i].jmpmode = 0;         // No jump size modifier
  }
  Parseasmoperand(scdata, aop[0]);
  jmpmode = aop[0].jmpmode;
  if (jmpmode != 0) jmpmode |= 0x80;
  if (scdata.scan == SCAN_SYMB && scdata.idata == ',') {
    scanasm(scdata, 0);
    Parseasmoperand(scdata, aop[1]);
    if (scdata.scan == SCAN_SYMB && scdata.idata == ',') {
      scanasm(scdata, 0);
      Parseasmoperand(scdata, aop[2]);
    }
  }
  if (scdata.scan == SCAN_ERR) { xstrcpyx(errtext, scdata.asmerror); goto error; }
  if (scdata.scan != SCAN_EOL) { xstrcpy(errtext, "Extra input after operand"); goto error; }
  // If jump size is not specified, function tries to use short jump. If
  // attempt fails, it retries with long form.
  longjump = 0; // Try short jump on the first pass
retrylongjump:
  nameok = 0;
  // Some commands allow different number of operands. Variables minop and
  // maxop accumulate their minimal and maximal counts. The numbers are not
  // used in assembly process but allow for better error diagnostics.
  minop = 3;
  maxop = 0;
  // Main assembly loop: try to find the command which matches all operands,
  // but do not process operands yet.
  namelen = strlen(name.ptr);
  foreach (const ref cdx; asmInstrs) {
    pd = &cdx;
    if (pd.name[0] == '&') {
      // Mnemonic depends on operand size
      j = 1;
      datasize = 2;
      addrsize = 4;
      // Try all mnemonics (separated by ':')
      for (;;) {
        for (i = 0; pd.name[j] != '\0' && pd.name[j] != ':'; ++j) {
          if (pd.name[j] == '*') {
                 if (name[i] == 'W') { datasize = 2; ++i; }
            else if (name[i] == 'D') { datasize = 4; ++i; }
            else if (opts.sizesens == 0) datasize = 2;
            else datasize = 4;
          } else if (pd.name[j] == name[i]) {
            ++i;
          } else {
            break;
          }
        }
        if (name[i] == '\0' && (pd.name[j] == '\0' || pd.name[j] == ':')) break; // Bingo!
        while (pd.name[j] != '\0' && pd.name[j] != ':') ++j;
        if (pd.name[j] == ':') {
          // Retry with 32-bit mnenonic
          ++j;
          datasize = 4;
        } else {
          // Comparison failed
          i = 0;
          break;
        }
      }
      if (i == 0) continue;
    } else if (pd.name[0] == '$') {
      // Mnemonic depends on address size
      j = 1;
      datasize = 0;
      addrsize = 2;
      // Try all mnemonics (separated by ':')
      for (;;) {
        for (i = 0; pd.name[j] != '\0' && pd.name[j] != ':'; ++j) {
          if (pd.name[j] == '*') {
                 if (name[i] == 'W') { addrsize = 2; ++i; }
            else if (name[i] == 'D') { addrsize = 4; ++i; }
            else if (opts.sizesens == 0) addrsize = 2;
            else addrsize = 4;
          } else if (pd.name[j] == name[i]) {
            ++i;
          } else {
            break;
          }
        }
        if (name[i] == '\0' && (pd.name[j] == '\0' || pd.name[j] == ':')) break; // Bingo!
        while (pd.name[j] != '\0' && pd.name[j] != ':') ++j;
        if (pd.name[j] == ':') {
          // Retry with 32-bit mnenonic
          ++j;
          addrsize = 4;
        } else {
          // Comparison failed
          i = 0;
          break;
        }
      }
      if (i == 0) continue;
    } else {
      // Compare with all synonimes
      j = k = 0;
      datasize = 0; // Default settings
      addrsize = 4;
      for (;;) {
        while (j < pd.name.length && pd.name[j] != ',' && pd.name[j] != '\0') ++j;
        if (j-k == namelen && strnicmp(name.ptr, pd.name.ptr+k, namelen) == 0) break;
        k = j+1;
        if (j >= pd.name.length || pd.name[j] == '\0') break;
        j = k;
      }
      if (k > j) continue;
    }
    // For error diagnostics it is important to know whether mnemonic exists.
    ++nameok;
    if (pd.arg1 == NNN || pd.arg1 >= PSEUDOOP) {
      minop = 0;
    } else if (pd.arg2 == NNN || pd.arg2 >= PSEUDOOP) {
      if (minop > 1) minop = 1;
      if (maxop < 1) maxop = 1;
    } else if (pd.arg3 == NNN || pd.arg3 >= PSEUDOOP) {
      if (minop > 2) minop = 2;
      if (maxop < 2) maxop = 2;
    } else {
      maxop = 3;
    }
    // Determine default and allowed operand size(s).
    if (pd.bits == FF) datasize = 2; // Forced 16-bit size
    bytesize = (pd.bits == WW || pd.bits == WS || pd.bits == W3 || pd.bits == WP ? 1 : 0); // 1-byte size allowed or Word/dword size only
    // Check whether command operands match specified. If so, variable match
    // remains zero, otherwise it contains kind of mismatch. This allows for
    // better error diagnostics.
    match = 0;
    // Up to 3 operands
    for (j = 0; j < 3; ++j) {
      op = aop.ptr+j;
           if (j == 0) arg = pd.arg1;
      else if (j == 1) arg = pd.arg2;
      else arg = pd.arg3;
      if (arg == NNN || arg >= PSEUDOOP) {
        if (op.type != NNN) match |= MA_NOP; // No more arguments
        break;
      }
      if (op.type == NNN) { match |= MA_NOP; break; } // No corresponding operand
      switch (arg) {
        case REG: // Integer register in Reg field
        case RCM: // Integer register in command byte
        case RAC: // Accumulator (AL/AX/EAX, implicit)
          if (op.type != REG) match |= MA_TYP;
          if (arg == RAC && op.index != REG_EAX && op.index != 8) match |= MA_TYP;
          if (bytesize == 0 && op.size == 1) match |= MA_SIZ;
          if (datasize == 0) datasize = op.size;
          if (datasize != op.size) match |= MA_DIF;
          break;
        case RG4: // Integer 4-byte register in Reg field
          if (op.type != REG) match |= MA_TYP;
          if (op.size != 4) match |= MA_SIZ;
          if (datasize == 0) datasize = op.size;
          if (datasize != op.size) match |= MA_DIF;
          break;
        case RAX: // AX (2-byte, implicit)
          if (op.type != REG || (op.index != REG_EAX && op.index != 8)) match |= MA_TYP;
          if (op.size != 2) match |= MA_SIZ;
          if (datasize == 0) datasize = op.size;
          if (datasize != op.size) match |= MA_DIF;
          break;
        case RDX: // DX (16-bit implicit port address)
          if (op.type != REG || (op.index != REG_EDX && op.index != 8)) match |= MA_TYP;
          if (op.size != 2) match |= MA_SIZ; break;
        case RCL: // Implicit CL register (for shifts)
          if (op.type != REG || (op.index != REG_ECX && op.index != 8)) match |= MA_TYP;
          if (op.size != 1) match |= MA_SIZ;
          break;
        case RS0: // Top of FPU stack (ST(0))
          if (op.type != RST || (op.index != 0 && op.index != 8)) match |= MA_TYP;
          break;
        case RST: // FPU register (ST(i)) in command byte
          if (op.type != RST) match |= MA_TYP;
          break;
        case RMX: // MMX register MMx
        case R3D: // 3DNow! register MMx
          if (op.type != RMX) match |= MA_TYP;
          break;
        case MRG:                      // Memory/register in ModRM byte
          if (op.type != MRG && op.type != REG) match |= MA_TYP;
          if (bytesize == 0 && op.size == 1) match |= MA_SIZ;
          if (datasize == 0) datasize = op.size;
          if (op.size != 0 && op.size != datasize) match |= MA_DIF;
          break;
        case MR1: // 1-byte memory/register in ModRM byte
          if (op.type != MRG && op.type != REG) match |= MA_TYP;
          if (op.size != 0 && op.size != 1) match |= MA_SIZ;
          break;
        case MR2: // 2-byte memory/register in ModRM byte
          if (op.type != MRG && op.type != REG) match |= MA_TYP;
          if (op.size != 0 && op.size != 2) match |= MA_SIZ;
          break;
        case MR4: // 4-byte memory/register in ModRM byte
          if (op.type != MRG && op.type != REG) match |= MA_TYP;
          if (op.size != 0 && op.size != 4) match |= MA_SIZ;
          break;
        case RR4: // 4-byte memory/register (register only)
          if (op.type != REG) match |= MA_TYP;
          if (op.size != 0 && op.size != 4) match |= MA_SIZ;
          break;
        case MRJ: // Memory/reg in ModRM as JUMP target
          if (op.type != MRG && op.type != REG) match |= MA_TYP;
          if (op.size != 0 && op.size != 4) match |= MA_SIZ;
          if ((jmpmode&0x09) != 0) match |= MA_JMP;
          jmpmode &= 0x7F;
          break;
        case MR8: // 8-byte memory/MMX register in ModRM
        case MRD: // 8-byte memory/3DNow! register in ModRM
          if (op.type != MRG && op.type != RMX) match |= MA_TYP;
          if (op.size != 0 && op.size != 8) match |= MA_SIZ;
          break;
        case RR8: // 8-byte MMX register only in ModRM
        case RRD: // 8-byte memory/3DNow! (register only)
          if (op.type != RMX) match |= MA_TYP;
          if (op.size != 0 && op.size != 8) match |= MA_SIZ;
          break;
        case MMA: // Memory address in ModRM byte for LEA
          if (op.type != MRG) match |= MA_TYP; break;
        case MML: // Memory in ModRM byte (for LES)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 6) match |= MA_SIZ;
          if (datasize == 0) datasize = 4; else if (datasize != 4) match |= MA_DIF;
          break;
        case MMS: // Memory in ModRM byte (as SEG:OFFS)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 6) match |= MA_SIZ;
          if ((jmpmode&0x07) != 0) match |= MA_JMP;
          jmpmode &= 0x7F;
          break;
        case MM6: // Memory in ModRm (6-byte descriptor)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 6) match |= MA_SIZ;
          break;
        case MMB: // Two adjacent memory locations (BOUND)
          if (op.type != MRG) match |= MA_TYP;
          k = op.size; if (opts.ideal == 0 && k > 1) k /= 2;
          if (k != 0 && k != datasize) match |= MA_DIF;
          break;
        case MD2: // Memory in ModRM byte (16-bit integer)
        case MB2: // Memory in ModRM byte (16-bit binary)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 2) match |= MA_SIZ;
          break;
        case MD4: // Memory in ModRM byte (32-bit integer)
        case MF4: // Memory in ModRM byte (32-bit float)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 4) match |= MA_SIZ;
          break;
        case MD8: // Memory in ModRM byte (64-bit integer)
        case MF8: // Memory in ModRM byte (64-bit float)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 8) match |= MA_SIZ;
          break;
        case MDA: // Memory in ModRM byte (80-bit BCD)
        case MFA: // Memory in ModRM byte (80-bit float)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0 && op.size != 10) match |= MA_SIZ;
          break;
        case MFE: // Memory in ModRM byte (FPU environment)
        case MFS: // Memory in ModRM byte (FPU state)
        case MFX: // Memory in ModRM byte (ext. FPU state)
          if (op.type != MRG) match |= MA_TYP;
          if (op.size != 0) match |= MA_SIZ;
          break;
        case MSO: // Source in string operands ([ESI])
          if (op.type != MRG || op.base != REG_ESI || op.index != -1 || op.offset != 0 || op.anyoffset != 0) match |= MA_TYP;
          if (datasize == 0) datasize = op.size;
          if (op.size != 0 && op.size != datasize) match |= MA_DIF;
          break;
        case MDE: // Destination in string operands ([EDI])
          if (op.type != MRG || op.base != REG_EDI || op.index != -1 || op.offset != 0 || op.anyoffset != 0) match |= MA_TYP;
          if (op.segment != SEG_UNDEF && op.segment != SEG_ES) match |= MA_SEG;
          if (datasize == 0) datasize = op.size;
          if (op.size != 0 && op.size != datasize) match |= MA_DIF;
          break;
        case MXL: // XLAT operand ([EBX+AL])
          if (op.type != MXL) match |= MA_TYP;
          break;
        case IMM: // Immediate data (8 or 16/32)
        case IMU: // Immediate unsigned data (8 or 16/32)
          if (op.type != IMM) match |= MA_TYP;
          break;
        case VXD:                      // VxD service (32-bit only)
          if (op.type != IMM) match |= MA_TYP;
          if (datasize == 0) datasize = 4;
          if (datasize != 4) match |= MA_SIZ;
          break;
        case JMF:                      // Immediate absolute far jump/call addr
          if (op.type != JMF) match |= MA_TYP;
          if ((jmpmode&0x05) != 0) match |= MA_JMP;
          jmpmode &= 0x7F;
          break;
        case JOB: // Immediate byte offset (for jumps)
          if (op.type != IMM || longjump) match |= MA_TYP;
          if ((jmpmode&0x0A) != 0) match |= MA_JMP;
          jmpmode &= 0x7F;
          break;
        case JOW: // Immediate full offset (for jumps)
          if (op.type != IMM) match |= MA_TYP;
          if ((jmpmode&0x09) != 0) match |= MA_JMP;
          jmpmode &= 0x7F;
          break;
        case IMA: // Immediate absolute near data address
          if (op.type != MRG || op.base >= 0 || op.index >= 0) match |= MA_TYP;
          break;
        case IMX: // Immediate sign-extendable byte
          if (op.type != IMM) match |= MA_TYP;
          if (op.offset < -128 || op.offset > 127) match |= MA_RNG;
          break;
        case C01: // Implicit constant 1 (for shifts)
          if (op.type != IMM || (op.offset != 1 && op.anyoffset == 0)) match |= MA_TYP;
          break;
        case IMS: // Immediate byte (for shifts)
        case IM1: // Immediate byte
          if (op.type != IMM) match |= MA_TYP;
          if (op.offset < -128 || op.offset > 255) match |= MA_RNG;
          break;
        case IM2: // Immediate word (ENTER/RET)
          if (op.type != IMM) match |= MA_TYP;
          if (op.offset < 0 || op.offset > 65535) match |= MA_RNG;
          break;
        case SGM: // Segment register in ModRM byte
          if (op.type != SGM) match |= MA_TYP;
          if (datasize == 0) datasize = 2;
          if (datasize != 2) match |= MA_DIF;
          break;
        case SCM: // Segment register in command byte
          if (op.type != SGM) match |= MA_TYP;
          break;
        case CRX: // Control register CRx
        case DRX: // Debug register DRx
          if (op.type != arg) match |= MA_TYP;
          if (datasize == 0) datasize = 4;
          if (datasize != 4) match |= MA_DIF;
          break;
        case PRN: // Near return address (pseudooperand)
        case PRF: // Far return address (pseudooperand)
        case PAC: // Accumulator (AL/AX/EAX, pseudooperand)
        case PAH: // AH (in LAHF/SAHF, pseudooperand)
        case PFL: // Lower byte of flags (pseudooperand)
        case PS0: // Top of FPU stack (pseudooperand)
        case PS1: // ST(1) (pseudooperand)
        case PCX: // CX/ECX (pseudooperand)
        case PDI: // EDI (pseudooperand in MMX extentions)
          break;
        default: // Undefined type of operand
          xstrcpy(errtext, "Internal Assembler error");
          goto error;
      } // End of switch (arg)
      if ((jmpmode&0x80) != 0) match |= MA_JMP;
      if (match != 0) break; // Some of the operands doesn't match
    } // End of operand matching loop
    if (match == 0) {
      // Exact match found
      if (attempt > 0) {
        // Well, try to find yet another match
        --attempt;
        nameok = 0;
      } else {
        break;
      }
    }
  } // End of command search loop
  // Check whether some error was detected. If several errors were found
  // similtaneously, report one (roughly in order of significance).
  if (nameok == 0) { xstrcpy(errtext, "Unrecognized command"); scdata.asmcmd = nameend; goto error; } // Mnemonic unavailable
  if (match != 0) {
    // Command not found
         if (minop > 0 && aop[minop-1].type == NNN) xstrcpy(errtext, "Too few operands");
    else if (maxop < 3 && aop[maxop].type != NNN) xstrcpy(errtext, "Too many operands");
    else if (nameok > 1) xstrcpy(errtext, "Command does not support given operands"); // More that 1 command
    else if (match&MA_JMP) xstrcpy(errtext, "Invalid jump size modifier");
    else if (match&MA_NOP) xstrcpy(errtext, "Wrong number of operands");
    else if (match&MA_TYP) xstrcpy(errtext, "Command does not support given operands");
    else if (match&MA_NOS) xstrcpy(errtext, "Please specify operand size");
    else if (match&MA_SIZ) xstrcpy(errtext, "Bad operand size");
    else if (match&MA_DIF) xstrcpy(errtext, "Different size of operands");
    else if (match&MA_SEG) xstrcpy(errtext, "Invalid segment register");
    else if (match&MA_RNG) xstrcpy(errtext, "Constant out of expected range");
    else xstrcpy(errtext, "Erroneous command");
    goto error;
  }
  // Exact match found. Now construct the code.
  hasrm = 0;           // Whether command has ModR/M byte
  hassib = 0;          // Whether command has SIB byte
  dispsize = 0;        // Size of displacement (if any)
  immsize = 0;         // Size of immediate data (if any)
  segment = SEG_UNDEF; // Necessary segment prefix
  jmpsize = 0;         // No relative jumps
  memset(tcode.ptr, 0, tcode.sizeof);
  *cast(uint*)tcode.ptr = pd.code&pd.mask;
  memset(tmask.ptr, 0, tmask.sizeof);
  *cast(uint*)tmask.ptr = pd.mask;
  i = pd.len-1; // Last byte of command itself
  if (rep) ++i; // REPxx prefixes count as extra byte
  // In some cases at least one operand must have explicit size declaration (as
  // in MOV [EAX], 1). This preliminary check does not include all cases.
  if (pd.bits == WW || pd.bits == WS || pd.bits == WP) {
    if (datasize == 0) { xstrcpy(errtext, "Please specify operand size"); goto error; }
    if (datasize > 1) tcode[i] |= 0x01; // WORD or DWORD size of operands
    tmask[i] |= 0x01;
  } else if (pd.bits == W3) {
    if (datasize == 0) { xstrcpy(errtext, "Please specify operand size"); goto error; }
    if (datasize > 1) tcode[i] |= 0x08; // WORD or DWORD size of operands
    tmask[i] |= 0x08;
  }
  // Present suffix of 3DNow! command as immediate byte operand.
  if ((pd.type&C_TYPEMASK) == C_NOW) {
    immsize = 1;
    immediate = (pd.code>>16)&0xFF;
  }
  // Process operands again, this time constructing the code.
  anydisp = anyimm = anyjmp = 0;
  // Up to 3 operands
  for (j = 0; j < 3; ++j) {
    op = aop.ptr+j;
         if (j == 0) arg = pd.arg1;
    else if (j == 1) arg = pd.arg2;
    else arg = pd.arg3;
    if (arg == NNN) break; // All operands processed
    switch (arg) {
      case REG: // Integer register in Reg field
      case RG4: // Integer 4-byte register in Reg field
      case RMX: // MMX register MMx
      case R3D: // 3DNow! register MMx
      case CRX: // Control register CRx
      case DRX: // Debug register DRx
        hasrm = 1;
        if (op.index < 8) { tcode[i+1] |= cast(ubyte)(op.index<<3); tmask[i+1] |= 0x38; }
        break;
      case RCM: // Integer register in command byte
      case RST: // FPU register (ST(i)) in command byte
        if (op.index < 8) { tcode[i] |= cast(ubyte)op.index; tmask[i] |= 0x07; }
        break;
      case RAC: // Accumulator (AL/AX/EAX, implicit)
      case RAX: // AX (2-byte, implicit)
      case RDX: // DX (16-bit implicit port address)
      case RCL: // Implicit CL register (for shifts)
      case RS0: // Top of FPU stack (ST(0))
      case MDE: // Destination in string op's ([EDI])
      case C01: // Implicit constant 1 (for shifts)
        break; // Simply skip implicit operands
      case MSO: // Source in string op's ([ESI])
      case MXL: // XLAT operand ([EBX+AL])
        if (op.segment != SEG_UNDEF && op.segment != SEG_DS) segment = op.segment;
        break;
      case MRG: // Memory/register in ModRM byte
      case MRJ: // Memory/reg in ModRM as JUMP target
      case MR1: // 1-byte memory/register in ModRM byte
      case MR2: // 2-byte memory/register in ModRM byte
      case MR4: // 4-byte memory/register in ModRM byte
      case RR4: // 4-byte memory/register (register only)
      case MR8: // 8-byte memory/MMX register in ModRM
      case RR8: // 8-byte MMX register only in ModRM
      case MRD: // 8-byte memory/3DNow! register in ModRM
      case RRD: // 8-byte memory/3DNow! (register only)
        hasrm = 1;
        if (op.type != MRG) {
          // Register in ModRM byte
          tcode[i+1] |= 0xC0; tmask[i+1] |= 0xC0;
          if (op.index < 8) { tcode[i+1] |= cast(ubyte)op.index; tmask[i+1] |= 0x07; }
          break;
        }
        // Note: NO BREAK, continue with address
        goto case;
      case MMA: // Memory address in ModRM byte for LEA
      case MML: // Memory in ModRM byte (for LES)
      case MMS: // Memory in ModRM byte (as SEG:OFFS)
      case MM6: // Memory in ModRm (6-byte descriptor)
      case MMB: // Two adjacent memory locations (BOUND)
      case MD2: // Memory in ModRM byte (16-bit integer)
      case MB2: // Memory in ModRM byte (16-bit binary)
      case MD4: // Memory in ModRM byte (32-bit integer)
      case MD8: // Memory in ModRM byte (64-bit integer)
      case MDA: // Memory in ModRM byte (80-bit BCD)
      case MF4: // Memory in ModRM byte (32-bit float)
      case MF8: // Memory in ModRM byte (64-bit float)
      case MFA: // Memory in ModRM byte (80-bit float)
      case MFE: // Memory in ModRM byte (FPU environment)
      case MFS: // Memory in ModRM byte (FPU state)
      case MFX: // Memory in ModRM byte (ext. FPU state)
        hasrm = 1; displacement = op.offset; anydisp = op.anyoffset;
        if (op.base < 0 && op.index < 0) {
          dispsize = 4; // Special case of immediate address
          if (op.segment != SEG_UNDEF && op.segment != SEG_DS) segment = op.segment;
          tcode[i+1] |= 0x05;
          tmask[i+1] |= 0xC7;
        } else if (op.index < 0 && op.base != REG_ESP) {
          tmask[i+1] |= 0xC0; // SIB byte unnecessary
          if (op.offset == 0 && op.anyoffset == 0 && op.base != REG_EBP) {
            // [EBP] always requires offset
          } else if ((constsize&1) != 0 && ((op.offset >= -128 && op.offset < 128) || op.anyoffset != 0)) {
            tcode[i+1] |= 0x40; // Disp8
            dispsize = 1;
          } else {
            tcode[i+1] |= 0x80; // Disp32
            dispsize = 4;
          }
          if (op.base < 8) {
            if (op.segment != SEG_UNDEF && op.segment != addr32[op.base].defseg) segment = op.segment;
            tcode[i+1] |= cast(ubyte)op.base; // Note that case [ESP] has base<0.
            tmask[i+1] |= 0x07;
          } else {
            segment = op.segment;
          }
        } else {
          // SIB byte necessary
          hassib = 1;
          // EBP as base requires offset? optimize
          if (op.base == REG_EBP && op.index >= 0 && op.scale == 1 && op.offset == 0 && op.anyoffset == 0) { op.base = op.index; op.index = REG_EBP; }
          // ESP cannot be an index, reorder
          if (op.index == REG_ESP && op.scale <= 1) { op.index = op.base; op.base = REG_ESP; op.scale = 1; }
          // No base means 4-byte offset, optimize
          if (op.base < 0 && op.index >= 0 && op.scale == 2 && op.offset >= -128 && op.offset < 128 && op.anyoffset == 0) { op.base = op.index; op.scale = 1; }
          if (op.index == REG_ESP) { xstrcpy(errtext, "Invalid indexing mode"); goto error; } // Reordering was unsuccessfull
               if (op.base < 0) { tcode[i+1] |= 0x04; dispsize = 4; }
          else if (op.offset == 0 && op.anyoffset == 0 && op.base != REG_EBP) tcode[i+1] |= 0x04; // No displacement
          else if ((constsize&1) != 0 && ((op.offset >= -128 && op.offset < 128) || op.anyoffset != 0)) { tcode[i+1] |= 0x44; dispsize = 1; } // Disp8
          else { tcode[i+1] |= 0x84; dispsize = 4; } // Disp32
          tmask[i+1] |= 0xC7; // ModRM completed, proceed with SIB
               if (op.scale == 2) tcode[i+2] |= 0x40;
          else if (op.scale == 4) tcode[i+2] |= 0x80;
          else if (op.scale == 8) tcode[i+2] |= 0xC0;
          tmask[i+2] |= 0xC0;
          if (op.index < 8) {
            if (op.index < 0) op.index = 0x04;
            tcode[i+2] |= cast(ubyte)(op.index<<3);
            tmask[i+2] |= 0x38;
          }
          if (op.base < 8) {
            if (op.base < 0) op.base = 0x05;
            if (op.segment != SEG_UNDEF && op.segment != addr32[op.base].defseg) segment = op.segment;
            tcode[i+2] |= cast(ubyte)op.base;
            tmask[i+2] |= 0x07;
          } else {
            segment = op.segment;
          }
        }
        break;
      case IMM: // Immediate data (8 or 16/32)
      case IMU: // Immediate unsigned data (8 or 16/32)
      case VXD: // VxD service (32-bit only)
        if (datasize == 0 && pd.arg2 == NNN && (pd.bits == SS || pd.bits == WS)) datasize = 4;
        if (datasize == 0) { xstrcpy(errtext, "Please specify operand size"); goto error; }
        immediate = op.offset; anyimm = op.anyoffset;
        if (pd.bits == SS || pd.bits == WS) {
          if (datasize > 1 && (constsize&2) != 0 && ((immediate >= -128 && immediate < 128) || op.anyoffset != 0)) { immsize = 1; tcode[i] |= 0x02; } else immsize = datasize;
          tmask[i] |= 0x02;
        } else {
          immsize = datasize;
        }
        break;
      case IMX: // Immediate sign-extendable byte
      case IMS: // Immediate byte (for shifts)
      case IM1: // Immediate byte
        if (immsize == 2) {
          // To accomodate ENTER instruction
          immediate = (immediate&0xFFFF)|(op.offset<<16);
        } else {
          immediate = op.offset;
        }
        anyimm |= op.anyoffset;
        ++immsize;
        break;
      case IM2: // Immediate word (ENTER/RET)
        immediate = op.offset;
        anyimm = op.anyoffset;
        immsize = 2;
        break;
      case IMA: // Immediate absolute near data address
        if (op.segment != SEG_UNDEF && op.segment != SEG_DS) segment = op.segment;
        displacement = op.offset;
        anydisp = op.anyoffset;
        dispsize = 4;
        break;
      case JOB: // Immediate byte offset (for jumps)
        jmpoffset = op.offset;
        anyjmp = op.anyoffset;
        jmpsize = 1;
        break;
      case JOW: // Immediate full offset (for jumps)
        jmpoffset = op.offset;
        anyjmp = op.anyoffset;
        jmpsize = 4;
        break;
      case JMF: // Immediate absolute far jump/call addr
        displacement = op.offset;
        anydisp = op.anyoffset;
        dispsize = 4;
        immediate = op.segment;
        anyimm = op.anyoffset;
        immsize = 2;
        break;
      case SGM: // Segment register in ModRM byte
        hasrm = 1;
        if (op.index < 6) { tcode[i+1] |= cast(ubyte)(op.index<<3); tmask[i+1] |= 0x38; }
        break;
      case SCM: // Segment register in command byte
        if (op.index == SEG_FS || op.index == SEG_GS) {
          tcode[0] = 0x0F;
          tmask[0] = 0xFF;
          i = 1;
          tcode[i] = cast(ubyte)((op.index<<3)|0x80);
          if (strcmp(name.ptr, "PUSH") == 0) tcode[i] |= 0x01;
          /*
          if (strcmp(name.ptr, "PUSH") == 0)
            tcode[i] = cast(ubyte)((op.index<<3)|0x80);
          else
            tcode[i] = cast(ubyte)((op.index<<3)|0x81);
          */
          tmask[i] = 0xFF;
        } else if (op.index < 6) {
          if (op.index == SEG_CS && strcmp(name.ptr, "POP") == 0) { xstrcpy(errtext, "Unable to POP CS"); goto error; }
          tcode[i] = cast(ubyte)((tcode[i]&0xC7)|(op.index<<3));
        } else {
          tcode[i] &= 0xC7;
          tmask[i] &= 0xC7;
        }
        break;
      case PRN: // Near return address (pseudooperand)
      case PRF: // Far return address (pseudooperand)
      case PAC: // Accumulator (AL/AX/EAX, pseudooperand)
      case PAH: // AH (in LAHF/SAHF, pseudooperand)
      case PFL: // Lower byte of flags (pseudooperand)
      case PS0: // Top of FPU stack (pseudooperand)
      case PS1: // ST(1) (pseudooperand)
      case PCX: // CX/ECX (pseudooperand)
      case PDI: // EDI (pseudooperand in MMX extentions)
        break; // Simply skip preudooperands
      default: // Undefined type of operand
        xstrcpy(errtext, "Internal Assembler error");
        goto error;
    }
  }
  // Gather parts of command together in the complete command.
  j = 0;
  if (lock != 0) {
    // Lock prefix specified
    model.code[j] = 0xF0;
    model.mask[j] = 0xFF;
    ++j;
  }
  if (datasize == 2 && pd.bits != FF) {
    // Data size prefix necessary
    model.code[j] = 0x66;
    model.mask[j] = 0xFF;
    ++j;
  }
  if (addrsize == 2) {
    // Address size prefix necessary
    model.code[j] = 0x67;
    model.mask[j] = 0xFF;
    ++j;
  }
  if (segment != SEG_UNDEF) {
    // Segment prefix necessary
         if (segment == SEG_ES) model.code[j] = 0x26;
    else if (segment == SEG_CS) model.code[j] = 0x2E;
    else if (segment == SEG_SS) model.code[j] = 0x36;
    else if (segment == SEG_DS) model.code[j] = 0x3E;
    else if (segment == SEG_FS) model.code[j] = 0x64;
    else if (segment == SEG_GS) model.code[j] = 0x65;
    else { xstrcpy(errtext, "Internal Assembler error"); goto error; }
    model.mask[j] = 0xFF;
    ++j;
  }
  if (dispsize > 0) {
    memcpy(tcode.ptr+i+1+hasrm+hassib, &displacement, dispsize);
    if (anydisp == 0) memset(tmask.ptr+i+1+hasrm+hassib, 0xFF, dispsize);
  }
  if (immsize > 0) {
         if (immsize == 1) l = 0xFFFFFF00U;
    else if (immsize == 2) l = 0xFFFF0000U;
    else l = 0;
    if ((immediate&l) != 0 && (immediate&l) != l) { xstrcpy(errtext, "Constant does not fit into operand"); goto error; }
    memcpy(tcode.ptr+i+1+hasrm+hassib+dispsize, &immediate, immsize);
    if (anyimm == 0) memset(tmask.ptr+i+1+hasrm+hassib+dispsize, 0xFF, immsize);
  }
  i = i+1+hasrm+hassib+dispsize+immsize;
  jmpoffset = jmpoffset-(i+j+jmpsize);
  model.jmpsize = jmpsize;
  model.jmpoffset = jmpoffset;
  model.jmppos = i+j;
  if (jmpsize != 0) {
    if (ip != 0) {
      jmpoffset = jmpoffset-ip;
      if (jmpsize == 1 && anyjmp == 0 && (jmpoffset < -128 || jmpoffset >= 128)) {
        if (longjump == 0 && (jmpmode&0x03) == 0) { longjump = 1; goto retrylongjump; }
        char[256] tbuf = 0;
        snprintf(tbuf.ptr, tbuf.length, "Relative jump out of range, use %s LONG form", name.ptr);
        xstrcpyx(errtext, tbuf[]);
        goto error;
      }
      memcpy(tcode.ptr+i, &jmpoffset, jmpsize);
    }
    if (anyjmp == 0) memset(tmask.ptr+i, 0xFF, jmpsize);
    i += jmpsize;
  }
  memcpy(model.code.ptr+j, tcode.ptr, i);
  memcpy(model.mask.ptr+j, tmask.ptr, i);
  i += j;
  model.length = i;
  return i; // Positive value: length of code
error:
  model.length = 0;
  return cast(int)(scdata.acommand.ptr-scdata.asmcmd); // Negative value: position of error
}
