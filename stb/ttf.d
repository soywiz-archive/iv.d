// stb_truetype.h - v1.11 - public domain
// authored from 2009-2015 by Sean Barrett / RAD Game Tools
// D port by Ketmar // Invisible Vector
//
//   This library processes TrueType files:
//        parse files
//        extract glyph metrics
//        extract glyph shapes
//        render glyphs to one-channel bitmaps with antialiasing (box filter)
//
//   Todo:
//        non-MS cmaps
//        crashproof on bad data
//        hinting? (no longer patented)
//        cleartype-style AA?
//        optimize: use simple memory allocator for intermediates
//        optimize: build edge-list directly from curves
//        optimize: rasterize directly from curves?
//
// ADDITIONAL CONTRIBUTORS
//
//   Mikko Mononen: compound shape support, more cmap formats
//   Tor Andersson: kerning, subpixel rendering
//
//   Misc other:
//       Ryan Gordon
//       Simon Glass
//
//   Bug/warning reports/fixes:
//       "Zer" on mollyrocket (with fix)
//       Cass Everitt
//       stoiko (Haemimont Games)
//       Brian Hook
//       Walter van Niftrik
//       David Gow
//       David Given
//       Ivan-Assen Ivanov
//       Anthony Pesch
//       Johan Duparc
//       Hou Qiming
//       Fabian "ryg" Giesen
//       Martins Mozeiko
//       Cap Petschulat
//       Omar Cornut
//       github:aloucks
//       Peter LaValle
//       Sergey Popov
//       Giumo X. Clanjor
//       Higor Euripedes
//       Thomas Fields
//       Derek Vinyard
//
// VERSION HISTORY
//
//   1.11 (2016-04-02) fix unused-variable warning
//   1.10 (2016-04-02) user-defined fabs(); rare memory leak; remove duplicate typedef
//   1.09 (2016-01-16) warning fix; avoid crash on outofmem; use allocation userdata properly
//   1.08 (2015-09-13) document stbtt_Rasterize(); fixes for vertical & horizontal edges
//   1.07 (2015-08-01) allow PackFontRanges to accept arrays of sparse codepoints;
//                     variant PackFontRanges to pack and render in separate phases;
//                     fix stbtt_GetFontOFfsetForIndex (never worked for non-0 input?);
//                     fixed an assert() bug in the new rasterizer
//                     replace assert() with STBTT_assert() in new rasterizer
//   1.06 (2015-07-14) performance improvements (~35% faster on x86 and x64 on test machine)
//                     also more precise AA rasterizer, except if shapes overlap
//                     remove need for STBTT_sort
//   1.05 (2015-04-15) fix misplaced definitions for STBTT_STATIC
//   1.04 (2015-04-15) typo in example
//   1.03 (2015-04-12) STBTT_STATIC, fix memory leak in new packing, various fixes
//
//   Full history can be found at the end of this file.
//
// LICENSE
//
//   This software is dual-licensed to the public domain and under the following
//   license: you are granted a perpetual, irrevocable license to copy, modify,
//   publish, and distribute this file as you see fit.
//
// USAGE
//
//   "Load" a font file from a memory buffer (you have to keep the buffer loaded)
//           stbtt_InitFont()
//           stbtt_GetFontOffsetForIndex()        -- use for TTC font collections
//
//   Render a unicode codepoint to a bitmap
//           stbtt_GetCodepointBitmap()           -- allocates and returns a bitmap
//           stbtt_MakeCodepointBitmap()          -- renders into bitmap you provide
//           stbtt_GetCodepointBitmapBox()        -- how big the bitmap must be
//
//   Character advance/positioning
//           stbtt_GetCodepointHMetrics()
//           stbtt_GetFontVMetrics()
//           stbtt_GetCodepointKernAdvance()
//
//   Starting with version 1.06, the rasterizer was replaced with a new,
//   faster and generally-more-precise rasterizer. The new rasterizer more
//   accurately measures pixel coverage for anti-aliasing, except in the case
//   where multiple shapes overlap, in which case it overestimates the AA pixel
//   coverage. Thus, anti-aliasing of intersecting shapes may look wrong. If
//   this turns out to be a problem, you can re-enable the old rasterizer with
//        #define STBTT_RASTERIZER_VERSION 1
//   which will incur about a 15% speed hit.
//
// ADDITIONAL DOCUMENTATION
//
//   Immediately after this block comment are a series of sample programs.
//
//   After the sample programs is the "header file" section. This section
//   includes documentation for each API function.
//
//   Some important concepts to understand to use this library:
//
//      Codepoint
//         Characters are defined by unicode codepoints, e.g. 65 is
//         uppercase A, 231 is lowercase c with a cedilla, 0x7e30 is
//         the hiragana for "ma".
//
//      Glyph
//         A visual character shape (every codepoint is rendered as
//         some glyph)
//
//      Glyph index
//         A font-specific integer ID representing a glyph
//
//      Baseline
//         Glyph shapes are defined relative to a baseline, which is the
//         bottom of uppercase characters. Characters extend both above
//         and below the baseline.
//
//      Current Point
//         As you draw text to the screen, you keep track of a "current point"
//         which is the origin of each character. The current point's vertical
//         position is the baseline. Even "baked fonts" use this model.
//
//      Vertical Font Metrics
//         The vertical qualities of the font, used to vertically position
//         and space the characters. See docs for stbtt_GetFontVMetrics.
//
//      Font Size in Pixels or Points
//         The preferred interface for specifying font sizes in stb_truetype
//         is to specify how tall the font's vertical extent should be in pixels.
//         If that sounds good enough, skip the next paragraph.
//
//         Most font APIs instead use "points", which are a common typographic
//         measurement for describing font size, defined as 72 points per inch.
//         stb_truetype provides a point API for compatibility. However, true
//         "per inch" conventions don't make much sense on computer displays
//         since they different monitors have different number of pixels per
//         inch. For example, Windows traditionally uses a convention that
//         there are 96 pixels per inch, thus making 'inch' measurements have
//         nothing to do with inches, and thus effectively defining a point to
//         be 1.333 pixels. Additionally, the TrueType font data provides
//         an explicit scale factor to scale a given font's glyphs to points,
//         but the author has observed that this scale factor is often wrong
//         for non-commercial fonts, thus making fonts scaled in points
//         according to the TrueType spec incoherently sized in practice.
//
// ADVANCED USAGE
//
//   Quality:
//
//    - Use the functions with Subpixel at the end to allow your characters
//      to have subpixel positioning. Since the font is anti-aliased, not
//      hinted, this is very import for quality. (This is not possible with
//      baked fonts.)
//
//    - Kerning is now supported, and if you're supporting subpixel rendering
//      then kerning is worth using to give your text a polished look.
//
//   Performance:
//
//    - Convert Unicode codepoints to glyph indexes and operate on the glyphs;
//      if you don't do this, stb_truetype is forced to do the conversion on
//      every call.
//
//    - There are a lot of memory allocations. We should modify it to take
//      a temp buffer and allocate from the temp buffer (without freeing),
//      should help performance a lot.
//
// NOTES
//
//   The system uses the raw data found in the .ttf file without changing it
//   and without building auxiliary data structures. This is a bit inefficient
//   on little-endian systems (the data is big-endian), but assuming you're
//   caching the bitmaps or glyph shapes this shouldn't be a big deal.
//
//   It appears to be very hard to programmatically determine what font a
//   given file is in a general way. I provide an API for this, but I don't
//   recommend it.
//
module iv.stb.ttf;

private:
// //////////////////////////////////////////////////////////////////////// //
import core.stdc.math : floor, ceil, STBTT_sqrt=sqrt, STBTT_fabs=fabs;
import core.stdc.string : STBTT_strlen=strlen, STBTT_memcpy=memcpy, STBTT_memset=memset;

int STBTT_ifloor() (double n) { pragma(inline, true); return cast(int)floor(n); }
int STBTT_iceil() (double n) { pragma(inline, true); return cast(int)ceil(n); }

T* STBTT_xalloc(T) (uint count, uint additional=0) {
  import core.stdc.stdlib : malloc;
  assert(count != 0);
  return cast(T*)malloc(T.sizeof*count+additional);
}

void STBTT_xfree(T) (ref T* ptr) {
  if (ptr !is null) {
    import core.stdc.stdlib : free;
    free(ptr);
    ptr = null;
  }
}


// ///////////////////////////////////////////////////////////////////////// //
// INTERFACE
public:

// //////////////////////////////////////////////////////////////////////// //
// FONT LOADING

//public int stbtt_GetFontOffsetForIndex(const(ubyte)* data, int index);
// Each .ttf/.ttc file may have more than one font. Each font has a sequential
// index number starting from 0. Call this function to get the font offset for
// a given index; it returns -1 if the index is out of range. A regular .ttf
// file will only define one font and it always be at offset 0, so it will
// return '0' for index 0, and -1 for all other indices. You can just skip
// this step if you know it's that kind of font.


// The following structure is defined publically so you can declare one on
// the stack or as a global or etc, but you should treat it as opaque.
struct stbtt_fontinfo {
  void* userdata;
  ubyte* data;                            // pointer to .ttf file
  int fontstart;                          // offset of start of font
  int numGlyphs;                          // number of glyphs, needed for range checking
  int loca, head, glyf, hhea, hmtx, kern; // table locations as offset from start of .ttf
  int index_map;                          // a cmap mapping for our chosen character encoding
  int indexToLocFormat;                   // format needed to map from glyph index to glyph
}

//public int stbtt_InitFont(stbtt_fontinfo* info, const(ubyte)* data, int offset);
// Given an offset into the file that defines a font, this function builds
// the necessary cached info for the rest of the system. You must allocate
// the stbtt_fontinfo yourself, and stbtt_InitFont will fill it out. You don't
// need to do anything special to free it, because the contents are pure
// value data with no additional data structures. Returns 0 on failure.


//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER TO GLYPH-INDEX CONVERSIOn

//public int stbtt_FindGlyphIndex(const(stbtt_fontinfo)* info, int unicode_codepoint);
// If you're going to perform multiple operations on the same character
// and you want a speed-up, call this function with the character you're
// going to process, then use glyph-based functions instead of the
// codepoint-based functions.


//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER PROPERTIES
//

//public float stbtt_ScaleForPixelHeight(const(stbtt_fontinfo)* info, float pixels);
// computes a scale factor to produce a font whose "height" is 'pixels' tall.
// Height is measured as the distance from the highest ascender to the lowest
// descender; in other words, it's equivalent to calling stbtt_GetFontVMetrics
// and computing:
//       scale = pixels/(ascent-descent)
// so if you prefer to measure height by the ascent only, use a similar calculation.

//public float stbtt_ScaleForMappingEmToPixels(const(stbtt_fontinfo)* info, float pixels);
// computes a scale factor to produce a font whose EM size is mapped to
// 'pixels' tall. This is probably what traditional APIs compute, but
// I'm not positive.

//public void stbtt_GetFontVMetrics(const(stbtt_fontinfo)* info, int* ascent, int* descent, int* lineGap);
// ascent is the coordinate above the baseline the font extends; descent
// is the coordinate below the baseline the font extends (i.e. it is typically negative)
// lineGap is the spacing between one row's descent and the next row's ascent...
// so you should advance the vertical position by "*ascent-*descent+*lineGap"
//   these are expressed in unscaled coordinates, so you must multiply by
//   the scale factor for a given size

//public void stbtt_GetFontBoundingBox(const(stbtt_fontinfo)* info, int* x0, int* y0, int* x1, int* y1);
// the bounding box around all possible characters

//public void stbtt_GetCodepointHMetrics(const(stbtt_fontinfo)* info, int codepoint, int* advanceWidth, int* leftSideBearing);
// leftSideBearing is the offset from the current horizontal position to the left edge of the character
// advanceWidth is the offset from the current horizontal position to the next horizontal position
//   these are expressed in unscaled coordinates

