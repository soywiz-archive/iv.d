/************************************************************

Copyright 1989, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

********************************************************/
module iv.x11.xshape /*is aliced*/;

import core.stdc.config;

import iv.alice;
import iv.x11.md;
import iv.x11.region;
import iv.x11.x11;
import iv.x11.xlib;

extern(C) nothrow @nogc:


//#include <X11/Xfuncproto.h>
//#include <X11/extensions/shapeconst.h>

/*
 * Protocol requests constants and alignment values
 * These would really be in SHAPE's X.h and Xproto.h equivalents
 */

//#define SHAPENAME "SHAPE"

//#define SHAPE_MAJOR_VERSION 1 /* current version numbers */
//#define SHAPE_MINOR_VERSION 1

enum ShapeSet = 0;
enum ShapeUnion = 1;
enum ShapeIntersect = 2;
enum ShapeSubtract = 3;
enum ShapeInvert = 4;

enum ShapeBounding = 0;
enum ShapeClip = 1;
enum ShapeInput = 2;

enum ShapeNotifyMask = 1U<<0;
enum ShapeNotify = 0;

enum ShapeNumberEvents = ShapeNotify+1;

struct XShapeEvent {
  int type;       /* of event */
  c_ulong serial;   /* # of last request processed by server */
  Bool send_event;      /* true if this came frome a SendEvent request */
  Display* display;     /* Display the event was read from */
  Window window;      /* window of event */
  int kind;       /* ShapeBounding or ShapeClip */
  int x, y;       /* extents of new region */
  uint width, height;
  Time time;        /* server timestamp when region changed */
  Bool shaped;      /* true if the region exists */
}


Bool XShapeQueryExtension (
  Display*  /* display */,
  int*  /* event_base */,
  int*  /* error_base */
);

Status XShapeQueryVersion (
  Display*  /* display */,
  int*  /* major_version */,
  int*  /* minor_version */
);

void XShapeCombineRegion (
  Display*  /* display */,
  Window  /* dest */,
  int   /* dest_kind */,
  int   /* x_off */,
  int   /* y_off */,
  XRegion  /* region */,
  int   /* op */
);

void XShapeCombineRectangles (
  Display*  /* display */,
  Window  /* dest */,
  int   /* dest_kind */,
  int   /* x_off */,
  int   /* y_off */,
  XRectangle* /* rectangles */,
  int   /* n_rects */,
  int   /* op */,
  int   /* ordering */
);

void XShapeCombineMask (
  Display*  /* display */,
  Window  /* dest */,
  int   /* dest_kind */,
  int   /* x_off */,
  int   /* y_off */,
  Pixmap  /* src */,
  int   /* op */
);

void XShapeCombineShape (
  Display*  /* display */,
  Window  /* dest */,
  int   /* dest_kind */,
  int   /* x_off */,
  int   /* y_off */,
  Window  /* src */,
  int   /* src_kind */,
  int   /* op */
);

void XShapeOffsetShape (
  Display*  /* display */,
  Window  /* dest */,
  int   /* dest_kind */,
  int   /* x_off */,
  int   /* y_off */
);

Status XShapeQueryExtents (
  Display*    /* display */,
  Window    /* window */,
  Bool*   /* bounding_shaped */,
  int*    /* x_bounding */,
  int*    /* y_bounding */,
  uint* /* w_bounding */,
  uint* /* h_bounding */,
  Bool*   /* clip_shaped */,
  int*    /* x_clip */,
  int*    /* y_clip */,
  uint* /* w_clip */,
  uint* /* h_clip */
);

void XShapeSelectInput (
  Display*    /* display */,
  Window    /* window */,
  c_ulong /* mask */
);

c_ulong XShapeInputSelected (
  Display*  /* display */,
  Window  /* window */
);

XRectangle *XShapeGetRectangles (
  Display*  /* display */,
  Window  /* window */,
  int   /* kind */,
  int*  /* count */,
  int*  /* ordering */
);
