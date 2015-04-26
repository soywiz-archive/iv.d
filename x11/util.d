module iv.x11.util is aliced;

import core.stdc.config;
import iv.x11.md;
import iv.x11.x11;
import iv.x11.xlib;
import iv.x11.region;
import iv.x11.resource : XrmStringToQuark;
import iv.x11.keysym;

extern(C) @trusted nothrow @nogc:

/*
 * Bitmask returned by XParseGeometry().  Each bit tells if the corresponding
 * value (x, y, width, height) was found in the parsed string.
 */
enum : int {
  NoValue     = 0x0000,
  XValue      = 0x0001,
  YValue      = 0x0002,
  WidthValue  = 0x0004,
  HeightValue = 0x0008,
  AllValues   = 0x000F,
  XNegative   = 0x0010,
  YNegative   = 0x0020,
}

/*
 * new version containing base_width, base_height, and win_gravity fields;
 * used with WM_NORMAL_HINTS.
 */
struct XSizeHints {
  c_long flags;      /* marks which fields in this structure are defined */
  int x, y;          /* obsolete for new window mgrs, but clients */
  int width, height; /* should set so old wm's don't mess up */
  int min_width, min_height;
  int max_width, max_height;
  int width_inc, height_inc;
  struct aspect {
    int x; /* numerator */
    int y; /* denominator */
  }
  aspect min_aspect, max_aspect;
  int base_width, base_height; /* added by ICCCM version 1 */
  int win_gravity;             /* added by ICCCM version 1 */
}

/*
 * The next block of definitions are for window manager properties that
 * clients and applications use for communication.
 */
/* flags argument in size hints */
enum {
  USPosition  = 1L<<0, /* user specified x, y */
  USSize      = 1L<<1, /* user specified width, height */

  PPosition   = 1L<<2, /* program specified position */
  PSize       = 1L<<3, /* program specified size */
  PMinSize    = 1L<<4, /* program specified minimum size */
  PMaxSize    = 1L<<5, /* program specified maximum size */
  PResizeInc  = 1L<<6, /* program specified resize increments */
  PAspect     = 1L<<7, /* program specified min and max aspect ratios */
  PBaseSize   = 1L<<8, /* program specified base for incrementing */
  PWinGravity = 1L<<9, /* program specified window gravity */
}

/* obsolete */
enum c_long PAllHints = (PPosition|PSize|PMinSize|PMaxSize|PResizeInc|PAspect);

struct XWMHints {
  c_long flags;       /* marks which fields in this structure are defined */
  Bool input;         /* does this application rely on the window manager to get keyboard input? */
  int nitial_state;   /* see below */
  Pixmap icon_pixmap; /* pixmap to be used as icon */
  Window icon_window; /* window to be used as icon */
  int icon_x, icon_y; /* initial position of icon */
  Pixmap icon_mask;   /* icon mask bitmap */
  XID window_group;   /* id of related window group */
  /* this structure may be extended in the future */
}

/* definition for flags of XWMHints */
enum {
  InputHint        = (1L<<0),
  StateHint        = (1L<<1),
  IconPixmapHint   = (1L<<2),
  IconWindowHint   = (1L<<3),
  IconPositionHint = (1L<<4),
  IconMaskHint     = (1L<<5),
  WindowGroupHint  = (1L<<6),
  AllHints         = (InputHint|StateHint|IconPixmapHint|IconWindowHint|IconPositionHint|IconMaskHint|WindowGroupHint),
  XUrgencyHint     = (1L<<8),
}

/* definitions for initial window state */
enum {
  WithdrawnState = 0, /* for windows that are not mapped */
  NormalState    = 1, /* most applications want to start this way */
  IconicState    = 3, /* application wants to start as an icon */
}

/*
 * Obsolete states no longer defined by ICCCM
 */
enum {
  DontCareState = 0, /* don't know or care */
  ZoomState     = 2, /* application wants to start zoomed */
  InactiveState = 4, /* application believes it is seldom used; */
}
/* some wm's may put it on inactive menu */


