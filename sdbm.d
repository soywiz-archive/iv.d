/* ********************************************************************************************* *
 * Simple Database Manager, based on QDBM code
 * QDBM Copyright (C) 2000-2007 Mikio Hirabayashi
 * SDBM Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * SDBM is free software; you can redistribute it and/or modify it under the terms of the GNU
 * Lesser General Public License as published by the Free Software Foundation; either version
 * 2.1 of the License or any later version.  SDBM is distributed in the hope that it will be
 * useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License along with SDBM; if
 * not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 * 02111-1307 USA.
 * ********************************************************************************************* */
// key/value database based on QDBM
module iv.sdbm is aliced;

import std.traits : isArray, isDynamicArray;
import iv.hash.fasthash;


/// database errors
class SDBMException : Exception {
  this (SDBM.Error ecode, string file=__FILE__, usize line=__LINE__, Throwable next=null) pure nothrow @safe @nogc {
    super(errorMessage(ecode), file, line, next);
  }

  /** Get a message string corresponding to an error code.
   *
   * Params:
   *   ecode = an error code
   *
   * Returns:
   *   The message string of the error code.
   */
  static string errorMessage (SDBM.Error ecode) @safe pure nothrow @nogc {
    switch (ecode) with (SDBM.Error) {
      case NOERR: return "no error";
      case FATAL: return "with fatal error";
      case CLOSED: return "database not opened error";
      case OPENED: return "already opened database error";
      case MODE: return "invalid mode";
      case BROKEN: return "broken database file";
      case KEEP: return "existing record";
      case NOITEM: return "no item found";
      case ALLOC: return "memory allocation error";
      case MAP: return "memory mapping error";
      case OPEN: return "open error";
      case CLOSE: return "close error";
      case TRUNC: return "trunc error";
      case SYNC: return "sync error";
      case STAT: return "stat error";
      case SEEK: return "seek error";
      case READ: return "read error";
      case WRITE: return "write error";
      case LOCK: return "lock error";
      case UNLINK: return "unlink error";
      case MKDIR: return "mkdir error";
      case RMDIR: return "rmdir error";
      case MISC: return "miscellaneous error";
      case NOTFOUND: return "not found error";
      default: return "(invalid ecode)";
    }
    assert(0);
  }
}


/// database
public final class SDBM {
  public import core.sys.posix.sys.types : time_t;
  private import std.typecons : Flag, Yes, No;

  enum SDBM_LIBVER = "0666";
  static assert(SDBM_LIBVER.length == SDBMHeader.versionstr.length);

  this (const(char)[] name, int omode=READER, int bnum=-1) { open(name, omode, bnum); }
  ~this () { close(); }

private:
  string m_name;   // name of the database file; terminated with '\0', but '\0' is not a string part
  bool m_wmode;    // whether to be writable
  ulong m_inode;   // inode of the database file
  time_t m_mtime;  // last modified time of the database
  int m_fd = -1;   // file descriptor of the database file
  long m_fsiz;     // size of the database file
  char* m_map;     // pointer to the mapped memory
  int m_msiz;      // size of the mapped memory
  int* m_buckets;  // pointer to the bucket array
  int m_bnum;      // number of the bucket array
  int m_rnum;      // number of records
  bool m_fatal;    // whether a fatal error occured
  int m_ioff;      // offset of the iterator
  int* m_fbpool;   // free block pool
  int m_fbpsiz;    // size of the free block pool
  int m_fbpinc;    // incrementor of update of the free block pool
  int m_alignment; // basic size of alignment (can be negative; why?)

private:
  public static ushort DP_FILEMODE = 384; // 0o600: permission of a creating file
  version(BigEndian) {
    enum DP_MAGIC = "[SDBMFILE]\n\f"; // magic on environments of big endian
  } else {
    enum DP_MAGIC = "[sdbmfile]\n\f"; // magic on environments of little endian
  }
  static assert(DP_MAGIC.length > 0 && DP_MAGIC.length <= SDBMHeader.signature.length);
  enum DP_DEFBNUM   = 8191; // default bucket number
  enum DP_FBPOOLSIZ = 16;   // size of free block pool
  enum DP_ENTBUFSIZ = 128;  // size of the entity buffer
  enum DP_STKBUFSIZ = 256;  // size of the stack key buffer
  enum DP_WRTBUFSIZ = 8192; // size of the writing buffer
  enum DP_FSBLKSIZ  = 4096; // size of a block of the file system
  enum DP_OPTBLOAD  = 0.25; // ratio of bucket loading at optimization
  enum DP_OPTRUNIT  = 256;  // number of records in a process of optimization
  enum DP_NUMBUFSIZ = 32;   // size of a buffer for a number
  enum DP_IOBUFSIZ  = 8192; // size of an I/O buffer
  enum DP_TMPFSUF = ".~sdbmtemp"; // suffix of a temporary file

  // enumeration for the flag of a record
  enum {
    DP_RECFDEL   = 0x01, // deleted
    DP_RECFREUSE = 0x02, // reusable
  }

  static align(1) struct SDBMHeader {
  align(1):
    char[12] signature; // DP_MAGICNUMB or DP_MAGICNUML, padded with '\0'
    char[4] versionstr; // string, padded with '\0'
    int flags;
    uint unused0;
    int filesize;
    uint unused1;
    int nbuckets; // number of buckets
    uint unused2;
    int nrecords; // number of records
    uint unused3;
  }
  static assert(SDBMHeader.sizeof == 48);
  static assert(SDBMHeader.signature.offsetof == 0);
  static assert(SDBMHeader.versionstr.offsetof == 12);
  static assert(SDBMHeader.flags.offsetof == 16);
  static assert(SDBMHeader.filesize.offsetof == 24);
  static assert(SDBMHeader.nbuckets.offsetof == 32);
  static assert(SDBMHeader.nrecords.offsetof == 40);

  static align(1) struct RecordHeader {
  align(1):
    int flags; // flags
    int hash2; // value of the second hash function
    int ksiz;  // the size of the key
    int vsiz;  // the size of the value
    int psiz;  // the size of the padding bytes
    int left;  // the offset of the left child
    int right; // the offset of the right child

    /* Get the size of a record in a database file.
     *
     * Returns:
     *   The return value is the size of a record in a database file
     */
    @property int recsize () const @safe pure nothrow @nogc {
      return cast(int)(RecordHeader.sizeof+ksiz+vsiz+psiz);
    }
  }
  static assert(RecordHeader.sizeof == 7*int.sizeof);
  static assert(RecordHeader.flags.offsetof == 0*int.sizeof);
  static assert(RecordHeader.hash2.offsetof == 1*int.sizeof);
  static assert(RecordHeader.ksiz.offsetof == 2*int.sizeof);
  static assert(RecordHeader.vsiz.offsetof == 3*int.sizeof);
  static assert(RecordHeader.psiz.offsetof == 4*int.sizeof);
  static assert(RecordHeader.left.offsetof == 5*int.sizeof);
  static assert(RecordHeader.right.offsetof == 6*int.sizeof);

public:
  /// enumeration for error codes
  enum Error {
    NOERR,  /// no error
    FATAL,  /// with fatal error
    CLOSED, /// trying to operate on closed db
    OPENED, /// trying to opend an already opened db
    MODE,   /// invalid mode
    BROKEN, /// broken database file
    KEEP,   /// existing record
    NOITEM, /// no item found
    ALLOC,  /// memory allocation error
    MAP,    /// memory mapping error
    OPEN,   /// open error
    CLOSE,  /// close error
    TRUNC,  /// trunc error
    SYNC,   /// sync error
    STAT,   /// stat error
    SEEK,   /// seek error
    READ,   /// read error
    WRITE,  /// write error
    LOCK,   /// lock error
    UNLINK, /// unlink error
    MKDIR,  /// mkdir error
    RMDIR,  /// rmdir error
    MISC,   /// miscellaneous error
    NOTFOUND, /// not found error
  }

  /// enumeration for open modes
  enum {
    READER = 1<<0, /// open as a reader
    WRITER = 1<<1, /// open as a writer
    CREAT  = 1<<2, /// a writer creating
    TRUNC  = 1<<3, /// a writer truncating
    NOLCK  = 1<<4, /// open without locking
    LCKNB  = 1<<5, /// lock without blocking
  }

  /// enumeration for write modes
  enum WMode {
    OVER, /// overwrite an existing value
    KEEP, /// keep an existing value
    CAT,  /// concatenate values
  }

final:
public:
  @property bool opened () const @safe pure nothrow @nogc { return (m_fd >= 0); }

  void checkOpened (string file=__FILE__, usize line=__LINE__) {
    if (m_fatal) raise(Error.FATAL, file, line);
    if (!opened) raise(Error.CLOSED, file, line);
  }

  void checkWriting (string file=__FILE__, usize line=__LINE__) {
    checkOpened(file, line);
    if (!m_wmode) raise(Error.MODE, file, line);
  }

