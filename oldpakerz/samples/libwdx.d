/*
 * original code: WDOSX-Pack v1.07, (c) 1999-2001 by Joergen Ibsen / Jibz
 * for data and executable compression software: http://www.ibsensoftware.com/
 */
module libwdx is aliced;

import iv.oldpakerz.crc32;
import iv.oldpakerz.wdx;

import iv.cmdcon;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
enum InFileName = "KA_HM.WAD";
enum PkFileName = "z00.hpk";
enum OutFileName = "z00.hpk.unp";


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  uint usz;

  {
    auto fi = VFile(InFileName);
    if (fi.size == 0 || fi.size >= int.max/2) throw new Exception("fucked!");
    auto data = new ubyte[](cast(uint)fi.size);
    fi.rawReadExact(data);
    usz = data.length;

    auto odata = new ubyte[](wdx_packbuf_size(data.length));

    conwriteln("packing...");

    auto pksize = wdx_pack(odata.ptr, odata.length, data.ptr, data.length);
    if (pksize < 0) throw new Exception("packing error");

    auto fo = VFile(PkFileName, "w");
    fo.rawWriteExact(odata[0..pksize]);

    conwriteln(data.length, " --> ", pksize);

    auto ucrc = wdx_crc32(data);
    conwritefln!"crc: 0x%08x"(ucrc);
  }

  {
    auto fi = VFile(PkFileName);
    if (fi.size == 0 || fi.size >= int.max/2) throw new Exception("fucked!");
    auto data = new ubyte[](cast(uint)fi.size);
    fi.rawReadExact(data);

    auto odata = new ubyte[](usz);

    conwriteln("unpacking...");

    auto upksize = wdx_unpack(odata.ptr, odata.length, data.ptr, data.length);
    if (upksize < 0) throw new Exception("unpacking error");

    auto fo = VFile(OutFileName, "w");
    fo.rawWriteExact(odata[]);

    conwriteln(data.length, " --> ", odata.length);

    auto ucrc = wdx_crc32(odata);
    conwritefln!"crc: 0x%08x"(ucrc);
  }
}
