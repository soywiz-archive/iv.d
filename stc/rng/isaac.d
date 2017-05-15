/*
 * ISAAC random number generator by Bob Jenkins.
 * Copyright (C) 2014 Ketmar Dark // Invisible Vector (ketmar@ketmar.no-ip.org)
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
 * Get a copy of the GNU GPL from <http://www.gnu.org/licenses/>.
 */
/*
 * ISAAC random number generator by Bob Jenkins.
 * http://www.burtleburtle.net/bob/rand/isaacafa.html
 *
 * Suitable for using with std.random functions.
 */
module iv.stc.rng.isaac is aliced;

import std.range;
import iv.stc.core;


struct ISAACEngine {
public nothrow @trusted @nogc:
  enum bool isUniformRandom = true; // mark as RNG
  enum bool hasFixedRange = true; // yes
  enum uint min = 0; // lowest value
  enum uint max = 0xffffffffU; // highest value

  enum MaxSeedBytes = RANDSIZ*randr[0].sizeof;

  /**
   * Constructs a $(D_PARAM LinearCongruentialEngine) generator seeded with $(D x0).
   */
  this(R0) (R0 rseed) if (isValidIR!R0) { seed(rseed); }

  @trusted this (uint x0) { seed(x0); }

  ~this () {
    randcnt = 0;
    randr[] = 0;
    randm[] = 0;
    randa = randb = randc = 0;
    mLastValue = 0;
  }

  /**
   * (Re)seeds the generator with non-random seed.
   */
  void seed() () { seed(cast(ubyte[])[]); }

  /**
   * (Re)seeds the generator.
   *
   * Params:
   *  rseed = seed value
   */
  void seed (uint rseed) {
    ubyte[4] sd;
    sd.ptr[0] = rseed&0xff;
    sd.ptr[1] = (rseed>>8)&0xff;
    sd.ptr[2] = (rseed>>16)&0xff;
    sd.ptr[3] = (rseed>>24)&0xff;
    seed(sd[]);
  }


  /**
   * (Re)seeds the generator.
   *
   * Params:
   *  rseed = seed vector; up to 256 bytes will be used
   */
  void seed(R0) (R0 rseed) if (isValidIR!R0) {
    enum mix = `
      a ^= b<<11; d += a; b += c;
      b ^= c>>2;  e += b; c += d;
      c ^= d<<8;  f += c; d += e;
      d ^= e>>16; g += d; e += f;
      e ^= f<<10; h += e; f += g;
      f ^= g>>4;  a += f; g += h;
      g ^= h<<8;  b += g; h += a;
      h ^= a>>9;  c += h; a += b;`;
    uint a, b, c, d, e, f, g, h;
    randa = randb = randc = 0;
    a = b = c = d = e = f = g = h = 0x9e3779b9; // the golden ratio
    // scramble it
    foreach (immutable i; 0..4) { mixin(mix); }
    if (!rseed.empty) {
      // copy seed to randr[]
      uint[256] xseed = void;
      uint xslen = 0;
      for (uint i = 0; i < randr.length && !rseed.empty; ++i) {
        uint n = cast(ubyte)rseed.front;
        rseed.popFront;
        if (!rseed.empty) { n |= (cast(uint)(cast(ubyte)rseed.front))<<8; rseed.popFront; }
        if (!rseed.empty) { n |= (cast(uint)(cast(ubyte)rseed.front))<<16; rseed.popFront; }
        if (!rseed.empty) { n |= (cast(uint)(cast(ubyte)rseed.front))<<24; rseed.popFront; }
        xseed.ptr[xslen++] = n;
      }
      foreach (immutable i, ref r; randr) r = cast(uint)i^xseed.ptr[i%xslen];
      // initialize using the contents of randr[] as the seed
      for (auto i = 0; i < RANDSIZ; i += 8) {
        a += randr.ptr[i  ]; b += randr.ptr[i+1]; c += randr.ptr[i+2]; d += randr.ptr[i+3];
        e += randr.ptr[i+4]; f += randr.ptr[i+5]; g += randr.ptr[i+6]; h += randr.ptr[i+7];
        mixin(mix);
        randm.ptr[i  ] = a; randm.ptr[i+1] = b; randm.ptr[i+2] = c; randm.ptr[i+3] = d;
        randm.ptr[i+4] = e; randm.ptr[i+5] = f; randm.ptr[i+6] = g; randm.ptr[i+7] = h;
      }
      // do a second pass to make all of the seed affect all of randm
      for (auto i = 0; i < RANDSIZ; i += 8) {
        a += randm.ptr[i  ]; b += randm.ptr[i+1]; c += randm.ptr[i+2]; d += randm.ptr[i+3];
        e += randm.ptr[i+4]; f += randm.ptr[i+5]; g += randm.ptr[i+6]; h += randm.ptr[i+7];
        mixin(mix);
        randm.ptr[i  ] = a; randm.ptr[i+1] = b; randm.ptr[i+2] = c; randm.ptr[i+3] = d;
        randm.ptr[i+4] = e; randm.ptr[i+5] = f; randm.ptr[i+6] = g; randm.ptr[i+7] = h;
      }
    } else {
      // fill in randm[] with messy stuff
      for (auto i = 0; i < RANDSIZ; i += 8) {
        mixin(mix);
        randm.ptr[i  ] = a; randm.ptr[i+1] = b; randm.ptr[i+2] = c; randm.ptr[i+3] = d;
        randm.ptr[i+4] = e; randm.ptr[i+5] = f; randm.ptr[i+6] = g; randm.ptr[i+7] = h;
      }
    }
    isaac(); // fill in the first set of results
    randcnt = RANDSIZ; // prepare to use the first set of results
    genRand(); // generate first value
  }

