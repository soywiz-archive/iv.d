/** SR3C, a symbol ranking data compressor.
 *
 * This file implements a fast and effective data compressor.
 * The compression is on par (k8: i guess ;-) to gzip -7.
 * bzip2 -2 compresses slightly better than SR3C, but takes almost
 * three times as long. Furthermore, since bzip2 is  based on
 * Burrows-Wheeler block sorting, it can't be used in on-line
 * compression tasks.
 * Memory consumption of SR3C is currently around 4.5 MB per ongoing
 * compression and decompression.
 *
 * Author: Kenneth Oksanen <cessu@iki.fi>, 2008.
 * Copyright (C) Helsinki University of Technology.
 * D conversion by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 *
 * This code borrows many ideas and some paragraphs of comments from
 * Matt Mahoney's s symbol ranking compression program SR2 and Peter
 * Fenwicks SRANK, but otherwise all code has been implemented from
 * scratch.
 *
 * This file is distributed under the following license:
 *
 * The MIT License
 * Copyright (c) 2008 Helsinki University of Technology
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
module iv.sr3c /*is aliced*/;
import iv.alice;

/** Prior to compression or uncompression the user of this library
 * creates a "compression context" of type `SR3C` which can
 * with certain disciplines be used for both compression and
 * uncompression. The compression context initialization is given a
 * function `outdg` which the compression and uncompression
 * routines call for processing the data further.
 *
 * This library is MT-safe so that any number of concurrent
 * compression or uncompression tasks may be ongoing as long as each
 * of them is passed a distinct compression context. By default each
 * compression context requires approximately 4.5 MB of memory, but
 * see the internal documentation of sr3c.d for further notes on this.
 *
 * Compression tasks are generally NOT synchronous in the sense that
 * once some data is passed to `compress()` the `outdg` would
 * be passed enough compressed data so as to uncompress all of the
 * same original data. When synchronization is required, for example
 * at the end of successful compression, the user of this library
 * should call `flush()`. The decompressing side will recognize
 * the flush from the compressed data. Only when a compression and
 * decompression have flushed in this manner, can the corresponding
 * compression contexts be used in reverse direction.
 */
public final class SR3C {
public:
  /** The type of the function used to process the compressed or
   * uncompressed data further. The function should return a non-zero
   * value on failure. The function may not free the memory referred to
   * by the 'bytes' argument. The argument 'flush' is passed a true
   * value iff `flush()` was called after compressing the data.
   */
  alias OutputDg = int delegate (const(void)[] bytes, bool flush);

private:
  enum SR_HMASK = 0xFFFFF;
  enum SR_HMULT = 480;
  enum SR_XSHFT = 20;
  /* It is possible to reduce memory consumption from 4.5 MB to, say,
     1.5 MB with the following definitions, but this will also reduce
     the compression ratio.  In my tests on average this would result in
     an almost 4% increase in the size of the compressed data.
    #define SR_HMASK   0x3FFFF
    #define SR_HMULT   352
    #define SR_XSHFT   18
     Even further memory savings are possible, but again with worse
     compression.  The following definitions require some 0.75 MB memory
     and result 7-8% larger compressed data than with current default
     definitions.  Further memory savings would require changes in the
     secondary arithmetic compression, a.k.a. state maps.
    #define SR_HMASK   0xFFFF
    #define SR_HMULT   288
    #define SR_XSHFT   16
     Conversely, by allowing a loftier memory budget, say 64.5 MB,
     compression can be improved further.  The following will result in
     a little over 2% improvement in compression:
    #define SR_HMASK   0xFFFFFF
    #define SR_HMULT   704
    #define SR_XSHFT   24
   */

  enum SM_P_HALF = 1U<<31;

  enum SM_HUFF_LO_N = 4*256*3;
  enum SM_HUFF_HI_N1 = 16;
  enum SM_HUFF_HI_N2 = 3;
  enum SM_BYTES_N = 256*256;

