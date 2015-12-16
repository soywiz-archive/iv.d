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
// Totro-inspired random name generator, clean room implementation
module iv.namegen is aliced;
private:

import iv.stream;


public struct NameGen {
private:
  enum { Vowel = 0, Consonant = 1 }

  enum {
    WordBeg = 0x01,
    WordMid = 0x02,
    WordEnd = 0x04,
  }

  static struct Syllable {
  private:
    char[3] sytext = 0;
    ubyte code; // WordXXX mask
    uint count;

  public:
    bool opEqual (in Syllable sy) const @safe pure nothrow @nogc {
      return (this.code == sy.code && this.count == sy.count && this.str == sy.str);
    }

    @property string str () const @trusted pure nothrow @nogc {
      usize sz = 0;
      while (sz < sytext.length && sytext[sz]) ++sz;
      return cast(string)sytext[0..sz];
    }

    debug @property string codeStr () const @trusted pure nothrow @nogc {
      switch (code) {
        case WordBeg: return "WordBeg";
        case WordMid: return "WordMid";
        case WordEnd: return "WordEnd";
        case WordBeg|WordMid: return "WordBeg|WordMid";
        case WordBeg|WordEnd: return "WordBeg|WordEnd";
        case WordBeg|WordMid|WordEnd: return "WordBeg|WordMid|WordEnd";
        case WordMid|WordEnd: return "WordMid|WordEnd";
        default: return "FUCKED";
      }
    }
  }

