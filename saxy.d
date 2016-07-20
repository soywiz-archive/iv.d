/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */
// SAX style xml parser
module iv.saxy;

import std.encoding;
import std.range;
static if (is(typeof({import iv.vfs;}))) {
  import iv.vfs;
  import iv.strex;
} else {
  // check if a given stream supports `rawRead()`.
  // it's enough to support `void[] rawRead (void[] buf)`
  private enum isReadableStream(T) = is(typeof((inout int=0) {
    auto t = T.init;
    ubyte[1] b;
    auto v = cast(void[])b;
    t.rawRead(v);
  }));
}


// ////////////////////////////////////////////////////////////////////////// //
//*WARNING*: attr keys are *NOT* strings!
void xmparse(ST) (auto ref ST fl,
  scope void delegate (char[] name, char[][string] attrs) tagStart,
  scope void delegate (char[] name) tagEnd,
  scope void delegate (char[] text) content,
) if (isReadableStream!ST || (isInputRange!ST && is(ElementEncodingType!ST == char))) {
  char[] buf;
  uint bufpos;
  char[][string] attrs;
  scope(exit) {
    attrs.destroy;
    buf.destroy;
  }

  static bool isValidNameChar() (char ch) {
    pragma(inline, true);
    return
      (ch >= '0' && ch <= '9') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_' || ch == '-' || ch == ':';
  }

  int tagLevel = 0;

  void bufPut (const(char)[] chars...) {
    if (/*tagLevel &&*/ chars.length) {
      if (chars.length+bufpos > buf.length) {
        if (chars.length+bufpos >= int.max) throw new Exception("out of memory in xml parser");
        buf.assumeSafeAppend;
        buf.length = ((chars.length+bufpos)|0x3ff)+1;
      }
      buf[bufpos..bufpos+chars.length] = chars[];
      bufpos += chars.length;
    }
  }

  void clearBuf () {
    bufpos = 0;
  }

  char curCh;
  bool eof;

  static if (isReadableStream!ST) {
    char[] rdbuf;
    scope(exit) rdbuf.destroy;
    uint rdbufpos, rdbufused;
  }

  void skipChar () {
    if (!eof) {
      static if (isReadableStream!ST) {
        // buffer more bytes
        if (rdbufpos >= rdbufused) {
          if (rdbuf.length == 0) rdbuf.length = 32*1024;
          auto rd = fl.rawRead(rdbuf[]);
          if (rd.length == 0) { eof = true; curCh = 0; return; }
          rdbufpos = 0;
          rdbufused = cast(uint)rd.length;
        }
        curCh = rdbuf.ptr[rdbufpos++];
      } else {
        if (fl.empty) { eof = true; curCh = 0; return; }
        curCh = fl.front;
        fl.popFront;
      }
      if (curCh == 0) curCh = ' ';
    }
  }

  // curCh is '&'
  void parseEntity (bool inattr) {
    assert(curCh == '&');
    bufPut(curCh);
    auto xpos = bufpos;
    skipChar();
    if (inattr) {
      while (!eof && curCh != '/' && curCh != '>' && curCh != '?' && curCh != ';' && bufpos-xpos < 9) {
        bufPut(curCh);
        skipChar();
      }
    } else {
      while (!eof && curCh != '<' && curCh != ';' && bufpos-xpos < 9) {
        bufPut(curCh);
        skipChar();
      }
    }
    if (!eof && curCh == ';' && bufpos > xpos) {
      import std.utf : encode, UseReplacementDchar;
      char[4] ubuf = void; // utf buffer
      switch (buf[xpos..bufpos]) {
        case "lt": bufpos = xpos-1; bufPut('<'); break;
        case "gt": bufpos = xpos-1; bufPut('>'); break;
        case "amp": bufpos = xpos-1; bufPut('&'); break;
        case "quot": bufpos = xpos-1; bufPut('"'); break;
        case "apos": bufpos = xpos-1; bufPut('\''); break;
        default:
          bufPut(curCh); // first put ';'
          if (bufpos-xpos > 3 && buf.ptr[xpos] == '#' && buf.ptr[xpos+1] == 'x') {
            // should be hex code
            uint n = 0;
            auto pos = xpos+2;
            while (pos < bufpos-1) {
              char ch = buf.ptr[pos++];
                   if (ch >= '0' && ch <= '9') n = n*16+ch-'0';
              else if (ch >= 'A' && ch <= 'F') n = n*16+ch-'A'+10;
              else if (ch >= 'a' && ch <= 'f') n = n*16+ch-'a'+10;
              else { n = uint.max; break; } // invalid digit
              if (n > dchar.max) break; // invalid char
            }
            if (n <= dchar.max) {
              bufpos = xpos-1;
              auto sz = encode!(UseReplacementDchar.yes)(ubuf, cast(dchar)n);
              foreach (immutable char ch; ubuf[0..sz]) bufPut(ch);
            }
          } else if (bufpos-xpos > 2 && buf.ptr[xpos] == '#') {
            // shoud be decimal code
            uint n = 0;
            auto pos = xpos+1;
            while (pos < bufpos-1) {
              char ch = buf.ptr[pos++];
              if (ch >= '0' && ch <= '9') n = n*10+ch-'0';
              else { n = uint.max; break; } // invalid digit
              if (n > dchar.max) break; // invalid char
            }
            if (n <= dchar.max) {
              bufpos = xpos-1;
              auto sz = encode!(UseReplacementDchar.yes)(ubuf, cast(dchar)n);
              foreach (immutable char ch; ubuf[0..sz]) bufPut(ch);
            }
          }
          break;
      }
      skipChar();
    }
  }

  void parseCData () {
    clearBuf();
    while (!eof) {
      if (bufpos >= 3 && buf.ptr[bufpos-1] == '>' && buf.ptr[bufpos-2] == ']' && buf.ptr[bufpos-3] == ']') {
        bufpos -= 3;
        break;
      }
      bufPut(curCh);
      skipChar();
    }
    if (tagLevel && bufpos > 0 && content !is null) content(buf[0..bufpos]);
    clearBuf();
  }

  void parseContent () {
    clearBuf();
    while (!eof) {
      if (curCh == '<') break;
      if (curCh != '&') {
        bufPut(curCh);
        skipChar();
      } else {
        parseEntity(false);
      }
    }
    if (tagLevel && bufpos > 0 && content !is null) content(buf[0..bufpos]);
    clearBuf();
  }

  void parseTag () {
    assert(!eof && curCh == '<');
    clearBuf();
    skipChar();
    if (eof) throw new Exception("invalid xml");
    bool inlineClose = false, closeTag = false;
    if (curCh == '!') {
      // either CDATA, or comment-like
      skipChar();
      if (curCh == '[') {
        // this *must* be CDATA
        skipChar();
        if (curCh != 'C') throw new Exception("invalid xml");
        skipChar();
        if (curCh != 'D') throw new Exception("invalid xml");
        skipChar();
        if (curCh != 'A') throw new Exception("invalid xml");
        skipChar();
        if (curCh != 'T') throw new Exception("invalid xml");
        skipChar();
        if (curCh != 'A') throw new Exception("invalid xml");
        skipChar();
        if (curCh != '[') throw new Exception("invalid xml");
        skipChar();
        clearBuf();
        parseCData();
        return;
      } else if (curCh == '-') {
        // comment
        skipChar();
        if (curCh != '-') throw new Exception("invalid xml");
        skipChar();
        for (;;) {
          if (eof) throw new Exception("invalid xml");
          if (curCh == '-') {
            skipChar();
            if (curCh == '-') {
              skipChar();
              if (curCh == '>') {
                skipChar();
                break;
              }
            }
          } else {
            skipChar();
          }
        }
        clearBuf();
        return;
      } else {
        // !tag
        bufPut('!');
      }
    } else {
      if (curCh == '/') { closeTag = true; skipChar(); }
      if (curCh == '?') { bufPut(curCh); skipChar(); }
    }
    if (eof || !isValidNameChar(curCh)) throw new Exception("invalid xml");
    while (isValidNameChar(curCh)) {
      bufPut(curCh);
      skipChar();
    }
    //{ import std.stdio; writeln("TAG: ", buf[0..bufpos].quote); }
    // now parse attributes
    scope(exit) attrs.clear();
    while (!eof && curCh <= ' ') skipChar();
    // closing tag?
    auto tagnameend = bufpos;
    if (!closeTag) {
      // attr=["]name["]
      // read the whole tag, so we can add AA items without anchoring stale memory
      if (eof) throw new Exception("invalid xml");
      if (curCh != '/' && curCh != '>' && curCh != '?') {
        bufPut(' ');
        auto stpos = bufpos;
        char qch = 0;
        for (;;) {
          if (eof) throw new Exception("invalid xml");
          if (qch) {
            if (curCh == qch) qch = 0;
            if (curCh == '&') {
              parseEntity(true);
              continue;
            }
          } else {
            if (curCh == '/' || curCh == '>' || curCh == '?') break;
            if (curCh == '"' || curCh == '\'') qch = curCh;
          }
          bufPut(curCh);
          skipChar();
        }
        // now parse attributes
        while (stpos < bufpos) {
          while (stpos < bufpos && buf.ptr[stpos] <= ' ') ++stpos;
          if (stpos >= bufpos) break;
          //{ import std.stdio; writeln(": ", buf[stpos..bufpos].quote); }
          if (!isValidNameChar(buf.ptr[stpos])) throw new Exception("invalid xml");
          auto nst = stpos;
          while (stpos < bufpos && isValidNameChar(buf.ptr[stpos])) ++stpos;
          string aname = cast(string)(buf[nst..stpos]); // unsafe cast, but meh...
          while (stpos < bufpos && buf.ptr[stpos] <= ' ') ++stpos;
          if (stpos >= bufpos) { attrs[aname] = null; break; } // no value
          if (buf.ptr[stpos] != '=') { attrs[aname] = null; continue; } // no value
          ++stpos;
          if (stpos >= bufpos) { attrs[aname] = buf[bufpos..bufpos]; break; }
          if (buf.ptr[stpos] == '"' || buf.ptr[stpos] == '\'') {
            auto ech = buf.ptr[stpos];
            nst = ++stpos;
            while (stpos < bufpos && buf.ptr[stpos] != ech) ++stpos;
            if (stpos >= bufpos) throw new Exception("invalid xml");
            attrs[aname] = buf[nst..stpos];
            ++stpos;
          } else {
            nst = stpos;
            while (stpos < bufpos && buf.ptr[stpos] > ' ') ++stpos;
            attrs[aname] = buf[nst..stpos];
          }
        }
      }
    }
    if (curCh == '?') {
      if (buf.ptr[0] != '?') throw new Exception("invalid xml");
      skipChar();
      inlineClose = true;
    } else if (buf.ptr[0] != '!') {
      if (curCh == '/') { inlineClose = true; skipChar(); }
    } else {
      inlineClose = true;
    }
    if (curCh != '>') throw new Exception("invalid xml");
    skipChar();
    if (closeTag) {
      if (inlineClose) throw new Exception("invalid xml");
      if (tagEnd !is null) tagEnd(buf[0..tagnameend]);
      --tagLevel;
    } else {
      ++tagLevel;
      if (tagStart !is null) tagStart(buf[0..tagnameend], attrs);
      if (inlineClose) {
        if (tagEnd !is null) tagEnd(buf[0..tagnameend]);
        --tagLevel;
      }
    }
  }

  while (!eof) {
    //writeln("*** ", tagLevel, " ***");
    parseContent();
    if (eof) break;
    if (curCh == '<') {
      parseTag();
      if (tagLevel < 0) throw new Exception("invalid xml");
    }
  }

  if (tagLevel != 0) throw new Exception("invalid xml");
}


