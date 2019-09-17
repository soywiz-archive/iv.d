/*
 * Salsa20 engine by D. J. Bernstein.
 * Copyright (C) 2014 Ketmar Dark // Invisible Vector (ketmar@ketmar.no-ip.org)
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
 * Get a copy of the GNU GPL from <http://www.gnu.org/licenses/>.
 */
module iv.chachasimple /*is aliced*/;

import iv.alice;
import std.range;


// ////////////////////////////////////////////////////////////////////////// //
class ChaChaException : Exception {
  this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) pure nothrow @safe @nogc {
    super(msg, file, line, next);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct ChaCha20 {
public:
  // cipher parameters
  enum BlockSize = 64;
  enum IVSize = 8; // in bytes
  enum KeySize = 32; // in bytes

private:
  enum sigma = "expand 32-byte k";
  enum tau = "expand 16-byte k";

private:
  uint[16] state;
  ubyte[64] buf;
  uint bufpos;

public:
  this (const(void)[] key, const(void)[] nonce) @trusted { reset(key, nonce); }
  ~this () pure nothrow @trusted @nogc { state[] = 0; buf[] = 0; }

  //void reset (const(void)[] key, const(void)[] nonce) @trusted { reset(cast(const(ubyte)[])key, cast(const(ubyte)[])nonce); }

  void reset (const(void)[] key, const(void)[] nonce) @trusted {
    if (key.length != 16 && key.length != 32) throw new ChaChaException("invalid key size");
    if (nonce.length != 0 && nonce.length != 8 && nonce.length != 12) throw new ChaChaException("invalid key size");

    // setup key
    uint ofs = 0;
    string constants = tau; // 128-bit key
    if (key.length == 32) { ofs = 16; constants = sigma; } // recommended
    state.ptr[0] = loadU32(constants.ptr+0);
    state.ptr[1] = loadU32(constants.ptr+4);
    state.ptr[2] = loadU32(constants.ptr+8);
    state.ptr[3] = loadU32(constants.ptr+12);
    state.ptr[4] = loadU32(key.ptr+0);
    state.ptr[5] = loadU32(key.ptr+4);
    state.ptr[6] = loadU32(key.ptr+8);
    state.ptr[7] = loadU32(key.ptr+12);
    state.ptr[8] = loadU32(key.ptr+ofs+0);
    state.ptr[9] = loadU32(key.ptr+ofs+4);
    state.ptr[10] = loadU32(key.ptr+ofs+8);
    state.ptr[11] = loadU32(key.ptr+ofs+12);

    // setup iv
    state.ptr[12..16] = 0;
    if (nonce.length == 12) {
      state.ptr[13] = loadU32(nonce.ptr+0);
      state.ptr[14] = loadU32(nonce.ptr+4);
      state.ptr[15] = loadU32(nonce.ptr+8);
    } else if (nonce.length == 8) {
      state.ptr[14] = loadU32(nonce.ptr+0);
      state.ptr[15] = loadU32(nonce.ptr+4);
    }

    nextBuf();
  }

  enum empty = false; // endless stream
  @property ubyte front () const pure nothrow @trusted @nogc { pragma(inline, true); return buf.ptr[bufpos]; }
  @property ChaCha20 save () const pure nothrow @trusted @nogc {
    ChaCha20 res = void;
    res.state[] = state[];
    res.buf[] = buf[];
    res.bufpos = bufpos;
    return res;
  }
  void popFront () nothrow @trusted @nogc { pragma(inline, true); if (++bufpos >= 64) nextBuf(); }

  void processBuf (void[] buf) nothrow @trusted @nogc {
    auto ptr = cast(ubyte*)buf.ptr;
    foreach (immutable _; 0..buf.length) {
      *ptr++ ^= front;
      popFront();
    }
  }

private:
  void nextState () nothrow @trusted @nogc {
    enum QuarterRoundMixin(int a, int b, int c, int d) =
      "x.ptr["~a.stringof~"] = cast(uint)x.ptr["~a.stringof~"]+x.ptr["~b.stringof~"]; x.ptr["~d.stringof~"] = bitRotLeft(x.ptr["~d.stringof~"]^x.ptr["~a.stringof~"],16);\n"~
      "x.ptr["~c.stringof~"] = cast(uint)x.ptr["~c.stringof~"]+x.ptr["~d.stringof~"]; x.ptr["~b.stringof~"] = bitRotLeft(x.ptr["~b.stringof~"]^x.ptr["~c.stringof~"],12);\n"~
      "x.ptr["~a.stringof~"] = cast(uint)x.ptr["~a.stringof~"]+x.ptr["~b.stringof~"]; x.ptr["~d.stringof~"] = bitRotLeft(x.ptr["~d.stringof~"]^x.ptr["~a.stringof~"], 8);\n"~
      "x.ptr["~c.stringof~"] = cast(uint)x.ptr["~c.stringof~"]+x.ptr["~d.stringof~"]; x.ptr["~b.stringof~"] = bitRotLeft(x.ptr["~b.stringof~"]^x.ptr["~c.stringof~"], 7);\n";

    uint[16] x = state[0..16];

    foreach (immutable i; 0..10) {
      mixin(QuarterRoundMixin!(0, 4, 8,12));
      mixin(QuarterRoundMixin!(1, 5, 9,13));
      mixin(QuarterRoundMixin!(2, 6,10,14));
      mixin(QuarterRoundMixin!(3, 7,11,15));
      mixin(QuarterRoundMixin!(0, 5,10,15));
      mixin(QuarterRoundMixin!(1, 6,11,12));
      mixin(QuarterRoundMixin!(2, 7, 8,13));
      mixin(QuarterRoundMixin!(3, 4, 9,14));
    }

    foreach (immutable i, ref n; x) n += state.ptr[i];
    auto outp = buf.ptr;
    foreach (uint n; x) {
      *outp++ = n&0xff;
      *outp++ = (n>>8)&0xff;
      *outp++ = (n>>16)&0xff;
      *outp++ = (n>>24)&0xff;
    }
  }

  void nextBuf () nothrow @trusted @nogc {
    nextState();
    if (++state.ptr[12] == 0) ++state.ptr[13]; // stopping at 2^70 bytes per nonce is user's responsibility
    bufpos = 0;
  }

static:
  static uint bitRotLeft (uint v, uint n) pure nothrow @safe @nogc { pragma(inline, true); return (v<<n)|(v>>(32-n)); }

  uint loadU32 (const(void)* dp) nothrow @trusted @nogc {
    uint res = 0;
    auto n = cast(const(ubyte)*)dp;
    res |= cast(uint)n[0];
    res |= cast(uint)n[1]<<8;
    res |= cast(uint)n[2]<<16;
    res |= cast(uint)n[3]<<24;
    return res;
  }
}


version(test_chachasimple) unittest {
  import std.stdio;

  uint count = 0;

  void test (const(void)[] key, const(void)[] iv, const(void)[] ks, const(uint)[] xstb=null) {
    auto bks = cast(const(ubyte)[])ks;
    auto ctx = ChaCha20(key, iv);

    if (xstb.length) {
      uint[16] xst = xstb[0..16];
      ++xst[12];
      if (ctx.state[] != xst[]) {
        import std.stdio;
        foreach (immutable idx; 0..16) {
          writefln("idx=%s; xst=0x%08x, st=0x%08x", idx, xst[idx], ctx.state[idx]);
          assert(xst[idx] == ctx.state[idx]);
        }
      }
    }

    foreach (immutable idx, ubyte v; bks) {
      if (ctx.front != v) {
        import std.string : format;
        assert(0, "failed! idx=%s; v=%02X %02X".format(idx, v, ctx.front));
      }
      ctx.popFront();
    }

    //writeln("test ", count, " passed");
    ++count;
  }


  writeln("testing ChaCha20...");

  { //0
    immutable[] key = x"00000000000000000000000000000000";
    immutable[] nonce = x"0000000000000000";
    immutable[] ks = x"89670952608364FD00B2F90936F031C8E756E15DBA04B8493D00429259B20F46CC04F111246B6C2CE066BE3BFB32D9AA0FDDFBC12123D4B9E44F34DCA05A103F6CD135C2878C832B5896B134F6142A9D4D8D0D8F1026D20A0A81512CBCE6E9758A7143D021978022A384141A80CEA3062F41F67A752E66AD3411984C787E30AD";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,];
    test(key[], nonce[], ks[], st[]);
  }
  { //1
    immutable[] key = x"0000000000000000000000000000000000000000000000000000000000000000";
    immutable[] nonce = x"0000000000000000";
    immutable[] ks = x"76B8E0ADA0F13D90405D6AE55386BD28BDD219B8A08DED1AA836EFCC8B770DC7DA41597C5157488D7724E03FB8D84A376A43B8F41518A11CC387B669B2EE65869F07E7BE5551387A98BA977C732D080DCB0F29A048E3656912C6533E32EE7AED29B721769CE64E43D57133B074D839D531ED1F28510AFB45ACE10A1F4B794D6F";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,];
    test(key[], nonce[], ks[], st[]);
  }
  { //2
    immutable[] key = x"01000000000000000000000000000000";
    immutable[] nonce = x"0000000000000000";
    immutable[] ks = x"AE56060D04F5B597897FF2AF1388DBCEFF5A2A4920335DC17A3CB1B1B10FBE70ECE8F4864D8C7CDF0076453A8291C7DBEB3AA9C9D10E8CA36BE4449376ED7C42FC3D471C34A36FBBF616BC0A0E7C523030D944F43EC3E78DD6A12466547CB4F7B3CEBD0A5005E762E562D1375B7AC44593A991B85D1A60FBA2035DFAA2A642D5";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0x00000001,0x00000000,0x00000000,0x00000000,0x00000001,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,];
    test(key[], nonce[], ks[], st[]);
  }
  { //3
    immutable[] key = x"0100000000000000000000000000000000000000000000000000000000000000";
    immutable[] nonce = x"0000000000000000";
    immutable[] ks = x"C5D30A7CE1EC119378C84F487D775A8542F13ECE238A9455E8229E888DE85BBD29EB63D0A17A5B999B52DA22BE4023EB07620A54F6FA6AD8737B71EB0464DAC010F656E6D1FD55053E50C4875C9930A33F6D0263BD14DFD6AB8C70521C19338B2308B95CF8D0BB7D202D2102780EA3528F1CB48560F76B20F382B942500FCEAC";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0x00000001,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,];
    test(key[], nonce[], ks[], st[]);
  }
  { //4
    immutable[] key = x"00000000000000000000000000000000";
    immutable[] nonce = x"0100000000000000";
    immutable[] ks = x"1663879EB3F2C9949E2388CAA343D361BB132771245AE6D027CA9CB010DC1FA7178DC41F8278BC1F64B3F12769A24097F40D63A86366BDB36AC08ABE60C07FE8B057375C89144408CC744624F69F7F4CCBD93366C92FC4DFCADA65F1B959D8C64DFC50DE711FB46416C2553CC60F21BBFD006491CB17888B4FB3521C4FDD8745";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000001,0x00000000,];
    test(key[], nonce[], ks[], st[]);
  }
  { //5
    immutable[] key = x"0000000000000000000000000000000000000000000000000000000000000000";
    immutable[] nonce = x"0100000000000000";
    immutable[] ks = x"EF3FDFD6C61578FBF5CF35BD3DD33B8009631634D21E42AC33960BD138E50D32111E4CAF237EE53CA8AD6426194A88545DDC497A0B466E7D6BBDB0041B2F586B5305E5E44AFF19B235936144675EFBE4409EB7E8E5F1430F5F5836AEB49BB5328B017C4B9DC11F8A03863FA803DC71D5726B2B6B31AA32708AFE5AF1D6B69058";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000001,0x00000000,];
    test(key[], nonce[], ks[], st[]);
  }
  { //6
    immutable[] key = x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
    immutable[] nonce = x"FFFFFFFFFFFFFFFF";
    immutable[] ks = x"992947C3966126A0E660A3E95DB048DE091FB9E0185B1E41E41015BB7EE50150399E4760B262F9D53F26D8DD19E56F5C506AE0C3619FA67FB0C408106D0203EE40EA3CFA61FA32A2FDA8D1238A2135D9D4178775240F99007064A6A7F0C731B67C227C52EF796B6BED9F9059BA0614BCF6DD6E38917F3B150E576375BE50ED67";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0x00000000,0x00000000,0xffffffff,0xffffffff,];
    test(key[], nonce[], ks[], st[]);
  }
  { //7
    immutable[] key = x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
    immutable[] nonce = x"FFFFFFFFFFFFFFFF";
    immutable[] ks = x"D9BF3F6BCE6ED0B54254557767FB57443DD4778911B606055C39CC25E674B8363FEABC57FDE54F790C52C8AE43240B79D49042B777BFD6CB80E931270B7F50EB5BAC2ACD86A836C5DC98C116C1217EC31D3A63A9451319F097F3B4D6DAB0778719477D24D24B403A12241D7CCA064F790F1D51CCAFF6B1667D4BBCA1958C4306";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff,0x00000000,0x00000000,0xffffffff,0xffffffff,];
    test(key[], nonce[], ks[], st[]);
  }
  { //8
    immutable[] key = x"55555555555555555555555555555555";
    immutable[] nonce = x"5555555555555555";
    immutable[] ks = x"357D7D94F966778F5815A2051DCB04133B26B0EAD9F57DD09927837BC3067E4B6BF299AD81F7F50C8DA83C7810BFC17BB6F4813AB6C326957045FD3FD5E19915EC744A6B9BF8CBDCB36D8B6A5499C68A08EF7BE6CC1E93F2F5BCD2CAD4E47C18A3E5D94B5666382C6D130D822DD56AACB0F8195278E7B292495F09868DDF12CC";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x00000000,0x00000000,0x55555555,0x55555555,];
    test(key[], nonce[], ks[], st[]);
  }
  { //9
    immutable[] key = x"5555555555555555555555555555555555555555555555555555555555555555";
    immutable[] nonce = x"5555555555555555";
    immutable[] ks = x"BEA9411AA453C5434A5AE8C92862F564396855A9EA6E22D6D3B50AE1B3663311A4A3606C671D605CE16C3AECE8E61EA145C59775017BEE2FA6F88AFC758069F7E0B8F676E644216F4D2A3422D7FA36C6C4931ACA950E9DA42788E6D0B6D1CD838EF652E97B145B14871EAE6C6804C7004DB5AC2FCE4C68C726D004B10FCABA86";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x55555555,0x00000000,0x00000000,0x55555555,0x55555555,];
    test(key[], nonce[], ks[], st[]);
  }
  { //10
    immutable[] key = x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    immutable[] nonce = x"AAAAAAAAAAAAAAAA";
    immutable[] ks = x"FC79ACBD58526103862776AAB20F3B7D8D3149B2FAB65766299316B6E5B16684DE5DE548C1B7D083EFD9E3052319E0C6254141DA04A6586DF800F64D46B01C871F05BC67E07628EBE6F6865A2177E0B66A558AA7CC1E8FF1A98D27F7071F8335EFCE4537BB0EF7B573B32F32765F29007DA53BBA62E7A44D006F41EB28FE15D6";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0x00000000,0x00000000,0xaaaaaaaa,0xaaaaaaaa,];
    test(key[], nonce[], ks[], st[]);
  }
  { //11
    immutable[] key = x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    immutable[] nonce = x"AAAAAAAAAAAAAAAA";
    immutable[] ks = x"9AA2A9F656EFDE5AA7591C5FED4B35AEA2895DEC7CB4543B9E9F21F5E7BCBCF3C43C748A970888F8248393A09D43E0B7E164BC4D0B0FB240A2D72115C480890672184489440545D021D97EF6B693DFE5B2C132D47E6F041C9063651F96B623E62A11999A23B6F7C461B2153026AD5E866A2E597ED07B8401DEC63A0934C6B2A9";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0xaaaaaaaa,0x00000000,0x00000000,0xaaaaaaaa,0xaaaaaaaa,];
    test(key[], nonce[], ks[], st[]);
  }
  { //12
    immutable[] key = x"00112233445566778899AABBCCDDEEFF";
    immutable[] nonce = x"0F1E2D3C4B5A6978";
    immutable[] ks = x"D1ABF630467EB4F67F1CFB47CD626AAE8AFEDBBE4FF8FC5FE9CFAE307E74ED451F1404425AD2B54569D5F18148939971ABB8FAFC88CE4AC7FE1C3D1F7A1EB7CAE76CA87B61A9713541497760DD9AE059350CAD0DCEDFAA80A883119A1A6F987FD1CE91FD8EE0828034B411200A9745A285554475D12AFC04887FEF3516D12A2C";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0x33221100,0x77665544,0xbbaa9988,0xffeeddcc,0x33221100,0x77665544,0xbbaa9988,0xffeeddcc,0x00000000,0x00000000,0x3c2d1e0f,0x78695a4b,];
    test(key[], nonce[], ks[], st[]);
  }
  { //13
    immutable[] key = x"00112233445566778899AABBCCDDEEFFFFEEDDCCBBAA99887766554433221100";
    immutable[] nonce = x"0F1E2D3C4B5A6978";
    immutable[] ks = x"9FADF409C00811D00431D67EFBD88FBA59218D5D6708B1D685863FABBB0E961EEA480FD6FB532BFD494B2151015057423AB60A63FE4F55F7A212E2167CCAB931FBFD29CF7BC1D279EDDF25DD316BB8843D6EDEE0BD1EF121D12FA17CBC2C574CCCAB5E275167B08BD686F8A09DF87EC3FFB35361B94EBFA13FEC0E4889D18DA5";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0x33221100,0x77665544,0xbbaa9988,0xffeeddcc,0xccddeeff,0x8899aabb,0x44556677,0x00112233,0x00000000,0x00000000,0x3c2d1e0f,0x78695a4b,];
    test(key[], nonce[], ks[], st[]);
  }
  { //14
    immutable[] key = x"C46EC1B18CE8A878725A37E780DFB735";
    immutable[] nonce = x"1ADA31D5CF688221";
    immutable[] ks = x"826ABDD84460E2E9349F0EF4AF5B179B426E4B2D109A9C5BB44000AE51BEA90A496BEEEF62A76850FF3F0402C4DDC99F6DB07F151C1C0DFAC2E56565D62896255B23132E7B469C7BFB88FA95D44CA5AE3E45E848A4108E98BAD7A9EB15512784A6A9E6E591DCE674120ACAF9040FF50FF3AC30CCFB5E14204F5E4268B90A8804";
    immutable uint[] st = [0x61707865,0x3120646e,0x79622d36,0x6b206574,0xb1c16ec4,0x78a8e88c,0xe7375a72,0x35b7df80,0xb1c16ec4,0x78a8e88c,0xe7375a72,0x35b7df80,0x00000000,0x00000000,0xd531da1a,0x218268cf,];
    test(key[], nonce[], ks[], st[]);
  }
  { //15
    immutable[] key = x"C46EC1B18CE8A878725A37E780DFB7351F68ED2E194C79FBC6AEBEE1A667975D";
    immutable[] nonce = x"1ADA31D5CF688221";
    immutable[] ks = x"F63A89B75C2271F9368816542BA52F06ED49241792302B00B5E8F80AE9A473AFC25B218F519AF0FDD406362E8D69DE7F54C604A6E00F353F110F771BDCA8AB92E5FBC34E60A1D9A9DB17345B0A402736853BF910B060BDF1F897B6290F01D138AE2C4C90225BA9EA14D518F55929DEA098CA7A6CCFE61227053C84E49A4A3332";
    immutable uint[] st = [0x61707865,0x3320646e,0x79622d32,0x6b206574,0xb1c16ec4,0x78a8e88c,0xe7375a72,0x35b7df80,0x2eed681f,0xfb794c19,0xe1beaec6,0x5d9767a6,0x00000000,0x00000000,0xd531da1a,0x218268cf,];
    test(key[], nonce[], ks[], st[]);
  }

  {
    immutable[] key = x"0000000000000000000000000000000000000000000000000000000000000000";
    immutable[] nonce = x"0000000000000000";
    immutable[] ks = x"76b8e0ada0f13d90405d6ae55386bd28bdd219b8a08ded1aa836efcc8b770dc7da41597c5157488d7724e03fb8d84a376a43b8f41518a11cc387b669b2ee6586";
    test(key[], nonce[], ks[]);
  }

  {
    immutable[] key = x"0000000000000000000000000000000000000000000000000000000000000001";
    immutable[] nonce = x"0000000000000000";
    immutable[] ks = x"4540f05a9f1fb296d7736e7b208e3c96eb4fe1834688d2604f450952ed432d41bbe2a0b6ea7566d2a5d1e7e20d42af2c53d792b1c43fea817e9ad275ae546963";
    test(key[], nonce[], ks[]);
  }

  {
    immutable[] key = x"0000000000000000000000000000000000000000000000000000000000000000";
    immutable[] nonce = x"0000000000000001";
    immutable[] ks = x"de9cba7bf3d69ef5e786dc63973f653a0b49e015adbff7134fcb7df137821031e85a050278a7084527214f73efc7fa5b5277062eb7a0433e445f41e3";
    test(key[], nonce[], ks[]);
  }

  {
    immutable[] key = x"0000000000000000000000000000000000000000000000000000000000000000";
    immutable[] nonce = x"0100000000000000";
    immutable[] ks = x"ef3fdfd6c61578fbf5cf35bd3dd33b8009631634d21e42ac33960bd138e50d32111e4caf237ee53ca8ad6426194a88545ddc497a0b466e7d6bbdb0041b2f586b";
    test(key[], nonce[], ks[]);
  }

  {
    immutable[] key = x"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
    immutable[] nonce = x"0001020304050607";
    immutable[] ks = x"f798a189f195e66982105ffb640bb7757f579da31602fc93ec01ac56f85ac3c134a4547b733b46413042c9440049176905d3be59ea1c53f15916155c2be8241a38008b9a26bc35941e2444177c8ade6689de95264986d95889fb60e84629c9bd9a5acb1cc118be563eb9b3a4a472f82e09a7e778492b562ef7130e88dfe031c79db9d4f7c7a899151b9a475032b63fc385245fe054e3dd5a97a5f576fe064025d3ce042c566ab2c507b138db853e3d6959660996546cc9c4a6eafdc777c040d70eaf46f76dad3979e5c5360c3317166a1c894c94a371876a94df7628fe4eaaf2ccb27d5aaae0ad7ad0f9d4b6ad3b54098746d4524d38407a6deb3ab78fab78c9";
    test(key[], nonce[], ks[]);
  }

  writeln(count, " tests passed.");
}
