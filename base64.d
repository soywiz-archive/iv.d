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
// BASE64 codec; because i can!
module iv.base64 is aliced;


// ////////////////////////////////////////////////////////////////////////// //
mixin(NewExceptionClass!"Base64Exception");


// ////////////////////////////////////////////////////////////////////////// //
public static immutable string b64alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

private static immutable ubyte[256] b64dc = () {
  ubyte[256] res = 0xff; // invalid
  foreach (immutable idx, immutable char ch; b64alphabet) {
    res[cast(ubyte)ch] = cast(ubyte)idx;
  }
  res['='] = 0xfe; // padding
  // ignore
  res[8..14] = 0xf0;
  res[32] = 0xf0;
  res[127] = 0xf0; // just in case
  return res;
}();


// ////////////////////////////////////////////////////////////////////////// //
public void base64Encode(bool padding=true, RO, RI) (auto ref RO ro, auto ref RI ri)
if (Imp!"std.range.primitives".isInputRange!RI && is(Imp!"std.range.primitives".ElementEncodingType!RI : ubyte) &&
    (Imp!"std.range.primitives".isOutputRange!(RO, char) || Imp!"std.range.primitives".isOutputRange!(RO, ubyte))
   )
{
  ubyte[3] bts;
  uint btspos;

  void encodeChunk() () {
    if (btspos == 0) return;
    ro.put(b64alphabet.ptr[(bts.ptr[0]&0xfc)>>2]);
    if (btspos == 1) {
      ro.put(b64alphabet.ptr[(bts.ptr[0]&0x03)<<4]);
      static if (padding) { ro.put('='); ro.put('='); }
    } else {
      // 2 or more
      ro.put(b64alphabet.ptr[((bts.ptr[0]&0x03)<<4)|((bts.ptr[1]&0xf0)>>4)]);
      if (btspos == 2) {
        ro.put(b64alphabet.ptr[(bts.ptr[1]&0x0f)<<2]);
        static if (padding) ro.put('=');
      } else {
        // 3 bytes
        ro.put(b64alphabet.ptr[((bts.ptr[1]&0x0f)<<2)|((bts.ptr[2]&0xc0)>>6)]);
        ro.put(b64alphabet.ptr[bts.ptr[2]&0x3f]);
      }
    }
    btspos = 0;
  }

  while (!ri.empty) {
    ubyte ib = cast(ubyte)ri.front;
    ri.popFront();
    bts.ptr[btspos++] = ib;
    if (btspos == 3) encodeChunk();
  }
  if (btspos != 0) encodeChunk();
}

public OT[] base64Encode(OT=ubyte, bool padding=true, RI) (auto ref RI ri)
if (!is(RI : AE[], AE) &&
    Imp!"std.range.primitives".isInputRange!RI && is(Imp!"std.range.primitives".ElementEncodingType!RI : ubyte) &&
    (is(OT == ubyte) || is(OT == char))
   )
{
  static struct OutRange {
    OT[] res;
    void put (const(OT)[] b...) nothrow @trusted { if (b.length) res ~= b[]; }
  }
  OutRange ro;
  base64Encode!padding(ro, ri);
  return ro.res;
}

public OT[] base64Encode(OT=ubyte, bool padding=true) (const(void)[] buf) if (is(OT == ubyte) || is(OT == char)) {
  static struct InRange {
    const(ubyte)[] data;
  pure nothrow @trusted @nogc:
    @property bool empty () const { pragma(inline, true); return (data.length == 0); }
    @property ubyte front () const { pragma(inline, true); return data.ptr[0]; }
    void popFront () { data = data[1..$]; }
  }
  static struct OutRange {
    OT[] res;
    void put (const(OT)[] b...) nothrow @trusted { if (b.length) res ~= b[]; }
  }
  auto ri = InRange(cast(const(ubyte)[])buf);
  OutRange ro;
  base64Encode!padding(ro, ri);
  return ro.res;
}


