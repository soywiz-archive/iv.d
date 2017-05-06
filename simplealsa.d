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

//version = simplealsa_writefile;
//version = eq_debug;
//version = SIALSA_X86_TRICK;


import iv.alsa;
import iv.follin.resampler;
import iv.follin.utils;
version(simplealsa_writefile) import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public __gshared string alsaDevice = "default"; /// output device
public __gshared ubyte alsaRQuality = SpeexResampler.Music; /// resampling quality (if required); [0..10]; default is 8
public __gshared int[EQ_MAX_BANDS] alsaEqBands = 0; /// [-20..20]
public __gshared int alsaGain = 0; /// sound gain, in %
public __gshared uint alsaLatencyms = 100; /// output latency, in milliseconds
public __gshared bool alsaEnableResampling = true; /// set to `false` to disable resampling (sound can be distorted)
public __gshared bool alsaEnableEqualizer = false; /// set to `false` to disable equalizer


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
version(simplealsa_writefile) VFile fo;
__gshared snd_pcm_t* pcm;

__gshared SpeexResampler srb;

__gshared uint srate, realsrate;

__gshared int lastGain = 0;
__gshared int lastEqSRate = 0;
__gshared int[EQ_MAX_BANDS] lastEqBands = -666;


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
  version(simplealsa_writefile) {
    auto bb = cast(const(ubyte)*)buf;
    fo.rawWriteExact(bb[0..bytes]);
  } else {
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

  bool didFloat = false;
  short* b = cast(short*)xxbuffer.ptr;
  // do gain
  if (alsaGain) {
    didFloat = true;
    tflShort2Float(b[0..smpCount], rsfbufi[0..smpCount]);
    immutable float gg = alsaGain/100.0f;
    foreach (ref float v; rsfbufi[0..smpCount]) v += v*gg;
    //tflFloat2Short(rsfbufi[0..smpCount], b[0..smpCount]);
  }

  // equalizer
  bool doeq = false;
  if (alsaEnableEqualizer) foreach (int v; alsaEqBands[]) if (v != 0) { doeq = true; break; }
  //doeq = alsaEnableEqualizer;

  /*
  if (doeq && alsaEnableEqualizer) {
    if (!didFloat) {
      didFloat = true;
      tflShort2Float(b[0..smpCount], rsfbufi[0..smpCount]);
    }
    mbeql.bands[] = alsaEqBands[];
    if (xxoutchans == 1) {
      mbeql.run(rsfbufo[0..smpCount], rsfbufi[0..smpCount]);
    } else {
      mbeqr.bands[] = alsaEqBands[];
      mbeql.run(rsfbufo[0..smpCount], rsfbufi[0..smpCount], 2, 0);
      mbeqr.run(rsfbufo[0..smpCount], rsfbufi[0..smpCount], 2, 1);
    }
    rsfbufi[0..smpCount] = rsfbufo[0..smpCount];
    //tflFloat2Short(rsfbufo[0..smpCount], b[0..smpCount]);
  }
  */

  void doEqualizing (short* buf, uint samples, uint srate) {
    if (doeq && samples) {
      if (srate != lastEqSRate) {
        initEqIIR(srate);
        lastEqSRate = srate;
        lastEqBands[] = -666;
        //{ import core.stdc.stdio; printf("equalizer reinited, srate: %u; chans: %u\n", srate, cast(uint)xxoutchans); }
      }
      foreach (immutable bidx, int bv; alsaEqBands[]) {
        if (bv < -20) bv = -20; else if (bv > 20) bv = 20;
        if (bv != lastEqBands.ptr[bidx]) {
          lastEqBands.ptr[bidx] = bv;
          double v = 0.03*bv+0.000999999*bv*bv;
          //{ import core.stdc.stdio; printf("  band #%u; value=%d; v=%g\n", cast(uint)bidx, bv, v); }
          set_gain(cast(int)bidx, 0/*chan*/, v);
          set_gain(cast(int)bidx, 1/*chan*/, v);
        }
      }
      iir(buf, cast(int)samples, xxoutchans);
    }
  }

  //{ import core.stdc.stdio; printf("smpCount: %u\n", cast(uint)smpCount); }
  // need resampling?
  if (srate == realsrate || !alsaEnableResampling) {
    // easy deal, no resampling required
    if (didFloat) tflFloat2Short(rsfbufi[0..smpCount], b[0..smpCount]);
    doEqualizing(b, smpCount, srate);
    outSoundFlushX(b, smpCount*2);
  } else {
    // oops, must resample
    SpeexResampler.Data srbdata;
    if (!didFloat) {
      didFloat = true;
      tflShort2Float(b[0..smpCount], rsfbufi[0..smpCount]);
    }
    uint inpos = 0;
    for (;;) {
      srbdata = srbdata.init; // just in case
      srbdata.dataIn = rsfbufi[inpos..smpCount];
      srbdata.dataOut = rsfbufo[];
      if (srb.process(srbdata) != 0) assert(0, "resampling error");
      //{ import core.stdc.stdio; printf("inpos=%u; smpCount=%u; iu=%u; ou=%u\n", cast(uint)inpos, cast(uint)smpCount, cast(uint)srbdata.inputSamplesUsed, cast(uint)srbdata.outputSamplesUsed); }
      if (srbdata.outputSamplesUsed) {
        tflFloat2Short(rsfbufo[0..srbdata.outputSamplesUsed], b[0..srbdata.outputSamplesUsed]);
        doEqualizing(b, srbdata.outputSamplesUsed, realsrate);
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
  outSoundS(cvtbuffer.ptr, cast(uint)(len*2));
}


// ////////////////////////////////////////////////////////////////////////// //
/// shutdown player
public void alsaShutdown (bool immediate=false) {
  if (pcm !is null) {
    if (immediate) {
      snd_pcm_drop(pcm);
    } else {
      if (xxbufused > 0) outSoundFlush();
      snd_pcm_drain(pcm);
    }
    snd_pcm_close(pcm);
    pcm = null;
  }
  srate = realsrate = 0;
  xxoutchans = 0;
  version(simplealsa_writefile) fo.close();
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

  version(simplealsa_writefile) fo = VFile("./zout.raw", "w");

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


// ////////////////////////////////////////////////////////////////////////// //
/*
 *   PCM time-domain equalizer
 *
 *   Copyright (C) 2002-2005  Felipe Rivera <liebremx at users.sourceforge.net>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *   $Id: iir.h,v 1.12 2005/10/17 01:57:59 liebremx Exp $
 */
private:

/*public*/ enum EQ_CHANNELS = 2; // 6
public enum EQ_MAX_BANDS = 10;


/* Coefficients entry */
struct sIIRCoefficients {
  float beta;
  float alpha;
  float gamma;
  //float dummy; // Word alignment
}

__gshared float[EQ_CHANNELS] preamp = 1.0; // Volume gain; values should be between 0.0 and 1.0
__gshared sIIRCoefficients* eqiirCoeffs;
//__gshared int bandCount;
enum bandCount = EQ_MAX_BANDS;


// Init the filters
/*public*/ void initEqIIR (uint srate) nothrow @trusted @nogc {
  //bandCount = EQ_MAX_BANDS;
  auto br = BandRec(srate);
  calc_coeffs(br);
  eqiirCoeffs = br.coeffs;
  clean_history();
}



/***************************
 * IIR filter coefficients *
 ***************************/
__gshared sIIRCoefficients[10] iir_cfx;


/******************************************************************
 * Definitions and data structures to calculate the coefficients
 ******************************************************************/
static immutable double[10] band_f011k = [ 31, 62, 125, 250, 500, 1000, 2000, 3000, 4000, 5500 ];
static immutable double[10] band_f022k = [ 31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 11000 ];
static immutable double[10] band_f010 = [ 31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 ];
static immutable double[10] band_original_f010 = [ 60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000 ];
/*
static immutable double[15] band_f015 = [ 25,40,63,100,160,250,400,630,1000,1600,2500,4000,6300,10000,16000 ];
static immutable double[25] band_f025 = [ 20,31.5,40,50,80,100,125,160,250,315,400,500,800,1000,1250,1600,2500,3150,4000,5000,8000,10000,12500,16000,20000 ];
static immutable double[31] band_f031 = [ 20,25,31.5,40,50,63,80,100,125,160,200,250,315,400,500,630,800,1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,12500,16000,20000 ];
*/

struct BandRec {
  sIIRCoefficients* coeffs;
  immutable(double)* cfs;
  double octave = 1.0;
  //int bandCount;
  enum bandCount = EQ_MAX_BANDS;
  double sfreq;

  this (int samplerate) nothrow @trusted @nogc {
    coeffs = iir_cfx.ptr;
         if (samplerate <= 11025) cfs = band_f011k.ptr;
    else if (samplerate <= 22050) cfs = band_f022k.ptr;
    else if (samplerate <= 48000) cfs = band_original_f010.ptr;
    else cfs = band_f010.ptr;
    sfreq = samplerate;
  }
}

/+
__gshared BandRec[13] bands = [
  BandRec(iir_cf10_11k_11025.ptr,     band_f011k.ptr,         1.0,     10, 11025.0 ),
  BandRec(iir_cf10_22k_22050.ptr,     band_f022k.ptr,         1.0,     10, 22050.0 ),
  BandRec(iir_cforiginal10_44100.ptr, band_original_f010.ptr, 1.0,     10, 44100.0 ),
  BandRec(iir_cforiginal10_48000.ptr, band_original_f010.ptr, 1.0,     10, 48000.0 ),
  BandRec(iir_cf10_96000.ptr,         band_f010.ptr,          1.0,     10, 96000.0 ),
  /*
  BandRec(iir_cf10_44100.ptr,         band_f010.ptr,          1.0,     10, 44100.0 ),
  BandRec(iir_cf10_48000.ptr,         band_f010.ptr,          1.0,     10, 48000.0 ),
  BandRec(iir_cf15_44100.ptr,         band_f015.ptr,          2.0/3.0, 15, 44100.0 ),
  BandRec(iir_cf15_48000.ptr,         band_f015.ptr,          2.0/3.0, 15, 48000.0 ),
  BandRec(iir_cf25_44100.ptr,         band_f025.ptr,          1.0/3.0, 25, 44100.0 ),
  BandRec(iir_cf25_48000.ptr,         band_f025.ptr,          1.0/3.0, 25, 48000.0 ),
  BandRec(iir_cf31_44100.ptr,         band_f031.ptr,          1.0/3.0, 31, 44100.0 ),
  BandRec(iir_cf31_48000.ptr,         band_f031.ptr,          1.0/3.0, 31, 48000.0 ),
  */
];

shared static this () { calc_coeffs(); }
+/


import std.math : PI, SQRT2;

enum GAIN_F0 = 1.0;
enum GAIN_F1 = GAIN_F0/SQRT2;

double TETA (double sfreq, double f) nothrow @trusted @nogc { return 2*PI*cast(double)f/ /*bands[n].*/sfreq; }
double TWOPOWER (double value) nothrow @trusted @nogc { return value*value; }

auto BETA2 (double tf0, double tf) nothrow @trusted @nogc {
  import std.math : cos, sin;
  return
    (TWOPOWER(GAIN_F1)*TWOPOWER(cos(tf0))
     - 2.0 * TWOPOWER(GAIN_F1) * cos(tf) * cos(tf0)
     + TWOPOWER(GAIN_F1)
     - TWOPOWER(GAIN_F0) * TWOPOWER(sin(tf)));
}

auto BETA1 (double tf0, double tf) nothrow @trusted @nogc {
  import std.math : cos, sin;
  return
    (2.0 * TWOPOWER(GAIN_F1) * TWOPOWER(cos(tf))
     + TWOPOWER(GAIN_F1) * TWOPOWER(cos(tf0))
     - 2.0 * TWOPOWER(GAIN_F1) * cos(tf) * cos(tf0)
     - TWOPOWER(GAIN_F1) + TWOPOWER(GAIN_F0) * TWOPOWER(sin(tf)));
}

auto BETA0 (double tf0, double tf) nothrow @trusted @nogc {
  import std.math : cos, sin;
  return
    (0.25 * TWOPOWER(GAIN_F1) * TWOPOWER(cos(tf0))
     - 0.5 * TWOPOWER(GAIN_F1) * cos(tf) * cos(tf0)
     + 0.25 * TWOPOWER(GAIN_F1)
     - 0.25 * TWOPOWER(GAIN_F0) * TWOPOWER(sin(tf)));
}


auto GAMMA (double beta, double tf0) nothrow @trusted @nogc { import std.math : cos; return (0.5+beta)*cos(tf0); }
auto ALPHA (double beta) nothrow @trusted @nogc { return (0.5-beta)/2.0; }

/* Get the coeffs for a given number of bands and sampling frequency */
/*
sIIRCoefficients* get_coeffs (uint sfreq) nothrow @trusted @nogc {
  switch (sfreq) {
    case 11025: return iir_cf10_11k_11025.ptr;
    case 22050: return eqiirCoeffs = iir_cf10_22k_22050.ptr;
    case 48000: return eqiirCoeffs = iir_cforiginal10_48000.ptr;
    case 96000: return eqiirCoeffs = iir_cf10_96000.ptr;
    default: break;
  }
  return null;
}
*/


/* Get the freqs at both sides of F0. These will be cut at -3dB */
void find_f1_and_f2 (double f0, double octave_percent, double* f1, double* f2) nothrow @trusted @nogc {
  import std.math : pow;
  double octave_factor = pow(2.0, octave_percent/2.0);
  *f1 = f0/octave_factor;
  *f2 = f0*octave_factor;
}


/* Find the quadratic root
 * Always return the smallest root */
bool find_root (double a, double b, double c, double* x0) nothrow @trusted @nogc {
  import std.math : sqrt;
  immutable double k = c-((b*b)/(4.0*a));
  if (-(k/a) < 0.0) return false;
  immutable double h = -(b/(2.0*a));
  *x0 = h-sqrt(-(k/a));
  immutable double x1 = h+sqrt(-(k/a));
  if (x1 < *x0) *x0 = x1;
  return true;
}


/* Calculate all the coefficients as specified in the bands[] array */
void calc_coeffs (ref BandRec band) nothrow @trusted @nogc {
  immutable(double)* freqs = band.cfs;
  for (int i = 0; i < band.bandCount; ++i) {
    double f1 = void, f2 = void;
    double x0 = void;
    /* Find -3dB frequencies for the center freq */
    find_f1_and_f2(freqs[i], band.octave, &f1, &f2);
    /* Find Beta */
    if (find_root(
          BETA2(TETA(band.sfreq, freqs[i]), TETA(band.sfreq, f1)),
          BETA1(TETA(band.sfreq, freqs[i]), TETA(band.sfreq, f1)),
          BETA0(TETA(band.sfreq, freqs[i]), TETA(band.sfreq, f1)),
          &x0))
    {
      /* Got a solution, now calculate the rest of the factors */
      /* Take the smallest root always (find_root returns the smallest one)
       *
       * NOTE: The IIR equation is
       *  y[n] = 2 * (alpha*(x[n]-x[n-2]) + gamma*y[n-1] - beta*y[n-2])
       *  Now the 2 factor has been distributed in the coefficients
       */
      /* Now store the coefficients */
      band.coeffs[i].beta = 2.0*x0;
      band.coeffs[i].alpha = 2.0*ALPHA(x0);
      band.coeffs[i].gamma = 2.0*GAMMA(x0, TETA(band.sfreq, freqs[i]));
      version(eq_debug) {
        import core.stdc.stdio;
        printf("Freq[%d]: %f. Beta: %.10e Alpha: %.10e Gamma %.10e\n", i, freqs[i], band.coeffs[i].beta, band.coeffs[i].alpha, band.coeffs[i].gamma);
      }
    } else {
      /* Shouldn't happen */
      band.coeffs[i].beta = 0.0;
      band.coeffs[i].alpha = 0.0;
      band.coeffs[i].gamma = 0.0;
      import core.stdc.stdio;
      printf("  **** Where are the roots?\n");
    }
  }
}


alias sample_t = double;

/*
 * Normal FPU implementation data structures
 */
/* Coefficient history for the IIR filter */
struct sXYData {
  sample_t[3] x = 0; /* x[n], x[n-1], x[n-2] */
  sample_t[3] y = 0; /* y[n], y[n-1], y[n-2] */
  //sample_t dummy1; // Word alignment
  //sample_t dummy2;
}


//static sXYData data_history[EQ_MAX_BANDS][EQ_CHANNELS];
//static sXYData data_history2[EQ_MAX_BANDS][EQ_CHANNELS];
//float gain[EQ_MAX_BANDS][EQ_CHANNELS];

__gshared sXYData[EQ_CHANNELS][EQ_MAX_BANDS] data_history;
__gshared sXYData[EQ_CHANNELS][EQ_MAX_BANDS] data_history2;
__gshared float[EQ_CHANNELS][EQ_MAX_BANDS] gain;

shared static this () {
  foreach (immutable bn; 0..EQ_MAX_BANDS) {
    foreach (immutable cn; 0..EQ_CHANNELS) {
      gain[bn][cn] = 0;
    }
  }
}

/* random noise */
__gshared sample_t[256] dither;
__gshared int di;

/* Indexes for the history arrays
 * These have to be kept between calls to this function
 * hence they are static */
__gshared int iirI = 2, iirJ = 1, iirK = 0;


/*public*/ void set_gain (int index, int chn, float val) nothrow @trusted @nogc {
  gain[index][chn] = val;
}


void clean_history () nothrow @trusted @nogc {
  //import core.stdc.string : memset;
  // Zero the history arrays
  //memset(data_history.ptr, 0, sXYData.sizeof * EQ_MAX_BANDS * EQ_CHANNELS);
  //memset(data_history2.ptr, 0, sXYData.sizeof * EQ_MAX_BANDS * EQ_CHANNELS);
  foreach (immutable bn; 0..EQ_MAX_BANDS) {
    foreach (immutable cn; 0..EQ_CHANNELS) {
      data_history[bn][cn] = sXYData.init;
      data_history2[bn][cn] = sXYData.init;
      //gain[bn][cn] = 0;
    }
  }
  import std.random : Xorshift32;
  //for (n = 0; n < 256; n++) dither[n] = (uniform!"[)"(0, 4)) - 2;
  auto xe = Xorshift32(666);
  dither[] = 0;
  for (int n = 0; n < 256; ++n) { int t = (xe.front%4)-2; dither.ptr[n] = cast(sample_t)t; xe.popFront(); }
  //{ import core.stdc.stdio; for (int n = 0; n < 256; ++n) printf("%d: %g\n", n, dither.ptr[n]); }
  //dither[] = 0;
  //for (int n = 0; n < 256; ++n) dither.ptr[n] = n%4-2;
  di = 0;
  iirI = 2;
  iirJ = 1;
  iirK = 0;
}


// input: 16-bit samples, interleaved; length in BYTES
/*public*/ void iir (short* data, int smplength, int nch) nothrow @trusted @nogc {
  if (eqiirCoeffs is null) return;

  /**
   * IIR filter equation is
   * y[n] = 2 * (alpha*(x[n]-x[n-2]) + gamma*y[n-1] - beta*y[n-2])
   *
   * NOTE: The 2 factor was introduced in the coefficients to save
   *      a multiplication
   *
   * This algorithm cascades two filters to get nice filtering
   * at the expense of extra CPU cycles
   */
  for (int index = 0; index < smplength; index += nch) {
    // for each channel
    for (int channel = 0; channel < nch; ++channel) {
      sample_t pcm = *data*4.0;

      // preamp gain
      pcm *= preamp[channel];

      // add random noise
      pcm += dither.ptr[di];

      sample_t outs = 0.0;

      // for each band
      for (int band = 0; band < bandCount; ++band) {
        // store Xi(n)
        data_history.ptr[band].ptr[channel].x.ptr[iirI] = pcm;
        // calculate and store Yi(n)
        data_history.ptr[band].ptr[channel].y.ptr[iirI] = (
          //     = alpha * [x(n)-x(n-2)]
          eqiirCoeffs[band].alpha * ( data_history.ptr[band].ptr[channel].x.ptr[iirI]-data_history.ptr[band].ptr[channel].x.ptr[iirK])
          //     + gamma * y(n-1)
          + eqiirCoeffs[band].gamma * data_history.ptr[band].ptr[channel].y.ptr[iirJ]
          //     - beta * y(n-2)
          - eqiirCoeffs[band].beta * data_history.ptr[band].ptr[channel].y.ptr[iirK]
        );
        // the multiplication by 2.0 was 'moved' into the coefficients to save CPU cycles here
        // apply the gain
        outs += data_history.ptr[band].ptr[channel].y.ptr[iirI]*gain.ptr[band].ptr[channel]; // * 2.0;
      } // for each band

      version(all) { //if (cfg.eq_extra_filtering)
        // filter the sample again
        for (int band = 0; band < bandCount; ++band) {
          // store Xi(n)
          data_history2.ptr[band].ptr[channel].x.ptr[iirI] = outs;
          // calculate and store Yi(n)
          data_history2.ptr[band].ptr[channel].y.ptr[iirI] = (
            // y(n) = alpha * [x(n)-x(n-2)]
            eqiirCoeffs[band].alpha * (data_history2.ptr[band].ptr[channel].x.ptr[iirI]-data_history2.ptr[band].ptr[channel].x.ptr[iirK])
            //       + gamma * y(n-1)
            + eqiirCoeffs[band].gamma * data_history2.ptr[band].ptr[channel].y.ptr[iirJ]
            //     - beta * y(n-2)
            - eqiirCoeffs[band].beta * data_history2.ptr[band].ptr[channel].y.ptr[iirK]
          );
          // apply the gain
          outs +=  data_history2.ptr[band].ptr[channel].y.ptr[iirI]*gain.ptr[band].ptr[channel];
        } // for each band
      }

      /* Volume stuff
         Scale down original PCM sample and add it to the filters
         output. This substitutes the multiplication by 0.25
         Go back to use the floating point multiplication before the
         conversion to give more dynamic range
         */
      outs += pcm*0.25;

      // remove random noise
      outs -= dither.ptr[di]*0.25;

      // round and convert to integer
      version(X86) {
        import core.stdc.math : lrint;
        int tempgint = cast(int)lrint(outs);
        //int tempgint = cast(int)outs;
      } else {
        int tempgint = cast(int)outs;
      }

      // limit the output
           if (tempgint < short.min) *data = short.min;
      else if (tempgint > short.max) *data = short.max;
      else *data = cast(short)tempgint;
      ++data;
    } // for each channel

    // wrap around the indexes
    iirI = (iirI+1)%3;
    iirJ = (iirJ+1)%3;
    iirK = (iirK+1)%3;
    // random noise index
    di = (di+1)%256;
  }
}
