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
module iv.encoding /*is aliced*/;

import std.encoding;


// ////////////////////////////////////////////////////////////////////////// //
// utils
// `ch`: utf8 start
// -1: invalid utf8
byte utf8CodeLen (char ch) {
  //pragma(inline, true);
  if (ch < 0x80) return 1;
  if ((ch&0b1111_1110) == 0b1111_1100) return 6;
  if ((ch&0b1111_1100) == 0b1111_1000) return 5;
  if ((ch&0b1111_1000) == 0b1111_0000) return 4;
  if ((ch&0b1111_0000) == 0b1110_0000) return 3;
  if ((ch&0b1110_0000) == 0b1100_0000) return 2;
  return -1; // invalid
}


bool utf8Valid (const(char)[] buf) {
  auto bp = buf.ptr;
  auto left = buf.length;
  while (left-- > 0) {
    auto len = utf8CodeLen(*bp++)-1;
    if (len < 0 || len > left) return false;
    left -= len;
    while (len-- > 0) if (((*bp++)&0b1100_0000) != 0b1000_0000) return false;
  }
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
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



// ////////////////////////////////////////////////////////////////////////// //
class K8ByteEncoding(alias charMap) : EncodingScheme {
  override bool canEncode (dchar c) const {
    if (c < 0x80) return true;
    foreach (wchar d; charMap) if (c == d) return true;
    return false;
  }

  override size_t encodedLength (dchar c) const
  in {
    assert(canEncode(c));
  }
  body {
    return 1;
  }

  override size_t encode (dchar c, ubyte[] buffer) const {
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
    return cast(dchar)charMap.ptr[bc-128];
  }

  override dchar safeDecode (ref const(ubyte)[] s) const {
    ubyte bc = s[0];
    s = s[1..$];
    if (bc < 0x80) return cast(dchar)bc;
    auto res = cast(dchar)charMap.ptr[bc-128];
    if (res < 0x80) return INVALID_SEQUENCE;
    return res;
  }

  override @property immutable(ubyte)[] replacementSequence () const { return ['?']; }
}


// ////////////////////////////////////////////////////////////////////////// //
class KBBCWindows1251 : K8ByteEncoding!charMap1251 {
  shared static this () { EncodingScheme.register!KBBCWindows1251; }
  override string toString () const @safe pure nothrow @nogc { return "windows-1251"; }
  override string[] names () const @safe pure nothrow { return ["windows-1251", "cp-1251", "cp1251"]; }
}


class KBBCP866 : K8ByteEncoding!charMap866 {
  shared static this () { EncodingScheme.register!KBBCP866; }
  override string toString () const @safe pure nothrow @nogc { return "windows-866"; }
  override string[] names () const @safe pure nothrow { return ["windows-866", "cp-866", "cp866"]; }
}


class KBBCKOI8 : K8ByteEncoding!charMapKOI8 {
  shared static this () { EncodingScheme.register!KBBCKOI8; }
  override string toString () const @safe pure nothrow @nogc { return "koi8-u"; }
  override string[] names () const @safe pure nothrow { return ["koi8-u", "koi8-r", "koi8", "koi8u", "koi8r"]; }
}


// ////////////////////////////////////////////////////////////////////////// //
public immutable char[256] koi8from866Table = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\xe1','\xe2','\xf7','\xe7','\xe4','\xe5','\xf6','\xfa','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef','\xf0',
  '\xf2','\xf3','\xf4','\xf5','\xe6','\xe8','\xe3','\xfe','\xfb','\xfd','\xff','\xf9','\xf8','\xfc','\xe0','\xf1',
  '\xc1','\xc2','\xd7','\xc7','\xc4','\xc5','\xd6','\xda','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf','\xd0',
  '\x90','\x91','\x92','\x81','\x87','\xb2','\x3f','\x3f','\x3f','\xb5','\xa1','\xa8','\xae','\x3f','\xac','\x83',
  '\x84','\x89','\x88','\x86','\x80','\x8a','\xaf','\xb0','\xab','\xa5','\xbb','\xb8','\xb1','\xa0','\xbe','\xb9',
  '\xba','\x3f','\x3f','\xaa','\xa9','\xa2','\x3f','\x3f','\xbc','\x85','\x82','\x8d','\x8c','\x8e','\x8f','\x8b',
  '\xd2','\xd3','\xd4','\xd5','\xc6','\xc8','\xc3','\xde','\xdb','\xdd','\xdf','\xd9','\xd8','\xdc','\xc0','\xd1',
  '\xb3','\xa3','\xb4','\xa4','\xb7','\xa7','\x3f','\x3f','\x9c','\x95','\x9e','\x96','\x3f','\x3f','\x94','\x9a',
];

