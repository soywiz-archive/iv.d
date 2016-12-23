// based on gif.h by Charlie Tangora
// Public domain.
// Email me : ctangora -at- gmail -dot- com
//
// This file offers a simple, very limited way to create animated GIFs directly in code.
//
// Those looking for particular cleverness are likely to be disappointed; it's pretty
// much a straight-ahead implementation of the GIF format with optional Floyd-Steinberg
// dithering. (It does at least use delta encoding - only the changed portions of each
// frame are saved.)
//
// So resulting files are often quite large. The hope is that it will be handy nonetheless
// as a quick and easily-integrated way for programs to spit out animations.
//
// Only RGBA8 is currently supported as an input format. (The alpha is ignored.)
/**
 * Example:
 * ---
 *   import std.stdio;
 *   import arsd.color;
 *   import iv.gifwriter;
 *   void main () {
 *     auto tc = new TrueColorImage(100, 50);
 *     auto fo = File("zgif.gif", "w");
 *     auto gw = new GifWriter((buf) { fo.rawWrite(buf); }, tc.width, tc.height, 2);
 *     gw.writeFrame(tc);
 *     foreach (immutable n; 0..tc.width) {
 *       tc.setPixel(n, 0, Color.red);
 *       gw.writeFrame(tc);
 *     }
 *     foreach (immutable n; 1..tc.height) {
 *       tc.setPixel(tc.width-1, n, Color.green);
 *       gw.writeFrame(tc);
 *     }
 *     foreach_reverse (immutable n; 0..tc.width-1) {
 *       tc.setPixel(n, tc.height-1, Color.blue);
 *       gw.writeFrame(tc);
 *     }
 *     foreach_reverse (immutable n; 0..tc.height-1) {
 *       tc.setPixel(0, n, Color.white);
 *       gw.writeFrame(tc);
 *     }
 *     gw.finish();
 *   }
 * ---
 */
module iv.gifwriter;
private:

// ////////////////////////////////////////////////////////////////////////// //
static if (__traits(compiles, (){import arsd.color;})) {
  import arsd.color;
  enum GifWriterHasArsdColor = true;
} else {
  enum GifWriterHasArsdColor = false;
}


// ////////////////////////////////////////////////////////////////////////// //
enum kGifTransIndex = 0;

struct GifPalette {
  ubyte bitDepth;

  ubyte[256] r;
  ubyte[256] g;
  ubyte[256] b;

  // k-d tree over RGB space, organized in heap fashion
  // i.e. left child of node i is node i*2, right child is node i*2+1
  // nodes 256-511 are implicitly the leaves, containing a color
  ubyte[256] treeSplitElt;
  ubyte[256] treeSplit;
}

// max, min, and abs functions
int gifIMax() (int l, int r) { pragma(inline, true); return (l > r ? l : r); }
int gifIMin() (int l, int r) { pragma(inline, true); return (l < r ? l : r); }
int gifIAbs() (int i) { pragma(inline, true); return (i < 0 ? -i : i); }

// walks the k-d tree to pick the palette entry for a desired color.
// Takes as in/out parameters the current best color and its error -
// only changes them if it finds a better color in its subtree.
// this is the major hotspot in the code at the moment.
void gifGetClosestPaletteColor (GifPalette* pPal, int r, int g, int b, ref int bestInd, ref int bestDiff, int treeRoot=1) {
  // base case, reached the bottom of the tree
  if (treeRoot > (1<<pPal.bitDepth)-1) {
    int ind = treeRoot-(1<<pPal.bitDepth);
    if (ind == kGifTransIndex) return;
    // check whether this color is better than the current winner
    int r_err = r-(cast(int)pPal.r.ptr[ind]);
    int g_err = g-(cast(int)pPal.g.ptr[ind]);
    int b_err = b-(cast(int)pPal.b.ptr[ind]);
    int diff = gifIAbs(r_err)+gifIAbs(g_err)+gifIAbs(b_err);
    if (diff < bestDiff) {
      bestInd = ind;
      bestDiff = diff;
    }
    return;
  }
  // take the appropriate color (r, g, or b) for this node of the k-d tree
  int[3] comps = void;
  comps[0] = r;
  comps[1] = g;
  comps[2] = b;
  int splitComp = comps[pPal.treeSplitElt.ptr[treeRoot]];

  int splitPos = pPal.treeSplit.ptr[treeRoot];
  if (splitPos > splitComp) {
    // check the left subtree
    gifGetClosestPaletteColor(pPal, r, g, b, bestInd, bestDiff, treeRoot*2);
    if (bestDiff > splitPos-splitComp) {
      // cannot prove there's not a better value in the right subtree, check that too
      gifGetClosestPaletteColor(pPal, r, g, b, bestInd, bestDiff, treeRoot*2+1);
    }
  } else {
    gifGetClosestPaletteColor(pPal, r, g, b, bestInd, bestDiff, treeRoot*2+1);
    if (bestDiff > splitComp-splitPos) {
      gifGetClosestPaletteColor(pPal, r, g, b, bestInd, bestDiff, treeRoot*2);
    }
  }
}