//public int  stbtt_GetCodepointKernAdvance(const(stbtt_fontinfo)* info, int ch1, int ch2);
// an additional amount to add to the 'advance' value between ch1 and ch2

//public int stbtt_GetCodepointBox(const(stbtt_fontinfo)* info, int codepoint, int* x0, int* y0, int* x1, int* y1);
// Gets the bounding box of the visible part of the glyph, in unscaled coordinates

//public void stbtt_GetGlyphHMetrics(const(stbtt_fontinfo)* info, int glyph_index, int* advanceWidth, int* leftSideBearing);
//public int  stbtt_GetGlyphKernAdvance(const(stbtt_fontinfo)* info, int glyph1, int glyph2);
//public int  stbtt_GetGlyphBox(const(stbtt_fontinfo)* info, int glyph_index, int* x0, int* y0, int* x1, int* y1);
// as above, but takes one or more glyph indices for greater efficiency


//////////////////////////////////////////////////////////////////////////////
//
// GLYPH SHAPES (you probably don't need these, but they have to go before
// the bitmaps for C declaration-order reasons)
//

enum {
  STBTT_vmove = 1,
  STBTT_vline,
  STBTT_vcurve
}

alias stbtt_vertex_type = short;
struct stbtt_vertex {
  stbtt_vertex_type x, y, cx, cy;
  ubyte type, padding;
}

//public int stbtt_IsGlyphEmpty(const(stbtt_fontinfo)* info, int glyph_index);
// returns non-zero if nothing is drawn for this glyph

//public int stbtt_GetCodepointShape(const(stbtt_fontinfo)* info, int unicode_codepoint, stbtt_vertex** vertices);
//public int stbtt_GetGlyphShape(const(stbtt_fontinfo)* info, int glyph_index, stbtt_vertex** vertices);
// returns # of vertices and fills *vertices with the pointer to them
//   these are expressed in "unscaled" coordinates
//
// The shape is a series of countours. Each one starts with
// a STBTT_moveto, then consists of a series of mixed
// STBTT_lineto and STBTT_curveto segments. A lineto
// draws a line from previous endpoint to its x, y; a curveto
// draws a quadratic bezier from previous endpoint to
// its x, y, using cx, cy as the bezier control point.

//public void stbtt_FreeShape(const(stbtt_fontinfo)* info, stbtt_vertex* vertices);
// frees the data allocated above

//////////////////////////////////////////////////////////////////////////////
//
// BITMAP RENDERING
//

//public void stbtt_FreeBitmap(ubyte* bitmap, void* userdata);
// frees the bitmap allocated below

//public ubyte* stbtt_GetCodepointBitmap(const(stbtt_fontinfo)* info, float scale_x, float scale_y, int codepoint, int* width, int* height, int* xoff, int* yoff);
// allocates a large-enough single-channel 8bpp bitmap and renders the
// specified character/glyph at the specified scale into it, with
// antialiasing. 0 is no coverage (transparent), 255 is fully covered (opaque).
// *width & *height are filled out with the width & height of the bitmap,
// which is stored left-to-right, top-to-bottom.
//
// xoff/yoff are the offset it pixel space from the glyph origin to the top-left of the bitmap

//public ubyte* stbtt_GetCodepointBitmapSubpixel(const(stbtt_fontinfo)* info, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint, int* width, int* height, int* xoff, int* yoff);
// the same as stbtt_GetCodepoitnBitmap, but you can specify a subpixel
// shift for the character

//public void stbtt_MakeCodepointBitmap(const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int codepoint);
// the same as stbtt_GetCodepointBitmap, but you pass in storage for the bitmap
// in the form of 'output', with row spacing of 'out_stride' bytes. the bitmap
// is clipped to out_w/out_h bytes. Call stbtt_GetCodepointBitmapBox to get the
// width and height and positioning info for it first.

//public void stbtt_MakeCodepointBitmapSubpixel(const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint);
// same as stbtt_MakeCodepointBitmap, but you can specify a subpixel
// shift for the character

//public void stbtt_GetCodepointBitmapBox(const(stbtt_fontinfo)* font, int codepoint, float scale_x, float scale_y, int* ix0, int* iy0, int* ix1, int* iy1);
// get the bbox of the bitmap centered around the glyph origin; so the
// bitmap width is ix1-ix0, height is iy1-iy0, and location to place
// the bitmap top left is (leftSideBearing*scale, iy0).
// (Note that the bitmap uses y-increases-down, but the shape uses
// y-increases-up, so CodepointBitmapBox and CodepointBox are inverted.)

//public void stbtt_GetCodepointBitmapBoxSubpixel(const(stbtt_fontinfo)* font, int codepoint, float scale_x, float scale_y, float shift_x, float shift_y, int* ix0, int* iy0, int* ix1, int* iy1);
// same as stbtt_GetCodepointBitmapBox, but you can specify a subpixel
// shift for the character

// the following functions are equivalent to the above functions, but operate
// on glyph indices instead of Unicode codepoints (for efficiency)
//public ubyte* stbtt_GetGlyphBitmap(const(stbtt_fontinfo)* info, float scale_x, float scale_y, int glyph, int* width, int* height, int* xoff, int* yoff);
//public ubyte* stbtt_GetGlyphBitmapSubpixel(const(stbtt_fontinfo)* info, float scale_x, float scale_y, float shift_x, float shift_y, int glyph, int* width, int* height, int* xoff, int* yoff);
//public void stbtt_MakeGlyphBitmap(const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int glyph);
//public void stbtt_MakeGlyphBitmapSubpixel(const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int glyph);
//public void stbtt_GetGlyphBitmapBox(const(stbtt_fontinfo)* font, int glyph, float scale_x, float scale_y, int* ix0, int* iy0, int* ix1, int* iy1);
//public void stbtt_GetGlyphBitmapBoxSubpixel(const(stbtt_fontinfo)* font, int glyph, float scale_x, float scale_y, float shift_x, float shift_y, int* ix0, int* iy0, int* ix1, int* iy1);


// @TODO: don't expose this structure
struct stbtt__bitmap {
  int w, h, stride;
  ubyte* pixels;
}

// rasterize a shape with quadratic beziers into a bitmap
/*
public void stbtt_Rasterize(stbtt__bitmap* result,        // 1-channel bitmap to draw into
                               float flatness_in_pixels,     // allowable error of curve in pixels
                               stbtt_vertex* vertices,       // array of vertices defining shape
                               int num_verts,                // number of vertices in above array
                               float scale_x, float scale_y, // scale applied to input vertices
                               float shift_x, float shift_y, // translation applied to input vertices
                               int x_off, int y_off,         // another translation applied to input
                               int invert,                   // if non-zero, vertically flip shape
                               void* userdata);              // context for to STBTT_MALLOC
*/

//////////////////////////////////////////////////////////////////////////////
//
// Finding the right font...
//
// You should really just solve this offline, keep your own tables
// of what font is what, and don't try to get it out of the .ttf file.
// That's because getting it out of the .ttf file is really hard, because
// the names in the file can appear in many possible encodings, in many
// possible languages, and e.g. if you need a case-insensitive comparison,
// the details of that depend on the encoding & language in a complex way
// (actually underspecified in truetype, but also gigantic).
//
// But you can use the provided functions in two possible ways:
//     stbtt_FindMatchingFont() will use *case-sensitive* comparisons on
//             unicode-encoded names to try to find the font you want;
//             you can run this before calling stbtt_InitFont()
//
//     stbtt_GetFontNameString() lets you get any of the various strings
//             from the file yourself and do your own comparisons on them.
//             You have to have called stbtt_InitFont() first.


//public int stbtt_FindMatchingFont(const(ubyte)* fontdata, const(char)* name, int flags);
// returns the offset (not index) of the font that matches, or -1 if none
//   if you use STBTT_MACSTYLE_DONTCARE, use a font name like "Arial Bold".
//   if you use any other flag, use a font name like "Arial"; this checks
//     the 'macStyle' header field; i don't know if fonts set this consistently
enum {
  STBTT_MACSTYLE_DONTCARE   = 0,
  STBTT_MACSTYLE_BOLD       = 1,
  STBTT_MACSTYLE_ITALIC     = 2,
  STBTT_MACSTYLE_UNDERSCORE = 4,
  STBTT_MACSTYLE_NONE       = 8, // <= not same as 0, this makes us check the bitfield is 0
}

//public int stbtt_CompareUTF8toUTF16_bigendian(const(char)* s1, int len1, const(char)* s2, int len2);
// returns 1/0 whether the first string interpreted as utf8 is identical to
// the second string interpreted as big-endian utf16... useful for strings from next func

//public const(char)* stbtt_GetFontNameString(const(stbtt_fontinfo)* font, int* length, int platformID, int encodingID, int languageID, int nameID);
// returns the string (which may be big-endian double byte, e.g. for unicode)
// and puts the length in bytes in *length.
//
// some of the values for the IDs are below; for more see the truetype spec:
//     http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6name.html
//     http://www.microsoft.com/typography/otspec/name.htm

enum { // platformID
  STBTT_PLATFORM_ID_UNICODE   =0,
  STBTT_PLATFORM_ID_MAC       =1,
  STBTT_PLATFORM_ID_ISO       =2,
  STBTT_PLATFORM_ID_MICROSOFT =3
}

enum { // encodingID for STBTT_PLATFORM_ID_UNICODE
  STBTT_UNICODE_EID_UNICODE_1_0    =0,
  STBTT_UNICODE_EID_UNICODE_1_1    =1,
  STBTT_UNICODE_EID_ISO_10646      =2,
  STBTT_UNICODE_EID_UNICODE_2_0_BMP=3,
  STBTT_UNICODE_EID_UNICODE_2_0_FULL=4
}

enum { // encodingID for STBTT_PLATFORM_ID_MICROSOFT
  STBTT_MS_EID_SYMBOL        =0,
  STBTT_MS_EID_UNICODE_BMP   =1,
  STBTT_MS_EID_SHIFTJIS      =2,
  STBTT_MS_EID_UNICODE_FULL  =10
}

enum { // encodingID for STBTT_PLATFORM_ID_MAC; same as Script Manager codes
  STBTT_MAC_EID_ROMAN        =0,   STBTT_MAC_EID_ARABIC       =4,
  STBTT_MAC_EID_JAPANESE     =1,   STBTT_MAC_EID_HEBREW       =5,
  STBTT_MAC_EID_CHINESE_TRAD =2,   STBTT_MAC_EID_GREEK        =6,
  STBTT_MAC_EID_KOREAN       =3,   STBTT_MAC_EID_RUSSIAN      =7
}

enum { // languageID for STBTT_PLATFORM_ID_MICROSOFT; same as LCID...
       // problematic because there are e.g. 16 english LCIDs and 16 arabic LCIDs
  STBTT_MS_LANG_ENGLISH     =0x0409,   STBTT_MS_LANG_ITALIAN     =0x0410,
  STBTT_MS_LANG_CHINESE     =0x0804,   STBTT_MS_LANG_JAPANESE    =0x0411,
  STBTT_MS_LANG_DUTCH       =0x0413,   STBTT_MS_LANG_KOREAN      =0x0412,
  STBTT_MS_LANG_FRENCH      =0x040c,   STBTT_MS_LANG_RUSSIAN     =0x0419,
  STBTT_MS_LANG_GERMAN      =0x0407,   STBTT_MS_LANG_SPANISH     =0x0409,
  STBTT_MS_LANG_HEBREW      =0x040d,   STBTT_MS_LANG_SWEDISH     =0x041D
}

