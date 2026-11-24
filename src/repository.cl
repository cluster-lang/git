// ==============================================================================
// Module:      Repository & Reference Engine (repository.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Repository initialization, HEAD branch resolution, refs, tags,
//              remotes, and reset operations adhering to standard Git layout.
// ==============================================================================

fn trim_string(s: string) -> string:
    sz := len(s)
    let mut start: int = 0
    while start < sz and (byte_at(s, start) == 32 or byte_at(s, start) == 9 or byte_at(s, start) == 10 or byte_at(s, start) == 13):
        start = start + 1
    let mut end: int = sz - 1
    while end >= start and (byte_at(s, end) == 32 or byte_at(s, end) == 9 or byte_at(s, end) == 10 or byte_at(s, end) == 13):
        end = end - 1
    if start > end:
        return ""
    return substring(s, start, end - start + 1)

// ------------------------------------------------------------------------------
// Function: find_git_dir
// Syntax:   fn find_git_dir(start_path: string) -> string
// Purpose:  Traverses directory hierarchy upward to locate enclosing .git folder.
// ------------------------------------------------------------------------------
fn find_git_dir(start_path: string) -> string:
    cur := start_path
    if len(cur) == 0:
        cur = "."

    i := 0
    while i < 10:
        candidate := cur + "/.git"
        if file_exists(candidate) == 1:
            return candidate
        if cur == "." or cur == "/":
            return ""
        cur = cur + "/.."
        i = i + 1

    return ""

// ------------------------------------------------------------------------------
// Function: init_repository
// Syntax:   fn init_repository(target_path: string) -> int
// Purpose:  Initializes standard Git repository directory layout, HEAD, and config.
// ------------------------------------------------------------------------------
fn init_repository(target_path: string) -> int:
    root := target_path
    if len(root) == 0:
        root = "."

    git_dir := root + "/.git"
    if file_exists(git_dir) == 1:
        return 0

    system("mkdir -p " + git_dir + "/objects")
    system("mkdir -p " + git_dir + "/refs/heads")
    system("mkdir -p " + git_dir + "/refs/tags")

    head_content := "ref: refs/heads/main" + chr(10)
    file_write(git_dir + "/HEAD", head_content)

    config_content := "[core]" + chr(10) + "\trepositoryformatversion = 0" + chr(10) + "\tfilemode = true" + chr(10) + "\tbare = false" + chr(10)
    file_write(git_dir + "/config", config_content)

    desc_content := "Unnamed repository; edit this file 'description' to name the repository." + chr(10)
    file_write(git_dir + "/description", desc_content)

    return 1

// ------------------------------------------------------------------------------
// Branch and HEAD Resolution
// ------------------------------------------------------------------------------
fn get_head_branch(git_dir: string) -> string:
    head_file := git_dir + "/HEAD"
    if file_exists(head_file) == 0:
        return "main"

    raw := file_read(head_file)
    clean := ""
    i := 0
    while i < len(raw):
        b := byte_at(raw, i)
        if b != 10 and b != 13:
            clean = clean + chr(b)
        i = i + 1

    ref_prefix := "ref: refs/heads/"
    if len(clean) >= len(ref_prefix) and substring(clean, 0, len(ref_prefix)) == ref_prefix:
        return substring(clean, len(ref_prefix), len(clean) - len(ref_prefix))

    return clean

fn get_head_commit(git_dir: string) -> string:
    branch := get_head_branch(git_dir)
    ref_file := git_dir + "/refs/heads/" + branch
    if file_exists(ref_file) == 1:
        raw := file_read(ref_file)
        clean := ""
        i := 0
        while i < len(raw):
            b := byte_at(raw, i)
            if b != 10 and b != 13 and b != 32:
                clean = clean + chr(b)
            i = i + 1
        return clean

    if len(branch) == 40:
        return branch

    return ""

fn update_branch_ref(git_dir: string, branch: string, commit_hash: string) -> void:
    ref_dir := git_dir + "/refs/heads"
    if file_exists(ref_dir) == 0:
        system("mkdir -p " + ref_dir)
    ref_file := ref_dir + "/" + branch
    file_write(ref_file, commit_hash + chr(10))

