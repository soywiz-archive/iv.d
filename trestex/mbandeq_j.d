// Shibatch Super Equalizer ver 0.03 for winamp
// written by Naoki Shibata  shibatch@users.sourceforge.net
// LGPL
module mbandeq_j /*is aliced*/;
private:
import iv.alice;

//import fftsg;

//version = mbeq_debug_output;

version(mbeq_debug_output) import iv.cmdcon;


// ////////////////////////////////////////////////////////////////////////// //
// Real Discrete Fourier Transform wrapper
void rfft (int n, int isign, REAL* x) {
  import std.math : sqrt;
  __gshared int ipsize = 0, wsize=0;
  __gshared int* ip = null;
  __gshared REAL* w = null;
  int newipsize, newwsize;

  if (n == 0) {
    import core.stdc.stdlib : free;
    free(ip); ip = null; ipsize = 0;
    free(w); w = null; wsize  = 0;
    return;
  }

  newipsize = 2+cast(int)sqrt(cast(REAL)(n/2));
  if (newipsize > ipsize) {
    import core.stdc.stdlib : realloc;
    ipsize = newipsize;
    ip = cast(int*)realloc(ip, int.sizeof*ipsize);
    ip[0] = 0;
  }

  newwsize = n/2;
  if (newwsize > wsize) {
    import core.stdc.stdlib : realloc;
    wsize = newwsize;
    w = cast(REAL*)realloc(w, REAL.sizeof*wsize);
  }

  rdft(n, isign, x, ip, w);
}


// ////////////////////////////////////////////////////////////////////////// //
enum M = 15;

//#define RINT(x) ((x) >= 0 ? ((int)((x)+0.5)) : ((int)((x)-0.5)))
int RINT (REAL x) pure nothrow @safe @nogc { pragma(inline, true); return (x >= 0 ? cast(int)(x+0.5f) : cast(int)(x-0.5f)); }

enum DITHERLEN = 65536;

__gshared REAL[M+1] fact;
__gshared REAL aa = 96;
__gshared REAL iza;
__gshared REAL* lires, lires1, lires2;
__gshared REAL* rires, rires1, rires2;
__gshared REAL* irest;
__gshared REAL* fsamples;
__gshared int chg_ires, cur_ires;
__gshared int winlen, winlenbit, tabsize, nbufsamples;
__gshared short* inbuf;
__gshared REAL* outbuf;
enum dither = false;
static if (dither) {
  __gshared REAL* ditherbuf;
  __gshared uint ditherptr = 0;
  __gshared REAL smphm1 = 0, smphm2 = 0;
}

enum NCH = 2;

enum NBANDS = 17;
static immutable REAL[NBANDS] bands = [
  65.406392, 92.498606, 130.81278, 184.99721, 261.62557, 369.99442, 523.25113,
  739.9884 , 1046.5023, 1479.9768, 2093.0045, 2959.9536, 4186.0091, 5919.9072,
  8372.0181, 11839.814, 16744.036,
];


REAL alpha (REAL a) nothrow @trusted @nogc {
  import std.math : pow;
  if (a <= 21) return 0;
  if (a <= 50) return 0.5842*pow(a-21, 0.4)+0.07886*(a-21);
  return 0.1102*(a-8.7);
}


REAL izero (REAL x) nothrow @trusted @nogc {
  import std.math : pow;
  REAL ret = 1;
  foreach (immutable m; 1..M+1) {
    REAL t = pow(x/2, m)/fact[m];
    ret += t*t;
  }
  return ret;
}


/// wb: window length, bits
public void mbeqInit (int wb=14) {
  import core.stdc.stdlib : malloc, calloc, free;

  if (lires1 !is null) free(lires1);
  if (lires2 !is null) free(lires2);
  if (rires1 !is null) free(rires1);
  if (rires2 !is null) free(rires2);
  if (irest !is null) free(irest);
  if (fsamples !is null) free(fsamples);
  if (inbuf !is null) free(inbuf);
  if (outbuf !is null) free(outbuf);
  static if (dither) { if (ditherbuf !is null) free(ditherbuf); }

  winlen = (1<<(wb-1))-1;
  winlenbit = wb;
  tabsize = 1<<wb;

  //{ import core.stdc.stdio; printf("winlen=%u\n", winlen); }

  lires1 = cast(REAL*)malloc(REAL.sizeof*tabsize);
  lires2 = cast(REAL*)malloc(REAL.sizeof*tabsize);
  rires1 = cast(REAL*)malloc(REAL.sizeof*tabsize);
  rires2 = cast(REAL*)malloc(REAL.sizeof*tabsize);
  irest = cast(REAL*)malloc(REAL.sizeof*tabsize);
  fsamples = cast(REAL*)malloc(REAL.sizeof*tabsize);
  inbuf = cast(short*)calloc(winlen*NCH, int.sizeof);
  outbuf = cast(REAL*)calloc(tabsize*NCH, REAL.sizeof);
  static if (dither) { ditherbuf = cast(REAL*)malloc(REAL.sizeof*DITHERLEN); }

  lires = lires1;
  rires = rires1;
  cur_ires = 1;
  chg_ires = 1;

  static if (dither) {
    foreach (immutable i; 0..DITHERLEN) {
      import std.random;
      //ditherbuf[i] = (REAL(rand())/RAND_MAX-0.5);
      ditherbuf[i] = uniform!"[]"(0, 32760)/32760.0f-0.5f;
    }
  }

  foreach (immutable i; 0..M+1) {
    fact[i] = 1;
    foreach (immutable j; 1..i+1) fact[i] *= j;
  }

  iza = izero(alpha(aa));
}


// -(N-1)/2 <= n <= (N-1)/2
REAL win (REAL n, int N) nothrow @trusted @nogc {
  pragma(inline, true);
  import std.math : sqrt;
  return izero(alpha(aa)*sqrt(1-4*n*n/((N-1)*(N-1))))/iza;
}


REAL sinc (REAL x) nothrow @trusted @nogc {
  pragma(inline, true);
  import std.math : sin;
  return (x == 0 ? 1 : sin(x)/x);
}


REAL hn_lpf (int n, REAL f, REAL fs) nothrow @trusted @nogc {
  pragma(inline, true);
  import std.math : PI;
  immutable REAL t = 1/fs;
  immutable REAL omega = 2*PI*f;
  return 2*f*t*sinc(n*omega*t);
}


REAL hn_imp (int n) nothrow @trusted @nogc {
  pragma(inline, true);
  return (n == 0 ? 1.0 : 0.0);
}


REAL getLower (int i) nothrow @trusted @nogc {
  pragma(inline, true);
  if (i < 0) assert(0, "wtf?");
  if (i > NBANDS+1) assert(0, "wtf?");
  return (i == 0 ? 0 : bands[i-1]);
}


REAL getUpper (int i) nothrow @trusted @nogc {
  pragma(inline, true);
  if (i < 0) assert(0, "wtf?");
  if (i > NBANDS+1) assert(0, "wtf?");
  return (i == NBANDS ? 48000/2 : bands[i]);
}


REAL hn (int n, const(REAL)[] gains, REAL fs) nothrow @trusted @nogc {
  REAL lhn = hn_lpf(n, bands[0], fs);
  REAL ret = gains[0]*lhn;
  foreach (immutable i, REAL gv; gains) {
    if (i == 0) continue;
    assert(i <= NBANDS);
    //immutable REAL lower = getLower(i);
    immutable REAL upper = getUpper(i);
    if (upper >= fs/2) {
      // the last one
      ret += gv*(hn_imp(n)-lhn);
      return ret;
    }
    REAL lhn2 = hn_lpf(n, upper, fs);
    ret += gv*(lhn2-lhn);
    lhn = lhn2;
  }
  assert(0, "wtf?!");
}


void processParam (REAL[] gains, const(REAL)[] bc, const(REAL)[] gainmods=null) {
  import std.math : pow;
  foreach (immutable i; 0..NBANDS+1) {
    gains[i] = bc[i];
    immutable REAL gm = (i < gainmods.length ? gainmods[i] : 1);
    gains[i] *= pow(10, gm/20);
    //if (i < gainmods.length) gains[i] *= pow(10, gainmods[i]/20);
  }
}


///
public void mbeqMakeTable (const(REAL)[] lbc, const(REAL)[] rbc, REAL fs, const(REAL)[] gainmods=null) {
  int i, cires = cur_ires;
  REAL* nires;
  REAL[NBANDS+1] gains;

  if (fs <= 0) return;

  // left
  processParam(gains[], lbc, gainmods);
  version(mbeq_debug_output) foreach (immutable gi, immutable REAL gv; gains[]) conwriteln("L: ", getLower(gi, fs), "Hz to ", getUpper(gi, fs), "Hz, ", gv);
  for (i = 0; i < winlen; ++i) irest[i] = hn(i-winlen/2, gains[], fs)*win(i-winlen/2, winlen);
  for (; i < tabsize; ++i) irest[i] = 0;
  rfft(tabsize, 1, irest);
  nires = (cires == 1 ? lires2 : lires1);
  for (i = 0; i < tabsize; ++i) nires[i] = irest[i];

  // right
  processParam(gains[], rbc, gainmods);
  version(mbeq_debug_output) foreach (immutable gi, immutable REAL gv; gains[]) conwriteln("R: ", getLower(gi, fs), "Hz to ", getUpper(gi, fs), "Hz, ", gv);
  for (i = 0; i < winlen; ++i) irest[i] = hn(i-winlen/2, gains[], fs)*win(i-winlen/2, winlen);
  for (; i < tabsize; ++i) irest[i] = 0;
  rfft(tabsize, 1, irest);
  nires = (cires == 1 ? rires2 : rires1);
  for (i = 0; i < tabsize; ++i) nires[i] = irest[i];

  // done
  chg_ires = (cires == 1 ? 2 : 1);
}


///
public void mbeqQuit () {
  import core.stdc.stdlib : free;

  if (lires1 !is null) free(lires1);
  if (lires2 !is null) free(lires2);
  if (rires1 !is null) free(rires1);
  if (rires2 !is null) free(rires2);
  if (irest !is null) free(irest);
  if (fsamples !is null) free(fsamples);
  if (inbuf !is null) free(inbuf);
  if (outbuf !is null) free(outbuf);

  lires1 = null;
  lires2 = null;
  rires1 = null;
  rires2 = null;
  irest = null;
  fsamples = null;
  inbuf = null;
  outbuf = null;

  rfft(0, 0, null);
}


///
public void mbeqClearbuf (int bps, int srate) {
  nbufsamples = 0;
  //foreach (immutable i; 0..tabsize*NCH) outbuf[i] = 0;
  outbuf[0..tabsize*NCH] = 0;
}


