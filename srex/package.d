/*
 * Copyright 2012 Yichun "agentzh" Zhang
 * Copyright 2007-2009 Russ Cox.  All Rights Reserved.
 * Use of this source code is governed by a BSD-style
 *
 * Part of this code is from the NGINX opensource project: http://nginx.org/LICENSE
 *
 * This library is licensed under the BSD license.
 *
 * Copyright (c) 2012-2014 Yichun "agentzh" Zhang.
 *
 * Copyright (c) 2007-2009 Russ Cox, Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *    * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *    * Neither the name of Google, Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module iv.srex;
private:

// ///////////////////////////////////////////////////////////////////////// //
/// status code
public enum {
  SRE_OK       = 0, ///
  SRE_ERROR    = -1, ///
  SRE_AGAIN    = -2, ///
  SRE_BUSY     = -3, ///
  SRE_DONE     = -4, ///
  SRE_DECLINED = -5, ///
}

/// regex flags
public enum Flags : uint {
  CaseInsensitive = (1<<0), ///
}


public struct RegExp {
private:
  MemPool pool; // first member is RegExpPart
  int count, capcount;
  Program* reprg; // it always points to pool

public:
  string lastError;
  int lastErrorPos;

public:
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (count > 0); }

  static RegExp create(R) (auto ref R rng) if (isInputRange!R && is(ElementEncodingType!R : char)) {
    RegExp res;
    res.compile(rng);
    return res;
  }

  bool compile (R) (auto ref R rng) if (isInputRange!R && is(ElementEncodingType!R : char)) {
    if (!pool.active) pool = MemPool.create;
    if (pool.active) {
      pool.clear();
      auto re = parseRegExp(rng, pool, lastError, lastErrorPos);
      if (re is null) { pool = pool.init; return false; } // free pool and exit
      auto prgpool = MemPool.create;
      if (!prgpool.active) { pool = pool.init; lastError = "compile error"; lastErrorPos = 0; return false; } // free pool and exit
      auto prg = reCompile(prgpool, re);
      if (prg is null) { pool = pool.init; lastError = "compile error"; lastErrorPos = 0; return false; } // free pool and exit
      debug(srex) prg.dump;
      count = re.nregexes;
      capcount = re.multi_ncaps[0];
      pool = prgpool;
      reprg = prg;
      return true;
    }
    lastError = "memory error";
    lastErrorPos = 0;
    reprg = null;
    count = capcount = 0;
    return false;
  }

  @property int reCount () const @safe { pragma(inline, true); return count; }
  // `captureCount` returns total number, including capture $0 for whole regex
  @property int captureCount () const @trusted { pragma(inline, true); return capcount+1; }
}


// ///////////////////////////////////////////////////////////////////////// //
// optimize this: allocate on demand
Exception reParseError;
static this () { reParseError = new Exception(""); }


bool isWordChar (char c) pure nothrow @safe @nogc {
  pragma(inline, true);
  return
    (c >= '0' && c <= '9') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= 'a' && c <= 'z') ||
    c == '_';
}


// ////////////////////////////////////////////////////////////////////////// //
// parser
struct REParser {
  static immutable char[2] esc_d_ranges = [ '0', '9' ];
  static immutable char[4] esc_D_ranges = [ 0, '0'-1, '9'+1, 255 ];
  static immutable char[8] esc_w_ranges = [ 'A', 'Z', 'a', 'z', '0', '9', '_', '_' ];
  static immutable char[10] esc_W_ranges = [ 0, 47, 58, 64, 91, 94, 96, 96, 123, 255 ];
  static immutable char[10] esc_s_ranges = [ ' ', ' ', '\f', '\f', '\n', '\n', '\r', '\r', '\t', '\t' ];
  static immutable char[8] esc_S_ranges = [ 0, 8, 11, 11, 14, 31, 33, 255 ];
  static immutable char[6] esc_h_ranges = [ 0x09, 0x09, 0x20, 0x20, 0xa0, 0xa0 ];
  static immutable char[8] esc_H_ranges = [ 0x00, 0x08, 0x0a, 0x1f, 0x21, 0x9f, 0xa1, 0xff ];
  static immutable char[10] esc_v_ranges = [ 0x0a, 0x0a, 0x0b, 0x0b, 0x0c, 0x0c, 0x0d, 0x0d, 0x85, 0x85 ];
  static immutable char[6] esc_V_ranges = [ 0x00, 0x09, 0x0e, 0x84, 0x86, 0xff ];
  static immutable char[4] esc_N_ranges = [ 0, '\n'-1, '\n'+1, 255 ];

  static bool isdigit (int ch) pure nothrow @safe @nogc { return (ch >= '0' && ch <= '9'); }
  static bool isalpha (int ch) pure nothrow @safe @nogc { return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z'); }
  static bool isalnum (int ch) pure nothrow @safe @nogc { return (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z'); }
  static int digitInBase (char ch, int base=10) pure nothrow @trusted @nogc {
    pragma(inline, true);
    return
      base >= 1 && ch >= '0' && ch < '0'+base ? ch-'0' :
      base > 10 && ch >= 'A' && ch < 'A'+base-10 ? ch-'A'+10 :
      base > 10 && ch >= 'a' && ch < 'a'+base-10 ? ch-'a'+10 :
      -1;
  }

  enum int EOF = -1;

  MemPool pool;
  int yytok;
  int ncaps;
  uint flags;
  int delegate () nextch; // -1 on EOL

  string errmsg;
  int errpos = -1; // valid only if error was thrown
  alias curpos = errpos;

  this (scope int delegate () anextch) {
    nextch = anextch;
  }

  void nextToken () {
    if (yytok >= 0) {
      ++errpos;
      yytok = nextch();
      if (yytok < 0) yytok = -1;
    }
  }

  void fail (string msg, int ep=-1) { errmsg = msg; if (ep >= 0) errpos = ep; throw reParseError; }

  T* memoryfail(T) (T* p) {
    if (p is null) { errmsg = "out of memory"; throw reParseError; }
    return p;
  }

  RegExpPart* buildRange (const(char)[] rng, bool normal) {
    auto yyl = memoryfail(pool.reCreate((normal ? RegExpPart.Type.Class : RegExpPart.Type.NClass), null, null));
    RERange* last;
    foreach (immutable idx; 0..rng.length/2) {
      auto range = memoryfail(pool.alloc!RERange);
      range.from = rng[idx*2];
      range.to = rng[idx*2+1];
      if (last is null) yyl.range = range; else last.next = range;
      last = range;
    }
    return yyl;
  }

  RegExpPart* metaAssert (RegExpPart.AssType att) {
    auto yyl = memoryfail(pool.reCreate(RegExpPart.Type.Assert, null, null));
    yyl.assertion = att;
    return yyl;
  }

  RegExpPart* metaLit (char ch) {
    auto yyl = memoryfail(pool.reCreate(RegExpPart.Type.Lit, null, null));
    yyl.ch = ch;
    return yyl;
  }

  RegExpPart* parseAtom () {
    if (yytok == '{' || yytok == '}' || yytok == '|') fail("invalid regexp special char");

    if (yytok == '(') {
      nextToken();
      auto stp = curpos;
      int gnum = -1;
      if (yytok == '?') {
        nextToken();
        if (yytok != ':') fail("':' expected in anonymous group");
        nextToken();
      } else {
        gnum = ++ncaps;
      }
      auto yyl = parseAlt();
      if (yytok != ')') fail("unclosed group", stp);
      nextToken();
      if (gnum >= 0) {
        yyl = memoryfail(pool.reCreate(RegExpPart.Type.Paren, yyl, null));
        yyl.group = gnum;
      }
      return yyl;
    }

    if (yytok == '.') {
      auto yyl = memoryfail(pool.reCreate(RegExpPart.Type.Dot, null, null));
      nextToken();
      return yyl;
    }

    if (yytok == '^') {
      auto yyl = metaAssert(RegExpPart.AssType.Bol);
      nextToken();
      return yyl;
    }

    if (yytok == '$') {
      auto yyl = metaAssert(RegExpPart.AssType.Eol);
      nextToken();
      return yyl;
    }

    if ((flags&Flags.CaseInsensitive) && isalpha(yytok)) {
      auto yyl = memoryfail(pool.reCreate(RegExpPart.Type.Class, null, null));
      yyl.range = memoryfail(pool.alloc!RERange);
      yyl.range.from = cast(char)yytok;
      yyl.range.to = cast(char)yytok;
      yyl.range.next = memoryfail(pool.alloc!RERange);
      if (yytok <= 'Z') {
        // upper case
        yyl.range.next.from = cast(char)(yytok+32);
        yyl.range.next.to = cast(char)(yytok+32);
      } else {
        // lower case
        yyl.range.next.from = cast(char)(yytok-32);
        yyl.range.next.to = cast(char)(yytok-32);
      }
      yyl.range.next.next = null;
      return yyl;
    }

    if (yytok == '\\') {
      RegExpPart* yyl;
      // meta
      nextToken();
      auto mt = yytok;
      nextToken();
      switch (mt) {
        case EOF: fail("metachar expected"); break;
        case 'B': yyl = metaAssert(RegExpPart.AssType.NonWord); break;
        case 'b': yyl = metaAssert(RegExpPart.AssType.Word); break;
        case 'z': yyl = metaAssert(RegExpPart.AssType.StreamEnd); break;
        case 'A': yyl = metaAssert(RegExpPart.AssType.StreamStart); break;
        case 'd': yyl = buildRange(esc_d_ranges, true); break;
        case 'D': yyl = buildRange(esc_d_ranges, false); break;
        case 'w': yyl = buildRange(esc_w_ranges, true); break;
        case 'W': yyl = buildRange(esc_w_ranges, false); break;
        case 's': yyl = buildRange(esc_s_ranges, true); break;
        case 'S': yyl = buildRange(esc_s_ranges, false); break;
        case 'N': // \N is defined as [^\n]
          yyl = memoryfail(pool.reCreate(RegExpPart.Type.NClass, null, null));
          auto range = memoryfail(pool.alloc!RERange);
          range.from = '\n';
          range.to = '\n';
          range.next = null;
          yyl.range = range;
          break;
        case 'C': yyl = memoryfail(pool.reCreate(RegExpPart.Type.Dot, null, null)); break; // \C is defined as .
        case 'h': yyl = buildRange(esc_h_ranges, true); break;
        case 'H': yyl = buildRange(esc_h_ranges, false); break;
        case 'v': yyl = buildRange(esc_v_ranges, true); break;
        case 'V': yyl = buildRange(esc_v_ranges, false); break;
        case 't': yyl = metaLit('\t'); break;
        case 'n': yyl = metaLit('\n'); break;
        case 'r': yyl = metaLit('\r'); break;
        case 'f': yyl = metaLit('\f'); break;
        case 'a': yyl = metaLit('\a'); break;
        case 'e': yyl = metaLit('\x1b'); break;
        case 'x':
          nextToken();
          if (yytok < 0 || yytok > 255) fail("invalid meta");
          int n = digitInBase(cast(char)yytok, 16);
          if (n < 0) fail("invalid meta");
          nextToken();
          if (yytok >= 0 && yytok <= 255 && digitInBase(cast(char)yytok, 16)) {
            n = n*16+digitInBase(cast(char)yytok, 16);
            nextToken();
          }
          yyl = metaLit(cast(char)n);
          break;
        default: // other non-char escapes are literal
          if (isalnum(mt)) fail("invalid meta");
          yyl = metaLit(cast(char)mt);
          break;
      }
      if (yyl is null) fail("wtf?!");
      if (flags&Flags.CaseInsensitive) {
        if (yyl.type == RegExpPart.Type.Class || yyl.type == RegExpPart.Type.NClass) {
          yyl.range = memoryfail(range2CI(pool, yyl.range));
        }
      }
      return yyl;
    }

    if (yytok == '[') {
      // range
      auto stp = curpos;
      nextToken();
      if (yytok == EOF) fail("invalid range", stp);
      auto type = RegExpPart.Type.Class;
      if (yytok == '^') { type = RegExpPart.Type.NClass; nextToken(); }
      if (yytok == ']') fail("empty ranges are not supported", stp);
      bool[256] chars = false;
      while (yytok != ']') {
        char litch;
        bool islit = false;
        bool isrange = false;
        if (yytok == EOF) fail("invalid range", stp);
        if (yytok == '\\') {
          nextToken();
          if (yytok == EOF) fail("invalid range", stp);
          switch (yytok) {
            case 't': litch = '\t'; islit = true; break;
            case 'n': litch = '\n'; islit = true; break;
            case 'r': litch = '\r'; islit = true; break;
            case 'f': litch = '\f'; islit = true; break;
            case 'a': litch = '\a'; islit = true; break;
            case 'e': litch = '\x1b'; islit = true; break;
            case 'd':
            case 'D':
            case 's':
            case 'S':
            case 'N':
            case 'w':
            case 'W':
            case 'h':
            case 'H':
            case 'v':
            case 'V':
              isrange = true;
              break;
            case 'x':
              nextToken();
              if (yytok < 0 || yytok > 255) fail("invalid meta");
              int n = digitInBase(cast(char)yytok, 16);
              if (n < 0) fail("invalid meta");
              nextToken();
              if (yytok >= 0 && yytok <= 255 && digitInBase(cast(char)yytok, 16)) {
                n = n*16+digitInBase(cast(char)yytok, 16);
                nextToken();
              }
              litch = cast(char)n;
              islit = true;
              break;
            default:
              if (isalnum(yytok)) fail("invalid escape");
              litch = cast(char)yytok;
              islit = true;
              break;
          }
        } else {
          islit = true;
          litch = cast(char)yytok;
        }
        if (isrange) {
          const(char)[] rng;
          switch (yytok) {
            case 'd': rng = esc_d_ranges; break;
            case 'D': rng = esc_D_ranges; break;
            case 's': rng = esc_s_ranges; break;
            case 'S': rng = esc_S_ranges; break;
            case 'N': rng = esc_N_ranges; break;
            case 'w': rng = esc_w_ranges; break;
            case 'W': rng = esc_W_ranges; break;
            case 'h': rng = esc_h_ranges; break;
            case 'H': rng = esc_H_ranges; break;
            case 'v': rng = esc_v_ranges; break;
            case 'V': rng = esc_V_ranges; break;
            default: assert(0);
          }
          nextToken(); // skip range type
          foreach (immutable idx; 0..rng.length/2) {
            chars[rng[idx*2+0]..rng[idx*2+1]+1] = true;
          }
          if (yytok == '-') fail("no metaranges, please");
          continue;
        }
        nextToken(); // skip literal
        if (yytok != '-') {
          chars[litch] = true;
          continue;
        }
        nextToken(); // skip minus
        if (yytok == EOF) fail("invalid range", stp);
        char ech;
        bool lxc = false;
        if (yytok == '\\') {
          nextToken();
          if (yytok == EOF) fail("invalid range", stp);
          switch (yytok) {
            case 't': ech = '\t'; lxc = true; break;
            case 'n': ech = '\n'; lxc = true; break;
            case 'r': ech = '\r'; lxc = true; break;
            case 'f': ech = '\f'; lxc = true; break;
            case 'a': ech = '\a'; lxc = true; break;
            case 'e': ech = '\x1b'; lxc = true; break;
            case 'd':
            case 'D':
            case 's':
            case 'S':
            case 'N':
            case 'w':
            case 'W':
            case 'h':
            case 'H':
            case 'v':
            case 'V':
              break;
            case 'x':
              nextToken();
              if (yytok < 0 || yytok > 255) fail("invalid meta");
              int n = digitInBase(cast(char)yytok, 16);
              if (n < 0) fail("invalid meta");
              nextToken();
              if (yytok >= 0 && yytok <= 255 && digitInBase(cast(char)yytok, 16)) {
                n = n*16+digitInBase(cast(char)yytok, 16);
                nextToken();
              }
              ech = cast(char)n;
              lxc = true;
              break;
            default:
              if (isalnum(yytok)) fail("invalid escape");
              ech = cast(char)yytok;
              lxc = true;
              break;
          }
        } else {
          ech = cast(char)yytok;
          lxc = true;
        }
        if (!lxc) fail("invalid range");
        if (ech < litch) fail("invalid range");
        nextToken(); // skip literal
        chars[litch..ech+1] = true;
      }
      if (yytok != ']') fail("invalid range", stp);
      nextToken();
      auto yyl = memoryfail(pool.reCreate(type, null, null));
      RERange* last;
      int idx = 0;
      while (idx < chars.length) {
        if (!chars[idx]) { ++idx; continue; }
        int ei = idx+1;
        while (ei < chars.length && chars[ei]) ++ei;
        auto range = memoryfail(pool.alloc!RERange);
        range.from = cast(char)idx;
        range.to = cast(char)(ei-1);
        if (last is null) yyl.range = range; else last.next = range;
        last = range;
        idx = ei;
      }
      if (last is null) fail("invalid range", stp);
      return yyl;
    }

    // literal char
    auto yyl = metaLit(cast(char)yytok);
    nextToken();
    return yyl;
  }

  RegExpPart* parseRepeat () {
    auto yyl = parseAtom();

    if (yytok == '{') {
      // counted repetition
      int parseInt () {
        int res = 0;
        while (yytok >= '0' && yytok <= '9') {
          res = res*10+yytok-'0';
          nextToken();
        }
        return res;
      }

      RECountedQuant qcc;
      nextToken();

      qcc.from = parseInt();
      if (yytok == '}') {
        qcc.to = qcc.from;
      } else if (yytok != ',') {
        fail("comma expected");
      } else {
        nextToken(); // skip comma
        qcc.to = (yytok == '}' ? -1 : parseInt());
      }
      if (yytok != '}') fail("'}' expected");
      //nextToken(); // later
      if (qcc.from >= 500 || qcc.to >= 500) fail("repetition count too big");
      if (qcc.to >= 0 && qcc.from > qcc.to) fail("invalid repetition count");
      if (qcc.from == 0) {
        if (qcc.to == 1) { yytok = '?'; goto cont; }
        if (qcc.to == -1) { yytok = '*'; goto cont; }
      } else if (qcc.from == 1) {
        if (qcc.to == -1) { yytok = '+'; goto cont; }
      }
      nextToken(); // skip closing curly
      bool greedy = true;
      if (yytok == '?') { greedy = false; nextToken(); }
      return memoryfail(lowerCountedRep(pool, yyl, qcc, greedy));
    }

  cont:
    if (yytok == '*') {
      nextToken();
      bool greedy = true;
      if (yytok == '?') { greedy = false; nextToken(); }
      yyl = memoryfail(pool.reCreate(RegExpPart.Type.Star, yyl, null));
      yyl.greedy = greedy;
    }

    if (yytok == '+') {
      nextToken();
      bool greedy = true;
      if (yytok == '?') { greedy = false; nextToken(); }
      yyl = memoryfail(pool.reCreate(RegExpPart.Type.Plus, yyl, null));
      yyl.greedy = greedy;
    }

    if (yytok == '?') {
      nextToken();
      bool greedy = true;
      if (yytok == '?') { greedy = false; nextToken(); }
      yyl = memoryfail(pool.reCreate(RegExpPart.Type.Quest, yyl, null));
      yyl.greedy = greedy;
    }

    return yyl;
  }

  RegExpPart* parseConcat () {
    RegExpPart* yyl;

    if (yytok == EOF) {
      yyl = memoryfail(pool.reCreate(RegExpPart.Type.Nil, null, null));
    } else {
      yyl = parseRepeat();
      while (yytok != '|' && yytok != ')' && yytok != EOF) {
        auto y2 = parseRepeat();
        yyl = memoryfail(pool.reCreate(RegExpPart.Type.Cat, yyl, y2));
      }
    }
    return yyl;
  }

  RegExpPart* parseAlt () {
    RegExpPart* yyl = parseConcat();
    while (yytok == '|') {
      nextToken();
      auto y2 = parseConcat();
      yyl = memoryfail(pool.reCreate(RegExpPart.Type.Alt, yyl, y2));
    }
    return yyl;
  }

  RegExpPart* parseMain () {
    ncaps = 0;
    flags = 0;
    nextToken();
    auto yyl = parseAlt();
    if (yytok != EOF) fail("extra data at regexp");
    return yyl;
  }
}


RegExpPart* parseRegExp(R) (auto ref R rng, ref MemPool pool, out string lasterr, out int lasterrpos)
if (isInputRange!R && is(ElementEncodingType!R : char))
{
  if (!pool.active) return null;

  auto p = REParser({
    int res = -1;
    if (!rng.empty) {
      res = rng.front;
      rng.popFront;
    }
    return res;
  });

  p.pool = pool;
  p.yytok = 0;
  p.ncaps = 0;
  p.flags = 0;

  RegExpPart* re;
  try {
    re = p.parseMain();
    // ok, build "wrapper" regex: ".*?(regex)"

    p.errmsg = "memory error";
    re = pool.reCreate(RegExpPart.Type.Paren, re, null); // $0 capture
    if (re is null) throw reParseError;

    re = pool.reCreate(RegExpPart.Type.TopLevel, re, null);
    if (re is null) throw reParseError;

    auto r = pool.reCreate(RegExpPart.Type.Dot, null, null);
    if (r is null) throw reParseError;

    r = pool.reCreate(RegExpPart.Type.Star, r, null);
    if (r is null) throw reParseError;

    re = pool.reCreate(RegExpPart.Type.Cat, r, re);
    if (re is null) throw reParseError;
  } catch (Exception) {
    lasterr = p.errmsg;
    lasterrpos = p.errpos;
    return null;
  }

  re.nregexes = 1;
  re.multi_ncaps = pool.alloc!uint;
  if (re.multi_ncaps is null) return null;

  re.multi_ncaps[0] = p.ncaps;

  return re;
}


// ///////////////////////////////////////////////////////////////////////// //
struct PoolImpl {
private:
  enum PoolSize = 4096;

private:
  static struct Pool {
    ubyte* data;
    uint used;
    uint size;
  }

nothrow @nogc:
private:
  uint rc;
  Pool* pools;
  uint poolcount, poolsize;

  int newPool (uint size) {
    import core.stdc.stdlib : malloc, realloc;
    assert(size > 0);
    debug(srex_pools) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("allocating new pool of size %u\n", size); }
    if (poolcount >= poolsize) {
      int nsz = poolsize+512;
      auto np = cast(Pool*)realloc(pools, nsz*pools[0].sizeof);
      if (np is null) return -1;
      //np[poolsize..nsz] = null;
      pools = np;
      poolsize = nsz;
    }
    auto pm = cast(ubyte*)malloc(size);
    if (pm is null) return -1;
    pools[poolcount].data = pm;
    pools[poolcount].used = 0;
    pools[poolcount].size = size;
    return poolcount++;
  }

  ubyte* xalloc (uint size) {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;
    assert(size > 0);
    //debug(srex_pools) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("allocating buffer of size %u\n", size); }
    ubyte* res;
    if (size >= PoolSize) {
      // unconditional new pool
      auto pn = newPool(size);
      if (pn < 0) return null;
      pools[pn].used = size;
      res = pools[pn].data;
    } else {
      // do we have free memory in last pool?
      auto lp = pools+poolcount-1;
      if (poolcount == 0 || lp.size-lp.used < size) {
        // new pool
        //if (poolcount != 0) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("  want new pool: used=%u; size=%u\n", lp.used, lp.size); }
        auto pn = newPool(PoolSize);
        if (pn < 0) return null;
        lp = pools+pn;
        //{ import core.stdc.stdio : stderr, fprintf; stderr.fprintf("  pools: %u\n", poolcount); }
      }
      res = lp.data+lp.used;
      lp.used += size;
    }
    //{ import core.stdc.stdio : stderr, fprintf; stderr.fprintf("  pool: used=%u; size=%u\n", lp.used, lp.size); }
    memset(res, 0, size);
    return res;
  }

public:
  void clear () {
    import core.stdc.stdlib : free;
    debug(srex_pools) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("clearing pools: %u\n", poolcount); }
    foreach_reverse (ref p; pools[0..poolcount]) free(p.data);
    if (pools !is null) free(pools);
    pools = null;
    poolcount = poolsize = 0;
  }

  T* alloc(T) (uint addsize=0) {
    static if ((void*).sizeof > 4) { assert(T.sizeof < int.max/8); }
    import core.stdc.string : memcpy;
    T* res = cast(T*)xalloc(cast(uint)T.sizeof+addsize);
    /*
    if (res !is null) {
      static if (is(T == struct) && T.sizeof > 0) {
        static immutable T i = T.init;
        memcpy(res, &i, T.sizeof);
      }
    }
    */
    return res;
  }
}


