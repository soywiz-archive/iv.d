/*
** Copyright (C) 2002-2011 Erik de Castro Lopo <erikd@mega-nerd.com>
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.
*/
/*
** This code is part of Secret Rabbit Code aka libsamplerate. A commercial
** use license for this code is available, please see:
**    http://www.mega-nerd.com/SRC/procedure.html
*/
module iv.secretrabbit;

//version = lib_secret_rabbit_allow_hq_filter;
//version = lib_secret_rabbit_do_additional_checks;

version(lib_secret_rabbit_allow_hq_filter) enum rabbitHasHQ = true; else enum rabbitHasHQ = false;


// ////////////////////////////////////////////////////////////////////////// //
static if (!is(usize == size_t)) alias usize = size_t;


// ////////////////////////////////////////////////////////////////////////// //
public struct SecretRabbit {
public:
  enum Error {
    OK = 0,
    Memory,
    BadData,
    BadRatio,
    NotInitialized,
    BadConverter,
    BadChannelCount,
    DataAfterEOS,
    DataOverlaps,
  }

  enum Type {
    Best,
    Medium,
    Fast,
  }

  // Data is used to pass data to `process()`
  static struct Data {
    float[] dataIn, dataOut; // samples; `.length%channel` must be 0!
    // alas, we can't change `.length` in @nogc, so...
    usize inputUsed, outputUsed; // in array items, not frames!
    bool endOfInput; // set if this is the last input chunk
    double srcRatio; // destinationSampleRate/sourceSampleRate
  }

private:
  // private filter data
  double lastRatio, lastPosition;

  Error lastError;
  int channels;
  bool wasEOI;
  Type interpType;

  // private data for interpolators
  usize inCount, inUsed;
  usize outCount, outUsed;

  // sinc data
  int indexInc;

  double srcRatio, inputIndex;

  immutable(float)[] coeffs;

  int bCurrent, bEnd, bRealEnd, bLen;

  // sure hope noone does more than 128 channels at once
  double[128] leftCalc;
  union {
    double[128] rightCalc;
    float[128] lastValue;
  }

  float* buffer; // malloced

  // other interpolators (linear and zoh)
  bool resetFlt;
  //float[128] lastValue;
  //alias lastValue = leftCalc;

  // processing functions
  Error function (ref SecretRabbit filter, ref Data data) nothrow @trusted @nogc processFn; // process function
  void function (ref SecretRabbit filter) nothrow @trusted @nogc resetFn; // state reset
  void function (ref SecretRabbit filter) nothrow @trusted @nogc deinitFn; // free additional memory, etc

nothrow @trusted @nogc:
public:
  this (Type flt, int chans) { setup(flt, chans); }
  ~this () { deinit(); }

  @disable this (this); // no copies

  @property Error error () pure const { return lastError; }
  @property Type type () pure const { return interpType; }
  @property bool wasComplete () pure const { return wasEOI; }

  void setup (Type flt, int chans) {
    deinit();
    if (chans < 1 || chans > leftCalc.length) { lastError = Error.BadChannelCount; return; }
    interpType = flt;
    channels = chans;
    if ((lastError = setupSinc(flt)) != 0) return;
    reset();
  }

  void deinit () {
    if (buffer !is null) {
      import core.stdc.stdlib : free;
      free(buffer);
      buffer = null;
    }
    processFn = null;
    lastError = Error.OK;
    channels = 0;
    wasEOI = false;
    coeffs = null;
  }

  // `data.inputUsed` and `data.outputUsed` will be set
  Error process (ref Data data) {
    import std.math : isNaN;

    // set the input and output counts to zero
    data.inputUsed = data.outputUsed = 0;

    if (processFn is null) return (lastError = Error.NotInitialized);

    // check for valid Data first
    if (data.dataIn.length > 0 && wasEOI) return (lastError = Error.DataAfterEOS);
    if (data.endOfInput) wasEOI = true;

    // and that dataIn and dataOut are valid
    if (data.dataOut.length == 0 || data.dataIn.length%channels != 0 || data.dataOut.length%channels != 0) return (lastError = Error.BadData);

    // check srcRatio is in range
    if (isBadSrcRatio(data.srcRatio)) return (lastError = Error.BadRatio);

    if (data.dataIn.ptr < data.dataOut.ptr) {
      if (data.dataIn.ptr+data.dataIn.length > data.dataOut.ptr) return (lastError = Error.DataOverlaps);
    } else if (data.dataOut.ptr+data.dataOut.length > data.dataIn.ptr) {
      return (lastError = Error.DataOverlaps);
    }

    // special case for when lastRatio has not been set
    if (isNaN(lastRatio) || lastRatio < (1.0/SRC_MAX_RATIO)) lastRatio = data.srcRatio;

    // now process
    lastError = processFn(this, data);

    data.inputUsed = inUsed/*/filter.channels*/;
    data.outputUsed = outUsed/*/filter.channels*/;

    return lastError;
  }

