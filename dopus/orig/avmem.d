module avmem is aliced;

enum {
  EOK = 0,
  EINVAL,
  ENOMEM,
}

int AVERROR (int v) { return -v; }

enum AVERROR_INVALIDDATA = -EINVAL;
enum AVERROR_PATCHWELCOME = -EINVAL;
enum AVERROR_BUG = -EINVAL;

void av_free(T) (T* p) {
  if (p !is null) {
    import core.stdc.stdlib : free;
    free(p);
  }
}


void av_freep(T) (T** p) {
  if (p !is null) {
    if (*p !is null) {
      import core.stdc.stdlib : free;
      free(*p);
      *p = null;
    }
  }
}


T* av_mallocz(T) (size_t cnt=1) {
  if (cnt == 0) return null;
  import core.stdc.stdlib : calloc;
  return cast(T*)calloc(cnt, T.sizeof);
}

alias av_malloc_array = av_mallocz;
alias av_mallocz_array = av_mallocz;
alias av_malloc = av_mallocz;

/*
int av_reallocp_array(T) (T** ptr, size_t cnt) {
  import core.stdc.stdlib : free, realloc;
  if (ptr is null) return -1;
  if (cnt == 0) {
    if (*ptr) free(*ptr);
    *ptr = null;
  } else {
    auto np = realloc(*ptr, T.sizeof*cnt);
    if (np is null) return -1;
    *ptr = cast(T*)np;
  }
  return 0;
}
*/


/*
 * Allocates a buffer, reusing the given one if large enough.
 * Contrary to av_fast_realloc the current buffer contents might not be preserved and on error
 * the old buffer is freed, thus no special handling to avoid memleaks is necessary.
 */
void av_fast_malloc (void** ptr, int* size, uint min_size) {
  static T FFMAX(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }
  void **p = ptr;
  if (min_size < *size) return;
  *size= FFMAX(17*min_size/16+32, min_size);
  av_free(*p);
  *p = av_malloc!ubyte(*size);
  if (!*p) *size = 0;
}


struct AVAudioFifo {
  //int fmt; // 8
  uint chans;
  float* buf;
  uint rdpos;
  uint used;
  uint alloced;
}

int av_audio_fifo_size (AVAudioFifo* af) {
  //{ import core.stdc.stdio : printf; printf("fifosize=%u\n", (af.used-af.rdpos)/af.chans); }
  return (af !is null ? (af.used-af.rdpos)/af.chans : -1);
}

int av_audio_fifo_read (AVAudioFifo* af, void** data, int nb_samples) {
  if (af is null) return -1;
  //{ import core.stdc.stdio : printf; printf("fiforead=%u\n", nb_samples); }
  auto dp = cast(float**)data;
  int total;
  while (nb_samples > 0) {
    if (af.used-af.rdpos < af.chans) break;
    foreach (immutable chn; 0..af.chans) *dp[chn]++ = af.buf[af.rdpos++];
    ++total;
    --nb_samples;
  }
  return total;
}

int av_audio_fifo_drain (AVAudioFifo* af, int nb_samples) {
  if (af is null) return -1;
  //{ import core.stdc.stdio : printf; printf("fifodrain=%u\n", nb_samples); }
  while (nb_samples > 0) {
    if (af.used-af.rdpos < af.chans) break;
    af.rdpos += af.chans;
    --nb_samples;
  }
  return 0;
}

int av_audio_fifo_write (AVAudioFifo* af, void** data, int nb_samples) {
  import core.stdc.string : memmove;
  { import core.stdc.stdio : printf; printf("fifowrite=%u\n", nb_samples); }
  assert(0);
  if (af is null || nb_samples < 0) return -1;
  if (nb_samples == 0) return 0;
  if (af.rdpos >= af.used) af.rdpos = af.used = 0;
  if (af.rdpos > 0) {
    memmove(af.buf, af.buf+af.rdpos, (af.used-af.rdpos)*float.sizeof);
    af.used -= af.rdpos;
    af.rdpos = 0;
  }
  if (af.used+nb_samples*af.chans > af.alloced) {
    import core.stdc.stdlib : realloc;
    uint newsz = af.used+nb_samples*af.chans;
    auto nb = cast(float*)realloc(af.buf, newsz*float.sizeof);
    if (nb is null) return -1;
    af.buf = nb;
    af.alloced = newsz;
  }
  auto dp = cast(float**)data;
  int total;
  while (nb_samples > 0) {
    if (af.alloced-af.used < af.chans) assert(0);
    foreach (immutable chn; 0..af.chans) af.buf[af.used++] = *dp[chn]++;
    ++total;
    --nb_samples;
  }
  return total;
}

