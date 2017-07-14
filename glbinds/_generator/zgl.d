import std.regex;

import arsd.dom;

import iv.strex;
import iv.vfs.io;

Document gldom;

auto xre = ctRegex!(`^const\s+([^\s*]+)\s*(\*+)\s*(.+)$`);
auto repre = ctRegex!(`\b(ref|in|out)\b`);
//auto fuckre = ctRegex!(`\*\s*const\s*\*`);
auto fuckre = ctRegex!(`\bconst\s*(\*+)`);

void parseCommand (Element cmd) {
  string getType (Element nr) {
    auto tp = nr.querySelector("ptype");
    if (tp is null) return "void";
    auto res = tp.innerText.xstrip;
    assert(res.length);
    return res;
  }

  string getName (Element nr) {
    auto ne = nr.querySelector("name");
    assert(ne !is null);
    auto res = ne.innerText.xstrip;
    assert(res.length);
    return res;
  }

  assert(cmd !is null);
  auto nameres = cmd.querySelector("proto");
  assert(nameres !is null);

  switch (getName(nameres)) {
    case "glCreateSyncFromCLeventARB": return;
    case "glPathGlyphIndexRangeNV": return; // [2]
    default: break;
  }

  /*
  write(getType(nameres), " ", getName(nameres), " (");
  bool needComma = false;
  foreach (Element param; cmd.querySelectorAll("param")) {
    if (needComma) write(", "); else needComma = true;
    write(getType(param), " ", getName(param));
  }
  writeln(");");
  */

  string textNoNameIntr (Element el) {
    string s;
    foreach (Element child; el.children) {
      if (child.tagName == "name") continue;
      if (child.nodeType != NodeType.Text) s ~= textNoNameIntr(child); else s ~= child.nodeValue();
    }
    return s;
  }

  string fixPointers (string s) {
    auto mt = s.matchFirst(xre);
    if (mt.empty) return s;
    string res = "const("~mt[1]~")"~mt[2]~" "~(mt[3].replaceAll(fuckre, "$1"));
    return res;
  }

  string textNoName (Element el) {
    return fixPointers(textNoNameIntr(el)~" _")[0..$-2];
  }

  string getArgs () {
    string res = "(";
    bool needComma = false;
    foreach (Element param; cmd.querySelectorAll("param")) {
      if (needComma) res ~= ", "; else needComma = true;
      res ~= fixPointers(param.innerText.xstrip.replaceAll(repre, "$1_"));
    }
    res ~= ")";
    return res;
  }

  string getCall () {
    string res = "(";
    bool needComma = false;
    foreach (Element param; cmd.querySelectorAll("param")) {
      if (needComma) res ~= ", "; else needComma = true;
      res ~= getName(param).replaceAll(repre, "$1_");
    }
    res ~= ")";
    return res;
  }

  writeln("alias ", getName(nameres), " = ", getName(nameres), "_Z_Z;");
  write("__gshared ", getName(nameres), "_Z_Z = function ", textNoName(nameres).xstrip, " ", getArgs(), " { ");
  if (textNoName(nameres).xstrip != "void") write("return ");
  write(getName(nameres), "_Z_Z_loader", getCall(), ";");
  writeln(" };");
  // loader
  writeln("private ", textNoName(nameres).xstrip, " ", getName(nameres), "_Z_Z_loader ", getArgs(), " {");
  writeln("  *cast(void**)&", getName(nameres), "_Z_Z = glbindGetProcAddress(`", getName(nameres), "`);");
  writeln("  if (*cast(void**)&", getName(nameres), "_Z_Z is null) assert(0, `OpenGL function '", getName(nameres), "' not found!`);");
  write("  ");
  if (textNoName(nameres).xstrip != "void") write("return ");
  writeln(getName(nameres), "_Z_Z", getCall(), ";");
  writeln("}");

/*
private const(char)* glbfn_glGetString_loader (uint a00) {
  *cast(void**)&glGetString_Z = glbindGetProcAddress(`glGetString`);
  if (*cast(void**)&glGetString_Z is null) assert(0, `OpenGL function 'glGetString' not found!`);
  return glGetString_Z(a00,);
}
*/

  /*
  write(fixPointers(nameres.innerText.xstrip), "_Z_Z (");
  bool needComma = false;
  foreach (Element param; cmd.querySelectorAll("param")) {
    if (needComma) write(", "); else needComma = true;
    write(fixPointers(param.innerText.xstrip));
  }
  writeln(");");
  */
}


void main () {
  gldom = new XmlDocument(readTextFile("gl.xml"));
  writeln("// enums");
  foreach (Element glenum; gldom.querySelectorAll("enums")) {
    //writeln(glenum.getAttribute("namespace"), ":", glenum.getAttribute("group"), " -- ", glenum.getAttribute("comment"));
    //<enum value="0x00000001" name="GL_CURRENT_BIT"/>
    foreach (Element it; glenum.querySelectorAll("enum[value][name]")) {
      string api = it.getAttribute("api");
      if (api == "gles2") continue; // fuck off
      if (api.length && api != "gl") {
        if (api.length) assert(0, api);
      }
      string type = it.getAttribute("type");
      string pfx = "U";
      if (type.length == 0 || type == "u") {
        type = "uint";
      } else if (type == "ull") {
        type = "ulong";
        pfx = "UL";
      } else if (type.length) {
        assert(0, type);
      }
      writeln("enum ", type, " ", it.getAttribute("name"), " = ", it.getAttribute("value"), pfx, ";");
    }
  }
  writeln;
  writeln("// API");
  foreach (Element cmd; gldom.querySelectorAll("commands > command")) {
    try {
      parseCommand(cmd);
    } catch (Throwable e) {
      writeln("-------------------------");
      writeln(cmd.outerHTML);
      writeln("-------------------------");
      throw e;
    }
  }
}


/*
<command>
    <proto>void <name>glApplyTextureEXT</name></proto>
    <param group="LightTextureModeEXT"><ptype>GLenum</ptype> <name>mode</name></param>
</command>
<command>
    <proto><ptype>GLboolean</ptype> <name>glAcquireKeyedMutexWin32EXT</name></proto>
    <param><ptype>GLuint</ptype> <name>memory</name></param>
    <param><ptype>GLuint64</ptype> <name>key</name></param>
    <param><ptype>GLuint</ptype> <name>timeout</name></param>
</command>
*/
