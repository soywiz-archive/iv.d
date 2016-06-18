// balz is written and placed in the public domain by Ilya Muravyov <ilya.muravyov@yahoo.com>
// BALZ is a command-line file compressor with a high compression ratio and fast decompression.
// Special thanks to Matt Mahoney, Eugene Shelwien, Uwe Herklotz, Malcolm Taylor and LovePimple.
// D port by Ketmar // Invisible Vector
module iv.balz is aliced;


/// LZ compressor and decompressor.
final class Balz {
private:
  enum MAGIC = 0xba; // baLZ

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
  uint high = cast(uint)-1;

  Counter*[256] counter1; //[512]
  Counter*[256] counter2; //[TAB_SIZE]
  //Counter[512][256] counter1; //[512]
  //Counter[TAB_SIZE][256] counter2; //[TAB_SIZE]

  ubyte[65536] obuf;
  uint obufPos;

  ubyte[65536] ibuf;
  uint ibufPos, ibufUsed;

  enum TAB_BITS = 7;
  enum TAB_SIZE = 1<<TAB_BITS;
  enum TAB_MASK = TAB_SIZE-1;

  enum MIN_MATCH = 3;
  enum MAX_MATCH = 255+MIN_MATCH;

  enum BUF_BITS = 25;
  enum BUF_SIZE = 1<<BUF_BITS;
  enum BUF_MASK = cast(uint)(BUF_SIZE-1);

