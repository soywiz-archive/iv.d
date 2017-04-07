/* Invisible Vector Library.
 * simple FlexBox-based TUI engine
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
module iv.egeditor.editor;

//version = egeditor_scan_time;
version = egeditor_line_cache_checks;

import iv.rawtty : koi2uni, uni2koi;
import iv.strex;
import iv.utfutil;
import iv.vfs;
debug import iv.vfs.io;

static if (!is(typeof(object.usize))) private alias usize = size_t;

version(egeditor_scan_time) import iv.pxclock;


// ////////////////////////////////////////////////////////////////////////// //
/// this interface is used to measure text for pixel-sized editor
abstract class EgTextMeter {
  int currofs; /// current x offset; keep this in sync with the current state
  int currheight; /// current text height; keep this in sync with the current state; `reset` should set it to "default text height"

  /// this should reset text width iterator (and curr* fields); tabsize > 0: process tabs as... well... tabs ;-)
  abstract void reset (int tabsize) nothrow;

  /// advance text width iterator, return x position for drawing next char
  abstract int advance (dchar ch) nothrow;

  /// advance text width iterator, return x position for drawing next char; override this if text size depends of attrs
  int advance (dchar ch, in ref GapBuffer.HighState hs) nothrow { return advance(ch); }

  /// return current string width, including last char passed to `advance()`, preferably without spacing after last char
  abstract int currWidth () nothrow;

  /// finish text iterator; it should NOT reset curr* fields!
  /// WARNING: EditorEngine tries to call this after each `reset()`, but user code may not
  abstract void finish () nothrow;
}


// ////////////////////////////////////////////////////////////////////////// //
/// highlighter should be able to work line-by-line
class EditorHL {
protected:
  GapBuffer gb; /// this will be set by EditorEngine on attaching
  LineCache lc; /// this will be set by EditorEngine on attaching

public:
  this () {} ///

  /// return true if highlighting for this line was changed
  abstract bool fixLine (int line);

  /// mark line as "need rehighlighting" (and possibly other text too)
  /// wasInsDel: some lines was inserted/deleted down the text
  abstract void lineChanged (int line, bool wasInsDel);
}


// ////////////////////////////////////////////////////////////////////////// //
///
public final class GapBuffer {
public:
  static align(1) struct HighState {
  align(1):
    ubyte kwtype; // keyword number
    ubyte kwidx; // index in keyword
    @property pure nothrow @safe @nogc {
      ushort u16 () const { pragma(inline, true); return cast(ushort)((kwidx<<8)|kwtype); }
      short s16 () const { pragma(inline, true); return cast(short)((kwidx<<8)|kwtype); }
      void u16 (ushort v) { pragma(inline, true); kwtype = v&0xff; kwidx = (v>>8)&0xff; }
      void s16 (short v) { pragma(inline, true); kwtype = v&0xff; kwidx = (v>>8)&0xff; }
    }
  }

private:
  HighState hidummy;
  bool mSingleLine;

protected:
  enum MinGapSize = 1024; // bytes in gap
  enum GrowGran = 65536; // must be power of 2
  enum MinGapSizeSmall = 64; // bytes in gap
  enum GrowGranSmall = 0x100; // must be power of 2

  static assert(GrowGran >= MinGapSize);
  static assert(GrowGranSmall >= MinGapSizeSmall);

  @property uint MGS () const pure nothrow @safe @nogc { pragma(inline, true); return (mSingleLine ? MinGapSizeSmall : MinGapSize); }

protected:
  char* tbuf; // text buffer
  HighState* hbuf; // highlight buffer
  uint tbused; // not including gap
  uint tbsize; // including gap
  uint tbmax = 512*1024*1024+MinGapSize; // maximum buffer size
  uint gapstart, gapend; // tbuf[gapstart..gapend]; gap cannot be empty
  uint bufferChangeCounter; // will simply increase on each buffer change

  static private bool xrealloc(T) (ref T* ptr, ref uint cursize, int newsize, uint gran) nothrow @trusted @nogc {
    import core.stdc.stdlib : realloc;
    assert(gran > 1);
    uint nsz = ((newsize+gran-1)/gran)*gran;
    assert(nsz >= newsize);
    T* nb = cast(T*)realloc(ptr, nsz*T.sizeof);
    if (nb is null) return false;
    cursize = nsz;
    ptr = nb;
    return true;
  }

final:
  // initial alloc
  void initTBuf () nothrow @nogc {
    import core.stdc.stdlib : free, malloc, realloc;
    assert(tbuf is null);
    assert(hbuf is null);
    immutable uint nsz = (mSingleLine ? GrowGranSmall : GrowGran);
    tbuf = cast(char*)malloc(nsz);
    if (tbuf is null) assert(0, "out of memory for text buffers");
    // don't allocate highlight buffer right now; wait until owner asks for it explicitly
    tbused = 0;
    tbsize = nsz;
    gapstart = 0;
    gapend = tbsize;
  }

  // ensure that we can place a text of size `size` in buffer, and will still have at least MGS bytes free
  // may change `tbsize`, but will not touch `tbused`
  bool growTBuf (uint size) nothrow @nogc {
    if (size > tbmax) return false; // too big
    immutable uint mingapsize = MGS; // desired gap buffer size
    immutable uint unused = tbsize-tbused; // number of unused bytes in buffer
    assert(tbused <= tbsize);
    if (size <= tbused && unused >= mingapsize) return true; // nothing to do, we have enough room in buffer
    // if the gap is bigger than the minimal gap size, check if we have enough extra bytes to avoid allocation
    if (unused > mingapsize) {
      immutable uint extra = unused-mingapsize; // extra bytes we can spend
      immutable uint bgrow = size-tbused; // number of bytes we need
      if (extra >= bgrow) return true; // yay, no need to realloc
    }
    // have to grow
    immutable uint newsz = size+mingapsize;
    immutable uint gran = (mSingleLine ? GrowGranSmall : GrowGran);
    uint hbufsz = tbsize;
    if (!xrealloc(tbuf, tbsize, newsz, gran)) return false;
    // reallocate highlighting buffer only if we already have one
    if (hbuf !is null) {
      if (!xrealloc(hbuf, hbufsz, newsz, gran)) { tbsize = hbufsz; return false; } // HACK!
      assert(tbsize == hbufsz);
    }
    assert(tbsize >= newsz);
    return true;
  }

protected:
  uint pos2real (uint pos) const pure @safe nothrow @nogc {
    pragma(inline, true);
    return pos+(pos >= gapstart ? gapend-gapstart : 0);
  }

public:
  HighState defhs; /// default highlighting state for new text

public:
  ///
  this (bool asingleline) nothrow @nogc {
    mSingleLine = asingleline;
    initTBuf();
  }

  ///
  ~this () nothrow @nogc {
    import core.stdc.stdlib : free;
    if (tbuf !is null) free(tbuf);
    if (hbuf !is null) free(hbuf);
  }

  /// remove all text from buffer
  /// WILL NOT call deletion hooks!
  void clear () nothrow @nogc {
    import core.stdc.stdlib : free;
    if (tbuf !is null) { free(tbuf); tbuf = null; }
    if (hbuf !is null) { free(hbuf); hbuf = null; }
    ++bufferChangeCounter;
    initTBuf();
  }

  @property bool hasHiBuffer () const pure nothrow @safe @nogc { pragma(inline, true); return (hbuf !is null); } ///

  /// after calling this with `true`, `hasHiBuffer` may still be false if there is no memory for it
  @property void hasHiBuffer (bool v) nothrow @trusted @nogc {
    if (v != hasHiBuffer) {
      if (v) {
        // create highlighting buffer
        import core.stdc.stdlib : malloc;
        assert(hbuf is null);
        assert(tbsize > 0);
        hbuf = cast(HighState*)malloc(tbsize*hbuf[0].sizeof);
        if (hbuf !is null) hbuf[0..tbsize] = HighState.init;
      } else {
        // remove highlighitng buffer
        import core.stdc.stdlib : free;
        assert(hbuf !is null);
        free(hbuf);
        hbuf = null;
      }
    }
  }

  /// "single line" mode, for line editors
  bool singleline () const pure @safe nothrow @nogc { pragma(inline, true); return mSingleLine; }

  /// size of text buffer without gap, in one-byte chars
  @property int textsize () const pure @safe nothrow @nogc { pragma(inline, true); return tbused; }

  @property char opIndex (uint pos) const pure @trusted nothrow @nogc { pragma(inline, true); return (pos < tbused ? tbuf[pos+(pos >= gapstart ? gapend-gapstart : 0)] : '\n'); } ///
  @property ref HighState hi (uint pos) pure @trusted nothrow @nogc { pragma(inline, true); return (hbuf !is null && pos < tbused ? hbuf[pos+(pos >= gapstart ? gapend-gapstart : 0)] : (hidummy = hidummy.init)); } ///

  @property dchar uniAt (uint pos) const @trusted nothrow @nogc {
    immutable ts = tbused;
    if (pos >= ts) return '\n';
    Utf8DecoderFast udc;
    while (pos < ts) {
      if (udc.decodeSafe(cast(ubyte)tbuf[pos2real(pos++)])) return udc.codepoint;
    }
    return udc.codepoint;
  }

  /// return utf-8 character length at buffer position pos or -1 on error (or 1 on error if "always positive")
  /// never returns zero
  int utfuckLenAt(bool alwaysPositive=true) (int pos) const @trusted nothrow @nogc {
    immutable ts = tbused;
    if (pos < 0 || pos >= ts) {
      static if (alwaysPositive) return 1; else return -1;
    }
    char ch = tbuf[pos2real(pos)];
    if (ch < 128) return 1;
    Utf8DecoderFast udc;
    auto spos = pos;
    while (pos < ts) {
      ch = tbuf[pos2real(pos++)];
      if (udc.decode(cast(ubyte)ch)) {
        static if (alwaysPositive) {
          return (udc.invalid ? 1 : pos-spos);
        } else {
          return (udc.invalid ? -1 : pos-spos);
        }
      }
    }
    static if (alwaysPositive) return 1; else return -1;
  }

  // ensure that the buffer has room for at least one char in the gap
  // note that this may move gap
  protected void ensureGap () pure @safe nothrow @nogc {
    pragma(inline, true);
    // if we have zero-sized gap, assume that it is at end; we always have a room for at least MinGapSize(Small) chars
    if (gapstart >= gapend || gapstart >= tbused) {
      assert(tbused <= tbsize);
      gapstart = tbused;
      gapend = tbsize;
      assert(gapend-gapstart >= MGS);
    }
  }

  /// put the gap *before* `pos`
  void moveGapAtPos (int pos) @trusted nothrow @nogc {
    import core.stdc.string : memmove;
    immutable ts = tbused; // i will need it in several places
    if (pos < 0) pos = 0;
    if (pos > ts) pos = ts;
    if (ts == 0) { gapstart = 0; gapend = tbsize; return; } // unlikely case, but...
    ensureGap(); // we should have a gap
    /* cases:
     *  pos is before gap: shift [pos..gapstart] to gapend-len, shift gap
     *  pos is after gap: shift [gapend..pos] to gapstart, shift gap
     */
    if (pos < gapstart) {
      // pos is before gap
      int len = gapstart-pos; // to shift
      memmove(tbuf+gapend-len, tbuf+pos, len);
      if (hbuf !is null) memmove(hbuf+gapend-len, hbuf+pos, len*hbuf[0].sizeof);
      gapstart -= len;
      gapend -= len;
    } else if (pos > gapstart) {
      // pos is after gap
      int len = pos-gapstart;
      memmove(tbuf+gapstart, tbuf+gapend, len);
      if (hbuf !is null) memmove(hbuf+gapstart, hbuf+gapend, len*hbuf[0].sizeof);
      gapstart += len;
      gapend += len;
    }
    // if we moved gap to buffer end, grow it; `ensureGap()` will do it for us
    ensureGap();
    assert(gapstart == pos);
    assert(gapstart < gapend);
    assert(gapstart <= ts);
  }

  /// put the gap at the end of the text
  void moveGapAtEnd () @trusted nothrow @nogc { moveGapAtPos(tbused); }

  /// put text into buffer; will either put all the text, or nothing
  /// returns success flag
  bool append (const(char)[] str...) @trusted nothrow @nogc { return (put(tbused, str) >= 0); }

  /// put text into buffer; will either put all the text, or nothing
  /// returns new position or -1
  int put (int pos, const(char)[] str...) @trusted nothrow @nogc {
    import core.stdc.string : memcpy;
    if (pos < 0) pos = 0;
    bool atend = (pos >= tbused);
    if (atend) pos = tbused;
    if (str.length == 0) return pos;
    if (tbmax-(tbsize-tbused) < str.length) return -1; // no room
    if (!growTBuf(tbused+cast(uint)str.length)) return -1; // memory allocation failed
    //TODO: this can be made faster, but meh...
    immutable slen = cast(uint)str.length;
    if (atend || gapend-gapstart < slen) moveGapAtEnd(); // this will grow the gap, so it will take all available room
    if (!atend) moveGapAtPos(pos); // very small speedup
    assert(gapend-gapstart >= slen);
    memcpy(tbuf+gapstart, str.ptr, str.length);
    if (hbuf !is null) hbuf[gapstart..gapstart+str.length] = defhs;
    gapstart += slen;
    tbused += slen;
    pos += slen;
    ensureGap();
    assert(tbsize-tbused >= MGS);
    ++bufferChangeCounter;
    return pos;
  }

  /// remove count bytes from the current position; will either remove all of 'em, or nothing
  /// returns success flag
  bool remove (int pos, int count) @trusted nothrow @nogc {
    import core.stdc.string : memmove;
    if (count < 0) return false;
    if (count == 0) return true;
    immutable ts = tbused; // cache current text size
    if (pos < 0) pos = 0;
    if (pos > ts) pos = ts;
    if (ts-pos < count) return false; // not enough text here
    assert(gapstart < gapend);
    ++bufferChangeCounter; // buffer will definitely be changed
    for (;;) {
      // at the start of the gap: i can just increase gap
      if (pos == gapstart) {
        gapend += count;
        tbused -= count;
        return true;
      }
      // removing text just before gap: increase gap (backspace does this)
      if (pos+count == gapstart) {
        gapstart -= count;
        tbused -= count;
        assert(gapstart == pos);
        return true;
      }
      // both variants failed; move gap at `pos` and try again
      moveGapAtPos(pos);
    }
  }

  /// count how much eols we have in this range
  int countEolsInRange (int pos, int count) const @trusted nothrow @nogc {
    import core.stdc.string : memchr;
    if (count < 1 || pos <= -count || pos >= tbused) return 0;
    if (pos+count > tbused) count = tbused-pos;
    int res = 0;
    while (count > 0) {
      int npos = fastFindCharIn(pos, count, '\n')+1;
      if (npos <= 0) break;
      ++res;
      count -= (npos-pos);
      pos = npos;
    }
    return res;
  }

  /// using `memchr`, jumps over gap; never moves after `tbused`
  public uint fastSkipEol (int pos) const @trusted nothrow @nogc {
    import core.stdc.string : memchr;
    immutable ts = tbused;
    if (ts == 0 || pos >= ts) return ts;
    if (pos < 0) pos = 0;
    // check text before gap
    if (pos < gapstart) {
      auto fp = cast(char*)memchr(tbuf+pos, '\n', gapstart-pos);
      if (fp !is null) return cast(int)(fp-tbuf)+1;
      pos = gapstart; // new starting position
    }
    assert(pos >= gapstart);
    // check after gap and to text end
    int left = ts-pos;
    if (left > 0) {
      auto stx = tbuf+gapend+(pos-gapstart);
      assert(cast(usize)(tbuf+tbsize-stx) >= left);
      auto fp = cast(char*)memchr(stx, '\n', left);
      if (fp !is null) return pos+cast(int)(fp-stx)+1;
    }
    return ts;
  }

  /// using `memchr`, jumps over gap; returns `tbused` if not found
  public uint fastFindChar (int pos, char ch) const @trusted nothrow @nogc {
    int res = fastFindCharIn(pos, tbused, ch);
    return (res >= 0 ? res : tbused);
  }

  /// use `memchr`, jumps over gap; returns -1 if not found
  public int fastFindCharIn (int pos, int len, char ch) const @trusted nothrow @nogc {
    import core.stdc.string : memchr;
    immutable ts = tbused;
    if (len < 1) return -1;
    if (ts == 0 || pos >= ts) return -1;
    if (pos < 0) {
      if (pos <= -len) return -1;
      len += pos;
      pos = 0;
    }
    if (tbused-pos < len) len = tbused-pos;
    assert(len > 0);
    int left;
    // check text before gap
    if (pos < gapstart) {
      left = gapstart-pos;
      if (left > len) left = len;
      auto fp = cast(char*)memchr(tbuf+pos, ch, left);
      if (fp !is null) return cast(int)(fp-tbuf);
      if ((len -= left) == 0) return -1;
      pos = gapstart; // new starting position
    }
    assert(pos >= gapstart);
    // check after gap and to text end
    left = ts-pos;
    if (left > len) left = len;
    if (left > 0) {
      auto stx = tbuf+gapend+(pos-gapstart);
      assert(cast(usize)(tbuf+tbsize-stx) >= left);
      auto fp = cast(char*)memchr(stx, ch, left);
      if (fp !is null) return pos+cast(int)(fp-stx);
    }
    return -1;
  }

  /// bufparts range
  /// this is hack for regexp searchers
  /// do not store returned slice anywhere for a long time!
  /// slice *will* be invalidated on next gap buffer operation!
  public auto bufparts (int pos) nothrow @nogc {
    static struct Range {
    nothrow @nogc:
      GapBuffer gb;
      bool aftergap; // fr is "aftergap"?
      const(char)[] fr;
      private this (GapBuffer agb, int pos) {
        gb = agb;
        auto ts = agb.tbused;
        if (ts == 0 || pos >= ts) { gb = null; return; }
        if (pos < 0) pos = 0;
        if (pos < agb.gapstart) {
          fr = agb.tbuf[pos..agb.gapstart];
        } else {
          int left = ts-pos;
          if (left < 1) { gb = null; return; }
          pos -= agb.gapstart;
          fr = agb.tbuf[agb.gapend+pos..agb.gapend+pos+left];
          aftergap = true;
        }
      }
      @property bool empty () pure const @safe { pragma(inline, true); return (gb is null); }
      @property const(char)[] front () pure @safe { pragma(inline, true); return fr; }
      void popFront () {
        if (aftergap) gb = null;
        if (gb is null) { fr = null; return; }
        int left = gb.textsize-gb.gapstart;
        if (left < 1) { gb = null; fr = null; return; }
        fr = gb.tbuf[gb.gapend..gb.gapend+left];
        aftergap = true;
      }
    }
    return Range(this, pos);
  }

  /// this calls dg with continuous buffer parts, so you can write 'em to a file, for example
  public final void forEachBufPart (int pos, int len, scope void delegate (const(char)[] buf) dg) {
    if (dg is null) return;
    immutable ts = tbused;
    if (len < 1) return;
    if (ts == 0 || pos >= ts) return;
    if (pos < 0) {
      if (pos <= -len) return;
      len += pos;
      pos = 0;
    }
    assert(len > 0);
    int left;
    // check text before gap
    if (pos < gapstart) {
      left = gapstart-pos;
      if (left > len) left = len;
      assert(left > 0);
      dg(tbuf[pos..pos+left]);
      if ((len -= left) == 0) return; // nothing more to do
      pos = gapstart; // new starting position
    }
    assert(pos >= gapstart);
    // check after gap and to text end
    left = ts-pos;
    if (left > len) left = len;
    if (left > 0) {
      auto stx = tbuf+gapend+(pos-gapstart);
      assert(cast(usize)(tbuf+tbsize-stx) >= left);
      dg(stx[0..left]);
    }
  }

