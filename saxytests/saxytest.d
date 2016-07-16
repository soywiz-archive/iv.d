/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
