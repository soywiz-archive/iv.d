/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module zflacvt is aliced;

import iv.drflac;
import iv.cmdcon;
import iv.encoding;
import iv.strex;
import iv.vfs;
import iv.vfs.io;
import iv.xyph;


// ////////////////////////////////////////////////////////////////////////// //
__gshared ubyte quality = 6;
__gshared int progressms = 500;

shared static this () {
  conRegVar!quality(0, 9, "quality", "vorbis encoding quality");
  conRegVar!progressms("progress_time", "progress update time, in milliseconds (-1: don't show progress)");
}



// ////////////////////////////////////////////////////////////////////////// //
struct CueFile {
private import iv.encoding;
private import iv.vfs;
private import iv.vfs.io;

public:
  static string koi2tr (const(char)[] s) {
    string res;
    foreach (char ch; s) {
           if (ch == '\xe1' || ch == '\xc1') res ~= "a";
      else if (ch == '\xe2' || ch == '\xc2') res ~= "b";
      else if (ch == '\xf7' || ch == '\xd7') res ~= "v";
      else if (ch == '\xe7' || ch == '\xc7') res ~= "g";
      else if (ch == '\xe4' || ch == '\xc4') res ~= "d";
      else if (ch == '\xe5' || ch == '\xc5') res ~= "e";
      else if (ch == '\xb3' || ch == '\xa3') res ~= "yo";
      else if (ch == '\xf6' || ch == '\xd6') res ~= "zh";
      else if (ch == '\xfa' || ch == '\xda') res ~= "z";
      else if (ch == '\xe9' || ch == '\xc9') res ~= "i";
      else if (ch == '\xea' || ch == '\xca') res ~= "j";
      else if (ch == '\xeb' || ch == '\xcb') res ~= "k";
      else if (ch == '\xec' || ch == '\xcc') res ~= "l";
      else if (ch == '\xed' || ch == '\xcd') res ~= "m";
      else if (ch == '\xee' || ch == '\xce') res ~= "n";
      else if (ch == '\xef' || ch == '\xcf') res ~= "o";
      else if (ch == '\xf0' || ch == '\xd0') res ~= "p";
      else if (ch == '\xf2' || ch == '\xd2') res ~= "r";
      else if (ch == '\xf3' || ch == '\xd3') res ~= "s";
      else if (ch == '\xf4' || ch == '\xd4') res ~= "t";
      else if (ch == '\xf5' || ch == '\xd5') res ~= "u";
      else if (ch == '\xe6' || ch == '\xc6') res ~= "f";
      else if (ch == '\xe8' || ch == '\xc8') res ~= "h";
      else if (ch == '\xe3' || ch == '\xc3') res ~= "c";
      else if (ch == '\xfe' || ch == '\xde') res ~= "ch";
      else if (ch == '\xfb' || ch == '\xdb') res ~= "sh";
      else if (ch == '\xfd' || ch == '\xdd') res ~= "sch";
      else if (ch == '\xff' || ch == '\xdf') {} //res ~= "x"; // tvyordyj znak
      else if (ch == '\xf9' || ch == '\xd9') res ~= "y";
      else if (ch == '\xf8' || ch == '\xd8') {} //res ~= "w"; // myagkij znak
      else if (ch == '\xfc' || ch == '\xdc') res ~= "e";
      else if (ch == '\xe0' || ch == '\xc0') res ~= "ju";
      else if (ch == '\xf1' || ch == '\xd1') res ~= "ja";
      else if (ch >= 'A' && ch <= 'Z') res ~= cast(char)(ch+32);
      else if (ch >= 'a' && ch <= 'z') res ~= ch;
      else if (ch >= '0' && ch <= '9') res ~= ch;
      else {
        if (res.length > 0 && res[$-1] != '_') res ~= '_';
      }
    }
    while (res.length && res[$-1] == '_') res = res[0..$-1];
    if (res.length == 0) res = "_";
    return res;
  }

public:
  static struct Track {
    string artist; // performer
    string title;
    string genre;
    uint year; // 0: unknown
    string filename;
    ulong startmsecs; // index 01
  }

private:
  ulong parseIndex (const(char)[] s) {
    import std.algorithm : splitter;
    import std.conv : to;
    import std.range : enumerate;
    uint[3] msf;
    bool lastHit = false;
    foreach (immutable idx, auto sv; s.splitter(':').enumerate) {
      if (idx >= msf.length) throw new Exception("invalid index");
      lastHit = (idx == msf.length-1);
      msf[idx] = sv.to!uint;
    }
    if (!lastHit) throw new Exception("invalid index");
    if (msf[1] > 59) throw new Exception("invalid index");
    if (msf[2] > 74) throw new Exception("invalid index");
    return cast(uint)((((msf[1]+msf[0]*60)*75)/75.0)*1000.0);
  }

public:
  string artist;
  string album;
  string genre;
  uint year; // 0: unknown
  string filename;
  Track[] tracks;

public:
  void clear () { this = this.default; }

