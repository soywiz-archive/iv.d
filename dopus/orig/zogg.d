// simple library for dealing with Ogg containers
module zogg;

import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public struct OggStream {
private:
  enum MaxPageSize = 65025+Offsets.Lacing+255;
  //pragma(msg, MaxPageSize); // 65307 bytes
  //enum MaxPageSize = 65536;

  // Ogg header entry offsets
  enum Offsets {
    Capture = 0,
    Version = 4,
    Flags = 5,
    Granulepos = 6,
    Serialno = 14,
    Sequenceno = 18,
    Crc = 22,
    Segments = 26,
    Lacing = 27,
  }

private:
  VFile fl;
  ubyte[] buf;
  uint bufpos, bufused;
  uint serno, seqno;
  bool eofhit; // "end-of-stream" hit
  long logStreamSize;
  ulong bytesRead;
  ulong newpos;
  long firstpagepos;

  // current page info
  bool pgbos, pgeos, pgcont;
  ulong granulepos;
  ubyte segments;
  uint pgseqno, pgserno;
  uint pglength, pgdatalength;
  ubyte[255] seglen;
  uint curseg; // for packet reader

public:
  bool packetBos;
  bool packetEos;
  bool packetBop; // first packet in page?
  bool packetEop; // last packet in page?
  ulong packetGranule;
  ubyte[] packetData;
  uint packetLength;

private:
  bool ensureBytes (uint len) {
    import core.stdc.string : memmove;
    if (len > buf.length) assert(0, "internal OggStream error");
    if (bufused-bufpos >= len) return true;
    if (eofhit) return false;
    // shift bytes
    if (bufused-bufpos > 0) {
      memmove(buf.ptr, buf.ptr+bufpos, bufused-bufpos);
      bufused -= bufpos;
      bufpos = 0;
    } else {
      bufused = bufpos = 0;
    }
    assert(bufpos == 0);
    assert(bufused < len);
    while (bufused < len) {
      auto rd = fl.rawRead(buf[bufused..len]);
      if (rd.length == 0) { eofhit = true; return false; }
      bufused += cast(uint)rd.length;
    }
    return true;
  }

  bool parsePageHeader () {
    if (!ensureBytes(Offsets.Lacing)) return false;
    if (!ensureBytes(Offsets.Lacing+buf.ptr[bufpos+Offsets.Segments])) return false;
    if (bufpos >= bufused) return false;
    auto p = (cast(const(ubyte)*)buf.ptr)+bufpos;
    if (p[0] != 'O' || p[1] != 'g' || p[2] != 'g' || p[3] != 'S') return false;
    if (p[Offsets.Version] != 0) return false;
    ubyte flags = p[Offsets.Flags];
    if ((flags&~0x07) != 0) return false;
    ulong grpos = getMemInt!ulong(p+Offsets.Granulepos);
    uint serialno = getMemInt!uint(p+Offsets.Serialno);
    uint sequenceno = getMemInt!uint(p+Offsets.Sequenceno);
    uint crc = getMemInt!uint(p+Offsets.Crc);
    ubyte segcount = p[Offsets.Segments];
    if (!ensureBytes(Offsets.Lacing+segcount)) return false;
    p = (cast(const(ubyte)*)buf.ptr)+bufpos;
    // calculate page size
    uint len = Offsets.Lacing+segcount;
    foreach (ubyte b; p[Offsets.Lacing..Offsets.Lacing+segcount]) len += b;
    if (!ensureBytes(len)) return false; // alas, invalid page
    //conwriteln("len=", len);
    p = (cast(const(ubyte)*)buf.ptr)+bufpos;
    // check page crc
    uint newcrc = crc32(p[0..Offsets.Crc]);
    ubyte[4] zeroes = 0;
    newcrc = crc32(zeroes[], newcrc); // per spec
    newcrc = crc32(p[Offsets.Crc+4..len], newcrc);
    if (newcrc != crc) return false; // bad crc
    // setup values for valid page
    pgcont = (flags&0x01 ? true : false);
    pgbos = (flags&0x02 ? true : false);
    pgeos = (flags&0x04 ? true : false);
    segments = segcount;
    if (segcount) seglen[0..segcount] = p[Offsets.Lacing..Offsets.Lacing+segcount];
    granulepos = grpos;
    pgseqno = sequenceno;
    pgserno = serialno;
    pglength = len;
    pgdatalength = len-Offsets.Lacing-segcount;
    return true;
  }

  // scan for page
  bool nextPage(bool first) () {
    if (eofhit) return false;
    scope(failure) eofhit = true;
    curseg = 0;
    static if (!first) bufpos += pglength; // skip page data
    clearPage();
    for (;;) {
      //conwriteln("0: bufpos=", bufpos, "; bufused=", bufused);
      while (bufpos >= bufused || bufused-bufpos < 4) {
        if (eofhit) break;
        if (bufpos < bufused) {
          import core.stdc.string : memmove;
          memmove(buf.ptr, buf.ptr+bufpos, bufused-bufpos);
          bufused -= bufpos;
          bufpos = 0;
        } else {
          bufpos = bufused = 0;
        }
        auto rd = fl.rawRead(buf[bufused..$]);
        if (rd.length == 0) break;
        bufused += cast(uint)rd.length;
      }
      //conwriteln("1: bufpos=", bufpos, "; bufused=", bufused, "; bleft=", bufused-bufpos);
      if (bufpos >= bufused || bufused < 4) { eofhit = true; return false; }
      uint bleft = bufused-bufpos;
      auto b = (cast(const(ubyte)*)buf.ptr)+bufpos;
      while (bleft >= 4) {
        if (b[0] == 'O' && b[1] == 'g' && b[2] == 'g' && b[3] == 'S') {
          bufpos = bufused-bleft;
          if (parsePageHeader()) {
            //conwriteln("1: bufpos=", bufpos, "; bufused=", bufused, "; segs: ", seglen[0..segments], "; pgseqno=", pgseqno, "; seqno=", seqno, "; pgserno=", pgserno, "; serno=", serno);
            eofhit = pgeos;
            static if (first) {
              firstpagepos = fl.tell-bufused+bufpos;
              serno = pgserno;
              seqno = pgseqno;
              return true;
            } else {
              if (serno == pgserno) {
                //conwriteln("2: bufpos=", bufpos, "; bufused=", bufused, "; segs: ", seglen[0..segments], "; pgseqno=", pgseqno, "; seqno=", seqno, "; pgserno=", pgserno, "; serno=", serno);
                if (seqno+1 == pgseqno) {
                  ++seqno;
                  //conwriteln("3: bufpos=", bufpos, "; bufused=", bufused, "; segs: ", seglen[0..segments], "; pgseqno=", pgseqno, "; seqno=", seqno, "; pgserno=", pgserno, "; serno=", serno);
                  return true;
                }
                // alas
                eofhit = true;
                return false;
              }
            }
            // continue
          } else {
            if (eofhit) return false;
          }
          bleft = bufused-bufpos;
          b = (cast(const(ubyte)*)buf.ptr)+bufpos;
        }
        ++b;
        --bleft;
      }
    }
  }

  void clearPage () {
    pgbos = pgeos = pgcont = false;
    granulepos = 0;
    segments = 0;
    pgseqno = pgserno = 0;
    pglength = pgdatalength = 0;
    seglen[] = 0;
  }

  void clearPacket () {
    packetBos = packetBop = packetEop = packetEos = false;
    packetGranule = 0;
    packetData[] = 0;
    packetLength = 0;
  }

public:
  void close () {
    fl = fl.init;
    bufpos = bufused = 0;
    curseg = 0;
    bytesRead = 0;
    eofhit = true;
    firstpagepos = 0;
    bytesRead = newpos = 0;
    logStreamSize = -1;
    clearPage();
    clearPacket();
  }

  void setup (VFile afl) {
    scope(failure) close();
    close();
    if (buf.length < MaxPageSize) buf.length = MaxPageSize;
    fl = afl;
    eofhit = false;
    if (!nextPage!true()) throw new Exception("can't find valid Ogg page");
    if (pgcont || !pgbos) throw new Exception("invalid starting Ogg page");
    if (!loadPacket()) throw new Exception("can't load Ogg packet");
  }

  // end of stream?
  @property bool eos () const pure nothrow @safe @nogc { pragma(inline, true); return eofhit; }

  // logical beginning of stream?
  @property bool bos () const pure nothrow @safe @nogc { pragma(inline, true); return pgbos; }

  bool loadPacket () {
    //conwritefln!"serno=0x%08x; seqno=%s"(serno, seqno);
    packetLength = 0;
    packetBos = pgbos;
    packetEos = pgeos;
    packetGranule = granulepos;
    packetBop = (curseg == 0);
    if (curseg >= segments) {
      if (!nextPage!false()) return false;
      if (pgcont || pgbos) throw new Exception("invalid starting Ogg page");
      packetBos = pgbos;
      packetBop = true;
      packetGranule = granulepos;
    }
    for (;;) {
      uint copyofs = bufpos+Offsets.Lacing+segments;
      foreach (ubyte psz; seglen[0..curseg]) copyofs += psz;
      uint copylen = 0;
      bool endofpacket = false;
      while (!endofpacket && curseg < segments) {
        copylen += seglen[curseg];
        endofpacket = (seglen[curseg++] < 255);
      }
      //conwriteln("copyofs=", copyofs, "; copylen=", copylen, "; eop=", eop, "; packetLength=", packetLength, "; segments=", segments, "; curseg=", curseg);
      if (copylen > 0) {
        if (packetLength+copylen > 1024*1024*32) throw new Exception("Ogg packet too big");
        if (packetLength+copylen > packetData.length) packetData.length = packetLength+copylen;
        packetData[packetLength..packetLength+copylen] = buf.ptr[copyofs..copyofs+copylen];
        packetLength += copylen;
      }
      if (endofpacket) {
        packetEop = (curseg >= segments);
        packetEos = pgeos;
        return true;
      }
      assert(curseg >= segments);
      // get next page
      if (!nextPage!false()) return false;
      if (!pgcont || pgbos) throw new Exception("invalid cont Ogg page");
    }
  }

static:
  T getMemInt(T) (const(void)* pp) {
    static if (is(T == byte) || is(T == ubyte)) {
      return *cast(const(ubyte)*)pp;
    } else static if (is(T == short) || is(T == ushort)) {
      version(LittleEndian) {
        return *cast(const(T)*)pp;
      } else {
        auto pp = cast(const(ubyte)*)pp;
        return cast(T)(pp[0]|(pp[1]<<8));
      }
    } else static if (is(T == int) || is(T == uint)) {
      version(LittleEndian) {
        return *cast(const(T)*)pp;
      } else {
        auto pp = cast(const(ubyte)*)pp;
        return cast(T)(pp[0]|(pp[1]<<8)|(pp[2]<<16)|(pp[3]<<24));
      }
    } else static if (is(T == long) || is(T == ulong)) {
      version(LittleEndian) {
        return *cast(const(T)*)pp;
      } else {
        auto pp = cast(const(ubyte)*)pp;
        return cast(T)(
          (cast(ulong)pp[0])|((cast(ulong)pp[1])<<8)|((cast(ulong)pp[2])<<16)|((cast(ulong)pp[3])<<24)|
          ((cast(ulong)pp[4])<<32)|((cast(ulong)pp[5])<<40)|((cast(ulong)pp[6])<<48)|((cast(ulong)pp[7])<<56)
        );
      }
    } else {
      static assert(0, "invalid type for getMemInt: '"~T.stringof~"'");
    }
  }

  uint crc32 (const(void)[] buf, uint crc=0) nothrow @trusted @nogc {
    static immutable uint[256] crctable = (){
      // helper to initialize lookup for direct-table CRC (illustrative; we use the static init below)
      static uint _ogg_crc_entry (uint index) {
        uint r = index<<24;
        foreach (immutable _; 0..8) {
          if (r&0x80000000U) {
            r = (r<<1)^0x04c11db7;
            /* The same as the ethernet generator
                polynomial, although we use an
                unreflected alg and an init/final
                of 0, not 0xffffffff */
          } else {
            r <<= 1;
          }
        }
        return (r&0xffffffffU);
      }
      uint[256] res;
      foreach (immutable idx, ref uint v; res[]) v = _ogg_crc_entry(cast(uint)idx);
      return res;
    }();
    foreach (ubyte b; cast(const(ubyte)[])buf) crc = (crc<<8)^crctable.ptr[((crc>>24)&0xFF)^b];
    return crc;
  }
}
