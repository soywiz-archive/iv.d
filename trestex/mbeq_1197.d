// code from LADSPA plugins project: http://plugin.org.uk/
// GNU GPLv3
module mbeq_1197;
private:
nothrow @trusted @nogc:

// ////////////////////////////////////////////////////////////////////////// //
//version = FFTW3;

version(FFTW3) {
  pragma(lib, "fftw3f");
  alias fft_plan = void*;
  alias fftw_real = float;
  extern(C) nothrow @trusted @nogc {
    enum FFTW_MEASURE = 0;
    enum { FFTW_R2HC=0, FFTW_HC2R=1, FFTW_DHT=2 }
    fft_plan fftwf_plan_r2r_1d (int n, fftw_real* inp, fftw_real* outp, size_t kind, uint flags);
    void fftwf_execute (fft_plan plan);
  }
} else {
  import kissfft;
  alias fft_plan = kiss_fftr_cfg;
  alias fftw_real = kiss_fft_scalar;
}


// ////////////////////////////////////////////////////////////////////////// //
public struct MBEQ {
public:
  enum FFT_LENGTH = 1024;
  enum OVER_SAMP = 4;
  enum BANDS = 15;

public:
  // [-70..30]
  // 50Hz gain (low shelving)
  // 100Hz gain (float value)
  // 156Hz gain (float value)
  // 220Hz gain (float value)
  // 311Hz gain (float value)
  // 440Hz gain (float value)
  // 622Hz gain (float value)
  // 880Hz gain (float value)
  // 1250Hz gain (float value)
  // 1750Hz gain (float value)
  // 2500Hz gain (float value)
  // 3500Hz gain (float value)
  // 5000Hz gain (float value)
  // 10000Hz gain (float value)
  // 20000Hz gain (float value)
  float[BANDS] bands = 0;
  //float* input;
  //float* output;
  int latency;
  int* bin_base;
  float* bin_delta;
  fftw_real* comp;
  float* db_table;
  uint fifo_pos;
  float* in_fifo;
  float* out_accum;
  float* out_fifo;
  fft_plan plan_cr;
  fft_plan plan_rc;
  fftw_real* realx;
  float* window;
  int s_rate;

  this (int asrate) {
    setup(asrate);
  }

  ~this () {
    cleanup();
  }

  void setup (int asrate) {
    import std.math : cos, pow, PI;

    cleanup();
    //scope(failure) cleanup();

    if (asrate < 1024 || asrate > 48000) assert(0, "invalid sampling rate");
    s_rate = asrate;
    float hz_per_bin = cast(float)s_rate/cast(float)FFT_LENGTH;

    zalloc(in_fifo, FFT_LENGTH);
    zalloc(out_fifo, FFT_LENGTH);
    zalloc(out_accum, FFT_LENGTH*2);
    zalloc(realx, FFT_LENGTH+16);
    zalloc(comp, FFT_LENGTH+16);
    zalloc(window, FFT_LENGTH);
    zalloc(bin_base, FFT_LENGTH/2);
    zalloc(bin_delta, FFT_LENGTH/2);
    fifo_pos = 0;

    version(FFTW3) {
      plan_rc = fftwf_plan_r2r_1d(FFT_LENGTH, realx, comp, FFTW_R2HC, FFTW_MEASURE);
      plan_cr = fftwf_plan_r2r_1d(FFT_LENGTH, comp, realx, FFTW_HC2R, FFTW_MEASURE);
    } else {
      //plan_rc = rfftw_create_plan(FFT_LENGTH, FFTW_REAL_TO_COMPLEX, FFTW_ESTIMATE);
      //plan_cr = rfftw_create_plan(FFT_LENGTH, FFTW_COMPLEX_TO_REAL, FFTW_ESTIMATE);
      //data=new REALTYPE[nsamples];for (int i=0;i<nsamples;i++) data[i]=0.0;

      //planfftw=fftwf_plan_r2r_1d(nsamples,data,data,FFTW_R2HC,FFTW_ESTIMATE);
      //planifftw=fftwf_plan_r2r_1d(nsamples,data,data,FFTW_HC2R,FFTW_ESTIMATE);

      //datar = new kiss_fft_scalar[nsamples+2];
      //for (int i=0;i<nsamples+2;i++) datar[i]=0.0;
      //datac=new kiss_fft_cpx[nsamples/2+2];
      //for (int i=0;i<nsamples/2+2;i++) datac[i].r=datac[i].i=0.0;
      //plankfft = kiss_fftr_alloc(nsamples,0,0,0);
      //plankifft = kiss_fftr_alloc(nsamples,1,0,0);
      plan_rc = kiss_fftr_alloc(FFT_LENGTH, 0, null, null);
      plan_cr = kiss_fftr_alloc(FFT_LENGTH, 1, null, null);
    }

    // create raised cosine window table
    foreach (immutable i; 0..FFT_LENGTH) {
      window[i] = -0.5f*cos(2.0f*PI*cast(double)i/cast(double)FFT_LENGTH)+0.5f;
      window[i] *= 2.0f;
    }

    // create db->coeffiecnt lookup table
    zalloc(db_table, 1000);
    foreach (immutable i; 0..1000) {
      float db = (cast(float)i/10)-70;
      db_table[i] = pow(10.0f, db/20.0f);
    }

    // create FFT bin -> band+delta tables
    int bin = 0;
    while (bin <= bandfrqs[0]/hz_per_bin) {
      bin_base[bin] = 0;
      bin_delta[bin++] = 0.0f;
    }
    for (int i = 1; i < BANDS-1 && bin < (FFT_LENGTH/2)-1 && bandfrqs[i+1] < s_rate/2; ++i) {
      float last_bin = bin;
      float next_bin = (bandfrqs[i+1])/hz_per_bin;
      while (bin <= next_bin) {
        bin_base[bin] = i;
        bin_delta[bin] = cast(float)(bin-last_bin)/cast(float)(next_bin-last_bin);
        ++bin;
      }
    }
    for (; bin < FFT_LENGTH/2; ++bin) {
      bin_base[bin] = BANDS-1;
      bin_delta[bin] = 0.0f;
    }
  }

