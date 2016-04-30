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
 *   negative maxlen: get right part
 * specifiers:
 *   's': use to!string to write argument
 *        note that writer can print strings, bools and integrals without allocation
 *   'S': print asciiz C string
 *   'x': write integer as hex
 *   'X': write integer as HEX
 *   '|': write all arguments that's left with "%s"
 *   '@': go to argument with number 'width' (use sign to relative goto)
 *        argument count starts with '1'
 *   '!': skip all arguments that's left, no width allowed
 *   '%': just a percent sign, no width allowed
 *   '$': go to argument with number 'width' (use sign to relative goto), continue parsing
 *        argument count starts with '1'
 * options (must immediately follow '%'):
 *   '/': center string; negative width means "add extra space (if any) to the right"
 *   '~': fill with the following char instead of space
 *        second '~': right filling char for 'center'
 *   '\0'...'\0': separator string for '%|'
 */
module iv.cmdcon is aliced;
private:


// ////////////////////////////////////////////////////////////////////////// //
// use this in conGetVar, for example, to avoid allocations
alias ConString = const(char)[];


// ////////////////////////////////////////////////////////////////////////// //
shared bool conStdoutFlag = true;
public @property bool conStdout () nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicLoad; return atomicLoad(conStdoutFlag); }
public @property void conStdout (bool v) nothrow @trusted @nogc { pragma(inline, true); import core.atomic : atomicStore; atomicStore(conStdoutFlag, v); }


// ////////////////////////////////////////////////////////////////////////// //
import core.sync.mutex : Mutex;
__gshared Mutex consoleLocker;
shared static this () { consoleLocker = new Mutex(); }


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

shared ulong changeCount = 1;
public @property ulong cbufLastChange () nothrow @trusted @nogc { import core.atomic; return atomicLoad(changeCount); }


// ////////////////////////////////////////////////////////////////////////// //
public void consoleLock() () { pragma(inline, true); consoleLocker.lock(); }
public void consoleUnlock() () { pragma(inline, true); consoleLocker.unlock(); }


