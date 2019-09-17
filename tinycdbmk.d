/* This file is a part of tinycdb package by Michael Tokarev, mjt@corpit.ru.
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
 *
 * D translation by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 */
// CDB key/value database creator
module iv.tinycdbmk /*is aliced*/;

import iv.alice;


struct CDBMaker {
private static import iv.tinycdb;
public:
  alias hash = iv.tinycdb.CDB.hash;

private:
  align(1) static struct Rec {
  align(1):
    uint hval;
    uint rpos;
  }

  static struct RecList {
    RecList *next;
    uint count;
    Rec[254] rec;
  }

  int mFD = -1; /* file descriptor */
  bool mCloseFD;
  uint mDataPos; /* data position so far */
  uint mRCount; /* record count so far */
  ubyte[4096] mBuf = void; /* write buffer */
  ubyte* mBufPos; /* current buf position */
  RecList*[256] mTables; /* list of arrays of record infos */
  bool mWasError;

public:
  enum {
    PUT_ADD = 0,      /* add unconditionnaly, like cdb_make_add() */
    PUT_REPLACE,      /* replace: do not place to index OLD record */
    PUT_INSERT,       /* add only if not already exists */
    PUT_WARN,         /* add unconditionally but ret. 1 if exists */
    PUT_REPLACE0,     /* if a record exists, fill old one with zeros */
    //
    FIND = PUT_ADD,
    FIND_REMOVE = PUT_REPLACE,
    FIND_FILL0 = PUT_REPLACE0,
  }

public:
nothrow:
  @disable this (this); // no copying

  this (string fname) { create(fname); }

  bool create (string fname) {
    import std.string : toStringz;
    import core.sys.posix.fcntl : xopen = open, O_CREAT, O_RDWR, O_TRUNC;
    close();
    int fd = xopen(fname.toStringz, O_RDWR|O_CREAT|O_TRUNC, 384);
    if (fd >= 0) {
      mCloseFD = true;
      create(fd);
      return true;
    }
    return false;
  }

@nogc:
  ~this () { close(); }

  this (int fd) @nogc { create(fd); }

  @property bool opened () const pure @safe { return (mFD >= 0); }
  @property bool valid () const pure @safe { return (mFD >= 0 && !mWasError); }

  //TODO: seek to start and truncate
  void create (int fd) {
    close();
    mFD = fd;
    mDataPos = 2048;
    mBufPos = mBuf.ptr+2048;
    mBuf[] = 0;
    if (!seek(0)) mWasError = true;
  }

  bool close () {
    bool res = true;
    if (mFD >= 0) {
      res = finish();
      if (mCloseFD) {
        import core.sys.posix.unistd : xclose = close;
        xclose(mFD);
      }
      foreach (immutable t; 0..256) {
        auto rl = mTables[t];
        while (rl !is null) {
          import core.stdc.stdlib : free;
          auto tm = rl;
          rl = rl.next;
          free(tm);
        }
      }
      res = !mWasError;
      mFD = -1;
      mCloseFD = false;
      mDataPos = 0;
      mRCount = 0;
      mBufPos = null;
      mTables[] = null;
      mWasError = false;
    }
    return res;
  }

  bool find (const(void)[] key, int mode, bool *err=null) {
    if (err !is null) *err = false;
    auto res = findRecord(key, hash(key), mode);
    if (err !is null && res == FindRes.ERROR) *err = true;
    return (res == FindRes.FOUND);
  }
  bool exists (const(void)[] key) { return (findRecord(key, hash(key), FIND) == FindRes.FOUND); }

  bool add (const(void)[] key, const(void)[] val) { return addRecord(hash(key), key, val); }

