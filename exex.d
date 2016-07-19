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
// severely outdated exception helpers
module iv.exex /*is aliced*/;


// ////////////////////////////////////////////////////////////////////////// //
mixin template ExceptionCtor() {
  static if (__VERSION__ > 2067) {
    this (string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null) @safe pure nothrow @nogc {
      super(msg, file, line, next);
    }
  } else {
    this (string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null) @safe pure nothrow {
      super(msg, file, line, next);
    }
  }
}


// usage:
//   mixin(MyException!"MyEx");
//   mixin(MyException!("MyEx1", "MyEx"));
enum MyException(string name, string base="Exception") = `class `~name~` : `~base~` { mixin ExceptionCtor; }`;


mixin(MyException!"IVException");
mixin(MyException!("IVNamedExceptionBase", "IVException"));
mixin(MyException!("IVNamedException(string name)", "IVNamedExceptionBase"));


version(test_exex)
unittest {
  import iv.writer;

  void testit (void delegate () dg) {
    try {
      dg();
    } catch (IVNamedException!"Alice" e) {
      writeln("from Alice: ", e.msg);
    } catch (IVNamedException!"Miriel" e) {
      writeln("from Miriel: ", e.msg);
    } catch (IVException e) {
      writeln("from IV: ", e.msg);
    }
  }

  testit({ throw new IVException("msg"); });
  testit({ throw new IVNamedException!"Alice"("Hi, I'm Alice!"); });
  testit({ throw new IVNamedException!"Miriel"("Hi, I'm Miriel!"); });
}
