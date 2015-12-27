/*
 * Pixel Graphics Library
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
module iv.sdpy.compat;


// ////////////////////////////////////////////////////////////////////////// //
static if (!is(usize == size_t)) alias usize = size_t;


// ////////////////////////////////////////////////////////////////////////// //
version(GNU) {
  static import gcc.attribute;
  package enum gcc_inline = gcc.attribute.attribute("forceinline");
  package enum gcc_noinline = gcc.attribute.attribute("noinline");
  package enum gcc_flatten = gcc.attribute.attribute("flatten");
} else {
  // hackery for non-gcc compilers
  package enum gcc_inline;
  package enum gcc_noinline;
  package enum gcc_flatten;
}


// ////////////////////////////////////////////////////////////////////////// //
static if (__traits(compiles, () { throw new NamedException!"FLF-WGDParser"("test"); })) {}
else {
mixin template ExceptionCtorMixinTpl() {
  this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) @safe pure nothrow @nogc {
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
