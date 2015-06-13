module iv.x11.xlib is aliced;
pragma(lib, "X11");

import core.stdc.config : c_long, c_ulong;
import core.stdc.stddef : wchar_t;

import iv.x11.md;
import iv.x11.x11;

extern (C) @trusted nothrow @nogc:

enum int XlibSpecificationRelease = 6;
enum int X_HAVE_UTF8_STRING       = 1;

alias XPointer = char*;
alias Status = int;

alias Bool = int;
enum { False, True }

alias QueueMode = int;
enum {
  QueuedAlready,
  QueuedAfterReading,
  QueuedAfterFlush
}

int ConnectionNumber() (Display* dpy) { return dpy.fd; }
Window RootWindow() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).root; }
int DefaultScreen() (Display* dpy) { return dpy.default_screen; }
Window DefaultRootWindow() (Display* dpy) { return ScreenOfDisplay( dpy,DefaultScreen( dpy ) ).root; }
Visual* DefaultVisual() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).root_visual; }
GC DefaultGC() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).default_gc; }
uint BlackPixel() (Display* dpy,int scr) { return cast(uint)ScreenOfDisplay( dpy,scr ).black_pixel; }
uint WhitePixel() (Display* dpy,int scr) { return cast(uint)ScreenOfDisplay( dpy,scr ).white_pixel; }
c_ulong AllPlanes() ( ) { return 0xFFFFFFFF; }
int QLength() (Display* dpy) { return dpy.qlen; }
int DisplayWidth() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).width; }
int DisplayHeight() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).height; }
int DisplayWidthMM() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).mwidth; }
int DisplayHeightMM() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).mheight; }
int DisplayPlanes() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).root_depth; }
int DisplayCells() (Display* dpy,int scr) { return DefaultVisual( dpy,scr ).map_entries; }
int ScreenCount() (Display* dpy) { return dpy.nscreens; }
const(char)* ServerVendor() (Display* dpy) { return dpy.vendor; }
int ProtocolVersion() (Display* dpy) { return dpy.proto_major_version; }
int ProtocolRevision() (Display* dpy) { return dpy.proto_minor_version; }
int VendorRelease() (Display* dpy) { return dpy.release; }
const(char)* DisplayString() (Display* dpy) { return dpy.display_name; }
int DefaultDepth() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).root_depth; }
Colormap DefaultColormap() (Display* dpy,int scr) { return ScreenOfDisplay( dpy,scr ).cmap; }
int BitmapUnit() (Display* dpy) { return dpy.bitmap_unit; }
int BitmapBitOrder() (Display* dpy) { return dpy.bitmap_bit_order; }
int BitmapPad() (Display* dpy) { return dpy.bitmap_pad; }
int ImagecharOrder() (Display* dpy) { return dpy.char_order; }
uint NextRequest() (Display* dpy) { return cast(uint)dpy.request + 1; }
uint LastKnownRequestProcessed() (Display* dpy) { return cast(uint)dpy.last_request_read; }

/* macros for screen oriented applications ( toolkit ) */
Screen* ScreenOfDisplay() (Display* dpy,int scr) { return &dpy.screens[scr]; }
Screen* DefaultScreenOfDisplay() (Display* dpy) { return ScreenOfDisplay( dpy,DefaultScreen( dpy ) ); }
Display* DisplayOfScreen() (Screen s) { return s.display; }
Window RootWindowOfScreen() (Screen s) { return s.root; }
uint BlackPixelOfScreen() (Screen s) { return cast(uint)s.black_pixel; }
uint WhitePixelOfScreen() (Screen s) { return cast(uint)s.white_pixel; }
Colormap DefaultColormapOfScreen() (Screen s) { return s.cmap; }
int DefaultDepthOfScreen() (Screen s) { return s.root_depth; }
GC DefaultGCOfScreen() (Screen s) { return s.default_gc; }
Visual* DefaultVisualOfScreen() (Screen s) { return s.root_visual; }
int WidthOfScreen() (Screen s) { return s.width; }
int HeightOfScreen() (Screen s) { return s.height; }
int WidthMMOfScreen() (Screen s) { return s.mwidth; }
int HeightMMOfScreen() (Screen s) { return s.mheight; }
int PlanesOfScreen() (Screen s) { return s.root_depth; }
int CellsOfScreen() (Screen s) { return DefaultVisualOfScreen( s ).map_entries; }
int MinCmapsOfScreen() (Screen s) { return s.min_maps; }
int MaxCmapsOfScreen() (Screen s) { return s.max_maps; }
Bool DoesSaveUnders() (Screen s) { return s.save_unders; }
int DoesBackingStore() (Screen s) { return s.backing_store; }
long EventMaskOfScreen() (Screen s) { return s.root_input_mask; }

/*
 * Extensions need a way to hang private data on some structures.
 */
struct XExtData {
  int number;            /* number returned by XRegisterExtension */
  XExtData* next;        /* next item on list of data for structure */
  extern(C) @trusted nothrow @nogc int function (XExtData *extension) free_private; /* called to free private storage */
  XPointer private_data; /* data private to this extension. */
}

/*
 * This file contains structures used by the extension mechanism.
 */
/* public to extension, cannot be changed */
struct XExtCodes {
  int extension;    /* extension number */
  int major_opcode; /* major op-code assigned by server */
  int first_event;  /* first event number for the extension */
  int first_error;  /* first error number for the extension */
}

/*
 * Data structure for retrieving info about pixmap formats.
 */
struct XPixmapFormatValues {
  int depth;
  int bits_per_pixel;
  int scanline_pad;
}

/*
 * Data structure for setting graphics context.
 */
struct XGCValues {
  int func;                /* logical operation */
  c_ulong plane_mask;      /* plane mask */
  c_ulong foreground;      /* foreground pixel */
  c_ulong background;      /* background pixel */
  int line_width;          /* line width */
  int line_style;          /* LineSolid; LineOnOffDash; LineDoubleDash */
  int cap_style;           /* CapNotLast; CapButt; CapRound; CapProjecting */
  int join_style;          /* JoinMiter; JoinRound; JoinBevel */
  int fill_style;          /* FillSolid; FillTiled; FillStippled; FillOpaeueStippled */
  int fill_rule;           /* EvenOddRule; WindingRule */
  int arc_mode;            /* ArcChord; ArcPieSlice */
  Pixmap tile;             /* tile pixmap for tiling operations */
  Pixmap stipple;          /* stipple 1 plane pixmap for stipping */
  int ts_x_origin;         /* offset for tile or stipple operations */
  int ts_y_origin;
  Font font;               /* default text font for text operations */
  int subwindow_mode;      /* ClipByChildren; IncludeInferiors */
  Bool graphics_exposures; /* boolean; should exposures be generated */
  int clip_x_origin;       /* origin for clipping */
  int clip_y_origin;
  Pixmap clip_mask;        /* bitmap clipping; other calls for rects */
  int dash_offset;         /* patterned/dashed line information */
  char dashes;
}
version (XLIB_ILLEGAL_ACCESS) {
  struct _XGC {
    XExtData* ext_data; /* hook for extension to hang data */
    GContext gid;       /* protocol ID for graphics context */
    /* there is more to this structure, but it is private to Xlib */
  }
} else {
  struct _XGC;
}

alias GC = _XGC*;

/*
 * Visual structure; contains information about colormapping possible.
 */
struct Visual {
  XExtData* ext_data; /* hook for extension to hang data */
  VisualID visualid;  /* visual id of this visual */
  int c_class;        /* class of screen (monochrome, etc.) */
  c_ulong  red_mask, green_mask, blue_mask; /* mask values */
  int bits_per_rgb;   /* log base 2 of distinct color values */
  int map_entries;    /* color map entries */
}

/*
 * Depth structure; contains information for each possible depth.
 */
struct Depth {
  int depth;       /* this depth (Z) of the depth */
  int nvisuals;    /* number of Visual types at this depth */
  Visual* visuals; /* list of visuals possible at this depth */
}

alias XDisplay = Display;

struct Screen {
  XExtData* ext_data;     /* hook for extension to hang data */
  XDisplay* display;      /* back pointer to display structure */
  Window root;            /* Root window id. */
  int width, height;      /* width and height of screen */
  int mwidth, mheight;    /* width and height of  in millimeters */
  int ndepths;            /* number of depths possible */
  Depth* depths;          /* list of allowable depths on the screen */
  int root_depth;         /* bits per pixel */
  Visual* root_visual;    /* root visual */
  GC default_gc;          /* GC for the root root visual */
  Colormap cmap;          /* default color map */
  c_ulong  white_pixel;
  c_ulong  black_pixel;   /* White and Black pixel values */
  int max_maps, min_maps; /* max and min color maps */
  int backing_store;      /* Never, WhenMapped, Always */
  Bool save_unders;
  c_long root_input_mask; /* initial root input mask */
}

/*
 * Format structure; describes ZFormat data the screen will understand.
 */
struct ScreenFormat {
  XExtData* ext_data; /* hook for extension to hang data */
  int depth;          /* depth of this image format */
  int bits_per_pixel; /* bits/pixel at this depth */
  int scanline_pad;   /* scanline must padded to this multiple */
}

/*
 * Data structure for setting window attributes.
 */
struct XSetWindowAttributes {
  Pixmap background_pixmap;     /* background or None or ParentRelative */
  c_ulong  background_pixel;    /* background pixel */
  Pixmap border_pixmap;         /* border of the window */
  c_ulong  border_pixel;        /* border pixel value */
  int bit_gravity;              /* one of bit gravity values */
  int win_gravity;              /* one of the window gravity values */
  int backing_store;            /* NotUseful, WhenMapped, Always */
  c_ulong  backing_planes;      /* planes to be preseved if possible */
  c_ulong  backing_pixel;       /* value to use in restoring planes */
  Bool save_under;              /* should bits under be saved? (popups) */
  c_long event_mask;            /* set of events that should be saved */
  c_long do_not_propagate_mask; /* set of events that should not propagate */
  Bool override_redirect;       /* boolean value for override-redirect */
  Colormap colormap;            /* color map to be associated with window */
  Cursor cursor;                /* cursor to be displayed (or None) */
}

