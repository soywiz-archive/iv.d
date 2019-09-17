/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module testhash is aliced;

import std.traits;

import iv.hash.siphash;
import iv.hash.murhash;
import iv.hash.fasthash;
import iv.hash.joaat;


version(use_custom_dict) {
  enum WordsFile = "_00/zwords.txt";
} else {
  enum WordsFile = "/usr/share/dict/words";
}


bool[string] words;


void loadWords () {
  import std.stdio : File;

  void addWord (const(char)[] w) {
    if (w.length == 0 || w in words) return;
    words[w.idup] = true;
  }

  foreach (auto line; File(WordsFile).byLine) {
    import std.string : strip;
    line = line.strip;
    addWord(line);
    // all lower
    foreach (ref ch; line) if (ch >= 'A' && ch <= 'Z') ch += 32;
    addWord(line);
    // all upper
    foreach (ref ch; line) if (ch >= 'a' && ch <= 'z') ch -= 32;
    addWord(line);
    // first upper
    if (line[0] >= 'A' && line[0] <= 'Z') {
      line[0] += 32;
      addWord(line);
    }
  }
}


void testHash(T) (string name, T hfn)
if (isCallable!T && (is(ReturnType!T == uint) || is(ReturnType!T == ulong)))
{
  { import std.stdio : stdout; stdout.write(name, " ... "); stdout.flush(); }
  alias HType = ReturnType!T;
  usize[HType] collisions;

  foreach (immutable w; words.byKey) {
    static if (__traits(compiles, { auto h = hfn(w); })) {
      auto h = hfn(w);
    } else {
      auto h = hfn(w, 0);
    }
    if (auto cc = h in collisions) {
      ++(*cc);
    } else {
      collisions[h] = 1;
    }
  }

  usize maxCollision = 0, elements = 0, colls = 0;
  foreach (immutable c; collisions.byValue) {
    if (c > maxCollision) maxCollision = c;
    if (c) ++elements;
    if (c > 1) colls += c-1;
  }
  assert(maxCollision >= 1);

  if (maxCollision == 1) {
    import std.stdio;
    writeln("perfect for ", words.length, " words!");
  } else {
    import std.algorithm : sort;
    import std.stdio;
    import std.array;
    writeln(maxCollision-1, " max collisions for ", words.length, " words, ", colls, " collisions total");
    auto cols = sort!"a>b"(collisions.values).array;
    cols ~= 0;
    usize idx = 0;
    //assert(cols[0] > 1);
    while (cols[idx] > 1) {
      uint count = 0;
      auto c = cols[idx];
      while (cols[idx] == c) { ++count; ++idx; }
      writeln("  ", count, " collisions for ", c, " times");
    }
  }
}


uint innerhash (const(void)[] kbuf) @trusted nothrow @nogc {
  int res;
  if (kbuf.length == int.sizeof) {
    import core.stdc.string : memcpy;
    memcpy(&res, kbuf.ptr, res.sizeof);
  } else {
    res = 751;
  }
  foreach (immutable bt; cast(const(ubyte)[])kbuf) res = res*31+bt;
  return (res*87767623)&int.max;
}


uint outerhash (const(void)[] kbuf) @trusted nothrow @nogc {
  int res = 774831917;
  foreach_reverse (immutable bt; cast(const(ubyte)[])kbuf) res = res*29+bt;
  return (res*5157883)&int.max;
}


uint djb2 (const(char)[] str) {
  uint hash = 5381;
  auto data = cast(const(ubyte)[])str;
  foreach (ubyte c; data) hash = ((hash << 5)+hash)+c; /* hash * 33 + c */
  auto len = str.length;
  while (len != 0) {
    hash = ((hash << 5)+hash)+(len&0xff); /* hash * 33 + c */
    len >>= 8;
  }
  return hash;
}


uint djb2x (const(char)[] str) {
  uint hash = 5381;
  auto data = cast(const(ubyte)[])str;
  foreach (ubyte c; data) hash = ((hash << 5)+hash)^c; /* hash * 33 ^ c */
  auto len = str.length;
  while (len != 0) {
    hash = ((hash << 5)+hash)^(len&0xff); /* hash * 33 ^ c */
    len >>= 8;
  }
  return hash;
}


uint sdbm (const(char)[] str) {
  uint hash = cast(uint)str.length;
  auto data = cast(const(ubyte)[])str;
  foreach (ubyte c; data) hash = c + (hash << 6) + (hash << 16) - hash;
  return hash;
}


uint loselose (const(char)[] str) {
  uint hash = 0;
  auto data = cast(const(ubyte)[])str;
  foreach (ubyte c; data) hash += c;
  return hash;
}


uint sfHash (const(char)[] str) {
  return SFhashOf(str.ptr, str.length);
}


