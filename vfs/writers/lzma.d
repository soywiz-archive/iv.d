/**
 * \file        api/lzma.h
 * \brief       The public API of liblzma data compression library
 *
 * liblzma is a public domain general-purpose data compression library with
 * a zlib-like API. The native file format is .xz, but also the old .lzma
 * format and raw (no headers) streams are supported. Multiple compression
 * algorithms (filters) are supported. Currently LZMA2 is the primary filter.
 *
 * liblzma is part of XZ Utils <http://tukaani.org/xz/>. XZ Utils includes
 * a gzip-like command line tool named xz and some other tools. XZ Utils
 * is developed and maintained by Lasse Collin.
 *
 * Major parts of liblzma are based on Igor Pavlov's public domain LZMA SDK
 * <http://7-zip.org/sdk.html>.
 *
 * The SHA-256 implementation is based on the public domain code found from
 * 7-Zip <http://7-zip.org/>, which has a modified version of the public
 * domain SHA-256 code found from Crypto++ <http://www.cryptopp.com/>.
 * The SHA-256 code in Crypto++ was written by Kevin Springle and Wei Dai.
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 */

module iv.vfs.writers.lzma;
pragma(lib, "lzma");

/***********
 * nothrow *
 ***********/

/*
 * None of the functions in liblzma may throw an exception. Even
 * the functions that use callback functions won't throw exceptions,
 * because liblzma would break if a callback function threw an exception.
 */
//lzma_nothrow --> nothrow


/********************
 * GNU C extensions *
 ********************/

/*
 * GNU C extensions are used conditionally in the public API. It doesn't
 * break anything if these are sometimes enabled and sometimes not, only
 * affects warnings and optimizations.
 */

//lzma_attr_pure --> pure
//lzma_attr_const --> const
//lzma_attr_warn_unused_result --> n/a


/+
/**************
 * Subheaders *
 **************/
public import deimos.lzma_.version_;
public import deimos.lzma_.base;
public import deimos.lzma_.vli;
public import deimos.lzma_.check;

/* Filters */
public import deimos.lzma_.filter;
public import deimos.lzma_.bcj;
public import deimos.lzma_.delta;
public import deimos.lzma_.lzma;

/* Container formats */
public import deimos.lzma_.container;

/* Advanced features */
public import deimos.lzma_.stream_flags;
public import deimos.lzma_.block;
public import deimos.lzma_.index;
public import deimos.lzma_.index_hash;

/* Hardware information */
public import deimos.lzma_.hardware;
+/


// ////////////////////////////////////////////////////////////////////////// //
// "version_.d"
/**
 * \file        lzma/version.h
 * \brief       Version number
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.version_;
//import deimos.lzma;
import std.conv;

extern(C):

/*
 * Version number split into components
 */
enum LZMA_VERSION_MAJOR = 5;
enum LZMA_VERSION_MINOR = 3;
enum LZMA_VERSION_PATCH = 0;
enum LZMA_VERSION_STABILITY = LZMA_VERSION_STABILITY_STABLE;

/*
#ifndef LZMA_VERSION_COMMIT
#	define LZMA_VERSION_COMMIT ""
#endif*/
enum LZMA_VERSION_COMMIT = "";

/*
 * Map symbolic stability levels to integers.
 */
enum LZMA_VERSION_STABILITY_ALPHA = 0;
enum LZMA_VERSION_STABILITY_BETA = 1;
enum LZMA_VERSION_STABILITY_STABLE = 2;


/**
 * \brief       Compile-time version number
 *
 * The version number is of format xyyyzzzs where
 *  - x = major
 *  - yyy = minor
 *  - zzz = revision
 *  - s indicates stability: 0 = alpha, 1 = beta, 2 = stable
 *
 * The same xyyyzzz triplet is never reused with different stability levels.
 * For example, if 5.1.0alpha has been released, there will never be 5.1.0beta
 * or 5.1.0 stable.
 *
 * \note        The version number of liblzma has nothing to with
 *              the version number of Igor Pavlov's LZMA SDK.
 */
enum LZMA_VERSION = (LZMA_VERSION_MAJOR * 10000000U 
		+ LZMA_VERSION_MINOR * 10000U
		+ LZMA_VERSION_PATCH * 10U
		+ LZMA_VERSION_STABILITY);


/*
 * Macros to construct the compile-time version string
 */
static if(LZMA_VERSION_STABILITY == LZMA_VERSION_STABILITY_ALPHA)
	enum LZMA_VERSION_STABILITY_STRING = "alpha";
else static if(LZMA_VERSION_STABILITY == LZMA_VERSION_STABILITY_BETA)
	enum LZMA_VERSION_STABILITY_STRING = "beta";
else static if(LZMA_VERSION_STABILITY == LZMA_VERSION_STABILITY_STABLE)
	enum LZMA_VERSION_STABILITY_STRING = "";
else
	static assert(false, "Incorrect LZMA_VERSION_STABILITY");

/**
 * \brief       Compile-time version as a string
 *
 * This can be for example "4.999.5alpha", "4.999.8beta", or "5.0.0" (stable
 * versions don't have any "stable" suffix). In future, a snapshot built
 * from source code repository may include an additional suffix, for example
 * "4.999.8beta-21-g1d92". The commit ID won't be available in numeric form
 * in LZMA_VERSION macro.
 */
enum LZMA_VERSION_STRING = 
		to!string(LZMA_VERSION_MAJOR) ~ "." ~ to!string(LZMA_VERSION_MINOR) ~
		"." ~ to!string(LZMA_VERSION_PATCH) ~ LZMA_VERSION_STABILITY_STRING ~
		LZMA_VERSION_COMMIT;


/**
 * \brief       Run-time version number as an integer
 *
 * Return the value of LZMA_VERSION macro at the compile time of liblzma.
 * This allows the application to compare if it was built against the same,
 * older, or newer version of liblzma that is currently running.
 */
nothrow uint lzma_version_number();


/**
 * \brief       Run-time version as a string
 *
 * This function may be useful if you want to display which version of
 * liblzma your application is currently using.
 */
nothrow immutable(char)* lzma_version_string();


// ////////////////////////////////////////////////////////////////////////// //
// "base.d"
/**
 * \file        lzma/base.h
 * \brief       Data types and functions used in many places in liblzma API
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.base;
//import deimos.lzma;

extern(C):

/**
 * \brief       Boolean
 *
 * This is here because C89 doesn't have stdbool.h. To set a value for
 * variables having type lzma_bool, you can use
 *   - C99's `true' and `false' from stdbool.h;
 *   - C++'s internal `true' and `false'; or
 *   - integers one (true) and zero (false).
 */
alias bool lzma_bool;


/**
 * \brief       Type of reserved enumeration variable in structures
 *
 * To avoid breaking library ABI when new features are added, several
 * structures contain extra variables that may be used in future. Since
 * sizeof(enum) can be different than sizeof(int), and sizeof(enum) may
 * even vary depending on the range of enumeration constants, we specify
 * a separate type to be used for reserved enumeration variables. All
 * enumeration constants in liblzma API will be non-negative and less
 * than 128, which should guarantee that the ABI won't break even when
 * new constants are added to existing enumerations.
 */
alias lzma_reserved_enum = uint;
enum : uint
{
	LZMA_RESERVED_ENUM      = 0
}


/**
 * \brief       Return values used by several functions in liblzma
 *
 * Check the descriptions of specific functions to find out which return
 * values they can return. With some functions the return values may have
 * more specific meanings than described here; those differences are
 * described per-function basis.
 */
alias lzma_ret = uint;
enum : uint
{
	LZMA_OK                 = 0,
		/**<
		 * \brief       Operation completed successfully
		 */

	LZMA_STREAM_END         = 1,
		/**<
		 * \brief       End of stream was reached
		 *
		 * In encoder, LZMA_SYNC_FLUSH, LZMA_FULL_FLUSH, or
		 * LZMA_FINISH was finished. In decoder, this indicates
		 * that all the data was successfully decoded.
		 *
		 * In all cases, when LZMA_STREAM_END is returned, the last
		 * output bytes should be picked from strm->next_out.
		 */

	LZMA_NO_CHECK           = 2,
		/**<
		 * \brief       Input stream has no integrity check
		 *
		 * This return value can be returned only if the
		 * LZMA_TELL_NO_CHECK flag was used when initializing
		 * the decoder. LZMA_NO_CHECK is just a warning, and
		 * the decoding can be continued normally.
		 *
		 * It is possible to call lzma_get_check() immediately after
		 * lzma_code has returned LZMA_NO_CHECK. The result will
		 * naturally be LZMA_CHECK_NONE, but the possibility to call
		 * lzma_get_check() may be convenient in some applications.
		 */

	LZMA_UNSUPPORTED_CHECK  = 3,
		/**<
		 * \brief       Cannot calculate the integrity check
		 *
		 * The usage of this return value is different in encoders
		 * and decoders.
		 *
		 * Encoders can return this value only from the initialization
		 * function. If initialization fails with this value, the
		 * encoding cannot be done, because there's no way to produce
		 * output with the correct integrity check.
		 *
		 * Decoders can return this value only from lzma_code() and
		 * only if the LZMA_TELL_UNSUPPORTED_CHECK flag was used when
		 * initializing the decoder. The decoding can still be
		 * continued normally even if the check type is unsupported,
		 * but naturally the check will not be validated, and possible
		 * errors may go undetected.
		 *
		 * With decoder, it is possible to call lzma_get_check()
		 * immediately after lzma_code() has returned
		 * LZMA_UNSUPPORTED_CHECK. This way it is possible to find
		 * out what the unsupported Check ID was.
		 */

	LZMA_GET_CHECK          = 4,
		/**<
		 * \brief       Integrity check type is now available
		 *
		 * This value can be returned only by the lzma_code() function
		 * and only if the decoder was initialized with the
		 * LZMA_TELL_ANY_CHECK flag. LZMA_GET_CHECK tells the
		 * application that it may now call lzma_get_check() to find
		 * out the Check ID. This can be used, for example, to
		 * implement a decoder that accepts only files that have
		 * strong enough integrity check.
		 */

	LZMA_MEM_ERROR          = 5,
		/**<
		 * \brief       Cannot allocate memory
		 *
		 * Memory allocation failed, or the size of the allocation
		 * would be greater than SIZE_MAX.
		 *
		 * Due to internal implementation reasons, the coding cannot
		 * be continued even if more memory were made available after
		 * LZMA_MEM_ERROR.
		 */

	LZMA_MEMLIMIT_ERROR     = 6,
		/**
		 * \brief       Memory usage limit was reached
		 *
		 * Decoder would need more memory than allowed by the
		 * specified memory usage limit. To continue decoding,
		 * the memory usage limit has to be increased with
		 * lzma_memlimit_set().
		 */

	LZMA_FORMAT_ERROR       = 7,
		/**<
		 * \brief       File format not recognized
		 *
		 * The decoder did not recognize the input as supported file
		 * format. This error can occur, for example, when trying to
		 * decode .lzma format file with lzma_stream_decoder,
		 * because lzma_stream_decoder accepts only the .xz format.
		 */

	LZMA_OPTIONS_ERROR      = 8,
		/**<
		 * \brief       Invalid or unsupported options
		 *
		 * Invalid or unsupported options, for example
		 *  - unsupported filter(s) or filter options; or
		 *  - reserved bits set in headers (decoder only).
		 *
		 * Rebuilding liblzma with more features enabled, or
		 * upgrading to a newer version of liblzma may help.
		 */

	LZMA_DATA_ERROR         = 9,
		/**<
		 * \brief       Data is corrupt
		 *
		 * The usage of this return value is different in encoders
		 * and decoders. In both encoder and decoder, the coding
		 * cannot continue after this error.
		 *
		 * Encoders return this if size limits of the target file
		 * format would be exceeded. These limits are huge, thus
		 * getting this error from an encoder is mostly theoretical.
		 * For example, the maximum compressed and uncompressed
		 * size of a .xz Stream is roughly 8 EiB (2^63 bytes).
		 *
		 * Decoders return this error if the input data is corrupt.
		 * This can mean, for example, invalid CRC32 in headers
		 * or invalid check of uncompressed data.
		 */

	LZMA_BUF_ERROR          = 10,
		/**<
		 * \brief       No progress is possible
		 *
		 * This error code is returned when the coder cannot consume
		 * any new input and produce any new output. The most common
		 * reason for this error is that the input stream being
		 * decoded is truncated or corrupt.
		 *
		 * This error is not fatal. Coding can be continued normally
		 * by providing more input and/or more output space, if
		 * possible.
		 *
		 * Typically the first call to lzma_code() that can do no
		 * progress returns LZMA_OK instead of LZMA_BUF_ERROR. Only
		 * the second consecutive call doing no progress will return
		 * LZMA_BUF_ERROR. This is intentional.
		 *
		 * With zlib, Z_BUF_ERROR may be returned even if the
		 * application is doing nothing wrong, so apps will need
		 * to handle Z_BUF_ERROR specially. The above hack
		 * guarantees that liblzma never returns LZMA_BUF_ERROR
		 * to properly written applications unless the input file
		 * is truncated or corrupt. This should simplify the
		 * applications a little.
		 */

	LZMA_PROG_ERROR         = 11,
		/**<
		 * \brief       Programming error
		 *
		 * This indicates that the arguments given to the function are
		 * invalid or the internal state of the decoder is corrupt.
		 *   - Function arguments are invalid or the structures
		 *     pointed by the argument pointers are invalid
		 *     e.g. if strm->next_out has been set to NULL and
		 *     strm->avail_out > 0 when calling lzma_code().
		 *   - lzma_* functions have been called in wrong order
		 *     e.g. lzma_code() was called right after lzma_end().
		 *   - If errors occur randomly, the reason might be flaky
		 *     hardware.
		 *
		 * If you think that your code is correct, this error code
		 * can be a sign of a bug in liblzma. See the documentation
		 * how to report bugs.
		 */
}


/**
 * \brief       The `action' argument for lzma_code()
 *
 * After the first use of LZMA_SYNC_FLUSH, LZMA_FULL_FLUSH, or LZMA_FINISH,
 * the same `action' must is used until lzma_code() returns LZMA_STREAM_END.
 * Also, the amount of input (that is, strm->avail_in) must not be modified
 * by the application until lzma_code() returns LZMA_STREAM_END. Changing the
 * `action' or modifying the amount of input will make lzma_code() return
 * LZMA_PROG_ERROR.
 */
alias lzma_action = uint;
enum : uint
{
	LZMA_RUN = 0,
		/**<
		 * \brief       Continue coding
		 *
		 * Encoder: Encode as much input as possible. Some internal
		 * buffering will probably be done (depends on the filter
		 * chain in use), which causes latency: the input used won't
		 * usually be decodeable from the output of the same
		 * lzma_code() call.
		 *
		 * Decoder: Decode as much input as possible and produce as
		 * much output as possible.
		 */

	LZMA_SYNC_FLUSH = 1,
		/**<
		 * \brief       Make all the input available at output
		 *
		 * Normally the encoder introduces some latency.
		 * LZMA_SYNC_FLUSH forces all the buffered data to be
		 * available at output without resetting the internal
		 * state of the encoder. This way it is possible to use
		 * compressed stream for example for communication over
		 * network.
		 *
		 * Only some filters support LZMA_SYNC_FLUSH. Trying to use
		 * LZMA_SYNC_FLUSH with filters that don't support it will
		 * make lzma_code() return LZMA_OPTIONS_ERROR. For example,
		 * LZMA1 doesn't support LZMA_SYNC_FLUSH but LZMA2 does.
		 *
		 * Using LZMA_SYNC_FLUSH very often can dramatically reduce
		 * the compression ratio. With some filters (for example,
		 * LZMA2), fine-tuning the compression options may help
		 * mitigate this problem significantly (for example,
		 * match finder with LZMA2).
		 *
		 * Decoders don't support LZMA_SYNC_FLUSH.
		 */

	LZMA_FULL_FLUSH = 2,
		/**<
		 * \brief       Finish encoding of the current Block
		 *
		 * All the input data going to the current Block must have
		 * been given to the encoder (the last bytes can still be
		 * pending in* next_in). Call lzma_code() with LZMA_FULL_FLUSH
		 * until it returns LZMA_STREAM_END. Then continue normally
		 * with LZMA_RUN or finish the Stream with LZMA_FINISH.
		 *
		 * This action is currently supported only by Stream encoder
		 * and easy encoder (which uses Stream encoder). If there is
		 * no unfinished Block, no empty Block is created.
		 */

