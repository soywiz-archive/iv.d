// Blip_Buffer 0.4.0. http://www.slack.net/~ant/
// Band-limited sound synthesis and buffering
/* Copyright (C) 2003-2006 Shay Green. This module is free software; you
 * can redistribute it and/or modify it under the terms of the GNU Lesser
 * General Public License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version. This
 * module is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
 * more details. You should have received a copy of the GNU Lesser General
 * Public License along with this module; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */
// assumptions code makes about implementation-defined features
// right shift of negative value preserves sign
// casting to smaller signed type truncates bits and extends sign
module iv.blipbuf;


// ////////////////////////////////////////////////////////////////////////// //
///
final class BlipBuffer {
public:
  alias Time = int; /// Time unit at source clock rate
  alias Int = int;
  alias UInt = uint;

  /// Output samples are 16-bit signed, with a range of -32767 to 32767
  alias Sample = short;

  /// Number of bits in resample ratio fraction. Higher values give a more accurate ratio but reduce maximum buffer size.
  enum BufferAccuracy = 16;

  /** Number bits in phase offset. Fewer than 6 bits (64 phase offsets) results in
   * noticeable broadband noise when synthesizing high frequency square waves.
   * Affects size of Blip_Synth objects since they store the waveform directly.
   */
  enum PhaseBits = 6;

  ///
  enum SampleBits = 30;


  /// Quality level. Start with blip_good_quality.
  enum {
    Medium  = 8, ///
    Good = 12, ///
    High = 16, ///
  }

public:
  ///
  enum Result {
    OK, ///
    BadArguments, ///
    NoMemory, ///
  }

  alias ResampledTime = UInt;

private:
  UInt mFactor;
  ResampledTime mOffset;
  BufType[] mBufferDArr;
  Int mBufferSize;

private:
  alias BufType = Int;
  enum BufferExtra = blip_widest_impulse_+2;

private:
  Int mReaderAccum;
  ubyte mBassShift;
  Int mSampleRate;
  Int mClockRate;
  int mBassFreq;
  int mLength;
  int mMSLength;

public:
  /** Set output sample rate and buffer length in milliseconds (1/1000 sec, defaults
   * to 1/4 second), then clear buffer. Returns Result.OK on success, otherwise if there
   * isn't enough memory, returns error without affecting current buffer setup.
   */
  Result setSampleRate(bool dofail=true) (Int samples_per_sec, uint msec_length=1000/4) nothrow @trusted {
    // start with maximum length that resampled time can represent
    Int new_size = (UInt.max>>BufferAccuracy)-BufferExtra-64;
    if (msec_length != blip_max_length) {
      long s = (cast(long)samples_per_sec*(msec_length+1)+999)/1000;
      if (s > new_size) {
        static if (dofail) {
          return Result.BadArguments; //assert(0, "requested buffer size too big");
        } else {
          s = new_size;
        }
      }
      if (s < new_size) new_size = cast(Int)s;
    }
    mMSLength = msec_length; //UNRELIABLE!

    if (mBufferSize != new_size) {
      mBufferDArr.assumeSafeAppend;
      mBufferDArr.length = new_size+BufferExtra;
    }

    mBufferSize = new_size;

    // update things based on the sample rate
    mSampleRate = samples_per_sec;
    mLength = new_size*1000/samples_per_sec-1;
    assert(msec_length == 0 || mLength == msec_length); // ensure length is same as that passed in
    if (mClockRate) clockRate(mClockRate);
    bassFreq(mBassFreq);

    clear!true();

    return Result.OK;
  }

  /// Set number of source time units per second
  @property void clockRate (Int cps) nothrow @trusted @nogc {
    mClockRate = cps;
    mFactor = clockRateFactor(cps);
  }

  /** End current time frame of specified duration and make its samples available
   * (along with any still-unread samples) for reading with read_samples(). Begins
   * a new time frame at the end of the current frame.
   */
  void endFrame (Time time) nothrow @trusted @nogc {
    mOffset += time*mFactor;
    assert(samplesAvail <= cast(Int)mBufferSize); // time outside buffer length
  }

