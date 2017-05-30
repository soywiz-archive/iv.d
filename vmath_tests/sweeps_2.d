import iv.vfs.io;
import iv.vmath;

alias AABB = AABBImpl!vec2;


void main () {
  auto a = AABB(vec2(0, 0), vec2(3, 3));
  auto b = AABB(vec2(5, 5), vec2(8, 8));
  vec2.Float u0, u1;
  immutable amove = vec2(10, 10);
  immutable bmove = vec2(0.1, 0.1);
  vec2 hitnorm;
  if (a.sweep(amove, b, &u0, &hitnorm, &u1)) {
    writeln("COLLIDE; u0=", u0, "; u1=", u1, "; hitnorm=", hitnorm);
    writeln("u0v for a: ", a.min+amove*u0, " : ", a.max+amove*u0);
    writeln("u1v for a: ", a.min+amove*u1, " : ", a.max+amove*u1);
    writeln("        b: ", b.min, " : ", b.max);
  }

  {
    writeln(a.overlapsSphere(vec2(1, 1), 1));
    writeln(a.overlapsSphere(vec2(2.5, 2.5), 2));
    writeln(a.overlapsSphere(vec2(3.5, 3.5), 2));
    writeln(a.overlapsSphere(vec2(4.5, 3.5), 2));
    writeln(a.overlapsSphere(vec2(4.5, 5.5), 2));
  }

  {
    writeln(a.overlaps(Sphere!vec2(vec2(1, 1), 1)));
    writeln(a.overlaps(Sphere!vec2(vec2(2.5, 2.5), 2)));
    writeln(a.overlaps(Sphere!vec2(vec2(3.5, 3.5), 2)));
    writeln(a.overlaps(Sphere!vec2(vec2(4.5, 3.5), 2)));
    writeln(a.overlaps(Sphere!vec2(vec2(4.5, 5.5), 2)));
  }

  auto s0 = Sphere!vec2(vec2(1, 1), 3);
  auto s1 = Sphere!vec2(vec2(7, 7), 3);

  if (s0.sweep(amove, s1, &u0, &u1)) {
    writeln("COLLIDE; u0=", u0, "; u1=", u1);
    writeln("u0v for s0: ", s0.orig*u0, " : ", s0.orig*u0+s0.radius);
    writeln("u0v for s1: ", s1.orig*u0, " : ", s0.orig*u0+s1.radius);
    writeln("u1v for s0: ", s0.orig*u1, " : ", s0.orig*u1+s0.radius);
    writeln("u1v for s1: ", s1.orig*u1, " : ", s1.orig*u1+s1.radius);
  }

  if (a.sweepLine(amove, vec2(7, 7), vec2(14, 0), &u0, &hitnorm, &u1)) {
    writeln("COLLIDE; u0=", u0, "; u1=", u1, "; hitnorm=", hitnorm);
    writeln("u0v for a: ", a.min+amove*u0, " : ", a.max+amove*u0);
    writeln("u1v for a: ", a.min+amove*u1, " : ", a.max+amove*u1);
  }
}