struct XWindowAttributes {
    int x, y;                     /* location of window */
    int width, height;            /* width and height of window */
    int border_width;             /* border width of window */
    int depth;                    /* depth of window */
    Visual* visual;               /* the associated visual structure */
    Window root;                  /* root of screen containing window */
    int c_class;                  /* InputOutput, InputOnly */
    int bit_gravity;              /* one of bit gravity values */
    int win_gravity;              /* one of the window gravity values */
    int backing_store;            /* NotUseful, WhenMapped, Always */
    c_ulong  backing_planes;      /* planes to be preserved if possible */
    c_ulong  backing_pixel;       /* value to be used when restoring planes */
    Bool save_under;              /* boolean, should bits under be saved? */
    Colormap colormap;            /* color map to be associated with window */
    Bool map_installed;           /* boolean, is color map currently installed */
    int map_state;                /* IsUnmapped, IsUnviewable, IsViewable */
    c_long all_event_masks;       /* set of events all people have interest in */
    c_long your_event_mask;       /* my event mask */
    c_long do_not_propagate_mask; /* set of events that should not propagate */
    Bool override_redirect;       /* boolean value for override-redirect */
    Screen* screen;               /* back pointer to correct screen */
}

/*
 * Data structure for host setting; getting routines.
 *
 */
struct XHostAddress {
  int family;    /* for example FamilyInternet */
  int length;    /* length of address, in chars */
  char* address; /* pointer to where to find the chars */
}

/*
 * Data structure for ServerFamilyInterpreted addresses in host routines
 */
struct XServerInterpretedAddress {
  int typelength;  /* length of type string, in chars */
  int valuelength; /* length of value string, in chars */
  char* type;      /* pointer to where to find the type string */
  char* value;     /* pointer to where to find the address */
}

struct XImage {
  int width, height;    /* size of image */
  int xoffset;          /* number of pixels offset in X direction */
  int format;           /* XYBitmap, XYPixmap, ZPixmap */
  char* data;           /* pointer to image data */
  int char_order;       /* data char order, LSBFirst, MSBFirst */
  int bitmap_unit;      /* quant. of scanline 8, 16, 32 */
  int bitmap_bit_order; /* LSBFirst, MSBFirst */
  int bitmap_pad;       /* 8, 16, 32 either XY or ZPixmap */
  int depth;            /* depth of image */
  int chars_per_line;   /* accelarator to next line */
  int bits_per_pixel;   /* bits per pixel (ZPixmap) */
  c_ulong  red_mask;    /* bits in z arrangment */
  c_ulong  green_mask;
  c_ulong  blue_mask;
  XPointer obdata;      /* hook for the object routines to hang on */
  /* image manipulation routines */
  static struct F {
    extern (C) @trusted nothrow @nogc:
    XImage* function (XDisplay* display, Visual* visual, uint depth, int format, int offset, char* data, uint width, uint height, int bitmap_pad, int chars_per_line) create_image;
    int function (XImage*) destroy_image;
    c_ulong function (XImage*, int, int) get_pixel;
    int function (XImage*, int, int, c_ulong ) put_pixel;
    XImage function (XImage*, int, int, uint, uint) sub_image;
    int function (XImage*, c_long) add_pixel;
  }
  F f;
}

/*
 * Data structure for XReconfigureWindow
 */
struct XWindowChanges {
  int x, y;
  int width, height;
  int border_width;
  Window sibling;
  int stack_mode;
}


/*
 * Data structure used by color operations
 */
struct XColor {
  c_ulong pixel;
  ushort red, green, blue;
  char flags; /* do_red, do_green, do_blue */
  char pad;
}

/*
 * Data structures for graphics operations.  On most machines, these are
 * congruent with the wire protocol structures, so reformatting the data
 * can be avoided on these architectures.
 */
struct XSegment {
  short x1, y1, x2, y2;
}

struct XPoint {
  short x, y;
}

struct XRectangle {
  short x, y;
  ushort width, height;
}

struct XArc {
  short x, y;
  ushort width, height;
  short angle1, angle2;
}

/* Data structure for XChangeKeyboardControl */
struct XKeyboardControl {
  int key_click_percent;
  int bell_percent;
  int bell_pitch;
  int bell_duration;
  int led;
  int led_mode;
  int key;
  int auto_repeat_mode; /* On, Off, Default */
}

/* Data structure for XGetKeyboardControl */
struct XKeyboardState {
  int key_click_percent;
  int bell_percent;
  uint bell_pitch, bell_duration;
  c_ulong led_mask;
  int global_auto_repeat;
  char[32] auto_repeats;
}

/* Data structure for XGetMotionEvents. */
struct XTimeCoord {
  Time time;
  short x, y;
}

/* Data structure for X{Set,Get}ModifierMapping */
struct XModifierKeymap {
  int max_keypermod;    /* The server's max # of keys per modifier */
  KeyCode* modifiermap; /* An 8 by max_keypermod array of modifiers */
}


/*
 * Display datatype maintaining display specific data.
 * The contents of this structure are implementation dependent.
 * A Display should be treated as opaque by application code.
 */

struct _XPrivate; /* Forward declare before use for C++ */
struct _XrmHashBucketRec;

struct _XDisplay {
  XExtData* ext_data;          /* hook for extension to hang data */
  _XPrivate* private1;
  int fd;                      /* Network socket. */
  int private2;
  int proto_major_version;     /* major version of server's X protocol */
  int proto_minor_version;     /* minor version of servers X protocol */
  char* vendor;                /* vendor of the server hardware */
  XID private3;
  XID private4;
  XID private5;
  int private6;
  extern (C) @trusted nothrow @nogc XID function(_XDisplay*) resource_alloc; /* allocator function */
  int char_order;              /* screen char order, LSBFirst, MSBFirst */
  int bitmap_unit;             /* padding and data requirements */
  int bitmap_pad;              /* padding requirements on bitmaps */
  int bitmap_bit_order;        /* LeastSignificant or MostSignificant */
  int nformats;                /* number of pixmap formats in list */
  ScreenFormat* pixmap_format; /* pixmap format list */
  int private8;
  int release;                 /* release of the server */
  _XPrivate* private9, private10;
  int qlen;                    /* Length of input event queue */
  c_ulong  last_request_read;  /* seq number of last event read */
  c_ulong  request;            /* sequence number of last request. */
  XPointer private11;
  XPointer private12;
  XPointer private13;
  XPointer private14;
  uint max_request_size;       /* maximum number 32 bit words in request*/
  _XrmHashBucketRec* db;
  extern (C) @trusted nothrow @nogc int function (_XDisplay*) private15;
  char* display_name;          /* "host:display" string used on this connect*/
  int default_screen;          /* default screen for operations */
  int nscreens;                /* number of screens on this server*/
  Screen* screens;             /* pointer to list of screens */
  c_ulong motion_buffer;       /* size of motion buffer */
  c_ulong private16;
  int min_keycode;             /* minimum defined keycode */
  int max_keycode;             /* maximum defined keycode */
  XPointer private17;
  XPointer private18;
  int private19;
  char* xdefaults;             /* contents of defaults from server */
  /* there is more to this structure, but it is private to Xlib */
}
alias Display = _XDisplay;
alias _XPrivDisplay = _XDisplay*;

struct XKeyEvent {
  int type;           /* of event */
  c_ulong  serial;    /* # of last request processed by server */
  Bool send_event;    /* true if this came from a SendEvent request */
  Display* display;   /* Display the event was read from */
  Window window;      /* "event" window it is reported relative to */
  Window root;        /* root window that the event occurred on */
  Window subwindow;   /* child window */
  Time time;          /* milliseconds */
  int x, y;           /* pointer x, y coordinates in event window */
  int x_root, y_root; /* coordinates relative to root */
  uint state;         /* key or button mask */
  uint keycode;       /* detail */
  Bool same_screen;   /* same screen flag */
}

alias XKeyPressedEvent = XKeyEvent;
alias XKeyReleasedEvent = XKeyEvent;

struct XButtonEvent {
  int type;           /* of event */
  c_ulong  serial;    /* # of last request processed by server */
  Bool send_event;    /* true if this came from a SendEvent request */
  Display* display;   /* Display the event was read from */
  Window window;      /* "event" window it is reported relative to */
  Window root;        /* root window that the event occurred on */
  Window subwindow;   /* child window */
  Time time;          /* milliseconds */
  int x, y;           /* pointer x, y coordinates in event window */
  int x_root, y_root; /* coordinates relative to root */
  uint state;         /* key or button mask */
  uint button;        /* detail */
  Bool same_screen;   /* same screen flag */
}
alias XButtonPressedEvent = XButtonEvent;
alias XButtonReleasedEvent = XButtonEvent;

struct XMotionEvent {
  int type;           /* of event */
  c_ulong serial;     /* # of last request processed by server */
  Bool send_event;    /* true if this came from a SendEvent request */
  Display* display;   /* Display the event was read from */
  Window window;      /* "event" window reported relative to */
  Window root;        /* root window that the event occurred on */
  Window subwindow;   /* child window */
  Time time;          /* milliseconds */
  int x, y;           /* pointer x, y coordinates in event window */
  int x_root, y_root; /* coordinates relative to root */
  uint state;         /* key or button mask */
  char is_hint;       /* detail */
  Bool same_screen;   /* same screen flag */
}
alias XPointerMovedEvent = XMotionEvent;

struct XCrossingEvent {
  int type;           /* of event */
  c_ulong serial;     /* # of last request processed by server */
  Bool send_event;    /* true if this came from a SendEvent request */
  Display* display;   /* Display the event was read from */
  Window window;      /* "event" window reported relative to */
  Window root;        /* root window that the event occurred on */
  Window subwindow;   /* child window */
  Time time;          /* milliseconds */
  int x, y;           /* pointer x, y coordinates in event window */
  int x_root, y_root; /* coordinates relative to root */
  int mode;           /* NotifyNormal, NotifyGrab, NotifyUngrab */
  int detail;
 /*
  * NotifyAncestor, NotifyVirtual, NotifyInferior,
  * NotifyNonlinear,NotifyNonlinearVirtual
  */
  Bool same_screen;   /* same screen flag */
  Bool focus;         /* boolean focus */
  uint state;         /* key or button mask */
}
alias XEnterWindowEvent = XCrossingEvent;
alias XLeaveWindowEvent = XCrossingEvent;

