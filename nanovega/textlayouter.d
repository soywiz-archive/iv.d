/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.nanovega.textlayouter is aliced;

import arsd.image;

import iv.cmdcon;
import iv.meta;
import iv.nanovega.nanovega;
import iv.utfutil;
import iv.vfs;


version(laytest) import iv.encoding;
version(Windows) {
  private int lrintf (float f) { pragma(inline, true); return cast(int)(f+0.5); }
} else {
  import core.stdc.math : lrintf;
}


// ////////////////////////////////////////////////////////////////////////// //
/// non-text object (image, for example); can be inserted in text.
/// all object's properties should be constant
public abstract class LayObject {
  abstract int width (); /// object width
  abstract int spacewidth (); /// space width for this object
  abstract int height (); /// object height
  abstract int ascent (); /// should be positive
  abstract int descent (); /// should be negative
  abstract bool canbreak (); /// can we do line break after this object?
  abstract bool spaced (); /// should we automatically add space after this object?
  /// y is at baseline
  abstract void draw (NVGContext ctx, float x, float y);
}


// ////////////////////////////////////////////////////////////////////////// //
/** This object is used to get various text dimensions.
 *
 * We need to have such fonts in stash:
 *   text -- normal
 *   texti -- italic
 *   textb -- bold
 *   textz -- italic and bold
 *   mono -- normal
 *   monoi -- italic
 *   monob -- bold
 *   monoz -- italic and bold
 */
public final class LayFontStash {
public:
  FONScontext* fs;

private:
  char[64] lastFontFace;
  int lastFFlen;
  int lastFFid = -1;

private:
  bool killFontStash;
  bool fontWasSet; // to ensure that first call to `setFont()` will do it's work
  LayFontStyle lastStyle;

public:
  /// create new fontstash
  /// if `nvg` is not null, use its fontstash.
  /// WARNING! this object SHOULD NOT outlive `nvg`!
  this (NVGContext nvg=null) {
    if (nvg !is null && nvg.fs !is null) {
      killFontStash = false;
      fs = nvg.fs;
      //{ import core.stdc.stdio; printf("*** reusing font stash!\n"); }
    } else {
      FONSparams fontParams;
      // image size doesn't matter, as we won't create font bitmaps here anyway (we only interested in dimensions)
      fontParams.width = 32;//1024/*NVG_INIT_FONTIMAGE_SIZE*/;
      fontParams.height = 32;//1024/*NVG_INIT_FONTIMAGE_SIZE*/;
      fontParams.flags = FONS_ZERO_TOPLEFT;
      fs = fonsCreateInternal(&fontParams);
      if (fs is null) throw new Exception("error creating font stash");
      killFontStash = true;
      //fs.fonsResetAtlas(1024, 1024);
      // image size doesn't matter, as we won't create font bitmaps here anyway (we only interested in dimensions)
      //fs.fonsResetAtlas(32, 32);
      fonsSetSpacing(fs, 0);
      fonsSetBlur(fs, 0);
      fonsSetAlign(fs, NVGTextAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Baseline));
    }
  }

  ///
  ~this () nothrow @nogc { freeFontStash(); }

  ///
  @property ownsFontContext () const pure nothrow @safe @nogc => killFontStash;

  private void freeFontStash () nothrow @nogc {
    if (killFontStash && fs !is null) fs.fonsDeleteInternal();
    killFontStash = false;
    fs = null;
  }

  /// add new font to stash
  void addFont(T : const(char)[], TP : const(char)[]) (T name, TP path) {
    static if (is(T == typeof(null))) {
      throw new Exception("invalid font face name");
    } else {
      if (name.length == 0) throw new Exception("invalid font face name");
      //if (name in fontfaces) throw new Exception("duplicate font '"~name.idup~"'");
      int fid = fs.fonsAddFont(name, path);
      if (fid == FONS_INVALID) throw new Exception("font '"~name~"' is not found at '"~path.idup~"'");
      /*
      static if (is(T == string)) {
        fontfaces[name] = fid;
        fontfaceids[fid] = name;
      } else {
        string n = name.idup;
        fontfaces[n] = fid;
        fontfaceids[fid] = n;
      }
      */
      // reset font cache
      lastFFlen = 0;
      lastFFid = -1;
      //{ import core.stdc.stdio; printf("loaded font: [%.*s] [%.*s]\n", cast(uint)name.length, name.ptr, cast(uint)path.length, path.ptr); }
    }
  }

  /// returns "font id" which can be used in `fontFace()`
  @property int fontFaceId (const(char)[] name) nothrow @safe @nogc {
    if (lastFFlen == name.length && strEquCI(lastFontFace[0..lastFFlen], name)) {
      assert(lastFFid != -1);
    } else {
      lastFFid = fonsGetFontByName(fs, name);
      if (lastFFid != FONS_INVALID && name.length <= lastFontFace.length) {
        lastFFlen = cast(int)name.length;
        lastFontFace[0..lastFFlen] = name[];
      } else {
        lastFFlen = 0;
      }
    }
    return lastFFid;
  }

  /// returns font name for the given id (or `null`)
  @property const(char)[] fontFace (int fid) nothrow @safe @nogc {
    if (fid < 0) return null;
    if (fid == lastFFid && lastFFlen > 0) return lastFontFace[0..lastFFlen];
    auto res = fonsGetNameByIndex(fs, fid);
    if (res.length > 0 && res.length <= lastFontFace.length) {
      lastFFlen = cast(int)res.length;
      lastFontFace[0..lastFFlen] = res[];
      lastFFid = fid;
    }
    return res;
  }

  /// set current font according to the given style
  void setFont() (in auto ref LayFontStyle style) nothrow @safe @nogc {
    int fsz = style.fontsize;
    if (fsz < 1) fsz = 1;
    if (!fontWasSet || fsz != lastStyle.fontsize || style.fontface != lastStyle.fontface) {
      if (style.fontface != lastStyle.fontface) fonsSetFont(fs, style.fontface);
      if (fsz != lastStyle.fontsize) fonsSetSize(fs, fsz);
      lastStyle = style;
      lastStyle.fontsize = fsz;
    }
  }

  /// calculate text width
  int textWidth(T) (const(T)[] str) nothrow @safe @nogc if (isAnyCharType!T) {
    import std.algorithm : max;
    float[4] b = void;
    float adv = fs.fonsTextBounds(0, 0, str, b[]);
    float w = b[2]-b[0];
    return lrintf(max(adv, w));
  }

  /// calculate spaces width
  int spacesWidth (int count) nothrow @safe @nogc {
    if (count < 1) return 0;
    auto it = FonsTextBoundsIterator(fs, 0, 0);
    it.put(' ');
    return lrintf(it.advance*count);
  }

  /// this returns "width", "width with trailing whitespace", and "width with trailing hypen"
  /// all `*` args can be omited
  void textWidth2(T) (const(T)[] str, int* w=null, int* wsp=null, int* whyph=null) nothrow @safe @nogc if (isAnyCharType!T) {
    import std.algorithm : max;
    if (w is null && wsp is null && whyph is null) return;
    float minx, maxx;
    auto it = FonsTextBoundsIterator(fs, 0, 0);
    it.put(str);
    if (w !is null) {
      it.getHBounds(minx, maxx);
      *w = lrintf(max(it.advance, maxx-minx));
    }
    if (wsp !is null && whyph is null) {
      it.put(" ");
      it.getHBounds(minx, maxx);
      *wsp = lrintf(max(it.advance, maxx-minx));
    } else if (wsp is null && whyph !is null) {
      it.put(cast(dchar)45);
      it.getHBounds(minx, maxx);
      *whyph = lrintf(max(it.advance, maxx-minx));
    } else if (wsp !is null && whyph !is null) {
      auto sit = it;
      it.put(" ");
      it.getHBounds(minx, maxx);
      *wsp = lrintf(max(it.advance, maxx-minx));
      sit.put(cast(dchar)45);
      sit.getHBounds(minx, maxx);
      *whyph = lrintf(max(sit.advance, maxx-minx));
    }
  }

  /// calculate text height
  int textHeight () nothrow @trusted @nogc {
    // use line bounds for height
    float y0 = void, y1 = void;
    fs.fonsLineBounds(0, &y0, &y1);
    return lrintf(y1-y0);
  }

  /// calculate text metrics: ascent, descent, line height
  /// any argument can be `null`
  void textMetrics (int* asc, int* desc, int* lineh) nothrow @trusted @nogc {
    float a = void, d = void, h = void;
    fs.fonsVertMetrics(&a, &d, &h);
    if (asc !is null) *asc = lrintf(a);
    if (desc !is null) *desc = lrintf(d);
    if (lineh !is null) *lineh = lrintf(h);
  }

