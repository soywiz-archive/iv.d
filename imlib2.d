/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// docs: https://docs.enlightenment.org/api/imlib2/html/imlib2_8c.html
// sample: https://docs.enlightenment.org/api/imlib2/html/
module iv.imlib2 /*is aliced*/;
pragma(lib, "Imlib2");
import iv.x11;
import iv.alice;

extern(C) nothrow @nogc:
/*
# ifndef X_DISPLAY_MISSING
#  include <X11/Xlib.h>
# endif
*/

alias DATA64 = ulong;
alias DATA32 = uint;
alias DATA16 = ushort;
alias DATA8 = ubyte;

/* opaque data types */
//typedef Imlib_Context = void*;
alias Imlib_Context = void*;
//typedef Imlib_Image = void*;
alias Imlib_Image = void*;
//typedef Imlib_Color_Modifier = void*;
alias Imlib_Color_Modifier = void*;
//typedef Imlib_Updates = void*;
alias Imlib_Updates = void*;
//typedef Imlib_Font = void*;
alias Imlib_Font = void*;
//typedef Imlib_Color_Range = void*;
alias Imlib_Color_Range = void*;
//typedef Imlib_Filter = void*;
alias Imlib_Filter = void*;
alias Imlib_Border = _imlib_border;
alias Imlib_Color = _imlib_color;
//typedef ImlibPolygon = void*;
alias ImlibPolygon = void*;

/* blending operations */
enum /*_imlib_operation*/
{
   IMLIB_OP_COPY,
   IMLIB_OP_ADD,
   IMLIB_OP_SUBTRACT,
   IMLIB_OP_RESHADE
}

enum /*_imlib_text_direction*/
{
   IMLIB_TEXT_TO_RIGHT = 0,
   IMLIB_TEXT_TO_LEFT = 1,
   IMLIB_TEXT_TO_DOWN = 2,
   IMLIB_TEXT_TO_UP = 3,
   IMLIB_TEXT_TO_ANGLE = 4
}

enum /*_imlib_load_error*/
{
   IMLIB_LOAD_ERROR_NONE,
   IMLIB_LOAD_ERROR_FILE_DOES_NOT_EXIST,
   IMLIB_LOAD_ERROR_FILE_IS_DIRECTORY,
   IMLIB_LOAD_ERROR_PERMISSION_DENIED_TO_READ,
   IMLIB_LOAD_ERROR_NO_LOADER_FOR_FILE_FORMAT,
   IMLIB_LOAD_ERROR_PATH_TOO_LONG,
   IMLIB_LOAD_ERROR_PATH_COMPONENT_NON_EXISTANT,
   IMLIB_LOAD_ERROR_PATH_COMPONENT_NOT_DIRECTORY,
   IMLIB_LOAD_ERROR_PATH_POINTS_OUTSIDE_ADDRESS_SPACE,
   IMLIB_LOAD_ERROR_TOO_MANY_SYMBOLIC_LINKS,
   IMLIB_LOAD_ERROR_OUT_OF_MEMORY,
   IMLIB_LOAD_ERROR_OUT_OF_FILE_DESCRIPTORS,
   IMLIB_LOAD_ERROR_PERMISSION_DENIED_TO_WRITE,
   IMLIB_LOAD_ERROR_OUT_OF_DISK_SPACE,
   IMLIB_LOAD_ERROR_UNKNOWN
}

/* Encodings known to Imlib2 (so far) */
enum /*_imlib_TTF_encoding*/
{
   IMLIB_TTF_ENCODING_ISO_8859_1,
   IMLIB_TTF_ENCODING_ISO_8859_2,
   IMLIB_TTF_ENCODING_ISO_8859_3,
   IMLIB_TTF_ENCODING_ISO_8859_4,
   IMLIB_TTF_ENCODING_ISO_8859_5
}

