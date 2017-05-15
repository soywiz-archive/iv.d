// Keystone Assembler Engine (www.keystone-engine.org)
// By Nguyen Anh Quynh <aquynh@gmail.com>, 2016
// k8: see licenses in original capstone package, i'm too lazy to copy 'em.
module iv.keystone is aliced;
pragma(lib, "keystone");
extern(C) nothrow:

struct ks_engine {}

// Keystone API version
enum KS_API_MAJOR = 0;
enum KS_API_MINOR = 9;

/*
  Macro to create combined version which can be compared to
  result of ks_version() API.
*/
uint KS_MAKE_VERSION (ubyte major, ubyte minor) { return ((major<<8)+minor); }

// Architecture type
alias ks_arch = uint;
enum /*ks_arch*/ : uint {
  KS_ARCH_ARM = 1, // ARM architecture (including Thumb, Thumb-2)
  KS_ARCH_ARM64,   // ARM-64, also called AArch64
  KS_ARCH_MIPS,    // Mips architecture
  KS_ARCH_X86,     // X86 architecture (including x86 & x86-64)
  KS_ARCH_PPC,     // PowerPC architecture (currently unsupported)
  KS_ARCH_SPARC,   // Sparc architecture
  KS_ARCH_SYSTEMZ, // SystemZ architecture (S390X)
  KS_ARCH_HEXAGON, // Hexagon architecture
  KS_ARCH_MAX,
}

// Mode type
alias ks_mode = uint;
enum /*ks_mode*/ : uint {
  KS_MODE_LITTLE_ENDIAN = 0,    // little-endian mode (default mode)
  KS_MODE_BIG_ENDIAN = 1 << 30, // big-endian mode
  // arm / arm64
  KS_MODE_ARM = 1 << 0,         // ARM mode
  KS_MODE_THUMB = 1 << 4,       // THUMB mode (including Thumb-2)
  KS_MODE_V8 = 1 << 6,          // ARMv8 A32 encodings for ARM
  // mips
  KS_MODE_MICRO = 1 << 4,       // MicroMips mode
  KS_MODE_MIPS3 = 1 << 5,       // Mips III ISA
  KS_MODE_MIPS32R6 = 1 << 6,    // Mips32r6 ISA
  KS_MODE_MIPS32 = 1 << 2,      // Mips32 ISA
  KS_MODE_MIPS64 = 1 << 3,      // Mips64 ISA
  // x86 / x64
  KS_MODE_16 = 1 << 1,          // 16-bit mode
  KS_MODE_32 = 1 << 2,          // 32-bit mode
  KS_MODE_64 = 1 << 3,          // 64-bit mode
  // ppc
  KS_MODE_PPC32 = 1 << 2,       // 32-bit mode
  KS_MODE_PPC64 = 1 << 3,       // 64-bit mode
  KS_MODE_QPX = 1 << 4,         // Quad Processing eXtensions mode
  // sparc
  KS_MODE_SPARC32 = 1 << 2,     // 32-bit mode
  KS_MODE_SPARC64 = 1 << 3,     // 64-bit mode
  KS_MODE_V9 = 1 << 4,          // SparcV9 mode
}

// All generic errors related to input assembly >= KS_ERR_ASM
enum KS_ERR_ASM = 128;

// All architecture-specific errors related to input assembly >= KS_ERR_ASM_ARCH
enum KS_ERR_ASM_ARCH = 512;

// All type of errors encountered by Keystone API.
alias ks_err = uint;
enum /*ks_err*/ : uint {
  KS_ERR_OK = 0,   // No error: everything was fine
  KS_ERR_NOMEM,      // Out-Of-Memory error: ks_open(), ks_emulate()
  KS_ERR_ARCH,     // Unsupported architecture: ks_open()
  KS_ERR_HANDLE,   // Invalid handle
  KS_ERR_MODE,     // Invalid/unsupported mode: ks_open()
  KS_ERR_VERSION,  // Unsupported version (bindings)
  KS_ERR_OPT_INVALID,  // Unsupported option

