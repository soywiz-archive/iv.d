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
import iv.strex;
import iv.vfs.io;

import iv.rawtty;
import iv.egtui;
import iv.egtui.utils;


// ///////////////////////////////////////////////////////////////////////// //
final class Parser {
public:
  VFile fl;
  char curCh = ' ', peekCh = ' ';
  int linenum;

public:
  this (VFile afl) {
    fl = afl;
    // load first chars
    nextChar();
    nextChar();
    linenum = 1;
  }

  void nextChar () {
    if (curCh == '\n') ++linenum;
    if (peekCh) {
      curCh = peekCh;
      if (fl.rawRead((&peekCh)[0..1]).length) {
        if (peekCh == 0) peekCh = ' ';
      } else {
        peekCh = 0;
      }
    } else {
      curCh = peekCh = 0;
    }
  }

  void skipBlanks () {
    while (curCh) {
      if ((curCh == '/' && peekCh == '/') || curCh == '#') {
        while (curCh && curCh != '\n') nextChar();
      } else if (curCh == '/' && peekCh == '*') {
        nextChar();
        nextChar();
        while (curCh) {
          if (curCh == '*' && peekCh == '/') {
            nextChar();
            nextChar();
            break;
          }
        }
      } else if (curCh == '/' && peekCh == '+') {
        nextChar();
        nextChar();
        int level = 1;
        while (curCh) {
          if (curCh == '+' && peekCh == '/') {
            nextChar();
            nextChar();
            if (--level == 0) break;
          } else if (curCh == '/' && peekCh == '+') {
            nextChar();
            nextChar();
            ++level;
          }
        }
      } else if (curCh > ' ') {
        break;
      } else {
        nextChar();
      }
    }
  }

  void error (string msg) { import std.conv : to; throw new Exception(msg~" around line "~linenum.to!string); }

  void expectChar (char ch) {
    skipBlanks();
    if (curCh != ch) error("'"~ch~"' expected");
    nextChar();
  }

  void skipComma () {
    skipBlanks();
    if (curCh == ',') nextChar();
  }

  static bool isGoodIdChar (char ch) pure nothrow @safe @nogc {
    return
      (ch >= '0' && ch <= '9') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_' || ch == '-' || ch == '+' || ch == '.';
  }

  static int digitInBase (char ch, int base=10) pure nothrow @trusted @nogc {
    pragma(inline, true);
    return
      base >= 1 && ch >= '0' && ch < '0'+base ? ch-'0' :
      base > 10 && ch >= 'A' && ch < 'A'+base-10 ? ch-'A'+10 :
      base > 10 && ch >= 'a' && ch < 'a'+base-10 ? ch-'a'+10 :
      -1;
  }

  void expectId (string eid) {
    auto id = getId;
    if (id != eid) error("'"~eid~"' expected, but got '"~id~"'");
  }

  bool getBool () {
    bool res;
    skipBlanks();
    if (curCh == 't' || curCh == 'T') {
      nextChar();
      if (curCh != 'r' && curCh != 'R') error("boolean expected");
      nextChar();
      if (curCh != 'u' && curCh != 'U') error("boolean expected");
      nextChar();
      if (curCh != 'e' && curCh != 'E') error("boolean expected");
      nextChar();
      res = true;
    } else if (curCh == 'f' || curCh == 'F') {
      nextChar();
      if (curCh != 'a' && curCh != 'A') error("boolean expected");
      nextChar();
      if (curCh != 'l' && curCh != 'L') error("boolean expected");
      nextChar();
      if (curCh != 's' && curCh != 'S') error("boolean expected");
      nextChar();
      if (curCh != 'e' && curCh != 'E') error("boolean expected");
      nextChar();
      res = false;
    } else error("boolean expected");
    if (isGoodIdChar(curCh)) error("boolean expected");
    return res;
  }

  int getInt () {
    skipBlanks();
    bool neg = false;
    if (curCh == '-') { neg = true; nextChar(); }
    if (digitInBase(curCh) < 0) error("integer expected");
    int n = 0;
    for (;;) {
      int d = digitInBase(curCh);
      if (d < 0) break;
      n = n*10+d;
      nextChar();
    }
    if (isGoodIdChar(curCh)) error("boolean expected");
    if (neg) n = -n;
    return n;
  }

  float getFloat () {
    skipBlanks();
    bool neg = false;
    if (curCh == '-') { neg = true; nextChar(); }
    if (curCh != '.' && digitInBase(curCh) < 0) error("number expected");
    float n = 0;
    for (;;) {
      int d = digitInBase(curCh);
      if (d < 0) break;
      n = n*10+d;
      nextChar();
    }
    if (curCh == '.') {
      float div = 1;
      nextChar();
      for (;;) {
        int d = digitInBase(curCh);
        if (d < 0) break;
        div /= 10;
        n += d*div;
        nextChar();
      }
    }
    if (isGoodIdChar(curCh)) error("boolean expected");
    if (neg) n = -n;
    return n;
  }

