// Shibatch Super Equalizer ver 0.03 for winamp
// written by Naoki Shibata  shibatch@users.sourceforge.net
// LGPL
module mbandeq;
private:

import fftsg;

//version = mbeq_debug_output;

version(mbeq_debug_output) import iv.cmdcon;


// ////////////////////////////////////////////////////////////////////////// //
// Real Discrete Fourier Transform wrapper
void rfft (int n, int isign, REAL* x) {
  import std.math : sqrt;
  static int ipsize = 0, wsize=0;
  static int* ip = null;
  static REAL* w = null;
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


public int mbeqBandCount () { pragma(inline, true); return NBANDS+1; } ///

/// last band is equal to samling rate
public int mbeqBandFreq (int idx) { pragma(inline, true); return (idx >= 0 && idx < NBANDS+1 ? mbeqBandFreqs[idx] : (idx == NBANDS+1 ? 48000 : 0)); }
