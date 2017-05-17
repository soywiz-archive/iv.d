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
module kissfft /*is aliced*/;
private:
import iv.alice;
nothrow @trusted @nogc:
/* The guts header contains all the multiplication and addition macros that are defined for
 fixed or floating point complex numbers.  It also delares the kf_ internal functions.
 */
//import kissfft_guts;

//version = kissfft_fixed;
//enum kissfft_fixed_size = 16;


version(kissfft_fixed) {
  static if (kissfft_fixed_size == 32) {
    public alias kiss_fft_scalar = int;
  } else static if (kissfft_fixed_size == 16) {
    public alias kiss_fft_scalar = short;
  } else {
    static assert(0, "wtf?!");
  }
} else {
  public alias kiss_fft_scalar = float;
}


///
public align(1) struct kiss_fft_cpx {
align(1):
  kiss_fft_scalar r;
  kiss_fft_scalar i;
}


///
public alias kiss_fft_cfg = kiss_fft_state*;


enum MAXFACTORS = 32;
/* e.g. an fft of length 128 has 4 factors
 as far as kissfft is concerned
 4*4*4*2
 */

struct kiss_fft_state {
  int nfft;
  int inverse;
  int[2*MAXFACTORS] factors;
  kiss_fft_cpx[1] twiddles;
}


// ////////////////////////////////////////////////////////////////////////// //
private void kf_bfly2 (kiss_fft_cpx* Fout, const size_t fstride, const(kiss_fft_cfg) st, int m) {
  kiss_fft_cpx* Fout2;
  const(kiss_fft_cpx)* tw1 = st.twiddles.ptr;
  kiss_fft_cpx t;
  Fout2 = Fout+m;
  do {
    mixin(C_FIXDIV!("*Fout", "2"));
    mixin(C_FIXDIV!("*Fout2", "2"));
    mixin(C_MUL!("t", "*Fout2", "*tw1"));
    tw1 += fstride;
    mixin(C_SUB!("*Fout2", "*Fout", "t"));
    mixin(C_ADDTO!("*Fout", "t"));
    ++Fout2;
    ++Fout;
  } while (--m);
}


private void kf_bfly4 (kiss_fft_cpx* Fout, const size_t fstride, const(kiss_fft_cfg) st, const size_t m) {
  const(kiss_fft_cpx)* tw1, tw2, tw3;
  kiss_fft_cpx[6] scratch = void;
  size_t k = m;
  const size_t m2 = 2*m;
  const size_t m3 = 3*m;
  tw3 = tw2 = tw1 = st.twiddles.ptr;
  do {
    mixin(C_FIXDIV!("*Fout", "4"));
    mixin(C_FIXDIV!("Fout[m]", "4"));
    mixin(C_FIXDIV!("Fout[m2]", "4"));
    mixin(C_FIXDIV!("Fout[m3]", "4"));

    mixin(C_MUL!("scratch[0]", "Fout[m]", "*tw1"));
    mixin(C_MUL!("scratch[1]", "Fout[m2]", "*tw2"));
    mixin(C_MUL!("scratch[2]", "Fout[m3]", "*tw3"));

    mixin(C_SUB!("scratch[5]", "*Fout", "scratch[1]"));
    mixin(C_ADDTO!("*Fout", "scratch[1]"));
    mixin(C_ADD!("scratch[3]", "scratch[0]", "scratch[2]"));
    mixin(C_SUB!("scratch[4]", "scratch[0]", "scratch[2]"));
    mixin(C_SUB!("Fout[m2]", "*Fout", "scratch[3]"));
    tw1 += fstride;
    tw2 += fstride*2;
    tw3 += fstride*3;
    mixin(C_ADDTO!("*Fout", "scratch[3]"));

    if (st.inverse) {
      Fout[m].r = cast(kiss_fft_scalar)(scratch[5].r - scratch[4].i);
      Fout[m].i = cast(kiss_fft_scalar)(scratch[5].i + scratch[4].r);
      Fout[m3].r = cast(kiss_fft_scalar)(scratch[5].r + scratch[4].i);
      Fout[m3].i = cast(kiss_fft_scalar)(scratch[5].i - scratch[4].r);
    } else {
      Fout[m].r = cast(kiss_fft_scalar)(scratch[5].r + scratch[4].i);
      Fout[m].i = cast(kiss_fft_scalar)(scratch[5].i - scratch[4].r);
      Fout[m3].r = cast(kiss_fft_scalar)(scratch[5].r - scratch[4].i);
      Fout[m3].i = cast(kiss_fft_scalar)(scratch[5].i + scratch[4].r);
    }
    ++Fout;
  } while (--k);
}


