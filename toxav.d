/**  toxav.h
 *
 *   Copyright (C) 2013 Tox project All Rights Reserved.
 *
 *   This file is part of Tox.
 *
 *   Tox is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   Tox is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with Tox. If not, see <http://www.gnu.org/licenses/>.
 *
 */
module iv.toxav is aliced;
pragma(lib, "toxav");
pragma(lib, "opus");
pragma(lib, "vpx");

import iv.tox;

extern(C):
enum vpx_img_fmt_t {
  /*VPX_IMG_FMT_*/NONE,
  /*VPX_IMG_FMT_*/RGB24,   /**< 24 bit per pixel packed RGB */
  /*VPX_IMG_FMT_*/RGB32,   /**< 32 bit per pixel packed 0RGB */
  /*VPX_IMG_FMT_*/RGB565,  /**< 16 bit per pixel, 565 */
  /*VPX_IMG_FMT_*/RGB555,  /**< 16 bit per pixel, 555 */
  /*VPX_IMG_FMT_*/UYVY,    /**< UYVY packed YUV */
  /*VPX_IMG_FMT_*/YUY2,    /**< YUYV packed YUV */
  /*VPX_IMG_FMT_*/YVYU,    /**< YVYU packed YUV */
  /*VPX_IMG_FMT_*/BGR24,   /**< 24 bit per pixel packed BGR */
  /*VPX_IMG_FMT_*/RGB32_LE, /**< 32 bit packed BGR0 */
  /*VPX_IMG_FMT_*/ARGB,     /**< 32 bit packed ARGB, alpha=255 */
  /*VPX_IMG_FMT_*/ARGB_LE,  /**< 32 bit packed BGRA, alpha=255 */
  /*VPX_IMG_FMT_*/RGB565_LE,  /**< 16 bit per pixel, gggbbbbb rrrrrggg */
  /*VPX_IMG_FMT_*/RGB555_LE,  /**< 16 bit per pixel, gggbbbbb 0rrrrrgg */
  /*VPX_IMG_FMT_*/YV12    = /*VPX_IMG_FMT_*/PLANAR | /*VPX_IMG_FMT_*/UV_FLIP | 1, /**< planar YVU */
  /*VPX_IMG_FMT_*/I420    = /*VPX_IMG_FMT_*/PLANAR | 2,
  /*VPX_IMG_FMT_*/VPXYV12 = /*VPX_IMG_FMT_*/PLANAR | /*VPX_IMG_FMT_*/UV_FLIP | 3, /** < planar 4:2:0 format with vpx color space */
  /*VPX_IMG_FMT_*/VPXI420 = /*VPX_IMG_FMT_*/PLANAR | 4,
  /*VPX_IMG_FMT_*/I422    = /*VPX_IMG_FMT_*/PLANAR | 5,
  /*VPX_IMG_FMT_*/I444    = /*VPX_IMG_FMT_*/PLANAR | 6,
  ///*VPX_IMG_FMT_*/444A    = /*VPX_IMG_FMT_*/PLANAR | /*VPX_IMG_FMT_*/HAS_ALPHA | 7,
  /*VPX_IMG_FMT_*/PLANAR    = 0x100, /**< Image is a planar format */
  /*VPX_IMG_FMT_*/UV_FLIP   = 0x200, /**< V plane precedes U plane in memory */
  /*VPX_IMG_FMT_*/HAS_ALPHA = 0x400, /**< Image has an alpha channel component */
}

struct vpx_image_t {
  vpx_img_fmt_t fmt; /**< Image Format */

  /* Image storage dimensions */
  uint w;   /**< Stored image width */
  uint h;   /**< Stored image height */

  /* Image display dimensions */
  uint d_w;   /**< Displayed image width */
  uint d_h;   /**< Displayed image height */

  /* Chroma subsampling info */
  uint x_chroma_shift;   /**< subsampling order, X */
  uint y_chroma_shift;   /**< subsampling order, Y */

  /* Image data pointers. */
  /+
  #define VPX_PLANE_PACKED 0   /**< To be used for all packed formats */
  #define VPX_PLANE_Y      0   /**< Y (Luminance) plane */
  #define VPX_PLANE_U      1   /**< U (Chroma) plane */
  #define VPX_PLANE_V      2   /**< V (Chroma) plane */
  #define VPX_PLANE_ALPHA  3   /**< A (Transparency) plane */
  +/
  ubyte*[4] planes;  /**< pointer to the top left pixel for each plane */
  int[4] stride;  /**< stride between rows for each plane */

  int bps; /**< bits per sample (for packed formats) */

  /* The following member may be set by the application to associate data
   * with this image.
   */
  void* user_priv; /**< may be set by the application to associate data
                       *   with this image. */

  /* The following members should be treated as private. */
  ubyte* img_data;       /**< private */
  int img_data_owner; /**< private */
  int self_allocd;    /**< private */
}

struct ToxAv {
  // disable construction and postblit
  @disable this ();
  @disable this (this);
}
alias ToxAvP = ToxAv*;

