// Copyright (C) 2010-2016  Lukas Lalinsky
// Distributed under the MIT license, see the LICENSE file for details.
/**
 * Chromaprint:
 *
 * Introduction:
 *
 * Chromaprint is a library for generating audio fingerprints, mainly to be used with the <a href="https://acoustid.org">AcoustID</a> service.
 *
 * It needs raw audio stream (16-bit signed int) on input. The audio can have any sampling rate and any number of channels. Typically,
 * you would use some native library for decoding compressed audio files and feed the result into Chromaprint.
 *
 * Audio fingerprints returned from the library can be represented either as
 * base64-encoded strings or 32-bit integer arrays. The base64-encoded strings
 * are usually what's used externally when you need to send the fingerprint
 * to a service. You can't directly compare the fingerprints in such form.
 * The 32-bit integer arrays are also called "raw fingerprints" and they
 * represent the internal structure of the fingerprints. If you want to
 * compare two fingerprints yourself, you probably want them in this form.
 *
 * Generating fingerprints:
 *
 * Here is a simple example code that generates a fingerprint from audio samples in memory:
 *
 * Example
 * -------
 *     ChromaprintContext *ctx;
 *     char *fp;
 *
 *     const int sample_rate = 44100;
 *     const int num_channels = 2;
 *
 *     ctx = chromaprint_new(CHROMAPRINT_ALGORITHM_DEFAULT);
 *
 *     chromaprint_start(ctx, sample_rate, num_channels);
 *     while (has_more_data) {
 *         chromaprint_feed(ctx, data, size);
 *     }
 *     chromaprint_finish(ctx);
 *
 *     chromaprint_get_fingerprint(ctx, &fp);
 *     printf("%s\n", fp);
 *     chromaprint_dealloc(fp);
 *
 *     chromaprint_free(ctx);
 * -------
 *
 * Note that there is no error handling in the code above. Almost any of the called functions can fail.
 * You should check the return values in an actual code.
 */
module iv.chromaprint;
pragma(lib, "chromaprint");

extern(C) nothrow @nogc:

struct ChromaprintContextPrivate {}
alias ChromaprintContext = ChromaprintContextPrivate;

struct ChromaprintMatcherContextPrivate {}
alias ChromaprintMatcherContext = ChromaprintMatcherContextPrivate;

enum CHROMAPRINT_VERSION_MAJOR = 1;
enum CHROMAPRINT_VERSION_MINOR = 4;
enum CHROMAPRINT_VERSION_PATCH = 0;

///
alias  ChromaprintAlgorithm = int;
enum /*ChromaprintAlgorithm*/:int {
  CHROMAPRINT_ALGORITHM_TEST1 = 0, ///
  CHROMAPRINT_ALGORITHM_TEST2, ///
  CHROMAPRINT_ALGORITHM_TEST3, ///
  CHROMAPRINT_ALGORITHM_TEST4, ///
  CHROMAPRINT_ALGORITHM_TEST5, ///
  CHROMAPRINT_ALGORITHM_DEFAULT = CHROMAPRINT_ALGORITHM_TEST2, ///
}

/**
 * Return the version number of Chromaprint.
 */
/*CHROMAPRINT_API*/ const(char)* chromaprint_get_version ();

/**
 * Allocate and initialize the Chromaprint context.
 *
 * Note that when Chromaprint is compiled with FFTW, this function is
 * not reentrant and you need to call it only from one thread at a time.
 * This is not a problem when using FFmpeg or vDSP.
 *
 * Params:
 *   algorithm = the fingerprint algorithm version you want to use, or
 *    CHROMAPRINT_ALGORITHM_DEFAULT for the default algorithm
 *
 * Returns: Chromaprint context pointer
 */
/*CHROMAPRINT_API*/ ChromaprintContext* chromaprint_new (int algorithm=CHROMAPRINT_ALGORITHM_DEFAULT);

