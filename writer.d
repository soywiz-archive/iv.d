/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
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
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
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
 * License: IVPLv0
 */
/* very simple compile-time format writer
 * understands [+|-]width[.maxlen]
 *   negative width: add spaces to right
 *   negative maxlen: get right part
 * specifiers:
 *   's': use to!string to write argument
 *        note that writer can print strings and integrals without allocation
 *   'x': write integer as hex
 *   'X': write integer as HEX
 *   '|': write all arguments that's left with "%s"
 *   '@': go to argument with number 'width' (use sign to relative goto)
 *   '!': skip all arguments that's left, no width allowed
 *   '%': just a percent sign, no width allowed
 * options (must immediately follow '%'):
 *   '/': center string; negative width means "add extra space (if any) to the right"
 *   '~': fill with the following char instead of space
 *        second '~': right filling char for 'center'
 *   '\0'...'\0': separator string for '%|'
 */
module iv.writer is aliced;
private:

private import std.traits : isBoolean, isIntegral, isPointer, StripTypedef;


__gshared void delegate (scope const(char[]), scope int fd=1) @trusted nothrow @nogc  wrwriter;

public @property auto WrWriter () @trusted nothrow @nogc => wrwriter;
public @property auto WrWriter (typeof(wrwriter) cv) @trusted nothrow @nogc { auto res = wrwriter; wrwriter = cv; return res; }


shared static this () {
  wrwriter = (scope str, scope fd) @trusted nothrow @nogc {
    import core.sys.posix.unistd : STDOUT_FILENO, STDERR_FILENO, write;
    if (fd >= 0) {
      if (fd == 0 || fd == 1) fd = STDOUT_FILENO;
      else if (fd == 2) fd = STDERR_FILENO;
      if (str.length > 0) write(fd, str.ptr, str.length);
    }
  };
}


// width<0: pad right
// width == int.min: no width specified
// maxlen == int.min: no maxlen specified
private void wrWriteWidth(char lfill=' ', char rfill=' ')
               (int fd,
                int width,
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
    width = cast(int)s.length-stpos;
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
        wrwriter(spacesl, fd);
        spleft -= spacesl.length;
        continue;
      } else {
        wrwriter(spacesl[0..spleft], fd);
        break;
      }
    }
    if (maxlen > 0) wrwriter(s[stpos..stpos+maxlen], fd);
    while (spright > 0) {
      if (spright > spacesr.length) {
        wrwriter(spacesr, fd);
        spright -= spacesr.length;
        continue;
      } else {
        wrwriter(spacesr[0..spright], fd);
        break;
      }
    }
  } else {
    // pad string
    bool writeS = true;
    if (width < 0) {
      // right padding, write string
      width = -width;
      if (maxlen > 0) wrwriter(s[stpos..stpos+maxlen], fd);
      writeS = false;
    }
    if (maxlen < width) {
      width -= maxlen;
      if (writeS && stpos == 0 && leftIsMinus && width > 0) {
        wrwriter("-", fd);
        // remove '-'
        ++stpos;
        --maxlen;
      }
      for (;;) {
        if (width > spacesl.length) {
          if (writeS) wrwriter(spacesl, fd); else wrwriter(spacesr, fd);
          width -= spacesl.length;
        } else {
          if (writeS) wrwriter(spacesl[0..width], fd); else wrwriter(spacesr[0..width], fd);
          break;
        }
      }
    }
    if (writeS && maxlen > 0) wrwriter(s[stpos..stpos+maxlen], fd);
  }
}


