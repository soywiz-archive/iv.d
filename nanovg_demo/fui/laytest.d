import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;

import iv.nanovg.fui;


// ////////////////////////////////////////////////////////////////////////// //
struct Ctl {}


// ////////////////////////////////////////////////////////////////////////// //
void buildWindow0 (FuiContext ctx) {
  ctx.clear();
  // left box to push buttons to center
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
    }
  }
  // button
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
      minSize = FuiSize(64, 16);
    }
  }
  // button
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
      minSize = FuiSize(32, 18);
    }
  }
  // right box to push buttons to center
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void buildWindow1 (FuiContext ctx) {
  ctx.clear();
  with (ctx.layprops(0)) {
    padding.left = 1;
    padding.right = 8;
    padding.top = 4;
    padding.bottom = 6;
    spacing = 0;
    lineSpacing = 10;
  }
  // left box to push buttons to center
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
      visible = false;
    }
  }
  // button
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 0;
      minSize = FuiSize(64, 16);
    }
  }
  // button
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
      minSize = FuiSize(32, 18);
    }
  }
  // right box to push buttons to center
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
      visible = false;
    }
  }
  // line break
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 0;
      visible = false;
      lineBreak = true;
    }
  }
  // left box to push buttons to right
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 1;
      visible = false;
    }
  }
  // button
  {
    auto idx = ctx.addItem!Ctl();
    with (ctx.layprops(idx)) {
      flex = 0;
      minSize = FuiSize(42, 18);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  auto ctx = FuiContext.create();
  ctx.buildWindow1();

  ctx.relayout();
  debug ctx.dumpLayout();
  debug ctx.dumpLayoutBack();

  /*
  ctx.layprops(0).minSize = FuiSize(320, 200);
  ctx.relayout();
  debug ctx.dumpLayout();
  */
}
