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
module iv.follin.synth.sfxr;

import iv.follin.engine : TflChannel;

static if (__traits(compiles, () { import iv.stream; })) {
import iv.stream;


// ////////////////////////////////////////////////////////////////////////// //
public struct Sfxr {
  // seed must not be 0
  /*
  static ulong nextrand64 (ref ulong seed) nothrow @trusted @nogc {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (seed == 0) seed = 0x29a; // arbitrary number
    seed ^= seed>>12; // a
    seed ^= seed<<25; // b
    seed ^= seed>>27; // c
    return seed*0x2545f4914f6cdd1dUL;
  }

  static uint nextrand32 (ref ulong seed) nothrow @trusted @nogc {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (seed == 0) seed = 0x29a; // arbitrary number
    seed ^= seed>>12; // a
    seed ^= seed<<25; // b
    seed ^= seed>>27; // c
    return (seed*0x2545f4914f6cdd1dUL)&0xffff_ffffu;
  }
  */

  static uint nextrand32 (ref int seed) nothrow @trusted @nogc {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (!seed) seed = 0x29a; // arbitrary number
    seed *= 16807;
    return cast(uint)seed;
  }

  // fast floating point rand, suitable for noise
  align(1) static union FITrick {
  align(1):
    float fres;
    uint ires;
  }

  // gives [0..1] result (wow!)
  static float nextfrand (ref int seed) nothrow @trusted @nogc {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (!seed) seed = 0x29a; // arbitrary number
    seed *= 16807;
    FITrick fi = void;
    fi.ires = (((cast(uint)seed)>>9)|0x3f800000);
    return fi.fres-1.0f;
  }

  // gives [-1..1] result (wow!)
  static float nextfrandneg (ref int seed) nothrow @trusted @nogc {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (!seed) seed = 0x29a; // arbitrary number
    seed *= 16807;
    FITrick fi = void;
    fi.ires = (((cast(uint)seed)>>9)|0x3f800000);
    fi.fres -= 1.0f;
    fi.ires ^= cast(uint)seed&0x8000_0000u;
    return fi.fres;
  }

  enum Type : int {
    Square, // 0
    Sawtooth, // 1
    Sine, // 2
    Noise, // 3
  }

  int wave_type = Type.Square;

  float p_base_freq = 0.3f;
  float p_freq_limit = 0.0f;
  float p_freq_ramp = 0.0f;
  float p_freq_dramp = 0.0f;
  float p_duty = 0.0f;
  float p_duty_ramp = 0.0f;

  float p_vib_strength = 0.0f;
  float p_vib_speed = 0.0f;
  float p_vib_delay = 0.0f;

  float p_env_attack = 0.0f;
  float p_env_sustain = 0.3f;
  float p_env_decay = 0.4f;
  float p_env_punch = 0.0f;

  ubyte filter_on = false; // bool
  float p_lpf_resonance = 0.0f;
  float p_lpf_freq = 1.0f;
  float p_lpf_ramp = 0.0f;
  float p_hpf_freq = 0.0f;
  float p_hpf_ramp = 0.0f;

  float p_pha_offset = 0.0f;
  float p_pha_ramp = 0.0f;

  float p_repeat_speed = 0.0f;

  float p_arp_speed = 0.0f;
  float p_arp_mod = 0.0f;

  float sound_vol = 0.5f;

  int origSeed = 0x29a, curseed = 0x29a;


  void setSeed (int seed) nothrow @trusted @nogc { origSeed = curseed = seed; }

  void reset () nothrow @safe @nogc {
    uint sd = origSeed;
    this = this.init;
    origSeed = curseed = sd;
  }

  void load (const(void)[] buf) {
    if (buf.length != 105) throw new NamedException!"SFXR"("invalid sfxr init buffer");
    auto ms = MemoryStreamRO(buf);
    load(ms);
  }

  void load(ST) (auto ref ST st) if (isReadableStream!ST) {
    scope(failure) reset();

    auto ver = st.readNum!int();
    if (ver != 100 && ver != 101 && ver != 102) throw new NamedException!"SFXR"("invalid stream version");

    wave_type = st.readNum!int();
    if (wave_type < 0 || wave_type > Type.max) throw new NamedException!"SFXR"("invalid stream wave type");

    sound_vol = (ver >= 102 ? st.readNum!float() : 0.5f);

    p_base_freq = st.readNum!float();
    p_freq_limit = st.readNum!float();
    p_freq_ramp = st.readNum!float();
    p_freq_dramp = (ver >= 101 ? st.readNum!float() : 0.0f);
    p_duty = st.readNum!float();
    p_duty_ramp = st.readNum!float();

    p_vib_strength = st.readNum!float();
    p_vib_speed = st.readNum!float();
    p_vib_delay = st.readNum!float();

    p_env_attack = st.readNum!float();
    p_env_sustain = st.readNum!float();
    p_env_decay = st.readNum!float();
    p_env_punch = st.readNum!float();

    filter_on = st.readNum!ubyte();
    p_lpf_resonance = st.readNum!float();
    p_lpf_freq = st.readNum!float();
    p_lpf_ramp = st.readNum!float();
    p_hpf_freq = st.readNum!float();
    p_hpf_ramp = st.readNum!float();

    p_pha_offset = st.readNum!float();
    p_pha_ramp = st.readNum!float();

    p_repeat_speed = st.readNum!float();

    if (ver >= 101) {
      p_arp_speed = st.readNum!float();
      p_arp_mod = st.readNum!float();
    } else {
      p_arp_speed = 0.0f;
      p_arp_mod = 0.0f;
    }
  }

  void save(ST) (auto ref ST st) if (isWriteableStream!ST) {
    st.writeNum!int(102); // version

    st.writeNum!int(wave_type);

    st.writeNum!float(sound_vol);

    st.writeNum!float(p_base_freq);
    st.writeNum!float(p_freq_limit);
    st.writeNum!float(p_freq_ramp);
    st.writeNum!float(p_freq_dramp);
    st.writeNum!float(p_duty);
    st.writeNum!float(p_duty_ramp);

    st.writeNum!float(p_vib_strength);
    st.writeNum!float(p_vib_speed);
    st.writeNum!float(p_vib_delay);

    st.writeNum!float(p_env_attack);
    st.writeNum!float(p_env_sustain);
    st.writeNum!float(p_env_decay);
    st.writeNum!float(p_env_punch);

    st.writeNum!ubyte(filter_on);
    st.writeNum!float(p_lpf_resonance);
    st.writeNum!float(p_lpf_freq);
    st.writeNum!float(p_lpf_ramp);
    st.writeNum!float(p_hpf_freq);
    st.writeNum!float(p_hpf_ramp);

    st.writeNum!float(p_pha_offset);
    st.writeNum!float(p_pha_ramp);

    st.writeNum!float(p_repeat_speed);

    st.writeNum!float(p_arp_speed);
    st.writeNum!float(p_arp_mod);
  }

  void exportWAV(string mode, BT, ST) (auto ref ST st)
  if ((is(BT == byte) || is(BT == short)) && (mode == "mono" || mode == "stereo") && isWriteableStream!ST && isSeekableStream!ST)
  {
    static if (is(BT == byte)) {
      enum bitsPerSample = 8;
    } else {
      enum bitsPerSample = 16;
    }
    static if (mode == "mono") {
      enum numChans = 1;
    } else {
      enum numChans = 2;
    }
    enum sampleRate = 44100;

    st.rawWrite("RIFF");
    auto fszpos = st.tell;
    st.writeNum!uint(0); // remaining file size
    st.rawWrite("WAVE");

    st.rawWrite("fmt ");
    st.writeNum!uint(16); // chunk size
    st.writeNum!ushort(1); // compression code
    st.writeNum!ushort(numChans); // channels
    st.writeNum!uint(sampleRate); // sample rate
    st.writeNum!uint(sampleRate*(bitsPerSample*numChans)/8); // bytes per second
    st.writeNum!ushort((bitsPerSample*numChans)/8); // block align
    st.writeNum!ushort(bitsPerSample); // bits per sample

    st.rawWrite("data");
    auto dszpos = st.tell;
    st.writeNum!uint(0); // chunk size

    BT[256*numChans] asmp;
    auto smp = SfxrSample(this);
    uint dataSize = 0;
    do {
      smp.fillBuffer!(mode, BT)(asmp[]);
      st.rawWrite(asmp[]);
      dataSize += cast(uint)(asmp.length*asmp[0].sizeof);
    } while (smp.playing);

    auto epos = st.tell;
    st.seek(dszpos);
    st.writeNum!uint(dataSize);
    st.seek(fszpos);
    st.writeNum!uint(epos-8);

    st.seek(epos);
  }

  void exportRaw(string mode, BT, ST) (auto ref ST st)
  if ((is(BT == byte) || is(BT == short)) && (mode == "mono" || mode == "stereo") && isWriteableStream!ST)
  {
    static if (is(BT == byte)) {
      enum bitsPerSample = 8;
    } else {
      enum bitsPerSample = 16;
    }
    static if (mode == "mono") {
      enum numChans = 1;
    } else {
      enum numChans = 2;
    }
    enum sampleRate = 44100;

    BT[256*numChans] asmp;
    auto smp = SfxrSample(this);
    uint dataSize = 0;
    do {
      smp.fillBuffer!(mode, BT)(asmp[]);
      st.rawWrite(asmp[]);
      dataSize += cast(uint)(asmp.length*asmp[0].sizeof);
    } while (smp.playing);
  }

  uint rnd () nothrow @trusted @nogc { static if (__VERSION__ > 2067) pragma(inline, true); return nextrand32(curseed); }
  float frnd (float range) nothrow @trusted @nogc { static if (__VERSION__ > 2067) pragma(inline, true); return nextfrand(curseed)*range; }

  void rndPickup () nothrow @safe @nogc {
    reset();
    p_base_freq = 0.4f+frnd(0.5f);
    p_env_attack = 0.0f;
    p_env_sustain = frnd(0.1f);
    p_env_decay = 0.1f+frnd(0.4f);
    p_env_punch = 0.3f+frnd(0.3f);
    if (rnd()%2) {
      p_arp_speed = 0.5f+frnd(0.2f);
      p_arp_mod = 0.2f+frnd(0.4f);
    }
  }

  void rndLaser () nothrow @safe @nogc {
    reset();
    wave_type = rnd()%3;
    if (wave_type==2 && rnd()%2) wave_type = rnd()%2;
    p_base_freq = 0.5f+frnd(0.5f);
    p_freq_limit = p_base_freq-0.2f-frnd(0.6f);
    if (p_freq_limit < 0.2f) p_freq_limit = 0.2f;
    p_freq_ramp = -0.15f-frnd(0.2f);
    if (rnd()%3 == 0) {
      p_base_freq = 0.3f+frnd(0.6f);
      p_freq_limit = frnd(0.1f);
      p_freq_ramp = -0.35f-frnd(0.3f);
    }
    if (rnd()%2) {
      p_duty = frnd(0.5f);
      p_duty_ramp = frnd(0.2f);
    } else {
      p_duty = 0.4f+frnd(0.5f);
      p_duty_ramp = -frnd(0.7f);
    }
    p_env_attack = 0.0f;
    p_env_sustain = 0.1f+frnd(0.2f);
    p_env_decay = frnd(0.4f);
    if (rnd()%2) p_env_punch = frnd(0.3f);
    if (rnd()%3 == 0) {
      p_pha_offset = frnd(0.2f);
      p_pha_ramp = -frnd(0.2f);
    }
    if (rnd()%2) p_hpf_freq = frnd(0.3f);
  }

  void rndExplosion () nothrow @safe @nogc {
    reset();
    wave_type = Type.Noise;
    if (rnd()%2) {
      p_base_freq = 0.1f+frnd(0.4f);
      p_freq_ramp = -0.1f+frnd(0.4f);
    } else {
      p_base_freq = 0.2f+frnd(0.7f);
      p_freq_ramp = -0.2f-frnd(0.2f);
    }
    p_base_freq *= p_base_freq;
    if (rnd()%5 == 0) p_freq_ramp = 0.0f;
    if (rnd()%3 == 0) p_repeat_speed = 0.3f+frnd(0.5f);
    p_env_attack = 0.0f;
    p_env_sustain = 0.1f+frnd(0.3f);
    p_env_decay = frnd(0.5f);
    if (rnd()%2 == 0) {
      p_pha_offset = -0.3f+frnd(0.9f);
      p_pha_ramp = -frnd(0.3f);
    }
    p_env_punch = 0.2f+frnd(0.6f);
    if (rnd()%2) {
      p_vib_strength = frnd(0.7f);
      p_vib_speed = frnd(0.6f);
    }
    if (rnd()%3 == 0) {
      p_arp_speed = 0.6f+frnd(0.3f);
      p_arp_mod = 0.8f-frnd(1.6f);
    }
  }

  void rndPowerup () nothrow @safe @nogc {
    reset();
    if (rnd()%2) wave_type = Type.Sawtooth; else p_duty = frnd(0.6f);
    if (rnd()%2) {
      p_base_freq = 0.2f+frnd(0.3f);
      p_freq_ramp = 0.1f+frnd(0.4f);
      p_repeat_speed = 0.4f+frnd(0.4f);
    } else {
      p_base_freq = 0.2f+frnd(0.3f);
      p_freq_ramp = 0.05f+frnd(0.2f);
      if (rnd()%2) {
        p_vib_strength = frnd(0.7f);
        p_vib_speed = frnd(0.6f);
      }
    }
    p_env_attack = 0.0f;
    p_env_sustain = frnd(0.4f);
    p_env_decay = 0.1f+frnd(0.4f);
  }

  void rndHurt () nothrow @safe @nogc {
    reset();
    wave_type = rnd()%3;
    if (wave_type == Type.Sine) wave_type = Type.Noise;
    if (wave_type == Type.Square) p_duty = frnd(0.6f);
    p_base_freq = 0.2f+frnd(0.6f);
    p_freq_ramp = -0.3f-frnd(0.4f);
    p_env_attack = 0.0f;
    p_env_sustain = frnd(0.1f);
    p_env_decay = 0.1f+frnd(0.2f);
    if (rnd()%2) p_hpf_freq = frnd(0.3f);
  }

  void rndJump () nothrow @safe @nogc {
    reset();
    wave_type = Type.Square;
    p_duty = frnd(0.6f);
    p_base_freq = 0.3f+frnd(0.3f);
    p_freq_ramp = 0.1f+frnd(0.2f);
    p_env_attack = 0.0f;
    p_env_sustain = 0.1f+frnd(0.3f);
    p_env_decay = 0.1f+frnd(0.2f);
    if (rnd()%2) p_hpf_freq = frnd(0.3f);
    if (rnd()%2) p_lpf_freq = 1.0f-frnd(0.6f);
  }

  void rndBlip () nothrow @safe @nogc {
    reset();
    wave_type = rnd()%2;
    if (wave_type == Type.Square) p_duty = frnd(0.6f);
    p_base_freq = 0.2f+frnd(0.4f);
    p_env_attack = 0.0f;
    p_env_sustain = 0.1f+frnd(0.1f);
    p_env_decay = frnd(0.2f);
    p_hpf_freq = 0.1f;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct SfxrSample {
  bool playing_sample = false;

  float master_vol = 0.5f;

  Sfxr fx;
  int phase;
  double fperiod;
  double fmaxperiod;
  double fslide;
  double fdslide;
  int period;
  float square_duty;
  float square_slide;
  int env_stage;
  int env_time;
  int[3] env_length;
  float env_vol;
  float fphase;
  float fdphase;
  int iphase;
  float[1024] phaser_buffer;
  int ipp;
  float[32] noise_buffer;
  float fltp;
  float fltdp;
  float fltw;
  float fltw_d;
  float fltdmp;
  float fltphp;
  float flthp;
  float flthp_d;
  float vib_phase;
  float vib_speed;
  float vib_amp;
  int rep_time;
  int rep_limit;
  int arp_time;
  int arp_limit;
  double arp_mod;
  int curseed;

  this() (in auto ref Sfxr sfx) { reset(sfx); curseed = sfx.origSeed; }

  void setSeed (int seed) nothrow @trusted @nogc { curseed = seed; }

  //float frnd (float range) nothrow @trusted @nogc { static if (__VERSION__ > 2067) pragma(inline, true); return (1.0f/16384.0f)*range*(Sfxr.nextrand32(curseed)%16384); }

  @property bool playing () const pure nothrow @safe @nogc { return playing_sample; }

  void resetLoop () nothrow @safe @nogc {
    import std.math : abs, pow;

    fperiod = 100.0/(fx.p_base_freq*fx.p_base_freq+0.001);
    period = cast(int)fperiod;
    fmaxperiod = 100.0/(fx.p_freq_limit*fx.p_freq_limit+0.001);
    fslide = 1.0-pow(cast(double)fx.p_freq_ramp, 3.0)*0.01;
    fdslide = -pow(cast(double)fx.p_freq_dramp, 3.0)*0.000001;
    square_duty = 0.5f-fx.p_duty*0.5f;
    square_slide = -fx.p_duty_ramp*0.00005f;
    if (fx.p_arp_mod >= 0.0f) {
      arp_mod = 1.0-pow(cast(double)fx.p_arp_mod, 2.0)*0.9;
    } else {
      arp_mod = 1.0+pow(cast(double)fx.p_arp_mod, 2.0)*10.0;
    }
    arp_time = 0;
    arp_limit = cast(int)(pow(1.0f-fx.p_arp_speed, 2.0f)*20000+32);
    if (fx.p_arp_speed == 1.0f) arp_limit = 0;
  }

  void reset() (in auto ref Sfxr sfx) nothrow @trusted @nogc {
    import std.math : abs, pow;

    fx = sfx;
    phase = 0;
    resetLoop();
    // reset filter
    fltp = 0.0f;
    fltdp = 0.0f;
    fltw = pow(fx.p_lpf_freq, 3.0f)*0.1f;
    fltw_d = 1.0f+fx.p_lpf_ramp*0.0001f;
    fltdmp = 5.0f/(1.0f+pow(fx.p_lpf_resonance, 2.0f)*20.0f)*(0.01f+fltw);
    if (fltdmp > 0.8f) fltdmp = 0.8f;
    fltphp = 0.0f;
    flthp = pow(fx.p_hpf_freq, 2.0f)*0.1f;
    flthp_d = 1.0+fx.p_hpf_ramp*0.0003f;
    // reset vibrato
    vib_phase = 0.0f;
    vib_speed = pow(fx.p_vib_speed, 2.0f)*0.01f;
    vib_amp = fx.p_vib_strength*0.5f;
    // reset envelope
    env_vol = 0.0f;
    env_stage = 0;
    env_time = 0;
    env_length[0] = cast(int)(fx.p_env_attack*fx.p_env_attack*100000.0f);
    env_length[1] = cast(int)(fx.p_env_sustain*fx.p_env_sustain*100000.0f);
    env_length[2] = cast(int)(fx.p_env_decay*fx.p_env_decay*100000.0f);

    fphase = pow(fx.p_pha_offset, 2.0f)*1020.0f;
    if (fx.p_pha_offset < 0.0f) fphase = -fphase;
    fdphase = pow(fx.p_pha_ramp, 2.0f)*1.0f;
    if (fx.p_pha_ramp < 0.0f) fdphase = -fdphase;
    iphase = abs(cast(int)fphase);
    ipp = 0;
    phaser_buffer[] = 0.0f;
    {
      auto nb = noise_buffer.ptr;
      foreach (immutable _; 0..noise_buffer.length) *nb++ = /*frnd(2.0f)-1.0f*/Sfxr.nextfrandneg(curseed);
    }

    rep_time = 0;
    rep_limit = cast(int)(pow(1.0f-fx.p_repeat_speed, 2.0f)*20000+32);
    if (fx.p_repeat_speed == 0.0f) rep_limit = 0;

    playing_sample = true;
  }

  // return `true` if the whole frame was silent
  void fillBuffer(string mode, BT) (BT[] buffer) nothrow @trusted @nogc
  if ((is(BT == byte) || is(BT == short) || is(BT == float)) && (mode == "mono" || mode == "stereo"))
  {
    import std.math : abs, pow, sin, PI;
    //static assert(is(BT == float));
    //static assert(mode == "mono");

    static if (mode == "stereo") {
      float smp;
      bool smpdup;
    }

    foreach (immutable bidx; 0..buffer.length) {
      auto bufel = buffer.ptr+bidx;
      static if (mode == "stereo") {
        if (smpdup) {
          smpdup = false;
          static if (is(BT == float)) *bufel = smp;
          else static if (is(BT == byte)) *bufel = cast(byte)(smp*127);
          else static if (is(BT == short)) *bufel = cast(short)(smp*32767);
          else static assert(0, "wtf?!");
          continue;
        }
      }
      //if (!playing_sample) break; //FIXME: silence buffer?
      if (!playing_sample) {
        //static if (is(BT == ubyte)) bufel = 0.0f;
        *bufel = 0;
        continue;
      }

      ++rep_time;
      if (rep_limit != 0 && rep_time >= rep_limit) {
        rep_time = 0;
        resetLoop();
      }

      // frequency envelopes/arpeggios
      ++arp_time;
      if (arp_limit != 0 && arp_time >= arp_limit) {
        arp_limit = 0;
        fperiod *= arp_mod;
      }
      fslide += fdslide;
      fperiod *= fslide;
      if (fperiod > fmaxperiod) {
        fperiod = fmaxperiod;
        if (fx.p_freq_limit > 0.0f) playing_sample = false;
      }
      float rfperiod = fperiod;
      if (vib_amp > 0.0f) {
        vib_phase += vib_speed;
        rfperiod = fperiod*(1.0+sin(vib_phase)*vib_amp);
      }
      period = cast(int)rfperiod;
      if (period < 8) period = 8;
      square_duty += square_slide;
      if (square_duty < 0.0f) square_duty = 0.0f;
      if (square_duty > 0.5f) square_duty = 0.5f;
      // volume envelope
      ++env_time;
      if (env_time > env_length[env_stage]) {
        env_time = 0;
        ++env_stage;
        if (env_stage == 3) playing_sample = false;
      }
      if (env_stage == 0) env_vol = cast(float)env_time/env_length[0];
      if (env_stage == 1) env_vol = 1.0f+pow(1.0f-cast(float)env_time/env_length[1], 1.0f)*2.0f*fx.p_env_punch;
      if (env_stage == 2) env_vol = 1.0f-cast(float)env_time/env_length[2];

      // phaser step
      fphase += fdphase;
      iphase = abs(cast(int)fphase);
      if (iphase > 1023) iphase = 1023;

      if (flthp_d != 0.0f) {
        flthp *= flthp_d;
        if (flthp < 0.00001f) flthp = 0.00001f;
        if (flthp > 0.1f) flthp = 0.1f;
      }

      float ssample = 0.0f;
      // 8x supersampling
      foreach (immutable _; 0..8) {
        float sample = 0.0f;
        ++phase;
        if (phase >= period) {
          //phase = 0;
          phase %= period;
          if (fx.wave_type == Sfxr.Type.Noise) {
            auto nb = noise_buffer.ptr;
            foreach (immutable _0; 0..noise_buffer.length) *nb++ = /*frnd(2.0f)-1.0f*/Sfxr.nextfrandneg(curseed);
          }
        }
        // base waveform
        float fp = cast(float)phase/period;
        final switch (fx.wave_type) with (Sfxr.Type) {
          case Square: sample = (fp < square_duty ? 0.5f : -0.5f); break;
          case Sawtooth: sample = 1.0f-fp*2; break;
          case Sine: sample = cast(float)sin(fp*2*PI); break;
          case Noise: sample = noise_buffer[phase*32/period]; break;
        }
        // lp filter
        float pp = fltp;
        fltw *= fltw_d;
        if (fltw < 0.0f) fltw = 0.0f;
        if (fltw > 0.1f) fltw = 0.1f;
        if (fx.p_lpf_freq != 1.0f) {
          fltdp += (sample-fltp)*fltw;
          fltdp -= fltdp*fltdmp;
        } else {
          fltp = sample;
          fltdp = 0.0f;
        }
        fltp += fltdp;
        // hp filter
        fltphp += fltp-pp;
        fltphp -= fltphp*flthp;
        sample = fltphp;
        // phaser
        phaser_buffer[ipp&1023] = sample;
        sample += phaser_buffer[(ipp-iphase+1024)&1023];
        ipp = (ipp+1)&1023;
        // final accumulation and envelope application
        ssample += sample*env_vol;
      }
      ssample = ssample/8*master_vol;
      ssample *= 2.0f*fx.sound_vol;
      // to buffer
      {
        static if (mode == "mono") float smp = ssample; else smp = ssample;
        if (smp > 1.0f) smp = 1.0f;
        if (smp < -1.0f) smp = -1.0f;
        static if (is(BT == float)) *bufel = smp;
        else static if (is(BT == byte)) *bufel = cast(byte)(smp*127);
        else static if (is(BT == short)) *bufel = cast(short)(smp*32767);
        else static assert(0, "wtf?!");
        static if (mode == "stereo") smpdup = true;
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class SfxChannel : TflChannel {
  SfxrSample smp;
  //shared bool sfxdone = false;

  this() (in auto ref Sfxr sfxr) { smp.reset(sfxr); }

  override uint fillFrames (float[] buf) nothrow {
    if (!smp.playing) return 0; // no more
    //{ import core.stdc.stdio; printf("filling sfx buffer... (%u)\n", (smp.playing ? 1 : 0)); }
    smp.fillBuffer!"stereo"(buf[]);
    return buf.length/2; // return number of frames
    //{ import core.stdc.stdio; printf("filled sfx buffer... (%u)\n", (smp.playing ? 1 : 0)); }
  }

  /*
  override void discarded () nothrow {
    import core.stdc.stdio;
    printf("sfx complete\n");
    atomicStore(sfxdone, true);
  }
  */
}
}
