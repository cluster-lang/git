// ==============================================================================
// Module:      Main CLI Porcelain & Plumbing Driver (main.cl)
// Project:     Cluster Git (Distributed Version Control System)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Porcelain command router (init, status, add, commit, log, diff, branch, checkout).
// ==============================================================================

import "src/sha1.cl"
import "src/zlib.cl"
import "src/object.cl"
import "src/index.cl"
import "src/repository.cl"
import "src/diff.cl"

// ------------------------------------------------------------------------------
// Function: sort_tree_entries
// Syntax:   fn sort_tree_entries(entries: vector[TreeEntry]) -> void
// Purpose:  Sorts tree entries by name in alphabetical order.
// ------------------------------------------------------------------------------
fn sort_tree_entries(entries: vector[TreeEntry]) -> void:
    n := len(entries)
    i := 0
    while i < n:
        j := 0
        while j < n - 1:
            if str_compare(entries[j].name, entries[j + 1].name) > 0:
                temp := entries[j]
                entries[j] = entries[j + 1]
                entries[j + 1] = temp
            j = j + 1
        i = i + 1

// ------------------------------------------------------------------------------
// Function: build_tree_recursive
// Syntax:   fn build_tree_recursive(git_dir: string, entries: vector[IndexEntry], prefix: string) -> string
// Purpose:  Recursively constructs tree and sub-tree objects from staged index entries.
// Params:   git_dir - Path to .git directory
//           entries - Staged index entries
//           prefix  - Current subdirectory prefix (e.g. "src/")
// Returns:  40-character SHA-1 of the generated tree object
// ------------------------------------------------------------------------------
fn build_tree_recursive(git_dir: string, entries: vector[IndexEntry], prefix: string) -> string:
    tree_entries: vector[TreeEntry] = []
    subdirs: vector[string] = []

    i := 0
    elen := len(entries)
    while i < elen:
        e := entries[i]
        p := e.path
        if len(prefix) > 0:
            if len(p) > len(prefix) and substring(p, 0, len(prefix)) == prefix:
                p = substring(p, len(prefix), len(p) - len(prefix))
            else:
                p = ""

        if len(p) > 0:
            slash_pos := -1
            j := 0
            while j < len(p):
                if byte_at(p, j) == 47: // '/'
                    slash_pos = j
                    j = len(p)
                j = j + 1

            if slash_pos < 0:
                tree_entries.push(TreeEntry(e.mode, p, e.sha1_hex))
            else:
                dir_name := substring(p, 0, slash_pos)
                found := 0
                k := 0
                while k < len(subdirs):
                    if subdirs[k] == dir_name:
                        found = 1
                        k = len(subdirs)
                    k = k + 1
                if found == 0:
                    subdirs.push(dir_name)
        i = i + 1

    k := 0
    while k < len(subdirs):
        dname := subdirs[k]
        sub_prefix := dname + "/"
        if len(prefix) > 0:
            sub_prefix = prefix + dname + "/"
        sub_tree_hash := build_tree_recursive(git_dir, entries, sub_prefix)
        tree_entries.push(TreeEntry("040000", dname, sub_tree_hash))
        k = k + 1

    sort_tree_entries(tree_entries)
    raw_tree := serialize_tree(tree_entries)
    return write_git_object(git_dir, "tree", raw_tree)

// ------------------------------------------------------------------------------
// Function: collect_working_files
// Syntax:   fn collect_working_files(dir_path: string, rel_prefix: string) -> vector[string]
// Purpose:  Recursively scans working directory ignoring .git to find all tracked/untracked files.
// ------------------------------------------------------------------------------
fn collect_working_files(dir_path: string, rel_prefix: string) -> vector[string]:
    let mut out: vector[string] = []
    files := fs_list_dir(dir_path)
    let mut i: int = 0
    let flen: int = len(files)
    while i < flen:
        f := files[i]
        if f != ".git" and f != "." and f != "..":
            sub_path := dir_path + "/" + f
            let mut rel_name: string = f
            if len(rel_prefix) > 0:
                rel_name = rel_prefix + "/" + f

            if fs_is_dir(sub_path) == 1:
                sub_res := collect_working_files(sub_path, rel_name)
                let mut j: int = 0
                while j < len(sub_res):
                    out.push(sub_res[j])
                    j = j + 1
            else:
                out.push(rel_name)
        i = i + 1
    return out

