/* This file is a part of tinycdb package by Michael Tokarev, mjt@corpit.ru.
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
 *
 * D translation by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 */
// CDB key/value database reader
module iv.tinycdb;


struct CDB {
public:
  enum Version { Major = 0, Minor = 78 }

private:
  int mFD = -1; /* file descriptor */
  bool mCloseFD; /* true: close fd on close() */
  uint mFSize; /* datafile size */
  uint mDataEnd; /* end of data ptr */
  const(ubyte)* mDataPtr; /* mmap'ed file memory */

public:
nothrow:
  @disable this (this); // no copying

  this (string fname) { open(fname); }

  bool open (string fname) {
    import std.string : toStringz;
    import core.sys.posix.fcntl : xopen = open, O_RDONLY;
    close();
    int fd = xopen(fname.toStringz, O_RDONLY);
    if (fd >= 0) {
      mCloseFD = true;
      if (open(fd)) return true;
      import core.sys.posix.unistd : xclose = close;
      xclose(fd);
      mFD = -1;
      mCloseFD = false;
      mFSize = 0;
      mDataEnd = 0;
      mDataPtr = null;
    }
    return false;
  }

@nogc:
  ~this () { close(); }

  this (int fd) @nogc { open(fd); }

  @property bool opened () const pure @safe { return (mFD >= 0 && mDataPtr !is null); }

  // was int, -1 == err
  bool open (int fd) {
    import core.sys.posix.sys.mman : mmap, PROT_READ, MAP_SHARED, MAP_FAILED;
    import core.sys.posix.sys.stat : fstat, stat_t;
    stat_t st;
    ubyte *mem;
    uint fsize, dend;
    close();
    /* get file size */
    if (fd < 0 || fstat(fd, &st) < 0) return false;
    /* trivial sanity check: at least toc should be here */
    if (st.st_size < 2048) return false;
    fsize = (st.st_size < 0xffffffffu ? cast(uint)st.st_size : 0xffffffffu);
    /* memory-map file */
    mem = cast(ubyte*)mmap(null, fsize, PROT_READ, MAP_SHARED, fd, 0);
    if (mem == MAP_FAILED) return false;
    mFD = fd;
    mFSize = fsize;
    mDataPtr = mem;
    /* set madvise() parameters. Ignore errors for now if system doesn't support it */
    {
      import core.sys.posix.sys.mman : posix_madvise, POSIX_MADV_WILLNEED, POSIX_MADV_RANDOM;
      posix_madvise(mem, 2048, POSIX_MADV_WILLNEED);
      posix_madvise(mem+2048, mFSize-2048, POSIX_MADV_RANDOM);
    }
    dend = unpack(mem);
    if (dend < 2048) dend = 2048; else if (dend >= fsize) dend = fsize;
    mDataEnd = dend;
    return true;
  }

  bool close () {
    if (mDataPtr) {
      import core.sys.posix.sys.mman : munmap;
      munmap(cast(void*)mDataPtr, mFSize);
      mDataPtr = null;
      bool wasError = false;
      if (mCloseFD) {
        import core.sys.posix.unistd : xclose = close;
        wasError = (xclose(mFD) != 0);
      }
      mFD = -1;
      mCloseFD = false;
      mFSize = 0;
      mDataEnd = 0;
      mDataPtr = null;
      return wasError;
    } else {
      return true;
    }
  }

  const(char)[] opIndex (const(char)[] key) const { return find(key); }