/*
 * new structure for manipulating TEXT properties; used with WM_NAME,
 * WM_ICON_NAME, WM_CLIENT_MACHINE, and WM_COMMAND.
 */
struct XTextProperty {
  ubyte* value;   /* same as Property routines */
  Atom encoding;  /* prop type */
  int format;     /* prop data format: 8, 16, or 32 */
  c_ulong nitems; /* number of data items in value */
}

enum int XNoMemory           = -1;
enum int XLocaleNotSupported = -2;
enum int XConverterNotFound  = -3;

alias XICCEncodingStyle = int;
enum {
  XStringStyle,       /* STRING */
  XCompoundTextStyle, /* COMPOUND_TEXT */
  XTextStyle,         /* text in owner's encoding (current locale) */
  XStdICCTextStyle,   /* STRING, else COMPOUND_TEXT */
  /* The following is an XFree86 extension, introduced in November 2000 */
  XUTF8StringStyle,   /* UTF8_STRING */
}

struct XIconSize {
  int min_width, min_height;
  int max_width, max_height;
  int width_inc, height_inc;
}

struct XClassHint {
  const(char)* res_name; // was `char*`
  const(char)* res_class; // was `char*`
}

version (XUTIL_DEFINE_FUNCTIONS) {
  int XDestroyImage (XImage* ximage);
  c_ulong XGetPixel (XImage *ximage, int x, int y);
  int XPutPixel (XImage* ximage, int x, int y, c_ulong pixel);
  XImage* XSubImage (XImage *ximage, int x, int y, uint width, uint height);
  int XAddPixel (XImage *ximage, c_long value);
} else {
  /*
   * These macros are used to give some sugar to the image routines so that
   * naive people are more comfortable with them.
   */
  /**
   * XDestroyImage
   * The XDestroyImage() function deallocates the memory associated with the XImage structure.
   * Note that when the image is created using XCreateImage(), XGetImage(), or XSubImage(), the destroy procedure that this macro calls frees both the image structure and the data pointed to by the image structure.
   * Params:
   *  ximage   = Specifies the image.
   * See_Also:
   *  XAddPixel(), XCreateImage(), XGetPixel(), XPutPixel(), XSubImage(), http://tronche.com/gui/x/xlib/utilities/manipulating-images.html
   */
  int XDestroyImage (XImage* ximage) { return ximage.f.destroy_image(ximage); }
  /**
   * XGetPixel
   * The XGetPixel() function returns the specified pixel from the named image. The pixel value is returned in normalized format (that is, the least-significant byte of the long is the least-significant byte of the pixel). The image must contain the x and y coordinates.
   * Params:
   *  ximage  = Specifies the image.
   *  x       = Specify the x coordinate.
   *  y       = Specify the y coordinate.
   * See_Also:
   *  XAddPixel(), XCreateImage(), XGetPixel(), XPutPixel(), XSubImage(), http://tronche.com/gui/x/xlib/utilities/manipulating-images.html
   */
  c_ulong XGetPixel (XImage* ximage, int x, int y) { return ximage.f.get_pixel(ximage, x, y); }
  /**
   * XPutPixel
   * The XPutPixel() function overwrites the pixel in the named image with the specified pixel value. The input pixel value must be in normalized format (that is, the least-significant byte of the long is the least-significant byte of the pixel). The image must contain the x and y coordinates.
   * Params:
   *  ximage  = Specifies the image.
   *  x       = Specify the x coordinate.
   *  y       = Specify the y coordinate.
   *  pixel   = Specifies the new pixel value.
   * See_Also:
   *  XAddPixel(), XCreateImage(), XGetPixel(), XPutPixel(), XSubImage(), http://tronche.com/gui/x/xlib/utilities/manipulating-images.html
   */
  int XPutPixel (XImage* ximage, int x, int y, c_ulong pixel) { return ximage.f.put_pixel(ximage, x, y, pixel); }
  /**
   * XSubImage
   * The XSubImage() function creates a new image that is a subsection of an existing one. It allocates the memory necessary for the new XImage structure and returns a pointer to the new image. The data is copied from the source image, and the image must contain the rectangle defined by x, y, subimage_width, and subimage_height.
   * Params:
   *  ximage          = Specifies the image.
   *  x               = Specify the x coordinate.
   *  y               = Specify the y coordinate.
   *  subimage_width  = Specifies the width of the new subimage, in pixels.
   *  subimage_height = Specifies the height of the new subimage, in pixels.
   * See_Also:
   *  XAddPixel(), XCreateImage(), XGetPixel(), XPutPixel(), XSubImage(), http://tronche.com/gui/x/xlib/utilities/manipulating-images.html
   */
  XImage XSubImage (XImage* ximage, int x, int y, uint width, uint height) { return ximage.f.sub_image(ximage, x, y, width, height); }
  /**
   * XAddPixel
   * The XAddPixel() function adds a constant value to every pixel in an image. It is useful when you have a base pixel value from allocating color resources and need to manipulate the image to that form.
   * Params:
   *  ximage          = Specifies the image.
   *  value           = Specifies the constant value that is to be added.
   * See_Also:
   *  XAddPixel(), XCreateImage(), XGetPixel(), XPutPixel(), XSubImage(), http://tronche.com/gui/x/xlib/utilities/manipulating-images.html
   */
  int XAddPixel (XImage* ximage, c_long value) { return ximage.f.add_pixel(ximage, value); }
}

