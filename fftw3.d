/*
 * Copyright (c) 2003, 2007-14 Matteo Frigo
 * Copyright (c) 2003, 2007-14 Massachusetts Institute of Technology
 *
 * The following statement of license applies *only* to this header file,
 * and *not* to the other files distributed with FFTW or derived therefrom:
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module iv.fftw3;
pragma(lib, "fftw3");
extern(C) nothrow @trusted @nogc:

/***************************** NOTE TO USERS *********************************
 *
 *                 THIS IS A HEADER FILE, NOT A MANUAL
 *
 *    If you want to know how to use FFTW, please read the manual,
 *    online at http://www.fftw.org/doc/ and also included with FFTW.
 *    For a quick start, see the manual's tutorial section.
 *
 *   (Reading header files to learn how to use a library is a habit
 *    stemming from code lacking a proper manual.  Arguably, it's a
 *    *bad* habit in most cases, because header files can contain
 *    interfaces that are not part of the public, stable API.)
 *
 ****************************************************************************/

/* If <complex.h> is included, use the C99 complex type.  Otherwise
   define a type bit-compatible with C99 complex */
/*
#if !defined(FFTW_NO_Complex) && defined(_Complex_I) && defined(complex) && defined(I)
#  define FFTW_DEFINE_COMPLEX(R, C) typedef R _Complex C
#else
#  define FFTW_DEFINE_COMPLEX(R, C) typedef R C[2]
#endif

#define FFTW_CONCAT(prefix, name) prefix ## name
#define FFTW_MANGLE_DOUBLE(name) FFTW_CONCAT(fftw_, name)
#define FFTW_MANGLE_FLOAT(name) FFTW_CONCAT(fftwf_, name)
#define FFTW_MANGLE_LONG_DOUBLE(name) FFTW_CONCAT(fftwl_, name)
#define FFTW_MANGLE_QUAD(name) FFTW_CONCAT(fftwq_, name)
*/


alias fftw_r2r_kind_do_not_use_me = int;
enum : int {
  FFTW_R2HC=0, FFTW_HC2R=1, FFTW_DHT=2,
  FFTW_REDFT00=3, FFTW_REDFT01=4, FFTW_REDFT10=5, FFTW_REDFT11=6,
  FFTW_RODFT00=7, FFTW_RODFT01=8, FFTW_RODFT10=9, FFTW_RODFT11=10,
}

struct fftw_iodim_do_not_use_me {
  int n; /* dimension size */
  int is_; /* input stride */
  int os; /* output stride */
}

struct fftw_iodim64_do_not_use_me {
  ptrdiff_t n; /* dimension size */
  ptrdiff_t is_; /* input stride */
  ptrdiff_t os; /* output stride */
}

//typedef void (FFTW_CDECL *fftw_write_char_func_do_not_use_me)(char c, void *);
//typedef int (FFTW_CDECL *fftw_read_char_func_do_not_use_me)(void *);

/*
  huge second-order macro that defines prototypes for all API
  functions.  We expand this macro for each supported precision

  X: name-mangling macro
  R: real data type
  C: complex data type
*/
enum FFTW_DEFINE_API(string X, string R, string C) = "
/*FFTW_DEFINE_COMPLEX("~R~", "~C~");*/
alias "~C~" = "~R~"[2];


/*struct "~X~"plan_s *"~X~"plan;*/
alias "~X~"plan = void*;

/*
typedef struct fftw_iodim_do_not_use_me "~X~"iodim;
typedef struct fftw_iodim64_do_not_use_me "~X~"iodim64;

typedef enum fftw_r2r_kind_do_not_use_me "~X~"r2r_kind;

typedef fftw_write_char_func_do_not_use_me "~X~"write_char_func;
typedef fftw_read_char_func_do_not_use_me "~X~"read_char_func;
*/

alias "~X~"iodim = fftw_iodim_do_not_use_me;
alias "~X~"iodim64 = fftw_iodim64_do_not_use_me;
alias "~X~"r2r_kind = int;

void "~X~"execute(const "~X~"plan p);

"~X~"plan "~X~"plan_dft(int rank, const int *n,
                       "~C~" *in_, "~C~" *out_, int sign, uint flags);

"~X~"plan "~X~"plan_dft_1d(int n, "~C~" *in_, "~C~" *out_, int sign,
                          uint flags);
"~X~"plan "~X~"plan_dft_2d(int n0, int n1,
                          "~C~" *in_, "~C~" *out_, int sign, uint flags);