  void activate () {
    fifo_pos = 0;
  }

  void cleanup () {
    xfree(in_fifo);
    xfree(out_fifo);
    xfree(out_accum);
    xfree(realx);
    xfree(comp);
    xfree(window);
    xfree(bin_base);
    xfree(bin_delta);
    xfree(db_table);
    version(FFTW3) {
    } else {
      kiss_fft_free(plan_rc);
      kiss_fft_free(plan_cr);
      plan_rc = null;
      plan_cr = null;
    }
  }

  // input: input (array of floats of length sample_count)
  // output: output (array of floats of length sample_count)
  void run (fftw_real[] output, const(fftw_real)[] input, uint stride=1, uint ofs=0) {
    if (output.length < input.length) assert(0, "wtf?!");
    if (stride == 0) assert(0, "wtf?!");
    if (ofs >= input.length || input.length < stride) return;

    float[BANDS+1] gains = void;
    gains[0..$-1] = bands[];
    gains[$-1] = 0.0f;

    float[FFT_LENGTH/2] coefs = void;

    enum step_size = FFT_LENGTH/OVER_SAMP;
    enum fft_latency = FFT_LENGTH-step_size;

    // convert gains from dB to co-efficents
    foreach (immutable i; 0..BANDS) {
      int gain_idx = cast(int)((gains[i]*10)+700);
      if (gain_idx < 0) gain_idx = 0; else if (gain_idx > 999) gain_idx = 999;
      gains[i] = db_table[gain_idx];
    }

    // calculate coefficients for each bin of FFT
    coefs[0] = 0.0f;
    for (int bin = 1; bin < FFT_LENGTH/2-1; ++bin) {
      coefs[bin] = ((1.0f-bin_delta[bin])*gains[bin_base[bin]])+(bin_delta[bin]*gains[bin_base[bin]+1]);
    }

    if (fifo_pos == 0) fifo_pos = fft_latency;

    foreach (immutable pos; 0..input.length/stride) {
      in_fifo[fifo_pos] = input.ptr[pos*stride+ofs];
      output.ptr[pos*stride+ofs] = out_fifo[fifo_pos-fft_latency];
      ++fifo_pos;

      // if the FIFO is full
      if (fifo_pos >= FFT_LENGTH) {
        fifo_pos = fft_latency;
        // window input FIFO
        foreach (immutable i; 0..FFT_LENGTH) realx[i] = in_fifo[i]*window[i];
        // run the real->complex transform
        version(FFTW3) {
          fftwf_execute(plan_rc);
          // multiply the bins magnitudes by the coeficients
          comp[0] *= coefs[0];
          foreach (immutable i; 1..FFT_LENGTH/2) {
            comp[i] *= coefs[i];
            comp[FFT_LENGTH-i] *= coefs[i];
          }
        } else {
          //rfftw_one(plan_rc, realx, comp);
          realx[FFT_LENGTH..FFT_LENGTH+16] = 0; // just in case
          comp[FFT_LENGTH-16..FFT_LENGTH+16] = 0; // just in case
          kiss_fftr(plan_rc, realx, cast(kiss_fft_cpx*)comp);
          // multiply the bins magnitudes by the coeficients
          comp[0*2+0] *= coefs[0];
          foreach (immutable i; 1..FFT_LENGTH/2) {
            comp[i*2+0] *= coefs[i];
            comp[i*2+1] *= coefs[i];
          }
        }
        //rfft(FFT_LENGTH, 1, realx);

        // run the complex->real transform
        version(FFTW3) {
          fftwf_execute(plan_cr);
        } else {
          //rfftw_one(plan_cr, comp, realx);
          kiss_fftri(plan_cr, cast(const(kiss_fft_cpx)*)comp, realx);
        }
        // window into the output accumulator
        foreach (immutable i; 0..FFT_LENGTH) out_accum[i] += 0.9186162f*window[i]*realx[i]/(FFT_LENGTH*OVER_SAMP);
        foreach (immutable i; 0..step_size) out_fifo[i] = out_accum[i];
        // shift output accumulator
        {
          import core.stdc.string : memmove;
          memmove(out_accum, out_accum+step_size, FFT_LENGTH*float.sizeof);
        }
        // shift input fifo
        foreach (immutable i; 0..fft_latency) in_fifo[i] = in_fifo[i+step_size];
      }
    }
    // store the fifo_position
    //plugin_data.fifo_pos = fifo_pos;
    //*(plugin_data.latency) = fft_latency;
    latency = fft_latency;
  }

private static immutable float[BANDS] bandfrqs = [
   50.00f,  100.00f,  155.56f,  220.00f,  311.13f, 440.00f, 622.25f,
  880.00f, 1244.51f, 1760.00f, 2489.02f, 3519.95, 4978.04f, 9956.08f,
  19912.16f
];

private:
static:
  T* xalloc(T) (uint count=1) nothrow @trusted @nogc {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memcpy, memset;
    if (count == 0 || count > 1024*1024*8) assert(0, "wtf?!");
    auto res = cast(T*)malloc(T.sizeof*count);
    if (res is null) assert(0, "out of memory");
    auto iv = typeid(T).initializer;
    if (iv.ptr is null) {
      memset(res, 0, T.sizeof*count);
    } else if (iv.length == T.sizeof) {
      foreach (immutable idx; 0..count) memcpy(res+idx, iv.ptr, T.sizeof);
    } else if (iv.length == 0) {
      memset(res, 0, T.sizeof*count);
    } else if (iv.length%T.sizeof == 0) {
      foreach (immutable idx; 0..count) {
        auto dp = cast(ubyte*)(res+idx);
        foreach (immutable c; 0..iv.length/T.sizeof) { memcpy(dp, iv.ptr, iv.length); dp += iv.length; }
      }
    } else {
      assert(0, "!!!");
    }
    return res;
  }

  T* zalloc(T) (uint count=1) nothrow @trusted @nogc {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memcpy, memset;
    if (count == 0 || count > 1024*1024*8) assert(0, "wtf?!");
    auto res = cast(T*)malloc(T.sizeof*count);
    if (res is null) assert(0, "out of memory");
    memset(res, 0, T.sizeof*count);
    return res;
  }

  void zalloc(T) (ref T* res, uint count=1) nothrow @trusted @nogc {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memcpy, memset;
    if (count == 0 || count > 1024*1024*8) assert(0, "wtf?!");
    res = cast(T*)malloc(T.sizeof*count);
    if (res is null) assert(0, "out of memory");
    memset(res, 0, T.sizeof*count);
  }

  void xfree(T) (ref T* ptr) nothrow @trusted @nogc {
    import core.stdc.stdlib : free;
    if (ptr !is null) { free(ptr); ptr = null; }
  }
}