/*
 * Compose sequence status structure, used in calling XLookupString.
 */
struct XComposeStatus {
  XPointer compose_ptr; /* state table pointer */
  int chars_matched;    /* match state */
}

/*
 * Keysym macros, used on Keysyms to test for classes of symbols
 */
//TODO
template IsKeypadKey (KeySym keysym) {
  enum IsKeypadKey = (keysym >= XK_KP_Space && keysym <= XK_KP_Equal);
}

template IsPrivateKeypadKey (KeySym keysym) {
  enum IsPrivateKeypadKey = (keysym >= 0x11000000 && keysym <= 0x1100FFFF);
}

template IsCursorKey (KeySym keysym) {
  enum IsCursorKey = (keysym >= XK_Home && keysym <  XK_Select);
}

template IsPFKey (KeySym keysym) {
  enum IsPFKey = (keysym >= XK_KP_F1 && keysym <= XK_KP_F4);
}

template IsFunctionKey (KeySym keysym) {
  enum IsFunctionKey = (keysym >= XK_F1 && keysym <= XK_F35);
}

template IsMiscFunctionKey (KeySym keysym) {
  enum IsMiscFunctionKey = (keysym >= XK_Select && keysym <= XK_Break);
}

template IsModifierKey (KeySym keysym) {
  enum IsModifierKey = (
    (keysym >= XK_Shift_L && keysym <= XK_Hyper_R) ||
    (keysym >= XK_ISO_Lock && keysym <= XK_ISO_Last_Group_Lock) ||
    (keysym == XK_Mode_switch) ||
    (keysym == XK_Num_Lock)
  );
}

/*
 * opaque reference to Region data type
 */
//alias Region = _XRegion*;

/* Return values from XRectInRegion() */
enum {
  RectangleOut  = 0,
  RectangleIn   = 1,
  RectanglePart = 2,
}


/*
 * Information used by the visual utility routines to find desired visual
 * type from the many visuals a display may support.
 */
struct XVisualInfo {
  Visual* visual;
  VisualID visualid;
  int screen;
  int depth;
  int c_class; /* C++ */;
  c_ulong red_mask;
  c_ulong green_mask;
  c_ulong blue_mask;
  int colormap_size;
  int bits_per_rgb;
}

enum {
  VisualNoMask           = 0x0,
  VisualIDMask           = 0x1,
  VisualScreenMask       = 0x2,
  VisualDepthMask        = 0x4,
  VisualClassMask        = 0x8,
  VisualRedMaskMask      = 0x10,
  VisualGreenMaskMask    = 0x20,
  VisualBlueMaskMask     = 0x40,
  VisualColormapSizeMask = 0x80,
  VisualBitsPerRGBMask   = 0x100,
  VisualAllMask          = 0x1FF,
}

