/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
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
module iv.olly.assembler /*is aliced*/;

import iv.alice;
import iv.olly.asm1;
import iv.olly.disasm2;


// ////////////////////////////////////////////////////////////////////////// //
class Assembler {
private:
  static struct Label {
    uint line; // index in lines
    uint addr; // 0: undefined
    string name;
  }
  Label[] labels;

  static struct Line {
    string str;
    uint srclnum;
    uint addr; // 0: undefined
    AsmModel am;
    ubyte[] databuf; // for "db" and such
  }
  Line[] lines;

  uint startpc;
  uint curpc;
  bool needMorePasses;
  bool assembled;
  uint linesSeen;

  bool isDataByte (uint addr) {
    foreach (const ref Line ln; lines) {
      if (ln.am.data && addr >= ln.addr && addr < ln.addr+ln.am.length) return true;
    }
    return false;
  }

  uint findLabelAddr (const(char)[] name) {
    foreach (const ref Label lbl; labels) {
      if (name == lbl.name) {
        if (lbl.addr == 0) {
          needMorePasses = true; // undefined label used, need more passes
          return curpc;
        }
        return lbl.addr;
      }
    }
    throw new Exception("undefined label");
  }

  void fixLabelAddr (uint lidx, uint addr) {
    foreach (ref Label lbl; labels) {
      if (lidx == lbl.line) {
        if (lbl.addr != addr) needMorePasses = true; // label address changed, need more passes
        lbl.addr = addr;
        //{ import std.stdio; writefln("label '%s' at 0x%08x", lbl.name, addr); }
      }
    }
  }

public:
  this (uint stpc) {
    if (stpc == 0) throw new Exception("invalid starting PC");
    startpc = curpc = stpc;
  }

  @property uint orgpc () const pure nothrow @safe @nogc { return startpc; }
  @property uint pc () const pure nothrow @safe @nogc { return curpc; }

  ubyte[] getCode () {
    if (!assembled) assemble();
    uint len = 0;
    foreach (const ref Line ln; lines) len += ln.am.length;
    auto res = new ubyte[](len);
    len = 0;
    foreach (const ref Line ln; lines) {
      if (ln.databuf.length) {
        res[len..len+ln.am.length] = ln.databuf[];
      } else {
        res[len..len+ln.am.length] = ln.am.code[0..ln.am.length];
      }
      len += ln.am.length;
    }
    assert(len == res.length);
    return res;
  }

  void addLabel (const(char)[] name, uint addr) {
    if (addr == 0) throw new Exception("invalid label address");
    if (name.length == 0) throw new Exception("invalid label name");
    foreach (const ref lbl; labels) if (lbl.name == name) throw new Exception("label '"~lbl.name~"' already defined");
    Label lbl;
    lbl.line = uint.max;
    lbl.addr = addr;
    lbl.name = name.idup;
    labels ~= lbl;
  }

  void addLabelHere (const(char)[] name) {
    if (name.length == 0) throw new Exception("invalid label name");
    foreach (const ref lbl; labels) if (lbl.name == name) throw new Exception("label '"~lbl.name~"' already defined");
    Label lbl;
    lbl.line = cast(uint)lines.length;
    lbl.addr = 0;
    lbl.name = name.idup;
    labels ~= lbl;
  }

  bool hasLabel (const(char)[] name) {
    foreach (const ref lbl; labels) if (lbl.name == name) return true;
    return false;
  }

  uint labelAddr (const(char)[] name) {
    foreach (const ref lbl; labels) if (lbl.name == name) return lbl.addr;
    throw new Exception("label '"~name.idup~"' not found");
  }

  void addLines(T : const(char)[]) (T s) {
    static if (!is(T == typeof(null))) {
      while (s.length > 0) {
        uint ep = 0;
        while (ep < s.length && s[ep] != '\n') ++ep;
        addLine(s[0..ep]);
        ++ep;
        if (ep >= s.length) break;
        s = s[ep..$];
      }
    }
  }

  private void addLine(T : const(char)[]) (T s) {
    ++linesSeen;
    static if (!is(T == typeof(null))) {
      import std.ascii : isAlpha, isAlphaNum;
      auto xs = s;
      while (xs.length > 0 && xs[0] <= ' ') xs = xs[1..$];
      if (xs.length == 0) return;
      if (xs[0] == ';') return;
      // is this a label?
      if (isAlpha(xs[0])) {
        uint pos = 0;
        while (pos < xs.length && isAlphaNum(xs[pos])) ++pos;
        auto ln = xs[0..pos];
        while (pos < xs.length && xs[pos] <= ' ') ++pos;
        if (pos < xs.length && xs[pos] == ':') {
          foreach (const ref lbl; labels) {
            if (lbl.name == ln) throw new Exception("label '"~lbl.name~"' already defined");
          }
          Label lbl;
          //{ import std.stdio; writeln("found label: [", ln, "]"); }
          lbl.line = cast(uint)lines.length;
          lbl.addr = 0;
          lbl.name = ln.idup;
          labels ~= lbl;
          if (++pos < xs.length) addLine(xs[pos..$]); // recursive, so allow many labels
          assembled = false;
          return;
        }
      }
      // save it
      if (lines.length >= int.max/2) throw new Exception("too many code lines");
      static if (is(T == string)) alias ss = s; else string ss = s.idup;
      //{ import std.stdio; writeln("*[", ss, "]"); }
      lines ~= Line(ss, linesSeen);
      assembled = false;
    }
  }

