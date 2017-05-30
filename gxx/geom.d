/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.gxx.geom /*is aliced*/;
private:


// ////////////////////////////////////////////////////////////////////////// //
public struct GxSize {
public:
  int width, height; ///

  ///
  string toString () const @trusted nothrow {
    if (valid) {
      import core.stdc.stdio : snprintf;
      char[128] buf = void;
      return buf[0..snprintf(buf.ptr, buf.length, "(%dx%d)", width, height)].idup;
    } else {
      return "(invalid-size)";
    }
  }

pure nothrow @safe @nogc:
  this() (in auto ref GxSize p) { /*pragma(inline, true);*/ width = p.width; height = p.height; } ///
  this (int ax, int ay) { /*pragma(inline, true);*/ width = ax; height = ay; } ///
  @property bool valid () const { pragma(inline, true); return (width >= 0 && height >= 0); } ///
  @property bool invalid () const { pragma(inline, true); return (width < 0 || height < 0); } ///
  @property bool empty () const { pragma(inline, true); return (width <= 0 || height <= 0); } /// invalid rects are empty
  void opAssign() (in auto ref GxSize p) { pragma(inline, true); width = p.width; height = p.height; } ///
  bool opEquals() (in auto ref GxSize p) const { pragma(inline, true); return (p.width == width && p.height == height); } ///
  ///
  int opCmp() (in auto ref GxSize p) const {
    pragma(inline, true);
         if (auto d0 = height-p.height) return (d0 < 0 ? -1 : 1);
    else if (auto d1 = width-p.width) return (d1 < 0 ? -1 : 1);
    else return 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct GxPoint {
public:
  int x, y; ///

  ///
  string toString () const @trusted nothrow {
    import core.stdc.stdio : snprintf;
    char[128] buf = void;
    return buf[0..snprintf(buf.ptr, buf.length, "(%d,%d)", x, y)].idup;
  }

pure nothrow @safe @nogc:
  this() (in auto ref GxPoint p) { pragma(inline, true); x = p.x; y = p.y; } ///
  this (int ax, int ay) { pragma(inline, true); x = ax; y = ay; } ///
  void opAssign() (in auto ref GxPoint p) { pragma(inline, true); x = p.x; y = p.y; } ///
  bool opEquals() (in auto ref GxPoint p) const { pragma(inline, true); return (p.x == x && p.y == y); } ///
  ///
  int opCmp() (in auto ref GxPoint p) const {
    pragma(inline, true);
         if (auto d0 = y-p.y) return (d0 < 0 ? -1 : 1);
    else if (auto d1 = x-p.x) return (d1 < 0 ? -1 : 1);
    else return 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct GxRect {
public:
  int x0, y0; ///
  int width = -1; // <0: invalid rect
  int height = -1; // <0: invalid rect

  alias left = x0; ///
  alias top = y0; ///
  alias right = x1; ///
  alias bottom = y1; ///
  alias x = x0;
  alias y = y0;

  ///
  string toString () const @trusted nothrow {
    if (valid) {
      import core.stdc.stdio : snprintf;
      char[128] buf = void;
      return buf[0..snprintf(buf.ptr, buf.length, "(%d,%d)-(%d,%d)", x0, y0, x0+width-1, y0+height-1)].idup;
    } else {
      return "(invalid-rect)";
    }
  }

pure nothrow @safe @nogc:
  ///
  this() (in auto ref GxRect rc) { /*pragma(inline, true);*/ x0 = rc.x0; y0 = rc.y0; width = rc.width; height = rc.height; }

  ///
  this() (in auto ref GxSize sz) { /*pragma(inline, true);*/ x0 = 0; y0 = 0; width = sz.width; height = sz.height; }

  ///
  this (int ax0, int ay0, int awidth, int aheight) {
    //pragma(inline, true);
    x0 = ax0;
    y0 = ay0;
    width = awidth;
    height = aheight;
  }

  ///
  this() (in auto ref GxPoint xy0, int awidth, int aheight) {
    //pragma(inline, true);
    x0 = xy0.x;
    y0 = xy0.y;
    width = awidth;
    height = aheight;
  }

  ///
  this() (in auto ref GxPoint xy0, in auto ref GxPoint xy1) {
    //pragma(inline, true);
    x0 = xy0.x;
    y0 = xy0.y;
    width = xy1.x-xy0.x+1;
    height = xy1.y-xy0.y+1;
  }

  void opAssign() (in auto ref GxRect rc) { /*pragma(inline, true);*/ x0 = rc.x0; y0 = rc.y0; width = rc.width; height = rc.height; } ///
  bool opEquals() (in auto ref GxRect rc) const { pragma(inline, true); return (rc.x0 == x0 && rc.y0 == y0 && rc.width == width && rc.height == height); } ///
  ///
  int opCmp() (in auto ref GxRect p) const {
    if (auto d0 = y0-rc.y0) return (d0 < 0 ? -1 : 1);
    if (auto d1 = x0-rc.x0) return (d1 < 0 ? -1 : 1);
    if (auto d2 = width*height-rc.width*rc.height) return (d2 < 0 ? -1 : 1);
    return 0;
  }

  @property bool valid () const { pragma(inline, true); return (width >= 0 && height >= 0); } ///
  @property bool invalid () const { pragma(inline, true); return (width < 0 || height < 0); } ///
  @property bool empty () const { pragma(inline, true); return (width <= 0 || height <= 0); } /// invalid rects are empty

  void invalidate () { pragma(inline, true); width = height = -1; } ///

  @property GxPoint lefttop () const { pragma(inline, true); return GxPoint(x0, y0); } ///
  @property GxPoint righttop () const { pragma(inline, true); return GxPoint(x0+width-1, y0); } ///
  @property GxPoint leftbottom () const { pragma(inline, true); return GxPoint(x0, y0+height-1); } ///
  @property GxPoint rightbottom () const { pragma(inline, true); return GxPoint(x0+width-1, y0+height-1); } ///

  @property void lefttop() (in auto ref GxPoint v) { pragma(inline, true); x0 = v.x; y0 = v.y; } ///
  @property void righttop() (in auto ref GxPoint v) { pragma(inline, true); x1 = v.x; y0 = v.y; } ///
  @property void leftbottom() (in auto ref GxPoint v) { pragma(inline, true); x0 = v.x; y1 = v.y; } ///
  @property void rightbottom() (in auto ref GxPoint v) { pragma(inline, true); x1 = v.x; y1 = v.y; } ///

  alias topleft = lefttop; ///
  alias topright = righttop; ///
  alias bottomleft = leftbottom; ///
  alias bottomright = rightbottom; ///

  @property GxSize size () const { pragma(inline, true); return GxSize(width, height); } ///
  @property void size() (in auto ref GxSize sz) { pragma(inline, true); width = sz.width; height = sz.height; } ///

  @property int x1 () const { pragma(inline, true); return (width > 0 ? x0+width-1 : x0-1); } ///
  @property int y1 () const { pragma(inline, true); return (height > 0 ? y0+height-1 : y0-1); } ///

  @property void x1 (in int val) { pragma(inline, true); width = val-x0+1; } ///
  @property void y1 (in int val) { pragma(inline, true); height = val-y0+1; } ///

  GxPoint translateToGlobal() (in auto ref GxPoint lpt) const {
    pragma(inline, true);
    return GxPoint(lpt.x+x0, lpt.y+y0);
  }

  GxRect translateToGlobal() (in auto ref GxRect lrc) const {
    pragma(inline, true);
    return GxRect(lrc.x0+x0, lrc.y0+y0, lrc.width, lrc.height);
  }

  ///
  bool inside() (in auto ref GxPoint p) const {
    pragma(inline, true);
    return (width > 0 && height > 0 ? (p.x >= x0 && p.y >= y0 && p.x < x0+width && p.y < y0+height) : false);
  }

  /// ditto
  bool inside (in int ax, in int ay) const {
    pragma(inline, true);
    return (width > 0 && height > 0 ? (ax >= x0 && ay >= y0 && ax < x0+width && ay < y0+height) : false);
  }

  /// is `r` inside `this`?
  bool contains() (in auto ref GxRect r) const {
    pragma(inline, true);
    return
      width > 0 && height > 0 &&
      r.width > 0 && r.height > 0 &&
      r.x0 >= x0 && r.y0 >= y0 &&
      r.x0+r.width <= x0+width && r.y0+r.height <= y0+height;
  }

  /// is `r` and `this` overlaps?
  bool overlaps() (in auto ref GxRect r) const {
    pragma(inline, true);
    return
      width > 0 && height > 0 &&
      r.width > 0 && r.height > 0 &&
      x0 < r.x0+r.width && r.x0 < x0+width &&
      y0 < r.y0+r.height && r.y0 < y0+height;
  }

  /// extend `this` so it will include `r`
  void include() (in auto ref GxRect r) {
    pragma(inline, true);
    if (!r.empty) {
      if (empty) {
        x0 = r.x;
        y0 = r.y;
        width = r.width;
        height = r.height;
      } else {
        if (r.x < x0) x0 = r.x0;
        if (r.y < y0) y0 = r.y0;
        if (r.x1 > x1) x1 = r.x1;
        if (r.y1 > y1) y1 = r.y1;
      }
    }
  }

  /// clip `this` so it will not be larger than `r`
  bool intersect() (in auto ref GxRect r) {
    if (r.invalid || invalid) { width = height = -1; return false; }
    if (r.empty || empty) { width = height = 0; return false; }
    if (r.y1 < y0 || r.x1 < x0 || r.x0 > x1 || r.y0 > y1) { width = height = 0; return false; }
    // rc is at least partially inside this rect
    if (x0 < r.x0) x0 = r.x0;
    if (y0 < r.y0) y0 = r.y0;
    if (x1 > r.x1) x1 = r.x1;
    if (y1 > r.y1) y1 = r.y1;
    assert(!empty); // yeah, always
    return true;
  }

  ///
  void shrinkBy (int dx, int dy) {
    pragma(inline, true);
    if ((dx || dy) && valid) {
      x0 += dx;
      y0 += dy;
      width -= dx*2;
      height -= dy*2;
    }
  }

  /// ditto
  void shrinkBy() (in auto ref GxSize sz) { pragma(inline, true); shrinkBy(sz.width, sz.height); }

  ///
  void growBy (int dx, int dy) {
    pragma(inline, true);
    if ((dx || dy) && valid) {
      x0 -= dx;
      y0 -= dy;
      width += dx*2;
      height += dy*2;
    }
  }

  /// ditto
  void growBy() (in auto ref GxSize sz) { pragma(inline, true); growBy(sz.width, sz.height); }

  ///
  void set (int ax0, int ay0, int awidth, int aheight) {
    pragma(inline, true);
    x0 = ax0;
    y0 = ay0;
    width = awidth;
    height = aheight;
  }

  ///
  void moveLeftTopBy (int dx, int dy) {
    pragma(inline, true);
    x0 += dx;
    y0 += dy;
    width -= dx;
    height -= dy;
  }

  /// ditto
  void moveLeftTopBy() (in auto ref GxPoint p) { pragma(inline, true); moveLeftTopBy(p.x, p.y); }

  alias moveTopLeftBy = moveLeftTopBy; /// ditto

  ///
  void moveRightBottomBy (int dx, int dy) {
    pragma(inline, true);
    width += dx;
    height += dy;
  }

  /// ditto
  void moveRightBottomBy() (in auto ref GxPoint p) { pragma(inline, true); moveRightBottomBy(p.x, p.y); }

  alias moveBottomRightBy = moveRightBottomBy; /// ditto

  ///
  void moveBy (int dx, int dy) {
    pragma(inline, true);
    x0 += dx;
    y0 += dy;
  }

  /// ditto
  void moveBy() (in auto ref GxPoint p) { pragma(inline, true); moveBy(p.x, p.y); }

  ///
  void moveTo (int nx, int ny) {
    pragma(inline, true);
    x0 = nx;
    y0 = ny;
  }

  /// ditto
  void moveTo() (in auto ref GxPoint p) { pragma(inline, true); moveTo(p.x, p.y); }

  /**
   * clip (x,y,len) stripe to this rect
   *
   * Params:
   *  x = stripe start (not relative to rect)
   *  y = stripe start (not relative to rect)
   *  len = stripe length
   *
   * Returns:
   *  x = fixed x (invalid if result is false)
   *  len = fixed length (invalid if result is false)
   *  leftSkip = how much cells skipped at the left side (invalid if result is false)
   *  result = false if stripe is completely clipped out
   *
   * TODO:
   *  overflows
   */
  bool clipHStripe (ref int x, int y, ref int len, int* leftSkip=null) const @trusted {
    if (empty) return false;
    if (len <= 0 || y < y0 || y >= y0+height || x >= x0+width) return false;
    if (x < x0) {
      // left clip
      if (x+len <= x0) return false;
      immutable int dx = x0-x;
      if (leftSkip !is null) *leftSkip = dx;
      len -= dx;
      x = x0;
      assert(len > 0); // yeah, always
    }
    if (x+len > x0+width) {
      // right clip
      len = x0+width-x;
      assert(len > 0); // yeah, always
    }
    return true;
  }

  /**
   * clip (x,y,hgt) stripe to this rect
   *
   * Params:
   *  x = stripe start (not relative to rect)
   *  y = stripe start (not relative to rect)
   *  hgt = stripe length
   *
   * Returns:
   *  y = fixed y (invalid if result is false)
   *  hgt = fixed length (invalid if result is false)
   *  topSkip = how much cells skipped at the top side (invalid if result is false)
   *  result = false if stripe is completely clipped out
   *
   * TODO:
   *  overflows
   */
  bool clipVStripe (int x, ref int y, ref int hgt, int* topSkip=null) const @trusted {
    if (empty) return false;
    if (hgt <= 0 || x < x0 || x >= x0+width || y >= y0+height) return false;
    if (y < y0) {
      // top clip
      if (y+hgt <= y0) return false;
      immutable int dy = y0-y;
      if (topSkip !is null) *topSkip = dy;
      hgt -= dy;
      y = y0;
      assert(hgt > 0); // yeah, always
    }
    if (y+hgt > y0+height) {
      // bottom clip
      hgt = y0+height-y;
      assert(hgt > 0); // yeah, always
    }
    return true;
  }

  ///
  bool clipHVStripes (ref int x, ref int y, ref int wdt, ref int hgt, int* leftSkip=null, int* topSkip=null) const @trusted {
    if (empty || wdt <= 0 || hgt <= 0) return false;
    if (y >= y0+height || x >= x0+width) return false;
    if (x < x0) {
      // left clip
      if (x+wdt <= x0) return false;
      immutable int dx = x0-x;
      if (leftSkip !is null) *leftSkip = dx;
      wdt -= dx;
      x = x0;
      assert(wdt > 0); // yeah, always
    }
    if (x+wdt > x0+width) {
      // right clip
      wdt = x0+width-x;
      assert(wdt > 0); // yeah, always
    }

    if (y < y0) {
      // top clip
      if (y+hgt <= y0) return false;
      immutable int dy = y0-y;
      if (topSkip !is null) *topSkip = dy;
      hgt -= dy;
      y = y0;
      assert(hgt > 0); // yeah, always
    }
    if (y+hgt > y0+height) {
      // bottom clip
      hgt = y0+height-y;
      assert(hgt > 0); // yeah, always
    }

    return true;
  }
}