private void kf_bfly3 (kiss_fft_cpx* Fout, const size_t fstride, const(kiss_fft_cfg) st, size_t m) {
  size_t k = m;
  const size_t m2 = 2*m;
  const(kiss_fft_cpx)* tw1, tw2;
  kiss_fft_cpx[5] scratch = void;
  kiss_fft_cpx epi3;
  epi3 = st.twiddles[fstride*m];
  tw1 = tw2 = st.twiddles.ptr;
  do {
    mixin(C_FIXDIV!("*Fout", "3"));
    mixin(C_FIXDIV!("Fout[m]", "3"));
    mixin(C_FIXDIV!("Fout[m2]", "3"));

    mixin(C_MUL!("scratch[1]", "Fout[m]", "*tw1"));
    mixin(C_MUL!("scratch[2]", "Fout[m2]", "*tw2"));

    mixin(C_ADD!("scratch[3]", "scratch[1]", "scratch[2]"));
    mixin(C_SUB!("scratch[0]", "scratch[1]", "scratch[2]"));
    tw1 += fstride;
    tw2 += fstride*2;

    Fout[m].r = cast(kiss_fft_scalar)(Fout.r - HALF_OF(scratch[3].r));
    Fout[m].i = cast(kiss_fft_scalar)(Fout.i - HALF_OF(scratch[3].i));

    mixin(C_MULBYSCALAR!("scratch[0]", "epi3.i"));

    mixin(C_ADDTO!("*Fout", "scratch[3]"));

    Fout[m2].r = cast(kiss_fft_scalar)(Fout[m].r + scratch[0].i);
    Fout[m2].i = cast(kiss_fft_scalar)(Fout[m].i - scratch[0].r);

    Fout[m].r -= scratch[0].i;
    Fout[m].i += scratch[0].r;

    ++Fout;
  } while (--k);
}