	LZMA_FINISH = 3
		/**<
		 * \brief       Finish the coding operation
		 *
		 * All the input data must have been given to the encoder
		 * (the last bytes can still be pending in next_in).
		 * Call lzma_code() with LZMA_FINISH until it returns
		 * LZMA_STREAM_END. Once LZMA_FINISH has been used,
		 * the amount of input must no longer be changed by
		 * the application.
		 *
		 * When decoding, using LZMA_FINISH is optional unless the
		 * LZMA_CONCATENATED flag was used when the decoder was
		 * initialized. When LZMA_CONCATENATED was not used, the only
		 * effect of LZMA_FINISH is that the amount of input must not
		 * be changed just like in the encoder.
		 */
}


/**
 * \brief       Custom functions for memory handling
 *
 * A pointer to lzma_allocator may be passed via lzma_stream structure
 * to liblzma, and some advanced functions take a pointer to lzma_allocator
 * as a separate function argument. The library will use the functions
 * specified in lzma_allocator for memory handling instead of the default
 * malloc() and free(). C++ users should note that the custom memory
 * handling functions must not throw exceptions.
 *
 * liblzma doesn't make an internal copy of lzma_allocator. Thus, it is
 * OK to change these function pointers in the middle of the coding
 * process, but obviously it must be done carefully to make sure that the
 * replacement `free' can deallocate memory allocated by the earlier
 * `alloc' function(s).
 */
struct lzma_allocator
{
	/**
	 * \brief       Pointer to a custom memory allocation function
	 *
	 * If you don't want a custom allocator, but still want
	 * custom free(), set this to NULL and liblzma will use
	 * the standard malloc().
	 *
	 * \param       opaque  lzma_allocator.opaque (see below)
	 * \param       nmemb   Number of elements like in calloc(). liblzma
	 *                      will always set nmemb to 1, so it is safe to
	 *                      ignore nmemb in a custom allocator if you like.
	 *                      The nmemb argument exists only for
	 *                      compatibility with zlib and libbzip2.
	 * \param       size    Size of an element in bytes.
	 *                      liblzma never sets this to zero.
	 *
	 * \return      Pointer to the beginning of a memory block of
	 *              `size' bytes, or NULL if allocation fails
	 *              for some reason. When allocation fails, functions
	 *              of liblzma return LZMA_MEM_ERROR.
	 *
	 * The allocator should not waste time zeroing the allocated buffers.
	 * This is not only about speed, but also memory usage, since the
	 * operating system kernel doesn't necessarily allocate the requested
	 * memory in physical memory until it is actually used. With small
	 * input files, liblzma may actually need only a fraction of the
	 * memory that it requested for allocation.
	 *
	 * \note        LZMA_MEM_ERROR is also used when the size of the
	 *              allocation would be greater than SIZE_MAX. Thus,
	 *              don't assume that the custom allocator must have
	 *              returned NULL if some function from liblzma
	 *              returns LZMA_MEM_ERROR.
	 */
	void* function(void *opaque, size_t nmemb, size_t size) alloc;

	/**
	 * \brief       Pointer to a custom memory freeing function
	 *
	 * If you don't want a custom freeing function, but still
	 * want a custom allocator, set this to NULL and liblzma
	 * will use the standard free().
	 *
	 * \param       opaque  lzma_allocator.opaque (see below)
	 * \param       ptr     Pointer returned by lzma_allocator.alloc(),
	 *                      or when it is set to NULL, a pointer returned
	 *                      by the standard malloc().
	 */
	void function(void *opaque, void *ptr) free;

	/**
	 * \brief       Pointer passed to .alloc() and .free()
	 *
	 * opaque is passed as the first argument to lzma_allocator.alloc()
	 * and lzma_allocator.free(). This intended to ease implementing
	 * custom memory allocation functions for use with liblzma.
	 *
	 * If you don't need this, you should set this to NULL.
	 */
	void *opaque;
}


/**
 * \brief       Internal data structure
 *
 * The contents of this structure is not visible outside the library.
 */
struct lzma_internal {}


/**
 * \brief       Passing data to and from liblzma
 *
 * The lzma_stream structure is used for
 *  - passing pointers to input and output buffers to liblzma;
 *  - defining custom memory hander functions; and
 *  - holding a pointer to coder-specific internal data structures.
 *
 * Typical usage:
 *
 *  - After allocating lzma_stream (on stack or with malloc()), it must be
 *    initialized to LZMA_STREAM_INIT (see LZMA_STREAM_INIT for details).
 *
 *  - Initialize a coder to the lzma_stream, for example by using
 *    lzma_easy_encoder() or lzma_auto_decoder(). Some notes:
 *      - In contrast to zlib, strm->next_in and strm->next_out are
 *        ignored by all initialization functions, thus it is safe
 *        to not initialize them yet.
 *      - The initialization functions always set strm->total_in and
 *        strm->total_out to zero.
 *      - If the initialization function fails, no memory is left allocated
 *        that would require freeing with lzma_end() even if some memory was
 *        associated with the lzma_stream structure when the initialization
 *        function was called.
 *
 *  - Use lzma_code() to do the actual work.
 *
 *  - Once the coding has been finished, the existing lzma_stream can be
 *    reused. It is OK to reuse lzma_stream with different initialization
 *    function without calling lzma_end() first. Old allocations are
 *    automatically freed.
 *
 *  - Finally, use lzma_end() to free the allocated memory. lzma_end() never
 *    frees the lzma_stream structure itself.
 *
 * Application may modify the values of total_in and total_out as it wants.
 * They are updated by liblzma to match the amount of data read and
 * written, but aren't used for anything else.
 */
struct lzma_stream
{
	const(ubyte)* next_in; /**< Pointer to the next input byte. */
	size_t avail_in;    /**< Number of available input bytes in next_in. */
	ulong total_in;  /**< Total number of bytes read by liblzma. */

	ubyte* next_out;  /**< Pointer to the next output position. */
	size_t avail_out;   /**< Amount of free space in next_out. */
	ulong total_out; /**< Total number of bytes written by liblzma. */

	/**
	 * \brief       Custom memory allocation functions
	 *
	 * In most cases this is NULL which makes liblzma use
	 * the standard malloc() and free().
	 */
	lzma_allocator *allocator;

	/** Internal state is not visible to applications. */
	lzma_internal *internal;

	/*
	 * Reserved space to allow possible future extensions without
	 * breaking the ABI. Excluding the initialization of this structure,
	 * you should not touch these, because the names of these variables
	 * may change.
	 */
	void *reserved_ptr1;
	void *reserved_ptr2;
	void *reserved_ptr3;
	void *reserved_ptr4;
	ulong reserved_int1;
	ulong reserved_int2;
	size_t reserved_int3;
	size_t reserved_int4;
	lzma_reserved_enum reserved_enum1;
	lzma_reserved_enum reserved_enum2;
}

/**
 * Initialization for lzma_stream
 *
 * Not needed in d, just use lzma_stream.init
 */
//void LZMA_STREAM_INIT(){};
enum LZMA_STREAM_INIT = lzma_stream.init;


/**
 * \brief       Encode or decode data
 *
 * Once the lzma_stream has been successfully initialized (e.g. with
 * lzma_stream_encoder()), the actual encoding or decoding is done
 * using this function. The application has to update strm->next_in,
 * strm->avail_in, strm->next_out, and strm->avail_out to pass input
 * to and get output from liblzma.
 *
 * See the description of the coder-specific initialization function to find
 * out what `action' values are supported by the coder.
 */
nothrow lzma_ret lzma_code(lzma_stream *strm, lzma_action action);


/**
 * \brief       Free memory allocated for the coder data structures
 *
 * \param       strm    Pointer to lzma_stream that is at least initialized
 *                      with LZMA_STREAM_INIT.
 *
 * After lzma_end(strm), strm->internal is guaranteed to be NULL. No other
 * members of the lzma_stream structure are touched.
 *
 * \note        zlib indicates an error if application end()s unfinished
 *              stream structure. liblzma doesn't do this, and assumes that
 *              application knows what it is doing.
 */
nothrow void lzma_end(lzma_stream *strm);


/**
 * \brief       Get the memory usage of decoder filter chain
 *
 * This function is currently supported only when *strm has been initialized
 * with a function that takes a memlimit argument. With other functions, you
 * should use e.g. lzma_raw_encoder_memusage() or lzma_raw_decoder_memusage()
 * to estimate the memory requirements.
 *
 * This function is useful e.g. after LZMA_MEMLIMIT_ERROR to find out how big
 * the memory usage limit should have been to decode the input. Note that
 * this may give misleading information if decoding .xz Streams that have
 * multiple Blocks, because each Block can have different memory requirements.
 *
 * \return      How much memory is currently allocated for the filter
 *              decoders. If no filter chain is currently allocated,
 *              some non-zero value is still returned, which is less than
 *              or equal to what any filter chain would indicate as its
 *              memory requirement.
 *
 *              If this function isn't supported by *strm or some other error
 *              occurs, zero is returned.
 */
nothrow pure ulong lzma_memusage(const lzma_stream *strm);


/**
 * \brief       Get the current memory usage limit
 *
 * This function is supported only when *strm has been initialized with
 * a function that takes a memlimit argument.
 *
 * \return      On success, the current memory usage limit is returned
 *              (always non-zero). On error, zero is returned.
 */
nothrow pure ulong lzma_memlimit_get(const lzma_stream *strm);

/**
 * \brief       Set the memory usage limit
 *
 * This function is supported only when *strm has been initialized with
 * a function that takes a memlimit argument.
 *
 * \return      - LZMA_OK: New memory usage limit successfully set.
 *              - LZMA_MEMLIMIT_ERROR: The new limit is too small.
 *                The limit was not changed.
 *              - LZMA_PROG_ERROR: Invalid arguments, e.g. *strm doesn't
 *                support memory usage limit or memlimit was zero.
 */
nothrow lzma_ret lzma_memlimit_set(lzma_stream *strm, ulong memlimit);


// ////////////////////////////////////////////////////////////////////////// //
// "vli.d"
/**
 * \file        lzma/vli.h
 * \brief       Variable-length integer handling
 *
 * In the .xz format, most integers are encoded in a variable-length
 * representation, which is sometimes called little endian base-128 encoding.
 * This saves space when smaller values are more likely than bigger values.
 *
 * The encoding scheme encodes seven bits to every byte, using minimum
 * number of bytes required to represent the given value. Encodings that use
 * non-minimum number of bytes are invalid, thus every integer has exactly
 * one encoded representation. The maximum number of bits in a VLI is 63,
 * thus the vli argument must be less than or equal to UINT64_MAX / 2. You
 * should use LZMA_VLI_MAX for clarity.
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.vli;
//import deimos.lzma;

extern(C):


/**
 * \brief       Maximum supported value of a variable-length integer
 */
enum LZMA_VLI_MAX = (ulong.max / 2);

/**
 * \brief       VLI value to denote that the value is unknown
 */
enum LZMA_VLI_UNKNOWN = ulong.max;

/**
 * \brief       Maximum supported encoded length of variable length integers
 */
enum LZMA_VLI_BYTES_MAX = 9;

/**
 * \brief       VLI constant suffix
 */
//#define LZMA_VLI_C(n) UINT64_C(n)


/**
 * \brief       Variable-length integer type
 *
 * Valid VLI values are in the range [0, LZMA_VLI_MAX]. Unknown value is
 * indicated with LZMA_VLI_UNKNOWN, which is the maximum value of the
 * underlaying integer type.
 *
 * lzma_vli will be uint64_t for the foreseeable future. If a bigger size
 * is needed in the future, it is guaranteed that 2 * LZMA_VLI_MAX will
 * not overflow lzma_vli. This simplifies integer overflow detection.
 */
alias ulong lzma_vli;


/**
 * \brief       Validate a variable-length integer
 *
 * This is useful to test that application has given acceptable values
 * for example in the uncompressed_size and compressed_size variables.
 *
 * \return      True if the integer is representable as VLI or if it
 *              indicates unknown value.
 */
bool lzma_vli_is_valid(lzma_vli vli)
{
    return vli <= LZMA_VLI_MAX || (vli) == LZMA_VLI_UNKNOWN;
}


/**
 * \brief       Encode a variable-length integer
 *
 * This function has two modes: single-call and multi-call. Single-call mode
 * encodes the whole integer at once; it is an error if the output buffer is
 * too small. Multi-call mode saves the position in *vli_pos, and thus it is
 * possible to continue encoding if the buffer becomes full before the whole
 * integer has been encoded.
 *
 * \param       vli       Integer to be encoded
 * \param       vli_pos   How many VLI-encoded bytes have already been written
 *                        out. When starting to encode a new integer in
 *                        multi-call mode, *vli_pos must be set to zero.
 *                        To use single-call encoding, set vli_pos to NULL.
 * \param       out       Beginning of the output buffer
 * \param       out_pos   The next byte will be written to out[*out_pos].
 * \param       out_size  Size of the out buffer; the first byte into
 *                        which no data is written to is out[out_size].
 *
 * \return      Slightly different return values are used in multi-call and
 *              single-call modes.
 *
 *              Single-call (vli_pos == NULL):
 *              - LZMA_OK: Integer successfully encoded.
 *              - LZMA_PROG_ERROR: Arguments are not sane. This can be due
 *                to too little output space; single-call mode doesn't use
 *                LZMA_BUF_ERROR, since the application should have checked
 *                the encoded size with lzma_vli_size().
 *
 *              Multi-call (vli_pos != NULL):
 *              - LZMA_OK: So far all OK, but the integer is not
 *                completely written out yet.
 *              - LZMA_STREAM_END: Integer successfully encoded.
 *              - LZMA_BUF_ERROR: No output space was provided.
 *              - LZMA_PROG_ERROR: Arguments are not sane.
 */
nothrow lzma_ret lzma_vli_encode(lzma_vli vli, size_t *vli_pos,
		ubyte* out_, size_t *out_pos, size_t out_size);


/**
 * \brief       Decode a variable-length integer
 *
 * Like lzma_vli_encode(), this function has single-call and multi-call modes.
 *
 * \param       vli       Pointer to decoded integer. The decoder will
 *                        initialize it to zero when *vli_pos == 0, so
 *                        application isn't required to initialize *vli.
 * \param       vli_pos   How many bytes have already been decoded. When
 *                        starting to decode a new integer in multi-call
 *                        mode, *vli_pos must be initialized to zero. To
 *                        use single-call decoding, set vli_pos to NULL.
 * \param       in        Beginning of the input buffer
 * \param       in_pos    The next byte will be read from in[*in_pos].
 * \param       in_size   Size of the input buffer; the first byte that
 *                        won't be read is in[in_size].
 *
 * \return      Slightly different return values are used in multi-call and
 *              single-call modes.
 *
 *              Single-call (vli_pos == NULL):
 *              - LZMA_OK: Integer successfully decoded.
 *              - LZMA_DATA_ERROR: Integer is corrupt. This includes hitting
 *                the end of the input buffer before the whole integer was
 *                decoded; providing no input at all will use LZMA_DATA_ERROR.
 *              - LZMA_PROG_ERROR: Arguments are not sane.
 *
 *              Multi-call (vli_pos != NULL):
 *              - LZMA_OK: So far all OK, but the integer is not
 *                completely decoded yet.
 *              - LZMA_STREAM_END: Integer successfully decoded.
 *              - LZMA_DATA_ERROR: Integer is corrupt.
 *              - LZMA_BUF_ERROR: No input was provided.
 *              - LZMA_PROG_ERROR: Arguments are not sane.
 */
nothrow lzma_ret lzma_vli_decode(lzma_vli *vli, size_t *vli_pos,
		const(ubyte)* in_, size_t *in_pos, size_t in_size);


/**
 * \brief       Get the number of bytes required to encode a VLI
 *
 * \return      Number of bytes on success (1-9). If vli isn't valid,
 *              zero is returned.
 */
nothrow pure uint lzma_vli_size(lzma_vli vli);


// ////////////////////////////////////////////////////////////////////////// //
// "check.d"
/**
 * \file        lzma/check.h
 * \brief       Integrity checks
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.check;
//import deimos.lzma;

extern(C):

/**
 * \brief       Type of the integrity check (Check ID)
 *
 * The .xz format supports multiple types of checks that are calculated
 * from the uncompressed data. They vary in both speed and ability to
 * detect errors.
 */
alias lzma_check = uint;
enum : uint
{
	LZMA_CHECK_NONE     = 0,
		/**<
		 * No Check is calculated.
		 *
		 * Size of the Check field: 0 bytes
		 */

	LZMA_CHECK_CRC32    = 1,
		/**<
		 * CRC32 using the polynomial from the IEEE 802.3 standard
		 *
		 * Size of the Check field: 4 bytes
		 */

