/**
 * Light read-only XML library
 * Soon to be deprecated.
 * See other XML modules for better implementations.
 *
 * License:
 *   This Source Code Form is subject to the terms of
 *   the Mozilla Public License, v. 2.0. If a copy of
 *   the MPL was not distributed with this file, You
 *   can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Authors:
 *   Vladimir Panteleev <vladimir@thecybershadow.net>
 *   Simon Arlott
 *   modifications and uglyfication by Ketmar // Invisible Vector
 */
module iv.xmllite is aliced;


/******************************************************************************/
/* xml parser                                                                 */
/******************************************************************************/
// TODO: better/safer handling of malformed XML

import std.ascii;
import std.exception;
import std.stream;
import std.string;


// ************************************************************************
/// Stream-like type with bonus speed
struct StringStream {
  string s;
  usize position;

  this (string s) {
    enum ditch = "'\">\0\0\0\0\0"; // Dirty precaution
    this.s = (s~ditch)[0..$-ditch.length];
  }

  void read (out char c) => c = s[position++];
  void seekCur (sizediff_t offset) => position += offset;
  @property usize size () const => s.length;
  @property bool eof () const => (position >= s.length);
}


// ************************************************************************
enum XmlNodeType {
  Root,
  Node,
  Comment,
  Meta,
  DocType,
  Text
}


class XmlNode {
  string tag;
  string[string] attributes;
  XmlNode[] children;
  XmlNodeType type;
  ulong startPos, endPos;

  this (Stream s) => parse(s);
  this (StringStream* s) => parse(s);
  this (string s) => this(new StringStream(s));

  private final void parse(S) (S s) {
    startPos = s.position;
    char c;
    do { s.read(c); } while (isWhiteChar[c]);
    // text node?
    if (c != '<') {
      type = XmlNodeType.Text;
      string text;
      while (c != '<') {
        // TODO: check for EOF
        text ~= c;
        s.read(c);
      }
      s.seekCur(-1); // rewind to '<'
      tag = decodeEntities(text.strip);
      //tag = tag.strip();
    } else {
      s.read(c);
      if (c == '!') {
        s.read(c);
        // comment?
        if (c == '-') {
          expect(s, '-');
          type = XmlNodeType.Comment;
          do {
            s.read(c);
            tag ~= c;
          } while (tag.length < 3 || tag[$-3..$] != "-->");
          tag = tag[0..$-3];
        } else {
          // doctype, etc.
          type = XmlNodeType.DocType;
          while (c != '>') {
            tag ~= c;
            s.read(c);
          }
        }
      } else if (c == '?') {
        type = XmlNodeType.Meta;
        tag = readWord(s);
        if (tag.length == 0) throw new Exception("Invalid tag");
        while (true) {
          skipWhitespace(s);
          if (peek(s) == '?') break;
          readAttribute(s);
        }
        s.read(c);
        expect(s, '>');
      } else if (c=='/') {
        throw new Exception("Unexpected close tag");
      } else {
        type = XmlNodeType.Node;
        tag = c~readWord(s);
        for (;;) {
          skipWhitespace(s);
          c = peek(s);
          if (c == '>' || c == '/') break;
          readAttribute(s);
        }
        s.read(c);
        if (c == '>') {
          for (;;) {
            skipWhitespace(s);
            if (peek(s) == '<' && peek(s, 2) == '/') break;
            try {
              children ~= new XmlNode(s);
            } catch (Exception e) {
              throw new Exception("Error while processing child of "~tag, e);
            }
          }
          expect(s, '<');
          expect(s, '/');
          foreach (immutable char tc; tag) expect(s, tc);
          expect(s, '>');
        } else {
          expect(s, '>');
        }
      }
    }
    endPos = s.position;
  }

  this (XmlNodeType type, string tag=null) {
    this.type = type;
    this.tag = tag;
  }

  XmlNode addAttribute (string name, string value) {
    attributes[name] = value;
    return this;
  }

  XmlNode addChild (XmlNode child) {
    children ~= child;
    return this;
  }

  override string toString() const {
    XmlWriter writer;
    writeTo(writer);
    return writer.output.get();
  }

  final string toPrettyString() const {
    PrettyXmlWriter writer;
    writeTo(writer);
    return writer.output.get();
  }

