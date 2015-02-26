/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module iv.autocomplete is aliced;


/**
 * Build list of suitable autocompletions.
 *
 * Params:
 *  cmd = user-given command prefix
 *  cmdlist = list of all available commands
 *
 * Returns:
 *  null = no matches (empty array)
 *  array with one item: exactly one match
 *  array with more that one item = [0] is max prefix, then list of autocompletes
 *
 * Throws:
 *  Out of memory exception
 */
string[] autocomplete (string cmd, const(string)[] cmdlist) @trusted nothrow {
  if (cmdlist.length == 0) return [cmd];
  string found; // autoinit
  usize foundlen, pfxcount; // autoinit
  // первый проход: считаем префиксы, запоминаем команду с самым длинным префиксом
  foreach (immutable s; cmdlist) {
    if (cmd.length <= s.length) {
      usize pos = cmd.length;
      foreach (immutable idx; 0..cmd.length) if (cmd[idx] != s[idx]) { pos = idx; break; }
      if (pos == cmd.length) {
        if (s.length > found.length) found = s;
        ++pfxcount;
      }
    }
  }
  if (pfxcount == 0) return null; // не нашли вообще нихера, валим отсюда, пацаны!
  if (pfxcount == 1) return [found]; // есть только один, уносите
  // нашли дохера, это прискорбно
  // ищем самый длинный префикс из возможных, заодно собираем всё, что можно
  string[] res = new string[pfxcount+1]; // сюда сложим всё подходящее; мы точно знаем, сколько их будет
  usize respos = 1; // res[0] -- самый длинный префикс, начнём с [1]
  usize slen = cmd.length; // точно не больше found.length
  foreach (immutable s; cmdlist) {
    if (s.length >= slen) {
      usize pos = slen;
      foreach (immutable idx; 0..slen) if (found[idx] != s[idx]) { pos = idx; break; }
      if (pos == slen) {
        // наше, запоминаем и правим префикс
        res[respos++] = s;
        // обрезаем по минимуму, но не меньше, чем надо
        for (; pos < found.length && pos < s.length; ++pos) if (found[pos] != s[pos]) break;
        if (pos < found.length) {
          found = found[0..pos];
          if (slen > pos) slen = pos;
        }
      }
    }
  }
  // первым элементом вставим максимальный префикс
  res[0] = found;
  // всё
  return res;
}


unittest {
  import std.stdio;
  {
    static immutable string[3] clist0 = ["aaz", "aabed", "aand"];
    //writeln("--------");
    assert(autocomplete("", clist0) == ["aa", "aaz", "aabed", "aand"]);
    assert(autocomplete("a", clist0) == ["aa", "aaz", "aabed", "aand"]);
    assert(autocomplete("aa", clist0) == ["aa", "aaz", "aabed", "aand"]);
    assert(autocomplete("aab", clist0) == ["aabed"]);
  }
  {
    static immutable string[3] clist1 = ["az", "abed", "and"];
    //writeln("--------");
    assert(autocomplete("", clist1) == ["a", "az", "abed", "and"]);
    assert(autocomplete("a", clist1) == ["a", "az", "abed", "and"]);
    assert(autocomplete("aa", clist1) == []);
    assert(autocomplete("aab", clist1) == []);
  }
}
