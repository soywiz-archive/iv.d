/* Invisible Vector Library
 * ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
// by technosaurus, https://github.com/memononen/nanosvg/issues/87#issue-231530483
module iv.nanovega.simplefont;
private:

import iv.nanovega.nanovega;
import iv.strex;


// ////////////////////////////////////////////////////////////////////////// //
static immutable string[96] simpleChars = [
/* " " */ "m8 0",
/* "!" */ "m4 1v9m0 1v1m4-12",
/*"\"" */ "m3 2v3m2-3v3m3-5",
/* "#" */ "m2 3v8m4-8v8m-5-2h6m-6-4h6m1-5",
/* "$" */ "m2 11a2 3 0 1 0 2-4a2 3 0 1 1 2-4m-2-2v12m4-15",
/* "%" */ "m2 3a1 1 0 1 1 0 .1zm4-2l-4 11m2-2a1 1 0 1 1 0 .1zm2-14",
/* "&" */ "m7 12l-3-6a2 2.5 0 1 1 .1 0a3 3 0 1 0 3 2m1-8",
/* "'" */ "m4 2v3m4-5",
/* "(" */ "m4 12q-3-6 0-11m4-1",
/* ")" */ "m4 12q3-6 0-11m4-1",
/* "*" */ "m1 6h6m-1 4l-4-8m2 0v8m-2 0l4-8m2-2",
/* "+" */ "m1 6h6m-3-3v6m4-9",
/* "," */ "m5 11q1 1-2 3m5-14",
/* "-" */ "m2 6h4m2-6",
/* "." */ "m3 12a.5.5 0 0 0-.1-.1zm5-12",
/* "/" */ "m2 12l4-11m2-1",
/* "0" */ "m2 5.5a2 4 0 1 1 4 0v2a2 4 0 1 1-4 0zm2 0v2m4-8",
/* "1" */ "m3 3l1-1v10m4-12",
/* "2" */ "m2 3a2 5 30 0 1 0 9h5m1-12",
/* "3" */ "m2 2a2 2 0 1 1 3 4m0 0h-1a3 3 0 1 1-3 4m7-10",
/* "4" */ "m2 1v5h4v6-11m2-1",
/* "5" */ "m2 10a2 4 0 1 0 0-4v-5h4m2-1",
/* "6" */ "m3 6a2 3 0 1 1 -1 1l4-6m2-1",
/* "7" */ "m1 1h5l-4 11m6-12",
/* "8" */ "m3.5 6a2 2.5 0 1 1 1 0a2 3 0 1 1 -1 0zm4.5-6",
/* "9" */ "m2 12l4-6a2.5 3 0 1 0 -1 1m3-7",
/* ":" */ "m3 3a.5.5 0 1 0 0-.1zm0 6a.5.5 0 1 0 0-.1zm5-9",
/* ";" */ "m3 3a.5.5 0 1 0 0-.1zm0 6a.5.5 0 1 0 0-.1zq2 0 -1 2m6-11",
/* "<" */ "m6 12l-4-6 4-5m2-1",
/* "=" */ "m2 5h4m-4 2h4m2-7",
/* ">" */ "m2 12l4-6-4-5m6-1",
/* "?" */ "m2 4a2 2 0 1 1 2 2v2m0 3a.5.5 0 1 0-.1 0zm4-11",
/* "@" */ "m5 8a1 1 0 1 1 0 -1a1 2 0 1 0 2-0a3 5 0 1 0 -2 4m3-11",
/* "A" */ "m1 12l3-10l3 10m-1-4h-4m6-8",
/* "B" */ "m2 1h1a2 2 0 1 1 0 5h-1h2a2 2 0 1 1 -2 6zm6-1",
/* "C" */ "m5.5 3a2 5 0 1 0 0 7m2.5-10",
/* "D" */ "m2 1h1a3 5 0 1 1 0 11h-1zm6-1",
/* "E" */ "m6 12h-4v-11h4m-4 5h3m3-6",
/* "F" */ "m2 12v-11h4m-4 5h3m3-6",
/* "G" */ "m6 4a2 5 0 1 0 0 5v-2h-2m4-7",
/* "H" */ "m2 1v11-6h4v6-11m2-1",
/* "I" */ "m2 1h4-2v11h2-4m6-12",
/* "J" */ "m4 1h2v7q0 4-4 4m6-12",
/* "K" */ "m2 1v11-6l5-5-4 4 4 7m1-12",
/* "L" */ "m2 1v11h4m2-12",
/* "M" */ "m1 12v-11l3 6 3-6v11m1-12",
/* "N" */ "m2 12v-11l4 11v-11m2-1",
/* "O" */ "m4 1a2 5.5 0 1 0 .1 0zm4-1",
/* "P" */ "m2 12v-11h1a3 2 0 1 1 0 5h-1m6-6",
/* "Q" */ "m4 1a2 5.5 0 1 0 .1 0zm0 7l3 4m1-12",
/* "R" */ "m2 12v-11h1a3 2 0 1 1 0 5h-1 1l4 6m1-12",
/* "S" */ "m2 10a2 3 0 1 0 2-4a2 2.5 0 1 1 2-4m2-2",
/* "T" */ "m1 1h6-3v11m4-12",
/* "U" */ "m2 1v9a2 2 0 0 0 4 0v-9m2-1",
/* "V" */ "m2 1l2 11 2-11m2-1",
/* "W" */ "m1 1l2 11 1-6 1 6 2-11m1-1",
/* "X" */ "m2 1l4 11m-4 0l4-11m2-1",
/* "Y" */ "m2 1l2 6v5-5l2-6m2-1",
/* "Z" */ "m6 12h-4l4-11h-4m6-1",
/* "[" */ "m5 12h-2v-11h2m3-1",
/*"\\" */ "m2 1l4 11m2-12",
/* "]" */ "m3 12h2v-11h-2m5-1",
/* "^" */ "m2 4l2-2 2 2m2-4",
/* "_" */ "m1 14h6m1-14",
/* "`" */ "m3 2l2 1m3-3",
/* "a" */ "m6 7a2 3 0 1 0 0 3v2-7m2-5",
/* "b" */ "m2 7a2 3 0 1 1 0 3v2-11m6-1",
/* "c" */ "m6 7a2 3 0 1 0 0 3m2-10",
/* "d" */ "m6 7a2 3 0 1 0 0 3v2-11m2-1",
/* "e" */ "m6 10a2 3 0 1 1 0-2h-4m6-8",
/* "f" */ "m2 12v-6h2-2q0-4 4-4m2-2",
/* "g" */ "m6 7a2 3 0 1 0 0 3v-5 8a2 2 0 0 1 -4 0m6-13",
/* "h" */ "m2 1v11-4a2 2 0 1 1 4 0v4m2-12",
/* "i" */ "m4 4v1m0 1v6m4-12",
/* "j" */ "m4 4v1m0 1v5q0 2-2 2m6-13",
/* "k" */ "m2 1v11-3l3 -3-2 2 3 4m2-12",
/* "l" */ "m4 1v11m4-12",
/* "m" */ "m2 6v6-4a1 2 0 1 1 2 0v4-4a1 2 0 1 1 2 0v4m2-12",
/* "n" */ "m2 6v6-4a2 2 0 1 1 4 0v4m2-12",
/* "o" */ "m6 9a2 3 0 1 0 0 .1zm2-9",
/* "p" */ "m2 7a2 3 0 1 1 0 3v5-10m6-5",
/* "q" */ "m6 7a2 3 0 1 0 0 3v5-10m2-5",
/* "r" */ "m2 6v6-4a2 2 0 1 1 4 0m2-8",
/* "s" */ "m2 10a2 2 0 1 0 2-2h-1a2 1 0 0 1 3-2m2-6",
/* "t" */ "m4 4v8-6h2-4m6-6",
/* "u" */ "m2 6v4a2 2 0 1 0 4 0v2-6m2-6",
/* "v" */ "m2 6l2 5 2-5m2-6",
/* "w" */ "m2 6l1 6 1-4 1 4 1-6m2-6",
/* "x" */ "m2 6l4 6m-4 0l4-6m2-6",
/* "y" */ "m2 6l2 4l2-4-4 8m6-14",
/* "z" */ "m2 6h4l-4 6h4m2-12",
/* "{" */ "m5 13a1 6 0 0 1-1-5l-1-1 1-1a1 6 0 0 1 1-5m3-1",
/* "|" */ "m4 13v-12m4-1",
/* "}" */ "m3 13a1 6 0 0 0 1-5l1-1-1-1a1 6 0 0 0 -1-5m5-1",
/* "~" */ "m2 6q1-1 2 0t2 0m2-6",
/* ??? */ "m1 1h6v14h-6zm7-1",
];


