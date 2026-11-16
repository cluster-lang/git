// ==============================================================================
// Module:      Compression & Decompression Engine (zlib.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      Zaid Alamgir (ZK Company)
// License:     MIT License
// Description: RFC 1950 (ZLIB) and RFC 1951 (DEFLATE) streaming compressor.
// ==============================================================================

// ------------------------------------------------------------------------------
// Function: adler32
// Syntax:   fn adler32(data: string) -> int
// Purpose:  Computes RFC 1950 Adler-32 checksum over uncompressed bytes.
// Params:   data - Input byte string
// Returns:  32-bit unsigned Adler-32 integer checksum
// ------------------------------------------------------------------------------
fn adler32(data: string) -> int:
    s1 := 1
    s2 := 0
    dlen := len(data)
    i := 0
    while i < dlen:
        b := byte_at(data, i)
        s1 = (s1 + b) % 65521
        s2 = (s2 + s1) % 65521
        i = i + 1
    return ((s2 << 16) | s1) & 4294967295

// ------------------------------------------------------------------------------
// Function: zlib_compress
// Syntax:   fn zlib_compress(data: string) -> string
// Purpose:  Compresses input payload into RFC 1950 / RFC 1951 compliant zlib stream.
// Params:   data - Raw uncompressed payload string
// Returns:  ZLIB formatted binary byte stream
// ------------------------------------------------------------------------------
fn zlib_compress(data: string) -> string:
    dlen := len(data)
    // RFC 1950 Header: CMF=0x78 (deflate, 32k window), FLG=0x01 (no dict, level 0)
    out := chr(120) + chr(1)

    offset := 0
    while offset < dlen or dlen == 0:
        chunk_size := dlen - offset
        is_final := 1
        if chunk_size > 65535:
            chunk_size = 65535
            is_final = 0

        bhdr := 0
        if is_final == 1:
            bhdr = 1

        l_low := chunk_size & 255
        l_hi := (chunk_size >> 8) & 255
        nl := 65535 - chunk_size
        nl_low := nl & 255
        nl_hi := (nl >> 8) & 255

        out = out + chr(bhdr) + chr(l_low) + chr(l_hi) + chr(nl_low) + chr(nl_hi)
        if chunk_size > 0:
            out = out + substring(data, offset, chunk_size)

        offset = offset + chunk_size
        if dlen == 0:
            offset = 1

    a := adler32(data)
    out = out + chr((a >> 24) & 255) + chr((a >> 16) & 255) + chr((a >> 8) & 255) + chr(a & 255)
    return out

// ------------------------------------------------------------------------------
// Function: zlib_decompress
// Syntax:   fn zlib_decompress(comp: string) -> string
// Purpose:  Decompresses RFC 1950 / RFC 1951 ZLIB streams into original bytes.
// Params:   comp - ZLIB compressed binary string
// Returns:  Decompressed uncompressed string payload
// ------------------------------------------------------------------------------
fn zlib_decompress(comp: string) -> string:
    clen := len(comp)
    if clen < 6:
        return ""

    // Verify RFC 1950 CMF byte
    cmf := byte_at(comp, 0)
    flg := byte_at(comp, 1)
    if cmf != 120:
        return ""

    // Inspect BTYPE (stored blocks vs Huffman)
    bhdr := byte_at(comp, 2)
    btype := (bhdr >> 1) & 3

    if btype == 0:
        // Native stored block inflation
        out := ""
        pos := 2
        while pos + 4 < clen - 4:
            cur_hdr := byte_at(comp, pos)
            is_final := cur_hdr & 1
            cur_type := (cur_hdr >> 1) & 3
            if cur_type != 0:
                return ""
            l0 := byte_at(comp, pos + 1)
            l1 := byte_at(comp, pos + 2)
            block_len := l0 | (l1 << 8)
            pos = pos + 5
            if block_len > 0 and pos + block_len <= clen - 4:
                out = out + substring(comp, pos, block_len)
                pos = pos + block_len
            if is_final == 1:
                return out
        return out

    // Fallback decompressor for dynamic Huffman streams
    tmp_in := "/tmp/cl_git_decomp_in"
    tmp_out := "/tmp/cl_git_decomp_out"
    file_write(tmp_in, comp)
    py_cmd := "python3 -c 'import zlib, sys; f=open(\"" + tmp_in + "\", \"rb\"); d=zlib.decompress(f.read()); open(\"" + tmp_out + "\", \"wb\").write(d)'"
    system(py_cmd)
    res := file_read(tmp_out)
    return res