AVAudioFifo* av_audio_fifo_alloc (int samplefmt, int channels, int nb_samples) {
  if (samplefmt != 8) assert(0);
  if (channels < 1 || channels > 255) assert(0);
  if (nb_samples < 0) nb_samples = 0;
  if (nb_samples > int.max/32) nb_samples = int.max/32;
  AVAudioFifo* av = av_mallocz!AVAudioFifo(1);
  if (av is null) return null;
  av.chans = channels;
  av.alloced = channels*nb_samples;
  av.buf = av_mallocz!float(av.alloced);
  if (av.buf is null) {
    av_free(av);
    return null;
  }
  av.rdpos = 0;
  av.used = 0;
  return av;
}

int av_audio_fifo_free (AVAudioFifo* af) {
  if (af !is null) {
    if (af.buf !is null) av_free(af.buf);
    *af = AVAudioFifo.init;
    av_free(af);
  }
  return 0;
}


struct AudioChannelMap {
  int  file_idx,  stream_idx,  channel_idx; // input
  int ofile_idx, ostream_idx;               // output
}


enum AV_CH_FRONT_LEFT = 0x00000001;
enum AV_CH_FRONT_RIGHT = 0x00000002;
enum AV_CH_FRONT_CENTER = 0x00000004;
enum AV_CH_LOW_FREQUENCY = 0x00000008;
enum AV_CH_BACK_LEFT = 0x00000010;
enum AV_CH_BACK_RIGHT = 0x00000020;
enum AV_CH_FRONT_LEFT_OF_CENTER = 0x00000040;
enum AV_CH_FRONT_RIGHT_OF_CENTER = 0x00000080;
enum AV_CH_BACK_CENTER = 0x00000100;
enum AV_CH_SIDE_LEFT = 0x00000200;
enum AV_CH_SIDE_RIGHT = 0x00000400;
enum AV_CH_TOP_CENTER = 0x00000800;
enum AV_CH_TOP_FRONT_LEFT = 0x00001000;
enum AV_CH_TOP_FRONT_CENTER = 0x00002000;
enum AV_CH_TOP_FRONT_RIGHT = 0x00004000;
enum AV_CH_TOP_BACK_LEFT = 0x00008000;
enum AV_CH_TOP_BACK_CENTER = 0x00010000;
enum AV_CH_TOP_BACK_RIGHT = 0x00020000;
enum AV_CH_STEREO_LEFT = 0x20000000;  ///< Stereo downmix.
enum AV_CH_STEREO_RIGHT = 0x40000000;  ///< See AV_CH_STEREO_LEFT.
enum AV_CH_WIDE_LEFT = 0x0000000080000000UL;
enum AV_CH_WIDE_RIGHT = 0x0000000100000000UL;
enum AV_CH_SURROUND_DIRECT_LEFT = 0x0000000200000000UL;
enum AV_CH_SURROUND_DIRECT_RIGHT = 0x0000000400000000UL;
enum AV_CH_LOW_FREQUENCY_2 = 0x0000000800000000UL;

/** Channel mask value used for AVCodecContext.request_channel_layout
    to indicate that the user requests the channel order of the decoder output
    to be the native codec channel order. */
enum AV_CH_LAYOUT_NATIVE = 0x8000000000000000UL;

/**
 * @}
 * @defgroup channel_mask_c Audio channel layouts
 * @{
 * */
