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
module saxytest;

import iv.saxy;

static if (is(typeof({import iv.vfs;}))) {
  import iv.vfs;
  enum HasVFS = true;
} else {
  enum HasVFS = false;
}

static if (is(typeof({import iv.strex;}))) {
  import iv.strex;
} else {
  private string quote (const(char)[] s) {
    import std.array : appender;
    import std.format : formatElement, FormatSpec;
    auto res = appender!string();
    FormatSpec!char fspc; // defaults to 's'
    formatElement(res, s, fspc);
    return res.data;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
char[] readFile (const(char)[] fname) {
  static if (HasVFS) {
    auto fl = VFile(fname);
    auto res = new char[](cast(int)fl.size);
    fl.rawReadExact(res[]);
    return res;
  } else {
    import std.conv : to;
    import std.stdio : File;
    auto fl = File(fname.to!string);
    auto res = new char[](cast(int)fl.size);
    fl.rawRead(res[]);
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  import std.stdio;
  import std.utf;
  char[] indent;
  version(all) {
    static if (HasVFS) {
      auto inst = VFile("z00.xml");
    } else {
      auto inst = File("z00.xml");
    }
  } else {
    auto inst = readFile("z00.xml").byChar;
  }
  xmparse(inst,
    (XmlString name, XmlString[string] attrs) {
      import std.stdio;
      write(indent);
      write("tag '", name, "' opened");
      if (attrs.length) {
        write(' ');
        foreach (const ref kv; attrs.byKeyValue) {
          write(' ', kv.key, "=", kv.value.quote);
        }
      }
      writeln;
      indent ~= ' ';
    },
    (XmlString name) {
      import std.stdio;
      indent.length -= 1;
      indent.assumeSafeAppend;
      writeln(indent, "tag '", name, "' closed");
    },
    (XmlString text) {
      import std.stdio;
      writeln(indent, text.length, " bytes of content");
    },
  );
}