// ------------------------------------------------------------------------------
// Function: cmd_init
// Syntax:   fn cmd_init(args: vector[string]) -> void
// Purpose:  Implements 'git init' command.
// ------------------------------------------------------------------------------
fn cmd_init(args: vector[string]) -> void:
    target := "."
    if len(args) > 1:
        target = args[1]

    res := init_repository(target)
    if res == 1:
        println("Initialized empty Git repository in " + target + "/.git/")
    else:
        println("Reinitialized existing Git repository in " + target + "/.git/")

// ------------------------------------------------------------------------------
// Function: cmd_status
// Syntax:   fn cmd_status(git_dir: string, repo_root: string) -> void
// Purpose:  Implements 'git status' displaying branch, staged, modified, and untracked files.
// ------------------------------------------------------------------------------
fn cmd_status(git_dir: string, repo_root: string) -> void:
    branch := get_head_branch(git_dir)
    println("On branch " + branch)

    head_commit := get_head_commit(git_dir)
    if len(head_commit) == 0:
        println("No commits yet\n")

    index_entries := read_index_file(git_dir)

    c_green := chr(27) + "[32m"
    c_red := chr(27) + "[31m"
    c_reset := chr(27) + "[0m"

    // Changes staged for commit
    if len(index_entries) > 0 and len(head_commit) == 0:
        println("Changes to be committed:")
        println("  (use \"cluster-git rm --cached <file>...\" to unstage)\n")
        i := 0
        while i < len(index_entries):
            println("        " + c_green + "new file:   " + index_entries[i].path + c_reset)
            i = i + 1
        println("")

    working_files := collect_working_files(repo_root, "")

    modified_files: vector[string] = []
    untracked_files: vector[string] = []

    i := 0
    wlen := len(working_files)
    while i < wlen:
        wf := working_files[i]
        idx_found := -1
        j := 0
        while j < len(index_entries):
            if index_entries[j].path == wf:
                idx_found = j
                j = len(index_entries)
            j = j + 1

        if idx_found >= 0:
            full_path := repo_root + "/" + wf
            content := file_read(full_path)
            payload := format_object_payload("blob", content)
            h := sha1(payload)
            if h != index_entries[idx_found].sha1_hex:
                modified_files.push(wf)
        else:
            untracked_files.push(wf)
        i = i + 1

    if len(modified_files) > 0:
        println("Changes not staged for commit:")
        println("  (use \"cluster-git add <file>...\" to update what will be committed)\n")
        i = 0
        while i < len(modified_files):
            println("        " + c_red + "modified:   " + modified_files[i] + c_reset)
            i = i + 1
        println("")

    if len(untracked_files) > 0:
        println("Untracked files:")
        println("  (use \"cluster-git add <file>...\" to include in what will be committed)\n")
        i = 0
        while i < len(untracked_files):
            println("        " + c_red + untracked_files[i] + c_reset)
            i = i + 1
        println("")

    if len(index_entries) == 0 and len(modified_files) == 0 and len(untracked_files) == 0:
        println("nothing to commit, working tree clean")

