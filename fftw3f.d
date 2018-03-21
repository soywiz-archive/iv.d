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
module iv.fftw3f;
pragma(lib, "fftw3f");
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


/*FFTW_DEFINE_COMPLEX(float, fftwf_complex);*/
alias fftwf_complex = float[2];


/*struct fftwf_plan_s *fftwf_plan;*/
alias fftwf_plan = void*;

/*
typedef struct fftw_iodim_do_not_use_me fftwf_iodim;
typedef struct fftw_iodim64_do_not_use_me fftwf_iodim64;

typedef enum fftw_r2r_kind_do_not_use_me fftwf_r2r_kind;

typedef fftw_write_char_func_do_not_use_me fftwf_write_char_func;
typedef fftw_read_char_func_do_not_use_me fftwf_read_char_func;
*/

alias fftwf_iodim = fftw_iodim_do_not_use_me;
alias fftwf_iodim64 = fftw_iodim64_do_not_use_me;
alias fftwf_r2r_kind = int;

void fftwf_execute(const fftwf_plan p);

fftwf_plan fftwf_plan_dft(int rank, const int *n,
                       fftwf_complex *in_, fftwf_complex *out_, int sign, uint flags);

fftwf_plan fftwf_plan_dft_1d(int n, fftwf_complex *in_, fftwf_complex *out_, int sign,
                          uint flags);
fftwf_plan fftwf_plan_dft_2d(int n0, int n1,
                          fftwf_complex *in_, fftwf_complex *out_, int sign, uint flags);
fftwf_plan fftwf_plan_dft_3d(int n0, int n1, int n2,
                          fftwf_complex *in_, fftwf_complex *out_, int sign, uint flags);

fftwf_plan fftwf_plan_many_dft(int rank, const int *n,
                            int howmany,
                            fftwf_complex *in_, const int *inembed,
                            int istride, int idist,
                            fftwf_complex *out_, const int *onembed,
                            int ostride, int odist,
                            int sign, uint flags);

fftwf_plan fftwf_plan_guru_dft(int rank, const fftwf_iodim *dims,
                            int howmany_rank,
                            const fftwf_iodim *howmany_dims,
                            fftwf_complex *in_, fftwf_complex *out_,
                            int sign, uint flags);
fftwf_plan fftwf_plan_guru_split_dft(int rank, const fftwf_iodim *dims,
                                  int howmany_rank,
                                  const fftwf_iodim *howmany_dims,
                                  float *ri, float *ii, float *ro, float *io,
                                  uint flags);

fftwf_plan fftwf_plan_guru64_dft(int rank,
                              const fftwf_iodim64 *dims,
                              int howmany_rank,
                              const fftwf_iodim64 *howmany_dims,
                              fftwf_complex *in_, fftwf_complex *out_,
                              int sign, uint flags);
fftwf_plan fftwf_plan_guru64_split_dft(int rank,
                                    const fftwf_iodim64 *dims,
                                    int howmany_rank,
                                    const fftwf_iodim64 *howmany_dims,
                                    float *ri, float *ii, float *ro, float *io,
                                    uint flags);

void fftwf_execute_dft(const fftwf_plan p, fftwf_complex *in_, fftwf_complex *out_);

void fftwf_execute_split_dft(const fftwf_plan p, float *ri, float *ii,
                                      float *ro, float *io);

fftwf_plan fftwf_plan_many_dft_r2c(int rank, const int *n,
                                int howmany,
                                float *in_, const int *inembed,
                                int istride, int idist,
                                fftwf_complex *out_, const int *onembed,
                                int ostride, int odist,
                                uint flags);

fftwf_plan fftwf_plan_dft_r2c(int rank, const int *n,
                           float *in_, fftwf_complex *out_, uint flags);

fftwf_plan fftwf_plan_dft_r2c_1d(int n,float *in_,fftwf_complex *out_,uint flags);

fftwf_plan fftwf_plan_dft_r2c_2d(int n0, int n1,
                              float *in_, fftwf_complex *out_, uint flags);

fftwf_plan fftwf_plan_dft_r2c_3d(int n0, int n1,
                              int n2,
                              float *in_, fftwf_complex *out_, uint flags);

fftwf_plan fftwf_plan_many_dft_c2r(int rank, const int *n,
                                int howmany,
                                fftwf_complex *in_, const int *inembed,
                                int istride, int idist,
                                float *out_, const int *onembed,
                                int ostride, int odist,
                                uint flags);

fftwf_plan fftwf_plan_dft_c2r(int rank, const int *n,
                           fftwf_complex *in_, float *out_, uint flags);

fftwf_plan fftwf_plan_dft_c2r_1d(int n,fftwf_complex *in_,float *out_,uint flags);

fftwf_plan fftwf_plan_dft_c2r_2d(int n0, int n1,
                              fftwf_complex *in_, float *out_, uint flags);

fftwf_plan fftwf_plan_dft_c2r_3d(int n0, int n1,
                              int n2,
                              fftwf_complex *in_, float *out_, uint flags);

fftwf_plan fftwf_plan_guru_dft_r2c(int rank, const fftwf_iodim *dims,
                                int howmany_rank,
                                const fftwf_iodim *howmany_dims,
                                float *in_, fftwf_complex *out_,
                                uint flags);

fftwf_plan fftwf_plan_guru_dft_c2r(int rank, const fftwf_iodim *dims,
                                int howmany_rank,
                                const fftwf_iodim *howmany_dims,
                                fftwf_complex *in_, float *out_,
                                uint flags);

