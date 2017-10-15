/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
/* contains very simple compile-time format writer
 * understands [+|-]width[.maxlen]
 *   negative width: add spaces to right
 *   + signed width: center
 *   negative maxlen: get right part
 * specifiers:
 *   's': use to!string to write argument
 *        note that writer can print strings, bools, integrals and floats without allocation
 *   'x': write integer as hex
 *   'X': write integer as HEX
 *   '!': skip all arguments that's left, no width allowed
 *   '%': just a percent sign, no width allowed
 *   '|': print all arguments that's left with simple "%s", no width allowed
 *   '<...>': print all arguments that's left with simple "%s", delimited with "...", no width allowed
 * options (must immediately follow '%'):
 *   '~': fill with the following char instead of space
 *        second '~': right filling char for 'center'
 */
module iv.cmdcon.core /*is aliced*/;
private:
import iv.alice;

//version = iv_cmdcon_debug_wait;
//version = iv_cmdcon_honest_ctfe_writer;


// ////////////////////////////////////////////////////////////////////////// //
/// use this in conGetVar, for example, to avoid allocations
public alias ConString = const(char)[];


// ////////////////////////////////////////////////////////////////////////// //
public enum ConDump : int { none, stdout, stderr }
shared ConDump conStdoutFlag = ConDump.stdout;
public @property ConDump conDump () nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicLoad; return atomicLoad(conStdoutFlag); } /// write console output to ...
public @property void conDump (ConDump v) nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicStore; atomicStore(conStdoutFlag, v); } /// ditto

shared static this () {
  conRegVar!conStdoutFlag("console_dump", "dump console output (none, stdout, stderr)");
}


// ////////////////////////////////////////////////////////////////////////// //
import core.sync.mutex : Mutex;
__gshared Mutex consoleLocker;
shared static this () { consoleLocker = new Mutex(); }


// ////////////////////////////////////////////////////////////////////////// //
enum isGShared(alias v) = !__traits(compiles, ()@safe{auto _=&v;}());
enum isShared(alias v) = is(typeof(v) == shared);
enum isGoodVar(alias v) = isGShared!v || isShared!v;
//alias isGoodVar = isGShared;


