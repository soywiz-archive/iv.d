import std.stdio;
import iv.slrex;


const(char)[] stest;
static assert(is(typeof({ auto t = typeof(stest).init; long len = t.length; })), "no length");
static assert(is(typeof({ auto t = typeof(stest).init; char ch = t[2]; })), "can't index");


int static_total_tests = 0;
int static_failed_tests = 0;


void FAIL (usize line, const(char)[] str) {
  writefln("Fail on line %s: [%s]", line, str);
  ++static_failed_tests;
}


void ASSERT(usize ln=__LINE__) (bool cond) {
  ++static_total_tests;
  if (!cond) FAIL(ln, "fucked");
}


// regex must have exactly one bracket pair
char[] slre_replace (const(char)[] regex, const(char)[] buf, const(char)[] sub) {
  //import std.utf : byChar;
  char[] s;
  Slre.Capture[1] cap;
  while (buf.length) {
    auto n = Slre.matchFirst(regex, buf, cap[]);
    if (n < 0) {
      // no match
      s ~= buf[];
      break;
    }
    // if some bytes were skipped, add them verbatim
    if (cap[0].ofs > 0) s ~= buf[0..cap[0].ofs];
    // add replacement
    s ~= sub[];
    // if we have some bytes left, add them verbatim
    if (cap[0].ofs+cap[0].len < n) {
      { import std.stdio; writeln("n=", n, "; ofs=", cap[0].ofs, "; len=", cap[0].len, "; end=", cap[0].ofs+cap[0].len); }
      s ~= buf[cap[0].ofs+cap[0].len..n];
    }
    buf = buf[n..$];
  }
  return s;
}