  /** Get a database handle.
   *
   *  While connecting as a writer, an exclusive lock is invoked to the database file.
   *  While connecting as a reader, a shared lock is invoked to the database file. The thread
   *  blocks until the lock is achieved. If `NOLCK` is used, the application is responsible
   *  for exclusion control.
   *
   * Params:
   *   name = the name of a database file
   *   omode = specifies the connection mode: `WRITER` as a writer, `READER` as a reader.
   *    If the mode is `WRITER`, the following may be added by bitwise or:
   *      `CREAT`, which means it creates a new database if not exist,
   *      `TRUNC`, which means it creates a new database regardless if one exists.
   *    Both of `READER` and `WRITER` can be added to by bitwise or:
   *      `NOLCK`, which means it opens a database file without file locking, or
   *      `LCKNB`, which means locking is performed without blocking.
   *   bnum = the number of elements of the bucket array.
   *    If it is not more than 0, the default value is specified.  The size of a bucket array is
   *    determined on creating, and can not be changed except for by optimization of the database.
   *    Suggested size of a bucket array is about from 0.5 to 4 times of the number of all records
   *    to store.
   *   errcode = the error code (can be `null`)
   *
   * Throws:
   *   SDBMException on various errors
   */
  void open (const(char)[] name, int omode=READER, int bnum=-1) {
    import core.sys.posix.fcntl : open, O_CREAT, O_RDONLY, O_RDWR;
    import core.sys.posix.sys.mman : mmap, munmap, MAP_FAILED, PROT_READ, PROT_WRITE, MAP_SHARED;
    import core.sys.posix.sys.stat : fstat, lstat, S_ISREG, stat_t;
    import core.sys.posix.unistd : close, ftruncate;
    SDBMHeader hbuf;
    char* map;
    int mode, fd;
    usize msiz;
    ulong inode;
    long fsiz;
    int* fbpool;
    stat_t sbuf;
    time_t mtime;
    if (opened) raise(Error.OPENED);
    assert(name.length);
    char[] namez; // unique
    // add '\0' after string
    {
      usize len = 0;
      while (len < name.length && name[len]) ++len;
      namez = new char[](len+1);
      namez[0..$-1] = name[0..len];
      namez[$-1] = 0;
    }
    mode = O_RDONLY;
    if (omode&WRITER) {
      mode = O_RDWR;
      if (omode&CREAT) mode |= O_CREAT;
    }
    if ((fd = open(namez.ptr, mode, DP_FILEMODE)) == -1) raise(Error.OPEN);
    scope(failure) close(fd);
    if ((omode&NOLCK) == 0) fdlock(fd, (omode&WRITER) != 0, (omode&LCKNB) != 0);
    if ((omode&(WRITER|TRUNC)) == (WRITER|TRUNC)) {
      if (ftruncate(fd, 0) == -1) raise(Error.TRUNC);
    }
    if (fstat(fd, &sbuf) == -1 || !S_ISREG(sbuf.st_mode) || (sbuf.st_ino == 0 && lstat(namez.ptr, &sbuf) == -1)) raise(Error.STAT);
    inode = sbuf.st_ino;
    mtime = sbuf.st_mtime;
    fsiz = sbuf.st_size;
    if ((omode&WRITER) && fsiz == 0) {
      hbuf.signature[] = 0;
      hbuf.versionstr[] = 0;
      hbuf.signature[0..DP_MAGIC.length] = DP_MAGIC[];
      hbuf.versionstr[] = SDBM_LIBVER[];
      bnum = (bnum < 1 ? DP_DEFBNUM : bnum);
      bnum = primenum(bnum);
      hbuf.nbuckets = bnum;
      hbuf.nrecords = 0;
      fsiz = hbuf.sizeof+bnum*int.sizeof;
      hbuf.filesize = cast(int)fsiz;
      fdseekwrite(fd, 0, (&hbuf)[0..1]);
      {
        ubyte[DP_IOBUFSIZ] ebuf = 0; // totally empty buffer initialized with 0 %-)
        usize pos = hbuf.sizeof;
        while (pos < fsiz) {
          usize left = cast(usize)fsiz-pos;
          usize wr = (left > ebuf.length ? ebuf.length : left);
          fdseekwrite(fd, pos, ebuf[0..wr]);
          pos += wr;
        }
      }
    }
    try {
      fdseekread(fd, 0, (&hbuf)[0..1]);
    } catch (Exception) {
      raise(Error.BROKEN);
    }
    if (hbuf.signature[0..DP_MAGIC.length] != DP_MAGIC) raise(Error.BROKEN);
    if (hbuf.versionstr[] != SDBM_LIBVER) raise(Error.BROKEN);
    if (hbuf.filesize != fsiz) raise(Error.BROKEN);
    bnum = hbuf.nbuckets;
    if (bnum < 1 || hbuf.nrecords < 0 || fsiz < SDBMHeader.sizeof+bnum*int.sizeof) raise(Error.BROKEN);
    msiz = SDBMHeader.sizeof+bnum*int.sizeof;
    map = cast(char*)mmap(null, msiz, PROT_READ|(mode&WRITER ? PROT_WRITE : 0), MAP_SHARED, fd, 0);
    if (map == MAP_FAILED || map is null) raise(Error.MAP);
    scope(failure) munmap(map, msiz);
    fbpool = alloc!int(DP_FBPOOLSIZ*2);
    {
      import std.exception : assumeUnique;
      m_name = namez[0..$-1].assumeUnique;
    }
    m_wmode = (mode&WRITER) != 0;
    m_inode = inode;
    m_mtime = mtime;
    m_fd = fd;
    m_fsiz = fsiz;
    m_map = map;
    m_msiz = cast(int)msiz;
    m_buckets = cast(int*)(map+SDBMHeader.sizeof);
    m_bnum = bnum;
    m_rnum = hbuf.nrecords;
    m_fatal = false;
    m_ioff = 0;
    m_fbpool = fbpool;
    m_fbpool[0..DP_FBPOOLSIZ*2] = -1;
    m_fbpsiz = DP_FBPOOLSIZ*2;
    m_fbpinc = 0;
    m_alignment = 0;
  }

  /** Close a database handle.
   *
   * Returns:
   *   If successful, the return value is true, else, it is false.
   *   Because the region of a closed handle is released, it becomes impossible to use the handle.
   *   Updating a database is assured to be written when the handle is closed. If a writer opens
   *   a database but does not close it appropriately, the database will be broken.
   *
   * Throws:
   *   SDBMException on various errors
   */
  void close () {
    import core.sys.posix.sys.mman : munmap, MAP_FAILED;
    import core.sys.posix.unistd : close;
    if (!opened) return;
    bool fatal = m_fatal;
    Error err = Error.NOERR;
    if (m_wmode) updateHeader();
    if (m_map != MAP_FAILED && m_map !is null) {
      if (munmap(m_map, m_msiz) == -1) err = Error.MAP;
    }
    m_map = null;
    if (close(m_fd) == -1) err = Error.CLOSE;
    freeptr(m_fbpool);
    m_name = null;
    m_fd = -1;
    m_wmode = false;
    if (fatal) err = Error.FATAL;
    if (err != Error.NOERR) raise(err);
  }

  /** Retrieve a record.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *   start = the offset address of the beginning of the region of the value to be read
   *   max = specifies the max size to be read; if it is `uint.max`, the size to read is unlimited
   *   sp = the pointer to a variable to which the size of the region of the return
   *        value is assigned; if it is `null`, it is not used
   *
   * Returns:
   *   If successful, the return value is the GC-allocated slice of the region of the value of the
   *   corresponding record, else, it is `null`. `null` is returned when no record corresponds to
   *   the specified key or the size of the value of the corresponding record is less than `start`.
   *   No additional zero code is appended at the end of the region of the return value.
   *
   * Throws:
   *   SDBMException on various errors
   */
  T[] getA(T=char) (const(void)[] kbuf, uint start=0, uint max=uint.max, usize* sp=null) if (!isArray!T) {
    RecordHeader head;
    int bi, off, entoff;
    bool ee;
    usize vsiz;
    char[DP_ENTBUFSIZ] ebuf;
    ubyte[] vbuf = null;
    if (sp !is null) *sp = 0;
    checkOpened();
    if (!recsearch(kbuf, &bi, &off, &entoff, head, ebuf[], &ee)) return null; //raise(Error.NOITEM);
    if (start >= head.vsiz) return null; //raise(Error.NOITEM);
    scope(failure) m_fatal = true; // any failure beyond this point is fatal
    if (ee && RecordHeader.sizeof+head.ksiz+head.vsiz <= DP_ENTBUFSIZ) {
      import core.stdc.string : memcpy;
      head.vsiz -= start;
      if (max == uint.max) {
        vsiz = head.vsiz;
      } else {
        vsiz = (max < head.vsiz ? max : head.vsiz);
      }
      if (vsiz != 0) {
        vbuf.length = vsiz;
        memcpy(vbuf.ptr, ebuf.ptr+(RecordHeader.sizeof+head.ksiz+start), vsiz);
      } else {
        vbuf = new ubyte[](1);
        vbuf.length = 0;
      }
    } else {
      vbuf = recReadValue!ubyte(off, head, start, max);
    }
    if (sp !is null) {
      if (max == uint.max) {
        *sp = head.vsiz;
      } else {
        *sp = (max < head.vsiz ? max : head.vsiz);
      }
    }
    immutable len = vbuf.length/T.sizeof;
    return cast(T[])(vbuf[0..len*T.sizeof]);
    //return cast(void[])vbuf;
  }

