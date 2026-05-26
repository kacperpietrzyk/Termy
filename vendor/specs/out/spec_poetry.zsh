# Termy spec-highlight: zsh assoc arrays for command "poetry"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_POETRY_SUB / TS_POETRY_OPT / nested TS_POETRY_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_POETRY_about_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_POETRY_add_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--group"]=0 ["--dev"]=0 ["--editable"]=0 ["--extras"]=0 ["--optional"]=0 ["--python"]=0 ["--platform"]=0 ["--source"]=0 ["--allow-prereleases"]=0 ["--dry-run"]=0 ["--lock"]=0 )
# TS_POETRY_add positional args: name
typeset -gA TS_POETRY_build_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--format"]=0 )
typeset -gA TS_POETRY_cache_clear_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--all"]=0 )
# TS_POETRY_cache_clear positional args: cache
typeset -gA TS_POETRY_cache_list_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_POETRY_cache_SUB=( ["clear"]=1 ["list"]=1 )
typeset -gA TS_POETRY_check_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_POETRY_config_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--list"]=0 ["--unset"]=0 ["--local"]=0 )
# TS_POETRY_config positional args: key value
typeset -gA TS_POETRY_debug_info_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_POETRY_debug_resolve_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--extras"]=0 ["--python"]=0 ["--tree"]=0 ["--install"]=0 )
# TS_POETRY_debug_resolve positional args: package
typeset -gA TS_POETRY_debug_SUB=( ["info"]=1 ["resolve"]=1 )
typeset -gA TS_POETRY_env_info_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--path"]=0 ["--executable"]=0 )
typeset -gA TS_POETRY_env_list_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--full-path"]=0 )
typeset -gA TS_POETRY_env_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--all"]=0 )
# TS_POETRY_env_remove positional args: python
typeset -gA TS_POETRY_env_use_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_POETRY_env_use positional args: python
typeset -gA TS_POETRY_env_SUB=( ["info"]=1 ["list"]=1 ["remove"]=1 ["use"]=1 )
typeset -gA TS_POETRY_init_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--name"]=0 ["--description"]=0 ["--author"]=0 ["--python"]=0 ["--dependency"]=0 ["--dev-dependency"]=0 ["--license"]=0 )
typeset -gA TS_POETRY_install_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--without"]=0 ["--with"]=0 ["--only"]=0 ["--no-dev"]=0 ["--sync"]=0 ["--no-root"]=0 ["--no-directory"]=0 ["--dry-run"]=0 ["--remove-untracked"]=0 ["--extras"]=0 ["--all-extras"]=0 ["--only-root"]=0 ["--compile"]=0 )
typeset -gA TS_POETRY_lock_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--no-update"]=0 ["--check"]=0 )
typeset -gA TS_POETRY_new_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--name"]=0 ["--src"]=0 ["--readme"]=0 )
# TS_POETRY_new positional args: path
typeset -gA TS_POETRY_publish_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--repository"]=0 ["--username"]=0 ["--password"]=0 ["--cert"]=0 ["--client-cert"]=0 ["--build"]=0 ["--dry-run"]=0 ["--skip-existing"]=0 )
typeset -gA TS_POETRY_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--group"]=0 ["--dev"]=0 ["--dry-run"]=0 ["--lock"]=0 )
# TS_POETRY_remove positional args: packages
typeset -gA TS_POETRY_run_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_POETRY_run positional args: args
typeset -gA TS_POETRY_search_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_POETRY_search positional args: tokens
typeset -gA TS_POETRY_self_add_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--editable"]=0 ["--extras"]=0 ["--source"]=0 ["--allow-prereleases"]=0 ["--dry-run"]=0 )
# TS_POETRY_self_add positional args: name
typeset -gA TS_POETRY_self_install_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--sync"]=0 ["--dry-run"]=0 )
typeset -gA TS_POETRY_self_lock_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--no-update"]=0 ["--check"]=0 )
typeset -gA TS_POETRY_self_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--dry-run"]=0 )
# TS_POETRY_self_remove positional args: packages
typeset -gA TS_POETRY_self_show_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--addons"]=0 ["--tree"]=0 ["--latest"]=0 ["--outdated"]=0 )
# TS_POETRY_self_show positional args: package
typeset -gA TS_POETRY_self_update_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--preview"]=0 ["--dry-run"]=0 )
# TS_POETRY_self_update positional args: version
typeset -gA TS_POETRY_self_SUB=( ["add"]=1 ["install"]=1 ["lock"]=1 ["remove"]=1 ["show"]=1 ["update"]=1 )
typeset -gA TS_POETRY_shell_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_POETRY_show_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--without"]=0 ["--with"]=0 ["--only"]=0 ["--no-dev"]=0 ["--tree"]=0 ["--why"]=0 ["--latest"]=0 ["--outdated"]=0 ["--all"]=0 ["--top-level"]=0 )
# TS_POETRY_show positional args: package
typeset -gA TS_POETRY_source_add_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--default"]=0 ["--secondary"]=0 ["--priority"]=0 )
# TS_POETRY_source_add positional args: name url
typeset -gA TS_POETRY_source_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_POETRY_source_remove positional args: name
typeset -gA TS_POETRY_source_show_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_POETRY_source_show positional args: source
typeset -gA TS_POETRY_source_SUB=( ["add"]=1 ["remove"]=1 ["show"]=1 )
typeset -gA TS_POETRY_update_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--without"]=0 ["--with"]=0 ["--only"]=0 ["--no-dev"]=0 ["--dry-run"]=0 ["--lock"]=0 )
# TS_POETRY_update positional args: packages
typeset -gA TS_POETRY_version_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 ["--short"]=0 ["--dry-run"]=0 )
# TS_POETRY_version positional args: version
typeset -gA TS_POETRY_SUB=( ["about"]=1 ["add"]=1 ["build"]=1 ["cache"]=1 ["check"]=1 ["config"]=1 ["debug"]=1 ["env"]=1 ["init"]=1 ["install"]=1 ["lock"]=1 ["new"]=1 ["publish"]=1 ["remove"]=1 ["run"]=1 ["search"]=1 ["self"]=1 ["shell"]=1 ["show"]=1 ["source"]=1 ["update"]=1 ["version"]=1 )
typeset -gA TS_POETRY_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-vv"]=0 ["-vvv"]=0 ["-V"]=0 ["--version"]=0 ["--ansi"]=0 ["--no-ansi"]=0 ["-n"]=0 ["--no-interaction"]=0 ["--no-plugins"]=0 ["--no-cache"]=0 ["--directory"]=1 ["-q"]=0 ["--quiet"]=0 )