  // true: record was replaced
  // false: new record or error
  bool put (const(void)[] key, const(void)[] val, int mode=PUT_ADD, bool *err=null) {
    if (err !is null) *err = false;
    uint hval = hash(key);
    FindRes r;
    switch (mode) {
      case PUT_REPLACE:
      case PUT_INSERT:
      case PUT_WARN:
      case PUT_REPLACE0:
        r = findRecord(key, hval, mode);
        if (r == FindRes.ERROR) {
          if (err !is null) *err = true;
          return false;
        }
        if (r == FindRes.FOUND && mode == PUT_INSERT) return /*errno = EEXIST,*/true;
        break;
      case PUT_ADD:
        r = FindRes.NOT_FOUND;
        break;
      default:
        if (err !is null) *err = true;
        return /*errno = EINVAL,*/false;
    }
    if (!addRecord(hval, key, val)) {
      if (err !is null) *err = true;
      return false;
    }
    return (r == FindRes.FOUND);
  }

private:
  private bool seek (uint pos) {
    import core.sys.posix.unistd : lseek;
    import core.stdc.stdio : SEEK_SET;
    return (lseek(mFD, pos, SEEK_SET) >= 0);
  }

  private bool fullRead (ubyte* buf, uint len) {
    while (len) {
      import core.stdc.errno;
      import core.sys.posix.unistd : read;
      auto l = read(mFD, cast(void*)buf, len);
      if (l > 0) {
        len -= l;
        buf += l;
      } else if (l == 0 || (l < 0 && errno != EINTR)) {
        return false;
      }
    }
    return true;
  }

  private int read (ubyte* buf, uint len) {
    immutable flen = len;
    while (len) {
      import core.stdc.errno;
      static import core.sys.posix.unistd;
      auto l = core.sys.posix.unistd.read(mFD, cast(void*)buf, len);
      if (l > 0) {
        len -= l;
        buf += l;
      } else if (l < 0 && errno != EINTR) {
        return -1;
      } else if (l == 0) {
        break;
      }
    }
    return cast(int)(flen-len);
  }

  private bool fullWrite (const(void)* bufp, uint len) {
    auto buf = cast(const(ubyte)*)bufp;
    while (len) {
      import core.stdc.errno;
      import core.sys.posix.unistd : write;
      auto l = write(mFD, cast(const void*)buf, len);
      if (l > 0) {
        len -= l;
        buf += l;
      } else if (l == 0 || (l < 0 && errno != EINTR)) {
        return false;
      }
    }
    return true;
  }

  private bool flush () {
    uint len = cast(uint)(mBufPos-mBuf.ptr);
    if (len) {
      if (!fullWrite(mBuf.ptr, len)) return false;
      mBufPos = mBuf.ptr;
    }
    return true;
  }

  private bool write (const(void)* ptrp, uint len) {
    import core.stdc.string : memcpy;
    auto ptr = cast(const(ubyte)*)ptrp;
    uint l = cast(uint)(mBuf.sizeof-(mBufPos-mBuf.ptr));
    mDataPos += len;
    if (len > l) {
      if (l) memcpy(mBufPos, ptr, l);
      mBufPos += l;
      if (!flush()) return false;
      ptr += l;
      len -= l;
      l = cast(uint)(len/mBuf.sizeof);
      if (l) {
        l *= cast(uint)mBuf.sizeof;
        if (!fullWrite(ptr, l)) return false;
        ptr += l;
        len -= l;
      }
    }
    if (len) {
      memcpy(mBufPos, ptr, len);
      mBufPos += len;
    }
    return true;
  }