enum AV_CH_LAYOUT_MONO = (AV_CH_FRONT_CENTER);
enum AV_CH_LAYOUT_STEREO = (AV_CH_FRONT_LEFT|AV_CH_FRONT_RIGHT);
enum AV_CH_LAYOUT_2POINT1 = (AV_CH_LAYOUT_STEREO|AV_CH_LOW_FREQUENCY);
enum AV_CH_LAYOUT_2_1 = (AV_CH_LAYOUT_STEREO|AV_CH_BACK_CENTER);
enum AV_CH_LAYOUT_SURROUND = (AV_CH_LAYOUT_STEREO|AV_CH_FRONT_CENTER);
enum AV_CH_LAYOUT_3POINT1 = (AV_CH_LAYOUT_SURROUND|AV_CH_LOW_FREQUENCY);
enum AV_CH_LAYOUT_4POINT0 = (AV_CH_LAYOUT_SURROUND|AV_CH_BACK_CENTER);
enum AV_CH_LAYOUT_4POINT1 = (AV_CH_LAYOUT_4POINT0|AV_CH_LOW_FREQUENCY);
enum AV_CH_LAYOUT_2_2 = (AV_CH_LAYOUT_STEREO|AV_CH_SIDE_LEFT|AV_CH_SIDE_RIGHT);
enum AV_CH_LAYOUT_QUAD = (AV_CH_LAYOUT_STEREO|AV_CH_BACK_LEFT|AV_CH_BACK_RIGHT);
enum AV_CH_LAYOUT_5POINT0 = (AV_CH_LAYOUT_SURROUND|AV_CH_SIDE_LEFT|AV_CH_SIDE_RIGHT);
enum AV_CH_LAYOUT_5POINT1 = (AV_CH_LAYOUT_5POINT0|AV_CH_LOW_FREQUENCY);
enum AV_CH_LAYOUT_5POINT0_BACK = (AV_CH_LAYOUT_SURROUND|AV_CH_BACK_LEFT|AV_CH_BACK_RIGHT);
enum AV_CH_LAYOUT_5POINT1_BACK = (AV_CH_LAYOUT_5POINT0_BACK|AV_CH_LOW_FREQUENCY);
enum AV_CH_LAYOUT_6POINT0 = (AV_CH_LAYOUT_5POINT0|AV_CH_BACK_CENTER);
enum AV_CH_LAYOUT_6POINT0_FRONT = (AV_CH_LAYOUT_2_2|AV_CH_FRONT_LEFT_OF_CENTER|AV_CH_FRONT_RIGHT_OF_CENTER);
enum AV_CH_LAYOUT_HEXAGONAL = (AV_CH_LAYOUT_5POINT0_BACK|AV_CH_BACK_CENTER);
enum AV_CH_LAYOUT_6POINT1 = (AV_CH_LAYOUT_5POINT1|AV_CH_BACK_CENTER);
enum AV_CH_LAYOUT_6POINT1_BACK = (AV_CH_LAYOUT_5POINT1_BACK|AV_CH_BACK_CENTER);
enum AV_CH_LAYOUT_6POINT1_FRONT = (AV_CH_LAYOUT_6POINT0_FRONT|AV_CH_LOW_FREQUENCY);
enum AV_CH_LAYOUT_7POINT0 = (AV_CH_LAYOUT_5POINT0|AV_CH_BACK_LEFT|AV_CH_BACK_RIGHT);
enum AV_CH_LAYOUT_7POINT0_FRONT = (AV_CH_LAYOUT_5POINT0|AV_CH_FRONT_LEFT_OF_CENTER|AV_CH_FRONT_RIGHT_OF_CENTER);
enum AV_CH_LAYOUT_7POINT1 = (AV_CH_LAYOUT_5POINT1|AV_CH_BACK_LEFT|AV_CH_BACK_RIGHT);
enum AV_CH_LAYOUT_7POINT1_WIDE = (AV_CH_LAYOUT_5POINT1|AV_CH_FRONT_LEFT_OF_CENTER|AV_CH_FRONT_RIGHT_OF_CENTER);
enum AV_CH_LAYOUT_7POINT1_WIDE_BACK = (AV_CH_LAYOUT_5POINT1_BACK|AV_CH_FRONT_LEFT_OF_CENTER|AV_CH_FRONT_RIGHT_OF_CENTER);
enum AV_CH_LAYOUT_OCTAGONAL = (AV_CH_LAYOUT_5POINT0|AV_CH_BACK_LEFT|AV_CH_BACK_CENTER|AV_CH_BACK_RIGHT);
enum AV_CH_LAYOUT_HEXADECAGONAL = (AV_CH_LAYOUT_OCTAGONAL|AV_CH_WIDE_LEFT|AV_CH_WIDE_RIGHT|AV_CH_TOP_BACK_LEFT|AV_CH_TOP_BACK_RIGHT|AV_CH_TOP_BACK_CENTER|AV_CH_TOP_FRONT_CENTER|AV_CH_TOP_FRONT_LEFT|AV_CH_TOP_FRONT_RIGHT);
enum AV_CH_LAYOUT_STEREO_DOWNMIX = (AV_CH_STEREO_LEFT|AV_CH_STEREO_RIGHT);


