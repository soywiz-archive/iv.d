/*
 * tinf  -  tiny inflate library (inflate, gzip, zlib)
 * version 1.00
 *
 * Copyright (c) 2003 by Joergen Ibsen / Jibz
 * All Rights Reserved
 *
 * http://www.ibsensoftware.com/
 *
 * This software is provided 'as-is', without any express
 * or implied warranty.  In no event will the authors be
 * held liable for any damages arising from the use of
 * this software.
 *
 * Permission is granted to anyone to use this software
 * for any purpose, including commercial applications,
 * and to alter it and redistribute it freely, subject to
 * the following restrictions:
 *
 * 1. The origin of this software must not be
 *    misrepresented; you must not claim that you
 *    wrote the original software. If you use this
 *    software in a product, an acknowledgment in
 *    the product documentation would be appreciated
 *    but is not required.
 *
 * 2. Altered source versions must be plainly marked
 *    as such, and must not be misrepresented as
 *    being the original software.
 *
 * 3. This notice may not be removed or altered from
 *    any source distribution.
 */
/*
 * This D port was made by Ketmar // Invisible Vector
 * ketmar@ketmar.no-ip.org
 */
module iv.vfs.inflate;


////////////////////////////////////////////////////////////////////////////////
/*
 * Adler-32 algorithm taken from the zlib source, which is
 * Copyright (C) 1995-1998 Jean-loup Gailly and Mark Adler
 */
/// Adler-32 checksum computer
struct Adler32 {
nothrow @safe @nogc:
private:
  enum { BASE = 65521, NMAX = 5552 }
  enum normS1S2 = `s1 %= BASE; s2 %= BASE;`;

  template genByteProcessors(int count) {
    static if (count > 0)
      enum genByteProcessors = `s1 += *dta++;s2 += s1;`~genByteProcessors!(count-1);
    else
      enum genByteProcessors = "";
  }

  uint s1 = 1;
  uint s2 = 0;

public:
  /**
   * Computes the Adler-32 checksum. We can do `Adler32(buf)`.
   *
   * Params:
   *  data = input data
   *
   * Returns:
   *  adler32 checksum
   */
  static uint opCall(T) (T[] data) {
    Adler32 a32;
    a32.doBuffer(data);
    return a32.result;
  }

  /// reinitialize
  void reset () {
    pragma(inline, true);
    s1 = 1;
    s2 = 0;
  }

  /// get current Adler-32 sum
  @property uint result () const pure { pragma(inline, true); return ((s2<<16)|s1); }

  /// process buffer
  void doBuffer(T) (T[] data) @trusted {
    if (data.length == 0) return;
    usize len = data.length*data[0].sizeof; // length in bytes
    const(ubyte)* dta = cast(const(ubyte)*)data.ptr;
    foreach (immutable _; 0..len/NMAX) {
      foreach (immutable _; 0..NMAX/16) { mixin(genByteProcessors!(16)); }
      mixin(normS1S2);
    }
    len %= NMAX;
    if (len) {
      foreach (immutable _; 0..len) { mixin(genByteProcessors!(1)); }
      mixin(normS1S2);
    }
  }

  /// process one byte
  void doByte(T) (T bt)
  // sorry
  if (is(T == char) || is(T == byte) || is(T == ubyte) ||
      is(T == const char) || is(T == const byte) || is(T == const ubyte) ||
      is(T == immutable char) || is(T == immutable byte) || is(T == immutable ubyte))
  {
    s1 += cast(ubyte)bt;
    s2 += s1;
    mixin(normS1S2);
  }
}


/**
 * Computes the Adler-32 checksum.
 *
 * Params:
 *  data = input data
 *
 * Returns:
 *  adler32 checksum
 */
alias adler32 = Adler32;


// -----------------------------------------------------------------------------
// internal data structures
//
private struct Tree {
  ushort[16] table; // table of code length counts
  ushort[288] trans; // code -> symbol translation table

  @disable this (this); // disable copying

