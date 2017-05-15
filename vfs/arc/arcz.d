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
module iv.vfs.arc.arcz is aliced;

import iv.vfs.types : Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"ArcZ");

// use Balz compressor if available
static if (__traits(compiles, { import iv.balz; })) enum iv_vfs_arcz_has_balz = true; else enum iv_vfs_arcz_has_balz = false;
static if (iv_vfs_arcz_has_balz) import iv.balz;


// ////////////////////////////////////////////////////////////////////////// //
// ARZ archive accessor. Use this to open ARZ archives, and open packed files from ARZ archives.
private struct ArzArchive {
private import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;
private:
  static assert(usize.sizeof >= (void*).sizeof);
  private import etc.c.zlib;

  static align(1) struct ChunkInfo {
  align(1):
    uint ofs; // offset in file
    uint pksize; // packed chunk size (same as chunk size: chunk is unpacked)
  }

  static align(1) struct FileInfo {
  align(1):
    //string name;
    uint nameofs; // in index
    uint namelen;
    const(char)[] name (const(void)* index) const pure nothrow @trusted @nogc { pragma(inline, true); return (cast(const(char)*)index)[nameofs..nameofs+namelen]; }
    // this is copied from index
    uint chunk;
    uint chunkofs; // offset of first file byte in unpacked chunk
    uint size; // unpacked file size
  }

  static struct Nfo {
    uint rc = 1; // refcounter
    ubyte* index; // unpacked archive index
    ChunkInfo* chunks; // in index, not allocated
    FileInfo* files; // in index, not allocated
    uint fcount; // number of valid entries in files
    uint ccount; // number of valid entries in chunks
    uint chunkSize;
    uint lastChunkSize;
    bool useBalz;
    VFile afl; // archive file, we'll keep it opened

    @disable this (this); // no copies!

    static void decRef (usize me) {
      if (me) {
        auto nfo = cast(Nfo*)me;
        assert(nfo.rc);
        if (--nfo.rc == 0) {
          import core.memory : GC;
          import core.stdc.stdlib : free;
          if (nfo.afl.isOpen) nfo.afl.close();
          if (nfo.index !is null) free(nfo.index);
          //GC.removeRange(cast(void*)nfo/*, Nfo.sizeof*/);
          free(nfo);
          debug(iv_vfs_arcz_rc) { import core.stdc.stdio : printf; printf("Nfo %p freed\n", nfo); }
        }
      }
    }
  }

  usize nfop; // hide it from GC

  private @property Nfo* nfo () { pragma(inline, true); return cast(Nfo*)nfop; }
  void decRef () { pragma(inline, true); Nfo.decRef(nfop); nfop = 0; }