///
public int mbeqModifySamples (void* buf, int nsamples, int nch, int bps) {
  int i, p, ch;
  REAL* ires;
  int amax = (1<<(bps-1))-1;
  int amin = -(1<<(bps-1));
  //static REAL smphm1 = 0, smphm2 = 0;

  if (chg_ires) {
    cur_ires = chg_ires;
    lires = (cur_ires == 1 ? lires1 : lires2);
    rires = (cur_ires == 1 ? rires1 : rires2);
    chg_ires = 0;
  }

  p = 0;

  while (nbufsamples+nsamples >= winlen) {
    //version(mbeq_debug_output) conwriteln("nbufsamples+nsamples=", nbufsamples+nsamples, "; winlen=", winlen);
    switch (bps) {
      case 8:
        for (i = 0; i < (winlen-nbufsamples)*nch; ++i) {
          inbuf[nbufsamples*nch+i] = (cast(ubyte*)buf)[i+p*nch]-0x80;
          REAL s = outbuf[nbufsamples*nch+i];
          static if (dither) {
            s -= smphm1;
            REAL u = s;
            s += ditherbuf[(ditherptr++)&(DITHERLEN-1)];
            if (s < amin) s = amin;
            if (amax < s) s = amax;
            s = RINT(s);
            smphm1 = s-u;
            (cast(ubyte*)buf)[i+p*nch] = cast(ubyte)(s+0x80);
          } else {
            if (s < amin) s = amin;
            if (amax < s) s = amax;
            (cast(ubyte*)buf)[i+p*nch] = cast(ubyte)(RINT(s)+0x80);
          }
        }
        for( i = winlen*nch; i < tabsize*nch; ++i) outbuf[i-winlen*nch] = outbuf[i];
        break;
      case 16:
        for (i = 0; i < (winlen-nbufsamples)*nch; ++i) {
          inbuf[nbufsamples*nch+i] = (cast(short*)buf)[i+p*nch];
          REAL s = outbuf[nbufsamples*nch+i];
          static if (dither) {
            s -= smphm1;
            REAL u = s;
            s += ditherbuf[(ditherptr++)&(DITHERLEN-1)];
            if (s < amin) s = amin;
            if (amax < s) s = amax;
            s = RINT(s);
            smphm1 = s-u;
            (cast(short*)buf)[i+p*nch] = cast(short)s;
          } else {
            if (s < amin) s = amin;
            if (amax < s) s = amax;
            (cast(short*)buf)[i+p*nch] = cast(short)RINT(s);
          }
        }
        for (i = winlen*nch; i < tabsize*nch; ++i) outbuf[i-winlen*nch] = outbuf[i];
        break;

      case 24:
        for (i = 0; i < (winlen-nbufsamples)*nch; ++i) {
          (cast(int*)inbuf)[nbufsamples*nch+i] =
            ((cast(ubyte*)buf)[(i+p*nch)*3])|
            ((cast(ubyte*)buf)[(i+p*nch)*3+1]<<8)|
            ((cast(byte*)buf)[(i+p*nch)*3+2]<<16);
          REAL s = outbuf[nbufsamples*nch+i];
          //static if (dither) s += ditherbuf[(ditherptr++)&(DITHERLEN-1)];
          if (s < amin) s = amin;
          if (amax < s) s = amax;
          int s2 = RINT(s);
          (cast(ubyte*)buf)[(i+p*nch)*3+0] = s2&255; s2 >>= 8;
          (cast(ubyte*)buf)[(i+p*nch)*3+1] = s2&255; s2 >>= 8;
          (cast(ubyte*)buf)[(i+p*nch)*3+2] = s2&255;
        }
        for (i = winlen*nch; i < tabsize*nch; ++i) outbuf[i-winlen*nch] = outbuf[i];
        break;
      default: assert(0);
    }

    p += winlen-nbufsamples;
    //{ import core.stdc.stdio; printf("old nsamples: %d\n", nsamples); }
    nsamples -= winlen-nbufsamples;
    //{ import core.stdc.stdio; printf("new nsamples: %d\n", nsamples); }
    nbufsamples = 0;

    for (ch = 0; ch < nch; ++ch) {
      ires = (ch == 0 ? lires : rires);

      if (bps == 24) {
        for (i = 0; i < winlen; ++i) fsamples[i] = (cast(int*)inbuf)[nch*i+ch];
      } else {
        for (i = 0; i < winlen; ++i) fsamples[i] = inbuf[nch*i+ch];
      }

      //for (i = winlen; i < tabsize; ++i) fsamples[i] = 0;
      fsamples[winlen..tabsize] = 0;

      rfft(tabsize, 1, fsamples);
      fsamples[0] = ires[0]*fsamples[0];
      fsamples[1] = ires[1]*fsamples[1];
      for (i = 1; i < tabsize/2; ++i) {
        REAL re = ires[i*2  ]*fsamples[i*2]-ires[i*2+1]*fsamples[i*2+1];
        REAL im = ires[i*2+1]*fsamples[i*2]+ires[i*2  ]*fsamples[i*2+1];
        fsamples[i*2  ] = re;
        fsamples[i*2+1] = im;
      }
      rfft(tabsize, -1, fsamples);
      /*if disabled:
      {
        for (i = winlen-1+winlen/2; i >= winlen/2; --i) fsamples[i] = fsamples[i-winlen/2]*tabsize/2;
        for (; i >= 0; --i) fsamples[i] = 0;
      }
      */

      for (i = 0; i < winlen; ++i) outbuf[i*nch+ch] += fsamples[i]/tabsize*2;
      for (i = winlen; i < tabsize; ++i) outbuf[i*nch+ch] = fsamples[i]/tabsize*2;
    }
  }

  switch (bps) {
    case 8:
      for (i = 0; i < nsamples*nch; ++i) {
        inbuf[nbufsamples*nch+i] = (cast(ubyte*)buf)[i+p*nch]-0x80;
        REAL s = outbuf[nbufsamples*nch+i];
        static if (dither) {
          s -= smphm1;
          REAL u = s;
          s += ditherbuf[(ditherptr++)&(DITHERLEN-1)];
          if (s < amin) s = amin;
          if (amax < s) s = amax;
          s = RINT(s);
          smphm1 = s-u;
          (cast(ubyte*)buf)[i+p*nch] = cast(ubyte)(s+0x80);
        } else {
          if (s < amin) s = amin;
          if (amax < s) s = amax;
          (cast(ubyte*)buf)[i+p*nch] = cast(ubyte)(RINT(s)+0x80);
        }
      }
      break;
    case 16:
      for (i = 0; i < nsamples*nch; ++i) {
        //{ import core.stdc.stdio; printf("i=%u; nsamples*nch=%u; nbufsamples*nch+i=%u; i+p*nch=%u\n", i, nsamples*nch, nbufsamples*nch+i, i+p*nch); }
        inbuf[nbufsamples*nch+i] = (cast(short*)buf)[i+p*nch];
        REAL s = outbuf[nbufsamples*nch+i];
        static if (dither) {
          s -= smphm1;
          REAL u = s;
          s += ditherbuf[(ditherptr++)&(DITHERLEN-1)];
          if (s < amin) s = amin;
          if (amax < s) s = amax;
          s = RINT(s);
          smphm1 = s-u;
          (cast(short*)buf)[i+p*nch] = cast(short)s;
        } else {
          if (s < amin) s = amin;
          if (amax < s) s = amax;
          (cast(short*)buf)[i+p*nch] = cast(short)RINT(s);
        }
      }
      break;
    case 24:
      for (i = 0; i < nsamples*nch; ++i) {
        (cast(int*)inbuf)[nbufsamples*nch+i] =
          ((cast(ubyte*)buf)[(i+p*nch)*3])|
          ((cast(ubyte*)buf)[(i+p*nch)*3+1]<<8)|
          ((cast(byte*)buf)[(i+p*nch)*3+2]<<16);
        REAL s = outbuf[nbufsamples*nch+i];
        //static if (dither) s += ditherbuf[(ditherptr++)&(DITHERLEN-1)];
        if (s < amin) s = amin;
        if (amax < s) s = amax;
        int s2 = RINT(s);
        (cast(ubyte*)buf)[(i+p*nch)*3+0] = s2&255; s2 >>= 8;
        (cast(ubyte*)buf)[(i+p*nch)*3+1] = s2&255; s2 >>= 8;
        (cast(ubyte*)buf)[(i+p*nch)*3+2] = s2&255;
      }
      break;
    default: assert(0);
  }

  p += nsamples;
  nbufsamples += nsamples;

  return p;
}


// ////////////////////////////////////////////////////////////////////////// //
private static immutable int[NBANDS+1] mbeqBandFreqs = [55, 77, 110, 156, 220, 311, 440, 622, 880, 1244, 1760, 2489, 3520, 4978, 7040, 9956, 14080, 19912]; ///
public __gshared int[NBANDS+2] mbeqLSliders; /// [0..96]; 0: preamp; 1..18: bands
public __gshared int[NBANDS+2] mbeqRSliders; /// [0..96]; 0: preamp; 1..18: bands
public __gshared REAL mbeqSampleRate = 48000; ///


public void mbeqSetBandsFromSliders () {
  import std.math : pow;

  REAL[NBANDS+1] lbands = 1.0;
  REAL[NBANDS+1] rbands = 1.0;

  immutable REAL lpreamp = (mbeqLSliders[0] == 96 ? 0 : pow(10, mbeqLSliders[0]/-20.0f));
  immutable REAL rpreamp = (mbeqRSliders[0] == 96 ? 0 : pow(10, mbeqRSliders[0]/-20.0f));
  version(mbeq_debug_output) conwriteln("lpreamp=", lpreamp, "; rpreamp=", rpreamp);
  foreach (immutable i; 0..NBANDS+1) {
    lbands[i] = (mbeqLSliders[i+1] == 96 ? 0 : lpreamp*pow(10, mbeqLSliders[i+1]/-20.0f));
    rbands[i] = (mbeqRSliders[i+1] == 96 ? 0 : rpreamp*pow(10, mbeqRSliders[i+1]/-20.0f));
  }
  //mbeq_makeTable(lbands.ptr, rbands.ptr, paramroot, last_srate);
  mbeqMakeTable(lbands[], rbands[], mbeqSampleRate);
  version(mbeq_debug_output) conwriteln("lbands=", lbands);
  version(mbeq_debug_output) conwriteln("rbands=", rbands);
}


public int mbeqBandCount () { pragma(inline, true); return NBANDS+2; } ///

/// last band is equal to samling rate
public int mbeqBandFreq (int idx) { pragma(inline, true); return (idx > 1 && idx < NBANDS+1 ? mbeqBandFreqs[idx-1] : (idx == NBANDS+1 ? 48000 : 0)); }


// ////////////////////////////////////////////////////////////////////////// //
private:
/*
 * Copyright(C) 1996-2001 Takuya OOURA
 * email: ooura@mmm.t.u-tokyo.ac.jp
 * download: http://momonga.t.u-tokyo.ac.jp/~ooura/fft.html
 * You may use, copy, modify this code for any purpose and
 * without fee. You may distribute this ORIGINAL package.
 */
//module fftsg /*is aliced*/;
private nothrow @trusted @nogc:

/*public*/ alias REAL = float;

/*
Fast Fourier/Cosine/Sine Transform
    dimension   :one
    data length :power of 2
    decimation  :frequency
    radix       :split-radix
    data        :inplace
    table       :use
functions
    cdft: Complex Discrete Fourier Transform
    rdft: Real Discrete Fourier Transform
    ddct: Discrete Cosine Transform
    ddst: Discrete Sine Transform
    dfct: Cosine Transform of RDFT (Real Symmetric DFT)
    dfst: Sine Transform of RDFT (Real Anti-symmetric DFT)
function prototypes
    void cdft(int, int, REAL *, int *, REAL *);
    void rdft(int, int, REAL *, int *, REAL *);
    void ddct(int, int, REAL *, int *, REAL *);
    void ddst(int, int, REAL *, int *, REAL *);
    void dfct(int, REAL *, REAL *, int *, REAL *);
    void dfst(int, REAL *, REAL *, int *, REAL *);


-------- Complex DFT (Discrete Fourier Transform) --------
    [definition]
        <case1>
            X[k] = sum_j=0^n-1 x[j]*exp(2*pi*i*j*k/n), 0<=k<n
        <case2>
            X[k] = sum_j=0^n-1 x[j]*exp(-2*pi*i*j*k/n), 0<=k<n
        (notes: sum_j=0^n-1 is a summation from j=0 to n-1)
    [usage]
        <case1>
            ip[0] = 0; // first time only
            cdft(2*n, 1, a, ip, w);
        <case2>
            ip[0] = 0; // first time only
            cdft(2*n, -1, a, ip, w);
    [parameters]
        2*n            :data length (int)
                        n >= 1, n = power of 2
        a[0...2*n-1]   :input/output data (REAL *)
                        input data
                            a[2*j] = Re(x[j]),
                            a[2*j+1] = Im(x[j]), 0<=j<n
                        output data
                            a[2*k] = Re(X[k]),
                            a[2*k+1] = Im(X[k]), 0<=k<n
        ip[0...*]      :work area for bit reversal (int *)
                        length of ip >= 2+sqrt(n)
                        strictly,
                        length of ip >=
                            2+(1<<(int)(log(n+0.5)/log(2))/2).
                        ip[0],ip[1] are pointers of the cos/sin table.
        w[0...n/2-1]   :cos/sin table (REAL *)
                        w[],ip[] are initialized if ip[0] == 0.
    [remark]
        Inverse of
            cdft(2*n, -1, a, ip, w);
        is
            cdft(2*n, 1, a, ip, w);
            for (j = 0; j <= 2 * n - 1; j++) {
                a[j] *= 1.0 / n;
            }
        .


-------- Real DFT / Inverse of Real DFT --------
    [definition]
        <case1> RDFT
            R[k] = sum_j=0^n-1 a[j]*cos(2*pi*j*k/n), 0<=k<=n/2
            I[k] = sum_j=0^n-1 a[j]*sin(2*pi*j*k/n), 0<k<n/2
        <case2> IRDFT (excluding scale)
            a[k] = (R[0] + R[n/2]*cos(pi*k))/2 +
                   sum_j=1^n/2-1 R[j]*cos(2*pi*j*k/n) +
                   sum_j=1^n/2-1 I[j]*sin(2*pi*j*k/n), 0<=k<n
    [usage]
        <case1>
            ip[0] = 0; // first time only
            rdft(n, 1, a, ip, w);
        <case2>
            ip[0] = 0; // first time only
            rdft(n, -1, a, ip, w);
    [parameters]
        n              :data length (int)
                        n >= 2, n = power of 2
        a[0...n-1]     :input/output data (REAL *)
                        <case1>
                            output data
                                a[2*k] = R[k], 0<=k<n/2
                                a[2*k+1] = I[k], 0<k<n/2
                                a[1] = R[n/2]
                        <case2>
                            input data
                                a[2*j] = R[j], 0<=j<n/2
                                a[2*j+1] = I[j], 0<j<n/2
                                a[1] = R[n/2]
        ip[0...*]      :work area for bit reversal (int *)
                        length of ip >= 2+sqrt(n/2)
                        strictly,
                        length of ip >=
                            2+(1<<(int)(log(n/2+0.5)/log(2))/2).
                        ip[0],ip[1] are pointers of the cos/sin table.
        w[0...n/2-1]   :cos/sin table (REAL *)
                        w[],ip[] are initialized if ip[0] == 0.
    [remark]
        Inverse of
            rdft(n, 1, a, ip, w);
        is
            rdft(n, -1, a, ip, w);
            for (j = 0; j <= n - 1; j++) {
                a[j] *= 2.0 / n;
            }
        .


-------- DCT (Discrete Cosine Transform) / Inverse of DCT --------
    [definition]
        <case1> IDCT (excluding scale)
            C[k] = sum_j=0^n-1 a[j]*cos(pi*j*(k+1/2)/n), 0<=k<n
        <case2> DCT
            C[k] = sum_j=0^n-1 a[j]*cos(pi*(j+1/2)*k/n), 0<=k<n
    [usage]
        <case1>
            ip[0] = 0; // first time only
            ddct(n, 1, a, ip, w);
        <case2>
            ip[0] = 0; // first time only
            ddct(n, -1, a, ip, w);
    [parameters]
        n              :data length (int)
                        n >= 2, n = power of 2
        a[0...n-1]     :input/output data (REAL *)
                        output data
                            a[k] = C[k], 0<=k<n
        ip[0...*]      :work area for bit reversal (int *)
                        length of ip >= 2+sqrt(n/2)
                        strictly,
                        length of ip >=
                            2+(1<<(int)(log(n/2+0.5)/log(2))/2).
                        ip[0],ip[1] are pointers of the cos/sin table.
        w[0...n*5/4-1] :cos/sin table (REAL *)
                        w[],ip[] are initialized if ip[0] == 0.
    [remark]
        Inverse of
            ddct(n, -1, a, ip, w);
        is
            a[0] *= 0.5;
            ddct(n, 1, a, ip, w);
            for (j = 0; j <= n - 1; j++) {
                a[j] *= 2.0 / n;
            }
        .


-------- DST (Discrete Sine Transform) / Inverse of DST --------
    [definition]
        <case1> IDST (excluding scale)
            S[k] = sum_j=1^n A[j]*sin(pi*j*(k+1/2)/n), 0<=k<n
        <case2> DST
            S[k] = sum_j=0^n-1 a[j]*sin(pi*(j+1/2)*k/n), 0<k<=n
    [usage]
        <case1>
            ip[0] = 0; // first time only
            ddst(n, 1, a, ip, w);
        <case2>
            ip[0] = 0; // first time only
            ddst(n, -1, a, ip, w);
    [parameters]
        n              :data length (int)
                        n >= 2, n = power of 2
        a[0...n-1]     :input/output data (REAL *)
                        <case1>
                            input data
                                a[j] = A[j], 0<j<n
                                a[0] = A[n]
                            output data
                                a[k] = S[k], 0<=k<n
                        <case2>
                            output data
                                a[k] = S[k], 0<k<n
                                a[0] = S[n]
        ip[0...*]      :work area for bit reversal (int *)
                        length of ip >= 2+sqrt(n/2)
                        strictly,
                        length of ip >=
                            2+(1<<(int)(log(n/2+0.5)/log(2))/2).
                        ip[0],ip[1] are pointers of the cos/sin table.
        w[0...n*5/4-1] :cos/sin table (REAL *)
                        w[],ip[] are initialized if ip[0] == 0.
    [remark]
        Inverse of
            ddst(n, -1, a, ip, w);
        is
            a[0] *= 0.5;
            ddst(n, 1, a, ip, w);
            for (j = 0; j <= n - 1; j++) {
                a[j] *= 2.0 / n;
            }
        .


-------- Cosine Transform of RDFT (Real Symmetric DFT) --------
    [definition]
        C[k] = sum_j=0^n a[j]*cos(pi*j*k/n), 0<=k<=n
    [usage]
        ip[0] = 0; // first time only
        dfct(n, a, t, ip, w);
    [parameters]
        n              :data length - 1 (int)
                        n >= 2, n = power of 2
        a[0...n]       :input/output data (REAL *)
                        output data
                            a[k] = C[k], 0<=k<=n
        t[0...n/2]     :work area (REAL *)
        ip[0...*]      :work area for bit reversal (int *)
                        length of ip >= 2+sqrt(n/4)
                        strictly,
                        length of ip >=
                            2+(1<<(int)(log(n/4+0.5)/log(2))/2).
                        ip[0],ip[1] are pointers of the cos/sin table.
        w[0...n*5/8-1] :cos/sin table (REAL *)
                        w[],ip[] are initialized if ip[0] == 0.
    [remark]
        Inverse of
            a[0] *= 0.5;
            a[n] *= 0.5;
            dfct(n, a, t, ip, w);
        is
            a[0] *= 0.5;
            a[n] *= 0.5;
            dfct(n, a, t, ip, w);
            for (j = 0; j <= n; j++) {
                a[j] *= 2.0 / n;
            }
        .


-------- Sine Transform of RDFT (Real Anti-symmetric DFT) --------
    [definition]
        S[k] = sum_j=1^n-1 a[j]*sin(pi*j*k/n), 0<k<n
    [usage]
        ip[0] = 0; // first time only
        dfst(n, a, t, ip, w);
    [parameters]
        n              :data length + 1 (int)
                        n >= 2, n = power of 2
        a[0...n-1]     :input/output data (REAL *)
                        output data
                            a[k] = S[k], 0<k<n
                        (a[0] is used for work area)
        t[0...n/2-1]   :work area (REAL *)
        ip[0...*]      :work area for bit reversal (int *)
                        length of ip >= 2+sqrt(n/4)
                        strictly,
                        length of ip >=
                            2+(1<<(int)(log(n/4+0.5)/log(2))/2).
                        ip[0],ip[1] are pointers of the cos/sin table.
        w[0...n*5/8-1] :cos/sin table (REAL *)
                        w[],ip[] are initialized if ip[0] == 0.
    [remark]
        Inverse of
            dfst(n, a, t, ip, w);
        is
            dfst(n, a, t, ip, w);
            for (j = 1; j <= n - 1; j++) {
                a[j] *= 2.0 / n;
            }
        .


Appendix :
    The cos/sin table is recalculated when the larger table required.
    w[] and ip[] are compatible with all routines.
*/