// ////////////////////////////////////////////////////////////////////////// //
final class SaxyEx {
private import std.range;
public:
  alias TagOpenCB = void delegate (char[] name, char[][string] attrs);
  alias TagCloseCB = void delegate (char[] name);
  alias TagContentCB = void delegate (char[] text);

private:
  static struct PathElement {
    string name; // empty: any tag
    char quant = 0; // '+', '*', 0
  }

  static struct TagCB {
    enum Type { Open, Close, Content, NormContent }
    Type type;
    PathElement[] path;
    union {
      TagOpenCB open;
      TagCloseCB close;
      TagContentCB content;
    }
  }

private:
  TagCB[] callbacks;

public:
  this () {}

  void load (const(char)[] filename) { loadFile(VFile(filename)); }

  void loadStream(ST) (auto ref ST st) if (isReadableStream!ST || (isInputRange!ST && is(ElementEncodingType!ST == char))) { loadFile(st); }

  void onOpen(ST : const(char)[]) (ST path, TagOpenCB cb) {
    assert(cb !is null);
    auto tcb = newCallback(path);
    tcb.type = TagCB.Type.Open;
    tcb.open = cb;
  }

  void onClose(ST : const(char)[]) (ST path, TagCloseCB cb) {
    assert(cb !is null);
    auto tcb = newCallback(path);
    tcb.type = TagCB.Type.Close;
    tcb.close = cb;
  }

