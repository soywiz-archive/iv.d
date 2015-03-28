/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module iv.ascii85 is aliced;

import std.range;
import std.traits;


/// returns input range
auto ascii85Decoder(RI) (auto ref RI src)
if (isInputRange!RI &&
    (isSomeChar!(ElementType!RI)) ||
     is(ElementType!RI : ubyte) ||
     is(ElementType!RI : sbyte))
{
  static struct A85D {
  private:
    static immutable uint[5] pow85 = [85*85*85*85u, 85*85*85u, 85*85u, 85u, 1u];
    uint btuple = 0;
    int count = 0;
    ubyte curCh = 0;
    static if (isInfinite!RI) {
      enum bool empty = false;
    } else {
      bool isEmpty = false;
    }
    RI rng = void;

  public:
    this() (auto ref RI sr) {
      if (sr.empty) {
        static if (!isInfinite!RI) isEmpty = true;
        rng = rng.init;
      } else {
        rng = sr;
        popFront; // populate curCh
      }
    }

    static if (!isInfinite!RI) {
      @property bool empty () const pure nothrow @nogc => isEmpty;
    }
    @property ubyte front () const pure nothrow @nogc => curCh;

    static if (isForwardRange!RI) {
      @property auto save() () {
        auto res = this;
        if (!empty) res.rng = rng.save();
        return res;
      }
    }

    // template to allow autodeducing attributes
    void popFront() () {
      static if (!isInfinite!RI) {
        if (isEmpty) { curCh = 0; return; }
      }
      if (count == 0) {
        // read more chars
        btuple = 0;
        while (count != 5) {
          if (rng.empty) break;
          uint b = cast(uint)rng.front;
          rng.popFront;
          if (count == 0 && b == 'z') {
            // 4 zeroes
            count = 5;
          } else if (count == 0 && b == 'y') {
            // 4 spaces
            count = 5;
            btuple = 0x20202020;
          } else if (b >= '!' && b <= 'u') {
            btuple += (b-'!')*pow85[count++];
          }
        }
        if (count < 2) {
          static if (isInfinite!RI) {
            assert(0);
          } else {
            isEmpty = true;
            curCh = 0;
            return;
          }
        }
        if (count != 5) {
          // we have some bytes ready
          btuple += pow85[--count];
        } else {
          // we have 4 bytes ready
          count = 4;
        }
      }
      assert(count > 0);
      curCh = (btuple>>24)&0xff;
      btuple <<= 8;
      --count;
    }
  }
  return A85D(src);
}


version(test_ascii85)
unittest {
  import std.array;
  import std.utf : byChar;
  {
    immutable e = `:Ms_p+EVgG/0IE&ARo=s-Z^D?Df'3+B-:f)EZfXGFT`;
    immutable s = cast(string)array(ascii85Decoder(e.byChar));
    //import iv.writer; writeln(s);
    assert(s == "One, two, Freddy's coming for you");
  }
  {
    immutable e =
      ":Ms_p+EVgG/0IE&ARo=s-Z^D?Df'3+B-:f)EZfXGFU\n"~
      "D)]Eb/f5+D,P7E\\&>\"ATW$*EZf1:@r!34Dfp(CA8cC\n"~
      ",$:\\`QALnsFBm;0OB6%Ei+CQC&Eckl+AncKB$<(MZA\n"~
      "Ss%AASGdjF=\\P)Df0H$+EMX5Gp%6K+DbJ.AM+<bBl7\n"~
      "K5+EV14/0I]!G%G\\:F)5E!E$/S%@;0U3/hRJ";
    immutable s = cast(string)array(ascii85Decoder(e.byChar));
    //import iv.writer; writeln(s);
    assert(s ==
      "One, two, Freddy's coming for you\n"~
      "Three, four, Better lock your door\n"~
      "Five, six, grab a crucifix.\n"~
      "Seven, eight, Gonna stay up late.\n"~
      "Nine, ten, Never sleep again...\n");
  }
}


/// returns input range
auto ascii85Encoder(RI) (auto ref RI src)
if (isInputRange!RI &&
    (is(ElementType!RI : char) ||
     is(ElementType!RI : ubyte) ||
     is(ElementType!RI : sbyte)))
{
  static struct A85E {
  private:
    usize bpos = 0;
    int count = 0;
    ubyte[5] buf;
    static if (isInfinite!RI) {
      enum bool empty = false;
    } else {
      bool isEmpty = false;
    }
    RI rng = void;

  public:
    this() (auto ref RI sr) {
      if (sr.empty) {
        static if (!isInfinite!RI) isEmpty = true;
        rng = rng.init;
      } else {
        rng = sr;
        popFront; // populate curCh
      }
    }

    static if (!isInfinite!RI) {
      @property bool empty () const pure nothrow @nogc => isEmpty;
      @property char front () const pure nothrow @nogc => (isEmpty ? 0 : cast(char)buf[bpos]);
    } else {
      @property char front () const pure nothrow @nogc => cast(char)buf[bpos];
    }

    static if (isForwardRange!RI) {
      @property auto save() () {
        auto res = this;
        if (!empty) res.rng = rng.save();
        return res;
      }
    }

    // template to allow autodeducing attributes
    void popFront() () {
      static if (!isInfinite!RI) {
        if (isEmpty) return;
      }
      if (count > 0) {
        --bpos;
        --count;
        return;
      }
      // read at most 4 bytes and encode 'em
      count = 0;
      uint btuple = 0;
      while (count < 4) {
        if (rng.empty) break;
        auto b = cast(uint)rng.front;
        rng.popFront;
        btuple |= b<<((3-count)*8);
        ++count;
      }
      if (count < 1) {
        static if (isInfinite!RI) {
          assert(0);
        } else {
          isEmpty = true;
          return;
        }
      }
      if (count == 4 && btuple == 0) {
        // special case
        bpos = 1;
        buf[0] = 'z';
      } else {
        // encode tuple
        for (bpos = 0; bpos < 5; ++bpos) {
          buf[bpos] = btuple%85+'!';
          btuple /= 85;
        }
        --bpos; // current char
      }
    }
  }
  return A85E(src);
}


version(test_ascii85)
unittest {
  import std.array;
  import std.utf : byChar;
  {
    immutable s = "One, two, Freddy's coming for you";
    immutable e = cast(string)array(ascii85Encoder(s.byChar));
    assert(e == `:Ms_p+EVgG/0IE&ARo=s-Z^D?Df'3+B-:f)EZfXGFT`);
    //import iv.writer; writeln(e);
  }
  {
    immutable s =
      "One, two, Freddy's coming for you\n"~
      "Three, four, Better lock your door\n"~
      "Five, six, grab a crucifix.\n"~
      "Seven, eight, Gonna stay up late.\n"~
      "Nine, ten, Never sleep again...\n";
    immutable e = cast(string)array(ascii85Encoder(s.byChar));
    assert(e ==
      ":Ms_p+EVgG/0IE&ARo=s-Z^D?Df'3+B-:f)EZfXGFU"~
      "D)]Eb/f5+D,P7E\\&>\"ATW$*EZf1:@r!34Dfp(CA8cC"~
      ",$:\\`QALnsFBm;0OB6%Ei+CQC&Eckl+AncKB$<(MZA"~
      "Ss%AASGdjF=\\P)Df0H$+EMX5Gp%6K+DbJ.AM+<bBl7"~
      "K5+EV14/0I]!G%G\\:F)5E!E$/S%@;0U3/hRJ");
    //import iv.writer; writeln(e);
  }
}
