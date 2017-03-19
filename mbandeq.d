// code from LADSPA plugins project: http://plugin.org.uk/
// GNU GPLv3
module iv.mbandeq;
private:
nothrow @trusted @nogc:

// ////////////////////////////////////////////////////////////////////////// //
//version = FFTW3;

version = mbandeq_extended;
//version = mbandeq_normal;
//version = mbandeq_winamp;


version(FFTW3) {
  pragma(lib, "fftw3f");
  alias fft_plan = void*;
  alias fftw_real = float;
  extern(C) nothrow @trusted @nogc {
    enum FFTW_MEASURE = 0;
    enum { FFTW_R2HC=0, FFTW_HC2R=1, FFTW_DHT=2 }
    fft_plan fftwf_plan_r2r_1d (int n, fftw_real* inp, fftw_real* outp, size_t kind, uint flags);
    void fftwf_execute (fft_plan plan);
  }
} else {
  //import kissfft;
  alias fft_plan = kiss_fftr_cfg;
  alias fftw_real = kiss_fft_scalar;
}


// ////////////////////////////////////////////////////////////////////////// //
public struct MBandEq {
private:
  enum FFT_LENGTH = 1024;
  enum OVER_SAMP = 4;
  enum STEP_SIZE = FFT_LENGTH/OVER_SAMP;

public:
  version(mbandeq_extended) {
    enum Bands = 30;
  } else version(mbandeq_normal) {
    enum Bands = 15;
  } else {
    enum Bands = 10;
  }
  enum Latency = FFT_LENGTH-STEP_SIZE;

public:
  int[Bands] bands = 0; // [-70..30)
  int* binBase;
  float* binDelta;
  fftw_real* comp;
  float* dbtable;
  uint fifoPos;
  float* inFifo;
  float* outAccum;
  float* outFifo;
  fft_plan planRC;
  fft_plan planCR;
  fftw_real* realx;
  float* window;
  int smpRate;

  this (int asrate) {
    setup(asrate);
  }

  ~this () {
    cleanup();
  }

  void setup (int asrate) {
    import std.math : cos, pow, PI;

    cleanup();
    //scope(failure) cleanup();

    if (asrate < 1024 || asrate > 48000) assert(0, "invalid sampling rate");
    smpRate = asrate;
    float hzPerBin = cast(float)asrate/cast(float)FFT_LENGTH;

    zalloc(inFifo, FFT_LENGTH);
    zalloc(outFifo, FFT_LENGTH);
    zalloc(outAccum, FFT_LENGTH*2);
    zalloc(realx, FFT_LENGTH+16);
    zalloc(comp, FFT_LENGTH+16);
    zalloc(window, FFT_LENGTH);
    zalloc(binBase, FFT_LENGTH/2);
    zalloc(binDelta, FFT_LENGTH/2);
    fifoPos = Latency;
    inFifo[0..FFT_LENGTH] = 0;
    outFifo[0..FFT_LENGTH] = 0;

    version(FFTW3) {
      planRC = fftwf_plan_r2r_1d(FFT_LENGTH, realx, comp, FFTW_R2HC, FFTW_MEASURE);
      planCR = fftwf_plan_r2r_1d(FFT_LENGTH, comp, realx, FFTW_HC2R, FFTW_MEASURE);
    } else {
      planRC = kiss_fftr_alloc(FFT_LENGTH, false); // normal
      planCR = kiss_fftr_alloc(FFT_LENGTH, true); // inverse
    }

    // create raised cosine window table
    foreach (immutable i; 0..FFT_LENGTH) {
      window[i] = -0.5f*cos(2.0f*PI*cast(double)i/cast(double)FFT_LENGTH)+0.5f;
      window[i] *= 2.0f;
    }

    // create db->coeffiecnt lookup table
    zalloc(dbtable, 1000);
    foreach (immutable i; 0..1000) {
      float db = (cast(float)i/10)-70;
      dbtable[i] = pow(10.0f, db/20.0f);
    }

    // create FFT bin -> band+delta tables
    int bin = 0;
    while (bin <= bandfrqs[0]/hzPerBin) {
      binBase[bin] = 0;
      binDelta[bin++] = 0.0f;
    }
    for (int i = 1; i < Bands-1 && bin < (FFT_LENGTH/2)-1 && bandfrqs[i+1] < asrate/2; ++i) {
      float lastBin = bin;
      float nextBin = (bandfrqs[i+1])/hzPerBin;
      while (bin <= nextBin) {
        binBase[bin] = i;
        binDelta[bin] = cast(float)(bin-lastBin)/cast(float)(nextBin-lastBin);
        ++bin;
      }
    }
    //{ import core.stdc.stdio; printf("bin=%d (%d)\n", bin, FFT_LENGTH/2); }
    for (; bin < FFT_LENGTH/2; ++bin) {
      binBase[bin] = Bands-1;
      binDelta[bin] = 0.0f;
    }
  }

