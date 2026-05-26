# Termy spec-highlight: zsh assoc arrays for command "pnpm"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_PNPM_SUB / TS_PNPM_OPT / nested TS_PNPM_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_PNPM_add_OPT=( ["--offline"]=0 ["--prefer-offline"]=0 ["--ignore-scripts"]=0 ["--reporter"]=1 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-E"]=0 ["--save-exact"]=0 ["--save-peer"]=0 ["--ignore-workspace-root-check"]=0 ["-W#"]=0 ["--global"]=0 ["-g"]=0 ["--workspace"]=0 ["--filter"]=1 )
# TS_PNPM_add positional args: package
typeset -gA TS_PNPM_install_test_OPT=( ["--offline"]=0 ["--prefer-offline"]=0 ["--ignore-scripts"]=0 ["--reporter"]=1 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["--no-optional"]=0 ["--lockfile-only"]=0 ["--frozen-lockfile"]=0 ["--use-store-server"]=0 ["--shamefully-hoist"]=0 )
typeset -gA TS_PNPM_update_OPT=( ["--recursive"]=0 ["-r"]=0 ["--latest"]=0 ["-L"]=0 ["--global"]=0 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["--no-optional"]=0 ["--interactive"]=0 ["-i"]=0 ["--workspace"]=0 ["--filter"]=1 )
# TS_PNPM_update positional args: Package
typeset -gA TS_PNPM_remove_OPT=( ["--recursive"]=0 ["-r"]=0 ["--global"]=0 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["--save-optional"]=0 ["-O"]=0 ["--filter"]=1 )
# TS_PNPM_remove positional args: Package
typeset -gA TS_PNPM_link_OPT=( ["--dir"]=0 ["-C"]=0 ["--global"]=0 )
# TS_PNPM_link positional args: Package arg
typeset -gA TS_PNPM_unlink_OPT=( ["--recursive"]=0 ["-r"]=0 ["--filter"]=1 )
# TS_PNPM_unlink positional args: Package arg
typeset -gA TS_PNPM_rebuild_OPT=( ["--recursive"]=0 ["-r"]=0 ["--filter"]=1 )
# TS_PNPM_rebuild positional args: Package arg
typeset -gA TS_PNPM_prune_OPT=( ["--prod"]=0 ["--no-optional"]=0 )
typeset -gA TS_PNPM_fetch_OPT=( ["--prod"]=0 ["--dev"]=0 )
typeset -gA TS_PNPM_patch_OPT=( ["--edit-dir"]=0 )
# TS_PNPM_patch positional args: package
typeset -gA TS_PNPM_audit_OPT=( ["--audit-level"]=1 ["--fix"]=0 ["--json"]=0 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--no-optional"]=0 ["--ignore-registry-errors"]=0 )
typeset -gA TS_PNPM_list_OPT=( ["--recursive"]=0 ["-r"]=0 ["--json"]=0 ["--long"]=0 ["--parseable"]=0 ["--global"]=0 ["--depth"]=1 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--no-optional"]=0 ["--filter"]=1 )
typeset -gA TS_PNPM_outdated_OPT=( ["--recursive"]=0 ["-r"]=0 ["--long"]=0 ["--global"]=0 ["--no-table"]=0 ["--compatible"]=0 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--no-optional"]=0 )
typeset -gA TS_PNPM_why_OPT=( ["--recursive"]=0 ["-r"]=0 ["--json"]=0 ["--long"]=0 ["--parseable"]=0 ["--global"]=0 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--filter"]=1 )
# TS_PNPM_why positional args: Scripts
typeset -gA TS_PNPM_run_OPT=( ["-r"]=0 ["--recursive"]=0 ["--if-present"]=0 ["--parallel"]=0 ["--stream"]=0 ["--filter"]=1 )
# TS_PNPM_run positional args: Scripts
typeset -gA TS_PNPM_exec_OPT=( ["-r"]=0 ["--recursive"]=0 ["--parallel"]=0 ["--filter"]=1 )
# TS_PNPM_exec positional args: Scripts
typeset -gA TS_PNPM_publish_OPT=( ["--tag"]=1 ["--dry-run"]=0 ["--ignore-scripts"]=0 ["--no-git-checks"]=0 ["--access"]=1 ["--force"]=0 ["--report-summary"]=0 ["--filter"]=1 )
# TS_PNPM_publish positional args: Branch
typeset -gA TS_PNPM_recursive_add_OPT=( ["--offline"]=0 ["--prefer-offline"]=0 ["--ignore-scripts"]=0 ["--reporter"]=1 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-E"]=0 ["--save-exact"]=0 ["--save-peer"]=0 ["--ignore-workspace-root-check"]=0 ["-W#"]=0 ["--global"]=0 ["-g"]=0 ["--workspace"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_add positional args: package
typeset -gA TS_PNPM_recursive_update_OPT=( ["--recursive"]=0 ["-r"]=0 ["--latest"]=0 ["-L"]=0 ["--global"]=0 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["--no-optional"]=0 ["--interactive"]=0 ["-i"]=0 ["--workspace"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_update positional args: Package
typeset -gA TS_PNPM_recursive_remove_OPT=( ["--recursive"]=0 ["-r"]=0 ["--global"]=0 ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["--save-optional"]=0 ["-O"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_remove positional args: Package
typeset -gA TS_PNPM_recursive_unlink_OPT=( ["--recursive"]=0 ["-r"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_unlink positional args: Package arg
typeset -gA TS_PNPM_recursive_rebuild_OPT=( ["--recursive"]=0 ["-r"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_rebuild positional args: Package arg
typeset -gA TS_PNPM_recursive_list_OPT=( ["--recursive"]=0 ["-r"]=0 ["--json"]=0 ["--long"]=0 ["--parseable"]=0 ["--global"]=0 ["--depth"]=1 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--no-optional"]=0 ["--filter"]=1 )
typeset -gA TS_PNPM_recursive_outdated_OPT=( ["--recursive"]=0 ["-r"]=0 ["--long"]=0 ["--global"]=0 ["--no-table"]=0 ["--compatible"]=0 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--no-optional"]=0 )
typeset -gA TS_PNPM_recursive_why_OPT=( ["--recursive"]=0 ["-r"]=0 ["--json"]=0 ["--long"]=0 ["--parseable"]=0 ["--global"]=0 ["--dev"]=0 ["-D"]=0 ["--prod"]=0 ["-P"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_why positional args: Scripts
typeset -gA TS_PNPM_recursive_run_OPT=( ["-r"]=0 ["--recursive"]=0 ["--if-present"]=0 ["--parallel"]=0 ["--stream"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_run positional args: Scripts
typeset -gA TS_PNPM_recursive_exec_OPT=( ["-r"]=0 ["--recursive"]=0 ["--parallel"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_exec positional args: Scripts
typeset -gA TS_PNPM_recursive_publish_OPT=( ["--tag"]=1 ["--dry-run"]=0 ["--ignore-scripts"]=0 ["--no-git-checks"]=0 ["--access"]=1 ["--force"]=0 ["--report-summary"]=0 ["--filter"]=1 )
# TS_PNPM_recursive_publish positional args: Branch
typeset -gA TS_PNPM_recursive_SUB=( ["add"]=1 ["install"]=0 ["i"]=0 ["update"]=1 ["upgrade"]=1 ["up"]=1 ["remove"]=1 ["rm"]=1 ["uninstall"]=1 ["un"]=1 ["unlink"]=1 ["rebuild"]=1 ["rb"]=1 ["list"]=1 ["ls"]=1 ["outdated"]=1 ["why"]=1 ["run"]=1 ["run-script"]=1 ["exec"]=1 ["test"]=0 ["t"]=0 ["tst"]=0 ["publish"]=1 )
typeset -gA TS_PNPM_recursive_OPT=( ["--link-workspace-packages"]=1 ["--workspace-concurrency"]=1 ["--bail"]=0 ["--no-bail"]=0 ["--sort"]=0 ["--no-sort"]=0 ["--reverse"]=0 ["--filter"]=1 )
typeset -gA TS_PNPM_server_start_OPT=( ["--background"]=0 ["--network-concurrency"]=1 ["--protocol"]=1 ["--port"]=1 ["--store-dir"]=1 ["--lock"]=0 ["--no-lock"]=0 ["--ignore-stop-requests"]=0 ["--ignore-upload-requests"]=0 )
typeset -gA TS_PNPM_server_SUB=( ["start"]=1 ["stop"]=0 ["status"]=0 )
typeset -gA TS_PNPM_store_SUB=( ["status"]=0 ["add"]=0 ["prune"]=0 ["path"]=0 )
typeset -gA TS_PNPM_SUB=( ["add"]=1 ["install"]=0 ["i"]=0 ["install-test"]=1 ["it"]=1 ["update"]=1 ["upgrade"]=1 ["up"]=1 ["remove"]=1 ["rm"]=1 ["uninstall"]=1 ["un"]=1 ["link"]=1 ["ln"]=1 ["unlink"]=1 ["import"]=0 ["rebuild"]=1 ["rb"]=1 ["prune"]=1 ["fetch"]=1 ["patch"]=1 ["patch-commit"]=0 ["patch-remove"]=0 ["audit"]=1 ["list"]=1 ["ls"]=1 ["outdated"]=1 ["why"]=1 ["run"]=1 ["run-script"]=1 ["exec"]=1 ["test"]=0 ["t"]=0 ["tst"]=0 ["start"]=0 ["publish"]=1 ["recursive"]=1 ["m"]=1 ["multi"]=1 ["-r"]=1 ["server"]=1 ["store"]=1 ["init"]=0 ["doctor"]=0 )
typeset -gA TS_PNPM_OPT=( ["-C"]=1 ["--dir"]=1 ["-w"]=1 ["--workspace-root"]=1 ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--version"]=0 )
# TS_PNPM positional args: Scripts