  /** Retrieve a record and write the value into a buffer.
   *
   * Params:
   *   vbuf = the pointer to a buffer into which the value of the corresponding record is written
   *   kbuf = the pointer to the region of a key
   *   start = the offset address of the beginning of the region of the value to be read
   *
   * Returns:
   *   If successful, the return value is the read data (slice of vbuf), else, it is `null`.
   *   `null` returned when no record corresponds to the specified key or the size of the value
   *   of the corresponding record is less than `start`.
   *   Note that no additional zero code is appended at the end of the region of the writing buffer.
   *
   * Throws:
   *   SDBMException on various errors
   */
  T[] getToBuf(T=char) (T[] vbuff, const(void)[] kbuf, uint start=0) if (!isArray!T) {
    RecordHeader head;
    int bi, off, entoff;
    bool ee;
    usize vsiz;
    char[DP_ENTBUFSIZ] ebuf;
    checkOpened();
    if (!recsearch(kbuf, &bi, &off, &entoff, head, ebuf[], &ee)) return null; //raise(Error.NOITEM);
    if (start > head.vsiz) return null; //raise(Error.NOITEM);
    scope(failure) m_fatal = true; // any failure beyond this point is fatal
    auto vbuf = cast(ubyte[])vbuff;
    if (ee && RecordHeader.sizeof+head.ksiz+head.vsiz <= DP_ENTBUFSIZ) {
      import core.stdc.string : memcpy;
      head.vsiz -= start;
      vsiz = (vbuf.length < head.vsiz ? vbuf.length : head.vsiz);
      memcpy(vbuf.ptr, ebuf.ptr+(RecordHeader.sizeof+head.ksiz+start), vsiz);
    } else {
      vbuf = recReadValueToBuf(vbuf, off, head, start);
      vsiz = vbuf.length;
    }
    immutable len = vsiz/T.sizeof;
    return cast(T[])(vbuf[0..len*T.sizeof]);
    //return vbuf[0..vsiz];
  }

  // `mode`: "throw", "nothrow"
  T get(T, string mode="throw") (const(void)[] kbuf) if (!isArray!T) {
    static assert(mode == "throw" || mode == "nothrow", "invalid mode");
    T[1] data;
    auto res = getToBuf(cast(ubyte[])(data[]), kbuf);
    static if (mode == "throw") {
      if (res.length != T.sizeof) raise(Error.NOTFOUND);
    } else {
      if (res.length != T.sizeof) data[0] = T.default;
    }
    return data[0];
  }

  // `mode`: "throw", "nothrow"
  bool get(T, string mode="nothrow") (const(void)[] kbuf, ref T dval) if (!isArray!T) {
    static assert(mode == "throw" || mode == "nothrow", "invalid mode");
    auto res = getToBuf(cast(ubyte[])((&dval)[0..1]), kbuf);
    static if (mode == "throw") {
      if (res.length != T.sizeof) raise(Error.NOTFOUND);
    } else {
      if (res.length != T.sizeof) dval = T.default;
    }
    return (res.length == T.sizeof);
  }

  /** Get the size of the value of a record.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *
   * Returns:
   *   If successful, the return value is the size of the value of the corresponding record, else, it is -1.
   *   Because this function does not read the entity of a record, it is faster than `get`.
   *
   * Throws:
   *   SDBMException on various errors
   */
  int vsize (const(void)[] kbuf) {
    RecordHeader head;
    int bi, off, entoff;
    bool ee;
    char[DP_ENTBUFSIZ] ebuf;
    checkOpened();
    if (!recsearch(kbuf, &bi, &off, &entoff, head, ebuf[], &ee)) return -1; //raise(Error.NOITEM);
    return head.vsiz;
  }

  /** Check if a record is existing.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *
   * Returns:
   *   `true` if a record is in database, `false` otherwise.
   *
   * Throws:
   *   SDBMException on various errors
   */
  bool exists (const(void)[] kbuf) {
    RecordHeader head;
    int bi, off, entoff;
    bool ee;
    char[DP_ENTBUFSIZ] ebuf;
    checkOpened();
    if (!recsearch(kbuf, &bi, &off, &entoff, head, ebuf[], &ee)) return false;
    return true;
  }

  /** Store a record.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *   vbuf = the pointer to the region of a value
   *   dmode = behavior when the key overlaps, by the following values:
   *           `WMode.OVER`, which means the specified value overwrites the existing one,
   *           `WMode.KEEP`, which means the existing value is kept,
   *           `WMode.CAT`, which means the specified value is concatenated at the end of the existing value.
   *
   * Throws:
   *   SDBMException on various errors
   */
  void put (const(void)[] kbuf, const(void)[] vbuf, WMode dmode=WMode.OVER) {
    RecordHeader head, next;
    int hash, bi, off, entoff, newoff, fdel, mroff, mrsiz, mi, min;
    usize rsiz, nsiz;
    bool ee;
    char[DP_ENTBUFSIZ] ebuf;
    checkWriting();
    newoff = -1;
    if (recsearch(kbuf, &bi, &off, &entoff, head, ebuf[], &ee, Yes.delhit, &hash)) {
      // record found
      fdel = head.flags&DP_RECFDEL;
      if (dmode == WMode.KEEP && !fdel) raise(Error.KEEP);
      if (fdel) {
        head.psiz += head.vsiz;
        head.vsiz = 0;
      }
      rsiz = head.recsize;
      nsiz = RecordHeader.sizeof+kbuf.length+vbuf.length;
      if (dmode == WMode.CAT) nsiz += head.vsiz;
      if (off+rsiz >= m_fsiz) {
        if (rsiz < nsiz) {
          head.psiz += nsiz-rsiz;
          rsiz = nsiz;
          m_fsiz = off+rsiz;
        }
      } else {
        while (nsiz > rsiz && off+rsiz < m_fsiz) {
          rechead(off+rsiz, next, null, null);
          if ((next.flags&DP_RECFREUSE) == 0) break;
          head.psiz += next.recsize;
          rsiz += next.recsize;
        }
        for (uint i = 0; i < m_fbpsiz; i += 2) {
          if (m_fbpool[i] >= off && m_fbpool[i] < off+rsiz) {
            m_fbpool[i] = m_fbpool[i+1] = -1;
          }
        }
      }
      if (nsiz <= rsiz) {
        recover(off, head, vbuf, (dmode == WMode.CAT ? Yes.catmode : No.catmode));
      } else {
        char[] tval = null;
        scope(failure) m_fatal = true;
        if (dmode == WMode.CAT) {
          import core.stdc.string : memcpy;
          if (ee && RecordHeader.sizeof+head.ksiz+head.vsiz <= DP_ENTBUFSIZ) {
            tval.length = head.vsiz+vbuf.length;
            if (head.vsiz > 0) memcpy(tval.ptr, ebuf.ptr+(RecordHeader.sizeof+head.ksiz), head.vsiz);
          } else {
            tval = recReadValue(off, head);
            tval.length = head.vsiz+vbuf.length;
          }
          if (vbuf.length) memcpy(tval.ptr+head.vsiz, vbuf.ptr, vbuf.length);
          immutable newsize = head.vsiz+vbuf.length;
          vbuf = tval[0..newsize];
        }
        mi = -1;
        min = -1;
        for (uint i = 0; i < m_fbpsiz; i += 2) {
          if (m_fbpool[i+1] < nsiz) continue;
          if (mi == -1 || m_fbpool[i+1] < min) {
            mi = i;
            min = m_fbpool[i+1];
          }
        }
        if (mi >= 0) {
          mroff = m_fbpool[mi];
          mrsiz = m_fbpool[mi+1];
          m_fbpool[mi] = -1;
          m_fbpool[mi+1] = -1;
        } else {
          mroff = -1;
          mrsiz = -1;
        }
        recdelete(off, head, Yes.reusable);
        if (mroff > 0 && nsiz <= mrsiz) {
          recrewrite(mroff, mrsiz, kbuf, vbuf, hash, head.left, head.right);
          newoff = mroff;
        } else {
          newoff = recappend(kbuf, vbuf, hash, head.left, head.right);
        }
      }
      if (fdel) ++m_rnum;
    } else {
      // no such record
      scope(failure) m_fatal = true;
      newoff = recappend(kbuf, vbuf, hash, 0, 0);
      ++m_rnum;
    }
    if (newoff > 0) {
      if (entoff > 0) {
        fdseekwritenum(m_fd, entoff, newoff);
      } else {
        m_buckets[bi] = newoff;
      }
    }
  }

  // `mode`: "throw", "nothrow"
  void put(T) (const(void)[] kbuf, in T val, WMode dmode=WMode.OVER) if (!isArray!T) {
    put(kbuf, (&val)[0..1], dmode);
  }

  /** Delete a record.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *
   * Returns:
   *   If successful, the return value is true, else, it is false.
   *   False is returned when no record corresponds to the specified key.
   *
   * Throws:
   *   SDBMException on various errors
   */
  bool del (const(void)[] kbuf) {
    RecordHeader head;
    int bi, off, entoff;
    bool ee;
    char[DP_ENTBUFSIZ] ebuf;
    checkWriting();
    if (!recsearch(kbuf, &bi, &off, &entoff, head, ebuf[], &ee)) return false; //raise(Error.NOITEM);
    recdelete(off, head, No.reusable);
    --m_rnum;
    return true;
  }