  void cleanup () {
    xfree(inFifo);
    xfree(outFifo);
    xfree(outAccum);
    xfree(realx);
    xfree(comp);
    xfree(window);
    xfree(binBase);
    xfree(binDelta);
    xfree(dbtable);
    version(FFTW3) {
      //??? no need to do FFTW cleanup?
    } else {
      kiss_fft_free(planRC);
      kiss_fft_free(planCR);
      //planRC = null;
      //planCR = null;
    }
  }

  // input: input (array of floats of length sample_count)
  // output: output (array of floats of length sample_count)
  void run (fftw_real[] output, const(fftw_real)[] input, uint stride=1, uint ofs=0) {
    import core.stdc.string : memmove;

    if (output.length < input.length) assert(0, "wtf?!");
    if (stride == 0) assert(0, "wtf?!");
    if (ofs >= input.length || input.length < stride) return;

    float[Bands+1] gains = void;
    foreach (immutable idx, int v; bands[]) {
      if (v < -70) v = -70; else if (v > 30) v = 30;
      gains.ptr[idx] = cast(float)v;
    }
    gains[$-1] = 0.0f;

    float[FFT_LENGTH/2] coefs = void;

    // convert gains from dB to co-efficents
    foreach (immutable i; 0..Bands) {
      int gain_idx = cast(int)((gains.ptr[i]*10)+700);
      if (gain_idx < 0) gain_idx = 0; else if (gain_idx > 999) gain_idx = 999;
      gains.ptr[i] = dbtable[gain_idx];
    }

    // calculate coefficients for each bin of FFT
    coefs.ptr[0] = 0.0f;
    for (int bin = 1; bin < FFT_LENGTH/2-1; ++bin) {
      coefs.ptr[bin] = ((1.0f-binDelta[bin])*gains.ptr[binBase[bin]])+(binDelta[bin]*gains.ptr[binBase[bin]+1]);
    }

    //if (fifoPos == 0) fifoPos = Latency;

    foreach (immutable pos; 0..input.length/stride) {
      inFifo[fifoPos] = input.ptr[pos*stride+ofs];
      output.ptr[pos*stride+ofs] = outFifo[fifoPos-Latency];
      ++fifoPos;
      // if the FIFO is full
      if (fifoPos >= FFT_LENGTH) {
        fifoPos = Latency;
        // window input FIFO
        foreach (immutable i; 0..FFT_LENGTH) realx[i] = inFifo[i]*window[i];
        version(FFTW3) {
          // run the real->complex transform
          fftwf_execute(planRC);
          // multiply the bins magnitudes by the coeficients
          comp[0] *= coefs.ptr[0];
          foreach (immutable i; 1..FFT_LENGTH/2) {
            comp[i] *= coefs.ptr[i];
            comp[FFT_LENGTH-i] *= coefs.ptr[i];
          }
          // run the complex->real transform
          fftwf_execute(planCR);
        } else {
          // run the real->complex transform
          realx[FFT_LENGTH..FFT_LENGTH+16] = 0; // just in case
          comp[FFT_LENGTH-16..FFT_LENGTH+16] = 0; // just in case
          kiss_fftr(planRC, realx, cast(kiss_fft_cpx*)comp);
          // multiply the bins magnitudes by the coeficients
          comp[0*2+0] *= coefs.ptr[0];
          kiss_fft_cpx* cc = cast(kiss_fft_cpx*)comp;
          foreach (immutable i; 1..FFT_LENGTH/2) {
            //comp[i*2+0] *= coefs.ptr[i];
            //comp[i*2+1] *= coefs.ptr[i];
            cc[i].r *= coefs.ptr[i];
            cc[i].i *= coefs.ptr[i];
          }
          // run the complex->real transform
          kiss_fftri(planCR, cast(const(kiss_fft_cpx)*)comp, realx);
        }
        // window into the output accumulator
        foreach (immutable i; 0..FFT_LENGTH) outAccum[i] += 0.9186162f*window[i]*realx[i]/(FFT_LENGTH*OVER_SAMP);
        //foreach (immutable i; 0..STEP_SIZE) outFifo[i] = outAccum[i];
        outFifo[0..STEP_SIZE] = outAccum[0..STEP_SIZE];
        // shift output accumulator
        memmove(outAccum, outAccum+STEP_SIZE, FFT_LENGTH*outAccum[0].sizeof);
        // shift input fifo
        //foreach (immutable i; 0..Latency) inFifo[i] = inFifo[i+STEP_SIZE];
        //memmove(inFifo, inFifo+Latency, (FFT_LENGTH-Latency)*float.sizeof);
        memmove(inFifo, inFifo+STEP_SIZE, Latency*inFifo[0].sizeof);
      }
    }
  }

public:
  version(mbandeq_extended) {
    /*
    static immutable float[Bands] bandfrqs = [
      12.5, 25, 37.5, 50, 62.5, 75, 87.5, 100, 125, 150, 175, 200, 250, 300, 350, 400,
      500, 600, 700, 800, 1000, 1200, 1400, 1600, 2000, 2400, 2800, 3200, 4000, 4800,
      5600, 6400, 8000, 9600, 11200, 12800, 16000, 19200, 22400
    ];
    */
    static immutable float[Bands] bandfrqs = [
      50, 75, 125, 150, 200, 250, 300, 350, 400,
      500, 600, 700, 800, 1000, 1200, 1400, 1600, 2000, 2400, 2800, 3200, 4000, 4800,
      5600, 6400, 8000, 9600, 11200, 12800, 16000
    ];
  } else version(mbandeq_normal) {
    static immutable float[Bands] bandfrqs = [
       50.00f,  100.00f,  155.56f,  220.00f,  311.13f, 440.00f, 622.25f,
      880.00f, 1244.51f, 1760.00f, 2489.02f, 3519.95, 4978.04f, 9956.08f,
      19912.16f
    ];
  } else {
    static immutable float[Bands] bandfrqs = [ 60.00f,  170.00f,  310.00f,  600.00f, 1000.00f, 3000.00f, 6000.00f, 12000.00f, 14000.00f, 16000.00f ];
  }

private:
  static void zalloc(T) (ref T* res, uint count) nothrow @trusted @nogc {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memcpy, memset;
    if (count == 0 || count > 1024*1024*8) assert(0, "wtf?!");
    res = cast(T*)malloc(T.sizeof*count);
    if (res is null) assert(0, "out of memory");
    memset(res, 0, T.sizeof*count);
  }

