/*
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
module imdct15 is aliced;

/**
 * @file
 * Celt non-power of 2 iMDCT
 */
import avmem;
import avfft;
import opus;


struct IMDCT15Context {
  int fft_n;
  int len2;
  int len4;

  FFTComplex* tmp;

  FFTComplex* twiddle_exptab;

  FFTComplex*[6] exptab;

  /**
   * Calculate the middle half of the iMDCT
   */
  void function (IMDCT15Context* s, float* dst, const(float)* src, ptrdiff_t src_stride, float scale) imdct_half;
}

/+
/**
 * Init an iMDCT of the length 2 * 15 * (2^N)
 */
int ff_imdct15_init(IMDCT15Context **s, int N);

/**
 * Free an iMDCT.
 */
void ff_imdct15_uninit(IMDCT15Context **s);

void ff_imdct15_init_aarch64(IMDCT15Context *s);
+/


// minimal iMDCT size to make SIMD opts easier
enum CELT_MIN_IMDCT_SIZE = 120;

// complex c = a * b
enum CMUL3(string cre, string cim, string are, string aim, string bre, string bim) =
  ""~cre~" = "~are~" * "~bre~" - "~aim~" * "~bim~";\n"~
  ""~cim~" = "~are~" * "~bim~" + "~aim~" * "~bre~";\n";

enum CMUL(string c, string a, string b) = CMUL3!("("~c~").re", "("~c~").im", "("~a~").re", "("~a~").im", "("~b~").re", "("~b~").im");

// complex c = a * b
//         d = a * conjugate(b)
enum CMUL2(string c, string d, string a, string b) =
"{\n"~
  "float are = ("~a~").re;\n"~
  "float aim = ("~a~").im;\n"~
  "float bre = ("~b~").re;\n"~
  "float bim = ("~b~").im;\n"~
  "float rr  = are * bre;\n"~
  "float ri  = are * bim;\n"~
  "float ir  = aim * bre;\n"~
  "float ii  = aim * bim;\n"~
  "("~c~").re =  rr - ii;\n"~
  "("~c~").im =  ri + ir;\n"~
  "("~d~").re =  rr + ii;\n"~
  "("~d~").im = -ri + ir;\n"~
"}\n";

/*av_cold*/ void ff_imdct15_uninit (IMDCT15Context** ps) {
  IMDCT15Context* s = *ps;
  if (s is null) return;
  for (int i = 0; i < /*FF_ARRAY_ELEMS*/cast(int)s.exptab.length; ++i) av_freep(&s.exptab[i]);
  av_freep(&s.twiddle_exptab);
  av_freep(&s.tmp);
  av_freep(ps);
}

//static void imdct15_half (IMDCT15Context* s, float* dst, const(float)* src, ptrdiff_t stride, float scale);

/*av_cold*/ int ff_imdct15_init (IMDCT15Context** ps, int N) {
  import std.math : cos, sin, PI;

  IMDCT15Context* s;
  int len2 = 15*(1<<N);
  int len  = 2*len2;
  int i, j;

  if (len2 > CELT_MAX_FRAME_SIZE || len2 < CELT_MIN_IMDCT_SIZE) return AVERROR(EINVAL);

  s = av_mallocz!IMDCT15Context();
  if (!s) return AVERROR(ENOMEM);

  s.fft_n = N - 1;
  s.len4 = len2 / 2;
  s.len2 = len2;

  s.tmp = av_malloc_array!(typeof(*s.tmp))(len);
  if (!s.tmp) goto fail;

  s.twiddle_exptab  = av_malloc_array!(typeof(*s.twiddle_exptab))(s.len4);
  if (!s.twiddle_exptab) goto fail;

  for (i = 0; i < s.len4; i++) {
    s.twiddle_exptab[i].re = cos(2 * PI * (i + 0.125 + s.len4) / len);
    s.twiddle_exptab[i].im = sin(2 * PI * (i + 0.125 + s.len4) / len);
  }

  for (i = 0; i < /*FF_ARRAY_ELEMS*/cast(int)s.exptab.length; i++) {
    int NN = 15 * (1 << i);
    s.exptab[i] = av_malloc!(typeof(*s.exptab[i]))(FFMAX(NN, 19));
    if (!s.exptab[i]) goto fail;
    for (j = 0; j < NN; j++) {
      s.exptab[i][j].re = cos(2 * PI * j / NN);
      s.exptab[i][j].im = sin(2 * PI * j / NN);
    }
  }

  // wrap around to simplify fft15
  for (j = 15; j < 19; j++) s.exptab[0][j] = s.exptab[0][j - 15];

  s.imdct_half = &imdct15_half;

  //if (ARCH_AARCH64) ff_imdct15_init_aarch64(s);

  *ps = s;

  return 0;

fail:
  ff_imdct15_uninit(&s);
  return AVERROR(ENOMEM);
}


