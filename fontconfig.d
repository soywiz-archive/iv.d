/*
 * fontconfig/fontconfig/fontconfig.h
 *
 * Copyright © 2001 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of the author(s) not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  The authors make no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * THE AUTHOR(S) DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */
module iv.fontconfig is aliced;
pragma(lib, "fontconfig");
pragma(lib, "freetype");

import core.stdc.stdarg : va_list;
import core.sys.posix.sys.stat;

import iv.freetype;


extern(C) nothrow @nogc:

alias FcChar8 = char;
alias FcChar16 = wchar;
alias FcChar32 = dchar;
alias FcBool = int;

/*
 * Current Fontconfig version number.  This same number
 * must appear in the fontconfig configure.in file. Yes,
 * it'a a pain to synchronize version numbers like this.
 */

enum FC_MAJOR = 2;
enum FC_MINOR = 11;
enum FC_REVISION = 1;

enum FC_VERSION = ((FC_MAJOR*10000)+(FC_MINOR*100)+(FC_REVISION));

/*
 * Current font cache file format version
 * This is appended to the cache files so that multiple
 * versions of the library will peacefully coexist
 *
 * Change this value whenever the disk format for the cache file
 * changes in any non-compatible way.  Try to avoid such changes as
 * it means multiple copies of the font information.
 */

enum FC_CACHE_VERSION = "4";

enum FcTrue = 1;
enum FcFalse = 0;

enum FC_FAMILY = "family"; /* String */
enum FC_STYLE = "style"; /* String */
enum FC_SLANT = "slant"; /* Int */
enum FC_WEIGHT = "weight"; /* Int */
enum FC_SIZE = "size"; /* Double */
enum FC_ASPECT = "aspect"; /* Double */
enum FC_PIXEL_SIZE = "pixelsize"; /* Double */
enum FC_SPACING = "spacing"; /* Int */
enum FC_FOUNDRY = "foundry"; /* String */
enum FC_ANTIALIAS = "antialias"; /* Bool (depends) */
enum FC_HINTING = "hinting"; /* Bool (true) */
enum FC_HINT_STYLE = "hintstyle"; /* Int */
enum FC_VERTICAL_LAYOUT = "verticallayout"; /* Bool (false) */
enum FC_AUTOHINT = "autohint"; /* Bool (false) */
/* FC_GLOBAL_ADVANCE is deprecated. this is simply ignored on freetype 2.4.5 or later */
enum FC_GLOBAL_ADVANCE = "globaladvance"; /* Bool (true) */
enum FC_WIDTH = "width"; /* Int */
enum FC_FILE = "file"; /* String */
enum FC_INDEX = "index"; /* Int */
enum FC_FT_FACE = "ftface"; /* FT_Face */
enum FC_RASTERIZER = "rasterizer"; /* String (deprecated) */
enum FC_OUTLINE = "outline"; /* Bool */
enum FC_SCALABLE = "scalable"; /* Bool */
enum FC_SCALE = "scale"; /* double */
enum FC_DPI = "dpi"; /* double */
enum FC_RGBA = "rgba"; /* Int */
enum FC_MINSPACE = "minspace"; /* Bool use minimum line spacing */
enum FC_SOURCE = "source"; /* String (deprecated) */
enum FC_CHARSET = "charset"; /* CharSet */
enum FC_LANG = "lang"; /* String RFC 3066 langs */
enum FC_FONTVERSION = "fontversion"; /* Int from 'head' table */
enum FC_FULLNAME = "fullname"; /* String */
enum FC_FAMILYLANG = "familylang"; /* String RFC 3066 langs */
enum FC_STYLELANG = "stylelang"; /* String RFC 3066 langs */
enum FC_FULLNAMELANG = "fullnamelang"; /* String RFC 3066 langs */
enum FC_CAPABILITY = "capability"; /* String */
enum FC_FONTFORMAT = "fontformat"; /* String */
enum FC_EMBOLDEN = "embolden"; /* Bool - true if emboldening needed*/
enum FC_EMBEDDED_BITMAP = "embeddedbitmap"; /* Bool - true to enable embedded bitmaps */
enum FC_DECORATIVE = "decorative"; /* Bool - true if style is a decorative variant */
enum FC_LCD_FILTER = "lcdfilter"; /* Int */
enum FC_FONT_FEATURES = "fontfeatures"; /* String */
enum FC_NAMELANG = "namelang"; /* String RFC 3866 langs */
enum FC_PRGNAME = "prgname"; /* String */
enum FC_HASH = "hash"; /* String */
enum FC_POSTSCRIPT_NAME = "postscriptname"; /* String */

