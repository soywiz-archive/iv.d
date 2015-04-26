module iv.x11.md is aliced;

/*
 *  Xmd.d: MACHINE DEPENDENT DECLARATIONS.
 */


/*
 * Bitfield suffixes for the protocol structure elements, if you
 * need them.  Note that bitfields are not guaranteed to be signed
 * (or even unsigned) according to ANSI C.
 */
//~ #  define B32 :32
//~ #  define B16 :16
alias INT8 = sbyte;
alias INT16 = short; // was uint, why?!
alias INT32 = int;
alias INT64 = long;

alias CARD8 = ubyte;
alias CARD16 = ushort;
alias CARD32 = uint;
alias CARD64 = ulong;

alias BITS16 = CARD16;
alias BITS32 = CARD32;

alias BYTE = CARD8;
alias BOOL = CARD8;


alias widechar = dchar;
