// ==============================================================================
// Module:      Cryptographic Hashing Engine (sha1.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      mohammadzaid/(cluster) <zkalamgir@proton.me>
// License:     Cluster Community // License:     MIT License Fair-Source License (CCFL-1.0)
// Description: RFC 3174 compliant SHA-1 hash function and hexadecimal encoder.
// ==============================================================================

// ------------------------------------------------------------------------------
// Function: rol32
// Syntax:   fn rol32(x: int, n: int) -> int
// Purpose:  Performs a 32-bit circular left rotation by n bits.
// Params:   x - The 32-bit integer word to rotate
//           n - Number of bit positions to shift left (0-31)
// Returns:  32-bit rotated integer result
// ------------------------------------------------------------------------------
fn rol32(x: int, n: int) -> int:
    mask := 4294967295
    left := (x << n) & mask
    right := (x >> (32 - n)) & mask
    return (left | right) & mask

// ------------------------------------------------------------------------------
// Function: hex_nibble
// Syntax:   fn hex_nibble(n: int) -> string
// Purpose:  Converts a 4-bit numeric value (0-15) to a single hex character.
// Params:   n - Value between 0 and 15
// Returns:  Single-character lowercase hex string ("0"-"f")
// ------------------------------------------------------------------------------
fn hex_nibble(n: int) -> string:
    v := n & 15
    if v == 0: return "0"
    if v == 1: return "1"
    if v == 2: return "2"
    if v == 3: return "3"
    if v == 4: return "4"
    if v == 5: return "5"
    if v == 6: return "6"
    if v == 7: return "7"
    if v == 8: return "8"
    if v == 9: return "9"
    if v == 10: return "a"
    if v == 11: return "b"
    if v == 12: return "c"
    if v == 13: return "d"
    if v == 14: return "e"
    return "f"

// ------------------------------------------------------------------------------
// Function: to_hex32
// Syntax:   fn to_hex32(val: int) -> string
// Purpose:  Converts a 32-bit unsigned integer into an 8-character hex string.
// Params:   val - 32-bit integer word
// Returns:  8-character lowercase hexadecimal string
// ------------------------------------------------------------------------------
fn to_hex32(val: int) -> string:
    v := val & 4294967295
    h := ""
    shift := 28
    while shift >= 0:
        nibble := (v >> shift) & 15
        h = h + hex_nibble(nibble)
        shift = shift - 4
    return h

// ------------------------------------------------------------------------------
// Function: hex_char_val
// Syntax:   fn hex_char_val(c: int) -> int
// Purpose:  Converts an ASCII byte code of a hex digit to its integer value (0-15).
// Params:   c - ASCII integer value of the character
// Returns:  Integer from 0 to 15, or 0 if invalid
// ------------------------------------------------------------------------------
fn hex_char_val(c: int) -> int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    return 0

// ------------------------------------------------------------------------------
// Function: str_compare
// Syntax:   fn str_compare(s1: string, s2: string) -> int
// Purpose:  Performs lexicographical byte comparison of two strings.
// Params:   s1 - First string operand
//           s2 - Second string operand
// Returns:  -1 if s1 < s2, 0 if s1 == s2, 1 if s1 > s2
// ------------------------------------------------------------------------------
fn str_compare(s1: string, s2: string) -> int:
    l1 := len(s1)
    l2 := len(s2)
    min_l := l1
    if l2 < min_l:
        min_l = l2
    i := 0
    while i < min_l:
        c1 := byte_at(s1, i)
        c2 := byte_at(s2, i)
        if c1 < c2:
            return -1
        if c1 > c2:
            return 1
        i = i + 1
    if l1 < l2:
        return -1
    if l1 > l2:
        return 1
    return 0

// ------------------------------------------------------------------------------
// Function: hex_to_raw_str
// Syntax:   fn hex_to_raw_str(hex_str: string) -> string
// Purpose:  Decodes a 40-character hex string into 20 raw binary bytes.
// Params:   hex_str - 40-character hexadecimal string
// Returns:  20-byte raw binary string
// ------------------------------------------------------------------------------
fn hex_to_raw_str(hex_str: string) -> string:
    res := ""
    hlen := len(hex_str)
    i := 0
    while i < hlen:
        c1 := byte_at(hex_str, i)
        c2 := byte_at(hex_str, i + 1)
        h1 := hex_char_val(c1)
        h2 := hex_char_val(c2)
        b := (h1 << 4) | h2
        res = res + chr(b)
        i = i + 2
    return res

