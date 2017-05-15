// Separable filtering image rescaler v2.21, Rich Geldreich - richgel99@gmail.com
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
//
// Feb. 1996: Creation, losely based on a heavily bugfixed version of Schumacher's resampler in Graphics Gems 3.
// Oct. 2000: Ported to C++, tweaks.
// May 2001: Continous to discrete mapping, box filter tweaks.
// March 9, 2002: Kaiser filter grabbed from Jonathan Blow's GD magazine mipmap sample code.
// Sept. 8, 2002: Comments cleaned up a bit.
// Dec. 31, 2008: v2.2: Bit more cleanup, released as public domain.
// June 4, 2012: v2.21: Switched to unlicense.org, integrated GCC fixes supplied by Peter Nagy <petern@crytek.com>, Anteru at anteru.net, and clay@coge.net,
// added Codeblocks project (for testing with MinGW and GCC), VS2008 static code analysis pass.
// float or double
module iv.iresample is aliced;

import arsd.color;


// ////////////////////////////////////////////////////////////////////////// //
enum RESAMPLER_DEFAULT_FILTER = "lanczos4";
enum RESAMPLER_MAX_DIMENSION = 16384;


// ////////////////////////////////////////////////////////////////////////// //
TrueColorImage imageResample (MemoryImage msrcimg, int destwdt, int desthgt, string filter) {
  return imageResample(msrcimg, destwdt, desthgt, filter, 1.0f);
}


TrueColorImage imageResample (MemoryImage msrcimg, int destwdt, int desthgt, float gamma) {
  return imageResample(msrcimg, destwdt, desthgt, RESAMPLER_DEFAULT_FILTER, gamma);
}


TrueColorImage imageResample (MemoryImage msrcimg, int destwdt, int desthgt, string filter=RESAMPLER_DEFAULT_FILTER, float gamma=1.0f, float filterScale=1.0f) {
  if (msrcimg is null || destwdt < 1 || desthgt < 1) return null;
  if (msrcimg.width < 1 || msrcimg.height < 1 || destwdt > RESAMPLER_MAX_DIMENSION || desthgt > RESAMPLER_MAX_DIMENSION || msrcimg.width > RESAMPLER_MAX_DIMENSION || msrcimg.height > RESAMPLER_MAX_DIMENSION) {
    throw new Exception("invalid image size");
  }
  TrueColorImage img = msrcimg.getAsTrueColorImage;

  int n = 4;
  int srcwidth = img.width;
  int srcheight = img.height;
  auto srcimgdata = img.imageData.bytes.ptr;

  enum MaxComponents = 4;

  // Partial gamma correction looks better on mips. Set to 1.0 to disable gamma correction.
  immutable float sourceGamma = gamma;

  // Filter scale - values < 1.0 cause aliasing, but create sharper looking mips.
  //enum filterScale = 1.0f;//.75f;

  float[256] srgb2linear;
  foreach (int i, ref v; srgb2linear) {
    import std.math : pow;
    v = cast(float)pow(i*1.0f/255.0f, sourceGamma);
  }

  enum Linear2srgbTableSize = 4096;
  ubyte[Linear2srgbTableSize] linear2srgb;

  enum InvLinear2srgbTableSize = cast(float)(1.0f/Linear2srgbTableSize);
  immutable float invSourceGamma = 1.0f/sourceGamma;

  foreach (int i, ref v; linear2srgb) {
    import std.math : pow;
    int k = cast(int)(255.0f*pow(i*InvLinear2srgbTableSize, invSourceGamma)+0.5f);
    if (k < 0) k = 0; else if (k > 255) k = 255;
    v = cast(ubyte)k;
  }

  Resampler[MaxComponents] resamplers;
  float[][MaxComponents] samples;

  // Now create a Resampler instance for each component to process. The first instance will create new contributor tables, which are shared by the resamplers
  // used for the other components (a memory and slight cache efficiency optimization).
  resamplers[0] = new Resampler(srcwidth, srcheight, destwdt, desthgt, Resampler.BOUNDARY_CLAMP, 0.0f, 1.0f, filter, null, null, filterScale, filterScale);
  samples[0].length = srcwidth;
  foreach (int i; 1..n) {
    resamplers[i] = new Resampler(srcwidth, srcheight, destwdt, desthgt, Resampler.BOUNDARY_CLAMP, 0.0f, 1.0f, filter, resamplers[0].get_clist_x(), resamplers[0].get_clist_y(), filterScale, filterScale);
    samples[i].length = srcwidth;
  }
  scope(exit) foreach (int i; 0..n) delete resamplers[i]; // delete the resamplers
  scope(exit) foreach (int i; 0..n) delete samples[i]; // delete samples

  auto dstimg = new TrueColorImage(destwdt, desthgt);
  auto destimage = dstimg.imageData.bytes.ptr;

  immutable int srcpitch = srcwidth*4;
  immutable int destpitch = destwdt*4;
  int desty = 0;

  foreach (int srcy; 0..srcheight) {
    const(ubyte)* pSrc = &srcimgdata[srcy*srcpitch];
    foreach (int x; 0..srcwidth) {
      foreach (int c; 0..n) {
        if (c == 3 /*|| (n == 2 && c == 1)*/)
          samples[c][x] = *pSrc++*(1.0f/255.0f);
        else
          samples[c][x] = srgb2linear[*pSrc++];
      }
    }

    foreach (int c; 0..n) {
      if (!resamplers[c].put_line(&samples[c][0])) assert(0, "Out of memory!");
    }

    for (;;) {
      int compIdx;
      for (compIdx = 0; compIdx < n; ++compIdx) {
        const(float)* outSmp = resamplers[compIdx].get_line();
        if (outSmp is null) break;
        immutable bool alphachan = (compIdx == 3);// || (n == 2 && compIdx == 1));
        assert(desty < desthgt);
        ubyte* pDst = &destimage[desty*destpitch+compIdx];
        foreach (int x; 0..destwdt) {
          if (alphachan) {
            int c = cast(int)(255.0f*outSmp[x]+0.5f);
            if (c < 0) c = 0; else if (c > 255) c = 255;
            *pDst = cast(ubyte)c;
          } else {
            int j = cast(int)(Linear2srgbTableSize * outSmp[x] + .5f);
            if (j < 0) j = 0; else if (j >= Linear2srgbTableSize) j = Linear2srgbTableSize-1;
            *pDst = linear2srgb[j];
          }
          pDst += 4;
        }
      }
      if (compIdx < n) break;
      ++desty;
    }
  }

  return dstimg;
}