public:
  ///
  static bool hasEols (const(char)[] str) pure nothrow @trusted @nogc {
    import core.stdc.string : memchr;
    uint left = cast(uint)str.length;
    return (left > 0 && memchr(str.ptr, '\n', left) !is null);
  }

  /// index or -1
  static int findEol (const(char)[] str) pure nothrow @trusted @nogc {
    if (str.length > int.max) assert(0, "string too long");
    int left = cast(int)str.length;
    if (left > 0) {
      import core.stdc.string : memchr;
      auto dp = cast(const(char)*)memchr(str.ptr, '\n', left);
      if (dp !is null) return cast(int)(dp-str.ptr);
    }
    return -1;
  }

  /// count number of '\n' chars in string
  static int countEols (const(char)[] str) pure nothrow @trusted @nogc {
    import core.stdc.string : memchr;
    if (str.length > int.max) assert(0, "string too long");
    int count = 0;
    uint left = cast(uint)str.length;
    auto dsp = str.ptr;
    while (left > 0) {
      auto ep = cast(const(char)*)memchr(dsp, '\n', left);
      if (ep is null) break;
      ++count;
      ++ep;
      left -= cast(uint)(ep-dsp);
      dsp = ep;
    }
    return count;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/*
line cache should be separate self-healing object.

cache item:
  uint ofs; // line offset; uint.max means "unknown" (do we need it?)
  uint len; // line length; uint.max means "unknown"
  uint height; // line height; 0 means unknown
  bool viswrap; // this line was "soft-wrapped"

cache state:
  last line for which len is known
  last line for which ofs is known

self-healing for non-wrapping mode:
  as we know the position and the length of inserted/deleted text,
  we can just insert/remove items in line cache, and fix line lengthes.
  offsets can be invalidated, and if we have more than, say, 30000-40000
  lines down the cache, we can invalidate the whole cache (but i'm not
  sure that it is really better than just doing memmove()). prolly just
  invalidate the whole cache if we have more than 3-5 megabytes to move?

self-healing for wrapping mode:
  almost the same as for non-wrapping, but we will rewrap the line. eol
  can be detected with "viswrap" flag.
*/
// Self-Healing Line Cache (utm) implementation
//TODO(?): don't do full cache repairing
private final class LineCache {
private:
  // line offset/height cache item
  static align(1) struct LOCItem {
  align(1):
    uint ofs;
    uint len = uint.max;
    private uint mheight; // 0: unknown; line height; high bit is reserved for "viswrap" flag
  pure nothrow @safe @nogc:
    @property bool validLen () const { pragma(inline, true); return (len != uint.max); }
    @property void resetLen () { pragma(inline, true); len = uint.max; }
    @property bool validHeight () const { pragma(inline, true); return ((mheight&0x7fff_ffffU) != 0); }
    @property void resetHeight () { pragma(inline, true); mheight &= 0x7fff_ffffU; } // doesn't reset "viswrap" flag
    @property uint height () const { pragma(inline, true); return (mheight&0x7fff_ffffU); }
    @property void height (uint v) { pragma(inline, true); assert(v <= 0x7fff_ffffU); mheight = (mheight&0x8000_0000)|v; }
    @property bool viswrap () const { pragma(inline, true); return ((mheight&0x8000_0000U) != 0); }
    @property viswrap (bool v) { pragma(inline, true); if (v) mheight |= 0x8000_0000U; else mheight &= 0x8000_0000U-1; }
  }

private:
  GapBuffer gb;
  LOCItem* locache;  // line info cache
  uint locsize; // number of allocated items in locache
  uint validofsc; // number of entries with valid offsets
  uint validlenc; // number of entries with valid lengthes; cannot be less than `validofsc`
  uint mLineCount; // total number of lines
  bool mWordWrapping; // true: "visual wrap" mode (not implemented yet)
  EgTextMeter textMeter; // null: monospaced font
  int mLineHeight = 1; // line height, in pixels/cells; <0: variable; 0: invalid state
  dchar delegate (char ch) nothrow recode1byte; // not null: delegate to recode from 1bt to unishit

public:
  // utfuck-8 and visual tabs support
  // WARNING! this will SIGNIFICANTLY slow down coordinate calculations!
  bool utfuck = false; /// should x coordinate calculation assume that the text is in UTF-8?
  bool visualtabs = false; /// should x coordinate calculation assume that tabs are not one-char width?
  ubyte tabsize = 2; /// tab size, in spaces

private:
  void initLC () nothrow @nogc {
    import core.stdc.stdlib : realloc;
    // allocate initial line cache
    uint ICS = (gb.mSingleLine ? 2 : 1024);
    locache = cast(typeof(locache[0])*)realloc(locache, ICS*locache[0].sizeof);
    if (locache is null) assert(0, "out of memory for line cache");
    locache[0..ICS] = LOCItem.init;
    locsize = ICS;
    validofsc = validlenc = 1;
    locache[0].len = 0;
    mLineCount = 1; // we always have at least one line, even if it is empty
  }

  // `total` is new number of entries in cache; actual number will be greater by one
  bool growLineCache (uint total) nothrow @nogc {
    assert(total != 0);
    if (locsize < total) {
      // have to allocate more
      if (!GapBuffer.xrealloc(locache, locsize, total, 0x400)) return false;
    }
    return true;
  }

  int calcLineHeight (int lidx) nothrow {
    int ls = locache[lidx].ofs;
    int le = ls+locache[lidx].len;
    textMeter.reset(0); // nobody cares about tab widths here
    scope(exit) textMeter.finish();
    int maxh = textMeter.currheight;
    if (maxh < 1) maxh = 1;
    auto tbufcopy = gb.tbuf;
    auto hbufcopy = gb.hbuf;
    if (utfuck) {
      Utf8DecoderFast udc;
      GapBuffer.HighState hs = (hbufcopy !is null ? hbufcopy[gb.pos2real(ls)] : GapBuffer.HighState.init);
      while (ls < le) {
        char ch = tbufcopy[gb.pos2real(ls++)];
        if (udc.decodeSafe(cast(ubyte)ch)) {
          immutable dchar dch = udc.codepoint;
          if (hbufcopy !is null) textMeter.advance(dch, hs); else textMeter.advance(dch);
        }
        if (textMeter.currheight > maxh) maxh = textMeter.currheight;
        if (ls < le && hbufcopy !is null) hs = hbufcopy[gb.pos2real(ls)];
      }
    } else {
      auto rc1b = recode1byte;
      while (ls < le) {
        immutable uint rpos = gb.pos2real(ls++);
        dchar dch = (rc1b !is null ? rc1b(tbufcopy[rpos]) : cast(dchar)tbufcopy[rpos]);
        if (hbufcopy !is null) textMeter.advance(dch, hbufcopy[rpos]); else textMeter.advance(dch);
        if (textMeter.currheight > maxh) maxh = textMeter.currheight;
      }
    }
    //{ import core.stdc.stdio; printf("line #%d height is %d\n", lidx, maxh); }
    return maxh;
  }

  // -1: not found
  int findLineCacheIndex (uint pos) const nothrow @nogc {
    if (validofsc == 0) return -1;
    if (pos >= gb.tbused) return (validofsc != mLineCount ? -1 : mLineCount-1);
    if (validofsc == 1) return (pos < locache[0].len ? 0 : -1);
    if (pos < locache[validofsc].ofs+locache[validofsc].len) {
      // yay! use binary search to find the line
      int bot = 0, i = cast(int)validofsc-1;
      while (bot != i) {
        int mid = i-(i-bot)/2;
        //!assert(mid >= 0 && mid < locused);
        immutable ls = locache[mid].ofs;
        immutable le = ls+locache[mid].len;
        if (pos >= ls && pos < le) return mid; // i found her!
        if (pos < ls) i = mid-1; else bot = mid;
      }
      return i;
    }
    return -1;
  }

  void updateCache (int lidx) nothrow {
  }

  // debug check
  void checkLineCache () nothrow {
    int lcount = gb.countEolsInRange(0, gb.textsize)+1; // total number of lines
    assert(mLineCount == lcount);
    assert(validlenc == lcount);
    assert(validofsc == lcount);
    assert(locsize >= lcount);
    uint pos = 0;
    foreach (immutable uint lidx; 0..lcount) {
      assert(locache[lidx].ofs == pos);
      immutable int eolpos = gb.fastSkipEol(pos);
      assert(locache[lidx].len == eolpos-pos);
      pos = eolpos;
    }
  }

public:
  this (GapBuffer agb) nothrow @nogc {
    assert(agb !is null);
    gb = agb;
    initLC();
  }

  ~this () nothrow @nogc {
    if (locache !is null) {
      import core.stdc.stdlib : free;
      free(locache);
    }
  }

public:
  /// there is always at least one line, so `linecount` is never zero
  @property int linecount () const pure nothrow @safe @nogc { pragma(inline, true); return mLineCount; }

  void clear () nothrow @nogc {
    import core.stdc.stdlib : free;
    gb.clear();
    // free old buffers
    if (locache !is null) { free(locache); locache = null; }
    // allocate new buffer
    initLC();
  }

  /* load file like this:
   *   if (!lc.resizeBuffer(filesize)) throw new Exception("memory?");
   *   scope(failure) lc.clear();
   *   fl.rawReadExact(lc.getBufferPtr[]);
   *   if (!lc.finishLoading()) throw new Exception("memory?");
   */

  // allocate text buffer for the text of the given size
  protected bool resizeBuffer (uint newsize) nothrow @nogc {
    if (newsize > gb.tbmax) return false;
    clear();
    //{ import core.stdc.stdio; printf("resizing buffer to %u bytes\n", newsize); }
    if (!gb.growTBuf(newsize)) return false;
    gb.tbused = gb.gapstart = newsize;
    gb.gapend = gb.tbsize;
    gb.ensureGap();
    return true;
  }

  // get continuous buffer pointer, so we can read the whole file into it
  protected char[] getBufferPtr () nothrow @nogc {
    gb.moveGapAtEnd();
    return gb.tbuf[0..gb.textsize];
  }

  // count lines, fill line cache
  protected bool finishLoading () {
    //gb.moveGapAtEnd(); // just in case
    immutable ts = gb.textsize;
    const(char)* tb = gb.tbuf;
    if (gb.mSingleLine) {
      // easy
      growLineCache(1);
      assert(locsize > 0);
      mLineCount = validofsc = validlenc = 1;
      locache[0] = LOCItem.init;
      locache[0].ofs = 0;
      locache[0].len = ts;
      return true;
    }
    version(egeditor_scan_time) auto stt = clockMilli();
    int lcount = gb.countEolsInRange(0, ts)+1; // total number of lines
    //{ import core.stdc.stdio; printf("loaded %u bytes; %d lines found\n", gb.textsize, lcount); }
    if (!growLineCache(lcount)) return false;
    locache[0..locsize] = LOCItem.init;
    assert(locsize >= lcount);
    uint pos = 0;
    foreach (immutable uint lidx; 0..lcount) {
      locache[lidx].ofs = pos;
      immutable int eolpos = gb.fastSkipEol(pos);
      locache[lidx].len = eolpos-pos;
      pos = eolpos;
    }
    mLineCount = validofsc = validlenc = lcount;
    /*
    foreach (immutable uint lidx; 0..validofsc) {
      import iv.cmdcon;
      conwriteln("line #", lidx, ": ofs=", locache[lidx].ofs, "; len=", locache[lidx].len);
    }
    */
    version(egeditor_scan_time) { import core.stdc.stdio; auto et = clockMilli()-stt; printf("%u lines (%u bytes) scanned in %u milliseconds\n", mLineCount, gb.textsize, cast(uint)et); }
    return true;
  }

  /// put text into buffer; will either put all the text, or nothing
  /// returns success flag
  bool append (const(char)[] str...) { return (put(gb.textsize, str) >= 0); }

  /// put text into buffer; will either put all the text, or nothing
  /// returns new position or -1
  int put (int pos, const(char)[] str...) {
    if (pos < 0) pos = 0;
    bool atend = (pos >= gb.textsize);
    if (str.length == 0) return pos;
    if (atend) pos = gb.textsize;
    auto ppos = gb.put(pos, str);
    if (ppos < 0) return ppos;
    // heal line cache for single-line case
    if (gb.mSingleLine) {
      assert(mLineCount == 1);
      assert(locsize > 0);
      assert(validofsc == 1);
      assert(validlenc == 1);
      assert(locache[0].ofs == 0);
      locache[0].len = gb.textsize;
      locache[0].resetHeight();
    } else {
      assert(validofsc == mLineCount); // for now
      assert(ppos > pos);
      int newlines = GapBuffer.countEols(str);
      auto lidx = findLineCacheIndex(pos);
      immutable int ldelta = ppos-pos;
      //{ import core.stdc.stdio; printf("count=%u; pos=%u; ppos=%u; newlines=%u; lidx=%u; mLineCount=%u\n", cast(uint)str.length, pos, ppos, newlines, lidx, mLineCount); }
      assert(lidx >= 0);
      if (newlines == 0) {
        // no lines was inserted, just repair the length
        locache[lidx].len += ldelta;
        locache[lidx].resetHeight();
      } else {
        import core.stdc.string : memmove;
        // we will start repairing from the last good line
        pos = locache[lidx].ofs;
        if (pos == 0) assert(lidx == 0); else assert(gb[pos-1] == '\n');
        // inserted some new lines, make room for 'em
        growLineCache(mLineCount+newlines);
        if (lidx < mLineCount) memmove(locache+lidx+newlines, locache+lidx, (mLineCount-lidx)*locache[0].sizeof);
        // no need to clear inserted lines, we'll overwrite em
        // recalc offsets and lengthes
        validofsc = validlenc = (mLineCount += newlines);
        while (newlines-- >= 0) {
          immutable int lend = gb.fastSkipEol(pos);
          locache[lidx].ofs = pos;
          locache[lidx].len = lend-pos;
          locache[lidx++].resetHeight();
          pos = lend;
        }
        --lidx; // have to
      }
      // repair line cache (offsets) -- for now; switch to "repair on demand" later?
      if (lidx+1 < mLineCount) foreach (ref lc; locache[lidx+1..mLineCount]) lc.ofs += ldelta;
      //{ import core.stdc.stdio; printf("  mLineCount=%u\n", mLineCount); }
      version(egeditor_line_cache_checks) checkLineCache();
    }
    return ppos;
  }

  /// remove count bytes from the current position; will either remove all of 'em, or nothing
  /// returns success flag
  bool remove (int pos, int count) {
    if (gb.mSingleLine) {
      // easy
      if (!remove(pos, count)) return false;
      assert(mLineCount == 1);
      assert(locsize > 0);
      assert(validofsc == 1);
      assert(validlenc == 1);
      assert(locache[0].ofs == 0);
      locache[0].len = gb.textsize;
      locache[0].resetHeight();
    } else {
      // hard
      import core.stdc.string : memmove;
      if (count < 0) return false;
      if (count == 0) return true;
      if (pos < 0) pos = 0;
      if (pos > gb.textsize) pos = gb.textsize;
      if (gb.textsize-pos < count) return false; // not enough text here
      auto lidx = findLineCacheIndex(pos);
      assert(lidx >= 0);
      int newlines = gb.countEolsInRange(pos, count);
      if (!gb.remove(pos, count)) return false;
      // repair line cache
      if (newlines == 0) {
        assert((lidx < mLineCount-1 && locache[lidx].len > count) || (lidx == mLineCount-1 && locache[lidx].len >= count));
        locache[lidx].len -= count;
        locache[lidx].resetHeight();
      } else {
        import core.stdc.string : memmove;
        // we will start repairing from the last good line
        pos = locache[lidx].ofs;
        if (pos == 0) assert(lidx == 0); else assert(gb[pos-1] == '\n');
        { import core.stdc.stdio; printf("count=%u; pos=%u; newlines=%u; lidx=%u; mLineCount=%u\n", count, pos, newlines, lidx, mLineCount); }
        // remove unused lines
        if (lidx < mLineCount) memmove(locache+lidx, locache+lidx+newlines, (mLineCount-lidx)*locache[0].sizeof);
        validofsc = validlenc = (mLineCount -= newlines);
        // fix current line
        immutable int lend = gb.fastSkipEol(pos);
        locache[lidx].ofs = pos;
        locache[lidx].len = lend-pos;
        locache[lidx].resetHeight();
      }
      if (lidx+1 < mLineCount) foreach (ref lc; locache[lidx+1..mLineCount]) lc.ofs -= count;
      version(egeditor_line_cache_checks) checkLineCache();
    }
    return true;
  }

  int lineHeightPixels (int lidx, bool forceRecalc=false) nothrow {
    int h;
    assert(textMeter !is null);
    if (lidx < 0 || mLineCount == 0 || lidx >= mLineCount) {
      textMeter.reset(0);
      h = (textMeter.currheight > 0 ? textMeter.currheight : 1);
      textMeter.finish();
    } else {
      updateCache(lidx);
      if (forceRecalc || !locache[lidx].validHeight) locache[lidx].height = calcLineHeight(lidx);
      h = locache[lidx].height;
    }
    return h;
  }

  /// get number of *symbols* to line end (this is not always equal to number of bytes for utfuck)
  int syms2eol (int pos) nothrow {
    immutable ts = gb.textsize;
    if (pos < 0) pos = 0;
    if (pos >= ts) return 0;
    int epos = line2pos(pos2line(pos)+1);
    if (!utfuck) return epos-pos; // fast path
    // slow path
    int count = 0;
    while (pos < epos) {
      pos += gb.utfuckLenAt!true(pos);
      ++count;
    }
    return count;
  }

  /// get line for the given position
  int pos2line (int pos) nothrow {
    immutable ts = gb.textsize;
    if (pos < 0) return 0;
    if (pos == 0 || ts == 0) return 0;
    if (pos >= ts) return mLineCount-1; // end of text: no need to update line offset cache
    if (mLineCount == 1) return 0;
    int lcidx = findLineCacheIndex(pos);
    if (lcidx < 0) {
      // line cache is unusable, update it
      assert(0);
      /*
      updateCache(0);
      while (locused < mLineCount && locache[locused-1].ofs <= pos) updateCache(locused);
      lcidx = findLineCacheIndex(pos);
      if (lcidx < 0) {
        //{ import core.stdc.stdio; auto fo = fopen("z00.log", "a"); scope(exit) fclose(fo); fo.fprintf("pos=%u; tbused=%u; locused=%u; mLineCount=%u; $-2=%u; $-1=%u\n", pos, tbused, locused, mLineCount, locache[locused-2].ofs, locache[locused-1].ofs); }
        assert(0, "internal line cache error");
      }
      if (lcidx < 0) assert(0, "internal line cache error");
      */
    }
    //!assert(lcidx >= 0 && lcidx < mLineCount);
    return lcidx;
  }

  /// get position (starting) for the given line
  /// it will be 0 for negative lines, and `textsize` for positive out of bounds lines
  int line2pos (int lidx) nothrow {
    if (lidx < 0 || gb.textsize == 0) return 0;
    if (lidx > mLineCount-1) return gb.textsize;
    if (mLineCount == 1) {
      assert(lidx == 0);
      return 0;
    }
    updateCache(lidx);
    return locache[lidx].ofs;
  }

  alias linestart = line2pos; /// ditto

  /// get ending position for the given line (position of '\n')
  /// it may be `textsize`, though, if this is the last line, and it doesn't end with '\n'
  int lineend (int lidx) nothrow {
    if (lidx < 0 || gb.textsize == 0) return 0;
    if (lidx > mLineCount-1) return gb.textsize;
    if (mLineCount == 1) {
      assert(lidx == 0);
      return gb.textsize;
    }
    if (lidx == mLineCount-1) return gb.textsize;
    updateCache(lidx);
    auto res = locache[lidx].ofs+locache[lidx].len;
    assert(res > 0);
    return res-1;
  }

  // move by `x` utfucked chars
  // `pos` should point to line start
  // will never go beyond EOL
  private int utfuck_x2pos (int x, int pos) nothrow {
    immutable ts = gb.textsize;
    const(char)* tbuf = gb.tbuf;
    if (pos < 0) pos = 0;
    if (gb.mSingleLine) {
      // single line
      while (pos < ts && x > 0) {
        pos += gb.utfuckLenAt!true(pos); // "always positive"
        --x;
      }
    } else {
      // multiline
      while (pos < ts && x > 0) {
        if (tbuf[gb.pos2real(pos)] == '\n') break;
        pos += gb.utfuckLenAt!true(pos); // "always positive"
        --x;
      }
    }
    if (pos > ts) pos = ts;
    return pos;
  }

  // convert line offset to screen x coordinate
  // `pos` should point into line (somewhere)
  private int utfuck_pos2x(bool dotabs=false) (int pos) nothrow {
    immutable ts = gb.textsize;
    if (pos < 0) pos = 0;
    if (pos > ts) pos = ts;
    immutable bool sl = gb.mSingleLine;
    const(char)* tbuf = gb.tbuf;
    // find line start
    int spos = pos;
    if (!sl) {
      while (spos > 0 && tbuf[gb.pos2real(spos-1)] != '\n') --spos;
    } else {
      spos = 0;
    }
    // now `spos` points to line start; walk over utfucked chars
    int x = 0;
    while (spos < pos) {
      char ch = tbuf[gb.pos2real(spos)];
      if (!sl && ch == '\n') break;
      static if (dotabs) {
        if (ch == '\t' && visualtabs && tabsize > 0) {
          x = ((x+tabsize)/tabsize)*tabsize;
        } else {
          ++x;
        }
      } else {
        ++x;
      }
      spos += (ch < 128 ? 1 : gb.utfuckLenAt!true(spos));
    }
    return x;
  }

  /// get position for the given text coordinates
  int xy2pos (int x, int y) nothrow {
    auto ts = gb.textsize;
    if (ts == 0 || y < 0) return 0;
    if (y > mLineCount-1) return ts;
    if (x < 0) x = 0;
    if (mLineCount == 1) {
      assert(y == 0);
      return (!utfuck ? (x < ts ? x : ts) : utfuck_x2pos(x, 0));
    }
    updateCache(y);
    uint ls = locache[y].ofs;
    uint le = ls+locache[y].len;
    if (ls == le) {
      // this should be last empty line
      //if (y != mLineCount-1) { import std.format; assert(0, "fuuuuu; y=%u; lc=%u; locused=%u".format(y, mLineCount, locused)); }
      assert(y == mLineCount-1);
      return ls;
    }
    if (!utfuck) {
      // we want line end (except for last empty line, where we want end-of-text)
      if (x >= le-ls) return (y != mLineCount-1 ? le-1 : le);
      return ls+x; // somewhere in line
    } else {
      // fuck
      return utfuck_x2pos(x, ls);
    }
  }

  /// get text coordinates for the given position
  void pos2xy (int pos, out int x, out int y) nothrow {
    immutable ts = gb.textsize;
    if (pos <= 0 || ts == 0) return; // x and y autoinited
    if (pos > ts) pos = ts;
    if (mLineCount == 1) {
      // y is autoinited
      x = (!utfuck ? pos : utfuck_pos2x(pos));
      return;
    }
    const(char)* tbuf = gb.tbuf;
    if (pos == ts) {
      // end of text: no need to update line offset cache
      y = mLineCount-1;
      if (!gb.mSingleLine) {
        while (pos > 0 && tbuf[gb.pos2real(--pos)] != '\n') ++x;
      } else {
        x = pos;
      }
      return;
    }
    int lcidx = findLineCacheIndex(pos);
    if (lcidx < 0) {
      // line cache is unusable, update it
      /*
      updateCache(0);
      while (locused < mLineCount && locache[locused-1].ofs <= pos) updateCache(locused);
      lcidx = findLineCacheIndex(pos);
      if (lcidx < 0) {
        //{ import core.stdc.stdio; auto fo = fopen("z00.log", "a"); scope(exit) fclose(fo); fo.fprintf("pos=%u; tbused=%u; locused=%u; mLineCount=%u\n", pos, tbused, locused, mLineCount); }
        assert(0, "internal line cache error");
      }
      */
      assert(0);
    }
    //!assert(lcidx >= 0 && lcidx < mLineCount);
    immutable ls = locache[lcidx].ofs;
    //auto le = lineofsc[lcidx+1];
    //!assert(pos >= ls && pos < le);
    y = cast(uint)lcidx;
    x = (!utfuck ? pos-ls : utfuck_pos2x(pos));
  }

  /// get text coordinates (adjusted for tabs) for the given position
  void pos2xyVT (int pos, out int x, out int y) nothrow {
    if (!utfuck && (!visualtabs || tabsize == 0)) { pos2xy(pos, x, y); return; }

    void tabbedX() (int ls) {
      x = 0;
      version(none) {
        //TODO:FIXME: fix this!
        while (ls < pos) {
          int tp = fastFindCharIn(ls, pos-ls, '\t');
          if (tp < 0) { x += pos-ls; return; }
          x += tp-ls;
          ls = tp;
          while (ls < pos && tbuf[pos2real(ls++)] == '\t') {
            x = ((x+tabsize)/tabsize)*tabsize;
          }
        }
      } else {
        const(char)* tbuf = gb.tbuf;
        while (ls < pos) {
          if (tbuf[gb.pos2real(ls++)] == '\t') x = ((x+tabsize)/tabsize)*tabsize; else ++x;
        }
      }
    }

    auto ts = gb.textsize;
    if (pos <= 0 || ts == 0) return; // x and y autoinited
    if (pos > ts) pos = ts;
    if (mLineCount == 1) {
      // y is autoinited
      if (utfuck) { x = utfuck_pos2x!true(pos); return; }
      if (!visualtabs || tabsize == 0) { x = pos; return; }
      tabbedX(0);
      return;
    }
    if (pos == ts) {
      // end of text: no need to update line offset cache
      const(char)* tbuf = gb.tbuf;
      y = mLineCount-1;
      while (pos > 0 && (gb.mSingleLine || tbuf[gb.pos2real(--pos)] != '\n')) ++x;
      if (utfuck) { x = utfuck_pos2x!true(ts); return; }
      if (visualtabs && tabsize != 0) { int ls = pos+1; pos = ts; tabbedX(ls); return; }
      return;
    }
    int lcidx = findLineCacheIndex(pos);
    if (lcidx < 0) {
      // line cache is unusable, update it
      assert(0);
      /*
      updateCache(0);
      while (locused < mLineCount && locache[locused-1].ofs < pos) updateCache(locused);
      lcidx = findLineCacheIndex(pos);
      if (lcidx < 0) assert(0, "internal line cache error");
      */
    }
    //!assert(lcidx >= 0 && lcidx < mLineCount);
    auto ls = locache[lcidx].ofs;
    //auto le = lineofsc[lcidx+1];
    //!assert(pos >= ls && pos < le);
    y = cast(uint)lcidx;
    if (utfuck) { x = utfuck_pos2x!true(pos); return; }
    if (visualtabs && tabsize > 0) { tabbedX(ls); return; }
    x = pos-ls;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private final class UndoStack {
public:
  enum Type : ubyte {
    None,
    //
    CurMove, // pos: old position; len: old topline (sorry)
    TextRemove, // pos: position; len: length; deleted chars follows
    TextInsert, // pos: position; len: length
    // grouping
    GroupStart,
    GroupEnd,
  }

private:
  static align(1) struct Action {
  align(1):
    enum Flag : ubyte {
      BlockMarking = 1<<0, // block marking state
      LastBE = 1<<1, // last block move was at end?
      Changed = 1<<2, // "changed" flag
      //VisTabs = 1<<3, // editor was in "visual tabs" mode
    }

    @property nothrow pure @safe @nogc {
      bool bmarking () const { pragma(inline, true); return (flags&Flag.BlockMarking) != 0; }
      bool lastbe () const { pragma(inline, true); return (flags&Flag.LastBE) != 0; }
      bool txchanged () const { pragma(inline, true); return (flags&Flag.Changed) != 0; }
      //bool vistabs () const { pragma(inline, true); return (flags&Flag.VisTabs) != 0; }

      void bmarking (bool v) { pragma(inline, true); if (v) flags |= Flag.BlockMarking; else flags &= ~Flag.BlockMarking; }
      void lastbe (bool v) { pragma(inline, true); if (v) flags |= Flag.LastBE; else flags &= ~Flag.LastBE; }
      void txchanged (bool v) { pragma(inline, true); if (v) flags |= Flag.Changed; else flags &= ~Flag.Changed; }
      //void vistabs (bool v) { pragma(inline, true); if (v) flags |= Flag.VisTabs; else flags &= ~Flag.VisTabs; }
    }

    Type type;
    int pos;
    int len;
    // after undoing action
    int cx, cy, topline, xofs;
    int bs, be; // block position
    ubyte flags;
    // data follows
    char[0] data;
  }

version(Posix) private import core.sys.posix.unistd : off_t;

private:
  version(Posix) int tmpfd = -1; else enum tmpfd = -1;
  version(Posix) off_t tmpsize = 0;
  bool asRedo;
  // undo buffer format:
  //   last uint is always record size (not including size uints); record follows (up), then size again
  uint maxBufSize = 32*1024*1024;
  ubyte* undoBuffer;
  uint ubUsed, ubSize;
  bool asRich;

final:
  version(Posix) void initTempFD () nothrow {
    import core.sys.posix.fcntl /*: open*/;
    static if (is(typeof(O_CLOEXEC)) && is(typeof(O_TMPFILE))) {
      auto xfd = open("/tmp/_egundoz", O_RDWR|O_CLOEXEC|O_TMPFILE, 0x1b6/*0o600*/);
      if (xfd < 0) return;
      tmpfd = xfd;
      tmpsize = 0;
    }
  }

  // returns record size
  version(Posix) uint loadLastRecord(bool fullrecord=true) (bool dropit=false) nothrow {
    import core.stdc.stdio : SEEK_SET, SEEK_END;
    import core.sys.posix.unistd : lseek, read;
    assert(tmpfd >= 0);
    uint sz;
    if (tmpsize < sz.sizeof) return 0;
    lseek(tmpfd, tmpsize-sz.sizeof, SEEK_SET);
    if (read(tmpfd, &sz, sz.sizeof) != sz.sizeof) return 0;
    if (tmpsize < sz+sz.sizeof*2) return 0;
    if (sz < Action.sizeof) return 0;
    lseek(tmpfd, tmpsize-sz-sz.sizeof, SEEK_SET);
    static if (fullrecord) {
      alias rsz = sz;
    } else {
      auto rsz = cast(uint)Action.sizeof;
    }
    if (ubSize < rsz) {
      import core.stdc.stdlib : realloc;
      auto nb = cast(ubyte*)realloc(undoBuffer, rsz);
      if (nb is null) return 0;
      undoBuffer = nb;
      ubSize = rsz;
    }
    ubUsed = rsz;
    if (read(tmpfd, undoBuffer, rsz) != rsz) return 0;
    if (dropit) tmpsize -= sz+sz.sizeof*2;
    return rsz;
  }

  bool saveLastRecord () nothrow {
    version(Posix) {
      import core.stdc.stdio : SEEK_SET;
      import core.sys.posix.unistd : lseek, write;
      if (tmpfd >= 0) {
        assert(ubUsed >= Action.sizeof);
        scope(exit) {
          import core.stdc.stdlib : free;
          if (ubUsed > 65536) {
            free(undoBuffer);
            undoBuffer = null;
            ubUsed = ubSize = 0;
          }
        }
        auto ofs = lseek(tmpfd, tmpsize, SEEK_SET);
        if (write(tmpfd, &ubUsed, ubUsed.sizeof) != ubUsed.sizeof) return false;
        if (write(tmpfd, undoBuffer, ubUsed) != ubUsed) return false;
        if (write(tmpfd, &ubUsed, ubUsed.sizeof) != ubUsed.sizeof) return false;
        write(tmpfd, &tmpsize, tmpsize.sizeof);
        tmpsize += ubUsed+uint.sizeof*2;
      }
    }
    return true;
  }

  // return `true` if something was removed
  bool removeFirstUndo () nothrow {
    import core.stdc.string : memmove;
    version(Posix) assert(tmpfd < 0);
    if (ubUsed == 0) return false;
    uint np = (*cast(uint*)undoBuffer)+4*2;
    assert(np <= ubUsed);
    if (np == ubUsed) { ubUsed = 0; return true; }
    memmove(undoBuffer, undoBuffer+np, ubUsed-np);
    ubUsed -= np;
    return true;
  }

  // return `null` if it can't; undo buffer is in invalid state then
  Action* addUndo (int dataSize) nothrow {
    import core.stdc.stdlib : realloc;
    import core.stdc.string : memset;
    version(Posix) if (tmpfd < 0) {
      if (dataSize < 0 || dataSize >= maxBufSize) return null; // no room
      uint asz = cast(uint)Action.sizeof+dataSize+4*2;
      if (asz > maxBufSize) return null;
      if (ubSize-ubUsed < asz) {
        uint nasz = ubUsed+asz;
        if (nasz&0xffff) nasz = (nasz|0xffff)+1;
        if (nasz > maxBufSize) {
          while (ubSize-ubUsed < asz) { if (!removeFirstUndo()) return null; }
        } else {
          auto nb = cast(ubyte*)realloc(undoBuffer, nasz);
          if (nb is null) {
            while (ubSize-ubUsed < asz) { if (!removeFirstUndo()) return null; }
          } else {
            undoBuffer = nb;
            ubSize = nasz;
          }
        }
      }
      assert(ubSize-ubUsed >= asz);
      *cast(uint*)(undoBuffer+ubUsed) = asz-4*2;
      auto res = cast(Action*)(undoBuffer+ubUsed+4);
      *cast(uint*)(undoBuffer+ubUsed+asz-4) = asz-4*2;
      ubUsed += asz;
      memset(res, 0, asz-4*2);
      return res;
    }
    {
      // has temp file
      if (dataSize < 0 || dataSize >= int.max/4) return null; // wtf?!
      uint asz = cast(uint)Action.sizeof+dataSize;
      if (ubSize < asz) {
        auto nb = cast(ubyte*)realloc(undoBuffer, asz);
        if (nb is null) return null;
        undoBuffer = nb;
        ubSize = asz;
      }
      ubUsed = asz;
      auto res = cast(Action*)undoBuffer;
      memset(res, 0, asz);
      return res;
    }
  }

  // can return null
  Action* lastUndoHead () nothrow {
    version(Posix) if (tmpfd >= 0) {
      if (loadLastRecord!false()) return null;
      return cast(Action*)undoBuffer;
    }
    {
      if (ubUsed == 0) return null;
      auto sz = *cast(uint*)(undoBuffer+ubUsed-4);
      return cast(Action*)(undoBuffer+ubUsed-4-sz);
    }
  }

  Action* popUndo () nothrow {
    version(Posix) if (tmpfd >= 0) {
      auto len = loadLastRecord!true(true); // pop it
      return (len ? cast(Action*)undoBuffer : null);
    }
    {
      if (ubUsed == 0) return null;
      auto sz = *cast(uint*)(undoBuffer+ubUsed-4);
      auto res = cast(Action*)(undoBuffer+ubUsed-4-sz);
      ubUsed -= sz+4*2;
      return res;
    }
  }

public:
  this (bool aAsRich, bool aAsRedo, bool aIntoFile) nothrow {
    asRedo = aAsRedo;
    asRich = aAsRich;
    if (aIntoFile) {
      initTempFD();
      if (tmpfd < 0) {
        //version(aliced) { import iv.rawtty; ttyBeep(); }
      }
    }
  }

  ~this () nothrow {
    import core.stdc.stdlib : free;
    import core.sys.posix.unistd : close;
    if (tmpfd >= 0) { close(tmpfd); tmpfd = -1; }
    if (undoBuffer !is null) free(undoBuffer);
  }

  void clear (bool doclose=false) nothrow {
    ubUsed = 0;
    if (doclose) {
      version(Posix) {
        import core.stdc.stdlib : free;
        if (tmpfd >= 0) {
          import core.sys.posix.unistd : close;
          close(tmpfd);
          tmpfd = -1;
        }
      }
      if (undoBuffer !is null) free(undoBuffer);
      undoBuffer = null;
      ubSize = 0;
    } else {
      if (ubSize > 65536) {
        import core.stdc.stdlib : realloc;
        auto nb = cast(ubyte*)realloc(undoBuffer, 65536);
        if (nb !is null) {
          undoBuffer = nb;
          ubSize = 65536;
        }
      }
      version(Posix) if (tmpfd >= 0) tmpsize = 0;
    }
  }

  void alwaysChanged () nothrow {
    if (tmpfd < 0) {
      auto pos = 0;
      while (pos < ubUsed) {
        auto sz = *cast(uint*)(undoBuffer+pos);
        auto res = cast(Action*)(undoBuffer+pos+4);
        pos += sz+4*2;
        switch (res.type) {
          case Type.TextRemove:
          case Type.TextInsert:
            res.txchanged = true;
            break;
          default:
        }
      }
    } else {
      version(Posix) {
        import core.stdc.stdio : SEEK_SET;
        import core.sys.posix.unistd : lseek, read, write;
        off_t cpos = 0;
        Action act;
        while (cpos < tmpsize) {
          uint sz;
          lseek(tmpfd, cpos, SEEK_SET);
          if (read(tmpfd, &sz, sz.sizeof) != sz.sizeof) break;
          if (sz < Action.sizeof) assert(0, "wtf?!");
          if (read(tmpfd, &act, Action.sizeof) != Action.sizeof) break;
          switch (act.type) {
            case Type.TextRemove:
            case Type.TextInsert:
              if (act.txchanged != true) {
                act.txchanged = true;
                lseek(tmpfd, cpos+sz.sizeof, SEEK_SET);
                write(tmpfd, &act, Action.sizeof);
              }
              break;
            default:
          }
          cpos += sz+sz.sizeof*2;
        }
      }
    }
  }

  private void fillCurPos (Action* ua, EditorEngine ed) nothrow {
    if (ua !is null && ed !is null) {
      //TODO: correct x according to "visual tabs" mode (i.e. make it "normal x")
      ua.cx = ed.cx;
      ua.cy = ed.cy;
      ua.topline = ed.mTopLine;
      ua.xofs = ed.mXOfs;
      ua.bs = ed.bstart;
      ua.be = ed.bend;
      ua.bmarking = ed.markingBlock;
      ua.lastbe = ed.lastBGEnd;
      ua.txchanged = ed.txchanged;
      //ua.vistabs = ed.visualtabs;
    }
  }

  bool addCurMove (EditorEngine ed, bool fromRedo=false) nothrow {
    if (auto lu = lastUndoHead()) {
      if (lu.type == Type.CurMove) {
        if (lu.cx == ed.cx && lu.cy == ed.cy && lu.topline == ed.mTopLine && lu.xofs == ed.mXOfs &&
            lu.bs == ed.bstart && lu.be == ed.bend && lu.bmarking == ed.markingBlock &&
            lu.lastbe == ed.lastBGEnd /*&& lu.vistabs == ed.visualtabs*/) return true;
      }
    }
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.CurMove;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  bool addTextRemove (EditorEngine ed, int pos, int count, bool fromRedo=false) nothrow {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    GapBuffer gb = ed.gb;
    assert(gb !is null);
    if (pos < 0 || pos >= gb.textsize) return true;
    if (count < 1) return true;
    if (count >= maxBufSize) { clear(); return false; }
    if (count > gb.textsize-pos) { clear(); return false; }
    int realcount = count;
    if (asRich && realcount > 0) {
      if (realcount >= int.max/gb.hbuf[0].sizeof/2) return false;
      realcount += realcount*cast(int)gb.hbuf[0].sizeof;
    }
    auto act = addUndo(realcount);
    if (act is null) { clear(); return false; }
    act.type = Type.TextRemove;
    act.pos = pos;
    act.len = count;
    fillCurPos(act, ed);
    auto dp = act.data.ptr;
    while (count--) *dp++ = gb[pos++];
    // save attrs for rich editor
    if (asRich && realcount > 0) {
      pos = act.pos;
      count = act.len;
      auto dph = cast(GapBuffer.HighState*)dp;
      while (count--) *dph++ = gb.hi(pos++);
    }
    return saveLastRecord();
  }

  bool addTextInsert (EditorEngine ed, int pos, int count, bool fromRedo=false) nothrow {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.TextInsert;
    act.pos = pos;
    act.len = count;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  bool addGroupStart (EditorEngine ed, bool fromRedo=false) nothrow {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.GroupStart;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  bool addGroupEnd (EditorEngine ed, bool fromRedo=false) nothrow {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.GroupEnd;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  @property bool hasUndo () const pure nothrow @safe @nogc { pragma(inline, true); return (tmpfd < 0 ? (ubUsed > 0) : (tmpsize > 0)); }

  private bool copyAction (Action* ua) nothrow {
    import core.stdc.string : memcpy;
    if (ua is null) return true;
    auto na = addUndo(ua.type == Type.TextRemove ? ua.len : 0);
    if (na is null) return false;
    memcpy(na, ua, Action.sizeof+(ua.type == Type.TextRemove ? ua.len : 0));
    return saveLastRecord();
  }

  // return "None" in case of error
  Type undoAction (EditorEngine ed) {
    UndoStack oppos = (asRedo ? ed.undo : ed.redo);
    assert(ed !is null);
    auto ua = popUndo();
    if (ua is null) return Type.None;
    //debug(egauto) if (!asRedo) { { import iv.vfs; auto fo = VFile("z00_undo.bin", "a"); fo.writeln(*ua); } }
    Type res = ua.type;
    final switch (ua.type) {
      case Type.None: assert(0, "wtf?!");
      case Type.GroupStart:
      case Type.GroupEnd:
        if (oppos !is null) { if (!oppos.copyAction(ua)) oppos.clear(); }
        break;
      case Type.CurMove:
        if (oppos !is null) { if (oppos.addCurMove(ed, asRedo) == Type.None) oppos.clear(); }
        break;
      case Type.TextInsert: // remove inserted text
        if (oppos !is null) { if (oppos.addTextRemove(ed, ua.pos, ua.len, asRedo) == Type.None) oppos.clear(); }
        //ed.writeLogAction(ua.pos, -ua.len);
        ed.ubTextRemove(ua.pos, ua.len);
        break;
      case Type.TextRemove: // insert removed text
        if (oppos !is null) { if (oppos.addTextInsert(ed, ua.pos, ua.len, asRedo) == Type.None) oppos.clear(); }
        if (ed.ubTextInsert(ua.pos, ua.data.ptr[0..ua.len])) {
          if (asRich) ed.ubTextSetAttrs(ua.pos, (cast(GapBuffer.HighState*)(ua.data.ptr+ua.len))[0..ua.len]);
        }
        //ed.writeLogAction(ua.pos, ua.len);
        break;
    }
    //FIXME: optimize redraw
    if (ua.bs != ed.bstart || ua.be != ed.bend) {
      if (ua.bs < ua.be) {
        // undo has block
        if (ed.bstart < ed.bend) ed.markLinesDirtySE(ed.lc.pos2line(ed.bstart), ed.lc.pos2line(ed.bend)); // old block is dirty
        ed.markLinesDirtySE(ed.lc.pos2line(ua.bs), ed.lc.pos2line(ua.be)); // new block is dirty
      } else {
        // undo has no block
        if (ed.bstart < ed.bend) ed.markLinesDirtySE(ed.lc.pos2line(ed.bstart), ed.lc.pos2line(ed.bend)); // old block is dirty
      }
    }
    ed.bstart = ua.bs;
    ed.bend = ua.be;
    ed.markingBlock = ua.bmarking;
    ed.lastBGEnd = ua.lastbe;
    // don't restore "visual tabs" mode
    //TODO: correct x according to "visual tabs" mode (i.e. make it "visual x")
    ed.cx = ua.cx;
    ed.cy = ua.cy;
    ed.mTopLine = ua.topline;
    ed.mXOfs = ua.xofs;
    ed.txchanged = ua.txchanged;
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// main editor engine: does all the undo/redo magic, block management, etc.
class EditorEngine {
public:
  ///
  enum CodePage : ubyte {
    koi8u, ///
    cp1251, ///
    cp866, ///
  }
  CodePage codepage = CodePage.koi8u; ///

  /// from koi to codepage
  final char recodeCharTo (char ch) pure const nothrow {
    pragma(inline, true);
    return
      codepage == CodePage.cp1251 ? uni2cp1251(koi2uni(ch)) :
      codepage == CodePage.cp866 ? uni2cp866(koi2uni(ch)) :
      ch;
  }

  /// from codepage to koi
  final char recodeCharFrom (char ch) pure const nothrow {
    pragma(inline, true);
    return
      codepage == CodePage.cp1251 ? uni2koi(cp12512uni(ch)) :
      codepage == CodePage.cp866 ? uni2koi(cp8662uni(ch)) :
      ch;
  }

  /// recode to codepage
  final char recodeU2B (dchar dch) pure const nothrow {
    final switch (codepage) {
      case CodePage.koi8u: return uni2koi(dch);
      case CodePage.cp1251: return uni2cp1251(dch);
      case CodePage.cp866: return uni2cp866(dch);
    }
  }

  /// should not be called for utfuck mode
  final dchar recode1b (char ch) pure const nothrow {
    final switch (codepage) {
      case CodePage.koi8u: return koi2uni(ch);
      case CodePage.cp1251: return cp12512uni(ch);
      case CodePage.cp866: return cp8662uni(ch);
    }
  }

protected:
  int lineHeightPixels = 0; /// <0: use line height API, proportional fonts; 0: everything is cell-based (tty); >0: constant line height in pixels; proprotional fonts
  int prevTopLine = -1;
  int mTopLine = 0;
  int prevXOfs = -1;
  int mXOfs = 0;
  int cx, cy;
  int[] dirtyLines; // line heights or 0 if not dirty; hack!
  int winx, winy, winw, winh;
  GapBuffer gb;
  LineCache lc;
  EditorHL hl;
  UndoStack undo, redo;
  int bstart = -1, bend = -1; // marked block position
  bool markingBlock;
  bool lastBGEnd; // last block grow was at end?
  bool txchanged;
  bool mReadOnly; // has any effect only if you are using `insertText()` and `deleteText()` API!
  bool mSingleLine; // has any effect only if you are using `insertText()` and `deleteText()` API!
  bool mKillTextOnChar; // mostly for single-line: remove all text on new char; will autoreset on move

  char[] indentText; // this buffer is actively reused, do not expose!
  int inPasteMode;

  bool mAsRich; /// this is "rich editor", so engine should save/restore highlighting info in undo

protected:
  bool[int] linebookmarked; /// is this line bookmarked?

public:
  //EgTextMeter textMeter; /// *MUST* be set when `inPixels` is true
  @property EgTextMeter textMeter () nothrow @nogc { return lc.textMeter; }
  @property void textMeter (EgTextMeter tm) nothrow @nogc { lc.textMeter = tm; }

public:
  /// is editor in "paste mode" (i.e. we are pasting chars from clipboard, and should skip autoindenting)?
  final @property bool pasteMode () const pure nothrow @safe @nogc { return (inPasteMode > 0); }
  final resetPasteMode () pure nothrow @safe @nogc { inPasteMode = 0; } /// reset "paste mode"

  ///
  void clearBookmarks () nothrow { linebookmarked.clear(); }

  enum BookmarkChangeMode { Toggle, Set, Reset } ///

  ///
  void bookmarkChange (int cy, BookmarkChangeMode mode) nothrow {
    if (cy < 0 || cy >= lc.linecount) return;
    if (mSingleLine) return; // ignore for single-line mode
    final switch (mode) {
      case BookmarkChangeMode.Toggle:
        if (cy in linebookmarked) linebookmarked.remove(cy); else linebookmarked[cy] = true;
        markLinesDirty(cy, 1);
        break;
      case BookmarkChangeMode.Set:
        if (cy !in linebookmarked) {
          linebookmarked[cy] = true;
          markLinesDirty(cy, 1);
        }
        break;
      case BookmarkChangeMode.Reset:
        if (cy in linebookmarked) {
          linebookmarked.remove(cy);
          markLinesDirty(cy, 1);
        }
        break;
    }
  }

  ///
  final void doBookmarkToggle () nothrow { pragma(inline, true); bookmarkChange(cy, BookmarkChangeMode.Toggle); }

  ///
  final @property bool isLineBookmarked (int lidx) nothrow {
    pragma(inline, true);
    return ((lidx in linebookmarked) !is null);
  }

  ///
  final void doBookmarkJumpUp () nothrow {
    int bestBM = -1;
    foreach (int lidx; linebookmarked.byKey) {
      if (lidx < cy && lidx > bestBM) bestBM = lidx;
    }
    if (bestBM >= 0) {
      pushUndoCurPos();
      cy = bestBM;
      normXY;
      growBlockMark();
      makeCurLineVisibleCentered();
    }
  }

  ///
  final void doBookmarkJumpDown () nothrow {
    int bestBM = int.max;
    foreach (int lidx; linebookmarked.byKey) {
      if (lidx > cy && lidx < bestBM) bestBM = lidx;
    }
    if (bestBM < lc.linecount) {
      pushUndoCurPos();
      cy = bestBM;
      normXY;
      growBlockMark();
      makeCurLineVisibleCentered();
    }
  }

  ///WARNING! don't mutate bookmarks here!
  final void forEachBookmark (scope void delegate (int lidx) dg) {
    if (dg is null) return;
    foreach (int lidx; linebookmarked.byKey) dg(lidx);
  }

  /// call this from `willBeDeleted()` (only!) to fix bookmarks
  final void bookmarkDeletionFix (int pos, int len, int eolcount) nothrow {
    if (eolcount && linebookmarked.length > 0) {
      import core.stdc.stdlib : malloc, free;
      // remove bookmarks whose lines are removed, move other bookmarks
      auto py = lc.pos2line(pos);
      auto ey = lc.pos2line(pos+len);
      bool wholeFirstLineDeleted = (pos == lc.line2pos(py)); // do we want to remove the whole first line?
      bool wholeLastLineDeleted = (pos+len == lc.line2pos(ey)); // do we want to remove the whole last line?
      if (wholeLastLineDeleted) --ey; // yes, `ey` is one line down the last, fix it
      // build new bookmark array
      int* newbm = cast(int*)malloc(int.sizeof*linebookmarked.length);
      if (newbm !is null) {
        scope(exit) free(newbm);
        int newbmpos = 0;
        bool smthWasChanged = false;
        foreach (int lidx; linebookmarked.byKey) {
          // remove "first line" bookmark if "first line" is deleted
          if (wholeFirstLineDeleted && lidx == py) { smthWasChanged = true; continue; }
          // remove "last line" bookmark if "last line" is deleted
          if (wholeLastLineDeleted && lidx == ey) { smthWasChanged = true; continue; }
          // remove bookmarks that are in range
          if (lidx > py && lidx < ey) continue;
          // fix bookmark line if necessary
          if (lidx >= ey) { smthWasChanged = true; lidx -= eolcount; }
          assert(lidx >= 0 && lidx < lc.linecount);
          // add this bookmark to new list
          newbm[newbmpos++] = lidx;
        }
        // rebuild list if something was changed
        if (smthWasChanged) {
          fullDirty(); //TODO: optimize this
          linebookmarked.clear;
          foreach (int lidx; newbm[0..newbmpos]) linebookmarked[lidx] = true;
        }
      } else {
        // out of memory, what to do? just clear bookmarks for now
        linebookmarked.clear;
        fullDirty(); // just in case
      }
    }
  }

  /// call this from `willBeInserted()` or `wasInserted()` to fix bookmarks
  final void bookmarkInsertionFix (int pos, int len, int eolcount) nothrow {
    if (eolcount && linebookmarked.length > 0) {
      import core.stdc.stdlib : malloc, free;
      // move affected bookmarks down
      auto py = lc.pos2line(pos);
      if (pos != lc.line2pos(py)) ++py; // not the whole first line was modified, don't touch bookmarks on it
      // build new bookmark array
      int* newbm = cast(int*)malloc(int.sizeof*linebookmarked.length);
      if (newbm !is null) {
        scope(exit) free(newbm);
        int newbmpos = 0;
        bool smthWasChanged = false;
        foreach (int lidx; linebookmarked.byKey) {
          // fix bookmark line if necessary
          if (lidx >= py) { smthWasChanged = true; lidx += eolcount; }
          if (lidx < 0 || lidx >= lc.linecount) continue;
          //assert(lidx >= 0 && lidx < gb.linecount);
          // add this bookmark to new list
          newbm[newbmpos++] = lidx;
        }
        // rebuild list if something was changed
        if (smthWasChanged) {
          fullDirty(); //TODO: optimize this
          linebookmarked.clear;
          foreach (int lidx; newbm[0..newbmpos]) linebookmarked[lidx] = true;
        }
      } else {
        // out of memory, what to do? just clear bookmarks for now
        linebookmarked.clear;
        fullDirty(); // just in case
      }
    }
  }

public:
  ///
  this (int x0, int y0, int w, int h, EditorHL ahl=null, bool asingleline=false) {
    if (w < 2) w = 2;
    if (h < 1) h = 1;
    winx = x0;
    winy = y0;
    winw = w;
    winh = h;
    //setDirtyLinesLength(visibleLinesPerWindow);
    gb = new GapBuffer(asingleline);
    lc = new LineCache(gb);
    lc.recode1byte = &recode1b;
    hl = ahl;
    if (ahl !is null) { hl.gb = gb; hl.lc = lc; }
    undo = new UndoStack(mAsRich, false, !asingleline);
    redo = new UndoStack(mAsRich, true, !asingleline);
    mSingleLine = asingleline;
  }

  private void setDirtyLinesLength (usize len) nothrow {
    if (len > int.max/4) assert(0, "wtf?!");
    if (dirtyLines.length > len) {
      dirtyLines.length = len;
      dirtyLines.assumeSafeAppend;
      dirtyLines[] = -1;
    } else if (dirtyLines.length < len) {
      auto optr = dirtyLines.ptr;
      auto olen = dirtyLines.length;
      dirtyLines.length = len;
      if (dirtyLines.ptr !is optr) {
        import core.memory : GC;
        if (dirtyLines.ptr is GC.addrOf(dirtyLines.ptr)) GC.setAttr(dirtyLines.ptr, GC.BlkAttr.NO_INTERIOR);
      }
      //dirtyLines[olen..$] = -1;
      dirtyLines[] = -1;
    }
  }

  // utfuck switch hooks
  protected void beforeUtfuckSwitch (bool newisutfuck) {} /// utfuck switch hook
  protected void afterUtfuckSwitch (bool newisutfuck) {} /// utfuck switch hook

  final @property {
    ///
    bool utfuck () const pure nothrow @safe @nogc { pragma(inline, true); return lc.utfuck; }

    /// this switches "utfuck" mode
    /// note that utfuck mode is FUCKIN' SLOW and buggy
    /// you should not lose any text, but may encounter visual and positional glitches
    void utfuck (bool v) {
      if (lc.utfuck == v) return;
      beforeUtfuckSwitch(v);
      auto pos = curpos;
      lc.utfuck = v;
      lc.pos2xy(pos, cx, cy);
      fullDirty();
      afterUtfuckSwitch(v);
    }

    ref inout(GapBuffer.HighState) defaultRichStyle () inout pure nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))gb.defhs; } ///

    @property bool asRich () const pure nothrow @safe @nogc { pragma(inline, true); return mAsRich; } ///

    /// WARNING! changing this will reset undo/redo buffers!
    void asRich (bool v) {
      if (mAsRich != v) {
        // detach highlighter for "rich mode"
        if (v && hl !is null) {
          hl.gb = null;
          hl.lc = null;
          hl = null;
        }
        mAsRich = v;
        if (undo !is null) {
          delete undo;
          undo = new UndoStack(mAsRich, false, !singleline);
        }
        if (redo !is null) {
          delete redo;
          redo = new UndoStack(mAsRich, true, !singleline);
        }
        gb.hasHiBuffer = v; // "rich" mode require highlighting buffer, normal mode doesn't, as it has no highlighter
        if (!gb.hasHiBuffer) assert(0, "out of memory"); // alas
      }
    }

    @property bool hasHiBuffer () const pure nothrow @safe @nogc { pragma(inline, true); return gb.hasHiBuffer; }
    @property void hasHiBuffer (bool v) nothrow @trusted @nogc {
      if (mAsRich) return; // cannot change
      if (hl !is null) return; // cannot change too
      gb.hasHiBuffer = v; // otherwise it is ok to change it
    }

    int x0 () const pure nothrow @safe @nogc { pragma(inline, true); return winx; } ///
    int y0 () const pure nothrow @safe @nogc { pragma(inline, true); return winy; } ///
    int width () const pure nothrow @safe @nogc { pragma(inline, true); return winw; } ///
    int height () const pure nothrow @safe @nogc { pragma(inline, true); return winh; } ///

    void x0 (int v) nothrow { pragma(inline, true); move(v, winy); } ///
    void y0 (int v) nothrow { pragma(inline, true); move(winx, v); } ///
    void width (int v) nothrow { pragma(inline, true); resize(v, winh); } ///
    void height (int v) nothrow { pragma(inline, true); resize(winw, v); } ///

    /// has any effect only if you are using `insertText()` and `deleteText()` API!
    bool readonly () const pure nothrow @safe @nogc { pragma(inline, true); return mReadOnly; }
    void readonly (bool v) nothrow { pragma(inline, true); mReadOnly = v; } ///

    /// "single line" mode, for line editors
    bool singleline () const pure nothrow @safe @nogc { pragma(inline, true); return mSingleLine; }

    /// "buffer change counter"
    uint bufferCC () const pure nothrow @safe @nogc { pragma(inline, true); return gb.bufferChangeCounter; }
    void bufferCC (uint v) pure nothrow { pragma(inline, true); gb.bufferChangeCounter = v; } ///

    bool killTextOnChar () const pure nothrow @safe @nogc { pragma(inline, true); return mKillTextOnChar; } ///
    void killTextOnChar (bool v) nothrow { ///
      pragma(inline, true);
      if (mKillTextOnChar != v) {
        mKillTextOnChar = v;
        fullDirty();
      }
    }

    bool inPixels () const pure nothrow @safe @nogc { pragma(inline, true); return (lineHeightPixels != 0); } ///

    /// this can recalc height cache
    int linesPerWindow () nothrow {
      pragma(inline, true);
      return
        lineHeightPixels == 0 || lineHeightPixels == 1 ? winh :
        lineHeightPixels > 0 ? (winh <= lineHeightPixels ? 1 : winh/lineHeightPixels) :
        calcLinesPerWindow();
    }

    /// this can recalc height cache
    int visibleLinesPerWindow () nothrow {
      pragma(inline, true);
      return
        lineHeightPixels == 0 || lineHeightPixels == 1 ? winh :
        lineHeightPixels > 0 ? (winh <= lineHeightPixels ? 1 : winh/lineHeightPixels+(winh%lineHeightPixels ? 1 : 0)) :
        calcVisLinesPerWindow();
    }
  }

  // for variable line height
  protected final int calcVisLinesPerWindow () nothrow {
    if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
    int hgtleft = winh;
    if (hgtleft < 1) return 1; // just in case
    int lidx = mTopLine;
    int lcount = 0;
    while (hgtleft > 0) {
      auto lh = lc.lineHeightPixels(lidx++);
      ++lcount;
      hgtleft -= lh;
    }
    return lcount;
  }

  // for variable line height
  protected final int calcLinesPerWindow () nothrow {
    if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
    int hgtleft = winh;
    if (hgtleft < 1) return 1; // just in case
    int lidx = mTopLine;
    int lcount = 0;
    //{ import core.stdc.stdio; printf("=== clpw ===\n"); }
    for (;;) {
      auto lh = lc.lineHeightPixels(lidx++);
      //if (gb.mLineCount > 0) { import core.stdc.stdio; printf("*clpw: lidx=%d; height=%d; hgtleft=%d\n", lidx-1, lh, hgtleft); }
      hgtleft -= lh;
      if (hgtleft >= 0) ++lcount;
      if (hgtleft <= 0) break;
    }
    //{ import core.stdc.stdio; printf("clpw: %d\n", lcount); }
    return (lcount ? lcount : 1);
  }

  /// has lille sense if `inPixels` is false
  final int linePixelHeight (int lidx) nothrow {
    if (!inPixels) return 1;
    if (lineHeightPixels > 0) {
      return lineHeightPixels;
    } else {
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      return lc.lineHeightPixels(lidx);
    }
  }

  /// resize control
  void resize (int nw, int nh) nothrow {
    if (nw < 2) nw = 2;
    if (nh < 1) nh = 1;
    if (nw != winw || nh != winh) {
      winw = nw;
      winh = nh;
      auto nvl = visibleLinesPerWindow;
      setDirtyLinesLength(nvl);
      makeCurLineVisible();
      fullDirty();
    }
  }

  /// move control
  void move (int nx, int ny) nothrow {
    if (winx != nx || winy != ny) {
      winx = nx;
      winy = ny;
      fullDirty();
    }
  }

  /// move and resize control
  void moveResize (int nx, int ny, int nw, int nh) nothrow {
    move(nx, ny);
    resize(nw, nh);
  }

  final @property void curx (int v) nothrow @system { gotoXY(v, cy); } ///
  final @property void cury (int v) nothrow @system { gotoXY(cx, v); } ///

  final @property nothrow {
    /// has active marked block?
    bool hasMarkedBlock () const pure @safe @nogc { pragma(inline, true); return (bstart < bend); }

    int curx () const pure @safe @nogc { pragma(inline, true); return cx; } ///
    int cury () const pure @safe @nogc { pragma(inline, true); return cy; } ///
    int xofs () const pure @safe @nogc { pragma(inline, true); return mXOfs; } ///

    int topline () const pure @safe @nogc { pragma(inline, true); return mTopLine; } ///
    int linecount () const pure @safe @nogc { pragma(inline, true); return lc.linecount; } ///
    int textsize () const pure @safe @nogc { pragma(inline, true); return gb.textsize; } ///

    char opIndex (int pos) const pure @safe @nogc { pragma(inline, true); return gb[pos]; } /// returns '\n' for out-of-bounds query

    /// returns '\n' for out-of-bounds query
    dchar dcharAt (int pos) const pure {
      auto ts = gb.textsize;
      if (pos < 0 || pos >= ts) return '\n';
      if (!lc.utfuck) {
        final switch (codepage) {
          case CodePage.koi8u: return koi2uni(gb[pos]);
          case CodePage.cp1251: return cp12512uni(gb[pos]);
          case CodePage.cp866: return cp8662uni(gb[pos]);
        }
        assert(0);
      }
      Utf8DecoderFast udc;
      while (pos < ts) {
        if (udc.decodeSafe(cast(ubyte)gb[pos++])) return cast(dchar)udc.codepoint;
      }
      return udc.replacement;
    }

    /// this advances `pos`, and returns '\n' for out-of-bounds query
    dchar dcharAtAdvance (ref int pos) const pure {
      auto ts = gb.textsize;
      if (pos < 0) { pos = 0; return '\n'; }
      if (pos >= ts) { pos = ts; return '\n'; }
      if (!lc.utfuck) {
        immutable char ch = gb[pos++];
        final switch (codepage) {
          case CodePage.koi8u: return koi2uni(ch);
          case CodePage.cp1251: return cp12512uni(ch);
          case CodePage.cp866: return cp8662uni(ch);
        }
        assert(0);
      }
      Utf8DecoderFast udc;
      while (pos < ts) {
        if (udc.decodeSafe(cast(ubyte)gb[pos++])) return cast(dchar)udc.codepoint;
      }
      return udc.replacement;
    }

    /// this works correctly with utfuck
    int nextpos (int pos) const pure {
      if (pos < 0) return 0;
      immutable ts = gb.textsize;
      if (pos >= ts) return ts;
      if (!lc.utfuck) return pos+1;
      Utf8DecoderFast udc;
      while (pos < ts) if (udc.decodeSafe(cast(ubyte)gb[pos++])) break;
      return pos;
    }

    /// this sometimes works correctly with utfuck
    int prevpos (int pos) const pure {
      if (pos <= 0) return 0;
      immutable ts = gb.textsize;
      if (ts == 0) return 0;
      if (pos > ts) pos = ts;
      --pos;
      if (lc.utfuck) {
        while (pos > 0 && !isValidUtf8Start(cast(ubyte)gb[pos])) --pos;
      }
      return pos;
    }

    bool textChanged () const pure { pragma(inline, true); return txchanged; } ///
    void textChanged (bool v) pure { pragma(inline, true); txchanged = v; } ///

    bool visualtabs () const pure { pragma(inline, true); return (lc.visualtabs && lc.tabsize > 0); } ///

    ///
    void visualtabs (bool v) {
      if (lc.visualtabs != v) {
        lc.visualtabs = v;
        fullDirty();
      }
    }

    ubyte tabsize () const pure { pragma(inline, true); return lc.tabsize; } ///

    ///
    void tabsize (ubyte v) {
      if (lc.tabsize != v) {
        lc.tabsize = v;
        if (lc.visualtabs) fullDirty();
      }
    }

    /// mark whole visible text as dirty
    final void fullDirty () nothrow { dirtyLines[] = -1; }
  }

  ///
  @property void topline (int v) nothrow {
    if (v < 0) v = 0;
    if (v > lc.linecount) v = lc.linecount-1;
    immutable auto moldtop = mTopLine;
    mTopLine = v; // for linesPerWindow
    if (v+linesPerWindow > lc.linecount) {
      v = lc.linecount-linesPerWindow;
      if (v < 0) v = 0;
    }
    if (v != moldtop) {
      mTopLine = moldtop;
      pushUndoCurPos();
      mTopLine = v;
    }
  }

  /// absolute coordinates in text
  final void gotoXY(bool vcenter=false) (int nx, int ny) nothrow {
    if (nx < 0) nx = 0;
    if (ny < 0) ny = 0;
    if (ny >= lc.linecount) ny = lc.linecount-1;
    auto pos = lc.xy2pos(nx, ny);
    lc.pos2xy(pos, nx, ny);
    if (nx != cx || ny != cy) {
      pushUndoCurPos();
      cx = nx;
      cy = ny;
      static if (vcenter) makeCurLineVisibleCentered(); else makeCurLineVisible();
    }
  }

  ///
  final void gotoPos(bool vcenter=false) (int pos) nothrow {
    if (pos < 0) pos = 0;
    if (pos > gb.textsize) pos = gb.textsize;
    int rx, ry;
    lc.pos2xy(pos, rx, ry);
    gotoXY!vcenter(rx, ry);
  }

  final int curpos () nothrow { pragma(inline, true); return lc.xy2pos(cx, cy); } ///

  ///
  void clearUndo () nothrow {
    if (undo !is null) undo.clear();
    if (redo !is null) redo.clear();
  }

  ///
  void clear () nothrow {
    lc.clear();
    txchanged = false;
    if (undo !is null) undo.clear();
    if (redo !is null) redo.clear();
    cx = cy = mTopLine = mXOfs = 0;
    prevTopLine = -1;
    prevXOfs = -1;
    dirtyLines[] = -1;
    bstart = bend = -1;
    markingBlock = false;
    lastBGEnd = false;
    txchanged = false;
  }

  ///
  void clearAndDisableUndo () {
    if (undo !is null) delete undo;
    if (redo !is null) delete redo;
  }

  ///
  void reinstantiateUndo () {
    if (undo is null) undo = new UndoStack(mAsRich, false, !mSingleLine);
    if (redo is null) redo = new UndoStack(mAsRich, true, !mSingleLine);
  }

  ///
  void loadFile (const(char)[] fname) { loadFile(VFile(fname)); }

  ///
  void loadFile (VFile fl) {
    import core.stdc.stdlib : malloc, free;
    clear();
    scope(failure) clear();
    auto fpos = fl.tell;
    auto fsz = fl.size;
    if (fpos < fsz) {
      if (fsz-fpos >= gb.tbmax) throw new Exception("text too big");
      uint filesize = cast(uint)(fsz-fpos);
      if (!lc.resizeBuffer(filesize)) throw new Exception("text too big");
      scope(failure) clear();
      fl.rawReadExact(lc.getBufferPtr[]);
      if (!lc.finishLoading()) throw new Exception("out of memory");
      //HACK!
      /*
      if (fsz-fpos >= gb.tbmax) throw new Exception("text too big");
      immutable uint sz = cast(uint)(fsz-fpos);
      if (!lc.growTBuf(sz)) throw new Exception("out of memory");
      fl.rawReadExact(lc.tbuf[0..sz]);
      lc.tbused = sz;
      lc.gapstart = sz;
      lc.gapend = lc.tbsize;
      int lncount = lc.countEols(lc.tbuf[0..sz])+1; // '\n' means "start new line after me, unconditionally", hence +1
      if (!lc.growLineCache(lncount)) throw new Exception("out of memory");
      lc.mLineCount = lncount;
      lc.locused = 0;
      */
    }
  }

  ///
  void saveFile (const(char)[] fname) { saveFile(VFile(fname, "w")); }

  ///
  void saveFile (VFile fl) {
    gb.forEachBufPart(0, gb.textsize, delegate (const(char)[] buf) { fl.rawWriteExact(buf); });
    txchanged = false;
    if (undo !is null) undo.alwaysChanged();
    if (redo !is null) redo.alwaysChanged();
  }

  /// attach new highlighter; return previous one
  /// note that you can't reuse one highlighter for several editors!
  EditorHL attachHiglighter (EditorHL ahl) {
    if (mAsRich) { assert(hl is null); return null; } // oops
    if (ahl is hl) return ahl; // nothing to do
    EditorHL prevhl = hl;
    if (ahl is null) {
      // detach
      if (hl !is null) {
        hl.gb = null;
        hl.lc = null;
        hl = null;
        gb.hasHiBuffer = false; // don't need it
        fullDirty();
      }
      return prevhl; // return previous
    }
    if (ahl.lc !is null) {
      if (ahl.lc !is lc) throw new Exception("highlighter already used by another editor");
      if (ahl !is hl) assert(0, "something is VERY wrong");
      return ahl;
    }
    if (hl !is null) { hl.gb = null; hl.lc = null; }
    ahl.gb = gb;
    ahl.lc = lc;
    hl = ahl;
    gb.hasHiBuffer = true; // need it
    if (!gb.hasHiBuffer) assert(0, "out of memory"); // alas
    ahl.lineChanged(0, true);
    fullDirty();
    return prevhl;
  }

  ///
  EditorHL detachHighlighter () {
    if (mAsRich) { assert(hl is null); return null; } // oops
    auto res = hl;
    if (res !is null) {
      hl.gb = null;
      hl.lc = null;
      hl = null;
      gb.hasHiBuffer = false; // don't need it
      fullDirty();
    }
    return res;
  }

  /// override this method to draw something before any other page drawing will be done
  public void drawPageBegin () {}

  /// override this method to draw one text line
  /// highlighting is done, other housekeeping is done, only draw
  /// lidx is always valid
  /// must repaint the whole line
  /// use `winXXX` vars to know window dimensions
  public abstract void drawLine (int lidx, int yofs, int xskip);

  /// just clear the line; you have to override this, 'cause it is used to clear empty space
  /// use `winXXX` vars to know window dimensions
  public abstract void drawEmptyLine (int yofs);

  /// override this method to draw something after page was drawn, but before drawing the cursor
  public void drawPageMisc () {}

  /// override this method to draw status line; it will be called after `drawPageBegin()`
  public void drawStatus ();

  /// override this method to draw text cursor; it will be called after `drawPageMisc()`
  public abstract void drawCursor ();

  /// override this method to draw something (or flush drawing buffer) after everything was drawn
  public void drawPageEnd () {}

  /** draw the page; it will fix coords, call necessary methods and so on. you are usually don't need to override this.
   * page drawing flow:
   *   drawPageBegin();
   *   page itself with drawLine() or drawEmptyLine();
   *   drawPageMisc();
   *   drawStatus();
   *   drawCursor();
   *   drawPageEnd();
   */
  void drawPage () {
    makeCurLineVisible();

    if (prevTopLine != mTopLine || prevXOfs != mXOfs) {
      prevTopLine = mTopLine;
      prevXOfs = mXOfs;
      dirtyLines[] = -1;
    }

    drawPageBegin();
    immutable int lhp = lineHeightPixels;
    immutable int ydelta = (inPixels ? lhp : 1);
    bool alwaysDirty = false;
    auto pos = lc.xy2pos(0, mTopLine);
    auto lc = lc.linecount;
    int lyofs = 0;
    //TODO: optimize redrawing for variable line height mode
    foreach (int y; 0..visibleLinesPerWindow) {
      bool dirty = (mTopLine+y < lc && hl !is null && hl.fixLine(mTopLine+y));
      if (!alwaysDirty) {
        if (lhp < 0) {
          // variable line height, hacks
          alwaysDirty = (!alwaysDirty && y < dirtyLines.length ? (dirtyLines.ptr[y] != linePixelHeight(mTopLine+y)) : true);
        } else if (!dirty && y < dirtyLines.length) {
          // tty or constant pixel height
          dirty = (dirtyLines.ptr[y] != 0);
        }
        dirty = true;
      }
      if (dirty || alwaysDirty) {
        if (y < dirtyLines.length) dirtyLines.ptr[y] = (lhp >= 0 ? 0 : linePixelHeight(mTopLine+y));
        if (mTopLine+y < lc) {
          drawLine(mTopLine+y, lyofs, mXOfs);
        } else {
          drawEmptyLine(lyofs);
        }
      }
      lyofs += (ydelta > 0 ? ydelta : linePixelHeight(mTopLine+y));
    }
    drawPageMisc();
    drawStatus();
    drawCursor();
    drawPageEnd();
  }

  /// force cursor coordinates to be in text
  final void normXY () nothrow {
    lc.pos2xy(curpos, cx, cy);
  }

  ///
  final void makeCurXVisible () nothrow {
    // use "real" x coordinate to calculate x offset
    if (cx < 0) cx = 0;
    int rx;
    if (!inPixels) {
      int ry;
      lc.pos2xyVT(curpos, rx, ry);
      if (rx < mXOfs) mXOfs = rx;
      if (rx-mXOfs >= winw) mXOfs = rx-winw+1;
    } else {
      rx = localCursorX();
      rx += mXOfs;
      if (rx < mXOfs) mXOfs = rx-8;
      if (rx+4-mXOfs > winw) mXOfs = rx-winw+4;
    }
    if (mXOfs < 0) mXOfs = 0;
  }

  /// in symbols, not chars
  final int linelen (int lidx) nothrow {
    if (lidx < 0 || lidx >= lc.linecount) return 0;
    auto pos = lc.line2pos(lidx);
    auto ts = gb.textsize;
    if (pos > ts) pos = ts;
    int res = 0;
    if (!lc.utfuck) {
      if (mSingleLine) return ts-pos;
      while (pos < ts) {
        if (gb[pos++] == '\n') break;
        ++res;
      }
    } else {
      immutable bool sl = mSingleLine;
      while (pos < ts) {
        char ch = gb[pos++];
        if (!sl && ch == '\n') break;
        ++res;
        if (ch >= 128) {
          --pos;
          pos += gb.utfuckLenAt(pos);
        }
      }
    }
    return res;
  }

  /// cursor position in "local" coords: from widget (x0,y0), possibly in pixels
  final int localCursorX () nothrow {
    int rx, ry;
    if (!inPixels) {
      lc.pos2xyVT(curpos, rx, ry);
      rx -= mXOfs;
    } else {
      lc.pos2xy(curpos, rx, ry);
      if (rx == 0) return 0-mXOfs;
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      textMeter.reset(visualtabs ? lc.tabsize : 0);
      scope(exit) textMeter.finish(); // just in case
      auto pos = lc.line2pos(ry);
      auto ts = gb.textsize;
      immutable bool ufuck = lc.utfuck;
      GapBuffer.HighState* hs;
      if (mSingleLine) {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          hs = &gb.hi(pos);
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch, *hs);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos), *hs);
          }
          --rx;
          if (rx == 0) break;
        }
      } else {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          if (ch == '\n') break;
          hs = &gb.hi(pos);
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch, *hs);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos), *hs);
          }
          --rx;
          if (rx == 0) break;
        }
      }
      rx = textMeter.currWidth()-mXOfs;
    }
    return rx;
  }

  /// cursor position in "local" coords: from widget (x0,y0), possibly in pixels
  final void localCursorXY (out int lcx, out int lcy) nothrow {
    int rx, ry;
    if (!inPixels) {
      lc.pos2xyVT(curpos, rx, ry);
      ry -= mTopLine;
      rx -= mXOfs;
      lcx = rx;
      lcy = ry;
    } else {
      lc.pos2xy(curpos, rx, ry);
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      if (lineHeightPixels > 0) {
        lcy = (ry-mTopLine)*lineHeightPixels;
      } else {
        if (ry >= mTopLine) {
          for (int ll = mTopLine; ll < ry; ++ll) lcy += lc.lineHeightPixels(ll);
        } else {
          for (int ll = mTopLine-1; ll >= ry; --ll) lcy -= lc.lineHeightPixels(ll);
        }
      }
      if (rx == 0) { lcx = 0-mXOfs; return; }
      textMeter.reset(visualtabs ? lc.tabsize : 0);
      scope(exit) textMeter.finish(); // just in case
      auto pos = lc.line2pos(ry);
      auto ts = gb.textsize;
      immutable bool ufuck = lc.utfuck;
      GapBuffer.HighState* hs;
      if (mSingleLine) {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          hs = &gb.hi(pos);
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch, *hs);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos), *hs);
          }
          --rx;
          if (rx == 0) break;
        }
      } else {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          if (ch == '\n') break;
          hs = &gb.hi(pos);
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch, *hs);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos), *hs);
          }
          --rx;
          if (rx == 0) break;
        }
      }
      lcx = textMeter.currWidth()-mXOfs;
    }
  }

  /// convert coordinates in widget into text coordinates; can be used to convert mouse click position into text position
  /// WARNING: ty can be equal to linecount or -1!
  final void widget2text (int mx, int my, out int tx, out int ty) nothrow {
    if (!inPixels) {
      int ry = my+mTopLine;
      if (ry < 0) { ty = -1; return; } // tx is zero here
      if (ry >= lc.linecount) { ty = lc.linecount; return; } // tx is zero here
      if (mx <= 0 && mXOfs == 0) return; // tx is zero here
      // ah, screw it! user should not call this very often, so i can stop care about speed.
      int visx = -mXOfs;
      auto pos = lc.line2pos(ry);
      auto ts = gb.textsize;
      int rx = 0;
      immutable bool ufuck = lc.utfuck;
      immutable bool sl = mSingleLine;
      while (pos < ts) {
        // advance one symbol
        char ch = gb[pos];
        if (!sl && ch == '\n') { tx = rx; return; } // done anyway
        int nextx = visx+1;
        if (ch == '\t' && visualtabs) {
          // hack!
          nextx = ((visx+mXOfs)/tabsize+1)*tabsize-mXOfs;
        }
        if (mx >= visx && mx < nextx) { tx = rx; return; }
        visx = nextx;
        if (!ufuck || ch < 128) {
          ++pos;
        } else {
          pos = nextpos(pos);
        }
        ++rx;
      }
    } else {
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      int ry;
      if (lineHeightPixels > 0) {
        ry = my/lineHeightPixels+mTopLine;
      } else {
        ry = mTopLine;
        if (my >= 0) {
          // down
          int lcy = 0;
          while (lcy < my) {
            lcy += lc.lineHeightPixels(ry);
            if (lcy > my) break;
            ++ry;
            if (lcy == my) break;
          }
        } else {
          // up
          ry = mTopLine-1;
          int lcy = 0;
          while (ry >= 0) {
            int upy = lcy-lc.lineHeightPixels(ry);
            if (my >= upy && my < lcy) break;
            lcy = upy;
          }
        }
      }
      if (ry < 0) { ty = -1; return; } // tx is zero here
      if (ry >= lc.linecount) { ty = lc.linecount; return; } // tx is zero here
      ty = ry;
      if (mx <= 0 && mXOfs == 0) return; // tx is zero here
      // now the hard part
      textMeter.reset(visualtabs ? lc.tabsize : 0);
      scope(exit) textMeter.finish(); // just in case
      int visx = -mXOfs, prevx;
      auto pos = lc.line2pos(ry);
      auto ts = gb.textsize;
      int rx = 0;
      immutable bool ufuck = lc.utfuck;
      immutable bool sl = mSingleLine;
      GapBuffer.HighState* hs;
      while (pos < ts) {
        // advance one symbol
        char ch = gb[pos];
        if (!sl && ch == '\n') { tx = rx; return; } // done anyway
        hs = &gb.hi(pos);
        prevx = visx;
        if (!ufuck || ch < 128) {
          visx = textMeter.advance(cast(dchar)ch, *hs)-mXOfs;
          ++pos;
        } else {
          visx = textMeter.advance(dcharAtAdvance(pos), *hs)-mXOfs;
        }
        // prevx is previous char x start
        // visx is current char x start
        // so if our mx is in [prevx..visx), we are at previous char
        if (mx >= prevx && mx < visx) {
          // it is more natural this way
          if (rx > 0 && mx < prevx+(visx-prevx)/2) --rx;
          tx = rx;
          return;
        }
        ++rx;
      }
    }
  }

  ///
  final void makeCurLineVisible () nothrow {
    if (cy < 0) cy = 0;
    if (cy >= lc.linecount) cy = lc.linecount-1;
    if (cy < mTopLine) {
      mTopLine = cy;
    } else {
      if (cy > mTopLine+linesPerWindow-1) {
        mTopLine = cy-linesPerWindow+1;
        if (mTopLine < 0) mTopLine = 0;
      }
    }
    setDirtyLinesLength(visibleLinesPerWindow);
    makeCurXVisible();
  }

  ///
  final void makeCurLineVisibleCentered (bool forced=false) nothrow {
    if (forced || !isCurLineVisible) {
      if (cy < 0) cy = 0;
      if (cy >= lc.linecount) cy = lc.linecount-1;
      mTopLine = cy-linesPerWindow/2;
      if (mTopLine < 0) mTopLine = 0;
      if (mTopLine+linesPerWindow > lc.linecount) {
        mTopLine = lc.linecount-linesPerWindow;
        if (mTopLine < 0) mTopLine = 0;
      }
    }
    setDirtyLinesLength(visibleLinesPerWindow);
    makeCurXVisible();
  }

  ///
  final bool isCurLineVisible () nothrow {
    if (cy < mTopLine) return false;
    if (cy > mTopLine+linesPerWindow-1) return false;
    return true;
  }

  /// `updateDown`: update all the page (as new lines was inserted/removed)
  final void lineChanged (int lidx, bool updateDown) {
    if (lidx < 0 || lidx >= lc.linecount) return;
    if (hl !is null) hl.lineChanged(lidx, updateDown);
    if (lidx < mTopLine) { if (updateDown) dirtyLines[] = -1; return; }
    if (lidx >= mTopLine+linesPerWindow) return;
    immutable stl = lidx-mTopLine;
    assert(stl >= 0);
    if (stl < dirtyLines.length) {
      if (updateDown) {
        dirtyLines[stl..$] = -1;
      } else {
        dirtyLines.ptr[stl] = -1;
      }
    }
  }

  ///
  final void lineChangedByPos (int pos, bool updateDown) { return lineChanged(lc.pos2line(pos), updateDown); }

  ///
  final void markLinesDirty (int lidx, int count) nothrow {
    if (prevTopLine != mTopLine || prevXOfs != mXOfs) return; // we will refresh the whole page anyway
    if (count < 1 || lidx >= lc.linecount) return;
    if (count > lc.linecount) count = lc.linecount;
    if (lidx >= mTopLine+linesPerWindow) return;
    int le = lidx+count;
    if (le <= mTopLine) { dirtyLines[] = -1; return; } // just in case
    if (lidx < mTopLine) { dirtyLines[] = -1; lidx = mTopLine; return; } // just in cale
    if (le > mTopLine+visibleLinesPerWindow) le = mTopLine+visibleLinesPerWindow;
    immutable stl = lidx-mTopLine;
    assert(stl >= 0);
    if (stl < dirtyLines.length) {
      auto el = le-mTopLine;
      if (el > dirtyLines.length) el = cast(int)dirtyLines.length;
      dirtyLines.ptr[stl..el] = -1;
    }
  }

  ///
  final void markLinesDirtySE (int lidxs, int lidxe) nothrow {
    if (lidxe < lidxs) { int tmp = lidxs; lidxs = lidxe; lidxe = tmp; }
    markLinesDirty(lidxs, lidxe-lidxs+1);
  }

  ///
  final void markRangeDirty (int pos, int len) nothrow {
    if (prevTopLine != mTopLine || prevXOfs != mXOfs) return; // we will refresh the whole page anyway
    int l0 = lc.pos2line(pos);
    int l1 = lc.pos2line(pos+len+1);
    markLinesDirtySE(l0, l1);
  }

  ///
  final void markBlockDirty () nothrow {
    //FIXME: optimize updating with block boundaries
    if (bstart >= bend) return;
    markRangeDirty(bstart, bend-bstart);
  }

  /// do various fixups before text deletion
  /// cursor coords *may* be already changed
  /// will be called before text deletion by `deleteText` or `replaceText` APIs
  /// eolcount: number of eols in (to be) deleted block
  protected void willBeDeleted (int pos, int len, int eolcount) nothrow {
    //FIXME: optimize updating with block boundaries
    if (len < 1) return; // just in case
    assert(pos >= 0 && cast(long)pos+len <= gb.textsize);
    bookmarkDeletionFix(pos, len, eolcount);
    if (hasMarkedBlock) {
      if (pos+len <= bstart) {
        // move whole block up
        markBlockDirty();
        bstart -= len;
        bend -= len;
        markBlockDirty();
        lastBGEnd = false;
      } else if (pos <= bstart && pos+len >= bend) {
        // whole block will be deleted
        doBlockResetMark(false); // skip undo
      } else if (pos >= bstart && pos+len <= bend) {
        // deleting something inside block, move end
        markBlockDirty();
        bend -= len;
        if (bstart >= bend) {
          doBlockResetMark(false); // skip undo
        } else {
          markBlockDirty();
          lastBGEnd = true;
        }
      } else if (pos >= bstart && pos < bend && pos+len > bend) {
        // chopping block end
        markBlockDirty();
        bend = pos;
        if (bstart >= bend) {
          doBlockResetMark(false); // skip undo
        } else {
          markBlockDirty();
          lastBGEnd = true;
        }
      }
    }
  }

  /// do various fixups after text deletion
  /// cursor coords *may* be already changed
  /// will be called after text deletion by `deleteText` or `replaceText` APIs
  /// eolcount: number of eols in deleted block
  /// pos and len: they were valid *before* deletion!
  protected void wasDeleted (int pos, int len, int eolcount) nothrow {
  }

  /// do various fixups before text insertion
  /// cursor coords *may* be already changed
  /// will be called before text insertion by `insertText` or `replaceText` APIs
  /// eolcount: number of eols in (to be) inserted block
  protected void willBeInserted (int pos, int len, int eolcount) nothrow {
  }

  /// do various fixups after text insertion
  /// cursor coords *may* be already changed
  /// will be called after text insertion by `insertText` or `replaceText` APIs
  /// eolcount: number of eols in inserted block
  protected void wasInserted (int pos, int len, int eolcount) nothrow {
    //FIXME: optimize updating with block boundaries
    if (len < 1) return;
    assert(pos >= 0 && cast(long)pos+len <= gb.textsize);
    bookmarkInsertionFix(pos, len, eolcount);
    if (markingBlock && pos == bend) {
      bend += len;
      markBlockDirty();
      lastBGEnd = true;
      return;
    }
    if (hasMarkedBlock) {
      if (pos <= bstart) {
        // move whole block down
        markBlockDirty();
        bstart += len;
        bend += len;
        markBlockDirty();
        lastBGEnd = false;
      } else if (pos < bend) {
        // move end of block down
        markBlockDirty();
        bend += len;
        markBlockDirty();
        lastBGEnd = true;
      }
    }
  }

  /// should be called after cursor position change
  protected final void growBlockMark () nothrow {
    if (!markingBlock || bstart < 0) return;
    makeCurLineVisible();
    int ry;
    int pos = curpos;
    if (pos < bstart) {
      if (lastBGEnd) {
        // move end
        ry = lc.pos2line(bend);
        bend = bstart;
        bstart = pos;
        lastBGEnd = false;
      } else {
        // move start
        ry = lc.pos2line(bstart);
        if (bstart == pos) return;
        bstart = pos;
        lastBGEnd = false;
      }
    } else if (pos > bend) {
      // move end
      if (bend == pos) return;
      ry = lc.pos2line(bend-1);
      bend = pos;
      lastBGEnd = true;
    } else if (pos >= bstart && pos < bend) {
      // shrink block
      if (lastBGEnd) {
        // from end
        if (bend == pos) return;
        ry = lc.pos2line(bend-1);
        bend = pos;
      } else {
        // from start
        if (bstart == pos) return;
        ry = lc.pos2line(bstart);
        bstart = pos;
      }
    }
    markLinesDirtySE(ry, cy);
  }

  /// all the following text operations will be grouped into one undo action
  bool undoGroupStart () {
    return (undo !is null ? undo.addGroupStart(this) : false);
  }

  /// end undo action started with `undoGroupStart()`
  bool undoGroupEnd () {
    return (undo !is null ? undo.addGroupEnd(this) : false);
  }

  /// build autoindent for the current line, put it into `indentText`
  /// `indentText` will include '\n'
  protected final void buildIndent (int pos) {
    if (indentText.length) { indentText.length = 0; indentText.assumeSafeAppend; }
    void putToIT (char ch) {
      auto optr = indentText.ptr;
      indentText ~= ch;
      if (optr !is indentText.ptr) {
        import core.memory : GC;
        if (indentText.ptr is GC.addrOf(indentText.ptr)) {
          GC.setAttr(indentText.ptr, GC.BlkAttr.NO_INTERIOR); // less false positives
        }
      }
    }
    putToIT('\n');
    pos = lc.line2pos(lc.pos2line(pos));
    auto ts = gb.textsize;
    int curx = 0;
    while (pos < ts) {
      if (curx == cx) break;
      auto ch = gb[pos];
      if (ch == '\n') break;
      if (ch > ' ') break;
      putToIT(ch);
      ++pos;
      ++curx;
    }
  }

  /// delete text, save undo, mark updated lines
  /// return `false` if operation cannot be performed
  /// if caller wants to delete more text than buffer has, it is ok
  /// calls `dg` *after* undo saving, but before `willBeDeleted()`
  final bool deleteText(string movecursor="none") (int pos, int count, scope void delegate (int pos, int count) dg=null) {
    static assert(movecursor == "none" || movecursor == "start" || movecursor == "end");
    if (mReadOnly) return false;
    killTextOnChar = false;
    auto ts = gb.textsize;
    if (pos < 0 || pos >= ts || count < 0) return false;
    if (ts-pos < count) count = ts-pos;
    if (count > 0) {
      bool undoOk = false;
      if (undo !is null) undoOk = undo.addTextRemove(this, pos, count);
      if (dg !is null) dg(pos, count);
      int delEols = (!mSingleLine ? gb.countEolsInRange(pos, count) : 0);
      willBeDeleted(pos, count, delEols);
      //writeLogAction(pos, -count);
      // hack: if new linecount is different, there was '\n' in text
      auto olc = lc.linecount;
      if (!lc.remove(pos, count)) {
        if (undoOk) undo.popUndo(); // remove undo record
        return false;
      }
      txchanged = true;
      static if (movecursor != "none") lc.pos2xy(pos, cx, cy);
      wasDeleted(pos, count, delEols);
      lineChangedByPos(pos, (lc.linecount != olc));
    } else {
      static if (movecursor != "none") {
        int rx, ry;
        lc.pos2xy(curpos, rx, ry);
        if (rx != cx || ry != cy) {
          if (pushUndoCurPos()) {
            cx = rx;
            cy = ry;
            markLinesDirty(cy, 1);
          }
        }
      }
    }
    return true;
  }

  /// ugly name is intentional
  /// this replaces editor text, clears undo and sets `killTextOnChar` if necessary
  /// it also ignores "readonly" flag
  final bool setNewText (const(char)[] text, bool killOnChar=true) {
    auto oldro = mReadOnly;
    scope(exit) mReadOnly = oldro;
    mReadOnly = false;
    clear();
    auto res = insertText!"end"(0, text);
    clearUndo();
    if (mSingleLine) killTextOnChar = killOnChar;
    fullDirty();
    return res;
  }

  /// insert text, save undo, mark updated lines
  /// return `false` if operation cannot be performed
  final bool insertText(string movecursor="none", bool doIndent=true) (int pos, const(char)[] str) {
    static assert(movecursor == "none" || movecursor == "start" || movecursor == "end");
    if (mReadOnly) return false;
    if (mKillTextOnChar) {
      killTextOnChar = false;
      if (gb.textsize > 0) {
        undoGroupStart();
        bstart = bend = -1;
        markingBlock = false;
        deleteText!"start"(0, gb.textsize);
        undoGroupEnd();
      }
    }
    auto ts = gb.textsize;
    if (pos < 0 || str.length >= int.max/3) return false;
    if (pos > ts) pos = ts;
    if (str.length > 0) {
      int nlc = (!mSingleLine ? GapBuffer.countEols(str) : 0);
      static if (doIndent) {
        if (nlc) {
          // want indenting and has at least one newline, hard case
          buildIndent(pos);
          if (indentText.length) {
            int toinsert = cast(int)str.length+nlc*(cast(int)indentText.length-1);
            bool undoOk = false;
            bool doRollback = false;
            // record undo
            if (undo !is null) undoOk = undo.addTextInsert(this, pos, toinsert);
            willBeInserted(pos, toinsert, nlc);
            auto spos = pos;
            auto ipos = pos;
            while (str.length > 0) {
              int elp = GapBuffer.findEol(str);
              if (elp < 0) elp = cast(int)str.length;
              if (elp > 0) {
                // insert text
                auto newpos = lc.put(ipos, str[0..elp]);
                if (newpos < 0) { doRollback = true; break; }
                ipos = newpos;
                str = str[elp..$];
              } else {
                // insert newline
                assert(str[0] == '\n');
                auto newpos = lc.put(ipos, indentText);
                if (newpos < 0) { doRollback = true; break; }
                ipos = newpos;
                str = str[1..$];
              }
            }
            if (doRollback) {
              // operation failed, rollback it
              if (ipos > spos) lc.remove(spos, ipos-spos); // remove inserted text
              if (undoOk) undo.popUndo(); // remove undo record
              return false;
            }
            //if (ipos-spos != toinsert) { import core.stdc.stdio : stderr, fprintf; fprintf(stderr, "spos=%d; ipos=%d; ipos-spos=%d; toinsert=%d; nlc=%d; sl=%d; il=%d\n", spos, ipos, ipos-spos, toinsert, nlc, cast(int)str.length, cast(int)indentText.length); }
            assert(ipos-spos == toinsert);
                 static if (movecursor == "start") lc.pos2xy(spos, cx, cy);
            else static if (movecursor == "end") lc.pos2xy(ipos, cx, cy);
            txchanged = true;
            lineChangedByPos(spos, true);
            wasInserted(spos, toinsert, nlc);
            return true;
          }
        }
      }
      // either we don't want indenting, or there are no eols in new text
      {
        bool undoOk = false;
        // record undo
        if (undo !is null) undoOk = undo.addTextInsert(this, pos, cast(int)str.length);
        willBeInserted(pos, cast(int)str.length, nlc);
        // insert text
        auto newpos = lc.put(pos, str[]);
        if (newpos < 0) {
          // operation failed, rollback it
          if (undoOk) undo.popUndo(); // remove undo record
          return false;
        }
             static if (movecursor == "start") lc.pos2xy(pos, cx, cy);
        else static if (movecursor == "end") lc.pos2xy(newpos, cx, cy);
        txchanged = true;
        lineChangedByPos(pos, (nlc > 0));
        wasInserted(pos, newpos-pos, nlc);
      }
    }
    return true;
  }

  /// replace text at pos, save undo, mark updated lines
  /// return `false` if operation cannot be performed
  final bool replaceText(string movecursor="none", bool doIndent=false) (int pos, int count, const(char)[] str) {
    static assert(movecursor == "none" || movecursor == "start" || movecursor == "end");
    if (mReadOnly) return false;
    if (count < 0 || pos < 0) return false;
    if (mKillTextOnChar) {
      killTextOnChar = false;
      if (gb.textsize > 0) {
        undoGroupStart();
        bstart = bend = -1;
        markingBlock = false;
        deleteText!"start"(0, gb.textsize);
        undoGroupEnd();
      }
    }
    auto ts = gb.textsize;
    if (pos >= ts) pos = ts;
    if (count > ts-pos) count = ts-pos;
    bool needToRestoreBlock = (markingBlock || hasMarkedBlock);
    auto bs = bstart;
    auto be = bend;
    auto mb = markingBlock;
    undoGroupStart();
    scope(exit) undoGroupEnd();
    auto ocp = curpos;
    deleteText!movecursor(pos, count);
    static if (movecursor == "none") { bool cmoved = false; if (ocp > pos) { cmoved = true; ocp -= count; } }
    if (insertText!(movecursor, doIndent)(pos, str)) {
      static if (movecursor == "none") { if (cmoved) ocp += count; }
      if (needToRestoreBlock && !hasMarkedBlock) {
        // restore block if it was deleted
        bstart = bs;
        bend = be-count+cast(int)str.length;
        markingBlock = mb;
        if (bend < bstart) markingBlock = false;
        lastBGEnd = true;
      } else if (hasMarkedBlock && bs == pos && bstart > pos) {
        // consider the case when replaced text is inside the block,
        // and block is starting on the text
        bstart = pos;
        lastBGEnd = false; //???
        markBlockDirty();
      }
      return true;
    }
    return false;
  }

  ///
  bool doBlockWrite (const(char)[] fname) { return doBlockWrite(VFile(fname, "w")); }

  ///
  bool doBlockWrite (VFile fl) {
    import core.stdc.stdlib : malloc, free;
    killTextOnChar = false;
    if (!hasMarkedBlock) return true;
    gb.forEachBufPart(bstart, bend-bstart, delegate (const(char)[] buf) { fl.rawWriteExact(buf); });
    return true;
  }

  ///
  bool doBlockRead (const(char)[] fname) { return doBlockRead(VFile(fname)); }

  ///
  bool doBlockRead (VFile fl) {
    //FIXME: optimize this!
    import core.stdc.stdlib : realloc, free;
    import core.stdc.string : memcpy;
    // read block data into temp buffer
    if (mReadOnly) return false;
    killTextOnChar = false;
    char* btext;
    scope(exit) if (btext !is null) free(btext);
    int blen = 0;
    char[1024] tb = void;
    for (;;) {
      auto rd = fl.rawRead(tb[]);
      if (rd.length == 0) break;
      if (blen+rd.length > int.max/2) return false;
      auto nb = cast(char*)realloc(btext, blen+rd.length);
      if (nb is null) return false;
      btext = nb;
      memcpy(btext+blen, rd.ptr, rd.length);
      blen += cast(int)rd.length;
    }
    return insertText!("start", false)(curpos, btext[0..blen]); // no indent
  }

  ///
  bool doBlockDelete () {
    if (mReadOnly) return false;
    if (!hasMarkedBlock) return true;
    return deleteText!"start"(bstart, bend-bstart, (pos, count) { doBlockResetMark(false); });
  }

  ///
  bool doBlockCopy () {
    //FIXME: optimize this!
    import core.stdc.stdlib : malloc, free;
    if (mReadOnly) return false;
    killTextOnChar = false;
    if (!hasMarkedBlock) return true;
    // copy block data into temp buffer
    int blen = bend-bstart;
    GapBuffer.HighState* hsbuf;
    scope(exit) if (hsbuf !is null) free(hsbuf);
    if (asRich) {
      // rich text: get atts
      hsbuf = cast(GapBuffer.HighState*)malloc(blen*hsbuf[0].sizeof);
      if (hsbuf is null) return false;
      foreach (int pp; bstart..bend) hsbuf[pp-bstart] = gb.hi(pp);
    }
    // normal text
    char* btext = cast(char*)malloc(blen);
    if (btext is null) return false; // alas
    scope(exit) free(btext);
    foreach (int pp; bstart..bend) btext[pp-bstart] = gb[pp];
    auto stp = curpos;
    return insertText!("start", false)(stp, btext[0..blen]); // no indent
    // attrs
    if (asRich) {
      foreach (immutable int idx; 0..blen) gb.hi(stp+idx) = hsbuf[idx];
    }
  }

  ///
  bool doBlockMove () {
    //FIXME: optimize this!
    import core.stdc.stdlib : malloc, free;
    if (mReadOnly) return false;
    killTextOnChar = false;
    if (!hasMarkedBlock) return true;
    int pos = curpos;
    if (pos >= bstart && pos < bend) return false; // can't do this while we are inside the block
    // copy block data into temp buffer
    int blen = bend-bstart;
    GapBuffer.HighState* hsbuf;
    scope(exit) if (hsbuf !is null) free(hsbuf);
    if (asRich) {
      // rich text: get atts
      hsbuf = cast(GapBuffer.HighState*)malloc(blen*hsbuf[0].sizeof);
      if (hsbuf is null) return false;
      foreach (int pp; bstart..bend) hsbuf[pp-bstart] = gb.hi(pp);
    }
    char* btext = cast(char*)malloc(blen);
    if (btext is null) return false; // alas
    scope(exit) free(btext);
    foreach (int pp; bstart..bend) btext[pp-bstart] = gb[pp];
    // group undo action
    bool undoOk = undoGroupStart();
    if (pos >= bstart) pos -= blen;
    if (!doBlockDelete()) {
      // rollback
      if (undoOk) undo.popUndo();
      return false;
    }
    auto stp = pos;
    if (!insertText!("start", false)(pos, btext[0..blen])) {
      // rollback
      if (undoOk) undo.popUndo();
      return false;
    }
    // attrs
    if (asRich) {
      foreach (immutable int idx; 0..blen) gb.hi(stp+idx) = hsbuf[idx];
    }
    // mark moved block
    bstart = pos;
    bend = pos+blen;
    markBlockDirty();
    undoGroupEnd();
    return true;
  }

  ///
  void doDelete () {
    if (mReadOnly) return;
    int pos = curpos;
    if (pos >= gb.textsize) return;
    if (!lc.utfuck) {
      deleteText!"start"(pos, 1);
    } else {
      deleteText!"start"(pos, gb.utfuckLenAt(pos));
    }
  }

  ///
  void doBackspace () {
    if (mReadOnly) return;
    killTextOnChar = false;
    int pos = curpos;
    if (pos == 0) return;
    immutable int ppos = prevpos(pos);
    deleteText!"start"(ppos, pos-ppos);
  }

  ///
  void doBackByIndent () {
    if (mReadOnly) return;
    int pos = curpos;
    int ls = lc.xy2pos(0, cy);
    if (pos == ls) { doDeleteWord(); return; }
    if (gb[pos-1] > ' ') { doDeleteWord(); return; }
    int rx, ry;
    lc.pos2xy(pos, rx, ry);
    int del = 2-rx%2;
    if (del > 1 && (pos-2 < ls || gb[pos-2] > ' ')) del = 1;
    pos -= del;
    deleteText!"start"(pos, del);
  }

  ///
  void doDeleteWord () {
    if (mReadOnly) return;
    int pos = curpos;
    if (pos == 0) return;
    auto ch = gb[pos-1];
    if (!mSingleLine && ch == '\n') { doBackspace(); return; }
    int stpos = pos-1;
    // find word start
    if (ch <= ' ') {
      while (stpos > 0) {
        ch = gb[stpos-1];
        if ((!mSingleLine && ch == '\n') || ch > ' ') break;
        --stpos;
      }
    } else if (isWordChar(ch)) {
      while (stpos > 0) {
        ch = gb[stpos-1];
        if (!isWordChar(ch)) break;
        --stpos;
      }
    }
    if (pos == stpos) return;
    deleteText!"start"(stpos, pos-stpos);
  }

  ///
  void doKillLine () {
    if (mReadOnly) return;
    int ls = lc.xy2pos(0, cy);
    int le;
    if (cy == lc.linecount-1) {
      le = gb.textsize;
    } else {
      le = lc.xy2pos(0, cy+1);
    }
    if (ls < le) deleteText!"start"(ls, le-ls);
  }

  ///
  void doKillToEOL () {
    if (mReadOnly) return;
    int pos = curpos;
    auto ts = gb.textsize;
    if (mSingleLine) {
      if (pos < ts) deleteText!"start"(pos, ts-pos);
    } else {
      if (pos < ts && gb[pos] != '\n') {
        int epos = pos+1;
        while (epos < ts && gb[epos] != '\n') ++epos;
        deleteText!"start"(pos, epos-pos);
      }
    }
  }

  /// split line at current position
  bool doLineSplit (bool autoindent=true) {
    if (mReadOnly || mSingleLine) return false;
    if (autoindent) {
      return insertText!("end", true)(curpos, "\n");
    } else {
      return insertText!("end", false)(curpos, "\n");
    }
  }

  /// put char in koi8
  void doPutChar (char ch) {
    if (mReadOnly) return;
    if (!mSingleLine && ch == '\n') { doLineSplit(inPasteMode <= 0); return; }
    if (ch > 127 && lc.utfuck) {
      char[8] ubuf = void;
      int len = utf8Encode(ubuf[], koi2uni(ch));
      if (len < 1) { ubuf[0] = '?'; len = 1; }
      insertText!("end", true)(curpos, ubuf[0..len]);
      return;
    }
    if (ch >= 128 && codepage != CodePage.koi8u) ch = recodeCharTo(ch);
    if (inPasteMode <= 0) {
      insertText!("end", true)(curpos, (&ch)[0..1]);
    } else {
      insertText!("end", false)(curpos, (&ch)[0..1]);
    }
  }

  ///
  void doPutDChar (dchar dch) {
    if (mReadOnly) return;
    if (!Utf8DecoderFast.isValidDC(dch)) dch = Utf8DecoderFast.replacement;
    if (dch < 128) { doPutChar(cast(char)dch); return; }
    char[4] ubuf = void;
    auto len = utf8Encode(ubuf[], dch);
    if (len < 1) return;
    if (lc.utfuck) {
      insertText!"end"(curpos, ubuf.ptr[0..len]);
    } else {
      // recode to codepage
      doPutChar(recodeU2B(dch));
    }
  }

  ///
  void doPutTextUtf (const(char)[] str) {
    if (mReadOnly) return;
    if (str.length == 0) return;

    bool ugstarted = false;
    void startug () { if (!ugstarted) { ugstarted = true; undoGroupStart(); } }
    scope(exit) if (ugstarted) undoGroupEnd();

    Utf8DecoderFast udc;
    foreach (immutable char ch; str) {
      if (udc.decode(cast(ubyte)ch)) {
        dchar dch = (udc.complete ? udc.codepoint : udc.replacement);
        if (!udc.isValidDC(dch)) dch = udc.replacement;
        if (!mSingleLine && dch == '\n') { startug(); doLineSplit(inPasteMode <= 0); continue; }
        startug();
        doPutChar(recodeU2B(dch));
      }
    }
  }

  /// put text in koi8
  void doPutText (const(char)[] str) {
    if (mReadOnly) return;
    if (str.length == 0) return;

    bool ugstarted = false;
    void startug () { if (!ugstarted) { ugstarted = true; undoGroupStart(); } }
    scope(exit) if (ugstarted) undoGroupEnd();

    size_t pos = 0;
    char ch;
    while (pos < str.length) {
      auto stpos = pos;
      while (pos < str.length) {
        ch = str.ptr[pos];
        if (!mSingleLine && ch == '\n') break;
        if (ch >= 128) break;
        ++pos;
      }
      if (stpos < pos) { startug(); insertText!"end"(curpos, str.ptr[stpos..pos]); }
      if (pos >= str.length) break;
      ch = str.ptr[pos];
      if (!mSingleLine && ch == '\n') { startug(); doLineSplit(inPasteMode <= 0); ++pos; continue; }
      if (ch < ' ') { startug(); insertText!"end"(curpos, str.ptr[pos..pos+1]); ++pos; continue; }
      Utf8DecoderFast udc;
      stpos = pos;
      while (pos < str.length) if (udc.decode(cast(ubyte)(str.ptr[pos++]))) break;
      startug();
      if (udc.complete) {
        insertText!"end"(curpos, str.ptr[stpos..pos]);
      } else {
        ch = uni2koi(Utf8DecoderFast.replacement);
        insertText!"end"(curpos, (&ch)[0..1]);
      }
    }
  }

  ///
  void doPasteStart () {
    if (mKillTextOnChar) {
      killTextOnChar = false;
      if (gb.textsize > 0) {
        undoGroupStart();
        bstart = bend = -1;
        markingBlock = false;
        deleteText!"start"(0, gb.textsize);
        undoGroupEnd();
      }
    }
    undoGroupStart();
    ++inPasteMode;
  }

  ///
  void doPasteEnd () {
    killTextOnChar = false;
    if (--inPasteMode < 0) inPasteMode = 0;
    undoGroupEnd();
  }

  protected final bool xIndentLine (int lidx) {
    //TODO: rollback
    if (mReadOnly) return false;
    if (lidx < 0 || lidx >= lc.linecount) return false;
    auto pos = lc.xy2pos(0, lidx);
    auto epos = lc.xy2pos(0, lidx+1);
    auto stpos = pos;
    // if line consists of blanks only, don't do anything
    while (pos < epos) {
      auto ch = gb[pos];
      if (ch == '\n') return true;
      if (ch > ' ') break;
      ++pos;
    }
    if (pos >= gb.textsize) return true;
    pos = stpos;
    char[2] spc = ' ';
    return insertText!("none", false)(pos, spc[]);
  }

  void doIndentBlock () {
    if (mReadOnly) return;
    killTextOnChar = false;
    if (!hasMarkedBlock) return;
    int sy = lc.pos2line(bstart);
    int ey = lc.pos2line(bend-1);
    bool bsAtBOL = (bstart == lc.line2pos(sy));
    undoGroupStart();
    scope(exit) undoGroupEnd();
    foreach (int lidx; sy..ey+1) xIndentLine(lidx);
    if (bsAtBOL) bstart = lc.line2pos(sy); // line already marked as dirty
  }

  protected final bool xUnindentLine (int lidx) {
    if (mReadOnly) return false;
    if (lidx < 0 || lidx >= lc.linecount) return true;
    auto pos = lc.xy2pos(0, lidx);
    auto len = 1;
    if (gb[pos] > ' ' || gb[pos] == '\n') return true;
    if (pos+1 < gb.textsize && gb[pos+1] <= ' ' && gb[pos+1] != '\n') ++len;
    return deleteText!"none"(pos, len);
  }

  ///
  void doUnindentBlock () {
    if (mReadOnly) return;
    killTextOnChar = false;
    if (!hasMarkedBlock) return;
    int sy = lc.pos2line(bstart);
    int ey = lc.pos2line(bend-1);
    undoGroupStart();
    scope(exit) undoGroupEnd();
    foreach (int lidx; sy..ey+1) xUnindentLine(lidx);
  }

  // ////////////////////////////////////////////////////////////////////// //
  // actions

  /// push cursor position to undo stach
  final bool pushUndoCurPos () nothrow {
    return (undo !is null ? undo.addCurMove(this) : false);
  }

  // returns old state
  enum SetupShiftMarkingMixin = q{
    auto omb = markingBlock;
    scope(exit) markingBlock = omb;
    if (domark) {
      if (!hasMarkedBlock) {
        int pos = curpos;
        bstart = bend = pos;
        lastBGEnd = true;
      }
      markingBlock = true;
    }
  };

  ///
  void doWordLeft (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    killTextOnChar = false;
    int pos = curpos;
    if (pos == 0) return;
    auto ch = gb[pos-1];
    if (!mSingleLine && ch == '\n') { doLeft(); return; }
    int stpos = pos-1;
    // find word start
    if (ch <= ' ') {
      while (stpos > 0) {
        ch = gb[stpos-1];
        if ((!mSingleLine && ch == '\n') || ch > ' ') break;
        --stpos;
      }
    }
    if (stpos > 0 && isWordChar(ch)) {
      while (stpos > 0) {
        ch = gb[stpos-1];
        if (!isWordChar(ch)) break;
        --stpos;
      }
    }
    pushUndoCurPos();
    lc.pos2xy(stpos, cx, cy);
    growBlockMark();
  }

  ///
  void doWordRight (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    killTextOnChar = false;
    int pos = curpos;
    if (pos == gb.textsize) return;
    auto ch = gb[pos];
    if (!mSingleLine && ch == '\n') { doRight(); return; }
    int epos = pos+1;
    // find word start
    if (ch <= ' ') {
      while (epos < gb.textsize) {
        ch = gb[epos];
        if ((!mSingleLine && ch == '\n') || ch > ' ') break;
        ++epos;
      }
    } else if (isWordChar(ch)) {
      while (epos < gb.textsize) {
        ch = gb[epos];
        if (!isWordChar(ch)) {
          if (ch <= ' ') {
            while (epos < gb.textsize) {
              ch = gb[epos];
              if ((!mSingleLine && ch == '\n') || ch > ' ') break;
              ++epos;
            }
          }
          break;
        }
        ++epos;
      }
    }
    pushUndoCurPos();
    lc.pos2xy(epos, cx, cy);
    growBlockMark();
  }

  ///
  void doTextTop (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (lc.mLineCount < 2) return;
    killTextOnChar = false;
    if (mTopLine == 0 && cy == 0) return;
    pushUndoCurPos();
    mTopLine = cy = 0;
    growBlockMark();
  }

  ///
  void doTextBottom (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (lc.mLineCount < 2) return;
    killTextOnChar = false;
    if (cy >= lc.linecount-1) return;
    pushUndoCurPos();
    cy = lc.linecount-1;
    growBlockMark();
  }

  ///
  void doPageTop (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (lc.mLineCount < 2) return;
    killTextOnChar = false;
    if (cy == mTopLine) return;
    pushUndoCurPos();
    cy = mTopLine;
    growBlockMark();
  }

  ///
  void doPageBottom (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (lc.mLineCount < 2) return;
    killTextOnChar = false;
    int ny = mTopLine+linesPerWindow-1;
    if (ny >= lc.linecount) ny = lc.linecount-1;
    if (cy != ny) {
      pushUndoCurPos();
      cy = ny;
    }
    growBlockMark();
  }

  ///
  void doScrollUp (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (mTopLine > 0) {
      killTextOnChar = false;
      pushUndoCurPos();
      --mTopLine;
      --cy;
    } else if (cy > 0) {
      killTextOnChar = false;
      pushUndoCurPos();
      --cy;
    }
    growBlockMark();
  }

  ///
  void doScrollDown (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (mTopLine+linesPerWindow < lc.linecount) {
      killTextOnChar = false;
      pushUndoCurPos();
      ++mTopLine;
      ++cy;
    } else if (cy < lc.linecount-1) {
      killTextOnChar = false;
      pushUndoCurPos();
      ++cy;
    }
    growBlockMark();
  }

  ///
  void doUp (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (cy > 0) {
      killTextOnChar = false;
      pushUndoCurPos();
      --cy;
    }
    growBlockMark();
  }

  ///
  void doDown (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (cy < lc.linecount-1) {
      killTextOnChar = false;
      pushUndoCurPos();
      ++cy;
    }
    growBlockMark();
  }

  ///
  void doLeft (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    int rx, ry;
    killTextOnChar = false;
    lc.pos2xy(curpos, rx, ry);
    if (cx > rx) cx = rx;
    if (cx > 0) {
      pushUndoCurPos();
      --cx;
    } else if (cy > 0) {
      // to prev line
      pushUndoCurPos();
      lc.pos2xy(lc.xy2pos(0, cy)-1, cx, cy);
    }
    growBlockMark();
  }

  ///
  void doRight (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    int rx, ry;
    killTextOnChar = false;
    lc.pos2xy(lc.xy2pos(cx+1, cy), rx, ry);
    if (cx+1 > rx) {
      if (cy < lc.linecount-1) {
        pushUndoCurPos();
        cx = 0;
        ++cy;
      }
    } else {
      pushUndoCurPos();
      ++cx;
    }
    growBlockMark();
  }

  ///
  void doPageUp (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (linesPerWindow < 2 || lc.mLineCount < 2) return;
    killTextOnChar = false;
    int ntl = mTopLine-(linesPerWindow-1);
    int ncy = cy-(linesPerWindow-1);
    if (ntl < 0) ntl = 0;
    if (ncy < 0) ncy = 0;
    if (ntl != mTopLine || ncy != cy) {
      pushUndoCurPos();
      mTopLine = ntl;
      cy = ncy;
    }
    growBlockMark();
  }

  ///
  void doPageDown (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (linesPerWindow < 2 || lc.mLineCount < 2) return;
    killTextOnChar = false;
    int ntl = mTopLine+(linesPerWindow-1);
    int ncy = cy+(linesPerWindow-1);
    if (ntl+linesPerWindow >= lc.linecount) ntl = lc.linecount-linesPerWindow;
    if (ncy >= lc.linecount) ncy = lc.linecount-1;
    if (ntl < 0) ntl = 0;
    if (ntl != mTopLine || ncy != cy) {
      pushUndoCurPos();
      mTopLine = ntl;
      cy = ncy;
    }
    growBlockMark();
  }

  ///
  void doHome (bool smart=true, bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    killTextOnChar = false;
    if (cx != 0) {
      pushUndoCurPos();
      cx = 0;
    } else {
      if (!smart) return;
      int nx = 0;
      auto pos = lc.xy2pos(0, cy);
      while (pos < gb.textsize) {
        auto ch = gb[pos];
        if (!mSingleLine && ch == '\n') return;
        if (ch > ' ') break;
        ++pos;
        ++nx;
      }
      if (nx != cx) {
        pushUndoCurPos();
        cx = nx;
      }
    }
    growBlockMark();
  }

  ///
  void doEnd (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    int rx, ry;
    killTextOnChar = false;
    auto ep = (cy >= lc.linecount-1 ? gb.textsize : lc.lineend(cy));
    lc.pos2xy(ep, rx, ry);
    if (rx != cx || ry != cy) {
      pushUndoCurPos();
      cx = rx;
      cy = ry;
    }
    growBlockMark();
  }

  //
  /*private*/protected void doUndoRedo (UndoStack us) { // "allMembers" trait: shut the fuck up!
    if (us is null) return;
    killTextOnChar = false;
    int level = 0;
    while (us.hasUndo) {
      auto tp = us.undoAction(this);
      switch (tp) {
        case UndoStack.Type.GroupStart:
          if (--level <= 0) return;
          break;
        case UndoStack.Type.GroupEnd:
          ++level;
          break;
        default:
          if (level <= 0) return;
          break;
      }
    }
  }

  void doUndo () { doUndoRedo(undo); } ///
  void doRedo () { doUndoRedo(redo); } ///

  ///
  void doBlockResetMark (bool saveUndo=true) nothrow {
    killTextOnChar = false;
    if (bstart < bend) {
      if (saveUndo) pushUndoCurPos();
      markLinesDirtySE(lc.pos2line(bstart), lc.pos2line(bend-1));
    }
    bstart = bend = -1;
    markingBlock = false;
  }

  /// toggle block marking mode
  void doToggleBlockMarkMode () {
    killTextOnChar = false;
    if (bstart == bend && markingBlock) { doBlockResetMark(false); return; }
    if (bstart < bend && !markingBlock) doBlockResetMark(false);
    int pos = curpos;
    if (!hasMarkedBlock) {
      bstart = bend = pos;
      markingBlock = true;
      lastBGEnd = true;
    } else {
      if (pos != bstart) {
        bend = pos;
        if (bend < bstart) { pos = bstart; bstart = bend; bend = pos; }
      }
      markingBlock = false;
      dirtyLines[] = -1; //FIXME: optimize
    }
  }

  ///
  void doSetBlockStart () {
    killTextOnChar = false;
    auto pos = curpos;
    if ((hasMarkedBlock || (bstart == bend && bstart >= 0 && bstart < gb.textsize)) && pos < bend) {
      //if (pos < bstart) markRangeDirty(pos, bstart-pos); else markRangeDirty(bstart, pos-bstart);
      bstart = pos;
      lastBGEnd = false;
    } else {
      doBlockResetMark();
      bstart = bend = pos;
      lastBGEnd = false;
    }
    markingBlock = false;
    dirtyLines[] = -1; //FIXME: optimize
  }

  ///
  void doSetBlockEnd () {
    auto pos = curpos;
    if ((hasMarkedBlock || (bstart == bend && bstart >= 0 && bstart < gb.textsize)) && pos > bstart) {
      //if (pos < bend) markRangeDirty(pos, bend-pos); else markRangeDirty(bend, pos-bend);
      bend = pos;
      lastBGEnd = true;
    } else {
      doBlockResetMark();
      bstart = bend = pos;
      lastBGEnd = true;
    }
    markingBlock = false;
    dirtyLines[] = -1; //FIXME: optimize
  }