  final void writeTo(XmlWriter) (ref XmlWriter output) const {
    void writeChildren () {
      foreach (auto child; children) child.writeTo(output);
    }

    void writeAttributes () {
      foreach (auto key, auto value; attributes) output.addAttribute(key, value);
    }

    switch (type) {
      case XmlNodeType.Root:
        writeChildren();
        return;
      case XmlNodeType.Node:
        output.startTagWithAttributes(tag);
        writeAttributes();
        output.endAttributes();
        writeChildren();
        output.endTag(tag);
        return;
      case XmlNodeType.Meta:
        assert(children.length == 0);
        output.startPI(tag);
        writeAttributes();
        output.endPI();
        return;
      case XmlNodeType.DocType:
        assert(children.length == 0);
        output.doctype(tag);
        return;
      case XmlNodeType.Text:
        output.text(tag, true);
        return;
      default:
        return;
    }
  }

  @property string text () {
    switch (type) {
      case XmlNodeType.Text:
        return tag;
      case XmlNodeType.Node:
      case XmlNodeType.Root:
        string childrenText;
        foreach (auto child; children) childrenText ~= child.text;
        return childrenText;
      default:
        return null;
    }
  }

  final XmlNode findChild (string tag) {
    foreach (auto child; children) if (child.type == XmlNodeType.Node && child.tag == tag) return child;
    return null;
  }

  final XmlNode[] findChildren (string tag) {
    XmlNode[] result;
    foreach (auto child; children) if (child.type == XmlNodeType.Node && child.tag == tag) result ~= child;
    return result;
  }

  final XmlNode opIndex (string tag) {
    auto node = findChild(tag);
    if (node is null) throw new Exception("No such child: "~tag);
    return node;
  }

  final XmlNode opIndex (string tag, usize index) {
    auto nodes = findChildren(tag);
    if (index >= nodes.length) {
      throw new Exception(format("Can't get node with tag %s and index %d, there are only %d children with that tag", tag, index, nodes.length));
    }
    return nodes[index];
  }

  final XmlNode opIndex (usize index) {
    return children[index];
  }

  final @property usize length () const => children.length;

  int opApply (int delegate (ref XmlNode) dg) {
    int result = 0;
    for (int i = 0; i < children.length; ++i) {
      result = dg(children[i]);
      if (result) break;
    }
    return result;
  }

  final @property XmlNode dup () {
    auto result = new XmlNode(type, tag);
    result.attributes = attributes.dup;
    result.children.length = children.length;
    foreach (auto i, auto child; children) result.children[i] = child.dup;
    return result;
  }

private:
  final void readAttribute(S) (S s) {
    string name = readWord(s);
    if (name.length==0) throw new Exception("Invalid attribute");
    skipWhitespace(s);
    expect(s, '=');
    skipWhitespace(s);
    char delim;
    s.read(delim);
    if (delim != '\'' && delim != '"') throw new Exception("Expected ' or \"");
    string value = readUntil(s, delim);
    attributes[name] = decodeEntities(value);
  }
}


class XmlDocument : XmlNode {
  this () {
    super(XmlNodeType.Root);
    tag = "<Root>";
  }

  this (Stream s) { this(); parse(s); }
  this (StringStream* s) { this(); parse(s); }
  this (string s) => this(new StringStream(s));

  final void parse(S) (S s) {
    skipWhitespace(s);
    while (s.position < s.size)
      try {
        children ~= new XmlNode(s);
        skipWhitespace(s);
      } catch (Exception e) {
        throw new Exception(format("Error at %d", s.position), e);
      }
  }
}


XmlDocument xmlParse(T) (T source) => new XmlDocument(source);


private:
char peek (Stream s, int n=1) {
  char c;
  for (int i = 0; i < n; ++i) s.read(c);
  s.seekCur(-n);
  return c;
}


char peek (StringStream* s, int n=1) {
  return s.s[s.position+n-1];
}


void skipWhitespace (Stream s) {
  char c;
  do {
    if (s.position >= s.size) return;
    s.read(c);
  } while (isWhiteChar[c]);
  s.seekCur(-1);
}


void skipWhitespace (StringStream* s) {
  while (isWhiteChar[s.s.ptr[s.position]]) ++s.position;
}


immutable bool[256] isWhiteChar = {
  bool[256] res;
  foreach (immutable c; 0..256) res[c] = isWhite(c);
  return res;
}();