/*
 * This defines a window manager property that clients may use to
 * share standard color maps of type RGB_COLOR_MAP:
 */
struct XStandardColormap{
  Colormap colormap;
  c_ulong red_max;
  c_ulong red_mult;
  c_ulong green_max;
  c_ulong green_mult;
  c_ulong blue_max;
  c_ulong blue_mult;
  c_ulong base_pixel;
  VisualID visualid; /* added by ICCCM version 1 */
  XID killid; /* added by ICCCM version 1 */
}

enum XID ReleaseByFreeingColormap = 1L; /* for killid field above */


/*
 * return codes for XReadBitmapFile and XWriteBitmapFile
 */
enum {
  BitmapSuccess     = 0,
  BitmapOpenFailed  = 1,
  BitmapFileInvalid = 2,
  BitmapNoMemory    = 3,
}

/*
 * Context Management
 */

/* Associative lookup table return codes */
enum {
  XCSUCCESS = 0, /* No error. */
  XCNOMEM   = 1, /* Out of memory */
  XCNOENT   = 2, /* No entry in table */
}

typedef XContext = int;

template XUniqueContext () {
  const XContext XUniqueContext = XrmUniqueQuark();
}

//TODO: const?
XContext XStringToContext (char* statement) { return cast(XContext)XrmStringToQuark(statement); }

