/** ARZ chunked archive format processor.
 *
 * This module provides `std.stdio.File`-like interface to ARZ archives.
 *
 * Copyright: Copyright Ketmar Dark, 2016
 *
 * License: Boost License 1.0
 */
module iv.arcz is aliced;

// use Balz compressor if available
static if (__traits(compiles, { import iv.balz; })) enum arcz_has_balz = true; else enum arcz_has_balz = false;
static if (__traits(compiles, { import iv.zopfli; })) enum arcz_has_zopfli = true; else enum arcz_has_zopfli = false;
static if (arcz_has_balz) import iv.balz;
static if (arcz_has_zopfli) import iv.zopfli;

// comment this to free pakced chunk buffer right after using
// i.e. `AZFile` will allocate new block for each new chunk
//version = arcz_use_more_memory;

public import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;


// ////////////////////////////////////////////////////////////////////////// //
/// ARZ archive accessor. Use this to open ARZ archives, and open packed files from ARZ archives.
public struct ArzArchive {
private:
  static assert(usize.sizeof >= (void*).sizeof);
  private import core.stdc.stdio : FILE, fopen, fclose, fread, fseek;
  private import etc.c.zlib;

  static struct ChunkInfo {
    uint ofs; // offset in file
    uint pksize; // packed chunk size (same as chunk size: chunk is unpacked)
  }

  static struct FileInfo {
    string name;
    uint chunk;
    uint chunkofs; // offset of first file byte in unpacked chunk
    uint size; // unpacked file size
  }

  static struct Nfo {
    uint rc = 1; // refcounter
    ChunkInfo[] chunks;
    FileInfo[string] files;
    uint chunkSize;
    uint lastChunkSize;
    bool useBalz;
    FILE* afl; // archive file, we'll keep it opened

    @disable this (this); // no copies!

    static void decRef (usize me) {
      if (me) {
        auto nfo = cast(Nfo*)me;
        assert(nfo.rc);
        if (--nfo.rc == 0) {
          import core.memory : GC;
          import core.stdc.stdlib : free;
          if (nfo.afl !is null) fclose(nfo.afl);
          nfo.chunks.destroy;
          nfo.files.destroy;
          nfo.afl = null;
          GC.removeRange(cast(void*)nfo/*, Nfo.sizeof*/);
          free(nfo);
          debug(arcz_rc) { import core.stdc.stdio : printf; printf("Nfo %p freed\n", nfo); }
        }
      }
    }
  }

  usize nfop; // hide it from GC

  private @property Nfo* nfo () { pragma(inline, true); return cast(Nfo*)nfop; }
  void decRef () { pragma(inline, true); Nfo.decRef(nfop); nfop = 0; }

  static uint readUint (FILE* fl) {
    if (fl is null) throw new Exception("cannot read from closed file");
    uint v;
    if (fread(&v, 1, v.sizeof, fl) != v.sizeof) throw new Exception("file reading error");
    version(BigEndian) {
      import core.bitop : bswap;
      v = bswap(v);
    } else version(LittleEndian) {
      // nothing to do
    } else {
      static assert(0, "wtf?!");
    }
    return v;
  }

  static uint readUbyte (FILE* fl) {
    if (fl is null) throw new Exception("cannot read from closed file");
    ubyte v;
    if (fread(&v, 1, v.sizeof, fl) != v.sizeof) throw new Exception("file reading error");
    return v;
  }

  static void readBuf (FILE* fl, void[] buf) {
    if (buf.length > 0) {
      if (fl is null) throw new Exception("cannot read from closed file");
      if (fread(buf.ptr, 1, buf.length, fl) != buf.length) throw new Exception("file reading error");
    }
  }

  static T* xalloc(T, bool clear=true) (uint mem) if (T.sizeof > 0) {
    import core.exception : onOutOfMemoryError;
    assert(mem != 0);
    static if (clear) {
      import core.stdc.stdlib : calloc;
      auto res = calloc(mem, T.sizeof);
      if (res is null) onOutOfMemoryError();
      static if (is(T == struct)) {
        import core.stdc.string : memcpy;
        static immutable T i = T.default;
        foreach (immutable idx; 0..mem) memcpy(res+idx, &i, T.sizeof);
      }
      debug(arcz_alloc) { import core.stdc.stdio : printf; printf("allocated %u bytes at %p\n", cast(uint)(mem*T.sizeof), res); }
      return cast(T*)res;
    } else {
      import core.stdc.stdlib : malloc;
      auto res = malloc(mem*T.sizeof);
      if (res is null) onOutOfMemoryError();
      static if (is(T == struct)) {
        import core.stdc.string : memcpy;
        static immutable T i = T.default;
        foreach (immutable idx; 0..mem) memcpy(res+idx, &i, T.sizeof);
      }
      debug(arcz_alloc) { import core.stdc.stdio : printf; printf("allocated %u bytes at %p\n", cast(uint)(mem*T.sizeof), res); }
      return cast(T*)res;
    }
  }

  static void xfree(T) (T* ptr) {
    if (ptr !is null) {
      import core.stdc.stdlib : free;
      debug(arcz_alloc) { import core.stdc.stdio : printf; printf("freing at %p\n", ptr); }
      free(ptr);
    }
  }

