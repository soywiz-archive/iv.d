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


/*FFTW_DEFINE_COMPLEX(double, fftw_complex);*/
alias fftw_complex = double[2];


/*struct fftw_plan_s *fftw_plan;*/
alias fftw_plan = void*;

/*
typedef struct fftw_iodim_do_not_use_me fftw_iodim;
typedef struct fftw_iodim64_do_not_use_me fftw_iodim64;

typedef enum fftw_r2r_kind_do_not_use_me fftw_r2r_kind;

typedef fftw_write_char_func_do_not_use_me fftw_write_char_func;
typedef fftw_read_char_func_do_not_use_me fftw_read_char_func;
*/

alias fftw_iodim = fftw_iodim_do_not_use_me;
alias fftw_iodim64 = fftw_iodim64_do_not_use_me;
alias fftw_r2r_kind = int;

void fftw_execute(const fftw_plan p);

fftw_plan fftw_plan_dft(int rank, const int *n,
                       fftw_complex *in_, fftw_complex *out_, int sign, uint flags);

fftw_plan fftw_plan_dft_1d(int n, fftw_complex *in_, fftw_complex *out_, int sign,
                          uint flags);
fftw_plan fftw_plan_dft_2d(int n0, int n1,
                          fftw_complex *in_, fftw_complex *out_, int sign, uint flags);
fftw_plan fftw_plan_dft_3d(int n0, int n1, int n2,
                          fftw_complex *in_, fftw_complex *out_, int sign, uint flags);

fftw_plan fftw_plan_many_dft(int rank, const int *n,
                            int howmany,
                            fftw_complex *in_, const int *inembed,
                            int istride, int idist,
                            fftw_complex *out_, const int *onembed,
                            int ostride, int odist,
                            int sign, uint flags);

fftw_plan fftw_plan_guru_dft(int rank, const fftw_iodim *dims,
                            int howmany_rank,
                            const fftw_iodim *howmany_dims,
                            fftw_complex *in_, fftw_complex *out_,
                            int sign, uint flags);
fftw_plan fftw_plan_guru_split_dft(int rank, const fftw_iodim *dims,
                                  int howmany_rank,
                                  const fftw_iodim *howmany_dims,
                                  double *ri, double *ii, double *ro, double *io,
                                  uint flags);

fftw_plan fftw_plan_guru64_dft(int rank,
                              const fftw_iodim64 *dims,
                              int howmany_rank,
                              const fftw_iodim64 *howmany_dims,
                              fftw_complex *in_, fftw_complex *out_,
                              int sign, uint flags);
fftw_plan fftw_plan_guru64_split_dft(int rank,
                                    const fftw_iodim64 *dims,
                                    int howmany_rank,
                                    const fftw_iodim64 *howmany_dims,
                                    double *ri, double *ii, double *ro, double *io,
                                    uint flags);

void fftw_execute_dft(const fftw_plan p, fftw_complex *in_, fftw_complex *out_);

void fftw_execute_split_dft(const fftw_plan p, double *ri, double *ii,
                                      double *ro, double *io);

fftw_plan fftw_plan_many_dft_r2c(int rank, const int *n,
                                int howmany,
                                double *in_, const int *inembed,
                                int istride, int idist,
                                fftw_complex *out_, const int *onembed,
                                int ostride, int odist,
                                uint flags);

fftw_plan fftw_plan_dft_r2c(int rank, const int *n,
                           double *in_, fftw_complex *out_, uint flags);

fftw_plan fftw_plan_dft_r2c_1d(int n,double *in_,fftw_complex *out_,uint flags);

fftw_plan fftw_plan_dft_r2c_2d(int n0, int n1,
                              double *in_, fftw_complex *out_, uint flags);

fftw_plan fftw_plan_dft_r2c_3d(int n0, int n1,
                              int n2,
                              double *in_, fftw_complex *out_, uint flags);

fftw_plan fftw_plan_many_dft_c2r(int rank, const int *n,
                                int howmany,
                                fftw_complex *in_, const int *inembed,
                                int istride, int idist,
                                double *out_, const int *onembed,
                                int ostride, int odist,
                                uint flags);

fftw_plan fftw_plan_dft_c2r(int rank, const int *n,
                           fftw_complex *in_, double *out_, uint flags);

fftw_plan fftw_plan_dft_c2r_1d(int n,fftw_complex *in_,double *out_,uint flags);

fftw_plan fftw_plan_dft_c2r_2d(int n0, int n1,
                              fftw_complex *in_, double *out_, uint flags);

fftw_plan fftw_plan_dft_c2r_3d(int n0, int n1,
                              int n2,
                              fftw_complex *in_, double *out_, uint flags);

fftw_plan fftw_plan_guru_dft_r2c(int rank, const fftw_iodim *dims,
                                int howmany_rank,
                                const fftw_iodim *howmany_dims,
                                double *in_, fftw_complex *out_,
                                uint flags);

fftw_plan fftw_plan_guru_dft_c2r(int rank, const fftw_iodim *dims,
                                int howmany_rank,
                                const fftw_iodim *howmany_dims,
                                fftw_complex *in_, double *out_,
                                uint flags);