enum { // languageID for STBTT_PLATFORM_ID_MAC
  STBTT_MAC_LANG_ENGLISH      =0 ,   STBTT_MAC_LANG_JAPANESE     =11,
  STBTT_MAC_LANG_ARABIC       =12,   STBTT_MAC_LANG_KOREAN       =23,
  STBTT_MAC_LANG_DUTCH        =4 ,   STBTT_MAC_LANG_RUSSIAN      =32,
  STBTT_MAC_LANG_FRENCH       =1 ,   STBTT_MAC_LANG_SPANISH      =6 ,
  STBTT_MAC_LANG_GERMAN       =2 ,   STBTT_MAC_LANG_SWEDISH      =5 ,
  STBTT_MAC_LANG_HEBREW       =10,   STBTT_MAC_LANG_CHINESE_SIMPLIFIED =33,
  STBTT_MAC_LANG_ITALIAN      =3 ,   STBTT_MAC_LANG_CHINESE_TRAD =19
}

// ///////////////////////////////////////////////////////////////////////// //
//   IMPLEMENTATION
private:

enum STBTT_RASTERIZER_VERSION = 2;


//////////////////////////////////////////////////////////////////////////
//
// accessors to parse data from file
//
bool stbtt_tag4() (const(void)* p, ubyte c0, ubyte c1, ubyte c2, ubyte c3) { pragma(inline, true); return ((cast(const(ubyte)*)p)[0] == c0 && (cast(const(ubyte)*)p)[1] == c1 && (cast(const(ubyte)*)p)[2] == c2 && (cast(const(ubyte)*)p)[3] == c3); }
bool stbtt_tag() (const(void)* p, const(char)[] tt) { pragma(inline, true); return ((cast(const(char)*)p)[0..4] == tt[]); }

ubyte ttBYTE() (const(void)* p) { pragma(inline, true); return (cast(const(ubyte)*)p)[0]; }
byte ttCHAR() (const(void)* p) { pragma(inline, true); return (cast(const(byte)*)p)[0]; }
ushort ttUSHORT() (const(void)* p) { pragma(inline, true); return cast(ushort)((cast(const(ubyte)*)p)[0]*256+(cast(const(ubyte)*)p)[1]); }
short ttSHORT() (const(void)* p) { pragma(inline, true); return cast(short)((cast(const(ubyte)*)p)[0]*256+(cast(const(ubyte)*)p)[1]); }
uint ttULONG() (const(void)* p) { pragma(inline, true); return ((cast(const(ubyte)*)p)[0]<<24)+((cast(const(ubyte)*)p)[1]<<16)+((cast(const(ubyte)*)p)[2]<<8)+(cast(const(ubyte)*)p)[3]; }
int ttLONG() (const(void)* p) { pragma(inline, true); return ((cast(const(ubyte)*)p)[0]<<24)+((cast(const(ubyte)*)p)[1]<<16)+((cast(const(ubyte)*)p)[2]<<8)+(cast(const(ubyte)*)p)[3]; }


bool stbtt__isfont (const(void)* font) {
  // check the version number
  const(char)* fnt = cast(const(char)*)font;
  if (fnt[0..4] == "1\x00\x00\x00") return true; // TrueType 1
  if (fnt[0..4] == "typ1") return true; // TrueType with type 1 font -- we don't support this!
  if (fnt[0..4] == "OTTO") return true; // OpenType with CFF
  if (fnt[0..4] == "\x00\x01\x00\x00") return true; // OpenType 1.0
  return false;
}

// @OPTIMIZE: binary search
uint stbtt__find_table (const(ubyte)* data, uint fontstart, const(char)[] tag) {
  int num_tables = ttUSHORT(data+fontstart+4);
  uint tabledir = fontstart+12;
  foreach (uint i; 0..num_tables) {
    uint loc = tabledir+16*i;
    if (stbtt_tag(data+loc+0, tag)) return ttULONG(data+loc+8);
  }
  return 0;
}

public int stbtt_GetFontOffsetForIndex (const(ubyte)* font_collection, int index) {
  // if it's just a font, there's only one valid index
  if (stbtt__isfont(font_collection)) return (index == 0 ? 0 : -1);
  // check if it's a TTC
  if (stbtt_tag(font_collection, "ttcf")) {
    // version 1?
    if (ttULONG(font_collection+4) == 0x00010000 || ttULONG(font_collection+4) == 0x00020000) {
      int n = ttLONG(font_collection+8);
      if (index >= n) return -1;
      return ttULONG(font_collection+12+index*4);
    }
  }
  return -1;
}

public bool stbtt_InitFont (stbtt_fontinfo* info, const(ubyte)* data2, int fontstart) {
  ubyte* data = cast(ubyte*)data2;
  uint cmap, t;
  int numTables;

  info.data = data;
  info.fontstart = fontstart;

  cmap = stbtt__find_table(data, fontstart, "cmap");      // required
  info.loca = stbtt__find_table(data, fontstart, "loca"); // required
  info.head = stbtt__find_table(data, fontstart, "head"); // required
  info.glyf = stbtt__find_table(data, fontstart, "glyf"); // required
  info.hhea = stbtt__find_table(data, fontstart, "hhea"); // required
  info.hmtx = stbtt__find_table(data, fontstart, "hmtx"); // required
  info.kern = stbtt__find_table(data, fontstart, "kern"); // not required
  if (!cmap || !info.loca || !info.head || !info.glyf || !info.hhea || !info.hmtx) return false;

  t = stbtt__find_table(data, fontstart, "maxp");
  if (t) info.numGlyphs = ttUSHORT(data+t+4); else info.numGlyphs = 0xffff;

  // find a cmap encoding table we understand *now* to avoid searching
  // later. (todo: could make this installable)
  // the same regardless of glyph.
  numTables = ttUSHORT(data+cmap+2);
  info.index_map = 0;
  foreach (int i; 0..numTables) {
    uint encoding_record = cmap+4+8*i;
    // find an encoding we understand:
    switch(ttUSHORT(data+encoding_record)) {
      case STBTT_PLATFORM_ID_MICROSOFT:
        switch (ttUSHORT(data+encoding_record+2)) {
          case STBTT_MS_EID_UNICODE_BMP:
          case STBTT_MS_EID_UNICODE_FULL:
            // MS/Unicode
            info.index_map = cmap+ttULONG(data+encoding_record+4);
            break;
          default:
        }
        break;
      case STBTT_PLATFORM_ID_UNICODE:
        // Mac/iOS has these
        // all the encodingIDs are unicode, so we don't bother to check it
        info.index_map = cmap+ttULONG(data+encoding_record+4);
        break;
      default:
    }
  }
  if (info.index_map == 0) return false;

  info.indexToLocFormat = ttUSHORT(data+info.head+50);
  return true;
}

public int stbtt_FindGlyphIndex (const(stbtt_fontinfo)* info, int unicode_codepoint) {
  const(ubyte)* data = info.data;
  uint index_map = info.index_map;
  ushort format = ttUSHORT(data+index_map+0);
  if (format == 0) {
    // apple byte encoding
    int bytes = ttUSHORT(data+index_map+2);
    if (unicode_codepoint < bytes-6) return ttBYTE(data+index_map+6+unicode_codepoint);
    return 0;
  } else if (format == 6) {
    uint first = ttUSHORT(data+index_map+6);
    uint count = ttUSHORT(data+index_map+8);
    if (cast(uint)unicode_codepoint >= first && cast(uint)unicode_codepoint < first+count) return ttUSHORT(data+index_map+10+(unicode_codepoint-first)*2);
    return 0;
  } else if (format == 2) {
    assert(0); // @TODO: high-byte mapping for japanese/chinese/korean
  } else if (format == 4) { // standard mapping for windows fonts: binary search collection of ranges
    ushort segcount = ttUSHORT(data+index_map+6)>>1;
    ushort searchRange = ttUSHORT(data+index_map+8)>>1;
    ushort entrySelector = ttUSHORT(data+index_map+10);
    ushort rangeShift = ttUSHORT(data+index_map+12)>>1;

    // do a binary search of the segments
    uint endCount = index_map+14;
    uint search = endCount;

    if (unicode_codepoint > 0xffff) return 0;

    // they lie from endCount .. endCount+segCount
    // but searchRange is the nearest power of two, so...
    if (unicode_codepoint >= ttUSHORT(data+search+rangeShift*2)) search += rangeShift*2;

     // now decrement to bias correctly to find smallest
    search -= 2;
    while (entrySelector) {
      ushort end;
      searchRange >>= 1;
      end = ttUSHORT(data+search+searchRange*2);
      if (unicode_codepoint > end) search += searchRange*2;
      --entrySelector;
    }
    search += 2;

    ushort offset, start;
    ushort item = cast(ushort)((search-endCount)>>1);

    assert(unicode_codepoint <= ttUSHORT(data+endCount+2*item));
    start = ttUSHORT(data+index_map+14+segcount*2+2+2*item);
    if (unicode_codepoint < start) return 0;

    offset = ttUSHORT(data+index_map+14+segcount*6+2+2*item);
    if (offset == 0) return cast(ushort)(unicode_codepoint+ttSHORT(data+index_map+14+segcount*4+2+2*item));

    return ttUSHORT(data+offset+(unicode_codepoint-start)*2+index_map+14+segcount*6+2+2*item);
  } else if (format == 12 || format == 13) {
    uint ngroups = ttULONG(data+index_map+12);
    int low, high;
    low = 0; high = cast(int)ngroups;
    // Binary search the right group.
    while (low < high) {
      int mid = low+((high-low)>>1); // rounds down, so low <= mid < high
      uint start_char = ttULONG(data+index_map+16+mid*12);
      uint end_char = ttULONG(data+index_map+16+mid*12+4);
           if (cast(uint)unicode_codepoint < start_char) high = mid;
      else if (cast(uint)unicode_codepoint > end_char) low = mid+1;
      else {
        uint start_glyph = ttULONG(data+index_map+16+mid*12+8);
        if (format == 12) return start_glyph+unicode_codepoint-start_char;
        return start_glyph; // format == 13
      }
    }
    return 0; // not found
  }
  // @TODO
  assert(0);
}

public int stbtt_GetCodepointShape (const(stbtt_fontinfo)* info, int unicode_codepoint, stbtt_vertex** vertices) {
  return stbtt_GetGlyphShape(info, stbtt_FindGlyphIndex(info, unicode_codepoint), vertices);
}

void stbtt_setvertex (stbtt_vertex* v, ubyte type, int x, int y, int cx, int cy) {
  v.type = type;
  v.x = cast(short)x;
  v.y = cast(short)y;
  v.cx = cast(short)cx;
  v.cy = cast(short)cy;
}

int stbtt__GetGlyfOffset (const(stbtt_fontinfo)* info, int glyph_index) {
  int g1, g2;

  if (glyph_index >= info.numGlyphs) return -1; // glyph index out of range
  if (info.indexToLocFormat >= 2) return -1; // unknown index.glyph map format

  if (info.indexToLocFormat == 0) {
    g1 = info.glyf+ttUSHORT(info.data+info.loca+glyph_index*2)*2;
    g2 = info.glyf+ttUSHORT(info.data+info.loca+glyph_index*2+2)*2;
  } else {
    g1 = info.glyf+ttULONG (info.data+info.loca+glyph_index*4);
    g2 = info.glyf+ttULONG (info.data+info.loca+glyph_index*4+4);
  }

  return (g1 == g2 ? -1 : g1); // if length is 0, return -1
}

public int stbtt_GetGlyphBox (const(stbtt_fontinfo)* info, int glyph_index, int* x0, int* y0, int* x1, int* y1) {
  int g = stbtt__GetGlyfOffset(info, glyph_index);
  if (g < 0) return 0;

  if (x0) *x0 = ttSHORT(info.data+g+2);
  if (y0) *y0 = ttSHORT(info.data+g+4);
  if (x1) *x1 = ttSHORT(info.data+g+6);
  if (y1) *y1 = ttSHORT(info.data+g+8);
  return 1;
}

public int stbtt_GetCodepointBox (const(stbtt_fontinfo)* info, int codepoint, int* x0, int* y0, int* x1, int* y1) {
  return stbtt_GetGlyphBox(info, stbtt_FindGlyphIndex(info, codepoint), x0, y0, x1, y1);
}

