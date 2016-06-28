/**
 * BALZ: A ROLZ-based file compressor.
 *
 * balz is written and placed in the public domain by Ilya Muravyov <ilya.muravyov@yahoo.com>
 *
 * BALZ is a ROLZ-based data compressor with a high compression ratio and fast decompression.
 *
 * Special thanks to Matt Mahoney, Eugene Shelwien, Uwe Herklotz, Malcolm Taylor and LovePimple.
 *
 * D port by Ketmar // Invisible Vector
 *
 * What is ROLZ: http://ezcodesample.com/rolz/rolz_article.html
 */
module iv.balz;


// ////////////////////////////////////////////////////////////////////////// //
/// LZ compressor and decompressor.
///
/// memory usage (both for compression and for decompression): (~65MB)
struct BalzCodec(string mode) {
static assert(mode == "encoder" || mode == "decoder", "invalid Balz mode");
//static assert(BufBits >= 8 && BufBits <= 25, "invalid dictionary size");

private:
  enum MAGIC = 0xab; // baLZ

  static align(1) struct Counter {
  pure nothrow @safe @nogc align(1):
    ushort p1 = 1<<15;
    ushort p2 = 1<<15;
    @property uint p () const { pragma(inline, true); return p1+p2; }
    void update0 () { pragma(inline, true); p1 -= p1>>3; p2 -= p2>>6; }
    void update1 () { pragma(inline, true); p1 += (p1^65535)>>3; p2 += (p2^65535)>>6; }
  }

private:
  uint code;
  uint low;
  uint high;

  enum CounterSize = 256;
  Counter* counters; // [512][CounterSize], then [TabSize][CounterSize]

  static if (mode == "encoder") {
    enum obufSize = 65536;
    ubyte* obuf;
    uint obufPos;
  } else {
    ubyte* ibuf;
    enum ibufSize = 65536;
    uint ibufPos, ibufUsed;
  }

  enum TabBits = 7;
  enum TabSize = 1<<TabBits;
  enum TabMask = TabSize-1;

  enum MinMatchLen = 3;
  enum MaxMatchLen = 255+MinMatchLen;

  //enum SlDictBits = 25;
  ubyte lastDictBits = 0;
  ubyte SlDictBits = 25;
  uint SlDictSize; // = 1<<SlDictBits;
  uint SlDictMask; // = cast(uint)(SlDictSize-1);

  enum TabCntSize = 1<<16;

  ubyte* sldict; //[SlDictSize]
  uint* tab; // [TabSize][TabCntSize]
  int* cnt; // [TabCntSize]

  bool inProgress; // we are currently doing compressing or decompressing (and can't reinit engine)

private:
  static T* xalloc(T) (uint mem) if (T.sizeof > 0) {
    import core.exception : onOutOfMemoryError;
    assert(mem != 0);
    import core.stdc.stdlib : malloc;
    auto res = malloc(mem*T.sizeof);
    if (res is null) onOutOfMemoryError();
    debug(balz_alloc) { import core.stdc.stdio : printf; printf("balz allocated %u bytes\n", cast(uint)(mem*T.sizeof)); }
    return cast(T*)res;
  }

  static void xfree(T) (ref T* ptr) {
    if (ptr !is null) {
      import core.stdc.stdlib : free;
      free(ptr);
      ptr = null;
    }
  }

public:
  /// read data to provided buffer. return number of bytes read (can be less then buf size) or 0 on EOF. should throw on error.
  alias GetBufFn = uint delegate (void[] buf);
  /// write data from buffer. should write everything. should throw on error.
  alias PutBufFn = void delegate (const(void)[] buf);

public:
  /// get memory requirements for current configuration
  uint getMemoryRequirements () {
    pragma(inline, true);
    static if (mode == "encoder") enum iobufsize = obufSize; else enum iobufsize = ibufSize;
    return
      (1U<<SlDictBits)+ // sldict
      TabSize*TabCntSize*cast(uint)uint.sizeof+ // tab
      TabCntSize*cast(uint)int.sizeof+
      (512*CounterSize+TabSize*CounterSize)*cast(uint)Counter.sizeof+
      iobufsize;
  }

public:
  ~this () { freeMem(); }

  @disable this (this); // no copies

  enum MinDictBits = 10; /// minimum dictionary size
  enum MaxDictBits = 25; /// maximum dictionary size

  @property ubyte dictBits () const pure nothrow @safe @nogc { pragma(inline, true); return SlDictBits; }
  @property uint dictSize () const pure nothrow @safe @nogc { pragma(inline, true); return (1U<<SlDictBits); }