  private bool finish () {
    uint[256] hcnt; /* hash table counts */
    uint[256] hpos; /* hash table positions */
    Rec* htab;
    ubyte* p;
    RecList* rl;
    uint hsize;

    if (((0xffffffffu-mDataPos)>>3) < mRCount) {
      mWasError = true;
      return /*errno = ENOMEM, -1*/false;
    }

    /* count htab sizes and reorder reclists */
    hsize = 0;
    foreach (immutable uint t; 0..256) {
      RecList* rlt = null;
      uint i = 0;
      rl = mTables[t];
      while (rl) {
        RecList* rln = rl.next;
        rl.next = rlt;
        rlt = rl;
        i += rl.count;
        rl = rln;
      }
      mTables[t] = rlt;
      if (hsize < (hcnt[t] = i<<1)) hsize = hcnt[t];
    }

    import core.stdc.stdlib : malloc, free;
    /* allocate memory to hold max htable */
    htab = cast(Rec*)malloc((hsize+2)*htab[0].sizeof);
    if (htab is null) {
      mWasError = true;
      return /*errno = ENOENT, -1*/false;
    }
    p = cast(ubyte*)htab;
    htab += 2;

    /* build hash tables */
    foreach (immutable uint t; 0..256) {
      uint len, hi;
      hpos[t] = mDataPos;
      if ((len = hcnt[t]) == 0) continue;
      foreach (immutable i; 0..len) htab[i].hval = htab[i].rpos = 0;
      for (rl = mTables[t]; rl !is null; rl = rl.next) {
        foreach (immutable i; 0..rl.count) {
          hi = (rl.rec[i].hval>>8)%len;
          while (htab[hi].rpos) if (++hi == len) hi = 0;
          htab[hi] = rl.rec[i];
        }
      }
      foreach (immutable i; 0..len) {
        pack(htab[i].hval, p+(i<<3));
        pack(htab[i].rpos, p+(i<<3)+4);
      }
      if (!write(p, len<<3)) {
        mWasError = true;
        free(p);
        return false;
      }
    }
    free(p);
    if (!flush()) {
      mWasError = true;
      return false;
    }

    p = mBuf.ptr;
    foreach (immutable t; 0..256) {
      pack(hpos[t], p+(t<<3));
      pack(hcnt[t], p+(t<<3)+4);
    }

    if (!seek(0) || !fullWrite(p, 2048)) {
      mWasError = true;
      return false;
    }

    return true;
  }

  private bool addRecord (uint hval, const(void)[] key, const(void)[] val) {
    immutable klen = cast(uint)key.length;
    if (klen == 0) return false;
    immutable vlen = cast(uint)val.length;
    ubyte[8] rlen;
    RecList *rl;
    uint i;
    if (klen > 0xffffffffu-(mDataPos+8) || vlen > 0xffffffffu-(mDataPos+klen+8)) {
      mWasError = true;
      return /*errno = ENOMEM, -1*/false;
    }
    i = hval&0xff; // hash table number
    rl = mTables[i];
    if (rl is null || rl.count >= rl.rec.length) {
      // new chunk
      import core.stdc.stdlib : malloc;
      rl = cast(RecList*)malloc(RecList.sizeof);
      if (rl is null) return /*errno = ENOMEM, -1*/false;
      rl.count = 0;
      rl.next = mTables[i];
      mTables[i] = rl;
    }
    i = rl.count++;
    rl.rec[i].hval = hval;
    rl.rec[i].rpos = mDataPos;
    ++mRCount;
    pack(klen, rlen.ptr);
    pack(vlen, rlen.ptr+4);
    if (!write(rlen.ptr, 8) || !write(key.ptr, klen) || !write(val.ptr, vlen)) {
      mWasError = true;
      return false;
    }
    return true;
  }

  void fixupRPos (uint rpos, uint rlen) {
    hashloop: foreach (immutable i; 0..256) {
      for (auto rl = mTables[i]; rl !is null; rl = rl.next) {
        Rec *rp, rs;
        for (rs = rl.rec.ptr, rp = rs+rl.count; --rp >= rs;) {
          if (rp.rpos <= rpos) continue hashloop;
          else rp.rpos -= rlen;
        }
      }
    }
  }

  bool removeRecord (uint rpos, uint rlen) {
    uint len = cast(uint)(mDataPos-rpos-rlen);
    uint pos;
    int r;
    mDataPos -= rlen;
    if (!len) return false; /* it was the last record, nothing to do */
    pos = rpos;
    do {
      r = cast(int)(len > mBuf.sizeof ? mBuf.sizeof : len);
      if (!seek(pos+rlen) || (r = read(mBuf.ptr, r)) <= 0) {
        mWasError = true;
        return false;
      }
      if (!seek(pos) || !fullWrite(mBuf.ptr, r)) {
        mWasError = true;
        return false;
      }
      pos += r;
      len -= r;
    } while (len);
    assert(mDataPos == pos);
    fixupRPos(rpos, rlen);
    return true;
  }