  /** Initialize the iterator of a database handle.
   *
   * Returns:
   *   If successful, the return value is true, else, it is false.
   *   The iterator is used in order to access the key of every record stored in a database.
   *
   * Throws:
   *   SDBMException on various errors
   */
  void itInit () {
    checkOpened();
    m_ioff = 0;
  }

  /** Get the next key of the iterator.
   *
   * Params:
   *   sp = the pointer to a variable to which the size of the region of the return value is assigned.
   *        If it is `null`, it is not used.
   *
   * Returns:
   *   If successful, the return value is the pointer to the GC-allocated region of the next key,
   *   else, it is `null`. `null` is returned when no record is to be get out of the iterator.
   *   No additional zero code is appended at the end of the region of the return value.
   *   It is possible to access every record by iteration of calling this function. However,
   *   it is not assured if updating the database is occurred while the iteration. Besides,
   *   the order of this traversal access method is arbitrary, so it is not assured that the
   *   order of storing matches the one of the traversal access.
   *
   * Throws:
   *   SDBMException on various errors
   */
  T[] itNext(T=char) (usize* sp=null) if (T.sizeof == 1) {
    RecordHeader head;
    usize off;
    bool ee;
    char[DP_ENTBUFSIZ] ebuf;
    char[] kbuf;
    if (sp !is null) *sp = 0;
    checkOpened();
    off = SDBMHeader.sizeof+m_bnum*int.sizeof;
    off = (off > m_ioff ? off : m_ioff);
    scope(failure) m_fatal = true; // any failure is fatal here
    while (off < m_fsiz) {
      rechead(off, head, ebuf[], &ee);
      if (head.flags&DP_RECFDEL) {
        off += head.recsize;
      } else {
        if (ee && RecordHeader.sizeof+head.ksiz <= DP_ENTBUFSIZ) {
          import core.stdc.string : memcpy;
          if (head.ksiz > 0) {
            kbuf.length = head.ksiz;
            memcpy(kbuf.ptr, ebuf.ptr+RecordHeader.sizeof, head.ksiz);
          }
        } else {
          kbuf = recReadKey(off, head);
        }
        m_ioff = cast(int)(off+head.recsize);
        if (sp !is null) *sp = head.ksiz;
        return kbuf;
      }
    }
    //raise(Error.NOITEM);
    return null;
  }

  /** Set alignment of a database handle.
   *
   * If alignment is set to a database, the efficiency of overwriting values is improved.
   * The size of alignment is suggested to be average size of the values of the records to be
   * stored. If alignment is positive, padding whose size is multiple number of the alignment
   * is placed. If alignment is negative, as `vsiz` is the size of a value, the size of padding
   * is calculated with `(vsiz/pow(2, abs(alignment)-1))'. Because alignment setting is not
   * saved in a database, you should specify alignment every opening a database.
   *
   * Params:
   *   alignment = the size of alignment
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property void alignment (int alignment) {
    checkWriting();
    m_alignment = alignment;
  }

  /** Get alignment of a database handle.
   *
   * Returns:
   *   The size of alignment
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property int alignment () {
    checkOpened();
    return m_alignment;
  }

  /** Set the size of the free block pool of a database handle.
   *
   * The default size of the free block pool is 16. If the size is greater, the space efficiency
   * of overwriting values is improved with the time efficiency sacrificed.
   *
   * Params:
   *   size = the size of the free block pool of a database
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property void freeBlockPoolSize (uint size) {
    import core.stdc.stdlib : realloc;
    checkWriting();
    if (size > 0x3fff_ffffu) raise(Error.ALLOC);
    size *= 2;
    auto fbpool = cast(int*)realloc(m_fbpool, size*int.sizeof+(size ? 0 : 1));
    if (fbpool is null) raise(Error.ALLOC);
    fbpool[0..size] = -1;
    m_fbpool = fbpool;
    m_fbpsiz = size;
  }

  /** Get the size of the free block pool of a database handle.
   *
   * Returns:
   *   The size of the free block pool of a database
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property uint freeBlockPoolSize () {
    checkOpened();
    return m_fbpsiz/2;
  }

  /** Synchronize updating contents with the file and the device.
   *
   * This function is useful when another process uses the connected database file.
   *
   * Throws:
   *   SDBMException on various errors
   */
  void sync () {
    import core.sys.posix.sys.mman : msync, MS_SYNC;
    import core.sys.posix.unistd : fsync;
    checkWriting();
    updateHeader();
    if (msync(m_map, m_msiz, MS_SYNC) == -1) {
      m_fatal = true;
      raise(Error.MAP);
    }
    if (fsync(m_fd) == -1) {
      m_fatal = true;
      raise(Error.SYNC);
    }
  }

  /** Optimize a database.
   *
   * In an alternating succession of deleting and storing with overwrite or concatenate,
   * dispensable regions accumulate. This function is useful to do away with them.
   *
   * Params:
   *   bnum = the number of the elements of the bucket array. If it is not more than 0,
   *          the default value is specified
   *
   * Throws:
   *   SDBMException on various errors
   */
  void optimize (int bnum=-1) {
    import core.sys.posix.sys.mman : mmap, munmap, MAP_FAILED, MAP_SHARED, PROT_READ, PROT_WRITE;
    import core.sys.posix.unistd : ftruncate, unlink;
    SDBM tdepot;
    RecordHeader head;
    usize off;
    int unum;
    bool ee;
    int[DP_OPTRUNIT] ksizs, vsizs;
    char[DP_ENTBUFSIZ] ebuf;
    char[][DP_OPTRUNIT] kbufs, vbufs;
    checkWriting();
    if (bnum < 0) {
      bnum = cast(int)(m_rnum*(1.0/DP_OPTBLOAD))+1;
      if (bnum < DP_DEFBNUM/2) bnum = DP_DEFBNUM/2;
    }
    tdepot = new SDBM(m_name~DP_TMPFSUF, WRITER|CREAT|TRUNC, bnum);
    scope(failure) {
      import std.exception : collectException;
      m_fatal = true;
      unlink(tdepot.m_name.ptr);
      collectException(tdepot.close());
    }
    scope(exit) delete tdepot;
    tdepot.flags = flags;
    tdepot.m_alignment = m_alignment;
    off = SDBMHeader.sizeof+m_bnum*int.sizeof;
    unum = 0;
    while (off < m_fsiz) {
      rechead(off, head, ebuf[], &ee);
      if ((head.flags&DP_RECFDEL) == 0) {
        if (ee && RecordHeader.sizeof+head.ksiz <= DP_ENTBUFSIZ) {
          import core.stdc.string : memcpy;
          kbufs[unum].length = head.ksiz;
          if (head.ksiz > 0) memcpy(kbufs[unum].ptr, ebuf.ptr+RecordHeader.sizeof, head.ksiz);
          if (RecordHeader.sizeof+head.ksiz+head.vsiz <= DP_ENTBUFSIZ) {
            vbufs[unum].length = head.vsiz;
            if (head.vsiz > 0) memcpy(vbufs[unum].ptr, ebuf.ptr+(RecordHeader.sizeof+head.ksiz), head.vsiz);
          } else {
            vbufs[unum] = recReadValue(off, head);
          }
        } else {
          kbufs[unum] = recReadKey(off, head);
          vbufs[unum] = recReadValue(off, head);
        }
        ksizs[unum] = head.ksiz;
        vsizs[unum] = head.vsiz;
        ++unum;
        if (unum >= DP_OPTRUNIT) {
          for (uint i = 0; i < unum; ++i) {
            assert(kbufs[i] !is null && vbufs[i] !is null);
            tdepot.put(kbufs[i][0..ksizs[i]], vbufs[i][0..vsizs[i]], WMode.KEEP);
            kbufs[i].length = 0;
            vbufs[i].length = 0;
          }
          unum = 0;
        }
      }
      off += head.recsize;
    }
    for (uint i = 0; i < unum; ++i) {
      assert(kbufs[i] !is null && vbufs[i] !is null);
      tdepot.put(kbufs[i][0..ksizs[i]], vbufs[i][0..vsizs[i]], WMode.KEEP);
      kbufs[i].length = 0;
      vbufs[i].length = 0;
    }
    tdepot.sync();
    if (munmap(m_map, m_msiz) == -1) raise(Error.MAP);
    m_map = cast(char*)MAP_FAILED;
    if (ftruncate(m_fd, 0) == -1) raise(Error.TRUNC);
    fcopy(m_fd, 0, tdepot.m_fd, 0);
    m_fsiz = tdepot.m_fsiz;
    m_bnum = tdepot.m_bnum;
    m_ioff = 0;
    for (uint i = 0; i < m_fbpsiz; i += 2) {
      m_fbpool[i] = m_fbpool[i+1] = -1;
    }
    m_msiz = tdepot.m_msiz;
    m_map = cast(char*)mmap(null, m_msiz, PROT_READ|PROT_WRITE, MAP_SHARED, m_fd, 0);
    if (m_map == MAP_FAILED) raise(Error.MAP);
    m_buckets = cast(int*)(m_map+SDBMHeader.sizeof);
    string tempname = tdepot.m_name; // with trailing zero
    tdepot.close();
    if (unlink(tempname.ptr) == -1) raise(Error.UNLINK);
  }

