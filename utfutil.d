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
module iv.utfutil;


// ////////////////////////////////////////////////////////////////////////// //
struct Utf8DecoderFast {
public:
  enum dchar replacement = '\uFFFD';
  static bool isValidDC (dchar c) pure nothrow @safe @nogc { pragma(inline, true); return (c < 0xD800 || (c > 0xDFFF && c <= 0x10FFFF)); }

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

nothrow @safe @nogc:
public:
  uint state;
  dchar codepoint = 0;

  // is current character complete? take `codepoint` then
  @property bool complete () const pure { pragma(inline, true); return (state == State.Accept); }
  @property bool invalid () const pure { pragma(inline, true); return (state == State.Reject); }
  @property bool completeOrInvalid () const pure { pragma(inline, true); return (state == State.Accept || state == State.Reject); }
  void reset () pure { pragma(inline, true); state = State.Accept; codepoint = 0; }
  // process one byte, return `true` if codepoint is ready
  bool decode (ubyte b) pure @trusted {
    if (state == State.Reject) { state = 0; codepoint = 0; }
    uint type = utf8dfa.ptr[b];
    codepoint = (state != State.Accept ? (b&0x3fu)|(codepoint<<6) : (0xff>>type)&b);
    state = utf8dfa.ptr[256+state+type];
    return (state == State.Accept);
  }
  // same as `decode`, but caller is guaranteed that decoder will never get invalid utf-8 sequence
  bool decodeValid (ubyte b) pure @trusted {
    uint type = utf8dfa.ptr[b];
    codepoint = (state != State.Accept ? (b&0x3fu)|(codepoint<<6) : (0xff>>type)&b);
    state = utf8dfa.ptr[256+state+type];
    return (state == State.Accept);
  }
  // same as `decode`, never reaches `invalid` state, returns `replacement` for invalid chars
  bool decodeSafe (ubyte b) pure @trusted {
    uint type = utf8dfa.ptr[b];
    codepoint = (state != State.Accept ? (b&0x3f)|(codepoint<<6) : (0xff>>type)&b);
    if ((state = utf8dfa.ptr[256+state+type]) == State.Reject) { state = State.Accept; codepoint = replacement; }
    return (state == State.Accept);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// slow, but using only 4 bytes (dchar)
struct Utf8Decoder {
public:
  enum dchar replacement = '\uFFFD';
  static bool isValidDC (dchar c) pure nothrow @safe @nogc { pragma(inline, true); return (c < 0xD800 || (c > 0xDFFF && c <= 0x10FFFF)); }

private:
  enum State : uint {
    Accept = 0x0000_0000u,
    Reject = 0x0c00_0000u,
    Mask = 0xff00_0000u
  }
  uint codep = State.Accept;
pure nothrow @safe @nogc:
public:
  // is current character complete? take `codepoint` then
  @property bool complete () const { pragma(inline, true); return ((codep&State.Mask) == State.Accept); }
  @property bool invalid () const { pragma(inline, true); return ((codep&State.Mask) == State.Reject); }
  @property bool completeOrInvalid () const { pragma(inline, true); return (complete || invalid); }
  @property dchar currCodePoint () const { pragma(inline, true); return (codep <= dchar.max ? codep : replacement); }
  // same as `decode`, never reaches `invalid` state, returns `replacement` for invalid chars
  // returns invalid dchar while it is "in progress" (i.e. result > dchar.max)
  void reset () { codep = State.Accept; }
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
// returns -1 on error (out of room in `s`, for example), or bytes taken
int utf8Encode(dchar replacement='\uFFFD') (char[] s, dchar c) pure nothrow @trusted @nogc {
  static assert(Utf8Decoder.isValidDC(replacement), "invalid replacement char");
  if (!Utf8Decoder.isValidDC(c)) c = replacement;
  if (c <= 0x7F) {
    if (s.length < 1) return -1;
    s.ptr[0] = cast(char)c;
    return 1;
  } else {
    char[4] buf;
    ubyte len;
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
      assert(0, "wtf?!");
    }
    if (s.length < len) return -1;
    s[0..len] = buf[0..len];
    return len;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// doesn't do all possible checks, so don't pass invalid UTF-8
size_t utf8Length (const(char)[] s) pure nothrow @trusted @nogc {
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
  size_t pos = 0, res = 0;
  while (pos < s.length) {
    ubyte l = UTF8stride.ptr[s.ptr[pos++]];
    if (l == 0xFF) l = 1;
    res += l;
    pos += (l-1);
  }
  return res;
}
