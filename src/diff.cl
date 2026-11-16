// ==============================================================================
// Module:      Unified Diff Engine (diff.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      mohammadzaid/(cluster) <zkalamgir@proton.me>
// License:     Cluster Community // License:     MIT License Fair-Source License (CCFL-1.0)
// Description: Longest Common Subsequence (LCS) line diff with ANSI color formatting.
// ==============================================================================

model DiffLine:
    kind: string
    text: string

// ------------------------------------------------------------------------------
// Function: split_lines
// Syntax:   fn split_lines(text: string) -> vector[string]
// Purpose:  Splits text payload into a vector of individual lines without CRLF.
// Params:   text - Multiline input string
// Returns:  Vector of individual line strings
// ------------------------------------------------------------------------------
fn split_lines(text: string) -> vector[string]:
    lines: vector[string] = []
    cur := ""
    tlen := len(text)
    i := 0
    while i < tlen:
        b := byte_at(text, i)
        if b == 10:
            lines.push(cur)
            cur = ""
        elif b != 13:
            cur = cur + chr(b)
        i = i + 1

    if len(cur) > 0:
        lines.push(cur)

    return lines

// ------------------------------------------------------------------------------
// Function: compute_diff
// Syntax:   fn compute_diff(a_lines: vector[string], b_lines: vector[string]) -> vector[DiffLine]
// Purpose:  Computes minimal line-by-line edit operations using 2D dynamic programming.
// Params:   a_lines - Original text lines
//           b_lines - Modified text lines
// Returns:  Vector of DiffLine items (' ' context, '-' deletion, '+' addition)
// ------------------------------------------------------------------------------
fn compute_diff(a_lines: vector[string], b_lines: vector[string]) -> vector[DiffLine]:
    m := len(a_lines)
    n := len(b_lines)

    diff: vector[DiffLine] = []

    if m == 0 and n == 0:
        return diff

    if m == 0:
        j := 0
        while j < n:
            diff.push(DiffLine("+", b_lines[j]))
            j = j + 1
        return diff

    if n == 0:
        i := 0
        while i < m:
            diff.push(DiffLine("-", a_lines[i]))
            i = i + 1
        return diff

    // Fast-path for extremely large line buffers to prevent matrix memory spikes
    if (m + 1) * (n + 1) > 2000000:
        lim := m
        if n < lim:
            lim = n
        k := 0
        while k < lim:
            if a_lines[k] == b_lines[k]:
                diff.push(DiffLine(" ", a_lines[k]))
            else:
                diff.push(DiffLine("-", a_lines[k]))
                diff.push(DiffLine("+", b_lines[k]))
            k = k + 1
        while k < m:
            diff.push(DiffLine("-", a_lines[k]))
            k = k + 1
        while k < n:
            diff.push(DiffLine("+", b_lines[k]))
            k = k + 1
        return diff

    stride := n + 1
    total := (m + 1) * stride
    dp: vector[int] = []
    k := 0
    while k < total:
        dp.push(0)
        k = k + 1

    i := 0
    while i < m:
        j := 0
        while j < n:
            curr_idx := ((i + 1) * stride) + (j + 1)
            if a_lines[i] == b_lines[j]:
                prev_diag := (i * stride) + j
                dp[curr_idx] = dp[prev_diag] + 1
            else:
                up := (i * stride) + (j + 1)
                left := ((i + 1) * stride) + j
                val_up := dp[up]
                val_left := dp[left]
                if val_left > val_up:
                    dp[curr_idx] = val_left
                else:
                    dp[curr_idx] = val_up
            j = j + 1
        i = i + 1

    rev_diff: vector[DiffLine] = []
    ci := m
    cj := n
    while ci > 0 or cj > 0:
        if ci > 0 and cj > 0 and a_lines[ci - 1] == b_lines[cj - 1]:
            rev_diff.push(DiffLine(" ", a_lines[ci - 1]))
            ci = ci - 1
            cj = cj - 1
        else:
            up_idx := ((ci - 1) * stride) + cj
            left_idx := (ci * stride) + (cj - 1)
            val_up := 0
            if ci > 0:
                val_up = dp[up_idx]
            val_left := 0
            if cj > 0:
                val_left = dp[left_idx]

            if cj > 0 and (ci == 0 or val_left >= val_up):
                rev_diff.push(DiffLine("+", b_lines[cj - 1]))
                cj = cj - 1
            elif ci > 0:
                rev_diff.push(DiffLine("-", a_lines[ci - 1]))
                ci = ci - 1

    // Reverse to chronological order
    rlen := len(rev_diff)
    idx := rlen - 1
    while idx >= 0:
        diff.push(rev_diff[idx])
        idx = idx - 1

    return diff

// ------------------------------------------------------------------------------
// Function: print_unified_diff
// Syntax:   fn print_unified_diff(path: string, a_content: string, b_content: string, use_color: int) -> int
// Purpose:  Prints standard unified diff format with optional ANSI terminal color highlighting.
// Params:   path      - Relative path of file being compared
//           a_content - Original staged file content
//           b_content - Modified working copy file content
//           use_color - 1 to enable ANSI escape colors, 0 for plain text
// Returns:  1 if differences existed and were printed, 0 if identical
// ------------------------------------------------------------------------------
fn print_unified_diff(path: string, a_content: string, b_content: string, use_color: int) -> int:
    a_lines := split_lines(a_content)
    b_lines := split_lines(b_content)
    diff := compute_diff(a_lines, b_lines)

    has_diff := 0
    i := 0
    dlen := len(diff)
    while i < dlen:
        if diff[i].kind != " ":
            has_diff = 1
            i = dlen
        i = i + 1

    if has_diff == 0:
        return 0

    c_reset := ""
    c_red := ""
    c_green := ""
    c_cyan := ""
    c_bold := ""

    if use_color == 1:
        c_reset = chr(27) + "[0m"
        c_bold = chr(27) + "[1m"
        c_red = chr(27) + "[31m"
        c_green = chr(27) + "[32m"
        c_cyan = chr(27) + "[36m"

    println(c_bold + "diff --cluster a/" + path + " b/" + path + c_reset)
    println(c_bold + "--- a/" + path + c_reset)
    println(c_bold + "+++ b/" + path + c_reset)
    println(c_cyan + "@@ -1," + len(a_lines) + " +1," + len(b_lines) + " @@" + c_reset)

    i = 0
    while i < dlen:
        dl := diff[i]
        if dl.kind == "+":
            println(c_green + "+" + dl.text + c_reset)
        elif dl.kind == "-":
            println(c_red + "-" + dl.text + c_reset)
        else:
            println(" " + dl.text)
        i = i + 1

    return 1