  // generic input assembly errors - parser specific
  KS_ERR_ASM_EXPR_TOKEN = KS_ERR_ASM,    // unknown token in expression
  KS_ERR_ASM_DIRECTIVE_VALUE_RANGE,   // literal value out of range for directive
  KS_ERR_ASM_DIRECTIVE_ID,    // expected identifier in directive
  KS_ERR_ASM_DIRECTIVE_TOKEN, // unexpected token in directive
  KS_ERR_ASM_DIRECTIVE_STR,   // expected string in directive
  KS_ERR_ASM_DIRECTIVE_COMMA, // expected comma in directive
  KS_ERR_ASM_DIRECTIVE_RELOC_NAME, // expected relocation name in directive
  KS_ERR_ASM_DIRECTIVE_RELOC_TOKEN, // unexpected token in .reloc directive
  KS_ERR_ASM_DIRECTIVE_FPOINT,    // invalid floating point in directive
  KS_ERR_ASM_DIRECTIVE_UNKNOWN,    // unknown directive
  KS_ERR_ASM_DIRECTIVE_EQU,   // invalid equal directive
  KS_ERR_ASM_DIRECTIVE_INVALID,   // (generic) invalid directive
  KS_ERR_ASM_VARIANT_INVALID, // invalid variant
  KS_ERR_ASM_EXPR_BRACKET,    // brackets expression not supported on this target
  KS_ERR_ASM_SYMBOL_MODIFIER, // unexpected symbol modifier following '@'
  KS_ERR_ASM_SYMBOL_REDEFINED, // invalid symbol redefinition
  KS_ERR_ASM_SYMBOL_MISSING,  // cannot find a symbol
  KS_ERR_ASM_RPAREN,          // expected ')' in parentheses expression
  KS_ERR_ASM_STAT_TOKEN,      // unexpected token at start of statement
  KS_ERR_ASM_UNSUPPORTED,     // unsupported token yet
  KS_ERR_ASM_MACRO_TOKEN,     // unexpected token in macro instantiation
  KS_ERR_ASM_MACRO_PAREN,     // unbalanced parentheses in macro argument
  KS_ERR_ASM_MACRO_EQU,       // expected '=' after formal parameter identifier
  KS_ERR_ASM_MACRO_ARGS,      // too many positional arguments
  KS_ERR_ASM_MACRO_LEVELS_EXCEED, // macros cannot be nested more than 20 levels deep
  KS_ERR_ASM_MACRO_STR,    // invalid macro string
  KS_ERR_ASM_MACRO_INVALID,    // invalid macro (generic error)
  KS_ERR_ASM_ESC_BACKSLASH,   // unexpected backslash at end of escaped string
  KS_ERR_ASM_ESC_OCTAL,       // invalid octal escape sequence  (out of range)
  KS_ERR_ASM_ESC_SEQUENCE,         // invalid escape sequence (unrecognized character)
  KS_ERR_ASM_ESC_STR,         // broken escape string
  KS_ERR_ASM_TOKEN_INVALID,   // invalid token
  KS_ERR_ASM_INSN_UNSUPPORTED,   // this instruction is unsupported in this mode
  KS_ERR_ASM_FIXUP_INVALID,   // invalid fixup
  KS_ERR_ASM_LABEL_INVALID,   // invalid label
  KS_ERR_ASM_FRAGMENT_INVALID,   // invalid fragment

  // generic input assembly errors - architecture specific
  KS_ERR_ASM_INVALIDOPERAND = KS_ERR_ASM_ARCH,
  KS_ERR_ASM_MISSINGFEATURE,
  KS_ERR_ASM_MNEMONICFAIL,
}


// Runtime option for the Keystone engine
alias ks_opt_type = uint;
enum /*ks_opt_type*/ : uint {
  KS_OPT_SYNTAX = 1,  // Choose syntax for input assembly
}


// Runtime option value (associated with ks_opt_type above)
alias ks_opt_value = uint;
enum /*ks_opt_value*/ : uint {
  KS_OPT_SYNTAX_INTEL = 1 << 0, // X86 Intel syntax - default on X86 (KS_OPT_SYNTAX).
  KS_OPT_SYNTAX_ATT   = 1 << 1, // X86 ATT asm syntax (KS_OPT_SYNTAX).
  KS_OPT_SYNTAX_NASM  = 1 << 2, // X86 Nasm syntax (KS_OPT_SYNTAX).
  KS_OPT_SYNTAX_MASM  = 1 << 3, // X86 Masm syntax (KS_OPT_SYNTAX) - unsupported yet.
  KS_OPT_SYNTAX_GAS   = 1 << 4, // X86 GNU GAS syntax (KS_OPT_SYNTAX).
}