public int stbtt_IsGlyphEmpty (const(stbtt_fontinfo)* info, int glyph_index) {
  short numberOfContours;
  int g = stbtt__GetGlyfOffset(info, glyph_index);
  if (g < 0) return 1;
  numberOfContours = ttSHORT(info.data+g);
  return numberOfContours == 0;
}

int stbtt__close_shape (stbtt_vertex* vertices, int num_vertices, int was_off, int start_off, int sx, int sy, int scx, int scy, int cx, int cy) {
  if (start_off) {
    if (was_off) stbtt_setvertex(&vertices[num_vertices++], STBTT_vcurve, (cx+scx)>>1, (cy+scy)>>1, cx, cy);
    stbtt_setvertex(&vertices[num_vertices++], STBTT_vcurve, sx, sy, scx, scy);
  } else {
    if (was_off)
      stbtt_setvertex(&vertices[num_vertices++], STBTT_vcurve, sx, sy, cx, cy);
    else
      stbtt_setvertex(&vertices[num_vertices++], STBTT_vline, sx, sy, 0, 0);
  }
  return num_vertices;
}

public int stbtt_GetGlyphShape (const(stbtt_fontinfo)* info, int glyph_index, stbtt_vertex** pvertices) {
  short numberOfContours;
  const(ubyte)* endPtsOfContours;
  const(ubyte)* data = info.data;
  stbtt_vertex* vertices = null;
  int num_vertices = 0;
  int g = stbtt__GetGlyfOffset(info, glyph_index);

  *pvertices = null;

  if (g < 0) return 0;

  numberOfContours = ttSHORT(data+g);

  if (numberOfContours > 0) {
    ubyte flags = 0, flagcount;
    int ins, j = 0, m, n, next_move, was_off = 0, off, start_off = 0;
    int x, y, cx, cy, sx, sy, scx, scy;
    const(ubyte)* points;
    endPtsOfContours = (data+g+10);
    ins = ttUSHORT(data+g+10+numberOfContours*2);
    points = data+g+10+numberOfContours*2+2+ins;

    n = 1+ttUSHORT(endPtsOfContours+numberOfContours*2-2);

    m = n+2*numberOfContours; // a loose bound on how many vertices we might need
    vertices = STBTT_xalloc!stbtt_vertex(m);
    if (vertices is null) return 0;

    next_move = 0;
    flagcount = 0;

    // in first pass, we load uninterpreted data into the allocated array
    // above, shifted to the end of the array so we won't overwrite it when
    // we create our final data starting from the front

    off = m-n; // starting offset for uninterpreted data, regardless of how m ends up being calculated

    // first load flags

    foreach (int i; 0..n) {
      if (flagcount == 0) {
        flags = *points++;
        if (flags&8) flagcount = *points++;
      } else {
        --flagcount;
      }
      vertices[off+i].type = flags;
    }

    // now load x coordinates
    x = 0;
    foreach (int i; 0..n) {
      flags = vertices[off+i].type;
      if (flags&2) {
        short dx = *points++;
        x += (flags&16 ? dx : -(cast(int)dx)); // ???
      } else {
        if (!(flags&16)) {
          x = x+cast(short)(points[0]*256+points[1]);
          points += 2;
        }
      }
      vertices[off+i].x = cast(short)x;
    }

    // now load y coordinates
    y = 0;
    foreach (int i; 0..n) {
      flags = vertices[off+i].type;
      if (flags&4) {
        short dy = *points++;
        y += (flags&32 ? dy : -(cast(int)dy)); // ???
      } else {
        if (!(flags&32)) {
          y = y+cast(short)(points[0]*256+points[1]);
          points += 2;
        }
      }
      vertices[off+i].y = cast(short)y;
    }

    // now convert them to our format
    num_vertices = 0;
    sx = sy = cx = cy = scx = scy = 0;
    foreach (int i; 0..n) {
      flags = vertices[off+i].type;
      x = cast(short)vertices[off+i].x;
      y = cast(short)vertices[off+i].y;
      if (next_move == i) {
        if (i != 0) num_vertices = stbtt__close_shape(vertices, num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy);
        // now start the new one
        start_off = !(flags&1);
        if (start_off) {
          // if we start off with an off-curve point, then when we need to find a point on the curve
          // where we can start, and we need to save some state for when we wraparound.
          scx = x;
          scy = y;
          if (!(vertices[off+i+1].type&1)) {
            // next point is also a curve point, so interpolate an on-point curve
            sx = (x+cast(int)vertices[off+i+1].x)>>1;
            sy = (y+cast(int)vertices[off+i+1].y)>>1;
          } else {
            // otherwise just use the next point as our start point
            sx = cast(int)vertices[off+i+1].x;
            sy = cast(int)vertices[off+i+1].y;
            ++i; // we're using point i+1 as the starting point, so skip it
          }
        } else {
          sx = x;
          sy = y;
        }
        stbtt_setvertex(&vertices[num_vertices++], STBTT_vmove, sx, sy, 0, 0);
        was_off = 0;
        next_move = 1+ttUSHORT(endPtsOfContours+j*2);
        ++j;
      } else {
        if (!(flags&1)) { // if it's a curve
          if (was_off) {
            // two off-curve control points in a row means interpolate an on-curve midpoint
            stbtt_setvertex(&vertices[num_vertices++], STBTT_vcurve, (cx+x)>>1, (cy+y)>>1, cx, cy);
          }
          cx = x;
          cy = y;
          was_off = 1;
        } else {
          if (was_off)
            stbtt_setvertex(&vertices[num_vertices++], STBTT_vcurve, x, y, cx, cy);
          else
            stbtt_setvertex(&vertices[num_vertices++], STBTT_vline, x, y, 0, 0);
          was_off = 0;
        }
      }
    }
    num_vertices = stbtt__close_shape(vertices, num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy);
  } else if (numberOfContours == -1) {
    // Compound shapes.
    int more = 1;
    const(ubyte)* comp = data+g+10;
    num_vertices = 0;
    vertices = null;
    while (more) {
      ushort flags, gidx;
      int comp_num_verts = 0;
      stbtt_vertex* comp_verts = null, tmp = null;
      //float[6] mtx = [1, 0, 0, 1, 0, 0];
      float[6] mtx = 0;
      mtx.ptr[0] = mtx.ptr[3] = 1;
      //float m, n;

      flags = ttSHORT(comp); comp += 2;
      gidx = ttSHORT(comp); comp += 2;

      if (flags&2) { // XY values
        if (flags&1) { // shorts
          mtx[4] = ttSHORT(comp); comp += 2;
          mtx[5] = ttSHORT(comp); comp += 2;
        } else {
          mtx[4] = ttCHAR(comp); comp += 1;
          mtx[5] = ttCHAR(comp); comp += 1;
        }
      } else {
        // @TODO handle matching point
        assert(0);
      }
      if (flags&(1<<3)) { // WE_HAVE_A_SCALE
        mtx[0] = mtx[3] = ttSHORT(comp)/16384.0f; comp += 2;
        mtx[1] = mtx[2] = 0;
      } else if (flags&(1<<6)) { // WE_HAVE_AN_X_AND_YSCALE
        mtx[0] = ttSHORT(comp)/16384.0f; comp += 2;
        mtx[1] = mtx[2] = 0;
        mtx[3] = ttSHORT(comp)/16384.0f; comp += 2;
      } else if (flags&(1<<7)) { // WE_HAVE_A_TWO_BY_TWO
        mtx[0] = ttSHORT(comp)/16384.0f; comp += 2;
        mtx[1] = ttSHORT(comp)/16384.0f; comp += 2;
        mtx[2] = ttSHORT(comp)/16384.0f; comp += 2;
        mtx[3] = ttSHORT(comp)/16384.0f; comp += 2;
      }

      // Find transformation scales.
      immutable float m = cast(float)STBTT_sqrt(mtx[0]*mtx[0]+mtx[1]*mtx[1]);
      immutable float n = cast(float)STBTT_sqrt(mtx[2]*mtx[2]+mtx[3]*mtx[3]);

      // Get indexed glyph.
      comp_num_verts = stbtt_GetGlyphShape(info, gidx, &comp_verts);
      if (comp_num_verts > 0) {
        // Transform vertices.
        foreach (int i; 0..comp_num_verts) {
          stbtt_vertex* v = &comp_verts[i];
          stbtt_vertex_type x, y;
          x = v.x; y = v.y;
          v.x = cast(stbtt_vertex_type)(m*(mtx[0]*x+mtx[2]*y+mtx[4]));
          v.y = cast(stbtt_vertex_type)(n*(mtx[1]*x+mtx[3]*y+mtx[5]));
          x = v.cx; y = v.cy;
          v.cx = cast(stbtt_vertex_type)(m*(mtx[0]*x+mtx[2]*y+mtx[4]));
          v.cy = cast(stbtt_vertex_type)(n*(mtx[1]*x+mtx[3]*y+mtx[5]));
        }
        // Append vertices.
        tmp = STBTT_xalloc!stbtt_vertex(num_vertices+comp_num_verts);
        if (!tmp) {
          if (vertices) STBTT_xfree(vertices);
          if (comp_verts) STBTT_xfree(comp_verts);
          return 0;
        }
        if (num_vertices > 0) STBTT_memcpy(tmp, vertices, num_vertices*stbtt_vertex.sizeof);
        STBTT_memcpy(tmp+num_vertices, comp_verts, comp_num_verts*stbtt_vertex.sizeof);
        if (vertices) STBTT_xfree(vertices);
        vertices = tmp;
        STBTT_xfree(comp_verts);
        num_vertices += comp_num_verts;
      }
      // More components ?
      more = flags&(1<<5);
    }
  } else if (numberOfContours < 0) {
    // @TODO other compound variations?
    assert(0);
  } else {
    // numberOfCounters == 0, do nothing
  }

  *pvertices = vertices;
  return num_vertices;
}

public void stbtt_GetGlyphHMetrics (const(stbtt_fontinfo)* info, int glyph_index, int* advanceWidth, int* leftSideBearing) {
  ushort numOfLongHorMetrics = ttUSHORT(info.data+info.hhea+34);
  if (glyph_index < numOfLongHorMetrics) {
    if (advanceWidth !is null) *advanceWidth = ttSHORT(info.data+info.hmtx+4*glyph_index);
    if (leftSideBearing !is null) *leftSideBearing = ttSHORT(info.data+info.hmtx+4*glyph_index+2);
  } else {
    if (advanceWidth !is null) *advanceWidth = ttSHORT(info.data+info.hmtx+4*(numOfLongHorMetrics-1));
    if (leftSideBearing !is null) *leftSideBearing = ttSHORT(info.data+info.hmtx+4*numOfLongHorMetrics+2*(glyph_index-numOfLongHorMetrics));
  }
}

public int stbtt_GetGlyphKernAdvance (const(stbtt_fontinfo)* info, int glyph1, int glyph2) {
  const(ubyte)* data = info.data+info.kern;
  uint needle, straw;
  int l, r, m;

  // we only look at the first table. it must be 'horizontal' and format 0.
  if (!info.kern) return 0;
  if (ttUSHORT(data+2) < 1) return 0; // number of tables, need at least 1
  if (ttUSHORT(data+8) != 1) return 0; // horizontal flag must be set in format

  l = 0;
  r = ttUSHORT(data+10)-1;
  needle = glyph1<<16|glyph2;
  while (l <= r) {
    m = (l+r)>>1;
    straw = ttULONG(data+18+(m*6)); // note: unaligned read
         if (needle < straw) r = m-1;
    else if (needle > straw) l = m+1;
    else return ttSHORT(data+22+(m*6));
  }
  return 0;
}

public int stbtt_GetCodepointKernAdvance (const(stbtt_fontinfo)* info, int ch1, int ch2) {
  if (!info.kern) return 0; // if no kerning table, don't waste time looking up both codepoint.glyphs
  return stbtt_GetGlyphKernAdvance(info, stbtt_FindGlyphIndex(info, ch1), stbtt_FindGlyphIndex(info, ch2));
}