/**
 * Deallocate the Chromaprint context.
 *
 * Note that when Chromaprint is compiled with FFTW, this function is
 * not reentrant and you need to call it only from one thread at a time.
 * This is not a problem when using FFmpeg or vDSP.
 *
 * params: ctx = Chromaprint context pointer
 */
/*CHROMAPRINT_API*/ void chromaprint_free (ChromaprintContext* ctx);

/**
 * Return the fingerprint algorithm this context is configured to use.
 * params: ctx = Chromaprint context pointer
 * returns: current algorithm version
 */
/*CHROMAPRINT_API*/ int chromaprint_get_algorithm (ChromaprintContext* ctx);

/**
 * Set a configuration option for the selected fingerprint algorithm.
 *
 * DO NOT USE THIS FUNCTION IF YOU ARE PLANNING TO USE
 * THE GENERATED FINGERPRINTS WITH THE ACOUSTID SERVICE.
 *
 * Possible options:
 *  - silence_threshold: threshold for detecting silence, 0-32767
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   name = option name
 *   value = option value
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_set_option (ChromaprintContext* ctx, const(char)* name, int value);

/**
 * Get the number of channels that is internally used for fingerprinting.
 *
 * Note: You normally don't need this. Just set the audio's actual number of channels
 * when calling chromaprint_start() and everything will work. This is only used for
 * certain optimized cases to control the audio source.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: number of channels
 */
/*CHROMAPRINT_API*/ int chromaprint_get_num_channels (ChromaprintContext* ctx);

/**
 * Get the sampling rate that is internally used for fingerprinting.
 *
 * Note: You normally don't need this. Just set the audio's actual number of channels
 * when calling chromaprint_start() and everything will work. This is only used for
 * certain optimized cases to control the audio source.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: sampling rate
 */
/*CHROMAPRINT_API*/ int chromaprint_get_sample_rate (ChromaprintContext* ctx);

/**
 * Get the duration of one item in the raw fingerprint in samples.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: duration in samples
 */
/*CHROMAPRINT_API*/ int chromaprint_get_item_duration (ChromaprintContext* ctx);

/**
 * Get the duration of one item in the raw fingerprint in milliseconds.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: duration in milliseconds
 */
/*CHROMAPRINT_API*/ int chromaprint_get_item_duration_ms (ChromaprintContext* ctx);

/**
 * Get the duration of internal buffers that the fingerprinting algorithm uses.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: duration in samples
 */
/*CHROMAPRINT_API*/ int chromaprint_get_delay (ChromaprintContext* ctx);

/**
 * Get the duration of internal buffers that the fingerprinting algorithm uses.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: duration in milliseconds
 */
/*CHROMAPRINT_API*/ int chromaprint_get_delay_ms (ChromaprintContext* ctx);