  enum {
    SR_FLUSHED,
    SR_COMPRESSING,
    /* The following states are for the uncompressor. */
    SR_FILLING_1, SR_FILLING_2, SR_FILLING_3,
    SR_UNCOMPRESSING_1, SR_UNCOMPRESSING_2, SR_UNCOMPRESSING_3,
    SR_UNCOMPRESSING_BYTE, SR_FLUSHING,
  }

  ubyte* outbuf_p; // current output buffer
  uint[SR_HMASK+1] rank; // symbol ranking tables
  uint hash; // hash value of the current compression context
  int prev_ch; // previous byte we encoded, 0 if none
  /* statemaps map secondary context to probability.
   * each statemap entry contains the prediction in the upper 25 bits and a count of
   * how many times this state has been reached in the lower 7 bits. */
  // states for encoding the first three bits in each context; some of the entries in sm_huff_hi are unused
  uint[SM_HUFF_LO_N] sm_huff_lo;
  uint[SM_HUFF_HI_N2][SM_HUFF_HI_N1] sm_huff_hi;
  // states for encoding a byte not predicted by symbol ranker using a context-1 arithmetic encoding
  uint[SM_BYTES_N] sm_bytes;
  // arithmetic coder range, initially [0, 1), scaled by 2^32; the field x is use only during uncompression
  uint x1, x2, x;
  // iutput function and its context, returns non-zero on error
  OutputDg output_f;
  int status; // SR_XXX
  // the following field is used by the uncompressor while uncompressing literal bytes
  int lit_ix;

public:
  this (OutputDg outdg) { reset(outdg); }

private:
  /** Reinitialize the given compression context. If `outdg` is
   * non-null, it is assigned to the compression context's new output
   * function. If, on the other hand, output_f is `null` the callback
   * function remain as it is.
   */
  public void reset (OutputDg outdg=null) {
    int i, j;
    /* Initialize statemaps.  The initial values were chosen based on a
       large number of test runs.  The cumulative statistic match quite
       well those of Fenwick:
         - Least recently used matches with 45% probability (over all counts),
         - Second least recently used matches with 15% probability,
         - Third least recently used matches with 7% probability,
         - Literals match with 32% probability.
       Initializing to anything else but SM_P_HALF produces
       proportionally modest benefits for large inputs, but we wanted
       SR3C to be effective also for small inputs. */
    for (i = 0; i < 3*256; i += 3) {
      sm_huff_lo.ptr[i] = (3400<<20)|0;
      sm_huff_lo.ptr[i+1] = (150<<20)|12;
      sm_huff_lo.ptr[i+2] = (1000<<20)|12;
    }
    for (; i < 2*3*256; i += 3) {
      sm_huff_lo.ptr[i] = (1500<<20)|0;
      sm_huff_lo.ptr[i+1] = (1840<<20)|12;
      sm_huff_lo.ptr[i+2] = (780<<20)|12;
    }
    for (; i < 3*3*256; i += 3) {
      sm_huff_lo.ptr[i] = (880<<20)|0;
      sm_huff_lo.ptr[i+1] = (1840<<20)|12;
      sm_huff_lo.ptr[i+2] = (760<<20)|12;
    }
    for (; i < 4*3*256; i += 3) {
      sm_huff_lo.ptr[i] = (780<<20)|0;
      sm_huff_lo.ptr[i+1] = (1840<<20)|12;
      sm_huff_lo.ptr[i+2] = (1120<<20)|12;
    }
    for (i = 0; i < SM_HUFF_HI_N1; i++) {
      sm_huff_hi.ptr[i].ptr[0] = (400<<20)|10;
      sm_huff_hi.ptr[i].ptr[1] = (1840<<20)|12;
      sm_huff_hi.ptr[i].ptr[2] = (1180<<20)|12;
    }
    for (i = 0; i < SM_BYTES_N; i++)
      sm_bytes.ptr[i] = SM_P_HALF;

    for (i = 0; i < SR_HMASK+1; i++)
      rank.ptr[i] = 0;

    prev_ch = 0;
    hash = 0;

    x1 = 0;
    x2 = 0xFEFFFFFF;
    if (outdg !is null) output_f = outdg;
    status = SR_FLUSHED;
  }