struct XFocusChangeEvent {
  int type;           /* FocusIn or FocusOut */
  c_ulong serial;     /* # of last request processed by server */
  Bool send_event;    /* true if this came from a SendEvent request */
  Display* display;   /* Display the event was read from */
  Window window;      /* window of event */
  int mode;           /* NotifyNormal, NotifyWhileGrabbed,*/
  /* NotifyGrab, NotifyUngrab */
  int detail;
  /*
   * NotifyAncestor, NotifyVirtual, NotifyInferior,
   * NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
   * NotifyPointerRoot, NotifyDetailNone
  */
}
alias  XFocusInEvent = XFocusChangeEvent;
alias  XFocusOutEvent = XFocusChangeEvent;

 /* generated on EnterWindow and FocusIn  when KeyMapState selected */
struct XKeymapEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  char[32] key_vector;
}

struct XExposeEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  int x, y;
  int width, height;
  int count;        /* if non-zero, at least this many more */
}

struct XGraphicsExposeEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Drawable drawable;
  int x, y;
  int width, height;
  int count;        /* if non-zero, at least this many more */
  int major_code;   /* core is CopyArea or CopyPlane */
  int minor_code;   /* not defined in the core */
}

struct XNoExposeEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Drawable drawable;
  int major_code;   /* core is CopyArea or CopyPlane */
  int minor_code;   /* not defined in the core */
}

struct XVisibilityEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  int state;        /* Visibility state */
}

struct XCreateWindowEvent {
  int type;
  c_ulong serial;         /* # of last request processed by server */
  Bool send_event;        /* true if this came from a SendEvent request */
  Display* display;       /* Display the event was read from */
  Window parent;          /* parent of the window */
  Window window;          /* window id of window created */
  int x, y;               /* window location */
  int width, height;      /* size of window */
  int border_width;       /* border width */
  Bool override_redirect; /* creation should be overridden */
}

struct XDestroyWindowEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window event;
  Window window;
}

struct XUnmapEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window event;
  Window window;
  Bool from_configure;
}

struct XMapEvent {
  int type;
  c_ulong serial;         /* # of last request processed by server */
  Bool send_event;        /* true if this came from a SendEvent request */
  Display* display;       /* Display the event was read from */
  Window event;
  Window window;
  Bool override_redirect; /* boolean, is override set... */
}

struct XMapRequestEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window parent;
  Window window;
}

struct XReparentEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window event;
  Window window;
  Window parent;
  int x, y;
  Bool override_redirect;
}

struct XConfigureEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window event;
  Window window;
  int x, y;
  int width, height;
  int border_width;
  Window above;
  Bool override_redirect;
}

struct XGravityEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window event;
  Window window;
  int x, y;
}

struct XResizeRequestEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  int width, height;
}

struct XConfigureRequestEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window parent;
  Window window;
  int x, y;
  int width, height;
  int border_width;
  Window above;
  int detail;       /* Above, Below, TopIf, BottomIf, Opposite */
  uint value_mask;
}

struct XCirculateEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window event;
  Window window;
  int place;        /* PlaceOnTop, PlaceOnBottom */
}

struct XCirculateRequestEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window parent;
  Window window;
  int place;        /* PlaceOnTop, PlaceOnBottom */
}

struct XPropertyEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  Atom atom;
  Time time;
  int state;        /* NewValue, Deleted */
}

struct XSelectionClearEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  Atom selection;
  Time time;
}

struct XSelectionRequestEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window owner;
  Window requestor;
  Atom selection;
  Atom target;
  Atom property;
  Time time;
}

struct XSelectionEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window requestor;
  Atom selection;
  Atom target;
  Atom property;    /* ATOM or None */
  Time time;
}

struct XColormapEvent {
  int type;
  c_ulong serial;    /* # of last request processed by server */
  Bool send_event;   /* true if this came from a SendEvent request */
  Display* display;  /* Display the event was read from */
  Window window;
  Colormap colormap; /* COLORMAP or None */
  Bool c_new;        /* C++ */
  int state;         /* ColormapInstalled, ColormapUninstalled */
}

struct XClientMessageEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;
  Atom message_type;
  int format;
  union _data {
    char[20] b;
    short[10] s;
    c_long[5] l;
  }
  _data data;
}

struct XMappingEvent {
  int type;
  c_ulong serial;    /* # of last request processed by server */
  Bool send_event;   /* true if this came from a SendEvent request */
  Display* display;  /* Display the event was read from */
  Window window;     /* unused */
  int request;       /* one of MappingModifier, MappingKeyboard, MappingPointer */
  int first_keycode; /* first keycode */
  int count;         /* defines range of change w. first_keycode */
}

struct XErrorEvent {
  int type;
  Display* display;   /* Display the event was read from */
  XID resourceid;     /* resource id */
  c_ulong  serial;    /* serial number of failed request */
  ubyte error_code;   /* error code of failed request */
  ubyte request_code; /* Major op-code of failed request */
  ubyte minor_code;   /* Minor op-code of failed request */
}

struct XAnyEvent {
  int type;
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;  /* true if this came from a SendEvent request */
  Display* display; /* Display the event was read from */
  Window window;    /* window on which event was requested in event mask */
}


/***************************************************************
 *
 * GenericEvent.  This event is the standard event for all newer extensions.
 */

struct XGenericEvent {
  int type;         /* of event. Always GenericEvent */
  c_ulong serial;   /* # of last request processed */
  Bool send_event;  /* true if from SendEvent request */
  Display* display; /* Display the event was read from */
  int extension;    /* major opcode of extension that caused the event */
  int evtype;       /* actual event type. */
}

struct XGenericEventCookie {
  int type;         /* of event. Always GenericEvent */
  c_ulong serial;   /* # of last request processed */
  Bool send_event;  /* true if from SendEvent request */
  Display* display; /* Display the event was read from */
  int extension;    /* major opcode of extension that caused the event */
  int evtype;       /* actual event type. */
  uint cookie;
  void* data;
}

/*
 * this union is defined so Xlib can always use the same sized
 * event structure internally, to avoid memory fragmentation.
 */
union XEvent {
  int type; /* must not be changed; first element */
  XAnyEvent xany;
  XKeyEvent xkey;
  XButtonEvent xbutton;
  XMotionEvent xmotion;
  XCrossingEvent xcrossing;
  XFocusChangeEvent xfocus;
  XExposeEvent xexpose;
  XGraphicsExposeEvent xgraphicsexpose;
  XNoExposeEvent xnoexpose;
  XVisibilityEvent xvisibility;
  XCreateWindowEvent xcreatewindow;
  XDestroyWindowEvent xdestroywindow;
  XUnmapEvent xunmap;
  XMapEvent xmap;
  XMapRequestEvent xmaprequest;
  XReparentEvent xreparent;
  XConfigureEvent xconfigure;
  XGravityEvent xgravity;
  XResizeRequestEvent xresizerequest;
  XConfigureRequestEvent xconfigurerequest;
  XCirculateEvent xcirculate;
  XCirculateRequestEvent xcirculaterequest;
  XPropertyEvent xproperty;
  XSelectionClearEvent xselectionclear;
  XSelectionRequestEvent xselectionrequest;
  XSelectionEvent xselection;
  XColormapEvent xcolormap;
  XClientMessageEvent xclient;
  XMappingEvent xmapping;
  XErrorEvent xerror;
  XKeymapEvent xkeymap;
  XGenericEvent xgeneric;
  XGenericEventCookie xcookie;
  c_long[24] pad;
}

int XAllocID (Display* dpy) { return cast(int)dpy.resource_alloc(dpy); }

/*
 * per character font metric information.
 */
struct XCharStruct {
  short lbearing;    /* origin to left edge of raster */
  short rbearing;    /* origin to right edge of raster */
  short width;       /* advance to next char's origin */
  short ascent;      /* baseline to top edge of raster */
  short descent;     /* baseline to bottom edge of raster */
  ushort attributes; /* per char flags (not predefined) */
}

/*
 * To allow arbitrary information with fonts, there are additional properties
 * returned.
 */
struct XFontProp {
  Atom name;
  c_ulong card32;
}

struct XFontStruct {
  XExtData* ext_data;     /* hook for extension to hang data */
  Font fid;               /* Font id for this font */
  uint direction;         /* hint about direction the font is painted */
  uint min_char_or_char2; /* first character */
  uint max_char_or_char2; /* last character */
  uint min_char1;         /* first row that exists */
  uint max_char1;         /* last row that exists */
  Bool all_chars_exist;   /* flag if all characters have non-zero size */
  uint default_char;      /* char to print for undefined character */
  int n_properties;       /* how many properties there are */
  XFontProp* properties;  /* pointer to array of additional properties */
  XCharStruct min_bounds; /* minimum bounds over all existing char */
  XCharStruct max_bounds; /* maximum bounds over all existing char */
  XCharStruct* per_char;  /* first_char to last_char information */
  int ascent;             /* log. extent above baseline for spacing */
  int descent;            /* log. descent below baseline for spacing */
}

/*
 * PolyText routines take these as arguments.
 */
struct XTextItem {
  char* chars; /* pointer to string */
  int nchars;  /* number of characters */
  int delta;   /* delta between strings */
  Font font;   /* font to print it in, None don't change */
}

/* normal 16 bit characters are two chars */
align(1) struct XChar2b {
align(1):
  ubyte char1;
  ubyte char2;
}

struct XTextItem16 {
  XChar2b* chars; /* two char characters */
  int nchars;     /* number of characters */
  int delta;      /* delta between strings */
  Font font;      /* font to print it in, None don't change */
}

union XEDataObject {
  Display* display;
  GC gc;
  Visual* visual;
  Screen* screen;
  ScreenFormat* pixmap_format;
  XFontStruct* font;
}

struct XFontSetExtents{
  XRectangle max_ink_extent;
  XRectangle max_logical_extent;
}

/* unused:
 void (*XOMProc)();
 */

struct _XOM {}
struct _XOC {}
alias XOM = _XOM*;
alias XOC = _XOC*;
alias XFontSet = _XOC*;

struct XmbTextItem {
  char* chars;
  int nchars;
  int delta;
  XFontSet font_set;
}

struct XwcTextItem {
  wchar_t* chars;
  int nchars;
  int delta;
  XFontSet font_set;
}

