import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;

import iv.nanovega.fui;


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
void buildWindow2 (FuiContext ctx) {
  ctx.clear();

  with (ctx.layprops(0)) {
    vertical = true;
    padding.left = 1;
    padding.right = 8;
    padding.top = 4;
    padding.bottom = 6;
    spacing = 0;
    lineSpacing = 1;
  }

  // horizontal box for the first two lines
  auto hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // left span to push buttons to center
    ctx.hspan(hbox);
    // button
    with (ctx.layprops(ctx.button(hbox, "button 0"))) {
      flex = 0;
      //minSize = FuiSize(64, 16);
    }
    // button
    ctx.button(hbox, "button 1");
    // right span to push buttons to center, line break
    with (ctx.layprops(ctx.hspan(hbox))) {
      lineBreak = true;
    }

    // left span to push buttons to right
    ctx.hspan(hbox);
    // button
    with (ctx.layprops(ctx.button(hbox, "long button 2"))) {
      flex = 0;
      //clickMask |= FuiLayoutProps.Buttons.Left;
      doubleMask |= FuiLayoutProps.Buttons.Left;
    }

  // horizontal box for the first text line
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // label
    auto lbl0 = ctx.label(hbox, "\x02first label:");
    with (ctx.layprops(lbl0)) {
      flex = 0;
      hgroup = lbl0;
      vgroup = lbl0;
    }
    // button
    auto but0 = ctx.button(hbox, "button for first label");
    with (ctx.layprops(but0)) {
      flex = 0;
      hgroup = but0;
      vgroup = lbl0;
    }

  // horizontal box for the second text line
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // label
    with (ctx.layprops(ctx.label(hbox, "\x02second label:"))) {
      flex = 0;
      hgroup = lbl0;
      vgroup = lbl0;
    }
    // button
    with (ctx.layprops(ctx.button(hbox, "button for second label"))) {
      flex = 0;
      hgroup = but0;
      vgroup = lbl0;
    }

  // horizontal box to push last line down
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 1;

  // horizontal box for the last line
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // left span to push button to right
    ctx.hspan(hbox);
    // button
    with (ctx.layprops(ctx.button(hbox, "last long button"))) {
      flex = 0;
      //clickMask |= FuiLayoutProps.Buttons.Left;
      doubleMask |= FuiLayoutProps.Buttons.Left;
    }
}


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  auto ctx = FuiContext.create();
  ctx.buildWindow2();
  ctx.layprops(0).maxSize = FuiSize(400, 300);

  ctx.relayout();
  debug ctx.dumpLayout();
  //debug ctx.dumpLayoutBack();
  auto sz = ctx.layprops(0).position.size;

  ctx.buildWindow2();
  ctx.layprops(0).minSize = sz;
  ctx.layprops(0).maxSize = ctx.layprops(0).minSize;
  ctx.relayout();
  debug ctx.dumpLayout();
}