/*
typedef enum _imlib_operation Imlib_Operation;
typedef enum _imlib_load_error Imlib_Load_Error;
typedef enum _imlib_load_error ImlibLoadError;
typedef enum _imlib_text_direction Imlib_Text_Direction;
typedef enum _imlib_TTF_encoding Imlib_TTF_Encoding;
*/
alias Imlib_Operation = int;
alias Imlib_Load_Error = int;
alias ImlibLoadError = int;
alias Imlib_Text_Direction = int;
alias Imlib_TTF_Encoding = int;

struct _imlib_border
{
   int left, right, top, bottom;
}

struct _imlib_color
{
   int alpha, red, green, blue;
}

/* Progressive loading callbacks */
/*typedef*/alias Imlib_Progress_Function = int function (
  Imlib_Image im, char percent,
  int update_x, int update_y,
  int update_w, int update_h);
//typedef Imlib_Data_Destructor_Function = void function (Imlib_Image im, void *data);
alias Imlib_Data_Destructor_Function = void function (Imlib_Image im, void *data);

/*EAPI*/ Imlib_Context imlib_context_new ();
/*EAPI*/ void imlib_context_free(Imlib_Context context);

/*EAPI*/ void imlib_context_push(Imlib_Context context);
/*EAPI*/ void imlib_context_pop();
/*EAPI*/ Imlib_Context imlib_context_get();

/* context setting */
//# ifndef X_DISPLAY_MISSING
/*EAPI*/ void imlib_context_set_display(Display * display);
/*EAPI*/ void imlib_context_disconnect_display();
/*EAPI*/ void imlib_context_set_visual(Visual * visual);
/*EAPI*/ void imlib_context_set_colormap(Colormap colormap);
/*EAPI*/ void imlib_context_set_drawable(Drawable drawable);
/*EAPI*/ void imlib_context_set_mask(Pixmap mask);
//# endif
/*EAPI*/ void imlib_context_set_dither_mask(char dither_mask);
/*EAPI*/ void imlib_context_set_mask_alpha_threshold(int mask_alpha_threshold);
/*EAPI*/ void imlib_context_set_anti_alias(char anti_alias);
/*EAPI*/ void imlib_context_set_dither(char dither);
/*EAPI*/ void imlib_context_set_blend(char blend);
/*EAPI*/ void imlib_context_set_color_modifier(Imlib_Color_Modifier color_modifier);
/*EAPI*/ void imlib_context_set_operation(Imlib_Operation operation);
/*EAPI*/ void imlib_context_set_font(Imlib_Font font);
/*EAPI*/ void imlib_context_set_direction(Imlib_Text_Direction direction);
/*EAPI*/ void imlib_context_set_angle(double angle);
/*EAPI*/ void imlib_context_set_color(int red, int green, int blue, int alpha);
/*EAPI*/ void imlib_context_set_color_hsva(float hue, float saturation, float value, int alpha);
/*EAPI*/ void imlib_context_set_color_hlsa(float hue, float lightness, float saturation, int alpha);
/*EAPI*/ void imlib_context_set_color_cmya(int cyan, int magenta, int yellow, int alpha);
/*EAPI*/ void imlib_context_set_color_range(Imlib_Color_Range color_range);
/*EAPI*/ void imlib_context_set_progress_function(Imlib_Progress_Function
                                                 progress_function);
/*EAPI*/ void imlib_context_set_progress_granularity(char progress_granularity);
/*EAPI*/ void imlib_context_set_image(Imlib_Image image);
/*EAPI*/ void imlib_context_set_cliprect(int x, int y, int w, int h);
/*EAPI*/ void imlib_context_set_TTF_encoding(Imlib_TTF_Encoding encoding);