  static void xfree(T) (ref T* ptr) nothrow @trusted @nogc {
    import core.stdc.stdlib : free;
    if (ptr !is null) { free(ptr); ptr = null; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// kissfft
version(FFTW3) {} else {
/*
 * Copyright (c) 2003-2010, Mark Borgerding
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the
 *    distribution.
 *
 *  * Neither the author nor the names of any contributors may be used to
 *    endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
//module kissfft;
private:
nothrow @trusted @nogc:

// ////////////////////////////////////////////////////////////////////////// //
///
public alias kiss_fft_scalar = float;


///
public align(1) struct kiss_fft_cpx {
align(1):
  kiss_fft_scalar r;
  kiss_fft_scalar i;

pure nothrow @safe @nogc:
  // C_MULBYSCALAR
  void opOpAssign(string op:"*") (in kiss_fft_scalar s) {
    pragma(inline, true);
    r *= s;
    i *= s;
  }

  // C_ADDTO, C_SUBFROM
  void opOpAssign(string op) (in kiss_fft_cpx b) if (op == "+" || op == "-") {
    pragma(inline, true);
    mixin("r"~op~"=b.r;");
    mixin("i"~op~"=b.i;");
  }

  // C_MUL
  kiss_fft_cpx opBinary(string op:"*") (in auto ref kiss_fft_cpx b) const {
    pragma(inline, true);
    return kiss_fft_cpx(r*b.r-i*b.i, r*b.i+i*b.r);
  }

  // C_ADD, C_SUB
  kiss_fft_cpx opBinary(string op) (in auto ref kiss_fft_cpx b) const if (op == "+" || op == "-") {
    pragma(inline, true);
    mixin("return kiss_fft_cpx(r"~op~"b.r, i"~op~"b.i);");
  }
}


///
public alias kiss_fft_cfg = kiss_fft_state*;


// ////////////////////////////////////////////////////////////////////////// //
enum MAXFACTORS = 32;
/* e.g. an fft of length 128 has 4 factors
 as far as kissfft is concerned
 4*4*4*2
 */

struct kiss_fft_state {
  int nfft;
  bool inverse;
  int[2*MAXFACTORS] factors;
  kiss_fft_cpx[1] twiddles;
}


// ////////////////////////////////////////////////////////////////////////// //
private void kf_bfly2 (kiss_fft_cpx* Fout, in size_t fstride, const(kiss_fft_cfg) st, int m) {
  kiss_fft_cpx* Fout2;
  const(kiss_fft_cpx)* tw1 = st.twiddles.ptr;
  kiss_fft_cpx t;
  Fout2 = Fout+m;
  do {
    t = (*Fout2)*(*tw1);
    tw1 += fstride;
    (*Fout2) = (*Fout)-t;
    (*Fout) += t;
    ++Fout2;
    ++Fout;
  } while (--m);
}


private void kf_bfly4 (kiss_fft_cpx* Fout, in size_t fstride, const(kiss_fft_cfg) st, in size_t m) {
  const(kiss_fft_cpx)* tw1, tw2, tw3;
  kiss_fft_cpx[6] scratch = void;
  size_t k = m;
  immutable size_t m2 = 2*m;
  immutable size_t m3 = 3*m;
  tw3 = tw2 = tw1 = st.twiddles.ptr;
  do {
    scratch.ptr[0] = Fout[m]*(*tw1);
    scratch.ptr[1] = Fout[m2]*(*tw2);
    scratch.ptr[2] = Fout[m3]*(*tw3);

    scratch.ptr[5] = (*Fout)-scratch.ptr[1];
    (*Fout) += scratch.ptr[1];
    scratch.ptr[3] = scratch.ptr[0]+scratch.ptr[2];
    scratch.ptr[4] = scratch.ptr[0]-scratch.ptr[2];
    Fout[m2] = (*Fout)-scratch.ptr[3];
    tw1 += fstride;
    tw2 += fstride*2;
    tw3 += fstride*3;
    (*Fout) += scratch.ptr[3];

    if (st.inverse) {
      Fout[m].r = scratch.ptr[5].r-scratch.ptr[4].i;
      Fout[m].i = scratch.ptr[5].i+scratch.ptr[4].r;
      Fout[m3].r = scratch.ptr[5].r+scratch.ptr[4].i;
      Fout[m3].i = scratch.ptr[5].i-scratch.ptr[4].r;
    } else {
      Fout[m].r = scratch.ptr[5].r+scratch.ptr[4].i;
      Fout[m].i = scratch.ptr[5].i-scratch.ptr[4].r;
      Fout[m3].r = scratch.ptr[5].r-scratch.ptr[4].i;
      Fout[m3].i = scratch.ptr[5].i+scratch.ptr[4].r;
    }
    ++Fout;
  } while (--k);
}


private void kf_bfly3 (kiss_fft_cpx* Fout, in size_t fstride, const(kiss_fft_cfg) st, size_t m) {
  size_t k = m;
  immutable size_t m2 = 2*m;
  const(kiss_fft_cpx)* tw1, tw2;
  kiss_fft_cpx[5] scratch = void;
  kiss_fft_cpx epi3;
  epi3 = st.twiddles.ptr[fstride*m];
  tw1 = tw2 = st.twiddles.ptr;
  do {
    scratch.ptr[1] = Fout[m]*(*tw1);
    scratch.ptr[2] = Fout[m2]*(*tw2);

    scratch.ptr[3] = scratch.ptr[1]+scratch.ptr[2];
    scratch.ptr[0] = scratch.ptr[1]-scratch.ptr[2];
    tw1 += fstride;
    tw2 += fstride*2;

    Fout[m].r = Fout.r-(scratch.ptr[3].r*cast(kiss_fft_scalar)0.5);
    Fout[m].i = Fout.i-(scratch.ptr[3].i*cast(kiss_fft_scalar)0.5);

    scratch.ptr[0] *= epi3.i;

    (*Fout) += scratch.ptr[3];

    Fout[m2].r = Fout[m].r+scratch.ptr[0].i;
    Fout[m2].i = Fout[m].i-scratch.ptr[0].r;

    Fout[m].r -= scratch.ptr[0].i;
    Fout[m].i += scratch.ptr[0].r;

    ++Fout;
  } while (--k);
}


private void kf_bfly5 (kiss_fft_cpx* Fout, in size_t fstride, const(kiss_fft_cfg) st, int m) {
  kiss_fft_cpx* Fout0, Fout1, Fout2, Fout3, Fout4;
  int u;
  kiss_fft_cpx[13] scratch = void;
  const(kiss_fft_cpx)* twiddles = st.twiddles.ptr;
  const(kiss_fft_cpx)* tw;
  kiss_fft_cpx ya, yb;
  ya = twiddles[fstride*m];
  yb = twiddles[fstride*2*m];

  Fout0 = Fout;
  Fout1 = Fout0+m;
  Fout2 = Fout0+2*m;
  Fout3 = Fout0+3*m;
  Fout4 = Fout0+4*m;

  tw = st.twiddles.ptr;
  for (u = 0; u < m; ++u) {
    scratch.ptr[0] = *Fout0;

    scratch.ptr[1] = (*Fout1)*tw[u*fstride];
    scratch.ptr[2] = (*Fout2)*tw[2*u*fstride];
    scratch.ptr[3] = (*Fout3)*tw[3*u*fstride];
    scratch.ptr[4] = (*Fout4)*tw[4*u*fstride];

    scratch.ptr[7] = scratch.ptr[1]+scratch.ptr[4];
    scratch.ptr[10] = scratch.ptr[1]-scratch.ptr[4];
    scratch.ptr[8] = scratch.ptr[2]+scratch.ptr[3];
    scratch.ptr[9] = scratch.ptr[2]-scratch.ptr[3];

    Fout0.r += scratch.ptr[7].r+scratch.ptr[8].r;
    Fout0.i += scratch.ptr[7].i+scratch.ptr[8].i;

    scratch.ptr[5].r = scratch.ptr[0].r+scratch.ptr[7].r*ya.r+scratch.ptr[8].r*yb.r;
    scratch.ptr[5].i = scratch.ptr[0].i+scratch.ptr[7].i*ya.r+scratch.ptr[8].i*yb.r;

    scratch.ptr[6].r =  scratch.ptr[10].i*ya.i+scratch.ptr[9].i*yb.i;
    scratch.ptr[6].i = -scratch.ptr[10].r*ya.i-scratch.ptr[9].r*yb.i;

    (*Fout1) = scratch.ptr[5]-scratch.ptr[6];
    (*Fout4) = scratch.ptr[5]+scratch.ptr[6];

    scratch.ptr[11].r = scratch.ptr[0].r+scratch.ptr[7].r*yb.r+scratch.ptr[8].r*ya.r;
    scratch.ptr[11].i = scratch.ptr[0].i+scratch.ptr[7].i*yb.r+scratch.ptr[8].i*ya.r;
    scratch.ptr[12].r = -scratch.ptr[10].i*yb.i+scratch.ptr[9].i*ya.i;
    scratch.ptr[12].i =  scratch.ptr[10].r*yb.i-scratch.ptr[9].r*ya.i;

    (*Fout2) = scratch.ptr[11]+scratch.ptr[12];
    (*Fout3) = scratch.ptr[11]-scratch.ptr[12];

    ++Fout0;
    ++Fout1;
    ++Fout2;
    ++Fout3;
    ++Fout4;
  }
}


// perform the butterfly for one stage of a mixed radix FFT
private void kf_bfly_generic (kiss_fft_cpx* Fout, in size_t fstride, const(kiss_fft_cfg) st, int m, int p) {
  import core.stdc.stdlib : alloca;
  int u, k, q1, q;
  const(kiss_fft_cpx)* twiddles = st.twiddles.ptr;
  kiss_fft_cpx t;
  int Norig = st.nfft;

  //kiss_fft_cpx* scratch = cast(kiss_fft_cpx*)KISS_FFT_TMP_ALLOC(kiss_fft_cpx.sizeof*p);
  kiss_fft_cpx* scratch = cast(kiss_fft_cpx*)alloca(kiss_fft_cpx.sizeof*p);

  for (u = 0; u < m; ++u) {
    k = u;
    for (q1 = 0; q1 < p; ++q1) {
      scratch[q1] = Fout[k];
      k += m;
    }

    k = u;
    for (q1 = 0; q1 < p; ++q1) {
      int twidx = 0;
      Fout[k] = scratch[0];
      for (q = 1; q < p; ++q) {
        twidx += fstride*k;
        if (twidx >= Norig) twidx -= Norig;
        t = scratch[q]*twiddles[twidx];
        Fout[k] += t;
      }
      k += m;
    }
  }
  //KISS_FFT_TMP_FREE(scratch);
}


private void kf_work (kiss_fft_cpx* Fout, const(kiss_fft_cpx)* f, in size_t fstride, int in_stride, int* factors, const(kiss_fft_cfg) st) {
  kiss_fft_cpx* Fout_beg = Fout;
  immutable int p = *factors++; // the radix
  immutable int m = *factors++; // stage's fft length/p
  const(kiss_fft_cpx)* Fout_end = Fout+p*m;

  if (m == 1) {
    do {
      *Fout = *f;
      f += fstride*in_stride;
    } while (++Fout != Fout_end);
  } else {
    do {
      // recursive call:
      // DFT of size m*p performed by doing
      // p instances of smaller DFTs of size m,
      // each one takes a decimated version of the input
      kf_work(Fout, f, fstride*p, in_stride, factors, st);
      f += fstride*in_stride;
    } while ((Fout += m) != Fout_end);
  }

  Fout = Fout_beg;

  // recombine the p smaller DFTs
  switch (p) {
    case 2: kf_bfly2(Fout, fstride, st, m); break;
    case 3: kf_bfly3(Fout, fstride, st, m); break;
    case 4: kf_bfly4(Fout, fstride, st, m); break;
    case 5: kf_bfly5(Fout, fstride, st, m); break;
    default: kf_bfly_generic(Fout, fstride, st, m, p); break;
  }
}


/* facbuf is populated by p1, m1, p2, m2, ...
 * where
 *   p[i]*m[i] = m[i-1]
 *   m0 = n
 */
private void kf_factor (int n, int* facbuf) {
  import std.math : floor, sqrt;
  immutable double floor_sqrt = floor(sqrt(cast(double)n));
  int p = 4;
  // factor out powers of 4, powers of 2, then any remaining primes
  do {
    while (n%p) {
      switch (p) {
        case 4: p = 2; break;
        case 2: p = 3; break;
        default: p += 2; break;
      }
      if (p > floor_sqrt) p = n; // no more factors, skip to end
    }
    n /= p;
    *facbuf++ = p;
    *facbuf++ = n;
  } while (n > 1);
}


/** Initialize a FFT (or IFFT) algorithm's cfg/state buffer.
 *
 * typical usage: `kiss_fft_cfg mycfg = kiss_fft_alloc(1024, 0, null, null);`
 *
 * The return value from fft_alloc is a cfg buffer used internally by the fft routine or `null`.
 *
 * If lenmem is `null`, then kiss_fft_alloc will allocate a cfg buffer using malloc.
 * The returned value should be `kiss_fft_free()`d when done to avoid memory leaks.
 *
 * The state can be placed in a user supplied buffer `mem`:
 * If lenmem is not `null` and `mem` is not `null` and `*lenmem` is large enough,
 * then the function places the cfg in `mem` and the size used in `*lenmem`,
 * and returns mem.
 *
 * If lenmem is not `null` and (`mem` is `null` or `*lenmem` is not large enough),
 * then the function returns `null` and places the minimum cfg buffer size in `*lenmem`.
 */
public kiss_fft_cfg kiss_fft_alloc (int nfft, bool inverse_fft, void* mem=null, size_t* lenmem=null) {
  kiss_fft_cfg st = null;
  size_t memneeded = kiss_fft_state.sizeof+kiss_fft_cpx.sizeof*(nfft-1); // twiddle factors
  if (lenmem is null) {
    import core.stdc.stdlib : malloc;
    st = cast(kiss_fft_cfg)malloc(memneeded);
  } else {
    if (mem !is null && *lenmem >= memneeded) st = cast(kiss_fft_cfg)mem;
    *lenmem = memneeded;
  }
  if (st !is null) {
    st.nfft = nfft;
    st.inverse = inverse_fft;
    for (int i = 0; i < nfft; ++i) {
      import std.math : cos, sin, PI;
      double phase = -2*PI*i/nfft;
      if (st.inverse) phase *= -1;
      st.twiddles.ptr[i].r = cos(phase);
      st.twiddles.ptr[i].i = sin(phase);

    }
    kf_factor(nfft, st.factors.ptr);
  }
  return st;
}


/** If kiss_fft_alloc allocated a buffer, it is one contiguous
 * buffer and can be simply free()d when no longer needed
 */
public void kiss_fft_free(T) (ref T* p) {
  if (p !is null) {
    import core.stdc.stdlib : free;
    free(p);
    p = null;
  }
}


/** Perform an FFT on a complex input buffer.
 *
 * for a forward FFT,
 * fin should be  f[0] , f[1] , ... ,f[nfft-1]
 * fout will be   F[0] , F[1] , ... ,F[nfft-1]
 * Note that each element is complex and can be accessed like f[k].r and f[k].i
 */
public void kiss_fft (kiss_fft_cfg cfg, const(kiss_fft_cpx)* fin, kiss_fft_cpx* fout) {
  kiss_fft_stride(cfg, fin, fout, 1);
}


/** A more generic version of the above function. It reads its input from every Nth sample. */
public void kiss_fft_stride (kiss_fft_cfg st, const(kiss_fft_cpx)* fin, kiss_fft_cpx* fout, int in_stride) {
  import core.stdc.stdlib : alloca;
  if (fin is fout) {
    import core.stdc.string : memcpy;
    //NOTE: this is not really an in-place FFT algorithm.
    //It just performs an out-of-place FFT into a temp buffer
    //kiss_fft_cpx* tmpbuf = cast(kiss_fft_cpx*)KISS_FFT_TMP_ALLOC(kiss_fft_cpx.sizeof*st.nfft);
    kiss_fft_cpx* tmpbuf = cast(kiss_fft_cpx*)alloca(kiss_fft_cpx.sizeof*st.nfft);
    kf_work(tmpbuf, fin, 1, in_stride, st.factors.ptr, st);
    memcpy(fout, tmpbuf, kiss_fft_cpx.sizeof*st.nfft);
    //KISS_FFT_TMP_FREE(tmpbuf);
  } else {
    kf_work(fout, fin, 1, in_stride, st.factors.ptr, st);
  }
}


/** Returns the smallest integer k, such that k>=n and k has only "fast" factors (2,3,5) */
public int kiss_fft_next_fast_size (int n) {
  for (;;) {
    int m = n;
    while ((m%2) == 0) m /= 2;
    while ((m%3) == 0) m /= 3;
    while ((m%5) == 0) m /= 5;
    if (m <= 1) break; // n is completely factorable by twos, threes, and fives
    ++n;
  }
  return n;
}


/** for real ffts, we need an even size */
public int kiss_fftr_next_fast_size_real (int n) {
  return kiss_fft_next_fast_size((n+1)>>1)<<1;
}


// ////////////////////////////////////////////////////////////////////////// //
// kissfftr
// Real optimized version can save about 45% cpu time vs. complex fft of a real seq.
public alias kiss_fftr_cfg = kiss_fftr_state*;

struct kiss_fftr_state {
  kiss_fft_cfg substate;
  kiss_fft_cpx* tmpbuf;
  kiss_fft_cpx* super_twiddles;
}


/*
 ** nfft must be even
 *
 * If you don't care to allocate space, use mem = lenmem = null
 */
public kiss_fftr_cfg kiss_fftr_alloc (int nfft, bool inverse_fft, void* mem=null, size_t* lenmem=null) {
  kiss_fftr_cfg st = null;
  size_t subsize, memneeded;

  if (nfft&1) assert(0, "real FFT optimization must be even");
  nfft >>= 1;

  kiss_fft_alloc(nfft, inverse_fft, null, &subsize);
  memneeded = kiss_fftr_state.sizeof+subsize+kiss_fft_cpx.sizeof*(nfft*3/2);

  if (lenmem is null) {
    import core.stdc.stdlib : malloc;
    st = cast(kiss_fftr_cfg)malloc(memneeded);
  } else {
    if (*lenmem >= memneeded) st = cast(kiss_fftr_cfg)mem;
    *lenmem = memneeded;
  }
  if (st is null) return null;

  st.substate = cast(kiss_fft_cfg)(st+1); // just beyond kiss_fftr_state struct
  st.tmpbuf = cast(kiss_fft_cpx*)((cast(ubyte*)st.substate)+subsize);
  st.super_twiddles = st.tmpbuf+nfft;
  kiss_fft_alloc(nfft, inverse_fft, st.substate, &subsize);

  foreach (immutable i; 0..nfft/2) {
    import std.math : cos, sin, PI;
    double phase = -PI*(cast(double)(i+1)/nfft+0.5);
    if (inverse_fft) phase *= -1;
    st.super_twiddles[i].r = cos(phase);
    st.super_twiddles[i].i = sin(phase);
  }

  return st;
}


/** input timedata has nfft scalar points
 * output freqdata has nfft/2+1 complex points
 */
public void kiss_fftr (kiss_fftr_cfg st, const(kiss_fft_scalar)* timedata, kiss_fft_cpx* freqdata) {
  // input buffer timedata is stored row-wise
  int k, ncfft;
  kiss_fft_cpx fpnk, fpk, f1k, f2k, tw, tdc;

  if (st.substate.inverse) assert(0, "kiss fft usage error: improper alloc");

  ncfft = st.substate.nfft;

  // perform the parallel fft of two real signals packed in real,imag
  kiss_fft(st.substate, cast(const(kiss_fft_cpx)*)timedata, st.tmpbuf);
  /* The real part of the DC element of the frequency spectrum in st->tmpbuf
   * contains the sum of the even-numbered elements of the input time sequence
   * The imag part is the sum of the odd-numbered elements
   *
   * The sum of tdc.r and tdc.i is the sum of the input time sequence.
   *      yielding DC of input time sequence
   * The difference of tdc.r - tdc.i is the sum of the input (dot product) [1,-1,1,-1...
   *      yielding Nyquist bin of input time sequence
   */

  tdc.r = st.tmpbuf[0].r;
  tdc.i = st.tmpbuf[0].i;
  freqdata[0].r = tdc.r+tdc.i;
  freqdata[ncfft].r = tdc.r-tdc.i;
  freqdata[ncfft].i = freqdata[0].i = 0;

  for (k = 1; k <= ncfft/2; ++k) {
    fpk = st.tmpbuf[k];
    fpnk.r = st.tmpbuf[ncfft-k].r;
    fpnk.i = -st.tmpbuf[ncfft-k].i;

    f1k = fpk+fpnk;
    f2k = fpk-fpnk;
    tw = f2k*st.super_twiddles[k-1];

    freqdata[k].r = (f1k.r+tw.r)*cast(kiss_fft_scalar)0.5;
    freqdata[k].i = (f1k.i+tw.i)*cast(kiss_fft_scalar)0.5;
    freqdata[ncfft-k].r = (f1k.r-tw.r)*cast(kiss_fft_scalar)0.5;
    freqdata[ncfft-k].i = (tw.i-f1k.i)*cast(kiss_fft_scalar)0.5;
  }
}


/** input freqdata has  nfft/2+1 complex points
 * output timedata has nfft scalar points
 */
public void kiss_fftri (kiss_fftr_cfg st, const(kiss_fft_cpx)* freqdata, kiss_fft_scalar* timedata) {
  // input buffer timedata is stored row-wise
  int k, ncfft;

  if (!st.substate.inverse) assert(0, "kiss fft usage error: improper alloc");

  ncfft = st.substate.nfft;

  st.tmpbuf[0].r = freqdata[0].r+freqdata[ncfft].r;
  st.tmpbuf[0].i = freqdata[0].r-freqdata[ncfft].r;

  for (k = 1; k <= ncfft/2; ++k) {
    kiss_fft_cpx fk, fnkc, fek, fok, tmp;
    fk = freqdata[k];
    fnkc.r = freqdata[ncfft-k].r;
    fnkc.i = -freqdata[ncfft-k].i;

    fek = fk+fnkc;
    tmp = fk-fnkc;
    fok = tmp*st.super_twiddles[k-1];
    st.tmpbuf[k] = fek+fok;
    st.tmpbuf[ncfft-k] = fek-fok;
    st.tmpbuf[ncfft-k].i *= -1;
  }
  kiss_fft(st.substate, st.tmpbuf, cast(kiss_fft_cpx*)timedata);
}
} // version, kissfft
