/*
Copyright (c) 2016, Ketmar // Invisible Vector

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
module trestex is aliced; // due to Phobos bug

import iv.cmdcon;
import iv.cmdcontty;
//import iv.mbandeq;
import iv.rawtty;
import iv.simplealsa;
import iv.vfs;

import iv.drflac;
import iv.minimp3;
import iv.mp3scan;
import iv.tremor;
import iv.dopus;


// ////////////////////////////////////////////////////////////////////////// //
string recodeToKOI8 (const(char)[] s) {
  immutable wchar[128] charMapKOI8 = [
    '\u2500','\u2502','\u250C','\u2510','\u2514','\u2518','\u251C','\u2524','\u252C','\u2534','\u253C','\u2580','\u2584','\u2588','\u258C','\u2590',
    '\u2591','\u2592','\u2593','\u2320','\u25A0','\u2219','\u221A','\u2248','\u2264','\u2265','\u00A0','\u2321','\u00B0','\u00B2','\u00B7','\u00F7',
    '\u2550','\u2551','\u2552','\u0451','\u0454','\u2554','\u0456','\u0457','\u2557','\u2558','\u2559','\u255A','\u255B','\u0491','\u255D','\u255E',
    '\u255F','\u2560','\u2561','\u0401','\u0404','\u2563','\u0406','\u0407','\u2566','\u2567','\u2568','\u2569','\u256A','\u0490','\u256C','\u00A9',
    '\u044E','\u0430','\u0431','\u0446','\u0434','\u0435','\u0444','\u0433','\u0445','\u0438','\u0439','\u043A','\u043B','\u043C','\u043D','\u043E',
    '\u043F','\u044F','\u0440','\u0441','\u0442','\u0443','\u0436','\u0432','\u044C','\u044B','\u0437','\u0448','\u044D','\u0449','\u0447','\u044A',
    '\u042E','\u0410','\u0411','\u0426','\u0414','\u0415','\u0424','\u0413','\u0425','\u0418','\u0419','\u041A','\u041B','\u041C','\u041D','\u041E',
    '\u041F','\u042F','\u0420','\u0421','\u0422','\u0423','\u0416','\u0412','\u042C','\u042B','\u0417','\u0428','\u042D','\u0429','\u0427','\u042A',
  ];
  string res;
  foreach (dchar ch; s) {
    if (ch < 128) {
      if (ch < ' ') ch = ' ';
      if (ch == 127) ch = '?';
      res ~= cast(char)ch;
    } else {
      bool found = false;
      foreach (immutable idx, wchar wch; charMapKOI8[]) {
        if (wch == ch) { res ~= cast(char)(idx+128); found = true; break; }
      }
      if (!found) res ~= '?';
    }
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
struct StreamIO {
private:
  VFile fl;
  string type;

public:
  //long timetotal; // in milliseconds
  uint rate = 1; // just in case
  ubyte channels = 1; // just in case
  ulong samplestotal; // multiplied by channels
  ulong samplesread;  // samples read so far, multiplied by channels

  @property ulong framesread () const pure nothrow @safe @nogc { pragma(inline, true); return samplesread/channels; }
  @property ulong framestotal () const pure nothrow @safe @nogc { pragma(inline, true); return samplestotal/channels; }

  @property uint timeread () const pure nothrow @safe @nogc { pragma(inline, true); return cast(uint)(samplesread*1000/rate/channels); }
  @property uint timetotal () const pure nothrow @safe @nogc { pragma(inline, true); return cast(uint)(samplestotal*1000/rate/channels); }

public:
  bool valid () {
    if (type.length == 0) return false;
    switch (type[0]) {
      case 'f': return (ff !is null);
      case 'v': return (vi !is null);
      case 'm': return mp3.valid;
      case 'o': return (of !is null);
      default:
    }
    return false;
  }

  @property string typestr () const pure nothrow @safe @nogc { return type; }

  void close () {
    if (type.length == 0) return;
    switch (type[0]) {
      case 'f': if (ff !is null) { drflac_close(ff); ff = null; } break;
      case 'v': if (vi !is null) { vi = null; ov_clear(&vf); } break;
      case 'm': if (mp3.valid) mp3.close(); break;
      default:
    }
  }

  int readFrames (void* buf, int count) {
    if (count < 1) return 0;
    if (count > int.max/4) count = int.max/4;
    if (!valid) return 0;
    switch (type[0]) {
      case 'f':
        if (ff is null) return 0;
        int[512] flcbuf;
        int res = 0;
        count *= channels;
        short* bp = cast(short*)buf;
        while (count > 0) {
          int xrd = (count <= flcbuf.length ? count : cast(int)flcbuf.length);
          auto rd = drflac_read_s32(ff, xrd, flcbuf.ptr); // samples
          if (rd <= 0) break;
          samplesread += rd; // number of samples read
          foreach (int v; flcbuf[0..cast(int)rd]) *bp++ = cast(short)(v>>16);
          res += rd;
          count -= rd;
        }
        return cast(int)(res/channels); // number of frames read
      case 'v':
        if (vi is null) return 0;
        int currstream = 0;
        auto ret = ov_read(&vf, cast(ubyte*)buf, count*2*channels, &currstream);
        if (ret <= 0) return 0; // error or eof
        samplesread += ret/2; // number of samples read
        return ret/2/channels; // number of frames read
      case 'o':
        auto dptr = cast(short*)buf;
        if (of is null) return 0;
        int total = 0;
        while (count > 0) {
          while (count > 0 && smpbufpos < smpbufused) {
            *dptr++ = smpbuf.ptr[smpbufpos++];
            if (channels == 2) *dptr++ = smpbuf.ptr[smpbufpos++];
            --count;
            ++total;
            samplesread += channels;
          }
          if (count == 0) break;
          auto rd = of.readFrame();
          if (rd.length == 0) break;
          if (rd.length > smpbuf.length) smpbuf.length = rd.length;
          smpbuf[0..rd.length] = rd[];
          smpbufpos = 0;
          smpbufused = cast(uint)rd.length;
        }
        return total;
      case 'm':
        // yes, i know that frames are not independend, and i should actually
        // seek to a frame with a correct sync word. meh.
        if (!mp3.valid) return 0;
        auto mfm = mp3.frameSamples;
        if (mp3smpused+channels > mfm.length) {
          mp3smpused = 0;
          if (!mp3.decodeNextFrame(&reader)) return 0;
          mfm = mp3.frameSamples;
          if (mp3.sampleRate != rate || mp3.channels != channels) return 0;
        }
        int res = 0;
        ushort* b = cast(ushort*)buf;
        auto oldmpu = mp3smpused;
        while (count > 0 && mp3smpused+channels <= mfm.length) {
          *b++ = mfm[mp3smpused++];
          if (channels == 2) *b++ = mfm[mp3smpused++];
          --count;
          ++res;
        }
        samplesread += mp3smpused-oldmpu; // number of samples read
        return res;
      default: break;
    }
    return 0;
  }

  // return new frame index
  ulong seekToTime (uint msecs) {
    if (!valid) return 0;
    ulong snum = cast(ulong)msecs*rate/1000*channels; // sample number
    switch (type[0]) {
      case 'f':
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
        samplesread = snum;
        return snum/channels;
      case 'v':
        if (vi is null) return 0;
        if (ov_pcm_seek(&vf, snum/channels) == 0) {
          samplesread = ov_pcm_tell(&vf)*channels;
          return samplesread/channels;
        }
        ov_pcm_seek(&vf, 0);
        return 0;
      case 'o':
        if (of is null) return 0;
        of.seek(msecs);
        samplesread = of.smpcurtime*channels;
        return samplesread/channels;
      case 'm':
        if (!mp3.valid) return 0;
        mp3smpused = 0;
        if (mp3info.index.length == 0 || snum == 0) {
          // alas, we cannot seek here
          samplesread = 0;
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
          auto smps = mp3info.index[cast(size_t)mid].samples;
          auto smpe = (mp3info.index.length-mid > 0 ? mp3info.index[cast(size_t)(mid+1)].samples : samplestotal);
          if (snum >= smps && snum < smpe) {
            // i found her!
            samplesread = snum;
            fl.seek(mp3info.index[cast(size_t)mid].fpos);
            mp3smpused = cast(uint)(snum-smps);
            mp3.sync(&reader);
            return snum;
          }
          if (snum < smps) end = mid-1; else start = mid+1;
        }
        // alas, we cannot seek
        samplesread = 0;
        fl.seek(0);
        mp3.restart(&reader);
        return 0;
      default: break;
    }
    return 0;
  }

private:
  drflac* ff;
  MP3Decoder mp3;
  Mp3Info mp3info; // scanned info, frame index
  uint mp3smpused;
  OggVorbis_File vf;
  vorbis_info* vi;
  OpusFile of;
  short[] smpbuf;
  uint smpbufpos, smpbufused;

  int reader (void[] buf) {
    try {
      auto rd = fl.rawRead(buf);
      return cast(int)rd.length;
    } catch (Exception e) {}
    return -1;
  }

public:
  static StreamIO open (VFile fl) {
    import std.string : fromStringz;
    StreamIO sio;
    fl.seek(0);
    // determine format
    try {
      auto fpos = fl.tell;
      // flac
      try {
        import core.stdc.stdio;
        import core.stdc.stdlib : malloc, free;
        uint commentCount;
        char* fcmts;
        scope(exit) if (fcmts !is null) free(fcmts);
        sio.ff = drflac_open_file(fl, (void* pUserData, drflac_metadata* pMetadata) {
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
        if (sio.ff !is null) {
          scope(failure) drflac_close(sio.ff);
          if (sio.ff.sampleRate < 1024 || sio.ff.sampleRate > 96000) throw new Exception("fucked flac");
          if (sio.ff.channels < 1 || sio.ff.channels > 2) throw new Exception("fucked flac");
          sio.rate = cast(uint)sio.ff.sampleRate;
          sio.channels = cast(ubyte)sio.ff.channels;
          sio.type = "flac";
          sio.fl = fl;
          sio.samplestotal = sio.ff.totalSampleCount;
          conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (flac)");
          {
            drflac_vorbis_comment_iterator i;
            drflac_init_vorbis_comment_iterator(&i, commentCount, fcmts);
            uint commentLength;
            const(char)* pComment;
            while ((pComment = drflac_next_vorbis_comment(&i, &commentLength)) !is null) {
              if (commentLength > 1024*1024*2) break; // just in case
              conwriteln("  ", pComment[0..commentLength].recodeToKOI8);
            }
          }
          conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
          return sio;
        }
      } catch (Exception) {}
      fl.seek(fpos);
      // vorbis
      try {
        if (ov_fopen(fl, &sio.vf) == 0) {
          scope(failure) ov_clear(&sio.vf);
          sio.type = "vorbis";
          sio.fl = fl;
          sio.vi = ov_info(&sio.vf, -1);
          if (sio.vi.rate < 1024 || sio.vi.rate > 96000) throw new Exception("fucked vorbis");
          if (sio.vi.channels < 1 || sio.vi.channels > 2) throw new Exception("fucked vorbis");
          sio.rate = sio.vi.rate;
          sio.channels = cast(ubyte)sio.vi.channels;
          conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (vorbis)");
          conwriteln("streams: ", ov_streams(&sio.vf));
          conwriteln("bitrate: ", ov_bitrate(&sio.vf));
          sio.samplestotal = ov_pcm_total(&sio.vf)*sio.channels;
          if (auto vc = ov_comment(&sio.vf, -1)) {
            conwriteln("Encoded by: ", vc.vendor.fromStringz.recodeToKOI8);
            foreach (immutable idx; 0..vc.comments) {
              conwriteln("  ", vc.user_comments[idx][0..vc.comment_lengths[idx]].recodeToKOI8);
            }
          }
          conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
          return sio;
        }
      } catch (Exception) {}
      fl.seek(fpos);
      // opus
      try {
        OpusFile of = opusOpen(fl);
        scope(failure) opusClose(of);
        if (of.rate < 1024 || of.rate > 96000) throw new Exception("fucked opus");
        if (of.channels < 1 || of.channels > 2) throw new Exception("fucked opus");
        sio.of = of;
        sio.type = "opus";
        sio.fl = fl;
        sio.rate = of.rate;
        sio.channels = of.channels;
        conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (opus)");
        sio.samplestotal = of.smpduration*sio.channels;
        if (of.vendor.length) conwriteln("Encoded by: ", of.vendor.recodeToKOI8);
        foreach (immutable cidx; 0..of.commentCount) conwriteln("  ", of.comment(cidx).recodeToKOI8);
        //TODO: comments
        conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
        return sio;
      } catch (Exception) {}
      fl.seek(fpos);
      // mp3
      try {
        sio.fl = fl;
        sio.mp3 = new MP3Decoder(&sio.reader);
        sio.type = "mp3";
        if (sio.mp3.valid) {
          // scan file to determine number of frames
          auto xfp = fl.tell;
          fl.seek(fpos);
          sio.mp3info = mp3Scan!true((void[] buf) => cast(int)fl.rawRead(buf).length); // build index too
          fl.seek(xfp);
          if (sio.mp3info.valid) {
            if (sio.mp3.sampleRate < 1024 || sio.mp3.sampleRate > 96000) throw new Exception("fucked mp3");
            if (sio.mp3.channels < 1 || sio.mp3.channels > 2) throw new Exception("fucked mp3");
            sio.rate = sio.mp3.sampleRate;
            sio.channels = sio.mp3.channels;
            sio.samplestotal = sio.mp3info.samples;
            conwriteln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (mp3)");
            conwritefln!"time: %d:%02d"(sio.timetotal/1000/60, sio.timetotal/1000%60);
            return sio;
          }
        }
        sio.mp3 = null;
      } catch (Exception) {}
      sio.mp3 = null;
      fl.seek(fpos);
    } catch (Exception) {}
    return StreamIO.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum BUF_SIZE = 4096;
short[BUF_SIZE] buffer;

string[] playlist;
int plidx = 0;

__gshared bool paused = false;


// ////////////////////////////////////////////////////////////////////////// //
enum BandHeight = 20;
__gshared int eqCurBand = 0, eqCurBandOld = 0;
__gshared bool eqBandEditor = false;
__gshared bool eqBandEditorOld = false;
__gshared int[/*MBandEq.Bands*/EQ_MAX_BANDS] eqOldBands = int.min;