// ///////////////////////////////////////////////////////////////////////// //
struct MemPool {
private:
  static if ((void*).sizeof <= 4) {
    uint pi;
  } else {
    ulong pi;
  }

nothrow @nogc:
  @property inout(PoolImpl)* impl () inout { pragma(inline, true); return cast(typeof(return))pi; }

private:
  void decref () {
    if (pi) {
      auto pp = cast(PoolImpl*)pi;
      if (--pp.rc == 0) {
        import core.stdc.stdlib : free;
        pp.clear;
        free(pp);
        debug(srex_pools_high) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("MEMHI: pool 0x%08x freed\n", pi); }
      }
      pi = 0;
    }
  }

  @property inout(void)* firstalloc () inout @trusted {
    if (pi) {
      auto pp = cast(PoolImpl*)pi;
      return cast(typeof(return))(pp.poolcount ? pp.pools[0].data : null);
    } else {
      return null;
    }
  }

public:
  this (in MemPool p) {
    pragma(inline, true);
    pi = p.pi;
    if (pi) ++(cast(PoolImpl*)pi).rc;
  }

  this (this) @trusted { pragma(inline, true); if (pi) ++(cast(PoolImpl*)pi).rc; }

  ~this () { pragma(inline, true); if (pi) decref(); }

  @property bool active () const pure @safe { pragma(inline, true); return (pi != 0); }

  static MemPool create () {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;
    // create new pool
    auto pp = cast(PoolImpl*)malloc(PoolImpl.sizeof);
    MemPool res;
    if (pp !is null) {
      memset(pp, 0, (*pp).sizeof);
      pp.rc = 1;
      res.pi = cast(typeof(res.pi))pp;
      debug(srex_pools_high) { import core.stdc.stdio : stderr, fprintf; stderr.fprintf("MEMHI: pool 0x%08x allocated\n", res.pi); }
    }
    return res;
  }

  void clear () { pragma(inline, true); if (pi) (cast(PoolImpl*)pi).clear; }

  void release () { pragma(inline, true); if (pi) decref(); }

  void opAssign (in MemPool p) {
    if (p.pi) ++(cast(PoolImpl*)(p.pi)).rc;
    decref();
    pi = p.pi;
  }

  T* alloc(T) (uint addsize=0) {
    if (!pi) return null;
    return (cast(PoolImpl*)pi).alloc!T(addsize);
  }
}