usize SFhashOf( const (void)* buf, usize len, usize seed = 0 ) @trusted pure nothrow
{
    /*
     * This is Paul Hsieh's SuperFastHash algorithm, described here:
     *   http://www.azillionmonkeys.com/qed/hash.html
     * It is protected by the following open source license:
     *   http://www.azillionmonkeys.com/qed/weblicense.html
     */
    static uint get16bits( const (ubyte)* x ) pure nothrow
    {
        // CTFE doesn't support casting ubyte* -> ushort*, so revert to
        // per-byte access when in CTFE.
        version( HasUnalignedOps )
        {
            if (!__ctfe)
                return *cast(ushort*) x;
        }

        return ((cast(uint) x[1]) << 8) + (cast(uint) x[0]);
    }

    // NOTE: SuperFastHash normally starts with a zero hash value.  The seed
    //       value was incorporated to allow chaining.
    auto data = cast(const (ubyte)*) buf;
    auto hash = seed;
    int  rem;

    if( len <= 0 || data is null )
        return 0;

    rem = len & 3;
    len >>= 2;

    for( ; len > 0; len-- )
    {
        hash += get16bits( data );
        auto tmp = (get16bits( data + 2 ) << 11) ^ hash;
        hash  = (hash << 16) ^ tmp;
        data += 2 * ushort.sizeof;
        hash += hash >> 11;
    }

    switch( rem )
    {
    case 3: hash += get16bits( data );
            hash ^= hash << 16;
            hash ^= data[ushort.sizeof] << 18;
            hash += hash >> 11;
            break;
    case 2: hash += get16bits( data );
            hash ^= hash << 11;
            hash += hash >> 17;
            break;
    case 1: hash += *data;
            hash ^= hash << 10;
            hash += hash >> 1;
            break;
     default:
            break;
    }

    /* Force "avalanching" of final 127 bits */
    hash ^= hash << 3;
    hash += hash >> 5;
    hash ^= hash << 4;
    hash += hash >> 17;
    hash ^= hash << 25;
    hash += hash >> 6;

    return hash;
}


uint ffHash (const(char)[] str) {
  return FFhashOf(str.ptr, str.length);
}


/**
 * 64-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 *
 * Returns:
 *   32-bit or 64-bit hash
 */
usize FFhashOf (const(void)* buf, usize len, usize seed=0) @trusted pure nothrow @nogc {
  enum Get8Bytes = q{
    cast(ulong)data[0]|
    (cast(ulong)data[1]<<8)|
    (cast(ulong)data[2]<<16)|
    (cast(ulong)data[3]<<24)|
    (cast(ulong)data[4]<<32)|
    (cast(ulong)data[5]<<40)|
    (cast(ulong)data[6]<<48)|
    (cast(ulong)data[7]<<56)
  };
  enum m = 0x880355f21e6d1965UL;
  auto data = cast(const(ubyte)*)buf;
  ulong h = seed;
  ulong t;
  foreach (immutable _; 0..len/8) {
    version(HasUnalignedOps) {
      if (__ctfe) {
        t = mixin(Get8Bytes);
      } else {
        t = *cast(ulong*)data;
      }
    } else {
      t = mixin(Get8Bytes);
    }
    data += 8;
    t ^= t>>23;
    t *= 0x2127599bf4325c37UL;
    t ^= t>>47;
    h ^= t;
    h *= m;
  }

  h ^= len*m;
  t = 0;
  switch (len&7) {
    case 7: t ^= cast(ulong)data[6]<<48; goto case 6;
    case 6: t ^= cast(ulong)data[5]<<40; goto case 5;
    case 5: t ^= cast(ulong)data[4]<<32; goto case 4;
    case 4: t ^= cast(ulong)data[3]<<24; goto case 3;
    case 3: t ^= cast(ulong)data[2]<<16; goto case 2;
    case 2: t ^= cast(ulong)data[1]<<8; goto case 1;
    case 1: t ^= cast(ulong)data[0]; goto default;
    default:
      t ^= t>>23;
      t *= 0x2127599bf4325c37UL;
      t ^= t>>47;
      h ^= t;
      h *= m;
      break;
  }

  h ^= h>>23;
  h *= 0x2127599bf4325c37UL;
  h ^= h>>47;
  static if (usize.sizeof == 4) {
    // 32-bit hash
    // the following trick converts the 64-bit hashcode to Fermat
    // residue, which shall retain information from both the higher
    // and lower parts of hashcode.
    return cast(usize)(h-(h>>32));
  } else {
    return h;
  }
}


uint jenkins_one_at_a_time_hash (const(void)* key, usize len) {
  uint h;
  auto data = cast(const(ubyte)*)key;
  foreach (immutable _; 0..len) {
    h += *data++;
    h += (h << 10);
    h ^= (h >> 6);
  }
  /*
  while (len != 0) {
    h += len&0xff;
    h += (h<<10);
    h ^= (h>>6);
    len >>= 8;
  }
  */
  h += (h << 3);
  h ^= (h >> 11);
  h += (h << 15);
  return h;
}

uint joaatHash (const(char)[] str) {
  return jenkins_one_at_a_time_hash(str.ptr, str.length);
}

void main () {
  loadWords();
  testHash("fastHash64", &fastHash64!char);
  testHash("fastHash32", &fastHash32!char);
  testHash("siphash24", (const(char)[] buf) => sipHash24Of("0123456789abcdef", buf));
  testHash("murhash", &murHash32!char);
  testHash("innerhash", &innerhash);
  testHash("outerhash", &outerhash);
  testHash("djb2", &djb2);
  testHash("djb2x", &djb2x);
  testHash("sdbm", &sdbm);
  testHash("sfHash", &sfHash);
  testHash("ffHash", &ffHash);
  testHash("joaatHash0", &joaatHash);
  testHash("joaatHash1", &joaatHash32!char);
  //testHash("loselose", &loselose);
}
