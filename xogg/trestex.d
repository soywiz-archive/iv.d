#!/usr/bin/env rdmd
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
import iv.alsa;
import iv.audioresampler;
import iv.cmdcon;
import iv.follin.resampler;
import iv.rawtty;
import iv.vfs;
import iv.vfs.io;

import iv.drflac;
import iv.minimp3;
import iv.xogg.tremor;


// ////////////////////////////////////////////////////////////////////////// //
//__gshared string device = "plug:default";
__gshared string device = "default";


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
  long timetotal; // in milliseconds
  uint rate;
  ubyte channels;

public:
  bool valid () {
    if (type.length == 0) return false;
    switch (type[0]) {
      case 'f': return (ff !is null);
      case 'v': return (vi !is null);
      case 'm': return mp3.valid;
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
        return ret/2/channels; // number of frames read
      case 'm':
        if (!mp3.valid) return 0;
        if (mp3smpused+2 > mp3.frameSamples.length) {
          if (!mp3.decodeNextFrame(&reader)) return 0;
          mp3smpused = 0;
        }
        int res = 0;
        ushort* b = cast(ushort*)buf;
        while (count > 0 && mp3smpused+2 <= mp3.frameSamples.length) {
          *b++ = mp3.frameSamples[mp3smpused++];
          *b++ = mp3.frameSamples[mp3smpused++];
          --count;
          ++res;
        }
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
        return snum/channels;
      case 'v':
        if (vi is null) return 0;
        if (ov_time_seek(&vf, msecs) == 0) return ov_time_tell(&vf)*rate/1000;
        ov_time_seek(&vf, 0);
        return 0;
      case 'm':
        if (!mp3.valid) return 0;
        // alas, we cannot seek here, so do it slow
        mp3smpused = 0;
        ulong smpleft = snum;
        fl.seek(0);
        mp3.reset();
        while (smpleft > 0) {
          if (!mp3.decodeNextFrame(&reader)) {
            fl.seek(0);
            mp3.reset();
            mp3.decodeNextFrame(&reader);
            return 0;
          }
          auto smp = mp3.frameSamples;
          if (smp.length < smpleft) {
            smpleft -= cast(int)smp.length;
          } else if (smp.length == smpleft) {
            mp3smpused = cast(int)smp.length;
            break;
          } else {
            mp3smpused = cast(int)smpleft;
            break;
          }
        }
        return snum/channels;
      default: break;
    }
    return 0;
  }

