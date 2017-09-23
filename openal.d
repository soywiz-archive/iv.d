/*
 * OpenAL cross platform audio library
 * Copyright (C) 2008 by authors.
 * This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the
 *  Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 * Or go to http://www.gnu.org/copyleft/lgpl.html
 */
module iv.openal;
pragma(lib, "openal");

// version = openal_alut;

extern(C) nothrow @nogc:

/** Deprecated macro. */
//#define OPENAL
//#define ALAPI                                    AL_API
//#define ALAPIENTRY                               AL_APIENTRY
enum AL_INVALID = (-1);
enum AL_ILLEGAL_ENUM = AL_INVALID_ENUM;
enum AL_ILLEGAL_COMMAND = AL_INVALID_OPERATION;

/** Supported AL version. */
enum AL_VERSION_1_0 = true;
enum AL_VERSION_1_1 = true;

/** 8-bit boolean */
alias ALboolean = ubyte;

/** character */
alias ALchar = char;

/** signed 8-bit 2's complement integer */
alias ALbyte = byte;

/** unsigned 8-bit integer */
alias ALubyte = ubyte;

/** signed 16-bit 2's complement integer */
alias ALshort = short;

/** unsigned 16-bit integer */
alias ALushort = ushort;

/** signed 32-bit 2's complement integer */
alias ALint = int;

/** unsigned 32-bit integer */
alias ALuint = uint;

/** non-negative 32-bit binary integer size */
alias ALsizei = int;

/** enumerated 32-bit value */
alias ALenum = int;

/** 32-bit IEEE754 floating-point */
alias ALfloat = float;

/** 64-bit IEEE754 floating-point */
alias ALdouble = double;

/** void type (for opaque pointers only) */
alias ALvoid = void;


/* Enumerant values begin at column 50. No tabs. */

/** "no distance model" or "no buffer" */
enum AL_NONE = 0;

/** Boolean False. */
enum AL_FALSE = 0;

/** Boolean True. */
enum AL_TRUE = 1;


/**
 * Relative source.
 * Type:    ALboolean
 * Range:   [AL_TRUE, AL_FALSE]
 * Default: AL_FALSE
 *
 * Specifies if the Source has relative coordinates.
 */
enum AL_SOURCE_RELATIVE = 0x202;


/**
 * Inner cone angle, in degrees.
 * Type:    ALint, ALfloat
 * Range:   [0 - 360]
 * Default: 360
 *
 * The angle covered by the inner cone, where the source will not attenuate.
 */
enum AL_CONE_INNER_ANGLE = 0x1001;

/**
 * Outer cone angle, in degrees.
 * Range:   [0 - 360]
 * Default: 360
 *
 * The angle covered by the outer cone, where the source will be fully
 * attenuated.
 */
enum AL_CONE_OUTER_ANGLE = 0x1002;

/**
 * Source pitch.
 * Type:    ALfloat
 * Range:   [0.5 - 2.0]
 * Default: 1.0
 *
 * A multiplier for the frequency (sample rate) of the source's buffer.
 */
enum AL_PITCH = 0x1003;

/**
 * Source or listener position.
 * Type:    ALfloat[3], ALint[3]
 * Default: {0, 0, 0}
 *
 * The source or listener location in three dimensional space.
 *
 * OpenAL, like OpenGL, uses a right handed coordinate system, where in a
 * frontal default view X (thumb) points right, Y points up (index finger), and
 * Z points towards the viewer/camera (middle finger).
 *
 * To switch from a left handed coordinate system, flip the sign on the Z
 * coordinate.
 */
enum AL_POSITION = 0x1004;

/**
 * Source direction.
 * Type:    ALfloat[3], ALint[3]
 * Default: {0, 0, 0}
 *
 * Specifies the current direction in local space.
 * A zero-length vector specifies an omni-directional source (cone is ignored).
 */
enum AL_DIRECTION = 0x1005;

/**
 * Source or listener velocity.
 * Type:    ALfloat[3], ALint[3]
 * Default: {0, 0, 0}
 *
 * Specifies the current velocity in local space.
 */
enum AL_VELOCITY = 0x1006;

/**
 * Source looping.
 * Type:    ALboolean
 * Range:   [AL_TRUE, AL_FALSE]
 * Default: AL_FALSE
 *
 * Specifies whether source is looping.
 */
enum AL_LOOPING = 0x1007;

/**
 * Source buffer.
 * Type:  ALuint
 * Range: any valid Buffer.
 *
 * Specifies the buffer to provide sound samples.
 */
enum AL_BUFFER = 0x1009;

/**
 * Source or listener gain.
 * Type:  ALfloat
 * Range: [0.0 - ]
 *
 * A value of 1.0 means unattenuated. Each division by 2 equals an attenuation
 * of about -6dB. Each multiplicaton by 2 equals an amplification of about
 * +6dB.
 *
 * A value of 0.0 is meaningless with respect to a logarithmic scale; it is
 * silent.
 */
enum AL_GAIN = 0x100A;

/**
 * Minimum source gain.
 * Type:  ALfloat
 * Range: [0.0 - 1.0]
 *
 * The minimum gain allowed for a source, after distance and cone attenation is
 * applied (if applicable).
 */
enum AL_MIN_GAIN = 0x100D;

/**
 * Maximum source gain.
 * Type:  ALfloat
 * Range: [0.0 - 1.0]
 *
 * The maximum gain allowed for a source, after distance and cone attenation is
 * applied (if applicable).
 */
enum AL_MAX_GAIN = 0x100E;

/**
 * Listener orientation.
 * Type: ALfloat[6]
 * Default: {0.0, 0.0, -1.0, 0.0, 1.0, 0.0}
 *
 * Effectively two three dimensional vectors. The first vector is the front (or
 * "at") and the second is the top (or "up").
 *
 * Both vectors are in local space.
 */
enum AL_ORIENTATION = 0x100F;

/**
 * Source state (query only).
 * Type:  ALint
 * Range: [AL_INITIAL, AL_PLAYING, AL_PAUSED, AL_STOPPED]
 */
enum AL_SOURCE_STATE = 0x1010;

/** Source state value. */
enum AL_INITIAL = 0x1011;
enum AL_PLAYING = 0x1012;
enum AL_PAUSED = 0x1013;
enum AL_STOPPED = 0x1014;

/**
 * Source Buffer Queue size (query only).
 * Type: ALint
 *
 * The number of buffers queued using alSourceQueueBuffers, minus the buffers
 * removed with alSourceUnqueueBuffers.
 */
enum AL_BUFFERS_QUEUED = 0x1015;

/**
 * Source Buffer Queue processed count (query only).
 * Type: ALint
 *
 * The number of queued buffers that have been fully processed, and can be
 * removed with alSourceUnqueueBuffers.
 *
 * Looping sources will never fully process buffers because they will be set to
 * play again for when the source loops.
 */
enum AL_BUFFERS_PROCESSED = 0x1016;

/**
 * Source reference distance.
 * Type:    ALfloat
 * Range:   [0.0 - ]
 * Default: 1.0
 *
 * The distance in units that no attenuation occurs.
 *
 * At 0.0, no distance attenuation ever occurs on non-linear attenuation models.
 */
enum AL_REFERENCE_DISTANCE = 0x1020;

/**
 * Source rolloff factor.
 * Type:    ALfloat
 * Range:   [0.0 - ]
 * Default: 1.0
 *
 * Multiplier to exaggerate or diminish distance attenuation.
 *
 * At 0.0, no distance attenuation ever occurs.
 */
enum AL_ROLLOFF_FACTOR = 0x1021;

/**
 * Outer cone gain.
 * Type:    ALfloat
 * Range:   [0.0 - 1.0]
 * Default: 0.0
 *
 * The gain attenuation applied when the listener is outside of the source's
 * outer cone.
 */
enum AL_CONE_OUTER_GAIN = 0x1022;

/**
 * Source maximum distance.
 * Type:    ALfloat
 * Range:   [0.0 - ]
 * Default: +inf
 *
 * The distance above which the source is not attenuated any further with a
 * clamped distance model, or where attenuation reaches 0.0 gain for linear
 * distance models with a default rolloff factor.
 */
enum AL_MAX_DISTANCE = 0x1023;

/** Source buffer position, in seconds */
enum AL_SEC_OFFSET = 0x1024;
/** Source buffer position, in sample frames */
enum AL_SAMPLE_OFFSET = 0x1025;
/** Source buffer position, in bytes */
enum AL_BYTE_OFFSET = 0x1026;

/**
 * Source type (query only).
 * Type:  ALint
 * Range: [AL_STATIC, AL_STREAMING, AL_UNDETERMINED]
 *
 * A Source is Static if a Buffer has been attached using AL_BUFFER.
 *
 * A Source is Streaming if one or more Buffers have been attached using
 * alSourceQueueBuffers.
 *
 * A Source is Undetermined when it has the NULL buffer attached using
 * AL_BUFFER.
 */
enum AL_SOURCE_TYPE = 0x1027;

/** Source type value. */
enum AL_STATIC = 0x1028;
enum AL_STREAMING = 0x1029;
enum AL_UNDETERMINED = 0x1030;

/** Buffer format specifier. */
enum AL_FORMAT_MONO8 = 0x1100;
enum AL_FORMAT_MONO16 = 0x1101;
enum AL_FORMAT_STEREO8 = 0x1102;
enum AL_FORMAT_STEREO16 = 0x1103;

/** Buffer frequency (query only). */
enum AL_FREQUENCY = 0x2001;
/** Buffer bits per sample (query only). */
enum AL_BITS = 0x2002;
/** Buffer channel count (query only). */
enum AL_CHANNELS = 0x2003;
/** Buffer data size (query only). */
enum AL_SIZE = 0x2004;

/**
 * Buffer state.
 *
 * Not for public use.
 */
enum AL_UNUSED = 0x2010;
enum AL_PENDING = 0x2011;
enum AL_PROCESSED = 0x2012;


/** No error. */
enum AL_NO_ERROR = 0;

/** Invalid name paramater passed to AL call. */
enum AL_INVALID_NAME = 0xA001;

/** Invalid enum parameter passed to AL call. */
enum AL_INVALID_ENUM = 0xA002;

/** Invalid value parameter passed to AL call. */
enum AL_INVALID_VALUE = 0xA003;

/** Illegal AL call. */
enum AL_INVALID_OPERATION = 0xA004;

/** Not enough memory. */
enum AL_OUT_OF_MEMORY = 0xA005;


/** Context string: Vendor ID. */
enum AL_VENDOR = 0xB001;
/** Context string: Version. */
enum AL_VERSION = 0xB002;
/** Context string: Renderer ID. */
enum AL_RENDERER = 0xB003;
/** Context string: Space-separated extension list. */
enum AL_EXTENSIONS = 0xB004;


/**
 * Doppler scale.
 * Type:    ALfloat
 * Range:   [0.0 - ]
 * Default: 1.0
 *
 * Scale for source and listener velocities.
 */
enum AL_DOPPLER_FACTOR = 0xC000;
/*AL_API*/ void /*AL_APIENTRY*/ alDopplerFactor(ALfloat value);

/**
 * Doppler velocity (deprecated).
 *
 * A multiplier applied to the Speed of Sound.
 */
enum AL_DOPPLER_VELOCITY = 0xC001;
/*AL_API*/ void /*AL_APIENTRY*/ alDopplerVelocity(ALfloat value);

/**
 * Speed of Sound, in units per second.
 * Type:    ALfloat
 * Range:   [0.0001 - ]
 * Default: 343.3
 *
 * The speed at which sound waves are assumed to travel, when calculating the
 * doppler effect.
 */
enum AL_SPEED_OF_SOUND = 0xC003;
/*AL_API*/ void /*AL_APIENTRY*/ alSpeedOfSound(ALfloat value);

/**
 * Distance attenuation model.
 * Type:    ALint
 * Range:   [AL_NONE, AL_INVERSE_DISTANCE, AL_INVERSE_DISTANCE_CLAMPED,
 *           AL_LINEAR_DISTANCE, AL_LINEAR_DISTANCE_CLAMPED,
 *           AL_EXPONENT_DISTANCE, AL_EXPONENT_DISTANCE_CLAMPED]
 * Default: AL_INVERSE_DISTANCE_CLAMPED
 *
 * The model by which sources attenuate with distance.
 *
 * None     - No distance attenuation.
 * Inverse  - Doubling the distance halves the source gain.
 * Linear   - Linear gain scaling between the reference and max distances.
 * Exponent - Exponential gain dropoff.
 *
 * Clamped variations work like the non-clamped counterparts, except the
 * distance calculated is clamped between the reference and max distances.
 */
enum AL_DISTANCE_MODEL = 0xD000;
/*AL_API*/ void /*AL_APIENTRY*/ alDistanceModel(ALenum distanceModel);

/** Distance model value. */
enum AL_INVERSE_DISTANCE = 0xD001;
enum AL_INVERSE_DISTANCE_CLAMPED = 0xD002;
enum AL_LINEAR_DISTANCE = 0xD003;
enum AL_LINEAR_DISTANCE_CLAMPED = 0xD004;
enum AL_EXPONENT_DISTANCE = 0xD005;
enum AL_EXPONENT_DISTANCE_CLAMPED = 0xD006;

/** Renderer State management. */
/*AL_API*/ void /*AL_APIENTRY*/ alEnable(ALenum capability);
/*AL_API*/ void /*AL_APIENTRY*/ alDisable(ALenum capability);
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsEnabled(ALenum capability);

