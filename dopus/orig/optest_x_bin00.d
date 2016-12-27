import avmem;
import avfft;
import opus;
import opus_celt;
import opus_silk;
import opusdec;
import swresample;
import zogg;
import xalsa;

import iv.cmdcon;
import iv.vfs;


//enum FileName = "/tmp/03/linda_karandashi_i_spichki.opus";
//enum FileName = "/tmp/03/melodie_128.opus";
enum FileName = "zpkt.bin";


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  OpusContext c;

  auto fl = VFile(args[1]);

  if (opus_decode_init_ll(&c) < 0) assert(0, "fuuuuu");

  enum outsize = 48000*2;
  foreach (immutable chn; 0..c.streams[0].output_channels) {
    conwriteln("output buf for chan #", chn);
    c.streams.out_[chn] = av_mallocz!float(48000);
  }

  short[] sbuf;
  sbuf.length = Rate*4;

  float[][2] obuf;
  foreach (ref obb; obuf[]) obb.length = outsize;
  ubyte*[2] eptr;
  ulong packets, frames;

  version(noplay) {} else alsaOpen();
  version(noplay) {} else scope(exit) alsaClose();

  ubyte[] data;
  {
    uint pklen = cast(uint)fl.size;
    if (data.length < pklen) data.length = pklen;
    fl.rawReadExact(data[0..pklen]);

    //conwriteln("packet #", packets, "; frame #", frames);
    AVFrame frame;
    AVPacket pkt;
    frame.linesize[0] = outsize;
    pkt.data = data.ptr;
    pkt.size = pklen;
    foreach (immutable idx, ref obb; obuf[]) eptr[idx] = cast(ubyte*)(obb.ptr);
    frame.extended_data = eptr.ptr;
    //c.streams.out_size = outsize;
    int gotfrptr = 0;
    int r = opus_decode_packet(&c, &frame, &gotfrptr, &pkt);
    if (r < 0) {
      conwriteln("can't process packet #", packets);
      assert(0);
    }
    if (gotfrptr) {
      ++frames;
      //assert(0);
    }
    //conwriteln("  ", c.streams.out_size);
    //conwriteln("dc=", r);

    //err = opus_decode(dc, data.ptr, pklen, sbuf.ptr, sbuf.length/2, 0);
    //if (err < 0) assert(0, opus_strerr(err).idup);

    //conwrite("\rpacket length: ", pklen, "; samples: ", opus_decoder_get_nb_samples(dc, data.ptr, pklen), " (", err, "); chans=", opus_packet_get_nb_channels(data.ptr), "\e[K");

    //conwriteln("  ", c.streams.out_size);
    //conwriteln("samples=", err);
    //version(noplay) {} else alsaWrite2B(sbuf.ptr, r);
    ++packets;
  }
}