  string getId () {
    skipBlanks();
    char[] buf;
    if (curCh == '"') {
      nextChar();
      while (curCh != '"') {
        if (curCh == '\\') {
          char ch;
          nextChar();
          if (curCh == 0) error("unexpected end of data");
          switch (curCh) {
            case 't': ch = '\t'; nextChar(); break;
            case 'r': ch = '\r'; nextChar(); break;
            case 'n': ch = '\n'; nextChar(); break;
            default:
              if ((curCh >= 'A' && curCh <= 'Z') ||
                  (curCh >= 'a' && curCh <= 'z') ||
                  (curCh >= '0' && curCh <= '9')) error("invalid escape");
              ch = curCh;
              nextChar();
              break;
          }
          buf ~= ch;
        } else {
          buf ~= curCh;
        }
        nextChar();
      }
      if (curCh != '"') error("quote expected");
      nextChar();
    } else {
      if (!isGoodIdChar(curCh)) error("identifier or number expected");
      while (isGoodIdChar(curCh)) {
        //if (bpos >= buf.length) error("identifier or number too long");
        buf ~= curCh;
        nextChar();
      }
    }
    return cast(string)buf; // safe cast
  }
}


// ///////////////////////////////////////////////////////////////////////// //
struct Suit {
  string klass;
  string itemId;
  string itemType;
  string name;
  string shortName;
  string description;
  string iconId;
  bool consumable;
  float shield;
  float armor;
  float rechargeTime;
  float buyValue;
  float sellValue;
  int[string] attrs;
}

bool[string] attrnames;

Suit[] parseSuits () {
  import std.file : readText;
  auto p = new Parser(VFile("suits.json"));
  p.expectChar('{');
  p.expectId("itemList");
  p.expectChar(':');
  p.expectChar('[');
  Suit[] res;
  for (;;) {
    p.skipBlanks();
    if (p.curCh == ']') break;
    Suit s;
    p.expectChar('{');
    for (;;) {
      p.skipBlanks();
      if (p.curCh == '}') break;
      auto nm = p.getId;
      p.expectChar(':');
      switch (nm) {
        case "class": s.klass = p.getId; break;
        case "itemId": s.itemId = p.getId; break;
        case "itemType": s.itemType = p.getId; break;
        case "name": s.name = p.getId; break;
        case "shortName": s.shortName = p.getId; break;
        case "description": s.description = p.getId.xstrip; break;
        case "iconId": s.iconId = p.getId; break;
        case "consumable": s.consumable = p.getBool; break;
        case "shield": s.shield = p.getFloat; break;
        case "armor": s.armor = p.getFloat; break;
        case "rechargeTime": s.rechargeTime = p.getFloat; break;
        case "buyValue": s.buyValue = p.getFloat; break;
        case "sellValue": s.sellValue = p.getFloat; break;
        case "attributes":
          p.expectChar('[');
          for (;;) {
            p.skipBlanks();
            if (p.curCh == ']') break;
            p.expectChar('{');
            string name;
            int amount = int.min;
            for (;;) {
              p.skipBlanks();
              if (p.curCh == '}') break;
              auto n = p.getId;
              p.expectChar(':');
                   if (n == "attribute") name = p.getId;
              else if (n == "amount") amount = p.getInt;
              else assert(0, "unknown field: '"~n~"'");
              p.skipComma();
            }
            p.expectChar('}');
            p.skipComma();
            if (name.length == 0 || amount == int.min) p.error("wtf?!");
            s.attrs[name] = amount;
            attrnames[name] = true;
          }
          p.expectChar(']');
          break;
        default: assert(0, "unknown field: '"~nm~"'");
      }
      p.skipComma();
    }
    if (s.description.length == 0) s.description = "No description.";
    res ~= s;
    p.expectChar('}');
    p.skipComma();
  }
  p.expectChar(']');
  p.skipComma();
  p.expectChar('}');
  return res;
}


