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

version = follin_use_spinrw;
//version = follin_prefer_alsa_plug;
//version = follin_threads_debug;
//version = follin_wait_debug;
//version = follin_debug_resampler_type;

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
    auto l = atomicLoad(sndMasterVolume);
    auto r = (l>>8)&0xff;
    return cast(ubyte)(l > r ? l : r);
  }
  void tflMasterVolume (ubyte v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndMasterVolume, cast(ushort)(v<<8|v)); }

  ubyte tflMasterVolumeL () { static if (__VERSION__ > 2067) pragma(inline, true); return atomicLoad(sndMasterVolume)&0xff; }
  ubyte tflMasterVolumeR () { static if (__VERSION__ > 2067) pragma(inline, true); return (atomicLoad(sndMasterVolume)>>8)&0xff; }
  void tflMasterVolumeL (ubyte v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndMasterVolume, cast(ushort)((atomicLoad(sndMasterVolume)&0xff00)|v)); }
  void tflMasterVolumeR (ubyte v) { static if (__VERSION__ > 2067) pragma(inline, true); atomicStore(sndMasterVolume, cast(ushort)((atomicLoad(sndMasterVolume)&0x00ff)|(v<<8))); }

  // DON'T USE YET!
  // callback is called inside mixing thread and lock
  auto tflS16Callback () { return sndS16CB; }
  void tflS16Callback (void delegate (short[] buf) nothrow @nogc dg) { sndS16CB = dg; }
}


// ////////////////////////////////////////////////////////////////////////// //
public void tflShort2Float (in short[] input, float[] output) nothrow @trusted @nogc {
  if (output.length < input.length) assert(0, "invalid length");
  auto d = output.ptr;
  immutable float mul = 1.0f/32768.0f;
  auto src = input.ptr;
  foreach (immutable _; 0..input.length) *d++ = mul*(*src++);
}