void gifSwapPixels (ubyte* image, int pixA, int pixB) {
  ubyte rA = image[pixA*4];
  ubyte gA = image[pixA*4+1];
  ubyte bA = image[pixA*4+2];
  ubyte aA = image[pixA*4+3];

  ubyte rB = image[pixB*4];
  ubyte gB = image[pixB*4+1];
  ubyte bB = image[pixB*4+2];
  ubyte aB = image[pixA*4+3];

  image[pixA*4] = rB;
  image[pixA*4+1] = gB;
  image[pixA*4+2] = bB;
  image[pixA*4+3] = aB;

  image[pixB*4] = rA;
  image[pixB*4+1] = gA;
  image[pixB*4+2] = bA;
  image[pixB*4+3] = aA;
}


// just the partition operation from quicksort
int gifPartition (ubyte* image, in int left, in int right, in int elt, int pivotIndex) {
  immutable int pivotValue = image[(pivotIndex)*4+elt];
  gifSwapPixels(image, pivotIndex, right-1);
  int storeIndex = left;
  bool split = 0;
  for (int ii = left; ii < right-1; ++ii) {
    int arrayVal = image[ii*4+elt];
    if (arrayVal < pivotValue) {
      gifSwapPixels(image, ii, storeIndex);
      ++storeIndex;
    } else if (arrayVal == pivotValue) {
      if (split) {
        gifSwapPixels(image, ii, storeIndex);
        ++storeIndex;
      }
      split = !split;
    }
  }
  gifSwapPixels(image, storeIndex, right-1);
  return storeIndex;
}


// perform an incomplete sort, finding all elements above and below the desired median
void gifPartitionByMedian (ubyte* image, int left, int right, int com, int neededCenter) {
  if (left < right-1) {
    int pivotIndex = left+(right-left)/2;
    pivotIndex = gifPartition(image, left, right, com, pivotIndex);
    // only "sort" the section of the array that contains the median
    if (pivotIndex > neededCenter) gifPartitionByMedian(image, left, pivotIndex, com, neededCenter);
    if (pivotIndex < neededCenter) gifPartitionByMedian(image, pivotIndex+1, right, com, neededCenter);
  }
}