// ////////////////////////////////////////////////////////////////////////// //
public void base64Decode(RO, RI) (auto ref RO ro, auto ref RI ri)
if (Imp!"std.range.primitives".isInputRange!RI && is(Imp!"std.range.primitives".ElementEncodingType!RI : dchar) &&
    (Imp!"std.range.primitives".isOutputRange!(RO, char) || Imp!"std.range.primitives".isOutputRange!(RO, ubyte))
   )
{
  bool inPadding = false;
  ubyte[4] bts;
  uint btspos;

  void decodeChunk() () {
    if (btspos == 0) return;
    if (btspos == 1) throw new Base64Exception("incomplete data in base64 decoder");
    ro.put(cast(char)((bts.ptr[0]<<2)|((bts.ptr[1]&0x30)>>4))); // 2 and more
    if (btspos > 2) ro.put(cast(char)(((bts.ptr[1]&0x0f)<<4)|((bts.ptr[2]&0x3c)>>2))); // 3 and more
    if (btspos > 3) ro.put(cast(char)(((bts.ptr[2]&0x03)<<6)|bts.ptr[3]));
  }

  while (!ri.empty) {
    static if (is(typeof(ri.front) : char)) {
      ubyte cb = b64dc.ptr[cast(ubyte)ri.front];
    } else {
      auto ccw = ri.front;
      ubyte cb = (ccw >= 0 && ccw <= 255 ? b64dc.ptr[cast(ubyte)ccw] : 0xff);
    }
    if (cb == 0xff) throw new Base64Exception("invalid input char in base64 decoder");
    ri.popFront();
    if (cb == 0xf0) continue; // empty
    if (cb == 0xfe) {
      // padding
      if (!inPadding) { decodeChunk(); inPadding = true; }
      if (++btspos == 4) { inPadding = false; btspos = 0; }
    } else {
      // normal
      if (inPadding) {
        if (btspos != 0) throw new Base64Exception("invalid input char in base64 decoder");
        inPadding = false;
      }
      bts.ptr[btspos++] = cb;
      if (btspos == 4) { decodeChunk(); btspos = 0; }
    }
  }
  if (btspos != 0 && !inPadding) decodeChunk(); // assume that it is not padded
}

public OT[] base64Decode(OT=ubyte, RI) (auto ref RI ri)
if (!is(RI : AE[], AE) &&
    Imp!"std.range.primitives".isInputRange!RI && is(Imp!"std.range.primitives".ElementEncodingType!RI : dchar) &&
    (is(OT == ubyte) || is(OT == char))
   )
{
  static struct OutRange {
    OT[] res;
    void put (const(OT)[] b...) nothrow @trusted { if (b.length) res ~= b[]; }
  }
  OutRange ro;
  base64Decode(ro, ri);
  return ro.res;
}

public OT[] base64Decode(OT=ubyte) (const(void)[] buf) if (is(OT == ubyte) || is(OT == char)) {
  static struct InRange {
    const(ubyte)[] data;
  pure nothrow @trusted @nogc:
    @property bool empty () const { pragma(inline, true); return (data.length == 0); }
    @property ubyte front () const { pragma(inline, true); return data.ptr[0]; }
    void popFront () { data = data[1..$]; }
  }
  static struct OutRange {
    OT[] res;
    void put (const(OT)[] b...) nothrow @trusted { if (b.length) res ~= b[]; }
  }
  auto ri = InRange(cast(const(ubyte)[])buf);
  OutRange ro;
  base64Decode(ro, ri);
  return ro.res;
}


// ////////////////////////////////////////////////////////////////////////// //
version(iv_base64_test) {
import iv.cmdcon;
void main () {
  conwriteln(base64Decode!char("Zm\r9 vY\tmF\ny\n"), "|");
  conwriteln(base64Decode!char("Zg=="), "|");
  conwriteln(base64Decode!char("Zg"), "|");
  conwriteln(base64Decode!char("Zm8="), "|");
  conwriteln(base64Decode!char("Zm8"), "|");
  conwriteln(base64Decode!char("Zm9v"), "|");
  conwriteln(base64Decode!char("Zm9vYg=="), "|");
  conwriteln(base64Decode!char("Zm9vYg="), "|");
  conwriteln(base64Decode!char("Zm9vYg"), "|");
  conwriteln(base64Decode!char("Zm9vYmE="), "|");
  conwriteln(base64Decode!char("Zm9vYmE"), "|");
  conwriteln(base64Decode!char("Zm9vYmFy"), "|");
  conwriteln(base64Decode!char("Zm9vYmFy==="), "|");
  conwriteln("==================");
  conwriteln(base64Encode!char(""));
  conwriteln(base64Encode!char("f"));
  conwriteln(base64Encode!char("fo"));
  conwriteln(base64Encode!char("foo"));
  conwriteln(base64Encode!char("foob"));
  conwriteln(base64Encode!char("fooba"));
  conwriteln(base64Encode!char("foobar"));
}
}