"~X~"plan "~X~"plan_dft_3d(int n0, int n1, int n2,
                          "~C~" *in_, "~C~" *out_, int sign, uint flags);

"~X~"plan "~X~"plan_many_dft(int rank, const int *n,
                            int howmany,
                            "~C~" *in_, const int *inembed,
                            int istride, int idist,
                            "~C~" *out_, const int *onembed,
                            int ostride, int odist,
                            int sign, uint flags);

"~X~"plan "~X~"plan_guru_dft(int rank, const "~X~"iodim *dims,
                            int howmany_rank,
                            const "~X~"iodim *howmany_dims,
                            "~C~" *in_, "~C~" *out_,
                            int sign, uint flags);
"~X~"plan "~X~"plan_guru_split_dft(int rank, const "~X~"iodim *dims,
                                  int howmany_rank,
                                  const "~X~"iodim *howmany_dims,
                                  "~R~" *ri, "~R~" *ii, "~R~" *ro, "~R~" *io,
                                  uint flags);

"~X~"plan "~X~"plan_guru64_dft(int rank,
                              const "~X~"iodim64 *dims,
                              int howmany_rank,
                              const "~X~"iodim64 *howmany_dims,
                              "~C~" *in_, "~C~" *out_,
                              int sign, uint flags);
"~X~"plan "~X~"plan_guru64_split_dft(int rank,
                                    const "~X~"iodim64 *dims,
                                    int howmany_rank,
                                    const "~X~"iodim64 *howmany_dims,
                                    "~R~" *ri, "~R~" *ii, "~R~" *ro, "~R~" *io,
                                    uint flags);

void "~X~"execute_dft(const "~X~"plan p, "~C~" *in_, "~C~" *out_);

void "~X~"execute_split_dft(const "~X~"plan p, "~R~" *ri, "~R~" *ii,
                                      "~R~" *ro, "~R~" *io);

"~X~"plan "~X~"plan_many_dft_r2c(int rank, const int *n,
                                int howmany,
                                "~R~" *in_, const int *inembed,
                                int istride, int idist,
                                "~C~" *out_, const int *onembed,
                                int ostride, int odist,
                                uint flags);

"~X~"plan "~X~"plan_dft_r2c(int rank, const int *n,
                           "~R~" *in_, "~C~" *out_, uint flags);

"~X~"plan "~X~"plan_dft_r2c_1d(int n,"~R~" *in_,"~C~" *out_,uint flags);

"~X~"plan "~X~"plan_dft_r2c_2d(int n0, int n1,
                              "~R~" *in_, "~C~" *out_, uint flags);

"~X~"plan "~X~"plan_dft_r2c_3d(int n0, int n1,
                              int n2,
                              "~R~" *in_, "~C~" *out_, uint flags);

"~X~"plan "~X~"plan_many_dft_c2r(int rank, const int *n,
                                int howmany,
                                "~C~" *in_, const int *inembed,
                                int istride, int idist,
                                "~R~" *out_, const int *onembed,
                                int ostride, int odist,
                                uint flags);

"~X~"plan "~X~"plan_dft_c2r(int rank, const int *n,
                           "~C~" *in_, "~R~" *out_, uint flags);

"~X~"plan "~X~"plan_dft_c2r_1d(int n,"~C~" *in_,"~R~" *out_,uint flags);

"~X~"plan "~X~"plan_dft_c2r_2d(int n0, int n1,
                              "~C~" *in_, "~R~" *out_, uint flags);

"~X~"plan "~X~"plan_dft_c2r_3d(int n0, int n1,
                              int n2,
                              "~C~" *in_, "~R~" *out_, uint flags);

"~X~"plan "~X~"plan_guru_dft_r2c(int rank, const "~X~"iodim *dims,
                                int howmany_rank,
                                const "~X~"iodim *howmany_dims,
                                "~R~" *in_, "~C~" *out_,
                                uint flags);

"~X~"plan "~X~"plan_guru_dft_c2r(int rank, const "~X~"iodim *dims,
                                int howmany_rank,
                                const "~X~"iodim *howmany_dims,
                                "~C~" *in_, "~R~" *out_,
                                uint flags);

"~X~"plan "~X~"plan_guru_split_dft_r2c(int rank, const "~X~"iodim *dims,
                                      int howmany_rank,
                                      const "~X~"iodim *howmany_dims,
                                      "~R~" *in_, "~R~" *ro, "~R~" *io,
                                      uint flags);

"~X~"plan "~X~"plan_guru_split_dft_c2r(int rank, const "~X~"iodim *dims,
                                      int howmany_rank,
                                      const "~X~"iodim *howmany_dims,
                                      "~R~" *ri, "~R~" *ii, "~R~" *out_,
                                      uint flags);