public void stbtt_GetCodepointHMetrics (const(stbtt_fontinfo)* info, int codepoint, int* advanceWidth, int* leftSideBearing) {
  stbtt_GetGlyphHMetrics(info, stbtt_FindGlyphIndex(info, codepoint), advanceWidth, leftSideBearing);
}

public void stbtt_GetFontVMetrics (const(stbtt_fontinfo)* info, int* ascent, int* descent, int* lineGap) {
  if (ascent !is null) *ascent = ttSHORT(info.data+info.hhea+4);
  if (descent !is null) *descent = ttSHORT(info.data+info.hhea+6);
  if (lineGap !is null) *lineGap = ttSHORT(info.data+info.hhea+8);
}

public void stbtt_GetFontBoundingBox (const(stbtt_fontinfo)* info, int* x0, int* y0, int* x1, int* y1) {
  if (x0 !is null) *x0 = ttSHORT(info.data+info.head+36);
  if (y0 !is null) *y0 = ttSHORT(info.data+info.head+38);
  if (x1 !is null) *x1 = ttSHORT(info.data+info.head+40);
  if (y1 !is null) *y1 = ttSHORT(info.data+info.head+42);
}

public float stbtt_ScaleForPixelHeight (const(stbtt_fontinfo)* info, float height) {
  int fheight = ttSHORT(info.data+info.hhea+4)-ttSHORT(info.data+info.hhea+6);
  return cast(float)height/fheight;
}

public float stbtt_ScaleForMappingEmToPixels (const(stbtt_fontinfo)* info, float pixels) {
  int unitsPerEm = ttUSHORT(info.data+info.head+18);
  return pixels/unitsPerEm;
}

public void stbtt_FreeShape (const(stbtt_fontinfo)* info, stbtt_vertex* v) {
  STBTT_xfree(v);
}

//////////////////////////////////////////////////////////////////////////////
//
// antialiasing software rasterizer
//
public void stbtt_GetGlyphBitmapBoxSubpixel (const(stbtt_fontinfo)* font, int glyph, float scale_x, float scale_y, float shift_x, float shift_y, int* ix0, int* iy0, int* ix1, int* iy1) {
  int x0, y0, x1, y1;
  if (!stbtt_GetGlyphBox(font, glyph, &x0, &y0, &x1, &y1)) {
    // e.g. space character
    if (ix0 !is null) *ix0 = 0;
    if (iy0 !is null) *iy0 = 0;
    if (ix1 !is null) *ix1 = 0;
    if (iy1 !is null) *iy1 = 0;
  } else {
    // move to integral bboxes (treating pixels as little squares, what pixels get touched)?
    if (ix0 !is null) *ix0 = STBTT_ifloor( x0*scale_x+shift_x);
    if (iy0 !is null) *iy0 = STBTT_ifloor(-y1*scale_y+shift_y);
    if (ix1 !is null) *ix1 = STBTT_iceil( x1*scale_x+shift_x);
    if (iy1 !is null) *iy1 = STBTT_iceil(-y0*scale_y+shift_y);
  }
}

public void stbtt_GetGlyphBitmapBox (const(stbtt_fontinfo)* font, int glyph, float scale_x, float scale_y, int* ix0, int* iy0, int* ix1, int* iy1) {
  stbtt_GetGlyphBitmapBoxSubpixel(font, glyph, scale_x, scale_y, 0.0f, 0.0f, ix0, iy0, ix1, iy1);
}

public void stbtt_GetCodepointBitmapBoxSubpixel (const(stbtt_fontinfo)* font, int codepoint, float scale_x, float scale_y, float shift_x, float shift_y, int* ix0, int* iy0, int* ix1, int* iy1) {
  stbtt_GetGlyphBitmapBoxSubpixel(font, stbtt_FindGlyphIndex(font, codepoint), scale_x, scale_y, shift_x, shift_y, ix0, iy0, ix1, iy1);
}

public void stbtt_GetCodepointBitmapBox (const(stbtt_fontinfo)* font, int codepoint, float scale_x, float scale_y, int* ix0, int* iy0, int* ix1, int* iy1) {
  stbtt_GetCodepointBitmapBoxSubpixel(font, codepoint, scale_x, scale_y, 0.0f, 0.0f, ix0, iy0, ix1, iy1);
}

//////////////////////////////////////////////////////////////////////////////
//
//  Rasterizer
struct stbtt__hheap_chunk {
  stbtt__hheap_chunk* next;
  // data here
}

struct stbtt__hheap {
  stbtt__hheap_chunk* head;
  void* first_free;
  int num_remaining_in_head_chunk;
}

void* stbtt__hheap_alloc (stbtt__hheap* hh, size_t size, void* userdata) {
  if (hh.first_free) {
    void* p = hh.first_free;
    hh.first_free = *cast(void**)p;
    return p;
  } else {
    if (hh.num_remaining_in_head_chunk == 0) {
      int count = (size < 32 ? 2000 : size < 128 ? 800 : 100);
      stbtt__hheap_chunk* c = STBTT_xalloc!stbtt__hheap_chunk(1, size*count);
      if (c is null) return null;
      c.next = hh.head;
      hh.head = c;
      hh.num_remaining_in_head_chunk = count;
    }
    --hh.num_remaining_in_head_chunk;
    return cast(char*)(hh.head)+size*hh.num_remaining_in_head_chunk;
  }
}

void stbtt__hheap_free (stbtt__hheap* hh, void* p) {
  *cast(void**)p = hh.first_free;
  hh.first_free = p;
}

void stbtt__hheap_cleanup (stbtt__hheap* hh, void* userdata) {
  stbtt__hheap_chunk* c = hh.head;
  while (c !is null) {
    stbtt__hheap_chunk* n = c.next;
    STBTT_xfree(c);
    c = n;
  }
}

struct stbtt__edge {
  float x0, y0, x1, y1;
  int invert;
}

struct stbtt__active_edge {
  stbtt__active_edge* next;
  static if (STBTT_RASTERIZER_VERSION == 1) {
    int x, dx;
    float ey;
    int direction;
  } else static if (STBTT_RASTERIZER_VERSION == 2) {
    float fx, fdx, fdy;
    float direction;
    float sy;
    float ey;
  } else {
    static assert(0, "Unrecognized value of STBTT_RASTERIZER_VERSION");
  }
}

static if (STBTT_RASTERIZER_VERSION == 1) {
enum STBTT_FIXSHIFT = 10;
enum STBTT_FIX = (1<<STBTT_FIXSHIFT);
enum STBTT_FIXMASK = (STBTT_FIX-1);

stbtt__active_edge* stbtt__new_active (stbtt__hheap* hh, stbtt__edge* e, int off_x, float start_point, void* userdata) {
  stbtt__active_edge* z = cast(stbtt__active_edge*)stbtt__hheap_alloc(hh, stbtt__active_edge.sizeof, userdata);
  immutable float dxdy = (e.x1-e.x0)/(e.y1-e.y0);
  assert(z !is null);
  if (!z) return z;

  // round dx down to avoid overshooting
  if (dxdy < 0)
    z.dx = -STBTT_ifloor(STBTT_FIX*-dxdy);
  else
    z.dx = STBTT_ifloor(STBTT_FIX*dxdy);

  z.x = STBTT_ifloor(STBTT_FIX*e.x0+z.dx*(start_point-e.y0)); // use z.dx so when we offset later it's by the same amount
  z.x -= off_x*STBTT_FIX;

  z.ey = e.y1;
  z.next = null;
  z.direction = (e.invert ? 1 : -1);
  return z;
}
} else static if (STBTT_RASTERIZER_VERSION == 2) {
stbtt__active_edge* stbtt__new_active(stbtt__hheap* hh, stbtt__edge* e, int off_x, float start_point, void* userdata) {
  stbtt__active_edge* z = cast(stbtt__active_edge*)stbtt__hheap_alloc(hh, stbtt__active_edge.sizeof, userdata);
  immutable float dxdy = (e.x1-e.x0)/(e.y1-e.y0);
  assert(z !is null);
  //assert(e.y0 <= start_point);
  if (!z) return z;
  z.fdx = dxdy;
  z.fdy = dxdy != 0.0f ? (1.0f/dxdy) : 0.0f;
  z.fx = e.x0+dxdy*(start_point-e.y0);
  z.fx -= off_x;
  z.direction = (e.invert ? 1.0f : -1.0f);
  z.sy = e.y0;
  z.ey = e.y1;
  z.next = null;
  return z;
}
} else {
static assert(0, "Unrecognized value of STBTT_RASTERIZER_VERSION");
}