  /**
   * Advances the random sequence.
   */
  void popFront () { genRand(); }

  /**
   * Returns the current number in the random sequence.
   */
  @property uint front () { pragma(inline, true); return mLastValue; }

  ///
  @property typeof(this) save () {
    return this;
  }

  /**
   * Always $(D false) (random generators are infinite ranges).
   */
  enum bool empty = false;

  /**
   * Compares against $(D_PARAM rhs) for equality.
   */
  bool opEquals (ref const ISAACEngine rhs) const {
    return
      (mLastValue == rhs.mLastValue && randcnt == rhs.randcnt &&
       randr == rhs.randr && randm == rhs.randm &&
       randa == rhs.randa && randb == rhs.randb && randc == rhs.randc);
  }

  /**
   * Returns new random number.
   *
   * Returns:
   *  random number
   */
  uint rand () {
    uint res = mLastValue;
    genRand();
    return res;
  }

private:
  /+ simplified 'understandable' version
  void isaac () @trusted nothrow {
    uint a, b, x, y;
    // cache values
    a = randa;
    b = randb+(++randc); // cc just gets incremented once per 256 results then combined with bb
    for (usize i = 0; i < 256; ++i) {
      x = randm.ptr[i];
      final switch (i&3) {
        case 0: a ^= a<<13; break;
        case 1: a ^= a>> 6; break;
        case 2: a ^= a<< 2; break;
        case 3: a ^= a>>16; break;
      }
      a += randm.ptr[(i+128)&0xff];
      randm.ptr[i] = y = randm.ptr[(x>>2)&0xff]+a+b;
      randr.ptr[i] = b = randm.ptr[(y>>10)&0xff]+x;
    }
    // save cached values
    randa = a;
    randb = b;
  }
  +/