  /** Get the name of a database.
   *
   * Returns:
   *   If successful, the return value is the pointer to the region of the name of the database,
   *   else, it is `null`.
   *
   * Throws:
   *   nothing
   */
  @property string name () const @safe pure nothrow @nogc {
    return m_name;
  }

  /** Get the size of a database file.
   *
   * Returns:
   *   If successful, the return value is the size of the database file, else, it is -1.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property long fileSize () {
    checkOpened();
    return m_fsiz;
  }


  /** Get the number of the elements of the bucket array.
   *
   * Returns:
   *   If successful, the return value is the number of the elements of the bucket array, else, it is -1.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property int bucketCount () {
    checkOpened();
    return m_bnum;
  }

  /** Get the number of the used elements of the bucket array.
   *
   * This function is inefficient because it accesses all elements of the bucket array.
   *
   * Returns:
   *   If successful, the return value is the number of the used elements of the bucket array, else, it is -1.
   *
   * Throws:
   *   SDBMException on various errors
   */
  int bucketUsed () {
    checkOpened();
    int hits = 0;
    foreach (immutable idx; 0..m_bnum) if (m_buckets[idx]) ++hits;
    return hits;
  }

  /** Get the number of the records stored in a database.
   *
   * Returns:
   *   If successful, the return value is the number of the records stored in the database, else, it is -1.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property int recordCount () {
    checkOpened();
    return m_rnum;
  }

  /** Check whether a database handle is a writer or not.
   *
   * Returns:
   *   The return value is true if the handle is a writer, false if not.
   */
  @property bool writable () const @safe pure nothrow @nogc {
    return (opened && m_wmode);
  }

  /** Check whether a database has a fatal error or not.
   *
   * Returns:
   *   The return value is true if the database has a fatal error, false if not.
   */
  @property bool fatalError () const @safe pure nothrow @nogc {
    return m_fatal;
  }

  /** Get the inode number of a database file.
   *
   * Returns:
   *   The return value is the inode number of the database file.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property long inode () {
    checkOpened();
    return m_inode;
  }

  /** Get the last modified time of a database.
   *
   * Returns:
   *   The return value is the last modified time of the database.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property time_t mtime () {
    checkOpened();
    return m_mtime;
  }

  /** Get the file descriptor of a database file.
   *
   * Returns:
   *   The return value is the file descriptor of the database file.
   *   Handling the file descriptor of a database file directly is not suggested.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property int fdesc () {
    checkOpened();
    return m_fd;
  }

  /* ********************************************************************************************* *
   * features for experts
   * ********************************************************************************************* */

  /** Synchronize updating contents on memory.
   *
   * Throws:
   *   SDBMException on various errors
   */
  void memsync () {
    import core.sys.posix.sys.mman : msync, MS_SYNC;
    checkWriting();
    updateHeader();
    if (msync(m_map, m_msiz, MS_SYNC) == -1) {
      m_fatal = true;
      raise(Error.MAP);
    }
  }

  /** Synchronize updating contents on memory, not physically.
   *
   * Throws:
   *   SDBMException on various errors
   */
  void memflush () {
    checkWriting();
    updateHeader();
    // there is no mflush() call
    version(none) {
      if (mflush(m_map, m_msiz, MS_SYNC) == -1) {
        m_fatal = true;
        raise(Error.MAP);
      }
    }
  }

  /** Get flags of a database.
   *
   * Returns:
   *   The return value is the flags of a database.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property int flags () {
    checkOpened();
    auto hdr = cast(SDBMHeader*)m_map;
    return hdr.flags;
  }

  /** Set flags of a database.
   *
   * Params:
   *   flags = flags to set. Least ten bits are reserved for internal use.
   *
   * Returns:
   *   If successful, the return value is true, else, it is false.
   *
   * Throws:
   *   SDBMException on various errors
   */
  @property void flags (int v) {
    checkWriting();
    auto hdr = cast(SDBMHeader*)m_map;
    hdr.flags = v;
  }

private:
  /* ********************************************************************************************* *
   * private objects
   * ********************************************************************************************* */

  void raise (Error errcode, string file=__FILE__, usize line=__LINE__) {
    assert(errcode >= Error.NOERR);
    if (errcode == Error.FATAL) m_fatal = true;
    throw new SDBMException(errcode, file, line);
  }

  static void straise (Error errcode, string file=__FILE__, usize line=__LINE__) {
    assert(errcode >= Error.NOERR);
    throw new SDBMException(errcode, file, line);
  }

  void updateHeader () @trusted nothrow @nogc {
    auto hdr = cast(SDBMHeader*)m_map;
    hdr.filesize = cast(int)m_fsiz;
    hdr.nrecords = m_rnum;
  }

  /* Lock a file descriptor.
   *
   * Params:
   *   fd = a file descriptor
   *   ex = whether an exclusive lock or a shared lock is performed
   *   nb = whether to request with non-blocking
   *   errcode = the error code (can be `null`)
   *
   * Throws:
   *   SDBMException on various errors
   */
  static void fdlock (int fd, bool ex, bool nb) {
    import core.stdc.stdio : SEEK_SET;
    import core.stdc.string : memset;
    import core.sys.posix.fcntl : flock, fcntl, F_RDLCK, F_SETLK, F_SETLKW, F_WRLCK;
    flock lock;
    assert(fd >= 0);
    memset(&lock, 0, lock.sizeof);
    lock.l_type = (ex ? F_WRLCK : F_RDLCK);
    lock.l_whence = SEEK_SET;
    lock.l_start = 0;
    lock.l_len = 0;
    lock.l_pid = 0;
    while (fcntl(fd, (nb ? F_SETLK : F_SETLKW), &lock) == -1) {
      import core.stdc.errno : errno, EINTR;
      if (errno != EINTR) straise(Error.LOCK);
    }
  }

  /* Write into a file.
   *
   * Params:
   *   fd = a file descriptor
   *   buf = a buffer to write
   *
   * Returns:
   *   The return value is the size of the written buffer, or -1 on failure
   *
   * Throws:
   *   Nothing
   */
  static int fdwrite (int fd, const(void)[] buf) @trusted nothrow @nogc {
    auto lbuf = cast(const(ubyte)[])buf;
    int rv = 0;
    assert(fd >= 0);
    while (lbuf.length > 0) {
      import core.sys.posix.unistd : write;
      auto wb = write(fd, lbuf.ptr, lbuf.length);
      if (wb == -1) {
        import core.stdc.errno : errno, EINTR;
        if (errno != EINTR) return -1;
        continue;
      }
      if (wb == 0) break;
      lbuf = lbuf[wb..$];
      rv += cast(int)wb;
    }
    return rv;
  }

  /* Write into a file at an offset.
   *
   * Params:
   *   fd = a file descriptor
   *   off = an offset of the file
   *   buf = a buffer to write
   *
   * Throws:
   *   SDBMException on various errors
   */
  static void fdseekwrite (int fd, long off, const(void)[] buf) {
    import core.stdc.stdio : SEEK_END, SEEK_SET;
    import core.sys.posix.unistd : lseek;
    assert(fd >= 0);
    if (buf.length < 1) return;
    if (lseek(fd, (off < 0 ? 0 : off), (off < 0 ? SEEK_END : SEEK_SET)) == -1) straise(Error.SEEK);
    if (fdwrite(fd, buf) != buf.length) straise(Error.WRITE);
  }

  /* Write an integer into a file at an offset.
   *
   * Params:
   *   fd = a file descriptor
   *   off = an offset of the file
   *   num = an integer
   *
   * Throws:
   *   SDBMException on various errors
   */
  void fdseekwritenum (int fd, long off, int num) {
    assert(fd >= 0);
    scope(failure) m_fatal = true;
    fdseekwrite(fd, off, (&num)[0..1]);
  }

  /* Read from a file and store the data into a buffer.
   *
   * Params:
   *   fd = a file descriptor
   *   buf = a buffer to store into.
   *
   * Returns:
   *   The return value is the size read with, or -1 on failure
   *
   * Throws:
   *   Nothing
   */
  static int fdread (int fd, void[] buf) @trusted nothrow @nogc {
    import core.sys.posix.unistd : read;
    auto lbuf = cast(ubyte[])buf;
    int total = 0;
    assert(fd >= 0);
    while (lbuf.length > 0) {
      auto bs = read(fd, lbuf.ptr, lbuf.length);
      if (bs < 0) {
        import core.stdc.errno : errno, EINTR;
        if (errno != EINTR) return -1;
        continue;
      }
      if (bs == 0) break;
      lbuf = lbuf[bs..$];
      total += cast(int)bs;
    }
    return total;
  }

  /* Read from a file at an offset and store the data into a buffer.
   *
   * Params:
   *   fd = a file descriptor
   *   off = an offset of the file
   *   buf = a buffer to store into
   *
   * Throws:
   *   SDBMException on various errors
   */
  static void fdseekread (int fd, long off, void[] buf) {
    import core.stdc.stdio : SEEK_SET;
    import core.sys.posix.unistd : lseek;
    assert(fd >= 0 && off >= 0);
    if (lseek(fd, off, SEEK_SET) != off) straise(Error.SEEK);
    if (fdread(fd, buf) != buf.length) straise(Error.READ);
  }