	LZMA_CHECK_CRC64    = 4,
		/**<
		 * CRC64 using the polynomial from the ECMA-182 standard
		 *
		 * Size of the Check field: 8 bytes
		 */

	LZMA_CHECK_SHA256   = 10
}


/**
 * \brief       Maximum valid Check ID
 *
 * The .xz file format specification specifies 16 Check IDs (0-15). Some
 * of them are only reserved, that is, no actual Check algorithm has been
 * assigned. When decoding, liblzma still accepts unknown Check IDs for
 * future compatibility. If a valid but unsupported Check ID is detected,
 * liblzma can indicate a warning; see the flags LZMA_TELL_NO_CHECK,
 * LZMA_TELL_UNSUPPORTED_CHECK, and LZMA_TELL_ANY_CHECK in container.h.
 */
enum LZMA_CHECK_ID_MAX = 15;


/**
 * \brief       Test if the given Check ID is supported
 *
 * Return true if the given Check ID is supported by this liblzma build.
 * Otherwise false is returned. It is safe to call this with a value that
 * is not in the range [0, 15]; in that case the return value is always false.
 *
 * You can assume that LZMA_CHECK_NONE and LZMA_CHECK_CRC32 are always
 * supported (even if liblzma is built with limited features).
 */
nothrow lzma_bool lzma_check_is_supported(lzma_check check);


/**
 * \brief       Get the size of the Check field with the given Check ID
 *
 * Although not all Check IDs have a check algorithm associated, the size of
 * every Check is already frozen. This function returns the size (in bytes) of
 * the Check field with the specified Check ID. The values are:
 * { 0, 4, 4, 4, 8, 8, 8, 16, 16, 16, 32, 32, 32, 64, 64, 64 }
 *
 * If the argument is not in the range [0, 15], UINT32_MAX is returned.
 */
nothrow uint lzma_check_size(lzma_check check);


/**
 * \brief       Maximum size of a Check field
 */
enum LZMA_CHECK_SIZE_MAX = 64;


/**
 * \brief       Calculate CRC32
 *
 * Calculate CRC32 using the polynomial from the IEEE 802.3 standard.
 *
 * \param       buf     Pointer to the input buffer
 * \param       size    Size of the input buffer
 * \param       crc     Previously returned CRC value. This is used to
 *                      calculate the CRC of a big buffer in smaller chunks.
 *                      Set to zero when starting a new calculation.
 *
 * \return      Updated CRC value, which can be passed to this function
 *              again to continue CRC calculation.
 */
nothrow pure uint lzma_crc32(
		const(ubyte)* buf, size_t size, uint crc);


/**
 * \brief       Calculate CRC64
 *
 * Calculate CRC64 using the polynomial from the ECMA-182 standard.
 *
 * This function is used similarly to lzma_crc32(). See its documentation.
 */
nothrow pure ulong lzma_crc64(
		const(ubyte)* buf, size_t size, ulong crc);


/*
 * SHA-256 functions are currently not exported to public API.
 * Contact Lasse Collin if you think it should be.
 */


/**
 * \brief       Get the type of the integrity check
 *
 * This function can be called only immediately after lzma_code() has
 * returned LZMA_NO_CHECK, LZMA_UNSUPPORTED_CHECK, or LZMA_GET_CHECK.
 * Calling this function in any other situation has undefined behavior.
 */
nothrow lzma_check lzma_get_check(const lzma_stream *strm);


// ////////////////////////////////////////////////////////////////////////// //
// "filter.d"
/**
 * \file        lzma/filter.h
 * \brief       Common filter related types and functions
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.filter;
//import deimos.lzma;

extern(C):

/**
 * \brief       Maximum number of filters in a chain
 *
 * A filter chain can have 1-4 filters, of which three are allowed to change
 * the size of the data. Usually only one or two filters are needed.
 */
enum LZMA_FILTERS_MAX = 4;


/**
 * \brief       Filter options
 *
 * This structure is used to pass Filter ID and a pointer filter's
 * options to liblzma. A few functions work with a single lzma_filter
 * structure, while most functions expect a filter chain.
 *
 * A filter chain is indicated with an array of lzma_filter structures.
 * The array is terminated with .id = LZMA_VLI_UNKNOWN. Thus, the filter
 * array must have LZMA_FILTERS_MAX + 1 elements (that is, five) to
 * be able to hold any arbitrary filter chain. This is important when
 * using lzma_block_header_decode() from block.h, because too small
 * array would make liblzma write past the end of the filters array.
 */
struct lzma_filter
{
	/**
	 * \brief       Filter ID
	 *
	 * Use constants whose name begin with `LZMA_FILTER_' to specify
	 * different filters. In an array of lzma_filter structures, use
	 * LZMA_VLI_UNKNOWN to indicate end of filters.
	 *
	 * \note        This is not an enum, because on some systems enums
	 *              cannot be 64-bit.
	 */
	lzma_vli id;

	/**
	 * \brief       Pointer to filter-specific options structure
	 *
	 * If the filter doesn't need options, set this to NULL. If id is
	 * set to LZMA_VLI_UNKNOWN, options is ignored, and thus
	 * doesn't need be initialized.
	 */
	void *options;

}


/**
 * \brief       Test if the given Filter ID is supported for encoding
 *
 * Return true if the give Filter ID is supported for encoding by this
 * liblzma build. Otherwise false is returned.
 *
 * There is no way to list which filters are available in this particular
 * liblzma version and build. It would be useless, because the application
 * couldn't know what kind of options the filter would need.
 */
nothrow lzma_bool lzma_filter_encoder_is_supported(lzma_vli id);


/**
 * \brief       Test if the given Filter ID is supported for decoding
 *
 * Return true if the give Filter ID is supported for decoding by this
 * liblzma build. Otherwise false is returned.
 */
nothrow lzma_bool lzma_filter_decoder_is_supported(lzma_vli id);


/**
 * \brief       Copy the filters array
 *
 * Copy the Filter IDs and filter-specific options from src to dest.
 * Up to LZMA_FILTERS_MAX filters are copied, plus the terminating
 * .id == LZMA_VLI_UNKNOWN. Thus, dest should have at least
 * LZMA_FILTERS_MAX + 1 elements space unless the caller knows that
 * src is smaller than that.
 *
 * Unless the filter-specific options is NULL, the Filter ID has to be
 * supported by liblzma, because liblzma needs to know the size of every
 * filter-specific options structure. The filter-specific options are not
 * validated. If options is NULL, any unsupported Filter IDs are copied
 * without returning an error.
 *
 * Old filter-specific options in dest are not freed, so dest doesn't
 * need to be initialized by the caller in any way.
 *
 * If an error occurs, memory possibly already allocated by this function
 * is always freed.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_OPTIONS_ERROR: Unsupported Filter ID and its options
 *                is not NULL.
 *              - LZMA_PROG_ERROR: src or dest is NULL.
 */
nothrow lzma_ret lzma_filters_copy(const lzma_filter*src,
		lzma_filter *dest, lzma_allocator *allocator);


/**
 * \brief       Calculate approximate memory requirements for raw encoder
 *
 * This function can be used to calculate the memory requirements for
 * Block and Stream encoders too because Block and Stream encoders don't
 * need significantly more memory than raw encoder.
 *
 * \param       filters     Array of filters terminated with
 *                          .id == LZMA_VLI_UNKNOWN.
 *
 * \return      Number of bytes of memory required for the given
 *              filter chain when encoding. If an error occurs,
 *              for example due to unsupported filter chain,
 *              UINT64_MAX is returned.
 */
pure nothrow ulong lzma_raw_encoder_memusage(const lzma_filter *filters);


/**
 * \brief       Calculate approximate memory requirements for raw decoder
 *
 * This function can be used to calculate the memory requirements for
 * Block and Stream decoders too because Block and Stream decoders don't
 * need significantly more memory than raw decoder.
 *
 * \param       filters     Array of filters terminated with
 *                          .id == LZMA_VLI_UNKNOWN.
 *
 * \return      Number of bytes of memory required for the given
 *              filter chain when decoding. If an error occurs,
 *              for example due to unsupported filter chain,
 *              UINT64_MAX is returned.
 */
nothrow pure ulong lzma_raw_decoder_memusage(const lzma_filter *filters);


/**
 * \brief       Initialize raw encoder
 *
 * This function may be useful when implementing custom file formats.
 *
 * \param       strm    Pointer to properly prepared lzma_stream
 * \param       filters Array of lzma_filter structures. The end of the
 *                      array must be marked with .id = LZMA_VLI_UNKNOWN.
 *
 * The `action' with lzma_code() can be LZMA_RUN, LZMA_SYNC_FLUSH (if the
 * filter chain supports it), or LZMA_FINISH.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_raw_encoder(
		lzma_stream *strm, const lzma_filter *filters);


/**
 * \brief       Initialize raw decoder
 *
 * The initialization of raw decoder goes similarly to raw encoder.
 *
 * The `action' with lzma_code() can be LZMA_RUN or LZMA_FINISH. Using
 * LZMA_FINISH is not required, it is supported just for convenience.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_raw_decoder(
		lzma_stream *strm, const lzma_filter *filters);


/**
 * \brief       Update the filter chain in the encoder
 *
 * This function is for advanced users only. This function has two slightly
 * different purposes:
 *
 *  - After LZMA_FULL_FLUSH when using Stream encoder: Set a new filter
 *    chain, which will be used starting from the next Block.
 *
 *  - After LZMA_SYNC_FLUSH using Raw, Block, or Stream encoder: Change
 *    the filter-specific options in the middle of encoding. The actual
 *    filters in the chain (Filter IDs) cannot be changed. In the future,
 *    it might become possible to change the filter options without
 *    using LZMA_SYNC_FLUSH.
 *
 * While rarely useful, this function may be called also when no data has
 * been compressed yet. In that case, this function will behave as if
 * LZMA_FULL_FLUSH (Stream encoder) or LZMA_SYNC_FLUSH (Raw or Block
 * encoder) had been used right before calling this function.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_MEMLIMIT_ERROR
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_filters_update(
		lzma_stream *strm, const lzma_filter *filters);


/**
 * \brief       Single-call raw encoder
 *
 * \param       filters     Array of lzma_filter structures. The end of the
 *                          array must be marked with .id = LZMA_VLI_UNKNOWN.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_size     Size of the input buffer
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if encoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_BUF_ERROR: Not enough output buffer space.
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_MEM_ERROR
 *              - LZMA_DATA_ERROR
 *              - LZMA_PROG_ERROR
 *
 * \note        There is no function to calculate how big output buffer
 *              would surely be big enough. (lzma_stream_buffer_bound()
 *              works only for lzma_stream_buffer_encode(); raw encoder
 *              won't necessarily meet that bound.)
 */
nothrow lzma_ret lzma_raw_buffer_encode(
		const lzma_filter *filters, lzma_allocator *allocator,
		const(ubyte) *in_, size_t in_size, ubyte *out_,
		size_t *out_pos, size_t out_size);


/**
 * \brief       Single-call raw decoder
 *
 * \param       filters     Array of lzma_filter structures. The end of the
 *                          array must be marked with .id = LZMA_VLI_UNKNOWN.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_pos      The next byte will be read from in[*in_pos].
 *                          *in_pos is updated only if decoding succeeds.
 * \param       in_size     Size of the input buffer; the first byte that
 *                          won't be read is in[in_size].
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if encoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 */
nothrow lzma_ret lzma_raw_buffer_decode(const lzma_filter *filters,
		lzma_allocator *allocator,
		const(ubyte) *in_, size_t *in_pos, size_t in_size,
		ubyte *out_, size_t *out_pos, size_t out_size);


/**
 * \brief       Get the size of the Filter Properties field
 *
 * This function may be useful when implementing custom file formats
 * using the raw encoder and decoder.
 *
 * \param       size    Pointer to uint32_t to hold the size of the properties
 * \param       filter  Filter ID and options (the size of the properties may
 *                      vary depending on the options)
 *
 * \return      - LZMA_OK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 *
 * \note        This function validates the Filter ID, but does not
 *              necessarily validate the options. Thus, it is possible
 *              that this returns LZMA_OK while the following call to
 *              lzma_properties_encode() returns LZMA_OPTIONS_ERROR.
 */
nothrow lzma_ret lzma_properties_size(
		uint *size, const lzma_filter *filter);


/**
 * \brief       Encode the Filter Properties field
 *
 * \param       filter  Filter ID and options
 * \param       props   Buffer to hold the encoded options. The size of
 *                      buffer must have been already determined with
 *                      lzma_properties_size().
 *
 * \return      - LZMA_OK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 *
 * \note        Even this function won't validate more options than actually
 *              necessary. Thus, it is possible that encoding the properties
 *              succeeds but using the same options to initialize the encoder
 *              will fail.
 *
 * \note        If lzma_properties_size() indicated that the size
 *              of the Filter Properties field is zero, calling
 *              lzma_properties_encode() is not required, but it
 *              won't do any harm either.
 */
nothrow lzma_ret lzma_properties_encode(
		const lzma_filter *filter, ubyte *props);


/**
 * \brief       Decode the Filter Properties field
 *
 * \param       filter      filter->id must have been set to the correct
 *                          Filter ID. filter->options doesn't need to be
 *                          initialized (it's not freed by this function). The
 *                          decoded options will be stored to filter->options.
 *                          filter->options is set to NULL if there are no
 *                          properties or if an error occurs.
 * \param       allocator   Custom memory allocator used to allocate the
 *                          options. Set to NULL to use the default malloc(),
 *                          and in case of an error, also free().
 * \param       props       Input buffer containing the properties.
 * \param       props_size  Size of the properties. This must be the exact
 *                          size; giving too much or too little input will
 *                          return LZMA_OPTIONS_ERROR.
 *
 * \return      - LZMA_OK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_MEM_ERROR
 */
nothrow lzma_ret lzma_properties_decode(
		lzma_filter *filter, lzma_allocator *allocator,
		const ubyte *props, size_t props_size);


/**
 * \brief       Calculate encoded size of a Filter Flags field
 *
 * Knowing the size of Filter Flags is useful to know when allocating
 * memory to hold the encoded Filter Flags.
 *
 * \param       size    Pointer to integer to hold the calculated size
 * \param       filter  Filter ID and associated options whose encoded
 *                      size is to be calculated
 *
 * \return      - LZMA_OK: *size set successfully. Note that this doesn't
 *                guarantee that filter->options is valid, thus
 *                lzma_filter_flags_encode() may still fail.
 *              - LZMA_OPTIONS_ERROR: Unknown Filter ID or unsupported options.
 *              - LZMA_PROG_ERROR: Invalid options
 *
 * \note        If you need to calculate size of List of Filter Flags,
 *              you need to loop over every lzma_filter entry.
 */
nothrow lzma_ret lzma_filter_flags_size(
		uint *size, const lzma_filter *filter);


/**
 * \brief       Encode Filter Flags into given buffer
 *
 * In contrast to some functions, this doesn't allocate the needed buffer.
 * This is due to how this function is used internally by liblzma.
 *
 * \param       filter      Filter ID and options to be encoded
 * \param       out         Beginning of the output buffer
 * \param       out_pos     out[*out_pos] is the next write position. This
 *                          is updated by the encoder.
 * \param       out_size    out[out_size] is the first byte to not write.
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_OPTIONS_ERROR: Invalid or unsupported options.
 *              - LZMA_PROG_ERROR: Invalid options or not enough output
 *                buffer space (you should have checked it with
 *                lzma_filter_flags_size()).
 */
nothrow lzma_ret lzma_filter_flags_encode(const lzma_filter *filter,
		ubyte *out_, size_t *out_pos, size_t out_size);


/**
 * \brief       Decode Filter Flags from given buffer
 *
 * The decoded result is stored into *filter. The old value of
 * filter->options is not free()d.
 *
 * \return      - LZMA_OK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_MEM_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_filter_flags_decode(
		lzma_filter *filter, lzma_allocator *allocator,
		const ubyte *in_, size_t *in_pos, size_t in_size);


// ////////////////////////////////////////////////////////////////////////// //
// "bcj.d"
/**
 * \file        lzma/bcj.h
 * \brief       Branch/Call/Jump conversion filters
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.bcj;
//import deimos.lzma;

extern(C):

/* Filter IDs for lzma_filter.id */

enum LZMA_FILTER_X86 = 0x04UL;
	/**<
	 * Filter for x86 binaries
	 */


enum LZMA_FILTER_POWERPC = 0x05UL;
	/**<
	 * Filter for Big endian PowerPC binaries
	 */

enum LZMA_FILTER_IA64 = 0x06UL;
	/**<
	 * Filter for IA-64 (Itanium) binaries.
	 */

enum LZMA_FILTER_ARM = 0x07UL;
	/**<
	 * Filter for ARM binaries.
	 */