private void wrWriteWidthHex(char lfill=' ', char rfill=' ', T)
               (int fd,
                int width,
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
      if (num == 0x8000_0000_0000_0000uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-8000000000000000", (lfill == '0')); return; }
    } else static if (T.sizeof == 4) {
      if (num == 0x8000_0000uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-80000000", (lfill == '0')); return; }
    } else static if (T.sizeof == 2) {
      if (num == 0x8000uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-8000", (lfill == '0')); return; }
    } else static if (T.sizeof == 1) {
      if (num == 0x80uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-80", (lfill == '0')); return; }
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
    wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, hstr[pos..$], (neg && lfill == '0'));
  } else {
    wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, hstr[pos..$]);
  }
}


// 2**64: 18446744073709551616 (20 chars)
// 2**64: 0x1_0000_0000_0000_0000
// width<0: pad right
private void wrWriteWidthInt(char lfill=' ', char rfill=' ', T)
               (int fd,
                int width,
                int maxlen,
                bool center,
                T numm)
if (isIntegral!T)
{
  import std.traits : isSigned, isMutable, Unqual;
  static if (isMutable!T) alias num = numm; else Unqual!T num = cast(Unqual!T)numm;
  char[22] hstr;
  auto pos = hstr.length;
  static if (isSigned!T) {
    static if (T.sizeof == 8) {
      if (num == 0x8000_0000_0000_0000uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-9223372036854775808", (lfill == '0')); return; }
    } else static if (T.sizeof == 4) {
      if (num == 0x8000_0000uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-2147483648", (lfill == '0')); return; }
    } else static if (T.sizeof == 2) {
      if (num == 0x8000uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-32768", (lfill == '0')); return; }
    } else static if (T.sizeof == 1) {
      if (num == 0x80uL) { wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, "-128", (lfill == '0')); return; }
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
    wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, hstr[pos..$], (neg && lfill == '0'));
  } else {
    wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, hstr[pos..$]);
  }
}


private void wrWriteWidthBool(char lfill=' ', char rfill=' ', T)
               (int fd,
                int width,
                int maxlen,
                bool center,
                T v)
if (isBoolean!T)
{
  wrWriteWidth!(lfill, rfill)(fd, width, maxlen, center, (v ? "true" : "false"));
}


////////////////////////////////////////////////////////////////////////////////
private auto WrData (int fd, int alen) {
  static struct Data {
    string fd; // just to pass to writers; string, 'cause we will concat it with other strings
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

    this (int afd, usize aalen) {
      import std.conv : to;
      fd = to!string(afd);
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
      auto sfd = fd;
      auto saidx = aidx;
      auto salen = alen;
      this = this.default;
      fd = sfd;
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

  return Data(fd, alen);
}


////////////////////////////////////////////////////////////////////////////////
// parse (possibly signed) number
template writefImpl(string state, string field, string fmt, alias data, AA...)
if (state == "parse-int")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] == '-' || fmt[0] == '+') {
    static assert(fmt.length > 1 && fmt[1] >= '0' && fmt[1] <= '9', "invalid number for '"~field~"'");
    enum writefImpl = writefImpl!("parse-digits", field, fmt[1..$], data.initInt!field(fmt[0]), AA);
  } else static if (fmt[0] >= '0' && fmt[0] <= '9') {
    enum writefImpl = writefImpl!("parse-digits", field, fmt, data.initInt!field('*'), AA);
  } else {
    enum writefImpl = writefImpl!("got-"~field, fmt, data.initInt!field(' '), AA);
  }
}


// parse integer digits
template writefImpl(string state, string field, string fmt, alias data, AA...)
if (state == "parse-digits")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] >= '0' && fmt[0] <= '9') {
    enum writefImpl = writefImpl!(state, field, fmt[1..$], data.putIntChar!field(fmt[0]), AA);
  } else {
    enum writefImpl = writefImpl!("got-"~field, fmt, data, AA);
  }
}


////////////////////////////////////////////////////////////////////////////////
// got maxlen, done with width parsing
template writefImpl(string state, string fmt, alias data, AA...)
if (state == "parse-format")
{
  static assert(fmt.length > 0, "invalid format string");
  static assert(fmt[0] == '%', "internal error");
  enum writefImpl = writefImpl!("parse-options", fmt[1..$], data, AA);
}