// ------------------------------------------------------------------------------
// Function: raw_str_to_hex
// Syntax:   fn raw_str_to_hex(raw_str: string) -> string
// Purpose:  Encodes 20 raw binary bytes into a 40-character hex digest.
// Params:   raw_str - Binary string containing raw bytes
// Returns:  40-character lowercase hexadecimal string
// ------------------------------------------------------------------------------
fn raw_str_to_hex(raw_str: string) -> string:
    res := ""
    rlen := len(raw_str)
    i := 0
    while i < rlen:
        b := byte_at(raw_str, i)
        hi := (b >> 4) & 15
        lo := b & 15
        res = res + hex_nibble(hi) + hex_nibble(lo)
        i = i + 1
    return res

// ------------------------------------------------------------------------------
// Function: sha1
// Syntax:   fn sha1(msg: string) -> string
// Purpose:  Computes RFC 3174 compliant SHA-1 hash for arbitrary text or binary data.
// Params:   msg - Input payload to hash
// Returns:  40-character lowercase hex digest
// ------------------------------------------------------------------------------
fn sha1(msg: string) -> string:
    mask := 4294967295
    mlen := len(msg)
    bit_len := mlen * 8

    bytes: vector[int] = []
    i := 0
    while i < mlen:
        bytes.push(byte_at(msg, i))
        i = i + 1

    bytes.push(128)

    while (len(bytes) + 8) % 64 != 0:
        bytes.push(0)

    // 64-bit message length encoded as big-endian
    high_bits := (bit_len >> 32) & mask
    low_bits := bit_len & mask

    bytes.push((high_bits >> 24) & 255)
    bytes.push((high_bits >> 16) & 255)
    bytes.push((high_bits >> 8) & 255)
    bytes.push(high_bits & 255)

    bytes.push((low_bits >> 24) & 255)
    bytes.push((low_bits >> 16) & 255)
    bytes.push((low_bits >> 8) & 255)
    bytes.push(low_bits & 255)

    // RFC 3174 initial state constants
    h0 := 1732584193
    h1 := 4023233417
    h2 := 2562383102
    h3 := 271733878
    h4 := 3285377520

    total_bytes := len(bytes)
    chunk := 0
    while chunk < total_bytes:
        w: vector[int] = []
        t := 0
        while t < 16:
            b_idx := chunk + (t * 4)
            b0 := bytes[b_idx]
            b1 := bytes[b_idx + 1]
            b2 := bytes[b_idx + 2]
            b3 := bytes[b_idx + 3]
            word := ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & mask
            w.push(word)
            t = t + 1

        while t < 80:
            val := (w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]) & mask
            rot := rol32(val, 1)
            w.push(rot)
            t = t + 1

        a := h0
        b := h1
        c := h2
        d := h3
        e := h4

        i = 0
        while i < 80:
            f := 0
            k := 0
            if i < 20:
                f = (b & c) | ((b ^ mask) & d)
                k = 1518500249
            elif i < 40:
                f = b ^ c ^ d
                k = 1859775393
            elif i < 60:
                f = (b & c) | (b & d) | (c & d)
                k = 2400959708
            else:
                f = b ^ c ^ d
                k = 3395469782

            temp := (rol32(a, 5) + f + e + k + w[i]) & mask
            e = d
            d = c
            c = rol32(b, 30)
            b = a
            a = temp
            i = i + 1

        h0 = (h0 + a) & mask
        h1 = (h1 + b) & mask
        h2 = (h2 + c) & mask
        h3 = (h3 + d) & mask
        h4 = (h4 + e) & mask

        chunk = chunk + 64

    return to_hex32(h0) + to_hex32(h1) + to_hex32(h2) + to_hex32(h3) + to_hex32(h4)