enum LZMA_FILTER_ARMTHUMB = 0x08UL;
	/**<
	 * Filter for ARM-Thumb binaries.
	 */

enum LZMA_FILTER_SPARC = 0x09UL;
	/**<
	 * Filter for SPARC binaries.
	 */


/**
 * \brief       Options for BCJ filters
 *
 * The BCJ filters never change the size of the data. Specifying options
 * for them is optional: if pointer to options is NULL, default value is
 * used. You probably never need to specify options to BCJ filters, so just
 * set the options pointer to NULL and be happy.
 *
 * If options with non-default values have been specified when encoding,
 * the same options must also be specified when decoding.
 *
 * \note        At the moment, none of the BCJ filters support
 *              LZMA_SYNC_FLUSH. If LZMA_SYNC_FLUSH is specified,
 *              LZMA_OPTIONS_ERROR will be returned. If there is need,
 *              partial support for LZMA_SYNC_FLUSH can be added in future.
 *              Partial means that flushing would be possible only at
 *              offsets that are multiple of 2, 4, or 16 depending on
 *              the filter, except x86 which cannot be made to support
 *              LZMA_SYNC_FLUSH predictably.
 */
struct lzma_options_bcj
{
	/**
	 * \brief       Start offset for conversions
	 *
	 * This setting is useful only when the same filter is used
	 * _separately_ for multiple sections of the same executable file,
	 * and the sections contain cross-section branch/call/jump
	 * instructions. In that case it is beneficial to set the start
	 * offset of the non-first sections so that the relative addresses
	 * of the cross-section branch/call/jump instructions will use the
	 * same absolute addresses as in the first section.
	 *
	 * When the pointer to options is NULL, the default value (zero)
	 * is used.
	 */
	uint start_offset;
}


// ////////////////////////////////////////////////////////////////////////// //
// "delta.d"
/**
 * \file        lzma/delta.h
 * \brief       Delta filter
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.delta;
//import deimos.lzma;

extern(C):

/**
 * \brief       Filter ID
 *
 * Filter ID of the Delta filter. This is used as lzma_filter.id.
 */
enum LZMA_FILTER_DELTA = 0x03UL;


/**
 * \brief       Type of the delta calculation
 *
 * Currently only byte-wise delta is supported. Other possible types could
 * be, for example, delta of 16/32/64-bit little/big endian integers, but
 * these are not currently planned since byte-wise delta is almost as good.
 */
alias lzma_delta_type = uint;
enum : uint
{
	LZMA_DELTA_TYPE_BYTE
}


/**
 * \brief       Options for the Delta filter
 *
 * These options are needed by both encoder and decoder.
 */
struct lzma_options_delta
{
	/** For now, this must always be LZMA_DELTA_TYPE_BYTE. */
	lzma_delta_type type;

	/**
	 * \brief       Delta distance
	 *
	 * With the only currently supported type, LZMA_DELTA_TYPE_BYTE,
	 * the distance is as bytes.
	 *
	 * Examples:
	 *  - 16-bit stereo audio: distance = 4 bytes
	 *  - 24-bit RGB image data: distance = 3 bytes
	 */
	uint dist;
	enum LZMA_DELTA_DIST_MIN = 1;
	enum LZMA_DELTA_DIST_MAX = 256;

	/*
	 * Reserved space to allow possible future extensions without
	 * breaking the ABI. You should not touch these, because the names
	 * of these variables may change. These are and will never be used
	 * when type is LZMA_DELTA_TYPE_BYTE, so it is safe to leave these
	 * uninitialized.
	 */
	uint reserved_int1;
	uint reserved_int2;
	uint reserved_int3;
	uint reserved_int4;
	void *reserved_ptr1;
	void *reserved_ptr2;

}


// ////////////////////////////////////////////////////////////////////////// //
// "lzma.d"
/**
 * \file        lzma/lzma.h
 * \brief       LZMA1 and LZMA2 filters
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.lzma;
//import deimos.lzma;

extern(C):


/**
 * \brief       LZMA1 Filter ID
 *
 * LZMA1 is the very same thing as what was called just LZMA in LZMA Utils,
 * 7-Zip, and LZMA SDK. It's called LZMA1 here to prevent developers from
 * accidentally using LZMA when they actually want LZMA2.
 *
 * LZMA1 shouldn't be used for new applications unless you _really_ know
 * what you are doing. LZMA2 is almost always a better choice.
 */
enum LZMA_FILTER_LZMA1 = 0x4000000000000001UL;

/**
 * \brief       LZMA2 Filter ID
 *
 * Usually you want this instead of LZMA1. Compared to LZMA1, LZMA2 adds
 * support for LZMA_SYNC_FLUSH, uncompressed chunks (smaller expansion
 * when trying to compress uncompressible data), possibility to change
 * lc/lp/pb in the middle of encoding, and some other internal improvements.
 */
enum LZMA_FILTER_LZMA2 = 0x21UL;


/**
 * \brief       Match finders
 *
 * Match finder has major effect on both speed and compression ratio.
 * Usually hash chains are faster than binary trees.
 *
 * If you will use LZMA_SYNC_FLUSH often, the hash chains may be a better
 * choice, because binary trees get much higher compression ratio penalty
 * with LZMA_SYNC_FLUSH.
 *
 * The memory usage formulas are only rough estimates, which are closest to
 * reality when dict_size is a power of two. The formulas are  more complex
 * in reality, and can also change a little between liblzma versions. Use
 * lzma_raw_encoder_memusage() to get more accurate estimate of memory usage.
 */
alias lzma_match_finder = uint;
enum : uint
{
	LZMA_MF_HC3     = 0x03,
		/**<
		 * \brief       Hash Chain with 2- and 3-byte hashing
		 *
		 * Minimum nice_len: 3
		 *
		 * Memory usage:
		 *  - dict_size <= 16 MiB: dict_size * 7.5
		 *  - dict_size > 16 MiB: dict_size * 5.5 + 64 MiB
		 */

	LZMA_MF_HC4     = 0x04,
		/**<
		 * \brief       Hash Chain with 2-, 3-, and 4-byte hashing
		 *
		 * Minimum nice_len: 4
		 *
		 * Memory usage:
		 *  - dict_size <= 32 MiB: dict_size * 7.5
		 *  - dict_size > 32 MiB: dict_size * 6.5
		 */

	LZMA_MF_BT2     = 0x12,
		/**<
		 * \brief       Binary Tree with 2-byte hashing
		 *
		 * Minimum nice_len: 2
		 *
		 * Memory usage: dict_size * 9.5
		 */

	LZMA_MF_BT3     = 0x13,
		/**<
		 * \brief       Binary Tree with 2- and 3-byte hashing
		 *
		 * Minimum nice_len: 3
		 *
		 * Memory usage:
		 *  - dict_size <= 16 MiB: dict_size * 11.5
		 *  - dict_size > 16 MiB: dict_size * 9.5 + 64 MiB
		 */

	LZMA_MF_BT4     = 0x14
		/**<
		 * \brief       Binary Tree with 2-, 3-, and 4-byte hashing
		 *
		 * Minimum nice_len: 4
		 *
		 * Memory usage:
		 *  - dict_size <= 32 MiB: dict_size * 11.5
		 *  - dict_size > 32 MiB: dict_size * 10.5
		 */
}


/**
 * \brief       Test if given match finder is supported
 *
 * Return true if the given match finder is supported by this liblzma build.
 * Otherwise false is returned. It is safe to call this with a value that
 * isn't listed in lzma_match_finder enumeration; the return value will be
 * false.
 *
 * There is no way to list which match finders are available in this
 * particular liblzma version and build. It would be useless, because
 * a new match finder, which the application developer wasn't aware,
 * could require giving additional options to the encoder that the older
 * match finders don't need.
 */
nothrow lzma_bool lzma_mf_is_supported(lzma_match_finder match_finder);


/**
 * \brief       Compression modes
 *
 * This selects the function used to analyze the data produced by the match
 * finder.
 */
alias lzma_mode = uint;
enum : uint
{
	LZMA_MODE_FAST = 1,
		/**<
		 * \brief       Fast compression
		 *
		 * Fast mode is usually at its best when combined with
		 * a hash chain match finder.
		 */

	LZMA_MODE_NORMAL = 2
		/**<
		 * \brief       Normal compression
		 *
		 * This is usually notably slower than fast mode. Use this
		 * together with binary tree match finders to expose the
		 * full potential of the LZMA1 or LZMA2 encoder.
		 */
}


/**
 * \brief       Test if given compression mode is supported
 *
 * Return true if the given compression mode is supported by this liblzma
 * build. Otherwise false is returned. It is safe to call this with a value
 * that isn't listed in lzma_mode enumeration; the return value will be false.
 *
 * There is no way to list which modes are available in this particular
 * liblzma version and build. It would be useless, because a new compression
 * mode, which the application developer wasn't aware, could require giving
 * additional options to the encoder that the older modes don't need.
 */
nothrow lzma_bool lzma_mode_is_supported(lzma_mode mode);


/**
 * \brief       Options specific to the LZMA1 and LZMA2 filters
 *
 * Since LZMA1 and LZMA2 share most of the code, it's simplest to share
 * the options structure too. For encoding, all but the reserved variables
 * need to be initialized unless specifically mentioned otherwise.
 * lzma_lzma_preset() can be used to get a good starting point.
 *
 * For raw decoding, both LZMA1 and LZMA2 need dict_size, preset_dict, and
 * preset_dict_size (if preset_dict != NULL). LZMA1 needs also lc, lp, and pb.
 */
struct lzma_options_lzma
{
	/**
	 * \brief       Dictionary size in bytes
	 *
	 * Dictionary size indicates how many bytes of the recently processed
	 * uncompressed data is kept in memory. One method to reduce size of
	 * the uncompressed data is to store distance-length pairs, which
	 * indicate what data to repeat from the dictionary buffer. Thus,
	 * the bigger the dictionary, the better the compression ratio
	 * usually is.
	 *
	 * Maximum size of the dictionary depends on multiple things:
	 *  - Memory usage limit
	 *  - Available address space (not a problem on 64-bit systems)
	 *  - Selected match finder (encoder only)
	 *
	 * Currently the maximum dictionary size for encoding is 1.5 GiB
	 * (i.e. (UINT32_C(1) << 30) + (UINT32_C(1) << 29)) even on 64-bit
	 * systems for certain match finder implementation reasons. In the
	 * future, there may be match finders that support bigger
	 * dictionaries.
	 *
	 * Decoder already supports dictionaries up to 4 GiB - 1 B (i.e.
	 * UINT32_MAX), so increasing the maximum dictionary size of the
	 * encoder won't cause problems for old decoders.
	 *
	 * Because extremely small dictionaries sizes would have unneeded
	 * overhead in the decoder, the minimum dictionary size is 4096 bytes.
	 *
	 * \note        When decoding, too big dictionary does no other harm
	 *              than wasting memory.
	 */
	uint dict_size;
	enum LZMA_DICT_SIZE_MIN     =  4096U;
	enum LZMA_DICT_SIZE_DEFAULT =  (1U << 23);

	/**
	 * \brief       Pointer to an initial dictionary
	 *
	 * It is possible to initialize the LZ77 history window using
	 * a preset dictionary. It is useful when compressing many
	 * similar, relatively small chunks of data independently from
	 * each other. The preset dictionary should contain typical
	 * strings that occur in the files being compressed. The most
	 * probable strings should be near the end of the preset dictionary.
	 *
	 * This feature should be used only in special situations. For
	 * now, it works correctly only with raw encoding and decoding.
	 * Currently none of the container formats supported by
	 * liblzma allow preset dictionary when decoding, thus if
	 * you create a .xz or .lzma file with preset dictionary, it
	 * cannot be decoded with the regular decoder functions. In the
	 * future, the .xz format will likely get support for preset
	 * dictionary though.
	 */
	const ubyte *preset_dict;

	/**
	 * \brief       Size of the preset dictionary
	 *
	 * Specifies the size of the preset dictionary. If the size is
	 * bigger than dict_size, only the last dict_size bytes are
	 * processed.
	 *
	 * This variable is read only when preset_dict is not NULL.
	 * If preset_dict is not NULL but preset_dict_size is zero,
	 * no preset dictionary is used (identical to only setting
	 * preset_dict to NULL).
	 */
	uint preset_dict_size;

	/**
	 * \brief       Number of literal context bits
	 *
	 * How many of the highest bits of the previous uncompressed
	 * eight-bit byte (also known as `literal') are taken into
	 * account when predicting the bits of the next literal.
	 *
	 * E.g. in typical English text, an upper-case letter is
	 * often followed by a lower-case letter, and a lower-case
	 * letter is usually followed by another lower-case letter.
	 * In the US-ASCII character set, the highest three bits are 010
	 * for upper-case letters and 011 for lower-case letters.
	 * When lc is at least 3, the literal coding can take advantage of
	 * this property in the uncompressed data.
	 *
	 * There is a limit that applies to literal context bits and literal
	 * position bits together: lc + lp <= 4. Without this limit the
	 * decoding could become very slow, which could have security related
	 * results in some cases like email servers doing virus scanning.
	 * This limit also simplifies the internal implementation in liblzma.
	 *
	 * There may be LZMA1 streams that have lc + lp > 4 (maximum possible
	 * lc would be 8). It is not possible to decode such streams with
	 * liblzma.
	 */
	uint lc;
	enum LZMA_LCLP_MIN   = 0;
	enum LZMA_LCLP_MAX   = 4;
	enum LZMA_LC_DEFAULT = 3;

	/**
	 * \brief       Number of literal position bits
	 *
	 * lp affects what kind of alignment in the uncompressed data is
	 * assumed when encoding literals. A literal is a single 8-bit byte.
	 * See pb below for more information about alignment.
	 */
	uint lp;
	enum LZMA_LP_DEFAULT = 0;

	/**
	 * \brief       Number of position bits
	 *
	 * pb affects what kind of alignment in the uncompressed data is
	 * assumed in general. The default means four-byte alignment
	 * (2^ pb =2^2=4), which is often a good choice when there's
	 * no better guess.
	 *
	 * When the aligment is known, setting pb accordingly may reduce
	 * the file size a little. E.g. with text files having one-byte
	 * alignment (US-ASCII, ISO-8859-*, UTF-8), setting pb=0 can
	 * improve compression slightly. For UTF-16 text, pb=1 is a good
	 * choice. If the alignment is an odd number like 3 bytes, pb=0
	 * might be the best choice.
	 *
	 * Even though the assumed alignment can be adjusted with pb and
	 * lp, LZMA1 and LZMA2 still slightly favor 16-byte alignment.
	 * It might be worth taking into account when designing file formats
	 * that are likely to be often compressed with LZMA1 or LZMA2.
	 */
	uint pb;
	enum LZMA_PB_MIN     = 0;
	enum LZMA_PB_MAX     = 4;
	enum LZMA_PB_DEFAULT = 2;

	/** Compression mode */
	lzma_mode mode;

	/**
	 * \brief       Nice length of a match
	 *
	 * This determines how many bytes the encoder compares from the match
	 * candidates when looking for the best match. Once a match of at
	 * least nice_len bytes long is found, the encoder stops looking for
	 * better candidates and encodes the match. (Naturally, if the found
	 * match is actually longer than nice_len, the actual length is
	 * encoded; it's not truncated to nice_len.)
	 *
	 * Bigger values usually increase the compression ratio and
	 * compression time. For most files, 32 to 128 is a good value,
	 * which gives very good compression ratio at good speed.
	 *
	 * The exact minimum value depends on the match finder. The maximum
	 * is 273, which is the maximum length of a match that LZMA1 and
	 * LZMA2 can encode.
	 */
	uint nice_len;

	/** Match finder ID */
	lzma_match_finder mf;

	/**
	 * \brief       Maximum search depth in the match finder
	 *
	 * For every input byte, match finder searches through the hash chain
	 * or binary tree in a loop, each iteration going one step deeper in
	 * the chain or tree. The searching stops if
	 *  - a match of at least nice_len bytes long is found;
	 *  - all match candidates from the hash chain or binary tree have
	 *    been checked; or
	 *  - maximum search depth is reached.
	 *
	 * Maximum search depth is needed to prevent the match finder from
	 * wasting too much time in case there are lots of short match
	 * candidates. On the other hand, stopping the search before all
	 * candidates have been checked can reduce compression ratio.
	 *
	 * Setting depth to zero tells liblzma to use an automatic default
	 * value, that depends on the selected match finder and nice_len.
	 * The default is in the range [4, 200] or so (it may vary between
	 * liblzma versions).
	 *
	 * Using a bigger depth value than the default can increase
	 * compression ratio in some cases. There is no strict maximum value,
	 * but high values (thousands or millions) should be used with care:
	 * the encoder could remain fast enough with typical input, but
	 * malicious input could cause the match finder to slow down
	 * dramatically, possibly creating a denial of service attack.
	 */
	uint depth;

