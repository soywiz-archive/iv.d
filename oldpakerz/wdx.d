/*
 * original code: WDOSX-Pack v1.07, (c) 1999-2001 by Joergen Ibsen / Jibz
 * for data and executable compression software: http://www.ibsensoftware.com/
 */
module iv.oldpakerz.wdx /*is aliced*/;
private:
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
enum WDXUNPACK_LEN2_LIMIT = 1920;


public usize wdx_packbuf_size (usize size_in) {
  if (size_in < 1) return 0;
  return size_in+((size_in+7)/8)+2;
}


struct match_t {
  uint pos;
  uint len;
}


struct pack_state_t {
  uint next_back_entry;
  ubyte *tag_byte;
  int bit_count;
  uint *back_tbl; /* back-table, array */
  const(ubyte)* bufin, srcofs, backptr;
  ubyte *bufout;
  uint *lookup; /* lookup-table [256][256] */
  uint last_match_pos;
  int last_was_match;
  uint bytes_out;
  usize size_out;
}


void wdxi_adv_tag_byte (pack_state_t *ps, uint bit) {
  /* check bitcount and then decrement */
  if (ps.bit_count-- == 0) {
    if (ps.size_out-- == 0) throw new Exception("wdx error");
    ps.bit_count = 7;
    ps.tag_byte = ps.bufout++;
    *ps.tag_byte = 0;
    ++ps.bytes_out;
  }
  /* shift in bit */
  *ps.tag_byte = cast(ubyte)(((*ps.tag_byte)<<1)|(bit ? 1 : 0));
}


/* output Gamma2-code for val in range [2..?] ... */
void wdxi_out_gamma (pack_state_t *ps, uint val) {
  uint invertlen = 0, invert = 0;
  /* rotate bits into invert (except last) */
  do {
    invert = (invert<<1)|(val&0x01);
    ++invertlen;
    val = (val>>1)&0x7FFFFFFF;
  } while (val > 1);
  /* output Gamma2-encoded bits */
  for (--invertlen; invertlen > 0; --invertlen) {
    wdxi_adv_tag_byte(ps, invert&0x01);
    wdxi_adv_tag_byte(ps, 1);
    invert >>= 1;
  }
  wdxi_adv_tag_byte(ps, invert&0x01);
  wdxi_adv_tag_byte(ps, 0);
}


void wdxi_out_lit (pack_state_t *ps, ubyte lit) {
  ps.last_was_match = 0;
  wdxi_adv_tag_byte(ps, 0); /* 0 indicates a literal */
  if (ps.size_out-- == 0) throw new Exception("wdx error");
  *ps.bufout++ = lit; /* output the literal */
  ++ps.bytes_out;
}