/**
 * Restart the computation of a fingerprint with a new audio stream.
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   sample_rate = sample rate of the audio stream (in Hz)
 *   num_channels = numbers of channels in the audio stream (1 or 2)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_start (ChromaprintContext* ctx, int sample_rate, int num_channels);

/**
 * Send audio data to the fingerprint calculator.
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   data = raw audio data, should point to an array of 16-bit signed integers in native byte-order
 *   size = size of the data buffer (in samples)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_feed (ChromaprintContext* ctx, const(short)* data, int size);

/**
 * Process any remaining buffered audio data.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_finish (ChromaprintContext* ctx);

/**
 * Return the calculated fingerprint as a compressed string.
 *
 * The caller is responsible for freeing the returned pointer using
 * chromaprint_dealloc().
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   fingerprint = pointer to a pointer, where a pointer to the allocated array will be stored (out)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_get_fingerprint (ChromaprintContext* ctx, char** fingerprint);

/**
 * Return the calculated fingerprint as an array of 32-bit integers.
 *
 * The caller is responsible for freeing the returned pointer using
 * chromaprint_dealloc().
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   fingerprint = pointer to a pointer, where a pointer to the allocated array will be stored (out)
 *   size = number of items in the returned raw fingerprint (out)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_get_raw_fingerprint(ChromaprintContext* ctx, uint** fingerprint, int* size);

/**
 * Return the length of the current raw fingerprint.
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   size = number of items in the current raw fingerprint (out)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_get_raw_fingerprint_size (ChromaprintContext* ctx, int* size);

/**
 * Return 32-bit hash of the calculated fingerprint.
 *
 * See chromaprint_hash_fingerprint() for details on how to use the hash.
 *
 * params:
 *   ctx = Chromaprint context pointer
 *   hash = pointer to a 32-bit integer where the hash will be stored (out)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_get_fingerprint_hash (ChromaprintContext* ctx, uint* hash);

/**
 * Clear the current fingerprint, but allow more data to be processed.
 *
 * This is useful if you are processing a long stream and want to many
 * smaller fingerprints, instead of waiting for the entire stream to be
 * processed.
 *
 * params: ctx = Chromaprint context pointer
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_clear_fingerprint (ChromaprintContext* ctx);

/**
 * Compress and optionally base64-encode a raw fingerprint
 *
 * The caller is responsible for freeing the returned pointer using
 * chromaprint_dealloc().
 *
 * params:
 *   fp = pointer to an array of 32-bit integers representing the raw fingerprint to be encoded
 *   size = number of items in the raw fingerprint
 *   algorithm = Chromaprint algorithm version which was used to generate the raw fingerprint
 *   encoded_fp = pointer to a pointer, where the encoded fingerprint will be stored (out)
 *   encoded_size = size of the encoded fingerprint in bytes (out)
 *   base64 = Whether to return binary data or base64-encoded ASCII data. The
 *            compressed fingerprint will be encoded using base64 with the
 *            URL-safe scheme if you set this parameter to 1. It will return
 *            binary data if it's 0.
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_encode_fingerprint (const(uint)* fp, int size, int algorithm, char** encoded_fp, int* encoded_size, int base64);

/**
 * Uncompress and optionally base64-decode an encoded fingerprint
 *
 * The caller is responsible for freeing the returned pointer using
 * chromaprint_dealloc().
 *
 * params:
 *   encoded_fp = pointer to an encoded fingerprint
 *   encoded_size = size of the encoded fingerprint in bytes
 *   fp = pointer to a pointer, where the decoded raw fingerprint (array of 32-bit integers) will be stored (out)
 *   size = Number of items in the returned raw fingerprint (out)
 *   algorithm = Chromaprint algorithm version which was used to generate the raw fingerprint (out)
 *   base64 = Whether the encoded_fp parameter contains binary data or
 *            base64-encoded ASCII data. If 1, it will base64-decode the data
 *            before uncompressing the fingerprint.
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_decode_fingerprint (const(char)* encoded_fp, int encoded_size, uint** fp, int* size, int* algorithm, int base64);

/**
 * Generate a single 32-bit hash for a raw fingerprint.
 *
 * If two fingerprints are similar, their hashes generated by this function
 * will also be similar. If they are significantly different, their hashes
 * will most likely be significantly different as well, but you can't rely
 * on that.
 *
 * You compare two hashes by counting the bits in which they differ. Normally
 * that would be something like POPCNT(hash1 XOR hash2), which returns a
 * number between 0 and 32. Anthing above 15 means the hashes are
 * completely different.
 *
 * params:
 *   fp = pointer to an array of 32-bit integers representing the raw fingerprint to be hashed
 *   size = number of items in the raw fingerprint
 *   hash = pointer to a 32-bit integer where the hash will be stored (out)
 *
 * returns: 0 on error, 1 on success
 */
/*CHROMAPRINT_API*/ int chromaprint_hash_fingerprint(const(uint)* fp, int size, uint *hash);

/**
 * Free memory allocated by any function from the Chromaprint API.
 *
 * params: ptr = pointer to be deallocated
 */
/*CHROMAPRINT_API*/ void chromaprint_dealloc(void *ptr);
