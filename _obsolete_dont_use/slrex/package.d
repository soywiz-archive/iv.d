/*
 * Copyright (c) 2004-2013 Sergey Lyubka <valenok@gmail.com>
 * Copyright (c) 2013 Cesanta Software Limited
 * All rights reserved
 *
 * This library is dual-licensed: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation. For the terms of this
 * license, see <http://www.gnu.org/licenses/>.
 *
 * You are free to use this library under the terms of the GNU General
 * Public License, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * Alternatively, you can license this library under a commercial
 * license, as set out in <http://cesanta.com/products.html>.
 */
/*
 * This is a regular expression library that implements a subset of Perl RE.
 * Please refer to README.md for a detailed reference.
 */
module iv.slrex;

enum isGoodSlreRange(T) =
  is(typeof({ auto t = T.init; long len = t.length; })) &&
  is(typeof({ auto t = T.init; char ch = t[2]; }));


struct Slre {
  static struct Capture {
    int ofs, len;
  }

  // possible flags for match()
  enum Flag {
    IgnoreCase = 1<<0,
    Multiline = 1<<1, // without this, dot will match '\n', and so on
  }

  // match() failure codes
  enum Result : int {
    Ok = 0,
    NoMatch = -1,
    UnexpectedQuantifier = -2,
    UnbalancedBrackets = -3,
    InternalError = -4,
    InvalidCharset = -5,
    InvalidMetaChar = -6,
    CapsArrayTooSmall = -7,
    TooManyBranches = -8,
    TooManyBrackets = -9,
    StringTooBig = -10,
    RegexpTooBig = -11,
  }