/** State retrieval. */
/*AL_API*/ const(ALchar)* /*AL_APIENTRY*/ alGetString(ALenum param);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBooleanv(ALenum param, ALboolean* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetIntegerv(ALenum param, ALint* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetFloatv(ALenum param, ALfloat* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetDoublev(ALenum param, ALdouble* values);
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alGetBoolean(ALenum param);
/*AL_API*/ ALint /*AL_APIENTRY*/ alGetInteger(ALenum param);
/*AL_API*/ ALfloat /*AL_APIENTRY*/ alGetFloat(ALenum param);
/*AL_API*/ ALdouble /*AL_APIENTRY*/ alGetDouble(ALenum param);

/**
 * Error retrieval.
 *
 * Obtain the first error generated in the AL context since the last check.
 */
/*AL_API*/ ALenum /*AL_APIENTRY*/ alGetError();

/**
 * Extension support.
 *
 * Query for the presence of an extension, and obtain any appropriate function
 * pointers and enum values.
 */
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsExtensionPresent(const(ALchar)* extname);
/*AL_API*/ void* /*AL_APIENTRY*/ alGetProcAddress(const(ALchar)* fname);
/*AL_API*/ ALenum /*AL_APIENTRY*/ alGetEnumValue(const(ALchar)* ename);


/** Set Listener parameters */
/*AL_API*/ void /*AL_APIENTRY*/ alListenerf(ALenum param, ALfloat value);
/*AL_API*/ void /*AL_APIENTRY*/ alListener3f(ALenum param, ALfloat value1, ALfloat value2, ALfloat value3);
/*AL_API*/ void /*AL_APIENTRY*/ alListenerfv(ALenum param, const(ALfloat)* values);
/*AL_API*/ void /*AL_APIENTRY*/ alListeneri(ALenum param, ALint value);
/*AL_API*/ void /*AL_APIENTRY*/ alListener3i(ALenum param, ALint value1, ALint value2, ALint value3);
/*AL_API*/ void /*AL_APIENTRY*/ alListeneriv(ALenum param, const(ALint)* values);

/** Get Listener parameters */
/*AL_API*/ void /*AL_APIENTRY*/ alGetListenerf(ALenum param, ALfloat* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetListener3f(ALenum param, ALfloat* value1, ALfloat* value2, ALfloat* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetListenerfv(ALenum param, ALfloat* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetListeneri(ALenum param, ALint* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetListener3i(ALenum param, ALint* value1, ALint* value2, ALint* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetListeneriv(ALenum param, ALint* values);


/** Create Source objects. */
/*AL_API*/ void /*AL_APIENTRY*/ alGenSources(ALsizei n, ALuint* sources);
/** Delete Source objects. */
/*AL_API*/ void /*AL_APIENTRY*/ alDeleteSources(ALsizei n, const(ALuint)* sources);
/** Verify a handle is a valid Source. */
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsSource(ALuint source);

/** Set Source parameters. */
/*AL_API*/ void /*AL_APIENTRY*/ alSourcef(ALuint source, ALenum param, ALfloat value);
/*AL_API*/ void /*AL_APIENTRY*/ alSource3f(ALuint source, ALenum param, ALfloat value1, ALfloat value2, ALfloat value3);
/*AL_API*/ void /*AL_APIENTRY*/ alSourcefv(ALuint source, ALenum param, const(ALfloat)* values);
/*AL_API*/ void /*AL_APIENTRY*/ alSourcei(ALuint source, ALenum param, ALint value);
/*AL_API*/ void /*AL_APIENTRY*/ alSource3i(ALuint source, ALenum param, ALint value1, ALint value2, ALint value3);
/*AL_API*/ void /*AL_APIENTRY*/ alSourceiv(ALuint source, ALenum param, const(ALint)* values);

/** Get Source parameters. */
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcef(ALuint source, ALenum param, ALfloat* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSource3f(ALuint source, ALenum param, ALfloat* value1, ALfloat* value2, ALfloat* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcefv(ALuint source, ALenum param, ALfloat* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcei(ALuint source,  ALenum param, ALint* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSource3i(ALuint source, ALenum param, ALint* value1, ALint* value2, ALint* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourceiv(ALuint source,  ALenum param, ALint* values);


/** Play, replay, or resume (if paused) a list of Sources */
/*AL_API*/ void /*AL_APIENTRY*/ alSourcePlayv(ALsizei n, const(ALuint)* sources);
/** Stop a list of Sources */
/*AL_API*/ void /*AL_APIENTRY*/ alSourceStopv(ALsizei n, const(ALuint)* sources);
/** Rewind a list of Sources */
/*AL_API*/ void /*AL_APIENTRY*/ alSourceRewindv(ALsizei n, const(ALuint)* sources);
/** Pause a list of Sources */
/*AL_API*/ void /*AL_APIENTRY*/ alSourcePausev(ALsizei n, const(ALuint)* sources);

/** Play, replay, or resume a Source */
/*AL_API*/ void /*AL_APIENTRY*/ alSourcePlay(ALuint source);
/** Stop a Source */
/*AL_API*/ void /*AL_APIENTRY*/ alSourceStop(ALuint source);
/** Rewind a Source (set playback postiton to beginning) */
/*AL_API*/ void /*AL_APIENTRY*/ alSourceRewind(ALuint source);
/** Pause a Source */
/*AL_API*/ void /*AL_APIENTRY*/ alSourcePause(ALuint source);

/** Queue buffers onto a source */
/*AL_API*/ void /*AL_APIENTRY*/ alSourceQueueBuffers(ALuint source, ALsizei nb, const(ALuint)* buffers);
/** Unqueue processed buffers from a source */
/*AL_API*/ void /*AL_APIENTRY*/ alSourceUnqueueBuffers(ALuint source, ALsizei nb, ALuint* buffers);


/** Create Buffer objects */
/*AL_API*/ void /*AL_APIENTRY*/ alGenBuffers(ALsizei n, ALuint* buffers);
/** Delete Buffer objects */
/*AL_API*/ void /*AL_APIENTRY*/ alDeleteBuffers(ALsizei n, const(ALuint)* buffers);
/** Verify a handle is a valid Buffer */
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsBuffer(ALuint buffer);

/** Specifies the data to be copied into a buffer */
/*AL_API*/ void /*AL_APIENTRY*/ alBufferData(ALuint buffer, ALenum format, const(ALvoid)* data, ALsizei size, ALsizei freq);

/** Set Buffer parameters, */
/*AL_API*/ void /*AL_APIENTRY*/ alBufferf(ALuint buffer, ALenum param, ALfloat value);
/*AL_API*/ void /*AL_APIENTRY*/ alBuffer3f(ALuint buffer, ALenum param, ALfloat value1, ALfloat value2, ALfloat value3);
/*AL_API*/ void /*AL_APIENTRY*/ alBufferfv(ALuint buffer, ALenum param, const(ALfloat)* values);
/*AL_API*/ void /*AL_APIENTRY*/ alBufferi(ALuint buffer, ALenum param, ALint value);
/*AL_API*/ void /*AL_APIENTRY*/ alBuffer3i(ALuint buffer, ALenum param, ALint value1, ALint value2, ALint value3);
/*AL_API*/ void /*AL_APIENTRY*/ alBufferiv(ALuint buffer, ALenum param, const(ALint)* values);

/** Get Buffer parameters. */
/*AL_API*/ void /*AL_APIENTRY*/ alGetBufferf(ALuint buffer, ALenum param, ALfloat* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBuffer3f(ALuint buffer, ALenum param, ALfloat* value1, ALfloat* value2, ALfloat* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBufferfv(ALuint buffer, ALenum param, ALfloat* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBufferi(ALuint buffer, ALenum param, ALint* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBuffer3i(ALuint buffer, ALenum param, ALint* value1, ALint* value2, ALint* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBufferiv(ALuint buffer, ALenum param, ALint* values);

/** Pointer-to-function type, useful for dynamically getting AL entry points. */
/+
typedef void          (/*AL_APIENTRY*/ *LPALENABLE)(ALenum capability);
typedef void          (/*AL_APIENTRY*/ *LPALDISABLE)(ALenum capability);
typedef ALboolean     (/*AL_APIENTRY*/ *LPALISENABLED)(ALenum capability);
typedef const(ALchar)* (/*AL_APIENTRY*/ *LPALGETSTRING)(ALenum param);
typedef void          (/*AL_APIENTRY*/ *LPALGETBOOLEANV)(ALenum param, ALboolean *values);
typedef void          (/*AL_APIENTRY*/ *LPALGETINTEGERV)(ALenum param, ALint *values);
typedef void          (/*AL_APIENTRY*/ *LPALGETFLOATV)(ALenum param, ALfloat *values);
typedef void          (/*AL_APIENTRY*/ *LPALGETDOUBLEV)(ALenum param, ALdouble *values);
typedef ALboolean     (/*AL_APIENTRY*/ *LPALGETBOOLEAN)(ALenum param);
typedef ALint         (/*AL_APIENTRY*/ *LPALGETINTEGER)(ALenum param);
typedef ALfloat       (/*AL_APIENTRY*/ *LPALGETFLOAT)(ALenum param);
typedef ALdouble      (/*AL_APIENTRY*/ *LPALGETDOUBLE)(ALenum param);
typedef ALenum        (/*AL_APIENTRY*/ *LPALGETERROR)(void);
typedef ALboolean     (/*AL_APIENTRY*/ *LPALISEXTENSIONPRESENT)(const(ALchar)* extname);
typedef void*         (/*AL_APIENTRY*/ *LPALGETPROCADDRESS)(const(ALchar)* fname);
typedef ALenum        (/*AL_APIENTRY*/ *LPALGETENUMVALUE)(const(ALchar)* ename);
typedef void          (/*AL_APIENTRY*/ *LPALLISTENERF)(ALenum param, ALfloat value);
typedef void          (/*AL_APIENTRY*/ *LPALLISTENER3F)(ALenum param, ALfloat value1, ALfloat value2, ALfloat value3);
typedef void          (/*AL_APIENTRY*/ *LPALLISTENERFV)(ALenum param, const(ALfloat)* values);
typedef void          (/*AL_APIENTRY*/ *LPALLISTENERI)(ALenum param, ALint value);
typedef void          (/*AL_APIENTRY*/ *LPALLISTENER3I)(ALenum param, ALint value1, ALint value2, ALint value3);
typedef void          (/*AL_APIENTRY*/ *LPALLISTENERIV)(ALenum param, const(ALint)* values);
typedef void          (/*AL_APIENTRY*/ *LPALGETLISTENERF)(ALenum param, ALfloat *value);
typedef void          (/*AL_APIENTRY*/ *LPALGETLISTENER3F)(ALenum param, ALfloat *value1, ALfloat *value2, ALfloat *value3);
typedef void          (/*AL_APIENTRY*/ *LPALGETLISTENERFV)(ALenum param, ALfloat *values);
typedef void          (/*AL_APIENTRY*/ *LPALGETLISTENERI)(ALenum param, ALint *value);
typedef void          (/*AL_APIENTRY*/ *LPALGETLISTENER3I)(ALenum param, ALint *value1, ALint *value2, ALint *value3);
typedef void          (/*AL_APIENTRY*/ *LPALGETLISTENERIV)(ALenum param, ALint *values);
typedef void          (/*AL_APIENTRY*/ *LPALGENSOURCES)(ALsizei n, ALuint *sources);
typedef void          (/*AL_APIENTRY*/ *LPALDELETESOURCES)(ALsizei n, const(ALuint)* sources);
typedef ALboolean     (/*AL_APIENTRY*/ *LPALISSOURCE)(ALuint source);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEF)(ALuint source, ALenum param, ALfloat value);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCE3F)(ALuint source, ALenum param, ALfloat value1, ALfloat value2, ALfloat value3);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEFV)(ALuint source, ALenum param, const(ALfloat)* values);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEI)(ALuint source, ALenum param, ALint value);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCE3I)(ALuint source, ALenum param, ALint value1, ALint value2, ALint value3);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEIV)(ALuint source, ALenum param, const(ALint)* values);
typedef void          (/*AL_APIENTRY*/ *LPALGETSOURCEF)(ALuint source, ALenum param, ALfloat *value);
typedef void          (/*AL_APIENTRY*/ *LPALGETSOURCE3F)(ALuint source, ALenum param, ALfloat *value1, ALfloat *value2, ALfloat *value3);
typedef void          (/*AL_APIENTRY*/ *LPALGETSOURCEFV)(ALuint source, ALenum param, ALfloat *values);
typedef void          (/*AL_APIENTRY*/ *LPALGETSOURCEI)(ALuint source, ALenum param, ALint *value);
typedef void          (/*AL_APIENTRY*/ *LPALGETSOURCE3I)(ALuint source, ALenum param, ALint *value1, ALint *value2, ALint *value3);
typedef void          (/*AL_APIENTRY*/ *LPALGETSOURCEIV)(ALuint source, ALenum param, ALint *values);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEPLAYV)(ALsizei n, const(ALuint)* sources);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCESTOPV)(ALsizei n, const(ALuint)* sources);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEREWINDV)(ALsizei n, const(ALuint)* sources);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEPAUSEV)(ALsizei n, const(ALuint)* sources);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEPLAY)(ALuint source);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCESTOP)(ALuint source);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEREWIND)(ALuint source);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEPAUSE)(ALuint source);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEQUEUEBUFFERS)(ALuint source, ALsizei nb, const(ALuint)* buffers);
typedef void          (/*AL_APIENTRY*/ *LPALSOURCEUNQUEUEBUFFERS)(ALuint source, ALsizei nb, ALuint *buffers);
typedef void          (/*AL_APIENTRY*/ *LPALGENBUFFERS)(ALsizei n, ALuint *buffers);
typedef void          (/*AL_APIENTRY*/ *LPALDELETEBUFFERS)(ALsizei n, const(ALuint)* buffers);
typedef ALboolean     (/*AL_APIENTRY*/ *LPALISBUFFER)(ALuint buffer);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFERDATA)(ALuint buffer, ALenum format, const(ALvoid)* data, ALsizei size, ALsizei freq);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFERF)(ALuint buffer, ALenum param, ALfloat value);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFER3F)(ALuint buffer, ALenum param, ALfloat value1, ALfloat value2, ALfloat value3);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFERFV)(ALuint buffer, ALenum param, const(ALfloat)* values);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFERI)(ALuint buffer, ALenum param, ALint value);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFER3I)(ALuint buffer, ALenum param, ALint value1, ALint value2, ALint value3);
typedef void          (/*AL_APIENTRY*/ *LPALBUFFERIV)(ALuint buffer, ALenum param, const(ALint)* values);
typedef void          (/*AL_APIENTRY*/ *LPALGETBUFFERF)(ALuint buffer, ALenum param, ALfloat *value);
typedef void          (/*AL_APIENTRY*/ *LPALGETBUFFER3F)(ALuint buffer, ALenum param, ALfloat *value1, ALfloat *value2, ALfloat *value3);
typedef void          (/*AL_APIENTRY*/ *LPALGETBUFFERFV)(ALuint buffer, ALenum param, ALfloat *values);
typedef void          (/*AL_APIENTRY*/ *LPALGETBUFFERI)(ALuint buffer, ALenum param, ALint *value);
typedef void          (/*AL_APIENTRY*/ *LPALGETBUFFER3I)(ALuint buffer, ALenum param, ALint *value1, ALint *value2, ALint *value3);
typedef void          (/*AL_APIENTRY*/ *LPALGETBUFFERIV)(ALuint buffer, ALenum param, ALint *values);
typedef void          (/*AL_APIENTRY*/ *LPALDOPPLERFACTOR)(ALfloat value);
typedef void          (/*AL_APIENTRY*/ *LPALDOPPLERVELOCITY)(ALfloat value);
typedef void          (/*AL_APIENTRY*/ *LPALSPEEDOFSOUND)(ALfloat value);
typedef void          (/*AL_APIENTRY*/ *LPALDISTANCEMODEL)(ALenum distanceModel);
+/