// builds a palette by creating a balanced k-d tree of all pixels in the image
void gifSplitPalette (ubyte* image, int numPixels, int firstElt, int lastElt, int splitElt, int splitDist, int treeNode, bool buildForDither, GifPalette* pal) {
  if (lastElt <= firstElt || numPixels == 0) return;
  // base case, bottom of the tree
  if (lastElt == firstElt+1) {
    if (buildForDither) {
      // dithering needs at least one color as dark as anything in the image and at least one brightest color
      // otherwise it builds up error and produces strange artifacts
      if (firstElt == 1) {
        // special case: the darkest color in the image
        uint r = 255, g = 255, b = 255;
        for (int ii = 0; ii < numPixels; ++ii) {
           r = gifIMin(r, image[ii*4+0]);
           g = gifIMin(g, image[ii*4+1]);
           b = gifIMin(b, image[ii*4+2]);
        }
        pal.r.ptr[firstElt] = cast(ubyte)r;
        pal.g.ptr[firstElt] = cast(ubyte)g;
        pal.b.ptr[firstElt] = cast(ubyte)b;
        return;
      }
      if (firstElt == (1<<pal.bitDepth)-1) {
        // special case: the lightest color in the image
        uint r = 0, g = 0, b = 0;
        for (int ii = 0; ii < numPixels; ++ii) {
          r = gifIMax(r, image[ii*4+0]);
          g = gifIMax(g, image[ii*4+1]);
          b = gifIMax(b, image[ii*4+2]);
        }
        pal.r.ptr[firstElt] = cast(ubyte)r;
        pal.g.ptr[firstElt] = cast(ubyte)g;
        pal.b.ptr[firstElt] = cast(ubyte)b;
        return;
      }
    }

    // otherwise, take the average of all colors in this subcube
    ulong r = 0, g = 0, b = 0;
    for (int ii = 0; ii < numPixels; ++ii) {
      r += image[ii*4+0];
      g += image[ii*4+1];
      b += image[ii*4+2];
    }

    r += numPixels/2; // round to nearest
    g += numPixels/2;
    b += numPixels/2;

    r /= numPixels;
    g /= numPixels;
    b /= numPixels;

    pal.r.ptr[firstElt] = cast(ubyte)r;
    pal.g.ptr[firstElt] = cast(ubyte)g;
    pal.b.ptr[firstElt] = cast(ubyte)b;

    return;
  }

  // find the axis with the largest range
  int minR = 255, maxR = 0;
  int minG = 255, maxG = 0;
  int minB = 255, maxB = 0;
  for (int ii = 0; ii < numPixels; ++ii) {
    int r = image[ii*4+0];
    int g = image[ii*4+1];
    int b = image[ii*4+2];
    if (r > maxR) maxR = r;
    if (r < minR) minR = r;
    if (g > maxG) maxG = g;
    if (g < minG) minG = g;
    if (b > maxB) maxB = b;
    if (b < minB) minB = b;
  }

  int rRange = maxR-minR;
  int gRange = maxG-minG;
  int bRange = maxB-minB;

  // and split along that axis. (incidentally, this means this isn't a "proper" k-d tree but I don't know what else to call it)
  int splitCom = 1;
  if (bRange > gRange) splitCom = 2;
  if (rRange > bRange && rRange > gRange) splitCom = 0;

  int subPixelsA = numPixels*(splitElt-firstElt)/(lastElt-firstElt);
  int subPixelsB = numPixels-subPixelsA;

  gifPartitionByMedian(image, 0, numPixels, splitCom, subPixelsA);

  pal.treeSplitElt.ptr[treeNode] = cast(ubyte)splitCom;
  pal.treeSplit.ptr[treeNode] = image[subPixelsA*4+splitCom];

  gifSplitPalette(image,              subPixelsA, firstElt, splitElt, splitElt-splitDist, splitDist/2, treeNode*2,   buildForDither, pal);
  gifSplitPalette(image+subPixelsA*4, subPixelsB, splitElt, lastElt,  splitElt+splitDist, splitDist/2, treeNode*2+1, buildForDither, pal);
}


// Finds all pixels that have changed from the previous image and
// moves them to the fromt of th buffer.
// This allows us to build a palette optimized for the colors of the
// changed pixels only.
int gifPickChangedPixels (const(ubyte)* lastFrame, ubyte* frame, int numPixels) {
  int numChanged = 0;
  ubyte* writeIter = frame;
  for (int ii = 0; ii < numPixels; ++ii) {
    if (lastFrame[0] != frame[0] || lastFrame[1] != frame[1] || lastFrame[2] != frame[2]) {
      writeIter[0] = frame[0];
      writeIter[1] = frame[1];
      writeIter[2] = frame[2];
      ++numChanged;
      writeIter += 4;
    }
    lastFrame += 4;
    frame += 4;
  }
  return numChanged;
}