  /** Read at most 'max_samples' out of buffer into 'aout', removing them from from
   * the buffer. Returns number of samples actually read and removed. If stereo is
   * true, increments 'aout' one extra time after writing each sample, to allow
   * easy interleving of two channels into a stereo output buffer.
   * Fill both left and right channels if `fake_stereo` is set.
   */
  Int readSamples(bool stereo, bool fake_stereo=false) (Sample* aout, Int max_samples) nothrow @trusted @nogc {
    Int count = samplesAvail;
    if (count > max_samples) count = max_samples;
    if (count) {
      enum sample_shift = SampleBits-16;
      immutable ubyte bass_shift = this.mBassShift;
      Int accum = mReaderAccum;
      const(BufType)* ain = mBufferDArr.ptr;
      for (Int n = count; n--; ) {
        Int s = accum>>sample_shift;
        accum -= accum>>bass_shift;
        accum += *ain++;
        *aout = cast(Sample)s;
        // clamp sample
        if (cast(Sample)s != s) *aout = cast(Sample)(0x7FFF-(s>>24));
        static if (stereo) {
          static if (fake_stereo) { aout[1] = aout[0]; }
          aout += 2;
        } else {
          ++aout;
        }
      }
      mReaderAccum = accum;
      removeSamples(count);
    }
    return count;
  }

  // Additional optional features

  /// Current output sample rate
  @property Int sampleRate () const nothrow @trusted @nogc { return mSampleRate; }

  /// Current output sample rate
  @property void sampleRate (Int rate) nothrow @trusted { setSampleRate!false(rate, (mMSLength ? mMSLength : 1000/4)); }

  /// Length of buffer, in milliseconds
  @property int length () const nothrow @trusted @nogc { return mLength; }

  /// Number of source time units per second
  @property Int clockRate () const nothrow @trusted @nogc { return mClockRate; }

  /// Set frequency high-pass filter frequency, where higher values reduce bass more
  void bassFreq (int freq) nothrow @trusted @nogc {
    mBassFreq = freq;
    ubyte shift = 31;
    if (freq > 0) {
      shift = 13;
      Int f = (freq<<16)/mSampleRate;
      while ((f >>= 1) != 0 && --shift) {}
    }
    mBassShift = shift;
  }

  /// Number of samples delay from synthesis to samples read out
  int outputLatency () const nothrow @trusted @nogc { return blip_widest_impulse_/2; }

  /** Remove all available samples and clear buffer to silence. If 'entire_buffer' is
   * false, just clears out any samples waiting rather than the entire buffer.
   */
  void clear(bool entire_buffer=true) () nothrow @trusted @nogc {
    mOffset = 0;
    mReaderAccum = 0;
    if (mBufferDArr.length) {
      static if (entire_buffer) {
        Int count = mBufferSize;
      } else {
        Int count = samples_avail;
      }
      mBufferDArr[0..count+BufferExtra] = 0;
    }
  }

  /// Number of samples available for reading with read_samples()
  Int samplesAvail () const nothrow @trusted @nogc { return cast(Int)(mOffset>>BufferAccuracy); }

  /// Remove 'count' samples from those waiting to be read
  void removeSamples (Int count) nothrow @trusted @nogc {
    import core.stdc.string : memmove, memset;
    if (count) {
      removeSilence(count);
      // copy remaining samples to beginning and clear old samples
      Int remain = samplesAvail+BufferExtra;
      if (remain) memmove(mBufferDArr.ptr, mBufferDArr.ptr+count, remain*mBufferDArr[0].sizeof);
      memset(mBufferDArr.ptr+remain, 0, count*mBufferDArr[0].sizeof);
    }
  }

  // Experimental features

  /// Number of raw samples that can be mixed within frame of specified duration.
  Int countSamples (Time duration) const nothrow @trusted @nogc {
    UInt last_sample = resampledTime(duration)>>BufferAccuracy;
    UInt first_sample = mOffset>>BufferAccuracy;
    return cast(Int)(last_sample-first_sample);
  }

