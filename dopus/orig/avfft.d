module avfft /*is aliced*/;
import iv.alice;

alias FFTSample = float;

struct FFTComplex {
  FFTSample re, im;
}

alias int8_t = byte;
alias uint8_t = ubyte;
alias int16_t = short;
alias uint16_t = ushort;
alias int32_t = int;
alias uint32_t = uint;
alias int64_t = long;
alias uint64_t = ulong;

enum AV_NOPTS_VALUE = cast(int64_t)0x8000000000000000UL;


T FFABS(T) (in T a) { pragma(inline, true); return (a < 0 ? -a : a); }

T FFMAX(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }
T FFMIN(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }

T FFMIN3(T) (in T a, in T b, in T c) { pragma(inline, true); return (a < b ? (a < c ? a : c) : (b < c ? b : c)); }

//T FFALIGN(T) (T x, T a) { pragma(inline, true); return (((x)+(a)-1)&~((a)-1)); }
//T FFALIGN(T) (T x, T a) { pragma(inline, true); return x; }


double ff_exp10 (double x) {
  import std.math : exp2;
  enum M_LOG2_10 = 3.32192809488736234787; /* log_2 10 */
  return exp2(M_LOG2_10 * x);
}


static immutable ubyte[256] ff_log2_tab = [
  0,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
];

alias av_log2 = ff_log2;
alias ff_log2 = ff_log2_c;

int ff_log2_c (uint v) nothrow @trusted @nogc {
  int n = 0;
  if (v & 0xffff0000) {
    v >>= 16;
    n += 16;
  }
  if (v & 0xff00) {
    v >>= 8;
    n += 8;
  }
  n += ff_log2_tab[v];
  return n;
}


/**
 * Clear high bits from an unsigned integer starting with specific bit position
 * @param  a value to clip
 * @param  p bit position to clip at
 * @return clipped value
 */
uint av_mod_uintp2 (uint a, uint p) pure nothrow @safe @nogc { pragma(inline, true); return a & ((1 << p) - 1); }

/* a*inverse[b]>>32 == a/b for all 0<=a<=16909558 && 2<=b<=256
 * for a>16909558, is an overestimate by less than 1 part in 1<<24 */
static immutable uint[257] ff_inverse = [
         0, 4294967295U,2147483648U,1431655766, 1073741824,  858993460,  715827883,  613566757,
 536870912,  477218589,  429496730,  390451573,  357913942,  330382100,  306783379,  286331154,
 268435456,  252645136,  238609295,  226050911,  214748365,  204522253,  195225787,  186737709,
 178956971,  171798692,  165191050,  159072863,  153391690,  148102321,  143165577,  138547333,
 134217728,  130150525,  126322568,  122713352,  119304648,  116080198,  113025456,  110127367,
 107374183,  104755300,  102261127,   99882961,   97612894,   95443718,   93368855,   91382283,
  89478486,   87652394,   85899346,   84215046,   82595525,   81037119,   79536432,   78090315,
  76695845,   75350304,   74051161,   72796056,   71582789,   70409300,   69273667,   68174085,
  67108864,   66076420,   65075263,   64103990,   63161284,   62245903,   61356676,   60492498,
  59652324,   58835169,   58040099,   57266231,   56512728,   55778797,   55063684,   54366675,
  53687092,   53024288,   52377650,   51746594,   51130564,   50529028,   49941481,   49367441,
  48806447,   48258060,   47721859,   47197443,   46684428,   46182445,   45691142,   45210183,
  44739243,   44278014,   43826197,   43383509,   42949673,   42524429,   42107523,   41698712,
  41297763,   40904451,   40518560,   40139882,   39768216,   39403370,   39045158,   38693400,
  38347923,   38008561,   37675152,   37347542,   37025581,   36709123,   36398028,   36092163,
  35791395,   35495598,   35204650,   34918434,   34636834,   34359739,   34087043,   33818641,
  33554432,   33294321,   33038210,   32786010,   32537632,   32292988,   32051995,   31814573,
  31580642,   31350127,   31122952,   30899046,   30678338,   30460761,   30246249,   30034737,
  29826162,   29620465,   29417585,   29217465,   29020050,   28825284,   28633116,   28443493,
  28256364,   28071682,   27889399,   27709467,   27531842,   27356480,   27183338,   27012373,
  26843546,   26676816,   26512144,   26349493,   26188825,   26030105,   25873297,   25718368,
  25565282,   25414008,   25264514,   25116768,   24970741,   24826401,   24683721,   24542671,
  24403224,   24265352,   24129030,   23994231,   23860930,   23729102,   23598722,   23469767,
  23342214,   23216040,   23091223,   22967740,   22845571,   22724695,   22605092,   22486740,
  22369622,   22253717,   22139007,   22025474,   21913099,   21801865,   21691755,   21582751,
  21474837,   21367997,   21262215,   21157475,   21053762,   20951060,   20849356,   20748635,
  20648882,   20550083,   20452226,   20355296,   20259280,   20164166,   20069941,   19976593,
  19884108,   19792477,   19701685,   19611723,   19522579,   19434242,   19346700,   19259944,
  19173962,   19088744,   19004281,   18920561,   18837576,   18755316,   18673771,   18592933,
  18512791,   18433337,   18354562,   18276457,   18199014,   18122225,   18046082,   17970575,
  17895698,   17821442,   17747799,   17674763,   17602325,   17530479,   17459217,   17388532,
  17318417,   17248865,   17179870,   17111424,   17043522,   16976156,   16909321,   16843010,
  16777216
];


