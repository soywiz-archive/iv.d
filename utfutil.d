/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */
// UTF-8 utilities (there will be more soon ;-)
module iv.utfutil /*is aliced*/;
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
bool isValidUtf8Start (ubyte b) pure nothrow @safe @nogc { pragma(inline, true); return (b < 128 || (b&0xc0) == 0xC0); } /// rough check

// ////////////////////////////////////////////////////////////////////////// //
bool isUtf8Start() (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch&0xC0) == 0xC0); } /// does this char start UTF-8 sequence?
bool isUtf8Cont() (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch&0xC0) == 0x80); } /// does this char continue UTF-8 sequence?


// ////////////////////////////////////////////////////////////////////////// //
/// fast state-machine based UTF-8 decoder; using 8 bytes of memory
/// code points from invalid range will never be valid, this is the property of the state machine
align(1) struct Utf8DecoderFast {
align(1):
public:
  enum dchar replacement = '\uFFFD'; /// replacement char for invalid unicode
  static bool isValidDC (dchar c) pure nothrow @safe @nogc { pragma(inline, true); return (c < 0xD800 || (c > 0xDFFF && c <= 0x10FFFF)); } /// is given codepoint valid?

private:
  enum State {
    Accept = 0,
    Reject = 12,
  }

  // see http://bjoern.hoehrmann.de/utf-8/decoder/dfa/
  static immutable ubyte[0x16c] utf8dfa = [
    // maps bytes to character classes
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 00-0f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 10-1f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 20-2f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 30-3f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 40-4f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 50-5f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 60-6f
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // 70-7f
    0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01, // 80-8f
    0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09, // 90-9f
    0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07, // a0-af
    0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07, // b0-bf
    0x08,0x08,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02, // c0-cf
    0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02, // d0-df
    0x0a,0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x03,0x04,0x03,0x03, // e0-ef
    0x0b,0x06,0x06,0x06,0x05,0x08,0x08,0x08,0x08,0x08,0x08,0x08,0x08,0x08,0x08,0x08, // f0-ff
    // maps a combination of a state of the automaton and a character class to a state
    0x00,0x0c,0x18,0x24,0x3c,0x60,0x54,0x0c,0x0c,0x0c,0x30,0x48,0x0c,0x0c,0x0c,0x0c, // 100-10f
    0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x00,0x0c,0x0c,0x0c,0x0c,0x0c,0x00, // 110-11f
    0x0c,0x00,0x0c,0x0c,0x0c,0x18,0x0c,0x0c,0x0c,0x0c,0x0c,0x18,0x0c,0x18,0x0c,0x0c, // 120-12f
    0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x18,0x0c,0x0c,0x0c,0x0c,0x0c,0x18,0x0c,0x0c, // 130-13f
    0x0c,0x0c,0x0c,0x0c,0x0c,0x18,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x24, // 140-14f
    0x0c,0x24,0x0c,0x0c,0x0c,0x24,0x0c,0x0c,0x0c,0x0c,0x0c,0x24,0x0c,0x24,0x0c,0x0c, // 150-15f
    0x0c,0x24,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c];

private:
  uint state;

nothrow @safe @nogc:
public:
  dchar codepoint = 0; /// decoded codepoint (valid only when decoder is in "complete" state)

  @property bool complete () const pure { pragma(inline, true); return (state == State.Accept); } /// is current character complete? take `codepoint` then
  @property bool invalid () const pure { pragma(inline, true); return (state == State.Reject); } ///
  @property bool completeOrInvalid () const pure { pragma(inline, true); return (state == State.Accept || state == State.Reject); } ///
  void reset () pure { pragma(inline, true); state = State.Accept; codepoint = 0; } ///
  /// process one byte, return `true` if codepoint is ready
  bool decode (ubyte b) pure @trusted {
    if (state == State.Reject) { state = 0; codepoint = 0; }
    uint type = utf8dfa.ptr[b];
    codepoint = (state != State.Accept ? (b&0x3fu)|(codepoint<<6) : (0xff>>type)&b);
    state = utf8dfa.ptr[256+state+type];
    return (state == State.Accept);
  }
  /// same as `decode`, but caller is guaranteed that decoder will never get invalid utf-8 sequence
  bool decodeValid (ubyte b) pure @trusted {
    uint type = utf8dfa.ptr[b];
    codepoint = (state != State.Accept ? (b&0x3fu)|(codepoint<<6) : (0xff>>type)&b);
    state = utf8dfa.ptr[256+state+type];
    return (state == State.Accept);
  }
  /// same as `decode`, never reaches `invalid` state, returns `replacement` for invalid chars
  bool decodeSafe (ubyte b) pure @trusted {
    uint type = utf8dfa.ptr[b];
    codepoint = (state != State.Accept ? (b&0x3f)|(codepoint<<6) : (0xff>>type)&b);
    if ((state = utf8dfa.ptr[256+state+type]) == State.Reject) { state = State.Accept; codepoint = replacement; }
    return (state == State.Accept);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// slightly slower state-machine based UTF-8 decoder; using 4 bytes of memory (uint)
/// code points from invalid range will never be valid, this is the property of the state machine
align(1) struct Utf8Decoder {
align(1):
public:
  enum dchar replacement = '\uFFFD'; /// replacement char for invalid unicode
  static bool isValidDC (dchar c) pure nothrow @safe @nogc { pragma(inline, true); return (c < 0xD800 || (c > 0xDFFF && c <= 0x10FFFF)); } /// is given codepoint valid?

private:
  enum State : uint {
    Accept = 0x0000_0000u,
    Reject = 0x0c00_0000u,
    Mask = 0xff00_0000u
  }
  uint codep = State.Accept;
pure nothrow @safe @nogc:
public:
  @property bool complete () const { pragma(inline, true); return ((codep&State.Mask) == State.Accept); } /// is current character complete?
  @property bool invalid () const { pragma(inline, true); return ((codep&State.Mask) == State.Reject); } ///
  @property bool completeOrInvalid () const { pragma(inline, true); return (complete || invalid); } ///
  @property dchar currCodePoint () const { pragma(inline, true); return (codep <= dchar.max ? codep : replacement); } /// valid only if decoder is in "complete" state
  void reset () { codep = State.Accept; } ///
  /** same as `decode`, never reaches `invalid` state, returns `replacement` for invalid chars
   * returns invalid dchar while it is "in progress" (i.e. result > dchar.max) */
  dchar decode (ubyte b) @trusted {
    immutable ubyte type = Utf8DecoderFast.utf8dfa.ptr[b];
    ubyte state = (codep>>24)&0xff;
    codep = (state /*!= State.Accept*/ ? (b&0x3f)|((codep&~State.Mask)<<6) : (0xff>>type)&b);
    if ((state = Utf8DecoderFast.utf8dfa.ptr[256+state+type]) == 12/*State.Reject*/) {
      codep = replacement;
    } else {
      codep |= (cast(uint)state<<24);
    }
    return codep;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// returns -1 on error (out of room in `s`), or number of generated bytes
int utf8Encode(dchar replacement='\uFFFD') (char[] s, dchar c) pure nothrow @trusted @nogc {
  static assert(Utf8Decoder.isValidDC(replacement), "invalid replacement char");
  // if this is out-of-range char, put replacement instead
  if (!Utf8Decoder.isValidDC(c)) c = replacement;
  if (c <= 0x7F) {
    if (s.length < 1) return -1;
    s.ptr[0] = cast(char)c;
    return 1;
  } else {
    char[4] buf = void;
    int len = void;
    if (c <= 0x7FF) {
      buf.ptr[0] = cast(char)(0xC0|(c>>6));
      buf.ptr[1] = cast(char)(0x80|(c&0x3F));
      len = 2;
    } else if (c <= 0xFFFF) {
      buf.ptr[0] = cast(char)(0xE0|(c>>12));
      buf.ptr[1] = cast(char)(0x80|((c>>6)&0x3F));
      buf.ptr[2] = cast(char)(0x80|(c&0x3F));
      len = 3;
    } else if (c <= 0x10FFFF) {
      buf.ptr[0] = cast(char)(0xF0|(c>>18));
      buf.ptr[1] = cast(char)(0x80|((c>>12)&0x3F));
      buf.ptr[2] = cast(char)(0x80|((c>>6)&0x3F));
      buf.ptr[3] = cast(char)(0x80|(c&0x3F));
      len = 4;
    } else {
      // the thing that should not be
      assert(0, "wtf?!");
    }
    if (s.length < len) return -1;
    s.ptr[0..len] = buf.ptr[0..len];
    return len;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// doesn't do all possible checks, so don't pass invalid UTF-8
usize utf8Length (const(char)[] s) pure nothrow @trusted @nogc {
  static immutable ubyte[256] UTF8stride = [
    cast(ubyte)
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,0xFF,0xFF,
  ];
  usize pos = 0, res = 0;
  while (pos < s.length) {
    ubyte l = UTF8stride.ptr[s.ptr[pos++]];
    if (l == 0xFF) l = 1;
    res += l;
    pos += (l-1);
  }
  return res;
}


/// `ch`: utf8 start
/// -1: invalid utf8
byte utf8CodeLen (char ch) {
  //pragma(inline, true);
  if (ch < 0x80) return 1;
  if ((ch&0b1111_1110) == 0b1111_1100) return 6;
  if ((ch&0b1111_1100) == 0b1111_1000) return 5;
  if ((ch&0b1111_1000) == 0b1111_0000) return 4;
  if ((ch&0b1111_0000) == 0b1110_0000) return 3;
  if ((ch&0b1110_0000) == 0b1100_0000) return 2;
  return -1; // invalid
}


///
bool utf8Valid (const(char)[] buf) {
  auto bp = buf.ptr;
  auto left = buf.length;
  while (left-- > 0) {
    auto len = utf8CodeLen(*bp++)-1;
    if (len < 0 || len > left) return false;
    left -= len;
    while (len-- > 0) if (((*bp++)&0b1100_0000) != 0b1000_0000) return false;
  }
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/+
private static immutable ubyte[0x458-0x401] uni2koiTable = [
  0xB3,0x3F,0x3F,0xB4,0x3F,0xB6,0xB7,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0xE1,
  0xE2,0xF7,0xE7,0xE4,0xE5,0xF6,0xFA,0xE9,0xEA,0xEB,0xEC,0xED,0xEE,0xEF,0xF0,0xF2,
  0xF3,0xF4,0xF5,0xE6,0xE8,0xE3,0xFE,0xFB,0xFD,0xFF,0xF9,0xF8,0xFC,0xE0,0xF1,0xC1,
  0xC2,0xD7,0xC7,0xC4,0xC5,0xD6,0xDA,0xC9,0xCA,0xCB,0xCC,0xCD,0xCE,0xCF,0xD0,0xD2,
  0xD3,0xD4,0xD5,0xC6,0xC8,0xC3,0xDE,0xDB,0xDD,0xDF,0xD9,0xD8,0xDC,0xC0,0xD1,0x3F,
  0xA3,0x3F,0x3F,0xA4,0x3F,0xA6,0xA7
];


private static immutable dchar[128] koi2uniTable = [
  0x2500,0x2502,0x250C,0x2510,0x2514,0x2518,0x251C,0x2524,0x252C,0x2534,0x253C,0x2580,0x2584,0x2588,0x258C,0x2590,
  0x2591,0x2592,0x2593,0x2320,0x25A0,0x2219,0x221A,0x2248,0x2264,0x2265,0x00A0,0x2321,0x00B0,0x00B2,0x00B7,0x00F7,
  0x2550,0x2551,0x2552,0x0451,0x0454,0x2554,0x0456,0x0457,0x2557,0x2558,0x2559,0x255A,0x255B,0x0491,0x255D,0x255E,
  0x255F,0x2560,0x2561,0x0401,0x0404,0x2563,0x0406,0x0407,0x2566,0x2567,0x2568,0x2569,0x256A,0x0490,0x256C,0x00A9,
  0x044E,0x0430,0x0431,0x0446,0x0434,0x0435,0x0444,0x0433,0x0445,0x0438,0x0439,0x043A,0x043B,0x043C,0x043D,0x043E,
  0x043F,0x044F,0x0440,0x0441,0x0442,0x0443,0x0436,0x0432,0x044C,0x044B,0x0437,0x0448,0x044D,0x0449,0x0447,0x044A,
  0x042E,0x0410,0x0411,0x0426,0x0414,0x0415,0x0424,0x0413,0x0425,0x0418,0x0419,0x041A,0x041B,0x041C,0x041D,0x041E,
  0x041F,0x042F,0x0420,0x0421,0x0422,0x0423,0x0416,0x0412,0x042C,0x042B,0x0417,0x0428,0x042D,0x0429,0x0427,0x042A,
];


// convert unicode to koi8-u
public char uni2koi() (dchar ch) pure nothrow @trusted @nogc {
  if (ch < 128) return cast(char)(ch&0xff);
  if (ch > 0x400 && ch < 0x458) return cast(char)(uni2koiTable.ptr[ch-0x401]);
  switch (ch) {
    case 0x490: return 0xBD; // ukrainian G with upturn (upcase)
    case 0x491: return 0xAD; // ukrainian G with upturn (locase)
    case 0x2500: return 0x80; // BOX DRAWINGS LIGHT HORIZONTAL
    case 0x2502: return 0x81; // BOX DRAWINGS LIGHT VERTICAL
    case 0x250c: return 0x82; // BOX DRAWINGS LIGHT DOWN AND RIGHT
    case 0x2510: return 0x83; // BOX DRAWINGS LIGHT DOWN AND LEFT
    case 0x2514: return 0x84; // BOX DRAWINGS LIGHT UP AND RIGHT
    case 0x2518: return 0x85; // BOX DRAWINGS LIGHT UP AND LEFT
    case 0x251c: return 0x86; // BOX DRAWINGS LIGHT VERTICAL AND RIGHT
    case 0x2524: return 0x87; // BOX DRAWINGS LIGHT VERTICAL AND LEFT
    case 0x252c: return 0x88; // BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
    case 0x2534: return 0x89; // BOX DRAWINGS LIGHT UP AND HORIZONTAL
    case 0x253c: return 0x8A; // BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
    case 0x2580: return 0x8B; // UPPER HALF BLOCK
    case 0x2584: return 0x8C; // LOWER HALF BLOCK
    case 0x2588: return 0x8D; // FULL BLOCK
    case 0x258c: return 0x8E; // LEFT HALF BLOCK
    case 0x2590: return 0x8F; // RIGHT HALF BLOCK
    case 0x2591: return 0x90; // LIGHT SHADE
    case 0x2592: return 0x91; // MEDIUM SHADE
    case 0x2593: return 0x92; // DARK SHADE
    case 0x2320: return 0x93; // TOP HALF INTEGRAL
    case 0x25a0: return 0x94; // BLACK SQUARE
    case 0x2219: return 0x95; // BULLET OPERATOR
    case 0x221a: return 0x96; // SQUARE ROOT
    case 0x2248: return 0x97; // ALMOST EQUAL TO
    case 0x2264: return 0x98; // LESS-THAN OR EQUAL TO
    case 0x2265: return 0x99; // GREATER-THAN OR EQUAL TO
    case 0x00a0: return 0x9A; // NO-BREAK SPACE
    case 0x2321: return 0x9B; // BOTTOM HALF INTEGRAL
    case 0x00b0: return 0x9C; // DEGREE SIGN
    case 0x00b2: return 0x9D; // SUPERSCRIPT TWO
    case 0x00b7: return 0x9E; // MIDDLE DOT
    case 0x00f7: return 0x9F; // DIVISION SIGN
    case 0x2550: return 0xA0; // BOX DRAWINGS DOUBLE HORIZONTAL
    case 0x2551: return 0xA1; // BOX DRAWINGS DOUBLE VERTICAL
    case 0x2552: return 0xA2; // BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE
    case 0x2554: return 0xA5; // BOX DRAWINGS DOUBLE DOWN AND RIGHT
    case 0x2557: return 0xA8; // BOX DRAWINGS DOUBLE DOWN AND LEFT
    case 0x2558: return 0xA9; // BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE
    case 0x2559: return 0xAA; // BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE
    case 0x255a: return 0xAB; // BOX DRAWINGS DOUBLE UP AND RIGHT
    case 0x255b: return 0xAC; // BOX DRAWINGS UP SINGLE AND LEFT DOUBLE
    case 0x255d: return 0xAE; // BOX DRAWINGS DOUBLE UP AND LEFT
    case 0x255e: return 0xAF; // BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE
    case 0x255f: return 0xB0; // BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE
    case 0x2560: return 0xB1; // BOX DRAWINGS DOUBLE VERTICAL AND RIGHT
    case 0x2561: return 0xB2; // BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE
    case 0x2563: return 0xB5; // BOX DRAWINGS DOUBLE VERTICAL AND LEFT
    case 0x2566: return 0xB8; // BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL
    case 0x2567: return 0xB9; // BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE
    case 0x2568: return 0xBA; // BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE
    case 0x2569: return 0xBB; // BOX DRAWINGS DOUBLE UP AND HORIZONTAL
    case 0x256a: return 0xBC; // BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE
    case 0x256c: return 0xBE; // BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL
    case 0x00a9: return 0xBF; // COPYRIGHT SIGN
    //
    case 0x2562: return 0xB4; // BOX DRAWINGS DOUBLE VERTICAL AND LEFT SINGLE
    case 0x2564: return 0xB6; // BOX DRAWINGS DOWN SINGLE AND DOUBLE HORIZONTAL
    case 0x2565: return 0xB7; // BOX DRAWINGS DOWN DOUBLE AND SINGLE HORIZONTAL
    case 0x256B: return 0xBD; // BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL SINGLE
    default:
  }
  return 0;
}


// convert koi8-u to unicode
public dchar koi2uni() (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (ch < 128 ? ch : koi2uniTable.ptr[cast(ubyte)ch-128]);
}
+/


// ////////////////////////////////////////////////////////////////////////// //
/// convert koi8 to unicode
wchar koi2uni() (char ch) pure nothrow @trusted @nogc {
  static immutable wchar[256] utbl = [
      0x0000,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,0x0008,0x0009,0x000a,0x000b,0x000c,0x000d,0x000e,0x000f,
      0x0010,0x0011,0x0012,0x0013,0x0014,0x0015,0x0016,0x0017,0x0018,0x0019,0x001a,0x001b,0x001c,0x001d,0x001e,0x001f,
      0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,0x0028,0x0029,0x002a,0x002b,0x002c,0x002d,0x002e,0x002f,
      0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,0x0038,0x0039,0x003a,0x003b,0x003c,0x003d,0x003e,0x003f,
      0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,0x0048,0x0049,0x004a,0x004b,0x004c,0x004d,0x004e,0x004f,
      0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,0x0058,0x0059,0x005a,0x005b,0x005c,0x005d,0x005e,0x005f,
      0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,0x0068,0x0069,0x006a,0x006b,0x006c,0x006d,0x006e,0x006f,
      0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,0x0078,0x0079,0x007a,0x007b,0x007c,0x007d,0x007e,0x007f,
      0x2500,0x2502,0x250c,0x2510,0x2514,0x2518,0x251c,0x2524,0x252c,0x2534,0x253c,0x2580,0x2584,0x2588,0x258c,0x2590,
      0x2591,0x2592,0x2593,0x2320,0x25a0,0x2219,0x221a,0x2248,0x2264,0x2265,0x00a0,0x2321,0x00b0,0x00b2,0x00b7,0x00f7,
      0x2550,0x2551,0x2552,0x0451,0x0454,0x2554,0x0456,0x0457,0x2557,0x2558,0x2559,0x255a,0x255b,0x0491,0x255d,0x255e,
      0x255f,0x2560,0x2561,0x0401,0x0404,0x2563,0x0406,0x0407,0x2566,0x2567,0x2568,0x2569,0x256a,0x0490,0x256c,0x00a9,
      0x044e,0x0430,0x0431,0x0446,0x0434,0x0435,0x0444,0x0433,0x0445,0x0438,0x0439,0x043a,0x043b,0x043c,0x043d,0x043e,
      0x043f,0x044f,0x0440,0x0441,0x0442,0x0443,0x0436,0x0432,0x044c,0x044b,0x0437,0x0448,0x044d,0x0449,0x0447,0x044a,
      0x042e,0x0410,0x0411,0x0426,0x0414,0x0415,0x0424,0x0413,0x0425,0x0418,0x0419,0x041a,0x041b,0x041c,0x041d,0x041e,
      0x041f,0x042f,0x0420,0x0421,0x0422,0x0423,0x0416,0x0412,0x042c,0x042b,0x0417,0x0428,0x042d,0x0429,0x0427,0x042a,
  ];
  return utbl.ptr[cast(ubyte)ch];
}

/// convert unicode to koi8
char uni2koi(char repchar='?') (dchar dch) pure nothrow @trusted @nogc {
  if (dch < 128) return cast(char)(dch&0xff);
  if (dch == 0x00a0) return cast(char)0x9a;
  if (dch == 0x00a9) return cast(char)0xbf;
  if (dch == 0x00b0) return cast(char)0x9c;
  if (dch == 0x00b2) return cast(char)0x9d;
  if (dch == 0x00b7) return cast(char)0x9e;
  if (dch == 0x00f7) return cast(char)0x9f;
  if (dch == 0x0401) return cast(char)0xb3;
  if (dch == 0x0404) return cast(char)0xb4;
  if (dch == 0x0406) return cast(char)0xb6;
  if (dch == 0x0407) return cast(char)0xb7;
  if (dch >= 0x0410 && dch <= 0x044f) {
    static immutable char[64] ctbl0 = [
      0xe1,0xe2,0xf7,0xe7,0xe4,0xe5,0xf6,0xfa,0xe9,0xea,0xeb,0xec,0xed,0xee,0xef,0xf0,
      0xf2,0xf3,0xf4,0xf5,0xe6,0xe8,0xe3,0xfe,0xfb,0xfd,0xff,0xf9,0xf8,0xfc,0xe0,0xf1,
      0xc1,0xc2,0xd7,0xc7,0xc4,0xc5,0xd6,0xda,0xc9,0xca,0xcb,0xcc,0xcd,0xce,0xcf,0xd0,
      0xd2,0xd3,0xd4,0xd5,0xc6,0xc8,0xc3,0xde,0xdb,0xdd,0xdf,0xd9,0xd8,0xdc,0xc0,0xd1,
    ];
    return ctbl0.ptr[cast(uint)dch-1040];
  }
  if (dch == 0x0451) return cast(char)0xa3;
  if (dch == 0x0454) return cast(char)0xa4;
  if (dch == 0x0456) return cast(char)0xa6;
  if (dch == 0x0457) return cast(char)0xa7;
  if (dch == 0x0490) return cast(char)0xbd;
  if (dch == 0x0491) return cast(char)0xad;
  if (dch == 0x2219) return cast(char)0x95;
  if (dch == 0x221a) return cast(char)0x96;
  if (dch == 0x2248) return cast(char)0x97;
  if (dch == 0x2264) return cast(char)0x98;
  if (dch == 0x2265) return cast(char)0x99;
  if (dch == 0x2320) return cast(char)0x93;
  if (dch == 0x2321) return cast(char)0x9b;
  if (dch == 0x2500) return cast(char)0x80;
  if (dch == 0x2502) return cast(char)0x81;
  if (dch == 0x250c) return cast(char)0x82;
  if (dch == 0x2510) return cast(char)0x83;
  if (dch == 0x2514) return cast(char)0x84;
  if (dch == 0x2518) return cast(char)0x85;
  if (dch == 0x251c) return cast(char)0x86;
  if (dch == 0x2524) return cast(char)0x87;
  if (dch == 0x252c) return cast(char)0x88;
  if (dch == 0x2534) return cast(char)0x89;
  if (dch == 0x253c) return cast(char)0x8a;
  if (dch == 0x2550) return cast(char)0xa0;
  if (dch == 0x2551) return cast(char)0xa1;
  if (dch == 0x2552) return cast(char)0xa2;
  if (dch == 0x2554) return cast(char)0xa5;
  if (dch >= 0x2557 && dch <= 0x255b) {
    static immutable char[5] ctbl1 = [0xa8,0xa9,0xaa,0xab,0xac,];
    return ctbl1.ptr[cast(uint)dch-9559];
  }
  if (dch >= 0x255d && dch <= 0x2561) {
    static immutable char[5] ctbl2 = [0xae,0xaf,0xb0,0xb1,0xb2,];
    return ctbl2.ptr[cast(uint)dch-9565];
  }
  if (dch == 0x2563) return cast(char)0xb5;
  if (dch >= 0x2566 && dch <= 0x256a) {
    static immutable char[5] ctbl3 = [0xb8,0xb9,0xba,0xbb,0xbc,];
    return ctbl3.ptr[cast(uint)dch-9574];
  }
  if (dch == 0x256c) return cast(char)0xbe;
  if (dch == 0x2580) return cast(char)0x8b;
  if (dch == 0x2584) return cast(char)0x8c;
  if (dch == 0x2588) return cast(char)0x8d;
  if (dch == 0x258c) return cast(char)0x8e;
  if (dch >= 0x2590 && dch <= 0x2593) {
    static immutable char[4] ctbl4 = [0x8f,0x90,0x91,0x92,];
    return ctbl4.ptr[cast(uint)dch-9616];
  }
  if (dch == 0x25a0) return cast(char)0x94;
  return repchar;
}


// ////////////////////////////////////////////////////////////////////////// //
/// conver 1251 to unicode
wchar cp12512uni() (char ch) pure nothrow @trusted @nogc {
  static immutable wchar[256] utbl = [
      0x0000,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,0x0008,0x0009,0x000a,0x000b,0x000c,0x000d,0x000e,0x000f,
      0x0010,0x0011,0x0012,0x0013,0x0014,0x0015,0x0016,0x0017,0x0018,0x0019,0x001a,0x001b,0x001c,0x001d,0x001e,0x001f,
      0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,0x0028,0x0029,0x002a,0x002b,0x002c,0x002d,0x002e,0x002f,
      0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,0x0038,0x0039,0x003a,0x003b,0x003c,0x003d,0x003e,0x003f,
      0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,0x0048,0x0049,0x004a,0x004b,0x004c,0x004d,0x004e,0x004f,
      0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,0x0058,0x0059,0x005a,0x005b,0x005c,0x005d,0x005e,0x005f,
      0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,0x0068,0x0069,0x006a,0x006b,0x006c,0x006d,0x006e,0x006f,
      0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,0x0078,0x0079,0x007a,0x007b,0x007c,0x007d,0x007e,0x007f,
      0x0402,0x0403,0x201a,0x0453,0x201e,0x2026,0x2020,0x2021,0x20ac,0x2030,0x0409,0x2039,0x040a,0x040c,0x040b,0x040f,
      0x0452,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0xfffd,0x2122,0x0459,0x203a,0x045a,0x045c,0x045b,0x045f,
      0x00a0,0x040e,0x045e,0x0408,0x00a4,0x0490,0x00a6,0x00a7,0x0401,0x00a9,0x0404,0x00ab,0x00ac,0x00ad,0x00ae,0x0407,
      0x00b0,0x00b1,0x0406,0x0456,0x0491,0x00b5,0x00b6,0x00b7,0x0451,0x2116,0x0454,0x00bb,0x0458,0x0405,0x0455,0x0457,
      0x0410,0x0411,0x0412,0x0413,0x0414,0x0415,0x0416,0x0417,0x0418,0x0419,0x041a,0x041b,0x041c,0x041d,0x041e,0x041f,
      0x0420,0x0421,0x0422,0x0423,0x0424,0x0425,0x0426,0x0427,0x0428,0x0429,0x042a,0x042b,0x042c,0x042d,0x042e,0x042f,
      0x0430,0x0431,0x0432,0x0433,0x0434,0x0435,0x0436,0x0437,0x0438,0x0439,0x043a,0x043b,0x043c,0x043d,0x043e,0x043f,
      0x0440,0x0441,0x0442,0x0443,0x0444,0x0445,0x0446,0x0447,0x0448,0x0449,0x044a,0x044b,0x044c,0x044d,0x044e,0x044f,
  ];
  return utbl.ptr[cast(ubyte)ch];
}

/// convert unicode to 1251
char uni2cp1251(char repchar='?') (dchar dch) pure nothrow @trusted @nogc {
  if (dch < 128) return cast(char)(dch&0xff);
  if (dch == 0x00a0) return cast(char)0xa0;
  if (dch == 0x00a4) return cast(char)0xa4;
  if (dch == 0x00a6) return cast(char)0xa6;
  if (dch == 0x00a7) return cast(char)0xa7;
  if (dch == 0x00a9) return cast(char)0xa9;
  if (dch >= 0x00ab && dch <= 0x00ae) {
    static immutable char[4] ctbl0 = [0xab,0xac,0xad,0xae,];
    return ctbl0.ptr[cast(uint)dch-171];
  }
  if (dch == 0x00b0) return cast(char)0xb0;
  if (dch == 0x00b1) return cast(char)0xb1;
  if (dch == 0x00b5) return cast(char)0xb5;
  if (dch == 0x00b6) return cast(char)0xb6;
  if (dch == 0x00b7) return cast(char)0xb7;
  if (dch == 0x00bb) return cast(char)0xbb;
  if (dch >= 0x0401 && dch <= 0x040c) {
    static immutable char[12] ctbl1 = [0xa8,0x80,0x81,0xaa,0xbd,0xb2,0xaf,0xa3,0x8a,0x8c,0x8e,0x8d,];
    return ctbl1.ptr[cast(uint)dch-1025];
  }
  if (dch >= 0x040e && dch <= 0x044f) {
    static immutable char[66] ctbl2 = [
      0xa1,0x8f,0xc0,0xc1,0xc2,0xc3,0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xcb,0xcc,0xcd,
      0xce,0xcf,0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xdb,0xdc,0xdd,
      0xde,0xdf,0xe0,0xe1,0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xeb,0xec,0xed,
      0xee,0xef,0xf0,0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xfb,0xfc,0xfd,
      0xfe,0xff,
    ];
    return ctbl2.ptr[cast(uint)dch-1038];
  }
  if (dch >= 0x0451 && dch <= 0x045c) {
    static immutable char[12] ctbl3 = [0xb8,0x90,0x83,0xba,0xbe,0xb3,0xbf,0xbc,0x9a,0x9c,0x9e,0x9d,];
    return ctbl3.ptr[cast(uint)dch-1105];
  }
  if (dch == 0x045e) return cast(char)0xa2;
  if (dch == 0x045f) return cast(char)0x9f;
  if (dch == 0x0490) return cast(char)0xa5;
  if (dch == 0x0491) return cast(char)0xb4;
  if (dch == 0x2013) return cast(char)0x96;
  if (dch == 0x2014) return cast(char)0x97;
  if (dch == 0x2018) return cast(char)0x91;
  if (dch == 0x2019) return cast(char)0x92;
  if (dch == 0x201a) return cast(char)0x82;
  if (dch == 0x201c) return cast(char)0x93;
  if (dch == 0x201d) return cast(char)0x94;
  if (dch == 0x201e) return cast(char)0x84;
  if (dch == 0x2020) return cast(char)0x86;
  if (dch == 0x2021) return cast(char)0x87;
  if (dch == 0x2022) return cast(char)0x95;
  if (dch == 0x2026) return cast(char)0x85;
  if (dch == 0x2030) return cast(char)0x89;
  if (dch == 0x2039) return cast(char)0x8b;
  if (dch == 0x203a) return cast(char)0x9b;
  if (dch == 0x20ac) return cast(char)0x88;
  if (dch == 0x2116) return cast(char)0xb9;
  if (dch == 0x2122) return cast(char)0x99;
  //if (dch == 0xfffd) return cast(char)0x98;
  return repchar;
}


// ////////////////////////////////////////////////////////////////////////// //
/// convert 866 to unicode
wchar cp8662uni() (char ch) pure nothrow @trusted @nogc {
  static immutable wchar[256] utbl = [
      0x0000,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,0x0008,0x0009,0x000a,0x000b,0x000c,0x000d,0x000e,0x000f,
      0x0010,0x0011,0x0012,0x0013,0x0014,0x0015,0x0016,0x0017,0x0018,0x0019,0x001a,0x001b,0x001c,0x001d,0x001e,0x001f,
      0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,0x0028,0x0029,0x002a,0x002b,0x002c,0x002d,0x002e,0x002f,
      0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,0x0038,0x0039,0x003a,0x003b,0x003c,0x003d,0x003e,0x003f,
      0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,0x0048,0x0049,0x004a,0x004b,0x004c,0x004d,0x004e,0x004f,
      0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,0x0058,0x0059,0x005a,0x005b,0x005c,0x005d,0x005e,0x005f,
      0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,0x0068,0x0069,0x006a,0x006b,0x006c,0x006d,0x006e,0x006f,
      0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,0x0078,0x0079,0x007a,0x007b,0x007c,0x007d,0x007e,0x007f,
      0x0410,0x0411,0x0412,0x0413,0x0414,0x0415,0x0416,0x0417,0x0418,0x0419,0x041a,0x041b,0x041c,0x041d,0x041e,0x041f,
      0x0420,0x0421,0x0422,0x0423,0x0424,0x0425,0x0426,0x0427,0x0428,0x0429,0x042a,0x042b,0x042c,0x042d,0x042e,0x042f,
      0x0430,0x0431,0x0432,0x0433,0x0434,0x0435,0x0436,0x0437,0x0438,0x0439,0x043a,0x043b,0x043c,0x043d,0x043e,0x043f,
      0x2591,0x2592,0x2593,0x2502,0x2524,0x2561,0x2562,0x2556,0x2555,0x2563,0x2551,0x2557,0x255d,0x255c,0x255b,0x2510,
      0x2514,0x2534,0x252c,0x251c,0x2500,0x253c,0x255e,0x255f,0x255a,0x2554,0x2569,0x2566,0x2560,0x2550,0x256c,0x2567,
      0x2568,0x2564,0x2565,0x2559,0x2558,0x2552,0x2553,0x256b,0x256a,0x2518,0x250c,0x2588,0x2584,0x258c,0x2590,0x2580,
      0x0440,0x0441,0x0442,0x0443,0x0444,0x0445,0x0446,0x0447,0x0448,0x0449,0x044a,0x044b,0x044c,0x044d,0x044e,0x044f,
      0x0401,0x0451,0x0404,0x0454,0x0407,0x0457,0x040e,0x045e,0x00b0,0x2219,0x00b7,0x221a,0x2116,0x00a4,0x25a0,0x00a0,
  ];
  return utbl.ptr[cast(ubyte)ch];
}

/// convert unicode to 866
char uni2cp866(char repchar='?') (dchar dch) pure nothrow @trusted @nogc {
  if (dch < 128) return cast(char)(dch&0xff);
  if (dch == 0x00a0) return cast(char)0xff;
  if (dch == 0x00a4) return cast(char)0xfd;
  if (dch == 0x00b0) return cast(char)0xf8;
  if (dch == 0x00b7) return cast(char)0xfa;
  if (dch == 0x0401) return cast(char)0xf0;
  if (dch == 0x0404) return cast(char)0xf2;
  if (dch == 0x0407) return cast(char)0xf4;
  if (dch == 0x040e) return cast(char)0xf6;
  if (dch >= 0x0410 && dch <= 0x044f) {
    static immutable char[64] ctbl0 = [
      0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f,
      0x90,0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0x9b,0x9c,0x9d,0x9e,0x9f,
      0xa0,0xa1,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0xad,0xae,0xaf,
      0xe0,0xe1,0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xeb,0xec,0xed,0xee,0xef,
    ];
    return ctbl0.ptr[cast(uint)dch-1040];
  }
  if (dch == 0x0451) return cast(char)0xf1;
  if (dch == 0x0454) return cast(char)0xf3;
  if (dch == 0x0457) return cast(char)0xf5;
  if (dch == 0x045e) return cast(char)0xf7;
  if (dch == 0x2116) return cast(char)0xfc;
  if (dch == 0x2219) return cast(char)0xf9;
  if (dch == 0x221a) return cast(char)0xfb;
  if (dch == 0x2500) return cast(char)0xc4;
  if (dch == 0x2502) return cast(char)0xb3;
  if (dch == 0x250c) return cast(char)0xda;
  if (dch == 0x2510) return cast(char)0xbf;
  if (dch == 0x2514) return cast(char)0xc0;
  if (dch == 0x2518) return cast(char)0xd9;
  if (dch == 0x251c) return cast(char)0xc3;
  if (dch == 0x2524) return cast(char)0xb4;
  if (dch == 0x252c) return cast(char)0xc2;
  if (dch == 0x2534) return cast(char)0xc1;
  if (dch == 0x253c) return cast(char)0xc5;
  if (dch >= 0x2550 && dch <= 0x256c) {
    static immutable char[29] ctbl1 = [
      0xcd,0xba,0xd5,0xd6,0xc9,0xb8,0xb7,0xbb,0xd4,0xd3,0xc8,0xbe,0xbd,0xbc,0xc6,0xc7,
      0xcc,0xb5,0xb6,0xb9,0xd1,0xd2,0xcb,0xcf,0xd0,0xca,0xd8,0xd7,0xce,
    ];
    return ctbl1.ptr[cast(uint)dch-9552];
  }
  if (dch == 0x2580) return cast(char)0xdf;
  if (dch == 0x2584) return cast(char)0xdc;
  if (dch == 0x2588) return cast(char)0xdb;
  if (dch == 0x258c) return cast(char)0xdd;
  if (dch >= 0x2590 && dch <= 0x2593) {
    static immutable char[4] ctbl2 = [0xde,0xb0,0xb1,0xb2,];
    return ctbl2.ptr[cast(uint)dch-9616];
  }
  if (dch == 0x25a0) return cast(char)0xfe;
  return repchar;
}


// ////////////////////////////////////////////////////////////////////////// //
/// `strlen()` for utf-8 string
public usize utflen (const(char)[] s) nothrow @trusted @nogc {
  Utf8DecoderFast dc;
  int res = 0;
  foreach (char ch; s) if (dc.decode(cast(ubyte)ch)) ++res;
  return res;
}


/// remove last character from utf-8 string
public T utfchop(T : const(char)[]) (T s) nothrow @trusted @nogc {
  Utf8DecoderFast dc;
  int last = 0;
  foreach (immutable idx, char ch; s) if (dc.decode(cast(ubyte)ch)) last = cast(int)idx;
  return s[0..last];
}


/// skip first `len` characters in utf-8 string
public T utfskip(T : const(char)[]) (T s, ptrdiff_t len) nothrow @trusted @nogc {
  if (len < 1) return s;
  if (len >= s.length) return null;
  Utf8DecoderFast dc;
  foreach (immutable idx, char ch; s) {
    if (dc.decode(cast(ubyte)ch)) {
      if (--len == 0) return s[idx+1..$];
    }
  }
  return null;
}


/// take first `len` characters in utf-8 string
public T utfleft(T : const(char)[]) (T s, ptrdiff_t len) nothrow @trusted @nogc {
  if (len < 1) return null;
  if (len >= s.length) return s;
  Utf8DecoderFast dc;
  foreach (immutable idx, char ch; s) {
    if (dc.decode(cast(ubyte)ch)) {
      if (--len == 0) return s[0..idx+1];
    }
  }
  return s;
}


/// take last `len` characters in utf-8 string (slow!)
public T utfright(T : const(char)[]) (T s, ptrdiff_t len) nothrow @trusted @nogc {
  if (len < 1) return null;
  if (len >= s.length) return s;
  auto fulllen = s.utflen;
  if (len >= fulllen) return s;
  Utf8DecoderFast dc;
  foreach (immutable idx, char ch; s) {
    if (dc.decode(cast(ubyte)ch)) {
      if (--fulllen == len) return s[idx+1..$];
    }
  }
  return null;
}


/// take `len` characters from position `pos` in utf-8 string (slow!)
public T utfmid(T : const(char)[]) (T s, ptrdiff_t pos, ptrdiff_t len) nothrow @trusted @nogc {
  if (len < 1 || pos >= s.length) return null;
  Utf8DecoderFast dc;
  int ds = -1, de = -1;
  if (pos == 0) ds = 0;
  foreach (immutable idx, char ch; s) {
    if (dc.decode(cast(ubyte)ch)) {
      if (ds < 0) {
        if (pos > 0) --pos; else ++pos;
        if (pos == 0) ds = cast(int)idx+1;
      } else if (de < 0) {
        if (--len == 0) { de = cast(int)idx+1; break; }
      } else {
        assert(0, "wtf?!");
      }
    }
  }
  if (ds < 0) return null;
  if (de < 0) return s[ds..$];
  return s[ds..de];
}


/// remove `len` characters from position `pos` in utf-8 string (slow!)
/// NOT REALLY TESTED!
public T utfdel(T : const(char)[]) (T s, ptrdiff_t pos, ptrdiff_t len) {
  static if (is(T == typeof(null))) {
    return null;
  } else {
    if (len < 1 || pos >= s.length) return s;
    Utf8DecoderFast dc;
    int ds = -1, de = -1;
    if (pos == 0) ds = 0;
    foreach (immutable idx, char ch; s) {
      if (dc.decode(cast(ubyte)ch)) {
        if (ds < 0) {
          if (pos > 0) --pos; else ++pos;
          if (pos == 0) ds = cast(int)idx+1;
        } else if (de < 0) {
          if (--len == 0) { de = cast(int)idx+1; break; }
        } else {
          assert(0, "wtf?!");
        }
      }
    }
    if (ds < 0) return s;
    if (de < 0) return s[0..ds];
    static if (is(T : char[])) {
      return s[0..ds]~s[de..$];
    } else {
      char[] res = s[0..ds].dup;
      res ~= s[de..$];
      return cast(T)res; // it is safe to cast here
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public T utfChopToSize(T:const(char)[]) (T s, int maxsize=255) nothrow @trusted {
  static if (is(T == typeof(null))) {
    return s;
  } else {
    if (maxsize < 1) return null;
    if (s.length <= maxsize) return s;
    // this is slow, but i don't care
    while (s.length > maxsize) s = s.utfchop;
    // add "..."
    if (maxsize > 3) {
      while (s.length > maxsize-3) s = s.utfchop;
      static if (is(T == const(char)[])) {
        return cast(T)(s.dup~"...");
      } else {
        return cast(T)(s~"...");
      }
    }
    return s;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// various one-byte encoding things, 'cause why not?


// ////////////////////////////////////////////////////////////////////////// //
public immutable char[256] koi8from866Table = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\xe1','\xe2','\xf7','\xe7','\xe4','\xe5','\xf6','\xfa','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef','\xf0',
  '\xf2','\xf3','\xf4','\xf5','\xe6','\xe8','\xe3','\xfe','\xfb','\xfd','\xff','\xf9','\xf8','\xfc','\xe0','\xf1',
  '\xc1','\xc2','\xd7','\xc7','\xc4','\xc5','\xd6','\xda','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf','\xd0',
  '\x90','\x91','\x92','\x81','\x87','\xb2','\x3f','\x3f','\x3f','\xb5','\xa1','\xa8','\xae','\x3f','\xac','\x83',
  '\x84','\x89','\x88','\x86','\x80','\x8a','\xaf','\xb0','\xab','\xa5','\xbb','\xb8','\xb1','\xa0','\xbe','\xb9',
  '\xba','\x3f','\x3f','\xaa','\xa9','\xa2','\x3f','\x3f','\xbc','\x85','\x82','\x8d','\x8c','\x8e','\x8f','\x8b',
  '\xd2','\xd3','\xd4','\xd5','\xc6','\xc8','\xc3','\xde','\xdb','\xdd','\xdf','\xd9','\xd8','\xdc','\xc0','\xd1',
  '\xb3','\xa3','\xb4','\xa4','\xb7','\xa7','\x3f','\x3f','\x9c','\x95','\x9e','\x96','\x3f','\x3f','\x94','\x9a',
];

public immutable char[256] koi8from1251Table = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f',
  '\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f',
  '\x9a','\x3f','\x3f','\x3f','\x3f','\xbd','\x3f','\x3f','\xb3','\xbf','\xb4','\x3f','\x3f','\x3f','\x3f','\xb7',
  '\x9c','\x3f','\xb6','\xa6','\xad','\x3f','\x3f','\x9e','\xa3','\x3f','\xa4','\x3f','\x3f','\x3f','\x3f','\xa7',
  '\xe1','\xe2','\xf7','\xe7','\xe4','\xe5','\xf6','\xfa','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef','\xf0',
  '\xf2','\xf3','\xf4','\xf5','\xe6','\xe8','\xe3','\xfe','\xfb','\xfd','\xff','\xf9','\xf8','\xfc','\xe0','\xf1',
  '\xc1','\xc2','\xd7','\xc7','\xc4','\xc5','\xd6','\xda','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf','\xd0',
  '\xd2','\xd3','\xd4','\xd5','\xc6','\xc8','\xc3','\xde','\xdb','\xdd','\xdf','\xd9','\xd8','\xdc','\xc0','\xd1',
];

// char toupper/tolower, koi8
public immutable char[256] koi8tolowerTable = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\x80','\x81','\x82','\x83','\x84','\x85','\x86','\x87','\x88','\x89','\x8a','\x8b','\x8c','\x8d','\x8e','\x8f',
  '\x90','\x91','\x92','\x93','\x94','\x95','\x96','\x97','\x98','\x99','\x9a','\x9b','\x9c','\x9d','\x9e','\x9f',
  '\xa0','\xa1','\xa2','\xa3','\xa4','\xa5','\xa6','\xa7','\xa8','\xa9','\xaa','\xab','\xac','\xad','\xae','\xaf',
  '\xb0','\xb1','\xb2','\xa3','\xa4','\xb5','\xa6','\xa7','\xb8','\xb9','\xba','\xbb','\xbc','\xad','\xbe','\xbf',
  '\xc0','\xc1','\xc2','\xc3','\xc4','\xc5','\xc6','\xc7','\xc8','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf',
  '\xd0','\xd1','\xd2','\xd3','\xd4','\xd5','\xd6','\xd7','\xd8','\xd9','\xda','\xdb','\xdc','\xdd','\xde','\xdf',
  '\xc0','\xc1','\xc2','\xc3','\xc4','\xc5','\xc6','\xc7','\xc8','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf',
  '\xd0','\xd1','\xd2','\xd3','\xd4','\xd5','\xd6','\xd7','\xd8','\xd9','\xda','\xdb','\xdc','\xdd','\xde','\xdf',
];

public immutable char[256] koi8toupperTable = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\x80','\x81','\x82','\x83','\x84','\x85','\x86','\x87','\x88','\x89','\x8a','\x8b','\x8c','\x8d','\x8e','\x8f',
  '\x90','\x91','\x92','\x93','\x94','\x95','\x96','\x97','\x98','\x99','\x9a','\x9b','\x9c','\x9d','\x9e','\x9f',
  '\xa0','\xa1','\xa2','\xb3','\xb4','\xa5','\xb6','\xb7','\xa8','\xa9','\xaa','\xab','\xac','\xbd','\xae','\xaf',
  '\xb0','\xb1','\xb2','\xb3','\xb4','\xb5','\xb6','\xb7','\xb8','\xb9','\xba','\xbb','\xbc','\xbd','\xbe','\xbf',
  '\xe0','\xe1','\xe2','\xe3','\xe4','\xe5','\xe6','\xe7','\xe8','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef',
  '\xf0','\xf1','\xf2','\xf3','\xf4','\xf5','\xf6','\xf7','\xf8','\xf9','\xfa','\xfb','\xfc','\xfd','\xfe','\xff',
  '\xe0','\xe1','\xe2','\xe3','\xe4','\xe5','\xe6','\xe7','\xe8','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef',
  '\xf0','\xf1','\xf2','\xf3','\xf4','\xf5','\xf6','\xf7','\xf8','\xf9','\xfa','\xfb','\xfc','\xfd','\xfe','\xff',
];

public immutable ubyte[32] koi8alphaTable = [
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0xff,0xff,0x07,0xfe,0xff,0xff,0x07,
  0x00,0x00,0x00,0x00,0xd8,0x20,0xd8,0x20,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
];

public char koi8lower (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return koi8tolowerTable.ptr[cast(int)ch];
}

public char koi8upper (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return koi8toupperTable.ptr[cast(int)ch];
}

public bool koi8isAlpha (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return ((koi8alphaTable.ptr[ch/8]&(1<<(ch%8))) != 0);
}
