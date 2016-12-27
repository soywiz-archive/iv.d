import iv.libopus;
import xalsa;

import iv.alsa;
import iv.cmdcon;
import iv.vfs;


enum FileName = "zpkt.bin";


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  auto fl = VFile(args[1]);

  int err;
  OpusDecoder* dc = opus_decoder_create(Rate, Chans, &err);
  if (err != OPUS_OK) assert(0, opus_strerr(err).idup);
  scope(exit) opus_decoder_destroy(dc);

  short[] sbuf;
  sbuf.length = Rate*4;

  ulong packets;

  version(noplay) {} else alsaOpen();
  version(noplay) {} else scope(exit) alsaClose();

  ubyte[] data;
  {
    uint pklen = cast(uint)fl.size;
    if (data.length < pklen) data.length = pklen;
    fl.rawReadExact(data[0..pklen]);

    err = opus_decode(dc, data.ptr, pklen, sbuf.ptr, sbuf.length/2, 0);
    if (err < 0) assert(0, opus_strerr(err).idup);

    conwriteln("packet length: ", pklen, "; samples: ", opus_decoder_get_nb_samples(dc, data.ptr, pklen), " (", err, "); chans=", opus_packet_get_nb_channels(data.ptr));

    ++packets;
  }
}
