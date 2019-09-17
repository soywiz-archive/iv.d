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
/* Ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.kissfft;
private nothrow @trusted @nogc:

version(aliced) {} else alias usize = size_t;

//version = kiss_fft_use_parallel; // absolutely no reason to


// ////////////////////////////////////////////////////////////////////////// //
///
public enum KissFFT { Forward, Inverse }

///
//public alias kiss_fft_scalar = float;
//public alias kiss_fft_scalar = double;

///
public template kiss_fft_scalar(T) if (is(T == float) || is(T == double) || is(T == real)) {
  alias kiss_fft_scalar = T;
}


///
public template isGoodKissFFTScalar(T) {
  static if (is(T == float) || is(T == double) || is(T == real)) {
    enum isGoodKissFFTScalar = true;
  } else {
    enum isGoodKissFFTScalar = false;
  }
}


///
public template isKissFFTComplex(T) {
  static if (is(T : kiss_fft_cpx!S, S)) {
    enum isKissFFTComplex = true;
  } else {
    enum isKissFFTComplex = false;
  }
}


///
public template KissFFTScalar(T) {
  static if (is(T : kiss_fft_cpx!S, S)) {
    alias KissFFTScalar = S;
  } else {
    static assert(0, "not a KissFFT complex type");
  }
}

///
public align(1) struct kiss_fft_cpx(T) if (is(T == float) || is(T == double) || is(T == real)) {
align(1):
  alias Scalar = T;
  T r;
  T i;

  T opIndex (uint n) const pure nothrow @trusted @nogc { pragma(inline, true); return (n ? i : r); }
  void opIndexAssign (in T v, uint n) nothrow @trusted @nogc { pragma(inline, true); if (n) i = v; else r = v; }
}


public alias kiss_fft_cpx_f = kiss_fft_cpx!float; ///
public alias kiss_fft_cpx_d = kiss_fft_cpx!double; ///


public alias kiss_fft_cfg_f = kiss_fft_state!float*; ///
public alias kiss_fft_cfg_d = kiss_fft_state!double*; ///

public template kiss_fft_cfg(T) if (is(T == float) || is(T == double) || is(T == real)) {
  alias kiss_fft_cfg = kiss_fft_state!T*;
}


// ////////////////////////////////////////////////////////////////////////// //
/** Initialize a FFT (or IFFT) algorithm's cfg/state buffer.
 *
 * typical usage: `kiss_fft_cfg mycfg = kiss_fft_alloc(1024, KissFFT.Forward);`
 *
 * The return value from fft_alloc is a cfg buffer used internally by the fft routine or `null`.
 *
 * If `lenmem` is `null`, then kiss_fft_alloc will allocate a cfg buffer using `malloc`.
 * The returned value should be `kiss_fft_free()`d when done to avoid memory leaks.
 *
 * The state can be placed in a user supplied buffer `mem`:
 * If `lenmem` is not `null` and `mem` is not `null` and `*lenmem` is large enough,
 * then the function places the cfg in `mem` and the size used in `*lenmem`,
 * and returns `mem`.
 *
 * If `lenmem` is not `null` and (`mem` is `null` or `*lenmem` is not large enough),
 * then the function returns `null` and places the minimum cfg buffer size in `*lenmem`.
 */
public kiss_fft_cfg!S kiss_fft_alloc(S) (uint nfft, KissFFT dir, void* mem=null, usize* lenmem=null)
if (is(S == float) || is(S == double) || is(S == real))
{
  kiss_fft_cfg!S st = null;
  usize memneeded = (kiss_fft_state!S).sizeof+(kiss_fft_cpx!S).sizeof*(nfft-1); // twiddle factors

  if (lenmem is null) {
    import core.stdc.stdlib : malloc;
    st = cast(kiss_fft_cfg!S)malloc(memneeded);
  } else {
    if (mem !is null && *lenmem >= memneeded) st = cast(kiss_fft_cfg!S)mem;
    *lenmem = memneeded;
  }

  if (st !is null) {
    st.nfft = nfft;
    st.inverse = (dir == KissFFT.Inverse);
    foreach (immutable uint i; 0..nfft) {
      enum pi = 3.141592653589793238462643383279502884197169399375105820974944;
      immutable double phase = -2*pi*i/nfft*(st.inverse ? -1 : 1);
      //if (st.inverse) phase = -phase;
      mixin(kf_cexp!("st.twiddles.ptr+i", "phase"));
    }
    kf_factor!S(nfft, st.factors.ptr);
  }

  return st;
}


/** If kiss_fft_alloc allocated a buffer, it is one contiguous
 * buffer and can be simply free()d when no longer needed
 */