// Creates a palette by placing all the image pixels in a k-d tree and then averaging the blocks at the bottom.
// This is known as the "modified median split" technique
void gifMakePalette (const(ubyte)* lastFrame, const(ubyte)* nextFrame, uint width, uint height, ubyte bitDepth, bool buildForDither, GifPalette* pPal) {
  import core.stdc.stdlib : malloc, free;
  import core.stdc.string : memcpy;

  pPal.bitDepth = bitDepth;

  // SplitPalette is destructive (it sorts the pixels by color) so
  // we must create a copy of the image for it to destroy
  int imageSize = width*height*4*cast(int)ubyte.sizeof;
  ubyte* destroyableImage = cast(ubyte*)malloc(imageSize);
  if (destroyableImage is null) assert(0, "out of memory");
  scope(exit) free(destroyableImage);
  memcpy(destroyableImage, nextFrame, imageSize);

  int numPixels = width*height;
  if (lastFrame) numPixels = gifPickChangedPixels(lastFrame, destroyableImage, numPixels);

  immutable int lastElt = 1<<bitDepth;
  immutable int splitElt = lastElt/2;
  immutable int splitDist = splitElt/2;

  gifSplitPalette(destroyableImage, numPixels, 1, lastElt, splitElt, splitDist, 1, buildForDither, pPal);

  //GIF_TEMP_FREE(destroyableImage);

  // add the bottom node for the transparency index
  pPal.treeSplit.ptr[1<<(bitDepth-1)] = 0;
  pPal.treeSplitElt.ptr[1<<(bitDepth-1)] = 0;

  pPal.r.ptr[0] = pPal.g.ptr[0] = pPal.b.ptr[0] = 0;
}


// Implements Floyd-Steinberg dithering, writes palette value to alpha
void gifDitherImage (const(ubyte)* lastFrame, const(ubyte)* nextFrame, ubyte* outFrame, uint width, uint height, GifPalette* pPal) {
  import core.stdc.stdlib : malloc, free;
  int numPixels = width*height;

  // quantPixels initially holds color*256 for all pixels
  // The extra 8 bits of precision allow for sub-single-color error values
  // to be propagated
  int* quantPixels = cast(int*)malloc(int.sizeof*numPixels*4);
  if (quantPixels is null) assert(0, "out of memory");
  scope(exit) free(quantPixels);

  for (int ii = 0; ii < numPixels*4; ++ii) {
    ubyte pix = nextFrame[ii];
    int pix16 = int(pix)*256;
    quantPixels[ii] = pix16;
  }

  for (uint yy = 0; yy < height; ++yy) {
    for (uint xx = 0; xx < width; ++xx) {
      int* nextPix = quantPixels+4*(yy*width+xx);
      const(ubyte)* lastPix = (lastFrame ? lastFrame+4*(yy*width+xx) : null);

      // Compute the colors we want (rounding to nearest)
      int rr = (nextPix[0]+127)/256;
      int gg = (nextPix[1]+127)/256;
      int bb = (nextPix[2]+127)/256;

      // if it happens that we want the color from last frame, then just write out a transparent pixel
      if (lastFrame && lastPix[0] == rr && lastPix[1] == gg && lastPix[2] == bb) {
        nextPix[0] = rr;
        nextPix[1] = gg;
        nextPix[2] = bb;
        nextPix[3] = kGifTransIndex;
        continue;
      }

      int bestDiff = 1000000;
      int bestInd = kGifTransIndex;

      // Search the palete
      gifGetClosestPaletteColor(pPal, rr, gg, bb, bestInd, bestDiff);

      // Write the result to the temp buffer
      int r_err = nextPix[0]-cast(int)(pPal.r.ptr[bestInd])*256;
      int g_err = nextPix[1]-cast(int)(pPal.g.ptr[bestInd])*256;
      int b_err = nextPix[2]-cast(int)(pPal.b.ptr[bestInd])*256;

      nextPix[0] = pPal.r.ptr[bestInd];
      nextPix[1] = pPal.g.ptr[bestInd];
      nextPix[2] = pPal.b.ptr[bestInd];
      nextPix[3] = bestInd;

      // Propagate the error to the four adjacent locations
      // that we haven't touched yet
      int quantloc_7 = (yy*width+xx+1);
      int quantloc_3 = (yy*width+width+xx-1);
      int quantloc_5 = (yy*width+width+xx);
      int quantloc_1 = (yy*width+width+xx+1);

      if (quantloc_7 < numPixels) {
        int* pix7 = quantPixels+4*quantloc_7;
        pix7[0] += gifIMax(-pix7[0], r_err*7/16);
        pix7[1] += gifIMax(-pix7[1], g_err*7/16);
        pix7[2] += gifIMax(-pix7[2], b_err*7/16);
      }

      if (quantloc_3 < numPixels) {
        int* pix3 = quantPixels+4*quantloc_3;
        pix3[0] += gifIMax(-pix3[0], r_err*3/16);
        pix3[1] += gifIMax(-pix3[1], g_err*3/16);
        pix3[2] += gifIMax(-pix3[2], b_err*3/16);
      }

      if (quantloc_5 < numPixels) {
        int* pix5 = quantPixels+4*quantloc_5;
        pix5[0] += gifIMax(-pix5[0], r_err*5/16);
        pix5[1] += gifIMax(-pix5[1], g_err*5/16);
        pix5[2] += gifIMax(-pix5[2], b_err*5/16);
      }

      if (quantloc_1 < numPixels) {
        int* pix1 = quantPixels+4*quantloc_1;
        pix1[0] += gifIMax(-pix1[0], r_err/16);
        pix1[1] += gifIMax(-pix1[1], g_err/16);
        pix1[2] += gifIMax(-pix1[2], b_err/16);
      }
    }
  }

  // Copy the palettized result to the output buffer
  for (int ii = 0; ii < numPixels*4; ++ii) outFrame[ii] = cast(ubyte)quantPixels[ii];
  //outFrame[0..numPixels*4] = quantPixels[0..numPixels*4];
}