alias ToxAVCallback = void function (void* agent, int call_idx, void* arg);
alias ToxAvAudioCallback = void function (void* agent, int call_idx, const(short)* PCM, ushort size, void* data);
alias ToxAvVideoCallback = void function (void* agent, int call_idx, in vpx_image_t* img, void* data);


enum RTP_PAYLOAD_SIZE = 65535;


/**
 * Callbacks ids that handle the call states.
 */
enum ToxAvCallbackID {
    /*av_*/OnInvite, /* Incoming call */
    /*av_*/OnRinging, /* When peer is ready to accept/reject the call */
    /*av_*/OnStart, /* Call (RTP transmission) started */
    /*av_*/OnCancel, /* The side that initiated call canceled invite */
    /*av_*/OnReject, /* The side that was invited rejected the call */
    /*av_*/OnEnd, /* Call that was active ended */
    /*av_*/OnRequestTimeout, /* When the requested action didn't get response in specified time */
    /*av_*/OnPeerTimeout, /* Peer timed out; stop the call */
    /*av_*/OnPeerCSChange, /* Peer changing Csettings. Prepare for changed AV */
    /*av_*/OnSelfCSChange /* Csettings change confirmation. Once triggered peer is ready to recv changed AV */
}


/**
 * Call type identifier.
 */
enum ToxAvCallType {
    /*av_*/TypeAudio = 192,
    /*av_*/TypeVideo
}


enum ToxAvCallState {
    /*av_*/CallNonExistent = -1,
    /*av_*/CallInviting, /* when sending call invite */
    /*av_*/CallStarting, /* when getting call invite */
    /*av_*/CallActive,
    /*av_*/CallHold,
    /*av_*/CallHungUp
}

/**
 * Error indicators. Values under -20 are reserved for toxcore.
 */
enum ToxAvError {
    /*av_*/ErrorNone = 0,
    /*av_*/ErrorUnknown = -1, /* Unknown error */
    /*av_*/ErrorNoCall = -20, /* Trying to perform call action while not in a call */
    /*av_*/ErrorInvalidState = -21, /* Trying to perform call action while in invalid state*/
    /*av_*/ErrorAlreadyInCallWithPeer = -22, /* Trying to call peer when already in a call with peer */
    /*av_*/ErrorReachedCallLimit = -23, /* Cannot handle more calls */
    /*av_*/ErrorInitializingCodecs = -30, /* Failed creating CSSession */
    /*av_*/ErrorSettingVideoResolution = -31, /* Error setting resolution */
    /*av_*/ErrorSettingVideoBitrate = -32, /* Error setting bitrate */
    /*av_*/ErrorSplittingVideoPayload = -33, /* Error splitting video payload */
    /*av_*/ErrorEncodingVideo = -34, /* vpx_codec_encode failed */
    /*av_*/ErrorEncodingAudio = -35, /* opus_encode failed */
    /*av_*/ErrorSendingPayload = -40, /* Sending lossy packet failed */
    /*av_*/ErrorCreatingRtpSessions = -41, /* One of the rtp sessions failed to initialize */
    /*av_*/ErrorNoRtpSession = -50, /* Trying to perform rtp action on invalid session */
    /*av_*/ErrorInvalidCodecState = -51, /* Codec state not initialized */
    /*av_*/ErrorPacketTooLarge = -52, /* Split packet exceeds it's limit */
}


/**
 * Locally supported capabilities.
 */
enum ToxAvCapabilities {
    /*av_*/AudioEncoding = 1 << 0,
    /*av_*/AudioDecoding = 1 << 1,
    /*av_*/VideoEncoding = 1 << 2,
    /*av_*/VideoDecoding = 1 << 3
}


/**
 * Encoding settings.
 */
struct ToxAvCSettings {
    ToxAvCallType call_type;

    uint video_bitrate; /* In kbits/s */
    ushort max_video_width; /* In px */
    ushort max_video_height; /* In px */

    uint audio_bitrate; /* In bits/s */
    ushort audio_frame_duration; /* In ms */
    uint audio_sample_rate; /* In Hz */
    uint audio_channels;
}

extern(C) const ToxAvCSettings av_DefaultSettings;

/**
 * Start new A/V session. There can only be one session at the time.
 */
ToxAv* toxav_new(Tox* messenger, int max_calls);

/**
 * Remove A/V session.
 */
void toxav_kill(ToxAv* av);

/**
 * Returns the interval in milliseconds when the next toxav_do() should be called.
 * If no call is active at the moment returns 200.
 */
uint toxav_do_interval(ToxAv* av);

/**
 * Main loop for the session. Best called right after tox_do();
 */
void toxav_do(ToxAv* av);

/**
 * Register callback for call state.
 */
void toxav_register_callstate_callback (ToxAv* av, ToxAVCallback cb, ToxAvCallbackID id, void* userdata);

/**
 * Register callback for audio data.
 */
void toxav_register_audio_callback (ToxAv* av, ToxAvAudioCallback cb, void* userdata);

/**
 * Register callback for video data.
 */
void toxav_register_video_callback (ToxAv* av, ToxAvVideoCallback cb, void* userdata);