public void kiss_fft_free(S) (ref kiss_fft_cfg!S p)
if (is(S == float) || is(S == double) || is(S == real))
{
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
public void kiss_fft(S) (kiss_fft_cfg!S cfg, const(kiss_fft_cpx!S)* fin, kiss_fft_cpx!S* fout)
if (is(S == float) || is(S == double) || is(S == real))
{
  assert(cfg !is null);
  kiss_fft_stride!S(cfg, fin, fout, 1);
}


/** A more generic version of the above function. It reads its input from every Nth sample. */
public void kiss_fft_stride(S) (kiss_fft_cfg!S st, const(kiss_fft_cpx!S)* fin, kiss_fft_cpx!S* fout, uint in_stride)
if (is(S == float) || is(S == double) || is(S == real))
{
  import core.stdc.stdlib : alloca;
  assert(st !is null);
  if (fin is fout) {
    import core.stdc.string : memcpy;
    //NOTE: this is not really an in-place FFT algorithm.
    //It just performs an out-of-place FFT into a temp buffer
    //kiss_fft_cpx* tmpbuf = cast(kiss_fft_cpx*)KISS_FFT_TMP_ALLOC(kiss_fft_cpx.sizeof*st.nfft);
    kiss_fft_cpx!S* tmpbuf = cast(kiss_fft_cpx!S*)alloca((kiss_fft_cpx!S).sizeof*st.nfft);
    kf_work!S(tmpbuf, fin, 1, in_stride, st.factors.ptr, st);
    memcpy(fout, tmpbuf, (kiss_fft_cpx!S).sizeof*st.nfft);
    //KISS_FFT_TMP_FREE(tmpbuf);
  } else {
    kf_work!S(fout, fin, 1, in_stride, st.factors.ptr, st);
  }
}


/** Returns the smallest integer k, such that k>=n and k has only "fast" factors (2,3,5) */
public uint kiss_fft_next_fast_size (uint n) {
  for (;;) {
    uint m = n;
    while ((m%2) == 0) m /= 2;
    while ((m%3) == 0) m /= 3;
    while ((m%5) == 0) m /= 5;
    if (m <= 1) break; // n is completely factorable by twos, threes, and fives
    ++n;
  }
  return n;
}


// ////////////////////////////////////////////////////////////////////////// //
// kissfftr
// Real optimized version can save about 45% cpu time vs. complex fft of a real seq.

public alias kiss_fftr_cfg_f = kiss_fftr_state!float*; ///
public alias kiss_fftr_cfg_d = kiss_fftr_state!double*; ///

///
public template kiss_fftr_cfg(T) if (is(T == float) || is(T == double) || is(T == real)) {
  alias kiss_fftr_cfg = kiss_fftr_state!T*;
}

struct kiss_fftr_state(S) if (is(S == float) || is(S == double) || is(S == real)) {
  kiss_fft_cfg!S substate;
  kiss_fft_cpx!S* tmpbuf;
  kiss_fft_cpx!S* super_twiddles;
}


/*
 ** nfft must be even
 *
 * If you don't care to allocate space, use mem = lenmem = null
 */
public kiss_fftr_cfg!S kiss_fftr_alloc(S) (uint nfft, KissFFT dir, void* mem, usize* lenmem)
if (is(S == float) || is(S == double) || is(S == real))
{
  kiss_fftr_cfg!S st = null;
  usize subsize, memneeded;

  if (nfft&1) return null; //assert(0, "real FFT optimization must be even");
  nfft >>= 1;

  kiss_fft_alloc!S(nfft, dir, null, &subsize);
  memneeded = (kiss_fftr_state!S).sizeof+subsize+(kiss_fft_cpx!S).sizeof*(nfft*3/2);

  if (lenmem is null) {
    import core.stdc.stdlib : malloc;
    st = cast(kiss_fftr_cfg!S)malloc(memneeded);
  } else {
    if (*lenmem >= memneeded) st = cast(kiss_fftr_cfg!S)mem;
    *lenmem = memneeded;
  }
  if (st is null) return null;

  st.substate = cast(kiss_fft_cfg!S)(st+1); // just beyond kiss_fftr_state struct
  st.tmpbuf = cast(kiss_fft_cpx!S*)((cast(ubyte*)st.substate)+subsize);
  st.super_twiddles = st.tmpbuf+nfft;
  kiss_fft_alloc!S(nfft, dir, st.substate, &subsize);

  foreach (immutable i; 0..nfft/2) {
    enum pi = 3.141592653589793238462643383279502884197169399375105820974944;
    immutable double phase = -pi*(cast(double)(i+1)/nfft+0.5)*(dir == KissFFT.Inverse ? -1 : 1);
    //if (dir == KissFFT.Inverse) phase = -phase;
    mixin(kf_cexp!("st.super_twiddles+i", "phase"));
  }

  return st;
}


/** Use this to free `fftr` buffer. */
public void kiss_fft_free(S) (ref kiss_fftr_cfg!S p)
if (is(S == float) || is(S == double) || is(S == real))
{
  if (p !is null) {
    import core.stdc.stdlib : free;
    free(p);
    p = null;
  }
}


/** input timedata has nfft scalar points
 * output freqdata has nfft/2+1 complex points
 */
public void kiss_fftr(S) (kiss_fftr_cfg!S st, const(kiss_fft_scalar!S)* timedata, kiss_fft_cpx!S* freqdata)
if (is(S == float) || is(S == double) || is(S == real))
{
  // input buffer timedata is stored row-wise
  uint k, ncfft;
  kiss_fft_cpx!S fpnk, fpk, f1k, f2k, tw, tdc;

  if (st.substate.inverse) assert(0, "kiss fft usage error: improper alloc");

  ncfft = st.substate.nfft;

  // perform the parallel fft of two real signals packed in real,imag
  kiss_fft!S(st.substate, cast(const(kiss_fft_cpx!S)*)timedata, st.tmpbuf);
  /* The real part of the DC element of the frequency spectrum in st.tmpbuf
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

    mixin(C_ADD!("f1k", "fpk", "fpnk"));
    mixin(C_SUB!("f2k", "fpk", "fpnk"));
    mixin(C_MUL!("tw", "f2k", "st.super_twiddles[k-1]"));

    freqdata[k].r = mixin(HALF_OF!"f1k.r+tw.r");
    freqdata[k].i = mixin(HALF_OF!"f1k.i+tw.i");
    freqdata[ncfft-k].r = mixin(HALF_OF!"f1k.r-tw.r");
    freqdata[ncfft-k].i = mixin(HALF_OF!"tw.i-f1k.i");
  }
}


/** input freqdata has  nfft/2+1 complex points
 * output timedata has nfft scalar points
 */
public void kiss_fftri(S) (kiss_fftr_cfg!S st, const(kiss_fft_cpx!S)* freqdata, kiss_fft_scalar!S* timedata)
if (is(S == float) || is(S == double) || is(S == real))
{
  // input buffer timedata is stored row-wise
  if (st.substate.inverse == 0) assert(0, "kiss fft usage error: improper alloc");

  uint ncfft = st.substate.nfft;

  st.tmpbuf[0].r = freqdata[0].r+freqdata[ncfft].r;
  st.tmpbuf[0].i = freqdata[0].r-freqdata[ncfft].r;

  foreach (immutable uint k; 1..ncfft/2+1) {
    kiss_fft_cpx!S fnkc = void, fek = void, fok = void, tmp = void;
    kiss_fft_cpx!S fk = freqdata[k];
    fnkc.r = freqdata[ncfft-k].r;
    fnkc.i = -freqdata[ncfft-k].i;
    mixin(C_ADD!("fek", "fk", "fnkc"));
    mixin(C_SUB!("tmp", "fk", "fnkc"));
    mixin(C_MUL!("fok", "tmp", "st.super_twiddles[k-1]"));
    mixin(C_ADD!("st.tmpbuf[k]", "fek", "fok"));
    mixin(C_SUB!("st.tmpbuf[ncfft-k]", "fek", "fok"));
    st.tmpbuf[ncfft-k].i *= -1;
  }
  kiss_fft!S(st.substate, st.tmpbuf, cast(kiss_fft_cpx!S*)timedata);
}


/** for real ffts, we need an even size */
public uint kiss_fftr_next_fast_size_real (uint n) {
  pragma(inline, true);
  return kiss_fft_next_fast_size((n+1)>>1)<<1;
}


// ////////////////////////////////////////////////////////////////////////// //
enum MAXFACTORS = 32;
/* e.g. an fft of length 128 has 4 factors
 as far as kissfft is concerned
 4*4*4*2
 */

struct kiss_fft_state(S) if (is(S == float) || is(S == double) || is(S == real)) {
  uint nfft;
  uint inverse;
  uint[2*MAXFACTORS] factors;
  kiss_fft_cpx!S[1] twiddles;
}


// ////////////////////////////////////////////////////////////////////////// //
private void kf_bfly2(S) (kiss_fft_cpx!S* Fout, in usize fstride, const(kiss_fft_cfg!S) st, int m) {
  kiss_fft_cpx!S* Fout2;
  const(kiss_fft_cpx!S)* tw1 = st.twiddles.ptr;
  kiss_fft_cpx!S t;
  Fout2 = Fout+m;
  do {
    mixin(C_MUL!("t", "*Fout2", "*tw1"));
    tw1 += fstride;
    mixin(C_SUB!("*Fout2", "*Fout", "t"));
    mixin(C_ADDTO!("*Fout", "t"));
    ++Fout2;
    ++Fout;
  } while (--m);
}


private void kf_bfly4(S) (kiss_fft_cpx!S* Fout, in usize fstride, const(kiss_fft_cfg!S) st, in usize m) {
  const(kiss_fft_cpx!S)* tw1, tw2, tw3;
  kiss_fft_cpx!S[6] scratch = void;
  usize k = m;
  immutable usize m2 = 2*m;
  immutable usize m3 = 3*m;
  tw3 = tw2 = tw1 = st.twiddles.ptr;
  do {
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
      Fout[m].r = scratch[5].r-scratch[4].i;
      Fout[m].i = scratch[5].i+scratch[4].r;
      Fout[m3].r = scratch[5].r+scratch[4].i;
      Fout[m3].i = scratch[5].i-scratch[4].r;
    } else {
      Fout[m].r = scratch[5].r+scratch[4].i;
      Fout[m].i = scratch[5].i-scratch[4].r;
      Fout[m3].r = scratch[5].r-scratch[4].i;
      Fout[m3].i = scratch[5].i+scratch[4].r;
    }
    ++Fout;
  } while (--k);
}


private void kf_bfly3(S) (kiss_fft_cpx!S* Fout, in usize fstride, const(kiss_fft_cfg!S) st, usize m) {
  usize k = m;
  immutable usize m2 = 2*m;
  const(kiss_fft_cpx!S)* tw1, tw2;
  kiss_fft_cpx!S[5] scratch = void;
  kiss_fft_cpx!S epi3;
  epi3 = st.twiddles[fstride*m];
  tw1 = tw2 = st.twiddles.ptr;
  do {
    mixin(C_MUL!("scratch[1]", "Fout[m]", "*tw1"));
    mixin(C_MUL!("scratch[2]", "Fout[m2]", "*tw2"));

    mixin(C_ADD!("scratch[3]", "scratch[1]", "scratch[2]"));
    mixin(C_SUB!("scratch[0]", "scratch[1]", "scratch[2]"));
    tw1 += fstride;
    tw2 += fstride*2;

    Fout[m].r = Fout.r-mixin(HALF_OF!"scratch[3].r");
    Fout[m].i = Fout.i-mixin(HALF_OF!"scratch[3].i");

    mixin(C_MULBYSCALAR!("scratch[0]", "epi3.i"));

    mixin(C_ADDTO!("*Fout", "scratch[3]"));

    Fout[m2].r = Fout[m].r+scratch[0].i;
    Fout[m2].i = Fout[m].i-scratch[0].r;

    Fout[m].r -= scratch[0].i;
    Fout[m].i += scratch[0].r;

    ++Fout;
  } while (--k);
}


private void kf_bfly5(S) (kiss_fft_cpx!S* Fout, in usize fstride, const(kiss_fft_cfg!S) st, uint m) {
  kiss_fft_cpx!S* Fout0, Fout1, Fout2, Fout3, Fout4;
  kiss_fft_cpx!S[13] scratch = void;
  const(kiss_fft_cpx!S)* twiddles = st.twiddles.ptr;
  const(kiss_fft_cpx!S)* tw;
  kiss_fft_cpx!S ya = twiddles[fstride*m];
  kiss_fft_cpx!S yb = twiddles[fstride*2*m];

  Fout0 = Fout;
  Fout1 = Fout0+m;
  Fout2 = Fout0+2*m;
  Fout3 = Fout0+3*m;
  Fout4 = Fout0+4*m;

  tw = st.twiddles.ptr;
  foreach (immutable uint u; 0..m) {
    scratch[0] = *Fout0;

    mixin(C_MUL!("scratch[1]", "*Fout1", "tw[u*fstride]"));
    mixin(C_MUL!("scratch[2]", "*Fout2", "tw[2*u*fstride]"));
    mixin(C_MUL!("scratch[3]", "*Fout3", "tw[3*u*fstride]"));
    mixin(C_MUL!("scratch[4]", "*Fout4", "tw[4*u*fstride]"));

    mixin(C_ADD!("scratch[7]", "scratch[1]", "scratch[4]"));
    mixin(C_SUB!("scratch[10]", "scratch[1]", "scratch[4]"));
    mixin(C_ADD!("scratch[8]", "scratch[2]", "scratch[3]"));
    mixin(C_SUB!("scratch[9]", "scratch[2]", "scratch[3]"));

    Fout0.r += scratch[7].r+scratch[8].r;
    Fout0.i += scratch[7].i+scratch[8].i;

    scratch[5].r = scratch[0].r+scratch[7].r*ya.r+scratch[8].r*yb.r;
    scratch[5].i = scratch[0].i+scratch[7].i*ya.r+scratch[8].i*yb.r;

    scratch[6].r =  scratch[10].i*ya.i+scratch[9].i*yb.i;
    scratch[6].i = -scratch[10].r*ya.i-scratch[9].r*yb.i;

    mixin(C_SUB!("*Fout1", "scratch[5]", "scratch[6]"));
    mixin(C_ADD!("*Fout4", "scratch[5]", "scratch[6]"));

    scratch[11].r = scratch[0].r+scratch[7].r*yb.r+scratch[8].r*ya.r;
    scratch[11].i = scratch[0].i+scratch[7].i*yb.r+scratch[8].i*ya.r;
    scratch[12].r = -scratch[10].i*yb.i+scratch[9].i*ya.i;
    scratch[12].i =  scratch[10].r*yb.i-scratch[9].r*ya.i;

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
private void kf_bfly_generic(S) (kiss_fft_cpx!S* Fout, in usize fstride, const(kiss_fft_cfg!S) st, uint m, uint p) {
  import core.stdc.stdlib : alloca;

  //uint q1, q;
  const(kiss_fft_cpx!S)* twiddles = st.twiddles.ptr;
  kiss_fft_cpx!S t;
  uint Norig = st.nfft;

  //kiss_fft_cpx* scratch = cast(kiss_fft_cpx*)KISS_FFT_TMP_ALLOC(kiss_fft_cpx.sizeof*p);
  kiss_fft_cpx!S* scratch = cast(kiss_fft_cpx!S*)alloca((kiss_fft_cpx!S).sizeof*p);

  foreach (immutable uint u; 0..m) {
    uint k = u;
    foreach (immutable uint q1; 0..p) {
      scratch[q1] = Fout[k];
      k += m;
    }

    k = u;
    foreach (immutable uint q1; 0..p) {
      uint twidx = 0;
      Fout[k] = scratch[0];
      foreach (immutable uint q; 1..p) {
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


private void kf_work(S) (kiss_fft_cpx!S* Fout, const(kiss_fft_cpx!S)* f, in usize fstride, uint in_stride, uint* factors, const(kiss_fft_cfg!S) st) {
  kiss_fft_cpx!S* Fout_beg = Fout;
  immutable uint p = *factors++; // the radix
  immutable uint m = *factors++; // stage's fft length/p
  const(kiss_fft_cpx!S)* Fout_end = Fout+p*m;

  version(kiss_fft_use_parallel) {
    // use threads at the top-level (not recursive)
    import std.parallelism;
    import std.range : iota;
    if (fstride == 1 && p <= 5) {
      // execute the p different work units in different threads
      foreach (uint k; parallel(iota(p))) {
        kf_work!S(Fout+k*m, f+fstride*in_stride*k, fstride*p, in_stride, factors, st);
      }
      // all threads have joined by this point
      switch (p) {
        case 2: kf_bfly2!S(Fout, fstride, st, m); break;
        case 3: kf_bfly3!S(Fout, fstride, st, m); break;
        case 4: kf_bfly4!S(Fout, fstride, st, m); break;
        case 5: kf_bfly5!S(Fout, fstride, st, m); break;
        default: kf_bfly_generic!S(Fout, fstride, st, m, p); break;
      }
      return;
    }
  }

  if (m == 1) {
    do {
      *Fout = *f;
      f += fstride*in_stride;
    } while (++Fout !is Fout_end);
  } else {
    do {
      // recursive call:
      // DFT of size m*p performed by doing
      // p instances of smaller DFTs of size m,
      // each one takes a decimated version of the input
      kf_work!S(Fout, f, fstride*p, in_stride, factors, st);
      f += fstride*in_stride;
    } while ((Fout += m) !is Fout_end);
  }

  Fout = Fout_beg;

  // recombine the p smaller DFTs
  switch (p) {
    case 2: kf_bfly2!S(Fout, fstride, st, m); break;
    case 3: kf_bfly3!S(Fout, fstride, st, m); break;
    case 4: kf_bfly4!S(Fout, fstride, st, m); break;
    case 5: kf_bfly5!S(Fout, fstride, st, m); break;
    default: kf_bfly_generic!S(Fout, fstride, st, m, p); break;
  }
}


/* facbuf is populated by p1, m1, p2, m2, ...
 * where
 *   p[i]*m[i] = m[i-1]
 *   m0 = n
 */
private void kf_factor(S) (uint n, uint* facbuf) {
  import std.math : floor, sqrt;
  immutable double floor_sqrt = floor(sqrt(cast(double)n));
  uint p = 4;
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


// ////////////////////////////////////////////////////////////////////////// //
// kissfft_guts
/*
  Explanation of macros dealing with complex math:

   C_MUL(m,a,b)         : m = a*b
   C_FIXDIV( c , div )  : if a fixed point impl., c /= div. noop otherwise
   C_SUB( res, a,b)     : res = a-b
   C_SUBFROM( res , a)  : res -= a
   C_ADDTO( res , a)    : res += a
 */
//enum S_MUL(string a, string b) = "(("~a~")*("~b~"))";
enum C_MUL(string m, string a, string b) =
  "{ ("~m~").r = ("~a~").r*("~b~").r-("~a~").i*("~b~").i;
     ("~m~").i = ("~a~").r*("~b~").i+("~a~").i*("~b~").r; }";
enum C_MULBYSCALAR(string c, string s) = " { ("~c~").r *= ("~s~"); ("~c~").i *= ("~s~"); }";

enum C_ADD(string res, string a, string b) = "{ ("~res~").r=("~a~").r+("~b~").r; ("~res~").i=("~a~").i+("~b~").i; }";
enum C_SUB(string res, string a, string b) = "{ ("~res~").r=("~a~").r-("~b~").r; ("~res~").i=("~a~").i-("~b~").i; }";
enum C_ADDTO(string res, string a) = "{ ("~res~").r += ("~a~").r; ("~res~").i += ("~a~").i; }";
enum C_SUBFROM(string res, string a) = "{ ("~res~").r -= ("~a~").r; ("~res~").i -= ("~a~").i; }";


//kiss_fft_scalar KISS_FFT_COS(T) (T phase) { import std.math : cos; return cos(phase); }
//kiss_fft_scalar KISS_FFT_SIN(T) (T phase) { import std.math : sin; return sin(phase); }
//kiss_fft_scalar HALF_OF (kiss_fft_scalar x) { return x*cast(kiss_fft_scalar)0.5; }
enum HALF_OF(string x) = "(cast(kiss_fft_scalar!S)(("~x~")*cast(kiss_fft_scalar!S)0.5))";

//enum kf_cexp(string x, string phase) = "{ ("~x~").r = KISS_FFT_COS("~phase~"); ("~x~").i = KISS_FFT_SIN("~phase~"); }";
enum kf_cexp(string x, string phase) = "{ import std.math : cos, sin; ("~x~").r = cos("~phase~"); ("~x~").i = sin("~phase~"); }";


/+
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

public alias kiss_fftnd_cfg_f = kiss_fftnd_state!float*; ///
public alias kiss_fftnd_cfg_d = kiss_fftnd_state!double*; ///

public template kiss_fftnd_cfg(T) if (is(T == float) || is(T == double) || is(T == real)) {
  alias kiss_fftnd_cfg = kiss_fftnd_state!T*;
}

struct kiss_fftnd_state(S)
if (is(S == float) || is(S == double) || is(S == real))
{
  uint dimprod; /* dimsum would be mighty tasty right now */
  uint ndims;
  uint* dims;
  kiss_fft_cfg!S* states; /* cfg states for each dimension */
  kiss_fft_cpx!S* tmpbuf; /* buffer capable of hold the entire input */
}


///
public kiss_fftnd_cfg!S kiss_fftnd_alloc(S) (const(uint)[] dims, KissFFT dir, void* mem=null, usize* lenmem=null)
if (is(S == float) || is(S == double) || is(S == real))
{
  import core.stdc.stdlib : malloc;

  if (dims.length < 1 || dims.length > ushort.max) return null;
  immutable uint ndims = cast(uint)dims.length;
  kiss_fftnd_cfg!S st = null;
  int dimprod = 1;
  usize memneeded = (kiss_fftnd_state!S).sizeof;
  ubyte* ptr;

  foreach (immutable uint i; 0..ndims) {
    usize sublen = 0;
    kiss_fft_alloc!S(dims[i], dir, null, &sublen);
    memneeded += sublen; /* st.states[i] */
    dimprod *= dims[i];
  }
  memneeded += int.sizeof*ndims;/*  st.dims */
  memneeded += (void*).sizeof*ndims;/* st.states  */
  memneeded += (kiss_fft_cpx!S).sizeof*dimprod; /* st.tmpbuf */

  if (lenmem is null) {
    /* allocate for the caller */
    st = cast(kiss_fftnd_cfg!S)malloc(memneeded);
  } else {
    /* initialize supplied buffer if big enough */
    if (*lenmem >= memneeded) st = cast(kiss_fftnd_cfg!S)mem;
    *lenmem = memneeded; /* tell caller how big struct is (or would be) */
  }
  if (st is null) return null; /* malloc failed or buffer too small */

  st.dimprod = dimprod;
  st.ndims = ndims;
  ptr = cast(ubyte*)(st+1);

  st.states = cast(kiss_fft_cfg!S*)ptr;
  ptr += (void*).sizeof*ndims;

  st.dims = cast(uint*)ptr;
  ptr += int.sizeof*ndims;

  st.tmpbuf = cast(kiss_fft_cpx!S*)ptr;
  ptr += (kiss_fft_cpx!S).sizeof*dimprod;

  foreach (immutable uint i; 0..ndims) {
    usize len;
    st.dims[i] = dims[i];
    kiss_fft_alloc!S(st.dims[i], dir, null, &len);
    st.states[i] = kiss_fft_alloc!S(st.dims[i], dir, ptr, &len);
    ptr += len;
  }

  return st;
}


///
public void kiss_fftnd_free(S) (ref kiss_fftnd_cfg!S p)
if (is(S == float) || is(S == double) || is(S == real))
{
  if (p !is null) {
    import core.stdc.stdlib : free;
    free(p);
    p = null;
  }
}


/**
This works by tackling one dimension at a time.

In effect,
Each stage starts out by reshaping the matrix into a DixSi 2d matrix.
A Di-sized fft is taken of each column, transposing the matrix as it goes.

Here's a 3-d example:
Take a 2x3x4 matrix, laid out in memory as a contiguous buffer
[ [ [ a b c d ] [ e f g h ] [ i j k l ] ]
 [ [ m n o p ] [ q r s t ] [ u v w x ] ] ]

Stage 0 ( D=2): treat the buffer as a 2x12 matrix
 [ [a b ... k l]
   [m n ... w x] ]

 FFT each column with size 2.
 Transpose the matrix at the same time using kiss_fft_stride.

 [ [ a+m a-m ]
   [ b+n b-n]
   ...
   [ k+w k-w ]
   [ l+x l-x ] ]

 Note fft([x y]) == [x+y x-y]

Stage 1 ( D=3) treats the buffer (the output of stage D=2) as an 3x8 matrix,
 [ [ a+m a-m b+n b-n c+o c-o d+p d-p ]
   [ e+q e-q f+r f-r g+s g-s h+t h-t ]
   [ i+u i-u j+v j-v k+w k-w l+x l-x ] ]

 And perform FFTs (size=3) on each of the columns as above, transposing
 the matrix as it goes.  The output of stage 1 is
     (Legend: ap = [ a+m e+q i+u ]
              am = [ a-m e-q i-u ] )

 [ [ sum(ap) fft(ap)[0] fft(ap)[1] ]
   [ sum(am) fft(am)[0] fft(am)[1] ]
   [ sum(bp) fft(bp)[0] fft(bp)[1] ]
   [ sum(bm) fft(bm)[0] fft(bm)[1] ]
   [ sum(cp) fft(cp)[0] fft(cp)[1] ]
   [ sum(cm) fft(cm)[0] fft(cm)[1] ]
   [ sum(dp) fft(dp)[0] fft(dp)[1] ]
   [ sum(dm) fft(dm)[0] fft(dm)[1] ]  ]

Stage 2 ( D=4) treats this buffer as a 4*6 matrix,
 [ [ sum(ap) fft(ap)[0] fft(ap)[1] sum(am) fft(am)[0] fft(am)[1] ]
   [ sum(bp) fft(bp)[0] fft(bp)[1] sum(bm) fft(bm)[0] fft(bm)[1] ]
   [ sum(cp) fft(cp)[0] fft(cp)[1] sum(cm) fft(cm)[0] fft(cm)[1] ]
   [ sum(dp) fft(dp)[0] fft(dp)[1] sum(dm) fft(dm)[0] fft(dm)[1] ]  ]

 Then FFTs each column, transposing as it goes.

 The resulting matrix is the 3d FFT of the 2x3x4 input matrix.

 Note as a sanity check that the first element of the final
 stage's output (DC term) is
 sum( [ sum(ap) sum(bp) sum(cp) sum(dp) ] )
 , i.e. the summation of all 24 input elements.

*/
public void kiss_fftnd(S) (kiss_fftnd_cfg!S st, const(kiss_fft_cpx!S)* fin, kiss_fft_cpx!S* fout)
if (is(S == float) || is(S == double) || is(S == real))
{
  import core.stdc.string : memcpy;

  const(kiss_fft_cpx!S)* bufin = fin;
  kiss_fft_cpx!S* bufout;

  /* arrange it so the last bufout == fout */
  if (st.ndims&1) {
    bufout = fout;
    if (fin is fout) {
      memcpy(st.tmpbuf, fin, (kiss_fft_cpx!S).sizeof*st.dimprod);
      bufin = st.tmpbuf;
    }
  } else {
    bufout = st.tmpbuf;
  }

  foreach (immutable uint k; 0..st.ndims) {
    uint curdim = st.dims[k];
    uint stride = st.dimprod/curdim;

    foreach (immutable uint i; 0..stride) {
      kiss_fft_stride!S(st.states[k], bufin+i, bufout+i*curdim, stride);
    }

    /* toggle back and forth between the two buffers */
    if (bufout is st.tmpbuf) {
      bufout = fout;
      bufin = st.tmpbuf;
    } else {
      bufout = st.tmpbuf;
      bufin = fout;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //

public alias kiss_fftndr_cfg_f = kiss_fftndr_state!float*; ///
public alias kiss_fftndr_cfg_d = kiss_fftndr_state!double*; ///

public template kiss_fftndr_cfg(T) if (is(T == float) || is(T == double) || is(T == real)) {
  alias kiss_fftndr_cfg = kiss_fftndr_state!T*;
}

struct kiss_fftndr_state(S)
if (is(S == float) || is(S == double) || is(S == real))
{
  uint dimReal;
  uint dimOther;
  kiss_fftr_cfg!S cfg_r;
  kiss_fftnd_cfg!S cfg_nd;
  ubyte* tmpbuf;
}


int prod (const(uint)[] dims) pure nothrow @trusted @nogc {
  uint x = 1;
  uint ndims = cast(uint)dims.length;
  const(uint)* dp = dims.ptr;
  while (ndims--) x *= *dp++;
  return x;
}

T MAX(T) (in T a, in T b) pure nothrow @safe @nogc { pragma(inline, true); return (a > b ? a : b); }


/*
dims[0] must be even

If you don't care to allocate space, use mem = lenmem = null
*/
public kiss_fftndr_cfg!S kiss_fftndr_alloc(S) (const(uint)[] dims, KissFFT dir, void* mem=null, usize* lenmem=null)
if (is(S == float) || is(S == double) || is(S == real))
{
  import core.stdc.stdlib : malloc, free;
  import core.stdc.string : memset;

  if (dims.length < 1 || dims.length > ushort.max) return null;
  immutable uint ndims = cast(uint)dims.length;

  kiss_fftndr_cfg!S st = null;
  usize nr = 0, nd = 0, ntmp = 0;
  uint dimReal = dims[ndims-1];
  uint dimOther = prod(dims[0..$-1]);
  usize memneeded;

  kiss_fftr_alloc!S(dimReal, dir, null, &nr);
  kiss_fftnd_alloc!S(dims[0..$-1], dir, null, &nd);
  ntmp =
      MAX(2*dimOther, dimReal+2)*(kiss_fft_scalar!S).sizeof+ // freq buffer for one pass
      dimOther*(dimReal+2)*(kiss_fft_scalar!S).sizeof; // large enough to hold entire input in case of in-place

  memneeded = (kiss_fftndr_state!S).sizeof+nr+nd+ntmp;

  bool malloced = false;
  if (lenmem is null) {
    st = cast(kiss_fftndr_cfg!S)malloc(memneeded);
    malloced = true;
  } else {
    if (*lenmem >= memneeded) st = cast(kiss_fftndr_cfg!S)mem;
    *lenmem = memneeded;
  }
  if (st is null) return null;

  memset(st, 0, memneeded);

  st.dimReal = dimReal;
  st.dimOther = dimOther;
  st.cfg_r = kiss_fftr_alloc!S(dimReal, dir, st+1, &nr);
  if (st.cfg_r is null) { if (malloced) free(st); return null; }
  st.cfg_nd = kiss_fftnd_alloc!S(dims[0..$-1], dir, (cast(ubyte*)st.cfg_r)+nr, &nd);
  if (st.cfg_nd is null) { if (malloced) free(st); return null; }
  st.tmpbuf = cast(ubyte*)st.cfg_nd+nd;
  assert(st.tmpbuf !is null);

  return st;
}


///
public void kiss_fftndr_free(S) (ref kiss_fftndr_cfg!S p)
if (is(S == float) || is(S == double) || is(S == real))
{
  if (p !is null) {
    import core.stdc.stdlib : free;
    free(p);
    p = null;
  }
}


/**
input timedata has dims[0] X dims[1] X ... X  dims[ndims-1] scalar points
output freqdata has dims[0] X dims[1] X ... X  dims[ndims-1]/2+1 complex points
*/
public void kiss_fftndr(S) (kiss_fftndr_cfg!S st, const(kiss_fft_scalar!S)* timedata, kiss_fft_cpx!S* freqdata)
if (is(S == float) || is(S == double) || is(S == real))
{
  uint dimReal = st.dimReal;
  uint dimOther = st.dimOther;
  uint nrbins = dimReal/2+1;

  kiss_fft_cpx!S* tmp1 = cast(kiss_fft_cpx!S*)st.tmpbuf;
  kiss_fft_cpx!S* tmp2 = tmp1+MAX(nrbins, dimOther);
  //assert(tmp1 !is null);

  // timedata is N0 x N1 x ... x Nk real

  // take a real chunk of data, fft it and place the output at correct intervals
  foreach (immutable uint k1; 0..dimOther) {
    kiss_fftr!S(st.cfg_r, timedata+k1*dimReal, tmp1); // tmp1 now holds nrbins complex points
    foreach (immutable uint k2; 0..nrbins) tmp2[k2*dimOther+k1] = tmp1[k2];
  }

  foreach (immutable uint k2; 0..nrbins) {
    kiss_fftnd!S(st.cfg_nd, tmp2+k2*dimOther, tmp1); // tmp1 now holds dimOther complex points
    foreach (immutable uint k1; 0..dimOther) freqdata[k1*nrbins+k2] = tmp1[k1];
  }
}


/**
input and output dimensions are the exact opposite of kiss_fftndr
*/
public void kiss_fftndri(S) (kiss_fftndr_cfg!S st, const(kiss_fft_cpx!S)* freqdata, kiss_fft_scalar!S* timedata)
if (is(S == float) || is(S == double) || is(S == real))
{
  int dimReal = st.dimReal;
  int dimOther = st.dimOther;
  int nrbins = dimReal/2+1;
  kiss_fft_cpx!S* tmp1 = cast(kiss_fft_cpx!S*)st.tmpbuf;
  kiss_fft_cpx!S* tmp2 = tmp1+MAX(nrbins, dimOther);

  foreach (immutable uint k2; 0..nrbins) {
    foreach (immutable uint k1; 0..dimOther) tmp1[k1] = freqdata[k1*(nrbins)+k2];
    kiss_fftnd!S(st.cfg_nd, tmp1, tmp2+k2*dimOther);
  }

  foreach (immutable uint k1; 0..dimOther) {
    foreach (immutable uint k2; 0..nrbins) tmp1[k2] = tmp2[k2*dimOther+k1];
    kiss_fftri!S(st.cfg_r, tmp1, timedata+k1*dimReal);
  }
}
