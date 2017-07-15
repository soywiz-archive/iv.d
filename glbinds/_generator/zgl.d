import std.regex;

import arsd.dom;

import iv.strex;
import iv.vfs.io;

Document gldom;


// ////////////////////////////////////////////////////////////////////////// //
struct TypeAndName {
  string name;
  string type;
  bool needReturn;

  this (Element pp) {
    assert(pp !is null);

    string getName (Element nr) {
      auto ne = nr.querySelector("name");
      assert(ne !is null);
      auto res = ne.innerText.xstrip;
      assert(res.length);
      return res;
    }

    string textNoNameIntr (Element el) {
      string s;
      foreach (Element child; el.children) {
        if (child.tagName == "name") continue;
        if (child.nodeType != NodeType.Text) s ~= textNoNameIntr(child); else s ~= child.nodeValue();
      }
      return s;
    }

    string fixTypes (string s) {
      s = s.xstrip;

      static struct Repl {
        StaticRegex!char re;
        string repl;
        bool cont;
      }

      static Repl[$] replaces = [
        Repl(ctRegex!(`^(Display|DMparams|XVisualInfo|GLXVideoCaptureDeviceNV)\s*\*$`), "/*$1*/void*"),
        Repl(ctRegex!(`^(GLXFBConfigSGIX|GLXFBConfig|GLXContext)\s*\*$`), "/*$1*/void**"),
        Repl(ctRegex!(`^(GLXFBConfigSGIX|GLXFBConfig|GLXContext)$`), "/*$1*/void*"),
        // shitdoze start
        Repl(ctRegex!(`^(HVIDEOINPUTDEVICENV|HVIDEOOUTPUTDEVICENV|HGPUNV|HPVIDEODEV)\s*\*$`), "/*$1*/void**"),
        Repl(ctRegex!(`^(HPBUFFERARB|HPBUFFEREXT|HVIDEOOUTPUTDEVICENV|HPVIDEODEV|HPGPUNV|HGPUNV|HVIDEOINPUTDEVICENV|PGPU_DEVICE)$`), "/*$1*/void*"),
        Repl(ctRegex!(`^const\s+(HGPUNV)\s*\*$`), "/*$1*/const(void)**"),
        // shitdoze end
        Repl(ctRegex!(`^const\s+(GLXContext)$`), "/*$1*/const(void)*"),
        Repl(ctRegex!(`\bunsigned\s+int\b`), "uint", true),
        Repl(ctRegex!(`\bunsigned\s+long\b`), "c_ulong", true),
        Repl(ctRegex!(`\blong\b`), "c_long", true),
        Repl(ctRegex!(`\bBool\b`), "int", true),
        Repl(ctRegex!(`\bint32_t\b`), "int", true),
        Repl(ctRegex!(`\bint64_t\b`), "long", true),
        Repl(ctRegex!(`\bGLXVideoDeviceNV\b`), "uint", true), // unsigned int
        Repl(ctRegex!(`^(Status|Font|GLXPbufferSGIX|Window|GLXDrawable|GLXVideoCaptureDeviceNV|GLXPbuffer|GLXPixmap|Pixmap|Colormap|GLXVideoSourceSGIX|GLXWindow|GLXVideoCaptureDeviceNV|GLXContextID)$`), "/*$1*/c_ulong"), // XID
        //Repl(ctRegex!(`^(GLXVideoCaptureDeviceNV)$`), "/*$1*/c_ulong"), // XID
        Repl(ctRegex!(`^(DMbuffer)$`), "/*$1*/void*"),
        Repl(ctRegex!(`^const\s+([^\s*]+)\s*(\*+)$`), "const($1)$2"),
      ];

      //if (s.indexOf("Display") >= 0) stderr.writeln("|", s, "|");

      foreach (ref repl; replaces[]) {
        auto mt = s.matchFirst(repl.re);
        if (!mt.empty) {
          s = s.replaceAll(repl.re, repl.repl);
          if (!repl.cont) break;
        }
      }
      for (;;) {
        auto pos = s.indexOf("* ");
        if (pos < 0) break;
        ++pos;
        while (pos < s.length && s[pos] == ' ') s = s[0..pos]~s[pos+1..$];
      }
      for (;;) {
        auto pos = s.indexOf(" *");
        if (pos < 0) break;
        while (pos > 0 && s[pos-1] == ' ') --pos;
        while (pos < s.length && s[pos] == ' ') s = s[0..pos]~s[pos+1..$];
      }
      if (s == "const GLchar*const*") s = "const(GLchar)**";
      if (s == "const void*const*") s = "const(void)**";
      return s;
    }

    string textNoName (Element el) {
      return fixTypes(textNoNameIntr(el));
    }

    name = getName(pp);
    if (name == "ref" || name == "in" || name == "out" || name == "version" || name == "align") name ~= "_";

    type = textNoName(pp);
    needReturn = (type != "void");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void parseCommand (Element cmd) {
  assert(cmd !is null);
  auto nameres = cmd.querySelector("proto");
  assert(nameres !is null);

  auto fntype = TypeAndName(nameres);

  switch (fntype.name) {
    case "glCreateSyncFromCLeventARB": return;
    case "glPathGlyphIndexRangeNV": return; // [2]
    case "SwapBuffers": return; // shitdoze
    case "ChoosePixelFormat": return; // shitdoze
    case "DescribePixelFormat": return; // shitdoze
    case "GetPixelFormat": return; // shitdoze
    case "SetPixelFormat": return; // shitdoze
    case "wglGetProcAddress": return; // shitdoze
    case "glXGetProcAddress": return;
    case "glXGetProcAddressARB": return;
    default: break;
  }

  if (fntype.name.endsWith("SGIX")) {
    //stderr.writeln(fntype.name);
    return;
  }

  TypeAndName[] args;
  foreach (Element param; cmd.querySelectorAll("param")) args ~= TypeAndName(param);

  if (fntype.name == "glXChooseVisual") {
    args[2].type = "const(int)*";
  }

  if (fntype.name == "glXGetProcAddress" || fntype.name == "glXGetProcAddressARB") {
    args[0].type = "const(char)*";
  }

  string getArgs () {
    string res = "(";
    bool needComma = false;
    foreach (const ref TypeAndName tn; args) {
      if (needComma) res ~= ", "; else needComma = true;
      res ~= tn.type;
      res ~= " ";
      res ~= tn.name;
    }
    res ~= ")";
    return res;
  }

  string getCall () {
    string res = "(";
    bool needComma = false;
    foreach (const ref TypeAndName tn; args) {
      if (needComma) res ~= ", "; else needComma = true;
      res ~= tn.name;
    }
    res ~= ")";
    return res;
  }

  string intrName = fntype.name~"_Z_Z_";
  string ldrName = intrName~"_loader_";

  writeln("alias ", fntype.name, " = ", intrName, ";");
  writeln("__gshared ", intrName, " = function ", fntype.type, " ", getArgs(), " { ", (fntype.needReturn ? "return " : ""), ldrName, getCall(), "; };");
  // loader
  writeln("private ", fntype.type, " ", ldrName, " ", getArgs(), " {");
  writeln("  *cast(void**)&", intrName, " = glbindGetProcAddress(`", fntype.name, "`);");
  writeln("  if (*cast(void**)&", intrName, " is null) assert(0, `OpenGL function '", fntype.name, "' not found!`);");
  writeln("  ", (fntype.needReturn ? "return " : ""), intrName, getCall(), ";");
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


void main (string[] args) {
  gldom = new XmlDocument(readTextFile(args.length == 1 ? "gl.xml" : args[1]));
  writeln("// enums");
  foreach (Element glenum; gldom.querySelectorAll("enums")) {
    //writeln(glenum.getAttribute("namespace"), ":", glenum.getAttribute("group"), " -- ", glenum.getAttribute("comment"));
    //<enum value="0x00000001" name="GL_CURRENT_BIT"/>
    foreach (Element it; glenum.querySelectorAll("enum[value][name]")) {
      string name = it.getAttribute("name").xstrip;
      assert(name.length);
      if (name[0] == '_') continue;
      if (name.endsWith("SGIX")) continue;
      string value = it.getAttribute("value").xstrip;
      assert(value.length);
      if (value[0] == '"') continue;
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
      writeln("enum ", type, " ", name, " = ", value, pfx, ";");
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
