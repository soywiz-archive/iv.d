/*
 * Opus decoder/demuxer common functions
 * Copyright (c) 2012 Andrew D'Addesio
 * Copyright (c) 2013-2014 Mozilla Corporation
 *
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
module opus;

import iv.cmdcon;

import zogg;
import avmem;
import avfft;
import opus_celt;
import opus_silk;
import opus_resampler;

static immutable uint64_t[9] ff_vorbis_channel_layouts = [
    AV_CH_LAYOUT_MONO,
    AV_CH_LAYOUT_STEREO,
    2/*AV_CH_LAYOUT_SURROUND*/,
    3/*AV_CH_LAYOUT_QUAD*/,
    4/*AV_CH_LAYOUT_5POINT0_BACK*/,
    5/*AV_CH_LAYOUT_5POINT1_BACK*/,
    6/*AV_CH_LAYOUT_5POINT1|AV_CH_BACK_CENTER*/,
    7/*AV_CH_LAYOUT_7POINT1*/,
    0
];

static immutable uint8_t[8][8] ff_vorbis_channel_layout_offsets = [
    [ 0 ],
    [ 0, 1 ],
    [ 0, 2, 1 ],
    [ 0, 1, 2, 3 ],
    [ 0, 2, 1, 3, 4 ],
    [ 0, 2, 1, 5, 3, 4 ],
    [ 0, 2, 1, 6, 5, 3, 4 ],
    [ 0, 2, 1, 7, 5, 6, 3, 4 ],
];


/+
/**
 * Read 1-25 bits.
 */
/*static inline*/ uint get_bits (GetBitContext* s, int n) {
/*
    register int tmp;
    OPEN_READER(re, s);
    av_assert2(n>0 && n<=25);
    UPDATE_CACHE(re, s);
    tmp = SHOW_UBITS(re, s, n);
    LAST_SKIP_BITS(re, s, n);
    CLOSE_READER(re, s);
    return tmp;
*/
  assert(0);
}
+/

enum M_SQRT1_2 = 0.70710678118654752440; /* 1/sqrt(2) */
enum M_SQRT2 = 1.41421356237309504880; /* sqrt(2) */


enum MAX_FRAME_SIZE = 1275;
enum MAX_FRAMES = 48;
enum MAX_PACKET_DUR = 5760;

enum CELT_SHORT_BLOCKSIZE = 120;
enum CELT_OVERLAP = CELT_SHORT_BLOCKSIZE;
enum CELT_MAX_LOG_BLOCKS = 3;
enum CELT_MAX_FRAME_SIZE = (CELT_SHORT_BLOCKSIZE * (1 << CELT_MAX_LOG_BLOCKS));
enum CELT_MAX_BANDS = 21;
enum CELT_VECTORS = 11;
enum CELT_ALLOC_STEPS = 6;
enum CELT_FINE_OFFSET = 21;
enum CELT_MAX_FINE_BITS = 8;
enum CELT_NORM_SCALE = 16384;
enum CELT_QTHETA_OFFSET = 4;
enum CELT_QTHETA_OFFSET_TWOPHASE = 16;
enum CELT_DEEMPH_COEFF = 0.85000610f;
enum CELT_POSTFILTER_MINPERIOD = 15;
enum CELT_ENERGY_SILENCE = (-28.0f);

enum SILK_HISTORY = 322;
enum SILK_MAX_LPC = 16;

//#define ROUND_MULL(a,b,s) (((MUL64(a, b) >> ((s) - 1)) + 1) >> 1)
//#define ROUND_MUL16(a,b)  ((MUL16(a, b) + 16384) >> 15)
//#define opus_ilog(i) (av_log2(i) + !!(i))

/* signed 16x16 . 32 multiply */
int MUL16() (int ra, int rb) { return ra*rb; }
long MUL64(T0, T1) (T0 a, T1 b) { return cast(int64_t)a * cast(int64_t)b; }
long ROUND_MULL() (int a, int b, int s) { return (((MUL64(a, b) >> ((s) - 1)) + 1) >> 1); }
int ROUND_MUL16() (int a, int b) { return ((MUL16(a, b) + 16384) >> 15); }

int opus_ilog (uint i) nothrow @trusted @nogc { pragma(inline, true); return av_log2(i)+!!i; }

int MULH() (int a, int b) { return cast(int)(MUL64(a, b) >> 32); }
long MULL(T0, T1, T2) (T0 a, T1 b, T2 s) { return (MUL64(a, b) >> (s)); }