fftwf_plan fftwf_plan_guru_split_dft_r2c(int rank, const fftwf_iodim *dims,
                                      int howmany_rank,
                                      const fftwf_iodim *howmany_dims,
                                      float *in_, float *ro, float *io,
                                      uint flags);

fftwf_plan fftwf_plan_guru_split_dft_c2r(int rank, const fftwf_iodim *dims,
                                      int howmany_rank,
                                      const fftwf_iodim *howmany_dims,
                                      float *ri, float *ii, float *out_,
                                      uint flags);

fftwf_plan fftwf_plan_guru64_dft_r2c(int rank,
                                  const fftwf_iodim64 *dims,
                                  int howmany_rank,
                                  const fftwf_iodim64 *howmany_dims,
                                  float *in_, fftwf_complex *out_,
                                  uint flags);

fftwf_plan fftwf_plan_guru64_dft_c2r(int rank,
                                  const fftwf_iodim64 *dims,
                                  int howmany_rank,
                                  const fftwf_iodim64 *howmany_dims,
                                  fftwf_complex *in_, float *out_,
                                  uint flags);

fftwf_plan fftwf_plan_guru64_split_dft_r2c(int rank, const fftwf_iodim64 *dims,
                                        int howmany_rank,
                                        const fftwf_iodim64 *howmany_dims,
                                        float *in_, float *ro, float *io,
                                        uint flags);
fftwf_plan fftwf_plan_guru64_split_dft_c2r(int rank, const fftwf_iodim64 *dims,
                                        int howmany_rank,
                                        const fftwf_iodim64 *howmany_dims,
                                        float *ri, float *ii, float *out_,
                                        uint flags);

void fftwf_execute_dft_r2c(const fftwf_plan p, float *in_, fftwf_complex *out_);

void fftwf_execute_dft_c2r(const fftwf_plan p, fftwf_complex *in_, float *out_);

void fftwf_execute_split_dft_r2c(const fftwf_plan p,
                                    float *in_, float *ro, float *io);

void fftwf_execute_split_dft_c2r(const fftwf_plan p,
                                    float *ri, float *ii, float *out_);

fftwf_plan fftwf_plan_many_r2r(int rank, const int *n,
                            int howmany,
                            float *in_, const int *inembed,
                            int istride, int idist,
                            float *out_, const int *onembed,
                            int ostride, int odist,
                            const fftwf_r2r_kind *kind, uint flags);

fftwf_plan fftwf_plan_r2r(int rank, const int *n, float *in_, float *out_,
                       const fftwf_r2r_kind *kind, uint flags);

fftwf_plan fftwf_plan_r2r_1d(int n, float *in_, float *out_,
                          fftwf_r2r_kind kind, uint flags);

fftwf_plan fftwf_plan_r2r_2d(int n0, int n1, float *in_, float *out_,
                          fftwf_r2r_kind kind0, fftwf_r2r_kind kind1,
                          uint flags);

fftwf_plan fftwf_plan_r2r_3d(int n0, int n1, int n2,
                          float *in_, float *out_, fftwf_r2r_kind kind0,
                          fftwf_r2r_kind kind1, fftwf_r2r_kind kind2,
                          uint flags);

fftwf_plan fftwf_plan_guru_r2r(int rank, const fftwf_iodim *dims,
                            int howmany_rank,
                            const fftwf_iodim *howmany_dims,
                            float *in_, float *out_,
                            const fftwf_r2r_kind *kind, uint flags);

fftwf_plan fftwf_plan_guru64_r2r(int rank, const fftwf_iodim64 *dims,
                              int howmany_rank,
                              const fftwf_iodim64 *howmany_dims,
                              float *in_, float *out_,
                              const fftwf_r2r_kind *kind, uint flags);

void fftwf_execute_r2r(const fftwf_plan p, float *in_, float *out_);

void fftwf_destroy_plan(fftwf_plan p);

void fftwf_forget_wisdom();
void fftwf_cleanup();

void fftwf_set_timelimit(double t);

void fftwf_plan_with_nthreads(int nthreads);

int fftwf_init_threads();

void fftwf_cleanup_threads();

void fftwf_make_planner_thread_safe();

int fftwf_export_wisdom_to_filename(const char *filename);

/*void fftwf_export_wisdom_to_file(FILE *output_file);*/

char * fftwf_export_wisdom_to_string();

/*void fftwf_export_wisdom(fftwf_write_char_func write_char, void *data);*/
int fftwf_import_system_wisdom();

int fftwf_import_wisdom_from_filename(const char *filename);

/*int fftwf_import_wisdom_from_file(FILE *input_file);*/

int fftwf_import_wisdom_from_string(const char *input_string);

/*int fftwf_import_wisdom(fftwf_read_char_func read_char, void *data);*/

/*void fftwf_fprint_plan(const fftwf_plan p, FILE *output_file);*/

void fftwf_print_plan(const fftwf_plan p);

char * fftwf_sprint_plan(const fftwf_plan p);

void * fftwf_malloc(size_t n);

float * fftwf_alloc_real(size_t n);
fftwf_complex * fftwf_alloc_complex(size_t n);

void fftwf_free(void *p);

void fftwf_flops(const fftwf_plan p,
                    double *add, double *mul, double *fmas);
double fftwf_estimate_cost(const fftwf_plan p);

double fftwf_cost(const fftwf_plan p);

int fftwf_alignment_of(float *p);

/*
const char fftwf_version[];
const char fftwf_cc[];
const char fftwf_codelet_optim[];
*/


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