immutable bool[256] isWordChar = {
  bool[256] res;
  foreach (immutable c; 0..256) res[c] = (c == '-' || c == '_' || c == ':' || isAlphaNum(c));
  return res;
}();


string readWord (Stream s) {
  char c;
  string result;
  for (;;) {
    s.read(c);
    if (!isWordChar[c]) break;
    result ~= c;
  }
  s.seekCur(-1);
  return result;
}


string readWord (StringStream* stream) {
  auto start = stream.s.ptr+stream.position;
  auto end = stream.s.ptr+stream.s.length;
  auto p = start;
  while (p < end && isWordChar[*p]) ++p;
  auto len = p-start;
  stream.position += len;
  return start[0..len];
}


void expect(S) (S s, char c) {
  char c2;
  s.read(c2);
  enforce(c == c2, "Expected "~c~", got "~c2);
}


string readUntil (Stream s, char until) {
  string value;
  for (;;) {
    char c;
    s.read(c);
    if (c == until) return value;
    value ~= c;
  }
}


string readUntil (StringStream* s, char until) {
  auto start = s.s.ptr+s.position;
  auto p = start;
  while (*p != until) ++p;
  auto len = p-start;
  s.position += len+1;
  return start[0..len];
}


unittest {
  enum xmlText =
    `<?xml version="1.0" encoding="UTF-8"?>`
    `<quotes>`
      `<quote author="Alan Perlis">`
        `When someone says, &quot;I want a programming language in which I need only say what I want done,&quot; give him a lollipop.`
      `</quote>`
    `</quotes>`;
  auto doc = new XmlDocument(new MemoryStream(xmlText.dup));
  assert(doc.toString() == xmlText);
  doc = new XmlDocument(xmlText);
  assert(doc.toString() == xmlText);
}


__gshared const dchar[string] entities;
/*const*/ __gshared string[dchar] entityNames;
shared static this () {
  entities = [
    "quot"  : '\&quot;',
    "amp"   : '\&amp;',
    "lt"    : '\&lt;',
    "gt"    : '\&gt;',
    "circ"  : '\&circ;',
    "tilde" : '\&tilde;',
    "nbsp"  : '\&nbsp;',
    "ensp"  : '\&ensp;',
    "emsp"  : '\&emsp;',
    "thinsp": '\&thinsp;',
    "ndash" : '\&ndash;',
    "mdash" : '\&mdash;',
    "lsquo" : '\&lsquo;',
    "rsquo" : '\&rsquo;',
    "sbquo" : '\&sbquo;',
    "ldquo" : '\&ldquo;',
    "rdquo" : '\&rdquo;',
    "bdquo" : '\&bdquo;',
    "dagger": '\&dagger;',
    "Dagger": '\&Dagger;',
    "permil": '\&permil;',
    "laquo" : '\&laquo;',
    "raquo" : '\&raquo;',
    "lsaquo": '\&lsaquo;',
    "rsaquo": '\&rsaquo;',
    "euro"  : '\&euro;',
    "copy"  : '\&copy;',
    "reg"   : '\&reg;',
    "apos"  : '\''
  ];
  foreach (immutable name, immutable c; entities) entityNames[c] = name;
}


public string encodeEntities (string str) {
  // TODO: optimize
  foreach_reverse (immutable i, immutable char c; str) {
    if (c == '<' || c == '>' || c == '"' || c == '\'' || c == '&') {
      str = str[0..i]~'&'~entityNames[c]~';'~str[i+1..$];
    }
  }
  return str;
}


public string encodeAllEntities (string str) {
  import std.utf;
  // TODO: optimize
  foreach_reverse (immutable i, immutable dchar c; str) {
    auto name = c in entityNames;
    if (name) str = str[0..i]~'&'~*name~';'~str[i+stride(str, i)..$];
  }
  return str;
}


public string decodeEntities (string str) {
  import std.conv : to;
  import std.utf : encode;

  auto fragments = str.fastSplit('&'); // see utils at the end of this file
  if (fragments.length <= 1) return str;

  auto interleaved = new string[fragments.length*2-1];
  auto buffers = new char[4][fragments.length-1];
  interleaved[0] = fragments[0];

  foreach (auto n, auto fragment; fragments[1..$]) {
    auto p = fragment.indexOf(';');
    enforce(p > 0, "Invalid entity (unescaped ampersand?)");
    dchar c;
    if (fragment[0] == '#') {
      if (fragment[1] == 'x') c = fromHex!uint(fragment[2..p]);
      else c = to!uint(fragment[1..p]);
    } else {
      auto pentity = fragment[0..p] in entities;
      enforce(pentity, "Unknown entity: "~fragment[0..p]);
      c = *pentity;
    }
    interleaved[1+n*2] = cast(string) buffers[n][0..std.utf.encode(buffers[n], c)];
    interleaved[2+n*2] = fragment[p+1..$];
  }

  return interleaved.join();
}