enum OPUS_TS_HEADER = 0x7FE0;        // 0x3ff (11 bits)
enum OPUS_TS_MASK = 0xFFE0;        // top 11 bits

static immutable uint8_t[38] opus_default_extradata = [
    'O', 'p', 'u', 's', 'H', 'e', 'a', 'd',
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];

alias OpusMode = int;
enum /*OpusMode*/:int {
    OPUS_MODE_SILK,
    OPUS_MODE_HYBRID,
    OPUS_MODE_CELT
}

alias OpusBandwidth = int;
enum /*OpusBandwidth*/: int {
    OPUS_BANDWIDTH_NARROWBAND,
    OPUS_BANDWIDTH_MEDIUMBAND,
    OPUS_BANDWIDTH_WIDEBAND,
    OPUS_BANDWIDTH_SUPERWIDEBAND,
    OPUS_BANDWIDTH_FULLBAND
};

struct RawBitsContext {
    const(uint8_t)* position;
    uint bytes;
    uint cachelen;
    uint cacheval;
}

struct OpusRangeCoder {
    GetBitContext gb;
    RawBitsContext rb;
    uint range;
    uint value;
    uint total_read_bits;
}

//typedef struct SilkContext SilkContext;

//typedef struct CeltContext CeltContext;

struct OpusPacket {
    int packet_size;                /**< packet size */
    int data_size;                  /**< size of the useful data -- packet size - padding */
    int code;                       /**< packet code: specifies the frame layout */
    int stereo;                     /**< whether this packet is mono or stereo */
    int vbr;                        /**< vbr flag */
    int config;                     /**< configuration: tells the audio mode,
                                     **                bandwidth, and frame duration */
    int frame_count;                /**< frame count */
    int[MAX_FRAMES] frame_offset;   /**< frame offsets */
    int[MAX_FRAMES] frame_size;     /**< frame sizes */
    int frame_duration;             /**< frame duration, in samples @ 48kHz */
    OpusMode mode;             /**< mode */
    OpusBandwidth bandwidth;   /**< bandwidth */
}

struct OpusStreamContext {
    //AVCodecContext *avctx;
    //AVCtx* avctx;
    int output_channels;

    OpusRangeCoder rc;
    OpusRangeCoder redundancy_rc;
    SilkContext *silk;
    CeltContext *celt;
    //AVFloatDSPContext *fdsp;

    float[960][2] silk_buf;
    float*[2] silk_output;
    //DECLARE_ALIGNED(32, float, celt_buf)[2][960];
    float[960][2] celt_buf;
    float*[2] celt_output;

    float[960][2] redundancy_buf;
    float*[2] redundancy_output;

    /* data buffers for the final output data */
    float*[2] out_;
    int out_size;

    float *out_dummy;
    int    out_dummy_allocated_size;

    //SwrContext *swr;
    SpeexResampler flr;
    AVAudioFifo *celt_delay;
    int silk_samplerate;
    /* number of samples we still want to get from the resampler */
    int delayed_samples;

    OpusPacket packet;

    int redundancy_idx;
}

// a mapping between an opus stream and an output channel
struct ChannelMap {
    int stream_idx;
    int channel_idx;

    // when a single decoded channel is mapped to multiple output channels, we
    // write to the first output directly and copy from it to the others
    // this field is set to 1 for those copied output channels
    int copy;
    // this is the index of the output channel to copy from
    int copy_idx;

    // this channel is silent
    int silence;
}

struct OpusContext {
    OpusStreamContext *streams;

    int in_channels;

    /* current output buffers for each streams */
    float **out_;
    int   *out_size;
    /* Buffers for synchronizing the streams when they have different resampling delays */
    AVAudioFifo **sync_buffers;
    /* number of decoded samples for each stream */
    int         *decoded_samples;

    int             nb_streams;
    int      nb_stereo_streams;

    //AVFloatDSPContext *fdsp;
    int16_t gain_i;
    float   gain;

    ChannelMap *channel_maps;
}