  // text will be duped
  void onContent(bool normText=false, ST : const(char)[]) (ST path, TagContentCB cb) {
    assert(cb !is null);
    auto tcb = newCallback(path);
    static if (normText) {
      tcb.type = TagCB.Type.NormContent;
    } else {
      tcb.type = TagCB.Type.Content;
    }
    tcb.content = cb;
  }

private:
  TagCB* newCallback(ST : const(char)[]) (ST path) {
    static if (is(ST == typeof(null))) {
      return newCallback("");
    } else {
      // parse path
      PathElement[] pth;
      if (path.length) {
        while (path.length != 0) {
          while (path.length != 0 && path.ptr[0] == '/') path = path[1..$];
          if (path.length == 0) break;
          size_t e = 0;
          while (e < path.length && path.ptr[e] != '/') ++e;
          //if (e == 1 && path.ptr[0] == '+') throw new Exception("invalid callback path");
          if (path.ptr[e-1] == '+' || path.ptr[e-1] == '*') {
            pth ~= PathElement(path[0..e-1].idup, path.ptr[e-1]);
          } else {
            pth ~= PathElement(path[0..e].idup, 0);
          }
          path = path[e..$];
        }
        if (pth.length == 0) throw new Exception("invalid callback path");
      } else {
        pth ~= PathElement(null, '*');
      }
      TagCB* res;
      callbacks.length += 1;
      res = &callbacks[$-1];
      res.path = pth;
      return res;
    }
  }