protected:
  // called by undo/redo processors
  final void ubTextRemove (int pos, int len) {
    if (mReadOnly) return;
    killTextOnChar = false;
    int nlc = (!mSingleLine ? gb.countEolsInRange(pos, len) : 0);
    bookmarkDeletionFix(pos, len, nlc);
    lineChangedByPos(pos, (nlc > 0));
    lc.remove(pos, len);
  }

  // called by undo/redo processors
  final bool ubTextInsert (int pos, const(char)[] str) {
    if (mReadOnly) return true;
    killTextOnChar = false;
    if (str.length == 0) return true;
    int nlc = (!mSingleLine ? gb.countEols(str) : 0);
    bookmarkInsertionFix(pos, pos+cast(int)str.length, nlc);
    if (lc.put(pos, str) >= 0) {
      lineChangedByPos(pos, (nlc > 0));
      return true;
    } else {
      return false;
    }
  }

  // can be called only after `ubTextInsert`, and with the same pos/length
  // usually it is done by undo/redo action if the editor is in "rich mode"
  final void ubTextSetAttrs (int pos, const(GapBuffer.HighState)[] hs) {
    if (mReadOnly || hs.length == 0) return;
    foreach (const ref hi; hs) {
      uint rtp = gb.pos2real(pos++);
      gb.hbuf[rtp] = hi;
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  public static struct TextRange {
  private:
    EditorEngine ed;
    int pos;
    int left; // chars left, including front
    char frontch = 0;
  nothrow:
  private:
    this (EditorEngine aed, int apos, int aleft, char afrontch) pure {
      ed = aed;
      pos = apos;
      left = aleft;
      frontch = afrontch;
    }

    this (EditorEngine aed, usize lo, usize hi) {
      ed = aed;
      if (aed !is null && lo < hi && lo < aed.gb.textsize) {
        pos = cast(int)lo;
        if (hi > ed.gb.textsize) hi = ed.gb.textsize;
        left = cast(int)hi-pos+1; // compensate for first popFront
        popFront();
      }
    }
  public:
    @property bool empty () const pure @safe @nogc { pragma(inline, true); return (left <= 0); }
    @property char front () const pure @safe @nogc { pragma(inline, true); return frontch; }
    void popFront () {
      if (ed is null || left < 2) { left = 0; frontch = 0; return; }
      --left;
      if (pos >= ed.gb.textsize) { left = 0; frontch = 0; return; }
      frontch = ed.gb[pos++];
    }
    auto save () pure { pragma(inline, true); return TextRange(ed, pos, left, frontch); }
    @property usize length () const pure @safe @nogc { pragma(inline, true); return (left > 0 ? left : 0); }
    alias opDollar = length;
    char opIndex (usize idx) {
      pragma(inline, true);
      return (left > 0 && idx < left ? (idx == 0 ? frontch : ed.gb[pos+cast(int)idx-1]) : 0);
    }
    auto opSlice () pure { pragma(inline, true); return this.save; }
    //WARNING: logic untested!
    auto opSlice (uint lo, uint hi) {
      if (ed is null || left <= 0 || lo >= left || lo >= hi) return TextRange(null, 0, 0);
      hi -= lo; // convert to length
      if (hi > left) hi = left;
      if (left-lo > hi) hi = left-lo;
      return TextRange(ed, cast(int)lo+1, cast(int)hi, ed.gb[cast(int)lo]);
    }
    // make it bidirectional, just for fun
    //WARNING: completely untested!
    char back () const pure {
      pragma(inline, true);
      return (ed !is null && left > 0 ? (left == 1 ? frontch : ed.gb[pos+left-2]) : 0);
    }
    void popBack () {
      if (ed is null || left < 2) { left = 0; frontch = 0; return; }
      --left;
    }
  }

public:
  /// range interface to editor text
  /// WARNING! do not change anything while range is active, or results *WILL* be UD
  final TextRange opSlice (usize lo, usize hi) nothrow { return TextRange(this, lo, hi); }
  final TextRange opSlice () nothrow { return TextRange(this, 0, gb.textsize); } /// ditto
  final int opDollar () nothrow { return gb.textsize; } ///

  ///
  final TextRange markedBlockRange () nothrow {
    if (!hasMarkedBlock) return TextRange.init;
    return TextRange(this, bstart, bend);
  }

static:
  ///
  bool isWordChar (char ch) pure nothrow {
    return (ch.isalnum || ch == '_' || ch > 127);
  }
}