/*static av_always_inline*/ void opus_rc_normalize(OpusRangeCoder *rc)
{
    while (rc.range <= 1<<23) {
        ubyte b = cast(ubyte)rc.gb.get_bits(8)^0xFF;
        //conwritefln!"b=0x%02x"(b);
        //rc.value = ((rc.value << 8) | (rc.gb.get_bits(8) ^ 0xFF)) & ((1u << 31) - 1);
        rc.value = ((rc.value << 8) | b) & ((1u << 31) - 1);
        rc.range          <<= 8;
        rc.total_read_bits += 8;
    }

/+
  /*If the range is too small, rescale it and input some bits.*/
  while(_this->rng<=EC_CODE_BOT){
    int sym;
    _this->nbits_total+=EC_SYM_BITS;
    _this->rng<<=EC_SYM_BITS;
    /*Use up the remaining bits from our last symbol.*/
    sym=_this->rem;
    /*Read the next value from the input.*/
    _this->rem=ec_read_byte(_this);
    /*Take the rest of the bits we need from this new symbol.*/
    sym=(sym<<EC_SYM_BITS|_this->rem)>>(EC_SYM_BITS-EC_CODE_EXTRA);

    sym=(sym<<8|_this->rem)>>1;

    /*And subtract them from val, capped to be less than EC_CODE_TOP.*/
    _this->val=((_this->val<<EC_SYM_BITS)+(EC_SYM_MAX&~sym))&(EC_CODE_TOP-1);
  }
+/
}

/*static av_always_inline*/ void opus_rc_update(OpusRangeCoder *rc, uint scale,
                                          uint low, uint high,
                                          uint total)
{
    rc.value -= scale * (total - high);
    rc.range  = low ? scale * (high - low)
                      : rc.range - scale * (total - high);
    opus_rc_normalize(rc);
}

/*static av_always_inline*/ uint opus_rc_getsymbol(OpusRangeCoder *rc, const(uint16_t)*cdf)
{
    uint k, scale, total, symbol, low, high;

    total = *cdf++;

    scale   = rc.range / total;
    symbol = rc.value / scale + 1;
    symbol = total - FFMIN(symbol, total);

    for (k = 0; cdf[k] <= symbol; k++) {}
    high = cdf[k];
    low  = k ? cdf[k-1] : 0;

    opus_rc_update(rc, scale, low, high, total);

    return k;
}

/*static av_always_inline*/ uint opus_rc_p2model(OpusRangeCoder *rc, uint bits)
{
    uint k, scale;
    scale = rc.range >> bits; // in this case, scale = symbol

    if (rc.value >= scale) {
        rc.value -= scale;
        rc.range -= scale;
        k = 0;
    } else {
        rc.range = scale;
        k = 1;
    }
    opus_rc_normalize(rc);
    return k;
}

/**
 * CELT: estimate bits of entropy that have thus far been consumed for the
 *       current CELT frame, to integer and fractional (1/8th bit) precision
 */
/*static av_always_inline*/ uint opus_rc_tell(const OpusRangeCoder *rc)
{
    return rc.total_read_bits - av_log2(rc.range) - 1;
}

/*static av_always_inline*/ uint opus_rc_tell_frac(const OpusRangeCoder *rc)
{
    uint i, total_bits, rcbuffer, range;

    total_bits = rc.total_read_bits << 3;
    rcbuffer   = av_log2(rc.range) + 1;
    range      = rc.range >> (rcbuffer-16);

    for (i = 0; i < 3; i++) {
        int bit;
        range = range * range >> 15;
        bit = range >> 16;
        rcbuffer = rcbuffer << 1 | bit;
        range >>= bit;
    }

    return total_bits - rcbuffer;
}

/**
 * CELT: read 1-25 raw bits at the end of the frame, backwards byte-wise
 */
/*static av_always_inline*/ uint opus_getrawbits(OpusRangeCoder *rc, uint count)
{
    uint value = 0;

    while (rc.rb.bytes && rc.rb.cachelen < count) {
        rc.rb.cacheval |= *--rc.rb.position << rc.rb.cachelen;
        rc.rb.cachelen += 8;
        rc.rb.bytes--;
    }

    value = av_mod_uintp2(rc.rb.cacheval, count);
    rc.rb.cacheval    >>= count;
    rc.rb.cachelen     -= count;
    rc.total_read_bits += count;

    return value;
}

/**
 * CELT: read a uniform distribution
 */
/*static av_always_inline*/ uint opus_rc_unimodel(OpusRangeCoder *rc, uint size)
{
    uint bits, k, scale, total;

    bits  = opus_ilog(size - 1);
    total = (bits > 8) ? ((size - 1) >> (bits - 8)) + 1 : size;

    scale  = rc.range / total;
    k      = rc.value / scale + 1;
    k      = total - FFMIN(k, total);
    opus_rc_update(rc, scale, k, k + 1, total);

    if (bits > 8) {
        k = k << (bits - 8) | opus_getrawbits(rc, bits - 8);
        return FFMIN(k, size - 1);
    } else
        return k;
}