  void load (const(char)[] fname) { load(VFile(fname)); }

  void load (VFile fl) {
    clear();
    scope(failure) clear();
    char[4096] linebuf;
    char lastSavedChar = 0;
    char[] line;
    bool firstLine = true;

    bool readLine () {
      scope(success) {
        if (firstLine) {
          firstLine = false;
          if (line.length >= 3 && line[0..3] == "\xEF\xBB\xBF") line = line[3..$]; // fuck BOM
        }
      }
      uint pos = 0;
      if (lastSavedChar) { linebuf[pos++] = lastSavedChar; lastSavedChar = 0; }
      while (pos < linebuf.length) {
        auto rd = fl.rawRead(linebuf[pos..pos+1]);
        if (rd.length == 0) {
          if (pos == 0) { line = null; return false; }
          line = linebuf[0..pos];
          return true;
        }
        char ch = linebuf[pos];
        if (ch == '\n') {
          line = linebuf[0..pos];
          return true;
        }
        if (ch == '\r') {
          rd = fl.rawRead((&lastSavedChar)[0..1]);
          if (rd.length == 1 && lastSavedChar == '\n') lastSavedChar = 0;
          line = linebuf[0..pos];
          return true;
        }
        ++pos;
      }
      throw new Exception("line too long!");
    }

    // null: EOL
    const(char)[] nextWord(bool doupper) () {
      while (line.length && line[0] <= ' ') line = line[1..$];
      if (line.length == 0) return null;
      char[] res;
      uint epos = 1;
      if (line[0] == '"') {
        // quoted
        while (epos < line.length && line[epos] != '"') {
          // just in case
          if (line[epos] == '\\' && line.length-epos > 1) epos += 2; else ++epos;
        }
        res = line[1..epos];
        if (epos < line.length) {
          assert(line[epos] == '"');
          ++epos;
        }
        line = line[epos..$];
        // remove spaces (i don't need 'em anyway; and i don't care about idiotic filenames)
        while (res.length && res[0] <= ' ') res = res[1..$];
        while (res.length && res[$-1] <= ' ') res = res[0..$-1];
      } else {
        // normal
        while (epos < line.length && line[epos] > ' ') ++epos;
        res = line[0..epos];
        line = line[epos..$];
      }
      // recode
      if (res !is null && !res.utf8Valid) return res.recode("utf-8", "cp1251");
      static if (doupper) {
        if (res !is null) {
          // upcase
          bool doconv = false;
          foreach (char ch; res) {
            if (ch >= 128) { doconv = false; break; }
            if (ch >= 'a' && ch <= 'z') doconv = true;
          }
          if (doconv) foreach (ref char ch; res) if (ch >= 'a' && ch <= 'z') ch -= 32;
        }
      }
      return res;
    }

    while (readLine) {
      //writeln("[", line, "]");
      auto w = nextWord!true();
      if (w is null) continue;
      switch (w) {
        case "REM": // special
          w = nextWord!true();
          switch (w) {
            case "DATE": case "YEAR":
              w = nextWord!false();
              int yr = 0;
              try { import std.conv : to; yr = w.to!ushort(10); } catch (Exception) {}
              if (yr >= 1900 && yr <= 3000) {
                if (tracks.length) tracks[$-1].year = yr; else year = yr;
              }
              break;
            case "GENRE":
              w = nextWord!false();
              if (w.length) {
                if (tracks.length) tracks[$-1].genre = w.idup; else genre = w.idup;
              }
              break;
            default: break;
          }
          break;
        case "TRACK": // new track
          tracks.length += 1;
          w = nextWord!true();
          try {
            import std.conv : to;
            auto tn = w.to!ubyte(10);
            if (tn != tracks.length) throw new Exception("invalid track number");
          } catch (Exception) {
            throw new Exception("fucked track number");
          }
          w = nextWord!true();
          if (w != "AUDIO") throw new Exception("non-audio track");
          break;
        case "PERFORMER":
          w = nextWord!false();
          if (w.length) {
            if (tracks.length) tracks[$-1].artist = w.idup; else artist = w.idup;
          }
          break;
        case "TITLE":
          w = nextWord!false();
          if (w.length) {
            if (tracks.length) tracks[$-1].title = w.idup; else album = w.idup;
          }
          break;
        case "FILE":
          w = nextWord!false();
          if (w.length) {
            if (tracks.length) tracks[$-1].filename = w.idup; else filename = w.idup;
          }
          break;
        case "INDEX":
          // mm:ss:ff (minute-second-frame) format. There are 75 such frames per second of audio
          // 00: pregap, optional
          // 01: song start
          if (tracks.length == 0) throw new Exception("index without track");
          w = nextWord!false();
          try {
            import std.conv : to;
            auto n = w.to!ubyte(10);
            if (n == 1) tracks[$-1].startmsecs = parseIndex(nextWord!true);
          } catch (Exception e) {
            writeln("ERROR: ", e.msg);
            throw new Exception("fucked index");
          }
          break;
        case "PREGAP": case "POSTGAP": break; // ignore
        case "ISRC": case "CATALOG": case "FLAGS": case "CDTEXTFILE": break;
        // SONGWRITER
        default:
          writeln("unknown CUE keyword: '", w, "'");
          throw new Exception("invalid keyword");
      }
    }

    // normalize tracks
    foreach (ref trk; tracks) {
      if (trk.artist == artist) trk.artist = null;
      if (trk.year == year) trk.year = 0;
      if (trk.genre == genre) trk.genre = null;
      if (trk.filename == filename) trk.filename = null;
    }
  }