  /* Matches the string buffer `s` against the regular expression `regexp`,
   * which should conform the syntax. If the regular expression `regexp`
   * contains brackets, `match()` can capture the respective substrings
   * into the array of `Capture` structures.
   *
   * Returns the number of bytes scanned from the beginning of the string.
   * If the return value is greater or equal to 0, there is a match.
   * If the return value is less then 0, there is no match, and error is from `Result` enum.
   *
   * `flags` is a bitset of `Flag`s.
   * `sofs` is offset of the first matched byte
   */
  public static int matchFirst(RR, RS) (RR regexp, RS s, Capture[] caps=null, int flags=0, int *sofs=null)
  if (isGoodSlreRange!RR && isGoodSlreRange!RS)
  {
    if (s.length > int.max-1) return Result.StringTooBig;
    if (regexp.length > int.max-1) return Result.RegexpTooBig;
    int dummy;
    if (sofs is null) sofs = &dummy;
    *sofs = -1;

    regex_info info;
    info.flags = flags;
    info.num_brackets = info.num_branches = 0;
    info.caps = caps[];
    info.sofs = sofs;

    //DBG(("========================> [%s] [%.*s]\n", regexp, s_len, s));
    foreach (ref cp; caps) { cp.ofs = 0; cp.len = -1; }
    return foo(XString!(typeof(regexp))(regexp), XString!(typeof(s))(s), &info);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:
char tolower (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= 'A' && ch <= 'Z' ? cast(char)(ch-'A'+'a') : ch); }
bool isxdigit (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f') || (ch >= '0' && ch <= '9')); }
bool iswordchar (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_'); }


enum MAX_BRANCHES = 100;
enum MAX_BRACKETS = 100;


struct bracket_pair {
  int ptrofs;       // points to the first char after '(' in regex
  int len;          // length of the text between '(' and ')'
  int branches;     // index in the branches array for this pair
  int num_branches; // number of '|' in this bracket pair
}

struct branch {
  int bracket_index; // index for 'struct bracket_pair brackets' array defined below
  int schlongofs; // points to the '|' character in the regex
}

struct regex_info {
  // describes all bracket pairs in the regular expression; first entry is always present, and grabs the whole regex
  bracket_pair[MAX_BRACKETS] brackets;
  int num_brackets;

  // describes alternations ('|' operators) in the regular expression; each branch falls into a specific branch pair
  branch[MAX_BRANCHES] branches;
  int num_branches;

  // array of captures provided by the user
  Slre.Capture[] caps;

  // e.g. Slre.Flag.IgnoreCase
  int flags;

  int* sofs; // starting offset of the match
}


struct XString(T) {
  T rng;
  int curofs;
  int len;
  this (T arng) { rng = arng; len = cast(int)rng.length; }
  this (T arng, int aofs, int alen) {
    rng = arng;
    if (aofs < 0 || alen < 1 || aofs >= arng.length) {
      curofs = 0;
      len = 0;
    } else {
      curofs = aofs;
      if (rng.length-aofs < alen) alen = cast(int)(rng.length-aofs);
      len = alen;
    }
  }
  char opIndex (size_t pos) {
    if (pos >= len) return 0;
    return rng[curofs+cast(int)pos];
  }
  //@property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (len < 1); }
  //@property char front () { return (len > 0 ? rng[curofs] : 0); }
  //void popFront () pure nothrow @safe @nogc { if (len > 0) { ++curofs; --len; } }
  @property int length () const pure nothrow @safe @nogc { pragma(inline, true); return len; }
  alias opDollar = length;
  auto opBinary(string op : "+") (int n) {
    if (n < 0) assert(0);
    if (n > len) n = len;
    return typeof(this)(rng, curofs+n, len-n);
  }
  void opOpAssign(string op : "+") (int n) {
    if (n < 0) assert(0);
    if (n > len) n = len;
    curofs += n;
    len -= n;
  }
  auto opSlice (size_t lo, size_t hi) {
    if (hi > len) hi = len;
    if (len < 1 || lo >= len || lo >= hi) return typeof(this)(rng, 0, 0);
    return typeof(this)(rng, cast(int)(curofs+lo), cast(int)(hi-lo));
  }
  auto origin () { return typeof(this)(rng); }
  debug(slrex) string toString () const { return (len > 0 ? rng[curofs..curofs+len].idup : ""); }
}


bool is_metacharacter (char stc) pure nothrow @safe @nogc {
  foreach (char ch; "^$().[]*+?|\\Ssdbfnrtv") if (stc == ch) return true;
  return false;
}

bool is_quantifier (char ch) pure nothrow @safe @nogc {
  pragma(inline, true);
  return (ch == '*' || ch == '+' || ch == '?');
}

int op_len(XS) (XS re) {
  return (re[0] == '\\' && re[1] == 'x' ? 4 : re[0] == '\\' ? 2 : 1);
}

int set_len(XS) (XS re) {
  int len = 0;
  while (len < re.length && re[len] != ']') len += op_len(re+len);
  return (len <= re.length ? len+1 : -1);
}

int get_op_len(XS) (XS re) {
  return (re[0] == '[' ? set_len(re+1)+1 : op_len(re));
}

int xtoi (int x) {
  return
    x >= '0' && x <= '9' ? x-'0' :
    x >= 'A' && x <= 'F' ? x-'A'+10 :
    x >= 'a' && x <= 'f' ? x-'a'+10 :
    0;
}

int hextoi(XS) (XS s) {
  return (xtoi(s[0])<<4)|xtoi(s[1]);
}


int match_op(XS, SS) (XS re, SS s, regex_info* info) {
  int result = 0;
  if (s.length == 0) return Slre.Result.NoMatch;
  switch (re[0]) {
    case '\\':
      // metacharacters
      switch (re[1]) {
        case 'S': if (s[0] <= ' ') return Slre.Result.NoMatch; ++result; break;
        case 's': if (s[0] > ' ') return Slre.Result.NoMatch; ++result; break;
        case 'd': if (s[0] < '0' || s[0] > '9') return Slre.Result.NoMatch; ++result; break;
        case 'b': // word boundary
          if (!iswordchar(s[0])) {
            // non-word char: check next char
            if (s.curofs > 0 && !iswordchar(s.origin[s.curofs-1])) return Slre.Result.NoMatch;
          } else {
            // word char: check previous char
            if (s.curofs > 0 && iswordchar(s.origin[s.curofs-1])) return Slre.Result.NoMatch;
          }
          //++result;
          break;
        case 'f': if (s[0] != '\f') return Slre.Result.NoMatch; ++result; break;
        case 'n': if (s[0] != '\n') return Slre.Result.NoMatch; ++result; break;
        case 'r': if (s[0] != '\r') return Slre.Result.NoMatch; ++result; break;
        case 't': if (s[0] != '\t') return Slre.Result.NoMatch; ++result; break;
        case 'v': if (s[0] != '\v') return Slre.Result.NoMatch; ++result; break;
        case 'x':
          // match byte, \xHH where HH is hexadecimal byte representaion
          if (hextoi(re+2) != s[0]) return Slre.Result.NoMatch;
          ++result;
          break;
        default:
          // valid metacharacter check is done in bar()
          if (re[1] != s[0]) return Slre.Result.NoMatch;
          ++result;
          break;
      }
      break;
    case '|': return Slre.Result.InternalError;
    case '$': return Slre.Result.NoMatch;
    case '.': ++result; break;
    default:
      if (info.flags&Slre.Flag.IgnoreCase) {
        if (tolower(re[0]) != tolower(s[0])) return Slre.Result.NoMatch;
      } else {
        if (re[0] != s[0]) return Slre.Result.NoMatch;
      }
      ++result;
      break;
  }
  return (result <= s.length ? result : Slre.Result.NoMatch);
}


int match_set(XS, SS) (XS re, SS s, regex_info* info) {
  debug(slre) { import std.stdio; writeln("match_set: re=<", re, ">; s=<", s, ">"); }
  int len = 0, result = -1;
  bool invert = (re[0] == '^');
  if (invert) {
    re += 1;
    debug(slre) { import std.stdio; writeln("  INV: re=<", re, ">; s=<", s, ">"); }
  }
  while (len <= re.length && re[len] != ']' && result <= 0) {
    // support character range
    if (re[len] != '-' && re[len+1] == '-' && re[len+2] != ']' && re[len+2] != '\0') {
      result = info.flags&Slre.Flag.IgnoreCase ?
        tolower(s[0]) >= tolower(re[len]) && tolower(s[0]) <= tolower(re[len+2]) :
        s[0] >= re[len] && s[0] <= re[len+2];
      len += 3;
    } else {
      result = match_op(re+len, s, info);
      len += op_len(re+len);
    }
  }
  return ((!invert && result > 0) || (invert && result <= 0) ? 1 : -1);
}


int bar(XS, SS) (XS re, SS s, regex_info* info, int bi) {
  // i is offset in re, j is offset in s, bi is brackets index
  int i, j, n, step;
  for (i = j = 0; i < re.length && j <= s.length; i += step) {
    // handle quantifiers; get the length of the chunk
    step = (re[i] == '(' ? info.brackets[bi+1].len+2 : get_op_len(re+i));
    debug(slre) { import std.stdio; writefln("%s <%s> <%s> re_len=%s step=%s i=%s j=%s", "bar", re+i, s+j, re.length, step, i, j); }
    if (is_quantifier(re[i])) return Slre.Result.UnexpectedQuantifier;
    if (step <= 0) return Slre.Result.InvalidCharset;

    if (i+step < re.length && is_quantifier(re[i+step])) {
      //DBG(("QUANTIFIER: [%.s[0]]%c [%.s[0]]\n", step, re+i, re[i+step], s_len-j, s+j));
      if (re[i+step] == '?') {
        int result = bar(re[i..i+step], s+j, info, bi);
        j += (result > 0 ? result : 0);
        ++i;
      } else if (re[i+step] == '+' || re[i+step] == '*') {
        int j2 = j, nj = j, n1, n2 = -1, ni;
        bool non_greedy = false;
        // points to the regexp code after the quantifier
        ni = i+step+1;
        if (ni < re.length && re[ni] == '?') {
          non_greedy = true;
          ++ni;
        }
        do {
          if ((n1 = bar(re[i..i+step], s+j2, info, bi)) > 0) j2 += n1;
          if (re[i+step] == '+' && n1 < 0) break;
          if (ni >= re.length) {
            // after quantifier, there is nothing
            nj = j2;
          } else if ((n2 = bar(re+ni, s+j2, info, bi)) >= 0) {
            // regex after quantifier matched
            nj = j2+n2;
          }
          if (nj > j && non_greedy) break;
        } while (n1 > 0);
        // even if we found one or more pattern, this branch will be executed, changing the next captures
        if (n1 < 0 && n2 < 0 && re[i+step] == '*' && (n2 = bar(re+ni, s+j, info, bi)) > 0) nj = j+n2;
        //DBG(("STAR/PLUS END: %d %d %d %d %d\n", j, nj, re_len-ni, n1, n2));
        if (re[i+step] == '+' && nj == j) return Slre.Result.NoMatch;
        // if while loop body above was not executed for the * quantifier, make sure the rest of the regex matches
        if (nj == j && ni < re.length && n2 < 0) return Slre.Result.NoMatch;
        // returning here cause we've matched the rest of RE already
        return nj;
      }
      continue;
    }

    if (re[i] == '[') {
      n = match_set(re+i+1, s+j, info);
      debug(slre) { import std.stdio; writefln("SET <%s> <%s> . %s", re[i..i+step], s+j, n); }
      if (n <= 0) {
        debug(slre) { import std.stdio; writeln("  NO SET MATCH"); }
        return Slre.Result.NoMatch;
      }
      j += n;
    } else if (re[i] == '(') {
      n = Slre.Result.NoMatch;
      ++bi;
      if (bi >= info.num_brackets) return Slre.Result.InternalError;
      //DBG(("CAPTURING [%.s[0]] [%.s[0]] [%s]\n", step, re+i, s_len-j, s+j, re+i+step));
      if (re.length-(i+step) <= 0) {
        // nothing follows brackets
        n = doh(re, s+j, info, bi);
      } else {
        int j2;
        for (j2 = 0; j2 <= s.length-j; ++j2) {
          if ((n = doh(re, s[j..$-(j+j2)+1], info, bi)) >= 0 && bar(re+i+step, s+j+n, info, bi) >= 0) break;
        }
      }
      //DBG(("CAPTURED [%.s[0]] [%.s[0]]:%d\n", step, re+i, s_len-j, s+j, n));
      if (n < 0) return n;
      if (/*info.caps.length &&*/ n > 0 && bi-1 >= 0 && bi-1 < info.caps.length) {
        //info.caps[bi-1].ptr = s+j;
        //info.caps[bi-1].len = n;
        info.caps[bi-1].ofs = s.curofs+j;
        info.caps[bi-1].len = n;
      }
      j += n;
    } else if (re[i] == '^') {
      if (j != 0) return Slre.Result.NoMatch;
    } else if (re[i] == '$') {
      if (j != s.length) {
        debug(slre) { import std.stdio; writefln("NOT DOLLAR <%s> <%s> s_len=%s j=%s", re+i, s+j, s.length, j); }
        return Slre.Result.NoMatch;
      }
      debug(slre) { import std.stdio; writefln("DOLLAR <%s> <%s> s_len=%s j=%s", re+i, s+j, s.length, j); }
    } else {
      if (j >= s.length) return Slre.Result.NoMatch;
      n = match_op(re+i, s+j, info);
      //if (n <= 0) return n;
      if (n < 0) return n;
      j += n;
    }
  }

  return j;
}


// process branch points
int doh(XS, SS) (XS re, SS s, regex_info* info, int bi) {
  const(bracket_pair)* b = info.brackets.ptr+bi;
  int i = 0, len, result;
  //const(char)* p;
  XS p;
  do {
    //p = (i == 0 ? b.ptr : info.branches[b.branches+i-1].schlong+1);
    p = (i == 0 ? re.origin+b.ptrofs : re.origin+info.branches[b.branches+i-1].schlongofs+1);
    len = b.num_branches == 0 ? b.len :
      i == b.num_branches ? cast(int)(b.ptrofs+b.len-p.curofs) :
      cast(int)(info.branches[b.branches+i].schlongofs-p.curofs);
    //DBG(("%s %d %d [%.s[0]] [%.s[0]]\n", __func__, bi, i, len, p, s_len, s));
    result = bar(p[0..len], s, info, bi);
    //DBG(("%s <- %d\n", __func__, result));
  } while (result <= 0 && i++ < b.num_branches); // at least 1 iteration
  return result;
}


int baz(XS, SS) (XS re, SS s, regex_info* info) {
  int result = -1;
  bool is_anchored = (re.origin[info.brackets[0].ptrofs] == '^');
  *info.sofs = -1;
  if (info.flags&Slre.Flag.Multiline) {
    int spos = 0;
    while (spos <= s.length) {
      // find EOL
      int epos = spos;
      while (epos < s.length && s[epos] != '\n') ++epos;
     tryagain:
      result = doh(re, s[spos..epos], info, 0);
      if (result >= 0) { *info.sofs = spos; result += spos; break; }
      if (is_anchored) {
        // skip to next line
        if (epos >= s.length) {
          result = doh(re, s[spos..epos], info, 0);
          if (result >= 0) { *info.sofs = spos; result += spos; break; }
          break;
        }
        spos = epos+1;
      } else {
        if (++spos <= epos) goto tryagain;
      }
    }
  } else {
    for (int i = 0; i <= s.length; ++i) {
      result = doh(re, s+i, info, 0);
      if (result >= 0) { *info.sofs = i; result += i; break; }
      if (is_anchored) break;
    }
  }
  return result;
}


void setup_branch_points (regex_info* info) {
  int i, j;
  branch tmp;

  // first, sort branches; must be stable, no qsort --> use bubble algo (k8: lol)
  for (i = 0; i < info.num_branches; ++i) {
    for (j = i+1; j < info.num_branches; ++j) {
      if (info.branches[i].bracket_index > info.branches[j].bracket_index) {
        tmp = info.branches[i];
        info.branches[i] = info.branches[j];
        info.branches[j] = tmp;
      }
    }
  }

  /*
   * For each bracket, set their branch points. This way, for every bracket
   * (i.e. every chunk of regex) we know all branch points before matching.
   */
  for (i = j = 0; i < info.num_brackets; ++i) {
    info.brackets[i].num_branches = 0;
    info.brackets[i].branches = j;
    while (j < info.num_branches && info.branches[j].bracket_index == i) {
      ++info.brackets[i].num_branches;
      ++j;
    }
  }
}


int foo(XS, SS) (XS re, SS s, regex_info* info) {
  int i, step, depth = 0;

  // first bracket captures everything
  info.brackets[0].ptrofs = re.curofs;
  info.brackets[0].len = re.length;
  info.num_brackets = 1;

  // make a single pass over regex string, memorize brackets and branches
  for (i = 0; i < re.length; i += step) {
    step = get_op_len(re+i);
    if (re[i] == '|') {
      if (info.num_branches >= info.branches.length) return Slre.Result.TooManyBranches;
      info.branches[info.num_branches].bracket_index = (info.brackets[info.num_brackets-1].len == -1 ? info.num_brackets-1 : depth);
      info.branches[info.num_branches].schlongofs = re.curofs+i;
      ++info.num_branches;
    } else if (re[i] == '\\') {
      if (i >= re.length-1) return Slre.Result.InvalidMetaChar;
      if (re[i+1] == 'x') {
        // hex digit specification must follow
        if (re[i+1] == 'x' && i >= re.length-3) return Slre.Result.InvalidMetaChar;
        if (re[i+1] == 'x' && !(isxdigit(re[i+2]) && isxdigit(re[i+3]))) return Slre.Result.InvalidMetaChar;
      } else {
        if (!is_metacharacter(re[i+1])) return Slre.Result.InvalidMetaChar;
      }
    } else if (re[i] == '(') {
      if (info.num_brackets >= info.brackets.length) return Slre.Result.TooManyBrackets;
      ++depth; // order is important here; depth increments first
      info.brackets[info.num_brackets].ptrofs = re.curofs+i+1;
      info.brackets[info.num_brackets].len = -1;
      ++info.num_brackets;
      //!if (info.caps.length && info.num_brackets-1 > info.caps.length) return Slre.Result.CapsArrayTooSmall;
    } else if (re[i] == ')') {
      int ind = (info.brackets[info.num_brackets-1].len == -1 ? info.num_brackets-1 : depth);
      info.brackets[ind].len = re.curofs+i-info.brackets[ind].ptrofs;
      //{ import std.stdio; writefln("SETTING BRACKET %s [%s[0]]", ind, re.origin[info.brackets[ind].ptrofs..info.brackets[ind].ptrofs+info.brackets[ind].len]); }
      --depth;
      if (depth < 0) return Slre.Result.UnbalancedBrackets;
      if (i > 0 && re[i-1] == '(') return Slre.Result.NoMatch;
    }
  }

  if (depth != 0) return Slre.Result.UnbalancedBrackets;
  setup_branch_points(info);

  return baz(re, s, info);
}
