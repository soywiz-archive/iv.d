/*
 * Copyright (c) Christos Zoulas 2003.
 * All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice immediately at the beginning of the file, without modification,
 *    this list of conditions, and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
module iv.libmagic /*is aliced*/;
pragma(lib, "magic");

import iv.alice;


extern(C) @trusted nothrow @nogc:
enum {
  MAGIC_NONE               = 0x0000000, /* No flags */
  MAGIC_DEBUG              = 0x0000001, /* Turn on debugging */
  MAGIC_SYMLINK            = 0x0000002, /* Follow symlinks */
  MAGIC_COMPRESS           = 0x0000004, /* Check inside compressed files */
  MAGIC_DEVICES            = 0x0000008, /* Look at the contents of devices */
  MAGIC_MIME_TYPE          = 0x0000010, /* Return the MIME type */
  MAGIC_CONTINUE           = 0x0000020, /* Return all matches */
  MAGIC_CHECK              = 0x0000040, /* Print warnings to stderr */
  MAGIC_PRESERVE_ATIME     = 0x0000080, /* Restore access time on exit */
  MAGIC_RAW                = 0x0000100, /* Don't convert unprintable chars */
  MAGIC_ERROR              = 0x0000200, /* Handle ENOENT etc as real errors */
  MAGIC_MIME_ENCODING      = 0x0000400, /* Return the MIME encoding */
  MAGIC_MIME               = (MAGIC_MIME_TYPE|MAGIC_MIME_ENCODING),
  MAGIC_APPLE              = 0x0000800, /* Return the Apple creator/type */
  MAGIC_EXTENSION          = 0x1000000, /* Return a /-separated list of extensions */
  MAGIC_COMPRESS_TRANSP    = 0x2000000, /* Check inside compressed files but not report compression */
  MAGIC_NODESC             = (MAGIC_EXTENSION|MAGIC_MIME|MAGIC_APPLE),

  MAGIC_NO_CHECK_COMPRESS  = 0x0001000, /* Don't check for compressed files */
  MAGIC_NO_CHECK_TAR       = 0x0002000, /* Don't check for tar files */
  MAGIC_NO_CHECK_SOFT      = 0x0004000, /* Don't check magic entries */
  MAGIC_NO_CHECK_APPTYPE   = 0x0008000, /* Don't check application type */
  MAGIC_NO_CHECK_ELF       = 0x0010000, /* Don't check for elf details */
  MAGIC_NO_CHECK_TEXT      = 0x0020000, /* Don't check for text files */
  MAGIC_NO_CHECK_CDF       = 0x0040000, /* Don't check for cdf files */
  MAGIC_NO_CHECK_TOKENS    = 0x0100000, /* Don't check tokens */
  MAGIC_NO_CHECK_ENCODING  = 0x0200000, /* Don't check text encodings */
}

/* No built-in tests; only consult the magic file */
enum MAGIC_NO_CHECK_BUILTIN = (
  MAGIC_NO_CHECK_COMPRESS |
  MAGIC_NO_CHECK_TAR      |
  /*MAGIC_NO_CHECK_SOFT   | */
  MAGIC_NO_CHECK_APPTYPE  |
  MAGIC_NO_CHECK_ELF      |
  MAGIC_NO_CHECK_TEXT     |
  MAGIC_NO_CHECK_CDF      |
  MAGIC_NO_CHECK_TOKENS   |
  MAGIC_NO_CHECK_ENCODING |
  0);

/* Defined for backwards compatibility (renamed) */
enum MAGIC_NO_CHECK_ASCII = MAGIC_NO_CHECK_TEXT;

/* Defined for backwards compatibility; do nothing */
enum {
  MAGIC_NO_CHECK_FORTRAN = 0x000000, /* Don't check ascii/fortran */
  MAGIC_NO_CHECK_TROFF   = 0x000000, /* Don't check ascii/troff */
}

enum MAGIC_VERSION = 524; /* This implementation */


struct magic_set_ {}
alias magic_t = magic_set_*;

magic_t magic_open (int flags);
void magic_close (magic_t cookie);

const(char)* magic_getpath (const(char)* filename, int);
const(char)* magic_file (magic_t cookie, const(char)* filename);
const(char)* magic_descriptor (magic_t cookie, int fd);
const(char)* magic_buffer (magic_t cookie, const(void)* buffer, usize length);

const(char)* magic_error (magic_t cookie);
int magic_setflags (magic_t cookie, int flags);

int magic_version ();
int magic_load (magic_t cookie, const(char)* filename);
int magic_load_buffers (magic_t cookie, void** buffers, usize* sizes, usize nbuffers);

int magic_compile (magic_t cookie, const(char)* filename);
int magic_check (magic_t cookie, const(char)* filename);
int magic_list (magic_t cookie, const(char)* filename);
int magic_errno (magic_t cookie);

enum {
  MAGIC_PARAM_INDIR_MAX     = 0,
  MAGIC_PARAM_NAME_MAX      = 1,
  MAGIC_PARAM_ELF_PHNUM_MAX = 2,
  MAGIC_PARAM_ELF_SHNUM_MAX = 3,
  MAGIC_PARAM_ELF_NOTES_MAX = 4,
  MAGIC_PARAM_REGEX_MAX     = 5,
}

int magic_setparam (magic_t cookie, int param, const(void)* value);
int magic_getparam (magic_t cookie, int param, void* value);