private void kf_bfly5 (kiss_fft_cpx* Fout, const size_t fstride, const(kiss_fft_cfg) st, int m) {
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
    mixin(C_FIXDIV!("*Fout0", "5"));
    mixin(C_FIXDIV!("*Fout1", "5"));
    mixin(C_FIXDIV!("*Fout2", "5"));
    mixin(C_FIXDIV!("*Fout3", "5"));
    mixin(C_FIXDIV!("*Fout4", "5"));
    scratch[0] = *Fout0;

    mixin(C_MUL!("scratch[1]", "*Fout1", "tw[u*fstride]"));
    mixin(C_MUL!("scratch[2]", "*Fout2", "tw[2*u*fstride]"));
    mixin(C_MUL!("scratch[3]", "*Fout3", "tw[3*u*fstride]"));
    mixin(C_MUL!("scratch[4]", "*Fout4", "tw[4*u*fstride]"));

    mixin(C_ADD!("scratch[7]", "scratch[1]", "scratch[4]"));
    mixin(C_SUB!("scratch[10]", "scratch[1]", "scratch[4]"));
    mixin(C_ADD!("scratch[8]", "scratch[2]", "scratch[3]"));
    mixin(C_SUB!("scratch[9]", "scratch[2]", "scratch[3]"));

    Fout0.r += scratch[7].r + scratch[8].r;
    Fout0.i += scratch[7].i + scratch[8].i;

    scratch[5].r = cast(kiss_fft_scalar)(scratch[0].r + mixin(S_MUL!("scratch[7].r", "ya.r")) + mixin(S_MUL!("scratch[8].r", "yb.r")));
    scratch[5].i = cast(kiss_fft_scalar)(scratch[0].i + mixin(S_MUL!("scratch[7].i", "ya.r")) + mixin(S_MUL!("scratch[8].i", "yb.r")));

    scratch[6].r = cast(kiss_fft_scalar)(           mixin(S_MUL!("scratch[10].i", "ya.i")) + mixin(S_MUL!("scratch[9].i", "yb.i")));
    scratch[6].i = cast(kiss_fft_scalar)(-cast(int)(mixin(S_MUL!("scratch[10].r", "ya.i")) - mixin(S_MUL!("scratch[9].r", "yb.i"))));

    mixin(C_SUB!("*Fout1", "scratch[5]", "scratch[6]"));
    mixin(C_ADD!("*Fout4", "scratch[5]", "scratch[6]"));

    scratch[11].r = cast(kiss_fft_scalar)(scratch[0].r + mixin(S_MUL!("scratch[7].r", "yb.r")) + mixin(S_MUL!("scratch[8].r", "ya.r")));
    scratch[11].i = cast(kiss_fft_scalar)(scratch[0].i + mixin(S_MUL!("scratch[7].i", "yb.r")) + mixin(S_MUL!("scratch[8].i", "ya.r")));
    scratch[12].r = cast(kiss_fft_scalar)(-cast(int)(mixin(S_MUL!("scratch[10].i", "yb.i")) + mixin(S_MUL!("scratch[9].i", "ya.i"))));
    scratch[12].i = cast(kiss_fft_scalar)(           mixin(S_MUL!("scratch[10].r", "yb.i")) - mixin(S_MUL!("scratch[9].r", "ya.i")));

    mixin(C_ADD!("*Fout2", "scratch[11]", "scratch[12]"));
    mixin(C_SUB!("*Fout3", "scratch[11]", "scratch[12]"));

    ++Fout0;
    ++Fout1;
    ++Fout2;
    ++Fout3;
    ++Fout4;
  }
}

// perform the butterfly for one stage of a mixed radix FFT
private void kf_bfly_generic (kiss_fft_cpx* Fout, const size_t fstride, const(kiss_fft_cfg) st, int m, int p) {
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
      mixin(C_FIXDIV!("scratch[q1]", "p"));
      k += m;
    }

    k = u;
    for (q1 = 0; q1 < p; ++q1) {
      int twidx = 0;
      Fout[k] = scratch[0];
      for (q = 1; q < p; ++q) {
        twidx += fstride*k;
        if (twidx >= Norig) twidx -= Norig;
        mixin(C_MUL!("t", "scratch[q]", "twiddles[twidx]"));
        mixin(C_ADDTO!("Fout[k]", "t"));
      }
      k += m;
    }
  }
  //KISS_FFT_TMP_FREE(scratch);
}


private void kf_work (kiss_fft_cpx* Fout, const(kiss_fft_cpx)* f, const size_t fstride, int in_stride, int* factors, const(kiss_fft_cfg) st) {
  kiss_fft_cpx* Fout_beg = Fout;
  const int p = *factors++; // the radix
  const int m = *factors++; // stage's fft length/p
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
      kf_work (Fout, f, fstride*p, in_stride, factors, st);
      f += fstride*in_stride;
    }while ((Fout += m) != Fout_end);
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


/*  facbuf is populated by p1, m1, p2, m2, ...
  where
  p[i] * m[i] = m[i-1]
  m0 = n                  */