// ////////////////////////////////////////////////////////////////////////// //
final class Resampler {
nothrow @trusted @nogc:
public:
  alias Resample_Real = float;
  alias Sample = Resample_Real;

  static struct Contrib {
    Resample_Real weight;
    ushort pixel;
  }

  static struct Contrib_List {
    ushort n;
    Contrib* p;
  }

  alias Boundary_Op = int;
  enum /*Boundary_Op*/ {
    BOUNDARY_WRAP = 0,
    BOUNDARY_REFLECT = 1,
    BOUNDARY_CLAMP = 2,
  }

  alias Status = int;
  enum /*Status*/ {
    STATUS_OKAY = 0,
    STATUS_OUT_OF_MEMORY = 1,
    STATUS_BAD_FILTER_NAME = 2,
    STATUS_SCAN_BUFFER_FULL = 3,
  }

private:
  alias FilterFunc = Resample_Real function (Resample_Real) nothrow @trusted @nogc;

  int m_intermediate_x;

  int m_resample_src_x;
  int m_resample_src_y;
  int m_resample_dst_x;
  int m_resample_dst_y;

  Boundary_Op m_boundary_op;

  Sample* m_Pdst_buf;
  Sample* m_Ptmp_buf;

  Contrib_List* m_Pclist_x;
  Contrib_List* m_Pclist_y;

  bool m_clist_x_forced;
  bool m_clist_y_forced;

  bool m_delay_x_resample;

  int* m_Psrc_y_count;
  ubyte* m_Psrc_y_flag;

  // The maximum number of scanlines that can be buffered at one time.
  enum { MAX_SCAN_BUF_SIZE = RESAMPLER_MAX_DIMENSION };

  static struct Scan_Buf {
    int[MAX_SCAN_BUF_SIZE] scan_buf_y;
    Sample*[MAX_SCAN_BUF_SIZE] scan_buf_l;
  }

  Scan_Buf* m_Pscan_buf;

  int m_cur_src_y;
  int m_cur_dst_y;

  Status m_status;

