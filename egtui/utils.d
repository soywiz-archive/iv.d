/* Invisible Vector Library
 * simple FlexBox-based TUI engine
 *
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
module iv.egtui.utils;

import iv.strex;
import iv.rawtty2;

import iv.egtui.types;


// ////////////////////////////////////////////////////////////////////////// //
// calculate text bounds (can call delegate to output string too ;-)
// use "|...|" to "quote" word
void calcTextBounds (out int cols, out int lines, const(char)[] text, int maxwdt,
  scope void delegate (int x, int y, const(char)[] s) dg=null)
{
  int col = 0;

  void putWord (const(char)[] text) {
    while (text.length > 0) {
      while (col == 0 && text.length > maxwdt) {
        if (dg !is null) dg(0, lines, text[0..maxwdt]);
        ++lines;
        text = text[maxwdt..$];
      }
      if (text.length == 0) break;
      if (col == 0) {
        if (dg !is null) dg(0, lines, text);
        col += cast(int)text.length;
        if (cols < col) cols = col;
        break;
      }
      int nw = col+cast(int)text.length+1;
      if (nw <= maxwdt) {
        ++col;
        if (dg !is null) dg(col, lines, text);
        col += cast(int)text.length;
        if (cols < col) cols = col;
        break;
      }
      ++lines;
      col = 0;
    }
  }

  while (text.length) {
    int pos = 0;
    while (pos < text.length && text.ptr[pos] != '\n' && text.ptr[pos] <= ' ') ++pos;
    if (pos > 0) { text = text[pos..$]; continue; }
    assert(pos == 0);
    if (text.ptr[pos] == '\n') {
      col = 0;
      ++lines;
      text = text[1..$];
      continue;
    }
    if (text.ptr[pos] == '|') {
      ++pos;
      while (pos < text.length && text.ptr[pos] != '|') ++pos;
      putWord(text[1..pos]);
      if (pos >= text.length) break;
      text = text[pos+1..$];
    } else {
      while (pos < text.length && text.ptr[pos] > ' ') ++pos;
      putWord(text[0..pos]);
      text = text[pos..$];
    }
  }
  if (col > 0) ++lines;
}


// ////////////////////////////////////////////////////////////////////////// //
// calculate text bounds, insert soft wraps, remove excessive spaces
// use "|...|" to "quote" word
// return new text length
uint calcTextBoundsEx (out int cols, out int lines, char[] text, int maxwdt) {
  enum EOT = 0;
  enum SoftWrap = 6;

  if (maxwdt < 1) maxwdt = 1;

  int col = 0;
  usize dpos = 0;
  char[] dtext = text;

  void putText (const(char)[] s...) {
    foreach (char ch; s) {
      if (dpos < dtext.length) dtext.ptr[dpos++] = ch;
    }
  }

  // replace soft wraps with blanks
  foreach (char ch; text) {
    if (ch == EOT) break;
    if (ch == SoftWrap) ch = ' ';
    if (ch < 1 || ch > 3) {
      if (ch != '\n' && (ch < ' ' || ch == 127)) ch = ' ';
    }
    dtext[dpos++] = ch;
  }
  // again
  text = text[0..dpos];
  dpos = 0;

  void putWord (const(char)[] text) {
    while (text.length > 0) {
      while (col == 0 && text.length > maxwdt) {
        putText(text[0..maxwdt]);
        ++lines;
        text = text[maxwdt..$];
      }
      if (text.length == 0) break;
      if (col == 0) {
        putText(text);
        col += cast(int)text.length;
        if (cols < col) cols = col;
        break;
      }
      int nw = col+cast(int)text.length+1;
      if (nw <= maxwdt) {
        putText(' ');
        putText(text);
        col += cast(int)text.length+1;
        if (cols < col) cols = col;
        break;
      }
      // newline
      if (lines != 0 || col) putText(SoftWrap);
      ++lines;
      col = 0;
    }
  }

  // align chars
  if (text.length && text.ptr[0] > 0 && text.ptr[0] <= 3) {
    putText(text.ptr[0]);
    text = text[1..$];
  }
  while (text.length) {
    int pos = 0;
    while (pos < text.length && text.ptr[pos] != '\n' && text.ptr[pos] <= ' ') ++pos;
    if (pos > 0) { text = text[pos..$]; continue; }
    assert(pos == 0);
    if (text.ptr[pos] == '\n') {
      if (lines || col) putText('\n');
      col = 0;
      ++lines;
      text = text[1..$];
      // align chars
      if (text.length && text.ptr[0] > 0 && text.ptr[0] <= 3) {
        putText(text.ptr[0]);
        text = text[1..$];
      }
      continue;
    }
    if (text.ptr[pos] == '|') {
      ++pos;
      while (pos < text.length && text.ptr[pos] != '|') ++pos;
      putWord(text[1..pos]);
      if (pos >= text.length) break;
      text = text[pos+1..$];
    } else {
      while (pos < text.length && text.ptr[pos] > ' ') ++pos;
      putWord(text[0..pos]);
      text = text[pos..$];
    }
  }
  if (col > 0) ++lines;

  return dpos;
}