  // what is the prediction, as a fractional probability from 0 to 4095, of the next bit being one
  enum SM_PREDICT(string sm) = "(("~sm~")>>20)";
  enum SM_COUNT(string sm) = "(("~sm~")&0x1FF)";


  enum SM_UPDATE_RANKS(string sm, string bit) = "do {\n"~
    //"assert(bit == 0 || bit == 1);\n"~
    "int count = "~sm~"&0x1FF, prediction__ = "~sm~">>9;\n"~
    "int d = ("~bit~"<<23)-prediction__;\n"~
    ""~sm~" += (d*sr_wt_ranks.ptr[count])&0xFFFFFE00;\n"~
    "if (d < 0) d = -d;\n"~
    "d >>= 17;\n"~
    "//"~sm~" += sr_ct_ranks.ptr[d].ptr[count];\n"~
    ""~sm~" ^= sr_ct_ranks.ptr[d].ptr[count];\n"~
  "} while (0);";

  enum SM_UPDATE_BYTES(string sm, string bit) = "do {\n"~
    //"assert(bit == 0 || bit == 1);\n"~
    "int count = "~sm~"&0x1FF, prediction__ = "~sm~">>9;\n"~
    "int d = ("~bit~"<<23)-prediction__;\n"~
    ""~sm~" += (d*sr_wt_bytes.ptr[count])&0xFFFFFE00;\n"~
    "if (d < 0) d = -d;\n"~
    "d >>= 17;\n"~
    ""~sm~" ^= sr_ct_bytes.ptr[d].ptr[count];\n"~
  "} while (0);";

  // compress bit in the given state map, possibly outputting bytes in process
  enum SR_ENCODE_RANK_BIT(string sm, string bit) = "do {\n"~
    "uint xmid;\n"~
    "int prediction_ = "~SM_PREDICT!sm~";\n"~
    //"assert(bit == 0 || bit == 1);\n"~
    "assert(prediction_ >= 0 && prediction_ < 4096);\n"~
    "xmid = x1+((x2-x1)>>12)*prediction_;\n"~
    "assert(xmid >= x1 && xmid < x2);\n"~
    "if ("~bit~") x2 = xmid; else x1 = xmid+1;\n"~
    SM_UPDATE_RANKS!(sm, bit)~"\n"~
    "/* pass equal leading bytes of range */\n"~
    "while ((x1>>24) == (x2>>24)) {\n"~
    "  *outbuf_p++ = x2>>24;\n"~
    "  x1 <<= 8;\n"~
    "  x2 = (x2<<8)+255;\n"~
    "}\n"~
  "} while (0);";

  enum SR_ENCODE_BYTE_BIT(string sm, string bit) = "do {\n"~
    "uint xmid;\n"~
    "int prediction_ = "~SM_PREDICT!sm~";\n"~
    //"assert(bit == 0 || bit == 1);\n"~
    "assert(prediction_ >= 0 && prediction_ < 4096);\n"~
    "xmid = x1+((x2-x1)>>12)*prediction_;\n"~
    "assert(xmid >= x1 && xmid < x2);\n"~
    "if ("~bit~") x2 = xmid; else x1 = xmid+1;\n"~
    SM_UPDATE_BYTES!(sm, bit)~"\n"~
    "// pass equal leading bytes of range\n"~
    "while ((x1>>24) == (x2>>24)) {\n"~
    "  *outbuf_p++ = x2>>24;\n"~
    "  x1 <<= 8;\n"~
    "  x2 = (x2<<8)+255;\n"~
    "}\n"~
  "} while (0);";

  enum SR_ENCODE_BYTE(string ch) = "do {\n"~
    "uint* sm_ = &sm_bytes.ptr[256*prev_ch];\n"~
    "uint ix = 1, x = "~ch~", bit;\n"~
    "do {\n"~
    "  bit = (x>>7)&0x1;\n"~
    "  "~SR_ENCODE_BYTE_BIT!("sm_[ix]", "bit")~"\n"~
    "  ix = (ix<<1)|bit;\n"~
    "  x <<= 1;\n"~
    "} while (ix < 256);\n"~
  "} while (0);";