immutable char* XNRequiredCharSet             = "requiredCharSet";
immutable char* XNQueryOrientation            = "queryOrientation";
immutable char* XNBaseFontName                = "baseFontName";
immutable char* XNOMAutomatic                 = "omAutomatic";
immutable char* XNMissingCharSet              = "missingCharSet";
immutable char* XNDefaultString               = "defaultString";
immutable char* XNOrientation                 = "orientation";
immutable char* XNDirectionalDependentDrawing = "directionalDependentDrawing";
immutable char* XNContextualDrawing           = "contextualDrawing";
immutable char* XNFontInfo                    = "fontInfo";

struct XOMCharSetList {
  int charset_count;
  char** charset_list;
}

alias XOrientation = int;
enum {
  XOMOrientation_LTR_TTB,
  XOMOrientation_RTL_TTB,
  XOMOrientation_TTB_LTR,
  XOMOrientation_TTB_RTL,
  XOMOrientation_Context,
}

struct XOMOrientation {
  int num_orientation;
  XOrientation* orientation; /* Input Text description */
}

struct XOMFontInfo{
  int num_font;
  XFontStruct **font_struct_list;
  char** font_name_list;
}

struct _XIM {}
struct _XIC {}
alias XIM = _XIM*;
alias XIC = _XIC*;

alias XIMProc = void function (
  XIM,
  XPointer,
  XPointer
);

alias XICProc = Bool function (
  XIC,
  XPointer,
  XPointer
);

alias XIDProc = void function (
  Display*,
  XPointer,
  XPointer
);

struct XIMStyles {
  ushort count_styles;
  XIMStyle* supported_styles;
}

alias XIMStyle = c_ulong;
enum : c_ulong {
  XIMPreeditArea      = 0x0001,
  XIMPreeditCallbacks = 0x0002,
  XIMPreeditPosition  = 0x0004,
  XIMPreeditNothing   = 0x0008,
  XIMPreeditNone      = 0x0010,
  XIMStatusArea       = 0x0100,
  XIMStatusCallbacks  = 0x0200,
  XIMStatusNothing    = 0x0400,
  XIMStatusNone       = 0x0800,
}

immutable char* XNVaNestedList = "XNVaNestedList";
immutable char* XNQueryInputStyle = "queryInputStyle";
immutable char* XNClientWindow = "clientWindow";
immutable char* XNInputStyle = "inputStyle";
immutable char* XNFocusWindow = "focusWindow";
immutable char* XNResourceName = "resourceName";
immutable char* XNResourceClass = "resourceClass";
immutable char* XNGeometryCallback = "geometryCallback";
immutable char* XNDestroyCallback = "destroyCallback";
immutable char* XNFilterEvents = "filterEvents";
immutable char* XNPreeditStartCallback = "preeditStartCallback";
immutable char* XNPreeditDoneCallback = "preeditDoneCallback";
immutable char* XNPreeditDrawCallback = "preeditDrawCallback";
immutable char* XNPreeditCaretCallback = "preeditCaretCallback";
immutable char* XNPreeditStateNotifyCallback = "preeditStateNotifyCallback";
immutable char* XNPreeditAttributes = "preeditAttributes";
immutable char* XNStatusStartCallback = "statusStartCallback";
immutable char* XNStatusDoneCallback = "statusDoneCallback";
immutable char* XNStatusDrawCallback = "statusDrawCallback";
immutable char* XNStatusAttributes = "statusAttributes";
immutable char* XNArea = "area";
immutable char* XNAreaNeeded = "areaNeeded";
immutable char* XNSpotLocation = "spotLocation";
immutable char* XNColormap = "colorMap";
immutable char* XNStdColormap = "stdColorMap";
immutable char* XNForeground = "foreground";
immutable char* XNBackground = "background";
immutable char* XNBackgroundPixmap = "backgroundPixmap";
immutable char* XNFontSet = "fontSet";
immutable char* XNLineSpace = "lineSpace";
immutable char* XNCursor = "cursor";

immutable char* XNQueryIMValuesList = "queryIMValuesList";
immutable char* XNQueryICValuesList = "queryICValuesList";
immutable char* XNVisiblePosition = "visiblePosition";
immutable char* XNR6PreeditCallback = "r6PreeditCallback";
immutable char* XNStringConversionCallback = "stringConversionCallback";
immutable char* XNStringConversion = "stringConversion";
immutable char* XNResetState = "resetState";
immutable char* XNHotKey = "hotKey";
immutable char* XNHotKeyState = "hotKeyState";
immutable char* XNPreeditState = "preeditState";
immutable char* XNSeparatorofNestedList = "separatorofNestedList";

enum int XBufferOverflow = -1;
enum int XLookupNone     = 1;
enum int XLookupChars    = 2;
enum int XLookupKeySym   = 3;
enum int XLookupBoth     = 4;

void* XVaNestedList;

struct XIMCallback {
  XPointer client_data;
  XIMProc callback;
}

struct XICCallback {
  XPointer client_data;
  XICProc callback;
}

alias XIMFeedback = int;
enum {
  XIMReverse           = 1,
  XIMUnderline         = (1<<1),
  XIMHighlight         = (1<<2),
  XIMPrimary           = (1<<5),
  XIMSecondary         = (1<<6),
  XIMTertiary          = (1<<7),
  XIMVisibleToForward  = (1<<8),
  XIMVisibleToBackword = (1<<9),
  XIMVisibleToCenter   = (1<<10),
}

struct XIMText {
  ushort length;
  XIMFeedback* feedback;
  Bool encoding_is_wchar;
  union c_string {
    char* multi_char;
    wchar_t* wide_char;
  }
}


alias XIMPreeditState = c_ulong;
enum {
  XIMPreeditUnKnown = 0,
  XIMPreeditEnable  = 1,
  XIMPreeditDisable = (1<<1),
}

struct XIMPreeditStateNotifyCallbackStruct {
  XIMPreeditState state;
}

alias XIMResetState = c_ulong;
enum {
  XIMInitialState  = 1,
  XIMPreserveState = 1<<1
}

alias XIMStringConversionFeedback = c_ulong;
enum {
  XIMStringConversionLeftEdge   = 0x00000001,
  XIMStringConversionRightEdge  = 0x00000002,
  XIMStringConversionTopEdge    = 0x00000004,
  XIMStringConversionBottomEdge = 0x00000008,
  XIMStringConversionConcealed  = 0x00000010,
  XIMStringConversionWrapped    = 0x00000020,
}

struct XIMStringConversionText{
  ushort length;
  XIMStringConversionFeedback* feedback;
  Bool encoding_is_wchar;
  union c_string{
    char* mbs;
    wchar_t* wcs;
  }
}

alias XIMStringConversionPosition = ushort;

alias XIMStringConversionType = ushort;
enum {
  XIMStringConversionBuffer = 0x0001,
  XIMStringConversionLine   = 0x0002,
  XIMStringConversionWord   = 0x0003,
  XIMStringConversionChar   = 0x0004,
}

alias XIMStringConversionOperation = ushort;
enum {
  XIMStringConversionSubstitution = 0x0001,
  XIMStringConversionRetrieval    = 0x0002,
}

alias XIMCaretDirection = int;
enum {
  XIMForwardChar, XIMBackwardChar,
  XIMForwardWord, XIMBackwardWord,
  XIMCaretUp,     XIMCaretDown,
  XIMNextLine,    XIMPreviousLine,
  XIMLineStart,   XIMLineEnd,
  XIMAbsolutePosition,
  XIMDontChange
}

struct XIMStringConversionCallbackStruct {
  XIMStringConversionPosition position;
  XIMCaretDirection direction;
  XIMStringConversionOperation operation;
  ushort factor;
  XIMStringConversionText* text;
}

struct XIMPreeditDrawCallbackStruct{
  int caret;      /* Cursor offset within pre-edit string */
  int chg_first;  /* Starting change position */
  int chg_length; /* Length of the change in character count */
  XIMText* text;
}

alias XIMCaretStyle = int;
enum {
  XIMIsInvisible, /* Disable caret feedback */
  XIMIsPrimary,   /* UI defined caret feedback */
  XIMIsSecondary  /* UI defined caret feedback */
}

struct XIMPreeditCaretCallbackStruct {
  int position;                /* Caret offset within pre-edit string */
  XIMCaretDirection direction; /* Caret moves direction */
  XIMCaretStyle style;         /* Feedback of the caret */
}

alias XIMStatusDataType = int;
enum {
  XIMTextType,
  XIMBitmapType
}

struct XIMStatusDrawCallbackStruct {
  XIMStatusDataType type;
  union data {
    XIMText* text;
    Pixmap bitmap;
  }
}

struct XIMHotKeyTrigger {
  KeySym keysym;
  int modifier;
  int modifier_mask;
}

struct XIMHotKeyTriggers {
  int num_hot_key;
  XIMHotKeyTrigger* key;
}

alias XIMHotKeyState = c_ulong;
enum : c_ulong {
  XIMHotKeyStateON  = 0x0001,
  XIMHotKeyStateOFF = 0x0002,
}

struct XIMValuesList {
  ushort count_values;
  char** supported_values;
}

version (Windows) {
  extern int *_Xdebug_p;
} else {
  extern int _Xdebug;
}

XFontStruct* XLoadQueryFont(
  Display* display,
  const(char)* name
);

XFontStruct* XQueryFont(
  Display* display,
  XID font_ID
);


XTimeCoord* XGetMotionEvents(
  Display* display,
  Window w,
  Time start,
  Time stop,
  int* nevents_return
);

XModifierKeymap* XDeleteModifiermapEntry(
  XModifierKeymap* modmap,
  KeyCode keycode_entry,
  int modifier
);

XModifierKeymap* XGetModifierMapping(
  Display* display
);

XModifierKeymap* XInsertModifiermapEntry(
  XModifierKeymap* modmap,
  KeyCode keycode_entry,
  int modifier
);

XModifierKeymap* XNewModifiermap(
  int max_keys_per_mod
);

XImage* XCreateImage(
  Display* display,
  Visual* visual,
  uint depth,
  int format,
  int offset,
  char* data,
  uint width,
  uint height,
  int bitmap_pad,
  int chars_per_line
);
Status XInitImage(
  XImage* image
);
XImage* XGetImage(
  Display* display,
  Drawable d,
  int x,
  int y,
  uint width,
  uint height,
  c_ulong plane_mask,
  int format
);
XImage* XGetSubImage(
  Display* display,
  Drawable d,
  int x,
  int y,
  uint width,
  uint height,
  c_ulong plane_mask,
  int format,
  XImage* dest_image,
  int dest_x,
  int dest_y
);

