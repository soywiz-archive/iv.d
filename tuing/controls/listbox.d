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
module iv.tuing.controls.listbox;

import iv.eventbus;
import iv.flexlayout;
import iv.strex;
import iv.rawtty;

import iv.tuing.events;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiListBox : FuiControl {
  alias onMyEvent = super.onMyEvent;

  private string[] items;
  private bool[] marks;
  private int mTopItem;
  private int mCurItem;
  private int mMaxItemWidth;
  public bool allowmarks; // `true` to allow item marking

  this (FuiControl aparent) {
    this.connectListeners();
    super(aparent);
    horizontal = true;
    aligning = Align.Start;
    minSize.w = 0;
    minSize.h = 0;
    canBeFocused = true;
    hotkeyed = false;
    acceptClick(TtyEvent.MButton.Left);
    acceptClick(TtyEvent.MButton.Right);
    acceptClick(TtyEvent.MButton.WheelUp);
    acceptClick(TtyEvent.MButton.WheelDown);
    flex = 1;
  }

  protected override void layoutingStarted () {
    super.layoutingStarted();
    if (minSize.w == 0) {
      int msz = (mMaxItemWidth ? mMaxItemWidth : 10);
      if (msz < 4) msz = 4;
      minSize.w = msz+2;
    }
    if (minSize.h == 0) {
      int mln = cast(int)items.length;
      if (mln > 16) mln = 16;
      minSize.h = mln;
    }
  }

  protected override void layoutingComplete () {
    super.layoutingComplete();
    normPage();
  }

  final @property int count () const pure nothrow @safe @nogc { return cast(int)items.length; }
  final @property int curitem () const pure nothrow @safe @nogc { return mCurItem; }
  // this won't call onAction
  final @property void curitem (int v) pure nothrow @safe @nogc {
    if (items.length == 0) return;
    if (v < 0) v = 0; else if (v >= items.length) v = cast(int)items.length;
    mCurItem = v;
    normPage();
  }

  //TODO: add methods to change item text, delete items, change marks, and so on
  final @property string opIndex (usize idx) const pure nothrow @trusted @nogc { return (idx < items.length ? items.ptr[idx] : null); }

  final bool isMarkedAt (usize idx) const pure nothrow @trusted @nogc { return (idx < marks.length ? marks.ptr[idx] : false); }
  final void setMarkedAt (usize idx, bool v) pure nothrow @trusted {
    if (idx >= items.length) return;
    if (marks.length <= idx) {
      if (!v) return;
      marks.length = idx+1;
    }
    marks[idx] = v;
  }

  // return item index (not count!)
  final int addItem(T : const(char)[]) (T val, bool marked=false) {
    if (items.length == int.max) throw new Exception("too many items in listbox");
    static if (is(T == typeof(null))) {
      items ~= "";
    } else static if (is(T == string)) {
      if (val.length > int.max/8) val = val[0..int.max/8];
      items ~= val;
    } else {
      if (val.length > int.max/8) val = val[0..int.max/8];
      items ~= val.idup;
    }
    if (marked) {
      assert(marks.length < items.length);
      marks.length = items.length;
      marks[$-1] = marked;
    }
    if (mMaxItemWidth < items[$-1].length) mMaxItemWidth = cast(int)items[$-1].length;
    return cast(int)items.length-1;
  }

  // should i draw a scrollbar?
  protected final @property bool needScrollBar () const pure nothrow @safe @nogc {
    return (size.w > 2 && (mTopItem > 0 || mTopItem+size.h < items.length));
  }

  final void normPage () pure nothrow @safe @nogc {
    // make current item visible
    if (items.length == 0) { mCurItem = -1; mTopItem = 0; mMaxItemWidth = 0; return; }
    // sanitize current item (just in case, it should be sane always)
    if (mCurItem < 0) mCurItem = 0;
    if (mCurItem >= items.length) mCurItem = cast(int)items.length-1;
    int oldtop = mTopItem;
    if (mTopItem > items.length-size.h) mTopItem = cast(int)items.length-size.h;
    if (mTopItem < 0) mTopItem = 0;
    if (mCurItem < mTopItem) {
      mTopItem = mCurItem;
    } else if (mTopItem+size.h <= mCurItem) {
      mTopItem = mCurItem-size.h+1;
      if (mTopItem < 0) mTopItem = 0;
    }
  }

  // action called when current item changed
  override void doAction () {
    if (onAction !is null) { onAction(this); return; }
    (new FuiEventListBoxCurIndexChanged(this, mCurItem)).post;
  }

  protected override void drawSelf (XtWindow win) {
    // get colors
    uint atext, asel, agauge, amark, amarksel;
    if (enabled) {
      atext = palColor!"def"();
      asel = palColor!"sel"();
      amark = palColor!"mark"();
      amarksel = palColor!"marksel"();
      agauge = palColor!"gauge"();
    } else {
      atext = asel = amark = amarksel = agauge = palColor!"disabled"();
    }
    win.color = atext;
    win.fill(0, 0, win.width, win.height);
    if (items.length == 0) return;
    bool wantSBar = needScrollBar;
    int wdt = win.width;
    int x = 0, y = 0;
    // should i draw a scrollbar?
    if (wantSBar) {
      wdt -= 2;
      x += 2;
    } else {
      x += 1;
      wdt -= 1;
    }
    // draw items
    auto curit = mTopItem;
    while (curit < items.length && y < win.height) {
      bool marked = (curit < marks.length ? marks[curit] : false);
      if (curit == mCurItem) {
        // fill cursor
        win.color = (marked ? amarksel : asel);
        win.writeCharsAt(x-(wantSBar ? 0 : 1), y, wdt+(wantSBar ? 0 : 1), ' ');
        if (focused) win.gotoXY(x-(wantSBar ? 0 : 1), y);
      } else if (marked) {
        // fill mark
        win.color = amark;
        win.writeCharsAt(x-(wantSBar ? 0 : 1), y, wdt+(wantSBar ? 0 : 1), ' ');
      } else {
        win.color = atext;
      }
      win.writeStrAt(x, y, items[curit]);
      ++y;
      ++curit;
    }
    // draw scrollbar
    if (wantSBar) {
      x -= 2;
      win.color = atext;
      win.vline(x+1, 0, win.height);
      win.color = agauge;
      int last = mTopItem+win.height;
      if (last > items.length) last = cast(int)items.length;
      last = win.height*last/cast(int)items.length;
      if (last >= win.height-1 && mTopItem+win.height < items.length) last = win.height-2;
      foreach (int yy; 0..win.height) win.writeCharsAt!true(x, yy, 1, (yy <= last ? 'a' : ' '));
    }
  }

  void onMyEvent (FuiEventClick evt) {
    auto oldCI = mCurItem;
    if (evt.wheelup) {
      evt.eat();
      if (--mCurItem < 0) mCurItem = 0;
    } else if (evt.wheeldown) {
      evt.eat();
      if (items.length > 0) {
        if (++mCurItem >= items.length) mCurItem = cast(int)items.length-1;
      }
    } else {
      int cnum = -1;
      int sx = (needScrollBar ? 2 : 1);
      if (evt.pt.x >= sx && evt.pt.x < size.w && evt.pt.y >= 0 && evt.pt.y < size.h) {
        cnum = mTopItem+evt.pt.y;
        if (cnum >= items.length) cnum = -1;
      }
      if (cnum >= 0 && cnum < items.length) {
        if (evt.right && allowmarks) {
          evt.eat();
          setMarkedAt(cnum, true);
        } else if (evt.left) {
          evt.eat();
          mCurItem = cnum;
        }
      }
    }
    normPage();
    if (mCurItem != oldCI) doAction();
  }

  void onMyEvent (FuiEventKey evt) {
    bool doKey() {
      if (items.length == 0) return false;
      if (evt.key == "Up") {
        if (--mCurItem < 0) mCurItem = 0;
        return true;
      }
      if (evt.key == "S-Up") {
        if (--mTopItem < 0) mTopItem = 0;
        return true;
      }
      if (evt.key == "Down") {
        if (items.length > 0) {
          if (++mCurItem >= items.length) mCurItem = cast(int)items.length-1;
        }
        return true;
      }
      if (evt.key == "S-Down") {
        if (mTopItem+size.h < items.length) ++mTopItem;
        return true;
      }
      if (evt.key == "Home") {
        mCurItem = 0;
        return true;
      }
      if (evt.key == "End") {
        if (items.length > 0) mCurItem = cast(int)items.length-1;
        return true;
      }
      if (evt.key == "PageUp") {
        if (mCurItem > mTopItem) {
          mCurItem = mTopItem;
        } else if (size.h > 1) {
          if ((mCurItem -= size.h-1) < 0) mCurItem = 0;
        }
        return true;
      }
      if (evt.key == "PageDown") {
        if (mCurItem < mTopItem+size.h-1) {
          mCurItem = mTopItem+size.h-1;
        } else if (size.h > 1 && items.length > 0) {
          if ((mCurItem += size.h-1) >= items.length) mCurItem = cast(int)items.length-1;
        }
        return true;
      }
      if (allowmarks && evt.key == "Space") {
        setMarkedAt(mCurItem, !isMarkedAt(mCurItem));
        return true;
      }
      return false;
    }
    auto oldci = mCurItem;
    if (doKey()) evt.eat();
    normPage();
    if (mCurItem != oldci) doAction();
  }
}