  enum OUTBUF_SIZE = 1024;

  /** Compress the given bytes, possibly sending some compressed data to
   * `outdg`. Returns zero on success, or whatever `outdg` returned
   * should it have erred. Once the context has been used for
   * compressing, it can't be used for uncompressing before `flush()`
   * has been called.
   */
  public int compress (const(void)[] data) {
    const(ubyte)* bytes = cast(const(ubyte)*)data.ptr;
    usize n_bytes = data.length;
    uint index, xsum, r;
    uint* sm;
    int ch;
    ubyte[OUTBUF_SIZE] outbuf;
    /* The theoretical worst case is that each bit is encoded into 12
       bits, and there can be 10 bits of output per bit sent to the
       arithmetic coder, or 15 bytes.  Additionally there may be some
       bytes of flushing from the arithmetic coder itself, thus a margin
       of slightly cautious 30 bytes. */
    ubyte* outbuf_end = outbuf.ptr+OUTBUF_SIZE-30;

    assert(status == SR_FLUSHED || status == SR_COMPRESSING);

    status = SR_COMPRESSING;

    while (n_bytes > 0) {
      outbuf_p = outbuf.ptr;
      while (outbuf_p < outbuf_end && n_bytes > 0) {
        --n_bytes;
        index = hash&SR_HMASK;
        xsum = (hash>>SR_XSHFT)&0xF;
        r = rank.ptr[index];
        if (((r>>24)&0xF) != xsum) {
          // hash collision: pick another index, use it if checksums match or it has a lower first-hit counter value
          int alt_index = (index+0x3A77)&SR_HMASK;
          uint alt_r = rank.ptr[alt_index];
          if (((alt_r>>24)&0xF) == xsum || alt_r < r) {
            index = alt_index;
            r = alt_r;
          }
        }
        if (r >= 0x40000000)
          sm = &sm_huff_hi.ptr[r>>28].ptr[0];
        else
          sm = &sm_huff_lo.ptr[3*(prev_ch|((r>>20)&0x300))];

        ch = *bytes++;
        xsum = (xsum<<24)|ch;
        if (ch == (r&0xFF)) {
          // is ch the least recently seen?
          mixin(SR_ENCODE_RANK_BIT!("sm[0]", "0"));
          if (r < 0xF0000000) r += 0x10000000; // increment hit count
        } else {
          mixin(SR_ENCODE_RANK_BIT!("sm[0]", "1"));
          if (ch == ((r>>8)&0xFF)) {
            // is ch the second least recent?
            mixin(SR_ENCODE_RANK_BIT!("sm[1]", "1"));
            mixin(SR_ENCODE_RANK_BIT!("sm[2]", "0"));
            if ((r>>28) >= 0xC)
              r &= 0x4FFFFFFF;
            else
              r = (r&0xFF0000)|((r&0xFF)<<8)|xsum|0x10000000;
          } else if (ch == ((r>>16)&0xFF)) {
            // is ch the third least recent?
            mixin(SR_ENCODE_RANK_BIT!("sm[1]", "1"));
            mixin(SR_ENCODE_RANK_BIT!("sm[2]", "1"));
            r = ((r&0xFFFF)<<8)|xsum|0x10000000;
          } else {
            mixin(SR_ENCODE_RANK_BIT!("sm[1]", "0"));
            mixin(SR_ENCODE_BYTE!"ch");
            r = ((r&0xFFFF)<<8)|xsum;
          }
        }
        rank.ptr[index] = r;
        prev_ch = ch;
        hash = SR_HMULT*hash+ch+1;
      }
      if (outbuf_p > outbuf.ptr) {
        if (int err = output_f(outbuf[0..outbuf_p-outbuf.ptr], false)) return err;
      }
    }
    return 0;
  }