/*
 * X function declarations.
 */
Display* XOpenDisplay(
  const(char)*dpname=null /*display_name*/
);

void XrmInitialize( );

char* XFetchchars(
  Display* display,
  int* nchars_return
);
char* XFetchBuffer(
  Display* display,
  int* nchars_return,
  int buffer
);
char* XGetAtomName(
  Display* display,
  Atom atom
);
Status XGetAtomNames(
  Display* dpy,
  Atom* atoms,
  int count,
  char** names_return
);
char* XGetDefault(
  Display* display,
  char* program,
  char* option
);
char* XDisplayName(
  char* string
);
char* XKeysymToString(
  KeySym keysym
);

int function(
  Display* display
)XSynchronize(
  Display* display,
  Bool onoff
);
int function(
  Display* display
)XSetAfterFunction(
  Display* display,
  int function(
       Display* display
  ) procedure
);
Atom XInternAtom(
  Display* display,
  const(char)* atom_name,
  Bool only_if_exists
);
Status XInternAtoms(
  Display* dpy,
  const(const(char)*)* names,
  int count,
  Bool onlyIfExists,
  Atom* atoms_return
);
Colormap XCopyColormapAndFree(
  Display* display,
  Colormap colormap
);
Colormap XCreateColormap(
  Display* display,
  Window w,
  Visual* visual,
  int alloc
);
Cursor XCreatePixmapCursor(
  Display* display,
  Pixmap source,
  Pixmap mask,
  XColor* foreground_color,
  XColor* background_color,
  uint x,
  uint y
);
Cursor XCreateGlyphCursor(
  Display* display,
  Font source_font,
  Font mask_font,
  uint* source_char, //FIXME
  uint* mask_char, //FIXME
  XColor* foreground_color,
  XColor* background_color
);
Cursor XCreateFontCursor(
  Display* display,
  uint shape
);
Font XLoadFont(
  Display* display,
  const(char)* name
);
GC XCreateGC(
  Display* display,
  Drawable d,
  c_ulong valuemask,
  XGCValues* values
);
GContext XGContextFromGC(
  GC gc
);
void XFlushGC(
  Display* display,
  GC gc
);
Pixmap XCreatePixmap(
  Display* display,
  Drawable d,
  uint width,
  uint height,
  uint depth
);
Pixmap XCreateBitmapFromData(
  Display* display,
  Drawable d,
  const(char)* data,
  uint width,
  uint height
);
Pixmap XCreatePixmapFromBitmapData(
  Display* display,
  Drawable d,
  const(char)* data,
  uint width,
  uint height,
  c_ulong fg,
  c_ulong bg,
  uint depth
);
Window XCreateSimpleWindow(
  Display* display,
  Window parent,
  int x,
  int y,
  uint width,
  uint height,
  uint border_width,
  c_ulong border,
  uint background
);
Window XGetSelectionOwner(
  Display* display,
  Atom selection
);
Window XCreateWindow(
  Display* display,
  Window parent,
  int x,
  int y,
  uint width,
  uint height,
  uint border_width,
  int depth,
  uint klass,
  Visual* visual,
  c_ulong valuemask,
  XSetWindowAttributes* attributes
);
Colormap* XListInstalledColormaps(
  Display* display,
  Window w,
  int* num_return
);
char** XListFonts(
  Display* display,
  const(char)* pattern,
  int maxnames,
  int* actual_count_return
);
char* XListFontsWithInfo(
  Display* display,
  const(char)* pattern,
  int maxnames,
  int* count_return,
  XFontStruct** info_return
);
char** XGetFontPath(
  Display* display,
  int* npaths_return
);
char** XListExtensions(
  Display* display,
  int* nextensions_return
);
Atom* XListProperties(
  Display* display,
  Window w,
  int* num_prop_return
);
XHostAddress* XListHosts(
  Display* display,
  int* nhosts_return,
  Bool* state_return
);
KeySym XKeycodeToKeysym(
  Display* display,
  KeyCode keycode,
  int index
);
KeySym XLookupKeysym(
  XKeyEvent* key_event,
  int index
);
KeySym* XGetKeyboardMapping(
  Display* display,
  KeyCode first_keycode,
  int keycode_count,
  int* keysyms_per_keycode_return
);
KeySym XStringToKeysym(
  const(char)* string
);
c_long XMaxRequestSize(
  Display* display
);
c_long XExtendedMaxRequestSize(
  Display* display
);
char* XResourceManagerString(
  Display* display
);
char* XScreenResourceString(
  Screen* screen
);
c_ulong XDisplayMotionBufferSize(
  Display* display
);
VisualID XVisualIDFromVisual(
  Visual* visual
);

 /* multithread routines */

Status XInitThreads( );

void XLockDisplay(
  Display* display
);

void XUnlockDisplay(
  Display* display
);

 /* routines for dealing with extensions */

XExtCodes* XInitExtension(
  Display* display,
  const(char)* name
);

XExtCodes* XAddExtension(
  Display* display
);
XExtData* XFindOnExtensionList(
  XExtData** structure,
  int number
);
XExtData **XEHeadOfExtensionList(
  XEDataObject object
);

 /* these are routines for which there are also macros */
Window XRootWindow(
  Display* display,
  int screen_number
);
Window XDefaultRootWindow(
  Display* display
);
Window XRootWindowOfScreen(
  Screen* screen
);
Visual* XDefaultVisual(
  Display* display,
  int screen_number
);
Visual* XDefaultVisualOfScreen(
  Screen* screen
);
GC XDefaultGC(
  Display* display,
  int screen_number
);
GC XDefaultGCOfScreen(
  Screen* screen
);
c_ulong XBlackPixel(
  Display* display,
  int screen_number
);
c_ulong XWhitePixel(
  Display* display,
  int screen_number
);
c_ulong XAllPlanes( );
c_ulong XBlackPixelOfScreen(
  Screen* screen
);
c_ulong XWhitePixelOfScreen(
  Screen* screen
);
uint XNextRequest(
  Display* display
);
uint XLastKnownRequestProcessed(
  Display* display
);
char* XServerVendor(
  Display* display
);
char* XDisplayString(
  Display* display
);
Colormap XDefaultColormap(
  Display* display,
  int screen_number
);
Colormap XDefaultColormapOfScreen(
  Screen* screen
);
Display* XDisplayOfScreen(
  Screen* screen
);
Screen* XScreenOfDisplay(
  Display* display,
  int screen_number
);
Screen* XDefaultScreenOfDisplay(
  Display* display
);
c_long XEventMaskOfScreen(
  Screen* screen
);

int XScreenNumberOfScreen(
  Screen* screen
);

alias XErrorHandler = int function ( /* WARNING, this type not in Xlib spec */
  Display* display,
  XErrorEvent* error_event
);

XErrorHandler XSetErrorHandler (
  XErrorHandler handler
);


alias XIOErrorHandler = int function ( /* WARNING, this type not in Xlib spec */
  Display* display
);

XIOErrorHandler XSetIOErrorHandler (
  XIOErrorHandler handler
);


XPixmapFormatValues* XListPixmapFormats(
  Display* display,
  int* count_return
);
int* XListDepths(
  Display* display,
  int screen_number,
  int* count_return
);

 /* ICCCM routines for things that don't require special include files; */
 /* other declarations are given in Xutil.h */
Status XReconfigureWMWindow(
  Display* display,
  Window w,
  int screen_number,
  uint mask,
  XWindowChanges* changes
);

Status XGetWMProtocols(
  Display* display,
  Window w,
  Atom** protocols_return,
  int* count_return
);
Status XSetWMProtocols(
  Display* display,
  Window w,
  Atom* protocols,
  int count
);
Status XIconifyWindow(
  Display* display,
  Window w,
  int screen_number
);
Status XWithdrawWindow(
  Display* display,
  Window w,
  int screen_number
);
Status XGetCommand(
  Display* display,
  Window w,
  char*** argv_return,
  int* argc_return
);
Status XGetWMColormapWindows(
  Display* display,
  Window w,
  Window** windows_return,
  int* count_return
);
Status XSetWMColormapWindows(
  Display* display,
  Window w,
  Window* colormap_windows,
  int count
);
void XFreeStringList(
  char** list
);
int XSetTransientForHint(
  Display* display,
  Window w,
  Window prop_window
);

 /* The following are given in alphabetical order */

int XActivateScreenSaver(
  Display* display
);

int XAddHost(
  Display* display,
  XHostAddress* host
);

int XAddHosts(
  Display* display,
  XHostAddress* hosts,
  int num_hosts
);

int XAddToExtensionList(
  XExtData** structure,
  XExtData* ext_data
);

int XAddToSaveSet(
  Display* display,
  Window w
);

Status XAllocColor(
  Display* display,
  Colormap colormap,
  XColor* screen_in_out
);

Status XAllocColorCells(
  Display* display,
  Colormap colormap,
  Bool contig,
  c_ulong* plane_masks_return,
  uint nplanes,
  c_ulong* pixels_return,
  uint npixels
);

Status XAllocColorPlanes(
  Display* display,
  Colormap colormap,
  Bool contig,
  c_ulong* pixels_return,
  int ncolors,
  int nreds,
  int ngreens,
  int nblues,
  c_ulong* rmask_return,
  c_ulong* gmask_return,
  c_ulong* bmask_return
);

Status XAllocNamedColor(
  Display* display,
  Colormap colormap,
  const(char)* color_name,
  XColor* screen_def_return,
  XColor* exact_def_return
);

int XAllowEvents(
  Display* display,
  int event_mode,
  Time time
);

int XAutoRepeatOff(
  Display* display
);

int XAutoRepeatOn(
  Display* display
);

int XBell(
  Display* display,
  int percent
);

int XBitmapBitOrder(
  Display* display
);

int XBitmapPad(
  Display* display
);

int XBitmapUnit(
  Display* display
);

int XCellsOfScreen(
  Screen* screen
);

int XChangeActivePointerGrab(
  Display* display,
  uint event_mask,
  Cursor cursor,
  Time time
);

int XChangeGC(
  Display* display,
  GC gc,
  c_ulong valuemask,
  XGCValues* values
);

int XChangeKeyboardControl(
  Display* display,
  c_ulong value_mask,
  XKeyboardControl* values
);

int XChangeKeyboardMapping(
  Display* display,
  int first_keycode,
  int keysyms_per_keycode,
  KeySym* keysyms,
  int num_codes
);

