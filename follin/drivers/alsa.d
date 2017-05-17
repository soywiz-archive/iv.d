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
module iv.follin.drivers.alsa /*is aliced*/;

//version = follin_init_debug;
//version = follin_write_debug;
version = follin_radio_silence_debug;

import core.atomic;

import iv.alice;
import iv.follin.exception;
import iv.follin.sdata;


// ////////////////////////////////////////////////////////////////////////// //
__gshared snd_pcm_t* apcm = null;
__gshared short* sndsilence = null;


// ////////////////////////////////////////////////////////////////////////// //
package(iv.follin) void sndDeinit () nothrow @trusted /*@nogc*/ {
  if (apcm !is null) {
    snd_pcm_drop(apcm);
    snd_pcm_close(apcm);
    apcm = null;
    if (sndsilence !is null) {
      import core.stdc.stdlib : free;
      free(sndsilence);
      sndsilence = null;
    }
  }
}


uint nextPowerOf2 (uint n) {
  //static if (__VERSION__ > 2067) pragma(inline, true);
  --n;
  n |= n>>1;
  n |= n>>2;
  n |= n>>4;
  n |= n>>8;
  n |= n>>16;
  ++n;
  return n;
}


package(iv.follin) void sndInit (const(char)* alsaDev, uint srate) {
  snd_pcm_hw_params_t* hw_params = null;
  snd_pcm_sw_params_t* sw_params = null;
  snd_pcm_uframes_t rlbufsize;
  uint sr = srate;

  static void alsaCall (int err, string msg) @trusted {
    if (err < 0) {
      import std.string : fromStringz;
      throw new FollinException((msg~" ("~snd_strerror(err).fromStringz~")").idup);
    }
  }

  fuck_alsa_messages();

  alsaCall(snd_pcm_open(&apcm, alsaDev, SND_PCM_STREAM_PLAYBACK, 0), "cannot open audio device");
  alsaCall(snd_pcm_hw_params_malloc(&hw_params), "cannot allocate hardware parameter structure");
  alsaCall(snd_pcm_hw_params_any(apcm, hw_params), "cannot initialize hardware parameter structure");
  alsaCall(snd_pcm_hw_params_set_access(apcm, hw_params, SND_PCM_ACCESS_RW_INTERLEAVED), "cannot set access type");
  alsaCall(snd_pcm_hw_params_set_format(apcm, hw_params, SND_PCM_FORMAT_S16_NATIVE), "cannot set sample format");
  snd_pcm_hw_params_set_rate_resample(apcm, hw_params, 1); // ignore errors here
  import core.stdc.string : strncmp;
  if (strncmp(alsaDev, "plug:default", 12) == 0) {
    alsaCall(snd_pcm_hw_params_set_rate_resample(apcm, hw_params, 1), "cannot turn on resampling");
    alsaCall(snd_pcm_hw_params_set_rate(apcm, hw_params, sr, 0), "cannot set sample rate");
  } else {
    alsaCall(snd_pcm_hw_params_set_rate_near(apcm, hw_params, &sr, null), "cannot set sample rate");
  }
  alsaCall(snd_pcm_hw_params_set_channels(apcm, hw_params, 2/*numchans*/), "cannot set channel count");

  //alsaCall(snd_pcm_hw_params_set_buffer_size_near(apcm, hw_params, &rlbufsize), "cannot set buffer size");
  rlbufsize = sr/100;
  rlbufsize = (rlbufsize < 512 ? 512 : nextPowerOf2(cast(uint)rlbufsize)); // can't do less
  auto rbsp2 = cast(uint)rlbufsize;
  rlbufsize *= 2; // we want room for at least two buffers, so one is always filled
  //{ import core.stdc.stdio : fprintf, stderr; fprintf(stderr, "want: %u\n", cast(uint)rlbufsize); }
  alsaCall(snd_pcm_hw_params_set_buffer_size_near(apcm, hw_params, &rlbufsize), "cannot set buffer size");
  realSampleRate = sr;
  sndSamplesSize = rbsp2; // in frames for now
  latency = 1000*sndSamplesSize/sr;
  version(follin_init_debug) {
    import core.stdc.stdio : fprintf, stderr;
    fprintf(stderr, "Follin: real soundcard sample rate: %u; frames in buffer: %u; latency: %u; rbsp2: %u\n", sr, cast(uint)rlbufsize, cast(uint)latency, rbsp2);
  }
  alsaCall(snd_pcm_hw_params(apcm, hw_params), "cannot set parameters");
  snd_pcm_hw_params_free(hw_params);

  realBufSize = cast(uint)rlbufsize;

  alsaCall(snd_pcm_sw_params_malloc(&sw_params), "cannot allocate software parameters structure");
  alsaCall(snd_pcm_sw_params_current(apcm, sw_params), "cannot initialize software parameters structure");
  alsaCall(snd_pcm_sw_params_set_avail_min(apcm, sw_params, rbsp2/*rlbufsize*/), "cannot set minimum available count");
  alsaCall(snd_pcm_sw_params_set_start_threshold(apcm, sw_params, rbsp2), "cannot set start mode");
  alsaCall(snd_pcm_sw_params(apcm, sw_params), "cannot set software parameters");
  alsaCall(snd_pcm_nonblock(apcm, 0), "cannot set blocking mode");
  //alsaCall(snd_pcm_nonblock(apcm, 1), "cannot set non-blocking mode");

  {
    import core.stdc.stdlib : realloc;
    sndsilence = cast(short*)realloc(sndsilence, sndSamplesSize*2*short.sizeof);
    if (sndsilence is null) throw new FollinException("out of memory"); // `new` when `malloc` failed, nice
    //sndsilence.length = sndSamplesSize*2; // frames->samples
    sndsilence[0..sndSamplesSize*2] = 0;
  }
}


