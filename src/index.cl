// ==============================================================================
// Module:      Staging & Index Engine (index.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      mohammadzaid/(cluster) <zkalamgir@proton.me>
// License:     Cluster Community // License:     MIT License Fair-Source License (CCFL-1.0)
// Description: Git DIRC v2 binary index serialization, parsing, and staging logic.
// ==============================================================================

model IndexEntry:
    path: string
    sha1_hex: string
    mode: string
    size: int

// ------------------------------------------------------------------------------
// Function: pack_be32
// Syntax:   fn pack_be32(val: int) -> string
// Purpose:  Serializes a 32-bit unsigned integer into 4 big-endian bytes.
// Params:   val - 32-bit integer value
// Returns:  4-character binary string
// ------------------------------------------------------------------------------
fn pack_be32(val: int) -> string:
    mask := 4294967295
    v := val & mask
    b0 := (v >> 24) & 255
    b1 := (v >> 16) & 255
    b2 := (v >> 8) & 255
    b3 := v & 255
    return chr(b0) + chr(b1) + chr(b2) + chr(b3)

// ------------------------------------------------------------------------------
// Function: pack_be16
// Syntax:   fn pack_be16(val: int) -> string
// Purpose:  Serializes a 16-bit unsigned integer into 2 big-endian bytes.
// Params:   val - 16-bit integer value
// Returns:  2-character binary string
// ------------------------------------------------------------------------------
fn pack_be16(val: int) -> string:
    v := val & 65535
    b0 := (v >> 8) & 255
    b1 := v & 255
    return chr(b0) + chr(b1)

// ------------------------------------------------------------------------------
// Function: unpack_be32
// Syntax:   fn unpack_be32(s: string, offset: int) -> int
// Purpose:  Unpacks a 32-bit big-endian unsigned integer from a byte offset.
// Params:   s      - Binary string containing bytes
//           offset - Starting index of the 4-byte integer
// Returns:  Decoded 32-bit integer
// ------------------------------------------------------------------------------
fn unpack_be32(s: string, offset: int) -> int:
    b0 := byte_at(s, offset)
    b1 := byte_at(s, offset + 1)
    b2 := byte_at(s, offset + 2)
    b3 := byte_at(s, offset + 3)
    return ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & 4294967295

// ------------------------------------------------------------------------------
// Function: sort_index_entries
// Syntax:   fn sort_index_entries(entries: vector[IndexEntry]) -> void
// Purpose:  Sorts index entries in lexicographical path order as required by Git.
// Params:   entries - Mutable vector of IndexEntry items
// ------------------------------------------------------------------------------
fn sort_index_entries(entries: vector[IndexEntry]) -> void:
    n := len(entries)
    i := 0
    while i < n:
        j := 0
        while j < n - 1:
            if str_compare(entries[j].path, entries[j + 1].path) > 0:
                temp := entries[j]
                entries[j] = entries[j + 1]
                entries[j + 1] = temp
            j = j + 1
        i = i + 1

// ------------------------------------------------------------------------------
// Function: write_index_file
// Syntax:   fn write_index_file(git_dir: string, entries: vector[IndexEntry]) -> void
// Purpose:  Encodes and writes canonical DIRC v2 binary index file (.git/index).
// Params:   git_dir - Path to the .git directory
//           entries - Staged IndexEntry items to serialize
// ------------------------------------------------------------------------------
fn write_index_file(git_dir: string, entries: vector[IndexEntry]) -> void:
    sort_index_entries(entries)

    // DIRC Header: Signature "DIRC" + version 2 + entry count
    buf := "DIRC" + pack_be32(2) + pack_be32(len(entries))

    i := 0
    elen := len(entries)
    while i < elen:
        entry := entries[i]
        mode_val := 33188 // 0100644 (regular file)
        if entry.mode == "100755":
            mode_val = 33261 // 0100755 (executable)

        entry_buf := pack_be32(0) + pack_be32(0) // ctime(sec, nsec)
        entry_buf = entry_buf + pack_be32(0) + pack_be32(0) // mtime(sec, nsec)
        entry_buf = entry_buf + pack_be32(0) + pack_be32(0) // dev, ino
        entry_buf = entry_buf + pack_be32(mode_val) // mode
        entry_buf = entry_buf + pack_be32(0) + pack_be32(0) // uid, gid
        entry_buf = entry_buf + pack_be32(entry.size) // file size

        // 20 raw binary bytes of SHA-1
        entry_buf = entry_buf + hex_to_raw_str(entry.sha1_hex)

        // 16-bit flags: path length (max 0xFFF)
        plen := len(entry.path)
        flags := plen
        if flags > 4095:
            flags = 4095
        entry_buf = entry_buf + pack_be16(flags)

        // Path and null byte terminator
        entry_buf = entry_buf + entry.path + chr(0)

        // Null padding to align entry on an 8-byte boundary
        rem := len(entry_buf) % 8
        if rem != 0:
            pad := 8 - rem
            p := 0
            while p < pad:
                entry_buf = entry_buf + chr(0)
                p = p + 1

        buf = buf + entry_buf
        i = i + 1

    // Append 20-byte SHA-1 checksum of index payload
    cksum_hex := sha1(buf)
    buf = buf + hex_to_raw_str(cksum_hex)

    index_path := git_dir + "/index"
    file_write(index_path, buf)