enum FC_CACHE_SUFFIX = ".cache-"~FC_CACHE_VERSION;
enum FC_DIR_CACHE_FILE = "fonts.cache-"~FC_CACHE_VERSION;
enum FC_USER_CACHE_FILE = ".fonts.cache-"~FC_CACHE_VERSION;

/* Adjust outline rasterizer */
enum FC_CHAR_WIDTH = "charwidth"; /* Int */
enum FC_CHAR_HEIGHT = "charheight"; /* Int */
enum FC_MATRIX = "matrix"; /* FcMatrix */

enum FC_WEIGHT_THIN = 0;
enum FC_WEIGHT_EXTRALIGHT = 40;
enum FC_WEIGHT_ULTRALIGHT = FC_WEIGHT_EXTRALIGHT;
enum FC_WEIGHT_LIGHT = 50;
enum FC_WEIGHT_BOOK = 75;
enum FC_WEIGHT_REGULAR = 80;
enum FC_WEIGHT_NORMAL = FC_WEIGHT_REGULAR;
enum FC_WEIGHT_MEDIUM = 100;
enum FC_WEIGHT_DEMIBOLD = 180;
enum FC_WEIGHT_SEMIBOLD = FC_WEIGHT_DEMIBOLD;
enum FC_WEIGHT_BOLD = 200;
enum FC_WEIGHT_EXTRABOLD = 205;
enum FC_WEIGHT_ULTRABOLD = FC_WEIGHT_EXTRABOLD;
enum FC_WEIGHT_BLACK = 210;
enum FC_WEIGHT_HEAVY = FC_WEIGHT_BLACK;
enum FC_WEIGHT_EXTRABLACK = 215;
enum FC_WEIGHT_ULTRABLACK = FC_WEIGHT_EXTRABLACK;

enum FC_SLANT_ROMAN = 0;
enum FC_SLANT_ITALIC = 100;
enum FC_SLANT_OBLIQUE = 110;

enum FC_WIDTH_ULTRACONDENSED = 50;
enum FC_WIDTH_EXTRACONDENSED = 63;
enum FC_WIDTH_CONDENSED = 75;
enum FC_WIDTH_SEMICONDENSED = 87;
enum FC_WIDTH_NORMAL = 100;
enum FC_WIDTH_SEMIEXPANDED = 113;
enum FC_WIDTH_EXPANDED = 125;
enum FC_WIDTH_EXTRAEXPANDED = 150;
enum FC_WIDTH_ULTRAEXPANDED = 200;

enum FC_PROPORTIONAL = 0;
enum FC_DUAL = 90;
enum FC_MONO = 100;
enum FC_CHARCELL = 110;

/* sub-pixel order */
enum FC_RGBA_UNKNOWN = 0;
enum FC_RGBA_RGB = 1;
enum FC_RGBA_BGR = 2;
enum FC_RGBA_VRGB = 3;
enum FC_RGBA_VBGR = 4;
enum FC_RGBA_NONE = 5;

/* hinting style */
enum FC_HINT_NONE = 0;
enum FC_HINT_SLIGHT = 1;
enum FC_HINT_MEDIUM = 2;
enum FC_HINT_FULL = 3;

/* LCD filter */
enum FC_LCD_NONE = 0;
enum FC_LCD_DEFAULT = 1;
enum FC_LCD_LIGHT = 2;
enum FC_LCD_LEGACY = 3;

alias FcType = int;
enum : FcType{
  FcTypeUnknown = -1,
  FcTypeVoid,
  FcTypeInteger,
  FcTypeDouble,
  FcTypeString,
  FcTypeBool,
  FcTypeMatrix,
  FcTypeCharSet,
  FcTypeFTFace,
  FcTypeLangSet
}

struct FcMatrix {
  double xx=1, xy=0, yx=0, yy=1;
}
//#define FcMatrixInit(m) ((m)->xx = (m)->yy = 1, (m)->xy = (m)->yx = 0)

/*
 * A data structure to represent the available glyphs in a font.
 * This is represented as a sparse boolean btree.
 */