  // null: not found (or some error occured)
  const(T)[] find(T=char) (const(void)[] key) const
  if (is(T == char) || is(T == byte) || is(T == ubyte) || is(T == void))
  {
    uint httodo; /* ht bytes left to look */
    uint pos, n;
    if (key.length < 1 || key.length >= mDataEnd) return null; /* if key size is too small or too large */
    immutable klen = cast(uint)key.length;
    immutable hval = hash(key);
    /* find (pos,n) hash table to use */
    /* first 2048 bytes (toc) are always available */
    /* (hval%256)*8 */
    auto htp = cast(const(ubyte)*)mDataPtr+((hval<<3)&2047); /* index in toc (256x8) */
    n = unpack(htp+4); /* table size */
    if (!n) return null; /* empty table: not found */
    httodo = n<<3; /* bytes of htab to lookup */
    pos = unpack(htp); /* htab position */
    if (n > (mFSize>>3) || /* overflow of httodo ? */
        pos < mDataEnd || /* is htab inside data section ? */
        pos > mFSize || /* htab start within file ? */
        httodo > mFSize-pos) /* entrie htab within file ? */
      return null; // error
    auto htab = mDataPtr+pos; /* hash table */
    auto htend = htab+httodo; /* after end of hash table */
    /* htab starting position: rest of hval modulo htsize, 8bytes per elt */
    htp = htab+(((hval>>8)%n)<<3); /* hash table pointer */
    for (;;) {
      pos = unpack(htp+4); /* record position */
      if (!pos) return null;
      if (unpack(htp) == hval) {
        if (pos > mDataEnd-8) return null; /* key+val lengths: error */
        if (unpack(mDataPtr+pos) == klen) {
          import core.stdc.string : memcmp;
          if (mDataEnd-klen < pos+8) return null; // error
          if (memcmp(key.ptr, mDataPtr+pos+8, klen) == 0) {
            n = unpack(mDataPtr+pos+4);
            pos += 8;
            if (mDataEnd < n || mDataEnd-n < pos+klen) return /*errno = EPROTO, -1*/null; // error
            // key: [pos..pos+klen]
            // val: [pos+klen..pos+klen+n]
            return cast(const(T)[])mDataPtr[pos+klen..pos+klen+n];
          }
        }
      }
      httodo -= 8;
      if (!httodo) return null;
      if ((htp += 8) >= htend) htp = htab;
    }
  }

  //WARNING! returned range should not outlive this object!
  auto findFirst(T=char) (const(void)[] key) const nothrow @nogc
  if (is(T == char) || is(T == byte) || is(T == ubyte) || is(T == void))
  {
    static struct Iter {
    private:
      const(CDB)* cdbp;
      uint hval;
      const(ubyte)* htp, htab, htend;
      uint httodo;
      const(void)[] key;
      uint vpos, vlen;

    public:
    nothrow:
    @nogc:
      @disable this ();

      @property bool empty () const @safe pure { return (cdbp is null || !cdbp.opened); }
      @property const(T)[] front () const @trusted pure nothrow @nogc {
        return (empty ? null : cast(const(T)[])cdbp.mDataPtr[vpos..vpos+vlen]);
      }
      void close () { cdbp = null; key = null; htp = htab = htend = null; }
      void popFront () {
        if (empty) return;
        auto cdb = cdbp;
        uint pos, n;
        immutable uint klen = cast(uint)key.length;
        while (httodo) {
          pos = unpack(htp+4);
          if (!pos) { close(); return; }
          n = (unpack(htp) == hval);
          if ((htp += 8) >= htend) htp = htab;
          httodo -= 8;
          if (n) {
            if (pos > cdb.mFSize-8) { close(); return; }
            if (unpack(cdb.mDataPtr+pos) == klen) {
              import core.stdc.string : memcmp;
              if (cdb.mFSize-klen < pos+8) { close(); return; }
              if (memcmp(key.ptr, cdb.mDataPtr+pos+8, klen) == 0) {
                n = unpack(cdb.mDataPtr+pos+4);
                pos += 8;
                if (cdb.mFSize < n || cdb.mFSize-n < pos+klen) { close(); return; }
                // key: [pos..pos+klen]
                // val: [pos+klen..pos+klen+n]
                vpos = pos+klen;
                vlen = n;
                return;
              }
            }
          }
        }
        close();
      }
    }

    if (key.length < 1 || key.length >= mDataEnd) return Iter.init; /* if key size is too large */
    immutable klen = cast(uint)key.length;

    auto it = Iter.init;
    it.cdbp = &this;
    it.key = key;
    it.hval = hash(key);

    it.htp = mDataPtr+((it.hval<<3)&2047);
    uint n = unpack(it.htp+4);
    it.httodo = n<<3;
    if (!n) return Iter.init;
    uint pos = unpack(it.htp);
    if (n > (mFSize >> 3) ||
        pos < mDataEnd ||
        pos > mFSize ||
        it.httodo > mFSize-pos)
      return Iter.init;

    it.htab = mDataPtr+pos;
    it.htend = it.htab+it.httodo;
    it.htp = it.htab+(((it.hval>>8)%n)<<3);

    it.popFront(); // prepare first item
    return it;
  }

static:
  uint hash() (const(void)[] buf) {
    auto p = cast(const(ubyte)*)buf.ptr;
    uint hash = 5381; /* start value */
    foreach (immutable nothing; 0..buf.length) hash = (hash+(hash<<5))^*p++;
    return hash;
  }

private:
  uint unpack() (const(ubyte)* buf) {
    //assert(buf !is null);
    uint n = buf[3];
    n <<= 8; n |= buf[2];
    n <<= 8; n |= buf[1];
    n <<= 8; n |= buf[0];
    return n;
  }
}
