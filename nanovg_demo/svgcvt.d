import core.stdc.stdio;
import iv.nanovg.svg;

import arsd.color;
import arsd.png;
import arsd.jpeg;

import iv.vfs;


void writePng (NSVG* svg, string ofname) {
  assert(svg !is null);
  assert(cast(int)svg.width > 0);
  assert(cast(int)svg.height > 0);
  assert(svg.width < 32768);
  assert(svg.height < 32768);

  ubyte[] svgraster;
  auto rst = nsvgCreateRasterizer();
  scope(exit) rst.kill();
  svgraster = new ubyte[](cast(int)svg.width*cast(int)svg.height*4);
  rst.rasterize(svg,
    0, 0, // ofs
    1, // scale
    svgraster.ptr, cast(int)svg.width, cast(int)svg.height);
  auto tc = new TrueColorImage(cast(int)svg.width, cast(int)svg.height, svgraster);
  scope(exit) tc.destroy;
  arsd.png.writePng(ofname, tc);
}


void main (string[] args) {
  NSVG* svg = nsvgParseFromFile(VFile(args.length > 1 ? args[1] : "data/svg/tiger.svg"));
  scope(exit) svg.kill();
  VFile("z00.svb", "w").serialize(svg);

  auto s1 = VFile("z00.svb").nsvgUnserialize;
  scope(exit) s1.kill();
  VFile("z01.svb", "w").serialize(s1);

  svg.writePng("z00.png");
  s1.writePng("z01.png");
}