/*static av_always_inline*/ int opus_rc_laplace(OpusRangeCoder *rc, uint symbol, int decay)
{
    /* extends the range coder to model a Laplace distribution */
    int value = 0;
    uint scale, low = 0, center;

    scale  = rc.range >> 15;
    center = rc.value / scale + 1;
    center = (1 << 15) - FFMIN(center, 1 << 15);

    if (center >= symbol) {
        value++;
        low = symbol;
        symbol = 1 + ((32768 - 32 - symbol) * (16384-decay) >> 15);

        while (symbol > 1 && center >= low + 2 * symbol) {
            value++;
            symbol *= 2;
            low    += symbol;
            symbol  = (((symbol - 2) * decay) >> 15) + 1;
        }

        if (symbol <= 1) {
            int distance = (center - low) >> 1;
            value += distance;
            low   += 2 * distance;
        }

        if (center < low + symbol)
            value *= -1;
        else
            low += symbol;
    }

    opus_rc_update(rc, scale, low, FFMIN(low + symbol, 32768), 32768);

    return value;
}

/*static av_always_inline*/ uint opus_rc_stepmodel(OpusRangeCoder *rc, int k0)
{
    /* Use a probability of 3 up to itheta=8192 and then use 1 after */
    uint k, scale, symbol, total = (k0+1)*3 + k0;
    scale  = rc.range / total;
    symbol = rc.value / scale + 1;
    symbol = total - FFMIN(symbol, total);

    k = (symbol < (k0+1)*3) ? symbol/3 : symbol - (k0+1)*2;

    opus_rc_update(rc, scale, (k <= k0) ? 3*(k+0) : (k-1-k0) + 3*(k0+1),
                   (k <= k0) ? 3*(k+1) : (k-0-k0) + 3*(k0+1), total);
    return k;
}

/*static av_always_inline*/ uint opus_rc_trimodel(OpusRangeCoder *rc, int qn)
{
    uint k, scale, symbol, total, low, center;

    total = ((qn>>1) + 1) * ((qn>>1) + 1);
    scale   = rc.range / total;
    center = rc.value / scale + 1;
    center = total - FFMIN(center, total);

    if (center < total >> 1) {
        k      = (ff_sqrt(8 * center + 1) - 1) >> 1;
        low    = k * (k + 1) >> 1;
        symbol = k + 1;
    } else {
        k      = (2*(qn + 1) - ff_sqrt(8*(total - center - 1) + 1)) >> 1;
        low    = total - ((qn + 1 - k) * (qn + 2 - k) >> 1);
        symbol = qn + 1 - k;
    }

    opus_rc_update(rc, scale, low, low + symbol, total);

    return k;
}


static immutable uint16_t[32] opus_frame_duration = [
    480, 960, 1920, 2880,
    480, 960, 1920, 2880,
    480, 960, 1920, 2880,
    480, 960,
    480, 960,
    120, 240,  480,  960,
    120, 240,  480,  960,
    120, 240,  480,  960,
    120, 240,  480,  960,
];

/**
 * Read a 1- or 2-byte frame length
 */
int xiph_lacing_16bit (const(uint8_t)** ptr, const(uint8_t)* end) {
  int val;
  if (*ptr >= end) return AVERROR_INVALIDDATA;
  val = *(*ptr)++;
  if (val >= 252) {
    if (*ptr >= end) return AVERROR_INVALIDDATA;
    val += 4 * *(*ptr)++;
  }
  return val;
}

/**
 * Read a multi-byte length (used for code 3 packet padding size)
 */
int xiph_lacing_full (const(uint8_t)** ptr, const(uint8_t)* end) {
  int val = 0;
  int next;
  for (;;) {
    if (*ptr >= end || val > int.max-254) return AVERROR_INVALIDDATA;
    next = *(*ptr)++;
    val += next;
    if (next < 255) break; else --val;
  }
  return val;
}

/**
 * Parse Opus packet info from raw packet data
 */
