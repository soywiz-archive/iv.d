/*
 * Copyright (c) 2016, Ketmar // Invisible Vector
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/** simple, yet useful blocking ALSA player. can do resampling and has 39-band equalizer */
module iv.simplealsa;
private:

import iv.alsa;
import iv.follin.resampler;
import iv.follin.utils;
import iv.mbandeq;


// ////////////////////////////////////////////////////////////////////////// //
public __gshared string alsaDevice = "default"; /// output device
public __gshared ubyte alsaRQuality = SpeexResampler.Music; /// resampling quality (if required); [0..10]; default is 8
public __gshared int[MBandEq.Bands] alsaEqBands = 0; /// 39-band equalizer options; [-70..30$(RPAREN)
public __gshared int alsaGain = 0; /// sound gain, in %
public __gshared uint alsaLatencyms = 100; /// output latency, in milliseconds
public __gshared bool alsaEnableResampling = true; /// set to `false` to disable resampling (sound can be distorted)
public __gshared bool alsaEnableEqualizer = true; /// set to `false` to disable resampling (sound can be distorted)


// ////////////////////////////////////////////////////////////////////////// //
public @property bool alsaIsOpen () nothrow @trusted @nogc { return (pcm !is null); } ///
public @property uint alsaRate () nothrow @trusted @nogc { return srate; } ///
public @property uint alsaRealRate () nothrow @trusted @nogc { return realsrate; } ///
public @property ubyte alsaChannels () nothrow @trusted @nogc { return cast(ubyte)xxoutchans; } ///


