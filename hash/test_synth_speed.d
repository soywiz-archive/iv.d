import iv.hash.fasthash;
import iv.hash.joaat;
import iv.hash.murhash;

import iv.pxclock;
import iv.vfs.io;

// /tmp/bigtext/dump.sql
// _00/zwords.txt


// ////////////////////////////////////////////////////////////////////////// //
string[] words;

void loadWords () {
  foreach (string s; VFile("_00/zwords.txt").byLineCopy) words ~= s;
}


// ////////////////////////////////////////////////////////////////////////// //
uint sfHash (const(char)[] str) {
  return SFhashOf(str.ptr, str.length);
}


usize SFhashOf( const (void)* buf, usize len, usize seed = 0 ) @trusted pure nothrow @nogc
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


// ////////////////////////////////////////////////////////////////////////// //
uint murHashX (const(char)[] str, usize seed=0) {
  return MurHashOf(str, seed);
}


usize MurHashOf (const(char)[] data, usize seed=0) pure nothrow @trusted @nogc {
  enum C1 = 0xcc9e2d51u;
  enum C2 = 0x1b873593u;

  uint hash = seed; // current value
  uint accum; // we operate 32-bit chunks; low 2 bits of accum used as counter
  ubyte n;
  uint k1;

  // process data blocks
  if (data.length) {
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    // process 32-bit chunks
    foreach (immutable _; 0..len/4) {
      version(LittleEndian) {
        if (__ctfe) {
          k1 = (bytes[0])|(bytes[1]<<8)|(bytes[2]<<16)|(bytes[3]<<24);
        } else {
          k1 = *cast(const(uint)*)bytes;
        }
      } else {
        if (__ctfe) {
          k1 = (bytes[3])|(bytes[2]<<8)|(bytes[1]<<16)|(bytes[0]<<24);
        } else {
          import core.bitop : bswap;
          k1 = bswap(*cast(const(uint)*)bytes);
        }
      }
      bytes += 4;
      k1 *= C1;
      k1 = (k1<<15)|(k1>>(32-15));
      k1 *= C2;
      hash ^= k1;
      hash = (hash<<13)|(hash>>(32-13));
      hash = hash*5+0xe6546b64;
    }
    // advance over whole 32-bit chunks, possibly leaving 1..3 bytes
    len &= 0x03;
    n = cast(ubyte)len;
    // append any remaining bytes into carry
    while (len--) accum = (accum>>8)|(*bytes++<<24);
  }

  // finalize a hash
  if (n) {
    k1 = accum>>(4-n)*8;
    k1 *= C1;
    k1 = (k1<<15)|(k1>>(32-15));
    k1 *= C2;
    hash ^= k1;
  }
  hash ^= cast(uint)data.length;
  // fmix
  hash ^= hash>>16;
  hash *= 0x85ebca6bu;
  hash ^= hash>>13;
  hash *= 0xc2b2ae35u;
  hash ^= hash>>16;
  return hash;
}


/**
 * MurmurHash3 was written by Austin Appleby, and is placed in the public domain.
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 *
 * Returns:
 *   32-bit hash
 */
uint murHash32 (const(char)[] data, uint seed=0) pure nothrow @trusted @nogc {
  enum C1 = 0xcc9e2d51u;
  enum C2 = 0x1b873593u;

  uint hash = seed; // current value
  uint k1;

  // process data blocks
  if (data.length) {
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    // process 32-bit chunks
    foreach (immutable _; 0..len/4) {
      version(LittleEndian) {
        if (__ctfe) {
          k1 = (bytes[0])|(bytes[1]<<8)|(bytes[2]<<16)|(bytes[3]<<24);
        } else {
          k1 = *cast(const(uint)*)bytes;
        }
      } else {
        if (__ctfe) {
          k1 = (bytes[3])|(bytes[2]<<8)|(bytes[1]<<16)|(bytes[0]<<24);
        } else {
          import core.bitop : bswap;
          k1 = bswap(*cast(const(uint)*)bytes);
        }
      }
      bytes += 4;
      k1 *= C1;
      k1 = (k1<<15)|(k1>>(32-15));
      k1 *= C2;
      hash ^= k1;
      hash = (hash<<13)|(hash>>(32-13));
      hash = hash*5+0xe6546b64;
    }
    // advance over whole 32-bit chunks, possibly leaving 1..3 bytes
    if ((len &= 0x03) != 0) {
      immutable ubyte n = cast(ubyte)len;
      // append any remaining bytes into carry
      uint accum = 0;
      while (len--) accum = (accum>>8)|(*bytes++<<24);
      // finalize a hash
      k1 = accum>>((4-n)*8);
      k1 *= C1;
      k1 = (k1<<15)|(k1>>(32-15));
      k1 *= C2;
      hash ^= k1;
    }
    hash ^= cast(uint)data.length;
  }

  // fmix
  hash ^= hash>>16;
  hash *= 0x85ebca6bu;
  hash ^= hash>>13;
  hash *= 0xc2b2ae35u;
  hash ^= hash>>16;

  return hash;
}