/* context getting */
//# ifndef X_DISPLAY_MISSING
/*EAPI*/ Display *imlib_context_get_display();
/*EAPI*/ Visual *imlib_context_get_visual();
/*EAPI*/ Colormap imlib_context_get_colormap();
/*EAPI*/ Drawable imlib_context_get_drawable();
/*EAPI*/ Pixmap imlib_context_get_mask();
//# endif
/*EAPI*/ char imlib_context_get_dither_mask();
/*EAPI*/ char imlib_context_get_anti_alias();
/*EAPI*/ int imlib_context_get_mask_alpha_threshold();
/*EAPI*/ char imlib_context_get_dither();
/*EAPI*/ char imlib_context_get_blend();
/*EAPI*/ Imlib_Color_Modifier imlib_context_get_color_modifier();
/*EAPI*/ Imlib_Operation imlib_context_get_operation();
/*EAPI*/ Imlib_Font imlib_context_get_font();
/*EAPI*/ double imlib_context_get_angle();
/*EAPI*/ Imlib_Text_Direction imlib_context_get_direction();
/*EAPI*/ void imlib_context_get_color(int *red, int *green, int *blue, int *alpha);
/*EAPI*/ void imlib_context_get_color_hsva(float *hue, float *saturation, float *value, int *alpha);
/*EAPI*/ void imlib_context_get_color_hlsa(float *hue, float *lightness, float *saturation, int *alpha);
/*EAPI*/ void imlib_context_get_color_cmya(int *cyan, int *magenta, int *yellow, int *alpha);
/*EAPI*/ Imlib_Color *imlib_context_get_imlib_color();
/*EAPI*/ Imlib_Color_Range imlib_context_get_color_range();
/*EAPI*/ Imlib_Progress_Function imlib_context_get_progress_function();
/*EAPI*/ char imlib_context_get_progress_granularity();
/*EAPI*/ Imlib_Image imlib_context_get_image();
/*EAPI*/ void imlib_context_get_cliprect(int *x, int *y, int *w, int *h);
/*EAPI*/ Imlib_TTF_Encoding imlib_context_get_TTF_encoding();

/*EAPI*/ int imlib_get_cache_size();
/*EAPI*/ void imlib_set_cache_size(int bytes);
/*EAPI*/ int imlib_get_color_usage();
/*EAPI*/ void imlib_set_color_usage(int max);
/*EAPI*/ void imlib_flush_loaders();
//# ifndef X_DISPLAY_MISSING
/*EAPI*/ int imlib_get_visual_depth(Display * display, Visual * visual);
/*EAPI*/ Visual *imlib_get_best_visual(Display * display, int screen,
                                      int *depth_return);
//# endif

/*EAPI*/ Imlib_Image imlib_load_image(const(char)* file);
/*EAPI*/ Imlib_Image imlib_load_image_immediately(const(char)* file);
/*EAPI*/ Imlib_Image imlib_load_image_without_cache(const(char)* file);
/*EAPI*/ Imlib_Image imlib_load_image_immediately_without_cache(const(char)* file);
/*EAPI*/ Imlib_Image imlib_load_image_with_error_return(const(char)* file,
                                                       Imlib_Load_Error *
                                                       error_return);
/*EAPI*/ void imlib_free_image();
/*EAPI*/ void imlib_free_image_and_decache();

/* query/modify image parameters */
/*EAPI*/ int imlib_image_get_width();
/*EAPI*/ int imlib_image_get_height();
/*EAPI*/ const(char)* imlib_image_get_filename();
/*EAPI*/ DATA32 *imlib_image_get_data(); // b, g, r, a
/*EAPI*/ const(DATA32) *imlib_image_get_data_for_reading_only();
/*EAPI*/ void imlib_image_put_back_data(DATA32 * data);
/*EAPI*/ char imlib_image_has_alpha();
/*EAPI*/ void imlib_image_set_changes_on_disk();
/*EAPI*/ void imlib_image_get_border(Imlib_Border * border);
/*EAPI*/ void imlib_image_set_border(Imlib_Border * border);
/*EAPI*/ void imlib_image_set_format(const(char)* format);
/*EAPI*/ void imlib_image_set_irrelevant_format(char irrelevant);
/*EAPI*/ void imlib_image_set_irrelevant_border(char irrelevant);
/*EAPI*/ void imlib_image_set_irrelevant_alpha(char irrelevant);
/*EAPI*/ char *imlib_image_format();
/*EAPI*/ void imlib_image_set_has_alpha(char has_alpha);
/*EAPI*/ void imlib_image_query_pixel(int x, int y, Imlib_Color * color_return);
/*EAPI*/ void imlib_image_query_pixel_hsva(int x, int y, float *hue, float *saturation, float *value, int *alpha);
/*EAPI*/ void imlib_image_query_pixel_hlsa(int x, int y, float *hue, float *lightness, float *saturation, int *alpha);
/*EAPI*/ void imlib_image_query_pixel_cmya(int x, int y, int *cyan, int *magenta, int *yellow, int *alpha);

