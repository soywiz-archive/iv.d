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
module iv.follin.engine;

//version = follin_prefer_alsa_plug;
//version = follin_threads_debug;
//version = follin_wait_debug;

import iv.follin.exception;


// ////////////////////////////////////////////////////////////////////////// //
// be evil!
/*
import core.sys.posix.signal : siginfo_t, sigaction_t;
private extern(C) void handleSignalZZ (int signum, siginfo_t* info, void* contextPtr) nothrow {
  import core.stdc.stdio : fprintf, stderr;
  import core.stdc.stdlib : abort;
  fprintf(stderr, "\bFUUUUUUU....\n");
  abort();
}
private __gshared sigaction_t old_sigaction;

shared static this () {
  //import etc.linux.memoryerror;
  //registerMemoryErrorHandler();
  import core.sys.posix.signal;
  sigaction_t action;
  action.sa_sigaction = &handleSignalZZ;
  action.sa_flags = SA_SIGINFO;
  auto oldptr = &old_sigaction;
  sigaction(SIGSEGV, &action, oldptr);
}
*/


// ////////////////////////////////////////////////////////////////////////// //
version(X86) {
  version = follin_use_sse;
  version = follin_use_sse2;
}


// ////////////////////////////////////////////////////////////////////////// //
// throws FollinException on error
// starts paused
void tflInit () {
  version(follin_prefer_alsa_plug) {
    static immutable string[2] devnames = ["plug:default", "default"];
  } else {
    static immutable string[2] devnames = ["default", "plug:default"];
  }
  if (!cas(&initialized, false, true)) throw new FollinException("double initialization");
  foreach (string name; devnames) {
    try {
      sndInit(name.ptr, samplerate);
      sndEngineInit();
      atomicStore(sndPaused, false);
      atomicStore(sndWantShutdown, false);
      atomicStore(sndSafeToShutdown0, false);
      atomicStore(sndSafeToShutdown1, false);
      //{ import core.stdc.stdio; printf("pmin=%u; pmax=%u; pdef=%u\n", Thread.PRIORITY_MIN, Thread.PRIORITY_MAX, Thread.PRIORITY_DEFAULT); }
      // 2.066 compatibility
      sndThread = new Thread(&sndPlayTreadFunc);
      sndThread.start();
      sndMixThread = new Thread(&sndMixTreadFunc);
      sndMixThread.start();
      return;
    } catch (FollinException e) {
      import core.stdc.stdio : fprintf, stderr;
      fprintf(stderr, "Follin: '%s' error: %.*s", name.ptr, cast(int)e.msg.length, cast(const(char)*)e.msg.ptr);
    }
  }
  atomicStore(initialized, false);
  throw new FollinException("can't initialize audio");
}

void tflDeinit () nothrow @trusted /*@nogc*/ { sndEngineDeinit(); }


@property nothrow @trusted @nogc bool tflInitialized () { static if (__VERSION__ > 2067) pragma(inline, true); return atomicLoad(initialized); }

@property pure nothrow @safe @nogc {
  bool tflStereo () { static if (__VERSION__ > 2067) pragma(inline, true); return (numchans == 2); }
  uint tflBytesPerSample () { static if (__VERSION__ > 2067) pragma(inline, true); return 2; }
}

@property nothrow @trusted @nogc {
  uint tflSampleRate () { static if (__VERSION__ > 2067) pragma(inline, true); return realSampleRate; }
  uint tflLatency () { static if (__VERSION__ > 2067) pragma(inline, true); return latency*bufcount; } // in milliseconds
  uint tflActiveChannels () { static if (__VERSION__ > 2067) pragma(inline, true); return atomicLoad(/*sndActiveChanCount*/firstFreeChan); }

  bool tflPaused () { static if (__VERSION__ > 2067) pragma(inline, true); return atomicLoad(sndPaused); }
  void tflPaused (bool v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndPaused, v); }

  ubyte tflMasterVolume () {
    static if (__VERSION__ > 2067) pragma(inline, true);
    auto l = atomicLoad(sndMasterVolumeL);
    auto r = atomicLoad(sndMasterVolumeR);
    return cast(ubyte)(l > r ? l : r);
  }
  void tflMasterVolume (ubyte v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndMasterVolumeL, cast(uint)v); atomicStore(sndMasterVolumeR, cast(uint)v); }

  ubyte tflMasterVolumeL () { static if (__VERSION__ > 2067) pragma(inline, true); return cast(ubyte)atomicLoad(sndMasterVolumeL); }
  void tflMasterVolumeL (ubyte v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndMasterVolumeL, cast(uint)v); }
  ubyte tflMasterVolumeR () { static if (__VERSION__ > 2067) pragma(inline, true); return cast(ubyte)atomicLoad(sndMasterVolumeR); }
  void tflMasterVolumeR (ubyte v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndMasterVolumeR, cast(uint)v); }
}


// ////////////////////////////////////////////////////////////////////////// //
public void tflShort2Float (in short[] input, float[] output) nothrow @trusted @nogc {
  if (output.length < input.length) assert(0, "invalid length");
  auto d = output.ptr;
  immutable float mul = 1.0f/32768.0f;
  foreach (short v; input) *d++ = mul*v;
}