// ------------------------------------------------------------------------------
// Function: cmd_add
// Syntax:   fn cmd_add(git_dir: string, repo_root: string, args: vector[string]) -> void
// Purpose:  Implements 'git add' staging target files or all files ('.').
// ------------------------------------------------------------------------------
fn cmd_add(git_dir: string, repo_root: string, args: vector[string]) -> void:
    if len(args) < 2:
        println("Nothing specified, nothing added.")
        return

    i := 1
    alen := len(args)
    while i < alen:
        target := args[i]
        if target == "." or target == "*":
            working_files := collect_working_files(repo_root, "")
            j := 0
            while j < len(working_files):
                add_file_to_index(git_dir, repo_root, working_files[j])
                j = j + 1
        else:
            if fs_is_dir(target) == 1:
                dir_files := collect_working_files(target, target)
                j := 0
                while j < len(dir_files):
                    add_file_to_index(git_dir, repo_root, dir_files[j])
                    j = j + 1
            else:
                add_file_to_index(git_dir, repo_root, target)
        i = i + 1

// ------------------------------------------------------------------------------
// Function: cmd_commit
// Syntax:   fn cmd_commit(git_dir: string, repo_root: string, args: vector[string]) -> void
// Purpose:  Implements 'git commit -m' creating tree, commit object, and updating branch ref.
// ------------------------------------------------------------------------------
fn cmd_commit(git_dir: string, repo_root: string, args: vector[string]) -> void:
    msg := ""
    i := 1
    while i < len(args):
        if args[i] == "-m" and i + 1 < len(args):
            msg = args[i + 1]
            i = i + 1
        i = i + 1

    if len(msg) == 0:
        println("Aborting commit due to empty commit message.")
        return

    index_entries := read_index_file(git_dir)
    if len(index_entries) == 0:
        println("nothing to commit, working tree clean")
        return

    tree_hash := build_tree_recursive(git_dir, index_entries, "")
    parent_hash := get_head_commit(git_dir)

    author_name := "Zaid Alamgir"
    author_email := "zaid@cluster-lang.org"
    ts := 1731700000

    commit_payload := serialize_commit(tree_hash, parent_hash, author_name, author_email, ts, msg)
    commit_hash := write_git_object(git_dir, "commit", commit_payload)

    branch := get_head_branch(git_dir)
    update_branch_ref(git_dir, branch, commit_hash)

    short_hash := substring(commit_hash, 0, 7)
    is_root := ""
    if len(parent_hash) == 0:
        is_root = " (root-commit)"

    println("[" + branch + is_root + " " + short_hash + "] " + msg)
    println(" " + len(index_entries) + " file(s) changed")

// ------------------------------------------------------------------------------
// Function: cmd_log
// Syntax:   fn cmd_log(git_dir: string, args: vector[string]) -> void
// Purpose:  Implements 'git log' traversing commit DAG parent links.
// ------------------------------------------------------------------------------
fn cmd_log(git_dir: string, args: vector[string]) -> void:
    cur_hash := get_head_commit(git_dir)
    if len(cur_hash) == 0:
        println("fatal: your current branch does not have any commits yet")
        return

    oneline := 0
    max_count := 100
    i := 1
    while i < len(args):
        if args[i] == "--oneline":
            oneline = 1
        elif args[i] == "-n" and i + 1 < len(args):
            max_count = to_int(args[i + 1])
            i = i + 1
        i = i + 1

    c_yellow := chr(27) + "[33m"
    c_reset := chr(27) + "[0m"

    count := 0
    while len(cur_hash) == 40 and count < max_count:
        obj := read_git_object(git_dir, cur_hash)
        if obj.obj_type != "commit":
            return

        info := parse_commit_info(obj.content)

        if oneline == 1:
            short_h := substring(cur_hash, 0, 7)
            println(c_yellow + short_h + c_reset + " " + info.message)
        else:
            println(c_yellow + "commit " + cur_hash + c_reset)
            println("Author: " + info.author_name + " <" + info.author_email + ">")
            println("Date:   Sun Nov 15 2026 +0000\n")
            println("    " + info.message + "\n")

        cur_hash = info.parent_hash
        count = count + 1