struct FcCharSet;

struct FcObjectType {
  const(char)* object;
  FcType type;
}

struct FcConstant {
  const(FcChar8)* name;
  const(char)* object;
  int value;
}

alias FcResult = int;
enum : FcResult {
  FcResultMatch,
  FcResultNoMatch,
  FcResultTypeMismatch,
  FcResultNoId,
  FcResultOutOfMemory
}

struct FcPattern;

struct FcLangSet;

struct FcValue {
  FcType  type;
  union U {
    const(FcChar8)* s;
    int i;
    FcBool b;
    double d;
    const(FcMatrix)* m;
    const(FcCharSet)* c;
    void* f;
    const(FcLangSet)* l;
  }
  U u;
}

struct FcFontSet {
  int nfont;
  int sfont;
  FcPattern** fonts;
}

struct FcObjectSet {
  int nobject;
  int sobject;
  const(char)** objects;
}

alias FcMatchKind = int;
enum : FcMatchKind {
  FcMatchPattern,
  FcMatchFont,
  FcMatchScan
}

alias FcLangResult = int;
enum : FcLangResult {
  FcLangEqual = 0,
  FcLangDifferentCountry = 1,
  FcLangDifferentTerritory = 1,
  FcLangDifferentLang = 2
}

alias FcSetName = int;
enum : FcSetName {
  FcSetSystem = 0,
  FcSetApplication = 1
}

struct FcAtomic;

alias FcEndian = int;
enum : FcEndian { FcEndianBig, FcEndianLittle }

struct FcConfig;
struct FcFileCache;
struct FcBlanks;
struct FcStrList;
struct FcStrSet;
struct FcCache;


/* fcblanks.c */
/*FcPublic*/ FcBlanks* FcBlanksCreate ();
/*FcPublic*/ void FcBlanksDestroy (FcBlanks* b);
/*FcPublic*/ FcBool FcBlanksAdd (FcBlanks* b, FcChar32 ucs4);
/*FcPublic*/ FcBool FcBlanksIsMember (FcBlanks* b, FcChar32 ucs4);

/* fccache.c */
/*FcPublic*/ const(FcChar8)* FcCacheDir(const(FcCache)* c);
/*FcPublic*/ FcFontSet* FcCacheCopySet(const(FcCache)* c);
/*FcPublic*/ const(FcChar8)* FcCacheSubdir (const(FcCache)* c, int i);
/*FcPublic*/ int FcCacheNumSubdir (const(FcCache)* c);
/*FcPublic*/ int FcCacheNumFont (const(FcCache)* c);
/*FcPublic*/ FcBool FcDirCacheUnlink (const(FcChar8)* dir, FcConfig* config);
/*FcPublic*/ FcBool FcDirCacheValid (const(FcChar8)* cache_file);
/*FcPublic*/ FcBool FcDirCacheClean (const(FcChar8)* cache_dir, FcBool verbose);
/*FcPublic*/ void FcCacheCreateTagFile (const(FcConfig)* config);

/* fccfg.c */
/*FcPublic*/ FcChar8* FcConfigHome ();
/*FcPublic*/ FcBool FcConfigEnableHome (FcBool enable);
/*FcPublic*/ FcChar8* FcConfigFilename (const(FcChar8)* url);
/*FcPublic*/ FcConfig* FcConfigCreate ();
/*FcPublic*/ FcConfig* FcConfigReference (FcConfig* config);
/*FcPublic*/ void FcConfigDestroy (FcConfig* config);
/*FcPublic*/ FcBool FcConfigSetCurrent (FcConfig* config);
/*FcPublic*/ FcConfig* FcConfigGetCurrent ();
/*FcPublic*/ FcBool FcConfigUptoDate (FcConfig* config);
/*FcPublic*/ FcBool FcConfigBuildFonts (FcConfig* config);
/*FcPublic*/ FcStrList* FcConfigGetFontDirs (FcConfig* config);
/*FcPublic*/ FcStrList* FcConfigGetConfigDirs (FcConfig* config);
/*FcPublic*/ FcStrList* FcConfigGetConfigFiles (FcConfig* config);
/*FcPublic*/ FcChar8* FcConfigGetCache (FcConfig* config);
/*FcPublic*/ FcBlanks* FcConfigGetBlanks (FcConfig* config);
/*FcPublic*/ FcStrList* FcConfigGetCacheDirs (const(FcConfig)* config);
/*FcPublic*/ int FcConfigGetRescanInterval (FcConfig* config);
/*FcPublic*/ FcBool FcConfigSetRescanInterval (FcConfig* config, int rescanInterval);
/*FcPublic*/ FcFontSet* FcConfigGetFonts (FcConfig* config, FcSetName set);
/*FcPublic*/ FcBool FcConfigAppFontAddFile (FcConfig* config, const(FcChar8)* file);
/*FcPublic*/ FcBool FcConfigAppFontAddDir (FcConfig* config, const(FcChar8)* dir);
/*FcPublic*/ void FcConfigAppFontClear (FcConfig* config);
/*FcPublic*/ FcBool FcConfigSubstituteWithPat (FcConfig* config, FcPattern* p, FcPattern* p_pat, FcMatchKind kind);
/*FcPublic*/ FcBool FcConfigSubstitute (FcConfig* config, FcPattern* p, FcMatchKind kind);
/*FcPublic*/ const(FcChar8)* FcConfigGetSysRoot (const(FcConfig)* config);
/*FcPublic*/ void FcConfigSetSysRoot (FcConfig* config, const(FcChar8)* sysroot);