private void kf_factor (int n, int* facbuf) {
  import std.math : floor, sqrt;
  int p = 4;
  double floor_sqrt = floor(sqrt(cast(double)n));

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

/* User-callable function to allocate all necessary storage space for the fft.
 *
 * The return value is a contiguous block of memory, allocated with malloc.  As such,
 * It can be freed with free(), rather than a kiss_fft-specific function.
 */

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
 *  then the function returns `null` and places the minimum cfg buffer size in `*lenmem`.
 */
public kiss_fft_cfg kiss_fft_alloc (int nfft, int inverse_fft, void* mem, size_t* lenmem) {
  kiss_fft_cfg st = null;
  size_t memneeded = kiss_fft_state.sizeof+kiss_fft_cpx.sizeof*(nfft-1); /* twiddle factors*/

  if (lenmem is null) {
    import core.stdc.stdlib : malloc;
    st = cast(kiss_fft_cfg)malloc(memneeded);
  } else {
    if (mem !is null && *lenmem >= memneeded) st = cast(kiss_fft_cfg)mem;
    *lenmem = memneeded;
  }
  if (st) {
    st.nfft = nfft;
    st.inverse = inverse_fft;
    for (int i = 0; i < nfft; ++i) {
      enum pi = 3.141592653589793238462643383279502884197169399375105820974944;
      double phase = -2*pi*i/nfft;
      if (st.inverse) phase *= -1;
      mixin(kf_cexp!("st.twiddles.ptr+i", "phase"));
    }
    kf_factor(nfft, st.factors.ptr);
  }
  return st;
}


/** If kiss_fft_alloc allocated a buffer, it is one contiguous
 * buffer and can be simply free()d when no longer needed
 */
public void kiss_fft_free (void *p) {
  if (p !is null) {
    import core.stdc.stdlib : free;
    free(p);
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
    //kiss_fft_cpx * tmpbuf = cast(kiss_fft_cpx*)KISS_FFT_TMP_ALLOC(kiss_fft_cpx.sizeof*st.nfft);
    kiss_fft_cpx * tmpbuf = cast(kiss_fft_cpx*)alloca(kiss_fft_cpx.sizeof*st.nfft);
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
// kissfft_guts
/*
  Explanation of macros dealing with complex math:

   C_MUL(m,a,b)         : m = a*b
   C_FIXDIV( c , div )  : if a fixed point impl., c /= div. noop otherwise
   C_SUB( res, a,b)     : res = a - b
   C_SUBFROM( res , a)  : res -= a
   C_ADDTO( res , a)    : res += a
 * */
version(kissfft_fixed) {
  static if (kissfft_fixed_size == 32) {
    enum FRACBITS = 31;
    alias SAMPPROD = long;
    enum SAMP_MAX = 2147483647;
  } else static if (kissfft_fixed_size == 16) {
    enum FRACBITS = 15;
    alias SAMPPROD = int;
    enum SAMP_MAX = 32767;
  } else {
    static assert(0, "wtf?!");
  }
  enum SAMP_MIN = -SAMP_MAX;

  /*
  #if defined(CHECK_OVERFLOW)
  #  define CHECK_OVERFLOW_OP(a,op,b)  \
    if ( (SAMPPROD)(a) op (SAMPPROD)(b) > SAMP_MAX || (SAMPPROD)(a) op (SAMPPROD)(b) < SAMP_MIN ) { \
      fprintf(stderr,"WARNING:overflow @ " __FILE__ "(%d): (%d " #op" %d) = %ld\n",__LINE__,(a),(b),(SAMPPROD)(a) op (SAMPPROD)(b) );  }
  #endif
  */

  enum smul(string a, string b) = "(cast(SAMPPROD)("~a~")*("~b~"))";
  enum sround(string x) = "(cast(kiss_fft_scalar)((("~x~")+(1<<(FRACBITS-1)))>>FRACBITS))";

  enum S_MUL(string a, string b) = sround!(smul!(a, b));

  enum C_MUL(string m, string a, string b) =
    "{ ("~m~").r = "~sround!(smul!("("~a~").r", "("~b~").r")~"-"~smul!("("~a~").i", "("~b~").i"))~";
       ("~m~").i = "~sround!(smul!("("~a~").r", "("~b~").i")~"+"~smul!("("~a~").i", "("~b~").r"))~"; }";

  enum DIVSCALAR(string x, string k) = "("~x~") = "~sround!(smul!(x, "SAMP_MAX/"~k));

  enum C_FIXDIV(string c, string div) = "{"~DIVSCALAR!("("~c~").r", div)~"; "~DIVSCALAR!("("~c~").i", div)~"; }";

  enum C_MULBYSCALAR(string c, string s ) =
    "{ ("~c~").r = "~sround!(smul!("("~c~").r", s))~";
       ("~c~").i = "~sround!(smul!("("~c~").i", s))~"; }";
} else {
  // not FIXED_POINT
  enum S_MUL(string a, string b) = "(("~a~")*("~b~"))";
  enum C_MUL(string m, string a, string b) =
    "{ ("~m~").r = ("~a~").r*("~b~").r - ("~a~").i*("~b~").i;
       ("~m~").i = ("~a~").r*("~b~").i + ("~a~").i*("~b~").r; }";
  enum C_FIXDIV(string c, string div) = "{}"; // NOOP
  enum C_MULBYSCALAR(string c, string s) = " { ("~c~").r *= ("~s~"); ("~c~").i *= ("~s~"); }";
}

