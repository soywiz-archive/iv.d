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
module iv.slre;

struct Slre {
  static struct Capture {
    const(char)[] ptr;
    int ofs, len;
  }

  // possible flags for match()
  enum Flag {
    IgnoreCase = 1<<0,
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
   * into the array of `slre_cap` structures.
   *
   * Returns the number of bytes scanned from the beginning of the string.
   * If the return value is greater or equal to 0, there is a match.
   * If the return value is less then 0, there is no match, and error is from `Result` enum.
   *
   * `flags` is a bitset of `Flag`s.
   */
  public static int matchFirst (const(char)[] regexp, const(char)[] s, Capture[] caps, int flags=0) {
    if (s.length > int.max-1) return Result.StringTooBig;
    if (regexp.length > int.max-1) return Result.RegexpTooBig;

    regex_info info;
    info.flags = flags;
    info.num_brackets = info.num_branches = 0;
    info.num_caps = (caps.length < MAX_BRACKETS ? cast(int)caps.length : MAX_BRACKETS);
    info.caps = caps.ptr;

    //DBG(("========================> [%s] [%.*s]\n", regexp, s_len, s));
    foreach (ref cp; caps) { cp.ptr = null; cp.ofs = cp.len = 0; }
    auto res = foo(regexp.ptr, cast(int)regexp.length, s.ptr, cast(int)s.length, &info);
    // fix captures
    foreach (ref cp; caps) {
      if (cp.ptr.ptr !is null) {
        cp.ofs = cast(int)(cp.ptr.ptr-s.ptr);
        cp.len = cast(int)cp.ptr.length;
      }
    }
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:
char tolower (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return (ch >= 'A' && ch <= 'Z' ? cast(char)(ch-'A'+'a') : ch); }
bool isxdigit (char ch) pure nothrow @trusted @nogc { pragma(inline, true); return ((ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f') || (ch >= '0' && ch <= '9')); }


enum MAX_BRANCHES = 100;
enum MAX_BRACKETS = 100;
//#define FAIL_IF(condition, error_code) if (condition) return (error_code)


struct bracket_pair {
  const(char)* ptr; // points to the first char after '(' in regex
  int len;          // length of the text between '(' and ')'
  int branches;     // index in the branches array for this pair
  int num_branches; // number of '|' in this bracket pair
}

struct branch {
  int bracket_index; // index for 'struct bracket_pair brackets' array defined below
  const(char)* schlong; // points to the '|' character in the regex
}

struct regex_info {
  /*
   * Describes all bracket pairs in the regular expression.
   * First entry is always present, and grabs the whole regex.
   */
  bracket_pair[MAX_BRACKETS] brackets;
  int num_brackets;

  /*
   * Describes alternations ('|' operators) in the regular expression.
   * Each branch falls into a specific branch pair.
   */
  branch[MAX_BRANCHES] branches;
  int num_branches;

  /* Array of captures provided by the user */
  Slre.Capture* caps;
  int num_caps;

  /* E.g. Slre.Flag.IgnoreCase. See enum below */
  int flags;
}


bool is_metacharacter (const(char)* s) nothrow @nogc {
  import core.stdc.string : memchr;
  static immutable string metacharacters = "^$().[]*+?|\\Ssdbfnrtv";
  return (memchr(metacharacters.ptr, *s, metacharacters.length) !is null);
}

int op_len (const(char)* re) {
  return (re[0] == '\\' && re[1] == 'x' ? 4 : re[0] == '\\' ? 2 : 1);
}

int set_len (const(char)* re, int re_len) {
  int len = 0;
  while (len < re_len && re[len] != ']') len += op_len(re+len);
  return (len <= re_len ? len+1 : -1);
}

int get_op_len (const(char)* re, int re_len) {
  return (re[0] == '[' ? set_len(re+1, re_len-1)+1 : op_len(re));
}

bool is_quantifier (const(char)* re) {
  return (re[0] == '*' || re[0] == '+' || re[0] == '?');
}

int xtoi (int x) {
  return
    x >= '0' && x <= '9' ? x-'0' :
    x >= 'A' && x <= 'F' ? x-'A'+10 :
    x >= 'a' && x <= 'f' ? x-'a'+10 :
    0;
}

int hextoi (const(char)* s) {
  return (xtoi(s[0])<<4)|xtoi(s[1]);
}


int match_op (const(char)* re, const(char)* s, regex_info* info) {
  int result = 0;
  switch (*re) {
    case '\\':
      // metacharacters
      switch (re[1]) {
        case 'S': if (*s == 0 || *s <= ' ') return Slre.Result.NoMatch; ++result; break;
        case 's': if (*s == 0 || *s > ' ') return Slre.Result.NoMatch; ++result; break;
        case 'd': if (*s < '0' || *s > '9') return Slre.Result.NoMatch; ++result; break;
        case 'b': if (*s != '\b') return Slre.Result.NoMatch; ++result; break;
        case 'f': if (*s != '\f') return Slre.Result.NoMatch; ++result; break;
        case 'n': if (*s != '\n') return Slre.Result.NoMatch; ++result; break;
        case 'r': if (*s != '\r') return Slre.Result.NoMatch; ++result; break;
        case 't': if (*s != '\t') return Slre.Result.NoMatch; ++result; break;
        case 'v': if (*s != '\v') return Slre.Result.NoMatch; ++result; break;
        case 'x':
          // match byte, \xHH where HH is hexadecimal byte representaion
          if (hextoi(re+2) != *s) return Slre.Result.NoMatch;
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
        if (tolower(*re) != tolower(*s)) return Slre.Result.NoMatch;
      } else {
        if (*re != *s) return Slre.Result.NoMatch;
      }
      ++result;
      break;
  }
  return result;
}


int match_set (const(char)* re, size_t re_len, const(char)* s, regex_info* info) {
  int len = 0, result = -1;
  bool invert = (re[0] == '^');
  if (invert) { ++re; --re_len; }
  while (len <= re_len && re[len] != ']' && result <= 0) {
    // support character range
    if (re[len] != '-' && re[len+1] == '-' && re[len+2] != ']' && re[len+2] != '\0') {
      result = info.flags&Slre.Flag.IgnoreCase ?
        tolower(*s) >= tolower(re[len]) && tolower(*s) <= tolower(re[len+2]) :
        *s >= re[len] && *s <= re[len+2];
      len += 3;
    } else {
      result = match_op(re+len, s, info);
      len += op_len(re+len);
    }
  }
  return ((!invert && result > 0) || (invert && result <= 0) ? 1 : -1);
}


int bar (const(char)* re, size_t re_len, const(char)* s, size_t s_len, regex_info* info, int bi) {
  // i is offset in re, j is offset in s, bi is brackets index
  int i, j, n, step;
  for (i = j = 0; i < re_len && j <= s_len; i += step) {
    // handle quantifiers; get the length of the chunk
    step = (re[i] == '(' ? info.brackets[bi+1].len+2 : get_op_len(re+i, re_len-i));
    //DBG(("%s [%.*s] [%.*s] re_len=%d step=%d i=%d j=%d\n", __func__, re_len-i, re+i, s_len-j, s+j, re_len, step, i, j));
    if (is_quantifier(&re[i])) return Slre.Result.UnexpectedQuantifier;
    if (step <= 0) return Slre.Result.InvalidCharset;

    if (i+step < re_len && is_quantifier(re+i+step)) {
      //DBG(("QUANTIFIER: [%.*s]%c [%.*s]\n", step, re+i, re[i+step], s_len-j, s+j));
      if (re[i+step] == '?') {
        int result = bar(re+i, step, s+j, s_len-j, info, bi);
        j += (result > 0 ? result : 0);
        ++i;
      } else if (re[i+step] == '+' || re[i+step] == '*') {
        int j2 = j, nj = j, n1, n2 = -1, ni, non_greedy = 0;
        // points to the regexp code after the quantifier
        ni = i+step+1;
        if (ni < re_len && re[ni] == '?') {
          non_greedy = 1;
          ++ni;
        }
        do {
          if ((n1 = bar(re+i, step, s+j2, s_len-j2, info, bi)) > 0) j2 += n1;
          if (re[i+step] == '+' && n1 < 0) break;
          if (ni >= re_len) {
            // after quantifier, there is nothing
            nj = j2;
          } else if ((n2 = bar(re+ni, re_len-ni, s+j2, s_len-j2, info, bi)) >= 0) {
            // regex after quantifier matched
            nj = j2+n2;
          }
          if (nj > j && non_greedy) break;
        } while (n1 > 0);
        // even if we found one or more pattern, this branch will be executed, changing the next captures
        if (n1 < 0 && n2 < 0 && re[i+step] == '*' && (n2 = bar(re+ni, re_len-ni, s+j, s_len-j, info, bi)) > 0) nj = j+n2;
        //DBG(("STAR/PLUS END: %d %d %d %d %d\n", j, nj, re_len-ni, n1, n2));
        if (re[i+step] == '+' && nj == j) return Slre.Result.NoMatch;
        // if while loop body above was not executed for the * quantifier, make sure the rest of the regex matches
        if (nj == j && ni < re_len && n2 < 0) return Slre.Result.NoMatch;
        // returning here cause we've matched the rest of RE already
        return nj;
      }
      continue;
    }

    if (re[i] == '[') {
      n = match_set(re+i+1, re_len-(i+2), s+j, info);
      //DBG(("SET %.*s [%.*s] . %d\n", step, re+i, s_len-j, s+j, n));
      if (n <= 0) return Slre.Result.NoMatch;
      j += n;
    } else if (re[i] == '(') {
      n = Slre.Result.NoMatch;
      ++bi;
      if (bi >= info.num_brackets) return Slre.Result.InternalError;
      //DBG(("CAPTURING [%.*s] [%.*s] [%s]\n", step, re+i, s_len-j, s+j, re+i+step));
      if (re_len-(i+step) <= 0) {
        // nothing follows brackets
        n = doh(s+j, s_len-j, info, bi);
      } else {
        int j2;
        for (j2 = 0; j2 <= s_len-j; ++j2) {
          if ((n = doh(s+j, s_len-(j+j2), info, bi)) >= 0 && bar(re+i+step, re_len-(i+step), s+j+n, s_len-(j+n), info, bi) >= 0) break;
        }
      }
      //DBG(("CAPTURED [%.*s] [%.*s]:%d\n", step, re+i, s_len-j, s+j, n));
      if (n < 0) return n;
      if (info.caps !is null && n > 0) {
        //info.caps[bi-1].ptr = s+j;
        //info.caps[bi-1].len = n;
        info.caps[bi-1].ptr = s[j..j+n];
      }
      j += n;
    } else if (re[i] == '^') {
      if (j != 0) return Slre.Result.NoMatch;
    } else if (re[i] == '$') {
      if (j != s_len) return Slre.Result.NoMatch;
    } else {
      if (j >= s_len) return Slre.Result.NoMatch;
      n = match_op(re+i, s+j, info);
      if (n <= 0) return n;
      j += n;
    }
  }

  return j;
}


// process branch points
int doh (const(char)* s, size_t s_len, regex_info* info, int bi) {
  const(bracket_pair)* b = &info.brackets[bi];
  int i = 0, len, result;
  const(char)* p;
  do {
    p = (i == 0 ? b.ptr : info.branches[b.branches+i-1].schlong+1);
    len = b.num_branches == 0 ? b.len :
      i == b.num_branches ? cast(int)(b.ptr+b.len-p) :
      cast(int)(info.branches[b.branches+i].schlong-p);
    //DBG(("%s %d %d [%.*s] [%.*s]\n", __func__, bi, i, len, p, s_len, s));
    result = bar(p, len, s, s_len, info, bi);
    //DBG(("%s <- %d\n", __func__, result));
  } while (result <= 0 && i++ < b.num_branches); // at least 1 iteration
  return result;
}


int baz (const(char)* s, size_t s_len, regex_info* info) {
  int i, result = -1;
  bool is_anchored = (info.brackets[0].ptr[0] == '^');
  for (i = 0; i <= s_len; ++i) {
    result = doh(s+i, s_len-i, info, 0);
    if (result >= 0) { result += i; break; }
    if (is_anchored) break;
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


int foo (const(char)* re, size_t re_len, const(char)* s, size_t s_len, regex_info* info) {
  int i, step, depth = 0;

  // first bracket captures everything
  info.brackets[0].ptr = re;
  info.brackets[0].len = re_len;
  info.num_brackets = 1;

  // make a single pass over regex string, memorize brackets and branches
  for (i = 0; i < re_len; i += step) {
    step = get_op_len(re+i, re_len-i);
    if (re[i] == '|') {
      if (info.num_branches >= info.branches.length) return Slre.Result.TooManyBranches;
      info.branches[info.num_branches].bracket_index = (info.brackets[info.num_brackets-1].len == -1 ? info.num_brackets-1 : depth);
      info.branches[info.num_branches].schlong = &re[i];
      ++info.num_branches;
    } else if (re[i] == '\\') {
      if (i >= re_len-1) return Slre.Result.InvalidMetaChar;
      if (re[i+1] == 'x') {
        // hex digit specification must follow
        if (re[i+1] == 'x' && i >= re_len-3) return Slre.Result.InvalidMetaChar;
        if (re[i+1] ==  'x' && !(isxdigit(re[i+2]) && isxdigit(re[i+3]))) return Slre.Result.InvalidMetaChar;
      } else {
        if (!is_metacharacter(re+i+1)) return Slre.Result.InvalidMetaChar;
      }
    } else if (re[i] == '(') {
      if (info.num_brackets >= info.brackets.length) return Slre.Result.TooManyBrackets;
      ++depth; // order is important here; depth increments first
      info.brackets[info.num_brackets].ptr = re+i+1;
      info.brackets[info.num_brackets].len = -1;
      ++info.num_brackets;
      if (info.num_caps > 0 && info.num_brackets-1 > info.num_caps) return Slre.Result.CapsArrayTooSmall;
    } else if (re[i] == ')') {
      int ind = (info.brackets[info.num_brackets-1].len == -1 ? info.num_brackets-1 : depth);
      info.brackets[ind].len = cast(int)(&re[i]-info.brackets[ind].ptr);
      //DBG(("SETTING BRACKET %d [%.*s]\n", ind, info.brackets[ind].len, info.brackets[ind].ptr));
      --depth;
      if (depth < 0) return Slre.Result.UnbalancedBrackets;
      if (i > 0 && re[i-1] == '(') return Slre.Result.NoMatch;
    }
  }

  if (depth != 0) return Slre.Result.UnbalancedBrackets;
  setup_branch_points(info);

  return baz(s, s_len, info);
}