usize bytesHash3(const(char)[] buf, usize seed=0) @system nothrow @nogc {
    static uint rotl32(uint n)(in uint x) pure nothrow @safe @nogc
    {
        return (x << n) | (x >> (32 - n));
    }

    //-----------------------------------------------------------------------------
    // Block read - if your platform needs to do endian-swapping or can only
    // handle aligned reads, do the conversion here
    static uint get32bits(const (ubyte)* x) pure nothrow @nogc
    {
        //Compiler can optimize this code to simple *cast(uint*)x if it possible.
        version(HasUnalignedOps)
        {
            if (!__ctfe)
                return *cast(uint*)x; //BUG: Can't be inlined by DMD
        }
        version(BigEndian)
        {
            return ((cast(uint) x[0]) << 24) | ((cast(uint) x[1]) << 16) | ((cast(uint) x[2]) << 8) | (cast(uint) x[3]);
        }
        else
        {
            return ((cast(uint) x[3]) << 24) | ((cast(uint) x[2]) << 16) | ((cast(uint) x[1]) << 8) | (cast(uint) x[0]);
        }
    }

    //-----------------------------------------------------------------------------
    // Finalization mix - force all bits of a hash block to avalanche
    static uint fmix32(uint h) pure nothrow @safe @nogc
    {
        h ^= h >> 16;
        h *= 0x85ebca6b;
        h ^= h >> 13;
        h *= 0xc2b2ae35;
        h ^= h >> 16;

        return h;
    }

    auto len = buf.length;
    auto data = cast(const(ubyte)*)buf.ptr;
    auto nblocks = len / 4;

    uint h1 = cast(uint)seed;

    enum uint c1 = 0xcc9e2d51;
    enum uint c2 = 0x1b873593;
    enum uint c3 = 0xe6546b64;

    //----------
    // body
    auto end_data = data+nblocks*uint.sizeof;
    for(; data!=end_data; data += uint.sizeof)
    {
        uint k1 = get32bits(data);
        k1 *= c1;
        k1 = rotl32!15(k1);
        k1 *= c2;

        h1 ^= k1;
        h1 = rotl32!13(h1);
        h1 = h1*5+c3;
    }

    //----------
    // tail
    uint k1 = 0;

    switch(len & 3)
    {
        case 3: k1 ^= data[2] << 16; goto case;
        case 2: k1 ^= data[1] << 8;  goto case;
        case 1: k1 ^= data[0];
                k1 *= c1; k1 = rotl32!15(k1); k1 *= c2; h1 ^= k1;
                goto default;
        default:
    }

    //----------
    // finalization
    h1 ^= len;
    h1 = fmix32(h1);
    return h1;
}


// ////////////////////////////////////////////////////////////////////////// //
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
usize FFhashOf (const(void)[] buf, usize seed=0) /*pure*/ nothrow @trusted @nogc {
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
  immutable len = buf.length;
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


// ////////////////////////////////////////////////////////////////////////// //
void doHash(T) () if (is(T == struct)) {
  foreach (string s; words) {
    T hash;
    hash.put(s);
    hash.finish32();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void doTest(T) () if (is(T == struct)) {
  enum Tries = 1000;
  write(T.stringof, ": ");
  auto stt = clockMilli();
  foreach (immutable _; 0..Tries) doHash!T();
  auto ett = clockMilli()-stt;
  writeln(words.length*Tries, " (", words.length, ", ", Tries, " times) took ", ett, " milliseconds");
}


// ////////////////////////////////////////////////////////////////////////// //
void doTestX(alias fn) () {
  enum Tries = 1000;
  write((&fn).stringof[2..$], ": ");
  auto stt = clockMilli();
  foreach (immutable _; 0..Tries) {
    foreach (string s; words) cast(void)fn(s);
  }
  auto ett = clockMilli()-stt;
  writeln(words.length*Tries, " (", words.length, ", ", Tries, " times) took ", ett, " milliseconds");
}


// ////////////////////////////////////////////////////////////////////////// //
static assert(murHashX("Hello, world!", 1234) == 0xfaf6cdb3U);
static assert(murHashX("Hello, world!", 4321) == 0xbf505788U);
static assert(murHashX("xxxxxxxxxxxxxxxxxxxxxxxxxxxx", 1234) == 0x8905ac28U);
static assert(murHashX("", 1234) == 0x0f2cc00bU);

static assert(bytesHash3("Hello, world!", 1234) == 0xfaf6cdb3U);
static assert(bytesHash3("Hello, world!", 4321) == 0xbf505788U);
static assert(bytesHash3("xxxxxxxxxxxxxxxxxxxxxxxxxxxx", 1234) == 0x8905ac28U);
static assert(bytesHash3("", 1234) == 0x0f2cc00bU);


pragma(msg, murHashX("Sample string"));
pragma(msg, murHashX("Alice & Miriel"));
pragma(msg, murHash32("Sample string"));
pragma(msg, murHash32("Alice & Miriel"));


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  assert(object.hashOf("Hello, world!", 1234) == 0xfaf6cdb3U);
  //writeln(object.hashOf("Hello, world!", 1234) == 0xfaf6cdb3U);
  loadWords();
  doTest!JoaatHash();
  doTest!FastHash();
  doTest!MurHash();
  doTestX!sfHash();
  doTestX!murHashX();
  doTestX!murHash32();
  doTestX!bytesHash3();
  doTestX!FFhashOf();

  foreach (string w; words) {
    if (murHashX(w) != murHash32(w)) assert(0, "shit!");
  }

  writeln("checking murhashes...");
  char[1024*8] buf = void;
  foreach (immutable _; 0..100000) {
    import std.random;
    auto len = uniform!"[]"(0, buf.length);
    foreach (ref char c; buf[0..len]) c = cast(char)(uniform!"[]"(0, 255));
    if (murHashX(buf[0..len]) != murHash32(buf[0..len])) assert(0, "shit!");
  }
}
