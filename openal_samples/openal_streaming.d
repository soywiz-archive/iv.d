// sample OpenAL streaming player
// based on the code by David Gow <david@ingeniumdigital.com>
// WTFPL
module openal_streaming is aliced;

import std.getopt;

import iv.audiostream;
import iv.openal;
import iv.pxclock;
import iv.vfs.io;


enum BufferSizeBytes = 960*2*2;

// the number of buffers we'll be rotating through
// ideally, all but one will be full
enum BufferCount = 3;


struct PlayTime {
  string warning;
  ulong warnStartFrm;
  uint warnDurMsecs;
  ulong framesDone; // with buffer precision

  bool warnWasPainted;
  bool newWarning;

  void warn (string w, uint durms=1500) {
    if (w.length > 0) {
      warning = w;
      warnStartFrm = framesDone;
      warnDurMsecs = durms;
      newWarning = true;
    }
  }
}


// returns number of *samples* (not frames!) queued, -1 on error, 0 on EOF
int fillBuffer (ref AudioStream ass, ALuint buffer) {
  // let's have a buffer that is two opus frames long (and two channels)
  short[BufferSizeBytes] buf = void; // no need to initialize it

  immutable int numChannels = ass.channels;

  // we only support stereo and mono
  if (numChannels < 1 || numChannels > 2) {
    stderr.writeln("File contained more channels than we support (", numChannels, ").");
    return -1;
  }

  int samplesRead = 0;
  // keep reading samples until we have them all
  while (samplesRead < BufferSizeBytes) {
    int ns = ass.readFrames(buf.ptr+samplesRead, (BufferSizeBytes-samplesRead)/numChannels);
    if (ns < 0) { stderr.writeln("ERROR reading audio file!"); return -1; }
    if (ns == 0) break;
    samplesRead += ns*numChannels;
  }

  if (samplesRead > 0) {
    ALenum format;
    // try to use OpenAL Soft extension first
    static if (AL_SOFT_buffer_samples) {
      ALenum chantype;
      static bssChecked = -1;
      if (bssChecked < 0) {
        if (alIsExtensionPresent("AL_SOFT_buffer_samples")) {
          if (alGetProcAddress("alIsBufferFormatSupportedSOFT") !is null &&
              alGetProcAddress("alBufferSamplesSOFT") !is null) bssChecked = 1; else bssChecked = 0;
          //writeln("bssChecked=", bssChecked);
        } else {
          bssChecked = 0;
        }
        if (!bssChecked) writeln("OpenAL: no 'AL_SOFT_buffer_samples'");
      }
      if (bssChecked > 0) {
        static bool warningDisplayed = false;
        final switch (numChannels) {
          case 1: format = AL_MONO16_SOFT; chantype = AL_MONO_SOFT; break;
          case 2: format = AL_STEREO16_SOFT; chantype = AL_STEREO_SOFT; break;
        }
        if (alIsBufferFormatSupportedSOFT(format)) {
          alBufferSamplesSOFT(buffer, ass.rate, format, samplesRead/numChannels, chantype, AL_SHORT_SOFT, buf.ptr);
          return true;
        }
        if (!warningDisplayed) { warningDisplayed = true; stderr.writeln("fallback!"); }
      }
    }
    // use normal OpenAL method
    final switch (numChannels) {
      case 1: format = AL_FORMAT_MONO16; break;
      case 2: format = AL_FORMAT_STEREO16; break;
    }
    alBufferData(buffer, format, buf.ptr, samplesRead*2, ass.rate);
  }

  return samplesRead;
}


bool updateStream (ref AudioStream ass, ALuint source, ref PlayTime ptime) {
  //bool someBufsAdded = false;
  ALuint currentbuffer;

  // how many buffers do we need to fill?
  int numProcessedBuffers = 0;
  alGetSourcei(source, AL_BUFFERS_PROCESSED, &numProcessedBuffers);

  if (numProcessedBuffers > 0) {
    // unqueue a finished buffer, fill it with new data, and re-add it to the end of the queue
    while (numProcessedBuffers--) {
      alSourceUnqueueBuffers(source, 1, &currentbuffer);
      // add number of played samples to playtime
      ALint bufsz;
      alGetBufferi(currentbuffer, AL_SIZE, &bufsz);
      ptime.framesDone += bufsz/2/ass.channels;
      //writeln("buffer size: ", bufsz);
      if (ass.fillBuffer(currentbuffer) <= 0) return false;
      //someBufsAdded = true;
      alSourceQueueBuffers(source, 1, &currentbuffer);
    }
  }

  return true;
}


