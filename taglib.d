/* *********************************************************************** *
 *   This library is free software; you can redistribute it and/or modify  *
 *   it  under the terms of the GNU Lesser General Public License version  *
 *   2.1 as published by the Free Software Foundation.                     *
 *                                                                         *
 *   This library is distributed in the hope that it will be useful, but   *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   Lesser General Public License for more details.                       *
 *                                                                         *
 *   You should have received a copy of the GNU Lesser General Public      *
 *   License along with this library; if not, write to the Free Software   *
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  *
 *   USA                                                                   *
 * *********************************************************************** */
// wrapper coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
///WARING! this MAY BE 64-bit unsafe!
module iv.taglib is aliced;

pragma(lib, "tag_c");
pragma(lib, "tag");


// ////////////////////////////////////////////////////////////////////////// //
class TagLibException : Exception {
  this (string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null) @safe @pure @nothrow {
    super(msg, file, line, next);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct TagFile {
  enum FileType {
    Autodetect = -1, // k8 extension, do not use in C API!
    MPEG = 0,
    OggVorbis,
    FLAC,
    MPC,
    OggFlac,
    WavPack,
    Speex,
    TrueAudio,
    MP4,
    ASF
  }


  this (string fname, FileType type=FileType.Autodetect) {
    loadInfo(fname, type);
  }

  ~this () {
    clear();
  }

  void clear () @trusted {
    if (mInited) {
      mInited = false;
      taglib_file_free(mFL);
      this = this.init;
    }
  }

  void save () {
    if (!mInited) throw new TagLibException("can't save tags object to empty file");
    if (!taglib_file_save(mFL)) throw new TagLibException("can't save tags object to file '"~mFName~"'");
  }

  @property bool valid () const @safe pure nothrow { return mInited; }

  @property string filename () const @safe pure nothrow { return (mInited ? mFName : null); }

  mixin(strPropMixin!"artist");
  mixin(strPropMixin!"album");
  mixin(strPropMixin!"title");
  mixin(strPropMixin!"genre");
  mixin(strPropMixin!"comment");

  @property uint year () const @safe pure nothrow { return (mInited ? mYear : 0); }
  @property void year (uint v) {
    if (!mInited) throw new TagLibException("can't set YEAR tag for empty file");
    if (v > 0) {
      uint ov;
      if (v < 50) v += 2000;
      else if (v < 100) v += 1900;
      else if (v < 1930) v = 0;
      if (v < 1930 || v > 2099) {
        import std.conv : to;
        throw new TagLibException("invalid YEAR tag value: "~to!string(ov));
      }
    }
    mYear = v;
    taglib_tag_set_year(mTags, v);
  }

  @property uint track () const @safe pure nothrow { return (mInited ? mTrack : 0); }
  @property void track (uint v) {
    if (!mInited) throw new TagLibException("can't set TRACK tag for empty file");
    if (v > 999) {
      import std.conv : to;
      throw new TagLibException("invalid TRACK tag value: "~to!string(v));
    }
    mTrack = v;
    taglib_tag_set_track(mTags, v);
  }

  mixin(uintPropMixin!"length"); // file length in seconds
  mixin(uintPropMixin!"channels"); // number of channels in file
  mixin(uintPropMixin!"bitrate"); // file bitrate in kb/s
  mixin(uintPropMixin!"samplerate"); // file samplerate in Hz

private:
  enum uintPropMixin(string propName) =
    `@property uint `~propName~` () {`~
    `if (!mInited) return 0;`~
    `auto tp = taglib_file_audioproperties(mFL);`~
    `if (!tp) throw new TagLibException("can't get audio properties for file '"~mFName~"'");`~
    `auto r = taglib_audioproperties_`~propName~`(tp);`~
    `return (r < 0 ? 0 : r);`~
    `}`;

  template strPropMixin (string propName) {
    import std.string : capitalize, toUpper;
    enum strPropMixin =
      `@property void `~propName~` (string v) {`~
      `import std.string : toStringz;`~
      `if (!mInited) throw new TagLibException("can't set `~toUpper(propName)~` tag for empty file");`~
      `auto s = trimStr(v);`~
      `taglib_tag_set_`~propName~`(mTags, s.toStringz);`~
      `m`~capitalize(propName)~` = s.idup;`~
      `}`~
      `@property string `~propName~` () const @trusted @nothrow { return (mInited ? m`~capitalize(propName)~` : null); }`;
  }

  static string stripL() (string str) {
    import std.uni : isWhite;
    foreach (immutable i, immutable dchar c; str) {
      if (c != 0 && c != '_' && !isWhite(c)) return str[i..$];
    }
    return null;
  }

  static string stripR() (string str) {
    import std.uni : isWhite;
    import std.utf : codeLength;
    foreach_reverse (immutable i, immutable dchar c; str) {
      if (c != 0 && c != '_' && !isWhite(c)) return str[0..i+codeLength!char(c)];
    }
    return null;
  }

  static string trimStr() (string s) {
    import std.array : appender;
    auto res = appender!string();
    dchar pch = 0;
    foreach (dchar ch; s) {
      if (ch < ' ') ch = ' ';
      // remove duplicate underlines
      if (pch == '_' && ch == '_') { pch = ch; continue; }
      // remove duplicate spaces
      if (pch == ' ' && ch == ' ') { pch = ch; continue; }
      res.put(ch);
    }
    return stripL(stripR(res.data));
  }

  static string trimStr() (char* s) {
    if (s !is null) {
      import std.conv : to;
      auto res = trimStr(to!string(s));
      taglib_free(s);
      return res;
    }
    return null;
  }

  void loadInfo (string fname, FileType type=FileType.Autodetect) {
    import std.string : toStringz;
    clear();
    if (type == FileType.Autodetect) {
      mFL = taglib_file_new(fname.toStringz);
    } else {
      mFL = taglib_file_new_type(fname.toStringz, cast(TagLibFileType)type);
    }
    scope(failure) clear();
    if (mFL is null) throw new TagLibException("can't open file '"~fname~"'");
    mTags = taglib_file_tag(mFL);
    if (mTags is null) throw new TagLibException("can't init tags object for file '"~fname~"'");
    mArtist = trimStr(taglib_tag_artist(mTags));
    mAlbum = trimStr(taglib_tag_album(mTags));
    mTitle = trimStr(taglib_tag_title(mTags));
    mGenre = trimStr(taglib_tag_genre(mTags));
    mYear = taglib_tag_year(mTags);
    if (mYear > 0) {
      if (mYear < 50) mYear += 2000;
      else if (mYear < 100) mYear += 1900;
      else if (mYear < 1930) mYear = 0;
    }
    if (mYear < 1930 || mYear > 2099) mYear = 0;
    mTrack = taglib_tag_track(mTags);
    if (mTrack > 999) mTrack = 0;
    mFName = fname.idup;
    mInited = true;
  }

private:
  bool mInited;
  TagLibFile mFL;
  TagLibTag mTags;
  string mFName;
  string mArtist;
  string mAlbum;
  string mTitle;
  string mComment;
  string mGenre;
  uint mYear;
  uint mTrack;
}


// ////////////////////////////////////////////////////////////////////////// //
shared static this () {
  taglib_set_strings_unicode(true);
  taglib_set_string_management_enabled(false);
}


// ////////////////////////////////////////////////////////////////////////// //
private:
extern(C):
@nothrow:
@trusted:

typedef TagLibFile = void*;
typedef TagLibTag = void*;
typedef TagLibAudioProperties = void*;
typedef TagBool = uint;
alias TagCString = const(char)*; // can't use typedef here


/*!
 * By default all strings coming into or out of TagLib's C API are in UTF8.
 * However, it may be desirable for TagLib to operate on Latin1 (ISO-8859-1)
 * strings in which case this should be set to FALSE.
 */
void taglib_set_strings_unicode (TagBool unicode);

/*!
 * TagLib can keep track of strings that are created when outputting tag values
 * and clear them using taglib_tag_clear_strings().  This is enabled by default.
 * However if you wish to do more fine grained management of strings, you can do
 * so by setting \a management to FALSE.
 */
void taglib_set_string_management_enabled (TagBool management);

/*!
 * Explicitly free a string returned from TagLib
 */
void taglib_free (void* pointer);


/*******************************************************************************
 * File API
 ******************************************************************************/
enum TagLibFileType {
  MPEG,
  OggVorbis,
  FLAC,
  MPC,
  OggFlac,
  WavPack,
  Speex,
  TrueAudio,
  MP4,
  ASF
}

/*!
 * Creates a TagLib file based on \a filename.  TagLib will try to guess the file
 * type.
 *
 * \returns NULL if the file type cannot be determined or the file cannot
 * be opened.
 */
TagLibFile taglib_file_new (TagCString filename);

/*!
 * Creates a TagLib file based on \a filename.  Rather than attempting to guess
 * the type, it will use the one specified by \a type.
 */
TagLibFile taglib_file_new_type (TagCString filename, TagLibFileType type);

/*!
 * Frees and closes the file.
 */
void taglib_file_free (TagLibFile file);

/*!
 * Returns true if the file is open and readble and valid information for
 * the Tag and / or AudioProperties was found.
 */

TagBool taglib_file_is_valid (const(TagLibFile) file);

/*!
 * Returns a pointer to the tag associated with this file.  This will be freed
 * automatically when the file is freed.
 */
TagLibTag taglib_file_tag (const(TagLibFile) file);

/*!
 * Returns a pointer to the the audio properties associated with this file.  This
 * will be freed automatically when the file is freed.
 */
const(TagLibAudioProperties) taglib_file_audioproperties (const(TagLibFile) file);

/*!
 * Saves the \a file to disk.
 */
TagBool taglib_file_save (TagLibFile file);


/******************************************************************************
 * Tag API
 ******************************************************************************/

/*!
 * Returns a string with this tag's title.
 *
 * \note By default this string should be UTF8 encoded and its memory should be
 * freed using taglib_tag_free_strings().
 */
char *taglib_tag_title (const(TagLibTag) tag);

/*!
 * Returns a string with this tag's artist.
 *
 * \note By default this string should be UTF8 encoded and its memory should be
 * freed using taglib_tag_free_strings().
 */
char *taglib_tag_artist (const(TagLibTag) tag);

/*!
 * Returns a string with this tag's album name.
 *
 * \note By default this string should be UTF8 encoded and its memory should be
 * freed using taglib_tag_free_strings().
 */
char *taglib_tag_album (const(TagLibTag) tag);

/*!
 * Returns a string with this tag's comment.
 *
 * \note By default this string should be UTF8 encoded and its memory should be
 * freed using taglib_tag_free_strings().
 */
char *taglib_tag_comment (const(TagLibTag) tag);

/*!
 * Returns a string with this tag's genre.
 *
 * \note By default this string should be UTF8 encoded and its memory should be
 * freed using taglib_tag_free_strings().
 */
char *taglib_tag_genre (const(TagLibTag) tag);

/*!
 * Returns the tag's year or 0 if year is not set.
 */
uint taglib_tag_year (const(TagLibTag) tag);

/*!
 * Returns the tag's track number or 0 if track number is not set.
 */
uint taglib_tag_track (const(TagLibTag) tag);

/*!
 * Sets the tag's title.
 *
 * \note By default this string should be UTF8 encoded.
 */
void taglib_tag_set_title (TagLibTag tag, TagCString title);

/*!
 * Sets the tag's artist.
 *
 * \note By default this string should be UTF8 encoded.
 */
void taglib_tag_set_artist (TagLibTag tag, TagCString artist);

/*!
 * Sets the tag's album.
 *
 * \note By default this string should be UTF8 encoded.
 */
void taglib_tag_set_album (TagLibTag tag, TagCString album);

/*!
 * Sets the tag's comment.
 *
 * \note By default this string should be UTF8 encoded.
 */
void taglib_tag_set_comment (TagLibTag tag, TagCString comment);

/*!
 * Sets the tag's genre.
 *
 * \note By default this string should be UTF8 encoded.
 */
void taglib_tag_set_genre (TagLibTag tag, TagCString genre);

/*!
 * Sets the tag's year.  0 indicates that this field should be cleared.
 */
void taglib_tag_set_year (TagLibTag tag, uint year);

/*!
 * Sets the tag's track number.  0 indicates that this field should be cleared.
 */
void taglib_tag_set_track (TagLibTag tag, uint track);

/*!
 * Frees all of the strings that have been created by the tag.
 */
void taglib_tag_free_strings ();


/******************************************************************************
 * Audio Properties API
 ******************************************************************************/

/*!
 * Returns the length of the file in seconds.
 */
int taglib_audioproperties_length (const(TagLibAudioProperties) audioProperties);

/*!
 * Returns the bitrate of the file in kb/s.
 */
int taglib_audioproperties_bitrate (const(TagLibAudioProperties) audioProperties);

/*!
 * Returns the sample rate of the file in Hz.
 */
int taglib_audioproperties_samplerate (const(TagLibAudioProperties) audioProperties);

/*!
 * Returns the number of channels in the audio stream.
 */
int taglib_audioproperties_channels (const(TagLibAudioProperties) audioProperties);


/*******************************************************************************
 * Special convenience ID3v2 functions
 *******************************************************************************/
enum TagLibID3v2Encoding {
  Latin1,
  UTF16,
  UTF16BE,
  UTF8
}


/*!
 * This sets the default encoding for ID3v2 frames that are written to tags.
 */
void taglib_id3v2_set_default_text_encoding (TagLibID3v2Encoding encoding);