// parse options
template writefImpl(string state, string fmt, alias data, AA...)
if (state == "parse-options")
{
  import std.string : indexOf;
  static if (fmt[0] == '/') {
    enum writefImpl = writefImpl!(state, fmt[1..$], data.set!"optCenter"(true), AA);
  } else static if (fmt[0] == '~') {
    static assert(fmt.length > 1, "invalid format option: '~'");
    enum writefImpl = writefImpl!(state, fmt[2..$], data.setFillChar(fmt[1]), AA);
  } else static if (fmt[0] == '\0') {
    enum epos = fmt.indexOf('\0', 1);
    static assert(epos > 0, "unterminated separator option");
    static assert(fmt[epos] == '\0');
    enum writefImpl = writefImpl!(state, fmt[epos+1..$], data.set!"wsep"(fmt[1..epos]), AA);
  } else {
    enum writefImpl = writefImpl!("parse-int", "width", fmt, data, AA);
  }
}


// got width, try maxlen
template writefImpl(string state, string fmt, alias data, AA...)
if (state == "got-width")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] == '.') {
    // got maxlen, parse it
    enum writefImpl = writefImpl!("parse-int", "maxlen", fmt[1..$], data.fixWidthFill(), AA);
  } else {
    enum writefImpl = writefImpl!("got-maxlen", fmt, data.fixWidthFill(), AA);
  }
}