int ff_opus_parse_packet (OpusPacket* pkt, const(uint8_t)* buf, int buf_size, bool self_delimiting) {
  import core.stdc.string : memset;

  const(uint8_t)* ptr = buf;
  const(uint8_t)* end = buf+buf_size;
  int padding = 0;
  int frame_bytes, i;
  //conwriteln("frame packet size=", buf_size);

  if (buf_size < 1) goto fail;

  // TOC byte
  i = *ptr++;
  pkt.code   = (i   )&0x3;
  pkt.stereo = (i>>2)&0x1;
  pkt.config = (i>>3)&0x1F;

  // code 2 and code 3 packets have at least 1 byte after the TOC
  if (pkt.code >= 2 && buf_size < 2) goto fail;

  //conwriteln("packet code: ", pkt.code);
  final switch (pkt.code) {
    case 0:
      // 1 frame
      pkt.frame_count = 1;
      pkt.vbr = 0;

      if (self_delimiting) {
        int len = xiph_lacing_16bit(&ptr, end);
        if (len < 0 || len > end-ptr) goto fail;
        end = ptr+len;
        buf_size = end-buf;
      }

      frame_bytes = end-ptr;
      if (frame_bytes > MAX_FRAME_SIZE) goto fail;
      pkt.frame_offset[0] = ptr-buf;
      pkt.frame_size[0] = frame_bytes;
      break;
    case 1:
      // 2 frames, equal size
      pkt.frame_count = 2;
      pkt.vbr = 0;

      if (self_delimiting) {
        int len = xiph_lacing_16bit(&ptr, end);
        if (len < 0 || 2 * len > end-ptr) goto fail;
        end = ptr+2*len;
        buf_size = end-buf;
      }

      frame_bytes = end-ptr;
      if ((frame_bytes&1) != 0 || (frame_bytes>>1) > MAX_FRAME_SIZE) goto fail;
      pkt.frame_offset[0] = ptr-buf;
      pkt.frame_size[0] = frame_bytes>>1;
      pkt.frame_offset[1] = pkt.frame_offset[0]+pkt.frame_size[0];
      pkt.frame_size[1] = frame_bytes>>1;
      break;
    case 2:
      // 2 frames, different sizes
      pkt.frame_count = 2;
      pkt.vbr = 1;

      // read 1st frame size
      frame_bytes = xiph_lacing_16bit(&ptr, end);
      if (frame_bytes < 0) goto fail;

      if (self_delimiting) {
        int len = xiph_lacing_16bit(&ptr, end);
        if (len < 0 || len+frame_bytes > end-ptr) goto fail;
        end = ptr+frame_bytes+len;
        buf_size = end-buf;
      }

      pkt.frame_offset[0] = ptr-buf;
      pkt.frame_size[0] = frame_bytes;

      // calculate 2nd frame size
      frame_bytes = end-ptr-pkt.frame_size[0];
      if (frame_bytes < 0 || frame_bytes > MAX_FRAME_SIZE) goto fail;
      pkt.frame_offset[1] = pkt.frame_offset[0]+pkt.frame_size[0];
      pkt.frame_size[1] = frame_bytes;
      break;
    case 3:
      // 1 to 48 frames, can be different sizes
      i = *ptr++;
      pkt.frame_count = (i   )&0x3F;
      padding         = (i>>6)&0x01;
      pkt.vbr         = (i>>7)&0x01;
      //conwriteln("  frc=", pkt.frame_count, "; padding=", padding, "; vbr=", pkt.vbr);

      if (pkt.frame_count == 0 || pkt.frame_count > MAX_FRAMES) goto fail;

      // read padding size
      if (padding) {
        padding = xiph_lacing_full(&ptr, end);
        if (padding < 0) goto fail;
        //conwriteln("  real padding=", padding);
      }

      // read frame sizes
      if (pkt.vbr) {
        // for VBR, all frames except the final one have their size coded in the bitstream. the last frame size is implicit
        int total_bytes = 0;
        for (i = 0; i < pkt.frame_count-1; i++) {
          frame_bytes = xiph_lacing_16bit(&ptr, end);
          if (frame_bytes < 0) goto fail;
          pkt.frame_size[i] = frame_bytes;
          total_bytes += frame_bytes;
        }

        if (self_delimiting) {
          int len = xiph_lacing_16bit(&ptr, end);
          if (len < 0 || len+total_bytes+padding > end-ptr) goto fail;
          end = ptr+total_bytes+len+padding;
          buf_size = end-buf;
        }

        frame_bytes = end-ptr-padding;
        if (total_bytes > frame_bytes) goto fail;
        pkt.frame_offset[0] = ptr-buf;
        for (i = 1; i < pkt.frame_count; i++) pkt.frame_offset[i] = pkt.frame_offset[i-1]+pkt.frame_size[i-1];
        pkt.frame_size[pkt.frame_count-1] = frame_bytes-total_bytes;
      } else {
        // for CBR, the remaining packet bytes are divided evenly between the frames
        if (self_delimiting) {
          frame_bytes = xiph_lacing_16bit(&ptr, end);
          //conwriteln("frame_bytes=", frame_bytes);
          if (frame_bytes < 0 || pkt.frame_count*frame_bytes+padding > end-ptr) goto fail;
          end = ptr+pkt.frame_count*frame_bytes+padding;
          buf_size = end-buf;
        } else {
          frame_bytes = end-ptr-padding;
          //conwriteln("frame_bytes=", frame_bytes);
          if (frame_bytes % pkt.frame_count || frame_bytes/pkt.frame_count > MAX_FRAME_SIZE) goto fail;
          frame_bytes /= pkt.frame_count;
        }

        pkt.frame_offset[0] = ptr-buf;
        pkt.frame_size[0]   = frame_bytes;
        for (i = 1; i < pkt.frame_count; i++) {
          pkt.frame_offset[i] = pkt.frame_offset[i-1]+pkt.frame_size[i-1];
          pkt.frame_size[i] = frame_bytes;
        }
      }
      break;
  }

  pkt.packet_size = buf_size;
  pkt.data_size = pkt.packet_size-padding;

  // total packet duration cannot be larger than 120ms
  pkt.frame_duration = opus_frame_duration[pkt.config];
  if (pkt.frame_duration*pkt.frame_count > MAX_PACKET_DUR) goto fail;

  // set mode and bandwidth
  if (pkt.config < 12) {
    pkt.mode = OPUS_MODE_SILK;
    pkt.bandwidth = pkt.config>>2;
    //conwriteln("SILK: ", pkt.bandwidth);
  } else if (pkt.config < 16) {
    pkt.mode = OPUS_MODE_HYBRID;
    pkt.bandwidth = OPUS_BANDWIDTH_SUPERWIDEBAND+(pkt.config >= 14 ? 1 : 0);
    //conwriteln("HYB: ", pkt.bandwidth);
  } else {
    pkt.mode = OPUS_MODE_CELT;
    pkt.bandwidth = (pkt.config-16)>>2;
    // skip medium band
    if (pkt.bandwidth) ++pkt.bandwidth;
    //conwriteln("CELT: ", pkt.bandwidth);
  }

  return 0;

fail:
  memset(pkt, 0, (*pkt).sizeof);
  return AVERROR_INVALIDDATA;
}

