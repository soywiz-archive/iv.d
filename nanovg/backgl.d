//
// Copyright (c) 2009-2013 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//
/* Invisible Vector Library
 * ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 * yes, this D port is GPLed. thanks to all "active" members of D
 * community, and for all (zero) feedback posts.
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
module iv.nanovg.backgl;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memcpy, memset;

import iv.nanovg.engine;
import arsd.simpledisplay;

// sdpy is missing that yet
static if (!is(typeof(GL_STENCIL_BUFFER_BIT))) enum uint GL_STENCIL_BUFFER_BIT = 0x00000400;


// OpenGL API missing from simpledisplay
private extern(C) nothrow @nogc {
  alias GLvoid = void;
  alias GLboolean = ubyte;
  alias GLuint = uint;
  alias GLenum = uint;
  alias GLchar = char;
  alias GLsizei = int;
  alias GLfloat = float;
  alias GLsizeiptr = ptrdiff_t;

  enum uint GL_ZERO = 0;
  enum uint GL_ONE = 1;

  enum uint GL_FLOAT = 0x1406;

  enum uint GL_STREAM_DRAW = 0x88E0;

  enum uint GL_CCW = 0x0901;

  enum uint GL_STENCIL_TEST = 0x0B90;
  enum uint GL_SCISSOR_TEST = 0x0C11;

  enum uint GL_EQUAL = 0x0202;
  enum uint GL_NOTEQUAL = 0x0205;

  enum uint GL_ALWAYS = 0x0207;
  enum uint GL_KEEP = 0x1E00;

  enum uint GL_INCR = 0x1E02;

  enum uint GL_INCR_WRAP = 0x8507;
  enum uint GL_DECR_WRAP = 0x8508;

  enum uint GL_CULL_FACE = 0x0B44;
  enum uint GL_BACK = 0x0405;

  enum uint GL_FRAGMENT_SHADER = 0x8B30;
  enum uint GL_VERTEX_SHADER = 0x8B31;

  enum uint GL_COMPILE_STATUS = 0x8B81;
  enum uint GL_LINK_STATUS = 0x8B82;

  enum uint GL_UNPACK_ALIGNMENT = 0x0CF5;
  enum uint GL_UNPACK_ROW_LENGTH = 0x0CF2;
  enum uint GL_UNPACK_SKIP_PIXELS = 0x0CF4;
  enum uint GL_UNPACK_SKIP_ROWS = 0x0CF3;

  enum uint GL_GENERATE_MIPMAP = 0x8191;
  enum uint GL_LINEAR_MIPMAP_LINEAR = 0x2703;

  enum uint GL_RED = 0x1903;

  enum uint GL_TEXTURE0 = 0x84C0;

  enum uint GL_ARRAY_BUFFER = 0x8892;

  alias glbfn_glStencilMask = void function(GLuint);
  __gshared glbfn_glStencilMask glStencilMask = function void (GLuint a0) nothrow {
    glStencilMask = cast(glbfn_glStencilMask)glGetProcAddress(`glStencilMask`);
    if (glStencilMask is null) assert(0, `OpenGL function 'glStencilMask' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glStencilMask'\n"); }
    glStencilMask(a0,);
  };

  alias glbfn_glStencilFunc = void function(GLenum, GLint, GLuint);
  __gshared glbfn_glStencilFunc glStencilFunc = function void (GLenum a0, GLint a1, GLuint a2) nothrow {
    glStencilFunc = cast(glbfn_glStencilFunc)glGetProcAddress(`glStencilFunc`);
    if (glStencilFunc is null) assert(0, `OpenGL function 'glStencilFunc' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glStencilFunc'\n"); }
    glStencilFunc(a0,a1,a2,);
  };

  alias glbfn_glGetShaderInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
  __gshared glbfn_glGetShaderInfoLog glGetShaderInfoLog = function void (GLuint a0, GLsizei a1, GLsizei* a2, GLchar* a3) nothrow {
    glGetShaderInfoLog = cast(glbfn_glGetShaderInfoLog)glGetProcAddress(`glGetShaderInfoLog`);
    if (glGetShaderInfoLog is null) assert(0, `OpenGL function 'glGetShaderInfoLog' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glGetShaderInfoLog'\n"); }
    glGetShaderInfoLog(a0,a1,a2,a3,);
  };

  alias glbfn_glGetProgramInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
  __gshared glbfn_glGetProgramInfoLog glGetProgramInfoLog = function void (GLuint a0, GLsizei a1, GLsizei* a2, GLchar* a3) nothrow {
    glGetProgramInfoLog = cast(glbfn_glGetProgramInfoLog)glGetProcAddress(`glGetProgramInfoLog`);
    if (glGetProgramInfoLog is null) assert(0, `OpenGL function 'glGetProgramInfoLog' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glGetProgramInfoLog'\n"); }
    glGetProgramInfoLog(a0,a1,a2,a3,);
  };

  alias glbfn_glCreateProgram = GLuint function();
  __gshared glbfn_glCreateProgram glCreateProgram = function GLuint () nothrow {
    glCreateProgram = cast(glbfn_glCreateProgram)glGetProcAddress(`glCreateProgram`);
    if (glCreateProgram is null) assert(0, `OpenGL function 'glCreateProgram' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glCreateProgram'\n"); }
    return glCreateProgram();
  };

  alias glbfn_glCreateShader = GLuint function(GLenum);
  __gshared glbfn_glCreateShader glCreateShader = function GLuint (GLenum a0) nothrow {
    glCreateShader = cast(glbfn_glCreateShader)glGetProcAddress(`glCreateShader`);
    if (glCreateShader is null) assert(0, `OpenGL function 'glCreateShader' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glCreateShader'\n"); }
    return glCreateShader(a0,);
  };

  alias glbfn_glShaderSource = void function(GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
  __gshared glbfn_glShaderSource glShaderSource = function void (GLuint a0, GLsizei a1, const(GLchar*)* a2, const(GLint)* a3) nothrow {
    glShaderSource = cast(glbfn_glShaderSource)glGetProcAddress(`glShaderSource`);
    if (glShaderSource is null) assert(0, `OpenGL function 'glShaderSource' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glShaderSource'\n"); }
    glShaderSource(a0,a1,a2,a3,);
  };

  alias glbfn_glCompileShader = void function(GLuint);
  __gshared glbfn_glCompileShader glCompileShader = function void (GLuint a0) nothrow {
    glCompileShader = cast(glbfn_glCompileShader)glGetProcAddress(`glCompileShader`);
    if (glCompileShader is null) assert(0, `OpenGL function 'glCompileShader' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glCompileShader'\n"); }
    glCompileShader(a0,);
  };

  alias glbfn_glGetShaderiv = void function(GLuint, GLenum, GLint*);
  __gshared glbfn_glGetShaderiv glGetShaderiv = function void (GLuint a0, GLenum a1, GLint* a2) nothrow {
    glGetShaderiv = cast(glbfn_glGetShaderiv)glGetProcAddress(`glGetShaderiv`);
    if (glGetShaderiv is null) assert(0, `OpenGL function 'glGetShaderiv' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glGetShaderiv'\n"); }
    glGetShaderiv(a0,a1,a2,);
  };

  alias glbfn_glAttachShader = void function(GLuint, GLuint);
  __gshared glbfn_glAttachShader glAttachShader = function void (GLuint a0, GLuint a1) nothrow {
    glAttachShader = cast(glbfn_glAttachShader)glGetProcAddress(`glAttachShader`);
    if (glAttachShader is null) assert(0, `OpenGL function 'glAttachShader' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glAttachShader'\n"); }
    glAttachShader(a0,a1,);
  };

  alias glbfn_glBindAttribLocation = void function(GLuint, GLuint, const(GLchar)*);
  __gshared glbfn_glBindAttribLocation glBindAttribLocation = function void (GLuint a0, GLuint a1, const(GLchar)* a2) nothrow {
    glBindAttribLocation = cast(glbfn_glBindAttribLocation)glGetProcAddress(`glBindAttribLocation`);
    if (glBindAttribLocation is null) assert(0, `OpenGL function 'glBindAttribLocation' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glBindAttribLocation'\n"); }
    glBindAttribLocation(a0,a1,a2,);
  };

  alias glbfn_glLinkProgram = void function(GLuint);
  __gshared glbfn_glLinkProgram glLinkProgram = function void (GLuint a0) nothrow {
    glLinkProgram = cast(glbfn_glLinkProgram)glGetProcAddress(`glLinkProgram`);
    if (glLinkProgram is null) assert(0, `OpenGL function 'glLinkProgram' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glLinkProgram'\n"); }
    glLinkProgram(a0,);
  };

  alias glbfn_glGetProgramiv = void function(GLuint, GLenum, GLint*);
  __gshared glbfn_glGetProgramiv glGetProgramiv = function void (GLuint a0, GLenum a1, GLint* a2) nothrow {
    glGetProgramiv = cast(glbfn_glGetProgramiv)glGetProcAddress(`glGetProgramiv`);
    if (glGetProgramiv is null) assert(0, `OpenGL function 'glGetProgramiv' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glGetProgramiv'\n"); }
    glGetProgramiv(a0,a1,a2,);
  };

  alias glbfn_glDeleteProgram = void function(GLuint);
  __gshared glbfn_glDeleteProgram glDeleteProgram = function void (GLuint a0) nothrow {
    glDeleteProgram = cast(glbfn_glDeleteProgram)glGetProcAddress(`glDeleteProgram`);
    if (glDeleteProgram is null) assert(0, `OpenGL function 'glDeleteProgram' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glDeleteProgram'\n"); }
    glDeleteProgram(a0,);
  };

  alias glbfn_glDeleteShader = void function(GLuint);
  __gshared glbfn_glDeleteShader glDeleteShader = function void (GLuint a0) nothrow {
    glDeleteShader = cast(glbfn_glDeleteShader)glGetProcAddress(`glDeleteShader`);
    if (glDeleteShader is null) assert(0, `OpenGL function 'glDeleteShader' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glDeleteShader'\n"); }
    glDeleteShader(a0,);
  };

  alias glbfn_glGetUniformLocation = GLint function(GLuint, const(GLchar)*);
  __gshared glbfn_glGetUniformLocation glGetUniformLocation = function GLint (GLuint a0, const(GLchar)* a1) nothrow {
    glGetUniformLocation = cast(glbfn_glGetUniformLocation)glGetProcAddress(`glGetUniformLocation`);
    if (glGetUniformLocation is null) assert(0, `OpenGL function 'glGetUniformLocation' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glGetUniformLocation'\n"); }
    return glGetUniformLocation(a0,a1,);
  };

  alias glbfn_glGenBuffers = void function(GLsizei, GLuint*);
  __gshared glbfn_glGenBuffers glGenBuffers = function void (GLsizei a0, GLuint* a1) nothrow {
    glGenBuffers = cast(glbfn_glGenBuffers)glGetProcAddress(`glGenBuffers`);
    if (glGenBuffers is null) assert(0, `OpenGL function 'glGenBuffers' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glGenBuffers'\n"); }
    glGenBuffers(a0,a1,);
  };

  alias glbfn_glPixelStorei = void function(GLenum, GLint);
  __gshared glbfn_glPixelStorei glPixelStorei = function void (GLenum a0, GLint a1) nothrow {
    glPixelStorei = cast(glbfn_glPixelStorei)glGetProcAddress(`glPixelStorei`);
    if (glPixelStorei is null) assert(0, `OpenGL function 'glPixelStorei' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glPixelStorei'\n"); }
    glPixelStorei(a0,a1,);
  };

  alias glbfn_glUniform4fv = void function(GLint, GLsizei, const(GLfloat)*);
  __gshared glbfn_glUniform4fv glUniform4fv = function void (GLint a0, GLsizei a1, const(GLfloat)* a2) nothrow {
    glUniform4fv = cast(glbfn_glUniform4fv)glGetProcAddress(`glUniform4fv`);
    if (glUniform4fv is null) assert(0, `OpenGL function 'glUniform4fv' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glUniform4fv'\n"); }
    glUniform4fv(a0,a1,a2,);
  };

  alias glbfn_glColorMask = void function(GLboolean, GLboolean, GLboolean, GLboolean);
  __gshared glbfn_glColorMask glColorMask = function void (GLboolean a0, GLboolean a1, GLboolean a2, GLboolean a3) nothrow {
    glColorMask = cast(glbfn_glColorMask)glGetProcAddress(`glColorMask`);
    if (glColorMask is null) assert(0, `OpenGL function 'glColorMask' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glColorMask'\n"); }
    glColorMask(a0,a1,a2,a3,);
  };

  alias glbfn_glStencilOpSeparate = void function(GLenum, GLenum, GLenum, GLenum);
  __gshared glbfn_glStencilOpSeparate glStencilOpSeparate = function void (GLenum a0, GLenum a1, GLenum a2, GLenum a3) nothrow {
    glStencilOpSeparate = cast(glbfn_glStencilOpSeparate)glGetProcAddress(`glStencilOpSeparate`);
    if (glStencilOpSeparate is null) assert(0, `OpenGL function 'glStencilOpSeparate' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glStencilOpSeparate'\n"); }
    glStencilOpSeparate(a0,a1,a2,a3,);
  };

  alias glbfn_glDrawArrays = void function(GLenum, GLint, GLsizei);
  __gshared glbfn_glDrawArrays glDrawArrays = function void (GLenum a0, GLint a1, GLsizei a2) nothrow {
    glDrawArrays = cast(glbfn_glDrawArrays)glGetProcAddress(`glDrawArrays`);
    if (glDrawArrays is null) assert(0, `OpenGL function 'glDrawArrays' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glDrawArrays'\n"); }
    glDrawArrays(a0,a1,a2,);
  };

  alias glbfn_glStencilOp = void function(GLenum, GLenum, GLenum);
  __gshared glbfn_glStencilOp glStencilOp = function void (GLenum a0, GLenum a1, GLenum a2) nothrow {
    glStencilOp = cast(glbfn_glStencilOp)glGetProcAddress(`glStencilOp`);
    if (glStencilOp is null) assert(0, `OpenGL function 'glStencilOp' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glStencilOp'\n"); }
    glStencilOp(a0,a1,a2,);
  };

  alias glbfn_glUseProgram = void function(GLuint);
  __gshared glbfn_glUseProgram glUseProgram = function void (GLuint a0) nothrow {
    glUseProgram = cast(glbfn_glUseProgram)glGetProcAddress(`glUseProgram`);
    if (glUseProgram is null) assert(0, `OpenGL function 'glUseProgram' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glUseProgram'\n"); }
    glUseProgram(a0,);
  };

  alias glbfn_glCullFace = void function(GLenum);
  __gshared glbfn_glCullFace glCullFace = function void (GLenum a0) nothrow {
    glCullFace = cast(glbfn_glCullFace)glGetProcAddress(`glCullFace`);
    if (glCullFace is null) assert(0, `OpenGL function 'glCullFace' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glCullFace'\n"); }
    glCullFace(a0,);
  };

  alias glbfn_glFrontFace = void function(GLenum);
  __gshared glbfn_glFrontFace glFrontFace = function void (GLenum a0) nothrow {
    glFrontFace = cast(glbfn_glFrontFace)glGetProcAddress(`glFrontFace`);
    if (glFrontFace is null) assert(0, `OpenGL function 'glFrontFace' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glFrontFace'\n"); }
    glFrontFace(a0,);
  };

  alias glbfn_glActiveTexture = void function(GLenum);
  __gshared glbfn_glActiveTexture glActiveTexture = function void (GLenum a0) nothrow {
    glActiveTexture = cast(glbfn_glActiveTexture)glGetProcAddress(`glActiveTexture`);
    if (glActiveTexture is null) assert(0, `OpenGL function 'glActiveTexture' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glActiveTexture'\n"); }
    glActiveTexture(a0,);
  };

  alias glbfn_glBindBuffer = void function(GLenum, GLuint);
  __gshared glbfn_glBindBuffer glBindBuffer = function void (GLenum a0, GLuint a1) nothrow {
    glBindBuffer = cast(glbfn_glBindBuffer)glGetProcAddress(`glBindBuffer`);
    if (glBindBuffer is null) assert(0, `OpenGL function 'glBindBuffer' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glBindBuffer'\n"); }
    glBindBuffer(a0,a1,);
  };

  alias glbfn_glBufferData = void function(GLenum, GLsizeiptr, const(void)*, GLenum);
  __gshared glbfn_glBufferData glBufferData = function void (GLenum a0, GLsizeiptr a1, const(void)* a2, GLenum a3) nothrow {
    glBufferData = cast(glbfn_glBufferData)glGetProcAddress(`glBufferData`);
    if (glBufferData is null) assert(0, `OpenGL function 'glBufferData' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glBufferData'\n"); }
    glBufferData(a0,a1,a2,a3,);
  };

  alias glbfn_glEnableVertexAttribArray = void function(GLuint);
  __gshared glbfn_glEnableVertexAttribArray glEnableVertexAttribArray = function void (GLuint a0) nothrow {
    glEnableVertexAttribArray = cast(glbfn_glEnableVertexAttribArray)glGetProcAddress(`glEnableVertexAttribArray`);
    if (glEnableVertexAttribArray is null) assert(0, `OpenGL function 'glEnableVertexAttribArray' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glEnableVertexAttribArray'\n"); }
    glEnableVertexAttribArray(a0,);
  };

  alias glbfn_glVertexAttribPointer = void function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
  __gshared glbfn_glVertexAttribPointer glVertexAttribPointer = function void (GLuint a0, GLint a1, GLenum a2, GLboolean a3, GLsizei a4, const(void)* a5) nothrow {
    glVertexAttribPointer = cast(glbfn_glVertexAttribPointer)glGetProcAddress(`glVertexAttribPointer`);
    if (glVertexAttribPointer is null) assert(0, `OpenGL function 'glVertexAttribPointer' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glVertexAttribPointer'\n"); }
    glVertexAttribPointer(a0,a1,a2,a3,a4,a5,);
  };

  alias glbfn_glUniform1i = void function(GLint, GLint);
  __gshared glbfn_glUniform1i glUniform1i = function void (GLint a0, GLint a1) nothrow {
    glUniform1i = cast(glbfn_glUniform1i)glGetProcAddress(`glUniform1i`);
    if (glUniform1i is null) assert(0, `OpenGL function 'glUniform1i' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glUniform1i'\n"); }
    glUniform1i(a0,a1,);
  };

  alias glbfn_glUniform2fv = void function(GLint, GLsizei, const(GLfloat)*);
  __gshared glbfn_glUniform2fv glUniform2fv = function void (GLint a0, GLsizei a1, const(GLfloat)* a2) nothrow {
    glUniform2fv = cast(glbfn_glUniform2fv)glGetProcAddress(`glUniform2fv`);
    if (glUniform2fv is null) assert(0, `OpenGL function 'glUniform2fv' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glUniform2fv'\n"); }
    glUniform2fv(a0,a1,a2,);
  };

  alias glbfn_glDisableVertexAttribArray = void function(GLuint);
  __gshared glbfn_glDisableVertexAttribArray glDisableVertexAttribArray = function void (GLuint a0) nothrow {
    glDisableVertexAttribArray = cast(glbfn_glDisableVertexAttribArray)glGetProcAddress(`glDisableVertexAttribArray`);
    if (glDisableVertexAttribArray is null) assert(0, `OpenGL function 'glDisableVertexAttribArray' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glDisableVertexAttribArray'\n"); }
    glDisableVertexAttribArray(a0,);
  };

  alias glbfn_glDeleteBuffers = void function(GLsizei, const(GLuint)*);
  __gshared glbfn_glDeleteBuffers glDeleteBuffers = function void (GLsizei a0, const(GLuint)* a1) nothrow {
    glDeleteBuffers = cast(glbfn_glDeleteBuffers)glGetProcAddress(`glDeleteBuffers`);
    if (glDeleteBuffers is null) assert(0, `OpenGL function 'glDeleteBuffers' not found!`);
    version(glbind_debug) { import core.stdc.stdio; fprintf(stderr, "GLBIND: 'glDeleteBuffers'\n"); }
    glDeleteBuffers(a0,a1,);
  };
}


// Create flags
alias NVGcreateFlags = int;
enum /*NVGcreateFlags*/ {
  // Flag indicating if geometry based anti-aliasing is used (may not be needed when using MSAA).
  NVG_ANTIALIAS = 1<<0,
  // Flag indicating if strokes should be drawn using stencil buffer. The rendering will be a little
  // slower, but path overlaps (i.e. self-intersecting or sharp turns) will be drawn just once.
  NVG_STENCIL_STROKES = 1<<1,
  // Flag indicating that additional debug checks are done.
  NVG_DEBUG = 1<<2,
}