  void isaac () {
    enum rngstep(string mix) =
      "x = randm.ptr[m];\n"~
      "a = (a^("~mix~"))+randm.ptr[m2++];\n"~
      "randm.ptr[m++] = y = randm.ptr[(x>>2)&0xff]+a+b;\n"~
      "randr.ptr[r++] = b = randm.ptr[((y>>RANDSIZL)>>2)&0xff]+x;\n";
    enum mend = (RANDSIZ/2);
    uint a, b, x, y;
    usize m, m2, r;
    a = randa;
    b = randb+(++randc);
    r = m = 0;
    m2 = RANDSIZ/2;
    while (m < mend) {
      mixin(rngstep!("a<<13"));
      mixin(rngstep!("a>>6"));
      mixin(rngstep!("a<<2"));
      mixin(rngstep!("a>>16"));
    }
    m2 = 0;
    while (m2 < mend) {
      mixin(rngstep!("a<<13"));
      mixin(rngstep!("a>>6"));
      mixin(rngstep!("a<<2"));
      mixin(rngstep!("a>>16"));
    }
    randb = b;
    randa = a;
  }

  void genRand () {
    if (randcnt-- == 0) {
      isaac();
      randcnt = RANDSIZ-1;
    }
    mLastValue = randr.ptr[randcnt];
  }

private:
  enum RANDSIZL = 8;
  enum RANDSIZ = (1<<RANDSIZL);
  // context of random number generator
  usize randcnt;
  uint[RANDSIZ] randr;
  uint[RANDSIZ] randm;
  uint randa;
  uint randb;
  uint randc;
  // current value (to work as range)
  uint mLastValue;
}


