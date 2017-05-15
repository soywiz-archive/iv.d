/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis SOFTWARE CODEC SOURCE CODE.   *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE OggVorbis SOURCE CODE IS (C) COPYRIGHT 1994-2001             *
 * by the Xiph.Org Foundation http://www.xiph.org/                  *
 ********************************************************************/
module iv.xyph.vorbis is aliced;
pragma(lib, "vorbis");

import core.stdc.config;
import iv.xyph.ogg/*: oggpack_buffer, ogg_packet*/;


struct vorbis_info {
  int version_;
  alias ver = version_;
  int channels;
  c_long rate;

  /* The below bitrate declarations are *hints*.
     Combinations of the three values carry the following implications:

     all three set to the same value:
       implies a fixed rate bitstream
     only nominal set:
       implies a VBR stream that averages the nominal bitrate.  No hard
       upper/lower limit
     upper and or lower set:
       implies a VBR bitstream that obeys the bitrate limits. nominal
       may also be set to give a nominal rate.
     none set:
       the coder does not care to speculate.
  */

  c_long bitrate_upper;
  c_long bitrate_nominal;
  c_long bitrate_lower;
  c_long bitrate_window;

  void* codec_setup;
}


/* vorbis_dsp_state buffers the current vorbis audio
   analysis/synthesis state.  The DSP state belongs to a specific
   logical bitstream ****************************************************/
struct vorbis_dsp_state {
  int analysisp;
  vorbis_info* vi;

  float** pcm;
  float** pcmret;
  int pcm_storage;
  int pcm_current;
  int pcm_returned;

  int preextrapolate;
  int eofflag;

  c_long lW;
  c_long W;
  c_long nW;
  c_long centerW;

  long granulepos;
  long sequence;

  long glue_bits;
  long time_bits;
  long floor_bits;
  long res_bits;

  void* backend_state;
}


/* vorbis_block is a single block of data to be processed as part of
the analysis/synthesis stream; it belongs to a specific logical
bitstream, but is independent from other vorbis_blocks belonging to
that logical bitstream. *************************************************/
struct alloc_chain {
  void* ptr;
  alloc_chain* next;
}


struct vorbis_block {
  /* necessary stream state for linking to the framing abstraction */
  float** pcm; /* this is a pointer into local storage */
  oggpack_buffer opb;

  c_long lW;
  c_long W;
  c_long nW;
  int pcmend;
  int mode;

  int eofflag;
  long granulepos;
  long sequence;
  vorbis_dsp_state* vd; /* For read-only access of configuration */

  /* local storage to avoid remallocing; it's up to the mapping to structure it */
  void* localstore;
  c_long localtop;
  c_long localalloc;
  c_long totaluse;
  alloc_chain* reap;

  /* bitmetrics for the frame */
  c_long glue_bits;
  c_long time_bits;
  c_long floor_bits;
  c_long res_bits;

  void* internal;
}


/* vorbis_info contains all the setup information specific to the
   specific compression/decompression mode in progress (eg,
   psychoacoustic settings, channel setup, options, codebook
   etc). vorbis_info and substructures are in backends.h.
*********************************************************************/

/* the comments are not part of vorbis_info so that vorbis_info can be
   static storage */
struct vorbis_comment {
  /* unlimited user comment fields.  libvorbis writes 'libvorbis'
     whatever vendor is set to in encode */
  char** user_comments;
  int* comment_lengths;
  int comments;
  char* vendor;
}


/* libvorbis encodes in two abstraction layers; first we perform DSP
   and produce a packet (see docs/analysis.txt).  The packet is then
   coded into a framed OggSquish bitstream by the second layer (see
   docs/framing.txt).  Decode is the reverse process; we sync/frame
   the bitstream and extract individual packets, then decode the
   packet back into PCM audio.

   The extra framing/packetizing is used in streaming formats, such as
   files.  Over the net (such as with UDP), the framing and
   packetization aren't necessary as they're provided by the transport
   and the streaming layer is not used */

