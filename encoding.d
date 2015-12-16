/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// 866,1251,koi8u
module iv.encoding is aliced;

import std.encoding;


////////////////////////////////////////////////////////////////////////////////
immutable wchar[128] charMap1251 = [
  '\u0402','\u0403','\u201A','\u0453','\u201E','\u2026','\u2020','\u2021','\u20AC','\u2030','\u0409','\u2039','\u040A','\u040C','\u040B','\u040F',
  '\u0452','\u2018','\u2019','\u201C','\u201D','\u2022','\u2013','\u2014','\u003F','\u2122','\u0459','\u203A','\u045A','\u045C','\u045B','\u045F',
  '\u00A0','\u040E','\u045E','\u0408','\u00A4','\u0490','\u00A6','\u00A7','\u0401','\u00A9','\u0404','\u00AB','\u00AC','\u00AD','\u00AE','\u0407',
  '\u00B0','\u00B1','\u0406','\u0456','\u0491','\u00B5','\u00B6','\u00B7','\u0451','\u2116','\u0454','\u00BB','\u0458','\u0405','\u0455','\u0457',
  '\u0410','\u0411','\u0412','\u0413','\u0414','\u0415','\u0416','\u0417','\u0418','\u0419','\u041A','\u041B','\u041C','\u041D','\u041E','\u041F',
  '\u0420','\u0421','\u0422','\u0423','\u0424','\u0425','\u0426','\u0427','\u0428','\u0429','\u042A','\u042B','\u042C','\u042D','\u042E','\u042F',
  '\u0430','\u0431','\u0432','\u0433','\u0434','\u0435','\u0436','\u0437','\u0438','\u0439','\u043A','\u043B','\u043C','\u043D','\u043E','\u043F',
  '\u0440','\u0441','\u0442','\u0443','\u0444','\u0445','\u0446','\u0447','\u0448','\u0449','\u044A','\u044B','\u044C','\u044D','\u044E','\u044F',
];


immutable wchar[128] charMap866 = [
  '\u0410','\u0411','\u0412','\u0413','\u0414','\u0415','\u0416','\u0417','\u0418','\u0419','\u041A','\u041B','\u041C','\u041D','\u041E','\u041F',
  '\u0420','\u0421','\u0422','\u0423','\u0424','\u0425','\u0426','\u0427','\u0428','\u0429','\u042A','\u042B','\u042C','\u042D','\u042E','\u042F',
  '\u0430','\u0431','\u0432','\u0433','\u0434','\u0435','\u0436','\u0437','\u0438','\u0439','\u043A','\u043B','\u043C','\u043D','\u043E','\u043F',
  '\u2591','\u2592','\u2593','\u2502','\u2524','\u2561','\u2562','\u2556','\u2555','\u2563','\u2551','\u2557','\u255D','\u255C','\u255B','\u2510',
  '\u2514','\u2534','\u252C','\u251C','\u2500','\u253C','\u255E','\u255F','\u255A','\u2554','\u2569','\u2566','\u2560','\u2550','\u256C','\u2567',
  '\u2568','\u2564','\u2565','\u2559','\u2558','\u2552','\u2553','\u256B','\u256A','\u2518','\u250C','\u2588','\u2584','\u258C','\u2590','\u2580',
  '\u0440','\u0441','\u0442','\u0443','\u0444','\u0445','\u0446','\u0447','\u0448','\u0449','\u044A','\u044B','\u044C','\u044D','\u044E','\u044F',
  '\u0401','\u0451','\u0404','\u0454','\u0407','\u0457','\u040E','\u045E','\u00B0','\u2219','\u00B7','\u221A','\u2116','\u00A4','\u25A0','\u00A0',
];


immutable wchar[128] charMapKOI8 = [
  '\u2500','\u2502','\u250C','\u2510','\u2514','\u2518','\u251C','\u2524','\u252C','\u2534','\u253C','\u2580','\u2584','\u2588','\u258C','\u2590',
  '\u2591','\u2592','\u2593','\u2320','\u25A0','\u2219','\u221A','\u2248','\u2264','\u2265','\u00A0','\u2321','\u00B0','\u00B2','\u00B7','\u00F7',
  '\u2550','\u2551','\u2552','\u0451','\u0454','\u2554','\u0456','\u0457','\u2557','\u2558','\u2559','\u255A','\u255B','\u0491','\u255D','\u255E',
  '\u255F','\u2560','\u2561','\u0401','\u0404','\u2563','\u0406','\u0407','\u2566','\u2567','\u2568','\u2569','\u256A','\u0490','\u256C','\u00A9',
  '\u044E','\u0430','\u0431','\u0446','\u0434','\u0435','\u0444','\u0433','\u0445','\u0438','\u0439','\u043A','\u043B','\u043C','\u043D','\u043E',
  '\u043F','\u044F','\u0440','\u0441','\u0442','\u0443','\u0436','\u0432','\u044C','\u044B','\u0437','\u0448','\u044D','\u0449','\u0447','\u044A',
  '\u042E','\u0410','\u0411','\u0426','\u0414','\u0415','\u0424','\u0413','\u0425','\u0418','\u0419','\u041A','\u041B','\u041C','\u041D','\u041E',
  '\u041F','\u042F','\u0420','\u0421','\u0422','\u0423','\u0416','\u0412','\u042C','\u042B','\u0417','\u0428','\u042D','\u0429','\u0427','\u042A',
];



