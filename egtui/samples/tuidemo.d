import iv.rawtty2;
import iv.strex;
import iv.vfs.io;

import iv.egtui;


enum laydsc = q{
  caption: "Test Dialog"
  small-frame: false
  // box with two buttons
  hbox: {
    flex: 0
    hspan // left span to push buttons to center
    button: {
      id: "btn0"
      caption: "button &0"
    }
    button: {
      flex: 1
      id: "btn1"
      caption: "button &1"
    }
    // right span to push buttons to center, line break
    hspan: { lineBreak: true }
    // right span to push buttons to right
    hspan
    button: {
      id: "btn2"
      caption: "long button &2"
      //clickMask: left
      doubleMask: left
    }
  }

  // horizontal box for the first text line
  hbox: {
    flex: 0
    label: {
      id: "lbl0"
      dest: "cb0"
      caption: `\R&first label: `
      hgroup: "lbl0"
      vgroup: "lbl0"
    }
    checkbox: {
      id: "cb0"
      caption: "checkbox for f&irst label"
      bind-var: cbval0
      hgroup: "cb0"
      vgroup: "lbl0"
    }
  }

  // horizontal box for the second text line
  hbox: {
    flex: 0
    label: {
      id: "lbl1"
      dest: "cb1"
      caption: `\R&second label: `
      hgroup: "lbl0"
      vgroup: "lbl0"
    }
    checkbox: {
      id: "cb1"
      caption: "checkbox for s&econd label"
      bind-var: cbval1
      bind-func: cb1action
      hgroup: "cb0"
      vgroup: "lbl0"
    }
  }

  // horizontal box for the third text line
  hbox: {
    flex: 0
    label: {
      id: "lbl2"
      dest: "rb0"
      caption: `\R&third label: `
      hgroup: "lbl0"
      vgroup: "lbl0"
    }
    radio: {
      id: "rb0"
      caption: "radio for third label"
      bind-var: rbval
      hgroup: "cb0"
      vgroup: "lbl0"
    }
  }

  // horizontal box for the fourth text line
  hbox: {
    flex: 0
    label: {
      id: "lbl3"
      dest: "rb1"
      caption: `\Rf&ourth label: `
      hgroup: "lbl0"
      vgroup: "lbl0"
    }
    radio: {
      id: "rb1"
      caption: "radio for fourth label"
      bind-var: rbval
      hgroup: "cb0"
      vgroup: "lbl0"
    }
  }

  hline

  // editor hbox
  hbox: {
    flex: 0
    align: expand # expand to eat all available horizontal space
    label: {
      caption: "in&put: "
      dest: "el0"
    }
    editline: {
      id: "el0"
      text: "defval"
      flex: 1
      bind-func: editchangecb
    }
  }

  hline

  // test panels
  hbox: {
    flex: 1
    align: expand # expand to eat all available horizontal space
    id: "hbx00"
    spacing: 0
    vbox: {
      flex: 1
      vpanel: {
        flex: 1
        align: expand # expand to eat all available horizontal space
        caption: "test panel"
        checkbox: { caption: "option 0" align: expand }
        checkbox: { caption: "option 1" align: expand }
      }
      vpanel: {
        flex: 1
        //align: expand # expand to eat all available horizontal space
        caption: "test panel"
        checkbox: { caption: "option 2" align: expand }
        checkbox: { caption: "option 3" align: expand }
      }
    }
    vpanel: {
      flex: 1
      align: expand # expand to eat all available horizontal space
      caption: "test panel"
      checkbox: { caption: "option 4" align: expand }
      checkbox: { caption: "option 5" align: expand }
    }
  }

  // horizontal box to push last line down
  //hbox: { flex: 1 }

  hline

  hbox: {
    spacing: 1
    vpanel: {
      textview: {
        id: "text0"
        text: "this is text view control\nit is not fully working now"
      }
    }
    listbox: {
      id: "lbox0"
      height: 6
      items: {
        "item #0"
        "item #1"
        "item #2"
        "item #3"
        "item #4"
        "item #5"
        "item #6"
        "item #7"
        "item #8"
        "item #9"
        "item #10"
        "item #11"
        "item #12"
      }
    }
  }

  hline

