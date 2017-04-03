/* Invisible Vector Library
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

import iv.rawtty : koi2uni, uni2koi;
import iv.strex;
import iv.utfutil;
import iv.vfs;
debug import iv.vfs.io;

static if (!is(typeof(object.usize))) private alias usize = size_t;


// ////////////////////////////////////////////////////////////////////////// //
/// this interface is used to measure text for pixel-sized editor
abstract class EgTextMeter {
  int currofs; /// current x offset; keep this in sync with the current state
  int currheight; /// current text height; keep this in sync with the current state; `reset` should set it to "default text height"

  /// this should reset text width iterator (and curr* fields); tabsize > 0: process tabs as... well... tabs ;-)
  abstract void reset (int tabsize) nothrow;

  /// advance text width iterator, return x position for drawing next char
  abstract int advance (dchar ch) nothrow;

  /// return current string width, including last char passed to `advance()`, preferably without spacing after last char
  abstract int currWidth () nothrow;

  /// finish text iterator; it should NOT reset curr* fields!
  /// WARNING: EditorEngine tries to call this after each `reset()`, but user code may not
  abstract void finish () nothrow;
}


// ////////////////////////////////////////////////////////////////////////// //
///
public final class GapBuffer {
public:
  static align(1) struct HighState {
  align(1):
    ubyte kwtype; // keyword number
    ubyte kwidx; // index in keyword
  }

public:
  // utfuck-8 support
  // WARNING! this will SIGNIFICANTLY slow down coordinate calculations!
  bool utfuck = false; /// should x coordinate calculation assume that the text is in UTF-8?
  bool visualtabs = false; /// should x coordinate calculation assume that tabs are not one-char width?
  ubyte tabsize = 2; /// tab size

private:
  HighState hidummy;
  bool mSingleLine;

protected:
  enum MinGapSize = 1024; // bytes in gap
  enum GrowGran = 0x1000; // must be power of 2
  static assert(GrowGran > MinGapSize);

// fuck you, D! there is still no way to cancel @nogc!
protected:
  // this will update buffer if necessary
  void updateLineHeightAndY (int lidx, EgTextMeter textMeter, scope dchar delegate (char ch) nothrow recode1byte) nothrow {
    //{ import core.stdc.stdio; printf("0: updateLineHeightAndY: lidx=%d\n", lidx); }
    if (lidx > 0 && (lineofsc[lidx-1].height == 0 || lineofsc[lidx-1].yofs == 0)) updateLineHeightAndY(lidx-1, textMeter, recode1byte);
    //scope(exit) { import core.stdc.stdio; printf("1: updateLineHeightAndY: lidx=%d; yofs=%d; height=%d\n", lidx, lineofsc[lidx].yofs, lineofsc[lidx].height); }
    int ls = lineofsc[lidx].ofs;
    int le = lineofsc[lidx+1].ofs;
    textMeter.reset(0); // nobody cares about tab widths here
    scope(exit) textMeter.finish();
    if (utfuck) {
      Utf8DecoderFast udc;
      while (ls < le) {
        char ch = tbuf[pos2real(ls++)];
        if (udc.decode(cast(ubyte)ch)) textMeter.advance(udc.invalid || !udc.isValidDC(udc.codepoint)? udc.replacement : udc.codepoint);
      }
    } else if (recode1byte !is null) {
      while (ls < le) textMeter.advance(recode1byte(tbuf[pos2real(ls++)]));
    } else {
      while (ls < le) textMeter.advance(tbuf[pos2real(ls++)]);
    }
    lineofsc[lidx].yofs = (lidx < 1 ? 0 : lineofsc[lidx-1].yofs+lineofsc[lidx-1].height);
    lineofsc[lidx].height = (textMeter.currheight > 0 ? textMeter.currheight : 1);
  }

  // this will update buffer if necessary
  void updateLineHeight (int lidx, EgTextMeter textMeter, scope dchar delegate (char ch) nothrow recode1byte) nothrow {
    //{ import core.stdc.stdio; printf("0: updateLineHeight: lidx=%d\n", lidx); }
    //scope(exit) { import core.stdc.stdio; printf("1: updateLineHeight: lidx=%d; yofs=%d; height=%d\n", lidx, lineofsc[lidx].yofs, lineofsc[lidx].height); }
    int ls = lineofsc[lidx].ofs;
    int le = lineofsc[lidx+1].ofs;
    textMeter.reset(0); // nobody cares about tab widths here
    scope(exit) textMeter.finish();
    if (utfuck) {
      Utf8DecoderFast udc;
      while (ls < le) {
        char ch = tbuf[pos2real(ls++)];
        if (udc.decode(cast(ubyte)ch)) textMeter.advance(udc.invalid || !udc.isValidDC(udc.codepoint)? udc.replacement : udc.codepoint);
      }
    } else if (recode1byte !is null) {
      while (ls < le) textMeter.advance(recode1byte(tbuf[pos2real(ls++)]));
    } else {
      while (ls < le) textMeter.advance(tbuf[pos2real(ls++)]);
    }
    int h = (textMeter.currheight > 0 ? textMeter.currheight : 1);
    if (lineofsc[lidx].height != h) {
      int lly = lidx;
      while (lly < locused) lineofsc[lly++].yofs = 0;
    }
    lineofsc[lidx].height = (textMeter.currheight > 0 ? textMeter.currheight : 1);
  }

  int pixely2lidx (int y, EgTextMeter textMeter, scope dchar delegate (char ch) nothrow recode1byte) nothrow {
    assert(textMeter !is null);
    int lidx = findLineCacheYIndex(y);
    if (lidx >= 0) return lidx;
    // line cache is unusable, update it
    updateCache(0);
    while (locused < mLineCount) {
      lidx = locused;
      updateCache(locused);
      assert(lidx+1 == locused);
      updateLineHeightAndY(lidx, textMeter, recode1byte);
      if (y <= lineofsc[lidx].yofs) {
        lidx = findLineCacheYIndex(y);
        if (lidx < 0) assert(0, "internal line cache error");
        return lidx;
      }
    }
    return mLineCount;
  }

  static struct LineHMetrics {
    int y;
    int height;
  }

  LineHMetrics lidx2pixelyh (int lidx, EgTextMeter textMeter, scope dchar delegate (char ch) nothrow recode1byte) nothrow {
    LineHMetrics res;
    assert(textMeter !is null);
    if (lidx < 0 || mLineCount == 0) {
      textMeter.reset(0);
      res.height = (textMeter.currheight > 0 ? textMeter.currheight : 1);
      textMeter.finish();
    } else {
      int ll = (lidx >= mLineCount ? mLineCount-1 : lidx);
      while (locused <= ll) {
        int lx = locused;
        if (lineofsc[lx].height == 0) updateLineHeightAndY(lx, textMeter, recode1byte);
        updateCache(locused);
        assert(lx+1 == locused);
        updateLineHeightAndY(lx, textMeter, recode1byte);
      }
      if (lidx >= mLineCount) {
        res.y = lineofsc[mLineCount].yofs+lineofsc[mLineCount].height;
        textMeter.reset(0);
        res.height = (textMeter.currheight > 0 ? textMeter.currheight : 1);
        textMeter.finish();
      } else {
        res.y = lineofsc[lidx].yofs;
        res.height = lineofsc[lidx].height;
      }
    }
    return res;
  }

  int lidx2pixelh (int lidx, EgTextMeter textMeter, scope dchar delegate (char ch) nothrow recode1byte) nothrow {
    int h;
    assert(textMeter !is null);
    if (lidx < 0 || mLineCount == 0 || lidx >= mLineCount) {
      textMeter.reset(0);
      h = (textMeter.currheight > 0 ? textMeter.currheight : 1);
      textMeter.finish();
    } else {
      while (locused <= lidx) updateCache(locused);
      if (lineofsc[lidx].height == 0) updateLineHeight(lidx, textMeter, recode1byte);
      h = lineofsc[lidx].height;
    }
    return h;
  }

nothrow @trusted @nogc:
public:
  ///
  static bool hasEols (const(char)[] str) {
    import core.stdc.string : memchr;
    uint left = cast(uint)str.length;
    return (left > 0 && memchr(str.ptr, '\n', left) !is null);
  }

  ///
  static int findEol (const(char)[] str) {
    int left = cast(int)str.length;
    if (left > 0) {
      import core.stdc.string : memchr;
      auto dp = memchr(str.ptr, '\n', left);
      if (dp !is null) return cast(int)(dp-str.ptr);
    }
    return -1;
  }

  ///
  static int countEols (const(char)[] str) {
    import core.stdc.string : memchr;
    int linecount = 0;
    uint left = cast(uint)str.length;
    auto dsp = str.ptr;
    while (left > 0) {
      auto ep = cast(const(char)*)memchr(dsp, '\n', left);
      if (ep is null) break;
      ++linecount;
      ++ep;
      left -= cast(uint)(ep-dsp);
      dsp = ep;
    }
    return linecount;
  }

protected:
  char* tbuf; /// text buffer
  HighState* hbuf; /// highlight buffer
  uint tbused; /// not including gap
  uint tbsize; /// including gap
  uint tbmax = 512*1024*1024+MinGapSize; /// maximum buffer size
  uint gapstart, gapend; /// tbuf[gapstart..gapend]; gap cannot be empty
  uint bufferChangeCounter; /// will simply increase on each buffer change

  // line offset/height cache item
  static align(1) struct LOCItem {
  align(1):
    uint ofs;
    uint height; // 0: invalid; line height
    uint yofs; // line y offset from text top
  }

  // line offset cache
  LOCItem* lineofsc;
  uint locused; // number of valid entries in lineofsc-1 (i.e. lineofsc[locused] is always valid)
  uint locsize;
  uint mLineCount; // number of lines in *text* buffer

final:
  // size doesn't include gap buffer, but it is total new size
  // this also does initial alloc, which is awful
  bool growTBuf (uint size) {
    import core.stdc.stdlib : malloc, realloc, free;
    if (size > tbmax) return false; // too big
    if (tbsize == 0) {
      // initial alloc
      assert(size == 0);
      enum nsz = GrowGran;
      tbuf = cast(char*)malloc(nsz);
      if (tbuf is null) return false;
      hbuf = cast(HighState*)malloc(nsz*HighState.sizeof);
      if (hbuf is null) { free(tbuf); tbuf = null; return false; }
      // allocate initial line cache
      uint ICS = (mSingleLine ? 2 : 1024);
      lineofsc = cast(typeof(lineofsc[0])*)realloc(lineofsc, ICS*lineofsc[0].sizeof);
      if (lineofsc is null) { free(hbuf); hbuf = null; free(tbuf); tbuf = null; return false; }
      lineofsc[0..ICS] = LOCItem.init;
      tbsize = nsz;
      locsize = ICS;
    } else {
      if (tbsize-MinGapSize >= size) return true; // nothing to do
      auto nsz = size+MinGapSize;
      if (nsz&(GrowGran-1)) nsz = (nsz|GrowGran)+1;
      char* nb = cast(char*)realloc(tbuf, nsz);
      if (nb is null) return false;
      HighState* hb = cast(HighState*)realloc(hbuf, nsz*HighState.sizeof);
      if (hb is null) { free(nb); return false; }
      tbuf = nb;
      hbuf = hb;
      tbsize = nsz;
    }
    return true;
  }

  bool growLineCache (uint total) {
    assert(total != 0);
    ++total;
    if (locsize < total) {
      import core.stdc.stdlib : realloc;
      // have to allocate more
      uint nsz = total;
      if (nsz&0xff) nsz = (nsz|0xff)+1;
      auto nb = cast(typeof(lineofsc[0])*)realloc(lineofsc, nsz*lineofsc[0].sizeof);
      if (nb is null) {
        // at least exact?
        nb = cast(typeof(lineofsc[0])*)realloc(lineofsc, total*lineofsc[0].sizeof);
        if (nb is null) return false; // alas
        nb[locsize..total] = LOCItem.init;
        locsize = total;
      } else {
        nb[locsize..nsz] = LOCItem.init;
        locsize = nsz;
      }
      lineofsc = nb;
    }
    return true;
  }

  /// using `memchr`, jumps over gap
  public int fastFindChar (int pos, char ch) {
    import core.stdc.string : memchr;
    auto ts = tbused;
    if (ts == 0 || pos >= ts) return ts;
    if (pos < 0) pos = 0;
    // check text before gap
    if (pos < gapstart) {
      auto fp = cast(char*)memchr(tbuf+pos, ch, gapstart-pos);
      if (fp !is null) return cast(int)(fp-tbuf);
      pos = gapstart; // new starting position
    }
    assert(pos >= gapstart);
    // check after gap and to text end
    int left = ts-pos;
    if (left > 0) {
      auto stx = tbuf+gapend+(pos-gapstart);
      auto fp = cast(char*)memchr(stx, ch, left);
      if (fp !is null) return pos+cast(int)(fp-stx);
    }
    return ts;
  }

  /// use `memchr`, jumps over gap
  public int fastFindCharIn (int pos, int len, char ch) {
    import core.stdc.string : memchr;
    auto ts = tbused;
    if (len < 1) return -1;
    if (ts == 0 || pos >= ts) return -1;
    if (pos < 0) {
      if (pos <= -len) return -1;
      len += pos;
      pos = 0;
    }
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
      auto fp = cast(char*)memchr(stx, ch, left);
      if (fp !is null) return pos+cast(int)(fp-stx);
    }
    return -1;
  }

  /// bufparts range
  /// this is hack for regexp searchers
  /// do not store returned slice anywhere for a long time!
  /// slice *will* be invalidated on next gap buffer operation!
  public auto bufparts (int pos) {
    static struct Range {
    nothrow @trusted @nogc:
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
      @property bool empty () pure const { pragma(inline, true); return (gb is null); }
      @property const(char)[] front () pure { pragma(inline, true); return fr; }
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

  // lineofsc[lidx] and lineofsc[lidx+1] should be valid after calling this
  void updateCache (uint lidx) {
    auto ts = tbused;
    if (ts == 0) {
      // rare case, but...
      assert(mLineCount == 1);
      locused = 1;
      lineofsc[0].ofs = lineofsc[1].ofs = 0;
      return;
    }
    if (mSingleLine) {
      assert(mLineCount == 1);
      locused = 1;
      lineofsc[0].ofs = 0;
      lineofsc[1].ofs = ts;
      return;
    }
    if (lidx >= mLineCount) lidx = mLineCount-1;
    if (lidx+1 <= locused) return; // nothing to do
    if (locused == 0) lineofsc[0] = LOCItem.init; else { --locused; lineofsc[locused].height = 0; } // recalc it
    while (locused < lidx+1) {
      auto pos = lineofsc[locused].ofs;
      version(none) {
        auto ep = fastFindChar(pos, '\n')+1;
        if (ep > ts) ep = ts;
        while (pos < ts) if (tbuf[pos2real(pos++)] == '\n') break; // i found her!
        /*
        if (ep != pos) {
          import core.stdc.stdio : FILE, fopen, fclose, fprintf;
          auto fl = fopen("z00.bin", "w");
          scope(exit) fl.fclose;
          fl.fprintf("pos=%d; ep=%d\n", pos, ep);
        }
        */
        assert(ep == pos);
      } else {
        pos = fastFindChar(pos, '\n')+1;
        if (pos > ts) pos = ts;
      }
      lineofsc[++locused] = LOCItem(pos);
    }
    assert(locused == lidx+1);
  }

  void invalidateCacheFrom (uint lidx) {
    if (locsize == 0) { locused = 0; return; } // just in case
    if (lidx == 0) {
      lineofsc[0] = LOCItem.init;
      locused = 0;
    } else {
      if (lidx > mLineCount-1) lidx = mLineCount-1;
      if (lidx < locused) locused = lidx;
      if (locused < locsize) lineofsc[locused].height = 0; // recalc it
    }
  }

  int findLineCacheIndex (uint pos) const {
    if (locused == 0) return -1;
    if (pos >= tbused) return (locused != mLineCount ? -1 : locused-1);
    if (locused == 1) return (pos < lineofsc[1].ofs ? 0 : -1);
    if (pos < lineofsc[locused].ofs) {
      // yay! use binary search to find the line
      int bot = 0, i = cast(int)locused-1;
      while (bot != i) {
        int mid = i-(i-bot)/2;
        //!assert(mid >= 0 && mid < locused);
        auto ls = lineofsc[mid].ofs;
        auto le = lineofsc[mid+1].ofs;
        if (pos >= ls && pos < le) return mid; // i found her!
        if (pos < ls) i = mid-1; else bot = mid;
      }
      return i;
    }
    return -1;
  }

  int findLineCacheYIndex (int y) const {
    if (locused == 0 || lineofsc[locused].height == 0) return -1;
    if (y <= 0) return 0;
    if (locused == 1) return (y < lineofsc[1].height ? 0 : -1);
    if (y < lineofsc[locused].yofs+lineofsc[locused].height) {
      // yay! use binary search to find the line
      int bot = 0, i = cast(int)locused-1;
      while (bot != i) {
        int mid = i-(i-bot)/2;
        //!assert(mid >= 0 && mid < locused);
        auto ls = lineofsc[mid].yofs;
        auto le = ls+lineofsc[mid].height;
        assert(lineofsc[mid].height != 0);
        if (y >= ls && y < le) return mid; // i found her!
        if (y < ls) i = mid-1; else bot = mid;
      }
      return i;
    }
    return -1;
  }

