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
module iv.egtui.editor.ttyeditor;

import std.datetime : SysTime;

import iv.rawtty;
import iv.srex;
import iv.strex;
import iv.utfutil;
import iv.vfs.io;

import iv.egtui.tty;
import iv.egtui.tui;
import iv.egtui.dialogs;
import iv.egeditor.editor;
import iv.egeditor.highlighters;
import iv.egtui.editor.highlighters;
import iv.egtui.editor.dialogs;


// ////////////////////////////////////////////////////////////////////////// //
private string normalizedAbsolutePath (string path) {
  import std.path;
  return buildNormalizedPath(absolutePath(path));
}


// ////////////////////////////////////////////////////////////////////////// //
class TtyEditor : EditorEngine {
  enum TEDSingleOnly; // only for single-line mode
  enum TEDMultiOnly; // only for multiline mode
  enum TEDEditOnly; // only for non-readonly mode
  enum TEDROOnly; // only for readonly mode
  enum TEDRepeated; // allow "repeation count"
  enum TEDRepeatChar; // this combo meant "repeat mode"

  static struct TEDKey { string key; string help; bool hidden; } // UDA

  static string TEDImplX(string key, string help, string code, size_t ln) () {
    static assert(key.length > 0, "wtf?!");
    static assert(code.length > 0, "wtf?!");
    string res = "@TEDKey("~key.stringof~", "~help.stringof~") void _ted_";
    int pos = 0;
    while (pos < key.length) {
      char ch = key[pos++];
      if (key.length-pos > 0 && key[pos] == '-') {
        if (ch == 'C' || ch == 'c') { ++pos; res ~= "Ctrl"; continue; }
        if (ch == 'M' || ch == 'm') { ++pos; res ~= "Alt"; continue; }
        if (ch == 'S' || ch == 's') { ++pos; res ~= "Shift"; continue; }
      }
      if (ch == '^') { res ~= "Ctrl"; continue; }
      if (ch >= 'a' && ch <= 'z') ch -= 32;
      if ((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || ch == '_') res ~= ch; else res ~= '_';
    }
    res ~= ln.stringof;
    res ~= " () {"~code~"}";
    return res;
  }

  mixin template TEDImpl(string key, string help, string code, size_t ln=__LINE__) {
    mixin(TEDImplX!(key, help, code, ln));
  }

  mixin template TEDImpl(string key, string code, size_t ln=__LINE__) {
    mixin(TEDImplX!(key, "", code, ln));
  }

protected:
  TtyEvent[32] comboBuf;
  int comboCount; // number of items in `comboBuf`
  bool waitingInF5;
  bool incInputActive;
  int repeatCounter = -1; // <0: not in counter typing
  int repeatCounterMode; // <0: C-Space just pressed; >0: just started; 0: normal

protected:
  TtyEditor mPromptInput; // input line for a prompt; lazy creation
  bool mPromptActive;
  char[128] mPromptPrompt; // lol
  int mPromptLen;

  final void promptDeactivate () {
    if (mPromptActive) {
      mPromptActive = false;
      fullDirty(); // just in case
    }
  }

  final void promptNoKillText () {
    if (mPromptInput !is null) mPromptInput.killTextOnChar = false;
  }

  final void promptActivate (const(char)[] prompt=null, const(char)[] text=null) {
    if (mPromptInput is null) {
      mPromptInput = new TtyEditor(0, 0, 10, 1, true); // single-lined
    }

    bool addDotDotDot = false;
    if (winw <= 8) {
      prompt = null;
    } else {
      if (prompt.length > winw-8) {
        addDotDotDot = true;
        prompt = prompt[$-(winw-8)..$];
      }
    }
    if (prompt.length > mPromptPrompt.length) addDotDotDot = true;

    mPromptPrompt[] = 0;
    if (addDotDotDot) {
      mPromptPrompt[0..3] = '.';
      if (prompt.length > mPromptPrompt.length-3) prompt = prompt[$-(mPromptPrompt.length-3)..$];
      mPromptPrompt[3..3+prompt.length] = prompt[];
      mPromptLen = cast(int)prompt.length+3;
    } else {
      mPromptPrompt[0..prompt.length] = prompt[];
      mPromptLen = cast(int)prompt.length;
    }

    mPromptInput.moveResize(winx+mPromptLen+2, winy-1, winw-mPromptLen-2, 1);
    mPromptInput.clear();
    if (text.length) {
      mPromptInput.doPutText(text);
      mPromptInput.clearUndo();
    }

    mPromptInput.killTextOnChar = true;
    mPromptInput.clrBlock = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TtyRgb2Color!(0x00, 0x5f, 0xff));
    mPromptInput.clrText = XtColorFB!(TtyRgb2Color!(0x00, 0x00, 0x00), TtyRgb2Color!(0xff, 0x7f, 0x00));
    mPromptInput.clrTextUnchanged = XtColorFB!(TtyRgb2Color!(0x00, 0x00, 0x00), TtyRgb2Color!(0xcf, 0x4f, 0x00));

    mPromptInput.utfuck = utfuck;
    mPromptInput.codepage = codepage;
    mPromptActive = true;
    fullDirty(); // just in case
  }

  final bool promptProcessKey (TtyEvent key, scope void delegate (EditorEngine ed) onChange=null) {
    if (!mPromptActive) return false;
    auto lastCC = mPromptInput.bufferCC;
    auto res = mPromptInput.processKey(key);
    if (lastCC != mPromptInput.bufferCC && onChange !is null) onChange(mPromptInput);
    return res;
  }

protected:
  int incSearchDir; // -1; 0; 1
  char[] incSearchBuf; // will be actively reused, don't expose
  int incSearchHitPos = -1;
  int incSearchHitLen = -1;

protected:
  // autocompletion buffers
  const(char)[][256] aclist; // autocompletion tokens
  uint acused = 0; // number of found tokens
  char[] acbuffer; // will be actively reused, don't expose

public:
  string logFileName;
  string tempBlockFileName;
  string fullFileName;
  // save this, so we can check on saving
  SysTime fileModTime;
  long fileDiskSize = -1; // <0: modtime is invalid
  bool dontSetCursor; // true: don't gotoxy to cursor position
  // colors; valid for singleline control
  uint clrBlock, clrText, clrTextUnchanged;
  // other
  SearchReplaceOptions srrOptions;
  bool hideStatus = false;
  bool hideSBar = false; // hide scrollbar
  FuiHistoryManager hisman; // history manager for dialogs

public:
  this (int x0, int y0, int w, int h, bool asinglesine=false) {
    // prompt should be created only for multiline editors
    super(x0, y0, w, h, null, asinglesine);
    //srrOptions.type = SearchReplaceOptions.Type.Regex;
    srrOptions.casesens = true;
    srrOptions.nocomments = true;
  }

  // call this after setting `fullFileName`
  void setupHighlighter () {
    auto ep = fullFileName.length;
    while (ep > 0 && fullFileName.ptr[ep-1] != '/' && fullFileName.ptr[ep-1] != '.') --ep;
    if (ep < 1 || fullFileName.ptr[ep-1] != '.') {
      attachHiglighter(getHiglighterObjectFor("", fullFileName));
    } else {
      attachHiglighter(getHiglighterObjectFor(fullFileName[ep-1..$], fullFileName));
    }
  }

  final void toggleHighlighting () {
    if (hl is null) setupHighlighter(); else detachHighlighter();
  }

  final @property bool hasHighlighter () const pure nothrow @safe @nogc { pragma(inline, true); return (hl !is null); }

  final void getDiskFileInfo () {
    import std.file : getSize, timeLastModified;
    if (fullFileName.length) {
      fileDiskSize = getSize(fullFileName);
      fileModTime = timeLastModified(fullFileName);
    } else {
      fileDiskSize = -1;
    }
  }

  // return `true` if file was changed
  final bool wasDiskFileChanged () {
    import std.file : exists, getSize, timeLastModified;
    if (fullFileName.length && fileDiskSize >= 0) {
      if (!fullFileName.exists) return false;
      auto sz = getSize(fullFileName);
      if (sz != fileDiskSize) return true;
      SysTime modtime = timeLastModified(fullFileName);
      if (modtime != fileModTime) return true;
    }
    return false;
  }

  override void loadFile (const(char)[] fname) {
    fileDiskSize = -1;
    fullFileName = normalizedAbsolutePath(fname.idup);
    super.loadFile(VFile(fullFileName));
    getDiskFileInfo();
  }

  // return `false` iff overwrite dialog was aborted
  final bool saveFileChecked () {
    if (fullFileName.length == 0) return true;
    if (wasDiskFileChanged) {
      auto res = dialogFileModified(fullFileName, false, "Disk file was changed. Overwrite it?");
      if (res < 0) return false;
      if (res == 1) {
        super.saveFile(fullFileName);
        getDiskFileInfo();
      }
    } else {
      super.saveFile(fullFileName);
      getDiskFileInfo();
    }
    return true;
  }

