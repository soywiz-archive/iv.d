/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 1, September 2015
 *
 * Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 1. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 2. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0 and 1 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv1
 */
module iv.glob;


////////////////////////////////////////////////////////////////////////////////
// low-level interface

import core.sys.posix.sys.stat : stat_t;
import core.sys.posix.dirent : dirent;
//import core.sys.posix.config : __USE_FILE_OFFSET64;
import core.sys.linux.config : __USE_GNU, __USE_MISC;

//static assert(__USE_MISC);

@trusted nothrow @nogc extern(C) {

/* Bits set in the FLAGS argument to `glob'.  */
enum {
  GLOB_ERR      = (1 << 0), /* Return on read errors.  */
  GLOB_MARK     = (1 << 1), /* Append a slash to each name.  */
  GLOB_NOSORT   = (1 << 2), /* Don't sort the names.  */
  GLOB_DOOFFS   = (1 << 3), /* Insert PGLOB->gl_offs NULLs.  */
  GLOB_NOCHECK  = (1 << 4), /* If nothing matches, return the pattern.  */
  GLOB_APPEND   = (1 << 5), /* Append to results of a previous call.  */
  GLOB_NOESCAPE = (1 << 6), /* Backslashes don't quote metacharacters.  */
  GLOB_PERIOD   = (1 << 7), /* Leading `.' can be matched by metachars.  */
}

/* posix-2 extensions */
static if (__USE_MISC) enum {
  GLOB_MAGCHAR     = (1 << 8), /* Set in gl_flags if any metachars seen.  */
  GLOB_ALTDIRFUNC  = (1 << 9), /* Use gl_opendir et al functions.  */
  GLOB_BRACE       = (1 << 10), /* Expand "{a,b}" to "a" "b".  */
  GLOB_NOMAGIC     = (1 << 11), /* If no magic chars, return the pattern.  */
  GLOB_TILDE       = (1 << 12), /* Expand ~user and ~ to home directories. */
  GLOB_ONLYDIR     = (1 << 13), /* Match only directories.  */
  GLOB_TILDE_CHECK = (1 << 14), /* Like GLOB_TILDE but return an error if the user name is not available.  */
}

/* Error returns from `glob'.  */
enum {
  GLOB_OK = 0,
  GLOB_NOERROR = 0,
  GLOB_NOSPACE = 1, /* Ran out of memory.  */
  GLOB_ABORTED = 2, /* Read error.  */
  GLOB_NOMATCH = 3, /* No matches found.  */
  GLOB_NOSYS   = 4, /* Not implemented.  */
}
/* Previous versions of this file defined GLOB_ABEND instead of
   GLOB_ABORTED.  Provide a compatibility definition here.  */
static if (__USE_GNU) enum GLOB_ABEND = GLOB_ABORTED;


struct glob_t {
  size_t gl_pathc;
  char** gl_pathv;
  size_t gl_offs;
  int gl_flags;

  /* If the GLOB_ALTDIRFUNC flag is set, the following functions
     are used instead of the normal file access functions.  */
  static if (__USE_GNU) {
    void function (void*) gl_closedir;
    dirent* function (void*) gl_readdir;
    void* function (const char *) gl_opendir;
    int function (const(char)*, stat_t*) gl_lstat;
    int function (const(char)*, stat_t*) gl_stat;
  } else {
    void function (void*) gl_closedir;
    void* function (void*) gl_readdir;
    void* function (const char *) gl_opendir;
    int function (const(char)*, void*) gl_lstat;
    int function (const(char)*, void*) gl_stat;
  }
}

alias GlobErrFunc = int function (const(char)* epath, int eerrno) @trusted nothrow @nogc;

/* Do glob searching for PATTERN, placing results in PGLOB.
   The bits defined above may be set in FLAGS.
   If a directory cannot be opened or read and ERRFUNC is not nil,
   it is called with the pathname that caused the error, and the
   `errno' value from the failing call; if it returns non-zero
   `glob' returns GLOB_ABEND; if it returns zero, the error is ignored.
   If memory cannot be allocated for PGLOB, GLOB_NOSPACE is returned.
   Otherwise, `glob' returns zero.  */
int glob (const(char)* pattern, int flags, GlobErrFunc errfunc, glob_t* pglob);

/* Free storage allocated in PGLOB by a previous `glob' call.  */
void globfree (glob_t* pglob);

/* Return nonzero if PATTERN contains any metacharacters.
   Metacharacters can be quoted with backslashes if QUOTE is nonzero.

   This function is not part of the interface specified by POSIX.2
   but several programs want to use it.  */
static if (__USE_GNU) int glob_pattern_p (const(char)* __pattern, int __quote);
}


////////////////////////////////////////////////////////////////////////////////
// high-level interface
struct Glob {
@trusted:
  private int opApplyX(DG, string dir="normal") (scope DG dg)
  if (isCallable!DG &&
      (ParameterTypeTuple!DG.length == 1 && is(ParameterTypeTuple!DG[0] : Item)) ||
      (ParameterTypeTuple!DG.length == 2 && isIntegral!(ParameterTypeTuple!DG[0]) && is(ParameterTypeTuple!DG[1] : Item)))
  {
    alias ptt = ParameterTypeTuple!DG;
    int res = 0;
    enum foreachBody = q{
      auto it = Item(ge, idx);
      static if (ptt.length == 2) {
        static if (idx.sizeof != ptt[0].sizeof) {
          auto i = cast(ptt[0])idx;
          res = dg(i, it);
        } else {
          res = dg(idx, it);
        }
      } else {
        res = dg(it);
      }
      if (res) break;
    };
    static if (dir == "normal") {
      foreach (size_t idx; 0..ge.gb.gl_pathc) { mixin(foreachBody); }
    } else static if (dir == "reverse") {
      foreach_reverse (size_t idx; 0..ge.gb.gl_pathc) { mixin(foreachBody); }
    } else {
      static assert(false, "wtf?!");
    }
    return res;
  }