// Complex Discrete Fourier Transform
/*public*/ void cdft (int n, int isgn, REAL* a, int* ip, REAL* w) {
  int nw = ip[0];
  if (n > (nw << 2)) {
    nw = n >> 2;
    makewt(nw, ip, w);
  }
  if (isgn >= 0) {
    cftfsub(n, a, ip, nw, w);
  } else {
    cftbsub(n, a, ip, nw, w);
  }
}


// Real Discrete Fourier Transform
/*public*/ void rdft (int n, int isgn, REAL* a, int* ip, REAL* w) {
  int nw = ip[0];
  if (n > (nw << 2)) {
    nw = n >> 2;
    makewt(nw, ip, w);
  }
  int nc = ip[1];
  if (n > (nc << 2)) {
    nc = n >> 2;
    makect(nc, ip, w + nw);
  }
  if (isgn >= 0) {
    if (n > 4) {
      cftfsub(n, a, ip, nw, w);
      rftfsub(n, a, nc, w + nw);
    } else if (n == 4) {
      cftfsub(n, a, ip, nw, w);
    }
    REAL xi = a[0] - a[1];
    a[0] += a[1];
    a[1] = xi;
  } else {
    a[1] = 0.5 * (a[0] - a[1]);
    a[0] -= a[1];
    if (n > 4) {
      rftbsub(n, a, nc, w + nw);
      cftbsub(n, a, ip, nw, w);
    } else if (n == 4) {
      cftbsub(n, a, ip, nw, w);
    }
  }
}


// Discrete Cosine Transform
/*public*/ void ddct (int n, int isgn, REAL* a, int* ip, REAL* w) {
  int nw = ip[0];
  if (n > (nw << 2)) {
      nw = n >> 2;
      makewt(nw, ip, w);
  }
  int nc = ip[1];
  if (n > nc) {
      nc = n;
      makect(nc, ip, w + nw);
  }
  if (isgn < 0) {
      REAL xr = a[n - 1];
      for (int j = n - 2; j >= 2; j -= 2) {
          a[j + 1] = a[j] - a[j - 1];
          a[j] += a[j - 1];
      }
      a[1] = a[0] - xr;
      a[0] += xr;
      if (n > 4) {
          rftbsub(n, a, nc, w + nw);
          cftbsub(n, a, ip, nw, w);
      } else if (n == 4) {
          cftbsub(n, a, ip, nw, w);
      }
  }
  dctsub(n, a, nc, w + nw);
  if (isgn >= 0) {
      if (n > 4) {
          cftfsub(n, a, ip, nw, w);
          rftfsub(n, a, nc, w + nw);
      } else if (n == 4) {
          cftfsub(n, a, ip, nw, w);
      }
      REAL xr = a[0] - a[1];
      a[0] += a[1];
      for (int j = 2; j < n; j += 2) {
          a[j - 1] = a[j] - a[j + 1];
          a[j] += a[j + 1];
      }
      a[n - 1] = xr;
  }
}


// Discrete Sine Transform
/*public*/ void ddst (int n, int isgn, REAL* a, int* ip, REAL* w) {
    int nw = ip[0];
    if (n > (nw << 2)) {
        nw = n >> 2;
        makewt(nw, ip, w);
    }
    int nc = ip[1];
    if (n > nc) {
        nc = n;
        makect(nc, ip, w + nw);
    }
    if (isgn < 0) {
        REAL xr = a[n - 1];
        for (int j = n - 2; j >= 2; j -= 2) {
            a[j + 1] = -a[j] - a[j - 1];
            a[j] -= a[j - 1];
        }
        a[1] = a[0] + xr;
        a[0] -= xr;
        if (n > 4) {
            rftbsub(n, a, nc, w + nw);
            cftbsub(n, a, ip, nw, w);
        } else if (n == 4) {
            cftbsub(n, a, ip, nw, w);
        }
    }
    dstsub(n, a, nc, w + nw);
    if (isgn >= 0) {
        if (n > 4) {
            cftfsub(n, a, ip, nw, w);
            rftfsub(n, a, nc, w + nw);
        } else if (n == 4) {
            cftfsub(n, a, ip, nw, w);
        }
        REAL xr = a[0] - a[1];
        a[0] += a[1];
        for (int j = 2; j < n; j += 2) {
            a[j - 1] = -a[j] - a[j + 1];
            a[j] -= a[j + 1];
        }
        a[n - 1] = -xr;
    }
}


// Cosine Transform of RDFT (Real Symmetric DFT)
/*public*/ void dfct (int n, REAL* a, REAL* t, int* ip, REAL* w) {
    int j, k, l, m, mh, nw, nc;
    //REAL xr, xi, yr, yi;

    nw = ip[0];
    if (n > (nw << 3)) {
        nw = n >> 3;
        makewt(nw, ip, w);
    }
    nc = ip[1];
    if (n > (nc << 1)) {
        nc = n >> 1;
        makect(nc, ip, w + nw);
    }
    m = n >> 1;
    REAL yi = a[m];
    REAL xi = a[0] + a[n];
    a[0] -= a[n];
    t[0] = xi - yi;
    t[m] = xi + yi;
    if (n > 2) {
        mh = m >> 1;
        for (j = 1; j < mh; j++) {
            k = m - j;
            REAL xr = a[j] - a[n - j];
            xi = a[j] + a[n - j];
            REAL yr = a[k] - a[n - k];
            yi = a[k] + a[n - k];
            a[j] = xr;
            a[k] = yr;
            t[j] = xi - yi;
            t[k] = xi + yi;
        }
        t[mh] = a[mh] + a[n - mh];
        a[mh] -= a[n - mh];
        dctsub(m, a, nc, w + nw);
        if (m > 4) {
            cftfsub(m, a, ip, nw, w);
            rftfsub(m, a, nc, w + nw);
        } else if (m == 4) {
            cftfsub(m, a, ip, nw, w);
        }
        a[n - 1] = a[0] - a[1];
        a[1] = a[0] + a[1];
        for (j = m - 2; j >= 2; j -= 2) {
            a[2 * j + 1] = a[j] + a[j + 1];
            a[2 * j - 1] = a[j] - a[j + 1];
        }
        l = 2;
        m = mh;
        while (m >= 2) {
            dctsub(m, t, nc, w + nw);
            if (m > 4) {
                cftfsub(m, t, ip, nw, w);
                rftfsub(m, t, nc, w + nw);
            } else if (m == 4) {
                cftfsub(m, t, ip, nw, w);
            }
            a[n - l] = t[0] - t[1];
            a[l] = t[0] + t[1];
            k = 0;
            for (j = 2; j < m; j += 2) {
                k += l << 2;
                a[k - l] = t[j] - t[j + 1];
                a[k + l] = t[j] + t[j + 1];
            }
            l <<= 1;
            mh = m >> 1;
            for (j = 0; j < mh; j++) {
                k = m - j;
                t[j] = t[m + k] - t[m + j];
                t[k] = t[m + k] + t[m + j];
            }
            t[mh] = t[m + mh];
            m = mh;
        }
        a[l] = t[0];
        a[n] = t[2] - t[1];
        a[0] = t[2] + t[1];
    } else {
        a[1] = a[0];
        a[2] = t[0];
        a[0] = t[1];
    }
}


// Sine Transform of RDFT (Real Anti-symmetric DFT)
/*public*/ void dfst (int n, REAL* a, REAL* t, int* ip, REAL* w) {
    int j, k, l, m, mh, nw, nc;
    //REAL xr, xi, yr, yi;

    nw = ip[0];
    if (n > (nw << 3)) {
        nw = n >> 3;
        makewt(nw, ip, w);
    }
    nc = ip[1];
    if (n > (nc << 1)) {
        nc = n >> 1;
        makect(nc, ip, w + nw);
    }
    if (n > 2) {
        m = n >> 1;
        mh = m >> 1;
        for (j = 1; j < mh; j++) {
            k = m - j;
            REAL xr = a[j] + a[n - j];
            REAL xi = a[j] - a[n - j];
            REAL yr = a[k] + a[n - k];
            REAL yi = a[k] - a[n - k];
            a[j] = xr;
            a[k] = yr;
            t[j] = xi + yi;
            t[k] = xi - yi;
        }
        t[0] = a[mh] - a[n - mh];
        a[mh] += a[n - mh];
        a[0] = a[m];
        dstsub(m, a, nc, w + nw);
        if (m > 4) {
            cftfsub(m, a, ip, nw, w);
            rftfsub(m, a, nc, w + nw);
        } else if (m == 4) {
            cftfsub(m, a, ip, nw, w);
        }
        a[n - 1] = a[1] - a[0];
        a[1] = a[0] + a[1];
        for (j = m - 2; j >= 2; j -= 2) {
            a[2 * j + 1] = a[j] - a[j + 1];
            a[2 * j - 1] = -a[j] - a[j + 1];
        }
        l = 2;
        m = mh;
        while (m >= 2) {
            dstsub(m, t, nc, w + nw);
            if (m > 4) {
                cftfsub(m, t, ip, nw, w);
                rftfsub(m, t, nc, w + nw);
            } else if (m == 4) {
                cftfsub(m, t, ip, nw, w);
            }
            a[n - l] = t[1] - t[0];
            a[l] = t[0] + t[1];
            k = 0;
            for (j = 2; j < m; j += 2) {
                k += l << 2;
                a[k - l] = -t[j] - t[j + 1];
                a[k + l] = t[j] - t[j + 1];
            }
            l <<= 1;
            mh = m >> 1;
            for (j = 1; j < mh; j++) {
                k = m - j;
                t[j] = t[m + k] + t[m + j];
                t[k] = t[m + k] - t[m + j];
            }
            t[0] = t[m + mh];
            m = mh;
        }
        a[l] = t[0];
    }
    a[0] = 0;
}


// ////////////////////////////////////////////////////////////////////////// //
private:
/* -------- initializing routines -------- */

void makewt(int nw, int *ip, REAL *w)
{
    import std.math : atan, cos, sin;
    int j, nwh, nw0, nw1;
    //REAL delta, wn4r, wk1r, wk1i, wk3r, wk3i;

    ip[0] = nw;
    ip[1] = 1;
    if (nw > 2) {
        nwh = nw >> 1;
        REAL delta = atan(1.0) / nwh;
        REAL wn4r = cos(delta * nwh);
        w[0] = 1;
        w[1] = wn4r;
        if (nwh == 4) {
            w[2] = cos(delta * 2);
            w[3] = sin(delta * 2);
        } else if (nwh > 4) {
            makeipt(nw, ip);
            w[2] = 0.5 / cos(delta * 2);
            w[3] = 0.5 / cos(delta * 6);
            for (j = 4; j < nwh; j += 4) {
                w[j] = cos(delta * j);
                w[j + 1] = sin(delta * j);
                w[j + 2] = cos(3 * delta * j);
                w[j + 3] = -sin(3 * delta * j);
            }
        }
        nw0 = 0;
        while (nwh > 2) {
            nw1 = nw0 + nwh;
            nwh >>= 1;
            w[nw1] = 1;
            w[nw1 + 1] = wn4r;
            if (nwh == 4) {
                REAL wk1r = w[nw0 + 4];
                REAL wk1i = w[nw0 + 5];
                w[nw1 + 2] = wk1r;
                w[nw1 + 3] = wk1i;
            } else if (nwh > 4) {
                REAL wk1r = w[nw0 + 4];
                REAL wk9r = w[nw0 + 6];
                w[nw1 + 2] = 0.5 / wk1r;
                w[nw1 + 3] = 0.5 / wk9r;
                for (j = 4; j < nwh; j += 4) {
                    wk1r = w[nw0 + 2 * j];
                    REAL wk1i = w[nw0 + 2 * j + 1];
                    REAL wk3r = w[nw0 + 2 * j + 2];
                    REAL wk3i = w[nw0 + 2 * j + 3];
                    w[nw1 + j] = wk1r;
                    w[nw1 + j + 1] = wk1i;
                    w[nw1 + j + 2] = wk3r;
                    w[nw1 + j + 3] = wk3i;
                }
            }
            nw0 = nw1;
        }
    }
}