  void dump (VFile fo) {
    fo.writeln("=======================");
    if (artist.length) fo.writeln("ARTIST: <", artist.recodeToKOI8, ">");
    if (album.length) fo.writeln("ALBUM : <", album.recodeToKOI8, ">");
    if (genre.length) fo.writeln("GENRE : <", genre.recodeToKOI8, ">");
    if (year) fo.writeln("YEAR  : <", year, ">");
    if (filename.length) fo.writeln("FILE  : <", filename.recodeToKOI8, ">");
    if (tracks.length) {
      fo.writeln("TRACKS: ", tracks.length);
      foreach (immutable tidx, const ref trk; tracks) {
        fo.writefln(" TRACK #%02d:  start: %d:%02d.%03d", tidx+1, trk.startmsecs/1000/60, (trk.startmsecs/1000)%60, trk.startmsecs%1000);
        if (trk.artist.length) fo.writeln("  ARTIST: <", trk.artist.recodeToKOI8, ">");
        if (trk.title.length) fo.writeln("  TITLE : <", trk.title.recodeToKOI8, ">");
        if (trk.genre.length) fo.writeln("  GENRE : <", trk.genre.recodeToKOI8, ">");
        if (trk.year) fo.writeln("  YEAR  : <", trk.year, ">");
        if (trk.filename.length) fo.writeln("  FILE  : <", trk.filename.recodeToKOI8, ">");
        if (trk.title.length) fo.writeln("  XFILE : <", koi2tr(trk.title.recodeToKOI8), ">");
      }
    }
  }