enum NANOVG_GL_USE_STATE_FILTER = true;

// Creates NanoVG contexts for different OpenGL (ES) versions.
// Flags should be combination of the create flags above.

//!NVGcontext* nvgCreateGL2(int flags);
//!void nvgDeleteGL2(NVGcontext* ctx);

//!int nvglCreateImageFromHandleGL2(NVGcontext* ctx, GLuint textureId, int w, int h, int flags);
//!GLuint nvglImageFromHandleGL2(NVGcontext* ctx, int image);


// These are additional flags on top of NVGimageFlags.
alias NVGimageFlagsGL = int;
enum /*NVGimageFlagsGL*/ {
  NVG_IMAGE_NODELETE = 1<<16,  // Do not delete GL texture handle.
}


/// Return flags for glClear().
uint nvgGlClearFlags () pure nothrow @safe @nogc {
  pragma(inline, true);
  return (GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
}


// ////////////////////////////////////////////////////////////////////////// //
private:

alias GLNVGuniformLoc = int;
enum /*GLNVGuniformLoc*/ {
  GLNVG_LOC_VIEWSIZE,
  GLNVG_LOC_TEX,
  GLNVG_LOC_FRAG,
  GLNVG_MAX_LOCS,
}

alias GLNVGshaderType = int;
enum /*GLNVGshaderType*/ {
  NSVG_SHADER_FILLGRAD,
  NSVG_SHADER_FILLIMG,
  NSVG_SHADER_SIMPLE,
  NSVG_SHADER_IMG,
}

struct GLNVGshader {
  GLuint prog;
  GLuint frag;
  GLuint vert;
  GLint[GLNVG_MAX_LOCS] loc;
}

struct GLNVGtexture {
  int id;
  GLuint tex;
  int width, height;
  NVGtexture type;
  int flags;
}

alias GLNVGcallType = int;
enum /*GLNVGcallType*/ {
  GLNVG_NONE = 0,
  GLNVG_FILL,
  GLNVG_CONVEXFILL,
  GLNVG_STROKE,
  GLNVG_TRIANGLES,
}

struct GLNVGcall {
  int type;
  int image;
  int pathOffset;
  int pathCount;
  int triangleOffset;
  int triangleCount;
  int uniformOffset;
}

struct GLNVGpath {
  int fillOffset;
  int fillCount;
  int strokeOffset;
  int strokeCount;
}

enum NANOVG_GL_UNIFORMARRAY_SIZE = 11;
struct GLNVGfragUniforms {
  // note: after modifying layout or size of uniform array,
  // don't forget to also update the fragment shader source!
  union {
    struct {
      float[12] scissorMat; // matrices are actually 3 vec4s
      float[12] paintMat;
      NVGcolor innerCol;
      NVGcolor outerCol;
      float[2] scissorExt;
      float[2] scissorScale;
      float[2] extent;
      float radius;
      float feather;
      float strokeMult;
      float strokeThr;
      float texType;
      float type;
    }
    float[4][NANOVG_GL_UNIFORMARRAY_SIZE] uniformArray;
  }
}

struct GLNVGcontext {
  GLNVGshader shader;
  GLNVGtexture* textures;
  float[2] view;
  int ntextures;
  int ctextures;
  int textureId;
  GLuint vertBuf;
  int fragSize;
  int flags;

  // Per frame buffers
  GLNVGcall* calls;
  int ccalls;
  int ncalls;
  GLNVGpath* paths;
  int cpaths;
  int npaths;
  NVGvertex* verts;
  int cverts;
  int nverts;
  ubyte* uniforms;
  int cuniforms;
  int nuniforms;

  // cached state
  static if (NANOVG_GL_USE_STATE_FILTER) {
    GLuint boundTexture;
    GLuint stencilMask;
    GLenum stencilFunc;
    GLint stencilFuncRef;
    GLuint stencilFuncMask;
  }
}

int glnvg__maxi() (int a, int b) { pragma(inline, true); return (a > b ? a : b); }

void glnvg__bindTexture (GLNVGcontext* gl, GLuint tex) {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.boundTexture != tex) {
      gl.boundTexture = tex;
      glBindTexture(GL_TEXTURE_2D, tex);
    }
  } else {
    glBindTexture(GL_TEXTURE_2D, tex);
  }
}

