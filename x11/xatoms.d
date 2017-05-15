module iv.x11.xatoms is aliced;

import iv.x11.x11 : Atom;


enum : Atom {
  XA_PRIMARY = cast(Atom)1,
  XA_SECONDARY = cast(Atom)2,
  XA_ARC = cast(Atom)3,
  XA_ATOM = cast(Atom)4,
  XA_BITMAP = cast(Atom)5,
  XA_CARDINAL = cast(Atom)6,
  XA_COLORMAP = cast(Atom)7,
  XA_CURSOR = cast(Atom)8,
  XA_CUT_BUFFER0 = cast(Atom)9,
  XA_CUT_BUFFER1 = cast(Atom)10,
  XA_CUT_BUFFER2 = cast(Atom)11,
  XA_CUT_BUFFER3 = cast(Atom)12,
  XA_CUT_BUFFER4 = cast(Atom)13,
  XA_CUT_BUFFER5 = cast(Atom)14,
  XA_CUT_BUFFER6 = cast(Atom)15,
  XA_CUT_BUFFER7 = cast(Atom)16,
  XA_DRAWABLE = cast(Atom)17,
  XA_FONT = cast(Atom)18,
  XA_INTEGER = cast(Atom)19,
  XA_PIXMAP = cast(Atom)20,
  XA_POINT = cast(Atom)21,
  XA_RECTANGLE = cast(Atom)22,
  XA_RESOURCE_MANAGER = cast(Atom)23,
  XA_RGB_COLOR_MAP = cast(Atom)24,
  XA_RGB_BEST_MAP = cast(Atom)25,
  XA_RGB_BLUE_MAP = cast(Atom)26,
  XA_RGB_DEFAULT_MAP = cast(Atom)27,
  XA_RGB_GRAY_MAP = cast(Atom)28,
  XA_RGB_GREEN_MAP = cast(Atom)29,
  XA_RGB_RED_MAP = cast(Atom)30,
  XA_STRING = cast(Atom)31,
  XA_VISUALID = cast(Atom)32,
  XA_WINDOW = cast(Atom)33,
  XA_WM_COMMAND = cast(Atom)34,
  XA_WM_HINTS = cast(Atom)35,
  XA_WM_CLIENT_MACHINE = cast(Atom)36,
  XA_WM_ICON_NAME = cast(Atom)37,
  XA_WM_ICON_SIZE = cast(Atom)38,
  XA_WM_NAME = cast(Atom)39,
  XA_WM_NORMAL_HINTS = cast(Atom)40,
  XA_WM_SIZE_HINTS = cast(Atom)41,
  XA_WM_ZOOM_HINTS = cast(Atom)42,
  XA_MIN_SPACE = cast(Atom)43,
  XA_NORM_SPACE = cast(Atom)44,
  XA_MAX_SPACE = cast(Atom)45,
  XA_END_SPACE = cast(Atom)46,
  XA_SUPERSCRIPT_X = cast(Atom)47,
  XA_SUPERSCRIPT_Y = cast(Atom)48,
  XA_SUBSCRIPT_X = cast(Atom)49,
  XA_SUBSCRIPT_Y = cast(Atom)50,
  XA_UNDERLINE_POSITION = cast(Atom)51,
  XA_UNDERLINE_THICKNESS = cast(Atom)52,
  XA_STRIKEOUT_ASCENT = cast(Atom)53,
  XA_STRIKEOUT_DESCENT = cast(Atom)54,
  XA_ITALIC_ANGLE = cast(Atom)55,
  XA_X_HEIGHT = cast(Atom)56,
  XA_QUAD_WIDTH = cast(Atom)57,
  XA_WEIGHT = cast(Atom)58,
  XA_POINT_SIZE = cast(Atom)59,
  XA_RESOLUTION = cast(Atom)60,
  XA_COPYRIGHT = cast(Atom)61,
  XA_NOTICE = cast(Atom)62,
  XA_FONT_NAME = cast(Atom)63,
  XA_FAMILY_NAME = cast(Atom)64,
  XA_FULL_NAME = cast(Atom)65,
  XA_CAP_HEIGHT = cast(Atom)66,
  XA_WM_CLASS = cast(Atom)67,
  XA_WM_TRANSIENT_FOR = cast(Atom)68,

  //XA_LAST_PREDEFINED = cast(Atom)68,
}