/* fccharset.c */
/*FcPublic*/ FcCharSet* FcCharSetCreate ();

/* deprecated alias for FcCharSetCreate */
/*FcPublic*/ FcCharSet* FcCharSetNew ();
/*FcPublic*/ void FcCharSetDestroy (FcCharSet* fcs);
/*FcPublic*/ FcBool FcCharSetAddChar (FcCharSet* fcs, FcChar32 ucs4);
/*FcPublic*/ FcBool FcCharSetDelChar (FcCharSet* fcs, FcChar32 ucs4);
/*FcPublic*/ FcCharSet* FcCharSetCopy (FcCharSet* src);
/*FcPublic*/ FcBool FcCharSetEqual (const(FcCharSet)* a, const(FcCharSet)* b);
/*FcPublic*/ FcCharSet* FcCharSetIntersect (const(FcCharSet)* a, const(FcCharSet)* b);
/*FcPublic*/ FcCharSet* FcCharSetUnion (const(FcCharSet)* a, const(FcCharSet)* b);
/*FcPublic*/ FcCharSet* FcCharSetSubtract (const(FcCharSet)* a, const(FcCharSet)* b);
/*FcPublic*/ FcBool FcCharSetMerge (FcCharSet* a, const(FcCharSet)* b, FcBool* changed);
/*FcPublic*/ FcBool FcCharSetHasChar (const(FcCharSet)* fcs, FcChar32 ucs4);
/*FcPublic*/ FcChar32 FcCharSetCount (const(FcCharSet)* a);
/*FcPublic*/ FcChar32 FcCharSetIntersectCount (const(FcCharSet)* a, const(FcCharSet)* b);
/*FcPublic*/ FcChar32 FcCharSetSubtractCount (const(FcCharSet)* a, const(FcCharSet)* b);
/*FcPublic*/ FcBool FcCharSetIsSubset (const(FcCharSet)* a, const(FcCharSet)* b);

enum FC_CHARSET_MAP_SIZE = (256/32);
enum FC_CHARSET_DONE = (cast(FcChar32)-1);

/*FcPublic*/ FcChar32 FcCharSetFirstPage (const(FcCharSet)* a, FcChar32*/*[FC_CHARSET_MAP_SIZE]*/ map, FcChar32 *next);
/*FcPublic*/ FcChar32 FcCharSetNextPage (const(FcCharSet)* a, FcChar32*/*[FC_CHARSET_MAP_SIZE]*/ map, FcChar32* next);

/*
 * old coverage API, rather hard to use correctly
 */
/*FcPublic*/ FcChar32 FcCharSetCoverage (const(FcCharSet)* a, FcChar32 page, FcChar32* result);

/* fcdbg.c */
/*FcPublic*/ void FcValuePrint (const FcValue v);
/*FcPublic*/ void FcPatternPrint (const(FcPattern)* p);
/*FcPublic*/ void FcFontSetPrint (const(FcFontSet)* s);

/* fcdefault.c */
/*FcPublic*/ FcStrSet* FcGetDefaultLangs ();
/*FcPublic*/ void FcDefaultSubstitute (FcPattern* pattern);