/+
#ifndef CHECK_OVERFLOW_OP
#  define CHECK_OVERFLOW_OP(a,op,b) /* noop */
#endif
+/

enum C_ADD(string res, string a, string b) = "{ ("~res~").r=cast(kiss_fft_scalar)(("~a~").r+("~b~").r); ("~res~").i=cast(kiss_fft_scalar)(("~a~").i+("~b~").i); }";
enum C_SUB(string res, string a, string b) = "{ ("~res~").r=cast(kiss_fft_scalar)(("~a~").r-("~b~").r); ("~res~").i=cast(kiss_fft_scalar)(("~a~").i-("~b~").i); }";
enum C_ADDTO(string res, string a) = "{ ("~res~").r += ("~a~").r; ("~res~").i += ("~a~").i; }";
enum C_SUBFROM(string res, string a) = "{ ("~res~").r -= ("~a~").r; ("~res~").i -= ("~a~").i; }";


version(kissfft_fixed) {
  kiss_fft_scalar KISS_FFT_COS (double phase) { import std.math : cos, floor; return cast(kiss_fft_scalar)(floor(0.5+SAMP_MAX*cos(phase))); }
  kiss_fft_scalar KISS_FFT_SIN (double phase) { import std.math : sin, floor; return cast(kiss_fft_scalar)(floor(0.5+SAMP_MAX*sin(phase))); }
  kiss_fft_scalar HALF_OF (kiss_fft_scalar x) { return cast(kiss_fft_scalar)(x>>1); }
} else {
  kiss_fft_scalar KISS_FFT_COS (double phase) { import std.math : cos; return cos(phase); }
  kiss_fft_scalar KISS_FFT_SIN (double phase) { import std.math : sin; return sin(phase); }
  kiss_fft_scalar HALF_OF (kiss_fft_scalar x) { return cast(kiss_fft_scalar)(x*cast(kiss_fft_scalar)0.5); }
}

enum kf_cexp(string x, string phase) = "{ ("~x~").r = KISS_FFT_COS("~phase~"); ("~x~").i = KISS_FFT_SIN("~phase~"); }";


/+
/* a debugging function */
#define pcpx(c)\
    fprintf(stderr,"%g + %gi\n",(double)((c)->r),(double)((c)->i) )