  final void checkDiskAndReloadPrompt () {
    if (fullFileName.length == 0) return;
    if (wasDiskFileChanged) {
      auto fn = fullFileName;
      if (fn.length > ttyw-3) fn = "* ..."~fn[$-(ttyw-4)..$];
      auto res = dialogFileModified(fullFileName, false, "Disk file was changed. Reload it?");
      if (res != 1) return;
      int rx = cx, ry = cy;
      clear();
      super.loadFile(VFile(fullFileName));
      getDiskFileInfo();
      cx = rx;
      cy = ry;
      normXY();
      makeCurLineVisibleCentered();
    }
  }

  override void saveFile (const(char)[] fname=null) {
    if (fname.length) {
      auto nfn = normalizedAbsolutePath(fname.idup);
      if (fname == fullFileName) { saveFileChecked(); return; }
      super.saveFile(VFile(nfn, "w"));
      fullFileName = nfn;
      getDiskFileInfo();
    } else {
      saveFileChecked();
    }
  }

  protected override void willBeDeleted (int pos, int len, int eolcount) {
    if (len > 0) resetIncSearchPos();
    super.willBeDeleted(pos, len, eolcount);
  }

  protected override void willBeInserted (int pos, int len, int eolcount) {
    if (len > 0) resetIncSearchPos();
    super.willBeInserted(pos, len, eolcount);
  }

  final void resetIncSearchPos () nothrow {
    if (incSearchHitPos >= 0) {
      markLinesDirty(gb.pos2line(incSearchHitPos), 1);
      incSearchHitPos = -1;
      incSearchHitLen = -1;
    }
  }

  final void doStartIncSearch (int sdir=0) {
    resetIncSearchPos();
    incInputActive = true;
    incSearchDir = (sdir ? sdir : incSearchDir ? incSearchDir : 1);
    promptActivate("incsearch", incSearchBuf);
    /*
    incSearchBuf.length = 0;
    incSearchBuf.assumeSafeAppend;
    */
  }

  final void doNextIncSearch (bool domove=true) {
    if (incSearchDir == 0 || incSearchBuf.length == 0) {
      resetIncSearchPos();
      return;
    }
    //gb.moveGapAtEnd();
    //TODO: use `memr?chr()` here?
    resetIncSearchPos();
    if (incSearchBuf.ptr[0] != '/') {
      // plain text
      int pos = curpos+(domove ? incSearchDir : 0);
      PlainMatch mt;
      if (incSearchDir < 0) {
        mt = findTextPlainBack(incSearchBuf, 0, pos, /*words:*/false, /*caseSens:*/true);
      } else {
        mt = findTextPlain(incSearchBuf, pos, textsize, /*words:*/false, /*caseSens:*/true);
      }
      if (!mt.empty) {
        incSearchHitPos = mt.s;
        incSearchHitLen = mt.e-mt.s;
      }
    } else if (incSearchBuf.length > 2 && incSearchBuf[$-1] == '/') {
      // regexp
      import std.utf : byChar;
      auto re = RegExp.create(incSearchBuf[1..$-1].byChar, SRFlags.Multiline);
      if (!re.valid) { ttyBeep; return; }
      Pike.Capture[2] caps;
      bool found;
      if (incSearchDir > 0) {
        found = findTextRegExp(re, curpos+(domove ? 1 : 0), textsize, caps);
      } else {
        found = findTextRegExpBack(re, 0, curpos+(domove ? -1 : 0), caps);
      }
      if (found) {
        // something was found
        incSearchHitPos = caps[0].s;
        incSearchHitLen = caps[0].e-caps[0].s;
      }
    }
    if (incSearchHitPos >= 0 && incSearchHitLen > 0) {
      pushUndoCurPos();
      gb.pos2xy(incSearchHitPos, cx, cy);
      makeCurLineVisibleCentered();
      markRangeDirty(incSearchHitPos, incSearchHitLen);
    }
  }

  final void drawScrollBar () {
    if (winx == 0) return; // it won't be visible anyway
    if (singleline || hideSBar) return;
    auto win = XtWindow(winx-1, winy-(hideStatus ? 0 : 1), 1, winh+(hideStatus ? 0 : 1));
    if (win.height < 1) return; // it won't be visible anyway
    win.fg = TtyRgb2Color!(0x00, 0x00, 0x00);
    win.bg = (termType != TermType.linux ? TtyRgb2Color!(0x00, 0x5f, 0xaf) : TtyRgb2Color!(0x00, 0x5f, 0xcf));
    int filled;
    int botline = topline+winh-1;
    if (botline >= linecount-1 || linecount == 0) {
      filled = win.height;
    } else {
      filled = (win.height-1)*botline/linecount;
      if (filled == win.height-1 && mTopLine+winh < linecount) --filled;
    }
    foreach (immutable y; 0..win.height) win.writeCharsAt!true(0, y, 1, (y <= filled ? ' ' : 'a'));
  }

  public override void drawCursor () {
    if (dontSetCursor) return;
    // draw prompt if it is active
    if (mPromptActive) { mPromptInput.drawCursor(); return; }
    int rx, ry;
    gb.pos2xyVT(curpos, rx, ry);
    XtWindow(winx, winy, winw, winh).gotoXY(rx-mXOfs, ry-topline);
  }

  public override void drawStatus () {
    if (singleline || hideStatus) return;
    auto win = XtWindow(winx, winy-1, winw, 1);
    win.fg = TtyRgb2Color!(0x00, 0x00, 0x00);
    win.bg = TtyRgb2Color!(0xb2, 0xb2, 0xb2);
    win.writeCharsAt(0, 0, win.width, ' ');
    import core.stdc.stdio : snprintf;
    auto cp = curpos;
    char[512] buf = void;
    auto sx = cx;
    if (visualtabs) {
      int ry;
      gb.pos2xyVT(cp, sx, ry);
    }
    // mod, (pos), topline, linecount
    auto len = snprintf(buf.ptr, buf.length, " %c[%04u:%05u : %5u : %5u]  ",
      (textChanged ? '*' : ' '), sx+0, cy+1, topline, linecount);
    // character code (hex, dec)
    if (!utfuck) {
      auto c = cast(uint)gb[cp];
      len += snprintf(buf.ptr+len, buf.length-len, "0x%02x %3u", c, c);
    } else {
      auto c = cast(uint)dcharAt(cp);
      len += snprintf(buf.ptr+len, buf.length-len, "U%04x %5u", c, c);
    }
    // filesize, bufstart, bufend
    len += snprintf(buf.ptr+len, buf.length-len, "   [ %u : %d : %d]", gb.textsize, bstart, bend);
    // counter
    if (repeatCounter >= 0) len += snprintf(buf.ptr+len, buf.length-len, "  rep:%d", repeatCounter);
    // done
    if (len > winw) len = winw;
    win.writeStrAt(0, 0, buf[0..len]);
    // mode flags
    if (utfuck) {
      win.fb(11, 9);
      if (readonly) win.writeCharsAt(0, 0, 1, '/'); else win.writeCharsAt(0, 0, 1, 'U');
    } else if (readonly) {
      win.fb(11, 9);
      win.writeCharsAt(0, 0, 1, 'R');
    }
  }

