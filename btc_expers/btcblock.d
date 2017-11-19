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
module btcblock is aliced;


// ////////////////////////////////////////////////////////////////////////// //
public struct MMapFile {
private:
  static struct SharedData {
    int rc; // refcounter
    int fd; // file descriptor
    char* fname; // 0-terminated, 'cause why not?
    ubyte* mbuf; // mmaped
    uint mbufsize;
  public:
    // `rc` won't be touched; throws on errors
    void setup (const(char)[] afname) @trusted {
      //import core.sys.posix.sys.mman;
      import core.sys.linux.sys.mman;
      import core.sys.posix.fcntl;
      import core.sys.posix.unistd;
      import core.stdc.stdio : SEEK_CUR, SEEK_END, SEEK_SET;
      import std.internal.cstring;
      fd = core.sys.posix.fcntl.open(afname.tempCString, O_RDONLY|O_CLOEXEC|O_DIRECT/*|O_NOATIME*/);
      if (fd < 0) throw new Exception("cannot open file '"~afname.idup~"'");
      scope(failure) { core.sys.posix.unistd.close(fd); fd = -1; }
      auto size = lseek(fd, 0, SEEK_END);
      if (size > uint.max/4) throw new Exception("file '"~afname.idup~"' too big");
      if (lseek(fd, 0, SEEK_SET) == cast(off_t)-1) throw new Exception("seek error in file '"~afname.idup~"'");
      mbufsize = cast(uint)size;
      if (mbufsize > 0) {
        mbuf = cast(ubyte*)mmap(null, mbufsize, PROT_READ, MAP_PRIVATE, fd, 0);
        if (mbuf is null) throw new Exception("cannot mmap file '"~afname.idup~"'");
      }
      scope(failure) { munmap(mbuf, mbufsize); mbuf = null; }
      if (afname.length) {
        import core.stdc.stdlib : malloc;
        import core.stdc.string : memcpy;
        fname = cast(char*)malloc(afname.length+1);
        if (fname is null) assert(0, "out of memory");
        memcpy(fname, afname.ptr, afname.length);
        fname[afname.length] = 0;
      } else {
        fname = null;
      }
    }

    // `fd` and `rc` must be already deinitialized
    void clear () nothrow @trusted @nogc {
      if (fname !is null) {
        import core.stdc.stdlib : free;
        free(fname);
        fname = null;
      }
      if (mbuf !is null) {
        import core.sys.linux.sys.mman;
        munmap(mbuf, mbufsize);
        mbuf = null;
      }
      mbufsize = 0;
      if (fd >= 0) {
        import core.sys.posix.unistd;
        core.sys.posix.unistd.close(fd);
        fd = -1;
      }
    }
  }

private:
  usize sdptr;

private:
  void addref () nothrow @trusted @nogc {
    pragma(inline, true);
    if (sdptr) ++(cast(SharedData*)sdptr).rc;
  }

  void decref () {
    if (sdptr) {
      if (--(cast(SharedData*)sdptr).rc == 0) {
        import core.stdc.stdlib : free;
        (cast(SharedData*)sdptr).clear();
        free(cast(void*)sdptr);
        sdptr = 0;
      }
    }
  }

public:
  this (const(char)[] fname) { open(fname); }
  this() (in auto ref MMapFile afl) { sdptr = afl.sdptr; addref(); }
  this (this) { addref(); }
  ~this () { decref(); }

  void opAssign() (in auto ref MMapFile afl) {
    pragma(inline, true);
    // order matters!
    if (afl.sdptr) ++(cast(SharedData*)afl.sdptr).rc;
    decref();
    sdptr = afl.sdptr;
  }

  void open (const(char)[] fname) {
    import core.stdc.stdlib : calloc, free;
    auto sd = cast(SharedData*)calloc(1, SharedData.sizeof);
    if (sd is null) assert(0, "out of memory");
    scope(failure) free(sd);
    sd.rc = 1;
    sd.setup(fname);
    sdptr = cast(usize)sd;
  }

  void close () { decref(); }

  @property bool isOpen () const pure nothrow @safe @nogc { pragma(inline, true); return (sdptr != 0); }

  @property uint size () const nothrow @trusted @nogc { pragma(inline, true); return (sdptr ? (cast(const(SharedData)*)sdptr).mbufsize : 0); }