	/*
	 * Reserved space to allow possible future extensions without
	 * breaking the ABI. You should not touch these, because the names
	 * of these variables may change. These are and will never be used
	 * with the currently supported options, so it is safe to leave these
	 * uninitialized.
	 */
	uint reserved_int1;
	uint reserved_int2;
	uint reserved_int3;
	uint reserved_int4;
	uint reserved_int5;
	uint reserved_int6;
	uint reserved_int7;
	uint reserved_int8;
	lzma_reserved_enum reserved_enum1;
	lzma_reserved_enum reserved_enum2;
	lzma_reserved_enum reserved_enum3;
	lzma_reserved_enum reserved_enum4;
	void *reserved_ptr1;
	void *reserved_ptr2;

}


/**
 * \brief       Set a compression preset to lzma_options_lzma structure
 *
 * 0 is the fastest and 9 is the slowest. These match the switches -0 .. -9
 * of the xz command line tool. In addition, it is possible to bitwise-or
 * flags to the preset. Currently only LZMA_PRESET_EXTREME is supported.
 * The flags are defined in container.h, because the flags are used also
 * with lzma_easy_encoder().
 *
 * The preset values are subject to changes between liblzma versions.
 *
 * This function is available only if LZMA1 or LZMA2 encoder has been enabled
 * when building liblzma.
 *
 * \return      On success, false is returned. If the preset is not
 *              supported, true is returned.
 */
nothrow lzma_bool lzma_lzma_preset(
		lzma_options_lzma *options, uint preset);


// ////////////////////////////////////////////////////////////////////////// //
// "container.d"
/**
 * \file        lzma/container.h
 * \brief       File formats
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.container;
//import deimos.lzma;

extern(C):

/************
 * Encoding *
 ************/

/**
 * \brief       Default compression preset
 *
 * It's not straightforward to recommend a default preset, because in some
 * cases keeping the resource usage relatively low is more important that
 * getting the maximum compression ratio.
 */
enum uint LZMA_PRESET_DEFAULT = 6U;


/**
 * \brief       Mask for preset level
 *
 * This is useful only if you need to extract the level from the preset
 * variable. That should be rare.
 */
enum uint LZMA_PRESET_LEVEL_MASK = 0x1FU;


/*
 * Preset flags
 *
 * Currently only one flag is defined.
 */

/**
 * \brief       Extreme compression preset
 *
 * This flag modifies the preset to make the encoding significantly slower
 * while improving the compression ratio only marginally. This is useful
 * when you don't mind wasting time to get as small result as possible.
 *
 * This flag doesn't affect the memory usage requirements of the decoder (at
 * least not significantly). The memory usage of the encoder may be increased
 * a little but only at the lowest preset levels (0-3).
 */
enum uint LZMA_PRESET_EXTREME = (1U << 31);


/**
 * \brief       Calculate approximate memory usage of easy encoder
 *
 * This function is a wrapper for lzma_raw_encoder_memusage().
 *
 * \param       preset  Compression preset (level and possible flags)
 *
 * \return      Number of bytes of memory required for the given
 *              preset when encoding. If an error occurs, for example
 *              due to unsupported preset, UINT64_MAX is returned.
 */
nothrow pure ulong lzma_easy_encoder_memusage(uint preset);


/**
 * \brief       Calculate approximate decoder memory usage of a preset
 *
 * This function is a wrapper for lzma_raw_decoder_memusage().
 *
 * \param       preset  Compression preset (level and possible flags)
 *
 * \return      Number of bytes of memory required to decompress a file
 *              that was compressed using the given preset. If an error
 *              occurs, for example due to unsupported preset, UINT64_MAX
 *              is returned.
 */
nothrow pure ulong lzma_easy_decoder_memusage(uint preset);


/**
 * \brief       Initialize .xz Stream encoder using a preset number
 *
 * This function is intended for those who just want to use the basic features
 * if liblzma (that is, most developers out there).
 *
 * \param       strm    Pointer to lzma_stream that is at least initialized
 *                      with LZMA_STREAM_INIT.
 * \param       preset  Compression preset to use. A preset consist of level
 *                      number and zero or more flags. Usually flags aren't
 *                      used, so preset is simply a number [0, 9] which match
 *                      the options -0 ... -9 of the xz command line tool.
 *                      Additional flags can be be set using bitwise-or with
 *                      the preset level number, e.g. 6 | LZMA_PRESET_EXTREME.
 * \param       check   Integrity check type to use. See check.h for available
 *                      checks. The xz command line tool defaults to
 *                      LZMA_CHECK_CRC64, which is a good choice if you are
 *                      unsure. LZMA_CHECK_CRC32 is good too as long as the
 *                      uncompressed file is not many gigabytes.
 *
 * \return      - LZMA_OK: Initialization succeeded. Use lzma_code() to
 *                encode your data.
 *              - LZMA_MEM_ERROR: Memory allocation failed.
 *              - LZMA_OPTIONS_ERROR: The given compression preset is not
 *                supported by this build of liblzma.
 *              - LZMA_UNSUPPORTED_CHECK: The given check type is not
 *                supported by this liblzma build.
 *              - LZMA_PROG_ERROR: One or more of the parameters have values
 *                that will never be valid. For example, strm == NULL.
 *
 * If initialization fails (return value is not LZMA_OK), all the memory
 * allocated for *strm by liblzma is always freed. Thus, there is no need
 * to call lzma_end() after failed initialization.
 *
 * If initialization succeeds, use lzma_code() to do the actual encoding.
 * Valid values for `action' (the second argument of lzma_code()) are
 * LZMA_RUN, LZMA_SYNC_FLUSH, LZMA_FULL_FLUSH, and LZMA_FINISH. In future,
 * there may be compression levels or flags that don't support LZMA_SYNC_FLUSH.
 */
nothrow lzma_ret lzma_easy_encoder(
		lzma_stream *strm, uint preset, lzma_check check);


/**
 * \brief       Single-call .xz Stream encoding using a preset number
 *
 * The maximum required output buffer size can be calculated with
 * lzma_stream_buffer_bound().
 *
 * \param       preset      Compression preset to use. See the description
 *                          in lzma_easy_encoder().
 * \param       check       Type of the integrity check to calculate from
 *                          uncompressed data.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_size     Size of the input buffer
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if encoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_BUF_ERROR: Not enough output buffer space.
 *              - LZMA_UNSUPPORTED_CHECK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_MEM_ERROR
 *              - LZMA_DATA_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_easy_buffer_encode(
		uint preset, lzma_check check,
		lzma_allocator *allocator, const(ubyte)* in_, size_t in_size,
		ubyte* out_, size_t *out_pos, size_t out_size);


/**
 * \brief       Initialize .xz Stream encoder using a custom filter chain
 *
 * \param       strm    Pointer to properly prepared lzma_stream
 * \param       filters Array of filters. This must be terminated with
 *                      filters[n].id = LZMA_VLI_UNKNOWN. See filter.h for
 *                      more information.
 * \param       check   Type of the integrity check to calculate from
 *                      uncompressed data.
 *
 * \return      - LZMA_OK: Initialization was successful.
 *              - LZMA_MEM_ERROR
 *              - LZMA_UNSUPPORTED_CHECK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_stream_encoder(lzma_stream *strm,
		const lzma_filter *filters, lzma_check check);


/**
 * \brief       Initialize .lzma encoder (legacy file format)
 *
 * The .lzma format is sometimes called the LZMA_Alone format, which is the
 * reason for the name of this function. The .lzma format supports only the
 * LZMA1 filter. There is no support for integrity checks like CRC32.
 *
 * Use this function if and only if you need to create files readable by
 * legacy LZMA tools such as LZMA Utils 4.32.x. Moving to the .xz format
 * is strongly recommended.
 *
 * The valid action values for lzma_code() are LZMA_RUN and LZMA_FINISH.
 * No kind of flushing is supported, because the file format doesn't make
 * it possible.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_alone_encoder(
		lzma_stream *strm, const lzma_options_lzma *options);


/**
 * \brief       Calculate output buffer size for single-call Stream encoder
 *
 * When trying to compress uncompressible data, the encoded size will be
 * slightly bigger than the input data. This function calculates how much
 * output buffer space is required to be sure that lzma_stream_buffer_encode()
 * doesn't return LZMA_BUF_ERROR.
 *
 * The calculated value is not exact, but it is guaranteed to be big enough.
 * The actual maximum output space required may be slightly smaller (up to
 * about 100 bytes). This should not be a problem in practice.
 *
 * If the calculated maximum size doesn't fit into size_t or would make the
 * Stream grow past LZMA_VLI_MAX (which should never happen in practice),
 * zero is returned to indicate the error.
 *
 * \note        The limit calculated by this function applies only to
 *              single-call encoding. Multi-call encoding may (and probably
 *              will) have larger maximum expansion when encoding
 *              uncompressible data. Currently there is no function to
 *              calculate the maximum expansion of multi-call encoding.
 */
nothrow size_t lzma_stream_buffer_bound(size_t uncompressed_size);


/**
 * \brief       Single-call .xz Stream encoder
 *
 * \param       filters     Array of filters. This must be terminated with
 *                          filters[n].id = LZMA_VLI_UNKNOWN. See filter.h
 *                          for more information.
 * \param       check       Type of the integrity check to calculate from
 *                          uncompressed data.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_size     Size of the input buffer
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if encoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_BUF_ERROR: Not enough output buffer space.
 *              - LZMA_UNSUPPORTED_CHECK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_MEM_ERROR
 *              - LZMA_DATA_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_stream_buffer_encode(
		lzma_filter *filters, lzma_check check,
		lzma_allocator *allocator, const(ubyte)* in_, size_t in_size,
		ubyte* out_, size_t *out_pos, size_t out_size);


/************
 * Decoding *
 ************/

/**
 * This flag makes lzma_code() return LZMA_NO_CHECK if the input stream
 * being decoded has no integrity check. Note that when used with
 * lzma_auto_decoder(), all .lzma files will trigger LZMA_NO_CHECK
 * if LZMA_TELL_NO_CHECK is used.
 */
enum uint LZMA_TELL_NO_CHECK = 0x01U;


/**
 * This flag makes lzma_code() return LZMA_UNSUPPORTED_CHECK if the input
 * stream has an integrity check, but the type of the integrity check is not
 * supported by this liblzma version or build. Such files can still be
 * decoded, but the integrity check cannot be verified.
 */
enum uint LZMA_TELL_UNSUPPORTED_CHECK = 0x02U;


/**
 * This flag makes lzma_code() return LZMA_GET_CHECK as soon as the type
 * of the integrity check is known. The type can then be got with
 * lzma_get_check().
 */
enum uint LZMA_TELL_ANY_CHECK = 0x04U;


/**
 * This flag enables decoding of concatenated files with file formats that
 * allow concatenating compressed files as is. From the formats currently
 * supported by liblzma, only the .xz format allows concatenated files.
 * Concatenated files are not allowed with the legacy .lzma format.
 *
 * This flag also affects the usage of the `action' argument for lzma_code().
 * When LZMA_CONCATENATED is used, lzma_code() won't return LZMA_STREAM_END
 * unless LZMA_FINISH is used as `action'. Thus, the application has to set
 * LZMA_FINISH in the same way as it does when encoding.
 *
 * If LZMA_CONCATENATED is not used, the decoders still accept LZMA_FINISH
 * as `action' for lzma_code(), but the usage of LZMA_FINISH isn't required.
 */
enum uint LZMA_CONCATENATED = 0x08U;


/**
 * \brief       Initialize .xz Stream decoder
 *
 * \param       strm        Pointer to properly prepared lzma_stream
 * \param       memlimit    Memory usage limit as bytes. Use UINT64_MAX
 *                          to effectively disable the limiter.
 * \param       flags       Bitwise-or of zero or more of the decoder flags:
 *                          LZMA_TELL_NO_CHECK, LZMA_TELL_UNSUPPORTED_CHECK,
 *                          LZMA_TELL_ANY_CHECK, LZMA_CONCATENATED
 *
 * \return      - LZMA_OK: Initialization was successful.
 *              - LZMA_MEM_ERROR: Cannot allocate memory.
 *              - LZMA_OPTIONS_ERROR: Unsupported flags
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_stream_decoder(
		lzma_stream *strm, ulong memlimit, uint flags);


/**
 * \brief       Decode .xz Streams and .lzma files with autodetection
 *
 * This decoder autodetects between the .xz and .lzma file formats, and
 * calls lzma_stream_decoder() or lzma_alone_decoder() once the type
 * of the input file has been detected.
 *
 * \param       strm        Pointer to properly prepared lzma_stream
 * \param       memlimit    Memory usage limit as bytes. Use UINT64_MAX
 *                          to effectively disable the limiter.
 * \param       flags       Bitwise-or of flags, or zero for no flags.
 *
 * \return      - LZMA_OK: Initialization was successful.
 *              - LZMA_MEM_ERROR: Cannot allocate memory.
 *              - LZMA_OPTIONS_ERROR: Unsupported flags
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_auto_decoder(
		lzma_stream *strm, ulong memlimit, uint flags);


/**
 * \brief       Initialize .lzma decoder (legacy file format)
 *
 * Valid `action' arguments to lzma_code() are LZMA_RUN and LZMA_FINISH.
 * There is no need to use LZMA_FINISH, but allowing it may simplify
 * certain types of applications.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_alone_decoder(
		lzma_stream *strm, ulong memlimit);


/**
 * \brief       Single-call .xz Stream decoder
 *
 * \param       memlimit    Pointer to how much memory the decoder is allowed
 *                          to allocate. The value pointed by this pointer is
 *                          modified if and only if LZMA_MEMLIMIT_ERROR is
 *                          returned.
 * \param       flags       Bitwise-or of zero or more of the decoder flags:
 *                          LZMA_TELL_NO_CHECK, LZMA_TELL_UNSUPPORTED_CHECK,
 *                          LZMA_CONCATENATED. Note that LZMA_TELL_ANY_CHECK
 *                          is not allowed and will return LZMA_PROG_ERROR.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_pos      The next byte will be read from in[*in_pos].
 *                          *in_pos is updated only if decoding succeeds.
 * \param       in_size     Size of the input buffer; the first byte that
 *                          won't be read is in[in_size].
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if decoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Decoding was successful.
 *              - LZMA_FORMAT_ERROR
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_DATA_ERROR
 *              - LZMA_NO_CHECK: This can be returned only if using
 *                the LZMA_TELL_NO_CHECK flag.
 *              - LZMA_UNSUPPORTED_CHECK: This can be returned only if using
 *                the LZMA_TELL_UNSUPPORTED_CHECK flag.
 *              - LZMA_MEM_ERROR
 *              - LZMA_MEMLIMIT_ERROR: Memory usage limit was reached.
 *                The minimum required memlimit value was stored to *memlimit.
 *              - LZMA_BUF_ERROR: Output buffer was too small.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_stream_buffer_decode(
		ulong *memlimit, uint flags, lzma_allocator *allocator,
		const (ubyte)* in_, size_t *in_pos, size_t in_size,
		ubyte* out_, size_t *out_pos, size_t out_size);


// ////////////////////////////////////////////////////////////////////////// //
// "stream_flags.d"
/**
 * \file        lzma/stream_flags.h
 * \brief       .xz Stream Header and Stream Footer encoder and decoder
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.stream_flags;
//import deimos.lzma;

extern(C):


/**
 * \brief       Size of Stream Header and Stream Footer
 *
 * Stream Header and Stream Footer have the same size and they are not
 * going to change even if a newer version of the .xz file format is
 * developed in future.
 */
enum LZMA_STREAM_HEADER_SIZE = 12;


/**
 * \brief       Options for encoding/decoding Stream Header and Stream Footer
 */
struct lzma_stream_flags
{
	/**
	 * \brief       Stream Flags format version
	 *
	 * To prevent API and ABI breakages if new features are needed in
	 * Stream Header or Stream Footer, a version number is used to
	 * indicate which fields in this structure are in use. For now,
	 * version must always be zero. With non-zero version, the
	 * lzma_stream_header_encode() and lzma_stream_footer_encode()
	 * will return LZMA_OPTIONS_ERROR.
	 *
	 * lzma_stream_header_decode() and lzma_stream_footer_decode()
	 * will always set this to the lowest value that supports all the
	 * features indicated by the Stream Flags field. The application
	 * must check that the version number set by the decoding functions
	 * is supported by the application. Otherwise it is possible that
	 * the application will decode the Stream incorrectly.
	 */
	uint version_;