/* rendering functions */
//# ifndef X_DISPLAY_MISSING
/*EAPI*/ void imlib_render_pixmaps_for_whole_image(Pixmap * pixmap_return,
                                                  Pixmap * mask_return);
/*EAPI*/ void imlib_render_pixmaps_for_whole_image_at_size(Pixmap * pixmap_return,
                                                          Pixmap * mask_return,
                                                          int width, int height);
/*EAPI*/ void imlib_free_pixmap_and_mask(Pixmap pixmap);
/*EAPI*/ void imlib_render_image_on_drawable(int x, int y);
/*EAPI*/ void imlib_render_image_on_drawable_at_size(int x, int y, int width,
                                                    int height);
/*EAPI*/ void imlib_render_image_part_on_drawable_at_size(int source_x,
                                                         int source_y,
                                                         int source_width,
                                                         int source_height, int x,
                                                         int y, int width,
                                                         int height);
/*EAPI*/ DATA32 imlib_render_get_pixel_color();
//# endif
/*EAPI*/ void imlib_blend_image_onto_image(Imlib_Image source_image,
                                          char merge_alpha, int source_x,
                                          int source_y, int source_width,
                                          int source_height, int destination_x,
                                          int destination_y, int destination_width,
                                          int destination_height);

/* creation functions */
/*EAPI*/ Imlib_Image imlib_create_image(int width, int height);
/*EAPI*/ Imlib_Image imlib_create_image_using_data(int width, int height,
                                                  DATA32 * data);
/*EAPI*/ Imlib_Image imlib_create_image_using_copied_data(int width, int height,
                                                         DATA32 * data);
//# ifndef X_DISPLAY_MISSING
/*EAPI*/ Imlib_Image imlib_create_image_from_drawable(Pixmap mask, int x, int y,
                                                     int width, int height,
                                                     char need_to_grab_x);
/*EAPI*/ Imlib_Image imlib_create_image_from_ximage(XImage *image, XImage *mask, int x, int y,
                                                     int width, int height,
                                                     char need_to_grab_x);
/*EAPI*/ Imlib_Image imlib_create_scaled_image_from_drawable(Pixmap mask,
                                                            int source_x,
                                                            int source_y,
                                                            int source_width,
                                                            int source_height,
                                                            int destination_width,
                                                            int destination_height,
                                                            char need_to_grab_x,
                                                            char
                                                            get_mask_from_shape);
/*EAPI*/ char imlib_copy_drawable_to_image(Pixmap mask, int x, int y, int width,
                                          int height, int destination_x,
                                          int destination_y, char need_to_grab_x);
//# endif
/*EAPI*/ Imlib_Image imlib_clone_image();
/*EAPI*/ Imlib_Image imlib_create_cropped_image(int x, int y, int width,
                                               int height);
/*EAPI*/ Imlib_Image imlib_create_cropped_scaled_image(int source_x, int source_y,
                                                      int source_width,
                                                      int source_height,
                                                      int destination_width,
                                                      int destination_height);

