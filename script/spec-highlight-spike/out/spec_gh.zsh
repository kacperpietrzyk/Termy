# spec-highlight-spike: zsh assoc arrays for command "gh"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_GH_SUB / TS_GH_OPT / nested TS_GH_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_GH_alias_set_OPT=( ["-s"]=0 ["--shell"]=0 )
# TS_GH_alias_set positional args: alias expansion
typeset -gA TS_GH_alias_SUB=( ["delete"]=0 ["list"]=0 ["set"]=1 )
typeset -gA TS_GH_auth_login_OPT=( ["-h"]=1 ["--hostname"]=1 ["-s"]=1 ["--scopes"]=1 ["-w"]=0 ["--web"]=0 ["--with-token"]=1 )
typeset -gA TS_GH_auth_logout_OPT=( ["-h"]=1 ["--hostname"]=1 )
typeset -gA TS_GH_auth_refresh_OPT=( ["-h"]=1 ["--hostname"]=1 ["-s"]=1 ["--scopes"]=1 )
typeset -gA TS_GH_auth_setup_git_OPT=( ["-h"]=1 ["--hostname"]=1 )
typeset -gA TS_GH_auth_status_OPT=( ["-h"]=1 ["--hostname"]=1 ["--with-token"]=1 )
typeset -gA TS_GH_auth_SUB=( ["login"]=1 ["logout"]=1 ["refresh"]=1 ["setup-git"]=1 ["status"]=1 )
typeset -gA TS_GH_gpg_key_SUB=( ["add"]=0 ["list"]=0 )
typeset -gA TS_GH_browse_OPT=( ["-b"]=1 ["--branch"]=1 ["-c"]=0 ["--commit"]=0 ["-n"]=0 ["--no-browser"]=0 ["-p"]=0 ["--projects"]=0 ["-R"]=1 ["--repo"]=1 ["-s"]=0 ["--settings"]=0 ["-w"]=0 ["--wiki"]=0 )
# TS_GH_browse positional args: _pr___issue___path__line_
typeset -gA TS_GH_completion_OPT=( ["-s"]=1 ["--shell"]=1 )
typeset -gA TS_GH_config_get_OPT=( ["-h"]=1 ["--host"]=1 )
# TS_GH_config_get positional args: key
typeset -gA TS_GH_config_set_SUB=( ["git_protocol"]=0 ["editor"]=0 ["prompt"]=0 ["pager"]=0 ["http_unix_socket"]=0 )
typeset -gA TS_GH_config_set_OPT=( ["-h"]=1 ["--host"]=1 )
typeset -gA TS_GH_config_SUB=( ["get"]=1 ["set"]=1 )
typeset -gA TS_GH_extensions_upgrade_OPT=( ["--all"]=0 ["--force"]=0 )
# TS_GH_extensions_upgrade positional args: name
typeset -gA TS_GH_extensions_SUB=( ["create"]=0 ["install"]=0 ["list"]=0 ["remove"]=0 ["upgrade"]=1 )
typeset -gA TS_GH_gist_create_OPT=( ["-d"]=1 ["--desc"]=1 ["-f"]=1 ["--filename"]=1 ["-p"]=0 ["--public"]=0 ["-w"]=0 ["--web"]=0 )
# TS_GH_gist_create positional args: filename
typeset -gA TS_GH_gist_edit_OPT=( ["-a"]=1 ["--add"]=1 ["-f"]=0 ["--filename"]=0 )
# TS_GH_gist_edit positional args: gist
typeset -gA TS_GH_gist_list_OPT=( ["-L"]=1 ["--limit"]=1 ["--public"]=0 ["--secret"]=0 )
typeset -gA TS_GH_gist_view_OPT=( ["-f"]=0 ["--filename"]=0 ["--files"]=0 ["-r"]=0 ["--raw"]=0 ["-w"]=0 ["--web"]=0 )
# TS_GH_gist_view positional args: gist
typeset -gA TS_GH_gist_SUB=( ["clone"]=0 ["create"]=1 ["delete"]=0 ["edit"]=1 ["list"]=1 ["view"]=1 )
typeset -gA TS_GH_issue_close_OPT=( ["-R"]=1 ["--repo"]=1 )
# TS_GH_issue_close positional args: issue
typeset -gA TS_GH_issue_comment_OPT=( ["-R"]=1 ["--repo"]=1 ["-b"]=1 ["--body"]=1 ["-F"]=1 ["--body-file"]=1 ["-e"]=1 ["--editor"]=1 ["-w"]=0 ["--web"]=0 )
# TS_GH_issue_comment positional args: issue
typeset -gA TS_GH_issue_create_OPT=( ["-R"]=1 ["--repo"]=1 ["-a"]=1 ["--assignee"]=1 ["-b"]=1 ["--body"]=1 ["-F"]=1 ["--body-file"]=1 ["-l"]=1 ["--label"]=1 ["-m"]=1 ["--milestone"]=1 ["-p"]=1 ["--project"]=1 ["--recover"]=1 ["-t"]=1 ["--title"]=1 ["-w"]=0 ["--web"]=0 )
typeset -gA TS_GH_issue_delete_OPT=( ["-R"]=1 ["--repo"]=1 )
typeset -gA TS_GH_issue_edit_OPT=( ["-R"]=1 ["--repo"]=1 ["--add-assignee"]=1 ["--add-label"]=1 ["-b"]=1 ["--body"]=1 ["-F"]=1 ["--body-file"]=1 ["-m"]=1 ["--milestone"]=1 ["--remove-assignee"]=1 ["--remove-label"]=1 ["--remove-project"]=1 ["-t"]=1 ["--title"]=1 )
# TS_GH_issue_edit positional args: issue
typeset -gA TS_GH_issue_list_OPT=( ["-R"]=1 ["--repo"]=1 ["-a"]=1 ["--assignee"]=1 ["-A"]=1 ["--author"]=1 ["-q"]=1 ["--jq"]=1 ["--json"]=1 ["-l"]=1 ["--label"]=1 ["-L"]=1 ["--limit"]=1 ["--mention"]=1 ["-m"]=1 ["--milestone"]=1 ["-S"]=1 ["--search"]=1 ["-s"]=1 ["--state"]=1 ["-t"]=1 ["--template"]=1 ["-w"]=0 ["--web"]=0 )
typeset -gA TS_GH_issue_reopen_OPT=( ["-R"]=1 ["--repo"]=1 )
typeset -gA TS_GH_issue_status_OPT=( ["-R"]=1 ["--repo"]=1 ["-q"]=1 ["--jq"]=1 ["--json"]=1 ["-t"]=1 ["--template"]=1 )
typeset -gA TS_GH_issue_transfer_OPT=( ["-R"]=1 ["--repo"]=1 )
# TS_GH_issue_transfer positional args: issue destination_repo
typeset -gA TS_GH_issue_view_OPT=( ["-R"]=1 ["--repo"]=1 ["-c"]=0 ["--comments"]=0 ["-q"]=1 ["--jq"]=1 ["--json"]=1 ["-t"]=1 ["--template"]=1 ["-w"]=0 ["--web"]=0 )
# TS_GH_issue_view positional args: issue
typeset -gA TS_GH_issue_SUB=( ["close"]=1 ["comment"]=1 ["create"]=1 ["delete"]=1 ["edit"]=1 ["list"]=1 ["reopen"]=1 ["status"]=1 ["transfer"]=1 ["view"]=1 )
typeset -gA TS_GH_pr_checkout_OPT=( ["--recurse-submodules"]=0 )
# TS_GH_pr_checkout positional args: number___url___branch
typeset -gA TS_GH_pr_checks_OPT=( ["-w"]=0 ["--web"]=0 )
# TS_GH_pr_checks positional args: number___url___branch
typeset -gA TS_GH_pr_close_OPT=( ["-d"]=0 ["--delete-branch"]=0 )
# TS_GH_pr_close positional args: number___url___branch
typeset -gA TS_GH_pr_edit_OPT=( ["--add-assignee"]=1 ["--add-label"]=1 ["--add-project"]=1 ["--add-reviewer"]=1 ["-B"]=1 ["--base"]=1 ["-b"]=1 ["--body"]=1 ["-F"]=1 ["--body-file"]=1 ["-m"]=1 ["--milestone"]=1 ["--remove-assignee"]=1 ["--remove-label"]=1 ["--remove-project"]=1 ["--remove-reviewer"]=1 ["-t"]=1 ["--title"]=1 ["--repo"]=1 ["-R"]=1 )
# TS_GH_pr_edit positional args: number___url___branch
typeset -gA TS_GH_pr_comment_OPT=( ["-b"]=1 ["--body"]=1 ["-e"]=0 ["--editor"]=0 ["-w"]=0 ["--web"]=0 )
# TS_GH_pr_comment positional args: number___url___branch
typeset -gA TS_GH_pr_create_OPT=( ["-a"]=1 ["--assignee"]=1 ["-B"]=1 ["--base"]=1 ["-b"]=1 ["--body"]=1 ["-d"]=0 ["--draft"]=0 ["-f"]=0 ["--fill"]=0 ["-H"]=1 ["--head"]=1 ["-l"]=1 ["--label"]=1 ["-m"]=1 ["--milestone"]=1 ["--no-maintainer-edit"]=0 ["-p"]=1 ["--project"]=1 ["-recover"]=1 ["-r"]=1 ["--reviewer"]=1 ["-t"]=1 ["--title"]=1 ["-w"]=0 ["--web"]=0 )
typeset -gA TS_GH_pr_diff_OPT=( ["--color"]=1 )
# TS_GH_pr_diff positional args: number___url___branch
typeset -gA TS_GH_pr_list_OPT=( ["-a"]=1 ["--assignee"]=1 ["-B"]=1 ["--base"]=1 ["-l"]=1 ["--label"]=1 ["-L"]=1 ["--limit"]=1 ["-s"]=1 ["--state"]=1 ["-w"]=1 ["--web"]=1 )
typeset -gA TS_GH_pr_merge_OPT=( ["-d"]=0 ["--delete-branch"]=0 ["-m"]=0 ["--merge"]=0 ["-r"]=0 ["--rebase"]=0 ["-s"]=0 ["--squash"]=0 )
# TS_GH_pr_merge positional args: number___url___branch
typeset -gA TS_GH_pr_review_OPT=( ["-a"]=0 ["--approve"]=0 ["-b"]=1 ["--body"]=1 ["-c"]=0 ["--comment"]=0 ["-r"]=0 ["--request-changes"]=0 )
# TS_GH_pr_review positional args: number___url___branch
typeset -gA TS_GH_pr_view_OPT=( ["-c"]=0 ["--comments"]=0 ["-w"]=0 ["--web"]=0 )
# TS_GH_pr_view positional args: number___url___branch
typeset -gA TS_GH_pr_SUB=( ["checkout"]=1 ["checks"]=1 ["close"]=1 ["edit"]=1 ["comment"]=1 ["create"]=1 ["diff"]=1 ["list"]=1 ["merge"]=1 ["ready"]=0 ["reopen"]=0 ["review"]=1 ["status"]=0 ["view"]=1 )
typeset -gA TS_GH_repo_archive_OPT=( ["-y"]=0 ["--confirm"]=0 )
# TS_GH_repo_archive positional args: repository
typeset -gA TS_GH_repo_clone_OPT=( ["--"]=1 ["-u"]=1 ["--upstream-remote-name"]=1 )
# TS_GH_repo_clone positional args: repository directory
typeset -gA TS_GH_repo_create_OPT=( ["-y"]=0 ["--confirm"]=0 ["-d"]=1 ["--description"]=1 ["-h"]=1 ["--homepage"]=1 ["--public"]=0 ["--private"]=0 ["--internal"]=0 ["-p"]=1 ["--template"]=1 ["-c"]=0 ["--clone"]=0 ["--disable-issues"]=0 ["--disable-wiki"]=0 ["-g"]=1 ["--gitignore"]=1 ["-l"]=1 ["--license"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--source"]=1 ["-t"]=1 ["--team"]=1 ["--include-all-branches"]=0 ["--push"]=0 ["--add-readme"]=0 )
# TS_GH_repo_create positional args: name
typeset -gA TS_GH_repo_deploy_key_add_OPT=( ["-w"]=0 ["--allow-write"]=0 ["-t"]=1 ["--title"]=1 )
# TS_GH_repo_deploy_key_add positional args: key_file
typeset -gA TS_GH_repo_deploy_key_SUB=( ["add"]=1 ["delete"]=0 ["list"]=0 )
typeset -gA TS_GH_repo_deploy_key_OPT=( ["-R"]=1 ["--repo"]=1 )
typeset -gA TS_GH_repo_delete_OPT=( ["-y"]=0 ["--confirm"]=0 )
# TS_GH_repo_delete positional args: repository
typeset -gA TS_GH_repo_edit_OPT=( ["--clone"]=0 ["--add-topic"]=1 ["--allow-forking"]=0 ["--default-branch"]=1 ["--delete-branch-on-merge"]=0 ["-d"]=1 ["--description"]=1 ["--enable-auto-merge"]=0 ["--enable-issues"]=0 ["--enable-merge-commit"]=0 ["--enable-projects"]=0 ["--enable-rebase-merge"]=0 ["--enable-squash-merge"]=0 ["--enable-wiki"]=0 ["-h"]=1 ["--homepage"]=1 ["--remove-topic"]=1 ["--template"]=0 ["--visibility"]=1 )
# TS_GH_repo_edit positional args: repository
typeset -gA TS_GH_repo_fork_OPT=( ["--"]=1 ["--clone"]=0 ["--remote"]=0 ["--remote-name"]=1 ["--org"]=1 ["--fork-name"]=1 )
# TS_GH_repo_fork positional args: repository
typeset -gA TS_GH_repo_list_OPT=( ["--visibility"]=1 ["--archived"]=0 ["--fork"]=0 ["-l"]=0 ["--language"]=0 ["-L"]=1 ["--limit"]=1 ["--no-archived"]=0 ["--source"]=0 ["-q"]=0 ["--jq"]=0 ["--json"]=0 ["-t"]=0 ["--template"]=0 ["--topic"]=1 ["--private"]=0 ["--public"]=0 )
# TS_GH_repo_list positional args: owner
typeset -gA TS_GH_repo_rename_OPT=( ["-y"]=0 ["--confirm"]=0 ["--repo"]=1 ["-R"]=1 ["-R"]=1 ["--repo"]=1 )
# TS_GH_repo_rename positional args: new_name
typeset -gA TS_GH_repo_set_default_OPT=( ["-u"]=0 ["--unset"]=0 ["-v"]=0 ["--view"]=0 )
# TS_GH_repo_set_default positional args: repository
typeset -gA TS_GH_repo_sync_OPT=( ["-b"]=1 ["--branch"]=1 ["--force"]=0 ["-s"]=1 ["--source"]=1 )
# TS_GH_repo_sync positional args: destination_repository
typeset -gA TS_GH_repo_view_OPT=( ["-b"]=1 ["--branch"]=1 ["-w"]=0 ["--web"]=0 ["-q"]=1 ["--jq"]=1 ["--json"]=1 ["-t"]=1 ["--template"]=1 )
# TS_GH_repo_view positional args: repository
typeset -gA TS_GH_repo_SUB=( ["archive"]=1 ["clone"]=1 ["create"]=1 ["deploy-key"]=1 ["delete"]=1 ["edit"]=1 ["fork"]=1 ["list"]=1 ["rename"]=1 ["set-default"]=1 ["sync"]=1 ["view"]=1 )
typeset -gA TS_GH_run_list_OPT=( ["--repo"]=1 ["-R"]=1 ["-L"]=1 ["--limit"]=1 ["-w"]=1 ["--workflow"]=1 )
typeset -gA TS_GH_run_rerun_OPT=( ["--repo"]=1 ["-R"]=1 )
# TS_GH_run_rerun positional args: run_id
typeset -gA TS_GH_run_view_OPT=( ["--repo"]=1 ["-R"]=1 ["--exit-status"]=0 ["-j"]=1 ["--job"]=1 ["--log"]=0 ["--log-failed"]=0 ["-v"]=0 ["--verbose"]=0 ["-w"]=0 ["--web"]=0 )
# TS_GH_run_view positional args: run_id
typeset -gA TS_GH_run_watch_OPT=( ["--repo"]=1 ["-R"]=1 ["--exit-status"]=0 ["-i"]=1 ["--interval"]=1 )
typeset -gA TS_GH_run_SUB=( ["download"]=0 ["list"]=1 ["rerun"]=1 ["view"]=1 ["watch"]=1 )
typeset -gA TS_GH_run_OPT=( ["--repo"]=1 ["-R"]=1 )
typeset -gA TS_GH_secret_list_OPT=( ["--repo"]=1 ["-R"]=1 ["-e"]=1 ["--env"]=1 ["-o"]=1 ["--org"]=1 )
typeset -gA TS_GH_secret_remove_OPT=( ["--repo"]=1 ["-R"]=1 ["-e"]=1 ["--env"]=1 ["-o"]=1 ["--org"]=1 )
typeset -gA TS_GH_secret_set_OPT=( ["--repo"]=1 ["-R"]=1 ["-e"]=1 ["--env"]=1 ["-o"]=1 ["--org"]=1 ["-b"]=1 ["--body"]=1 ["-v"]=1 ["--visibility"]=1 )
typeset -gA TS_GH_secret_SUB=( ["list"]=1 ["remove"]=1 ["set"]=1 )
typeset -gA TS_GH_secret_OPT=( ["--repo"]=1 ["-R"]=1 )
typeset -gA TS_GH_ssh_key_add_OPT=( ["--repo"]=1 ["-R"]=1 ["-t"]=0 ["--title"]=0 )
# TS_GH_ssh_key_add positional args: _key_file_
typeset -gA TS_GH_ssh_key_list_OPT=( ["--repo"]=1 ["-R"]=1 )
typeset -gA TS_GH_ssh_key_SUB=( ["add"]=1 ["list"]=1 )
typeset -gA TS_GH_workflow_disable_OPT=( ["--repo"]=1 ["-R"]=1 )
# TS_GH_workflow_disable positional args: __workflow_id_____workflow_name__
typeset -gA TS_GH_workflow_enable_OPT=( ["--repo"]=1 ["-R"]=1 )
# TS_GH_workflow_enable positional args: __workflow_id_____workflow_name__
typeset -gA TS_GH_workflow_list_OPT=( ["--repo"]=1 ["-R"]=1 ["-a"]=0 ["--all"]=0 ["-L"]=1 ["--limit"]=1 )
# TS_GH_workflow_list positional args: __workflow_id_____workflow_name__
typeset -gA TS_GH_workflow_run_OPT=( ["--repo"]=1 ["-R"]=1 ["-F"]=1 ["--field"]=1 ["--json"]=0 ["-f"]=1 ["--raw-field"]=1 ["-r"]=1 ["--ref"]=1 )
# TS_GH_workflow_run positional args: __workflow_id_____workflow_name__
typeset -gA TS_GH_workflow_view_OPT=( ["--repo"]=1 ["-R"]=1 ["-r"]=1 ["--ref"]=1 ["-w"]=0 ["--web"]=0 ["-y"]=0 ["--yaml"]=0 )
# TS_GH_workflow_view positional args: workflow_id workflow_name filename
typeset -gA TS_GH_workflow_SUB=( ["disable"]=1 ["enable"]=1 ["list"]=1 ["run"]=1 ["view"]=1 )
typeset -gA TS_GH_workflow_OPT=( ["--repo"]=1 ["-R"]=1 )
typeset -gA TS_GH_codespace_code_OPT=( ["-c"]=1 ["--codespace"]=1 ["--insiders"]=0 ["-w"]=0 ["--web"]=0 )
typeset -gA TS_GH_codespace_cp_OPT=( ["-c"]=1 ["--codespace"]=1 ["-e"]=0 ["--expand"]=0 ["-p"]=1 ["--profile"]=1 ["-r"]=0 ["--recursive"]=0 )
# TS_GH_codespace_cp positional args: sources dest
typeset -gA TS_GH_codespace_create_OPT=( ["-b"]=0 ["--branch"]=0 ["--default-permissions"]=0 ["--devcontainer-path"]=1 ["-d"]=1 ["--display-name"]=1 ["--idle-timeout"]=1 ["-l"]=1 ["--location"]=1 ["-m"]=1 ["--machine"]=1 ["-R"]=1 ["--repo"]=1 ["--retention-period"]=1 ["-s"]=0 ["--status"]=0 )
typeset -gA TS_GH_codespace_delete_OPT=( ["-c"]=1 ["--codespace"]=1 ["--all"]=0 ["--days"]=1 ["-f"]=0 ["--force"]=0 ["-o"]=1 ["--org"]=1 ["-r"]=1 ["--repo"]=1 ["-u"]=1 ["--user"]=1 )
typeset -gA TS_GH_codespace_edit_OPT=( ["-c"]=1 ["--codespace"]=1 ["-d"]=1 ["--display-name"]=1 ["-m"]=1 ["--machine"]=1 )
typeset -gA TS_GH_codespace_jupyter_OPT=( ["-c"]=1 ["--codespace"]=1 )
typeset -gA TS_GH_codespace_list_OPT=( ["-q"]=1 ["--jq"]=1 ["--json"]=1 ["-L"]=1 ["--limit"]=1 ["-o"]=1 ["--org"]=1 ["-R"]=1 ["--repo"]=1 ["-t"]=1 ["--template"]=1 ["-u"]=1 ["--user"]=1 )
typeset -gA TS_GH_codespace_logs_OPT=( ["-c"]=1 ["--codespace"]=1 ["-f"]=0 ["--follow"]=0 )
typeset -gA TS_GH_codespace_ports_forward_OPT=( ["-c"]=1 ["--codespace"]=1 )
typeset -gA TS_GH_codespace_ports_visibility_OPT=( ["-c"]=1 ["--codespace"]=1 )
typeset -gA TS_GH_codespace_ports_SUB=( ["forward"]=1 ["visibility"]=1 )
typeset -gA TS_GH_codespace_ports_OPT=( ["-c"]=1 ["--codespace"]=1 ["-q"]=1 ["--jq"]=1 ["--json"]=1 ["-t"]=1 ["--template"]=1 )
typeset -gA TS_GH_codespace_rebuild_OPT=( ["-c"]=1 ["--codespace"]=1 )
typeset -gA TS_GH_codespace_ssh_OPT=( ["-c"]=1 ["--codespace"]=1 ["--config"]=0 ["-d"]=0 ["--debug"]=0 ["--debug-file"]=1 ["--profile"]=1 ["--server-port"]=1 )
# TS_GH_codespace_ssh positional args: command
typeset -gA TS_GH_codespace_stop_OPT=( ["-c"]=1 ["--codespace"]=1 ["-o"]=1 ["--org"]=1 ["-u"]=1 ["--user"]=1 )
typeset -gA TS_GH_codespace_SUB=( ["code"]=1 ["cp"]=1 ["create"]=1 ["delete"]=1 ["edit"]=1 ["jupyter"]=1 ["list"]=1 ["logs"]=1 ["ports"]=1 ["rebuild"]=1 ["ssh"]=1 ["stop"]=1 )
typeset -gA TS_GH_project_create_OPT=( ["--title"]=1 ["--owner"]=1 ["--format"]=1 )
typeset -gA TS_GH_project_edit_OPT=( ["--title"]=1 ["-d"]=1 ["--description"]=1 ["--owner"]=1 ["--readme"]=1 ["--visibility"]=1 )
typeset -gA TS_GH_project_list_OPT=( ["--closed"]=1 ["--owner"]=1 ["-L"]=1 ["--limit"]=1 ["--format"]=1 ["--web"]=0 )
typeset -gA TS_GH_project_delete_OPT=( ["--owner"]=1 ["--format"]=1 )
typeset -gA TS_GH_project_close_OPT=( ["--owner"]=1 ["--format"]=1 ["--undo"]=0 )
typeset -gA TS_GH_project_view_OPT=( ["--owner"]=1 ["--format"]=1 ["-w"]=0 ["--web"]=0 )
typeset -gA TS_GH_project_copy_OPT=( ["--title"]=1 ["--target-owner"]=1 ["--source-owner"]=1 ["--format"]=1 ["--drafts"]=0 )
typeset -gA TS_GH_project_field_create_OPT=( ["--name"]=1 ["--data-type"]=1 ["--owner"]=1 ["--format"]=1 ["--single-select-options"]=1 )
typeset -gA TS_GH_project_field_delete_OPT=( ["--id"]=1 ["--format"]=0 )
typeset -gA TS_GH_project_field_list_OPT=( ["--owner"]=1 ["--format"]=0 ["-L"]=1 ["--limit"]=1 )
typeset -gA TS_GH_project_item_create_OPT=( ["--title"]=1 ["--body"]=1 ["--format"]=1 ["--owner"]=1 )
typeset -gA TS_GH_project_item_edit_OPT=( ["--id"]=1 ["--project-id"]=1 ["--title"]=1 ["--body"]=1 ["--format"]=1 ["--field-id"]=1 ["--iteration-id"]=1 ["--text"]=1 ["--number"]=1 ["--single-select-option-id"]=1 ["--date"]=1 )
typeset -gA TS_GH_project_item_delete_OPT=( ["--id"]=1 ["--format"]=1 ["--owner"]=1 )
typeset -gA TS_GH_project_item_list_OPT=( ["--format"]=1 ["-L"]=1 ["--limit"]=1 ["--owner"]=1 )
typeset -gA TS_GH_project_item_add_OPT=( ["--url"]=1 ["--owner"]=1 ["--format"]=1 )
typeset -gA TS_GH_project_item_archive_OPT=( ["--id"]=1 ["--format"]=1 ["--owner"]=1 ["--undo"]=0 )
typeset -gA TS_GH_project_SUB=( ["create"]=1 ["edit"]=1 ["list"]=1 ["delete"]=1 ["close"]=1 ["view"]=1 ["copy"]=1 ["field-create"]=1 ["field-delete"]=1 ["field-list"]=1 ["item-create"]=1 ["item-edit"]=1 ["item-delete"]=1 ["item-list"]=1 ["item-add"]=1 ["item-archive"]=1 )
typeset -gA TS_GH_SUB=( ["alias"]=1 ["api"]=0 ["auth"]=1 ["gpg-key"]=1 ["browse"]=1 ["completion"]=1 ["config"]=1 ["extensions"]=1 ["gist"]=1 ["issue"]=1 ["pr"]=1 ["release"]=0 ["repo"]=1 ["run"]=1 ["secret"]=1 ["ssh-key"]=1 ["workflow"]=1 ["codespace"]=1 ["cs"]=1 ["project"]=1 )
typeset -gA TS_GH_OPT=( ["--help"]=0 )
# TS_GH positional args: alias