void drawEqBands () {
  static int eqclamp (int v) { pragma(inline, true); return (v < -70 ? -70 : v > 30 ? 30 : v); }

  __gshared char[65536] cobuf = void;
  uint cobufpos = 0;

  void conOReset () nothrow @trusted @nogc { cobufpos = 0; }

  void conOFlush () nothrow @trusted @nogc { if (cobufpos) ttyRawWrite(cobuf[0..cobufpos]); cobufpos = 0; }

  void conOPut (const(char)[] s...) nothrow @trusted @nogc {
    while (s.length) {
      auto left = cast(uint)cobuf.length-cobufpos;
      if (left == 0) {
        conOFlush();
      } else {
        if (s.length < left) left = cast(uint)s.length;
        cobuf[cobufpos..cobufpos+left] = s[0..left];
        s = s[left..$];
        cobufpos += left;
      }
    }
  }

  void conOInt(T) (T n) nothrow @trusted @nogc if (__traits(isIntegral, T) && !is(T == char) && !is(T == wchar) && !is(T == dchar) && !is(T == bool) && !is(T == enum)) {
    import core.stdc.stdio : snprintf;
    char[64] buf = void;
    static if (__traits(isUnsigned, T)) {
      static if (T.sizeof > 4) {
        auto len = snprintf(buf.ptr, buf.length, "%llu", n);
      } else {
        auto len = snprintf(buf.ptr, buf.length, "%u", cast(uint)n);
      }
    } else {
      static if (T.sizeof > 4) {
        auto len = snprintf(buf.ptr, buf.length, "%lld", n);
      } else {
        auto len = snprintf(buf.ptr, buf.length, "%d", cast(int)n);
      }
    }
    if (len > 0) conOPut(buf[0..len]);
  }

  void conOColorFG (uint c) nothrow @trusted @nogc {
    conOPut("\x1b[38;5;");
    conOInt(ttyRgb2Color((c>>16)&0xff, (c>>8)&0xff, c&0xff));
    conOPut("m");
  }

  void conOColorBG (uint c) nothrow @trusted @nogc {
    conOPut("\x1b[48;5;");
    conOInt(ttyRgb2Color((c>>16)&0xff, (c>>8)&0xff, c&0xff));
    conOPut("m");
  }

  void conOAt (int x, int y) nothrow @trusted @nogc {
    conOPut("\x1b[");
    conOInt(y);
    conOPut(";");
    conOInt(x);
    conOPut("H");
  }

  if (eqBandEditor != eqBandEditorOld && !eqBandEditor) {
    // erase editor and exit
    eqBandEditorOld = eqBandEditor;
    eqCurBandOld = eqCurBand;
    eqOldBands[] = int.min;
    conOReset();
    scope(exit) { conOPut("\x1b8"); conOFlush(); } // restore
    conOPut("\x1b7\x1b[0m\x1b[H"); // save, reset color, goto top
    foreach (immutable y; 0..BandHeight+2) conOPut("\x1b[K\r\n");
    return;
  }

  // did something changed?
  if (eqBandEditor == eqBandEditorOld && eqCurBand == eqCurBandOld) {
    bool changed = false;
    foreach (immutable idx, int v; alsaEqBands[]) if (v != eqOldBands[idx]) { changed = true; break; }
    if (!changed) return;
    if (!eqBandEditor) return;
  }

  bool drawFull = false;

  if (eqBandEditor != eqBandEditorOld) drawFull = true;

  eqBandEditorOld = eqBandEditor;

  conOReset();
  scope(exit) { conOPut("\x1b8"); conOFlush(); } // restore

  conOPut("\x1b7\x1b[0m\x1b[H"); // save, reset color, goto top

  conOColorBG(0x00_00_c0);
  conOColorFG(0x80_80_80);

  if (drawFull) {
    foreach (immutable y; 0..BandHeight) {
      conOPut("   ");
      foreach (immutable x; 0../*MBandEq.Bands*/EQ_MAX_BANDS) {
        if (x == eqCurBand) conOColorFG(0xff_ff_00);
        conOPut("|   ");
        if (x == eqCurBand) conOColorFG(0x80_80_80);
      }
      conOPut("\x1b[K\r\n");
    }
    conOPut("\x1b[K\r\n");
    conOPut("\x1b[K\r\n");

    foreach (immutable x; 0../*MBandEq.Bands*/EQ_MAX_BANDS) {
      if (x%2 != 0) continue;
      conOPut("\x1b[");
      conOInt(BandHeight+1);
      conOPut(";");
      conOInt(3+x*4);
      conOPut("H");
      //!!!conOInt(cast(int)MBandEq.bandfrqs[x]);
    }

    foreach (immutable x; 0../*MBandEq.Bands*/EQ_MAX_BANDS) {
      if (x%2 == 0) continue;
      conOPut("\x1b[");
      conOInt(BandHeight+2);
      conOPut(";");
      conOInt(3+x*4);
      conOPut("H");
      //!!!conOInt(cast(int)MBandEq.bandfrqs[x]);
    }

    foreach (immutable x; 0../*MBandEq.Bands*/EQ_MAX_BANDS) {
      if (x == eqCurBand) conOColorFG(0xff_ff_00);
      int bv = alsaEqBands[x];
      if (bv < -70) bv = -70; else if (bv > 30) bv = 30;
      bv += 70;
      int y = BandHeight-BandHeight*bv/100;
      conOPut("\x1b[");
      conOInt(y);
      conOPut(";");
      conOInt(3+x*4);
      conOPut("H");
      conOPut("===");
      if (y != BandHeight-BandHeight*(0+70)/100) {
        conOPut("\x1b[");
        conOInt(BandHeight-BandHeight*(0+70)/100);
        conOPut(";");
        conOInt(3+x*4);
        conOPut("H");
        conOPut("---");
      }
      if (x == eqCurBand) conOColorFG(0x80_80_80);
    }
  } else {
    // remove highlight from old band
    if (eqCurBandOld >= 0 && eqCurBand != eqCurBandOld) {
      //conOColorFG(0x80_80_80);
      foreach (immutable y; 0..BandHeight) {
        conOAt(3+eqCurBandOld*4, y+1);
        conOPut(" | ");
      }
      conOAt(3+eqCurBandOld*4, BandHeight-BandHeight*(0+70)/100);
      conOPut("---");
      conOAt(3+eqCurBandOld*4, BandHeight-BandHeight*(eqclamp(alsaEqBands[eqCurBandOld])+70)/100);
      conOPut("===");
    }
    // repaint new band
    conOColorFG(0xff_ff_00);
    foreach (immutable y; 0..BandHeight) {
      conOAt(3+eqCurBand*4, y+1);
      conOPut(" | ");
    }
    conOAt(3+eqCurBand*4, BandHeight-BandHeight*(0+70)/100);
    conOPut("---");
    conOAt(3+eqCurBand*4, BandHeight-BandHeight*(eqclamp(alsaEqBands[eqCurBand])+70)/100);
    conOPut("===");
  }

  eqCurBandOld = eqCurBand;
  eqOldBands[] = alsaEqBands[];
}