// AudioStream is required to get sampling rate and number of channels
uint getPositionMSec (ref AudioStream ass, ALuint source, in ref PlayTime ptime) {
  ulong frames = ptime.framesDone;
  int offset;
  alGetSourcei(source, AL_SAMPLE_OFFSET, &offset); // in the current buffer
  if (alGetError() == AL_NO_ERROR) {
    // add processed buffers (assume that all buffers are of the same size)
    int numProcessedBuffers = 0;
    alGetSourcei(source, AL_BUFFERS_PROCESSED, &numProcessedBuffers);
    if (alGetError() == AL_NO_ERROR) {
      frames += numProcessedBuffers*(BufferSizeBytes/2/ass.channels);
      frames += offset/ass.channels;
    } else {
      //assert(0);
    }
  } else {
    //assert(0);
  }
  return cast(uint)(frames*1000/ass.rate);
}


// load an ogg opus file into the given AL buffer
void streamAudioFile (ALuint source, string filename) {
  PlayTime ptime;

  // open the file
  writeln("opening '", filename, "'...");
  auto ass = AudioStream.detect(VFile(filename));
  scope(exit) ass.close();

  // get the number of channels in the current link
  immutable int numChannels = ass.channels;
  // get the number of samples (per channel) in the current link
  immutable long frameCount = ass.framesTotal;

  uint nextProgressTime = 0;
  int procBufs = -1;


  void showTime () {
    /*
    static if (AL_SOFT_source_latency) {
      if (alIsExtensionPresent("AL_SOFT_source_latency")) {
        ALint64SOFT[2] smpvals;
        ALdouble[2] timevals;
        alGetSourcei64vSOFT(source, AL_SAMPLE_OFFSET_LATENCY_SOFT, smpvals.ptr);
        alGetSourcedvSOFT(source, AL_SEC_OFFSET_LATENCY_SOFT, timevals.ptr);
        writeln("sample: ", smpvals[0]>>32, "; latency (ns): ", smpvals[1], "; seconds=", timevals[0], "; latency (msecs)=", timevals[1]*1000);
      }
    }
    */
    version(none) {
      ALdouble blen;
      alGetSourcedSOFT(source, AL_SEC_LENGTH_SOFT, &blen);
      writeln("slen: ", blen);
    }

    // process warnings
    if (ptime.newWarning && ptime.warning.length == 0) ptime.newWarning = false;

    if (ptime.newWarning) {
      import std.string : toStringz;
      import core.stdc.stdio : stdout, fprintf;
      if (ptime.warnWasPainted) stdout.fprintf("\e[A");
      stdout.fprintf("\r%s\e[K\n", ptime.warning.toStringz);
      ptime.warnWasPainted = true;
      ptime.newWarning = false;
      nextProgressTime = 0; // redraw time
    }

    uint time = cast(uint)(ptime.framesDone*1000/ass.rate);
    uint total = cast(uint)(frameCount*1000/ass.rate);
    uint xtime = getPositionMSec(ass, source, ptime);

    if (ptime.warning.length > 0 && ptime.warnWasPainted) {
      import core.stdc.stdio : stdout, fprintf;
      uint etime = cast(uint)(ptime.warnStartFrm*1000/ass.rate)+ptime.warnDurMsecs;
      if (etime <= time) {
        stdout.fprintf("\e\r[A\e[K\n");
        ptime.warning = null;
        nextProgressTime = 0; // redraw time
      }
    }

    if (time >= nextProgressTime) {
      import core.stdc.stdio : stdout, fprintf, fflush;
      if (procBufs >= 0) {
        stdout.fprintf("\r%2u:%02u / %u:%02u  (%u of %u) (%u : %u)\e[K", time/60/1000, time%60000/1000, total/60/1000, total%60000/1000, cast(uint)procBufs, BufferCount, time, xtime);
      } else {
        stdout.fprintf("\r%2u:%02u / %u:%02u  (%u : %u)\e[K", time/60/1000, time%60000/1000, total/60/1000, total%60000/1000, time, xtime);
      }
      stdout.fflush();
      nextProgressTime = time+500;
    }
  }

  void doneTime () {
    nextProgressTime = 0;
    showTime();
    import core.stdc.stdio : stdout, fprintf, fflush;
    stdout.fprintf("\n");
    stdout.fflush();
  }


  writeln(filename, ": ", numChannels, " channels, ", frameCount, " frames (", ass.timeTotal/1000, " seconds)");

  ALuint[BufferCount] buffers; // no need to initialize it, but why not?

  alGenBuffers(BufferCount, buffers.ptr);

  foreach (ref buf; buffers) ass.fillBuffer(buf); //TODO: check for errors here too

  alSourceQueueBuffers(source, BufferCount, buffers.ptr);

  ulong stt = clockMicro();

  alSourcePlay(source);
  if (alGetError() != AL_NO_ERROR) throw new Exception("Could not play source!");

  showTime();
  pumploop: for (;;) {
    import core.sys.posix.unistd : usleep;
    //usleep(sleepTimeNS);
    showTime();
    // sleep until at least one buffer is empty
    ulong ett = stt+(ass.rate*1000/(BufferSizeBytes/2/numChannels));
    ulong ctt = clockMicro();
    //writeln("  ", ctt, " ", ett, " " , ett-ctt);
    if (ctt < ett && ett-ctt > 100) usleep(cast(uint)(ett-ctt)-100);
    // statistics
    alGetSourcei(source, AL_BUFFERS_PROCESSED, &procBufs);
    // refill buffers
    if (!ass.updateStream(source, ptime)) break pumploop;
    stt = clockMicro();
    // source can stop playing on buffer underflow
    version(all) {
      ALenum sourceState;
      alGetSourcei(source, AL_SOURCE_STATE, &sourceState);
      if (sourceState != AL_PLAYING && sourceState != AL_PAUSED) {
        version(none) {
          int numProcessedBuffers = 0;
          alGetSourcei(source, AL_BUFFERS_PROCESSED, &numProcessedBuffers);
          writeln("  npb=", numProcessedBuffers, " of ", BufferCount);
        }
        ptime.warn("Source not playing!", 600);
        alSourcePlay(source);
      }
    }
  }
  // actually, "waiting" should go into time display too
  doneTime();

  // wait for source to finish playing
  writeln("waiting source to finish playing...");
  for (;;) {
    ALenum sourceState;
    alGetSourcei(source, AL_SOURCE_STATE, &sourceState);
    if (sourceState != AL_PLAYING) break;
  }

  alSourceUnqueueBuffers(source, BufferCount, buffers.ptr);

  // we have to delete the source here, as OpenAL soft seems to need the source gone before the buffers
  // perhaps this is just timing
  alDeleteSources(1, &source);
  alDeleteBuffers(BufferCount, buffers.ptr);
}