void glnvg__stencilMask (GLNVGcontext* gl, GLuint mask) {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.stencilMask != mask) {
      gl.stencilMask = mask;
      glStencilMask(mask);
    }
  } else {
    glStencilMask(mask);
  }
}

void glnvg__stencilFunc (GLNVGcontext* gl, GLenum func, GLint ref_, GLuint mask) {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.stencilFunc != func || gl.stencilFuncRef != ref_ || gl.stencilFuncMask != mask) {
      gl.stencilFunc = func;
      gl.stencilFuncRef = ref_;
      gl.stencilFuncMask = mask;
      glStencilFunc(func, ref_, mask);
    }
  } else {
    glStencilFunc(func, ref_, mask);
  }
}

GLNVGtexture* glnvg__allocTexture (GLNVGcontext* gl) {
  GLNVGtexture* tex = null;
  foreach (int i; 0..gl.ntextures) {
    if (gl.textures[i].id == 0) {
      tex = &gl.textures[i];
      break;
    }
  }
  if (tex is null) {
    if (gl.ntextures+1 > gl.ctextures) {
      GLNVGtexture* textures;
      int ctextures = glnvg__maxi(gl.ntextures+1, 4)+gl.ctextures/2; // 1.5x Overallocate
      textures = cast(GLNVGtexture*)realloc(gl.textures, GLNVGtexture.sizeof*ctextures);
      if (textures is null) return null;
      gl.textures = textures;
      gl.ctextures = ctextures;
    }
    tex = &gl.textures[gl.ntextures++];
  }

  memset(tex, 0, (*tex).sizeof);
  tex.id = ++gl.textureId;

  return tex;
}