static int channel_reorder_vorbis(int nb_channels, int channel_idx)
{
    return ff_vorbis_channel_layout_offsets[nb_channels - 1][channel_idx];
}

static int channel_reorder_unknown(int nb_channels, int channel_idx)
{
    return channel_idx;
}


int ff_opus_parse_extradata(AVCtx* avctx, OpusContext* s) {
  static immutable ubyte[2] default_channel_map = [ 0, 1 ];

  int function (int, int) channel_reorder = &channel_reorder_unknown;

  const(uint8_t)* extradata, channel_map;
  int extradata_size;
  int ver, channels, map_type, streams, stereo_streams, i, j;
  uint64_t layout;

  if (!avctx.extradata) {
    if (avctx.channels > 2) {
      conwriteln("Multichannel configuration without extradata.");
      return AVERROR(EINVAL);
    }
    extradata      = opus_default_extradata.ptr;
    extradata_size = cast(uint)opus_default_extradata.length;
  } else {
    extradata = avctx.extradata;
    extradata_size = avctx.extradata_size;
  }

  if (extradata_size < 19) {
    conwriteln("Invalid extradata size: %s", extradata_size);
    return AVERROR_INVALIDDATA;
  }

  ver = extradata[8];
  if (ver > 15) {
    conwriteln("Extradata version %s", ver);
    return AVERROR_PATCHWELCOME;
  }

  avctx.delay = AV_RL16(extradata + 10);

  channels = avctx.extradata ? extradata[9] : (avctx.channels == 1) ? 1 : 2;
  if (!channels) {
    conwriteln("Zero channel count specified in the extradata");
    return AVERROR_INVALIDDATA;
  }

  s.gain_i = AV_RL16(extradata + 16);
  if (s.gain_i) s.gain = ff_exp10(s.gain_i / (20.0 * 256));

  map_type = extradata[18];
  if (!map_type) {
    if (channels > 2) {
      conwriteln("Channel mapping 0 is only specified for up to 2 channels");
      return AVERROR_INVALIDDATA;
    }
    layout         = (channels == 1) ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
    streams        = 1;
    stereo_streams = channels - 1;
    channel_map    = default_channel_map.ptr;
  } else if (map_type == 1 || map_type == 2 || map_type == 255) {
    if (extradata_size < 21 + channels) {
      conwriteln("Invalid extradata size: %s", extradata_size);
      return AVERROR_INVALIDDATA;
    }

    streams        = extradata[19];
    stereo_streams = extradata[20];
    if (!streams || stereo_streams > streams || streams + stereo_streams > 255) {
      conwriteln("Invalid stream/stereo stream count: %s/%s", streams, stereo_streams);
      return AVERROR_INVALIDDATA;
    }

    if (map_type == 1) {
      if (channels > 8) {
        conwriteln("Channel mapping 1 is only specified for up to 8 channels");
        return AVERROR_INVALIDDATA;
      }
      layout = ff_vorbis_channel_layouts[channels - 1];
      //!channel_reorder = channel_reorder_vorbis;
    } else if (map_type == 2) {
      int ambisonic_order = ff_sqrt(channels) - 1;
      if (channels != (ambisonic_order + 1) * (ambisonic_order + 1)) {
        conwriteln("Channel mapping 2 is only specified for channel counts which can be written as (n + 1)^2 for nonnegative integer n");
        return AVERROR_INVALIDDATA;
      }
      layout = 0;
    } else {
      layout = 0;
    }

    channel_map = extradata + 21;
  } else {
    conwriteln("Mapping type %s", map_type);
    return AVERROR_PATCHWELCOME;
  }

  s.channel_maps = av_mallocz_array!(typeof(s.channel_maps[0]))(channels);
  if (s.channel_maps is null) return AVERROR(ENOMEM);

  for (i = 0; i < channels; i++) {
    ChannelMap* map = &s.channel_maps[i];
    uint8_t idx = channel_map[channel_reorder(channels, i)];

    if (idx == 255) {
      map.silence = 1;
      continue;
    } else if (idx >= streams + stereo_streams) {
      conwriteln("Invalid channel map for output channel %s: %s", i, idx);
      return AVERROR_INVALIDDATA;
    }

    // check that we did not see this index yet
    map.copy = 0;
    for (j = 0; j < i; j++) {
      if (channel_map[channel_reorder(channels, j)] == idx) {
        map.copy     = 1;
        map.copy_idx = j;
        break;
      }
    }

    if (idx < 2*stereo_streams) {
      map.stream_idx  = idx/2;
      map.channel_idx = idx&1;
    } else {
      map.stream_idx  = idx-stereo_streams;
      map.channel_idx = 0;
    }
  }

  avctx.channels       = channels;
  avctx.channel_layout = layout;
  s.nb_streams         = streams;
  s.nb_stereo_streams  = stereo_streams;

  return 0;
}