  // highlighting is done, other housekeeping is done, only draw
  // lidx is always valid
  // must repaint the whole line
  // use `winXXX` vars to know window dimensions
  //FIXME: clean this up!
  public override void drawLine (int lidx, int yofs, int xskip) {
    immutable vt = visualtabs;
    immutable tabsz = gb.tabsize;
    auto win = XtWindow(winx, winy, winw, winh);
    auto pos = gb.line2pos(lidx);
    int x = -xskip;
    int y = yofs;
    auto ts = gb.textsize;
    bool inBlock = (bstart < bend && pos >= bstart && pos < bend);
    bool bookmarked = isLineBookmarked(lidx);
    if (singleline) {
      win.color = (clrText ? clrText : TextColor);
      if (killTextOnChar) win.color = (clrTextUnchanged ? clrTextUnchanged : TextKillColor);
      if (inBlock) win.color = (clrBlock ? clrBlock : BlockColor);
    } else {
      win.color = TextColor;
      if (bookmarked) win.color = BookmarkColor; else if (inBlock) win.color = BlockColor;
    }
    // if we have no highlighter, check for trailing spaces explicitly
    bool hasHL = (hl !is null); // do we have highlighter (just a cache)
    // look for trailing spaces even if we have a highlighter
    int trspos = gb.line2pos(lidx+1); // this is where trailing spaces starts (will)
    if (!singleline) while (trspos > pos && gb[trspos-1] <= ' ') --trspos;
    bool utfucked = utfuck;
    int bs = bstart, be = bend;
    auto sltextClr = (singleline ?
                       (killTextOnChar ?
                         (clrTextUnchanged ? clrTextUnchanged : TextKillColor) :
                         (clrText ? clrText : TextColor)) :
                       TextColor);
    auto blkClr = (singleline ? (clrBlock ? clrBlock : BlockColor) : BlockColor);
    while (pos < ts) {
      inBlock = (bs < be && pos >= bs && pos < be);
      auto ch = gb[pos++];
      if (ch == '\n') {
        if (!killTextOnChar && !singleline) win.color = (hasHL ? hiColor(gb.hi(pos-1)) : TextColor); else win.color = sltextClr;
      } else if (hasHL) {
        // has highlighter
        if (pos-1 >= trspos) {
          if (ch != '\t') ch = '.';
          if (!killTextOnChar && !singleline) win.color = (ch != '\t' ? TrailSpaceColor : VisualTabColor); else win.color = sltextClr;
        } else if (ch < ' ' || ch == 127) {
          if (!killTextOnChar && !singleline) win.color = (ch != '\t' ? BadColor : VisualTabColor); else win.color = sltextClr;
        } else {
          auto hs = gb.hi(pos-1);
          if (!killTextOnChar && !singleline) win.color = hiColor(hs); else win.color = sltextClr;
        }
      } else {
        // no highlighter
        if (pos-1 >= trspos) {
          if (ch != '\t') ch = '.';
          if (!killTextOnChar && !singleline) win.color = (ch != '\t' ? TrailSpaceColor : VisualTabColor); else win.color = sltextClr;
        } else if (ch < ' ' || ch == 127) {
          if (!killTextOnChar && !singleline) win.color = (ch != '\t' ? BadColor : VisualTabColor); else win.color = sltextClr;
        } else {
          win.color = sltextClr;
        }
      }
      if (!killTextOnChar && !singleline) {
        if (bookmarked) win.color = BookmarkColor; else if (inBlock) win.color = blkClr;
      } else {
        if (inBlock) win.color = blkClr; else win.color = sltextClr;
      }
      if (ch == '\n') break;
      if (x < winw) {
        if (vt && ch == '\t') {
          int ex = ((x+tabsz)/tabsz)*tabsz;
          if (ex > 0) {
            int sz = ex-x;
            if (sz > 1) {
              win.writeCharsAt(x, y, 1, '<');
              win.writeCharsAt(x+1, y, sz-2, '-');
              win.writeCharsAt(ex-1, y, 1, '>');
            } else {
              win.writeCharsAt(x, y, 1, '\t');
            }
          }
          x = ex-1; // compensate the following increment
        } else if (!utfucked) {
          if (x >= 0) win.writeCharsAt(x, y, 1, recodeCharFrom(ch));
        } else {
          // utfuck
          --pos;
          if (x >= 0) {
            dchar dch = dcharAt(pos);
            if (dch > dchar.max || dch == 0xFFFD) {
              auto oc = win.color;
              scope(exit) win.color = oc;
              if (!inBlock) win.color = UtfuckedColor;
              win.writeCharsAt!true(x, y, 1, '\x7e'); // dot
            } else {
              win.writeCharsAt(x, y, 1, uni2koi(dch));
            }
          }
          pos += gb.utfuckLenAt(pos);
        }
        if (++x >= winw) return;
      }
    }
    if (x >= winw) return;
    if (x < 0) x = 0;
    if (pos >= ts) {
      win.color = TextColor;
      if (!killTextOnChar && !singleline) {
        if (bookmarked) win.color = BookmarkColor; else win.color = sltextClr;
      } else {
        win.color = sltextClr;
      }
    }
    win.writeCharsAt(x, y, winw-x, ' ');
  }

  // just clear line
  // use `winXXX` vars to know window dimensions
  public override void drawEmptyLine (int yofs) {
    auto win = XtWindow(winx, winy, winw, winh);
    if (singleline) {
      win.color = (clrText ? clrText : TextColor);
      if (killTextOnChar) win.color = (clrTextUnchanged ? clrTextUnchanged : TextKillColor);
    } else {
      win.color = TextColor;
    }
    win.writeCharsAt(0, yofs, winw, ' ');
  }

  public override void drawPageBegin () {
  }

  // check if line has only spaces (or comments, use highlighter) to begin/end (determined by dir)
  final bool lineHasOnlySpaces (int pos, int dir) {
    if (dir == 0) return false;
    dir = (dir < 0 ? -1 : 1);
    auto ts = textsize;
    if (ts == 0) return true; // wow, rare case
    if (pos < 0) { if (dir < 0) return true; pos = 0; }
    if (pos >= ts) { if (dir > 0) return true; pos = ts-1; }
    while (pos >= 0 && pos < ts) {
      auto ch = gb[pos];
      if (ch == '\n') break;
      if (ch > ' ') {
        // nonspace, check highlighting, if any
        if (hl !is null) {
          auto lidx = gb.pos2line(pos);
          if (hl.fixLine(lidx)) markLinesDirty(lidx, 1); // so it won't lost dirty flag in redraw
          if (!hiIsComment(gb.hi(pos))) return false;
          // ok, it is comment, it's the same as whitespace
        } else {
          return false;
        }
      }
      pos += dir;
    }
    return true;
  }

  // always starts at BOL
  final int lineFindFirstNonSpace (int pos) {
    auto ts = textsize;
    if (ts == 0) return 0; // wow, rare case
    pos = gb.line2pos(gb.pos2line(pos));
    while (pos < ts) {
      auto ch = gb[pos];
      if (ch == '\n') break;
      if (ch > ' ') {
        // nonspace, check highlighting, if any
        if (hl !is null) {
          auto lidx = gb.pos2line(pos);
          if (hl.fixLine(lidx)) markLinesDirty(lidx, 1); // so it won't lost dirty flag in redraw
          if (!hiIsComment(gb.hi(pos))) return pos;
          // ok, it is comment, it's the same as whitespace
        } else {
          return pos;
        }
      }
      ++pos;
    }
    return pos;
  }

  final void drawHiBracket (int pos, int lidx, char bch, char ech, int dir, bool drawline=false) {
    enum LineScanPages = 8;
    int level = 1;
    auto ts = gb.textsize;
    auto stpos = pos;
    int toplimit = (drawline ? mTopLine-winh*(LineScanPages-1) : mTopLine);
    int botlimit = (drawline ? mTopLine+winh*LineScanPages : mTopLine+winh);
    pos += dir;
    while (pos >= 0 && pos < ts) {
      auto ch = gb[pos];
      if (ch == '\n') {
        lidx += dir;
        if (lidx < toplimit || lidx >= botlimit) return;
        pos += dir;
        continue;
      }
      if (isAnyTextChar(pos, (dir > 0))) {
        if (ch == bch) {
          ++level;
        } else if (ch == ech) {
          if (--level == 0) {
            int rx, ry;
            gb.pos2xyVT(pos, rx, ry);
            if (rx >= mXOfs || rx < mXOfs+winw) {
              if (ry >= mTopLine && ry < mTopLine+winh) {
                auto win = XtWindow(winx, winy, winw, winh);
                win.color = BracketColor;
                win.writeCharsAt(rx-mXOfs, ry-mTopLine, 1, ech);
                markLinesDirty(ry, 1);
              }
              // draw line with opening bracket if it is out of screen
              if (drawline && dir < 0 && ry < mTopLine) {
                // line start
                int ls = pos;
                while (ls > 0 && gb[ls-1] != '\n') --ls;
                // skip leading spaces
                while (ls < pos && gb[ls] <= ' ') ++ls;
                // line end
                int le = pos+1;
                while (le < ts && gb[le] != '\n') ++le;
                // remove trailing spaces
                while (le > pos && gb[le-1] <= ' ') --le;
                if (ls < le) {
                  auto win = XtWindow(winx+1, winy-1, winw-1, 1);
                  win.color = XtColorFB!(TtyRgb2Color!(0x40, 0x40, 0x40), TtyRgb2Color!(0xb2, 0xb2, 0xb2)); // 0,7
                  win.writeCharsAt(0, 0, winw, ' ');
                  int x = 0;
                  while (x < winw && ls < le) {
                    win.writeCharsAt(x, 0, 1, uni2koi(gb.uniAt(ls)));
                    ls += gb.utfuckLenAt(ls);
                    ++x;
                  }
                }
              }
              if (drawline) {
                // draw vertical line
                int stx, sty, ls;
                if (dir > 0) {
                  // opening
                  // has some text after the bracket on the starting line?
                  //if (!lineHasOnlySpaces(stpos+1, 1)) return; // has text, can't draw
                  // find first non-space at the starting line
                  ls = lineFindFirstNonSpace(stpos);
                } else if (dir < 0) {
                  // closing
                  gb.pos2xyVT(stpos, rx, ry);
                  ls = lineFindFirstNonSpace(pos);
                }
                gb.pos2xyVT(ls, stx, sty);
                if (stx == rx) {
                  markLinesDirtySE(sty+1, ry-1);
                  rx -= mXOfs;
                  stx -= mXOfs;
                  ry -= mTopLine;
                  sty -= mTopLine;
                  auto win = XtWindow(winx, winy, winw, winh);
                  win.color = VLineColor;
                  win.vline(stx, sty+1, ry-sty-1);
                }
              }
            }
            return;
          }
        }
      }
      pos += dir;
    }
  }

