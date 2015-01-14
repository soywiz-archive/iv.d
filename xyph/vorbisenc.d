/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/
module iv.xyph.vorbisenc;
pragma(lib, "vorbisenc");

import core.stdc.config;
import iv.xyph.vorbis;

enum {
  OV_ECTL_RATEMANAGE_GET =0x10,
  OV_ECTL_RATEMANAGE_SET =0x11,
  OV_ECTL_RATEMANAGE_AVG =0x12,
  OV_ECTL_RATEMANAGE_HARD =0x13,
}

struct ovectl_ratemanage_arg {
  int management_active;
  c_long bitrate_hard_min;
  c_long bitrate_hard_max;
  double bitrate_hard_window;
  c_long bitrate_av_lo;
  c_long bitrate_av_hi;
  double bitrate_av_window;
  double bitrate_av_window_center;
}

enum {
  OV_ECTL_RATEMANAGE2_GET =0x14,
  OV_ECTL_RATEMANAGE2_SET =0x15,
}

struct ovectl_ratemanage2_arg {
  int management_active;
  c_long bitrate_limit_min_kbps;
  c_long bitrate_limit_max_kbps;
  c_long bitrate_limit_reservoir_bits;
  double bitrate_limit_reservoir_bias;
  c_long bitrate_average_kbps;
  double bitrate_average_damping;
}

enum {
  OV_ECTL_LOWPASS_GET = 0x20,
  OV_ECTL_LOWPASS_SET = 0x21,
  OV_ECTL_IBLOCK_GET  = 0x30,
  OV_ECTL_IBLOCK_SET  = 0x31,
}

extern(C) @nogc nothrow {
  int vorbis_encode_init (vorbis_info*, c_long, c_long, c_long, c_long, c_long);
  int vorbis_encode_setup_managed (vorbis_info*, c_long, c_long, c_long, c_long, c_long);
  int vorbis_encode_setup_vbr (vorbis_info*, c_long, c_long, float);
  int vorbis_encode_init_vbr (vorbis_info*, c_long, c_long, float);
  int vorbis_encode_setup_init (vorbis_info*);
  int vorbis_encode_ctl (vorbis_info*, int, void*);
}