  // The make_clist() method generates, for all destination samples,
  // the list of all source samples with non-zero weighted contributions.
  Contrib_List* make_clist(
    int src_x, int dst_x, Boundary_Op boundary_op,
    FilterFunc Pfilter,
    Resample_Real filter_support,
    Resample_Real filter_scale,
    Resample_Real src_ofs)
  {
    import core.stdc.stdlib : calloc, free;
    import std.math : floor, ceil;

    static struct Contrib_Bounds {
      // The center of the range in DISCRETE coordinates (pixel center = 0.0f).
      Resample_Real center;
      int left, right;
    }

    int i, j, k, n, left, right;
    Resample_Real total_weight;
    Resample_Real xscale, center, half_width, weight;
    Contrib_List* Pcontrib, PcontribRes;
    Contrib* Pcpool;
    Contrib* Pcpool_next;
    Contrib_Bounds* Pcontrib_bounds;

    if ((Pcontrib = cast(Contrib_List*)calloc(dst_x, Contrib_List.sizeof)) is null) return null;
    scope(exit) if (Pcontrib !is null) free(Pcontrib);

    Pcontrib_bounds = cast(Contrib_Bounds*)calloc(dst_x, Contrib_Bounds.sizeof);
    if (Pcontrib_bounds is null) return null;
    scope(exit) free(Pcontrib_bounds);

    immutable Resample_Real oo_filter_scale = 1.0f/filter_scale;

    immutable Resample_Real NUDGE = 0.5f;
    xscale = dst_x/cast(Resample_Real)src_x;

    if (xscale < 1.0f) {
      int total;
      // Handle case when there are fewer destination samples than source samples (downsampling/minification).
      // stretched half width of filter
      half_width = (filter_support/xscale)*filter_scale;
      // Find the range of source sample(s) that will contribute to each destination sample.
      for (i = 0, n = 0; i < dst_x; ++i) {
        // Convert from discrete to continuous coordinates, scale, then convert back to discrete.
        center = (cast(Resample_Real)i+NUDGE)/xscale;
        center -= NUDGE;
        center += src_ofs;
        left = cast_to_int(cast(Resample_Real)floor(center-half_width));
        right = cast_to_int(cast(Resample_Real)ceil(center+half_width));
        Pcontrib_bounds[i].center = center;
        Pcontrib_bounds[i].left = left;
        Pcontrib_bounds[i].right = right;
        n += (right-left+1);
      }

      // Allocate memory for contributors.
      if (n == 0 || ((Pcpool = cast(Contrib*)calloc(n, Contrib.sizeof)) is null)) return null;
      //scope(failure) free(Pcpool);
      total = n;

      Pcpool_next = Pcpool;

      // Create the list of source samples which contribute to each destination sample.
      for (i = 0; i < dst_x; i++) {
        int max_k = -1;
        Resample_Real max_w = -1e+20f;

        center = Pcontrib_bounds[i].center;
        left = Pcontrib_bounds[i].left;
        right = Pcontrib_bounds[i].right;

        Pcontrib[i].n = 0;
        Pcontrib[i].p = Pcpool_next;
        Pcpool_next += (right-left+1);
        assert(Pcpool_next-Pcpool <= total);

        total_weight = 0;

        for (j = left; j <= right; ++j) total_weight += Pfilter((center-cast(Resample_Real)j)*xscale*oo_filter_scale);
        immutable Resample_Real norm = cast(Resample_Real)(1.0f/total_weight);

        total_weight = 0;
        for (j = left; j <= right; ++j) {
          weight = Pfilter((center-cast(Resample_Real)j)*xscale*oo_filter_scale)*norm;
          if (weight == 0.0f) continue;
          n = reflect(j, src_x, boundary_op);
          // Increment the number of source samples which contribute to the current destination sample.
          k = Pcontrib[i].n++;
          Pcontrib[i].p[k].pixel = cast(ushort)(n); // store src sample number
          Pcontrib[i].p[k].weight = weight; // store src sample weight
          total_weight += weight; // total weight of all contributors
          if (weight > max_w) {
            max_w = weight;
            max_k = k;
          }
        }
        //assert(Pcontrib[i].n);
        //assert(max_k != -1);
        if (max_k == -1 || Pcontrib[i].n == 0) return null;
        if (total_weight != 1.0f) Pcontrib[i].p[max_k].weight += 1.0f-total_weight;
      }
    } else {
      // Handle case when there are more destination samples than source samples (upsampling).
      half_width = filter_support*filter_scale;
      // Find the source sample(s) that contribute to each destination sample.
      for (i = 0, n = 0; i < dst_x; ++i) {
        // Convert from discrete to continuous coordinates, scale, then convert back to discrete.
        center = (cast(Resample_Real)i+NUDGE)/xscale;
        center -= NUDGE;
        center += src_ofs;
        left = cast_to_int(cast(Resample_Real)floor(center-half_width));
        right = cast_to_int(cast(Resample_Real)ceil(center+half_width));
        Pcontrib_bounds[i].center = center;
        Pcontrib_bounds[i].left = left;
        Pcontrib_bounds[i].right = right;
        n += (right-left+1);
      }

      // Allocate memory for contributors.
      int total = n;
      if (total == 0 || ((Pcpool = cast(Contrib*)calloc(total, Contrib.sizeof)) is null)) return null;
      //scope(failure) free(Pcpool);

      Pcpool_next = Pcpool;

      // Create the list of source samples which contribute to each destination sample.
      for (i = 0; i < dst_x; ++i) {
        int max_k = -1;
        Resample_Real max_w = -1e+20f;

        center = Pcontrib_bounds[i].center;
        left = Pcontrib_bounds[i].left;
        right = Pcontrib_bounds[i].right;

        Pcontrib[i].n = 0;
        Pcontrib[i].p = Pcpool_next;
        Pcpool_next += (right-left+1);
        assert(Pcpool_next-Pcpool <= total);

        total_weight = 0;
        for (j = left; j <= right; ++j) total_weight += Pfilter((center-cast(Resample_Real)j)*oo_filter_scale);
        immutable Resample_Real norm = cast(Resample_Real)(1.0f/total_weight);

        total_weight = 0;
        for (j = left; j <= right; ++j) {
          weight = Pfilter((center-cast(Resample_Real)j)*oo_filter_scale)*norm;
          if (weight == 0.0f) continue;
          n = reflect(j, src_x, boundary_op);
          // Increment the number of source samples which contribute to the current destination sample.
          k = Pcontrib[i].n++;
          Pcontrib[i].p[k].pixel = cast(ushort)(n); // store src sample number
          Pcontrib[i].p[k].weight = weight; // store src sample weight
          total_weight += weight; // total weight of all contributors
          if (weight > max_w) {
            max_w = weight;
            max_k = k;
          }
        }
        //assert(Pcontrib[i].n);
        //assert(max_k != -1);
        if (max_k == -1 || Pcontrib[i].n == 0) return null;
        if (total_weight != 1.0f) Pcontrib[i].p[max_k].weight += 1.0f-total_weight;
      }
    }
    // don't free return value
    PcontribRes = Pcontrib;
    Pcontrib = null;
    return PcontribRes;
  }

  static int count_ops (const(Contrib_List)* Pclist, int k) {
    int i, t = 0;
    for (i = 0; i < k; i++) t += Pclist[i].n;
    return t;
  }

  private Resample_Real m_lo;
  private Resample_Real m_hi;

