// jpge.cpp - C++ class for JPEG compression.
// Public domain, Rich Geldreich <richgel99@gmail.com>
// Alex Evans: Added RGBA support, linear memory allocator.
// v1.01, Dec. 18, 2010 - Initial release
// v1.02, Apr. 6, 2011 - Removed 2x2 ordered dither in H2V1 chroma subsampling method load_block_16_8_8(). (The rounding factor was 2, when it should have been 1. Either way, it wasn't helping.)
// v1.03, Apr. 16, 2011 - Added support for optimized Huffman code tables, optimized dynamic memory allocation down to only 1 alloc.
//                        Also from Alex Evans: Added RGBA support, linear memory allocator (no longer needed in v1.03).
// v1.04, May. 19, 2012: Forgot to set m_pFile ptr to null in cfile_stream::close(). Thanks to Owen Kaluza for reporting this bug.
//                       Code tweaks to fix VS2008 static code analysis warnings (all looked harmless).
//                       Code review revealed method load_block_16_8_8() (used for the non-default H2V1 sampling mode to downsample chroma) somehow didn't get the rounding factor fix from v1.02.
// D translation by Ketmar // Invisible Vector
//
// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.
//
// In jurisdictions that recognize copyright laws, the author or authors
// of this software dedicate any and all copyright interest in the
// software to the public domain. We make this dedication for the benefit
// of the public at large and to the detriment of our heirs and
// successors. We intend this dedication to be an overt act of
// relinquishment in perpetuity of all present and future rights to this
// software under copyright law.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// For more information, please refer to <http://unlicense.org/>
/**
 * Writes a JPEG image to a file or stream.
 * num_channels must be 1 (Y), 3 (RGB), 4 (RGBA), image pitch must be width*num_channels.
 * note that alpha will not be stored in jpeg file.
 */
module iv.jpege is aliced;

public:
// ////////////////////////////////////////////////////////////////////////// //
// JPEG chroma subsampling factors. Y_ONLY (grayscale images) and H2V2 (color images) are the most common.
enum JpegSubsampling { Y_ONLY = 0, H1V1 = 1, H2V1 = 2, H2V2 = 3 }

// JPEG compression parameters structure.
public struct JpegParams {
  // Quality: 1-100, higher is better. Typical values are around 50-95.
  int quality = 85;

  // subsampling:
  // 0 = Y (grayscale) only
  // 1 = YCbCr, no subsampling (H1V1, YCbCr 1x1x1, 3 blocks per MCU)
  // 2 = YCbCr, H2V1 subsampling (YCbCr 2x1x1, 4 blocks per MCU)
  // 3 = YCbCr, H2V2 subsampling (YCbCr 4x1x1, 6 blocks per MCU-- very common)
  JpegSubsampling subsampling = JpegSubsampling.H2V2;

  // Disables CbCr discrimination - only intended for testing.
  // If true, the Y quantization table is also used for the CbCr channels.
  bool noChromaDiscrimFlag = false;

  bool twoPass = true;