  // given an array of code lengths, build a tree
  void buildTree (const(ubyte)[] lengths) @trusted {
    if (lengths.length < 1) throw new Exception("invalid lengths");
    ushort[16] offs = void;
    ushort sum = 0;
    // clear code length count table
    table[] = 0;
    // scan symbol lengths, and sum code length counts
    foreach (immutable l; lengths) {
      if (l >= 16) throw new Exception("invalid lengths");
      ++table.ptr[l];
    }
    table.ptr[0] = 0;
    // compute offset table for distribution sort
    foreach (immutable i, immutable n; table) {
      offs.ptr[i] = sum;
      sum += n;
    }
    // create code->symbol translation table (symbols sorted by code)
    foreach (ushort i, immutable l; lengths) {
      if (l) {
        auto n = offs.ptr[l]++;
        if (n >= 288) throw new Exception("invalid lengths");
        trans.ptr[n] = i;
      }
    }
  }
}


// -----------------------------------------------------------------------------
// stream of unpacked data
//
struct InfStream {
alias ReadBufDg = int delegate (ubyte[] buf);
private:
  // return number of bytes read, -1 on error, 0 on eof; can read less than requested
  ReadBufDg readBuf = null;

  // state data
  uint bytesLeft = void; // bytes to copy both for compressed and for uncompressed blocks
  uint matchOfs = void; // match offset for inflated block
  const(Tree)* lt = void; // dynamic length/symbol tree
  const(Tree)* dt = void; // dynamic distance tree
  bool doingFinalBlock = false; // stop on next processBlockHeader()

  // current state
  enum State {
    ExpectZLibHeader, // expecting ZLib header
    ExpectBlock, // expecting new block
    RawBlock, // uncompressed block
    CompressedBlock,
    EOF, // readOneByte() returns false before block header
    Dead, // some error occured, throw exception on any read
  }
  State state = State.ExpectZLibHeader;
  Mode mode = Mode.ZLib;

  // other data
  ushort tag;
  int bitcount;

  // trees
  Tree ltree; // dynamic length/symbol tree
  Tree dtree; // dynamic distance tree

  // adler-32
  uint a32s1, a32s2;
  uint nmaxLeft = Adler32.NMAX;
  uint cura32;

  // dictionary
  ubyte[65536] dict = void;
  uint dictEnd; // current dict free byte

  ubyte[65536] rdbuf = void;
  int rbpos, rbused;
  bool rbeof;

  void dictPutByte (ubyte bt) nothrow @trusted @nogc {
    if (dictEnd == dict.length) {
      import core.stdc.string : memmove;
      // move dict data
      memmove(dict.ptr, dict.ptr+dictEnd-32768, 32768);
      dictEnd = 32768;
    }
    dict.ptr[dictEnd++] = bt;
    if (mode == Mode.ZLib) {
      a32s1 += bt;
      a32s2 += a32s1;
      if (--nmaxLeft == 0) {
        nmaxLeft = Adler32.NMAX;
        a32s1 %= Adler32.BASE;
        a32s2 %= Adler32.BASE;
      }
    }
  }

  uint finishAdler32 () nothrow @safe @nogc {
    a32s1 %= Adler32.BASE;
    a32s2 %= Adler32.BASE;
    return (a32s2<<16)|a32s1;
  }

  bool readOneByte (ref ubyte bt) {
    //pragma(inline, true);
    if (rbeof) return false;
    if (rbpos >= rbused) {
      rbpos = 0;
      if ((rbused = readBuf(rdbuf[])) <= 0) {
        rbeof = true;
        if (rbused < 0) throw new Exception("inflate read error");
        return false;
      }
    }
    assert(rbpos < rbused);
    bt = rdbuf.ptr[rbpos++];
    return true;
  }

private:
  void setErrorState () nothrow @safe @nogc {
    state = State.Dead;
    lt = dt = null; // just in case
    doingFinalBlock = false; // just in case too
  }

  void processZLibHeader () @trusted {
    scope(failure) setErrorState();
    ubyte cmf, flg;
    // 7 bytes
    // compression parameters
    if (!readOneByte(cmf)) throw new Exception("out of input data");
    // flags
    if (!readOneByte(flg)) throw new Exception("out of input data");
    // check format
    // check checksum
    if ((256*cmf+flg)%31) throw new Exception("invalid zlib checksum");
    // check method (only deflate allowed)
    if ((cmf&0x0f) != 8) throw new Exception("invalid compression method");
    // check window size
    if ((cmf>>4) > 7) throw new Exception("invalid window size");
    // there must be no preset dictionary
    if (flg&0x20) throw new Exception("preset dictionaries are not supported");
    // FYI: flg>>6 will give you compression level:
    //      0 - compressor used fastest algorithm
    //      1 - compressor used fast algorithm
    //      2 - compressor used default algorithm
    //      3 - compressor used maximum compression, slowest algorithm
    // not that you can make any sane use of that info though...
    // note that last 4 bytes is Adler32 checksum in big-endian format
    // init Adler32 counters
    a32s1 = 1;
    a32s2 = 0;
    nmaxLeft = Adler32.NMAX;
    // ok, we can go now
    state = State.ExpectBlock;
  }