// return `true` if good sample buffer was consumed
package(iv.follin) bool sndWriteBuffer (ref bool playbackStarted) {
  version(follin_threads_debug) { import core.stdc.stdio; printf("playing %u buffer\n", atomicLoad(sndbufToPlay)); }
  // now start playback, if it's necessary
  if (!playbackStarted) {
    if (snd_pcm_prepare(apcm) != 0) return false; // alas
    if (snd_pcm_start(apcm) != 0) return false; // alas
    playbackStarted = true;
  }
  // wait and write
  waitnwrite: for (;;) {
    auto avail = snd_pcm_avail/*_update*/(apcm); // "_update" for mmaped i/o
    if (avail < 0) {
      import core.stdc.errno : EPIPE;
      import core.stdc.stdio;
      if (avail != -EPIPE) {
        fprintf(stderr, "ALSA ERROR: %s\n", snd_strerror(cast(int)avail));
      }
      snd_pcm_recover(apcm, cast(int)avail, 1);
      //playbackStarted = false; //FIXME
      //return false;
      goto waitnwrite;
    }
    // now wait or write
    auto used = realBufSize-avail;
    if (used <= sndSamplesSize/2) {
      // have room to write
      bool res = true;
      version(follin_write_debug) { import core.stdc.stdio; printf("avail: %u; used: %u; under: %u\n", cast(uint)avail, cast(uint)used, cast(uint)(sndSamplesSize/2-used)); }
      version(follin_radio_silence_debug) { import core.stdc.stdio; if (sndSamplesSize-(sndSamplesSize/2-used) < 256) printf("radio silence: too much input buffer drained: %u\n", cast(uint)(sndSamplesSize/2-used)); }
      auto paused = atomicLoad(sndPaused);
      auto b2p = atomicLoad(sndbufToPlay);
      auto bpos = (!paused ? sndbufptr[b2p] : sndsilence);
      if (atomicLoad(sndbufToFill) == b2p && atomicLoad(sndbufFillingNow)) {
        // radio silence
        //bpos = sndsilence.ptr;
        res = false;
        version(follin_radio_silence_debug) { import core.stdc.stdio; printf("radio silence!\n"); }
      }
      if (paused) res = false;
      snd_pcm_sframes_t err;
      snd_pcm_sframes_t fleft = sndSamplesSize/2/*numchans*/;
      while (fleft > 0) {
        err = snd_pcm_writei(apcm, bpos, fleft);
        if (err < 0) {
          import core.stdc.stdio : fprintf, stderr;
          import core.stdc.errno : EPIPE;
          if (err == -EPIPE) {
            fprintf(stderr, "ALSA: underrun!\n");
          } else if (err == -11) {
            // we can't write, that's wrong
            fprintf(stderr, "ALSA: write failed (%s)\n", snd_strerror(cast(int)err));
          } else {
            fprintf(stderr, "ALSA: write failed %d (%s)\n", cast(int)err, snd_strerror(cast(int)err));
          }
          snd_pcm_recover(apcm, cast(int)err, 1);
          fleft = sndSamplesSize/2/*numchans*/;
          bpos = sndsilence; // write silence instead
          res = false;
          continue waitnwrite;
        }
        //version(follin_write_debug) { import core.stdc.stdio; printf("Follin: written %u of %u frames\n", cast(uint)err, cast(uint)fleft); }
        bpos += cast(uint)(err*2/*numchans*/);
        fleft -= err;
      }
      return res;
    } else {
      // no room, wait
      uint over = used-sndSamplesSize/2;
      uint mcswait = 1000_0*over/441;
      version(follin_write_debug) { import core.stdc.stdio; printf("avail: %u; need: %u; used: %u; over: %u; mcswait=%u\n", cast(uint)avail, cast(uint)sndSamplesSize, cast(uint)used, over, mcswait); }
      if (mcswait >= 100) {
        // one second is 1_000_000_000 nanoseconds or 1_000_000 microseconds or 1_000 milliseconds
        import core.sys.posix.signal : timespec;
        import core.sys.posix.time : nanosleep;
        timespec ts = void;
        ts.tv_sec = 0;
        ts.tv_nsec = (mcswait-1)*1000; // micro to nano
        nanosleep(&ts, null); // idc how much time was passed
      }
    }
  }
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
// alsa bindings
import core.stdc.config;
extern(C) nothrow @trusted @nogc:
package(iv.follin):

// alsa bindings (bare minimum)
pragma(lib, "asound");

struct snd_pcm_t {}
struct snd_pcm_hw_params_t {}
struct snd_pcm_sw_params_t {}
struct snd_async_handler_t {}
alias snd_async_callback_t = void function (snd_async_handler_t* handler);

alias snd_pcm_stream_t = int;
alias snd_pcm_access_t = int;
alias snd_pcm_format = int;

alias snd_pcm_uframes_t = c_ulong;
alias snd_pcm_sframes_t = c_long;

enum SND_PCM_STREAM_PLAYBACK = 0;
enum SND_PCM_ACCESS_MMAP_INTERLEAVED = 0;
enum SND_PCM_ACCESS_RW_INTERLEAVED = 3;

enum SND_PCM_FORMAT_S16_LE = 2;
enum SND_PCM_FORMAT_S16_BE = 3;
enum SND_PCM_FORMAT_FLOAT_LE = 14;
enum SND_PCM_FORMAT_FLOAT_BE = 15;

version(LittleEndian) {
  enum SND_PCM_FORMAT_S16_NATIVE = SND_PCM_FORMAT_S16_LE;
  enum SND_PCM_FORMAT_FLOAT_NATIVE = SND_PCM_FORMAT_FLOAT_LE;
} else {
  enum SND_PCM_FORMAT_S16_NATIVE = SND_PCM_FORMAT_S16_BE;
  enum SND_PCM_FORMAT_FLOAT_NATIVE = SND_PCM_FORMAT_FLOAT_BE;
}


const(char)* snd_strerror (int errnum);

int snd_pcm_open (snd_pcm_t** pcm, const(char)* name, snd_pcm_stream_t stream, int mode);
int snd_pcm_close (snd_pcm_t* pcm);
int snd_pcm_prepare (snd_pcm_t* pcm);
int snd_pcm_drop (snd_pcm_t* pcm);
int snd_pcm_drain (snd_pcm_t* pcm);
int snd_pcm_recover (snd_pcm_t* pcm, int err, int silent);
int snd_pcm_nonblock (snd_pcm_t* pcm, int nonblock);
int snd_pcm_abort (snd_pcm_t* pcm) { return snd_pcm_nonblock(pcm, 2); }
int snd_pcm_start (snd_pcm_t* pcm);
int snd_pcm_pause (snd_pcm_t* pcm, int enable);

int snd_async_add_pcm_handler (snd_async_handler_t** handler, snd_pcm_t* pcm, snd_async_callback_t callback, void* private_data);
snd_pcm_t* snd_async_handler_get_pcm (snd_async_handler_t* handler);
int snd_async_del_handler (snd_async_handler_t* handler);

int snd_pcm_wait (snd_pcm_t* pcm, int timeout);
int snd_pcm_avail_delay (snd_pcm_t* pcm, snd_pcm_sframes_t* availp, snd_pcm_sframes_t* delayp);
snd_pcm_sframes_t snd_pcm_avail (snd_pcm_t* pcm);
snd_pcm_sframes_t snd_pcm_avail_update (snd_pcm_t* pcm);

snd_pcm_sframes_t snd_pcm_writei (snd_pcm_t* pcm, const(void)* buffer, snd_pcm_uframes_t size);
snd_pcm_sframes_t snd_pcm_writen (snd_pcm_t* pcm, void** bufs, snd_pcm_uframes_t size);

int snd_pcm_hw_params (snd_pcm_t* pcm, snd_pcm_hw_params_t* params);

int snd_pcm_hw_params_current (snd_pcm_t* pcm, snd_pcm_hw_params_t* params);
int snd_pcm_hw_params_any (snd_pcm_t* pcm, snd_pcm_hw_params_t* params);
void snd_pcm_hw_params_free (snd_pcm_hw_params_t* params);
int snd_pcm_hw_params_malloc (snd_pcm_hw_params_t** params);
int snd_pcm_hw_params_set_access (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_access_t);
int snd_pcm_hw_params_set_channels (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint chans);
int snd_pcm_hw_params_set_format (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_format);
int snd_pcm_hw_params_set_rate (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_set_rate_near (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint*, int*);
int snd_pcm_hw_params_set_rate_resample (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val);

int snd_pcm_hw_params_test_buffer_size (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t val);
int snd_pcm_hw_params_set_buffer_size (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t val);
int snd_pcm_hw_params_set_buffer_size_min (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val);
int snd_pcm_hw_params_set_buffer_size_max (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val);
int snd_pcm_hw_params_set_buffer_size_minmax (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* min, snd_pcm_uframes_t* max);
int snd_pcm_hw_params_set_buffer_size_near (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val);
int snd_pcm_hw_params_set_buffer_size_first (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val);
int snd_pcm_hw_params_set_buffer_size_last (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val);

// nanoseconds
int snd_pcm_hw_params_test_buffer_time (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_set_buffer_time (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_set_buffer_time_min (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_buffer_time_max (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_buffer_time_minmax (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* min, int* mindir, uint* max, int* maxdir);
int snd_pcm_hw_params_set_buffer_time_near (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_buffer_time_first (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_buffer_time_last (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);

int snd_pcm_hw_params_set_period_size (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t val, int dir);
int snd_pcm_hw_params_set_period_size_min (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val, int* dir);
int snd_pcm_hw_params_set_period_size_max (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val, int* dir);
int snd_pcm_hw_params_set_period_size_minmax (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* min, int* mindir, snd_pcm_uframes_t* max, int* maxdir);
int snd_pcm_hw_params_set_period_size_near (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val, int* dir);
int snd_pcm_hw_params_set_period_size_first (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val, int* dir);
int snd_pcm_hw_params_set_period_size_last (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, snd_pcm_uframes_t* val, int* dir);
int snd_pcm_hw_params_set_period_size_integer (snd_pcm_t* pcm, snd_pcm_hw_params_t* params);

// nanoseconds
int snd_pcm_hw_params_test_period_time (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_set_period_time (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint val, int dir);
int snd_pcm_hw_params_set_period_time_min (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_period_time_max (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_period_time_minmax (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* min, int* mindir, uint* max, int* maxdir);
int snd_pcm_hw_params_set_period_time_near (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_period_time_first (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);
int snd_pcm_hw_params_set_period_time_last (snd_pcm_t* pcm, snd_pcm_hw_params_t* params, uint* val, int* dir);

int snd_pcm_sw_params (snd_pcm_t* pcm, snd_pcm_sw_params_t* params);
int snd_pcm_sw_params_current (snd_pcm_t* pcm, snd_pcm_sw_params_t* params);
void snd_pcm_sw_params_free (snd_pcm_sw_params_t* params);
int snd_pcm_sw_params_malloc (snd_pcm_sw_params_t** params);
int snd_pcm_sw_params_set_avail_min (snd_pcm_t* pcm, snd_pcm_sw_params_t* params, snd_pcm_uframes_t val);
int snd_pcm_sw_params_set_start_threshold (snd_pcm_t* pcm, snd_pcm_sw_params_t* params, snd_pcm_uframes_t val);

alias snd_lib_error_handler_t = void function (const(char)* file, int line, const(char)* function_, int err, const(char)* fmt, ...);
int snd_lib_error_set_handler (snd_lib_error_handler_t handler);

private void alsa_message_fucker (const(char)* file, int line, const(char)* function_, int err, const(char)* fmt, ...) {}

private void fuck_alsa_messages () {
  snd_lib_error_set_handler(&alsa_message_fucker);
}
