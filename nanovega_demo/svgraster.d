//
// Copyright (c) 2013 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//
import core.stdc.stdio;
import iv.nanovega.svg;

import arsd.color;
import arsd.image;


void writePng (NSVG* svg, string ofname) {
  import core.time, std.datetime;
  import std.stdio : writeln;
  assert(svg !is null);
  assert(cast(int)svg.width > 0);
  assert(cast(int)svg.height > 0);
  assert(svg.width < 32768);
  assert(svg.height < 32768);

  ubyte[] svgraster;
  auto rst = nsvgCreateRasterizer();
  scope(exit) rst.kill();
  auto stt = MonoTime.currTime;
  svgraster = new ubyte[](cast(int)svg.width*cast(int)svg.height*4);
  rst.rasterize(svg,
    0, 0, // ofs
    1, // scale
    svgraster.ptr, cast(int)svg.width, cast(int)svg.height);
  auto dur = (MonoTime.currTime-stt).total!"msecs";
  writeln("rasterizing took ", dur, " milliseconds (", dur/1000.0, " seconds)");
  auto tc = new TrueColorImage(cast(int)svg.width, cast(int)svg.height, svgraster);
  scope(exit) tc.destroy;
  arsd.png.writePng(ofname, tc);
}


void main (string[] args) {
  import core.time;

  NSVG* svg;
  scope(exit) svg.kill();
  {
    import std.stdio : writeln;
    import core.time, std.datetime;
    auto stt = MonoTime.currTime;
    svg = nsvgParseFromFile(args.length > 1 ? args[1] : "data/svg/tiger.svg");
    auto dur = (MonoTime.currTime-stt).total!"msecs";
    writeln("loading took ", dur, " milliseconds (", dur/1000.0, " seconds)");
    { import std.stdio; writeln(args.length > 1 ? args[1] : "data/svg/tiger.svg"); }
  }

  svg.writePng("zout.png");
}