fn list_branches(git_dir: string) -> vector[string]:
    branches: vector[string] = []
    ref_dir := git_dir + "/refs/heads"
    if file_exists(ref_dir) == 0:
        return branches

    files := fs_list_dir(ref_dir)
    i := 0
    flen := len(files)
    while i < flen:
        f := files[i]
        if f != "." and f != "..":
            branches.push(f)
        i = i + 1
    return branches

fn create_branch(git_dir: string, branch_name: string, commit_hash: string) -> int:
    if len(commit_hash) == 0:
        return 0
    update_branch_ref(git_dir, branch_name, commit_hash)
    return 1

fn set_head_branch(git_dir: string, branch_name: string) -> void:
    head_file := git_dir + "/HEAD"
    content := "ref: refs/heads/" + branch_name + chr(10)
    file_write(head_file, content)

// ------------------------------------------------------------------------------
// Tag Management (git tag)
// ------------------------------------------------------------------------------
fn create_tag(git_dir: string, tag_name: string, target_commit: string) -> int:
    if len(target_commit) == 0:
        return 0
    tag_dir := git_dir + "/refs/tags"
    if file_exists(tag_dir) == 0:
        system("mkdir -p " + tag_dir)
    file_write(tag_dir + "/" + tag_name, target_commit + chr(10))
    return 1

fn get_tag_commit(git_dir: string, tag_name: string) -> string:
    tag_file := git_dir + "/refs/tags/" + tag_name
    if file_exists(tag_file) == 0:
        return ""
    raw := file_read(tag_file)
    let mut clean: string = ""
    let mut i: int = 0
    while i < len(raw):
        b := byte_at(raw, i)
        if b != 10 and b != 13 and b != 32:
            clean = clean + chr(b)
        i = i + 1
    return clean

fn list_tags(git_dir: string) -> vector[string]:
    tags: vector[string] = []
    tag_dir := git_dir + "/refs/tags"
    if file_exists(tag_dir) == 0:
        return tags

    files := fs_list_dir(tag_dir)
    let mut i: int = 0
    while i < len(files):
        f := files[i]
        if f != "." and f != "..":
            tags.push(f)
        i = i + 1
    return tags

fn delete_tag(git_dir: string, tag_name: string) -> int:
    tag_file := git_dir + "/refs/tags/" + tag_name
    if file_exists(tag_file) == 1:
        system("rm -f " + tag_file)
        return 1
    return 0

// ------------------------------------------------------------------------------
// Remotes and Config (git remote)
// ------------------------------------------------------------------------------
fn add_remote(git_dir: string, remote_name: string, remote_url: string) -> int:
    config_file := git_dir + "/config"
    entry := "[remote \"" + remote_name + "\"]" + chr(10) + "\turl = " + remote_url + chr(10) + "\tfetch = +refs/heads/*:refs/remotes/" + remote_name + "/*" + chr(10)
    let mut cur: string = ""
    if file_exists(config_file) == 1:
        cur = file_read(config_file)
    file_write(config_file, cur + entry)
    return 1

fn get_remote_url(git_dir: string, remote_name: string) -> string:
    config_file := git_dir + "/config"
    if file_exists(config_file) == 0:
        return ""
    content := file_read(config_file)
    target_sec := "[remote \"" + remote_name + "\"]"
    if string_contains(content, target_sec) == 0:
        return ""
    
    // Find section start
    sz := len(content)
    let mut i: int = 0
    while i < sz:
        if substring(content, i, len(target_sec)) == target_sec:
            break
        i = i + 1
    
    // Read lines until next section or EOF
    let mut url_line: string = ""
    let mut cur: string = ""
    let mut j: int = i + len(target_sec)
    while j < sz:
        b := byte_at(content, j)
        if b == 10:
            if string_contains(cur, "url = ") == 1:
                url_line = cur
                break
            cur = ""
        else:
            cur = cur + chr(b)
        j = j + 1

    if len(url_line) > 0:
        pos := 0
        while pos + 6 <= len(url_line):
            if substring(url_line, pos, 6) == "url = ":
                return substring(url_line, pos + 6, len(url_line) - pos - 6)
            pos = pos + 1
    return ""

// ------------------------------------------------------------------------------
// Reset Engine (git reset)
// ------------------------------------------------------------------------------
fn reset_soft(git_dir: string, target_commit: string) -> void:
    branch := get_head_branch(git_dir)
    update_branch_ref(git_dir, branch, target_commit)