/** Deprecated macro. */
//enum ALCAPI = ALC_API;
//enum ALCAPIENTRY = ALC_APIENTRY;
enum ALC_INVALID = 0;

/** Supported ALC version? */
enum ALC_VERSION_0_1 = 1;

/** Opaque device handle */
//typedef struct ALCdevice_struct ALCdevice;
struct ALCdevice {}
/** Opaque context handle */
//typedef struct ALCcontext_struct ALCcontext;
struct ALCcontext {}

/** 8-bit boolean */
alias ALCboolean = ubyte;

/** character */
alias ALCchar = char;

/** signed 8-bit 2's complement integer */
alias ALCbyte = byte;

/** unsigned 8-bit integer */
alias ALCubyte = ubyte;

/** signed 16-bit 2's complement integer */
alias ALCshort = short;

/** unsigned 16-bit integer */
alias ALCushort = ushort;

/** signed 32-bit 2's complement integer */
alias ALCint = int;

/** unsigned 32-bit integer */
alias ALCuint = uint;

/** non-negative 32-bit binary integer size */
alias ALCsizei = int;

/** enumerated 32-bit value */
alias ALCenum = int;

/** 32-bit IEEE754 floating-point */
alias ALCfloat = float;

/** 64-bit IEEE754 floating-point */
alias ALCdouble = double;

/** void type (for opaque pointers only) */
alias ALCvoid = void;


/* Enumerant values begin at column 50. No tabs. */

/** Boolean False. */
enum ALC_FALSE = 0;

/** Boolean True. */
enum ALC_TRUE = 1;

/** Context attribute: <int> Hz. */
enum ALC_FREQUENCY = 0x1007;

/** Context attribute: <int> Hz. */
enum ALC_REFRESH = 0x1008;

/** Context attribute: AL_TRUE or AL_FALSE. */
enum ALC_SYNC = 0x1009;

/** Context attribute: <int> requested Mono (3D) Sources. */
enum ALC_MONO_SOURCES = 0x1010;

/** Context attribute: <int> requested Stereo Sources. */
enum ALC_STEREO_SOURCES = 0x1011;

/** No error. */
enum ALC_NO_ERROR = 0;

/** Invalid device handle. */
enum ALC_INVALID_DEVICE = 0xA001;

/** Invalid context handle. */
enum ALC_INVALID_CONTEXT = 0xA002;

/** Invalid enum parameter passed to an ALC call. */
enum ALC_INVALID_ENUM = 0xA003;

/** Invalid value parameter passed to an ALC call. */
enum ALC_INVALID_VALUE = 0xA004;

/** Out of memory. */
enum ALC_OUT_OF_MEMORY = 0xA005;


/** Runtime ALC version. */
enum ALC_MAJOR_VERSION = 0x1000;
enum ALC_MINOR_VERSION = 0x1001;

/** Context attribute list properties. */
enum ALC_ATTRIBUTES_SIZE = 0x1002;
enum ALC_ALL_ATTRIBUTES = 0x1003;

/** String for the default device specifier. */
enum ALC_DEFAULT_DEVICE_SPECIFIER = 0x1004;
/**
 * String for the given device's specifier.
 *
 * If device handle is NULL, it is instead a null-char separated list of
 * strings of known device specifiers (list ends with an empty string).
 */
enum ALC_DEVICE_SPECIFIER = 0x1005;
/** String for space-separated list of ALC extensions. */
enum ALC_EXTENSIONS = 0x1006;


/** Capture extension */
enum ALC_EXT_CAPTURE = 1;
/**
 * String for the given capture device's specifier.
 *
 * If device handle is NULL, it is instead a null-char separated list of
 * strings of known capture device specifiers (list ends with an empty string).
 */
enum ALC_CAPTURE_DEVICE_SPECIFIER = 0x310;
/** String for the default capture device specifier. */
enum ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER = 0x311;
/** Number of sample frames available for capture. */
enum ALC_CAPTURE_SAMPLES = 0x312;


/** Enumerate All extension */
enum ALC_ENUMERATE_ALL_EXT = 1;
/** String for the default extended device specifier. */
enum ALC_DEFAULT_ALL_DEVICES_SPECIFIER = 0x1012;
/**
 * String for the given extended device's specifier.
 *
 * If device handle is NULL, it is instead a null-char separated list of
 * strings of known extended device specifiers (list ends with an empty string).
 */
enum ALC_ALL_DEVICES_SPECIFIER = 0x1013;


/** Context management. */
/*ALC_API*/ ALCcontext* /*ALC_APIENTRY*/ alcCreateContext(ALCdevice* device, const(ALCint)* attrlist);
/*ALC_API*/ ALCboolean  /*ALC_APIENTRY*/ alcMakeContextCurrent(ALCcontext* context);
/*ALC_API*/ void        /*ALC_APIENTRY*/ alcProcessContext(ALCcontext* context);
/*ALC_API*/ void        /*ALC_APIENTRY*/ alcSuspendContext(ALCcontext* context);
/*ALC_API*/ void        /*ALC_APIENTRY*/ alcDestroyContext(ALCcontext* context);
/*ALC_API*/ ALCcontext* /*ALC_APIENTRY*/ alcGetCurrentContext();
/*ALC_API*/ ALCdevice* /*ALC_APIENTRY*/ alcGetContextsDevice(ALCcontext* context);

/** Device management. */
/*ALC_API*/ ALCdevice* /*ALC_APIENTRY*/ alcOpenDevice(const(ALCchar)* devicename);
/*ALC_API*/ ALCboolean /*ALC_APIENTRY*/ alcCloseDevice(ALCdevice* device);


/**
 * Error support.
 *
 * Obtain the most recent Device error.
 */
/*ALC_API*/ ALCenum /*ALC_APIENTRY*/ alcGetError(ALCdevice* device);

/**
 * Extension support.
 *
 * Query for the presence of an extension, and obtain any appropriate
 * function pointers and enum values.
 */
/*ALC_API*/ ALCboolean /*ALC_APIENTRY*/ alcIsExtensionPresent(ALCdevice* device, const(ALCchar)* extname);
/*ALC_API*/ void* /*ALC_APIENTRY*/ alcGetProcAddress(ALCdevice* device, const(ALCchar)* funcname);
/*ALC_API*/ ALCenum    /*ALC_APIENTRY*/ alcGetEnumValue(ALCdevice* device, const(ALCchar)* enumname);

/** Query function. */
/*ALC_API*/ const(ALCchar)* /*ALC_APIENTRY*/ alcGetString(ALCdevice* device, ALCenum param);
/*ALC_API*/ void           /*ALC_APIENTRY*/ alcGetIntegerv(ALCdevice* device, ALCenum param, ALCsizei size, ALCint* values);

/** Capture function. */
/*ALC_API*/ ALCdevice* /*ALC_APIENTRY*/ alcCaptureOpenDevice(const(ALCchar)* devicename, ALCuint frequency, ALCenum format, ALCsizei buffersize);
/*ALC_API*/ ALCboolean /*ALC_APIENTRY*/ alcCaptureCloseDevice(ALCdevice* device);
/*ALC_API*/ void       /*ALC_APIENTRY*/ alcCaptureStart(ALCdevice* device);
/*ALC_API*/ void       /*ALC_APIENTRY*/ alcCaptureStop(ALCdevice* device);
/*ALC_API*/ void       /*ALC_APIENTRY*/ alcCaptureSamples(ALCdevice* device, ALCvoid* buffer, ALCsizei samples);

/** Pointer-to-function type, useful for dynamically getting ALC entry points. */
/+
typedef ALCcontext* (/*ALC_APIENTRY*/ *LPALCCREATECONTEXT)(ALCdevice* device, const(ALCint)* attrlist);
typedef ALCboolean     (/*ALC_APIENTRY*/ *LPALCMAKECONTEXTCURRENT)(ALCcontext* context);
typedef void           (/*ALC_APIENTRY*/ *LPALCPROCESSCONTEXT)(ALCcontext* context);
typedef void           (/*ALC_APIENTRY*/ *LPALCSUSPENDCONTEXT)(ALCcontext* context);
typedef void           (/*ALC_APIENTRY*/ *LPALCDESTROYCONTEXT)(ALCcontext* context);
typedef ALCcontext* (/*ALC_APIENTRY*/ *LPALCGETCURRENTCONTEXT)(void);
typedef ALCdevice* (/*ALC_APIENTRY*/ *LPALCGETCONTEXTSDEVICE)(ALCcontext* context);
typedef ALCdevice* (/*ALC_APIENTRY*/ *LPALCOPENDEVICE)(const(ALCchar)* devicename);
typedef ALCboolean     (/*ALC_APIENTRY*/ *LPALCCLOSEDEVICE)(ALCdevice* device);
typedef ALCenum        (/*ALC_APIENTRY*/ *LPALCGETERROR)(ALCdevice* device);
typedef ALCboolean     (/*ALC_APIENTRY*/ *LPALCISEXTENSIONPRESENT)(ALCdevice* device, const(ALCchar)* extname);
typedef void*          (/*ALC_APIENTRY*/ *LPALCGETPROCADDRESS)(ALCdevice* device, const(ALCchar)* funcname);
typedef ALCenum        (/*ALC_APIENTRY*/ *LPALCGETENUMVALUE)(ALCdevice* device, const(ALCchar)* enumname);
typedef const(ALCchar)* (/*ALC_APIENTRY*/ *LPALCGETSTRING)(ALCdevice* device, ALCenum param);
typedef void           (/*ALC_APIENTRY*/ *LPALCGETINTEGERV)(ALCdevice* device, ALCenum param, ALCsizei size, ALCint *values);
typedef ALCdevice* (/*ALC_APIENTRY*/ *LPALCCAPTUREOPENDEVICE)(const(ALCchar)* devicename, ALCuint frequency, ALCenum format, ALCsizei buffersize);
typedef ALCboolean     (/*ALC_APIENTRY*/ *LPALCCAPTURECLOSEDEVICE)(ALCdevice* device);
typedef void           (/*ALC_APIENTRY*/ *LPALCCAPTURESTART)(ALCdevice* device);
typedef void           (/*ALC_APIENTRY*/ *LPALCCAPTURESTOP)(ALCdevice* device);
typedef void           (/*ALC_APIENTRY*/ *LPALCCAPTURESAMPLES)(ALCdevice* device, ALCvoid *buffer, ALCsizei samples);
+/

enum AL_LOKI_IMA_ADPCM_format = true;
enum AL_FORMAT_IMA_ADPCM_MONO16_EXT = 0x10000;
enum AL_FORMAT_IMA_ADPCM_STEREO16_EXT = 0x10001;

enum AL_LOKI_WAVE_format = true;
enum AL_FORMAT_WAVE_EXT = 0x10002;

enum AL_EXT_vorbis = true;
enum AL_FORMAT_VORBIS_EXT = 0x10003;

enum AL_LOKI_quadriphonic = true;
enum AL_FORMAT_QUAD8_LOKI = 0x10004;
enum AL_FORMAT_QUAD16_LOKI = 0x10005;

enum AL_EXT_float32 = true;
enum AL_FORMAT_MONO_FLOAT32 = 0x10010;
enum AL_FORMAT_STEREO_FLOAT32 = 0x10011;

enum AL_EXT_double = true;
enum AL_FORMAT_MONO_DOUBLE_EXT = 0x10012;
enum AL_FORMAT_STEREO_DOUBLE_EXT = 0x10013;

enum AL_EXT_MULAW = true;
enum AL_FORMAT_MONO_MULAW_EXT = 0x10014;
enum AL_FORMAT_STEREO_MULAW_EXT = 0x10015;

enum AL_EXT_ALAW = true;
enum AL_FORMAT_MONO_ALAW_EXT = 0x10016;
enum AL_FORMAT_STEREO_ALAW_EXT = 0x10017;

enum ALC_LOKI_audio_channel = true;
enum ALC_CHAN_MAIN_LOKI = 0x500001;
enum ALC_CHAN_PCM_LOKI = 0x500002;
enum ALC_CHAN_CD_LOKI = 0x500003;

enum AL_EXT_MCFORMATS = true;
enum AL_FORMAT_QUAD8 = 0x1204;
enum AL_FORMAT_QUAD16 = 0x1205;
enum AL_FORMAT_QUAD32 = 0x1206;
enum AL_FORMAT_REAR8 = 0x1207;
enum AL_FORMAT_REAR16 = 0x1208;
enum AL_FORMAT_REAR32 = 0x1209;
enum AL_FORMAT_51CHN8 = 0x120A;
enum AL_FORMAT_51CHN16 = 0x120B;
enum AL_FORMAT_51CHN32 = 0x120C;
enum AL_FORMAT_61CHN8 = 0x120D;
enum AL_FORMAT_61CHN16 = 0x120E;
enum AL_FORMAT_61CHN32 = 0x120F;
enum AL_FORMAT_71CHN8 = 0x1210;
enum AL_FORMAT_71CHN16 = 0x1211;
enum AL_FORMAT_71CHN32 = 0x1212;

enum AL_EXT_MULAW_MCFORMATS = true;
enum AL_FORMAT_MONO_MULAW = 0x10014;
enum AL_FORMAT_STEREO_MULAW = 0x10015;
enum AL_FORMAT_QUAD_MULAW = 0x10021;
enum AL_FORMAT_REAR_MULAW = 0x10022;
enum AL_FORMAT_51CHN_MULAW = 0x10023;
enum AL_FORMAT_61CHN_MULAW = 0x10024;
enum AL_FORMAT_71CHN_MULAW = 0x10025;