// ///////////////////////////////////////////////////////////////////////// //
struct CaptureRec {
  uint rc; // reference count
  size_t ovecsize;
  int regex_id;
  int* vector;
  CaptureRec* next;
}

enum Opcode : ubyte {
  Char   = 1,
  Match  = 2,
  Jump   = 3,
  Split  = 4,
  Any    = 5,
  Save   = 6,
  In     = 7,
  NotIn  = 8,
  Assert = 9,
}

align(1) struct Range2VM {
align(1):
  char from = 0;
  char to = 0;
}

struct RangesInVM {
  uint count;
  Range2VM* head;
}

struct VMInstr {
  Opcode opcode;
  VMInstr* x;
  VMInstr* y;
  uint tag;
  union {
    char ch = 0;
    RangesInVM* ranges;
    uint group; // capture group
    uint greedy;
    uint assertion;
    int regex_id;
  }
}

struct Chain {
  void* data;
  Chain* next;
}

struct Program {
  VMInstr* start;
  uint len;

  uint tag;
  uint uniq_threads; // unique thread count
  uint dup_threads;  // duplicatable thread count
  uint lookahead_asserts;
  uint nullable;
  Chain* leading_bytes;
  int leading_byte;

  uint ovecsize;
  uint nregexes;
  uint[1] multi_ncaps;
}


// ///////////////////////////////////////////////////////////////////////// //
void dump (Program* prog) {
  VMInstr* pc, start, end;
  start = prog.start;
  end = prog.start+prog.len;
  for (pc = start; pc < end; ++pc) {
    import core.stdc.stdio : printf;
    dump(pc, start);
    printf("\n");
  }
}