  alias length = size;
  alias opDollar = size;

  const(ubyte)[] opSlice () @trusted {
    if (!sdptr) return null;
    auto sd = cast(SharedData*)sdptr;
    return sd.mbuf[0..sd.mbufsize];
  }

  const(ubyte)[] opSlice (usize lo, usize hi) @trusted {
    if (!sdptr || lo >= hi) return null;
    auto sd = cast(SharedData*)sdptr;
    if (hi > sd.mbufsize) throw new Exception("invalid index");
    return sd.mbuf[lo..hi];
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public string bin2hex(string mode="BE") (const(ubyte)[] buf) @trusted nothrow {
  static assert(mode == "BE" || mode == "LE", "invalid mode: '"~mode~"'");
  static immutable string hexd = "0123456789abcdef";
  if (buf.length == 0) return null;
  auto res = new char[](buf.length*2);
  auto d = res.ptr;
  static if (mode == "LE") {
    foreach (immutable ubyte b; buf[]) {
      *d++ = hexd.ptr[b>>4];
      *d++ = hexd.ptr[b&0x0f];
    }
  } else {
    foreach (immutable ubyte b; buf[]; reverse) {
      *d++ = hexd.ptr[b>>4];
      *d++ = hexd.ptr[b&0x0f];
    }
  }
  return cast(string)res;
}


// ////////////////////////////////////////////////////////////////////////// //
public struct MemBuffer {
  const(ubyte)[] membuf;
  uint ofs;

  this (const(void)[] abuf) pure nothrow @safe @nogc {
    membuf = cast(const(ubyte)[])abuf;
  }

  @property usize length () const pure nothrow @safe @nogc { pragma(inline, true); return (ofs < membuf.length ? membuf.length-ofs : 0); }

  @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (ofs >= membuf.length); }

  void clear () pure nothrow @safe @nogc { pragma(inline, true); membuf = null; ofs = 0; }

  T getvl(T, bool dochecks=true) () @trusted if (is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
    import core.stdc.string : memcpy;
    static if (dochecks) if (ofs >= membuf.length) throw new Exception("malformed block");
    ulong v = membuf.ptr[ofs++];
    if (v == 0xFD) {
      static if (dochecks) if (membuf.length-ofs < 3) throw new Exception("malformed block");
      version(BigEndian) {
        v = membuf.ptr[ofs]|(membuf.ptr[ofs+1]<<8);
      } else {
        memcpy(&v, membuf.ptr+ofs, 2);
      }
      ofs += 2;
    } else if (v == 0xFE) {
      static if (dochecks) if (membuf.length-ofs < 5) throw new Exception("malformed block");
      version(BigEndian) {
        v = membuf.ptr[ofs]|(membuf.ptr[ofs+1]<<8)|(membuf.ptr[ofs+2]<<16)|(membuf.ptr[ofs+3]<<24);
      } else {
        memcpy(&v, membuf.ptr+ofs, 4);
      }
      ofs += 4;
    } else if (v == 0xFF) {
      static if (dochecks) if (membuf.length-ofs < 9) throw new Exception("malformed block");
      version(BigEndian) {
        v = cast(ulong)(membuf.ptr[ofs]|(membuf.ptr[ofs+1]<<8)|(membuf.ptr[ofs+2]<<16)|(membuf.ptr[ofs+3]<<24))|
          ((cast(ulong)(membuf.ptr[ofs+4]))<<32)|
          ((cast(ulong)(membuf.ptr[ofs+5]))<<40)|
          ((cast(ulong)(membuf.ptr[ofs+6]))<<48)|
          ((cast(ulong)(membuf.ptr[ofs+7]))<<56);
      } else {
        memcpy(&v, membuf.ptr+ofs, 8);
      }
      ofs += 8;
    }
    static if (!is(T == ulong)) {
      if (v > T.max) throw new Exception("value too big");
    }
    return cast(T)v;
  }

  T get(T, bool dochecks=true) () @trusted if (is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
    static if (dochecks) {
      if (ofs >= membuf.length) throw new Exception("malformed block");
      if (membuf.length-ofs < T.sizeof) throw new Exception("malformed block");
    }
    version(BigEndian) {
      static if (T.sizeof == 1) {
        T res = *cast(const(T)*)(membuf.ptr+ofs);
      } else static if (T.sizeof == 2) {
        T res = cast(T)(membuf.ptr[ofs]|(membuf.ptr[ofs+1]<<8));
      } else {
        import core.bitop : bswap;
        T res = bswap(*cast(const(T)*)(membuf.ptr+ofs));
      }
    } else {
      T res = *cast(const(T)*)(membuf.ptr+ofs);
    }
    ofs += cast(uint)T.sizeof;
    return res;
  }

  //FIXME: overflow checks
  void getbuf(T) (ref T[] buf) @trusted if (is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
    import core.stdc.string : memcpy;
    if (ofs >= membuf.length) throw new Exception("malformed block");
    if (membuf.length-ofs < buf.length*T.sizeof) throw new Exception("malformed block");
    memcpy(buf.ptr, membuf.ptr+ofs, buf.length*T.sizeof);
    ofs += cast(uint)(buf.length*T.sizeof);
  }

  //FIXME: overflow checks
  const(T)[] getbufnc(T) (uint len) @trusted if (is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    if (membuf.length-ofs < len*T.sizeof) throw new Exception("malformed block");
    auto res = cast(const(T)[])(membuf.ptr[ofs..ofs+len*T.sizeof]);
    ofs += cast(uint)(len*T.sizeof);
    return res;
  }

  void skipInput () @trusted {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // id[32]
    if (membuf.length-ofs < 32) throw new Exception("malformed block");
    ofs += 32;
    // vout
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    ofs += 4;
    // script
    uint scsz = getvl!uint;
    if (membuf.length-ofs < scsz) throw new Exception("malformed block");
    ofs += scsz;
    // seq
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    ofs += 4;
  }

  void skipOutput () @trusted {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // value
    if (membuf.length-ofs < 8) throw new Exception("malformed block");
    ofs += 8;
    // script
    uint scsz = getvl!uint;
    if (membuf.length-ofs < scsz) throw new Exception("malformed block");
    ofs += scsz;
  }

  void skipTx(bool skiplocktime=true) () @trusted {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // version
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    ofs += 4;
    // inputs
    uint icount = getvl!ushort;
    while (icount-- > 0) skipInput();
    // outputs
    uint ocount = getvl!ushort;
    while (ocount-- > 0) skipOutput();
    static if (skiplocktime) {
      if (membuf.length-ofs < 4) throw new Exception("malformed block");
      ofs += 4;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public align(1) struct BtcBlock {
align(1):
public:
  enum Magic : uint {
    Main = 0xD9B4BEF9U,
    TestNet = 0xDAB5BFFAU,
    TestNet3 = 0x0709110BU,
    NameCoin = 0xFEB4BEF9U,
  }

  align(1) static struct Header {
  align(1):
    uint ver;
    const(ubyte)[32] prev;
    const(ubyte)[32] root;
    uint time; // unix
    uint bits;
    uint nonce;

    ubyte[32] decodeBits () const nothrow @trusted @nogc {
      ubyte[32] res = 0;
      if (bits > 0x1d00ffff) assert(0, "bits is too big");
      int len = (bits>>24)&0xff;
      if (len < 6 || len > 30) assert(0, "fucked block");
      res[len-3] = bits&0xff;
      res[len-2] = (bits>>8)&0xff;
      res[len-1] = (bits>>16)&0xff;
      return res;
    }

    string bits2str () const {
      static immutable string hexd = "0123456789abcdef";
      if (bits > 0x1d00ffff) assert(0, "bits is too big");
      int len = (bits>>24)&0xff;
      if (len < 6 || len > 30) assert(0, "fucked block");
      char[64] res = '0';
      int pos = cast(int)(res.length)-len*2;
      foreach (immutable bc; 0..3) {
        ubyte b = (bits>>((2-bc)*8))&0xff;
        res[pos+0] = hexd[b>>4];
        res[pos+1] = hexd[b&0x0f];
        pos += 2;
      }
      return res[].idup;
    }
  }

  align(1) static struct Input {
  align(1):
    const(ubyte)[] id; // [32]
    uint vout;
    const(ubyte)[] script;
    uint seq;
  }

  align(1) static struct Output {
  align(1):
    ulong value; // satoshis
    const(ubyte)[] script;
  }

public:
  private static struct TxInOutRange(FT, string parser) {
  private:
    MemBuffer mbuf;
    uint cur, len;
    FT crec;

  private:
    void xparse() () { mixin(parser); }

    // no need to validate anything here
    this (in ref MemBuffer abuf, uint aofs, int acount) @trusted {
      mbuf.membuf = abuf.membuf[aofs..$];
      len = acount;
      if (acount > 0) xparse();
    }

  public:
    @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (cur >= len); }
    @property uint length () const pure nothrow @safe @nogc { pragma(inline, true); return len-cur; }

    @property FT front () const pure nothrow @trusted @nogc { pragma(inline, true); return crec; }

    void popFront () {
      pragma(inline, true);
      if (cur < len) {
        ++cur;
        if (cur < len) xparse();
      }
    }
  }

  public alias TxInRange = TxInOutRange!(Input, q{
    // id[32]
    crec.id = mbuf.getbufnc!ubyte(32);
    // outnum
    crec.vout = mbuf.get!uint;
    // script
    uint scsz = mbuf.getvl!uint;
    crec.script = mbuf.getbufnc!ubyte(scsz);
    // seq
    crec.seq = mbuf.get!uint;
  });

  public alias TxOutRange = TxInOutRange!(Output, q{
    // value
    crec.value = mbuf.get!ulong;
    // script
    uint scsz = mbuf.getvl!uint;
    crec.script = mbuf.getbufnc!ubyte(scsz);
  });


  static struct Tx {
  private:
    MemBuffer mbuf;
    int icount, ocount;
    uint iofs, oofs;
    uint txver;
    uint txlocktm;

  private:
    this (in ref MemBuffer abuf, uint atxofs) @trusted {
      mbuf.membuf = abuf.membuf[atxofs..$];
      scope(failure) mbuf.clear();
      txver = mbuf.get!uint;
      icount = mbuf.getvl!ushort;
      iofs = mbuf.ofs;
      //{ import core.stdc.stdio; printf("txver=%u; icount=%u; iofs=%u\n", txver, icount, iofs); }
      foreach (immutable _; 0..icount) mbuf.skipInput();
      ocount = mbuf.getvl!ushort;
      oofs = mbuf.ofs;
      //{ import core.stdc.stdio; printf(" ocount=%u; oofs=%u\n", ocount, oofs); }
      foreach (immutable _; 0..ocount) mbuf.skipOutput();
      txlocktm = mbuf.get!uint;
      // drop alien data
      mbuf.membuf = mbuf.membuf[0..mbuf.ofs];
    }

  public:
    @property uint ver () const pure nothrow @safe @nogc { pragma(inline, true); return txver; }
    @property uint locktime () const pure nothrow @safe @nogc { pragma(inline, true); return txlocktm; }

    @property int incount () const pure nothrow @safe @nogc { pragma(inline, true); return icount; }
    @property int outcount () const pure nothrow @safe @nogc { pragma(inline, true); return ocount; }

    @property auto data () const pure nothrow @trusted @nogc { pragma(inline, true); return mbuf.membuf; }

    // calculate txid; return reversed txid, 'cause this is how it is stored in inputs
    @property ubyte[32] txid () const pure nothrow @trusted @nogc {
      import std.digest.sha : sha256Of;
      auto dg0 = sha256Of(mbuf.membuf);
      dg0 = sha256Of(dg0[]);
      version(none) {
        foreach (immutable idx, ref ubyte b; dg0[0..16]) {
          ubyte t = dg0.ptr[31-idx];
          dg0.ptr[31-idx] = t;
          b = t;
        }
      }
      return dg0;
    }

    TxInRange inputs () const @safe { return TxInRange(mbuf, iofs, icount); }
    TxOutRange outputs () const @safe { return TxOutRange(mbuf, oofs, ocount); }
  }


  static struct TxRange {
  private:
    MemBuffer mbuf;
    uint txn, txe;

  private:
    this (in ref MemBuffer abuf, usize txlo, usize txhi) @trusted {
      mbuf.membuf = abuf.membuf;
      mbuf.ofs = cast(uint)BtcBlock.Header.sizeof;
      auto txc = mbuf.getvl!uint;
      if (txlo >= txhi || txlo >= txc) {
        mbuf.ofs = 0;
      } else {
        //{ import core.stdc.stdio; printf("txlo=%u; txhi=%u; txc=%u\n", cast(uint)txlo, cast(uint)txhi, cast(uint)txc); }
        while (txn < txlo) { mbuf.skipTx(); ++txn; }
        txe = (txhi <= txc ? cast(uint)txhi : txc);
      }
    }

  public:
    @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (txn >= txe); }
    @property uint length () const pure nothrow @safe @nogc { pragma(inline, true); return txe-txn; }

    @property Tx front () const @trusted {
      pragma(inline, true);
      if (txn >= txe) assert(0, "no front element in empty range");
      return Tx(mbuf, mbuf.ofs);
    }

    void popFront () {
      pragma(inline, true);
      if (txn < txe) {
        ++txn;
        mbuf.skipTx();
      }
    }
  }

private:
  MemBuffer mbuf;

public @trusted:
  // throws on invalid data
  static const(ubyte)[] getPackedData (const(ubyte)[] abuf) {
    if (abuf.length < 8) throw new Exception("invalid packet size");
    auto magic = *cast(const(uint)*)(abuf.ptr);
    auto len = *cast(const(uint)*)(abuf.ptr+4);
    if (magic != Magic.Main && magic != Magic.TestNet && magic != Magic.TestNet3 && magic != Magic.NameCoin) throw new Exception("invalid packet signature");
    if (len < Header.sizeof+1 || len >= uint.max-16) throw new Exception("invalid packet size");
    if (8+len > abuf.length) throw new Exception("invalid packet size");
    return abuf[8..8+len];
  }

  // returns zero-length slice on EOF
  static const(ubyte)[] skipPackedData (const(ubyte)[] abuf) {
    if (abuf.length == 0) return null;
    if (abuf.length < 8) throw new Exception("invalid packet size");
    auto magic = *cast(const(uint)*)(abuf.ptr);
    auto len = *cast(const(uint)*)(abuf.ptr+4);
    if (magic != Magic.Main && magic != Magic.TestNet && magic != Magic.TestNet3 && magic != Magic.NameCoin) throw new Exception("invalid packet signature");
    if (8+len > abuf.length || len >= uint.max-16) throw new Exception("invalid packet size");
    if (8+len == abuf.length) return null;
    return abuf[8+len..$];
  }

  static uint packedDataSize (const(ubyte)[] abuf) {
    if (abuf.length == 0) return 0;
    if (abuf.length < 8) throw new Exception("invalid packet size");
    auto magic = *cast(const(uint)*)(abuf.ptr);
    auto len = *cast(const(uint)*)(abuf.ptr+4);
    if (magic != Magic.Main && magic != Magic.TestNet && magic != Magic.TestNet3 && magic != Magic.NameCoin) throw new Exception("invalid packet signature");
    if (8+len > abuf.length || len >= uint.max-16) throw new Exception("invalid packet size");
    return len+8;
  }

  // advance abuf offset past the block
  this (ref MemBuffer abuf, uint amagic=Magic.Main) @trusted {
    if (abuf.length < 8) throw new Exception("malformed block");
    auto magic = abuf.get!uint;
    if (magic != amagic) throw new Exception("invalid packet magic");
    auto len = abuf.get!uint;
    if (len >= uint.max-16 || len > abuf.length) throw new Exception("invalid packet size");
    if (len < Header.sizeof) throw new Exception("malformed block");
    mbuf.membuf = abuf.membuf[abuf.ofs..abuf.ofs+len];
    mbuf.ofs = cast(uint)Header.sizeof;
    abuf.ofs += len;
  }

  void clear () nothrow @nogc { pragma(inline, true); mbuf.clear(); }

  @property bool valid () const pure nothrow @nogc { pragma(inline, true); return (mbuf.length > Header.sizeof); }
  @property auto header () const nothrow @nogc { pragma(inline, true); return (mbuf.length > Header.sizeof ? cast(const Header*)mbuf.membuf.ptr : cast(const Header*)null); }

  @property int txcount () const {
    MemBuffer xmbuf = mbuf;
    xmbuf.ofs = cast(uint)Header.sizeof;
    return cast(int)xmbuf.getvl!ushort;
  }

  @property usize length () const { pragma(inline, true); return txcount; }
  alias opDollar = length;

  TxRange opSlice () const { pragma(inline, true); return TxRange(mbuf, 0, length); }
  TxRange opSlice (usize lo, usize hi) const { pragma(inline, true); return TxRange(mbuf, lo, hi); }
}
