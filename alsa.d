/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.alsa /*is aliced*/;
pragma(lib, "asound");

import iv.alice;
import core.stdc.config;
import core.sys.posix.poll;

extern(C):
nothrow @trusted: @nogc:
const(char)* snd_strerror (int errnum);

/+
#ifdef __GLIBC__
#if !defined(_POSIX_C_SOURCE) && !defined(_POSIX_SOURCE)
struct timeval {
  time_t tv_sec; /* seconds */
  long tv_usec; /* microseconds */
};

struct timespec {
  time_t tv_sec; /* seconds */
  long tv_nsec; /* nanoseconds */
};
#endif
#endif

/** Timestamp */
typedef struct timeval snd_timestamp_t;
/** Hi-res timestamp */
typedef struct timespec snd_htimestamp_t;
+/

// pcm
alias snd_pcm_stream_t = int;
enum : int {
  SND_PCM_STREAM_PLAYBACK,
  SND_PCM_STREAM_CAPTURE,
}

/** Unsigned frames quantity */
alias snd_pcm_uframes_t = c_ulong;
/** Signed frames quantity */
alias snd_pcm_sframes_t = c_long;


/** PCM type */
alias snd_pcm_type_t = int;
enum : int {
  /** Kernel level PCM */
  SND_PCM_TYPE_HW = 0,
  /** Hooked PCM */
  SND_PCM_TYPE_HOOKS,
  /** One or more linked PCM with exclusive access to selected
      channels */
  SND_PCM_TYPE_MULTI,
  /** File writing plugin */
  SND_PCM_TYPE_FILE,
  /** Null endpoint PCM */
  SND_PCM_TYPE_NULL,
  /** Shared memory client PCM */
  SND_PCM_TYPE_SHM,
  /** INET client PCM (not yet implemented) */
  SND_PCM_TYPE_INET,
  /** Copying plugin */
  SND_PCM_TYPE_COPY,
  /** Linear format conversion PCM */
  SND_PCM_TYPE_LINEAR,
  /** A-Law format conversion PCM */
  SND_PCM_TYPE_ALAW,
  /** Mu-Law format conversion PCM */
  SND_PCM_TYPE_MULAW,
  /** IMA-ADPCM format conversion PCM */
  SND_PCM_TYPE_ADPCM,
  /** Rate conversion PCM */
  SND_PCM_TYPE_RATE,
  /** Attenuated static route PCM */
  SND_PCM_TYPE_ROUTE,
  /** Format adjusted PCM */
  SND_PCM_TYPE_PLUG,
  /** Sharing PCM */
  SND_PCM_TYPE_SHARE,
  /** Meter plugin */
  SND_PCM_TYPE_METER,
  /** Mixing PCM */
  SND_PCM_TYPE_MIX,
  /** Attenuated dynamic route PCM (not yet implemented) */
  SND_PCM_TYPE_DROUTE,
  /** Loopback server plugin (not yet implemented) */
  SND_PCM_TYPE_LBSERVER,
  /** Linear Integer <-> Linear Float format conversion PCM */
  SND_PCM_TYPE_LINEAR_FLOAT,
  /** LADSPA integration plugin */
  SND_PCM_TYPE_LADSPA,
  /** Direct Mixing plugin */
  SND_PCM_TYPE_DMIX,
  /** Jack Audio Connection Kit plugin */
  SND_PCM_TYPE_JACK,
  /** Direct Snooping plugin */
  SND_PCM_TYPE_DSNOOP,
  /** Direct Sharing plugin */
  SND_PCM_TYPE_DSHARE,
  /** IEC958 subframe plugin */
  SND_PCM_TYPE_IEC958,
  /** Soft volume plugin */
  SND_PCM_TYPE_SOFTVOL,
  /** External I/O plugin */
  SND_PCM_TYPE_IOPLUG,
  /** External filter plugin */
  SND_PCM_TYPE_EXTPLUG,
  /** Mmap-emulation plugin */
  SND_PCM_TYPE_MMAP_EMUL,
  SND_PCM_TYPE_LAST = SND_PCM_TYPE_MMAP_EMUL,
};


