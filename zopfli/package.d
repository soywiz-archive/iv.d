/*
Copyright 2011 Google Inc. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Author: lode.vandevenne@gmail.com (Lode Vandevenne)
Author: jyrki.alakuijala@gmail.com (Jyrki Alakuijala)
*/
module iv.zopfli /*is aliced*/;
extern(C) nothrow @nogc:
import iv.alice;
//pragma(lib, "libzopfli.a");
pragma(lib, "zopfli");

/*
Options used throughout the program.
*/
struct ZopfliOptions {
  /* Whether to print output */
  int verbose = 0;

  /* Whether to print more detailed output */
  int verbose_more = 0;

  /*
  Maximum amount of times to rerun forward and backward pass to optimize LZ77
  compression cost. Good values: 10, 15 for small files, 5 for files over
  several MB in size or it will be too slow.
  */
  int numiterations = 15;

  /*
  If true, splits the data in multiple deflate blocks with optimal choice
  for the block boundaries. Block splitting gives better compression. Default:
  true (1).
  */
  int blocksplitting = 1;

  /*
  No longer used, left for compatibility.
  */
  int blocksplittinglast = 0;

  /*
  Maximum amount of blocks to split into (0 for unlimited, but this can give
  extreme results that hurt compression on some files). Default value: 15.
  */
  int blocksplittingmax = 15;
}


/* Output format */
alias ZopfliFormat = int;
enum {
  ZOPFLI_FORMAT_GZIP,
  ZOPFLI_FORMAT_ZLIB,
  ZOPFLI_FORMAT_DEFLATE,
}

/*
Compresses according to the given output format and appends the result to the
output.

options: global program options
output_type: the output format to use
out: pointer to the dynamic output array to which the result is appended. Must
  be `free()`d after use (you can use `ZopfliFree()`)
outsize: pointer to the dynamic output array size
*/
void ZopfliCompress (const ref ZopfliOptions options, ZopfliFormat output_type,
                     const(void)* indata, usize insize,
                     void** outarr, usize* outsize);

void ZopfliFree (void* ptr) { import core.stdc.stdlib : free; if (ptr !is null) free(ptr); }
