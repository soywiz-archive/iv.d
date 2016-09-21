/*
**  This software is provided AS-IS with no warranty, either express or
**  implied.
**
**  This software is dual licensed under the MIT and GPLv3 licenses.
*/
module iv.libstrophe.utils;


// ////////////////////////////////////////////////////////////////////////// //
char* xmpp_toStrz (const(char)[] s) {
  auto res = new char[](s.length+1);
  res[] = 0;
  res[0..s.length] = s[];
  return res.ptr;
}


T[] xmpp_fromStrz(T : char) (T* s) {
  if (s is null) return null;
  size_t pos = 0;
  while (s[pos]) ++pos;
  return s[0..pos];
}