  protected final void drawPartHighlight (int pos, int count, uint clr) {
    if (pos >= 0 && count > 0 && pos < gb.textsize) {
      int rx, ry;
      gb.pos2xyVT(pos, rx, ry);
      //auto oldclr = xtGetColor;
      //scope(exit) win.color = oldclr;
      if (ry >= topline && ry < topline+winh) {
        // visible, mark it
        auto win = XtWindow(winx, winy, winw, winh);
        win.color = clr;
        if (count > gb.textsize-pos) count = gb.textsize-pos;
        rx -= mXOfs;
        ry -= topline;
        //ry += winy;
        if (!utfuck) {
          foreach (immutable _; 0..count) {
            if (rx >= 0 && rx < winw) win.writeCharsAt(rx, ry, 1, recodeCharFrom(gb[pos++]));
            ++rx;
          }
        } else {
          int end = pos+count;
          while (pos < end) {
            if (rx >= winw) break;
            if (rx >= 0) {
              dchar dch = dcharAt(pos);
              if (dch > dchar.max || dch == 0xFFFD) {
                //auto oc = xtGetColor();
                //win.color = UtfuckedColor;
                win.writeCharsAt!true(rx, ry, 1, '\x7e'); // dot
              } else {
                win.writeCharsAt(rx, ry, 1, uni2koi(dch));
              }
            }
            ++rx;
            pos += gb.utfuckLenAt(pos);
          }
        }
      }
    }
  }

  public override void drawPageMisc () {
    auto pos = curpos;
    if (isAnyTextChar(pos, false)) {
      auto ch = gb[pos];
           if (ch == '(') drawHiBracket(pos, cy, ch, ')', 1);
      else if (ch == '{') drawHiBracket(pos, cy, ch, '}', 1, true);
      else if (ch == '[') drawHiBracket(pos, cy, ch, ']', 1);
      else if (ch == ')') drawHiBracket(pos, cy, ch, '(', -1);
      else if (ch == '}') drawHiBracket(pos, cy, ch, '{', -1, true);
      else if (ch == ']') drawHiBracket(pos, cy, ch, '[', -1);
    }
    // highlight search
    if (incSearchHitPos >= 0 && incSearchHitLen > 0 && incSearchHitPos < gb.textsize) {
      drawPartHighlight(incSearchHitPos, incSearchHitLen, IncSearchColor);
    }
    drawScrollBar();
  }

  public override void drawPageEnd () {
    if (mPromptActive) {
      auto win = XtWindow(winx, winy-(singleline || hideStatus ? 0 : 1), winw, 1);
      win.color = mPromptInput.clrText;
      win.writeCharsAt(0, 0, winw, ' ');
      win.writeStrAt(0, 0, mPromptPrompt[0..mPromptLen]);
      win.writeCharsAt(mPromptLen, 0, 1, ':');
      mPromptInput.fullDirty(); // force redraw
      mPromptInput.drawPage();
      return;
    }
  }

  //TODO: fix cx if current line was changed
  final void doUntabify (int tabSize=2) {
    if (mReadOnly || gb.textsize == 0) return;
    if (tabSize < 1 || tabSize > 255) return;
    int pos = 0;
    auto ts = gb.textsize;
    int curx = 0;
    while (pos < ts && gb[pos] != '\t') {
      if (gb[pos] == '\n') curx = 0; else ++curx;
      ++pos;
    }
    if (pos >= ts) return;
    undoGroupStart();
    scope(exit) undoGroupEnd();
    char[255] spaces = ' ';
    txchanged = true;
    while (pos < ts) {
      // replace space
      assert(gb[pos] == '\t');
      int spc = tabSize-(curx%tabSize);
      replaceText!"none"(pos, 1, spaces[0..spc]);
      // find next tab
      ts = gb.textsize;
      while (pos < ts && gb[pos] != '\t') {
        if (gb[pos] == '\n') curx = 0; else ++curx;
        ++pos;
      }
    }
    normXY();
  }

  //TODO: fix cx if current line was changed
  final void doRemoveTailingSpaces () {
    if (mReadOnly || gb.textsize == 0) return;
    bool wasChanged = false;
    scope(exit) if (wasChanged) undoGroupEnd();
    foreach (int lidx; 0..linecount) {
      auto ls = gb.linestart(lidx);
      auto le = gb.lineend(lidx); // points at '\n', or after text buffer
      int count = 0;
      while (le > ls && gb[le-1] <= ' ') { --le; ++count; }
      if (count == 0) continue;
      if (!wasChanged) { undoGroupStart(); wasChanged = true; }
      deleteText!"none"(le, count);
    }
    normXY();
  }

  // not string, not comment
  // if `goingDown` is true, update highlighting
  final bool isAnyTextChar (int pos, bool goingDown) {
    if (hl is null) return true;
    if (pos < 0 || pos >= gb.textsize) return false;
    // update highlighting
    if (goingDown && hl !is null) {
      auto lidx = gb.pos2line(pos);
      if (hl.fixLine(lidx)) markLinesDirty(lidx, 1); // so it won't lost dirty flag in redraw
      // ok, it is comment, it's the same as whitespace
    }
    switch (gb.hi(pos).kwtype) {
      case HiCommentOneLine:
      case HiCommentMulti:
      case HiChar:
      case HiCharSpecial:
      case HiString:
      case HiStringSpecial:
      case HiSQString:
      case HiSQStringSpecial:
      case HiBQString:
      case HiRQString:
        return false;
      default:
    }
    return true;
  }

  final bool isInComment (int pos) {
    if (hl is null || pos < 0 || pos >= gb.textsize) return false;
    return hiIsComment(gb.hi(pos));
  }

  final bool isACGoodWordChar (int pos) {
    if (pos < 0 || pos >= gb.textsize) return false;
    if (!isWordChar(gb[pos])) return false;
    if (hl !is null) {
      // don't autocomplete in strings
      switch (gb.hi(pos).kwtype) {
        case HiNumber:
        case HiChar:
        case HiCharSpecial:
        case HiString:
        case HiStringSpecial:
        case HiSQString:
        case HiSQStringSpecial:
        case HiBQString:
        case HiRQString:
          return false;
        default:
      }
    }
    return true;
  }

  final void doAutoComplete () {
    scope(exit) {
      acused = 0;
      if (acbuffer.length > 0) {
        acbuffer.length = 0;
        acbuffer.assumeSafeAppend;
      }
    }

    void addAcToken (const(char)[] tk) {
      if (tk.length == 0) return;
      foreach (const(char)[] t; aclist[0..acused]) if (t == tk) return;
      if (acused >= aclist.length) return;
      // add to buffer
      auto pos = acbuffer.length;
      acbuffer ~= tk;
      aclist[acused++] = acbuffer[pos..$];
    }

    import std.ascii : isAlphaNum;
    // get token to autocomplete
    auto pos = curpos;
    if (!isACGoodWordChar(pos-1)) return;
    //debug(egauto) { { import iv.vfs; auto fo = VFile("z00_ch.bin", "w"); fo.write(ch); } }
    bool startedInComment = isInComment(pos-1);
    char[128] tk = void;
    int tkpos = cast(int)tk.length;
    while (pos > 0 && isACGoodWordChar(pos-1)) {
      if (tkpos == 0) return;
      tk.ptr[--tkpos] = gb[--pos];
    }
    int tklen = cast(int)tk.length-tkpos;
    auto tkstpos = pos;
    //HACK: try "std.algo"
    if (gb[pos-1] == '.' && gb[pos-2] == 'd' && gb[pos-3] == 't' && gb[pos-4] == 's' && !isACGoodWordChar(pos-5)) {
      if (tk[$-tklen..$] == "algo") {
        tkstpos += tklen;
        string ntx = "rithm";
        // insert new token
        replaceText!"end"(tkstpos, 0, ntx);
        return;
      }
    }
    //debug(egauto) { { import iv.vfs; auto fo = VFile("z00_tk.bin", "w"); fo.write(tk[$-tklen..$]); } }
    // build token list
    char[128] xtk = void;
    while (pos > 0) {
      while (pos > 0 && !isACGoodWordChar(pos-1)) --pos;
      if (pos <= 0) break;
      int xtp = cast(int)xtk.length;
      while (pos > 0 && isACGoodWordChar(pos-1)) {
        if (xtp > 0) {
          xtk.ptr[--xtp] = gb[--pos];
        } else {
          xtp = -1;
          --pos;
        }
      }
      if (xtp >= 0 && isInComment(pos) == startedInComment) {
        int xlen = cast(int)xtk.length-xtp;
        if (xlen > tklen) {
          import core.stdc.string : memcmp;
          if (memcmp(xtk.ptr+xtk.length-xlen, tk.ptr+tk.length-tklen, tklen) == 0) {
            const(char)[] tt = xtk[$-xlen..$];
            addAcToken(tt);
            if (acused >= 128) break;
          }
        }
      }
    }
    debug(egauto) { { import iv.vfs; auto fo = VFile("z00_list.bin", "w"); fo.writeln(list[]); } }
    const(char)[] acp;
    if (acused == 0) return;
    if (acused == 1) {
      acp = aclist[0];
    } else {
      int rx, ry;
      gb.pos2xyVT(tkstpos, rx, ry);
      //int residx = promptSelect(aclist[0..acused], winx+(rx-mXOfs), winy+(ry-mTopLine)+1);
      int residx = dialogSelectAC(aclist[0..acused], winx+(rx-mXOfs), winy+(ry-mTopLine)+1);
      if (residx < 0) return;
      acp = aclist[residx];
    }
    if (mReadOnly) return;
    replaceText!"end"(tkstpos, tklen, acp);
  }

