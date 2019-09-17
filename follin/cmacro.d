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
module iv.follin.cmacro /*is aliced*/;
import iv.alice;


// cool helper to translate C defines
template cmacroFixVars(T...) {
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
  usize hashBuffer (const(void)* buf, usize len, usize seed=0) pure nothrow @trusted @nogc {
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

  string cmacroFixVars (string s, string[] names...) {
    assert(T.length == names.length, "cmacroFixVars: names and arguments count mismatch");
    enum tmpPfxName = "__temp_prefix__";
    string res;
    string tmppfx;
    uint pos = 0;
    // skip empty lines (for pretty printing)
    // trim trailing spaces
    while (s.length > 0 && s[$-1] <= ' ') s = s[0..$-1];
    uint linestpos = 0; // start of the current line
    while (pos < s.length) {
      if (s[pos] > ' ') break;
      if (s[pos] == '\n') linestpos = pos+1;
      ++pos;
    }
    pos = linestpos;
    while (pos+2 < s.length) {
      int epos = pos;
      while (epos+2 < s.length && (s[epos] != '$' || s[epos+1] != '{')) ++epos;
      if (epos > pos) {
        if (s.length-epos < 3) break;
        res ~= s[pos..epos];
        pos = epos;
      }
      assert(s[pos] == '$' && s[pos+1] == '{');
      pos += 2;
      bool found = false;
      if (s.length-pos >= tmpPfxName.length+1 && s[pos+tmpPfxName.length] == '}' && s[pos..pos+tmpPfxName.length] == tmpPfxName) {
        if (tmppfx.length == 0) {
          // generate temporary prefix
          auto hash = hashBuffer(s.ptr, s.length);
          immutable char[16] hexChars = "0123456789abcdef";
          tmppfx = "_temp_macro_var_";
          foreach_reverse (immutable idx; 0..usize.sizeof*2) {
            tmppfx ~= hexChars[hash&0x0f];
            hash >>= 4;
          }
          tmppfx ~= "_";
        }
        pos += tmpPfxName.length+1;
        res ~= tmppfx;
        found = true;
      } else {
        foreach (immutable nidx, string oname; T) {
          static assert(oname.length > 0);
          if (s.length-pos >= oname.length+1 && s[pos+oname.length] == '}' && s[pos..pos+oname.length] == oname) {
            found = true;
            pos += oname.length+1;
            res ~= names[nidx];
            break;
          }
        }
      }
      assert(found, "unknown variable in macro");
    }
    if (pos < s.length) res ~= s[pos..$];
    return res;
  }
}


/*
//void draw_line (float* ${output}, int ${x0}, int ${y0}, int ${x1}, int ${y1}, int ${n})
enum draw_line(string output, string x0, string y0, string x1, string y1, string n) = q{{
  int ${__temp_prefix__}dy = ${y1}-${y0};
  int ${__temp_prefix__}adx = ${x1}-${x0};
  int ${__temp_prefix__}ady = mixin(ABS!"${__temp_prefix__}dy");
  int ${__temp_prefix__}base;
  int ${__temp_prefix__}x = ${x0}, ${__temp_prefix__}y = ${y0};
  int ${__temp_prefix__}err = 0;
  int ${__temp_prefix__}sy;

  version(STB_VORBIS_DIVIDE_TABLE) {
    if (${__temp_prefix__}adx < DIVTAB_DENOM && ${__temp_prefix__}ady < DIVTAB_NUMER) {
      if (${__temp_prefix__}dy < 0) {
        ${__temp_prefix__}base = -integer_divide_table[${__temp_prefix__}ady][${__temp_prefix__}adx];
        ${__temp_prefix__}sy = ${__temp_prefix__}base-1;
      } else {
        ${__temp_prefix__}base = integer_divide_table[${__temp_prefix__}ady][${__temp_prefix__}adx];
        ${__temp_prefix__}sy = ${__temp_prefix__}base+1;
      }
    } else {
      ${__temp_prefix__}base = ${__temp_prefix__}dy/${__temp_prefix__}adx;
      ${__temp_prefix__}sy = ${__temp_prefix__}base+(${__temp_prefix__}dy < 0 ? -1 : 1);
    }
  } else {
    ${__temp_prefix__}base = ${__temp_prefix__}dy/${__temp_prefix__}adx;
    ${__temp_prefix__}sy = ${__temp_prefix__}base+(${__temp_prefix__}dy < 0 ? -1 : 1);
  }
  ${__temp_prefix__}ady -= mixin(ABS!"${__temp_prefix__}base")*${__temp_prefix__}adx;
  if (${x1} > ${n}) ${x1} = ${n};
  mixin(LINE_OP!("${output}[${__temp_prefix__}x]", "inverse_db_table[${__temp_prefix__}y]"));
  for (++${__temp_prefix__}x; ${__temp_prefix__}x < ${x1}; ++${__temp_prefix__}x) {
    ${__temp_prefix__}err += ${__temp_prefix__}ady;
    if (${__temp_prefix__}err >= ${__temp_prefix__}adx) {
      ${__temp_prefix__}err -= ${__temp_prefix__}adx;
      ${__temp_prefix__}y += ${__temp_prefix__}sy;
    } else {
      ${__temp_prefix__}y += ${__temp_prefix__}base;
    }
    mixin(LINE_OP!("${output}[${__temp_prefix__}x]", "inverse_db_table[${__temp_prefix__}y]"));
  }
}}.cmacroFixVars!("output", "x0", "y0", "x1", "y1", "n")(output, x0, y0, x1, y1, n);
*/