void makeipt(int nw, int *ip)
{
    int j, l, m, m2, p, q;

    ip[2] = 0;
    ip[3] = 16;
    m = 2;
    for (l = nw; l > 32; l >>= 2) {
        m2 = m << 1;
        q = m2 << 3;
        for (j = m; j < m2; j++) {
            p = ip[j] << 2;
            ip[m + j] = p;
            ip[m2 + j] = p + q;
        }
        m = m2;
    }
}


void makect(int nc, int *ip, REAL *c)
{
    import std.math : atan, cos, sin;
    int j, nch;
    //REAL delta;

    ip[1] = nc;
    if (nc > 1) {
        nch = nc >> 1;
        REAL delta = atan(1.0) / nch;
        c[0] = cos(delta * nch);
        c[nch] = 0.5 * c[0];
        for (j = 1; j < nch; j++) {
            c[j] = 0.5 * cos(delta * j);
            c[nc - j] = 0.5 * sin(delta * j);
        }
    }
}


/* -------- child routines -------- */

void cftfsub(int n, REAL *a, int *ip, int nw, REAL *w)
{

    if (n > 8) {
        if (n > 32) {
            cftf1st(n, a, &w[nw - (n >> 2)]);
            if (n > 512) {
                cftrec4(n, a, nw, w);
            } else if (n > 128) {
                cftleaf(n, 1, a, nw, w);
            } else {
                cftfx41(n, a, nw, w);
            }
            bitrv2(n, ip, a);
        } else if (n == 32) {
            cftf161(a, &w[nw - 8]);
            bitrv216(a);
        } else {
            cftf081(a, w);
            bitrv208(a);
        }
    } else if (n == 8) {
        cftf040(a);
    } else if (n == 4) {
        cftx020(a);
    }
}


void cftbsub(int n, REAL *a, int *ip, int nw, REAL *w)
{
    if (n > 8) {
        if (n > 32) {
            cftb1st(n, a, &w[nw - (n >> 2)]);
            if (n > 512) {
                cftrec4(n, a, nw, w);
            } else if (n > 128) {
                cftleaf(n, 1, a, nw, w);
            } else {
                cftfx41(n, a, nw, w);
            }
            bitrv2conj(n, ip, a);
        } else if (n == 32) {
            cftf161(a, &w[nw - 8]);
            bitrv216neg(a);
        } else {
            cftf081(a, w);
            bitrv208neg(a);
        }
    } else if (n == 8) {
        cftb040(a);
    } else if (n == 4) {
        cftx020(a);
    }
}


void bitrv2(int n, int *ip, REAL *a)
{
    int j, j1, k, k1, l, m, nh, nm;
    //REAL xr, xi, yr, yi;

    m = 1;
    for (l = n >> 2; l > 8; l >>= 2) {
        m <<= 1;
    }
    nh = n >> 1;
    nm = 4 * m;
    if (l == 8) {
        for (k = 0; k < m; k++) {
            for (j = 0; j < k; j++) {
                j1 = 4 * j + 2 * ip[m + k];
                k1 = 4 * k + 2 * ip[m + j];
                REAL xr = a[j1];
                REAL xi = a[j1 + 1];
                REAL yr = a[k1];
                REAL yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 -= nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nh;
                k1 += 2;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 += nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += 2;
                k1 += nh;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 -= nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nh;
                k1 -= 2;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 += nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
            }
            k1 = 4 * k + 2 * ip[m + k];
            j1 = k1 + 2;
            k1 += nh;
            REAL xr = a[j1];
            REAL xi = a[j1 + 1];
            REAL yr = a[k1];
            REAL yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 += nm;
            k1 += 2 * nm;
            xr = a[j1];
            xi = a[j1 + 1];
            yr = a[k1];
            yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 += nm;
            k1 -= nm;
            xr = a[j1];
            xi = a[j1 + 1];
            yr = a[k1];
            yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 -= 2;
            k1 -= nh;
            xr = a[j1];
            xi = a[j1 + 1];
            yr = a[k1];
            yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 += nh + 2;
            k1 += nh + 2;
            xr = a[j1];
            xi = a[j1 + 1];
            yr = a[k1];
            yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 -= nh - nm;
            k1 += 2 * nm - 2;
            xr = a[j1];
            xi = a[j1 + 1];
            yr = a[k1];
            yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
        }
    } else {
        for (k = 0; k < m; k++) {
            for (j = 0; j < k; j++) {
                j1 = 4 * j + ip[m + k];
                k1 = 4 * k + ip[m + j];
                REAL xr = a[j1];
                REAL xi = a[j1 + 1];
                REAL yr = a[k1];
                REAL yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nh;
                k1 += 2;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += 2;
                k1 += nh;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nh;
                k1 -= 2;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= nm;
                xr = a[j1];
                xi = a[j1 + 1];
                yr = a[k1];
                yi = a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
            }
            k1 = 4 * k + ip[m + k];
            j1 = k1 + 2;
            k1 += nh;
            REAL xr = a[j1];
            REAL xi = a[j1 + 1];
            REAL yr = a[k1];
            REAL yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 += nm;
            k1 += nm;
            xr = a[j1];
            xi = a[j1 + 1];
            yr = a[k1];
            yi = a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
        }
    }
}


void bitrv2conj(int n, int *ip, REAL *a)
{
    int j, j1, k, k1, l, m, nh, nm;
    //REAL xr, xi, yr, yi;

    m = 1;
    for (l = n >> 2; l > 8; l >>= 2) {
        m <<= 1;
    }
    nh = n >> 1;
    nm = 4 * m;
    if (l == 8) {
        for (k = 0; k < m; k++) {
            for (j = 0; j < k; j++) {
                j1 = 4 * j + 2 * ip[m + k];
                k1 = 4 * k + 2 * ip[m + j];
                REAL xr = a[j1];
                REAL xi = -a[j1 + 1];
                REAL yr = a[k1];
                REAL yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 -= nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nh;
                k1 += 2;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 += nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += 2;
                k1 += nh;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 -= nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nh;
                k1 -= 2;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 += nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= 2 * nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
            }
            k1 = 4 * k + 2 * ip[m + k];
            j1 = k1 + 2;
            k1 += nh;
            a[j1 - 1] = -a[j1 - 1];
            REAL xr = a[j1];
            REAL xi = -a[j1 + 1];
            REAL yr = a[k1];
            REAL yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            a[k1 + 3] = -a[k1 + 3];
            j1 += nm;
            k1 += 2 * nm;
            xr = a[j1];
            xi = -a[j1 + 1];
            yr = a[k1];
            yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 += nm;
            k1 -= nm;
            xr = a[j1];
            xi = -a[j1 + 1];
            yr = a[k1];
            yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 -= 2;
            k1 -= nh;
            xr = a[j1];
            xi = -a[j1 + 1];
            yr = a[k1];
            yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 += nh + 2;
            k1 += nh + 2;
            xr = a[j1];
            xi = -a[j1 + 1];
            yr = a[k1];
            yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            j1 -= nh - nm;
            k1 += 2 * nm - 2;
            a[j1 - 1] = -a[j1 - 1];
            xr = a[j1];
            xi = -a[j1 + 1];
            yr = a[k1];
            yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            a[k1 + 3] = -a[k1 + 3];
        }
    } else {
        for (k = 0; k < m; k++) {
            for (j = 0; j < k; j++) {
                j1 = 4 * j + ip[m + k];
                k1 = 4 * k + ip[m + j];
                REAL xr = a[j1];
                REAL xi = -a[j1 + 1];
                REAL yr = a[k1];
                REAL yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nh;
                k1 += 2;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += 2;
                k1 += nh;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 += nm;
                k1 += nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nh;
                k1 -= 2;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
                j1 -= nm;
                k1 -= nm;
                xr = a[j1];
                xi = -a[j1 + 1];
                yr = a[k1];
                yi = -a[k1 + 1];
                a[j1] = yr;
                a[j1 + 1] = yi;
                a[k1] = xr;
                a[k1 + 1] = xi;
            }
            k1 = 4 * k + ip[m + k];
            j1 = k1 + 2;
            k1 += nh;
            a[j1 - 1] = -a[j1 - 1];
            REAL xr = a[j1];
            REAL xi = -a[j1 + 1];
            REAL yr = a[k1];
            REAL yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            a[k1 + 3] = -a[k1 + 3];
            j1 += nm;
            k1 += nm;
            a[j1 - 1] = -a[j1 - 1];
            xr = a[j1];
            xi = -a[j1 + 1];
            yr = a[k1];
            yi = -a[k1 + 1];
            a[j1] = yr;
            a[j1 + 1] = yi;
            a[k1] = xr;
            a[k1 + 1] = xi;
            a[k1 + 3] = -a[k1 + 3];
        }
    }
}


void bitrv216(REAL *a)
{
    /*
    REAL x1r, x1i, x2r, x2i, x3r, x3i, x4r, x4i,
        x5r, x5i, x7r, x7i, x8r, x8i, x10r, x10i,
        x11r, x11i, x12r, x12i, x13r, x13i, x14r, x14i;
    */
    immutable REAL x1r = a[2];
    immutable REAL x1i = a[3];
    immutable REAL x2r = a[4];
    immutable REAL x2i = a[5];
    immutable REAL x3r = a[6];
    immutable REAL x3i = a[7];
    immutable REAL x4r = a[8];
    immutable REAL x4i = a[9];
    immutable REAL x5r = a[10];
    immutable REAL x5i = a[11];
    immutable REAL x7r = a[14];
    immutable REAL x7i = a[15];
    immutable REAL x8r = a[16];
    immutable REAL x8i = a[17];
    immutable REAL x10r = a[20];
    immutable REAL x10i = a[21];
    immutable REAL x11r = a[22];
    immutable REAL x11i = a[23];
    immutable REAL x12r = a[24];
    immutable REAL x12i = a[25];
    immutable REAL x13r = a[26];
    immutable REAL x13i = a[27];
    immutable REAL x14r = a[28];
    immutable REAL x14i = a[29];
    a[2] = x8r;
    a[3] = x8i;
    a[4] = x4r;
    a[5] = x4i;
    a[6] = x12r;
    a[7] = x12i;
    a[8] = x2r;
    a[9] = x2i;
    a[10] = x10r;
    a[11] = x10i;
    a[14] = x14r;
    a[15] = x14i;
    a[16] = x1r;
    a[17] = x1i;
    a[20] = x5r;
    a[21] = x5i;
    a[22] = x13r;
    a[23] = x13i;
    a[24] = x3r;
    a[25] = x3i;
    a[26] = x11r;
    a[27] = x11i;
    a[28] = x7r;
    a[29] = x7i;
}


void bitrv216neg(REAL *a)
{
    /*
    REAL x1r, x1i, x2r, x2i, x3r, x3i, x4r, x4i,
        x5r, x5i, x6r, x6i, x7r, x7i, x8r, x8i,
        x9r, x9i, x10r, x10i, x11r, x11i, x12r, x12i,
        x13r, x13i, x14r, x14i, x15r, x15i;
    */
    immutable REAL x1r = a[2];
    immutable REAL x1i = a[3];
    immutable REAL x2r = a[4];
    immutable REAL x2i = a[5];
    immutable REAL x3r = a[6];
    immutable REAL x3i = a[7];
    immutable REAL x4r = a[8];
    immutable REAL x4i = a[9];
    immutable REAL x5r = a[10];
    immutable REAL x5i = a[11];
    immutable REAL x6r = a[12];
    immutable REAL x6i = a[13];
    immutable REAL x7r = a[14];
    immutable REAL x7i = a[15];
    immutable REAL x8r = a[16];
    immutable REAL x8i = a[17];
    immutable REAL x9r = a[18];
    immutable REAL x9i = a[19];
    immutable REAL x10r = a[20];
    immutable REAL x10i = a[21];
    immutable REAL x11r = a[22];
    immutable REAL x11i = a[23];
    immutable REAL x12r = a[24];
    immutable REAL x12i = a[25];
    immutable REAL x13r = a[26];
    immutable REAL x13i = a[27];
    immutable REAL x14r = a[28];
    immutable REAL x14i = a[29];
    immutable REAL x15r = a[30];
    immutable REAL x15i = a[31];
    a[2] = x15r;
    a[3] = x15i;
    a[4] = x7r;
    a[5] = x7i;
    a[6] = x11r;
    a[7] = x11i;
    a[8] = x3r;
    a[9] = x3i;
    a[10] = x13r;
    a[11] = x13i;
    a[12] = x5r;
    a[13] = x5i;
    a[14] = x9r;
    a[15] = x9i;
    a[16] = x1r;
    a[17] = x1i;
    a[18] = x14r;
    a[19] = x14i;
    a[20] = x6r;
    a[21] = x6i;
    a[22] = x10r;
    a[23] = x10i;
    a[24] = x2r;
    a[25] = x2i;
    a[26] = x12r;
    a[27] = x12i;
    a[28] = x4r;
    a[29] = x4i;
    a[30] = x8r;
    a[31] = x8i;
}


void bitrv208(REAL *a)
{
    //REAL x1r, x1i, x3r, x3i, x4r, x4i, x6r, x6i;

    immutable REAL x1r = a[2];
    immutable REAL x1i = a[3];
    immutable REAL x3r = a[6];
    immutable REAL x3i = a[7];
    immutable REAL x4r = a[8];
    immutable REAL x4i = a[9];
    immutable REAL x6r = a[12];
    immutable REAL x6i = a[13];
    a[2] = x4r;
    a[3] = x4i;
    a[6] = x6r;
    a[7] = x6i;
    a[8] = x1r;
    a[9] = x1i;
    a[12] = x3r;
    a[13] = x3i;
}