// Picks palette colors for the image using simple thresholding, no dithering
void gifThresholdImage (const(ubyte)* lastFrame, const(ubyte)* nextFrame, ubyte* outFrame, uint width, uint height, GifPalette* pPal) {
  uint numPixels = width*height;
  for (uint ii = 0; ii < numPixels; ++ii) {
    // if a previous color is available, and it matches the current color, set the pixel to transparent
    if (lastFrame && lastFrame[0] == nextFrame[0] && lastFrame[1] == nextFrame[1] && lastFrame[2] == nextFrame[2]) {
      outFrame[0] = lastFrame[0];
      outFrame[1] = lastFrame[1];
      outFrame[2] = lastFrame[2];
      outFrame[3] = kGifTransIndex;
    } else {
      // palettize the pixel
      int bestDiff = 1000000;
      int bestInd = 1;
      gifGetClosestPaletteColor(pPal, nextFrame[0], nextFrame[1], nextFrame[2], bestInd, bestDiff);
      // Write the resulting color to the output buffer
      outFrame[0] = pPal.r.ptr[bestInd];
      outFrame[1] = pPal.g.ptr[bestInd];
      outFrame[2] = pPal.b.ptr[bestInd];
      outFrame[3] = cast(ubyte)bestInd;
    }
    if (lastFrame) lastFrame += 4;
    outFrame += 4;
    nextFrame += 4;
  }
}


// Simple structure to write out the LZW-compressed portion of the image
// one bit at a time
struct gifBitStatus {
  ubyte bitIndex;  // how many bits in the partial byte written so far
  ubyte bytev;      // current partial byte
  uint chunkIndex;
  ubyte[256] chunk;   // bytes are written in here until we have 256 of them, then written to the file
}


// insert a single bit
void gifWriteBit (ref gifBitStatus stat, uint bit) {
  bit = bit&1;
  bit = bit<<stat.bitIndex;
  stat.bytev |= bit;
  ++stat.bitIndex;
  if (stat.bitIndex > 7) {
    // move the newly-finished byte to the chunk buffer
    stat.chunk[stat.chunkIndex++] = stat.bytev;
    // and start a new byte
    stat.bitIndex = 0;
    stat.bytev = 0;
  }
}


// write all bytes so far to the file
void gifWriteChunk (GifWriter.WriterCB wr, ref gifBitStatus stat) {
  ubyte[1] b = cast(ubyte)stat.chunkIndex;
  wr(b[]);
  wr(stat.chunk[0..stat.chunkIndex]);
  stat.bitIndex = 0;
  stat.bytev = 0;
  stat.chunkIndex = 0;
}


void gifWriteCode (GifWriter.WriterCB wr, ref gifBitStatus stat, uint code, uint length) {
  for (uint ii = 0; ii < length; ++ii) {
    gifWriteBit(stat, code);
    code = code>>1;
    if (stat.chunkIndex == 255) gifWriteChunk(wr, stat);
  }
}