  static if (arcz_has_balz) static ubyte balzDictSize (uint blockSize) {
    foreach (ubyte bits; Balz.MinDictBits..Balz.MaxDictBits+1) {
      if ((1U<<bits) >= blockSize) return bits;
    }
    return Balz.MaxDictBits;
  }

  // unpack exactly `destlen` bytes
  static if (arcz_has_balz) static void unpackBlockBalz (void* dest, uint destlen, const(void)* src, uint srclen, uint blocksize) {
    Unbalz bz;
    bz.reinit(balzDictSize(blocksize));
    int ipos, opos;
    auto dc = bz.decompress(
      // reader
      (buf) {
        import core.stdc.string : memcpy;
        if (ipos >= srclen) return 0;
        uint rd = destlen-ipos;
        if (rd > buf.length) rd = cast(uint)buf.length;
        memcpy(buf.ptr, src+ipos, rd);
        ipos += rd;
        return rd;
      },
      // writer
      (buf) {
        //if (opos+buf.length > destlen) throw new Exception("error unpacking archive");
        uint wr = destlen-opos;
        if (wr > buf.length) wr = cast(uint)buf.length;
        if (wr > 0) {
          import core.stdc.string : memcpy;
          memcpy(dest+opos, buf.ptr, wr);
          opos += wr;
        }
      },
      // unpack length
      destlen
    );
    if (opos != destlen) throw new Exception("error unpacking archive");
  }

  static void unpackBlockZLib (void* dest, uint destlen, const(void)* src, uint srclen, uint blocksize) {
    z_stream zs;
    zs.avail_in = 0;
    zs.avail_out = 0;
    // initialize unpacker
    if (inflateInit2(&zs, 15) != Z_OK) throw new Exception("can't initialize zlib");
    scope(exit) inflateEnd(&zs);
    zs.next_in = cast(typeof(zs.next_in))src;
    zs.avail_in = srclen;
    zs.next_out = cast(typeof(zs.next_out))dest;
    zs.avail_out = destlen;
    while (zs.avail_out > 0) {
      auto err = inflate(&zs, Z_SYNC_FLUSH);
      if (err != Z_STREAM_END && err != Z_OK) throw new Exception("error unpacking archive");
      if (err == Z_STREAM_END) break;
    }
    if (zs.avail_out != 0) throw new Exception("error unpacking archive");
  }

  static void unpackBlock (void* dest, uint destlen, const(void)* src, uint srclen, uint blocksize, bool useBalz) {
    if (useBalz) {
      static if (arcz_has_balz) {
        unpackBlockBalz(dest, destlen, src, srclen, blocksize);
      } else {
        throw new Exception("no Balz support was compiled in ArcZ");
      }
    } else {
      unpackBlockZLib(dest, destlen, src, srclen, blocksize);
    }
  }

public:
  this (in ArzArchive arc) {
    assert(nfop == 0);
    nfop = arc.nfop;
    if (nfop) ++nfo.rc;
  }

  this (this) {
    if (nfop) ++nfo.rc;
  }

  ~this () { close(); }

  void opAssign (in ArzArchive arc) {
    if (arc.nfop) {
      auto n = cast(Nfo*)arc.nfop;
      ++n.rc;
    }
    decRef();
    nfop = arc.nfop;
  }

  void close () { decRef(); }

  @property FileInfo[string] files () { return (nfop ? nfo.files : null); }

