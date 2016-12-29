import avmem;
import avfft;
import opus;
import opus_celt;
import opus_silk;
import opusdec;
import xalsa;
import zogg;

import iv.alsa;
import iv.cmdcon;
import iv.vfs;


//version = noplay;

enum FileName = "/tmp/03/linda_karandashi_i_spichki.opus";
//enum FileName = "/tmp/03/melodie_128.opus";


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  AVCtx ctx;
  OpusContext c;

  OggStream ogg;
  ogg.setup(VFile(args[1]));

  ogg.PageInfo lastpage;
  if (!ogg.findLastPage(lastpage)) assert(0, "can't find last ogg page");
  lastpage.granule -= ctx.preskip;
  conwriteln("last page seqnum: ", lastpage.seqnum);
  conwriteln("last page granule: ", lastpage.granule);
  conwriteln("last page filepos: ", lastpage.pgfpos);

  for (;;) {
    auto r = opus_header(&ctx, ogg);
    if (r < 0) assert(0);
    if (!ogg.loadPacket()) assert(0);
    if (r == 1) break;
  }

  if (opus_decode_init(&ctx, &c) < 0) assert(0, "fuuuuu");
  scope(exit) opus_decode_close(&c);
  assert(c.nb_streams == 1);
  assert(c.streams[0].output_channels >= 1 && c.streams[0].output_channels <= 2);
  //assert(c.streams[0].output_channels == 2);

  /+
  foreach (immutable chn; 0..c.streams[0].output_channels) {
    conwriteln("output buf for chan #", chn);
    //c.streams.out_[chn] = av_mallocz!float(Rate);
  }
  +/

  float[][2] obuf;
  foreach (ref obb; obuf[]) obb.length = Rate;
  ubyte*[2] eptr;
  ulong packets, frames;

  version(noplay) {} else alsaOpen(c.streams[0].output_channels);
  version(noplay) {} else scope(exit) alsaClose();

  //ogg.seekPCM(lastpage.granule/4+ctx.preskip);
  //ogg.seekPCM(lastpage.granule/6+ctx.preskip);

  ulong lastgran = 0;
  for (;;) {
    auto r = opus_packet(&ctx, ogg);
    if (r < 0) break;

    //conwriteln("packet #", packets, "; frame #", frames);
    AVFrame frame;
    AVPacket pkt;
    frame.linesize[0] = obuf[0].length*obuf[0].sizeof;
    pkt.data = ogg.packetData.ptr;
    pkt.size = cast(uint)ogg.packetLength;
    foreach (immutable idx, ref obb; obuf[]) eptr[idx] = cast(ubyte*)(obb.ptr);
    frame.extended_data = eptr.ptr;
    //c.streams.out_size = outsize;
    int gotfrptr = 0;
    r = opus_decode_packet(/*&ctx,*/ &c, &frame, &gotfrptr, &pkt);
    if (r < 0) {
      conwriteln("can't process packet #", packets);
      assert(0);
    }
    if (gotfrptr) ++frames;
    //conwriteln("  ", c.streams.out_size);
    //conwriteln("dc=", r);
    if (ogg.packetGranule && ogg.packetGranule != -1) lastgran = ogg.packetGranule-ctx.preskip;
    conwritef!"\r%s:%02s / %s:%02s"((lastgran/48000)/60, (lastgran/48000)%60, (lastpage.granule/48000)/60, (lastpage.granule/48000)%60);
    version(noplay) {} else alsaWrite2B(eptr.ptr, r);

    ++packets;
    if (!ogg.loadPacket()) break;
  }
  conwriteln(packets, " opus packets, ", frames, " frames found");
}