  int opApply (scope int delegate (ref Item) dg) { return opApplyX!(typeof(dg))(dg); }
  int opApply (scope int delegate (ref size_t idx, ref Item) dg) { return opApplyX!(typeof(dg))(dg); }

  int opApplyReverse (scope int delegate (ref Item) dg) { return opApplyX!(typeof(dg), "reverse")(dg); }
  int opApplyReverse (scope int delegate (ref size_t idx, ref Item) dg) { return opApplyX!(typeof(dg), "reverse")(dg); }

nothrow @nogc: // ah, let's dance!
private:
  this (globent* ange, size_t idx=0) {
    ge = ange;
    Glob.incref(ge);
  }

public:
  this (const(char)[] pattern, int flags=GLOB_BRACE|GLOB_TILDE_CHECK) {
    // remove bad flags, add good flags
    flags &= ~(GLOB_DOOFFS|GLOB_APPEND);
    static if (__USE_MISC) flags &= ~(GLOB_MAGCHAR|GLOB_ALTDIRFUNC);
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;
    import core.exception : onOutOfMemoryErrorNoGC;
    import std.internal.cstring : tempCString;
    ge = cast(globent*)malloc(globent.sizeof);
    if (ge is null) onOutOfMemoryErrorNoGC();
    version(iv_glob_debug) { import core.stdc.stdio : stdout, fprintf; fprintf(stdout, "new %p\n", ge); }
    memset(ge, globent.sizeof, 0); // just in case
    ge.refcount = 1;
    ge.res = .glob(pattern.tempCString, flags|GLOB_ERR, null, &ge.gb);
  }

  this (this) { Glob.incref(ge); }

  ~this () { Glob.decref(ge); }

  // note that "no match" is error too!
  @property bool error () pure const { return (ge.res != 0); }
  @property bool nomatch () pure const { return (ge.res == GLOB_NOMATCH); }

  @property size_t length () pure const { return (idx < ge.gb.gl_pathc ? ge.gb.gl_pathc-idx : 0); }
  alias opDollar = length;

  void rewind () { idx = 0; }

  @property bool empty () pure const { return (idx >= ge.gb.gl_pathc); }
  @property auto save () { return Glob(ge, idx); }
  void popFront () { if (idx < ge.gb.gl_pathc) ++idx; }

  @property auto front () {
    if (idx >= ge.gb.gl_pathc) {
      import core.exception : RangeError;
      throw staticError!RangeError();
    }
    return Item(ge, idx);
  }

  auto opIndex (size_t idx) {
    if (idx >= ge.gb.gl_pathc) {
      import core.exception : RangeError;
      throw staticError!RangeError();
    }
    return Item(ge, idx);
  }

  private import std.traits;

private:
  static struct globent {
    size_t refcount;
    glob_t gb;
    int res;
  }

  static struct Item {
  @trusted nothrow @nogc: // ah, let's dance!
  private:
    globent* ge;
    size_t idx;

    this (globent* ange, size_t anidx) {
      ge = ange;
      idx = anidx;
      Glob.incref(ge);
    }

  public:
    this (this) { assert(ge !is null); Glob.incref(ge); }
    ~this () { assert(ge !is null); Glob.decref(ge); }

    @property size_t index () pure const { return idx; }

    // WARNING! this can escape!
    @property const(char)[] name () pure const return {
      size_t pos = 0;
      auto ptr = ge.gb.gl_pathv[idx];
      while (ptr[pos]) ++pos;
      return ptr[0..pos];
    }

    @property bool prev () { if (idx > 0) { --idx; return true; } else return false; }
    @property bool next () { if (idx < ge.gb.gl_pathc) { ++idx; return true; } else return false; }
  }

  static void incref (globent* ge) @safe nothrow @nogc {
    pragma(inline, true);
    assert(ge !is null);
    ++ge.refcount;
  }

  static void decref (globent* ge) @trusted nothrow @nogc {
    pragma(inline, true);
    assert(ge !is null);
    if (--ge.refcount == 0) {
      version(iv_glob_debug) { import core.stdc.stdio : stdout, fprintf; fprintf(stdout, "freeing %p\n", ge); }
      import core.stdc.stdlib : free;
      globfree(&ge.gb);
      free(ge);
    }
  }

private:
  globent* ge;
  size_t idx; // current position in range
}


////////////////////////////////////////////////////////////////////////////////
// shamelessly borrowed from `core.exception`
// TLS storage shared for all errors, chaining might create circular reference
private void[128] stestore_;

// only Errors for now as those are rarely chained
private T staticError(T, Args...) (auto ref Args args) if (is(T : Error)) {
  // pure hack, what we actually need is @noreturn and allow to call that in pure functions
  static T get () {
    static assert(__traits(classInstanceSize, T) <= stestore_.length, T.stringof~" is too large for staticError()");
    stestore_[0..__traits(classInstanceSize, T)] = typeid(T).init[];
    return cast(T) stestore_.ptr;
  }
  auto res = (cast(T function() @trusted pure nothrow @nogc) &get)();
  res.__ctor(args);
  return res;
}