// ////////////////////////////////////////////////////////////////////////// //
struct oggopus_private {
  int need_comments;
  uint pre_skip;
  int64_t cur_dts;
}

enum OPUS_SEEK_PREROLL_MS = 80;
enum OPUS_HEAD_SIZE = 19;

static int opus_header (AVCtx* avf, ref OggStream ogg) {
  if (avf.priv is null) {
    avf.priv = av_mallocz!oggopus_private(1);
    if (avf.priv is null) return AVERROR(ENOMEM);
  }
  auto priv = cast(oggopus_private*)avf.priv;
  //uint8_t *packet              = os.buf + os.pstart;

  if (ogg.packetBos) {
    if (ogg.packetLength < OPUS_HEAD_SIZE || (ogg.packetData[8]&0xF0) != 0) return AVERROR_INVALIDDATA;
      //st.codecpar.codec_type = AVMEDIA_TYPE_AUDIO;
      //st.codecpar.codec_id   = AV_CODEC_ID_OPUS;
      //st.codecpar.channels   = ost.packetData[8];

      priv.pre_skip        = ogg.getMemInt!ushort(ogg.packetData.ptr+10);
      avf.preskip = priv.pre_skip;
      //!!!st.codecpar.initial_padding = priv.pre_skip;
      /*orig_sample_rate    = AV_RL32(packet + 12);*/
      /*gain                = AV_RL16(packet + 16);*/
      /*channel_map         = AV_RL8 (packet + 18);*/

      //if (ff_alloc_extradata(st.codecpar, os.psize)) return AVERROR(ENOMEM);
      avf.extradata = av_mallocz!ubyte(ogg.packetLength);
      avf.extradata[0..ogg.packetLength] = ogg.packetData[0..ogg.packetLength];
      avf.extradata_size = cast(uint)ogg.packetLength;

      //memcpy(st.codecpar.extradata, packet, os.psize);

      //st.codecpar.sample_rate = 48000;
      //st.codecpar.seek_preroll = av_rescale(OPUS_SEEK_PREROLL_MS, st.codecpar.sample_rate, 1000);
      //avpriv_set_pts_info(st, 64, 1, 48000);
      priv.need_comments = 1;
      return 2;
  }

  if (priv.need_comments) {
    import core.stdc.string : memcmp;
    if (ogg.packetLength < 8 || memcmp(ogg.packetData.ptr, "OpusTags".ptr, 8) != 0) return AVERROR_INVALIDDATA;
    //ff_vorbis_stream_comment(avf, st, ogg.packetData.ptr + 8, ogg.packetLength - 8);
    --priv.need_comments;
    return 1;
  }

  return 0;
}