  Resample_Real clamp_sample (Resample_Real f) const {
    if (f < m_lo) f = m_lo; else if (f > m_hi) f = m_hi;
    return f;
  }

public:
  // src_x/src_y - Input dimensions
  // dst_x/dst_y - Output dimensions
  // boundary_op - How to sample pixels near the image boundaries
  // sample_low/sample_high - Clamp output samples to specified range, or disable clamping if sample_low >= sample_high
  // Pclist_x/Pclist_y - Optional pointers to contributor lists from another instance of a Resampler
  // src_x_ofs/src_y_ofs - Offset input image by specified amount (fractional values okay)
  this(
    int src_x, int src_y,
    int dst_x, int dst_y,
    Boundary_Op boundary_op=BOUNDARY_CLAMP,
    Resample_Real sample_low=0.0f, Resample_Real sample_high=0.0f,
    string Pfilter_name=RESAMPLER_DEFAULT_FILTER,
    Contrib_List* Pclist_x=null,
    Contrib_List* Pclist_y=null,
    Resample_Real filter_x_scale=1.0f,
    Resample_Real filter_y_scale=1.0f,
    Resample_Real src_x_ofs=0.0f,
    Resample_Real src_y_ofs=0.0f)
  {
    import core.stdc.stdlib : calloc, malloc;

    int i, j;
    Resample_Real support;
    FilterFunc func;

    assert(src_x > 0);
    assert(src_y > 0);
    assert(dst_x > 0);
    assert(dst_y > 0);

    m_lo = sample_low;
    m_hi = sample_high;

    m_delay_x_resample = false;
    m_intermediate_x = 0;
    m_Pdst_buf = null;
    m_Ptmp_buf = null;
    m_clist_x_forced = false;
    m_Pclist_x = null;
    m_clist_y_forced = false;
    m_Pclist_y = null;
    m_Psrc_y_count = null;
    m_Psrc_y_flag = null;
    m_Pscan_buf = null;
    m_status = STATUS_OKAY;

    m_resample_src_x = src_x;
    m_resample_src_y = src_y;
    m_resample_dst_x = dst_x;
    m_resample_dst_y = dst_y;

    m_boundary_op = boundary_op;

    if ((m_Pdst_buf = cast(Sample*)malloc(m_resample_dst_x*Sample.sizeof)) is null) {
      m_status = STATUS_OUT_OF_MEMORY;
      return;
    }

    // Find the specified filter.
    if (Pfilter_name == null) Pfilter_name = RESAMPLER_DEFAULT_FILTER;
    for (i = 0; i < NUM_FILTERS; ++i) if (Pfilter_name == g_filters[i].name) break;
    if (i == NUM_FILTERS) {
      m_status = STATUS_BAD_FILTER_NAME;
      return;
    }

    func = g_filters[i].func;
    support = g_filters[i].support;

    // Create contributor lists, unless the user supplied custom lists.
    if (Pclist_x is null) {
      m_Pclist_x = make_clist(m_resample_src_x, m_resample_dst_x, m_boundary_op, func, support, filter_x_scale, src_x_ofs);
      if (m_Pclist_x is null) {
        m_status = STATUS_OUT_OF_MEMORY;
        return;
      }
    } else {
      m_Pclist_x = Pclist_x;
      m_clist_x_forced = true;
    }

    if (Pclist_y is null) {
      m_Pclist_y = make_clist(m_resample_src_y, m_resample_dst_y, m_boundary_op, func, support, filter_y_scale, src_y_ofs);
      if (m_Pclist_y is null) {
        m_status = STATUS_OUT_OF_MEMORY;
        return;
      }
    } else {
      m_Pclist_y = Pclist_y;
      m_clist_y_forced = true;
    }

    if ((m_Psrc_y_count = cast(int*)calloc(m_resample_src_y, int.sizeof)) is null) {
      m_status = STATUS_OUT_OF_MEMORY;
      return;
    }

    if ((m_Psrc_y_flag = cast(ubyte*)calloc(m_resample_src_y, ubyte.sizeof)) is null) {
      m_status = STATUS_OUT_OF_MEMORY;
      return;
    }

    // Count how many times each source line contributes to a destination line.
    for (i = 0; i < m_resample_dst_y; ++i) {
      for (j = 0; j < m_Pclist_y[i].n; ++j) {
        ++m_Psrc_y_count[resampler_range_check(m_Pclist_y[i].p[j].pixel, m_resample_src_y)];
      }
    }

    if ((m_Pscan_buf = cast(Scan_Buf*)malloc(Scan_Buf.sizeof)) is null) {
      m_status = STATUS_OUT_OF_MEMORY;
      return;
    }

    for (i = 0; i < MAX_SCAN_BUF_SIZE; ++i) {
      m_Pscan_buf.scan_buf_y[i] = -1;
      m_Pscan_buf.scan_buf_l[i] = null;
    }

    m_cur_src_y = m_cur_dst_y = 0;
    {
      // Determine which axis to resample first by comparing the number of multiplies required
      // for each possibility.
      int x_ops = count_ops(m_Pclist_x, m_resample_dst_x);
      int y_ops = count_ops(m_Pclist_y, m_resample_dst_y);

      // Hack 10/2000: Weight Y axis ops a little more than X axis ops.
      // (Y axis ops use more cache resources.)
      int xy_ops = x_ops*m_resample_src_y+(4*y_ops*m_resample_dst_x)/3;
      int yx_ops = (4*y_ops*m_resample_src_x)/3+x_ops*m_resample_dst_y;

      // Now check which resample order is better. In case of a tie, choose the order
      // which buffers the least amount of data.
      if (xy_ops > yx_ops || (xy_ops == yx_ops && m_resample_src_x < m_resample_dst_x)) {
        m_delay_x_resample = true;
        m_intermediate_x = m_resample_src_x;
      } else {
        m_delay_x_resample = false;
        m_intermediate_x = m_resample_dst_x;
      }
    }

    if (m_delay_x_resample) {
      if ((m_Ptmp_buf = cast(Sample*)malloc(m_intermediate_x*Sample.sizeof)) is null) {
        m_status = STATUS_OUT_OF_MEMORY;
        return;
      }
    }
  }