unittest {
  assert(encodeAllEntities("©,€") == "&copy;,&euro;");
  assert(decodeEntities("&copy;,&euro;") == "©,€");
}


/******************************************************************************/
/* xml writer                                                                 */
/******************************************************************************/
struct CustomXmlWriter(WRITER, bool PRETTY) {
  /// You can set this to something to e.g. write to another buffer.
  WRITER output;

  static if (PRETTY) {
    uint indentLevel = 0;

    void newLine () => output.put('\n');
    void startLine () => output.allocate(indentLevel)[] = ' ';
    void indent () => ++indentLevel;
    void outdent () { assert(indentLevel); --indentLevel; }
  }

  // verify well-formedness
  debug {
    string[] tagStack;
    void pushTag (string tag) => tagStack ~= tag;
    void popTag () {
      assert(tagStack.length, "No tag to close");
      tagStack = tagStack[0..$-1];
    }
    void popTag (string tag) {
      assert(tagStack.length, "No tag to close");
      assert(tagStack[$-1] == tag, "Closing wrong tag ("~tag~" instead of "~tagStack[$-1]~")");
      tagStack = tagStack[0..$-1];
    }

    bool inAttributes;
  }

  void startDocument () {
    output.put(`<?xml version="1.0" encoding="UTF-8"?>`);
    static if (PRETTY) newLine();
    debug assert(tagStack.length == 0);
  }

  void text (string s, bool addNL=false) {
    // https://gist.github.com/2192846
    static if (PRETTY) { if (addNL) startLine(); }
    auto start = s.ptr, p = start, end = start+s.length;
    while (p < end) {
      auto c = *p++;
      if (escEscaped[c]) {
        output.put(start[0..p-start-1], escChars[c]);
        start = p;
      }
    }
    output.put(start[0..p-start]);
    static if (PRETTY) {
      if (addNL && (s.length == 0 || s[$-1] != '\n')) output.put("\n");
    }
  }

  // Common
  private enum mixStartWithAttributesGeneric =
  q{
    debug assert(!inAttributes, "Tag attributes not ended");
    static if (PRETTY) startLine();

    static if (STATIC)
      output.put(OPEN~name);
    else
      output.put(OPEN, name);

    debug inAttributes = true;
    debug pushTag(name);
  };

  private enum mixEndAttributesAndTagGeneric =
  q{
    debug assert(inAttributes, "Tag attributes not started");
    output.put(CLOSE);
    static if (PRETTY) newLine();
    debug inAttributes = false;
    debug popTag();
  };

  // startTag

  private enum mixStartTag =
  q{
    debug assert(!inAttributes, "Tag attributes not ended");
    static if (PRETTY) startLine();

    static if (STATIC)
      output.put('<'~name~'>');
    else
      output.put('<', name, '>');

    static if (PRETTY) { newLine(); indent(); }
    debug pushTag(name);
  };

  void startTag(string name) () { enum STATIC = true;  mixin(mixStartTag); }
  void startTag() (string name) { enum STATIC = false; mixin(mixStartTag); }

  // startTagWithAttributes

  void startTagWithAttributes(string name) () { enum STATIC = true;  enum OPEN = '<'; mixin(mixStartWithAttributesGeneric); }
  void startTagWithAttributes() (string name) { enum STATIC = false; enum OPEN = '<'; mixin(mixStartWithAttributesGeneric); }

  // addAttribute
  private enum mixAddAttribute =
  q{
    debug assert(inAttributes, "Tag attributes not started");

    static if (STATIC)
      output.put(' '~name~`="`);
    else
      output.put(' ', name, `="`);

    text(value);
    output.put('"');
  };

  void addAttribute(string name) (string value)   { enum STATIC = true;  mixin(mixAddAttribute); }
  void addAttribute() (string name, string value) { enum STATIC = false; mixin(mixAddAttribute); }