void wdxi_out_pair (pack_state_t *ps, uint pos, uint len, const ubyte *buffer) {
  /* if we just had a match, don't use ps.last_match_pos */
  if (ps.last_was_match) {
    /* if a short match is too far away, encode it as two literals instead */
    if (pos > WDXUNPACK_LEN2_LIMIT && len == 2) {
      wdxi_out_lit(ps, buffer[0]);
      wdxi_out_lit(ps, buffer[1]);
    } else {
      wdxi_adv_tag_byte(ps, 1); /* 1 indicates a match */
      /* a match more than WDXUNPACK_LEN2_LIMIT bytes back will be longer than 2 */
      if (pos > WDXUNPACK_LEN2_LIMIT) --len;
      wdxi_out_gamma(ps, len); /* output length */
      ps.last_match_pos = pos--;
      /*assert(pos >= 0);*/
      wdxi_out_gamma(ps, ((pos>>6)&0x3FFFFFFF)+2); /* output high part of position */
      /* output low 6 bits of position */
      wdxi_adv_tag_byte(ps, pos&0x20);
      wdxi_adv_tag_byte(ps, pos&0x10);
      wdxi_adv_tag_byte(ps, pos&0x08);
      wdxi_adv_tag_byte(ps, pos&0x04);
      wdxi_adv_tag_byte(ps, pos&0x02);
      wdxi_adv_tag_byte(ps, pos&0x01);
    }
  } else {
    ps.last_was_match = 1;
    /* if a short match is too far away, encode it as two literals instead */
    if (pos > WDXUNPACK_LEN2_LIMIT && len == 2 && pos != ps.last_match_pos) {
      wdxi_out_lit(ps, buffer[0]);
      wdxi_out_lit(ps, buffer[1]);
    } else {
      wdxi_adv_tag_byte(ps, 1); /* 1 indicates a match */
      /* a match more than WDXUNPACK_LEN2_LIMIT bytes back will be longer than 2 */
      if (pos > WDXUNPACK_LEN2_LIMIT && pos != ps.last_match_pos) --len;
      wdxi_out_gamma(ps, len); /* output length */
      /* output position */
      if (pos == ps.last_match_pos) {
        /* a match with position 0 means use last position */
        wdxi_adv_tag_byte(ps, 0);
        wdxi_adv_tag_byte(ps, 0);
      } else {
        ps.last_match_pos = pos--;
        /*assert(pos >= 0);*/
        wdxi_out_gamma(ps, ((pos>>6)&0x3FFFFFFF)+3); /* output high part of position */
        /* output low 6 bits of position */
        wdxi_adv_tag_byte(ps, pos&0x20);
        wdxi_adv_tag_byte(ps, pos&0x10);
        wdxi_adv_tag_byte(ps, pos&0x08);
        wdxi_adv_tag_byte(ps, pos&0x04);
        wdxi_adv_tag_byte(ps, pos&0x02);
        wdxi_adv_tag_byte(ps, pos&0x01);
      }
    }
  }
}


void wdxi_find_match (pack_state_t *ps, match_t *thematch, const ubyte *buffer, uint lookback, uint lookforward) {
  uint back_pos, match_len, best_match_len, best_match_pos;
  const(ubyte)* ptr;
  uint idx0, idx1;
  /* temporary variables to avoid indirect addressing into the match */
  best_match_len = 0;
  best_match_pos = 0;
  /* update ps.lookup- and backtable up to current position */
  while (ps.backptr < buffer) {
    idx0 = ps.backptr[0];
    idx1 = ps.backptr[1];
    ps.back_tbl[ps.next_back_entry] = ps.lookup[idx0*256+idx1];
    ps.lookup[idx0*256+idx1] = ps.next_back_entry;
    ++ps.next_back_entry;
    ++ps.backptr;
  }
  /* get position by looking up next two bytes */
  back_pos = ps.lookup[buffer[0]*256+buffer[1]];
  if (back_pos != 0 && lookforward > 1) {
    ptr = back_pos+ps.srcofs;
    /* go backwards until before buffer */
    while (ptr >= buffer && back_pos != 0) {
      /*back_pos := PInt(Integer(ps.back_tbl)+back_pos*4)^;*/
      back_pos = ps.back_tbl[back_pos];
      ptr = back_pos+ps.srcofs;
    }
    /* search through table entries */
    while (back_pos != 0 && buffer-ptr <= lookback) {
      match_len = 2;
      /* if this position has a chance to be better */
      if (*(ptr+best_match_len) == *(buffer+best_match_len)) {
        /* scan it */
        while (match_len < lookforward && *(ptr+match_len) == *(buffer+match_len)) ++match_len;
        /* check it */
        if (match_len+(buffer-ptr == ps.last_match_pos) > best_match_len+(best_match_pos == ps.last_match_pos)) {
          best_match_len = match_len;
          if (best_match_len == lookforward) back_pos = 0;
          best_match_pos = buffer-ptr;
        }
      }
      /* move backwards to next position */
      back_pos = ps.back_tbl[back_pos];
      ptr = back_pos+ps.srcofs;
    }
  }
  /* forget match if too far away */
  if (best_match_pos > WDXUNPACK_LEN2_LIMIT && best_match_len == 2 && best_match_pos != ps.last_match_pos) {
    best_match_len = 0;
    best_match_pos = 0;
  }
  /* update the match with best match */
  thematch.len = best_match_len;
  thematch.pos = best_match_pos;
}