// The LZW dictionary is a 256-ary tree constructed as the file is encoded, this is one node
struct gifLzwNode {
  ushort[256] m_next;
}


// write a 256-color (8-bit) image palette to the file
void gifWritePalette (const(GifPalette)* pPal, GifWriter.WriterCB wr) {
  // first color: transparency
  int ii;
  ubyte[256*3] b = 0;
  assert(pPal.bitDepth <= 8);
  for (ii = 1; ii < (1<<pPal.bitDepth); ++ii) {
    b.ptr[ii*3+0] = cast(ubyte)pPal.r.ptr[ii];
    b.ptr[ii*3+1] = cast(ubyte)pPal.g.ptr[ii];
    b.ptr[ii*3+2] = cast(ubyte)pPal.b.ptr[ii];
  }
  wr(b[0..ii*3]);
}


// write the image header, LZW-compress and write out the image
void gifWriteLzwImage (GifWriter.WriterCB wr, gifLzwNode* codetree, ubyte* image, uint left, uint top,  uint width, uint height, uint delay, GifPalette* pPal) {
  //import core.stdc.stdlib : malloc, free;
  import core.stdc.string : memset;

  void writeByte (ubyte b) { wr((&b)[0..1]); }

  // graphics control extension
  writeByte(cast(ubyte)(0x21));
  writeByte(cast(ubyte)(0xf9));
  writeByte(cast(ubyte)(0x04));
  writeByte(cast(ubyte)(0x05)); // leave prev frame in place, this frame has transparency
  writeByte(cast(ubyte)(delay&0xff));
  writeByte(cast(ubyte)((delay>>8)&0xff));
  writeByte(cast(ubyte)(kGifTransIndex)); // transparent color index
  writeByte(cast(ubyte)(0));

  writeByte(cast(ubyte)(0x2c)); // image descriptor block

  writeByte(cast(ubyte)(left&0xff));           // corner of image in canvas space
  writeByte(cast(ubyte)((left>>8)&0xff));
  writeByte(cast(ubyte)(top&0xff));
  writeByte(cast(ubyte)((top>>8)&0xff));

  writeByte(cast(ubyte)(width&0xff));          // width and height of image
  writeByte(cast(ubyte)((width>>8)&0xff));
  writeByte(cast(ubyte)(height&0xff));
  writeByte(cast(ubyte)((height>>8)&0xff));

  //writeByte(cast(ubyte)(0)); // no local color table, no transparency
  //writeByte(cast(ubyte)(0x80)); // no local color table, but transparency

  writeByte(cast(ubyte)(0x80+pPal.bitDepth-1)); // local color table present, 2^bitDepth entries
  gifWritePalette(pPal, wr);

  immutable int minCodeSize = pPal.bitDepth;
  immutable uint clearCode = 1<<pPal.bitDepth;

  writeByte(cast(ubyte)(minCodeSize)); // min code size 8 bits

  //gifLzwNode* codetree = cast(gifLzwNode*)malloc(gifLzwNode.sizeof*4096);
  //if (codetree is null) assert(0, "out of memory");
  //scope(exit) free(codetree);

  memset(codetree, 0, gifLzwNode.sizeof*4096);
  int curCode = -1;
  uint codeSize = minCodeSize+1;
  uint maxCode = clearCode+1;

  gifBitStatus stat;
  stat.bytev = 0;
  stat.bitIndex = 0;
  stat.chunkIndex = 0;

  gifWriteCode(wr, stat, clearCode, codeSize);  // start with a fresh LZW dictionary

  bool fixCodeSize () {
    if (maxCode >= (1U<<codeSize)) {
      // dictionary entry count has broken a size barrier, we need more bits for codes
      ++codeSize;
    }
    if (maxCode == 4095) {
      // the dictionary is full, clear it out and begin anew
      gifWriteCode(wr, stat, clearCode, codeSize); // clear tree
      memset(codetree, 0, gifLzwNode.sizeof*4096);
      curCode = -1;
      codeSize = minCodeSize+1;
      maxCode = clearCode+1;
      return true;
    }
    return false;
  }

  for (uint yy = 0; yy < height; ++yy) {
    for (uint xx = 0; xx < width; ++xx) {
      ubyte nextValue = image[(yy*width+xx)*4+3];

      // "loser mode" - no compression, every single code is followed immediately by a clear
      //WriteCode( f, stat, nextValue, codeSize );
      //WriteCode( f, stat, 256, codeSize );

      if (curCode < 0) {
        // first value in a new run
        curCode = nextValue;
      } else if (codetree[curCode].m_next[nextValue]) {
        // current run already in the dictionary
        curCode = codetree[curCode].m_next[nextValue];
      } else {
        // finish the current run, write a code
        gifWriteCode(wr, stat, curCode, codeSize);
        // insert the new run into the dictionary
        codetree[curCode].m_next[nextValue] = cast(ushort)(++maxCode);
        fixCodeSize();
        curCode = nextValue;
      }
    }
  }

  // compression footer
  gifWriteCode(wr, stat, curCode, codeSize);
  ++maxCode;
  if (!fixCodeSize()) gifWriteCode(wr, stat, clearCode, codeSize);
  gifWriteCode(wr, stat, clearCode+1, minCodeSize+1);

  // write out the last partial chunk
  while (stat.bitIndex) gifWriteBit(stat, 0);
  if (stat.chunkIndex) gifWriteChunk(wr, stat);

  writeByte(cast(ubyte)(0)); // image block terminator
}