void dump (VMInstr* pc, VMInstr* start) {
  import core.stdc.stdio : FILE, fprintf, stdout, fputc;
  FILE* f = stdout;

  uint i;
  Range2VM* range;

  switch (pc.opcode) {
    case Opcode.Split:
      fprintf(f, "%2d. split %d, %d", cast(int)(pc-start), cast(int)(pc.x-start), cast(int)(pc.y-start));
      break;
    case Opcode.Jump:
      fprintf(f, "%2d. jmp %d", cast(int)(pc-start), cast(int)(pc.x-start));
      break;
    case Opcode.Char:
      fprintf(f, "%2d. char %d", cast(int)(pc-start), cast(int)pc.ch);
      break;
    case Opcode.In:
      fprintf(f, "%2d. in", cast(int)(pc-start));
      for (i = 0; i < pc.ranges.count; i++) {
        range = pc.ranges.head+i;
        if (i > 0) fputc(',', f);
        fprintf(f, " %d-%d", range.from, range.to);
      }
      break;
    case Opcode.NotIn:
      fprintf(f, "%2d. notin", cast(int)(pc-start));
      for (i = 0; i < pc.ranges.count; i++) {
        range = pc.ranges.head+i;
        if (i > 0) fputc(',', f);
        fprintf(f, " %d-%d", range.from, range.to);
      }
      break;
    case Opcode.Any:
      fprintf(f, "%2d. any", cast(int)(pc-start));
      break;
    case Opcode.Match:
      fprintf(f, "%2d. match %d", cast(int)(pc-start), cast(int)pc.regex_id);
      break;
    case Opcode.Save:
      fprintf(f, "%2d. save %d", cast(int)(pc-start), cast(int)pc.group);
      break;
    case Opcode.Assert:
      fprintf(f, "%2d. assert ", cast(int)(pc-start));
      switch (pc.assertion) {
        case RegExpPart.AssType.StreamStart:
          fprintf(f, "\\A");
          break;
        case RegExpPart.AssType.Bol:
          fprintf(f, "^");
          break;
        case RegExpPart.AssType.StreamEnd:
          fprintf(f, "\\z");
          break;
        case RegExpPart.AssType.NonWord:
          fprintf(f, "\\B");
          break;
        case RegExpPart.AssType.Word:
          fprintf(f, "\\b");
          break;
        case RegExpPart.AssType.Eol:
          fprintf(f, "$");
          break;
        default:
          fprintf(f, "?");
          break;
      }
      break;
    default:
      fprintf(f, "%2d. unknown", cast(int)(pc-start));
      break;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
import std.range;


struct RERange {
  char from = 0;
  char to = 0;
  RERange* next;
}

// counted quantifier
struct RECountedQuant {
  int from;
  int to;
}

struct RegExpPart {
  enum Type : ubyte {
    Nil      = 0,
    Alt      = 1,
    Cat      = 2,
    Lit      = 3,
    Dot      = 4,
    Paren    = 5,
    Quest    = 6,
    Star     = 7,
    Plus     = 8,
    Class    = 9,
    NClass   = 10,
    Assert   = 11,
    TopLevel = 12,
  }

  enum AssType : ubyte {
    StreamEnd   = 0x01,
    Eol         = 0x02,
    NonWord     = 0x04,
    Word        = 0x08,
    StreamStart = 0x10,
    Bol         = 0x20,
  }

  Type type;

  RegExpPart* left;
  RegExpPart* right;

  uint nregexes;

  union {
    char ch = 0;
    RERange* range;
    uint* multi_ncaps;
    uint group;
    uint assertion;
    uint greedy;
    int regex_id;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void dump (const(RegExpPart)* r) {
  import core.stdc.stdio : printf;
  const(RERange)* range;
  switch (r.type) {
    case RegExpPart.Type.Alt:
      printf("Alt(");
      dump(r.left);
      printf(", ");
      dump(r.right);
      printf(")");
      break;
    case RegExpPart.Type.Cat:
      printf("Cat(");
      dump(r.left);
      printf(", ");
      dump(r.right);
      printf(")");
      break;
    case RegExpPart.Type.Lit:
      printf("Lit(%d)", cast(int)r.ch);
      break;
    case RegExpPart.Type.Dot:
      printf("Dot");
      break;
    case RegExpPart.Type.Paren:
      printf("Paren(%lu, ", cast(uint)r.group);
      dump(r.left);
      printf(")");
      break;
    case RegExpPart.Type.Star:
      if (!r.greedy) printf("Ng");
      printf("Star(");
      dump(r.left);
      printf(")");
      break;
    case RegExpPart.Type.Plus:
      if (!r.greedy) printf("Ng");
      printf("Plus(");
      dump(r.left);
      printf(")");
      break;
    case RegExpPart.Type.Quest:
      if (!r.greedy) printf("Ng");
      printf("Quest(");
      dump(r.left);
      printf(")");
      break;
    case RegExpPart.Type.Nil:
      printf("Nil");
      break;
    case RegExpPart.Type.Class:
      printf("CLASS(");
      for (range = r.range; range; range = range.next) printf("[%d, %d]", range.from, range.to);
      printf(")");
      break;
    case RegExpPart.Type.NClass:
      printf("NCLASS(");
      for (range = r.range; range; range = range.next) printf("[%d, %d]", range.from, range.to);
      printf(")");
      break;
    case RegExpPart.Type.Assert:
      printf("ASSERT(");
      switch (r.assertion) {
        case RegExpPart.AssType.StreamStart:
           printf("\\A");
           break;
        case RegExpPart.AssType.Bol:
          printf("^");
          break;
        case RegExpPart.AssType.Eol:
          printf("$");
          break;
        case RegExpPart.AssType.StreamEnd:
          printf("\\z");
          break;
        case RegExpPart.AssType.NonWord:
          printf("\\B");
          break;
        case RegExpPart.AssType.Word:
          printf("\\b");
          break;
        default:
          printf("???");
          break;
      }
      printf(")");
      break;
    case RegExpPart.Type.TopLevel:
      printf("TOPLEVEL(%lu, ", cast(uint)r.regex_id);
      dump(r.left);
      printf(")");
      break;
    default:
      printf("???");
      break;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private RegExpPart* reCreate (MemPool pool, RegExpPart.Type type, RegExpPart* left, RegExpPart* right) {
  auto r = pool.alloc!RegExpPart;
  if (r is null) return null;
  r.type = type;
  r.left = left;
  r.right = right;
  return r;
}


// turn range into case-insensitive one
private RERange* range2CI (MemPool pool, RERange* range) {
  static T max(T) (T a, T b) pure nothrow @safe @nogc { pragma(inline, true); return (a > b ? a : b); }
  static T min(T) (T a, T b) pure nothrow @safe @nogc { pragma(inline, true); return (a < b ? a : b); }

  char from = 0, to = 0;
  RERange* r, nr;
  for (r = range; r; r = r.next) {
    from = r.from;
    to = r.to;
    if (to >= 'A' && from <= 'Z') {
      // overlap with A-Z
      nr = pool.alloc!RERange;
      if (nr is null) return null;
      nr.from = cast(char)(max(from, 'A')+32);
      nr.to = cast(char)(min(to, 'Z')+32);
      nr.next = r.next;
      r.next = nr;
      r = nr;
    }
    if (to >= 'a' && from <= 'z') {
      /* overlap with a-z */
      nr = pool.alloc!RERange;
      if (nr is null) return null;
      nr.from = cast(char)(max(from, 'a')-32);
      nr.to = cast(char)(min(to, 'z')-32);
      nr.next = r.next;
      r.next = nr;
      r = nr;
    }
  }
  return range;
}


private RegExpPart* lowerCountedRep (MemPool pool, RegExpPart* subj, ref RECountedQuant cquant, bool greedy) {
  int i;
  RegExpPart* concat, quest, star;

  if (cquant.from == 1 && cquant.to == 1) return subj;

  // generate subj{from} first
  if (cquant.from == 0) {
    concat = pool.reCreate(RegExpPart.Type.Nil, null, null);
    if (concat is null) return null;
    i = 0;
  } else {
    concat = subj;
    for (i = 1; i < cquant.from; ++i) {
      concat = pool.reCreate(RegExpPart.Type.Cat, concat, subj);
      if (concat is null) return null;
    }
  }

  if (cquant.from == cquant.to) return concat;

  if (cquant.to == -1) {
    // append subj* to concat
    star = pool.reCreate(RegExpPart.Type.Star, subj, null);
    if (star is null) return null;
    star.greedy = greedy;
    concat = pool.reCreate(RegExpPart.Type.Cat, concat, star);
    if (concat is null) return null;
    return concat;
  }

  // append (?:subj?){to-from}
  quest = pool.reCreate(RegExpPart.Type.Quest, subj, null);
  if (quest is null) return null;
  quest.greedy = greedy;
  for (; i < cquant.to; ++i) {
    concat = pool.reCreate(RegExpPart.Type.Cat, concat, quest);
    if (concat is null) return null;
  }
  return concat;
}


// ////////////////////////////////////////////////////////////////////////// //
Program* reCompile (MemPool pool, RegExpPart* re) {
  import core.stdc.string : memcpy, memset;

  uint i, n, multi_ncaps_size;
  char* p;
  Program* prog;
  VMInstr* pc;

  n = re.prgLength;

  multi_ncaps_size = (re.nregexes-1)*uint.sizeof;

  p = pool.alloc!char(cast(uint)Program.sizeof+multi_ncaps_size+n*cast(uint)VMInstr.sizeof);
  if (p is null) return null;

  prog = cast(Program*)p;

  prog.nregexes = re.nregexes;

  memcpy(prog.multi_ncaps.ptr, re.multi_ncaps, re.nregexes*uint.sizeof);

  prog.start = cast(VMInstr*)(p+Program.sizeof+multi_ncaps_size);

  memset(prog.start, 0, n*VMInstr.sizeof);

  pc = emit(pool, prog.start, re);
  if (pc is null) return null;

  if (pc-prog.start != n) {
    //dd("buffer error: %d != %d", (int)(pc-prog.start), (int)n);
    return null;
  }

  prog.len = pc-prog.start;
  prog.tag = 0;
  prog.lookahead_asserts = 0;
  prog.dup_threads = 0;
  prog.uniq_threads = 0;
  prog.nullable = 0;
  prog.leading_bytes = null;
  prog.leading_byte = -1;

  prog.ovecsize = 0;
  for (i = 0; i < prog.nregexes; ++i) prog.ovecsize += prog.multi_ncaps[i]+1;
  prog.ovecsize *= 2*uint.sizeof;

  if (getLeadingBytes(pool, prog, &prog.leading_bytes) == SRE_ERROR) return null;

  if (prog.leading_bytes && prog.leading_bytes.next is null) {
    pc = cast(VMInstr*)prog.leading_bytes.data;
    if (pc.opcode == Opcode.Char) prog.leading_byte = pc.ch;
  }

  //dd("nullable: %u", prog.nullable);

  version(none) {
    Chain* cl;
    for (cl = prog.leading_bytes; cl; cl = cl.next) {
      pc = cl.data;
      fprintf(stderr, "[");
      dump(stderr, pc, prog.start);
      fprintf(stderr, "]");
    }
    if (prog.leading_bytes) fprintf(stderr, "\n");
  }

  return prog;
}


private int getLeadingBytes (MemPool pool, Program* prog, Chain** res) {
  uint tag = prog.tag+1;
  int rc = getLeadingBytesHelper(pool, prog.start, prog, res, tag);
  prog.tag = tag;
  if (rc == SRE_ERROR) return SRE_ERROR;
  if (rc == SRE_DECLINED || prog.nullable) {
    *res = null;
    return SRE_DECLINED;
  }
  return rc;
}


private int getLeadingBytesHelper (MemPool pool, VMInstr* pc, Program* prog, Chain** res, uint tag) {
  int rc;
  Chain* cl, ncl;
  VMInstr* bc;

  if (pc.tag == tag) return SRE_OK;

  if (pc == prog.start+1) {
    // skip the dot (.) in the initial boilerplate ".*?"
    return SRE_OK;
  }

  pc.tag = tag;

  switch (pc.opcode) {
    case Opcode.Split:
      rc = getLeadingBytesHelper(pool, pc.x, prog, res, tag);
      if (rc != SRE_OK) return rc;
      return getLeadingBytesHelper(pool, pc.y, prog, res, tag);
    case Opcode.Jump:
      return getLeadingBytesHelper(pool, pc.x, prog, res, tag);
    case Opcode.Save:
      if (++pc == prog.start+prog.len) return SRE_OK;
      return getLeadingBytesHelper(pool, pc, prog, res, tag);
    case Opcode.Match:
      prog.nullable = 1;
      return SRE_DONE;
    case Opcode.Assert:
      if (++pc == prog.start+prog.len) return SRE_OK;
      return getLeadingBytesHelper(pool, pc, prog, res, tag);
    case Opcode.Any:
      return SRE_DECLINED;
    default:
      /* CHAR, ANY, IN, NOTIN */
      ncl = pool.alloc!Chain;
      if (ncl is null) return SRE_ERROR;
      ncl.data = pc;
      ncl.next = null;
      if (*res) {
        for (cl = *res; /* void */; cl = cl.next) {
          bc = cast(VMInstr*)cl.data;
          if (bc.opcode == pc.opcode) {
            if (bc.opcode == Opcode.Char) {
              if (bc.ch == pc.ch) return SRE_OK;
            }
          }
          if (cl.next is null) {
            cl.next = ncl;
            return SRE_OK;
          }
        }
      } else {
        *res = ncl;
      }
      return SRE_OK;
  }
}


private uint prgLength (RegExpPart* r) {
  //dd("program len on node: %d", (int)r.type);
  final switch (r.type) {
    case RegExpPart.Type.Alt:
      return 2+r.left.prgLength+r.right.prgLength;
    case RegExpPart.Type.Cat:
      return r.left.prgLength+r.right.prgLength;
    case RegExpPart.Type.Lit:
    case RegExpPart.Type.Dot:
    case RegExpPart.Type.Class:
    case RegExpPart.Type.NClass:
      return 1;
    case RegExpPart.Type.Paren:
      return 2+r.left.prgLength;
    case RegExpPart.Type.Quest:
      return 1+r.left.prgLength;
    case RegExpPart.Type.Star:
      return 2+r.left.prgLength;
    case RegExpPart.Type.Plus:
      return 1+r.left.prgLength;
    case RegExpPart.Type.Assert:
      return 1;
    case RegExpPart.Type.TopLevel:
      return 1+r.left.prgLength;
    case RegExpPart.Type.Nil:
      // impossible to reach here
      assert(0);
  }
}


private VMInstr* emit (MemPool pool, VMInstr* pc, RegExpPart* r) {
  VMInstr* p1, p2, t;
  //dd("program emit bytecode on node: %d", (int)r.type);
  switch(r.type) {
    case RegExpPart.Type.Alt:
      // split
      pc.opcode = Opcode.Split;
      p1 = pc++;
      p1.x = pc;
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      // jump
      pc.opcode = Opcode.Jump;
      p2 = pc++;
      p1.y = pc;
      pc = emit(pool, pc, r.right);
      if (pc is null) return null;
      p2.x = pc;
      break;
    case RegExpPart.Type.Cat:
      // left
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      // right
      pc = emit(pool, pc, r.right);
      if (pc is null) return null;
      break;
    case RegExpPart.Type.Lit:
      pc.opcode = Opcode.Char;
      pc.ch = r.ch;
      ++pc;
      break;
    case RegExpPart.Type.Class:
      pc.opcode = Opcode.In;
      if (addCharClass(pool, pc, r.range) != SRE_OK) return null;
      ++pc;
      break;
    case RegExpPart.Type.NClass:
      pc.opcode = Opcode.NotIn;
      if (addCharClass(pool, pc, r.range) != SRE_OK) return null;
      ++pc;
      break;
    case RegExpPart.Type.Dot:
      pc.opcode = Opcode.Any;
      ++pc;
      break;
    case RegExpPart.Type.Paren:
      // save
      pc.opcode = Opcode.Save;
      pc.group = 2*r.group;
      ++pc;
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      pc.opcode = Opcode.Save;
      pc.group = 2*r.group+1;
      ++pc;
      break;
    case RegExpPart.Type.Quest:
      // split
      pc.opcode = Opcode.Split;
      p1 = pc++;
      p1.x = pc;
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      p1.y = pc;
      // non-greedy?
      if (!r.greedy) {
        t = p1.x;
        p1.x = p1.y;
        p1.y = t;
      }
      break;
    case RegExpPart.Type.Star:
      // split
      pc.opcode = Opcode.Split;
      p1 = pc++;
      p1.x = pc;
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      // jump
      pc.opcode = Opcode.Jump;
      pc.x = p1;
      ++pc;
      p1.y = pc;
      // non-greedy?
      if (!r.greedy) {
        t = p1.x;
        p1.x = p1.y;
        p1.y = t;
      }
      break;
    case RegExpPart.Type.Plus:
      // first
      p1 = pc;
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      // split
      pc.opcode = Opcode.Split;
      pc.x = p1;
      p2 = pc;
      ++pc;
      p2.y = pc;
      // non-greedy?
      if (!r.greedy) {
        t = p2.x;
        p2.x = p2.y;
        p2.y = t;
      }
      break;
    case RegExpPart.Type.Assert:
      pc.opcode = Opcode.Assert;
      pc.assertion = r.assertion;
      ++pc;
      break;
    case RegExpPart.Type.TopLevel:
      pc = emit(pool, pc, r.left);
      if (pc is null) return null;
      pc.opcode = Opcode.Match;
      //dd("setting regex id %ld", (long) r.regex_id);
      pc.regex_id = r.regex_id;
      ++pc;
      break;
    case RegExpPart.Type.Nil:
      /* do nothing */
      break;
    default:
      /* impossible to reach here */
      break;
  }
  return pc;
}


private int addCharClass (MemPool pool, VMInstr* pc, RERange* range) {
  char* p;
  uint i, n;
  RERange* r;

  n = 0;
  for (r = range; r; r = r.next) ++n;

  p = pool.alloc!char(cast(uint)RangesInVM.sizeof+n*cast(uint)Range2VM.sizeof);
  if (p is null) return SRE_ERROR;

  pc.ranges = cast(RangesInVM*)p;

  p += RangesInVM.sizeof;
  pc.ranges.head = cast(Range2VM*)p;

  pc.ranges.count = n;

  for (i = 0, r = range; r; i++, r = r.next) {
    pc.ranges.head[i].from = r.from;
    pc.ranges.head[i].to = r.to;
  }

  return SRE_OK;
}


// ////////////////////////////////////////////////////////////////////////// //
/// thompson virtual machine. used to check if re matches, but can't return position.
public struct Thompson {
private:
  MemPool pool;

public:
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return pool.active; }

  static Thompson create (RegExp rex) {
    uint len;
    ThompsonCtx* ctx;
    ThompsonThreadList* clist, nlist;

    if (!rex.valid) return Thompson.init;

    Thompson vm;

    vm.pool = MemPool.create;
    if (!vm.pool.active) return Thompson.init;

    ctx = vm.pool.alloc!ThompsonCtx;
    if (ctx is null) { vm.pool.release; return Thompson.init; }
    scope(exit) ctx.pool.release; // fixup rc

    ctx.pool = vm.pool;
    assert(vm.pool.impl.rc == 2);
    ctx.program = rex.reprg;

    len = rex.reprg.len;

    clist = createThreadList(vm.pool, len);
    if (clist is null) { ctx.pool.release; vm.pool.release; return Thompson.init; }

    ctx.current_threads = clist;

    nlist = createThreadList(vm.pool, len);
    if (nlist is null) { ctx.pool.release; vm.pool.release; return Thompson.init; }

    ctx.next_threads = nlist;

    ctx.tag = rex.reprg.tag+1;
    ctx.first_buf = true;
    assert(vm.pool.impl.rc == 2);

    return vm;
  }

  int exec (const(char)[] input, bool eof=true) {
    if (!pool.active) return SRE_ERROR;
    auto ctx = cast(ThompsonCtx*)pool.firstalloc;
    ctx.pool = pool;
    scope(exit) ctx.pool = MemPool.init; // fixup rc
    return execute(ctx, input.ptr, input.length, eof);
  }
}


struct ThompsonThread {
  VMInstr* pc;
  void* asserts_handler;
  bool seen_word;
}


struct ThompsonThreadList {
  uint count;
  ThompsonThread[1] threads;
}


struct ThompsonCtx {
  MemPool pool;
  Program* program;
  const(char)* buffer;

  ThompsonThreadList* current_threads;
  ThompsonThreadList* next_threads;

  uint tag;
  bool first_buf;
  bool[1] threads_added; // bit array
}


int execute (ThompsonCtx* ctx, const(char)* input, size_t size, bool eof) {
  const(char)* sp, last;
  uint i, j;
  bool in_;
  Program* prog;
  Range2VM* range;
  VMInstr* pc;
  ThompsonThread* t;
  ThompsonThreadList* clist, nlist, tmp;

  prog = ctx.program;
  clist = ctx.current_threads;
  nlist = ctx.next_threads;
  ctx.buffer = input;

  if (ctx.first_buf) {
    ctx.first_buf = false;
    addThread(ctx, clist, prog.start, input);
  }

  last = input+size;

  for (sp = input; sp < last || (eof && sp == last); sp++) {
    //dd("=== pos %d (char %d).\n", (int)(sp-input), (sp < last) ? (*sp&0xFF) : 0);
    if (clist.count == 0) break;
    /* printf("%d(%02x).", (int)(sp-input), *sp&0xFF); */
    ctx.tag++;
    for (i = 0; i < clist.count; i++) {
      t = clist.threads.ptr+i;
      pc = t.pc;
      //dd("--- #%u: pc %d: opcode %d\n", ctx.tag, (int)(pc-prog.start), pc.opcode);
      switch (pc.opcode) {
        case Opcode.In:
          if (sp == last) break;
          in_ = false;
          for (j = 0; j < pc.ranges.count; j++) {
            range = pc.ranges.head+j;
            //dd("testing %d for [%d, %d] (%u)", *sp, (int)range.from, (int)range.to, (unsigned) j);
            if (*sp >= range.from && *sp <= range.to) {
              in_ = true;
              break;
            }
          }
          if (!in_) break;
          addThread(ctx, nlist, pc+1, sp+1);
          break;
        case Opcode.NotIn:
          if (sp == last) break;
          in_ = false;
          for (j = 0; j < pc.ranges.count; j++) {
            range = pc.ranges.head+j;
            //dd("testing %d for [%d, %d] (%u)", *sp, (int)range.from, (int)range.to, (unsigned) j);
            if (*sp >= range.from && *sp <= range.to) {
              in_ = true;
              break;
            }
          }
          if (in_) break;
          addThread(ctx, nlist, pc+1, sp+1);
          break;
        case Opcode.Char:
          if (sp == last || *sp != pc.ch) break;
          addThread(ctx, nlist, pc+1, sp+1);
          break;
        case Opcode.Any:
          if (sp == last) break;
          addThread(ctx, nlist, pc+1, sp+1);
          break;
        case Opcode.Assert:
          switch (pc.assertion) {
            case RegExpPart.AssType.StreamEnd:
              if (sp != last) break;
              goto assertion_hold;
            case RegExpPart.AssType.Eol:
              if (sp != last && *sp != '\n') break;
              goto assertion_hold;
            case RegExpPart.AssType.NonWord:
              if (cast(ubyte)t.seen_word ^ cast(ubyte)(sp != last && isWordChar(*sp))) {
                //dd("\\B assertion failed: %u %c", t.seen_word, *sp);
                break;
              }
              //dd("\\B assertion passed: %u %c", t.seen_word, *sp);
              goto assertion_hold;
            case RegExpPart.AssType.Word:
              //dd("seen word: %d, sp == last: %d, char=%d", t.seen_word, sp == last, sp == last ? 0 : *sp);
              if ((cast(ubyte)t.seen_word ^ cast(ubyte)(sp != last && isWordChar(*sp))) == 0) {
                //dd("\\b assertion failed: %u %c, cur is word: %d, " "pc=%d", (int)t.seen_word, sp == last ? 0 : *sp, sp != last && isWordChar(*sp), (int)(pc-ctx.program.start));
                break;
              }
              //dd("\\b assertion passed: %u %c", (int)t.seen_word, sp != last ? *sp : 0);
              goto assertion_hold;
            default:
              // impossible to reach here
              break;
          }
          break;
         assertion_hold:
          ctx.tag--;
          addThread(ctx, clist, pc+1, sp);
          ctx.tag++;
          break;
        case Opcode.Match:
          prog.tag = ctx.tag;
          return SRE_OK;
        default:
          /*
           * Jmp, Split, Save handled in addthread, so that
           * machine execution matches what a backtracker would do.
           * This is discussed (but not shown as code) in
           * Regular Expression Matching: the Virtual Machine Approach.
           */
          break;
      }
    }
    /* printf("\n"); */
    tmp = clist;
    clist = nlist;
    nlist = tmp;
    nlist.count = 0;
    if (sp == last) break;
  }

  prog.tag = ctx.tag;

  ctx.current_threads = clist;
  ctx.next_threads = nlist;

  if (eof) return SRE_DECLINED;

  return SRE_AGAIN;
}


private void addThread (ThompsonCtx* ctx, ThompsonThreadList* l, VMInstr* pc, const(char)* sp) {
  bool seen_word = false;
  ThompsonThread* t;

  if (pc.tag == ctx.tag) return; // already on list

  pc.tag = ctx.tag;

  switch (pc.opcode) {
    case Opcode.Jump:
      addThread(ctx, l, pc.x, sp);
      return;
    case Opcode.Split:
      addThread(ctx, l, pc.x, sp);
      addThread(ctx, l, pc.y, sp);
      return;
    case Opcode.Save:
      addThread(ctx, l, pc+1, sp);
      return;
    case Opcode.Assert:
      switch (pc.assertion) {
        case RegExpPart.AssType.StreamStart:
          if (sp != ctx.buffer) {
            //dd("\\A assertion failed: %d", (int)(sp-ctx.buffer));
            return;
          }
          addThread(ctx, l, pc+1, sp);
          return;
        case RegExpPart.AssType.Bol:
          if (sp != ctx.buffer && sp[-1] != '\n') return;
          addThread(ctx, l, pc+1, sp);
          return;
        case RegExpPart.AssType.Word:
        case RegExpPart.AssType.NonWord:
          seen_word = (sp != ctx.buffer && isWordChar(sp[-1]));
          //dd("pc=%d, setting seen word: %u %c", (int)(pc-ctx.program.start), (int)seen_word, (sp != ctx.buffer) ? sp[-1] : 0);
          break;
        default:
          // postpone look-ahead assertions
          break;
      }
      break;
    default:
      break;
  }

  t = l.threads.ptr+l.count;
  t.pc = pc;
  t.seen_word = seen_word;

  l.count++;
}


ThompsonThreadList* createThreadList (MemPool pool, uint size) {
  auto l = pool.alloc!ThompsonThreadList((size-1)*cast(uint)ThompsonThread.sizeof);
  if (l is null) return null;
  l.count = 0;
  return l;
}


// ////////////////////////////////////////////////////////////////////////// //
/// pike virtual machine. can return captures.
public struct Pike {
public:
  align(1) static struct Capture {
  align(1):
    int s, e; // starting and ending indicies
  }

private:
  MemPool pool;

public:
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return pool.active; }

  static Pike create (RegExp rex, Capture[] ovector) {
    PikeCtx* ctx;
    PikeThreadList* clist, nlist;

    if (!rex.valid) return Pike.init;

    Pike vm;

    vm.pool = MemPool.create;
    if (!vm.pool.active) return Pike.init;

    ctx = vm.pool.alloc!PikeCtx;
    if (ctx is null) { vm.pool.release; return Pike.init; }

    ctx.pool = vm.pool;
    ctx.program = rex.reprg;
    ctx.processed_bytes = 0;
    ctx.pending_ovector = null;
    scope(exit) ctx.pool.release; // fixup rc

    clist = treadListCreate(vm.pool);
    if (clist is null) { ctx.pool.release; vm.pool.release; return Pike.init; }

    ctx.current_threads = clist;

    nlist = treadListCreate(vm.pool);
    if (nlist is null) { ctx.pool.release; vm.pool.release; return Pike.init; }

    ctx.next_threads = nlist;

    //ctx.program = rex.reprg;
    //ctx.pool = pool;
    ctx.free_capture = null;
    ctx.free_threads = null;
    ctx.matched = null;

    if (ovector.length > 0) {
      ctx.ovector = cast(int*)ovector.ptr;
      ctx.ovecsize = cast(int)ovector.length*2;
    } else {
      ctx.ovector = ctx.pool.alloc!int(int.sizeof); // 2 ints
      if (ctx.ovector is null) { ctx.pool.release; vm.pool.release; return Pike.init; }
      ctx.ovecsize = 2;
    }

    //dd("resetting seen start state");
    ctx.seen_start_state = false;
    ctx.initial_states_count = 0;
    ctx.initial_states = null;
    ctx.first_buf = true;
    ctx.eof = false;
    ctx.empty_capture = false;
    ctx.seen_newline = false;
    ctx.seen_word = false;

    return vm;
  }

  int exec (const(char)[] input, bool eof=true) {
    if (!pool.active) return SRE_ERROR;
    auto ctx = cast(PikeCtx*)pool.firstalloc;
    ctx.pool = pool;
    scope(exit) ctx.pool.release; // fixup rc
    return execute(ctx, input.ptr, input.length, eof, null);
  }
}


// mixin
enum PikeFreeThreadCtxT = "t.next = ctx.free_threads; ctx.free_threads = t;";


struct PikeThread {
  VMInstr* pc;
  CaptureRec* capture;
  PikeThread* next;
  bool seen_word;
}


struct PikeThreadList {
  uint count;
  PikeThread* head;
  PikeThread** next;
}


struct PikeCtx {
  uint tag;
  int processed_bytes;
  const(char)* buffer;
  MemPool pool;
  Program* program;
  CaptureRec* matched;
  CaptureRec* free_capture;
  PikeThread* free_threads;

  int* pending_ovector;
  int* ovector;
  size_t ovecsize;

  PikeThreadList* current_threads;
  PikeThreadList *next_threads;

  int last_matched_pos; // the pos for the last (partial) match

  VMInstr** initial_states;
  uint initial_states_count;

  bool first_buf;
  bool seen_start_state;
  bool eof;
  bool empty_capture;
  bool seen_newline;
  bool seen_word;
}


int execute (PikeCtx* ctx, const(char)* input, size_t size, bool eof, int** pending_matched) {
  const(char)* sp, last, p;
  int rc;
  uint i;
  bool seen_word, in_;
  MemPool pool;
  Program* prog;
  CaptureRec* cap, matched;
  Range2VM* range;
  VMInstr* pc;
  PikeThread* t;
  PikeThreadList* clist, nlist, tmp;
  PikeThreadList list;

  if (ctx.eof) {
    //dd("eof found");
    return SRE_ERROR;
  }

  pool = ctx.pool;
  prog = ctx.program;
  clist = ctx.current_threads;
  nlist = ctx.next_threads;
  matched = ctx.matched;

  ctx.buffer = input;
  ctx.last_matched_pos = -1;

  if (ctx.empty_capture) {
    //dd("found empty capture");
    ctx.empty_capture = false;
    if (size == 0) {
      if (eof) {
        ctx.eof = true;
        return SRE_DECLINED;
      }
      return SRE_AGAIN;
    }
    sp = input+1;
  } else {
    sp = input;
  }

  last = input+size;

  //dd("processing buffer size %d", (int)size);

  if (ctx.first_buf) {
    ctx.first_buf = false;

    cap = captureCreate(pool, prog.ovecsize, 1, &ctx.free_capture);
    if (cap is null) return SRE_ERROR;

    ctx.tag = prog.tag+1;
    rc = addThread(ctx, clist, prog.start, cap, cast(int)(sp-input), null);
    if (rc != SRE_OK) {
      prog.tag = ctx.tag;
      return SRE_ERROR;
    }

    ctx.initial_states_count = clist.count;
    ctx.initial_states = pool.alloc!(VMInstr*)(cast(uint)(VMInstr*).sizeof*clist.count); //k8: -1 is safe here
    if (ctx.initial_states is null) return SRE_ERROR;

    /* we skip the last thread because it must always be .*? */
    for (i = 0, t = clist.head; t && t.next; i++, t = t.next) {
      ctx.initial_states[i] = t.pc;
    }
  } else {
    ctx.tag = prog.tag;
  }

  for (; sp < last || (eof && sp == last); sp++) {
    //dd("=== pos %d, offset %d (char '%c' (%d)).\n", (int)(sp-input+ctx.processed_bytes), (int)(sp-input), sp < last ? *sp : '?', sp < last ? *sp : 0);
    if (clist.head is null) {
      //dd("clist empty. abort.");
      break;
    }

    version(none) {
      fprintf(stderr, "sregex: cur list:");
      for (t = clist.head; t; t = t.next) fprintf(stderr, " %d", cast(int)(t.pc-prog.start));
      fprintf(stderr, "\n");
    }

    //dd("seen start state: %d", (int)ctx.seen_start_state);

    if (prog.leading_bytes && ctx.seen_start_state) {
      //dd("resetting seen start state");
      ctx.seen_start_state = false;

      if (sp == last || clist.count != ctx.initial_states_count) {
        //dd("skip because sp == last or clist.count != initial states count!");
        goto run_cur_threads;
      }

      for (i = 0, t = clist.head; t && t.next; i++, t = t.next) {
        if (t.pc != ctx.initial_states[i]) {
          //dd("skip because pc %d unmatched: %d != %d", (int)i, (int)(t.pc-prog.start), (int)(ctx.initial_states[i]-prog.start));
          goto run_cur_threads;
        }
      }

      //dd("XXX found initial state to do first byte search!");
      p = findFirstByte(sp, last, prog.leading_byte, prog.leading_bytes);

      if (p > sp) {
        //dd("XXX moved sp by %d bytes", (int)(p-sp));
        sp = p;
        clearThreadList(ctx, clist);
        cap = captureCreate(pool, prog.ovecsize, 1, &ctx.free_capture);
        if (cap is null) return SRE_ERROR;
        ctx.tag++;
        rc = addThread(ctx, clist, prog.start, cap, cast(int)(sp-input), null);
        if (rc != SRE_OK) {
          prog.tag = ctx.tag;
          return SRE_ERROR;
        }
        if (sp == last) break;
      }
    }

  run_cur_threads:
    ctx.tag++;
    while (clist.head) {
      t = clist.head;
      clist.head = t.next;
      clist.count--;

      pc = t.pc;
      cap = t.capture;

      /*#if DDEBUG
          fprintf(stderr, "--- #%u", ctx.tag);
          dump(stderr, pc, prog.start);
          fprintf(stderr, "\n");
      #endif*/

      switch (pc.opcode) {
        case Opcode.In:
          if (sp == last) {
            ctx.decref(cap);
            break;
          }
          in_ = false;
          for (i = 0; i < pc.ranges.count; i++) {
            range = pc.ranges.head+i;
            //dd("testing %d for [%d, %d] (%u)", *sp, (int)range.from, (int)range.to, (unsigned) i);
            if (*sp >= range.from && *sp <= range.to) {
              in_ = true;
              break;
            }
          }
          if (!in_) {
            ctx.decref(cap);
            break;
          }
          rc = addThread(ctx, nlist, pc+1, cap, cast(int)(sp-input+1), &cap);
          if (rc == SRE_DONE) goto matched;
          if (rc != SRE_OK) {
            prog.tag = ctx.tag;
            return SRE_ERROR;
          }
          break;
        case Opcode.NotIn:
          if (sp == last) {
            ctx.decref(cap);
            break;
          }
          in_ = false;
          for (i = 0; i < pc.ranges.count; i++) {
            range = pc.ranges.head+i;
            //dd("testing %d for [%d, %d] (%u)", *sp, (int)range.from, (int)range.to, (unsigned) i);
            if (*sp >= range.from && *sp <= range.to) {
              in_ = true;
              break;
            }
          }
          if (in_) {
            ctx.decref(cap);
            break;
          }
          rc = addThread(ctx, nlist, pc+1, cap, cast(int)(sp-input+1), &cap);
          if (rc == SRE_DONE) goto matched;
          if (rc != SRE_OK) {
            prog.tag = ctx.tag;
            return SRE_ERROR;
          }
          break;
        case Opcode.Char:
          //dd("matching char '%c' (%d) against %d", sp != last ? *sp : '?', sp != last ? *sp : 0, pc.ch);
          if (sp == last || *sp != pc.ch) {
            ctx.decref(cap);
            break;
          }
          rc = addThread(ctx, nlist, pc+1, cap, cast(int)(sp-input+1), &cap);
          if (rc == SRE_DONE) goto matched;
          if (rc != SRE_OK) {
            prog.tag = ctx.tag;
            return SRE_ERROR;
          }
          break;
        case Opcode.Any:
          if (sp == last) {
            ctx.decref(cap);
            break;
          }
          rc = addThread(ctx, nlist, pc+1, cap, cast(int)(sp-input+1), &cap);
          if (rc == SRE_DONE) goto matched;
          if (rc != SRE_OK) {
            prog.tag = ctx.tag;
            return SRE_ERROR;
          }
          break;
        case Opcode.Assert:
          switch (pc.assertion) {
            case RegExpPart.AssType.StreamEnd:
              if (sp != last) break;
              goto assertion_hold;
            case RegExpPart.AssType.Eol:
              if (sp != last && *sp != '\n') break;
              //dd("dollar $ assertion hold: pos=%d", (int)(sp-input+ctx.processed_bytes));
              goto assertion_hold;
            case RegExpPart.AssType.NonWord:
              seen_word = (t.seen_word || (sp == input && ctx.seen_word));
              if (cast(ubyte)seen_word ^ cast(ubyte)(sp != last && isWordChar(*sp))) break;
              //dd("\\B assertion passed: %u %c", t.seen_word, *sp);
              goto assertion_hold;
            case RegExpPart.AssType.Word:
              seen_word = (t.seen_word || (sp == input && ctx.seen_word));
              if ((cast(ubyte)seen_word ^ cast(ubyte)(sp != last && isWordChar(*sp))) == 0) break;
              goto assertion_hold;
            default:
              /* impossible to reach here */
              break;
          }
          break;
         assertion_hold:
          ctx.tag--;
          list.head = null;
          list.count = 0;
          rc = addThread(ctx, &list, pc+1, cap, cast(int)(sp-input), null);
          if (rc != SRE_OK) {
            prog.tag = ctx.tag+1;
            return SRE_ERROR;
          }
          if (list.head) {
            *list.next = clist.head;
            clist.head = list.head;
            clist.count += list.count;
          }
          ctx.tag++;
          //dd("sp+1 == last: %d, eof: %u", sp+1 == last, eof);
          break;
        case Opcode.Match:
          ctx.last_matched_pos = cap.vector[1];
          cap.regex_id = pc.regex_id;
         matched:
          if (matched) {
            //dd("discarding match: ");
            ctx.decref(matched);
          }
          //dd("set matched, regex id: %d", (int)pc.regex_id);
          matched = cap;
          //PikeFreeThreadCtxT(ctx, t);
          mixin(PikeFreeThreadCtxT);
          clearThreadList(ctx, clist);
          goto step_done;
          /*
           * Jmp, Split, Save handled in addthread, so that
           * machine execution matches what a backtracker would do.
           * This is discussed (but not shown as code) in
           * Regular Expression Matching: the Virtual Machine Approach.
           */
        default:
          /* impossible to reach here */
          break;
      }
      //PikeFreeThreadCtxT(ctx, t);
      mixin(PikeFreeThreadCtxT);
    }
  step_done:
    tmp = clist;
    clist = nlist;
    nlist = tmp;
    if (nlist.head) clearThreadList(ctx, nlist);
    if (sp == last) break;
  }

  //dd("matched: %p, clist: %p, pos: %d", matched, clist.head, (int)(ctx.processed_bytes+(sp-input)));

  if (ctx.last_matched_pos >= 0) {
    p = input+ctx.last_matched_pos-ctx.processed_bytes;
    if (p > input) {
      //dd("diff: %d", (int)(ctx.last_matched_pos-ctx.processed_bytes));
      //dd("p=%p, input=%p", p, ctx.buffer);
      ctx.seen_newline = (p[-1] == '\n');
      ctx.seen_word = isWordChar(p[-1]);
      //dd("set seen newline: %u", ctx.seen_newline);
      //dd("set seen word: %u", ctx.seen_word);
    }
    ctx.last_matched_pos = -1;
  }

  prog.tag = ctx.tag;
  ctx.current_threads = clist;
  ctx.next_threads = nlist;

  if (matched) {
    if (eof || clist.head is null) {
      if (prepareMatchedCaptures(ctx, matched, ctx.ovector, ctx.ovecsize, true) != SRE_OK) return SRE_ERROR;

      if (clist.head) {
        *clist.next = ctx.free_threads;
        ctx.free_threads = clist.head;
        clist.head = null;
        clist.count = 0;
        ctx.eof = true;
      }

      ctx.processed_bytes = ctx.ovector[1];
      ctx.empty_capture = (ctx.ovector[0] == ctx.ovector[1]);

      ctx.matched = null;
      ctx.first_buf = true;

      rc = matched.regex_id;
      ctx.decref(matched);

      //dd("set empty capture: %u", ctx.empty_capture);

      return rc;
    }

    //dd("clist head cap == matched: %d", clist.head.capture == matched);

    if (pending_matched) {
      if (ctx.pending_ovector is null) {
        ctx.pending_ovector = pool.alloc!int(2*cast(uint)int.sizeof); //k8: -1 is safe here
        if (ctx.pending_ovector is null) return SRE_ERROR;
      }
      *pending_matched = ctx.pending_ovector;
      if (prepareMatchedCaptures(ctx, matched, *pending_matched, 2, false) != SRE_OK) return SRE_ERROR;
    }
  } else {
    if (eof) {
      ctx.eof = true;
      ctx.matched = null;
      return SRE_DECLINED;
    }
    if (pending_matched) *pending_matched = null;
  }

  ctx.processed_bytes += cast(int)(sp-input);

  //dd("processed bytes: %u", (unsigned) ctx.processed_bytes);

  ctx.matched = matched;

  prepareTempCaptures(prog, ctx);

  return SRE_AGAIN;
}


private void prepareTempCaptures (Program* prog, PikeCtx* ctx) {
  int a, b;
  uint ofs;
  CaptureRec* cap;
  PikeThread* t;

  ctx.ovector[0] = -1;
  ctx.ovector[1] = -1;

  for (t = ctx.current_threads.head; t; t = t.next) {
    cap = t.capture;
    ofs = 0;
    foreach (int i; 0..prog.nregexes) {
      a = ctx.ovector[0];
      b = cap.vector[ofs+0];
      //dd("%d: %d . %d", (int)0, (int)b, (int)a);
      if (b != -1 && (a == -1 || b < a)) {
        //dd("setting group %d to %d", (int)0, (int)cap.vector[0]);
        ctx.ovector[0] = b;
      }
      a = ctx.ovector[0+1];
      b = cap.vector[0+1];
      //dd("%d: %d . %d", (int)(0+1), (int)b, (int)a);
      if (b != -1 && (a == -1 || b > a)) {
        //dd("setting group %d to %d", (int)(0+1), (int)cap.vector[0+1]);
        ctx.ovector[0+1] = b;
      }
      ofs += 2*(prog.multi_ncaps[i]+1);
    }
  }
}


private PikeThreadList* treadListCreate (MemPool pool) {
  auto l = pool.alloc!PikeThreadList;
  if (l is null) return null;
  l.head = null;
  l.next = &l.head;
  l.count = 0;
  return l;
}


private int addThread (PikeCtx* ctx, PikeThreadList* l, VMInstr* pc, CaptureRec* capture, int pos, CaptureRec** pcap) {
  int rc;
  PikeThread* t;
  CaptureRec* cap;
  bool seen_word = false;

  if (pc.tag == ctx.tag) {
    //dd("pc %d: already on list: %d", (int)(pc-ctx.program.start), pc.tag);
    if (pc.opcode == Opcode.Split) {
      if (pc.y.tag != ctx.tag) {
        if (pc == ctx.program.start) {
          //dd("setting seen start state");
          ctx.seen_start_state = true;
        }
        return addThread(ctx, l, pc.y, capture, pos, pcap);
      }
    }
    return SRE_OK;
  }

  //dd("adding thread: pc %d, bytecode %d", (int)(pc-ctx.program.start), pc.opcode);

  pc.tag = ctx.tag;

  switch (pc.opcode) {
    case Opcode.Jump:
      return addThread(ctx, l, pc.x, capture, pos, pcap);

    case Opcode.Split:
      if (pc == ctx.program.start) {
        //dd("setting seen start state");
        ctx.seen_start_state = true;
      }

      ++capture.rc;

      rc = addThread(ctx, l, pc.x, capture, pos, pcap);
      if (rc != SRE_OK) {
          --capture.rc;
          return rc;
      }

      return addThread(ctx, l, pc.y, capture, pos, pcap);

    case Opcode.Save:
      //dd("save %u: processed bytes: %u, pos: %u", (unsigned) pc.group, (unsigned) ctx.processed_bytes, (unsigned) pos);
      cap = captureUpdate(ctx.pool, capture, pc.group, ctx.processed_bytes+pos, &ctx.free_capture);
      if (cap is null) return SRE_ERROR;
      return addThread(ctx, l, pc+1, cap, pos, pcap);

    case Opcode.Assert:
      switch (pc.assertion) {
        case RegExpPart.AssType.StreamStart:
          if (pos || ctx.processed_bytes) break;
          return addThread(ctx, l, pc+1, capture, pos, pcap);

        case RegExpPart.AssType.Bol:
          //dd("seen newline: %u", ctx.seen_newline);
          if (pos == 0) {
            if (ctx.processed_bytes && !ctx.seen_newline) break;
          } else {
            if (ctx.buffer[pos-1] != '\n') break;
          }
          //dd("newline assertion hold");
          return addThread(ctx, l, pc+1, capture, pos, pcap);

        case RegExpPart.AssType.Word:
        case RegExpPart.AssType.NonWord:
          if (pos == 0) {
            seen_word = false;
          } else {
            char c = ctx.buffer[pos-1];
            seen_word = isWordChar(c);
          }
          goto add;

        default:
          /* postpone look-ahead assertions */
          goto add;
      }
      break;

    case Opcode.Match:
      ctx.last_matched_pos = capture.vector[1];
      capture.regex_id = pc.regex_id;
      if (pcap) {
        *pcap = capture;
        return SRE_DONE;
      }
      goto default; //k8:???

    default:
     add:
      if (ctx.free_threads) {
        /* fprintf(stderr, "reusing free thread\n"); */
        t = ctx.free_threads;
        ctx.free_threads = t.next;
        t.next = null;
      } else {
        /* fprintf(stderr, "creating new thread\n"); */
        t = ctx.pool.alloc!PikeThread;
        if (t is null) return SRE_ERROR;
      }

      t.pc = pc;
      t.capture = capture;
      t.next = null;
      t.seen_word = seen_word;

      if (l.head is null) {
        l.head = t;
      } else {
        *l.next = t;
      }

      l.count++;
      l.next = &t.next;

      //dd("added thread: pc %d, bytecode %d", (int)(pc-ctx.program.start), pc.opcode);

      break;
  }

  return SRE_OK;
}


private int prepareMatchedCaptures (PikeCtx* ctx, CaptureRec* matched, int* ovector, size_t ovecsize, bool complete) {
  import core.stdc.string : memcpy, memset;

  Program* prog = ctx.program;
  uint ofs = 0;
  size_t len;

  if (matched.regex_id >= prog.nregexes) {
    //dd("bad regex id: %ld >= %ld", (long) matched.regex_id, (long) prog.nregexes);
    return SRE_ERROR;
  }

  if (ovecsize == 0) return SRE_OK;

  foreach (uint i; 0..matched.regex_id) ofs += prog.multi_ncaps[i]+1;

  ofs *= 2;

  if (complete) {
    len = 2*(prog.multi_ncaps[matched.regex_id]+1);
  } else {
    len = 2;
  }
  if (len > ovecsize) len = ovecsize;

  //dd("ncaps for regex %d: %d", (int)i, (int)prog.multi_ncaps[i]);
  //dd("matched captures: ofs: %d, len: %d", (int)ofs, (int)(len/sizeof(int)));

  memcpy(ovector, matched.vector+ofs, len*int.sizeof);

  if (!complete) return SRE_OK;

  if (ovecsize > len) memset(cast(char*)ovector+len*int.sizeof, -1, (ctx.ovecsize-len)*int.sizeof);

  return SRE_OK;
}


private const(char)* findFirstByte (const(char)* pos, const(char)* last, int leading_byte, Chain* leading_bytes) {
  bool in_;
  uint i;
  Chain* cl;
  VMInstr* pc;
  Range2VM* range;

  // optimize for single CHAR bc
  if (leading_byte != -1) {
    import core.stdc.string : memchr;
    pos = cast(char*)memchr(pos, leading_byte, last-pos);
    if (pos is null) return last;
    return pos;
  }

  for (; pos != last; pos++) {
    for (cl = leading_bytes; cl; cl = cl.next) {
      pc = cast(VMInstr*)cl.data;
      switch (pc.opcode) {
        case Opcode.Char:
          if (*pos == pc.ch) return pos;
          break;
        case Opcode.In:
          for (i = 0; i < pc.ranges.count; i++) {
            range = pc.ranges.head+i;
            if (*pos >= range.from && *pos <= range.to) return pos;
          }
          break;
        case Opcode.NotIn:
          in_ = false;
          for (i = 0; i < pc.ranges.count; i++) {
            range = pc.ranges.head+i;
            if (*pos >= range.from && *pos <= range.to) {
              in_ = true;
              break;
            }
          }
          if (!in_) return pos;
          break;
        default:
          assert(pc.opcode);
          break;
      }
    }
  }

  return pos;
}


private void clearThreadList (PikeCtx* ctx, PikeThreadList* list) {
  PikeThread* t;
  while (list.head) {
    t = list.head;
    list.head = t.next;
    list.count--;
    ctx.decref(t.capture);
    //PikeFreeThreadCtxT(ctx, t);
    mixin(PikeFreeThreadCtxT);
  }
  assert(list.count == 0);
}


void decref (PikeCtx* ctx, CaptureRec* cap) {
  pragma(inline, true);
  if (--cap.rc == 0) {
    cap.next = ctx.free_capture;
    ctx.free_capture = cap;
  }
}


private CaptureRec* captureCreate (MemPool pool, size_t ovecsize, uint clear, CaptureRec** freecap) {
  char* p;
  CaptureRec* cap;
  if (*freecap) {
    //dd("reusing cap %p", *freecap);
    cap = *freecap;
    *freecap = cap.next;
    cap.next = null;
    cap.rc = 1;
  } else {
    //pragma(msg, CaptureRec.sizeof);
    //writeln(ovecsize);
    p = pool.alloc!char(cast(uint)CaptureRec.sizeof+ovecsize);
    if (p is null) return null;
    cap = cast(CaptureRec*)p;
    cap.ovecsize = ovecsize;
    cap.rc = 1;
    cap.next = null;
    cap.regex_id = 0;
    p += CaptureRec.sizeof;
    cap.vector = cast(int*)p;
  }
  if (clear) {
    import core.stdc.string : memset;
    memset(cap.vector, -1, ovecsize);
  }
  return cap;
}


private CaptureRec* captureUpdate (MemPool pool, CaptureRec* cap, uint group, int pos, CaptureRec** freecap) {
  CaptureRec* newcap;
  //dd("update cap %u to %d", group, pos);
  if (cap.rc > 1) {
    import core.stdc.string : memcpy;
    newcap = captureCreate(pool, cap.ovecsize, 0, freecap);
    if (newcap is null) return null;
    memcpy(newcap.vector, cap.vector, cap.ovecsize);
    --cap.rc;
    //dd("!! cap %p: set group %u to %d", newcap, group, pos);
    newcap.vector[group] = pos;
    return newcap;
  }
  //dd("!! cap %p: set group %u to %d", cap, group, pos);
  cap.vector[group] = pos;
  return cap;
}