static int opus_duration (const(uint8_t)* src, int size) {
  uint nb_frames  = 1;
  uint toc        = src[0];
  uint toc_config = toc>>3;
  uint toc_count  = toc&3;
  uint frame_size = toc_config < 12 ? FFMAX(480, 960 * (toc_config & 3)) :
                    toc_config < 16 ? 480 << (toc_config & 1) : 120 << (toc_config & 3);
  if (toc_count == 3) {
    if (size<2) return AVERROR_INVALIDDATA;
    nb_frames = src[1] & 0x3F;
  } else if (toc_count) {
    nb_frames = 2;
  }

  return frame_size*nb_frames;
}

static int opus_packet (AVCtx* avf, ref OggStream ogg) {
  //AVStream *st                 = avf.streams[idx];
  auto priv = cast(oggopus_private*)avf.priv;
  //uint8_t *packet              = os.buf + os.pstart;
  int ret;

  if (!ogg.packetLength)
      return AVERROR_INVALIDDATA;
  if (ogg.packetGranule > (1UL << 62)) {
      //av_log(avf, AV_LOG_ERROR, "Unsupported huge granule pos %"PRId64 "\n", os.granule);
      return AVERROR_INVALIDDATA;
  }

  //if ((!ogg.lastpts || ogg.lastpts == AV_NOPTS_VALUE) && !(ogg.flags & OGG_FLAG_EOS))
  if (ogg.packetGranule != 0 && !ogg.packetEos) {
      /*!
      int seg, d;
      int duration;
      uint8_t *last_pkt  = os.buf + os.pstart;
      uint8_t *next_pkt  = last_pkt;

      duration = 0;
      seg = os.segp;
      d = opus_duration(last_pkt, ogg.packetLength);
      if (d < 0) {
          os.pflags |= AV_PKT_FLAG_CORRUPT;
          return 0;
      }
      duration += d;
      last_pkt = next_pkt =  next_pkt + ogg.packetLength;
      for (; seg < os.nsegs; seg++) {
          next_pkt += os.segments[seg];
          if (os.segments[seg] < 255 && next_pkt != last_pkt) {
              int d = opus_duration(last_pkt, next_pkt - last_pkt);
              if (d > 0)
                  duration += d;
              last_pkt = next_pkt;
          }
      }
      os.lastpts                 =
      os.lastdts                 = os.granule - duration;
      */
  }

  if ((ret = opus_duration(ogg.packetData.ptr, ogg.packetLength)) < 0)
      return ret;

  /*!
  os.pduration = ret;
  if (os.lastpts != AV_NOPTS_VALUE) {
      if (st.start_time == AV_NOPTS_VALUE)
          st.start_time = os.lastpts;
      priv.cur_dts = os.lastdts = os.lastpts -= priv.pre_skip;
  }

  priv.cur_dts += os.pduration;
  if ((os.flags & OGG_FLAG_EOS)) {
      int64_t skip = priv.cur_dts - os.granule + priv.pre_skip;
      skip = FFMIN(skip, os.pduration);
      if (skip > 0) {
          os.pduration = skip < os.pduration ? os.pduration - skip : 1;
          os.end_trimming = skip;
          //av_log(avf, AV_LOG_DEBUG, "Last packet was truncated to %d due to end trimming.\n", os.pduration);
      }
  }
  */

  return 0;
}