int XChangePointerControl(
  Display* display,
  Bool do_accel,
  Bool do_threshold,
  int accel_numerator,
  int accel_denominator,
  int threshold
);

int XChangeProperty(
  Display* display,
  Window w,
  Atom property,
  Atom type,
  int format,
  int mode,
  ubyte* data,
  int nelements
);

int XChangeSaveSet(
  Display* display,
  Window w,
  int change_mode
);

int XChangeWindowAttributes(
  Display* display,
  Window w,
  uint valuemask,
  XSetWindowAttributes* attributes
);

Bool XCheckIfEvent(
  Display* display,
  XEvent* event_return,
  Bool function(
      Display* display,
      XEvent* event,
      XPointer arg
  ) predicate,
  XPointer arg
);

Bool XCheckMaskEvent(
  Display* display,
  c_long event_mask,
  XEvent* event_return
);

Bool XCheckTypedEvent(
  Display* display,
  int event_type,
  XEvent* event_return
);

Bool XCheckTypedWindowEvent(
  Display* display,
  Window w,
  int event_type,
  XEvent* event_return
);

Bool XCheckWindowEvent(
  Display* display,
  Window w,
  c_long event_mask,
  XEvent* event_return
);

int XCirculateSubwindows(
  Display* display,
  Window w,
  int direction
);

int XCirculateSubwindowsDown(
  Display* display,
  Window w
);

int XCirculateSubwindowsUp(
  Display* display,
  Window w
);

int XClearArea(
  Display* display,
  Window w,
  int x,
  int y,
  uint width,
  uint height,
  Bool exposures
);

int XClearWindow(
  Display* display,
  Window w
);

int XCloseDisplay(
  Display* display
);

int XConfigureWindow(
  Display* display,
  Window w,
  c_ulong value_mask,
  XWindowChanges* values
);

int XConnectionNumber(
  Display* display
);

int XConvertSelection(
  Display* display,
  Atom selection,
  Atom target,
  Atom property,
  Window requestor,
  Time time
);

int XCopyArea(
  Display* display,
  Drawable src,
  Drawable dest,
  GC gc,
  int src_x,
  int src_y,
  uint width,
  uint height,
  int dest_x,
  int dest_y
);

int XCopyGC(
  Display* display,
  GC src,
  uint valuemask,
  GC dest
);

int XCopyPlane(
  Display* display,
  Drawable src,
  Drawable dest,
  GC gc,
  int src_x,
  int src_y,
  uint width,
  uint height,
  int dest_x,
  int dest_y,
  c_ulong plane
);

int XDefaultDepth(
  Display* display,
  int screen_number
);

int XDefaultDepthOfScreen(
  Screen* screen
);

int XDefaultScreen(
  Display* display
);

int XDefineCursor(
  Display* display,
  Window w,
  Cursor cursor
);

int XDeleteProperty(
  Display* display,
  Window w,
  Atom property
);

int XDestroyWindow(
  Display* display,
  Window w
);

int XDestroySubwindows(
  Display* display,
  Window w
);

int XDoesBackingStore(
  Screen* screen
);

Bool XDoesSaveUnders(
  Screen* screen
);

int XDisableAccessControl(
  Display* display
);


int XDisplayCells(
  Display* display,
  int screen_number
);

int XDisplayHeight(
  Display* display,
  int screen_number
);

int XDisplayHeightMM(
  Display* display,
  int screen_number
);

int XDisplayKeycodes(
  Display* display,
  int* min_keycodes_return,
  int* max_keycodes_return
);

int XDisplayPlanes(
  Display* display,
  int screen_number
);

int XDisplayWidth(
  Display* display,
  int screen_number
);

int XDisplayWidthMM(
  Display* display,
  int screen_number
);

int XDrawArc(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  uint width,
  uint height,
  int angle1,
  int angle2
);

int XDrawArcs(
  Display* display,
  Drawable d,
  GC gc,
  XArc* arcs,
  int narcs
);

int XDrawImageString(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  const(char)* string,
  int length
);

int XDrawImageString16(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XChar2b* string,
  int length
);

int XDrawLine(
  Display* display,
  Drawable d,
  GC gc,
  int x1,
  int y1,
  int x2,
  int y2
);

int XDrawLines(
  Display* display,
  Drawable d,
  GC gc,
  XPoint* points,
  int npoints,
  int mode
);

int XDrawPoint(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y
);

int XDrawPoints(
  Display* display,
  Drawable d,
  GC gc,
  XPoint* points,
  int npoints,
  int mode
);

int XDrawRectangle(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  uint width,
  uint height
);

int XDrawRectangles(
  Display* display,
  Drawable d,
  GC gc,
  XRectangle* rectangles,
  int nrectangles
);

int XDrawSegments(
  Display* display,
  Drawable d,
  GC gc,
  XSegment* segments,
  int nsegments
);

int XDrawString(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  const(char)* string,
  int length
);

int XDrawString16(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XChar2b* string,
  int length
);

int XDrawText(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XTextItem* items,
  int nitems
);

int XDrawText16(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XTextItem16* items,
  int nitems
);

int XEnableAccessControl(
  Display* display
);

int XEventsQueued(
  Display* display,
  int mode
);

Status XFetchName(
  Display* display,
  Window w,
  char** window_name_return
);

int XFillArc(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  uint width,
  uint height,
  int angle1,
  int angle2
);

int XFillArcs(
  Display* display,
  Drawable d,
  GC gc,
  XArc* arcs,
  int narcs
);

int XFillPolygon(
  Display* display,
  Drawable d,
  GC gc,
  XPoint* points,
  int npoints,
  int shape,
  int mode
);

int XFillRectangle(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  uint width,
  uint height
);

int XFillRectangles(
  Display* display,
  Drawable d,
  GC gc,
  XRectangle* rectangles,
  int nrectangles
);

int XFlush(
  Display* display
);

int XForceScreenSaver(
  Display* display,
  int mode
);

int XFree(
  void* data
);

int XFreeColormap(
  Display* display,
  Colormap colormap
);

int XFreeColors(
  Display* display,
  Colormap colormap,
  c_ulong* pixels,
  int npixels,
  c_ulong planes
);

int XFreeCursor(
  Display* display,
  Cursor cursor
);

int XFreeExtensionList(
  char** list
);

int XFreeFont(
  Display* display,
  XFontStruct* font_struct
);

int XFreeFontInfo(
  char** names,
  XFontStruct* free_info,
  int actual_count
);

int XFreeFontNames(
  char** list
);

int XFreeFontPath(
  char** list
);

int XFreeGC(
  Display* display,
  GC gc
);

int XFreeModifiermap(
  XModifierKeymap* modmap
);

int XFreePixmap(
  Display* display,
  Pixmap pixmap
);

int XGeometry(
  Display* display,
  int screen,
  char* position,
  char* default_position,
  uint bwidth,
  uint fwidth,
  uint fheight,
  int xadder,
  int yadder,
  int* x_return,
  int* y_return,
  int* width_return,
  int* height_return
);

int XGetErrorDatabaseText(
  Display* display,
  char* name,
  char* message,
  char* default_string,
  char* buffer_return,
  int length
);

int XGetErrorText(
  Display* display,
  int code,
  char* buffer_return,
  int length
);

Bool XGetFontProperty(
  XFontStruct* font_struct,
  Atom atom,
  c_ulong* value_return
);

Status XGetGCValues(
  Display* display,
  GC gc,
  c_ulong valuemask,
  XGCValues* values_return
);

Status XGetGeometry(
  Display* display,
  Drawable d,
  Window* root_return,
  int* x_return,
  int* y_return,
  uint* width_return,
  uint* height_return,
  uint* border_width_return,
  uint* depth_return
);

Status XGetIconName(
  Display* display,
  Window w,
  char** icon_name_return
);

int XGetInputFocus(
  Display* display,
  Window* focus_return,
  int* revert_to_return
);

int XGetKeyboardControl(
  Display* display,
  XKeyboardState* values_return
);

int XGetPointerControl(
  Display* display,
  int* accel_numerator_return,
  int* accel_denominator_return,
  int* threshold_return
);

int XGetPointerMapping(
  Display* display,
  ubyte* map_return,
  int nmap
);

int XGetScreenSaver(
  Display* display,
  int* timeout_return,
  int* interval_return,
  int* prefer_blanking_return,
  int* allow_exposures_return
);

Status XGetTransientForHint(
  Display* display,
  Window w,
  Window* prop_window_return
);

int XGetWindowProperty(
  Display* display,
  Window w,
  Atom property,
  c_long c_long_offset,
  c_long c_long_length,
  Bool dodelete,
  Atom req_type,
  Atom* actual_type_return,
  int* actual_format_return,
  c_ulong* nitems_return,
  c_ulong* chars_after_return,
  ubyte** prop_return
);

Status XGetWindowAttributes(
  Display* display,
  Window w,
  XWindowAttributes* window_attributes_return
);

int XGrabButton(
  Display* display,
  uint button,
  uint modifiers,
  Window grab_window,
  Bool owner_events,
  uint event_mask,
  int pointer_mode,
  int keyboard_mode,
  Window confine_to,
  Cursor cursor
);

int XGrabKey(
  Display* display,
  int keycode,
  uint modifiers,
  Window grab_window,
  Bool owner_events,
  int pointer_mode,
  int keyboard_mode
);

int XGrabKeyboard(
  Display* display,
  Window grab_window,
  Bool owner_events,
  int pointer_mode,
  int keyboard_mode,
  Time time
);

int XGrabPointer(
  Display* display,
  Window grab_window,
  Bool owner_events,
  uint event_mask,
  int pointer_mode,
  int keyboard_mode,
  Window confine_to,
  Cursor cursor,
  Time time
);

int XGrabServer(
  Display* display
);

int XHeightMMOfScreen(
  Screen* screen
);

int XHeightOfScreen(
  Screen* screen
);

int XIfEvent(
  Display* display,
  XEvent* event_return,
  Bool function(
      Display* display,
      XEvent* event,
      XPointer arg
  ) predicate,
  XPointer arg
);

int XImagecharOrder(
  Display* display
);

int XInstallColormap(
  Display* display,
  Colormap colormap
);

KeyCode XKeysymToKeycode(
  Display* display,
  KeySym keysym
);

int XKillClient(
  Display* display,
  XID resource
);

