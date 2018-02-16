import iv.cmdcon;
import iv.fontconfig;


void main () {
  if (!FcInit()) assert(0, "cannot init fontconfig");
  //scope(exit) FcFini(); // that segfaults, lol. packard, please, kill yourself.

  FcConfig* config = FcInitLoadConfigAndFonts();
  FcPattern* pat = FcPatternCreate();
  FcObjectSet* os = FcObjectSetBuild(FC_FAMILY.ptr, FC_STYLE.ptr, FC_LANG.ptr, FC_FILE.ptr, null);
  FcFontSet* fs = FcFontList(config, pat, os);
  if (fs !is null) {
    conwriteln("Total matching fonts: ", fs.nfont);
    foreach (int i; 0..fs.nfont) {
      FcPattern* font = fs.fonts[i];
      char* file, style, family;
      if (FcPatternGetString(font, FC_FILE, 0, &file) == FcResultMatch &&
          FcPatternGetString(font, FC_FAMILY, 0, &family) == FcResultMatch &&
          FcPatternGetString(font, FC_STYLE, 0, &style) == FcResultMatch)
      {
        conwriteln("file: ", file, " (family: <", family, ">; style: ", style, ")");
      }
    }
    FcFontSetDestroy(fs);
  }
}