// ////////////////////////////////////////////////////////////////////////// //
// thread-safe
public void cbufPut (scope ConString chrs...) nothrow @trusted @nogc {
  if (chrs.length) {
    import core.atomic : atomicLoad, atomicOp;
    consoleLock();
    scope(exit) consoleUnlock();
    if (atomicLoad(conStdoutFlag)) {
      import core.sys.posix.unistd : STDOUT_FILENO, write;
      write(STDOUT_FILENO, chrs.ptr, chrs.length);
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
// warning! don't modify conbuf while the range is active!
// not thread-safe
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


// width<0: pad right
// width == int.min: no width specified
// maxlen == int.min: no maxlen specified
private void wrWriteWidth(char lfill=' ', char rfill=' ')
               (int width,
                int maxlen,
                bool center,
                const(char[]) s,
                bool leftIsMinus=false) {
  static immutable char[64] spacesl = () { char[64] r; foreach (immutable p; 0..64) r[p] = lfill; return r; }();
  static immutable char[64] spacesr = () { char[64] r; foreach (immutable p; 0..64) r[p] = rfill; return r; }();
  usize stpos = 0;
  // fix maxlen
  if (maxlen != int.min) {
    if (maxlen < 0) {
      maxlen = -maxlen;
      if (maxlen > s.length) {
        maxlen = cast(int)s.length;
      } else {
        stpos = s.length-maxlen;
      }
    } else if (maxlen > 0) {
      if (maxlen > s.length) maxlen = cast(int)s.length;
    }
  } else {
    // no maxlen specified
    maxlen = cast(int)s.length;
  }
  // fuck overflows
  if (maxlen < 0) maxlen = 666;
  // fix width
  if (width == int.min) {
    // no width specified, defaults to visible string width
    width = cast(int)(s.length-stpos);
    // fuck overflows
    if (width < 0) width = 666;
  }
  // centering?
  if (center && ((width > 0 && width > maxlen) || (width < 0 && -width > maxlen))) {
    // center string
    int wdt = (width > 0 ? width : -width)-maxlen;
    int spleft = wdt/2+(width > 0 && wdt%2);
    int spright = wdt-spleft;
    while (spleft > 0) {
      if (spleft > spacesl.length) {
        conwriter(spacesl);
        spleft -= spacesl.length;
        continue;
      } else {
        conwriter(spacesl[0..spleft]);
        break;
      }
    }
    if (maxlen > 0) conwriter(s[stpos..stpos+maxlen]);
    while (spright > 0) {
      if (spright > spacesr.length) {
        conwriter(spacesr);
        spright -= spacesr.length;
        continue;
      } else {
        conwriter(spacesr[0..spright]);
        break;
      }
    }
  } else {
    // pad string
    bool writeS = true;
    if (width < 0) {
      // right padding, write string
      width = -width;
      if (maxlen > 0) conwriter(s[stpos..stpos+maxlen]);
      writeS = false;
    }
    if (maxlen < width) {
      width -= maxlen;
      if (writeS && stpos == 0 && leftIsMinus && width > 0) {
        conwriter("-");
        // remove '-'
        ++stpos;
        --maxlen;
      }
      for (;;) {
        if (width > spacesl.length) {
          if (writeS) conwriter(spacesl); else conwriter(spacesr);
          width -= spacesl.length;
        } else {
          if (writeS) conwriter(spacesl[0..width]); else conwriter(spacesr[0..width]);
          break;
        }
      }
    }
    if (writeS && maxlen > 0) conwriter(s[stpos..stpos+maxlen]);
  }
}

// width<0: pad right
// width == int.min: no width specified
// maxlen == int.min: no maxlen specified
private void wrWriteWidthStrZ(char lfill=' ', char rfill=' ')
               (int width,
                int maxlen,
                bool center,
                const(char)* s,
                bool leftIsMinus=false) {
  usize end = 0;
  while (s[end]) ++end;
  wrWriteWidth!(lfill, rfill)(width, maxlen, center, s[0..end], leftIsMinus);
}


private void wrWriteWidthHex(char lfill=' ', char rfill=' ', T)
               (int width,
                int maxlen,
                bool center,
                bool upcase,
                T numm)
if (isIntegral!T)
{
  import std.traits : isSigned, isMutable, Unqual;
  static if (isMutable!T) alias num = numm; else Unqual!T num = cast(Unqual!T)numm;
  char[18] hstr = void;
  auto pos = hstr.length;
  static if (isSigned!T) {
    static if (T.sizeof == 8) {
      if (num == 0x8000_0000_0000_0000uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-8000000000000000", (lfill == '0')); return; }
    } else static if (T.sizeof == 4) {
      if (num == 0x8000_0000uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-80000000", (lfill == '0')); return; }
    } else static if (T.sizeof == 2) {
      if (num == 0x8000uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-8000", (lfill == '0')); return; }
    } else static if (T.sizeof == 1) {
      if (num == 0x80uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-80", (lfill == '0')); return; }
    }
    bool neg = (num < 0);
    if (neg) num = -num;
  }
  do {
    assert(pos > 0);
    ubyte b = num&0x0f;
    num >>= 4;
    if (b < 10) {
      hstr[--pos] = cast(char)('0'+b);
    } else if (upcase) {
      hstr[--pos] = cast(char)('A'+b-10);
    } else {
      hstr[--pos] = cast(char)('a'+b-10);
    }
  } while (num);
  static if (isSigned!T) {
    if (neg) {
      assert(pos > 0);
      hstr[--pos] = '-';
    }
    wrWriteWidth!(lfill, rfill)(width, maxlen, center, hstr[pos..$], (neg && lfill == '0'));
  } else {
    wrWriteWidth!(lfill, rfill)(width, maxlen, center, hstr[pos..$]);
  }
}


// 2**64: 18446744073709551616 (20 chars)
// 2**64: 0x1_0000_0000_0000_0000
// width<0: pad right
private void wrWriteWidthInt(char lfill=' ', char rfill=' ', T)
               (int width,
                int maxlen,
                bool center,
                T numm)
if (isIntegral!T)
{
  import std.traits : isSigned, isMutable, Unqual;
  static if (isMutable!T) alias num = numm; else Unqual!T num = cast(Unqual!T)numm;
  char[22] hstr = void;
  auto pos = hstr.length;
  static if (isSigned!T) {
    static if (T.sizeof == 8) {
      if (num == 0x8000_0000_0000_0000uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-9223372036854775808", (lfill == '0')); return; }
    } else static if (T.sizeof == 4) {
      if (num == 0x8000_0000uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-2147483648", (lfill == '0')); return; }
    } else static if (T.sizeof == 2) {
      if (num == 0x8000uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-32768", (lfill == '0')); return; }
    } else static if (T.sizeof == 1) {
      if (num == 0x80uL) { wrWriteWidth!(lfill, rfill)(width, maxlen, center, "-128", (lfill == '0')); return; }
    }
    bool neg = (num < 0);
    if (neg) num = -num;
  }
  do {
    assert(pos > 0);
    ubyte b = cast(ubyte)(num%10);
    num /= 10;
    hstr[--pos] = cast(char)('0'+b);
  } while (num);
  static if (isSigned!T) {
    if (neg) {
      assert(pos > 0);
      hstr[--pos] = '-';
    }
    wrWriteWidth!(lfill, rfill)(width, maxlen, center, hstr[pos..$], (neg && lfill == '0'));
  } else {
    wrWriteWidth!(lfill, rfill)(width, maxlen, center, hstr[pos..$]);
  }
}


private void wrWriteWidthBool(char lfill=' ', char rfill=' ', T)
               (int width,
                int maxlen,
                bool center,
                T v)
if (isBoolean!T)
{
  wrWriteWidth!(lfill, rfill)(width, maxlen, center, (v ? "true" : "false"));
}


import std.traits : Unqual;
private void wrWriteWidthChar(char lfill=' ', char rfill=' ', T)
               (int width,
                int maxlen,
                bool center,
                T v)
if (is(Unqual!T == char))
{
  char[1] s = v;
  wrWriteWidth!(lfill, rfill)(width, maxlen, center, s);
}

private void wrWriteWidthFloat(char lfill=' ', char rfill=' ', T)
               (int width,
                int maxlen,
                bool center,
                T numm) nothrow @trusted @nogc
if (is(T == float) || is(T == double) || is(T == const float) || is(T == const double) || is(T == immutable float) || is(T == immutable double))
{
  import core.stdc.stdio : snprintf;
  char[256] hstr = void;
  auto len = snprintf(hstr.ptr, hstr.length, "%g", cast(double)numm);
  wrWriteWidth!(lfill, rfill)(width, maxlen, center, hstr[0..len], (numm < 0 && lfill == '0'));
}


////////////////////////////////////////////////////////////////////////////////
private auto WrData (int alen) {
  static struct Data {
    int aidx; // current arg index
    int alen; // number of args
    // changeable
    int width = int.min; // this means 'not specified'
    char widthSign = ' '; // '+', '-', '*' (no sign), ' ' (absent)
    bool widthZeroStarted;
    bool widthWasDigits;
    int maxlen = int.min; // this means 'not specified'
    char maxlenSign = ' '; // '+', '-', '*' (no sign), ' ' (absent)
    bool maxlenZeroStarted;
    bool maxlenWasDigits;
    bool optCenter; // center string?
    char lfchar = ' '; // "left fill"
    char rfchar = ' '; // "right fill"
    int fillhcharIdx; // 0: next will be lfchar, 1: next will be rfchar; 2: no more fills
    string wsep; // separator string for "%|"

    @disable this ();

    this (usize aalen) {
      if (aalen >= 1024) assert(0, "too many arguments for writer");
      alen = cast(int)aalen;
    }

    // set named field
    auto set(string name, T) (in T value) if (__traits(hasMember, this, name)) {
      __traits(getMember, this, name) = value;
      return this;
    }

    // increment current index
    auto incAIdx () {
      ++aidx;
      if (aidx > alen) aidx = alen;
      return this;
    }

    // prepare for next formatted output (reset all format params)
    auto resetFmt () {
      // trick with saving necessary fields
      auto saidx = aidx;
      auto salen = alen;
      this = this.init;
      aidx = saidx;
      alen = salen;
      return this;
    }

    // set filling char
    auto setFillChar (char ch) {
      switch (fillhcharIdx) {
        case 0: lfchar = ch; break;
        case 1: rfchar = ch; break;
        default:
      }
      ++fillhcharIdx;
      return this;
    }

    // prepare to parse integer field
    auto initInt(string name) (char sign) if (__traits(hasMember, this, name)) {
      __traits(getMember, this, name) = (sign == '-' ? -1 : 0);
      __traits(getMember, this, name~"Sign") = sign;
      __traits(getMember, this, name~"ZeroStarted") = false;
      __traits(getMember, this, name~"WasDigits") = false;
      return this;
    }

    // integer field parsing: process next char
    auto putIntChar(string name) (char ch) if (__traits(hasMember, this, name)) {
      bool wd = __traits(getMember, this, name~"WasDigits");
      if (!wd) {
        __traits(getMember, this, name~"ZeroStarted") = (ch == '0');
        __traits(getMember, this, name~"WasDigits") = true;
      }
      int n = __traits(getMember, this, name);
      if (n == int.min) n = 0;
      if (n < 0) {
        n = -(n+1);
        immutable nn = n*10+ch-'0';
        if (nn < n || nn == int.max) assert(0, "integer overflow");
        n = (-nn)-1;
      } else {
        immutable nn = n*10+ch-'0';
        if (nn < n || nn == int.max) assert(0, "integer overflow");
        n = nn;
      }
      __traits(getMember, this, name) = n;
      return this;
    }

    //TODO: do more checks on getInt, getBool, etc.
    auto getInt(string name) () if (__traits(hasMember, this, name)) {
      import std.traits;
      immutable n = __traits(getMember, this, name);
      static if (isSigned!(typeof(n))) {
        return (n < 0 && n != n.min ? n+1 : n);
      } else {
        return n;
      }
    }

    auto getIntDef(string name) () if (__traits(hasMember, this, name)) {
      import std.traits;
      immutable n = __traits(getMember, this, name);
      static if (isSigned!(typeof(n))) {
        if (n == n.min) return 0;
        else if (n < 0) return n+1;
        else return n;
      } else {
        return n;
      }
    }

    string getIntStr(string name) () if (__traits(hasMember, this, name)) {
      import std.conv : to;
      return to!string(getInt!name());
    }

    string getBoolStr(string name) () if (__traits(hasMember, this, name)) {
      return (__traits(getMember, this, name) ? "true" : "false");
    }

   // set fillchar according to width flags
   auto fixWidthFill () {
      if (fillhcharIdx == 0 && widthZeroStarted) {
        lfchar = '0';
        fillhcharIdx = 1;
      }
      return this;
    }
  }

  return Data(alen);
}


////////////////////////////////////////////////////////////////////////////////
// parse (possibly signed) number
template conwritefImpl(string state, string field, string fmt, alias data, AA...)
if (state == "parse-int")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] == '-' || fmt[0] == '+') {
    static assert(fmt.length > 1 && fmt[1] >= '0' && fmt[1] <= '9', "invalid number for '"~field~"'");
    enum conwritefImpl = conwritefImpl!("parse-digits", field, fmt[1..$], data.initInt!field(fmt[0]), AA);
  } else static if (fmt[0] >= '0' && fmt[0] <= '9') {
    enum conwritefImpl = conwritefImpl!("parse-digits", field, fmt, data.initInt!field('*'), AA);
  } else {
    enum conwritefImpl = conwritefImpl!("got-"~field, fmt, data.initInt!field(' '), AA);
  }
}


// parse integer digits
template conwritefImpl(string state, string field, string fmt, alias data, AA...)
if (state == "parse-digits")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] >= '0' && fmt[0] <= '9') {
    enum conwritefImpl = conwritefImpl!(state, field, fmt[1..$], data.putIntChar!field(fmt[0]), AA);
  } else {
    enum conwritefImpl = conwritefImpl!("got-"~field, fmt, data, AA);
  }
}


////////////////////////////////////////////////////////////////////////////////
// got maxlen, done with width parsing
template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "parse-format")
{
  static assert(fmt.length > 0, "invalid format string");
  static assert(fmt[0] == '%', "internal error");
  enum conwritefImpl = conwritefImpl!("parse-options", fmt[1..$], data, AA);
}


// parse options
template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "parse-options")
{
  import std.string : indexOf;
  static if (fmt[0] == '/') {
    enum conwritefImpl = conwritefImpl!(state, fmt[1..$], data.set!"optCenter"(true), AA);
  } else static if (fmt[0] == '~') {
    static assert(fmt.length > 1, "invalid format option: '~'");
    enum conwritefImpl = conwritefImpl!(state, fmt[2..$], data.setFillChar(fmt[1]), AA);
  } else static if (fmt[0] == '\0') {
    enum epos = fmt.indexOf('\0', 1);
    static assert(epos > 0, "unterminated separator option");
    static assert(fmt[epos] == '\0');
    enum conwritefImpl = conwritefImpl!(state, fmt[epos+1..$], data.set!"wsep"(fmt[1..epos]), AA);
  } else {
    enum conwritefImpl = conwritefImpl!("parse-int", "width", fmt, data, AA);
  }
}


// got width, try maxlen
template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "got-width")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] == '.') {
    // got maxlen, parse it
    enum conwritefImpl = conwritefImpl!("parse-int", "maxlen", fmt[1..$], data.fixWidthFill(), AA);
  } else {
    enum conwritefImpl = conwritefImpl!("got-maxlen", fmt, data.fixWidthFill(), AA);
  }
}