  void dump () { dump(stdout); }
}


// ////////////////////////////////////////////////////////////////////////// //
enum READ = 1024; // there is no reason to use bigger buffer
int[READ*2] smpbuffer; // out of the data segment, not the stack


// ////////////////////////////////////////////////////////////////////////// //
void makeOggs (string flacfile, ref CueFile cue, ubyte quality) {
  import std.file : mkdirRecurse;
  import std.string : toStringz;

  if (quality < 0) quality = 0;
  if (quality > 9) quality = 9;

  import core.stdc.stdlib : malloc, free;
  drflac* flc;
  uint commentCount;
  char* fcmts;
  scope(exit) if (fcmts !is null) free(fcmts);

  /+
  flc = drflac_open_file_with_metadata(flacfile.toStringz, (void* pUserData, drflac_metadata* pMetadata) {
    if (pMetadata.type == DRFLAC_METADATA_BLOCK_TYPE_VORBIS_COMMENT) {
      if (fcmts !is null) free(fcmts);
      auto csz = drflac_vorbis_comment_size(pMetadata.data.vorbis_comment.commentCount, pMetadata.data.vorbis_comment.comments);
      if (csz > 0 && csz < 0x100_0000) {
        fcmts = cast(char*)malloc(cast(uint)csz);
      } else {
        fcmts = null;
      }
      if (fcmts is null) {
        commentCount = 0;
      } else {
        import core.stdc.string : memcpy;
        commentCount = pMetadata.data.vorbis_comment.commentCount;
        memcpy(fcmts, pMetadata.data.vorbis_comment.comments, cast(uint)csz);
      }
    }
  });
  +/

  flc = drflac_open_file(flacfile.toStringz);
  if (flc is null) throw new Exception("can't open input file");
  scope(exit) drflac_close(flc);


  if (flc.sampleRate < 1024 || flc.sampleRate > 96000) throw new Exception("invalid flac sample rate");
  if (flc.channels < 1 || flc.channels > 2) throw new Exception("invalid flac channel number");
  if (flc.totalSampleCount%flc.channels != 0) throw new Exception("invalid flac sample count");

  writeln(flc.sampleRate, "Hz, ", flc.channels, " channels; quality=", quality);

  writeln("=======================");
  if (cue.artist.length) writeln("ARTIST: <", cue.artist.recodeToKOI8, ">");
  if (cue.album.length) writeln("ALBUM : <", cue.album.recodeToKOI8, ">");
  if (cue.genre.length) writeln("GENRE : <", cue.genre.recodeToKOI8, ">");
  if (cue.year) writeln("YEAR  : <", cue.year, ">");

  void encodeSamples (VFile fo, uint tidx, ulong totalSamples) {
    import std.conv : to;

    ogg_stream_state os; // take physical pages, weld into a logical stream of packets
    ogg_page og; // one Ogg bitstream page.  Vorbis packets are inside
    ogg_packet op; // one raw packet of data for decode

    vorbis_info vi; // struct that stores all the static vorbis bitstream settings
    vorbis_comment vc; // struct that stores all the user comments

    vorbis_dsp_state vd; // central working state for the packet->PCM decoder
    vorbis_block vb; // local working space for packet->PCM decode


    vorbis_info_init(&vi);
    scope(exit) vorbis_info_clear(&vi);

    // choose an encoding mode.  A few possibilities commented out, one actually used:
    /*********************************************************************
     Encoding using a VBR quality mode.  The usable range is -.1
     (lowest quality, smallest file) to 1. (highest quality, largest file).
     Example quality mode .4: 44kHz stereo coupled, roughly 128kbps VBR

     ret = vorbis_encode_init_vbr(&vi, 2, 44100, .4);

     ---------------------------------------------------------------------

     Encoding using an average bitrate mode (ABR).
     example: 44kHz stereo coupled, average 128kbps VBR

     ret = vorbis_encode_init(&vi, 2, 44100, -1, 128000, -1);

     *********************************************************************/
    if (vorbis_encode_init_vbr(&vi, flc.channels, flc.sampleRate, quality/9.0f) != 0) throw new Exception("cannot init vorbis encoder");
    /* do not continue if setup failed; this can happen if we ask for a
       mode that libVorbis does not support (eg, too low a bitrate, etc,
       will return 'OV_EIMPL') */

    // add comments
    vorbis_comment_init(&vc);
    /*
    {
      drflac_vorbis_comment_iterator i;
      drflac_init_vorbis_comment_iterator(&i, commentCount, fcmts);
      uint commentLength;
      const(char)* pComment;
      while ((pComment = drflac_next_vorbis_comment(&i, &commentLength)) !is null) {
        if (commentLength > 1024*1024*2) break; // just in case
        //comments ~= pComment[0..commentLength].idup;
        auto cmt = pComment[0..commentLength];
        auto eqpos = cmt.indexOf('=');
        if (eqpos < 1) {
          writeln("invalid comment: [", cmt, "]");
        } else {
          import std.string : toStringz;
          vorbis_comment_add_tag(&vc, cmt[0..eqpos].toStringz, cmt[eqpos+1..$].toStringz);
          //writeln("  [", cmt[0..eqpos], "] [", cmt[eqpos+1..$], "]");
        }
      }
    }
    */
    {
      string val = cue.tracks[tidx].artist;
      if (val.length == 0) val = cue.artist;
      if (val.length) vorbis_comment_add_tag(&vc, "ARTIST", val.toStringz);
    }
    if (cue.tracks[tidx].year) vorbis_comment_add_tag(&vc, "DATE", cue.tracks[tidx].year.to!string.toStringz);
    else if (cue.year) vorbis_comment_add_tag(&vc, "DATE", cue.year.to!string.toStringz);
    {
      string val = cue.album;
      if (val.length) vorbis_comment_add_tag(&vc, "ALBUM", val.toStringz);
    }
    {
      string val = cue.tracks[tidx].title;
      if (val.length == 0) val = cue.album;
      if (val.length == 0) val = "untitled";
      vorbis_comment_add_tag(&vc, "TITLE", val.toStringz);
    }
    {
      string val = cue.tracks[tidx].artist;
      if (val.length == 0) val = cue.artist;
      if (val.length) vorbis_comment_add_tag(&vc, "PERFORMER", val.toStringz);
    }
    vorbis_comment_add_tag(&vc, "TRACKNUMBER", (tidx+1).to!string.toStringz);
    vorbis_comment_add_tag(&vc, "TRACKTOTAL", cue.tracks.length.to!string.toStringz);

    // set up the analysis state and auxiliary encoding storage
    vorbis_analysis_init(&vd, &vi);
    vorbis_block_init(&vd, &vb);
    scope(exit) vorbis_block_clear(&vb);
    scope(exit) vorbis_dsp_clear(&vd);

    // set up our packet->stream encoder
    // pick a random serial number; that way we can more likely build chained streams just by concatenation
    {
      import std.random : uniform;
      ogg_stream_init(&os, uniform!"[]"(0, uint.max));
    }
    scope(exit) ogg_stream_clear(&os);

    bool eos = false;

    /* Vorbis streams begin with three headers; the initial header (with
       most of the codec setup parameters) which is mandated by the Ogg
       bitstream spec.  The second header holds any comment fields.  The
       third header holds the bitstream codebook.  We merely need to
       make the headers, then pass them to libvorbis one at a time;
       libvorbis handles the additional Ogg bitstream constraints */
    {
      ogg_packet header;
      ogg_packet header_comm;
      ogg_packet header_code;

      vorbis_analysis_headerout(&vd, &vc, &header, &header_comm, &header_code);
      ogg_stream_packetin(&os, &header); // automatically placed in its own page
      ogg_stream_packetin(&os, &header_comm);
      ogg_stream_packetin(&os, &header_code);

      // this ensures the actual audio data will start on a new page, as per spec
      while (!eos) {
        int result = ogg_stream_flush(&os, &og);
        if (result == 0) break;
        fo.rawWriteExact(og.header[0..og.header_len]);
        fo.rawWriteExact(og.body[0..og.body_len]);
      }
    }

    import core.time;
    long samplesDone = 0, prc = 0;
    MonoTime lastPrcTime = MonoTime.currTime;
    if (progressms >= 0) write("  0%");
    while (!eos) {
      uint rdsmp = cast(uint)(totalSamples-samplesDone > smpbuffer.length ? smpbuffer.length : totalSamples-samplesDone);
      if (rdsmp == 0) {
        /* end of file.  this can be done implicitly in the mainline,
           but it's easier to see here in non-clever fashion.
           Tell the library we're at end of stream so that it can handle
           the last frame and mark end of stream in the output properly */
        vorbis_analysis_wrote(&vd, 0);
        //writeln("DONE!");
      } else {
        auto rdx = drflac_read_s32(flc, rdsmp, smpbuffer.ptr); // interleaved 32-bit samples
        if (rdx < 1) {
          // alas -- the thing that should not be
          writeln("FUCK!");
          vorbis_analysis_wrote(&vd, 0);
        } else {
          samplesDone += rdx;
          if (progressms >= 0) {
            auto nprc = 100*samplesDone/totalSamples;
            if (nprc != prc) {
              auto ctt = MonoTime.currTime;
              if ((ctt-lastPrcTime).total!"msecs" >= progressms) {
                lastPrcTime = ctt;
                if (prc >= 0) write("\x08\x08\x08\x08");
                prc = nprc;
                writef("%3d%%", prc);
              }
            }
          }

          // expose the buffer to submit data
          uint frames = cast(uint)(rdx/flc.channels);
          float** buffer = vorbis_analysis_buffer(&vd, /*READ*/frames);

          // uninterleave samples
          auto wd = smpbuffer.ptr;
          foreach (immutable i; 0..frames) {
            foreach (immutable cn; 0..flc.channels) {
              buffer[cn][i] = ((*wd)>>16)/32768.0f;
              ++wd;
            }
          }

          // tell the library how much we actually submitted
          vorbis_analysis_wrote(&vd, frames);
        }
      }

      /* vorbis does some data preanalysis, then divvies up blocks for
         more involved (potentially parallel) processing.  Get a single
         block for encoding now */
      while (vorbis_analysis_blockout(&vd, &vb) == 1) {
        // analysis, assume we want to use bitrate management
        vorbis_analysis(&vb, null);
        vorbis_bitrate_addblock(&vb);
        while (vorbis_bitrate_flushpacket(&vd, &op)){
          // weld the packet into the bitstream
          ogg_stream_packetin(&os, &op);
          // write out pages (if any)
          while (!eos) {
            int result = ogg_stream_pageout(&os, &og);
            if (result == 0) break;
            //fwrite(og.header, 1, og.header_len, stdout);
            //fwrite(og.body, 1, og.body_len, stdout);
            fo.rawWriteExact(og.header[0..og.header_len]);
            fo.rawWriteExact(og.body[0..og.body_len]);
            // this could be set above, but for illustrative purposes, I do it here (to show that vorbis does know where the stream ends)
            if (ogg_page_eos(&og)) eos = true;
          }
        }
      }
    }
    if (progressms >= 0) {
      if (prc >= 0) write("\x08\x08\x08\x08");
    }
    writeln("DONE");

    // clean up and exit.  vorbis_info_clear() must be called last
    // ogg_page and ogg_packet structs always point to storage in libvorbis.  They're never freed or manipulated directly
    //ogg_stream_clear(&os);
    //vorbis_block_clear(&vb);
    //vorbis_dsp_clear(&vd);
    //vorbis_comment_clear(&vc);
    //vorbis_info_clear(&vi);
  }

  mkdirRecurse("ogg");
  ulong samplesProcessed = 0;
  foreach (immutable tidx, ref trk; cue.tracks) {
    import std.format : format;
    string fname;
    if (trk.title.length) fname = CueFile.koi2tr(trk.title.recodeToKOI8); else fname = "untitled";
    string ofname = "ogg/%02d_%s.ogg".format(tidx, fname);
    write("[", tidx+1, "/", cue.tracks.length, "] ", (trk.title.length ? trk.title.recodeToKOI8 : "untitled"), " -> ", ofname, "  ");
    ulong smpstart, smpend;
    if (tidx == 0) smpstart = 0; else smpstart = cast(ulong)((trk.startmsecs/1000.0)*flc.sampleRate)*flc.channels;
    if (smpstart != samplesProcessed) assert(0, "index fucked");
    if (tidx == cue.tracks.length-1) smpend = flc.totalSampleCount; else smpend = cast(ulong)((cue.tracks[tidx+1].startmsecs/1000.0)*flc.sampleRate)*flc.channels;
    if (smpend <= samplesProcessed) assert(0, "index fucked");
    samplesProcessed = smpend;
    encodeSamples(VFile(ofname, "w"), tidx, smpend-smpstart);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import std.path;
  import std.file : exists;

  concmd("exec .encoder.rc tan");
  conProcessArgs!true(args);

  //writeln(args);

  string flacfile, cuefile;
  //if (args.length == 1) args ~= "linda_karandashi_i_spichki.cue";
  if (args.length < 2) assert(0, "filename?");

  void findFlac (string dir) {
    import std.file;
    flacfile = null;
    foreach (DirEntry de; dirEntries(dir, "*.flac", SpanMode.shallow)) {
      if (de.isFile) {
        if (flacfile.length) assert(0, "too many flac files");
        //writeln("flac: <", de.name, ">");
        flacfile = de.name;
      }
    }
    if (flacfile.length == 0) assert(0, "no flac file");
  }

  void findCue (string dir) {
    //writeln("dir: <", dir, ">");
    import std.file;
    cuefile = null;
    foreach (DirEntry de; dirEntries(dir, "*.cue", SpanMode.shallow)) {
      if (de.isFile) {
        //writeln("cue: <", de.name, ">");
        if (cuefile.length) assert(0, "too many cue files");
        cuefile = de.name;
      }
    }
    if (cuefile.length == 0) assert(0, "no cue file");
  }


  if (args.length < 2) assert(0, "input file?");
  flacfile = args[1];
  if (args.length > 2) {
    if (args.length > 3) assert(0, "too many input files");
    if (flacfile.extension.strEquCI(".flac")) {
      cuefile = args[2];
      if (cuefile.extension.strEquCI(".cue")) assert(0, "invalid input files");
    } else if (flacfile.extension.strEquCI(".cue")) {
      cuefile = flacfile;
      flacfile = args[2];
      if (flacfile.extension.strEquCI(".flac")) assert(0, "invalid input files");
    } else {
      assert(0, "invalid input files");
    }
  } else {
    if (flacfile.extension.strEquCI(".cue")) {
      cuefile = flacfile;
      flacfile = cuefile.setExtension(".flac");
      if (!flacfile.exists) findFlac(flacfile.dirName);
    } else if (flacfile.extension.strEquCI(".flac")) {
      cuefile = flacfile.setExtension(".cue");
      if (!cuefile.exists) findCue(cuefile.dirName);
    } else {
      if (exists(flacfile~".flac")) {
        flacfile ~= ".flac";
        findCue(flacfile.dirName);
      } else if (exists(flacfile~".cue")) {
        cuefile = flacfile~".cue";
        findFlac(cuefile.dirName);
      } else {
        assert(0, "wtf?!");
      }
    }
  }

  writeln("FLAC: ", flacfile);
  writeln("CUE : ", cuefile);

  CueFile cue;
  cue.load(cuefile);

  if (cue.tracks.length == 0) assert(0, "no tracks");
  if (cue.tracks[0].startmsecs != 0) assert(0, "found first hidden track");

  //cue.dump();
  makeOggs(flacfile, cue, quality);
}