  /* Copy data between files.
   *
   * Params:
   *   destfd = a file descriptor of a destination file
   *   destoff = an offset of the destination file
   *   srcfd = a file descriptor of a source file
   *   srcoff = an offset of the source file
   *
   * Returns:
   *   The return value is the size copied with
   *
   * Throws:
   *   SDBMException on various errors
   */
  static int fcopy (int destfd, long destoff, int srcfd, long srcoff) {
    import core.stdc.stdio : SEEK_SET;
    import core.sys.posix.unistd : lseek;
    char[DP_IOBUFSIZ] iobuf;
    int sum, iosiz;
    if (lseek(srcfd, srcoff, SEEK_SET) == -1 || lseek(destfd, destoff, SEEK_SET) == -1) straise(Error.SEEK);
    sum = 0;
    while ((iosiz = fdread(srcfd, iobuf[])) > 0) {
      if (fdwrite(destfd, iobuf[0..iosiz]) != iosiz) straise(Error.WRITE);
      sum += iosiz;
    }
    if (iosiz < 0) straise(Error.READ);
    return sum;
  }

  /* Get the padding size of a record.
   *
   * Params:
   *   ksiz = the size of the key of a record
   *   vsiz = the size of the value of a record
   *
   * Returns:
   *   The return value is the padding size of a record
   */
  usize padsize (usize ksiz, usize vsiz) const @safe pure nothrow @nogc {
    if (m_alignment > 0) {
      return cast(usize)(m_alignment-(m_fsiz+RecordHeader.sizeof+ksiz+vsiz)%m_alignment);
    } else if (m_alignment < 0) {
      usize pad = cast(usize)(vsiz*(2.0/(1<<(-m_alignment))));
      if (vsiz+pad >= DP_FSBLKSIZ) {
        if (vsiz <= DP_FSBLKSIZ) pad = 0;
        if (m_fsiz%DP_FSBLKSIZ == 0) {
          return cast(usize)((pad/DP_FSBLKSIZ)*DP_FSBLKSIZ+DP_FSBLKSIZ-(m_fsiz+RecordHeader.sizeof+ksiz+vsiz)%DP_FSBLKSIZ);
        } else {
          return cast(usize)((pad/(DP_FSBLKSIZ/2))*(DP_FSBLKSIZ/2)+(DP_FSBLKSIZ/2)-
            (m_fsiz+RecordHeader.sizeof+ksiz+vsiz)%(DP_FSBLKSIZ/2));
        }
      } else {
        return (pad >= RecordHeader.sizeof ? pad : RecordHeader.sizeof);
      }
    }
    return 0;
  }

  /* Read the header of a record.
   *
   * Params:
   *   off = an offset of the database file
   *   head = specifies a buffer for the header
   *   ebuf = specifies the pointer to the entity buffer
   *   eep = the pointer to a variable to which whether ebuf was used is assigned
   *
   * Throws:
   *   SDBMException on various errors
   */
  void rechead (long off, ref RecordHeader head, void[] ebuf, bool* eep) {
    assert(off >= 0);
    if (eep !is null) *eep = false;
    if (off < 0 || off > m_fsiz) raise(Error.BROKEN);
    scope(failure) m_fatal = true; // any failure is fatal here
    if (ebuf.length >= DP_ENTBUFSIZ && off < m_fsiz-DP_ENTBUFSIZ) {
      import core.stdc.string : memcpy;
      if (eep !is null) *eep = true;
      fdseekread(m_fd, off, ebuf[0..DP_ENTBUFSIZ]);
      memcpy(&head, ebuf.ptr, RecordHeader.sizeof);
    } else {
      fdseekread(m_fd, off, (&head)[0..1]);
    }
    if (head.ksiz < 0 || head.vsiz < 0 || head.psiz < 0 || head.left < 0 || head.right < 0) raise(Error.BROKEN);
  }

  /* Read the entitiy of the key of a record.
   *
   * Params:
   *   off = an offset of the database file
   *   head = the header of a record
   *
   * Returns:
   *   The return value is a key data whose region is allocated by GC
   *
   * Throws:
   *   SDBMException on various errors
   */
  T[] recReadKey(T=char) (long off, ref in RecordHeader head) if (T.sizeof == 1) {
    T[] kbuf;
    assert(off >= 0);
    int ksiz = head.ksiz;
    if (ksiz > 0) {
      kbuf.length = ksiz;
      fdseekread(m_fd, off+RecordHeader.sizeof, kbuf[0..ksiz]);
    } else {
      kbuf = new T[](1);
      kbuf.length = 0;
    }
    return kbuf;
  }

  /* Read the entitiy of the value of a record.
   *
   * Params:
   *   off = an offset of the database file
   *   head = the header of a record
   *   start = the offset address of the beginning of the region of the value to be read
   *   max = the max size to be read; if it is `uint.max`, the size to read is unlimited
   *
   * Returns:
   *  The return value is a value data whose region is allocated with GC.
   *
   * Throws:
   *   SDBMException on various errors
   */
  T[] recReadValue(T=char) (long off, ref RecordHeader head, uint start=0, uint max=uint.max) if (T.sizeof == 1) {
    T[] vbuf;
    uint vsiz;
    assert(off >= 0);
    head.vsiz -= start;
    if (max == uint.max) {
      vsiz = head.vsiz;
    } else {
      vsiz = (max < head.vsiz ? max : head.vsiz);
    }
    scope(failure) m_fatal = true;
    if (vsiz > 0) {
      vbuf.length = vsiz;
      fdseekread(m_fd, off+RecordHeader.sizeof+head.ksiz+start, vbuf[0..vsiz]);
    } else {
      vbuf = new T[](1);
      vbuf.length = 0;
    }
    return vbuf;
  }

  /* Read the entitiy of the value of a record and write it into a given buffer.
   *
   * Params:
   *   off = an offset of the database file
   *   head = the header of a record
   *   start = the offset address of the beginning of the region of the value to be read
   *   vbuf = the pointer to a buffer into which the value of the corresponding record is written
   *
   * Returns:
   *   Read data (can be less then vbuf)
   *
   * Throws:
   *   SDBMException on various errors
   */
  T[] recReadValueToBuf(T=char) (T[] vbuf, long off, ref RecordHeader head, uint start=0) if (T.sizeof == 1) {
    assert(off >= 0);
    head.vsiz -= start;
    usize vsiz = (vbuf.length < head.vsiz ? vbuf.length : head.vsiz);
    fdseekread(m_fd, off+RecordHeader.sizeof+head.ksiz+start, vbuf[0..vsiz]);
    return vbuf[0..vsiz];
  }

  /* Compare two keys.
   *
   * Params:
   *   abuf = the pointer to the region of the former
   *   asiz = the size of the region
   *   bbuf = the pointer to the region of the latter
   *   bsiz = the size of the region
   *
   * Returns:
   *   The return value is 0 if two equals, positive if the formar is big, else, negative.
   */
  static int keycmp (const(void)[] abuf, const(void)[] bbuf) @trusted nothrow @nogc {
    import core.stdc.string : memcmp;
    //assert(abuf && asiz >= 0 && bbuf && bsiz >= 0);
    if (abuf.length > bbuf.length) return 1;
    if (abuf.length < bbuf.length) return -1;
    return memcmp(abuf.ptr, bbuf.ptr, abuf.length);
  }

  /* Search for a record.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *   hash = the second hash value of the key
   *   bip = the pointer to the region to assign the index of the corresponding record
   *   offp = the pointer to the region to assign the last visited node in the hash chain,
   *          or, -1 if the hash chain is empty
   *   entp = the offset of the last used joint, or, -1 if the hash chain is empty
   *   head = the pointer to the region to store the header of the last visited record in
   *   ebuf = the pointer to the entity buffer
   *   eep = the pointer to a variable to which whether ebuf was used is assigned
   *   delhit = whether a deleted record corresponds or not
   *   hout = calculated "second hash" of a key
   *
   * Returns:
   *   The return value is true if record was found, false if there is no corresponding record.
   *
   * Throws:
   *   SDBMException on various errors
   */
  bool recsearch (const(void)[] kbuf, int* bip, int* offp, int* entp,
                  ref RecordHeader head, void[] ebuf, bool* eep, Flag!"delhit" delhit=No.delhit, int* hout=null)
  {
    usize off;
    int entoff;
    int kcmp;
    char[DP_STKBUFSIZ] stkey;
    assert(ebuf.length >= DP_ENTBUFSIZ);
    assert(bip !is null && offp !is null && entp !is null && eep !is null);
    int hash = fastHash32(kbuf, 0xdeadf00dU)&0x7fff_ffff;
    if (hout !is null) *hout = hash;
    int thash = fastHash32(kbuf, 0xf00ddeadU)&0x7fff_ffff;
    *bip = thash%m_bnum;
    off = m_buckets[*bip];
    *offp = -1;
    *entp = -1;
    entoff = -1;
    *eep = false;
    while (off != 0) {
      rechead(off, head, ebuf, eep);
      thash = head.hash2;
      if (hash > thash) {
        entoff = cast(int)(off+RecordHeader.left.offsetof);
        off = head.left;
      } else if (hash < thash) {
        entoff = cast(int)(off+RecordHeader.right.offsetof);
        off = head.right;
      } else {
        if (*eep && RecordHeader.sizeof+head.ksiz <= DP_ENTBUFSIZ) {
          immutable ebstart = RecordHeader.sizeof;
          kcmp = keycmp(kbuf, ebuf[ebstart..ebstart+head.ksiz]);
        } else if (head.ksiz > DP_STKBUFSIZ) {
          auto tkey = recReadKey(off, head);
          kcmp = keycmp(kbuf, tkey[0..head.ksiz]);
          tkey.length = 0;
        } else {
          try {
            fdseekread(m_fd, off+RecordHeader.sizeof, stkey[0..head.ksiz]);
          } catch (Exception) {
            raise(Error.FATAL);
          }
          kcmp = keycmp(kbuf, stkey[0..head.ksiz]);
        }
        if (kcmp > 0) {
          entoff = cast(int)(off+RecordHeader.left.offsetof);
          off = head.left;
        } else if (kcmp < 0) {
          entoff = cast(int)(off+RecordHeader.right.offsetof);
          off = head.right;
        } else {
          if (!delhit && (head.flags&DP_RECFDEL)) {
            entoff = cast(int)(off+RecordHeader.left.offsetof);
            off = head.left;
          } else {
            *offp = cast(int)off;
            *entp = entoff;
            return true;
          }
        }
      }
    }
    *offp = cast(int)off;
    *entp = entoff;
    return false;
  }