  // use this to immediately change resampling ratio instead of nicely sliding to it
  Error setRatio (double newRatio) {
    if (processFn is null) return (lastError = Error.NotInitialized);
    if (isBadSrcRatio(newRatio)) return (lastError = Error.BadRatio);
    lastRatio = newRatio;
    return (lastError = Error.OK);
  }

  // if you want to start new conversion from the scratch, reset resampler
  Error reset () {
    import core.stdc.string : memset;
    lastPosition = 0.0;
    lastRatio = 0.0; // really?
    wasEOI = false;
    resetFlt = true;
    // sinc reset
    bCurrent = bEnd = 0;
    bRealEnd = -1;
    srcRatio = inputIndex = 0.0;
    if (buffer !is null) {
      if (bLen > 0) buffer[0..bLen] = 0;
      // set this for a sanity check
      memset(buffer+bLen, 0xAA, channels*buffer[0].sizeof);
    }
    leftCalc[] = 0;
    rightCalc[] = 0;
    //lastValue[] = 0;
    return (lastError = Error.OK);
  }

private:
  Error setupSinc (Type flt) nothrow @trusted @nogc {
    import core.stdc.math : lrint;
    import core.stdc.stdlib : malloc;

    switch (channels) {
      case 1: processFn = &sincMonoProcessor; break;
      case 2: processFn = &sincStereoProcessor; break;
      default: processFn = &sincMultiChanProcessor; break;
    }

    switch (flt) with (Type) {
      case Fast:
        coeffs = coeffsFT.coeffs;
        indexInc = coeffsFT.increment;
        break;
      case Medium:
        coeffs = coeffsMD.coeffs;
        indexInc = coeffsMD.increment;
        break;
      case Best:
        version(lib_secret_rabbit_allow_hq_filter) {
          coeffs = coeffsHQ.coeffs;
          indexInc = coeffsHQ.increment;
        } else {
          // use "medium" filter if we were compiled without "hq" one
          coeffs = coeffsMD.coeffs;
          indexInc = coeffsMD.increment;
        }
        break;
      default:
        return Error.BadConverter;
    }

    /*
     * FIXME : This needs to be looked at more closely to see if there is
     * a better way. Need to look at prepareData() at the same time.
     */

    bLen = lrint(2.5*(cast(int)coeffs.length-1)/(indexInc*1.0)*SRC_MAX_RATIO);
    bLen = max(bLen, 4096);
    bLen *= channels;

    buffer = cast(float*)malloc(buffer[0].sizeof*(bLen+channels));
    if (buffer is null) return Error.Memory;
    //buffer = buf[0..bLen+channels];

    version(lib_secret_rabbit_do_additional_checks) {
      import core.stdc.stdlib : free;
      int count = (cast(int)coeffs.length-1);
      int bits = void;
      for (bits = 0; (1<<bits) < count; ++bits) count |= (1<<bits);
      if (bits+SHIFT_BITS-1 >= int.sizeof*8) {
        free(buffer);
        assert(0, "SecretRabbit: corrupted filter data!");
      }
    }

    return Error.OK;
  }

public:
static:
  string errorStr (Error err) pure { static if (__VERSION__ > 2067) pragma(inline, true); return (err >= Error.min && err <= Error.max ? rabbitErrorStrings[err] : "rabbit-wtf"); }
  string name (Type flt) pure { static if (__VERSION__ > 2067) pragma(inline, true); return (flt >= Type.min && flt <= Type.max ? rabbitFilterNames[flt] : "invalid interpolator type"); }
  string description (Type flt) pure { static if (__VERSION__ > 2067) pragma(inline, true); return (flt >= Type.min && flt <= Type.max ? rabbitFilterDescs[flt] : "invalid interpolator type"); }
  bool isValidRatio (double ratio) pure { static if (__VERSION__ > 2067) pragma(inline, true); return !isBadSrcRatio(ratio); }