extern(C) nothrow @nogc:

/* Vorbis PRIMITIVES: general ***************************************/
void vorbis_info_init (vorbis_info* vi);
void vorbis_info_clear (vorbis_info* vi);
int vorbis_info_blocksize (vorbis_info* vi, int zo);
void vorbis_comment_init (vorbis_comment* vc);
void vorbis_comment_add (vorbis_comment* vc, const(char)* comment);
void vorbis_comment_add_tag (vorbis_comment* vc, const(char)* tag, const(char)* contents);
char* vorbis_comment_query (vorbis_comment* vc, const(char)* tag, int count);
int vorbis_comment_query_count (vorbis_comment* vc, const(char)* tag);
void vorbis_comment_clear (vorbis_comment* vc);

int vorbis_block_init (vorbis_dsp_state* v, vorbis_block* vb);
int vorbis_block_clear (vorbis_block* vb);
void vorbis_dsp_clear (vorbis_dsp_state* v);
double vorbis_granule_time (vorbis_dsp_state* v, long granulepos);

const(char)* vorbis_version_string ();

/* Vorbis PRIMITIVES: analysis/DSP layer ****************************/

int vorbis_analysis_init (vorbis_dsp_state* v, vorbis_info* vi);
int vorbis_commentheader_out (vorbis_comment* vc, ogg_packet* op);
int vorbis_analysis_headerout (vorbis_dsp_state* v, vorbis_comment* vc, ogg_packet* op, ogg_packet* op_comm, ogg_packet* op_code);
float** vorbis_analysis_buffer (vorbis_dsp_state* v, int vals);
int vorbis_analysis_wrote (vorbis_dsp_state* v, int vals);
int vorbis_analysis_blockout (vorbis_dsp_state* v, vorbis_block* vb);
int vorbis_analysis (vorbis_block* vb, ogg_packet* op);

int vorbis_bitrate_addblock (vorbis_block* vb);
int vorbis_bitrate_flushpacket (vorbis_dsp_state* vd, ogg_packet* op);

/* Vorbis PRIMITIVES: synthesis layer *******************************/
int vorbis_synthesis_idheader (ogg_packet* op);
int vorbis_synthesis_headerin (vorbis_info* vi, vorbis_comment* vc, ogg_packet* op);

int vorbis_synthesis_init (vorbis_dsp_state* v, vorbis_info* vi);
int vorbis_synthesis_restart (vorbis_dsp_state* v);
int vorbis_synthesis (vorbis_block* vb, ogg_packet* op);
int vorbis_synthesis_trackonly (vorbis_block* vb, ogg_packet* op);
int vorbis_synthesis_blockin (vorbis_dsp_state* v, vorbis_block* vb);
int vorbis_synthesis_pcmout (vorbis_dsp_state* v, float*** pcm);
int vorbis_synthesis_lapout (vorbis_dsp_state* v, float*** pcm);
int vorbis_synthesis_read (vorbis_dsp_state* v, int samples);
c_long vorbis_packet_blocksize (vorbis_info* vi, ogg_packet* op);

int vorbis_synthesis_halfrate (vorbis_info* v, int flag);
int vorbis_synthesis_halfrate_p (vorbis_info* v);


/* Vorbis ERRORS and return codes ***********************************/
enum {
  OV_FALSE = -1,
  OV_EOF = -2,
  OV_HOLE = -3,

  OV_EREAD = -128,
  OV_EFAULT = -129,
  OV_EIMPL = -130,
  OV_EINVAL = -131,
  OV_ENOTVORBIS = -132,
  OV_EBADHEADER = -133,
  OV_EVERSION = -134,
  OV_ENOTAUDIO = -135,
  OV_EBADPACKET = -136,
  OV_EBADLINK = -137,
  OV_ENOSEEK = -138,
}