bool eqProcessKey (TtyEvent key) {
  static int eqclamp (int v) { pragma(inline, true); return (v < -70 ? -70 : v > 30 ? 30 : v); }

  if (!eqBandEditor) return false;
  switch (key.key) {
    case TtyEvent.Key.Left: if (eqCurBand > 0) --eqCurBand; return true;
    case TtyEvent.Key.Right: if (++eqCurBand >= /*MBandEq.Bands*/EQ_MAX_BANDS) eqCurBand = /*MBandEq.Bands*/EQ_MAX_BANDS-1; return true;
    case TtyEvent.Key.Up: alsaEqBands[eqCurBand] = eqclamp(alsaEqBands[eqCurBand]+10); return true;
    case TtyEvent.Key.Down: alsaEqBands[eqCurBand] = eqclamp(alsaEqBands[eqCurBand]-10); return true;
    case TtyEvent.Key.Home: alsaEqBands[eqCurBand] = 30; return true;
    case TtyEvent.Key.End: alsaEqBands[eqCurBand] = -70; return true;
    case TtyEvent.Key.Insert: alsaEqBands[eqCurBand] = 0; return true;
    default:
      if (key == "S" || key == "s") {
        try {
          import iv.vfs.io;
          auto fo = VFile("./mbeqa.rc", "w");
          fo.writeln("eq_reset");
          foreach (immutable idx, int v; alsaEqBands[]) fo.writeln("eq_band ", idx, " ", v);
        } catch (Exception) {}
      } else if (key == "L" || key == "l") {
        concmd("exec mbeqa.rc");
      } else if (key == "R" || key == "r") {
        concmd("eq_reset");
      }
      break;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
enum Action { None, Quit, Prev, Next }
__gshared Action conaction;


Action playFile () {
  if (plidx < 0) plidx = 0;
  if (plidx >= playlist.length) return Action.Quit;
  auto fname = playlist[plidx];

  StreamIO sio = StreamIO.open(VFile(fname));
  if (!sio.valid) return Action.Next;
  scope(exit) sio.close();

  uint realRate = alsaGetBestSampleRate(sio.rate);
  conwriteln("real sampling rate: ", realRate);

  long prevtime = -1;

  if (!alsaIsOpen || alsaRate != sio.rate || alsaChannels != sio.channels) {
    if (!alsaInit(sio.rate, sio.channels)) assert(0, "cannot init ALSA playback");
  }

  bool oldpaused = !paused;
  int oldgain = alsaGain+1;

  void writeTime () {
    import core.stdc.stdio : snprintf;
    char[128] xbuf;
    //auto len = snprintf(xbuf.ptr, xbuf.length, "\r%d:%02d / %d:%02d (%d)%s\x1b[K", 0, 0, sio.timetotal/1000/60, sio.timetotal/1000%60, gain, (paused ? " !".ptr : "".ptr));
    long tm = sio.timeread;
    auto len = snprintf(xbuf.ptr, xbuf.length, "\r%d:%02d / %d:%02d (%d)%s\x1b[K", cast(uint)(tm/1000/60), cast(uint)(tm/1000%60), cast(uint)(sio.timetotal/1000/60), cast(uint)(sio.timetotal/1000%60), alsaGain, (paused ? " !".ptr : "".ptr));
    ttyRawWrite(xbuf[0..len]);
  }
  scope(exit) ttyRawWrite("\r\x1b[0m\x1b[K\n");

  writeTime();

  void processKeys (bool dowait) {
    for (;;) {
      if (!dowait && !ttyIsKeyHit) return;
      dowait = false; // only first iteration should be blocking
      auto key = ttyReadKey(-1, 20);
      if (!ttyconEvent(key) && !eqProcessKey(key)) {
        long oldtm = sio.timeread;
        long tm = oldtm;
        switch (key.key) {
          case TtyEvent.Key.Left:
            tm -= 10*1000;
            if (tm < 0) tm = 0;
            break;
          case TtyEvent.Key.Right:
            tm += 10*1000;
            break;
          case TtyEvent.Key.Down:
            tm -= 60*1000;
            break;
          case TtyEvent.Key.Up:
            tm += 60*1000;
            break;
          case TtyEvent.Key.F1:
            concmd("eq_editor toggle");
            break;
          case TtyEvent.Key.Char:
            if (key.ch == '<') { concmd("prev"); return; }
            if (key.ch == '>') { concmd("next"); return; }
            if (key.ch == 'q') { concmd("quit"); return; }
            if (key.ch == ' ') { concmd("paused toggle"); return; }
            if (key.ch == '0') alsaGain = 0;
            if (key.ch == '-') { alsaGain -= 10; if (alsaGain < -100) alsaGain = -100; }
            if (key.ch == '+') { alsaGain += 10; if (alsaGain > 1000) alsaGain = 1000; }
            break;
          default: break;
        }
        if (tm < 0) tm = 0;
        if (tm >= sio.timetotal) tm = (sio.timetotal ? sio.timetotal-1 : 0);
        if (oldtm != tm) {
          //conwriteln("seek to: ", tm);
          sio.seekToTime(cast(uint)tm);
        }
      }
    }
  }

  mainloop: for (;;) {
    if (!paused) {
      if (!alsaIsOpen) {
        if (!alsaInit(sio.rate, sio.channels)) assert(0, "cannot init ALSA playback");
      }

      auto frmread = sio.readFrames(buffer.ptr, BUF_SIZE/sio.channels);
      if (frmread <= 0) break;

      alsaWriteShort(buffer[0..frmread*sio.channels]);
    } else {
      if (alsaIsOpen) alsaShutdown();
      //import core.thread, core.time;
      //Thread.sleep(100.msecs);
    }

    long tm = sio.timeread;
    if (tm/1000 != prevtime/1000 || paused != oldpaused || alsaGain != oldgain) {
      prevtime = tm;
      oldpaused = paused;
      oldgain = alsaGain;
      writeTime();
    }

    processKeys(paused);
    {
      auto conoldcdump = conDump;
      scope(exit) conDump = conoldcdump;
      conDump = ConDump.none;
      conProcessQueue();
    }
    drawEqBands();
    ttyconDraw();
    if (isQuitRequested) return Action.Quit;
    if (conaction != Action.None) { auto res = conaction; conaction = Action.None; return res; }
  }

  return Action.Next;
}


extern(C) void atExitRestoreTty () {
  ttySetNormal();
}


void main (string[] args) {
  alsaEqBands[] = 0;

  conRegUserVar!bool("shuffle", "shuffle playlist");

  conRegVar!alsaRQuality(0, 10, "rsquality", "resampling quality; 0=worst, 10=best, default is 8");
  conRegVar!alsaDevice("device", "audio output device");
  conRegVar!alsaGain(-100, 1000, "gain", "playback gain (0: normal; -100: silent; 100: 2x)");
  conRegVar!alsaLatencyms(5, 5000, "latency", "playback latency, in milliseconds");
  conRegVar!alsaEnableResampling("use_resampling", "allow audio resampling?");
  conRegVar!alsaEnableEqualizer("use_equalizer", "allow audio equalizer?");

  conRegVar!paused("paused", "is playback paused?");

  conRegVar!eqBandEditor("eq_editor", "is eq band editor active?");

  // lol, `std.trait : ParameterDefaults()` blocks using argument with name `value`
  conRegFunc!((int idx, byte value) {
    if (value < -70) value = -70;
    if (value > 30) value = 30;
    if (idx >= 0 && idx < alsaEqBands.length) {
      if (alsaEqBands[idx] != value) {
        alsaEqBands[idx] = value;
      }
    } else {
      conwriteln("invalid equalizer band index: ", idx);
    }
  })("eq_band", "set equalizer band #n to v (band 0 is preamp)");

  conRegFunc!(() {
    alsaEqBands[] = 0;
  })("eq_reset", "reset equalizer");

  conRegFunc!(() { conaction = Action.Next; })("next", "next song");
  conRegFunc!(() { conaction = Action.Prev; })("prev", "previous song");

  concmd("exec .config.rc tan");
  concmd("exec mbeqa.rc tan");
  conProcessArgs!true(args);

  foreach (string fname; args[1..$]) {
    import std.file;
    if (fname.length == 0) continue;
    try {
      if (fname.exists && fname.isFile) playlist ~= fname;
    } catch (Exception) {}
  }

  if (playlist.length == 0) {
    import core.stdc.stdio : printf;
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    printf("no files!\n");
    exit(EXIT_FAILURE);
  }

  if (ttyIsRedirected) {
    import core.stdc.stdio : printf;
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    printf("no redirects, please!\n");
    exit(EXIT_FAILURE);
  }

  if (conGetVar!bool("shuffle")) {
    import std.random;
    playlist.randomShuffle;
  }

  ttySetRaw();
  {
    import core.stdc.stdlib : atexit;
    atexit(&atExitRestoreTty);
  }
  ttyconInit();

  mainloop: for (;;) {
    final switch (playFile()) with (Action) {
      case Prev: if (plidx > 0) --plidx; break;
      case None:
      case Next: ++plidx; break;
      case Quit: break mainloop;
    }
  }
}