  void openArchive (const(char)[] filename) {
    debug/*(arcz)*/ import core.stdc.stdio : printf;
    FILE* fl = null;
    scope(exit) if (fl !is null) fclose(fl);
    close();
    if (filename.length == 0) throw new Exception("cannot open unnamed archive file");
    if (filename.length < 2048) {
      import core.stdc.stdlib : alloca;
      auto tfn = (cast(char*)alloca(filename.length+1))[0..filename.length+1];
      tfn[0..filename.length] = filename[];
      tfn[filename.length] = 0;
      fl = fopen(tfn.ptr, "rb");
    } else {
      import core.stdc.stdlib : malloc, free;
      auto tfn = (cast(char*)malloc(filename.length+1))[0..filename.length+1];
      if (tfn !is null) {
        scope(exit) free(tfn.ptr);
        fl = fopen(tfn.ptr, "rb");
      }
    }
    if (fl is null) throw new Exception("cannot open archive file '"~filename.idup~"'");
    char[4] sign;
    bool useBalz;
    readBuf(fl, sign[]);
    if (sign != "CZA2") throw new Exception("invalid archive file '"~filename.idup~"'");
    switch (readUbyte(fl)) {
      case 0: useBalz = false; break;
      case 1: useBalz = true; break;
      default: throw new Exception("invalid version of archive file '"~filename.idup~"'");
    }
    uint indexofs = readUint(fl); // index offset in file
    uint pkidxsize = readUint(fl); // packed index size
    uint idxsize = readUint(fl); // unpacked index size
    if (pkidxsize == 0 || idxsize == 0 || indexofs == 0) throw new Exception("invalid archive file '"~filename.idup~"'");
    // now read index
    ubyte* idxbuf = null;
    scope(exit) xfree(idxbuf);
    {
      auto pib = xalloc!ubyte(pkidxsize);
      scope(exit) xfree(pib);
      if (fseek(fl, indexofs, 0) < 0) throw new Exception("seek error in archive file '"~filename.idup~"'");
      readBuf(fl, pib[0..pkidxsize]);
      idxbuf = xalloc!ubyte(idxsize);
      unpackBlock(idxbuf, idxsize, pib, pkidxsize, idxsize, useBalz);
    }

    // parse index and build structures
    uint idxbufpos = 0;

    ubyte getUbyte () {
      if (idxsize-idxbufpos < ubyte.sizeof) throw new Exception("invalid index for archive file '"~filename.idup~"'");
      return idxbuf[idxbufpos++];
    }

    uint getUint () {
      if (idxsize-idxbufpos < uint.sizeof) throw new Exception("invalid index for archive file '"~filename.idup~"'");
      version(BigEndian) {
        import core.bitop : bswap;
        uint v = *cast(uint*)(idxbuf+idxbufpos);
        idxbufpos += 4;
        return bswap(v);
      } else version(LittleEndian) {
        uint v = *cast(uint*)(idxbuf+idxbufpos);
        idxbufpos += 4;
        return v;
      } else {
        static assert(0, "wtf?!");
      }
    }

    void getBuf (void[] buf) {
      if (buf.length > 0) {
        import core.stdc.string : memcpy;
        if (idxsize-idxbufpos < buf.length) throw new Exception("invalid index for archive file '"~filename.idup~"'");
        memcpy(buf.ptr, idxbuf+idxbufpos, buf.length);
        idxbufpos += buf.length;
      }
    }

    // allocate shared info struct
    Nfo* nfo = xalloc!Nfo(1);
    assert(nfo.rc == 1);
    debug(arcz_rc) { import core.stdc.stdio : printf; printf("Nfo %p allocated\n", nfo); }
    scope(failure) decRef();
    nfop = cast(usize)nfo;
    {
      import core.memory : GC;
      GC.addRange(nfo, Nfo.sizeof);
    }

    // read chunk info and data
    nfo.useBalz = useBalz;
    nfo.chunkSize = getUint;
    auto ccount = getUint; // chunk count
    nfo.lastChunkSize = getUint;
    debug(arcz_dirread) printf("chunk size: %u\nchunk count: %u\nlast chunk size:%u\n", nfo.chunkSize, ccount, nfo.lastChunkSize);
    if (ccount == 0 || nfo.chunkSize < 1 || nfo.lastChunkSize < 1 || nfo.lastChunkSize > nfo.chunkSize) throw new Exception("invalid archive file '"~filename.idup~"'");
    nfo.chunks.length = ccount;
    // chunk offsets and sizes
    foreach (ref ci; nfo.chunks) {
      ci.ofs = getUint;
      ci.pksize = getUint;
    }
    // read file count and info
    auto fcount = getUint;
    if (fcount == 0) throw new Exception("empty archive file '"~filename.idup~"'");
    // calc name buffer position and size
    //immutable uint nbofs = idxbufpos+fcount*(5*4);
    //if (nbofs >= idxsize) throw new Exception("invalid index in archive file '"~filename.idup~"'");
    //immutable uint nbsize = idxsize-nbofs;
    debug(arcz_dirread) printf("file count: %u\n", fcount);
    foreach (immutable _; 0..fcount) {
      uint nameofs = getUint;
      uint namelen = getUint;
      if (namelen == 0) {
        // skip unnamed file
        //throw new Exception("invalid archive file '"~filename.idup~"'");
        getUint; // chunk number
        getUint; // offset in chunk
        getUint; // unpacked size
        debug(arcz_dirread) printf("skipped empty file\n");
      } else {
        //if (nameofs >= nbsize || namelen > nbsize || nameofs+namelen > nbsize) throw new Exception("invalid index in archive file '"~filename.idup~"'");
        if (nameofs >= idxsize || namelen > idxsize || nameofs+namelen > idxsize) throw new Exception("invalid index in archive file '"~filename.idup~"'");
        FileInfo fi;
        auto nb = new char[](namelen);
        nb[0..namelen] = (cast(char*)idxbuf)[nameofs..nameofs+namelen];
        fi.name = cast(string)(nb); // it is safe here
        fi.chunk = getUint; // chunk number
        fi.chunkofs = getUint; // offset in chunk
        fi.size = getUint; // unpacked size
        debug(arcz_dirread) printf("file size: %u\nfile chunk: %u\noffset in chunk:%u; name: [%.*s]\n", fi.size, fi.chunk, fi.chunkofs, cast(uint)fi.name.length, fi.name.ptr);
        nfo.files[fi.name] = fi;
      }
    }
    // transfer achive file ownership
    nfo.afl = fl;
    fl = null;
  }

  bool exists (const(char)[] name) { if (nfop) return ((name in nfo.files) !is null); else return false; }