static private:
  bool strEquCI (const(char)[] s0, const(char)[] s1) nothrow @trusted @nogc {
    if (s0.length != s1.length) return false;
    const(char)* sp0 = s0.ptr;
    const(char)* sp1 = s1.ptr;
    foreach (; 0..s0.length) {
      char c0 = *sp0++;
      char c1 = *sp1++;
      if (c0 != c1) {
        if (c0 >= 'A' && c0 <= 'Z') c0 += 32; // poor man tolower
        if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man tolower
        if (c0 != c1) return false;
      }
    }
    return true;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// generic text style
/// note that you must manually fix `fontface` after changing attrs. sorry.
public align(1) struct LayFontStyle {
align(1):
  ///
  enum Flag : uint {
    Italic    = 1<<0, ///
    Bold      = 1<<1, ///
    Strike    = 1<<2, ///
    Underline = 1<<3, ///
    Overline  = 1<<4, ///
    Monospace = 1<<6, ///
    Href      = 1<<7, /// this is cross-reference (not actually a style flag, but it somewhat fits here)
    DontResetFont = 1U<<31, /// Don't reset font on style change
  }
  enum StyleMask = Flag.Italic|Flag.Bold|Flag.Strike|Flag.Underline|Flag.Overline|Flag.Monospace;
  uint flags; /// see above
  int fontface = -1; /// i can't use strings here, as this struct inside LayWord will not be GC-scanned
  int fontsize; ///
  uint color = 0xff000000; /// AABBGGRR; AA usually ignored by renderer, but i'll keep it anyway
  uint bgcolor = 0xff000000; /// AABBGGRR; AA usually ignored by renderer, but i'll keep it anyway
  string toString () const {
    import std.format : format;
    string res = "font:%s;size:%s;color:0x%08X".format(fontface, fontsize, color);
    if (flags&Flag.Italic) res ~= ";italic";
    if (flags&Flag.Bold) res ~= ";bold";
    if (flags&Flag.Strike) res ~= ";strike";
    if (flags&Flag.Underline) res ~= ";under";
    if (flags&Flag.Overline) res ~= ";over";
    if (flags&Flag.Monospace) res ~= ";mono";
    return res;
  }
  // this generates getter and setter for each `Flag`
  mixin((){
    auto res = CTFECharBuffer!false(3000);
    foreach (immutable string s; __traits(allMembers, Flag)) {
      // getter
      res.put("@property bool ");
      res.putStrLoCasedFirst(s);
      res.put(" () const pure nothrow @safe @nogc { pragma(inline, true); return ((flags&Flag."~s~") != 0); }\n");
      // setter
      res.put("@property void ");
      res.putStrLoCasedFirst(s);
      res.put(" (bool v) ");
      static if ((__traits(getMember, Flag, s)&StyleMask) == 0) res.put("pure ");
      res.put("nothrow @safe @nogc { pragma(inline, true); ");
      static if (__traits(getMember, Flag, s)&StyleMask) {
        res.put("if ((flags&Flag.DontResetFont) == 0 && (!!(flags&Flag.");
        res.put(s);
        res.put(")) != v) fontface = -1; ");
      }
      res.put("if (v) flags |= Flag.");
      res.put(s);
      res.put("; else flags &= ~Flag.");
      res.put(s);
      res.put("; ");
      static if (__traits(getMember, Flag, s)&StyleMask) {
        res.put("if (fontface == -1 && layFixFontDG !is null) layFixFontDG(this);");
      }
      res.put("}\n");
    }
    return res.asString; // it is safe to cast here
  }());
  /// this doesn't touch `Flag.DontResetFont`
  void resetAttrs () nothrow @safe @nogc {
    if ((flags&Flag.DontResetFont) == 0) {
      if (flags&StyleMask) fontface = -1;
    }
    flags = 0;
    if (fontface == -1 && layFixFontDG !is null) layFixFontDG(this);
  }
  ///
  bool opEquals() (in auto ref LayFontStyle s) const pure nothrow @safe @nogc { pragma(inline, true); return (flags == s.flags && fontface == s.fontface && color == s.color && bgcolor == s.bgcolor && fontsize == s.fontsize); }
}


// ////////////////////////////////////////////////////////////////////////// //
/// line align style
public align(1) struct LayLineStyle {
align(1):
  ///
  enum Justify : ubyte {
    Left, ///
    Right, ///
    Center, ///
    Justify, ///
  }
  Justify mode = Justify.Left; ///
  short lpad, rpad, tpad, bpad; /// paddings; left and right can be negative
  ubyte paraIndent; /// in spaces
  string toString () const {
    import std.format : format;
    string res;
    final switch (mode) {
      case Justify.Left: res = "left"; break;
      case Justify.Right: res = "right"; break;
      case Justify.Center: res = "center"; break;
      case Justify.Justify: res = "justify"; break;
    }
    if (lpad) res ~= ";lpad:%s".format(lpad);
    if (rpad) res ~= ";rpad:%s".format(rpad);
    if (tpad) res ~= ";tpad:%s".format(tpad);
    if (bpad) res ~= ";bpad:%s".format(bpad);
    return res;
  }
  // this generates getter and setter for each `Justify` mode
  mixin((){
    auto res = CTFECharBuffer!false(1024); // currently it is ~900
    foreach (immutable string s; __traits(allMembers, Justify)) {
      // getter
      res.put("@property bool ");
      res.putStrLoCasedFirst(s);
      res.put(" () const pure nothrow @safe @nogc { pragma(inline, true); return (mode == Justify.");
      res.put(s);
      res.put("); }\n");
      // setter (in the form of `setLeft`, etc.)
      res.put("ref LayLineStyle set");
      res.put(s);
      res.put(" () pure nothrow @safe @nogc { mode = Justify.");
      res.put(s);
      res.put("; return this; }\n");
    }
    return res.asString;
  }());
  //bool opEquals() (in auto ref LayLineStyle s) const pure nothrow @safe @nogc { pragma(inline, true); return (mode == s.mode && lpad == s.lpad); }
  @property pure nothrow @safe @nogc {
    int leftpad () const { pragma(inline, true); return lpad; }
    void leftpad (int v) { pragma(inline, true); lpad = (v < short.min ? short.min : v > short.max ? short.max : cast(short)v); }
    int rightpad () const { pragma(inline, true); return rpad; }
    void rightpad (int v) { pragma(inline, true); rpad = (v < short.min ? short.min : v > short.max ? short.max : cast(short)v); }
    int toppad () const { pragma(inline, true); return tpad; }
    void toppad (int v) { pragma(inline, true); tpad = (v < 0 ? 0 : v > short.max ? short.max : cast(short)v); }
    int bottompad () const { pragma(inline, true); return bpad; }
    void bottompad (int v) { pragma(inline, true); bpad = (v < 0 ? 0 : v > short.max ? short.max : cast(short)v); }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// layouted text word
public align(1) struct LayWord {
align(1):
  ///
  static align(1) struct Props {
  align(1):
    /// note that if word is softhyphen candidate, i have hyphen mark at [wend].
    /// if props.hyphen is set, wend is including that mark, otherwise it isn't.
    enum Flag : uint {
      CanBreak  = 1<<0, /// can i break line at this word?
      Spaced    = 1<<1, /// should this word be whitespaced at the end?
      Hypen     = 1<<2, /// if i'll break at this word, should i add hyphen mark?
      LineEnd   = 1<<3, /// this word ends current line
      ParaEnd   = 1<<4, /// this word ends current paragraph (and, implicitly, line)
      Object    = 1<<5, /// wstart is actually object index in object array
      Expander  = 1<<6, /// this is special "expander" word
      HardSpace = 1<<7, /// "hard space": nonbreakable space with fixed size
    }
    ubyte flags; /// see above
  @property pure nothrow @safe @nogc:
    bool canbreak () const { pragma(inline, true); return ((flags&Flag.CanBreak) != 0); } ///
    void canbreak (bool v) { pragma(inline, true); if (v) flags |= Flag.CanBreak; else flags &= ~Flag.CanBreak; } ///
    bool spaced () const { pragma(inline, true); return ((flags&Flag.Spaced) != 0); } ///
    void spaced (bool v) { pragma(inline, true); if (v) flags |= Flag.Spaced; else flags &= ~Flag.Spaced; } ///
    bool hyphen () const { pragma(inline, true); return ((flags&Flag.Hypen) != 0); } ///
    void hyphen (bool v) { pragma(inline, true); if (v) flags |= Flag.Hypen; else flags &= ~Flag.Hypen; } ///
    bool lineend () const { pragma(inline, true); return ((flags&Flag.LineEnd) != 0); } ///
    void lineend (bool v) { pragma(inline, true); if (v) flags |= Flag.LineEnd; else flags &= ~Flag.LineEnd; } ///
    bool paraend () const { pragma(inline, true); return ((flags&Flag.ParaEnd) != 0); } ///
    void paraend (bool v) { pragma(inline, true); if (v) flags |= Flag.ParaEnd; else flags &= ~Flag.ParaEnd; } ///
    bool someend () const { pragma(inline, true); return ((flags&(Flag.ParaEnd|Flag.LineEnd)) != 0); } ///
    bool object () const { pragma(inline, true); return ((flags&Flag.Object) != 0); } ///
    void object (bool v) { pragma(inline, true); if (v) flags |= Flag.Object; else flags &= ~Flag.Object; } ///
    bool expander () const { pragma(inline, true); return ((flags&Flag.Expander) != 0); } ///
    void expander (bool v) { pragma(inline, true); if (v) flags |= Flag.Expander; else flags &= ~Flag.Expander; } ///
    bool hardspace () const { pragma(inline, true); return ((flags&Flag.HardSpace) != 0); } ///
    void hardspace (bool v) { pragma(inline, true); if (v) flags |= Flag.HardSpace; else flags &= ~Flag.HardSpace; } ///
  }
  uint wstart, wend; /// in LayText text buffer
  LayFontStyle style; /// font style
  uint wordNum; /// word number (index in LayText word array)
  Props propsOrig; /// original properties, used for relayouting
  // calculated values
  Props props; /// effective props after layouting
  short x; /// horizontal word position in line
  short h; /// word height (full)
  short asc; /// ascent (positive)
  short desc; /// descent (negative)
  short w; /// word width, without hyphen and spacing
  short wsp; /// word width with spacing (i.e. with space added at the end)
  short whyph; /// word width with hyphen (i.e. with hyphen mark added at the end)
  /// word width (with hypen mark, if necessary)
  @property short width () const pure nothrow @safe @nogc => (props.hyphen ? whyph : w);
  /// width with spacing/hyphen
  @property short fullwidth () const pure nothrow @safe @nogc => (props.hyphen ? whyph : props.spaced ? wsp : w);
  /// space width based on original props
  @property short spacewidth () const pure nothrow @safe @nogc => cast(short)(propsOrig.spaced ? wsp-w : 0);
  //FIXME: find better place for this! keep that in separate pool, or something, and look there with word index
  LayLineStyle just; ///
  short paraPad; /// to not recalcuate it on each relayouting; set to -1 to recalculate ;-)
  /// returns `-1` if this is not an object
  @property int objectIdx () const pure nothrow @safe @nogc => (propsOrig.object ? wstart : -1);
  @property bool expander () const pure nothrow @safe @nogc => propsOrig.expander;
  @property bool hardspace () const pure nothrow @safe @nogc => propsOrig.hardspace;
}


// ////////////////////////////////////////////////////////////////////////// //
/// layouted text line
public struct LayLine {
  uint wstart, wend; /// indicies in word array
  LayLineStyle just; /// line style
  // calculated properties
  int x, y, w; /// starting x and y positions, width
  // on finish, layouter will calculate minimal ('cause it is negative) descent
  int h, desc; /// height, descent (negative)
  @property int wordCount () const pure nothrow @safe @nogc { pragma(inline, true); return cast(int)(wend-wstart); } ///
}


// ////////////////////////////////////////////////////////////////////////// //
public void delegate (ref LayFontStyle st) nothrow @safe @nogc layFixFontDG; /// you can set this delegate, and it will be called if fontstyle's fontface is -1; it should set it to proper font id

public alias LayTextC = LayTextImpl!char; ///
public alias LayTextW = LayTextImpl!wchar; ///
public alias LayTextD = LayTextImpl!dchar; ///

// layouted text
public final class LayTextImpl(TBT=char) if (isAnyCharType!TBT) {
public:
  alias CharType = TBT; ///

  // special control characters
  enum dchar EndLineCh = 0x2028; // 0x0085 is treated like whitespace
  enum dchar EndParaCh = 0x2029;
  enum dchar NonBreakingSpaceCh = 0xa0;
  enum dchar SoftHyphenCh = 0xad;

private:
  void ensurePool(ubyte pow2, bool clear, T) (uint want, ref T* ptr, ref uint used, ref uint alloced) nothrow @nogc {
    if (want == 0) return;
    static assert(pow2 < 24, "wtf?!");
    uint cursz = used*cast(uint)T.sizeof;
    if (cursz >= int.max/2) assert(0, "pool overflow");
    auto lsz = cast(ulong)want*T.sizeof;
    if (lsz >= int.max/2 || lsz+cursz >= int.max/2) assert(0, "pool overflow");
    want = cast(uint)lsz;
    uint cural = alloced*cast(uint)T.sizeof;
    if (cursz+want > cural) {
      import core.stdc.stdlib : realloc;
      // grow it
      uint newsz = ((cursz+want)|((1<<pow2)-1))+1;
      if (newsz >= int.max/2) assert(0, "pool overflow");
      auto np = cast(T*)realloc(ptr, newsz);
      if (np is null) assert(0, "out of memory for pool");
      static if (clear) {
        import core.stdc.string : memset;
        memset(np+used, 0, newsz-cursz);
      }
      ptr = np;
      alloced = newsz/cast(uint)T.sizeof;
    }
  }

  CharType* ltext;
  uint charsUsed, charsAllocated;

  static char[] utfEncode (char[] buf, dchar ch) nothrow @trusted @nogc {
    if (buf.length < 4) assert(0, "please provide at least 4-char buffer");
    if (!Utf8Decoder.isValidDC(ch)) ch = Utf8Decoder.replacement;
    if (ch <= 0x7F) {
      buf.ptr[0] = cast(char)(ch&0xff);
      return buf.ptr[0..1];
    }
    if (ch <= 0x7FF) {
      buf.ptr[0] = cast(char)(0xC0|(ch>>6));
      buf.ptr[1] = cast(char)(0x80|(ch&0x3F));
      return buf.ptr[0..2];
    }
    if (ch <= 0xFFFF) {
      buf.ptr[0] = cast(char)(0xE0|(ch>>12));
      buf.ptr[1] = cast(char)(0x80|((ch>>6)&0x3F));
      buf.ptr[2] = cast(char)(0x80|(ch&0x3F));
      return buf.ptr[0..3];
    }
    if (ch <= 0x10FFFF) {
      buf.ptr[0] = cast(char)(0xF0|(ch>>18));
      buf.ptr[1] = cast(char)(0x80|((ch>>12)&0x3F));
      buf.ptr[2] = cast(char)(0x80|((ch>>6)&0x3F));
      buf.ptr[3] = cast(char)(0x80|(ch&0x3F));
      return buf.ptr[0..4];
    }
    assert(0, "wtf?!");
  }

  static if (is(CharType == char)) {
    void putChars (const(char)[] str...) nothrow @nogc {
      import core.stdc.string : memcpy;
      if (str.length == 0) return;
      if (str.length >= int.max/4) assert(0, "string too long");
      ensurePool!(16, false)(cast(uint)str.length, ltext, charsUsed, charsAllocated);
      memcpy(ltext+charsUsed, str.ptr, cast(uint)str.length);
      charsUsed += cast(uint)str.length;
    }
    void putChars(XCT) (const(XCT)[] str...) nothrow @nogc if (isWideCharType!XCT) {
      import core.stdc.string : memcpy;
      //if (str.length >= int.max/2) throw new Exception("string too long");
      char[4] buf = void;
      foreach (XCT ch; str[]) {
        auto xbuf = utfEncode(buf[], cast(dchar)ch);
        uint len = cast(uint)xbuf.length;
        ensurePool!(16, false)(len, ltext, charsUsed, charsAllocated);
        memcpy(ltext+charsUsed, xbuf.ptr, len);
        charsUsed += len;
      }
    }
  } else {
    void putChars (const(char)[] str...) nothrow @nogc {
      import core.stdc.string : memcpy;
      if (str.length == 0) return;
      if (str.length >= int.max/4/dchar.sizeof) assert(0, "string too long");
      ensurePool!(16, false)(cast(uint)str.length, ltext, charsUsed, charsAllocated);
      CharType* dp = ltext+charsUsed;
      foreach (char xch; str) *dp++ = cast(CharType)xch;
      charsUsed += cast(uint)str.length;
    }
    void putChars(XCT) (const(XCT)[] str...) nothrow @nogc if (isWideCharType!XCT) {
      import core.stdc.string : memcpy;
      if (str.length == 0) return;
      if (str.length >= int.max/4/dchar.sizeof) assert(0, "string too long");
      ensurePool!(16, false)(cast(uint)str.length, ltext, charsUsed, charsAllocated);
      static if (is(XCT == CharType)) {
        memcpy(ltext+charsUsed, str.ptr, cast(uint)str.length*dchar.sizeof);
      } else {
        CharType* dp = ltext+charsUsed;
        foreach (XCT xch; str) {
          static if (is(CharType == wchar)) {
            *dp++ = cast(CharType)(xch > wchar.max ? '?' : xch);
          } else {
            *dp++ = cast(CharType)xch;
          }
        }
      }
      charsUsed += cast(uint)str.length;
    }
  }

  LayWord* words;
  uint wordsUsed, wordsAllocated;

  LayWord* allocWord(bool clear) () nothrow @nogc {
    ensurePool!(16, true)(1, words, wordsUsed, wordsAllocated);
    auto res = words+wordsUsed;
    static if (clear) {
      import core.stdc.string : memset;
      memset(res, 0, (*res).sizeof);
    }
    res.wordNum = wordsUsed++;
    //res.userTag = wordTag;
    return res;
  }

  LayLine* lines;
  uint linesUsed, linesAllocated;

  LayLine* allocLine(bool clear=false) () nothrow @nogc {
    ensurePool!(16, true)(1, lines, linesUsed, linesAllocated);
    static if (clear) {
      import core.stdc.string : memset;
      auto res = lines+(linesUsed++);
      memset(res, 0, (*res).sizeof);
      return res;
    } else {
      return lines+(linesUsed++);
    }
  }

  LayLine* lastLine () nothrow @nogc => (linesUsed > 0 ? lines+linesUsed-1 : null);

  bool lastLineHasWords () nothrow @nogc => (linesUsed > 0 ? (lines[linesUsed-1].wend > lines[linesUsed-1].wstart) : false);

  // should not be called when there are no lines, or no words in last line
  LayWord* lastLineLastWord () nothrow @nogc => words+lastLine.wend-1;

  static struct StyleStackItem {
    LayFontStyle fs;
    LayLineStyle ls;
  }
  StyleStackItem* styleStack;
  uint ststackUsed, ststackAllocated;

private:
  bool firstParaLine = true;
  uint lastWordStart; // in fulltext
  uint firstWordNotFlushed;

  @property bool hasWordChars () const pure nothrow @safe @nogc { pragma(inline, true); return (lastWordStart < charsUsed); }

private:
  // current attributes
  LayLineStyle just; // for current paragraph
  LayFontStyle style;
  // user can change this alot, so don't apply that immediately
  LayFontStyle newStyle;
  LayLineStyle newJust;

private:
  Utf8Decoder dec;
  bool lastWasUtf;
  bool lastWasSoftHypen;
  int maxWidth; // maximum text width
  LayFontStash laf;

private:
  int mTextHeight = 0; // total text height
  int mTextWidth = 0; // maximum text width

public:
  // compare function should return (roughly): key-l
  alias CmpFn = int delegate (LayLine* l) nothrow @safe @nogc;

  /// find line using binary search and predicate
  /// returns line number or -1
  int findLineBinary (scope CmpFn cmpfn) nothrow @trusted @nogc {
    if (linesUsed == 0) return -1;
    int bot = 0, i = cast(int)linesUsed-1;
    while (bot != i) {
      int mid = i-(i-bot)/2;
      int cmp = cmpfn(lines+mid);
           if (cmp < 0) i = mid-1;
      else if (cmp > 0) bot = mid;
      else return mid;
    }
    return (cmpfn(lines+i) == 0 ? i : -1);
  }

private:
  LayObject[] mObjects; /// all known object; DON'T MODIFY!

public:
  ///
  this (LayFontStash alaf, int awidth) nothrow @trusted @nogc {
    if (alaf is null) assert(0, "no layout fonts");
    if (awidth < 1) awidth = 1;
    laf = alaf;
    maxWidth = awidth;
    if (newStyle.fontface == -1 && layFixFontDG !is null) layFixFontDG(newStyle);
    if (newStyle.fontsize == 0) newStyle.fontsize = 16;
    style = newStyle;
  }

  ~this () nothrow @trusted @nogc { freeMemory(); }

  void freeMemory () nothrow @trusted @nogc {
    import core.stdc.stdlib : free;
    if (lines !is null) { free(lines); lines = null; }
    if (words !is null) { free(words); words = null; }
    if (ltext !is null) { free(ltext); ltext = null; }
    if (styleStack !is null) { free(styleStack); styleStack = null; }
    wordsUsed = wordsAllocated = linesUsed = linesAllocated = charsUsed = charsAllocated = ststackUsed = ststackAllocated = 0;
    lastWasSoftHypen = false;
  }

  /// wipe all text and stacks, but don't deallocate memory
  /// if `killObjects` is `true`, call `delete` on each object
  void wipeAll (bool killObjects=false) nothrow @trusted {
    wordsUsed = linesUsed = charsUsed = ststackUsed = 0;
    lastWasSoftHypen = false;
    lastWasUtf = false;
    dec.reset;
    mTextHeight = mTextWidth = 0;
    if (mObjects.length) {
      if (killObjects) foreach (ref obj; mObjects) delete obj;
      mObjects.length = 0;
      mObjects.assumeSafeAppend;
    }
    style = newStyle;
    just = newJust;
    firstParaLine = true;
    lastWordStart = 0;
    firstWordNotFlushed = 0;
  }

  /// get object with the given index (return `null` on invalid index)
  @property objectAtIndex (uint idx) nothrow @trusted @nogc => (idx < mObjects.length ? mObjects.ptr[idx] : null);

  ///
  @property isStyleStackEmpty () const pure nothrow @trusted @nogc => (ststackUsed == 0);

  /// push current font and justify
  void pushStyles () nothrow @trusted @nogc {
    ensurePool!(4, false)(1, styleStack, ststackUsed, ststackAllocated);
    if (newStyle.fontface == -1 && layFixFontDG !is null) layFixFontDG(newStyle);
    auto si = styleStack+(ststackUsed++);
    si.fs = newStyle;
    si.ls = newJust;
  }

  /// pop last pushed font and justify
  void popStyles () nothrow @trusted @nogc {
    if (ststackUsed == 0) assert(0, "style stack underflow");
    auto si = styleStack+(--ststackUsed);
    newStyle = si.fs;
    newJust = si.ls;
    if (newStyle.fontface == -1 && layFixFontDG !is null) layFixFontDG(newStyle);
  }

  @property int textHeight () const pure nothrow @safe @nogc => mTextHeight; /// total text height
  @property int textWidth () const pure nothrow @safe @nogc => mTextWidth; /// maximum text width

  /// find line with this word index
  /// returns line number or -1
  int findLineWithWord (uint idx) nothrow @trusted @nogc {
    return findLineBinary((LayLine* l) {
      if (idx < l.wstart) return -1;
      if (idx >= l.wend) return 1;
      return 0;
    });
  }

  /// find line at this pixel coordinate
  /// returns line number or -1
  int findLineAtY (int y) nothrow @trusted @nogc {
    if (linesUsed == 0) return 0;
    if (y < 0) return 0;
    if (y >= mTextHeight) return cast(int)linesUsed-1;
    auto res = findLineBinary((LayLine* l) {
      if (y < l.y) return -1;
      if (y >= l.y+l.h) return 1;
      return 0;
    });
    assert(res != -1);
    return res;
  }

  /// find word at the given coordinate in the given line
  /// returns line number or -1
  int findWordAtX (LayLine* ln, int x) nothrow @trusted @nogc {
    int wcmp (int wnum) {
      auto w = words+ln.wstart+wnum;
      if (x < w.x) return -1;
      return (x >= (wnum+1 < ln.wordCount ? w[1].x : w.x+w.w) ? 1 : 0);
    }
    if (ln is null || ln.wordCount == 0) return -1;
    int bot = 0, i = ln.wordCount-1;
    while (bot != i) {
      int mid = i-(i-bot)/2;
      switch (wcmp(mid)) {
        case -1: i = mid-1; break;
        case  1: bot = mid; break;
        default: return ln.wstart+mid;
      }
    }
    return (wcmp(i) == 0 ? ln.wstart+i : -1);
  }

  /// find word at the given coordinates
  /// returns line number or -1
  int wordAtXY (int x, int y) nothrow @trusted @nogc {
    auto lidx = findLineAtY(y);
    if (lidx < 0) return -1;
    auto ln = lines+lidx;
    if (y < ln.y || y >= ln.y+ln.h || ln.wordCount == 0) return -1;
    return findWordAtX(ln, x);
  }

  /// get word by it's index; return `null` if index is invalid
  LayWord* wordByIndex (uint idx) pure nothrow @trusted @nogc => (idx < wordsUsed ? words+idx : null);

  /// get textual representation of the given word
  @property const(CharType)[] wordText (in ref LayWord w) const pure nothrow @trusted @nogc => (w.wstart <= w.wend ? ltext[w.wstart..w.wend] : null);

  /// get number of lines
  @property int lineCount () const pure nothrow @safe @nogc => cast(int)linesUsed;

  /// returns range with all words in the given line
  @property auto lineWords (int lidx) nothrow @trusted @nogc {
    static struct Range {
    private:
      LayWord* w;
      int wordsLeft; // not including current
    nothrow @trusted @nogc:
    private:
      this(LT) (LT lay, int lidx) {
        if (lidx >= 0 && lidx < lay.linesUsed) {
          auto ln = lay.lines+lidx;
          if (ln.wend > ln.wstart) {
            w = lay.words+ln.wstart;
            wordsLeft = ln.wend-ln.wstart-1;
          }
        }
      }
    public:
      @property bool empty () const pure => (w is null);
      @property ref LayWord front () pure { pragma(inline, true); assert(w !is null); return *w; }
      void popFront () { if (wordsLeft) { ++w; --wordsLeft; } else w = null; }
      Range save () { Range res = void; res.w = w; res.wordsLeft = wordsLeft; return res; }
      @property int length () const pure => (w !is null ? wordsLeft+1 : 0);
      alias opDollar = length;
      @property LayWord[] opSlice () => (w !is null ? w[0..wordsLeft+1] : null);
      @property LayWord[] opSlice (int lo, int hi) {
        if (lo < 0) lo = 0;
        if (w is null || hi <= lo || lo > wordsLeft) return null;
        if (hi > wordsLeft+1) hi = wordsLeft+1;
        return w[lo..hi];
      }
    }
    return Range(this, lidx);
  }

  /// returns layouted line object, or `null` on invalid index
  LayLine* line (int lidx) nothrow @trusted @nogc => (lidx >= 0 && lidx < linesUsed ? lines+lidx : null);

  /// maximum width layouter can use; note that resulting `textWidth` can be less than this
  @property int width () const pure nothrow @safe @nogc => maxWidth;

  /// last flushed word index
  @property uint lastWordIndex () const pure nothrow @safe @nogc => (wordsUsed ? wordsUsed-1 : 0);

  /// current word index
  @property uint nextWordIndex () const pure nothrow @safe @nogc => wordsUsed+hasWordChars;

  /// get font style object; changes will take effect on next char
  @property ref LayFontStyle fontStyle () pure nothrow @safe @nogc => newStyle;
  /// get line style object; changes will take effect on next line
  @property ref LayLineStyle lineStyle () pure nothrow @safe @nogc => newJust;

  /// return "font id" for the given font face
  @property int fontFaceId(bool fail=true) (const(char)[] name) nothrow @safe @nogc {
    if (laf !is null) {
      int fid = laf.fontFaceId(name);
      if (fid >= 0) return fid;
    }
    static if (fail) assert(0, "unknown font face"); // '"~name.idup~"'");
    return -1;
  }

  /// return font face for the given "font id"
  @property const(char)[] fontFace (int fid) nothrow @safe @nogc => (laf !is null ? laf.fontFace(fid) : null);

  /// end current line
  void endLine () nothrow @trusted @nogc => put(EndLineCh);

  /// end current paragraph
  void endPara () nothrow @trusted @nogc => put(EndParaCh);

  /// put non-breaking space
  void putNBSP () nothrow @trusted @nogc => put(NonBreakingSpaceCh);

  /// put soft hypen
  void putSoftHypen () nothrow @trusted @nogc => put(SoftHyphenCh);

  /// add "object" into text -- special thing that knows it's dimensions
  void putObject (LayObject obj) @trusted {
    import std.algorithm : max, min;
    if (lastWasUtf) {
      lastWasUtf = false;
      if (!dec.complete) { dec.reset; put(' '); }
    }
    flushWord();
    lastWasSoftHypen = false;
    if (obj is null) return;
    if (mObjects.length >= int.max/2) throw new Exception("too many mObjects");
    just = newJust;
    // create special word
    auto w = allocWord!true();
    w.wstart = cast(uint)mObjects.length; // store object index
    w.wend = 0;
    mObjects ~= obj;
    w.style = style;
    w.propsOrig.object = true;
    w.propsOrig.spaced = obj.spaced;
    w.propsOrig.canbreak = obj.canbreak;
    w.props = w.propsOrig;
    w.w = cast(short)min(max(0, obj.width), short.max);
    w.whyph = w.wsp = cast(short)min(w.w+max(0, obj.spacewidth), short.max);
    w.h = cast(short)min(max(0, obj.height), short.max);
    w.asc = cast(short)min(max(0, obj.ascent), short.max);
    if (w.asc < 0) throw new Exception("object ascent should be positive");
    w.desc = cast(short)min(max(0, obj.descent), short.max);
    if (w.desc > 0) throw new Exception("object descent should be negative");
    w.just = just;
    w.paraPad = -1;
  }

  /// put "expander" (it will expand to take all unused line width on finalization).
  /// it line contains more than one expander, all expanders will try to get same width.
  void putExpander () nothrow @trusted @nogc {
    if (lastWasUtf) {
      lastWasUtf = false;
      if (!dec.complete) { dec.reset; put(' '); }
    }
    flushWord();
    if (wordsUsed > 0) {
      auto lw = words+wordsUsed-1;
      lw.propsOrig.canbreak = false; // cannot break before expander
      lw.propsOrig.spaced = false;
    }
    lastWasSoftHypen = false;
    // create special expander word
    auto w = createEmptyWord();
    // fix word properties
    w.propsOrig.canbreak = false; // cannot break after expander
    w.propsOrig.spaced = false;
    w.propsOrig.hyphen = false;
    w.propsOrig.expander = true;
    w.propsOrig.lineend = false;
    w.propsOrig.paraend = false;
    w.wstart = charsUsed;
    w.wend = charsUsed;
  }

  /// put "hard space" (it will always takes the given number of pixels).
  void putHardSpace (int wdt) nothrow @trusted @nogc {
    putExpander(); // hack: i am too lazy to refactor the code
    auto lw = words+wordsUsed-1;
    lw.propsOrig.expander = false;
    lw.propsOrig.hardspace = true;
    if (wdt > 8192) wdt = 8192;
    lw.w = cast(short)(wdt < 1 ? 0 : wdt);
  }

  /// add text to layouter; it is ok to mix (valid) utf-8 and dchars here
  void put(T) (const(T)[] str...) nothrow @trusted @nogc if (isAnyCharType!T) {
    if (str.length == 0) return;

    dchar curCh; // 0: no more chars
    usize stpos;

    static if (is(T == char)) {
      // utf-8 stream
      if (!lastWasUtf) { lastWasUtf = true; dec.reset; }
      void skipCh () @trusted {
        while (stpos < str.length) {
          curCh = dec.decode(cast(ubyte)str.ptr[stpos++]);
          if (curCh <= dchar.max) return;
        }
        curCh = 0;
      }
      // load first char
      skipCh();
    } else {
      // dchar stream
      void skipCh () @trusted {
        if (stpos < str.length) {
          curCh = str.ptr[stpos++];
          if (curCh > dchar.max) curCh = '?';
        } else {
          curCh = 0;
        }
      }
      // load first char
      if (lastWasUtf) {
        lastWasUtf = false;
        if (!dec.complete) curCh = '?'; else skipCh();
      } else {
        skipCh();
      }
    }

    // process stream dchars
    if (curCh == 0) return;
    if (!hasWordChars) style = newStyle;
    if (wordsUsed == 0 || words[wordsUsed-1].propsOrig.someend) just = newJust;
    while (curCh) {
      import std.uni;
      dchar ch = curCh;
      skipCh();
      if (ch == EndLineCh || ch == EndParaCh) {
        // ignore leading empty lines
        if (hasWordChars) flushWord(); // has some word data, flush it now
        lastWasSoftHypen = false; // word flusher is using this flag
        auto lw = (wordsUsed ? words+wordsUsed-1 : createEmptyWord());
        // do i need to add empty word for attrs?
        if (lw.propsOrig.someend) lw = createEmptyWord();
        // fix word properties
        lw.propsOrig.canbreak = true;
        lw.propsOrig.spaced = false;
        lw.propsOrig.hyphen = false;
        lw.propsOrig.lineend = (ch == EndLineCh);
        lw.propsOrig.paraend = (ch == EndParaCh);
        flushWord();
        just = newJust;
        firstParaLine = (ch == EndParaCh);
      } else if (ch == NonBreakingSpaceCh) {
        // non-breaking space
        lastWasSoftHypen = false;
        if (hasWordChars && style != newStyle) flushWord();
        putChars(' ');
      } else if (ch == SoftHyphenCh) {
        // soft hyphen
        if (!lastWasSoftHypen && hasWordChars) {
          putChars('-');
          lastWasSoftHypen = true; // word flusher is using this flag
          flushWord();
        } else {
          lastWasSoftHypen = true;
        }
      } else if (ch <= ' ' || isWhite(ch)) {
        if (hasWordChars) {
          flushWord();
          auto lw = words+wordsUsed-1;
          lw.propsOrig.canbreak = true;
          lw.propsOrig.spaced = true;
        } else {
          style = newStyle;
        }
        lastWasSoftHypen = false;
      } else {
        lastWasSoftHypen = false;
        if (ch > dchar.max || ch.isSurrogate || ch.isPrivateUse || ch.isNonCharacter || ch.isMark || ch.isFormat || ch.isControl) ch = '?';
        if (hasWordChars && style != newStyle) flushWord();
        putChars(ch);
        if (isDash(ch) && charsUsed-lastWordStart > 1 && !isDash(ltext[charsUsed-2])) flushWord();
      }
    }
  }

  /// "finalize" layout: calculate lines, layout words...
  /// call this after you done feeding text
  void finalize () nothrow @trusted @nogc {
    flushWord();
    lastWasSoftHypen = false;
    relayout(maxWidth, true);
  }

  /// relayout everything using the existing words
  void relayout (int newWidth, bool forced=false) nothrow @trusted @nogc {
    if (newWidth < 1) newWidth = 1;
    if (!forced && newWidth == maxWidth) return;
    auto odepth = ststackUsed;
    scope(exit) {
      while (ststackUsed > odepth) popStyles();
    }
    if (newStyle.fontface == -1 && layFixFontDG !is null) layFixFontDG(newStyle);
    maxWidth = newWidth;
    linesUsed = 0;
    if (linesAllocated > 0) {
      import core.stdc.string : memset;
      memset(lines, 0, linesAllocated*lines[0].sizeof);
    }
    uint widx = 0;
    uint wu = wordsUsed;
    mTextWidth = 0;
    mTextHeight = 0;
    firstParaLine = true;
    scope(exit) firstWordNotFlushed = wu;
    while (widx < wu) {
      uint lend = widx;
      while (lend < wu) {
        auto w = words+(lend++);
        if (w.expander) w.w = w.wsp = w.whyph = 0; // will be fixed in `flushLines()`
        if (w.propsOrig.someend) break;
      }
      flushLines(widx, lend);
      widx = lend;
      firstParaLine = words[widx-1].propsOrig.paraend;
    }
  }

public:
  /*
  // don't use
  void save (VFile fl) {
    fl.rawWriteExact("XLL0");
    fl.rawWriteExact(ltext[0..charsUsed]);
    fl.rawWriteExact(words[0..wordsUsed]);
  }
  */

public:
  // don't use
  debug(xlayouter_dump) void dump (VFile fl) const {
    import iv.vfs.io;
    fl.writeln("LINES: ", linesUsed);
    foreach (immutable idx, const ref ln; lines[0..linesUsed]) {
      fl.writeln("LINE #", idx, ": ", ln.wordCount, " words; just=", ln.just.toString, "; jlpad=", ln.just.leftpad, "; y=", ln.y, "; h=", ln.h, "; desc=", ln.desc);
      foreach (immutable widx, const ref w; words[ln.wstart..ln.wend]) {
        fl.writeln("  WORD #", widx, "(", w.wordNum, ")[", w.wstart, "..", w.wend, "]: ", wordText(w));
        fl.writeln("    wbreak=", w.props.canbreak, "; wspaced=", w.props.spaced, "; whyphen=", w.props.hyphen, "; style=", w.style.toString);
        fl.writeln("    x=", w.x, "; w=", w.w, "; h=", w.h, "; asc=", w.asc, "; desc=", w.desc);
      }
    }
  }

private:
  static bool isDash (dchar ch) pure nothrow @trusted @nogc {
    pragma(inline, true);
    return (ch == '-' || (ch >= 0x2013 && ch == 0x2015) || ch == 0x2212);
  }

  LayWord* createEmptyWord () nothrow @trusted @nogc {
    assert(!hasWordChars);
    auto w = allocWord!true();
    w.style = style;
    w.props = w.propsOrig;
    // set word dimensions
    if (w.style.fontface < 0) assert(0, "invalid font face in word style");
    laf.setFont(w.style);
    w.w = w.wsp = w.whyph = 0;
    // calculate ascent, descent and height
    {
      int a, d, h;
      laf.textMetrics(&a, &d, &h);
      w.asc = cast(short)a;
      w.desc = cast(short)d;
      w.h = cast(short)h;
    }
    w.just = just;
    w.paraPad = -1;
    style = newStyle;
    return w;
  }

  void flushWord () nothrow @trusted @nogc {
    if (hasWordChars) {
      auto w = allocWord!true();
      w.wstart = lastWordStart;
      w.wend = charsUsed;
      //{ import iv.encoding, std.conv : to; writeln("adding word: [", wordText(*w).to!string.recodeToKOI8, "]"); }
      w.propsOrig.hyphen = lastWasSoftHypen;
      if (lastWasSoftHypen) {
        w.propsOrig.canbreak = true;
        w.propsOrig.spaced = false;
        --w.wend; // remove hyphen mark (for now)
      }
      w.style = style;
      w.props = w.propsOrig;
      w.props.hyphen = false;
      // set word dimensions
      if (w.style.fontface < 0) assert(0, "invalid font face in word style");
      laf.setFont(w.style);
      // i may need spacing later, and anyway most words should be with spacing, so calc it unconditionally
      if (w.wend > w.wstart) {
        auto t = wordText(*w);
        int ww, wsp, whyph;
        laf.textWidth2(t, &ww, &wsp, (w.propsOrig.hyphen ? &whyph : null));
        w.w = cast(short)ww;
        w.wsp = cast(short)wsp;
        if (!w.propsOrig.hyphen) w.whyph = w.w; else w.whyph = cast(short)whyph;
        if (isDash(t[$-1])) { w.propsOrig.canbreak = true; w.props.canbreak = true; }
      } else {
        w.w = w.wsp = w.whyph = 0;
      }
      // calculate ascent, descent and height
      {
        int a, d, h;
        laf.textMetrics(&a, &d, &h);
        w.asc = cast(short)a;
        w.desc = cast(short)d;
        w.h = cast(short)h;
      }
      w.just = just;
      w.paraPad = -1;
      lastWordStart = charsUsed;
    }
    style = newStyle;
  }

  // [curw..endw)"
  void flushLines (uint curw, uint endw) nothrow @trusted @nogc {
    if (curw < endw) {
      debug(xlay_line_flush) conwriteln("flushing ", endw-curw, " words");
      uint stline = linesUsed; // reformat from this
      // fix word styles
      foreach (ref LayWord w; words[curw..endw]) {
        if (w.props.hyphen) --w.wend; // remove hyphen mark
        w.props = w.propsOrig;
        w.props.hyphen = false;
      }
      LayLine* ln;
      LayWord* w = words+curw;
      while (curw < endw) {
        debug(xlay_line_flush) conwriteln("  ", endw-curw, " words left");
        if (ln is null) {
          // add line to work with
          ln = allocLine();
          ln.wstart = ln.wend = curw;
          ln.just = w.just;
          ln.w = w.just.leftpad+w.just.rightpad;
          // indent first line of paragraph
          if (firstParaLine) {
            firstParaLine = false;
            // left-side or justified lines has paragraph indent
            if (ln.just.paraIndent > 0 && (w.just.left || w.just.justify)) {
              auto ind = w.paraPad;
              if (ind < 0) {
                laf.setFont(w.style);
                ind = cast(short)laf.spacesWidth(ln.just.paraIndent);
                w.paraPad = ind;
              }
              ln.w += ind;
              ln.just.leftpad = ln.just.leftpad+ind;
            } else {
              w.paraPad = 0;
            }
          }
          //conwriteln("new line; maxWidth=", maxWidth, "; starting line width=", ln.w);
          //conwriteln("* maxWidth=", maxWidth, "; ln.w=", ln.w, "; leftpad=", ln.just.leftpad, "; rightpad=", ln.just.rightpad);
        }
        debug(xlay_line_flush) conwritefln!"  (%s:0x%04x) 0x%08x : 0x%08x : 0x%08x : %s"(LayLine.sizeof, LayLine.sizeof, cast(uint)lines, cast(uint)ln, cast(uint)(lines+linesUsed-1), cast(int)(ln-((lines+linesUsed-1))));
        // add words until i hit breaking point
        // if it will end beyond maximum width, and this line
        // has some words, flush the line and start new one
        uint startIndex = curw;
        int curwdt = ln.w, lastwsp = 0;
        int hyphenWdt = 0;
        while (curw < endw) {
          // add word width with spacing (i will compensate for that after loop)
          lastwsp = (w.propsOrig.spaced ? w.wsp-w.w : 0);
          curwdt += w.w+lastwsp;
          ++curw; // advance counter here...
          if (w.propsOrig.hyphen) { hyphenWdt = w.whyph-w.w; if (hyphenWdt < 0) hyphenWdt = 0; } else hyphenWdt = 0;
          if (w.props.canbreak) break; // done with this span
          ++w; // ...and word pointer here (skipping one inc at the end ;-)
        }
        debug(xlay_line_flush) conwriteln("  ", curw-startIndex, " words processed");
        // can i add the span? if this is first span in line, add it unconditionally
        if (ln.wordCount == 0 || curwdt+hyphenWdt-lastwsp <= maxWidth) {
          //if (hyphenWdt) { import core.stdc.stdio; printf("curwdt=%d; hwdt=%d; next=%d; max=%d\n", curwdt, hyphenWdt, curwdt+hyphenWdt-lastwsp, maxWidth); }
          // yay, i can!
          ln.wend = curw;
          ln.w = curwdt;
          ++w; // advance to curw
          debug(xlay_line_flush) conwriteln("curwdt=", curwdt, "; maxWidth=", maxWidth, "; wc=", ln.wordCount, "(", ln.wend-ln.wstart, ")");
        } else {
          // nope, start new line here
          debug(xlay_line_flush) conwriteln("added line with ", ln.wordCount, " words");
          // last word in the line should not be spaced
          auto ww = words+ln.wend-1;
          // compensate for spacing at last word
          ln.w -= (ww.props.spaced ? ww.wsp-ww.w : 0);
          ww.props.spaced = false;
          // and should have hyphen mark if it is necessary
          if (ww.propsOrig.hyphen) {
            assert(!ww.props.hyphen);
            ww.props.hyphen = true;
            ++ww.wend;
            // fix line width (word layouter will use that)
            ln.w += ww.whyph-ww.w;
          }
          ln = null;
          curw = startIndex;
          w = words+curw;
        }
      }
      debug(xlay_line_flush) conwriteln("added line with ", ln.wordCount, " words; new lines range: [", stline, "..", linesUsed, "]");
      debug(xlay_line_flush) conwritefln!"(%s:0x%04x) 0x%08x : 0x%08x : 0x%08x : %s"(LayLine.sizeof, LayLine.sizeof, cast(uint)lines, cast(uint)ln, cast(uint)(lines+linesUsed-1), cast(int)(ln-((lines+linesUsed-1))));
      // last line should not be justified
      if (ln.just.justify) ln.just.setLeft;
      // do real word layouting and fix line metrics
      debug(xlay_line_flush) conwriteln("added ", linesUsed-stline, " lines");
      foreach (uint lidx; stline..linesUsed) {
        debug(xlay_line_flush) conwriteln(": lidx=", lidx, "; wc=", lines[lidx].wordCount);
        layoutLine(lidx);
      }
    }
  }

  // do word layouting and fix line metrics
  void layoutLine (uint lidx) nothrow @trusted @nogc {
    import std.algorithm : max, min;
    assert(lidx < linesUsed);
    auto ln = lines+lidx;
    //conwriteln("maxWidth=", maxWidth, "; ln.w=", ln.w, "; leftpad=", ln.just.leftpad, "; rightpad=", ln.just.rightpad);
    debug(xlay_line_layout) conwriteln("lidx=", lidx, "; wc=", ln.wordCount);
    // y position
    ln.y = (lidx ? ln[-1].y+ln[-1].h : 0);
    auto lwords = lineWords(lidx);
    assert(!lwords.empty); // i should have at least one word in each line
    // line width is calculated for us by `flushLines()`
    // calculate line metrics and number of words with spacing
    int expanderCount = 0;
    int lineH, lineDesc, wspCount;
    foreach (ref LayWord w; lwords.save) {
      lineH = max(lineH, w.h);
      lineDesc = min(lineDesc, w.desc);
      if (w.props.spaced) ++wspCount;
      if (w.expander) ++expanderCount;
    }
    // process expanders
    if (expanderCount > 0 && ln.w < maxWidth) {
      int expanderWdt = (maxWidth-ln.w)/expanderCount;
      int expanderLeft = (maxWidth-ln.w)-expanderWdt*expanderCount;
      debug(xlayouter_expander) conwriteln("expanderWdt=", expanderWdt, "; expanderLeft=", expanderLeft);
      foreach (ref LayWord w; lwords) {
        if (w.propsOrig.expander) {
          assert(w.w == 0);
          w.w = cast(short)(expanderWdt+(expanderLeft-- > 0 ? 1 : 0));
          ln.w += w.w;
        }
      }
    }
    // vertical padding; clamp it, as i can't have line over line (it will break too many things)
    lineH += ln.just.toppad+ln.just.bottompad;
    ln.h = lineH;
    ln.desc = lineDesc;
    if (ln.w >= maxWidth) {
      //conwriteln("*** ln.w=", ln.w, "; maxWidth=", maxWidth);
      // way too long; (almost) easy deal
      // calculate free space to spare in case i'll need to compensate hyphen mark
      int x = ln.just.leftpad, spc = 0;
      foreach (ref LayWord w; lwords.save) {
        w.x = cast(short)x;
        x += w.fullwidth;
        if (w.props.spaced) spc += w.wsp-w.w;
      }
      // if last word ends with hyphen, try to compensate it
      if (words[ln.wend-1].props.hyphen) {
        int needspc = ln.w-maxWidth;
        // no more than 8 pix or 2/3 of free space
        if (needspc <= 8 && needspc <= spc/3*2) {
          // compensate (i can do fractional math here, but meh...)
          while (needspc > 0) {
            // excellence in coding!
            foreach_reverse (immutable widx; ln.wstart..ln.wend) {
              if (words[widx].props.spaced) {
                --ln.w;
                foreach (immutable c; widx+1..ln.wend) words[c].x -= 1;
                if (--needspc == 0) break;
              }
            }
          }
        }
      }
    } else if (ln.just.justify && wspCount > 0) {
      // fill the whole line
      int spc = maxWidth-ln.w; // space left to distribute
      int xadvsp = spc/wspCount;
      int frac = spc-xadvsp*wspCount;
      int x = ln.just.leftpad;
      // no need to save range here, i'll do it in one pass
      foreach (ref LayWord w; lwords) {
        w.x = cast(short)x;
        x += w.fullwidth;
        if (w.props.spaced) {
          x += xadvsp;
          //spc -= xadvsp;
          if (frac-- > 0) {
            ++x;
            //--spc;
          }
        }
      }
      //if (x != maxWidth-ln.just.rightpad) conwriteln("x=", x, "; but it should be ", maxWidth-ln.just.rightpad, "; spcleft=", spc, "; ln.w=", ln.w, "; maxWidth=", maxWidth-ln.w);
      //assert(x == maxWidth-ln.just.rightpad);
    } else {
      int x;
           if (ln.just.left || ln.just.justify) x = ln.just.leftpad;
      else if (ln.just.right) x = maxWidth-ln.w+ln.just.leftpad;
      else if (ln.just.center) x = (maxWidth-(ln.w-ln.just.leftpad-ln.just.rightpad))/2;
      else assert(0, "wtf?!");
      // no need to save range here, i'll do it in one pass
      foreach (ref LayWord w; lwords) {
        w.x = cast(short)x;
        x += w.fullwidth;
      }
    }
    if (ln.h < 1) ln.h = 1;
    // done
    mTextWidth = max(mTextWidth, ln.w);
    mTextHeight = ln.y+ln.h;
    debug(xlay_line_layout) conwriteln("lidx=", lidx, "; wc=", ln.wordCount);
  }
}
