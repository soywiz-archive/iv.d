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
 * options (must immediately follow '%'):
 *   '~': fill with the following char instead of space
 *        second '~': right filling char for 'center'
 */
module iv.cmdcon /*is aliced*/;
private:


// ////////////////////////////////////////////////////////////////////////// //
/// use this in conGetVar, for example, to avoid allocations
public alias ConString = const(char)[];


// ////////////////////////////////////////////////////////////////////////// //
public enum ConDump : int { None, Stdout, Stderr }
shared ConDump conStdoutFlag = ConDump.Stderr;
public @property ConDump conDump () nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicLoad; return atomicLoad(conStdoutFlag); } /// write console output to ...
public @property void conDump (ConDump v) nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicStore; atomicStore(conStdoutFlag, v); } /// ditto


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
version(test_cbuf)
  enum ConBufSize = 64;
else
  enum ConBufSize = 256*1024;

// each line in buffer ends with '\n'; we don't keep offsets or lengthes, as
// it's fairly easy to search in buffer, and drawing console is not a common
// thing, so it doesn't have to be superfast.
__gshared char[ConBufSize] cbuf = 0;
__gshared int cbufhead, cbuftail; // `cbuftail` points *at* last char
__gshared bool cbufLastWasCR = false;
shared static this () { cbuf.ptr[0] = '\n'; }

shared uint changeCount = 1;
public @property uint cbufLastChange () nothrow @trusted @nogc { import core.atomic; return atomicLoad(changeCount); } /// changed when something was written to console buffer


// ////////////////////////////////////////////////////////////////////////// //
public void consoleLock() () { pragma(inline, true); version(aliced) consoleLocker.lock(); } /// multithread lock
public void consoleUnlock() () { pragma(inline, true); version(aliced) consoleLocker.unlock(); } /// multithread unlock


// ////////////////////////////////////////////////////////////////////////// //
/// put characters to console buffer (and, possibly, STDOUT_FILENO). thread-safe.
public void cbufPut (scope ConString chrs...) nothrow @trusted @nogc {
  if (chrs.length) {
    import core.atomic : atomicLoad, atomicOp;
    consoleLock();
    scope(exit) consoleUnlock();
    final switch (atomicLoad(conStdoutFlag)) {
      case ConDump.None: break;
      case ConDump.Stdout:
        import core.sys.posix.unistd : STDOUT_FILENO, write;
        write(STDOUT_FILENO, chrs.ptr, chrs.length);
        break;
      case ConDump.Stderr:
        import core.sys.posix.unistd : STDERR_FILENO, write;
        write(STDERR_FILENO, chrs.ptr, chrs.length);
        break;
    }
    atomicOp!"+="(changeCount, 1);
    foreach (char ch; chrs) {
      if (cbufLastWasCR && ch == '\x0a') { cbufLastWasCR = false; continue; }
      if ((cbufLastWasCR = (ch == '\x0d')) != false) ch = '\x0a';
      int np = (cbuftail+1)%ConBufSize;
      if (np == cbufhead) {
        // we have to make some room; delete top line for this
        for (;;) {
          char och = cbuf.ptr[cbufhead];
          cbufhead = (cbufhead+1)%ConBufSize;
          if (cbufhead == np || och == '\n') break;
        }
      }
      cbuf.ptr[np] = ch;
      cbuftail = np;
    }
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
    @property auto front () const { pragma(inline, true); return (sp >= 0 ? cbuf.ptr[sp] : '\x00'); }
    @property bool empty () const { pragma(inline, true); return (sp < 0 || h != cbufhead || t != cbuftail); }
    @property auto save () { pragma(inline, true); return Line(h, t, sp, ep); }
    void popFront () { pragma(inline, true); if (sp < 0 || (sp = (sp+1)%ConBufSize) == ep) sp = -1; }
    @property usize opDollar () { pragma(inline, true); return (sp >= 0 ? (sp > ep ? ep+ConBufSize-sp : ep-sp) : 0); }
    alias length = opDollar;
    char opIndex (usize pos) { pragma(inline, true); return (sp >= 0 ? cbuf.ptr[sp+pos] : '\x00'); }
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
        int p = (pos+ConBufSize-1)%ConBufSize;
        if (cbuf.ptr[p] == '\n') break;
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
      pos = (pos+ConBufSize-1)%ConBufSize;
      toLineStart();
    }
  }

  Range res;
  res.h = cbufhead;
  res.pos = res.t = cbuftail;
  if (cbuf.ptr[res.pos] != '\n') res.pos = (res.pos+1)%ConBufSize;
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
    if (cbuf.ptr[pp] == '\n') stdout.write('|');
    stdout.write(cbuf.ptr[pp]);
    if (pp == cbuftail) {
      if (cbuf.ptr[pp] != '\n') stdout.write('\n');
      break;
    }
    pp = (pp+1)%ConBufSize;
  }
  //foreach (auto s; conbufLinesRev) stdout.writeln(s, "|");
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
static if (!is(typeof(usize))) private alias usize = size_t;
//private alias StripTypedef(T) = T;