  AZFile open (const(char)[] name) {
    if (!nfop) throw new Exception("can't open file from non-opened archive");
    if (auto fi = name in nfo.files) {
      auto zl = xalloc!LowLevelPackedRO(1);
      scope(failure) xfree(zl);
      debug(arcz_rc) { import core.stdc.stdio : printf; printf("Zl %p allocated\n", zl); }
      zl.setup(nfo, fi.chunk, fi.chunkofs, fi.size);
      AZFile fl;
      fl.zlp = cast(usize)zl;
      return fl;
    }
    throw new Exception("can't open file '"~name.idup~"' from archive");
  }

private:
  static struct LowLevelPackedRO {
    private import etc.c.zlib;

    uint rc = 1;
    usize nfop; // hide it from GC

    private @property inout(Nfo*) nfo () inout pure nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))nfop; }
    static void decRef (usize me) {
      if (me) {
        auto zl = cast(LowLevelPackedRO*)me;
        assert(zl.rc);
        if (--zl.rc == 0) {
          import core.stdc.stdlib : free;
          if (zl.chunkData !is null) free(zl.chunkData);
          version(arcz_use_more_memory) if (zl.pkdata !is null) free(zl.pkdata);
          Nfo.decRef(zl.nfop);
          free(zl);
          debug(arcz_rc) { import core.stdc.stdio : printf; printf("Zl %p freed\n", zl); }
        } else {
          //debug(arcz_rc) { import core.stdc.stdio : printf; printf("Zl %p; rc after decRef is %u\n", zl, zl.rc); }
        }
      }
    }

    uint nextchunk; // next chunk to read
    uint curcpos; // position in current chunk
    uint curcsize; // number of valid bytes in `chunkData`
    uint stchunk; // starting chunk
    uint stofs; // offset in starting chunk
    uint totalsize; // total file size
    uint pos; // current file position
    uint lastrdpos; // last actual read position
    z_stream zs;
    ubyte* chunkData; // can be null
    version(arcz_use_more_memory) {
      ubyte* pkdata;
      uint pkdatasize;
    }

    @disable this (this);

    void setup (Nfo* anfo, uint astchunk, uint astofs, uint asize) {
      assert(anfo !is null);
      assert(rc == 1);
      nfop = cast(usize)anfo;
      ++anfo.rc;
      nextchunk = stchunk = astchunk;
      //curcpos = 0;
      stofs = astofs;
      totalsize = asize;
    }

    @property bool eof () { pragma(inline, true); return (pos >= totalsize); }

    // return less than chunk size if our file fits in one non-full chunk completely
    uint justEnoughMemory () pure const nothrow @safe @nogc {
      pragma(inline, true);
      version(none) {
        return nfo.chunkSize;
      } else {
        return (totalsize < nfo.chunkSize && stofs+totalsize < nfo.chunkSize ? stofs+totalsize : nfo.chunkSize);
      }
    }

    void unpackNextChunk () {
      if (nfop == 0) assert(0, "wtf?!");
      //scope(failure) if (chunkData !is null) { xfree(chunkData); chunkData = null; }
      debug(arcz_unp) { import core.stdc.stdio : printf; printf("unpacking chunk %u\n", nextchunk); }
      // allocate buffer for unpacked data
      if (chunkData is null) {
        // optimize things a little: if our file fits in less then one chunk, allocate "just enough" memory
        chunkData = xalloc!(ubyte, false)(justEnoughMemory);
      }
      auto chunk = &nfo.chunks[nextchunk];
      if (chunk.pksize == nfo.chunkSize) {
        // unpacked chunk, just read it
        debug(arcz_unp) { import core.stdc.stdio : printf; printf(" chunk is not packed\n"); }
        if (fseek(nfo.afl, chunk.ofs, 0) < 0) throw new Exception("ARCZ reading error");
        if (fread(chunkData, 1, nfo.chunkSize, nfo.afl) != nfo.chunkSize) throw new Exception("ARCZ reading error");
        curcsize = nfo.chunkSize;
      } else {
        // packed chunk, unpack it
        // allocate buffer for packed data
        version(arcz_use_more_memory) {
          import core.stdc.stdlib : realloc;
          if (pkdatasize < chunk.pksize) {
            import core.exception : onOutOfMemoryError;
            auto newpk = realloc(pkdata, chunk.pksize);
            if (newpk is null) onOutOfMemoryError();
            debug(arcz_alloc) { import core.stdc.stdio : printf; printf("reallocated from %u to %u bytes; %p -> %p\n", cast(uint)pkdatasize, cast(uint)chunk.pksize, pkdata, newpk); }
            pkdata = cast(ubyte*)newpk;
            pkdatasize = chunk.pksize;
          }
          alias pkd = pkdata;
        } else {
          auto pkd = xalloc!(ubyte, false)(chunk.pksize);
          scope(exit) xfree(pkd);
        }
        if (fseek(nfo.afl, chunk.ofs, 0) < 0) throw new Exception("ARCZ reading error");
        if (fread(pkd, 1, chunk.pksize, nfo.afl) != chunk.pksize) throw new Exception("ARCZ reading error");
        uint upsize = (nextchunk == nfo.chunks.length-1 ? nfo.lastChunkSize : nfo.chunkSize); // unpacked chunk size
        immutable uint cksz = upsize;
        immutable uint jem = justEnoughMemory;
        if (upsize > jem) upsize = jem;
        debug(arcz_unp) { import core.stdc.stdio : printf; printf(" unpacking %u bytes to %u bytes\n", chunk.pksize, upsize); }
        ArzArchive.unpackBlock(chunkData, upsize, pkd, chunk.pksize, cksz, nfo.useBalz);
        curcsize = upsize;
      }
      curcpos = 0;
      // fix first chunk offset if necessary
      if (nextchunk == stchunk && stofs > 0) {
        // it's easier to just memmove it
        import core.stdc.string : memmove;
        assert(stofs < curcsize);
        memmove(chunkData, chunkData+stofs, curcsize-stofs);
        curcsize -= stofs;
      }
      ++nextchunk; // advance to next chunk
    }

    void syncReadPos () {
      if (pos >= totalsize || pos == lastrdpos) return;
      immutable uint fcdata = nfo.chunkSize-stofs; // number of our bytes in the first chunk
      // does our pos lie in the first chunk?
      if (pos < fcdata) {
        // yep, just read it
        if (nextchunk != stchunk+1) {
          nextchunk = stchunk;
          unpackNextChunk(); // we'll need it anyway
        } else {
          // just rewind
          curcpos = 0;
        }
        curcpos += pos;
        lastrdpos = pos;
        return;
      }
      // find the chunk we want
      uint npos = pos-fcdata;
      uint xblock = stchunk+1+npos/nfo.chunkSize;
      uint curcstart = (xblock-(stchunk+1))*nfo.chunkSize+fcdata;
      if (xblock != nextchunk-1) {
        // read and unpack this chunk
        nextchunk = xblock;
        unpackNextChunk();
      } else {
        // just rewind
        curcpos = 0;
      }
      assert(pos >= curcstart && pos < curcstart+nfo.chunkSize);
      uint skip = pos-curcstart;
      lastrdpos = pos;
      curcpos += skip;
    }

    int read (void* buf, uint count) {
      if (buf is null) return -1;
      if (count == 0 || totalsize == 0) return 0;
      if (totalsize >= 0 && pos >= totalsize) return 0; // EOF
      syncReadPos();
      assert(lastrdpos == pos);
      if (cast(long)pos+count > totalsize) count = totalsize-pos;
      auto res = count;
      while (count > 0) {
        debug(arcz_read) { import core.stdc.stdio : printf; printf("reading %u bytes; pos=%u; lastrdpos=%u; curcpos=%u; curcsize=%u\n", count, pos, lastrdpos, curcpos, curcsize); }
        import core.stdc.string : memcpy;
        if (curcpos >= curcsize) {
          unpackNextChunk(); // we want next chunk!
          debug(arcz_read) { import core.stdc.stdio : printf; printf(" *reading %u bytes; pos=%u; lastrdpos=%u; curcpos=%u; curcsize=%u\n", count, pos, lastrdpos, curcpos, curcsize); }
        }
        assert(curcpos < curcsize && curcsize != 0);
        int rd = (curcsize-curcpos >= count ? count : curcsize-curcpos);
        assert(rd > 0);
        memcpy(buf, chunkData+curcpos, rd);
        curcpos += rd;
        pos += rd;
        lastrdpos += rd;
        buf += rd;
        count -= rd;
      }
      assert(pos == lastrdpos);
      return res;
    }

    long lseek (long ofs, int origin) {
      //TODO: overflow checks
      switch (origin) {
        case SEEK_SET: break;
        case SEEK_CUR: ofs += pos; break;
        case SEEK_END:
          if (ofs > 0) ofs = 0;
          if (-ofs > totalsize) ofs = -cast(long)totalsize;
          ofs += totalsize;
          break;
        default:
          return -1;
      }
      if (ofs < 0) return -1;
      if (totalsize >= 0 && ofs > totalsize) ofs = totalsize;
      pos = cast(uint)ofs;
      return pos;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// Opened file.
public struct AZFile {
private:
  usize zlp;

  private @property inout(ArzArchive.LowLevelPackedRO)* zl () inout pure nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))zlp; }
  private void decRef () { pragma(inline, true); ArzArchive.LowLevelPackedRO.decRef(zlp); zlp = 0; }