// got maxlen, done with width parsing
template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "got-maxlen")
{
  static assert(fmt.length > 0, "invalid format string");
  enum conwritefImpl = conwritefImpl!("format-spec", fmt, data, AA);
}


////////////////////////////////////////////////////////////////////////////////
static template isStaticNarrowString(T) {
  import std.traits : isStaticArray;
  static if (isStaticArray!T) {
    import std.traits : Unqual;
    static alias ArrayElementType(T: T[]) = Unqual!T;
    enum isStaticNarrowString = is(ArrayElementType!T == char);
  } else {
    enum isStaticNarrowString = false;
  }
}

template conwritefImpl(string state, alias data, AA...)
if (state == "write-argument-s")
{
  import std.traits : Unqual;
  import std.conv : to;
  static assert(data.aidx >= 0 && data.aidx < data.alen, "argument index out of range");
  enum aidx = data.aidx;
  alias aatype = /*StripTypedef!*/AA[aidx];
  //pragma(msg, "TYPE: ", Unqual!aatype);
  static if (is(Unqual!aatype == char[]) ||
             is(Unqual!aatype == ConString) ||
             is(aatype == string) ||
             isStaticNarrowString!aatype) {
    //pragma(msg, "STRING!");
    enum callFunc = "wrWriteWidth";
    enum func = "";
  } else static if (isIntegral!aatype) {
    enum callFunc = "wrWriteWidthInt";
    enum func = "";
  } else static if (is(aatype == float) || is(aatype == double) || is(aatype == const float) || is(aatype == const double) || is(aatype == immutable float) || is(aatype == immutable double)) {
    enum callFunc = "wrWriteWidthFloat";
    enum func = "";
  } else static if (isBoolean!aatype) {
    enum callFunc = "wrWriteWidthBool";
    enum func = "";
  } else static if (is(Unqual!aatype == char)) {
    enum callFunc = "wrWriteWidthChar";
    enum func = "";
  } else {
    // this may allocate!
    enum callFunc = "wrWriteWidth";
    enum func = "to!string";
  }
  enum lfchar = data.lfchar;
  enum rfchar = data.rfchar;
  enum conwritefImpl =
    callFunc~"!("~lfchar.stringof~","~rfchar.stringof~")("~
      data.getIntStr!"width"()~","~
      data.getIntStr!"maxlen"()~","~
      data.getBoolStr!"optCenter"()~","~
      func~"(args["~to!string(aidx)~"]));\n";
}


