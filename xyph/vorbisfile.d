/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis SOFTWARE CODEC SOURCE CODE.   *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE OggVorbis SOURCE CODE IS (C) COPYRIGHT 1994-2007             *
 * by the Xiph.Org Foundation http://www.xiph.org/                  *
 *                                                                  *
 ********************************************************************/
module iv.xyph.vorbisfile is aliced;
pragma(lib, "vorbisfile");

import core.stdc.config;
import core.stdc.stdio;

import iv.xyph.ogg;
import iv.xyph.vorbis;


extern(C) nothrow @nogc:

struct ov_callbacks {
  usize function (void *ptr, usize size, usize nmemb, void *datasource) read_func;
  int function (void *datasource, long offset, int whence) seek_func;
  int function (void *datasource) close_func;
  c_long function (void *datasource) tell_func;
}

enum {
  NOTOPEN   = 0,
  PARTOPEN  = 1,
  OPENED    = 2,
  STREAMSET = 3,
  INITSET   = 4,
}


struct OggVorbis_File {
  void* datasource; /* Pointer to a FILE *, etc. */
  int seekable;
  long offset;
  long end;
  ogg_sync_state oy;

  /* If the FILE handle isn't seekable (eg, a pipe), only the current stream appears */
  int links;
  long* offsets;
  long* dataoffsets;
  c_long* serialnos;
  long* pcmlengths; /* overloaded to maintain binary compatibility; x2 size, stores both beginning and end values */
  vorbis_info* vi;
  vorbis_comment* vc;

  /* Decoding working state local storage */
  long pcm_offset;
  int ready_state;
  c_long current_serialno;
  int current_link;

  double bittrack;
  double samptrack;

  ogg_stream_state os; /* take physical pages, weld into a logical stream of packets */
  vorbis_dsp_state vd; /* central working state for the packet->PCM decoder */
  vorbis_block vb; /* local working space for packet->PCM decode */

  ov_callbacks callbacks;
}


int ov_clear (OggVorbis_File* vf);
int ov_fopen (const(char)* path, OggVorbis_File* vf);
int ov_open (FILE* f, OggVorbis_File* vf, const(char)* initial, c_long ibytes);
int ov_open_callbacks (void* datasource, OggVorbis_File* vf, const(char)* initial, c_long ibytes, ov_callbacks callbacks);

int ov_test (FILE* f, OggVorbis_File* vf, const(char)* initial, c_long ibytes);
int ov_test_callbacks (void* datasource, OggVorbis_File* vf, const(char)* initial, c_long ibytes, ov_callbacks callbacks);
int ov_test_open (OggVorbis_File* vf);

c_long ov_bitrate (OggVorbis_File* vf, int i);
c_long ov_bitrate_instant (OggVorbis_File* vf);
c_long ov_streams (OggVorbis_File* vf);
c_long ov_seekable (OggVorbis_File* vf);
c_long ov_serialnumber (OggVorbis_File* vf, int i);

long ov_raw_total (OggVorbis_File* vf, int i);
long ov_pcm_total (OggVorbis_File* vf, int i);
double ov_time_total (OggVorbis_File* vf, int i);

int ov_raw_seek (OggVorbis_File* vf, long pos);
int ov_pcm_seek (OggVorbis_File* vf, long pos);
int ov_pcm_seek_page (OggVorbis_File* vf, long pos);
int ov_time_seek (OggVorbis_File* vf, double pos);
int ov_time_seek_page (OggVorbis_File* vf, double pos);

int ov_raw_seek_lap (OggVorbis_File* vf, long pos);
int ov_pcm_seek_lap (OggVorbis_File* vf, long pos);
int ov_pcm_seek_page_lap (OggVorbis_File* vf, long pos);
int ov_time_seek_lap (OggVorbis_File* vf, double pos);
int ov_time_seek_page_lap (OggVorbis_File* vf, double pos);

long ov_raw_tell (OggVorbis_File* vf);
long ov_pcm_tell (OggVorbis_File* vf);
double ov_time_tell (OggVorbis_File* vf);

vorbis_info* ov_info (OggVorbis_File* vf, int link);
vorbis_comment* ov_comment (OggVorbis_File* vf, int link);

c_long ov_read_float (OggVorbis_File* vf, float*** pcm_channels, int samples, int* bitstream);
c_long ov_read_filter (OggVorbis_File* vf, char* buffer, int length, int bigendianp, int word, int sgned, int* bitstream,
                          void function (float** pcm, c_long channels, c_long samples, void* filter_param) filter, void* filter_param);
c_long ov_read (OggVorbis_File* vf, void* buffer, int length, int bigendianp, int word, int sgned, int* bitstream);
int ov_crosslap (OggVorbis_File* vf1, OggVorbis_File* vf2);

int ov_halfrate (OggVorbis_File* vf, int flag);
int ov_halfrate_p (OggVorbis_File* vf);


private {
  usize libcfile_VorbisRead (void* ptr, usize byteSize, usize sizeToRead, void* datasource) {
    return fread(ptr, byteSize, sizeToRead, cast(FILE*)datasource);
  }

  int libcfile_VorbisSeek (void* datasource, long offset, int whence) {
    return fseek(cast(FILE*)datasource, cast(int)offset, whence);
  }

  int libcfile_VorbisClose (void* datasource) {
    return fclose(cast(FILE*)datasource);
  }

  c_long libcfile_VorbisTell (void* datasource) {
    return cast(c_long)ftell(cast(FILE*)datasource);
  }
}

// ov_open is rewritten below because of incompatibility between compilers with FILE struct
// Using this wrapper, it *should* work exactly as it would in c++. --JoeCoder
int ov_open (FILE* f, OggVorbis_File* vf, const(char)* initial, c_long ibytes) {
  // Fill the ov_callbacks structure
  ov_callbacks vorbisCallbacks; // Structure to hold pointers to callback functions
  vorbisCallbacks.read_func = &libcfile_VorbisRead;
  vorbisCallbacks.close_func = &libcfile_VorbisClose;
  vorbisCallbacks.seek_func = &libcfile_VorbisSeek;
  vorbisCallbacks.tell_func = &libcfile_VorbisTell;
  return ov_open_callbacks(cast(void*)f, vf, initial, cast(int)ibytes, vorbisCallbacks);
}

int ov_open_noclose (FILE* f, OggVorbis_File* vf, const(char)* initial, c_long ibytes) {
  // Fill the ov_callbacks structure
  ov_callbacks vorbisCallbacks; // Structure to hold pointers to callback functions
  vorbisCallbacks.read_func = &libcfile_VorbisRead;
  vorbisCallbacks.close_func = null;
  vorbisCallbacks.seek_func = &libcfile_VorbisSeek;
  vorbisCallbacks.tell_func = &libcfile_VorbisTell;
  return ov_open_callbacks(cast(void*)f, vf, initial, cast(int)ibytes, vorbisCallbacks);
}

// ditto for ov_test
int ov_test (FILE* f, OggVorbis_File* vf, const(char)* initial, c_long ibytes) {
  // Fill the ov_callbacks structure
  ov_callbacks vorbisCallbacks; // Structure to hold pointers to callback functions
  vorbisCallbacks.read_func = &libcfile_VorbisRead;
  vorbisCallbacks.close_func = &libcfile_VorbisClose;
  vorbisCallbacks.seek_func = &libcfile_VorbisSeek;
  vorbisCallbacks.tell_func = &libcfile_VorbisTell;
  return ov_test_callbacks(cast(void*)f, vf, initial, cast(int)ibytes, vorbisCallbacks);
}