/* fcdir.c */
/*FcPublic*/ FcBool FcFileIsDir (const(FcChar8)* file);
/*FcPublic*/ FcBool FcFileScan (FcFontSet* set, FcStrSet* dirs, FcFileCache* cache, FcBlanks* blanks, const(FcChar8)* file, FcBool force);
/*FcPublic*/ FcBool FcDirScan (FcFontSet* set, FcStrSet* dirs, FcFileCache* cache, FcBlanks* blanks, const(FcChar8)* dir, FcBool force);
/*FcPublic*/ FcBool FcDirSave (FcFontSet* set, FcStrSet* dirs, const(FcChar8)* dir);
/*FcPublic*/ FcCache* FcDirCacheLoad (const(FcChar8)* dir, FcConfig* config, FcChar8** cache_file);
/*FcPublic*/ FcCache* FcDirCacheRescan (const(FcChar8)* dir, FcConfig* config);
/*FcPublic*/ FcCache* FcDirCacheRead (const(FcChar8)* dir, FcBool force, FcConfig* config);
/*FcPublic*/ FcCache* FcDirCacheLoadFile (const(FcChar8)* cache_file, stat_t* file_stat);
/*FcPublic*/ void FcDirCacheUnload (FcCache* cache);

/* fcfreetype.c */
/*FcPublic*/ FcPattern* FcFreeTypeQuery (const(FcChar8)* file, int id, FcBlanks* blanks, int* count);

/* fcfs.c */
/*FcPublic*/ FcFontSet* FcFontSetCreate ();
/*FcPublic*/ void FcFontSetDestroy (FcFontSet* s);
/*FcPublic*/ FcBool FcFontSetAdd (FcFontSet* s, FcPattern* font);

/* fcinit.c */
/*FcPublic*/ FcConfig* FcInitLoadConfig ();
/*FcPublic*/ FcConfig* FcInitLoadConfigAndFonts ();
/*FcPublic*/ FcBool FcInit ();
/*FcPublic*/ void FcFini ();
/*FcPublic*/ int FcGetVersion ();
/*FcPublic*/ FcBool FcInitReinitialize ();
/*FcPublic*/ FcBool FcInitBringUptoDate ();

/* fclang.c */
/*FcPublic*/ FcStrSet* FcGetLangs ();
/*FcPublic*/ FcChar8* FcLangNormalize (const(FcChar8)* lang);
/*FcPublic*/ const(FcCharSet)* FcLangGetCharSet (const(FcChar8)* lang);
/*FcPublic*/ FcLangSet* FcLangSetCreate ();
/*FcPublic*/ void FcLangSetDestroy (FcLangSet* ls);
/*FcPublic*/ FcLangSet* FcLangSetCopy (const(FcLangSet)* ls);
/*FcPublic*/ FcBool FcLangSetAdd (FcLangSet* ls, const(FcChar8)* lang);
/*FcPublic*/ FcBool FcLangSetDel (FcLangSet* ls, const(FcChar8)* lang);
/*FcPublic*/ FcLangResult FcLangSetHasLang (const(FcLangSet)* ls, const(FcChar8)* lang);
/*FcPublic*/ FcLangResult FcLangSetCompare (const(FcLangSet)* lsa, const(FcLangSet)* lsb);
/*FcPublic*/ FcBool FcLangSetContains (const(FcLangSet)* lsa, const(FcLangSet)* lsb);
/*FcPublic*/ FcBool FcLangSetEqual (const(FcLangSet)* lsa, const(FcLangSet)* lsb);
/*FcPublic*/ FcChar32 FcLangSetHash (const(FcLangSet)* ls);
/*FcPublic*/ FcStrSet* FcLangSetGetLangs (const(FcLangSet)* ls);
/*FcPublic*/ FcLangSet* FcLangSetUnion (const(FcLangSet)* a, const(FcLangSet)* b);
/*FcPublic*/ FcLangSet* FcLangSetSubtract (const(FcLangSet)* a, const(FcLangSet)* b);