struct AVFrame {
  /**
   * number of audio samples (per channel) described by this frame
   */
  int nb_samples;
  /**
   * For video, size in bytes of each picture line.
   * For audio, size in bytes of each plane.
   *
   * For audio, only linesize[0] may be set. For planar audio, each channel
   * plane must be the same size.
   *
   * For video the linesizes should be multiples of the CPUs alignment
   * preference, this is 16 or 32 for modern desktop CPUs.
   * Some code requires such alignment other code can be slower without
   * correct alignment, for yet other it makes no difference.
   *
   * @note The linesize may be larger than the size of usable data -- there
   * may be extra padding present for performance reasons.
   */
  int[1/*AV_NUM_DATA_POINTERS*/] linesize;
  /**
   * pointers to the data planes/channels.
   *
   * For video, this should simply point to data[].
   *
   * For planar audio, each channel has a separate data pointer, and
   * linesize[0] contains the size of each channel buffer.
   * For packed audio, there is just one data pointer, and linesize[0]
   * contains the total size of the buffer for all channels.
   *
   * Note: Both data and extended_data should always be set in a valid frame,
   * but for planar audio with more channels that can fit in data,
   * extended_data must be used in order to access all channels.
   */
  ubyte** extended_data;

  AudioChannelMap* audio_channel_maps; /* one info entry per -map_channel */
  int nb_audio_channel_maps; /* number of (valid) -map_channel settings */
}


int ff_get_buffer (AVFrame* frame, int flags) {
  return 0;
}


struct AVCtx {
  int sample_fmt;
  int sample_rate;
  int channels;
  ubyte* extradata;
  uint extradata_size;
  int delay;
  ulong channel_layout;
  void* priv;
  int preskip;
}


ushort AV_RL16 (const(void*) b) {
  version(LittleEndian) {
    return *cast(const(ushort)*)b;
  } else {
    static assert(0, "boo!");
  }
}


struct AVPacket {
  /**
   * A reference to the reference-counted buffer where the packet data is
   * stored.
   * May be NULL, then the packet data is not reference-counted.
   */
  //AVBufferRef *buf;
  /**
   * Presentation timestamp in AVStream.time_base units; the time at which
   * the decompressed packet will be presented to the user.
   * Can be AV_NOPTS_VALUE if it is not stored in the file.
   * pts MUST be larger or equal to dts as presentation cannot happen before
   * decompression, unless one wants to view hex dumps. Some formats misuse
   * the terms dts and pts/cts to mean something different. Such timestamps
   * must be converted to true pts/dts before they are stored in AVPacket.
   */
  long pts;
  /**
   * Decompression timestamp in AVStream.time_base units; the time at which
   * the packet is decompressed.
   * Can be AV_NOPTS_VALUE if it is not stored in the file.
   */
  long dts;
  ubyte *data;
  int   size;
  int   stream_index;
  /**
   * A combination of AV_PKT_FLAG values
   */
  int   flags;
  /**
   * Additional packet data that can be provided by the container.
   * Packet can contain several types of side information.
   */
  //AVPacketSideData *side_data;
  int side_data_elems;

  /**
   * Duration of this packet in AVStream.time_base units, 0 if unknown.
   * Equals next_pts - this_pts in presentation order.
   */
  long duration;

  long pos;                            ///< byte position in stream, -1 if unknown
}


struct GetBitContext {
private:
  const(ubyte)* buffer;
  uint pos;
  uint bytestotal;
  ubyte curv;
  ubyte bleft;

  __gshared Exception eobs;

  shared static this () { eobs = new Exception("out of bits in stream"); }

public:
  int init_get_bits8 (const(void)* buf, uint bytelen) nothrow @trusted @nogc {
    if (bytelen >= int.max/16) assert(0, "too big");
    buffer = cast(const(ubyte)*)buf;
    bytestotal = bytelen;
    bleft = 0;
    pos = 0;
    return 0;
  }

  T get_bits(T=uint) (uint n) @trusted if (__traits(isIntegral, T)) {
    if (n == 0 || n > 8) assert(0, "invalid number of bits requested");
    T res = 0;
    foreach_reverse (immutable shift; 0..n) {
      if (bleft == 0) {
        if (pos < bytestotal) {
          curv = buffer[pos++];
        } else {
          curv = 0;
          //throw eobs;
        }
        bleft = 8;
      }
      if (curv&0x80) res |= (1U<<shift);
      curv <<= 1;
      --bleft;
    }
    return res;
  }
}