// ////////////////////////////////////////////////////////////////////////// //
public ssize wdx_pack (void *buf_out, usize size_out, const(void)* buf_in, usize size_in) {
  import core.stdc.stdlib : malloc, free;
  import core.stdc.string : memset;
  /* global variables */
  pack_state_t ps;
  match_t match, nextmatch, literalmatch, testmatch;
  uint pos, lastpos, literalCount;
  uint i0, i1;
  /* main code */
  if (size_in < 1) return 0;
  if (size_out < 2) return -1;
  /* init ps */
  ps.bufin = cast(const(ubyte)*)buf_in;
  ps.bufout = cast(ubyte*)buf_out;
  ps.lookup = null; /* lookup-table [256][256] */
  ps.last_match_pos = 0;
  ps.last_was_match = 0;
  ps.bytes_out = 0;
  ps.size_out = size_out;
  /* alloc memory */
  if ((ps.back_tbl = cast(uint*)malloc((size_in+4)*4)) is null) return -2; /* out of memory */
  if ((ps.lookup = cast(uint*)malloc(256*256*4)) is null) { free(ps.back_tbl); return -2; } /* out of memory */
  scope(exit) {
    free(ps.lookup);
    free(ps.back_tbl);
  }
  /* go on */
  memset(&match, 0, match.sizeof);
  memset(&nextmatch, 0, nextmatch.sizeof);
  memset(&literalmatch, 0, literalmatch.sizeof);
  memset(&testmatch, 0, testmatch.sizeof);
  literalmatch.pos = literalmatch.len = 0;
  ps.srcofs = ps.bufin-1;
  /* init ps.lookup- and backtable */
  memset(ps.lookup, 0, 256*256*4);
  memset(ps.back_tbl, 0, (size_in+4)*4);
  ps.backptr = ps.bufin;
  ps.back_tbl[0] = 0;
  ps.next_back_entry = 1;
  lastpos = -1;
  ps.last_match_pos = -1;
  ps.last_was_match = 0;
  literalCount = 0;
  /* the first byte is sent verbatim */
  *ps.bufout++ = *ps.bufin++;
  --size_out;
  ++ps.bytes_out;
  /* init tag-byte */
  ps.bit_count = 8;
  *(ps.tag_byte = ps.bufout++) = 0;
  --size_out;
  ++ps.bytes_out;
  /* pack data */
  pos = 1;
  while (pos < size_in) {
    /* find best match at current position (if not already found) */
    if (pos == lastpos) {
      match.len = nextmatch.len;
      match.pos = nextmatch.pos;
    } else {
      wdxi_find_match(&ps, &match, ps.bufin, pos, size_in-pos);
    }
    /* if we found a match, find the best match at the next position */
    if (match.len != 0) {
      wdxi_find_match(&ps, &nextmatch, ps.bufin+1, pos+1, size_in-(pos+1));
      lastpos = pos+1;
    } else {
      nextmatch.len = 0;
    }
    /* decide if we should output a match or a literal */
    i0 = (match.pos==ps.last_match_pos ? 1 : 0);
    i1 = (nextmatch.pos==ps.last_match_pos ? 1 : 0);
    if (match.len != 0 && match.len+i0 >= nextmatch.len+i1) {
      /* output any pending literals */
      if (literalCount != 0) {
        if (literalCount == 1) {
          wdxi_out_lit(&ps, ps.bufin[-1]);
        } else {
          /* check if there is a closer match with the required length */
          wdxi_find_match(&ps, &testmatch, ps.bufin-literalCount, literalmatch.pos, literalCount);
          if (testmatch.len >= literalCount) {
            wdxi_out_pair(&ps, testmatch.pos, literalCount, ps.bufin-literalCount);
          } else {
            wdxi_out_pair(&ps, literalmatch.pos, literalCount, ps.bufin-literalCount);
          }
        }
        literalCount = 0;
      }
      /* output match */
      wdxi_out_pair(&ps, match.pos, match.len, ps.bufin);
      ps.bufin += match.len;
      pos += match.len;
    } else {
      /* check if we are allready collecting literals */
      if (literalCount != 0) {
        /* if so, continue.. */
        ++literalCount;
        /* have we collected as many as possible? */
        if (literalCount == literalmatch.len) {
          wdxi_out_pair(&ps, literalmatch.pos, literalCount, ps.bufin-literalCount+1);
          literalCount = 0;
        }
      } else {
        /* if we had a match which was not good enough, then save it.. */
        if (match.len != 0) {
          literalmatch.len = match.len;
          literalmatch.pos = match.pos;
          ++literalCount;
        } else {
          /* if not, we have to output the literal now */
          wdxi_out_lit(&ps, ps.bufin[0]);
        }
      }
      ++ps.bufin;
      ++pos;
    }
  }
  /* output any remaining literal bytes */
  if (literalCount != 0) {
    if (literalCount == 1) {
      wdxi_out_lit(&ps, ps.bufin[-1]);
    } else {
      wdxi_out_pair(&ps, literalmatch.pos, literalCount, ps.bufin-literalCount);
    }
  }
  /* switch last ps.tag_byte into position */
  if (ps.bit_count != 8) *ps.tag_byte <<= ps.bit_count;
  //
  return ps.bytes_out;
}