// ------------------------------------------------------------------------------
// Function: cmd_cat_file
// Syntax:   fn cmd_cat_file(git_dir: string, args: vector[string]) -> void
// Purpose:  Implements 'git cat-file (-p | -t | -s) <hash>' pretty-printer.
// ------------------------------------------------------------------------------
fn cmd_cat_file(git_dir: string, args: vector[string]) -> void:
    if len(args) < 3:
        println("usage: cluster-git cat-file (-p | -t | -s) <object>")
        return

    flag := args[1]
    hash_arg := args[2]
    obj := read_git_object(git_dir, hash_arg)

    if obj.obj_type == "error":
        println("fatal: Not a valid object name " + hash_arg)
        return

    if flag == "-t":
        println(obj.obj_type)
    elif flag == "-s":
        println(obj.size)
    elif flag == "-p":
        if obj.obj_type == "tree":
            entries := parse_tree_entries(obj.content)
            i := 0
            while i < len(entries):
                e := entries[i]
                kind := "blob"
                if e.mode == "040000" or e.mode == "40000":
                    kind = "tree"
                println(e.mode + " " + kind + " " + e.sha1_hex + "\t" + e.name)
                i = i + 1
        else:
            print(obj.content)
            if len(obj.content) > 0 and byte_at(obj.content, len(obj.content) - 1) != 10:
                println("")

// ------------------------------------------------------------------------------
// Function: cmd_hash_object
// Syntax:   fn cmd_hash_object(git_dir: string, args: vector[string]) -> void
// Purpose:  Implements 'git hash-object [-w] <file>' computing blob SHA-1.
// ------------------------------------------------------------------------------
fn cmd_hash_object(git_dir: string, args: vector[string]) -> void:
    write_obj := 0
    file_path := ""
    i := 1
    while i < len(args):
        if args[i] == "-w":
            write_obj = 1
        else:
            file_path = args[i]
        i = i + 1

    if len(file_path) == 0 or file_exists(file_path) == 0:
        println("fatal: Cannot open " + file_path)
        return

    content := file_read(file_path)
    if write_obj == 1 and len(git_dir) > 0:
        h := write_git_object(git_dir, "blob", content)
        println(h)
    else:
        payload := format_object_payload("blob", content)
        println(sha1(payload))

// ------------------------------------------------------------------------------
// Function: cmd_write_tree
// Syntax:   fn cmd_write_tree(git_dir: string) -> void
// Purpose:  Implements 'git write-tree' creating root tree from staging index.
// ------------------------------------------------------------------------------
fn cmd_write_tree(git_dir: string) -> void:
    index_entries := read_index_file(git_dir)
    if len(index_entries) == 0:
        println("fatal: empty index")
        return
    tree_hash := build_tree_recursive(git_dir, index_entries, "")
    println(tree_hash)

// ------------------------------------------------------------------------------
// Function: cmd_branch
// Syntax:   fn cmd_branch(git_dir: string, args: vector[string]) -> void
// Purpose:  Implements 'git branch [<name>]' listing or creating branches.
// ------------------------------------------------------------------------------
fn cmd_branch(git_dir: string, args: vector[string]) -> void:
    if len(args) <= 1:
        branches := list_branches(git_dir)
        cur_branch := get_head_branch(git_dir)
        c_green := chr(27) + "[32m"
        c_reset := chr(27) + "[0m"
        i := 0
        while i < len(branches):
            b := branches[i]
            if b == cur_branch:
                println("* " + c_green + b + c_reset)
            else:
                println("  " + b)
            i = i + 1
    else:
        new_branch := args[1]
        head_commit := get_head_commit(git_dir)
        if len(head_commit) == 0:
            println("fatal: Not a valid object name: 'HEAD'.")
            return
        create_branch(git_dir, new_branch, head_commit)
        println("Created branch " + new_branch)