  void finishZLibData () {
    // read Adler32
    scope(failure) setErrorState();
    uint a32; // autoinit
    ubyte bt = void;
    foreach_reverse (immutable n; 0..4) {
      if (!readOneByte(bt)) throw new Exception("out of input data");
      a32 |= (cast(uint)bt)<<(n*8);
    }
    if (a32 != finishAdler32()) throw new Exception("invalid checksum");
  }

  // get one bit from source stream
  uint getBit () {
    if (!bitcount--) {
      scope(failure) setErrorState();
      ubyte bt = void;
      if (!readOneByte(bt)) throw new Exception("out of input data");
      tag = bt;
      bitcount = 7;
    }
    uint res = tag&0x01;
    tag >>= 1;
    return res;
  }

  // read a num bit value from a stream and add base
  uint readBits (ubyte num, uint base) {
    uint val = 0;
    if (num) {
      immutable uint limit = 1<<num;
      for (uint mask = 1; mask < limit; mask <<= 1) if (getBit()) val += mask;
    }
    return val+base;
  }

  // given a data stream and a tree, decode a symbol
  uint decodeSymbol (const(Tree*) t) {
    scope(failure) setErrorState();
    int cur, sum, len; // autoinit
    // get more bits while code value is above sum
    do {
      ushort sl;
      cur = 2*cur+getBit();
      ++len;
      if (len >= 16) throw new Exception("invalid symbol");
      sl = t.table.ptr[len];
      sum += sl;
      cur -= sl;
    } while (cur >= 0);
    sum += cur;
    if (sum < 0 || sum >= 288) throw new Exception("invalid symbol");
    return t.trans.ptr[sum];
  }