public:
  this (in AZFile afl) {
    assert(zlp == 0);
    zlp = afl.zlp;
    if (zlp) ++zl.rc;
  }

  this (this) {
    if (zlp) ++zl.rc;
  }

  ~this () { close(); }

  void opAssign (in AZFile afl) {
    if (afl.zlp) {
      auto n = cast(ArzArchive.LowLevelPackedRO*)afl.zlp;
      ++n.rc;
    }
    decRef();
    zlp = afl.zlp;
  }

  void close () { decRef(); }

  @property bool isOpen () const pure nothrow @safe @nogc { pragma(inline, true); return (zlp != 0); }
  @property uint size () const pure nothrow @safe @nogc { pragma(inline, true); return (zlp ? zl.totalsize : 0); }
  @property uint tell () const pure nothrow @safe @nogc { pragma(inline, true); return (zlp ? zl.pos : 0); }

  void seek (long ofs, int origin=SEEK_SET) {
    if (!zlp) throw new Exception("can't seek in closed file");
    auto res = zl.lseek(ofs, origin);
    if (res < 0) throw new Exception("seek error");
  }

  private import std.traits : isMutable;

  //TODO: overflow check
  T[] rawRead(T) (T[] buf) if (isMutable!T) {
    if (!zlp) throw new Exception("can't read from closed file");
    if (buf.length > 0) {
      auto res = zl.read(buf.ptr, buf.length*T.sizeof);
      if (res == -1 || res%T.sizeof != 0) throw new Exception("read error");
      return buf[0..res/T.sizeof];
    } else {
      return buf[0..0];
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/** this class can be used to create archive file.
 *
 * Example:
 * --------------------
 *  import std.file, std.path, std.stdio : File;
 *
 *  enum ArcName = "z00.arz";
 *  enum DirName = "experimental-docs";
 *
 *  ubyte[] rdbuf;
 *  rdbuf.length = 65536;
 *
 *  auto arcz = new ArzCreator(ArcName);
 *  long total = 0;
 *  foreach (DirEntry e; dirEntries(DirName, SpanMode.breadth)) {
 *    if (e.isFile) {
 *      assert(e.size < uint.max);
 *      //writeln(e.name);
 *      total += e.size;
 *      string fname = e.name[DirName.length+1..$];
 *      arcz.newFile(fname, cast(uint)e.size);
 *      auto fi = File(e.name);
 *      for (;;) {
 *        auto rd = fi.rawRead(rdbuf[]);
 *        if (rd.length == 0) break;
 *        arcz.rawWrite(rd[]);
 *      }
 *    }
 *  }
 *  arcz.close();
 *  writeln(total, " bytes packed to ", getSize(ArcName), " (", arcz.chunksWritten, " chunks, ", arcz.filesWritten, " files)");
 * --------------------
 */
final class ArzCreator {
private import etc.c.zlib;
private import core.stdc.stdio : FILE, fopen, fclose, ftell, fseek, fwrite;

public:
  //WARNING! don't change the order!
  enum Compressor {
    ZLib, // default
    Balz,
    BalzMax, // Balz, maximum compression
    Zopfli, // this will fallback to zlib if no zopfli support was compiled in
  }

private:
  static struct ChunkInfo {
    uint ofs; // offset in file
    uint pksize; // packed chunk size
  }

  static struct FileInfo {
    string name;
    uint chunk;
    uint chunkofs; // offset of first file byte in unpacked chunk
    uint size; // unpacked file size
  }

private:
  ubyte[] chunkdata;
  uint cdpos;
  FILE* arcfl;
  ChunkInfo[] chunks;
  FileInfo[] files;
  uint lastChunkSize;
  uint statChunks, statFiles;
  Compressor cpr = Compressor.ZLib;

private:
  void writeUint (uint v) {
    if (arcfl is null) throw new Exception("write error");
    version(BigEndian) {
      import core.bitop : bswap;
      v = bswap(v);
    } else version(LittleEndian) {
      // nothing to do
    } else {
      static assert(0, "wtf?!");
    }
    if (fwrite(&v, 1, v.sizeof, arcfl) != v.sizeof) throw new Exception("write error"); // signature
  }

  void writeUbyte (ubyte v) {
    if (arcfl is null) throw new Exception("write error");
    if (fwrite(&v, 1, v.sizeof, arcfl) != v.sizeof) throw new Exception("write error"); // signature
  }

  void writeBuf (const(void)[] buf) {
    if (buf.length > 0) {
      if (arcfl is null) throw new Exception("write error");
      if (fwrite(buf.ptr, 1, buf.length, arcfl) != buf.length) throw new Exception("write error"); // signature
    }
  }

  static if (arcz_has_balz) long writePackedBalz (const(void)[] upbuf) {
    assert(upbuf.length > 0 && upbuf.length < int.max);
    long res = 0;
    Balz bz;
    int ipos, opos;
    bz.reinit(ArzArchive.balzDictSize(cast(uint)upbuf.length));
    bz.compress(
      // reader
      (buf) {
        import core.stdc.string : memcpy;
        if (ipos >= upbuf.length) return 0;
        uint rd = cast(uint)upbuf.length-ipos;
        if (rd > buf.length) rd = cast(uint)buf.length;
        memcpy(buf.ptr, upbuf.ptr+ipos, rd);
        ipos += rd;
        return rd;
      },
      // writer
      (buf) {
        res += buf.length;
        writeBuf(buf[]);
      },
      // max mode
      (cpr == Compressor.BalzMax)
    );
    return res;
  }

  static if (arcz_has_zopfli) long writePackedZopfli (const(void)[] upbuf) {
    ubyte[] indata;
    void* odata;
    usize osize;
    ZopfliOptions opts;
    ZopfliCompress(opts, ZOPFLI_FORMAT_ZLIB, upbuf.ptr, upbuf.length, &odata, &osize);
    writeBuf(odata[0..osize]);
    ZopfliFree(odata);
    return cast(long)osize;
  }

  long writePackedZLib (const(void)[] upbuf) {
    assert(upbuf.length > 0 && upbuf.length < int.max);
    long res = 0;
    z_stream zs;
    ubyte[2048] obuf;
    zs.next_out = obuf.ptr;
    zs.avail_out = cast(uint)obuf.length;
    zs.next_in = null;
    zs.avail_in = 0;
    // initialize packer
    if (deflateInit2(&zs, Z_BEST_COMPRESSION, Z_DEFLATED, 15, 9, 0) != Z_OK) throw new Exception("can't write packed data");
    scope(exit) deflateEnd(&zs);
    zs.next_in = cast(typeof(zs.next_in))upbuf.ptr;
    zs.avail_in = cast(uint)upbuf.length;
    while (zs.avail_in > 0) {
      if (zs.avail_out == 0) {
        res += cast(uint)obuf.length;
        writeBuf(obuf[]);
        zs.next_out = obuf.ptr;
        zs.avail_out = cast(uint)obuf.length;
      }
      auto err = deflate(&zs, Z_NO_FLUSH);
      if (err != Z_OK) throw new Exception("zlib compression error");
    }
    while (zs.avail_out != obuf.length) {
      res += cast(uint)obuf.length-zs.avail_out;
      writeBuf(obuf[0..$-zs.avail_out]);
      zs.next_out = obuf.ptr;
      zs.avail_out = cast(uint)obuf.length;
      auto err = deflate(&zs, Z_FINISH);
      if (err != Z_OK && err != Z_STREAM_END) throw new Exception("zlib compression error");
      // succesfully flushed?
      //if (err != Z_STREAM_END) throw new VFSException("zlib compression error");
    }
    return res;
  }

  // return size of packed data written
  uint writePackedBuf (const(void)[] upbuf) {
    assert(upbuf.length > 0 && upbuf.length < int.max);
    long res = 0;
    final switch (cpr) {
      case Compressor.ZLib:
        res = writePackedZLib(upbuf);
        break;
      case Compressor.Balz:
      case Compressor.BalzMax:
        static if (arcz_has_balz) {
          res = writePackedBalz(upbuf);
          break;
        } else {
          new Exception("no Balz support was compiled in ArcZ");
        }
      case Compressor.Zopfli:
        static if (arcz_has_zopfli) {
          res = writePackedZopfli(upbuf);
          //break;
        } else {
          //new Exception("no Zopfli support was compiled in ArcZ");
          res = writePackedZLib(upbuf);
        }
        break;
    }
    if (res > uint.max) throw new Exception("output archive too big");
    return cast(uint)res;
  }

  void flushData () {
    if (cdpos > 0) {
      ChunkInfo ci;
      auto pos = ftell(arcfl);
      if (pos < 0 || pos >= uint.max) throw new Exception("output archive too big");
      ci.ofs = cast(uint)pos;
      auto wlen = writePackedBuf(chunkdata[0..cdpos]);
      ci.pksize = wlen;
      if (cdpos == chunkdata.length && ci.pksize >= chunkdata.length) {
        // wow, this chunk is unpackable
        //{ import std.stdio; writeln("unpackable chunk found!"); }
        if (fseek(arcfl, pos, 0) < 0) throw new Exception("can't seek in output file");
        writeBuf(chunkdata[0..cdpos]);
        version(Posix) {
          import core.stdc.stdio : fileno;
          import core.sys.posix.unistd : ftruncate;
          pos = ftell(arcfl);
          if (pos < 0 || pos >= uint.max) throw new Exception("output archive too big");
          if (ftruncate(fileno(arcfl), cast(uint)pos) < 0) throw new Exception("error truncating output file");
        }
        ci.pksize = cdpos;
      }
      if (cdpos < chunkdata.length) lastChunkSize = cast(uint)cdpos;
      cdpos = 0;
      chunks ~= ci;
    } else {
      lastChunkSize = cast(uint)chunkdata.length;
    }
  }

  void closeArc () {
    flushData();
    // write index
    //assert(ftell(arcfl) > 0 && ftell(arcfl) < uint.max);
    assert(chunkdata.length < uint.max);
    assert(chunks.length < uint.max);
    assert(files.length < uint.max);
    // create index in memory
    ubyte[] index;

    void putUint (uint v) {
      index ~= v&0xff;
      index ~= (v>>8)&0xff;
      index ~= (v>>16)&0xff;
      index ~= (v>>24)&0xff;
    }

    void putUbyte (ubyte v) {
      index ~= v;
    }

    void putBuf (const(void)[] buf) {
      assert(buf.length > 0);
      index ~= (cast(const(ubyte)[])buf)[];
    }

    // create index in memory
    {
      // chunk size
      putUint(cast(uint)chunkdata.length);
      // chunk count
      putUint(cast(uint)chunks.length);
      // last chunk size
      putUint(lastChunkSize); // 0: last chunk is full
      // chunk offsets and sizes
      foreach (ref ci; chunks) {
        putUint(ci.ofs);
        putUint(ci.pksize);
      }
      // file count
      putUint(cast(uint)files.length);
      uint nbofs = cast(uint)index.length+cast(uint)files.length*(5*4);
      //uint nbofs = 0;
      // files
      foreach (ref fi; files) {
        // name: length(byte), chars
        assert(fi.name.length > 0 && fi.name.length <= 16384);
        putUint(nbofs);
        putUint(cast(uint)fi.name.length);
        nbofs += cast(uint)fi.name.length+1; // put zero byte there to ease C interfacing
        //putBuf(fi.name[]);
        // chunk number
        putUint(fi.chunk);
        // offset in unpacked chunk
        putUint(fi.chunkofs);
        // unpacked size
        putUint(fi.size);
      }
      // names
      foreach (ref fi; files) {
        putBuf(fi.name[]);
        putUbyte(0); // this means nothing, it is here just for convenience (hello, C!)
      }
      assert(index.length < uint.max);
    }
    auto cpos = ftell(arcfl);
    if (cpos < 0 || cpos > uint.max) throw new Exception("output archive too big");
    // write packed index
    debug(arcz_writer) { import core.stdc.stdio : pinrtf; printf("index size: %u\n", cast(uint)index.length); }
    auto pkisz = writePackedBuf(index[]);
    debug(arcz_writer) { import core.stdc.stdio : pinrtf; printf("packed index size: %u\n", cast(uint)pkisz); }
    // write index info
    if (fseek(arcfl, 5, 0) < 0) throw new Exception("seek error");
    // index offset in file
    writeUint(cpos);
    // packed index size
    writeUint(pkisz);
    // unpacked index size
    writeUint(cast(uint)index.length);
    // done
    statChunks = cast(uint)chunks.length;
    statFiles = cast(uint)files.length;
  }

public:
  this (const(char)[] fname, uint chunkSize=256*1024, Compressor acpr=Compressor.ZLib) {
    import std.internal.cstring;
    assert(chunkSize > 0 && chunkSize < 32*1024*1024); // arbitrary limit
    static if (!arcz_has_balz) {
      if (acpr == Compressor.Balz || acpr == Compressor.BalzMax) throw new Exception("no Balz support was compiled in ArcZ");
    }
    static if (!arcz_has_zopfli) {
      //if (acpr == Compressor.Zopfli) throw new Exception("no Zopfli support was compiled in ArcZ");
    }
    cpr = acpr;
    arcfl = fopen(fname.tempCString, "wb");
    if (arcfl is null) throw new Exception("can't create output file '"~fname.idup~"'");
    cdpos = 0;
    chunkdata.length = chunkSize;
    scope(failure) { fclose(arcfl); arcfl = null; }
    writeBuf("CZA2"); // signature
    if (cpr == Compressor.Balz || cpr == Compressor.BalzMax) {
      writeUbyte(1); // version
    } else {
      writeUbyte(0); // version
    }
    writeUint(0); // offset to index
    writeUint(0); // packed index size
    writeUint(0); // unpacked index size
  }

  ~this () { close(); }

  void close () {
    if (arcfl !is null) {
      scope(exit) { fclose(arcfl); arcfl = null; }
      closeArc();
    }
    chunkdata = null;
    chunks = null;
    files = null;
    lastChunkSize = 0;
    cdpos = 0;
  }

  // valid after closing
  @property uint chunksWritten () const pure nothrow @safe @nogc { pragma(inline, true); return statChunks; }
  @property uint filesWritten () const pure nothrow @safe @nogc { pragma(inline, true); return statFiles; }

  void newFile (string name, uint size) {
    FileInfo fi;
    assert(name.length <= 255);
    fi.name = name;
    fi.chunk = cast(uint)chunks.length;
    fi.chunkofs = cast(uint)cdpos;
    fi.size = size;
    files ~= fi;
  }

  void rawWrite(T) (const(T)[] buffer) {
    if (buffer.length > 0) {
      auto src = cast(const(ubyte)*)buffer.ptr;
      auto len = buffer.length*T.sizeof;
      while (len > 0) {
        if (cdpos == chunkdata.length) flushData();
        if (cdpos < chunkdata.length) {
          auto wr = chunkdata.length-cdpos;
          if (wr > len) wr = len;
          chunkdata[cdpos..cdpos+wr] = src[0..wr];
          cdpos += wr;
          len -= wr;
          src += wr;
        }
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/* arcz file format:
header
======
db 'CZA2'     ; signature
db version    ; 0: zlib; 1: balz
dd indexofs   ; offset to packed index
dd pkindexsz  ; size of packed index
dd upindexsz  ; size of unpacked index


index
=====
dd chunksize    ; unpacked chunk size in bytes
dd chunkcount   ; number of chunks in file
dd lastchunksz  ; size of last chunk (it may be incomplete); 0: last chunk is completely used (all `chunksize` bytes)

then chunk offsets and sizes follows:
  dd chunkofs   ; from file start
  dd pkchunksz  ; size of (possibly packed) chunk data; if it equals to `chunksize`, this chunk is not packed

then file list follows:
dd filecount  ; number of files in archive

then file info follows:
  dd nameofs     ; (in index)
  dd namelen     ; length of name (can't be 0)
  dd firstchunk  ; chunk where file starts
  dd firstofs    ; offset in first chunk (unpacked) where file starts
  dd filesize    ; unpacked file size

then name buffer follows -- just bytes
*/