// ////////////////////////////////////////////////////////////////////////// //
/// gif writer class
public final class GifWriter {
public:
  alias WriterCB = void delegate (const(ubyte)[] buf); /// buffer writer

private:
  WriterCB writeBytes;
  ubyte[] oldImage;
  bool firstFrame;
  bool errored;
  bool finished;
  ubyte origBitDepth;
  bool origDither;
  uint origW, origH;
  uint origDelay;
  gifLzwNode[4096] codetree;
  GifPalette pal;

public:
  /** Creates a gif writer.
   *
   * The delay value is the time between frames in hundredths of a second.
   * Note that not all viewers pay much attention to this value.
   *
   * USAGE:
   * Create a GifWriter class. Pass subsequent frames to writeFrame().
   * Finally, call finish() to close the file handle and free memory.
   *
   * Params:
   *   writeBytesCB = file write delegate; should write the whole buffer or throw; will never be called with zero-length buffer
   *   width = maximum picture width
   *   height = maximum picture height
   *   delay = delay between frames, in 1/100 of second
   *   bitDepth = resulting image bit depth; [1..8]
   *   dither = dither resulting image (image may or may not look better when dithered ;-)
   */
  this (WriterCB writeBytesCB, uint width, uint height, uint delay, ubyte bitDepth=8, bool dither=false) {
    if (writeBytesCB is null) throw new Exception("no write delegate");
    if (width < 1 || height < 1 || width > 16383 || height > 16383) throw new Exception("invalid dimensions");
    if (bitDepth < 1 || bitDepth > 8) throw new Exception("invalid bit depth");
    writeBytes = writeBytesCB;
    origBitDepth = bitDepth;
    origDither = dither;
    origW = width;
    origH = height;
    origDelay = delay;
    scope(failure) errored = true;
    setup(width, height, delay, bitDepth, dither);
  }

  /** Writes out a new frame to a GIF in progress.
   *
   * Params:
   *   image = frame RGBA data, width*height*4 bytes
   *   delay = delay between frames, in 1/100 of second
   *   width = frame width
   *   height = frame height
   */
  void writeFrame (const(void)[] image, uint delay=uint.max, uint width=0, uint height=0) {
    if (errored) throw new Exception("error writing gif data");
    if (finished) throw new Exception("can't add frame to finished gif");
    if (width == 0) width = origW;
    if (height == 0) height = origH;
    if (delay == uint.max) delay = origDelay;
    if (image.length < width*height*4) throw new Exception("image buffer too small");
    scope(failure) errored = true;
    const(ubyte)* oldImg = (firstFrame ? null : oldImage.ptr);
    firstFrame = false;
    gifMakePalette((origDither ? null : oldImg), cast(const(ubyte)*)image.ptr, width, height, origBitDepth, origDither, &pal);
    if (origDither) {
      gifDitherImage(oldImg, cast(const(ubyte)*)image.ptr, oldImage.ptr, width, height, &pal);
    } else {
      gifThresholdImage(oldImg, cast(const(ubyte)*)image.ptr, oldImage.ptr, width, height, &pal);
    }
    gifWriteLzwImage(writeBytes, codetree.ptr, oldImage.ptr, 0, 0, width, height, delay, &pal);
  }