  /// Mix 'count' samples from 'ain' into buffer.
  void mixSamples (const(Sample)* ain, Int count) nothrow @trusted @nogc {
    BufType* aout = mBufferDArr.ptr+(mOffset>>BufferAccuracy)+blip_widest_impulse_/2;
    enum sample_shift = SampleBits-16;
    int prev = 0;
    while (count--) {
      Int s = (cast(Int)(*ain++))<<sample_shift;
      *aout += s-prev;
      prev = s;
      ++aout;
    }
    *aout -= prev;
  }

  /** Count number of clocks needed until 'count' samples will be available.
   * If buffer can't even hold 'count' samples, returns number of clocks until
   * buffer becomes full.
   */
  Time countClocks (Int count) const nothrow @trusted @nogc {
    if (count > mBufferSize) count = mBufferSize;
    ResampledTime time = (cast(ResampledTime)count)<<BufferAccuracy;
    return cast(Time)((time-mOffset+mFactor-1)/mFactor);
  }

  /// not documented yet
  void removeSilence (Int count) nothrow @trusted @nogc {
    assert(count <= samplesAvail); // tried to remove more samples than available
    mOffset -= (cast(ResampledTime)count)<<BufferAccuracy;
  }

  ///
  ResampledTime resampledDuration (int t) const nothrow @trusted @nogc { return t*mFactor; }

  ///
  ResampledTime resampledTime (Time t) const nothrow @trusted @nogc { return t*mFactor+mOffset; }

  ///
  ResampledTime clockRateFactor (Int clock_rate) const nothrow @trusted @nogc {
    import std.math : floor;
    double ratio = cast(double)mSampleRate/clock_rate;
    Int factor = cast(Int)floor(ratio*((cast(Int)1)<<BufferAccuracy)+0.5);
    assert(factor > 0 || !mSampleRate); // fails if clock/output ratio is too large
    return cast(ResampledTime)factor;
  }

public:
  this () nothrow @trusted { kill(); } ///