template conwritefImpl(string state, alias data, AA...)
if (state == "write-argument-S")
{
  import std.traits : Unqual;
  import std.conv : to;
  static assert(data.aidx >= 0 && data.aidx < data.alen, "argument index out of range");
  enum aidx = data.aidx;
  alias aatype = /*StripTypedef!*/AA[aidx];
  //pragma(msg, "TYPE: ", Unqual!aatype);
  static if (is(Unqual!aatype == char*) ||
             is(Unqual!aatype == const(char)*) ||
             is(Unqual!aatype == immutable(char)*) ||
             is(Unqual!aatype == const(char*)) ||
             is(Unqual!aatype == immutable(char*))) {
    enum lfchar = data.lfchar;
    enum rfchar = data.rfchar;
    enum conwritefImpl =
      "wrWriteWidthStrZ!("~lfchar.stringof~","~rfchar.stringof~")("~
        data.getIntStr!"width"()~","~
        data.getIntStr!"maxlen"()~","~
        data.getBoolStr!"optCenter"()~","~
        "(cast(const char*)args["~to!string(aidx)~"]));\n";
  } else {
    enum conwritefImpl = conwritefImpl!"write-argument-s"(state, data, AA);
  }
}


template conwritefImpl(string state, bool upcase, alias data, AA...)
if (state == "write-argument-xx")
{
  import std.traits : Unqual;
  import std.conv : to;
  static assert(data.aidx >= 0 && data.aidx < data.alen, "argument index out of range");
  enum aidx = data.aidx;
  private alias TTA = /*StripTypedef!*/AA[aidx];
  static assert(isIntegral!TTA || isPointer!TTA, "'x' expects integer or pointer argument");
  enum lfchar = data.lfchar;
  enum rfchar = data.rfchar;
  enum conwritefImpl =
    "wrWriteWidthHex!("~lfchar.stringof~","~rfchar.stringof~")("~
      data.getIntStr!"width"()~","~
      data.getIntStr!"maxlen"()~","~
      data.getBoolStr!"optCenter"()~","~
      (upcase ? "true," : "false,")~
      (isPointer!TTA ? "cast(usize)" : "cast("~TTA.stringof~")")~
      "(args["~to!string(aidx)~"]));\n";
}