void main (string[] args) {
  import std.string : fromStringz;

  ALuint testSource;
  ALfloat listenerGain = 1.0f;
  bool limiting = true;

  ALCdevice* dev;
  ALCcontext* ctx;

  auto gof = getopt(args,
    std.getopt.config.caseSensitive,
    std.getopt.config.bundling,
    "gain|g", &listenerGain,
    "limit|l", &limiting,
  );

  if (args.length <= 1) throw new Exception("filename?!");

  writeln("OpenAL device extensions: ", alcGetString(null, ALC_EXTENSIONS).fromStringz);

  if (alcIsExtensionPresent(null, "ALC_ENUMERATE_ALL_EXT")) {
    auto hwdevlist = alcGetString(null, ALC_ALL_DEVICES_SPECIFIER);
    writeln("OpenAL hw devices:");
    while (*hwdevlist) {
      writeln("  ", hwdevlist.fromStringz);
      while (*hwdevlist) ++hwdevlist;
      ++hwdevlist;
    }
  }

  if (alcIsExtensionPresent(null, "ALC_ENUMERATION_EXT")) {
    auto devlist = alcGetString(null, ALC_DEVICE_SPECIFIER);
    writeln("OpenAL renderers:");
    while (*devlist) {
      writeln("  ", devlist.fromStringz);
      while (*devlist) ++devlist;
      ++devlist;
    }
  }

  writeln("OpenAL default renderer: ", alcGetString(null, ALC_DEFAULT_DEVICE_SPECIFIER).fromStringz);

  // open the default device
  dev = alcOpenDevice(null);
  if (dev is null) throw new Exception("couldn't open OpenAL device");
  scope(exit) alcCloseDevice(dev);

  writeln("OpenAL renderer: ", alcGetString(dev, ALC_DEVICE_SPECIFIER).fromStringz);
  writeln("OpenAL hw device: ", alcGetString(dev, ALC_ALL_DEVICES_SPECIFIER).fromStringz);

  // we want an OpenAL context
  {
    immutable ALCint[$] attrs = [
      ALC_STEREO_SOURCES, 1, // get at least one stereo source for music
      ALC_MONO_SOURCES, 1, // this should be audio channels in our game engine
      //ALC_FREQUENCY, 48000, // desired frequency; we don't really need this, let OpenAL choose the best
      0,
    ];
    ctx = alcCreateContext(dev, attrs.ptr);
  }
  if (ctx is null) throw new Exception("couldn't create OpenAL context");
  scope(exit) {
    // just to show you how it's done
    if (alcIsExtensionPresent(null, "ALC_EXT_thread_local_context")) alcSetThreadContext(null); else alcMakeContextCurrent(null);
    alcDestroyContext(ctx);
  }

  if (!limiting && alcGetProcAddress(dev, "alcResetDeviceSOFT") !is null) {
    immutable ALCint[$] attrs = [
      ALC_OUTPUT_LIMITER_SOFT, ALC_FALSE,
      0,
    ];
    if (!alcResetDeviceSOFT(dev, attrs.ptr)) stderr.writeln("WARNING: can't turn off OpenAL limiter");
  }

  // just to show you how it's done; see https://github.com/openalext/openalext/blob/master/ALC_EXT_thread_local_context.txt
  if (alcIsExtensionPresent(null, "ALC_EXT_thread_local_context")) alcSetThreadContext(ctx); else alcMakeContextCurrent(ctx);
  //alcMakeContextCurrent(ctx);

  writeln("OpenAL vendor: ", alGetString(AL_VENDOR).fromStringz);
  writeln("OpenAL version: ", alGetString(AL_VERSION).fromStringz);
  writeln("OpenAL renderer: ", alGetString(AL_RENDERER).fromStringz);
  writeln("OpenAL extensions: ", alGetString(AL_EXTENSIONS).fromStringz);

  // get us a buffer and a source to attach it to
  writeln("creating OpenAL source...");
  alGenSources(1, &testSource);

  // this turns off OpenAL spatial processing for the source,
  // thus directly mapping stereo sound to the corresponding channels;
  // but this works only for stereo samples, and we'd better do that
  // after checking number of channels in input stream
  static if (AL_SOFT_direct_channels) {
    if (alIsExtensionPresent("AL_SOFT_direct_channels")) {
      writeln("OpenAL: direct channels extension detected");
      alSourcei(testSource, AL_DIRECT_CHANNELS_SOFT, AL_TRUE);
      if (alGetError() != AL_NO_ERROR) stderr.writeln("WARNING: can't turn on direct channels");
    }
  }

  writeln("setting OpenAL listener...");
  // set position and gain for the listener
  alListener3f(AL_POSITION, 0.0f, 0.0f, 0.0f);
  //alListenerf(AL_GAIN, 1.0f);
  // as listener gain is applied after source gain, and it not limited to 1.0, it is possible to do the following
  writeln("listener gain: ", listenerGain);
  alListenerf(AL_GAIN, listenerGain);

  // ...and set source properties
  writeln("setting OpenAL source properties...");
  alSource3f(testSource, AL_POSITION, 0.0f, 0.0f, 0.0f);

  {
    //ALfloat maxGain;
    //alGetSourcef(testSource, AL_MAX_GAIN, &maxGain);
    //writeln("max gain: ", maxGain);
  }
  if (alIsExtensionPresent("AL_SOFT_gain_clamp_ex")) {
    ALfloat gainLimit = 0.0f;
    alGetFloatv(AL_GAIN_LIMIT_SOFT, &gainLimit);
    writeln("gain limit: ", gainLimit);
  }

  alSourcef(testSource, AL_GAIN, 1.0f);
  // MAX_GAIN is *user* limit, not library/hw; so you can do the following
  // but somehow it doesn't work right on my system (or i misunderstood it's use case)
  // it seems to slowly fall back to 1.0, and distort both volume and (sometimes) pitch
  version(none) {
    alSourcef(testSource, AL_MAX_GAIN, 2.0f);
    alSourcef(testSource, AL_GAIN, 2.0f);
  }

  if (alGetError() != AL_NO_ERROR) throw new Exception("error initializing OpenAL");

  writeln("streaming...");
  streamAudioFile(testSource, args[1]);
}
