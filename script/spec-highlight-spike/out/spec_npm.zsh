# spec-highlight-spike: zsh assoc arrays for command "npm"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_NPM_SUB / TS_NPM_OPT / nested TS_NPM_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_NPM_install_OPT=( ["-P"]=0 ["--save-prod"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-E"]=0 ["--save-exact"]=0 ["-B"]=0 ["--save-bundle"]=0 ["-g"]=0 ["--global"]=0 ["--global-style"]=0 ["--legacy-bundling"]=0 ["--legacy-peer-deps"]=0 ["--strict-peer-deps"]=0 ["--no-package-lock"]=0 ["--registry"]=1 ["--verbose"]=1 ["--omit"]=1 ["--ignore-scripts"]=0 ["--no-audit"]=0 ["--no-bin-links"]=0 ["--no-fund"]=0 ["--dry-run"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_install positional args: package
typeset -gA TS_NPM_run_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--if-present"]=0 ["--silent"]=0 ["--ignore-scripts"]=0 ["--script-shell"]=1 ["--"]=1 )
# TS_NPM_run positional args: script
typeset -gA TS_NPM_init_OPT=( ["-y"]=0 ["--yes"]=0 ["-w"]=1 )
typeset -gA TS_NPM_adduser_OPT=( ["--registry"]=1 ["--scope"]=1 )
typeset -gA TS_NPM_audit_fix_OPT=( ["--dry-run"]=0 ["-f"]=0 ["--force"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
typeset -gA TS_NPM_audit_SUB=( ["fix"]=1 )
typeset -gA TS_NPM_audit_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--audit-level"]=1 ["--package-lock-only"]=0 ["--json"]=0 ["--omit"]=1 )
typeset -gA TS_NPM_bin_OPT=( ["-g"]=0 ["--global"]=0 )
typeset -gA TS_NPM_bugs_OPT=( ["--no-browser"]=0 ["--browser"]=1 ["--registry"]=1 )
# TS_NPM_bugs positional args: package
typeset -gA TS_NPM_cache_SUB=( ["add"]=0 ["clean"]=0 ["verify"]=0 )
typeset -gA TS_NPM_cache_OPT=( ["--cache"]=1 )
typeset -gA TS_NPM_ci_OPT=( ["--audit"]=1 ["--no-audit"]=0 ["--ignore-scripts"]=0 ["--script-shell"]=1 ["--verbose"]=1 ["--registry"]=1 )
typeset -gA TS_NPM_config_set_OPT=( ["-g"]=0 ["--global"]=0 )
# TS_NPM_config_set positional args: key value
typeset -gA TS_NPM_config_list_OPT=( ["-g"]=0 ["-l"]=0 ["--json"]=0 )
typeset -gA TS_NPM_config_edit_OPT=( ["--global"]=0 )
typeset -gA TS_NPM_config_SUB=( ["set"]=1 ["get"]=0 ["list"]=1 ["delete"]=0 ["edit"]=1 )
typeset -gA TS_NPM_deprecate_OPT=( ["--registry"]=1 )
typeset -gA TS_NPM_docs_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--registry"]=1 ["--no-browser"]=0 ["--browser"]=1 )
# TS_NPM_docs positional args: package
typeset -gA TS_NPM_doctor_OPT=( ["--registry"]=1 )
typeset -gA TS_NPM_edit_OPT=( ["--editor"]=0 )
typeset -gA TS_NPM_help_OPT=( ["--viewer"]=1 )
# TS_NPM_help positional args: term
typeset -gA TS_NPM_help_search_OPT=( ["-l"]=0 ["--long"]=0 )
# TS_NPM_help_search positional args: text
typeset -gA TS_NPM_logout_OPT=( ["--registry"]=1 ["--scope"]=1 )
typeset -gA TS_NPM_ls_OPT=( ["-a"]=0 ["-all"]=0 ["--json"]=0 ["-l"]=0 ["--long"]=0 ["-p"]=0 ["--parseable"]=0 ["--depth"]=1 ["--link"]=0 ["--package-lock-only"]=0 ["--no-unicode"]=0 ["-g"]=0 ["--global"]=0 ["--omit"]=1 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_ls positional args: __scope__pkg
typeset -gA TS_NPM_org_set_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_org_set positional args: orgname username role
typeset -gA TS_NPM_org_rm_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_org_rm positional args: orgname username
typeset -gA TS_NPM_org_ls_OPT=( ["--registry"]=1 ["--otp"]=1 ["--json"]=0 ["-p"]=0 ["--parseable"]=0 )
# TS_NPM_org_ls positional args: orgname username
typeset -gA TS_NPM_org_SUB=( ["set"]=1 ["rm"]=1 ["ls"]=1 )
typeset -gA TS_NPM_outdated_OPT=( ["-a"]=0 ["-all"]=0 ["--json"]=0 ["-l"]=0 ["--long"]=0 ["-p"]=0 ["--parseable"]=0 ["-g"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_outdated positional args: ___scope____pkg_
typeset -gA TS_NPM_owner_ls_OPT=( ["--registry"]=1 )
# TS_NPM_owner_ls positional args: __scope__pkg
typeset -gA TS_NPM_owner_add_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_owner_add positional args: user __scope__pkg
typeset -gA TS_NPM_owner_rm_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_owner_rm positional args: user __scope__pkg
typeset -gA TS_NPM_owner_SUB=( ["ls"]=1 ["add"]=1 ["rm"]=1 )
typeset -gA TS_NPM_pack_OPT=( ["--json"]=0 ["--dry-run"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--pack-destination"]=1 )
# TS_NPM_pack positional args: ___scope____pkg_
typeset -gA TS_NPM_ping_OPT=( ["--registry"]=1 )
typeset -gA TS_NPM_pkg_get_OPT=( ["--json"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_pkg_get positional args: field
typeset -gA TS_NPM_pkg_set_OPT=( ["--json"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["-f"]=0 ["--force"]=0 )
# TS_NPM_pkg_set positional args: field
typeset -gA TS_NPM_pkg_delete_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["-f"]=0 ["--force"]=0 )
# TS_NPM_pkg_delete positional args: key
typeset -gA TS_NPM_pkg_SUB=( ["get"]=1 ["set"]=1 ["delete"]=1 )
typeset -gA TS_NPM_prefix_OPT=( ["-g"]=0 ["--global"]=0 )
typeset -gA TS_NPM_profile_get_OPT=( ["--registry"]=1 ["--json"]=0 ["-p"]=0 ["--parseable"]=0 ["--otp"]=1 )
# TS_NPM_profile_get positional args: property
typeset -gA TS_NPM_profile_set_SUB=( ["password"]=0 )
typeset -gA TS_NPM_profile_set_OPT=( ["--registry"]=1 ["--json"]=0 ["-p"]=0 ["--parseable"]=0 ["--otp"]=1 )
# TS_NPM_profile_set positional args: property value
typeset -gA TS_NPM_profile_enable_2fa_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_profile_enable_2fa positional args: mode
typeset -gA TS_NPM_profile_disable_2fa_OPT=( ["--registry"]=1 ["--otp"]=1 )
typeset -gA TS_NPM_profile_SUB=( ["get"]=1 ["set"]=1 ["enable-2fa"]=1 ["disable-2fa"]=1 )
typeset -gA TS_NPM_prune_OPT=( ["--omit"]=1 ["--dry-run"]=0 ["--json"]=0 ["--production"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_prune positional args: ___scope____pkg_
typeset -gA TS_NPM_publish_OPT=( ["--tag"]=1 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--access"]=1 ["--dry-run"]=0 ["--otp"]=1 )
# TS_NPM_publish positional args: tarball_folder
typeset -gA TS_NPM_rebuild_OPT=( ["-g"]=0 ["--global"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--ignore-scripts"]=0 ["--no-bin-links"]=0 )
# TS_NPM_rebuild positional args: ___scope____pkg____version__
typeset -gA TS_NPM_repo_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--no-browser"]=0 ["--browser"]=1 )
# TS_NPM_repo positional args: package
typeset -gA TS_NPM_restart_OPT=( ["--ignore-scripts"]=0 ["--script-shell"]=1 ["--"]=1 )
typeset -gA TS_NPM_root_OPT=( ["-g"]=0 ["--global"]=0 )
typeset -gA TS_NPM_search_OPT=( ["-l"]=0 ["--long"]=0 ["--json"]=0 ["--color"]=1 ["--no-color"]=0 ["-p"]=0 ["--parseable"]=0 ["--no-description"]=0 ["--searchopts"]=1 ["--searchexclude"]=1 ["--registry"]=1 ["--prefer-online"]=0 ["--prefer-offline"]=0 ["--offline"]=0 )
# TS_NPM_search positional args: search_terms
typeset -gA TS_NPM_set_script_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_set_script positional args: script command
typeset -gA TS_NPM_star_OPT=( ["--registry"]=1 ["--no-unicode"]=0 )
# TS_NPM_star positional args: pkg
typeset -gA TS_NPM_stars_OPT=( ["--registry"]=1 )
# TS_NPM_stars positional args: user
typeset -gA TS_NPM_start_OPT=( ["--ignore-scripts"]=0 ["--script-shell"]=1 ["--"]=1 )
typeset -gA TS_NPM_stop_OPT=( ["--ignore-scripts"]=0 ["--script-shell"]=1 ["--"]=1 )
typeset -gA TS_NPM_team_create_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_team_create positional args: scope_team
typeset -gA TS_NPM_team_destroy_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_team_destroy positional args: scope_team
typeset -gA TS_NPM_team_add_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_team_add positional args: scope_team user
typeset -gA TS_NPM_team_rm_OPT=( ["--registry"]=1 ["--otp"]=1 )
# TS_NPM_team_rm positional args: scope_team user
typeset -gA TS_NPM_team_ls_OPT=( ["--registry"]=1 ["--json"]=0 ["-p"]=0 ["--parseable"]=0 )
# TS_NPM_team_ls positional args: scope_scope_team
typeset -gA TS_NPM_team_SUB=( ["create"]=1 ["destroy"]=1 ["add"]=1 ["rm"]=1 ["ls"]=1 )
typeset -gA TS_NPM_test_OPT=( ["--ignore-scripts"]=0 ["--script-shell"]=1 )
typeset -gA TS_NPM_token_list_OPT=( ["--json"]=0 ["-p"]=0 ["--parseable"]=0 )
typeset -gA TS_NPM_token_create_OPT=( ["--read-only"]=0 ["--cidr"]=1 )
typeset -gA TS_NPM_token_SUB=( ["list"]=1 ["create"]=1 ["revoke"]=0 )
typeset -gA TS_NPM_token_OPT=( ["--registry"]=1 ["--otp"]=1 )
typeset -gA TS_NPM_uninstall_OPT=( ["-S"]=0 ["--save"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-g"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_uninstall positional args: package
typeset -gA TS_NPM_r_OPT=( ["-S"]=0 ["--save"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-g"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_r positional args: package
typeset -gA TS_NPM_un_OPT=( ["-S"]=0 ["--save"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-g"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_un positional args: package
typeset -gA TS_NPM_remove_OPT=( ["-S"]=0 ["--save"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-g"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_remove positional args: package
typeset -gA TS_NPM_unlink_OPT=( ["-S"]=0 ["--save"]=0 ["-D"]=0 ["--save-dev"]=0 ["-O"]=0 ["--save-optional"]=0 ["--no-save"]=0 ["-g"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_unlink positional args: package
typeset -gA TS_NPM_unpublish_OPT=( ["--dry-run"]=0 ["-f"]=0 ["--force"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
# TS_NPM_unpublish positional args: ___scope____pkg____version__
typeset -gA TS_NPM_unstar_OPT=( ["--registry"]=1 ["--otp"]=1 ["--no-unicode"]=0 )
# TS_NPM_unstar positional args: pkg
typeset -gA TS_NPM_update_OPT=( ["-g"]=0 ["--global-style"]=0 ["--legacy-bundling"]=0 ["--strict-peer-deps"]=0 ["--no-package-lock"]=0 ["--omit"]=1 ["--ignore-scripts"]=0 ["--no-audit"]=0 ["--no-bin-links"]=0 ["--no-fund"]=0 ["--save"]=0 ["--dry-run"]=0 ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 )
typeset -gA TS_NPM_version_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--json"]=0 ["--allow-same-version"]=0 ["--no-commit-hooks"]=0 ["--no-git-tag-version"]=0 ["--preid"]=1 ["--sign-git-tag"]=0 )
typeset -gA TS_NPM_view_OPT=( ["-w"]=1 ["--workspace"]=1 ["-ws"]=0 ["--workspaces"]=0 ["--json"]=0 )
typeset -gA TS_NPM_whoami_OPT=( ["--registry"]=1 )
typeset -gA TS_NPM_SUB=( ["install"]=1 ["i"]=1 ["add"]=1 ["run"]=1 ["run-script"]=1 ["init"]=1 ["access"]=0 ["adduser"]=1 ["login"]=1 ["audit"]=1 ["bin"]=1 ["bugs"]=1 ["issues"]=1 ["cache"]=1 ["ci"]=1 ["clean-install"]=1 ["install-clean"]=1 ["cit"]=0 ["clean-install-test"]=0 ["completion"]=0 ["config"]=1 ["c"]=1 ["create"]=0 ["dedupe"]=0 ["ddp"]=0 ["deprecate"]=1 ["dist-tag"]=0 ["docs"]=1 ["home"]=1 ["doctor"]=1 ["edit"]=1 ["explore"]=0 ["fund"]=0 ["get"]=0 ["help"]=1 ["help-search"]=1 ["hook"]=0 ["install-ci-test"]=0 ["install-test"]=0 ["it"]=0 ["link"]=0 ["ln"]=0 ["logout"]=1 ["ls"]=1 ["list"]=1 ["org"]=1 ["outdated"]=1 ["owner"]=1 ["author"]=1 ["pack"]=1 ["ping"]=1 ["pkg"]=1 ["prefix"]=1 ["profile"]=1 ["prune"]=1 ["publish"]=1 ["rebuild"]=1 ["rb"]=1 ["repo"]=1 ["restart"]=1 ["root"]=1 ["search"]=1 ["s"]=1 ["se"]=1 ["find"]=1 ["set"]=0 ["set-script"]=1 ["shrinkwrap"]=0 ["star"]=1 ["stars"]=1 ["start"]=1 ["stop"]=1 ["team"]=1 ["test"]=1 ["tst"]=1 ["t"]=1 ["token"]=1 ["uninstall"]=1 ["r"]=1 ["rm"]=1 ["un"]=1 ["remove"]=1 ["unlink"]=1 ["unpublish"]=1 ["unstar"]=1 ["update"]=1 ["upgrade"]=1 ["up"]=1 ["version"]=1 ["view"]=1 ["v"]=1 ["info"]=1 ["show"]=1 ["whoami"]=1 )