// ////////////////////////////////////////////////////////////////////////// //
private bool strEquCI (const(char)[] s0, const(char)[] s1) pure nothrow @trusted @nogc {
  if (s0.length != s1.length) return false;
  foreach (immutable idx, char c0; s0) {
    if (c0 >= 'A' && c0 <= 'Z') c0 += 32; // poor man's tolower()
    char c1 = s1.ptr[idx];
    if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man's tolower()
    if (c0 != c1) return false;
  }
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/*
version(test_cbuf)
  enum ConBufSize = 64;
else
  enum ConBufSize = 256*1024;
*/

// each line in buffer ends with '\n'; we don't keep offsets or lengthes, as
// it's fairly easy to search in buffer, and drawing console is not a common
// thing, so it doesn't have to be superfast.
__gshared char* cbuf = null;
__gshared int cbufhead, cbuftail; // `cbuftail` points *at* last char
__gshared bool cbufLastWasCR = false;
__gshared uint cbufcursize = 0;
__gshared uint cbufmaxsize = 256*1024;

shared static this () {
  import core.stdc.stdlib : malloc;
  //cbuf.ptr[0] = '\n';
  version(test_cbuf) {
    cbufcursize = 32;
    cbufmaxsize = 256;
  } else {
    cbufcursize = 8192;
  }
  cbuf = cast(char*)malloc(cbufcursize);
  if (cbuf is null) assert(0, "cmdcon: out of memory!"); // unlikely case
  cbuf[0..cbufcursize] = 0;
  cbuf[0] = '\n';

  conRegVar("con_bufsize", "current size of console output buffer", (ConVarBase self) => cbufcursize, (ConVarBase self, uint nv) {}, ConVarAttr.ReadOnly);
  conRegVar!cbufmaxsize(8192, 512*1024*1024, "con_bufmaxsize", "maximum size of console output buffer");
}

shared uint changeCount = 1;
public @property uint cbufLastChange () nothrow @trusted @nogc { import core.atomic; return atomicLoad(changeCount); } /// changed when something was written to console buffer


// ////////////////////////////////////////////////////////////////////////// //
/// multithread lock
public void consoleLock() () nothrow @trusted {
  version(aliced) pragma(inline, true);
  version(aliced) {
    consoleLocker.lock();
  } else {
    try { consoleLocker.lock(); } catch (Exception e) { assert(0, "fuck vanilla!"); }
  }
}

/// multithread unlock
public void consoleUnlock() () nothrow @trusted {
  version(aliced) pragma(inline, true);
  version(aliced) {
    consoleLocker.unlock();
  } else {
    try { consoleLocker.unlock(); } catch (Exception e) { assert(0, "fuck vanilla!"); }
  }
}

public __gshared void delegate () nothrow @trusted @nogc conWasNewLineCB; /// can be called in any thread; called if some '\n' was output with `conwrite*()`


// ////////////////////////////////////////////////////////////////////////// //
/// put characters to console buffer (and, possibly, STDOUT_FILENO). thread-safe.
public void cbufPut() (scope ConString chrs...) nothrow @trusted /*@nogc*/ { pragma(inline, true); if (chrs.length) cbufPutIntr!true(chrs); }

public void cbufPutIntr(bool dolock) (scope ConString chrs...) nothrow @trusted /*@nogc*/ {
  if (chrs.length) {
    import core.atomic : atomicLoad, atomicOp;
    static if (dolock) consoleLock();
    static if (dolock) scope(exit) consoleUnlock();
    final switch (/*atomicLoad(conStdoutFlag)*/cast(ConDump)conStdoutFlag) {
      case ConDump.none: break;
      case ConDump.stdout:
        version(Windows) {
          //fuck
          import core.sys.windows.winbase;
          import core.sys.windows.windef;
          import core.sys.windows.wincon;
          auto hh = GetStdHandle(STD_OUTPUT_HANDLE);
          if (hh != INVALID_HANDLE_VALUE) {
            DWORD ww;
            usize xpos = 0;
            while (xpos < chrs.length) {
              usize epos = xpos;
              while (epos < chrs.length && chrs.ptr[epos] != '\n') ++epos;
              if (epos > xpos) WriteConsoleA(hh, chrs.ptr, cast(DWORD)chrs.length, &ww, null);
              if (epos < chrs.length) WriteConsoleA(hh, "\r\n".ptr, cast(DWORD)2, &ww, null);
              xpos = epos+1;
            }
          }
        } else {
          import core.sys.posix.unistd : STDOUT_FILENO, write;
          write(STDOUT_FILENO, chrs.ptr, chrs.length);
        }
        break;
      case ConDump.stderr:
        version(Windows) {
          //fuck
          import core.sys.windows.winbase;
          import core.sys.windows.windef;
          import core.sys.windows.wincon;
          auto hh = GetStdHandle(STD_ERROR_HANDLE);
          if (hh != INVALID_HANDLE_VALUE) {
            DWORD ww;
            usize xpos = 0;
            while (xpos < chrs.length) {
              usize epos = xpos;
              while (epos < chrs.length && chrs.ptr[epos] != '\n') ++epos;
              if (epos > xpos) WriteConsoleA(hh, chrs.ptr, cast(DWORD)chrs.length, &ww, null);
              if (epos < chrs.length) WriteConsoleA(hh, "\r\n".ptr, cast(DWORD)2, &ww, null);
              xpos = epos+1;
            }
          }
        } else {
          import core.sys.posix.unistd : STDERR_FILENO, write;
          write(STDERR_FILENO, chrs.ptr, chrs.length);
        }
        break;
    }
    //atomicOp!"+="(changeCount, 1);
    bool wasNewLine = false;
    (*cast(uint*)&changeCount)++;
    foreach (char ch; chrs) {
      if (cbufLastWasCR && ch == '\x0a') { cbufLastWasCR = false; continue; }
      if ((cbufLastWasCR = (ch == '\x0d')) != false) ch = '\x0a';
      wasNewLine = wasNewLine || (ch == '\x0a');
      int np = (cbuftail+1)%cbufcursize;
      if (np == cbufhead) {
        // we have to make some room; delete top line for this
        bool removelines = true;
        // first, try grow cosole buffer if we can
        if (cbufcursize < cbufmaxsize) {
          import core.stdc.stdlib : realloc;
          version(test_cbuf) {
            auto newsz = cbufcursize+13;
          } else {
            auto newsz = cbufcursize*2;
          }
          if (newsz > cbufmaxsize) newsz = cbufmaxsize;
          //{ import core.stdc.stdio : stderr, fprintf; stderr.fprintf("*** CON: %u -> %u; head=%u; tail=%u; np=%u\n", cbufcursize, newsz, cbufhead, cbuftail, np); }
          auto nbuf = cast(char*)realloc(cbuf, newsz);
          if (nbuf !is null) {
            // yay, we got some room; move text down, so there will be more room
            version(test_cbuf) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("np=%u; cbufcursize=%u; cbufmaxsize=%u; newsz=%u; ndest=%u\n", np, cbufcursize, cbufmaxsize, newsz, newsz-cbufcursize, cbuf+np); }
            if (np == 0) {
              // yay, we can do some trickery here
              np = cbuftail+1; // yep, that easy
            } else {
              import core.stdc.string : memmove;
              auto tsz = cbufcursize-np;
              if (tsz > 0) memmove(cbuf+newsz-tsz, cbuf+np, tsz);
              cbufhead += newsz-cbufcursize;
            }
            cbufcursize = newsz;
            cbuf = nbuf;
            removelines = false;
            version(test_cbuf) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("  cbufhead=%u; cbuftail=%u\n", cbufhead, cbuftail); }
            assert(np < cbufcursize);
          }
        }
        if (removelines) {
          for (;;) {
            char och = cbuf[cbufhead];
            cbufhead = (cbufhead+1)%cbufcursize;
            if (cbufhead == np || och == '\n') break;
          }
        }
      }
      cbuf[np] = ch;
      cbuftail = np;
    }
    if (wasNewLine && conWasNewLineCB !is null) conWasNewLineCB();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// range of conbuffer lines, from last. not thread-safe.
/// warning! don't modify conbuf while the range is active!
public auto conbufLinesRev () nothrow @trusted @nogc {
  static struct Line {
  nothrow @trusted @nogc:
  private:
    int h, t; // head and tail, to check validity
    int sp = -1, ep;

  public:
    @property auto front () const { pragma(inline, true); return (sp >= 0 ? cbuf[sp] : '\x00'); }
    @property bool empty () const { pragma(inline, true); return (sp < 0 || h != cbufhead || t != cbuftail); }
    @property auto save () { pragma(inline, true); return Line(h, t, sp, ep); }
    void popFront () { pragma(inline, true); if (sp < 0 || (sp = (sp+1)%cbufcursize) == ep) sp = -1; }
    @property usize opDollar () { pragma(inline, true); return (sp >= 0 ? (sp > ep ? ep+cbufcursize-sp : ep-sp) : 0); }
    alias length = opDollar;
    char opIndex (usize pos) { pragma(inline, true); return (sp >= 0 ? cbuf[sp+pos] : '\x00'); }
  }

  static struct Range {
  nothrow @trusted @nogc:
  private:
    int h, t; // head and tail, to check validity
    int pos; // position of prev line
    Line line;

    void toLineStart () {
      line.ep = pos;
      while (pos != cbufhead) {
        int p = (pos+cbufcursize-1)%cbufcursize;
        if (cbuf[p] == '\n') break;
        pos = p;
      }
      line.sp = pos;
      line.h = h;
      line.t = t;
    }

  public:
    @property auto front () pure { pragma(inline, true); return line; }
    @property bool empty () const { pragma(inline, true); return (pos < 0 || pos == h || h != cbufhead || t != cbuftail); }
    @property auto save () { pragma(inline, true); return Range(h, t, pos, line); }
    void popFront () {
      if (pos < 0 || pos == h || h != cbufhead || t != cbuftail) { line = Line.init; h = t = pos = -1; return; }
      pos = (pos+cbufcursize-1)%cbufcursize;
      toLineStart();
    }
  }

  Range res;
  res.h = cbufhead;
  res.pos = res.t = cbuftail;
  if (cbuf[res.pos] != '\n') res.pos = (res.pos+1)%cbufcursize;
  res.toLineStart();
  //{ import std.stdio; writeln("pos=", res.pos, "; head=", res.h, "; tail=", res.t, "; llen=", res.line.length, "; [", res.line, "]"); }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
version(unittest) public void conbufDump () {
  import std.stdio;
  int pp = cbufhead;
  stdout.writeln("==========================");
  for (;;) {
    if (cbuf[pp] == '\n') stdout.write('|');
    stdout.write(cbuf[pp]);
    if (pp == cbuftail) {
      if (cbuf[pp] != '\n') stdout.write('\n');
      break;
    }
    pp = (pp+1)%cbufcursize;
  }
  //foreach (/+auto+/ s; conbufLinesRev) stdout.writeln(s, "|");
}


// ////////////////////////////////////////////////////////////////////////// //
version(test_cbuf) unittest {
  conbufDump();
  cbufPut("boo\n"); conbufDump();
  cbufPut("this is another line\n"); conbufDump();
  cbufPut("one more line\n"); conbufDump();
  cbufPut("foo\n"); conbufDump();
  cbufPut("more lines!\n"); conbufDump();
  cbufPut("and even more lines!\n"); conbufDump();
  foreach (immutable idx; 0..256) {
    import std.string : format;
    cbufPut("line %s\n".format(idx));
    conbufDump();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// writer
private import std.traits/* : isBoolean, isIntegral, isPointer*/;
//private alias StripTypedef(T) = T;

//__gshared void delegate (scope const(char[])) @trusted nothrow @nogc  conwriter;
//public @property auto ConWriter () @trusted nothrow @nogc { return conwriter; }
//public @property auto ConWriter (typeof(conwriter) cv) @trusted nothrow @nogc { auto res = conwriter; conwriter = cv; return res; }

void conwriter() (scope ConString str) nothrow @trusted /*@nogc*/ {
  pragma(inline, true);
  if (str.length > 0) cbufPut(str);
}


// ////////////////////////////////////////////////////////////////////////// //
// i am VERY sorry for this!
private template XUQQ(T) {
  static if (is(T : shared TT, TT)) {
         static if (is(TT : const TX, TX)) alias XUQQ = TX;
    else static if (is(TT : immutable TX, TX)) alias XUQQ = TX;
    else alias XUQQ = TT;
  } else static if (is(T : const TT, TT)) {
         static if (is(TT : shared TX, TX)) alias XUQQ = TX;
    else static if (is(TT : immutable TX, TX)) alias XUQQ = TX;
    else alias XUQQ = TT;
  } else static if (is(T : immutable TT, TT)) {
         static if (is(TT : const TX, TX)) alias XUQQ = TX;
    else static if (is(TT : shared TX, TX)) alias XUQQ = TX;
    else alias XUQQ = TT;
  } else {
    alias XUQQ = T;
  }
}
static assert(is(XUQQ!string == string));
static assert(is(XUQQ!(const(char)[]) == const(char)[]));


// ////////////////////////////////////////////////////////////////////////// //
private void cwrxputch (scope const(char)[] s...) nothrow @trusted @nogc {
  pragma(inline, true);
  if (s.length) cbufPutIntr!false(s); // no locking
}


private void cwrxputstr(bool cutsign=false) (scope const(char)[] str, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  if (maxwdt < 0) {
    if (maxwdt == maxwdt.min) ++maxwdt; // alas
    maxwdt = -(maxwdt);
    if (str.length > maxwdt) str = str[$-maxwdt..$];
  } else if (maxwdt > 0) {
    if (str.length > maxwdt) str = str[0..maxwdt];
  }
  static if (cutsign) {
    if (signw == ' ' && wdt && str.length && str.length < wdt) {
      if (str.ptr[0] == '-' || str.ptr[0] == '+') {
        cwrxputch(str.ptr[0]);
        str = str[1..$];
        --wdt;
      }
    }
  }
  if (str.length < wdt) {
    // '+' means "center"
    if (signw == '+') {
      foreach (immutable _; 0..(wdt-str.length)/2) cwrxputch(lchar);
    } else if (signw != '-') {
      foreach (immutable _; 0..wdt-str.length) cwrxputch(lchar);
    }
  }
  cwrxputch(str);
  if (str.length < wdt) {
    // '+' means "center"
    if (signw == '+') {
      foreach (immutable _; ((wdt-str.length)/2)+str.length..wdt) cwrxputch(rchar);
    } else if (signw == '-') {
      foreach (immutable _; 0..wdt-str.length) cwrxputch(rchar);
    }
  }
}


private void cwrxputstrz(bool cutsign=false) (scope const(char)* str, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  if (str is null) {
    cwrxputstr!cutsign("", signw, lchar, rchar, wdt, maxwdt);
  } else {
    auto end = str;
    while (*end) ++end;
    cwrxputstr!cutsign(str[0..cast(usize)(end-str)], signw, lchar, rchar, wdt, maxwdt);
  }
}


private void cwrxputchar (char ch, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  cwrxputstr((&ch)[0..1], signw, lchar, rchar, wdt, maxwdt);
}


private void cwrxputint(TT) (TT nn, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  char[32] buf = ' ';

  static if (is(TT == shared)) {
    import core.atomic;
    alias T = XUQQ!TT;
    T n = atomicLoad(nn);
  } else {
    alias T = XUQQ!TT;
    T n = nn;
  }

  static if (is(T == long)) {
    if (n == 0x8000_0000_0000_0000uL) { cwrxputstr!true("-9223372036854775808", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == int)) {
    if (n == 0x8000_0000u) { cwrxputstr!true("-2147483648", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == short)) {
    if ((n&0xffff) == 0x8000u) { cwrxputstr!true("-32768", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == byte)) {
    if ((n&0xff) == 0x80u) { cwrxputstr!true("-128", signw, lchar, rchar, wdt, maxwdt); return; }
  }

  static if (__traits(isUnsigned, T)) {
    enum neg = false;
  } else {
    bool neg = (n < 0);
    if (neg) n = -(n);
  }

  int bpos = buf.length;
  do {
    //if (bpos == 0) assert(0, "internal printer error");
    buf.ptr[--bpos] = cast(char)('0'+n%10);
    n /= 10;
  } while (n != 0);
  if (neg) {
    //if (bpos == 0) assert(0, "internal printer error");
    buf.ptr[--bpos] = '-';
  }
  cwrxputstr!true(buf[bpos..$], signw, lchar, rchar, wdt, maxwdt);
}


private void cwrxputhex(TT) (TT nn, bool upcase, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  char[32] buf = ' ';

  static if (is(TT == shared)) {
    import core.atomic;
    alias T = XUQQ!TT;
    T n = atomicLoad(nn);
  } else {
    alias T = XUQQ!TT;
    T n = nn;
  }

  static if (is(T == long)) {
    if (n == 0x8000_0000_0000_0000uL) { cwrxputstr!true("-8000000000000000", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == int)) {
    if (n == 0x8000_0000u) { cwrxputstr!true("-80000000", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == short)) {
    if (n == 0x8000u) { cwrxputstr!true("-8000", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == byte)) {
    if (n == 0x80u) { cwrxputstr!true("-80", signw, lchar, rchar, wdt, maxwdt); return; }
  }

  static if (__traits(isUnsigned, T)) {
    enum neg = false;
  } else {
    bool neg = (n < 0);
    if (neg) n = -(n);
  }

  int bpos = buf.length;
  do {
    //if (bpos == 0) assert(0, "internal printer error");
    immutable ubyte b = n&0x0f;
    n >>= 4;
    if (b < 10) buf.ptr[--bpos] = cast(char)('0'+b); else buf.ptr[--bpos] = cast(char)((upcase ? 'A' : 'a')+(b-10));
  } while (n != 0);
  if (neg) {
    //if (bpos == 0) assert(0, "internal printer error");
    buf.ptr[--bpos] = '-';
  }
  cwrxputstr!true(buf[bpos..$], signw, lchar, rchar, wdt, maxwdt);
}


private void cwrxputfloat(TT) (TT nn, bool simple, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  import core.stdc.stdlib : malloc, realloc;

  static if (is(TT == shared)) {
    import core.atomic;
    alias T = XUQQ!TT;
    T n = atomicLoad(nn);
  } else {
    alias T = XUQQ!TT;
    T n = nn;
  }

  static char* buf;
  static usize buflen = 0;
  char[256] fmtstr;
  int fspos = 0;

  if (buf is null) {
    buflen = 256;
    buf = cast(char*)malloc(buflen);
    if (buf is null) assert(0, "out of memory");
  }

  void putNum (int n) {
    if (n == n.min) assert(0, "oops");
    if (n < 0) { fmtstr.ptr[fspos++] = '-'; n = -(n); }
    char[24] buf = void;
    int bpos = buf.length;
    do {
      buf.ptr[--bpos] = cast(char)('0'+n%10);
      n /= 10;
    } while (n != 0);
    if (fmtstr.length-fspos < buf.length-bpos) assert(0, "internal printer error");
    fmtstr.ptr[fspos..fspos+(buf.length-bpos)] = buf[bpos..$];
    fspos += buf.length-bpos;
  }

  fmtstr.ptr[fspos++] = '%';
  if (!simple) {
    if (wdt) {
      if (signw == '-') fmtstr.ptr[fspos++] = '-';
      putNum(wdt);
    }
    if (maxwdt) {
      fmtstr.ptr[fspos++] = '.';
      putNum(maxwdt);
    }
    fmtstr.ptr[fspos++] = 'g';
    maxwdt = 0;
  } else {
    fmtstr.ptr[fspos++] = 'g';
  }
  fmtstr.ptr[fspos++] = '\x00';
  //{ import core.stdc.stdio; printf("<%s>", fmtstr.ptr); }

  for (;;) {
    import core.stdc.stdio : snprintf;
    auto plen = snprintf(buf, buflen, fmtstr.ptr, cast(double)n);
    if (plen >= buflen) {
      buflen = plen+2;
      buf = cast(char*)realloc(buf, buflen);
      if (buf is null) assert(0, "out of memory");
    } else {
      if (lchar != ' ') {
        foreach (ref ch; buf[0..plen]) {
          if (ch != ' ') break;
          ch = lchar;
        }
      }
      if (rchar != ' ') {
        foreach_reverse (ref ch; buf[0..plen]) {
          if (ch != ' ') break;
          ch = rchar;
        }
      }
      //{ import core.stdc.stdio; printf("<{%s}>", buf); }
      cwrxputstr!true(buf[0..plen], signw, lchar, rchar, wdt, maxwdt);
      return;
    }
  }
}


private void cwrxputenum(TT) (TT nn, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  static if (is(TT == shared)) {
    import core.atomic;
    alias T = XUQQ!TT;
    T n = atomicLoad(nn);
  } else {
    alias T = XUQQ!TT;
    T n = nn;
  }

  foreach (string mname; __traits(allMembers, T)) {
    if (n == __traits(getMember, T, mname)) {
      cwrxputstr!false(mname, signw, lchar, rchar, wdt, maxwdt);
      return;
    }
  }
  static if (__traits(isUnsigned, T)) {
    cwrxputint!long(cast(long)n, signw, lchar, rchar, wdt, maxwdt);
  } else {
    cwrxputint!ulong(cast(ulong)n, signw, lchar, rchar, wdt, maxwdt);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/** write formatted string to console with runtime format string
 * will try to not allocate if it is possible.
 *
 * understands [+|-]width[.maxlen]
 *   negative width: add spaces to right
 *   + signed width: center
 *   negative maxlen: get right part
 * specifiers:
 *   's': use to!string to write argument
 *        note that writer can print strings, bools, integrals and floats without allocation
 *   'x': write integer as hex
 *   'X': write integer as HEX
 *   '!': skip all arguments that's left, no width allowed
 *   '%': just a percent sign, no width allowed
 *   '|': print all arguments that's left with simple "%s", no width allowed
 *   '<...>': print all arguments that's left with simple "%s", delimited with "...", no width allowed
 * options (must immediately follow '%'): NOT YET
 *   '~': fill with the following char instead of space
 *        second '~': right filling char for 'center'
 */
public void conprintfX(bool donl, A...) (ConString fmt, in auto ref A args) {
  import core.stdc.stdio : snprintf;
  char[128] tmp = void;
  usize tlen;

  struct Writer {
    void put (const(char)[] s...) nothrow @trusted @nogc {
      foreach (char ch; s) {
        if (tlen >= tmp.length) { tlen = tmp.length+42; break; }
        tmp.ptr[tlen++] = ch;
      }
    }
  }

  static struct IntNum { char sign; int aval; bool leadingZero; /*|value|*/ }

  static char[] utf8Encode (char[] s, dchar c) pure nothrow @trusted @nogc {
    assert(s.length >= 4);
    if (c > 0x10FFFF) c = '\uFFFD';
    if (c <= 0x7F) {
      s.ptr[0] = cast(char)c;
      return s[0..1];
    } else {
      if (c <= 0x7FF) {
        s.ptr[0] = cast(char)(0xC0|(c>>6));
        s.ptr[1] = cast(char)(0x80|(c&0x3F));
        return s[0..2];
      } else if (c <= 0xFFFF) {
        s.ptr[0] = cast(char)(0xE0|(c>>12));
        s.ptr[1] = cast(char)(0x80|((c>>6)&0x3F));
        s.ptr[2] = cast(char)(0x80|(c&0x3F));
        return s[0..3];
      } else if (c <= 0x10FFFF) {
        s.ptr[0] = cast(char)(0xF0|(c>>18));
        s.ptr[1] = cast(char)(0x80|((c>>12)&0x3F));
        s.ptr[2] = cast(char)(0x80|((c>>6)&0x3F));
        s.ptr[3] = cast(char)(0x80|(c&0x3F));
        return s[0..4];
      } else {
        s[0..3] = "<?>";
        return s[0..3];
      }
    }
  }

  void parseInt(bool allowsign) (ref IntNum n) nothrow @trusted @nogc {
    n.sign = ' ';
    n.aval = 0;
    n.leadingZero = false;
    if (fmt.length == 0) return;
    static if (allowsign) {
      if (fmt.ptr[0] == '-' || fmt.ptr[0] == '+') {
        n.sign = fmt.ptr[0];
        fmt = fmt[1..$];
        if (fmt.length == 0) return;
      }
    }
    if (fmt.ptr[0] < '0' || fmt.ptr[0] > '9') return;
    n.leadingZero = (fmt.ptr[0] == '0');
    while (fmt.length && fmt.ptr[0] >= '0' && fmt.ptr[0] <= '9') {
      n.aval = n.aval*10+(fmt.ptr[0]-'0'); // ignore overflow here
      fmt = fmt[1..$];
    }
  }

  void skipLitPart () nothrow @trusted @nogc {
    while (fmt.length > 0) {
      import core.stdc.string : memchr;
      auto prcptr = cast(const(char)*)memchr(fmt.ptr, '%', fmt.length);
      if (prcptr is null) prcptr = fmt.ptr+fmt.length;
      // print (and remove) literal part
      if (prcptr !is fmt.ptr) {
        auto lplen = cast(usize)(prcptr-fmt.ptr);
        cwrxputch(fmt[0..lplen]);
        fmt = fmt[lplen..$];
      }
      if (fmt.length >= 2 && fmt.ptr[0] == '%' && fmt.ptr[1] == '%') {
        cwrxputch("%");
        fmt = fmt[2..$];
        continue;
      }
      break;
    }
  }

  if (fmt.length == 0) return;
  consoleLock();
  scope(exit) consoleUnlock();
  auto fmtanchor = fmt;
  IntNum wdt, maxlen;
  char mode = ' ';

  ConString smpDelim = null;
  ConString fmtleft = null;

  argloop: foreach (immutable argnum, /*auto*/ att; A) {
    alias at = XUQQ!att;
    // skip literal part of the format string
    skipLitPart();
    // something's left in the format string?
    if (fmt.length > 0) {
      // here we should have at least two chars
      assert(fmt[0] == '%');
      if (fmt.length == 1) { cwrxputch("<stray-percent-in-conprintf>"); break argloop; }
      fmt = fmt[1..$];
      parseInt!true(wdt);
      if (fmt.length && fmt[0] == '.') {
        fmt = fmt[1..$];
        parseInt!false(maxlen);
      } else {
        maxlen.sign = ' ';
        maxlen.aval = 0;
        maxlen.leadingZero = false;
      }
      if (fmt.length == 0) { cwrxputch("<stray-percent-in-conprintf>"); break argloop; }
      mode = fmt[0];
      fmt = fmt[1..$];
      switch (mode) {
        case '!': break argloop; // no more
        case '|': // rock 'till the end
          wdt.sign = maxlen.sign = ' ';
          wdt.aval = maxlen.aval = 0;
          wdt.leadingZero = maxlen.leadingZero = false;
          if (fmt !is null) fmtleft = fmt;
          fmt = null;
          break;
        case '<': // <...>: print all arguments that's left with simple "%s", delimited with "...", no width allowed
          wdt.sign = maxlen.sign = ' ';
          wdt.aval = maxlen.aval = 0;
          wdt.leadingZero = maxlen.leadingZero = false;
          usize epos = 0;
          while (epos < fmt.length && fmt[epos] != '>') ++epos;
          smpDelim = fmt[0..epos];
          if (epos < fmt.length) ++epos;
          fmtleft = fmt[epos..$];
          fmt = null;
          break;
        case 's': // process as simple string
          break;
        case 'd': case 'D': // decimal, process as simple string
        case 'u': case 'U': // unsigned decimal, process as simple string
          static if (is(at == bool)) {
            cwrxputint((args[argnum] ? 1 : 0), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            continue argloop;
          } else static if (is(at == char) || is(at == wchar) || is(at == dchar)) {
            cwrxputint(cast(uint)(args[argnum] ? 1 : 0), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            continue argloop;
          } else static if (is(at == enum)) {
            static if (at.min >= int.min && at.max <= int.max) {
              cwrxputint(cast(int)args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            } else static if (at.min >= 0 && at.max <= uint.max) {
              cwrxputint(cast(uint)args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            } else static if (at.min >= long.min && at.max <= long.max) {
              cwrxputint(cast(long)args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            } else {
              cwrxputint(cast(ulong)args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            }
            continue argloop;
          } else {
            break;
          }
        case 'c': case 'C': // char
          static if (is(at == bool)) {
            cwrxputstr!false((args[argnum] ? "t" : "f"), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == wchar) || is(at == dchar)) {
            cwrxputstr!false(utf8Encode(tmp[], cast(dchar)args[argnum]), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == byte) || is(at == short) || is(at == int) || is(at == long) ||
                            is(at == ubyte) || is(at == ushort) || is(at == uint) || is(at == ulong) ||
                            is(at == char))
          {
            tmp[0] = cast(char)args[argnum]; // nobody cares about unifuck
            cwrxputstr!false(tmp[0..1], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else {
            cwrxputch("<cannot-charprint-");
            cwrxputch(at.stringof);
            cwrxputch("in-conprintf>");
          }
          continue argloop;
        case 'x': case 'X': // hex
          static if (is(at == bool)) {
            cwrxputint((args[argnum] ? 1 : 0), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == byte) || is(at == short) || is(at == int) || is(at == long) ||
                            is(at == ubyte) || is(at == ushort) || is(at == uint) || is(at == ulong))
          {
            //cwrxputint(args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            cwrxputhex(args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == char) || is(at == wchar) || is(at == dchar)) {
            cwrxputhex(cast(uint)args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == enum)) {
            static if (at.min >= int.min && at.max <= int.max) {
              cwrxputhex(cast(int)args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            } else static if (at.min >= 0 && at.max <= uint.max) {
              cwrxputhex(cast(uint)args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            } else static if (at.min >= long.min && at.max <= long.max) {
              cwrxputhex(cast(long)args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            } else {
              cwrxputhex(cast(ulong)args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
            }
          } else static if (is(at : T*, T)) {
            // pointers
            cwrxputhex(cast(usize)args[argnum], (mode == 'X'), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else {
            cwrxputch("<cannot-hexprint-");
            cwrxputch(at.stringof);
            cwrxputch("in-conprintf>");
          }
          continue argloop;
        case 'f':
          static if (is(at == bool)) {
            cwrxputfloat((args[argnum] ? 1.0f : 0.0f), false, wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == byte) || is(at == short) || is(at == int) || is(at == long) ||
                            is(at == ubyte) || is(at == ushort) || is(at == uint) || is(at == ulong) ||
                            is(at == char) || is(at == wchar) || is(at == dchar))
          {
            cwrxputfloat(cast(double)args[argnum], false, wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else static if (is(at == float) || is(at == double)) {
            cwrxputfloat(args[argnum], false, wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
          } else {
            cwrxputch("<cannot-floatprint-");
            cwrxputch(at.stringof);
            cwrxputch("in-conprintf>");
          }
          continue argloop;
        default:
          cwrxputch("<invalid-format-in-conprintf(%");
          if (mode < 32 || mode == 127) {
            tlen = snprintf(tmp.ptr, tmp.length, "\\x%02x", cast(uint)mode);
            cwrxputch(tmp[0..tlen]);
          } else {
            cwrxputch(mode);
          }
          cwrxputch(")>");
          break argloop;
      }
    } else {
      if (smpDelim.length) cwrxputch(smpDelim);
      wdt.sign = maxlen.sign = ' ';
      wdt.aval = maxlen.aval = 0;
      wdt.leadingZero = maxlen.leadingZero = false;
    }
    // print as string
    static if (is(at == bool)) {
      cwrxputstr!false((args[argnum] ? "true" : "false"), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else static if (is(at == wchar) || is(at == dchar)) {
      cwrxputstr!false(utf8Encode(tmp[], cast(dchar)args[argnum]), wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else static if (is(at == byte) || is(at == short) || is(at == int) || is(at == long) ||
                      is(at == ubyte) || is(at == ushort) || is(at == uint) || is(at == ulong))
    {
      cwrxputint(args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else static if (is(at == char)) {
      tmp[0] = cast(char)args[argnum]; // nobody cares about unifuck
      cwrxputstr!false(tmp[0..1], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else static if (is(at == float) || is(at == double)) {
      cwrxputfloat(args[argnum], false, wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else static if (is(at == enum)) {
      cwrxputenum(args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else static if (is(at : T*, T)) {
      // pointers
      static if (is(XUQQ!T == char)) {
        // special case: `char*` will be printed as 0-terminated string
        cwrxputstrz(args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
      } else {
        // other pointers will be printed as "0x..."
        if (wdt.aval == 0) { wdt.aval = 8/*cast(int)usize.sizeof*2*/; wdt.leadingZero = true; }
        cwrxputhex(cast(usize)args[argnum], true, wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
      }
    } else static if (is(at : const(char)[])) {
      // strings
      cwrxputstr!false(args[argnum], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
    } else {
      // alas
      try {
        import std.format : formatValue, singleSpec;
        tlen = 0;
        scope Writer wrt;
        scope spec = singleSpec("%s");
        formatValue(wrt, args[argnum], spec);
        if (tlen > tmp.length) {
          cwrxputch("<error-formatting-in-conprintf>");
        } else {
          cwrxputstr!false(tmp[0..tlen], wdt.sign, (wdt.leadingZero ? '0' : ' '), (maxlen.leadingZero ? '0' : ' '), wdt.aval, maxlen.aval);
        }
      } catch (Exception e) {
        cwrxputch("<error-formatting-in-conprintf>");
      }
    }
  }

  if (fmt is null) {
    if (fmtleft.length) cwrxputch(fmtleft);
  }

  if (fmt.length) {
    skipLitPart();
    if (fmt.length) {
      assert(fmt[0] == '%');
      if (fmt.length == 1) {
        cwrxputch("<stray-percent-in-conprintf>");
      } else {
        fmt = fmt[1..$];
        parseInt!true(wdt);
        if (fmt.length && fmt[0] == '.') {
          fmt = fmt[1..$];
          parseInt!false(maxlen);
        }
        if (fmt.length == 0) {
          cwrxputch("<stray-percent-in-conprintf>");
        } else {
          mode = fmt[0];
          fmt = fmt[1..$];
          if (mode == '!' || mode == '|') {
            if (fmt.length) cwrxputch(fmt);
          } else if (mode == '<') {
            while (fmt.length && fmt[0] != '>') fmt = fmt[1..$];
            if (fmt.length) fmt = fmt[1..$];
            if (fmt.length) cwrxputch(fmt);
          } else {
            cwrxputch("<orphan-format-in-conprintf(%");
            if (mode < 32 || mode == 127) {
              tlen = snprintf(tmp.ptr, tmp.length, "\\x%02x", cast(uint)mode);
              cwrxputch(tmp[0..tlen]);
            } else {
              cwrxputch(mode);
            }
            cwrxputch(")>");
          }
        }
      }
    }
  }

  static if (donl) cwrxputch("\n");
}

public void conprintf(A...) (ConString fmt, in auto ref A args) { conprintfX!false(fmt, args); }
public void conprintfln(A...) (ConString fmt, in auto ref A args) { conprintfX!true(fmt, args); }


// ////////////////////////////////////////////////////////////////////////// //
version(iv_cmdcon_honest_ctfe_writer)
/// write formatted string to console with compile-time format string
public template conwritef(string fmt, A...) {
  private string gen() () {
    usize pos;
    char[] res;
    usize respos;
    //string simpledelim;
    char[] simpledelim;
    uint simpledelimpos;

    res.length = fmt.length+128;

    void putRes (const(char)[] s...) {
      //if (respos+s.length > res.length) res.length = respos+s.length+256;
      foreach (char ch; s) {
        if (respos >= res.length) res.length = res.length*2;
        res[respos++] = ch;
      }
    }

    void putSD (const(char)[] s...) {
      if (simpledelim.length == 0) simpledelim.length = 128;
      foreach (char ch; s) {
        if (simpledelimpos >= simpledelim.length) simpledelim.length = simpledelim.length*2;
        simpledelim[simpledelimpos++] = ch;
      }
    }

    void putNum(bool hex=false) (int n, int minlen=-1) {
      if (n == n.min) assert(0, "oops");
      if (n < 0) { putRes('-'); n = -(n); }
      char[24] buf;
      int bpos = buf.length;
      do {
        static if (hex) {
          buf[--bpos] = "0123456789abcdef"[n&0x0f];
          n /= 16;
        } else {
          buf[--bpos] = cast(char)('0'+n%10);
          n /= 10;
        }
        --minlen;
      } while (n != 0 || minlen > 0);
      putRes(buf[bpos..$]);
    }

    int parseNum (ref char sign, ref bool leadzero) {
      sign = ' ';
      leadzero = false;
      if (pos >= fmt.length) return 0;
      if (fmt[pos] == '-' || fmt[pos] == '+') sign = fmt[pos++];
      if (pos >= fmt.length) return 0;
      int res = 0;
      if (pos < fmt.length && fmt[pos] == '0') leadzero = true;
      while (pos < fmt.length && fmt[pos] >= '0' && fmt[pos] <= '9') res = res*10+fmt[pos++]-'0';
      return res;
    }

    void processUntilFSp () {
      while (pos < fmt.length) {
        usize epos = pos;
        while (epos < fmt.length && fmt[epos] != '%') {
          if (fmt[epos] < ' ' && fmt[epos] != '\t' && fmt[epos] != '\n') break;
          if (fmt[epos] >= 127 || fmt[epos] == '`') break;
          ++epos;
        }
        if (epos > pos) {
          putRes("cwrxputch(`");
          putRes(fmt[pos..epos]);
          putRes("`);\n");
          pos = epos;
          if (pos >= fmt.length) break;
        }
        if (fmt[pos] != '%') {
          putRes("cwrxputch('\\x");
          putNum!true(cast(ubyte)fmt[pos], 2);
          putRes("');\n");
          ++pos;
          continue;
        }
        if (fmt.length-pos < 2 || fmt[pos+1] == '%') { putRes("cwrxputch('%');\n"); pos += 2; continue; }
        return;
      }
    }

    bool simples = false;
    bool putsimpledelim = false;
    char lchar=' ', rchar=' ';
    char signw = ' ';
    bool leadzerow = false;
    int wdt, maxwdt;
    char fmtch;

    argloop: foreach (immutable argnum, /*auto*/ att; A) {
      alias at = XUQQ!att;
      if (!simples) {
        processUntilFSp();
        if (pos >= fmt.length) assert(0, "out of format specifiers for arguments");
        assert(fmt[pos] == '%');
        ++pos;
        if (pos < fmt.length && fmt[pos] == '!') { ++pos; break; } // skip rest
        if (pos < fmt.length && fmt[pos] == '|') {
          ++pos;
          simples = true;
        } else if (pos < fmt.length && fmt[pos] == '<') {
          ++pos;
          simples = true;
          auto ep = pos;
          while (ep < fmt.length) {
            if (fmt[ep] == '>') break;
            if (fmt[ep] == '\\') ++ep;
            ++ep;
          }
          if (ep >= fmt.length) assert(0, "invalid format string");
          simpledelimpos = 0;
          if (ep-pos > 0) {
            bool hasQuote = false;
            foreach (char ch; fmt[pos..ep]) if (ch == '\\' || (ch < ' ' && ch != '\n' && ch != '\t') || ch >= 127 || ch == '`') { hasQuote = true; break; }
            if (!hasQuote) {
              putSD("cwrxputch(`");
              putSD(fmt[pos..ep]);
              putSD("`);\n");
            } else {
              //FIXME: get rid of char-by-char processing!
              putSD("cwrxputch(\"");
              while (pos < ep) {
                char ch = fmt[pos++];
                if (ch == '\\') ch = fmt[pos++];
                if (ch == '\\' || ch < ' ' || ch >= 127 || ch == '"') {
                  putSD("\\x");
                  putSD("0123456789abcdef"[ch>>4]);
                  putSD("0123456789abcdef"[ch&0x0f]);
                } else {
                  putSD(ch);
                }
              }
              putSD("\");\n");
            }
          }
          pos = ep+1;
        } else {
          lchar = rchar = ' ';
          bool lrset = false;
          if (pos < fmt.length && fmt[pos] == '~') {
            lrset = true;
            if (fmt.length-pos < 2) assert(0, "invalid format string");
            lchar = fmt[pos+1];
            pos += 2;
            if (pos < fmt.length && fmt[pos] == '~') {
              if (fmt.length-pos < 2) assert(0, "invalid format string");
              rchar = fmt[pos+1];
              pos += 2;
            }
          }
          wdt = parseNum(signw, leadzerow);
          if (pos >= fmt.length) assert(0, "invalid format string");
          if (!lrset && leadzerow) lchar = '0';
          if (fmt[pos] == '.') {
            char mws;
            bool lzw;
            ++pos;
            maxwdt = parseNum(mws, lzw);
            if (mws == '-') maxwdt = -maxwdt;
          } else {
            maxwdt = 0;
          }
          if (pos >= fmt.length) assert(0, "invalid format string");
          fmtch = fmt[pos++];
        }
      }
      if (simples) {
        lchar = rchar = signw = ' ';
        leadzerow = false;
        wdt =  maxwdt = 0;
        fmtch = 's';
        if (putsimpledelim && simpledelimpos > 0) {
          putRes(simpledelim[0..simpledelimpos]);
        } else {
          putsimpledelim = true;
        }
      }
      switch (fmtch) {
        case 's':
        case 'd': // oops
        case 'u': // oops
          static if (is(at == char)) {
            putRes("cwrxputchar(args[");
            putNum(argnum);
            putRes("]");
          } else static if (is(at == wchar) || is(at == dchar)) {
            putRes("import std.conv : to; cwrxputstr(to!string(args[");
            putNum(argnum);
            putRes("])");
          } else static if (is(at == bool)) {
            putRes("cwrxputstr((args[");
            putNum(argnum);
            putRes("] ? `true` : `false`)");
          } else static if (is(at == enum)) {
            putRes("cwrxputenum(args[");
            putNum(argnum);
            putRes("]");
          } else static if (is(at == float) || is(at == double) || is(at == real)) {
            putRes("cwrxputfloat(args[");
            putNum(argnum);
            putRes("], true");
          } else static if (is(at : const(char)[])) {
            putRes("cwrxputstr(args[");
            putNum(argnum);
            putRes("]");
          } else static if (is(at : T*, T)) {
            //putRes("cwrxputch(`0x`); ");
            static if (is(T == char)) {
              putRes("cwrxputstrz(args[");
              putNum(argnum);
              putRes("]");
            } else {
              if (wdt < (void*).sizeof*2) { lchar = '0'; wdt = cast(int)((void*).sizeof)*2; signw = ' '; }
              putRes("cwrxputhex(cast(usize)args[");
              putNum(argnum);
              putRes("], false");
            }
          } else static if (is(at : long)) {
            putRes("cwrxputint(args[");
            putNum(argnum);
            putRes("]");
          } else {
            putRes("import std.conv : to; cwrxputstr(to!string(args[");
            putNum(argnum);
            putRes("])");
          }
          break;
        case 'x':
          static if (is(at == char) || is(at == wchar) || is(at == dchar)) {
            putRes("cwrxputhex(cast(uint)args[");
            putNum(argnum);
            putRes("], false");
          } else static if (is(at == bool)) {
            putRes("cwrxputstr((args[");
            putNum(argnum);
            putRes("] ? `1` : `0`)");
          } else static if (is(at == float) || is(at == double) || is(at == real)) {
            assert(0, "can't hexprint floats yet");
          } else static if (is(at : T*, T)) {
            if (wdt < (void*).sizeof*2) { lchar = '0'; wdt = cast(int)((void*).sizeof)*2; signw = ' '; }
            putRes("cwrxputhex(cast(usize)args[");
            putNum(argnum);
            putRes("], false");
          } else static if (is(at : long)) {
            putRes("cwrxputhex(args[");
            putNum(argnum);
            putRes("], false");
          } else {
            assert(0, "can't print '"~at.stringof~"' as hex");
          }
          break;
        case 'X':
          static if (is(at == char) || is(at == wchar) || is(at == dchar)) {
            putRes("cwrxputhex(cast(uint)args[");
            putNum(argnum);
            putRes("], true");
          } else static if (is(at == bool)) {
            putRes("cwrxputstr((args[");
            putNum(argnum);
            putRes("] ? `1` : `0`)");
          } else static if (is(at == float) || is(at == double) || is(at == real)) {
            assert(0, "can't hexprint floats yet");
          } else static if (is(at : T*, T)) {
            if (wdt < (void*).sizeof*2) { lchar = '0'; wdt = cast(int)((void*).sizeof)*2; signw = ' '; }
            putRes("cwrxputhex(cast(usize)args[");
            putNum(argnum);
            putRes("], true");
          } else static if (is(at : long)) {
            putRes("cwrxputhex(args[");
            putNum(argnum);
            putRes("], true");
          } else {
            assert(0, "can't print '"~at.stringof~"' as hex");
          }
          break;
        case 'f':
          static if (is(at == float) || is(at == double) || is(at == real)) {
            putRes("cwrxputfloat(args[");
            putNum(argnum);
            putRes("], false");
          } else {
            assert(0, "can't print '"~at.stringof~"' as float");
          }
          break;
        default: assert(0, "invalid format specifier: '"~fmtch~"'");
      }
      putRes(", '");
      putRes(signw);
      putRes("', '\\x");
      putNum!true(cast(uint)lchar, 2);
      putRes("', '\\x");
      putNum!true(cast(uint)rchar, 2);
      putRes("', ");
      putNum(wdt);
      putRes(", ");
      putNum(maxwdt);
      putRes(");\n");
    }
    while (pos < fmt.length) {
      processUntilFSp();
      if (pos >= fmt.length) break;
      assert(fmt[pos] == '%');
      ++pos;
      if (pos < fmt.length && (fmt[pos] == '!' || fmt[pos] == '|')) { ++pos; continue; } // skip rest
      if (pos < fmt.length && fmt[pos] == '<') {
        // skip it
        while (pos < fmt.length) {
          if (fmt[pos] == '>') break;
          if (fmt[pos] == '\\') ++pos;
          ++pos;
        }
        ++pos;
        continue;
      }
      assert(0, "too many format specifiers");
    }
    return res[0..respos];
  }
  void conwritef (A args) {
    //enum code = gen();
    //pragma(msg, code);
    //pragma(msg, "===========");
    consoleLock();
    scope(exit) consoleUnlock();
    mixin(gen());
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public:

//void conwritef(string fmt, A...) (A args) { fdwritef!(fmt)(args); }
version(iv_cmdcon_honest_ctfe_writer) {
  void conwritefln(string fmt, A...) (A args) { conwritef!(fmt)(args); cwrxputch('\n'); } /// write formatted string to console with compile-time format string
  void conwrite(A...) (A args) { conwritef!("%|")(args); } /// write formatted string to console with compile-time format string
  void conwriteln(A...) (A args) { conwritef!("%|\n")(args); } /// write formatted string to console with compile-time format string
} else {
  public void conwritef(string fmt, A...) (in auto ref A args) { conprintfX!false(fmt, args); } /// unhonest CTFE writer
  void conwritefln(string fmt, A...) (in auto ref A args) { conprintfX!true(fmt, args); } /// write formatted string to console with compile-time format string
  void conwrite(A...) (in auto ref A args) { conprintfX!false("%|", args); } /// write formatted string to console with compile-time format string
  void conwriteln(A...) (in auto ref A args) { conprintfX!false("%|\n", args); } /// write formatted string to console with compile-time format string
}


// ////////////////////////////////////////////////////////////////////////// //
version(conwriter_test)
unittest {
  class A {
    override string toString () const { return "{A}"; }
  }

  char[] n = ['x', 'y', 'z'];
  char[3] t = "def";//['d', 'e', 'f'];
  conwriter("========================\n");
  conwritef!"`%%`\n"();
  conwritef!"`%-3s`\n"(42);
  conwritef!"<`%3s`%%{str=%s}%|>\n"(cast(int)42, "[a]", new A(), n, t[]);
  //conwritefln!"<`%3@%3s`>%!"(cast(int)42, "[a]", new A(), n, t);
  //errwriteln("stderr");
  conwritefln!"`%-3s`"(42);
  //conwritefln!"`%!z%-2@%-3s`%!"(69, 42, 666);
  //conwritefln!"`%!%1@%-3s%!`"(69, 42, 666);
  //conwritefln!"`%!%-1@%+0@%-3s%!`"(69, 42, 666);
  conwritefln!"`%3.5s`"("a");
  conwritefln!"`%7.5s`"("abcdefgh");
  conwritef!"%|\n"(42, 666);
  conwritefln!"`%+10.5s`"("abcdefgh");
  conwritefln!"`%+10.-5s`"("abcdefgh");
  conwritefln!"`%~++10.-5s`"("abcdefgh");
  conwritefln!"`%~+~:+10.-5s`"("abcdefgh");
  //conwritef!"%\0<>\0|\n"(42, 666, 999);
  //conwritef!"%\0\t\0|\n"(42, 666, 999);
  conwritefln!"`%~*05s %~.5s`"(42, 666);
  conwritef!"`%s`\n"(t);
  conwritef!"`%08s`\n"("alice");
  conwritefln!"#%08x"(16396);
  conwritefln!"#%08X"(-16396);
  conwritefln!"#%02X"(-16385);
  conwritefln!"[%06s]"(-666);
  conwritefln!"[%06s]"(cast(long)0x8000_0000_0000_0000uL);
  conwritefln!"[%06x]"(cast(long)0x8000_0000_0000_0000uL);

  void wrflt () nothrow @nogc {
    conwriteln(42.666f);
    conwriteln(cast(double)42.666);
  }
  wrflt();

  //immutable char *strz = "stringz\0s";
  //conwritefln!"[%S]"(strz);
}


// ////////////////////////////////////////////////////////////////////////// //
/// dump variables. use like this: `mixin condump!("x", "y")` ==> "x = 5, y = 3"
mixin template condump (Names...) {
  auto _xdump_tmp_ = {
    import iv.cmdcon : conwrite;
    foreach (/*auto*/ i, /*auto*/ name; Names) conwrite(name, " = ", mixin(name), (i < Names.length-1 ? ", " : "\n"));
    return false;
  }();
}

///
version(conwriter_test_dump)
unittest {
  int x = 5;
  int y = 3;
  int z = 15;

  mixin condump!("x", "y");  // x = 5, y = 3
  mixin condump!("z");       // z = 15
  mixin condump!("x+y");     // x+y = 8
  mixin condump!("x+y < z"); // x+y < z = true

  conbufDump();
}


// ////////////////////////////////////////////////////////////////////////// //
// command console

/// base console command class
public class ConCommand {
private:
  public import std.conv : ConvException, ConvOverflowException;
  import std.range;
  // this is hack to avoid allocating error exceptions
  // don't do that at home!

  __gshared ConvException exBadNum;
  __gshared ConvException exBadStr;
  __gshared ConvException exBadBool;
  __gshared ConvException exBadInt;
  __gshared ConvException exBadEnum;
  __gshared ConvOverflowException exIntOverflow;
  __gshared ConvException exBadHexEsc;
  __gshared ConvException exBadEscChar;
  __gshared ConvException exNoArg;
  __gshared ConvException exTooManyArgs;
  __gshared ConvException exBadArgType;

  shared static this () {
    exBadNum = new ConvException("invalid number");
    exBadStr = new ConvException("invalid string");
    exBadBool = new ConvException("invalid boolean");
    exBadInt = new ConvException("invalid integer number");
    exBadEnum = new ConvException("invalid enumeration value");
    exIntOverflow = new ConvOverflowException("overflow in integral conversion");
    exBadHexEsc = new ConvException("invalid hex escape");
    exBadEscChar = new ConvException("invalid escape char");
    exNoArg = new ConvException("argument expected");
    exTooManyArgs = new ConvException("too many arguments");
    exBadArgType = new ConvException("can't parse given argument type (internal error)");
  }

public:
  alias ArgCompleteCB = void delegate (ConCommand self); /// prototype for argument completion callback

private:
  __gshared usize wordBufMem; // buffer for `getWord()`
  __gshared uint wordBufUsed, wordBufSize;
  ArgCompleteCB argcomplete; // this delegate will be called to do argument autocompletion

  static void wbReset () nothrow @trusted @nogc { pragma(inline, true); wordBufUsed = 0; }

  static void wbPut (const(char)[] s...) nothrow @trusted @nogc {
    if (s.length == 0) return;
    if (s.length > int.max/4) assert(0, "oops: console command too long");
    if (wordBufUsed+cast(uint)s.length > int.max/4) assert(0, "oops: console command too long");
    // grow wordbuf, if necessary
    if (wordBufUsed+cast(uint)s.length > wordBufSize) {
      import core.stdc.stdlib : realloc;
      wordBufSize = ((wordBufUsed+cast(uint)s.length)|0x3fff)+1;
      auto newmem = cast(usize)realloc(cast(void*)wordBufMem, wordBufSize);
      if (newmem == 0) assert(0, "cmdcon: out of memory");
      wordBufMem = cast(usize)newmem;
    }
    assert(wordBufUsed+cast(uint)s.length <= wordBufSize);
    (cast(char*)(wordBufMem+wordBufUsed))[0..s.length] = s;
    wordBufUsed += cast(uint)s.length;
  }

  static @property const(char)[] wordBuf () nothrow @trusted @nogc { pragma(inline, true); return (cast(char*)wordBufMem)[0..wordBufUsed]; }

public:
  string name; ///
  string help; ///

  this (string aname, string ahelp=null) { name = aname; help = ahelp; } ///

  void showHelp () { conwriteln(name, " -- ", help); } ///

  /// can throw, yep
  /// cmdline doesn't contain command name
  void exec (ConString cmdline) {
    auto w = getWord(cmdline);
    if (w == "?") showHelp;
  }

public:
static:
  /// parse ch as digit in given base. return -1 if ch is not a valid digit.
  int digit(TC) (TC ch, uint base) pure nothrow @safe @nogc if (isSomeChar!TC) {
    int res = void;
         if (ch >= '0' && ch <= '9') res = ch-'0';
    else if (ch >= 'A' && ch <= 'Z') res = ch-'A'+10;
    else if (ch >= 'a' && ch <= 'z') res = ch-'a'+10;
    else return -1;
    return (res >= base ? -1 : res);
  }

  /** get word from string.
   *
   * it will correctly parse quoted strings.
   *
   * note that next call to `getWord()` can destroy result.
   * returns `null` if there are no more words.
   * `*strtemp` will be `true` if temporary string storage was used.
   */
  ConString getWord (ref ConString s, bool *strtemp=null) {
    wbReset();
    if (strtemp !is null) *strtemp = false;
    usize pos;
    while (s.length > 0 && s.ptr[0] <= ' ') s = s[1..$];
    if (s.length == 0) return null;
    // quoted string?
    if (s.ptr[0] == '"' || s.ptr[0] == '\'') {
      char qch = s.ptr[0];
      s = s[1..$];
      pos = 0;
      bool hasSpecial = false;
      while (pos < s.length && s.ptr[pos] != qch) {
        if (s.ptr[pos] == '\\') { hasSpecial = true; break; }
        ++pos;
      }
      // simple quoted string?
      if (!hasSpecial) {
        auto res = s[0..pos];
        if (pos < s.length) ++pos; // skip closing quote
        s = s[pos..$];
        return res;
      }
      if (strtemp !is null) *strtemp = true;
      //wordBuf.assumeSafeAppend.length = pos;
      //if (pos) wordBuf[0..pos] = s[0..pos];
      if (pos) wbPut(s[0..pos]);
      // process special chars
      while (pos < s.length && s.ptr[pos] != qch) {
        if (s.ptr[pos] == '\\' && s.length-pos > 1) {
          ++pos;
          switch (s.ptr[pos++]) {
            case '"': case '\'': case '\\': wbPut(s.ptr[pos-1]); break;
            case '0': wbPut('\x00'); break;
            case 'a': wbPut('\a'); break;
            case 'b': wbPut('\b'); break;
            case 'e': wbPut('\x1b'); break;
            case 'f': wbPut('\f'); break;
            case 'n': wbPut('\n'); break;
            case 'r': wbPut('\r'); break;
            case 't': wbPut('\t'); break;
            case 'v': wbPut('\v'); break;
            case 'x': case 'X':
              int n = 0;
              foreach (immutable _; 0..2) {
                if (pos >= s.length) throw exBadHexEsc;
                char c2 = s.ptr[pos++];
                if (digit(c2, 16) < 0) throw exBadHexEsc;
                n = n*16+digit(c2, 16);
              }
              wbPut(cast(char)n);
              break;
            default: throw exBadEscChar;
          }
          continue;
        }
        wbPut(s.ptr[pos++]);
      }
      if (pos < s.length) ++pos; // skip closing quote
      s = s[pos..$];
      return wordBuf;
    } else {
      // normal word
      pos = 0;
      while (pos < s.length && s.ptr[pos] > ' ') ++pos;
      auto res = s[0..pos];
      s = s[pos..$];
      return res;
    }
  }

  /// parse value of type T.
  T parseType(T) (ref ConString s) {
    import std.utf : byCodeUnit;
    alias UT = XUQQ!T;
    static if (is(UT == enum)) {
      // enum
      auto w = getWord(s);
      // case-sensitive
      foreach (string mname; __traits(allMembers, UT)) {
        if (mname == w) return __traits(getMember, UT, mname);
      }
      // case-insensitive
      foreach (string mname; __traits(allMembers, UT)) {
        if (strEquCI(mname, w)) return __traits(getMember, UT, mname);
      }
      // integer
      if (w.length < 1) throw exBadEnum;
      auto ns = w;
      try {
        if (w[0] == '-') {
          long num = parseInt!long(ns);
          if (ns.length > 0) throw exBadEnum;
          foreach (string mname; __traits(allMembers, UT)) {
            if (__traits(getMember, UT, mname) == num) return __traits(getMember, UT, mname);
          }
        } else {
          ulong num = parseInt!ulong(ns);
          if (ns.length > 0) throw exBadEnum;
          foreach (string mname; __traits(allMembers, UT)) {
            if (__traits(getMember, UT, mname) == num) return __traits(getMember, UT, mname);
          }
        }
      } catch (Exception) {}
      throw exBadEnum;
    } else static if (is(UT == bool)) {
      // boolean
      auto w = getWord(s);
      if (w is null) throw exNoArg;
      bool good = false;
      auto res = parseBool(w, true, &good);
      if (!good) throw exBadBool;
      return res;
    } else static if ((isIntegral!UT || isFloatingPoint!UT) && !is(UT == enum)) {
      // number
      auto w = getWord(s);
      if (w is null) throw exNoArg;
      bool goodbool = false;
      auto bv = parseBool(w, false, &goodbool); // no numbers
      if (goodbool) {
        return cast(UT)(bv ? 1 : 0);
      } else {
        auto ss = w.byCodeUnit;
        auto res = parseNum!UT(ss);
        if (!ss.empty) throw exBadNum;
        return res;
      }
    } else static if (is(UT : ConString)) {
      // string
      bool stemp = false;
      auto w = getWord(s);
      if (w is null) throw exNoArg;
      if (s.length && s.ptr[0] > 32) throw exBadStr;
      if (stemp) {
        // temp storage was used
        static if (is(UT == string)) return w.idup; else return w.dup;
      } else {
        // no temp storage was used
        static if (is(UT == ConString)) return w;
        else static if (is(UT == string)) return w.idup;
        else return w.dup;
      }
    } else static if (is(UT : char)) {
      // char
      bool stemp = false;
      auto w = getWord(s);
      if (w is null || w.length != 1) throw exNoArg;
      if (s.length && s.ptr[0] > 32) throw exBadStr;
      return w.ptr[0];
    } else {
      throw exBadArgType;
    }
  }

  /// parse boolean value
  public static bool parseBool (ConString s, bool allowNumbers=true, bool* goodval=null) nothrow @trusted @nogc {
    char[5] tbuf;
    if (goodval !is null) *goodval = false;
    while (s.length > 0 && s[0] <= ' ') s = s[1..$];
    while (s.length > 0 && s[$-1] <= ' ') s = s[0..$-1];
    if (s.length > tbuf.length) return false;
    usize pos = 0;
    foreach (char ch; s) {
      if (ch >= 'A' && ch <= 'Z') ch += 32; // poor man's tolower
      tbuf.ptr[pos++] = ch;
    }
    switch (tbuf[0..pos]) {
      case "y": case "t":
      case "yes": case "tan":
      case "true": case "on":
        if (goodval !is null) *goodval = true;
        return true;
      case "1": case "-1": case "42":
        if (allowNumbers) {
          if (goodval !is null) *goodval = true;
          return true;
        }
        break;
      case "n": case "f":
      case "no": case "ona":
      case "false": case "off":
        if (goodval !is null) *goodval = true;
        return false;
      case "0":
        if (allowNumbers) {
          if (goodval !is null) *goodval = true;
          return false;
        }
        break;
      default: break;
    }
    return false;
  }

  /** parse integer number.
   *
   * parser checks for overflows and understands different bases (0x, 0b, 0o, 0d).
   * parser skips leading spaces. stops on first non-numeric char.
   *
   * Params:
   *  T = result type
   *  s = input range; will be modified
   *
   * Returns:
   *  parsed number
   *
   * Throws:
   *  ConvException or ConvOverflowException
   */
  public static T parseInt(T, TS) (ref TS s) if (isSomeChar!(ElementType!TS) && isIntegral!T && !is(T == enum)) {
    import std.traits : isSigned;
    uint base = 10;
    ulong num = 0;
    static if (isSigned!T) bool neg = false;
    // skip spaces
    while (!s.empty) {
      if (s.front > 32) break;
      s.popFront();
    }
    if (s.empty) throw exBadInt;
    // check for sign
    switch (s.front) {
      case '+': // it's ok
        s.popFront();
        break;
      case '-':
        static if (isSigned!T) {
          neg = true;
          s.popFront();
          break;
        } else {
          throw exBadInt;
        }
      default: // do nothing
    }
    if (s.empty) throw exBadInt;
    // check for various bases
    if (s.front == '0') {
      s.popFront();
      if (s.empty) return cast(T)0;
      auto ch = s.front;
      switch (/*auto ch = s.front*/ch) {
        case 'b': case 'B': base = 2; goto gotbase;
        case 'o': case 'O': base = 8; goto gotbase;
        case 'd': case 'D': base = 10; goto gotbase;
        case 'x': case 'X': base = 16;
       gotbase:
          s.popFront();
          goto checkfirstdigit;
        default:
          if (ch != '_' && digit(ch, base) < 0) throw exBadInt;
          break;
      }
    } else {
      // no base specification; we want at least one digit
     checkfirstdigit:
      if (s.empty || digit(s.front, base) < 0) throw exBadInt;
    }
    // parse number
    // we already know that the next char is valid
    bool needDigit = false;
    do {
      auto ch = s.front;
      int d = digit(ch, base);
      if (d < 0) {
        if (needDigit) throw exBadInt;
        if (ch != '_') break;
        needDigit = true;
      } else {
        // funny overflow checks
        auto onum = num;
        if ((num *= base) < onum) throw exIntOverflow;
        if ((num += d) < onum) throw exIntOverflow;
        needDigit = false;
      }
      s.popFront();
    } while (!s.empty);
    if (needDigit) throw exBadInt;
    // check underflow and overflow
    static if (isSigned!T) {
      long n = cast(long)num;
      if (neg) {
        // special case: negative 0x8000_0000_0000_0000uL is ok
        if (num > 0x8000_0000_0000_0000uL) throw exIntOverflow;
        if (num != 0x8000_0000_0000_0000uL) n = -(n);
      } else {
        if (num >= 0x8000_0000_0000_0000uL) throw exIntOverflow;
      }
      if (n < T.min || n > T.max) throw exIntOverflow;
      return cast(T)n;
    } else {
      if (num < T.min || num > T.max) throw exIntOverflow;
      return cast(T)num;
    }
  }

  /** parse number.
   *
   * parser checks for overflows and understands different integer bases (0x, 0b, 0o, 0d).
   * parser skips leading spaces. stops on first non-numeric char.
   *
   * Params:
   *  T = result type
   *  s = input range; will be modified
   *
   * Returns:
   *  parsed number
   *
   * Throws:
   *  ConvException or ConvOverflowException
   */
  public static T parseNum(T, TS) (ref TS s) if (isSomeChar!(ElementType!TS) && (isIntegral!T || isFloatingPoint!T) && !is(T == enum)) {
    static if (isIntegral!T) {
      return parseInt!T(s);
    } else {
      while (!s.empty) {
        if (s.front > 32) break;
        s.popFront();
      }
      import std.conv : stcparse = parse;
      return stcparse!T(s);
    }
  }

  public static bool checkHelp (scope ConString s) {
    usize pos = 0;
    while (pos < s.length && s.ptr[pos] <= 32) ++pos;
    if (pos == s.length || s.ptr[pos] != '?') return false;
    ++pos;
    while (pos < s.length && s.ptr[pos] <= 32) ++pos;
    return (pos >= s.length);
  }

  public static bool hasArgs (scope ConString s) {
    usize pos = 0;
    while (pos < s.length && s.ptr[pos] <= 32) ++pos;
    return (pos < s.length);
  }

  private static bool isBadStrChar() (char ch) {
    pragma(inline, true);
    return (ch < ' ' || ch == '\\' || ch == '"' || ch == '\'' || ch == '#' || ch == ';' || ch > 126);
  }

  public static void writeQuotedString(bool forceQuote=true) (scope ConString s) { quoteStringDG!forceQuote(s, delegate (scope ConString s) { conwriter(s); }); }

  public static void quoteStringDG(bool forceQuote=false) (scope ConString s, scope void delegate (scope ConString) dg) {
    if (dg is null) return;
    static immutable string hexd = "0123456789abcdef";
    static bool isBadStrChar() (char ch) {
      pragma(inline, true);
      return (ch < ' ' || ch == '\\' || ch == '"' || ch == '\'' || ch == '#' || ch == ';' || ch > 126);
    }
    // need to quote?
    if (s.length == 0) { dg(`""`); return; }
    static if (!forceQuote) {
      bool needQuote = false;
      foreach (char ch; s) if (ch == ' ' || isBadStrChar(ch)) { needQuote = true; break; }
      if (!needQuote) { dg(s); return; }
    }
    dg("\"");
    usize pos = 0;
    while (pos < s.length) {
      usize end = pos;
      while (end < s.length && !isBadStrChar(s.ptr[end])) ++end;
      if (end > pos) dg(s[pos..end]);
      pos = end;
      if (pos >= s.length) break;
      dg("\\");
      switch (s.ptr[pos++]) {
        case '"': case '\'': case '\\': dg(s.ptr[pos-1..pos]); break;
        case '\x00': dg("0"); break;
        case '\a': dg("a"); break;
        case '\b': dg("b"); break;
        case '\x1b': dg("e"); break;
        case '\f': dg("f"); break;
        case '\n': dg("n"); break;
        case '\r': dg("r"); break;
        case '\t': dg("t"); break;
        case '\v': dg("c"); break;
        default:
          ubyte c = cast(ubyte)(s.ptr[pos-1]);
          dg("x");
          dg(hexd[c>>4..(c>>4)+1]);
          dg(hexd[c&0x0f..(c&0x0f)+1]);
          break;
      }
    }
    dg("\"");
  }
}


version(contest_parser) unittest {
  auto cc = new ConCommand("!");
  string s = "this is 'a test' string \"you\tknow\" ";
  auto sc = cast(ConString)s;
  {
    auto w = cc.getWord(sc);
    assert(w == "this");
  }
  {
    auto w = cc.getWord(sc);
    assert(w == "is");
  }
  {
    auto w = cc.getWord(sc);
    assert(w == "a test");
  }
  {
    auto w = cc.getWord(sc);
    assert(w == "string");
  }
  {
    auto w = cc.getWord(sc);
    assert(w == "you\tknow");
  }
  {
    auto w = cc.getWord(sc);
    assert(w is null);
    assert(sc.length == 0);
  }

  import std.conv : ConvException, ConvOverflowException;
  import std.exception;
  import std.math : abs;

  void testnum(T) (string s, T res, int line=__LINE__) {
    import std.string : format;
    bool ok = false;
    try {
      import std.utf : byCodeUnit;
      auto ss = s.byCodeUnit;
      auto v = ConCommand.parseNum!T(ss);
      while (!ss.empty && ss.front <= 32) ss.popFront();
      if (!ss.empty) throw new ConvException("shit happens!");
      static assert(is(typeof(v) == T));
      static if (isIntegral!T) ok = (v == res); else ok = (abs(v-res) < T.epsilon);
    } catch (ConvException e) {
      assert(0, format("unexpected exception thrown, called from line %s", line));
    }
    if (!ok) assert(0, format("assertion failure, called from line %s", line));
  }

  void testbadnum(T) (string s, int line=__LINE__) {
    import std.string : format;
    try {
      import std.utf : byCodeUnit;
      auto ss = s.byCodeUnit;
      auto v = ConCommand.parseNum!T(ss);
      while (!ss.empty && ss.front <= 32) ss.popFront();
      if (!ss.empty) throw new ConvException("shit happens!");
    } catch (ConvException e) {
      return;
    }
    assert(0, format("exception not thrown, called from line %s", line));
  }

  testnum!int(" -42", -42);
  testnum!int(" +42", 42);
  testnum!int(" -4_2", -42);
  testnum!int(" +4_2", 42);
  testnum!int(" -0d42", -42);
  testnum!int(" +0d42", 42);
  testnum!int("0x2a", 42);
  testnum!int("-0x2a", -42);
  testnum!int("0o52", 42);
  testnum!int("-0o52", -42);
  testnum!int("0b00101010", 42);
  testnum!int("-0b00101010", -42);
  testnum!ulong("+9223372036854775808", 9223372036854775808uL);
  testnum!long("9223372036854775807", 9223372036854775807);
  testnum!long("-9223372036854775808", -9223372036854775808uL); // uL to workaround issue #13606
  testnum!ulong("+0x8000_0000_0000_0000", 9223372036854775808uL);
  testnum!long("-0x8000_0000_0000_0000", -9223372036854775808uL); // uL to workaround issue #13606
  testbadnum!long("9223372036854775808");
  testbadnum!int("_42");
  testbadnum!int("42_");
  testbadnum!int("42_ ");
  testbadnum!int("4__2");
  testbadnum!int("0x_2a");
  testbadnum!int("-0x_2a");
  testbadnum!int("_0x2a");
  testbadnum!int("-_0x2a");
  testbadnum!int("_00x2a");
  testbadnum!int("-_00x2a");
  testbadnum!int(" +0x");

  testnum!int("666", 666);
  testnum!int("+666", 666);
  testnum!int("-666", -666);

  testbadnum!int("+");
  testbadnum!int("-");
  testbadnum!int("5a");

  testbadnum!int("5.0");
  testbadnum!int("5e+2");

  testnum!uint("666", 666);
  testnum!uint("+666", 666);
  testbadnum!uint("-666");

  testnum!int("0x29a", 666);
  testnum!int("0X29A", 666);
  testnum!int("-0x29a", -666);
  testnum!int("-0X29A", -666);
  testnum!int("0b100", 4);
  testnum!int("0B100", 4);
  testnum!int("-0b100", -4);
  testnum!int("-0B100", -4);
  testnum!int("0o666", 438);
  testnum!int("0O666", 438);
  testnum!int("-0o666", -438);
  testnum!int("-0O666", -438);
  testnum!int("0d666", 666);
  testnum!int("0D666", 666);
  testnum!int("-0d666", -666);
  testnum!int("-0D666", -666);

  testnum!byte("-0x7f", -127);
  testnum!byte("-0x80", -128);
  testbadnum!byte("0x80");
  testbadnum!byte("-0x81");

  testbadnum!uint("1a");
  testbadnum!uint("0x1g");
  testbadnum!uint("0b12");
  testbadnum!uint("0o78");
  testbadnum!uint("0d1f");

  testbadnum!int("0x_2__9_a__");
  testbadnum!uint("0x_");

  testnum!ulong("0x8000000000000000", 0x8000000000000000UL);
  testnum!long("-0x8000000000000000", -0x8000000000000000uL);
  testbadnum!long("0x8000000000000000");
  testbadnum!ulong("0x80000000000000001");
  testbadnum!long("-0x8000000000000001");

  testbadnum!float("-0O666");
  testnum!float("0x666p0", 1638.0f);
  testnum!float("-0x666p0", -1638.0f);
  testnum!double("+1.1e+2", 110.0);
  testnum!double("2.4", 2.4);
  testnum!double("1_2.4", 12.4);
  testnum!float("42666e-3", 42.666f);
  testnum!float(" 4.2 ", 4.2);

  conwriteln("console: parser test passed");
}


// ////////////////////////////////////////////////////////////////////////// //
/// console alias
public final class ConAlias {
private:
  public import std.conv : ConvOverflowException;
  __gshared ConvOverflowException exAliasTooBig;
  __gshared ConvOverflowException exAliasTooDeep;

  shared static this () {
    exAliasTooBig = new ConvOverflowException("alias text too big");
    exAliasTooDeep = new ConvOverflowException("alias expansion too deep");
  }

  usize textmem;
  uint textsize;
  uint allocsize;

  this (const(char)[] atext) @nogc {
    set(atext);
  }

  ~this () {
    import core.stdc.stdlib : free;
    if (textmem != 0) free(cast(void*)textmem);
  }

  const(char)[] get () nothrow @trusted @nogc { pragma(inline, true); return (textmem != 0 ? (cast(char*)textmem)[0..textsize] : null); }

  void set (const(char)[] atext) @nogc {
    if (atext.length > 65535) throw exAliasTooBig;
    // realloc
    if (atext.length > allocsize) {
      import core.stdc.stdlib : realloc;
      uint newsz;
           if (atext.length <= 4096) newsz = 4096;
      else if (atext.length <= 8192) newsz = 8192;
      else if (atext.length <= 16384) newsz = 16384;
      else if (atext.length <= 32768) newsz = 32768;
      else newsz = 65536;
      assert(newsz >= atext.length);
      auto newmem = cast(usize)realloc(cast(void*)textmem, newsz);
      if (newmem == 0) assert(0, "out of memory for alias"); //FIXME
      textmem = newmem;
      allocsize = newsz;
    }
    assert(allocsize >= atext.length);
    textsize = cast(uint)atext.length;
    (cast(char*)textmem)[0..textsize] = atext;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// convar attributes
public enum ConVarAttr : uint {
  None = 0, ///
  Archive = 1U<<0, /// save on change (saving must be done by library user)
  Hex = 1U<<1, /// dump this variable as hex value (valid for integrals)
  //TODO:
  User = 1U<<30, /// user-created
  ReadOnly = 1U<<31, /// can't be changed with console command (direct change is still possible)
}


/// variable of some type
public class ConVarBase : ConCommand {
protected:
  uint mAttrs;

public:
  alias PreChangeHookCB = bool delegate (ConVarBase self, ConString newval); /// prototype for "before value change hook"; return `false` to abort; `newval` is not parsed
  alias PostChangeHookCB = void delegate (ConVarBase self, ConString newval); /// prototype for "after value change hook"; `newval` is not parsed

private:
  PreChangeHookCB hookBeforeChange;
  PostChangeHookCB hookAfterChange;

public:
  this (string aname, string ahelp=null) { super(aname, ahelp); } ///

  /// replaces current attributes (can't set `ConVarAttr.User` w/o !true)
  final void setAttrs(bool any=false) (const(ConVarAttr)[] attrs...) pure nothrow @safe @nogc {
    mAttrs = 0;
    foreach (const ConVarAttr a; attrs) {
      static if (!any) {
        if (a == ConVarAttr.User) continue;
      }
      mAttrs |= a;
    }
  }

  final ConVarBase setBeforeHook (PreChangeHookCB cb) { hookBeforeChange = cb; return this; } /// this can be chained
  final ConVarBase setAfterHook (PostChangeHookCB cb) { hookAfterChange = cb; return this; } /// this can be chained

  @property pure nothrow @safe @nogc final {
    PreChangeHookCB beforeHook () { return hookBeforeChange; } ///
    PostChangeHookCB afterHook () { return hookAfterChange; } ///

    void beforeHook (PreChangeHookCB cb) { hookBeforeChange = cb; } ///
    void afterHook (PostChangeHookCB cb) { hookAfterChange = cb; } ///

    /// attributes (see ConVarAttr enum)
    uint attrs () const { pragma(inline, true); return mAttrs; }
    /// replaces current attributes (can't set/remove `ConVarAttr.User` w/o !true)
    void attrs(bool any=false) (uint v) {
      pragma(inline, true);
      static if (any) mAttrs = v; else mAttrs = v&~(ConVarAttr.User);
    }

    bool attrArchive () const { pragma(inline, true); return ((mAttrs&ConVarAttr.Archive) != 0); } ///
    bool attrNoArchive () const { pragma(inline, true); return ((mAttrs&ConVarAttr.Archive) == 0); } ///

    void attrArchive (bool v) { pragma(inline, true); if (v) mAttrs |= ConVarAttr.Archive; else mAttrs &= ~ConVarAttr.Archive; } ///
    void attrNoArchive (bool v) { pragma(inline, true); if (!v) mAttrs |= ConVarAttr.Archive; else mAttrs &= ~ConVarAttr.Archive; } ///

    bool attrHexDump () const { pragma(inline, true); return ((mAttrs&ConVarAttr.Hex) != 0); } ///

    bool attrReadOnly () const { pragma(inline, true); return ((mAttrs&ConVarAttr.ReadOnly) != 0); } ///
    void attrReadOnly (bool v) { pragma(inline, true); if (v) mAttrs |= ConVarAttr.ReadOnly; else mAttrs &= ~ConVarAttr.ReadOnly; } ///

    bool attrUser () const { pragma(inline, true); return ((mAttrs&ConVarAttr.User) != 0); } ///
  }

  abstract void printValue (); /// print variable value to console
  abstract bool isString () const pure nothrow @nogc; /// is this string variable?
  abstract ConString strval () /*nothrow @nogc*/; /// get string value (for any var)

  /// get variable value, converted to the given type (if it is possible).
  @property T value(T) () /*nothrow @nogc*/ {
    pragma(inline, true);
    static if (is(T == enum)) {
      return cast(T)getIntValue;
    } else static if (is(T : ulong)) {
      // integer, xchar, boolean
      return cast(T)getIntValue;
    } else static if (is(T : double)) {
      // floats
      return cast(T)getDoubleValue;
    } else static if (is(T : ConString)) {
      // string
           static if (is(T == string)) return strval.idup;
      else static if (is(T == char[])) return strval.dup;
      else return strval;
    } else {
      // alas
      return T.init;
    }
  }

  /// set variable value, converted from the given type (if it is possible).
  /// ReadOnly is ignored, no hooks will be called.
  @property void value(T) (T val) /*nothrow*/ {
    pragma(inline, true);
    static if (is(T : ulong)) {
      // integer, xchar, boolean
      setIntValue(cast(ulong)val, isSigned!T);
    } else static if (is(T : double)) {
      // floats
      setDoubleValue(cast(double)val);
    } else static if (is(T : ConString)) {
      static if (is(T == string)) setStrValue(val); else setCCharValue(val);
    } else {
      static assert(0, "invalid type");
    }
  }

protected:
  abstract ulong getIntValue () /*nothrow @nogc*/;
  abstract double getDoubleValue () /*nothrow @nogc*/;

  abstract void setIntValue (ulong v, bool signed) /*nothrow @nogc*/;
  abstract void setDoubleValue (double v) /*nothrow @nogc*/;
  abstract void setStrValue (string v) /*nothrow*/;
  abstract void setCCharValue (ConString v) /*nothrow*/;
}


// ////////////////////////////////////////////////////////////////////////// //
/// console will use this to register console variables
final class ConVar(T) : ConVarBase {
  alias TT = XUQQ!T;
  enum useAtomic = is(T == shared);
  T* vptr;
  static if (isIntegral!TT) {
    TT minv = TT.min;
    TT maxv = TT.max;
  } else static if (isFloatingPoint!TT) {
    TT minv = -TT.max;
    TT maxv = TT.max;
  }
  static if (!is(TT : ConString)) {
    char[256] vbuf;
  } else {
    char[256] tvbuf; // temp value
  }

  TT delegate (ConVarBase self) cvGetter;
  void delegate (ConVarBase self, TT nv) cvSetter;

  void delegate (ConVarBase self, TT pv, TT nv) hookAfterChangeVV;

  this (T* avptr, string aname, string ahelp=null) {
    vptr = avptr;
    super(aname, ahelp);
  }

  static if (isIntegral!TT || isFloatingPoint!TT) {
    this (T* avptr, TT aminv, TT amaxv, string aname, string ahelp=null) {
      vptr = avptr;
      minv = aminv;
      maxv = amaxv;
      super(aname, ahelp);
    }
  }

  /// this method will respect `ReadOnly` flag, and will call before/after hooks.
  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) { printValue; return; }
    if (attrReadOnly) return; // can't change read-only var with console commands
    static if ((is(TT == bool) || isIntegral!TT || isFloatingPoint!TT) && !is(TT == enum)) {
      while (cmdline.length && cmdline[0] <= 32) cmdline = cmdline[1..$];
      while (cmdline.length && cmdline[$-1] <= 32) cmdline = cmdline[0..$-1];
      if (cmdline == "toggle") {
        if (hookBeforeChange !is null) { if (!hookBeforeChange(this, cmdline)) return; }
        auto prval = getv();
        if (cvSetter !is null) {
          cvSetter(this, !prval);
        } else {
          static if (useAtomic) {
            import core.atomic;
            atomicStore(*vptr, !prval);
          } else {
            *vptr = !prval;
          }
        }
        if (hookAfterChangeVV !is null) hookAfterChangeVV(this, prval, !prval);
        if (hookAfterChange !is null) hookAfterChange(this, cmdline);
        return;
      }
    }
    auto newvals = cmdline;
    TT val = parseType!TT(/*ref*/ cmdline);
    if (hasArgs(cmdline)) throw exTooManyArgs;
    static if (isIntegral!TT) {
      if (val < minv) val = minv;
      if (val > maxv) val = maxv;
    }
    if (hookBeforeChange !is null) { if (!hookBeforeChange(this, newvals)) return; }
    TT oval;
    if (hookAfterChangeVV !is null) oval = getv();
    if (cvSetter !is null) {
      cvSetter(this, val);
    } else {
      static if (useAtomic) {
        import core.atomic;
        atomicStore(*vptr, val);
      } else {
        *vptr = val;
      }
    }
    if (hookAfterChangeVV !is null) hookAfterChangeVV(this, oval, val);
    if (hookAfterChange !is null) hookAfterChange(this, newvals);
  }

  override bool isString () const pure nothrow @nogc {
    static if (is(TT : ConString)) return true; else return false;
  }

  final private TT getv() () /*nothrow @nogc*/ {
    pragma(inline, true);
    import core.atomic;
    if (cvGetter !is null) {
      return cvGetter(this);
    } else {
      static if (useAtomic) return atomicLoad(*vptr); else return *vptr;
    }
  }

  override ConString strval () /*nothrow @nogc*/ {
    //conwriteln("*** strval for '", name, "'");
    import core.stdc.stdio : snprintf;
    static if (is(TT == enum)) {
      auto v = getv();
      foreach (string mname; __traits(allMembers, TT)) {
        if (__traits(getMember, TT, mname) == v) return mname;
      }
      return "???";
    } else static if (is(T : ConString)) {
      return getv();
    } else static if (is(XUQQ!T == bool)) {
      return (getv() ? "tan" : "ona");
    } else static if (isIntegral!T) {
      static if (isSigned!T) {
        auto len = snprintf(vbuf.ptr, vbuf.length, "%lld", cast(long)(getv()));
      } else {
        auto len = snprintf(vbuf.ptr, vbuf.length, (attrHexDump ? "0x%06llx".ptr : "%llu".ptr), cast(ulong)(getv()));
      }
      return (len >= 0 ? vbuf[0..len] : "?");
    } else static if (isFloatingPoint!T) {
      auto len = snprintf(vbuf.ptr, vbuf.length, "%g", cast(double)(getv()));
      return (len >= 0 ? vbuf[0..len] : "?");
    } else static if (is(XUQQ!T == char)) {
      vbuf.ptr[0] = cast(char)getv();
      return vbuf[0..1];
    } else {
      static assert(0, "can't get string value of convar with type '"~T.stringof~"'");
    }
  }

  protected override ulong getIntValue () /*nothrow @nogc*/ {
    static if (is(T : ulong) || is(T : double)) return cast(ulong)(getv()); else return ulong.init;
  }

  protected override double getDoubleValue () /*nothrow @nogc*/ {
    static if (is(T : double) || is(T : ulong)) return cast(double)(getv()); else return double.init;
  }

  private template PutVMx(string val) {
    static if (useAtomic) {
      enum PutVMx = "{ import core.atomic; if (cvSetter !is null) cvSetter(this, "~val~"); else atomicStore(*vptr, "~val~"); }";
    } else {
      enum PutVMx = "{ if (cvSetter !is null) cvSetter(this, "~val~"); else *vptr = "~val~"; }";
    }
  }

  protected override void setIntValue (ulong v, bool signed) /*nothrow @nogc*/ {
    import core.atomic;
    static if (is(XUQQ!T == enum)) {
      foreach (string mname; __traits(allMembers, TT)) {
        if (__traits(getMember, TT, mname) == v) {
          mixin(PutVMx!"cast(T)v");
          return;
        }
      }
      // alas
      conwriteln("invalid enum value '", v, "' for variable '", name, "'");
    } else static if (is(T : ulong) || is(T : double)) {
      mixin(PutVMx!"cast(T)v");
    } else static if (is(T : ConString)) {
      import core.stdc.stdio : snprintf;
      auto len = snprintf(tvbuf.ptr, tvbuf.length, (signed ? "%lld" : "%llu"), v);
           static if (is(T == string)) mixin(PutVMx!"cast(string)(tvbuf[0..len])"); // not really safe, but...
      else static if (is(T == ConString)) mixin(PutVMx!"cast(ConString)(tvbuf[0..len])");
      else static if (is(T == char[])) mixin(PutVMx!"tvbuf[0..len]");
    }
  }

  protected override void setDoubleValue (double v) /*nothrow @nogc*/ {
    import core.atomic;
    static if (is(XUQQ!T == enum)) {
      foreach (string mname; __traits(allMembers, TT)) {
        if (__traits(getMember, TT, mname) == v) {
          mixin(PutVMx!"cast(T)v");
          return;
        }
      }
      // alas
      conwriteln("invalid enum value '", v, "' for variable '", name, "'");
    } else static if (is(T : ulong) || is(T : double)) {
      mixin(PutVMx!"cast(T)v");
    } else static if (is(T : ConString)) {
      import core.stdc.stdio : snprintf;
      auto len = snprintf(tvbuf.ptr, tvbuf.length, "%g", v);
           static if (is(T == string)) mixin(PutVMx!"cast(string)(tvbuf[0..len])"); // not really safe, but...
      else static if (is(T == ConString)) mixin(PutVMx!"cast(ConString)(tvbuf[0..len])");
      else static if (is(T == char[])) mixin(PutVMx!"tvbuf[0..len]");
    }
  }

  protected override void setStrValue (string v) /*nothrow*/ {
    import core.atomic;
    static if (is(XUQQ!T == enum)) {
      try {
        ConString ss = v;
        auto vv = ConCommand.parseType!T(ss);
        mixin(PutVMx!"cast(T)vv");
      } catch (Exception) {
        conwriteln("invalid enum value '", v, "' for variable '", name, "'");
      }
    } else static if (is(T == string) || is(T == ConString)) {
      mixin(PutVMx!"cast(T)v");
    } else static if (is(T == char[])) {
      mixin(PutVMx!"v.dup");
    }
  }

  protected override void setCCharValue (ConString v) /*nothrow*/ {
    import core.atomic;
    static if (is(XUQQ!T == enum)) {
      try {
        ConString ss = v;
        auto vv = ConCommand.parseType!T(ss);
        mixin(PutVMx!"cast(T)vv");
      } catch (Exception) {
        conwriteln("invalid enum value '", v, "' for variable '", name, "'");
      }
    }
    else static if (is(T == string)) mixin(PutVMx!"v.idup");
    else static if (is(T == ConString)) mixin(PutVMx!"v");
    else static if (is(T == char[])) mixin(PutVMx!"v.dup");
  }

  override void printValue () {
    static if (is(T == enum)) {
      auto vx = getv();
      foreach (string mname; __traits(allMembers, TT)) {
        if (__traits(getMember, TT, mname) == vx) {
          conwrite(name);
          conwrite(" ");
          //writeQuotedString(mname);
          conwrite(mname);
          conwrite("\n");
          return;
        }
      }
      //FIXME: doubles?
      conwriteln(name, " ", cast(ulong)getv());
    } else static if (is(T : ConString)) {
      conwrite(name);
      conwrite(" ");
      writeQuotedString(getv());
      conwrite("\n");
    } else static if (is(XUQQ!T == char)) {
      conwrite(name);
      conwrite(" ");
      char[1] st = getv();
      if (st[0] <= ' ' || st[0] == 127 || st[0] == '"' || st[0] == '\\') {
        writeQuotedString(st[]);
      } else {
        conwrite(`"`);
        conwrite(st[]);
        conwrite(`"`);
      }
      conwrite("\n");
    } else static if (is(T == bool)) {
      conwriteln(name, " ", (getv() ? "tan" : "ona"));
    } else {
      conwriteln(name, " ", strval);
    }
  }
}


///
version(contest_vars) unittest {
  __gshared int vi = 42;
  __gshared string vs = "str";
  __gshared bool vb = true;
  auto cvi = new ConVar!int(&vi, "vi", "integer variable");
  auto cvs = new ConVar!string(&vs, "vs", "string variable");
  auto cvb = new ConVar!bool(&vb, "vb", "bool variable");
  cvi.exec("?");
  cvs.exec("?");
  cvb.exec("?");
  cvi.exec("");
  cvs.exec("");
  cvb.exec("");
  cvi.exec("666");
  cvs.exec("'fo\to'");
  cvi.exec("");
  cvs.exec("");
  conwriteln("vi=", vi);
  conwriteln("vs=[", vs, "]");
  cvs.exec("'?'");
  cvs.exec("");
  cvb.exec("tan");
  cvb.exec("");
  cvb.exec("ona");
  cvb.exec("");
}


// don't use std.algo
private void heapsort(alias lessfn, T) (T[] arr) {
  auto count = arr.length;
  if (count < 2) return; // nothing to do

  void siftDown(T) (T start, T end) {
    auto root = start;
    for (;;) {
      auto child = 2*root+1; // left child
      if (child > end) break;
      auto swap = root;
      if (lessfn(arr.ptr[swap], arr.ptr[child])) swap = child;
      if (child+1 <= end && lessfn(arr.ptr[swap], arr.ptr[child+1])) swap = child+1;
      if (swap == root) break;
      auto tmp = arr.ptr[swap];
      arr.ptr[swap] = arr.ptr[root];
      arr.ptr[root] = tmp;
      root = swap;
    }
  }

  auto end = count-1;
  // heapify
  auto start = (end-1)/2; // parent; always safe, as our array has at least two items
  for (;;) {
    siftDown(start, end);
    if (start-- == 0) break; // as `start` cannot be negative, use this condition
  }

  while (end > 0) {
    {
      auto tmp = arr.ptr[0];
      arr.ptr[0] = arr.ptr[end];
      arr.ptr[end] = tmp;
    }
    --end;
    siftDown(0, end);
  }
}


private void conUnsafeArrayAppend(T) (ref T[] arr, auto ref T v) /*nothrow*/ {
  if (arr.length >= int.max/2) assert(0, "too many elements in array");
  auto optr = arr.ptr;
  arr ~= v;
  if (arr.ptr !is optr) {
    import core.memory : GC;
    optr = arr.ptr;
    if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
  }
}


private void addName (string name) {
  //{ import core.stdc.stdio; printf("%.*s\n", cast(uint)name.length, name.ptr); }
  // ascii only
  static bool strLessCI (const(char)[] s0, const(char)[] s1) pure nothrow @trusted @nogc {
    auto slen = s0.length;
    if (slen > s1.length) slen = s1.length;
    char c1;
    foreach (immutable idx, char c0; s0[0..slen]) {
      if (c0 >= 'A' && c0 <= 'Z') c0 += 32; // poor man's tolower()
      c1 = s1.ptr[idx];
      if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man's tolower()
      if (c0 < c1) return true;
      if (c0 > c1) return false;
    }
    if (s0.length < s1.length) return true;
    if (s0.length > s1.length) return false;
    return false;
  }

  if (name.length == 0) return;
  if (name !in cmdlist) {
    //cmdlistSorted ~= name;
    cmdlistSorted.conUnsafeArrayAppend(name);
    heapsort!strLessCI(cmdlistSorted);
  }
}


private void enumComplete(T) (ConCommand self) if (is(T == enum)) {
  auto cs = conInputBuffer[0..conInputBufferCurX];
  ConCommand.getWord(cs); // skip command
  while (cs.length && cs[0] <= ' ') cs = cs[1..$];
  if (cs.length == 0) {
    conwriteln(self.name, ":");
    foreach (string mname; __traits(allMembers, T)) conwriteln("  ", mname);
  } else {
    if (cs[0] == '"' || cs[0] == '\'') return; // alas
    ConString pfx = ConCommand.getWord(cs);
    while (cs.length && cs[0] <= ' ') cs = cs[1..$];
    if (cs.length) return; // alas
    string bestPfx;
    int count = 0;
    foreach (string mname; __traits(allMembers, T)) {
      if (mname.length >= pfx.length && strEquCI(mname[0..pfx.length], pfx)) {
        if (count == 0) {
          bestPfx = mname;
        } else {
          //if (mname.length < bestPfx.length) bestPfx = bestPfx[0..mname.length];
          usize pos = 0;
          while (pos < bestPfx.length && pos < mname.length) {
            char c0 = bestPfx[pos];
            char c1 = mname[pos];
            if (c0 >= 'A' && c0 <= 'Z') c0 += 32; // poor man's tolower()
            if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man's tolower()
            if (c0 != c1) break;
            ++pos;
          }
          if (pos < bestPfx.length) bestPfx = bestPfx[0..pos];
        }
        ++count;
      }
    }
    if (count == 0 || bestPfx.length < pfx.length) { conwriteln(self.name, ": ???"); return; }
    foreach (char ch; bestPfx[pfx.length..$]) conAddInputChar(ch);
    if (count == 1) {
      conAddInputChar(' ');
    } else {
      conwriteln(self.name, ":");
      foreach (string mname; __traits(allMembers, T)) {
        if (mname.length >= bestPfx.length && mname[0..bestPfx.length] == bestPfx) {
          conwriteln("  ", mname);
        }
      }
    }
  }
}


private void boolComplete(T) (ConCommand self) if (is(T == bool)) {
  auto cs = conInputBuffer[0..conInputBufferCurX];
  ConCommand.getWord(cs); // skip command
  while (cs.length && cs[0] <= ' ') cs = cs[1..$];
  if (cs.length > 0) {
    enum Cmd = "toggle";
    foreach (immutable idx, char ch; Cmd) {
      if (idx >= cs.length) break;
      if (cs[idx] != ch) return; // alas
    }
    if (cs.length > Cmd.length) return;
    foreach (char ch; Cmd[cs.length..$]) conAddInputChar(ch);
    conAddInputChar(' ');
  } else {
    conwriteln("  toggle?");
  }
}


/** register console variable with getter and setter.
 *
 * Params:
 *   aname = variable name
 *   ahelp = help text
 *   dgg = getter
 *   dgs = setter
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(T) (string aname, string ahelp, T delegate (ConVarBase self) dgg, void delegate (ConVarBase self, T nv) dgs, const(ConVarAttr)[] attrs...)
if (!is(T == struct) && !is(T == class))
{
  if (dgg is null || dgs is null) assert(0, "cmdcon: both getter and setter should be defined for convar");
  if (aname.length > 0) {
    addName(aname);
    auto cv = new ConVar!T(null, aname, ahelp);
    cv.setAttrs(attrs);
    cv.cvGetter = dgg;
    cv.cvSetter = dgs;
    cmdlist[aname] = cv;
    return cv;
  } else {
    return null;
  }
}


private enum RegVarMixin(string cvcreate) =
  `static assert(isGoodVar!v, "console variable '"~v.stringof~"' must be shared or __gshared");`~
  `if (aname.length == 0) {`~
  `aname = (&v).stringof[2..$]; /*HACK*/`~
  `  foreach_reverse (immutable cidx, char ch; aname) if (ch == '.') { aname = aname[cidx+1..$]; break; }`~
  `}`~
  `if (aname.length > 0) {`~
  `  addName(aname);`~
  `  auto cv = `~cvcreate~`;`~
  `  cv.setAttrs(attrs);`~
  `  alias UT = XUQQ!(typeof(v));`~
  `  static if (is(UT == enum)) {`~
  `    import std.functional : toDelegate;`~
  `    cv.argcomplete = toDelegate(&enumComplete!UT);`~
  `  } else static if (is(UT == bool)) {`~
  `    import std.functional : toDelegate;`~
  `    cv.argcomplete = toDelegate(&boolComplete!UT);`~
  `  }`~
  `  cmdlist[aname] = cv;`~
  `  return cv;`~
  `} else {`~
  `  return null;`~
  `}`;


/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v, T) (T aminv, T amaxv, string aname, string ahelp, const(ConVarAttr)[] attrs...)
if ((isIntegral!(typeof(v)) && isIntegral!T) || (isFloatingPoint!(typeof(v)) && (isIntegral!T || isFloatingPoint!T)))
{
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, cast(typeof(v))aminv, cast(typeof(v))amaxv, aname, ahelp)`);
}

/** register integral console variable with old/new delegate.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   cdg = old/new change delegate
 *   attrs = convar attributes (see `ConVarAttr`)
 */
ConVarBase conRegVar(alias v) (string aname, string ahelp, void delegate (ConVarBase self, XUQQ!(typeof(v)) oldv, XUQQ!(typeof(v)) newv) cdg, const(ConVarAttr)[] attrs...)
if (is(XUQQ!(typeof(v)) : long) || is(XUQQ!(typeof(v)) : double) || is(XUQQ!(typeof(v)) : ConString) || is(XUQQ!(typeof(v)) == bool) || is(XUQQ!(typeof(v)) == enum)) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, aname, ahelp); cv.hookAfterChangeVV = cdg`);
}

/** register integral console variable with bounded value and old/new delegate.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   cdg = old/new change delegate
 *   attrs = convar attributes (see `ConVarAttr`)
 */
ConVarBase conRegVar(alias v) (XUQQ!(typeof(v)) amin, XUQQ!(typeof(v)) amax, string aname, string ahelp, void delegate (ConVarBase self, XUQQ!(typeof(v)) oldv, XUQQ!(typeof(v)) newv) cdg, const(ConVarAttr)[] attrs...)
if (is(XUQQ!(typeof(v)) : long) || is(XUQQ!(typeof(v)) : double) && !is(XUQQ!(typeof(v)) == bool) && !is(XUQQ!(typeof(v)) == enum)) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, amin, amax, aname, ahelp); cv.hookAfterChangeVV = cdg`);
}

/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   bcb = "before value change" hook: `bool (ConVarBase self, ConString valstr)`, return `false` to block change
 *   acb = "after value change" hook: `(ConVarBase self, ConString valstr)`
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v, T) (T aminv, T amaxv, string aname, string ahelp, ConVarBase.PreChangeHookCB bcb, ConVarBase.PostChangeHookCB acb, const(ConVarAttr)[] attrs...) if (isIntegral!(typeof(v)) && isIntegral!T) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, cast(typeof(v))aminv, cast(typeof(v))amaxv, aname, ahelp); cv.hookBeforeChange = bcb; cv.hookAfterChange = acb`);
}

/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   acb = "after value change" hook: `(ConVarBase self, ConString valstr)`
 *   bcb = "before value change" hook: `bool (ConVarBase self, ConString valstr)`, return `false` to block change
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v, T) (T aminv, T amaxv, string aname, string ahelp, ConVarBase.PostChangeHookCB acb, ConVarBase.PreChangeHookCB bcb, const(ConVarAttr)[] attrs...) if (isIntegral!(typeof(v)) && isIntegral!T) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, cast(typeof(v))aminv, cast(typeof(v))amaxv, aname, ahelp); cv.hookBeforeChange = bcb; cv.hookAfterChange = acb`);
}

/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   bcb = "before value change" hook: `bool (ConVarBase self, ConString valstr)`, return `false` to block change
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v, T) (T aminv, T amaxv, string aname, string ahelp, ConVarBase.PreChangeHookCB bcb, const(ConVarAttr)[] attrs...) if (isIntegral!(typeof(v)) && isIntegral!T) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, cast(typeof(v))aminv, cast(typeof(v))amaxv, aname, ahelp); cv.hookBeforeChange = bcb`);
}

/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   acb = "after value change" hook: `(ConVarBase self, ConString valstr)`
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v, T) (T aminv, T amaxv, string aname, string ahelp, ConVarBase.PostChangeHookCB acb, const(ConVarAttr)[] attrs...) if (isIntegral!(typeof(v)) && isIntegral!T) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, cast(typeof(v))aminv, cast(typeof(v))amaxv, aname, ahelp); cv.hookAfterChange = acb`);
}


/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v) (string aname, string ahelp, const(ConVarAttr)[] attrs...) if (!isCallable!(typeof(v))) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, aname, ahelp)`);
}

/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   bcb = "before value change" hook: `bool (ConVarBase self, ConString valstr)`, return `false` to block change
 *   acb = "after value change" hook: `(ConVarBase self, ConString valstr)`
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v) (string aname, string ahelp, ConVarBase.PreChangeHookCB bcb, ConVarBase.PostChangeHookCB acb, const(ConVarAttr)[] attrs...) if (!isCallable!(typeof(v))) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, aname, ahelp); cv.hookBeforeChange = bcb; cv.hookAfterChange = acb`);
}

/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   acb = "after value change" hook: `(ConVarBase self, ConString valstr)`
 *   bcb = "before value change" hook: `bool (ConVarBase self, ConString valstr)`, return `false` to block change
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v) (string aname, string ahelp, ConVarBase.PostChangeHookCB acb, ConVarBase.PreChangeHookCB bcb, const(ConVarAttr)[] attrs...) if (!isCallable!(typeof(v))) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, aname, ahelp); cv.hookBeforeChange = bcb; cv.hookAfterChange = acb`);
}

/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   bcb = "before value change" hook: `bool (ConVarBase self, ConString valstr)`, return `false` to block change
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v) (string aname, string ahelp, ConVarBase.PreChangeHookCB bcb, const(ConVarAttr)[] attrs...) if (!isCallable!(typeof(v))) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, aname, ahelp); cv.hookBeforeChange = bcb`);
}

/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   acb = "after value change" hook: `(ConVarBase self, ConString valstr)`
 *   attrs = convar attributes (see `ConVarAttr`)
 */
public ConVarBase conRegVar(alias v) (string aname, string ahelp, ConVarBase.PostChangeHookCB acb, const(ConVarAttr)[] attrs...) if (!isCallable!(typeof(v))) {
  mixin(RegVarMixin!`new ConVar!(typeof(v))(&v, aname, ahelp); cv.hookAfterChange = acb`);
}


// ////////////////////////////////////////////////////////////////////////// //
// delegate
public class ConFuncBase : ConCommand {
  this (string aname, string ahelp=null) { super(aname, ahelp); }
}


/// use `conRegFunc!((ConFuncVA va) {...}, ...)` to switch off automatic argument parsing
public struct ConFuncVA {
  ConString cmdline;
}


/** register console command.
 *
 * Params:
 *   fn = symbol
 *   aname = variable name
 *   ahelp = help text
 */
public void conRegFunc(alias fn) (string aname, string ahelp) if (isCallable!fn) {
  // we have to make the class nested, so we can use `dg`, which keeps default args

  // hack for inline lambdas
  static if (is(typeof(&fn))) {
    auto dg = &fn;
  } else {
    auto dg = fn;
  }

  class ConFunc : ConFuncBase {
    this (string aname, string ahelp=null) { super(aname, ahelp); }

    override void exec (ConString cmdline) {
      if (checkHelp(cmdline)) { showHelp; return; }
      Parameters!dg args;
      static if (args.length == 0) {
        if (hasArgs(cmdline)) {
          conwriteln("too many args for command '", name, "'");
        } else {
          dg();
        }
      } else static if (args.length == 1 && is(typeof(args[0]) == ConFuncVA)) {
        args[0].cmdline = cmdline;
        dg(args);
      } else {
        alias defaultArguments = ParameterDefaults!fn;
        //pragma(msg, "defs: ", defaultArguments);
        import std.conv : to;
        ConString[128] rest; // to avoid allocations in most cases
        ConString[] restdyn; // will be used if necessary
        uint restpos;
        foreach (/*auto*/ idx, ref arg; args) {
          // populate arguments, with user data if available,
          // default if not, and throw if no argument provided
          if (hasArgs(cmdline)) {
            import std.conv : ConvException;
            static if (is(typeof(arg) == ConString[])) {
              auto xidx = idx+1;
              if (idx != args.length-1) {
                conwriteln("error parsing argument #", xidx, " for command '", name, "'");
                return;
              }
              while (hasArgs(cmdline)) {
                try {
                  ConString cs = parseType!ConString(cmdline);
                  if (restpos == rest.length) { restdyn = rest[]; ++restpos; }
                  if (restpos < rest.length) rest[restpos++] = cs; else restdyn ~= cs;
                  ++xidx;
                } catch (ConvException) {
                  conwriteln("error parsing argument #", xidx, " for command '", name, "'");
                  return;
                }
              }
              arg = (restpos <= rest.length ? rest[0..restpos] : restdyn);
            } else {
              try {
                arg = parseType!(typeof(arg))(cmdline);
              } catch (ConvException) {
                conwriteln("error parsing argument #", idx+1, " for command '", name, "'");
                return;
              }
            }
          } else {
            static if (!is(defaultArguments[idx] == void)) {
              arg = defaultArguments[idx];
            } else {
              conwriteln("required argument #", idx+1, " for command '", name, "' is missing");
              return;
            }
          }
        }
        if (hasArgs(cmdline)) {
          conwriteln("too many args for command '", name, "'");
          return;
        }
        //static if (is(ReturnType!dg == void))
        dg(args);
      }
    }
  }

  static if (is(typeof(&fn))) {
    if (aname.length == 0) aname = (&fn).stringof[2..$]; // HACK
  }
  if (aname.length > 0) {
    addName(aname);
    cmdlist[aname] = new ConFunc(aname, ahelp);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared /*ConCommand*/Object[string] cmdlist; // ConCommand or ConAlias
__gshared string[] cmdlistSorted;


/** set argument completion delegate for command.
 *
 * delegate will be called from `conAddInputChar()`.
 * delegate can use `conInputBuffer()` to get current input buffer,
 * `conInputBufferCurX()` to get cursor position, and
 * `conAddInputChar()` itself to put new chars into buffer.
 */
void conSetArgCompleter (ConString cmdname, ConCommand.ArgCompleteCB ac) {
  if (auto cp = cmdname in cmdlist) {
    if (auto cmd = cast(ConCommand)(*cp)) cmd.argcomplete = ac;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// all following API is thread-unsafe, if the opposite is not written
public bool conHasCommand (ConString name) { pragma(inline, true); return ((name in cmdlist) !is null); } /// check if console has a command with a given name (thread-unsafe)
public bool conHasAlias (ConString name) { if (auto cc = name in cmdlist) return (cast(ConAlias)(*cc) !is null); else return false; } /// check if console has an alias with a given name (thread-unsafe)
public bool conHasVar (ConString name) { if (auto cc = name in cmdlist) return (cast(ConVarBase)(*cc) !is null); else return false; } /// check if console has a variable with a given name (thread-unsafe)

/// known console commands (funcs and vars) range (thread-unsafe)
/// type: "all", "vars", "funcs"
public auto conByCommand(string type="all") () if (type == "all" || type == "vars" || type == "funcs" || type == "aliases" || type == "archive") {
  static struct Range(string type) {
  private:
    usize idx;

  private:
    this (usize stidx) {
      static if (type == "all") {
        idx = stidx;
      } else static if (type == "vars") {
        while (stidx < cmdlistSorted.length && (cast(ConVarBase)cmdlist[cmdlistSorted.ptr[stidx]]) is null) ++stidx;
        idx = stidx;
      } else static if (type == "funcs") {
        while (stidx < cmdlistSorted.length && (cast(ConFuncBase)cmdlist[cmdlistSorted.ptr[stidx]]) is null) ++stidx;
        idx = stidx;
      } else static if (type == "aliases") {
        while (stidx < cmdlistSorted.length && (cast(ConAlias)cmdlist[cmdlistSorted.ptr[stidx]]) is null) ++stidx;
        idx = stidx;
      } else static if (type == "archive") {
        while (stidx < cmdlistSorted.length) {
          if (auto v = cast(ConVarBase)cmdlist[cmdlistSorted.ptr[stidx]]) {
            if (v.attrArchive) break;
          }
          ++stidx;
        }
        idx = stidx;
      } else {
        static assert(0, "wtf?!");
      }
    }

  public:
    @property bool empty() () { pragma(inline, true); return (idx >= cmdlistSorted.length); }
    @property string front() () { pragma(inline, true); return (idx < cmdlistSorted.length ? cmdlistSorted.ptr[idx] : null); }
    @property bool frontIsVar() () { pragma(inline, true); return (idx < cmdlistSorted.length ? (cast(ConVarBase)cmdlist[cmdlistSorted.ptr[idx]] !is null) : false); }
    @property bool frontIsFunc() () { pragma(inline, true); return (idx < cmdlistSorted.length ? (cast(ConFuncBase)cmdlist[cmdlistSorted.ptr[idx]] !is null) : false); }
    @property bool frontIsAlias() () { pragma(inline, true); return (idx < cmdlistSorted.length ? (cast(ConAlias)cmdlist[cmdlistSorted.ptr[idx]] !is null) : false); }
    void popFront () {
      if (idx >= cmdlistSorted.length) return;
      static if (type == "all") {
       //pragma(inline, true);
        ++idx;
      } else static if (type == "vars") {
        ++idx;
        while (idx < cmdlistSorted.length && (cast(ConVarBase)cmdlist[cmdlistSorted.ptr[idx]]) is null) ++idx;
      } else static if (type == "funcs") {
        ++idx;
        while (idx < cmdlistSorted.length && (cast(ConFuncBase)cmdlist[cmdlistSorted.ptr[idx]]) is null) ++idx;
      } else static if (type == "aliases") {
        ++idx;
        while (idx < cmdlistSorted.length && (cast(ConAlias)cmdlist[cmdlistSorted.ptr[idx]]) is null) ++idx;
      } else static if (type == "archive") {
        ++idx;
        while (idx < cmdlistSorted.length) {
          if (auto v = cast(ConVarBase)cmdlist[cmdlistSorted.ptr[idx]]) {
            if (v.attrArchive) break;
          }
          ++idx;
        }
      } else {
        static assert(0, "wtf?!");
      }
    }
  }
  return Range!type(0);
}


// ////////////////////////////////////////////////////////////////////////// //
// thread-safe

/// get console variable value (thread-safe)
public T conGetVar(T=ConString) (ConString s) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) return cv.value!T;
  }
  return T.init;
}

/// ditto
public T conGetVar(T=ConString) (ConVarBase v) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (v !is null) return v.value!T;
  return T.init;
}


/// set console variable value (thread-safe)
public void conSetVar(T) (ConString s, T val) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) cv.value = val;
  }
}

/// ditto
public void conSetVar(T) (ConVarBase v, T val) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (v !is null) v.value = val;
}


/// "seal" console variable (i.e. make it read-only) (thread-safe)
public void conSealVar (ConString s) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) cv.attrReadOnly = true;
  }
}

/// ditto
public void conSealVar (ConVarBase v) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (v !is null) v.attrReadOnly = true;
}


/// "seal" console variable (i.e. make it r/w) (thread-safe)
public void conUnsealVar (ConString s) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) cv.attrReadOnly = false;
  }
}

/// ditto
public void conUnsealVar (ConVarBase v) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (v !is null) v.attrReadOnly = false;
}


// ////////////////////////////////////////////////////////////////////////// //
// thread-safe

shared bool ccWaitPrepends = true;
public @property bool conWaitPrepends () nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicLoad; return atomicLoad(ccWaitPrepends); } /// shoud "wait" prepend rest of the alias?
public @property void conWaitPrepends (bool v) nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicStore; atomicStore(ccWaitPrepends, v); } /// ditto

__gshared char* ccWaitPrependStr = null;
__gshared uint ccWaitPrependStrSize, ccWaitPrependStrLen;

ConString prependStr () { return ccWaitPrependStr[0..ccWaitPrependStrLen]; }

void clearPrependStr () { ccWaitPrependStrLen = 0; return; }

void setPrependStr (ConString s) {
  if (s.length == 0) { ccWaitPrependStrLen = 0; return; }
  if (s.length >= int.max/8) assert(0, "console command too long"); //FIXME
  if (s.length > ccWaitPrependStrSize) {
    import core.stdc.stdlib : realloc;
    ccWaitPrependStr = cast(char*)realloc(ccWaitPrependStr, s.length);
    if (ccWaitPrependStr is null) assert(0, "out of memory in cmdcon"); //FIXME
    ccWaitPrependStrSize = cast(uint)s.length;
  }
  assert(s.length <= ccWaitPrependStrSize);
  ccWaitPrependStrLen = cast(uint)s.length;
  ccWaitPrependStr[0..s.length] = s[];
}


/// execute console command (thread-safe)
/// return `true` if `wait` pseudocommant was hit
public bool conExecute (ConString s) {
  bool waitHit = false;
  auto ss = s; // anchor it
  consoleLock();
  scope(exit) consoleUnlock();

  enum MaxAliasExpand = 256*1024; // 256KB

  void conExecuteInternal (ConString s, int aliassize, int aliaslevel) {
    ConString anchor = s, curs = s;
    for (;;) {
      if (aliaslevel > 0) {
        s = conGetCommandStr(curs);
        if (s is null) return;
      } else {
        curs = null;
      }
      auto w = ConCommand.getWord(s);
      if (w is null) return;
      // "wait" pseudocommand
      if (w == "wait") {
        waitHit = true;
        // insert the rest of the code into command queue (at the top),
        // so it will be processed on the next `conProcessQueue()` call
        while (curs.length) {
          while (curs.length && curs.ptr[0] <= ' ') curs = curs[1..$];
          if (curs.length == 0 || curs.ptr[0] != '#') break;
          // comment; skip it
          while (curs.length && curs.ptr[0] != '\n') curs = curs[1..$];
        }
        if (curs.length) {
          // has something to insert
          if (conWaitPrepends) {
            //ccWaitPrependStr = curs;
            //concmdPrepend(curs);
            setPrependStr(curs);
          } else {
            concmdAdd!true(curs); // ensure new command
          }
        }
        return;
      }
      version(iv_cmdcon_debug_wait) conwriteln("CMD: <", w, ">; args=<", s, ">; rest=<", curs, ">");
      if (auto cobj = w in cmdlist) {
        if (auto cmd = cast(ConCommand)(*cobj)) {
          // execute command
          while (s.length && s.ptr[0] <= 32) s = s[1..$];
          //conwriteln("'", s, "'");
          cmd.exec(s);
        } else if (auto ali = cast(ConAlias)(*cobj)) {
          // execute alias
          //TODO: alias arguments
          auto atext = ali.get;
          //conwriteln("ALIAS: '", w, "': '", atext, "'");
          if (atext.length) {
            if (aliassize+atext.length > MaxAliasExpand) throw ConAlias.exAliasTooDeep;
            if (aliaslevel >= 128) throw ConAlias.exAliasTooDeep;
            conExecuteInternal(atext, aliassize+cast(int)atext.length, aliaslevel+1);
          }
        } else {
          conwrite("command ");
          ConCommand.writeQuotedString(w);
          conwrite(" is of unknown type (internal error)");
          conwrite("\n");
        }
      } else {
        conwrite("command ");
        ConCommand.writeQuotedString(w);
        conwrite(" not found");
        conwrite("\n");
      }
      s = curs;
    }
  }

  try {
    conExecuteInternal(s, 0, 0);
  } catch (Exception) {
    conwriteln("error executing console command:\n ", s);
  }
  return waitHit;
}


// ////////////////////////////////////////////////////////////////////////// //
///
version(contest_func) unittest {
  static void xfunc (int v, int x=42) { conwriteln("xfunc: v=", v, "; x=", x); }

  conRegFunc!xfunc("", "function with two int args (last has default value '42')");
  conExecute("xfunc ?");
  conExecute("xfunc 666");
  conExecute("xfunc");

  conRegFunc!({conwriteln("!!!");})("bang", "dummy function");
  conExecute("bang");

  conRegFunc!((ConFuncVA va) {
    int idx = 1;
    for (;;) {
      auto w = ConCommand.getWord(va.cmdline);
      if (w is null) break;
      conwriteln("#", idx, ": [", w, "]");
      ++idx;
    }
  })("doo", "another dummy function");
  conExecute("doo 1 2 ' 34 '");
}


// ////////////////////////////////////////////////////////////////////////// //
/** get console commad from array of text.
 *
 * console commands are delimited with newlines, but can include various quoted chars and such.
 * this function will take care of that, and return something suitable for passing to `conExecute`.
 *
 * it will return `null` if there is no command (i.e. end-of-text reached).
 */
public ConString conGetCommandStr (ref ConString s) {
  for (;;) {
    while (s.length > 0 && s[0] <= 32) s = s[1..$];
    if (s.length == 0) return null;
    if (s.ptr[0] != ';') break;
    s = s[1..$];
  }

  usize pos = 0;

  void skipString () {
    char qch = s.ptr[pos++];
    while (pos < s.length) {
      if (s.ptr[pos] == qch) { ++pos; break; }
      if (s.ptr[pos++] == '\\') {
        if (pos < s.length) {
          if (s.ptr[pos] == 'x' || s.ptr[pos] == 'X') pos += 2; else ++pos;
        }
      }
    }
  }

  void skipLine () {
    while (pos < s.length) {
      if (s.ptr[pos] == '"' || s.ptr[pos] == '\'') {
        skipString();
      } else if (s.ptr[pos++] == '\n') {
        break;
      }
    }
  }

  if (s.ptr[0] == '#') {
    skipLine();
    if (pos >= s.length) { s = s[$..$]; return null; }
    s = s[pos..$];
    pos = 0;
  }

  while (pos < s.length) {
    if (s.ptr[pos] == '"' || s.ptr[pos] == '\'') {
      skipString();
    } else if (s.ptr[pos] == ';' || s.ptr[pos] == '#' || s.ptr[pos] == '\n') {
      auto res = s[0..pos];
      if (s.ptr[pos] == '#') s = s[pos..$]; else s = s[pos+1..$];
      return res;
    } else {
      ++pos;
    }
  }
  auto res = s[];
  s = s[$..$];
  return res;
}

///
version(contest_cpx) unittest {
  ConString s = "boo; woo \";\" 42#cmt\ntest\nfoo";
  {
    auto c = conGetCommandStr(s);
    conwriteln("[", c, "] : [", s, "]");
  }
  {
    auto c = conGetCommandStr(s);
    conwriteln("[", c, "] : [", s, "]");
  }
  {
    auto c = conGetCommandStr(s);
    conwriteln("[", c, "] : [", s, "]");
  }
  {
    auto c = conGetCommandStr(s);
    conwriteln("[", c, "] : [", s, "]");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// console always has "echo" command, no need to register it.
public class ConCommandEcho : ConCommand {
  this () { super("echo", "write string to console"); }

  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) { conwriteln; return; }
    bool needSpace = false;
    for (;;) {
      auto w = getWord(cmdline);
      if (w is null) break;
      if (needSpace) conwrite(" "); else needSpace = true;
      while (w.length) {
        usize pos = 0;
        while (pos < w.length && w.ptr[pos] != '$') ++pos;
        if (w.length-pos > 1 && w.ptr[pos+1] == '$') {
          conwrite(w[0..pos+1]);
          w = w[pos+2..$];
        } else if (w.length-pos <= 1) {
          conwrite(w);
          break;
        } else {
          // variable name
          ConString vname;
          if (pos > 0) conwrite(w[0..pos]);
          ++pos;
          if (w.ptr[pos] == '{') {
            w = w[pos+1..$];
            pos = 0;
            while (pos < w.length && w.ptr[pos] != '}') ++pos;
            vname = w[0..pos];
            if (pos < w.length) ++pos;
            w = w[pos..$];
          } else {
            w = w[pos..$];
            pos = 0;
            while (pos < w.length) {
              char ch = w.ptr[pos];
              if (ch == '_' || (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')) {
                ++pos;
              } else {
                break;
              }
            }
            vname = w[0..pos];
            w = w[pos..$];
          }
          if (vname.length) {
            if (auto cc = vname in cmdlist) {
              if (auto cv = cast(ConVarBase)(*cc)) {
                auto v = cv.strval;
                conwrite(v);
              } else {
                conwrite("${!");
                conwrite(vname);
                conwrite("}");
              }
            } else {
              conwrite("${");
              conwrite(vname);
              conwrite("}");
            }
          }
        }
      }
    }
    conwrite("\n");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// console always has "alias" command, no need to register it.
public class ConCommandAlias : ConCommand {
  this () { super("alias", "set or remove alias"); }

  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) { conwriteln("alias what?"); return; }

    auto name = getWord(cmdline);
    if (name is null || name.length == 0) { conwriteln("alias what?"); return; }
    if (name.length > 128) { conwriteln("alias name too long: ", name); return; }

    char[129] nbuf = void;
    nbuf[0..name.length] = name;
    const(char)[] xname = nbuf[0..name.length];

    // alias value
    auto v = getWord(cmdline);
    while (v.length && v[0] <= ' ') v = v[1..$];
    while (v.length && v[$-1] <= ' ') v = v[0..$-1];

    if (hasArgs(cmdline)) { conwriteln("too many arguments to `alias` command"); return; }

    if (auto cp = xname in cmdlist) {
      // existing alias?
      auto ali = cast(ConAlias)(*cp);
      if (ali is null) { conwriteln("can't change existing command/var to alias: ", xname); return; }
      if (v.length == 0) {
        // remove
        cmdlist.remove(cast(string)xname); // it is safe to cast here
        foreach (immutable idx, string n; cmdlistSorted) {
          if (n == xname) {
            foreach (immutable c; idx+1..cmdlistSorted.length) cmdlistSorted[c-1] = cmdlistSorted[c];
            break;
          }
        }
      } else {
        // change
        ali.set(v);
      }
      return;
    } else {
      // new alias
      auto ali = new ConAlias(v);
      //conwriteln(xname, ": <", ali.get, ">");
      string sname = xname.idup;
      addName(sname);
      cmdlist[sname] = ali;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// create "user console variable"
ConVarBase conRegUserVar(T) (string aname, string help, const(ConVarAttr)[] attrs...) {
  if (aname.length == 0) return null;
  ConVarBase v;
  static if (is(T : long) || is(T : double)) {
    T* var = new T;
    v = new ConVar!T(var, aname, help);
  } else static if (is(T : const(char)[])) {
    T[] var;
    var.length = 1;
    v = new ConVar!T(&var[0], aname, help);
  } else {
    static assert(0, "can't create uservar of type '"~T.stringof~"'");
  }
  v.setAttrs(attrs);
  v.mAttrs |= ConVarAttr.User;
  addName(aname);
  cmdlist[aname] = v;
  return v;
}


/// create bounded "user console variable"
ConVarBase conRegUserVar(T) (T amin, T amax, string aname, string help, const(ConVarAttr)[] attrs...) if (is(T : long) || is(T : double)) {
  if (aname.length == 0) return null;
  ConVarBase v;
  static if (is(T : long) || is(T : double)) {
    T* var = new T;
    v = new ConVar!T(var, amin, amax, aname, help);
  } else static if (is(T : const(char)[])) {
    T[] var;
    var.length = 1;
    v = new ConVar!T(&var[0], aname, help);
  } else {
    static assert(0, "can't create uservar of type '"~T.stringof~"'");
  }
  c.setAttrs(attrs);
  v.mAttrs |= ConVarAttr.User;
  addName(aname);
  cmdlist[aname] = v;
  return v;
}


// ////////////////////////////////////////////////////////////////////////// //
// console always has "userconvar" command, no need to register it.
public class ConCommandUserConVar : ConCommand {
  this () { super("userconvar", "create user convar: userconvar \"<type> <name>\"; type is <int|str|bool|float|double>"); }

  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) return;
    auto type = getWord(cmdline);
    auto name = getWord(cmdline);
    if (type.length == 0 || name.length == 0) return;
    if (name in cmdlist) { conwriteln("console variable '", name, "' already exists"); return; }
    ConVarBase v;
    string aname = name.idup;
    switch (type) {
      case "int":
        int* var = new int;
        v = new ConVar!int(var, aname, null);
        break;
      case "str":
        //string* var = new string; // alas
        string[] var;
        var.length = 1;
        v = new ConVar!string(&var[0], aname, null);
        break;
      case "bool":
        bool* var = new bool;
        v = new ConVar!bool(var, aname, null);
        break;
      case "float":
        float* var = new float;
        v = new ConVar!float(var, aname, null);
        break;
      case "double":
        double* var = new double;
        v = new ConVar!double(var, aname, null);
        break;
      default:
        conwriteln("can't create console variable '", name, "' of unknown type '", type, "'");
        return;
    }
    v.setAttrs!true(ConVarAttr.User);
    addName(aname);
    cmdlist[aname] = v;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// console always has "killuserconvar" command, no need to register it.
public class ConCommandKillUserConVar : ConCommand {
  this () { super("killuserconvar", "remove user convar: killuserconvar \"<name>\""); }

  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) return;
    auto name = getWord(cmdline);
    if (name.length == 0) return;
    if (auto vp = name in cmdlist) {
      if (auto var = cast(ConVarBase)(*vp)) {
        if (!var.attrUser) {
          conwriteln("console command '", name, "' is not a uservar");
          return;
        }
        // remove it
        cmdlist.remove(cast(string)name); // it is safe to cast here
        foreach (immutable idx, string n; cmdlistSorted) {
          if (n == name) {
            foreach (immutable c; idx+1..cmdlistSorted.length) cmdlistSorted[c-1] = cmdlistSorted[c];
            return;
          }
        }
      } else {
        conwriteln("console command '", name, "' is not a var");
        return;
      }
    } else {
      conwriteln("console variable '", name, "' doesn't exist");
      return;
    }
  }
}


shared static this () {
  addName("echo");
  cmdlist["echo"] = new ConCommandEcho();
  addName("alias");
  cmdlist["alias"] = new ConCommandAlias();
  addName("userconvar");
  cmdlist["userconvar"] = new ConCommandUserConVar();
  addName("killuserconvar");
  cmdlist["killuserconvar"] = new ConCommandKillUserConVar();
}


/** replace "$var" in string.
 *
 * this function will replace "$var" in string with console var values.
 *
 * Params:
 *   dest = destination buffer
 *   s = source string
 */
public char[] conFormatStr (char[] dest, ConString s) {
  usize dpos = 0;

  void put (ConString ss) {
    if (ss.length == 0) return;
    auto len = ss.length;
    if (dest.length-dpos < len) len = dest.length-dpos;
    if (len) {
      dest[dpos..dpos+len] = ss[];
      dpos += len;
    }
  }

  while (s.length) {
    usize pos = 0;
    while (pos < s.length && s.ptr[pos] != '$') ++pos;
    if (s.length-pos > 1 && s.ptr[pos+1] == '$') {
      put(s[0..pos+1]);
      s = s[pos+2..$];
    } else if (s.length-pos <= 1) {
      put(s);
      break;
    } else {
      // variable name
      ConString vname;
      if (pos > 0) put(s[0..pos]);
      ++pos;
      if (s.ptr[pos] == '{') {
        s = s[pos+1..$];
        pos = 0;
        while (pos < s.length && s.ptr[pos] != '}') ++pos;
        vname = s[0..pos];
        if (pos < s.length) ++pos;
        s = s[pos..$];
      } else {
        s = s[pos..$];
        pos = 0;
        while (pos < s.length) {
          char ch = s.ptr[pos];
          if (ch == '_' || (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')) {
            ++pos;
          } else {
            break;
          }
        }
        vname = s[0..pos];
        s = s[pos..$];
      }
      if (vname.length) {
        if (auto cc = vname in cmdlist) {
          if (auto cv = cast(ConVarBase)(*cc)) {
            auto v = cv.strval;
            put(v);
          } else {
            put("${!");
            put(vname);
            put("}");
          }
        } else {
          put("${");
          put(vname);
          put("}");
        }
      }
    }
  }
  return dest[0..dpos];
}


///
version(contest_echo) unittest {
  __gshared int vi = 42;
  __gshared string vs = "str";
  __gshared bool vb = true;
  conRegVar!vi("vi", "int var");
  conRegVar!vs("vs", "string var");
  conRegVar!vb("vb", "bool var");
  conRegVar!vb("r_interpolation", "bool var");
  conwriteln("=================");
  conExecute("r_interpolation");
  conExecute("echo ?");
  conExecute("echo vs=$vs,  vi=${vi},  vb=${vb}!");
  {
    char[44] buf;
    auto s = buf.conFormatStr("vs=$vs,  vi=${vi},  vb=${vb}!");
    conwriteln("[", s, "]");
    foreach (/*auto*/ kv; cmdlist.byKeyValue) conwriteln(" ", kv.key);
    assert("r_interpolation" in cmdlist);
    s = buf.conFormatStr("Interpolation: $r_interpolation");
    conwriteln("[", s, "]");
  }
  conwriteln("vi=", conGetVar!int("vi"));
  conwriteln("vi=", conGetVar("vi"));
  conwriteln("vs=", conGetVar("vi"));
  conwriteln("vb=", conGetVar!int("vb"));
  conwriteln("vb=", conGetVar!bool("vb"));
  conwriteln("vb=", conGetVar("vb"));
}


///
version(contest_cmdlist) unittest {
  {
    auto cl = conByCommand;
    conwriteln("=== all ===");
    while (!cl.empty) {
           if (cl.frontIsVar) conwrite("VAR  ");
      else if (cl.frontIsFunc) conwrite("FUNC ");
      else conwrite("UNK  ");
      conwriteln("[", cl.front, "]");
      cl.popFront();
    }
  }

  conwriteln("=== funcs ===");
  foreach (/*auto*/ clx; conByCommand!"funcs") conwriteln("  [", clx, "]");

  conwriteln("=== vars ===");
  foreach (/*auto*/ clx; conByCommand!"vars") conwriteln("  [", clx, "]");
}


shared static this () {
  conRegFunc!(() {
    uint maxlen = 0;
    foreach (string name; cmdlistSorted[]) {
      if (auto ccp = name in cmdlist) {
        if (name.length > 64) {
          if (maxlen < 64) maxlen = 64;
        } else {
          if (name.length > maxlen) maxlen = cast(uint)name.length;
        }
      }
    }
    foreach (string name; cmdlistSorted[]) {
      if (auto ccp = name in cmdlist) {
        conwrite(name);
        foreach (immutable _; name.length..maxlen) conwrite(" ");
        if (auto cmd = cast(ConCommand)(*ccp)) {
          conwriteln(" -- ", cmd.help);
        } else {
          conwriteln(" -- alias");
        }
      }
    }
  })("cmdlist", "list all known commands and variables");
}


// ////////////////////////////////////////////////////////////////////////// //
// simple input buffer for console
private:
__gshared char[4096] concli = 0;
__gshared uint conclilen = 0;
__gshared int concurx = 0;
public __gshared void delegate () nothrow @trusted conInputChangedCB; /// can be called in any thread

shared uint inchangeCount = 1;
public @property uint conInputLastChange () nothrow @trusted @nogc { pragma(inline, true); import core.atomic; return atomicLoad(inchangeCount); } /// changed when something was put to console input buffer (thread-safe)
public void conInputIncLastChange () nothrow @trusted { pragma(inline, true); import core.atomic; atomicOp!"+="(inchangeCount, 1); if (conInputChangedCB !is null) conInputChangedCB(); } /// increment console input buffer change flag (thread-safe)

public @property ConString conInputBuffer() () @trusted { pragma(inline, true); return concli[0..conclilen]; } /// returns console input buffer (not thread-safe)
public @property int conInputBufferCurX() () @trusted { pragma(inline, true); return concurx; } /// returns cursor position in input buffer: [0..conclilen] (not thread-safe)


/** clear console input buffer. (not thread-safe)
 *
 * call this function with `addToHistory:true` to add current input buffer to history.
 * it is safe to call this for empty input buffer, history won't get empty line.
 *
 * Params:
 *   addToHistory = true if current buffer should be "added to history", so current history index should be reset and history will be updated
 */
public void conInputBufferClear() (bool addToHistory=false) @trusted {
  if (conclilen > 0) {
    if (addToHistory) conHistoryAdd(conInputBuffer);
    conclilen = 0;
    concurx = 0;
    conInputIncLastChange();
  }
  if (addToHistory) conhisidx = -1;
}


private struct ConHistItem {
  char* dbuf; // without trailing 0
  char[256] sbuf = 0; // static buffer
  uint len; // of dbuf or sbuf, without trailing 0
  uint alloted; // !0: `dbuf` is used
nothrow @trusted @nogc:
  void releaseMemory () { import core.stdc.stdlib : free; if (dbuf !is null) free(dbuf); dbuf = null; alloted = len = 0; }
  @property const(char)[] str () { pragma(inline, true); return (alloted ? dbuf : sbuf.ptr)[0..len]; }
  @property void str (const(char)[] s) {
    import core.stdc.stdlib : malloc, realloc;
    if (s.length > 65536) s = s[0..65536]; // just in case
    if (s.length == 0) { len = 0; return; }
    // try to put in allocated space
    if (alloted) {
      if (s.length > alloted) {
        auto np = cast(char*)realloc(dbuf, s.length);
        if (np is null) {
          // can't allocate memory
          dbuf[0..alloted] = s[0..alloted];
          len = alloted;
          return;
        }
        alloted = cast(uint)s.length;
      }
      // it fits!
      dbuf[0..s.length] = s[];
      len = cast(uint)s.length;
      return;
    }
    // fit in static buf?
    if (s.length <= sbuf.length) {
      sbuf.ptr[0..s.length] = s[];
      len = cast(uint)s.length;
      return;
    }
    // allocate dynamic buffer
    dbuf = cast(char*)malloc(s.length);
    if (dbuf is null) {
      // alas; trim and use static one
      sbuf[] = s[0..sbuf.length];
      len = cast(uint)sbuf.length;
    } else {
      // ok, use dynamic buffer
      alloted = len = cast(uint)s.length;
      dbuf[0..len] = s[];
    }
  }
}


//TODO: make circular buffer
private enum ConHistMax = 8192;
__gshared ConHistItem* concmdhistory = null;
__gshared int conhisidx = -1;
__gshared uint conhismax = 128;
__gshared uint conhisused = 0;
__gshared uint conhisalloted = 0;


shared static this () {
  conRegVar!conhismax(1, ConHistMax, "r_conhistmax", "maximum commands in console input history");
}


// free unused slots if `conhismax` was changed
private void conHistShrinkBuf () {
  import core.stdc.stdlib : realloc;
  import core.stdc.string : memmove, memset;
  if (conhisalloted <= conhismax) return;
  auto tokill = conhisalloted-conhismax;
  debug(concmd_history) conwriteln("removing ", tokill, " items out of ", conhisalloted);
  // discard old items
  if (conhisused > conhismax) {
    auto todis = conhisused-conhismax;
    debug(concmd_history) conwriteln("discarding ", todis, " items out of ", conhisused);
    // free used memory
    foreach (ref ConHistItem it; concmdhistory[0..todis]) it.releaseMemory();
    // move array elements
    memmove(concmdhistory, concmdhistory+todis, ConHistItem.sizeof*conhismax);
    // clear what is left
    memset(concmdhistory+conhismax, 0, ConHistItem.sizeof*todis);
    conhisused = conhismax;
  }
  // resize array
  auto np = cast(ConHistItem*)realloc(concmdhistory, ConHistItem.sizeof*conhismax);
  if (np !is null) concmdhistory = np;
  conhisalloted = conhismax;
}


// allocate space for new command, return it's index or -1 on error
private int conHistAllot () {
  import core.stdc.stdlib : realloc;
  import core.stdc.string : memmove, memset;
  conHistShrinkBuf(); // shrink buffer, if necessary
  if (conhisused >= conhisalloted && conhisused < conhismax) {
    // we need more!
    uint newsz = conhisalloted+64;
    if (newsz > conhismax) newsz = conhismax;
    debug(concmd_history) conwriteln("adding ", newsz-conhisalloted, " items (now: ", conhisalloted, ")");
    auto np = cast(ConHistItem*)realloc(concmdhistory, ConHistItem.sizeof*newsz);
    if (np !is null) {
      // yay! we did it!
      concmdhistory = np;
      // clear new items
      memset(concmdhistory+conhisalloted, 0, ConHistItem.sizeof*(newsz-conhisalloted));
      conhisalloted = newsz; // fix it! ;-)
      return conhisused++;
    }
    // alas, have to move
  }
  if (conhisalloted == 0) return -1; // no memory
  if (conhisalloted == 1) { conhisused = 1; return 0; } // always
  assert(conhisused <= conhisalloted);
  if (conhisused == conhisalloted) {
    ConHistItem tmp = concmdhistory[0];
    // move items up
    --conhisused;
    memmove(concmdhistory, concmdhistory+1, ConHistItem.sizeof*conhisused);
    //memset(concmdhistory+conhisused, 0, ConHistItem.sizeof);
    memmove(concmdhistory+conhisused, &tmp, ConHistItem.sizeof);
  }
  return conhisused++;
}


/// returns input buffer history item (0 is oldest) or null if there are no more items (not thread-safe)
public ConString conHistoryAt (int idx) {
  if (idx < 0 || idx >= conhisused) return null;
  return concmdhistory[conhisused-idx-1].str;
}


/// find command in input history, return index or -1 (not thread-safe)
public int conHistoryFind (ConString cmd) {
  while (cmd.length && cmd[0] <= 32) cmd = cmd[1..$];
  while (cmd.length && cmd[$-1] <= 32) cmd = cmd[0..$-1];
  if (cmd.length == 0) return -1;
  foreach (int idx; 0..conhisused) {
    auto c = concmdhistory[idx].str;
    while (c.length > 0 && c[0] <= 32) c = c[1..$];
    while (c.length > 0 && c[$-1] <= 32) c = c[0..$-1];
    if (c == cmd) return conhisused-idx-1;
  }
  return -1;
}


/// add command to history. will take care about duplicate commands. (not thread-safe)
public void conHistoryAdd (ConString cmd) {
  import core.stdc.string : memmove, memset;
  auto orgcmd = cmd;
  while (cmd.length && cmd[0] <= 32) cmd = cmd[1..$];
  while (cmd.length && cmd[$-1] <= 32) cmd = cmd[0..$-1];
  if (cmd.length == 0) return;
  auto idx = conHistoryFind(cmd);
  if (idx >= 0) {
    debug(concmd_history) conwriteln("command found! idx=", idx, "; real idx=", conhisused-idx-1, "; used=", conhisused);
    idx = conhisused-idx-1; // fix index
    // move command to bottom
    if (idx == conhisused-1) return; // nothing to do
    // cheatmove! ;-)
    ConHistItem tmp = concmdhistory[idx];
    // move items up
    memmove(concmdhistory+idx, concmdhistory+idx+1, ConHistItem.sizeof*(conhisused-idx-1));
    //memset(concmdhistory+conhisused, 0, ConHistItem.sizeof);
    memmove(concmdhistory+conhisused-1, &tmp, ConHistItem.sizeof);
  } else {
    // new command
    idx = conHistAllot();
    if (idx < 0) return; // alas
    concmdhistory[idx].str = orgcmd;
  }
}


/// special characters for `conAddInputChar()`
public enum ConInputChar : char {
  Up = '\x01', ///
  Down = '\x02', ///
  Left = '\x03', ///
  Right = '\x04', ///
  Home = '\x05', ///
  End = '\x06', ///
  PageUp = '\x07', ///
  Backspace = '\x08', ///
  Tab = '\x09', ///
  // 0a
  PageDown = '\x0b', ///
  Delete = '\x0c', ///
  Enter = '\x0d', ///
  Insert = '\x0e', ///
  //
  CtrlY = '\x19', ///
  LineUp = '\x1a', ///
  LineDown = '\x1b', ///
  CtrlW = '\x1c', ///
}


/// process console input char (won't execute commands, but will do autocompletion and history) (not thread-safe)
public void conAddInputChar (char ch) {
  __gshared int prevWasEmptyAndTab = 0;

  bool insChars (const(char)[] s...) {
    if (s.length == 0) return false;
    if (concli.length-conclilen < s.length) return false;
    foreach (char ch; s) {
      if (concurx == conclilen) {
        concli.ptr[conclilen++] = ch;
        ++concurx;
      } else {
        import core.stdc.string : memmove;
        memmove(concli.ptr+concurx+1, concli.ptr+concurx, conclilen-concurx);
        concli.ptr[concurx++] = ch;
        ++conclilen;
      }
    }
    return true;
  }

  // autocomplete
  if (ch == ConInputChar.Tab) {
    if (concurx == 0) {
      if (++prevWasEmptyAndTab < 2) return;
    } else {
      prevWasEmptyAndTab = 0;
    }
    if (concurx > 0) {
      // if there are space(s) before cursor position, this is argument completion
      bool doArgAC = false;
      {
        int p = concurx;
        while (p > 0 && concli.ptr[p-1] > ' ') --p;
        doArgAC = (p > 0);
      }
      if (doArgAC) {
        prevWasEmptyAndTab = 0;
        // yeah, arguments; first, get command name
        int stp = 0;
        while (stp < concurx && concli.ptr[stp] <= ' ') ++stp;
        if (stp >= concurx) return; // alas
        auto ste = stp+1;
        while (ste < concurx && concli.ptr[ste] > ' ') ++ste;
        if (auto cp = concli[stp..ste] in cmdlist) {
          if (auto cmd = cast(ConCommand)(*cp)) {
            if (cmd.argcomplete !is null) try { cmd.argcomplete(cmd); } catch (Exception) {} // sorry
          }
        }
        return;
      }
      string minPfx = null;
      // find longest command
      foreach (/*auto*/ name; conByCommand) {
        if (name.length >= concurx && name.length > minPfx.length && name[0..concurx] == concli[0..concurx]) minPfx = name;
      }
      string longestCmd = minPfx;
      //conwriteln("longest command: [", minPfx, "]");
      // find longest prefix
      foreach (/*auto*/ name; conByCommand) {
        if (name.length < concurx) continue;
        if (name[0..concurx] != concli[0..concurx]) continue;
        usize pos = 0;
        while (pos < name.length && pos < minPfx.length && minPfx.ptr[pos] == name.ptr[pos]) ++pos;
        if (pos < minPfx.length) minPfx = minPfx[0..pos];
      }
      if (minPfx.length > concli.length) minPfx = minPfx[0..concli.length];
      //conwriteln("longest prefix : [", minPfx, "]");
      if (minPfx.length >= concurx) {
        // wow! has something to add
        bool doRet = (minPfx.length > concurx);
        if (insChars(minPfx[concurx..$])) {
          // insert space after complete command
          if (longestCmd.length == minPfx.length && conHasCommand(minPfx)) {
            if (concurx >= conclilen || concli.ptr[concurx] > ' ') {
              doRet = insChars(' ');
            } else {
              ++concurx;
              doRet = true;
            }
          }
          conInputIncLastChange();
          if (doRet) return;
        }
      }
    }
    // nope, print all available commands
    bool needDelimiter = true;
    foreach (/*auto*/ name; conByCommand) {
      if (name.length == 0) continue;
      if (concurx > 0) {
        if (name.length < concurx) continue;
        if (name[0..concurx] != concli[0..concurx]) continue;
      } else {
        // skip "unusal" commands"
        ch = name[0];
        if (!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_')) continue;
      }
      if (needDelimiter) { conwriteln("----------------"); needDelimiter = false; }
      conwriteln(name);
    }
    return;
  }
  // process other keys
  prevWasEmptyAndTab = 0;
  // remove last char
  if (ch == ConInputChar.Backspace) {
    if (concurx > 0) {
      if (concurx < conclilen) {
        import core.stdc.string : memmove;
        memmove(concli.ptr+concurx-1, concli.ptr+concurx, conclilen-concurx);
      }
      --concurx;
      --conclilen;
      conInputIncLastChange();
    }
    return;
  }
  // delete char
  if (ch == ConInputChar.Delete) {
    if (concurx < conclilen) {
      if (conclilen > 1) {
        import core.stdc.string : memmove;
        memmove(concli.ptr+concurx, concli.ptr+concurx+1, conclilen-concurx-1);
      }
      --conclilen;
      conInputIncLastChange();
    }
    return;
  }
  // ^W (delete previous word)
  if (ch == ConInputChar.CtrlW) {
    if (concurx > 0) {
      int stp = concurx;
      // skip spaces
      while (stp > 0 && concli.ptr[stp-1] <= ' ') --stp;
      // skip non-spaces
      while (stp > 0 && concli.ptr[stp-1] > ' ') --stp;
      if (stp < concurx) {
        import core.stdc.string : memmove;
        // delete from stp to concurx
        int dlen = concurx-stp;
        assert(concurx <= conclilen);
        if (concurx < conclilen) memmove(concli.ptr+stp, concli.ptr+concurx, conclilen-concurx);
        conclilen -= dlen;
        concurx = stp;
        conInputIncLastChange();
      }
    }
    return;
  }
  // ^Y (delete line)
  if (ch == ConInputChar.CtrlY) {
    if (conclilen > 0) { conclilen = 0; concurx = 0; conInputIncLastChange(); }
    return;
  }
  // home
  if (ch == ConInputChar.Home) {
    if (concurx > 0) {
      concurx = 0;
      conInputIncLastChange();
    }
    return;
  }
  // end
  if (ch == ConInputChar.End) {
    if (concurx < conclilen) {
      concurx = conclilen;
      conInputIncLastChange();
    }
    return;
  }
  // up
  if (ch == ConInputChar.Up) {
    ++conhisidx;
    auto cmd = conHistoryAt(conhisidx);
    if (cmd.length == 0) {
      --conhisidx;
    } else {
      concli[0..cmd.length] = cmd[];
      conclilen = cast(uint)cmd.length;
      concurx = conclilen;
      conInputIncLastChange();
    }
    return;
  }
  // down
  if (ch == ConInputChar.Down) {
    --conhisidx;
    auto cmd = conHistoryAt(conhisidx);
    if (cmd.length == 0 && conhisidx < -1) {
      ++conhisidx;
    } else {
      concli[0..cmd.length] = cmd[];
      conclilen = cast(uint)cmd.length;
      concurx = conclilen;
      conInputIncLastChange();
    }
    return;
  }
  // left
  if (ch == ConInputChar.Left) {
    if (concurx > 0) {
      --concurx;
      conInputIncLastChange();
    }
    return;
  }
  // right
  if (ch == ConInputChar.Right) {
    if (concurx < conclilen) {
      ++concurx;
      conInputIncLastChange();
    }
    return;
  }
  // other
  if (ch < ' ' || ch > 127) return;
  if (insChars(ch)) conInputIncLastChange();
}


// ////////////////////////////////////////////////////////////////////////// //
private:

/// add console command to execution queue (thread-safe)
public void concmd (ConString cmd) {
  consoleLock();
  scope(exit) { consoleUnlock(); conInputIncLastChange(); }
  concmdAdd(cmd);
}


/// add console command to execution queue (thread-safe)
/// this understands '%s' and '%q' (quoted string, but without surroinding quotes)
/// it also understands '$var', '${var}', '${var:ifabsent}', '${var?ifempty}'
/// var substitution in quotes will be automatically quoted
/// string substitution in quotes will be automatically quoted
public void concmdf(string fmt, A...) (A args) { concmdfdg(fmt, null, args); }


/// add console command to execution queue (thread-safe)
/// this understands '%s' and '%q' (quoted string, but without surroinding quotes)
/// it also understands '$var', '${var}', '${var:ifabsent}', '${var?ifempty}'
/// var substitution in quotes will be automatically quoted
/// string substitution in quotes will be automatically quoted
public void concmdfdg(A...) (ConString fmt, scope void delegate (ConString cmd) cmddg, A args) {
  consoleLock();
  scope(exit) { consoleUnlock(); conInputIncLastChange(); }

  auto fmtanchor = fmt;
  usize pos = 0;
  bool ensureCmd = true;
  char inQ = 0;

  usize stpos = usize.max;

  void puts(bool quote=false) (const(char)[] s...) {
    if (s.length) {
      if (ensureCmd) { concmdEnsureNewCommand(); ensureCmd = false; }
      if (stpos == usize.max) stpos = concmdbufpos;
      static if (quote) {
        char[8] buf;
        foreach (immutable idx, char ch; s) {
          if (ch < ' ' || ch == 127 || ch == '#' || ch == '"' || ch == '\\') {
            import core.stdc.stdio : snprintf;
            auto len = snprintf(buf.ptr, buf.length, "\\x%02x", cast(uint)ch);
            concmdAdd!false(buf[0..len]);
          } else {
            concmdAdd!false(s[idx..idx+1]);
          }
        }
      } else {
        concmdAdd!false(s);
      }
    }
  }

  void putint(TT) (TT nn) {
    char[32] buf = ' ';

    static if (is(TT == shared)) {
      import core.atomic;
      alias T = XUQQ!TT;
      T n = atomicLoad(nn);
    } else {
      alias T = XUQQ!TT;
      T n = nn;
    }

    static if (is(T == long)) {
      if (n == 0x8000_0000_0000_0000uL) { puts("-9223372036854775808"); return; }
    } else static if (is(T == int)) {
      if (n == 0x8000_0000u) { puts("-2147483648"); return; }
    } else static if (is(T == short)) {
      if ((n&0xffff) == 0x8000u) { puts("-32768"); return; }
    } else static if (is(T == byte)) {
      if ((n&0xff) == 0x80u) { puts("-128"); return; }
    }

    static if (__traits(isUnsigned, T)) {
      enum neg = false;
    } else {
      bool neg = (n < 0);
      if (neg) n = -(n);
    }

    int bpos = buf.length;
    do {
      //if (bpos == 0) assert(0, "internal printer error");
      buf.ptr[--bpos] = cast(char)('0'+n%10);
      n /= 10;
    } while (n != 0);
    if (neg) {
      //if (bpos == 0) assert(0, "internal printer error");
      buf.ptr[--bpos] = '-';
    }
    puts(buf[bpos..$]);
  }

  void putfloat(TT) (TT nn) {
    import core.stdc.stdlib : malloc, realloc;

    static if (is(TT == shared)) {
      import core.atomic;
      alias T = XUQQ!TT;
      T n = atomicLoad(nn);
    } else {
      alias T = XUQQ!TT;
      T n = nn;
    }

    static char* buf;
    static usize buflen = 0;

    if (buf is null) {
      buflen = 256;
      buf = cast(char*)malloc(buflen);
      if (buf is null) assert(0, "out of memory");
    }

    for (;;) {
      import core.stdc.stdio : snprintf;
      auto plen = snprintf(buf, buflen, "%g", cast(double)n);
      if (plen >= buflen) {
        buflen = plen+2;
        buf = cast(char*)realloc(buf, buflen);
        if (buf is null) assert(0, "out of memory");
      } else {
        puts(buf[0..plen]);
        return;
      }
    }
  }

  static bool isGoodIdChar (char ch) pure nothrow @safe @nogc {
    pragma(inline, true);
    return
      (ch >= '0' && ch <= '9') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_';
  }

  void processUntilFSp () {
    while (pos < fmt.length) {
      usize epos = pos;
      while (epos < fmt.length && fmt[epos] != '%') {
        if (fmt[epos] == '\\' && fmt.length-epos > 1 /*&& (fmt[epos+1] == '"' || fmt[epos+1] == '$')*/) {
          puts(fmt[pos..epos]);
          puts(fmt[epos+1]);
          pos = (epos += 2);
          continue;
        }
        if (inQ && fmt[epos] == inQ) inQ = 0;
        if (fmt[epos] == '"') {
          inQ = '"';
        } else if (fmt[epos] == '$') {
          puts(fmt[pos..epos]);
          pos = epos;
          if (fmt.length-epos > 0 && fmt[epos+1] != '{') {
            // simple
            ++epos;
            while (epos < fmt.length && isGoodIdChar(fmt[epos])) ++epos;
            if (epos-pos > 1) {
              if (auto cc = fmt[pos+1..epos] in cmdlist) {
                if (auto cv = cast(ConVarBase)(*cc)) {
                  if (inQ) puts!true(cv.strval); else puts!false(cv.strval);
                  pos = epos;
                  continue;
                }
              }
            }
            // go on
          } else {
            // complex
            epos += 2;
            //FIXME: allow escaping of '}'
            while (epos < fmt.length && fmt[epos] != '}') ++epos;
            if (epos >= fmt.length) { epos = pos+1; continue; } // no '}'
            pos += 2;
            usize cpos = pos;
            while (cpos < epos && fmt[cpos] != ':' && fmt[cpos] != '?') ++cpos;
            if (auto cc = fmt[pos..cpos] in cmdlist) {
              if (auto cv = cast(ConVarBase)(*cc)) {
                auto sv = cv.strval;
                // process replacement value for empty strings
                if (cpos < epos && fmt[cpos] == '?' && sv.length == 0) {
                  if (inQ) puts!true(fmt[cpos+1..epos]); else puts!false(fmt[cpos+1..epos]);
                } else {
                  if (inQ) puts!true(sv); else puts!false(sv);
                }
                pos = epos+1;
                continue;
              }
            }
            // either no such command, or it's not a var
            if (cpos < epos && (fmt[cpos] == '?' || fmt[cpos] == ':')) {
              if (inQ) puts!true(fmt[cpos+1..epos]); else puts!false(fmt[cpos+1..epos]);
            }
            pos = epos+1;
            continue;
          }
        }
        ++epos;
      }
      if (epos > pos) {
        puts(fmt[pos..epos]);
        pos = epos;
        if (pos >= fmt.length) break;
      }
      if (fmt.length-pos < 2 || fmt[pos+1] == '%') { puts('%'); pos += 2; continue; }
      break;
    }
  }

  foreach (immutable argnum, /*auto*/ att; A) {
    processUntilFSp();
    if (pos >= fmt.length) assert(0, "out of format specifiers for arguments");
    assert(fmt[pos] == '%');
    ++pos;
    if (pos >= fmt.length) assert(0, "out of format specifiers for arguments");
    alias at = XUQQ!att;
    bool doQuote = false;
    switch (fmt[pos++]) {
      case 'q':
        static if (is(at == char)) {
          puts!true(args[argnum]);
        } else static if (is(at == wchar) || is(at == dchar)) {
          import std.conv : to;
          puts!true(to!string(args[argnum]));
        } else static if (is(at == bool)) {
          putsq(args[argnum] ? "true" : "false");
        } else static if (is(at == enum)) {
          bool dumpNum = true;
          foreach (string mname; __traits(allMembers, at)) {
            if (args[argnum] == __traits(getMember, at, mname)) {
              puts(mname);
              dumpNum = false;
              break;
            }
          }
          //FIXME: check sign
          if (dumpNum) putint!long(cast(long)args[argnum]);
        } else static if (is(at == float) || is(at == double) || is(at == real)) {
          putfloat(args[argnum]);
        } else static if (is(at : const(char)[])) {
          puts!true(args[argnum]);
        } else static if (is(at : T*, T)) {
          assert(0, "can't put pointers");
        } else {
          import std.conv : to;
          puts!true(to!string(args[argnum]));
        }
        break;
      case 's':
      case 'd': // oops
      case 'u': // oops
        if (inQ) goto case 'q';
        static if (is(at == char)) {
          puts(args[argnum]);
        } else static if (is(at == wchar) || is(at == dchar)) {
          import std.conv : to;
          puts(to!string(args[argnum]));
        } else static if (is(at == bool)) {
          puts(args[argnum] ? "true" : "false");
        } else static if (is(at == enum)) {
          bool dumpNum = true;
          foreach (string mname; __traits(allMembers, at)) {
            if (args[argnum] == __traits(getMember, at, mname)) {
              puts(mname);
              dumpNum = false;
              break;
            }
          }
          //FIXME: check sign
          if (dumpNum) putint!long(cast(long)args[argnum]);
        } else static if (is(at == float) || is(at == double) || is(at == real)) {
          putfloat(args[argnum]);
        } else static if (is(at : const(char)[])) {
          puts(args[argnum]);
        } else static if (is(at : T*, T)) {
          assert(0, "can't put pointers");
        } else {
          import std.conv : to;
          puts(to!string(args[argnum]));
        }
        break;
      default:
        assert(0, "invalid format specifier");
    }
  }

  while (pos < fmt.length) {
    processUntilFSp();
    if (pos >= fmt.length) break;
    assert(0, "out of args for format specifier");
  }

  //conwriteln(concmdbuf[0..concmdbufpos]);
  if (cmddg !is null) {
    if (stpos != usize.max) {
      cmddg(concmdbuf[stpos..concmdbufpos]);
    } else {
      cmddg("");
    }
  }
}


/// get console variable value; doesn't do complex conversions! (thread-safe)
public T convar(T) (ConString s) {
  consoleLock();
  scope(exit) consoleUnlock();
  return conGetVar!T(s);
}

/// set console variable value; doesn't do complex conversions! (thread-safe)
/// WARNING! this is instant action, execution queue and r/o (and other) flags are ignored!
public void convar(T) (ConString s, T val) {
  consoleLock();
  scope(exit) consoleUnlock();
  conSetVar!T(s, val);
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared char[] concmdbuf;
__gshared uint concmdbufpos;
shared static this () { concmdbuf.unsafeArraySetLength(65536); }


private void unsafeArraySetLength(T) (ref T[] arr, int newlen) /*nothrow*/ {
  if (newlen < 0 || newlen >= int.max/2) assert(0, "invalid number of elements in array");
  if (arr.length > newlen) {
    arr.length = newlen;
    arr.assumeSafeAppend;
  } else if (arr.length < newlen) {
    auto optr = arr.ptr;
    arr.length = newlen;
    if (arr.ptr !is optr) {
      import core.memory : GC;
      optr = arr.ptr;
      if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }
}


void concmdPrepend (ConString s) {
  if (s.length == 0) return; // nothing to do
  if (s.length >= int.max/4) assert(0, "console command too long"); //FIXME
  uint reslen = cast(uint)s.length+1;
  uint newlen = concmdbufpos+reslen;
  if (newlen <= concmdbufpos || newlen >= int.max/2-1024) assert(0, "console command too long"); //FIXME
  if (newlen > concmdbuf.length) concmdbuf.unsafeArraySetLength(newlen+512);
  // make room
  if (concmdbufpos > 0) {
    import core.stdc.string : memmove;
    memmove(concmdbuf.ptr+reslen, concmdbuf.ptr, concmdbufpos);
  }
  // put new test and '\n'
  concmdbuf.ptr[0..s.length] = s[];
  concmdbuf.ptr[s.length] = '\n';
  concmdbufpos += reslen;
}


void concmdEnsureNewCommand () {
  if (concmdbufpos > 0 && concmdbuf[concmdbufpos-1] != '\n') {
    if (concmdbuf.length-concmdbufpos < 1) concmdbuf.unsafeArraySetLength(concmdbuf.length+512);
  }
  concmdbuf.ptr[concmdbufpos++] = '\n';
}


package(iv) void concmdAdd(bool ensureNewCommand=true) (ConString s) {
  if (s.length) {
    if (concmdbuf.length-concmdbufpos < s.length+1) {
      concmdbuf.unsafeArraySetLength(cast(int)(concmdbuf.length+s.length-(concmdbuf.length-concmdbufpos)+512));
    }
    static if (ensureNewCommand) {
      if (concmdbufpos > 0 && concmdbuf[concmdbufpos-1] != '\n') concmdbuf.ptr[concmdbufpos++] = '\n';
    }
    concmdbuf[concmdbufpos..concmdbufpos+s.length] = s[];
    concmdbufpos += s.length;
  }
}


/** does console has anything in command queue? (not thread-safe)
 *
 * note that it can be anything, including comment or some blank chars.
 *
 * Returns:
 *   `true` is queue is empty.
 */
public bool conQueueEmpty () {
  return (concmdbufpos == 0);
}


/** execute commands added with `concmd()`. (not thread-safe)
 *
 * all commands added during execution of this function will be postponed for the next call.
 * call this function in your main loop to process all accumulated console commands.
 *
 * WARNING:
 * this is NOT thread-safe! you MUST call this in your "processing thread", and you MUST
 * put `consoleLock()/consoleUnlock()` around the call!
 *
 * Params:
 *   maxlen = maximum queue size to process (0: don't process commands added while processing ;-)
 *
 * Returns:
 *   "has more commands" flag (i.e. some new commands were added to queue)
 */
public bool conProcessQueue (uint maxlen=0) {
  scope(exit) { clearPrependStr(); conHistShrinkBuf(); } // do it here
  if (concmdbufpos == 0) return false;
  bool once = (maxlen == 0);
  for (;;) {
    auto ebuf = concmdbufpos;
    ConString s = concmdbuf[0..ebuf];
    version(iv_cmdcon_debug_wait) conwriteln("** [", s, "]; ebuf=", ebuf);
    while (s.length) {
      auto cmd = conGetCommandStr(s);
      if (cmd is null) break;
      try {
        //consoleLock();
        //scope(exit) consoleUnlock();
        version(iv_cmdcon_debug_wait) conwriteln("** <", cmd, ">");
        if (conExecute(cmd)) {
          // "wait" pseudocommand hit; remove executed part
          //import core.stdc.string : memmove;
          version(iv_cmdcon_debug_wait) conwriteln(" :: rest=<", s, ">");
          version(iv_cmdcon_debug_wait) if (conWaitPrepends) conwriteln("pps: <", prependStr, ">"); // should prepend `ccWaitPrependStr` instead of the whole buffer
          ebuf -= cast(uint)s.length;
          version(iv_cmdcon_debug_wait) conwriteln("<WAIT> HIT! ebuf=", ebuf, "; concmdbufpos=", concmdbufpos);
          //if (leftlen > 0) memmove(concmdbuf.ptr, concmdbuf.ptr+leftlen, ebuf-leftlen);
          //concmdbufpos -= leftlen;
          version(iv_cmdcon_debug_wait) conwriteln("=== BUFFER LEFT ===\n", concmdbuf[ebuf..concmdbufpos], "\n=================");
          once = true;
          break;
        }
        version(iv_cmdcon_debug_wait) conwriteln(" ++++++++++");
      } catch (Exception e) {
        conwriteln("***ERROR: ", e.msg);
      }
    }
    auto pbc = concmdbufpos-ebuf;
    // shift postponed commands
    if (concmdbufpos > ebuf) {
      import core.stdc.string : memmove;
      //consoleLock();
      //scope(exit) consoleUnlock();
      memmove(concmdbuf.ptr, concmdbuf.ptr+ebuf, concmdbufpos-ebuf);
      concmdbufpos -= ebuf;
      //s = concmdbuf[0..concmdbufpos];
      //ebuf = concmdbufpos;
      //return true;
      if (ccWaitPrependStrLen) { concmdPrepend(prependStr); clearPrependStr(); }
    } else {
      concmdbufpos = 0;
      if (ccWaitPrependStrLen) { concmdPrepend(prependStr); clearPrependStr(); }
      break;
    }
    if (once || pbc >= maxlen) break;
    maxlen -= pbc;
  }
  return (concmdbufpos == 0);
}


// ////////////////////////////////////////////////////////////////////////// //
/** process command-line arguments, put 'em to console queue, remove from array (thread-safe).
 *
 * just call this function from `main (string[] args)`, with `args`.
 *
 * console args looks like:
 *  +cmd arg arg +cmd arg arg
 *
 * Params:
 *   immediate = immediately call `conProcessQueue()` with some big limit
 *   args = those arg vector passed to `main()`
 *
 * Returns:
 *   `true` is any command was added to queue.
 */
public bool conProcessArgs(bool immediate=false) (ref string[] args) {
  consoleLock();
  scope(exit) consoleUnlock();

  bool ensureCmd = true;
  auto ocbpos = concmdbufpos;

  void puts (const(char)[] s...) {
    if (s.length) {
      if (ensureCmd) {
        concmdEnsureNewCommand();
        ensureCmd = false;
      } else {
        concmdAdd!false(" "); // argument delimiter
      }
      // check if we need to quote arg
      bool doQuote = false;
      foreach (char ch; s) if (ch <= ' ' || ch == 127 || ch == '"' || ch == '#') { doQuote = true; break; }
      if (doQuote) {
        concmdAdd!false("\"");
        foreach (immutable idx, char ch; s) {
          if (ch < ' ' || ch == 127 || ch == '"' || ch == '\\') {
            import core.stdc.stdio : snprintf;
            char[8] buf = 0;
            auto len = snprintf(buf.ptr, buf.length, "\\x%02x", cast(uint)ch);
            if (len <= 0) assert(0, "concmd: ooooops!");
            concmdAdd!false(buf[0..len]);
          } else {
            concmdAdd!false(s[idx..idx+1]);
          }
        }
        concmdAdd!false("\"");
      } else {
        concmdAdd!false(s);
      }
    }
  }

  static if (immediate) bool res = false;

  usize idx = 1;
  while (idx < args.length) {
    string a = args[idx++];
    if (a.length == 0) continue;
    if (a == "--") break; // no more
    if (a == "++" || a == "+--") {
      // normal parsing, remove this
      --idx;
      foreach (immutable c; idx+1..args.length) args[c-1] = args[c];
      args.length -= 1;
      continue;
    }
    if (a[0] == '+') {
      scope(exit) ensureCmd = true;
      auto xidx = idx-1;
      puts(a[1..$]);
      while (idx < args.length) {
        a = args[idx];
        if (a.length > 0) {
          if (a[0] == '+') break;
          puts(a);
        }
        ++idx;
      }
      foreach (immutable c; idx..args.length) args[xidx+c-idx] = args[c];
      args.length -= idx-xidx;
      idx = xidx;
      // execute it immediately if we're asked to do so
      static if (immediate) {
        if (concmdbufpos > ocbpos) {
          res = true;
          conProcessQueue(256*1024);
          ocbpos = concmdbufpos;
        }
      }
    }
  }

  debug(concmd_procargs) {
    import core.stdc.stdio : snprintf;
    import core.sys.posix.unistd : STDERR_FILENO, write;
    if (concmdbufpos > ocbpos) {
      write(STDERR_FILENO, "===\n".ptr, 4);
      write(STDERR_FILENO, concmdbuf.ptr+ocbpos, concmdbufpos-ocbpos);
      write(STDERR_FILENO, "\n".ptr, 1);
    }
    foreach (immutable aidx, string a; args) {
      char[16] buf;
      auto len = snprintf(buf.ptr, buf.length, "%u: ", cast(uint)aidx);
      write(STDERR_FILENO, buf.ptr, len);
      write(STDERR_FILENO, a.ptr, a.length);
      write(STDERR_FILENO, "\n".ptr, 1);
    }
  }

  static if (immediate) return res; else return (concmdbufpos > ocbpos);
}


// ////////////////////////////////////////////////////////////////////////// //
// "exec" command
static if (__traits(compiles, (){import iv.vfs;}())) {
  enum CmdConHasVFS = true;
  import iv.vfs;
} else {
  enum CmdConHasVFS = false;
  import std.stdio : File;
}
private int xindexof (const(char)[] s, const(char)[] pat, int stpos=0) nothrow @trusted @nogc {
  if (pat.length == 0 || pat.length > s.length) return -1;
  if (stpos < 0) stpos = 0;
  if (s.length > int.max/4) s = s[0..int.max/4];
  while (stpos < s.length) {
    if (s.length-stpos < pat.length) break;
    if (s.ptr[stpos] == pat.ptr[0]) {
      if (s.ptr[stpos..stpos+pat.length] == pat[]) return stpos;
    }
    ++stpos;
  }
  return -1;
}

shared static this () {
  conRegFunc!((ConString fname, bool silent=false) {
    try {
      static if (CmdConHasVFS) {
        auto fl = VFile(fname);
      } else {
        auto fl = File(fname.idup);
      }
      auto sz = fl.size;
      if (sz > 1024*1024*64) throw new Exception("script file too big");
      if (sz > 0) {
        enum AbortCmd = "!!abort!!";
        auto s = new char[](cast(uint)sz);
        static if (CmdConHasVFS) {
          fl.rawReadExact(s);
        } else {
          auto tbuf = s;
          while (tbuf.length) {
            auto rd = fl.rawRead(tbuf);
            if (rd.length == 0) throw new Exception("read error");
            tbuf = tbuf[rd.length..$];
          }
        }
        if (s.xindexof(AbortCmd) >= 0) {
          auto apos = s.xindexof(AbortCmd);
          while (apos >= 0) {
            if (s.length-apos <= AbortCmd.length || s[apos+AbortCmd.length] <= ' ') {
              bool good = true;
              // it should be the first command, not commented
              auto pos = apos;
              while (pos > 0 && s[pos-1] != '\n') {
                if (s[pos-1] != ' ' && s[pos-1] != '\t') { good = false; break; }
                --pos;
              }
              if (good) { s = s[0..apos]; break; }
            }
            // check next
            apos = s.xindexof(AbortCmd, apos+1);
          }
        }
        concmd(s);
      }
    } catch (Exception e) {
      if (!silent) conwriteln("ERROR loading script \"", fname, "\"");
    }
  })("exec", "execute console script (name [silent_failure_flag])");
}