  // given a data stream, decode dynamic trees from it
  void decodeTrees () {
    scope(failure) setErrorState();
    // special ordering of code length codes
    static immutable ubyte[19] clcidx = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15];
    Tree codeTree;
    ubyte[288+32] lengths;
    uint hlit, hdist, hclen;
    uint num, length;
    // get 5 bits HLIT (257-286)
    hlit = readBits(5, 257);
    // get 5 bits HDIST (1-32)
    hdist = readBits(5, 1);
    if (hlit+hdist > 288+32) throw new Exception("invalid tree");
    // get 4 bits HCLEN (4-19)
    hclen = readBits(4, 4);
    if (hclen > 19) throw new Exception("invalid tree");
    lengths[0..19] = 0;
    // read code lengths for code length alphabet
    foreach (immutable i; 0..hclen) lengths[clcidx[i]] = cast(ubyte)readBits(3, 0); // get 3 bits code length (0-7)
    // build code length tree
    codeTree.buildTree(lengths[0..19]);
    // decode code lengths for the dynamic trees
    for (num = 0; num < hlit+hdist; ) {
      ubyte bt;
      uint sym = decodeSymbol(&codeTree);
      switch (sym) {
        case 16: // copy previous code length 3-6 times (read 2 bits)
          if (num == 0) throw new Exception("invalid tree");
          bt = lengths[num-1];
          length = readBits(2, 3);
          break;
        case 17: // repeat code length 0 for 3-10 times (read 3 bits)
          bt = 0;
          length = readBits(3, 3);
          break;
        case 18: // repeat code length 0 for 11-138 times (read 7 bits)
          bt = 0;
          length = readBits(7, 11);
          break;
        default: // values 0-15 represent the actual code lengths
          if (sym >= 19) throw new Exception("invalid tree symbol");
          length = 1;
          bt = cast(ubyte)sym;
          break;
      }
      // fill it
      if (num+length > 288+32) throw new Exception("invalid tree");
      while (length-- > 0) lengths[num++] = bt;
    }
    // build dynamic trees
    ltree.buildTree(lengths[0..hlit]);
    dtree.buildTree(lengths[hlit..hlit+hdist]);
  }

  // return true if char was read
  bool processInflatedBlock (ref ubyte bt) {
    if (bytesLeft > 0) {
      // copying match; all checks already done
      --bytesLeft;
      bt = dict[dictEnd-matchOfs];
    } else {
      uint sym = decodeSymbol(lt);
      if (sym == 256) {
        // end of block, fix state
        state = State.ExpectBlock;
        return false;
      }
      if (sym < 256) {
        // normal
        bt = cast(ubyte)sym;
      } else {
        scope(failure) setErrorState();
        // copy
        uint dist, length, offs;
        sym -= 257;
        // possibly get more bits from length code
        if (sym >= 30) throw new Exception("invalid symbol");
        length = readBits(lengthBits[sym], lengthBase[sym]);
        dist = decodeSymbol(dt);
        if (dist >= 30) throw new Exception("invalid distance");
        // possibly get more bits from distance code
        offs = readBits(distBits[dist], distBase[dist]);
        if (offs > dictEnd) throw new Exception("invalid distance");
        // copy match
        bytesLeft = length;
        matchOfs = offs;
        return false; // no byte read yet
      }
    }
    return true;
  }

  // return true if char was read
  bool processUncompressedBlock (ref ubyte bt) {
    if (bytesLeft > 0) {
      // copying
      scope(failure) setErrorState();
      if (!readOneByte(bt)) throw new Exception("out of input data");
      --bytesLeft;
      return true;
    }
    return false;
  }

  ushort readU16 () {
    scope(failure) setErrorState();
    ubyte b0 = void, b1 = void;
    if (!readOneByte(b0)) throw new Exception("out of input data");
    if (!readOneByte(b1)) throw new Exception("out of input data");
    return cast(ushort)(b0|(b1<<8));
  }

  void processRawHeader () {
    ushort length = readU16();
    ushort invlength = readU16(); // one's complement of length
    // check length
    if (length != cast(ushort)(~invlength)) { setErrorState(); throw new Exception("invalid uncompressed block length"); }
    bitcount = 0; // make sure we start next block on a byte boundary
    bytesLeft = length;
    state = State.RawBlock;
  }

  void processFixedHeader () nothrow @safe @nogc {
    lt = &sltree;
    dt = &sdtree;
    bytesLeft = 0; // force reading of symbol (just in case)
    state = State.CompressedBlock;
  }

  void processDynamicHeader () {
    // decode trees from stream
    decodeTrees();
    lt = &ltree;
    dt = &dtree;
    bytesLeft = 0; // force reading of symbol (just in case)
    state = State.CompressedBlock;
  }

  // set state to State.EOF on correct EOF
  void processBlockHeader () {
    if (doingFinalBlock) {
      if (mode == Mode.ZLib) finishZLibData();
      doingFinalBlock = false;
      state = State.EOF;
      return;
    }
    doingFinalBlock = (getBit() != 0); // final block flag
    // read block type (2 bits) and fix state
    switch (readBits(2, 0)) {
      case 0: processRawHeader(); break; // uncompressed block
      case 1: processFixedHeader(); break; // block with fixed huffman trees
      case 2: processDynamicHeader(); break; // block with dynamic huffman trees
      default: setErrorState(); throw new Exception("invalid input block type");
    }
  }