#ifdef KISS_FFT_USE_ALLOCA
// define this to allow use of alloca instead of malloc for temporary buffers
// Temporary buffers are used in two case:
// 1. FFT sizes that have "bad" factors. i.e. not 2,3 and 5
// 2. "in-place" FFTs.  Notice the quotes, since kissfft does not really do an in-place transform.
#include <alloca.h>
#define  KISS_FFT_TMP_ALLOC(nbytes) alloca(nbytes)
#define  KISS_FFT_TMP_FREE(ptr)
#else
#define  KISS_FFT_TMP_ALLOC(nbytes) KISS_FFT_MALLOC(nbytes)
#define  KISS_FFT_TMP_FREE(ptr) KISS_FFT_FREE(ptr)
#endif
+/


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
public kiss_fftr_cfg kiss_fftr_alloc (int nfft, int inverse_fft, void* mem, size_t* lenmem) {
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
  st.tmpbuf = cast(kiss_fft_cpx*)((cast(char*)st.substate)+subsize);
  st.super_twiddles = st.tmpbuf+nfft;
  kiss_fft_alloc(nfft, inverse_fft, st.substate, &subsize);

  foreach (immutable i; 0..nfft/2) {
    double phase = -3.14159265358979323846264338327*(cast(double)(i+1)/nfft+0.5);
    if (inverse_fft) phase *= -1;
    mixin(kf_cexp!("st.super_twiddles+i", "phase"));
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
  mixin(C_FIXDIV!("tdc", "2"));
  //CHECK_OVERFLOW_OP(tdc.r ,+, tdc.i);
  //CHECK_OVERFLOW_OP(tdc.r ,-, tdc.i);
  freqdata[0].r = cast(kiss_fft_scalar)(tdc.r+tdc.i);
  freqdata[ncfft].r = cast(kiss_fft_scalar)(tdc.r-tdc.i);
  freqdata[ncfft].i = freqdata[0].i = 0;

  for (k = 1; k <= ncfft/2; ++k) {
    fpk = st.tmpbuf[k];
    fpnk.r = st.tmpbuf[ncfft-k].r;
    fpnk.i = cast(kiss_fft_scalar)(-cast(int)st.tmpbuf[ncfft-k].i);
    mixin(C_FIXDIV!("fpk", "2"));
    mixin(C_FIXDIV!("fpnk", "2"));

    mixin(C_ADD!("f1k", "fpk", "fpnk"));
    mixin(C_SUB!("f2k", "fpk", "fpnk"));
    mixin(C_MUL!("tw", "f2k", "st.super_twiddles[k-1]"));

    freqdata[k].r = HALF_OF(cast(kiss_fft_scalar)(f1k.r+tw.r));
    freqdata[k].i = HALF_OF(cast(kiss_fft_scalar)(f1k.i+tw.i));
    freqdata[ncfft-k].r = HALF_OF(cast(kiss_fft_scalar)(f1k.r-tw.r));
    freqdata[ncfft-k].i = HALF_OF(cast(kiss_fft_scalar)(tw.i-f1k.i));
  }
}


/** input freqdata has  nfft/2+1 complex points
 * output timedata has nfft scalar points
 */
public void kiss_fftri (kiss_fftr_cfg st, const(kiss_fft_cpx)* freqdata, kiss_fft_scalar* timedata) {
  // input buffer timedata is stored row-wise
  int k, ncfft;

  if (st.substate.inverse == 0) assert(0, "kiss fft usage error: improper alloc");

  ncfft = st.substate.nfft;

  st.tmpbuf[0].r = cast(kiss_fft_scalar)(freqdata[0].r+freqdata[ncfft].r);
  st.tmpbuf[0].i = cast(kiss_fft_scalar)(freqdata[0].r-freqdata[ncfft].r);
  mixin(C_FIXDIV!("st.tmpbuf[0]", "2"));

  for (k = 1; k <= ncfft/2; ++k) {
    kiss_fft_cpx fk, fnkc, fek, fok, tmp;
    fk = freqdata[k];
    fnkc.r = freqdata[ncfft-k].r;
    fnkc.i = cast(kiss_fft_scalar)(-cast(int)freqdata[ncfft-k].i);
    mixin(C_FIXDIV!("fk", "2"));
    mixin(C_FIXDIV!("fnkc", "2"));

    mixin(C_ADD!("fek", "fk", "fnkc"));
    mixin(C_SUB!("tmp", "fk", "fnkc"));
    mixin(C_MUL!("fok", "tmp", "st.super_twiddles[k-1]"));
    mixin(C_ADD!("st.tmpbuf[k]", "fek", "fok"));
    mixin(C_SUB!("st.tmpbuf[ncfft-k]", "fek", "fok"));
    st.tmpbuf[ncfft-k].i *= -1;
  }
  kiss_fft(st.substate, st.tmpbuf, cast(kiss_fft_cpx*)timedata);
}