/* The following declarations are alphabetized. */
XClassHint* XAllocClassHint ();
XIconSize* XAllocIconSize ();
XSizeHints* XAllocSizeHints ();
XStandardColormap* XAllocStandardColormap ();
XWMHints* XAllocWMHints ();
int XClipBox (XRegion r, XRectangle* rect_return);
XRegion XCreateRegion ();
char* XDefaultString ();
int XDeleteContext (Display* display, XID rid, XContext context);
int XDestroyRegion (XRegion r);
int XEmptyRegion (XRegion r);
int XEqualRegion (XRegion r1, XRegion r2);
int XFindContext (Display* display, XID rid, XContext context, XPointer* data_return);
Status XGetClassHint (Display* display, Window w, XClassHint* class_hints_return);
Status XGetIconSizes (Display* display, Window w, XIconSize** size_list_return, int* count_return);
Status XGetNormalHints (Display* display, Window w, XSizeHints* hints_return);
Status XGetRGBColormaps (Display* display, Window w, XStandardColormap** stdcmap_return, int* count_return, Atom property);
Status XGetSizeHints (Display* display, Window w, XSizeHints* hints_return, Atom property);
Status XGetStandardColormap (Display* display, Window w, XStandardColormap* colormap_return, Atom property);
Status XGetTextProperty (Display* display, Window window, XTextProperty* text_prop_return, Atom property);
XVisualInfo* XGetVisualInfo (Display* display, long vinfo_mask, XVisualInfo* vinfo_template, int* nitems_return);
Status XGetWMClientMachine (Display* display, Window w, XTextProperty* text_prop_return);
XWMHints *XGetWMHints (Display* display, Window w);
Status XGetWMIconName (Display* display, Window w, XTextProperty* text_prop_return);
Status XGetWMName (Display* display, Window w, XTextProperty* text_prop_return);
Status XGetWMNormalHints (Display* display, Window w, XSizeHints* hints_return, long* supplied_return);
Status XGetWMSizeHints (Display* display, Window w, XSizeHints* hints_return, long* supplied_return, Atom property);
Status XGetZoomHints (Display* display, Window w, XSizeHints* zhints_return);
int XIntersectRegion (XRegion sra, XRegion srb, XRegion dr_return);
void XConvertCase (KeySym sym, KeySym* lower, KeySym* upper);
int XLookupString (XKeyEvent* event_struct, char* buffer_return, int bytes_buffer, KeySym* keysym_return, XComposeStatus* status_in_out);
Status XMatchVisualInfo (Display* display, int screen, int depth, int cclass, XVisualInfo* vinfo_return);
int XOffsetRegion (XRegion r, int dx, int dy);
Bool XPointInRegion (XRegion r, int x, int y);
XRegion XPolygonRegion (iv.x11.xlib.XPoint* points, int n, int fill_rule);
int XRectInRegion (XRegion r, int x, int y, uint width, uint height);
int XSaveContext (Display* display, XID rid, XContext context, char* data);
int XSetClassHint (Display* display, Window w, XClassHint* class_hints);
int XSetIconSizes (Display* display, Window w, XIconSize* size_list, int count);
int XSetNormalHints (Display* display, Window w, XSizeHints* hints);
void XSetRGBColormaps (Display* display, Window w, XStandardColormap* stdcmaps, int count, Atom property);
int XSetSizeHints (Display* display, Window w, XSizeHints* hints, Atom property);
int XSetStandardProperties (Display* display, Window w, const(char)* window_name, const(char)* icon_name, Pixmap icon_pixmap, char** argv, int argc, XSizeHints* hints);
void XSetTextProperty (Display* display, Window w, XTextProperty* text_prop, Atom property);
void XSetWMClientMachine (Display* display, Window w, XTextProperty* text_prop);
int XSetWMHints (Display* display, Window w, XWMHints* wm_hints);
void XSetWMIconName (Display* display, Window w, XTextProperty* text_prop);
void XSetWMName (Display* display, Window w, XTextProperty* text_prop);
void XSetWMNormalHints (Display* display, Window w, XSizeHints* hints);
void XSetWMProperties (Display* display, Window w, XTextProperty* window_name, XTextProperty* icon_name, char** argv, int argc, XSizeHints* normal_hints, XWMHints* wm_hints, XClassHint* class_hints);
void XmbSetWMProperties (Display* display, Window w, const(char)* window_name, const(char)* icon_name, char** argv, int argc, XSizeHints* normal_hints, XWMHints* wm_hints, XClassHint* class_hints);
void Xutf8SetWMProperties (Display* display, Window w, const(char)* window_name, const(char)* icon_name, char** argv, int argc, XSizeHints* normal_hints, XWMHints* wm_hints, XClassHint* class_hints);
void XSetWMSizeHints (Display* display, Window w, XSizeHints* hints, Atom property);
int XSetRegion (Display* display, GC gc, XRegion r);
void XSetStandardColormap (Display* display, Window w, XStandardColormap* colormap, Atom property);
int XSetZoomHints (Display* display, Window w, XSizeHints* zhints);
int XShrinkRegion (XRegion r, int dx, int dy);
Status XStringListToTextProperty (char** list, int count, XTextProperty* text_prop_return);
int XSubtractRegion (XRegion sra, XRegion srb, XRegion dr_return);
int XmbTextListToTextProperty (Display* display, char** list, int count, XICCEncodingStyle style, XTextProperty* text_prop_return);
int XwcTextListToTextProperty (Display* display, widechar** list, int count, XICCEncodingStyle style, XTextProperty* text_prop_return);
int Xutf8TextListToTextProperty (Display* display, char** list, int count, XICCEncodingStyle style, XTextProperty* text_prop_return);
void XwcFreeStringList (widechar** list);
Status XTextPropertyToStringList (XTextProperty* text_prop, char*** list_return, int* count_return);
int XmbTextPropertyToTextList (Display* display, const XTextProperty* text_prop, char*** list_return, int* count_return);
int XwcTextPropertyToTextList (Display* display, const(XTextProperty)* text_prop, widechar*** list_return, int* count_return);
int Xutf8TextPropertyToTextList (Display* display, const(XTextProperty)* text_prop, char*** list_return, int* count_return);
int XUnionRectWithRegion (XRectangle* rectangle, XRegion src_region, XRegion dest_region_return);
int XUnionRegion (XRegion sra, XRegion srb, XRegion dr_return);
int XWMGeometry (Display* display, int screen_number, char* user_geometry, char* default_geometry, uint border_width,
  XSizeHints* hints, int* x_return, int* y_return, int* width_return, int* height_return, int* gravity_return);
int XXorRegion (XRegion sra, XRegion srb, XRegion dr_return);