  static if (GifWriterHasArsdColor) {
    /** Writes out a new frame to a GIF in progress.
     *
     * Params:
     *   mimage = frame data, width*height pixels
     *   delay = delay between frames, in 1/100 of second
     */
    void writeFrame() (MemoryImage mimage, uint delay=uint.max) {
      if (errored) throw new Exception("error writing gif data");
      if (finished) throw new Exception("can't add frame to finished gif");
      if (mimage is null || mimage.width < 1 || mimage.height < 1) return;
      if (mimage.width != origW || mimage.height != origH) throw new Exception("invalid image dimensions");
      if (delay == uint.max) delay = origDelay;
      scope(failure) errored = true;
      auto tcimg = mimage.getAsTrueColorImage();
      writeFrame(tcimg.imageData.bytes, delay, 0, 0);
    }
  }

  /** Writes the EOF code.
   *
   * Many if not most viewers will still display a GIF properly if the EOF code is missing,
   * but it's still a good idea to write it out.
   */
  void finish () {
    if (errored) throw new Exception("error writing gif data");
    if (finished) throw new Exception("can't finish finished gif");
    scope(failure) errored = true;
    writeByte(0x3b); // end of file
    oldImage = null;
    finished = true;
  }

  /** Flips image data vertically.
   *
   * This can be used to flip result of `glReadPixels()`, for example.
   *
   * Params:
   *   img = frame RGBA data, width*height*4 bytes
   *   width = frame width
   *   height = frame height
   */
  static void flipY (void[] img, uint width, uint height) {
    if (width < 1 || height < 1) return;
    if (img.length < width*height*4) throw new Exception("image buffer too small");
    uint spos = 0;
    uint dpos = (height-1)*(width*4);
    auto image = cast(ubyte*)img.ptr;
    foreach (immutable y; 0..height/2) {
      foreach (immutable x; 0..width*4) {
        ubyte t = image[spos+x];
        image[spos+x] = image[dpos+x];
        image[dpos+x] = t;
      }
      spos += width*4;
      dpos -= width*4;
    }
  }

private:
  void writeByte (ubyte b) { writeBytes((&b)[0..1]); }
  void writeBuf (const(void)[] buf) { if (buf.length) writeBytes(cast(const(ubyte)[])buf); }

  void setup (uint width, uint height, uint delay, ubyte bitDepth, bool dither) {
    firstFrame = true;

    // allocate
    oldImage.length = width*height*4;

    writeBuf("GIF89a");

    // screen descriptor
    writeByte(cast(ubyte)(width&0xff));
    writeByte(cast(ubyte)((width>>8)&0xff));
    writeByte(cast(ubyte)(height&0xff));
    writeByte(cast(ubyte)((height>>8)&0xff));

    writeByte(cast(ubyte)(0xf0)); // there is an unsorted global color table of 2 entries
    writeByte(cast(ubyte)(0));    // background color
    writeByte(cast(ubyte)(0));    // pixels are square (we need to specify this because it's 1989)

    // now the "global" palette (really just a dummy palette)
    // color 0: black
    writeByte(cast(ubyte)(0));
    writeByte(cast(ubyte)(0));
    writeByte(cast(ubyte)(0));
    // color 1: also black
    writeByte(cast(ubyte)(0));
    writeByte(cast(ubyte)(0));
    writeByte(cast(ubyte)(0));

    if (delay != 0) {
      // animation header
      writeByte(cast(ubyte)(0x21)); // extension
      writeByte(cast(ubyte)(0xff)); // application specific
      writeByte(cast(ubyte)(11)); // length 11
      writeBuf("NETSCAPE2.0"); // yes, really
      writeByte(cast(ubyte)(3)); // 3 bytes of NETSCAPE2.0 data

      writeByte(cast(ubyte)(1)); // JUST BECAUSE
      writeByte(cast(ubyte)(0)); // loop infinitely (byte 0)
      writeByte(cast(ubyte)(0)); // loop infinitely (byte 1)

      writeByte(cast(ubyte)(0)); // block terminator
    }
  }
}