// ------------------------------------------------------------------------------
// Function: read_index_file
// Syntax:   fn read_index_file(git_dir: string) -> vector[IndexEntry]
// Purpose:  Reads and decodes binary DIRC v2 .git/index file into IndexEntry records.
// Params:   git_dir - Path to the .git directory
// Returns:  Vector of parsed IndexEntry items
// ------------------------------------------------------------------------------
fn read_index_file(git_dir: string) -> vector[IndexEntry]:
    entries: vector[IndexEntry] = []
    index_path := git_dir + "/index"
    if file_exists(index_path) == 0:
        return entries

    raw := file_read(index_path)
    rlen := len(raw)
    if rlen < 32:
        return entries

    // Validate DIRC signature
    sig := substring(raw, 0, 4)
    if sig != "DIRC":
        return entries

    ver := unpack_be32(raw, 4)
    count := unpack_be32(raw, 8)

    pos := 12
    idx := 0
    while idx < count and pos + 62 < rlen - 20:
        entry_start := pos
        mode_val := unpack_be32(raw, pos + 24)
        file_sz := unpack_be32(raw, pos + 36)
        raw_sha := substring(raw, pos + 40, 20)
        sha_hex := raw_str_to_hex(raw_sha)

        mode_str := "100644"
        if mode_val == 33261:
            mode_str = "100755"

        path_pos := pos + 62
        null_pos := -1
        p := path_pos
        while p < rlen - 20:
            if byte_at(raw, p) == 0:
                null_pos = p
                p = rlen
            p = p + 1

        if null_pos < 0:
            return entries

        file_path := substring(raw, path_pos, null_pos - path_pos)
        entries.push(IndexEntry(file_path, sha_hex, mode_str, file_sz))

        entry_len := (null_pos + 1) - entry_start
        rem := entry_len % 8
        if rem != 0:
            entry_len = entry_len + (8 - rem)

        pos = entry_start + entry_len
        idx = idx + 1

    return entries

// ------------------------------------------------------------------------------
// Function: add_file_to_index
// Syntax:   fn add_file_to_index(git_dir: string, repo_root: string, rel_path: string) -> string
// Purpose:  Hashes a working file, creates a blob in the object store, and stages it.
// Params:   git_dir   - Path to .git directory
//           repo_root - Root directory of the repository
//           rel_path  - Relative path of file to add
// Returns:  40-character SHA-1 of the created blob
// ------------------------------------------------------------------------------
fn add_file_to_index(git_dir: string, repo_root: string, rel_path: string) -> string:
    full_path := rel_path
    if len(repo_root) > 0 and repo_root != ".":
        full_path = repo_root + "/" + rel_path

    if file_exists(full_path) == 0:
        return ""

    content := file_read(full_path)
    blob_hash := write_git_object(git_dir, "blob", content)

    entries := read_index_file(git_dir)
    updated := 0
    i := 0
    elen := len(entries)
    while i < elen:
        if entries[i].path == rel_path:
            entries[i].sha1_hex = blob_hash
            entries[i].size = len(content)
            updated = 1
            i = elen
        i = i + 1

    if updated == 0:
        entries.push(IndexEntry(rel_path, blob_hash, "100644", len(content)))

    write_index_file(git_dir, entries)
    return blob_hash

// ------------------------------------------------------------------------------
// Function: remove_file_from_index
// Syntax:   fn remove_file_from_index(git_dir: string, rel_path: string) -> int
// Purpose:  Unstages a file from the index.
// Params:   git_dir  - Path to .git directory
//           rel_path - Relative path of file to remove
// Returns:  1 if entry was removed, 0 if not found
// ------------------------------------------------------------------------------
fn remove_file_from_index(git_dir: string, rel_path: string) -> int:
    entries := read_index_file(git_dir)
    new_entries: vector[IndexEntry] = []
    found := 0
    i := 0
    elen := len(entries)
    while i < elen:
        if entries[i].path != rel_path:
            new_entries.push(entries[i])
        else:
            found = 1
        i = i + 1

    if found == 1:
        write_index_file(git_dir, new_entries)
    return found