void bitrv208neg(REAL *a)
{
    //REAL x1r, x1i, x2r, x2i, x3r, x3i, x4r, x4i, x5r, x5i, x6r, x6i, x7r, x7i;

    immutable REAL x1r = a[2];
    immutable REAL x1i = a[3];
    immutable REAL x2r = a[4];
    immutable REAL x2i = a[5];
    immutable REAL x3r = a[6];
    immutable REAL x3i = a[7];
    immutable REAL x4r = a[8];
    immutable REAL x4i = a[9];
    immutable REAL x5r = a[10];
    immutable REAL x5i = a[11];
    immutable REAL x6r = a[12];
    immutable REAL x6i = a[13];
    immutable REAL x7r = a[14];
    immutable REAL x7i = a[15];
    a[2] = x7r;
    a[3] = x7i;
    a[4] = x3r;
    a[5] = x3i;
    a[6] = x5r;
    a[7] = x5i;
    a[8] = x1r;
    a[9] = x1i;
    a[10] = x6r;
    a[11] = x6i;
    a[12] = x2r;
    a[13] = x2i;
    a[14] = x4r;
    a[15] = x4i;
}


void cftf1st(int n, REAL *a, REAL *w)
{
    int j, j0, j1, j2, j3, k, m, mh;
    //REAL wn4r, csc1, csc3, wk1r, wk1i, wk3r, wk3i, wd1r, wd1i, wd3r, wd3i;
    //REAL x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i, y0r, y0i, y1r, y1i, y2r, y2i, y3r, y3i;

    mh = n >> 3;
    m = 2 * mh;
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    REAL x0r = a[0] + a[j2];
    REAL x0i = a[1] + a[j2 + 1];
    REAL x1r = a[0] - a[j2];
    REAL x1i = a[1] - a[j2 + 1];
    REAL x2r = a[j1] + a[j3];
    REAL x2i = a[j1 + 1] + a[j3 + 1];
    REAL x3r = a[j1] - a[j3];
    REAL x3i = a[j1 + 1] - a[j3 + 1];
    a[0] = x0r + x2r;
    a[1] = x0i + x2i;
    a[j1] = x0r - x2r;
    a[j1 + 1] = x0i - x2i;
    a[j2] = x1r - x3i;
    a[j2 + 1] = x1i + x3r;
    a[j3] = x1r + x3i;
    a[j3 + 1] = x1i - x3r;
    REAL wn4r = w[1];
    REAL csc1 = w[2];
    REAL csc3 = w[3];
    REAL wd1r = 1;
    REAL wd1i = 0;
    REAL wd3r = 1;
    REAL wd3i = 0;
    k = 0;
    for (j = 2; j < mh - 2; j += 4) {
        k += 4;
        REAL wk1r = csc1 * (wd1r + w[k]);
        REAL wk1i = csc1 * (wd1i + w[k + 1]);
        REAL wk3r = csc3 * (wd3r + w[k + 2]);
        REAL wk3i = csc3 * (wd3i + w[k + 3]);
        wd1r = w[k];
        wd1i = w[k + 1];
        wd3r = w[k + 2];
        wd3i = w[k + 3];
        j1 = j + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j] + a[j2];
        x0i = a[j + 1] + a[j2 + 1];
        x1r = a[j] - a[j2];
        x1i = a[j + 1] - a[j2 + 1];
        REAL y0r = a[j + 2] + a[j2 + 2];
        REAL y0i = a[j + 3] + a[j2 + 3];
        REAL y1r = a[j + 2] - a[j2 + 2];
        REAL y1i = a[j + 3] - a[j2 + 3];
        x2r = a[j1] + a[j3];
        x2i = a[j1 + 1] + a[j3 + 1];
        x3r = a[j1] - a[j3];
        x3i = a[j1 + 1] - a[j3 + 1];
        REAL y2r = a[j1 + 2] + a[j3 + 2];
        REAL y2i = a[j1 + 3] + a[j3 + 3];
        REAL y3r = a[j1 + 2] - a[j3 + 2];
        REAL y3i = a[j1 + 3] - a[j3 + 3];
        a[j] = x0r + x2r;
        a[j + 1] = x0i + x2i;
        a[j + 2] = y0r + y2r;
        a[j + 3] = y0i + y2i;
        a[j1] = x0r - x2r;
        a[j1 + 1] = x0i - x2i;
        a[j1 + 2] = y0r - y2r;
        a[j1 + 3] = y0i - y2i;
        x0r = x1r - x3i;
        x0i = x1i + x3r;
        a[j2] = wk1r * x0r - wk1i * x0i;
        a[j2 + 1] = wk1r * x0i + wk1i * x0r;
        x0r = y1r - y3i;
        x0i = y1i + y3r;
        a[j2 + 2] = wd1r * x0r - wd1i * x0i;
        a[j2 + 3] = wd1r * x0i + wd1i * x0r;
        x0r = x1r + x3i;
        x0i = x1i - x3r;
        a[j3] = wk3r * x0r + wk3i * x0i;
        a[j3 + 1] = wk3r * x0i - wk3i * x0r;
        x0r = y1r + y3i;
        x0i = y1i - y3r;
        a[j3 + 2] = wd3r * x0r + wd3i * x0i;
        a[j3 + 3] = wd3r * x0i - wd3i * x0r;
        j0 = m - j;
        j1 = j0 + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j0] + a[j2];
        x0i = a[j0 + 1] + a[j2 + 1];
        x1r = a[j0] - a[j2];
        x1i = a[j0 + 1] - a[j2 + 1];
        y0r = a[j0 - 2] + a[j2 - 2];
        y0i = a[j0 - 1] + a[j2 - 1];
        y1r = a[j0 - 2] - a[j2 - 2];
        y1i = a[j0 - 1] - a[j2 - 1];
        x2r = a[j1] + a[j3];
        x2i = a[j1 + 1] + a[j3 + 1];
        x3r = a[j1] - a[j3];
        x3i = a[j1 + 1] - a[j3 + 1];
        y2r = a[j1 - 2] + a[j3 - 2];
        y2i = a[j1 - 1] + a[j3 - 1];
        y3r = a[j1 - 2] - a[j3 - 2];
        y3i = a[j1 - 1] - a[j3 - 1];
        a[j0] = x0r + x2r;
        a[j0 + 1] = x0i + x2i;
        a[j0 - 2] = y0r + y2r;
        a[j0 - 1] = y0i + y2i;
        a[j1] = x0r - x2r;
        a[j1 + 1] = x0i - x2i;
        a[j1 - 2] = y0r - y2r;
        a[j1 - 1] = y0i - y2i;
        x0r = x1r - x3i;
        x0i = x1i + x3r;
        a[j2] = wk1i * x0r - wk1r * x0i;
        a[j2 + 1] = wk1i * x0i + wk1r * x0r;
        x0r = y1r - y3i;
        x0i = y1i + y3r;
        a[j2 - 2] = wd1i * x0r - wd1r * x0i;
        a[j2 - 1] = wd1i * x0i + wd1r * x0r;
        x0r = x1r + x3i;
        x0i = x1i - x3r;
        a[j3] = wk3i * x0r + wk3r * x0i;
        a[j3 + 1] = wk3i * x0i - wk3r * x0r;
        x0r = y1r + y3i;
        x0i = y1i - y3r;
        a[j3 - 2] = wd3i * x0r + wd3r * x0i;
        a[j3 - 1] = wd3i * x0i - wd3r * x0r;
    }
    REAL wk1r = csc1 * (wd1r + wn4r);
    REAL wk1i = csc1 * (wd1i + wn4r);
    REAL wk3r = csc3 * (wd3r - wn4r);
    REAL wk3i = csc3 * (wd3i - wn4r);
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    x0r = a[j0 - 2] + a[j2 - 2];
    x0i = a[j0 - 1] + a[j2 - 1];
    x1r = a[j0 - 2] - a[j2 - 2];
    x1i = a[j0 - 1] - a[j2 - 1];
    x2r = a[j1 - 2] + a[j3 - 2];
    x2i = a[j1 - 1] + a[j3 - 1];
    x3r = a[j1 - 2] - a[j3 - 2];
    x3i = a[j1 - 1] - a[j3 - 1];
    a[j0 - 2] = x0r + x2r;
    a[j0 - 1] = x0i + x2i;
    a[j1 - 2] = x0r - x2r;
    a[j1 - 1] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[j2 - 2] = wk1r * x0r - wk1i * x0i;
    a[j2 - 1] = wk1r * x0i + wk1i * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[j3 - 2] = wk3r * x0r + wk3i * x0i;
    a[j3 - 1] = wk3r * x0i - wk3i * x0r;
    x0r = a[j0] + a[j2];
    x0i = a[j0 + 1] + a[j2 + 1];
    x1r = a[j0] - a[j2];
    x1i = a[j0 + 1] - a[j2 + 1];
    x2r = a[j1] + a[j3];
    x2i = a[j1 + 1] + a[j3 + 1];
    x3r = a[j1] - a[j3];
    x3i = a[j1 + 1] - a[j3 + 1];
    a[j0] = x0r + x2r;
    a[j0 + 1] = x0i + x2i;
    a[j1] = x0r - x2r;
    a[j1 + 1] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[j2] = wn4r * (x0r - x0i);
    a[j2 + 1] = wn4r * (x0i + x0r);
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[j3] = -wn4r * (x0r + x0i);
    a[j3 + 1] = -wn4r * (x0i - x0r);
    x0r = a[j0 + 2] + a[j2 + 2];
    x0i = a[j0 + 3] + a[j2 + 3];
    x1r = a[j0 + 2] - a[j2 + 2];
    x1i = a[j0 + 3] - a[j2 + 3];
    x2r = a[j1 + 2] + a[j3 + 2];
    x2i = a[j1 + 3] + a[j3 + 3];
    x3r = a[j1 + 2] - a[j3 + 2];
    x3i = a[j1 + 3] - a[j3 + 3];
    a[j0 + 2] = x0r + x2r;
    a[j0 + 3] = x0i + x2i;
    a[j1 + 2] = x0r - x2r;
    a[j1 + 3] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[j2 + 2] = wk1i * x0r - wk1r * x0i;
    a[j2 + 3] = wk1i * x0i + wk1r * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[j3 + 2] = wk3i * x0r + wk3r * x0i;
    a[j3 + 3] = wk3i * x0i - wk3r * x0r;
}


