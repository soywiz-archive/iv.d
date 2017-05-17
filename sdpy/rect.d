/*
 * Pixel Graphics Library
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
module iv.sdpy.rect /*is aliced*/;
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
struct Rect {
  int x = 0, y = 0;
  int width = -1; // <0: invalid rect
  int height = -1; // <0: invalid rect

  string toString () const @safe pure {
    import std.string : format;
    return (valid ? "(%s,%s)-(%s,%s)".format(x, y, x+width-1, y+height-1) : "(invalid-rect)");
  }

nothrow @safe @nogc:
  // default constructor: (x, y, w, h)
  this (int ax, int ay, int awidth, int aheight) { static if (__VERSION__ > 2067) pragma(inline, true); set(ax, ay, awidth, aheight); }

  @property pure const {
    // note that killed rects are always equal
    bool opEquals() (in auto ref Rect rc) {
      static if (__VERSION__ > 2067) pragma(inline, true);
      return (valid ? (x0 == rc.x0 && y0 == rc.y0 && width == rc.width && height == rc.height) : !rc.valid);
    }

    bool valid () { static if (__VERSION__ > 2067) pragma(inline, true); return (width >= 0 && height >= 0); }
    bool empty () { static if (__VERSION__ > 2067) pragma(inline, true); return (width <= 0 || height <= 0); } // invalid rects are empty

    int x0 () { static if (__VERSION__ > 2067) pragma(inline, true); return x; }
    int y0 () { static if (__VERSION__ > 2067) pragma(inline, true); return y; }
    int x1 () { static if (__VERSION__ > 2067) pragma(inline, true); return (width > 0 ? x+width-1 : x-1); }
    int y1 () { static if (__VERSION__ > 2067) pragma(inline, true); return (height > 0 ? y+height-1 : y-1); }
  }

  @property {
    void x0 (in int val) { static if (__VERSION__ > 2067) pragma(inline, true); width = x+width-val; x = val; }
    void y0 (in int val) { static if (__VERSION__ > 2067) pragma(inline, true); height = y+height-val; y = val; }
    void x1 (in int val) { static if (__VERSION__ > 2067) pragma(inline, true); width = val-x+1; }
    void y1 (in int val) { static if (__VERSION__ > 2067) pragma(inline, true); height = val-y+1; }
  }

  void kill () { static if (__VERSION__ > 2067) pragma(inline, true); width = height = -1; }

  alias left = x0;
  alias top = y0;
  alias right = x1;
  alias bottom = y1;

  bool contains (in int ax, in int ay) const pure { static if (__VERSION__ > 2067) pragma(inline, true); return (empty ? false : (ax >= x && ay >= y && ax < x+width && ay < y+height)); }

  // is `this` contains `rc`?
  bool contains() (in auto ref Rect rc) const pure {
    static if (__VERSION__ > 2067) pragma(inline, true);
    return
      !this.empty && !rc.empty &&
      rc.x >= this.x && rc.y >= this.y &&
      rc.x1 <= this.x1 && rc.y1 <= this.y1;
  }

  // is `this` inside `rc`?
  bool inside() (in auto ref Rect rc) const pure {
    static if (__VERSION__ > 2067) pragma(inline, true);
    return
      !rc.empty && !this.empty &&
      this.x >= rc.x && this.y >= rc.y &&
      this.x1 <= rc.x1 && this.y1 <= rc.y1;
  }

  // is `r` and `this` overlaps?
  bool overlap() (in auto ref Rect r) const pure {
    static if (__VERSION__ > 2067) pragma(inline, true);
    return
      !empty && !r.empty &&
      x <= r.x1 && r.x <= x1 && y <= r.y1 && r.y <= y1;
      //!(x > r.x1 || r.x > x1 || y > r.y1 || r.y > y1);
  }

  // extend `this` so it will include `r`
  void include() (in auto ref Rect r) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (!r.empty) {
      if (empty) {
        x = r.x;
        y = r.y;
        width = r.width;
        height = r.height;
      } else {
        if (r.x < x) x = r.x;
        if (r.y < y) y = r.y;
        if (r.x1 > x1) x1 = r.x1;
        if (r.y1 > y1) y1 = r.y1;
      }
    }
  }

  void set (int ax, int ay, int awidth, int aheight) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    x = ax;
    y = ay;
    width = awidth;
    height = aheight;
  }

  void moveX0Y0By (int dx, int dy) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    x += dx;
    y += dy;
    width -= dx;
    height -= dy;
  }

  void moveX1Y1By (int dx, int dy) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    width += dx;
    height += dy;
  }

  void moveBy (int dx, int dy) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    x += dx;
    y += dy;
  }

  /**
   * clip (x,y,len) stripe to this rect
   *
   * Params:
   *  x = stripe start (not relative to rect)
   *  y = stripe start (not relative to rect)
   *  len = stripe length
   *
   * Returns:
   *  x = fixed x
   *  len = fixed length
   *  leftSkip = how much cells skipped at the left side
   *  result = false if stripe is completely clipped out
   *
   * TODO:
   *  overflows
   */
  bool clipStripe (ref int x, int y, ref int len, int* leftSkip=null) @trusted {
    int dummy;
    if (leftSkip is null) leftSkip = &dummy;
    *leftSkip = 0;
    if (empty) return false;
    if (len <= 0 || y < this.y || y >= this.y+height || x >= this.x+width) return false;
    if (x < this.x) {
      // left clip
      if (x+len <= this.x) return false;
      len -= (*leftSkip = this.x-x);
      x = this.x;
    }
    if (x+len >= this.x+width) {
      // right clip
      len = this.x+width-x;
      assert(len > 0); // yeah, always
    }
    return true;
  }

  /**
   * clip this rect by another rect. both rects has same origin.
   *
   * Params:
   *  rc = rect to clip by
   *
   * Returns:
   *  result = false if rect is completely clipped out (and is killed)
   */
  bool clipByRect() (in auto ref Rect rc) {
    // alas, dmd cannot inline function with more than one assignment
    //static if (__VERSION__ > 2067) pragma(inline, true);
    if (this.empty || rc.empty || this.y1 < rc.y0 || this.x1 < rc.x0 || this.x0 > rc.x1 || this.y0 > rc.y1) {
      this.kill();
      return false;
    } else {
      // this is at least partially inside rc rect
      if (this.x0 < rc.x0) this.x0 = rc.x0; // clip left
      if (this.y0 < rc.y0) this.y0 = rc.y0; // clip top
      if (this.x1 > rc.x1) this.x1 = rc.x1; // clip right
      if (this.y1 > rc.y1) this.y1 = rc.y1; // clip bottom
      assert(!this.empty); // yeah, always
      return true;
    }
  }
}
