// ============================================================================
//  cluster-git: Object Storage Engine (src/object.cl)
//  Git Content-Addressable Object Database (Blob, Tree, Commit, Tag)
// ============================================================================

model GitObject:
    obj_type: string
    size: int
    content: string
    hash: string

model TreeEntry:
    mode: string
    name: string
    sha1_hex: string

model CommitInfo:
    tree_hash: string
    parent_hash: string
    author_name: string
    author_email: string
    timestamp: int
    message: string

fn format_object_payload(obj_type: string, content: string) -> string:
    return obj_type + " " + len(content) + chr(0) + content

fn parse_object_payload(raw: string, hash: string) -> GitObject:
    rlen := len(raw)
    null_pos := -1
    i := 0
    while i < rlen:
        if byte_at(raw, i) == 0:
            null_pos = i
            i = rlen
        i = i + 1

    if null_pos < 0:
        return GitObject("unknown", 0, "", hash)

    header := substring(raw, 0, null_pos)
    content := ""
    if null_pos + 1 < rlen:
        content = substring(raw, null_pos + 1, rlen - null_pos - 1)

    // Parse header: "<type> <size>"
    space_pos := -1
    hlen := len(header)
    i = 0
    while i < hlen:
        if byte_at(header, i) == 32:
            space_pos = i
            i = hlen
        i = i + 1

    obj_type := "blob"
    sz := len(content)
    if space_pos > 0:
        obj_type = substring(header, 0, space_pos)

    return GitObject(obj_type, sz, content, hash)

fn write_git_object(git_dir: string, obj_type: string, content: string) -> string:
    payload := format_object_payload(obj_type, content)
    h := sha1(payload)
    prefix := substring(h, 0, 2)
    rest := substring(h, 2, 38)

    obj_dir := git_dir + "/objects/" + prefix
    if file_exists(obj_dir) == 0:
        system("mkdir -p " + obj_dir)

    obj_path := obj_dir + "/" + rest
    comp := zlib_compress(payload)
    file_write(obj_path, comp)
    return h

fn read_git_object(git_dir: string, hash: string) -> GitObject:
    if len(hash) != 40:
        // Try finding prefix match if partial hash is provided
        found_hash := find_object_by_prefix(git_dir, hash)
        if len(found_hash) == 40:
            hash = found_hash
        else:
            return GitObject("error", 0, "Object not found", hash)

    prefix := substring(hash, 0, 2)
    rest := substring(hash, 2, 38)
    obj_path := git_dir + "/objects/" + prefix + "/" + rest

    if file_exists(obj_path) == 0:
        return GitObject("error", 0, "Object not found: " + hash, hash)

    comp := file_read(obj_path)
    payload := zlib_decompress(comp)
    return parse_object_payload(payload, hash)

fn find_object_by_prefix(git_dir: string, prefix_str: string) -> string:
    if len(prefix_str) < 4:
        return ""
    dir_name := substring(prefix_str, 0, 2)
    sub_prefix := substring(prefix_str, 2, len(prefix_str) - 2)
    obj_dir := git_dir + "/objects/" + dir_name
    if file_exists(obj_dir) == 0:
        return ""

    files := fs_list_dir(obj_dir)
    i := 0
    flen := len(files)
    match_hash := ""
    while i < flen:
        f := files[i]
        if len(f) >= len(sub_prefix):
            if substring(f, 0, len(sub_prefix)) == sub_prefix:
                match_hash = dir_name + f
                i = flen
        i = i + 1
    return match_hash

fn serialize_tree(entries: vector[TreeEntry]) -> string:
    res := ""
    i := 0
    elen := len(entries)
    while i < elen:
        entry := entries[i]
        res = res + entry.mode + " " + entry.name + chr(0) + hex_to_raw_str(entry.sha1_hex)
        i = i + 1
    return res

fn parse_tree_entries(content: string) -> vector[TreeEntry]:
    entries: vector[TreeEntry] = []
    clen := len(content)
    pos := 0

    while pos < clen:
        // Find space
        space_pos := -1
        i := pos
        while i < clen:
            if byte_at(content, i) == 32:
                space_pos = i
                i = clen
            i = i + 1

        if space_pos < 0:
            return entries

        mode := substring(content, pos, space_pos - pos)

        // Find null byte
        null_pos := -1
        i = space_pos + 1
        while i < clen:
            if byte_at(content, i) == 0:
                null_pos = i
                i = clen
            i = i + 1

        if null_pos < 0:
            return entries

        name := substring(content, space_pos + 1, null_pos - space_pos - 1)

        // 20-byte SHA-1 hash
        raw_sha := ""
        if null_pos + 1 + 20 <= clen:
            raw_sha = substring(content, null_pos + 1, 20)
            pos = null_pos + 1 + 20
        else:
            return entries

        sha_hex := raw_str_to_hex(raw_sha)
        entries.push(TreeEntry(mode, name, sha_hex))

    return entries

fn serialize_commit(tree_hash: string, parent_hash: string, author_name: string, author_email: string, ts: int, msg: string) -> string:
    out := "tree " + tree_hash + chr(10)
    if len(parent_hash) > 0:
        out = out + "parent " + parent_hash + chr(10)

    out = out + "author " + author_name + " <" + author_email + "> " + ts + " +0000" + chr(10)
    out = out + "committer " + author_name + " <" + author_email + "> " + ts + " +0000" + chr(10)
    out = out + chr(10)
    out = out + msg + chr(10)
    return out

fn parse_commit_info(content: string) -> CommitInfo:
    tree_hash := ""
    parent_hash := ""
    author_name := "Cluster User"
    author_email := "cluster@lang.org"
    ts := 0
    msg := ""

    lines: vector[string] = []
    cur := ""
    clen := len(content)
    i := 0
    in_message := 0

    while i < clen:
        b := byte_at(content, i)
        if in_message == 1:
            msg = msg + chr(b)
        else:
            if b == 10:
                if len(cur) == 0:
                    in_message = 1
                else:
                    lines.push(cur)
                    cur = ""
            else:
                cur = cur + chr(b)
        i = i + 1

    i = 0
    llen := len(lines)
    while i < llen:
        line := lines[i]
        if len(line) >= 5 and substring(line, 0, 5) == "tree ":
            tree_hash = substring(line, 5, len(line) - 5)
        elif len(line) >= 7 and substring(line, 0, 7) == "parent ":
            parent_hash = substring(line, 7, len(line) - 7)
        elif len(line) >= 7 and substring(line, 0, 7) == "author ":
            // author Name <email> ts +0000
            auth_str := substring(line, 7, len(line) - 7)
            lt := -1
            gt := -1
            j := 0
            while j < len(auth_str):
                if byte_at(auth_str, j) == 60: lt = j
                if byte_at(auth_str, j) == 62: gt = j
                j = j + 1
            if lt > 0:
                author_name = substring(auth_str, 0, lt - 1)
            if lt >= 0 and gt > lt:
                author_email = substring(auth_str, lt + 1, gt - lt - 1)
        i = i + 1

    return CommitInfo(tree_hash, parent_hash, author_name, author_email, ts, msg)