enum AL_EXT_IMA4 = true;
enum AL_FORMAT_MONO_IMA4 = 0x1300;
enum AL_FORMAT_STEREO_IMA4 = 0x1301;

enum AL_EXT_STATIC_BUFFER = true;
//typedef ALvoid (/*AL_APIENTRY*/*PFNALBUFFERDATASTATICPROC)(const ALint,ALenum,ALvoid*,ALsizei,ALsizei);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alBufferDataStatic(const ALint buffer, ALenum format, ALvoid* data, ALsizei len, ALsizei freq);

enum ALC_EXT_EFX = true;
//#include "efx.h" // below

enum ALC_EXT_disconnect = true;
enum ALC_CONNECTED = 0x313;

enum ALC_EXT_thread_local_context = true;
//typedef ALCboolean  (/*ALC_APIENTRY*/*PFNALCSETTHREADCONTEXTPROC)(ALCcontext* context);
//typedef ALCcontext* (/*ALC_APIENTRY*/*PFNALCGETTHREADCONTEXTPROC)(void);
/*ALC_API*/ ALCboolean  /*ALC_APIENTRY*/ alcSetThreadContext(ALCcontext* context);
/*ALC_API*/ ALCcontext* /*ALC_APIENTRY*/ alcGetThreadContext();

enum AL_EXT_source_distance_model = true;
enum AL_SOURCE_DISTANCE_MODEL = 0x200;

enum AL_SOFT_buffer_sub_data = true;
enum AL_BYTE_RW_OFFSETS_SOFT = 0x1031;
enum AL_SAMPLE_RW_OFFSETS_SOFT = 0x1032;
//typedef ALvoid (/*AL_APIENTRY*/*PFNALBUFFERSUBDATASOFTPROC)(ALuint,ALenum,const(ALvoid)* ,ALsizei,ALsizei);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alBufferSubDataSOFT(ALuint buffer,ALenum format,const(ALvoid)* data,ALsizei offset,ALsizei length);

enum AL_SOFT_loop_points = true;
enum AL_LOOP_POINTS_SOFT = 0x2015;

enum AL_EXT_FOLDBACK = true;
enum AL_EXT_FOLDBACK_NAME = "AL_EXT_FOLDBACK";
enum AL_FOLDBACK_EVENT_BLOCK = 0x4112;
enum AL_FOLDBACK_EVENT_START = 0x4111;
enum AL_FOLDBACK_EVENT_STOP = 0x4113;
enum AL_FOLDBACK_MODE_MONO = 0x4101;
enum AL_FOLDBACK_MODE_STEREO = 0x4102;
//typedef void (/*AL_APIENTRY*/*LPALFOLDBACKCALLBACK)(ALenum,ALsizei);
alias LPALFOLDBACKCALLBACK = void function (ALenum,ALsizei);
//typedef void (/*AL_APIENTRY*/*LPALREQUESTFOLDBACKSTART)(ALenum,ALsizei,ALsizei,ALfloat*,LPALFOLDBACKCALLBACK);
//typedef void (/*AL_APIENTRY*/*LPALREQUESTFOLDBACKSTOP)();
/*AL_API*/ void /*AL_APIENTRY*/ alRequestFoldbackStart(ALenum mode,ALsizei count,ALsizei length,ALfloat* mem,LPALFOLDBACKCALLBACK callback);
/*AL_API*/ void /*AL_APIENTRY*/ alRequestFoldbackStop();

enum ALC_EXT_DEDICATED = true;
enum AL_DEDICATED_GAIN = 0x0001;
enum AL_EFFECT_DEDICATED_DIALOGUE = 0x9001;
enum AL_EFFECT_DEDICATED_LOW_FREQUENCY_EFFECT = 0x9000;

enum AL_SOFT_buffer_samples = true;
/* Channel configurations */
enum AL_MONO_SOFT = 0x1500;
enum AL_STEREO_SOFT = 0x1501;
enum AL_REAR_SOFT = 0x1502;
enum AL_QUAD_SOFT = 0x1503;
enum AL_5POINT1_SOFT = 0x1504;
enum AL_6POINT1_SOFT = 0x1505;
enum AL_7POINT1_SOFT = 0x1506;

/* Sample types */
enum AL_BYTE_SOFT = 0x1400;
enum AL_UNSIGNED_BYTE_SOFT = 0x1401;
enum AL_SHORT_SOFT = 0x1402;
enum AL_UNSIGNED_SHORT_SOFT = 0x1403;
enum AL_INT_SOFT = 0x1404;
enum AL_UNSIGNED_INT_SOFT = 0x1405;
enum AL_FLOAT_SOFT = 0x1406;
enum AL_DOUBLE_SOFT = 0x1407;
enum AL_BYTE3_SOFT = 0x1408;
enum AL_UNSIGNED_BYTE3_SOFT = 0x1409;

/* Storage formats */
enum AL_MONO8_SOFT = 0x1100;
enum AL_MONO16_SOFT = 0x1101;
enum AL_MONO32F_SOFT = 0x10010;
enum AL_STEREO8_SOFT = 0x1102;
enum AL_STEREO16_SOFT = 0x1103;
enum AL_STEREO32F_SOFT = 0x10011;
enum AL_QUAD8_SOFT = 0x1204;
enum AL_QUAD16_SOFT = 0x1205;
enum AL_QUAD32F_SOFT = 0x1206;
enum AL_REAR8_SOFT = 0x1207;
enum AL_REAR16_SOFT = 0x1208;
enum AL_REAR32F_SOFT = 0x1209;
enum AL_5POINT1_8_SOFT = 0x120A;
enum AL_5POINT1_16_SOFT = 0x120B;
enum AL_5POINT1_32F_SOFT = 0x120C;
enum AL_6POINT1_8_SOFT = 0x120D;
enum AL_6POINT1_16_SOFT = 0x120E;
enum AL_6POINT1_32F_SOFT = 0x120F;
enum AL_7POINT1_8_SOFT = 0x1210;
enum AL_7POINT1_16_SOFT = 0x1211;
enum AL_7POINT1_32F_SOFT = 0x1212;

/* Buffer attributes */
enum AL_INTERNAL_FORMAT_SOFT = 0x2008;
enum AL_BYTE_LENGTH_SOFT = 0x2009;
enum AL_SAMPLE_LENGTH_SOFT = 0x200A;
enum AL_SEC_LENGTH_SOFT = 0x200B;

//typedef void (/*AL_APIENTRY*/*LPALBUFFERSAMPLESSOFT)(ALuint,ALuint,ALenum,ALsizei,ALenum,ALenum,const(ALvoid)* );
//typedef void (/*AL_APIENTRY*/*LPALBUFFERSUBSAMPLESSOFT)(ALuint,ALsizei,ALsizei,ALenum,ALenum,const(ALvoid)* );
//typedef void (/*AL_APIENTRY*/*LPALGETBUFFERSAMPLESSOFT)(ALuint,ALsizei,ALsizei,ALenum,ALenum,ALvoid*);
//typedef ALboolean (/*AL_APIENTRY*/*LPALISBUFFERFORMATSUPPORTEDSOFT)(ALenum);
/*AL_API*/ void /*AL_APIENTRY*/ alBufferSamplesSOFT(ALuint buffer, ALuint samplerate, ALenum internalformat, ALsizei samples, ALenum channels, ALenum type, const(ALvoid)* data);
/*AL_API*/ void /*AL_APIENTRY*/ alBufferSubSamplesSOFT(ALuint buffer, ALsizei offset, ALsizei samples, ALenum channels, ALenum type, const(ALvoid)* data);
/*AL_API*/ void /*AL_APIENTRY*/ alGetBufferSamplesSOFT(ALuint buffer, ALsizei offset, ALsizei samples, ALenum channels, ALenum type, ALvoid* data);
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsBufferFormatSupportedSOFT(ALenum format);

enum AL_SOFT_direct_channels = true;
enum AL_DIRECT_CHANNELS_SOFT = 0x1033;

enum ALC_SOFT_loopback = true;
enum ALC_FORMAT_CHANNELS_SOFT = 0x1990;
enum ALC_FORMAT_TYPE_SOFT = 0x1991;

/* Sample types */
enum ALC_BYTE_SOFT = 0x1400;
enum ALC_UNSIGNED_BYTE_SOFT = 0x1401;
enum ALC_SHORT_SOFT = 0x1402;
enum ALC_UNSIGNED_SHORT_SOFT = 0x1403;
enum ALC_INT_SOFT = 0x1404;
enum ALC_UNSIGNED_INT_SOFT = 0x1405;
enum ALC_FLOAT_SOFT = 0x1406;

/* Channel configurations */
enum ALC_MONO_SOFT = 0x1500;
enum ALC_STEREO_SOFT = 0x1501;
enum ALC_QUAD_SOFT = 0x1503;
enum ALC_5POINT1_SOFT = 0x1504;
enum ALC_6POINT1_SOFT = 0x1505;
enum ALC_7POINT1_SOFT = 0x1506;

//typedef ALCdevice* (/*ALC_APIENTRY*/*LPALCLOOPBACKOPENDEVICESOFT)(const(ALCchar)* );
//typedef ALCboolean (/*ALC_APIENTRY*/*LPALCISRENDERFORMATSUPPORTEDSOFT)(ALCdevice* ,ALCsizei,ALCenum,ALCenum);
//typedef void (/*ALC_APIENTRY*/*LPALCRENDERSAMPLESSOFT)(ALCdevice* ,ALCvoid*,ALCsizei);
/*ALC_API*/ ALCdevice* /*ALC_APIENTRY*/ alcLoopbackOpenDeviceSOFT(const(ALCchar)* deviceName);
/*ALC_API*/ ALCboolean /*ALC_APIENTRY*/ alcIsRenderFormatSupportedSOFT(ALCdevice* device, ALCsizei freq, ALCenum channels, ALCenum type);
/*ALC_API*/ void /*ALC_APIENTRY*/ alcRenderSamplesSOFT(ALCdevice* device, ALCvoid* buffer, ALCsizei samples);

enum AL_EXT_STEREO_ANGLES = true;
enum AL_STEREO_ANGLES = 0x1030;

enum AL_EXT_SOURCE_RADIUS = true;
enum AL_SOURCE_RADIUS = 0x1031;