  /** Flush the internal buffered state of the compression context to
   * `outdg` so that a uncompression of all the data provided prior
   * to the flush becomes possible. Returns zero on success, or
   * whatever `outdg` returned should it have erred. It is possible
   * to continue compression after flushing the buffers, but each flush
   * will cause at least a three byte overhead, probably higher.
   * File compressors and archivers typically flush only at the end of
   * compression, but message-interchanging programs flush whenever
   * real-timeness requires or a response is required to proceed.
   *
   * Note that `flush()` may not be called for a context currently used
   * for uncompression.
   */
  public int flush () {
    uint r;
    uint *sm;
    int index, xsum, i, err;
    ubyte[128] outbuf;
    outbuf_p = &outbuf[0];

    assert(status == SR_COMPRESSING || status == SR_FLUSHED);

    /* Pick state map entry as if compressing a normal data byte. */
    index = hash&SR_HMASK;
    xsum = (hash>>SR_XSHFT)&0xF;
    r = rank.ptr[index];
    if (((r>>24)&0xF) != xsum) {
      int alt_index = (index+0x3A77)&SR_HMASK;
      uint alt_r = rank.ptr[alt_index];
      if (((alt_r>>24)&0xF) == xsum || alt_r < r) {
        index = alt_index;
        r = alt_r;
      }
    }
    if (r >= 0x40000000)
      sm = &sm_huff_hi.ptr[r>>28].ptr[0];
    else
      sm = &sm_huff_lo.ptr[3*(prev_ch|((r>>20)&0x300))];

    /* Mark end of data by coding third least recently used byte as
       a literal. */
    mixin(SR_ENCODE_RANK_BIT!("sm[0]", "1"));
    mixin(SR_ENCODE_RANK_BIT!("sm[1]", "0"));
    mixin(SR_ENCODE_BYTE!"((r>>16)&0xFF)");

    /* Flush also the arithmetic encoder, first by the first unequal
       byte in the range and thereafter three maximum bytes. */
    *outbuf_p++ = x1>>24;
    *outbuf_p++ = 0xFF;
    *outbuf_p++ = 0xFF;
    *outbuf_p++ = 0xFF;

    /* Finally send this all out. */
    err = output_f(outbuf[0..outbuf_p-outbuf.ptr], true);
    if (err) return err;

    /* Reset internal values in the context, not however the statemaps or ranks. */
    prev_ch = 0;
    hash = 0;
    x1 = 0;
    x2 = 0xFEFFFFFF;
    status = SR_FLUSHED;

    return 0;
  }

  /** Return true if the given context is flushed, i.e. if the
   * context can now be used for either compression or uncompression.
   */
  public @property bool flushed () const pure nothrow @safe @nogc { return (status == SR_FLUSHED); }