GLNVGtexture* glnvg__findTexture (GLNVGcontext* gl, int id) {
  foreach (int i; 0..gl.ntextures) if (gl.textures[i].id == id) return &gl.textures[i];
  return null;
}

bool glnvg__deleteTexture (GLNVGcontext* gl, int id) {
  foreach (int i; 0..gl.ntextures) {
    if (gl.textures[i].id == id) {
      if (gl.textures[i].tex != 0 && (gl.textures[i].flags&NVG_IMAGE_NODELETE) == 0) glDeleteTextures(1, &gl.textures[i].tex);
      memset(&gl.textures[i], 0, (gl.textures[i]).sizeof);
      return true;
    }
  }
  return false;
}

void glnvg__dumpShaderError (GLuint shader, const(char)* name, const(char)* type) {
  import core.stdc.stdio : fprintf, stderr;
  GLchar[512+1] str;
  GLsizei len = 0;
  glGetShaderInfoLog(shader, 512, &len, str.ptr);
  if (len > 512) len = 512;
  str[len] = '\0';
  fprintf(stderr, "Shader %s/%s error:\n%s\n", name, type, str.ptr);
}

void glnvg__dumpProgramError (GLuint prog, const(char)* name) {
  import core.stdc.stdio : fprintf, stderr;
  GLchar[512+1] str;
  GLsizei len = 0;
  glGetProgramInfoLog(prog, 512, &len, str.ptr);
  if (len > 512) len = 512;
  str[len] = '\0';
  fprintf(stderr, "Program %s error:\n%s\n", name, str.ptr);
}

void glnvg__checkError (GLNVGcontext* gl, const(char)* str) {
  GLenum err;
  if ((gl.flags&NVG_DEBUG) == 0) return;
  err = glGetError();
  if (err != GL_NO_ERROR) {
    import core.stdc.stdio : fprintf, stderr;
    fprintf(stderr, "Error %08x after %s\n", err, str);
    return;
  }
}

bool glnvg__createShader (GLNVGshader* shader, const(char)* name, const(char)* header, const(char)* opts, const(char)* vshader, const(char)* fshader) {
  GLint status;
  GLuint prog, vert, frag;
  const(char)*[3] str;
  str[0] = header;
  str[1] = (opts !is null ? opts : "");

  memset(shader, 0, (*shader).sizeof);

  prog = glCreateProgram();
  vert = glCreateShader(GL_VERTEX_SHADER);
  frag = glCreateShader(GL_FRAGMENT_SHADER);
  str[2] = vshader;
  glShaderSource(vert, 3, cast(const(char*)*)str.ptr, null);
  str[2] = fshader;
  glShaderSource(frag, 3, cast(const(char*)*)str.ptr, null);

  glCompileShader(vert);
  glGetShaderiv(vert, GL_COMPILE_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpShaderError(vert, name, "vert");
    return false;
  }

  glCompileShader(frag);
  glGetShaderiv(frag, GL_COMPILE_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpShaderError(frag, name, "frag");
    return false;
  }

  glAttachShader(prog, vert);
  glAttachShader(prog, frag);

  glBindAttribLocation(prog, 0, "vertex");
  glBindAttribLocation(prog, 1, "tcoord");

  glLinkProgram(prog);
  glGetProgramiv(prog, GL_LINK_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpProgramError(prog, name);
    return false;
  }

  shader.prog = prog;
  shader.vert = vert;
  shader.frag = frag;

  return true;
}

void glnvg__deleteShader (GLNVGshader* shader) {
  if (shader.prog != 0) glDeleteProgram(shader.prog);
  if (shader.vert != 0) glDeleteShader(shader.vert);
  if (shader.frag != 0) glDeleteShader(shader.frag);
}