//__gshared void delegate (scope const(char[])) @trusted nothrow @nogc  conwriter;
//public @property auto ConWriter () @trusted nothrow @nogc { return conwriter; }
//public @property auto ConWriter (typeof(conwriter) cv) @trusted nothrow @nogc { auto res = conwriter; conwriter = cv; return res; }

void conwriter (scope ConString str) nothrow @trusted @nogc {
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


// ////////////////////////////////////////////////////////////////////////// //
private void cwrxputch (scope const(char)[] s...) nothrow @trusted @nogc {
  pragma(inline, true);
  if (s.length) cbufPut(s);
}


private void cwrxputstr(bool cutsign=false) (scope const(char)[] str, char signw, char lchar, char rchar, int wdt, int maxwdt) nothrow @trusted @nogc {
  if (maxwdt < 0) {
    if (maxwdt == maxwdt.min) ++maxwdt; // alas
    maxwdt = -maxwdt;
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
    if (n == 0x8000u) { cwrxputstr!true("-32768", signw, lchar, rchar, wdt, maxwdt); return; }
  } else static if (is(T == byte)) {
    if (n == 0x80u) { cwrxputstr!true("-128", signw, lchar, rchar, wdt, maxwdt); return; }
  }

  static if (__traits(isUnsigned, T)) {
    enum neg = false;
  } else {
    bool neg = (n < 0);
    if (neg) n = -n;
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
    if (neg) n = -n;
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
    if (n < 0) { fmtstr.ptr[fspos++] = '-'; n = -n; }
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
    fmtstr.ptr[fspos++] = 'f';
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


// ////////////////////////////////////////////////////////////////////////// //
/// write formatted string to console with compile-time format string
public template conwritef(string fmt, A...) {
  private string gen() () {
    string res;
    usize pos;

    void putNum(bool hex=false) (int n, int minlen=-1) {
      if (n == n.min) assert(0, "oops");
      if (n < 0) { res ~= '-'; n = -n; }
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
      res ~= buf[bpos..$];
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
          res ~= "cwrxputch(`"~fmt[pos..epos]~"`);\n";
          pos = epos;
          if (pos >= fmt.length) break;
        }
        if (fmt[pos] != '%') {
          res ~= "cwrxputch('\\x";
          putNum!true(cast(ubyte)fmt[pos], 2);
          res ~= "');\n";
          ++pos;
          continue;
        }
        if (fmt.length-pos < 2 || fmt[pos+1] == '%') { res ~= "cwrxputch('%');\n"; pos += 2; continue; }
        return;
      }
    }

    bool simples = false;
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
      }
      switch (fmtch) {
        case 's':
          static if (is(at == char)) {
            res ~= "cwrxputchar(args[";
            putNum(argnum);
            res ~= "]";
          } else static if (is(at == wchar) || is(at == dchar)) {
            res ~= "import std.conv : to; cwrxputstr(to!string(args[";
            putNum(argnum);
            res ~= "])";
          } else static if (is(at == bool)) {
            res ~= "cwrxputstr((args[";
            putNum(argnum);
            res ~= "] ? `true` : `false`)";
          } else static if (is(at == float) || is(at == double) || is(at == real)) {
            res ~= "cwrxputfloat(args[";
            putNum(argnum);
            res ~= "], true";
          } else static if (is(at : const(char)[])) {
            res ~= "cwrxputstr(args[";
            putNum(argnum);
            res ~= "]";
          } else static if (is(at : T*, T)) {
            //res ~= "cwrxputch(`0x`); ";
            if (wdt < (void*).sizeof*2) { lchar = '0'; wdt = cast(int)((void*).sizeof)*2; signw = ' '; }
            res ~= "cwrxputhex(cast(size_t)args[";
            putNum(argnum);
            res ~= "], false";
          } else static if (is(at : long)) {
            res ~= "cwrxputint(args[";
            putNum(argnum);
            res ~= "]";
          } else {
            res ~= "import std.conv : to; cwrxputstr(to!string(args[";
            putNum(argnum);
            res ~= "])";
          }
          break;
        case 'x':
          static if (is(at == char) || is(at == wchar) || is(at == dchar)) {
            res ~= "cwrxputhex(cast(uint)args[";
            putNum(argnum);
            res ~= "], false";
          } else static if (is(at == bool)) {
            res ~= "cwrxputstr((args[";
            putNum(argnum);
            res ~= "] ? `1` : `0`)";
          } else static if (is(at == float) || is(at == double) || is(at == real)) {
            assert(0, "can't hexprint floats yet");
          } else static if (is(at : T*, T)) {
            if (wdt < (void*).sizeof*2) { lchar = '0'; wdt = cast(int)((void*).sizeof)*2; signw = ' '; }
            res ~= "cwrxputhex(cast(size_t)args[";
            putNum(argnum);
            res ~= "], false";
          } else static if (is(at : long)) {
            res ~= "cwrxputhex(args[";
            putNum(argnum);
            res ~= "], false";
          } else {
            assert(0, "can't print '"~at.stringof~"' as hex");
          }
          break;
        case 'X':
          static if (is(at == char) || is(at == wchar) || is(at == dchar)) {
            res ~= "cwrxputhex(cast(uint)args[";
            putNum(argnum);
            res ~= "], true";
          } else static if (is(at == bool)) {
            res ~= "cwrxputstr((args[";
            putNum(argnum);
            res ~= "] ? `1` : `0`)";
          } else static if (is(at == float) || is(at == double) || is(at == real)) {
            assert(0, "can't hexprint floats yet");
          } else static if (is(at : T*, T)) {
            if (wdt < (void*).sizeof*2) { lchar = '0'; wdt = cast(int)((void*).sizeof)*2; signw = ' '; }
            res ~= "cwrxputhex(cast(size_t)args[";
            putNum(argnum);
            res ~= "], true";
          } else static if (is(at : long)) {
            res ~= "cwrxputhex(args[";
            putNum(argnum);
            res ~= "], true";
          } else {
            assert(0, "can't print '"~at.stringof~"' as hex");
          }
          break;
        case 'f':
          static if (is(at == float) || is(at == double) || is(at == real)) {
            res ~= "cwrxputfloat(args[";
            putNum(argnum);
            res ~= "], false";
          } else {
            assert(0, "can't print '"~at.stringof~"' as float");
          }
          break;
        default: assert(0, "invalid format specifier: '"~fmtch~"'");
      }
      res ~= ", '";
      res ~= signw;
      res ~= "', '\\x";
      putNum!true(cast(uint)lchar, 2);
      res ~= "', '\\x";
      putNum!true(cast(uint)rchar, 2);
      res ~= "', ";
      putNum(wdt);
      res ~= ", ";
      putNum(maxwdt);
      res ~= ");\n";
    }
    while (pos < fmt.length) {
      processUntilFSp();
      if (pos >= fmt.length) break;
      assert(fmt[pos] == '%');
      ++pos;
      if (pos < fmt.length && (fmt[pos] == '!' || fmt[pos] == '|')) { ++pos; continue; } // skip rest
      assert(0, "too many format specifiers");
    }
    return res;
  }
  void conwritef (A args) {
    enum code = gen();
    //pragma(msg, code);
    //pragma(msg, "===========");
    mixin(code);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public:

//void conwritef(string fmt, A...) (A args) { fdwritef!(fmt)(args); }
void conwritefln(string fmt, A...) (A args) { conwritef!(fmt)(args); cwrxputch('\n'); } /// write formatted string to console with compile-time format string
void conwrite(A...) (A args) { conwritef!("%|")(args); } /// write formatted string to console with compile-time format string
void conwriteln(A...) (A args) { conwritef!("%|\n")(args); } /// write formatted string to console with compile-time format string


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
    exIntOverflow = new ConvOverflowException("overflow in integral conversion");
    exBadHexEsc = new ConvException("invalid hex escape");
    exBadEscChar = new ConvException("invalid escape char");
    exNoArg = new ConvException("argument expected");
    exTooManyArgs = new ConvException("too many arguments");
    exBadArgType = new ConvException("can't parse given argument type (internal error)");
  }