  /// free memory and such
  void kill () nothrow @trusted {
    mFactor = Int.max; //???
    mOffset = 0;
    delete mBufferDArr; mBufferDArr = null; // double-safety! ;-)
    mBufferSize = 0;
    mSampleRate = 0;
    mReaderAccum = 0;
    mBassShift = 0;
    mClockRate = 0;
    mBassFreq = 16;
    mLength = 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
///
//alias Blip_Synth = Blip_Synth_Parm!(blip_good_quality, 65535);


// ////////////////////////////////////////////////////////////////////////// //
/** Range specifies the greatest expected change in amplitude. Calculate it
 * by finding the difference between the maximum and minimum expected
 * amplitudes (max - min).
 */
final class BlipSynthBase(int quality, int range) {
static assert(quality > 0 && quality <= BlipBuffer.High, "invalid blip synth quality");
static assert(range > 0 && range <= 65535, "invalid blip synth range");
private:
  alias imp_t = short;
  imp_t[blip_res*(quality/2)+1+4] impulses;
  BlipSynth_!(imp_t, quality) impl;

  final double calcVolUnit (double v) {
    pragma(inline, true);
    //return v*(1.0/(range < 0 ? -(range) : range));
    return v*(1.0/range);
  }

public:
  /// Set overall volume of waveform
  void volume (double v) nothrow @trusted @nogc { impl.last_amp = 0; impl.volume_unit(calcVolUnit(v)); }

  /// Configure low-pass filter (see notes.txt)
  void trebleEq() (in auto ref BlipEq eq) nothrow @trusted @nogc { impl.last_amp = 0; impl.treble_eq(eq); }

  /// Configure low-pass filter (see notes.txt)
  void setVolumeTreble (double vol, double treb) nothrow @trusted @nogc { impl.last_amp = 0; impl.set_volume_treble(calcVolUnit(vol), treb); }

  /// Configure low-pass filter (see notes.txt)
  void setOutputVolumeTreble (BlipBuffer b, double vol, double treb) nothrow @trusted @nogc { impl.buf = b; impl.last_amp = 0; impl.set_volume_treble(calcVolUnit(vol), treb); }

  /// Get/set Blip_Buffer used for output
  BlipBuffer output () nothrow @trusted @nogc { return impl.buf; }
  void output (BlipBuffer b) nothrow @trusted @nogc { impl.set_buffer(b); impl.last_amp = 0; }

  /// Update amplitude of waveform at given time. Using this requires a separate
  /// Blip_Synth for each waveform.
  void update (BlipBuffer.Time t, int amp) nothrow @trusted @nogc {
    if (amp < -range) amp = -range; else if (amp > range) amp = range;
    int delta = amp-impl.last_amp;
    impl.last_amp = amp;
    offsetResampled(t*impl.buf.mFactor+impl.buf.mOffset, delta, impl.buf);
  }

  // Low-level interface

  // Add an amplitude transition of specified delta, optionally into specified buffer
  // rather than the one set with output(). Delta can be positive or negative.
  // The actual change in amplitude is delta * (volume / range)
  void offset (BlipBuffer.Time t, int delta, BlipBuffer buf) nothrow @trusted @nogc { offsetResampled(t*buf.mFactor+buf.mOffset, delta, buf); }
  void offset (BlipBuffer.Time t, int delta) nothrow @trusted @nogc { offset(t, delta, impl.buf); }

  // Works directly in terms of fractional output samples. Contact author for more.
  void offsetResampled (BlipBuffer.ResampledTime time, int delta, BlipBuffer blip_buf) nothrow @trusted @nogc {
    enum BLIP_FWD (string i) = "
      t0 = i0*delta+buf[fwd+"~i~"];
      t1 = imp[blip_res*("~i~"+1)]*delta+buf[fwd+1+"~i~"];
      i0 = imp[blip_res*("~i~"+2)];
      buf[fwd+"~i~"] = t0;
      buf[fwd+1+"~i~"] = t1;
    ";

    enum BLIP_REV(string r) = "
      t0 = i0*delta+buf[rev-"~r~"];
      t1 = imp[blip_res*"~r~"]*delta+buf[rev+1-"~r~"];
      i0 = imp[blip_res*("~r~"-1)];
      buf[rev-"~r~"] = t0;
      buf[rev+1-"~r~"] = t1;
    ";

    // Fails if time is beyond end of Blip_Buffer, due to a bug in caller code or the
    // need for a longer buffer as set by set_sample_rate().
    assert(cast(BlipBuffer.Int)(time>>BlipBuffer.BufferAccuracy) < blip_buf.mBufferSize);
    delta *= impl.delta_factor;
    int phase = cast(int)(time>>(BlipBuffer.BufferAccuracy-BlipBuffer.PhaseBits)&(blip_res-1));
    imp_t* imp = impulses.ptr+blip_res-phase;
    BlipBuffer.Int* buf = blip_buf.mBufferDArr.ptr+(time>>BlipBuffer.BufferAccuracy);
    BlipBuffer.Int i0 = *imp;
    BlipBuffer.Int t0, t1;

    enum fwd = (blip_widest_impulse_-quality)/2;
    enum rev = fwd+quality-2;

    mixin(BLIP_FWD!"0");
    static if (quality > 8) { mixin(BLIP_FWD!"2"); }
    static if (quality > 12) { mixin(BLIP_FWD!"4"); }

    enum mid = quality/2-1;
    t0 = i0*delta+buf[fwd+mid-1];
    t1 = imp[blip_res*mid]*delta+buf[fwd+mid];
    imp = impulses.ptr+phase;
    i0 = imp[blip_res*mid];
    buf[fwd+mid-1] = t0;
    buf[fwd+mid] = t1;

    static if (quality > 12) { mixin(BLIP_REV!"6"); }
    static if (quality > 8) { mixin(BLIP_REV!"4"); }
    mixin(BLIP_REV!"2");

    t0 = i0*delta+buf[rev];
    t1 = (*imp)*delta+buf[rev+1];
    buf[rev] = t0;
    buf[rev+1] = t1;
  }

public:
  this () nothrow @trusted { impl.impulses = impulses.ptr; }
}


// ////////////////////////////////////////////////////////////////////////// //
/// Low-pass equalization parameters
struct BlipEq {
public:
  double treble = 0;
  BlipBuffer.Int rolloff_freq = 0;
  BlipBuffer.Int cutoff_freq = 0;

public:
  /// Logarithmic rolloff to treble dB at half sampling rate. Negative values reduce treble, small positive values (0 to 5.0) increase treble.
  /// See notes.txt
  this (double treble_db, BlipBuffer.Int arolloff_freq=0, BlipBuffer.Int acutoff_freq=0) nothrow @trusted @nogc {
    treble = treble_db;
    rolloff_freq = arolloff_freq;
    cutoff_freq = acutoff_freq;
  }

private:
  void generate (float* aout, int count, BlipBuffer.Int sample_rate) const nothrow @trusted @nogc {
    import std.math : PI, cos;
    // lower cutoff freq for narrow kernels with their wider transition band
    // (8 points->1.49, 16 points->1.15)
    immutable double half_rate = sample_rate*0.5;
    double oversample = blip_res*2.25/count+0.85;
    if (cutoff_freq) oversample = half_rate/cutoff_freq;
    immutable double cutoff = rolloff_freq*oversample/half_rate;
    gen_sinc(aout, count, blip_res*oversample, treble, cutoff);
    // apply (half of) hamming window
    immutable double to_fraction = PI/(count-1);
    for (int i = count; i--; ) aout[i] *= 0.54-0.46*cos(i*to_fraction);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// Sample reader for custom sample formats and mixing of BlipBuffer samples
struct BlipReader {
private:
  const(BlipBuffer.BufType)* buf;
  BlipBuffer.Int accum;

public:
  /// Begin reading samples from buffer. Returns value to pass to next() (can be ignored if default bass_freq is acceptable).
  int begin (BlipBuffer blip_buf) nothrow @trusted @nogc {
    pragma(inline, true);
    buf = blip_buf.mBufferDArr.ptr;
    accum = blip_buf.mReaderAccum;
    return blip_buf.mBassShift;
  }

  /// Current sample
  BlipBuffer.Int read () const pure nothrow @trusted @nogc { pragma(inline, true); return accum>>(BlipBuffer.SampleBits-16); }

  /// Current raw sample in full internal resolution
  BlipBuffer.Int read_raw () const pure nothrow @trusted @nogc { pragma(inline, true); return accum; }

  /// Advance to next sample
  void next (int bass_shift=9) nothrow @trusted @nogc { pragma(inline, true); accum += (*buf++)-(accum>>bass_shift); }

  /// End reading samples from buffer. The number of samples read must now be removed using `Blip_Buffer.remove_samples()`.
  void end (BlipBuffer b) nothrow @trusted @nogc { pragma(inline, true); b.mReaderAccum = accum; }
}


// ////////////////////////////////////////////////////////////////////////// //
// End of public interface

private:
enum blip_max_length = 0;
enum blip_default_length = 250;

enum blip_widest_impulse_ = 16;
enum blip_res = 1<<BlipBuffer.PhaseBits;


// ////////////////////////////////////////////////////////////////////////// //
struct BlipSynth_(imp_t, int width) {
private:
  BlipEq cur_eq = BlipEq(-8.0);
  double mVolumeUnit = 0;
  BlipBuffer.Int kernel_unit = 0;
  imp_t* impulses;
  //int width;

public:
  BlipBuffer buf;
  int last_amp = 0;
  int delta_factor = 0;

public:
  /+
  this (imp_t* aimpulses/*, int awidth*/) nothrow @trusted @nogc {
    impulses = aimpulses;
    //width = awidth;
  }
  +/

  @disable this (this); // no copies

  void set_buffer (BlipBuffer abuf) nothrow @trusted @nogc {
    buf = abuf;
    treble_eq(cur_eq);
  }

  void set_volume_treble (double vol, double treb) nothrow @trusted @nogc {
    cur_eq.treble = treb;
    mVolumeUnit = vol;
    treble_eq(cur_eq); // recalculate
  }

  void treble_eq() (in auto ref BlipEq eq) nothrow @trusted @nogc {
    float[blip_res/2*(blip_widest_impulse_-1)+blip_res*2] fimpulse = void;
    enum half_size = blip_res/2*(width-1);

    BlipBuffer.Int sample_rate = (buf !is null ? buf.sampleRate : 48000);
    eq.generate(&fimpulse[blip_res], half_size, sample_rate);

    //FIXME! don't do copypasta here
    cur_eq.treble = eq.treble;
    cur_eq.rolloff_freq = eq.rolloff_freq;
    cur_eq.cutoff_freq = eq.cutoff_freq;

    // need mirror slightly past center for calculation
    for (int i = blip_res; i--; ) fimpulse[blip_res+half_size+i] = fimpulse[blip_res+half_size-1-i];

    // starts at 0
    //for (int i = 0; i < blip_res; ++i) fimpulse[i] = 0.0f;
    fimpulse[0..blip_res] = 0;

    // find rescale factor
    double total = 0.0;
    foreach (float v; fimpulse[blip_res..blip_res+half_size]) total += v;

    //double const base_unit = 44800.0 - 128 * 18; // allows treble up to +0 dB
    //double const base_unit = 37888.0; // allows treble to +5 dB
    enum base_unit = cast(double)32768.0; // necessary for blip_unscaled to work
    immutable double rescale = base_unit/2/total;
    kernel_unit = cast(BlipBuffer.Int)base_unit;

    // integrate, first difference, rescale, convert to int
    double sum = 0.0;
    double next = 0.0;
    foreach (immutable int i; 0..impulses_size) {
      import std.math : floor;
      impulses[i] = cast(imp_t)floor((next-sum)*rescale+0.5);
      sum += fimpulse.ptr[i];
      next += fimpulse.ptr[i+blip_res];
    }
    adjust_impulse();

    // volume might require rescaling
    double vol = mVolumeUnit;
    if (vol) {
      mVolumeUnit = 0.0;
      volume_unit(vol);
    }
  }

  void volume_unit (double new_unit) nothrow @trusted @nogc {
    import std.math : floor;
    if (new_unit != mVolumeUnit) {
      // use default eq if it hasn't been set yet
      if (!kernel_unit) treble_eq(cur_eq);
      mVolumeUnit = new_unit;
      double factor = new_unit*((cast(BlipBuffer.Int)1)<<BlipBuffer.SampleBits)/kernel_unit;
      if (factor > 0.0) {
        int shift = 0;
        // if unit is really small, might need to attenuate kernel
        while (factor < 2.0) { ++shift; factor *= 2.0; }
        if (shift) {
          kernel_unit >>= shift;
          assert(kernel_unit > 0); // fails if volume unit is too low
          // keep values positive to avoid round-towards-zero of sign-preserving
          // right shift for negative values
          BlipBuffer.Int offset = 0x8000+(1<<(shift-1));
          BlipBuffer.Int offset2 = 0x8000>>shift;
          for (int i = impulses_size; i--; ) impulses[i] = cast(imp_t)(((impulses[i]+offset)>>shift)-offset2);
          adjust_impulse();
        }
      }
      delta_factor = cast(int)floor(factor+0.5);
    }
  }

private:
  //int impulses_size () const nothrow @trusted @nogc { pragma(inline, true); return blip_res/2*width+1; }
  //enum impulses_size = blip_res/2*width+1;
  enum impulses_size = blip_res*(width/2)+1;

  void adjust_impulse () nothrow @trusted @nogc {
    // sum pairs for each phase and add error correction to end of first half
    enum size = impulses_size;
    for (int p = blip_res; p-- >= blip_res/2; ) {
      int p2 = blip_res-2-p;
      BlipBuffer.Int error = kernel_unit;
      for (int i = 1; i < size; i += blip_res) {
        error -= impulses[i+p];
        error -= impulses[i+p2];
      }
      if (p == p2) error /= 2; // phase = 0.5 impulse uses same half for both sides
      impulses[size-blip_res+p] += error;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void gen_sinc (float* aout, int count, double oversample, double treble, double cutoff) nothrow @trusted @nogc {
  import std.math : PI, cos, pow;

  if (cutoff > 0.999) cutoff = 0.999;
  if (treble < -300.0) treble = -300.0; else if (treble > 5.0) treble = 5.0;

  enum maxh = cast(double)4096.0;
  immutable double rolloff = pow(10.0, 1.0/(maxh*20.0)*treble/(1.0-cutoff));
  immutable double pow_a_n = pow(rolloff, maxh-maxh*cutoff);
  immutable double to_angle = PI/2/maxh/oversample;
  foreach (immutable int i; 0..count) {
    immutable double angle = ((i-count)*2+1)*to_angle;
    double c = rolloff * cos( (maxh - 1.0) * angle ) - cos( maxh * angle );
    immutable double cos_nc_angle = cos(maxh*cutoff*angle);
    immutable double cos_nc1_angle = cos((maxh*cutoff-1.0)*angle);
    immutable double cos_angle = cos(angle);

    c = c*pow_a_n-rolloff*cos_nc1_angle+cos_nc_angle;
    immutable double d = 1.0+rolloff*(rolloff-cos_angle-cos_angle);
    immutable double b = 2.0-cos_angle-cos_angle;
    immutable double a = 1.0-cos_angle-cos_nc_angle+cos_nc1_angle;

    aout[i] = cast(float)((a*d+c*b)/(b*d)); // a / b + c / d
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/+
Blip_Buffer 0.4.0 Notes
-----------------------
Author : Shay Green <hotpop.com@blargg>
Website: http://www.slack.net/~ant/
Forum  : http://groups.google.com/group/blargg-sound-libs

Overview
--------
Blip_Buffer buffers samples at the current sampling rate until they are read
out. Blip_Synth adds waveforms into a Blip_Buffer, specified by amplitude
changes at times given in the source clock rate. To generate sound, setup one
or more Blip_Buffers and Blip_Synths, add sound waves, then read samples as
needed.

Waveform amplitude changes are specified to Blip_Synth in time units at the
source clock rate, relative to the beginning of the current time frame. When a
time frame is ended at time T, what was time T becomes time 0, and all samples
before that are made available for reading from the Blip_Buffer using
read_samples(). Time frames can be whatever length is convenient, and can
differ in length from one frame to the next. Also, samples don't need to be
read immediately after each time frame; unread samples accumulate in the buffer
until they're read (but also reduce the available free space for new
synthesis).

This sets up a Blip_Buffer at a 1MHz input clock rate, 44.1kHz output sample
rate:

  Blip_Buffer buf;
  buf.clock_rate( 1000000 );
  if ( buf.set_sample_rate( 44100 ) )
    out_of_memory();

This sets up a Blip_Synth with good sound quality, an amplitude range of 20
(for a waveform that goes from -10 to 10), at 50% volume, outputting to buf:

  Blip_Synth<blip_good_quality,20> synth;
  synth.volume( 0.50 );
  synth.output( &buf );

See the demos for examples of adding a waveform and reading samples.


Treble and Bass Equalization
----------------------------
Treble and bass frequency equalization can be adjusted. Blip_Synth::treble_eq(
treble_dB ) sets the treble level (in dB), where 0.0 dB gives normal treble;
-200.0 dB is quite muffled, and 5.0 dB emphasizes treble for an extra crisp
sound. Blip_Buffer::bass_freq( freq_hz ) sets the frequency where bass response
starts to diminish; 15 Hz is normal, 0 Hz gives maximum bass, and 15000 Hz
removes all bass.

Bass    Treble      Type
- - - - - - - - - - - - - - - - - - - - - - - -
1 Hz     0.0 dB     Flat equalization
1 Hz    +5.0 dB     Extra crisp sound
16 Hz   -8.0 dB     Default equalization
180 Hz  -8.0 dB     TV Speaker
2000 Hz -47.0 dB    Handheld game speaker

For example, to simulate a TV speaker, call buf.bass_freq( 180 ) and
synth.treble_eq( -8.0 ). The best way to find parameters is to write a program
which allows interactive control over bass and treble.

For more information about blip_eq_t, which allows several parameters for
low-pass equalization, post to the forum.


Limitations
-----------
The length passed to Blip_Buffer::set_sample_rate() specifies the length of the
buffer in milliseconds. At the default time resolution, the resulting buffer
currently can't be more than about 65000 samples, which works out to almost
1500 milliseconds at the common 44.1kHz sample rate. This is much more than
necessary for most uses.

The output sample rate should be around 44-48kHz for best results. Since
synthesis is band-limited, there's almost no reason to use a higher sample
rate.

The ratio of input clock rate to output sample rate has limited precision (at
the default time resolution, rounded to nearest 1/65536th), so you won't get
the exact sample rate you requested. However, it is *exact*, so whatever the
input/output ratio is internally rounded to, it will generate exactly that many
output samples for each second of input. For example if you set the clock rate
to 768000 Hz and the sample rate to 48000 Hz (a ratio it can represent
exactly), there will always be exactly one sample generated for every 16 clocks
of input.

For an example of rounding, setting a clock rate of 1000000Hz (1MHz) and sample
rate of 44100 Hz results in an actual sample rate of 44097.9 Hz, causing an
unnoticeable shift in frequency. If you're running 60 frames of sound per
second and expecting exactly 735 samples each frame (to keep synchronized with
graphics), your code will require some changes. This isn't a problem in
practice because the computer's sound output itself probably doesn't run at
*exactly* the claimed sample rate, and it's better to synchronize graphics with
sound rather than the other way around. Put another way, even if this library
could generate exactly 735 samples per frame, every frame, you would still have
audio problems (try generating a sine wave manually and see). Post to the forum
if you'd like to discuss this issue further.


Advanced Topics
---------------
There are more advanced topics not covered here, some of which aren't fully
worked out. Some of these are: using multiple clock rates, more efficient
synthesis, higher resampling ratio accuracy, an mini-version in the C language,
sound quality issues, mixing samples directly into a Blip_Buffer. I lack
feedback from people using the library so I haven't been able to complete
design of these features. Post to the forum and we can work on adding these
features.


Solving Problems
----------------
If you're having problems, try the following:

- Enable debugging support in your environment. This enables assertions and
other run-time checks.

- Turn the compiler's optimizer is off. Sometimes an optimizer generates bad
code.

- If multiple threads are being used, ensure that only one at a time is
accessing objects from the library. This library is not in general thread-safe,
though independent objects can be used in separate threads.

- If all else fails, see if the demos work.


Internal Operation
------------------
Understanding the basic internal operation might help in proper use of
Blip_Synth. There are two main aspects: what Blip_Synth does, and how samples
are stored internally to Blip_Buffer. A description of the core algorithm and
example code showing the essentials is available on the web:

  http://www.slack.net/~ant/bl-synth/

When adding a band-limited amplitude transition, the waveform differs based on
the relative position of the transition with respect to output samples. Adding
a transition between two samples requires a different waveform than one
centered on one sample. Blip_Synth stores the waveforms at several small
increments of differing alignment and selects the proper one based on the
source time.

Blip_Synth adds step waveforms, which start at zero and end up at the final
amplitude, extending infinitely into the future. This would be hard to handle
given a finite buffer size, so the sample buffer holds the *differences*
between each sample, rather than the absolute sample values. For example, the
waveform 0, 0, 1, 1, 1, 0, 0 is stored in a Blip_Buffer as 0, 0, +1, 0, 0, -1,
0. With this scheme, adding a change in amplitude at any position in the buffer
simply requires adding the proper values around that position; no other samples
in the buffer need to be modified. The extension of the final amplitude occurs
when reading samples out, by keeping a running sum of all samples up to
present.

The above should make it clearer how Blip_Synth::offset() gets its flexibility,
and that there is no penalty for making full use of this by adding amplitude
transitions in whatever order is convenient. Blip_Synth::update() simply keeps
track of the current amplitude and calls offset() with the change, so it's no
worse except being limited to a single waveform.


Thanks
------
Thanks to Jsr (FamiTracker author), the Mednafen team (multi-system emulator),
and ShizZie (Nhes GMB author) for using and giving feedback for the library.
Thanks to Disch for his interest and discussions about the synthesis algorithm
itself, and for writing his own implementation of it (Schpune). Thanks to
Xodnizel for Festalon, whose sound quality got me interested in video game
sound emulation in the first place, and where I first came up with the
algorithm while optimizing its brute-force filter.
+/