unittest {
  import std.stdio;

  uint count = 0;

  void check (ref ISAACEngine ctx, immutable(uint)[] output) {
    assert(output.length == 8*16);
    usize pos = 0;
    for (usize f = 0; f < 8; ++f) {
      for (usize c = 0; c < 16; ++c) {
        uint val = ctx.rand();
        assert(output[pos] == val);
        ++pos;
      }
      // now skip 1024 values
      for (usize c = 0; c < 1024; ++c) ctx.rand();
    }
    ++count;
  }

  writeln("testing ISAAC...");

  auto ctx = ISAACEngine(0);
  //
  ctx.seed(); // non-random seed
  check(ctx, [
    0x71d71fd2U,0xb54adae7U,0xd4788559U,0xc36129faU,0x21dc1ea9U,0x3cb879caU,0xd83b237fU,0xfa3ce5bdU,0x8d048509U,0xd82e9489U,0xdb452848U,0xca20e846U,0x500f972eU,0x0eeff940U,0x00d6b993U,0xbc12c17fU,
    0x37a954ceU,0x8c39f569U,0x6e8af314U,0x1f12211cU,0x189c7aaaU,0x1a1429bcU,0xbb5f9847U,0xbad5e406U,0x59ca7a8dU,0xeca16198U,0x3edf0edeU,0xd93e18ebU,0xb11b611aU,0x53993416U,0xc0570ab8U,0x21fe08d3U,
    0xf432fc21U,0xb7e1aa14U,0xf669c793U,0xcc2b7c40U,0xee198054U,0xfb536609U,0xcc102403U,0x2e5a28c2U,0x16d94e20U,0x819773b9U,0x026456e0U,0x6a70dfc4U,0x3954762fU,0x50c8975bU,0xe51f0d24U,0xe44252c9U,
    0x4a0cee40U,0xc4b4d179U,0x5043fabaU,0x24276bf8U,0x904e9563U,0xb39f1e43U,0x1b828bf2U,0x3ba031aeU,0xbc770490U,0x03f8b6f6U,0xc48cae8bU,0xeb55e6c1U,0xc59e2858U,0x99af5ff2U,0x9395cf37U,0xea3e4daeU,
    0xda24c7e7U,0x763f9144U,0x3af14bafU,0x472cfd26U,0xbd0e27b4U,0x185f6c58U,0x14806685U,0x9406526eU,0x0322b0dfU,0xe49178cdU,0x006371e9U,0x67c36669U,0x70217736U,0x53c1077aU,0x4e7f9330U,0x723952c7U,
    0x68799afdU,0x7c42985fU,0x6a380462U,0xa2986edbU,0x7138478fU,0x867d070fU,0xa9089ef9U,0x17e200bdU,0x85893862U,0x20c5a7b3U,0x4974bdc2U,0x67ec7fb5U,0x8ba2417dU,0xd9c368c2U,0x2754a488U,0x57219a5bU,
    0x9a326b71U,0x0075101fU,0x7384b2a8U,0x65954f18U,0x935bcaf4U,0x71689ad4U,0x9f22e61dU,0x2091c3c3U,0x9a1745e0U,0x0fe9d163U,0xe44692d8U,0x1e38aa08U,0x20421bf8U,0xc645fe81U,0x55793bf8U,0xa742c66fU,
    0x7728fe32U,0x68d5fab6U,0x506fbdfaU,0xedf9e9b3U,0xda631a76U,0x9468ab6eU,0x196d5b9aU,0xa020a596U,0x355178e7U,0x13cb82e3U,0x318e6572U,0xd2dd871aU,0xded20b87U,0x48a7c202U,0xe4c88f68U,0xbc46d85cU,
  ]);
  //
  ctx.seed(666);
  check(ctx, [
    0x46737a83U,0x44bbc623U,0x798696a5U,0x8c93a9e4U,0xdeb438f6U,0xac06b964U,0x1ded1504U,0x24ef178cU,0x9bcbabf1U,0xcade7455U,0xd5fa32fcU,0x2bdbe5baU,0xc73c0d4fU,0x0defaf62U,0x63725a11U,0x6b573752U,
    0x84179b99U,0xf2d73f6dU,0xeff77abdU,0xb22c5c0bU,0xbe540035U,0x3a7d8125U,0x2983cb15U,0xb2f76cb9U,0x80e31a9cU,0xf88e5321U,0x9019a00aU,0x84662816U,0x037239b3U,0x944e547cU,0xaf707256U,0xb6054c5bU,
    0x712308d3U,0x2ee5d372U,0x33f9462cU,0xf42504e2U,0xf51a83f0U,0xad61fef6U,0x48371c0dU,0x3bdbc775U,0x9b1b5032U,0x7619b8b0U,0xe1e55536U,0xcbbf9473U,0x99442cfbU,0x7d947048U,0x7994c700U,0x96e246f5U,
    0xd8a9e8d4U,0xeb528c72U,0x9e590beaU,0xce44a3adU,0x67d96b0fU,0x372ad21fU,0x448e4711U,0x4cd94d06U,0x403bc6b8U,0xb4f033c0U,0xcf9f6782U,0xd4a4fa4bU,0xa6617c47U,0x7a2e98e6U,0xc691c1f9U,0x71b6f0e2U,
    0xdcc5e0d0U,0x5ef1fbd4U,0xc11099a8U,0xd9ef4094U,0x49c7c082U,0x6f0d2a46U,0xc492793aU,0x57db109bU,0xd6095192U,0x7680197dU,0xf29f6985U,0xc7e97d9eU,0xb574549cU,0x2822e602U,0x40829276U,0x8131b5cfU,
    0xc1c066a1U,0xad819821U,0x5a60c4e9U,0x71a4f036U,0xe89c36dfU,0x179cc63bU,0x3fcc1941U,0xc6e8a3bcU,0xde9b2e89U,0x6cb10e61U,0xc70a4232U,0x0db4747dU,0xd2493ac0U,0xcef680a8U,0xbe7b2c34U,0x78208879U,
    0x5895241bU,0x8e90209aU,0x424acd06U,0x93a40fb9U,0x29baf3d4U,0x084289ccU,0x2c5665ddU,0x2cb87ea4U,0xbe2c3dcaU,0x027ec1b1U,0x91f46567U,0xdabebcd4U,0x5c1b1480U,0xef50e92cU,0xf3edf50bU,0x656bddb3U,
    0xd6dc78ddU,0x63364746U,0xf84cf51cU,0xe1739e9bU,0x43646bb0U,0x9a72966aU,0xdf998d5aU,0x8fc305caU,0x3d10e593U,0xf3cedc79U,0x847563b8U,0x4dbf2720U,0xc6f2a7cbU,0xefd6c664U,0xe78f644bU,0xe28fd5f0U,
  ]);
  //
  ctx.seed(cast(ubyte[])[42,0,0,0, 154,2,0,0, 205,2,0,0]);
  check(ctx, [
    0x0684d993U,0x1d182b73U,0x7d42a40cU,0xf51095a6U,0x292d1b7aU,0x46748f70U,0x900fe28bU,0x661eed9cU,0xf52dcf2cU,0xddd238bbU,0x0ae0f9dbU,0xad4bbcefU,0x494d299fU,0xb71966a4U,0x94e6f40aU,0x6d2ecfccU,
    0xfa9c3f73U,0xb0cad8bbU,0x8916ec8fU,0x76674f28U,0xef95a86bU,0x4c27365cU,0x3646048cU,0xa4647d41U,0x96ac01e9U,0x32d7d7acU,0xbe0fb19aU,0x030be7bfU,0xb8331c3bU,0xb5ffdf02U,0x85b49413U,0xe32811d7U,
    0xa334b60fU,0xe8169485U,0x5d625a3dU,0x16acf52dU,0xbeb6e505U,0xde115e42U,0x9d38193fU,0xacbcb132U,0x1b6613a5U,0xfc53f0f9U,0x4226ee2dU,0x3c53f518U,0xd3c8d11dU,0xebe2bbafU,0x255d1a03U,0x76c18386U,
    0x88c337baU,0x9f963810U,0x13459d9eU,0x6d88d972U,0xa25bc6f0U,0xd99717d0U,0xb7ff12d6U,0xe399e7cdU,0x95ed519cU,0x2b952e7bU,0xb517162bU,0xda967643U,0x441b80fdU,0x1803c78eU,0x212252fdU,0x115bd732U,
    0xa7f64f38U,0xfe2e5722U,0x91be0042U,0xf829a8caU,0x6feec9cfU,0x9a937bd7U,0x19b232f3U,0xb6913374U,0xa21243e1U,0xf334dd67U,0x95c9c9e9U,0x77a20c0bU,0x083eebe2U,0x02ab4bf8U,0x26ebc441U,0x214e7610U,
    0xb1298da5U,0x0e891943U,0x5c6c5f9fU,0xd61a61d8U,0x4147d95cU,0xca2d7a50U,0xbec59566U,0x557b5a5dU,0x353c6060U,0x0a039723U,0x8cebe8d9U,0x5fa281b3U,0x332950f7U,0x50a00a2fU,0x4379afc9U,0xbdd77372U,
    0xc68a019dU,0x1cb2ea5eU,0xd4bb3c24U,0x4aaea948U,0xec215565U,0xdd14192fU,0x6d1ff4f6U,0x16bbdc3aU,0xd1a86470U,0x880b711cU,0x83a89e49U,0x5b60341dU,0xbb4ca3abU,0x6d5245f9U,0x664998deU,0x9654e28fU,
    0x4ea20fb1U,0x25427666U,0xc3a1c55aU,0x2383d00bU,0x2f415e03U,0x6b95d134U,0x36282b27U,0x3c5fb8a4U,0xe4e083bdU,0x42021ba1U,0xb86bb1f9U,0x08e7ba63U,0xeb572b73U,0x1d840f9bU,0x1e03a7e9U,0x9e038163U,
  ]);

  writeln(count, " tests passed.");
}


/+
unittest {
  import std.stdio;
  auto rng = ISAACEngine(File("/dev/urandom").byChunk(ISAACEngine.MaxSeedBytes).front);
  writeln(rng.front);
}
+/