  /** Uncompress the given bytes, possibly sending some uncompressed data
   * to `outdg`.  Returns zero on success, or whatever `outdg`
   * returned should it have failed. SR3C includes no checksum so
   * corrupted compressed messages will not be detected. Once the
   * context has been used for uncompressing, it can't be used for
   * compressing before `flush()` has been issued on the corresponding
   * compressing side and the resulting compressed data has been
   * uncompressed.
   */
  public int uncompress (const(void)[] data) {
    enum SR_INPUT(string state_name) =
      "do {\n"~
      ""~state_name~":\n"~
      "  while ((x1>>24) == (x2>>24)) {\n"~
      "    if (n_bytes == 0) { status = "~state_name~"; goto out_of_input; }\n"~
      "    x1 <<= 8;\n"~
      "    x2 = (x2<<8)+255;\n"~
      "    x = (x<<8)+*bytes++;\n"~
      "    n_bytes--;\n"~
      "  }\n"~
      "} while (0);";

    enum SR_DECODE_BIT(string sm, string bit, string state_name) =
      "do {\n"~
      "  "~SR_INPUT!(state_name)~"\n"~
      "  prediction = "~SM_PREDICT!(sm)~";\n"~
      "  assert(prediction >= 0 && prediction < 4096);\n"~
      "  xmid = x1+((x2-x1)>>12)*prediction;\n"~
      "  assert(xmid >= x1 && xmid < x2);\n"~
      "  if (x <= xmid) {\n"~
      "    "~bit~" = 1;\n"~
      "    x2 = xmid;\n"~
      "  } else {\n"~
      "    "~bit~" = 0;\n"~
      "    x1 = xmid+1;\n"~
      "  }\n"~
      "} while (0);";

    const(ubyte)* bytes = cast(const(ubyte)*)data.ptr;
    usize n_bytes = data.length;
    uint xmid;
    int prediction;

    uint index, xsum, r;
    uint* sm;
    int bit, ch, err;
    ubyte[OUTBUF_SIZE] outbuf;
    outbuf_p = outbuf.ptr;
    ubyte* outbuf_end = outbuf.ptr+OUTBUF_SIZE;

    assert(status != SR_COMPRESSING);

    switch (status) {
      case SR_FLUSHED:
        while (n_bytes > 0 && *bytes == 0xFF) {
          bytes++;
          n_bytes--;
        }
        if (n_bytes-- == 0) return 0;
      restart:
        x = (x<<8)|*bytes++;
        goto case;
      case SR_FILLING_1:
        if (n_bytes-- == 0) {
          status = SR_FILLING_1;
          return 0;
        }
        x = (x<<8)|*bytes++;
        goto case;
      case SR_FILLING_2:
        if (n_bytes-- == 0) {
          status = SR_FILLING_2;
          return 0;
        }
        x = (x<<8)|*bytes++;
        goto case;
      case SR_FILLING_3:
        if (n_bytes-- == 0) {
          status = SR_FILLING_3;
          return 0;
        }
        x = (x<<8)|*bytes++;
        status = SR_UNCOMPRESSING_1;
        break;
      case SR_FLUSHING:
        goto SR_FLUSHING;
      default:
        // the default branch is here to only to keep the compiler happy
        break;
    }

    index = hash&SR_HMASK;
    xsum = (hash>>SR_XSHFT)&0xF;
    r = rank.ptr[index];
    if (((r>>24)&0xF) != xsum) {
      // hash collision: pick another index, use it if checksums match or it has a lower first-hit counter value
      int alt_index = (index+0x3A77)&SR_HMASK;
      uint alt_r = rank.ptr[alt_index];
      if (((alt_r>>24)&0xF) == xsum || alt_r < r) {
        index = alt_index;
        r = alt_r;
      }
    }
    if (r >= 0x40000000)
      sm = &sm_huff_hi.ptr[r>>28].ptr[0];
    else
      sm = &sm_huff_lo.ptr[3*(prev_ch|((r>>20)&0x300))];
    xsum <<= 24;

    switch (status) {
      case SR_UNCOMPRESSING_1: goto SR_UNCOMPRESSING_1;
      case SR_UNCOMPRESSING_2: goto SR_UNCOMPRESSING_2;
      case SR_UNCOMPRESSING_3: goto SR_UNCOMPRESSING_3;
      case SR_UNCOMPRESSING_BYTE: sm = &sm_bytes.ptr[256*prev_ch]; goto SR_UNCOMPRESSING_BYTE;
      default: assert(0);
    }

    for (;;) {
      index = hash&SR_HMASK;
      xsum = (hash>>SR_XSHFT)&0xF;
      r = rank.ptr[index];
      if (((r>>24)&0xF) != xsum) {
        // hash collision: pick another index, use it if checksums match or it has a lower first-hit counter value
        int alt_index = (index+0x3A77)&SR_HMASK;
        uint alt_r = rank.ptr[alt_index];
        if (((alt_r>>24)&0xF) == xsum || alt_r < r) {
          index = alt_index;
          r = alt_r;
        }
      }
      if (r >= 0x40000000)
        sm = &sm_huff_hi.ptr[r>>28].ptr[0];
      else
        sm = &sm_huff_lo.ptr[3*(prev_ch|((r>>20)&0x300))];
      xsum <<= 24;

      mixin(SR_DECODE_BIT!("sm[0]", "bit", "SR_UNCOMPRESSING_1"));
      mixin(SM_UPDATE_RANKS!("sm[0]", "bit"));
      if (bit) {
        mixin(SR_DECODE_BIT!("sm[1]", "bit", "SR_UNCOMPRESSING_2"));
        mixin(SM_UPDATE_RANKS!("sm[1]", "bit"));
        if (bit) {
          mixin(SR_DECODE_BIT!("sm[2]", "bit", "SR_UNCOMPRESSING_3"));
          mixin(SM_UPDATE_RANKS!("sm[2]", "bit"));
          if (bit) {
            // third least recent byte
            ch = (r>>16)&0xFF;
            r = ((r&0xFFFF)<<8)|ch|xsum|0x10000000;
          } else {
            // second least recent byte
            ch = (r>>8)&0xFF;
            if ((r>>28) >= 0xC)
              r &= 0x4FFFFFFF;
            else
              r = (r&0xFF0000)|((r&0xFF)<<8)|ch|xsum|0x10000000;
          }
        } else {
          sm = &sm_bytes.ptr[256*prev_ch];
          lit_ix = 1;
          do {
            mixin(SR_DECODE_BIT!("sm[lit_ix]", "bit", "SR_UNCOMPRESSING_BYTE"));
            mixin(SM_UPDATE_BYTES!("sm[lit_ix]", "bit"));
            lit_ix = (lit_ix<<1)|bit;
          } while (lit_ix < 256);
          ch = lit_ix&0xFF;
          if (ch == ((r>>16)&0xFF)) goto flush;
          r = ((r&0xFFFF)<<8)|ch|xsum;
        }
      } else {
        // least recent byte
        ch = r&0xFF;
        if (r < 0xF0000000) r += 0x10000000;
      }

      *outbuf_p++ = cast(ubyte)ch;
      rank.ptr[index] = r;
      prev_ch = ch;
      hash = SR_HMULT*hash+ch+1;
      if (outbuf_p == outbuf_end) {
        err = output_f(outbuf[0..OUTBUF_SIZE], false);
        if (err) return err;
        outbuf_p = outbuf.ptr;
      }
    }

   flush:
    // we come here when we have received a flush.
    // pass the flush-induced bytes in the data stream and reset internal values
    // in the context, not however the statemaps or ranks.
    mixin(SR_INPUT!"SR_FLUSHING");
    prev_ch = 0;
    hash = 0;
    x1 = 0;
    x2 = 0xFEFFFFFF;
    status = SR_FLUSHED;
    /* Skip 0xFF-bytes. */
    while (n_bytes > 0 && *bytes == 0xFF) {
      bytes++;
      n_bytes--;
    }
    err = output_f(outbuf[0..outbuf_p-outbuf.ptr], true);
    if (err) return err;
    outbuf_p = outbuf.ptr;
    if (n_bytes-- > 0) {
      outbuf_p = outbuf.ptr;
      goto restart;
    }
    return 0;

   out_of_input:
    if (outbuf_p != outbuf.ptr) return output_f(outbuf[0..outbuf_p-outbuf.ptr], false);
    return 0;
  }

static:
  // some precomputed tables on how the secondary arithmetical compressor adjusts to actual data; see comments later
  static immutable ubyte[512] sr_wt_bytes;
  static immutable ubyte[512] sr_wt_ranks;
  static immutable ushort[512][65] sr_ct_bytes;
  static immutable ushort[512][65] sr_ct_ranks;