/* imlib updates. lists of rectangles for storing required update draws */
/*EAPI*/ Imlib_Updates imlib_updates_clone(Imlib_Updates updates);
/*EAPI*/ Imlib_Updates imlib_update_append_rect(Imlib_Updates updates, int x, int y,
                                               int w, int h);
/*EAPI*/ Imlib_Updates imlib_updates_merge(Imlib_Updates updates, int w, int h);
/*EAPI*/ Imlib_Updates imlib_updates_merge_for_rendering(Imlib_Updates updates,
                                                        int w, int h);
/*EAPI*/ void imlib_updates_free(Imlib_Updates updates);
/*EAPI*/ Imlib_Updates imlib_updates_get_next(Imlib_Updates updates);
/*EAPI*/ void imlib_updates_get_coordinates(Imlib_Updates updates, int *x_return,
                                           int *y_return, int *width_return,
                                           int *height_return);
/*EAPI*/ void imlib_updates_set_coordinates(Imlib_Updates updates, int x, int y,
                                           int width, int height);
/*EAPI*/ void imlib_render_image_updates_on_drawable(Imlib_Updates updates, int x,
                                                    int y);
/*EAPI*/ Imlib_Updates imlib_updates_init();
/*EAPI*/ Imlib_Updates imlib_updates_append_updates(Imlib_Updates updates,
                                                   Imlib_Updates appended_updates);

/* image modification */
/*EAPI*/ void imlib_image_flip_horizontal();
/*EAPI*/ void imlib_image_flip_vertical();
/*EAPI*/ void imlib_image_flip_diagonal();
/*EAPI*/ void imlib_image_orientate(int orientation);
/*EAPI*/ void imlib_image_blur(int radius);
/*EAPI*/ void imlib_image_sharpen(int radius);
/*EAPI*/ void imlib_image_tile_horizontal();
/*EAPI*/ void imlib_image_tile_vertical();
/*EAPI*/ void imlib_image_tile();

/* fonts and text */
/*EAPI*/ Imlib_Font imlib_load_font(const(char)* font_name);
/*EAPI*/ void imlib_free_font();
   /* NB! The four functions below are deprecated. */
/*EAPI*/ int imlib_insert_font_into_fallback_chain(Imlib_Font font, Imlib_Font fallback_font);
/*EAPI*/ void imlib_remove_font_from_fallback_chain(Imlib_Font fallback_font);
/*EAPI*/ Imlib_Font imlib_get_prev_font_in_fallback_chain(Imlib_Font fn);
/*EAPI*/ Imlib_Font imlib_get_next_font_in_fallback_chain(Imlib_Font fn);
   /* NB! The four functions above are deprecated. */
/*EAPI*/ void imlib_text_draw(int x, int y, const(char)* text);
/*EAPI*/ void imlib_text_draw_with_return_metrics(int x, int y, const(char)* text,
                                                 int *width_return,
                                                 int *height_return,
                                                 int *horizontal_advance_return,
                                                 int *vertical_advance_return);
/*EAPI*/ void imlib_get_text_size(const(char)* text, int *width_return,
                                 int *height_return);
/*EAPI*/ void imlib_get_text_advance(const(char)* text,
             int *horizontal_advance_return,
             int *vertical_advance_return);
/*EAPI*/ int imlib_get_text_inset(const(char)* text);
/*EAPI*/ void imlib_add_path_to_font_path(const(char)* path);
/*EAPI*/ void imlib_remove_path_from_font_path(const(char)* path);
/*EAPI*/ char **imlib_list_font_path(int *number_return);
/*EAPI*/ int imlib_text_get_index_and_location(const(char)* text, int x, int y,
                                              int *char_x_return,
                                              int *char_y_return,
                                              int *char_width_return,
                                              int *char_height_return);
/*EAPI*/ void imlib_text_get_location_at_index(const(char)* text, int index,
                                              int *char_x_return,
                                              int *char_y_return,
                                              int *char_width_return,
                                              int *char_height_return);
