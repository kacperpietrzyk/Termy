# Termy spec-highlight: zsh assoc arrays for command "pod"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_POD_SUB / TS_POD_OPT / nested TS_POD_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_POD_deintegrate_OPT=( ["--project-directory"]=1 ["--allow-root"]=0 )
# TS_POD_deintegrate positional args: XCODE_PROJECT
typeset -gA TS_POD_cache_clean_OPT=( ["--all"]=0 ["--allow-root"]=0 )
# TS_POD_cache_clean positional args: NAME
typeset -gA TS_POD_cache_list_OPT=( ["--short"]=0 ["--allow-root"]=0 )
# TS_POD_cache_list positional args: NAME
typeset -gA TS_POD_cache_SUB=( ["clean"]=1 ["list"]=1 )
typeset -gA TS_POD_cache_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_list_OPT=( ["--update"]=0 ["--stats"]=0 ["--allow-root"]=0 )
typeset -gA TS_POD_setup_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_spec_edit_OPT=( ["--regex"]=0 ["--show-all"]=0 ["--allow-root"]=0 )
# TS_POD_spec_edit positional args: QUERY
typeset -gA TS_POD_spec_create_OPT=( ["--allow-root"]=0 )
# TS_POD_spec_create positional args: NAME_https___github_com_USER_REPO
typeset -gA TS_POD_spec_cat_OPT=( ["--regex"]=0 ["--show-all"]=0 ["--allow-root"]=0 )
# TS_POD_spec_cat positional args: QUERY
typeset -gA TS_POD_spec_which_OPT=( ["--regex"]=0 ["--show-all"]=0 ["--allow-root"]=0 )
# TS_POD_spec_which positional args: QUERY
typeset -gA TS_POD_spec_lint_OPT=( ["--quick"]=0 ["--allow-warnings"]=0 ["--subspec"]=1 ["--no-subspecs"]=0 ["--no-clean"]=0 ["--fail-fast"]=0 ["--use-libraries"]=0 ["--use-modular-headers"]=0 ["--use-static-frameworks"]=0 ["--sources"]=1 ["--platforms"]=1 ["--private"]=0 ["--swift-version"]=1 ["--skip-import-validation"]=0 ["--skip-tests"]=0 ["--test-specs"]=1 ["--analyze"]=0 ["--configuration"]=1 ["--allow-root"]=0 )
# TS_POD_spec_lint positional args: NAME_podspec_DIRECTORY_http___PATH_NAME_podspec
typeset -gA TS_POD_spec_SUB=( ["edit"]=1 ["create"]=1 ["cat"]=1 ["which"]=1 ["lint"]=1 )
typeset -gA TS_POD_spec_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_install_OPT=( ["--repo-update"]=0 ["--deployment"]=0 ["--clean-install"]=0 ["--project-directory"]=1 ["--allow-root"]=0 )
typeset -gA TS_POD_env_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_outdated_OPT=( ["--project-directory"]=1 ["--no-repo-update"]=0 ["--allow-root"]=0 )
typeset -gA TS_POD_init_OPT=( ["--allow-root"]=0 )
# TS_POD_init positional args: XCODEPROJ
typeset -gA TS_POD_ipc_list_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_ipc_update_search_index_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_ipc_podfile_json_OPT=( ["--project-directory"]=1 ["--allow-root"]=0 )
# TS_POD_ipc_podfile_json positional args: PATH
typeset -gA TS_POD_ipc_spec_OPT=( ["--allow-root"]=0 )
# TS_POD_ipc_spec positional args: PATH
typeset -gA TS_POD_ipc_podfile_OPT=( ["--project-directory"]=1 ["--allow-root"]=0 )
# TS_POD_ipc_podfile positional args: PATH
typeset -gA TS_POD_ipc_repl_OPT=( ["--project-directory"]=1 ["--allow-root"]=0 )
typeset -gA TS_POD_ipc_SUB=( ["list"]=1 ["update-search-index"]=1 ["podfile-json"]=1 ["spec"]=1 ["podfile"]=1 ["repl"]=1 )
typeset -gA TS_POD_ipc_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_plugins_search_OPT=( ["--full"]=0 ["--allow-root"]=0 )
# TS_POD_plugins_search positional args: QUERY
typeset -gA TS_POD_plugins_installed_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_plugins_create_OPT=( ["--allow-root"]=0 )
# TS_POD_plugins_create positional args: NAME TEMPLATE_URL
typeset -gA TS_POD_plugins_publish_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_plugins_SUB=( ["search"]=1 ["installed"]=1 ["create"]=1 ["publish"]=1 )
typeset -gA TS_POD_plugins_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_lib_create_OPT=( ["--template-url"]=1 ["--allow-root"]=0 )
# TS_POD_lib_create positional args: NAME
typeset -gA TS_POD_lib_lint_OPT=( ["--quick"]=0 ["--allow-warnings"]=0 ["--subspec"]=1 ["--no-subspecs"]=0 ["--no-clean"]=0 ["--fail-fast"]=0 ["--use-libraries"]=0 ["--use-modular-headers"]=0 ["--use-static-frameworks"]=0 ["--sources"]=1 ["--platforms"]=1 ["--private"]=0 ["--swift-version"]=1 ["--include-podspecs"]=1 ["--external-podspecs"]=1 ["--skip-import-validation"]=0 ["--skip-tests"]=0 ["--test-specs"]=1 ["--analyze"]=0 ["--configuration"]=1 ["--allow-root"]=0 )
# TS_POD_lib_lint positional args: PODSPEC_PATHS
typeset -gA TS_POD_lib_SUB=( ["create"]=1 ["lint"]=1 )
typeset -gA TS_POD_lib_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_search_OPT=( ["--regex"]=0 ["--simple"]=0 ["--stats"]=0 ["--web"]=0 ["--ios"]=0 ["--osx"]=0 ["--watchos"]=0 ["--tvos"]=0 ["--no-pager"]=0 ["--allow-root"]=0 )
# TS_POD_search positional args: QUERY
typeset -gA TS_POD_repo_push_OPT=( ["--allow-warnings"]=0 ["--use-libraries"]=0 ["--use-modular-headers"]=0 ["--sources"]=1 ["--local-only"]=0 ["--no-private"]=0 ["--skip-import-validation"]=0 ["--skip-tests"]=0 ["--commit-message"]=1 ["--use-json"]=0 ["--swift-version"]=1 ["--no-overwrite"]=0 ["--allow-root"]=0 )
# TS_POD_repo_push positional args: REPO NAME_podspec
typeset -gA TS_POD_repo_add_OPT=( ["--progress"]=0 ["--allow-root"]=0 )
# TS_POD_repo_add positional args: NAME URL BRANCH
typeset -gA TS_POD_repo_remove_OPT=( ["--allow-root"]=0 )
# TS_POD_repo_remove positional args: NAME
typeset -gA TS_POD_repo_add_cdn_OPT=( ["--allow-root"]=0 )
# TS_POD_repo_add_cdn positional args: NAME URL
typeset -gA TS_POD_repo_lint_OPT=( ["--only-errors"]=0 ["--allow-root"]=0 )
# TS_POD_repo_lint positional args: NAME_DIRECTORY
typeset -gA TS_POD_repo_update_OPT=( ["--allow-root"]=0 )
# TS_POD_repo_update positional args: NAME
typeset -gA TS_POD_repo_SUB=( ["push"]=1 ["add"]=1 ["remove"]=1 ["add-cdn"]=1 ["lint"]=1 ["update"]=1 )
typeset -gA TS_POD_repo_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_trunk_push_OPT=( ["--allow-warnings"]=0 ["--use-libraries"]=0 ["--use-modular-headers"]=0 ["--swift-version"]=1 ["--skip-import-validation"]=0 ["--skip-tests"]=0 ["--synchronous"]=0 ["--allow-root"]=0 )
# TS_POD_trunk_push positional args: PATH
typeset -gA TS_POD_trunk_deprecate_OPT=( ["--in-favor-of"]=1 ["--allow-root"]=0 )
# TS_POD_trunk_deprecate positional args: NAME
typeset -gA TS_POD_trunk_delete_OPT=( ["--allow-root"]=0 )
# TS_POD_trunk_delete positional args: NAME VERSION
typeset -gA TS_POD_trunk_add_owner_OPT=( ["--allow-root"]=0 )
# TS_POD_trunk_add_owner positional args: POD OWNER_EMAIL
typeset -gA TS_POD_trunk_remove_owner_OPT=( ["--allow-root"]=0 )
# TS_POD_trunk_remove_owner positional args: POD OWNER_EMAIL
typeset -gA TS_POD_trunk_me_clean_sessions_OPT=( ["--all"]=0 ["--allow-root"]=0 )
typeset -gA TS_POD_trunk_me_SUB=( ["clean-sessions"]=1 )
typeset -gA TS_POD_trunk_me_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_trunk_register_OPT=( ["--description"]=1 ["--allow-root"]=0 )
# TS_POD_trunk_register positional args: EMAIL YOUR_NAME
typeset -gA TS_POD_trunk_info_OPT=( ["--allow-root"]=0 )
# TS_POD_trunk_info positional args: NAME
typeset -gA TS_POD_trunk_SUB=( ["push"]=1 ["deprecate"]=1 ["delete"]=1 ["add-owner"]=1 ["remove-owner"]=1 ["me"]=1 ["register"]=1 ["info"]=1 )
typeset -gA TS_POD_trunk_OPT=( ["--allow-root"]=0 )
typeset -gA TS_POD_update_OPT=( ["--sources"]=1 ["--exclude-pods"]=1 ["--clean-install"]=0 ["--project-directory"]=1 ["--no-repo-update"]=0 ["--allow-root"]=0 )
# TS_POD_update positional args: POD_NAMES
typeset -gA TS_POD_try_OPT=( ["--podspec_name"]=1 ["--no-repo-update"]=0 ["--allow-root"]=0 )
# TS_POD_try positional args: NAME_URL
typeset -gA TS_POD_SUB=( ["deintegrate"]=1 ["cache"]=1 ["list"]=1 ["setup"]=1 ["spec"]=1 ["install"]=1 ["env"]=1 ["outdated"]=1 ["init"]=1 ["ipc"]=1 ["plugins"]=1 ["lib"]=1 ["search"]=1 ["repo"]=1 ["trunk"]=1 ["update"]=1 ["try"]=1 )
typeset -gA TS_POD_OPT=( ["--silent"]=0 ["--verbose"]=0 ["--no-ansi"]=0 ["--help"]=0 )