// x86
alias ks_err_asm_x86 = uint;
enum /*ks_err_asm_x86*/ {
  KS_ERR_ASM_X86_INVALIDOPERAND = KS_ERR_ASM_ARCH,
  KS_ERR_ASM_X86_MISSINGFEATURE,
  KS_ERR_ASM_X86_MNEMONICFAIL,
}

/*
 Return combined API version & major and minor version numbers.

 @major: major number of API version
 @minor: minor number of API version

 @return hexical number as (major << 8 | minor), which encodes both
     major & minor versions.
     NOTE: This returned value can be compared with version number made
     with macro KS_MAKE_VERSION

 For example, second API version would return 1 in @major, and 1 in @minor
 The return value would be 0x0101

 NOTE: if you only care about returned value, but not major and minor values,
 set both @major & @minor arguments to NULL.
*/
public uint ks_version (uint* major, uint* minor);


/*
 Determine if the given architecture is supported by this library.

 @arch: architecture type (KS_ARCH_*)

 @return True if this library supports the given arch.
*/
public bool ks_arch_supported (ks_arch arch);


/*
 Create new instance of Keystone engine.

 @arch: architecture type (KS_ARCH_*)
 @mode: hardware mode. This is combined of KS_MODE_*
 @ks: pointer to ks_engine, which will be updated at return time

 @return KS_ERR_OK on success, or other value on failure (refer to ks_err enum
   for detailed error).
*/
public ks_err ks_open (ks_arch arch, int mode, ks_engine** ks);


/*
 Close KS instance: MUST do to release the handle when it is not used anymore.
 NOTE: this must be called only when there is no longer usage of Keystone.
 The reason is the this API releases some cached memory, thus access to any
 Keystone API after ks_close() might crash your application.
 After this, @ks is invalid, and nolonger usable.

 @ks: pointer to a handle returned by ks_open()

 @return KS_ERR_OK on success, or other value on failure (refer to ks_err enum
   for detailed error).
*/
public ks_err ks_close (ks_engine* ks);


/*
 Report the last error number when some API function fail.
 Like glibc's errno, ks_errno might not retain its old error once accessed.

 @ks: handle returned by ks_open()

 @return: error code of ks_err enum type (KS_ERR_*, see above)
*/
public ks_err ks_errno (ks_engine* ks);


/*
 Return a string describing given error code.

 @code: error code (see KS_ERR_* above)

 @return: returns a pointer to a string that describes the error code
   passed in the argument @code
 */
public const(char)* ks_strerror (ks_err code);


/*
 Set option for Keystone engine at runtime

 @ks: handle returned by ks_open()
 @type: type of option to be set
 @value: option value corresponding with @type

 @return: KS_ERR_OK on success, or other value on failure.
 Refer to ks_err enum for detailed error.
*/
public ks_err ks_option (ks_engine* ks, ks_opt_type type, usize value);


/*
 Assemble a string given its the buffer, size, start address and number
 of instructions to be decoded.
 This API dynamically allocate memory to contain assembled instruction.
 Resulted array of bytes containing the machine code  is put into @*encoding

 NOTE 1: this API will automatically determine memory needed to contain
 output bytes in *encoding.

 NOTE 2: caller must free the allocated memory itself to avoid memory leaking.

 @ks: handle returned by ks_open()
 @str: NULL-terminated assembly string. Use ; or \n to separate statements.
 @address: address of the first assembly instruction, or 0 to ignore.
 @encoding: array of bytes containing encoding of input assembly string.
     NOTE: *encoding will be allocated by this function, and should be freed
     with ks_free() function.
 @encoding_size: size of *encoding
 @stat_count: number of statements successfully processed

 @return: 0 on success, or -1 on failure.

 On failure, call ks_errno() for error code.
*/
public int ks_asm (ks_engine* ks, const(char)* string, ulong address, ubyte** encoding, usize* encoding_size, usize* stat_count);


/*
 Free memory allocated by ks_asm()

 @p: memory allocated in @encoding argument of ks_asm()
*/
public void ks_free (void* p);
