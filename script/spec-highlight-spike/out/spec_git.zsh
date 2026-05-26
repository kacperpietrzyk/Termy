# spec-highlight-spike: zsh assoc arrays for command "git"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_GIT_SUB / TS_GIT_OPT / nested TS_GIT_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_GIT_archive_OPT=( ["--format"]=1 ["--prefix"]=1 ["--add-file"]=1 ["-o"]=1 ["--output"]=1 ["--worktree-attributes"]=0 ["-v"]=0 ["--verbose"]=0 ["-NUM"]=0 ["-l"]=0 ["--list"]=0 ["--remote"]=1 ["--exec"]=1 )
# TS_GIT_archive positional args: tree_ish path
typeset -gA TS_GIT_blame_OPT=( ["--incremental"]=0 ["-b"]=0 ["--root"]=0 ["--show-stats"]=0 ["--progress"]=0 ["--score-debug"]=0 ["-f"]=0 ["--show-name"]=0 ["-n"]=0 ["--show-number"]=0 ["-p"]=0 ["--porcelain"]=0 ["--line-porcelain"]=0 ["-c"]=0 ["-t"]=0 ["-l"]=0 ["-s"]=0 ["-e"]=0 ["--show-email"]=0 ["-w"]=0 ["--ignore-rev"]=1 ["--ignore-revs-file"]=1 ["--color-lines"]=0 ["--color-by-age"]=0 ["--minimal"]=0 ["-S"]=1 ["--contents"]=1 ["-C"]=0 ["-M"]=0 ["-L"]=1 ["--abbrev"]=1 )
# TS_GIT_blame positional args: file
typeset -gA TS_GIT_commit_OPT=( ["-m"]=1 ["--message"]=1 ["-a"]=0 ["--all"]=0 ["-am"]=1 ["-v"]=0 ["--verbose"]=0 ["-p"]=0 ["--patch"]=0 ["-C"]=1 ["--reuse-message"]=1 ["-c"]=1 ["--reedit-message"]=1 ["--fixup"]=1 ["--squash"]=1 ["--reset-author"]=0 ["--short"]=0 ["--branch"]=0 ["--porcelain"]=0 ["--long"]=0 ["-z"]=0 ["--null"]=0 ["-F"]=1 ["--file"]=1 ["--author"]=1 ["--date"]=1 ["-t"]=1 ["--template"]=1 ["-s"]=0 ["--signoff"]=0 ["--no-signoff"]=0 ["-n"]=0 ["--no-verify"]=0 ["--allow-empty"]=0 ["--allow-empty-message"]=0 ["--cleanup"]=1 ["-e"]=0 ["--edit"]=0 ["--no-edit"]=0 ["--amend"]=0 ["--no-post-rewrite"]=0 ["-i"]=0 ["--include"]=0 ["-o"]=0 ["--only"]=0 ["--pathspec-from-file"]=1 ["--pathspec-file-nul"]=0 ["-u"]=1 ["--untracked-files"]=1 ["-q"]=0 ["--quiet"]=0 ["--dry-run"]=0 ["--status"]=0 ["--no-status"]=0 ["-S"]=1 ["--gpg-sign"]=1 ["--no-gpg-sign"]=0 ["--"]=0 )
# TS_GIT_commit positional args: pathspec
typeset -gA TS_GIT_config_OPT=( ["--local"]=1 ["--global"]=0 ["--replace-all"]=0 ["--add"]=0 ["--get"]=0 ["--get-all"]=0 ["--get-regexp"]=1 ["--get-urlmatch"]=1 ["--system"]=0 ["--worktree"]=0 ["-f"]=1 ["--file"]=1 ["--blob"]=1 ["--remove-section"]=0 ["--rename-section"]=0 ["--unset"]=0 ["--unset-all"]=0 ["-l"]=0 ["--list"]=0 ["--fixed-value"]=0 ["--type"]=1 ["--no-type"]=0 ["-z"]=0 ["--null"]=0 ["--name-only"]=0 ["--show-origin"]=0 ["--show-scope"]=0 ["--get-colorbool"]=1 ["--get-color"]=1 ["-e"]=0 ["--edit"]=0 ["--includes"]=0 ["--no-includes"]=0 ["--default"]=1 )
# TS_GIT_config positional args: setting value
typeset -gA TS_GIT_rebase_OPT=( ["--onto"]=1 ["--keep-base"]=0 ["--continue"]=0 ["--abort"]=0 ["--quit"]=0 ["--apply"]=0 ["--empty"]=1 ["--no-keep-empty"]=0 ["--keep-empty"]=0 ["--reapply-cherry-picks"]=0 ["--no-reapply-cherry-picks"]=0 ["--allow-empty-message"]=0 ["--skip"]=0 ["--edit-todo"]=0 ["--show-current-patch"]=0 ["-m"]=0 ["--merge"]=0 ["-s"]=1 ["--strategy"]=1 ["-X"]=1 ["--strategy-option"]=1 ["--rerere-autoupdate"]=0 ["--no-rerere-autoupdate"]=0 ["-S"]=1 ["--gpg-sign"]=1 ["--no-gpg-sign"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--stat"]=0 ["-n"]=0 ["--no-stat"]=0 ["--no-verify"]=0 ["--verify"]=0 ["-C"]=1 ["--no-ff"]=0 ["--force-rebase"]=0 ["-f"]=0 ["--fork-point"]=0 ["--no-fork-point"]=0 ["--ignore-whitespace"]=0 ["--whitespace"]=1 ["--committer-date-is-author-date"]=0 ["--ignore-date"]=0 ["--reset-author-date"]=0 ["--signoff"]=0 ["-i"]=0 ["--interactive"]=0 ["-r"]=1 ["--rebase-merges"]=1 ["-x"]=1 ["--exec"]=1 ["--root"]=0 ["--autosquash"]=0 ["--no-autosquash"]=0 ["--autostash"]=0 ["--no-autostash"]=0 ["--reschedule-failed-exec"]=0 ["--no-reschedule-failed-exec"]=0 )
# TS_GIT_rebase positional args: base new_base
typeset -gA TS_GIT_add_OPT=( ["-n"]=0 ["--dry-run"]=0 ["-v"]=0 ["--verbose"]=0 ["-f"]=0 ["--force"]=0 ["-i"]=0 ["--interactive"]=0 ["-p"]=0 ["--patch"]=0 ["-e"]=0 ["--edit"]=0 ["-u"]=0 ["--update"]=0 ["-A"]=0 ["--all"]=0 ["--no-ignore-removal"]=0 ["--no-all"]=0 ["--ignore-removal"]=0 ["-N"]=0 ["--intent-to-add"]=0 ["--refresh"]=0 ["--ignore-errors"]=0 ["--ignore-missing"]=0 ["--no-warn-embedded-repo"]=0 ["--renormalize"]=0 ["--chmod"]=1 ["--pathspec-from-file"]=1 ["--pathspec-file-nul"]=0 ["--"]=0 )
# TS_GIT_add positional args: pathspec
typeset -gA TS_GIT_stage_OPT=( ["-n"]=0 ["--dry-run"]=0 ["-v"]=0 ["--verbose"]=0 ["-f"]=0 ["--force"]=0 ["-i"]=0 ["--interactive"]=0 ["-p"]=0 ["--patch"]=0 ["-e"]=0 ["--edit"]=0 ["-u"]=0 ["--update"]=0 ["-A"]=0 ["--all"]=0 ["--no-ignore-removal"]=0 ["--no-all"]=0 ["--ignore-removal"]=0 ["-N"]=0 ["--intent-to-add"]=0 ["--refresh"]=0 ["--ignore-errors"]=0 ["--ignore-missing"]=0 ["--no-warn-embedded-repo"]=0 ["--renormalize"]=0 ["--chmod"]=1 ["--pathspec-from-file"]=1 ["--pathspec-file-nul"]=0 ["--"]=0 )
# TS_GIT_stage positional args: pathspec
typeset -gA TS_GIT_status_OPT=( ["-s"]=0 ["--short"]=0 ["-v"]=0 ["--verbose"]=0 ["-b"]=0 ["--branch"]=0 ["--show-stash"]=0 ["--porcelain"]=1 ["--ahead-behind"]=0 ["--no-ahead-behind"]=0 ["--column"]=1 ["--no-column"]=1 ["--long"]=0 ["-z"]=0 ["--null"]=0 ["-u"]=1 ["--untracked-files"]=1 ["--ignore-submodules"]=1 ["--ignored"]=1 ["--no-renames"]=0 ["--renames"]=0 ["--find-renames"]=1 )
# TS_GIT_status positional args: pathspec
typeset -gA TS_GIT_clean_OPT=( ["-d"]=0 ["-f"]=0 ["--force"]=0 ["-i"]=0 ["--interactive"]=0 ["-n"]=0 ["--dry-run"]=0 ["-q"]=0 ["--quiet"]=0 ["-e"]=1 ["--exclude"]=1 ["-x"]=0 ["-X"]=0 )
# TS_GIT_clean positional args: path
typeset -gA TS_GIT_push_OPT=( ["--all"]=0 ["--prune"]=0 ["--mirror"]=0 ["-n"]=0 ["--dry-run"]=0 ["--porcelain"]=0 ["-d"]=0 ["--delete"]=0 ["--tags"]=0 ["--follow-tags"]=0 ["--signed"]=1 ["--no-signed"]=0 ["--atomic"]=0 ["--no-atomic"]=0 ["-f"]=0 ["--force"]=0 ["--repo"]=1 ["-u"]=0 ["--set-upstream"]=0 ["--thin"]=0 ["--no-thin"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--progress"]=0 ["--no-recurse-submodules"]=0 ["--recurse-submodules"]=1 ["--verify"]=0 ["--no-verify"]=0 ["-4"]=0 ["--ipv4"]=0 ["-6"]=0 ["--ipv6"]=0 ["-o"]=1 ["--push-option"]=1 ["--receive-pack"]=1 ["--exec"]=1 ["--no-force-with-lease"]=0 ["--force-with-lease"]=1 )
# TS_GIT_push positional args: remote branch
typeset -gA TS_GIT_pull_OPT=( ["--rebase"]=1 ["-r"]=1 ["--no-rebase"]=0 ["--commit"]=0 ["--no-commit"]=0 ["--edit"]=0 ["-e"]=0 ["--no-edit"]=0 ["--cleanup"]=1 ["--ff"]=0 ["--no-ff"]=0 ["--ff-only"]=0 ["-S"]=1 ["--gpg-sign"]=1 ["--no-gpg-sign"]=0 ["--log"]=1 ["--no-log"]=0 ["--signoff"]=0 ["--no-signoff"]=0 ["--stat"]=0 ["-n"]=0 ["--no-stat"]=0 ["--squash"]=0 ["--no-squash"]=0 ["--no-verify"]=0 ["-s"]=1 ["--strategy"]=1 ["-X"]=1 ["--strategy-option"]=1 ["--verify-signatures"]=0 ["--no-verify-signatures"]=0 ["--summary"]=0 ["--no-summary"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--autostash"]=0 ["--no-autostash"]=0 ["--allow-unrelated-histories"]=0 ["--all"]=0 ["-a"]=0 ["--append"]=0 ["--atomic"]=0 ["--depth"]=1 ["--deepen"]=1 ["--shallow-since"]=1 ["--shallow-exclude"]=1 ["--unshallow"]=0 ["--update-shallow"]=0 ["--negotiation-tip"]=1 ["--dry-run"]=0 ["-f"]=0 ["--force"]=0 ["-k"]=0 ["--keep"]=0 ["-p"]=0 ["--prune"]=0 ["-P"]=0 ["--prune-tags"]=0 ["--no-tags"]=0 ["--refmap"]=1 ["-t"]=0 ["--tags"]=0 ["--recurse-submodules"]=1 ["--no-recurse-submodules"]=0 ["-j"]=1 ["--jobs"]=1 ["--set-upstream"]=0 ["--upload-pack"]=1 ["--progress"]=0 ["-o"]=1 ["--server-option"]=1 ["--show-forced-updates"]=0 ["--no-show-forced-updates"]=0 ["-4"]=0 ["--ipv4"]=0 ["-6"]=0 ["--ipv6"]=0 )
# TS_GIT_pull positional args: remote branch
typeset -gA TS_GIT_diff_OPT=( ["--staged"]=0 ["--cached"]=0 ["--help"]=0 ["--numstat"]=0 ["--name-only"]=0 ["--shortstat"]=0 ["--stat"]=1 ["--"]=1 )
# TS_GIT_diff positional args: commit_or_file
typeset -gA TS_GIT_reset_OPT=( ["--keep"]=0 ["--soft"]=0 ["--hard"]=0 ["--mixed"]=0 ["-N"]=0 ["--merge"]=0 ["-q"]=0 ["--quiet"]=0 ["--no-quiet"]=0 ["--pathspec-from-file"]=1 ["--pathspec-file-nul"]=0 ["-p"]=0 ["--patch"]=0 )
typeset -gA TS_GIT_log_OPT=( ["--follow"]=1 ["-q"]=0 ["--quiet"]=0 ["--show-signature"]=0 ["--source"]=0 ["--oneline"]=0 ["-p"]=0 ["-u"]=0 ["--patch"]=0 ["--stat"]=0 ["--grep"]=1 ["--author"]=1 )
# TS_GIT_log positional args: since until
typeset -gA TS_GIT_remote_add_OPT=( ["-t"]=1 ["-m"]=1 ["-f"]=0 ["--tags"]=0 ["--no-tags"]=0 ["--mirror"]=1 )
# TS_GIT_remote_add positional args: name repository_url
typeset -gA TS_GIT_remote_set_head_OPT=( ["--auto"]=0 ["-a"]=0 ["--delete"]=0 ["-d"]=0 )
# TS_GIT_remote_set_head positional args: name branch
typeset -gA TS_GIT_remote_set_branches_OPT=( ["--add"]=0 )
# TS_GIT_remote_set_branches positional args: name branch
typeset -gA TS_GIT_remote_get_url_OPT=( ["--push"]=0 ["--all"]=0 )
# TS_GIT_remote_get_url positional args: name
typeset -gA TS_GIT_remote_set_url_OPT=( ["--push"]=0 ["--add"]=0 ["--delete"]=0 )
# TS_GIT_remote_set_url positional args: name newurl oldurl
typeset -gA TS_GIT_remote_show_OPT=( ["-n"]=0 )
# TS_GIT_remote_show positional args: name
typeset -gA TS_GIT_remote_prune_OPT=( ["-n"]=0 ["--dry-run"]=0 )
# TS_GIT_remote_prune positional args: name
typeset -gA TS_GIT_remote_update_OPT=( ["-p"]=0 ["--prune"]=0 )
# TS_GIT_remote_update positional args: group remote
typeset -gA TS_GIT_remote_SUB=( ["add"]=1 ["set-head"]=1 ["set-branches"]=1 ["rm"]=0 ["remove"]=0 ["rename"]=0 ["get-url"]=1 ["set-url"]=1 ["show"]=1 ["prune"]=1 ["update"]=1 )
typeset -gA TS_GIT_remote_OPT=( ["-v"]=0 ["--verbose"]=0 )
typeset -gA TS_GIT_fetch_OPT=( ["--all"]=0 ["-a"]=0 ["--append"]=0 ["--atomic"]=0 ["--depth"]=1 ["--deepen"]=1 ["--shallow-since"]=1 ["--shallow-exclude"]=1 ["--unshallow"]=0 ["--update-shallow"]=0 ["--negotiation-tip"]=1 ["--dry-run"]=0 ["--write-fetch-head"]=0 ["--no-write-fetch-head"]=0 ["-f"]=0 ["--force"]=0 ["-k"]=0 ["--keep"]=0 ["--multiple"]=0 ["--auto-maintenance"]=0 ["--auto-gc"]=0 ["--no-auto-maintenance"]=0 ["--no-auto-gc"]=0 ["--write-commit-graph"]=0 ["--no-write-commit-graph"]=0 ["-p"]=0 ["--prune"]=0 ["-P"]=0 ["--prune-tags"]=0 ["-n"]=0 ["--no-tags"]=0 ["--refmap"]=1 ["-t"]=0 ["--tags"]=0 ["--recurse-submodules"]=1 ["-j"]=1 ["--jobs"]=1 ["--no-recurse-submodules"]=0 ["--set-upstream"]=0 ["--submodule-prefix"]=1 ["--recurse-submodules-default"]=1 ["-u"]=0 ["--update-head-ok"]=0 ["--upload-pack"]=1 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--progress"]=0 ["-o"]=1 ["--server-option"]=1 ["--show-forced-updates"]=0 ["--no-show-forced-updates"]=0 ["-4"]=0 ["--ipv4"]=0 ["-6"]=0 ["--ipv6"]=0 ["--stdin"]=0 )
# TS_GIT_fetch positional args: remote branch refspec
typeset -gA TS_GIT_stash_push_OPT=( ["-p"]=0 ["--patch"]=0 ["-k"]=0 ["--keep-index"]=0 ["-u"]=0 ["--include-untracked"]=0 ["-a"]=0 ["--all"]=0 ["-q"]=0 ["--quiet"]=0 ["-m"]=1 ["--message"]=1 ["--pathspec-from-file"]=0 ["--"]=0 )
typeset -gA TS_GIT_stash_save_OPT=( ["-p"]=0 ["--patch"]=0 ["-k"]=0 ["--keep-index"]=0 ["-u"]=0 ["--include-untracked"]=0 ["-a"]=0 ["--all"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_GIT_stash_save positional args: message
typeset -gA TS_GIT_stash_pop_OPT=( ["--index"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_GIT_stash_pop positional args: stash
typeset -gA TS_GIT_stash_drop_OPT=( ["-q"]=0 ["--quiet"]=0 )
# TS_GIT_stash_drop positional args: stash
typeset -gA TS_GIT_stash_apply_OPT=( ["--index"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_GIT_stash_apply positional args: stash
typeset -gA TS_GIT_stash_store_OPT=( ["-m"]=1 ["--message"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_GIT_stash_store positional args: message commit
typeset -gA TS_GIT_stash_SUB=( ["push"]=1 ["show"]=0 ["save"]=1 ["pop"]=1 ["list"]=0 ["drop"]=1 ["clear"]=0 ["apply"]=1 ["branch"]=0 ["create"]=0 ["store"]=1 )
typeset -gA TS_GIT_reflog_OPT=( ["--relative-date"]=0 ["--all"]=0 )
typeset -gA TS_GIT_clone_OPT=( ["-l"]=0 ["--local"]=0 ["--no-hardlinks"]=0 ["-s"]=0 ["--shared"]=0 ["--dry-run"]=0 ["--reference"]=1 ["--reference-if-able"]=1 ["--dissociate"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--progress"]=0 ["--server-option"]=1 ["-n"]=0 ["--no-checkout"]=0 ["--bare"]=0 ["--sparse"]=0 ["--filter"]=1 ["--mirror"]=0 ["-o"]=1 ["--origin"]=1 ["-b"]=1 ["--branch"]=1 ["-u"]=1 ["--upload-pack"]=1 ["--template"]=1 ["-c"]=1 ["--config"]=1 ["--depth"]=1 ["--shallow-since"]=1 ["--shallow-exclude"]=1 ["--single-branch"]=0 ["--no-single-branch"]=0 ["--no-tags"]=0 ["--recurse-submodules"]=1 ["--shallow-submodules"]=0 ["--no-shallow-submodules"]=0 ["--remote-submodules"]=0 ["--no-remote-submodules"]=0 ["-j"]=1 ["--jobs"]=1 ["--separate-git-dir"]=1 )
# TS_GIT_clone positional args: repository directory
typeset -gA TS_GIT_init_OPT=( ["-q"]=0 ["--quiet"]=0 ["--bare"]=0 ["--object-format"]=1 ["--template"]=1 ["--separate-git-dir"]=1 ["-b"]=1 ["--initial-branch"]=1 ["--shared"]=1 )
# TS_GIT_init positional args: directory
typeset -gA TS_GIT_mv_OPT=( ["-f"]=0 ["--force"]=0 ["-k"]=0 ["-n"]=0 ["--dry-run"]=0 ["-v"]=0 ["--verbose"]=0 )
# TS_GIT_mv positional args: source destination
typeset -gA TS_GIT_rm_OPT=( ["--"]=0 ["--cached"]=0 ["-f"]=0 ["--force"]=0 ["-n"]=0 ["--dry-run"]=0 ["-r"]=0 )
typeset -gA TS_GIT_bisect_start_OPT=( ["--term-new"]=1 ["--term-bad"]=1 ["--term-good"]=1 ["--term-old"]=1 ["--no-checkout"]=0 ["--first-parent"]=0 ["--"]=0 )
# TS_GIT_bisect_start positional args: bad good
typeset -gA TS_GIT_bisect_terms_OPT=( ["--term-old"]=0 ["--term-good"]=0 )
typeset -gA TS_GIT_bisect_SUB=( ["start"]=1 ["bad"]=0 ["new"]=0 ["old"]=0 ["good"]=0 ["next"]=0 ["terms"]=1 ["skip"]=0 ["reset"]=0 ["visualize"]=0 ["view"]=0 ["replay"]=0 ["log"]=0 ["run"]=0 ["help"]=0 )
# TS_GIT_bisect positional args: paths
typeset -gA TS_GIT_branch_OPT=( ["-a"]=0 ["--all"]=0 ["-d"]=1 ["--delete"]=1 ["-D"]=1 ["-m"]=1 ["--move"]=1 ["-M"]=1 ["-c"]=0 ["--copy"]=0 ["-C"]=0 ["-l"]=0 ["--list"]=0 ["--create-reflog"]=0 ["--edit-description"]=1 ["-f"]=0 ["--force"]=0 ["--merged"]=1 ["--no-merged"]=1 ["--column"]=0 ["--no-column"]=0 ["--sort"]=1 ["--points-at"]=1 ["-i"]=0 ["--ignore-case"]=0 ["--format"]=1 ["-r"]=0 ["--remotes"]=0 ["--show-current"]=0 ["-v"]=0 ["--verbose"]=0 ["-q"]=0 ["--quiet"]=0 ["--abbrev"]=1 ["--no-abbrev"]=0 ["-t"]=1 ["--track"]=1 ["--no-track"]=1 ["-u"]=1 ["--set-upstream-to"]=1 ["--unset-upstream"]=1 ["--contains"]=1 ["--no-contains"]=1 ["--color"]=1 ["--no-color"]=0 )
typeset -gA TS_GIT_checkout_OPT=( ["-q"]=0 ["--quiet"]=0 ["--progress"]=0 ["--no-progress"]=0 ["-f"]=0 ["--force"]=0 ["-2"]=0 ["--ours"]=0 ["-3"]=0 ["--theirs"]=0 ["-b"]=1 ["-B"]=1 ["-t"]=0 ["--track"]=0 ["--no-track"]=0 ["--guess"]=0 ["--no-guess"]=0 ["-l"]=0 ["-d"]=0 ["--detach"]=0 ["--orphan"]=1 ["--ignore-skip-worktree-bits"]=0 ["-m"]=0 ["--merge"]=0 ["--conflict"]=1 ["-p"]=0 ["--patch"]=0 ["--ignore-other-worktrees"]=0 ["--overwrite-ignore"]=0 ["--no-overwrite-ignore"]=0 ["--recurse-submodules"]=0 ["--no-recurse-submodules"]=0 ["--overlay"]=0 ["--no-overlay"]=0 ["--pathspec-from-file"]=1 ["--pathspec-file-nul"]=0 )
# TS_GIT_checkout positional args: branch__file__tag_or_commit pathspec
typeset -gA TS_GIT_cherry_pick_OPT=( ["--continue"]=0 ["--skip"]=0 ["--quit"]=0 ["--abort"]=0 ["-e"]=0 ["--edit"]=0 ["--cleanup"]=1 ["-x"]=0 ["-m"]=1 ["--mainline"]=1 ["-n"]=0 ["--no-commit"]=0 ["-s"]=0 ["--signoff"]=0 ["-S"]=1 ["--gpg-sign"]=1 ["--no-gpg-sign"]=0 ["--ff"]=0 ["--allow-empty"]=0 ["--allow-empty-message"]=0 ["--keep-redundant-commits"]=0 ["--strategy"]=1 ["-X"]=1 ["--strategy-option"]=1 ["--rerere-autoupdate"]=0 ["--no-rerere-autoupdate"]=0 )
# TS_GIT_cherry_pick positional args: commit
typeset -gA TS_GIT_submodule_add_OPT=( ["-b"]=1 ["-f"]=0 ["--force"]=0 ["--name"]=1 ["--reference"]=1 ["--depth"]=1 ["--"]=0 )
# TS_GIT_submodule_add positional args: repository path
typeset -gA TS_GIT_submodule_status_OPT=( ["--cached"]=0 ["--recursive"]=0 ["--"]=0 )
# TS_GIT_submodule_status positional args: path
typeset -gA TS_GIT_submodule_init_OPT=( ["--"]=0 )
# TS_GIT_submodule_init positional args: path
typeset -gA TS_GIT_submodule_deinit_OPT=( ["-f"]=0 ["--force"]=0 ["--all"]=0 ["--"]=0 )
# TS_GIT_submodule_deinit positional args: path
typeset -gA TS_GIT_submodule_update_OPT=( ["--init"]=0 ["--remote"]=0 ["-N"]=0 ["--no-fetch"]=0 ["--no-recommend-shallow"]=0 ["--recommend-shallow"]=0 ["-f"]=0 ["--force"]=0 ["--checkout"]=0 ["--rebase"]=0 ["--merge"]=0 ["--reference"]=1 ["--depth"]=1 ["--recursive"]=0 ["--jobs"]=1 ["--single-branch"]=0 ["--no-single-branch"]=0 ["--"]=0 )
# TS_GIT_submodule_update positional args: path
typeset -gA TS_GIT_submodule_set_branch_OPT=( ["-b"]=1 ["--branch"]=1 ["-d"]=0 ["--default"]=0 ["--"]=0 )
# TS_GIT_submodule_set_branch positional args: path
typeset -gA TS_GIT_submodule_set_url_OPT=( ["--"]=0 )
# TS_GIT_submodule_set_url positional args: path newurl
typeset -gA TS_GIT_submodule_summary_OPT=( ["--cached"]=0 ["--files"]=0 ["-n"]=1 ["--summary-limit"]=1 ["--"]=0 )
# TS_GIT_submodule_summary positional args: commit path
typeset -gA TS_GIT_submodule_foreach_OPT=( ["--recursive"]=0 )
# TS_GIT_submodule_foreach positional args: command
typeset -gA TS_GIT_submodule_sync_OPT=( ["--recursive"]=0 ["--"]=0 )
# TS_GIT_submodule_sync positional args: path
typeset -gA TS_GIT_submodule_SUB=( ["add"]=1 ["status"]=1 ["init"]=1 ["deinit"]=1 ["update"]=1 ["set-branch"]=1 ["set-url"]=1 ["summary"]=1 ["foreach"]=1 ["sync"]=1 ["absorbgitdirs"]=0 )
typeset -gA TS_GIT_submodule_OPT=( ["-q"]=0 ["--quiet"]=0 ["--cached"]=0 )
typeset -gA TS_GIT_merge_OPT=( ["--commit"]=0 ["--no-commit"]=0 ["--edit"]=0 ["-e"]=0 ["--no-edit"]=0 ["--cleanup"]=1 ["--ff"]=0 ["--no-ff"]=0 ["--ff-only"]=0 ["-S"]=1 ["--gpg-sign"]=1 ["--no-gpg-sign"]=0 ["--log"]=1 ["--no-log"]=0 ["--signoff"]=0 ["--no-signoff"]=0 ["--stat"]=0 ["-n"]=0 ["--no-stat"]=0 ["--squash"]=0 ["--no-squash"]=0 ["--no-verify"]=0 ["-s"]=1 ["--strategy"]=1 ["-X"]=1 ["--strategy-option"]=1 ["--verify-signatures"]=0 ["--no-verify-signatures"]=0 ["--summary"]=0 ["--no-summary"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--progress"]=0 ["--no-progress"]=0 ["--autostash"]=0 ["--no-autostash"]=0 ["--allow-unrelated-histories"]=0 ["-m"]=1 ["-F"]=1 ["--file"]=1 ["--rerere-autoupdate"]=0 ["--no-rerere-autoupdate"]=0 ["--overwrite-ignore"]=0 ["--no-overwrite-ignore"]=0 ["--abort"]=0 ["--quit"]=0 ["--continue"]=0 )
# TS_GIT_merge positional args: branch
typeset -gA TS_GIT_tag_OPT=( ["-l"]=0 ["--list"]=0 ["-n"]=1 ["-d"]=0 ["--delete"]=0 ["-v"]=0 ["--verify"]=0 ["-a"]=0 ["--annotate"]=0 ["-m"]=1 ["--message"]=1 ["--points-at"]=1 )
# TS_GIT_tag positional args: tagname
typeset -gA TS_GIT_restore_OPT=( ["-s"]=1 ["--source"]=1 ["-p"]=0 ["--patch"]=0 ["-W"]=0 ["--worktree"]=0 ["-S"]=0 ["--staged"]=0 ["-q"]=0 ["--quiet"]=0 ["--progress"]=0 ["--no-progress"]=0 ["-2"]=0 ["--ours"]=0 ["-3"]=0 ["--theirs"]=0 ["-m"]=0 ["--merge"]=0 ["--conflict"]=1 ["--ignore-unmerged"]=0 ["--ignore-skip-worktree-bits"]=0 ["--recurse-submodules"]=0 ["--no-recurse-submodules"]=0 ["--overlay"]=0 ["--no-overlay"]=0 ["--pathspec-from-file"]=1 ["--pathspec-file-nul"]=0 ["--"]=0 )
# TS_GIT_restore positional args: pathspec
typeset -gA TS_GIT_switch_OPT=( ["-c"]=1 ["--create"]=1 ["-C"]=1 ["--force-create"]=1 ["-d"]=0 ["--detach"]=0 ["--guess"]=0 ["--no-guess"]=0 ["-f"]=0 ["--force"]=0 ["--discard-changes"]=0 ["-m"]=0 ["--merge"]=0 ["--conflict"]=1 ["-q"]=0 ["--quiet"]=0 ["--progress"]=0 ["--no-progress"]=0 ["-t"]=1 ["--track"]=1 ["--no-track"]=1 ["--orphan"]=1 ["--ignore-other-worktrees"]=0 ["--recurse-submodules"]=0 ["--no-recurse-submodules"]=0 )
# TS_GIT_switch positional args: branch_name start_point
typeset -gA TS_GIT_worktree_add_OPT=( ["-f"]=0 ["--force"]=0 ["-d"]=0 ["--detach"]=0 ["--checkout"]=0 ["--lock"]=0 ["-b"]=1 ["-B"]=1 )
typeset -gA TS_GIT_worktree_list_OPT=( ["--porcelain"]=0 ["-v"]=0 ["--verbose"]=0 ["--expire"]=1 )
typeset -gA TS_GIT_worktree_lock_OPT=( ["--reason"]=1 )
# TS_GIT_worktree_lock positional args: worktree
typeset -gA TS_GIT_worktree_move_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_GIT_worktree_move positional args: worktree new_path
typeset -gA TS_GIT_worktree_prune_OPT=( ["-n"]=0 ["--dry-run"]=0 ["-v"]=0 ["--verbose"]=0 ["--expire"]=1 )
typeset -gA TS_GIT_worktree_remove_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_GIT_worktree_remove positional args: worktree
typeset -gA TS_GIT_worktree_SUB=( ["add"]=1 ["list"]=1 ["lock"]=1 ["move"]=1 ["prune"]=1 ["remove"]=1 ["repair"]=0 ["unlock"]=0 )
typeset -gA TS_GIT_apply_OPT=( ["--exclude"]=1 ["--include"]=1 ["-p"]=1 ["--no-add"]=0 ["--stat"]=0 ["--numstat"]=0 ["--summary"]=0 ["--check"]=0 ["--index"]=0 ["-N"]=0 ["--intent-to-add"]=0 ["--cached"]=0 ["--unsafe-paths"]=0 ["--apply"]=0 ["-3"]=0 ["--3way"]=0 ["--build-fake-ancestor"]=1 ["-z"]=0 ["-C"]=1 ["--whitespace"]=1 ["--ignore-space-change"]=0 ["--ignore-whitespace"]=0 ["-R"]=0 ["--reverse"]=0 ["--unidiff-zero"]=0 ["--reject"]=0 ["--allow-overlap"]=0 ["-v"]=0 ["--verbose"]=0 ["--inaccurate-eof"]=0 ["--recount"]=0 ["--directory"]=1 )
# TS_GIT_apply positional args: patch
typeset -gA TS_GIT_daemon_OPT=( ["--strict-paths"]=0 ["--base-path"]=1 ["--base-path-relaxed"]=0 ["--interpolated-path"]=1 ["--export-all"]=0 ["--inetd"]=0 ["--listen"]=1 ["--port"]=1 ["--init-timeout"]=1 ["--max-connections"]=1 ["--syslog"]=0 ["--log-destination"]=1 ["--user-path"]=1 ["--verbose"]=0 ["--detach"]=0 ["--pid-file"]=1 ["--user"]=1 ["--group"]=0 ["--enable"]=1 ["--disable"]=1 ["--allow-override"]=1 ["--forbid-override"]=1 ["--informative-errors"]=0 ["--no-informative-errors"]=0 ["--access-hook"]=1 )
# TS_GIT_daemon positional args: directory
typeset -gA TS_GIT_SUB=( ["archive"]=1 ["blame"]=1 ["commit"]=1 ["config"]=1 ["rebase"]=1 ["add"]=1 ["stage"]=1 ["status"]=1 ["clean"]=1 ["revert"]=0 ["ls-remote"]=0 ["push"]=1 ["pull"]=1 ["diff"]=1 ["reset"]=1 ["log"]=1 ["remote"]=1 ["fetch"]=1 ["stash"]=1 ["reflog"]=1 ["clone"]=1 ["init"]=1 ["mv"]=1 ["rm"]=1 ["bisect"]=1 ["grep"]=0 ["show"]=0 ["branch"]=1 ["checkout"]=1 ["cherry-pick"]=1 ["submodule"]=1 ["merge"]=1 ["mergetool"]=0 ["tag"]=1 ["restore"]=1 ["switch"]=1 ["worktree"]=1 ["apply"]=1 ["daemon"]=1 )
typeset -gA TS_GIT_OPT=( ["--version"]=0 ["--help"]=0 ["-C"]=1 ["-c"]=1 ["--exec-path"]=1 ["--html-path"]=0 ["--man-path"]=0 ["--info-path"]=0 ["-p"]=0 ["--paginate"]=0 ["--no-pager"]=0 ["--no-replace-objects"]=0 ["--no-optional-locks"]=0 ["--bare"]=0 ["--git-dir"]=1 ["--work-tree"]=1 ["--namespace"]=1 )
# TS_GIT positional args: alias
