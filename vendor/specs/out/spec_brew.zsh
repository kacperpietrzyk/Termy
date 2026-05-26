# Termy spec-highlight: zsh assoc arrays for command "brew"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_BREW_SUB / TS_BREW_OPT / nested TS_BREW_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_BREW_list_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--formulae"]=0 ["--cask"]=0 ["--casks"]=0 ["--unbrewed"]=0 ["--full-name"]=0 ["--pinned"]=0 ["--versions"]=0 ["--multiple"]=0 ["--pinned"]=0 ["-1"]=0 ["-l"]=0 ["-r"]=0 ["-t"]=0 )
# TS_BREW_list positional args: formula
typeset -gA TS_BREW_ls_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--cask"]=0 ["--unbrewed"]=0 ["--full-name"]=0 ["--pinned"]=0 ["--versions"]=0 ["--multiple"]=0 ["--pinned"]=0 ["-1"]=0 ["-l"]=0 ["-r"]=0 ["-t"]=0 )
# TS_BREW_ls positional args: formula
typeset -gA TS_BREW_leaves_OPT=( ["-r"]=0 ["--installed-on-request"]=0 ["-p"]=0 ["--installed-as-dependency"]=0 )
typeset -gA TS_BREW_doctor_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--list-checks"]=0 ["-D"]=0 ["--audit-debug"]=0 )
typeset -gA TS_BREW_abv_OPT=( ["--cask"]=0 ["--casks"]=0 ["--analytics"]=0 ["--days"]=1 ["--category"]=1 ["--github"]=0 ["--json"]=0 ["--installed"]=0 ["--all"]=0 ["-v"]=0 ["--verbose"]=0 ["--formula"]=0 ["--cash"]=0 ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-h"]=0 ["--help"]=0 )
# TS_BREW_abv positional args: formula
typeset -gA TS_BREW_update_OPT=( ["-f"]=0 ["--force"]=0 ["-v"]=0 ["--verbose"]=0 ["-d"]=0 ["--debug"]=0 ["-h"]=0 ["--help"]=0 ["--merge"]=0 ["--preinstall"]=0 )
typeset -gA TS_BREW_outdated_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--cask"]=0 ["--fetch-HEAD"]=0 ["--formula"]=0 ["--greedy"]=0 ["--greedy-latest"]=0 ["--greedy-auto-updates"]=0 ["--json"]=0 )
typeset -gA TS_BREW_pin_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 )
# TS_BREW_pin positional args: formula
typeset -gA TS_BREW_unpin_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 )
# TS_BREW_unpin positional args: formula
typeset -gA TS_BREW_upgrade_OPT=( ["-d"]=0 ["--debug"]=0 ["-f"]=0 ["--force"]=0 ["-v"]=0 ["--verbose"]=0 ["-n"]=0 ["--dry-run"]=0 ["-s"]=0 ["--build-from-source"]=0 ["-i"]=0 ["--interactive"]=0 ["-g"]=0 ["--git"]=0 ["-q"]=0 ["--quiet"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--formulae"]=0 ["--env"]=0 ["--ignore-dependencies"]=0 ["--only-dependencies"]=0 ["--cc"]=1 ["--force-bottle"]=0 ["--include-test"]=0 ["--HEAD"]=0 ["--fetch-HEAD"]=0 ["--ignore-pinned"]=0 ["--keep-tmp"]=0 ["--build-bottle"]=0 ["--bottle-arch"]=0 ["--display-times"]=0 ["--cask"]=0 ["--casks"]=0 ["--binaries"]=0 ["--no-binaries"]=0 ["--require-sha"]=0 ["--quarantine"]=0 ["--no-quarantine"]=0 ["--skip-cask-deps"]=0 ["--greedy"]=0 ["--greedy-latest"]=0 ["--greedy-auto-updates"]=0 ["--appdir"]=1 ["--colorpickerdir"]=1 ["--prefpanedir"]=1 ["--qlplugindir"]=1 ["--mdimporterdir"]=1 ["--dictionarydir"]=1 ["--fontdir"]=1 ["--servicedir"]=1 ["--input-methoddir"]=1 ["--internet-plugindir"]=1 ["--audio-unit-plugindir"]=1 ["--vst-plugindir"]=1 ["--vst3-plugindir"]=1 ["--screen-saverdir"]=1 ["--language"]=0 )
# TS_BREW_upgrade positional args: outdated_formula_outdated_cask
typeset -gA TS_BREW_search_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--cask"]=0 ["--desc"]=0 ["--pull-request"]=0 ["--open"]=0 ["--closed"]=0 ["--repology"]=0 ["--macports"]=0 ["--fink"]=0 ["--opensuse"]=0 ["--fedora"]=0 ["--debian"]=0 ["--ubuntu"]=0 )
typeset -gA TS_BREW_postinstall_OPT=( ["-d"]=0 ["--debug"]=0 ["-v"]=0 ["--verbose"]=0 ["-q"]=0 ["--quiet"]=0 ["-h"]=0 ["--help"]=0 )
# TS_BREW_postinstall positional args: formula
typeset -gA TS_BREW_install_OPT=( ["-f"]=0 ["--force"]=0 ["-v"]=0 ["--verbose"]=0 ["-s"]=0 ["--build-from-source"]=0 ["-i"]=0 ["--interactive"]=0 ["-g"]=0 ["--git"]=0 ["-q"]=0 ["--quiet"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--env"]=0 ["--ignore-dependencies"]=0 ["--only-dependencies"]=0 ["--cc"]=1 ["--force-bottle"]=0 ["--include-test"]=0 ["--HEAD"]=0 ["--fetch-HEAD"]=0 ["--keep-tmp"]=0 ["--build-bottle"]=0 ["--bottle-arch"]=0 ["--display-times"]=0 ["--cask"]=0 ["--binaries"]=0 ["--no-binaries"]=0 ["--require-sha"]=0 ["--quarantine"]=0 ["--no-quarantine"]=0 ["--skip-cask-deps"]=0 ["--appdir"]=1 ["--colorpickerdir"]=1 ["--prefpanedir"]=1 ["--qlplugindir"]=1 ["--mdimporterdir"]=1 ["--dictionarydir"]=1 ["--fontdir"]=1 ["--servicedir"]=1 ["--input-methoddir"]=1 ["--internet-plugindir"]=1 ["--audio-unit-plugindir"]=1 ["--vst-plugindir"]=1 ["--vst3-plugindir"]=1 ["--screen-saverdir"]=1 ["--language"]=0 )
# TS_BREW_install positional args: formula
typeset -gA TS_BREW_reinstall_OPT=( ["-d"]=0 ["--debug"]=0 ["-f"]=0 ["--force"]=0 ["-v"]=0 ["--verbose"]=0 ["-s"]=0 ["--build-from-source"]=0 ["-i"]=0 ["--interactive"]=0 ["-g"]=0 ["--git"]=0 ["--formula"]=0 ["--force-bottle"]=0 ["--keep-tmp"]=0 ["--display-times"]=0 ["--cask"]=0 ["--binaries"]=0 ["--no-binaries"]=0 ["--require-sha"]=0 ["--quarantine"]=0 ["--no-quarantine"]=0 ["--skip-cask-deps"]=0 )
# TS_BREW_reinstall positional args: formula
typeset -gA TS_BREW___prefix_OPT=( ["--unbrewed"]=0 ["--installed"]=0 )
# TS_BREW___prefix positional args: formula
typeset -gA TS_BREW_cask_uninstall_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--zap"]=0 ["--ignore-dependencies"]=0 ["--formula"]=0 ["--cask"]=0 )
typeset -gA TS_BREW_cask_SUB=( ["install"]=0 ["uninstall"]=1 )
typeset -gA TS_BREW_cleanup_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--prune"]=0 ["--prune=all"]=0 ["-n"]=0 ["--dry-run"]=0 ["-s"]=0 ["--prune-prefix"]=0 )
typeset -gA TS_BREW_services_run_OPT=( ["--all"]=0 )
typeset -gA TS_BREW_services_start_OPT=( ["--all"]=0 )
typeset -gA TS_BREW_services_stop_OPT=( ["--all"]=0 )
typeset -gA TS_BREW_services_restart_OPT=( ["--all"]=0 )
typeset -gA TS_BREW_services_SUB=( ["cleanup"]=0 ["list"]=0 ["run"]=1 ["start"]=1 ["stop"]=1 ["restart"]=1 )
typeset -gA TS_BREW_services_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--file"]=0 ["--all"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 )
typeset -gA TS_BREW_analytics_SUB=( ["on"]=0 ["off"]=0 ["regenerate-uuid"]=0 )
typeset -gA TS_BREW_autoremove_OPT=( ["-n"]=0 ["--dry-run"]=0 )
typeset -gA TS_BREW_tap_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--full"]=0 ["--shallow"]=0 ["--force-auto-update"]=0 ["--repair"]=0 ["--list-pinned"]=0 )
# TS_BREW_tap positional args: user_repo_or_URL
typeset -gA TS_BREW_untap_OPT=( ["-f"]=0 ["--force"]=0 ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 )
# TS_BREW_untap positional args: repository
typeset -gA TS_BREW_link_OPT=( ["--overwrite"]=0 ["-n"]=0 ["--dry-run"]=0 ["-f"]=0 ["--force"]=0 ["--HEAD"]=0 )
# TS_BREW_link positional args: formula
typeset -gA TS_BREW_unlink_OPT=( ["-n"]=0 ["--dry-run"]=0 )
# TS_BREW_unlink positional args: formula
typeset -gA TS_BREW_edit_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--formulae"]=0 ["--cask"]=0 ["--casks"]=0 )
# TS_BREW_edit positional args: formula
typeset -gA TS_BREW_home_OPT=( ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 ["--formula"]=0 ["--formulae"]=0 ["--cask"]=0 ["--casks"]=0 )
# TS_BREW_home positional args: formula
typeset -gA TS_BREW_alias_OPT=( ["--edit"]=0 ["-d"]=0 ["--debug"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["-h"]=0 ["--help"]=0 )
# TS_BREW_alias positional args: alias
typeset -gA TS_BREW_SUB=( ["list"]=1 ["ls"]=1 ["leaves"]=1 ["doctor"]=1 ["abv"]=1 ["info"]=1 ["update"]=1 ["outdated"]=1 ["pin"]=1 ["unpin"]=1 ["upgrade"]=1 ["search"]=1 ["config"]=0 ["postinstall"]=1 ["install"]=1 ["reinstall"]=1 ["uninstall"]=0 ["remove"]=0 ["rm"]=0 ["--prefix"]=1 ["cask"]=1 ["cleanup"]=1 ["services"]=1 ["analytics"]=1 ["autoremove"]=1 ["tap"]=1 ["untap"]=1 ["link"]=1 ["unlink"]=1 ["formulae"]=0 ["casks"]=0 ["edit"]=1 ["home"]=1 ["homepage"]=1 ["alias"]=1 ["developer"]=0 )
typeset -gA TS_BREW_OPT=( ["--version"]=0 )
# TS_BREW positional args: alias