/*EAPI*/ char **imlib_list_fonts(int *number_return);
/*EAPI*/ void imlib_free_font_list(char **font_list, int number);
/*EAPI*/ int imlib_get_font_cache_size();
/*EAPI*/ void imlib_set_font_cache_size(int bytes);
/*EAPI*/ void imlib_flush_font_cache();
/*EAPI*/ int imlib_get_font_ascent();
/*EAPI*/ int imlib_get_font_descent();
/*EAPI*/ int imlib_get_maximum_font_ascent();
/*EAPI*/ int imlib_get_maximum_font_descent();

/* color modifiers */
/*EAPI*/ Imlib_Color_Modifier imlib_create_color_modifier();
/*EAPI*/ void imlib_free_color_modifier();
/*EAPI*/ void imlib_modify_color_modifier_gamma(double gamma_value);
/*EAPI*/ void imlib_modify_color_modifier_brightness(double brightness_value);
/*EAPI*/ void imlib_modify_color_modifier_contrast(double contrast_value);
/*EAPI*/ void imlib_set_color_modifier_tables(DATA8 * red_table,
                                             DATA8 * green_table,
                                             DATA8 * blue_table,
                                             DATA8 * alpha_table);
/*EAPI*/ void imlib_get_color_modifier_tables(DATA8 * red_table,
                                             DATA8 * green_table,
                                             DATA8 * blue_table,
                                             DATA8 * alpha_table);
/*EAPI*/ void imlib_reset_color_modifier();
/*EAPI*/ void imlib_apply_color_modifier();
/*EAPI*/ void imlib_apply_color_modifier_to_rectangle(int x, int y, int width,
                                                     int height);

/* drawing on images */
/*EAPI*/ Imlib_Updates imlib_image_draw_pixel(int x, int y, char make_updates);
/*EAPI*/ Imlib_Updates imlib_image_draw_line(int x1, int y1, int x2, int y2,
                                            char make_updates);
/*EAPI*/ void imlib_image_draw_rectangle(int x, int y, int width, int height);
/*EAPI*/ void imlib_image_fill_rectangle(int x, int y, int width, int height);
/*EAPI*/ void imlib_image_copy_alpha_to_image(Imlib_Image image_source, int x,
                                             int y);
/*EAPI*/ void imlib_image_copy_alpha_rectangle_to_image(Imlib_Image image_source,
                                                       int x, int y, int width,
                                                       int height,
                                                       int destination_x,
                                                       int destination_y);
/*EAPI*/ void imlib_image_scroll_rect(int x, int y, int width, int height,
                                     int delta_x, int delta_y);
/*EAPI*/ void imlib_image_copy_rect(int x, int y, int width, int height, int new_x,
                                   int new_y);

/* polygons */
/*EAPI*/ ImlibPolygon imlib_polygon_new();
/*EAPI*/ void imlib_polygon_free(ImlibPolygon poly);
/*EAPI*/ void imlib_polygon_add_point(ImlibPolygon poly, int x, int y);
/*EAPI*/ void imlib_image_draw_polygon(ImlibPolygon poly, ubyte closed);
/*EAPI*/ void imlib_image_fill_polygon(ImlibPolygon poly);
/*EAPI*/ void imlib_polygon_get_bounds(ImlibPolygon poly, int *px1, int *py1,
                                      int *px2, int *py2);
/*EAPI*/ ubyte imlib_polygon_contains_point(ImlibPolygon poly, int x, int y);

/* ellipses */
/*EAPI*/ void imlib_image_draw_ellipse(int xc, int yc, int a, int b);
/*EAPI*/ void imlib_image_fill_ellipse(int xc, int yc, int a, int b);

/* color ranges */
/*EAPI*/ Imlib_Color_Range imlib_create_color_range();
/*EAPI*/ void imlib_free_color_range();
/*EAPI*/ void imlib_add_color_to_color_range(int distance_away);
/*EAPI*/ void imlib_image_fill_color_range_rectangle(int x, int y, int width,
                                                    int height, double angle);
