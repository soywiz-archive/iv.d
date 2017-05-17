// simple library for dealing with Ogg containers
module zogg /*is aliced*/;

import iv.alice;
//import iv.cmdcon;
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
  long firstdatapgofs = -1;
  ulong firstgranule;

  // current page info
  bool pgbos, pgeos, pgcont;
  ulong pggranule;
  ubyte segments;
  uint pgseqno, pgserno;
  uint pglength, pgdatalength;
  ubyte[255] seglen;
  uint curseg; // for packet reader

  PageInfo lastpage;

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
    pggranule = grpos;
    pgseqno = sequenceno;
    pgserno = serialno;
    pglength = len;
    pgdatalength = len-Offsets.Lacing-segcount;
    return true;
  }

  long getfpos () {
    return fl.tell-bufused+bufpos;
  }

  // scan for page
  bool nextPage(bool first, bool ignoreseqno=false) (long maxbytes=long.max) {
    if (eofhit) return false;
    scope(failure) eofhit = true;
    curseg = 0;
    static if (!first) bufpos += pglength; // skip page data
    clearPage();
    while (maxbytes >= Offsets.Lacing) {
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
        uint rdx = cast(uint)buf.length-bufused;
        if (rdx > maxbytes) rdx = cast(uint)maxbytes;
        auto rd = fl.rawRead(buf[bufused..bufused+rdx]);
        if (rd.length == 0) break;
        bufused += cast(uint)rd.length;
        maxbytes -= cast(uint)rd.length;
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
              firstdatapgofs = (pggranule && pggranule != -1 ? firstpagepos : -1);
              firstgranule = pggranule;
              serno = pgserno;
              seqno = pgseqno;
              return true;
            } else {
              if (serno == pgserno) {
                //conwriteln("2: bufpos=", bufpos, "; bufused=", bufused, "; segs: ", seglen[0..segments], "; pgseqno=", pgseqno, "; seqno=", seqno, "; pgserno=", pgserno, "; serno=", serno);
                static if (!ignoreseqno) {
                  bool ok = (seqno+1 == pgseqno);
                  if (ok) ++seqno;
                } else {
                  enum ok = true;
                }
                if (ok) {
                  if (firstdatapgofs == -1 && pggranule && pggranule != -1) {
                    firstdatapgofs = fl.tell-bufused+bufpos;
                    firstgranule = pggranule;
                  }
                  //conwriteln("3: bufpos=", bufpos, "; bufused=", bufused, "; segs: ", seglen[0..segments], "; pgseqno=", pgseqno, "; seqno=", seqno, "; pgserno=", pgserno, "; serno=", serno);
                  return true;
                }
                // alas
                static if (!ignoreseqno) {
                  eofhit = true;
                  return false;
                }
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
    return false;
  }

  void clearPage () {
    pgbos = pgeos = pgcont = false;
    pggranule = 0;
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
    lastpage = lastpage.init;
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

  static struct PageInfo {
    uint seqnum;
    ulong granule;
    long pgfpos = -1;
  }

  bool findLastPage (out PageInfo pi) {
    if (lastpage.pgfpos >= 0) {
      pi = lastpage;
      return true;
    }
    enum ChunkSize = 65535;
    if (buf.length-bufused < ChunkSize) buf.length = bufused+ChunkSize;
    auto lastfpos = fl.tell;
    scope(success) fl.seek(lastfpos);
    auto flsize = fl.size;
    if (flsize < 0) return false;
    // linear scan backward
    auto flpos = flsize-firstpagepos-ChunkSize;
    if (flpos < firstpagepos) flpos = firstpagepos;
    for (;;) {
      fl.seek(flpos);
      fl.rawReadExact(buf[bufused..bufused+ChunkSize]);
      uint pos = bufused+ChunkSize-27;
      uint pend = bufused+ChunkSize;
      for (;;) {
        if (buf.ptr[pos] == 'O' && buf.ptr[pos+1] == 'g' && buf.ptr[pos+2] == 'g' && buf.ptr[pos+3] == 'S') {
          ulong gran = getMemInt!ulong(buf.ptr+pos+Offsets.Granulepos);
          if (gran > 0 && gran != -1 && buf.ptr[pos+Offsets.Version] == 0 && getMemInt!uint(buf.ptr+pos+Offsets.Serialno) == serno) {
            // ok, possible page found
            bool rereadbuf = false;
            auto opos = pos;
            // calc page size
            ubyte segs = buf.ptr[pos+Offsets.Segments];
            uint pgsize = Offsets.Lacing+segs;
            ubyte[4] zeroes = 0;
            ubyte* p;
            uint newcrc;
            //conwritefln!"0x%08x (left: %s; pgsize0=%s)"(flpos+opos-bufused, pend-pos, pgsize);
            if (pend-pos < pgsize) {
              // load page
              pos = pend = bufused;
              rereadbuf = true;
              fl.seek(flpos+opos-bufused);
              for (uint bp = 0; bp < MaxPageSize; ) {
                auto rd = fl.rawRead(buf.ptr[pos+bp..pos+MaxPageSize]);
                if (rd.length == 0) {
                  if (bp < pgsize) goto badpage;
                  break;
                }
                bp += cast(uint)rd.length;
                pend += cast(uint)rd.length;
              }
            }
            foreach (ubyte ss; buf.ptr[pos+Offsets.Lacing..pos+Offsets.Lacing+segs]) pgsize += ss;
            //conwritefln!"0x%08x (left: %s; pgsize1=%s)"(flpos+opos-bufused, pend-pos, pgsize);
            if (pend-pos < pgsize) {
              // load page
              pos = bufused;
              rereadbuf = true;
              fl.seek(flpos+opos-bufused);
              for (uint bp = 0; bp < MaxPageSize; ) {
                auto rd = fl.rawRead(buf.ptr[pos+bp..pos+MaxPageSize]);
                if (rd.length == 0) {
                  if (bp < pgsize) goto badpage;
                  break;
                }
                bp += cast(uint)rd.length;
                pend += cast(uint)rd.length;
              }
            }
            // check page CRC
            p = buf.ptr+pos;
            newcrc = crc32(p[0..Offsets.Crc]);
            newcrc = crc32(zeroes[], newcrc); // per spec
            newcrc = crc32(p[Offsets.Crc+4..pgsize], newcrc);
            if (newcrc != getMemInt!uint(p+Offsets.Crc)) goto badpage;
            pi.seqnum = getMemInt!uint(p+Offsets.Sequenceno);
            pi.granule = gran;
            pi.pgfpos = flpos+opos-bufused;
            lastpage = pi;
            return true;
           badpage:
            if (rereadbuf) {
              fl.seek(flpos);
              fl.rawReadExact(buf[bufused..bufused+ChunkSize]);
              pos = opos;
              pend = bufused+ChunkSize;
            }
          }
        }
        if (pos == bufused) break; // prev chunk
        --pos;
      }
      if (flpos == firstpagepos) break; // not found
      flpos -= ChunkSize-30;
      if (flpos < firstpagepos) flpos = firstpagepos;
    }
    return false;
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
    packetGranule = pggranule;
    packetBop = (curseg == 0);
    if (curseg >= segments) {
      if (!nextPage!false()) return false;
      if (pgcont || pgbos) throw new Exception("invalid starting Ogg page");
      packetBos = pgbos;
      packetBop = true;
      packetGranule = pggranule;
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

  /* Page granularity seek (faster than sample granularity because we
     don't do the last bit of decode to find a specific sample).

     Seek to the last [granule marked] page preceding the specified pos
     location, such that decoding past the returned point will quickly
     arrive at the requested position. */
  public bool seekPCM (long pos) {
    enum ChunkSize = 65535;

    // rescales the number x from the range of [0,from] to [0,to] x is in the range [0,from] from, to are in the range [1, 1<<62-1]
    static long rescale64 (long x, long from, long to) {
      if (x >= from) return to;
      if (x <= 0) return 0;

      long frac = 0;
      long ret = 0;

      foreach (immutable _; 0..64) {
        if (x >= from) { frac |= 1; x -= from; }
        x <<= 1;
        frac <<= 1;
      }

      foreach (immutable _; 0..64) {
        if (frac&1) ret += to;
        frac >>= 1;
        ret >>= 1;
      }

      return ret;
    }

    if (pos < 0) return 0;
    if (pos <= firstdatapgofs) {
      bufused = bufpos = 0;
      pglength = 0;
      curseg = 0;
      fl.seek(firstpagepos);
      if (!nextPage!true()) throw new Exception("can't find valid Ogg page");
      if (pgcont || !pgbos) throw new Exception("invalid starting Ogg page");
      for (;;) {
        if (!loadPacket()) throw new Exception("can't load Ogg packet");
        if (packetGranule && packetGranule != -1) break;
      }
      return true;
    }

    if (lastpage.pgfpos < 0) {
      PageInfo pi;
      if (!findLastPage(pi)) throw new Exception("can't find last Ogg page");
    }

    if (firstdatapgofs < 0) assert(0, "internal error");

    if (pos > lastpage.granule) pos = lastpage.granule;

    if (buf.length < ChunkSize) buf.length = ChunkSize;

    long total = lastpage.granule;

    {
      long end = lastpage.pgfpos;
      long begin = firstdatapgofs;
      long begintime = 0/*firstgranule*/;
      long endtime = lastpage.granule;
      long target = pos;//-total+begintime;
      long best = -1;
      bool got_page = false;

      // if we have only one page, there will be no bisection: grab the page here
      if (begin == end) {
        bufused = bufpos = 0;
        pglength = 0;
        curseg = 0;
        fl.seek(begin);
        if (!nextPage!false()) return false;
        if (!loadPacket()) return false;
        return true;
      }

      // bisection loop
      while (begin < end) {
        long bisect;

        if (end-begin < ChunkSize) {
          bisect = begin;
        } else {
          // take a (pretty decent) guess
          bisect = begin+rescale64(target-begintime, endtime-begintime, end-begin)-ChunkSize;
          if (bisect < begin+ChunkSize) bisect = begin;
          //conwriteln("begin=", begin, "; end=", end, "; bisect=", bisect, "; rsc=", rescale64(target-begintime, endtime-begintime, end-begin));
        }

        bufused = bufpos = 0;
        pglength = 0;
        curseg = 0;
        fl.seek(bisect);

        // read loop within the bisection loop
        while (begin < end) {
          // hack for nextpage
          if (!nextPage!(false, true)(end-getfpos)) {
            // there is no next page!
            if (bisect <= begin+1) {
              // no bisection left to perform: we've either found the best candidate already or failed; exit loop
              end = begin;
            } else {
              // we tried to load a fraction of the last page; back up a bit and try to get the whole last page
              if (bisect == 0) goto seek_error;
              bisect -= ChunkSize;

              // don't repeat/loop on a read we've already performed
              if (bisect <= begin) bisect = begin+1;

              // seek and continue bisection
              bufused = bufpos = 0;
              pglength = 0;
              curseg = 0;
              fl.seek(bisect);
            }
          } else {
            //conwriteln("page #", pgseqno, " (", pggranule, ") at ", getfpos);
            long granulepos;
            got_page = true;

            // got a page: analyze it
            // only consider pages from primary vorbis stream
            if (pgserno != serno) continue;

            // only consider pages with the granulepos set
            granulepos = pggranule;
            if (granulepos == -1) continue;
            //conwriteln("pos=", pos, "; gran=", granulepos, "; target=", target);

            if (granulepos < target) {
              // this page is a successful candidate! Set state
              best = getfpos; // raw offset of packet with granulepos
              begin = getfpos+pglength; // raw offset of next page
              begintime = granulepos;

              // if we're before our target but within a short distance, don't bisect; read forward
              if (target-begintime > 48000) break;

              bisect = begin; // *not* begin+1 as above
            } else {
              // this is one of our pages, but the granpos is post-target; it is not a bisection return candidate
              // the only way we'd use it is if it's the first page in the stream; we handle that case later outside the bisection
              if (bisect <= begin+1) {
                // no bisection left to perform: we've either found the best candidate already or failed; exit loop
                end = begin;
              } else {
                if (end == getfpos+pglength) {
                  // bisection read to the end; use the known page boundary (result) to update bisection, back up a little bit, and try again
                  end = getfpos;
                  bisect -= ChunkSize;
                  if (bisect <= begin) bisect = begin+1;
                  bufused = bufpos = 0;
                  pglength = 0;
                  curseg = 0;
                  fl.seek(bisect);
                } else {
                  // normal bisection
                  end = bisect;
                  endtime = granulepos;
                  break;
                }
              }
            }
          }
        }
      }

      // out of bisection: did it 'fail?'
      if (best == -1) {
        /+
        // check the 'looking for data in first page' special case;
        // bisection would 'fail' because our search target was before the first PCM granule position fencepost
        if (got_page && begin == firstdatapgofs && ogg_page_serialno(&og) == vf.serialnos[link]) {
          // yes, this is the beginning-of-stream case; we already have our page, right at the beginning of PCM data -- set state and return
          vf.pcm_offset = total;
          if (link != vf.current_link) {
            // different link; dump entire decode machine
            decode_clear_(vf);
            vf.current_link = link;
            vf.current_serialno = vf.serialnos[link];
            vf.ready_state = STREAMSET;
          } else {
            vorbis_synthesis_restart(&vf.vd);
          }
          ogg_stream_reset_serialno(&vf.os, vf.current_serialno);
          ogg_stream_pagein(&vf.os, &og);
        } else {
          goto seek_error;
        }
        +/
        //goto seek_error;
        bufused = bufpos = 0;
        pglength = 0;
        curseg = 0;
        fl.seek(firstpagepos);
        if (!nextPage!true()) throw new Exception("can't find valid Ogg page");
        if (pgcont || !pgbos) throw new Exception("invalid starting Ogg page");
        for (;;) {
          if (!loadPacket()) throw new Exception("can't load Ogg packet");
          if (packetGranule && packetGranule != -1) break;
        }
        return false;
      } else {
        // bisection found our page. seek to it, update pcm offset; easier case than raw_seek, don't keep packets preceding granulepos
        bufused = bufpos = 0;
        pglength = 0;
        curseg = 0;
        fl.seek(best);
        if (!nextPage!(false, true)()) throw new Exception("wtf?!");
        seqno = pgseqno;
        // pull out all but last packet; the one with granulepos
        for (int p = 0; p < segments; ++p) if (seglen[p] < 255) curseg = p+1;
        if (!loadPacket()) throw new Exception("wtf?!");
      }
    }

    return true;

   seek_error:
    throw new Exception("wtf?!");
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