enum {
  /** Non blocking mode (flag for open mode) \hideinitializer */
  SND_PCM_NONBLOCK = 0x00000001,
  /** Async notification (flag for open mode) \hideinitializer */
  SND_PCM_ASYNC = 0x00000002,
  /** In an abort state (internal, not allowed for open) */
  SND_PCM_ABORT = 0x00008000,
  /** Disable automatic (but not forced!) rate resamplinig */
  SND_PCM_NO_AUTO_RESAMPLE = 0x00010000,
  /** Disable automatic (but not forced!) channel conversion */
  SND_PCM_NO_AUTO_CHANNELS = 0x00020000,
  /** Disable automatic (but not forced!) format conversion */
  SND_PCM_NO_AUTO_FORMAT = 0x00040000,
  /** Disable soft volume control */
  SND_PCM_NO_SOFTVOL = 0x00080000,
}

alias snd_pcm_access_t = int;
enum : int {
  /** mmap access with simple interleaved channels */
  SND_PCM_ACCESS_MMAP_INTERLEAVED = 0,
  /** mmap access with simple non interleaved channels */
  SND_PCM_ACCESS_MMAP_NONINTERLEAVED,
  /** mmap access with complex placement */
  SND_PCM_ACCESS_MMAP_COMPLEX,
  /** snd_pcm_readi/snd_pcm_writei access */
  SND_PCM_ACCESS_RW_INTERLEAVED,
  /** snd_pcm_readn/snd_pcm_writen access */
  SND_PCM_ACCESS_RW_NONINTERLEAVED,
  SND_PCM_ACCESS_LAST = SND_PCM_ACCESS_RW_NONINTERLEAVED,
}

alias snd_pcm_format = int;
enum : int {
  /** Unknown */
  SND_PCM_FORMAT_UNKNOWN = -1,
  /** Signed 8 bit */
  SND_PCM_FORMAT_S8 = 0,
  /** Unsigned 8 bit */
  SND_PCM_FORMAT_U8,
  /** Signed 16 bit Little Endian */
  SND_PCM_FORMAT_S16_LE,
  /** Signed 16 bit Big Endian */
  SND_PCM_FORMAT_S16_BE,
  /** Unsigned 16 bit Little Endian */
  SND_PCM_FORMAT_U16_LE,
  /** Unsigned 16 bit Big Endian */
  SND_PCM_FORMAT_U16_BE,
  /** Signed 24 bit Little Endian using low three bytes in 32-bit word */
  SND_PCM_FORMAT_S24_LE,
  /** Signed 24 bit Big Endian using low three bytes in 32-bit word */
  SND_PCM_FORMAT_S24_BE,
  /** Unsigned 24 bit Little Endian using low three bytes in 32-bit word */
  SND_PCM_FORMAT_U24_LE,
  /** Unsigned 24 bit Big Endian using low three bytes in 32-bit word */
  SND_PCM_FORMAT_U24_BE,
  /** Signed 32 bit Little Endian */
  SND_PCM_FORMAT_S32_LE,
  /** Signed 32 bit Big Endian */
  SND_PCM_FORMAT_S32_BE,
  /** Unsigned 32 bit Little Endian */
  SND_PCM_FORMAT_U32_LE,
  /** Unsigned 32 bit Big Endian */
  SND_PCM_FORMAT_U32_BE,
  /** Float 32 bit Little Endian, Range -1.0 to 1.0 */
  SND_PCM_FORMAT_FLOAT_LE,
  /** Float 32 bit Big Endian, Range -1.0 to 1.0 */
  SND_PCM_FORMAT_FLOAT_BE,
  /** Float 64 bit Little Endian, Range -1.0 to 1.0 */
  SND_PCM_FORMAT_FLOAT64_LE,
  /** Float 64 bit Big Endian, Range -1.0 to 1.0 */
  SND_PCM_FORMAT_FLOAT64_BE,
  /** IEC-958 Little Endian */
  SND_PCM_FORMAT_IEC958_SUBFRAME_LE,
  /** IEC-958 Big Endian */
  SND_PCM_FORMAT_IEC958_SUBFRAME_BE,
  /** Mu-Law */
  SND_PCM_FORMAT_MU_LAW,
  /** A-Law */
  SND_PCM_FORMAT_A_LAW,
  /** Ima-ADPCM */
  SND_PCM_FORMAT_IMA_ADPCM,
  /** MPEG */
  SND_PCM_FORMAT_MPEG,
  /** GSM */
  SND_PCM_FORMAT_GSM,
  /** Special */
  SND_PCM_FORMAT_SPECIAL = 31,
  /** Signed 24bit Little Endian in 3bytes format */
  SND_PCM_FORMAT_S24_3LE = 32,
  /** Signed 24bit Big Endian in 3bytes format */
  SND_PCM_FORMAT_S24_3BE,
  /** Unsigned 24bit Little Endian in 3bytes format */
  SND_PCM_FORMAT_U24_3LE,
  /** Unsigned 24bit Big Endian in 3bytes format */
  SND_PCM_FORMAT_U24_3BE,
  /** Signed 20bit Little Endian in 3bytes format */
  SND_PCM_FORMAT_S20_3LE,
  /** Signed 20bit Big Endian in 3bytes format */
  SND_PCM_FORMAT_S20_3BE,
  /** Unsigned 20bit Little Endian in 3bytes format */
  SND_PCM_FORMAT_U20_3LE,
  /** Unsigned 20bit Big Endian in 3bytes format */
  SND_PCM_FORMAT_U20_3BE,
  /** Signed 18bit Little Endian in 3bytes format */
  SND_PCM_FORMAT_S18_3LE,
  /** Signed 18bit Big Endian in 3bytes format */
  SND_PCM_FORMAT_S18_3BE,
  /** Unsigned 18bit Little Endian in 3bytes format */
  SND_PCM_FORMAT_U18_3LE,
  /** Unsigned 18bit Big Endian in 3bytes format */
  SND_PCM_FORMAT_U18_3BE,
  /* G.723 (ADPCM) 24 kbit/s, 8 samples in 3 bytes */
  SND_PCM_FORMAT_G723_24,
  /* G.723 (ADPCM) 24 kbit/s, 1 sample in 1 byte */
  SND_PCM_FORMAT_G723_24_1B,
  /* G.723 (ADPCM) 40 kbit/s, 8 samples in 3 bytes */
  SND_PCM_FORMAT_G723_40,
  /* G.723 (ADPCM) 40 kbit/s, 1 sample in 1 byte */
  SND_PCM_FORMAT_G723_40_1B,
  /* Direct Stream Digital (DSD) in 1-byte samples (x8) */
  SND_PCM_FORMAT_DSD_U8,
  /* Direct Stream Digital (DSD) in 2-byte samples (x16) */
  SND_PCM_FORMAT_DSD_U16_LE,
  SND_PCM_FORMAT_LAST = SND_PCM_FORMAT_DSD_U16_LE,