static if (STBTT_RASTERIZER_VERSION == 1) {
// note: this routine clips fills that extend off the edges... ideally this
// wouldn't happen, but it could happen if the truetype glyph bounding boxes
// are wrong, or if the user supplies a too-small bitmap
void stbtt__fill_active_edges (ubyte* scanline, int len, stbtt__active_edge* e, int max_weight) {
  // non-zero winding fill
  int x0 = 0, w = 0;
  while (e !is null) {
    if (w == 0) {
      // if we're currently at zero, we need to record the edge start point
      x0 = e.x; w += e.direction;
    } else {
      int x1 = e.x; w += e.direction;
      // if we went to zero, we need to draw
      if (w == 0) {
        int i = x0>>STBTT_FIXSHIFT;
        int j = x1>>STBTT_FIXSHIFT;
        if (i < len && j >= 0) {
          if (i == j) {
            // x0, x1 are the same pixel, so compute combined coverage
            scanline[i] = cast(ubyte)(scanline[i]+cast(ubyte)((x1-x0)*max_weight>>STBTT_FIXSHIFT));
          } else {
            if (i >= 0) // add antialiasing for x0
              scanline[i] = cast(ubyte)(scanline[i]+cast(ubyte)(((STBTT_FIX-(x0&STBTT_FIXMASK))*max_weight)>>STBTT_FIXSHIFT));
            else
              i = -1; // clip

            if (j < len) // add antialiasing for x1
              scanline[j] = cast(ubyte)(scanline[j]+cast(ubyte)(((x1&STBTT_FIXMASK)*max_weight)>>STBTT_FIXSHIFT));
            else
              j = len; // clip

            // fill pixels between x0 and x1
            for (++i; i < j; ++i) scanline[i] = cast(ubyte)(scanline[i]+cast(ubyte)max_weight);
          }
        }
      }
    }
    e = e.next;
  }
}

void stbtt__rasterize_sorted_edges (stbtt__bitmap* result, stbtt__edge* e, int n, int vsubsample, int off_x, int off_y, void* userdata) {
  stbtt__hheap hh; // = { 0, 0, 0 };
  stbtt__active_edge* active = null;
  int y, j=0;
  int max_weight = (255/vsubsample);  // weight per vertical scanline
  int s; // vertical subsample index
  ubyte[512] scanline_data;
  ubyte* scanline;

  if (result.w > 512)
    scanline = STBTT_xalloc!ubyte(result.w);
  else
    scanline = scanline_data.ptr;

  y = off_y*vsubsample;
  e[n].y0 = (off_y+result.h)*cast(float)vsubsample+1;

  while (j < result.h) {
    STBTT_memset(scanline, 0, result.w);
    for (s = 0; s < vsubsample; ++s) {
      // find center of pixel for this scanline
      float scan_y = y+0.5f;
      stbtt__active_edge** step = &active;

      // update all active edges;
      // remove all active edges that terminate before the center of this scanline
      while (*step) {
        stbtt__active_edge*z = *step;
        if (z.ey <= scan_y) {
          *step = z.next; // delete from list
          assert(z.direction);
          z.direction = 0;
          stbtt__hheap_free(&hh, z);
        } else {
          z.x += z.dx; // advance to position for current scanline
          step = &((*step).next); // advance through list
        }
      }

      // resort the list if needed
      for (;;) {
        bool changed = false;
        step = &active;
        while (*step && (*step).next) {
          if ((*step).x > (*step).next.x) {
            stbtt__active_edge* t = *step;
            stbtt__active_edge* q = t.next;

            t.next = q.next;
            q.next = t;
            *step = q;
            changed = true;
          }
          step = &(*step).next;
        }
        if (!changed) break;
      }

      // insert all edges that start before the center of this scanline -- omit ones that also end on this scanline
      while (e.y0 <= scan_y) {
        if (e.y1 > scan_y) {
          stbtt__active_edge* z = stbtt__new_active(&hh, e, off_x, scan_y, userdata);
          if (z !is null) {
            // find insertion point
            if (active is null) {
              active = z;
            } else if (z.x < active.x) {
              // insert at front
              z.next = active;
              active = z;
            } else {
              // find thing to insert AFTER
              stbtt__active_edge* p = active;
              while (p.next && p.next.x < z.x) p = p.next;
              // at this point, p.next.x is NOT < z.x
              z.next = p.next;
              p.next = z;
            }
          }
        }
        ++e;
      }

      // now process all active edges in XOR fashion
      if (active) stbtt__fill_active_edges(scanline, result.w, active, max_weight);

      ++y;
    }
    STBTT_memcpy(result.pixels+j*result.stride, scanline, result.w);
    ++j;
  }

  stbtt__hheap_cleanup(&hh, userdata);

  if (scanline !is scanline_data.ptr) STBTT_xfree(scanline);
}

} else static if (STBTT_RASTERIZER_VERSION == 2) {

// the edge passed in here does not cross the vertical line at x or the vertical line at x+1
// (i.e. it has already been clipped to those)
void stbtt__handle_clipped_edge (float* scanline, int x, stbtt__active_edge* e, float x0, float y0, float x1, float y1) {
  if (y0 == y1) return;
  assert(y0 < y1);
  assert(e.sy <= e.ey);
  if (y0 > e.ey) return;
  if (y1 < e.sy) return;
  if (y0 < e.sy) {
    x0 += (x1-x0)*(e.sy-y0)/(y1-y0);
    y0 = e.sy;
  }
  if (y1 > e.ey) {
    x1 += (x1-x0)*(e.ey-y1)/(y1-y0);
    y1 = e.ey;
  }

  version(none) {
         if (x0 == x) assert(x1 <= x+1);
    else if (x0 == x+1) assert(x1 >= x);
    else if (x0 <= x) assert(x1 <= x);
    else if (x0 >= x+1) assert(x1 >= x+1);
    else assert(x1 >= x && x1 <= x+1);
  }

  if (x0 <= x && x1 <= x) {
    scanline[x] += e.direction*(y1-y0);
  } else if (x0 >= x+1 && x1 >= x+1) {
  } else {
    assert(x0 >= x && x0 <= x+1 && x1 >= x && x1 <= x+1);
    scanline[x] += e.direction*(y1-y0)*(1-((x0-x)+(x1-x))/2); // coverage = 1-average x position
  }
}

void stbtt__fill_active_edges_new (float* scanline, float* scanline_fill, int len, stbtt__active_edge* e, float y_top) {
  float y_bottom = y_top+1;
  while (e !is null) {
    // brute force every pixel

    // compute intersection points with top & bottom
    assert(e.ey >= y_top);
    if (e.fdx == 0) {
      float x0 = e.fx;
      if (x0 < len) {
        if (x0 >= 0) {
          stbtt__handle_clipped_edge(scanline, cast(int)x0, e, x0, y_top, x0, y_bottom);
          stbtt__handle_clipped_edge(scanline_fill-1, cast(int)x0+1, e, x0, y_top, x0, y_bottom);
        } else {
          stbtt__handle_clipped_edge(scanline_fill-1, 0, e, x0, y_top, x0, y_bottom);
        }
      }
    } else {
      float x0 = e.fx;
      float dx = e.fdx;
      float xb = x0+dx;
      float x_top, x_bottom;
      float sy0, sy1;
      float dy = e.fdy;
      assert(e.sy <= y_bottom && e.ey >= y_top);

      // compute endpoints of line segment clipped to this scanline (if the
      // line segment starts on this scanline. x0 is the intersection of the
      // line with y_top, but that may be off the line segment.
      if (e.sy > y_top) {
        x_top = x0+dx*(e.sy-y_top);
        sy0 = e.sy;
      } else {
        x_top = x0;
        sy0 = y_top;
      }
      if (e.ey < y_bottom) {
        x_bottom = x0+dx*(e.ey-y_top);
        sy1 = e.ey;
      } else {
        x_bottom = xb;
        sy1 = y_bottom;
      }

      if (x_top >= 0 && x_bottom >= 0 && x_top < len && x_bottom < len) {
        // from here on, we don't have to range check x values

        if (cast(int)x_top == cast(int)x_bottom) {
          // simple case, only spans one pixel
          int x = cast(int)x_top;
          float height = sy1-sy0;
          assert(x >= 0 && x < len);
          scanline[x] += e.direction*(1-((x_top-x)+(x_bottom-x))/2)*height;
          scanline_fill[x] += e.direction*height; // everything right of this pixel is filled
        } else {
          int x, x1, x2;
          //float y_crossing, step, sign, area;
          // covers 2+ pixels
          if (x_top > x_bottom) {
            // flip scanline vertically; signed area is the same
            sy0 = y_bottom-(sy0-y_top);
            sy1 = y_bottom-(sy1-y_top);
            float t = sy0; sy0 = sy1, sy1 = t;
            t = x_bottom, x_bottom = x_top, x_top = t;
            dx = -dx;
            dy = -dy;
            t = x0, x0 = xb, xb = t;
          }

          x1 = cast(int)x_top;
          x2 = cast(int)x_bottom;
          // compute intersection with y axis at x1+1
          float y_crossing = (x1+1-x0)*dy+y_top;

          float sign = e.direction;
          // area of the rectangle covered from y0..y_crossing
          float area = sign*(y_crossing-sy0);
          // area of the triangle (x_top, y0), (x+1, y0), (x+1, y_crossing)
          scanline[x1] += area*(1-((x_top-x1)+(x1+1-x1))/2);

          float step = sign*dy;
          for (x = x1+1; x < x2; ++x) {
            scanline[x] += area+step/2;
            area += step;
          }
          y_crossing += dy*(x2-(x1+1));

          assert(STBTT_fabs(area) <= 1.01f);

          scanline[x2] += area+sign*(1-((x2-x2)+(x_bottom-x2))/2)*(sy1-y_crossing);

          scanline_fill[x2] += sign*(sy1-sy0);
        }
      } else {
        // if edge goes outside of box we're drawing, we require
        // clipping logic. since this does not match the intended use
        // of this library, we use a different, very slow brute
        // force implementation
        foreach (immutable int x; 0..len) {
          // cases:
          //
          // there can be up to two intersections with the pixel. any intersection
          // with left or right edges can be handled by splitting into two (or three)
          // regions. intersections with top & bottom do not necessitate case-wise logic.
          //
          // the old way of doing this found the intersections with the left & right edges,
          // then used some simple logic to produce up to three segments in sorted order
          // from top-to-bottom. however, this had a problem: if an x edge was epsilon
          // across the x border, then the corresponding y position might not be distinct
          // from the other y segment, and it might ignored as an empty segment. to avoid
          // that, we need to explicitly produce segments based on x positions.

          // rename variables to clear pairs
          float y0 = y_top;
          float x1 = cast(float)(x);
          float x2 = cast(float)(x+1);
          float x3 = xb;
          float y3 = y_bottom;
          //float y1, y2;

          // x = e.x+e.dx*(y-y_top)
          // (y-y_top) = (x-e.x)/e.dx
          // y = (x-e.x)/e.dx+y_top
          float y1 = (x-x0)/dx+y_top;
          float y2 = (x+1-x0)/dx+y_top;

          if (x0 < x1 && x3 > x2) {         // three segments descending down-right
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1);
            stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x2, y2);
            stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x3, y3);
          } else if (x3 < x1 && x0 > x2) {  // three segments descending down-left
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x2, y2);
            stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x1, y1);
            stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x3, y3);
          } else if (x0 < x1 && x3 > x1) {  // two segments across x, down-right
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1);
            stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x3, y3);
          } else if (x3 < x1 && x0 > x1) {  // two segments across x, down-left
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1);
            stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x3, y3);
          } else if (x0 < x2 && x3 > x2) {  // two segments across x+1, down-right
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x2, y2);
            stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x3, y3);
          } else if (x3 < x2 && x0 > x2) {  // two segments across x+1, down-left
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x2, y2);
            stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x3, y3);
          } else {  // one segment
            stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x3, y3);
          }
        }
      }
    }
    e = e.next;
  }
}

// directly AA rasterize edges w/o supersampling
void stbtt__rasterize_sorted_edges (stbtt__bitmap* result, stbtt__edge* e, int n, int vsubsample, int off_x, int off_y, void* userdata) {
  stbtt__hheap hh;// = { 0, 0, 0 };
  stbtt__active_edge* active = null;
  int y, j = 0;
  float[129] scanline_data = void;
  float* scanline, scanline2;

  if (result.w > 64)
    scanline = STBTT_xalloc!float(result.w*2+1);
  else
    scanline = scanline_data.ptr;

  scanline2 = scanline+result.w;

  y = off_y;
  e[n].y0 = cast(float)(off_y+result.h)+1;

  while (j < result.h) {
    // find center of pixel for this scanline
    float scan_y_top = y+0.0f;
    float scan_y_bottom = y+1.0f;
    stbtt__active_edge** step = &active;

    STBTT_memset(scanline , 0, result.w*scanline[0].sizeof);
    STBTT_memset(scanline2, 0, (result.w+1)*scanline[0].sizeof);

    // update all active edges;
    // remove all active edges that terminate before the top of this scanline
    while (*step) {
      stbtt__active_edge*z = *step;
      if (z.ey <= scan_y_top) {
        *step = z.next; // delete from list
        assert(z.direction);
        z.direction = 0;
        stbtt__hheap_free(&hh, z);
      } else {
        step = &((*step).next); // advance through list
      }
    }

    // insert all edges that start before the bottom of this scanline
    while (e.y0 <= scan_y_bottom) {
      if (e.y0 != e.y1) {
        stbtt__active_edge* z = stbtt__new_active(&hh, e, off_x, scan_y_top, userdata);
        if (z !is null) {
          assert(z.ey >= scan_y_top);
          // insert at front
          z.next = active;
          active = z;
        }
      }
      ++e;
    }

    // now process all active edges
    if (active) stbtt__fill_active_edges_new(scanline, scanline2+1, result.w, active, scan_y_top);

    float sum = 0;
    foreach (immutable int i; 0..result.w) {
      sum += scanline2[i];
      float k = scanline[i]+sum;
      k = cast(float)STBTT_fabs(k)*255+0.5f;
      int m = cast(int)k;
      if (m > 255) m = 255;
      result.pixels[j*result.stride+i] = cast(ubyte)m;
    }

    // advance all the edges
    step = &active;
    while (*step) {
      stbtt__active_edge* z = *step;
      z.fx += z.fdx; // advance to position for current scanline
      step = &((*step).next); // advance through list
    }

    ++y;
    ++j;
  }

  stbtt__hheap_cleanup(&hh, userdata);

  if (scanline !is scanline_data.ptr) STBTT_xfree(scanline);
}
} else {
static assert(0, "Unrecognized value of STBTT_RASTERIZER_VERSION");
}

void stbtt__sort_edges_ins_sort (stbtt__edge* p, int n) {
  foreach (int i; 1..n) {
    stbtt__edge t = p[i];
    stbtt__edge* a = &t;
    int j = i;
    while (j > 0) {
      stbtt__edge* b = &p[j-1];
      int c = (a.y0 < b.y0);
      if (!c) break;
      p[j] = p[j-1];
      --j;
    }
    if (i != j) p[j] = t;
  }
}