  /// reinit engine with new dictionary size
  bool reinit (ubyte dictbits) pure nothrow @safe @nogc {
    if (dictbits < MinDictBits || dictbits > MaxDictBits) return false;
    if (inProgress) return false;
    SlDictBits = dictbits;
    SlDictSize = 1U<<SlDictBits;
    SlDictMask = cast(uint)(SlDictSize-1);
    return true;
  }

  /// free working memory. can be called after compressing/decompressing.
  void freeMem () {
    static if (mode == "encoder") {
      xfree(obuf);
    } else {
      xfree(ibuf);
    }
    xfree(counters);
    xfree(cnt);
    xfree(tab);
    xfree(sldict);
  }

  // ////////////////////////////////////////////////////////////////////// //
  /// compress data. will call `getBuf()` to read uncompressed data and
  /// `putBuf` to write compressed data. set `max` to `true` to squeeze some
  /// more bytes, but sacrifice some speed.
  static if (mode == "encoder") void compress (scope GetBufFn getBuf, scope PutBufFn putBuf, bool max=false) {
    assert(getBuf !is null);
    assert(putBuf !is null);

    // i moved those functions here 'cause they need to do i/o
    void encodeWithCounter (int bit, Counter* counter) {
      immutable mid = cast(uint)(low+((cast(ulong)(high-low)*(counter.p<<15))>>32));
      if (bit) {
        high = mid;
        counter.update1();
      } else {
        low = mid+1;
        counter.update0();
      }
      while ((low^high) < (1<<24)) {
        if (obufPos >= obufSize) { auto wr = obufPos; obufPos = 0; putBuf(obuf[0..wr]); }
        obuf[obufPos++] = cast(ubyte)(low>>24);
        low <<= 8;
        high = (high<<8)|255;
      }
    }

    // doesn't do 511-escaping
    void encode(string mode) (uint t, uint c) {
      static if (mode == "char") {
        enum Limit = 512;
        enum Mask = 256;
        auto cptr = counters;
        debug(balz_eos) { import core.stdc.stdio : printf; printf("ec: t=%u; c=%u\n", cast(uint)t, cast(uint)c); }
      } else static if (mode == "idx") {
        enum Limit = TabSize;
        enum Mask = (TabSize>>1);
        auto cptr = counters+(512*CounterSize);
      } else {
        static assert(0, "invalid mode");
      }
      cptr += c*Limit;
      int ctx = 1;
      while (ctx < Limit) {
        immutable bit = cast(int)((t&Mask) != 0);
        t += t;
        encodeWithCounter(bit, cptr+ctx);
        ctx += ctx+bit;
      }
    }

    int[MaxMatchLen+1] bestIdx;

    if (inProgress) throw new Exception("already doing something");
    inProgress = true;
    scope(exit) inProgress = false;
    reset();
    obuf[obufPos++] = MAGIC;
    obuf[obufPos++] = 00; // stream version
    for (;;) {
      int n = 0;
      while (n < SlDictSize) {
        auto rd = getBuf(sldict[n..SlDictSize]);
        if (rd == 0) break;
        n += rd;
      }
      // write block size
      encode!"char"((n>>24)&0xff, 0);
      encode!"char"((n>>16)&0xff, 0);
      encode!"char"((n>>8)&0xff, 0);
      encode!"char"(n&0xff, 0);
      if (n == 0) break;
      int p = 0;
      while (p < 2 && p < n) encode!"char"(sldict[p++], 0);
      tab[0..TabSize*TabCntSize] = 0;
      while (p < n) {
        immutable int c2 = sldict[(p+SlDictSize-2)&SlDictMask]|(sldict[(p+SlDictSize-1)&SlDictMask]<<8);
        immutable uint hash = getHash(p);
        int len = MinMatchLen-1;
        int idx = TabSize;
        int max_match = n-p;
        if (max_match > MaxMatchLen) max_match = MaxMatchLen;
        // hash search
        foreach (uint x; 0..TabSize) {
          immutable uint d = tab[c2*TabSize+((cnt[c2]-x)&TabMask)];
          if (!d) break;
          if ((d&~SlDictMask) != hash) continue;
          immutable int s = d&SlDictMask;
          if (sldict[(s+len)&SlDictMask] != sldict[(p+len)&SlDictMask] || sldict[s] != sldict[p&SlDictMask]) continue;
          int l = 0;
          while (++l < max_match) if (sldict[(s+l)&SlDictMask] != sldict[(p+l)&SlDictMask]) break;
          if (l > len) {
            for (int i = l; i > len; --i) bestIdx.ptr[i] = x;
            idx = x;
            len = l;
            if (l == max_match) break;
          }
        }
        // check match
        if (max && len >= MinMatchLen) {
          int sum = getPts(len, idx)+getPtsAt(p+len, n);
          if (sum < getPts(len+MaxMatchLen, 0)) {
            immutable int lookahead = len;
            for (int i = 1; i < lookahead; ++i) {
              immutable int tmp = getPts(i, bestIdx.ptr[i])+getPtsAt(p+i, n);
              if (tmp > sum) {
                sum = tmp;
                len = i;
              }
            }
            idx = bestIdx.ptr[len];
          }
        }
        tab[c2*TabSize+(++cnt[c2]&TabMask)] = hash|p;
        if (len >= MinMatchLen) {
          encode!"char"((256-MinMatchLen)+len, sldict[(p+SlDictSize-1)&SlDictMask]);
          encode!"idx"(idx, sldict[(p+SlDictSize-2)&SlDictMask]);
          p += len;
        } else {
          encode!"char"(sldict[p], sldict[(p+SlDictSize-1)&SlDictMask]);
          ++p;
        }
      }
    }
    // flush output buffer, so we can skip flush checks in code flush
    if (obufPos > 0) { auto wr = obufPos; obufPos = 0; putBuf(obuf[0..wr]); }
    // flush codes
    foreach (immutable _; 0..4) {
      obuf[obufPos++] = cast(ubyte)(low>>24);
      low <<= 8;
    }
    // flush output buffer again
    if (obufPos > 0) { auto wr = obufPos; obufPos = 0; putBuf(obuf[0..wr]); }
  }