void main () {
  Slre.Capture[10] caps;

  int slre_match (const(char)[] re, const(char)[] str, int strlen, Slre.Capture* caps, int capslen, int flags, bool dump=false) {
    import std.stdio;
    auto len = Slre.matchFirst(re, str[0..strlen], caps[0..capslen], flags);
    if (dump) writeln("re: <", re, ">; str:<", str, ">; len=", len);
    return len;
  }

  /* Metacharacters */
  ASSERT(slre_match("$", "abcd", 4, null, 0, 0) == 4);
  ASSERT(slre_match("^", "abcd", 4, null, 0, 0) == 0);
  ASSERT(slre_match("x|^", "abcd", 4, null, 0, 0) == 0);
  ASSERT(slre_match("x|$", "abcd", 4, null, 0, 0) == 4);
  ASSERT(slre_match("x", "abcd", 4, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match(".", "abcd", 4, null, 0, 0) == 1);
  ASSERT(slre_match("^.*\\\\.*$", "c:\\Tools", 8, null, 0, Slre.Flag.IgnoreCase) == 8);
  ASSERT(slre_match("\\", "a", 1, null, 0, 0) == Slre.Result.InvalidMetaChar);
  ASSERT(slre_match("\\x", "a", 1, null, 0, 0) == Slre.Result.InvalidMetaChar);
  ASSERT(slre_match("\\x1", "a", 1, null, 0, 0) == Slre.Result.InvalidMetaChar);
  ASSERT(slre_match("\\x20", " ", 1, null, 0, 0) == 1);

  ASSERT(slre_match("^.+$", "", 0, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("^(.+)$", "", 0, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("^([\\+-]?)([\\d]+)$", "+", 1, caps.ptr, 10, Slre.Flag.IgnoreCase) == Slre.Result.NoMatch);
  ASSERT(slre_match("^([\\+-]?)([\\d]+)$", "+27", 3, caps.ptr, 10, Slre.Flag.IgnoreCase) == 3);
  //ASSERT(caps[0].ptr == "+");
  //ASSERT(caps[1].ptr == "27");
  ASSERT(caps[0].ofs == 0);
  ASSERT(caps[0].len == 1);
  ASSERT(caps[1].ofs == 1);
  ASSERT(caps[1].len == 2);

  ASSERT(slre_match("tel:\\+(\\d+[\\d-]+\\d)", "tel:+1-201-555-0123;a=b", 23, caps.ptr, 10, 0) == 19);
  //ASSERT(caps[0].ptr == "1-201-555-0123");
  ASSERT(caps[0].ofs == 5);
  ASSERT(caps[0].len == 14);

  // character sets
  ASSERT(slre_match("[abc]", "1c2", 3, null, 0, 0) == 2);
  ASSERT(slre_match("[abc]", "1C2", 3, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("[abc]", "1C2", 3, null, 0, Slre.Flag.IgnoreCase) == 2);
  ASSERT(slre_match("[.2]", "1C2", 3, null, 0, 0) == 1);
  ASSERT(slre_match("[\\S]+", "ab cd", 5, null, 0, 0) == 2);
  ASSERT(slre_match("[\\S]+\\s+[tyc]*", "ab cd", 5, null, 0, 0) == 4);
  ASSERT(slre_match("[\\d]", "ab cd", 5, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("[^\\d]", "ab cd", 5, null, 0, 0) == 1);
  ASSERT(slre_match("[^\\d]+", "abc123", 6, null, 0, 0) == 3);
  ASSERT(slre_match("[1-5]+", "123456789", 9, null, 0, 0) == 5);
  ASSERT(slre_match("[1-5a-c]+", "123abcdef", 9, null, 0, 0) == 6);
  ASSERT(slre_match("[1-5a-]+", "123abcdef", 9, null, 0, 0) == 4);
  ASSERT(slre_match("[1-5a-]+", "123a--2oo", 9, null, 0, 0) == 7);
  ASSERT(slre_match("[htps]+://", "https://", 8, null, 0, 0) == 8);
  ASSERT(slre_match("[^\\s]+", "abc def", 7, null, 0, 0) == 3);
  ASSERT(slre_match("[^fc]+", "abc def", 7, null, 0, 0) == 2);
  ASSERT(slre_match("[^d\\sf]+", "abc def", 7, null, 0, 0) == 3);

  // flags: case sensitivity
  ASSERT(slre_match("FO", "foo", 3, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("FO", "foo", 3, null, 0, Slre.Flag.IgnoreCase) == 2);
  ASSERT(slre_match("(?m)FO", "foo", 3, null, 0, 0) == Slre.Result.UnexpectedQuantifier);
  ASSERT(slre_match("(?m)x", "foo", 3, null, 0, 0) == Slre.Result.UnexpectedQuantifier);

  ASSERT(slre_match("fo", "foo", 3, null, 0, 0) == 2);
  ASSERT(slre_match(".+", "foo", 3, null, 0, 0) == 3);
  ASSERT(slre_match(".+k", "fooklmn", 7, null, 0, 0) == 4);
  ASSERT(slre_match(".+k.", "fooklmn", 7, null, 0, 0) == 5);
  ASSERT(slre_match("p+", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("ok", "fooklmn", 7, null, 0, 0) == 4);
  ASSERT(slre_match("lmno", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("mn.", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("o", "fooklmn", 7, null, 0, 0) == 2);
  ASSERT(slre_match("^o", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("^", "fooklmn", 7, null, 0, 0) == 0);
  ASSERT(slre_match("n$", "fooklmn", 7, null, 0, 0) == 7);
  ASSERT(slre_match("n$k", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("l$", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match(".$", "fooklmn", 7, null, 0, 0) == 7);
  ASSERT(slre_match("a?", "fooklmn", 7, null, 0, 0) == 0);
  ASSERT(slre_match("^a*CONTROL", "CONTROL", 7, null, 0, 0) == 7);
  ASSERT(slre_match("^[a]*CONTROL", "CONTROL", 7, null, 0, 0) == 7);
  ASSERT(slre_match("^(a*)CONTROL", "CONTROL", 7, null, 0, 0) == 7);
  ASSERT(slre_match("^(a*)?CONTROL", "CONTROL", 7, null, 0, 0) == 7);

  ASSERT(slre_match("\\_", "abc", 3, null, 0, 0) == Slre.Result.InvalidMetaChar);
  ASSERT(slre_match("+", "fooklmn", 7, null, 0, 0) == Slre.Result.UnexpectedQuantifier);
  ASSERT(slre_match("()+", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("\\x", "12", 2, null, 0, 0) == Slre.Result.InvalidMetaChar);
  ASSERT(slre_match("\\xhi", "12", 2, null, 0, 0) == Slre.Result.InvalidMetaChar);
  ASSERT(slre_match("\\x20", "_ J", 3, null, 0, 0) == 2);
  ASSERT(slre_match("\\x4A", "_ J", 3, null, 0, 0) == 3);
  ASSERT(slre_match("\\d+", "abc123def", 9, null, 0, 0) == 6);

  // balancing brackets
  ASSERT(slre_match("(x))", "fooklmn", 7, null, 0, 0) == Slre.Result.UnbalancedBrackets);
  ASSERT(slre_match("(", "fooklmn", 7, null, 0, 0) == Slre.Result.UnbalancedBrackets);

  ASSERT(slre_match("klz?mn", "fooklmn", 7, null, 0, 0) == 7);
  ASSERT(slre_match("fa?b", "fooklmn", 7, null, 0, 0) == Slre.Result.NoMatch);

  // brackets & capturing
  ASSERT(slre_match("^(te)", "tenacity subdues all", 20, caps.ptr, 10, 0) == 2);
  ASSERT(slre_match("(bc)", "abcdef", 6, caps.ptr, 10, 0) == 3);
  ASSERT(slre_match(".(d.)", "abcdef", 6, caps.ptr, 10, 0) == 5);
  ASSERT(slre_match(".(d.)\\)?", "abcdef", 6, caps.ptr, 10, 0) == 5);
  //ASSERT(caps[0].ptr == "de");
  ASSERT(caps[0].ofs == 3);
  ASSERT(caps[0].len == 2);
  ASSERT(slre_match("(.+)", "123", 3, caps.ptr, 10, 0) == 3);
  ASSERT(slre_match("(2.+)", "123", 3, caps.ptr, 10, 0) == 3);
  //ASSERT(caps[0].ptr == "23");
  ASSERT(caps[0].ofs == 1);
  ASSERT(caps[0].len == 2);
  ASSERT(slre_match("(.+2)", "123", 3, caps.ptr, 10, 0) == 2);
  //ASSERT(caps[0].ptr == "12");
  ASSERT(caps[0].ofs == 0);
  ASSERT(caps[0].len == 2);
  /*
  {
    import std.stdio;
    auto len = slre_match("(.*(2.))", "123", 3, caps.ptr, 10, 0);
    writeln("len=", len);
  }
  */
  ASSERT(slre_match("(.*(2.))", "123", 3, caps.ptr, 10, 0) == 3);
  ASSERT(slre_match("(.)(.)", "123", 3, caps.ptr, 10, 0) == 2);
  ASSERT(slre_match("(\\d+)\\s+(\\S+)", "12 hi", 5, caps.ptr, 10, 0) == 5);
  ASSERT(slre_match("ab(cd)+ef", "abcdcdef", 8, null, 0, 0) == 8);
  ASSERT(slre_match("ab(cd)*ef", "abcdcdef", 8, null, 0, 0) == 8);
  ASSERT(slre_match("ab(cd)+?ef", "abcdcdef", 8, null, 0, 0) == 8);
  ASSERT(slre_match("ab(cd)+?.", "abcdcdef", 8, null, 0, 0) == 5);
  ASSERT(slre_match("ab(cd)?", "abcdcdef", 8, null, 0, 0) == 4);
  ASSERT(slre_match("a(b)(cd)", "abcdcdef", 8, caps.ptr, 1, 0) == Slre.Result.CapsArrayTooSmall);
  ASSERT(slre_match("(.+/\\d+\\.\\d+)\\.jpg$", "/foo/bar/12.34.jpg", 18, caps.ptr, 1, 0) == 18);
  ASSERT(slre_match("(ab|cd).*\\.(xx|yy)", "ab.yy", 5, null, 0, 0) == 5);
  ASSERT(slre_match(".*a", "abcdef", 6, null, 0, 0) == 1);
  ASSERT(slre_match("(.+)c", "abcdef", 6, null, 0, 0) == 3);
  ASSERT(slre_match("\\n", "abc\ndef", 7, null, 0, 0) == 4);
  ASSERT(slre_match("b.\\s*\\n", "aa\r\nbb\r\ncc\r\n\r\n", 14, caps.ptr, 10, 0) == 8);

  // greedy vs non-greedy
  ASSERT(slre_match(".+c", "abcabc", 6, null, 0, 0) == 6);
  ASSERT(slre_match(".+?c", "abcabc", 6, null, 0, 0) == 3);
  ASSERT(slre_match(".*?c", "abcabc", 6, null, 0, 0) == 3);
  ASSERT(slre_match(".*c", "abcabc", 6, null, 0, 0) == 6);
  ASSERT(slre_match("bc.d?k?b+", "abcabc", 6, null, 0, 0) == 5);

  // branching
  ASSERT(slre_match("|", "abc", 3, null, 0, 0) == 0);
  ASSERT(slre_match("|.", "abc", 3, null, 0, 0) == 1);
  ASSERT(slre_match("x|y|b", "abc", 3, null, 0, 0) == 2);
  ASSERT(slre_match("k(xx|yy)|ca", "abcabc", 6, null, 0, 0) == 4);
  ASSERT(slre_match("k(xx|yy)|ca|bc", "abcabc", 6, null, 0, 0) == 3);
  ASSERT(slre_match("(|.c)", "abc", 3, caps.ptr, 10, 0) == 3);
  //ASSERT(caps[0].ptr == "bc");
  ASSERT(caps[0].ofs == 1);
  ASSERT(caps[0].len == 2);
  ASSERT(slre_match("a|b|c", "a", 1, null, 0, 0) == 1);
  ASSERT(slre_match("a|b|c", "b", 1, null, 0, 0) == 1);
  ASSERT(slre_match("a|b|c", "c", 1, null, 0, 0) == 1);
  ASSERT(slre_match("a|b|c", "d", 1, null, 0, 0) == Slre.Result.NoMatch);

  // optional match at the end of the string
  ASSERT(slre_match("^.*c.?$", "abc", 3, null, 0, 0) == 3);
  ASSERT(slre_match("^.*C.?$", "abc", 3, null, 0, Slre.Flag.IgnoreCase) == 3);
  ASSERT(slre_match("bk?", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("b(k?)", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("b[k-z]*", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("ab(k|z|y)*", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("[b-z].*", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("(b|z|u).*", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("ab(k|z|y)?", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match(".*", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match(".*$", "ab", 2, null, 0, 0) == 2);
  ASSERT(slre_match("a+$", "aa", 2, null, 0, 0) == 2);
  ASSERT(slre_match("a*$", "aa", 2, null, 0, 0) == 2);
  ASSERT(slre_match( "a+$" ,"Xaa", 3, null, 0, 0) == 3);
  ASSERT(slre_match( "a*$" ,"Xaa", 3, null, 0, 0) == 3);

  // ignore case flag
  ASSERT(slre_match("[a-h]+", "abcdefghxxx", 11, null, 0, 0) == 8);
  ASSERT(slre_match("[A-H]+", "ABCDEFGHyyy", 11, null, 0, 0) == 8);
  ASSERT(slre_match("[a-h]+", "ABCDEFGHyyy", 11, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("[A-H]+", "abcdefghyyy", 11, null, 0, 0) == Slre.Result.NoMatch);
  ASSERT(slre_match("[a-h]+", "ABCDEFGHyyy", 11, null, 0, Slre.Flag.IgnoreCase) == 8);
  ASSERT(slre_match("[A-H]+", "abcdefghyyy", 11, null, 0, Slre.Flag.IgnoreCase) == 8);

  {
    // example: HTTP request
    string request = " GET /index.html HTTP/1.0\r\n\r\n";
    //slre_cap[4] caps;

    if (slre_match("^\\s*(\\S+)\\s+(\\S+)\\s+HTTP/(\\d)\\.(\\d)", request, cast(int)request.length, caps.ptr, 4, 0) > 0) {
      writefln("Method: [%s], URI: [%s]", request[caps[0].ofs..caps[0].ofs+caps[0].len], request[caps[1].ofs..caps[1].ofs+caps[1].len]);
    } else {
      writefln("Error parsing [%s]", request);
    }
    //ASSERT(caps[1].ptr == "/index.html");
    ASSERT(caps[1].ofs == 5);
    ASSERT(caps[1].len == 11);
  }

  {
    // example: string replacement
    auto s = slre_replace("({{.+?}})", "Good morning, {{foo}}. How are you, {{bar}}?", "Bob");
    writeln(s);
    ASSERT(s == "Good morning, Bob. How are you, Bob?");
  }

  {
    // example: find all URLs in a string
    string str = "<img src=\"HTTPS://FOO.COM/x?b#c=tab1\"/>   <a href=\"http://cesanta.com\">some link</a>";
    string regex = "((https?://)[^\\s/'\"<>]+/?[^\\s'\"<>]*)";
    //slre_cap[2] caps;
    int i, j = 0, str_len = cast(int)str.length;
    while (j < str_len && (i = slre_match(regex, str[j..$], str_len-j, caps.ptr, 2, Slre.Flag.IgnoreCase)) > 0) {
      writefln("Found URL: [%s]", str[j+caps[0].ofs..j+caps[0].ofs+caps[0].len]);
      j += i;
    }
  }

  {
    // example more complex regular expression
    string str = "aa 1234 xy\nxyz";
    string regex = "aa ([0-9]*) *([x-z]*)\\s+xy([yz])";
    //slre_cap[3] caps;
    ASSERT(slre_match(regex, str, cast(int)str.length, caps.ptr, 3, 0) > 0);
    ASSERT(caps[0].len == 4);
    ASSERT(caps[1].len == 2);
    ASSERT(caps[2].len == 1);
    ASSERT(caps[2].ofs == 13);
  }

  writefln("Unit test %s (total test: %s, failed tests: %s)",
         static_failed_tests > 0 ? "FAILED": "PASSED",
         static_total_tests, static_failed_tests);

  //return static_failed_tests == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
