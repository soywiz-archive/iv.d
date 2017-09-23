// sample OpenAL streaming player
// based on the code by David Gow <david@ingeniumdigital.com>
// WTFPL
module openal_streaming;

import std.getopt;

import iv.audiostream;
import iv.openal;
import iv.vfs.io;


bool fillBuffer (ref AudioStream ass, ALuint buffer) {
  // let's have a buffer that is two opus frames long (and two channels)
  enum bufferSize = 960*2*2;
  short[bufferSize] buf = void; // no need to initialize it

  immutable int numChannels = ass.channels;

  // we only support stereo and mono, set the openAL format based on channels
  // opus always uses signed 16-bit integers, unless the _float functions are called
  ALenum format;
  switch (numChannels) {
    case 1: format = AL_FORMAT_MONO16; break;
    case 2: format = AL_FORMAT_STEREO16; break;
    default:
      stderr.writeln("File contained more channels than we support (", numChannels, ").");
      return false;
  }

  int samplesRead = 0;
  // keep reading samples until we have them all
  while (samplesRead < bufferSize) {
    int ns = ass.readFrames(buf.ptr+samplesRead, (bufferSize-samplesRead)/numChannels);
    if (ns < 0) { stderr.writeln("ERROR reading audio file!"); return false; }
    if (ns == 0) break;
    samplesRead += ns*numChannels;
  }

  alBufferData(buffer, format, buf.ptr, samplesRead*2, ass.rate);

  return true;
}


bool updateStream (ref AudioStream ass, ALuint source) {
  ALuint currentbuffer;

  // how many buffers do we need to fill?
  int numProcessedBuffers = 0;
  alGetSourcei(source, AL_BUFFERS_PROCESSED, &numProcessedBuffers);

  // source can stop playing on buffer underflow
  ALenum sourceState;
  alGetSourcei(source, AL_SOURCE_STATE, &sourceState);
  if (sourceState != AL_PLAYING) {
    writeln("Source not playing!");
    alSourcePlay(source);
  }

  // unqueue a finished buffer, fill it with new data, and re-add it to the end of the queue
  while (numProcessedBuffers--) {
    alSourceUnqueueBuffers(source, 1, &currentbuffer);
    if (!ass.fillBuffer(currentbuffer)) return false;
    alSourceQueueBuffers(source, 1, &currentbuffer);
  }

  return true;
}


// load an ogg opus file into the given AL buffer
void streamAudioFile (ALuint source, string filename) {
  // open the file
  writeln("opening '", filename, "'...");
  auto ass = AudioStream.detect(VFile(filename));
  scope(exit) ass.close();

  // get the number of channels in the current link
  int numChannels = ass.channels;
  // get the number of samples (per channel) in the current link
  long pcmSize = ass.framesTotal;

  writeln(filename, ": ", numChannels, " channels, ", pcmSize, " samples (", ass.timeTotal/1000, " seconds)");

  // the number of buffers we'll be rotating through
  // ideally, all bar one will be full
  enum numBuffers = 2;

  ALuint[numBuffers] buffers; // no need to initialize it, but why not?

  alGenBuffers(numBuffers, buffers.ptr);

  foreach (ref buf; buffers) ass.fillBuffer(buf); // check for errors here too

  alSourceQueueBuffers(source, numBuffers, buffers.ptr);

  alSourcePlay(source);
  if (alGetError() != AL_NO_ERROR) throw new Exception("Could not play source!");

  while (ass.updateStream(source)) {
    // this reduces CPU use (obviously)
    // it's important not to sleep for too long, though
    // sleep() and friends give a _minimum_ time to be kept asleep
    import core.sys.posix.unistd : usleep;
    usleep(1000*1000*960/48000/10);
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

  version(all) {
    auto devlist = alcGetString(null, ALC_ALL_DEVICES_SPECIFIER);
    writeln("OpenAL hw devices:");
    while (*devlist) {
      writeln("  ", devlist.fromStringz);
      while (*devlist) ++devlist;
      ++devlist;
    }
  }

  // open the default device
  dev = alcOpenDevice(null);
  if (dev is null) throw new Exception("couldn't open OpenAL device");
  scope(exit) alcCloseDevice(dev);

  writeln("OpenAL default renderer: ", alcGetString(dev, ALC_DEFAULT_DEVICE_SPECIFIER).fromStringz);
  writeln("OpenAL renderer: ", alcGetString(dev, ALC_DEVICE_SPECIFIER).fromStringz);
  writeln("OpenAL hw device: ", alcGetString(dev, ALC_ALL_DEVICES_SPECIFIER).fromStringz);

  // we want an OpenAL context
  ctx = alcCreateContext(dev, null);
  if (ctx is null) throw new Exception("couldn't create OpenAL context");
  scope(exit) { /*alcSetThreadContext(null);*/ alcMakeContextCurrent(null); alcDestroyContext(ctx); }

  alcMakeContextCurrent(ctx);
  //alcSetThreadContext(ctx); //k8: doesn't work without this on my box (why?) -- this prolly was faulty OpenAL build

  writeln("OpenAL vendor: ", alGetString(AL_VENDOR).fromStringz);
  writeln("OpenAL version: ", alGetString(AL_VERSION).fromStringz);
  writeln("OpenAL renderer: ", alGetString(AL_RENDERER).fromStringz);
  writeln("OpenAL extensions: ", alGetString(AL_EXTENSIONS).fromStringz);

  // get us a buffer and a source to attach it to
  writeln("creating OpenAL source...");
  alGenSources(1, &testSource);

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