"~X~"plan "~X~"plan_guru64_dft_r2c(int rank,
                                  const "~X~"iodim64 *dims,
                                  int howmany_rank,
                                  const "~X~"iodim64 *howmany_dims,
                                  "~R~" *in_, "~C~" *out_,
                                  uint flags);

"~X~"plan "~X~"plan_guru64_dft_c2r(int rank,
                                  const "~X~"iodim64 *dims,
                                  int howmany_rank,
                                  const "~X~"iodim64 *howmany_dims,
                                  "~C~" *in_, "~R~" *out_,
                                  uint flags);

"~X~"plan "~X~"plan_guru64_split_dft_r2c(int rank, const "~X~"iodim64 *dims,
                                        int howmany_rank,
                                        const "~X~"iodim64 *howmany_dims,
                                        "~R~" *in_, "~R~" *ro, "~R~" *io,
                                        uint flags);
"~X~"plan "~X~"plan_guru64_split_dft_c2r(int rank, const "~X~"iodim64 *dims,
                                        int howmany_rank,
                                        const "~X~"iodim64 *howmany_dims,
                                        "~R~" *ri, "~R~" *ii, "~R~" *out_,
                                        uint flags);

void "~X~"execute_dft_r2c(const "~X~"plan p, "~R~" *in_, "~C~" *out_);

void "~X~"execute_dft_c2r(const "~X~"plan p, "~C~" *in_, "~R~" *out_);

void "~X~"execute_split_dft_r2c(const "~X~"plan p,
                                    "~R~" *in_, "~R~" *ro, "~R~" *io);

void "~X~"execute_split_dft_c2r(const "~X~"plan p,
                                    "~R~" *ri, "~R~" *ii, "~R~" *out_);

"~X~"plan "~X~"plan_many_r2r(int rank, const int *n,
                            int howmany,
                            "~R~" *in_, const int *inembed,
                            int istride, int idist,
                            "~R~" *out_, const int *onembed,
                            int ostride, int odist,
                            const "~X~"r2r_kind *kind, uint flags);

"~X~"plan "~X~"plan_r2r(int rank, const int *n, "~R~" *in_, "~R~" *out_,
                       const "~X~"r2r_kind *kind, uint flags);

"~X~"plan "~X~"plan_r2r_1d(int n, "~R~" *in_, "~R~" *out_,
                          "~X~"r2r_kind kind, uint flags);

"~X~"plan "~X~"plan_r2r_2d(int n0, int n1, "~R~" *in_, "~R~" *out_,
                          "~X~"r2r_kind kind0, "~X~"r2r_kind kind1,
                          uint flags);

"~X~"plan "~X~"plan_r2r_3d(int n0, int n1, int n2,
                          "~R~" *in_, "~R~" *out_, "~X~"r2r_kind kind0,
                          "~X~"r2r_kind kind1, "~X~"r2r_kind kind2,
                          uint flags);

"~X~"plan "~X~"plan_guru_r2r(int rank, const "~X~"iodim *dims,
                            int howmany_rank,
                            const "~X~"iodim *howmany_dims,
                            "~R~" *in_, "~R~" *out_,
                            const "~X~"r2r_kind *kind, uint flags);

"~X~"plan "~X~"plan_guru64_r2r(int rank, const "~X~"iodim64 *dims,
                              int howmany_rank,
                              const "~X~"iodim64 *howmany_dims,
                              "~R~" *in_, "~R~" *out_,
                              const "~X~"r2r_kind *kind, uint flags);

void "~X~"execute_r2r(const "~X~"plan p, "~R~" *in_, "~R~" *out_);

void "~X~"destroy_plan("~X~"plan p);

void "~X~"forget_wisdom();
void "~X~"cleanup();

void "~X~"set_timelimit(double t);

void "~X~"plan_with_nthreads(int nthreads);

int "~X~"init_threads();

void "~X~"cleanup_threads();

void "~X~"make_planner_thread_safe();

int "~X~"export_wisdom_to_filename(const char *filename);

/*void "~X~"export_wisdom_to_file(FILE *output_file);*/

char * "~X~"export_wisdom_to_string();

/*void "~X~"export_wisdom("~X~"write_char_func write_char, void *data);*/
int "~X~"import_system_wisdom();

int "~X~"import_wisdom_from_filename(const char *filename);

/*int "~X~"import_wisdom_from_file(FILE *input_file);*/

int "~X~"import_wisdom_from_string(const char *input_string);