  // horizontal box for the last line
  hbox: {
    flex: 0
    // left span to push button to right
    hspan
    button: {
      flex: 0
      id: "btn3"
      caption: "last &long button"
      //clickMask |= FuiLayoutProps.Buttons.Left;
      doubleMask: left
      default
    }
  }
};


void showResult (FuiContext cc, int res) {
  enum reslay = q{
    caption: "Result"
    small-frame: false
    // hbox for label and text
    hbox: {
      label: { caption: "Result: " }
      label: { id: "res" caption: "$res <$id>" }
    }
    hline
    // center button
    hbox: {
      span: { flex: 1 }
      button: { caption: "&Close" }
      span: { flex: 1 }
    }
  };
  auto id = cc.itemId(res);

  auto ctx = FuiContext.create();
  ctx.tuiParse!(res, id)(reslay);
  ctx.relayout();

  ctx.modalDialog;
}


void main (string[] args) {
  if (ttyIsRedirected) assert(0, "no redirections, please");
  xtInit();
  if (ttyw < 24 || ttyh < 8) assert(0, "tty is too small");

  auto ctx = FuiContext.create();
  // layout controls in default root box to determine minimal dimenstions
  // but set maximal dimensions to our max window size
  //ctx.maxDimensions = FuiSize(ttyw, ttyh);

  if (args.length <= 1) {
    bool cbval0 = true;
    bool cbval1 = false;
    int rbval;

    void fixEnabledDisabled (FuiContext ctx) {
      ctx.setEnabled(ctx.findById("rb0"), cbval1);
      ctx.setEnabled(ctx.findById("rb1"), cbval1);
      ctx.setEnabled(ctx.findById("el0"), !cbval1);
      if (auto edl = ctx.itemAs!"editline"("el0")) {
        ctx.setEnabled(ctx.findById("btn3"), (edl.ed.textsize > 0));
      }
      { import core.memory : GC; GC.collect; GC.minimize; }
    }

    int cb1action (FuiContext ctx, int item) {
      //ttyBeep();
      fixEnabledDisabled(ctx);
      return -666; // or control id
    }

    int editchangecb (FuiContext ctx, int item) {
      //ttyBeep();
      fixEnabledDisabled(ctx);
      return -666;
    }

    ctx.tuiParse!(cbval0, cbval1, rbval, cb1action, editchangecb)(laydsc);
    ctx.relayout();
    debug(tui_dump) ctx.dumpLayout();
    //writeln(ctx.layprops(0).position.w, "x", ctx.layprops(0).position.h);
    //assert(0);

    fixEnabledDisabled(ctx);

    int itres = -666;

    auto ttymode = ttyGetMode();
    scope(exit) {
      ttyDisableBracketedPaste();
      normalScreen();
      ttySetMode(ttymode);
      writeln("result: ", itres);
      writeln("cbval0: ", cbval0);
      writeln("cbval1: ", cbval1);
      writeln("rbval: ", rbval);
    }
    ttySetRaw();
    altScreen();
    ttyEnableBracketedPaste();

    {
      xtSetFB(TtyRgb2Color!(0x00, 0x00, 0x00), TtyRgb2Color!(0x00, 0x5f, 0xaf)); // 0,25
      //xtSetFB(TtyRgb2Color!(0x60, 0x60, 0x60), 0);
      //xtSetFB(8, 0);
      xtFill!true(0, 0, ttyw, ttyh, 'a');
    }

    itres = ctx.modalDialog;

    showResult(ctx, itres);
  } else {
    auto fl = VFile(args[1]);
    auto buf = new char[](cast(int)fl.size);
    fl.rawReadExact(buf[]);

    ctx.tuiParse(buf);
    ctx.relayout();

    auto ttymode = ttyGetMode();
    scope(exit) {
      ttyDisableBracketedPaste();
      normalScreen();
      ttySetMode(ttymode);
    }
    ttySetRaw();
    altScreen();
    ttyEnableBracketedPaste();

    {
      xtSetFB(TtyRgb2Color!(0x00, 0x00, 0x00), TtyRgb2Color!(0x00, 0x5f, 0xaf)); // 0,25
      //xtSetFB(TtyRgb2Color!(0x60, 0x60, 0x60), 0);
      xtSetFB(8, 0);
      xtFill!true(0, 0, ttyw, ttyh, 'a');
    }

    ctx.modalDialog;
  }
}