  // will not resize output
  void short2float (in short[] input, float[] output) {
    if (output.length < input.length) assert(0, "invalid length");
    foreach (immutable idx, short v; input) output.ptr[idx] = cast(float)(v/(1.0*0x8000));
  }

  // will not resize output
  void float2short (in float[] input, short[] output) {
    import core.stdc.math : lrint;
    double scaledValue = void;
    if (output.length < input.length) assert(0, "invalid length");
    foreach (immutable idx, float v; input) {
      scaledValue = v*(8.0*0x10000000);
      if (scaledValue >= 1.0*0x7FFFFFFF) output.ptr[idx] = 32767;
      else if (scaledValue <= -8.0*0x10000000) output.ptr[idx] = -32768;
      else output.ptr[idx] = cast(short)(lrint(scaledValue)>>16);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum SRC_MAX_RATIO = 256;
enum SRC_MIN_RATIO_DIFF = (1.0e-20);


// ////////////////////////////////////////////////////////////////////////// //
immutable string[SecretRabbit.Error.max+1] rabbitErrorStrings = [
  "no error",
  "out of memory",
  "invalid data passed",
  "ratio outside [1/256, 256] range",
  "trying to use uninitialized filter",
  "bad converter number",
  "channel count must be >= 1 and <= 128",
  "process() called without reset after end of input",
  "input and output data arrays overlap",
];

immutable string[SecretRabbit.Type.max+1] rabbitFilterNames = [
  "Best Sinc Interpolator",
  "Medium Sinc Interpolator",
  "Fastest Sinc Interpolator",
];

immutable string[SecretRabbit.Type.max+1] rabbitFilterDescs = [
  "Band limited sinc interpolation, fastest, 97dB SNR, 80% BW",
  "Band limited sinc interpolation, medium quality, 121dB SNR, 90% BW",
  "Band limited sinc interpolation, best quality, 145dB SNR, 96% BW",
];


// ////////////////////////////////////////////////////////////////////////// //
// sinc interpolator blobs
static struct CoeffData {
  int increment;
  float[] coeffs;
}

version(lib_secret_rabbit_allow_hq_filter) immutable CoeffData coeffsHQ;
immutable CoeffData coeffsMD, coeffsFT;

shared static this () {
  version(lib_secret_rabbit_allow_hq_filter) immutable coeffs_hq_data = import("secretrabbit/coeffs_hq.bin");
  immutable coeffs_md_data = import("secretrabbit/coeffs_md.bin");
  immutable coeffs_ft_data = import("secretrabbit/coeffs_ft.bin");

  version(lib_secret_rabbit_allow_hq_filter) {
    coeffsHQ.increment = *(cast(immutable(int)*)coeffs_hq_data);
    coeffsHQ.coeffs = (cast(immutable(float)*)(coeffs_hq_data.ptr+4))[0..(coeffs_hq_data.length-4)/4];
  }

  coeffsMD.increment = *(cast(immutable(int)*)coeffs_md_data);
  coeffsMD.coeffs = (cast(immutable(float)*)(coeffs_md_data.ptr+4))[0..(coeffs_md_data.length-4)/4];

  coeffsFT.increment = *(cast(immutable(int)*)coeffs_ft_data);
  coeffsFT.coeffs = (cast(immutable(float)*)(coeffs_ft_data.ptr+4))[0..(coeffs_ft_data.length-4)/4];
}


// ////////////////////////////////////////////////////////////////////////// //
enum SHIFT_BITS = 12;
enum FP_ONE = cast(double)(1<<SHIFT_BITS);
enum INV_FP_ONE = (1.0/FP_ONE);

// quick sanity check
static assert(SHIFT_BITS < int.sizeof*8-1, "internal error: SHIFT_BITS too large");

// ////////////////////////////////////////////////////////////////////////// //
bool isBadSrcRatio() (double ratio) { static if (__VERSION__ > 2067) pragma(inline, true); import std.math : isNaN; return (isNaN(ratio) || ratio < (1.0/SRC_MAX_RATIO) || ratio > (1.0*SRC_MAX_RATIO)); }

double fmodOne() (double x) {
  static if (__VERSION__ > 2067) pragma(inline, true);
  import core.stdc.math : lrint;
  double res = x-lrint(x);
  return (res < 0.0 ? res+1.0 : res);
}

T min(T) (T v0, T v1) { static if (__VERSION__ > 2067) pragma(inline, true); return (v0 < v1 ? v0 : v1); }
T max(T) (T v0, T v1) { static if (__VERSION__ > 2067) pragma(inline, true); return (v0 < v1 ? v1 : v0); }
T fabs(T) (T v) { static if (__VERSION__ > 2067) pragma(inline, true); return (v < 0 ? -v : v); }

int double2fp() (double x) { static if (__VERSION__ > 2067) pragma(inline, true); import core.stdc.math : lrint; return (lrint((x)*FP_ONE)); } /* double2fp */
int int2fp() (int x) { static if (__VERSION__ > 2067) pragma(inline, true); return (x<<SHIFT_BITS); } /* int2fp */
int fp2int() (int x) { static if (__VERSION__ > 2067) pragma(inline, true); return (x>>SHIFT_BITS); } /* fp2int */
int fpfrac() (int x) { static if (__VERSION__ > 2067) pragma(inline, true); return (x&((1<<SHIFT_BITS)-1)); } /* fpfrac */
double fp2double() (int x) { static if (__VERSION__ > 2067) pragma(inline, true); return fpfrac(x)*INV_FP_ONE; } /* fp2double */


// ////////////////////////////////////////////////////////////////////////// //
// Beware all ye who dare pass this point. There be dragons here.
double sincCalcOutputMono (ref SecretRabbit filter, int increment, int startFilterIndex) nothrow @trusted @nogc {
  double fraction, left, right, icoeff;
  int filterIndex, maxFilterIndex;
  int dataIndex, coeffCount, indx;

  // convert input parameters into fixed point
  maxFilterIndex = int2fp((cast(int)filter.coeffs.length-1));

  // first apply the left half of the filter
  filterIndex = startFilterIndex;
  coeffCount = (maxFilterIndex-filterIndex)/increment;
  filterIndex = filterIndex+coeffCount*increment;
  dataIndex = filter.bCurrent-coeffCount;

  left = 0.0;
  do {
    fraction = fp2double(filterIndex);
    indx = fp2int(filterIndex);
    icoeff = filter.coeffs.ptr[indx]+fraction*(filter.coeffs.ptr[indx+1]-filter.coeffs.ptr[indx]);
    left += icoeff*filter.buffer[dataIndex];
    filterIndex -= increment;
    dataIndex = dataIndex+1;
  } while (filterIndex >= 0);

  // now apply the right half of the filter
  filterIndex = increment-startFilterIndex;
  coeffCount = (maxFilterIndex-filterIndex)/increment;
  filterIndex = filterIndex+coeffCount*increment;
  dataIndex = filter.bCurrent+1+coeffCount;

  right = 0.0;
  do {
    fraction = fp2double(filterIndex);
    indx = fp2int(filterIndex);
    icoeff = filter.coeffs.ptr[indx]+fraction*(filter.coeffs.ptr[indx+1]-filter.coeffs.ptr[indx]);
    right += icoeff*filter.buffer[dataIndex];
    filterIndex -= increment;
    dataIndex = dataIndex-1;
  } while (filterIndex > 0);

  return left+right;
}


SecretRabbit.Error sincMonoProcessor (ref SecretRabbit filter, ref SecretRabbit.Data data) nothrow @trusted @nogc {
  import core.stdc.math : lrint;

  double inputIndex, srcRatio, count, floatIncrement, terminate, rem;
  int increment, startFilterIndex;
  int halfFilterChanLen, samplesInHand;

  filter.inCount = data.dataIn.length/*mul chans*/;
  filter.outCount = data.dataOut.length/*mul chans*/;
  filter.inUsed = filter.outUsed = 0;

  srcRatio = filter.lastRatio;

  // check the sample rate ratio wrt the buffer len
  count = ((cast(int)filter.coeffs.length-1)+2.0)/filter.indexInc;
  if (min(filter.lastRatio, data.srcRatio) < 1.0) count /= min(filter.lastRatio, data.srcRatio);

  // maximum coefficientson either side of center point
  halfFilterChanLen = filter.channels*(lrint(count)+1);

  inputIndex = filter.lastPosition;
  floatIncrement = filter.indexInc;

  rem = fmodOne (inputIndex);
  filter.bCurrent = (filter.bCurrent+filter.channels*lrint(inputIndex-rem))%filter.bLen;
  inputIndex = rem;

  terminate = 1.0/srcRatio+1.0e-20;

  // main processing loop
  while (filter.outUsed < filter.outCount) {
    // need to reload buffer?
    samplesInHand = (filter.bEnd-filter.bCurrent+filter.bLen)%filter.bLen;

    if (samplesInHand <= halfFilterChanLen) {
      prepareData(filter, data, halfFilterChanLen);
      samplesInHand = (filter.bEnd-filter.bCurrent+filter.bLen)%filter.bLen;
      if (samplesInHand <= halfFilterChanLen) break;
    }

    // this is the termination condition
    if (filter.bRealEnd >= 0 && filter.bCurrent+inputIndex+terminate >= filter.bRealEnd) break;

    if (filter.outCount > 0 && fabs(filter.lastRatio-data.srcRatio) > 1.0e-10) {
      srcRatio = filter.lastRatio+filter.outUsed*(data.srcRatio-filter.lastRatio)/filter.outCount;
    }

    floatIncrement = filter.indexInc*1.0;
    if (srcRatio < 1.0) floatIncrement = filter.indexInc*srcRatio;

    increment = double2fp(floatIncrement);

    startFilterIndex = double2fp(inputIndex*floatIncrement);

    data.dataOut.ptr[filter.outUsed] = cast(float)((floatIncrement/filter.indexInc)*sincCalcOutputMono(filter, increment, startFilterIndex));
    ++filter.outUsed;

    // figure out the next index
    inputIndex += 1.0/srcRatio;
    rem = fmodOne(inputIndex);

    filter.bCurrent = (filter.bCurrent+filter.channels*lrint(inputIndex-rem))%filter.bLen;
    inputIndex = rem;
  }

  filter.lastPosition = inputIndex;

  // save current ratio rather then target ratio
  filter.lastRatio = srcRatio;

  return SecretRabbit.Error.OK;
}


// ////////////////////////////////////////////////////////////////////////// //
void sincCalcOutputStereo (ref SecretRabbit filter, int increment, int startFilterIndex, double scale, float* output) nothrow @trusted @nogc {
  double fraction, icoeff;
  double[2] left, right;
  int filterIndex, maxFilterIndex;
  int dataIndex, coeffCount, indx;

  // convert input parameters into fixed point
  maxFilterIndex = int2fp((cast(int)filter.coeffs.length-1));

  // first apply the left half of the filter
  filterIndex = startFilterIndex;
  coeffCount = (maxFilterIndex-filterIndex)/increment;
  filterIndex = filterIndex+coeffCount*increment;
  dataIndex = filter.bCurrent-filter.channels*coeffCount;

  left.ptr[0] = left.ptr[1] = 0.0;
  do {
    fraction = fp2double(filterIndex);
    indx = fp2int(filterIndex);
    icoeff = filter.coeffs.ptr[indx]+fraction*(filter.coeffs.ptr[indx+1]-filter.coeffs.ptr[indx]);
    left.ptr[0] += icoeff*filter.buffer[dataIndex];
    left.ptr[1] += icoeff*filter.buffer[dataIndex+1];
    filterIndex -= increment;
    dataIndex = dataIndex+2;
  } while (filterIndex >= 0);

  // now apply the right half of the filter
  filterIndex = increment-startFilterIndex;
  coeffCount = (maxFilterIndex-filterIndex)/increment;
  filterIndex = filterIndex+coeffCount*increment;
  dataIndex = filter.bCurrent+filter.channels*(1+coeffCount);

  right.ptr[0] = right.ptr[1] = 0.0;
  do {
    fraction = fp2double (filterIndex);
    indx = fp2int (filterIndex);
    icoeff = filter.coeffs.ptr[indx]+fraction*(filter.coeffs.ptr[indx+1]-filter.coeffs.ptr[indx]);
    right.ptr[0] += icoeff*filter.buffer[dataIndex];
    right.ptr[1] += icoeff*filter.buffer[dataIndex+1];
    filterIndex -= increment;
    dataIndex = dataIndex-2;
  } while (filterIndex > 0);

  output[0] = scale*(left.ptr[0]+right.ptr[0]);
  output[1] = scale*(left.ptr[1]+right.ptr[1]);
}


SecretRabbit.Error sincStereoProcessor (ref SecretRabbit filter, ref SecretRabbit.Data data) nothrow @trusted @nogc {
  import core.stdc.math : lrint;

  double inputIndex, srcRatio, count, floatIncrement, terminate, rem;
  int increment, startFilterIndex;
  int halfFilterChanLen, samplesInHand;

  filter.inCount = data.dataIn.length/*mul chans*/;
  filter.outCount = data.dataOut.length/*mul chans*/;
  filter.inUsed = filter.outUsed = 0;

  srcRatio = filter.lastRatio;

  // check the sample rate ratio wrt the buffer len
  count = ((cast(int)filter.coeffs.length-1)+2.0)/filter.indexInc;
  if (min(filter.lastRatio, data.srcRatio) < 1.0) count /= min(filter.lastRatio, data.srcRatio);

  // maximum coefficientson either side of center point
  halfFilterChanLen = filter.channels*(lrint(count)+1);

  inputIndex = filter.lastPosition;
  floatIncrement = filter.indexInc;

  rem = fmodOne(inputIndex);
  filter.bCurrent = (filter.bCurrent+filter.channels*lrint(inputIndex-rem))%filter.bLen;
  inputIndex = rem;

  terminate = 1.0/srcRatio+1e-20;

  // main processing loop
  while (filter.outUsed < filter.outCount) {
    // need to reload buffer?
    samplesInHand = (filter.bEnd-filter.bCurrent+filter.bLen)%filter.bLen;

    if (samplesInHand <= halfFilterChanLen) {
      prepareData(filter, data, halfFilterChanLen);
      samplesInHand = (filter.bEnd-filter.bCurrent+filter.bLen)%filter.bLen;
      if (samplesInHand <= halfFilterChanLen) break;
    }

    // this is the termination condition
    if (filter.bRealEnd >= 0 && filter.bCurrent+inputIndex+terminate >= filter.bRealEnd) break;

    if (filter.outCount > 0 && fabs(filter.lastRatio-data.srcRatio) > 1.0e-10) {
      srcRatio = filter.lastRatio+filter.outUsed*(data.srcRatio-filter.lastRatio)/filter.outCount;
    }

    floatIncrement = filter.indexInc*1.0;
    if (srcRatio < 1.0) floatIncrement = filter.indexInc*srcRatio;

    increment = double2fp(floatIncrement);

    startFilterIndex = double2fp(inputIndex*floatIncrement);

    sincCalcOutputStereo(filter, increment, startFilterIndex, floatIncrement/filter.indexInc, data.dataOut.ptr+filter.outUsed);
    filter.outUsed += 2;

    // figure out the next index
    inputIndex += 1.0/srcRatio;
    rem = fmodOne(inputIndex);

    filter.bCurrent = (filter.bCurrent+filter.channels*lrint(inputIndex-rem))%filter.bLen;
    inputIndex = rem;
  }

  filter.lastPosition = inputIndex;

  // save current ratio rather then target ratio
  filter.lastRatio = srcRatio;

  return SecretRabbit.Error.OK;
}


// ////////////////////////////////////////////////////////////////////////// //
void sincCalcOutputMultiChan (ref SecretRabbit filter, int increment, int startFilterIndex, int channels, double scale, float* output) nothrow @trusted @nogc {
  double fraction, icoeff;
  double* left, right;
  int filterIndex, maxFilterIndex;
  int dataIndex, coeffCount, indx, ch;

  left = filter.leftCalc.ptr;
  right = filter.rightCalc.ptr;

  // convert input parameters into fixed point
  maxFilterIndex = int2fp((cast(int)filter.coeffs.length-1));

  // first apply the left half of the filter
  filterIndex = startFilterIndex;
  coeffCount = (maxFilterIndex-filterIndex)/increment;
  filterIndex = filterIndex+coeffCount*increment;
  dataIndex = filter.bCurrent-channels*coeffCount;

  //memset(left, 0, left[0].sizeof*channels);
  left[0..channels] = 0;
  do {
    fraction = fp2double(filterIndex);
    indx = fp2int(filterIndex);
    icoeff = filter.coeffs.ptr[indx]+fraction*(filter.coeffs.ptr[indx+1]-filter.coeffs.ptr[indx]);
    /*
    **  Duff's Device.
    **  See : http://en.wikipedia.org/wiki/Duff's_device
    */
    ch = channels;
    do {
      switch (ch%8) {
        default:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 7:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 6:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 5:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 4:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 3:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 2:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 1:
          --ch;
          left[ch] += icoeff*filter.buffer[dataIndex+ch];
          break;
      }
    } while (ch > 0);

    filterIndex -= increment;
    dataIndex = dataIndex+channels;
  } while (filterIndex >= 0);

  // now apply the right half of the filter
  filterIndex = increment-startFilterIndex;
  coeffCount = (maxFilterIndex-filterIndex)/increment;
  filterIndex = filterIndex+coeffCount*increment;
  dataIndex = filter.bCurrent+channels*(1+coeffCount);

  //memset(right, 0, right[0].sizeof*channels);
  right[0..channels] = 0;
  do {
    fraction = fp2double (filterIndex);
    indx = fp2int (filterIndex);
    icoeff = filter.coeffs.ptr[indx]+fraction*(filter.coeffs.ptr[indx+1]-filter.coeffs.ptr[indx]);
    ch = channels;
    do {
      switch (ch%8) {
        default:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 7:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 6:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 5:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 4:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 3:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 2:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          goto case;
        case 1:
          --ch;
          right[ch] += icoeff*filter.buffer[dataIndex+ch];
          break;
      }
    } while (ch > 0);

    filterIndex -= increment;
    dataIndex = dataIndex-channels;
  } while (filterIndex > 0);

  ch = channels;
  do {
    switch (ch%8) {
      default:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 7:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 6:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 5:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 4:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 3:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 2:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        goto case;
      case 1:
        --ch;
        output[ch] = scale*(left[ch]+right[ch]);
        break;
    }
  } while (ch > 0);
}


SecretRabbit.Error sincMultiChanProcessor (ref SecretRabbit filter, ref SecretRabbit.Data data) nothrow @trusted @nogc {
  import core.stdc.math : lrint;

  double inputIndex, srcRatio, count, floatIncrement, terminate, rem;
  int increment, startFilterIndex;
  int halfFilterChanLen, samplesInHand;

  filter.inCount = data.dataIn.length/*mul chans*/;
  filter.outCount = data.dataOut.length/*mul chans*/;
  filter.inUsed = filter.outUsed = 0;

  srcRatio = filter.lastRatio;

  // check the sample rate ratio wrt the buffer len
  count = ((cast(int)filter.coeffs.length-1)+2.0)/filter.indexInc;
  if (min(filter.lastRatio, data.srcRatio) < 1.0) count /= min(filter.lastRatio, data.srcRatio);

  // maximum coefficientson either side of center point
  halfFilterChanLen = filter.channels*(lrint(count)+1);

  inputIndex = filter.lastPosition;
  floatIncrement = filter.indexInc;

  rem = fmodOne (inputIndex);
  filter.bCurrent = (filter.bCurrent+filter.channels*lrint(inputIndex-rem))%filter.bLen;
  inputIndex = rem;

  terminate = 1.0/srcRatio+1e-20;

  // main processing loop
  while (filter.outUsed < filter.outCount) {
    // need to reload buffer?
    samplesInHand = (filter.bEnd-filter.bCurrent+filter.bLen)%filter.bLen;

    if (samplesInHand <= halfFilterChanLen) {
      prepareData(filter, data, halfFilterChanLen);
      samplesInHand = (filter.bEnd-filter.bCurrent+filter.bLen)%filter.bLen;
      if (samplesInHand <= halfFilterChanLen) break;
    }

    // this is the termination condition
    if (filter.bRealEnd >= 0 && filter.bCurrent+inputIndex+terminate >= filter.bRealEnd) break;

    if (filter.outCount > 0 && fabs(filter.lastRatio-data.srcRatio) > 1.0e-10) {
      srcRatio = filter.lastRatio+filter.outUsed*(data.srcRatio-filter.lastRatio)/filter.outCount;
    }

    floatIncrement = filter.indexInc*1.0;
    if (srcRatio < 1.0) floatIncrement = filter.indexInc*srcRatio;

    increment = double2fp(floatIncrement);

    startFilterIndex = double2fp(inputIndex*floatIncrement);

    sincCalcOutputMultiChan(filter, increment, startFilterIndex, filter.channels, floatIncrement/filter.indexInc, data.dataOut.ptr+filter.outUsed);
    filter.outUsed += filter.channels;

    /* Figure out the next index. */
    inputIndex += 1.0/srcRatio;
    rem = fmodOne(inputIndex);

    filter.bCurrent = (filter.bCurrent+filter.channels*lrint(inputIndex-rem))%filter.bLen;
    inputIndex = rem;
  }

  filter.lastPosition = inputIndex;

  // save current ratio rather then target ratio
  filter.lastRatio = srcRatio;

  return SecretRabbit.Error.OK;
}


// ////////////////////////////////////////////////////////////////////////// //
void prepareData (ref SecretRabbit filter, ref SecretRabbit.Data data, int halfFilterChanLen) nothrow @trusted @nogc {
  import core.stdc.string : memcpy, memmove, memset;

  int len = 0;
  if (filter.bRealEnd >= 0) return; // should be terminating: just return
  if (filter.bCurrent == 0) {
    // initial state. Set up zeros at the start of the buffer and then load new data after that
    len = filter.bLen-2*halfFilterChanLen;
    filter.bCurrent = filter.bEnd = halfFilterChanLen;
  } else if (filter.bEnd+halfFilterChanLen+filter.channels < filter.bLen) {
    // load data at current end position
    len = max(filter.bLen-filter.bCurrent-halfFilterChanLen, 0);
  } else {
    // move data at end of buffer back to the start of the buffer
    len = filter.bEnd-filter.bCurrent;
    memmove(filter.buffer, filter.buffer+filter.bCurrent-halfFilterChanLen, (halfFilterChanLen+len)*filter.buffer[0].sizeof);
    filter.bCurrent = halfFilterChanLen;
    filter.bEnd = filter.bCurrent+len;
    // now load data at current end of buffer
    len = max(filter.bLen-filter.bCurrent-halfFilterChanLen, 0);
  }
  len = min(filter.inCount-filter.inUsed, len);
  len -= (len%filter.channels);
  if (len < 0 || filter.bEnd+len > filter.bLen) assert(0, "SecretRabbit internal error: bad length in prepareData()");
  memcpy(filter.buffer+filter.bEnd, data.dataIn.ptr+filter.inUsed, len*filter.buffer[0].sizeof);
  filter.bEnd += len;
  filter.inUsed += len;
  if (filter.inUsed == filter.inCount && filter.bEnd-filter.bCurrent < 2*halfFilterChanLen && data.endOfInput) {
    // handle the case where all data in the current buffer has been consumed and this is the last buffer
    if (filter.bLen-filter.bEnd < halfFilterChanLen+5) {
      // if necessary, move data down to the start of the buffer
      len = filter.bEnd-filter.bCurrent;
      memmove(filter.buffer, filter.buffer+filter.bCurrent-halfFilterChanLen, (halfFilterChanLen+len)*filter.buffer[0].sizeof);
      filter.bCurrent = halfFilterChanLen;
      filter.bEnd = filter.bCurrent+len;
    }
    filter.bRealEnd = filter.bEnd;
    len = halfFilterChanLen+5;
    if (len < 0 || filter.bEnd+len > filter.bLen) len = filter.bLen-filter.bEnd;
    memset(filter.buffer+filter.bEnd, 0, len*filter.buffer[0].sizeof);
    filter.bEnd += len;
  }
}