// ////////////////////////////////////////////////////////////////////////// //
/// find best (native, if output device is "default") supported sampling rate, or 0 on error
public uint alsaGetBestSampleRate (uint wantedRate) {
  import std.internal.cstring : tempCString;

  if (wantedRate == 0) wantedRate = 44110;

  snd_pcm_t* pcm;
  snd_pcm_hw_params_t* hwparams;

  auto err = snd_pcm_open(&pcm, alsaDevice.tempCString, SND_PCM_STREAM_PLAYBACK, SND_PCM_NONBLOCK);
  if (err < 0) return 0;
  scope(exit) snd_pcm_close(pcm);

  err = snd_pcm_hw_params_malloc(&hwparams);
  if (err < 0) return 0;
  scope(exit) snd_pcm_hw_params_free(hwparams);

  err = snd_pcm_hw_params_any(pcm, hwparams);
  if (err < 0) return 0;

  //printf("Device: %s (type: %s)\n", device_name, snd_pcm_type_name(snd_pcm_type(pcm)));

  if (snd_pcm_hw_params_test_rate(pcm, hwparams, wantedRate, 0) == 0) return wantedRate;

  uint min, max;

  err = snd_pcm_hw_params_get_rate_min(hwparams, &min, null);
  if (err < 0) return 0;

  err = snd_pcm_hw_params_get_rate_max(hwparams, &max, null);
  if (err < 0) return 0;

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
__gshared snd_pcm_t* pcm;

__gshared SpeexResampler srb;

__gshared uint srate, realsrate;
__gshared MBandEq mbeql, mbeqr;

enum XXBUF_SIZE = 4096;
__gshared ubyte[XXBUF_SIZE*4] xxbuffer; // just in case
__gshared uint xxbufused;
__gshared uint xxoutchans;


// ////////////////////////////////////////////////////////////////////////// //
void outSoundInit (uint chans) {
  if (chans < 1 || chans > 2) assert(0, "invalid number of channels");
  xxbufused = 0;
  xxoutchans = chans;
}


void outSoundFlushX (const(void)* buf, uint bytes) {
  auto bb = cast(const(short)*)buf;
  auto fleft = bytes/(2*xxoutchans);
  while (fleft > 0) {
    auto frames = snd_pcm_writei(pcm, bb, fleft);
    if (frames < 0) {
      frames = snd_pcm_recover(pcm, cast(int)frames, 0);
      if (frames < 0) {
        //import core.stdc.stdio : printf;
        //printf("snd_pcm_writei failed: %s\n", snd_strerror(cast(int)frames));
      }
    } else {
      bb += cast(uint)frames*xxoutchans;
      fleft -= cast(uint)frames;
    }
  }
}


//TODO: optimize code to avoid multiple float<->short conversions
void outSoundFlush () {
  __gshared float[XXBUF_SIZE] rsfbufi = 0;
  __gshared float[XXBUF_SIZE] rsfbufo = 0;

  if (xxbufused == 0) return;
  assert(xxbufused%(2*xxoutchans) == 0);
  auto smpCount = xxbufused/2;
  xxbufused = 0;
  //{ import core.stdc.stdio; printf("smpCount: %u\n", cast(uint)smpCount); }

  short* b = cast(short*)xxbuffer.ptr;
  // do gain
  if (alsaGain) {
    tflShort2Float(b[0..smpCount], rsfbufi[0..smpCount]);
    immutable float gg = alsaGain/100.0f;
    foreach (ref float v; rsfbufi[0..smpCount]) v += v*gg;
    tflFloat2Short(rsfbufi[0..smpCount], b[0..smpCount]);
  }

  // equalizer
  bool doeq = false;
  foreach (int v; alsaEqBands[]) if (v != 0) { doeq = true; break; }
  if (doeq && alsaEnableEqualizer) {
    tflShort2Float(b[0..smpCount], rsfbufi[0..smpCount]);
    mbeql.bands[] = alsaEqBands[];
    if (xxoutchans == 1) {
      mbeql.run(rsfbufo[0..smpCount], rsfbufi[0..smpCount]);
    } else {
      mbeqr.bands[] = alsaEqBands[];
      mbeql.run(rsfbufo[0..smpCount], rsfbufi[0..smpCount], 2, 0);
      mbeqr.run(rsfbufo[0..smpCount], rsfbufi[0..smpCount], 2, 1);
    }
    tflFloat2Short(rsfbufo[0..smpCount], b[0..smpCount]);
  }

  //{ import core.stdc.stdio; printf("smpCount: %u\n", cast(uint)smpCount); }
  // need resampling?
  if (srate == realsrate || !alsaEnableResampling) {
    // easy deal, no resampling required
    outSoundFlushX(b, smpCount*2);
  } else {
    // oops, must resample
    SpeexResampler.Data srbdata;
    tflShort2Float(b[0..smpCount], rsfbufi[0..smpCount]);
    uint inpos = 0;
    for (;;) {
      srbdata = srbdata.init; // just in case
      srbdata.dataIn = rsfbufi[inpos..smpCount];
      srbdata.dataOut = rsfbufo[];
      if (srb.process(srbdata) != 0) assert(0, "resampling error");
      //{ import core.stdc.stdio; printf("inpos=%u; smpCount=%u; iu=%u; ou=%u\n", cast(uint)inpos, cast(uint)smpCount, cast(uint)srbdata.inputSamplesUsed, cast(uint)srbdata.outputSamplesUsed); }
      if (srbdata.outputSamplesUsed) {
        tflFloat2Short(rsfbufo[0..srbdata.outputSamplesUsed], b[0..srbdata.outputSamplesUsed]);
        outSoundFlushX(b, srbdata.outputSamplesUsed*2);
      } else {
        // no data consumed, no data produced, so we're done
        if (inpos >= smpCount) break;
      }
      inpos += cast(uint)srbdata.inputSamplesUsed;
    }
  }
  //{ import core.stdc.stdio; printf("OK (%u)\n", cast(uint)xxbufused); }
}


void outSoundS (const(void)* buf, uint bytes) {
  //{ import core.stdc.stdio; printf("outSoundS: %u\n", bytes); }
  auto src = cast(const(ubyte)*)buf;
  while (bytes > 0) {
    while (bytes > 0 && xxbufused < XXBUF_SIZE) {
      xxbuffer.ptr[xxbufused++] = *src++;
      --bytes;
    }
    if (xxbufused == XXBUF_SIZE) outSoundFlush();
  }
  //{ import core.stdc.stdio; printf("outSoundS: DONE\n"); }
}


void outSoundF (const(void)* buf, uint bytes) {
  __gshared short[XXBUF_SIZE] cvtbuffer;
  auto len = bytes/float.sizeof;
  assert(len <= cvtbuffer.length);
  tflFloat2Short((cast(const(float)*)buf)[0..len], cvtbuffer[0..len]);
  outSoundS(cvtbuffer.ptr, len*2);
}


// ////////////////////////////////////////////////////////////////////////// //
/// shutdown player
public void alsaShutdown (bool immediate=false) {
  if (pcm !is null) {
    if (immediate) {
      snd_pcm_drop(pcm);
    } else {
      snd_pcm_drain(pcm);
    }
    snd_pcm_close(pcm);
    pcm = null;
  }
  srate = realsrate = 0;
  xxoutchans = 0;
}


// ////////////////////////////////////////////////////////////////////////// //
/// (re)initialize player; return success flag
public bool alsaInit (uint asrate, ubyte chans) {
  import std.internal.cstring : tempCString;

  alsaShutdown(true);
  fuck_alsa_messages();

  if (asrate < 1024 || asrate > 96000) return false;
  if (chans < 1 || chans > 2) return false;

  srate = asrate;
  if (asrate == 44100 || asrate == 48000) {
    realsrate = alsaGetBestSampleRate(asrate);
  } else {
    realsrate = alsaGetBestSampleRate(48000);
  }
  if (realsrate == 0) return false; // alas

  if (realsrate != srate) {
    srb.setup(chans, srate, realsrate, alsaRQuality);
  }

  mbeql.setup(srate);
  mbeqr.setup(srate);

  outSoundInit(chans);

  int err;

  if ((err = snd_pcm_open(&pcm, alsaDevice.tempCString, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
    //import core.stdc.stdlib : exit, EXIT_FAILURE;
    //conwriteln("Playback open error for device '%s': %s", device, snd_strerror(err));
    //exit(EXIT_FAILURE);
    return false;
  }
  //scope(exit) snd_pcm_close(pcm);

  if ((err = snd_pcm_set_params(pcm, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, chans, /*sio.rate*/realsrate, 1, /*500000*//*20000*/alsaLatencyms*1000)) < 0) {
    //import core.stdc.stdlib : exit, EXIT_FAILURE;
    //conwriteln("Playback open error: %s", snd_strerror(err));
    //exit(EXIT_FAILURE);
    snd_pcm_close(pcm);
    pcm = null;
    return false;
  }

  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/// write (interleaved) buffer
public void alsaWriteShort (const(short)[] buf) {
  if (pcm is null || buf.length == 0) return;
  if (buf.length >= 1024*1024) assert(0, "too much");
  outSoundS(buf.ptr, cast(uint)(buf.length*buf[0].sizeof));
}


/// write (interleaved) buffer
public void alsaWriteFloat (const(float)[] buf) {
  if (pcm is null || buf.length == 0) return;
  if (buf.length >= 1024*1024) assert(0, "too much");
  outSoundF(buf.ptr, cast(uint)(buf.length*buf[0].sizeof));
}