  // curpc is current pc ;-)
  private void asmLine (uint lidx) {
    // try to assemble it
    AsmModel lastgoodam;
    AsmModel am;
    AsmOptions opts;
    opts.ideal = true;
    char[256] errtext = 0;
    char[256] lasterrtext = 0;
    int lasterrpos = 1; // <=0: was error
    auto line = &lines[lidx];
    ubyte[] dbdata;

    if (curpc == 0) throw new Exception("invalid pc");
    fixLabelAddr(lidx, curpc);

    void throwError () {
      if (lasterrpos > 0) return;
      import core.stdc.stdio : stderr, fprintf;
      fprintf(stderr, "ERROR at line %u: %s\n", line.srclnum, lasterrtext.ptr);
      fprintf(stderr, "%.*s\n", cast(uint)line.str.length, line.str.ptr);
      foreach (immutable _; 0..-lasterrpos-1) fprintf(stderr, "^");
      fprintf(stderr, "^\n");
      throw new Exception("asm error");
    }

    // try all possible variants, choose shorter one
    int attempt = 0;
    lastgoodam.length = lastgoodam.length.max;
    mainloop: for (;; ++attempt) {
      // try each operand size
      int errcount = 0; // all 4 sizes gives an error? we are done
      foreach (immutable int csize; 0..4) {
        auto cmdlen = .assemble(line.str, curpc, &am, opts, attempt, csize, errtext[], &findLabelAddr, (uint addr, ubyte b) { dbdata ~= b; });
        if (cmdlen <= 0) {
          // error; if we have no previous command, and no previous error, register this one
          // we are using the fact that 0th attempt with 0th operand size should always produce an instruction
          if (lastgoodam.length == lastgoodam.length.max && lasterrpos > 0) {
            lasterrpos = cmdlen;
            lasterrtext[] = errtext[];
          }
          ++errcount;
          continue;
        }
        // if this is data command, don't go further
        if (am.data) { lastgoodam = am; break mainloop; }
        // good command, check if we should save it
        if (am.length >= lastgoodam.length) continue;
        // i found her!
        lastgoodam = am;
      }
      if (errcount == 4) break; // all 4 operand sizes gives us error, so no more commands can be found
    }
    throwError(); // if any
    // if command size of address was changed, we need yet another pass to stabilize the things
    if (line.addr != 0) {
      if (line.am.length != lastgoodam.length || line.addr != curpc) needMorePasses = true;
    }
    line.addr = curpc;
    line.am = lastgoodam;
    line.databuf = dbdata;
    curpc += lastgoodam.length;
  }

  private void asmPass () {
    needMorePasses = false;
    curpc = startpc;
    foreach (uint lidx; 0..cast(uint)lines.length) asmLine(lidx);
  }

  // we finished parsing, now assemble it
  void assemble () {
    if (assembled) return;
    bool firstPass = true;
    for (;;) {
      asmPass();
      // check if we still have undefined labels after first pass
      if (firstPass) {
        foreach (const ref Label lbl; labels) if (lbl.addr == 0) throw new Exception("undefined label '"~lbl.name~"'");
        firstPass = false;
      }
      if (!needMorePasses) break;
    }
  }

  uint dasmOne (const(void)[] code, uint ip, uint ofs) {
    // put labels
    foreach (const ref Label lbl; labels) {
      if (lbl.addr == ip+ofs) {
        import core.stdc.stdio : stderr, fprintf;
        fprintf(stderr, "0x%08x: %.*s:\n", ip+ofs, cast(uint)lbl.name.length, lbl.name.ptr);
      }
    }

    if (isDataByte(ip+ofs)) {
      import core.stdc.stdio : stderr, fprintf;
      ubyte b = (cast(const(ubyte)[])code)[ofs];
      if (b >= ' ' && b < 127) {
        fprintf(stderr, "0x%08x:   %02x%-14s db\t0x%02x  ; '%c'\n", ip+ofs, b, "".ptr, b, b);
      } else {
        fprintf(stderr, "0x%08x:   %02x%-14s db\t0x%02x\n", ip+ofs, b, "".ptr, b);
      }
      return 1;
    }
    DisasmData da;
    DAConfig cfg;
    cfg.tabarguments = true;
    auto len = disasm(code[ofs..$], ip+ofs, &da, DA_DUMP|DA_TEXT|DA_HILITE, &cfg, (uint addr) {
      foreach (const ref lbl; labels) if (lbl.addr == addr) return /*cast(const(char)[])*/lbl.name; // it is safe to cast here
      return null;
    });
    if (len == 0) throw new Exception("ERROR: "~disErrMessage(da.errors, da.warnings));
    {
      import core.stdc.stdio : stderr, fprintf;
      fprintf(stderr, "0x%08x:   %-16s %s\n", da.ip, da.dump.ptr, da.result.ptr);
    }
    return da.size;
  }

  void disasmCode (const(ubyte)[] code, uint orgpc) {
    uint ofs = 0;
    while (ofs < code.length) ofs += dasmOne(code, orgpc, ofs);
  }
}