// ------------------------------------------------------------------------------
// Function: cmd_checkout
// Syntax:   fn cmd_checkout(git_dir: string, repo_root: string, args: vector[string]) -> void
// Purpose:  Implements 'git checkout <branch>' switching active branch.
// ------------------------------------------------------------------------------
fn cmd_checkout(git_dir: string, repo_root: string, args: vector[string]) -> void:
    if len(args) < 2:
        println("usage: cluster-git checkout <branch>")
        return

    branch := args[1]
    ref_file := git_dir + "/refs/heads/" + branch
    if file_exists(ref_file) == 0:
        println("error: pathspec '" + branch + "' did not match any file(s) known to git")
        return

    set_head_branch(git_dir, branch)
    println("Switched to branch '" + branch + "'")

// ------------------------------------------------------------------------------
// Function: cmd_diff
// Syntax:   fn cmd_diff(git_dir: string, repo_root: string) -> void
// Purpose:  Implements 'git diff' between working files and staged index.
// ------------------------------------------------------------------------------
fn cmd_diff(git_dir: string, repo_root: string) -> void:
    index_entries := read_index_file(git_dir)
    i := 0
    while i < len(index_entries):
        ie := index_entries[i]
        full_path := repo_root + "/" + ie.path
        if file_exists(full_path) == 1:
            work_content := file_read(full_path)
            blob_obj := read_git_object(git_dir, ie.sha1_hex)
            if blob_obj.content != work_content:
                print_unified_diff(ie.path, blob_obj.content, work_content, 1)
        i = i + 1

fn print_help():
    println("Cluster Git: Distributed Version Control System")
    println("Author: zk-mohammad <ZaidKhan-alamgir@proton.me>")
    println("Usage: cluster-git <command> [<args>]\n")
    println("Core Commands:")
    println("   init           Initialize a new Git repository")
    println("   status         Show the working tree status")
    println("   add            Add file contents to the staging index")
    println("   commit         Record changes to the repository")
    println("   log            Show commit logs")
    println("   diff           Show changes between commits, commit and working tree")
    println("   branch         List or create branches")
    println("   checkout       Switch branches")
    println("   hash-object    Compute object ID and optionally create a blob")
    println("   cat-file       Provide content or type/size for repository objects")
    println("   write-tree     Create a tree object from the current index")
    println("   version        Display version information")

fn main():
    args: vector[string] = sys_args
    if len(args) < 1:
        print_help()
        return

    subcmd := args[0]
    if subcmd == "-h" or subcmd == "--help" or subcmd == "help":
        print_help()
        return

    if subcmd == "-v" or subcmd == "--version" or subcmd == "version":
        println("cluster-git version 1.0.0 (Cluster native LLVM -O3)")
        println("Author: zk-mohammad <ZaidKhan-alamgir@proton.me>")
        return

    if subcmd == "init":
        cmd_init(args)
        return

    git_dir := find_git_dir(".")
    if len(git_dir) == 0:
        println("fatal: not a git repository (or any of the parent directories): .git")
        return

    repo_root := "."
    if len(git_dir) > 5:
        repo_root = substring(git_dir, 0, len(git_dir) - 5)

    if subcmd == "status":
        cmd_status(git_dir, repo_root)
    elif subcmd == "add":
        cmd_add(git_dir, repo_root, args)
    elif subcmd == "commit":
        cmd_commit(git_dir, repo_root, args)
    elif subcmd == "log":
        cmd_log(git_dir, args)
    elif subcmd == "diff":
        cmd_diff(git_dir, repo_root)
    elif subcmd == "branch":
        cmd_branch(git_dir, args)
    elif subcmd == "checkout":
        cmd_checkout(git_dir, repo_root, args)
    elif subcmd == "cat-file":
        cmd_cat_file(git_dir, args)
    elif subcmd == "hash-object":
        cmd_hash_object(git_dir, args)
    elif subcmd == "write-tree":
        cmd_write_tree(git_dir)
    else:
        println("cluster-git: '" + subcmd + "' is not a cluster-git command. See 'cluster-git --help'.")