  /* Overwrite a record.
   *
   * Params:
   *   off = the offset of the database file
   *   rsiz = the size of the existing record
   *   kbuf = the pointer to the region of a key
   *   vbuf = the pointer to the region of a value
   *   hash = the second hash value of the key
   *   left = the offset of the left child
   *   right = the offset of the right child
   *
   * Throws:
   *   SDBMException on various errors
   */
  void recrewrite (long off, int rsiz, const(void)[] kbuf, const(void)[] vbuf, int hash, int left, int right) {
    char[DP_WRTBUFSIZ] ebuf;
    RecordHeader head;
    int hoff, koff, voff, mi, min, size;
    usize asiz;
    assert(off >= 1 && rsiz > 0);
    head.flags = 0;
    head.hash2 = hash;
    head.ksiz = cast(int)kbuf.length;
    head.vsiz = cast(int)vbuf.length;
    head.psiz = cast(int)(rsiz-head.sizeof-kbuf.length-vbuf.length);
    head.left = left;
    head.right = right;
    asiz = head.sizeof+kbuf.length+vbuf.length;
    if (m_fbpsiz > DP_FBPOOLSIZ*4 && head.psiz > asiz) {
      rsiz = cast(int)((head.psiz-asiz)/2+asiz);
      head.psiz -= rsiz;
    } else {
      rsiz = 0;
    }
    if (asiz <= DP_WRTBUFSIZ) {
      import core.stdc.string : memcpy;
      memcpy(ebuf.ptr, &head, head.sizeof);
      memcpy(ebuf.ptr+head.sizeof, kbuf.ptr, kbuf.length);
      memcpy(ebuf.ptr+head.sizeof+kbuf.length, vbuf.ptr, vbuf.length);
      fdseekwrite(m_fd, off, ebuf[0..asiz]);
    } else {
      hoff = cast(int)off;
      koff = cast(int)(hoff+head.sizeof);
      voff = cast(int)(koff+kbuf.length);
      fdseekwrite(m_fd, hoff, (&head)[0..1]);
      fdseekwrite(m_fd, koff, kbuf[]);
      fdseekwrite(m_fd, voff, vbuf[]);
    }
    if (rsiz > 0) {
      off += head.sizeof+kbuf.length+vbuf.length+head.psiz;
      head.flags = DP_RECFDEL|DP_RECFREUSE;
      head.hash2 = hash;
      head.ksiz = cast(int)kbuf.length;
      head.vsiz = cast(int)vbuf.length;
      head.psiz = cast(int)(rsiz-head.sizeof-kbuf.length-vbuf.length);
      head.left = 0;
      head.right = 0;
      fdseekwrite(m_fd, off, (&head)[0..1]);
      size = head.recsize;
      mi = -1;
      min = -1;
      for (uint i = 0; i < m_fbpsiz; i += 2) {
        if (m_fbpool[i] == -1) {
          m_fbpool[i] = cast(int)off;
          m_fbpool[i+1] = size;
          fbpoolcoal();
          mi = -1;
          break;
        }
        if (mi == -1 || m_fbpool[i+1] < min) {
          mi = i;
          min = m_fbpool[i+1];
        }
      }
      if (mi >= 0 && size > min) {
        m_fbpool[mi] = cast(int)off;
        m_fbpool[mi+1] = size;
        fbpoolcoal();
      }
    }
  }

  /* Write a record at the end of a database file.
   *
   * Params:
   *   kbuf = the pointer to the region of a key
   *   vbuf = the pointer to the region of a value
   *   hash = the second hash value of the key
   *   left = the offset of the left child
   *   right = the offset of the right child
   *
   * Returns:
   *   The return value is the offset of the record
   *
   * Throws:
   *   SDBMException on various errors
   */
  int recappend (const(void)[] kbuf, const(void)[] vbuf, int hash, int left, int right) {
    char[DP_WRTBUFSIZ] ebuf;
    RecordHeader head;
    usize asiz, psiz;
    long off;
    psiz = padsize(kbuf.length, vbuf.length);
    head.flags = 0;
    head.hash2 = hash;
    head.ksiz = cast(int)kbuf.length;
    head.vsiz = cast(int)vbuf.length;
    head.psiz = cast(int)psiz;
    head.left = left;
    head.right = right;
    asiz = head.sizeof+kbuf.length+vbuf.length+psiz;
    off = m_fsiz;
    if (asiz <= DP_WRTBUFSIZ) {
      import core.stdc.string : memcpy, memset;
      memcpy(ebuf.ptr, &head, head.sizeof);
      memcpy(ebuf.ptr+head.sizeof, kbuf.ptr, kbuf.length);
      memcpy(ebuf.ptr+head.sizeof+kbuf.length, vbuf.ptr, vbuf.length);
      memset(ebuf.ptr+head.sizeof+kbuf.length+vbuf.length, 0, psiz);
      fdseekwrite(m_fd, off, ebuf[0..asiz]);
    } else {
      import core.stdc.string : memcpy, memset;
      ubyte[8192] tbuf;
      ubyte[] hbuf;
      if (asiz <= tbuf.length) hbuf = tbuf[0..asiz]; else hbuf.length = asiz;
      memcpy(hbuf.ptr, &head, head.sizeof);
      memcpy(hbuf.ptr+head.sizeof, kbuf.ptr, kbuf.length);
      memcpy(hbuf.ptr+head.sizeof+kbuf.length, vbuf.ptr, vbuf.length);
      memset(hbuf.ptr+head.sizeof+kbuf.length+vbuf.length, 0, psiz);
      fdseekwrite(m_fd, off, hbuf[0..asiz]);
    }
    m_fsiz += asiz;
    return cast(int)off;
  }

  /* Overwrite the value of a record.
   *
   * Params:
   *   off = the offset of the database file
   *   head = the header of the record
   *   vbuf = the pointer to the region of a value
   *   cat = whether it is concatenate mode or not
   *
   * Throws:
   *   SDBMException on various errors
   */
  void recover (long off, ref RecordHeader head, const(void)[] vbuf, Flag!"catmode" catmode) {
    assert(off >= 0);
    for (uint i = 0; i < m_fbpsiz; i += 2) {
      if (m_fbpool[i] == off) {
        m_fbpool[i] = m_fbpool[i+1] = -1;
        break;
      }
    }
    head.flags = 0;
    long voff = off+RecordHeader.sizeof+head.ksiz;
    if (catmode) {
      head.psiz -= vbuf.length;
      head.vsiz += vbuf.length;
      voff += head.vsiz-vbuf.length;
    } else {
      head.psiz += head.vsiz-vbuf.length;
      head.vsiz = cast(int)vbuf.length;
    }
    scope(failure) m_fatal = true; // any failure is fatal here
    fdseekwrite(m_fd, off, (&head)[0..1]);
    fdseekwrite(m_fd, voff, vbuf[]);
  }

  /* Delete a record.
   *
   * Params:
   *   off = the offset of the database file
   *   head = the header of the record
   *   reusable = whether the region is reusable or not
   *
   * Throws:
   *   SDBMException on various errors
   */
  void recdelete (long off, ref in RecordHeader head, Flag!"reusable" reusable) {
    assert(off >= 0);
    if (reusable) {
      auto size = head.recsize;
      int mi = -1;
      int min = -1;
      for (uint i = 0; i < m_fbpsiz; i += 2) {
        if (m_fbpool[i] == -1) {
          m_fbpool[i] = cast(int)off;
          m_fbpool[i+1] = size;
          fbpoolcoal();
          mi = -1;
          break;
        }
        if (mi == -1 || m_fbpool[i+1] < min) {
          mi = i;
          min = m_fbpool[i+1];
        }
      }
      if (mi >= 0 && size > min) {
        m_fbpool[mi] = cast(int)off;
        m_fbpool[mi+1] = size;
        fbpoolcoal();
      }
    }
    fdseekwritenum(m_fd, off+RecordHeader.flags.offsetof, DP_RECFDEL|(reusable ? DP_RECFREUSE : 0));
  }

