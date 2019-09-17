/* Invisible Vector Library
 * simple FlexBox-based TUI engine
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.egtui.editor.highlighters /*is aliced*/;
private:

import iv.alice;
import iv.rawtty;
import iv.strex;
import iv.egtui.tty;
import iv.egeditor.editor;
public import iv.egeditor.highlighters;


// ////////////////////////////////////////////////////////////////////////// //
public enum TextBG = TtyRgb2Color!(0x3a, 0x3a, 0x3a); // 237
//public enum TextBG = TtyRGB!"333"; // 237

public enum TextColorNoHi = XtColorFB!(TtyRgb2Color!(0xff, 0xa0, 0x00), TextBG);
public enum TextColor = XtColorFB!(TtyRgb2Color!(0xd0, 0xd0, 0xd0), TextBG); // 252,237
public enum TextKillColor = XtColorFB!(TtyRgb2Color!(0xe0, 0xe0, 0xe0), TextBG); // 252,237
public enum BadColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x54), TtyRgb2Color!(0xb2, 0x18, 0x18)); // 11,1
//public enum TrailSpaceColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x00), TtyRgb2Color!(0x00, 0x00, 0x87)); // 226,18
public enum TrailSpaceColor = XtColorFB!(TtyRgb2Color!(0x6c, 0x6c, 0x6c), TtyRgb2Color!(0x26, 0x26, 0x26)); // 242,235
public enum VisualTabColor = XtColorFB!(TtyRgb2Color!(0x80, 0x00, 0x00), TextBG); // 242,235
public enum BlockColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TtyRgb2Color!(0x00, 0x5f, 0xff)); // 15,27
public enum BookmarkColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TtyRgb2Color!(0x87, 0x00, 0xd7)); // 15,92
public enum BracketColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x54), TtyRgb2Color!(0x00, 0x00, 0x00)); // 11,0
public enum IncSearchColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x00), TtyRgb2Color!(0xd7, 0x00, 0x00)); // 226,160

public enum UtfuckedColor = XtColorFB!(TtyRgb2Color!(0x6c, 0x6c, 0x6c), TtyRgb2Color!(0x26, 0x26, 0x26)); // 242,235

public enum VLineColor = XtColorFB!(TtyRgb2Color!(0x60, 0x60, 0x60), TextBG); // 252,237

//public enum TabColor = XtColorFB!(TtyRgb2Color!(0x00, 0x00, 0x80), TextBG);


// ////////////////////////////////////////////////////////////////////////// //
public uint hiColor() (in auto ref GapBuffer.HighState hs) nothrow @safe @nogc {
  switch (hs.kwtype) {
    case HiNone: return XtColorFB!(TtyRgb2Color!(0xb2, 0xb2, 0xb2), TtyRgb2Color!(0x00, 0x00, 0x00)); // 7,0
    case HiText: return TextColor;

    case HiCommentOneLine:
    case HiCommentMulti:
      return XtColorFB!(TtyRgb2Color!(0xb2, 0x68, 0x18), TextBG); // 3,237

    case HiCommentDirective:
      return XtColorFB!(TtyRgb2Color!(0xd0, 0x00, 0x00), TextBG);

    case HiNumber:
      return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0x18), TextBG); // 2,237

    case HiChar:
      return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TextBG); // 14,237
    case HiCharSpecial:
      return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0x54), TextBG); // 10,237; green
      //return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0x18), TextBG); // 2,237
      //return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TextBG); // 14,237

    // normal string
    case HiDQString:
    case HiSQString:
    case HiBQString:
    case HiRQString:
      return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0xb2), TextBG); // 6,237
    case HiDQStringSpecial:
    case HiSQStringSpecial:
      return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TextBG); // 14,237
      //return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0x18), TextBG); // 2,237

    case HiKeyword: return XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x54), TextBG); // 11,237
    case HiKeywordHi: return XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TextBG); // 202,237
    case HiBuiltin: return XtColorFB!(TtyRgb2Color!(0xff, 0x5f, 0x00), TextBG); // 202,237
    case HiType: return XtColorFB!(TtyRgb2Color!(0xff, 0xaf, 0x00), TextBG); // 214,237
    case HiSpecial: return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0x54), TextBG); // 10,237; green
    case HiInternal: return XtColorFB!(TtyRgb2Color!(0xff, 0x54, 0x54), TextBG); // 9,237; red
    case HiPunct: return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TextBG); // 14,237
    case HiSemi: return XtColorFB!(TtyRgb2Color!(0xff, 0x00, 0xff), TextBG); // 201,237
    case HiUDA: return XtColorFB!(TtyRgb2Color!(0x00, 0x87, 0xff), TextBG); // 33,237
    case HiAliced: return XtColorFB!(TtyRgb2Color!(0xff, 0x5f, 0x00), TextBG); // 202,237
    case HiPreprocessor: return XtColorFB!(TtyRgb2Color!(0xff, 0x54, 0x54), TextBG); // 9,237; red

    case HiRegExp: return XtColorFB!(TtyRgb2Color!(0xff, 0x5f, 0x00), TextBG); // 202,237

    case HiToDoOpen: // [.]
      return XtColorFB!(TtyRgb2Color!(0xff, 0x00, 0xff), TextBG);
    case HiToDoUnsure: // [?]
      return XtColorFB!(TtyRgb2Color!(0xc0, 0x00, 0xc0), TextBG);
    case HiToDoUrgent: // [!]
      return XtColorFB!(TtyRgb2Color!(0xff, 0x00, 0x00), TextBG);
    case HiToDoSemi: // [+]
      return XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x00), TextBG);
    case HiToDoDone: // [*]
      return XtColorFB!(TtyRgb2Color!(0x00, 0xa0, 0x00), TextBG);
    case HiToDoDont: // [-]
      return XtColorFB!(TtyRgb2Color!(0x90, 0x90, 0x00), TextBG);

    default: assert(0, "wtf?!");
  }
}
