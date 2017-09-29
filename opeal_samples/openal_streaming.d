// sample OpenAL streaming player
// based on the code by David Gow <david@ingeniumdigital.com>
// WTFPL
module openal_streaming;

import std.getopt;

import iv.audiostream;
import iv.openal;
import iv.vfs.io;


enum BufferSizeBytes = 960*2*2;

struct PlayTime {
  ulong framesDone;
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
    if (ns == 0) { writeln("done reading audio data."); break; }
    samplesRead += ns*numChannels;
  }

  if (samplesRead > 0) {
    ALenum format, chantype;
    // try to use OpenAL Soft extension first
    static if (AL_SOFT_buffer_samples) {
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
  bool someBufsAdded = false;
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
      someBufsAdded = true;
      alSourceQueueBuffers(source, 1, &currentbuffer);
    }
  }

  // source can stop playing on buffer underflow
  if (someBufsAdded) {
    ALenum sourceState;
    alGetSourcei(source, AL_SOURCE_STATE, &sourceState);
    if (sourceState != AL_PLAYING) {
      stderr.writeln("Source not playing!");
      alSourcePlay(source);
    }
  }

  return true;
}


// load an ogg opus file into the given AL buffer
void streamAudioFile (ALuint source, string filename) {
  PlayTime ptime;

  // open the file
  writeln("opening '", filename, "'...");
  auto ass = AudioStream.detect(VFile(filename));
  scope(exit) ass.close();

  uint nextProgressTime = 0;
  enum sleepTimeNS = 1000*1000*960/48000/10;

  void showTime () {
    /*
    static if (AL_SOFT_source_latency) {
      ALint64SOFT[2] smpvals;
      ALdouble[2] timevals;
      alGetSourcei64vSOFT(source, AL_SAMPLE_OFFSET_LATENCY_SOFT, smpvals.ptr);
      alGetSourcedvSOFT(source, AL_SEC_OFFSET_LATENCY_SOFT, timevals.ptr);
      writeln("sample: ", smpvals[0]>>32, "; latency (ns): ", smpvals[1], "; seconds=", timevals[0], "; latency (msecs)=", timevals[1]*1000);
    }
    */
    version(none) {
      ALdouble blen;
      alGetSourcedSOFT(source, AL_SEC_LENGTH_SOFT, &blen);
      writeln("slen: ", blen);
    }
    uint time = cast(uint)(ptime.framesDone*1000/ass.rate);
    uint total = cast(uint)(ass.framesTotal*1000/ass.rate);
    if (time >= nextProgressTime) {
      import core.stdc.stdio : stdout, fprintf, fflush;
      stdout.fprintf("\r%2u:%02u / %u:%02u", time/60/1000, time%60000/1000, total/60/1000, total%60000/1000);
      stdout.fflush();
      nextProgressTime = time+500;
    }
  }

  void doneTime () {
    nextProgressTime = 0;
    showTime();
    import core.stdc.stdio : stdout, fprintf, fflush;
    stdout.fprintf("\n");
  }


  // get the number of channels in the current link
  int numChannels = ass.channels;
  // get the number of samples (per channel) in the current link
  long pcmSize = ass.framesTotal;

  writeln(filename, ": ", numChannels, " channels, ", pcmSize, " frames (", ass.timeTotal/1000, " seconds)");

  // the number of buffers we'll be rotating through
  // ideally, all bar one will be full
  enum numBuffers = 2;

  ALuint[numBuffers] buffers; // no need to initialize it, but why not?

  alGenBuffers(numBuffers, buffers.ptr);

  foreach (ref buf; buffers) ass.fillBuffer(buf); //TODO: check for errors here too

  alSourceQueueBuffers(source, numBuffers, buffers.ptr);

  alSourcePlay(source);
  if (alGetError() != AL_NO_ERROR) throw new Exception("Could not play source!");

  showTime();
  while (ass.updateStream(source, ptime)) {
    // this reduces CPU use (obviously)
    // it's important not to sleep for too long, though
    // sleep() and friends give a _minimum_ time to be kept asleep
    import core.sys.posix.unistd : usleep;
    usleep(sleepTimeNS);
    showTime();
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

  alSourceUnqueueBuffers(source, numBuffers, buffers.ptr);

  // we have to delete the source here, as OpenAL soft seems to need the source gone before the buffers
  // perhaps this is just timing
  alDeleteSources(1, &source);
  alDeleteBuffers(numBuffers, buffers.ptr);
}


void main (string[] args) {
  import std.string : fromStringz;

  ALuint testSource;
  ALfloat maxGain;
  ALfloat listenerGain = 1.0f;

  ALCdevice* dev;
  ALCcontext* ctx;

  auto gof = getopt(args,
    std.getopt.config.caseSensitive,
    std.getopt.config.bundling,
    "gain|g", &listenerGain,
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
  ctx = alcCreateContext(dev, null);
  if (ctx is null) throw new Exception("couldn't create OpenAL context");
  scope(exit) {
    // just to show you how it's done
    if (alcIsExtensionPresent(null, "ALC_EXT_thread_local_context")) alcSetThreadContext(null); else alcMakeContextCurrent(null);
    alcDestroyContext(ctx);
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
  static if (AL_SOFT_direct_channels) alSourcei(testSource, AL_DIRECT_CHANNELS_SOFT, AL_TRUE);

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

  //alGetSourcef(testSource, AL_MAX_GAIN, &maxGain);
  //writeln("max gain: ", maxGain);
  alSourcef(testSource, AL_GAIN, 1.0f);
  // MAX_GAIN is *user* limit, not library/hw; so you can do the following
  // but somehow it doesn't work right on my system (or i misunderstood it's use case)
  // it seems to slowly fall back to 1.0, and distort both volume and (sometimes) pitch
  version(none) {
    alSourcef(testSource, AL_MAX_GAIN, 2.0f);
    alSourcef(testSource, AL_GAIN, 2.0f);
  }

  writeln("streaming...");
  streamAudioFile(testSource, args[1]);
}