  // yes, i can make it faster with some more preprocessing, but why should i bother?
  static bool pathHit (string[] tagStack, PathElement[] path) {
    version(none) {
      import std.stdio;
      writeln("tagStack: ", tagStack[]);
      foreach (const ref PathElement pe; path) {
        write((pe.quant ? pe.quant : ' '), pe.name);
      }
      writeln;
    }
    while (path.length > 0) {
      auto pe = &path[0];
      path = path[1..$];
      if (pe.quant == '*') {
        if (pe.name.length == 0) {
          // any number of any tag, including zero
          if (path.length == 0) return true;
          while (tagStack.length > 0) {
            if (pathHit(tagStack, path)) return true;
            tagStack = tagStack[1..$];
          }
          return false;
        } else {
          // any number of given tag, including zero
          // skip this tag and continue
          while (tagStack.length && tagStack.ptr[0] == pe.name) tagStack = tagStack[1..$];
        }
      } else if (pe.quant == '+') {
        if (pe.name.length == 0) {
          // any number of any tag, not including zero
          if (path.length == 0) return (tagStack.length > 0);
          while (tagStack.length > 0) {
            if (pathHit(tagStack, path)) return true;
            tagStack = tagStack[1..$];
          }
          return false;
        } else {
          // any number of given tag, not including zero
          if (tagStack.length == 0 || tagStack.ptr[0] != pe.name) return false;
          // skip this tag and continue
          while (tagStack.length && tagStack.ptr[0] == pe.name) tagStack = tagStack[1..$];
        }
      } else if (pe.name.length != 0) {
        // named tag
        if (tagStack.length == 0) return false;
        if (pe.name != tagStack.ptr[0]) return false;
        tagStack = tagStack[1..$];
      } else {
        // any tag
        tagStack = tagStack[1..$];
      }
    }
    return (tagStack.length == 0);
  }

private:
  void loadFile(ST) (auto ref ST fl) if (isReadableStream!ST || (isInputRange!ST && is(ElementEncodingType!ST == char))) {
    bool seenXML;
    string[] tagStack;
    EncodingScheme efrom, eto;
    scope(exit) { efrom.destroy; eto.destroy; }
    char[] recbuf; // recode buffer
    size_t rcpos; // for recode buffer
    scope(exit) recbuf.destroy;

    char[] nrecode (char[] text) {
      if (efrom is null) return text.dup; // nothing to do
      rcpos = 0;
      ubyte[16] buf;
      auto ub = cast(const(ubyte)[])text;
      while (ub.length > 0) {
        dchar dc = efrom.safeDecode(ub);
        if (dc == INVALID_SEQUENCE) dc = '?';
        auto len = eto.encode(dc, buf);
        if (rcpos+len > recbuf.length) {
          recbuf.assumeSafeAppend; // we will copy that anyway
          recbuf.length = ((rcpos+len)|0x3ff)+1;
        }
        recbuf[rcpos..rcpos+len] = cast(char[])buf[0..len];
        rcpos += len;
      }
      return recbuf[0..rcpos];
    }

    char[] norm(bool dospacenorm) (char[] text) {
      static if (dospacenorm) {
        while (text.length > 0 && text.ptr[0] <= ' ') text = text[1..$];
        while (text.length > 0 && text[$-1] <= ' ') text = text[0..$-1];
      }
      if (text.length == 0) return null;
      char[] s;
      if (efrom !is null) {
        s = nrecode(text);
      } else {
        s = text.dup;
      }
      static if (dospacenorm) {
        size_t pos = 0;
        while (pos < s.length) {
          if (s.ptr[pos] <= ' ') {
            if (pos == 0 || s.ptr[pos-1] <= ' ') {
              import core.stdc.string : memmove;
              memmove(s.ptr+pos, s.ptr+pos+1, s.length-pos-1);
              s.length -= 1;
              continue;
            }
            s.ptr[pos] = ' ';
          }
          ++pos;
        }
      }
      return s; // it is safe to cast here
    }

    xmparse(fl,
      (char[] name, char[][string] attrs) {
        if (name == "?xml") {
          if (seenXML) throw new Exception("duplicate '?xml?' tag");
          seenXML = true;
          if (auto ec = "encoding" in attrs) {
            foreach (ref char ch; *ec) {
              import std.ascii : toLower;
              ch = ch.toLower;
            }
            if ((*ec).length && *ec != "utf-8") {
              efrom = EncodingScheme.create(cast(string)(*ec)); // let's hope that it is safe...
              eto = EncodingScheme.create("utf-8");
            }
          }
          return;
        }
        if (!seenXML) throw new Exception("no '?xml?' tag");
        tagStack.assumeSafeAppend;
        tagStack ~= name.idup;
        bool attrsRecoded = (efrom !is null);
        foreach (ref TagCB tcb; callbacks) {
          if (tcb.type == TagCB.Type.Open && pathHit(tagStack, tcb.path)) {
            // recode attrs and call the callback
            if (!attrsRecoded) {
              foreach (ref v; attrs.byValue) v = nrecode(v);
              attrsRecoded = true;
            }
            tcb.open(name, attrs);
          }
        }
      },
      (char[] name) {
        if (name == "?xml") return;
        if (tagStack.length == 0 || tagStack[$-1] != name) throw new Exception("unbalanced xml tags");
        foreach (ref TagCB tcb; callbacks) {
          if (tcb.type == TagCB.Type.Close && pathHit(tagStack, tcb.path)) {
            // call the callback
            tcb.close(name);
          }
        }
        tagStack.length -= 1;
      },
      (char[] text) {
        bool textRecoded = false;
        bool textNormed = false;
        char[] textNorm;
        foreach (ref TagCB tcb; callbacks) {
          if (tcb.type == TagCB.Type.Content && pathHit(tagStack, tcb.path)) {
            // recode text and call the callback
            if (!textRecoded) {
              text = nrecode(text);
              textRecoded = true;
            }
            tcb.content(text);
          } else if (tcb.type == TagCB.Type.NormContent && pathHit(tagStack, tcb.path)) {
            // normalize text and call the callback
            if (!textNormed) {
              textNorm = norm!true(text);
              textNormed = true;
            }
            if (textNorm.length) tcb.content(textNorm);
          }
        }
      },
    );
  }
}