void glnvg__getUniforms (GLNVGshader* shader) {
  shader.loc[GLNVG_LOC_VIEWSIZE] = glGetUniformLocation(shader.prog, "viewSize");
  shader.loc[GLNVG_LOC_TEX] = glGetUniformLocation(shader.prog, "tex");
  shader.loc[GLNVG_LOC_FRAG] = glGetUniformLocation(shader.prog, "frag");
}

bool glnvg__renderCreate (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  enum align_ = 4;

  // TODO: mediump float may not be enough for GLES2 in iOS.
  // see the following discussion: https://github.com/memononen/nanovg/issues/46
  enum shaderHeader =
    "#define UNIFORMARRAY_SIZE 11\n"~
    "\n";

  enum fillVertShader =
    " uniform vec2 viewSize;\n"~
    " attribute vec2 vertex;\n"~
    " attribute vec2 tcoord;\n"~
    " varying vec2 ftcoord;\n"~
    " varying vec2 fpos;\n"~
    "void main(void) {\n"~
    " ftcoord = tcoord;\n"~
    " fpos = vertex;\n"~
    " gl_Position = vec4(2.0*vertex.x/viewSize.x-1.0, 1.0-2.0*vertex.y/viewSize.y, 0, 1);\n"~
    "}\n";

  enum fillFragShader =
    " uniform vec4 frag[UNIFORMARRAY_SIZE];\n"~
    " uniform sampler2D tex;\n"~
    " varying vec2 ftcoord;\n"~
    " varying vec2 fpos;\n"~
    " #define scissorMat mat3(frag[0].xyz, frag[1].xyz, frag[2].xyz)\n"~
    " #define paintMat mat3(frag[3].xyz, frag[4].xyz, frag[5].xyz)\n"~
    " #define innerCol frag[6]\n"~
    " #define outerCol frag[7]\n"~
    " #define scissorExt frag[8].xy\n"~
    " #define scissorScale frag[8].zw\n"~
    " #define extent frag[9].xy\n"~
    " #define radius frag[9].z\n"~
    " #define feather frag[9].w\n"~
    " #define strokeMult frag[10].x\n"~
    " #define strokeThr frag[10].y\n"~
    " #define texType int(frag[10].z)\n"~
    " #define type int(frag[10].w)\n"~
    "\n"~
    "float sdroundrect(vec2 pt, vec2 ext, float rad) {\n"~
    " vec2 ext2 = ext-vec2(rad,rad);\n"~
    " vec2 d = abs(pt)-ext2;\n"~
    " return min(max(d.x,d.y),0.0)+length(max(d,0.0))-rad;\n"~
    "}\n"~
    "\n"~
    "// Scissoring\n"~
    "float scissorMask(vec2 p) {\n"~
    " vec2 sc = (abs((scissorMat*vec3(p,1.0)).xy)-scissorExt);\n"~
    " sc = vec2(0.5,0.5)-sc*scissorScale;\n"~
    " return clamp(sc.x,0.0,1.0)*clamp(sc.y,0.0,1.0);\n"~
    "}\n"~
    "#ifdef EDGE_AA\n"~
    "// Stroke - from [0..1] to clipped pyramid, where the slope is 1px.\n"~
    "float strokeMask() {\n"~
    " return min(1.0, (1.0-abs(ftcoord.x*2.0-1.0))*strokeMult)*min(1.0, ftcoord.y);\n"~
    "}\n"~
    "#endif\n"~
    "\n"~
    "void main(void) {\n"~
    "   vec4 result;\n"~
    " float scissor = scissorMask(fpos);\n"~
    "#ifdef EDGE_AA\n"~
    " float strokeAlpha = strokeMask();\n"~
    "#else\n"~
    " float strokeAlpha = 1.0;\n"~
    "#endif\n"~
    " if (type == 0) {      // Gradient\n"~
    "   // Calculate gradient color using box gradient\n"~
    "   vec2 pt = (paintMat*vec3(fpos,1.0)).xy;\n"~
    "   float d = clamp((sdroundrect(pt, extent, radius)+feather*0.5)/feather, 0.0, 1.0);\n"~
    "   vec4 color = mix(innerCol,outerCol,d);\n"~
    "   // Combine alpha\n"~
    "   color *= strokeAlpha*scissor;\n"~
    "   result = color;\n"~
    " } else if (type == 1) {   // Image\n"~
    "   // Calculate color fron texture\n"~
    "   vec2 pt = (paintMat*vec3(fpos,1.0)).xy/extent;\n"~
    "   vec4 color = texture2D(tex, pt);\n"~
    "   if (texType == 1) color = vec4(color.xyz*color.w,color.w);\n"~
    "   if (texType == 2) color = vec4(color.x);\n"~
    "   // Apply color tint and alpha.\n"~
    "   color *= innerCol;\n"~
    "   // Combine alpha\n"~
    "   color *= strokeAlpha*scissor;\n"~
    "   result = color;\n"~
    " } else if (type == 2) {   // Stencil fill\n"~
    "   result = vec4(1,1,1,1);\n"~
    " } else if (type == 3) {   // Textured tris\n"~
    "   vec4 color = texture2D(tex, ftcoord);\n"~
    "   if (texType == 1) color = vec4(color.xyz*color.w,color.w);\n"~
    "   if (texType == 2) color = vec4(color.x);\n"~
    "   color *= scissor;\n"~
    "   result = color*innerCol;\n"~
    " }\n"~
    "#ifdef EDGE_AA\n"~
    " if (strokeAlpha < strokeThr) discard;\n"~
    "#endif\n"~
    " gl_FragColor = result;\n"~
    "}\n";

  glnvg__checkError(gl, "init");

  if (gl.flags&NVG_ANTIALIAS) {
    if (!glnvg__createShader(&gl.shader, "shader", shaderHeader, "#define EDGE_AA 1\n", fillVertShader, fillFragShader)) return false;
  } else {
    if (!glnvg__createShader(&gl.shader, "shader", shaderHeader, null, fillVertShader, fillFragShader)) return false;
  }

  glnvg__checkError(gl, "uniform locations");
  glnvg__getUniforms(&gl.shader);

  // Create dynamic vertex array
  glGenBuffers(1, &gl.vertBuf);

  gl.fragSize = (GLNVGfragUniforms).sizeof+align_-GLNVGfragUniforms.sizeof%align_;

  glnvg__checkError(gl, "create done");

  glFinish();

  return 1;
}

int glnvg__renderCreateTexture (void* uptr, NVGtexture type, int w, int h, int imageFlags, const(ubyte)* data) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__allocTexture(gl);

  if (tex is null) return 0;

  glGenTextures(1, &tex.tex);
  tex.width = w;
  tex.height = h;
  tex.type = type;
  tex.flags = imageFlags;
  glnvg__bindTexture(gl, tex.tex);

  glPixelStorei(GL_UNPACK_ALIGNMENT,1);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, tex.width);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  // GL 1.4 and later has support for generating mipmaps using a tex parameter.
  if (imageFlags&NVGimageFlags.GenerateMipmaps) glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);

  if (type == NVGtexture.RGBA) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
  } else {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, data);
  }

  if (imageFlags&NVGimageFlags.GenerateMipmaps) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  if (imageFlags&NVGimageFlags.RepeatX) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  }

  if (imageFlags&NVGimageFlags.RepeatY) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  }

  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  glnvg__checkError(gl, "create tex");
  glnvg__bindTexture(gl, 0);

  return tex.id;
}


bool glnvg__renderDeleteTexture (void* uptr, int image) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  return glnvg__deleteTexture(gl, image);
}