  bool zeroFillRecord (uint rpos, uint rlen) {
    if (rpos+rlen == mDataPos) {
      mDataPos = rpos;
      return true;
    }
    if (!seek(rpos)) return false;
    mBuf[] = 0;
    pack(rlen-8, mBuf.ptr+4);
    for (;;) {
      rpos = cast(uint)(rlen > mBuf.sizeof ? mBuf.sizeof : rlen);
      if (!fullWrite(mBuf.ptr, rpos)) {
        mWasError = true;
        return false;
      }
      rlen -= rpos;
      if (!rlen) return true;
      mBuf[4..8] = 0;
    }
  }

  enum ERR = 1;
  enum NOTF = 0;
  /* return: 0 = not found, 1 = error; >1 = record length */
  uint matchKey (uint pos, const(void)[] key) {
    auto klen = cast(uint)key.length;
    if (klen < 1) return ERR;
    if (!seek(pos)) return ERR;
    if (!fullRead(mBuf.ptr, 8)) return ERR;
    if (unpack(mBuf.ptr) != klen) return NOTF;
    /* record length; check its validity */
    uint rlen = unpack(mBuf.ptr+4);
    if (rlen > mDataPos-pos-klen-8) return /*errno = EPROTO, 1*/ERR; /* someone changed our file? */
    rlen += klen+8;
    /* compare key */
    if (klen < mBuf.sizeof) {
      import core.stdc.string : memcmp;
      if (!fullRead(mBuf.ptr, klen)) return ERR;
      if (memcmp(mBuf.ptr, key.ptr, klen) != 0) return 0;
    } else {
      while (klen) {
        import core.stdc.string : memcmp;
        uint len = cast(uint)(klen > mBuf.sizeof ? mBuf.sizeof : klen);
        if (!fullRead(mBuf.ptr, len)) return ERR;
        if (memcmp(mBuf.ptr, key.ptr, len) != 0) return 0;
        key = key[len..$];
        klen -= len;
      }
    }
    return rlen;
  }

  enum FindRes { ERROR = -1, NOT_FOUND = 0, FOUND = 1 }
  FindRes findRecord (const(void)[] key, uint hval, int mode) {
    RecList *rl;
    Rec *rp, rs;
    uint r;
    bool seeked = false;
    FindRes ret = FindRes.NOT_FOUND;
    outerloop: for (rl = mTables[hval&0xff]; rl !is null; rl = rl.next) {
      for (rs = rl.rec.ptr, rp = rs+rl.count; --rp >= rs;) {
        import core.stdc.string : memmove;
        if (rp.hval != hval) continue;
        /*XXX this explicit flush may be unnecessary having
         * smarter matchKey() that looks into mBuf too, but
         * most of a time here spent in finding hash values
         * (above), not keys */
        if (!seeked && !flush()) {
          mWasError = true;
          return FindRes.ERROR;
        }
        seeked = true;
        r = matchKey(rp.rpos, key);
        if (r == NOTF) continue; // not found
        if (r == ERR) {
          mWasError = true;
          return FindRes.ERROR;
        }
        ret = FindRes.FOUND;
        switch (mode) {
          case FIND_REMOVE:
            if (!removeRecord(rp.rpos, r)) return FindRes.ERROR;
            break;
          case FIND_FILL0:
            if (!zeroFillRecord(rp.rpos, r)) return FindRes.ERROR;
            break;
          default: break outerloop;
        }
        memmove(rp, rp+1, (rs+rl.count-1-rp)*rp[0].sizeof);
        --rl.count;
        --mRCount;
      }
    }
    if (seeked && !seek(mDataPos)) {
      mWasError = true;
      return FindRes.ERROR;
    }
    return ret;
  }

static:
  uint unpack() (const(ubyte)* buf) {
    //assert(buf !is null);
    uint n = buf[3];
    n <<= 8; n |= buf[2];
    n <<= 8; n |= buf[1];
    n <<= 8; n |= buf[0];
    return n;
  }

  void pack() (uint num, ubyte* buf) nothrow @nogc {
    //assert(buf !is null);
    buf[0] = num&0xff; num >>= 8;
    buf[1] = num&0xff; num >>= 8;
    buf[2] = num&0xff;
    buf[3] = (num>>8)&0xff;
  }
}
