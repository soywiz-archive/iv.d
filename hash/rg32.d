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
module iv.hash.rg32 /*is aliced*/;
// RadioGatun[32] hash function, based on the code by Sam Trenholme


/// RadioGatun[32] hash function
public struct RG32Hash {
public:
  enum ByteSize = 32; // 32 bytes (aka 256 bits, if you cannot do the math)

private:
  ubyte[12] buf;
  uint[19] a; // mill
  uint[39] b; // belt
  uint bufused;
  uint o, hasdata;

public:
nothrow @trusted @nogc:
  /// reset state
  void reset () pure { buf[] = 0; a[] = 0; b[] = 0; bufused = 0; o = 0; hasdata = 0; }

  /// process data block
  void put(T) (scope const(T)[] data...) if (T.sizeof == 1) {
    if (data.length == 0) return; // nothing to do
    hasdata = 1;
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    while (len > 0) {
      while (bufused < 12 && len > 0) {
        buf.ptr[bufused++] = *bytes++;
        --len;
      }
      if (bufused == 12) { processBuf(); bufused = 0; }
    }
  }

  /// finalize a hash (i.e. return current result).
  /// note that you can continue putting data, as this is not destructive
  ubyte[ByteSize] finish () {
    if (!hasdata || bufused) processBuf();
    // end injection
    foreach (immutable uint c; 0..16) {
      rground(a.ptr, b.ptr, o);
      o += 1;
      if (o > 12) o=0;
    }
    ubyte[ByteSize] res = void;
    uint respos = 0;
    // end mangling
    foreach (immutable uint c; 0..4) {
      rground(a.ptr, b.ptr, o);
      o += 1;
      if (o > 12) o = 0;
      assert(respos < ByteSize && ByteSize-respos >= 8);
      res.ptr[respos++] = a.ptr[1]&0xff;
      res.ptr[respos++] = (a.ptr[1]>>8)&0xff;
      res.ptr[respos++] = (a.ptr[1]>>16)&0xff;
      res.ptr[respos++] = (a.ptr[1]>>24)&0xff;
      res.ptr[respos++] = a.ptr[2]&0xff;
      res.ptr[respos++] = (a.ptr[2]>>8)&0xff;
      res.ptr[respos++] = (a.ptr[2]>>16)&0xff;
      res.ptr[respos++] = (a.ptr[2]>>24)&0xff;
    }
    reset();
    return res[];
  }

private:
  void processBuf () {
    if (bufused == 0) return;
    uint[3] p = 0;
    uint offset = 0;
    bool done = false;
    foreach (immutable uint r; 0..3) {
      foreach (immutable uint q; 0..4) {
        uint x = buf.ptr[offset];
        if (offset >= bufused) {
          done = true;
          /* Spec says this should have a value
           * of 0x80; reference code gives this
           * a value of 1.  This is IMHO a bug
           * in the reference code. */
          x = 1;
        }
        ++offset;
        p.ptr[r] |= x<<(q*8);
        if (done) {
          foreach (immutable uint c; 0..3) {
            uint w = 13-o;
            if (w == 13) w = 0;
            b.ptr[w+c*13] ^= p.ptr[c];
            a.ptr[16+c] ^= p.ptr[c];
          }
          rground(a.ptr, b.ptr, o);
          o += 1;
          if (o == 13) o = 0;
          return;
        }
      }
    }
    foreach (immutable uint c; 0..3) {
      uint w = 13-o;
      if (w == 13) w = 0;
      b.ptr[w+c*13] ^= p.ptr[c];
      a.ptr[16+c] ^= p.ptr[c];
    }
    rground(a.ptr, b.ptr, o);
    o += 1;
    if (o == 13) o = 0;
  }

static:
  void mill (uint* a) {
    uint[19] A = void;
    uint x;
    // the following is the output of the awk script "make.mill.core"
    x = a[0]^(a[1]|(~a[2]));
    A.ptr[0] = x;
    x = a[7]^(a[8]|(~a[9]));
    A.ptr[1] = (x>>1)|(x<<31);
    x = a[14]^(a[15]|(~a[16]));
    A.ptr[2] = (x>>3)|(x<<29);
    x = a[2]^(a[3]|(~a[4]));
    A.ptr[3] = (x>>6)|(x<<26);
    x = a[9]^(a[10]|(~a[11]));
    A.ptr[4] = (x>>10)|(x<<22);
    x = a[16]^(a[17]|(~a[18]));
    A.ptr[5] = (x>>15)|(x<<17);
    x = a[4]^(a[5]|(~a[6]));
    A.ptr[6] = (x>>21)|(x<<11);
    x = a[11]^(a[12]|(~a[13]));
    A.ptr[7] = (x>>28)|(x<<4);
    x = a[18]^(a[0]|(~a[1]));
    A.ptr[8] = (x>>4)|(x<<28);
    x = a[6]^(a[7]|(~a[8]));
    A.ptr[9] = (x>>13)|(x<<19);
    x = a[13]^(a[14]|(~a[15]));
    A.ptr[10] = (x>>23)|(x<<9);
    x = a[1]^(a[2]|(~a[3]));
    A.ptr[11] = (x>>2)|(x<<30);
    x = a[8]^(a[9]|(~a[10]));
    A.ptr[12] = (x>>14)|(x<<18);
    x = a[15]^(a[16]|(~a[17]));
    A.ptr[13] = (x>>27)|(x<<5);
    x = a[3]^(a[4]|(~a[5]));
    A.ptr[14] = (x>>9)|(x<<23);
    x = a[10]^(a[11]|(~a[12]));
    A.ptr[15] = (x>>24)|(x<<8);
    x = a[17]^(a[18]|(~a[0]));
    A.ptr[16] = (x>>8)|(x<<24);
    x = a[5]^(a[6]|(~a[7]));
    A.ptr[17] = (x>>25)|(x<<7);
    x = a[12]^(a[13]|(~a[14]));
    A.ptr[18] = (x>>11)|(x<<21);
    a[0] = A.ptr[0]^A.ptr[1]^A.ptr[4];
    a[1] = A.ptr[1]^A.ptr[2]^A.ptr[5];
    a[2] = A.ptr[2]^A.ptr[3]^A.ptr[6];
    a[3] = A.ptr[3]^A.ptr[4]^A.ptr[7];
    a[4] = A.ptr[4]^A.ptr[5]^A.ptr[8];
    a[5] = A.ptr[5]^A.ptr[6]^A.ptr[9];
    a[6] = A.ptr[6]^A.ptr[7]^A.ptr[10];
    a[7] = A.ptr[7]^A.ptr[8]^A.ptr[11];
    a[8] = A.ptr[8]^A.ptr[9]^A.ptr[12];
    a[9] = A.ptr[9]^A.ptr[10]^A.ptr[13];
    a[10] = A.ptr[10]^A.ptr[11]^A.ptr[14];
    a[11] = A.ptr[11]^A.ptr[12]^A.ptr[15];
    a[12] = A.ptr[12]^A.ptr[13]^A.ptr[16];
    a[13] = A.ptr[13]^A.ptr[14]^A.ptr[17];
    a[14] = A.ptr[14]^A.ptr[15]^A.ptr[18];
    a[15] = A.ptr[15]^A.ptr[16]^A.ptr[0];
    a[16] = A.ptr[16]^A.ptr[17]^A.ptr[1];
    a[17] = A.ptr[17]^A.ptr[18]^A.ptr[2];
    a[18] = A.ptr[18]^A.ptr[0]^A.ptr[3];
    a[0] ^= 1;
  }