template conwritefImpl(string state, alias data, AA...)
if (state == "write-argument-x")
{
  enum conwritefImpl = conwritefImpl!("write-argument-xx", false, data, AA);
}


template conwritefImpl(string state, alias data, AA...)
if (state == "write-argument-X")
{
  enum conwritefImpl = conwritefImpl!("write-argument-xx", true, data, AA);
}


template conwritefImpl(string state, string field, alias data)
if (state == "write-field")
{
  enum fld = __traits(getMember, data, field);
  static if (fld.length > 0) {
    enum conwritefImpl = "conwriter("~fld.stringof~");\n";
  } else {
    enum conwritefImpl = "";
  }
}


template conwritefImpl(string state, string str, alias data)
if (state == "write-strlit")
{
  static if (str.length > 0) {
    enum conwritefImpl = "conwriter("~str.stringof~");\n";
  } else {
    enum conwritefImpl = "";
  }
}


////////////////////////////////////////////////////////////////////////////////
template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "format-spec")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] == 's' || fmt[0] == 'x' || fmt[0] == 'X' || fmt[0] == 'S') {
    // known specs
    enum conwritefImpl =
      conwritefImpl!("write-argument-"~fmt[0], data, AA)~
      conwritefImpl!("main", fmt[1..$], data.incAIdx(), AA);
  } else static if (fmt[0] == '|') {
    // write all unprocessed arguments
    static if (data.aidx < data.alen) {
      // has argument to process
      static if (data.aidx+1 < data.alen && data.wsep.length > 0) {
        // has separator
        enum conwritefImpl =
          conwritefImpl!("write-argument-s", data, AA)~
          conwritefImpl!("write-field", "wsep", data)~
          conwritefImpl!(state, fmt, data.incAIdx(), AA);
      } else {
        // has no separator
        enum conwritefImpl =
          conwritefImpl!("write-argument-s", data, AA)~
          conwritefImpl!(state, fmt, data.incAIdx(), AA);
      }
    } else {
      // no more arguments
      enum conwritefImpl = conwritefImpl!("main", fmt[1..$], data, AA);
    }
  } else static if (fmt[0] == '@' || fmt[0] == '$') {
    // set current argument index
    // we must have no maxlen here
    static assert(data.maxlenSign == ' ', "invalid position for '@'");
    static if (data.widthSign == '+' || data.widthSign == '-')
      enum newpos = data.aidx+data.getIntDef!"width"()+1;
    else
      enum newpos = data.getIntDef!"width"();
    static assert(newpos >= 1 && newpos <= data.alen+1, "position out of range for '"~fmt[0]~"'");
    static if (fmt[0] == '@' || (fmt.length > 1 && fmt[1] == '%')) {
      enum conwritefImpl = conwritefImpl!("main", fmt[1..$], data.set!"aidx"(newpos-1), AA);
    } else {
      enum conwritefImpl = conwritefImpl!("main", "%"~fmt[1..$], data.set!"aidx"(newpos-1), AA);
    }
  } else {
    static assert(0, "invalid format specifier: '"~fmt[0]~"'");
  }
}