  shared static this () pure nothrow @safe @nogc {
    // initialize the various precomputed tables
    foreach (int count; 0..512) {
      // a table indexed by current state map count and returning the corresponding responsiveness to unpredicted input
      // found with numeric optimization for the order-0 arithmetic compressor
      sr_wt_bytes[count] = cast(ubyte)(2.814086+(1.107489*count+639.588922)/(0.006940*count*count+count+6.318012));
      // as above, but for rank encoding data
      sr_wt_ranks[count] = cast(ubyte)(-1.311630+(0.616477*count+640.391038)/(0.001946*count*count+count+5.632143));
      foreach (int d; 0..64+1) {
        // a table for updating the count-part in statemaps for bytes
        int c = (d > 1.1898325 && count > 19.782085 ? cast(int)(-2+0.021466*(d-1.1898325)*(count-19.782085)) : -2);
        if (c > count) c = 0; else if (count-c > 0x1FF) c = 0x1FF; else c = count-c;
        sr_ct_bytes[d][count] = cast(ushort)(c^count);
        // a table for updating the count-part in statemaps for ranks
        c = (count > 33.861341 ? cast(int)(-2+0.005355*(d+0.981405)*(count-33.861341)) : -2);
        if (c > count) c = 0; else if (count-c > 0x1FF) c = 0x1FF; else c = count-c;
        sr_ct_ranks[d][count] = cast(ushort)(c^count);
      }
    }
  }
}