public immutable char[256] koi8from1251Table = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f',
  '\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f','\x3f',
  '\x9a','\x3f','\x3f','\x3f','\x3f','\xbd','\x3f','\x3f','\xb3','\xbf','\xb4','\x3f','\x3f','\x3f','\x3f','\xb7',
  '\x9c','\x3f','\xb6','\xa6','\xad','\x3f','\x3f','\x9e','\xa3','\x3f','\xa4','\x3f','\x3f','\x3f','\x3f','\xa7',
  '\xe1','\xe2','\xf7','\xe7','\xe4','\xe5','\xf6','\xfa','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef','\xf0',
  '\xf2','\xf3','\xf4','\xf5','\xe6','\xe8','\xe3','\xfe','\xfb','\xfd','\xff','\xf9','\xf8','\xfc','\xe0','\xf1',
  '\xc1','\xc2','\xd7','\xc7','\xc4','\xc5','\xd6','\xda','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf','\xd0',
  '\xd2','\xd3','\xd4','\xd5','\xc6','\xc8','\xc3','\xde','\xdb','\xdd','\xdf','\xd9','\xd8','\xdc','\xc0','\xd1',
];

// char toupper/tolower, koi8
immutable char[256] koi8tolowerTable = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6a','\x6b','\x6c','\x6d','\x6e','\x6f',
  '\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\x80','\x81','\x82','\x83','\x84','\x85','\x86','\x87','\x88','\x89','\x8a','\x8b','\x8c','\x8d','\x8e','\x8f',
  '\x90','\x91','\x92','\x93','\x94','\x95','\x96','\x97','\x98','\x99','\x9a','\x9b','\x9c','\x9d','\x9e','\x9f',
  '\xa0','\xa1','\xa2','\xa3','\xa4','\xa5','\xa6','\xa7','\xa8','\xa9','\xaa','\xab','\xac','\xad','\xae','\xaf',
  '\xb0','\xb1','\xb2','\xa3','\xa4','\xb5','\xa6','\xa7','\xb8','\xb9','\xba','\xbb','\xbc','\xad','\xbe','\xbf',
  '\xc0','\xc1','\xc2','\xc3','\xc4','\xc5','\xc6','\xc7','\xc8','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf',
  '\xd0','\xd1','\xd2','\xd3','\xd4','\xd5','\xd6','\xd7','\xd8','\xd9','\xda','\xdb','\xdc','\xdd','\xde','\xdf',
  '\xc0','\xc1','\xc2','\xc3','\xc4','\xc5','\xc6','\xc7','\xc8','\xc9','\xca','\xcb','\xcc','\xcd','\xce','\xcf',
  '\xd0','\xd1','\xd2','\xd3','\xd4','\xd5','\xd6','\xd7','\xd8','\xd9','\xda','\xdb','\xdc','\xdd','\xde','\xdf',
];

