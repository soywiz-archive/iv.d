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
// DooM2d digital music
module iv.follin.synth.dmm;

import iv.follin.engine : TflChannel;

static if (__traits(compiles, () { import iv.stream; })) {
import iv.stream;


// ////////////////////////////////////////////////////////////////////////// //
version = dmm_use_sse;
version = dmm_ignore_module_loops;
//version = dmm_complex_cubic;


// ////////////////////////////////////////////////////////////////////////// //
class DmmInstrument {
  uint srate;
  uint loopstart;
  uint loopend; // after last byte
  float[] data;
  ubyte[] s8data;
  string name;

  this (string fname=null, string aname=null) {
    name = aname;
    if (fname.length) {
      import std.stdio : File;
      load(File(fname), false);
    }
  }

  @property bool hasloop () const pure nothrow @safe @nogc { return (loopstart < loopend); }

  void saveDMI2(ST) (auto ref ST st) if (isWriteableStream!ST) {
    st.rawWriteExact("DMI2");
    st.writeNum!ubyte(0); // version
    st.writeNum!ubyte(cast(ubyte)name.length);
    st.rawWriteExact(name[0..cast(ubyte)name.length]);
    st.writeNum!ushort(cast(ushort)s8data.length);
    st.writeNum!ushort(cast(ushort)srate);
    st.writeNum!ushort(cast(ushort)loopstart);
    st.writeNum!ushort(cast(ushort)loopend);
    st.rawWriteExact(s8data[]);
  }

  void loadDMI2(ST) (auto ref ST st) if (isReadableStream!ST) {
    char[4] sign;
    st.rawRead(sign[]);
    if (sign != "DMI2") throw new Exception("invalid DMI2 instrument signature");
    if (st.readNum!ubyte() != 0) throw new Exception("invalid DMI2 instrument version");
    // name
    uint nlen = st.readNum!ubyte();
    if (nlen > 0) {
      import std.exception : assumeUnique;
      auto nm = new char[](nlen);
      st.rawReadExact(nm[]);
      name = nm.assumeUnique;
    } else {
      name = "";
    }
    // other data
    load(st, true);
  }

  void loadDMI(ST) (auto ref ST st, string aname="") if (isReadableStream!ST) {
    name = aname;
    load(st, true);
  }

private:
  void load(ST) (auto ref ST st, bool asDMI2) if (isReadableStream!ST) {
    if (name.length > 255) name = name[0..255];
    uint lenbytes = st.readNum!ushort();
    srate = st.readNum!ushort();
    loopstart = st.readNum!ushort();
    if (asDMI2) {
      loopend = st.readNum!ushort();
    } else {
      uint looplen = st.readNum!ushort();
      loopend = loopstart+looplen;
    }
    //{ import core.stdc.stdio; printf("len=%u; srate=%u; loopstart=%u; looplen=%u\n", lenbytes, srate, loopstart, looplenbyte); }
    if (lenbytes < 1) throw new Exception("invalid instrument length");
    s8data.length = lenbytes;
    s8data = st.rawRead(s8data[]);
    if (s8data.length == 0) throw new Exception("invalid instrument data");
    if (s8data.length < lenbytes) { import core.stdc.stdio; printf("  len=%u; reallen=%u\n", lenbytes, cast(uint)s8data.length); }
    // convert to float
    data.length = s8data.length;
    foreach (immutable idx, byte b; s8data) data.ptr[idx] = (1.0f/128.0f)*b;
    // fix looping values
    if (loopend > s8data.length) loopend = cast(uint)s8data.length;
    if (loopstart >= s8data.length || loopstart >= loopend) { loopstart = loopend = 0; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// this walks over the data array, taking into account looping, and
// returning interpolated values; note that step>1 will sound awful
private struct InterWalker {
public:
nothrow @trusted @nogc:
  // starting position (will be changed for looping)
  uint spos; // used for looping
  // starting position (will be changed for looping)
  float epos; // used for looping; position AFTER the last element
  // current position
  float curpos;
  // how long we should move on one step?
  float step;
  // are we currently in loop (false: no, it's first time we going thru it all
  bool inloop;
  bool hasloop;
  uint loopstart, loopend; // positions
  float[] data;
  float lastseenbyte = 0.0f; // just4fun; you won't hear the difference

  void setup (DmmInstrument ai, float astep) {
    if (ai !is null) {
      data = ai.data;
      spos = 0;
      epos = cast(uint)data.length;
      curpos = 0;
      step = astep;
      inloop = false;
      hasloop = ai.hasloop;
      if (hasloop) {
        loopstart = ai.loopstart;
        loopend = ai.loopend;
        // sanity check
        if (loopend > cast(uint)data.length) loopend = cast(uint)data.length;
        hasloop = (loopend > loopstart && loopend-loopstart >= 2 && loopstart < cast(uint)data.length);
        if (hasloop) spos = loopstart;
      }
    } else {
      spos = spos.max;
      data = null; // don't anchor it
    }
    //{ import core.stdc.stdio; printf("setup: step=%f\n", step); }
  }

  @property /*const pure*/ {
    bool empty () const pure { pragma(inline, true); return (spos == spos.max); }

    // this will do cubic interpolation
    // valid only if the range is not empty
    float front () {
      //version(dmm_complex_cubic) {} else pragma(inline, true);
      auto ipos = cast(uint)curpos;
      // interpolate between y1 and y2
      immutable float mu = curpos-ipos; // how far we are moved from y1 to y2
      //{ import core.stdc.stdio; printf("front at %i (%f)\n", ipos, mu); }
      immutable float mu2 = mu*mu; // wow
      immutable dlen = cast(uint)data.length;
      auto d = data.ptr+ipos;
      float y0 = void, y1 = d[0], y2 = void, y3 = void;
      // get the points; the process is complicated by looping
      if (!hasloop) {
        // no looping, easy deal
        y0 = (ipos > lastseenbyte ? d[-1] : d[0]); // we can do better at the start, of course
        y2 = (ipos+1 < dlen ? d[1] : 0);
        y3 = (ipos+2 < dlen ? d[2] : 0);
      } else if (!inloop) {
        // has looping, but we aren't in the loop yet
        y0 = (ipos > lastseenbyte ? d[-1] : d[0]); // we can do better at the start, of course
        y2 = (ipos+1 < dlen ? d[1] : data.ptr[loopstart]);
        y3 = (ipos+2 < dlen ? d[2] : data.ptr[loopstart+(ipos+2-dlen)]);
      } else {
        // has looping, and we are in the loop
        y0 = (ipos > loopstart ? d[-1] : data.ptr[loopend-1]);
        y2 = (ipos+1 < loopend ? d[1] : data.ptr[loopstart]);
        y3 = (ipos+2 < loopend ? d[2] : data.ptr[loopstart+(ipos+2-dlen)]);
      }
      lastseenbyte = y2;
      version(dmm_complex_cubic) {
        immutable float z0 = 0.5*y3;
        immutable float z1 = 0.5*y0;
        immutable float a0 = 1.5*y1-z1-1.5*y2+z0;
        immutable float a1 = y0-2.5*y1+2*y2-z0;
        immutable float a2 = 0.5*y2-z1;
      } else {
        immutable float a0 = y3-y2-y0+y1;
        immutable float a1 = y0-y1-a0;
        immutable float a2 = y2-y0;
      }
      return a0*mu*mu2+a1*mu2+a2*mu+y1;
    }
  }
  void popFront () {
    if ((curpos += step) >= epos) {
      if (!hasloop) { spos = spos.max; return; } // this is the end, my only friend
      // alas, we moved out of data
      float stover = cast(float)epos-curpos; // how much?
      // fix bounds
      if (!inloop) { epos = loopend; inloop = true; }
      // the following can happen if `step` is too big
      if ((curpos = spos+stover) >= epos) {
        // just carry over a rational part here
        curpos = cast(float)(loopstart+cast(int)curpos%(loopend-loopstart))+(curpos-cast(int)curpos);
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// instrument mixer
private struct IMixer {
nothrow @trusted @nogc:
private:
  float destRateF = 48000;
  uint xdestRate = 48000;
  uint xtickLen = 48000/64;

public:
  @property const pure nothrow @safe @nogc {
    uint destRate () { pragma(inline, true); return xdestRate; }
    uint samplesInTick () { pragma(inline, true); return xtickLen; }
  }

  void setupDestRate (uint srate) nothrow @safe @nogc {
    if (srate < 64 || srate > 96000) assert(0, "DMM: invalid destination sample rate");
    xdestRate = srate;
    destRateF = srate;
    xtickLen = srate/64+(srate%64 >= 32 ? 1 : 0);
    assert(xtickLen >= 32 && xtickLen <= 8192);
    step = fdrate/destRateF;
  }

private:
  DmmInstrument i;
  InterWalker w;
  float step = 1.0f;
  float volume = 0.0f;
  float fdrate = 48000.0f;
  bool xsilent = true;
  bool cantsound = true;

public:
  void setNote() (ubyte n) {
    import std.math : pow;
    if (i !is null) {
      fdrate = cast(float)pow(2.0f, cast(float)(cast(int)n-24)/12.0f)*cast(float)i.srate;
      step = fdrate/destRateF;
      //{ import core.stdc.stdio; printf("new rate for note %u is %u; stepping is %f\n", cast(uint)n, cast(int)fdrate, step); }
      cantsound = (/*step < 0.00001f ||*/ step >= i.data.length/2); // you won't hear anything interesting anyway
    } else {
      cantsound = true;
    }
    xsilent = false;
    if (!cantsound) w.setup(i, step);
  }

  void setSilent () { xsilent = true; }
  @property bool silent () const pure { return (silent || cantsound); }

  void setVolume() (ubyte v) {
    // minus ~30% of volume, just4fun
    volume = (v == 0 ? 0.0f : (1.0f/(127.0f+32.0f))*(v&0x7f));
    xsilent = (volume <= 0.00001f);
  }

  void changeInstrument() (DmmInstrument newi) { i = newi; }

  // mix one tick, no clipping; return `false` if nothing was done
  bool mixTick() (float* outdata) {
    if (xsilent || cantsound) { w.lastseenbyte = 0.0f; return false; } // you won't hear it anyway ;-)
    foreach (immutable _; 0..samplesInTick) {
      if (w.empty) { w.lastseenbyte = 0.0f; return (_ > 0); }
      *outdata++ += w.front*volume;
      w.popFront();
    }
    return true;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
final class DmmModule {
private:
  align(1) static struct Event {
  align(1):
    ubyte note;
    ubyte instrument;
    ubyte volume; // or sfx if bit 7 is set
    ubyte duration; // in 1/64 of second
  }

  string instrumentBaseDir;

  Event[] events;
  ubyte[] sequences;
  DmmInstrument[] instruments;
  uint[8][] patStartOfs; // in `events`
  float[] tickbuf;
  uint patCount;
  ubyte ver = 255; // 0 or 1

  static struct Chan {
  nothrow @safe @nogc:
    IMixer mix;
    uint eofs = uint.max; // offset in `events`, or `uint.max` to "no play"
    int ticksLeft;

    // doesn't clear mixer instrument
    void clearAndMute () { eofs = uint.max; ticksLeft = 0; mix.setSilent(); }
    void dummyOut () { eofs = uint.max; ticksLeft = ticksLeft.max; }
  }
  Chan[8] chans;
  uint nextseq;
  uint songLenMsecs;

public:
  this (string fname, string instrumentBaseDir=null) {
    import std.path;
    tickbuf.length = chans[0].mix.samplesInTick+8; // +dummy values for sse
    scope(failure) ver = 255;
    import std.stdio : File;
    loadIntr(instrumentBaseDir, File(fname));
  }

  ubyte getVersion () const pure nothrow @safe @nogc { pragma(inline, true); return ver; }

  @property uint samplesInTick () const nothrow @safe @nogc { pragma(inline, true); return chans.ptr[0].mix.samplesInTick; }
  @property inout(float)[] soundBuffer () inout pure nothrow @safe @nogc { pragma(inline, true); return tickbuf[0..chans.ptr[0].mix.samplesInTick]; }

  @property uint destRate () const nothrow @safe @nogc { pragma(inline, true); return chans.ptr[0].mix.destRate; }
  @property void destRate (uint srate) nothrow @safe {
    if (srate != chans.ptr[0].mix.destRate) {
      foreach (ref ch; chans) ch.mix.setupDestRate(srate);
      tickbuf.length = chans[0].mix.samplesInTick+8; // +dummy values for sse
    }
  }

  @property uint songLengthMsecs () const pure nothrow @safe @nogc { pragma(inline, true); return songLenMsecs; }

  void saveDM2(ST) (auto ref ST st) if (isWriteableStream!ST) {
    st.rawWriteExact("DMM\0");
    st.writeNum!ubyte(1); // version
    st.writeNum!ubyte(cast(ubyte)patCount);
    st.writeNum!ushort(cast(ushort)events.length);
    // write events
    foreach (ref Event ev; events) {
      st.writeNum!ubyte(ev.note);
      st.writeNum!ubyte(ev.instrument);
      st.writeNum!ubyte(ev.volume);
      st.writeNum!ubyte(ev.duration);
    }
    // write sequences
    st.writeNum!ubyte(cast(ubyte)sequences.length);
    st.rawWriteExact(sequences[]);
    // write instruments
    st.writeNum!ubyte(cast(ubyte)instruments.length);
    foreach (DmmInstrument i; instruments) i.saveDMI2(st);
  }

private:
  uint calcSongLengthMsecs () {
    // calculate song length in ticks
    uint ticks = 0;
    uint seq = 0;
    uint[8] pofs = void;
    int[8] durs = void;
    while (seq < sequences.length) {
      // start new sequence
      uint pnum = void;
      pnum = sequences[seq++];
      if (pnum == 255) {
        // jump
        if (seq >= sequences.length) break;
        pnum = sequences[seq];
        if (pnum <= seq) {
          // jump back: it's probably a loop
          ++seq;
        } else {
          seq = pnum;
        }
        continue;
      }
      // setup events
      if (pnum >= patStartOfs.length) break;
      // setup positions
      foreach (immutable cidx; 0..8) pofs[cidx] = patStartOfs[pnum][cidx];
      durs[] = 0; // nothing was set yet
      bool hasAliveChannel = void;
      // process pattern
      do {
        hasAliveChannel = false;
        foreach (immutable cidx; 0..8) {
          for (;;) {
            if (--durs[cidx] >= 0) { hasAliveChannel = true; break; } // still playing
            durs[cidx] = 0;
            uint ofs = pofs[cidx]++;
            if (ofs >= events.length) { pofs[cidx] = uint.max; break; } // this channel is dead
            auto ev = events.ptr+ofs;
            if (ev.volume == 0x80) { pofs[cidx] = uint.max; break; } // this channel is dead
            if (ev.note == 0xfe) {
              // pause
              durs[cidx] = ev.duration+256*ev.instrument;
              if (durs[cidx] == 0) {
                import core.stdc.stdio;
                fprintf(stderr, "DMM: long pause of length 0!\n");
                durs[cidx] = ushort.max+1;
              }
            } else {
              // duration
              durs[cidx] = (ev.duration ? ev.duration : 256);
            }
          }
        }
        if (hasAliveChannel) ++ticks;
      } while (hasAliveChannel);
    }
    return ticks*1000/64; // milliseconds
  }

  // setup sequence, move to next sequence; return `false` is there are no more sequences
  bool setupSeq() () {
    // stop instrument playback, if there was any
    foreach (ref Chan ch; chans) ch.clearAndMute();
    uint pnum = void;
    for (;;) {
      if (nextseq >= sequences.length) return false;
      if ((pnum = sequences[nextseq++]) != 255) break;
      // jump, check for infinite looping
      if (nextseq >= sequences.length) return false;
      version(dmm_ignore_module_loops) {
        // ignore backward jumps
        if (sequences[nextseq] <= nextseq) {
          { import core.stdc.stdio; printf("ignored backwards jump to %u from %u\n", cast(uint)sequences[nextseq], nextseq-1); }
          //nextseq = nextseq.max;
          //return false;
          ++nextseq;
        }
      } else {
        nextseq = sequences[nextseq];
      }
    }
    if (pnum >= patStartOfs.length) { nextseq = nextseq.max; return false; }
    //{ import core.stdc.stdio; printf("sequence: %u of %u\n", cast(uint)nextseq, cast(uint)sequences.length); }
    // setup positions
    foreach (immutable cidx, ref Chan ch; chans) ch.eofs = patStartOfs[pnum][cidx];
    return true;
  }

  // `false`: pattern complete
  bool processEvent() (uint cidx) {
    auto ch = &chans[cidx];
    for (;;) {
      if (ch.eofs == uint.max) return false; // this channel is no more
      if (--ch.ticksLeft >= 0) return true; // playing something
      ch.ticksLeft = 0;
      uint ofs = ch.eofs++; // get offset, move to next one
      if (ofs >= events.length || events.ptr[ofs].volume == 0x80) {
        // no more
        //{ import core.stdc.stdio; printf("channel #%u is no more\n", cidx); }
        ch.dummyOut();
        return false;
      }
      auto ev = events.ptr+ofs;
      //{ import core.stdc.stdio; printf("channel #%u event: n=%u; i=%u; v=%u; d=%u\n", cidx, ev.note, ev.instrument, ev.volume, ev.duration); }
      if (ev.note == 0xfe) {
        // pause
        ch.ticksLeft = ev.duration+256*ev.instrument;
        if (ch.ticksLeft == 0) {
          import core.stdc.stdio;
          fprintf(stderr, "DMM: long pause of length 0!\n");
          ch.ticksLeft = ushort.max+1;
        }
        ch.mix.setSilent();
      } else {
        // change instrument
        if (ev.instrument > 0) ch.mix.changeInstrument(ev.instrument <= instruments.length ? instruments[ev.instrument-1] : null);
        // new note (0xfe: pause; 0xff: don't change note)
        if (ev.note < 0xfe) ch.mix.setNote(ev.note);
        // change volume
        ch.mix.setVolume(ev.volume);
        // duration
        ch.ticksLeft = (ev.duration ? ev.duration : 256);
      }
    }
  }

  // return `false` is no channel is playing
  bool mixChansTick() () {
    tickbuf[] = 0;
    for (;;) {
      bool someChanIsActive = false;
      bool needClip = false;
      for (;;) {
        foreach (immutable cidx; 0..chans.length) {
          auto ch = chans.ptr+cidx;
          if (processEvent(cidx)) someChanIsActive = true;
          if (ch.mix.mixTick(tickbuf.ptr)) needClip = true; // if anything was mixed, set "clip flag"
        }
        if (!someChanIsActive) {
          // not a single channel is active, move to the next pattern
          if (!setupSeq) return false;
          // repeat
          continue;
        }
        // if we did something, clip it
        if (needClip) {
          auto tb = tickbuf.ptr;
          version(dmm_use_sse) {
            __gshared /*immutable*/ float[4] fmin4 = -1.0;
            __gshared /*immutable*/ float[4] fmax4 = 1.0;
            auto blen = cast(uint)(tickbuf.length+3)/4;
            asm nothrow @safe @nogc {
              mov      EAX,offsetof fmin4[0];
              movups   XMM2,[EAX]; // XMM2: min values
              mov      EAX,offsetof fmax4[0];
              movups   XMM3,[EAX]; // XMM3: max values
              mov      EAX,[tb]; // source
              mov      ECX,[blen];
              align 8;
             cliploop:
              movups   XMM0,[EAX];
              maxps    XMM0,XMM2;    // clip lower
              minps    XMM0,XMM3;    // clip upper
              movups   [EAX],XMM0;
              add      EAX,16;
              dec      ECX;
              jnz      cliploop;
            }
          } else {
            foreach (immutable _; 0..tickbuf.length) {
              if (*tb < -1.0f) *tb = -1.0f; else if (*tb > 1.0f) *tb = 1.0f;
              ++tb;
            }
          }
        }
        return true;
      }
    }
  }

  void loadIntr(ST) (string basepath, auto ref ST st) if (isReadableStream!ST) {
    char[4] sign;
    st.rawReadExact(sign[]);
    if (sign != "DMM\0") throw new Exception("not a DMM module");
    ver = st.readNum!ubyte();
    if (ver > 1) throw new Exception("invalid DMM version");
    patCount = st.readNum!ubyte();
    uint eventCount = st.readNum!ushort();
    if (patCount == 0) { import core.stdc.stdio; printf("no patterns in DMM\n"); }
    if (eventCount == 0) { import core.stdc.stdio; printf("no events in DMM\n"); }
    events.length = eventCount;
    if (events.length) st.rawReadExact(events[]);
    uint seqCount = st.readNum!ubyte();
    if (seqCount == 0) { import core.stdc.stdio; printf("no sequences in DMM\n"); }
    sequences.length = seqCount;
    if (sequences.length) st.rawReadExact(sequences[]);
    //{ import std.stdio; writeln(sequences[]); }
    uint instrCount = st.readNum!ubyte();

    bool isInstrumentUsed() (uint iidx) {
      foreach (ref ev; events) {
        if (ev.volume == 0x80 || ev.note == 255) continue;
        if (ev.instrument == iidx+1) return true;
      }
      return false;
    }

    if (ver == 0) {
      auto imap = new uint[](instrCount); // instrument map
      instruments.length = 0;
      string[] inames;
      foreach (immutable idx; 0..instrCount) {
        char[13] namebuf = 0;
        // read
        auto type = st.readNum!ubyte();
        st.rawReadExact(namebuf[]);
        auto res = st.readNum!ushort();
        // fix name
        char[] name = namebuf[];
        foreach (immutable f; 0..namebuf.length) if (namebuf[f] == 0) { name = name[0..f]; break; }
        foreach (ref char ch; name) {
          if (ch <= ' ' || ch >= 127 || ch == '-') ch = '_';
          if (ch >= 'A' && ch <= 'Z') ch += 32;
        }
        if (name.length >= 4 && name[$-4..$] == ".dmi") name = name[0..$-4];
        while (name.length && name[$-1] == '_') name = name[0..$-1];
        if (name.length) {
          if (isInstrumentUsed(idx)) {
            { import core.stdc.stdio; printf("%2u: [%.*s]\n", cast(uint)idx, cast(uint)name.length, name.ptr); }
            // check if we already loaded this instrument
            uint ii = void; // index to remap
            for (ii = 0; ii < inames.length && inames[ii] != name; ++ii) {}
            if (ii >= inames.length) {
              import std.path;
              ii = cast(uint)instruments.length;
              DmmInstrument im = new DmmInstrument(buildPath(basepath, "dmi", name.idup~".dmi"), name.idup);
              instruments ~= im;
            }
            imap[idx] = ii+1;
          } else {
            { import core.stdc.stdio; printf("%2u: [%.*s] -- unused\n", cast(uint)idx, cast(uint)name.length, name.ptr); }
            imap[idx] = 0; // no such instrument
          }
        } else {
          { import core.stdc.stdio; printf("%2u: [%.*s]\n", cast(uint)idx, cast(uint)name.length, name.ptr); }
          imap[idx] = 0; // no such instrument
        }
      }
      // remap instruments
      foreach (ref Event ev; events) {
        if (ev.volume == 0x80) {
          ev.note = ev.instrument = ev.duration = 0;
        } else if (ev.note == 0xfe) {
          ev.volume = 0;
        } else if (ev.instrument) {
          if (ev.instrument > imap.length) {
            { import core.stdc.stdio; printf("instrument %u remaped to nothing\n", cast(uint)ev.instrument); }
            ev.instrument = 0; // no such instrument
          } else {
            auto ni = imap[ev.instrument-1];
            if (ev.instrument != ni) {
              //{ import core.stdc.stdio; printf("instrument %u remaped to %u\n", cast(uint)ev.instrument, ni); }
              ev.instrument = cast(ubyte)ni;
            }
          }
        }
      }
    } else {
      // version 1, with instruments
      instruments.length = instrCount;
      //{ import core.stdc.stdio; printf("instruments: %u\n", instrCount); }
      foreach (immutable idx; 0..instrCount) {
        auto i = new DmmInstrument();
        i.loadDMI2(st);
        instruments[idx] = i;
        { import core.stdc.stdio; printf("%2u: [%.*s]\n", cast(uint)idx, cast(uint)i.name.length, i.name.ptr); }
      }
    }
    // find pattern offsets
    patStartOfs.length = patCount;
    uint cpos = 0;
    foreach (immutable pidx; 0..patCount) {
      foreach (immutable cidx, ref ps; patStartOfs[pidx]) {
        //{ import std.stdio; writeln("max=", events.length, "; p", pidx, "c", cidx, ": ", cpos); }
        ps = cpos;
        // next channel
        while (cpos < events.length && events[cpos].volume != 0x80) ++cpos;
        if (cpos < events.length) ++cpos;
      }
    }
    if (patCount > 0 && sequences.length == 0) {
      // create sequences for all existing patterns
      sequences.length = patCount;
      if (sequences.length > 254) sequences.length = 254;
      foreach (uint idx; 0..patCount) sequences[idx] = cast(ubyte)idx;
    }
    songLenMsecs = calcSongLengthMsecs();
    nextseq = 0;
    foreach (ref Chan ch; chans) ch.clearAndMute();
    setupSeq();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class DmmChannel : TflChannel {
  DmmModule mod;
  uint smppos;

  this (DmmModule amod) {
    sampleRate = (amod !is null ? amod.destRate : 48000);
    stereo = false;
    volume = 128;
    mod = amod;
    smppos = uint.max-1;
  }

  override uint fillFrames (float[] buf) nothrow @nogc {
    //buf[] = 0; return buf.length;
    //{ import core.stdc.stdio; printf("frm=%u\n", buf.length); }
    if (mod is null) return 0;
    auto spt = mod.samplesInTick;
    uint count = 0;
    while (count < buf.length) {
      // do we want a new sample?
      if (smppos >= spt) {
        if (!mod.mixChansTick()) { mod = null; break; } // no more samples
        smppos = 0;
      }
      uint toget = spt-smppos;
      if (toget > buf.length-count) toget = cast(uint)(buf.length-count);
      buf.ptr[count..count+toget] = mod.soundBuffer.ptr[smppos..smppos+toget];
      count += toget;
      smppos += toget;
    }
    return count; // return number of mono frames
  }
}
}