////////////////////////////////////////////////////////////////////////////////
class K8ByteEncoding(alias charMap) : EncodingScheme {
  override bool canEncode (dchar c) const {
    if (c < 0x80) return true;
    foreach (wchar d; charMap) if (c == d) return true;
    return false;
  }

  override usize encodedLength (dchar c) const
  in {
    assert(canEncode(c));
  }
  body {
    return 1;
  }

  override usize encode (dchar c, ubyte[] buffer) const {
    if (c < 0x80) {
      buffer[0] = c&0xff;
    } else {
      buffer[0] = '?';
      foreach (immutable i, wchar d; charMap) {
        if (c == d) {
          buffer[0] = (i+128)&0xff;
          break;
        }
      }
    }
    return 1;
  }

  override dchar decode (ref const(ubyte)[] s) const {
    ubyte bc = s[0];
    s = s[1..$];
    if (bc < 0x80) return cast(dchar)bc;
    return cast(dchar)charMap[bc-128];
  }

  override dchar safeDecode (ref const(ubyte)[] s) const {
    ubyte bc = s[0];
    s = s[1..$];
    if (bc < 0x80) return cast(dchar)bc;
    auto res = cast(dchar)charMap[bc-128];
    if (res < 0x80) return INVALID_SEQUENCE;
    return res;
  }

  override @property immutable(ubyte)[] replacementSequence () const => ['?'];
}


////////////////////////////////////////////////////////////////////////////////
class KBBCWindows1251 : K8ByteEncoding!charMap1251 {
  shared static this () => EncodingScheme.register("iv.encoding.KBBCWindows1251");
  override string toString () const @safe pure nothrow @nogc => "windows-1251";
  override string[] names () const @safe pure nothrow => ["windows-1251", "cp-1251", "cp1251"];
}


class KBBCP866 : K8ByteEncoding!charMap866 {
  shared static this () => EncodingScheme.register("iv.encoding.KBBCP866");
  override string toString () const @safe pure nothrow @nogc => "windows-866";
  override string[] names () const @safe pure nothrow => ["windows-866", "cp-866", "cp866"];
}


class KBBCKOI8 : K8ByteEncoding!charMapKOI8 {
  shared static this () => EncodingScheme.register("iv.encoding.KBBCKOI8");
  override string toString () const @safe pure nothrow @nogc => "koi8-u";
  override string[] names () const @safe pure nothrow => ["koi8-u", "koi8-r", "koi8", "koi8u", "koi8r"];
}


////////////////////////////////////////////////////////////////////////////////
import std.traits;

// SLOOOOOW. but who cares?
string recode(T) (T s, string to, string from) if (isSomeString!T) {
  ubyte[] res;
  ubyte[16] buf;
  auto efrom = EncodingScheme.create(from);
  auto eto = EncodingScheme.create(to);
  auto ub = cast(const(ubyte)[])s;
  while (ub.length > 0) {
    dchar dc = efrom.safeDecode(ub);
    if (dc == INVALID_SEQUENCE) dc = '?';
    auto len = eto.encode(dc, buf);
    res ~= buf[0..len];
  }
  //import std.stdio; writefln("<%s>", cast(string)res);
  return cast(string)res;
}


unittest {
  assert(recode(n"¯¨§¤ ", "utf-8", "cp866") == "Ð¿Ð¸Ð·Ð´Ð°");
  assert(recode("Ð¿Ð¸Ð·Ð´Ð°", "koi8-u", "utf-8") == n"ÐÉÚÄÁ");
  assert(recode(n"ïèçäà", "koi8-u", "cp1251") == n"ÐÉÚÄÁ");
}


string recodeToKOI8(T) (T s, string from=null) if (isSomeString!T) {
  ubyte[] res;
  ubyte[1] buf;
  auto eto = EncodingScheme.create("koi8-u");
  if (from.length == 0) {
    import std.utf : count;
    // from utf-8
    auto len = s.count;
    res = new ubyte[](len);
    usize idx = 0;
    foreach (dchar dc; s) {
      eto.encode(dc, buf);
      res[idx++] = buf[0];
    }
  } else {
    auto efrom = EncodingScheme.create(from);
    auto ub = cast(const(ubyte)[])s;
    while (ub.length > 0) {
      dchar dc = efrom.safeDecode(ub);
      if (dc == INVALID_SEQUENCE) dc = '?';
      eto.encode(dc, buf);
      res ~= buf[0];
    }
  }
  return cast(string)res;
}


unittest {
  assert(recodeToKOI8("Ð¿Ð¸Ð·Ð´Ð°!"c) == n"ÐÉÚÄÁ!");
  assert(recodeToKOI8("Ð¿Ð¸Ð·Ð´Ð°!"w) == n"ÐÉÚÄÁ!");
  assert(recodeToKOI8("Ð¿Ð¸Ð·Ð´Ð°!"d) == n"ÐÉÚÄÁ!");
}


////////////////////////////////////////////////////////////////////////////////
//public import std.conv;

string to(string enc, T) (T s)
if (isSomeString!T && (enc == "koi8" || enc == "koi8-r" || enc == "koi8-u" || enc == "koi8r" || enc == "koi8u"))
{
  return recodeToKOI8(s);
}


unittest {
  assert(to!"koi8"("Ð¿Ð¸Ð·Ð´Ð°!"c) == n"ÐÉÚÄÁ!");
  assert(to!"koi8"("Ð¿Ð¸Ð·Ð´Ð°!"w) == n"ÐÉÚÄÁ!");
  assert(to!"koi8"("Ð¿Ð¸Ð·Ð´Ð°!"d) == n"ÐÉÚÄÁ!");
}