  // endAttributes[AndTag]
  void endAttributes () {
    debug assert(inAttributes, "Tag attributes not started");
    output.put('>');
    static if (PRETTY) { newLine(); indent(); }
    debug inAttributes = false;
  }

  void endAttributesAndTag () { enum CLOSE = " />"; mixin(mixEndAttributesAndTagGeneric); }

  // endTag
  private enum mixEndTag =
  q{
    debug assert(!inAttributes, "Tag attributes not ended");
    static if (PRETTY) { outdent(); startLine(); }

    static if (STATIC)
      output.put("</"~name~">");
    else
      output.put("</", name, ">");

    static if (PRETTY) newLine();
    debug popTag(name);
  };

  void endTag(string name) () { enum STATIC = true;  mixin(mixEndTag); }
  void endTag() (string name) { enum STATIC = false; mixin(mixEndTag); }

  // Processing instructions

  void startPI(string name) () { enum STATIC = true;  enum OPEN = "<?"; mixin(mixStartWithAttributesGeneric); }
  void startPI() (string name) { enum STATIC = false; enum OPEN = "<?"; mixin(mixStartWithAttributesGeneric); }
  void endPI () { enum CLOSE = "?>"; mixin(mixEndAttributesAndTagGeneric); }

  // Doctypes

  void doctype (string text) {
    debug assert(!inAttributes, "Tag attributes not ended");
    output.put("<!", text, ">");
    static if (PRETTY) newLine();
  }
}


public alias XmlWriter = CustomXmlWriter!(StringBuilder, false);
public alias PrettyXmlWriter = CustomXmlWriter!(StringBuilder, true);


private:
static immutable string[256] escChars = {
  import std.string;
  string[256] res;
  foreach (immutable c; 0..256) {
    switch (c) {
      case '<': res[c] = "&lt;"; break;
      case '>': res[c] = "&gt;"; break;
      case '&': res[c] = "&amp;"; break;
      case '"': res[c] = "&quot;"; break;
      default:
        if (c < 0x20 && c != 0x0D && c != 0x0A) res[c] = format("&#x%02X;", c);
        else res[c] = [cast(char)c];
        break;
    }
  }
  return res;
}();

static immutable bool[256] escEscaped = {
  bool[256] res;
  res[] = true;
  foreach (immutable c; 0..256) {
    switch (c) {
      case '<': case '>': case '&': case '"': break;
      default:
        if (c < 0x20 && c != 0x0D && c != 0x0A) break;
        res[c] = false;
        break;
    }
  }
  return res;
}();


unittest {
  string[string] quotes;
  quotes["Alan Perlis"] = "When someone says, \"I want a programming language in which I need only say what I want done,\" give him a lollipop.";

  XmlWriter xml;
  xml.startDocument();
  xml.startTag!"quotes"();
  foreach (immutable author, immutable text; quotes) {
    xml.startTagWithAttributes!"quote"();
    xml.addAttribute!"author"(author);
    xml.endAttributes();
    xml.text(text);
    xml.endTag!"quote"();
  }
  xml.endTag!"quotes"();

  auto str = xml.output.get();
  assert(str ==
    `<?xml version="1.0" encoding="UTF-8"?>`
    `<quotes>`
      `<quote author="Alan Perlis">`
        `When someone says, &quot;I want a programming language in which I need only say what I want done,&quot; give him a lollipop.`
      `</quote>`
    `</quotes>`);
}

// TODO: StringBuilder-compatible XML-encoding string sink/filter?
// e.g. to allow putTime to write directly to an XML node content


////////////////////////////////////////////////////////////////////////////////
// utils
import std.traits;


private:
T[][] fastSplit(T, U) (T[] s, U d) if (is(Unqual!T == Unqual!U)) {
  import core.stdc.string;

  if (!s.length) return null;

  auto p = cast(T*)memchr(s.ptr, d, s.length);
  if (!p) return [s];

  usize n;
  auto end = s.ptr+s.length;
  do {
    ++n;
    ++p;
    p = cast(T*)memchr(p, d, end-p);
  } while (p);

  auto result = new T[][n+1];
  n = 0;
  auto start = s.ptr;
  p = cast(T*)memchr(start, d, s.length);
  do {
    result[n++] = start[0..p-start];
    start = ++p;
    p = cast(T*) memchr(p, d, end-p);
  } while (p);
  result[n] = start[0..end-start];

  return result;
}