  // ////////////////////////////////////////////////////////////////////// //
  /// decompress data. will call `getBuf()` to read compressed data and
  /// `putBuf` to write uncompressed data. pass *uncompressed* data length in
  /// `flen`. sorry, no "end of stream" flag is provided.
  /// returns number of decoded bytes.
  static if (mode == "decoder") long decompress (scope GetBufFn getBuf, scope PutBufFn putBuf, long flen=-1) {
    assert(getBuf !is null);
    assert(putBuf !is null);
    //assert(flen >= 0);

    // i moved those functions here 'cause they need to do i/o
    ubyte getb () {
      if (ibufPos >= ibufUsed) {
        ibufPos = ibufUsed = 0;
        ibufUsed = getBuf(ibuf[0..ibufSize]);
        if (ibufUsed == 0) throw new Exception("out of input data");
      }
      return ibuf[ibufPos++];
    }

    uint decodeWithCounter (Counter* counter) {
      immutable uint mid = cast(uint)(low+((cast(ulong)(high-low)*(counter.p<<15))>>32));
      immutable int bit = (code <= mid);
      if (bit) {
        high = mid;
        counter.update1();
      } else {
        low = mid+1;
        counter.update0();
      }
      while ((low^high) < (1<<24)) {
        code = (code<<8)|getb();
        low <<= 8;
        high = (high<<8)|255;
      }
      return bit;
    }

    int decode(string mode) (uint c) {
      static if (mode == "char") {
        enum Limit = 512;
        auto cptr = counters;
      } else static if (mode == "idx") {
        enum Limit = TabSize;
        auto cptr = counters+(512*CounterSize);
      } else {
        static assert(0, "invalid mode");
      }
      cptr += c*Limit;
      uint ctx = 1;
      while (ctx < Limit) ctx += ctx+decodeWithCounter(cptr+ctx);
      static if (mode == "char") {
        debug(balz_eos) { import core.stdc.stdio : printf; printf("dc: t=%u; c=%u\n", cast(uint)(ctx-Limit), cast(uint)c); }
      }
      return ctx-Limit;
    }

    if (inProgress) throw new Exception("already doing something");
    inProgress = true;
    scope(exit) inProgress = false;
    long totalout = 0;
    reset();
    if (getb() != MAGIC) throw new Exception("invalid compressed stream format");
    if (getb() != 00) throw new Exception("invalid compressed stream version");
    foreach (immutable _; 0..4) code = (code<<8)|getb();
    while (flen != 0) {
      // read block size
      int n = 0;
      foreach (immutable _; 0..4) {
        immutable uint t = decode!"char"(0);
        if (t >= 256) throw new Exception("compressed stream corrupted");
        n = (n<<8)|(t&0xff);
      }
      if (n < 0 || n > SlDictSize) throw new Exception("compressed stream corrupted");
      if (n == 0) {
        // done
        if (flen > 0) throw new Exception("compressed stream ends unexpectedly");
        break;
      }
      if (flen > 0) {
        if (n > flen) n = cast(int)flen; // don't read more than we need
        flen -= n;
      }
      int p = 0;
      while (p < 2 && p < n) {
        immutable uint t = decode!"char"(0);
        if (t >= 256) throw new Exception("compressed stream corrupted");
        sldict[p++] = cast(ubyte)t;
      }
      while (p < n) {
        immutable int tmp = p;
        immutable int c2 = sldict[(p+SlDictSize-2)&SlDictMask]|(sldict[(p+SlDictSize-1)&SlDictMask]<<8);
        int t = decode!"char"(sldict[(p+SlDictSize-1)&SlDictMask]);
        if (t >= 256) {
          int len = t-256;
          int s = tab[c2*TabSize+((cnt[c2]-decode!"idx"(sldict[(p+SlDictSize-2)&SlDictMask]))&TabMask)];
          sldict[p&SlDictMask] = sldict[s&SlDictMask]; ++p; ++s;
          sldict[p&SlDictMask] = sldict[s&SlDictMask]; ++p; ++s;
          sldict[p&SlDictMask] = sldict[s&SlDictMask]; ++p; ++s;
          while (len--) { sldict[p&SlDictMask] = sldict[s&SlDictMask]; ++p; ++s; }
        } else {
          sldict[p&SlDictMask] = cast(ubyte)t; ++p;
        }
        tab[c2*TabSize+(++cnt[c2]&TabMask)] = tmp;
      }
      totalout += p;
      putBuf(sldict[0..p]);
    }
    return totalout;
  }

private:
  void setupMem () {
    scope(failure) freeMem();
    SlDictSize = 1U<<SlDictBits;
    SlDictMask = cast(uint)(SlDictSize-1);
    if (sldict is null || SlDictBits != lastDictBits) {
      xfree(sldict);
      sldict = xalloc!ubyte(SlDictSize);
      lastDictBits = SlDictBits;
    }
    if (tab is null) tab = xalloc!uint(TabSize*TabCntSize);
    if (cnt is null) cnt = xalloc!int(TabCntSize);
    if (counters is null) counters = xalloc!Counter(512*CounterSize+TabSize*CounterSize);
    static if (mode == "encoder") {
      if (obuf is null) obuf = xalloc!ubyte(obufSize);
    } else {
      if (ibuf is null) ibuf = xalloc!ubyte(ibufSize);
    }
  }