public:
  /// stream format
  enum Mode { ZLib, Deflate }

  /// disable copying
  @disable this (this);

  /**
   * Initialize decompression stream.
   *
   * Params:
   *  dgb = byte reader;
   *        must either set bt to next byte and return true or return false on EOF;
   *        note that it will not be called anymore after EOF or error;
   *        can be null
   *  amode = stream format; either headerless 'deflate' stream or 'zlib' stream
   *
   * Throws:
   *  on error
   */
  this (ReadBufDg dgb, Mode amode=Mode.ZLib) {
    if (dgb is null) assert(0, "wtf?!");
    reinit(dgb, amode);
  }

  /// Ditto.
  void reinit (ReadBufDg dgb=null, Mode amode=Mode.ZLib) {
    if (dgb !is null) readBuf = dgb;
    rbpos = rbused = 0;
    rbeof = false;
    mode = amode;
    tag = 0;
    bitcount = 0;
    dictEnd = 0;
    state = (amode == Mode.ZLib ? State.ExpectZLibHeader : State.ExpectBlock);
    doingFinalBlock = false;
  }

  /**
   * Check stream header. Can be called after this() or reinit().
   *
   * Returns:
   *  nothing
   *
   * Throws:
   *  on error
   */
  void checkStreamHeader () {
    if (mode == Mode.ZLib && state == State.ExpectZLibHeader) processZLibHeader();
  }

  /**
   * Get another byte from stream.
   *
   * Returns:
   *  one decompressed byte in `bt` and `true`, or `false`, and `bt` is undefined
   *
   * Throws:
   *  Exception on error
   */
  bool getOneByte (ref ubyte bt) {
    bool gotbyte = false;
    do {
      final switch (state) {
        case State.ExpectZLibHeader: processZLibHeader(); break;
        case State.ExpectBlock: processBlockHeader(); break;
        case State.RawBlock: gotbyte = processUncompressedBlock(bt); break;
        case State.CompressedBlock: gotbyte = processInflatedBlock(bt); break;
        case State.EOF: return false;
        case State.Dead: setErrorState(); throw new Exception("dead stream"); break;
      }
    } while (!gotbyte);
    dictPutByte(bt);
    return true;
  }

  /**
   * Get another byte from stream.
   *
   * Returns:
   *  one decompressed byte
   *
   * Throws:
   *  Exception on EOF/error
   */
  ubyte getByte () {
    ubyte res = void;
    if (!getOneByte(res)) throw new Exception("no more data");
    return res;
  }

  /**
   * Read bytes from stream. Almost similar to File.rawRead().
   *
   * Params:
   *  buf = destination buffer
   *
   * Returns:
   *  destination buffer or slice of destination buffer if EOF encountered
   *
   * Throws:
   *  on error
   */
  T[] rawRead(T) (T[] buf) {
    auto len = buf.length*T.sizeof;
    auto dst = cast(ubyte*)buf.ptr;
    ubyte res = void;
    while (len--) {
      if (!getOneByte(*dst)) {
        // check if the last 'dest' item is fully decompressed
        static if (T.sizeof > 1) { if ((cast(size_t)dst-buf.ptr)%T.sizeof) { setErrorState(); throw new Exception("partial data"); } }
        return buf[0..cast(size_t)(dst-buf.ptr)];
      }
      ++dst;
    }
    return buf;
  }

  @property bool eof () const pure nothrow @safe @nogc { pragma(inline, true); return (state == State.EOF); }
  @property bool invalid () const pure nothrow @safe @nogc { pragma(inline, true); return (state == State.Dead); }
}


// -----------------------------------------------------------------------------
private:
// private global data
// build it using CTFE

// fixed length/symbol tree
static immutable Tree sltree = (){
  Tree sl;
  sl.table[7] = 24;
  sl.table[8] = 152;
  sl.table[9] = 112;
  foreach (immutable i; 0..24) sl.trans[i] = cast(ushort)(256+i);
  foreach (immutable ushort i; 0..144) sl.trans[24+i] = i;
  foreach (immutable i; 0..8) sl.trans[24+144+i] = cast(ushort)(280+i);
  foreach (immutable i; 0..112) sl.trans[24+144+8+i] = cast(ushort)(144+i);
  return sl;
}();

// fixed distance tree
static immutable Tree sdtree = (){
  Tree sd;
  sd.table[5] = 32;
  foreach (immutable ushort i; 0..32) sd.trans[i] = i;
  return sd;
}();

void fillBits (ubyte[] bits, uint delta) @safe nothrow {
  bits[0..delta] = 0;
  foreach (immutable i; 0..30-delta) bits[i+delta] = cast(ubyte)(i/delta);
}

void fillBase (ushort[] base, immutable(ubyte[30]) bits, ushort first) @safe nothrow {
  ushort sum = first;
  foreach (immutable i; 0..30) {
    base[i] = sum;
    sum += 1<<bits[i];
  }
}

// extra bits and base tables for length codes
static immutable ubyte[30] lengthBits = (){
  ubyte[30] bits;
  fillBits(bits, 4);
  bits[28] = 0; // fix a special case
  return bits;
}();

static immutable ushort[30] lengthBase = (){
  ubyte[30] bits;
  ushort[30] base;
  fillBits(bits, 4);
  fillBase(base, bits, 3);
  base[28] = 258; // fix a special case
  return base;
}();

// extra bits and base tables for distance codes
static immutable ubyte[30] distBits = (){
  ubyte[30] bits;
  fillBits(bits, 2);
  return bits;
}();

static immutable ushort[30] distBase = (){
  enum bits = distBits;
  ushort[30] base;
  fillBase(base, bits, 1);
  return base;
}();


InfStream ifs;