private:
  drflac* ff;
  MP3Decoder mp3;
  uint mp3smpused;
  OggVorbis_File vf;
  vorbis_info* vi;

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
          sio.timetotal = (sio.ff.totalSampleCount/sio.ff.channels)*1000/sio.ff.sampleRate;
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
          scope(failure) scope(exit) ov_clear(&sio.vf);
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
          sio.timetotal = ov_time_total(&sio.vf);
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
      // mp3
      try {
        sio.fl = fl;
        sio.mp3 = new MP3Decoder(&sio.reader);
        sio.type = "mp3";
        if (sio.mp3.valid) {
          // scan file to determine number of frames
          fl.seek(fpos);
          auto info = mp3Scan((void[] buf) {
            return cast(int)fl.rawRead(buf).length;
          });
          fl.seek(fpos);
          if (info.valid) {
            if (sio.mp3.sampleRate < 1024 || sio.mp3.sampleRate > 96000) throw new Exception("fucked mp3");
            if (sio.mp3.channels < 1 || sio.mp3.channels > 2) throw new Exception("fucked mp3");
            sio.rate = sio.mp3.sampleRate;
            sio.channels = sio.mp3.channels;
            sio.timetotal = info.samples*1000/info.sampleRate;
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

  short[] rsbuf;
  uint rsbufused;
  float[] rsfbufi, rsfbufo;
  uint rsibufused, rsobufused;

  if (realRate != sio.rate && allowresampling) {
    if (rstype == ResamplerType.simple) {
      rsl = new Resampler();
      rsl.rate = cast(double)sio.rate/cast(double)realRate;
      rsr = new Resampler();
      rsr.rate = cast(double)sio.rate/cast(double)realRate;
    } else {
      //srb.reset();
      //srb.setRate(sio.rate, realRate);
      srb.setup(sio.channels, sio.rate, realRate, /*SpeexResampler.Quality.Desktop*/8);
      srb.skipZeros();
      rsfbufi.length = 8192;
      rsfbufo.length = 8192;
    }
    rsbuf.length = 8192;
  }

  long prevtime = -1;
  long doneframes = 0;

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

  scope(exit) writeln;
  bool oldpaused = !paused;
  int oldgain = gain+1;
  writef("\r%d:%02d / %d:%02d (%d)%s\x1b[K", 0, 0, sio.timetotal/1000/60, sio.timetotal/1000%60, gain, (paused ? " !" : ""));

  mainloop: for (;;) {
    int frmread = 0;
    if (!paused) {
      frmread = sio.readFrames(buffer.ptr, BUF_SIZE/2/sio.channels);
      if (frmread > 0) doneframes += frmread;
    } else {
      frmread = BUF_SIZE/2/sio.channels;
      buffer[] = 0;
    }

    if (frmread <= 0) break;

    if (gain) {
      auto bp = cast(short*)buffer.ptr;
      foreach (ref short v; bp[0..frmread*sio.channels]) {
        double d = cast(double)v*gain/100.0;
        d += v;
        if (d < -32767) d = -32767;
        if (d > 32767) d = 32767;
        v = cast(short)d;
      }
    }

    if (realRate == sio.rate || !allowresampling) {
      for (;;) {
        frames = snd_pcm_writei(pcm, buffer.ptr, frmread);
        if (frames < 0) {
          frames = snd_pcm_recover(pcm, cast(int)frames, 0);
          if (frames < 0) {
            import core.stdc.stdio : printf;
            printf("snd_pcm_writei failed: %s\n", snd_strerror(err));
            break mainloop;
          }
        } else {
          import core.stdc.string : memmove;
          if (frames >= frmread) break;
          memmove(buffer.ptr, buffer.ptr+cast(uint)frames*2*sio.channels, (frmread-frames)*2*sio.channels);
          frmread -= frames;
        }
      }
    } else if (rsl is null) {
      // resampling
      // feed resampler
      short* sb = cast(short*)buffer.ptr;
      while (frmread > 0) {
        if (rsibufused >= rsfbufi.length) rsfbufi.length *= 2;
        rsfbufi.ptr[rsibufused++] = (*sb++)/32768.0f;
        if (sio.channels == 2) {
          if (rsibufused >= rsfbufi.length) rsfbufi.length *= 2;
          rsfbufi.ptr[rsibufused++] = (*sb++)/32768.0f;
        }
        --frmread;
      }
      if (rsfbufi.length*2 > rsfbufo.length) rsfbufo.length = rsfbufi.length*2;
      if (rsobufused >= rsfbufo.length) rsfbufo.length *= 2;
      for (;;) {
        srbdata.dataIn = rsfbufi[0..rsibufused];
        srbdata.dataOut = rsfbufo[rsobufused..$];
        if (srb.process(srbdata)) {
          conwriteln("  RESAMPLING ERROR!");
          return Action.Quit;
        }
        rsobufused += srbdata.outputSamplesUsed;
        // shift input buffer
        if (srbdata.inputSamplesUsed > 0) {
          if (srbdata.inputSamplesUsed < rsibufused) {
            import core.stdc.string : memmove;
            memmove(rsfbufi.ptr, rsfbufi.ptr+srbdata.inputSamplesUsed, rsibufused-srbdata.inputSamplesUsed);
            rsibufused -= srbdata.inputSamplesUsed;
          } else {
            rsibufused = 0;
          }
        }
        if (rsobufused > rsbuf.length) rsbuf.length = rsobufused;
        if (rsobufused > 0) {
          assert(rsobufused%sio.channels == 0);
          sb = rsbuf.ptr;
          foreach (float ov; rsfbufo[0..rsobufused]) {
            if (ov < -1.0f) ov = -1.0f; else if (ov > 1.0f) ov = 1.0f;
            int n = cast(int)(ov*32767.0f);
            if (n < short.min) n = short.min; else if (n > short.max) n = short.max;
            *sb++ = cast(short)n;
          }
          uint rsopos = 0;
          while (rsopos < rsobufused/sio.channels) {
            frames = snd_pcm_writei(pcm, rsbuf.ptr+rsopos*sio.channels, (rsobufused-rsopos)/sio.channels);
            if (frames < 0) {
              frames = snd_pcm_recover(pcm, cast(int)frames, 0);
              if (frames < 0) {
                import core.stdc.stdio : printf;
                printf("snd_pcm_writei failed: %s\n", snd_strerror(err));
                break mainloop;
              }
            }
            rsopos += cast(uint)frames;
          }
          // shift output buffer
          if (srbdata.outputSamplesUsed > 0) {
            if (srbdata.outputSamplesUsed < rsobufused) {
              import core.stdc.string : memmove;
              memmove(rsfbufo.ptr, rsfbufo.ptr+srbdata.outputSamplesUsed, rsobufused-srbdata.outputSamplesUsed);
              rsobufused -= srbdata.outputSamplesUsed;
            } else {
              rsobufused = 0;
            }
          }
        } else {
          if (srbdata.inputSamplesUsed == 0) break;
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
          frames = snd_pcm_writei(pcm, rsbuf.ptr, rsbufused/sio.channels);
          if (frames < 0) {
            frames = snd_pcm_recover(pcm, cast(int)frames, 0);
            if (frames < 0) {
              import core.stdc.stdio : printf;
              printf("snd_pcm_writei failed: %s\n", snd_strerror(err));
              break mainloop;
            }
          }
        }
      }
    }

    long tm = doneframes*1000/sio.rate;
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
      if (oldtm != tm) doneframes = sio.seekToTime(cast(uint)tm);
    }
  }

  return Action.Next;
}


extern(C) void atExitRestoreTty () {
  ttySetNormal();
}


void main (string[] args) {
  conRegUserVar!bool("shuffle", "shuffle playlist");

  conRegVar!device("device", "audio output device");
  conRegVar!paused("paused", "is playback paused?");
  conRegVar!gain(-100, 1000, "gain", "playback gain (0: normal; -100: silent; 100: 2x)");
  conRegVar!latencyms(5, 5000, "latency", "playback latency, in milliseconds");
  conRegVar!allowresampling("allow_resampling", "allow audio resampling?");
  conRegVar!rstype("resampler_type", "resampler to use (speex or simple)");

  concmd("exec .config.rc tan");
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

  mainloop: for (;;) {
    final switch (playFile()) with (Action) {
      case Prev: if (plidx > 0) --plidx; break;
      case Next: ++plidx; break;
      case Quit: break mainloop;
    }
  }
}