	/**
	 * \brief       Backward Size
	 *
	 * Backward Size must be a multiple of four bytes. In this Stream
	 * format version, Backward Size is the size of the Index field.
	 *
	 * Backward Size isn't actually part of the Stream Flags field, but
	 * it is convenient to include in this structure anyway. Backward
	 * Size is present only in the Stream Footer. There is no need to
	 * initialize backward_size when encoding Stream Header.
	 *
	 * lzma_stream_header_decode() always sets backward_size to
	 * LZMA_VLI_UNKNOWN so that it is convenient to use
	 * lzma_stream_flags_compare() when both Stream Header and Stream
	 * Footer have been decoded.
	 */
	lzma_vli backward_size;
	enum LZMA_BACKWARD_SIZE_MIN = 4;
	enum LZMA_BACKWARD_SIZE_MAX = (1UL << 34);

	/**
	 * \brief       Check ID
	 *
	 * This indicates the type of the integrity check calculated from
	 * uncompressed data.
	 */
	lzma_check check;

	/*
	 * Reserved space to allow possible future extensions without
	 * breaking the ABI. You should not touch these, because the
	 * names of these variables may change.
	 *
	 * (We will never be able to use all of these since Stream Flags
	 * is just two bytes plus Backward Size of four bytes. But it's
	 * nice to have the proper types when they are needed.)
	 */
	lzma_reserved_enum reserved_enum1;
	lzma_reserved_enum reserved_enum2;
	lzma_reserved_enum reserved_enum3;
	lzma_reserved_enum reserved_enum4;
	lzma_bool reserved_bool1;
	lzma_bool reserved_bool2;
	lzma_bool reserved_bool3;
	lzma_bool reserved_bool4;
	lzma_bool reserved_bool5;
	lzma_bool reserved_bool6;
	lzma_bool reserved_bool7;
	lzma_bool reserved_bool8;
	uint reserved_int1;
	uint reserved_int2;
}


/**
 * \brief       Encode Stream Header
 *
 * \param       options     Stream Header options to be encoded.
 *                          options->backward_size is ignored and doesn't
 *                          need to be initialized.
 * \param       out         Beginning of the output buffer of
 *                          LZMA_STREAM_HEADER_SIZE bytes.
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_OPTIONS_ERROR: options->version is not supported by
 *                this liblzma version.
 *              - LZMA_PROG_ERROR: Invalid options.
 */
nothrow lzma_ret lzma_stream_header_encode(
		const lzma_stream_flags *options, ubyte *out_);


/**
 * \brief       Encode Stream Footer
 *
 * \param       options     Stream Footer options to be encoded.
 * \param       out         Beginning of the output buffer of
 *                          LZMA_STREAM_HEADER_SIZE bytes.
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_OPTIONS_ERROR: options->version is not supported by
 *                this liblzma version.
 *              - LZMA_PROG_ERROR: Invalid options.
 */
nothrow lzma_ret lzma_stream_footer_encode(
		const lzma_stream_flags *options, ubyte *out_);


/**
 * \brief       Decode Stream Header
 *
 * \param       options     Target for the decoded Stream Header options.
 * \param       in          Beginning of the input buffer of
 *                          LZMA_STREAM_HEADER_SIZE bytes.
 *
 * options->backward_size is always set to LZMA_VLI_UNKNOWN. This is to
 * help comparing Stream Flags from Stream Header and Stream Footer with
 * lzma_stream_flags_compare().
 *
 * \return      - LZMA_OK: Decoding was successful.
 *              - LZMA_FORMAT_ERROR: Magic bytes don't match, thus the given
 *                buffer cannot be Stream Header.
 *              - LZMA_DATA_ERROR: CRC32 doesn't match, thus the header
 *                is corrupt.
 *              - LZMA_OPTIONS_ERROR: Unsupported options are present
 *                in the header.
 *
 * \note        When decoding .xz files that contain multiple Streams, it may
 *              make sense to print "file format not recognized" only if
 *              decoding of the Stream Header of the _first_ Stream gives
 *              LZMA_FORMAT_ERROR. If non-first Stream Header gives
 *              LZMA_FORMAT_ERROR, the message used for LZMA_DATA_ERROR is
 *              probably more appropriate.
 *
 *              For example, Stream decoder in liblzma uses LZMA_DATA_ERROR if
 *              LZMA_FORMAT_ERROR is returned by lzma_stream_header_decode()
 *              when decoding non-first Stream.
 */
nothrow lzma_ret lzma_stream_header_decode(
		lzma_stream_flags *options, const ubyte *in_);


/**
 * \brief       Decode Stream Footer
 *
 * \param       options     Target for the decoded Stream Header options.
 * \param       in          Beginning of the input buffer of
 *                          LZMA_STREAM_HEADER_SIZE bytes.
 *
 * \return      - LZMA_OK: Decoding was successful.
 *              - LZMA_FORMAT_ERROR: Magic bytes don't match, thus the given
 *                buffer cannot be Stream Footer.
 *              - LZMA_DATA_ERROR: CRC32 doesn't match, thus the Stream Footer
 *                is corrupt.
 *              - LZMA_OPTIONS_ERROR: Unsupported options are present
 *                in Stream Footer.
 *
 * \note        If Stream Header was already decoded successfully, but
 *              decoding Stream Footer returns LZMA_FORMAT_ERROR, the
 *              application should probably report some other error message
 *              than "file format not recognized", since the file more likely
 *              is corrupt (possibly truncated). Stream decoder in liblzma
 *              uses LZMA_DATA_ERROR in this situation.
 */
nothrow lzma_ret lzma_stream_footer_decode(
		lzma_stream_flags *options, const ubyte *in_);


/**
 * \brief       Compare two lzma_stream_flags structures
 *
 * backward_size values are compared only if both are not
 * LZMA_VLI_UNKNOWN.
 *
 * \return      - LZMA_OK: Both are equal. If either had backward_size set
 *                to LZMA_VLI_UNKNOWN, backward_size values were not
 *                compared or validated.
 *              - LZMA_DATA_ERROR: The structures differ.
 *              - LZMA_OPTIONS_ERROR: version in either structure is greater
 *                than the maximum supported version (currently zero).
 *              - LZMA_PROG_ERROR: Invalid value, e.g. invalid check or
 *                backward_size.
 */
nothrow pure lzma_ret lzma_stream_flags_compare(
		const lzma_stream_flags *a, const lzma_stream_flags *b);


// ////////////////////////////////////////////////////////////////////////// //
// "block.d"
/**
 * \file        lzma/block.h
 * \brief       .xz Block handling
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.block;
//import deimos.lzma;

extern(C):

//TODO: initialize fields to void?
/**
 * \brief       Options for the Block and Block Header encoders and decoders
 *
 * Different Block handling functions use different parts of this structure.
 * Some read some members, other functions write, and some do both. Only the
 * members listed for reading need to be initialized when the specified
 * functions are called. The members marked for writing will be assigned
 * new values at some point either by calling the given function or by
 * later calls to lzma_code().
 */
struct lzma_block
{
	/**
	 * \brief       Block format version
	 *
	 * To prevent API and ABI breakages if new features are needed in
	 * the Block field, a version number is used to indicate which
	 * fields in this structure are in use. For now, version must always
	 * be zero. With non-zero version, most Block related functions will
	 * return LZMA_OPTIONS_ERROR.
	 *
	 * Read by:
	 *  - All functions that take pointer to lzma_block as argument,
	 *    including lzma_block_header_decode().
	 *
	 * Written by:
	 *  - lzma_block_header_decode()
	 */
	uint version_;

	/**
	 * \brief       Size of the Block Header field
	 *
	 * This is always a multiple of four.
	 *
	 * Read by:
	 *  - lzma_block_header_encode()
	 *  - lzma_block_header_decode()
	 *  - lzma_block_compressed_size()
	 *  - lzma_block_unpadded_size()
	 *  - lzma_block_total_size()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_decode()
	 *
	 * Written by:
	 *  - lzma_block_header_size()
	 *  - lzma_block_buffer_encode()
	 */

	uint header_size;
	enum LZMA_BLOCK_HEADER_SIZE_MIN = 8;
	enum LZMA_BLOCK_HEADER_SIZE_MAX = 1024;

	/**
	 * \brief       Type of integrity Check
	 *
	 * The Check ID is not stored into the Block Header, thus its value
	 * must be provided also when decoding.
	 *
	 * Read by:
	 *  - lzma_block_header_encode()
	 *  - lzma_block_header_decode()
	 *  - lzma_block_compressed_size()
	 *  - lzma_block_unpadded_size()
	 *  - lzma_block_total_size()
	 *  - lzma_block_encoder()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_encode()
	 *  - lzma_block_buffer_decode()
	 */
	lzma_check check;

	/**
	 * \brief       Size of the Compressed Data in bytes
	 *
	 * Encoding: If this is not LZMA_VLI_UNKNOWN, Block Header encoder
	 * will store this value to the Block Header. Block encoder doesn't
	 * care about this value, but will set it once the encoding has been
	 * finished.
	 *
	 * Decoding: If this is not LZMA_VLI_UNKNOWN, Block decoder will
	 * verify that the size of the Compressed Data field matches
	 * compressed_size.
	 *
	 * Usually you don't know this value when encoding in streamed mode,
	 * and thus cannot write this field into the Block Header.
	 *
	 * In non-streamed mode you can reserve space for this field before
	 * encoding the actual Block. After encoding the data, finish the
	 * Block by encoding the Block Header. Steps in detail:
	 *
	 *  - Set compressed_size to some big enough value. If you don't know
	 *    better, use LZMA_VLI_MAX, but remember that bigger values take
	 *    more space in Block Header.
	 *
	 *  - Call lzma_block_header_size() to see how much space you need to
	 *    reserve for the Block Header.
	 *
	 *  - Encode the Block using lzma_block_encoder() and lzma_code().
	 *    It sets compressed_size to the correct value.
	 *
	 *  - Use lzma_block_header_encode() to encode the Block Header.
	 *    Because space was reserved in the first step, you don't need
	 *    to call lzma_block_header_size() anymore, because due to
	 *    reserving, header_size has to be big enough. If it is "too big",
	 *    lzma_block_header_encode() will add enough Header Padding to
	 *    make Block Header to match the size specified by header_size.
	 *
	 * Read by:
	 *  - lzma_block_header_size()
	 *  - lzma_block_header_encode()
	 *  - lzma_block_compressed_size()
	 *  - lzma_block_unpadded_size()
	 *  - lzma_block_total_size()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_decode()
	 *
	 * Written by:
	 *  - lzma_block_header_decode()
	 *  - lzma_block_compressed_size()
	 *  - lzma_block_encoder()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_encode()
	 *  - lzma_block_buffer_decode()
	 */
	lzma_vli compressed_size;

	/**
	 * \brief       Uncompressed Size in bytes
	 *
	 * This is handled very similarly to compressed_size above.
	 *
	 * uncompressed_size is needed by fewer functions than
	 * compressed_size. This is because uncompressed_size isn't
	 * needed to validate that Block stays within proper limits.
	 *
	 * Read by:
	 *  - lzma_block_header_size()
	 *  - lzma_block_header_encode()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_decode()
	 *
	 * Written by:
	 *  - lzma_block_header_decode()
	 *  - lzma_block_encoder()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_encode()
	 *  - lzma_block_buffer_decode()
	 */
	lzma_vli uncompressed_size;

	/**
	 * \brief       Array of filters
	 *
	 * There can be 1-4 filters. The end of the array is marked with
	 * .id = LZMA_VLI_UNKNOWN.
	 *
	 * Read by:
	 *  - lzma_block_header_size()
	 *  - lzma_block_header_encode()
	 *  - lzma_block_encoder()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_encode()
	 *  - lzma_block_buffer_decode()
	 *
	 * Written by:
	 *  - lzma_block_header_decode(): Note that this does NOT free()
	 *    the old filter options structures. All unused filters[] will
	 *    have .id == LZMA_VLI_UNKNOWN and .options == NULL. If
	 *    decoding fails, all filters[] are guaranteed to be
	 *    LZMA_VLI_UNKNOWN and NULL.
	 *
	 * \note        Because of the array is terminated with
	 *              .id = LZMA_VLI_UNKNOWN, the actual array must
	 *              have LZMA_FILTERS_MAX + 1 members or the Block
	 *              Header decoder will overflow the buffer.
	 */
	lzma_filter *filters;

	/**
	 * \brief       Raw value stored in the Check field
	 *
	 * After successful coding, the first lzma_check_size(check) bytes
	 * of this array contain the raw value stored in the Check field.
	 *
	 * Note that CRC32 and CRC64 are stored in little endian byte order.
	 * Take it into account if you display the Check values to the user.
	 *
	 * Written by:
	 *  - lzma_block_encoder()
	 *  - lzma_block_decoder()
	 *  - lzma_block_buffer_encode()
	 *  - lzma_block_buffer_decode()
	 */
	ubyte[LZMA_CHECK_SIZE_MAX] raw_check;

	/*
	 * Reserved space to allow possible future extensions without
	 * breaking the ABI. You should not touch these, because the names
	 * of these variables may change. These are and will never be used
	 * with the currently supported options, so it is safe to leave these
	 * uninitialized.
	 */
	void *reserved_ptr1;
	void *reserved_ptr2;
	void *reserved_ptr3;
	uint reserved_int1;
	uint reserved_int2;
	lzma_vli reserved_int3;
	lzma_vli reserved_int4;
	lzma_vli reserved_int5;
	lzma_vli reserved_int6;
	lzma_vli reserved_int7;
	lzma_vli reserved_int8;
	lzma_reserved_enum reserved_enum1;
	lzma_reserved_enum reserved_enum2;
	lzma_reserved_enum reserved_enum3;
	lzma_reserved_enum reserved_enum4;
	lzma_bool reserved_bool1;
	lzma_bool reserved_bool2;
	lzma_bool reserved_bool3;
	lzma_bool reserved_bool4;
	lzma_bool reserved_bool5;
	lzma_bool reserved_bool6;
	lzma_bool reserved_bool7;
	lzma_bool reserved_bool8;
}


/**
 * \brief       Decode the Block Header Size field
 *
 * To decode Block Header using lzma_block_header_decode(), the size of the
 * Block Header has to be known and stored into lzma_block.header_size.
 * The size can be calculated from the first byte of a Block using this macro.
 * Note that if the first byte is 0x00, it indicates beginning of Index; use
 * this macro only when the byte is not 0x00.
 *
 * There is no encoding macro, because Block Header encoder is enough for that.
 */
template lzma_block_header_size_decode(uint b)
{
    enum lzma_block_header_size_decode = (b+1)*4;
}


/**
 * \brief       Calculate Block Header Size
 *
 * Calculate the minimum size needed for the Block Header field using the
 * settings specified in the lzma_block structure. Note that it is OK to
 * increase the calculated header_size value as long as it is a multiple of
 * four and doesn't exceed LZMA_BLOCK_HEADER_SIZE_MAX. Increasing header_size
 * just means that lzma_block_header_encode() will add Header Padding.
 *
 * \return      - LZMA_OK: Size calculated successfully and stored to
 *                block->header_size.
 *              - LZMA_OPTIONS_ERROR: Unsupported version, filters or
 *                filter options.
 *              - LZMA_PROG_ERROR: Invalid values like compressed_size == 0.
 *
 * \note        This doesn't check that all the options are valid i.e. this
 *              may return LZMA_OK even if lzma_block_header_encode() or
 *              lzma_block_encoder() would fail. If you want to validate the
 *              filter chain, consider using lzma_memlimit_encoder() which as
 *              a side-effect validates the filter chain.
 */
nothrow lzma_ret lzma_block_header_size(lzma_block *block);


/**
 * \brief       Encode Block Header
 *
 * The caller must have calculated the size of the Block Header already with
 * lzma_block_header_size(). If a value larger than the one calculated by
 * lzma_block_header_size() is used, the Block Header will be padded to the
 * specified size.
 *
 * \param       out         Beginning of the output buffer. This must be
 *                          at least block->header_size bytes.
 * \param       block       Block options to be encoded.
 *
 * \return      - LZMA_OK: Encoding was successful. block->header_size
 *                bytes were written to output buffer.
 *              - LZMA_OPTIONS_ERROR: Invalid or unsupported options.
 *              - LZMA_PROG_ERROR: Invalid arguments, for example
 *                block->header_size is invalid or block->filters is NULL.
 */
nothrow lzma_ret lzma_block_header_encode(const (lzma_block)* block, ubyte* out_);