  void reset () {
    setupMem();
    sldict[0..SlDictSize] = 0;
    counters[0..512*CounterSize+TabSize*CounterSize] = Counter.init;
    static if (mode == "decoder") {
      tab[0..TabSize*TabCntSize] = 0; // encoder will immediately reinit this anyway
      ibufPos = ibufUsed = 0;
    } else {
      obufPos = 0;
    }
    cnt[0..TabCntSize] = 0;
    code = 0;
    low = 0;
    high = uint.max;
  }

  // ////////////////////////////////////////////////////////////////////// //
  // encoder utility functions
  static if (mode == "encoder") {
    uint getHash (int p) {
      pragma(inline, true);
      return (((sldict[(p+0)&SlDictMask]|(sldict[(p+1)&SlDictMask]<<8)|(sldict[(p+2)&SlDictMask]<<16)|(sldict[(p+3)&SlDictMask]<<24))&0xffffff)*2654435769UL)&~SlDictMask;
    }

    int getPts (int len, int x) {
      pragma(inline, true);
      return (len >= MinMatchLen ? (len<<TabBits)-x : ((MinMatchLen-1)<<TabBits)-8);
    }

    int getPtsAt (int p, int n) {
      immutable int c2 = sldict[(p+SlDictSize-2)&SlDictMask]|(sldict[(p+SlDictSize-1)&SlDictMask]<<8);//*cast(ushort*)(sldict.ptr+p-2);
      immutable uint hash = getHash(p);
      int len = MinMatchLen-1;
      int idx = TabSize;
      int max_match = n-p;
      if (max_match > MaxMatchLen) max_match = MaxMatchLen;
      foreach (int x; 0..TabSize) {
        immutable uint d = tab[c2*TabSize+((cnt[c2]-x)&TabMask)];
        if (!d) break;
        if ((d&~SlDictMask) != hash) continue;
        immutable int s = d&SlDictMask;
        if (sldict[(s+len)&SlDictMask] != sldict[(p+len)&SlDictMask] || sldict[s] != sldict[p]) continue;
        int l = 0;
        while (++l < max_match) if (sldict[(s+l)&SlDictMask] != sldict[(p+l)&SlDictMask]) break;
        if (l > len) {
          idx = x;
          len = l;
          if (l == max_match) break;
        }
      }
      return getPts(len, idx);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// handy aliases
alias Balz = BalzCodec!"encoder"; /// alias for Balz encoder
alias Unbalz = BalzCodec!"decoder"; /// alias for Balz decoder