static immutable ubyte[256] ff_sqrt_tab = [
  0, 16, 23, 28, 32, 36, 40, 43, 46, 48, 51, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72, 74, 76, 77, 79, 80, 82, 84, 85, 87, 88, 90,
 91, 92, 94, 95, 96, 98, 99,100,102,103,104,105,107,108,109,110,111,112,114,115,116,117,118,119,120,121,122,123,124,125,126,127,
128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,144,145,146,147,148,149,150,151,151,152,153,154,155,156,156,
157,158,159,160,160,161,162,163,164,164,165,166,167,168,168,169,170,171,171,172,173,174,174,175,176,176,177,178,179,179,180,181,
182,182,183,184,184,185,186,186,187,188,188,189,190,190,191,192,192,193,194,194,195,196,196,197,198,198,199,200,200,201,202,202,
203,204,204,205,205,206,207,207,208,208,209,210,210,211,212,212,213,213,214,215,215,216,216,217,218,218,219,219,220,220,221,222,
222,223,223,224,224,225,226,226,227,227,228,228,229,230,230,231,231,232,232,233,233,234,235,235,236,236,237,237,238,238,239,239,
240,240,241,242,242,243,243,244,244,245,245,246,246,247,247,248,248,249,249,250,250,251,251,252,252,253,253,254,254,255,255,255
];

uint FASTDIV() (uint a, uint b) { pragma(inline, true); return (cast(uint)(((cast(ulong)a) * ff_inverse[b]) >> 32)); }

uint ff_sqrt (uint a) nothrow @safe @nogc {
  uint b;
  alias av_log2_16bit = av_log2;

  if (a < 255) return (ff_sqrt_tab[a + 1] - 1) >> 4;
  else if (a < (1 << 12)) b = ff_sqrt_tab[a >> 4] >> 2;
//#if !CONFIG_SMALL
  else if (a < (1 << 14)) b = ff_sqrt_tab[a >> 6] >> 1;
  else if (a < (1 << 16)) b = ff_sqrt_tab[a >> 8];
//#endif
  else {
      int s = av_log2_16bit(a >> 16) >> 1;
      uint c = a >> (s + 2);
      b = ff_sqrt_tab[c >> (s + 8)];
      b = FASTDIV(c,b) + (b << s);
  }
  return b - (a < b * b);
}

/**
 * Clip a signed integer value into the amin-amax range.
 * @param a value to clip
 * @param amin minimum value of the clip range
 * @param amax maximum value of the clip range
 * @return clipped value
 */
int av_clip (int a, int amin, int amax) pure nothrow @safe @nogc {
  pragma(inline, true);
  //if (a < amin) return amin; else if (a > amax) return amax; else return a;
  return (a < amin ? amin : a > amax ? amax : a);
}

/**
 * Clip a signed integer to an unsigned power of two range.
 * @param  a value to clip
 * @param  p bit position to clip at
 * @return clipped value
 */
uint av_clip_uintp2 (int a, int p) pure nothrow @safe @nogc {
  pragma(inline, true);
  //if (a & ~((1<<p) - 1)) return -a >> 31 & ((1<<p) - 1); else return  a;
  return (a & ~((1<<p) - 1) ? -a >> 31 & ((1<<p) - 1) : a);
}

/**
 * Clip a signed integer value into the -32768,32767 range.
 * @param a value to clip
 * @return clipped value
 */
short av_clip_int16 (int a) pure nothrow @safe @nogc {
  pragma(inline, true);
  return cast(short)((a+0x8000U) & ~0xFFFF ? (a>>31) ^ 0x7FFF : a);
}

/**
 * Clip a float value into the amin-amax range.
 * @param a value to clip
 * @param amin minimum value of the clip range
 * @param amax maximum value of the clip range
 * @return clipped value
 */
float av_clipf (float a, float amin, float amax) pure nothrow @safe @nogc {
  pragma(inline, true);
  return (a < amin ? amin : a > amax ? amax : a);
}


// ////////////////////////////////////////////////////////////////////////// //
// dsp part
void vector_fmul_window (float* dst, const(float)* src0, const(float)* src1, const(float)* win, int len) {
  int i, j;
  dst  += len;
  win  += len;
  src0 += len;
  for (i = -len, j = len-1; i < 0; ++i, --j) {
    float s0 = src0[i];
    float s1 = src1[j];
    float wi = win[i];
    float wj = win[j];
    dst[i] = s0*wj-s1*wi;
    dst[j] = s0*wi+s1*wj;
  }
}

static void vector_fmac_scalar (float* dst, const(float)* src, float mul, int len) {
  for (int i = 0; i < len; i++) dst[i] += src[i]*mul;
}

static void vector_fmul_scalar (float* dst, const(float)* src, float mul, int len) {
  for (int i = 0; i < len; ++i) dst[i] = src[i]*mul;
}