/**
 * \brief       Decode Block Header
 *
 * block->version should be set to the highest value supported by the
 * application; currently the only possible version is zero. This function
 * will set version to the lowest value that still supports all the features
 * required by the Block Header.
 *
 * The size of the Block Header must have already been decoded with
 * lzma_block_header_size_decode() macro and stored to block->header_size.
 *
 * block->filters must have been allocated, but they don't need to be
 * initialized (possible existing filter options are not freed).
 *
 * \param       block       Destination for Block options.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() (and also free()
 *                          if an error occurs).
 * \param       in          Beginning of the input buffer. This must be
 *                          at least block->header_size bytes.
 *
 * \return      - LZMA_OK: Decoding was successful. block->header_size
 *                bytes were read from the input buffer.
 *              - LZMA_OPTIONS_ERROR: The Block Header specifies some
 *                unsupported options such as unsupported filters. This can
 *                happen also if block->version was set to a too low value
 *                compared to what would be required to properly represent
 *                the information stored in the Block Header.
 *              - LZMA_DATA_ERROR: Block Header is corrupt, for example,
 *                the CRC32 doesn't match.
 *              - LZMA_PROG_ERROR: Invalid arguments, for example
 *                block->header_size is invalid or block->filters is NULL.
 */
nothrow lzma_ret lzma_block_header_decode(lzma_block* block,
		lzma_allocator* allocator, const(ubyte)* in_);


/**
 * \brief       Validate and set Compressed Size according to Unpadded Size
 *
 * Block Header stores Compressed Size, but Index has Unpadded Size. If the
 * application has already parsed the Index and is now decoding Blocks,
 * it can calculate Compressed Size from Unpadded Size. This function does
 * exactly that with error checking:
 *
 *  - Compressed Size calculated from Unpadded Size must be positive integer,
 *    that is, Unpadded Size must be big enough that after Block Header and
 *    Check fields there's still at least one byte for Compressed Size.
 *
 *  - If Compressed Size was present in Block Header, the new value
 *    calculated from Unpadded Size is compared against the value
 *    from Block Header.
 *
 * \note        This function must be called _after_ decoding the Block Header
 *              field so that it can properly validate Compressed Size if it
 *              was present in Block Header.
 *
 * \return      - LZMA_OK: block->compressed_size was set successfully.
 *              - LZMA_DATA_ERROR: unpadded_size is too small compared to
 *                block->header_size and lzma_check_size(block->check).
 *              - LZMA_PROG_ERROR: Some values are invalid. For example,
 *                block->header_size must be a multiple of four and
 *                between 8 and 1024 inclusive.
 */
nothrow lzma_ret lzma_block_compressed_size(
		lzma_block* block, lzma_vli unpadded_size);


/**
 * \brief       Calculate Unpadded Size
 *
 * The Index field stores Unpadded Size and Uncompressed Size. The latter
 * can be taken directly from the lzma_block structure after coding a Block,
 * but Unpadded Size needs to be calculated from Block Header Size,
 * Compressed Size, and size of the Check field. This is where this function
 * is needed.
 *
 * \return      Unpadded Size on success, or zero on error.
 */
nothrow lzma_vli lzma_block_unpadded_size(const lzma_block* block);


/**
 * \brief       Calculate the total encoded size of a Block
 *
 * This is equivalent to lzma_block_unpadded_size() except that the returned
 * value includes the size of the Block Padding field.
 *
 * \return      On success, total encoded size of the Block. On error,
 *              zero is returned.
 */
nothrow pure lzma_vli lzma_block_total_size(const(lzma_block*) block);


/**
 * \brief       Initialize .xz Block encoder
 *
 * Valid actions for lzma_code() are LZMA_RUN, LZMA_SYNC_FLUSH (only if the
 * filter chain supports it), and LZMA_FINISH.
 *
 * \return      - LZMA_OK: All good, continue with lzma_code().
 *              - LZMA_MEM_ERROR
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_UNSUPPORTED_CHECK: block->check specifies a Check ID
 *                that is not supported by this buid of liblzma. Initializing
 *                the encoder failed.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_block_encoder(
		lzma_stream* strm, lzma_block* block);


/**
 * \brief       Initialize .xz Block decoder
 *
 * Valid actions for lzma_code() are LZMA_RUN and LZMA_FINISH. Using
 * LZMA_FINISH is not required. It is supported only for convenience.
 *
 * \return      - LZMA_OK: All good, continue with lzma_code().
 *              - LZMA_UNSUPPORTED_CHECK: Initialization was successful, but
 *                the given Check ID is not supported, thus Check will be
 *                ignored.
 *              - LZMA_PROG_ERROR
 *              - LZMA_MEM_ERROR
 */
nothrow lzma_ret lzma_block_decoder(
		lzma_stream *strm, lzma_block *block);


/**
 * \brief       Calculate maximum output size for single-call Block encoding
 *
 * This is equivalent to lzma_stream_buffer_bound() but for .xz Blocks.
 * See the documentation of lzma_stream_buffer_bound().
 */
nothrow size_t lzma_block_buffer_bound(size_t uncompressed_size);


/**
 * \brief       Single-call .xz Block encoder
 *
 * In contrast to the multi-call encoder initialized with
 * lzma_block_encoder(), this function encodes also the Block Header. This
 * is required to make it possible to write appropriate Block Header also
 * in case the data isn't compressible, and different filter chain has to be
 * used to encode the data in uncompressed form using uncompressed chunks
 * of the LZMA2 filter.
 *
 * When the data isn't compressible, header_size, compressed_size, and
 * uncompressed_size are set just like when the data was compressible, but
 * it is possible that header_size is too small to hold the filter chain
 * specified in block->filters, because that isn't necessarily the filter
 * chain that was actually used to encode the data. lzma_block_unpadded_size()
 * still works normally, because it doesn't read the filters array.
 *
 * \param       block       Block options: block->version, block->check,
 *                          and block->filters must have been initialized.
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_size     Size of the input buffer
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if encoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_BUF_ERROR: Not enough output buffer space.
 *              - LZMA_UNSUPPORTED_CHECK
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_MEM_ERROR
 *              - LZMA_DATA_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_block_buffer_encode(
		lzma_block *block, lzma_allocator *allocator,
		const(ubyte)* in_, size_t in_size,
		ubyte* out_, size_t *out_pos, size_t out_size);


/**
 * \brief       Single-call .xz Block decoder
 *
 * This is single-call equivalent of lzma_block_decoder(), and requires that
 * the caller has already decoded Block Header and checked its memory usage.
 *
 * \param       block       Block options just like with lzma_block_decoder().
 * \param       allocator   lzma_allocator for custom allocator functions.
 *                          Set to NULL to use malloc() and free().
 * \param       in          Beginning of the input buffer
 * \param       in_pos      The next byte will be read from in[*in_pos].
 *                          *in_pos is updated only if decoding succeeds.
 * \param       in_size     Size of the input buffer; the first byte that
 *                          won't be read is in[in_size].
 * \param       out         Beginning of the output buffer
 * \param       out_pos     The next byte will be written to out[*out_pos].
 *                          *out_pos is updated only if encoding succeeds.
 * \param       out_size    Size of the out buffer; the first byte into
 *                          which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Decoding was successful.
 *              - LZMA_OPTIONS_ERROR
 *              - LZMA_DATA_ERROR
 *              - LZMA_MEM_ERROR
 *              - LZMA_BUF_ERROR: Output buffer was too small.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_block_buffer_decode(
		lzma_block *block, lzma_allocator *allocator,
		const(ubyte)* in_, size_t *in_pos, size_t in_size,
		ubyte* out_, size_t *out_pos, size_t out_size);


// ////////////////////////////////////////////////////////////////////////// //
// "index.d"
/**
 * \file        lzma/index.h
 * \brief       Handling of .xz Index and related information
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.index;
//import deimos.lzma;

extern(C):

/**
 * \brief       Opaque data type to hold the Index(es) and other information
 *
 * lzma_index often holds just one .xz Index and possibly the Stream Flags
 * of the same Stream and size of the Stream Padding field. However,
 * multiple lzma_indexes can be concatenated with lzma_index_cat() and then
 * there may be information about multiple Streams in the same lzma_index.
 *
 * Notes about thread safety: Only one thread may modify lzma_index at
 * a time. All functions that take non-const pointer to lzma_index
 * modify it. As long as no thread is modifying the lzma_index, getting
 * information from the same lzma_index can be done from multiple threads
 * at the same time with functions that take a const pointer to
 * lzma_index or use lzma_index_iter. The same iterator must be used
 * only by one thread at a time, of course, but there can be as many
 * iterators for the same lzma_index as needed.
 */
struct lzma_index {};


/**
 * \brief       Iterator to get information about Blocks and Streams
 */
struct lzma_index_iter
{
	struct StreamStruct
	{
		/**
		 * \brief       Pointer to Stream Flags
		 *
		 * This is NULL if Stream Flags have not been set for
		 * this Stream with lzma_index_stream_flags().
		 */
		const lzma_stream_flags *flags;

		const void *reserved_ptr1;
		const void *reserved_ptr2;
		const void *reserved_ptr3;

		/**
		 * \brief       Stream number in the lzma_index
		 *
		 * The first Stream is 1.
		 */
		lzma_vli number;

		/**
		 * \brief       Number of Blocks in the Stream
		 *
		 * If this is zero, the block structure below has
		 * undefined values.
		 */
		lzma_vli block_count;

		/**
		 * \brief       Compressed start offset of this Stream
		 *
		 * The offset is relative to the beginning of the lzma_index
		 * (i.e. usually the beginning of the .xz file).
		 */
		lzma_vli compressed_offset;

		/**
		 * \brief       Uncompressed start offset of this Stream
		 *
		 * The offset is relative to the beginning of the lzma_index
		 * (i.e. usually the beginning of the .xz file).
		 */
		lzma_vli uncompressed_offset;

		/**
		 * \brief       Compressed size of this Stream
		 *
		 * This includes all headers except the possible
		 * Stream Padding after this Stream.
		 */
		lzma_vli compressed_size;

		/**
		 * \brief       Uncompressed size of this Stream
		 */
		lzma_vli uncompressed_size;

		/**
		 * \brief       Size of Stream Padding after this Stream
		 *
		 * If it hasn't been set with lzma_index_stream_padding(),
		 * this defaults to zero. Stream Padding is always
		 * a multiple of four bytes.
		 */
		lzma_vli padding;

		lzma_vli reserved_vli1;
		lzma_vli reserved_vli2;
		lzma_vli reserved_vli3;
		lzma_vli reserved_vli4;
	}
	StreamStruct stream;

	struct BlockStruct
	{
		/**
		 * \brief       Block number in the file
		 *
		 * The first Block is 1.
		 */
		lzma_vli number_in_file;

		/**
		 * \brief       Compressed start offset of this Block
		 *
		 * This offset is relative to the beginning of the
		 * lzma_index (i.e. usually the beginning of the .xz file).
		 * Normally this is where you should seek in the .xz file
		 * to start decompressing this Block.
		 */
		lzma_vli compressed_file_offset;

		/**
		 * \brief       Uncompressed start offset of this Block
		 *
		 * This offset is relative to the beginning of the lzma_index
		 * (i.e. usually the beginning of the .xz file).
		 *
		 * When doing random-access reading, it is possible that
		 * the target offset is not exactly at Block boundary. One
		 * will need to compare the target offset against
		 * uncompressed_file_offset or uncompressed_stream_offset,
		 * and possibly decode and throw away some amount of data
		 * before reaching the target offset.
		 */
		lzma_vli uncompressed_file_offset;

		/**
		 * \brief       Block number in this Stream
		 *
		 * The first Block is 1.
		 */
		lzma_vli number_in_stream;

		/**
		 * \brief       Compressed start offset of this Block
		 *
		 * This offset is relative to the beginning of the Stream
		 * containing this Block.
		 */
		lzma_vli compressed_stream_offset;

		/**
		 * \brief       Uncompressed start offset of this Block
		 *
		 * This offset is relative to the beginning of the Stream
		 * containing this Block.
		 */
		lzma_vli uncompressed_stream_offset;

		/**
		 * \brief       Uncompressed size of this Block
		 *
		 * You should pass this to the Block decoder if you will
		 * decode this Block. It will allow the Block decoder to
		 * validate the uncompressed size.
		 */
		lzma_vli uncompressed_size;

		/**
		 * \brief       Unpadded size of this Block
		 *
		 * You should pass this to the Block decoder if you will
		 * decode this Block. It will allow the Block decoder to
		 * validate the unpadded size.
		 */
		lzma_vli unpadded_size;

		/**
		 * \brief       Total compressed size
		 *
		 * This includes all headers and padding in this Block.
		 * This is useful if you need to know how many bytes
		 * the Block decoder will actually read.
		 */
		lzma_vli total_size;

		lzma_vli reserved_vli1;
		lzma_vli reserved_vli2;
		lzma_vli reserved_vli3;
		lzma_vli reserved_vli4;

		const void *reserved_ptr1;
		const void *reserved_ptr2;
		const void *reserved_ptr3;
		const void *reserved_ptr4;
	}
	BlockStruct block;

	/*
	 * Internal data which is used to store the state of the iterator.
	 * The exact format may vary between liblzma versions, so don't
	 * touch these in any way.
	 */
	union InternalData
	{
		const void *p;
		size_t s;
		lzma_vli v;
	}
	InternalData[6] internal;
}


/**
 * Operation mode for lzma_index_iter_next()
 */
alias lzma_index_iter_mode = uint;
enum : uint
{
	LZMA_INDEX_ITER_ANY             = 0,
		/**<
		 * \brief       Get the next Block or Stream
		 *
		 * Go to the next Block if the current Stream has at least
		 * one Block left. Otherwise go to the next Stream even if
		 * it has no Blocks. If the Stream has no Blocks
		 * (lzma_index_iter.stream.block_count == 0),
		 * lzma_index_iter.block will have undefined values.
		 */

	LZMA_INDEX_ITER_STREAM          = 1,
		/**<
		 * \brief       Get the next Stream
		 *
		 * Go to the next Stream even if the current Stream has
		 * unread Blocks left. If the next Stream has at least one
		 * Block, the iterator will point to the first Block.
		 * If there are no Blocks, lzma_index_iter.block will have
		 * undefined values.
		 */

	LZMA_INDEX_ITER_BLOCK           = 2,
		/**<
		 * \brief       Get the next Block
		 *
		 * Go to the next Block if the current Stream has at least
		 * one Block left. If the current Stream has no Blocks left,
		 * the next Stream with at least one Block is located and
		 * the iterator will be made to point to the first Block of
		 * that Stream.
		 */

	LZMA_INDEX_ITER_NONEMPTY_BLOCK  = 3

}


/**
 * \brief       Calculate memory usage of lzma_index
 *
 * On disk, the size of the Index field depends on both the number of Records
 * stored and how big values the Records store (due to variable-length integer
 * encoding). When the Index is kept in lzma_index structure, the memory usage
 * depends only on the number of Records/Blocks stored in the Index(es), and
 * in case of concatenated lzma_indexes, the number of Streams. The size in
 * RAM is almost always significantly bigger than in the encoded form on disk.
 *
 * This function calculates an approximate amount of memory needed hold
 * the given number of Streams and Blocks in lzma_index structure. This
 * value may vary between CPU architectures and also between liblzma versions
 * if the internal implementation is modified.
 */
nothrow ulong lzma_index_memusage(
		lzma_vli streams, lzma_vli blocks);


/**
 * \brief       Calculate the memory usage of an existing lzma_index
 *
 * This is a shorthand for lzma_index_memusage(lzma_index_stream_count(i),
 * lzma_index_block_count(i)).
 */
nothrow ulong lzma_index_memused(const lzma_index *i);


/**
 * \brief       Allocate and initialize a new lzma_index structure
 *
 * \return      On success, a pointer to an empty initialized lzma_index is
 *              returned. If allocation fails, NULL is returned.
 */
nothrow lzma_index* lzma_index_init(lzma_allocator *allocator);


/**
 * \brief       Deallocate lzma_index
 *
 * If i is NULL, this does nothing.
 */
nothrow void lzma_index_end(lzma_index *i, lzma_allocator *allocator);