void cftb1st(int n, REAL *a, REAL *w)
{
    int j, j0, j1, j2, j3, k, m, mh;
    //REAL wn4r, csc1, csc3, wk1r, wk1i, wk3r, wk3i, wd1r, wd1i, wd3r, wd3i;
    //REAL x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i, y0r, y0i, y1r, y1i, y2r, y2i, y3r, y3i;

    mh = n >> 3;
    m = 2 * mh;
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    REAL x0r = a[0] + a[j2];
    REAL x0i = -a[1] - a[j2 + 1];
    REAL x1r = a[0] - a[j2];
    REAL x1i = -a[1] + a[j2 + 1];
    REAL x2r = a[j1] + a[j3];
    REAL x2i = a[j1 + 1] + a[j3 + 1];
    REAL x3r = a[j1] - a[j3];
    REAL x3i = a[j1 + 1] - a[j3 + 1];
    a[0] = x0r + x2r;
    a[1] = x0i - x2i;
    a[j1] = x0r - x2r;
    a[j1 + 1] = x0i + x2i;
    a[j2] = x1r + x3i;
    a[j2 + 1] = x1i + x3r;
    a[j3] = x1r - x3i;
    a[j3 + 1] = x1i - x3r;
    REAL wn4r = w[1];
    REAL csc1 = w[2];
    REAL csc3 = w[3];
    REAL wd1r = 1;
    REAL wd1i = 0;
    REAL wd3r = 1;
    REAL wd3i = 0;
    k = 0;
    for (j = 2; j < mh - 2; j += 4) {
        k += 4;
        REAL wk1r = csc1 * (wd1r + w[k]);
        REAL wk1i = csc1 * (wd1i + w[k + 1]);
        REAL wk3r = csc3 * (wd3r + w[k + 2]);
        REAL wk3i = csc3 * (wd3i + w[k + 3]);
        wd1r = w[k];
        wd1i = w[k + 1];
        wd3r = w[k + 2];
        wd3i = w[k + 3];
        j1 = j + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j] + a[j2];
        x0i = -a[j + 1] - a[j2 + 1];
        x1r = a[j] - a[j2];
        x1i = -a[j + 1] + a[j2 + 1];
        REAL y0r = a[j + 2] + a[j2 + 2];
        REAL y0i = -a[j + 3] - a[j2 + 3];
        REAL y1r = a[j + 2] - a[j2 + 2];
        REAL y1i = -a[j + 3] + a[j2 + 3];
        x2r = a[j1] + a[j3];
        x2i = a[j1 + 1] + a[j3 + 1];
        x3r = a[j1] - a[j3];
        x3i = a[j1 + 1] - a[j3 + 1];
        REAL y2r = a[j1 + 2] + a[j3 + 2];
        REAL y2i = a[j1 + 3] + a[j3 + 3];
        REAL y3r = a[j1 + 2] - a[j3 + 2];
        REAL y3i = a[j1 + 3] - a[j3 + 3];
        a[j] = x0r + x2r;
        a[j + 1] = x0i - x2i;
        a[j + 2] = y0r + y2r;
        a[j + 3] = y0i - y2i;
        a[j1] = x0r - x2r;
        a[j1 + 1] = x0i + x2i;
        a[j1 + 2] = y0r - y2r;
        a[j1 + 3] = y0i + y2i;
        x0r = x1r + x3i;
        x0i = x1i + x3r;
        a[j2] = wk1r * x0r - wk1i * x0i;
        a[j2 + 1] = wk1r * x0i + wk1i * x0r;
        x0r = y1r + y3i;
        x0i = y1i + y3r;
        a[j2 + 2] = wd1r * x0r - wd1i * x0i;
        a[j2 + 3] = wd1r * x0i + wd1i * x0r;
        x0r = x1r - x3i;
        x0i = x1i - x3r;
        a[j3] = wk3r * x0r + wk3i * x0i;
        a[j3 + 1] = wk3r * x0i - wk3i * x0r;
        x0r = y1r - y3i;
        x0i = y1i - y3r;
        a[j3 + 2] = wd3r * x0r + wd3i * x0i;
        a[j3 + 3] = wd3r * x0i - wd3i * x0r;
        j0 = m - j;
        j1 = j0 + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j0] + a[j2];
        x0i = -a[j0 + 1] - a[j2 + 1];
        x1r = a[j0] - a[j2];
        x1i = -a[j0 + 1] + a[j2 + 1];
        y0r = a[j0 - 2] + a[j2 - 2];
        y0i = -a[j0 - 1] - a[j2 - 1];
        y1r = a[j0 - 2] - a[j2 - 2];
        y1i = -a[j0 - 1] + a[j2 - 1];
        x2r = a[j1] + a[j3];
        x2i = a[j1 + 1] + a[j3 + 1];
        x3r = a[j1] - a[j3];
        x3i = a[j1 + 1] - a[j3 + 1];
        y2r = a[j1 - 2] + a[j3 - 2];
        y2i = a[j1 - 1] + a[j3 - 1];
        y3r = a[j1 - 2] - a[j3 - 2];
        y3i = a[j1 - 1] - a[j3 - 1];
        a[j0] = x0r + x2r;
        a[j0 + 1] = x0i - x2i;
        a[j0 - 2] = y0r + y2r;
        a[j0 - 1] = y0i - y2i;
        a[j1] = x0r - x2r;
        a[j1 + 1] = x0i + x2i;
        a[j1 - 2] = y0r - y2r;
        a[j1 - 1] = y0i + y2i;
        x0r = x1r + x3i;
        x0i = x1i + x3r;
        a[j2] = wk1i * x0r - wk1r * x0i;
        a[j2 + 1] = wk1i * x0i + wk1r * x0r;
        x0r = y1r + y3i;
        x0i = y1i + y3r;
        a[j2 - 2] = wd1i * x0r - wd1r * x0i;
        a[j2 - 1] = wd1i * x0i + wd1r * x0r;
        x0r = x1r - x3i;
        x0i = x1i - x3r;
        a[j3] = wk3i * x0r + wk3r * x0i;
        a[j3 + 1] = wk3i * x0i - wk3r * x0r;
        x0r = y1r - y3i;
        x0i = y1i - y3r;
        a[j3 - 2] = wd3i * x0r + wd3r * x0i;
        a[j3 - 1] = wd3i * x0i - wd3r * x0r;
    }
    REAL wk1r = csc1 * (wd1r + wn4r);
    REAL wk1i = csc1 * (wd1i + wn4r);
    REAL wk3r = csc3 * (wd3r - wn4r);
    REAL wk3i = csc3 * (wd3i - wn4r);
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    x0r = a[j0 - 2] + a[j2 - 2];
    x0i = -a[j0 - 1] - a[j2 - 1];
    x1r = a[j0 - 2] - a[j2 - 2];
    x1i = -a[j0 - 1] + a[j2 - 1];
    x2r = a[j1 - 2] + a[j3 - 2];
    x2i = a[j1 - 1] + a[j3 - 1];
    x3r = a[j1 - 2] - a[j3 - 2];
    x3i = a[j1 - 1] - a[j3 - 1];
    a[j0 - 2] = x0r + x2r;
    a[j0 - 1] = x0i - x2i;
    a[j1 - 2] = x0r - x2r;
    a[j1 - 1] = x0i + x2i;
    x0r = x1r + x3i;
    x0i = x1i + x3r;
    a[j2 - 2] = wk1r * x0r - wk1i * x0i;
    a[j2 - 1] = wk1r * x0i + wk1i * x0r;
    x0r = x1r - x3i;
    x0i = x1i - x3r;
    a[j3 - 2] = wk3r * x0r + wk3i * x0i;
    a[j3 - 1] = wk3r * x0i - wk3i * x0r;
    x0r = a[j0] + a[j2];
    x0i = -a[j0 + 1] - a[j2 + 1];
    x1r = a[j0] - a[j2];
    x1i = -a[j0 + 1] + a[j2 + 1];
    x2r = a[j1] + a[j3];
    x2i = a[j1 + 1] + a[j3 + 1];
    x3r = a[j1] - a[j3];
    x3i = a[j1 + 1] - a[j3 + 1];
    a[j0] = x0r + x2r;
    a[j0 + 1] = x0i - x2i;
    a[j1] = x0r - x2r;
    a[j1 + 1] = x0i + x2i;
    x0r = x1r + x3i;
    x0i = x1i + x3r;
    a[j2] = wn4r * (x0r - x0i);
    a[j2 + 1] = wn4r * (x0i + x0r);
    x0r = x1r - x3i;
    x0i = x1i - x3r;
    a[j3] = -wn4r * (x0r + x0i);
    a[j3 + 1] = -wn4r * (x0i - x0r);
    x0r = a[j0 + 2] + a[j2 + 2];
    x0i = -a[j0 + 3] - a[j2 + 3];
    x1r = a[j0 + 2] - a[j2 + 2];
    x1i = -a[j0 + 3] + a[j2 + 3];
    x2r = a[j1 + 2] + a[j3 + 2];
    x2i = a[j1 + 3] + a[j3 + 3];
    x3r = a[j1 + 2] - a[j3 + 2];
    x3i = a[j1 + 3] - a[j3 + 3];
    a[j0 + 2] = x0r + x2r;
    a[j0 + 3] = x0i - x2i;
    a[j1 + 2] = x0r - x2r;
    a[j1 + 3] = x0i + x2i;
    x0r = x1r + x3i;
    x0i = x1i + x3r;
    a[j2 + 2] = wk1i * x0r - wk1r * x0i;
    a[j2 + 3] = wk1i * x0i + wk1r * x0r;
    x0r = x1r - x3i;
    x0i = x1i - x3r;
    a[j3 + 2] = wk3i * x0r + wk3r * x0i;
    a[j3 + 3] = wk3i * x0i - wk3r * x0r;
}


void cftrec4(int n, REAL *a, int nw, REAL *w)
{
    int isplt, j, k, m;

    m = n;
    while (m > 512) {
        m >>= 2;
        cftmdl1(m, &a[n - m], &w[nw - (m >> 1)]);
    }
    cftleaf(m, 1, &a[n - m], nw, w);
    k = 0;
    for (j = n - m; j > 0; j -= m) {
        k++;
        isplt = cfttree(m, j, k, a, nw, w);
        cftleaf(m, isplt, &a[j - m], nw, w);
    }
}


int cfttree(int n, int j, int k, REAL *a, int nw, REAL *w)
{
    int i, isplt, m;

    if ((k & 3) != 0) {
        isplt = k & 1;
        if (isplt != 0) {
            cftmdl1(n, &a[j - n], &w[nw - (n >> 1)]);
        } else {
            cftmdl2(n, &a[j - n], &w[nw - n]);
        }
    } else {
        m = n;
        for (i = k; (i & 3) == 0; i >>= 2) {
            m <<= 2;
        }
        isplt = i & 1;
        if (isplt != 0) {
            while (m > 128) {
                cftmdl1(m, &a[j - m], &w[nw - (m >> 1)]);
                m >>= 2;
            }
        } else {
            while (m > 128) {
                cftmdl2(m, &a[j - m], &w[nw - m]);
                m >>= 2;
            }
        }
    }
    return isplt;
}


void cftleaf(int n, int isplt, REAL *a, int nw, REAL *w)
{
    if (n == 512) {
        cftmdl1(128, a, &w[nw - 64]);
        cftf161(a, &w[nw - 8]);
        cftf162(&a[32], &w[nw - 32]);
        cftf161(&a[64], &w[nw - 8]);
        cftf161(&a[96], &w[nw - 8]);
        cftmdl2(128, &a[128], &w[nw - 128]);
        cftf161(&a[128], &w[nw - 8]);
        cftf162(&a[160], &w[nw - 32]);
        cftf161(&a[192], &w[nw - 8]);
        cftf162(&a[224], &w[nw - 32]);
        cftmdl1(128, &a[256], &w[nw - 64]);
        cftf161(&a[256], &w[nw - 8]);
        cftf162(&a[288], &w[nw - 32]);
        cftf161(&a[320], &w[nw - 8]);
        cftf161(&a[352], &w[nw - 8]);
        if (isplt != 0) {
            cftmdl1(128, &a[384], &w[nw - 64]);
            cftf161(&a[480], &w[nw - 8]);
        } else {
            cftmdl2(128, &a[384], &w[nw - 128]);
            cftf162(&a[480], &w[nw - 32]);
        }
        cftf161(&a[384], &w[nw - 8]);
        cftf162(&a[416], &w[nw - 32]);
        cftf161(&a[448], &w[nw - 8]);
    } else {
        cftmdl1(64, a, &w[nw - 32]);
        cftf081(a, &w[nw - 8]);
        cftf082(&a[16], &w[nw - 8]);
        cftf081(&a[32], &w[nw - 8]);
        cftf081(&a[48], &w[nw - 8]);
        cftmdl2(64, &a[64], &w[nw - 64]);
        cftf081(&a[64], &w[nw - 8]);
        cftf082(&a[80], &w[nw - 8]);
        cftf081(&a[96], &w[nw - 8]);
        cftf082(&a[112], &w[nw - 8]);
        cftmdl1(64, &a[128], &w[nw - 32]);
        cftf081(&a[128], &w[nw - 8]);
        cftf082(&a[144], &w[nw - 8]);
        cftf081(&a[160], &w[nw - 8]);
        cftf081(&a[176], &w[nw - 8]);
        if (isplt != 0) {
            cftmdl1(64, &a[192], &w[nw - 32]);
            cftf081(&a[240], &w[nw - 8]);
        } else {
            cftmdl2(64, &a[192], &w[nw - 64]);
            cftf082(&a[240], &w[nw - 8]);
        }
        cftf081(&a[192], &w[nw - 8]);
        cftf082(&a[208], &w[nw - 8]);
        cftf081(&a[224], &w[nw - 8]);
    }
}


void cftmdl1(int n, REAL *a, REAL *w)
{
    int j, j0, j1, j2, j3, k, m, mh;
    //REAL wn4r, wk1r, wk1i, wk3r, wk3i;
    //REAL x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i;

    mh = n >> 3;
    m = 2 * mh;
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    REAL x0r = a[0] + a[j2];
    REAL x0i = a[1] + a[j2 + 1];
    REAL x1r = a[0] - a[j2];
    REAL x1i = a[1] - a[j2 + 1];
    REAL x2r = a[j1] + a[j3];
    REAL x2i = a[j1 + 1] + a[j3 + 1];
    REAL x3r = a[j1] - a[j3];
    REAL x3i = a[j1 + 1] - a[j3 + 1];
    a[0] = x0r + x2r;
    a[1] = x0i + x2i;
    a[j1] = x0r - x2r;
    a[j1 + 1] = x0i - x2i;
    a[j2] = x1r - x3i;
    a[j2 + 1] = x1i + x3r;
    a[j3] = x1r + x3i;
    a[j3 + 1] = x1i - x3r;
    REAL wn4r = w[1];
    k = 0;
    for (j = 2; j < mh; j += 2) {
        k += 4;
        REAL wk1r = w[k];
        REAL wk1i = w[k + 1];
        REAL wk3r = w[k + 2];
        REAL wk3i = w[k + 3];
        j1 = j + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j] + a[j2];
        x0i = a[j + 1] + a[j2 + 1];
        x1r = a[j] - a[j2];
        x1i = a[j + 1] - a[j2 + 1];
        x2r = a[j1] + a[j3];
        x2i = a[j1 + 1] + a[j3 + 1];
        x3r = a[j1] - a[j3];
        x3i = a[j1 + 1] - a[j3 + 1];
        a[j] = x0r + x2r;
        a[j + 1] = x0i + x2i;
        a[j1] = x0r - x2r;
        a[j1 + 1] = x0i - x2i;
        x0r = x1r - x3i;
        x0i = x1i + x3r;
        a[j2] = wk1r * x0r - wk1i * x0i;
        a[j2 + 1] = wk1r * x0i + wk1i * x0r;
        x0r = x1r + x3i;
        x0i = x1i - x3r;
        a[j3] = wk3r * x0r + wk3i * x0i;
        a[j3 + 1] = wk3r * x0i - wk3i * x0r;
        j0 = m - j;
        j1 = j0 + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j0] + a[j2];
        x0i = a[j0 + 1] + a[j2 + 1];
        x1r = a[j0] - a[j2];
        x1i = a[j0 + 1] - a[j2 + 1];
        x2r = a[j1] + a[j3];
        x2i = a[j1 + 1] + a[j3 + 1];
        x3r = a[j1] - a[j3];
        x3i = a[j1 + 1] - a[j3 + 1];
        a[j0] = x0r + x2r;
        a[j0 + 1] = x0i + x2i;
        a[j1] = x0r - x2r;
        a[j1 + 1] = x0i - x2i;
        x0r = x1r - x3i;
        x0i = x1i + x3r;
        a[j2] = wk1i * x0r - wk1r * x0i;
        a[j2 + 1] = wk1i * x0i + wk1r * x0r;
        x0r = x1r + x3i;
        x0i = x1i - x3r;
        a[j3] = wk3i * x0r + wk3r * x0i;
        a[j3 + 1] = wk3i * x0i - wk3r * x0r;
    }
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    x0r = a[j0] + a[j2];
    x0i = a[j0 + 1] + a[j2 + 1];
    x1r = a[j0] - a[j2];
    x1i = a[j0 + 1] - a[j2 + 1];
    x2r = a[j1] + a[j3];
    x2i = a[j1 + 1] + a[j3 + 1];
    x3r = a[j1] - a[j3];
    x3i = a[j1 + 1] - a[j3 + 1];
    a[j0] = x0r + x2r;
    a[j0 + 1] = x0i + x2i;
    a[j1] = x0r - x2r;
    a[j1 + 1] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[j2] = wn4r * (x0r - x0i);
    a[j2 + 1] = wn4r * (x0i + x0r);
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[j3] = -wn4r * (x0r + x0i);
    a[j3 + 1] = -wn4r * (x0i - x0r);
}