enum AL_SOFT_source_latency = true;
enum AL_SAMPLE_OFFSET_LATENCY_SOFT = 0x1200;
enum AL_SEC_OFFSET_LATENCY_SOFT = 0x1201;
alias ALint64SOFT = long;
alias ALuint64SOFT = ulong;
/+
typedef void (/*AL_APIENTRY*/*LPALSOURCEDSOFT)(ALuint,ALenum,ALdouble);
typedef void (/*AL_APIENTRY*/*LPALSOURCE3DSOFT)(ALuint,ALenum,ALdouble,ALdouble,ALdouble);
typedef void (/*AL_APIENTRY*/*LPALSOURCEDVSOFT)(ALuint,ALenum,const(ALdouble)* );
typedef void (/*AL_APIENTRY*/*LPALGETSOURCEDSOFT)(ALuint,ALenum,ALdouble*);
typedef void (/*AL_APIENTRY*/*LPALGETSOURCE3DSOFT)(ALuint,ALenum,ALdouble*,ALdouble*,ALdouble*);
typedef void (/*AL_APIENTRY*/*LPALGETSOURCEDVSOFT)(ALuint,ALenum,ALdouble*);
typedef void (/*AL_APIENTRY*/*LPALSOURCEI64SOFT)(ALuint,ALenum,ALint64SOFT);
typedef void (/*AL_APIENTRY*/*LPALSOURCE3I64SOFT)(ALuint,ALenum,ALint64SOFT,ALint64SOFT,ALint64SOFT);
typedef void (/*AL_APIENTRY*/*LPALSOURCEI64VSOFT)(ALuint,ALenum,const ALint64SOFT*);
typedef void (/*AL_APIENTRY*/*LPALGETSOURCEI64SOFT)(ALuint,ALenum,ALint64SOFT*);
typedef void (/*AL_APIENTRY*/*LPALGETSOURCE3I64SOFT)(ALuint,ALenum,ALint64SOFT*,ALint64SOFT*,ALint64SOFT*);
typedef void (/*AL_APIENTRY*/*LPALGETSOURCEI64VSOFT)(ALuint,ALenum,ALint64SOFT*);
+/
/*AL_API*/ void /*AL_APIENTRY*/ alSourcedSOFT(ALuint source, ALenum param, ALdouble value);
/*AL_API*/ void /*AL_APIENTRY*/ alSource3dSOFT(ALuint source, ALenum param, ALdouble value1, ALdouble value2, ALdouble value3);
/*AL_API*/ void /*AL_APIENTRY*/ alSourcedvSOFT(ALuint source, ALenum param, const(ALdouble)* values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcedSOFT(ALuint source, ALenum param, ALdouble* value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSource3dSOFT(ALuint source, ALenum param, ALdouble* value1, ALdouble* value2, ALdouble* value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcedvSOFT(ALuint source, ALenum param, ALdouble* values);
/*AL_API*/ void /*AL_APIENTRY*/ alSourcei64SOFT(ALuint source, ALenum param, ALint64SOFT value);
/*AL_API*/ void /*AL_APIENTRY*/ alSource3i64SOFT(ALuint source, ALenum param, ALint64SOFT value1, ALint64SOFT value2, ALint64SOFT value3);
/*AL_API*/ void /*AL_APIENTRY*/ alSourcei64vSOFT(ALuint source, ALenum param, const ALint64SOFT *values);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcei64SOFT(ALuint source, ALenum param, ALint64SOFT *value);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSource3i64SOFT(ALuint source, ALenum param, ALint64SOFT *value1, ALint64SOFT *value2, ALint64SOFT *value3);
/*AL_API*/ void /*AL_APIENTRY*/ alGetSourcei64vSOFT(ALuint source, ALenum param, ALint64SOFT *values);

enum ALC_EXT_DEFAULT_FILTER_ORDER = true;
enum ALC_DEFAULT_FILTER_ORDER = 0x1100;

enum AL_SOFT_deferred_updates = true;
enum AL_DEFERRED_UPDATES_SOFT = 0xC002;
//typedef ALvoid (/*AL_APIENTRY*/*LPALDEFERUPDATESSOFT)();
//typedef ALvoid (/*AL_APIENTRY*/*LPALPROCESSUPDATESSOFT)();
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alDeferUpdatesSOFT();
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alProcessUpdatesSOFT();

enum AL_SOFT_block_alignment = true;
enum AL_UNPACK_BLOCK_ALIGNMENT_SOFT = 0x200C;
enum AL_PACK_BLOCK_ALIGNMENT_SOFT = 0x200D;

enum AL_SOFT_MSADPCM = true;
enum AL_FORMAT_MONO_MSADPCM_SOFT = 0x1302;
enum AL_FORMAT_STEREO_MSADPCM_SOFT = 0x1303;

enum AL_SOFT_source_length = true;
//??? it was commented in the original C header
/*#define AL_BYTE_LENGTH_SOFT                      0x2009*/
/*#define AL_SAMPLE_LENGTH_SOFT                    0x200A*/
/*#define AL_SEC_LENGTH_SOFT                       0x200B*/

enum ALC_SOFT_pause_device = true;
//typedef void (/*ALC_APIENTRY*/*LPALCDEVICEPAUSESOFT)(ALCdevice* device);
//typedef void (/*ALC_APIENTRY*/*LPALCDEVICERESUMESOFT)(ALCdevice* device);
/*ALC_API*/ void /*ALC_APIENTRY*/ alcDevicePauseSOFT(ALCdevice* device);
/*ALC_API*/ void /*ALC_APIENTRY*/ alcDeviceResumeSOFT(ALCdevice* device);

enum AL_EXT_BFORMAT = true;
enum AL_FORMAT_BFORMAT2D_8 = 0x20021;
enum AL_FORMAT_BFORMAT2D_16 = 0x20022;
enum AL_FORMAT_BFORMAT2D_FLOAT32 = 0x20023;
enum AL_FORMAT_BFORMAT3D_8 = 0x20031;
enum AL_FORMAT_BFORMAT3D_16 = 0x20032;
enum AL_FORMAT_BFORMAT3D_FLOAT32 = 0x20033;

enum AL_EXT_MULAW_BFORMAT = true;
enum AL_FORMAT_BFORMAT2D_MULAW = 0x10031;
enum AL_FORMAT_BFORMAT3D_MULAW = 0x10032;

enum ALC_SOFT_HRTF = true;
enum ALC_HRTF_SOFT = 0x1992;
enum ALC_DONT_CARE_SOFT = 0x0002;
enum ALC_HRTF_STATUS_SOFT = 0x1993;
enum ALC_HRTF_DISABLED_SOFT = 0x0000;
enum ALC_HRTF_ENABLED_SOFT = 0x0001;
enum ALC_HRTF_DENIED_SOFT = 0x0002;
enum ALC_HRTF_REQUIRED_SOFT = 0x0003;
enum ALC_HRTF_HEADPHONES_DETECTED_SOFT = 0x0004;
enum ALC_HRTF_UNSUPPORTED_FORMAT_SOFT = 0x0005;
enum ALC_NUM_HRTF_SPECIFIERS_SOFT = 0x1994;
enum ALC_HRTF_SPECIFIER_SOFT = 0x1995;
enum ALC_HRTF_ID_SOFT = 0x1996;
//typedef const(ALCchar)* (/*ALC_APIENTRY*/*LPALCGETSTRINGISOFT)(ALCdevice* device, ALCenum paramName, ALCsizei index);
//typedef ALCboolean (/*ALC_APIENTRY*/*LPALCRESETDEVICESOFT)(ALCdevice* device, const(ALCint)* attribs);
/*ALC_API*/ const(ALCchar)* /*ALC_APIENTRY*/ alcGetStringiSOFT(ALCdevice* device, ALCenum paramName, ALCsizei index);
/*ALC_API*/ ALCboolean /*ALC_APIENTRY*/ alcResetDeviceSOFT(ALCdevice* device, const(ALCint)* attribs);

enum AL_SOFT_gain_clamp_ex = true;
enum AL_GAIN_LIMIT_SOFT = 0x200E;

enum AL_SOFT_source_resampler = true;
enum AL_NUM_RESAMPLERS_SOFT = 0x1210;
enum AL_DEFAULT_RESAMPLER_SOFT = 0x1211;
enum AL_SOURCE_RESAMPLER_SOFT = 0x1212;
enum AL_RESAMPLER_NAME_SOFT = 0x1213;
//typedef const(ALchar)* (/*AL_APIENTRY*/*LPALGETSTRINGISOFT)(ALenum pname, ALsizei index);
/*AL_API*/ const(ALchar)* /*AL_APIENTRY*/ alGetStringiSOFT(ALenum pname, ALsizei index);

enum AL_SOFT_source_spatialize = true;
enum AL_SOURCE_SPATIALIZE_SOFT = 0x1214;
enum AL_AUTO_SOFT = 0x0002;

enum ALC_SOFT_output_limiter = true;
enum ALC_OUTPUT_LIMITER_SOFT = 0x199A;


// ////////////////////////////////////////////////////////////////////////// //
// ALUT
version(openal_alut) {
pragma(lib, "alut");
enum ALUT_API_MAJOR_VERSION = 1;
enum ALUT_API_MINOR_VERSION = 1;

enum ALUT_ERROR_NO_ERROR = 0;
enum ALUT_ERROR_OUT_OF_MEMORY = 0x200;
enum ALUT_ERROR_INVALID_ENUM = 0x201;
enum ALUT_ERROR_INVALID_VALUE = 0x202;
enum ALUT_ERROR_INVALID_OPERATION = 0x203;
enum ALUT_ERROR_NO_CURRENT_CONTEXT = 0x204;
enum ALUT_ERROR_AL_ERROR_ON_ENTRY = 0x205;
enum ALUT_ERROR_ALC_ERROR_ON_ENTRY = 0x206;
enum ALUT_ERROR_OPEN_DEVICE = 0x207;
enum ALUT_ERROR_CLOSE_DEVICE = 0x208;
enum ALUT_ERROR_CREATE_CONTEXT = 0x209;
enum ALUT_ERROR_MAKE_CONTEXT_CURRENT = 0x20A;
enum ALUT_ERROR_DESTROY_CONTEXT = 0x20B;
enum ALUT_ERROR_GEN_BUFFERS = 0x20C;
enum ALUT_ERROR_BUFFER_DATA = 0x20D;
enum ALUT_ERROR_IO_ERROR = 0x20E;
enum ALUT_ERROR_UNSUPPORTED_FILE_TYPE = 0x20F;
enum ALUT_ERROR_UNSUPPORTED_FILE_SUBTYPE = 0x210;
enum ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA = 0x211;

enum ALUT_WAVEFORM_SINE = 0x100;
enum ALUT_WAVEFORM_SQUARE = 0x101;
enum ALUT_WAVEFORM_SAWTOOTH = 0x102;
enum ALUT_WAVEFORM_WHITENOISE = 0x103;
enum ALUT_WAVEFORM_IMPULSE = 0x104;

enum ALUT_LOADER_BUFFER = 0x300;
enum ALUT_LOADER_MEMORY = 0x301;

/*ALUT_API*/ ALboolean /*ALUT_APIENTRY*/ alutInit (int* argcp, char** argv);
/*ALUT_API*/ ALboolean /*ALUT_APIENTRY*/ alutInitWithoutContext (int* argcp, char** argv);
/*ALUT_API*/ ALboolean /*ALUT_APIENTRY*/ alutExit ();

/*ALUT_API*/ ALenum /*ALUT_APIENTRY*/ alutGetError ();
/*ALUT_API*/ const(char)* /*ALUT_APIENTRY*/ alutGetErrorString (ALenum error);

/*ALUT_API*/ ALuint /*ALUT_APIENTRY*/ alutCreateBufferFromFile (const(char)* fileName);
/*ALUT_API*/ ALuint /*ALUT_APIENTRY*/ alutCreateBufferFromFileImage (const(ALvoid)* data, ALsizei length);
/*ALUT_API*/ ALuint /*ALUT_APIENTRY*/ alutCreateBufferHelloWorld ();
/*ALUT_API*/ ALuint /*ALUT_APIENTRY*/ alutCreateBufferWaveform (ALenum waveshape, ALfloat frequency, ALfloat phase, ALfloat duration);

/*ALUT_API*/ ALvoid* /*ALUT_APIENTRY*/ alutLoadMemoryFromFile (const(char)* fileName, ALenum* format, ALsizei* size, ALfloat* frequency);
/*ALUT_API*/ ALvoid* /*ALUT_APIENTRY*/ alutLoadMemoryFromFileImage (const(ALvoid)* data, ALsizei length, ALenum* format, ALsizei* size, ALfloat* frequency);
/*ALUT_API*/ ALvoid* /*ALUT_APIENTRY*/ alutLoadMemoryHelloWorld (ALenum* format, ALsizei* size, ALfloat* frequency);
/*ALUT_API*/ ALvoid* /*ALUT_APIENTRY*/ alutLoadMemoryWaveform (ALenum waveshape, ALfloat frequency, ALfloat phase, ALfloat duration, ALenum* format, ALsizei* size, ALfloat* freq);

/*ALUT_API*/ const(char)* /*ALUT_APIENTRY*/ alutGetMIMETypes (ALenum loader);

/*ALUT_API*/ ALint /*ALUT_APIENTRY*/ alutGetMajorVersion ();
/*ALUT_API*/ ALint /*ALUT_APIENTRY*/ alutGetMinorVersion ();

/*ALUT_API*/ ALboolean /*ALUT_APIENTRY*/ alutSleep (ALfloat duration);

/* Nasty Compatibility stuff, WARNING: THESE FUNCTIONS ARE STRONGLY DEPRECATED */
/*ALUT_API*/ /*ALUT_ATTRIBUTE_DEPRECATED*/ deprecated void /*ALUT_APIENTRY*/ alutLoadWAVFile (ALbyte* fileName, ALenum* format, void** data, ALsizei* size, ALsizei* frequency, ALboolean* loop);
/*ALUT_API*/ /*ALUT_ATTRIBUTE_DEPRECATED*/ deprecated void /*ALUT_APIENTRY*/ alutLoadWAVMemory (ALbyte* buffer, ALenum* format, void** data, ALsizei* size, ALsizei* frequency, ALboolean* loop);
/*ALUT_API*/ /*ALUT_ATTRIBUTE_DEPRECATED*/ deprecated void /*ALUT_APIENTRY*/ alutUnloadWAV (ALenum format, ALvoid* data, ALsizei size, ALsizei frequency);
}
// ////////////////////////////////////////////////////////////////////////// //


enum ALC_EXT_EFX_NAME = "ALC_EXT_EFX";

enum ALC_EFX_MAJOR_VERSION = 0x20001;
enum ALC_EFX_MINOR_VERSION = 0x20002;
enum ALC_MAX_AUXILIARY_SENDS = 0x20003;


/* Listener properties. */
enum AL_METERS_PER_UNIT = 0x20004;

/* Source properties. */
enum AL_DIRECT_FILTER = 0x20005;
enum AL_AUXILIARY_SEND_FILTER = 0x20006;
enum AL_AIR_ABSORPTION_FACTOR = 0x20007;
enum AL_ROOM_ROLLOFF_FACTOR = 0x20008;
enum AL_CONE_OUTER_GAINHF = 0x20009;
enum AL_DIRECT_FILTER_GAINHF_AUTO = 0x2000A;
enum AL_AUXILIARY_SEND_FILTER_GAIN_AUTO = 0x2000B;
enum AL_AUXILIARY_SEND_FILTER_GAINHF_AUTO = 0x2000C;


/* Effect properties. */

/* Reverb effect parameters */
enum AL_REVERB_DENSITY = 0x0001;
enum AL_REVERB_DIFFUSION = 0x0002;
enum AL_REVERB_GAIN = 0x0003;
enum AL_REVERB_GAINHF = 0x0004;
enum AL_REVERB_DECAY_TIME = 0x0005;
enum AL_REVERB_DECAY_HFRATIO = 0x0006;
enum AL_REVERB_REFLECTIONS_GAIN = 0x0007;
enum AL_REVERB_REFLECTIONS_DELAY = 0x0008;
enum AL_REVERB_LATE_REVERB_GAIN = 0x0009;
enum AL_REVERB_LATE_REVERB_DELAY = 0x000A;
enum AL_REVERB_AIR_ABSORPTION_GAINHF = 0x000B;
enum AL_REVERB_ROOM_ROLLOFF_FACTOR = 0x000C;
enum AL_REVERB_DECAY_HFLIMIT = 0x000D;

/* EAX Reverb effect parameters */
enum AL_EAXREVERB_DENSITY = 0x0001;
enum AL_EAXREVERB_DIFFUSION = 0x0002;
enum AL_EAXREVERB_GAIN = 0x0003;
enum AL_EAXREVERB_GAINHF = 0x0004;
enum AL_EAXREVERB_GAINLF = 0x0005;
enum AL_EAXREVERB_DECAY_TIME = 0x0006;
enum AL_EAXREVERB_DECAY_HFRATIO = 0x0007;
enum AL_EAXREVERB_DECAY_LFRATIO = 0x0008;
enum AL_EAXREVERB_REFLECTIONS_GAIN = 0x0009;
enum AL_EAXREVERB_REFLECTIONS_DELAY = 0x000A;
enum AL_EAXREVERB_REFLECTIONS_PAN = 0x000B;
enum AL_EAXREVERB_LATE_REVERB_GAIN = 0x000C;
enum AL_EAXREVERB_LATE_REVERB_DELAY = 0x000D;
enum AL_EAXREVERB_LATE_REVERB_PAN = 0x000E;
enum AL_EAXREVERB_ECHO_TIME = 0x000F;
enum AL_EAXREVERB_ECHO_DEPTH = 0x0010;
enum AL_EAXREVERB_MODULATION_TIME = 0x0011;
enum AL_EAXREVERB_MODULATION_DEPTH = 0x0012;
enum AL_EAXREVERB_AIR_ABSORPTION_GAINHF = 0x0013;
enum AL_EAXREVERB_HFREFERENCE = 0x0014;
enum AL_EAXREVERB_LFREFERENCE = 0x0015;
enum AL_EAXREVERB_ROOM_ROLLOFF_FACTOR = 0x0016;
enum AL_EAXREVERB_DECAY_HFLIMIT = 0x0017;

/* Chorus effect parameters */
enum AL_CHORUS_WAVEFORM = 0x0001;
enum AL_CHORUS_PHASE = 0x0002;
enum AL_CHORUS_RATE = 0x0003;
enum AL_CHORUS_DEPTH = 0x0004;
enum AL_CHORUS_FEEDBACK = 0x0005;
enum AL_CHORUS_DELAY = 0x0006;

/* Distortion effect parameters */
enum AL_DISTORTION_EDGE = 0x0001;
enum AL_DISTORTION_GAIN = 0x0002;
enum AL_DISTORTION_LOWPASS_CUTOFF = 0x0003;
enum AL_DISTORTION_EQCENTER = 0x0004;
enum AL_DISTORTION_EQBANDWIDTH = 0x0005;

/* Echo effect parameters */
enum AL_ECHO_DELAY = 0x0001;
enum AL_ECHO_LRDELAY = 0x0002;
enum AL_ECHO_DAMPING = 0x0003;
enum AL_ECHO_FEEDBACK = 0x0004;
enum AL_ECHO_SPREAD = 0x0005;

/* Flanger effect parameters */
enum AL_FLANGER_WAVEFORM = 0x0001;
enum AL_FLANGER_PHASE = 0x0002;
enum AL_FLANGER_RATE = 0x0003;
enum AL_FLANGER_DEPTH = 0x0004;
enum AL_FLANGER_FEEDBACK = 0x0005;
enum AL_FLANGER_DELAY = 0x0006;

/* Frequency shifter effect parameters */
enum AL_FREQUENCY_SHIFTER_FREQUENCY = 0x0001;
enum AL_FREQUENCY_SHIFTER_LEFT_DIRECTION = 0x0002;
enum AL_FREQUENCY_SHIFTER_RIGHT_DIRECTION = 0x0003;

/* Vocal morpher effect parameters */
enum AL_VOCAL_MORPHER_PHONEMEA = 0x0001;
enum AL_VOCAL_MORPHER_PHONEMEA_COARSE_TUNING = 0x0002;
enum AL_VOCAL_MORPHER_PHONEMEB = 0x0003;
enum AL_VOCAL_MORPHER_PHONEMEB_COARSE_TUNING = 0x0004;
enum AL_VOCAL_MORPHER_WAVEFORM = 0x0005;
enum AL_VOCAL_MORPHER_RATE = 0x0006;

/* Pitchshifter effect parameters */
enum AL_PITCH_SHIFTER_COARSE_TUNE = 0x0001;
enum AL_PITCH_SHIFTER_FINE_TUNE = 0x0002;

/* Ringmodulator effect parameters */
enum AL_RING_MODULATOR_FREQUENCY = 0x0001;
enum AL_RING_MODULATOR_HIGHPASS_CUTOFF = 0x0002;
enum AL_RING_MODULATOR_WAVEFORM = 0x0003;

/* Autowah effect parameters */
enum AL_AUTOWAH_ATTACK_TIME = 0x0001;
enum AL_AUTOWAH_RELEASE_TIME = 0x0002;
enum AL_AUTOWAH_RESONANCE = 0x0003;
enum AL_AUTOWAH_PEAK_GAIN = 0x0004;

/* Compressor effect parameters */
enum AL_COMPRESSOR_ONOFF = 0x0001;

/* Equalizer effect parameters */
enum AL_EQUALIZER_LOW_GAIN = 0x0001;
enum AL_EQUALIZER_LOW_CUTOFF = 0x0002;
enum AL_EQUALIZER_MID1_GAIN = 0x0003;
enum AL_EQUALIZER_MID1_CENTER = 0x0004;
enum AL_EQUALIZER_MID1_WIDTH = 0x0005;
enum AL_EQUALIZER_MID2_GAIN = 0x0006;
enum AL_EQUALIZER_MID2_CENTER = 0x0007;
enum AL_EQUALIZER_MID2_WIDTH = 0x0008;
enum AL_EQUALIZER_HIGH_GAIN = 0x0009;
enum AL_EQUALIZER_HIGH_CUTOFF = 0x000A;

/* Effect type */
enum AL_EFFECT_FIRST_PARAMETER = 0x0000;
enum AL_EFFECT_LAST_PARAMETER = 0x8000;
enum AL_EFFECT_TYPE = 0x8001;

/* Effect types, used with the AL_EFFECT_TYPE property */
enum AL_EFFECT_NULL = 0x0000;
enum AL_EFFECT_REVERB = 0x0001;
enum AL_EFFECT_CHORUS = 0x0002;
enum AL_EFFECT_DISTORTION = 0x0003;
enum AL_EFFECT_ECHO = 0x0004;
enum AL_EFFECT_FLANGER = 0x0005;
enum AL_EFFECT_FREQUENCY_SHIFTER = 0x0006;
enum AL_EFFECT_VOCAL_MORPHER = 0x0007;
enum AL_EFFECT_PITCH_SHIFTER = 0x0008;
enum AL_EFFECT_RING_MODULATOR = 0x0009;
enum AL_EFFECT_AUTOWAH = 0x000A;
enum AL_EFFECT_COMPRESSOR = 0x000B;
enum AL_EFFECT_EQUALIZER = 0x000C;
enum AL_EFFECT_EAXREVERB = 0x8000;

/* Auxiliary Effect Slot properties. */
enum AL_EFFECTSLOT_EFFECT = 0x0001;
enum AL_EFFECTSLOT_GAIN = 0x0002;
enum AL_EFFECTSLOT_AUXILIARY_SEND_AUTO = 0x0003;

/* NULL Auxiliary Slot ID to disable a source send. */
enum AL_EFFECTSLOT_NULL = 0x0000;


/* Filter properties. */

/* Lowpass filter parameters */
enum AL_LOWPASS_GAIN = 0x0001;
enum AL_LOWPASS_GAINHF = 0x0002;

/* Highpass filter parameters */
enum AL_HIGHPASS_GAIN = 0x0001;
enum AL_HIGHPASS_GAINLF = 0x0002;

/* Bandpass filter parameters */
enum AL_BANDPASS_GAIN = 0x0001;
enum AL_BANDPASS_GAINLF = 0x0002;
enum AL_BANDPASS_GAINHF = 0x0003;

/* Filter type */
enum AL_FILTER_FIRST_PARAMETER = 0x0000;
enum AL_FILTER_LAST_PARAMETER = 0x8000;
enum AL_FILTER_TYPE = 0x8001;

/* Filter types, used with the AL_FILTER_TYPE property */
enum AL_FILTER_NULL = 0x0000;
enum AL_FILTER_LOWPASS = 0x0001;
enum AL_FILTER_HIGHPASS = 0x0002;
enum AL_FILTER_BANDPASS = 0x0003;


/* Effect object function types. */
/+
typedef void (/*AL_APIENTRY*/ *LPALGENEFFECTS)(ALsizei, ALuint*);
typedef void (/*AL_APIENTRY*/ *LPALDELETEEFFECTS)(ALsizei, const(ALuint)* );
typedef ALboolean (/*AL_APIENTRY*/ *LPALISEFFECT)(ALuint);
typedef void (/*AL_APIENTRY*/ *LPALEFFECTI)(ALuint, ALenum, ALint);
typedef void (/*AL_APIENTRY*/ *LPALEFFECTIV)(ALuint, ALenum, const(ALint)* );
typedef void (/*AL_APIENTRY*/ *LPALEFFECTF)(ALuint, ALenum, ALfloat);
typedef void (/*AL_APIENTRY*/ *LPALEFFECTFV)(ALuint, ALenum, const(ALfloat)* );
typedef void (/*AL_APIENTRY*/ *LPALGETEFFECTI)(ALuint, ALenum, ALint*);
typedef void (/*AL_APIENTRY*/ *LPALGETEFFECTIV)(ALuint, ALenum, ALint*);
typedef void (/*AL_APIENTRY*/ *LPALGETEFFECTF)(ALuint, ALenum, ALfloat*);
typedef void (/*AL_APIENTRY*/ *LPALGETEFFECTFV)(ALuint, ALenum, ALfloat*);

/* Filter object function types. */
typedef void (/*AL_APIENTRY*/ *LPALGENFILTERS)(ALsizei, ALuint*);
typedef void (/*AL_APIENTRY*/ *LPALDELETEFILTERS)(ALsizei, const(ALuint)* );
typedef ALboolean (/*AL_APIENTRY*/ *LPALISFILTER)(ALuint);
typedef void (/*AL_APIENTRY*/ *LPALFILTERI)(ALuint, ALenum, ALint);
typedef void (/*AL_APIENTRY*/ *LPALFILTERIV)(ALuint, ALenum, const(ALint)* );
typedef void (/*AL_APIENTRY*/ *LPALFILTERF)(ALuint, ALenum, ALfloat);
typedef void (/*AL_APIENTRY*/ *LPALFILTERFV)(ALuint, ALenum, const(ALfloat)* );
typedef void (/*AL_APIENTRY*/ *LPALGETFILTERI)(ALuint, ALenum, ALint*);
typedef void (/*AL_APIENTRY*/ *LPALGETFILTERIV)(ALuint, ALenum, ALint*);
typedef void (/*AL_APIENTRY*/ *LPALGETFILTERF)(ALuint, ALenum, ALfloat*);
typedef void (/*AL_APIENTRY*/ *LPALGETFILTERFV)(ALuint, ALenum, ALfloat*);

/* Auxiliary Effect Slot object function types. */
typedef void (/*AL_APIENTRY*/ *LPALGENAUXILIARYEFFECTSLOTS)(ALsizei, ALuint*);
typedef void (/*AL_APIENTRY*/ *LPALDELETEAUXILIARYEFFECTSLOTS)(ALsizei, const(ALuint)* );
typedef ALboolean (/*AL_APIENTRY*/ *LPALISAUXILIARYEFFECTSLOT)(ALuint);
typedef void (/*AL_APIENTRY*/ *LPALAUXILIARYEFFECTSLOTI)(ALuint, ALenum, ALint);
typedef void (/*AL_APIENTRY*/ *LPALAUXILIARYEFFECTSLOTIV)(ALuint, ALenum, const(ALint)* );
typedef void (/*AL_APIENTRY*/ *LPALAUXILIARYEFFECTSLOTF)(ALuint, ALenum, ALfloat);
typedef void (/*AL_APIENTRY*/ *LPALAUXILIARYEFFECTSLOTFV)(ALuint, ALenum, const(ALfloat)* );
typedef void (/*AL_APIENTRY*/ *LPALGETAUXILIARYEFFECTSLOTI)(ALuint, ALenum, ALint*);
typedef void (/*AL_APIENTRY*/ *LPALGETAUXILIARYEFFECTSLOTIV)(ALuint, ALenum, ALint*);
typedef void (/*AL_APIENTRY*/ *LPALGETAUXILIARYEFFECTSLOTF)(ALuint, ALenum, ALfloat*);
typedef void (/*AL_APIENTRY*/ *LPALGETAUXILIARYEFFECTSLOTFV)(ALuint, ALenum, ALfloat*);
+/

/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGenEffects(ALsizei n, ALuint* effects);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alDeleteEffects(ALsizei n, const(ALuint)* effects);
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsEffect(ALuint effect);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alEffecti(ALuint effect, ALenum param, ALint iValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alEffectiv(ALuint effect, ALenum param, const(ALint)* piValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alEffectf(ALuint effect, ALenum param, ALfloat flValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alEffectfv(ALuint effect, ALenum param, const(ALfloat)* pflValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetEffecti(ALuint effect, ALenum param, ALint* piValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetEffectiv(ALuint effect, ALenum param, ALint* piValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetEffectf(ALuint effect, ALenum param, ALfloat* pflValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetEffectfv(ALuint effect, ALenum param, ALfloat* pflValues);

/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGenFilters(ALsizei n, ALuint* filters);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alDeleteFilters(ALsizei n, const(ALuint)* filters);
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsFilter(ALuint filter);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alFilteri(ALuint filter, ALenum param, ALint iValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alFilteriv(ALuint filter, ALenum param, const(ALint)* piValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alFilterf(ALuint filter, ALenum param, ALfloat flValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alFilterfv(ALuint filter, ALenum param, const(ALfloat)* pflValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetFilteri(ALuint filter, ALenum param, ALint* piValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetFilteriv(ALuint filter, ALenum param, ALint* piValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetFilterf(ALuint filter, ALenum param, ALfloat* pflValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetFilterfv(ALuint filter, ALenum param, ALfloat* pflValues);

/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGenAuxiliaryEffectSlots(ALsizei n, ALuint* effectslots);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alDeleteAuxiliaryEffectSlots(ALsizei n, const(ALuint)* effectslots);
/*AL_API*/ ALboolean /*AL_APIENTRY*/ alIsAuxiliaryEffectSlot(ALuint effectslot);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alAuxiliaryEffectSloti(ALuint effectslot, ALenum param, ALint iValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alAuxiliaryEffectSlotiv(ALuint effectslot, ALenum param, const(ALint)* piValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alAuxiliaryEffectSlotf(ALuint effectslot, ALenum param, ALfloat flValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alAuxiliaryEffectSlotfv(ALuint effectslot, ALenum param, const(ALfloat)* pflValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetAuxiliaryEffectSloti(ALuint effectslot, ALenum param, ALint* piValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetAuxiliaryEffectSlotiv(ALuint effectslot, ALenum param, ALint* piValues);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetAuxiliaryEffectSlotf(ALuint effectslot, ALenum param, ALfloat* pflValue);
/*AL_API*/ ALvoid /*AL_APIENTRY*/ alGetAuxiliaryEffectSlotfv(ALuint effectslot, ALenum param, ALfloat* pflValues);

/* Filter ranges and defaults. */

/* Lowpass filter */
enum AL_LOWPASS_MIN_GAIN = (0.0f);
enum AL_LOWPASS_MAX_GAIN = (1.0f);
enum AL_LOWPASS_DEFAULT_GAIN = (1.0f);

enum AL_LOWPASS_MIN_GAINHF = (0.0f);
enum AL_LOWPASS_MAX_GAINHF = (1.0f);
enum AL_LOWPASS_DEFAULT_GAINHF = (1.0f);

/* Highpass filter */
enum AL_HIGHPASS_MIN_GAIN = (0.0f);
enum AL_HIGHPASS_MAX_GAIN = (1.0f);
enum AL_HIGHPASS_DEFAULT_GAIN = (1.0f);

enum AL_HIGHPASS_MIN_GAINLF = (0.0f);
enum AL_HIGHPASS_MAX_GAINLF = (1.0f);
enum AL_HIGHPASS_DEFAULT_GAINLF = (1.0f);

/* Bandpass filter */
enum AL_BANDPASS_MIN_GAIN = (0.0f);
enum AL_BANDPASS_MAX_GAIN = (1.0f);
enum AL_BANDPASS_DEFAULT_GAIN = (1.0f);

enum AL_BANDPASS_MIN_GAINHF = (0.0f);
enum AL_BANDPASS_MAX_GAINHF = (1.0f);
enum AL_BANDPASS_DEFAULT_GAINHF = (1.0f);

enum AL_BANDPASS_MIN_GAINLF = (0.0f);
enum AL_BANDPASS_MAX_GAINLF = (1.0f);
enum AL_BANDPASS_DEFAULT_GAINLF = (1.0f);


/* Effect parameter ranges and defaults. */

/* Standard reverb effect */
enum AL_REVERB_MIN_DENSITY = (0.0f);
enum AL_REVERB_MAX_DENSITY = (1.0f);
enum AL_REVERB_DEFAULT_DENSITY = (1.0f);

enum AL_REVERB_MIN_DIFFUSION = (0.0f);
enum AL_REVERB_MAX_DIFFUSION = (1.0f);
enum AL_REVERB_DEFAULT_DIFFUSION = (1.0f);

enum AL_REVERB_MIN_GAIN = (0.0f);
enum AL_REVERB_MAX_GAIN = (1.0f);
enum AL_REVERB_DEFAULT_GAIN = (0.32f);

enum AL_REVERB_MIN_GAINHF = (0.0f);
enum AL_REVERB_MAX_GAINHF = (1.0f);
enum AL_REVERB_DEFAULT_GAINHF = (0.89f);

enum AL_REVERB_MIN_DECAY_TIME = (0.1f);
enum AL_REVERB_MAX_DECAY_TIME = (20.0f);
enum AL_REVERB_DEFAULT_DECAY_TIME = (1.49f);

enum AL_REVERB_MIN_DECAY_HFRATIO = (0.1f);
enum AL_REVERB_MAX_DECAY_HFRATIO = (2.0f);
enum AL_REVERB_DEFAULT_DECAY_HFRATIO = (0.83f);

enum AL_REVERB_MIN_REFLECTIONS_GAIN = (0.0f);
enum AL_REVERB_MAX_REFLECTIONS_GAIN = (3.16f);
enum AL_REVERB_DEFAULT_REFLECTIONS_GAIN = (0.05f);

enum AL_REVERB_MIN_REFLECTIONS_DELAY = (0.0f);
enum AL_REVERB_MAX_REFLECTIONS_DELAY = (0.3f);
enum AL_REVERB_DEFAULT_REFLECTIONS_DELAY = (0.007f);

enum AL_REVERB_MIN_LATE_REVERB_GAIN = (0.0f);
enum AL_REVERB_MAX_LATE_REVERB_GAIN = (10.0f);
enum AL_REVERB_DEFAULT_LATE_REVERB_GAIN = (1.26f);

enum AL_REVERB_MIN_LATE_REVERB_DELAY = (0.0f);
enum AL_REVERB_MAX_LATE_REVERB_DELAY = (0.1f);
enum AL_REVERB_DEFAULT_LATE_REVERB_DELAY = (0.011f);

enum AL_REVERB_MIN_AIR_ABSORPTION_GAINHF = (0.892f);
enum AL_REVERB_MAX_AIR_ABSORPTION_GAINHF = (1.0f);
enum AL_REVERB_DEFAULT_AIR_ABSORPTION_GAINHF = (0.994f);

enum AL_REVERB_MIN_ROOM_ROLLOFF_FACTOR = (0.0f);
enum AL_REVERB_MAX_ROOM_ROLLOFF_FACTOR = (10.0f);
enum AL_REVERB_DEFAULT_ROOM_ROLLOFF_FACTOR = (0.0f);

enum AL_REVERB_MIN_DECAY_HFLIMIT = AL_FALSE;
enum AL_REVERB_MAX_DECAY_HFLIMIT = AL_TRUE;
enum AL_REVERB_DEFAULT_DECAY_HFLIMIT = AL_TRUE;

/* EAX reverb effect */
enum AL_EAXREVERB_MIN_DENSITY = (0.0f);
enum AL_EAXREVERB_MAX_DENSITY = (1.0f);
enum AL_EAXREVERB_DEFAULT_DENSITY = (1.0f);

enum AL_EAXREVERB_MIN_DIFFUSION = (0.0f);
enum AL_EAXREVERB_MAX_DIFFUSION = (1.0f);
enum AL_EAXREVERB_DEFAULT_DIFFUSION = (1.0f);

enum AL_EAXREVERB_MIN_GAIN = (0.0f);
enum AL_EAXREVERB_MAX_GAIN = (1.0f);
enum AL_EAXREVERB_DEFAULT_GAIN = (0.32f);

enum AL_EAXREVERB_MIN_GAINHF = (0.0f);
enum AL_EAXREVERB_MAX_GAINHF = (1.0f);
enum AL_EAXREVERB_DEFAULT_GAINHF = (0.89f);

enum AL_EAXREVERB_MIN_GAINLF = (0.0f);
enum AL_EAXREVERB_MAX_GAINLF = (1.0f);
enum AL_EAXREVERB_DEFAULT_GAINLF = (1.0f);

enum AL_EAXREVERB_MIN_DECAY_TIME = (0.1f);
enum AL_EAXREVERB_MAX_DECAY_TIME = (20.0f);
enum AL_EAXREVERB_DEFAULT_DECAY_TIME = (1.49f);

enum AL_EAXREVERB_MIN_DECAY_HFRATIO = (0.1f);
enum AL_EAXREVERB_MAX_DECAY_HFRATIO = (2.0f);
enum AL_EAXREVERB_DEFAULT_DECAY_HFRATIO = (0.83f);

enum AL_EAXREVERB_MIN_DECAY_LFRATIO = (0.1f);
enum AL_EAXREVERB_MAX_DECAY_LFRATIO = (2.0f);
enum AL_EAXREVERB_DEFAULT_DECAY_LFRATIO = (1.0f);

enum AL_EAXREVERB_MIN_REFLECTIONS_GAIN = (0.0f);
enum AL_EAXREVERB_MAX_REFLECTIONS_GAIN = (3.16f);
enum AL_EAXREVERB_DEFAULT_REFLECTIONS_GAIN = (0.05f);

enum AL_EAXREVERB_MIN_REFLECTIONS_DELAY = (0.0f);
enum AL_EAXREVERB_MAX_REFLECTIONS_DELAY = (0.3f);
enum AL_EAXREVERB_DEFAULT_REFLECTIONS_DELAY = (0.007f);

enum AL_EAXREVERB_DEFAULT_REFLECTIONS_PAN_XYZ = (0.0f);

enum AL_EAXREVERB_MIN_LATE_REVERB_GAIN = (0.0f);
enum AL_EAXREVERB_MAX_LATE_REVERB_GAIN = (10.0f);
enum AL_EAXREVERB_DEFAULT_LATE_REVERB_GAIN = (1.26f);

enum AL_EAXREVERB_MIN_LATE_REVERB_DELAY = (0.0f);
enum AL_EAXREVERB_MAX_LATE_REVERB_DELAY = (0.1f);
enum AL_EAXREVERB_DEFAULT_LATE_REVERB_DELAY = (0.011f);

enum AL_EAXREVERB_DEFAULT_LATE_REVERB_PAN_XYZ = (0.0f);

enum AL_EAXREVERB_MIN_ECHO_TIME = (0.075f);
enum AL_EAXREVERB_MAX_ECHO_TIME = (0.25f);
enum AL_EAXREVERB_DEFAULT_ECHO_TIME = (0.25f);

enum AL_EAXREVERB_MIN_ECHO_DEPTH = (0.0f);
enum AL_EAXREVERB_MAX_ECHO_DEPTH = (1.0f);
enum AL_EAXREVERB_DEFAULT_ECHO_DEPTH = (0.0f);

enum AL_EAXREVERB_MIN_MODULATION_TIME = (0.04f);
enum AL_EAXREVERB_MAX_MODULATION_TIME = (4.0f);
enum AL_EAXREVERB_DEFAULT_MODULATION_TIME = (0.25f);

enum AL_EAXREVERB_MIN_MODULATION_DEPTH = (0.0f);
enum AL_EAXREVERB_MAX_MODULATION_DEPTH = (1.0f);
enum AL_EAXREVERB_DEFAULT_MODULATION_DEPTH = (0.0f);

enum AL_EAXREVERB_MIN_AIR_ABSORPTION_GAINHF = (0.892f);
enum AL_EAXREVERB_MAX_AIR_ABSORPTION_GAINHF = (1.0f);
enum AL_EAXREVERB_DEFAULT_AIR_ABSORPTION_GAINHF = (0.994f);

enum AL_EAXREVERB_MIN_HFREFERENCE = (1000.0f);
enum AL_EAXREVERB_MAX_HFREFERENCE = (20000.0f);
enum AL_EAXREVERB_DEFAULT_HFREFERENCE = (5000.0f);

enum AL_EAXREVERB_MIN_LFREFERENCE = (20.0f);
enum AL_EAXREVERB_MAX_LFREFERENCE = (1000.0f);
enum AL_EAXREVERB_DEFAULT_LFREFERENCE = (250.0f);

enum AL_EAXREVERB_MIN_ROOM_ROLLOFF_FACTOR = (0.0f);
enum AL_EAXREVERB_MAX_ROOM_ROLLOFF_FACTOR = (10.0f);
enum AL_EAXREVERB_DEFAULT_ROOM_ROLLOFF_FACTOR = (0.0f);

enum AL_EAXREVERB_MIN_DECAY_HFLIMIT = AL_FALSE;
enum AL_EAXREVERB_MAX_DECAY_HFLIMIT = AL_TRUE;
enum AL_EAXREVERB_DEFAULT_DECAY_HFLIMIT = AL_TRUE;

/* Chorus effect */
enum AL_CHORUS_WAVEFORM_SINUSOID = (0);
enum AL_CHORUS_WAVEFORM_TRIANGLE = (1);

enum AL_CHORUS_MIN_WAVEFORM = (0);
enum AL_CHORUS_MAX_WAVEFORM = (1);
enum AL_CHORUS_DEFAULT_WAVEFORM = (1);

enum AL_CHORUS_MIN_PHASE = (-180);
enum AL_CHORUS_MAX_PHASE = (180);
enum AL_CHORUS_DEFAULT_PHASE = (90);

enum AL_CHORUS_MIN_RATE = (0.0f);
enum AL_CHORUS_MAX_RATE = (10.0f);
enum AL_CHORUS_DEFAULT_RATE = (1.1f);

enum AL_CHORUS_MIN_DEPTH = (0.0f);
enum AL_CHORUS_MAX_DEPTH = (1.0f);
enum AL_CHORUS_DEFAULT_DEPTH = (0.1f);

enum AL_CHORUS_MIN_FEEDBACK = (-1.0f);
enum AL_CHORUS_MAX_FEEDBACK = (1.0f);
enum AL_CHORUS_DEFAULT_FEEDBACK = (0.25f);

enum AL_CHORUS_MIN_DELAY = (0.0f);
enum AL_CHORUS_MAX_DELAY = (0.016f);
enum AL_CHORUS_DEFAULT_DELAY = (0.016f);

/* Distortion effect */
enum AL_DISTORTION_MIN_EDGE = (0.0f);
enum AL_DISTORTION_MAX_EDGE = (1.0f);
enum AL_DISTORTION_DEFAULT_EDGE = (0.2f);

enum AL_DISTORTION_MIN_GAIN = (0.01f);
enum AL_DISTORTION_MAX_GAIN = (1.0f);
enum AL_DISTORTION_DEFAULT_GAIN = (0.05f);

enum AL_DISTORTION_MIN_LOWPASS_CUTOFF = (80.0f);
enum AL_DISTORTION_MAX_LOWPASS_CUTOFF = (24000.0f);
enum AL_DISTORTION_DEFAULT_LOWPASS_CUTOFF = (8000.0f);

enum AL_DISTORTION_MIN_EQCENTER = (80.0f);
enum AL_DISTORTION_MAX_EQCENTER = (24000.0f);
enum AL_DISTORTION_DEFAULT_EQCENTER = (3600.0f);

enum AL_DISTORTION_MIN_EQBANDWIDTH = (80.0f);
enum AL_DISTORTION_MAX_EQBANDWIDTH = (24000.0f);
enum AL_DISTORTION_DEFAULT_EQBANDWIDTH = (3600.0f);

/* Echo effect */
enum AL_ECHO_MIN_DELAY = (0.0f);
enum AL_ECHO_MAX_DELAY = (0.207f);
enum AL_ECHO_DEFAULT_DELAY = (0.1f);

enum AL_ECHO_MIN_LRDELAY = (0.0f);
enum AL_ECHO_MAX_LRDELAY = (0.404f);
enum AL_ECHO_DEFAULT_LRDELAY = (0.1f);

enum AL_ECHO_MIN_DAMPING = (0.0f);
enum AL_ECHO_MAX_DAMPING = (0.99f);
enum AL_ECHO_DEFAULT_DAMPING = (0.5f);

enum AL_ECHO_MIN_FEEDBACK = (0.0f);
enum AL_ECHO_MAX_FEEDBACK = (1.0f);
enum AL_ECHO_DEFAULT_FEEDBACK = (0.5f);

enum AL_ECHO_MIN_SPREAD = (-1.0f);
enum AL_ECHO_MAX_SPREAD = (1.0f);
enum AL_ECHO_DEFAULT_SPREAD = (-1.0f);

/* Flanger effect */
enum AL_FLANGER_WAVEFORM_SINUSOID = (0);
enum AL_FLANGER_WAVEFORM_TRIANGLE = (1);

enum AL_FLANGER_MIN_WAVEFORM = (0);
enum AL_FLANGER_MAX_WAVEFORM = (1);
enum AL_FLANGER_DEFAULT_WAVEFORM = (1);

enum AL_FLANGER_MIN_PHASE = (-180);
enum AL_FLANGER_MAX_PHASE = (180);
enum AL_FLANGER_DEFAULT_PHASE = (0);

enum AL_FLANGER_MIN_RATE = (0.0f);
enum AL_FLANGER_MAX_RATE = (10.0f);
enum AL_FLANGER_DEFAULT_RATE = (0.27f);

enum AL_FLANGER_MIN_DEPTH = (0.0f);
enum AL_FLANGER_MAX_DEPTH = (1.0f);
enum AL_FLANGER_DEFAULT_DEPTH = (1.0f);

enum AL_FLANGER_MIN_FEEDBACK = (-1.0f);
enum AL_FLANGER_MAX_FEEDBACK = (1.0f);
enum AL_FLANGER_DEFAULT_FEEDBACK = (-0.5f);

enum AL_FLANGER_MIN_DELAY = (0.0f);
enum AL_FLANGER_MAX_DELAY = (0.004f);
enum AL_FLANGER_DEFAULT_DELAY = (0.002f);

/* Frequency shifter effect */
enum AL_FREQUENCY_SHIFTER_MIN_FREQUENCY = (0.0f);
enum AL_FREQUENCY_SHIFTER_MAX_FREQUENCY = (24000.0f);
enum AL_FREQUENCY_SHIFTER_DEFAULT_FREQUENCY = (0.0f);

enum AL_FREQUENCY_SHIFTER_MIN_LEFT_DIRECTION = (0);
enum AL_FREQUENCY_SHIFTER_MAX_LEFT_DIRECTION = (2);
enum AL_FREQUENCY_SHIFTER_DEFAULT_LEFT_DIRECTION = (0);

enum AL_FREQUENCY_SHIFTER_DIRECTION_DOWN = (0);
enum AL_FREQUENCY_SHIFTER_DIRECTION_UP = (1);
enum AL_FREQUENCY_SHIFTER_DIRECTION_OFF = (2);

enum AL_FREQUENCY_SHIFTER_MIN_RIGHT_DIRECTION = (0);
enum AL_FREQUENCY_SHIFTER_MAX_RIGHT_DIRECTION = (2);
enum AL_FREQUENCY_SHIFTER_DEFAULT_RIGHT_DIRECTION = (0);

/* Vocal morpher effect */
enum AL_VOCAL_MORPHER_MIN_PHONEMEA = (0);
enum AL_VOCAL_MORPHER_MAX_PHONEMEA = (29);
enum AL_VOCAL_MORPHER_DEFAULT_PHONEMEA = (0);

enum AL_VOCAL_MORPHER_MIN_PHONEMEA_COARSE_TUNING = (-24);
enum AL_VOCAL_MORPHER_MAX_PHONEMEA_COARSE_TUNING = (24);
enum AL_VOCAL_MORPHER_DEFAULT_PHONEMEA_COARSE_TUNING = (0);

enum AL_VOCAL_MORPHER_MIN_PHONEMEB = (0);
enum AL_VOCAL_MORPHER_MAX_PHONEMEB = (29);
enum AL_VOCAL_MORPHER_DEFAULT_PHONEMEB = (10);

enum AL_VOCAL_MORPHER_MIN_PHONEMEB_COARSE_TUNING = (-24);
enum AL_VOCAL_MORPHER_MAX_PHONEMEB_COARSE_TUNING = (24);
enum AL_VOCAL_MORPHER_DEFAULT_PHONEMEB_COARSE_TUNING = (0);

enum AL_VOCAL_MORPHER_PHONEME_A = (0);
enum AL_VOCAL_MORPHER_PHONEME_E = (1);
enum AL_VOCAL_MORPHER_PHONEME_I = (2);
enum AL_VOCAL_MORPHER_PHONEME_O = (3);
enum AL_VOCAL_MORPHER_PHONEME_U = (4);
enum AL_VOCAL_MORPHER_PHONEME_AA = (5);
enum AL_VOCAL_MORPHER_PHONEME_AE = (6);
enum AL_VOCAL_MORPHER_PHONEME_AH = (7);
enum AL_VOCAL_MORPHER_PHONEME_AO = (8);
enum AL_VOCAL_MORPHER_PHONEME_EH = (9);
enum AL_VOCAL_MORPHER_PHONEME_ER = (10);
enum AL_VOCAL_MORPHER_PHONEME_IH = (11);
enum AL_VOCAL_MORPHER_PHONEME_IY = (12);
enum AL_VOCAL_MORPHER_PHONEME_UH = (13);
enum AL_VOCAL_MORPHER_PHONEME_UW = (14);
enum AL_VOCAL_MORPHER_PHONEME_B = (15);
enum AL_VOCAL_MORPHER_PHONEME_D = (16);
enum AL_VOCAL_MORPHER_PHONEME_F = (17);
enum AL_VOCAL_MORPHER_PHONEME_G = (18);
enum AL_VOCAL_MORPHER_PHONEME_J = (19);
enum AL_VOCAL_MORPHER_PHONEME_K = (20);
enum AL_VOCAL_MORPHER_PHONEME_L = (21);
enum AL_VOCAL_MORPHER_PHONEME_M = (22);
enum AL_VOCAL_MORPHER_PHONEME_N = (23);
enum AL_VOCAL_MORPHER_PHONEME_P = (24);
enum AL_VOCAL_MORPHER_PHONEME_R = (25);
enum AL_VOCAL_MORPHER_PHONEME_S = (26);
enum AL_VOCAL_MORPHER_PHONEME_T = (27);
enum AL_VOCAL_MORPHER_PHONEME_V = (28);
enum AL_VOCAL_MORPHER_PHONEME_Z = (29);

enum AL_VOCAL_MORPHER_WAVEFORM_SINUSOID = (0);
enum AL_VOCAL_MORPHER_WAVEFORM_TRIANGLE = (1);
enum AL_VOCAL_MORPHER_WAVEFORM_SAWTOOTH = (2);

enum AL_VOCAL_MORPHER_MIN_WAVEFORM = (0);
enum AL_VOCAL_MORPHER_MAX_WAVEFORM = (2);
enum AL_VOCAL_MORPHER_DEFAULT_WAVEFORM = (0);

enum AL_VOCAL_MORPHER_MIN_RATE = (0.0f);
enum AL_VOCAL_MORPHER_MAX_RATE = (10.0f);
enum AL_VOCAL_MORPHER_DEFAULT_RATE = (1.41f);

/* Pitch shifter effect */
enum AL_PITCH_SHIFTER_MIN_COARSE_TUNE = (-12);
enum AL_PITCH_SHIFTER_MAX_COARSE_TUNE = (12);
enum AL_PITCH_SHIFTER_DEFAULT_COARSE_TUNE = (12);

enum AL_PITCH_SHIFTER_MIN_FINE_TUNE = (-50);
enum AL_PITCH_SHIFTER_MAX_FINE_TUNE = (50);
enum AL_PITCH_SHIFTER_DEFAULT_FINE_TUNE = (0);

/* Ring modulator effect */
enum AL_RING_MODULATOR_MIN_FREQUENCY = (0.0f);
enum AL_RING_MODULATOR_MAX_FREQUENCY = (8000.0f);
enum AL_RING_MODULATOR_DEFAULT_FREQUENCY = (440.0f);

enum AL_RING_MODULATOR_MIN_HIGHPASS_CUTOFF = (0.0f);
enum AL_RING_MODULATOR_MAX_HIGHPASS_CUTOFF = (24000.0f);
enum AL_RING_MODULATOR_DEFAULT_HIGHPASS_CUTOFF = (800.0f);

enum AL_RING_MODULATOR_SINUSOID = (0);
enum AL_RING_MODULATOR_SAWTOOTH = (1);
enum AL_RING_MODULATOR_SQUARE = (2);

enum AL_RING_MODULATOR_MIN_WAVEFORM = (0);
enum AL_RING_MODULATOR_MAX_WAVEFORM = (2);
enum AL_RING_MODULATOR_DEFAULT_WAVEFORM = (0);

/* Autowah effect */
enum AL_AUTOWAH_MIN_ATTACK_TIME = (0.0001f);
enum AL_AUTOWAH_MAX_ATTACK_TIME = (1.0f);
enum AL_AUTOWAH_DEFAULT_ATTACK_TIME = (0.06f);

enum AL_AUTOWAH_MIN_RELEASE_TIME = (0.0001f);
enum AL_AUTOWAH_MAX_RELEASE_TIME = (1.0f);
enum AL_AUTOWAH_DEFAULT_RELEASE_TIME = (0.06f);

enum AL_AUTOWAH_MIN_RESONANCE = (2.0f);
enum AL_AUTOWAH_MAX_RESONANCE = (1000.0f);
enum AL_AUTOWAH_DEFAULT_RESONANCE = (1000.0f);

enum AL_AUTOWAH_MIN_PEAK_GAIN = (0.00003f);
enum AL_AUTOWAH_MAX_PEAK_GAIN = (31621.0f);
enum AL_AUTOWAH_DEFAULT_PEAK_GAIN = (11.22f);

/* Compressor effect */
enum AL_COMPRESSOR_MIN_ONOFF = (0);
enum AL_COMPRESSOR_MAX_ONOFF = (1);
enum AL_COMPRESSOR_DEFAULT_ONOFF = (1);

/* Equalizer effect */
enum AL_EQUALIZER_MIN_LOW_GAIN = (0.126f);
enum AL_EQUALIZER_MAX_LOW_GAIN = (7.943f);
enum AL_EQUALIZER_DEFAULT_LOW_GAIN = (1.0f);

enum AL_EQUALIZER_MIN_LOW_CUTOFF = (50.0f);
enum AL_EQUALIZER_MAX_LOW_CUTOFF = (800.0f);
enum AL_EQUALIZER_DEFAULT_LOW_CUTOFF = (200.0f);

enum AL_EQUALIZER_MIN_MID1_GAIN = (0.126f);
enum AL_EQUALIZER_MAX_MID1_GAIN = (7.943f);
enum AL_EQUALIZER_DEFAULT_MID1_GAIN = (1.0f);

enum AL_EQUALIZER_MIN_MID1_CENTER = (200.0f);
enum AL_EQUALIZER_MAX_MID1_CENTER = (3000.0f);
enum AL_EQUALIZER_DEFAULT_MID1_CENTER = (500.0f);

enum AL_EQUALIZER_MIN_MID1_WIDTH = (0.01f);
enum AL_EQUALIZER_MAX_MID1_WIDTH = (1.0f);
enum AL_EQUALIZER_DEFAULT_MID1_WIDTH = (1.0f);

enum AL_EQUALIZER_MIN_MID2_GAIN = (0.126f);
enum AL_EQUALIZER_MAX_MID2_GAIN = (7.943f);
enum AL_EQUALIZER_DEFAULT_MID2_GAIN = (1.0f);

enum AL_EQUALIZER_MIN_MID2_CENTER = (1000.0f);
enum AL_EQUALIZER_MAX_MID2_CENTER = (8000.0f);
enum AL_EQUALIZER_DEFAULT_MID2_CENTER = (3000.0f);

enum AL_EQUALIZER_MIN_MID2_WIDTH = (0.01f);
enum AL_EQUALIZER_MAX_MID2_WIDTH = (1.0f);
enum AL_EQUALIZER_DEFAULT_MID2_WIDTH = (1.0f);

enum AL_EQUALIZER_MIN_HIGH_GAIN = (0.126f);
enum AL_EQUALIZER_MAX_HIGH_GAIN = (7.943f);
enum AL_EQUALIZER_DEFAULT_HIGH_GAIN = (1.0f);

enum AL_EQUALIZER_MIN_HIGH_CUTOFF = (4000.0f);
enum AL_EQUALIZER_MAX_HIGH_CUTOFF = (16000.0f);
enum AL_EQUALIZER_DEFAULT_HIGH_CUTOFF = (6000.0f);


/* Source parameter value ranges and defaults. */
enum AL_MIN_AIR_ABSORPTION_FACTOR = (0.0f);
enum AL_MAX_AIR_ABSORPTION_FACTOR = (10.0f);
enum AL_DEFAULT_AIR_ABSORPTION_FACTOR = (0.0f);

enum AL_MIN_ROOM_ROLLOFF_FACTOR = (0.0f);
enum AL_MAX_ROOM_ROLLOFF_FACTOR = (10.0f);
enum AL_DEFAULT_ROOM_ROLLOFF_FACTOR = (0.0f);

enum AL_MIN_CONE_OUTER_GAINHF = (0.0f);
enum AL_MAX_CONE_OUTER_GAINHF = (1.0f);
enum AL_DEFAULT_CONE_OUTER_GAINHF = (1.0f);

enum AL_MIN_DIRECT_FILTER_GAINHF_AUTO = AL_FALSE;
enum AL_MAX_DIRECT_FILTER_GAINHF_AUTO = AL_TRUE;
enum AL_DEFAULT_DIRECT_FILTER_GAINHF_AUTO = AL_TRUE;

enum AL_MIN_AUXILIARY_SEND_FILTER_GAIN_AUTO = AL_FALSE;
enum AL_MAX_AUXILIARY_SEND_FILTER_GAIN_AUTO = AL_TRUE;
enum AL_DEFAULT_AUXILIARY_SEND_FILTER_GAIN_AUTO = AL_TRUE;

enum AL_MIN_AUXILIARY_SEND_FILTER_GAINHF_AUTO = AL_FALSE;
enum AL_MAX_AUXILIARY_SEND_FILTER_GAINHF_AUTO = AL_TRUE;
enum AL_DEFAULT_AUXILIARY_SEND_FILTER_GAINHF_AUTO = AL_TRUE;


/* Listener parameter value ranges and defaults. */
enum AL_MIN_METERS_PER_UNIT = /*FLT_MIN*/float.min_normal; //FIXME:k8:???
enum AL_MAX_METERS_PER_UNIT = /*FLT_MAX*/float.max;
enum AL_DEFAULT_METERS_PER_UNIT = (1.0f);
