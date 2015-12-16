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