Status XLookupColor(
  Display* display,
  Colormap colormap,
  const(char)* color_name,
  XColor* exact_def_return,
  XColor* screen_def_return
);

int XLowerWindow(
  Display* display,
  Window w
);

int XMapRaised(
  Display* display,
  Window w
);

int XMapSubwindows(
  Display* display,
  Window w
);

int XMapWindow(
  Display* display,
  Window w
);

int XMaskEvent(
  Display* display,
  c_long event_mask,
  XEvent* event_return
);

int XMaxCmapsOfScreen(
  Screen* screen
);

int XMinCmapsOfScreen(
  Screen* screen
);

int XMoveResizeWindow(
  Display* display,
  Window w,
  int x,
  int y,
  uint width,
  uint height
);

int XMoveWindow(
  Display* display,
  Window w,
  int x,
  int y
);

int XNextEvent(
  Display* display,
  XEvent* event_return
);

int XNoOp(
  Display* display
);

Status XParseColor(
  Display* display,
  Colormap colormap,
  const(char)* spec,
  XColor* exact_def_return
);

int XParseGeometry(
  char* parsestring,
  int* x_return,
  int* y_return,
  uint* width_return,
  uint* height_return
);

int XPeekEvent(
  Display* display,
  XEvent* event_return
);

int XPeekIfEvent(
  Display* display,
  XEvent* event_return,
  Bool function(
      Display* display,
      XEvent* event,
      XPointer arg
  ) predicate,
  XPointer arg
);

int XPending(
  Display* display
);

int XPlanesOfScreen(
  Screen* screen
);

int XProtocolRevision(
  Display* display
);

int XProtocolVersion(
  Display* display
);


int XPutBackEvent(
  Display* display,
  XEvent* event
);

int XPutImage(
  Display* display,
  Drawable d,
  GC gc,
  XImage* image,
  int src_x,
  int src_y,
  int dest_x,
  int dest_y,
  uint width,
  uint height
);

int XQLength(
  Display* display
);

Status XQueryBestCursor(
  Display* display,
  Drawable d,
  uint width,
  uint height,
  uint* width_return,
  uint* height_return
);

Status XQueryBestSize(
  Display* display,
  int klass,
  Drawable which_screen,
  uint width,
  uint height,
  uint* width_return,
  uint* height_return
);

Status XQueryBestStipple(
  Display* display,
  Drawable which_screen,
  uint width,
  uint height,
  uint* width_return,
  uint* height_return
);

Status XQueryBestTile(
  Display* display,
  Drawable which_screen,
  uint width,
  uint height,
  uint* width_return,
  uint* height_return
);

int XQueryColor(
  Display* display,
  Colormap colormap,
  XColor* def_in_out
);

int XQueryColors(
  Display* display,
  Colormap colormap,
  XColor* defs_in_out,
  int ncolors
);

Bool XQueryExtension(
  Display* display,
  char* name,
  int* major_opcode_return,
  int* first_event_return,
  int* first_error_return
);

int XQueryKeymap(
  Display* display,
  char [32] keys_return
);

Bool XQueryPointer(
  Display* display,
  Window w,
  Window* root_return,
  Window* child_return,
  int* root_x_return,
  int* root_y_return,
  int* win_x_return,
  int* win_y_return,
  uint* mask_return
);

int XQueryTextExtents(
  Display* display,
  XID font_ID,
  const(char)* string,
  int nchars,
  int* direction_return,
  int* font_ascent_return,
  int* font_descent_return,
  XCharStruct* overall_return
);

int XQueryTextExtents16(
  Display* display,
  XID font_ID,
  XChar2b* string,
  int nchars,
  int* direction_return,
  int* font_ascent_return,
  int* font_descent_return,
  XCharStruct* overall_return
);

Status XQueryTree(
  Display* display,
  Window w,
  Window* root_return,
  Window* parent_return,
  Window** children_return,
  uint* nchildren_return
);

int XRaiseWindow(
  Display* display,
  Window w
);

int XReadBitmapFile(
  Display* display,
  Drawable d,
  ubyte* filename,
  uint* width_return,
  uint* height_return,
  Pixmap* bitmap_return,
  int* x_hot_return,
  int* y_hot_return
);

int XReadBitmapFileData(
  const(char)* filename,
  uint* width_return,
  uint* height_return,
  ubyte** data_return,
  int* x_hot_return,
  int* y_hot_return
);

int XRebindKeysym(
  Display* display,
  KeySym keysym,
  KeySym* list,
  int mod_count,
  ubyte* string,
  int chars_string
);

int XRecolorCursor(
  Display* display,
  Cursor cursor,
  XColor* foreground_color,
  XColor* background_color
);

int XRefreshKeyboardMapping(
  XMappingEvent* event_map
);

int XRemoveFromSaveSet(
  Display* display,
  Window w
);

int XRemoveHost(
  Display* display,
  XHostAddress* host
);

int XRemoveHosts(
  Display* display,
  XHostAddress* hosts,
  int num_hosts
);

int XReparentWindow(
  Display* display,
  Window w,
  Window parent,
  int x,
  int y
);

int XResetScreenSaver(
  Display* display
);

int XResizeWindow(
  Display* display,
  Window w,
  uint width,
  uint height
);

int XRestackWindows(
  Display* display,
  Window* windows,
  int nwindows
);

int XRotateBuffers(
  Display* display,
  int rotate
);

int XRotateWindowProperties(
  Display* display,
  Window w,
  Atom* properties,
  int num_prop,
  int npositions
);

int XScreenCount(
  Display* display
);

int XSelectInput(
  Display* display,
  Window w,
  c_long event_mask
);

Status XSendEvent(
  Display* display,
  Window w,
  Bool propagate,
  c_long event_mask,
  XEvent* event_send
);

int XSetAccessControl(
  Display* display,
  int mode
);

int XSetArcMode(
  Display* display,
  GC gc,
  int arc_mode
);

int XSetBackground(
  Display* display,
  GC gc,
  c_ulong background
);

int XSetClipMask(
  Display* display,
  GC gc,
  Pixmap pixmap
);

int XSetClipOrigin(
  Display* display,
  GC gc,
  int clip_x_origin,
  int clip_y_origin
);

int XSetClipRectangles(
  Display* display,
  GC gc,
  int clip_x_origin,
  int clip_y_origin,
  XRectangle* rectangles,
  int n,
  int ordering
);

int XSetCloseDownMode(
  Display* display,
  int close_mode
);

int XSetCommand(
  Display* display,
  Window w,
  char** argv,
  int argc
);

int XSetDashes(
  Display* display,
  GC gc,
  int dash_offset,
  char* dash_list,
  int n
);

int XSetFillRule(
  Display* display,
  GC gc,
  int fill_rule
);

int XSetFillStyle(
  Display* display,
  GC gc,
  int fill_style
);

int XSetFont(
  Display* display,
  GC gc,
  Font font
);

int XSetFontPath(
  Display* display,
  char** directories,
  int ndirs
);

int XSetForeground(
  Display* display,
  GC gc,
  c_ulong foreground
);

int XSetFunction(
  Display* display,
  GC gc,
  int func
);

int XSetGraphicsExposures(
  Display* display,
  GC gc,
  Bool graphics_exposures
);

int XSetIconName(
  Display* display,
  Window w,
  const(char)* icon_name
);

int XSetInputFocus(
  Display* display,
  Window focus,
  int revert_to,
  Time time
);

int XSetLineAttributes(
  Display* display,
  GC gc,
  uint line_width,
  int line_style,
  int cap_style,
  int join_style
);

int XSetModifierMapping(
  Display* display,
  XModifierKeymap* modmap
);

int XSetPlaneMask(
  Display* display,
  GC gc,
  c_ulong plane_mask
);

int XSetPointerMapping(
  Display* display,
  ubyte* map,
  int nmap
);

int XSetScreenSaver(
  Display* display,
  int timeout,
  int interval,
  int prefer_blanking,
  int allow_exposures
);

int XSetSelectionOwner(
  Display* display,
  Atom selection,
  Window owner,
  Time time
);

int XSetState(
  Display* display,
  GC gc,
  c_ulong foreground,
  c_ulong background,
  int func,
  c_ulong plane_mask
);

int XSetStipple(
  Display* display,
  GC gc,
  Pixmap stipple
);

int XSetSubwindowMode(
  Display* display,
  GC gc,
  int subwindow_mode
);

int XSetTSOrigin(
  Display* display,
  GC gc,
  int ts_x_origin,
  int ts_y_origin
);

int XSetTile(
  Display* display,
  GC gc,
  Pixmap tile
);

int XSetWindowBackground(
  Display* display,
  Window w,
  c_ulong background_pixel
);

int XSetWindowBackgroundPixmap(
  Display* display,
  Window w,
  Pixmap background_pixmap
);

int XSetWindowBorder(
  Display* display,
  Window w,
  c_ulong border_pixel
);

int XSetWindowBorderPixmap(
  Display* display,
  Window w,
  Pixmap border_pixmap
);

int XSetWindowBorderWidth(
  Display* display,
  Window w,
  uint width
);

int XSetWindowColormap(
  Display* display,
  Window w,
  Colormap colormap
);

int XStoreBuffer(
  Display* display,
  char* chars,
  int nchars,
  int buffer
);

int XStorechars(
  Display* display,
  char* chars,
  int nchars
);

int XStoreColor(
  Display* display,
  Colormap colormap,
  XColor* color
);

int XStoreColors(
  Display* display,
  Colormap colormap,
  XColor* color,
  int ncolors
);

int XStoreName(
  Display* display,
  Window w,
  const(char)* window_name
);

int XStoreNamedColor(
  Display* display,
  Colormap colormap,
  char* color,
  c_ulong pixel,
  int flags
);

int XSync(
  Display* display,
  Bool discard
);

int XTextExtents(
  XFontStruct* font_struct,
  const(char)* string,
  int nchars,
  int* direction_return,
  int* font_ascent_return,
  int* font_descent_return,
  XCharStruct* overall_return
);

int XTextExtents16(
  XFontStruct* font_struct,
  XChar2b* string,
  int nchars,
  int* direction_return,
  int* font_ascent_return,
  int* font_descent_return,
  XCharStruct* overall_return
);

int XTextWidth(
  XFontStruct* font_struct,
  const(char)* string,
  int count
);