protected:
  uint pos2real (uint pos) const pure {
    pragma(inline, true);
    return pos+(pos >= gapstart ? gapend-gapstart : 0);
  }

public:
  ///
  this (bool asingleline) {
    // allocate minimal buffers
    if (!growTBuf(0)) assert(0, "out of memory for text buffers");
    gapend = MinGapSize;
    mLineCount = 1; // we always have at least one line, even if it is empty
    lineofsc[0..2] = LOCItem.init; // initial line cache
    locused = 0;
    mSingleLine = asingleline;
  }

  ///
  ~this () {
    import core.stdc.stdlib : free;
    if (tbuf !is null) free(tbuf);
    if (hbuf !is null) free(hbuf);
    if (lineofsc !is null) free(lineofsc);
  }

  /// remove all text from buffer
  /// WILL NOT call deletion hooks!
  void clear () {
    import core.stdc.stdlib : free;
    if (tbuf !is null) { free(tbuf); tbuf = null; }
    if (hbuf !is null) { free(hbuf); hbuf = null; }
    if (lineofsc !is null) { free(lineofsc); lineofsc = null; }
    // clear various shit
    tbused = tbsize = 0;
    gapstart = gapend = 0;
    ++bufferChangeCounter;
    locused = locsize = 0;
    mLineCount = 0;
    // allocate new buffer
    if (!growTBuf(0)) assert(0, "out of memory for text buffers");
    gapend = MinGapSize;
    mLineCount = 1; // we always have at least one line, even if it is empty
    lineofsc[0..2] = LOCItem.init; // initial line cache
    locused = 0;
  }

  /// "single line" mode, for line editors
  bool singleline () const pure nothrow @safe @nogc { pragma(inline, true); return mSingleLine; }

  /// size of text buffer without gap, in one-byte chars
  @property int textsize () const pure { pragma(inline, true); return tbused; }
  /// there is always at least one line, so `linecount` is never zero
  @property int linecount () const pure { pragma(inline, true); return mLineCount; }

  @property char opIndex (uint pos) const pure { pragma(inline, true); return (pos < tbsize ? tbuf[pos+(pos >= gapstart ? gapend-gapstart : 0)] : '\0'); } ///
  @property ref HighState hi (uint pos) pure { pragma(inline, true); return (pos < tbsize ? hbuf[pos+(pos >= gapstart ? gapend-gapstart : 0)] : hidummy); } ///

  /// return decoded to koi-8 utf-8 char at buffer position pos
  @property char utfuckAt (uint pos) const pure {
    if (pos >= tbsize) return 0;
    if (!utfuck) return this[pos];
    Utf8DecoderFast udc;
    while (pos < tbsize) {
      if (udc.decode(cast(ubyte)tbuf[pos2real(pos++)])) {
        immutable dchar dch = udc.codepoint;
        return uni2koi(udc.invalid || !udc.isValidDC(dch) ? udc.replacement : dch);
      }
    }
    return uni2koi(udc.replacement);
  }

  /// return utf-8 character length at buffer position pos or -1 on error (or 1 on error if "always positive")
  /// never returns zero
  int utfuckLenAt(bool alwaysPositive=true) (int pos) {
    auto ts = tbused;
    if (pos < 0 || pos >= ts) {
      static if (alwaysPositive) return 1; else return -1;
    }
    if (!utfuck) return 1;
    auto ch = tbuf[pos2real(pos)];
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

  /// get number of *symbols* to line end (this is not always equal to number of bytes for utfuck)
  int syms2eol (int pos) {
    auto ts = tbused;
    if (pos < 0) pos = 0;
    if (pos >= ts) return 0;
    int epos = line2pos(pos2line(pos)+1);
    if (!utfuck) return epos-pos; // fast path
    // slow path
    int count = 0;
    mainloop: while (pos < epos) {
      pos += utfuckLenAt(pos);
      ++count;
    }
    return count;
  }

  /// get line for the given position
  int pos2line (int pos) {
    auto ts = tbused;
    if (pos < 0) return 0;
    if (pos == 0 || ts == 0) return 0;
    if (pos >= ts) return mLineCount-1; // end of text: no need to update line offset cache
    if (mLineCount == 1) return 0;
    int lcidx = findLineCacheIndex(pos);
    if (lcidx < 0) {
      // line cache is unusable, update it
      updateCache(0);
      while (locused < mLineCount && lineofsc[locused-1].ofs < pos) updateCache(locused);
      lcidx = findLineCacheIndex(pos);
      if (lcidx < 0) assert(0, "internal line cache error");
    }
    //!assert(lcidx >= 0 && lcidx < mLineCount);
    return lcidx;
  }

  /// get position (starting) for the given line
  int line2pos (int lidx) {
    if (lidx < 0 || tbused == 0) return 0;
    if (lidx > mLineCount-1) return tbused;
    if (mLineCount == 1) {
      assert(lidx == 0);
      return 0;
    }
    updateCache(lidx);
    return lineofsc[lidx].ofs;
  }

  alias linestart = line2pos; /// ditto

  /// get ending position for the given line (position of '\n')
  /// it may be `textsize-1`, though, if this is the last line, and it doesn't end with '\n', so check for '\n' at EOL, and for any chars in line
  int lineend (int lidx) {
    if (lidx < 0 || tbused == 0) return 0;
    if (lidx > mLineCount-1) return tbused-1;
    if (mLineCount == 1) {
      assert(lidx == 0);
      return tbused-1;
    }
    updateCache(lidx);
    auto res = lineofsc[lidx+1].ofs;
    return (res > lineofsc[lidx].ofs ? res-1 : res);
  }

  // move by `x` utfucked chars
  // `pos` should point to line start
  // will never go beyond EOL
  private int utfuck_x2pos (int x, int pos) {
    auto ts = tbused;
    if (pos < 0) pos = 0;
    immutable bool sl = mSingleLine;
    mainloop: while (pos < ts && x > 0) {
      auto len = utfuckLenAt(pos);
      while (len-- > 0) {
        if (!sl && tbuf[pos2real(pos)] == '\n') break mainloop;
        ++pos;
      }
      --x;
    }
    if (pos > ts) pos = ts;
    return pos;
  }

  // convert line offset to screen x coordinate
  // `pos` should point into line (somewhere)
  private int utfuck_pos2x(bool dotabs=false) (int pos) {
    auto ts = tbused;
    if (pos < 0) pos = 0;
    if (pos > ts) pos = ts;
    immutable bool sl = mSingleLine;
    // find line start
    int spos = pos;
    if (!sl) {
      while (spos > 0 && tbuf[pos2real(spos-1)] != '\n') --spos;
    } else {
      spos = 0;
    }
    // now `spos` points to line start; walk over utfucked chars
    int x = 0;
    mainloop: while (spos < pos) {
      auto len = utfuckLenAt(spos);
      if (len == 1) {
        auto ch = tbuf[pos2real(spos)];
        if (!sl && ch == '\n') break mainloop;
        ++spos;
        static if (dotabs) {
          if (ch == '\t' && visualtabs && tabsize > 0) {
            x = ((x+tabsize)/tabsize)*tabsize;
          } else {
            ++x;
          }
        } else {
          ++x;
        }
      } else {
        while (len-- > 0) {
          if (!sl && tbuf[pos2real(spos)] == '\n') break mainloop; // just in case
          ++spos;
        }
        ++x;
      }
    }
    return x;
  }

  /// get position for the given text coordinates
  int xy2pos (int x, int y) {
    auto ts = tbused;
    if (ts == 0 || y < 0) return 0;
    if (y > mLineCount-1) return ts;
    if (x < 0) x = 0;
    if (mLineCount == 1) {
      assert(y == 0);
      return (!utfuck ? (x < ts ? x : ts) : utfuck_x2pos(x, 0));
    }
    updateCache(y);
    uint ls = lineofsc[y].ofs;
    uint le = lineofsc[y+1].ofs;
    if (ls == le) {
      // this should be last empty line
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
  void pos2xy (int pos, out int x, out int y) {
    auto ts = tbused;
    if (pos <= 0 || ts == 0) return; // x and y autoinited
    if (pos > ts) pos = ts;
    if (mLineCount == 1) {
      // y is autoinited
      x = (!utfuck ? pos : utfuck_pos2x(pos));
      return;
    }
    if (pos == ts) {
      // end of text: no need to update line offset cache
      y = mLineCount-1;
      if (!mSingleLine) {
        while (pos > 0 && tbuf[pos2real(--pos)] != '\n') ++x;
      } else {
        x = pos;
      }
      return;
    }
    int lcidx = findLineCacheIndex(pos);
    if (lcidx < 0) {
      // line cache is unusable, update it
      updateCache(0);
      while (locused < mLineCount && lineofsc[locused-1].ofs < pos) updateCache(locused);
      lcidx = findLineCacheIndex(pos);
      if (lcidx < 0) assert(0, "internal line cache error");
    }
    //!assert(lcidx >= 0 && lcidx < mLineCount);
    auto ls = lineofsc[lcidx].ofs;
    //auto le = lineofsc[lcidx+1];
    //!assert(pos >= ls && pos < le);
    y = cast(uint)lcidx;
    x = (!utfuck ? pos-ls : utfuck_pos2x(pos));
  }

  /// get text coordinates (adjusted for tabs) for the given position
  void pos2xyVT (int pos, out int x, out int y) {
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
        while (ls < pos) {
          if (tbuf[pos2real(ls++)] == '\t') x = ((x+tabsize)/tabsize)*tabsize; else ++x;
        }
      }
    }

    auto ts = tbused;
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
      y = mLineCount-1;
      while (pos > 0 && (mSingleLine || tbuf[pos2real(--pos)] != '\n')) ++x;
      if (utfuck) { x = utfuck_pos2x!true(ts); return; }
      if (visualtabs && tabsize != 0) { int ls = pos+1; pos = ts; tabbedX(ls); return; }
      return;
    }
    int lcidx = findLineCacheIndex(pos);
    if (lcidx < 0) {
      // line cache is unusable, update it
      updateCache(0);
      while (locused < mLineCount && lineofsc[locused-1].ofs < pos) updateCache(locused);
      lcidx = findLineCacheIndex(pos);
      if (lcidx < 0) assert(0, "internal line cache error");
    }
    //!assert(lcidx >= 0 && lcidx < mLineCount);
    auto ls = lineofsc[lcidx].ofs;
    //auto le = lineofsc[lcidx+1];
    //!assert(pos >= ls && pos < le);
    y = cast(uint)lcidx;
    if (utfuck) { x = utfuck_pos2x!true(pos); return; }
    if (visualtabs && tabsize > 0) { tabbedX(ls); return; }
    x = pos-ls;
  }

  /// ensure that the buffer has room for at least one char in the gap
  /// note that this may move gap
  protected void ensureGap () {
    // if we have zero-sized gap, assume that it is at end; we always have a room for at least MinGapSize chars
    if (gapstart >= gapend) {
      assert(tbused-tbsize >= MinGapSize);
      gapend = (gapstart = tbused)+MinGapSize;
    }
  }

  /// put the gap *before* `pos`
  protected void moveGapAtPos (int pos) {
    import core.stdc.string : memmove;
    auto ts = tbused; // i will need it in several places
    if (pos < 0) pos = 0;
    if (pos > ts) pos = ts;
    debug(gapmove) { import core.stdc.stdio : printf; printf("pos=%u; ts=%u; gs=%u; ge=%u\n", pos, ts, gapstart, gapend); }
    assert(pos <= ts);
    if (ts == 0) { gapstart = 0; gapend = MinGapSize; return; } // unlikely case, but...
    ensureGap(); // we should have a gap
    assert(gapstart < gapend);
    if (pos == gapstart) return; // nothing to do
    /* cases:
     *  pos is before gap: shift [pos..gapstart] to gapend-len, shift gap
     *  pos is after gap: shift [gapend..pos] to gapstart, shift gap
     */
    if (pos < gapstart) {
      // pos is before gap
      int len = gapstart-pos; // to shift
      memmove(tbuf+gapend-len, tbuf+pos, len);
      memmove(hbuf+gapend-len, hbuf+pos, len*HighState.sizeof);
      gapstart -= len;
      gapend -= len;
    } else {
      // pos is after gap
      assert(pos > gapstart);
      //int pos += gapend-gapstart; // real position in buffer
      int len = pos-gapstart;
      assert(len > 0);
      memmove(tbuf+gapstart, tbuf+gapend, len);
      memmove(hbuf+gapstart, hbuf+gapend, len*HighState.sizeof);
      gapstart += len;
      gapend += len;
    }
    assert(gapstart == pos);
    assert(gapstart < gapend);
  }

  /// put the gap at the end of the text
  void moveGapAtEnd () {
    import core.stdc.string : memmove;
    auto ts = tbused; // i will need it in several places
    if (ts == 0) { gapstart = 0; gapend = MinGapSize; return; } // unlikely case, but...
    if (gapstart < gapend && gapstart != ts) {
      // has gap somewhere, compact text
      auto msz = ts-gapstart;
      debug(gapmove) { import core.stdc.stdio : printf; printf("toend: ts=%u; gs=%u; ge=%u; msz=%u\n", ts, gapstart, gapend, msz); }
      memmove(tbuf+gapstart, tbuf+gapend, msz);
      memmove(hbuf+gapstart, hbuf+gapend, msz*HighState.sizeof);
    }
    // fix gap pointers
    gapend = (gapstart = ts)+MinGapSize;
    debug(gapmove) { import core.stdc.stdio : printf; printf("toend: ts=%u; gs=%u; ge=%u\n", ts, gapstart, gapend); }
    assert(gapend <= tbsize);
  }

  /// put text into buffer; will either put all the text, or nothing
  /// returns success flag
  bool append (const(char)[] str...) { return (put(tbused, str) >= 0); }

  /// put text into buffer; will either put all the text, or nothing
  /// returns new position or -1
  int put (int pos, const(char)[] str...) {
    import core.stdc.string : memchr, memcpy, memset;
    if (pos < 0) pos = 0;
    auto ts = tbused;
    bool atend = false;
    if (pos >= ts) { pos = ts; atend = true; }
    if (str.length == 0) return pos;
    //if (str.length > tbmax-MinGapSize) return -1; // no room anyway
    if (tbmax-tbused-MinGapSize < str.length) return -1; // still no room
    if (!growTBuf(tbused+cast(uint)str.length)) return -1; // memory allocation failed
    int linecount = (!mSingleLine ? countEols(str) : 0);
    // count number of new lines and grow line cache
    if (!growLineCache(mLineCount+linecount)) return -1;
    auto olc = mLineCount;
    mLineCount += linecount;
    // invalidate line cache
    int lcidx = findLineCacheIndex(pos);
    //TODO: i can make this faster
    if (lcidx >= 0) invalidateCacheFrom(lcidx);
    //scope(exit) updateCache(0);
    if (pos == tbused) {
      moveGapAtEnd();
      memcpy(tbuf+tbused, str.ptr, str.length);
      memset(hbuf+tbused, 0, HighState.sizeof*str.length);
      tbused += cast(uint)str.length;
      gapend = (gapstart = tbused)+MinGapSize;
      pos += cast(uint)str.length;
    } else {
      while (str.length > 0) {
        moveGapAtPos(pos);
        assert(gapstart == pos);
        assert(gapstart < gapend);
        auto cplen = gapend-gapstart;
        if (cplen > str.length) cplen = cast(uint)str.length;
        memcpy(tbuf+gapstart, str.ptr, cplen);
        memset(hbuf+gapstart, 0, cplen*HighState.sizeof);
        pos += cplen;
        gapstart += cplen;
        tbused += cplen;
        assert(tbused <= tbsize-MinGapSize);
        str = str[cplen..$];
      }
      ensureGap(); // we should always have gap buffer available
    }
    assert(tbsize-tbused >= MinGapSize);
    if (atend) invalidateCacheFrom(olc-1); // if last line was empty, and the cache was full, the cache in invalid now
    ++bufferChangeCounter;
    return pos;
  }

  /// remove count codepoints from the current position; will either remove all of 'em, or nothing
  /// returns success flag
  bool remove (int pos, int count) {
    import core.stdc.string : memmove;
    if (count < 0) return false;
    if (count == 0) return true;
    auto ts = tbused;
    if (pos < 0) pos = 0;
    if (pos > ts) pos = ts;
    if (ts-pos < count) return false; // not enough text here
    assert(gapstart < gapend);
    // invalidate line cache
    int lcidx = findLineCacheIndex(pos);
    //TODO: i can make this faster
    if (lcidx >= 0) invalidateCacheFrom(lcidx);
    //scope(exit) updateCache(0);
    //TODO: utfuck
    // at the start of the gap: i can just increase gap
    ++bufferChangeCounter;
    if (pos == gapstart) {
      // decrease line counter
      mLineCount -= (!mSingleLine ? countEols(tbuf[gapend..gapend+count]) : 0);
      gapend += count;
      tbused -= count;
      return true;
    }
    // removing text just before gap: increase gap (backspace does this)
    if (pos+count == gapstart) {
      mLineCount -= (!mSingleLine ? countEols(tbuf[pos..pos+count]) : 0);
      gapstart -= count;
      tbused -= count;
      return true;
    }
    //TODO: add more gap edge movement?
    moveGapAtEnd();
    assert(pos+count <= ts);
    mLineCount -= (!mSingleLine ? countEols(tbuf[pos..pos+count]) : 0);
    if (pos+count == ts) {
      tbused = pos;
      gapend = (gapstart = tbused)+MinGapSize;
    } else {
      memmove(tbuf+pos, tbuf+pos+count, tbused-pos-count);
      memmove(hbuf+pos, hbuf+pos+count, (tbused-pos-count)*HighState.sizeof);
      tbused -= count;
      gapstart -= count;
      gapend -= count;
      moveGapAtPos(pos);
    }
    return true;
  }

  /// count how much eols we have in this range
  int countEolsInRange (int pos, int count) {
    if (count < 1 || pos <= -count || pos >= tbused) return 0;
    if (pos+count > tbused) count = tbused-pos;
    int res = 0;
    foreach (int p; pos..pos+count) if (tbuf[pos2real(p)] == '\n') ++res;
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// highlighter should be able to work line-by-line
class EditorHL {
protected:
  GapBuffer gb; ///

public:
  this () {} ///

  /// return true if highlighting for this line was changed
  abstract bool fixLine (int line);

  /// mark line as "need rehighlighting" (and possibly other text too)
  /// wasInsDel: some lines was inserted/deleted down the text
  abstract void lineChanged (int line, bool wasInsDel);
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

    @property nothrow @safe @nogc pure {
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

private import core.sys.posix.unistd : off_t;

private:
  int tmpfd = -1;
  off_t tmpsize = 0;
  bool asRedo;
  // undo buffer format:
  //   last uint is always record size (not including size uints); record follows (up), then size again
  uint maxBufSize = 32*1024*1024;
  ubyte* undoBuffer;
  uint ubUsed, ubSize;

final:
  void initTempFD () nothrow @nogc {
    import core.sys.posix.fcntl /*: open*/;
    static if (is(typeof(O_CLOEXEC)) && is(typeof(O_TMPFILE))) {
      auto xfd = open("/tmp/_egundoz", O_RDWR|O_CLOEXEC|O_TMPFILE, 0x1b6/*0o600*/);
      if (xfd < 0) return;
      tmpfd = xfd;
      tmpsize = 0;
    }
  }

  // returns record size
  uint loadLastRecord(bool fullrecord=true) (bool dropit=false) nothrow @nogc {
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

  bool saveLastRecord () nothrow @nogc {
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
    return true;
  }

  // return `true` if something was removed
  bool removeFirstUndo () nothrow @nogc {
    import core.stdc.string : memmove;
    assert(tmpfd < 0);
    if (ubUsed == 0) return false;
    uint np = (*cast(uint*)undoBuffer)+4*2;
    assert(np <= ubUsed);
    if (np == ubUsed) { ubUsed = 0; return true; }
    memmove(undoBuffer, undoBuffer+np, ubUsed-np);
    ubUsed -= np;
    return true;
  }

  // return `null` if it can't; undo buffer is in invalid state then
  Action* addUndo (int dataSize) nothrow @nogc {
    import core.stdc.stdlib : realloc;
    import core.stdc.string : memset;
    if (tmpfd < 0) {
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
    } else {
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
  Action* lastUndoHead () nothrow @trusted @nogc {
    if (tmpfd >= 0) {
      if (loadLastRecord!false()) return null;
      return cast(Action*)undoBuffer;
    } else {
      if (ubUsed == 0) return null;
      auto sz = *cast(uint*)(undoBuffer+ubUsed-4);
      return cast(Action*)(undoBuffer+ubUsed-4-sz);
    }
  }

  Action* popUndo () nothrow @trusted @nogc {
    if (tmpfd >= 0) {
      auto len = loadLastRecord!true(true); // pop it
      return (len ? cast(Action*)undoBuffer : null);
    } else {
      if (ubUsed == 0) return null;
      auto sz = *cast(uint*)(undoBuffer+ubUsed-4);
      auto res = cast(Action*)(undoBuffer+ubUsed-4-sz);
      ubUsed -= sz+4*2;
      return res;
    }
  }

public:
  this (bool aAsRedo, bool aIntoFile) nothrow @nogc {
    asRedo = aAsRedo;
    if (aIntoFile) {
      initTempFD();
      if (tmpfd < 0) {
        //version(aliced) { import iv.rawtty; ttyBeep(); }
      }
    }
  }

  ~this () nothrow @nogc {
    import core.stdc.stdlib : free;
    import core.sys.posix.unistd : close;
    if (tmpfd >= 0) { close(tmpfd); tmpfd = -1; }
    if (undoBuffer !is null) free(undoBuffer);
  }

  void clear (bool doclose=false) nothrow @nogc {
    ubUsed = 0;
    if (doclose) {
      import core.stdc.stdlib : free;
      if (tmpfd >= 0) {
        import core.sys.posix.unistd : close;
        close(tmpfd);
        tmpfd = -1;
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
      if (tmpfd >= 0) tmpsize = 0;
    }
  }

  void alwaysChanged () nothrow @trusted @nogc {
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

  private void fillCurPos (Action* ua, EditorEngine ed) nothrow @trusted @nogc {
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

  bool addCurMove (EditorEngine ed, bool fromRedo=false) nothrow @nogc {
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

  bool addTextRemove (EditorEngine ed, int pos, int count, bool fromRedo=false) nothrow @nogc {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    GapBuffer gb = ed.gb;
    assert(gb !is null);
    if (pos < 0 || pos >= gb.textsize) return true;
    if (count < 1) return true;
    if (count >= maxBufSize) { clear(); return false; }
    if (count > gb.textsize-pos) { clear(); return false; }
    auto act = addUndo(count);
    if (act is null) { clear(); return false; }
    act.type = Type.TextRemove;
    act.pos = pos;
    act.len = count;
    fillCurPos(act, ed);
    auto dp = act.data.ptr;
    while (count--) *dp++ = gb[pos++];
    return saveLastRecord();
  }

  bool addTextInsert (EditorEngine ed, int pos, int count, bool fromRedo=false) nothrow @nogc {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.TextInsert;
    act.pos = pos;
    act.len = count;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  bool addGroupStart (EditorEngine ed, bool fromRedo=false) nothrow @nogc {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.GroupStart;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  bool addGroupEnd (EditorEngine ed, bool fromRedo=false) nothrow @nogc {
    if (!asRedo && !fromRedo && ed.redo !is null) ed.redo.clear();
    auto act = addUndo(0);
    if (act is null) { clear(); return false; }
    act.type = Type.GroupEnd;
    fillCurPos(act, ed);
    return saveLastRecord();
  }

  @property bool hasUndo () const pure nothrow @safe @nogc { pragma(inline, true); return (tmpfd < 0 ? (ubUsed > 0) : (tmpsize > 0)); }

  private bool copyAction (Action* ua) nothrow @nogc {
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
        ed.ubTextInsert(ua.pos, ua.data.ptr[0..ua.len]);
        //ed.writeLogAction(ua.pos, ua.len);
        break;
    }
    //FIXME: optimize redraw
    if (ua.bs != ed.bstart || ua.be != ed.bend) {
      if (ua.bs < ua.be) {
        // undo has block
        if (ed.bstart < ed.bend) ed.markLinesDirtySE(ed.gb.pos2line(ed.bstart), ed.gb.pos2line(ed.bend)); // old block is dirty
        ed.markLinesDirtySE(ed.gb.pos2line(ua.bs), ed.gb.pos2line(ua.be)); // new block is dirty
      } else {
        // undo has no block
        if (ed.bstart < ed.bend) ed.markLinesDirtySE(ed.gb.pos2line(ed.bstart), ed.gb.pos2line(ed.bend)); // old block is dirty
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
  final char recodeCharTo (char ch) pure const nothrow @safe @nogc {
    pragma(inline, true);
    return
      codepage == CodePage.cp1251 ? uni2cp1251(koi2uni(ch)) :
      codepage == CodePage.cp866 ? uni2cp866(koi2uni(ch)) :
      ch;
  }

  /// from codepage to koi
  final char recodeCharFrom (char ch) pure const nothrow @safe @nogc {
    pragma(inline, true);
    return
      codepage == CodePage.cp1251 ? uni2koi(cp12512uni(ch)) :
      codepage == CodePage.cp866 ? uni2koi(cp8662uni(ch)) :
      ch;
  }

  /// recode to codepage
  final char recodeU2B (dchar dch) pure const nothrow @safe @nogc {
    final switch (codepage) {
      case CodePage.koi8u: return uni2koi(dch);
      case CodePage.cp1251: return uni2cp1251(dch);
      case CodePage.cp866: return uni2cp866(dch);
    }
  }

  /// should not be called for utfuck mode
  final dchar recode1b (char ch) pure const nothrow @safe @nogc {
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
  bool[] dirtyLines;
  int winx, winy, winw, winh;
  GapBuffer gb;
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

protected:
  bool[int] linebookmarked; /// is this line bookmarked?

public:
  EgTextMeter textMeter; // *MUST* be set for coordsInPixels

public:
  /// is editor in "paste mode" (i.e. we are pasting chars from clipboard, and should skip autoindenting)?
  final @property bool pasteMode () const pure nothrow @safe @nogc { return (inPasteMode > 0); }
  final resetPasteMode () pure nothrow @safe @nogc { inPasteMode = 0; } ///

  ///
  final void clearBookmarks () nothrow {
    linebookmarked.clear();
  }

  ///
  final void bookmarkChange(string mode="toggle") (int cy) nothrow {
    static assert(mode == "toggle" || mode == "set" || mode == "reset");
    if (cy < 0 || cy >= gb.linecount) return;
    if (mSingleLine) return; // ignore for singleline mode
    static if (mode == "toggle") {
      if (cy in linebookmarked) {
        // remove it
        linebookmarked.remove(cy);
      } else {
        // add it
        linebookmarked[cy] = true;
      }
      markLinesDirty(cy, 1);
    } else static if (mode == "set") {
      if (cy !in linebookmarked) {
        linebookmarked[cy] = true;
        markLinesDirty(cy, 1);
      }
    } else static if (mode == "reset") {
      if (cy in linebookmarked) {
        linebookmarked.remove(cy);
        markLinesDirty(cy, 1);
      }
    } else {
      static assert(0, "wtf?!");
    }
  }

  ///
  final void doBookmarkToggle () nothrow { pragma(inline, true); bookmarkChange!"toggle"(cy); }

  ///
  final @property bool isLineBookmarked (int lidx) nothrow @safe @nogc {
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
    if (bestBM < gb.linecount) {
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

  /// call this from `willBeDeleted()` (only) to fix bookmarks
  final void bookmarkDeletionFix (int pos, int len, int eolcount) nothrow {
    if (eolcount && linebookmarked.length > 0) {
      import core.stdc.stdlib : malloc, free;
      // remove bookmarks whose lines are removed, move other bookmarks
      auto py = gb.pos2line(pos);
      auto ey = gb.pos2line(pos+len);
      bool wholeFirstLineDeleted = (pos == gb.line2pos(py)); // do we want to remove the whole first line?
      bool wholeLastLineDeleted = (pos+len == gb.line2pos(ey)); // do we want to remove the whole last line?
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
          assert(lidx >= 0 && lidx < gb.linecount);
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
      auto py = gb.pos2line(pos);
      if (pos != gb.line2pos(py)) ++py; // not the whole first line was modified, don't touch bookmarks on it
      // build new bookmark array
      int* newbm = cast(int*)malloc(int.sizeof*linebookmarked.length);
      if (newbm !is null) {
        scope(exit) free(newbm);
        int newbmpos = 0;
        bool smthWasChanged = false;
        foreach (int lidx; linebookmarked.byKey) {
          // fix bookmark line if necessary
          if (lidx >= py) { smthWasChanged = true; lidx += eolcount; }
          if (lidx < 0 || lidx >= gb.linecount) continue;
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
    hl = ahl;
    if (ahl !is null) hl.gb = gb;
    undo = new UndoStack(false, !asingleline);
    redo = new UndoStack(true, !asingleline);
    mSingleLine = asingleline;
  }

  private void setDirtyLinesLength (usize len) nothrow @trusted {
    if (len > int.max/4) assert(0, "wtf?!");
    if (dirtyLines.length > len) {
      dirtyLines.length = len;
      dirtyLines.assumeSafeAppend;
    } else if (dirtyLines.length < len) {
      auto optr = dirtyLines.ptr;
      auto olen = dirtyLines.length;
      dirtyLines.length = len;
      if (dirtyLines.ptr !is optr) {
        import core.memory : GC;
        if (dirtyLines.ptr is GC.addrOf(dirtyLines.ptr)) GC.setAttr(dirtyLines.ptr, GC.BlkAttr.NO_INTERIOR);
      }
      dirtyLines[olen..$] = true;
    }
  }

  // utfuck switch hooks
  protected void beforeUtfuckSwitch (bool newisutfuck) {} /// utfuck switch hook
  protected void afterUtfuckSwitch (bool newisutfuck) {} /// utfuck switch hook

  final @property {
    ///
    bool utfuck () const pure nothrow @safe @nogc { pragma(inline, true); return gb.utfuck; }

    /// this switches "utfuck" mode
    /// note that utfuck mode is FUCKIN' SLOW and buggy
    /// you should not lose any text, but may encounder visual and positional glitches
    void utfuck (bool v) {
      if (gb.utfuck == v) return;
      beforeUtfuckSwitch(v);
      auto pos = curpos;
      gb.utfuck = v;
      gb.pos2xy(pos, cx, cy);
      fullDirty();
      afterUtfuckSwitch(v);
    }

    int x0 () const pure nothrow @safe @nogc { pragma(inline, true); return winx; } ///
    int y0 () const pure nothrow @safe @nogc { pragma(inline, true); return winy; } ///
    int width () const pure nothrow @safe @nogc { pragma(inline, true); return winw; } ///
    int height () const pure nothrow @safe @nogc { pragma(inline, true); return winh; } ///

    void x0 (int v) nothrow @safe @nogc { pragma(inline, true); move(v, winy); } ///
    void y0 (int v) nothrow @safe @nogc { pragma(inline, true); move(winx, v); } ///
    void width (int v) nothrow @safe { pragma(inline, true); resize(v, winh); } ///
    void height (int v) nothrow @safe { pragma(inline, true); resize(winw, v); } ///

    /// has any effect only if you are using `insertText()` and `deleteText()` API!
    bool readonly () const pure nothrow @safe @nogc { pragma(inline, true); return mReadOnly; }
    void readonly (bool v) nothrow @safe @nogc { pragma(inline, true); mReadOnly = v; } ///

    /// "single line" mode, for line editors
    bool singleline () const pure nothrow @safe @nogc { pragma(inline, true); return mSingleLine; }

    /// "buffer change counter"
    uint bufferCC () const pure nothrow @safe @nogc { pragma(inline, true); return gb.bufferChangeCounter; }
    void bufferCC (uint v) pure nothrow @safe @nogc { pragma(inline, true); gb.bufferChangeCounter = v; } ///

    bool killTextOnChar () const pure nothrow @safe @nogc { pragma(inline, true); return mKillTextOnChar; } ///
    void killTextOnChar (bool v) nothrow @safe @nogc { ///
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
      auto lh = gb.lidx2pixelh(lidx++, textMeter, &recode1b);
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
      auto lh = gb.lidx2pixelh(lidx++, textMeter, &recode1b);
      //if (gb.mLineCount > 0) { import core.stdc.stdio; printf("*clpw: lidx=%d; height=%d; hgtleft=%d\n", lidx-1, lh, hgtleft); }
      hgtleft -= lh;
      if (hgtleft >= 0) ++lcount;
      if (hgtleft <= 0) break;
    }
    //{ import core.stdc.stdio; printf("clpw: %d\n", lcount); }
    return (lcount ? lcount : 1);
  }

  /// has lille sense if `inPixels` is false
  final int linePixelYHeight (int lidx, int* outhgt=null) nothrow {
    if (lidx <= 0) {
      if (inPixels && textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      if (outhgt !is null) *outhgt = (inPixels ? (lineHeightPixels > 0 ? lineHeightPixels : gb.lidx2pixelh(gb.mLineCount, textMeter, &recode1b)) : 1);
      return 0;
    }
    if (!inPixels) {
      if (outhgt !is null) *outhgt = 1;
      return (lidx < gb.mLineCount ? gb.mLineCount : lidx);
    }
    if (lineHeightPixels > 0) {
      if (outhgt !is null) *outhgt = lineHeightPixels;
      if (lidx > gb.mLineCount) lidx = gb.mLineCount;
      return lidx*lineHeightPixels;
    } else {
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      auto lm = gb.lidx2pixelyh(lidx, textMeter, &recode1b);
      if (outhgt !is null) *outhgt = lm.height;
      return lm.y;
    }
  }

  /// has lille sense if `inPixels` is false
  final int linePixelHeight (int lidx) nothrow {
    if (!inPixels) return 1;
    if (lineHeightPixels > 0) {
      return lineHeightPixels;
    } else {
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      return gb.lidx2pixelh(lidx, textMeter, &recode1b);
    }
  }

  /// resize control
  void resize (int nw, int nh) nothrow @trusted {
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

  ///
  void move (int nx, int ny) nothrow @safe @nogc {
    if (winx != nx || winy != ny) {
      winx = nx;
      winy = ny;
      fullDirty();
    }
  }

  ///
  void moveResize (int nx, int ny, int nw, int nh) nothrow @safe {
    move(nx, ny);
    resize(nw, nh);
  }

  final @property void curx (int v) nothrow @system { gotoXY(v, cy); } ///
  final @property void cury (int v) nothrow @system { gotoXY(cx, v); } ///

  final @property nothrow @safe @nogc {
    /// has active marked block?
    bool hasMarkedBlock () const pure { pragma(inline, true); return (bstart < bend); }

    int curx () const pure { pragma(inline, true); return cx; } ///
    int cury () const pure { pragma(inline, true); return cy; } ///
    int xofs () const pure { pragma(inline, true); return mXOfs; } ///

    int topline () const pure { pragma(inline, true); return mTopLine; } ///
    int linecount () const pure { pragma(inline, true); return gb.linecount; } ///
    int textsize () const pure { pragma(inline, true); return gb.textsize; } ///

    char opIndex (int pos) const pure { pragma(inline, true); return gb[pos]; } ///

    ///
    dchar dcharAt (int pos) const pure {
      auto ts = gb.textsize;
      if (pos < 0 || pos >= ts) return 0;
      if (!gb.utfuck) {
        final switch (codepage) {
          case CodePage.koi8u: return koi2uni(this[pos]);
          case CodePage.cp1251: return cp12512uni(this[pos]);
          case CodePage.cp866: return cp8662uni(this[pos]);
        }
        assert(0);
      }
      Utf8DecoderFast udc;
      while (pos < ts) {
        if (udc.decode(cast(ubyte)gb[pos++])) {
          immutable dchar dch = udc.codepoint;
          return (udc.invalid || !udc.isValidDC(dch) ? udc.replacement : dch);
        }
      }
      return udc.replacement;
    }

    /// this advances `pos`
    dchar dcharAtAdvance (ref int pos) const pure {
      auto ts = gb.textsize;
      if (pos < 0) { pos = 0; return 0; }
      if (pos >= ts) { pos = ts; return 0; }
      if (!gb.utfuck) {
        immutable char ch = this[pos++];
        final switch (codepage) {
          case CodePage.koi8u: return koi2uni(ch);
          case CodePage.cp1251: return cp12512uni(ch);
          case CodePage.cp866: return cp8662uni(ch);
        }
        assert(0);
      }
      immutable ep = pos+1;
      Utf8DecoderFast udc;
      while (pos < ts) {
        if (udc.decode(cast(ubyte)gb[pos++])) {
          immutable dchar dch = udc.codepoint;
          if (udc.invalid || !udc.isValidDC(dch)) { pos = ep; return udc.replacement; }
          return dch;
        }
      }
      pos = ep;
      return udc.replacement;
    }

    /// this works correctly with utfuck
    int nextpos (int pos) const pure {
      if (pos < 0) return 0;
      immutable ts = gb.textsize;
      if (pos >= ts) return ts;
      if (!gb.utfuck) return pos+1;
      immutable ep = pos+1;
      Utf8DecoderFast udc;
      while (pos < ts) {
        if (udc.decode(cast(ubyte)gb[pos++])) return (udc.invalid ? ep : pos);
      }
      return ep;
    }

    bool textChanged () const pure { pragma(inline, true); return txchanged; } ///
    void textChanged (bool v) pure { pragma(inline, true); txchanged = v; } ///

    bool visualtabs () const pure { pragma(inline, true); return (gb.visualtabs && gb.tabsize > 0); } ///

    ///
    void visualtabs (bool v) {
      if (gb.visualtabs != v) {
        //auto pos = curpos;
        gb.visualtabs = v;
        fullDirty();
        //gb.pos2xy(pos, cx, cy);
      }
    }

    ubyte tabsize () const pure { pragma(inline, true); return gb.tabsize; } ///

    ///
    void tabsize (ubyte v) {
      if (gb.tabsize != v) {
        gb.tabsize = v;
        if (gb.visualtabs) fullDirty();
      }
    }

    /// mark whole visible text as dirty
    final void fullDirty () nothrow @safe @nogc { dirtyLines[] = true; }
  }

  ///
  void topline (int v) nothrow {
    if (v < 0) v = 0;
    if (v > gb.linecount) v = gb.linecount-1;
    immutable auto moldtop = mTopLine;
    mTopLine = v; // for linesPerWindow
    if (v+linesPerWindow > gb.linecount) {
      v = gb.linecount-linesPerWindow;
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
    if (ny >= gb.linecount) ny = gb.linecount-1;
    auto pos = gb.xy2pos(nx, ny);
    gb.pos2xy(pos, nx, ny);
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
    gb.pos2xy(pos, rx, ry);
    gotoXY!vcenter(rx, ry);
  }

  final int curpos () nothrow @safe @nogc { pragma(inline, true); return gb.xy2pos(cx, cy); } ///

  ///
  void clearUndo () nothrow @nogc {
    if (undo !is null) undo.clear();
    if (redo !is null) redo.clear();
  }

  ///
  void clear () nothrow @nogc {
    gb.clear();
    txchanged = false;
    if (undo !is null) undo.clear();
    if (redo !is null) redo.clear();
    cx = cy = mTopLine = mXOfs = 0;
    prevTopLine = -1;
    prevXOfs = -1;
    dirtyLines[] = true;
    bstart = bend = -1;
    markingBlock = false;
    lastBGEnd = false;
    txchanged = false;
  }

  ///
  void clearAndDisableUndo () {
    if (undo !is null) { undo.clear(true); delete undo; undo = null; }
    if (redo !is null) { redo.clear(true); delete redo; redo = null; }
  }

  ///
  void reinstantiateUndo () {
    if (undo is null) undo = new UndoStack(false, !mSingleLine);
    if (redo is null) redo = new UndoStack(true, !mSingleLine);
  }

  ///
  void loadFile (const(char)[] fname) { loadFile(VFile(fname)); }

  ///
  void loadFile (VFile fl) {
    import core.stdc.stdlib : malloc, free;
    clear();
    enum BufSize = 65536;
    char* buf = cast(char*)malloc(BufSize);
    if (buf is null) throw new Exception("out of memory");
    scope(exit) free(buf);
    for (;;) {
      auto rd = fl.rawRead(buf[0..BufSize]);
      if (rd.length == 0) break;
      if (!gb.append(rd[])) throw new Exception("text too big");
    }
  }

  ///
  void saveFile (const(char)[] fname) { saveFile(VFile(fname, "w")); }

  ///
  void saveFile (VFile fl) {
    //FIXME: this uses internals of gap buffer!
    gb.moveGapAtEnd();
    fl.rawWriteExact(gb.tbuf[0..gb.tbused]);
    txchanged = false;
    if (undo !is null) undo.alwaysChanged();
    if (redo !is null) redo.alwaysChanged();
  }

  /// note that you can't reuse one highlighter for several editors!
  void attachHiglighter (EditorHL ahl) {
    if (ahl is hl) return; // nothing to do
    if (ahl is null) {
      // detach
      if (hl !is null) {
        hl.gb = null;
        hl = null;
        fullDirty();
      }
      return;
    }
    if (ahl.gb !is null) {
      if (ahl.gb !is gb) throw new Exception("highlighter already used by another editor");
      if (ahl !is hl) assert(0, "something is VERY wrong");
      return;
    }
    if (hl !is null) hl.gb = null;
    ahl.gb = gb;
    hl = ahl;
    ahl.lineChanged(0, true);
    fullDirty();
  }

  ///
  EditorHL detachHighlighter () {
    auto res = hl;
    if (res !is null) {
      hl.gb = null;
      hl = null;
      fullDirty();
    }
    return res;
  }

  /// override this method to draw text cursor; it will be called after `drawPageMisc()`
  public abstract void drawCursor ();

  /// override this method to draw status line; it will be called after `drawPageBegin()`
  public abstract void drawStatus ();

  /// override this method to draw one text line
  /// highlighting is done, other housekeeping is done, only draw
  /// lidx is always valid
  /// must repaint the whole line
  /// use `winXXX` vars to know window dimensions
  public abstract void drawLine (int lidx, int yofs, int xskip);

  /// just clear line
  /// use `winXXX` vars to know window dimensions
  public abstract void drawEmptyLine (int yofs);

  /// override this method to draw something before any other page drawing will be done
  public void drawPageBegin () {}

  /// override this method to draw something after page was drawn, but before drawing the cursor
  public void drawPageMisc () {}

  /// override this method to draw something (or flush drawing buffer) after everything was drawn
  public void drawPageEnd () {}

  /// draw the page; it will fix coords, call necessary methods and so on. you are usually don't need to override this.
  void drawPage () {
    makeCurLineVisible();

    if (prevTopLine != mTopLine || prevXOfs != mXOfs) {
      prevTopLine = mTopLine;
      prevXOfs = mXOfs;
      dirtyLines[] = true;
    }

    drawPageBegin();
    drawStatus();
    immutable int ydelta = (inPixels ? lineHeightPixels : 1);
    auto pos = gb.xy2pos(0, mTopLine);
    auto lc = gb.linecount;
    int lyofs = 0;
    foreach (int y; 0..visibleLinesPerWindow) {
      bool dirty = true;
      if (mTopLine+y < lc && hl !is null && hl.fixLine(mTopLine+y)) {
        if (y < dirtyLines.length) dirtyLines.ptr[y] = true;
      } else {
        dirty = (y < dirtyLines.length ? dirtyLines.ptr[y] : true);
      }
      if (dirty) {
        if (y < dirtyLines.length) dirtyLines.ptr[y] = false;
        if (mTopLine+y < lc) {
          drawLine(mTopLine+y, lyofs, mXOfs);
        } else {
          drawEmptyLine(lyofs);
        }
      }
      if (ydelta > 0) {
        lyofs += ydelta;
      } else {
        lyofs += linePixelHeight(mTopLine+y);
      }
    }
    drawPageMisc();
    drawCursor();
    drawPageEnd();
  }

  /// force cursor coordinates to be in text
  final void normXY () nothrow @safe @nogc {
    gb.pos2xy(curpos, cx, cy);
  }

  /+
  /// this should reset text width iterator; tabsize > 0: process tabs as... well... tabs ;-)
  void textWidthReset (int tabsize) nothrow @trusted {}

  /// advance text width iterator, return current x position for drawing next char
  int textWidthAdvance (char ch) nothrow @trusted { return 0; }

  /// advance text width iterator, return current x position for drawing next char
  int textWidthAdvanceUtfuck (dchar ch) nothrow @trusted { return 0; }

  /// return position after last char, preferably without char spacing
  int textWidthOfsEndChar () nothrow @trusted { return 0; }

  /// finish text iterator, return position after last char
  int textWidthAdvanceFinish () nothrow @trusted { return 0; }
  +/

  ///
  final void makeCurXVisible () nothrow {
    // use "real" x coordinate to calculate x offset
    if (cx < 0) cx = 0;
    int rx;
    if (!inPixels) {
      int ry;
      gb.pos2xyVT(curpos, rx, ry);
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
  final int linelen (int lidx) nothrow @trusted @nogc {
    if (lidx < 0 || lidx >= gb.linecount) return 0;
    auto pos = gb.line2pos(lidx);
    auto ts = gb.textsize;
    if (pos > ts) pos = ts;
    int res = 0;
    if (!gb.utfuck) {
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
      gb.pos2xyVT(curpos, rx, ry);
      rx -= mXOfs;
    } else {
      gb.pos2xy(curpos, rx, ry);
      if (rx == 0) return 0-mXOfs;
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      textMeter.reset(visualtabs ? gb.tabsize : 0);
      scope(exit) textMeter.finish(); // just in case
      auto pos = gb.line2pos(ry);
      auto ts = gb.textsize;
      immutable bool ufuck = gb.utfuck;
      if (mSingleLine) {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos));
          }
          --rx;
          if (rx == 0) break;
        }
      } else {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          if (ch == '\n') break;
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos));
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
      gb.pos2xyVT(curpos, rx, ry);
      ry -= mTopLine;
      rx -= mXOfs;
      lcx = rx;
      lcy = ry;
    } else {
      gb.pos2xy(curpos, rx, ry);
      if (textMeter is null) assert(0, "you forgot to setup `textMeter` for EditorEngine");
      if (lineHeightPixels > 0) {
        lcy = (ry-mTopLine)*lineHeightPixels;
      } else {
        if (ry >= mTopLine && ry < mTopLine+linesPerWindow) {
          // don't update y offsets
          //lcy = 0;
          for (int ll = mTopLine; ll < ry; ++ll) lcy += gb.lidx2pixelh(ll, textMeter, &recode1b);
        } else {
          auto lmt = gb.lidx2pixelyh(mTopLine, textMeter, &recode1b);
          auto lmr = gb.lidx2pixelyh(ry, textMeter, &recode1b);
          lcy = lmr.y-lmt.y;
        }
      }
      if (rx == 0) { lcx = 0-mXOfs; return; }
      textMeter.reset(visualtabs ? gb.tabsize : 0);
      scope(exit) textMeter.finish(); // just in case
      auto pos = gb.line2pos(ry);
      auto ts = gb.textsize;
      immutable bool ufuck = gb.utfuck;
      if (mSingleLine) {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos));
          }
          --rx;
          if (rx == 0) break;
        }
      } else {
        while (pos < ts) {
          // advance one symbol
          char ch = gb[pos];
          if (ch == '\n') break;
          if (!ufuck || ch < 128) {
            textMeter.advance(cast(dchar)ch);
            ++pos;
          } else {
            textMeter.advance(dcharAtAdvance(pos));
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
      if (ry >= gb.linecount) { ty = gb.linecount; return; } // tx is zero here
      if (mx <= 0 && mXOfs == 0) return; // tx is zero here
      // ah, screw it! user should not call this very often, so i can stop care about speed.
      int visx = -mXOfs;
      auto pos = gb.line2pos(ry);
      auto ts = gb.textsize;
      int rx = 0;
      immutable bool ufuck = gb.utfuck;
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
        if (my >= 0 && my <= winh) {
          // don't update y offsets
          ry = mTopLine;
          int lcy = 0;
          while (lcy < my) {
            lcy += gb.lidx2pixelh(ry, textMeter, &recode1b);
            if (lcy > my) break;
            ++ry;
            if (lcy == my) break;
          }
        } else {
          auto ytop = gb.lidx2pixelyh(mTopLine, textMeter, &recode1b).y;
          ry = gb.pixely2lidx(ytop+my, textMeter, &recode1b);
        }
      }
      if (ry < 0) { ty = -1; return; } // tx is zero here
      if (ry >= gb.linecount) { ty = gb.linecount; return; } // tx is zero here
      ty = ry;
      if (mx <= 0 && mXOfs == 0) return; // tx is zero here
      // now the hard part
      textMeter.reset(visualtabs ? gb.tabsize : 0);
      scope(exit) textMeter.finish(); // just in case
      int visx = -mXOfs, prevx;
      auto pos = gb.line2pos(ry);
      auto ts = gb.textsize;
      int rx = 0;
      immutable bool ufuck = gb.utfuck;
      immutable bool sl = mSingleLine;
      while (pos < ts) {
        // advance one symbol
        char ch = gb[pos];
        if (!sl && ch == '\n') { tx = rx; return; } // done anyway
        prevx = visx;
        if (!ufuck || ch < 128) {
          visx = textMeter.advance(cast(dchar)ch)-mXOfs;
          ++pos;
        } else {
          visx = textMeter.advance(dcharAtAdvance(pos))-mXOfs;
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
    if (cy >= gb.linecount) cy = gb.linecount-1;
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
      if (cy >= gb.linecount) cy = gb.linecount-1;
      mTopLine = cy-linesPerWindow/2;
      if (mTopLine < 0) mTopLine = 0;
      if (mTopLine+linesPerWindow > gb.linecount) {
        mTopLine = gb.linecount-linesPerWindow;
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
    if (lidx < 0 || lidx >= gb.linecount) return;
    if (hl !is null) hl.lineChanged(lidx, updateDown);
    if (lidx < mTopLine) { if (updateDown) dirtyLines[] = true; return; }
    if (lidx >= mTopLine+linesPerWindow) return;
    immutable stl = lidx-mTopLine;
    assert(stl >= 0);
    if (stl < dirtyLines.length) {
      if (updateDown) {
        dirtyLines[stl..$] = true;
      } else {
        dirtyLines.ptr[stl] = true;
      }
    }
  }

  ///
  final void lineChangedByPos (int pos, bool updateDown) { return lineChanged(gb.pos2line(pos), updateDown); }

  ///
  final void markLinesDirty (int lidx, int count) nothrow {
    if (prevTopLine != mTopLine || prevXOfs != mXOfs) return; // we will refresh the whole page anyway
    if (count < 1 || lidx >= gb.linecount) return;
    if (count > gb.linecount) count = gb.linecount;
    if (lidx >= mTopLine+linesPerWindow) return;
    int le = lidx+count;
    if (le <= mTopLine) return;
    if (lidx < mTopLine) lidx = mTopLine;
    if (le > mTopLine+linesPerWindow) le = mTopLine+linesPerWindow;
    immutable stl = lidx-mTopLine;
    assert(stl >= 0);
    if (stl < dirtyLines.length) {
      auto el = le-mTopLine;
      if (el > dirtyLines.length) el = cast(int)dirtyLines.length;
      dirtyLines.ptr[stl..el] = true;
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
    int l0 = gb.pos2line(pos);
    int l1 = gb.pos2line(pos+len+1);
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
        ry = gb.pos2line(bend);
        bend = bstart;
        bstart = pos;
        lastBGEnd = false;
      } else {
        // move start
        ry = gb.pos2line(bstart);
        if (bstart == pos) return;
        bstart = pos;
        lastBGEnd = false;
      }
    } else if (pos > bend) {
      // move end
      if (bend == pos) return;
      ry = gb.pos2line(bend-1);
      bend = pos;
      lastBGEnd = true;
    } else if (pos >= bstart && pos < bend) {
      // shrink block
      if (lastBGEnd) {
        // from end
        if (bend == pos) return;
        ry = gb.pos2line(bend-1);
        bend = pos;
      } else {
        // from start
        if (bstart == pos) return;
        ry = gb.pos2line(bstart);
        bstart = pos;
      }
    }
    markLinesDirtySE(ry, cy);
  }

  ///
  bool undoGroupStart () {
    return (undo !is null ? undo.addGroupStart(this) : false);
  }

  ///
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
    pos = gb.line2pos(gb.pos2line(pos));
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
      auto olc = gb.linecount;
      if (!gb.remove(pos, count)) {
        if (undoOk) undo.popUndo(); // remove undo record
        return false;
      }
      txchanged = true;
      static if (movecursor != "none") gb.pos2xy(pos, cx, cy);
      wasDeleted(pos, count, delEols);
      lineChangedByPos(pos, (gb.linecount != olc));
    } else {
      static if (movecursor != "none") {
        int rx, ry;
        gb.pos2xy(curpos, rx, ry);
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
                auto newpos = gb.put(ipos, str[0..elp]);
                if (newpos < 0) { doRollback = true; break; }
                ipos = newpos;
                str = str[elp..$];
              } else {
                // insert newline
                auto newpos = gb.put(ipos, indentText);
                if (newpos < 0) { doRollback = true; break; }
                ipos = newpos;
                assert(str[0] == '\n');
                str = str[1..$];
              }
            }
            if (doRollback) {
              // operation failed, rollback it
              if (ipos > spos) gb.remove(spos, ipos-spos); // remove inserted text
              if (undoOk) undo.popUndo(); // remove undo record
              return false;
            }
            //if (ipos-spos != toinsert) { import core.stdc.stdio : stderr, fprintf; fprintf(stderr, "spos=%d; ipos=%d; ipos-spos=%d; toinsert=%d; nlc=%d; sl=%d; il=%d\n", spos, ipos, ipos-spos, toinsert, nlc, cast(int)str.length, cast(int)indentText.length); }
            assert(ipos-spos == toinsert);
                 static if (movecursor == "start") gb.pos2xy(spos, cx, cy);
            else static if (movecursor == "end") gb.pos2xy(ipos, cx, cy);
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
        auto newpos = gb.put(pos, str[]);
        if (newpos < 0) {
          // operation failed, rollback it
          if (undoOk) undo.popUndo(); // remove undo record
          return false;
        }
             static if (movecursor == "start") gb.pos2xy(pos, cx, cy);
        else static if (movecursor == "end") gb.pos2xy(newpos, cx, cy);
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
    // copy block data into temp buffer
    int blen = bend-bstart;
    char* btext = cast(char*)malloc(blen);
    if (btext is null) return false; // alas
    scope(exit) free(btext);
    foreach (int pp; bstart..bend) btext[pp-bstart] = gb[pp];
    fl.rawWriteExact(btext[0..blen]);
    return true;
  }

  ///
  bool doBlockRead (const(char)[] fname) { return doBlockRead(VFile(fname)); }

  ///
  bool doBlockRead (VFile fl) {
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
    import core.stdc.stdlib : malloc, free;
    if (mReadOnly) return false;
    killTextOnChar = false;
    if (!hasMarkedBlock) return true;
    // copy block data into temp buffer
    int blen = bend-bstart;
    char* btext = cast(char*)malloc(blen);
    if (btext is null) return false; // alas
    scope(exit) free(btext);
    foreach (int pp; bstart..bend) btext[pp-bstart] = gb[pp];
    return insertText!("start", false)(curpos, btext[0..blen]); // no indent
  }

  ///
  bool doBlockMove () {
    import core.stdc.stdlib : malloc, free;
    if (mReadOnly) return false;
    killTextOnChar = false;
    if (!hasMarkedBlock) return true;
    int pos = curpos;
    if (pos >= bstart && pos < bend) return false; // can't do this while we are inside the block
    // copy block data into temp buffer
    int blen = bend-bstart;
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
    if (!insertText!("start", false)(pos, btext[0..blen])) {
      // rollback
      if (undoOk) undo.popUndo();
      return false;
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
    if (!gb.utfuck) {
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
    if (!gb.utfuck) {
      deleteText!"start"(pos-1, 1);
    } else {
      if (gb[pos-1] < 128) { deleteText!"start"(pos-1, 1); return; }
      int rx, ry;
      gb.pos2xy(pos, rx, ry);
      if (rx == 0) return; // the thing that should not be
      int spos = gb.xy2pos(rx-1, ry);
      deleteText!"start"(spos, pos-spos);
    }
  }

  ///
  void doBackByIndent () {
    if (mReadOnly) return;
    int pos = curpos;
    int ls = gb.xy2pos(0, cy);
    if (pos == ls) { doDeleteWord(); return; }
    if (gb[pos-1] > ' ') { doDeleteWord(); return; }
    int rx, ry;
    gb.pos2xy(pos, rx, ry);
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
    int ls = gb.xy2pos(0, cy);
    int le;
    if (cy == gb.linecount-1) {
      le = gb.textsize;
    } else {
      le = gb.xy2pos(0, cy+1);
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
    if (ch > 127 && gb.utfuck) {
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
    if (gb.utfuck) {
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

  ///
  protected final bool xIndentLine (int lidx) {
    //TODO: rollback
    if (mReadOnly) return false;
    if (lidx < 0 || lidx >= gb.linecount) return false;
    auto pos = gb.xy2pos(0, lidx);
    auto epos = gb.xy2pos(0, lidx+1);
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
    int sy = gb.pos2line(bstart);
    int ey = gb.pos2line(bend-1);
    bool bsAtBOL = (bstart == gb.line2pos(sy));
    undoGroupStart();
    scope(exit) undoGroupEnd();
    foreach (int lidx; sy..ey+1) xIndentLine(lidx);
    if (bsAtBOL) bstart = gb.line2pos(sy); // line already marked as dirty
  }

  protected final bool xUnindentLine (int lidx) {
    if (mReadOnly) return false;
    if (lidx < 0 || lidx >= gb.linecount) return true;
    auto pos = gb.xy2pos(0, lidx);
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
    int sy = gb.pos2line(bstart);
    int ey = gb.pos2line(bend-1);
    undoGroupStart();
    scope(exit) undoGroupEnd();
    foreach (int lidx; sy..ey+1) xUnindentLine(lidx);
  }

  // ////////////////////////////////////////////////////////////////////// //
  // actions

  ///
  final bool pushUndoCurPos () nothrow @nogc {
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
    gb.pos2xy(stpos, cx, cy);
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
    gb.pos2xy(epos, cx, cy);
    growBlockMark();
  }

  ///
  void doTextTop (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (gb.mLineCount < 2) return;
    killTextOnChar = false;
    if (mTopLine == 0 && cy == 0) return;
    pushUndoCurPos();
    mTopLine = cy = 0;
    growBlockMark();
  }

  ///
  void doTextBottom (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (gb.mLineCount < 2) return;
    killTextOnChar = false;
    if (cy >= gb.linecount-1) return;
    pushUndoCurPos();
    cy = gb.linecount-1;
    growBlockMark();
  }

  ///
  void doPageTop (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (gb.mLineCount < 2) return;
    killTextOnChar = false;
    if (cy == mTopLine) return;
    pushUndoCurPos();
    cy = mTopLine;
    growBlockMark();
  }

  ///
  void doPageBottom (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    if (gb.mLineCount < 2) return;
    killTextOnChar = false;
    int ny = mTopLine+linesPerWindow-1;
    if (ny >= gb.linecount) ny = gb.linecount-1;
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
    if (mTopLine+linesPerWindow < gb.linecount) {
      killTextOnChar = false;
      pushUndoCurPos();
      ++mTopLine;
      ++cy;
    } else if (cy < gb.linecount-1) {
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
    if (cy < gb.linecount-1) {
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
    gb.pos2xy(curpos, rx, ry);
    if (cx > rx) cx = rx;
    if (cx > 0) {
      pushUndoCurPos();
      --cx;
    } else if (cy > 0) {
      // to prev line
      pushUndoCurPos();
      gb.pos2xy(gb.xy2pos(0, cy)-1, cx, cy);
    }
    growBlockMark();
  }

  ///
  void doRight (bool domark=false) {
    mixin(SetupShiftMarkingMixin);
    int rx, ry;
    killTextOnChar = false;
    gb.pos2xy(gb.xy2pos(cx+1, cy), rx, ry);
    if (cx+1 > rx) {
      if (cy < gb.linecount-1) {
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
    if (linesPerWindow < 2 || gb.mLineCount < 2) return;
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
    if (linesPerWindow < 2 || gb.mLineCount < 2) return;
    killTextOnChar = false;
    int ntl = mTopLine+(linesPerWindow-1);
    int ncy = cy+(linesPerWindow-1);
    if (ntl+linesPerWindow >= gb.linecount) ntl = gb.linecount-linesPerWindow;
    if (ncy >= gb.linecount) ncy = gb.linecount-1;
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
      auto pos = gb.xy2pos(0, cy);
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
    auto ep = (cy >= gb.linecount-1 ? gb.textsize : gb.lineend(cy));
    gb.pos2xy(ep, rx, ry);
    if (rx != cx || ry != cy) {
      pushUndoCurPos();
      cx = rx;
      cy = ry;
    }
    growBlockMark();
  }

  ///
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
      markLinesDirtySE(gb.pos2line(bstart), gb.pos2line(bend-1));
    }
    bstart = bend = -1;
    markingBlock = false;
  }

  ///
  void doBlockMark () {
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
      dirtyLines[] = true; //FIXME: optimize
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
    dirtyLines[] = true; //FIXME: optimize
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
    dirtyLines[] = true; //FIXME: optimize
  }

protected:
  final void ubTextRemove (int pos, int len) {
    if (mReadOnly) return;
    killTextOnChar = false;
    int nlc = (!mSingleLine ? gb.countEolsInRange(pos, len) : 0);
    bookmarkDeletionFix(pos, len, nlc);
    lineChangedByPos(pos, (nlc > 0));
    gb.remove(pos, len);
  }

  final void ubTextInsert (int pos, const(char)[] str) {
    if (mReadOnly) return;
    killTextOnChar = false;
    if (str.length == 0) return;
    int nlc = (!mSingleLine ? gb.countEols(str) : 0);
    bookmarkInsertionFix(pos, pos+cast(int)str.length, nlc);
    if (gb.put(pos, str) >= 0) lineChangedByPos(pos, (nlc > 0));
  }

  static struct TextRange {
  private:
    EditorEngine ed;
    int pos;
    int left; // chars left, including front
    char frontch = 0;
  nothrow @safe @nogc:
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
    @property bool empty () const pure { pragma(inline, true); return (left <= 0); }
    @property char front () const pure { pragma(inline, true); return frontch; }
    void popFront () {
      if (ed is null || left < 2) { left = 0; frontch = 0; return; }
      --left;
      if (pos >= ed.gb.textsize) { left = 0; frontch = 0; return; }
      frontch = ed.gb[pos++];
    }
    auto save () pure { pragma(inline, true); return TextRange(ed, pos, left, frontch); }
    @property usize length () const pure { pragma(inline, true); return (left > 0 ? left : 0); }
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
  final TextRange opSlice (usize lo, usize hi) nothrow @nogc { return TextRange(this, lo, hi); }
  final TextRange opSlice () nothrow @nogc { return TextRange(this, 0, gb.textsize); } /// ditto
  final int opDollar () nothrow @nogc { return gb.textsize; } ///

  ///
  final TextRange markedBlockRange () nothrow @nogc {
    if (!hasMarkedBlock) return TextRange.init;
    return TextRange(this, bstart, bend);
  }

static:
  ///
  bool isWordChar (char ch) pure nothrow @safe @nogc {
    return (ch.isalnum || ch == '_' || ch > 127);
  }
}