////////////////////////////////////////////////////////////////////////////////
template conwritefImpl(string state, string accum, string fmt, alias data, AA...)
if (state == "main-with-accum")
{
  static if (fmt.length == 0) {
    static assert(data.aidx == data.alen, "too many arguments to writer");
    enum conwritefImpl = conwritefImpl!("write-strlit", accum, data);
  } else static if (fmt[0] == '%') {
    static assert (fmt.length > 1, "invalid format string");
    static if (fmt[1] == '%') {
      // '%%'
      enum conwritefImpl = conwritefImpl!(state, accum~"%", fmt[2..$], data, AA);
    } else static if (fmt[1] == '!') {
      // '%!'
      enum conwritefImpl = conwritefImpl!(state, accum, fmt[2..$], data.set!"aidx"(data.alen), AA);
    } else {
      // other format specifiers
      enum conwritefImpl =
        conwritefImpl!("write-strlit", accum, data)~
        conwritefImpl!("parse-format", fmt, data, AA);
    }
  } else {
    import std.string : indexOf;
    enum ppos = fmt.indexOf('%');
    static if (ppos < 0) {
      // no format specifiers
      enum conwritefImpl = conwritefImpl!("write-strlit", accum~fmt, data);
    } else {
      enum conwritefImpl = conwritefImpl!(state, accum~fmt[0..ppos], fmt[ppos..$], data, AA);
    }
  }
}


////////////////////////////////////////////////////////////////////////////////
template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "main")
{
  enum conwritefImpl = conwritefImpl!("main-with-accum", "", fmt, data.resetFmt(), AA);
}


////////////////////////////////////////////////////////////////////////////////
void fdwritef(string fmt, AA...) (AA args) {
  import std.string : indexOf;
  static if (fmt.indexOf('%') < 0) {
    conwriter(fmt);
  } else {
    import std.conv : to;
    enum mixstr = conwritefImpl!("main", fmt, WrData(AA.length), AA);
    //pragma(msg, "-------\n"~mixstr~"-------");
    mixin(mixstr);
  }
  //conwriter(null);
}


////////////////////////////////////////////////////////////////////////////////
public:

void conwritef(string fmt, A...) (A args) { fdwritef!(fmt)(args); }
void conwritefln(string fmt, A...) (A args) { fdwritef!(fmt~"\n")(args); }
void conwrite(A...) (A args) { fdwritef!("%|")(args); }
void conwriteln(A...) (A args) { fdwritef!("%|\n")(args); }


////////////////////////////////////////////////////////////////////////////////
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
  conwritefln!"<`%3@%3s`>%!"(cast(int)42, "[a]", new A(), n, t);
  //errwriteln("stderr");
  conwritefln!"`%-3s`"(42);
  conwritefln!"`%!z%-2@%-3s`%!"(69, 42, 666);
  conwritefln!"`%!%1@%-3s%!`"(69, 42, 666);
  conwritefln!"`%!%-1@%+0@%-3s%!`"(69, 42, 666);
  conwritefln!"`%3.5s`"("a");
  conwritefln!"`%7.5s`"("abcdefgh");
  conwritef!"%|\n"(42, 666);
  conwritefln!"`%/10.5s`"("abcdefgh");
  conwritefln!"`%/-10.-5s`"("abcdefgh");
  conwritefln!"`%/~+-10.-5s`"("abcdefgh");
  conwritefln!"`%/~+~:-10.-5s`"("abcdefgh");
  conwritef!"%\0<>\0|\n"(42, 666, 999);
  conwritef!"%\0\t\0|\n"(42, 666, 999);
  conwritefln!"`%~*05s %~.5s`"(42, 666);
  conwritef!"`%s`\n"(t);
  conwritef!"`%08s`\n"("alice");
  conwritefln!"#%08x"(16396);
  conwritefln!"#%08X"(-16396);
  conwritefln!"#%02X"(-16385);
  conwritefln!"[%06s]"(-666);
  conwritefln!"[%06s]"(cast(long)0x8000_0000_0000_0000uL);
  conwritefln!"[%06x]"(cast(long)0x8000_0000_0000_0000uL);

  version(aliced) {
    enum TypedefTestStr = q{
      typedef MyInt = int;
      typedef MyString = string;

      MyInt mi = 42;
      MyString ms = cast(MyString)"hurry";
      conwritefln!"%s"(mi);
      conwritefln!"%x"(mi);
      conwritefln!"%s"(ms);

      void testBool () @nogc {
        conwritefln!"%s"(true);
        conwritefln!"%s"(false);
      }
      testBool();

      conwritefln!"Hello, %2$s, I'm %1$s."("Alice", "Miriel");
      conwritef!"%2$7s|\n%1$%7s|\n%||\n"("Alice", "Miriel");
    };
    //mixin(TypedefTestStr);
  }

  void wrflt () nothrow @nogc {
    conwriteln(42.666f);
    conwriteln(cast(double)42.666);
  }
  wrflt();

  immutable char *strz = "stringz\0s";
  conwritefln!"[%S]"(strz);
}