/* fclist.c */
/*FcPublic*/ FcObjectSet* FcObjectSetCreate ();
/*FcPublic*/ FcBool FcObjectSetAdd (FcObjectSet* os, const(char)* object);
/*FcPublic*/ void FcObjectSetDestroy (FcObjectSet* os);
/*FcPublic*/ FcObjectSet* FcObjectSetVaBuild (const(char)* first, va_list va);
/*FcPublic*/ FcObjectSet* FcObjectSetBuild (const(char)* first, ...) /*FC_ATTRIBUTE_SENTINEL(0)*/;
/*FcPublic*/ FcFontSet* FcFontSetList (FcConfig* config, FcFontSet** sets, int nsets, FcPattern* p, FcObjectSet* os);
/*FcPublic*/ FcFontSet* FcFontList (FcConfig* config, FcPattern* p, FcObjectSet* os);

/* fcatomic.c */
/*FcPublic*/ FcAtomic* FcAtomicCreate (const(FcChar8)* file);
/*FcPublic*/ FcBool FcAtomicLock (FcAtomic* atomic);
/*FcPublic*/ FcChar8* FcAtomicNewFile (FcAtomic* atomic);
/*FcPublic*/ FcChar8* FcAtomicOrigFile (FcAtomic* atomic);
/*FcPublic*/ FcBool FcAtomicReplaceOrig (FcAtomic* atomic);
/*FcPublic*/ void FcAtomicDeleteNew (FcAtomic* atomic);
/*FcPublic*/ void FcAtomicUnlock (FcAtomic* atomic);
/*FcPublic*/ void FcAtomicDestroy (FcAtomic* atomic);

/* fcmatch.c */
/*FcPublic*/ FcPattern* FcFontSetMatch (FcConfig* config, FcFontSet** sets, int nsets, FcPattern* p, FcResult* result);
/*FcPublic*/ FcPattern* FcFontMatch (FcConfig* config, FcPattern* p, FcResult* result);
/*FcPublic*/ FcPattern* FcFontRenderPrepare (FcConfig* config, FcPattern* pat, FcPattern* font);
/*FcPublic*/ FcFontSet* FcFontSetSort (FcConfig* config, FcFontSet** sets, int      nsets, FcPattern* p, FcBool     trim, FcCharSet** csp,FcResult* result);
/*FcPublic*/ FcFontSet* FcFontSort (FcConfig* config, FcPattern* p, FcBool   trim, FcCharSet** csp, FcResult* result);
/*FcPublic*/ void FcFontSetSortDestroy (FcFontSet* fs);

/* fcmatrix.c */
/*FcPublic*/ FcMatrix* FcMatrixCopy (const(FcMatrix)* mat);
/*FcPublic*/ FcBool FcMatrixEqual (const(FcMatrix)* mat1, const(FcMatrix)* mat2);
/*FcPublic*/ void FcMatrixMultiply (FcMatrix* result, const(FcMatrix)* a, const(FcMatrix)* b);
/*FcPublic*/ void FcMatrixRotate (FcMatrix* m, double c, double s);
/*FcPublic*/ void FcMatrixScale (FcMatrix* m, double sx, double sy);
/*FcPublic*/ void FcMatrixShear (FcMatrix* m, double sh, double sv);

/* fcname.c */
/* Deprecated.  Does nothing.  Returns FcFalse. */
/*FcPublic*/ FcBool FcNameRegisterObjectTypes (const(FcObjectType)* types, int ntype);
/* Deprecated.  Does nothing.  Returns FcFalse. */
/*FcPublic*/ FcBool FcNameUnregisterObjectTypes (const(FcObjectType)* types, int ntype);
/*FcPublic*/ const(FcObjectType)* FcNameGetObjectType (const(char)* object);
/* Deprecated.  Does nothing.  Returns FcFalse. */
/*FcPublic*/ FcBool FcNameRegisterConstants (const(FcConstant)* consts, int nconsts);
/* Deprecated.  Does nothing.  Returns FcFalse. */
/*FcPublic*/ FcBool FcNameUnregisterConstants (const(FcConstant)* consts, int nconsts);
/*FcPublic*/ const(FcConstant)* FcNameGetConstant (const(FcChar8)* string);
/*FcPublic*/ FcBool FcNameConstant (const(FcChar8)* string, int* result);
/*FcPublic*/ FcPattern* FcNameParse (const(FcChar8)* name);
/*FcPublic*/ FcChar8* FcNameUnparse (FcPattern* pat);