// will not resize output
public void tflFloat2Short (in float[] input, short[] output) nothrow @trusted @nogc {
  auto s = input.ptr;
  auto d = output.ptr;
  version(follin_use_sse) {
    auto blen = cast(uint)input.length;
    if (blen > 0) {
      __gshared float[4] mvol = void;
      mvol[] = 32768.0;
      asm nothrow @safe @nogc {
        mov      EAX,offsetof mvol[0]; // source
        movups   XMM4,[EAX]; // XMM4: multipliers
        mov      EAX,[s]; // source
        mov      EBX,[d]; // dest
        mov      ECX,[blen];
        mov      EDX,ECX;
        shr      ECX,2;
        jz       skip4part;
        align 8;
       finalloopmix:
        movups   XMM0,[EAX];
        mulps    XMM0,XMM4;    // mul by volume and shift
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;  // XMM1 now contains four int32 values
        packssdw  XMM1,XMM1;
        movq      [EBX],XMM1;
      } else asm nothrow @safe @nogc {
        cvtps2pi MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps  XMM5,XMM0;    // get high floats
        cvtps2pi MM1,XMM5;     // MM1 now contains two high int32 values
        packssdw MM0,MM1;      // MM0 now contains 4 int16 values
        movq     [EBX],MM0;
      }
      asm nothrow @safe @nogc {
        add     EAX,16;
        add     EBX,8;
        dec     ECX;
        jnz     finalloopmix;
       skip4part:
        test    EDX,2;
        jz      skip2part;
        // do 2 floats
        movd    XMM0,[EAX];
       }
       version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;  // XMM1 now contains int32 values
        packssdw  XMM1,XMM1;
        movd      [EBX],XMM1;
       } else asm nothrow @safe @nogc {
        cvtps2pi MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps  XMM5,XMM0;    // get high floats
        packssdw MM0,MM1;      // MM0 now contains 4 int16 values
        movd     [EBX],MM0;
       }
       asm nothrow @safe @nogc {
        add     EAX,8;
        add     EBX,4;
       skip2part:
        test     EDX,1;
        jz       skip1part;
        movss     XMM0,[EAX];
       }
       version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;  // XMM1 now contains int32 values
        packssdw  XMM1,XMM1;
        movss     [EBX],XMM1;
       } else asm nothrow @safe @nogc {
        cvtps2pi MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps  XMM5,XMM0;    // get high floats
        packssdw MM0,MM1;      // MM0 now contains 4 int16 values
        movss    [EBX],MM0;
       }
      skip1part:
      version(follin_use_sse2) {} else {
        asm nothrow @safe @nogc { emms; }
      }
    }
  } else {
    mixin(declfcvar!"temp");
    foreach (immutable _; 0..input.length) {
      mixin(FAST_SCALED_FLOAT_TO_INT!("*s", "15"));
      if (cast(uint)(v+32768) > 65535) v = (v < 0 ? -32768 : 32767);
      *d++ = cast(short)v;
      ++s;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// channel management
// note that any method can be called while sound engine is locked, and from arbitrary thread
class TflChannel {
  // resampling quality
  alias Quality = int;
  enum QualityMin = -1; // try cubic upsampler
  enum QualityMax = 10;
  enum QualityMusic = 8;
  enum QualitySfx = -1; // default

  // volumes for each channel
  ubyte volL = 255;
  ubyte volR = 255;
  uint sampleRate = 44100;
  bool stereo = true;
  bool paused = false;

  final @property ubyte volume () pure const nothrow @safe @nogc { return (volL > volR ? volL : volR); }
  final @property void volume (ubyte v) nothrow @safe @nogc { volL = volR = v; }

  // all of the above will be read before `fillFrames`
  // if channel is paused, `fillFrames` will not be called

  // override this if you can provide floating buffer
  // Folling will provide `tmpbuf` of the same size as `buf`
  // return number of *frames* (not samples!) written
  // 0 means "this channel is no more"
  uint fillFrames (float[] buf) nothrow @nogc { return 0; }

  // called when the channel is discarded (due to being `done` or by replacing with another channel)
  // note that sound engine is locked, so you can't call `tflAddChan()` here
  // also, this can (and will) be called from different threads
  void discarded () nothrow @nogc {}
}


// default priority; channel with lesser priority wins
enum TFLdefault = 1000;
enum TFLplayer = 500;
enum TFLmusic = 100; // music should always play

// returns `false` if there's no room for new channel (and it's not added)
bool tflAddChannel (const(char)[] name, TflChannel chan, uint prio=TFLdefault, TflChannel.Quality q=TflChannel.QualitySfx) { static if (__VERSION__ > 2067) pragma(inline, true); return sndAddChan(name, chan, prio, q); }
bool tflKillChannel (const(char)[] name) { static if (__VERSION__ > 2067) pragma(inline, true); return sndKillChan(name); }
bool tflIsChannelAlive (const(char)[] name) nothrow @trusted /*@nogc*/ { static if (__VERSION__ > 2067) pragma(inline, true); return sndIsChanAlive(name); }
TflChannel tflChannelObject (const(char)[] name) nothrow @trusted /*@nogc*/ { static if (__VERSION__ > 2067) pragma(inline, true); return sndGetChanObj(name); }
uint tflChannelPlayTimeMsec (const(char)[] name) nothrow @trusted /*@nogc*/ { static if (__VERSION__ > 2067) pragma(inline, true); return sndGetPlayTimeMsec(name); }

// ////////////////////////////////////////////////////////////////////////// //
private:
import core.atomic;
import core.sync.condition;
import core.sync.rwmutex;
import core.sync.mutex;
import core.thread;

import iv.follin.drivers;
import iv.follin.ftrick;
import iv.follin.hash;
import iv.follin.resampler;
import iv.follin.sdata;


enum samplerate = 44100;
enum numchans = 2;
enum bufcount = 2;
enum maxchans = 32;
//enum latency = 200; // milliseconds
//static assert(1000%latency == 0);
shared bool initialized = false;
shared bool sndWantShutdown = false;
shared bool sndSafeToShutdown0 = false, sndSafeToShutdown1 = false;
//shared uint sndActiveChanCount;
__gshared float[] sndrsbuf;
__gshared float[] tmprsbuf; // here we'll collect floating point samples
__gshared float[] tmpmonobuf; // here we'll collect mono samples
__gshared Thread sndThread = null, sndMixThread = null;
shared uint sndMasterVolumeL = 255;
shared uint sndMasterVolumeR = 255;
__gshared ReadWriteMutex sndMutexChanRW;
__gshared Mutex mutexCondMixer;
__gshared Condition condMixerWait;

shared static this () {
  mutexCondMixer = new Mutex();
  condMixerWait = new Condition(mutexCondMixer);
  sndMutexChanRW = new ReadWriteMutex(ReadWriteMutex.Policy.PREFER_WRITERS);
}


// ////////////////////////////////////////////////////////////////////////// //
void sndEngineInit () {
  sndSamplesSize *= numchans; // frames to samples
  sndbuf.length = (sndSamplesSize+32)*bufcount;
  sndbuf[] = 0;
  sndsilence.length = (sndSamplesSize+32)*bufcount;
  sndsilence[] = 0;
  tmprsbuf.length = sndSamplesSize+32;
  sndrsbuf.length = sndSamplesSize+32;
  tmpmonobuf.length = sndSamplesSize+32;
  foreach (ref ch; chans) {
    import core.stdc.stdlib : malloc;
    ch.buf = cast(float*)malloc(ch.buf[0].sizeof*(sndSamplesSize+32));
    if (ch.buf is null) assert(0, "Follin: out of memory");
    ch.bufpos = 0;
    if (!ch.srb.inited) {
      ch.lastquality = 8;
      ch.srb.setup(numchans, 44100, 48000, ch.lastquality);
    }
    ch.cub.reset();
    ch.prevsrate = ch.lastsrate = 44100;
  }
  scope(failure) {
    import core.stdc.stdlib : free;
    foreach (ref ch; chans) {
      if (ch.buf !is null) { free(ch.buf); ch.buf = null; }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Channel {
  uint prio; // channel priority
  usize namehash;
  usize namelen; // 0: this channel is free
  char[128] name; // no longer than this
  TflChannel chan; // can be `null` if channel callback is done, but something is still playing
  SpeexResampler srb;
  CubicUpsampler cub;
  // buffers are always of `sndSamplesSize` size
  float* buf; // frame buffer
  uint bufpos; // current position to write in `tmpbuf`/`buf`
  ubyte lastvolL, lastvolR; // latest volume
  int lastquality = 666; // <0: try cubic
  uint lastsrate, prevsrate; // last sampling rate
  ulong genFrames; // generated, but not yet consumed frames
  ulong playedFrames;

  @disable this (this); // no copies
}


__gshared Channel[maxchans] chans;
shared ulong chanid = 0;
shared uint firstFreeChan = 0;
__gshared uint sndFrameId;


void packChannels () nothrow @trusted @nogc {
  import core.stdc.string : memcpy;

  __gshared ubyte[Channel.srb.sizeof > Channel.cub.sizeof ? Channel.srb.sizeof : Channel.cub.sizeof] srbMoveBuf = void;

  int freeIdx = 0;
  for (;;) {
    // find free channel
    while (freeIdx < firstFreeChan && chans.ptr[freeIdx].namelen != 0) ++freeIdx;
    if (freeIdx >= firstFreeChan) return; // nothing to do
    // find used channel
    int idx = freeIdx;
    while (idx < firstFreeChan && chans.ptr[idx].namelen == 0) ++idx;
    if (idx >= firstFreeChan) { firstFreeChan = freeIdx; return; } // done
    // now move used channel up
    auto sc = &chans.ptr[idx];
    auto dc = &chans.ptr[freeIdx];
    sc.prio = dc.prio;
    sc.namehash = dc.namehash;
    sc.namelen = dc.namelen;
    sc.name = dc.name;
    sc.chan = dc.chan;
    // now tricky part: swap SpeexResampler
    memcpy(srbMoveBuf.ptr, &sc.srb, sc.srb.sizeof);
    memcpy(&sc.srb, &dc.srb, sc.srb.sizeof);
    memcpy(&dc.srb, srbMoveBuf.ptr, sc.srb.sizeof);
    // now tricky part: swap CubicUpsampler
    memcpy(srbMoveBuf.ptr, &sc.cub, sc.cub.sizeof);
    memcpy(&sc.cub, &dc.cub, sc.cub.sizeof);
    memcpy(&dc.cub, srbMoveBuf.ptr, sc.cub.sizeof);
    // mark as free
    sc.namelen = 0;
    sc.chan = null;
  }
}


Channel* sndFindChanByName (const(char)[] name) nothrow @trusted @nogc {
  if (name.length == 0 || name.length > Channel.name.length) return null;
  auto hash = hashBuffer(name.ptr, name.length);
  foreach (ref ch; chans) {
    if (ch.namelen == 0) break;
    if (ch.namehash == hash && ch.namelen == name.length && ch.name[0..ch.namelen] == name) return &ch;
  }
  return null;
}


bool sndIsChanAlive (const(char)[] name) nothrow @trusted /*@nogc*/ {
  synchronized (sndMutexChanRW.reader) {
    if (auto ch = sndFindChanByName(name)) return true;
  }
  return false;
}


TflChannel sndGetChanObj (const(char)[] name) nothrow @trusted /*@nogc*/ {
  synchronized (sndMutexChanRW.reader) {
    if (auto ch = sndFindChanByName(name)) return ch.chan;
  }
  return null;
}


uint sndGetPlayTimeMsec (const(char)[] name) nothrow @trusted /*@nogc*/ {
  synchronized (sndMutexChanRW.reader) {
    if (auto ch = sndFindChanByName(name)) return cast(uint)(ch.playedFrames*1000/realSampleRate);
  }
  return 0;
}


bool sndKillChan (const(char)[] name) {
  if (name.length == 0 || name.length > Channel.name.length) return false;
  auto hash = hashBuffer(name.ptr, name.length);
  //sndLock!"sndKillChan"();
  //scope(exit) sndUnlock!"sndKillChan"();
  synchronized (sndMutexChanRW.writer) {
    foreach (ref ch; chans) {
      if (ch.namelen == 0) break;
      if (ch.namehash == hash && ch.namelen == name.length && ch.name[0..ch.namelen] == name) {
        // kill this channel
        auto ochan = ch.chan;
        ch.chan = null;
        ch.bufpos = 0;
        ch.namelen = 0;
        ch.genFrames = 0;
        if (ochan !is null) ochan.discarded();
        return true;
      }
    }
  }
  return false;
}


bool sndAddChan (const(char)[] name, TflChannel chan, uint prio, TflChannel.Quality q) {
  char[64] tmpname;
  // build name if there's none
  if (name.length == 0) {
    if (chan is null) return false;
    usize pos = tmpname.length;
    //sndLock!"sndAddChanAnon"();
    ulong num = atomicOp!"+="(chanid, 1);
    //sndUnlock!"sndAddChanAnon"();
    do { tmpname[--pos] = cast(char)('0'+num%10); } while ((num /= 10) != 0);
    enum pfx = "uninspiring channel #";
    pos -= pfx.length;
    tmpname[pos..pos+pfx.length] = pfx[];
    name = tmpname[pos..$];
  } else if (name.length > Channel.name.length) {
    //throw FollinException("channel name too long: '"~name.idup~"'");
    return false;
  }
  auto hash = hashBuffer(name.ptr, name.length);
  //sndLock!"sndAddChan"();
  //scope(exit) sndUnlock!"sndAddChan"();

  static struct VictimInfo {
    int idx = -1;
    ubyte vol = 255;
    int state = int.max; // bufpos, or `int.max-1` for paused

    static T max(T) (T a, T b) { return (a > b ? a : b); }
    static T min(T) (T a, T b) { return (a < b ? a : b); }

    void fixVictim(string mode) (ref Channel ch, uint prio, usize curidx) nothrow @trusted @nogc {
      static assert(mode == "same" || mode == "lower");
      static if (mode == "same") {
        if (ch.prio != prio) return;
      } else {
        if (ch.prio <= prio) return;
        if (idx >= 0 && chans.ptr[idx].prio > ch.prio) {
          // we have a victim with better priority, but we'll prefer "going to die" to paused one
          if (chans.ptr[idx].chan is null || ch.chan !is null) return;
        }
      }
      if (ch.chan is null) {
        // this channel is going to die
        if (ch.bufpos < state || max(ch.lastvolL, ch.lastvolR) < vol) {
          // this channel is better victim: has less data left, or has lower volume
          idx = cast(int)curidx;
          state = ch.bufpos;
          vol = max(ch.lastvolL, ch.lastvolR);
        }
      } else if (ch.chan.paused) {
        // this channel is paused
        if (state == int.max || (state == int.max-1 && max(ch.lastvolL, ch.lastvolR) < vol)) {
          // this channel is better victim: either there is no victim found yet, or has paused victim with lower volume
          idx = cast(int)curidx;
          state = int.max-1;
          vol = max(ch.lastvolL, ch.lastvolR);
        }
      }
    }
  }

  VictimInfo lower, same;
  int replaceIdx = -1;

  synchronized (sndMutexChanRW.writer) {
    // for lowest prio: prefer finished channel, then paused channel
    foreach (immutable idx, ref ch; chans) {
      if (ch.namelen == 0) break; // last channel
      if (ch.namehash == hash && ch.namelen == name.length && ch.name[0..ch.namelen] == name) {
        replaceIdx = cast(int)idx;
        break;
      }
      lower.fixVictim!"lower"(ch, prio, idx);
      same.fixVictim!"same"(ch, prio, idx);
    }

    if (replaceIdx < 0) {
      if (chan is null) return false;
      if (lower.idx >= 0 && lower.state < int.max-1) {
        // lower and dying
        replaceIdx = lower.idx;
      } else if (same.idx >= 0 && same.state < int.max-1) {
        // same and dying
        replaceIdx = same.idx;
      } else if (lower.idx >= 0) {
        // lower
        replaceIdx = lower.idx;
      } else {
        // same
        replaceIdx = same.idx;
      }
      if (replaceIdx < 0) {
        if (firstFreeChan >= chans.length) return false; // alas
        replaceIdx = firstFreeChan;
      }
    }

    // replace channel
    auto ch = &chans.ptr[replaceIdx];

    // fix resampling ratio
    if (chan !is null && ch.chan !is chan) {
      auto srate = chan.sampleRate;
      ch.lastsrate = (srate < 1024 || srate > 96000 ? 0 : srate);
      if (ch.lastsrate != 0) {
        ch.srb.reset();
        if (ch.prevsrate != ch.lastsrate && ch.lastsrate != realSampleRate) {
          if (ch.srb.setRate(ch.lastsrate, realSampleRate)) ch.lastsrate = 0;
        }
      }
      ch.prevsrate = ch.lastsrate;
      if (ch.lastsrate == 0) chan = null;
    }

    if (ch.chan !is chan) {
      auto ochan = ch.chan;
      ch.chan = null;
      ch.bufpos = 0;
      ch.genFrames = 0;
      ch.playedFrames = 0;
      if (ochan !is null) ochan.discarded();
      ch.cub.reset(); // it is fast
    }

    if (chan !is null) {
      //if (ch.chan is null) ch.srb.reset();
      if (q < -1) q = -1; else if (q > 10) q = 10;
      if (ch.lastquality != q) {
        //{ import core.stdc.stdio; printf("changing quality from %u to %u\n", ch.lastquality, q); }
        ch.lastquality = q;
        if (ch.srb.inited) {
          ch.srb.setQuality(q);
        } else {
          //ch.srb.deinit();
          ch.srb.setup(numchans, 44100, 48000, q);
        }
      }
      if (ch.prevsrate != ch.lastsrate) {
        if (ch.srb.setRate(ch.lastsrate, realSampleRate)) {
          ch.prevsrate = ch.lastsrate = 0;
          auto ochan = ch.chan;
          ch.chan = null;
          ch.bufpos = 0;
          if (ochan !is null) ochan.discarded();
          ch.namelen = 0; // "it's free" flag
          packChannels();
          return false;
        }
      }
      if (ch.lastquality < 0 && !ch.cub.setup(cast(float)ch.lastsrate/cast(float)realSampleRate)) ch.lastquality = 0; // don't use cubic
      //if (ch.lastquality < 0) { import core.stdc.stdio; printf("*** using cubic upsampler\n"); }
      ch.prevsrate = ch.lastsrate;
      if (ch.bufpos == 0) ch.lastvolL = ch.lastvolR = 0; // so if we won't even had a chance to play it, it can be replaced
      ch.prio = prio;
      ch.namehash = hash;
      ch.namelen = name.length;
      ch.name[0..name.length] = name;
      ch.chan = chan;
      if (replaceIdx >= firstFreeChan) {
        firstFreeChan = replaceIdx+1;
        packChannels();
      }
    } else {
      ch.namelen = 0; // "it's free" flag
      packChannels();
    }
  }

  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
bool sndGenerateBuffer () {
  static void killChan() (ref Channel ch, ref bool channelsChanged) {
    if (ch.namelen) {
      channelsChanged = true;
      auto chan = ch.chan;
      ch.chan = null;
      ch.namelen = 0;
      ch.playedFrames = 0;
      if (chan !is null) {
        chan.discarded();
        ch.srb.reset();
      }
    } else {
      ch.chan = null;
    }
    ch.bufpos = 0;
  }

  SpeexResampler.Error err;
  SpeexResampler.Data srbdata = void;
  bool channelsChanged = false;
  auto buf2fill = atomicLoad(sndbufToFill);
  atomicStore(sndbufFillingNow, true);
  bool wasAtLeastOne = false;
  uint bpos, epos;
  synchronized (sndMutexChanRW.writer) {
    bpos = (sndSamplesSize+8)*buf2fill;
    epos = bpos+sndSamplesSize;
    if (firstFreeChan > 0) {
      immutable bufsz = sndSamplesSize;
      sndrsbuf.ptr[0..sndSamplesSize] = 0.0f;
      //{ import core.stdc.stdio; printf("filling buffer %u\n", buf2fill); }
      foreach (ref ch; chans) {
        if (ch.namelen == 0) break; // last channel
        uint rspos = 0; // current position in `sndrsbuf`
        chmixloop: while (rspos < bufsz) {
          // try to get as much data from the channel as we can
          if (ch.bufpos == 0 && (ch.chan !is null && !ch.chan.paused) && ch.lastsrate != ch.chan.sampleRate) {
            auto srate = ch.chan.sampleRate;
            ch.lastsrate = srate;
            if (srate < 1024 || srate > 96000) {
              ch.lastsrate = srate = 0;
            } else if (srate != ch.prevsrate && srate != realSampleRate) {
              if (ch.srb.setRate(srate, realSampleRate)) ch.lastsrate = srate = 0;
            }
            ch.prevsrate = ch.lastsrate;
            if (!srate) { killChan(ch, channelsChanged); break chmixloop; } // something is wrong with this channel, kill it
            if (ch.lastquality < 0 && !ch.cub.setup(cast(float)srate/cast(float)realSampleRate)) ch.lastquality = 0; // don't use cubic
            //if (ch.lastquality < 0) { import core.stdc.stdio; printf("*** using cubic upsampler\n"); }
          }
          //{ import core.stdc.stdio; printf("wanted %u frames (has %u frames)\n", (bufsz-ch.bufpos)/2, ch.bufpos/2); }
          while (ch.bufpos < bufsz && (ch.chan !is null && !ch.chan.paused) && ch.lastsrate == ch.chan.sampleRate) {
            // fix last known volume
            ch.lastvolL = ch.chan.volL;
            ch.lastvolR = ch.chan.volR;
            // fix last known sample rate
            uint fblen;
            auto len = (bufsz-ch.bufpos)/2; // frames
            if (ch.chan.stereo) {
              // stereo
              fblen = ch.chan.fillFrames(ch.buf[ch.bufpos..bufsz]);
              if (fblen > len) fblen = 0; // something is very wrong with this channel
            } else {
              //FIXME mono
              fblen = ch.chan.fillFrames(tmpmonobuf[0..len]);
              if (fblen > len) fblen = 0; // something is very wrong with this channel
              // expand
              auto s = tmpmonobuf.ptr;
              auto d = ch.buf+ch.bufpos;
              foreach (immutable _; 0..fblen) {
                *d++ = *s;
                *d++ = *s++;
              }
            }
            //{ import core.stdc.stdio; printf("trying to get %u frames, got %u frames...\n", (bufsz-ch.bufpos)/2, fblen); }
            if (fblen == 0) { killChan(ch, channelsChanged); break; }
            // do volume
            if (ch.lastvolL+ch.lastvolR == 0) {
              // silent
              ch.buf[ch.bufpos..bufsz] = 0.0f;
            } else {
              version(follin_use_sse) {
                if (ch.lastvolL != 255 || ch.lastvolR != 255) {
                  __gshared float[4] mul = void;
                  mul[0] = mul[2] = (1.0f/255.0f)*cast(float)ch.lastvolL;
                  mul[1] = mul[3] = (1.0f/255.0f)*cast(float)ch.lastvolR;
                  auto bptr = ch.buf+ch.bufpos;
                  auto blen = (fblen+1)/2;
                  asm nothrow @safe @nogc {
                    mov     EAX,[bptr];
                    mov     EBX,offsetof mul[0];
                    mov     ECX,[blen];
                    align 8;
                    movups  XMM1,[EBX];
                    align 8;
                   addloopchvol:
                    movups  XMM0,[EAX];
                    mulps   XMM0,XMM1;
                    movups  [EAX],XMM0;
                    add     EAX,16;
                    dec     ECX;
                    jnz     addloopchvol;
                  }
                }
              } else {
                // left
                if (ch.lastvolL == 255) {
                  // at full volume, do nothing
                } else if (ch.lastvolL == 0) {
                  // silent, clear it
                  auto d = ch.buf+ch.bufpos;
                  foreach (immutable _; 0..fblen) {
                    *d = 0.0f;
                    d += 2;
                  }
                } else {
                  // do volume
                  immutable float mul = cast(float)ch.lastvolL/255.0f;
                  auto d = ch.buf+ch.bufpos;
                  foreach (immutable _; 0..fblen) {
                    *d *= mul;
                    d += 2;
                  }
                }
                // right
                if (ch.lastvolR == 255) {
                  // at full volume, do nothing
                } else if (ch.lastvolR == 0) {
                  // silent, clear it
                  auto d = ch.buf+ch.bufpos+1;
                  foreach (immutable _; 0..fblen) {
                    *d = 0.0f;
                    d += 2;
                  }
                } else {
                  // do volume
                  immutable float mul = cast(float)ch.lastvolL/255.0f;
                  auto d = ch.buf+ch.bufpos+1;
                  foreach (immutable _; 0..fblen) {
                    *d *= mul;
                    d += 2;
                  }
                }
              } // version
            }
            ch.bufpos += fblen*2; // frames to samples
          }
          if (ch.lastquality < 0 && ch.bufpos < bufsz) ch.cub.reset(); // it is fast

          //{ import core.stdc.stdio; printf("have %u frames out of %u\n", ch.bufpos/2, bufsz/2); }
          // if we have any data in channel buffer, resample it
          uint bsused = void;
          if (ch.lastsrate != realSampleRate) {
            // resample
            bsused = 0;
            uint tspos = rspos;
            while (bsused < ch.bufpos && tspos < bufsz) {
              srbdata.dataIn = ch.buf[bsused..ch.bufpos];
              srbdata.dataOut = tmprsbuf.ptr[tspos..bufsz];
              //{ import core.stdc.stdio; printf("realSampleRate=%u; ch.lastsrate=%u\n", realSampleRate, ch.lastsrate); }
              err = (ch.lastquality < 0 ? ch.cub.process(srbdata) : ch.srb.process(srbdata));
              if (err) { killChan(ch, channelsChanged); break; }
              //{ import core.stdc.stdio; printf("inused: %u of %u; outused: %u of %u; bsused=%u\n", srbdata.inputSamplesUsed, cast(uint)srbdata.dataIn.length, srbdata.outputSamplesUsed, cast(uint)srbdata.dataOut.length, bsused); }
              bsused += srbdata.inputSamplesUsed;
              tspos += srbdata.outputSamplesUsed;
            }
            //{ import core.stdc.stdio; printf("resampled %u frames to %u frames\n", bsused/2, (tspos-rspos)/2); }
            // mix
            // will clamp later
            version(follin_use_sse) {
              if (rspos < tspos) {
                auto s = tmprsbuf.ptr+rspos;
                auto d = sndrsbuf.ptr+rspos;
                auto blen = (tspos-rspos+3)/4;
                asm nothrow @safe @nogc {
                  mov     EAX,[d];
                  mov     EBX,[s];
                  mov     ECX,[blen];
                  align 8;
                 addloopchmix:
                  movups  XMM0,[EAX];
                  movups  XMM1,[EBX];
                  addps   XMM0,XMM1;
                  movups  [EAX],XMM0;
                  add     EAX,16;
                  add     EBX,16;
                  dec     ECX;
                  jnz     addloopchmix;
                }
              }
            } else {
              auto s = tmprsbuf.ptr+rspos;
              auto d = sndrsbuf.ptr+rspos;
              foreach (immutable _; rspos..tspos) *d++ += *s++;
            }
            ch.genFrames += (tspos-rspos)/2;
            //{ import core.stdc.stdio; printf("  +f: %u\n", (tspos-rspos)/2); }
            rspos += tspos;
          } else {
            // mix directly
            bsused = ch.bufpos;
            if (bsused > bufsz-rspos) bsused = bufsz-rspos;
            auto s = ch.buf;
            auto d = sndrsbuf.ptr+rspos;
            // will clamp later
            version(follin_use_sse) {
              auto blen = (bsused+3)/4;
              asm nothrow @safe @nogc {
                mov     EAX,[d];
                mov     EBX,[s];
                mov     ECX,[blen];
                align 8;
               addloopchmix1:
                movups  XMM0,[EAX];
                movups  XMM1,[EBX];
                addps   XMM0,XMM1;
                movups  [EAX],XMM0;
                add     EAX,16;
                add     EBX,16;
                dec     ECX;
                jnz     addloopchmix1;
              }
            } else {
              foreach (immutable _; 0..bsused) *d++ += *s++;
            }
            rspos += bsused;
            ch.genFrames += bsused/2;
            //{ import core.stdc.stdio; printf("  +f: %u\n", bsused/2); }
          }

          // remove data from input buffer
          if (bsused >= ch.bufpos) {
            ch.bufpos = 0;
          } else if (bsused > 0) {
            import core.stdc.string : memmove;
            memmove(ch.buf, ch.buf+bsused, (ch.bufpos-bsused)*ch.buf[0].sizeof);
            ch.bufpos -= bsused;
          }

          // if this channel is paused or dead, do not try to process it again
          if (ch.chan is null || ch.chan.paused) {
          // try to squeeze last resampled data bytes out of it
            if (rspos < bufsz && ch.lastsrate != realSampleRate) {
              srbdata.dataIn = null;
              srbdata.dataOut = tmprsbuf.ptr[rspos..bufsz];
              err = (ch.lastquality < 0 ? ch.cub.process(srbdata) : ch.srb.process(srbdata));
              if (err) { killChan(ch, channelsChanged); break chmixloop; }
              if (srbdata.outputSamplesUsed) {
                // mix
                auto s = tmprsbuf.ptr+rspos;
                auto d = sndrsbuf.ptr+rspos;
                // will clamp later
                version(follin_use_sse) {
                  auto blen = (srbdata.outputSamplesUsed+3)/4;
                  asm nothrow @safe @nogc {
                    mov     EAX,[d];
                    mov     EBX,[s];
                    mov     ECX,[blen];
                    align 8;
                   addloopchmix2:
                    movups  XMM0,[EAX];
                    movups  XMM1,[EBX];
                    addps   XMM0,XMM1;
                    movups  [EAX],XMM0;
                    add     EAX,16;
                    add     EBX,16;
                    dec     ECX;
                    jnz     addloopchmix2;
                  }
                } else {
                  foreach (immutable _; 0..srbdata.outputSamplesUsed) *d++ += *s++;
                }
                rspos += srbdata.outputSamplesUsed;
              }
            }
            break;
          }
        } // rspos loop
        // what is left is silence, no need to mix it
        wasAtLeastOne = wasAtLeastOne || (rspos > 0);
      }
    }
    if (channelsChanged) packChannels();
  }

  // do final converting
  if (wasAtLeastOne) {
    // something is playing, mix it
    auto mvolL = cast(ubyte)atomicLoad(sndMasterVolumeL);
    auto mvolR = cast(ubyte)atomicLoad(sndMasterVolumeR);
    if (mvolL+mvolR == 0) {
      sndbuf[bpos..epos] = 0;
    } else {
      auto dp = sndbuf.ptr+bpos;
      auto src = sndrsbuf.ptr;
      version(follin_use_sse) {
        //__gshared immutable float[4] fmin4 = -32768.0;
        //__gshared immutable float[4] fmax4 = 32767.0;
        __gshared float[4] mvol = void;
        mvol[0] = mvol[2] = (32768.0/255.0f)*cast(float)mvolL;
        mvol[1] = mvol[3] = (32768.0/255.0f)*cast(float)mvolR;
        auto blen = (sndSamplesSize+3)/4;
        asm nothrow @safe @nogc {
          //mov      EAX,offsetof fmin4[0];
          //movups   XMM2,[EAX]; // XMM2: min values
          //mov      EAX,offsetof fmax4[0];
          //movups   XMM3,[EAX]; // XMM3: max values
          mov      EAX,offsetof mvol[0]; // source
          movups   XMM4,[EAX]; // XMM4: multipliers
          mov      EAX,[src]; // source
          mov      EBX,[dp]; // dest
          mov      ECX,[blen];
          align 8;
         finalloopmix:
          movups   XMM0,[EAX];
          mulps    XMM0,XMM4;    // mul by volume and shift
          //maxps    XMM0,XMM2;    // clip lower
          //minps    XMM0,XMM3;    // clip upper
        }
        version(follin_use_sse2) asm nothrow @safe @nogc {
          cvttps2dq XMM1,XMM0;  // XMM1 now contains four int32 values
          packssdw  XMM1,XMM1;
          movq      [EBX],XMM1;
        } else asm nothrow @safe @nogc {
          cvtps2pi MM0,XMM0;     // MM0 now contains two low int32 values
          movhlps  XMM5,XMM0;    // get high floats
          cvtps2pi MM1,XMM5;     // MM1 now contains two high int32 values
          packssdw MM0,MM1;      // MM0 now contains 4 int16 values
          movq     [EBX],MM0;
        }
        asm nothrow @safe @nogc {
          add     EAX,16;
          add     EBX,8;
          dec     ECX;
          jnz     finalloopmix;
        }
        version(follin_use_sse2) {} else {
          asm nothrow @safe @nogc { emms; }
        }
      } else {
        immutable float mull = (1.0f/255.0f)*mvolL;
        immutable float mulr = (1.0f/255.0f)*mvolR;
        mixin(declfcvar!"temp");
        foreach (immutable _; 0..sndSamplesSize/2) {
          // left
          float f = (*src++)*mull;
          {
            mixin(FAST_SCALED_FLOAT_TO_INT!("f", "15"));
            if (cast(uint)(v+32768) > 65535) v = (v < 0 ? -32768 : 32767);
            *dp++ = cast(short)v;
          }
          // right
          f = (*src++)*mulr;
          {
            mixin(FAST_SCALED_FLOAT_TO_INT!("f", "15"));
            if (cast(uint)(v+32768) > 65535) v = (v < 0 ? -32768 : 32767);
            *dp++ = cast(short)v;
          }
        }
      }
    }
  } else {
    sndbuf[bpos..epos] = 0;
  }
  atomicStore(sndbufToFill, (buf2fill+1)%bufcount);
  atomicStore(sndbufFillingNow, false);
  return wasAtLeastOne;
}


// ////////////////////////////////////////////////////////////////////////// //
private extern (C) void thread_suspendAll() nothrow; // steal that func!


// ////////////////////////////////////////////////////////////////////////// //
// mixer thread: it mixes sound buffers
// as modern systems had multicore CPUs, i believe that it worth having two worker threads
void sndMixTreadFunc () {
  // detach ourself, so GC will not stop us
  thread_detachThis();
  // while documentation says that we have to call this, in reality
  // i see one more module tls dtor called with it. this is due to
  // the fact that `thread_entryPoint()` will call `rt_moduleTlsDtor()`
  // on exiting. let's hope that modules won't rely on GC suspending
  // all threads on collecting (they shouldn't)
  //rt_moduleTlsDtor();
  try {
    version(follin_threads_debug) { import core.stdc.stdio; printf("mixer thread started\n"); }
    for (;;) {
      if (atomicLoad(sndWantShutdown)) { atomicStore(sndSafeToShutdown0, true); return; }
      // do we have a room for new buffer?
      auto b2f = atomicLoad(sndbufToFill);
      auto b2p = atomicLoad(sndbufToPlay);
      // note that if playback is paused, we will eventually fill all buffers and wait
      if (b2f != b2p) {
        // yay!
        version(follin_threads_debug) { import core.stdc.stdio; printf("creating %u buffer; playing %u buffer\n", b2f, b2p); }
        sndGenerateBuffer();
      } else {
        version(follin_threads_debug) { import core.stdc.stdio; printf("mixer thread fell asleep; 2play=%u; 2fill=%u\n", atomicLoad(sndbufToPlay), atomicLoad(sndbufToFill)); }
        synchronized(mutexCondMixer) condMixerWait.wait();
        version(follin_threads_debug) { import core.stdc.stdio; printf("mixer thread awoken; 2play=%u; 2fill=%u\n", atomicLoad(sndbufToPlay), atomicLoad(sndbufToFill)); }
      }
    }
  } catch (Throwable e) {
    // here, we are dead and fucked (the exact order doesn't matter)
    import core.stdc.stdlib : abort;
    import core.stdc.stdio : fprintf, stderr;
    import core.memory : GC;
    GC.disable(); // yeah
    thread_suspendAll(); // stop right here, you criminal scum!
    auto s = e.toString();
    fprintf(stderr, "\n=== FATAL ===\n%.*s\n", cast(uint)s.length, s.ptr);
    abort(); // die, you bitch!
  }
}


// player thread: it plays mixed buffers
void sndPlayTreadFunc () {
  // detach ourself, so GC will not stop us
  thread_detachThis(); // see comment in `sndMixTreadFunc()`
  try {
    // fill all buffers
    foreach (uint bufnum; 0..bufcount) {
      atomicStore(sndbufToPlay, bufnum+1); // hoax
      atomicStore(sndbufToFill, bufnum);
      // generate one buffer
      sndGenerateBuffer();
    }
    // restore playing and filling order
    atomicStore(sndbufToFill, 0);
    atomicStore(sndbufToPlay, 0);
    // and go with the sound
    version(follin_threads_debug) { import core.stdc.stdio; printf("starting playback\n"); }
    bool playbackStarted = false;
    for (;;) {
      if (atomicLoad(sndWantShutdown)) { atomicStore(sndSafeToShutdown1, true); return; }
      auto b2p = atomicLoad(sndbufToPlay);
      auto consumed = sndWriteBuffer(playbackStarted);
      if (consumed) {
        // buffer consumed
        // fix channel playing time
        synchronized (sndMutexChanRW.writer) {
          if (firstFreeChan > 0) {
            foreach (ref ch; chans) {
              if (ch.namelen == 0) break; // last channel
              //{ import core.stdc.stdio; printf("pf: %u; gf: %u\n", cast(uint)ch.playedFrames, cast(uint)ch.genFrames); }
              if (ch.playedFrames < ch.genFrames) {
                ch.playedFrames += sndSamplesSize/2;
                if (ch.playedFrames > ch.genFrames) ch.playedFrames = ch.genFrames;
              }
            }
          }
        }
        b2p = (b2p+1)%bufcount;
        atomicStore(sndbufToPlay, b2p);
        //if (b2p != atomicLoad(sndbufToFill)) atomicStore(sndbufToPlay, (b2p+1)%bufcount);
        version(follin_threads_debug) { import core.stdc.stdio; printf("pinging mixer thread; b2p=%u; b2f=%u\n", atomicLoad(sndbufToPlay), atomicLoad(sndbufToFill)); }
        synchronized(mutexCondMixer) condMixerWait.notify();
      }
    }
  } catch (Throwable e) {
    // here, we are dead and fucked (the exact order doesn't matter)
    import core.stdc.stdlib : abort;
    import core.stdc.stdio : fprintf, stderr;
    import core.memory : GC;
    GC.disable(); // yeah
    thread_suspendAll(); // stop right here, you criminal scum!
    auto s = e.toString();
    fprintf(stderr, "\n=== FATAL ===\n%.*s\n", cast(uint)s.length, s.ptr);
    abort(); // die, you bitch!
  }
}


// ////////////////////////////////////////////////////////////////////////// //
shared static ~this () nothrow @trusted /*@nogc*/ { sndEngineDeinit(); }


void sndEngineDeinit () nothrow @trusted {
  //{ import core.stdc.stdio; printf("DEINIT...\n"); }
  if (cas(&sndWantShutdown, false, true)) {
    //{ import core.stdc.stdio; printf("DEINIT: 0\n"); }
    if (atomicLoad(initialized)) {
      import core.sys.posix.unistd : usleep;
      while (!atomicLoad(sndSafeToShutdown0)) { synchronized(mutexCondMixer) condMixerWait.notify(); usleep(1000); } // arbitrary number
      while (!atomicLoad(sndSafeToShutdown1)) usleep(1000); // arbitrary number
      //{ import core.stdc.stdio; printf("DEINIT: 1\n"); }
      sndThread = sndMixThread = null;
      sndDeinit();
      foreach (ref ch; chans) {
        import core.stdc.stdlib : free;
        ch.namelen = 0;
        ch.chan = null;
        if (ch.buf !is null) { free(ch.buf); ch.buf = null; }
        ch.srb.deinit();
      }
      atomicStore(initialized, false);
    }
  }
  atomicStore(sndWantShutdown, false);
  atomicStore(sndSafeToShutdown0, false);
  atomicStore(sndSafeToShutdown1, false);
}