fftw_plan fftw_plan_guru_split_dft_r2c(int rank, const fftw_iodim *dims,
                                      int howmany_rank,
                                      const fftw_iodim *howmany_dims,
                                      double *in_, double *ro, double *io,
                                      uint flags);

fftw_plan fftw_plan_guru_split_dft_c2r(int rank, const fftw_iodim *dims,
                                      int howmany_rank,
                                      const fftw_iodim *howmany_dims,
                                      double *ri, double *ii, double *out_,
                                      uint flags);

fftw_plan fftw_plan_guru64_dft_r2c(int rank,
                                  const fftw_iodim64 *dims,
                                  int howmany_rank,
                                  const fftw_iodim64 *howmany_dims,
                                  double *in_, fftw_complex *out_,
                                  uint flags);

fftw_plan fftw_plan_guru64_dft_c2r(int rank,
                                  const fftw_iodim64 *dims,
                                  int howmany_rank,
                                  const fftw_iodim64 *howmany_dims,
                                  fftw_complex *in_, double *out_,
                                  uint flags);

fftw_plan fftw_plan_guru64_split_dft_r2c(int rank, const fftw_iodim64 *dims,
                                        int howmany_rank,
                                        const fftw_iodim64 *howmany_dims,
                                        double *in_, double *ro, double *io,
                                        uint flags);
fftw_plan fftw_plan_guru64_split_dft_c2r(int rank, const fftw_iodim64 *dims,
                                        int howmany_rank,
                                        const fftw_iodim64 *howmany_dims,
                                        double *ri, double *ii, double *out_,
                                        uint flags);

void fftw_execute_dft_r2c(const fftw_plan p, double *in_, fftw_complex *out_);

void fftw_execute_dft_c2r(const fftw_plan p, fftw_complex *in_, double *out_);

void fftw_execute_split_dft_r2c(const fftw_plan p,
                                    double *in_, double *ro, double *io);

void fftw_execute_split_dft_c2r(const fftw_plan p,
                                    double *ri, double *ii, double *out_);

fftw_plan fftw_plan_many_r2r(int rank, const int *n,
                            int howmany,
                            double *in_, const int *inembed,
                            int istride, int idist,
                            double *out_, const int *onembed,
                            int ostride, int odist,
                            const fftw_r2r_kind *kind, uint flags);

fftw_plan fftw_plan_r2r(int rank, const int *n, double *in_, double *out_,
                       const fftw_r2r_kind *kind, uint flags);

fftw_plan fftw_plan_r2r_1d(int n, double *in_, double *out_,
                          fftw_r2r_kind kind, uint flags);

fftw_plan fftw_plan_r2r_2d(int n0, int n1, double *in_, double *out_,
                          fftw_r2r_kind kind0, fftw_r2r_kind kind1,
                          uint flags);

fftw_plan fftw_plan_r2r_3d(int n0, int n1, int n2,
                          double *in_, double *out_, fftw_r2r_kind kind0,
                          fftw_r2r_kind kind1, fftw_r2r_kind kind2,
                          uint flags);

fftw_plan fftw_plan_guru_r2r(int rank, const fftw_iodim *dims,
                            int howmany_rank,
                            const fftw_iodim *howmany_dims,
                            double *in_, double *out_,
                            const fftw_r2r_kind *kind, uint flags);

fftw_plan fftw_plan_guru64_r2r(int rank, const fftw_iodim64 *dims,
                              int howmany_rank,
                              const fftw_iodim64 *howmany_dims,
                              double *in_, double *out_,
                              const fftw_r2r_kind *kind, uint flags);

void fftw_execute_r2r(const fftw_plan p, double *in_, double *out_);

void fftw_destroy_plan(fftw_plan p);

void fftw_forget_wisdom();
void fftw_cleanup();

void fftw_set_timelimit(double t);

void fftw_plan_with_nthreads(int nthreads);

int fftw_init_threads();

void fftw_cleanup_threads();

void fftw_make_planner_thread_safe();

int fftw_export_wisdom_to_filename(const char *filename);

/*void fftw_export_wisdom_to_file(FILE *output_file);*/

char * fftw_export_wisdom_to_string();

/*void fftw_export_wisdom(fftw_write_char_func write_char, void *data);*/
int fftw_import_system_wisdom();

int fftw_import_wisdom_from_filename(const char *filename);

/*int fftw_import_wisdom_from_file(FILE *input_file);*/

int fftw_import_wisdom_from_string(const char *input_string);

/*int fftw_import_wisdom(fftw_read_char_func read_char, void *data);*/

/*void fftw_fprint_plan(const fftw_plan p, FILE *output_file);*/

void fftw_print_plan(const fftw_plan p);

char * fftw_sprint_plan(const fftw_plan p);

void * fftw_malloc(size_t n);

double * fftw_alloc_real(size_t n);
fftw_complex * fftw_alloc_complex(size_t n);

void fftw_free(void *p);

void fftw_flops(const fftw_plan p,
                    double *add, double *mul, double *fmas);
double fftw_estimate_cost(const fftw_plan p);

double fftw_cost(const fftw_plan p);

int fftw_alignment_of(double *p);

/*
const char fftw_version[];
const char fftw_cc[];
const char fftw_codelet_optim[];
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