  /* Make contiguous records of the free block pool coalesce. */
  void fbpoolcoal () @trusted {
    import core.stdc.stdlib : qsort;
    if (m_fbpinc++ <= m_fbpsiz/4) return;
    m_fbpinc = 0;
    qsort(m_fbpool, m_fbpsiz/2, int.sizeof*2, &fbpoolcmp);
    for (uint i = 2; i < m_fbpsiz; i += 2) {
      if (m_fbpool[i-2] > 0 && m_fbpool[i-2]+m_fbpool[i-1]-m_fbpool[i] == 0) {
        m_fbpool[i] = m_fbpool[i-2];
        m_fbpool[i+1] += m_fbpool[i-1];
        m_fbpool[i-2] = m_fbpool[i-1] = -1;
      }
    }
  }

  /* Compare two records of the free block pool.
     a = the pointer to one record.
     b = the pointer to the other record.
     The return value is 0 if two equals, positive if the formar is big, else, negative. */
  static extern(C) int fbpoolcmp (in void* a, in void* b) @trusted nothrow @nogc {
    assert(a && b);
    return *cast(const int*)a - *cast(const int*)b;
  }

  /* ********************************************************************************************* *
   * static utilities
   * ********************************************************************************************* */
public:
static:
  /** Remove a database file.
   *
   * Params:
   *   name = the name of a database file
   *
   * Throws:
   *   SDBMException on various errors
   */
  void remove (const(char)[] name) {
    import core.stdc.errno : errno, ENOENT;
    import core.sys.posix.sys.stat : lstat, stat_t;
    import core.sys.posix.unistd : unlink;
    import std.string : toStringz;
    stat_t sbuf;
    assert(name.length);
    auto namez = name.toStringz;
    if (lstat(namez, &sbuf) == -1) {
      if (errno != ENOENT) straise(Error.STAT);
      // no file
      return;
    }
    //k8:??? try to open the file to check if it's not locked or something
    auto depot = new SDBM(name, WRITER|TRUNC);
    delete depot;
    // remove file
    if (unlink(namez) == -1) {
      if (errno != ENOENT) straise(Error.UNLINK);
      // no file
    }
  }

  /** Repair a broken database file.
   *
   * There is no guarantee that all records in a repaired database file correspond to the original
   * or expected state.
   *
   * Params:
   *   name = the name of a database file
   *
   * Returns:
   *   true if ok, false is there were some errors
   *
   * Throws:
   *   SDBMException on various errors
   */
  bool repair (const(char)[] name) {
    import core.sys.posix.fcntl : open, O_RDWR;
    import core.sys.posix.sys.stat : lstat, stat_t;
    import core.sys.posix.unistd : close, ftruncate, unlink;
    SDBM tdepot;
    SDBMHeader dbhead;
    char* kbuf, vbuf;
    RecordHeader head;
    int fd, flags, bnum, tbnum, rsiz, ksiz, vsiz;
    usize off;
    long fsiz;
    stat_t sbuf;
    assert(name.length);
    {
      import std.string : toStringz;
      auto namez = name.toStringz;
      if (lstat(namez, &sbuf) == -1) throw new SDBMException(Error.STAT); //raise(Error.STAT);
      fsiz = sbuf.st_size;
      if ((fd = open(namez, O_RDWR, DP_FILEMODE)) == -1) throw new SDBMException(Error.OPEN); //raise(Error.OPEN);
    }
    scope(exit) if (fd >= 0) close(fd);
    fdseekread(fd, 0, (&dbhead)[0..1]);
    flags = dbhead.flags;
    bnum = dbhead.nbuckets;
    tbnum = dbhead.nrecords*2;
    if (tbnum < DP_DEFBNUM) tbnum = DP_DEFBNUM;
    tdepot = new SDBM(name~DP_TMPFSUF, WRITER|CREAT|TRUNC, tbnum);
    off = SDBMHeader.sizeof+bnum*int.sizeof;
    bool err = false;
    while (off < fsiz) {
      try {
        fdseekread(fd, off, (&head)[0..1]);
      } catch (Exception) {
        break;
      }
      if (head.flags&DP_RECFDEL) {
        rsiz = head.recsize;
        if (rsiz < 0) break;
        off += rsiz;
        continue;
      }
      ksiz = head.ksiz;
      vsiz = head.vsiz;
      if (ksiz >= 0 && vsiz >= 0) {
        kbuf = alloc!char(ksiz);
        vbuf = alloc!char(vsiz);
        if (kbuf !is null && vbuf !is null) {
          try {
            fdseekread(fd, off+RecordHeader.sizeof, kbuf[0..ksiz]);
            fdseekread(fd, off+RecordHeader.sizeof+ksiz, vbuf[0..vsiz]);
            tdepot.put(kbuf[0..ksiz], vbuf[0..vsiz], WMode.KEEP);
          } catch (Exception) {
            err = true;
          }
        } else {
          //if (!err) raise(Error.ALLOC);
          err = true;
        }
        if (vbuf !is null) freeptr(vbuf);
        if (kbuf !is null) freeptr(kbuf);
      } else {
        //if (!err) raise(Error.BROKEN);
        err = true;
      }
      rsiz = head.recsize;
      if (rsiz < 0) break;
      off += rsiz;
    }
    tdepot.flags = flags; // err = true;
    try {
      tdepot.sync();
    } catch (Exception) {
      err = true;
    }
    if (ftruncate(fd, 0) == -1) {
      //if (!err) raise(Error.TRUNC);
      err = true;
    }
    auto tempname = tdepot.m_name; // with trailing zero
    try {
      fcopy(fd, 0, tdepot.m_fd, 0);
      tdepot.close();
    } catch (Exception) {
      err = true;
    }
    if (close(fd) == -1) {
      //if (!err) raise(Error.CLOSE);
      err = true;
    }
    fd = -1;
    if (unlink(tempname.ptr) == -1) {
      //if (!err) raise(Error.UNLINK);
      err = true;
    }
    return !err;
  }

  /** Get a natural prime number not less than a number.
   *
   * This function is useful when an application determines the size of a bucket array of its
   * own hash algorithm.
   *
   * Params:
   *   num = a natural number
   *
   * Returns:
   *   The return value is a natural prime number not less than the specified number
   */
  int primenum (int num) @safe pure nothrow @nogc {
    static immutable int[217] primes = [
      1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 43, 47, 53, 59, 61, 71, 79, 83,
      89, 103, 109, 113, 127, 139, 157, 173, 191, 199, 223, 239, 251, 283, 317, 349,
      383, 409, 443, 479, 509, 571, 631, 701, 761, 829, 887, 953, 1021, 1151, 1279,
      1399, 1531, 1663, 1789, 1913, 2039, 2297, 2557, 2803, 3067, 3323, 3583, 3833,
      4093, 4603, 5119, 5623, 6143, 6653, 7159, 7673, 8191, 9209, 10223, 11261,
      12281, 13309, 14327, 15359, 16381, 18427, 20479, 22511, 24571, 26597, 28669,
      30713, 32749, 36857, 40949, 45053, 49139, 53239, 57331, 61417, 65521, 73727,
      81919, 90107, 98299, 106487, 114679, 122869, 131071, 147451, 163819, 180221,
      196597, 212987, 229373, 245759, 262139, 294911, 327673, 360439, 393209, 425977,
      458747, 491503, 524287, 589811, 655357, 720887, 786431, 851957, 917503, 982981,
      1048573, 1179641, 1310719, 1441771, 1572853, 1703903, 1835003, 1966079,
      2097143, 2359267, 2621431, 2883577, 3145721, 3407857, 3670013, 3932153,
      4194301, 4718579, 5242877, 5767129, 6291449, 6815741, 7340009, 7864301,
      8388593, 9437179, 10485751, 11534329, 12582893, 13631477, 14680063, 15728611,
      16777213, 18874367, 20971507, 23068667, 25165813, 27262931, 29360087, 31457269,
      33554393, 37748717, 41943023, 46137319, 50331599, 54525917, 58720253, 62914549,
      67108859, 75497467, 83886053, 92274671, 100663291, 109051903, 117440509,
      125829103, 134217689, 150994939, 167772107, 184549373, 201326557, 218103799,
      234881011, 251658227, 268435399, 301989881, 335544301, 369098707, 402653171,
      436207613, 469762043, 503316469, 536870909, 603979769, 671088637, 738197503,
      805306357, 872415211, 939524087, 1006632947, 1073741789, 1207959503,
      1342177237, 1476394991, 1610612711, 1744830457, 1879048183, 2013265907,
    ];
    assert(num > 0);
    foreach (immutable pr; primes) if (num <= pr) return pr;
    return primes[$-1];
  }

private:
  /** Free `malloc()`ed pointer and set variable to `null`.
   *
   * Params:
   *   ptr = the pointer to variable holding a pointer
   */
  static freeptr(T) (ref T* ptr) {
    import core.stdc.stdlib : free;
    if (ptr !is null) {
      free(cast(void*)ptr);
      ptr = null;
    }
  }

  // `noerr`: "nothrow" --> return `null` on error
  static T* alloc(T, string noerr=null) (usize count=1) {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;
    //TODO: overflow checking
    usize asz = T.sizeof*count;
    if (asz == 0) asz = 1;
    void* res = malloc(asz);
    if (res is null) {
      static if (noerr == "nothrow") throw new SDBMException(Error.ALLOC);
    } else {
      memset(res, 0, asz);
    }
    return cast(T*)res;
  }
}