  ubyte* buf; //[BUF_SIZE]
  uint*[1<<16] tab; //[TAB_SIZE][1<<16]
  int[1<<16] cnt;

private:
  static T* xalloc(T, bool clear=true) (uint mem) if (T.sizeof > 0) {
    import core.exception : onOutOfMemoryError;
    assert(mem != 0);
    static if (clear) {
      import core.stdc.stdlib : calloc;
      auto res = calloc(mem, T.sizeof);
      if (res is null) onOutOfMemoryError();
      static if (is(T == struct)) {
        import core.stdc.string : memcpy;
        static immutable T i = T.init;
        memcpy(res, &i, T.sizeof);
      }
      return cast(T*)res;
    } else {
      import core.stdc.stdlib : malloc;
      auto res = malloc(mem*T.sizeof);
      if (res is null) onOutOfMemoryError();
      static if (is(T == struct)) {
        import core.stdc.string : memcpy;
        static immutable T i = T.init;
        memcpy(res, &i, T.sizeof);
      }
      return cast(T*)res;
    }
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
  GetBufFn getBuf;
  PutBufFn putBuf;

public:
  this () {}
  this (GetBufFn rdfn, PutBufFn wrfn) { getBuf = rdfn; putBuf = wrfn; }
  ~this () { freeMem(); }

  /// free working memory. can be called after compressing/decompressing.
  void freeMem () {
    import core.stdc.stdlib : free;
    foreach_reverse (ref c; counter2) xfree(c);
    foreach_reverse (ref c; counter1) xfree(c);
    foreach_reverse (ref t; tab) xfree(t);
    xfree(buf);
  }

  // ////////////////////////////////////////////////////////////////////// //
  /// compress data. will call `getBuf()` to read uncompressed data and
  /// `putBuf` to write compressed data. set `max` to `true` to squeeze some
  /// more bytes, but sacrifice some speed.
  public void compress (bool max=false) {
    int[MAX_MATCH+1] bestIdx;
    int n;

    setupMem();
    putb(MAGIC);
    buf[0..BUF_SIZE] = 0;
    foreach (ref c; counter1) c[0..512] = Counter.init;
    foreach (ref c; counter2) c[0..TAB_SIZE] = Counter.init;

    while ((n = readToBuf()) > 0) {
      int oldn = n;
      foreach (ref t; tab) t[0..TAB_SIZE] = 0;
      int p = 0;

      while (p < 2 && p < n) encode(buf[p++], 0);

      while (p < n) {
        immutable int c2 = buf[(p+BUF_SIZE-2)&BUF_MASK]|(buf[(p+BUF_SIZE-1)&BUF_MASK]<<8);
        immutable uint hash = getHash(p);

        int len = MIN_MATCH-1;
        int idx = TAB_SIZE;

        int max_match = n-p;
        if (max_match > MAX_MATCH) max_match = MAX_MATCH;

        for (int x = 0; x < TAB_SIZE; ++x) {
          immutable uint d = tab.ptr[c2][(cnt[c2]-x)&TAB_MASK];
          if (!d) break;

          if ((d&~BUF_MASK) != hash) continue;

          immutable int s = d&BUF_MASK;
          if (buf[(s+len)&BUF_MASK] != buf[(p+len)&BUF_MASK] || buf[s] != buf[p&BUF_MASK]) continue;

          int l = 0;
          while (++l < max_match) if (buf[(s+l)&BUF_MASK] != buf[(p+l)&BUF_MASK]) break;

          if (l > len) {
            for (int i = l; i > len; --i) bestIdx[i] = x;
            idx = x;
            len = l;
            if (l == max_match) break;
          }
        }

        if (max && len >= MIN_MATCH) {
          int sum = getPts(len, idx)+getPtsAt(p+len, n);
          if (sum < getPts(len+MAX_MATCH, 0)) {
            immutable int lookahead = len;
            for (int i = 1; i < lookahead; ++i) {
              immutable int tmp = getPts(i, bestIdx[i])+getPtsAt(p+i, n);
              if (tmp > sum) {
                sum = tmp;
                len = i;
              }
            }
            idx = bestIdx[len];
          }
        }

        tab.ptr[c2][++cnt[c2]&TAB_MASK] = hash|p;

        if (len >= MIN_MATCH) {
          encode((256-MIN_MATCH)+len, buf[(p+BUF_SIZE-1)&BUF_MASK]);
          encodeIdx(idx, buf[(p+BUF_SIZE-2)&BUF_MASK]);
          p += len;
        } else {
          encode(buf[p], buf[(p+BUF_SIZE-1)&BUF_MASK]);
          ++p;
        }
      }
      if (oldn < BUF_SIZE) break;
    }

    flush();
  }

  // ////////////////////////////////////////////////////////////////////// //
  /// decompress data. will call `getBuf()` to read compressed data and
  /// `putBuf` to write uncompressed data. pass *uncompressed* data length in
  /// `flen`. sorry, no "end of stream" flag is provided.
  public void decompress (long flen) {
    assert(flen >= 0);

    setupMem();
    if (getb != MAGIC) throw new Exception("invalid compressed stream format");
    flushb();

    buf[0..BUF_SIZE] = 0;
    foreach (ref c; counter1) c[0..512] = Counter.init;
    foreach (ref c; counter2) c[0..TAB_SIZE] = Counter.init;
    foreach (ref t; tab) t[0..TAB_SIZE] = 0;
    foreach (immutable _; 0..4) code = (code<<8)|getb();

    while (flen > 0) {
      int p = 0;

      while (p < 2 && p < flen) {
        immutable int t = decode(0);
        if (t >= 256) throw new Exception("compressed stream corrupted");
        buf[p++] = cast(ubyte)t;
      }

      while (p < BUF_SIZE && p < flen) {
        immutable int tmp = p;
        immutable int c2 = buf[(p+BUF_SIZE-2)&BUF_MASK]|(buf[(p+BUF_SIZE-1)&BUF_MASK]<<8);//*cast(ushort*)(buf.ptr+p-2);

        immutable int t = decode(buf[(p+BUF_SIZE-1)&BUF_MASK]);
        if (t >= 256) {
          int len = t-256;
          int s = tab.ptr[c2][(cnt[c2]-decodeIdx(buf[(p+BUF_SIZE-2)&BUF_MASK]))&TAB_MASK];

          buf[p&BUF_MASK] = buf[s&BUF_MASK]; ++p; ++s;
          buf[p&BUF_MASK] = buf[s&BUF_MASK]; ++p; ++s;
          buf[p&BUF_MASK] = buf[s&BUF_MASK]; ++p; ++s;
          while (len--) { buf[p&BUF_MASK] = buf[s&BUF_MASK]; ++p; ++s; }
        } else {
          buf[p&BUF_MASK] = cast(ubyte)t; ++p;
        }

        tab.ptr[c2][++cnt[c2]&TAB_MASK] = tmp;
      }
      putBuf(buf[0..p]);
      flen -= p;
    }
  }

private:
  void setupMem () {
    scope(failure) freeMem();
    if (buf is null) buf = xalloc!ubyte(BUF_SIZE);
    foreach (ref t; tab) if (t is null) t = xalloc!uint(TAB_SIZE);
    foreach (ref c; counter1) c = xalloc!Counter(512);
    foreach (ref c; counter2) c = xalloc!Counter(TAB_SIZE);
  }

  void flushb () {
    if (obufPos > 0) {
      auto wr = obufPos;
      obufPos = 0;
      putBuf(obuf[0..wr]);
    }
  }

  void putb (ubyte b) {
    obuf.ptr[obufPos++] = b;
    if (obufPos >= obuf.length) flushb();
  }

  ubyte getb () {
    if (ibufPos >= ibufUsed) {
      ibufPos = ibufUsed = 0;
      ibufUsed = getBuf(ibuf[]);
      if (ibufUsed == 0) throw new Exception("out of input data");
    }
    return ibuf.ptr[ibufPos++];
  }

  uint readToBuf () {
    uint bp = 0;
    while (bp < BUF_SIZE && ibufPos < ibufUsed) buf[bp++] = ibuf[ibufPos++];
    ibufPos = ibufUsed = 0;
    while (bp < BUF_SIZE) {
      auto rd = getBuf(buf[bp..BUF_SIZE]);
      if (rd == 0) break;
      bp += rd;
    }
    return bp;
  }

  void encode (int bit, ref Counter counter) {
    immutable uint mid = cast(uint)(low+((cast(ulong)(high-low)*(counter.p<<15))>>32));
    if (bit) {
      high = mid;
      counter.update1();
    } else {
      low = mid+1;
      counter.update0();
    }
    while ((low^high) < (1<<24)) {
      putb(cast(ubyte)(low>>24));
      low <<= 8;
      high = (high<<8)|255;
    }
  }

  void flush () {
    foreach (immutable _; 0..4) {
      putb(cast(ubyte)(low>>24));
      low <<= 8;
    }
    flushb();
  }

  int decode (ref Counter counter) {
    immutable uint mid = cast(uint)(low+((cast(ulong)(high-low)*(counter.p<<15))>>32));
    immutable int bit = (code<=mid);
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

  // ////////////////////////////////////////////////////////////////////// //
  void encode (int t, int c1) {
    int ctx = 1;
    while (ctx < 512) {
      immutable int bit = cast(int)((t&256) != 0);
      t += t;
      encode(bit, counter1.ptr[c1][ctx]);
      ctx += ctx+bit;
    }
  }

  void encodeIdx (int x, int c2) {
    int ctx = 1;
    while (ctx < TAB_SIZE) {
      immutable int bit = cast(int)((x&(TAB_SIZE>>1)) != 0);
      x += x;
      encode(bit, counter2.ptr[c2][ctx]);
      ctx += ctx+bit;
    }
  }

  int decode (int c1) {
    int ctx = 1;
    while (ctx < 512) ctx += ctx+decode(counter1.ptr[c1][ctx]);
    return ctx-512;
  }

  int decodeIdx (int c2) {
    int ctx = 1;
    while (ctx < TAB_SIZE) ctx += ctx+decode(counter2.ptr[c2][ctx]);
    return ctx-TAB_SIZE;
  }

  // ////////////////////////////////////////////////////////////////////// //
  uint getHash (int p) {
    pragma(inline, true);
    return (((buf[(p+0)&BUF_MASK]|(buf[(p+1)&BUF_MASK]<<8)|(buf[(p+2)&BUF_MASK]<<16)|(buf[(p+3)&BUF_MASK]<<24))&0xffffff)*2654435769UL)&~BUF_MASK;
  }

  int getPts (int len, int x) {
    pragma(inline, true);
    return (len >= MIN_MATCH ? (len<<TAB_BITS)-x : ((MIN_MATCH-1)<<TAB_BITS)-8);
  }

  int getPtsAt (int p, int n) {
    immutable int c2 = buf[(p+BUF_SIZE-2)&BUF_MASK]|(buf[(p+BUF_SIZE-1)&BUF_MASK]<<8);//*cast(ushort*)(buf.ptr+p-2);
    immutable uint hash = getHash(p);

    int len = MIN_MATCH-1;
    int idx = TAB_SIZE;

    int max_match = n-p;
    if (max_match > MAX_MATCH) max_match = MAX_MATCH;

    foreach (int x; 0..TAB_SIZE) {
      immutable uint d = tab.ptr[c2][(cnt[c2]-x)&TAB_MASK];
      if (!d) break;

      if ((d&~BUF_MASK) != hash) continue;

      immutable int s = d&BUF_MASK;
      if (buf[(s+len)&BUF_MASK] != buf[(p+len)&BUF_MASK] || buf[s] != buf[p]) continue;

      int l = 0;
      while (++l < max_match) if (buf[(s+l)&BUF_MASK] != buf[(p+l)&BUF_MASK]) break;

      if (l > len) {
        idx = x;
        len = l;
        if (l == max_match) break;
      }
    }

    return getPts(len, idx);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
version(balz_demo) {
int main (string[] args) {
  import core.stdc.time;
  import std.stdio;

  if (args.length != 4) {
    write(
      "BALZ - A ROLZ-based file compressor, v1.20\n"~
      "\n"~
      "Usage: BALZ command infile outfile\n"~
      "\n"~
      "Commands:\n"~
      "  c|cx Compress (Normal|Maximum)\n"~
      "  d    Decompress\n"
    );
    return 1;
  }

  auto fin = File(args[2]);
  auto fout = File(args[3], "w");

  auto cm = new Balz(
    // reader
    (buf) { auto res = fin.rawRead(buf[]); return cast(uint)res.length; },
    // writer
    (buf) { fout.rawWrite(buf[]); },
  );

  // 'e' -- for compatibility with v1.15
  if (args[1][0] == 'c' || args[1][0] == 'e') {
    writefln("Compressing %s...", args[2]);
    long fsz = fin.size;
    fout.rawWrite((&fsz)[0..1]);
    auto start = clock();
    cm.compress(args[1].length > 1 && args[1][1] == 'x');
    writefln("%s -> %s in %.3fs", fin.size, fout.size, double(clock()-start)/CLOCKS_PER_SEC);
  } else if (args[1][0] == 'd') {
    writefln("Decompressing %s...", args[2]);
    long fsz;
    fin.rawRead((&fsz)[0..1]);
    auto start = clock();
    cm.decompress(fsz);
    writefln("%s -> %s in %.3fs", fin.size, fout.size, double(clock()-start)/CLOCKS_PER_SEC);
  } else {
    writefln("Unknown command: %s", args[1]);
    return 1;
  }

  return 0;
}
}