  final char[] buildHelpText(this ME) () {
    char[] res;
    void buildHelpFor(UDA) () {
      foreach (string memn; __traits(allMembers, ME)) {
        static if (is(typeof(__traits(getMember, ME, memn)))) {
          foreach (const attr; __traits(getAttributes, __traits(getMember, ME, memn))) {
            static if (is(typeof(attr) == UDA)) {
              static if (!attr.hidden && attr.help.length && attr.key.length) {
                // check modifiers
                bool goodMode = true;
                foreach (const attrx; __traits(getAttributes, __traits(getMember, ME, memn))) {
                       static if (is(attrx == TEDSingleOnly)) { if (!singleline) goodMode = false; }
                  else static if (is(attrx == TEDMultiOnly)) { if (singleline) goodMode = false; }
                  else static if (is(attrx == TEDEditOnly)) { if (readonly) goodMode = false; }
                  else static if (is(attrx == TEDROOnly)) { if (!readonly) goodMode = false; }
                }
                if (goodMode) {
                  //res ~= "|";
                  res ~= attr.key;
                  foreach (immutable _; attr.key.length..12) res ~= ".";
                  //res ~= "|";
                  res ~= " ";
                  res ~= attr.help;
                  res ~= "\n";
                }
              }
            }
          }
        }
      }
    }
    buildHelpFor!TEDKey;
    while (res.length && res[$-1] <= ' ') res = res[0..$-1];
    return res;
  }

  protected enum Ecc { None, Eaten, Combo }

  // None: not valid
  // Eaten: exact hit
  // Combo: combo start
  // comboBuf should contain comboCount+1 keys!
  protected final Ecc checkKeys (const(char)[] keys) {
    TtyEvent k;
    // check if current combo prefix is ok
    foreach (const ref TtyEvent ck; comboBuf[0..comboCount+1]) {
      keys = TtyEvent.parse(k, keys);
      if (k.key == TtyEvent.Key.Error || k.key == TtyEvent.Key.None || k.key == TtyEvent.Key.Unknown) return Ecc.None;
      if (k != ck) return Ecc.None;
    }
    return (keys.length == 0 ? Ecc.Eaten : Ecc.Combo);
  }

  // fuck! `(this ME)` trick doesn't work here
  protected final Ecc doEditorCommandByUDA(ME=typeof(this)) (TtyEvent key) {
    import std.traits;
    if (key.key == TtyEvent.Key.None) return Ecc.None;
    if (key.key == TtyEvent.Key.Error || key.key == TtyEvent.Key.Unknown) { repeatCounter = -1; comboCount = 0; return Ecc.None; }
    // process repeat counter
    if (repeatCounter >= 0) {
      // cancel counter mode?
      if (key == "C-C" || key == "C-G") { repeatCounter = -1; return Ecc.Eaten; }
      if (key == "C-Space") { repeatCounterMode = -1; return Ecc.None; } // so C-Space can allow insert alot of numbers, for example
      if (key.key == TtyEvent.Key.Char && key.ch >= '0' && key.ch <= '9') {
        // digit
        if (repeatCounterMode < 0) return Ecc.None; // previous was C-Space
        if (repeatCounterMode > 0) repeatCounter = 0;
        repeatCounter = repeatCounter*10+key.ch-'0';
        repeatCounterMode = 0;
        return Ecc.Combo;
      }
      if (repeatCounterMode < 0) repeatCounterMode = 0;
    }
    // normal key processing
    bool possibleCombo = false;
    // temporarily add current key to combo
    comboBuf[comboCount] = key;
    // check all known combos
    foreach (string memn; __traits(allMembers, ME)) {
      static if (is(typeof(&__traits(getMember, ME, memn)))) {
        import std.meta : AliasSeq;
        alias mx = AliasSeq!(__traits(getMember, ME, memn))[0];
        static if (isCallable!mx && hasUDA!(mx, TEDKey)) {
          // check modifiers
          bool goodMode = true;
          static if (hasUDA!(mx, TEDSingleOnly)) { if (!singleline) goodMode = false; }
          static if (hasUDA!(mx, TEDMultiOnly)) { if (singleline) goodMode = false; }
          static if (hasUDA!(mx, TEDEditOnly)) { if (readonly) goodMode = false; }
          static if (hasUDA!(mx, TEDROOnly)) { if (!readonly) goodMode = false; }
          if (goodMode) {
            foreach (const TEDKey attr; getUDAs!(mx, TEDKey)) {
              auto cc = checkKeys(attr.key);
              if (cc == Ecc.Eaten) {
                // hit
                static if (is(ReturnType!mx == void)) {
                  comboCount = 0; // reset combo
                  static if (hasUDA!(mx, TEDRepeated)) {
                    scope(exit) repeatCounter = -1; // reset counter
                    if (repeatCounter < 0) repeatCounter = 1; // no counter means 1
                    foreach (immutable _; 0..repeatCounter) mx();
                  } else {
                    static if (!hasUDA!(mx, TEDRepeatChar)) repeatCounter = -1;
                    mx();
                  }
                  return Ecc.Eaten;
                } else {
                  static if (hasUDA!(mx, TEDRepeated)) {
                    if (repeatCounter != 0 && mx()) {
                      scope(exit) repeatCounter = -1; // reset counter
                      if (repeatCounter < 0) repeatCounter = 1; // no counter means 1
                      comboCount = 0; // reset combo
                      foreach (immutable _; 1..repeatCounter) if (!mx()) break;
                      return Ecc.Eaten;
                    }
                  } else {
                    static if (!hasUDA!(mx, TEDRepeatChar)) repeatCounter = -1;
                    if (mx()) {
                      repeatCounter = -1; // reset counter
                      comboCount = 0; // reset combo
                      return Ecc.Eaten;
                    }
                  }
                }
              } else if (cc == Ecc.Combo) {
                possibleCombo = true;
              }
            }
          }
        }
      }
    }
    // check if we can start/continue combo
    // combo can't start with normal char, but can include normal chars
    if (possibleCombo && (comboCount > 0 || key.key != TtyEvent.Key.Char)) {
      if (++comboCount < comboBuf.length-1) return Ecc.Combo;
    }
    // if we have combo prefix, eat key unconditionally
    if (comboCount > 0) {
      repeatCounter = -1; // reset counter
      comboCount = 0; // reset combo, too long, or invalid, or none
      return Ecc.Eaten;
    }
    return Ecc.None;
  }

  void doCounterMode () {
    if (waitingInF5) { repeatCounter = -1; return; }
    if (repeatCounter < 0) {
      // start counter mode
      repeatCounter = 1;
      repeatCounterMode = 1; // just started
    } else {
      repeatCounter *= 2; // so ^P will multiply current counter
    }
  }

  bool processKey (TtyEvent key) {
    // hack it here, so it won't interfere with normal keyboard processing
    if (key.key == TtyEvent.Key.PasteStart) { doPasteStart(); return true; }
    if (key.key == TtyEvent.Key.PasteEnd) { doPasteEnd(); return true; }

    if (waitingInF5) {
      waitingInF5 = false;
      if (key == "enter") {
        if (tempBlockFileName.length) {
          try { doBlockRead(tempBlockFileName); } catch (Exception) {} // sorry
        }
      }
      return true;
    }

    if (key.key == TtyEvent.Key.Error || key.key == TtyEvent.Key.Unknown) { repeatCounter = -1; comboCount = 0; return false; }

    if (incInputActive) {
      if (key.key == TtyEvent.Key.ModChar) {
        if (key == "C-C") { incInputActive = false; resetIncSearchPos(); promptNoKillText(); return true; }
        if (key == "C-R") { incSearchDir = 1; doNextIncSearch(); promptNoKillText(); return true; }
        if (key == "C-V") { incSearchDir = -1; doNextIncSearch(); promptNoKillText(); return true; }
        //return true;
      }
      if (key == "esc" || key == "enter") {
        incInputActive = false;
        promptDeactivate();
        resetIncSearchPos();
        return true;
      }
      if (mPromptInput !is null) mPromptInput.utfuck = utfuck;
      promptProcessKey(key, delegate (ed) {
        // input buffer changed
        // check if it was *really* changed
        if (incSearchBuf.length == ed.textsize) {
          int pos = 0;
          foreach (char ch; ed[]) { if (incSearchBuf[pos] != ch) break; ++pos; }
          if (pos >= ed.textsize) return; // nothing was changed, so nothing to do
        }
        // recollect it
        incSearchBuf.length = 0;
        incSearchBuf.assumeSafeAppend;
        foreach (char ch; ed[]) incSearchBuf ~= ch;
        doNextIncSearch(false); // don't move pointer
      });
      drawStatus(); // just in case
      return true;
    }

    resetIncSearchPos();

    final switch (doEditorCommandByUDA(key)) {
      case Ecc.None: break;
      case Ecc.Combo:
      case Ecc.Eaten:
        return true;
    }

    if (key.key == TtyEvent.Key.Char) {
      scope(exit) repeatCounter = -1; // reset counter
      if (readonly) return false;
      if (repeatCounter != 0) {
        if (repeatCounter < 0) repeatCounter = 1;
        if (repeatCounter > 1) {
          undoGroupStart();
          scope(exit) undoGroupEnd();
          foreach (immutable _; 0..repeatCounter) doPutChar(cast(char)key.ch);
        } else {
          doPutChar(cast(char)key.ch);
        }
      }
      return true;
    }

    return false;
  }

