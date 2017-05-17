/*
   rsvg.h: SAX-based renderer for SVG files into a GdkPixbuf.

   Copyright (C) 2000 Eazel, Inc.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this program; if not, write to the
   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.

   Author: Raph Levien <raph@artofcode.com>
*/
module iv.librsvg /*is aliced*/;
pragma(lib, "rsvg-2");
pragma(lib, "gio-2.0");
pragma(lib, "gdk_pixbuf-2.0");
pragma(lib, "gobject-2.0");
pragma(lib, "glib-2.0");

import iv.alice;
import iv.cairo;

extern(C) nothrow @nogc:

alias rsvgbool = int;
struct GError;

void g_error_free (GError* err);


enum LIBRSVG_MAJOR_VERSION = 2;
enum LIBRSVG_MINOR_VERSION = 40;
enum LIBRSVG_MICRO_VERSION = 16;
enum LIBRSVG_VERSION = "2.40.16";

bool LIBRSVG_CHECK_VERSION (int major, int minor, int micro) pure nothrow @safe @nogc {
  pragma(inline, true);
  return
    (LIBRSVG_MAJOR_VERSION > major ||
    (LIBRSVG_MAJOR_VERSION == major && LIBRSVG_MINOR_VERSION > minor) ||
    (LIBRSVG_MAJOR_VERSION == major && LIBRSVG_MINOR_VERSION == minor && LIBRSVG_MICRO_VERSION >= micro));
}

extern immutable uint librsvg_major_version;
extern immutable uint librsvg_minor_version;
extern immutable uint librsvg_micro_version;
extern immutable(char)* librsvg_version;

/**
 * RsvgError:
 * @RSVG_ERROR_FAILED: the request failed
 *
 * An enumeration representing possible errors
 */
alias RsvgError = int;
enum : RsvgError {
  RSVG_ERROR_FAILED
}

/**
 * RsvgHandle:
 *
 * The #RsvgHandle is an object representing the parsed form of a SVG
 */
struct RsvgHandle;
struct RsvgHandlePrivate;
struct RsvgHandleClass;

/**
 * RsvgDimensionData:
 * @width: SVG's width, in pixels
 * @height: SVG's height, in pixels
 * @em: em
 * @ex: ex
 */
struct RsvgDimensionData {
  int width;
  int height;
  double em;
  double ex;
}

/**
 * RsvgPositionData:
 * @x: position on the x axis
 * @y: position on the y axis
 *
 * Position of an SVG fragment.
 */
struct RsvgPositionData {
  int x;
  int y;
}

void rsvg_cleanup ();

void rsvg_set_default_dpi (double dpi);
void rsvg_set_default_dpi_x_y (double dpi_x, double dpi_y);

void rsvg_handle_set_dpi (RsvgHandle* handle, double dpi);
void rsvg_handle_set_dpi_x_y (RsvgHandle* handle, double dpi_x, double dpi_y);

RsvgHandle* rsvg_handle_new ();
rsvgbool rsvg_handle_write (RsvgHandle* handle, const(void)* buf, usize count, GError** error);
rsvgbool rsvg_handle_close (RsvgHandle* handle, GError** error);
/*
GdkPixbuf* rsvg_handle_get_pixbuf (RsvgHandle* handle);
GdkPixbuf* rsvg_handle_get_pixbuf_sub (RsvgHandle* handle, const char *id);
*/

const(char)* rsvg_handle_get_base_uri (RsvgHandle* handle);
void rsvg_handle_set_base_uri (RsvgHandle* handle, const(char)* base_uri);

void rsvg_handle_get_dimensions (RsvgHandle* handle, RsvgDimensionData* dimension_data);

rsvgbool rsvg_handle_get_dimensions_sub (RsvgHandle* handle, RsvgDimensionData* dimension_data, const(char)* id);
rsvgbool rsvg_handle_get_position_sub (RsvgHandle* handle, RsvgPositionData* position_data, const(char)* id);

rsvgbool rsvg_handle_has_sub (RsvgHandle* handle, const(char)* id);

/* GIO APIs */

/**
 * RsvgHandleFlags:
 * @RSVG_HANDLE_FLAGS_NONE: none
 * @RSVG_HANDLE_FLAG_UNLIMITED: Allow any SVG XML without size limitations.
 *   For security reasons, this should only be used for trusted input!
 *   Since: 2.40.3
 * @RSVG_HANDLE_FLAG_KEEP_IMAGE_DATA: Keeps the image data when loading images,
 *  for use by cairo when painting to e.g. a PDF surface. This will make the
 *  resulting PDF file smaller and faster.
 *  Since: 2.40.3
 */
/*< flags >*/
/*
alias RsvgHandleFlags = int;
enum : RsvgHandleFlags {
  RSVG_HANDLE_FLAGS_NONE           = 0,
  RSVG_HANDLE_FLAG_UNLIMITED       = 1 << 0,
  RSVG_HANDLE_FLAG_KEEP_IMAGE_DATA = 1 << 1
}
*/

//RsvgHandle* rsvg_handle_new_with_flags (RsvgHandleFlags flags);
//void rsvg_handle_set_base_gfile (RsvgHandle* handle, GFile* base_file);
//rsvgbool rsvg_handle_read_stream_sync (RsvgHandle* handle, GInputStream* stream, GCancellable* cancellable, GError** error);
//RsvgHandle* rsvg_handle_new_from_gfile_sync (GFile* file, RsvgHandleFlags flags, GCancellable* cancellable, GError** error);
//RsvgHandle *rsvg_handle_new_from_stream_sync (GInputStream* input_stream, GFile* base_file, RsvgHandleFlags flags, GCancellable* cancellable, GError** error);

RsvgHandle* rsvg_handle_new_from_data (const(void)* data, usize data_len, GError** error);
RsvgHandle* rsvg_handle_new_from_file (const(char)* file_name, GError** error);


rsvgbool rsvg_handle_render_cairo (RsvgHandle* handle, cairo_t* cr);
rsvgbool rsvg_handle_render_cairo_sub (RsvgHandle* handle, cairo_t* cr, const(char)* id);
