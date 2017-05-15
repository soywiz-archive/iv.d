/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.audiostream is aliced;
private:

//import iv.cmdcon;
import iv.id3v2;
import iv.mp3scan;
import iv.strex;
import iv.utfutil;
import iv.vfs;

import iv.dopus;
import iv.drflac;
import iv.minimp3;
import iv.tremor;


// ////////////////////////////////////////////////////////////////////////// //
public class AudioStream {
public:
  enum Type {
    Unknown,
    Opus,
    Vorbis,
    Flac,
    Mp3,
  }

protected:
  VFile fl;
  Type mType = Type.Unknown;
  uint mRate = 1; // just in case
  ubyte mChannels = 1; // just in case
  ulong mSamplesTotal; // multiplied by channels
  ulong mSamplesRead;  // samples read so far, multiplied by channels
  bool mOnlyMeta = false;

protected:

  final int reader (void[] buf) {
    try {
      auto rd = fl.rawRead(buf);
      return cast(int)rd.length;
    } catch (Exception e) {}
    return -1;
  }

protected:
  this () {}

public:
  string album;
  string artist;
  string title;

public:
  final @property uint rate () const pure nothrow @safe @nogc { pragma(inline, true); return mRate; }
  final @property ubyte channels () const pure nothrow @safe @nogc { pragma(inline, true); return mChannels; }

  final @property ulong framesRead () const pure nothrow @safe @nogc { pragma(inline, true); return mSamplesRead/mChannels; }
  final @property ulong framesTotal () const pure nothrow @safe @nogc { pragma(inline, true); return mSamplesTotal/mChannels; }

  final @property uint timeRead () const pure nothrow @safe @nogc { pragma(inline, true); return cast(uint)(mSamplesRead*1000/mRate/mChannels); }
  final @property uint timeTotal () const pure nothrow @safe @nogc { pragma(inline, true); return cast(uint)(mSamplesTotal*1000/mRate/mChannels); }

  final @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (mType != Type.Unknown); }

  final @property bool onlyMeta () const pure nothrow @safe @nogc { pragma(inline, true); return mOnlyMeta; }

  void close () {
    mType = Type.Unknown;
    mRate = 1;
    mChannels = 1;
    mSamplesTotal = mSamplesRead = 0;
    album = artist = title = null;
    fl.close();
  }

  abstract int readFrames (void* buf, int count);

  // return new frame index
  abstract ulong seekToTime (uint msecs);