/**
 * \brief       Add a new Block to lzma_index
 *
 * \param       i                 Pointer to a lzma_index structure
 * \param       allocator         Pointer to lzma_allocator, or NULL to
 *                                use malloc()
 * \param       unpadded_size     Unpadded Size of a Block. This can be
 *                                calculated with lzma_block_unpadded_size()
 *                                after encoding or decoding the Block.
 * \param       uncompressed_size Uncompressed Size of a Block. This can be
 *                                taken directly from lzma_block structure
 *                                after encoding or decoding the Block.
 *
 * Appending a new Block does not invalidate iterators. For example,
 * if an iterator was pointing to the end of the lzma_index, after
 * lzma_index_append() it is possible to read the next Block with
 * an existing iterator.
 *
 * \return      - LZMA_OK
 *              - LZMA_MEM_ERROR
 *              - LZMA_DATA_ERROR: Compressed or uncompressed size of the
 *                Stream or size of the Index field would grow too big.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_append(
		lzma_index *i, lzma_allocator *allocator,
		lzma_vli unpadded_size, lzma_vli uncompressed_size);


/**
 * \brief       Set the Stream Flags
 *
 * Set the Stream Flags of the last (and typically the only) Stream
 * in lzma_index. This can be useful when reading information from the
 * lzma_index, because to decode Blocks, knowing the integrity check type
 * is needed.
 *
 * The given Stream Flags are copied into internal preallocated structure
 * in the lzma_index, thus the caller doesn't need to keep the *stream_flags
 * available after calling this function.
 *
 * \return      - LZMA_OK
 *              - LZMA_OPTIONS_ERROR: Unsupported stream_flags->version.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_stream_flags(
		lzma_index *i, const lzma_stream_flags *stream_flags);


/**
 * \brief       Get the types of integrity Checks
 *
 * If lzma_index_stream_flags() is used to set the Stream Flags for
 * every Stream, lzma_index_checks() can be used to get a bitmask to
 * indicate which Check types have been used. It can be useful e.g. if
 * showing the Check types to the user.
 *
 * The bitmask is 1 << check_id, e.g. CRC32 is 1 << 1 and SHA-256 is 1 << 10.
 */
nothrow pure uint lzma_index_checks(const lzma_index *i);


/**
 * \brief       Set the amount of Stream Padding
 *
 * Set the amount of Stream Padding of the last (and typically the only)
 * Stream in the lzma_index. This is needed when planning to do random-access
 * reading within multiple concatenated Streams.
 *
 * By default, the amount of Stream Padding is assumed to be zero bytes.
 *
 * \return      - LZMA_OK
 *              - LZMA_DATA_ERROR: The file size would grow too big.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_stream_padding(
		lzma_index *i, lzma_vli stream_padding);


/**
 * \brief       Get the number of Streams
 */
nothrow pure lzma_vli lzma_index_stream_count(const lzma_index *i);


/**
 * \brief       Get the number of Blocks
 *
 * This returns the total number of Blocks in lzma_index. To get number
 * of Blocks in individual Streams, use lzma_index_iter.
 */
nothrow pure lzma_vli lzma_index_block_count(const lzma_index *i);


/**
 * \brief       Get the size of the Index field as bytes
 *
 * This is needed to verify the Backward Size field in the Stream Footer.
 */
nothrow pure lzma_vli lzma_index_size(const lzma_index *i);


/**
 * \brief       Get the total size of the Stream
 *
 * If multiple lzma_indexes have been combined, this works as if the Blocks
 * were in a single Stream. This is useful if you are going to combine
 * Blocks from multiple Streams into a single new Stream.
 */
nothrow pure lzma_vli lzma_index_stream_size(const lzma_index *i);


/**
 * \brief       Get the total size of the Blocks
 *
 * This doesn't include the Stream Header, Stream Footer, Stream Padding,
 * or Index fields.
 */
nothrow pure lzma_vli lzma_index_total_size(const lzma_index *i);


/**
 * \brief       Get the total size of the file
 *
 * When no lzma_indexes have been combined with lzma_index_cat() and there is
 * no Stream Padding, this function is identical to lzma_index_stream_size().
 * If multiple lzma_indexes have been combined, this includes also the headers
 * of each separate Stream and the possible Stream Padding fields.
 */
nothrow pure lzma_vli lzma_index_file_size(const lzma_index *i);


/**
 * \brief       Get the uncompressed size of the file
 */
nothrow pure lzma_vli lzma_index_uncompressed_size(const lzma_index *i);


/**
 * \brief       Initialize an iterator
 *
 * \param       iter    Pointer to a lzma_index_iter structure
 * \param       i       lzma_index to which the iterator will be associated
 *
 * This function associates the iterator with the given lzma_index, and calls
 * lzma_index_iter_rewind() on the iterator.
 *
 * This function doesn't allocate any memory, thus there is no
 * lzma_index_iter_end(). The iterator is valid as long as the
 * associated lzma_index is valid, that is, until lzma_index_end() or
 * using it as source in lzma_index_cat(). Specifically, lzma_index doesn't
 * become invalid if new Blocks are added to it with lzma_index_append() or
 * if it is used as the destination in lzma_index_cat().
 *
 * It is safe to make copies of an initialized lzma_index_iter, for example,
 * to easily restart reading at some particular position.
 */
nothrow void lzma_index_iter_init(
		lzma_index_iter *iter, const lzma_index *i);


/**
 * \brief       Rewind the iterator
 *
 * Rewind the iterator so that next call to lzma_index_iter_next() will
 * return the first Block or Stream.
 */
nothrow void lzma_index_iter_rewind(lzma_index_iter *iter);


/**
 * \brief       Get the next Block or Stream
 *
 * \param       iter    Iterator initialized with lzma_index_iter_init()
 * \param       mode    Specify what kind of information the caller wants
 *                      to get. See lzma_index_iter_mode for details.
 *
 * \return      If next Block or Stream matching the mode was found, *iter
 *              is updated and this function returns false. If no Block or
 *              Stream matching the mode is found, *iter is not modified
 *              and this function returns true. If mode is set to an unknown
 *              value, *iter is not modified and this function returns true.
 */
nothrow lzma_bool lzma_index_iter_next(
		lzma_index_iter *iter, lzma_index_iter_mode mode);


/**
 * \brief       Locate a Block
 *
 * If it is possible to seek in the .xz file, it is possible to parse
 * the Index field(s) and use lzma_index_iter_locate() to do random-access
 * reading with granularity of Block size.
 *
 * \param       iter    Iterator that was earlier initialized with
 *                      lzma_index_iter_init().
 * \param       target  Uncompressed target offset which the caller would
 *                      like to locate from the Stream
 *
 * If the target is smaller than the uncompressed size of the Stream (can be
 * checked with lzma_index_uncompressed_size()):
 *  - Information about the Stream and Block containing the requested
 *    uncompressed offset is stored into *iter.
 *  - Internal state of the iterator is adjusted so that
 *    lzma_index_iter_next() can be used to read subsequent Blocks or Streams.
 *  - This function returns false.
 *
 * If target is greater than the uncompressed size of the Stream, *iter
 * is not modified, and this function returns true.
 */
nothrow lzma_bool lzma_index_iter_locate(
		lzma_index_iter *iter, lzma_vli target);


/**
 * \brief       Concatenate lzma_indexes
 *
 * Concatenating lzma_indexes is useful when doing random-access reading in
 * multi-Stream .xz file, or when combining multiple Streams into single
 * Stream.
 *
 * \param       dest      lzma_index after which src is appended
 * \param       src       lzma_index to be appended after dest. If this
 *                        function succeeds, the memory allocated for src
 *                        is freed or moved to be part of dest, and all
 *                        iterators pointing to src will become invalid.
 * \param       allocator Custom memory allocator; can be NULL to use
 *                        malloc() and free().
 *
 * \return      - LZMA_OK: lzma_indexes were concatenated successfully.
 *                src is now a dangling pointer.
 *              - LZMA_DATA_ERROR: *dest would grow too big.
 *              - LZMA_MEM_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_cat(
		lzma_index *dest, lzma_index *src, lzma_allocator *allocator);


/**
 * \brief       Duplicate lzma_index
 *
 * \return      A copy of the lzma_index, or NULL if memory allocation failed.
 */
nothrow lzma_index * lzma_index_dup(
		const lzma_index *i, lzma_allocator *allocator);


/**
 * \brief       Initialize .xz Index encoder
 *
 * \param       strm        Pointer to properly prepared lzma_stream
 * \param       i           Pointer to lzma_index which should be encoded.
 *
 * The valid `action' values for lzma_code() are LZMA_RUN and LZMA_FINISH.
 * It is enough to use only one of them (you can choose freely; use LZMA_RUN
 * to support liblzma versions older than 5.0.0).
 *
 * \return      - LZMA_OK: Initialization succeeded, continue with lzma_code().
 *              - LZMA_MEM_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_encoder(
		lzma_stream *strm, const lzma_index *i);


/**
 * \brief       Initialize .xz Index decoder
 *
 * \param       strm        Pointer to properly prepared lzma_stream
 * \param       i           The decoded Index will be made available via
 *                          this pointer. Initially this function will
 *                          set *i to NULL (the old value is ignored). If
 *                          decoding succeeds (lzma_code() returns
 *                          LZMA_STREAM_END), *i will be set to point
 *                          to a new lzma_index, which the application
 *                          has to later free with lzma_index_end().
 * \param       memlimit    How much memory the resulting lzma_index is
 *                          allowed to require.
 *
 * The valid `action' values for lzma_code() are LZMA_RUN and LZMA_FINISH.
 * It is enough to use only one of them (you can choose freely; use LZMA_RUN
 * to support liblzma versions older than 5.0.0).
 *
 * \return      - LZMA_OK: Initialization succeeded, continue with lzma_code().
 *              - LZMA_MEM_ERROR
 *              - LZMA_MEMLIMIT_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_decoder(
		lzma_stream *strm, lzma_index **i, ulong memlimit);


/**
 * \brief       Single-call .xz Index encoder
 *
 * \param       i         lzma_index to be encoded
 * \param       out       Beginning of the output buffer
 * \param       out_pos   The next byte will be written to out[*out_pos].
 *                        *out_pos is updated only if encoding succeeds.
 * \param       out_size  Size of the out buffer; the first byte into
 *                        which no data is written to is out[out_size].
 *
 * \return      - LZMA_OK: Encoding was successful.
 *              - LZMA_BUF_ERROR: Output buffer is too small. Use
 *                lzma_index_size() to find out how much output
 *                space is needed.
 *              - LZMA_PROG_ERROR
 *
 * \note        This function doesn't take allocator argument since all
 *              the internal data is allocated on stack.
 */
nothrow lzma_ret lzma_index_buffer_encode(const lzma_index *i,
		ubyte *out_, size_t *out_pos, size_t out_size);


/**
 * \brief       Single-call .xz Index decoder
 *
 * \param       i           If decoding succeeds, *i will point to a new
 *                          lzma_index, which the application has to
 *                          later free with lzma_index_end(). If an error
 *                          occurs, *i will be NULL. The old value of *i
 *                          is always ignored and thus doesn't need to be
 *                          initialized by the caller.
 * \param       memlimit    Pointer to how much memory the resulting
 *                          lzma_index is allowed to require. The value
 *                          pointed by this pointer is modified if and only
 *                          if LZMA_MEMLIMIT_ERROR is returned.
 * \param       allocator   Pointer to lzma_allocator, or NULL to use malloc()
 * \param       in          Beginning of the input buffer
 * \param       in_pos      The next byte will be read from in[*in_pos].
 *                          *in_pos is updated only if decoding succeeds.
 * \param       in_size     Size of the input buffer; the first byte that
 *                          won't be read is in[in_size].
 *
 * \return      - LZMA_OK: Decoding was successful.
 *              - LZMA_MEM_ERROR
 *              - LZMA_MEMLIMIT_ERROR: Memory usage limit was reached.
 *                The minimum required memlimit value was stored to *memlimit.
 *              - LZMA_DATA_ERROR
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_buffer_decode(lzma_index **i,
		ulong *memlimit, lzma_allocator *allocator,
		const ubyte *in_, size_t *in_pos, size_t in_size);


// ////////////////////////////////////////////////////////////////////////// //
// "index_hash.d"
/**
 * \file        lzma/index_hash.h
 * \brief       Validate Index by using a hash function
 *
 * Hashing makes it possible to use constant amount of memory to validate
 * Index of arbitrary size.
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.index_hash;
//import deimos.lzma;

extern(C):

/**
 * \brief       Opaque data type to hold the Index hash
 */
struct lzma_index_hash {};


/**
 * \brief       Allocate and initialize a new lzma_index_hash structure
 *
 * If index_hash is NULL, a new lzma_index_hash structure is allocated,
 * initialized, and a pointer to it returned. If allocation fails, NULL
 * is returned.
 *
 * If index_hash is non-NULL, it is reinitialized and the same pointer
 * returned. In this case, return value cannot be NULL or a different
 * pointer than the index_hash that was given as an argument.
 */
nothrow lzma_index_hash * lzma_index_hash_init(
		lzma_index_hash *index_hash, lzma_allocator *allocator);


/**
 * \brief       Deallocate lzma_index_hash structure
 */
nothrow void lzma_index_hash_end(
		lzma_index_hash *index_hash, lzma_allocator *allocator);


/**
 * \brief       Add a new Record to an Index hash
 *
 * \param       index             Pointer to a lzma_index_hash structure
 * \param       unpadded_size     Unpadded Size of a Block
 * \param       uncompressed_size Uncompressed Size of a Block
 *
 * \return      - LZMA_OK
 *              - LZMA_DATA_ERROR: Compressed or uncompressed size of the
 *                Stream or size of the Index field would grow too big.
 *              - LZMA_PROG_ERROR: Invalid arguments or this function is being
 *                used when lzma_index_hash_decode() has already been used.
 */
nothrow lzma_ret lzma_index_hash_append(lzma_index_hash *index_hash,
		lzma_vli unpadded_size, lzma_vli uncompressed_size);


/**
 * \brief       Decode and validate the Index field
 *
 * After telling the sizes of all Blocks with lzma_index_hash_append(),
 * the actual Index field is decoded with this function. Specifically,
 * once decoding of the Index field has been started, no more Records
 * can be added using lzma_index_hash_append().
 *
 * This function doesn't use lzma_stream structure to pass the input data.
 * Instead, the input buffer is specified using three arguments. This is
 * because it matches better the internal APIs of liblzma.
 *
 * \param       index_hash      Pointer to a lzma_index_hash structure
 * \param       in              Pointer to the beginning of the input buffer
 * \param       in_pos          in[*in_pos] is the next byte to process
 * \param       in_size         in[in_size] is the first byte not to process
 *
 * \return      - LZMA_OK: So far good, but more input is needed.
 *              - LZMA_STREAM_END: Index decoded successfully and it matches
 *                the Records given with lzma_index_hash_append().
 *              - LZMA_DATA_ERROR: Index is corrupt or doesn't match the
 *                information given with lzma_index_hash_append().
 *              - LZMA_BUF_ERROR: Cannot progress because *in_pos >= in_size.
 *              - LZMA_PROG_ERROR
 */
nothrow lzma_ret lzma_index_hash_decode(lzma_index_hash *index_hash,
		const ubyte *in_, size_t *in_pos, size_t in_size);


/**
 * \brief       Get the size of the Index field as bytes
 *
 * This is needed to verify the Backward Size field in the Stream Footer.
 */
nothrow pure lzma_vli lzma_index_hash_size(
		const lzma_index_hash *index_hash);


// ////////////////////////////////////////////////////////////////////////// //
// "hardware.d"
/**
 * \file        lzma/hardware.h
 * \brief       Hardware information
 *
 * Since liblzma can consume a lot of system resources, it also provides
 * ways to limit the resource usage. Applications linking against liblzma
 * need to do the actual decisions how much resources to let liblzma to use.
 * To ease making these decisions, liblzma provides functions to find out
 * the relevant capabilities of the underlaying hardware. Currently there
 * is only a function to find out the amount of RAM, but in the future there
 * will be also a function to detect how many concurrent threads the system
 * can run.
 *
 * \note        On some operating systems, these function may temporarily
 *              load a shared library or open file descriptor(s) to find out
 *              the requested hardware information. Unless the application
 *              assumes that specific file descriptors are not touched by
 *              other threads, this should have no effect on thread safety.
 *              Possible operations involving file descriptors will restart
 *              the syscalls if they return EINTR.
 */

/*
 * Author: Lasse Collin
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 *
 * See ../lzma.h for information about liblzma as a whole.
 */

//module deimos.lzma_.hardware;
//import deimos.lzma;

extern(C):

/**
 * \brief       Get the total amount of physical memory (RAM) in bytes
 *
 * This function may be useful when determining a reasonable memory
 * usage limit for decompressing or how much memory it is OK to use
 * for compressing.
 *
 * \return      On success, the total amount of physical memory in bytes
 *              is returned. If the amount of RAM cannot be determined,
 *              zero is returned. This can happen if an error occurs
 *              or if there is no code in liblzma to detect the amount
 *              of RAM on the specific operating system.
 */
nothrow ulong lzma_physmem();