// got maxlen, done with width parsing
template writefImpl(string state, string fmt, alias data, AA...)
if (state == "got-maxlen")
{
  static assert(fmt.length > 0, "invalid format string");
  enum writefImpl = writefImpl!("format-spec", fmt, data, AA);
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

template writefImpl(string state, alias data, AA...)
if (state == "write-argument-s")
{
  import std.traits : Unqual;
  import std.conv : to;
  static assert(data.aidx >= 0 && data.aidx < data.alen, "argument index out of range");
  enum aidx = data.aidx;
  alias aatype = StripTypedef!(AA[aidx]);
  //pragma(msg, "TYPE: ", Unqual!aatype);
  static if (is(Unqual!aatype == char[]) ||
             is(Unqual!aatype == const(char)[]) ||
             is(aatype == string) ||
             isStaticNarrowString!aatype) {
    //pragma(msg, "STRING!");
    enum callFunc = "wrWriteWidth";
    enum func = "";
  } else static if (isIntegral!aatype) {
    enum callFunc = "wrWriteWidthInt";
    enum func = "";
  } else static if (isBoolean!aatype) {
    enum callFunc = "wrWriteWidthBool";
    enum func = "";
  } else {
    // this may allocate!
    enum callFunc = "wrWriteWidth";
    enum func = "to!string";
  }
  enum lfchar = data.lfchar;
  enum rfchar = data.rfchar;
  enum writefImpl =
    callFunc~"!("~lfchar.stringof~","~rfchar.stringof~")("~
      data.fd~","~
      data.getIntStr!"width"()~","~
      data.getIntStr!"maxlen"()~","~
      data.getBoolStr!"optCenter"()~","~
      func~"(args["~to!string(aidx)~"]));\n";
}


template writefImpl(string state, bool upcase, alias data, AA...)
if (state == "write-argument-xx")
{
  import std.traits : Unqual;
  import std.conv : to;
  static assert(data.aidx >= 0 && data.aidx < data.alen, "argument index out of range");
  enum aidx = data.aidx;
  private alias TTA = StripTypedef!(AA[aidx]);
  static assert(isIntegral!TTA || isPointer!TTA, "'x' expects integer or pointer argument");
  enum lfchar = data.lfchar;
  enum rfchar = data.rfchar;
  enum writefImpl =
    "wrWriteWidthHex!("~lfchar.stringof~","~rfchar.stringof~")("~
      data.fd~","~
      data.getIntStr!"width"()~","~
      data.getIntStr!"maxlen"()~","~
      data.getBoolStr!"optCenter"()~","~
      (upcase ? "true," : "false,")~
      (isPointer!TTA ? "cast(usize)" : "cast("~TTA.stringof~")")~
      "(args["~to!string(aidx)~"]));\n";
}


template writefImpl(string state, alias data, AA...)
if (state == "write-argument-x")
{
  enum writefImpl = writefImpl!("write-argument-xx", false, data, AA);
}


template writefImpl(string state, alias data, AA...)
if (state == "write-argument-X")
{
  enum writefImpl = writefImpl!("write-argument-xx", true, data, AA);
}


template writefImpl(string state, string field, alias data)
if (state == "write-field")
{
  enum fld = __traits(getMember, data, field);
  static if (fld.length > 0) {
    enum writefImpl = "wrwriter("~fld.stringof~", "~data.fd~");\n";
  } else {
    enum writefImpl = "";
  }
}


template writefImpl(string state, string str, alias data)
if (state == "write-strlit")
{
  static if (str.length > 0) {
    enum writefImpl = "wrwriter("~str.stringof~", "~data.fd~");\n";
  } else {
    enum writefImpl = "";
  }
}


////////////////////////////////////////////////////////////////////////////////
template writefImpl(string state, string fmt, alias data, AA...)
if (state == "format-spec")
{
  static assert(fmt.length > 0, "invalid format string");
  static if (fmt[0] == 's' || fmt[0] == 'x' || fmt[0] == 'X') {
    // known specs
    enum writefImpl =
      writefImpl!("write-argument-"~fmt[0], data, AA)~
      writefImpl!("main", fmt[1..$], data.incAIdx(), AA);
  } else static if (fmt[0] == '|') {
    // write all unprocessed arguments
    static if (data.aidx < data.alen) {
      // has argument to process
      static if (data.aidx+1 < data.alen && data.wsep.length > 0) {
        // has separator
        enum writefImpl =
          writefImpl!("write-argument-s", data, AA)~
          writefImpl!("write-field", "wsep", data)~
          writefImpl!(state, fmt, data.incAIdx(), AA);
      } else {
        // has no separator
        enum writefImpl =
          writefImpl!("write-argument-s", data, AA)~
          writefImpl!(state, fmt, data.incAIdx(), AA);
      }
    } else {
      // no more arguments
      enum writefImpl = writefImpl!("main", fmt[1..$], data, AA);
    }
  } else static if (fmt[0] == '@') {
    // set current argument index
    // we must have no maxlen here
    static assert(data.maxlenSign == ' ', "invalid position for '@'");
    static if (data.widthSign == '+' || data.widthSign == '-')
      enum newpos = data.aidx+data.getIntDef!"width"();
    else
      enum newpos = data.getIntDef!"width"();
    static assert(newpos >= 0 && newpos <= data.alen, "position out of range for '@'");
    enum writefImpl = writefImpl!("main", fmt[1..$], data.set!"aidx"(newpos), AA);
  } else {
    static assert(0, "invalid format specifier: '"~fmt[0]~"'");
  }
}


////////////////////////////////////////////////////////////////////////////////
template writefImpl(string state, string accum, string fmt, alias data, AA...)
if (state == "main-with-accum")
{
  static if (fmt.length == 0) {
    static assert(data.aidx == data.alen, "too many arguments to writer");
    enum writefImpl = writefImpl!("write-strlit", accum, data);
  } else static if (fmt[0] == '%') {
    static assert (fmt.length > 1, "invalid format string");
    static if (fmt[1] == '%') {
      // '%%'
      enum writefImpl = writefImpl!(state, accum~"%", fmt[2..$], data, AA);
    } else static if (fmt[1] == '!') {
      // '%!'
      enum writefImpl = writefImpl!(state, accum, fmt[2..$], data.set!"aidx"(data.alen), AA);
    } else {
      // other format specifiers
      enum writefImpl =
        writefImpl!("write-strlit", accum, data)~
        writefImpl!("parse-format", fmt, data, AA);
    }
  } else {
    import std.string : indexOf;
    enum ppos = fmt.indexOf('%');
    static if (ppos < 0) {
      // no format specifiers
      enum writefImpl = writefImpl!("write-strlit", accum~fmt, data);
    } else {
      enum writefImpl = writefImpl!(state, accum~fmt[0..ppos], fmt[ppos..$], data, AA);
    }
  }
}


////////////////////////////////////////////////////////////////////////////////
template writefImpl(string state, string fmt, alias data, AA...)
if (state == "main")
{
  enum writefImpl = writefImpl!("main-with-accum", "", fmt, data.resetFmt(), AA);
}


////////////////////////////////////////////////////////////////////////////////
void wrwritef(int fd, string fmt, AA...) (AA args) {
  import std.string : indexOf;
  static if (fmt.indexOf('%') < 0) {
    wrwriter(fmt, fd);
  } else {
    import std.conv : to;
    enum mixstr = writefImpl!("main", fmt, WrData(fd, AA.length), AA);
    //pragma(msg, "-------\n"~mixstr~"-------");
    mixin(mixstr);
  }
  wrwriter(null, fd);
}


////////////////////////////////////////////////////////////////////////////////
public:

void fdwritef(int fd, string fmt, A...) (A args) => wrwritef!(fd, fmt)(args);
void fdwrite(int fd, A...) (A args) => wrwritef!(fd, "%|")(args);
void fdwriteln(int fd, A...) (A args) => wrwritef!(fd, "%|\n")(args);

void writef(string fmt, A...) (A args) => wrwritef!(1, fmt)(args);
void errwritef(string fmt, A...) (A args) => wrwritef!(2, fmt)(args);

void writefln(string fmt, A...) (A args) => wrwritef!(1, fmt~"\n")(args);
void errwritefln(string fmt, A...) (A args) => wrwritef!(2, fmt~"\n")(args);

void write(A...) (A args) => wrwritef!(1, "%|")(args);
void errwrite(A...) (A args) => wrwritef!(2, "%|")(args);

void writeln(A...) (A args) => wrwritef!(1, "%|\n")(args);
void errwriteln(A...) (A args) => wrwritef!(2, "%|\n")(args);


////////////////////////////////////////////////////////////////////////////////
version(writer_test)
unittest {
  class A {
    override string toString () const => "{A}";
  }

  char[] n = ['x', 'y', 'z'];
  char[3] t = "def";//['d', 'e', 'f'];
  wrwriter("========================\n");
  writef!"`%%`\n"();
  writef!"`%-3s`\n"(42);
  writef!"<`%3s`%%{str=%s}%|>\n"(cast(int)42, "[a]", new A(), n, t[]);
  writefln!"<`%2@%3s`>%!"(cast(int)42, "[a]", new A(), n, t);
  errwriteln("stderr");
  writefln!"`%-3s`"(42);
  writefln!"`%!z%-2@%-3s`%!"(69, 42, 666);
  writefln!"`%!%0@%-3s%!`"(69, 42, 666);
  writefln!"`%!%-1@%+0@%-3s%!`"(69, 42, 666);
  writefln!"`%3.5s`"("a");
  writefln!"`%7.5s`"("abcdefgh");
  writef!"%|\n"(42, 666);
  writefln!"`%/10.5s`"("abcdefgh");
  writefln!"`%/-10.-5s`"("abcdefgh");
  writefln!"`%/~+-10.-5s`"("abcdefgh");
  writefln!"`%/~+~:-10.-5s`"("abcdefgh");
  writef!"%\0<>\0|\n"(42, 666, 999);
  writef!"%\0\t\0|\n"(42, 666, 999);
  writefln!"`%~*05s %~.5s`"(42, 666);
  writef!"`%s`\n"(t);
  writef!"`%08s`\n"("alice");
  writefln!"#%08x"(16396);
  writefln!"#%08X"(-16396);
  writefln!"#%02X"(-16385);
  writefln!"[%06s]"(-666);
  writefln!"[%06s]"(cast(long)0x8000_0000_0000_0000uL);
  writefln!"[%06x]"(cast(long)0x8000_0000_0000_0000uL);

  typedef MyInt = int;
  typedef MyString = string;

  MyInt mi = 42;
  MyString ms = cast(MyString)"hurry";
  writefln!"%s"(mi);
  writefln!"%x"(mi);
  writefln!"%s"(ms);

  void testBool () @nogc {
    writefln!"%s"(true);
    writefln!"%s"(false);
  }
  testBool();
}