private:
  __gshared char[] wordBuf;

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

protected:
static:
  //private import std.traits : isSomeChar;
  int digit(TC) (TC ch, uint base) pure nothrow @safe @nogc if (isSomeChar!TC) {
    int res = void;
         if (ch >= '0' && ch <= '9') res = ch-'0';
    else if (ch >= 'A' && ch <= 'Z') res = ch-'A'+10;
    else if (ch >= 'a' && ch <= 'z') res = ch-'a'+10;
    else return -1;
    return (res >= base ? -1 : res);
  }

  // get word from command line
  // note that next call to `getWord()` can destroy result
  // returns `null` if there are no more words
  // `*strtemp` will be `true` if temporary string storage was used
  ConString getWord (ref ConString s, bool *strtemp=null) {
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
      wordBuf.assumeSafeAppend.length = pos;
      if (pos) wordBuf[0..pos] = s[0..pos];
      // process special chars
      while (pos < s.length && s.ptr[pos] != qch) {
        if (s.ptr[pos] == '\\' && s.length-pos > 1) {
          ++pos;
          switch (s.ptr[pos++]) {
            case '"': case '\'': case '\\': wordBuf ~= s.ptr[pos-1]; break;
            case '0': wordBuf ~= '\x00'; break;
            case 'a': wordBuf ~= '\a'; break;
            case 'b': wordBuf ~= '\b'; break;
            case 'e': wordBuf ~= '\x1b'; break;
            case 'f': wordBuf ~= '\f'; break;
            case 'n': wordBuf ~= '\n'; break;
            case 'r': wordBuf ~= '\r'; break;
            case 't': wordBuf ~= '\t'; break;
            case 'v': wordBuf ~= '\v'; break;
            case 'x': case 'X':
              int n = 0;
              foreach (immutable _; 0..2) {
                if (pos >= s.length) throw exBadHexEsc;
                char c2 = s.ptr[pos++];
                if (digit(c2, 16) < 0) throw exBadHexEsc;
                n = n*16+digit(c2, 16);
              }
              wordBuf ~= cast(char)n;
              break;
            default: throw exBadEscChar;
          }
          continue;
        }
        wordBuf ~= s.ptr[pos++];
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

  T parseType(T) (ref ConString s) {
    import std.utf : byCodeUnit;
    // number
    static if (is(T == bool)) {
      auto w = getWord(s);
      if (w is null) throw exNoArg;
      bool good = false;
      auto res = parseBool(w, true, &good);
      if (!good) throw exBadBool;
      return res;
    } else static if ((isIntegral!T || isFloatingPoint!T) && !is(T == enum)) {
      auto w = getWord(s);
      if (w is null) throw exNoArg;
      auto ss = w.byCodeUnit;
      auto res = parseNum!T(ss);
      if (!ss.empty) throw exBadNum;
      return res;
    } else static if (is(T : ConString)) {
      bool stemp = false;
      auto w = getWord(s);
      if (w is null) throw exNoArg;
      if (s.length && s.ptr[0] > 32) throw exBadStr;
      if (stemp) {
        // temp storage was used
        static if (is(T == string)) return w.idup; else return w.dup;
      } else {
        // no temp storage was used
        static if (is(T == ConString)) return w;
        else static if (is(T == string)) return w.idup;
        else return w.dup;
      }
    } else static if (is(T : char)) {
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
        if (num != 0x8000_0000_0000_0000uL) n = -n;
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

  public static void writeQuotedString (scope ConString s) {
    static immutable string hexd = "0123456789abcdef";
    static bool isBadChar() (char ch) {
      pragma(inline, true);
      return (ch < ' ' || ch == '\\' || ch == '"' || ch > 126);
    }
    //auto wrt = ConWriter;
    alias wrt = conwriter;
    wrt("\"");
    usize pos = 0;
    while (pos < s.length) {
      usize end = pos;
      while (end < s.length && !isBadChar(s.ptr[end])) ++end;
      if (end > pos) wrt(s[pos..end]);
      pos = end;
      if (pos >= s.length) break;
      wrt("\\");
      switch (s.ptr[pos++]) {
        case '"': case '\'': case '\\': wrt(s.ptr[pos-1..pos]); break;
        case '\x00': wrt("0"); break;
        case '\a': wrt("a"); break;
        case '\b': wrt("b"); break;
        case '\x1b': wrt("e"); break;
        case '\f': wrt("f"); break;
        case '\n': wrt("n"); break;
        case '\r': wrt("r"); break;
        case '\t': wrt("t"); break;
        case '\v': wrt("c"); break;
        default:
          ubyte c = cast(ubyte)(s.ptr[pos-1]);
          wrt("x");
          wrt(hexd[c>>4..(c>>4)+1]);
          wrt(hexd[c&0x0f..c&0x0f+1]);
          break;
      }
    }
    wrt("\"");
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
/// convar attributes
public enum ConVarAttr {
  None = 0, ///
  Archive = 0, /// for convenience
  NoArchive = 1U<<0, /// don't save on change (saving must be done by library user)
  Hex = 1U<<1, /// dump this variable as hex value (valid for integrals)
}


/// variable of some type
public class ConVarBase : ConCommand {
protected:
  uint mAttrs;

public:
  this (string aname, string ahelp=null) { super(aname, ahelp); }

  /// replaces current attributes
  final void setAttrs (const(ConVarAttr)[] attrs...) pure nothrow @safe @nogc {
    mAttrs = 0;
    foreach (const ConVarAttr a; attrs) mAttrs |= a;
  }

  @property pure nothrow @safe @nogc final {
    uint attrs () const { pragma(inline, true); return mAttrs; }
    void attrs (uint v) { pragma(inline, true); mAttrs = v; }

    bool attrArchive () const { pragma(inline, true); return ((mAttrs&ConVarAttr.NoArchive) == 0); }
    bool attrNoArchive () const { pragma(inline, true); return ((mAttrs&ConVarAttr.NoArchive) != 0); }
    bool attrHexDump () const { pragma(inline, true); return ((mAttrs&ConVarAttr.Hex) != 0); }
  }

  abstract void printValue ();
  abstract bool isString () const pure nothrow @nogc;
  abstract ConString strval () nothrow @nogc;

  @property T value(T) () nothrow @nogc {
    pragma(inline, true);
    static if (is(T : ulong)) {
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

  @property void value(T) (T val) nothrow {
    pragma(inline, true);
    static if (is(T : ulong)) {
      // integer, xchar, boolean
      setIntValue(cast(ulong)val, isSigned!T);
    } else static if (is(T : double)) {
      // floats
      setDoubleValue(cast(double)val);
    } else static if (is(T : ConString)) {
      static if (is(T == string)) setStrValue(val); else setCCharValue(val);
    }
  }

protected:
  abstract ulong getIntValue () nothrow @nogc;
  abstract double getDoubleValue () nothrow @nogc;

  abstract void setIntValue (ulong v, bool signed) nothrow @nogc;
  abstract void setDoubleValue (double v) nothrow @nogc;
  abstract void setStrValue (string v) nothrow;
  abstract void setCCharValue (ConString v) nothrow;
}


// ////////////////////////////////////////////////////////////////////////// //
/// console will use this to register console variables
final class ConVar(T) : ConVarBase {
  enum useAtomic = is(T == shared);
  T* vptr;
  static if (isIntegral!T) {
    T minv = T.min;
    T maxv = T.max;
  }
  static if (!is(T : ConString)) {
    char[256] vbuf;
  } else {
    char[256] tvbuf; // temp value
  }

  this (T* avptr, string aname, string ahelp=null) { vptr = avptr; super(aname, ahelp); }
  static if (isIntegral!T) {
    this (T* avptr, T aminv, T amaxv, string aname, string ahelp=null) {
      vptr = avptr;
      minv = aminv;
      maxv = amaxv;
      super(aname, ahelp);
    }
  }

  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) { printValue; return; }
    static if (is(XUQQ!T == bool)) {
      while (cmdline.length && cmdline[0] <= 32) cmdline = cmdline[1..$];
      while (cmdline.length && cmdline[$-1] <= 32) cmdline = cmdline[0..$-1];
      if (cmdline == "toggle") {
        static if (useAtomic) {
          import core.atomic;
          atomicStore(*vptr, !atomicLoad(*vptr));
        } else {
          *vptr = !(*vptr);
        }
        return;
      }
    }
    T val = parseType!T(/*ref*/ cmdline);
    if (hasArgs(cmdline)) throw exTooManyArgs;
    static if (isIntegral!T) {
      if (val < minv) val = minv;
      if (val > maxv) val = maxv;
    }
    static if (useAtomic) {
      import core.atomic;
      atomicStore(*vptr, val);
    } else {
      *vptr = val;
    }
  }

  override bool isString () const pure nothrow @nogc {
    static if (is(T : ConString)) {
      return true;
    } else {
      return false;
    }
  }

  final private T getv () nothrow @nogc {
    pragma(inline, true);
    import core.atomic;
    static if (useAtomic) return atomicLoad(*vptr); else return *vptr;
  }

  override ConString strval () nothrow @nogc {
    //conwriteln("*** strval for '", name, "'");
    import core.stdc.stdio : snprintf;
    static if (is(T : ConString)) {
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
      auto len = snprintf(vbuf.ptr, vbuf.length, "%f", cast(double)(getv()));
      return (len >= 0 ? vbuf[0..len] : "?");
    } else static if (is(XUQQ!T == char)) {
      vbuf.ptr[0] = cast(char)getv();
      return vbuf[0..1];
    } else {
      static assert(0, "can't get string value of convar with type '"~T.stringof~"'");
    }
  }

  protected override ulong getIntValue () nothrow @nogc {
    static if (is(T : ulong) || is(T : double)) return cast(ulong)(getv()); else return ulong.init;
  }

  protected override double getDoubleValue () nothrow @nogc {
    static if (is(T : double) || is(T : ulong)) return cast(double)(getv()); else return double.init;
  }

  private template PutVMx(string val) {
    static if (useAtomic) {
      enum PutVMx = "{ import core.atomic; atomicStore(*vptr, "~val~"); }";
    } else {
      enum PutVMx = "*vptr = "~val~";";
    }
  }

  protected override void setIntValue (ulong v, bool signed) nothrow @nogc {
    import core.atomic;
    static if (is(T : ulong) || is(T : double)) {
      mixin(PutVMx!"cast(T)v");
    } else static if (is(T : ConString)) {
      import core.stdc.stdio : snprintf;
      auto len = snprintf(tvbuf.ptr, tvbuf.length, (signed ? "%lld" : "%llu"), v);
           static if (is(T == string)) mixin(PutVMx!"cast(string)(tvbuf[0..len])"); // not really safe, but...
      else static if (is(T == ConString)) mixin(PutVMx!"cast(ConString)(tvbuf[0..len])");
      else static if (is(T == char[])) mixin(PutVMx!"tvbuf[0..len]");
    }
  }

  protected override void setDoubleValue (double v) nothrow @nogc {
    import core.atomic;
    static if (is(T : ulong) || is(T : double)) {
      mixin(PutVMx!"cast(T)v");
    } else static if (is(T : ConString)) {
      import core.stdc.stdio : snprintf;
      auto len = snprintf(tvbuf.ptr, tvbuf.length, "%g", v);
           static if (is(T == string)) mixin(PutVMx!"cast(string)(tvbuf[0..len])"); // not really safe, but...
      else static if (is(T == ConString)) mixin(PutVMx!"cast(ConString)(tvbuf[0..len])");
      else static if (is(T == char[])) mixin(PutVMx!"tvbuf[0..len]");
    }
  }

  protected override void setStrValue (string v) nothrow {
    import core.atomic;
    static if (is(T == string) || is(T == ConString)) {
      mixin(PutVMx!"cast(T)v");
    } else static if (is(T == char[])) {
      mixin(PutVMx!"v.dup");
    }
  }

  protected override void setCCharValue (ConString v) nothrow {
    import core.atomic;
         static if (is(T == string)) mixin(PutVMx!"v.idup");
    else static if (is(T == ConString)) mixin(PutVMx!"v");
    else static if (is(T == char[])) mixin(PutVMx!"v.dup");
  }

  override void printValue () {
    //auto wrt = ConWriter;
    alias wrt = conwriter;
    static if (is(T : ConString)) {
      wrt(name);
      wrt(" ");
      writeQuotedString(getv());
      wrt("\n");
      //wrt(null); // flush
    } else static if (is(XUQQ!T == char)) {
      wrt(name);
      wrt(" ");
      char[1] st = getv();
      if (st[0] <= ' ' || st[0] == 127 || st[0] == '"' || st[0] == '\\') {
        writeQuotedString(st[]);
      } else {
        wrt(`"`);
        wrt(st[]);
        wrt(`"`);
      }
      wrt("\n");
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


void addName (string name) {
  if (name.length == 0) return;
  if (name !in cmdlist) {
    import std.algorithm : sort;
    //import std.range : array;
    cmdlistSorted ~= name;
    cmdlistSorted.sort;
  }
}


/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 *   ahelp = help text
 *   attrs = convar attributes (see ConVarAttr)
 */
public void conRegVar(alias v, T) (T aminv, T amaxv, string aname, string ahelp, const(ConVarAttr)[] attrs...) if (isIntegral!(typeof(v)) && isIntegral!T) {
  static assert(isGoodVar!v, "console variable '"~v.stringof~"' must be shared or __gshared");
  if (aname.length == 0) aname = (&v).stringof[2..$]; // HACK
  if (aname.length > 0) {
    addName(aname);
    auto v = new ConVar!(typeof(v))(&v, cast(typeof(v))aminv, cast(typeof(v))amaxv, aname, ahelp);
    v.setAttrs(attrs);
    cmdlist[aname] = v;
  }
}


/** register integral console variable with bounded value.
 *
 * Params:
 *   v = variable symbol
 *   aminv = minimum value
 *   amaxv = maximum value
 *   aname = variable name
 */
public void conRegVar(alias v, T) (T aminv, T amaxv, string aname) if (isIntegral!(typeof(v)) && isIntegral!T) { conRegVar!(v, T)(aminv, amaxv, aname, null); }


/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 *   ahelp = help text
 *   attrs = convar attributes (see ConVarAttr)
 */
public void conRegVar(alias v) (string aname, string ahelp, const(ConVarAttr)[] attrs...) if (!isCallable!(typeof(v))) {
  static assert(isGoodVar!v, "console variable '"~v.stringof~"' must be shared or __gshared");
  if (aname.length == 0) aname = (&v).stringof[2..$]; // HACK
  if (aname.length > 0) {
    addName(aname);
    auto v = new ConVar!(typeof(v))(&v, aname, ahelp);
    v.setAttrs(attrs);
    cmdlist[aname] = v;
  }
}


/** register console variable.
 *
 * Params:
 *   v = variable symbol
 *   aname = variable name
 */
public void conRegVar(alias v) (string aname) if (!isCallable!(typeof(v))) { conRegVar!(v)(aname, null); }


// ////////////////////////////////////////////////////////////////////////// //
// delegate
public class ConFuncBase : ConCommand {
  this (string aname, string ahelp=null) { super(aname, ahelp); }
}


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
public void conRegFunc(alias fn) (string aname, string ahelp=null) if (isCallable!fn) {
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
        alias defaultArguments = ParameterDefaultValueTuple!fn;
        //pragma(msg, "defs: ", defaultArguments);
        import std.conv : to;
        foreach (/*auto*/ idx, ref arg; args) {
          // populate arguments, with user data if available,
          // default if not, and throw if no argument provided
          if (hasArgs(cmdline)) {
            import std.conv : ConvException;
            try {
              arg = parseType!(typeof(arg))(cmdline);
            } catch (ConvException) {
              conwriteln("error parsing argument #", idx+1, " for command '", name, "'");
              return;
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
__gshared ConCommand[string] cmdlist;
__gshared string[] cmdlistSorted;


// ////////////////////////////////////////////////////////////////////////// //
// all following API is thread-unsafe, if the opposite is not written
public bool conHasCommand (ConString name) { pragma(inline, true); return ((name in cmdlist) !is null); } /// check if console has a command with a given name (thread-unsafe)

/// known console commands range (thread-unsafe)
public auto conByCommand () {
  static struct Range {
  private:
    usize idx;

  public:
    @property bool empty() () { pragma(inline, true); return (idx >= cmdlistSorted.length); }
    @property string front() () { pragma(inline, true); return (idx < cmdlistSorted.length ? cmdlistSorted.ptr[idx] : null); }
    @property bool frontIsVar() () { pragma(inline, true); return (idx < cmdlistSorted.length ? (cast(ConVarBase)cmdlist[cmdlistSorted.ptr[idx]] !is null) : false); }
    @property bool frontIsFunc() () { pragma(inline, true); return (idx < cmdlistSorted.length ? (cast(ConFuncBase)cmdlist[cmdlistSorted.ptr[idx]] !is null) : false); }
    void popFront () { pragma(inline, true); if (idx < cmdlistSorted.length) ++idx; }
  }
  Range res;
  return res;
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


/// set console variable value (thread-safe)
public void conSetVar(T) (ConString s, T val) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) cv.value = val;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// thread-safe

/// execute console command (thread-safe)
public void conExecute (ConString s) {
  auto ss = s;
  consoleLock();
  scope(exit) consoleUnlock();
  try {
    auto w = ConCommand.getWord(s);
    if (w is null) return;
    if (auto cmd = w in cmdlist) {
      while (s.length && s.ptr[0] <= 32) s = s[1..$];
      //conwriteln("'", s, "'");
      (*cmd).exec(s);
    } else {
      //auto wrt = ConWriter;
      alias wrt = conwriter;
      wrt("command ");
      ConCommand.writeQuotedString(w);
      wrt(" not found");
      wrt("\n");
      //wrt(null); // flush
    }
  } catch (Exception) {
    conwriteln("error executing console command:\n ", s);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
///
version(contest_func) unittest {
  static void xfunc (int v, int x=42) { conwriteln("xfunc: v=", v, "; x=", x); }

  conRegFunc!xfunc("", "function with two int args (last has default value '42')");
  conExecute("xfunc ?");
  conExecute("xfunc 666");
  conExecute("xfunc");

  conRegFunc!({conwriteln("!!!");})("bang");
  conExecute("bang");

  conRegFunc!((ConFuncVA va) {
    int idx = 1;
    for (;;) {
      auto w = ConCommand.getWord(va.cmdline);
      if (w is null) break;
      conwriteln("#", idx, ": [", w, "]");
      ++idx;
    }
  })("doo");
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
/// console always has "echo" command, no need to register it.
public class ConCommandEcho : ConCommand {
  this () { super("echo", "write string to console"); }

  override void exec (ConString cmdline) {
    if (checkHelp(cmdline)) { showHelp; return; }
    if (!hasArgs(cmdline)) return;
    bool needSpace = false;
    //auto wrt = ConWriter;
    alias wrt = conwriter;
    for (;;) {
      auto w = getWord(cmdline);
      if (w is null) break;
      if (needSpace) wrt(" "); else needSpace = true;
      while (w.length) {
        usize pos = 0;
        while (pos < w.length && w.ptr[pos] != '$') ++pos;
        if (w.length-pos > 1 && w.ptr[pos+1] == '$') {
          wrt(w[0..pos+1]);
          w = w[pos+2..$];
        } else if (w.length-pos <= 1) {
          wrt(w);
          break;
        } else {
          // variable name
          ConString vname;
          if (pos > 0) wrt(w[0..pos]);
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
                wrt(v);
              } else {
                wrt("${!");
                wrt(vname);
                wrt("}");
              }
            } else {
              wrt("${");
              wrt(vname);
              wrt("}");
            }
          }
        }
      }
    }
    wrt("\n");
    //wrt(null); // flush
  }
}


shared static this () {
  addName("echo");
  cmdlist["echo"] = new ConCommandEcho();
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
  conRegVar!vi("vi");
  conRegVar!vs("vs");
  conRegVar!vb("vb");
  conRegVar!vb("r_interpolation");
  conwriteln("=================");
  conExecute("r_interpolation");
  conExecute("echo ?");
  conExecute("echo vs=$vs,  vi=${vi},  vb=${vb}!");
  {
    char[44] buf;
    auto s = buf.conFormatStr("vs=$vs,  vi=${vi},  vb=${vb}!");
    conwriteln("[", s, "]");
    foreach (auto kv; cmdlist.byKeyValue) conwriteln(" ", kv.key);
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
  auto cl = conByCommand;
  while (!cl.empty) {
         if (cl.frontIsVar) conwrite("VAR  ");
    else if (cl.frontIsFunc) conwrite("FUNC ");
    else conwrite("UNK  ");
    conwriteln("[", cl.front, "]");
    cl.popFront();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// simple input buffer for console
__gshared char[4096] concli = 0;
__gshared uint conclilen = 0;

shared uint inchangeCount = 1;
public @property ulong conInputLastChange () nothrow @trusted @nogc { pragma(inline, true); import core.atomic; return atomicLoad(inchangeCount); } /// changed when something was put to console input buffer
public void conInputIncLastChange () nothrow @trusted @nogc { pragma(inline, true); import core.atomic; atomicOp!"+="(inchangeCount, 1); } /// increment console input buffer change flag


public @property ConString conInputBuffer() () @trusted { pragma(inline, true); return concli[0..conclilen]; } /// returns console input buffer

/** clear console input buffer.
 *
 * call this function with `addToHistory:true` to add current input buffer to history.
 * it is safe to call this for empty input buffer, history won't get empty line.
 *
 * Params:
 *   addToHistory = true if current buffer should be "added to history", so current history index should be reset and history will be updated
 */
public void conInputBufferClear() (bool addToHistory=false) @trusted {
  if (conclilen > 0) {
    if (addToHistory) conhisAdd(conInputBuffer);
    conclilen = 0;
    conInputIncLastChange();
  }
  if (addToHistory) conhisidx = -1;
}


__gshared char[4096][128] concmdhistory = void;
__gshared int conhisidx = -1;
shared static this () { foreach (ref hb; concmdhistory) hb[] = 0; }


/// returns input buffer history item (0 is oldest) or null if there are no more items
ConString conhisAt (int idx) {
  if (idx < 0 || idx >= concmdhistory.length) return null;
  ConString res = concmdhistory.ptr[idx][];
  usize pos = 0;
  while (pos < res.length && res.ptr[pos]) ++pos;
  return res[0..pos];
}


/// find command in input history, return index or -1
int conhisFind (ConString cmd) {
  while (cmd.length && cmd[$-1] <= 32) cmd = cmd[0..$-1];
  if (cmd.length > concmdhistory.ptr[0].length) cmd = cmd[0..concmdhistory.ptr[0].length];
  if (cmd.length == 0) return -1;
  foreach (int idx; 0..cast(int)concmdhistory.length) {
    auto c = conhisAt(idx);
    while (c.length > 0 && c[$-1] <= 32) c = c[0..$-1];
    if (c == cmd) return idx;
  }
  return -1;
}


/// add command to history. will take care about duplicate commands.
void conhisAdd (ConString cmd) {
  while (cmd.length && cmd[$-1] <= 32) cmd = cmd[0..$-1];
  if (cmd.length > concmdhistory.ptr[0].length) cmd = cmd[0..concmdhistory.ptr[0].length];
  if (cmd.length == 0) return;
  auto idx = conhisFind(cmd);
  if (idx >= 0) {
    // remove command
    foreach (immutable c; idx+1..concmdhistory.length) concmdhistory.ptr[c-1][] = concmdhistory.ptr[c][];
  }
  // make room
  foreach_reverse (immutable c; 1..concmdhistory.length) concmdhistory.ptr[c][] = concmdhistory.ptr[c-1][];
  concmdhistory.ptr[0][] = 0;
  concmdhistory.ptr[0][0..cmd.length] = cmd[];
}


/// special characters for `conAddInputChar()`
public enum ConInputChar : char {
  Up = '\x01',
  Down = '\x02',
  Left = '\x03',
  Right = '\x04',
  Home = '\x05',
  End = '\x06',
  PageUp = '\x07',
  Backspace = '\x08',
  Tab = '\x09',
  // 0a
  PageDown = '\x0b',
  Delete = '\x0c',
  Enter = '\x0d',
  Insert = '\x0e',
  //
  CtrlY = '\x19',
}


/// process console input char (won't execute commands, but will do autocompletion and history)
public void conAddInputChar (char ch) {
  __gshared int prevWasEmptyAndTab = 0;
  // autocomplete
  if (ch == ConInputChar.Tab) {
    if (conclilen == 0) {
      if (++prevWasEmptyAndTab < 2) return;
    } else {
      prevWasEmptyAndTab = 0;
    }
    if (conclilen > 0) {
      string minPfx = null;
      // find longest command
      foreach (/*auto*/ name; conByCommand) {
        if (name.length >= conclilen && name.length > minPfx.length && name[0..conclilen] == concli[0..conclilen]) minPfx = name;
      }
      //conwriteln("longest command: [", minPfx, "]");
      // find longest prefix
      foreach (/*auto*/ name; conByCommand) {
        if (name.length < conclilen) continue;
        if (name[0..conclilen] != concli[0..conclilen]) continue;
        usize pos = 0;
        while (pos < name.length && pos < minPfx.length && minPfx.ptr[pos] == name.ptr[pos]) ++pos;
        if (pos < minPfx.length) minPfx = minPfx[0..pos];
      }
      if (minPfx.length > concli.length) minPfx = minPfx[0..concli.length];
      //conwriteln("longest prefix : [", minPfx, "]");
      if (minPfx.length >= conclilen) {
        // wow!
        bool doRet = (minPfx.length > conclilen);
        concli[0..minPfx.length] = minPfx[];
        conclilen = cast(uint)minPfx.length;
        if (conclilen < concli.length && conHasCommand(minPfx)) {
          concli.ptr[conclilen++] = ' ';
          doRet = true;
        }
        conInputIncLastChange();
        if (doRet) return;
      }
    }
    // nope, print all available commands
    bool needDelimiter = true;
    foreach (/*auto*/ name; conByCommand) {
      if (conclilen > 0) {
        if (name.length < conclilen) continue;
        if (name[0..conclilen] != concli[0..conclilen]) continue;
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
    if (conclilen > 0) { --conclilen; conInputIncLastChange(); }
    return;
  }
  // ^Y
  if (ch == ConInputChar.CtrlY) {
    if (conclilen > 0) { conInputIncLastChange(); conclilen = 0; }
    return;
  }
  // up
  if (ch == ConInputChar.Up) {
    ++conhisidx;
    auto cmd = conhisAt(conhisidx);
    if (cmd.length == 0) {
      --conhisidx;
    } else {
      concli[0..cmd.length] = cmd[];
      conclilen = cast(uint)cmd.length;
      conInputIncLastChange();
    }
    return;
  }
  // down
  if (ch == ConInputChar.Down) {
    --conhisidx;
    auto cmd = conhisAt(conhisidx);
    if (cmd.length == 0 && conhisidx < -1) {
      ++conhisidx;
    } else {
      concli[0..cmd.length] = cmd[];
      conclilen = cast(uint)cmd.length;
      conInputIncLastChange();
    }
    return;
  }
  // other
  if (ch < ' ' || ch > 127) return;
  if (conclilen >= concli.length) return;
  concli.ptr[conclilen++] = ch;
  conInputIncLastChange();
}