bool glnvg__renderUpdateTexture (void* uptr, int image, int x, int y, int w, int h, const(ubyte)* data) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);

  if (tex is null) return false;
  glnvg__bindTexture(gl, tex.tex);

  glPixelStorei(GL_UNPACK_ALIGNMENT,1);

  glPixelStorei(GL_UNPACK_ROW_LENGTH, tex.width);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, x);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, y);

  if (tex.type == NVGtexture.RGBA) {
    glTexSubImage2D(GL_TEXTURE_2D, 0, x,y, w,h, GL_RGBA, GL_UNSIGNED_BYTE, data);
  } else {
    glTexSubImage2D(GL_TEXTURE_2D, 0, x,y, w,h, GL_RED, GL_UNSIGNED_BYTE, data);
  }

  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  glnvg__bindTexture(gl, 0);

  return true;
}

bool glnvg__renderGetTextureSize (void* uptr, int image, int* w, int* h) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);
  if (tex is null) return false;
  *w = tex.width;
  *h = tex.height;
  return true;
}

void glnvg__xformToMat3x4 (float* m3, const(float)* t) {
  m3[0] = t[0];
  m3[1] = t[1];
  m3[2] = 0.0f;
  m3[3] = 0.0f;
  m3[4] = t[2];
  m3[5] = t[3];
  m3[6] = 0.0f;
  m3[7] = 0.0f;
  m3[8] = t[4];
  m3[9] = t[5];
  m3[10] = 1.0f;
  m3[11] = 0.0f;
}

NVGcolor glnvg__premulColor (NVGcolor c) {
  c.r *= c.a;
  c.g *= c.a;
  c.b *= c.a;
  return c;
}

bool glnvg__convertPaint (GLNVGcontext* gl, GLNVGfragUniforms* frag, NVGpaint* paint, NVGscissor* scissor, float width, float fringe, float strokeThr) {
  import core.stdc.math : sqrtf;
  GLNVGtexture* tex = null;
  float[6] invxform;

  memset(frag, 0, (*frag).sizeof);

  frag.innerCol = glnvg__premulColor(paint.innerColor);
  frag.outerCol = glnvg__premulColor(paint.outerColor);

  if (scissor.extent[0] < -0.5f || scissor.extent[1] < -0.5f) {
    memset(frag.scissorMat.ptr, 0, frag.scissorMat.sizeof);
    frag.scissorExt[0] = 1.0f;
    frag.scissorExt[1] = 1.0f;
    frag.scissorScale[0] = 1.0f;
    frag.scissorScale[1] = 1.0f;
  } else {
    nvgTransformInverse(invxform.ptr, scissor.xform.ptr);
    glnvg__xformToMat3x4(frag.scissorMat.ptr, invxform.ptr);
    frag.scissorExt[0] = scissor.extent[0];
    frag.scissorExt[1] = scissor.extent[1];
    frag.scissorScale[0] = sqrtf(scissor.xform[0]*scissor.xform[0]+scissor.xform[2]*scissor.xform[2])/fringe;
    frag.scissorScale[1] = sqrtf(scissor.xform[1]*scissor.xform[1]+scissor.xform[3]*scissor.xform[3])/fringe;
  }

  memcpy(frag.extent.ptr, paint.extent.ptr, frag.extent.sizeof);
  frag.strokeMult = (width*0.5f+fringe*0.5f)/fringe;
  frag.strokeThr = strokeThr;

  if (paint.image != 0) {
    tex = glnvg__findTexture(gl, paint.image);
    if (tex is null) return false;
    if ((tex.flags&NVGimageFlags.FlipY) != 0) {
      float[6] flipped;
      nvgTransformScale(flipped.ptr, 1.0f, -1.0f);
      nvgTransformMultiply(flipped.ptr, paint.xform.ptr);
      nvgTransformInverse(invxform.ptr, flipped.ptr);
    } else {
      nvgTransformInverse(invxform.ptr, paint.xform.ptr);
    }
    frag.type = NSVG_SHADER_FILLIMG;

    if (tex.type == NVGtexture.RGBA) {
      frag.texType = (tex.flags&NVGimageFlags.Premultiplied ? 0 : 1);
    } else {
      frag.texType = 2;
    }
    //printf("frag.texType = %d\n", frag.texType);
  } else {
    frag.type = NSVG_SHADER_FILLGRAD;
    frag.radius = paint.radius;
    frag.feather = paint.feather;
    nvgTransformInverse(invxform.ptr, paint.xform.ptr);
  }

  glnvg__xformToMat3x4(frag.paintMat.ptr, invxform.ptr);

  return true;
}

void glnvg__setUniforms (GLNVGcontext* gl, int uniformOffset, int image) {
  GLNVGfragUniforms* frag = nvg__fragUniformPtr(gl, uniformOffset);
  glUniform4fv(gl.shader.loc[GLNVG_LOC_FRAG], NANOVG_GL_UNIFORMARRAY_SIZE, &(frag.uniformArray[0][0]));
  if (image != 0) {
    GLNVGtexture* tex = glnvg__findTexture(gl, image);
    glnvg__bindTexture(gl, tex !is null ? tex.tex : 0);
    glnvg__checkError(gl, "tex paint tex");
  } else {
    glnvg__bindTexture(gl, 0);
  }
}

void glnvg__renderViewport (void* uptr, int width, int height) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  gl.view[0] = cast(float)width;
  gl.view[1] = cast(float)height;
}

