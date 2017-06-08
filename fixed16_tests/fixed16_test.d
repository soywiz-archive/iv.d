import iv.fixed16;
import iv.vfs.io;
import std.math;

void main () {
  writeln(Fixnum.PI);
  //auto n = Fixed!42;
  Fixnum n = 42;
  Fixnum n1 = 42.2;
  Fixnum nd1 = 0.1;
  writeln(n);
  writeln(n1);
  n += 0.1;
  writeln(n);
  n += nd1;
  writeln(n);

  writeln("sin=", Fixnum.sin(Fixnum(0.3)));
  writeln("dsin=", sin(0.3));
  writeln("cos=", Fixnum.cos(Fixnum(0.5)));
  writeln("dcos=", cos(0.5));
}