// ////////////////////////////////////////////////////////////////////////// //
// returns advance
public float simpleCharHeight (const(float)[] xform=null) nothrow @trusted @nogc {
  float[6] xf = void;
  if (xform.length < 6) xf[] = nvgIdentity[]; else xf[] = xform[0..6];
  float cx = 8, cy = 14;
  nvgTransformPoint(cx, cy, xf[]);
  return cy;
}

public float simpleCharWidth (const(float)[] xform=null) nothrow @trusted @nogc {
  float[6] xf = void;
  if (xform.length < 6) xf[] = nvgIdentity[]; else xf[] = xform[0..6];
  float cx = 8, cy = 14;
  nvgTransformPoint(cx, cy, xf[]);
  return cx;
}

// returns advance
public float drawSimpleChar (NVGContext ctx, float x0, float y0, char ch, const(float)[] xform=null) nothrow @trusted @nogc {
  float[6] xf = void;
  if (xform.length < 6) xf[] = nvgIdentity[]; else xf[] = xform[0..6];

  float firstx = 0, firsty = 0;
  bool firstPoint = true;

  static float nsvg__sqr() (in float x) { pragma(inline, true); return x*x; }
  static float nsvg__vmag() (in float x, float y) { pragma(inline, true); import std.math : sqrt; return sqrt(x*x+y*y); }

  static float nsvg__vecrat (float ux, float uy, float vx, float vy) {
    pragma(inline, true);
    return (ux*vx+uy*vy)/(nsvg__vmag(ux, uy)*nsvg__vmag(vx, vy));
  }

  static float nsvg__vecang (float ux, float uy, float vx, float vy) {
    import std.math : acos;
    float r = nsvg__vecrat(ux, uy, vx, vy);
    if (r < -1.0f) r = -1.0f;
    if (r > 1.0f) r = 1.0f;
    return (ux*vy < uy*vx ? -1.0f : 1.0f)*acos(r);
  }

  static void nsvg__xformPoint (float* dx, float* dy, in float x, in float y, const(float)* t) {
    if (dx !is null) *dx = x*t[0]+y*t[2]+t[4];
    if (dy !is null) *dy = x*t[1]+y*t[3]+t[5];
  }

  static void nsvg__xformVec (float* dx, float* dy, in float x, in float y, const(float)* t) {
    if (dx !is null) *dx = x*t[0]+y*t[2];
    if (dy !is null) *dy = x*t[1]+y*t[3];
  }

  // Ported from canvg (https://code.google.com/p/canvg/)
  void nsvg__pathArcTo (float* cpx, float* cpy, const(float)[] args, bool relative) {
    enum NSVG_PI = 3.14159265358979323846264338327f;
    import std.math : fabsf = abs, cosf = cos, sinf = sin, sqrtf = sqrt;
    assert(args.length >= 7);

    float px = 0, py = 0, ptanx = 0, ptany = 0;
    float[6] t = void;
    float x2 = args[5], y2 = args[6]; // end point

    float rx = fabsf(args[0]); // y radius
    float ry = fabsf(args[1]); // x radius
    immutable float rotx = args[2]/180.0f*NSVG_PI; // x rotation engle
    immutable float fa = (fabsf(args[3]) > 1e-6 ? 1 : 0); // Large arc
    immutable float fs = (fabsf(args[4]) > 1e-6 ? 1 : 0); // Sweep direction
    immutable float x1 = *cpx; // start point
    immutable float y1 = *cpy;
    // end point
    if (relative) {
      x2 += *cpx;
      y2 += *cpy;
    }

    float dx = x1-x2;
    float dy = y1-y2;
    float d = sqrtf(dx*dx+dy*dy);
    if (d < 1e-6f || rx < 1e-6f || ry < 1e-6f) {
      // The arc degenerates to a line
      if (firstPoint) { firstx = x2; firsty = y2; firstPoint = false; }
      float vgx, vgy;
      nvgTransformPoint(&vgx, &vgy, xf[], x2, y2);
      ctx.lineTo(x0+vgx, y0+vgy);
      //nsvg__lineTo(p, x2, y2);
      *cpx = x2;
      *cpy = y2;
      return;
    }

    immutable float sinrx = sinf(rotx);
    immutable float cosrx = cosf(rotx);

    // Convert to center point parameterization.
    // http://www.w3.org/TR/SVG11/implnote.html#ArcImplementationNotes
    // 1) Compute x1', y1'
    immutable float x1p = cosrx*dx/2.0f+sinrx*dy/2.0f;
    immutable float y1p = -sinrx*dx/2.0f+cosrx*dy/2.0f;
    d = nsvg__sqr(x1p)/nsvg__sqr(rx)+nsvg__sqr(y1p)/nsvg__sqr(ry);
    if (d > 1) {
      d = sqrtf(d);
      rx *= d;
      ry *= d;
    }
    // 2) Compute cx', cy'
    float s = 0.0f;
    float sa = nsvg__sqr(rx)*nsvg__sqr(ry)-nsvg__sqr(rx)*nsvg__sqr(y1p)-nsvg__sqr(ry)*nsvg__sqr(x1p);
    immutable float sb = nsvg__sqr(rx)*nsvg__sqr(y1p)+nsvg__sqr(ry)*nsvg__sqr(x1p);
    if (sa < 0.0f) sa = 0.0f;
    if (sb > 0.0f) s = sqrtf(sa/sb);
    if (fa == fs) s = -s;
    immutable float cxp = s*rx*y1p/ry;
    immutable float cyp = s*-ry*x1p/rx;

    // 3) Compute cx,cy from cx',cy'
    immutable float cx = (x1+x2)/2.0f+cosrx*cxp-sinrx*cyp;
    immutable float cy = (y1+y2)/2.0f+sinrx*cxp+cosrx*cyp;

    // 4) Calculate theta1, and delta theta.
    immutable float ux = (x1p-cxp)/rx;
    immutable float uy = (y1p-cyp)/ry;
    immutable float vx = (-x1p-cxp)/rx;
    immutable float vy = (-y1p-cyp)/ry;
    immutable float a1 = nsvg__vecang(1.0f, 0.0f, ux, uy);  // Initial angle
    float da = nsvg__vecang(ux, uy, vx, vy);    // Delta angle

         if (fs == 0 && da > 0) da -= 2*NSVG_PI;
    else if (fs == 1 && da < 0) da += 2*NSVG_PI;

    // Approximate the arc using cubic spline segments.
    t[0] = cosrx; t[1] = sinrx;
    t[2] = -sinrx; t[3] = cosrx;
    t[4] = cx; t[5] = cy;

    // Split arc into max 90 degree segments.
    // The loop assumes an iteration per end point (including start and end), this +1.
    immutable ndivs = cast(int)(fabsf(da)/(NSVG_PI*0.5f)+1.0f);
    immutable float hda = (da/cast(float)ndivs)/2.0f;
    float kappa = fabsf(4.0f/3.0f*(1.0f-cosf(hda))/sinf(hda));
    if (da < 0.0f) kappa = -kappa;

    immutable float ndivsf = cast(float)ndivs;
    foreach (int i; 0..ndivs+1) {
      float x = void, y = void, tanx = void, tany = void;
      immutable float a = a1+da*(i/ndivsf);
      dx = cosf(a);
      dy = sinf(a);
      nsvg__xformPoint(&x, &y, dx*rx, dy*ry, t.ptr); // position
      nsvg__xformVec(&tanx, &tany, -dy*rx*kappa, dx*ry*kappa, t.ptr); // tangent
      if (i > 0) {
        if (firstPoint) { firstx = px+ptanx; firsty = py+ptany; firstPoint = false; }
        float vgx1, vgy1, vgx2, vgy2, vgx3, vgy3;
        nvgTransformPoint(&vgx1, &vgy1, xf[], px+ptanx, py+ptany);
        nvgTransformPoint(&vgx2, &vgy2, xf[], x-tanx, y-tany);
        nvgTransformPoint(&vgx3, &vgy3, xf[], x, y);
        ctx.bezierTo(x0+vgx1, y0+vgy1, x0+vgx2, y0+vgy2, x0+vgx3, y0+vgy3);
        //nsvg__cubicBezTo(p, px+ptanx, py+ptany, x-tanx, y-tany, x, y);
      }
      px = x;
      py = y;
      ptanx = tanx;
      ptany = tany;
    }

    *cpx = x2;
    *cpy = y2;
  }

  if (ch < ' ' || ch >= 0x80) {
    float x = 8, y = 0;
    nvgTransformPoint(x, y, xf[]);
    return x;
  } else {
    string cmd = simpleChars[cast(int)ch-32];
    float[8] args = void;
    float cx = 0, cy = 0;
    float qx1, qy1;
    enum Code { MoveTo, LineTo, HorizTo, VertTo, ArcTo, QuadTo, ShortQuadTo, Close }
    Code code = Code.Close;
    int argc = 0, argn = 0;
    ctx.moveTo(x0, y0);
    while (cmd.length) {
      if (cmd[0] <= ' ' || cmd[0] == ',') { cmd = cmd[1..$]; continue; }
      switch (cmd[0]) {
        case 'm': code = Code.MoveTo; cmd = cmd[1..$]; argc = 2; argn = 0; break;
        case 'l': code = Code.LineTo; cmd = cmd[1..$]; argc = 2; argn = 0; break;
        case 'a': code = Code.ArcTo; cmd = cmd[1..$]; argc = 7; argn = 0; break;
        case 'h': code = Code.HorizTo; cmd = cmd[1..$]; argc = 1; argn = 0; break;
        case 'v': code = Code.VertTo; cmd = cmd[1..$]; argc = 1; argn = 0; break;
        case 'q': code = Code.QuadTo; cmd = cmd[1..$]; argc = 4; argn = 0; break;
        case 't': code = Code.ShortQuadTo; cmd = cmd[1..$]; argc = 2; argn = 0; break;
        case 'z':
          assert(argn == 0);
          float vgx, vgy;
          nvgTransformPoint(&vgx, &vgy, xf[], firstx, firsty);
          //conwriteln("Z: cx=", cx, "; cy=", cy, "; fx=", firstx, "; fy=", firsty);
          ctx.lineTo(x0+vgx, y0+vgy);
          code = Code.Close;
          cmd = cmd[1..$];
          cx = qx1 = firstx;
          cy = qy1 = firsty;
          firstPoint = true;
          break;
        default:
          import std.math : isNaN;
          if (cmd[0].isalpha) assert(0, "unknown command"); //: '"~cmd[0]~"'");
          usize end = 0;
          if (cmd[0] == '+' || cmd[0] == '-') ++end;
          while (end < cmd.length && cmd[end].isdigit) ++end;
          if (end < cmd.length && cmd[end] == '.') {
            ++end;
            while (end < cmd.length && cmd[end].isdigit) ++end;
          }
          auto arg = atof(cmd[0..end]);
          //static assert(is(typeof(arg) == float));
          if (arg.isNaN) assert(0, "ooops"); //: <"~cmd[0..end].idup~"> : "~cmd.idup);
          cmd = cmd[end..$];
          args[argn++] = arg;
          assert(argn <= argc);
          if (argn == argc) {
            argn = 0;
            final switch (code) {
              case Code.MoveTo:
              case Code.LineTo:
                //if (code == Code.MoveTo && ch == '%') { import core.stdc.stdio; printf("$-M: %g %g (cur: %g %g)\n", cast(double)args[0], cast(double)args[1], cx, cy); }
                cx += args[0];
                cy += args[1];
                float vgx, vgy;
                nvgTransformPoint(&vgx, &vgy, xf[], cx, cy);
                if (code == Code.MoveTo) ctx.moveTo(x0+vgx, y0+vgy); else ctx.lineTo(x0+vgx, y0+vgy);
                if (firstPoint || code == Code.MoveTo) { firstx = cx; firsty = cy; firstPoint = false; }
                code = Code.LineTo;
                break;
              case Code.HorizTo:
              case Code.VertTo:
                float vgx, vgy;
                if (code == Code.HorizTo) {
                  nvgTransformPoint(&vgx, &vgy, xf[], cx+args[0], cy);
                  cx += args[0];
                } else {
                  nvgTransformPoint(&vgx, &vgy, xf[], cx, cy+args[0]);
                  cy += args[0];
                }
                ctx.lineTo(x0+vgx, y0+vgy);
                if (firstPoint) { firstx = cx; firsty = cy; firstPoint = false; }
                break;
              case Code.ArcTo:
                nsvg__pathArcTo(&cx, &cy, args[0..argc], true);
                break;
              case Code.QuadTo:
                immutable float x1 = cx;
                immutable float y1 = cy;
                cx += args[0];
                cy += args[1];
                immutable float x2 = x1+args[2];
                immutable float y2 = y1+args[3];
                immutable float cx1 = x1+2.0f/3.0f*(cx-x1);
                immutable float cy1 = y1+2.0f/3.0f*(cy-y1);
                immutable float cx2 = x2+2.0f/3.0f*(cx-x2);
                immutable float cy2 = y2+2.0f/3.0f*(cy-y2);
                qx1 = cx;
                qy1 = cy;
                cx = x2;
                cy = y2;
                args[0] = cx1;
                args[1] = cy1;
                args[2] = cx2;
                args[3] = cy2;
                args[4] = x2;
                args[5] = y2;
                if (firstPoint) { firstx = cx1; firsty = cy1; firstPoint = false; }
                foreach (immutable pidx; 0..3) nvgTransformPoint(args[pidx*2+0], args[pidx*2+1], xf[]);
                ctx.bezierTo(x0+args[0], y0+args[1], x0+args[2], y0+args[3], x0+args[4], y0+args[5]);
                break;
              case Code.ShortQuadTo:
                immutable float x1 = cx;
                immutable float y1 = cy;
                immutable float x2 = cx+args[0];
                immutable float y2 = cy+args[1];

                cx = 2*x1-qx1;
                cy = 2*y1-qy1;

                // Convert to cubix bezier
                immutable float cx1 = x1+2.0f/3.0f*(cx-x1);
                immutable float cy1 = y1+2.0f/3.0f*(cy-y1);
                immutable float cx2 = x2+2.0f/3.0f*(cx-x2);
                immutable float cy2 = y2+2.0f/3.0f*(cy-y2);

                cx = x2;
                cy = y2;

                args[0] = cx1;
                args[1] = cy1;
                args[2] = cx2;
                args[3] = cy2;
                args[4] = x2;
                args[5] = y2;
                if (firstPoint) { firstx = cx1; firsty = cy1; firstPoint = false; }
                foreach (immutable pidx; 0..3) nvgTransformPoint(args[pidx*2+0], args[pidx*2+1], xf[]);
                ctx.bezierTo(x0+args[0], y0+args[1], x0+args[2], y0+args[3], x0+args[4], y0+args[5]);
                break;
              case Code.Close:
                assert(0, "ooops");
            }
            assert(!firstPoint);
          }
          break;
      }
    }
    //conwriteln("cx=", cx, "; cy=", cy);
    version(none) {
      import std.math : abs;
      if (abs(cx-8) > 0.0001) { import core.stdc.stdio; printf("char=%c; cx=%g\n", cast(int)ch, cx); }
      if (abs(cy) > 0.0001) { import core.stdc.stdio; printf("char=%c; cy=%g\n", cast(int)ch, cy); }
    } else {
      cx = 8;
      cy = 0;
    }
    nvgTransformPoint(cx, cy, xf[]);
    //nvg.moveTo(cx, cy);
    return cx;
  }
}
