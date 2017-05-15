// WTFPL or Public Domain, on your choice
module iv.glbinds.binds_minimal is aliced;

// lazy loading
version = glbind_lazy_load;

// show loaded functions
//version = glbind_debug;


public import arsd.simpledisplay;


// ////////////////////////////////////////////////////////////////////////// //
extern(C) nothrow @nogc {

alias GLvoid = void;
alias GLintptr = ptrdiff_t;
alias GLsizei = int;
alias GLchar = char;
alias GLcharARB = byte;
alias GLushort = ushort;
alias GLint64EXT = long;
alias GLshort = short;
alias GLuint64 = ulong;
alias GLhalfARB = ushort;
alias GLubyte = ubyte;
alias GLdouble = double;
alias GLhandleARB = uint;
alias GLint64 = long;
alias GLenum = uint;
alias GLeglImageOES = void*;
alias GLintptrARB = ptrdiff_t;
alias GLsizeiptr = ptrdiff_t;
alias GLint = int;
alias GLboolean = ubyte;
alias GLbitfield = uint;
alias GLsizeiptrARB = ptrdiff_t;
alias GLfloat = float;
alias GLuint64EXT = ulong;
alias GLclampf = float;
alias GLbyte = byte;
alias GLclampd = double;
alias GLuint = uint;
alias GLvdpauSurfaceNV = ptrdiff_t;
alias GLfixed = int;
alias GLhalf = ushort;
alias GLclampx = int;
alias GLhalfNV = ushort;
struct ___GLsync; alias __GLsync = ___GLsync*;
alias GLsync = __GLsync*;
struct __cl_context; alias _cl_context = __cl_context*;
struct __cl_event; alias _cl_event = __cl_event*;

enum uint GL_ONE = 1;
enum uint GL_RGBA8 = 0x8058;
enum uint GL_FRAGMENT_SHADER = 0x8B30;
enum uint GL_COMPILE_STATUS = 0x8B81;
enum uint GL_INFO_LOG_LENGTH = 0x8B84;
enum uint GL_FRAMEBUFFER_COMPLETE_EXT = 0x8CD5;
enum uint GL_FRAMEBUFFER_EXT = 0x8D40;
enum uint GL_COLOR_ATTACHMENT0_EXT = 0x8CE0;
enum uint GL_RENDERBUFFER_EXT = 0x8D41;
enum uint GL_DEPTH_COMPONENT16 = 0x81A5;
enum uint GL_DEPTH_COMPONENT24 = 0x81A6;
enum uint GL_DEPTH_COMPONENT32 = 0x81A7;
enum uint GL_DEPTH_ATTACHMENT_EXT = 0x8D00;
enum uint GL_CLAMP_TO_BORDER = 0x812D;
enum uint GL_TEXTURE0 = 0x84C0;
enum uint GL_TEXTURE1 = 0x84C1;
enum uint GL_TEXTURE2 = 0x84C2;
enum uint GL_TEXTURE3 = 0x84C3;
enum uint GL_TEXTURE4 = 0x84C4;
enum uint GL_TEXTURE5 = 0x84C5;
enum uint GL_TEXTURE6 = 0x84C6;
enum uint GL_TEXTURE7 = 0x84C7;
enum uint GL_TEXTURE8 = 0x84C8;
enum uint GL_TEXTURE9 = 0x84C9;
enum uint GL_TEXTURE10 = 0x84CA;
enum uint GL_TEXTURE11 = 0x84CB;
enum uint GL_TEXTURE12 = 0x84CC;
enum uint GL_TEXTURE13 = 0x84CD;
enum uint GL_TEXTURE14 = 0x84CE;
enum uint GL_TEXTURE15 = 0x84CF;
enum uint GL_TEXTURE16 = 0x84D0;
enum uint GL_TEXTURE17 = 0x84D1;
enum uint GL_TEXTURE18 = 0x84D2;
enum uint GL_TEXTURE19 = 0x84D3;
enum uint GL_TEXTURE20 = 0x84D4;
enum uint GL_TEXTURE21 = 0x84D5;
enum uint GL_TEXTURE22 = 0x84D6;
enum uint GL_TEXTURE23 = 0x84D7;
enum uint GL_TEXTURE24 = 0x84D8;
enum uint GL_TEXTURE25 = 0x84D9;
enum uint GL_TEXTURE26 = 0x84DA;
enum uint GL_TEXTURE27 = 0x84DB;
enum uint GL_TEXTURE28 = 0x84DC;
enum uint GL_TEXTURE29 = 0x84DD;
enum uint GL_TEXTURE30 = 0x84DE;
enum uint GL_TEXTURE31 = 0x84DF;
enum uint GL_ACTIVE_TEXTURE = 0x84E0;
enum uint GL_COMPILE = 0x1300;
enum uint GL_COMPILE_AND_EXECUTE = 0x1301;
enum uint GL_TEXTURE_CUBE_MAP = 0x8513;
enum uint GL_TEXTURE_WRAP_R = 0x8072;
enum uint GL_TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515;
enum uint GL_TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516;
enum uint GL_TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517;
enum uint GL_TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518;
enum uint GL_TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519;
enum uint GL_TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A;
enum uint GL_TEXTURE_BORDER_COLOR = 0x1004;
enum uint GL_RGBA16F = 0x881A;
enum uint GL_FLOAT = 0x1406;
enum uint GL_DOUBLE = 0x140A;

alias glbfn_glTexParameterf = void function (GLenum, GLenum, GLfloat);
alias glbfn_glTexParameterfv = void function (GLenum, GLenum, const(GLfloat)*);
alias glbfn_glTexParameteri = void function (GLenum, GLenum, GLint);
alias glbfn_glTexParameteriv = void function (GLenum, GLenum, const(GLint)*);

alias glbfn_glCreateShader = GLuint function (GLenum);
alias glbfn_glShaderSource = void function (GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
alias glbfn_glCompileShader = void function (GLuint);
alias glbfn_glCreateProgram = GLuint function ();
alias glbfn_glAttachShader = void function (GLuint, GLuint);
alias glbfn_glLinkProgram = void function (GLuint);
alias glbfn_glUseProgram = void function (GLuint);
alias glbfn_glGetShaderiv = void function (GLuint, GLenum, GLint*);
alias glbfn_glGetShaderInfoLog = void function (GLuint, GLsizei, GLsizei*, GLchar*);

alias glbfn_glGetUniformLocation = GLint function (GLuint, const(GLchar)*);

alias glbfn_glUniform1f = void function (GLint, GLfloat);
alias glbfn_glUniform2f = void function (GLint, GLfloat, GLfloat);
alias glbfn_glUniform3f = void function (GLint, GLfloat, GLfloat, GLfloat);
alias glbfn_glUniform4f = void function (GLint, GLfloat, GLfloat, GLfloat, GLfloat);
alias glbfn_glUniform1i = void function (GLint, GLint);
alias glbfn_glUniform2i = void function (GLint, GLint, GLint);
alias glbfn_glUniform3i = void function (GLint, GLint, GLint, GLint);
alias glbfn_glUniform4i = void function (GLint, GLint, GLint, GLint, GLint);
alias glbfn_glUniform1fv = void function (GLint, GLsizei, const(GLfloat)*);
alias glbfn_glUniform2fv = void function (GLint, GLsizei, const(GLfloat)*);
alias glbfn_glUniform3fv = void function (GLint, GLsizei, const(GLfloat)*);
alias glbfn_glUniform4fv = void function (GLint, GLsizei, const(GLfloat)*);
alias glbfn_glUniform1iv = void function (GLint, GLsizei, const(GLint)*);
alias glbfn_glUniform2iv = void function (GLint, GLsizei, const(GLint)*);
alias glbfn_glUniform3iv = void function (GLint, GLsizei, const(GLint)*);
alias glbfn_glUniform4iv = void function (GLint, GLsizei, const(GLint)*);
alias glbfn_glUniformMatrix2fv = void function (GLint, GLsizei, GLboolean, const(GLfloat)*);
alias glbfn_glUniformMatrix3fv = void function (GLint, GLsizei, GLboolean, const(GLfloat)*);
alias glbfn_glUniformMatrix4fv = void function (GLint, GLsizei, GLboolean, const(GLfloat)*);

alias glbfn_glGenFramebuffersEXT = void function (GLsizei, GLuint*);
alias glbfn_glBindFramebufferEXT = void function (GLenum, GLuint);
alias glbfn_glFramebufferTexture2DEXT = void function (GLenum, GLenum, GLenum, GLuint, GLint);
alias glbfn_glGenRenderbuffersEXT = void function (GLsizei, GLuint*);
alias glbfn_glRenderbufferStorageEXT = void function (GLenum, GLenum, GLsizei, GLsizei);
alias glbfn_glFramebufferRenderbufferEXT = void function (GLenum, GLenum, GLenum, GLuint);
alias glbfn_glCheckFramebufferStatusEXT = GLenum function (GLenum);
alias glbfn_glBindRenderbufferEXT = void function (GLenum, GLuint);
alias glbfn_glDeleteFramebuffersEXT = void function(GLsizei, const(GLuint)*);
alias glbfn_glIsFramebufferEXT = GLboolean function(GLuint);

alias glbfn_glActiveTexture = void function (GLenum);

alias glbfn_glGenLists = GLuint function (GLsizei);
alias glbfn_glNewList = void function (GLuint, GLenum);
alias glbfn_glEndList = void function ();
alias glbfn_glCallList = void function (GLuint);
alias glbfn_glCallLists = void function (GLsizei, GLenum, const(void)*);
alias glbfn_glDeleteLists = void function (GLuint, GLsizei);

enum uint GL_VERSION = 0x1F02;
enum uint GL_EXTENSIONS = 0x1F03;
enum uint GL_SHADING_LANGUAGE_VERSION = 0x8B8C;

alias glbfn_glGetString = const(char*) function (GLenum);
alias glbfn_glGetStringi = const(char)* function (GLenum, GLuint);

enum uint GL_MAJOR_VERSION = 0x821B;
enum uint GL_MINOR_VERSION = 0x821C;
enum uint GL_NUM_EXTENSIONS = 0x821D;
enum uint GL_NUM_SHADING_LANGUAGE_VERSIONS = 0x82E9;

alias glbfn_glGetIntegerv = void function (GLenum, GLint*);
}


// ////////////////////////////////////////////////////////////////////////// //
version(glbind_lazy_load) {
  private string glbindCreateInternalVars () {
    string res;
    foreach (name; __traits(allMembers, mixin(__MODULE__))) {
      static if (name.length > 6 && name[0..6] == "glbfn_") {
        //pragma(msg, mixin(name));
        import std.traits;
        //pragma(msg, ReturnType!(mixin(name)));
        //pragma(msg, Parameters!(mixin(name)));
        // create pointer
        string pars, call;
        foreach (immutable idx, immutable ptype; Parameters!(mixin(name))) {
          import std.conv : to;
          pars ~= ", "~ptype.stringof~" a"~to!string(idx);
          call ~= "a"~to!string(idx)~",";
        }
        if (pars.length) pars = pars[2..$];
        res ~= "__gshared "~name~" "~name[6..$]~" = function "~
          ReturnType!(mixin(name)).stringof~" "~
          /*Parameters!(mixin(name)).stringof*/"("~pars~") nothrow{\n"~
          // build loader
          "  "~name[6..$]~" = cast("~name~")glGetProcAddress(`"~name[6..$]~"`);\n"~
          "  if ("~name[6..$]~" is null) assert(0, `OpenGL function '"~name[6..$]~"' not found!`);\n"~
          "  version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, \"GLBIND: '"~name[6..$]~"'\\n\"); }\n"~
          "  "~(is(ReturnType!(mixin(name)) == void) ? "" : "return ")~name[6..$]~"("~call~");\n"~
          //"  assert(0, `"~name[6..$]~"`);\n"~
          "};\n";
      }
    }
    return res;
  }
} else {
  private string glbindCreateInternalVars () {
    string res;
    foreach (name; __traits(allMembers, mixin(__MODULE__))) {
      static if (name.length > 6 && name[0..6] == "glbfn_") {
        //pragma(msg, name);
        // create pointer
        res ~= "__gshared "~name~" "~name[6..$]~";\n";
      }
    }
    return res;
  }
}
mixin(glbindCreateInternalVars());


public void glbindLoadFunctions () {
  version(glbind_lazy_load) {} else {
  foreach (name; __traits(allMembers, mixin(__MODULE__))) {
    static if (name.length > 6 && name[0..6] == "glbfn_") {
      //pragma(msg, name);
      // load function
      mixin(name[6..$]~" = cast("~name~")glGetProcAddress(`"~name[6..$]~"`);");
      mixin("if ("~name[6..$]~" is null) assert(0, `OpenGL function '"~name[6..$]~"' not found!`);");
    }
  }
  }
}


//void main () { glbindLoadFunctions(); }