  ~this () {
     import core.stdc.stdlib : free;

     if (m_Pdst_buf !is null) {
       free(m_Pdst_buf);
       m_Pdst_buf = null;
     }

     if (m_Ptmp_buf !is null) {
       free(m_Ptmp_buf);
       m_Ptmp_buf = null;
     }

     // Don't deallocate a contibutor list if the user passed us one of their own.
     if (m_Pclist_x !is null && !m_clist_x_forced) {
       free(m_Pclist_x.p);
       free(m_Pclist_x);
       m_Pclist_x = null;
     }
     if (m_Pclist_y !is null && !m_clist_y_forced) {
       free(m_Pclist_y.p);
       free(m_Pclist_y);
       m_Pclist_y = null;
     }

     if (m_Psrc_y_count !is null) {
       free(m_Psrc_y_count);
       m_Psrc_y_count = null;
     }

     if (m_Psrc_y_flag !is null) {
       free(m_Psrc_y_flag);
       m_Psrc_y_flag = null;
     }

     if (m_Pscan_buf !is null) {
       foreach (immutable i; 0..MAX_SCAN_BUF_SIZE) if (m_Pscan_buf.scan_buf_l[i] !is null) free(m_Pscan_buf.scan_buf_l[i]);
       free(m_Pscan_buf);
       m_Pscan_buf = null;
     }
  }

  // Reinits resampler so it can handle another frame.
  void restart () {
    import core.stdc.stdlib : free;
    if (STATUS_OKAY != m_status) return;
    m_cur_src_y = m_cur_dst_y = 0;
    int i, j;
    for (i = 0; i < m_resample_src_y; i++) {
      m_Psrc_y_count[i] = 0;
      m_Psrc_y_flag[i] = false;
    }
    for (i = 0; i < m_resample_dst_y; i++) {
      for (j = 0; j < m_Pclist_y[i].n; j++) {
        ++m_Psrc_y_count[resampler_range_check(m_Pclist_y[i].p[j].pixel, m_resample_src_y)];
      }
    }
    for (i = 0; i < MAX_SCAN_BUF_SIZE; i++) {
      m_Pscan_buf.scan_buf_y[i] = -1;
      free(m_Pscan_buf.scan_buf_l[i]);
      m_Pscan_buf.scan_buf_l[i] = null;
    }
  }

  // false on out of memory.
  bool put_line (const(Sample)* Psrc) {
    int i;

    if (m_cur_src_y >= m_resample_src_y) return false;

    // Does this source line contribute to any destination line? if not, exit now.
    if (!m_Psrc_y_count[resampler_range_check(m_cur_src_y, m_resample_src_y)]) {
      ++m_cur_src_y;
      return true;
    }

    // Find an empty slot in the scanline buffer. (FIXME: Perf. is terrible here with extreme scaling ratios.)
    for (i = 0; i < MAX_SCAN_BUF_SIZE; ++i) if (m_Pscan_buf.scan_buf_y[i] == -1) break;

    // If the buffer is full, exit with an error.
    if (i == MAX_SCAN_BUF_SIZE) {
      m_status = STATUS_SCAN_BUFFER_FULL;
      return false;
    }

    m_Psrc_y_flag[resampler_range_check(m_cur_src_y, m_resample_src_y)] = true;
    m_Pscan_buf.scan_buf_y[i] = m_cur_src_y;

    // Does this slot have any memory allocated to it?
    if (!m_Pscan_buf.scan_buf_l[i]) {
      import core.stdc.stdlib : malloc;
      if ((m_Pscan_buf.scan_buf_l[i] = cast(Sample*)malloc(m_intermediate_x*Sample.sizeof)) is null) {
        m_status = STATUS_OUT_OF_MEMORY;
        return false;
      }
    }

    // Resampling on the X axis first?
    if (m_delay_x_resample) {
      import core.stdc.string : memcpy;
      assert(m_intermediate_x == m_resample_src_x);
      // Y-X resampling order
      memcpy(m_Pscan_buf.scan_buf_l[i], Psrc, m_intermediate_x*Sample.sizeof);
    } else {
      assert(m_intermediate_x == m_resample_dst_x);
      // X-Y resampling order
      resample_x(m_Pscan_buf.scan_buf_l[i], Psrc);
    }

    ++m_cur_src_y;

    return true;
  }

  // null if no scanlines are currently available (give the resampler more scanlines!)
  const(Sample)* get_line () {
    int i;
    // If all the destination lines have been generated, then always return null.
    if (m_cur_dst_y == m_resample_dst_y) return null;
    // Check to see if all the required contributors are present, if not, return null.
    for (i = 0; i < m_Pclist_y[m_cur_dst_y].n; i++) {
      if (!m_Psrc_y_flag[resampler_range_check(m_Pclist_y[m_cur_dst_y].p[i].pixel, m_resample_src_y)]) return null;
    }
    resample_y(m_Pdst_buf);
    ++m_cur_dst_y;
    return m_Pdst_buf;
  }

  @property Status status () const { pragma(inline, true); return m_status; }