  // the following is the output of "make.belt.core"
  void belt_00 (uint* a, uint *b) {
    uint q0 = b[12];
    uint q1 = b[25];
    uint q2 = b[38];
    b[0] ^= a[1];
    b[14] ^= a[2];
    b[28] ^= a[3];
    b[3] ^= a[4];
    b[17] ^= a[5];
    b[31] ^= a[6];
    b[6] ^= a[7];
    b[20] ^= a[8];
    b[34] ^= a[9];
    b[9] ^= a[10];
    b[23] ^= a[11];
    b[37] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_01 (uint* a, uint* b) {
    uint q0 = b[11];
    uint q1 = b[24];
    uint q2 = b[37];
    b[12] ^= a[1];
    b[13] ^= a[2];
    b[27] ^= a[3];
    b[2] ^= a[4];
    b[16] ^= a[5];
    b[30] ^= a[6];
    b[5] ^= a[7];
    b[19] ^= a[8];
    b[33] ^= a[9];
    b[8] ^= a[10];
    b[22] ^= a[11];
    b[36] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_02 (uint* a, uint* b) {
    uint q0 = b[10];
    uint q1 = b[23];
    uint q2 = b[36];
    b[11] ^= a[1];
    b[25] ^= a[2];
    b[26] ^= a[3];
    b[1] ^= a[4];
    b[15] ^= a[5];
    b[29] ^= a[6];
    b[4] ^= a[7];
    b[18] ^= a[8];
    b[32] ^= a[9];
    b[7] ^= a[10];
    b[21] ^= a[11];
    b[35] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_03 (uint* a, uint* b) {
    uint q0 = b[9];
    uint q1 = b[22];
    uint q2 = b[35];
    b[10] ^= a[1];
    b[24] ^= a[2];
    b[38] ^= a[3];
    b[0] ^= a[4];
    b[14] ^= a[5];
    b[28] ^= a[6];
    b[3] ^= a[7];
    b[17] ^= a[8];
    b[31] ^= a[9];
    b[6] ^= a[10];
    b[20] ^= a[11];
    b[34] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_04 (uint* a, uint* b) {
    uint q0 = b[8];
    uint q1 = b[21];
    uint q2 = b[34];
    b[9] ^= a[1];
    b[23] ^= a[2];
    b[37] ^= a[3];
    b[12] ^= a[4];
    b[13] ^= a[5];
    b[27] ^= a[6];
    b[2] ^= a[7];
    b[16] ^= a[8];
    b[30] ^= a[9];
    b[5] ^= a[10];
    b[19] ^= a[11];
    b[33] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_05 (uint* a, uint* b) {
    uint q0 = b[7];
    uint q1 = b[20];
    uint q2 = b[33];
    b[8] ^= a[1];
    b[22] ^= a[2];
    b[36] ^= a[3];
    b[11] ^= a[4];
    b[25] ^= a[5];
    b[26] ^= a[6];
    b[1] ^= a[7];
    b[15] ^= a[8];
    b[29] ^= a[9];
    b[4] ^= a[10];
    b[18] ^= a[11];
    b[32] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_06 (uint* a, uint* b) {
    uint q0 = b[6];
    uint q1 = b[19];
    uint q2 = b[32];
    b[7] ^= a[1];
    b[21] ^= a[2];
    b[35] ^= a[3];
    b[10] ^= a[4];
    b[24] ^= a[5];
    b[38] ^= a[6];
    b[0] ^= a[7];
    b[14] ^= a[8];
    b[28] ^= a[9];
    b[3] ^= a[10];
    b[17] ^= a[11];
    b[31] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_07 (uint* a, uint* b) {
    uint q0 = b[5];
    uint q1 = b[18];
    uint q2 = b[31];
    b[6] ^= a[1];
    b[20] ^= a[2];
    b[34] ^= a[3];
    b[9] ^= a[4];
    b[23] ^= a[5];
    b[37] ^= a[6];
    b[12] ^= a[7];
    b[13] ^= a[8];
    b[27] ^= a[9];
    b[2] ^= a[10];
    b[16] ^= a[11];
    b[30] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_08 (uint* a, uint* b) {
    uint q0 = b[4];
    uint q1 = b[17];
    uint q2 = b[30];
    b[5] ^= a[1];
    b[19] ^= a[2];
    b[33] ^= a[3];
    b[8] ^= a[4];
    b[22] ^= a[5];
    b[36] ^= a[6];
    b[11] ^= a[7];
    b[25] ^= a[8];
    b[26] ^= a[9];
    b[1] ^= a[10];
    b[15] ^= a[11];
    b[29] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_09 (uint* a, uint* b) {
    uint q0 = b[3];
    uint q1 = b[16];
    uint q2 = b[29];
    b[4] ^= a[1];
    b[18] ^= a[2];
    b[32] ^= a[3];
    b[7] ^= a[4];
    b[21] ^= a[5];
    b[35] ^= a[6];
    b[10] ^= a[7];
    b[24] ^= a[8];
    b[38] ^= a[9];
    b[0] ^= a[10];
    b[14] ^= a[11];
    b[28] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_10 (uint* a, uint* b) {
    uint q0 = b[2];
    uint q1 = b[15];
    uint q2 = b[28];
    b[3] ^= a[1];
    b[17] ^= a[2];
    b[31] ^= a[3];
    b[6] ^= a[4];
    b[20] ^= a[5];
    b[34] ^= a[6];
    b[9] ^= a[7];
    b[23] ^= a[8];
    b[37] ^= a[9];
    b[12] ^= a[10];
    b[13] ^= a[11];
    b[27] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_11 (uint* a, uint* b) {
    uint q0 = b[1];
    uint q1 = b[14];
    uint q2 = b[27];
    b[2] ^= a[1];
    b[16] ^= a[2];
    b[30] ^= a[3];
    b[5] ^= a[4];
    b[19] ^= a[5];
    b[33] ^= a[6];
    b[8] ^= a[7];
    b[22] ^= a[8];
    b[36] ^= a[9];
    b[11] ^= a[10];
    b[25] ^= a[11];
    b[26] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void belt_12 (uint* a, uint* b) {
    uint q0 = b[0];
    uint q1 = b[13];
    uint q2 = b[26];
    b[1] ^= a[1];
    b[15] ^= a[2];
    b[29] ^= a[3];
    b[4] ^= a[4];
    b[18] ^= a[5];
    b[32] ^= a[6];
    b[7] ^= a[7];
    b[21] ^= a[8];
    b[35] ^= a[9];
    b[10] ^= a[10];
    b[24] ^= a[11];
    b[38] ^= a[12];
    mill(a);
    a[13] ^= q0;
    a[14] ^= q1;
    a[15] ^= q2;
  }

  void rground (uint* a, uint* b, int offset) {
    final switch (offset) {
      case 0: belt_00(a, b); return;
      case 1: belt_01(a, b); return;
      case 2: belt_02(a, b); return;
      case 3: belt_03(a, b); return;
      case 4: belt_04(a, b); return;
      case 5: belt_05(a, b); return;
      case 6: belt_06(a, b); return;
      case 7: belt_07(a, b); return;
      case 8: belt_08(a, b); return;
      case 9: belt_09(a, b); return;
      case 10: belt_10(a, b); return;
      case 11: belt_11(a, b); return;
      case 12: belt_12(a, b); return;
    }
  }
}


ubyte[RG32Hash.ByteSize] RG32HashOf(T) (const(T)[] data) nothrow @trusted @nogc if (T.sizeof == 1) {
  RG32Hash h;
  h.put(data);
  return h.finish();
}


ubyte[RG32Hash.ByteSize] RG32HashOf(T) (const(T)[] data) nothrow @trusted @nogc if (T.sizeof > 1) {
  RG32Hash h;
  h.put((cast(const(ubyte)*)data.ptr)[0..data.length*T.sizeof]);
  return h.finish();
}


version(rg32_test) {
  enum xhash = RG32HashOf("Alice & Miriel");
  static assert(cast(string)xhash == x"ebcd82ad5b21cc5ac6ca1f707faad10fe047963aa9e5cb35150a8bf2120bee4a");
}


version(rg32_test) void main () {
  static immutable string xres = x"ebcd82ad5b21cc5ac6ca1f707faad10fe047963aa9e5cb35150a8bf2120bee4a";
  auto hash = RG32HashOf("Alice & Miriel");
  { import core.stdc.stdio; foreach (ubyte b; hash[]) printf("%02x", b); printf("\n"); }
  assert(hash[] == cast(const(ubyte)[])xres);
}