void suitDialog (Suit[] suits) {
  auto ctx = FuiContext.create();

  enum laydesc = q{
    caption: "Known Suits"
    small-frame: false
    min-width: 90

    listbox: {
      id: "lbsuit"
      flex: 1
      align: expand
      on-action: onSuitChange
      max-width: $lbwdt
      max-height: $lbhgt
    }

    hline

    hbox: {
      span

      vbox: {
        hbox: {
          label: { id: "lbattr0name" caption: `\Ragility:` hgroup: "lbattr0name" }
          label: { id: "lbattr0" width: 5 }
        }
        hbox: {
          label: { id: "lbattr1name" caption: `\Raiming:` hgroup: "lbattr0name" }
          label: { id: "lbattr1" width: 5 }
        }
        hbox: {
          label: { id: "lbattr2name" caption: `\Rhealth:` hgroup: "lbattr0name" }
          label: { id: "lbattr2" width: 5 }
        }
      }

      vbox: {
        hbox: {
          label: { id: "lbxxx0name" caption: `\Rshield:` hgroup: "lbxxx0name" }
          label: { id: "lbshield" width: 5  caption: "0" }
        }
        hbox: {
          label: { id: "lbxxx1name" caption: `\Rarmor:` hgroup: "lbxxx0name" }
          label: { id: "lbarmor" width: 5 }
        }
        hbox: {
          label: { id: "lbxxx2name" caption: `\Rrecharge:` hgroup: "lbxxx0name" }
          label: { id: "lbrecharge" width: 5 }
        }
      }

      span
    }

    hline

    custombox: {
      id: "dscbox"
      flex: 0
      align: expand
      on-draw: onDescDraw
      height: 8  // this is max height for description box, due to overall window height and lbsuit height
    }
  };


  int onSuitChange (FuiContext ctx, int item) {
    import std.conv : to;
    int it = ctx.listboxItemCurrent(ctx["lbsuit"]);
    ctx.setCaption(ctx["lbattr0"], "0");
    ctx.setCaption(ctx["lbattr1"], "0");
    ctx.setCaption(ctx["lbattr2"], "0");
    ctx.setCaption(ctx["lbshield"], suits[it].shield.to!string);
    ctx.setCaption(ctx["lbarmor"], suits[it].armor.to!string);
    ctx.setCaption(ctx["lbrecharge"], suits[it].rechargeTime.to!string);
    if (auto vp = "Agility" in suits[it].attrs) ctx.setCaption(ctx["lbattr0"], to!string(*vp));
    if (auto vp = "Aiming" in suits[it].attrs) ctx.setCaption(ctx["lbattr1"], to!string(*vp));
    if (auto vp = "Health" in suits[it].attrs) ctx.setCaption(ctx["lbattr2"], to!string(*vp));
    // resize text area
    if (auto lp = ctx.layprops(ctx["dscbox"])) {
      int cols, lines;
      calcTextBounds(cols, lines, suits[it].description, lp.position.w);
      if (lines == 0) lines = 1;
      if (lines != lp.minSize.h) {
        auto rlp = ctx.layprops(0);
        rlp.minSize = rlp.maxSize = rlp.position.size;
        lp.minSize.h = lp.maxSize.h = lines;
        ctx.relayout();
        ctx.listboxNormPage(item);
      }
    }
    return -666; // or control id
  }

  void onDescDraw (FuiContext ctx, int item, FuiRect rc) {
    int it = ctx.listboxItemCurrent(ctx["lbsuit"]);
    auto win = XtWindow(rc.x, rc.y, rc.w, rc.h);
    win.color = ctx.palColor!"def"(item);
    //win.bg = 1;
    win.fill(0, 0, rc.w, rc.h);
    int cols, lines;
    calcTextBounds(cols, lines, suits[it].description, rc.w,
      (x, y, s) {
        win.writeStrAt(x, y, s);
      }
    );
  }

  int lbwdt = ttyw-12;
  int lbhgt = ttyh-20;

  ctx.parse!(lbwdt, lbhgt, onSuitChange, onDescDraw)(laydesc);

  foreach (const ref s; suits) {
    ctx.listboxItemAdd(ctx["lbsuit"], s.name); // shortName
  }

  ctx.relayout();
  onSuitChange(ctx, ctx["lbsuit"]);

  auto ttymode = ttyGetMode();
  scope(exit) {
    normalScreen();
    ttySetMode(ttymode);
  }
  ttySetRaw();
  altScreen();

  {
    xtSetFB(TtyRgb2Color!(0x00, 0x00, 0x00), TtyRgb2Color!(0x00, 0x5f, 0xaf)); // 0,25
    //xtSetFB(TtyRgb2Color!(0x60, 0x60, 0x60), 0);
    //xtSetFB(8, 0);
    xtFill!true(0, 0, ttyw, ttyh, 'a');
  }

  ctx.modalDialog;
}


void main () {
  if (ttyIsRedirected) assert(0, "no redirections, please");
  xtInit();
  if (ttyw < 96 || ttyh < 26) assert(0, "tty is too small");

  import std.algorithm : sort;
  auto suits = parseSuits();
  writeln(suits.length, " suits found");
  writeln(attrnames.length, " attributes");
  foreach (string n; attrnames.keys.sort) writeln("  ", n);

  suitDialog(suits);
}
/*
{
  "itemList" : [
    {
      "class" : "Suit",
      "itemId" : "scoutSuit03",
      "itemType" : "Suit",
      "name" : "Scout Suit MK-III",
      "shortName" : "Scout III",
      "description" : "Scout Suits MK-III were developed for fast moving scouting troops. By utilising the latest in shield technology these suits are light and don't rely on heavy armor materials.",
      "iconId" : "scoutSuit",
      "consumable" : false,
      "shield" : 16,
      "armor" : 0.1,
      "rechargeTime" : 4,
      "buyValue" : 540,
      "sellValue" : 30,
      "attributes" : [
        {
          "attribute" : "Agility",
          "amount" : 1
        },
        {
          "attribute" : "Aiming",
          "amount" : 1
        }
      ]
*/