private void fft5(FFTComplex* out_, const(FFTComplex)* in_, ptrdiff_t stride) {
  // [0] = exp(2 * i * pi / 5), [1] = exp(2 * i * pi * 2 / 5)
  static immutable FFTComplex[2] fact = [ { 0.30901699437494745,  0.95105651629515353 },
                                          { -0.80901699437494734, 0.58778525229247325 } ];

  FFTComplex[4][4] z;

  mixin(CMUL2!("z[0][0]", "z[0][3]", "in_[1 * stride]", "fact[0]"));
  mixin(CMUL2!("z[0][1]", "z[0][2]", "in_[1 * stride]", "fact[1]"));
  mixin(CMUL2!("z[1][0]", "z[1][3]", "in_[2 * stride]", "fact[0]"));
  mixin(CMUL2!("z[1][1]", "z[1][2]", "in_[2 * stride]", "fact[1]"));
  mixin(CMUL2!("z[2][0]", "z[2][3]", "in_[3 * stride]", "fact[0]"));
  mixin(CMUL2!("z[2][1]", "z[2][2]", "in_[3 * stride]", "fact[1]"));
  mixin(CMUL2!("z[3][0]", "z[3][3]", "in_[4 * stride]", "fact[0]"));
  mixin(CMUL2!("z[3][1]", "z[3][2]", "in_[4 * stride]", "fact[1]"));

  out_[0].re = in_[0].re + in_[stride].re + in_[2 * stride].re + in_[3 * stride].re + in_[4 * stride].re;
  out_[0].im = in_[0].im + in_[stride].im + in_[2 * stride].im + in_[3 * stride].im + in_[4 * stride].im;

  out_[1].re = in_[0].re + z[0][0].re + z[1][1].re + z[2][2].re + z[3][3].re;
  out_[1].im = in_[0].im + z[0][0].im + z[1][1].im + z[2][2].im + z[3][3].im;

  out_[2].re = in_[0].re + z[0][1].re + z[1][3].re + z[2][0].re + z[3][2].re;
  out_[2].im = in_[0].im + z[0][1].im + z[1][3].im + z[2][0].im + z[3][2].im;

  out_[3].re = in_[0].re + z[0][2].re + z[1][0].re + z[2][3].re + z[3][1].re;
  out_[3].im = in_[0].im + z[0][2].im + z[1][0].im + z[2][3].im + z[3][1].im;

  out_[4].re = in_[0].re + z[0][3].re + z[1][2].re + z[2][1].re + z[3][0].re;
  out_[4].im = in_[0].im + z[0][3].im + z[1][2].im + z[2][1].im + z[3][0].im;
}

private void fft15 (IMDCT15Context* s, FFTComplex* out_, const(FFTComplex)* in_, ptrdiff_t stride) {
  const(FFTComplex)* exptab = s.exptab[0];
  FFTComplex[5] tmp;
  FFTComplex[5] tmp1;
  FFTComplex[5] tmp2;
  int k;

  fft5(tmp.ptr,  in_,              stride * 3);
  fft5(tmp1.ptr, in_ +     stride, stride * 3);
  fft5(tmp2.ptr, in_ + 2 * stride, stride * 3);

  for (k = 0; k < 5; k++) {
    FFTComplex t1, t2;

    mixin(CMUL!("t1", "tmp1[k]", "exptab[k]"));
    mixin(CMUL!("t2", "tmp2[k]", "exptab[2 * k]"));
    out_[k].re = tmp[k].re + t1.re + t2.re;
    out_[k].im = tmp[k].im + t1.im + t2.im;

    mixin(CMUL!("t1", "tmp1[k]", "exptab[k + 5]"));
    mixin(CMUL!("t2", "tmp2[k]", "exptab[2 * (k + 5)]"));
    out_[k + 5].re = tmp[k].re + t1.re + t2.re;
    out_[k + 5].im = tmp[k].im + t1.im + t2.im;

    mixin(CMUL!("t1", "tmp1[k]", "exptab[k + 10]"));
    mixin(CMUL!("t2", "tmp2[k]", "exptab[2 * k + 5]"));
    out_[k + 10].re = tmp[k].re + t1.re + t2.re;
    out_[k + 10].im = tmp[k].im + t1.im + t2.im;
  }
}

/*
* FFT of the length 15 * (2^N)
*/
private void fft_calc (IMDCT15Context* s, FFTComplex* out_, const(FFTComplex)* in_, int N, ptrdiff_t stride) {
  if (N) {
    const(FFTComplex)* exptab = s.exptab[N];
    const int len2 = 15 * (1 << (N - 1));
    int k;

    fft_calc(s, out_,        in_,          N - 1, stride * 2);
    fft_calc(s, out_ + len2, in_ + stride, N - 1, stride * 2);

    for (k = 0; k < len2; k++) {
      FFTComplex t;

      mixin(CMUL!("t", "out_[len2 + k]", "exptab[k]"));

      out_[len2 + k].re = out_[k].re - t.re;
      out_[len2 + k].im = out_[k].im - t.im;

      out_[k].re += t.re;
      out_[k].im += t.im;
    }
  } else {
    fft15(s, out_, in_, stride);
  }
}

private void imdct15_half (IMDCT15Context* s, float* dst, const(float)* src, ptrdiff_t stride, float scale) {
  FFTComplex *z = cast(FFTComplex *)dst;
  const int len8 = s.len4 / 2;
  const(float)* in1 = src;
  const(float)* in2 = src + (s.len2 - 1) * stride;
  int i;

  for (i = 0; i < s.len4; i++) {
    FFTComplex tmp = { *in2, *in1 };
    mixin(CMUL!("s.tmp[i]", "tmp", "s.twiddle_exptab[i]"));
    in1 += 2 * stride;
    in2 -= 2 * stride;
  }

  fft_calc(s, z, s.tmp, s.fft_n, 1);

  for (i = 0; i < len8; i++) {
    float r0, i0, r1, i1;

    mixin(CMUL3!("r0", "i1", "z[len8 - i - 1].im", "z[len8 - i - 1].re", "s.twiddle_exptab[len8 - i - 1].im", "s.twiddle_exptab[len8 - i - 1].re"));
    mixin(CMUL3!("r1", "i0", "z[len8 + i].im",     "z[len8 + i].re",     "s.twiddle_exptab[len8 + i].im",     "s.twiddle_exptab[len8 + i].re"));
    z[len8 - i - 1].re = scale * r0;
    z[len8 - i - 1].im = scale * i0;
    z[len8 + i].re     = scale * r1;
    z[len8 + i].im     = scale * i1;
  }
}