  // Returned contributor lists can be shared with another Resampler.
  void get_clists (Contrib_List** ptr_clist_x, Contrib_List** ptr_clist_y) {
    if (ptr_clist_x !is null) *ptr_clist_x = m_Pclist_x;
    if (ptr_clist_y !is null) *ptr_clist_y = m_Pclist_y;
  }

  @property Contrib_List* get_clist_x () { pragma(inline, true); return m_Pclist_x; }
  @property Contrib_List* get_clist_y () { pragma(inline, true); return m_Pclist_y; }

  // Filter accessors.
  static @property auto filters () {
    static struct FilterRange {
    pure nothrow @trusted @nogc:
      int idx;
      @property bool empty () const { pragma(inline, true); return (idx >= NUM_FILTERS); }
      @property string front () const { pragma(inline, true); return (idx < NUM_FILTERS ? g_filters[idx].name : null); }
      void popFront () { if (idx < NUM_FILTERS) ++idx; }
      int length () const { return cast(int)NUM_FILTERS; }
      alias opDollar = length;
    }
    return FilterRange();
  }

private:
  /* Ensure that the contributing source sample is
  * within bounds. If not, reflect, clamp, or wrap.
  */
  int reflect(in int j, in int src_x, in Boundary_Op boundary_op) {
    int n;

    if (j < 0)
    {
       if (boundary_op == BOUNDARY_REFLECT)
       {
          n = -j;

          if (n >= src_x)
             n = src_x-1;
       }
       else if (boundary_op == BOUNDARY_WRAP)
          n = posmod(j, src_x);
       else
          n = 0;
    }
    else if (j >= src_x)
    {
       if (boundary_op == BOUNDARY_REFLECT)
       {
          n = (src_x-j)+(src_x-1);

          if (n < 0)
             n = 0;
       }
       else if (boundary_op == BOUNDARY_WRAP)
          n = posmod(j, src_x);
       else
          n = src_x-1;
    }
    else
       n = j;

    return n;
  }

  void resample_x(Sample* Pdst, const(Sample)* Psrc)
  {
     assert(Pdst);
     assert(Psrc);

     int i, j;
     Sample total;
     Contrib_List *Pclist = m_Pclist_x;
     Contrib *p;

     for (i = m_resample_dst_x; i > 0; i--, Pclist++)
     {
        for (j = Pclist.n, p = Pclist.p, total = 0; j > 0; j--, p++)
           total += Psrc[p.pixel]*p.weight;

        *Pdst++ = total;
     }
  }

  void scale_y_mov(Sample* Ptmp, const(Sample)* Psrc, Resample_Real weight, int dst_x)
  {
     int i;

     // Not += because temp buf wasn't cleared.
     for (i = dst_x; i > 0; i--)
        *Ptmp++ = *Psrc++*weight;
  }

  void scale_y_add(Sample* Ptmp, const(Sample)* Psrc, Resample_Real weight, int dst_x)
  {
     for (int i = dst_x; i > 0; i--)
        (*Ptmp++) += *Psrc++*weight;
  }

  void clamp(Sample* Pdst, int n)
  {
     while (n > 0)
     {
        *Pdst = clamp_sample(*Pdst);
        ++Pdst;
        n--;
     }
  }

  void resample_y(Sample* Pdst)
  {
     int i, j;
     Sample* Psrc;
     Contrib_List* Pclist = &m_Pclist_y[m_cur_dst_y];

     Sample* Ptmp = m_delay_x_resample ? m_Ptmp_buf : Pdst;
     assert(Ptmp);

     /* Process each contributor. */

     for (i = 0; i < Pclist.n; i++)
     {
        /* locate the contributor's location in the scan
        * buffer -- the contributor must always be found!
        */

        for (j = 0; j < MAX_SCAN_BUF_SIZE; j++)
           if (m_Pscan_buf.scan_buf_y[j] == Pclist.p[i].pixel)
              break;

        assert(j < MAX_SCAN_BUF_SIZE);

        Psrc = m_Pscan_buf.scan_buf_l[j];

        if (!i)
           scale_y_mov(Ptmp, Psrc, Pclist.p[i].weight, m_intermediate_x);
        else
           scale_y_add(Ptmp, Psrc, Pclist.p[i].weight, m_intermediate_x);

        /* If this source line doesn't contribute to any
        * more destination lines then mark the scanline buffer slot
        * which holds this source line as free.
        * (The max. number of slots used depends on the Y
        * axis sampling factor and the scaled filter width.)
        */

        if (--m_Psrc_y_count[resampler_range_check(Pclist.p[i].pixel, m_resample_src_y)] == 0)
        {
           m_Psrc_y_flag[resampler_range_check(Pclist.p[i].pixel, m_resample_src_y)] = false;
           m_Pscan_buf.scan_buf_y[j] = -1;
        }
     }

     /* Now generate the destination line */

     if (m_delay_x_resample) // Was X resampling delayed until after Y resampling?
     {
        assert(Pdst != Ptmp);
        resample_x(Pdst, Ptmp);
     }
     else
     {
        assert(Pdst == Ptmp);
     }

     if (m_lo < m_hi)
        clamp(Pdst, m_resample_dst_x);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private nothrow @trusted @nogc:
int resampler_range_check (int v, int h) {
  version(assert) {
    //import std.conv : to;
    //assert(v >= 0 && v < h, "invalid v ("~to!string(v)~"), should be in [0.."~to!string(h)~")");
    assert(v >= 0 && v < h); // alas, @nogc
    return v;
  } else {
    pragma(inline, true);
    return v;
  }
}

enum M_PI = 3.14159265358979323846;

// Float to int cast with truncation.
int cast_to_int (Resampler.Resample_Real i) { return cast(int)i; }

// (x mod y) with special handling for negative x values.
int posmod (int x, int y) {
  if (x >= 0) return (x%y);
  else {
    int m = (-x)%y;
    if (m != 0) m = y-m;
    return m;
  }
}

// To add your own filter, insert the new function below and update the filter table.
// There is no need to make the filter function particularly fast, because it's
// only called during initializing to create the X and Y axis contributor tables.

/* pulse/Fourier window */
enum BOX_FILTER_SUPPORT = 0.5f;
Resampler.Resample_Real box_filter (Resampler.Resample_Real t) {
  // make_clist() calls the filter function with t inverted (pos = left, neg = right)
  if (t >= -0.5f && t < 0.5f) return 1.0f; else return 0.0f;
}

/* box (*) box, bilinear/triangle */
enum TENT_FILTER_SUPPORT = 1.0f;
Resampler.Resample_Real tent_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 1.0f) return 1.0f-t; else return 0.0f;
}

