// ============================================================================
//  cluster-git: Repository & Reference Engine (src/repository.cl)
//  Git Repository Layout, HEAD Tracking, and Branch Management
// ============================================================================

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

fn get_head_branch(git_dir: string) -> string:
    head_file := git_dir + "/HEAD"
    if file_exists(head_file) == 0:
        return "main"

    raw := file_read(head_file)
    // Strip trailing newlines
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

    // If HEAD is detached 40-char hash
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