void glnvg__fill (GLNVGcontext* gl, GLNVGcall* call) {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  // Draw shapes
  glEnable(GL_STENCIL_TEST);
  glnvg__stencilMask(gl, 0xff);
  glnvg__stencilFunc(gl, GL_ALWAYS, 0, 0xff);
  glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);

  // set bindpoint for solid loc
  glnvg__setUniforms(gl, call.uniformOffset, 0);
  glnvg__checkError(gl, "fill simple");

  glStencilOpSeparate(GL_FRONT, GL_KEEP, GL_KEEP, GL_INCR_WRAP);
  glStencilOpSeparate(GL_BACK, GL_KEEP, GL_KEEP, GL_DECR_WRAP);
  glDisable(GL_CULL_FACE);
  foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
  glEnable(GL_CULL_FACE);

  // Draw anti-aliased pixels
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

  glnvg__setUniforms(gl, call.uniformOffset+gl.fragSize, call.image);
  glnvg__checkError(gl, "fill fill");

  if (gl.flags&NVG_ANTIALIAS) {
    glnvg__stencilFunc(gl, GL_EQUAL, 0x00, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    // Draw fringes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }

  // Draw fill
  glnvg__stencilFunc(gl, GL_NOTEQUAL, 0x0, 0xff);
  glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  glDrawArrays(GL_TRIANGLES, call.triangleOffset, call.triangleCount);

  glDisable(GL_STENCIL_TEST);
}

void glnvg__convexFill (GLNVGcontext* gl, GLNVGcall* call) {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  glnvg__setUniforms(gl, call.uniformOffset, call.image);
  glnvg__checkError(gl, "convex fill");

  foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
  if (gl.flags&NVG_ANTIALIAS) {
    // Draw fringes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }
}

void glnvg__stroke (GLNVGcontext* gl, GLNVGcall* call) {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  if (gl.flags&NVG_STENCIL_STROKES) {
    glEnable(GL_STENCIL_TEST);
    glnvg__stencilMask(gl, 0xff);

    // Fill the stroke base without overlap
    glnvg__stencilFunc(gl, GL_EQUAL, 0x0, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_INCR);
    glnvg__setUniforms(gl, call.uniformOffset+gl.fragSize, call.image);
    glnvg__checkError(gl, "stroke fill 0");
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);

    // Draw anti-aliased pixels.
    glnvg__setUniforms(gl, call.uniformOffset, call.image);
    glnvg__stencilFunc(gl, GL_EQUAL, 0x00, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);

    // Clear stencil buffer.
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    glnvg__stencilFunc(gl, GL_ALWAYS, 0x0, 0xff);
    glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
    glnvg__checkError(gl, "stroke fill 1");
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

    glDisable(GL_STENCIL_TEST);

    //glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset+gl.fragSize), paint, scissor, strokeWidth, fringe, 1.0f-0.5f/255.0f);
  } else {
    glnvg__setUniforms(gl, call.uniformOffset, call.image);
    glnvg__checkError(gl, "stroke fill");
    // Draw Strokes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }
}

void glnvg__triangles (GLNVGcontext* gl, GLNVGcall* call) {
  glnvg__setUniforms(gl, call.uniformOffset, call.image);
  glnvg__checkError(gl, "triangles fill");
  glDrawArrays(GL_TRIANGLES, call.triangleOffset, call.triangleCount);
}

void glnvg__renderCancel (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  gl.nverts = 0;
  gl.npaths = 0;
  gl.ncalls = 0;
  gl.nuniforms = 0;
}

void glnvg__renderFlush (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  if (gl.ncalls > 0) {
    // Setup require GL state.
    glUseProgram(gl.shader.prog);

    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_SCISSOR_TEST);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glStencilMask(0xffffffff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    glStencilFunc(GL_ALWAYS, 0, 0xffffffff);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0);
    static if (NANOVG_GL_USE_STATE_FILTER) {
      gl.boundTexture = 0;
      gl.stencilMask = 0xffffffff;
      gl.stencilFunc = GL_ALWAYS;
      gl.stencilFuncRef = 0;
      gl.stencilFuncMask = 0xffffffff;
    }

    // Upload vertex data
    glBindBuffer(GL_ARRAY_BUFFER, gl.vertBuf);
    glBufferData(GL_ARRAY_BUFFER, gl.nverts*NVGvertex.sizeof, gl.verts, GL_STREAM_DRAW);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, NVGvertex.sizeof, cast(const(GLvoid)*)cast(size_t)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, NVGvertex.sizeof, cast(const(GLvoid)*)(0+2*(float).sizeof));

    // Set view and texture just once per frame.
    glUniform1i(gl.shader.loc[GLNVG_LOC_TEX], 0);
    glUniform2fv(gl.shader.loc[GLNVG_LOC_VIEWSIZE], 1, gl.view.ptr);

    foreach (int i; 0..gl.ncalls) {
      GLNVGcall* call = &gl.calls[i];
           if (call.type == GLNVG_FILL) glnvg__fill(gl, call);
      else if (call.type == GLNVG_CONVEXFILL) glnvg__convexFill(gl, call);
      else if (call.type == GLNVG_STROKE) glnvg__stroke(gl, call);
      else if (call.type == GLNVG_TRIANGLES) glnvg__triangles(gl, call);
    }

    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
    glDisable(GL_CULL_FACE);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glUseProgram(0);
    glnvg__bindTexture(gl, 0);
  }

  // Reset calls
  gl.nverts = 0;
  gl.npaths = 0;
  gl.ncalls = 0;
  gl.nuniforms = 0;
}

int glnvg__maxVertCount (const(NVGpath)* paths, int npaths) {
  int count = 0;
  foreach (int i; 0..npaths) {
    count += paths[i].nfill;
    count += paths[i].nstroke;
  }
  return count;
}

GLNVGcall* glnvg__allocCall (GLNVGcontext* gl) {
  GLNVGcall* ret = null;
  if (gl.ncalls+1 > gl.ccalls) {
    GLNVGcall* calls;
    int ccalls = glnvg__maxi(gl.ncalls+1, 128)+gl.ccalls/2; // 1.5x Overallocate
    calls = cast(GLNVGcall*)realloc(gl.calls, (GLNVGcall).sizeof*ccalls);
    if (calls is null) return null;
    gl.calls = calls;
    gl.ccalls = ccalls;
  }
  ret = &gl.calls[gl.ncalls++];
  memset(ret, 0, (GLNVGcall).sizeof);
  return ret;
}

int glnvg__allocPaths (GLNVGcontext* gl, int n) {
  int ret = 0;
  if (gl.npaths+n > gl.cpaths) {
    GLNVGpath* paths;
    int cpaths = glnvg__maxi(gl.npaths+n, 128)+gl.cpaths/2; // 1.5x Overallocate
    paths = cast(GLNVGpath*)realloc(gl.paths, (GLNVGpath).sizeof*cpaths);
    if (paths is null) return -1;
    gl.paths = paths;
    gl.cpaths = cpaths;
  }
  ret = gl.npaths;
  gl.npaths += n;
  return ret;
}

int glnvg__allocVerts (GLNVGcontext* gl, int n) {
  int ret = 0;
  if (gl.nverts+n > gl.cverts) {
    NVGvertex* verts;
    int cverts = glnvg__maxi(gl.nverts+n, 4096)+gl.cverts/2; // 1.5x Overallocate
    verts = cast(NVGvertex*)realloc(gl.verts, (NVGvertex).sizeof*cverts);
    if (verts is null) return -1;
    gl.verts = verts;
    gl.cverts = cverts;
  }
  ret = gl.nverts;
  gl.nverts += n;
  return ret;
}

int glnvg__allocFragUniforms (GLNVGcontext* gl, int n) {
  int ret = 0, structSize = gl.fragSize;
  if (gl.nuniforms+n > gl.cuniforms) {
    ubyte* uniforms;
    int cuniforms = glnvg__maxi(gl.nuniforms+n, 128)+gl.cuniforms/2; // 1.5x Overallocate
    uniforms = cast(ubyte*)realloc(gl.uniforms, structSize*cuniforms);
    if (uniforms is null) return -1;
    gl.uniforms = uniforms;
    gl.cuniforms = cuniforms;
  }
  ret = gl.nuniforms*structSize;
  gl.nuniforms += n;
  return ret;
}

GLNVGfragUniforms* nvg__fragUniformPtr (GLNVGcontext* gl, int i) {
  return cast(GLNVGfragUniforms*)&gl.uniforms[i];
}

void glnvg__vset (NVGvertex* vtx, float x, float y, float u, float v) {
  vtx.x = x;
  vtx.y = y;
  vtx.u = u;
  vtx.v = v;
}

void glnvg__renderFill (void* uptr, NVGpaint* paint, NVGscissor* scissor, float fringe, const(float)* bounds, const(NVGpath)* paths, int npaths) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  NVGvertex* quad;
  GLNVGfragUniforms* frag;
  int maxverts, offset;

  if (call is null) return;

  call.type = GLNVG_FILL;
  call.pathOffset = glnvg__allocPaths(gl, npaths);
  if (call.pathOffset == -1) goto error;
  call.pathCount = npaths;
  call.image = paint.image;

  if (npaths == 1 && paths[0].convex) call.type = GLNVG_CONVEXFILL;

  // Allocate vertices for all the paths.
  maxverts = glnvg__maxVertCount(paths, npaths)+6;
  offset = glnvg__allocVerts(gl, maxverts);
  if (offset == -1) goto error;

  foreach (int i; 0..npaths) {
    GLNVGpath* copy = &gl.paths[call.pathOffset+i];
    const(NVGpath)* path = &paths[i];
    memset(copy, 0, GLNVGpath.sizeof);
    if (path.nfill > 0) {
      copy.fillOffset = offset;
      copy.fillCount = path.nfill;
      memcpy(&gl.verts[offset], path.fill, (NVGvertex).sizeof*path.nfill);
      offset += path.nfill;
    }
    if (path.nstroke > 0) {
      copy.strokeOffset = offset;
      copy.strokeCount = path.nstroke;
      memcpy(&gl.verts[offset], path.stroke, (NVGvertex).sizeof*path.nstroke);
      offset += path.nstroke;
    }
  }

  // Quad
  call.triangleOffset = offset;
  call.triangleCount = 6;
  quad = &gl.verts[call.triangleOffset];
  glnvg__vset(&quad[0], bounds[0], bounds[3], 0.5f, 1.0f);
  glnvg__vset(&quad[1], bounds[2], bounds[3], 0.5f, 1.0f);
  glnvg__vset(&quad[2], bounds[2], bounds[1], 0.5f, 1.0f);

  glnvg__vset(&quad[3], bounds[0], bounds[3], 0.5f, 1.0f);
  glnvg__vset(&quad[4], bounds[2], bounds[1], 0.5f, 1.0f);
  glnvg__vset(&quad[5], bounds[0], bounds[1], 0.5f, 1.0f);

  // Setup uniforms for draw calls
  if (call.type == GLNVG_FILL) {
    call.uniformOffset = glnvg__allocFragUniforms(gl, 2);
    if (call.uniformOffset == -1) goto error;
    // Simple shader for stencil
    frag = nvg__fragUniformPtr(gl, call.uniformOffset);
    memset(frag, 0, (*frag).sizeof);
    frag.strokeThr = -1.0f;
    frag.type = NSVG_SHADER_SIMPLE;
    // Fill shader
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset+gl.fragSize), paint, scissor, fringe, fringe, -1.0f);
  } else {
    call.uniformOffset = glnvg__allocFragUniforms(gl, 1);
    if (call.uniformOffset == -1) goto error;
    // Fill shader
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset), paint, scissor, fringe, fringe, -1.0f);
  }

  return;