  // totro tables
  static immutable Syllable[26] totroSyllsV = [
    {sytext:"'\0", count:1, code:WordMid},
    {sytext:"y\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"aa\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ae\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ai\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ao\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"au\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ea\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ee\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"eo\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"eu\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ia\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ii\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"io\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"iu\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"oa\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"oe\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"oi\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"oo\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ou\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"eau", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"a\0", count:12, code:WordBeg|WordMid|WordEnd},
    {sytext:"e\0", count:12, code:WordBeg|WordMid|WordEnd},
    {sytext:"i\0", count:12, code:WordBeg|WordMid|WordEnd},
    {sytext:"o\0", count:12, code:WordBeg|WordMid|WordEnd},
    {sytext:"u\0", count:12, code:WordBeg|WordMid|WordEnd},
  ];
  static immutable Syllable[51] totroSyllsC = [
    {sytext:"x\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"y\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"z\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ch\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"ck\0", count:1, code:WordMid|WordEnd},
    {sytext:"cl\0", count:1, code:WordBeg|WordMid},
    {sytext:"cr\0", count:1, code:WordBeg|WordMid},
    {sytext:"fl\0", count:1, code:WordBeg|WordMid},
    {sytext:"gh\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"gl\0", count:1, code:WordBeg|WordMid},
    {sytext:"kl\0", count:1, code:WordBeg|WordMid},
    {sytext:"ll\0", count:1, code:WordBeg|WordMid},
    {sytext:"nk\0", count:1, code:WordMid|WordEnd},
    {sytext:"ph\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"pl\0", count:1, code:WordBeg|WordMid},
    {sytext:"pr\0", count:1, code:WordBeg|WordMid},
    {sytext:"qu\0", count:1, code:WordBeg|WordMid},
    {sytext:"rk\0", count:1, code:WordMid|WordEnd},
    {sytext:"sc\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"sh\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"sk\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"sl\0", count:1, code:WordBeg|WordMid},
    {sytext:"sr\0", count:1, code:WordBeg|WordMid},
    {sytext:"ss\0", count:1, code:WordMid|WordEnd},
    {sytext:"st\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"th\0", count:1, code:WordBeg|WordMid|WordEnd},
    {sytext:"tr\0", count:1, code:WordBeg|WordMid},
    {sytext:"wh\0", count:1, code:WordBeg|WordMid},
    {sytext:"str", count:1, code:WordBeg|WordMid},
    {sytext:"br\0", count:2, code:WordBeg|WordMid},
    {sytext:"dr\0", count:2, code:WordBeg|WordMid},
    {sytext:"fr\0", count:2, code:WordBeg|WordMid},
    {sytext:"gr\0", count:2, code:WordBeg|WordMid},
    {sytext:"kr\0", count:2, code:WordBeg|WordMid},
    {sytext:"b\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"c\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"d\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"f\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"g\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"h\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"j\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"k\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"l\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"m\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"n\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"p\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"r\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"s\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"t\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"v\0", count:3, code:WordBeg|WordMid|WordEnd},
    {sytext:"w\0", count:3, code:WordBeg|WordMid|WordEnd},
  ];

  Syllable[][2] sylls = [totroSyllsV, totroSyllsC];
  uint[2] totals = [81, 90];

  static uint defaultUni (uint max) @trusted nothrow @nogc {
    import iv.prng;
    static BJRng prng;
    static bool inited = false;
    if (!inited) {
      prng.randomize();
      inited = true;
    }
    return prng.next%max; // this is not uniform, but i don't care
  }

  uint rand (uint min, uint max) const @trusted nothrow @nogc {
    return (genRand is null ? defaultUni(max-min+1) : genRand(max-min+1))+min;
  }

public:
  // generate random number, [0..max); max is never uint.max or 0
  uint delegate (uint max) @trusted nothrow @nogc genRand;

  void setTotro() () {
    sylls[0] = totroSyllsV.dup;
    sylls[1] = totroSyllsC.dup;
    totals = [81, 90];
  }

  void setSW() () {
    // [11979, 16732]
    static immutable Syllable[56] swSyllsV = [
      {sytext:"ui\0", count:1, code:WordMid},
      {sytext:"aea", count:1, code:WordBeg},
      {sytext:"ooo", count:1, code:WordBeg},
      {sytext:"uee", count:2, code:WordMid},
      {sytext:"oe\0", count:2, code:WordBeg},
      {sytext:"aee", count:2, code:WordBeg},
      {sytext:"aeo", count:2, code:WordBeg},
      {sytext:"eeo", count:2, code:WordMid},
      {sytext:"oa\0", count:2, code:WordBeg},
      {sytext:"eu\0", count:3, code:WordMid},
      {sytext:"io\0", count:3, code:WordMid},
      {sytext:"ou\0", count:4, code:WordMid},
      {sytext:"uo\0", count:4, code:WordMid},
      {sytext:"eeu", count:4, code:WordMid},
      {sytext:"ooe", count:4, code:WordBeg},
      {sytext:"ooi", count:4, code:WordBeg},
      {sytext:"ou\0", count:5, code:WordBeg},
      {sytext:"eea", count:5, code:WordMid},
      {sytext:"aei", count:5, code:WordBeg},
      {sytext:"oi\0", count:6, code:WordBeg},
      {sytext:"eee", count:6, code:WordMid},
      {sytext:"au\0", count:8, code:WordMid},
      {sytext:"eei", count:9, code:WordMid},
      {sytext:"oee", count:12, code:WordMid},
      {sytext:"ie\0", count:14, code:WordMid},
      {sytext:"ii\0", count:14, code:WordMid},
      {sytext:"aee", count:15, code:WordMid},
      {sytext:"eo\0", count:15, code:WordMid},
      {sytext:"oo\0", count:16, code:WordMid},
      {sytext:"ei\0", count:16, code:WordMid},
      {sytext:"oe\0", count:17, code:WordMid},
      {sytext:"oa\0", count:22, code:WordMid},
      {sytext:"ea\0", count:25, code:WordMid},
      {sytext:"aa\0", count:29, code:WordMid},
      {sytext:"ae\0", count:49, code:WordBeg},
      {sytext:"ai\0", count:51, code:WordMid},
      {sytext:"oo\0", count:54, code:WordBeg},
      {sytext:"ae\0", count:55, code:WordMid},
      {sytext:"ue\0", count:61, code:WordMid},
      {sytext:"ia\0", count:64, code:WordMid},
      {sytext:"ua\0", count:69, code:WordMid},
      {sytext:"ao\0", count:86, code:WordMid},
      {sytext:"oi\0", count:91, code:WordMid},
      {sytext:"o\0", count:106, code:WordBeg},
      {sytext:"e\0", count:113, code:WordBeg},
      {sytext:"o\0", count:130, code:WordEnd},
      {sytext:"ee\0", count:152, code:WordMid},
      {sytext:"i\0", count:165, code:WordEnd},
      {sytext:"e\0", count:455, code:WordEnd},
      {sytext:"a\0", count:477, code:WordBeg},
      {sytext:"u\0", count:815, code:WordMid},
      {sytext:"a\0", count:890, code:WordEnd},
      {sytext:"o\0", count:1322, code:WordMid},
      {sytext:"i\0", count:1481, code:WordMid},
      {sytext:"e\0", count:2376, code:WordMid},
      {sytext:"a\0", count:2637, code:WordMid},
    ];
    static immutable Syllable[389] swSyllsC = [
      {sytext:"ntg", count:1, code:WordMid},
      {sytext:"yc\0", count:1, code:WordMid},
      {sytext:"xg\0", count:1, code:WordMid},
      {sytext:"xw\0", count:1, code:WordMid},
      {sytext:"tm\0", count:1, code:WordMid},
      {sytext:"td\0", count:1, code:WordMid},
      {sytext:"sq\0", count:1, code:WordMid},
      {sytext:"thh", count:1, code:WordMid},
      {sytext:"rrc", count:1, code:WordMid},
      {sytext:"yg\0", count:1, code:WordMid},
      {sytext:"rdv", count:1, code:WordMid},
      {sytext:"ndb", count:1, code:WordMid},
      {sytext:"trd", count:1, code:WordBeg},
      {sytext:"bv\0", count:1, code:WordMid},
      {sytext:"vpr", count:1, code:WordMid},
      {sytext:"shr", count:1, code:WordMid},
      {sytext:"xhr", count:1, code:WordMid},
      {sytext:"dm\0", count:1, code:WordMid},
      {sytext:"ndw", count:1, code:WordMid},
      {sytext:"sv\0", count:1, code:WordMid},
      {sytext:"yd\0", count:1, code:WordMid},
      {sytext:"tg\0", count:1, code:WordMid},
      {sytext:"ndp", count:1, code:WordMid},
      {sytext:"rrn", count:1, code:WordMid},
      {sytext:"lfb", count:1, code:WordMid},
      {sytext:"sck", count:1, code:WordMid},
      {sytext:"bs\0", count:1, code:WordMid},
      {sytext:"kdg", count:1, code:WordMid},
      {sytext:"ss\0", count:1, code:WordMid},
      {sytext:"ntp", count:1, code:WordMid},
      {sytext:"xq\0", count:1, code:WordMid},
      {sytext:"thv", count:1, code:WordMid},
      {sytext:"tb\0", count:1, code:WordMid},
      {sytext:"sm\0", count:1, code:WordMid},
      {sytext:"ntb", count:1, code:WordMid},
      {sytext:"trc", count:1, code:WordBeg},
      {sytext:"xs\0", count:1, code:WordMid},
      {sytext:"ntc", count:1, code:WordMid},
      {sytext:"thw", count:1, code:WordMid},
      {sytext:"vg\0", count:1, code:WordMid},
      {sytext:"ntd", count:1, code:WordMid},
      {sytext:"yt\0", count:1, code:WordMid},
      {sytext:"trh", count:1, code:WordBeg},
      {sytext:"ryg", count:1, code:WordBeg},
      {sytext:"xtr", count:1, code:WordMid},
      {sytext:"rrb", count:1, code:WordMid},
      {sytext:"sh\0", count:1, code:WordMid},
      {sytext:"ryc", count:1, code:WordBeg},
      {sytext:"tsy", count:1, code:WordMid},
      {sytext:"bk\0", count:1, code:WordMid},
      {sytext:"bg\0", count:1, code:WordMid},
      {sytext:"lfq", count:1, code:WordMid},
      {sytext:"lfg", count:1, code:WordMid},
      {sytext:"vv\0", count:1, code:WordMid},
      {sytext:"nds", count:1, code:WordMid},
      {sytext:"tt\0", count:1, code:WordMid},
      {sytext:"rkc", count:1, code:WordMid},
      {sytext:"ntw", count:1, code:WordMid},
      {sytext:"tck", count:1, code:WordMid},
      {sytext:"bb\0", count:1, code:WordMid},
      {sytext:"bll", count:1, code:WordMid},
      {sytext:"lfn", count:1, code:WordMid},
      {sytext:"rkg", count:1, code:WordMid},
      {sytext:"rkq", count:2, code:WordMid},
      {sytext:"xck", count:2, code:WordMid},
      {sytext:"xv\0", count:2, code:WordMid},
      {sytext:"ydr", count:2, code:WordMid},
      {sytext:"ttr", count:2, code:WordMid},
      {sytext:"vc\0", count:2, code:WordMid},
      {sytext:"ts\0", count:2, code:WordMid},
      {sytext:"trb", count:2, code:WordBeg},
      {sytext:"sw\0", count:2, code:WordMid},
      {sytext:"tw\0", count:2, code:WordMid},
      {sytext:"ryn", count:2, code:WordBeg},
      {sytext:"vs\0", count:2, code:WordMid},
      {sytext:"yb\0", count:2, code:WordMid},
      {sytext:"xt\0", count:2, code:WordMid},
      {sytext:"str", count:2, code:WordMid},
      {sytext:"kpr", count:2, code:WordMid},
      {sytext:"khr", count:2, code:WordMid},
      {sytext:"nts", count:2, code:WordMid},
      {sytext:"xk\0", count:2, code:WordMid},
      {sytext:"rkv", count:2, code:WordMid},
      {sytext:"nth", count:2, code:WordMid},
      {sytext:"rrl", count:2, code:WordMid},
      {sytext:"bhr", count:2, code:WordMid},
      {sytext:"ryd", count:2, code:WordBeg},
      {sytext:"thc", count:2, code:WordMid},
      {sytext:"bdr", count:2, code:WordMid},
      {sytext:"sc\0", count:2, code:WordMid},
      {sytext:"sl\0", count:2, code:WordMid},
      {sytext:"tc\0", count:2, code:WordMid},
      {sytext:"rym", count:2, code:WordBeg},
      {sytext:"rrg", count:2, code:WordMid},
      {sytext:"kq\0", count:2, code:WordMid},
      {sytext:"lfl", count:2, code:WordMid},
      {sytext:"lfm", count:2, code:WordMid},
      {sytext:"thb", count:2, code:WordMid},
      {sytext:"vsy", count:2, code:WordMid},
      {sytext:"sg\0", count:2, code:WordMid},
      {sytext:"lfp", count:2, code:WordMid},
      {sytext:"yw\0", count:2, code:WordMid},
      {sytext:"rkb", count:2, code:WordMid},
      {sytext:"trl", count:2, code:WordBeg},
      {sytext:"ryh", count:2, code:WordBeg},
      {sytext:"sn\0", count:2, code:WordMid},
      {sytext:"rrq", count:2, code:WordMid},
      {sytext:"nhr", count:2, code:WordMid},
      {sytext:"ysy", count:2, code:WordMid},
      {sytext:"thd", count:2, code:WordMid},
      {sytext:"ndv", count:2, code:WordMid},
      {sytext:"vq\0", count:2, code:WordMid},
      {sytext:"db\0", count:2, code:WordMid},
      {sytext:"ndh", count:2, code:WordMid},
      {sytext:"tk\0", count:2, code:WordMid},
      {sytext:"rdp", count:2, code:WordMid},
      {sytext:"yck", count:2, code:WordMid},
      {sytext:"bdg", count:2, code:WordMid},
      {sytext:"dd\0", count:2, code:WordMid},
      {sytext:"rrt", count:2, code:WordMid},
      {sytext:"kll", count:2, code:WordMid},
      {sytext:"thp", count:2, code:WordMid},
      {sytext:"xm\0", count:2, code:WordMid},
      {sytext:"ntt", count:2, code:WordMid},
      {sytext:"xb\0", count:2, code:WordMid},
      {sytext:"ds\0", count:2, code:WordMid},
      {sytext:"tq\0", count:2, code:WordMid},
      {sytext:"rdc", count:2, code:WordMid},
      {sytext:"lfv", count:2, code:WordMid},
      {sytext:"ym\0", count:2, code:WordMid},
      {sytext:"rll", count:2, code:WordMid},
      {sytext:"xdr", count:2, code:WordMid},
      {sytext:"lfd", count:2, code:WordMid},
      {sytext:"rrk", count:2, code:WordMid},
      {sytext:"ytr", count:3, code:WordMid},
      {sytext:"dk\0", count:3, code:WordMid},
      {sytext:"vt\0", count:3, code:WordMid},
      {sytext:"dll", count:3, code:WordMid},
      {sytext:"tdr", count:3, code:WordMid},
      {sytext:"thq", count:3, code:WordMid},
      {sytext:"vh\0", count:3, code:WordMid},
      {sytext:"ryk", count:3, code:WordBeg},
      {sytext:"yh\0", count:3, code:WordMid},
      {sytext:"npr", count:3, code:WordMid},
      {sytext:"btr", count:3, code:WordMid},
      {sytext:"dl\0", count:3, code:WordMid},
      {sytext:"vm\0", count:3, code:WordMid},
      {sytext:"vdg", count:3, code:WordMid},
      {sytext:"lft", count:3, code:WordMid},
      {sytext:"thn", count:3, code:WordMid},
      {sytext:"kh\0", count:3, code:WordMid},
      {sytext:"lfc", count:3, code:WordMid},
      {sytext:"ndt", count:3, code:WordMid},
      {sytext:"yn\0", count:3, code:WordMid},
      {sytext:"trn", count:3, code:WordBeg},
      {sytext:"dt\0", count:3, code:WordMid},
      {sytext:"ryt", count:3, code:WordBeg},
      {sytext:"vb\0", count:3, code:WordMid},
      {sytext:"vtr", count:3, code:WordMid},
      {sytext:"lfk", count:3, code:WordMid},
      {sytext:"ddr", count:3, code:WordMid},
      {sytext:"bw\0", count:4, code:WordMid},
      {sytext:"bt\0", count:4, code:WordMid},
      {sytext:"tht", count:4, code:WordMid},
      {sytext:"kg\0", count:4, code:WordMid},
      {sytext:"rrw", count:4, code:WordMid},
      {sytext:"rrm", count:4, code:WordMid},
      {sytext:"rdw", count:4, code:WordMid},
      {sytext:"ksy", count:4, code:WordMid},
      {sytext:"ndl", count:4, code:WordMid},
      {sytext:"sk\0", count:4, code:WordMid},
      {sytext:"rdn", count:4, code:WordMid},
      {sytext:"rdt", count:4, code:WordMid},
      {sytext:"rdm", count:4, code:WordMid},
      {sytext:"thm", count:4, code:WordMid},
      {sytext:"ntk", count:4, code:WordMid},
      {sytext:"dn\0", count:4, code:WordMid},
      {sytext:"dc\0", count:4, code:WordMid},
      {sytext:"rrh", count:4, code:WordMid},
      {sytext:"rkd", count:4, code:WordMid},
      {sytext:"rdh", count:4, code:WordMid},
      {sytext:"dh\0", count:4, code:WordMid},
      {sytext:"nv\0", count:4, code:WordMid},
      {sytext:"bm\0", count:4, code:WordMid},
      {sytext:"vhr", count:4, code:WordMid},
      {sytext:"lfw", count:4, code:WordMid},
      {sytext:"trs", count:4, code:WordBeg},
      {sytext:"rdb", count:4, code:WordMid},
      {sytext:"rks", count:4, code:WordMid},
      {sytext:"kb\0", count:4, code:WordMid},
      {sytext:"ryb", count:4, code:WordBeg},
      {sytext:"rkt", count:4, code:WordMid},
      {sytext:"kw\0", count:5, code:WordMid},
      {sytext:"vw\0", count:5, code:WordMid},
      {sytext:"vd\0", count:5, code:WordMid},
      {sytext:"trr", count:5, code:WordBeg},
      {sytext:"trk", count:5, code:WordBeg},
      {sytext:"ndc", count:5, code:WordMid},
      {sytext:"xl\0", count:5, code:WordMid},
      {sytext:"nck", count:5, code:WordMid},
      {sytext:"rkw", count:5, code:WordMid},
      {sytext:"kd\0", count:5, code:WordMid},
      {sytext:"rrs", count:5, code:WordMid},
      {sytext:"nsy", count:5, code:WordMid},
      {sytext:"lsy", count:5, code:WordMid},
      {sytext:"bn\0", count:5, code:WordMid},
      {sytext:"nll", count:5, code:WordMid},
      {sytext:"lfh", count:5, code:WordMid},
      {sytext:"thk", count:5, code:WordMid},
      {sytext:"ndd", count:5, code:WordMid},
      {sytext:"ndm", count:5, code:WordMid},
      {sytext:"kt\0", count:5, code:WordMid},
      {sytext:"ktr", count:5, code:WordMid},
      {sytext:"lpr", count:5, code:WordMid},
      {sytext:"trt", count:6, code:WordBeg},
      {sytext:"ryl", count:6, code:WordBeg},
      {sytext:"ndk", count:6, code:WordMid},
      {sytext:"km\0", count:6, code:WordMid},
      {sytext:"ntm", count:6, code:WordMid},
      {sytext:"rkn", count:6, code:WordMid},
      {sytext:"thl", count:6, code:WordMid},
      {sytext:"rkh", count:6, code:WordMid},
      {sytext:"rkm", count:6, code:WordMid},
      {sytext:"bd\0", count:6, code:WordMid},
      {sytext:"tl\0", count:6, code:WordMid},
      {sytext:"bc\0", count:6, code:WordMid},
      {sytext:"rds", count:6, code:WordMid},
      {sytext:"yr\0", count:7, code:WordMid},
      {sytext:"ndg", count:7, code:WordMid},
      {sytext:"rdd", count:7, code:WordMid},
      {sytext:"ng\0", count:7, code:WordMid},
      {sytext:"rrr", count:7, code:WordMid},
      {sytext:"kdr", count:7, code:WordMid},
      {sytext:"ntl", count:7, code:WordMid},
      {sytext:"nw\0", count:7, code:WordMid},
      {sytext:"rkk", count:7, code:WordMid},
      {sytext:"yk\0", count:7, code:WordMid},
      {sytext:"ryr", count:7, code:WordBeg},
      {sytext:"ks\0", count:7, code:WordMid},
      {sytext:"bh\0", count:7, code:WordMid},
      {sytext:"nh\0", count:7, code:WordMid},
      {sytext:"kc\0", count:8, code:WordMid},
      {sytext:"lv\0", count:8, code:WordMid},
      {sytext:"rdl", count:8, code:WordMid},
      {sytext:"kk\0", count:8, code:WordMid},
      {sytext:"vk\0", count:9, code:WordMid},
      {sytext:"rdg", count:9, code:WordMid},
      {sytext:"lll", count:9, code:WordMid},
      {sytext:"lq\0", count:9, code:WordMid},
      {sytext:"vl\0", count:9, code:WordMid},
      {sytext:"rkl", count:9, code:WordMid},
      {sytext:"bl\0", count:9, code:WordMid},
      {sytext:"yl\0", count:9, code:WordMid},
      {sytext:"nb\0", count:10, code:WordMid},
      {sytext:"xr\0", count:10, code:WordMid},
      {sytext:"lck", count:10, code:WordMid},
      {sytext:"kl\0", count:10, code:WordMid},
      {sytext:"ldg", count:10, code:WordMid},
      {sytext:"nc\0", count:11, code:WordMid},
      {sytext:"vn\0", count:11, code:WordMid},
      {sytext:"pr\0", count:12, code:WordMid},
      {sytext:"rdk", count:12, code:WordMid},
      {sytext:"rv\0", count:12, code:WordMid},
      {sytext:"hr\0", count:12, code:WordMid},
      {sytext:"kn\0", count:12, code:WordMid},
      {sytext:"lw\0", count:12, code:WordMid},
      {sytext:"lhr", count:13, code:WordMid},
      {sytext:"rck", count:13, code:WordMid},
      {sytext:"rhr", count:13, code:WordMid},
      {sytext:"lg\0", count:14, code:WordMid},
      {sytext:"sr\0", count:14, code:WordMid},
      {sytext:"lfr", count:14, code:WordMid},
      {sytext:"rh\0", count:14, code:WordMid},
      {sytext:"thr", count:15, code:WordMid},
      {sytext:"br\0", count:15, code:WordMid},
      {sytext:"q\0", count:15, code:WordMid},
      {sytext:"lf\0", count:15, code:WordMid},
      {sytext:"rsy", count:15, code:WordMid},
      {sytext:"ld\0", count:16, code:WordMid},
      {sytext:"x\0", count:16, code:WordMid},
      {sytext:"rs\0", count:16, code:WordMid},
      {sytext:"rpr", count:16, code:WordMid},
      {sytext:"rc\0", count:16, code:WordMid},
      {sytext:"rq\0", count:17, code:WordMid},
      {sytext:"rg\0", count:17, code:WordMid},
      {sytext:"rkr", count:18, code:WordMid},
      {sytext:"ldr", count:18, code:WordMid},
      {sytext:"lh\0", count:18, code:WordMid},
      {sytext:"ns\0", count:19, code:WordMid},
      {sytext:"th\0", count:20, code:WordMid},
      {sytext:"sy\0", count:20, code:WordMid},
      {sytext:"lb\0", count:20, code:WordMid},
      {sytext:"rb\0", count:20, code:WordMid},
      {sytext:"ndr", count:20, code:WordMid},
      {sytext:"ltr", count:20, code:WordMid},
      {sytext:"tr\0", count:20, code:WordBeg},
      {sytext:"kr\0", count:20, code:WordMid},
      {sytext:"lt\0", count:21, code:WordMid},
      {sytext:"rw\0", count:22, code:WordMid},
      {sytext:"ck\0", count:22, code:WordMid},
      {sytext:"ntr", count:22, code:WordMid},
      {sytext:"vr\0", count:22, code:WordMid},
      {sytext:"ls\0", count:22, code:WordMid},
      {sytext:"ry\0", count:23, code:WordBeg},
      {sytext:"nm\0", count:23, code:WordMid},
      {sytext:"nt\0", count:23, code:WordMid},
      {sytext:"rt\0", count:24, code:WordMid},
      {sytext:"nd\0", count:24, code:WordMid},
      {sytext:"lc\0", count:27, code:WordMid},
      {sytext:"rtr", count:29, code:WordMid},
      {sytext:"w\0", count:30, code:WordMid},
      {sytext:"rdr", count:31, code:WordMid},
      {sytext:"lm\0", count:31, code:WordMid},
      {sytext:"nl\0", count:33, code:WordMid},
      {sytext:"dg\0", count:33, code:WordMid},
      {sytext:"rm\0", count:34, code:WordMid},
      {sytext:"ln\0", count:35, code:WordMid},
      {sytext:"nk\0", count:36, code:WordMid},
      {sytext:"rn\0", count:37, code:WordMid},
      {sytext:"ght", count:46, code:WordMid},
      {sytext:"g\0", count:52, code:WordMid},
      {sytext:"d\0", count:52, code:WordEnd},
      {sytext:"rhy", count:52, code:WordBeg},
      {sytext:"rd\0", count:54, code:WordMid},
      {sytext:"h\0", count:54, code:WordMid},
      {sytext:"tyr", count:55, code:WordBeg},
      {sytext:"g\0", count:55, code:WordEnd},
      {sytext:"c\0", count:56, code:WordEnd},
      {sytext:"f\0", count:57, code:WordBeg},
      {sytext:"v\0", count:58, code:WordMid},
      {sytext:"thr", count:59, code:WordBeg},
      {sytext:"cyn", count:62, code:WordBeg},
      {sytext:"zs\0", count:65, code:WordMid},
      {sytext:"sr\0", count:67, code:WordBeg},
      {sytext:"dr\0", count:67, code:WordMid},
      {sytext:"x\0", count:69, code:WordEnd},
      {sytext:"rch", count:70, code:WordMid},
      {sytext:"f\0", count:72, code:WordMid},
      {sytext:"try", count:72, code:WordBeg},
      {sytext:"dry", count:75, code:WordBeg},
      {sytext:"rl\0", count:79, code:WordMid},
      {sytext:"rk\0", count:80, code:WordMid},
      {sytext:"nr\0", count:81, code:WordMid},
      {sytext:"tr\0", count:85, code:WordMid},
      {sytext:"nn\0", count:85, code:WordMid},
      {sytext:"b\0", count:95, code:WordMid},
      {sytext:"g\0", count:99, code:WordBeg},
      {sytext:"z\0", count:110, code:WordBeg},
      {sytext:"d\0", count:110, code:WordBeg},
      {sytext:"kr\0", count:111, code:WordBeg},
      {sytext:"b\0", count:112, code:WordBeg},
      {sytext:"p\0", count:114, code:WordBeg},
      {sytext:"q\0", count:114, code:WordBeg},
      {sytext:"lk\0", count:115, code:WordMid},
      {sytext:"sky", count:116, code:WordBeg},
      {sytext:"y\0", count:116, code:WordEnd},
      {sytext:"sh\0", count:119, code:WordBeg},
      {sytext:"d\0", count:134, code:WordMid},
      {sytext:"lr\0", count:136, code:WordMid},
      {sytext:"c\0", count:149, code:WordMid},
      {sytext:"ll\0", count:155, code:WordMid},
      {sytext:"r\0", count:166, code:WordBeg},
      {sytext:"y\0", count:167, code:WordMid},
      {sytext:"m\0", count:171, code:WordMid},
      {sytext:"h\0", count:172, code:WordBeg},
      {sytext:"k\0", count:173, code:WordBeg},
      {sytext:"r\0", count:174, code:WordEnd},
      {sytext:"w\0", count:181, code:WordBeg},
      {sytext:"c\0", count:187, code:WordBeg},
      {sytext:"f\0", count:204, code:WordEnd},
      {sytext:"rr\0", count:222, code:WordMid},
      {sytext:"t\0", count:224, code:WordEnd},
      {sytext:"s\0", count:226, code:WordMid},
      {sytext:"k\0", count:248, code:WordEnd},
      {sytext:"h\0", count:254, code:WordEnd},
      {sytext:"j\0", count:260, code:WordBeg},
      {sytext:"l\0", count:282, code:WordEnd},
      {sytext:"t\0", count:285, code:WordMid},
      {sytext:"s\0", count:329, code:WordBeg},
      {sytext:"k\0", count:332, code:WordMid},
      {sytext:"l\0", count:476, code:WordBeg},
      {sytext:"t\0", count:492, code:WordBeg},
      {sytext:"n\0", count:535, code:WordBeg},
      {sytext:"l\0", count:536, code:WordMid},
      {sytext:"m\0", count:586, code:WordBeg},
      {sytext:"n\0", count:780, code:WordMid},
      {sytext:"r\0", count:795, code:WordMid},
      {sytext:"s\0", count:903, code:WordEnd},
      {sytext:"n\0", count:1723, code:WordEnd},
    ];
    sylls[0] = swSyllsV.dup;
    sylls[1] = swSyllsC.dup;
    totals = [11979, 16732];
  }

  bool checkCorrectness() () const @safe nothrow @nogc {
    foreach (auto aidx; 0..sylls.length) {
      if (sylls[aidx].length < 1 || sylls[aidx].length > 0xffff) {
        //assert(0);
        return false;
      }
      if (totals[aidx] < 1 || totals[aidx] > 0x00ff_ffffu) {
        //assert(0);
        return false;
      }
      ubyte hasCodes = 0;
      foreach (immutable sy; sylls[aidx]) {
        if (sy.code < 1 || sy.code > 7 || sy.sytext[0] == 0) {
          //assert(0);
          return false;
        }
        hasCodes |= sy.code;
      }
      if (hasCodes != (WordBeg|WordMid|WordEnd)) {
        //assert(0);
        return false;
      }
    }
    return true;
  }

  void clear () @safe nothrow @nogc {
    sylls[0] = sylls[1] = null;
    totals[0] = totals[1] = 0;
  }

  string next (int minsyl=2, int maxsyl=8) const @trusted nothrow
  in {
    assert(minsyl > 0);
    assert(maxsyl > 0);
    assert(minsyl <= maxsyl);
  }
  body {
    auto leng = rand(minsyl, maxsyl);
    uint iscons = rand(0, 1);
    auto res = new char[](leng*3);
    usize respos = 0;
    foreach (auto i; 0..leng) {
      // WARNING: may hang if no termination vowel/consonants are present
      const(Syllable)* sy = null;
      while (sy is null) {
        uint count = rand(1, totals[iscons]);
        //try { writefln("count=%s, total=%s", count, totals[iscons]); } catch (Exception) {}
        foreach (auto idx; 0..sylls[iscons].length) {
          auto cc = sylls[iscons][idx].count;
          if (count > cc) {
            count -= cc;
          } else {
            sy = &sylls[iscons][idx];
            break;
          }
        }
        if (sy is null) assert(0, "internal error");
        ubyte cde = WordMid;
        if (i == 0) cde = WordBeg;
        else if (i == leng-1) cde = WordEnd;
        if ((sy.code&cde) == 0) sy = null;
      }
      // add the syllable
      foreach (immutable char ch; sy.sytext) {
        if (ch == 0) break;
        res[respos++] = ch;
      }
      iscons = 1-iscons;
    }

    assert(respos > 0);
    if (res[0] >= 'a' && res[0] <= 'z') res[0] -= 32;
    return cast(string)res[0..respos];
  }


  // ////////////////////////////////////////////////////////////////////////// //
  private void parseText() (const(char)[] text) {
    enum MaxSyllableLen = 2;
    static assert(MaxSyllableLen > 0 && MaxSyllableLen < Syllable.sytext.length, "invalid max syllable length");

    static usize isvowel() (immutable char ch) {
      return
        ((ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u') ||
         (ch == 'A' || ch == 'E' || ch == 'I' || ch == 'O' || ch == 'U') ? Vowel : Consonant);
    }

    static bool isalpha() (immutable char ch) {
      return
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= 'a' && ch <= 'z');
    }

    while (text.length > 0) {
      // get next word
      usize pos = 0;
      while (pos < text.length && !isalpha(text[pos])) ++pos;
      if (pos >= text.length) break;
      text = text[pos..$];
      pos = 1;
      while (pos < text.length && isalpha(text[pos])) ++pos;
      auto word = text[0..pos];
      text = text[pos..$];
      //writeln("[", word, "]");
      // process word
      Syllable sy;
      sy.code = WordBeg;
      sy.count = 1;
      while (word.length > 0) {
        // get syllable
        auto vowel = isvowel(word[0]);
        pos = 1;
        while (pos < word.length && pos < MaxSyllableLen && isvowel(word[pos]) == vowel) ++pos;
        if (pos == word.length) sy.code |= WordEnd;
        sy.sytext[] = 0; // clear array
        sy.sytext[0..pos] = word[0..pos]; // copy syllable
        foreach (ref ch; sy.sytext) if (ch >= 'A' && ch <= 'Z') ch += 32;
        //{ import std.conv : to; writeln("SYL: [", to!string(sy.sytext.ptr), "]"); }
        // add/fix syllable info
        if (totals[vowel] >= 0x00ff_ffffu) throw new Exception("too many syllables");
        ++totals[vowel];
        bool doAdd = true;
        foreach (ref sx; sylls[vowel]) {
          import core.stdc.string : strcmp;
          if (sy.code == sx.code && strcmp(sy.sytext.ptr, sx.sytext.ptr) == 0) {
            ++sx.count;
            doAdd = false;
            break;
          }
        }
        if (doAdd) sylls[vowel] ~= sy;
        // next syllable
        sy.code = WordMid;
        word = word[pos..$];
      }
    }
  }

  public void loadText() (const(char)[] text) {
    import std.algorithm : sort;
    clear();
    scope(failure) clear();
    parseText(text);
    if (!checkCorrectness()) throw new Exception("incorrect resulting set");
    foreach (auto idx; 0..sylls.length) sort!((ref a, ref b) => a.count < b.count)(sylls[idx]);
  }

  void saveToStream(ST) (auto ref ST fo) if (isWriteableStream!ST) {
    fo.rawWriteExact("SYLLDATA");
    fo.writeNum!ubyte(0); // version
    foreach (auto aidx; 0..sylls.length) {
      fo.writeNum!ushort(cast(ushort)sylls[aidx].length); // count
      foreach (immutable sy; sylls[aidx]) {
        fo.writeNum!ubyte(cast(ubyte)sy.str.length);
        fo.rawWriteExact(sy.str);
        uint cc = sy.count|(sy.code<<24);
        fo.writeNum!uint(cc);
      }
    }
  }

  void loadFromStream(ST) (auto ref ST st) if (isReadableStream!ST) {
    clear();
    scope(failure) clear();
    char[8] sign = void;
    st.rawReadExact(sign);
    if (sign != "SYLLDATA") throw new Exception("invalid signature");
    if (st.readNum!ubyte() != 0) throw new Exception("invalid version");
    foreach (auto aidx; 0..sylls.length) {
      auto len = st.readNum!ushort();
      if (len < 1) throw new Exception("invalid length");
      sylls[aidx].length = len;
      foreach (ref sy; sylls[aidx]) {
        auto slen = st.readNum!ubyte();
        if (slen < 1 || slen > 3) throw new Exception("invalid syllable length");
        sy.sytext[] = 0;
        st.rawReadExact(sy.sytext[0..slen]);
        uint cc = st.readNum!uint();
        sy.code = (cc>>24)&0xff;
        if (sy.code < 1 || sy.code > 7) throw new Exception("invalid syllable code");
        sy.count = cc&0x00ff_ffffu;
        if (sy.count < 1) throw new Exception("invalid syllable count");
        uint ntot = cast(uint)(totals[aidx]+sy.count);
        if (ntot <= totals[aidx] || ntot > 0x00ff_ffffu) throw new Exception("invalid syllable total");
        totals[aidx] = ntot;
      }
    }
    if (!checkCorrectness()) throw new Exception("invalid syllable data");
  }

  string infoStr() () const {
    import std.string;
    return format("%s vowels and %s consonants grouped into {%s, %s} rules", totals[Vowel], totals[Consonant], sylls[Vowel].length, sylls[Consonant].length);
  }

  debug {
    import std.stdio : File;
    void dumpToFile (File fo, string name="table") {
      fo.writeln("  // [", totals[0], ", ", totals[1], "]");
      foreach (auto sidx; 0..sylls.length) {
        fo.writeln("  static immutable Syllable[", sylls[sidx].length, "] ", name, (sidx ? "C" : "V"), " = [");
        foreach (immutable sy; sylls[sidx]) {
          string s = sy.str;
          if (s.length < 3) s ~= `\0`;
          fo.writeln("    {sytext:\"", s, "\", count:", sy.count, ", code:", sy.codeStr, "},");
        }
        fo.writeln("  ];");
      }
    }
  }
}


version(test_namegen)
unittest {
  import iv.writer;
  auto ng = NameGen();
  //ng.loadFromStream(File("names.syl"));
  //ng.loadText(readText("names.txt"));
  //ng.saveToStream(File("names.syl", "w"));
  writeln("==========="); foreach (; 0..10) writeln(ng.next, " ", ng.next);
  ng.setSW();
  writeln("==========="); foreach (; 0..10) writeln(ng.next, " ", ng.next);
  ng.setTotro();
  writeln("==========="); foreach (; 0..10) writeln(ng.next, " ", ng.next);
}
