// ==============================================================================
// Module:      Git Packfile v2 Generator & Parser (pack.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Packfile v2 serialization, object chunking, and SHA-1 checksumming.
// ==============================================================================

import "src/sha1.cl"
import "src/zlib.cl"
import "src/object.cl"

model PackHeader:
    magic: string
    version: int
    object_count: int

fn pack_header_serialize(num_objects: int) -> string:
    let mut hdr: string = "PACK"
    hdr = hdr + chr(0) + chr(0) + chr(0) + chr(2)
    hdr = hdr + chr((num_objects >> 24) & 255)
    hdr = hdr + chr((num_objects >> 16) & 255)
    hdr = hdr + chr((num_objects >> 8) & 255)
    hdr = hdr + chr(num_objects & 255)
    return hdr

fn pack_encode_object(obj_type: string, content: string) -> string:
    let mut type_id: int = 1
    if obj_type == "commit": type_id = 1
    elif obj_type == "tree": type_id = 2
    elif obj_type == "blob": type_id = 3
    elif obj_type == "tag": type_id = 4

    sz := len(content)
    let mut b0: int = (type_id << 4) | (sz & 15)
    let mut rest_sz: int = sz >> 4
    let mut header_bytes: string = ""

    if rest_sz > 0:
        b0 = b0 | 128
        header_bytes = header_bytes + chr(b0)
        while rest_sz > 0:
            let mut b: int = rest_sz & 127
            rest_sz = rest_sz >> 7
            if rest_sz > 0:
                b = b | 128
            header_bytes = header_bytes + chr(b)
    else:
        header_bytes = header_bytes + chr(b0)

    compressed := zlib_compress(content)
    return header_bytes + compressed

fn pack_create(objects: vector[GitObject]) -> string:
    let num_objs: int = len(objects)
    let mut pack_stream: string = pack_header_serialize(num_objs)

    let mut i: int = 0
    while i < num_objs:
        let obj: GitObject = objects[i]
        chunk := pack_encode_object(obj.obj_type, obj.content)
        pack_stream = pack_stream + chunk
        i = i + 1

    trailer_sha := sha1(pack_stream)
    return pack_stream + trailer_sha

fn pack_verify_header(raw: string) -> PackHeader:
    if len(raw) < 12:
        return PackHeader("error", 0, 0)
    magic := substring(raw, 0, 4)
    if magic != "PACK":
        return PackHeader("error", 0, 0)

    v := (byte_at(raw, 4) << 24) | (byte_at(raw, 5) << 16) | (byte_at(raw, 6) << 8) | byte_at(raw, 7)
    cnt := (byte_at(raw, 8) << 24) | (byte_at(raw, 9) << 16) | (byte_at(raw, 10) << 8) | byte_at(raw, 11)
    return PackHeader(magic, v, cnt)
