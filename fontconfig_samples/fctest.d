import iv.cmdcon;
import iv.fontconfig;


void main () {
  if (!FcInit()) assert(0, "cannot init fontconfig");
  //scope(exit) FcFini(); // that segfaults, lol. packard, please, kill yourself.
  FcPattern* pat = FcNameParse("Arial:pixelsize=16");
  if (pat is null) assert(0, "cannot parse font name");
  if (!FcConfigSubstitute(null, pat, FcMatchPattern)) assert(0, "cannot find fontconfig substitute");
  FcDefaultSubstitute(pat);
  // find the font
  FcResult result;
  FcPattern* font = FcFontMatch(null, pat, &result);
  if (font !is null) {
    char* file = null;
    if (FcPatternGetString(font, FC_FILE, 0, &file) == FcResultMatch) {
      //import std.string : fromStringz;
      conwriteln("font file: [", file, "]");
    }
    double pixelsize;
    if (FcPatternGetDouble(font, FC_PIXEL_SIZE, 0, &pixelsize) == FcResultMatch) {
      conwriteln("pixel size: ", pixelsize);
    }
    double pointsize;
    if (FcPatternGetDouble(font, FC_SIZE, 0, &pointsize) == FcResultMatch) {
      conwriteln("point size: ", pointsize);
    }
  }
  FcPatternDestroy(pat);
}
