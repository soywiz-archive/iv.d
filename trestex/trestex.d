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

import iv.alsa;
import iv.audioresampler;
import iv.cmdcon;
import iv.follin.resampler;
import iv.follin.utils;
import iv.rawtty;
import iv.vfs;
import iv.vfs.io;

import iv.drflac;
import iv.minimp3;
import iv.mp3scan;
import iv.tremor;
import iv.dopus;

version(supereq) {
  import mbandeq;
} else {
  import mbeq_1197;
  float[MBEQ.BANDS] eqbands = 0;
}


// ////////////////////////////////////////////////////////////////////////// //
//__gshared string device = "plug:default";
__gshared string device = "default";
__gshared ubyte rsquality = 8;


// ////////////////////////////////////////////////////////////////////////// //
uint getBestSampleRate (uint wantedRate) {
  import std.internal.cstring : tempCString;

  if (wantedRate == 0) wantedRate = 44110;

  snd_pcm_t* pcm;
  snd_pcm_hw_params_t* hwparams;

  auto err = snd_pcm_open(&pcm, device.tempCString, SND_PCM_STREAM_PLAYBACK, SND_PCM_NONBLOCK);
  if (err < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("cannot open device '%s': %s", device, snd_strerror(err));
    exit(EXIT_FAILURE);
  }
  scope(exit) snd_pcm_close(pcm);

  err = snd_pcm_hw_params_malloc(&hwparams);
  if (err < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("cannot malloc hardware parameters: %s", snd_strerror(err));
    exit(EXIT_FAILURE);
  }
  scope(exit) snd_pcm_hw_params_free(hwparams);

  err = snd_pcm_hw_params_any(pcm, hwparams);
  if (err < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("cannot get hardware parameters: %s", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  //printf("Device: %s (type: %s)\n", device_name, snd_pcm_type_name(snd_pcm_type(pcm)));

  if (snd_pcm_hw_params_test_rate(pcm, hwparams, wantedRate, 0) == 0) return wantedRate;

  uint min, max;

  err = snd_pcm_hw_params_get_rate_min(hwparams, &min, null);
  if (err < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("cannot get minimum rate: %s", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  err = snd_pcm_hw_params_get_rate_max(hwparams, &max, null);
  if (err < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("cannot get maximum rate: %s", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  if (wantedRate < min) return min;
  if (wantedRate > max) return max;

  for (int delta = 1; delta < wantedRate; ++delta) {
    if (wantedRate-delta < min && wantedRate+delta > max) break;
    if (wantedRate-delta > min) {
      if (snd_pcm_hw_params_test_rate(pcm, hwparams, wantedRate-delta, 0) == 0) return wantedRate-delta;
    }
    if (wantedRate+delta < max) {
      if (snd_pcm_hw_params_test_rate(pcm, hwparams, wantedRate+delta, 0) == 0) return wantedRate+delta;
    }
  }
  return (wantedRate-min < max-wantedRate ? min : max);
}


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
enum XXBUF_SIZE = 4096;
ubyte[XXBUF_SIZE] xxbuffer;
uint xxbufused;
uint xxoutchans;


void outSoundInit (uint chans) {
  if (chans < 1 || chans > 2) assert(0, "invalid number of channels");
  xxbufused = 0;
  xxoutchans = chans;
}


void outSoundFlush (snd_pcm_t* pcm) {
  while (xxbufused/2/xxoutchans > 0) {
    auto frames = snd_pcm_writei(pcm, xxbuffer.ptr, xxbufused/2/xxoutchans);
    if (frames < 0) {
      frames = snd_pcm_recover(pcm, cast(int)frames, 0);
      if (frames < 0) {
        import core.stdc.stdio : printf;
        printf("snd_pcm_writei failed: %s\n", snd_strerror(cast(int)frames));
      }
    } else {
      import core.stdc.string : memmove;
      auto bwr = cast(uint)(frames*2*xxoutchans);
      if (bwr >= xxbufused) { xxbufused = 0; break; }
      memmove(xxbuffer.ptr, xxbuffer.ptr+bwr, xxbufused-bwr);
      xxbufused -= bwr;
    }
  }
}


void outSound (snd_pcm_t* pcm, const(void)* buf, uint bytes) {
  //conwriteln("xxbufused=", xxbufused, "; left=", xxbuffer.length-xxbufused, "; bytes=", bytes);
  auto src = cast(const(ubyte)*)buf;
  while (bytes > 0) {
    while (bytes > 0 && xxbufused < xxbuffer.length) {
      xxbuffer.ptr[xxbufused++] = *src++;
      --bytes;
    }
    if (xxbufused == xxbuffer.length) outSoundFlush(pcm);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum BUF_SIZE = 4096;
ubyte[BUF_SIZE] buffer;

string[] playlist;
int plidx = 0;

__gshared bool paused = false;
__gshared int gain = 0;
__gshared uint latencyms = 100;
__gshared bool allowresampling = true;

enum ResamplerType { speex, simple }
__gshared ResamplerType rstype = ResamplerType.speex;


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
          writeln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (flac)");
          {
            drflac_vorbis_comment_iterator i;
            drflac_init_vorbis_comment_iterator(&i, commentCount, fcmts);
            uint commentLength;
            const(char)* pComment;
            while ((pComment = drflac_next_vorbis_comment(&i, &commentLength)) !is null) {
              if (commentLength > 1024*1024*2) break; // just in case
              writeln("  ", pComment[0..commentLength].recodeToKOI8);
            }
          }
          writefln("time: %d:%02d", sio.timetotal/1000/60, sio.timetotal/1000%60);
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
          writeln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (vorbis)");
          writeln("streams: ", ov_streams(&sio.vf));
          writeln("bitrate: ", ov_bitrate(&sio.vf));
          sio.samplestotal = ov_pcm_total(&sio.vf)*sio.channels;
          if (auto vc = ov_comment(&sio.vf, -1)) {
            writeln("Encoded by: ", vc.vendor.fromStringz.recodeToKOI8);
            foreach (immutable idx; 0..vc.comments) {
              writeln("  ", vc.user_comments[idx][0..vc.comment_lengths[idx]].recodeToKOI8);
            }
          }
          writefln("time: %d:%02d", sio.timetotal/1000/60, sio.timetotal/1000%60);
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
        writeln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (opus)");
        sio.samplestotal = of.smpduration*sio.channels;
        if (of.vendor.length) writeln("Encoded by: ", of.vendor.recodeToKOI8);
        foreach (immutable cidx; 0..of.commentCount) writeln("  ", of.comment(cidx).recodeToKOI8);
        //TODO: comments
        writefln("time: %d:%02d", sio.timetotal/1000/60, sio.timetotal/1000%60);
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
            writeln("Bitstream is ", sio.channels, " channel, ", sio.rate, "Hz (mp3)");
            writefln("time: %d:%02d", sio.timetotal/1000/60, sio.timetotal/1000%60);
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
enum Action { Quit, Prev, Next }

Action playFile () {
  import std.internal.cstring : tempCString;

  int err;
  snd_pcm_t* pcm;
  snd_pcm_sframes_t frames;

  Resampler rsl, rsr;
  SpeexResampler srb;
  SpeexResampler.Data srbdata;

  if (plidx < 0) plidx = 0;
  if (plidx >= playlist.length) return Action.Quit;
  auto fname = playlist[plidx];

  StreamIO sio = StreamIO.open(VFile(fname));
  if (!sio.valid) return Action.Next;
  scope(exit) sio.close();

  uint realRate = getBestSampleRate(sio.rate);
  conwriteln("real sampling rate: ", realRate);

  outSoundInit(sio.channels);

  static short[] rsbuf;
  static float[] rsfbufi, rsfbufo;
  uint rsbufused;
  uint rsibufused, rsobufused;

  rsbufused = rsibufused = rsobufused = 0;
  if (realRate != sio.rate && allowresampling) {
    if (rstype == ResamplerType.simple) {
      rsl = new Resampler();
      rsl.rate = cast(double)sio.rate/cast(double)realRate;
      rsr = new Resampler();
      rsr.rate = cast(double)sio.rate/cast(double)realRate;
    } else {
      //srb.reset();
      //srb.setRate(sio.rate, realRate);
      srb.setup(sio.channels, sio.rate, realRate, /*SpeexResampler.Quality.Desktop*/rsquality);
      if (rsfbufi.length == 0) rsfbufi.length = 8192;
      if (rsfbufo.length == 0) rsfbufo.length = 8192;
    }
    if (rsbuf.length == 0) rsbuf.length = 8192;
  }

  long prevtime = -1;

  if ((err = snd_pcm_open(&pcm, device.tempCString, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("Playback open error for device '%s': %s", device, snd_strerror(err));
    exit(EXIT_FAILURE);
  }
  scope(exit) snd_pcm_close(pcm);

  if ((err = snd_pcm_set_params(pcm, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, sio.channels, /*sio.rate*/realRate, 1, /*500000*//*20000*/latencyms*1000)) < 0) {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    conwriteln("Playback open error: %s", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  version(none) {
    snd_pcm_uframes_t bufsize, periodsize;
    if (snd_pcm_get_params(pcm, &bufsize, &periodsize) == 0) {
      writeln("desired latency: ", latencyms);
      writeln("buffer size: ", bufsize);
      writeln("period size: ", periodsize);
    }
  }

  version(supereq) {
    mbeqInit(14);
    //mbeqInit(12);
    scope(exit) mbeqQuit();

    bool mbeqActive = false;
    foreach (immutable v; mbeqLSliders[]) if (v != 0) { mbeqActive = true; break; }
    if (!mbeqActive) foreach (immutable v; mbeqRSliders[]) if (v != 0) { mbeqActive = true; break; }

    mbeqSampleRate = sio.rate;
    mbeqSetBandsFromSliders();
  } else {
    auto mbeql = MBEQ(sio.rate);
    auto mbeqr = MBEQ(sio.rate);
    bool mbeqActive = false;
    foreach (immutable v; eqbands[]) if (v != 0) { mbeqActive = true; break; }
  }
  conwriteln("equalizer is ", (mbeqActive ? "" : "not "), "active");

  scope(exit) writeln;
  bool oldpaused = !paused;
  int oldgain = gain+1;
  writef("\r%d:%02d / %d:%02d (%d)%s\x1b[K", 0, 0, sio.timetotal/1000/60, sio.timetotal/1000%60, gain, (paused ? " !" : ""));

  mainloop: for (;;) {
    int frmread = 0;
    bool silence = false;

    if (!paused) {
      frmread = sio.readFrames(buffer.ptr, BUF_SIZE/2/sio.channels);
      if (frmread <= 0) break;

      if (gain) {
        static float[] flbuf;
        if (flbuf.length < frmread*sio.channels) flbuf.length = frmread*sio.channels;
        auto bp = cast(short*)buffer.ptr;
        tflShort2Float(bp[0..frmread*sio.channels], flbuf[0..frmread*sio.channels]);
        immutable float gg = gain/100.0f;
        foreach (ref float v; flbuf[0..frmread*sio.channels]) v += v*gg;
        tflFloat2Short(flbuf[0..frmread*sio.channels], bp[0..frmread*sio.channels]);
      }

      if (mbeqActive) {
        version(supereq) {
          //conwriteln("frmread=", frmread);
          if (frmread > 8191) assert(0, "oops");
          auto eqsr = mbeqModifySamples(buffer.ptr, frmread, sio.channels, 16);
          //conwriteln("frmread=", frmread, "; eqsr=", eqsr);
          if (eqsr > frmread) assert(0, "wtf?!");
          frmread = eqsr;
        } else {
          if (rsfbufi.length < frmread*sio.channels) rsfbufi.length = frmread*sio.channels;
          if (rsfbufo.length < frmread*sio.channels) rsfbufo.length = frmread*sio.channels;
          tflShort2Float((cast(const(short)*)buffer.ptr)[0..frmread*sio.channels], rsfbufi[0..frmread*sio.channels]);
          mbeql.bands[] = eqbands[];
          if (sio.channels == 1) {
            mbeql.run(rsfbufo[0..frmread], rsfbufi[0..frmread]);
          } else {
            mbeqr.bands[] = eqbands[];
            mbeql.run(rsfbufo[0..frmread*sio.channels], rsfbufi[0..frmread*sio.channels], 2, 0);
            mbeqr.run(rsfbufo[0..frmread*sio.channels], rsfbufi[0..frmread*sio.channels], 2, 1);
          }
          tflFloat2Short(rsfbufo[0..frmread*sio.channels], (cast(short*)buffer.ptr)[0..frmread*sio.channels]);
        }
      }
    } else {
      frmread = BUF_SIZE/2/sio.channels;
      buffer[] = 0;
      silence = true;
    }

    // no need to resample silence ;-)
    if (realRate == sio.rate || !allowresampling || silence) {
      outSound(pcm, buffer.ptr, frmread*2*sio.channels);
    } else if (rsl is null) {
      // resampling
      // feed resampler
      rsibufused = cast(uint)frmread*sio.channels;
      if (rsfbufi.length < rsibufused) rsfbufi.length = rsibufused;
      tflShort2Float((cast(short*)buffer.ptr)[0..rsibufused], rsfbufi[0..rsibufused]);
      if (rsfbufi.length*4 > rsfbufo.length) rsfbufo.length = rsfbufi.length*4;
      //if (rsobufused >= rsfbufo.length) rsfbufo.length = rsobufused*2;
      int ibu0count = 0;
      for (;;) {
        if (rsibufused == 0) {
          if (++ibu0count > 2) break;
        }
        srbdata = srbdata.init; // just in case
        srbdata.dataIn = rsfbufi[0..rsibufused];
        srbdata.dataOut = rsfbufo[rsobufused..$];
        if (srb.process(srbdata) != 0) {
          conwriteln("  RESAMPLING ERROR!");
          return Action.Quit;
        }
        rsobufused += srbdata.outputSamplesUsed;
        // shift input buffer
        if (srbdata.inputSamplesUsed > 0) {
          if (srbdata.inputSamplesUsed < rsibufused) {
            import core.stdc.string : memmove;
            memmove(rsfbufi.ptr, rsfbufi.ptr+srbdata.inputSamplesUsed, (rsibufused-srbdata.inputSamplesUsed)*rsfbufi[0].sizeof);
            rsibufused -= srbdata.inputSamplesUsed;
          } else {
            rsibufused = 0;
          }
        }
        if (rsobufused > rsbuf.length) rsbuf.length = rsobufused;
        if (rsobufused > 0) {
          assert(rsobufused%sio.channels == 0);
          if (rsbuf.length < rsobufused) rsbuf.length = rsobufused;
          tflFloat2Short(rsfbufo[0..rsobufused], rsbuf[0..rsobufused]);
          outSound(pcm, rsbuf.ptr, rsobufused*2);
          // shift output buffer
          if (srbdata.outputSamplesUsed > 0) {
            if (srbdata.outputSamplesUsed < rsobufused) {
              import core.stdc.string : memmove;
              memmove(rsfbufo.ptr, rsfbufo.ptr+srbdata.outputSamplesUsed, (rsobufused-srbdata.outputSamplesUsed)*rsfbufi[0].sizeof);
              rsobufused -= srbdata.outputSamplesUsed;
            } else {
              rsobufused = 0;
            }
          }
        } else {
          /*if (srbdata.inputSamplesUsed == 0)*/ break;
        }
      }
    } else {
      short* sb = cast(short*)buffer.ptr;
      while (frmread > 0) {
        // feed resampler
        while (frmread > 0 && rsl.freeCount > 0) {
          rsl.writeSampleFixed(*sb++, 1);
          if (sio.channels == 2) {
            if (rsr.freeCount == 0) assert(0, "wtf?!");
            rsr.writeSampleFixed(*sb++, 1);
          }
          --frmread;
        }
        //conwriteln("left: ", frmread, "; freecount=", rsl.freeCount);
        // get resampled data
        if (rsl.ready) {
          rsbufused = 0;
          while (rsl.sampleCount > 0) {
            auto smp = rsl.sample; // 16-bit sample
            rsl.removeSample();
            if (rsbufused >= rsbuf.length) rsbuf.length *= 2;
            rsbuf.ptr[rsbufused++] = smp;
            if (sio.channels == 2) {
              if (rsr.sampleCount == 0) assert(0, "wtf?!");
              smp = rsr.sample; // 16-bit sample
              rsr.removeSample();
              if (rsbufused >= rsbuf.length) rsbuf.length *= 2;
              rsbuf.ptr[rsbufused++] = smp;
            }
          }
          //conwriteln("  got: ", rsbufused/sio.channels);
          /*
          uint left = rsbufused/sio.channels;
          uint pos = 0;
          while (pos < left) {
            frames = snd_pcm_writei(pcm, rsbuf.ptr+pos*sio.channels, left-pos);
            if (frames < 0) {
              frames = snd_pcm_recover(pcm, cast(int)frames, 0);
              if (frames < 0) {
                import core.stdc.stdio : printf;
                printf("snd_pcm_writei failed: %s\n", snd_strerror(err));
                break mainloop;
              }
            } else {
              pos += frames;
            }
          }
          */
          outSound(pcm, rsbuf.ptr, rsbufused*2);
        }
      }
    }

    long tm = sio.timeread;
    if (tm/1000 != prevtime/1000 || paused != oldpaused || gain != oldgain) {
      prevtime = tm;
      oldpaused = paused;
      oldgain = gain;
      writef("\r%d:%02d / %d:%02d (%d)%s\x1b[K", tm/1000/60, tm/1000%60, sio.timetotal/1000/60, sio.timetotal/1000%60, gain, (paused ? " !" : ""));
    }

    if (ttyIsKeyHit) {
      auto key = ttyReadKey();
      auto oldtm = tm;
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
        case TtyEvent.Key.Char:
          if (key.ch == '<') return Action.Prev;
          if (key.ch == '>') return Action.Next;
          if (key.ch == 'q') return Action.Quit;
          if (key.ch == ' ') paused = !paused;
          if (key.ch == '0') gain = 0;
          if (key.ch == '-') { gain -= 10; if (gain < -100) gain = -100; }
          if (key.ch == '+') { gain += 10; if (gain > 1000) gain = 1000; }
          break;
        default: break;
      }
      if (tm < 0) tm = 0;
      if (tm >= sio.timetotal) tm = (sio.timetotal ? sio.timetotal-1 : 0);
      if (oldtm != tm) sio.seekToTime(cast(uint)tm);
    }
  }
  outSoundFlush(pcm);

  return Action.Next;
}


extern(C) void atExitRestoreTty () {
  ttySetNormal();
}


void main (string[] args) {
  version(supereq) {
    mbeqLSliders[] = mbeqRSliders[] = 0;
  } else {
    eqbands[] = 0;
  }

  conRegUserVar!bool("shuffle", "shuffle playlist");

  conRegVar!rsquality(0, 10, "rsquality", "resampling quality; 0=worst, 10=best, default is 8");
  conRegVar!device("device", "audio output device");
  conRegVar!paused("paused", "is playback paused?");
  conRegVar!gain(-100, 1000, "gain", "playback gain (0: normal; -100: silent; 100: 2x)");
  conRegVar!latencyms(5, 5000, "latency", "playback latency, in milliseconds");
  conRegVar!allowresampling("use_resampling", "allow audio resampling?");
  conRegVar!rstype("resampler_type", "resampler to use (speex or simple)");

  // lol, `std.trait : ParameterDefaults()` blocks using argument with name `value`
  conRegFunc!((int idx, byte value) {
    version(supereq) {
      if (idx >= 0 && idx < mbeqBandCount) {
        mbeqLSliders[idx] = mbeqRSliders[idx] = value;
      } else {
        conwriteln("invalid equalizer band index: ", idx);
      }
    } else {
      if (idx >= 0 && idx < eqbands.length) {
        eqbands[idx] = value;
      } else {
        conwriteln("invalid equalizer band index: ", idx);
      }
    }
  })("eq_band", "set equalizer band #n to v (band 0 is preamp)");

  concmd("exec .config.rc tan");
  version(supereq) {
    concmd("exec mbeqs.rc tan");
  } else {
    concmd("exec mbeqa.rc tan");
  }
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

  fuck_alsa_messages();

  ttySetRaw();
  {
    import core.stdc.stdlib : atexit;
    atexit(&atExitRestoreTty);
  }

  mainloop: for (;;) {
    final switch (playFile()) with (Action) {
      case Prev: if (plidx > 0) --plidx; break;
      case Next: ++plidx; break;
      case Quit: break mainloop;
    }
  }
}
