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
module encflac is aliced;

import iv.drflac;
import iv.strex;
import iv.xyph;
import iv.vfs;
import iv.vfs.io;


enum READ = 1024; // there is no reason to use bigger buffer
int[READ*2] smpbuffer; // out of the data segment, not the stack


void main () {
  ogg_stream_state os; // take physical pages, weld into a logical stream of packets
  ogg_page og; // one Ogg bitstream page.  Vorbis packets are inside
  ogg_packet op; // one raw packet of data for decode

  vorbis_info vi; // struct that stores all the static vorbis bitstream settings
  vorbis_comment vc; // struct that stores all the user comments

  vorbis_dsp_state vd; // central working state for the packet->PCM decoder
  vorbis_block vb; // local working space for packet->PCM decode


  import core.stdc.stdlib : malloc, free;
  drflac* ff;
  uint commentCount;
  char* fcmts;
  scope(exit) if (fcmts !is null) free(fcmts);

  ff = drflac_open_file_with_metadata("11_rubber_plants.flac", (void* pUserData, drflac_metadata* pMetadata) {
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
  if (ff is null) assert(0, "can't open input file");
  scope(exit) drflac_close(ff);


  if (ff.sampleRate < 1024 || ff.sampleRate > 96000) assert(0, "invalid flac sample rate");
  if (ff.channels < 1 || ff.channels > 2) assert(0, "invalid flac channel number");
  if (ff.totalSampleCount%ff.channels != 0) assert(0, "invalid flac sample count");

  writeln(ff.sampleRate, "Hz, ", ff.channels, " channels");


  // ********* Encode setup ***********

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

  if (vorbis_encode_init_vbr(&vi, ff.channels, ff.sampleRate, 0.6) != 0) assert(0, "cannot init vorbis encoder");
  /* do not continue if setup failed; this can happen if we ask for a
     mode that libVorbis does not support (eg, too low a bitrate, etc,
     will return 'OV_EIMPL') */

  // add comments
  vorbis_comment_init(&vc);
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

  auto fo = VFile("z00.ogg", "w");
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

  long samplesDone = 0, prc = -1;
  while (!eos) {
    uint rdsmp = cast(uint)(ff.totalSampleCount-samplesDone > smpbuffer.length ? smpbuffer.length : ff.totalSampleCount-samplesDone);
    if (rdsmp == 0) {
      /* end of file.  this can be done implicitly in the mainline,
         but it's easier to see here in non-clever fashion.
         Tell the library we're at end of stream so that it can handle
         the last frame and mark end of stream in the output properly */
      vorbis_analysis_wrote(&vd, 0);
      //writeln("DONE!");
    } else {
      auto rdx = drflac_read_s32(ff, rdsmp, smpbuffer.ptr); // interleaved 32-bit samples
      if (rdx < 1) {
        // alas -- the thing that should not be
        writeln("FUCK!");
        vorbis_analysis_wrote(&vd, 0);
      } else {
        samplesDone += rdx;
        auto nprc = 100*samplesDone/ff.totalSampleCount;
        if (nprc != prc) {
          prc = nprc;
          writef("\r%3d%%", prc);
        }

        // expose the buffer to submit data
        uint frames = cast(uint)(rdx/ff.channels);
        float** buffer = vorbis_analysis_buffer(&vd, /*READ*/frames);

        // uninterleave samples
        auto wd = smpbuffer.ptr;
        foreach (immutable i; 0..frames) {
          foreach (immutable cn; 0..ff.channels) {
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
  writeln("\r100%");

  // clean up and exit.  vorbis_info_clear() must be called last
  // ogg_page and ogg_packet structs always point to storage in libvorbis.  They're never freed or manipulated directly
  //ogg_stream_clear(&os);
  //vorbis_block_clear(&vb);
  //vorbis_dsp_clear(&vd);
  //vorbis_comment_clear(&vc);
  //vorbis_info_clear(&vi);

  fo.close();
}
