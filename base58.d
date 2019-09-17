/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// BASE58 codec; because i can!
module iv.base58 /*is aliced*/;
private:
import iv.alice;


// all alphanumeric characters except for "0", "I", "O", and "l"
static immutable string base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
static immutable ubyte[256] b58idx = () {
  ubyte[256] res = 255;
  foreach (immutable idx, immutable char ch; base58Alphabet) res[ch] = cast(ubyte)idx;
  return res;
}();


public struct Base58Decoder {
private:
  ubyte[2048] b256 = 0; // int size = cast(int)(buf.length)*733/1000+1; // log(58) / log(256), rounded up
  uint zeroes = 0; // bit 31 set: done zero counting; 0xffff_ffffU is error

public:
  void clear () nothrow @trusted @nogc { pragma(inline, true); this = this.init; }

  @property bool error () const nothrow @trusted @nogc { pragma(inline, true); return (zeroes == 0xffff_ffffU); }

  bool put (const(char)[] buf...) nothrow @trusted @nogc {
    if (error) return false;
    foreach (immutable char ch; buf) {
      // counting zeroes?
      if (zeroes < 0x8000_0000U) {
        if (ch == '1') {
          if (++zeroes == 0x0fff_ffffU) { zeroes = 0xffff_ffffU; return false; }
          continue;
        }
        zeroes |= 0x8000_0000U;
      }
      // ok, this should be a valid char
      int carry = b58idx.ptr[cast(ubyte)ch];
      if (carry > 57) { zeroes = 0xffff_ffffU; return false; }
      foreach_reverse (ref ubyte vb; b256[]) {
        carry += 58*vb;
        vb = carry&0xff;
        carry /= 256;
        if (carry == 0 && vb == 0) break;
      }
      if (carry != 0) { zeroes = 0xffff_ffffU; return false; }
    }
    return true;
  }

  uint length () const nothrow @trusted @nogc {
    if (!error) {
      uint bpos = 0;
      while (bpos < b256.length && b256.ptr[bpos] == 0) ++bpos;
      return cast(uint)(b256.length)-bpos+(zeroes&0x7fff_ffffU);
    } else {
      return 0;
    }
  }

  @property uint getZeroes () const nothrow @trusted @nogc { pragma(inline, true); return (zeroes == 0xffff_ffffU ? 0 : zeroes&0x7fff_ffffU); }

  const(ubyte)[] getBuf () const nothrow @trusted @nogc {
    if (error) return null;
    uint bpos = 0;
    while (bpos < b256.length && b256.ptr[bpos] == 0) ++bpos;
    uint xlen = cast(uint)(b256.length)-bpos;
    return b256[0..xlen];
  }

  // return slice of the resuling buffer or `null` if there is no room in `dest`
  ubyte[] get (ubyte[] dest) const nothrow @trusted @nogc {
    if (error) return null;
    uint bpos = 0;
    while (bpos < b256.length && b256.ptr[bpos] == 0) ++bpos;
    uint xlen = cast(uint)(b256.length)-bpos+(zeroes&0x7fff_ffffU);
    if (dest.length < xlen) return null;
    auto res = dest[0..xlen];
    res[0..(zeroes&0x7fff_ffffU)] = 0;
    res[(zeroes&0x7fff_ffffU)..$] = b256[bpos..$];
    return res;
  }

  // allocate resuling buffer
  ubyte[] get () const nothrow @trusted {
    if (error) return null;
    auto res = new ubyte[](length);
    auto rx = get(res);
    if (rx is null) { delete res; return null; }
    return res;
  }
}


public struct Base58Encoder {
private:
  ubyte[2048] b58 = 0; // int size = cast(int)(buf.length)*138/100+1; // log(256) / log(58), rounded up
  uint zeroes = 0; // bit 31 set: done zero counting; 0xffff_ffffU is error

public:
  void clear () nothrow @trusted @nogc { pragma(inline, true); this = this.init; }

  @property bool error () const nothrow @trusted @nogc { pragma(inline, true); return (zeroes == 0xffff_ffffU); }