immutable char[256] koi8toupperTable = [
  '\x00','\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0a','\x0b','\x0c','\x0d','\x0e','\x0f',
  '\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x1a','\x1b','\x1c','\x1d','\x1e','\x1f',
  '\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2a','\x2b','\x2c','\x2d','\x2e','\x2f',
  '\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3a','\x3b','\x3c','\x3d','\x3e','\x3f',
  '\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x5b','\x5c','\x5d','\x5e','\x5f',
  '\x60','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4a','\x4b','\x4c','\x4d','\x4e','\x4f',
  '\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5a','\x7b','\x7c','\x7d','\x7e','\x7f',
  '\x80','\x81','\x82','\x83','\x84','\x85','\x86','\x87','\x88','\x89','\x8a','\x8b','\x8c','\x8d','\x8e','\x8f',
  '\x90','\x91','\x92','\x93','\x94','\x95','\x96','\x97','\x98','\x99','\x9a','\x9b','\x9c','\x9d','\x9e','\x9f',
  '\xa0','\xa1','\xa2','\xb3','\xb4','\xa5','\xb6','\xb7','\xa8','\xa9','\xaa','\xab','\xac','\xbd','\xae','\xaf',
  '\xb0','\xb1','\xb2','\xb3','\xb4','\xb5','\xb6','\xb7','\xb8','\xb9','\xba','\xbb','\xbc','\xbd','\xbe','\xbf',
  '\xe0','\xe1','\xe2','\xe3','\xe4','\xe5','\xe6','\xe7','\xe8','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef',
  '\xf0','\xf1','\xf2','\xf3','\xf4','\xf5','\xf6','\xf7','\xf8','\xf9','\xfa','\xfb','\xfc','\xfd','\xfe','\xff',
  '\xe0','\xe1','\xe2','\xe3','\xe4','\xe5','\xe6','\xe7','\xe8','\xe9','\xea','\xeb','\xec','\xed','\xee','\xef',
  '\xf0','\xf1','\xf2','\xf3','\xf4','\xf5','\xf6','\xf7','\xf8','\xf9','\xfa','\xfb','\xfc','\xfd','\xfe','\xff',
];

immutable ubyte[32] koi8alphaTable = [
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0xff,0xff,0x07,0xfe,0xff,0xff,0x07,
  0x00,0x00,0x00,0x00,0xd8,0x20,0xd8,0x20,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
];

char koi8lower (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return koi8tolowerTable.ptr[cast(int)ch];
}

char koi8upper (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return koi8toupperTable.ptr[cast(int)ch];
}

bool koi8isAlpha (char ch) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return ((koi8alphaTable.ptr[ch/8]&(1<<(ch%8))) != 0);
}


// ////////////////////////////////////////////////////////////////////////// //
import std.traits;

// SLOOOOOW. but who cares?
string recode(T) (T s, string to, string from) if (isSomeString!T) {
  static bool strEqu (const(char)[] s0, const(char)[] s1) {
    if (s0.length != s1.length) return false;
    foreach (immutable idx, char c0; s0) {
      import std.ascii : toLower;
      c0 = c0.toLower;
      char c1 = s1.ptr[idx].toLower;
      if (c0 != c1) return false;
    }
    return true;
  }
  ubyte[] res;
  ubyte[16] buf;
  auto efrom = (strEqu(from, "utf-8") ? new EncodingSchemeUtf8() : EncodingScheme.create(from));
  auto eto = (strEqu(to, "utf-8") ? new EncodingSchemeUtf8() : EncodingScheme.create(to));
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


string recodeToKOI8(T) (T s, string from=null) if (isSomeString!T) {
  ubyte[] res;
  ubyte[1] buf;
  auto eto = EncodingScheme.create("koi8-u");
  if (from.length == 0) {
    import std.utf : count;
    // from utf-8
    auto len = s.count;
    res = new ubyte[](len);
    size_t idx = 0;
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


// ////////////////////////////////////////////////////////////////////////// //
//public import std.conv;

string to(string enc, T) (T s)
if (isSomeString!T && (enc == "koi8" || enc == "koi8-r" || enc == "koi8-u" || enc == "koi8r" || enc == "koi8u"))
{
  return recodeToKOI8(s);
}