/* box (*) box (*) box */
enum BELL_SUPPORT = 1.5f;
Resampler.Resample_Real bell_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 0.5f) return (0.75f-(t*t));
  if (t < 1.5f) { t = (t-1.5f); return (0.5f*(t*t)); }
  return (0.0f);
}

/* box (*) box (*) box (*) box */
enum B_SPLINE_SUPPORT = 2.0f;
Resampler.Resample_Real B_spline_filter (Resampler.Resample_Real t) {
  Resampler.Resample_Real tt;
  if (t < 0.0f) t = -t;
  if (t < 1.0f) { tt = t*t; return ((0.5f*tt*t)-tt+(2.0f/3.0f)); }
  if (t < 2.0f) { t = 2.0f-t; return ((1.0f/6.0f)*(t*t*t)); }
  return (0.0f);
}

// Dodgson, N., "Quadratic Interpolation for Image Resampling"
enum QUADRATIC_SUPPORT = 1.5f;
Resampler.Resample_Real quadratic (Resampler.Resample_Real t, in Resampler.Resample_Real R) {
  if (t < 0.0f) t = -t;
  if (t < QUADRATIC_SUPPORT) {
    Resampler.Resample_Real tt = t*t;
    if (t <= 0.5f) return (-2.0f*R)*tt+0.5f*(R+1.0f);
    return (R*tt)+(-2.0f*R-0.5f)*t+(3.0f/4.0f)*(R+1.0f);
  }
  return 0.0f;
}

Resampler.Resample_Real quadratic_interp_filter (Resampler.Resample_Real t) {
  return quadratic(t, 1.0f);
}

Resampler.Resample_Real quadratic_approx_filter (Resampler.Resample_Real t) {
  return quadratic(t, 0.5f);
}

Resampler.Resample_Real quadratic_mix_filter (Resampler.Resample_Real t) {
  return quadratic(t, 0.8f);
}

// Mitchell, D. and A. Netravali, "Reconstruction Filters in Computer Graphics."
// Computer Graphics, Vol. 22, No. 4, pp. 221-228.
// (B, C)
// (1/3, 1/3)  - Defaults recommended by Mitchell and Netravali
// (1, 0)    - Equivalent to the Cubic B-Spline
// (0, 0.5)   - Equivalent to the Catmull-Rom Spline
// (0, C)   - The family of Cardinal Cubic Splines
// (B, 0)   - Duff's tensioned B-Splines.
Resampler.Resample_Real mitchell (Resampler.Resample_Real t, in Resampler.Resample_Real B, in Resampler.Resample_Real C) {
  Resampler.Resample_Real tt;
  tt = t*t;
  if (t < 0.0f) t = -t;
  if (t < 1.0f) {
    t = (((12.0f-9.0f*B-6.0f*C)*(t*tt))+
         ((-18.0f+12.0f*B+6.0f*C)*tt)+
         (6.0f-2.0f*B));
    return (t/6.0f);
  }
  if (t < 2.0f) {
    t = (((-1.0f*B-6.0f*C)*(t*tt))+
         ((6.0f*B+30.0f*C)*tt)+
         ((-12.0f*B-48.0f*C)*t)+
         (8.0f*B+24.0f*C));
    return (t/6.0f);
  }
  return (0.0f);
}

enum MITCHELL_SUPPORT = 2.0f;
Resampler.Resample_Real mitchell_filter (Resampler.Resample_Real t) {
  return mitchell(t, 1.0f/3.0f, 1.0f/3.0f);
}

enum CATMULL_ROM_SUPPORT = 2.0f;
Resampler.Resample_Real catmull_rom_filter (Resampler.Resample_Real t) {
  return mitchell(t, 0.0f, 0.5f);
}

double sinc (double x) {
  import std.math : sin;
  x = (x*M_PI);
  if (x < 0.01f && x > -0.01f) return 1.0f+x*x*(-1.0f/6.0f+x*x*1.0f/120.0f);
  return sin(x)/x;
}

Resampler.Resample_Real clean (double t) {
  import std.math : abs;
  enum EPSILON = cast(Resampler.Resample_Real)0.0000125f;
  if (abs(t) < EPSILON) return 0.0f;
  return cast(Resampler.Resample_Real)t;
}