  // I snipped a bunch of endian-specific ones!
}

/** PCM state */
alias snd_pcm_state_t = int;
enum : int {
  /** Open */
  SND_PCM_STATE_OPEN = 0,
  /** Setup installed */
  SND_PCM_STATE_SETUP,
  /** Ready to start */
  SND_PCM_STATE_PREPARED,
  /** Running */
  SND_PCM_STATE_RUNNING,
  /** Stopped: underrun (playback) or overrun (capture) detected */
  SND_PCM_STATE_XRUN,
  /** Draining: running (playback) or stopped (capture) */
  SND_PCM_STATE_DRAINING,
  /** Paused */
  SND_PCM_STATE_PAUSED,
  /** Hardware is suspended */
  SND_PCM_STATE_SUSPENDED,
  /** Hardware is disconnected */
  SND_PCM_STATE_DISCONNECTED,
  SND_PCM_STATE_LAST = SND_PCM_STATE_DISCONNECTED,
}

struct snd_pcm_t {}
struct snd_pcm_hw_params_t {}
struct snd_pcm_sw_params_t {}

int snd_pcm_open (snd_pcm_t** pcm, const(char)* name, snd_pcm_stream_t stream, int mode);
int snd_pcm_close (snd_pcm_t* pcm);
const(char)* snd_pcm_name (snd_pcm_t* pcm);
snd_pcm_type_t snd_pcm_type (snd_pcm_t* pcm);
snd_pcm_stream_t snd_pcm_stream (snd_pcm_t* pcm);

int snd_pcm_poll_descriptors_count (snd_pcm_t* pcm);
int snd_pcm_poll_descriptors (snd_pcm_t* pcm, pollfd* pfds, uint space);
int snd_pcm_poll_descriptors_revents (snd_pcm_t* pcm, pollfd* pfds, uint nfds, ushort* revents);
int snd_pcm_nonblock (snd_pcm_t* pcm, int nonblock);
int snd_pcm_abort (snd_pcm_t* pcm) { return snd_pcm_nonblock(pcm, 2); }