T fromHex(T : ulong = uint, C) (const(C)[] s) {
  import std.conv;
  T result = parse!T(s, 16);
  enforce(s.length == 0, new ConvException("Could not parse entire string"));
  return result;
}


alias StringBuilder = FastAppender!(immutable(char));


struct FastAppender(I) {
  static assert(T.sizeof == 1, "TODO");

private:
  enum PAGE_SIZE = 4096;
  enum MIN_SIZE = PAGE_SIZE/2+1; // smallest size that can expand

  alias T = Unqual!I;

  T* cursor, start, end;

  void reserve (usize len) {
    import core.memory;
    auto size = cursor-start;
    auto newSize = size+len;
    auto capacity = end-start;

    if (start) {
      auto extended = GC.extend(start, newSize, newSize*2);
      if (extended) {
        end = start+extended;
        return;
      }
    }

    auto newCapacity = (newSize < MIN_SIZE ? MIN_SIZE : newSize*2);

    auto bi = GC.qalloc(newCapacity*T.sizeof, (typeid(T[]).next.flags&1) ? 0 : GC.BlkAttr.NO_SCAN);
    auto newStart = cast(T*)bi.base;
    newCapacity = bi.size;

    newStart[0..size] = start[0..size];
    start = newStart;
    cursor = start+size;
    end = start+newCapacity;
  }

public:
  /// Preallocate
  this (usize capacity) => reserve(capacity);

  /// Start with a given buffer
  this (I[] arr) {
    start = cursor = cast(T*)arr.ptr;
    end = start+arr.length;
  }

  void put(U...) (U items) if (CanPutAll!U) {
    // TODO: check for static if length is 1
    auto cursorEnd = cursor;
    foreach (auto item; items) {
      static if (is(typeof(cursor[0] = item))) ++cursorEnd;
      else static if (is(typeof(cursor[0..1] = item[0..1]))) cursorEnd += item.length;
        // TODO: is this too lax? it allows passing static arrays by value
      else static assert(0, "Can't put "~typeof(item).stringof);
    }
    if (cursorEnd > end) {
      auto len = cursorEnd-cursor;
      reserve(len);
      cursorEnd = cursor+len;
    }
    auto cursor = this.cursor;
    this.cursor = cursorEnd;

    static if (items.length == 1) {
      alias item = items[0];
      static if (is(typeof(cursor[0] = item))) cursor[0] = item;
      else cursor[0..item.length] = item[];
    } else {
      foreach (auto item; items)
        static if (is(typeof(cursor[0] = item))) {
          *cursor++ = item;
        } else static if (is(typeof(cursor[0..1] = item[0..1]))) {
          cursor[0..item.length] = item[];
          cursor += item.length;
        }
    }
  }

  /// Unsafe. Use together with preallocate().
  void uncheckedPut(U...) (U items) if (CanPutAll!U) {
    auto cursor = this.cursor;
    foreach (auto item; items) {
      static if (is(typeof(cursor[0] = item))) {
        *cursor++ = item;
      } else static if (is(typeof(cursor[0..1] = item[0..1]))) {
        cursor[0..item.length] = item;
        cursor += item.length;
      }
    }
    this.cursor = cursor;
  }

  void preallocate (usize len) {
    if (end-cursor < len) reserve(len);
  }

  T[] allocate (usize len) {
    auto cursorEnd = cursor+len;
    if (cursorEnd > end) {
      reserve(len);
      cursorEnd = cursor+len;
    }
    auto result = cursor[0..len];
    cursor = cursorEnd;
    return result;
  }

  template CanPutAll(U...) {
    static if (U.length == 0) {
      enum bool CanPutAll = true;
    } else {
      enum bool CanPutAll =
        (
          is(typeof(cursor[0] = U[0].init)) ||
          is(typeof(cursor[0..1] = U[0].init[0..1]))
        ) && CanPutAll!(U[1..$]);
    }
  }

  void opOpAssign(string op, U) (U item) if (op == "~" && is(typeof(put!U))) => put(item);

  I[] get () => cast(I[])start[0..cursor-start];

  @property usize length () const => cursor-start;

  // mutable types only
  static if (is(I == T)) {
    /// Does not resize. Use preallocate for that.
    @property void length (usize value) {
      cursor = start+value;
      assert(cursor <= end);
    }

    /// Effectively empties the data, but preserves the storage for reuse.
    /// Same as setting length to 0.
    void clear () => cursor = start;
  }
}