////////////////////////////////////////////////////////////////////////////////
mixin template condump (Names...) {
  auto _xdump_tmp_ = {
    import conwrt : conwrite;
    foreach (auto i, auto name; Names) conwrite(name, " = ", mixin(name), (i < Names.length-1 ? ", " : "\n"));
    return false;
  }();
}

version(conwriter_test)
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

// base console command class
public class ConCommand {
private:
  public import std.conv : ConvException, ConvOverflowException;
  import std.range;
  // this is hack to avoid allocating error exceptions
  // don't do this at home!

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
  string name;
  string help;

  this (string aname, string ahelp=null) { name = aname; help = ahelp; }

  void showHelp () { conwriteln(name, " -- ", help); }

  // can throw, yep
  // cmdline doesn't contain command name
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
      if (w.length > 5) throw exBadBool;
      char[5] tbuf;
      usize pos = 0;
      foreach (char ch; w[]) {
        if (ch >= 'A' && ch <= 'Z') ch += 32; // poor man's tolower
        tbuf.ptr[pos++] = ch;
      }
      w = tbuf[0..w.length];
      switch (w) {
        case "y": case "t":
        case "yes": case "tan":
        case "true": case "on":
        case "1":
          return true;
        case "n": case "f":
        case "no": case "ona":
        case "false": case "off":
        case "0":
          return false;
        default: break;
      }
      throw exBadBool;
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
    } else {
      throw exBadArgType;
    }
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
  private T parseInt(T, TS) (ref TS s) if (isSomeChar!(ElementType!TS) && isIntegral!T && !is(T == enum)) {
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
  private T parseNum(T, TS) (ref TS s) if (isSomeChar!(ElementType!TS) && (isIntegral!T || isFloatingPoint!T) && !is(T == enum)) {
    static if (isIntegral!T) {
      return parseInt!T(s);
    } else {
      import std.conv : parse;
      while (!s.empty) {
        if (s.front > 32) break;
        s.popFront();
      }
      return std.conv.parse!T(s);
    }
  }

  bool checkHelp (scope ConString s) {
    usize pos = 0;
    while (pos < s.length && s.ptr[pos] <= 32) ++pos;
    if (pos == s.length || s.ptr[pos] != '?') return false;
    ++pos;
    while (pos < s.length && s.ptr[pos] <= 32) ++pos;
    return (pos >= s.length);
  }

  bool hasArgs (scope ConString s) {
    usize pos = 0;
    while (pos < s.length && s.ptr[pos] <= 32) ++pos;
    return (pos < s.length);
  }

  void writeQuotedString (scope ConString s) {
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
        case '\e': wrt("e"); break;
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
// variable of some type
public class ConVarBase : ConCommand {
  this (string aname, string ahelp=null) { super(aname, ahelp); }

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
      static if (is(T == string)) setStrValue(val); else setCharValue(val);
    }
  }

protected:
  abstract ulong getIntValue () nothrow @nogc;
  abstract double getDoubleValue () nothrow @nogc;

  abstract void setIntValue (ulong v, bool signed) nothrow @nogc;
  abstract void setDoubleValue (double v) nothrow @nogc;
  abstract void setStrValue (string v) nothrow;
  abstract void setCharValue (ConString v) nothrow;
}


