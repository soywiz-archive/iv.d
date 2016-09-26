/* Invisible Vector Library
 * simple FlexBox-based layouting engine
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
// this engine can layout any boxset (if it is valid)
module iv.flexlayout;


// ////////////////////////////////////////////////////////////////////////// //
public align(1) struct FuiPoint {
align(1):
  int x, y;
@property pure nothrow @safe @nogc:
  bool inside (in FuiRect rc) const { pragma(inline, true); return (x >= rc.pos.x && y >= rc.pos.y && x < rc.pos.x+rc.size.w && y < rc.pos.y+rc.size.h); }
  ref FuiPoint opOpAssign(string op) (in auto ref FuiPoint pt) if (op == "+" || op == "-") {
    mixin("x"~op~"=pt.x; y"~op~"=pt.y;");
    return this;
  }
  FuiPoint opBinary(string op) (in auto ref FuiPoint pt) if (op == "+" || op == "-") {
    mixin("return FuiPoint(x"~op~"pt.x, y"~op~"pt.y);");
  }
  int opIndex (size_t idx) const { pragma(inline, true); return (idx == 0 ? x : idx == 1 ? y : 0); }
  void opIndexAssign (int v, size_t idx) { pragma(inline, true); if (idx == 0) x = v; else if (idx == 1) y = v; }
}
public align(1) struct FuiSize {
align(1):
  int w, h;
@property pure nothrow @safe @nogc:
  int opIndex (size_t idx) const { pragma(inline, true); return (idx == 0 ? w : idx == 1 ? h : 0); }
  void opIndexAssign (int v, size_t idx) { pragma(inline, true); if (idx == 0) w = v; else if (idx == 1) h = v; }
}
public align(1) struct FuiRect {
align(1):
  FuiPoint pos;
  FuiSize size;
@property pure nothrow @safe @nogc:
  int x () const { pragma(inline, true); return pos.x; }
  int y () const { pragma(inline, true); return pos.y; }
  int w () const { pragma(inline, true); return size.w; }
  int h () const { pragma(inline, true); return size.h; }
  void x (int v) { pragma(inline, true); pos.x = v; }
  void y (int v) { pragma(inline, true); pos.y = v; }
  void w (int v) { pragma(inline, true); size.w = v; }
  void h (int v) { pragma(inline, true); size.h = v; }

  ref int xp () { pragma(inline, true); return pos.x; }
  ref int yp () { pragma(inline, true); return pos.y; }
  ref int wp () { pragma(inline, true); return size.w; }
  ref int hp () { pragma(inline, true); return size.h; }

  bool inside (in FuiPoint pt) const { pragma(inline, true); return (pt.x >= pos.x && pt.y >= pos.y && pt.x < pos.x+size.w && pt.y < pos.y+size.h); }
}
public align(1) struct FuiMargin {
align(1):
  int[4] ltrb;
pure nothrow @trusted @nogc:
  this (const(int)[] v...) { if (v.length > 4) v = v[0..4]; ltrb[0..v.length] = v[]; }
@property:
  int left () const { pragma(inline, true); return ltrb.ptr[0]; }
  int top () const { pragma(inline, true); return ltrb.ptr[1]; }
  int right () const { pragma(inline, true); return ltrb.ptr[2]; }
  int bottom () const { pragma(inline, true); return ltrb.ptr[3]; }
  void left (int v) { pragma(inline, true); ltrb.ptr[0] = v; }
  void top (int v) { pragma(inline, true); ltrb.ptr[1] = v; }
  void right (int v) { pragma(inline, true); ltrb.ptr[2] = v; }
  void bottom (int v) { pragma(inline, true); ltrb.ptr[3] = v; }
  int opIndex (size_t idx) const { pragma(inline, true); return (idx < 4 ? ltrb.ptr[idx] : 0); }
  void opIndexAssign (int v, size_t idx) { pragma(inline, true); if (idx < 4) ltrb.ptr[idx] = v; }
}


// ////////////////////////////////////////////////////////////////////////// //
// properties for layouter
public class FuiLayoutProps {
  enum Orientation {
    Horizontal,
    Vertical,
  }

  // "NPD" means "non-packing direction"
  enum Align {
    Center, // the available space is divided evenly
    Start, // the NPD edge of each box is placed along the NPD of the parent box
    End, // the opposite-NPD edge of each box is placed along the opposite-NPD of the parent box
    Stretch, // the NPD-size of each boxes is adjusted to fill the parent box
  }

  void layoutingStarted () {} // called when layouter starts it's work
  void layoutingComplete () {} // called when layouter complete it's work

  //WARNING! the following properties should be set to correct values before layouting
  //         you can use `layoutingStarted()` method to do this

  bool visible; // invisible controls will be ignored by layouter
  bool lineBreak; // layouter should start a new line after this control
  bool ignoreSpacing;

  Orientation orientation = Orientation.Horizontal; // box orientation
  Align aligning = Align.Start; // NPD for children; sadly, "align" keyword is reserved
  int flex; // <=0: not flexible

  FuiMargin padding; // padding for this widget
  int spacing; // spacing for children
  int lineSpacing; // line spacing for horizontal boxes
  FuiSize minSize; // minimal control size
  FuiSize maxSize; // maximal control size (0 means "unlimited")

  // controls in ahorizontal group has the same width, and the same height in a vertical group
  FuiLayoutProps[Orientation.max+1] groupNext; // next sibling for this control's group or null

  // calculated item dimensions
  //FuiPoint pos;
  //FuiSize size;
  FuiRect rect;
  final @property ref inout(FuiPoint) pos () pure inout nothrow @safe @nogc { pragma(inline, true); return rect.pos; }
  final @property ref inout(FuiSize) size () pure inout nothrow @safe @nogc { pragma(inline, true); return rect.size; }

  FuiLayoutProps parent; // null for root element
  FuiLayoutProps firstChild; // null for "no children"
  FuiLayoutProps nextSibling; // null for last item

  // you can specify your own root if necessary
  final FuiPoint toGlobal (FuiPoint pt, FuiLayoutProps root=null) const pure nothrow @trusted @nogc {
    for (FuiLayoutProps it = cast(FuiLayoutProps)this; it !is null; it = it.parent) {
      pt.x += it.pos.x;
      pt.y += it.pos.y;
      if (it is root) break;
    }
    return pt;
  }

  // you can specify your own root if necessary
  final FuiPoint toLocal (FuiPoint pt, FuiLayoutProps root=null) const pure nothrow @trusted @nogc {
    for (FuiLayoutProps it = cast(FuiLayoutProps)this; it !is null; it = it.parent) {
      pt.x -= it.pos.x;
      pt.y -= it.pos.y;
      if (it is root) break;
    }
    return pt;
  }

private:
  // internal housekeeping for layouter
  FuiLayoutProps[Orientation.max+1] groupHead;
  bool tempLineBreak;

final:
  void resetLayouterFlags () { pragma(inline, true); tempLineBreak = false; groupHead[] = null; }
}


// ////////////////////////////////////////////////////////////////////////// //
// you can set maximum dimesions by setting root panel maxSize
// visit `root` and it's children
private static void forEachItem (FuiLayoutProps root, scope void delegate (FuiLayoutProps it) dg) {
  void visitAll (FuiLayoutProps it) {
    while (it !is null) {
      dg(it);
      visitAll(it.firstChild);
      it = it.nextSibling;
    }
  }
  if (root is null || dg is null) return;
  dg(root);
  visitAll(root.firstChild);
}


void flexLayout (FuiLayoutProps aroot) {
  import std.algorithm : min, max;

  if (aroot is null) return;
  auto oparent = aroot.parent;
  auto onexts = aroot.nextSibling;
  aroot.parent = null;
  aroot.nextSibling = null;
  scope(exit) { aroot.parent = oparent; aroot.nextSibling = onexts; }
  auto mroot = aroot;

  // layout children in this item
  void layit() (FuiLayoutProps lp) {
    if (lp is null || !lp.visible) return;

    // cache values
    immutable bpadLeft = max(0, lp.padding.left);
    immutable bpadRight = max(0, lp.padding.right);
    immutable bpadTop = max(0, lp.padding.top);
    immutable bpadBottom = max(0, lp.padding.bottom);
    immutable bspc = max(0, lp.spacing);
    immutable hbox = (lp.orientation == FuiLayoutProps.Orientation.Horizontal);

    // widget can only grow, and while doing that, `maxSize` will be respected, so we don't need to fix it's size

    // layout children, insert line breaks, if necessary
    int curWidth = bpadLeft+bpadRight, maxW = bpadLeft+bpadRight, maxH = bpadTop+bpadBottom;
    FuiLayoutProps lastCIdx = null; // last processed item for the current line
    int lineH = 0; // for the current line
    int lineCount = 0;
    int lineMaxW = (lp.size.w > 0 ? lp.size.w : (lp.maxSize.w > 0 ? lp.maxSize.w : int.max));

    // unconditionally add current item to the current line
    void addToLine (FuiLayoutProps clp) {
      clp.tempLineBreak = false;
      curWidth += clp.size.w+(lastCIdx !is null && !lastCIdx.ignoreSpacing ? bspc : 0);
      lineH = max(lineH, clp.size.h);
      lastCIdx = clp;
    }

    // flush current line
    void flushLine () {
      if (lastCIdx is null) return;
      // mark last item as line break
      lastCIdx.tempLineBreak = true;
      // fix max width
      maxW = max(maxW, curWidth);
      // fix max height
      maxH += lineH+(lineCount ? lp.lineSpacing : 0);
      // restart line
      curWidth = bpadLeft+bpadRight;
      lastCIdx = null;
      lineH = 0;
      ++lineCount;
    }

    // put item, do line management
    void putItem (FuiLayoutProps clp) {
      int nw = curWidth+clp.size.w+(lastCIdx !is null && !lastCIdx.ignoreSpacing ? bspc : 0);
      // do we neeed to start a new line?
      if (nw <= lineMaxW) {
        // no, just put item into the current line
        addToLine(clp);
        return;
      }
      // yes, check if we have at least one item in the current line
      if (lastCIdx is null) {
        // alas, no items in the current line, put clp into it anyway
        addToLine(clp);
        // and flush line immediately
        flushLine();
      } else {
        // flush current line
        flushLine();
        // and add this item to new one
        addToLine(clp);
      }
    }

    // layout children, insert "soft" line breaks
    for (auto clp = lp.firstChild, cspc = 0; clp !is null; clp = clp.nextSibling) {
      if (!clp.visible) continue; // invisible, skip it
      layit(clp); // layout children of this box
      if (hbox) {
        // for horizontal box, logic is somewhat messy
        putItem(clp);
        if (clp.lineBreak) flushLine();
      } else {
        // for vertical box, it is as easy as this
        clp.tempLineBreak = true;
        maxW = max(maxW, clp.size.w+bpadLeft+bpadRight);
        maxH += clp.size.h+cspc;
        cspc = (clp.ignoreSpacing ? 0 : bspc);
        ++lineCount;
      }
    }
    if (hbox) flushLine(); // flush last line for horizontal box (it is safe to flush empty line)
    // fix max sizes
    if (lp.maxSize.w > 0 && maxW > lp.maxSize.w) maxW = lp.maxSize.w;
    if (lp.maxSize.h > 0 && maxH > lp.maxSize.h) maxH = lp.maxSize.h;

    // grow box or clamp max size
    // but only if size is not defined; in other cases our size is changed by parent to fit in
    if (lp.size.w == 0) lp.size.w = max(0, lp.minSize.w, maxW);
    if (lp.size.h == 0) lp.size.h = max(0, lp.minSize.h, maxH);
    // cache values
    maxH = lp.size.h;
    maxW = lp.size.w;

    int flexTotal; // total sum of flex fields
    int flexBoxCount; // number of boxes
    int curSpc; // "current" spacing in layout calculations (for bspc)
    int spaceLeft;

    if (hbox) {
      // layout horizontal box; we should do this for each line separately
      int lineStartY = bpadTop;

      void resetLine () {
        flexTotal = 0;
        flexBoxCount = 0;
        curSpc = 0;
        spaceLeft = maxW-(bpadLeft+bpadRight);
        lineH = 0;
      }

      auto lstart = lp.firstChild;
      int lineNum = 0;
      for (;;) {
        if (lstart is null) break;
        if (!lstart.visible) continue;
        // calculate flex variables and line height
        --lineCount; // so 0 will be "last line"
        assert(lineCount >= 0);
        resetLine();
        for (auto clp = lstart; clp !is null; clp = clp.nextSibling) {
          if (!clp.visible) continue;
          auto dim = clp.size.w+curSpc;
          spaceLeft -= dim;
          lineH = max(lineH, clp.size.h);
          // process flex
          if (clp.flex > 0) { flexTotal += clp.flex; ++flexBoxCount; }
          if (clp.tempLineBreak) break; // no more in this line
          curSpc = (clp.ignoreSpacing ? 0 : bspc);
        }
        if (lineCount == 0) lineH = max(lineH, maxH-bpadBottom-lineStartY-lineH);
        debug(fui_layout) { import core.stdc.stdio : printf; printf("lineStartY=%d; lineH=%d\n", lineStartY, lineH); }

        // distribute flex space, fix coordinates
        debug(fui_layout) { import core.stdc.stdio : printf; printf("flexTotal=%d; flexBoxCount=%d; spaceLeft=%d\n", flexTotal, flexBoxCount, spaceLeft); }
        if (spaceLeft < 0) spaceLeft = 0;
        float flt = cast(float)flexTotal;
        float left = cast(float)spaceLeft;
        //{ import iv.vfs.io; VFile("zlay.log", "a").writefln("flt=%s; left=%s", flt, left); }
        int curpos = bpadLeft;
        for (auto clp = lstart; clp !is null; clp = clp.nextSibling) {
          lstart = clp.nextSibling;
          if (!clp.visible) continue;
          // fix packing coordinate
          clp.pos.x = curpos;
          bool doChildrenRelayout = false;
          // fix non-packing coordinate (and, maybe, non-packing dimension)
          // fix y coord
          final switch (clp.aligning) {
            case FuiLayoutProps.Align.Start: clp.pos.y = lineStartY; break;
            case FuiLayoutProps.Align.End: clp.pos.y = (lineStartY+lineH)-clp.size.h; break;
            case FuiLayoutProps.Align.Center: clp.pos.y = lineStartY+(lineH-clp.size.h)/2; break;
            case FuiLayoutProps.Align.Stretch:
              clp.pos.y = lineStartY;
              int nd = min(max(0, lineH, clp.minSize.h), (clp.maxSize.h > 0 ? clp.maxSize.h : int.max));
              if (nd != clp.size.h) {
                // size changed, relayout children
                doChildrenRelayout = true;
                clp.size.h = nd;
              }
              break;
          }
          // fix flexbox size
          if (clp.flex > 0) {
            //{ import iv.vfs.io; write("\x07"); }
            int toadd = cast(int)(left*cast(float)clp.flex/flt+0.5);
            if (toadd > 0) {
              // size changed, relayout children
              doChildrenRelayout = true;
              clp.size.w += toadd;
              // compensate (crudely) rounding errors
              if (toadd > 1 && clp.size.w <= maxW && maxW-(curpos+clp.size.w) < 0) clp.size.w -= 1;
            }
          }
          // advance packing coordinate
          curpos += clp.size.w+(clp.ignoreSpacing ? 0 : bspc);
          // relayout children if dimensions was changed
          if (doChildrenRelayout) layit(clp);
          if (clp.tempLineBreak) break; // exit if we have linebreak
          // next line, please!
        }
        // yep, move to next line
        debug(fui_layout) { import core.stdc.stdio : printf; printf("lineStartY=%d; next lineStartY=%d\n", lineStartY, lineStartY+lineH+lp.lineSpacing); }
        lineStartY += lineH+lp.lineSpacing;
      }
    } else {
      // layout vertical box, it is much easier
      spaceLeft = maxH-(bpadTop+bpadBottom);
      if (spaceLeft < 0) spaceLeft = 0;

      // calculate flex variables
      for (auto clp = lp.firstChild; clp !is null; clp = clp.nextSibling) {
        if (!clp.visible) continue;
        auto dim = clp.size.h+curSpc;
        spaceLeft -= dim;
        // process flex
        if (clp.flex > 0) { flexTotal += clp.flex; ++flexBoxCount; }
        curSpc = (clp.ignoreSpacing ? 0 : bspc);
      }

      // distribute flex space, fix coordinates
      float flt = cast(float)flexTotal;
      float left = cast(float)spaceLeft;
      int curpos = bpadTop;
      for (auto clp = lp.firstChild; clp !is null; clp = clp.nextSibling) {
        if (!clp.visible) break;
        // fix packing coordinate
        clp.pos.y = curpos;
        bool doChildrenRelayout = false;
        // fix non-packing coordinate (and, maybe, non-packing dimension)
        // fix x coord
        final switch (clp.aligning) {
          case FuiLayoutProps.Align.Start: clp.pos.x = bpadLeft; break;
          case FuiLayoutProps.Align.End: clp.pos.x = maxW-bpadRight-clp.size.w; break;
          case FuiLayoutProps.Align.Center: clp.pos.x = (maxW-clp.size.w)/2; break;
          case FuiLayoutProps.Align.Stretch:
            int nd = min(max(0, maxW-(bpadLeft+bpadRight), clp.minSize.w), (clp.maxSize.w > 0 ? clp.maxSize.w : int.max));
            if (nd != clp.size.w) {
              // size changed, relayout children
              doChildrenRelayout = true;
              clp.size.w = nd;
            }
            clp.pos.x = bpadLeft;
            break;
        }
        // fix flexbox size
        if (clp.flex > 0) {
          int toadd = cast(int)(left*cast(float)clp.flex/flt);
          if (toadd > 0) {
            // size changed, relayout children
            doChildrenRelayout = true;
            clp.size.h += toadd;
            // compensate (crudely) rounding errors
            if (toadd > 1 && clp.size.h <= maxH && maxH-(curpos+clp.size.h) < 0) clp.size.h -= 1;
          }
        }
        // advance packing coordinate
        curpos += clp.size.h+(clp.ignoreSpacing ? bspc : 0);
        // relayout children if dimensions was changed
        if (doChildrenRelayout) layit(clp);
      }
      // that's all for vertical boxes
    }
  }

  // main code
  if (mroot is null) return;

  bool[FuiLayoutProps.Orientation.max+1] seenGroup = false;

  // reset flags, check if we have any groups
  forEachItem(mroot, (FuiLayoutProps it) {
    it.layoutingStarted();
    it.resetLayouterFlags();
    it.pos = it.pos.init;
    foreach (int gidx; 0..FuiLayoutProps.Orientation.max+1) if (it.groupNext[gidx] !is null) seenGroup[gidx] = true;
    if (!it.visible) { it.size = it.size.init; return; }
    it.size = it.size.init;
  });

  if (seenGroup[0] || seenGroup[1]) {
    // fix groups
    forEachItem(mroot, (FuiLayoutProps it) {
      foreach (int gidx; 0..FuiLayoutProps.Orientation.max+1) {
        if (it.groupNext[gidx] is null || it.groupHead[gidx] !is null) continue;
        // this item is group member, but has no head set, so this is new head: fix the whole list
        for (FuiLayoutProps gm = it; gm !is null; gm = gm.groupNext[gidx]) gm.groupHead[gidx] = it;
      }
    });
  }

  // do top-level packing
  for (;;) {
    layit(mroot);
    bool doFix = false;

    //FIXME: mark changed items and process only those
    void fixGroups (FuiLayoutProps it, int grp) nothrow @nogc {
      int dim = 0;
      // calcluate maximal dimension
      for (FuiLayoutProps clp = it; clp !is null; clp = clp.groupNext[grp]) {
        if (!clp.visible) continue;
        dim = max(dim, clp.size[grp]);
      }
      // fix dimensions
      for (FuiLayoutProps clp = it; clp !is null; clp = clp.groupNext[grp]) {
        if (!clp.visible) continue;
        auto od = clp.size[grp];
        int nd = max(od, dim);
        auto mx = clp.maxSize[grp];
        if (mx > 0) nd = min(nd, mx);
        version(none) {
          import core.stdc.stdio;
          auto fo = fopen("zlx.log", "a");
          //fo.fprintf("%.*s: od=%d; nd=%d\n", cast(uint)clp.classinfo.name.length, clp.classinfo.name.ptr, od, nd);
          fo.fprintf("gidx=%d; dim=%d; w=%d; h=%d\n", grp, dim, clp.size[0], clp.size[1]);
          fo.fclose();
        }
        if (od != nd) {
          doFix = true;
          clp.size[grp] = nd;
        }
      }
    }

    if (seenGroup[0] || seenGroup[1]) {
      forEachItem(mroot, (FuiLayoutProps it) {
        foreach (int gidx; 0..FuiLayoutProps.Orientation.max+1) {
          if (it.groupHead[gidx] is it) fixGroups(it, gidx);
        }
      });
      if (!doFix) break; // nothing to do
    } else {
      // no groups -> nothing to do
      break;
    }
  }

  // signal completions
  forEachItem(mroot, (FuiLayoutProps it) { it.layoutingComplete(); });
}


debug(flexlayout_dump) void dumpLayout() (FuiLayoutProps mroot, const(char)[] foname=null) {
  import core.stdc.stdio : stderr, fopen, fclose, fprintf;
  import std.internal.cstring;

  auto fo = (foname.length ? stderr : fopen(foname.tempCString, "w"));
  if (fo is null) return;
  scope(exit) if (foname.length) fclose(fo);

  void ind (int indent) { foreach (immutable _; 0..indent) fo.fprintf(" "); }

  void dumpItem() (FuiLayoutProps lp, int indent) {
    if (lp is null || !lp.visible) return;
    ind(indent);
    fo.fprintf("Ctl#%08x: position:(%d,%d); size:(%d,%d)\n", cast(uint)cast(void*)lp, lp.pos.x, lp.pos.y, lp.size.w, lp.size.h);
    for (lp = lp.firstChild; lp !is null; lp = lp.nextSibling) {
      if (!lp.visible) continue;
      dumpItem(lp, indent+2);
    }
  }

  dumpItem(mroot, 0);
}