/*EAPI*/ void imlib_image_fill_hsva_color_range_rectangle(int x, int y, int width,
                                                         int height, double angle);

/* image data */
/*EAPI*/ void imlib_image_attach_data_value(const(char)* key, void *data, int value,
                                           Imlib_Data_Destructor_Function
                                           destructor_function);
/*EAPI*/ void *imlib_image_get_attached_data(const(char)* key);
/*EAPI*/ int imlib_image_get_attached_value(const(char)* key);
/*EAPI*/ void imlib_image_remove_attached_data_value(const(char)* key);
/*EAPI*/ void imlib_image_remove_and_free_attached_data_value(const(char)* key);

/* saving */
/*EAPI*/ void imlib_save_image(const(char)* filename);
/*EAPI*/ void imlib_save_image_with_error_return(const(char)* filename,
                                                Imlib_Load_Error * error_return);

/* FIXME: */
/* need to add arbitrary rotation routines */

/* rotation/skewing */
/*EAPI*/ Imlib_Image imlib_create_rotated_image(double angle);

/* rotation from buffer to context (without copying)*/
/*EAPI*/ void imlib_rotate_image_from_buffer(double angle,
               Imlib_Image source_image);

/*EAPI*/ void imlib_blend_image_onto_image_at_angle(Imlib_Image source_image,
                                                   char merge_alpha, int source_x,
                                                   int source_y, int source_width,
                                                   int source_height,
                                                   int destination_x,
                                                   int destination_y, int angle_x,
                                                   int angle_y);
/*EAPI*/ void imlib_blend_image_onto_image_skewed(Imlib_Image source_image,
                                                 char merge_alpha, int source_x,
                                                 int source_y, int source_width,
                                                 int source_height,
                                                 int destination_x,
                                                 int destination_y, int h_angle_x,
                                                 int h_angle_y, int v_angle_x,
                                                 int v_angle_y);
//# ifndef X_DISPLAY_MISSING
/*EAPI*/ void imlib_render_image_on_drawable_skewed(int source_x, int source_y,
                                                   int source_width,
                                                   int source_height,
                                                   int destination_x,
                                                   int destination_y,
                                                   int h_angle_x, int h_angle_y,
                                                   int v_angle_x, int v_angle_y);
/*EAPI*/ void imlib_render_image_on_drawable_at_angle(int source_x, int source_y,
                                                     int source_width,
                                                     int source_height,
                                                     int destination_x,
                                                     int destination_y,
                                                     int angle_x, int angle_y);
//# endif

/* image filters */
/*EAPI*/ void imlib_image_filter();
/*EAPI*/ Imlib_Filter imlib_create_filter(int initsize);
/*EAPI*/ void imlib_context_set_filter(Imlib_Filter filter);
/*EAPI*/ Imlib_Filter imlib_context_get_filter();
/*EAPI*/ void imlib_free_filter();
/*EAPI*/ void imlib_filter_set(int xoff, int yoff, int a, int r, int g, int b);
/*EAPI*/ void imlib_filter_set_alpha(int xoff, int yoff, int a, int r, int g,
                                    int b);
/*EAPI*/ void imlib_filter_set_red(int xoff, int yoff, int a, int r, int g, int b);
/*EAPI*/ void imlib_filter_set_green(int xoff, int yoff, int a, int r, int g,
                                    int b);
/*EAPI*/ void imlib_filter_set_blue(int xoff, int yoff, int a, int r, int g, int b);
/*EAPI*/ void imlib_filter_constants(int a, int r, int g, int b);
/*EAPI*/ void imlib_filter_divisors(int a, int r, int g, int b);

/*EAPI*/ void imlib_apply_filter(char *script, ...);

/*EAPI*/ void imlib_image_clear();
/*EAPI*/ void imlib_image_clear_color(int r, int g, int b, int a);