// ////////////////////////////////////////////////////////////////////////// //
class ConVar(T) : ConVarBase {
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
    static if (is(T == bool)) {
      while (cmdline.length && cmdline[0] <= 32) cmdline = cmdline[1..$];
      while (cmdline.length && cmdline[$-1] <= 32) cmdline = cmdline[0..$-1];
      if (cmdline == "toggle") {
        *vptr = !(*vptr);
        return;
      }
    }
    T val = parseType!T(ref cmdline);
    if (hasArgs(cmdline)) throw exTooManyArgs;
    static if (isIntegral!T) {
      if (val < minv) val = minv;
      if (val > maxv) val = maxv;
    }
    *vptr = val;
  }

  override bool isString () const pure nothrow @nogc {
    static if (is(T : ConString)) {
      return true;
    } else {
      return false;
    }
  }

  override ConString strval () nothrow @nogc {
    //conwriteln("*** strval for '", name, "'");
    import core.stdc.stdio : snprintf;
    static if (is(T : ConString)) {
      return *vptr;
    } else static if (is(T == bool)) {
      return (*vptr ? "tan" : "ona");
    } else static if (isIntegral!T) {
      static if (isSigned!T) {
        auto len = snprintf(vbuf.ptr, vbuf.length, "%lld", cast(long)(*vptr));
      } else {
        auto len = snprintf(vbuf.ptr, vbuf.length, "%llu", cast(long)(*vptr));
      }
      return (len >= 0 ? vbuf[0..len] : "?");
    } else static if (isFloatingPoint!T) {
      auto len = snprintf(vbuf.ptr, vbuf.length, "%f", cast(double)(*vptr));
      return (len >= 0 ? vbuf[0..len] : "?");
    }
  }

  protected override ulong getIntValue () nothrow @nogc {
    static if (is(T : ulong) || is(T : double)) return cast(ulong)(*vptr); else return ulong.init;
  }

  protected override double getDoubleValue () nothrow @nogc {
    static if (is(T : double) || is(T : ulong)) return cast(double)(*vptr); else return double.init;
  }

  protected override void setIntValue (ulong v, bool signed) nothrow @nogc {
    static if (is(T : ulong) || is(T : double)) {
      *vptr = cast(T)v;
    } else static if (is(T : ConString)) {
      import core.stdc.stdio : snprintf;
      auto len = snprintf(tvbuf.ptr, tvbuf.length, (signed ? "%lld" : "%llu"), v);
           static if (is(T == string)) *vptr = cast(string)(tvbuf[0..len]); // not really safe, but...
      else static if (is(T == ConString)) *vptr = cast(ConString)(tvbuf[0..len]);
      else static if (is(T == char[])) *vptr = tvbuf[0..len];
    }
  }

  protected override void setDoubleValue (double v) nothrow @nogc {
    static if (is(T : ulong) || is(T : double)) {
      *vptr = cast(T)v;
    } else static if (is(T : ConString)) {
      import core.stdc.stdio : snprintf;
      auto len = snprintf(tvbuf.ptr, tvbuf.length, "%g", v);
           static if (is(T == string)) *vptr = cast(string)(tvbuf[0..len]); // not really safe, but...
      else static if (is(T == ConString)) *vptr = cast(ConString)(tvbuf[0..len]);
      else static if (is(T == char[])) *vptr = tvbuf[0..len];
    }
  }

  protected override void setStrValue (string v) nothrow {
    static if (is(T == string) || is(T == ConString)) {
      *vptr = cast(T)v;
    } else static if (is(T == char[])) {
      *vptr = v.dup;
    }
  }

  protected override void setCharValue (ConString v) nothrow {
         static if (is(T == string)) *vptr = v.idup;
    else static if (is(T == ConString)) *vptr = v;
    else static if (is(T == char[])) *vptr = v.dup;
  }

  override void printValue () {
    //auto wrt = ConWriter;
    alias wrt = conwriter;
    static if (is(T : ConString)) {
      wrt(name);
      wrt(" ");
      writeQuotedString(*vptr);
      wrt("\n");
      //wrt(null); // flush
    } else static if (is(T == bool)) {
      conwriteln(name, " ", (*vptr ? "tan" : "ona"));
    } else {
      conwriteln(name, " ", *vptr);
    }
  }
}


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


public void conRegVar(alias fn, T) (T aminv, T amaxv, string aname, string ahelp=null) if (isIntegral!(typeof(fn)) && isIntegral!T) {
  if (aname.length == 0) aname = (&fn).stringof[2..$]; // HACK
  if (aname.length > 0) {
    addName(aname);
    cmdlist[aname] = new ConVar!(typeof(fn))(&fn, cast(typeof(fn))aminv, cast(typeof(fn))amaxv, aname, ahelp);
  }
}

public void conRegVar(alias fn) (string aname, string ahelp=null) if (!isCallable!(typeof(fn))) {
  if (aname.length == 0) aname = (&fn).stringof[2..$]; // HACK
  if (aname.length > 0) {
    addName(aname);
    cmdlist[aname] = new ConVar!(typeof(fn))(&fn, aname, ahelp);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// delegate
public class ConFuncBase : ConCommand {
  this (string aname, string ahelp=null) { super(aname, ahelp); }
}


public struct ConFuncVA {
  ConString cmdline;
}

// we have to make the class nested, so we can use `dg`, which keeps default args
public void conRegFunc(alias fn) (string aname, string ahelp=null) if (isCallable!fn) {
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
        foreach (auto idx, ref arg; args) {
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
public bool conHasCommand (ConString name) { pragma(inline, true); return ((name in cmdlist) !is null); }

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
public T conGetVar(T=ConString) (ConString s) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) return cv.value!T;
  }
  return T.init;
}


public void conSetVar(T) (ConString s, T val) {
  consoleLock();
  scope(exit) consoleUnlock();
  if (auto cc = s in cmdlist) {
    if (auto cv = cast(ConVarBase)(*cc)) cv.value = val;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// thread-safe
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
version(contest_func) unittest {
  static void xfunc (int v, int x=42) { conwriteln("xfunc: v=", v, "; x=", x); }

  //pragma(msg, typeof(&xfunc), " ", ParameterDefaultValueTuple!xfunc);
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
// return `null` when there is no command
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