/* fcpat.c */
/*FcPublic*/ FcPattern* FcPatternCreate ();
/*FcPublic*/ FcPattern* FcPatternDuplicate (const(FcPattern)* p);
/*FcPublic*/ void FcPatternReference (FcPattern* p);
/*FcPublic*/ FcPattern* FcPatternFilter (FcPattern* p, const(FcObjectSet)* os);
/*FcPublic*/ void FcValueDestroy (FcValue v);
/*FcPublic*/ FcBool FcValueEqual (FcValue va, FcValue vb);
/*FcPublic*/ FcValue FcValueSave (FcValue v);
/*FcPublic*/ void FcPatternDestroy (FcPattern* p);
/*FcPublic*/ FcBool FcPatternEqual (const(FcPattern)* pa, const(FcPattern)* pb);
/*FcPublic*/ FcBool FcPatternEqualSubset (const(FcPattern)* pa, const(FcPattern)* pb, const(FcObjectSet)* os);
/*FcPublic*/ FcChar32 FcPatternHash (const(FcPattern)* p);
/*FcPublic*/ FcBool FcPatternAdd (FcPattern* p, const(char)* object, FcValue value, FcBool append);
/*FcPublic*/ FcBool FcPatternAddWeak (FcPattern* p, const(char)* object, FcValue value, FcBool append);
/*FcPublic*/ FcResult FcPatternGet (const(FcPattern)* p, const(char)* object, int id, FcValue* v);
/*FcPublic*/ FcBool FcPatternDel (FcPattern* p, const(char)* object);
/*FcPublic*/ FcBool FcPatternRemove (FcPattern* p, const(char)* object, int id);
/*FcPublic*/ FcBool FcPatternAddInteger (FcPattern* p, const(char)* object, int i);
/*FcPublic*/ FcBool FcPatternAddDouble (FcPattern* p, const(char)* object, double d);
/*FcPublic*/ FcBool FcPatternAddString (FcPattern* p, const(char)* object, const(FcChar8)* s);
/*FcPublic*/ FcBool FcPatternAddMatrix (FcPattern* p, const(char)* object, const(FcMatrix)* s);
/*FcPublic*/ FcBool FcPatternAddCharSet (FcPattern* p, const(char)* object, const(FcCharSet)* c);
/*FcPublic*/ FcBool FcPatternAddBool (FcPattern* p, const(char)* object, FcBool b);
/*FcPublic*/ FcBool FcPatternAddLangSet (FcPattern* p, const(char)* object, const(FcLangSet)* ls);
/*FcPublic*/ FcResult FcPatternGetInteger (const(FcPattern)* p, const(char)* object, int n, int* i);
/*FcPublic*/ FcResult FcPatternGetDouble (const(FcPattern)* p, const(char)* object, int n, double* d);
/*FcPublic*/ FcResult FcPatternGetString (const(FcPattern)* p, const(char)* object, int n, FcChar8** s);
/*FcPublic*/ FcResult FcPatternGetMatrix (const(FcPattern)* p, const(char)* object, int n, FcMatrix** s);
/*FcPublic*/ FcResult FcPatternGetCharSet (const(FcPattern)* p, const(char)* object, int n, FcCharSet** c);
/*FcPublic*/ FcResult FcPatternGetBool (const(FcPattern)* p, const(char)* object, int n, FcBool* b);
/*FcPublic*/ FcResult FcPatternGetLangSet (const(FcPattern)* p, const(char)* object, int n, FcLangSet** ls);
/*FcPublic*/ FcPattern* FcPatternVaBuild (FcPattern* p, va_list va);
/*FcPublic*/ FcPattern* FcPatternBuild (FcPattern* p, ...) /*FC_ATTRIBUTE_SENTINEL(0)*/;
/*FcPublic*/ FcChar8* FcPatternFormat (FcPattern* pat, const(FcChar8)* format);

/* fcstr.c */
/*FcPublic*/ FcChar8* FcStrCopy (const(FcChar8)* s);
/*FcPublic*/ FcChar8* FcStrCopyFilename (const(FcChar8)* s);
/*FcPublic*/ FcChar8* FcStrPlus (const(FcChar8)* s1, const(FcChar8)* s2);
/*FcPublic*/ void FcStrFree (FcChar8* s);