// ////////////////////////////////////////////////////////////////////////// //
public ssize wdx_unpack (void *buf_out, usize size_out, const(void)* buf_in, usize size_in) {
  int len, pos, b, itsOk;
  ubyte *pp;
  const(ubyte)* src = cast(const ubyte *)buf_in;
  ubyte *dest = cast(ubyte*)buf_out;
  ubyte fbyte = 0;
  int last_match_pos = 0, last_was_match = 0, bCount = 0, origOutSz = size_out;
  /* main code */
  if (size_out < 1) return 0;
  if (size_in < 1) return -1; /* out of input data */

  auto WDXU_GET_BIT () {
    int res;
    if (bCount <= 0) {
      if (size_in < 1) throw new Exception("wdx error");
      fbyte = *src++;
      --size_in;
      bCount = 8;
    }
    res = (fbyte&0x80 ? 1 : 0);
    fbyte = (fbyte&0x7f)<<1;
    --bCount;
    return res;
  }

  auto WDXU_GET_GAMMA () {
    int res = 1;
    do {
      res = (res<<1)|WDXU_GET_BIT();
    } while (WDXU_GET_BIT() == 1);
    return res;
  }

  /* get 6 low bits of position */
  auto WDXU_GET_LO_POS (int _pos) {
    int ps = _pos;
    for (int f = 0; f < 6; ++f) ps = (ps<<1)|WDXU_GET_BIT();
    return ps;
  }

  /* the first byte was sent verbatim */
  *dest++ = *src++;
  --size_in;
  --size_out;
  while (size_out > 0) {
    itsOk = 1;
    b = WDXU_GET_BIT();
    itsOk = 0;
    if (b == 0) {
      /* literal */
      if (size_in < 1) break;
      if (size_out == 0) return -1;
      *dest++ = *src++;
      --size_in;
      --size_out;
      last_was_match = 0;
    } else {
      /* match */
      len = WDXU_GET_GAMMA();
      if (last_was_match) {
        pos = WDXU_GET_GAMMA()-2;
        pos = WDXU_GET_LO_POS(pos)+1;
        last_match_pos = pos;
        if (pos > WDXUNPACK_LEN2_LIMIT) ++len;
      } else {
        last_was_match = 1;
        pos = WDXU_GET_GAMMA()-2;
        /* same position as last match? */
        if (pos == 0) {
          pos = last_match_pos;
        } else {
          pos = WDXU_GET_LO_POS(pos-1)+1;
          last_match_pos = pos;
          if (pos > WDXUNPACK_LEN2_LIMIT) ++len;
        }
      }
      /* copy match */
      /*FIXME: wrapping*/
      pp = dest-pos;
      if (cast(void*)pp < cast(void*)buf_out) return -1; /* shit! */
      if (size_out < len) return -1;
      for (; len > 0 && size_out > 0; --size_out, --len) *dest++ = *pp++;
    }
  }
  return origOutSz-size_out;
//wdxu_error:
  /* decompressing error */
  if (!itsOk) return -1;
  return origOutSz-size_out;
}