  bool processClick (int button, int x, int y) {
    if (x < 0 || y < 0 || x >= winw || y >= winh) return false;
    if (button != 0) return false;
    gotoXY(x, topline+y);
    return true;
  }

final:
  void pasteToX11 () {
    import std.file;
    import std.process;
    import std.regex;
    import std.stdio;

    if (!hasMarkedBlock) return;

    void doPaste (string cbkey) {
      try {
        string[string] moreEnv;
        moreEnv["K8_SUBSHELL"] = "tan";
        auto pp = std.process.pipeProcess(
          //["dmd", "-c", "-o-", "-verrors=64", "-vcolumns", fname],
          ["xsel", "-i", cbkey],
          std.process.Redirect.stderrToStdout|std.process.Redirect.stdout|std.process.Redirect.stdin,
          moreEnv,
          std.process.Config.none,
          null, //workdir
        );
        pp.stdout.close();
        auto rng = markedBlockRange;
        foreach (char ch; rng) pp.stdin.write(ch);
        pp.stdin.flush();
        pp.stdin.close();
        pp.pid.wait;
      } catch (Exception) {}
    }

    doPaste("-p");
    doPaste("-s");
    doPaste("-b");
  }

  static struct PlainMatch {
    int s, e;
    @property bool empty () const pure nothrow @safe @nogc { return (s < 0 || s >= e); }
  }

  // epos is not included
  final PlainMatch findTextPlain (const(char)[] pat, int spos, int epos, bool words, bool caseSens) {
    PlainMatch res;
    immutable ts = gb.textsize;
    if (pat.length == 0 || pat.length > ts) return res;
    if (epos <= spos || spos >= ts) return res;
    if (spos < 0) spos = 0;
    if (epos < 0) epos = 0;
    if (epos > ts) epos = ts;
    immutable bl = cast(int)pat.length;
    //dialogMessage!"debug"("findTextPlain", "spos=%s; epos=%s; ts=%s; curpos=%s; pat:[%s]", spos, epos, ts, curpos, pat);
    while (ts-spos >= bl) {
      if (caseSens || !pat.ptr[0].isalpha) {
        spos = gb.fastFindChar(spos, pat.ptr[0]);
        if (ts-spos < bl) break;
      }
      bool found = true;
      if (caseSens) {
        foreach (int p; spos..spos+bl) if (gb[p] != pat.ptr[p-spos]) { found = false; break; }
      } else {
        foreach (int p; spos..spos+bl) if (gb[p].tolower != pat.ptr[p-spos].tolower) { found = false; break; }
      }
      // check word boundaries
      if (found && words) {
        if (spos > 0 && isWordChar(gb[spos-1])) found = false;
        int ep = spos+bl;
        if (ep < ts && isWordChar(gb[ep])) found = false;
      }
      //dialogMessage!"debug"("findTextPlain", "spos=%s; epos=%s; found=%s", spos, epos, found);
      if (found) {
        res.s = spos;
        res.e = spos+bl;
        break;
      }
      ++spos;
    }
    return res;
  }

  // epos is not included
  final PlainMatch findTextPlainBack (const(char)[] pat, int spos, int epos, bool words, bool caseSens) {
    PlainMatch res;
    immutable ts = gb.textsize;
    if (pat.length == 0 || pat.length > ts) return res;
    if (epos <= spos || spos >= ts) return res;
    if (spos < 0) spos = 0;
    if (epos < 0) epos = 0;
    if (epos > ts) epos = ts;
    immutable bl = cast(int)pat.length;
    if (ts-epos < bl) epos = ts-bl;
    while (epos >= spos) {
      bool found = true;
      if (caseSens) {
        foreach (int p; epos..epos+bl) if (gb[p] != pat.ptr[p-epos]) { found = false; break; }
      } else {
        foreach (int p; epos..epos+bl) if (gb[p].tolower != pat.ptr[p-epos].tolower) { found = false; break; }
      }
      if (found && words) {
        if (epos > 0 && isWordChar(gb[epos-1])) found = false;
        int ep = epos+bl;
        if (ep < ts && isWordChar(gb[ep])) found = false;
      }
      if (found) {
        res.s = epos;
        res.e = epos+bl;
        break;
      }
      --epos;
    }
    return res;
  }

  // epos is not included
  // caps are fixed so it can be used to index gap buffer
  final bool findTextRegExp (RegExp re, int spos, int epos, Pike.Capture[] caps) {
    Pike.Capture[1] tcaps;
    if (epos <= spos || spos >= textsize) return false;
    if (caps.length == 0) caps = tcaps;
    if (spos < 0) spos = 0;
    if (epos < 0) epos = 0;
    if (epos > textsize) epos = textsize;
    auto ctx = Pike.create(re, caps);
    if (!ctx.valid) return false;
    int res = SRes.Again;
    foreach (const(char)[] buf; gb.bufparts(spos)) {
      res = ctx.exec(buf, false);
      if (res < 0) {
        if (res != SRes.Again) return false;
      } else {
        break;
      }
    }
    if (res < 0) return false;
    if (spos+caps[0].s >= epos) return false;
    if (spos+caps[0].e > epos) return false;
    foreach (ref cp; caps) if (cp.s < cp.e) { cp.s += spos; cp.e += spos; }
    return true;
  }

  // epos is not included
  // caps are fixed so it can be used to index gap buffer
  final bool findTextRegExpBack (RegExp re, int spos, int epos, Pike.Capture[] caps) {
    import core.stdc.string : memcpy;
    MemPool csave;
    Pike.Capture* savedCaps;
    Pike.Capture[1] tcaps;
    if (epos <= spos || spos >= textsize) return false;
    if (caps.length == 0) caps = tcaps;
    if (spos < 0) spos = 0;
    if (epos < 0) epos = 0;
    if (epos > textsize) epos = textsize;
    while (spos < epos) {
      auto ctx = Pike.create(re, caps);
      if (!ctx.valid) break;
      int res = SRes.Again;
      foreach (const(char)[] buf; gb.bufparts(spos)) {
        res = ctx.exec(buf, false);
        if (res < 0) {
          if (res != SRes.Again) return false;
        } else {
          break;
        }
      }
      if (spos+caps[0].s >= epos) break;
      //dialogMessage!"debug"("findTextRegexpBack", "spos=%s; epos=%s; found=%s", spos, epos, spos+caps[0].s);
      // save this hit
      if (savedCaps is null) {
        if (!csave.active) {
          csave = MemPool.create;
          if (!csave.active) return false; // alas
          savedCaps = csave.alloc!(typeof(caps[0]))(cast(uint)(caps[0].sizeof*(caps.length-1)));
          if (savedCaps is null) return false; // alas
        }
      }
      // fix it
      foreach (ref cp; caps) if (cp.s < cp.e) { cp.s += spos; cp.e += spos; }
      memcpy(savedCaps, caps.ptr, caps[0].sizeof*caps.length);
      //FIXME: should we skip the whole found match?
      spos = caps[0].s+1;
    }
    if (savedCaps is null) return false;
    // restore latest match
    memcpy(caps.ptr, savedCaps, caps[0].sizeof*caps.length);
    return true;
  }

  final void srrPlain (in ref SearchReplaceOptions srr) {
    if (srr.search.length == 0) return;
    if (srr.inselection && !hasMarkedBlock) return;
    scope(exit) fullDirty(); // to remove highlighting
    bool closeGroup = false;
    scope(exit) if (closeGroup) undoGroupEnd();
    bool doAll = false;
    // epos will be fixed on replacement
    int spos, epos;
    if (srr.inselection) {
      spos = bstart;
      epos = bend;
    } else {
      if (!srr.backwards) {
        // forward
        spos = curpos;
        epos = textsize;
      } else {
        // backward
        spos = 0;
        epos = curpos;
      }
    }
    int count = 0;
    while (spos < epos) {
      PlainMatch mt;
      if (srr.backwards) {
        mt = findTextPlainBack(srr.search, spos, epos, srr.wholeword, srr.casesens);
      } else {
        mt = findTextPlain(srr.search, spos, epos, srr.wholeword, srr.casesens);
      }
      if (mt.empty) break;
      // if i need to skip comments, do highlighting
      if (srr.nocomments && hl !is null) {
        auto lidx = gb.pos2line(mt.s);
        if (hl.fixLine(lidx)) markLinesDirty(lidx, 1); // so it won't lost dirty flag in redraw
        if (hiIsComment(gb.hi(mt.s))) {
          // skip
          if (!srr.backwards) spos = mt.s+1; else epos = mt.s;
          continue;
        }
      }
      // i found her!
      if (!doAll) {
        bool doundo = (mt.s != curpos);
        if (doundo) gotoPos!true(mt.s);
        fullDirty();
        drawPage();
        drawPartHighlight(mt.s, mt.e-mt.s, IncSearchColor);
        auto act = dialogReplacePrompt(gb.pos2line(mt.s)-topline+winy);
        //FIXME: do undo only if it was succesfully registered
        //doUndo(); // undo cursor movement
        if (act == DialogRepPromptResult.Cancel) break;
        //if (doundo) doUndo();
        if (act == DialogRepPromptResult.Skip) {
          if (!srr.backwards) spos = mt.s+1; else epos = mt.s;
          continue;
        }
        if (act == DialogRepPromptResult.All) { doAll = true; }
      }
      if (doAll && !closeGroup) { undoGroupStart(); closeGroup = true; }
      replaceText!"end"(mt.s, mt.e-mt.s, srr.replace);
      // fix search range
      if (!srr.backwards) {
        // forward
        spos = mt.s+cast(int)srr.replace.length;
        epos -= (mt.e-mt.s)-cast(int)srr.replace.length;
      } else {
        epos = mt.s;
      }
      if (doAll) ++count;
    }
    if (doAll) {
      fullDirty();
      drawPage();
      dialogMessage!"info"("Search and Replace", "%s replacement%s made", count, (count != 1 ? "s" : ""));
    }
  }

