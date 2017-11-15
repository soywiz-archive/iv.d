module btcblk is aliced;


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
      fd = core.sys.posix.fcntl.open(afname.tempCString, O_RDONLY|O_CLOEXEC|O_DIRECT|O_NOATIME);
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
public align(1) struct BtcBlock {
align(1):
public:
  enum Magic : uint {
    Main = 0xD9B4BEF9U,
    TestNet = 0xDAB5BFFAU,
    TestNet3 = 0x0709110BU,
    NameCoin = 0xFEB4BEF9U,
  }

  align(1) struct Header {
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

private:
  T getvl(T, bool dochecks=true) (ref usize ofs) const @trusted if (is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
    version(BigEndian) {
      static assert(0, "not yet");
    } else {
      import core.stdc.string : memcpy;
      static if (dochecks) if (ofs >= membuf.length) throw new Exception("malformed block");
      ulong v = membuf.ptr[ofs++];
      if (v == 0xFD) {
        static if (dochecks) if (membuf.length-ofs < 3) throw new Exception("malformed block");
        memcpy(&v, membuf.ptr+ofs, 2);
        ofs += 2;
      } else if (v == 0xFE) {
        static if (dochecks) if (membuf.length-ofs < 5) throw new Exception("malformed block");
        memcpy(&v, membuf.ptr+ofs, 4);
        ofs += 4;
      } else if (v == 0xFF) {
        static if (dochecks) if (membuf.length-ofs < 9) throw new Exception("malformed block");
        memcpy(&v, membuf.ptr+ofs, 8);
        ofs += 8;
      }
      static if (!is(T == ulong)) {
        if (v > T.max) throw new Exception("value too big");
      }
      return cast(T)v;
    }
  }

  void skipInput (ref usize ofs) const @trusted {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // id[32]
    if (membuf.length-ofs < 32) throw new Exception("malformed block");
    ofs += 32;
    // vout
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    ofs += 4;
    // script
    uint scsz = getvl!uint(ofs);
    if (membuf.length-ofs < scsz) throw new Exception("malformed block");
    ofs += scsz;
    // seq
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    ofs += 4;
  }

  void skipOutput (ref usize ofs) const @trusted {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // value
    if (membuf.length-ofs < 8) throw new Exception("malformed block");
    ofs += 8;
    // script
    uint scsz = getvl!uint(ofs);
    if (membuf.length-ofs < scsz) throw new Exception("malformed block");
    ofs += scsz;
  }

  void skipTx(bool skiplocktime=true) (ref usize ofs) const @trusted {
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // version
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    ofs += 4;
    // inputs
    uint icount = getvl!ushort(ofs);
    while (icount-- > 0) skipInput(ofs);
    // outputs
    uint ocount = getvl!ushort(ofs);
    while (ocount-- > 0) skipOutput(ofs);
    static if (skiplocktime) {
      if (membuf.length-ofs < 4) throw new Exception("malformed block");
      ofs += 4;
    }
  }

private:
  const(ubyte)[] membuf;

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

  this (const(void)[] abuf) {
    //pragma(inline, true);
    if (abuf.length < Header.sizeof) throw new Exception("malformed block");
    membuf = cast(const(ubyte)[])abuf;
    scope(failure) membuf = null; // ease GC pressure
  }

  void clear () nothrow @nogc { pragma(inline, true); membuf = null; }

  @property bool valid () const pure nothrow @nogc { pragma(inline, true); return (membuf.length > Header.sizeof); }
  @property auto header () const nothrow @nogc { pragma(inline, true); return (membuf.length > Header.sizeof ? cast(const Header*)membuf.ptr : cast(const Header*)null); }

  @property int txcount () const {
    usize ofs = Header.sizeof;
    return cast(int)getvl!ushort(ofs);
  }

  @property uint txofs (usize idx) const {
    usize ofs = Header.sizeof;
    uint txc = getvl!ushort(ofs);
    if (idx >= txc) return 0; //throw new Exception("invalid index");
    //{ import core.stdc.stdio; printf("txc=%u; hsz=%u; ofs=%u\n", txc, cast(uint)Header.sizeof, cast(uint)ofs); }
    while (idx-- > 0) skipTx(ofs);
    return cast(uint)ofs;
  }

  // 0: no more
  @property uint txnext (uint txofs) const {
    if (txofs == 0) return 0;
    usize ofs = txofs;
    skipTx(ofs);
    return (membuf.length-ofs > 0 ? cast(uint)ofs : 0);
  }

  @property uint txver (uint txofs) const {
    if (txofs == 0) return 0;
    if (membuf.length-txofs < 4) throw new Exception("malformed block");
    return *cast(const(uint)*)(membuf.ptr+txofs);
  }

  @property int icount (uint txofs) const {
    if (txofs == 0) return 0;
    if (txofs < Header.sizeof+1) throw new Exception("invalid transaction offset");
    usize ofs = txofs+4; // skip version
    return cast(int)getvl!ushort(ofs);
  }

  @property int ocount (uint txofs) const {
    if (txofs == 0) return 0;
    if (txofs < Header.sizeof+1) throw new Exception("invalid transaction offset");
    usize ofs = txofs+4; // skip version
    uint icount = getvl!ushort(ofs);
    while (icount-- > 0) skipInput(ofs);
    return cast(int)getvl!ushort(ofs);
  }

  @property uint locktime (uint txofs) const {
    if (txofs == 0) return 0;
    if (txofs < Header.sizeof+1) throw new Exception("invalid transaction offset");
    usize ofs = txofs;
    skipTx!false(ofs);
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    return *cast(const(uint)*)(membuf.ptr+ofs);
  }

  @property Input getInput (uint txofs, usize idx) const {
    if (txofs < Header.sizeof+1) throw new Exception("invalid transaction offset");
    usize ofs = txofs+4; // skip version
    int icount = getvl!ushort(ofs);
    if (idx >= icount) throw new Exception("invalid index");
    while (idx-- > 0) skipInput(ofs);
    // read input
    Input res;
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // id[32]
    if (membuf.length-ofs < 32) throw new Exception("malformed block");
    res.id = membuf.ptr[ofs..ofs+32];
    ofs += 32;
    // outnum
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    res.vout = *cast(const(uint)*)(membuf.ptr+ofs);
    ofs += 4;
    // script
    uint scsz = getvl!uint(ofs);
    if (membuf.length-ofs < scsz) throw new Exception("malformed block");
    res.script = membuf.ptr[ofs..ofs+scsz];
    ofs += scsz;
    // seq
    if (membuf.length-ofs < 4) throw new Exception("malformed block");
    res.seq = *cast(const(uint)*)(membuf.ptr+ofs);
    // done
    return res;
  }

  @property Output getOutput (uint txofs, usize idx) const {
    if (txofs < Header.sizeof+1) throw new Exception("invalid transaction offset");
    usize ofs = txofs+4; // skip version
    int icount = getvl!ushort(ofs);
    while (icount-- > 0) skipInput(ofs);
    int ocount = getvl!ushort(ofs);
    if (idx >= ocount) throw new Exception("invalid index");
    while (idx-- > 0) skipOutput(ofs);
    // read output
    Output res;
    if (ofs >= membuf.length) throw new Exception("malformed block");
    // value
    if (membuf.length-ofs < 8) throw new Exception("malformed block");
    res.value = *cast(const(ulong)*)(membuf.ptr+ofs);
    ofs += 8;
    // script
    uint scsz = getvl!uint(ofs);
    if (membuf.length-ofs < scsz) throw new Exception("malformed block");
    res.script = membuf.ptr[ofs..ofs+scsz];
    // done
    return res;
  }
}
