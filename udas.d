/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 1, September 2015
 *
 * Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
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
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 1. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 2. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0 and 1 of this license.
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
 * License: IVPLv1
 */
module iv.udas is aliced;

private alias aliasHelper(alias T) = T;
private alias aliasHelper(T) = T;


template hasUDA(alias T, alias uda) {
  static template Has(alias uda, lst...) {
    static if (lst.length == 0)
      enum Has = false;
    else static if (is(aliasHelper!(lst[0]) == uda) || is(typeof(lst[0]) == uda))
      enum Has = true;
    else
      enum Has = Has!(uda, lst[1..$]);
  }
  enum hasUDA = Has!(uda, __traits(getAttributes, T));
}


template getUDA(alias T, alias uda) {
  template Find(lst...) {
    static if (lst.length == 0)
      static assert(0, "uda '"~uda.stringof~"' not found in type '"~T.stringof~"'");
    else static if (is(aliasHelper!(lst[0]) == uda) || is(typeof(lst[0]) == uda))
      enum Find = lst[0];
    else
      enum Find = Find!(lst[1..$]);
  }
  enum getUDA = Find!(__traits(getAttributes, T));
}


unittest {
  enum testuda0;
  struct testuda1 {}

  struct A {
    @A string bar;
  }

  @testuda1 struct Foo {
    @A("foo")
    int i;
    @testuda0 string s;
  }

  static assert(!hasUDA!(Foo, A));
  static assert(hasUDA!(Foo, testuda1));
  static assert(hasUDA!(Foo.i, A));
  static assert(getUDA!(Foo.i, A).bar == "foo");

  //even uda-inception works
  static assert(hasUDA!(getUDA!(Foo.i, A).bar, A));
  static assert(!hasUDA!(getUDA!(Foo.i, A).bar, testuda1));
}