void cftmdl2(int n, REAL *a, REAL *w)
{
    int j, j0, j1, j2, j3, k, kr, m, mh;
    //REAL wn4r, wk1r, wk1i, wk3r, wk3i, wd1r, wd1i, wd3r, wd3i;
    //REAL x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i, y0r, y0i, y2r, y2i;

    mh = n >> 3;
    m = 2 * mh;
    REAL wn4r = w[1];
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    REAL x0r = a[0] - a[j2 + 1];
    REAL x0i = a[1] + a[j2];
    REAL x1r = a[0] + a[j2 + 1];
    REAL x1i = a[1] - a[j2];
    REAL x2r = a[j1] - a[j3 + 1];
    REAL x2i = a[j1 + 1] + a[j3];
    REAL x3r = a[j1] + a[j3 + 1];
    REAL x3i = a[j1 + 1] - a[j3];
    REAL y0r = wn4r * (x2r - x2i);
    REAL y0i = wn4r * (x2i + x2r);
    a[0] = x0r + y0r;
    a[1] = x0i + y0i;
    a[j1] = x0r - y0r;
    a[j1 + 1] = x0i - y0i;
    y0r = wn4r * (x3r - x3i);
    y0i = wn4r * (x3i + x3r);
    a[j2] = x1r - y0i;
    a[j2 + 1] = x1i + y0r;
    a[j3] = x1r + y0i;
    a[j3 + 1] = x1i - y0r;
    k = 0;
    kr = 2 * m;
    for (j = 2; j < mh; j += 2) {
        k += 4;
        REAL wk1r = w[k];
        REAL wk1i = w[k + 1];
        REAL wk3r = w[k + 2];
        REAL wk3i = w[k + 3];
        kr -= 4;
        REAL wd1i = w[kr];
        REAL wd1r = w[kr + 1];
        REAL wd3i = w[kr + 2];
        REAL wd3r = w[kr + 3];
        j1 = j + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j] - a[j2 + 1];
        x0i = a[j + 1] + a[j2];
        x1r = a[j] + a[j2 + 1];
        x1i = a[j + 1] - a[j2];
        x2r = a[j1] - a[j3 + 1];
        x2i = a[j1 + 1] + a[j3];
        x3r = a[j1] + a[j3 + 1];
        x3i = a[j1 + 1] - a[j3];
        y0r = wk1r * x0r - wk1i * x0i;
        y0i = wk1r * x0i + wk1i * x0r;
        REAL y2r = wd1r * x2r - wd1i * x2i;
        REAL y2i = wd1r * x2i + wd1i * x2r;
        a[j] = y0r + y2r;
        a[j + 1] = y0i + y2i;
        a[j1] = y0r - y2r;
        a[j1 + 1] = y0i - y2i;
        y0r = wk3r * x1r + wk3i * x1i;
        y0i = wk3r * x1i - wk3i * x1r;
        y2r = wd3r * x3r + wd3i * x3i;
        y2i = wd3r * x3i - wd3i * x3r;
        a[j2] = y0r + y2r;
        a[j2 + 1] = y0i + y2i;
        a[j3] = y0r - y2r;
        a[j3 + 1] = y0i - y2i;
        j0 = m - j;
        j1 = j0 + m;
        j2 = j1 + m;
        j3 = j2 + m;
        x0r = a[j0] - a[j2 + 1];
        x0i = a[j0 + 1] + a[j2];
        x1r = a[j0] + a[j2 + 1];
        x1i = a[j0 + 1] - a[j2];
        x2r = a[j1] - a[j3 + 1];
        x2i = a[j1 + 1] + a[j3];
        x3r = a[j1] + a[j3 + 1];
        x3i = a[j1 + 1] - a[j3];
        y0r = wd1i * x0r - wd1r * x0i;
        y0i = wd1i * x0i + wd1r * x0r;
        y2r = wk1i * x2r - wk1r * x2i;
        y2i = wk1i * x2i + wk1r * x2r;
        a[j0] = y0r + y2r;
        a[j0 + 1] = y0i + y2i;
        a[j1] = y0r - y2r;
        a[j1 + 1] = y0i - y2i;
        y0r = wd3i * x1r + wd3r * x1i;
        y0i = wd3i * x1i - wd3r * x1r;
        y2r = wk3i * x3r + wk3r * x3i;
        y2i = wk3i * x3i - wk3r * x3r;
        a[j2] = y0r + y2r;
        a[j2 + 1] = y0i + y2i;
        a[j3] = y0r - y2r;
        a[j3 + 1] = y0i - y2i;
    }
    REAL wk1r = w[m];
    REAL wk1i = w[m + 1];
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    x0r = a[j0] - a[j2 + 1];
    x0i = a[j0 + 1] + a[j2];
    x1r = a[j0] + a[j2 + 1];
    x1i = a[j0 + 1] - a[j2];
    x2r = a[j1] - a[j3 + 1];
    x2i = a[j1 + 1] + a[j3];
    x3r = a[j1] + a[j3 + 1];
    x3i = a[j1 + 1] - a[j3];
    y0r = wk1r * x0r - wk1i * x0i;
    y0i = wk1r * x0i + wk1i * x0r;
    REAL y2r = wk1i * x2r - wk1r * x2i;
    REAL y2i = wk1i * x2i + wk1r * x2r;
    a[j0] = y0r + y2r;
    a[j0 + 1] = y0i + y2i;
    a[j1] = y0r - y2r;
    a[j1 + 1] = y0i - y2i;
    y0r = wk1i * x1r - wk1r * x1i;
    y0i = wk1i * x1i + wk1r * x1r;
    y2r = wk1r * x3r - wk1i * x3i;
    y2i = wk1r * x3i + wk1i * x3r;
    a[j2] = y0r - y2r;
    a[j2 + 1] = y0i - y2i;
    a[j3] = y0r + y2r;
    a[j3 + 1] = y0i + y2i;
}


void cftfx41(int n, REAL *a, int nw, REAL *w)
{
    if (n == 128) {
        cftf161(a, &w[nw - 8]);
        cftf162(&a[32], &w[nw - 32]);
        cftf161(&a[64], &w[nw - 8]);
        cftf161(&a[96], &w[nw - 8]);
    } else {
        cftf081(a, &w[nw - 8]);
        cftf082(&a[16], &w[nw - 8]);
        cftf081(&a[32], &w[nw - 8]);
        cftf081(&a[48], &w[nw - 8]);
    }
}


void cftf161(REAL *a, REAL *w)
{
    /*
    REAL wn4r, wk1r, wk1i,
        x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i,
        y0r, y0i, y1r, y1i, y2r, y2i, y3r, y3i,
        y4r, y4i, y5r, y5i, y6r, y6i, y7r, y7i,
        y8r, y8i, y9r, y9i, y10r, y10i, y11r, y11i,
        y12r, y12i, y13r, y13i, y14r, y14i, y15r, y15i;
    */
    REAL wn4r = w[1];
    REAL wk1r = w[2];
    REAL wk1i = w[3];
    REAL x0r = a[0] + a[16];
    REAL x0i = a[1] + a[17];
    REAL x1r = a[0] - a[16];
    REAL x1i = a[1] - a[17];
    REAL x2r = a[8] + a[24];
    REAL x2i = a[9] + a[25];
    REAL x3r = a[8] - a[24];
    REAL x3i = a[9] - a[25];
    REAL y0r = x0r + x2r;
    REAL y0i = x0i + x2i;
    REAL y4r = x0r - x2r;
    REAL y4i = x0i - x2i;
    REAL y8r = x1r - x3i;
    REAL y8i = x1i + x3r;
    REAL y12r = x1r + x3i;
    REAL y12i = x1i - x3r;
    x0r = a[2] + a[18];
    x0i = a[3] + a[19];
    x1r = a[2] - a[18];
    x1i = a[3] - a[19];
    x2r = a[10] + a[26];
    x2i = a[11] + a[27];
    x3r = a[10] - a[26];
    x3i = a[11] - a[27];
    REAL y1r = x0r + x2r;
    REAL y1i = x0i + x2i;
    REAL y5r = x0r - x2r;
    REAL y5i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    REAL y9r = wk1r * x0r - wk1i * x0i;
    REAL y9i = wk1r * x0i + wk1i * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    REAL y13r = wk1i * x0r - wk1r * x0i;
    REAL y13i = wk1i * x0i + wk1r * x0r;
    x0r = a[4] + a[20];
    x0i = a[5] + a[21];
    x1r = a[4] - a[20];
    x1i = a[5] - a[21];
    x2r = a[12] + a[28];
    x2i = a[13] + a[29];
    x3r = a[12] - a[28];
    x3i = a[13] - a[29];
    REAL y2r = x0r + x2r;
    REAL y2i = x0i + x2i;
    REAL y6r = x0r - x2r;
    REAL y6i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    REAL y10r = wn4r * (x0r - x0i);
    REAL y10i = wn4r * (x0i + x0r);
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    REAL y14r = wn4r * (x0r + x0i);
    REAL y14i = wn4r * (x0i - x0r);
    x0r = a[6] + a[22];
    x0i = a[7] + a[23];
    x1r = a[6] - a[22];
    x1i = a[7] - a[23];
    x2r = a[14] + a[30];
    x2i = a[15] + a[31];
    x3r = a[14] - a[30];
    x3i = a[15] - a[31];
    REAL y3r = x0r + x2r;
    REAL y3i = x0i + x2i;
    REAL y7r = x0r - x2r;
    REAL y7i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    REAL y11r = wk1i * x0r - wk1r * x0i;
    REAL y11i = wk1i * x0i + wk1r * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    REAL y15r = wk1r * x0r - wk1i * x0i;
    REAL y15i = wk1r * x0i + wk1i * x0r;
    x0r = y12r - y14r;
    x0i = y12i - y14i;
    x1r = y12r + y14r;
    x1i = y12i + y14i;
    x2r = y13r - y15r;
    x2i = y13i - y15i;
    x3r = y13r + y15r;
    x3i = y13i + y15i;
    a[24] = x0r + x2r;
    a[25] = x0i + x2i;
    a[26] = x0r - x2r;
    a[27] = x0i - x2i;
    a[28] = x1r - x3i;
    a[29] = x1i + x3r;
    a[30] = x1r + x3i;
    a[31] = x1i - x3r;
    x0r = y8r + y10r;
    x0i = y8i + y10i;
    x1r = y8r - y10r;
    x1i = y8i - y10i;
    x2r = y9r + y11r;
    x2i = y9i + y11i;
    x3r = y9r - y11r;
    x3i = y9i - y11i;
    a[16] = x0r + x2r;
    a[17] = x0i + x2i;
    a[18] = x0r - x2r;
    a[19] = x0i - x2i;
    a[20] = x1r - x3i;
    a[21] = x1i + x3r;
    a[22] = x1r + x3i;
    a[23] = x1i - x3r;
    x0r = y5r - y7i;
    x0i = y5i + y7r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    x0r = y5r + y7i;
    x0i = y5i - y7r;
    x3r = wn4r * (x0r - x0i);
    x3i = wn4r * (x0i + x0r);
    x0r = y4r - y6i;
    x0i = y4i + y6r;
    x1r = y4r + y6i;
    x1i = y4i - y6r;
    a[8] = x0r + x2r;
    a[9] = x0i + x2i;
    a[10] = x0r - x2r;
    a[11] = x0i - x2i;
    a[12] = x1r - x3i;
    a[13] = x1i + x3r;
    a[14] = x1r + x3i;
    a[15] = x1i - x3r;
    x0r = y0r + y2r;
    x0i = y0i + y2i;
    x1r = y0r - y2r;
    x1i = y0i - y2i;
    x2r = y1r + y3r;
    x2i = y1i + y3i;
    x3r = y1r - y3r;
    x3i = y1i - y3i;
    a[0] = x0r + x2r;
    a[1] = x0i + x2i;
    a[2] = x0r - x2r;
    a[3] = x0i - x2i;
    a[4] = x1r - x3i;
    a[5] = x1i + x3r;
    a[6] = x1r + x3i;
    a[7] = x1i - x3r;
}


