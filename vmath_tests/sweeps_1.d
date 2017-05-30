import iv.vfs.io;
import iv.vmath;

alias AABB = AABBImpl!vec3;


void main () {
  auto a = AABB(vec3(0, 0, 0), vec3(3, 3, 3));
  auto b = AABB(vec3(5, 5, 5), vec3(8, 8, 8));
  VFloat u0, u1;
  immutable amove = vec3(10, 10, 10);
  immutable bmove = vec3(0.1, 0.1, 0.1);
  vec3 hitnorm;
  if (a.sweep(amove, b, &u0, &hitnorm, &u1)) {
    writeln("COLLIDE; u0=", u0, "; u1=", u1, "; hitnorm=", hitnorm);
    writeln("u0v for a: ", a.min+amove*u0, " : ", a.max+amove*u0);
    writeln("u1v for a: ", a.min+amove*u1, " : ", a.max+amove*u1);
    writeln("        b: ", b.min, " : ", b.max);
  }

  {
    writeln(a.overlapsSphere(vec3(1, 1, 1), 1));
    writeln(a.overlapsSphere(vec3(2.5, 2.5, 2.5), 2));
    writeln(a.overlapsSphere(vec3(3.5, 3.5, 2.5), 2));
    writeln(a.overlapsSphere(vec3(4.5, 3.5, 2.5), 2));
    writeln(a.overlapsSphere(vec3(4.5, 5.5, 2.5), 2));
  }

  {
    writeln(a.overlaps(Sphere!vec3(vec3(1, 1, 1), 1)));
    writeln(a.overlaps(Sphere!vec3(vec3(2.5, 2.5, 2.5), 2)));
    writeln(a.overlaps(Sphere!vec3(vec3(3.5, 3.5, 2.5), 2)));
    writeln(a.overlaps(Sphere!vec3(vec3(4.5, 3.5, 2.5), 2)));
    writeln(a.overlaps(Sphere!vec3(vec3(4.5, 5.5, 2.5), 2)));
  }

  auto s0 = Sphere!vec3(vec3(1, 1, 1), 3);
  auto s1 = Sphere!vec3(vec3(5, 5, 5), 3);

  if (s0.sweep(amove, s1, &u0, &u1)) {
    writeln("COLLIDE; u0=", u0, "; u1=", u1);
    writeln("u0v for s0: ", s0.orig*u0, " : ", s0.orig*u0+s0.radius);
    writeln("u0v for s1: ", s1.orig*u0, " : ", s0.orig*u0+s1.radius);
    writeln("u1v for s0: ", s0.orig*u1, " : ", s0.orig*u1+s0.radius);
    writeln("u1v for s1: ", s1.orig*u1, " : ", s1.orig*u1+s1.radius);
  }

  auto pl = Plane3!VFloat(vec3(0, 0, 1), vec3(0, -1, 1), vec3(0.5, 0.5, 1));
  pl.normalize;
  //pl.normal = vec3(0, 0, 1);
  //pl.w = 1;
  writeln("plane: ", pl.normal, "; w=", pl.w);
  vec3 hitpos;
  if (s1.sweep(pl, vec3(-5, -5, -5), &hitpos, &u0)) {
    writeln("COLLIDE; hitpos=", hitpos, "; u0=", u0);
  }
}
