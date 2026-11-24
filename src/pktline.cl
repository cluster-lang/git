// ==============================================================================
// Module:      Git Smart HTTP & Pkt-Line Wire Protocol (pktline.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Encodes and decodes standard Git pkt-line framing used by fetch,
//              push, and smart-HTTP transfer protocols.
// ==============================================================================

fn hex_to_nibble(c: int) -> int:
    if c >= 48 and c <= 57: return c - 48
    if c >= 97 and c <= 102: return c - 87
    if c >= 65 and c <= 70: return c - 55
    return 0

fn nibble_to_hex(n: int) -> string:
    hex_chars := "0123456789abcdef"
    if n >= 0 and n < 16:
        return char_at(hex_chars, n)
    return "0"

fn format_pkt_line(payload: string) -> string:
    total_len := len(payload) + 4
    if total_len > 65520:
        return ""
    let h1: string = nibble_to_hex((total_len >> 12) & 15)
    let h2: string = nibble_to_hex((total_len >> 8) & 15)
    let h3: string = nibble_to_hex((total_len >> 4) & 15)
    let h4: string = nibble_to_hex(total_len & 15)
    return h1 + h2 + h3 + h4 + payload

fn format_pkt_flush() -> string:
    return "0000"

fn parse_pkt_length(hex_hdr: string) -> int:
    if len(hex_hdr) < 4:
        return -1
    b1 := hex_to_nibble(byte_at(hex_hdr, 0))
    b2 := hex_to_nibble(byte_at(hex_hdr, 1))
    b3 := hex_to_nibble(byte_at(hex_hdr, 2))
    b4 := hex_to_nibble(byte_at(hex_hdr, 3))
    return (b1 << 12) | (b2 << 8) | (b3 << 4) | b4

fn parse_pkt_payload(raw: string) -> string:
    if len(raw) < 4:
        return ""
    pkt_len := parse_pkt_length(substring(raw, 0, 4))
    if pkt_len <= 4 or pkt_len > len(raw):
        return ""
    return substring(raw, 4, pkt_len - 4)