int snd_pcm_prepare (snd_pcm_t* pcm);
int snd_pcm_reset (snd_pcm_t* pcm);
//int snd_pcm_status (snd_pcm_t* pcm, snd_pcm_status_t *status);
int snd_pcm_start (snd_pcm_t* pcm);
int snd_pcm_drop (snd_pcm_t* pcm);
int snd_pcm_drain (snd_pcm_t* pcm);
int snd_pcm_pause (snd_pcm_t* pcm, int enable);
snd_pcm_state_t snd_pcm_state (snd_pcm_t* pcm);
int snd_pcm_hwsync (snd_pcm_t* pcm);
int snd_pcm_delay (snd_pcm_t* pcm, snd_pcm_sframes_t *delayp);
int snd_pcm_resume (snd_pcm_t* pcm);
int snd_pcm_recover (snd_pcm_t* pcm, int err, int silent);
//int snd_pcm_htimestamp (snd_pcm_t* pcm, snd_pcm_uframes_t* avail, snd_htimestamp_t* tstamp);
snd_pcm_sframes_t snd_pcm_avail (snd_pcm_t* pcm);
snd_pcm_sframes_t snd_pcm_avail_update (snd_pcm_t* pcm);
int snd_pcm_avail_delay (snd_pcm_t* pcm, snd_pcm_sframes_t* availp, snd_pcm_sframes_t* delayp);
snd_pcm_sframes_t snd_pcm_rewindable (snd_pcm_t* pcm);
snd_pcm_sframes_t snd_pcm_rewind (snd_pcm_t* pcm, snd_pcm_uframes_t frames);
snd_pcm_sframes_t snd_pcm_forwardable (snd_pcm_t* pcm);
snd_pcm_sframes_t snd_pcm_forward (snd_pcm_t* pcm, snd_pcm_uframes_t frames);
snd_pcm_sframes_t snd_pcm_writei (snd_pcm_t* pcm, const(void)* buffer, snd_pcm_uframes_t size);
snd_pcm_sframes_t snd_pcm_readi (snd_pcm_t* pcm, void* buffer, snd_pcm_uframes_t size);
snd_pcm_sframes_t snd_pcm_writen (snd_pcm_t* pcm, void** bufs, snd_pcm_uframes_t size);
snd_pcm_sframes_t snd_pcm_readn (snd_pcm_t* pcm, void** bufs, snd_pcm_uframes_t size);
int snd_pcm_wait (snd_pcm_t* pcm, int timeout);