error:
  // We get here if call alloc was ok, but something else is not.
  // Roll back the last call to prevent drawing it.
  if (gl.ncalls > 0) --gl.ncalls;
}

void glnvg__renderStroke (void* uptr, NVGpaint* paint, NVGscissor* scissor, float fringe, float strokeWidth, const(NVGpath)* paths, int npaths) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  int maxverts, offset;

  if (call is null) return;

  call.type = GLNVG_STROKE;
  call.pathOffset = glnvg__allocPaths(gl, npaths);
  if (call.pathOffset == -1) goto error;
  call.pathCount = npaths;
  call.image = paint.image;

  // Allocate vertices for all the paths.
  maxverts = glnvg__maxVertCount(paths, npaths);
  offset = glnvg__allocVerts(gl, maxverts);
  if (offset == -1) goto error;

  foreach (int i; 0..npaths) {
    GLNVGpath* copy = &gl.paths[call.pathOffset+i];
    const(NVGpath)* path = &paths[i];
    memset(copy, 0, GLNVGpath.sizeof);
    if (path.nstroke) {
      copy.strokeOffset = offset;
      copy.strokeCount = path.nstroke;
      memcpy(&gl.verts[offset], path.stroke, (NVGvertex).sizeof*path.nstroke);
      offset += path.nstroke;
    }
  }

  if (gl.flags&NVG_STENCIL_STROKES) {
    // Fill shader
    call.uniformOffset = glnvg__allocFragUniforms(gl, 2);
    if (call.uniformOffset == -1) goto error;
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset+gl.fragSize), paint, scissor, strokeWidth, fringe, 1.0f-0.5f/255.0f);
  } else {
    // Fill shader
    call.uniformOffset = glnvg__allocFragUniforms(gl, 1);
    if (call.uniformOffset == -1) goto error;
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
  }

  return;

error:
  // We get here if call alloc was ok, but something else is not.
  // Roll back the last call to prevent drawing it.
  if (gl.ncalls > 0) --gl.ncalls;
}

void glnvg__renderTriangles (void* uptr, NVGpaint* paint, NVGscissor* scissor, const(NVGvertex)* verts, int nverts) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  GLNVGfragUniforms* frag;

  if (call is null) return;

  call.type = GLNVG_TRIANGLES;
  call.image = paint.image;

  // Allocate vertices for all the paths.
  call.triangleOffset = glnvg__allocVerts(gl, nverts);
  if (call.triangleOffset == -1) goto error;
  call.triangleCount = nverts;

  memcpy(&gl.verts[call.triangleOffset], verts, NVGvertex.sizeof*nverts);

  // Fill shader
  call.uniformOffset = glnvg__allocFragUniforms(gl, 1);
  if (call.uniformOffset == -1) goto error;
  frag = nvg__fragUniformPtr(gl, call.uniformOffset);
  glnvg__convertPaint(gl, frag, paint, scissor, 1.0f, 1.0f, -1.0f);
  frag.type = NSVG_SHADER_IMG;

  return;

error:
  // We get here if call alloc was ok, but something else is not.
  // Roll back the last call to prevent drawing it.
  if (gl.ncalls > 0) --gl.ncalls;
}

void glnvg__renderDelete (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  if (gl is null) return;

  glnvg__deleteShader(&gl.shader);

  if (gl.vertBuf != 0) glDeleteBuffers(1, &gl.vertBuf);

  foreach (int i; 0..gl.ntextures) {
    if (gl.textures[i].tex != 0 && (gl.textures[i].flags&NVG_IMAGE_NODELETE) == 0) glDeleteTextures(1, &gl.textures[i].tex);
  }
  free(gl.textures);

  free(gl.paths);
  free(gl.verts);
  free(gl.uniforms);
  free(gl.calls);

  free(gl);
}


public NVGcontext* nvgCreateGL2 (int flags) {
  NVGparams params;
  NVGcontext* ctx = null;
  GLNVGcontext* gl = cast(GLNVGcontext*)malloc(GLNVGcontext.sizeof);
  if (gl is null) goto error;
  memset(gl, 0, GLNVGcontext.sizeof);

  memset(&params, 0, params.sizeof);
  params.renderCreate = &glnvg__renderCreate;
  params.renderCreateTexture = &glnvg__renderCreateTexture;
  params.renderDeleteTexture = &glnvg__renderDeleteTexture;
  params.renderUpdateTexture = &glnvg__renderUpdateTexture;
  params.renderGetTextureSize = &glnvg__renderGetTextureSize;
  params.renderViewport = &glnvg__renderViewport;
  params.renderCancel = &glnvg__renderCancel;
  params.renderFlush = &glnvg__renderFlush;
  params.renderFill = &glnvg__renderFill;
  params.renderStroke = &glnvg__renderStroke;
  params.renderTriangles = &glnvg__renderTriangles;
  params.renderDelete = &glnvg__renderDelete;
  params.userPtr = gl;
  params.edgeAntiAlias = (flags&NVG_ANTIALIAS ? 1 : 0);

  gl.flags = flags;

  ctx = nvgCreateInternal(&params);
  if (ctx is null) goto error;

  return ctx;

error:
  // 'gl' is freed by nvgDeleteInternal.
  if (ctx !is null) nvgDeleteInternal(ctx);
  return null;
}

public void nvgDeleteGL2 (NVGcontext* ctx) {
  if (ctx !is null) nvgDeleteInternal(ctx);
}

public int nvglCreateImageFromHandleGL2 (NVGcontext* ctx, GLuint textureId, int w, int h, int imageFlags) {
  GLNVGcontext* gl = cast(GLNVGcontext*)nvgInternalParams(ctx).userPtr;
  GLNVGtexture* tex = glnvg__allocTexture(gl);

  if (tex is null) return 0;

  tex.type = NVGtexture.RGBA;
  tex.tex = textureId;
  tex.flags = imageFlags;
  tex.width = w;
  tex.height = h;

  return tex.id;
}

public GLuint nvglImageHandleGL2 (NVGcontext* ctx, int image) {
  GLNVGcontext* gl = cast(GLNVGcontext*)nvgInternalParams(ctx).userPtr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);
  return tex.tex;
}