  bool check () const pure nothrow @safe @nogc {
    if (quality < 1 || quality > 100) return false;
    if (cast(uint)subsampling > cast(uint)JpegSubsampling.H2V2) return false;
    return true;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// Writes JPEG image to file.
/// num_channels must be 1 (Y), 3 (RGB), 4 (RGBA), image pitch must be width*num_channels.
/// note that alpha will not be stored in jpeg file.
bool compress_image_to_jpeg_stream() (scope jpeg_encoder.WriteFunc wfn, int width, int height, int num_channels, const(ubyte)[] pImage_data) { return compress_image_to_jpeg_stream(wfn, width, height, num_channels, pImage_data, JpegParams()); }

/// Writes JPEG image to file.
/// num_channels must be 1 (Y), 3 (RGB), 4 (RGBA), image pitch must be width*num_channels.
/// note that alpha will not be stored in jpeg file.
bool compress_image_to_jpeg_stream() (scope jpeg_encoder.WriteFunc wfn, int width, int height, int num_channels, const(ubyte)[] pImage_data, in auto ref JpegParams comp_params) {
  jpeg_encoder dst_image;
  if (!dst_image.setup(wfn, width, height, num_channels, comp_params)) return false;
  for (uint pass_index = 0; pass_index < dst_image.total_passes(); pass_index++) {
    for (int i = 0; i < height; i++) {
      const(ubyte)* pBuf = pImage_data.ptr+i*width*num_channels;
      if (!dst_image.process_scanline(pBuf)) return false;
    }
    if (!dst_image.process_scanline(null)) return false;
  }
  dst_image.deinit();
  //return dst_stream.close();
  return true;
}


/// Writes JPEG image to file.
/// num_channels must be 1 (Y), 3 (RGB), 4 (RGBA), image pitch must be width*num_channels.
/// note that alpha will not be stored in jpeg file.
bool compress_image_to_jpeg_file (const(char)[] fname, int width, int height, int num_channels, const(ubyte)[] pImage_data) { return compress_image_to_jpeg_file(fname, width, height, num_channels, pImage_data, JpegParams()); }

/// Writes JPEG image to file.
/// num_channels must be 1 (Y), 3 (RGB), 4 (RGBA), image pitch must be width*num_channels.
/// note that alpha will not be stored in jpeg file.
bool compress_image_to_jpeg_file() (const(char)[] fname, int width, int height, int num_channels, const(ubyte)[] pImage_data, in auto ref JpegParams comp_params) {
  import std.internal.cstring;
  import core.stdc.stdio : FILE, fopen, fclose, fwrite;
  FILE* fl = fopen(fname.tempCString, "wb");
  if (fl is null) return false;
  scope(exit) if (fl !is null) fclose(fl);
  auto res = compress_image_to_jpeg_stream(
    delegate bool (const(void)[] buf) {
      if (fwrite(buf.ptr, 1, buf.length, fl) != buf.length) return false;
      return true;
    }, width, height, num_channels, pImage_data, comp_params);
  if (res) {
    if (fclose(fl) != 0) res = false;
    fl = null;
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
private:
nothrow @trusted @nogc {
auto JPGE_MIN(T) (T a, T b) pure nothrow @safe @nogc { pragma(inline, true); return (a < b ? a : b); }
auto JPGE_MAX(T) (T a, T b) pure nothrow @safe @nogc { pragma(inline, true); return (a > b ? a : b); }

void *jpge_malloc (usize nSize) { import core.stdc.stdlib : malloc; return malloc(nSize); }
void jpge_free (void *p) { import core.stdc.stdlib : free; if (p !is null) free(p); }


// Various JPEG enums and tables.
enum { M_SOF0 = 0xC0, M_DHT = 0xC4, M_SOI = 0xD8, M_EOI = 0xD9, M_SOS = 0xDA, M_DQT = 0xDB, M_APP0 = 0xE0 }
enum { DC_LUM_CODES = 12, AC_LUM_CODES = 256, DC_CHROMA_CODES = 12, AC_CHROMA_CODES = 256, MAX_HUFF_SYMBOLS = 257, MAX_HUFF_CODESIZE = 32 }

static immutable ubyte[64] s_zag = [ 0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63 ];
static immutable short[64] s_std_lum_quant = [ 16,11,12,14,12,10,16,14,13,14,18,17,16,19,24,40,26,24,22,22,24,49,35,37,29,40,58,51,61,60,57,51,56,55,64,72,92,78,64,68,87,69,55,56,80,109,81,87,95,98,103,104,103,62,77,113,121,112,100,120,92,101,103,99 ];
static immutable short[64] s_std_croma_quant = [ 17,18,18,24,21,24,47,26,26,47,99,66,56,66,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99 ];
static immutable ubyte[17] s_dc_lum_bits = [ 0,0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0 ];
static immutable ubyte[DC_LUM_CODES] s_dc_lum_val = [ 0,1,2,3,4,5,6,7,8,9,10,11 ];
static immutable ubyte[17] s_ac_lum_bits = [ 0,0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,0x7d ];
static immutable ubyte[AC_LUM_CODES] s_ac_lum_val = [
  0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,0x21,0x31,0x41,0x06,0x13,0x51,0x61,0x07,0x22,0x71,0x14,0x32,0x81,0x91,0xa1,0x08,0x23,0x42,0xb1,0xc1,0x15,0x52,0xd1,0xf0,
  0x24,0x33,0x62,0x72,0x82,0x09,0x0a,0x16,0x17,0x18,0x19,0x1a,0x25,0x26,0x27,0x28,0x29,0x2a,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,0x49,
  0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x83,0x84,0x85,0x86,0x87,0x88,0x89,
  0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,0xc4,0xc5,
  0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe1,0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
  0xf9,0xfa
];
static immutable ubyte[17] s_dc_chroma_bits = [ 0,0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0 ];
static immutable ubyte[DC_CHROMA_CODES] s_dc_chroma_val = [ 0,1,2,3,4,5,6,7,8,9,10,11 ];
static immutable ubyte[17] s_ac_chroma_bits = [ 0,0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,0x77 ];
static immutable ubyte[AC_CHROMA_CODES] s_ac_chroma_val = [
  0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91,0xa1,0xb1,0xc1,0x09,0x23,0x33,0x52,0xf0,
  0x15,0x62,0x72,0xd1,0x0a,0x16,0x24,0x34,0xe1,0x25,0xf1,0x17,0x18,0x19,0x1a,0x26,0x27,0x28,0x29,0x2a,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,
  0x49,0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x82,0x83,0x84,0x85,0x86,0x87,
  0x88,0x89,0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,
  0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
  0xf9,0xfa
];

// Low-level helper functions.
//template <class T> inline void clear_obj(T &obj) { memset(&obj, 0, sizeof(obj)); }

enum YR = 19595, YG = 38470, YB = 7471, CB_R = -11059, CB_G = -21709, CB_B = 32768, CR_R = 32768, CR_G = -27439, CR_B = -5329; // int
//ubyte clamp (int i) { if (cast(uint)(i) > 255U) { if (i < 0) i = 0; else if (i > 255) i = 255; } return cast(ubyte)(i); }
ubyte clamp() (int i) { pragma(inline, true); return cast(ubyte)(cast(uint)i > 255 ? (((~i)>>31)&0xFF) : i); }

void RGB_to_YCC (ubyte* pDst, const(ubyte)* pSrc, int num_pixels) {
  for (; num_pixels; pDst += 3, pSrc += 3, --num_pixels) {
    immutable int r = pSrc[0], g = pSrc[1], b = pSrc[2];
    pDst[0] = cast(ubyte)((r*YR+g*YG+b*YB+32768)>>16);
    pDst[1] = clamp(128+((r*CB_R+g*CB_G+b*CB_B+32768)>>16));
    pDst[2] = clamp(128+((r*CR_R+g*CR_G+b*CR_B+32768)>>16));
  }
}

void RGB_to_Y (ubyte* pDst, const(ubyte)* pSrc, int num_pixels) {
  for (; num_pixels; ++pDst, pSrc += 3, --num_pixels) {
    pDst[0] = cast(ubyte)((pSrc[0]*YR+pSrc[1]*YG+pSrc[2]*YB+32768)>>16);
  }
}

void RGBA_to_YCC (ubyte* pDst, const(ubyte)* pSrc, int num_pixels) {
  for (; num_pixels; pDst += 3, pSrc += 4, --num_pixels) {
    immutable int r = pSrc[0], g = pSrc[1], b = pSrc[2];
    pDst[0] = cast(ubyte)((r*YR+g*YG+b*YB+32768)>>16);
    pDst[1] = clamp(128+((r*CB_R+g*CB_G+b*CB_B+32768)>>16));
    pDst[2] = clamp(128+((r*CR_R+g*CR_G+b*CR_B+32768)>>16));
  }
}

void RGBA_to_Y (ubyte* pDst, const(ubyte)* pSrc, int num_pixels) {
  for (; num_pixels; ++pDst, pSrc += 4, --num_pixels) {
    pDst[0] = cast(ubyte)((pSrc[0]*YR+pSrc[1]*YG+pSrc[2]*YB+32768)>>16);
  }
}

void Y_to_YCC (ubyte* pDst, const(ubyte)* pSrc, int num_pixels) {
  for (; num_pixels; pDst += 3, ++pSrc, --num_pixels) { pDst[0] = pSrc[0]; pDst[1] = 128; pDst[2] = 128; }
}

// Forward DCT - DCT derived from jfdctint.
enum { CONST_BITS = 13, ROW_BITS = 2 }
//#define DCT_DESCALE(x, n) (((x)+(((int)1)<<((n)-1)))>>(n))
int DCT_DESCALE() (int x, int n) { pragma(inline, true); return (((x)+((cast(int)1)<<((n)-1)))>>(n)); }
//#define DCT_MUL(var, c) (cast(short)(var)*cast(int)(c))

//#define DCT1D(s0, s1, s2, s3, s4, s5, s6, s7)
enum DCT1D = q{{
  int t0 = s0+s7, t7 = s0-s7, t1 = s1+s6, t6 = s1-s6, t2 = s2+s5, t5 = s2-s5, t3 = s3+s4, t4 = s3-s4;
  int t10 = t0+t3, t13 = t0-t3, t11 = t1+t2, t12 = t1-t2;
  int u1 = (cast(short)(t12+t13)*cast(int)(4433));
  s2 = u1+(cast(short)(t13)*cast(int)(6270));
  s6 = u1+(cast(short)(t12)*cast(int)(-15137));
  u1 = t4+t7;
  int u2 = t5+t6, u3 = t4+t6, u4 = t5+t7;
  int z5 = (cast(short)(u3+u4)*cast(int)(9633));
  t4 = (cast(short)(t4)*cast(int)(2446)); t5 = (cast(short)(t5)*cast(int)(16819));
  t6 = (cast(short)(t6)*cast(int)(25172)); t7 = (cast(short)(t7)*cast(int)(12299));
  u1 = (cast(short)(u1)*cast(int)(-7373)); u2 = (cast(short)(u2)*cast(int)(-20995));
  u3 = (cast(short)(u3)*cast(int)(-16069)); u4 = (cast(short)(u4)*cast(int)(-3196));
  u3 += z5; u4 += z5;
  s0 = t10+t11; s1 = t7+u1+u4; s3 = t6+u2+u3; s4 = t10-t11; s5 = t5+u2+u4; s7 = t4+u1+u3;
}};

void DCT2D (int* p) {
  int c;
  int* q = p;
  for (c = 7; c >= 0; --c, q += 8) {
    int s0 = q[0], s1 = q[1], s2 = q[2], s3 = q[3], s4 = q[4], s5 = q[5], s6 = q[6], s7 = q[7];
    //DCT1D(s0, s1, s2, s3, s4, s5, s6, s7);
    mixin(DCT1D);
    q[0] = s0<<ROW_BITS; q[1] = DCT_DESCALE(s1, CONST_BITS-ROW_BITS); q[2] = DCT_DESCALE(s2, CONST_BITS-ROW_BITS); q[3] = DCT_DESCALE(s3, CONST_BITS-ROW_BITS);
    q[4] = s4<<ROW_BITS; q[5] = DCT_DESCALE(s5, CONST_BITS-ROW_BITS); q[6] = DCT_DESCALE(s6, CONST_BITS-ROW_BITS); q[7] = DCT_DESCALE(s7, CONST_BITS-ROW_BITS);
  }
  for (q = p, c = 7; c >= 0; --c, ++q) {
    int s0 = q[0*8], s1 = q[1*8], s2 = q[2*8], s3 = q[3*8], s4 = q[4*8], s5 = q[5*8], s6 = q[6*8], s7 = q[7*8];
    //DCT1D(s0, s1, s2, s3, s4, s5, s6, s7);
    mixin(DCT1D);
    q[0*8] = DCT_DESCALE(s0, ROW_BITS+3); q[1*8] = DCT_DESCALE(s1, CONST_BITS+ROW_BITS+3); q[2*8] = DCT_DESCALE(s2, CONST_BITS+ROW_BITS+3); q[3*8] = DCT_DESCALE(s3, CONST_BITS+ROW_BITS+3);
    q[4*8] = DCT_DESCALE(s4, ROW_BITS+3); q[5*8] = DCT_DESCALE(s5, CONST_BITS+ROW_BITS+3); q[6*8] = DCT_DESCALE(s6, CONST_BITS+ROW_BITS+3); q[7*8] = DCT_DESCALE(s7, CONST_BITS+ROW_BITS+3);
  }
}

struct sym_freq { uint m_key, m_sym_index; }

// Radix sorts sym_freq[] array by 32-bit key m_key. Returns ptr to sorted values.
sym_freq* radix_sort_syms (uint num_syms, sym_freq* pSyms0, sym_freq* pSyms1) {
  const uint cMaxPasses = 4;
  uint[256*cMaxPasses] hist;
  //clear_obj(hist);
  for (uint i = 0; i < num_syms; i++) {
    uint freq = pSyms0[i].m_key;
    ++hist[freq&0xFF];
    ++hist[256+((freq>>8)&0xFF)];
    ++hist[256*2+((freq>>16)&0xFF)];
    ++hist[256*3+((freq>>24)&0xFF)];
  }
  sym_freq* pCur_syms = pSyms0;
  sym_freq* pNew_syms = pSyms1;
  uint total_passes = cMaxPasses; while (total_passes > 1 && num_syms == hist[(total_passes-1)*256]) --total_passes;
  uint[256] offsets;
  for (uint pass_shift = 0, pass = 0; pass < total_passes; ++pass, pass_shift += 8) {
    const(uint)* pHist = &hist[pass<<8];
    uint cur_ofs = 0;
    for (uint i = 0; i < 256; i++) { offsets[i] = cur_ofs; cur_ofs += pHist[i]; }
    for (uint i = 0; i < num_syms; i++) pNew_syms[offsets[(pCur_syms[i].m_key>>pass_shift)&0xFF]++] = pCur_syms[i];
    sym_freq* t = pCur_syms; pCur_syms = pNew_syms; pNew_syms = t;
  }
  return pCur_syms;
}

// calculate_minimum_redundancy() originally written by: Alistair Moffat, alistair@cs.mu.oz.au, Jyrki Katajainen, jyrki@diku.dk, November 1996.
void calculate_minimum_redundancy (sym_freq* A, int n) {
  int root, leaf, next, avbl, used, dpth;
  if (n == 0) return;
  if (n == 1) { A[0].m_key = 1; return; }
  A[0].m_key += A[1].m_key; root = 0; leaf = 2;
  for (next=1; next < n-1; next++)
  {
    if (leaf>=n || A[root].m_key<A[leaf].m_key) { A[next].m_key = A[root].m_key; A[root++].m_key = next; } else A[next].m_key = A[leaf++].m_key;
    if (leaf>=n || (root<next && A[root].m_key<A[leaf].m_key)) { A[next].m_key += A[root].m_key; A[root++].m_key = next; } else A[next].m_key += A[leaf++].m_key;
  }
  A[n-2].m_key = 0;
  for (next=n-3; next>=0; next--) A[next].m_key = A[A[next].m_key].m_key+1;
  avbl = 1; used = dpth = 0; root = n-2; next = n-1;
  while (avbl>0)
  {
    while (root >= 0 && cast(int)A[root].m_key == dpth) { used++; root--; }
    while (avbl>used) { A[next--].m_key = dpth; avbl--; }
    avbl = 2*used; dpth++; used = 0;
  }
}

// Limits canonical Huffman code table's max code size to max_code_size.
void huffman_enforce_max_code_size (int* pNum_codes, int code_list_len, int max_code_size) {
  if (code_list_len <= 1) return;
  for (int i = max_code_size+1; i <= MAX_HUFF_CODESIZE; i++) pNum_codes[max_code_size] += pNum_codes[i];
  uint total = 0;
  for (int i = max_code_size; i > 0; i--) total += ((cast(uint)pNum_codes[i])<<(max_code_size-i));
  while (total != (1UL<<max_code_size)) {
    pNum_codes[max_code_size]--;
    for (int i = max_code_size-1; i > 0; i--) {
      if (pNum_codes[i]) { pNum_codes[i]--; pNum_codes[i+1] += 2; break; }
    }
    total--;
  }
}
}


// ////////////////////////////////////////////////////////////////////////// //
// Lower level jpeg_encoder class - useful if more control is needed than the above helper functions.
struct jpeg_encoder {
public:
  alias WriteFunc = bool delegate (const(void)[] buf);

nothrow /*@trusted @nogc*/:
private:
  alias sample_array_t = int;

  WriteFunc m_pStream;
  JpegParams m_params;
  ubyte m_num_components;
  ubyte[3] m_comp_h_samp;
  ubyte[3] m_comp_v_samp;
  int m_image_x, m_image_y, m_image_bpp, m_image_bpl;
  int m_image_x_mcu, m_image_y_mcu;
  int m_image_bpl_xlt, m_image_bpl_mcu;
  int m_mcus_per_row;
  int m_mcu_x, m_mcu_y;
  ubyte*[16] m_mcu_lines;
  ubyte m_mcu_y_ofs;
  sample_array_t[64] m_sample_array;
  short[64] m_coefficient_array;
  int[64][2] m_quantization_tables;
  uint[256][4] m_huff_codes;
  ubyte[256][4] m_huff_code_sizes;
  ubyte[17][4] m_huff_bits;
  ubyte[256][4] m_huff_val;
  uint[256][4] m_huff_count;
  int[3] m_last_dc_val;
  enum JPGE_OUT_BUF_SIZE = 2048;
  ubyte[JPGE_OUT_BUF_SIZE] m_out_buf;
  ubyte* m_pOut_buf;
  uint m_out_buf_left;
  uint m_bit_buffer;
  uint m_bits_in;
  ubyte m_pass_num;
  bool m_all_stream_writes_succeeded = true;

private:
  // Generates an optimized offman table.
  void optimize_huffman_table (int table_num, int table_len) {
    sym_freq[MAX_HUFF_SYMBOLS] syms0;
    sym_freq[MAX_HUFF_SYMBOLS] syms1;
    syms0[0].m_key = 1; syms0[0].m_sym_index = 0;  // dummy symbol, assures that no valid code contains all 1's
    int num_used_syms = 1;
    const uint *pSym_count = &m_huff_count[table_num][0];
    for (int i = 0; i < table_len; i++) {
      if (pSym_count[i]) { syms0[num_used_syms].m_key = pSym_count[i]; syms0[num_used_syms++].m_sym_index = i+1; }
    }
    sym_freq* pSyms = radix_sort_syms(num_used_syms, syms0.ptr, syms1.ptr);
    calculate_minimum_redundancy(pSyms, num_used_syms);

    // Count the # of symbols of each code size.
    int[1+MAX_HUFF_CODESIZE] num_codes;
    //clear_obj(num_codes);
    for (int i = 0; i < num_used_syms; i++) num_codes[pSyms[i].m_key]++;

    enum JPGE_CODE_SIZE_LIMIT = 16u; // the maximum possible size of a JPEG Huffman code (valid range is [9,16] - 9 vs. 8 because of the dummy symbol)
    huffman_enforce_max_code_size(num_codes.ptr, num_used_syms, JPGE_CODE_SIZE_LIMIT);

    // Compute m_huff_bits array, which contains the # of symbols per code size.
    //clear_obj(m_huff_bits[table_num]);
    m_huff_bits[table_num][] = 0;
    for (int i = 1; i <= cast(int)JPGE_CODE_SIZE_LIMIT; i++) m_huff_bits[table_num][i] = cast(ubyte)(num_codes[i]);

    // Remove the dummy symbol added above, which must be in largest bucket.
    for (int i = JPGE_CODE_SIZE_LIMIT; i >= 1; i--) {
      if (m_huff_bits[table_num][i]) { m_huff_bits[table_num][i]--; break; }
    }

    // Compute the m_huff_val array, which contains the symbol indices sorted by code size (smallest to largest).
    for (int i = num_used_syms-1; i >= 1; i--) m_huff_val[table_num][num_used_syms-1-i] = cast(ubyte)(pSyms[i].m_sym_index-1);
  }

  bool put_obj(T) (T v) {
    try {
      return (m_pStream !is null && m_pStream((&v)[0..1]));
    } catch (Exception) {}
    return false;
  }

  bool put_buf() (const(void)* v, uint len) {
    try {
      return (m_pStream !is null && m_pStream(v[0..len]));
    } catch (Exception) {}
    return false;
  }

  // JPEG marker generation.
  void emit_byte (ubyte i) {
    m_all_stream_writes_succeeded = m_all_stream_writes_succeeded && put_obj(i);
  }

  void emit_word(uint i) {
    emit_byte(cast(ubyte)(i>>8));
    emit_byte(cast(ubyte)(i&0xFF));
  }

  void emit_marker (int marker) {
    emit_byte(cast(ubyte)(0xFF));
    emit_byte(cast(ubyte)(marker));
  }

  // Emit JFIF marker
  void emit_jfif_app0 () {
    emit_marker(M_APP0);
    emit_word(2+4+1+2+1+2+2+1+1);
    emit_byte(0x4A); emit_byte(0x46); emit_byte(0x49); emit_byte(0x46); /* Identifier: ASCII "JFIF" */
    emit_byte(0);
    emit_byte(1); /* Major version */
    emit_byte(1); /* Minor version */
    emit_byte(0); /* Density unit */
    emit_word(1);
    emit_word(1);
    emit_byte(0); /* No thumbnail image */
    emit_byte(0);
  }

  // Emit quantization tables
  void emit_dqt () {
    for (int i = 0; i < (m_num_components == 3 ? 2 : 1); i++) {
      emit_marker(M_DQT);
      emit_word(64+1+2);
      emit_byte(cast(ubyte)(i));
      for (int j = 0; j < 64; j++) emit_byte(cast(ubyte)(m_quantization_tables[i][j]));
    }
  }

  // Emit start of frame marker
  void emit_sof () {
    emit_marker(M_SOF0); /* baseline */
    emit_word(3*m_num_components+2+5+1);
    emit_byte(8); /* precision */
    emit_word(m_image_y);
    emit_word(m_image_x);
    emit_byte(m_num_components);
    for (int i = 0; i < m_num_components; i++) {
      emit_byte(cast(ubyte)(i+1)); /* component ID */
      emit_byte(cast(ubyte)((m_comp_h_samp[i]<<4)+m_comp_v_samp[i])); /* h and v sampling */
      emit_byte(i > 0); /* quant. table num */
    }
  }

  // Emit Huffman table.
  void emit_dht (ubyte* bits, ubyte* val, int index, bool ac_flag) {
    emit_marker(M_DHT);
    int length = 0;
    for (int i = 1; i <= 16; i++) length += bits[i];
    emit_word(length+2+1+16);
    emit_byte(cast(ubyte)(index+(ac_flag<<4)));
    for (int i = 1; i <= 16; i++) emit_byte(bits[i]);
    for (int i = 0; i < length; i++) emit_byte(val[i]);
  }

  // Emit all Huffman tables.
  void emit_dhts () {
    emit_dht(m_huff_bits[0+0].ptr, m_huff_val[0+0].ptr, 0, false);
    emit_dht(m_huff_bits[2+0].ptr, m_huff_val[2+0].ptr, 0, true);
    if (m_num_components == 3) {
      emit_dht(m_huff_bits[0+1].ptr, m_huff_val[0+1].ptr, 1, false);
      emit_dht(m_huff_bits[2+1].ptr, m_huff_val[2+1].ptr, 1, true);
    }
  }

  // emit start of scan
  void emit_sos () {
    emit_marker(M_SOS);
    emit_word(2*m_num_components+2+1+3);
    emit_byte(m_num_components);
    for (int i = 0; i < m_num_components; i++) {
      emit_byte(cast(ubyte)(i+1));
      if (i == 0)
        emit_byte((0<<4)+0);
      else
        emit_byte((1<<4)+1);
    }
    emit_byte(0); /* spectral selection */
    emit_byte(63);
    emit_byte(0);
  }

  // Emit all markers at beginning of image file.
  void emit_markers () {
    emit_marker(M_SOI);
    emit_jfif_app0();
    emit_dqt();
    emit_sof();
    emit_dhts();
    emit_sos();
  }

  // Compute the actual canonical Huffman codes/code sizes given the JPEG huff bits and val arrays.
  void compute_huffman_table (uint* codes, ubyte* code_sizes, ubyte* bits, ubyte* val) {
    import core.stdc.string : memset;

    int i, l, last_p, si;
    ubyte[257] huff_size;
    uint[257] huff_code;
    uint code;

    int p = 0;
    for (l = 1; l <= 16; l++)
      for (i = 1; i <= bits[l]; i++)
        huff_size[p++] = cast(ubyte)l;

    huff_size[p] = 0; last_p = p; // write sentinel

    code = 0; si = huff_size[0]; p = 0;

    while (huff_size[p])
    {
      while (huff_size[p] == si)
        huff_code[p++] = code++;
      code <<= 1;
      si++;
    }

    memset(codes, 0, codes[0].sizeof*256);
    memset(code_sizes, 0, code_sizes[0].sizeof*256);
    for (p = 0; p < last_p; p++)
    {
      codes[val[p]]      = huff_code[p];
      code_sizes[val[p]] = huff_size[p];
    }
  }

  // Quantization table generation.
  void compute_quant_table (int* pDst, const(short)* pSrc) {
    int q;
    if (m_params.quality < 50)
      q = 5000/m_params.quality;
    else
      q = 200-m_params.quality*2;
    for (int i = 0; i < 64; i++) {
      int j = *pSrc++; j = (j*q+50L)/100L;
      *pDst++ = JPGE_MIN(JPGE_MAX(j, 1), 255);
    }
  }

  // Higher-level methods.
  void first_pass_init () {
    import core.stdc.string : memset;
    m_bit_buffer = 0; m_bits_in = 0;
    memset(m_last_dc_val.ptr, 0, 3*m_last_dc_val[0].sizeof);
    m_mcu_y_ofs = 0;
    m_pass_num = 1;
  }

  bool second_pass_init () {
    compute_huffman_table(&m_huff_codes[0+0][0], &m_huff_code_sizes[0+0][0], m_huff_bits[0+0].ptr, m_huff_val[0+0].ptr);
    compute_huffman_table(&m_huff_codes[2+0][0], &m_huff_code_sizes[2+0][0], m_huff_bits[2+0].ptr, m_huff_val[2+0].ptr);
    if (m_num_components > 1)
    {
      compute_huffman_table(&m_huff_codes[0+1][0], &m_huff_code_sizes[0+1][0], m_huff_bits[0+1].ptr, m_huff_val[0+1].ptr);
      compute_huffman_table(&m_huff_codes[2+1][0], &m_huff_code_sizes[2+1][0], m_huff_bits[2+1].ptr, m_huff_val[2+1].ptr);
    }
    first_pass_init();
    emit_markers();
    m_pass_num = 2;
    return true;
  }

  bool jpg_open (int p_x_res, int p_y_res, int src_channels) {
    m_num_components = 3;
    switch (m_params.subsampling) {
      case JpegSubsampling.Y_ONLY:
        m_num_components = 1;
        m_comp_h_samp[0] = 1; m_comp_v_samp[0] = 1;
        m_mcu_x          = 8; m_mcu_y          = 8;
        break;
      case JpegSubsampling.H1V1:
        m_comp_h_samp[0] = 1; m_comp_v_samp[0] = 1;
        m_comp_h_samp[1] = 1; m_comp_v_samp[1] = 1;
        m_comp_h_samp[2] = 1; m_comp_v_samp[2] = 1;
        m_mcu_x          = 8; m_mcu_y          = 8;
        break;
      case JpegSubsampling.H2V1:
        m_comp_h_samp[0] = 2; m_comp_v_samp[0] = 1;
        m_comp_h_samp[1] = 1; m_comp_v_samp[1] = 1;
        m_comp_h_samp[2] = 1; m_comp_v_samp[2] = 1;
        m_mcu_x          = 16; m_mcu_y         = 8;
        break;
      case JpegSubsampling.H2V2:
        m_comp_h_samp[0] = 2; m_comp_v_samp[0] = 2;
        m_comp_h_samp[1] = 1; m_comp_v_samp[1] = 1;
        m_comp_h_samp[2] = 1; m_comp_v_samp[2] = 1;
        m_mcu_x          = 16; m_mcu_y         = 16;
        break;
      default: assert(0);
    }

    m_image_x        = p_x_res; m_image_y = p_y_res;
    m_image_bpp      = src_channels;
    m_image_bpl      = m_image_x*src_channels;
    m_image_x_mcu    = (m_image_x+m_mcu_x-1)&(~(m_mcu_x-1));
    m_image_y_mcu    = (m_image_y+m_mcu_y-1)&(~(m_mcu_y-1));
    m_image_bpl_xlt  = m_image_x*m_num_components;
    m_image_bpl_mcu  = m_image_x_mcu*m_num_components;
    m_mcus_per_row   = m_image_x_mcu/m_mcu_x;

    if ((m_mcu_lines[0] = cast(ubyte*)(jpge_malloc(m_image_bpl_mcu*m_mcu_y))) is null) return false;
    for (int i = 1; i < m_mcu_y; i++)
      m_mcu_lines[i] = m_mcu_lines[i-1]+m_image_bpl_mcu;

    compute_quant_table(m_quantization_tables[0].ptr, s_std_lum_quant.ptr);
    compute_quant_table(m_quantization_tables[1].ptr, (m_params.noChromaDiscrimFlag ? s_std_lum_quant.ptr : s_std_croma_quant.ptr));

    m_out_buf_left = JPGE_OUT_BUF_SIZE;
    m_pOut_buf = m_out_buf.ptr;

    if (m_params.twoPass)
    {
      //clear_obj(m_huff_count);
      import core.stdc.string : memset;
      memset(m_huff_count.ptr, 0, m_huff_count.sizeof);
      first_pass_init();
    }
    else
    {
      import core.stdc.string : memcpy;
      memcpy(m_huff_bits[0+0].ptr, s_dc_lum_bits.ptr, 17);    memcpy(m_huff_val[0+0].ptr, s_dc_lum_val.ptr, DC_LUM_CODES);
      memcpy(m_huff_bits[2+0].ptr, s_ac_lum_bits.ptr, 17);    memcpy(m_huff_val[2+0].ptr, s_ac_lum_val.ptr, AC_LUM_CODES);
      memcpy(m_huff_bits[0+1].ptr, s_dc_chroma_bits.ptr, 17); memcpy(m_huff_val[0+1].ptr, s_dc_chroma_val.ptr, DC_CHROMA_CODES);
      memcpy(m_huff_bits[2+1].ptr, s_ac_chroma_bits.ptr, 17); memcpy(m_huff_val[2+1].ptr, s_ac_chroma_val.ptr, AC_CHROMA_CODES);
      if (!second_pass_init()) return false;   // in effect, skip over the first pass
    }
    return m_all_stream_writes_succeeded;
  }

  void load_block_8_8_grey (int x) {
    ubyte *pSrc;
    sample_array_t *pDst = m_sample_array.ptr;
    x <<= 3;
    for (int i = 0; i < 8; i++, pDst += 8)
    {
      pSrc = m_mcu_lines[i]+x;
      pDst[0] = pSrc[0]-128; pDst[1] = pSrc[1]-128; pDst[2] = pSrc[2]-128; pDst[3] = pSrc[3]-128;
      pDst[4] = pSrc[4]-128; pDst[5] = pSrc[5]-128; pDst[6] = pSrc[6]-128; pDst[7] = pSrc[7]-128;
    }
  }

  void load_block_8_8 (int x, int y, int c) {
    ubyte *pSrc;
    sample_array_t *pDst = m_sample_array.ptr;
    x = (x*(8*3))+c;
    y <<= 3;
    for (int i = 0; i < 8; i++, pDst += 8)
    {
      pSrc = m_mcu_lines[y+i]+x;
      pDst[0] = pSrc[0*3]-128; pDst[1] = pSrc[1*3]-128; pDst[2] = pSrc[2*3]-128; pDst[3] = pSrc[3*3]-128;
      pDst[4] = pSrc[4*3]-128; pDst[5] = pSrc[5*3]-128; pDst[6] = pSrc[6*3]-128; pDst[7] = pSrc[7*3]-128;
    }
  }

  void load_block_16_8 (int x, int c) {
    ubyte* pSrc1;
    ubyte* pSrc2;
    sample_array_t *pDst = m_sample_array.ptr;
    x = (x*(16*3))+c;
    int a = 0, b = 2;
    for (int i = 0; i < 16; i += 2, pDst += 8)
    {
      pSrc1 = m_mcu_lines[i+0]+x;
      pSrc2 = m_mcu_lines[i+1]+x;
      pDst[0] = ((pSrc1[ 0*3]+pSrc1[ 1*3]+pSrc2[ 0*3]+pSrc2[ 1*3]+a)>>2)-128; pDst[1] = ((pSrc1[ 2*3]+pSrc1[ 3*3]+pSrc2[ 2*3]+pSrc2[ 3*3]+b)>>2)-128;
      pDst[2] = ((pSrc1[ 4*3]+pSrc1[ 5*3]+pSrc2[ 4*3]+pSrc2[ 5*3]+a)>>2)-128; pDst[3] = ((pSrc1[ 6*3]+pSrc1[ 7*3]+pSrc2[ 6*3]+pSrc2[ 7*3]+b)>>2)-128;
      pDst[4] = ((pSrc1[ 8*3]+pSrc1[ 9*3]+pSrc2[ 8*3]+pSrc2[ 9*3]+a)>>2)-128; pDst[5] = ((pSrc1[10*3]+pSrc1[11*3]+pSrc2[10*3]+pSrc2[11*3]+b)>>2)-128;
      pDst[6] = ((pSrc1[12*3]+pSrc1[13*3]+pSrc2[12*3]+pSrc2[13*3]+a)>>2)-128; pDst[7] = ((pSrc1[14*3]+pSrc1[15*3]+pSrc2[14*3]+pSrc2[15*3]+b)>>2)-128;
      int temp = a; a = b; b = temp;
    }
  }

  void load_block_16_8_8 (int x, int c) {
    ubyte *pSrc1;
    sample_array_t *pDst = m_sample_array.ptr;
    x = (x*(16*3))+c;
    for (int i = 0; i < 8; i++, pDst += 8) {
      pSrc1 = m_mcu_lines[i+0]+x;
      pDst[0] = ((pSrc1[ 0*3]+pSrc1[ 1*3])>>1)-128; pDst[1] = ((pSrc1[ 2*3]+pSrc1[ 3*3])>>1)-128;
      pDst[2] = ((pSrc1[ 4*3]+pSrc1[ 5*3])>>1)-128; pDst[3] = ((pSrc1[ 6*3]+pSrc1[ 7*3])>>1)-128;
      pDst[4] = ((pSrc1[ 8*3]+pSrc1[ 9*3])>>1)-128; pDst[5] = ((pSrc1[10*3]+pSrc1[11*3])>>1)-128;
      pDst[6] = ((pSrc1[12*3]+pSrc1[13*3])>>1)-128; pDst[7] = ((pSrc1[14*3]+pSrc1[15*3])>>1)-128;
    }
  }

  void load_quantized_coefficients (int component_num) {
    int *q = m_quantization_tables[component_num > 0].ptr;
    short *pDst = m_coefficient_array.ptr;
    for (int i = 0; i < 64; i++)
    {
      sample_array_t j = m_sample_array[s_zag[i]];
      if (j < 0)
      {
        if ((j = -j+(*q>>1)) < *q)
          *pDst++ = 0;
        else
          *pDst++ = cast(short)(-(j/ *q));
      }
      else
      {
        if ((j = j+(*q>>1)) < *q)
          *pDst++ = 0;
        else
          *pDst++ = cast(short)((j/ *q));
      }
      q++;
    }
  }

  void flush_output_buffer () {
    if (m_out_buf_left != JPGE_OUT_BUF_SIZE) m_all_stream_writes_succeeded = m_all_stream_writes_succeeded && put_buf(m_out_buf.ptr, JPGE_OUT_BUF_SIZE-m_out_buf_left);
    m_pOut_buf = m_out_buf.ptr;
    m_out_buf_left = JPGE_OUT_BUF_SIZE;
  }

  void put_bits (uint bits, uint len) {
    m_bit_buffer |= (cast(uint)bits<<(24-(m_bits_in += len)));
    while (m_bits_in >= 8) {
      ubyte c;
      //#define JPGE_PUT_BYTE(c) { *m_pOut_buf++ = (c); if (--m_out_buf_left == 0) flush_output_buffer(); }
      //JPGE_PUT_BYTE(c = (ubyte)((m_bit_buffer>>16)&0xFF));
      //if (c == 0xFF) JPGE_PUT_BYTE(0);
      c = cast(ubyte)((m_bit_buffer>>16)&0xFF);
      *m_pOut_buf++ = c;
      if (--m_out_buf_left == 0) flush_output_buffer();
      if (c == 0xFF) {
        *m_pOut_buf++ = 0;
        if (--m_out_buf_left == 0) flush_output_buffer();
      }
      m_bit_buffer <<= 8;
      m_bits_in -= 8;
    }
  }

  void code_coefficients_pass_one (int component_num) {
    if (component_num >= 3) return; // just to shut up static analysis
    int i, run_len, nbits, temp1;
    short *src = m_coefficient_array.ptr;
    uint *dc_count = (component_num ? m_huff_count[0+1].ptr : m_huff_count[0+0].ptr);
    uint *ac_count = (component_num ? m_huff_count[2+1].ptr : m_huff_count[2+0].ptr);

    temp1 = src[0]-m_last_dc_val[component_num];
    m_last_dc_val[component_num] = src[0];
    if (temp1 < 0) temp1 = -temp1;

    nbits = 0;
    while (temp1)
    {
      nbits++; temp1 >>= 1;
    }

    dc_count[nbits]++;
    for (run_len = 0, i = 1; i < 64; i++)
    {
      if ((temp1 = m_coefficient_array[i]) == 0)
        run_len++;
      else
      {
        while (run_len >= 16)
        {
          ac_count[0xF0]++;
          run_len -= 16;
        }
        if (temp1 < 0) temp1 = -temp1;
        nbits = 1;
        while (temp1 >>= 1) nbits++;
        ac_count[(run_len<<4)+nbits]++;
        run_len = 0;
      }
    }
    if (run_len) ac_count[0]++;
  }

  void code_coefficients_pass_two (int component_num) {
    int i, j, run_len, nbits, temp1, temp2;
    short *pSrc = m_coefficient_array.ptr;
    uint*[2] codes;
    ubyte*[2] code_sizes;

    if (component_num == 0)
    {
      codes[0] = m_huff_codes[0+0].ptr; codes[1] = m_huff_codes[2+0].ptr;
      code_sizes[0] = m_huff_code_sizes[0+0].ptr; code_sizes[1] = m_huff_code_sizes[2+0].ptr;
    }
    else
    {
      codes[0] = m_huff_codes[0+1].ptr; codes[1] = m_huff_codes[2+1].ptr;
      code_sizes[0] = m_huff_code_sizes[0+1].ptr; code_sizes[1] = m_huff_code_sizes[2+1].ptr;
    }

    temp1 = temp2 = pSrc[0]-m_last_dc_val[component_num];
    m_last_dc_val[component_num] = pSrc[0];

    if (temp1 < 0)
    {
      temp1 = -temp1; temp2--;
    }

    nbits = 0;
    while (temp1)
    {
      nbits++; temp1 >>= 1;
    }

    put_bits(codes[0][nbits], code_sizes[0][nbits]);
    if (nbits) put_bits(temp2&((1<<nbits)-1), nbits);

    for (run_len = 0, i = 1; i < 64; i++)
    {
      if ((temp1 = m_coefficient_array[i]) == 0)
        run_len++;
      else
      {
        while (run_len >= 16)
        {
          put_bits(codes[1][0xF0], code_sizes[1][0xF0]);
          run_len -= 16;
        }
        if ((temp2 = temp1) < 0)
        {
          temp1 = -temp1;
          temp2--;
        }
        nbits = 1;
        while (temp1 >>= 1)
          nbits++;
        j = (run_len<<4)+nbits;
        put_bits(codes[1][j], code_sizes[1][j]);
        put_bits(temp2&((1<<nbits)-1), nbits);
        run_len = 0;
      }
    }
    if (run_len)
      put_bits(codes[1][0], code_sizes[1][0]);
  }

  void code_block (int component_num) {
    DCT2D(m_sample_array.ptr);
    load_quantized_coefficients(component_num);
    if (m_pass_num == 1)
      code_coefficients_pass_one(component_num);
    else
      code_coefficients_pass_two(component_num);
  }

  void process_mcu_row () {
    if (m_num_components == 1)
    {
      for (int i = 0; i < m_mcus_per_row; i++)
      {
        load_block_8_8_grey(i); code_block(0);
      }
    }
    else if ((m_comp_h_samp[0] == 1) && (m_comp_v_samp[0] == 1))
    {
      for (int i = 0; i < m_mcus_per_row; i++)
      {
        load_block_8_8(i, 0, 0); code_block(0); load_block_8_8(i, 0, 1); code_block(1); load_block_8_8(i, 0, 2); code_block(2);
      }
    }
    else if ((m_comp_h_samp[0] == 2) && (m_comp_v_samp[0] == 1))
    {
      for (int i = 0; i < m_mcus_per_row; i++)
      {
        load_block_8_8(i*2+0, 0, 0); code_block(0); load_block_8_8(i*2+1, 0, 0); code_block(0);
        load_block_16_8_8(i, 1); code_block(1); load_block_16_8_8(i, 2); code_block(2);
      }
    }
    else if ((m_comp_h_samp[0] == 2) && (m_comp_v_samp[0] == 2))
    {
      for (int i = 0; i < m_mcus_per_row; i++)
      {
        load_block_8_8(i*2+0, 0, 0); code_block(0); load_block_8_8(i*2+1, 0, 0); code_block(0);
        load_block_8_8(i*2+0, 1, 0); code_block(0); load_block_8_8(i*2+1, 1, 0); code_block(0);
        load_block_16_8(i, 1); code_block(1); load_block_16_8(i, 2); code_block(2);
      }
    }
  }

  bool terminate_pass_one () {
    optimize_huffman_table(0+0, DC_LUM_CODES); optimize_huffman_table(2+0, AC_LUM_CODES);
    if (m_num_components > 1)
    {
      optimize_huffman_table(0+1, DC_CHROMA_CODES); optimize_huffman_table(2+1, AC_CHROMA_CODES);
    }
    return second_pass_init();
  }

  bool terminate_pass_two () {
    put_bits(0x7F, 7);
    flush_output_buffer();
    emit_marker(M_EOI);
    m_pass_num++; // purposely bump up m_pass_num, for debugging
    return true;
  }

  bool process_end_of_image () {
    if (m_mcu_y_ofs)
    {
      if (m_mcu_y_ofs < 16) // check here just to shut up static analysis
      {
        for (int i = m_mcu_y_ofs; i < m_mcu_y; i++) {
          import core.stdc.string : memcpy;
          memcpy(m_mcu_lines[i], m_mcu_lines[m_mcu_y_ofs-1], m_image_bpl_mcu);
        }
      }
      process_mcu_row();
    }

    if (m_pass_num == 1)
      return terminate_pass_one();
    else
      return terminate_pass_two();
  }

  void load_mcu (const(void)* pSrc) {
    import core.stdc.string : memcpy;
    const(ubyte)* Psrc = cast(const(ubyte)*)(pSrc);

    ubyte* pDst = m_mcu_lines[m_mcu_y_ofs]; // OK to write up to m_image_bpl_xlt bytes to pDst

    if (m_num_components == 1)
    {
      if (m_image_bpp == 4)
        RGBA_to_Y(pDst, Psrc, m_image_x);
      else if (m_image_bpp == 3)
        RGB_to_Y(pDst, Psrc, m_image_x);
      else
        memcpy(pDst, Psrc, m_image_x);
    }
    else
    {
      if (m_image_bpp == 4)
        RGBA_to_YCC(pDst, Psrc, m_image_x);
      else if (m_image_bpp == 3)
        RGB_to_YCC(pDst, Psrc, m_image_x);
      else
        Y_to_YCC(pDst, Psrc, m_image_x);
    }

    // Possibly duplicate pixels at end of scanline if not a multiple of 8 or 16
    if (m_num_components == 1) {
      import core.stdc.string : memset;
      memset(m_mcu_lines[m_mcu_y_ofs]+m_image_bpl_xlt, pDst[m_image_bpl_xlt-1], m_image_x_mcu-m_image_x);
    } else
    {
      const ubyte y = pDst[m_image_bpl_xlt-3+0], cb = pDst[m_image_bpl_xlt-3+1], cr = pDst[m_image_bpl_xlt-3+2];
      ubyte *q = m_mcu_lines[m_mcu_y_ofs]+m_image_bpl_xlt;
      for (int i = m_image_x; i < m_image_x_mcu; i++)
      {
        *q++ = y; *q++ = cb; *q++ = cr;
      }
    }

    if (++m_mcu_y_ofs == m_mcu_y)
    {
      process_mcu_row();
      m_mcu_y_ofs = 0;
    }
  }

  void clear() {
    m_mcu_lines[0] = null;
    m_pass_num = 0;
    m_all_stream_writes_succeeded = true;
  }


public:
  //this () { clear(); }
  ~this () { deinit(); }

  @disable this (this); // no copies

  // Initializes the compressor.
  // pStream: The stream object to use for writing compressed data.
  // comp_params - Compression parameters structure, defined above.
  // width, height  - Image dimensions.
  // channels - May be 1, or 3. 1 indicates grayscale, 3 indicates RGB source data.
  // Returns false on out of memory or if a stream write fails.
  bool setup() (WriteFunc pStream, int width, int height, int src_channels, in auto ref JpegParams comp_params) {
    deinit();
    if ((pStream is null || width < 1 || height < 1) || (src_channels != 1 && src_channels != 3 && src_channels != 4) || !comp_params.check()) return false;
    m_pStream = pStream;
    m_params = comp_params;
    return jpg_open(width, height, src_channels);
  }

  bool setup() (WriteFunc pStream, int width, int height, int src_channels) { return setup(pStream, width, height, src_channels, JpegParams()); }

  @property ref const(JpegParams) params () const pure nothrow @safe @nogc { pragma(inline, true); return m_params; }

  // Deinitializes the compressor, freeing any allocated memory. May be called at any time.
  void deinit () {
    jpge_free(m_mcu_lines[0]);
    clear();
  }

  @property uint total_passes () const pure nothrow @safe @nogc { pragma(inline, true); return (m_params.twoPass ? 2 : 1); }
  @property uint cur_pass () const pure nothrow @safe @nogc { pragma(inline, true); return m_pass_num; }

  // Call this method with each source scanline.
  // width*src_channels bytes per scanline is expected (RGB or Y format).
  // You must call with null after all scanlines are processed to finish compression.
  // Returns false on out of memory or if a stream write fails.
  bool process_scanline (const(void)* pScanline) {
    if (m_pass_num < 1 || m_pass_num > 2) return false;
    if (m_all_stream_writes_succeeded) {
      if (pScanline is null) {
        if (!process_end_of_image()) return false;
      } else {
        load_mcu(pScanline);
      }
    }
    return m_all_stream_writes_succeeded;
  }
}