/* These are ASCII only, suitable only for pattern element names */
/*
#define FcIsUpper(c)  ((0101 <= (c) && (c) <= 0132))
#define FcIsLower(c)  ((0141 <= (c) && (c) <= 0172))
#define FcToLower(c)  (FcIsUpper(c) ? (c) - 0101 + 0141 : (c))
*/

/*FcPublic*/ FcChar8* FcStrDowncase (const(FcChar8)* s);
/*FcPublic*/ int FcStrCmpIgnoreCase (const(FcChar8)* s1, const(FcChar8)* s2);
/*FcPublic*/ int FcStrCmp (const(FcChar8)* s1, const(FcChar8)* s2);
/*FcPublic*/ const(FcChar8)* FcStrStrIgnoreCase (const(FcChar8)* s1, const(FcChar8)* s2);
/*FcPublic*/ const(FcChar8)* FcStrStr (const(FcChar8)* s1, const(FcChar8)* s2);
/*FcPublic*/ int FcUtf8ToUcs4 (const(FcChar8)* src_orig, FcChar32* dst, int len);
/*FcPublic*/ FcBool FcUtf8Len (const(FcChar8)* string, int len, int* nchar, int* wchr);

enum FC_UTF8_MAX_LEN = 6;

/*FcPublic*/ int FcUcs4ToUtf8 (FcChar32  ucs4, FcChar8*/*[FC_UTF8_MAX_LEN]*/ dest);
/*FcPublic*/ int FcUtf16ToUcs4 (const(FcChar8)* src_orig, FcEndian endian, FcChar32* dst, int len);     /* len: in bytes */
/*FcPublic*/ FcBool FcUtf16Len (const(FcChar8)* string, FcEndian endian, int len, int* nchar, int* wchr); /* len: in bytes */
/*FcPublic*/ FcChar8* FcStrDirname (const(FcChar8)* file);
/*FcPublic*/ FcChar8* FcStrBasename (const(FcChar8)* file);
/*FcPublic*/ FcStrSet* FcStrSetCreate ();
/*FcPublic*/ FcBool FcStrSetMember (FcStrSet* set, const(FcChar8)* s);
/*FcPublic*/ FcBool FcStrSetEqual (FcStrSet* sa, FcStrSet* sb);
/*FcPublic*/ FcBool FcStrSetAdd (FcStrSet* set, const(FcChar8)* s);
/*FcPublic*/ FcBool FcStrSetAddFilename (FcStrSet* set, const(FcChar8)* s);
/*FcPublic*/ FcBool FcStrSetDel (FcStrSet* set, const(FcChar8)* s);
/*FcPublic*/ void FcStrSetDestroy (FcStrSet* set);
/*FcPublic*/ FcStrList* FcStrListCreate (FcStrSet* set);
/*FcPublic*/ void FcStrListFirst (FcStrList* list);
/*FcPublic*/ FcChar8* FcStrListNext (FcStrList* list);
/*FcPublic*/ void FcStrListDone (FcStrList* list);

/* fcxml.c */
/*FcPublic*/ FcBool FcConfigParseAndLoad (FcConfig* config, const(FcChar8)* file, FcBool complain);


/+
#ifndef _FCINT_H_
/*
 * Deprecated functions are placed here to help users fix their code without
 * digging through documentation
 */
#define FcConfigGetRescanInverval   FcConfigGetRescanInverval_REPLACE_BY_FcConfigGetRescanInterval
#define FcConfigSetRescanInverval   FcConfigSetRescanInverval_REPLACE_BY_FcConfigSetRescanInterval
#endif
+/

/* fcfreetype.h */
/*FcPublic*/ FT_UInt FcFreeTypeCharIndex (FT_Face face, FcChar32 ucs4);
/*FcPublic*/ FcCharSet* FcFreeTypeCharSetAndSpacing (FT_Face face, FcBlanks* blanks, int* spacing);
/*FcPublic*/ FcCharSet* FcFreeTypeCharSet (FT_Face face, FcBlanks* blanks);
/*FcPublic*/ FcResult FcPatternGetFTFace (const(FcPattern)* p, const(char)* object, int n, FT_Face* f);
/*FcPublic*/ FcBool FcPatternAddFTFace (FcPattern* p, const(char)* object, const FT_Face f);
/*FcPublic*/ FcPattern* FcFreeTypeQueryFace (const FT_Face face, const(FcChar8)* file, int id, FcBlanks* blanks);