/*int "~X~"import_wisdom("~X~"read_char_func read_char, void *data);*/

/*void "~X~"fprint_plan(const "~X~"plan p, FILE *output_file);*/

void "~X~"print_plan(const "~X~"plan p);

char * "~X~"sprint_plan(const "~X~"plan p);

void * "~X~"malloc(size_t n);

"~R~" * "~X~"alloc_real(size_t n);
"~C~" * "~X~"alloc_complex(size_t n);

void "~X~"free(void *p);

void "~X~"flops(const "~X~"plan p,
                    double *add, double *mul, double *fmas);
double "~X~"estimate_cost(const "~X~"plan p);

double "~X~"cost(const "~X~"plan p);

int "~X~"alignment_of("~R~" *p);

/*
const char "~X~"version[];
const char "~X~"cc[];
const char "~X~"codelet_optim[];
*/
";

/* end of FFTW_DEFINE_API macro */

mixin(FFTW_DEFINE_API!("fftw_", "double", "fftw_complex"));
mixin(FFTW_DEFINE_API!("fftwf_", "float", "fftwf_complex"));

/*
FFTW_DEFINE_API(FFTW_MANGLE_DOUBLE, double, fftw_complex)
FFTW_DEFINE_API(FFTW_MANGLE_FLOAT, float, fftwf_complex)
FFTW_DEFINE_API(FFTW_MANGLE_LONG_DOUBLE, long double, fftwl_complex)
*/

/+
/* __float128 (quad precision) is a gcc extension on i386, x86_64, and ia64
   for gcc >= 4.6 (compiled in FFTW with --enable-quad-precision) */
#if (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 6))
 && !(defined(__ICC) || defined(__INTEL_COMPILER) || defined(__CUDACC__) || defined(__PGI))
 && (defined(__i386__) || defined(__x86_64__) || defined(__ia64__))
#  if !defined(FFTW_NO_Complex) && defined(_Complex_I) && defined(complex) && defined(I)
/* note: __float128 is a typedef, which is not supported with the _Complex
         keyword in gcc, so instead we use this ugly __attribute__ version.
         However, we can't simply pass the __attribute__ version to
         FFTW_DEFINE_API because the __attribute__ confuses gcc in pointer
         types.  Hence redefining FFTW_DEFINE_COMPLEX.  Ugh. */
#    undef FFTW_DEFINE_COMPLEX
#    define FFTW_DEFINE_COMPLEX(R, C) typedef _Complex float __attribute__((mode(TC))) C
#  endif
FFTW_DEFINE_API(FFTW_MANGLE_QUAD, __float128, fftwq_complex)
#endif
+/

enum FFTW_FORWARD = -1;
enum FFTW_BACKWARD = 1;

enum FFTW_NO_TIMELIMIT = -1.0;

/* documented flags */
enum FFTW_MEASURE = 0U;
enum FFTW_DESTROY_INPUT = 1U << 0;
enum FFTW_UNALIGNED = 1U << 1;
enum FFTW_CONSERVE_MEMORY = 1U << 2;
enum FFTW_EXHAUSTIVE = 1U << 3; /* NO_EXHAUSTIVE is default */
enum FFTW_PRESERVE_INPUT = 1U << 4; /* cancels FFTW_DESTROY_INPUT */
enum FFTW_PATIENT = 1U << 5; /* IMPATIENT is default */
enum FFTW_ESTIMATE = 1U << 6;
enum FFTW_WISDOM_ONLY = 1U << 21;

/* undocumented beyond-guru flags */
enum FFTW_ESTIMATE_PATIENT = 1U << 7;
enum FFTW_BELIEVE_PCOST = 1U << 8;
enum FFTW_NO_DFT_R2HC = 1U << 9;
enum FFTW_NO_NONTHREADED = 1U << 10;
enum FFTW_NO_BUFFERING = 1U << 11;
enum FFTW_NO_INDIRECT_OP = 1U << 12;
enum FFTW_ALLOW_LARGE_GENERIC = 1U << 13; /* NO_LARGE_GENERIC is default */
enum FFTW_NO_RANK_SPLITS = 1U << 14;
enum FFTW_NO_VRANK_SPLITS = 1U << 15;
enum FFTW_NO_VRECURSE = 1U << 16;
enum FFTW_NO_SIMD = 1U << 17;
enum FFTW_NO_SLOW = 1U << 18;
enum FFTW_NO_FIXED_RADIX_LARGE_N = 1U << 19;
enum FFTW_ALLOW_PRUNING = 1U << 20;