// will not resize output
public void tflFloat2Short (in float[] input, short[] output) nothrow @trusted @nogc {
  auto s = input.ptr;
  auto d = output.ptr;
  /+ALIGN NOT WORKING YET: version(follin_use_sse) {
    auto blen = cast(uint)input.length;
    if (blen > 0) {
      //TODO: use aligned instructions
      align(64) __gshared float[4] mvol = 32768.0;
      float tmp;
      auto tmpptr = &tmp;
      asm nothrow @safe @nogc {
        mov       EAX,offsetof mvol[0]; // source
        //movntdqa  XMM4,[EAX]; // XMM4: multipliers (sse4.1)
        movaps    XMM4,[EAX];
        mov       EAX,[s]; // source
        mov       EBX,[d]; // dest
        mov       ECX,[blen];
        mov       EDX,ECX;
        shr       ECX,2;
        jz        skip4part;
        // process 4 floats per step
        align 8;
       finalloopmix:
        movups    XMM0,[EAX];
        mulps     XMM0,XMM4;    // mul by volume and shift
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;    // XMM1 now contains four int32 values
        packssdw  XMM1,XMM1;
        movq      [EBX],XMM1;   // four s16 == one double
      } else asm nothrow @safe @nogc {
        cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps   XMM5,XMM0;    // get high floats
        cvtps2pi  MM1,XMM5;     // MM1 now contains two high int32 values
        packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
        movq      [EBX],MM0;
      }
      asm nothrow @safe @nogc {
        add       EAX,16;
        add       EBX,8;
        dec       ECX;
        jnz       finalloopmix;
       skip4part:
        test      EDX,2;
        jz        skip2part;
        // do 2 floats
        movsd     XMM0,[EAX];   // one double == two floats
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;    // XMM1 now contains int32 values
        packssdw  XMM1,XMM1;
        movd      [EBX],XMM1;   // one float == two s16
      } else asm nothrow @safe @nogc {
        cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps   XMM5,XMM0;    // get high floats
        packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
        movd      [EBX],MM0;
      }
      asm nothrow @safe @nogc {
        add       EAX,8;
        add       EBX,4;
       skip2part:
        test      EDX,1;
        jz        skip1part;
        movss     XMM0,[EAX];
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;    // XMM1 now contains int32 values
        packssdw  XMM1,XMM1;
        mov       EAX,[tmpptr];
        movss     [EAX],XMM1;
      } else asm nothrow @safe @nogc {
        cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps   XMM5,XMM0;    // get high floats
        packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
        mov       EAX,[tmpptr]
        movss     [EAX],MM0;
      }
      asm nothrow @safe @nogc {
        mov       CX,[EAX];
        mov       [EBX],CX;
       skip1part:;
      }
      version(follin_use_sse2) {} else {
        asm nothrow @safe @nogc { emms; }
      }
    }
  } else +/{
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
bool tflKillChannel (const(char)[] name) { /*static if (__VERSION__ > 2067) pragma(inline, true);*/ return sndKillChan(name); }
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
version(follin_use_spinrw) import iv.follin.rwlock;


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
__gshared void delegate (short[] buf) nothrow @nogc sndS16CB;
__gshared short* sndbufMem = null; // chunk of memory for `sndbufptr`
__gshared float* sndrsbufMem = null; // chunk of memory for `sndrsbufptr`
__gshared float* sndrsbufptr = null; // aligned on 16 bytes for sse
__gshared float* tmprsbufMem = null; // chunk of memory for `tmprsbufptr`
__gshared float* tmprsbufptr = null; // here we'll collect floating point samples; aligned on 16 bytes for sse
__gshared float* tmpmonobufMem = null; // chunk of memory for `tmpmonobufptr`
__gshared float* tmpmonobufptr = null; // here we'll collect mono samples; aligned on 16 bytes for sse
__gshared Thread sndThread = null, sndMixThread = null;
shared ushort sndMasterVolume = 0xffff;
version(follin_use_spinrw) {
  shared TflRWLock sndMutexChanRW;
} else {
  __gshared ReadWriteMutex sndMutexChanRW;
}
__gshared Mutex mutexCondMixer;
__gshared Condition condMixerWait;

shared static this () {
  mutexCondMixer = new Mutex();
  condMixerWait = new Condition(mutexCondMixer);
  version(follin_use_spinrw) {} else sndMutexChanRW = new ReadWriteMutex(ReadWriteMutex.Policy.PREFER_WRITERS);
}


// ////////////////////////////////////////////////////////////////////////// //
private T* alignTo16(T) (T* ptr) {
  pragma(inline, true);
  if ((cast(usize)ptr)&0x0f) ptr = cast(T*)(((cast(usize)ptr)|0x0f)+1);
  return ptr;
}


void sndEngineInit () {
  static T* realloc(T) (ref T* ptr, uint len) {
    import core.stdc.stdlib: realloc;
    ptr = cast(T*)realloc(ptr, len*T.sizeof);
    if (ptr is null) assert(0, "Follin: out of memory");
    return alignTo16(ptr);
  }
  sndSamplesSize *= numchans; // frames to samples
  // buffers for final mixed sound
  sndbufptr = cast(short**)realloc(sndbufptr, (short*).sizeof*bufcount);
  if (sndbufptr is null) assert(0, "Follin: out of memory");
  sndbufptr[0] = realloc(sndbufMem, (sndSamplesSize+128)*bufcount);
  //{ import std.stdio; writefln("0x%08x 0x%08x 0x%08x", cast(uint)sndbufMem, cast(uint)sndbufptr[0], cast(uint)sndbufptr[1]); }
  foreach (immutable idx; 1..bufcount) sndbufptr[idx] = alignTo16(sndbufptr[idx-1]+sndSamplesSize+8);
  // buffer to collect stereo samples (float)
  tmprsbufptr = realloc(tmprsbufMem, sndSamplesSize+128);
  // buffer to collect mono samples (float)
  tmpmonobufptr = realloc(tmpmonobufMem, sndSamplesSize+128);
  // buffer to mix samples (float)
  sndrsbufptr = realloc(sndrsbufMem, sndSamplesSize+128);
  // init channels
  foreach (ref ch; chans) {
    import core.stdc.stdlib : malloc;
    ch.bufptr = realloc(ch.bufMem, sndSamplesSize+128);
    ch.bufpos = 0;
    if (!ch.srb.inited) {
      ch.lastquality = 8;
      ch.useCubic = false;
      ch.srb.setup(numchans, 44100, 48000, ch.lastquality);
    }
    ch.cub.reset();
    ch.prevsrate = ch.lastsrate = 44100;
  }
  /*
  scope(failure) {
    import core.stdc.stdlib : free;
    foreach (ref ch; chans) {
      if (ch.bufMem !is null) { free(ch.bufMem); ch.bufMem = null; }
    }
  }
  */
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
  float* bufMem; // chunk of memory for `buf`
  float* bufptr; // frame buffer, aligned to 16 bytes
  uint bufpos; // current position to write in `tmpbuf`/`buf`
  ubyte lastvolL, lastvolR; // latest volume
  int lastquality = 666; // <0: try cubic
  bool useCubic;
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
  foreach (immutable idx; 0..chans.length) {
    auto ch = chans.ptr+idx;
    if (ch.namelen == 0) break;
    if (ch.namehash == hash && ch.namelen == name.length && ch.name[0..ch.namelen] == name) return ch;
  }
  return null;
}


bool sndIsChanAlive (const(char)[] name) nothrow @trusted /*@nogc*/ {
  version(follin_use_spinrw) {
    sndMutexChanRW.readLock();
    auto ch = sndFindChanByName(name);
    sndMutexChanRW.readUnlock();
    return (ch !is null);
  } else {
    synchronized (sndMutexChanRW.reader) {
      if (auto ch = sndFindChanByName(name)) return true;
    }
    return false;
  }
}


TflChannel sndGetChanObj (const(char)[] name) nothrow @trusted /*@nogc*/ {
  version(follin_use_spinrw) {
    sndMutexChanRW.readLock();
    auto ch = sndFindChanByName(name);
    TflChannel res = (ch !is null ? ch.chan : null);
    sndMutexChanRW.readUnlock();
    return res;
  } else {
    synchronized (sndMutexChanRW.reader) {
      if (auto ch = sndFindChanByName(name)) return ch.chan;
    }
    return null;
  }
}


uint sndGetPlayTimeMsec (const(char)[] name) nothrow @trusted /*@nogc*/ {
  version(follin_use_spinrw) {
    sndMutexChanRW.readLock();
    if (auto ch = sndFindChanByName(name)) {
      auto res = cast(uint)(ch.playedFrames*1000/realSampleRate);
      sndMutexChanRW.readUnlock();
      return res;
    }
    sndMutexChanRW.readUnlock();
    return 0;
  } else {
    synchronized (sndMutexChanRW.reader) {
      if (auto ch = sndFindChanByName(name)) return cast(uint)(ch.playedFrames*1000/realSampleRate);
    }
    return 0;
  }
}


bool sndKillChan (const(char)[] name) {
  static bool doIt() (usize hash, const(char)[] name) {
    auto ch = chans.ptr;
    foreach (immutable idx; 0..chans.length) {
      if (ch.namelen == 0) break;
      if (ch.namehash == hash && ch.namelen == name.length && ch.name[0..ch.namelen] == name) {
        // kill this channel
        auto ochan = ch.chan;
        ch.chan = null;
        ch.bufpos = 0;
        ch.namelen = 0;
        ch.genFrames = 0;
        if (ochan !is null) ochan.discarded();
        packChannels();
        return true;
      }
      ++ch;
    }
    return false;
  }

  if (name.length == 0 || name.length > Channel.name.length) return false;
  auto hash = hashBuffer(name.ptr, name.length);
  version(follin_use_spinrw) {
    sndMutexChanRW.writeLock();
    auto res = doIt(hash, name);
    sndMutexChanRW.writeUnlock();
    return res;
  } else {
    synchronized (sndMutexChanRW.writer) return doIt(hash, name);
  }
}


bool sndAddChan (const(char)[] name, TflChannel chan, uint prio, TflChannel.Quality q) {
  char[64] tmpname;
  // build name if there's none
  if (name.length == 0) {
    if (chan is null) return false;
    usize pos = tmpname.length;
    ulong num = atomicOp!"+="(chanid, 1);
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

  bool doIt() () {
    // for lowest prio: prefer finished channel, then paused channel
    foreach (immutable idx; 0..chans.length) {
      auto ch = chans.ptr+idx;
      if (ch.namelen == 0) break; // last channel
      if (ch.namehash == hash && ch.namelen == name.length && ch.name[0..ch.namelen] == name) {
        replaceIdx = cast(int)idx;
        break;
      }
      lower.fixVictim!"lower"(*ch, prio, idx);
      same.fixVictim!"same"(*ch, prio, idx);
    }

    //{ import core.stdc.stdio; printf("replaceIdx(0)=%d; firstFreeChan=%u\n", replaceIdx, firstFreeChan); }

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

    //{ import core.stdc.stdio; printf("replaceIdx(1)=%d; firstFreeChan=%u\n", replaceIdx, firstFreeChan); }

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
      if (ch.lastquality < 0) ch.useCubic = ch.cub.setup(cast(float)ch.lastsrate/cast(float)realSampleRate); // don't use cubic
      version(follin_debug_resampler_type) if (ch.useCubic) { import core.stdc.stdio; printf("*** using cubic upsampler\n"); }
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
    return true;
  }

  version(follin_use_spinrw) {
    sndMutexChanRW.writeLock();
    auto res = doIt();
    sndMutexChanRW.writeUnlock();
    return res;
  } else {
    synchronized (sndMutexChanRW.writer) return doIt();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
bool sndGenerateBuffer () {
  //version(follin_use_sse) align(64) __gshared float[4] zeroes = 0; // dmd cannot into such aligns, alas
  version(follin_use_sse) {
    align(64) __gshared float[4+32] zeroesBuf = 0; // dmd cannot into such aligns, alas
    __gshared uint zeroesptr = 0;
    if (zeroesptr == 0) {
      zeroesptr = cast(uint)zeroesBuf.ptr;
      if (zeroesptr&0x3f) zeroesptr = (zeroesptr|0x3f)+1;
    }
    assert((zeroesptr&0x3f) == 0, "wtf?!");
  }
  //version(follin_use_sse) assert(((cast(size_t)zeroes.ptr)&0x3f) == 0, "wtf?!");

  static void killChan() (Channel* ch, ref bool channelsChanged) {
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

  enum doer = q{
    if (firstFreeChan > 0) {
      immutable bufsz = sndSamplesSize;
      // use SSE to clear buffer, if we can
      version(follin_use_sse) {
        asm nothrow @safe @nogc {
          mov       EAX,[sndrsbufptr];
          // ECX = (sndSamplesSize+3)/4
          mov       ECX,[sndSamplesSize];
          add       ECX,3;
          shr       ECX,2;
          //mov       EBX,offsetof zeroes[0];
          mov       EBX,[zeroesptr];
          //movntdqa  XMM0,[EBX]; // non-temporal, don't bring zeroes to cache (sse4.1)
          movaps    XMM0,[EBX];
          align 8;
         loopsseclear_x0:
          movaps    [EAX],XMM0; // dest is always aligned
          add       EAX,16;
          dec       ECX;
          jnz       loopsseclear_x0;
        }
      } else {
        sndrsbufptr[0..sndSamplesSize] = 0.0f;
      }
      //{ import core.stdc.stdio; printf("filling buffer %u\n", buf2fill); }
      foreach (immutable cidx; 0..chans.length) {
        auto ch = chans.ptr+cidx;
        if (ch.namelen == 0) break; // last channel
        uint rspos = 0; // current position in `sndrsbufptr`
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
            if (ch.lastquality < 0) ch.useCubic = ch.cub.setup(cast(float)srate/cast(float)realSampleRate); // don't use cubic
            version(follin_debug_resampler_type) { if (ch.useCubic) { import core.stdc.stdio; printf("*** using cubic upsampler\n"); } }
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
              fblen = ch.chan.fillFrames(ch.bufptr[ch.bufpos..bufsz]);
              if (fblen > len) fblen = 0; // something is very wrong with this channel
            } else {
              //FIXME mono
              fblen = ch.chan.fillFrames(tmpmonobufptr[0..len]);
              if (fblen > len) fblen = 0; // something is very wrong with this channel
              // expand
              auto s = tmpmonobufptr;
              auto d = ch.bufptr+ch.bufpos;
              foreach (immutable _; 0..fblen) {
                *d++ = *s;
                *d++ = *s++;
              }
            }
            //{ import core.stdc.stdio; printf("trying to get %u frames, got %u frames...\n", (bufsz-ch.bufpos)/2, fblen); }
            if (fblen == 0) { killChan(ch, channelsChanged); break; }
            // do volume
            auto bptr = ch.bufptr+ch.bufpos;
            ch.bufpos += fblen*2; // frames to samples
            if ((ch.lastvolL|ch.lastvolR) == 0) {
              // silent
              version(follin_use_sse) {
                asm nothrow @safe @nogc {
                  mov       EAX,[bptr];
                  //mov       EBX,offsetof zeroes[0];
                  mov       EBX,[zeroesptr];
                  //movntdqa XMM0,[EBX]; // non-temporal (sse4.1)
                  movaps    XMM0,[EBX];
                  mov       ECX,[fblen];
                  mov       EDX,8;
                  // is buffer aligned?
                  // process floats one-by-one if not
                 zerovol_unaligned:
                  test      EAX,0x0f;
                  jz        zerovol_aligned;
                  // using `movsd` brings some penalty here, but meh...
                  movsd     [EAX],XMM0; // store two floats (single double)
                  add       EAX,EDX;
                  dec       ECX;
                  jnz       zerovol_unaligned;
                  jmp       zerovol_done;
                 zerovol_aligned:
                  mov       EDX,16;
                  // ECX = (xlen+1)/2
                  inc       ECX;
                  shr       ECX,1;
                  align 8;
                 zerovol:
                  movaps    [EAX],XMM0;
                  add       EAX,EDX;
                  dec       ECX;
                  jnz       zerovol;
                 zerovol_done:;
               }
              } else {
                //ch.bufptr[ch.bufpos..bufsz] = 0.0f;
                bptr[0..fblen*2] = 0;
              }
            } else {
              version(follin_use_sse) {
                if (ch.lastvolL != 255 || ch.lastvolR != 255) {
                  align(64) __gshared float[4] mul = void;
                  mul[0] = mul[2] = (1.0f/255.0f)*cast(float)ch.lastvolL;
                  mul[1] = mul[3] = (1.0f/255.0f)*cast(float)ch.lastvolR;
                  asm nothrow @safe @nogc {
                    mov       EAX,[bptr];
                    mov       EBX,offsetof mul[0];
                    //movntdqa  XMM1,[EBX]; // non-temporal, don't bring volumes to cache (sse4.1)
                    movaps    XMM1,[EBX];
                    mov       ECX,[fblen];
                    mov       EDX,8;
                    // is buffer aligned?
                    // process floats one-by-one if not
                   addloopchvol_unaligned:
                    test      EAX,0x0f;
                    jz        addloopchvol_aligned;
                    // using `movsd` brings some penalty here, but meh...
                    movsd     XMM3,[EAX]; // load two floats (single double), clear others
                    mulps     XMM3,XMM1;
                    movsd     [EAX],XMM3; // store two floats (single double)
                    add       EAX,EDX;
                    dec       ECX;
                    jnz       addloopchvol_unaligned;
                    jmp       addloopchvol_done;
                   addloopchvol_aligned:
                    mov       EDX,16;
                    // ECX = (xlen+1)/2
                    inc       ECX;
                    shr       ECX,1;
                    align 8;
                   addloopchvol:
                    movaps    XMM0,[EAX];
                    mulps     XMM0,XMM1;
                    movaps    [EAX],XMM0;
                    add       EAX,EDX;
                    dec       ECX;
                    jnz       addloopchvol;
                   addloopchvol_done:;
                  }
                }
              } else {
                // do volume
                if (ch.lastvolL != 255 || ch.lastvolR != 255) {
                  immutable float mulL = (1.0f/255.0f)*cast(float)ch.lastvolL;
                  immutable float mulR = (1.0f/255.0f)*cast(float)ch.lastvolR;
                  foreach (immutable _; 0..fblen) {
                    *bptr++ *= mulL;
                    *bptr++ *= mulR;
                  }
                }
              } // version
            }
          } // while

          //{ import core.stdc.stdio; printf("have %u frames out of %u\n", ch.bufpos/2, bufsz/2); }
          // if we have any data in channel buffer, resample it
          uint blen = void, bsused = void;
          float* xss = void;
          auto xdd = sndrsbufptr+rspos;
          if (ch.lastsrate != realSampleRate) {
            // resample
            xss = tmprsbufptr+rspos;
            bsused = 0;
            blen = 0;
            while (bsused < ch.bufpos && rspos < bufsz) {
              srbdata.dataIn = ch.bufptr[bsused..ch.bufpos];
              srbdata.dataOut = tmprsbufptr[rspos..bufsz];
              //{ import core.stdc.stdio; printf("realSampleRate=%u; ch.lastsrate=%u\n", realSampleRate, ch.lastsrate); }
              err = (ch.useCubic ? ch.cub.process(srbdata) : ch.srb.process(srbdata));
              if (err) { killChan(ch, channelsChanged); break; }
              //{ import core.stdc.stdio; printf("inused: %u of %u; outused: %u of %u; bsused=%u\n", srbdata.inputSamplesUsed, cast(uint)srbdata.dataIn.length, srbdata.outputSamplesUsed, cast(uint)srbdata.dataOut.length, bsused); }
              bsused += srbdata.inputSamplesUsed;
              rspos += srbdata.outputSamplesUsed;
              blen += srbdata.outputSamplesUsed;
            }
          } else {
            // no need to resample, can use data as-is
            xss = ch.bufptr;
            bsused = blen = ch.bufpos;
            rspos += blen;
          }
          // if we have something to mix...
          if (blen) {
            // ...mix it; will clamp data later (this should theoretically improve mixing quality)
            ch.genFrames += blen/2;
            version(follin_use_sse) {
              asm nothrow @safe @nogc {
                mov     ECX,[blen];
                mov     EAX,[xdd];
                mov     EBX,[xss];
                // dest may be unaligned, check it
                test    EAX,0x0f;
                jz      diraddmix_daligned;
                // here we should process some floats to become aligned again
                mov     EDX,EAX;
                shr     EDX,2;
                and     EDX,0x03;
                // now DL is the number of unaligned floats
                jz      diraddmix_daligned;
                sub     ECX,EDX; // will check ECX later
                // we can do it faster by unrolling here, but meh...
                mov     DH,3;
               diraddmix_unaligned:
                movss   XMM2,[EBX]; // load single float, clear others
                movss   XMM3,[EAX]; // load single float, clear others
                addss   XMM3,XMM2;
                movss   [EAX],XMM3; // store single float
                add     EAX,4;
                add     EBX,4;
                inc     DL;
                and     DL,DH;
                jnz     diraddmix_unaligned;
                // ECX is actually really small, so check the high bit to detect overflow
                test    ECX,0x8000_0000U;
                jnz     diraddmix_done;
                // has something more to do
               diraddmix_daligned:
                // ECX=(blen+3)/4;
                mov     EDX,16; // memory increment
                add     ECX,3;
                shr     ECX,2;
                // is source aligned too?
                test    EBX,0x0f;
                jnz     diraddmix_bad;
                // good case: source is aligned
                align 8;
               diraddmix_good:
                movaps  XMM0,[EAX];
                movaps  XMM1,[EBX];
                addps   XMM0,XMM1;
                movaps  [EAX],XMM0;
                add     EAX,EDX;
                add     EBX,EDX;
                dec     ECX;
                jnz     diraddmix_good;
                jmp     diraddmix_done;
                // bad case: source is not aligned
                align 8;
               diraddmix_bad:
                movaps  XMM0,[EAX];
                movups  XMM1,[EBX];
                addps   XMM0,XMM1;
                movaps  [EAX],XMM0;
                add     EAX,EDX;
                add     EBX,EDX;
                dec     ECX;
                jnz     diraddmix_bad;
               diraddmix_done:;
              }
            } else {
              // no sse
              foreach (immutable _; 0..blen) *xdd++ += *xss++;
            }
          }

          // remove data from input buffer
          if (bsused >= ch.bufpos) {
            ch.bufpos = 0;
          } else if (bsused > 0) {
            import core.stdc.string : memmove;
            memmove(ch.bufptr, ch.bufptr+bsused, (ch.bufpos-bsused)*ch.bufptr[0].sizeof);
            ch.bufpos -= bsused;
          }

          // if this channel is paused or dead, do not try to process it again
          if (ch.chan is null || ch.chan.paused) {
            // try to squeeze last resampled data bytes out of it
            if (rspos < bufsz && ch.lastsrate != realSampleRate) {
              // here we can shift tmprsbufptr to get both buffers aligned
              blen = bufsz-rspos; // we don't need more than this
              xss = tmprsbufptr+(rspos&0x03); // if rspos is not aligned, shift xss
              srbdata.dataIn = null;
              srbdata.dataOut = xss[0..blen];
              err = (ch.useCubic ? ch.cub.process(srbdata) : ch.srb.process(srbdata));
              if (err) { killChan(ch, channelsChanged); break chmixloop; }
              if (ch.lastquality < 0 && ch.bufpos < bufsz) ch.cub.reset(); // it is fast
              if (srbdata.outputSamplesUsed) {
                // ...mix it; will clamp data later (this should theoretically improve mixing quality)
                xdd = sndrsbufptr+rspos;
                rspos += srbdata.outputSamplesUsed;
                version(follin_use_sse) {
                  blen = srbdata.outputSamplesUsed;
                  asm nothrow @safe @nogc {
                    mov     EAX,[xdd];
                    mov     EBX,[xss];
                    mov     ECX,[blen];
                    // dest may be unaligned, check it
                    test    EAX,0x0f;
                    jz      diraddmix2_daligned;
                    // here we should process some floats to become aligned again
                    mov     EDX,EAX;
                    shr     EDX,2;
                    and     EDX,0x03;
                    // now DL is the number of unaligned floats
                    jz      diraddmix2_daligned;
                    sub     ECX,EDX; // will check ECX later
                    // we can do it faster by unrolling here, but meh...
                    mov     DH,3;
                   diraddmix2_unaligned:
                    movss   XMM2,[EBX]; // load single float, clear others
                    movss   XMM3,[EAX]; // load single float, clear others
                    addss   XMM3,XMM2;
                    movss   [EAX],XMM3; // store single float
                    add     EAX,4;
                    add     EBX,4;
                    inc     DL;
                    and     DL,DH;
                    jnz     diraddmix2_unaligned;
                    // ECX is actually really small, so check the high bit to detect overflow
                    test    ECX,0x8000_0000U;
                    jnz     diraddmix2_done;
                    // has something more to do
                   diraddmix2_daligned:
                    // ECX=(blen+3)/4;
                    mov     EDX,16; // memory increment
                    add     ECX,3;
                    shr     ECX,2;
                    // source is aligned too
                    align 8;
                   diraddmix2_good:
                    movaps  XMM0,[EAX];
                    movaps  XMM1,[EBX];
                    addps   XMM0,XMM1;
                    movaps  [EAX],XMM0;
                    add     EAX,EDX;
                    add     EBX,EDX;
                    dec     ECX;
                    jnz     diraddmix2_good;
                   diraddmix2_done:;
                  }
                } else {
                  foreach (immutable _; 0..srbdata.outputSamplesUsed) *xdd++ += *xss++;
                }
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
  }; // doer

  version(follin_use_spinrw) {
    sndMutexChanRW.writeLock();
    mixin(doer);
    sndMutexChanRW.writeUnlock();
  } else {
    synchronized (sndMutexChanRW.writer) { mixin(doer); }
  }

  // do final converting
  auto dp = sndbufptr[buf2fill];
  if (wasAtLeastOne) {
    // something is playing, mix it
    auto mvol = atomicLoad(sndMasterVolume);
    if (mvol == 0) {
      version(follin_use_sse) {
        asm nothrow @safe @nogc {
          mov      ECX,[sndSamplesSize];
          // (sndSamplesSize+7)/8 -- destination is s16, not float
          add       ECX,7;
          shr       ECX,3;
          mov       EAX,[dp]; // dest, aligned
          //mov       EBX,offsetof zeroes[0]; // lucky me, floating zero is s16 zero too
          mov       EBX,[zeroesptr]; // lucky me, floating zero is s16 zero too
          //movntdqa  XMM0,[EBX]; // non-temporal, don't bring zeroes to cache (sse4.1)
          movaps    XMM0,[EBX];
          mov       EDX,16;
          align 8;
         lastzfill_loop:
          movaps    [EAX],XMM0;
          add       EAX,EDX;
          dec       ECX;
          jnz       lastzfill_loop;
        }
      } else {
        dp[0..sndSamplesSize] = 0;
      }
    } else {
      auto mvolL = mvol&0xff;
      auto mvolR = (mvol>>8)&0xff;
      auto src = sndrsbufptr;
      version(follin_use_sse) {
        //align(64) __gshared float[4] fmin4 = -32768.0;
        //align(64) __gshared float[4] fmax4 = 32767.0;
        align(64) __gshared float[4] mvolf = void;
        mvolf[0] = mvolf[2] = (32768.0/255.0f)*cast(float)mvolL;
        mvolf[1] = mvolf[3] = (32768.0/255.0f)*cast(float)mvolR;
        auto blen = (sndSamplesSize+3)/4;
        asm nothrow @safe @nogc {
          //mov      EAX,offsetof fmin4[0];
          //movntdqa XMM2,[EAX]; // XMM2: min values
          //mov      EAX,offsetof fmax4[0];
          //movntdqa XMM3,[EAX]; // XMM3: max values
          mov       EAX,offsetof mvolf[0]; // source
          //movntdqa  XMM4,[EAX]; // XMM4: multipliers (sse4.1)
          movaps    XMM4,[EAX];
          // source and dest are aligned
          mov       EAX,[src]; // source
          mov       EBX,[dp]; // dest
          mov       ECX,[blen];
          mov       EDX,16;
          align 8;
         finalloopmix:
          movaps    XMM0,[EAX];
          mulps     XMM0,XMM4;    // mul by volume and shift
          //maxps     XMM0,XMM2;    // clip lower
          //minps     XMM0,XMM3;    // clip upper
        }
        version(follin_use_sse2) asm nothrow @safe @nogc {
          cvttps2dq XMM1,XMM0;  // XMM1 now contains four int32 values
          packssdw  XMM1,XMM1;
          movq      [EBX],XMM1;
        } else asm nothrow @safe @nogc {
          cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
          movhlps   XMM5,XMM0;    // get high floats
          cvtps2pi  MM1,XMM5;     // MM1 now contains two high int32 values
          packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
          movq      [EBX],MM0;
        }
        asm nothrow @safe @nogc {
          add       EAX,EDX;
          add       EBX,8;
          dec       ECX;
          jnz       finalloopmix;
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
    dp[0..sndSamplesSize] = 0;
  }
  if (sndS16CB !is null) sndS16CB(dp[0..sndSamplesSize]);
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
        enum doer = q{
          if (firstFreeChan > 0) {
            foreach (immutable idx; 0..chans.length) {
              auto ch = chans.ptr+idx;
              if (ch.namelen == 0) break; // last channel
              //{ import core.stdc.stdio; printf("pf: %u; gf: %u\n", cast(uint)ch.playedFrames, cast(uint)ch.genFrames); }
              if (ch.playedFrames < ch.genFrames) {
                ch.playedFrames += sndSamplesSize/2;
                if (ch.playedFrames > ch.genFrames) ch.playedFrames = ch.genFrames;
              }
            }
          }
        }; // doer
        version(follin_use_spinrw) {
          sndMutexChanRW.writeLock();
          mixin(doer);
          sndMutexChanRW.writeUnlock();
        } else {
          synchronized (sndMutexChanRW.writer) { mixin(doer); }
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
      /*
      foreach (ref ch; chans) {
        import core.stdc.stdlib : free;
        ch.namelen = 0;
        ch.chan = null;
        if (ch.bufMem !is null) { free(ch.bufMem); ch.bufMem = null; }
        ch.srb.deinit();
      }
      */
      atomicStore(initialized, false);
    }
  }
  atomicStore(sndWantShutdown, false);
  atomicStore(sndSafeToShutdown0, false);
  atomicStore(sndSafeToShutdown1, false);
}