void cftf162(REAL *a, REAL *w)
{
    /*
    REAL wn4r, wk1r, wk1i, wk2r, wk2i, wk3r, wk3i,
        x0r, x0i, x1r, x1i, x2r, x2i,
        y0r, y0i, y1r, y1i, y2r, y2i, y3r, y3i,
        y4r, y4i, y5r, y5i, y6r, y6i, y7r, y7i,
        y8r, y8i, y9r, y9i, y10r, y10i, y11r, y11i,
        y12r, y12i, y13r, y13i, y14r, y14i, y15r, y15i;
    */
    REAL wn4r = w[1];
    REAL wk1r = w[4];
    REAL wk1i = w[5];
    REAL wk3r = w[6];
    REAL wk3i = -w[7];
    REAL wk2r = w[8];
    REAL wk2i = w[9];
    REAL x1r = a[0] - a[17];
    REAL x1i = a[1] + a[16];
    REAL x0r = a[8] - a[25];
    REAL x0i = a[9] + a[24];
    REAL x2r = wn4r * (x0r - x0i);
    REAL x2i = wn4r * (x0i + x0r);
    REAL y0r = x1r + x2r;
    REAL y0i = x1i + x2i;
    REAL y4r = x1r - x2r;
    REAL y4i = x1i - x2i;
    x1r = a[0] + a[17];
    x1i = a[1] - a[16];
    x0r = a[8] + a[25];
    x0i = a[9] - a[24];
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    REAL y8r = x1r - x2i;
    REAL y8i = x1i + x2r;
    REAL y12r = x1r + x2i;
    REAL y12i = x1i - x2r;
    x0r = a[2] - a[19];
    x0i = a[3] + a[18];
    x1r = wk1r * x0r - wk1i * x0i;
    x1i = wk1r * x0i + wk1i * x0r;
    x0r = a[10] - a[27];
    x0i = a[11] + a[26];
    x2r = wk3i * x0r - wk3r * x0i;
    x2i = wk3i * x0i + wk3r * x0r;
    REAL y1r = x1r + x2r;
    REAL y1i = x1i + x2i;
    REAL y5r = x1r - x2r;
    REAL y5i = x1i - x2i;
    x0r = a[2] + a[19];
    x0i = a[3] - a[18];
    x1r = wk3r * x0r - wk3i * x0i;
    x1i = wk3r * x0i + wk3i * x0r;
    x0r = a[10] + a[27];
    x0i = a[11] - a[26];
    x2r = wk1r * x0r + wk1i * x0i;
    x2i = wk1r * x0i - wk1i * x0r;
    REAL y9r = x1r - x2r;
    REAL y9i = x1i - x2i;
    REAL y13r = x1r + x2r;
    REAL y13i = x1i + x2i;
    x0r = a[4] - a[21];
    x0i = a[5] + a[20];
    x1r = wk2r * x0r - wk2i * x0i;
    x1i = wk2r * x0i + wk2i * x0r;
    x0r = a[12] - a[29];
    x0i = a[13] + a[28];
    x2r = wk2i * x0r - wk2r * x0i;
    x2i = wk2i * x0i + wk2r * x0r;
    REAL y2r = x1r + x2r;
    REAL y2i = x1i + x2i;
    REAL y6r = x1r - x2r;
    REAL y6i = x1i - x2i;
    x0r = a[4] + a[21];
    x0i = a[5] - a[20];
    x1r = wk2i * x0r - wk2r * x0i;
    x1i = wk2i * x0i + wk2r * x0r;
    x0r = a[12] + a[29];
    x0i = a[13] - a[28];
    x2r = wk2r * x0r - wk2i * x0i;
    x2i = wk2r * x0i + wk2i * x0r;
    REAL y10r = x1r - x2r;
    REAL y10i = x1i - x2i;
    REAL y14r = x1r + x2r;
    REAL y14i = x1i + x2i;
    x0r = a[6] - a[23];
    x0i = a[7] + a[22];
    x1r = wk3r * x0r - wk3i * x0i;
    x1i = wk3r * x0i + wk3i * x0r;
    x0r = a[14] - a[31];
    x0i = a[15] + a[30];
    x2r = wk1i * x0r - wk1r * x0i;
    x2i = wk1i * x0i + wk1r * x0r;
    REAL y3r = x1r + x2r;
    REAL y3i = x1i + x2i;
    REAL y7r = x1r - x2r;
    REAL y7i = x1i - x2i;
    x0r = a[6] + a[23];
    x0i = a[7] - a[22];
    x1r = wk1i * x0r + wk1r * x0i;
    x1i = wk1i * x0i - wk1r * x0r;
    x0r = a[14] + a[31];
    x0i = a[15] - a[30];
    x2r = wk3i * x0r - wk3r * x0i;
    x2i = wk3i * x0i + wk3r * x0r;
    REAL y11r = x1r + x2r;
    REAL y11i = x1i + x2i;
    REAL y15r = x1r - x2r;
    REAL y15i = x1i - x2i;
    x1r = y0r + y2r;
    x1i = y0i + y2i;
    x2r = y1r + y3r;
    x2i = y1i + y3i;
    a[0] = x1r + x2r;
    a[1] = x1i + x2i;
    a[2] = x1r - x2r;
    a[3] = x1i - x2i;
    x1r = y0r - y2r;
    x1i = y0i - y2i;
    x2r = y1r - y3r;
    x2i = y1i - y3i;
    a[4] = x1r - x2i;
    a[5] = x1i + x2r;
    a[6] = x1r + x2i;
    a[7] = x1i - x2r;
    x1r = y4r - y6i;
    x1i = y4i + y6r;
    x0r = y5r - y7i;
    x0i = y5i + y7r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[8] = x1r + x2r;
    a[9] = x1i + x2i;
    a[10] = x1r - x2r;
    a[11] = x1i - x2i;
    x1r = y4r + y6i;
    x1i = y4i - y6r;
    x0r = y5r + y7i;
    x0i = y5i - y7r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[12] = x1r - x2i;
    a[13] = x1i + x2r;
    a[14] = x1r + x2i;
    a[15] = x1i - x2r;
    x1r = y8r + y10r;
    x1i = y8i + y10i;
    x2r = y9r - y11r;
    x2i = y9i - y11i;
    a[16] = x1r + x2r;
    a[17] = x1i + x2i;
    a[18] = x1r - x2r;
    a[19] = x1i - x2i;
    x1r = y8r - y10r;
    x1i = y8i - y10i;
    x2r = y9r + y11r;
    x2i = y9i + y11i;
    a[20] = x1r - x2i;
    a[21] = x1i + x2r;
    a[22] = x1r + x2i;
    a[23] = x1i - x2r;
    x1r = y12r - y14i;
    x1i = y12i + y14r;
    x0r = y13r + y15i;
    x0i = y13i - y15r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[24] = x1r + x2r;
    a[25] = x1i + x2i;
    a[26] = x1r - x2r;
    a[27] = x1i - x2i;
    x1r = y12r + y14i;
    x1i = y12i - y14r;
    x0r = y13r - y15i;
    x0i = y13i + y15r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[28] = x1r - x2i;
    a[29] = x1i + x2r;
    a[30] = x1r + x2i;
    a[31] = x1i - x2r;
}


void cftf081(REAL *a, REAL *w)
{
    /*
    REAL wn4r, x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i,
        y0r, y0i, y1r, y1i, y2r, y2i, y3r, y3i,
        y4r, y4i, y5r, y5i, y6r, y6i, y7r, y7i;
    */
    REAL wn4r = w[1];
    REAL x0r = a[0] + a[8];
    REAL x0i = a[1] + a[9];
    REAL x1r = a[0] - a[8];
    REAL x1i = a[1] - a[9];
    REAL x2r = a[4] + a[12];
    REAL x2i = a[5] + a[13];
    REAL x3r = a[4] - a[12];
    REAL x3i = a[5] - a[13];
    REAL y0r = x0r + x2r;
    REAL y0i = x0i + x2i;
    REAL y2r = x0r - x2r;
    REAL y2i = x0i - x2i;
    REAL y1r = x1r - x3i;
    REAL y1i = x1i + x3r;
    REAL y3r = x1r + x3i;
    REAL y3i = x1i - x3r;
    x0r = a[2] + a[10];
    x0i = a[3] + a[11];
    x1r = a[2] - a[10];
    x1i = a[3] - a[11];
    x2r = a[6] + a[14];
    x2i = a[7] + a[15];
    x3r = a[6] - a[14];
    x3i = a[7] - a[15];
    REAL y4r = x0r + x2r;
    REAL y4i = x0i + x2i;
    REAL y6r = x0r - x2r;
    REAL y6i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    x2r = x1r + x3i;
    x2i = x1i - x3r;
    REAL y5r = wn4r * (x0r - x0i);
    REAL y5i = wn4r * (x0r + x0i);
    REAL y7r = wn4r * (x2r - x2i);
    REAL y7i = wn4r * (x2r + x2i);
    a[8] = y1r + y5r;
    a[9] = y1i + y5i;
    a[10] = y1r - y5r;
    a[11] = y1i - y5i;
    a[12] = y3r - y7i;
    a[13] = y3i + y7r;
    a[14] = y3r + y7i;
    a[15] = y3i - y7r;
    a[0] = y0r + y4r;
    a[1] = y0i + y4i;
    a[2] = y0r - y4r;
    a[3] = y0i - y4i;
    a[4] = y2r - y6i;
    a[5] = y2i + y6r;
    a[6] = y2r + y6i;
    a[7] = y2i - y6r;
}


void cftf082(REAL *a, REAL *w)
{
    /*
    REAL wn4r, wk1r, wk1i, x0r, x0i, x1r, x1i,
        y0r, y0i, y1r, y1i, y2r, y2i, y3r, y3i,
        y4r, y4i, y5r, y5i, y6r, y6i, y7r, y7i;
    */
    REAL wn4r = w[1];
    REAL wk1r = w[2];
    REAL wk1i = w[3];
    REAL y0r = a[0] - a[9];
    REAL y0i = a[1] + a[8];
    REAL y1r = a[0] + a[9];
    REAL y1i = a[1] - a[8];
    REAL x0r = a[4] - a[13];
    REAL x0i = a[5] + a[12];
    REAL y2r = wn4r * (x0r - x0i);
    REAL y2i = wn4r * (x0i + x0r);
    x0r = a[4] + a[13];
    x0i = a[5] - a[12];
    REAL y3r = wn4r * (x0r - x0i);
    REAL y3i = wn4r * (x0i + x0r);
    x0r = a[2] - a[11];
    x0i = a[3] + a[10];
    REAL y4r = wk1r * x0r - wk1i * x0i;
    REAL y4i = wk1r * x0i + wk1i * x0r;
    x0r = a[2] + a[11];
    x0i = a[3] - a[10];
    REAL y5r = wk1i * x0r - wk1r * x0i;
    REAL y5i = wk1i * x0i + wk1r * x0r;
    x0r = a[6] - a[15];
    x0i = a[7] + a[14];
    REAL y6r = wk1i * x0r - wk1r * x0i;
    REAL y6i = wk1i * x0i + wk1r * x0r;
    x0r = a[6] + a[15];
    x0i = a[7] - a[14];
    REAL y7r = wk1r * x0r - wk1i * x0i;
    REAL y7i = wk1r * x0i + wk1i * x0r;
    x0r = y0r + y2r;
    x0i = y0i + y2i;
    REAL x1r = y4r + y6r;
    REAL x1i = y4i + y6i;
    a[0] = x0r + x1r;
    a[1] = x0i + x1i;
    a[2] = x0r - x1r;
    a[3] = x0i - x1i;
    x0r = y0r - y2r;
    x0i = y0i - y2i;
    x1r = y4r - y6r;
    x1i = y4i - y6i;
    a[4] = x0r - x1i;
    a[5] = x0i + x1r;
    a[6] = x0r + x1i;
    a[7] = x0i - x1r;
    x0r = y1r - y3i;
    x0i = y1i + y3r;
    x1r = y5r - y7r;
    x1i = y5i - y7i;
    a[8] = x0r + x1r;
    a[9] = x0i + x1i;
    a[10] = x0r - x1r;
    a[11] = x0i - x1i;
    x0r = y1r + y3i;
    x0i = y1i - y3r;
    x1r = y5r + y7r;
    x1i = y5i + y7i;
    a[12] = x0r - x1i;
    a[13] = x0i + x1r;
    a[14] = x0r + x1i;
    a[15] = x0i - x1r;
}


void cftf040(REAL *a)
{
    //REAL x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i;

    immutable REAL x0r = a[0] + a[4];
    immutable REAL x0i = a[1] + a[5];
    immutable REAL x1r = a[0] - a[4];
    immutable REAL x1i = a[1] - a[5];
    immutable REAL x2r = a[2] + a[6];
    immutable REAL x2i = a[3] + a[7];
    immutable REAL x3r = a[2] - a[6];
    immutable REAL x3i = a[3] - a[7];
    a[0] = x0r + x2r;
    a[1] = x0i + x2i;
    a[2] = x1r - x3i;
    a[3] = x1i + x3r;
    a[4] = x0r - x2r;
    a[5] = x0i - x2i;
    a[6] = x1r + x3i;
    a[7] = x1i - x3r;
}


void cftb040(REAL *a)
{
    //REAL x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i;

    immutable REAL x0r = a[0] + a[4];
    immutable REAL x0i = a[1] + a[5];
    immutable REAL x1r = a[0] - a[4];
    immutable REAL x1i = a[1] - a[5];
    immutable REAL x2r = a[2] + a[6];
    immutable REAL x2i = a[3] + a[7];
    immutable REAL x3r = a[2] - a[6];
    immutable REAL x3i = a[3] - a[7];
    a[0] = x0r + x2r;
    a[1] = x0i + x2i;
    a[2] = x1r + x3i;
    a[3] = x1i - x3r;
    a[4] = x0r - x2r;
    a[5] = x0i - x2i;
    a[6] = x1r - x3i;
    a[7] = x1i + x3r;
}


void cftx020(REAL *a)
{
    //REAL x0r, x0i;

    immutable REAL x0r = a[0] - a[2];
    immutable REAL x0i = a[1] - a[3];
    a[0] += a[2];
    a[1] += a[3];
    a[2] = x0r;
    a[3] = x0i;
}


void rftfsub(int n, REAL *a, int nc, REAL *c)
{
    int j, k, kk, ks, m;
    //REAL wkr, wki, xr, xi, yr, yi;

    m = n >> 1;
    ks = 2 * nc / m;
    kk = 0;
    for (j = 2; j < m; j += 2) {
        k = n - j;
        kk += ks;
        REAL wkr = 0.5 - c[nc - kk];
        REAL wki = c[kk];
        REAL xr = a[j] - a[k];
        REAL xi = a[j + 1] + a[k + 1];
        REAL yr = wkr * xr - wki * xi;
        REAL yi = wkr * xi + wki * xr;
        a[j] -= yr;
        a[j + 1] -= yi;
        a[k] += yr;
        a[k + 1] -= yi;
    }
}


void rftbsub(int n, REAL *a, int nc, REAL *c)
{
    int j, k, kk, ks, m;
    //REAL wkr, wki, xr, xi, yr, yi;

    m = n >> 1;
    ks = 2 * nc / m;
    kk = 0;
    for (j = 2; j < m; j += 2) {
        k = n - j;
        kk += ks;
        REAL wkr = 0.5 - c[nc - kk];
        REAL wki = c[kk];
        REAL xr = a[j] - a[k];
        REAL xi = a[j + 1] + a[k + 1];
        REAL yr = wkr * xr + wki * xi;
        REAL yi = wkr * xi - wki * xr;
        a[j] -= yr;
        a[j + 1] -= yi;
        a[k] += yr;
        a[k + 1] -= yi;
    }
}


void dctsub(int n, REAL *a, int nc, REAL *c)
{
    int j, k, kk, ks, m;
    //REAL wkr, wki, xr;

    m = n >> 1;
    ks = nc / n;
    kk = 0;
    for (j = 1; j < m; j++) {
        k = n - j;
        kk += ks;
        REAL wkr = c[kk] - c[nc - kk];
        REAL wki = c[kk] + c[nc - kk];
        REAL xr = wki * a[j] - wkr * a[k];
        a[j] = wkr * a[j] + wki * a[k];
        a[k] = xr;
    }
    a[m] *= c[0];
}


void dstsub(int n, REAL *a, int nc, REAL *c)
{
    int j, k, kk, ks, m;
    //REAL wkr, wki, xr;

    m = n >> 1;
    ks = nc / n;
    kk = 0;
    for (j = 1; j < m; j++) {
        k = n - j;
        kk += ks;
        REAL wkr = c[kk] - c[nc - kk];
        REAL wki = c[kk] + c[nc - kk];
        REAL xr = wki * a[k] - wkr * a[j];
        a[k] = wkr * a[k] + wki * a[j];
        a[j] = xr;
    }
    a[m] *= c[0];
}
