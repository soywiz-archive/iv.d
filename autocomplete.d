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
string[] autocomplete (string cmd, string[] cmdlist...) @trusted nothrow {
  if (cmdlist.length == 0) return [cmd];
  string found; // autoinit
  usize foundlen, pfxcount; // autoinit
  // ������ ������: ������� ��������, ���������� ������� � ����� ������� ���������
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
  if (pfxcount == 0) return null; // �� ����� ������ ������, ����� ������, ������!
  if (pfxcount == 1) return [found]; // ���� ������ ����, �������
  // ����� ������, ��� ����������
  // ���� ����� ������� ������� �� ���������, ������ �������� �ӣ, ��� �����
  string[] res = new string[pfxcount+1]; // ���� ������ �ӣ ����������; �� ����� �����, ������� �� �����
  usize respos = 1; // res[0] -- ����� ������� �������, ���Σ� � [1]
  usize slen = cmd.length; // ����� �� ������ found.length
  foreach (immutable s; cmdlist) {
    if (s.length >= slen) {
      usize pos = slen;
      foreach (immutable idx; 0..slen) if (found[idx] != s[idx]) { pos = idx; break; }
      if (pos == slen) {
        // ����, ���������� � ������ �������
        res[respos++] = s;
        // �������� �� ��������, �� �� ������, ��� ����
        for (; pos < found.length && pos < s.length; ++pos) if (found[pos] != s[pos]) break;
        if (pos < found.length) {
          found = found[0..pos];
          if (slen > pos) slen = pos;
        }
      }
    }
  }
  // ������ ��������� ������� ������������ �������
  res[0] = found;
  // �ӣ
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