/* This code is based on many of the ideas in Matt Mahoney's SR2
   symbol ranking compression program
       http://www.cs.fit.edu/~mmahoney/compression/#sr2
   which in turn is based on SRANK by P. M. Fenwick in 1997-98
       ftp://ftp.cs.auckland.ac.nz/pub/staff/peter-f/srank.c
   See also Fenwick's technical report "A fast, constant-order, symbol
   ranking text compressor", The University of Auckland, Department of
   Computer Science Report No 145, Apr. 1997.

   A symbol ranking compressor maintains a list (a move-to-front
   queue) of the most recently seen symbols (bytes) in the given
   context in order of time since last seen.  The original SRANK used
   a table of 2^10 to 2^18 hashed order-3 contexts, SR2 uses 2^20
   hashed order-4 contexts, and some versions of SR3 use 2^24
   contexts, which we considered excessively much in terms of implied
   memory consumption.  All the mentioned programs use a queue length
   of 3, SR2 furthermore uses a 6 bit count (n) of consecutive hits,
   SR3C uses only a 4 bit count but employs a 4-bit checksum to reduce
   hash collisions.

   SR2 as well as SR3C follow Fenwick's suggestion for a hardware
   implementation in sending 0 for literals, 110 and 111 for the
   second and third least recently seen, and 10xxxxxxxx's are reserved
   for literals.  These are compressed further with arithmetic coding
   using both an order-1 context (last coded byte) and the count as
   context, or order-0 and count if the count is greater or equal to
   four.

   Codes and updates are as follows:

      Input    Code        Next state
                           (c1  c2  c3  n)
      -----    ----        ---------------
      Initial              (0,  0,  0,  0)
        c1     0           (c1, c2, c3, min(n+1, 15))
        c2     110         (c2, c1, c3, 1)
        c3     111         (c3, c1, c2, 1)
      other c  10cccccccc  (c,  c1, c2, 0)

   As an exception, however, in SR3C if input is c2 and n has reached
   very high counts (12 or more), then the count is reduced to four
   but the queue is kept intact.

   After coding byte c, the hash index h is updated to h * 480 + c + 1
   (mod 2^20) which depends on only the last 4 bytes.  SR2 did not
   detect hash collisions, but SR3C uses a 4-bit checksum which is
   formed by the next four higher bits of the hash.  The values are
   packed into a 32 bit integer as follows: c1 in bits 0-7, c2 in
   8-15, c3 in 16-23, checksum in 24-27, n in 28-31.

   End of file is marked by coding c3 as a literal (SR2 used c1)
   followed by three 0xFF's.  The compressor library adds no header,
   but ensures the message doesn't begin with 0xFF so as to enable
   arbitrary catenation of messages.  Additional headers and checksums
   may be added by a stand-alone archiver using this library.

   Arithmetic coding is performed as in SR2, and we advise the reader
   to its documentation.  Let it only be noted that compared to SR2,
   SR3C uses far fewer arithmetic coding states than SR2 thus saving
   ~1.5 MB of RAM as well as incidentally also a slightly better
   compression ratio.  There are also several other differences in
   between SR2 and SR3C in how the predictions for next bits are
   updated.
 */