  bool put (const(ubyte)[] buf...) nothrow @trusted @nogc {
    if (error) return false;
    foreach (immutable ubyte b; buf) {
      // counting zeroes?
      if (zeroes < 0x8000_0000U) {
        if (b == 0) {
          if (++zeroes == 0x0fff_ffffU) { zeroes = 0xffff_ffffU; return false; }
          continue;
        }
        zeroes |= 0x8000_0000U;
      }
      // ok, this should be a valid char
      int carry = b;
      foreach_reverse (immutable idx, ref ubyte vb; b58[]) {
        carry += 256*vb;
        vb = cast(ubyte)(carry%58);
        carry /= 58;
        if (carry == 0 && vb == 0) break;
      }
      if (carry != 0) { zeroes = 0xffff_ffffU; return false; }
    }
    return true;
  }

  uint length () const nothrow @trusted @nogc {
    if (!error) {
      uint bpos = 0;
      while (bpos < b58.length && b58.ptr[bpos] == 0) ++bpos;
      return cast(uint)(b58.length)-bpos+(zeroes&0x7fff_ffffU);
    } else {
      return 0;
    }
  }

  // allocate resuling buffer
  char[] get (char[] dest) const nothrow @trusted @nogc {
    if (error) return null;
    uint bpos = 0;
    while (bpos < b58.length && b58.ptr[bpos] == 0) ++bpos;
    uint xlen = cast(uint)(b58.length)-bpos+(zeroes&0x7fff_ffffU);
    if (dest.length < xlen) return null;
    auto res = dest[0..xlen];
    res[0..(zeroes&0x7fff_ffffU)] = '1';
    foreach (ref char rc; res) {
      assert(bpos < b58.length);
      assert(b58.ptr[bpos] < 58);
      rc = base58Alphabet.ptr[b58.ptr[bpos++]];
    }
    return res;
  }

  // allocate resuling buffer
  char[] get () const nothrow @trusted {
    if (error) return null;
    auto res = new char[](length);
    auto rx = get(res);
    if (rx is null) { delete res; return null; }
    return res;
  }
}


public ubyte[] base58Decode (const(void)[] vbuf) {
  Base58Decoder dc;
  foreach (immutable char ch; cast(const(char)[])vbuf) if (!dc.put(ch)) return null;
  return dc.get();
}


public char[] base58Encode (const(void)[] vbuf) {
  Base58Encoder ec;
  foreach (immutable ubyte ch; cast(const(ubyte)[])vbuf) if (!ec.put(ch)) return null;
  return ec.get();
}


public char[] base58EncodeCheck() (ubyte prefixbyte, const(void)[] data) {
  import std.digest.sha : SHA256, sha256Of;
  SHA256 hasher;
  hasher.start();
  hasher.put(prefixbyte);
  hasher.put(cast(const(ubyte)[])data);
  auto hash1 = hasher.finish();
  scope(exit) hash1[] = 0;
  auto hash2 = sha256Of(hash1[]);
  scope(exit) hash2[] = 0;
  Base58Encoder ec;
  if (!ec.put(prefixbyte)) return null;
  foreach (immutable ubyte b; cast(const(ubyte)[])data) if (!ec.put(b)) return null;
  foreach (immutable ubyte b; hash2[0..4]) if (!ec.put(b)) return null;
  return ec.get();
}


public ubyte[] base58DecodeCheck() (const(void)[] data) {
  import std.digest.sha : SHA256, sha256Of;
  Base58Decoder dc;
  foreach (immutable char ch; cast(const(char)[])data) if (!dc.put(ch)) return null;
  if (dc.length < 5) return null;
  auto res = dc.get();
  SHA256 hasher;
  hasher.start();
  hasher.put(res[0..$-4]);
  auto hash1 = hasher.finish();
  scope(exit) hash1[] = 0;
  auto hash2 = sha256Of(hash1[]);
  scope(exit) hash2[] = 0;
  if (hash2[0..4] != res[$-4..$]) { res[] = 0; delete res; }
  res[$-4..$] = 0;
  return res[0..$-4];
}
