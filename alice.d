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
module iv.alice;

version(aliced) {} else {

// ////////////////////////////////////////////////////////////////////////// //
static if (!is(typeof(usize))) public alias usize = size_t;
static if (!is(typeof(sptrdiff))) public alias sptrdiff = ptrdiff_t;
static if (!is(typeof(ssizediff))) public alias ssizediff = ptrdiff_t;

static if (!is(typeof(ssize))) {
       static if (usize.sizeof == 8) public alias ssize = long; //k8
  else static if (usize.sizeof == 4) public alias ssize = int; //k8
  else static assert(0, "invalid usize size"); //k8
}


// ////////////////////////////////////////////////////////////////////////// //
static if (!is(typeof(NamedExceptionBase))) {
  mixin template ExceptionCtorMixinTpl() {
    this (string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null) @safe pure nothrow @nogc {
      super(msg, file, line, next);
    }
  }

  // usage:
  //   mixin(NewExceptionClass!"MyEx");
  //   mixin(NewExceptionClass!("MyEx1", "MyEx"));
  enum NewExceptionClass(string name, string base="Exception") = `class `~name~` : `~base~` { mixin ExceptionCtorMixinTpl; }`;


  mixin(NewExceptionClass!("NamedExceptionBase", "Exception"));
  mixin(NewExceptionClass!("NamedException(string name)", "NamedExceptionBase"));
}


// ////////////////////////////////////////////////////////////////////////// //
template Imp(string mod) { mixin("import Imp="~mod~";"); }
// usage: auto boo(T)(Imp!"std.datetime".SysTime tm) if (Imp!"std.traits".isCallable!T) { return tm; }


// ////////////////////////////////////////////////////////////////////////// //
}