int XTextWidth16(
  XFontStruct* font_struct,
  XChar2b* string,
  int count
);

Bool XTranslateCoordinates(
  Display* display,
  Window src_w,
  Window dest_w,
  int src_x,
  int src_y,
  int* dest_x_return,
  int* dest_y_return,
  Window* child_return
);

int XUndefineCursor(
  Display* display,
  Window w
);

int XUngrabButton(
  Display* display,
  uint button,
  uint modifiers,
  Window grab_window
);

int XUngrabKey(
  Display* display,
  int keycode,
  uint modifiers,
  Window grab_window
);

int XUngrabKeyboard(
  Display* display,
  Time time
);

int XUngrabPointer(
  Display* display,
  Time time
);

int XUngrabServer(
  Display* display
);

int XUninstallColormap(
  Display* display,
  Colormap colormap
);

int XUnloadFont(
  Display* display,
  Font font
);

int XUnmapSubwindows(
  Display* display,
  Window w
);

int XUnmapWindow(
  Display* display,
  Window w
);

int XVendorRelease(
  Display* display
);

int XWarpPointer(
  Display* display,
  Window src_w,
  Window dest_w,
  int src_x,
  int src_y,
  uint src_width,
  uint src_height,
  int dest_x,
  int dest_y
);

int XWidthMMOfScreen(
  Screen* screen
);

int XWidthOfScreen(
  Screen* screen
);

int XWindowEvent(
  Display* display,
  Window w,
  c_long event_mask,
  XEvent* event_return
);

int XWriteBitmapFile(
  Display* display,
  const(char)* filename,
  Pixmap bitmap,
  uint width,
  uint height,
  int x_hot,
  int y_hot
);

Bool XSupportsLocale ( );

char* XSetLocaleModifiers(
  const(char)* modifier_list
);

XOM XOpenOM(
  Display* display,
  _XrmHashBucketRec* rdb,
  const(char)* res_name,
  const(char)* res_class
);

Status XCloseOM(
  XOM om
);

/+todo
char* XSetOMValues(
  XOM om,
  ...
) _X_SENTINEL(0);

char* XGetOMValues(
  XOM om,
  ...
) _X_SENTINEL(0);
+/

Display* XDisplayOfOM(
  XOM om
);

char* XLocaleOfOM(
  XOM om
);

/+todo
XOC XCreateOC(
  XOM om,
  ...
) _X_SENTINEL(0);
+/
void XDestroyOC(
  XOC oc
);

XOM XOMOfOC(
  XOC oc
);

/+todo
char* XSetOCValues(
  XOC oc,
  ...
) _X_SENTINEL(0);

char* XGetOCValues(
  XOC oc,
  ...
) _X_SENTINEL(0);
+/

XFontSet XCreateFontSet(
  Display* display,
  const(char)* base_font_name_list,
  char*** missing_charset_list,
  int* missing_charset_count,
  char** def_string
);

void XFreeFontSet(
  Display* display,
  XFontSet font_set
);

int XFontsOfFontSet(
  XFontSet font_set,
  XFontStruct*** font_struct_list,
  char*** font_name_list
);

char* XBaseFontNameListOfFontSet(
  XFontSet font_set /*was char*/
);

char* XLocaleOfFontSet(
  XFontSet font_set
);

Bool XContextDependentDrawing(
  XFontSet font_set
);

Bool XDirectionalDependentDrawing(
  XFontSet font_set
);

Bool XContextualDrawing(
  XFontSet font_set
);

XFontSetExtents* XExtentsOfFontSet(
  XFontSet font_set
);

int XmbTextEscapement(
  XFontSet font_set,
  const(char)* text,
  int chars_text
);

int XwcTextEscapement(
  XFontSet font_set,
  const(wchar_t)* text,
  int num_wchars
);

int Xutf8TextEscapement(
  XFontSet font_set,
  const(char)* text,
  int chars_text
);

int XmbTextExtents(
  XFontSet font_set,
  const(char)* text,
  int chars_text,
  XRectangle* overall_ink_return,
  XRectangle* overall_logical_return
);

int XwcTextExtents(
  XFontSet font_set,
  const(wchar_t)* text,
  int num_wchars,
  XRectangle* overall_ink_return,
  XRectangle* overall_logical_return
);

int Xutf8TextExtents(
  XFontSet font_set,
  const(char)* text,
  int chars_text,
  XRectangle* overall_ink_return,
  XRectangle* overall_logical_return
);

Status XmbTextPerCharExtents(
  XFontSet font_set,
  const(char)* text,
  int chars_text,
  XRectangle* ink_extents_buffer,
  XRectangle* logical_extents_buffer,
  int buffer_size,
  int* num_chars,
  XRectangle* overall_ink_return,
  XRectangle* overall_logical_return
);

Status XwcTextPerCharExtents(
  XFontSet font_set,
  const(wchar_t)* text,
  int num_wchars,
  XRectangle* ink_extents_buffer,
  XRectangle* logical_extents_buffer,
  int buffer_size,
  int* num_chars,
  XRectangle* overall_ink_return,
  XRectangle* overall_logical_return
);

Status Xutf8TextPerCharExtents(
  XFontSet font_set,
  const(char)* text,
  int chars_text,
  XRectangle* ink_extents_buffer,
  XRectangle* logical_extents_buffer,
  int buffer_size,
  int* num_chars,
  XRectangle* overall_ink_return,
  XRectangle* overall_logical_return
);

void XmbDrawText(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XmbTextItem* text_items,
  int nitems
);

void XwcDrawText(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XwcTextItem* text_items,
  int nitems
);

void Xutf8DrawText(
  Display* display,
  Drawable d,
  GC gc,
  int x,
  int y,
  XmbTextItem* text_items,
  int nitems
);

void XmbDrawString(
  Display* display,
  Drawable d,
  XFontSet font_set,
  GC gc,
  int x,
  int y,
  const(char)* text,
  int chars_text
);

void XwcDrawString(
  Display* display,
  Drawable d,
  XFontSet font_set,
  GC gc,
  int x,
  int y,
  const(wchar_t)* text,
  int num_wchars
);

void Xutf8DrawString(
  Display* display,
  Drawable d,
  XFontSet font_set,
  GC gc,
  int x,
  int y,
  const(char)* text,
  int chars_text
);

void XmbDrawImageString(
  Display* display,
  Drawable d,
  XFontSet font_set,
  GC gc,
  int x,
  int y,
  const(char)* text,
  int chars_text
);

void XwcDrawImageString(
  Display* display,
  Drawable d,
  XFontSet font_set,
  GC gc,
  int x,
  int y,
  const(wchar_t)* text,
  int num_wchars
);

void Xutf8DrawImageString(
  Display* display,
  Drawable d,
  XFontSet font_set,
  GC gc,
  int x,
  int y,
  const(char)* text,
  int chars_text
);

XIM XOpenIM(
  Display* dpy,
  _XrmHashBucketRec* rdb,
  const(char)* res_name,
  const(char)* res_class
);

Status XCloseIM(
  XIM im
);

char* XGetIMValues(
  XIM im, ...
) /*_X_SENTINEL(0)*/;

char* XSetIMValues(
  XIM im, ...
) /*_X_SENTINEL(0)*/;

Display* XDisplayOfIM(
  XIM im
);

char* XLocaleOfIM(
  XIM im
);

//TODO
XIC XCreateIC(
  XIM im, ...
) /*_X_SENTINEL(0)*/;

void XDestroyIC(
  XIC ic
);

void XSetICFocus(
  XIC ic
);

void XUnsetICFocus(
  XIC ic
);

wchar_t* XwcResetIC(
  XIC ic
);

char* XmbResetIC(
  XIC ic
);

char* Xutf8ResetIC(
  XIC ic
);

char* XSetICValues(
  XIC ic, ...
) /*_X_SENTINEL(0)*/;

char* XGetICValues(
  XIC ic, ...
) /*_X_SENTINEL(0)*/;

XIM XIMOfIC(
  XIC ic
);

Bool XFilterEvent(
  XEvent* event,
  Window window
);

int XmbLookupString(
  XIC ic,
  XKeyPressedEvent* event,
  char* buffer_return,
  int chars_buffer,
  KeySym* keysym_return,
  Status* status_return
);

int XwcLookupString(
  XIC ic,
  XKeyPressedEvent* event,
  wchar_t* buffer_return,
  int wchars_buffer,
  KeySym* keysym_return,
  Status* status_return
);

int Xutf8LookupString(
  XIC ic,
  XKeyPressedEvent* event,
  char* buffer_return,
  int chars_buffer,
  KeySym* keysym_return,
  Status* status_return
);

/+todo
XVaNestedList XVaCreateNestedList(
  int unused, ...
) _X_SENTINEL(0);
+/
 /* internal connections for IMs */

Bool XRegisterIMInstantiateCallback(
  Display* dpy,
  _XrmHashBucketRec* rdb,
  const(char)* res_name,
  const(char)* res_class,
  XIDProc callback,
  XPointer client_data
);

Bool XUnregisterIMInstantiateCallback(
  Display* dpy,
  _XrmHashBucketRec* rdb,
  const(char)* res_name,
  const(char)* res_class,
  XIDProc callback,
  XPointer client_data
);

alias XConnectionWatchProc = void function(
  Display* dpy,
  XPointer client_data,
  int fd,
  Bool /* opening, open or close flag */,
  XPointer* /* watch_data, open sets, close uses */
);


Status XInternalConnectionNumbers(
  Display* dpy,
  int** fd_return,
  int* count_return
);

void XProcessInternalConnection(
  Display* dpy,
  int fd
);

Status XAddConnectionWatch(
  Display* dpy,
  XConnectionWatchProc callback,
  XPointer client_data
);

void XRemoveConnectionWatch(
  Display* dpy,
  XConnectionWatchProc callback,
  XPointer client_data
);

void XSetAuthorization(
  char* name,
  int namelen,
  char* data,
  int datalen
);

int _Xmbtowc(
  wchar_t* wstr,
  char* str,
  int len
);

int _Xwctomb(
  char* str,
  wchar_t wc
);

Bool XGetEventData(
  Display* dpy,
  XGenericEventCookie* cookie
);

void XFreeEventData(
  Display* dpy,
  XGenericEventCookie* cookie
);


Bool XkbSetDetectableAutoRepeat(
  Display* dpy,
  Bool detectable,
  Bool* supported
);