public:
  static AudioStream detect (VFile fl, bool onlymeta=false) nothrow {
    bool didOpus, didVorbis, didFlac, didMp3;

    AudioStream tryFormat(T : AudioStream) (ref bool didit) nothrow {
      if (didit) return null;
      didit = true;
      //conwriteln("trying ", T.stringof);
      try {
        fl.seek(0);
        if (auto ast = T.detect(fl, onlymeta)) return ast;
      } catch (Exception e) {
        //conwriteln("DETECT ERROR: ", e.msg);
      }
      return null;
    }

    AudioStream tryOpus () nothrow { return tryFormat!AudioStreamOpus(didOpus); }
    AudioStream tryVorbis () nothrow { return tryFormat!AudioStreamVorbis(didVorbis); }
    AudioStream tryFlac () nothrow { return tryFormat!AudioStreamFlac(didFlac); }
    AudioStream tryMp3 () nothrow { return tryFormat!AudioStreamMp3(didMp3); }

    try {
      auto fname = fl.name;
      auto extpos = fname.lastIndexOf('.');
      if (extpos >= 0) {
        auto ext = fname[extpos..$];
             if (ext.strEquCI(".opus")) { if (auto ast = tryOpus()) return ast; }
        else if (ext.strEquCI(".ogg")) { if (auto ast = tryVorbis()) return ast; }
        else if (ext.strEquCI(".flac")) { if (auto ast = tryFlac()) return ast; }
        else if (ext.strEquCI(".mp3")) { if (auto ast = tryMp3()) return ast; }
      }
      // this is fastest for my collection
      if (auto ast = tryFlac()) return ast;
      if (auto ast = tryOpus()) return ast;
      if (auto ast = tryVorbis()) return ast;
      if (auto ast = tryMp3()) return ast;
    } catch (Exception e) {}
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
final class AudioStreamOpus : AudioStream {
private:
  OpusFile of;
  short[] smpbuf;
  uint smpbufpos, smpbufused;

protected:
  this () {}

public:
  override void close () {
    opusClose(of);
    delete smpbuf;
    smpbufpos = smpbufused = 0;
    super.close();
  }

  override int readFrames (void* buf, int count) {
    if (count < 1) return 0;
    if (count > int.max/4) count = int.max/4;
    if (!valid || onlyMeta) return 0;

    auto dptr = cast(short*)buf;
    if (of is null) return 0;
    int total = 0;
    while (count > 0) {
      while (count > 0 && smpbufpos < smpbufused) {
        *dptr++ = smpbuf.ptr[smpbufpos++];
        if (mChannels == 2) *dptr++ = smpbuf.ptr[smpbufpos++];
        --count;
        ++total;
        mSamplesRead += mChannels;
      }
      if (count == 0) break;
      auto rd = of.readFrame();
      if (rd.length == 0) break;
      if (rd.length > smpbuf.length) {
        auto optr = smpbuf.ptr;
        smpbuf.length = rd.length;
        if (smpbuf.ptr !is optr) {
          import core.memory : GC;
          if (smpbuf.ptr is GC.addrOf(smpbuf.ptr)) GC.setAttr(smpbuf.ptr, GC.BlkAttr.NO_INTERIOR);
        }
      }
      smpbuf[0..rd.length] = rd[];
      smpbufpos = 0;
      smpbufused = cast(uint)rd.length;
    }
    return total;
  }

  override ulong seekToTime (uint msecs) {
    if (!valid || onlyMeta) return 0;
    ulong snum = cast(ulong)msecs*mRate/1000*mChannels; // sample number

    if (of is null) return 0;
    of.seek(msecs);
    mSamplesRead = of.smpcurtime*mChannels;
    return mSamplesRead/mChannels;
  }

protected:
  static AudioStreamOpus detect (VFile fl, bool onlymeta) {
    OpusFile of = opusOpen(fl);
    scope(failure) opusClose(of);
    if (of.rate < 1024 || of.rate > 96000) throw new Exception("fucked opus");
    if (of.channels < 1 || of.channels > 2) throw new Exception("fucked opus");
    AudioStreamOpus sio = new AudioStreamOpus();
    sio.of = of;
    sio.mType = Type.Opus;
    sio.fl = fl;
    sio.mRate = of.rate;
    sio.mChannels = of.channels;
    sio.mOnlyMeta = onlymeta;
    //conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (opus)");
    sio.mSamplesTotal = of.smpduration*sio.mChannels;
    //if (of.vendor.length) conwriteln("Encoded by: ", of.vendor.recodeToKOI8);
    foreach (immutable cidx; 0..of.commentCount) {
      //conwriteln("  ", of.comment(cidx).recodeToKOI8);
      auto cmts = of.comment(cidx);
           if (cmts.startsWithCI("ALBUM=")) sio.album = cmts[6..$].xstrip.idup;
      else if (cmts.startsWithCI("ARTIST=")) sio.artist = cmts[7..$].xstrip.idup;
      else if (cmts.startsWithCI("TITLE=")) sio.title = cmts[6..$].xstrip.idup;
    }
    if (onlymeta) {
      scope(exit) { of = null; sio.of = null; sio.fl.close(); }
      opusClose(sio.of);
    }
    //conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
    return sio;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
final class AudioStreamVorbis : AudioStream {
private:
  OggVorbis_File vf;
  vorbis_info* vi;

protected:
  this () {}

public:
  override void close () {
    if (vi !is null) { vi = null; ov_clear(&vf); }
    super.close();
  }

  override int readFrames (void* buf, int count) {
    if (count < 1) return 0;
    if (count > int.max/4) count = int.max/4;
    if (!valid || onlyMeta) return 0;

    if (vi is null) return 0;
    int currstream = 0;
    auto ret = ov_read(&vf, cast(ubyte*)buf, count*2*mChannels, &currstream);
    if (ret <= 0) return 0; // error or eof
    mSamplesRead += ret/2; // number of samples read
    return ret/2/mChannels; // number of frames read
  }

  override ulong seekToTime (uint msecs) {
    if (!valid || onlyMeta) return 0;
    ulong snum = cast(ulong)msecs*mRate/1000*mChannels; // sample number

    if (vi is null) return 0;
    if (ov_pcm_seek(&vf, snum/mChannels) == 0) {
      mSamplesRead = ov_pcm_tell(&vf)*mChannels;
      return mSamplesRead/mChannels;
    }
    ov_pcm_seek(&vf, 0);
    return 0;
  }

protected:
  static AudioStreamVorbis detect (VFile fl, bool onlymeta) {
    OggVorbis_File vf;
    if (ov_fopen(fl, &vf) == 0) {
      scope(failure) ov_clear(&vf);
      auto sio = new AudioStreamVorbis();
      scope(failure) delete sio;
      sio.mType = Type.Vorbis;
      sio.mOnlyMeta = onlymeta;
      sio.fl = fl;
      sio.vi = ov_info(&vf, -1);
      if (sio.vi.rate < 1024 || sio.vi.rate > 96000) throw new Exception("fucked vorbis");
      if (sio.vi.channels < 1 || sio.vi.channels > 2) throw new Exception("fucked vorbis");
      sio.mRate = sio.vi.rate;
      sio.mChannels = cast(ubyte)sio.vi.channels;
      //conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (vorbis)");
      //conwriteln("streams: ", ov_streams(&sio.vf));
      //conwriteln("bitrate: ", ov_bitrate(&sio.vf));
      sio.mSamplesTotal = ov_pcm_total(&vf)*sio.mChannels;
      if (auto vc = ov_comment(&vf, -1)) {
        //conwriteln("Encoded by: ", vc.vendor.fromStringz.recodeToKOI8);
        foreach (immutable idx; 0..vc.comments) {
          //conwriteln("  ", vc.user_comments[idx][0..vc.comment_lengths[idx]].recodeToKOI8);
          auto cmts = vc.user_comments[idx][0..vc.comment_lengths[idx]];
               if (cmts.startsWithCI("ALBUM=")) sio.album = cmts[6..$].xstrip.idup;
          else if (cmts.startsWithCI("ARTIST=")) sio.artist = cmts[7..$].xstrip.idup;
          else if (cmts.startsWithCI("TITLE=")) sio.title = cmts[6..$].xstrip.idup;
        }
      }
      //conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
      if (onlymeta) {
        try { ov_clear(&vf); } catch (Exception e) {}
        sio.fl.close();
      } else {
        sio.vf = vf;
      }
      return sio;
    }
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
final class AudioStreamFlac : AudioStream {
private:
  drflac* ff;

protected:
  this () {}

public:
  override void close () {
    if (ff !is null) { drflac_close(ff); ff = null; }
    super.close();
  }

  override int readFrames (void* buf, int count) {
    if (count < 1) return 0;
    if (count > int.max/4) count = int.max/4;
    if (!valid || onlyMeta) return 0;

    if (ff is null) return 0;
    int[512] flcbuf = void;
    int res = 0;
    count *= mChannels;
    short* bp = cast(short*)buf;
    while (count > 0) {
      int xrd = (count <= flcbuf.length ? count : cast(int)flcbuf.length);
      auto rd = drflac_read_s32(ff, xrd, flcbuf.ptr); // samples
      if (rd <= 0) break;
      mSamplesRead += rd; // number of samples read
      foreach (int v; flcbuf[0..cast(int)rd]) *bp++ = cast(short)(v>>16);
      res += rd;
      count -= rd;
    }
    return cast(int)(res/mChannels); // number of frames read
  }

  override ulong seekToTime (uint msecs) {
    if (!valid || onlyMeta) return 0;
    ulong snum = cast(ulong)msecs*mRate/1000*mChannels; // sample number

    if (ff is null) return 0;
    if (ff.totalSampleCount < 1) return 0;
    if (snum >= ff.totalSampleCount) {
      drflac_seek_to_sample(ff, 0);
      return 0;
    }
    if (!drflac_seek_to_sample(ff, snum)) {
      drflac_seek_to_sample(ff, 0);
      return 0;
    }
    mSamplesRead = snum;
    return snum/mChannels;
  }

protected:
  static AudioStreamFlac detect (VFile fl, bool onlymeta) {
    import core.stdc.stdio;
    import core.stdc.stdlib : malloc, free;
    uint commentCount;
    char* fcmts;
    scope(exit) if (fcmts !is null) free(fcmts);
    drflac* ff = drflac_open_file(fl, (void* pUserData, drflac_metadata* pMetadata) {
      if (pMetadata.type == DRFLAC_METADATA_BLOCK_TYPE_VORBIS_COMMENT) {
        if (fcmts !is null) free(fcmts);
        auto csz = drflac_vorbis_comment_size(pMetadata.data.vorbis_comment.commentCount, pMetadata.data.vorbis_comment.comments);
        if (csz > 0 && csz < 0x100_0000) {
          fcmts = cast(char*)malloc(cast(uint)csz);
        } else {
          fcmts = null;
        }
        if (fcmts is null) {
          commentCount = 0;
        } else {
          import core.stdc.string : memcpy;
          commentCount = pMetadata.data.vorbis_comment.commentCount;
          memcpy(fcmts, pMetadata.data.vorbis_comment.comments, cast(uint)csz);
        }
      }
    });
    if (ff !is null) {
      scope(failure) drflac_close(ff);
      if (ff.sampleRate < 1024 || ff.sampleRate > 96000) throw new Exception("fucked flac");
      if (ff.channels < 1 || ff.channels > 2) throw new Exception("fucked flac");
      AudioStreamFlac sio = new AudioStreamFlac();
      scope(failure) delete sio;
      sio.mRate = cast(uint)ff.sampleRate;
      sio.mChannels = cast(ubyte)ff.channels;
      sio.mType = Type.Flac;
      sio.mSamplesTotal = ff.totalSampleCount;
      sio.mOnlyMeta = onlymeta;
      if (!onlymeta) {
        sio.ff = ff;
        sio.mOnlyMeta = false;
        sio.fl = fl;
      }
      //conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (flac)");
      {
        drflac_vorbis_comment_iterator i;
        drflac_init_vorbis_comment_iterator(&i, commentCount, fcmts);
        uint commentLength;
        const(char)* pComment;
        while ((pComment = drflac_next_vorbis_comment(&i, &commentLength)) !is null) {
          if (commentLength > 1024*1024*2) break; // just in case
          //conwriteln("  ", pComment[0..commentLength]);
          auto cmts = pComment[0..commentLength];
          //conwriteln("  <", cmts, ">");
               if (cmts.startsWithCI("ALBUM=")) sio.album = cmts[6..$].xstrip.idup;
          else if (cmts.startsWithCI("ARTIST=")) sio.artist = cmts[7..$].xstrip.idup;
          else if (cmts.startsWithCI("TITLE=")) sio.title = cmts[6..$].xstrip.idup;
        }
      }
      //conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
      return sio;
    }
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
final class AudioStreamMp3 : AudioStream {
private:
  MP3Decoder mp3;
  Mp3Info mp3info; // scanned info, frame index
  uint mp3smpused;

protected:
  this () {}

public:
  override void close () {
    if (mp3 !is null && mp3.valid) { mp3.close(); delete mp3; }
    delete mp3info.index;
    mp3info = Mp3Info.init;
    super.close();
  }

  override int readFrames (void* buf, int count) {
    if (count < 1) return 0;
    if (count > int.max/4) count = int.max/4;
    if (!valid || onlyMeta) return 0;

    // yes, i know that frames are not independent, and i should actually
    // seek to a frame with a correct sync word. meh.
    if (!mp3.valid) return 0;
    auto mfm = mp3.frameSamples;
    if (mp3smpused+mChannels > mfm.length) {
      mp3smpused = 0;
      if (!mp3.decodeNextFrame(&reader)) return 0;
      mfm = mp3.frameSamples;
      if (mp3.sampleRate != mRate || mp3.channels != mChannels) return 0;
    }
    int res = 0;
    ushort* b = cast(ushort*)buf;
    auto oldmpu = mp3smpused;
    while (count > 0 && mp3smpused+mChannels <= mfm.length) {
      *b++ = mfm[mp3smpused++];
      if (mChannels == 2) *b++ = mfm[mp3smpused++];
      --count;
      ++res;
    }
    mSamplesRead += mp3smpused-oldmpu; // number of samples read
    return res;
  }

  override ulong seekToTime (uint msecs) {
    if (!valid || onlyMeta) return 0;
    ulong snum = cast(ulong)msecs*mRate/1000*mChannels; // sample number

    if (!mp3.valid) return 0;
    mp3smpused = 0;
    if (mp3info.index.length == 0 || snum == 0) {
      // alas, we cannot seek here
      mSamplesRead = 0;
      fl.seek(0);
      mp3.restart(&reader);
      return 0;
    }
    // find frame containing our sample
    // stupid binary search; ignore overflow bug
    ulong start = 0;
    ulong end = mp3info.index.length-1;
    while (start <= end) {
      ulong mid = (start+end)/2;
      auto smps = mp3info.index[cast(usize)mid].samples;
      auto smpe = (mp3info.index.length-mid > 0 ? mp3info.index[cast(usize)(mid+1)].samples : mSamplesTotal);
      if (snum >= smps && snum < smpe) {
        // i found her!
        mSamplesRead = snum;
        fl.seek(mp3info.index[cast(usize)mid].fpos);
        mp3smpused = cast(uint)(snum-smps);
        mp3.sync(&reader);
        return snum;
      }
      if (snum < smps) end = mid-1; else start = mid+1;
    }
    // alas, we cannot seek
    mSamplesRead = 0;
    fl.seek(0);
    mp3.restart(&reader);
    return 0;
  }

protected:
  static AudioStreamMp3 detect (VFile fl, bool onlymeta) {
    auto fpos = fl.tell; // usually 0, but...
    AudioStreamMp3 sio = new AudioStreamMp3();
    scope(failure) delete sio;
    sio.fl = fl;
    scope(failure) sio.fl.close();
    sio.mp3 = new MP3Decoder(&sio.reader);
    scope(failure) delete sio.mp3;
    sio.mType = Type.Mp3;
    if (sio.mp3.valid) {
      // scan file to determine number of frames
      auto xfp = fl.tell; // mp3 decoder already buffered some data
      fl.seek(fpos);
      if (onlymeta) {
        sio.mOnlyMeta = true;
        sio.mp3info = mp3Scan!false((void[] buf) => cast(int)fl.rawRead(buf).length);
      } else {
        sio.mp3info = mp3Scan!true((void[] buf) => cast(int)fl.rawRead(buf).length); // build index too
      }
      if (sio.mp3info.valid) {
        if (sio.mp3.sampleRate < 1024 || sio.mp3.sampleRate > 96000) throw new Exception("fucked mp3");
        if (sio.mp3.channels < 1 || sio.mp3.channels > 2) throw new Exception("fucked mp3");
        sio.mRate = sio.mp3.sampleRate;
        sio.mChannels = sio.mp3.channels;
        sio.mSamplesTotal = sio.mp3info.samples;
        //conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (mp3)");
        //conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
        //conwriteln("id3v2: ", sio.mp3info.hasID3v2, "; ofs: ", sio.mp3info.id3v2ofs);
        // get metadata
        if (sio.mp3info.hasID3v2) {
          try {
            ID3v2 idtag;
            fl.seek(fpos+sio.mp3info.id3v2ofs);
            if (idtag.scanParse!false(fl)) {
              sio.album = idtag.album;
              sio.artist = idtag.artist;
              sio.title = idtag.title;
            }
          } catch (Exception e) {}
        }
        fl.seek(xfp);
        return sio;
      }
    }
    // cleanup
    sio.fl.close();
    delete sio.mp3;
    delete sio;
    return null;
  }
}