  static uint readUint (VFile fl) {
    if (!fl.isOpen) throw new Exception("cannot read from closed file");
    uint v;
    fl.rawReadExact((&v)[0..1]);
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

  static uint readUbyte (VFile fl) {
    if (!fl.isOpen) throw new Exception("cannot read from closed file");
    ubyte v;
    fl.rawReadExact((&v)[0..1]);
    return v;
  }

  static void readBuf (VFile fl, void[] buf) {
    if (buf.length > 0) {
      fl.rawReadExact(buf[]);
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
      debug(iv_vfs_arcz_alloc) { import core.stdc.stdio : printf; printf("allocated %u bytes at %p\n", cast(uint)(mem*T.sizeof), res); }
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
      debug(iv_vfs_arcz_alloc) { import core.stdc.stdio : printf; printf("allocated %u bytes at %p\n", cast(uint)(mem*T.sizeof), res); }
      return cast(T*)res;
    }
  }

  static void xfree(T) (T* ptr) {
    if (ptr !is null) {
      import core.stdc.stdlib : free;
      debug(iv_vfs_arcz_alloc) { import core.stdc.stdio : printf; printf("freing at %p\n", ptr); }
      free(ptr);
    }
  }

  static if (iv_vfs_arcz_has_balz) static ubyte balzDictSize (uint blockSize) {
    foreach (ubyte bits; Balz.MinDictBits..Balz.MaxDictBits+1) {
      if ((1U<<bits) >= blockSize) return bits;
    }
    return Balz.MaxDictBits;
  }

  // unpack exactly `destlen` bytes
  static if (iv_vfs_arcz_has_balz) static void unpackBlockBalz (void* dest, uint destlen, const(void)* src, uint srclen, uint blocksize) {
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
      static if (iv_vfs_arcz_has_balz) {
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

  //@property FileInfo[string] files () { return (nfop ? nfo.files : null); }

  void openArchive (VFile fl) {
    debug/*(arcz)*/ import core.stdc.stdio : printf;
    char[4] sign;
    bool useBalz;
    readBuf(fl, sign[]);
    if (sign != "CZA2") throw new Exception("invalid arcz archive file");
    switch (readUbyte(fl)) {
      case 0: useBalz = false; break;
      case 1: useBalz = true; break;
      default: throw new Exception("invalid version of arcz archive file");
    }
    uint indexofs = readUint(fl); // index offset in file
    uint pkidxsize = readUint(fl); // packed index size
    uint idxsize = readUint(fl); // unpacked index size
    if (pkidxsize == 0 || idxsize == 0 || indexofs == 0) throw new Exception("invalid arcz archive file");
    // now read index
    ubyte* idxbuf = null;
    scope(failure) xfree(idxbuf);
    {
      auto pib = xalloc!ubyte(pkidxsize);
      scope(exit) xfree(pib);
      fl.seek(indexofs);
      readBuf(fl, pib[0..pkidxsize]);
      idxbuf = xalloc!ubyte(idxsize);
      unpackBlock(idxbuf, idxsize, pib, pkidxsize, idxsize, useBalz);
    }

    // parse index and build structures
    uint idxbufpos = 0;

    ubyte getUbyte () {
      if (idxsize-idxbufpos < ubyte.sizeof) throw new Exception("invalid index for arcz archive file");
      return idxbuf[idxbufpos++];
    }

    uint getUint () {
      if (idxsize-idxbufpos < uint.sizeof) throw new Exception("invalid index for arcz archive file");
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
        if (idxsize-idxbufpos < buf.length) throw new Exception("invalid index for arcz archive file");
        memcpy(buf.ptr, idxbuf+idxbufpos, buf.length);
        idxbufpos += buf.length;
      }
    }

    void skipBuf (uint len) {
      if (len > 0) {
        if (idxsize-idxbufpos < len) throw new Exception("invalid index for arcz archive file");
        idxbufpos += len;
      }
    }

    // allocate shared info struct
    Nfo* nfo = xalloc!Nfo(1);
    assert(nfo.rc == 1);
    debug(iv_vfs_arcz_rc) { import core.stdc.stdio : printf; printf("Nfo %p allocated\n", nfo); }
    scope(failure) decRef();
    nfop = cast(usize)nfo;
    /* no need to, there is nothing that needs GC there
    {
      import core.memory : GC;
      GC.addRange(nfo, Nfo.sizeof);
    }
    */

    // read chunk info and data
    nfo.useBalz = useBalz;
    nfo.chunkSize = getUint;
    auto ccount = getUint; // chunk count
    nfo.lastChunkSize = getUint;
    debug(iv_vfs_arcz_dirread) printf("chunk size: %u\nchunk count: %u\nlast chunk size:%u\n", nfo.chunkSize, ccount, nfo.lastChunkSize);
    if (ccount == 0 || nfo.chunkSize < 1 || nfo.lastChunkSize < 1 || nfo.lastChunkSize > nfo.chunkSize) throw new Exception("invalid arcz archive file");
    /*
    nfo.chunks.length = ccount;
    // chunk offsets and sizes
    foreach (ref ci; nfo.chunks) {
      ci.ofs = getUint;
      ci.pksize = getUint;
    }
    */
    nfo.chunks = cast(ChunkInfo*)(idxbuf+idxbufpos);
    nfo.ccount = ccount;
    skipBuf(ccount*8);
    // fix endianness
    version(BigEndian) {
      foreach (ref ChunkInfo ci; nfo.chunks[0..ccount]) {
        import core.bitop : bswap;
        ci.ofs = bswap(ci.ofs);
        ci.pksize = bswap(ci.pksize);
      }
    }
    // read file count and info
    auto fcount = getUint;
    if (fcount == 0) throw new Exception("empty arcz archive");
    debug(iv_vfs_arcz_dirread) printf("file count: %u\n", fcount);
    if (fcount >= uint.max/(5*4)) throw new Exception("too many files in arcz archive");
    if (fcount*(5*4) > idxsize-idxbufpos) throw new Exception("invalid index in arcz archive");
    nfo.files = cast(FileInfo*)(idxbuf+idxbufpos);
    nfo.fcount = fcount;
    skipBuf(fcount*(5*4));
    //immutable uint ubofs = idxbufpos;
    //immutable uint ubsize = idxsize-ubofs;
    foreach (ref FileInfo fi; nfo.files[0..fcount]) {
      // fix endianness
      version(BigEndian) {
        import core.bitop : bswap;
        fi.nameofs = bswap(fi.nameofs);
        fi.namelen = bswap(fi.namelen);
        fi.chunk = bswap(fi.chunk);
        fi.chunkofs = bswap(fi.chunkofs);
        fi.size = bswap(fi.size);
      }
      if (fi.namelen > idxsize || fi.nameofs > idxsize || fi.nameofs+fi.namelen > idxsize) throw new Exception("invalid index in arcz archive");
    }
    // transfer achive file ownership
    nfo.afl = fl;
    nfo.index = idxbuf;
  }

  //bool exists (const(char)[] name) { if (nfop) return ((name in nfo.files) !is null); else return false; }

  AZFile openByIndex (uint idx) {
    if (!nfop) throw new Exception("can't open file from non-opened archive");
    if (idx >= nfo.fcount) throw new Exception("can't open non-existing file");
    auto fi = nfo.files+idx;
    auto zl = xalloc!LowLevelPackedRO(1);
    scope(failure) xfree(zl);
    debug(iv_vfs_arcz_rc) { import core.stdc.stdio : printf; printf("Zl %p allocated\n", zl); }
    zl.setup(nfo, fi.chunk, fi.chunkofs, fi.size);
    AZFile fl;
    fl.zlp = cast(usize)zl;
    return fl;
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
          version(iv_vfs_arcz_use_more_memory) if (zl.pkdata !is null) free(zl.pkdata);
          Nfo.decRef(zl.nfop);
          free(zl);
          debug(iv_vfs_arcz_rc) { import core.stdc.stdio : printf; printf("Zl %p freed\n", zl); }
        } else {
          //debug(iv_vfs_arcz_rc) { import core.stdc.stdio : printf; printf("Zl %p; rc after decRef is %u\n", zl, zl.rc); }
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
    version(iv_vfs_arcz_use_more_memory) {
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
      debug(iv_vfs_arcz_unp) { import core.stdc.stdio : printf; printf("unpacking chunk %u\n", nextchunk); }
      // allocate buffer for unpacked data
      if (chunkData is null) {
        // optimize things a little: if our file fits in less then one chunk, allocate "just enough" memory
        chunkData = xalloc!(ubyte, false)(justEnoughMemory);
      }
      auto chunk = &nfo.chunks[nextchunk];
      if (chunk.pksize == nfo.chunkSize) {
        // unpacked chunk, just read it
        debug(iv_vfs_arcz_unp) { import core.stdc.stdio : printf; printf(" chunk is not packed\n"); }
        nfo.afl.seek(chunk.ofs, Seek.Set);
        nfo.afl.rawReadExact(chunkData[0..nfo.chunkSize]);
        curcsize = nfo.chunkSize;
      } else {
        // packed chunk, unpack it
        // allocate buffer for packed data
        version(iv_vfs_arcz_use_more_memory) {
          import core.stdc.stdlib : realloc;
          if (pkdatasize < chunk.pksize) {
            import core.exception : onOutOfMemoryError;
            auto newpk = realloc(pkdata, chunk.pksize);
            if (newpk is null) onOutOfMemoryError();
            debug(iv_vfs_arcz_alloc) { import core.stdc.stdio : printf; printf("reallocated from %u to %u bytes; %p -> %p\n", cast(uint)pkdatasize, cast(uint)chunk.pksize, pkdata, newpk); }
            pkdata = cast(ubyte*)newpk;
            pkdatasize = chunk.pksize;
          }
          alias pkd = pkdata;
        } else {
          auto pkd = xalloc!(ubyte, false)(chunk.pksize);
          scope(exit) xfree(pkd);
        }
        nfo.afl.seek(chunk.ofs, Seek.Set);
        nfo.afl.rawReadExact(pkd[0..chunk.pksize]);
        uint upsize = (nextchunk == nfo.ccount-1 ? nfo.lastChunkSize : nfo.chunkSize); // unpacked chunk size
        immutable uint cksz = upsize;
        immutable uint jem = justEnoughMemory;
        if (upsize > jem) upsize = jem;
        debug(iv_vfs_arcz_unp) { import core.stdc.stdio : printf; printf(" unpacking %u bytes to %u bytes\n", chunk.pksize, upsize); }
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

    ssize read (void* buf, usize count) {
      if (buf is null) return -1;
      if (count == 0 || totalsize == 0) return 0;
      if (totalsize >= 0 && pos >= totalsize) return 0; // EOF
      syncReadPos();
      assert(lastrdpos == pos);
      if (cast(long)pos+count > totalsize) count = totalsize-pos;
      auto res = count;
      while (count > 0) {
        debug(iv_vfs_arcz_read) { import core.stdc.stdio : printf; printf("reading %u bytes; pos=%u; lastrdpos=%u; curcpos=%u; curcsize=%u\n", count, pos, lastrdpos, curcpos, curcsize); }
        import core.stdc.string : memcpy;
        if (curcpos >= curcsize) {
          unpackNextChunk(); // we want next chunk!
          debug(iv_vfs_arcz_read) { import core.stdc.stdio : printf; printf(" *reading %u bytes; pos=%u; lastrdpos=%u; curcpos=%u; curcsize=%u\n", count, pos, lastrdpos, curcpos, curcsize); }
        }
        assert(curcpos < curcsize && curcsize != 0);
        ssize rd = (curcsize-curcpos >= count ? count : curcsize-curcpos);
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
// Opened file.
private struct AZFile {
private import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;
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

  //TODO: overflow check
  T[] rawRead(T) (T[] buf) if (!is(T == const) && !is(T == immutable)) {
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
public final class VFSDriverArcZ : VFSDriver {
  mixin VFSSimpleArchiveDriverMixin;

private:
  ArzArchive arc;

  static struct FileInfo {
    long size;
    string name; // with path
    uint aidx;
  }

  VFile wrap (usize idx) { return wrapStream(arc.openByIndex(dir[idx].aidx), dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    arc.openArchive(fl);
    debug(iv_vfs_arcz_dirread) { import core.stdc.stdio; printf("files: %u\n", cast(uint)arc.nfo.fcount); }
    foreach (immutable aidx, ref afi; arc.nfo.files[0..arc.nfo.fcount]) {
      auto xname = afi.name(arc.nfo.index);
      if (xname.length == 0) continue; // just in case
      FileInfo fi;
      fi.size = afi.size;
      fi.aidx = cast(uint)aidx;
      auto name = new char[](prefixpath.length+xname.length);
      if (prefixpath.length) name[0..prefixpath.length] = prefixpath;
      name[prefixpath.length..$] = xname[];
      fi.name = cast(string)name; // it is safe to cast here
      dir.arrayAppendUnsafe(fi);
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
