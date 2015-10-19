/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 1, September 2015
 *
 * Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
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
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 1. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 2. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0 and 1 of this license.
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
 * License: IVPLv1
 */
module iv.rect is aliced;


////////////////////////////////////////////////////////////////////////////////
struct Rect {
  import std.traits : isIntegral, isUnsigned;

  int x = 0, y = 0;
  int width = -1; // <0: invalid rect
  int height = -1; // <0: invalid rect

  string toString () const @safe pure {
    import std.string : format; // should be std.format, but gdc...
    return (valid ? "(%s,%s)-(%s,%s)".format(x, y, x+width-1, y+height-1) : "(invalid-rect)");
  }

  // default constructor: (x, y, w, h)
  this(CW, CH) (int ax, int ay, CW awidth, CH aheight) if (isIntegral!CW && isIntegral!CH) => set(ax, ay, awidth, aheight);

@safe:
nothrow:
@nogc:

  @property bool valid () const pure => (width >= 0 && height >= 0);
  @property bool empty () const pure => (width <= 0 || height <= 0); /// invalid rects are empty

  void invalidate () => width = height = -1;

  @property int x0 () const pure => x;
  @property int y0 () const pure => y;
  @property int x1 () const pure => (width > 0 ? x+width-1 : x-1);
  @property int y1 () const pure => (height > 0 ? y+height-1 : y-1);

  @property void x0 (in int val) { width = x+width-val; x = val; }
  @property void y0 (in int val) { height = y+height-val; y = val; }
  @property void x1 (in int val) => width = val-x+1;
  @property void y1 (in int val) => height = val-y+1;

  alias left = x0;
  alias top = y0;
  alias right = x1;
  alias bottom = y1;

  bool inside (in int ax, in int ay) const pure =>
    empty ? false : (ax >= x && ay >= y && ax < x+width && ay < y+height);

  // is `r` inside `this`?
  bool inside (in Rect r) const pure {
    return
      !empty && !r.empty &&
      r.x >= x && r.y >= y &&
      r.x1 <= x1 && r.y1 <= y1;
  }

  // is `r` and `this` overlaps?
  bool overlap (in Rect r) const pure {
    return
      !empty && !r.empty &&
      x <= r.x1 && r.x <= x1 && y <= r.y1 && r.y <= y1;
      //!(x > r.x1 || r.x > x1 || y > r.y1 || r.y > y1);
  }

  // extend `this` so it will include `r`
  void include (in Rect r) {
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

  void set(CW, CH) (int ax, int ay, CW awidth, CH aheight) if (isIntegral!CW && isIntegral!CH) {
    x = ax;
    y = ay;
    static if (isUnsigned!CW && CW.sizeof >= width.sizeof) if (awidth >= width.max) awidth = width.max;
    static if (isUnsigned!CH && CH.sizeof >= height.sizeof) if (aheight >= height.max) aheight = height.max;
    width = cast(int)awidth;
    height = cast(int)aheight;
  }

  void moveX0Y0By (int dx, int dy) {
    x += dx;
    y += dy;
    width -= dx;
    height -= dy;
  }

  void moveX1Y1By (int dx, int dy) {
    width += dx;
    height += dy;
  }

  void moveBy (int dx, int dy) {
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
  bool clipStripe(LT) (ref int x, int y, ref LT len, out int leftSkip) if (isIntegral!LT) {
    if (empty) return false;
    if (len <= 0 || y < this.y || y >= this.y+height || x >= this.x+width) return false;
    if (x < this.x) {
      // left clip
      if (x+len <= this.x) return false;
      len -= (leftSkip = this.x-x);
      x = this.x;
    }
    if (x+len >= this.x+width) {
      // right clip
      len = this.x+width-x;
      assert(len > 0); // yeah, always
    }
    return true;
  }

  bool clipStripe(LT) (ref int x, int y, ref LT len) if (isIntegral!LT) {
    int dummy = void;
    return clipStripe(x, y, len, dummy);
  }

  /**
   * clip another rect to this rect. both rects has same origin.
   *
   * Params:
   *  rc = rect to clip against this
   *
   * Returns:
   *  result = false if rect is completely clipped out (and rc is invalidated)
   */
  bool clipRect (ref Rect rc) {
    if (rc.empty || this.empty) { rc.invalidate(); return false; }
    if (rc.y1 < this.y0 || rc.x1 < this.x0 || rc.x0 > this.x1 || rc.y0 > this.y1) { rc.invalidate(); return false; }
    // rc is at least partially inside this rect
    if (rc.x0 < this.x0) rc.x0 = this.x0; // clip left
    if (rc.y0 < this.y0) rc.y0 = this.y0; // clip top
    if (rc.x1 > this.x1) rc.x1 = this.x1; // clip right
    if (rc.y1 > this.y1) rc.y1 = this.y1; // clip bottom
    assert(!rc.empty); // yeah, always
    return true;
  }
}


/*
unittest {
  auto rc = Rect(0, 0, 10, 10);
  import iv.writer;
  writefln!"rect=%s"(rc);
}
*/