//static double blackman_window(double x)
//{
//  return 0.42f+0.50f*cos(M_PI*x)+0.08f*cos(2.0f*M_PI*x);
//}

double blackman_exact_window (double x) {
  import std.math : cos;
  return 0.42659071f+0.49656062f*cos(M_PI*x)+0.07684867f*cos(2.0f*M_PI*x);
}

enum BLACKMAN_SUPPORT = 3.0f;
Resampler.Resample_Real blackman_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 3.0f) {
    //return clean(sinc(t)*blackman_window(t/3.0f));
    return clean(sinc(t)*blackman_exact_window(t/3.0f));
  }
  return (0.0f);
}

// with blackman window
enum GAUSSIAN_SUPPORT = 1.25f;
Resampler.Resample_Real gaussian_filter (Resampler.Resample_Real t) {
  import std.math : exp, sqrt;
  if (t < 0) t = -t;
  if (t < GAUSSIAN_SUPPORT) return clean(exp(-2.0f*t*t)*sqrt(2.0f/M_PI)*blackman_exact_window(t/GAUSSIAN_SUPPORT));
  return 0.0f;
}

// Windowed sinc -- see "Jimm Blinn's Corner: Dirty Pixels" pg. 26.
enum LANCZOS3_SUPPORT = 3.0f;
Resampler.Resample_Real lanczos3_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 3.0f) return clean(sinc(t)*sinc(t/3.0f));
  return (0.0f);
}

enum LANCZOS4_SUPPORT = 4.0f;
Resampler.Resample_Real lanczos4_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 4.0f) return clean(sinc(t)*sinc(t/4.0f));
  return (0.0f);
}

enum LANCZOS6_SUPPORT = 6.0f;
Resampler.Resample_Real lanczos6_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 6.0f) return clean(sinc(t)*sinc(t/6.0f));
  return (0.0f);
}

enum LANCZOS12_SUPPORT = 12.0f;
Resampler.Resample_Real lanczos12_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < 12.0f) return clean(sinc(t)*sinc(t/12.0f));
  return (0.0f);
}

double bessel0 (double x) {
  enum EPSILON_RATIO = cast(double)1E-16;
  double xh, sum, pow, ds;
  int k;
  xh = 0.5*x;
  sum = 1.0;
  pow = 1.0;
  k = 0;
  ds = 1.0;
  // FIXME: Shouldn't this stop after X iterations for max. safety?
  while (ds > sum*EPSILON_RATIO) {
    ++k;
    pow = pow*(xh/k);
    ds = pow*pow;
    sum = sum+ds;
  }
  return sum;
}

enum KAISER_ALPHA = cast(Resampler.Resample_Real)4.0;
double kaiser (double alpha, double half_width, double x) {
  import std.math : sqrt;
  immutable double ratio = (x/half_width);
  return bessel0(alpha*sqrt(1-ratio*ratio))/bessel0(alpha);
}

enum KAISER_SUPPORT = 3;
static Resampler.Resample_Real kaiser_filter (Resampler.Resample_Real t) {
  if (t < 0.0f) t = -t;
  if (t < KAISER_SUPPORT) {
    import std.math : exp, log;
    // db atten
    immutable Resampler.Resample_Real att = 40.0f;
    immutable Resampler.Resample_Real alpha = cast(Resampler.Resample_Real)(exp(log(cast(double)0.58417*(att-20.96))*0.4)+0.07886*(att-20.96));
    //const Resampler.Resample_Real alpha = KAISER_ALPHA;
    return cast(Resampler.Resample_Real)clean(sinc(t)*kaiser(alpha, KAISER_SUPPORT, t));
  }
  return 0.0f;
}

// filters[] is a list of all the available filter functions.
struct FilterInfo {
  string name;
  Resampler.FilterFunc func;
  Resampler.Resample_Real support;
}

static immutable FilterInfo[16] g_filters = [
   FilterInfo("box",              &box_filter,              BOX_FILTER_SUPPORT),
   FilterInfo("tent",             &tent_filter,             TENT_FILTER_SUPPORT),
   FilterInfo("bell",             &bell_filter,             BELL_SUPPORT),
   FilterInfo("bspline",          &B_spline_filter,         B_SPLINE_SUPPORT),
   FilterInfo("mitchell",         &mitchell_filter,         MITCHELL_SUPPORT),
   FilterInfo("lanczos3",         &lanczos3_filter,         LANCZOS3_SUPPORT),
   FilterInfo("blackman",         &blackman_filter,         BLACKMAN_SUPPORT),
   FilterInfo("lanczos4",         &lanczos4_filter,         LANCZOS4_SUPPORT),
   FilterInfo("lanczos6",         &lanczos6_filter,         LANCZOS6_SUPPORT),
   FilterInfo("lanczos12",        &lanczos12_filter,        LANCZOS12_SUPPORT),
   FilterInfo("kaiser",           &kaiser_filter,           KAISER_SUPPORT),
   FilterInfo("gaussian",         &gaussian_filter,         GAUSSIAN_SUPPORT),
   FilterInfo("catmullrom",       &catmull_rom_filter,      CATMULL_ROM_SUPPORT),
   FilterInfo("quadratic_interp", &quadratic_interp_filter, QUADRATIC_SUPPORT),
   FilterInfo("quadratic_approx", &quadratic_approx_filter, QUADRATIC_SUPPORT),
   FilterInfo("quadratic_mix",    &quadratic_mix_filter,    QUADRATIC_SUPPORT),
];

enum NUM_FILTERS = cast(int)g_filters.length;