void stbtt__sort_edges_quicksort (stbtt__edge* p, int n) {
  // threshhold for transitioning to insertion sort
  while (n > 12) {
    stbtt__edge t;
    int c01, c12, m, i, j, c;

    // compute median of three
    m = n>>1;
    c01 = (p[0].y0 < p[m].y0);
    c12 = (p[m].y0 < p[n-1].y0);
    // if 0 >= mid >= end, or 0 < mid < end, then use mid
    if (c01 != c12) {
      // otherwise, we'll need to swap something else to middle
      int z;
      c = cast(int)(p[0].y0 < p[n-1].y0);
      // 0>mid && mid<n:  0>n => n; 0<n => 0
      // 0<mid && mid>n:  0>n => 0; 0<n => n
      z = (c == c12 ? 0 : n-1);
      t = p[z];
      p[z] = p[m];
      p[m] = t;
    }
    // now p[m] is the median-of-three
    // swap it to the beginning so it won't move around
    t = p[0];
    p[0] = p[m];
    p[m] = t;

    // partition loop
    i = 1;
    j = n-1;
    for (;;) {
      // handling of equality is crucial here
      // for sentinels&efficiency with duplicates
      for (;;++i) { if (!(p[i].y0 < p[0].y0)) break; }
      for (;;--j) { if (!(p[0].y0 < p[j].y0)) break; }
      // make sure we haven't crossed
      if (i >= j) break;
      t = p[i];
      p[i] = p[j];
      p[j] = t;

      ++i;
      --j;
    }
    // recurse on smaller side, iterate on larger
    if (j < n-i) {
      stbtt__sort_edges_quicksort(p, j);
      p = p+i;
      n = n-i;
    } else {
      stbtt__sort_edges_quicksort(p+i, n-i);
      n = j;
    }
  }
}

void stbtt__sort_edges (stbtt__edge* p, int n) {
  stbtt__sort_edges_quicksort(p, n);
  stbtt__sort_edges_ins_sort(p, n);
}

struct stbtt__point {
  float x, y;
}

void stbtt__rasterize (stbtt__bitmap* result, stbtt__point* pts, int* wcount, int windings, float scale_x, float scale_y, float shift_x, float shift_y, int off_x, int off_y, int invert, void* userdata) {
  float y_scale_inv = (invert ? -scale_y : scale_y);
  stbtt__edge* e;
  int n, j, k, m;
  static if (STBTT_RASTERIZER_VERSION == 1)
    immutable int vsubsample = (result.h < 8 ? 15 : 5);
  else static if (STBTT_RASTERIZER_VERSION == 2)
    enum vsubsample = 1;
  else
    static assert(0, "Unrecognized value of STBTT_RASTERIZER_VERSION");
  // vsubsample should divide 255 evenly; otherwise we won't reach full opacity

  // now we have to blow out the windings into explicit edge lists
  n = 0;
  foreach (immutable int i; 0..windings) n += wcount[i];

  e = STBTT_xalloc!stbtt__edge(n+1); // add an extra one as a sentinel
  if (e is null) return;
  n = 0;

  m = 0;
  foreach (immutable int i; 0..windings) {
    stbtt__point* p = pts+m;
    m += wcount[i];
    j = wcount[i]-1;
    for (k = 0; k < wcount[i]; j = k++) {
      int a = k, b = j;
      // skip the edge if horizontal
      if (p[j].y == p[k].y) continue;
      // add edge from j to k to the list
      e[n].invert = 0;
      if ((invert ? p[j].y > p[k].y : p[j].y < p[k].y)) {
        e[n].invert = 1;
        a=j, b=k;
      }
      e[n].x0 = p[a].x*scale_x+shift_x;
      e[n].y0 = (p[a].y*y_scale_inv+shift_y)*vsubsample;
      e[n].x1 = p[b].x*scale_x+shift_x;
      e[n].y1 = (p[b].y*y_scale_inv+shift_y)*vsubsample;
      ++n;
    }
  }

  // now sort the edges by their highest point (should snap to integer, and then by x)
  //STBTT_sort(e, n, sizeof(e[0]), stbtt__edge_compare);
  stbtt__sort_edges(e, n);

  // now, traverse the scanlines and find the intersections on each scanline, use xor winding rule
  stbtt__rasterize_sorted_edges(result, e, n, vsubsample, off_x, off_y, userdata);

  STBTT_xfree(e);
}

void stbtt__add_point (stbtt__point* points, int n, float x, float y) {
  if (points is null) return; // during first pass, it's unallocated
  points[n].x = x;
  points[n].y = y;
}

// tesselate until threshhold p is happy... @TODO warped to compensate for non-linear stretching
void stbtt__tesselate_curve (stbtt__point* points, int* num_points, float x0, float y0, float x1, float y1, float x2, float y2, float objspace_flatness_squared, int n) {
  // midpoint
  float mx = (x0+2*x1+x2)/4;
  float my = (y0+2*y1+y2)/4;
  // versus directly drawn line
  float dx = (x0+x2)/2-mx;
  float dy = (y0+y2)/2-my;
  if (n > 16) return; // 65536 segments on one curve better be enough!
  if (dx*dx+dy*dy > objspace_flatness_squared) { // half-pixel error allowed... need to be smaller if AA
    stbtt__tesselate_curve(points, num_points, x0, y0, (x0+x1)/2.0f, (y0+y1)/2.0f, mx, my, objspace_flatness_squared, n+1);
    stbtt__tesselate_curve(points, num_points, mx, my, (x1+x2)/2.0f, (y1+y2)/2.0f, x2, y2, objspace_flatness_squared, n+1);
  } else {
    stbtt__add_point(points, *num_points, x2, y2);
    *num_points = *num_points+1;
  }
}

// returns number of contours
stbtt__point* stbtt_FlattenCurves (stbtt_vertex* vertices, int num_verts, float objspace_flatness, int** contour_lengths, int* num_contours, void* userdata) {
  stbtt__point* points = null;
  int num_points = 0;

  float objspace_flatness_squared = objspace_flatness*objspace_flatness;
  int n = 0, start = 0;

  // count how many "moves" there are to get the contour count
  foreach (immutable int i; 0..num_verts) if (vertices[i].type == STBTT_vmove) ++n;

  *num_contours = n;
  if (n == 0) return null;

  *contour_lengths = STBTT_xalloc!int(/*sizeof(**contour_lengths)*/n);

  if (*contour_lengths is null) {
    *num_contours = 0;
    return null;
  }

  // make two passes through the points so we don't need to realloc
  foreach (immutable int pass; 0..2) {
    float x = 0, y = 0;
    if (pass == 1) {
      points = STBTT_xalloc!stbtt__point(num_points);
      if (points is null) goto error;
    }
    num_points = 0;
    n = -1;
    foreach (immutable int i; 0..num_verts) {
      switch (vertices[i].type) {
        case STBTT_vmove:
          // start the next contour
          if (n >= 0) (*contour_lengths)[n] = num_points-start;
          ++n;
          start = num_points;
          x = vertices[i].x, y = vertices[i].y;
          stbtt__add_point(points, num_points++, x, y);
          break;
        case STBTT_vline:
          x = vertices[i].x, y = vertices[i].y;
          stbtt__add_point(points, num_points++, x, y);
          break;
        case STBTT_vcurve:
          stbtt__tesselate_curve(points, &num_points, x, y, vertices[i].cx, vertices[i].cy, vertices[i].x, vertices[i].y, objspace_flatness_squared, 0);
          x = vertices[i].x, y = vertices[i].y;
          break;
        default:
      }
    }
    (*contour_lengths)[n] = num_points-start;
  }

  return points;
error:
  STBTT_xfree(points);
  STBTT_xfree(*contour_lengths);
  *contour_lengths = null;
  *num_contours = 0;
  return null;
}

public void stbtt_Rasterize (stbtt__bitmap* result, float flatness_in_pixels, stbtt_vertex* vertices, int num_verts, float scale_x, float scale_y, float shift_x, float shift_y, int x_off, int y_off, int invert, void* userdata) {
  float scale = (scale_x > scale_y ? scale_y : scale_x);
  int winding_count;
  int* winding_lengths;
  stbtt__point* windings = stbtt_FlattenCurves(vertices, num_verts, flatness_in_pixels/scale, &winding_lengths, &winding_count, userdata);
  if (windings !is null) {
    stbtt__rasterize(result, windings, winding_lengths, winding_count, scale_x, scale_y, shift_x, shift_y, x_off, y_off, invert, userdata);
    STBTT_xfree(winding_lengths);
    STBTT_xfree(windings);
  }
}

public void stbtt_FreeBitmap (ubyte* bitmap, void* userdata) {
  STBTT_xfree(bitmap);
}

public ubyte* stbtt_GetGlyphBitmapSubpixel (const(stbtt_fontinfo)* info, float scale_x, float scale_y, float shift_x, float shift_y, int glyph, int* width, int* height, int* xoff, int* yoff) {
  int ix0, iy0, ix1, iy1;
  stbtt__bitmap gbm;
  stbtt_vertex* vertices;
  int num_verts = stbtt_GetGlyphShape(info, glyph, &vertices);

  if (scale_x == 0) scale_x = scale_y;
  if (scale_y == 0) {
    if (scale_x == 0) {
      STBTT_xfree(vertices);
      return null;
    }
    scale_y = scale_x;
  }

  stbtt_GetGlyphBitmapBoxSubpixel(info, glyph, scale_x, scale_y, shift_x, shift_y, &ix0, &iy0, &ix1, &iy1);

  // now we get the size
  gbm.w = (ix1-ix0);
  gbm.h = (iy1-iy0);
  gbm.pixels = null; // in case we error

  if (width !is null) *width = gbm.w;
  if (height !is null) *height = gbm.h;
  if (xoff !is null) *xoff = ix0;
  if (yoff !is null) *yoff = iy0;

  if (gbm.w && gbm.h) {
    gbm.pixels = STBTT_xalloc!ubyte(gbm.w*gbm.h);
    if (gbm.pixels !is null) {
      gbm.stride = gbm.w;
      stbtt_Rasterize(&gbm, 0.35f, vertices, num_verts, scale_x, scale_y, shift_x, shift_y, ix0, iy0, 1, cast(void*)info.userdata); // alas
    }
  }
  STBTT_xfree(vertices);
  return gbm.pixels;
}

public ubyte* stbtt_GetGlyphBitmap (const(stbtt_fontinfo)* info, float scale_x, float scale_y, int glyph, int* width, int* height, int* xoff, int* yoff) {
  return stbtt_GetGlyphBitmapSubpixel(info, scale_x, scale_y, 0.0f, 0.0f, glyph, width, height, xoff, yoff);
}

public void stbtt_MakeGlyphBitmapSubpixel (const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int glyph) {
  int ix0, iy0;
  stbtt_vertex* vertices;
  int num_verts = stbtt_GetGlyphShape(info, glyph, &vertices);
  stbtt__bitmap gbm;

  stbtt_GetGlyphBitmapBoxSubpixel(info, glyph, scale_x, scale_y, shift_x, shift_y, &ix0, &iy0, null, null);
  gbm.pixels = output;
  gbm.w = out_w;
  gbm.h = out_h;
  gbm.stride = out_stride;

  if (gbm.w && gbm.h) stbtt_Rasterize(&gbm, 0.35f, vertices, num_verts, scale_x, scale_y, shift_x, shift_y, ix0, iy0, 1, cast(void*)info.userdata); // alas

  STBTT_xfree(vertices);
}

public void stbtt_MakeGlyphBitmap (const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int glyph) {
  stbtt_MakeGlyphBitmapSubpixel(info, output, out_w, out_h, out_stride, scale_x, scale_y, 0.0f, 0.0f, glyph);
}