/**
 * Call user. Use its friend_id.
 */
int toxav_call(ToxAv* av,
               int* call_index,
               int friend_id,
               in ToxAvCSettings* csettings,
               int ringing_seconds);

/**
 * Hangup active call.
 */
int toxav_hangup(ToxAv* av, int call_index);

/**
 * Answer incoming call. Pass the csettings that you will use.
 */
int toxav_answer(ToxAv* av, int call_index, in ToxAvCSettings* csettings );

/**
 * Reject incoming call.
 */
int toxav_reject(ToxAv* av, int call_index, const(char)* reason);

/**
 * Cancel outgoing request.
 */
int toxav_cancel(ToxAv* av, int call_index, int peer_id, const(char)* reason);

/**
 * Notify peer that we are changing codec settings.
 */
int toxav_change_settings(ToxAv* av, int call_index, in ToxAvCSettings* csettings);

/**
 * Terminate transmission. Note that transmission will be
 * terminated without informing remote peer. Usually called when we can't inform peer.
 */
int toxav_stop_call(ToxAv* av, int call_index);

/**
 * Allocates transmission data. Must be call before calling toxav_prepare_* and toxav_send_*.
 * Also, it must be called when call is started
 */
int toxav_prepare_transmission(ToxAv* av, int call_index, int support_video);

/**
 * Clears transmission data. Call this at the end of the transmission.
 */
int toxav_kill_transmission(ToxAv* av, int call_index);

/**
 * Encode video frame.
 */
int toxav_prepare_video_frame ( ToxAv* av,
                                int call_index,
                                ubyte* dest,
                                int dest_max,
                                vpx_image_t* input);

/**
 * Send encoded video packet.
 */
int toxav_send_video ( ToxAv* av, int call_index, const(ubyte)* frame, uint frame_size);

/**
 * Encode audio frame.
 */
int toxav_prepare_audio_frame ( ToxAv* av,
                                int call_index,
                                ubyte* dest,
                                int dest_max,
                                const(short)* frame,
                                int frame_size);

/**
 * Send encoded audio frame.
 */
int toxav_send_audio ( ToxAv* av, int call_index, const(ubyte)* frame, uint size);

/**
 * Get codec settings from the peer. These were exchanged during call initialization
 * or when peer send us new csettings.
 */
int toxav_get_peer_csettings ( ToxAv* av, int call_index, int peer, ToxAvCSettings* dest );

/**
 * Get friend id of peer participating in conversation.
 */
int toxav_get_peer_id ( ToxAv* av, int call_index, int peer );

/**
 * Get current call state.
 */
ToxAvCallState toxav_get_call_state ( ToxAv* av, int call_index );

/**
 * Is certain capability supported. Used to determine if encoding/decoding is ready.
 */
int toxav_capability_supported ( ToxAv* av, int call_index, ToxAvCapabilities capability );

/**
 * Returns tox reference.
 */
Tox* toxav_get_tox (ToxAv* av);

/**
 * Returns number of active calls or -1 on error.
 */
int toxav_get_active_count (ToxAv* av);

/* Create a new toxav group.
 *
 * return group number on success.
 * return -1 on failure.
 *
 * Audio data callback format:
 *   audio_callback(Tox* tox, int groupnumber, int peernumber, const short* pcm, uint samples, ubyte channels, uint sample_rate, void* userdata)
 *
 * Note that total size of pcm in bytes is equal to (samples * channels * sizeof(short)).
 */
int toxav_add_av_groupchat(Tox* tox,
  void function (Tox *, int, int, const(short)*, uint, ubyte, uint, void *) audio_callback,
  void* userdata);

/* Join a AV group (you need to have been invited first.)
 *
 * returns group number on success
 * returns -1 on failure.
 *
 * Audio data callback format (same as the one for toxav_add_av_groupchat()):
 *   audio_callback(Tox* tox, int groupnumber, int peernumber, const short* pcm, uint samples, ubyte channels, uint sample_rate, void* userdata)
 *
 * Note that total size of pcm in bytes is equal to (samples * channels * sizeof(short)).
 */
int toxav_join_av_groupchat(Tox* tox, int friendnumber, const(ubyte)* data, ushort length,
  void function (Tox *, int, int, const(short)*, uint, ubyte, uint, void *) audio_callback,
  void* userdata);

/* Send audio to the group chat.
 *
 * return 0 on success.
 * return -1 on failure.
 *
 * Note that total size of pcm in bytes is equal to (samples * channels * sizeof(short)).
 *
 * Valid number of samples are ((sample rate) * (audio length (Valid ones are: 2.5, 5, 10, 20, 40 or 60 ms)) / 1000)
 * Valid number of channels are 1 or 2.
 * Valid sample rates are 8000, 12000, 16000, 24000, or 48000.
 *
 * Recommended values are: samples = 960, channels = 1, sample_rate = 48000
 */
int toxav_group_send_audio(Tox* tox, int groupnumber, const(short)* pcm, uint samples, ubyte channels,
                           uint sample_rate);