  final void srrRegExp (in ref SearchReplaceOptions srr) {
    import std.utf : byChar;
    if (srr.search.length == 0) return;
    if (srr.inselection && !hasMarkedBlock) return;
    auto re = RegExp.create(srr.search.byChar, (srr.casesens ? 0 : SRFlags.CaseInsensitive)|SRFlags.Multiline);
    if (!re.valid) { ttyBeep; return; }
    scope(exit) fullDirty(); // to remove highlighting
    bool closeGroup = false;
    scope(exit) if (closeGroup) undoGroupEnd();
    bool doAll = false;
    // epos will be fixed on replacement
    int spos, epos;

    if (srr.inselection) {
      spos = bstart;
      epos = bend;
    } else {
      if (!srr.backwards) {
        // forward
        spos = curpos;
        epos = textsize;
      } else {
        // backward
        spos = 0;
        epos = curpos;
      }
    }
    Pike.Capture[64] caps; // max captures

    char[] newtext; // will be aggressively reused!
    scope(exit) { delete newtext; newtext.length = 0; }

    int rereplace () {
      if (newtext.length) { newtext.length = 0; newtext.assumeSafeAppend; }
      auto reps = srr.replace;
      int spos = 0;
      mainloop: while (spos < reps.length) {
        if ((reps[spos] == '$' || reps[spos] == '\\') && reps.length-spos > 1 && reps[spos+1].isdigit) {
          int n = reps[spos+1]-'0';
          spos += 2;
          if (!caps[n].empty) foreach (char ch; this[caps[n].s..caps[n].e]) newtext ~= ch;
        } else if ((reps[spos] == '$' || reps[spos] == '\\') && reps.length-spos > 2 && reps[spos+1] == '{' && reps[spos+2].isdigit) {
          bool toupper, tolower, capitalize, uncapitalize;
          spos += 2;
          int n = 0;
          // parse number
          while (spos < reps.length && reps[spos].isdigit) n = n*10+reps[spos++]-'0';
          while (spos < reps.length && reps[spos] != '}') {
            switch (reps[spos++]) {
              case 'u': case 'U': toupper = true; tolower = false; break;
              case 'l': case 'L': tolower = true; toupper = false; break;
              case 'C': capitalize = true; break;
              case 'c': uncapitalize = true; break;
              default: // ignore other flags
            }
          }
          if (spos < reps.length && reps[spos] == '}') ++spos;
          if (n < caps.length && !caps[n].empty) {
            int tp = caps[n].s, ep = caps[n].e;
            char ch = gb[tp++];
                 if (capitalize || toupper) ch = ch.toupper;
            else if (uncapitalize || tolower) ch = ch.tolower;
            newtext ~= ch;
            while (tp < ep) {
              ch = gb[tp++];
                   if (toupper) ch = ch.toupper;
              else if (tolower) ch = ch.tolower;
              newtext ~= ch;
            }
          }
        } else if (reps[spos] == '\\' && reps.length-spos > 1) {
          spos += 2;
          switch (reps[spos-1]) {
            case 't': newtext ~= '\t'; break;
            case 'n': newtext ~= '\n'; break;
            case 'r': newtext ~= '\r'; break;
            case 'a': newtext ~= '\a'; break;
            case 'b': newtext ~= '\b'; break;
            case 'e': newtext ~= '\x1b'; break;
            case 'x': case 'X':
              if (reps.length-spos < 1) break mainloop;
              int n = digitInBase(reps[spos], 16);
              if (n < 0) break;
              ++spos;
              if (reps.length-spos > 0 && digitInBase(reps[spos], 16) >= 0) {
                n = n*16+digitInBase(reps[spos], 16);
                ++spos;
              }
              newtext ~= cast(char)n;
              break;
            default:
              newtext ~= reps[spos-1];
              break;
          }
        } else {
          newtext ~= reps[spos++];
        }
      }
      replaceText!"end"(caps[0].s, caps[0].e-caps[0].s, newtext);
      return cast(int)newtext.length;
    }

    int count = 0;
    while (spos < epos) {
      bool found;
      if (srr.backwards) {
        found = findTextRegExpBack(re, spos, epos, caps[]);
      } else {
        found = findTextRegExp(re, spos, epos, caps[]);
      }
      if (!found) break;
      // i found her!
      if (srr.nocomments && hl !is null) {
        auto lidx = gb.pos2line(caps[0].s);
        if (hl.fixLine(lidx)) markLinesDirty(lidx, 1); // so it won't lost dirty flag in redraw
        if (hiIsComment(gb.hi(caps[0].s))) {
          // skip
          if (!srr.backwards) spos = caps[0].s+1; else epos = caps[0].s;
          continue;
        }
      }
      if (!doAll) {
        bool doundo = (caps[0].s != curpos);
        if (doundo) gotoPos!true(caps[0].s);
        fullDirty();
        drawPage();
        drawPartHighlight(caps[0].s, caps[0].e-caps[0].s, IncSearchColor);
        auto act = dialogReplacePrompt(gb.pos2line(caps[0].s)-topline+winy);
        //FIXME: do undo only if it was succesfully registered
        //doUndo(); // undo cursor movement
        if (act == DialogRepPromptResult.Cancel) break;
        //if (doundo) doUndo();
        if (act == DialogRepPromptResult.Skip) {
          if (!srr.backwards) spos = caps[0].s+1; else epos = caps[0].s;
          continue;
        }
        if (act == DialogRepPromptResult.All) { doAll = true; }
      }
      if (doAll && !closeGroup) { undoGroupStart(); closeGroup = true; }
      int replen = rereplace();
      // fix search range
      if (!srr.backwards) {
        spos = caps[0].s+(replen ? replen : 1);
        epos += replen-(caps[0].e-caps[0].s);
      } else {
        epos = caps[0].s;
      }
      if (doAll) ++count;
    }
    if (doAll) {
      fullDirty();
      drawPage();
      dialogMessage!"info"("Search and Replace", "%s replacement%s made", count, (count != 1 ? "s" : ""));
    }
  }

final:
  void processWordWith (scope char delegate (char ch) dg) {
    if (dg is null) return;
    bool undoAdded = false;
    scope(exit) if (undoAdded) undoGroupEnd();
    auto pos = curpos;
    if (!isWordChar(gb[pos])) return;
    // find word start
    while (pos > 0 && isWordChar(gb[pos-1])) --pos;
    while (pos < gb.textsize) {
      auto ch = gb[pos];
      if (!isWordChar(gb[pos])) break;
      auto nc = dg(ch);
      if (ch != nc) {
        if (!undoAdded) { undoAdded = true; undoGroupStart(); }
        replaceText!"none"(pos, 1, (&nc)[0..1]);
      }
      ++pos;
    }
    gotoPos(pos);
  }

final:
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("Up", q{ doUp(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-Up", q{ doUp(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-Up", q{ doScrollUp(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-C-Up", q{ doScrollUp(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("Down", q{ doDown(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-Down", q{ doDown(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-Down", q{ doScrollDown(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-C-Down", q{ doScrollDown(true); });

  @TEDRepeated mixin TEDImpl!("Left", q{ doLeft(); });
  @TEDRepeated mixin TEDImpl!("S-Left", q{ doLeft(true); });

  @TEDRepeated mixin TEDImpl!("C-Left", q{ doWordLeft(); });
  @TEDRepeated mixin TEDImpl!("S-C-Left", q{ doWordLeft(true); });
  @TEDRepeated mixin TEDImpl!("Right", q{ doRight(); });
  @TEDRepeated mixin TEDImpl!("S-Right", q{ doRight(true); });
  @TEDRepeated mixin TEDImpl!("C-Right", q{ doWordRight(); });
  @TEDRepeated mixin TEDImpl!("S-C-Right", q{ doWordRight(true); });

  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("PageUp", q{ doPageUp(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-PageUp", q{ doPageUp(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-PageUp", q{ doTextTop(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-C-PageUp", q{ doTextTop(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("PageDown", q{ doPageDown(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-PageDown", q{ doPageDown(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-PageDown", q{ doTextBottom(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-C-PageDown", q{ doTextBottom(true); });
                @TEDRepeated mixin TEDImpl!("Home", q{ doHome(); });
                @TEDRepeated mixin TEDImpl!("S-Home", q{ doHome(true, true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-Home", q{ doPageTop(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-C-Home", q{ doPageTop(true); });
                @TEDRepeated mixin TEDImpl!("End", q{ doEnd(); });
                @TEDRepeated mixin TEDImpl!("S-End", q{ doEnd(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-End", q{ doPageBottom(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("S-C-End", q{ doPageBottom(true); });

  @TEDEditOnly @TEDRepeated mixin TEDImpl!("Backspace", q{ doBackspace(); });
  @TEDSingleOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-Backspace", "delete previous word", q{ doDeleteWord(); });
  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-Backspace", "delete previous word or unindent", q{ doBackByIndent(); });

  @TEDRepeated mixin TEDImpl!("Delete", q{ doDelete(); });
  mixin TEDImpl!("C-Insert", "copy block to clipboard file, reset block mark", q{ if (tempBlockFileName.length == 0) return; doBlockWrite(tempBlockFileName); doBlockResetMark(); });

  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("Enter", q{ doPutChar('\n'); });
  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-Enter", "split line without autoindenting", q{ doLineSplit(false); });


  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("F2", "save file", q{ saveFile(fullFileName); });
  mixin TEDImpl!("F3", "start/stop/reset block marking", q{ doToggleBlockMarkMode(); });
  mixin TEDImpl!("C-F3", "reset block mark", q{ doBlockResetMark(); });
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("F4", "search and relace text", q{
    srrOptions.inselenabled = hasMarkedBlock;
    srrOptions.utfuck = utfuck;
    if (!dialogSearchReplace(hisman, srrOptions)) return;
    if (srrOptions.type == SearchReplaceOptions.Type.Normal) { srrPlain(srrOptions); return; }
    if (srrOptions.type == SearchReplaceOptions.Type.Regex) { srrRegExp(srrOptions); return; }
    dialogMessage!"error"("Not Yet", "This S&R type is not supported yet!");
  });
  @TEDEditOnly mixin TEDImpl!("F5", "copy block", q{ doBlockCopy(); });
               mixin TEDImpl!("C-F5", "copy block to clipboard file", q{ if (tempBlockFileName.length == 0) return; doBlockWrite(tempBlockFileName); });
  @TEDEditOnly mixin TEDImpl!("S-F5", "insert block from clipboard file", q{ if (tempBlockFileName.length == 0) return; waitingInF5 = true; });
  @TEDEditOnly mixin TEDImpl!("F6", "move block", q{ doBlockMove(); });
  @TEDEditOnly mixin TEDImpl!("F8", "delete block", q{ doBlockDelete(); });

  mixin TEDImpl!("C-A", "move to line start", q{ doHome(); });
  mixin TEDImpl!("C-E", "move to line end", q{ doEnd(); });

  @TEDMultiOnly mixin TEDImpl!("M-I", "jump to previous bookmark", q{ doBookmarkJumpUp(); });
  @TEDMultiOnly mixin TEDImpl!("M-J", "jump to next bookmark", q{ doBookmarkJumpDown(); });
  @TEDMultiOnly mixin TEDImpl!("M-K", "toggle bookmark", q{ doBookmarkToggle(); });
  @TEDMultiOnly mixin TEDImpl!("M-L", "goto line", q{
    auto lnum = dialogLineNumber(hisman);
    if (lnum > 0 && lnum < linecount) gotoXY!true(curx, lnum-1); // vcenter
  });

  @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-C", "capitalize word", q{
    bool first = true;
    processWordWith((char ch) {
      if (first) { first = false; ch = ch.toupper; }
      return ch;
    });
  });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-Q", "lowercase word", q{ processWordWith((char ch) => ch.tolower); });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-U", "uppercase word", q{ processWordWith((char ch) => ch.toupper); });

  @TEDMultiOnly mixin TEDImpl!("M-S-L", "force center current line", q{ makeCurLineVisibleCentered(true); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-R", "continue incremental search, forward", q{ incSearchDir = 1; if (incSearchBuf.length == 0 && !incInputActive) doStartIncSearch(1); else doNextIncSearch(); });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-U", "undo", q{ doUndo(); });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("M-S-U", "redo", q{ doRedo(); });
  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-V", "continue incremental search, backward", q{ incSearchDir = -1; if (incSearchBuf.length == 0 && !incInputActive) doStartIncSearch(-1); else doNextIncSearch(); });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-W", "remove previous word", q{ doDeleteWord(); });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-Y", "remove current line", q{ doKillLine(); });
  @TEDMultiOnly mixin TEDImpl!("C-_", "start new incremental search, forward", q{ doStartIncSearch(1); }); // ctrl+slash, actually
  @TEDMultiOnly mixin TEDImpl!("C-\\", "start new incremental search, backward", q{ doStartIncSearch(-1); });

  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("Tab", q{ doPutText("  "); });
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("M-Tab", "autocomplete word", q{ doAutoComplete(); });
  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-Tab", "indent block", q{ doIndentBlock(); });
  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-S-Tab", "unindent block", q{ doUnindentBlock(); });

  mixin TEDImpl!("M-S-c", "copy block to X11 selections (all three)", q{ pasteToX11(); doBlockResetMark(); });

  @TEDMultiOnly mixin TEDImpl!("M-E", "select codepage", q{
    auto ncp = dialogCodePage(utfuck ? 3 : codepage);
    if (ncp < 0) return;
    if (ncp > CodePage.max) { utfuck = true; return; }
    utfuck = false;
    codepage = cast(CodePage)ncp;
    fullDirty();
  });

  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-K C-I", "indent block", q{ doIndentBlock(); });
  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-K C-U", "unindent block", q{ doUnindentBlock(); });
  @TEDEditOnly mixin TEDImpl!("C-K C-E", "clear from cursor to EOL", q{ doKillToEOL(); });
  @TEDMultiOnly @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-K Tab", "indent block", q{ doIndentBlock(); });
  @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-K M-Tab", "untabify", q{ doUntabify(gb.tabsize ? gb.tabsize : 2); }); // alt+tab: untabify
  @TEDEditOnly mixin TEDImpl!("C-K C-space", "remove trailing spaces", q{ doRemoveTailingSpaces(); });
  mixin TEDImpl!("C-K C-T", /*"toggle \"visual tabs\" mode",*/ q{ visualtabs = !visualtabs; });

  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K C-B", q{ doSetBlockStart(); });
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K C-K", q{ doSetBlockEnd(); });

  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K C-C", q{ doBlockCopy(); });
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K C-M", q{ doBlockMove(); });
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K C-Y", q{ doBlockDelete(); });
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K C-H", q{ doBlockResetMark(); });
  // fuckin' vt100!
  @TEDMultiOnly @TEDEditOnly mixin TEDImpl!("C-K Backspace", q{ doBlockResetMark(); });

  @TEDEditOnly @TEDRepeated mixin TEDImpl!("C-Q Tab", q{ doPutChar('\t'); });
  mixin TEDImpl!("C-Q C-U", "toggle utfuck mode", q{ utfuck = !utfuck; }); // ^Q^U: switch utfuck mode
  mixin TEDImpl!("C-Q 1", "switch to koi8", q{ utfuck = false; codepage = CodePage.koi8u; fullDirty(); });
  mixin TEDImpl!("C-Q 2", "switch to cp1251", q{ utfuck = false; codepage = CodePage.cp1251; fullDirty(); });
  mixin TEDImpl!("C-Q 3", "switch to cp866", q{ utfuck = false; codepage = CodePage.cp866; fullDirty(); });
  mixin TEDImpl!("C-Q C-B", "go to block start", q{ if (hasMarkedBlock) gotoPos!true(bstart); lastBGEnd = false; });

  @TEDMultiOnly @TEDRepeated mixin TEDImpl!("C-Q C-F", "incremental search current word", q{
    auto pos = curpos;
    if (!isWordChar(gb[pos])) return;
    // deactivate prompt
    if (incInputActive) {
      incInputActive = false;
      promptDeactivate();
      resetIncSearchPos();
    }
    // collect word
    while (pos > 0 && isWordChar(gb[pos-1])) --pos;
    incSearchBuf.length = 0;
    incSearchBuf.assumeSafeAppend;
    while (pos < gb.textsize && isWordChar(gb[pos])) incSearchBuf ~= gb[pos++];
    incSearchDir = 1;
    // get current word
    doNextIncSearch();
  });

  mixin TEDImpl!("C-Q C-K", "go to block end", q{ if (hasMarkedBlock) gotoPos!true(bend); lastBGEnd = true; });
  mixin TEDImpl!("C-Q C-T", "set tab size", q{
    auto tsz = dialogTabSize(hisman, tabsize);
    if (tsz > 0 && tsz <= 64) tabsize = cast(ubyte)tsz;
  });

  @TEDMultiOnly mixin TEDImpl!("C-Q C-X", "toggle syntax highlighing", q{ toggleHighlighting(); });

  @TEDMultiOnly @TEDROOnly @TEDRepeated mixin TEDImpl!("Space", q{ doPageDown(); });
  @TEDMultiOnly @TEDROOnly @TEDRepeated mixin TEDImpl!("C-Space", q{ doPageUp(); });

  @TEDRepeatChar mixin TEDImpl!("C-P", "counter (*2 or direct number)", q{ doCounterMode(); });
  @TEDRepeatChar mixin TEDImpl!("C-]", "", q{ doCounterMode(); });
}