int snd_pcm_hw_params_current (snd_pcm_t* pcm, snd_pcm_hw_params_t* params);
int snd_pcm_hw_params (snd_pcm_t* pcm, snd_pcm_hw_params_t* params);
int snd_pcm_hw_params_set_channels(snd_pcm_t*, snd_pcm_hw_params_t*, uint);
int snd_pcm_hw_params_malloc(snd_pcm_hw_params_t**);
void snd_pcm_hw_params_free(snd_pcm_hw_params_t*);
int snd_pcm_hw_params_any(snd_pcm_t*, snd_pcm_hw_params_t*);
int snd_pcm_hw_params_set_access(snd_pcm_t*, snd_pcm_hw_params_t*, snd_pcm_access_t);
int snd_pcm_hw_params_set_format(snd_pcm_t*, snd_pcm_hw_params_t*, snd_pcm_format);
int snd_pcm_hw_params_set_rate_near(snd_pcm_t*, snd_pcm_hw_params_t*, uint*, int*);
int snd_pcm_hw_params_set_rate (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_set_buffer_size_near (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val);
int snd_pcm_hw_params_set_buffer_size (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t val);

int snd_pcm_hw_params_set_rate_resample (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val);

int snd_pcm_sw_params_malloc(snd_pcm_sw_params_t**);
void snd_pcm_sw_params_free(snd_pcm_sw_params_t*);

int snd_pcm_sw_params_current(snd_pcm_t *pcm, snd_pcm_sw_params_t *params);
int snd_pcm_sw_params(snd_pcm_t *pcm, snd_pcm_sw_params_t *params);
int snd_pcm_sw_params_set_avail_min(snd_pcm_t*, snd_pcm_sw_params_t*, snd_pcm_uframes_t);
int snd_pcm_sw_params_set_start_threshold(snd_pcm_t*, snd_pcm_sw_params_t*, snd_pcm_uframes_t);
int snd_pcm_sw_params_set_stop_threshold(snd_pcm_t*, snd_pcm_sw_params_t*, snd_pcm_uframes_t);

//alias snd_pcm_sframes_t = c_long;
//alias snd_pcm_uframes_t = c_ulong;
//snd_pcm_sframes_t snd_pcm_writei(snd_pcm_t*, const void*, snd_pcm_uframes_t size);
//snd_pcm_sframes_t snd_pcm_readi(snd_pcm_t*, void*, snd_pcm_uframes_t size);

//int snd_pcm_wait(snd_pcm_t *pcm, int timeout);
//snd_pcm_sframes_t snd_pcm_avail(snd_pcm_t *pcm);
//snd_pcm_sframes_t snd_pcm_avail_update(snd_pcm_t *pcm);

// raw midi


/+
struct snd_rawmidi_t {}
int snd_rawmidi_open(snd_rawmidi_t**, snd_rawmidi_t**, const char*, int);
int snd_rawmidi_close(snd_rawmidi_t*);
int snd_rawmidi_drain(snd_rawmidi_t*);
ssize snd_rawmidi_write(snd_rawmidi_t*, const void*, usize);
ssize snd_rawmidi_read(snd_rawmidi_t*, void*, usize);
+/

// mixer

struct snd_mixer_t {}
struct snd_mixer_elem_t {}
struct snd_mixer_selem_id_t {}

alias snd_mixer_elem_callback_t = int function(snd_mixer_elem_t*, uint);

int snd_mixer_open(snd_mixer_t**, int mode);
int snd_mixer_close(snd_mixer_t*);
int snd_mixer_attach(snd_mixer_t*, const char*);
int snd_mixer_load(snd_mixer_t*);

// FIXME: those aren't actually void*
int snd_mixer_selem_register(snd_mixer_t*, void*, void*);
int snd_mixer_selem_id_malloc(snd_mixer_selem_id_t**);
void snd_mixer_selem_id_free(snd_mixer_selem_id_t*);
void snd_mixer_selem_id_set_index(snd_mixer_selem_id_t*, uint);
void snd_mixer_selem_id_set_name(snd_mixer_selem_id_t*, const char*);
snd_mixer_elem_t* snd_mixer_find_selem(snd_mixer_t*, in snd_mixer_selem_id_t*);

// FIXME: the int should be an enum for channel identifier
int snd_mixer_selem_get_playback_volume(snd_mixer_elem_t*, int, c_long*);

int snd_mixer_selem_get_playback_volume_range(snd_mixer_elem_t*, c_long*, c_long*);

int snd_mixer_selem_set_playback_volume_all(snd_mixer_elem_t*, c_long);

void snd_mixer_elem_set_callback(snd_mixer_elem_t*, snd_mixer_elem_callback_t);
int snd_mixer_poll_descriptors(snd_mixer_t*, pollfd*, uint space);

int snd_mixer_handle_events(snd_mixer_t*);

// FIXME: the first int should be an enum for channel identifier
int snd_mixer_selem_get_playback_switch(snd_mixer_elem_t*, int, int* value);
int snd_mixer_selem_set_playback_switch_all(snd_mixer_elem_t*, int);


int snd_pcm_set_params (snd_pcm_t *pcm, snd_pcm_format format, snd_pcm_access_t access, uint channels, uint rate, int soft_resample, uint latency);
int snd_pcm_get_params (snd_pcm_t *pcm, snd_pcm_uframes_t *buffer_size, snd_pcm_uframes_t *period_size);

int snd_pcm_hw_params_test_rate (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_get_rate_min (const(snd_pcm_hw_params_t)* params, uint* val, int* dir);
int snd_pcm_hw_params_get_rate_max (const(snd_pcm_hw_params_t)* params, uint* val, int* dir);

alias snd_lib_error_handler_t = void function (const(char)* file, int line, const(char)* function_, int err, const(char)* fmt, ...);
int snd_lib_error_set_handler (snd_lib_error_handler_t handler);

private void alsa_message_fucker (const(char)* file, int line, const(char)* function_, int err, const(char)* fmt, ...) {}

void fuck_alsa_messages () {
  snd_lib_error_set_handler(&alsa_message_fucker);
}