public ubyte* stbtt_GetCodepointBitmapSubpixel (const(stbtt_fontinfo)* info, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint, int* width, int* height, int* xoff, int* yoff) {
  return stbtt_GetGlyphBitmapSubpixel(info, scale_x, scale_y, shift_x, shift_y, stbtt_FindGlyphIndex(info, codepoint), width, height, xoff, yoff);
}

public void stbtt_MakeCodepointBitmapSubpixel (const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint) {
  stbtt_MakeGlyphBitmapSubpixel(info, output, out_w, out_h, out_stride, scale_x, scale_y, shift_x, shift_y, stbtt_FindGlyphIndex(info, codepoint));
}

public ubyte* stbtt_GetCodepointBitmap (const(stbtt_fontinfo)* info, float scale_x, float scale_y, int codepoint, int* width, int* height, int* xoff, int* yoff) {
  return stbtt_GetCodepointBitmapSubpixel(info, scale_x, scale_y, 0.0f, 0.0f, codepoint, width, height, xoff, yoff);
}

public void stbtt_MakeCodepointBitmap (const(stbtt_fontinfo)* info, ubyte* output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int codepoint) {
  stbtt_MakeCodepointBitmapSubpixel(info, output, out_w, out_h, out_stride, scale_x, scale_y, 0.0f, 0.0f, codepoint);
}


//////////////////////////////////////////////////////////////////////////////
//
// font name matching -- recommended not to use this
//

// check if a utf8 string contains a prefix which is the utf16 string; if so return length of matching utf8 string
size_t stbtt__CompareUTF8toUTF16_bigendian_prefix (const(ubyte)[] s1, const(ubyte)[] s2) {
  size_t i = 0;
  // convert utf16 to utf8 and compare the results while converting
  while (s2.length) {
    if (s2.length < 2) return -1;
    ushort ch = s2[0]*256+s2[1];
    if (ch < 0x80) {
      if (i >= s1.length) return -1;
      if (s1[i++] != ch) return -1;
    } else if (ch < 0x800) {
      if (i+1 >= s1.length) return -1;
      if (s1[i++] != 0xc0+(ch>>6)) return -1;
      if (s1[i++] != 0x80+(ch&0x3f)) return -1;
    } else if (ch >= 0xd800 && ch < 0xdc00) {
      uint c;
      ushort ch2 = s2[2]*256+s2[3];
      if (i+3 >= s1.length) return -1;
      c = ((ch-0xd800)<<10)+(ch2-0xdc00)+0x10000;
      if (s1[i++] != 0xf0+(c>>18)) return -1;
      if (s1[i++] != 0x80+((c>>12)&0x3f)) return -1;
      if (s1[i++] != 0x80+((c>>6)&0x3f)) return -1;
      if (s1[i++] != 0x80+((c)&0x3f)) return -1;
      //s2 += 2; // plus another 2 below
      //len2 -= 2;
      s2 = s2[2..$];
    } else if (ch >= 0xdc00 && ch < 0xe000) {
      return -1;
    } else {
      if (i+2 >= s1.length) return -1;
      if (s1[i++] != 0xe0+(ch>>12)) return -1;
      if (s1[i++] != 0x80+((ch>>6)&0x3f)) return -1;
      if (s1[i++] != 0x80+((ch)&0x3f)) return -1;
    }
    //s2 += 2;
    //len2 -= 2;
    s2 = s2[2..$];
  }
  return i;
}

public bool stbtt_CompareUTF8toUTF16_bigendian (const(char)[] s1, const(char)[] s2) {
  return (s1.length == stbtt__CompareUTF8toUTF16_bigendian_prefix(cast(const(ubyte)[])s1, cast(const(ubyte)[])s2)*2);
}

// returns results in whatever encoding you request... but note that 2-byte encodings
// will be BIG-ENDIAN... use stbtt_CompareUTF8toUTF16_bigendian() to compare
public const(char)[] stbtt_GetFontNameString (const(stbtt_fontinfo)* font, int platformID, int encodingID, int languageID, int nameID) {
  int count, stringOffset;
  const(ubyte)* fc = font.data;
  uint offset = font.fontstart;
  uint nm = stbtt__find_table(fc, offset, "name");
  if (!nm) return null;
  count = ttUSHORT(fc+nm+2);
  stringOffset = nm+ttUSHORT(fc+nm+4);
  foreach (immutable int i; 0..count) {
    uint loc = nm+6+12*i;
    if (platformID == ttUSHORT(fc+loc+0) && encodingID == ttUSHORT(fc+loc+2) &&
        languageID == ttUSHORT(fc+loc+4) && nameID == ttUSHORT(fc+loc+6)) {
      //*length = ttUSHORT(fc+loc+8);
      //return cast(const(char)*)(fc+stringOffset+ttUSHORT(fc+loc+10));
      int len = ttUSHORT(fc+loc+8);
      int pos = stringOffset+ttUSHORT(fc+loc+10);
      return cast(const(char)[])fc[pos..pos+len];
    }
  }
  return null;
}

bool stbtt__matchpair (const(ubyte)* fc, uint nm, const(ubyte)* name, int nlen, int target_id, int next_id) {
  int count = ttUSHORT(fc+nm+2);
  int stringOffset = nm+ttUSHORT(fc+nm+4);
  foreach (immutable int i; 0..count) {
    uint loc = nm+6+12*i;
    int id = ttUSHORT(fc+loc+6);
    if (id == target_id) {
      // find the encoding
      int platform = ttUSHORT(fc+loc+0), encoding = ttUSHORT(fc+loc+2), language = ttUSHORT(fc+loc+4);
      // is this a Unicode encoding?
      if (platform == 0 || (platform == 3 && encoding == 1) || (platform == 3 && encoding == 10)) {
        int slen = ttUSHORT(fc+loc+8);
        int off = ttUSHORT(fc+loc+10);
        // check if there's a prefix match
        int matchlen = stbtt__CompareUTF8toUTF16_bigendian_prefix(name[0..nlen], (fc+stringOffset+off)[0..slen]);
        if (matchlen >= 0) {
          // check for target_id+1 immediately following, with same encoding & language
          if (i+1 < count && ttUSHORT(fc+loc+12+6) == next_id && ttUSHORT(fc+loc+12) == platform && ttUSHORT(fc+loc+12+2) == encoding && ttUSHORT(fc+loc+12+4) == language) {
            slen = ttUSHORT(fc+loc+12+8);
            off = ttUSHORT(fc+loc+12+10);
            if (slen == 0) {
              if (matchlen == nlen) return true;
            } else if (matchlen < nlen && name[matchlen] == ' ') {
              ++matchlen;
              if (stbtt_CompareUTF8toUTF16_bigendian((cast(const(char*))(name+matchlen))[0..nlen-matchlen], (cast(const(char*))(fc+stringOffset+off))[0..slen])) return true;
            }
          } else {
            // if nothing immediately following
            if (matchlen == nlen) return true;
          }
        }
      }
      // @TODO handle other encodings
    }
  }
  return false;
}

bool stbtt__matches (const(ubyte)* fc, uint offset, const(ubyte)[] name, int flags) {
  //int nlen = cast(int)STBTT_strlen(cast(char*)name);
  if (name.length > int.max) return false;
  //int nlen = cast(int)name.length;
  uint nm, hd;
  if (!stbtt__isfont(fc+offset)) return false;

  // check italics/bold/underline flags in macStyle...
  if (flags) {
    hd = stbtt__find_table(fc, offset, "head");
    if ((ttUSHORT(fc+hd+44)&7) != (flags&7)) return false;
  }

  nm = stbtt__find_table(fc, offset, "name");
  if (!nm) return false;

  if (flags) {
    // if we checked the macStyle flags, then just check the family and ignore the subfamily
    if (stbtt__matchpair(fc, nm, name.ptr, cast(int)name.length, 16, -1)) return true;
    if (stbtt__matchpair(fc, nm, name.ptr, cast(int)name.length,  1, -1)) return true;
    if (stbtt__matchpair(fc, nm, name.ptr, cast(int)name.length,  3, -1)) return true;
  } else {
    if (stbtt__matchpair(fc, nm, name.ptr, cast(int)name.length, 16, 17)) return true;
    if (stbtt__matchpair(fc, nm, name.ptr, cast(int)name.length,  1,  2)) return true;
    if (stbtt__matchpair(fc, nm, name.ptr, cast(int)name.length,  3, -1)) return true;
  }

  return false;
}

public int stbtt_FindMatchingFont (const(ubyte)* font_collection, const(char)[] name_utf8, int flags) {
  for (int i = 0;;++i) {
    int off = stbtt_GetFontOffsetForIndex(font_collection, i);
    if (off < 0) return off;
    if (stbtt__matches(font_collection, off, cast(const(ubyte)[])name_utf8, flags)) return off;
  }
}


// FULL VERSION HISTORY
//
//   1.11 (2016-04-02) fix unused-variable warning
//   1.10 (2016-04-02) allow user-defined fabs() replacement
//                     fix memory leak if fontsize=0.0
//                     fix warning from duplicate typedef
//   1.09 (2016-01-16) warning fix; avoid crash on outofmem; use alloc userdata for PackFontRanges
//   1.08 (2015-09-13) document stbtt_Rasterize(); fixes for vertical & horizontal edges
//   1.07 (2015-08-01) allow PackFontRanges to accept arrays of sparse codepoints;
//                     allow PackFontRanges to pack and render in separate phases;
//                     fix stbtt_GetFontOFfsetForIndex (never worked for non-0 input?);
//                     fixed an assert() bug in the new rasterizer
//                     replace assert() with assert() in new rasterizer
//   1.06 (2015-07-14) performance improvements (~35% faster on x86 and x64 on test machine)
//                     also more precise AA rasterizer, except if shapes overlap
//                     remove need for STBTT_sort
//   1.05 (2015-04-15) fix misplaced definitions for STBTT_STATIC
//   1.04 (2015-04-15) typo in example
//   1.03 (2015-04-12) STBTT_STATIC, fix memory leak in new packing, various fixes
//   1.02 (2014-12-10) fix various warnings & compile issues w/ stb_rect_pack, C++
//   1.01 (2014-12-08) fix subpixel position when oversampling to exactly match
//                        non-oversampled; STBTT_POINT_SIZE for packed case only
//   1.00 (2014-12-06) add new PackBegin etc. API, w/ support for oversampling
//   0.99 (2014-09-18) fix multiple bugs with subpixel rendering (ryg)
//   0.9  (2014-08-07) support certain mac/iOS fonts without an MS platformID
//   0.8b (2014-07-07) fix a warning
//   0.8  (2014-05-25) fix a few more warnings
//   0.7  (2013-09-25) bugfix: subpixel glyph bug fixed in 0.5 had come back
//   0.6c (2012-07-24) improve documentation
//   0.6b (2012-07-20) fix a few more warnings
//   0.6  (2012-07-17) fix warnings; added stbtt_ScaleForMappingEmToPixels,
//                        stbtt_GetFontBoundingBox, stbtt_IsGlyphEmpty
//   0.5  (2011-12-09) bugfixes:
//                        subpixel glyph renderer computed wrong bounding box
//                        first vertex of shape can be off-curve (FreeSans)
//   0.4b (2011-12-03) fixed an error in the font baking example
//   0.4  (2011-12-01) kerning, subpixel rendering (tor)
//                    bugfixes for:
//                        codepoint-to-glyph conversion using table fmt=12
//                        codepoint-to-glyph conversion using table fmt=4
//                        stbtt_GetBakedQuad with non-square texture (Zer)
//                    updated Hello World! sample to use kerning and subpixel
//                    fixed some warnings
//   0.3  (2009-06-24) cmap fmt=12, compound shapes (MM)
//                    userdata, malloc-from-userdata, non-zero fill (stb)
//   0.2  (2009-03-11) Fix unsigned/signed char warnings
//   0.1  (2009-03-09) First public release
//
