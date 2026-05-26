# Termy spec-highlight: zsh assoc arrays for command "rustup"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_RUSTUP_SUB / TS_RUSTUP_OPT / nested TS_RUSTUP_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_RUSTUP_show_SUB=( ["active-toolchain"]=0 ["home"]=0 ["profile"]=0 ["keys"]=0 ["help"]=0 )
typeset -gA TS_RUSTUP_show_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_update_OPT=( ["--force"]=0 ["--force-non-host"]=0 ["-h"]=0 ["--help"]=0 ["--no-self-update"]=0 )
# TS_RUSTUP_update positional args: toolchain
typeset -gA TS_RUSTUP_check_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_RUSTUP_check positional args: toolchain
typeset -gA TS_RUSTUP_default_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_RUSTUP_default positional args: toolchain
typeset -gA TS_RUSTUP_target_list_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_target_add_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 ["--toolchain"]=1 )
# TS_RUSTUP_target_add positional args: target
typeset -gA TS_RUSTUP_target_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 ["--toolchain"]=1 )
# TS_RUSTUP_target_remove positional args: target
typeset -gA TS_RUSTUP_target_help_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
# TS_RUSTUP_target_help positional args: subcommand
typeset -gA TS_RUSTUP_target_SUB=( ["list"]=1 ["add"]=1 ["remove"]=1 ["help"]=1 )
typeset -gA TS_RUSTUP_target_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_toolchain_list_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_toolchain_install_OPT=( ["-h"]=0 ["--help"]=0 ["-t"]=1 ["--target"]=1 ["-c"]=1 ["--component"]=1 ["--profile"]=1 ["--allow-downgrade"]=0 ["--force"]=0 ["--no-self-update"]=0 )
# TS_RUSTUP_toolchain_install positional args: toolchain
typeset -gA TS_RUSTUP_toolchain_uninstall_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_RUSTUP_toolchain_uninstall positional args: toolchain
typeset -gA TS_RUSTUP_toolchain_link_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_RUSTUP_toolchain_link positional args: toolchain path
typeset -gA TS_RUSTUP_toolchain_help_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
# TS_RUSTUP_toolchain_help positional args: subcommand
typeset -gA TS_RUSTUP_toolchain_SUB=( ["list"]=1 ["install"]=1 ["uninstall"]=1 ["link"]=1 ["help"]=1 )
typeset -gA TS_RUSTUP_toolchain_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_component_list_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_component_add_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_component_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_component_SUB=( ["list"]=1 ["add"]=1 ["remove"]=1 ["help"]=0 )
typeset -gA TS_RUSTUP_component_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_override_list_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_override_set_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
# TS_RUSTUP_override_set positional args: toolchain
typeset -gA TS_RUSTUP_override_unset_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_override_SUB=( ["list"]=1 ["set"]=1 ["unset"]=1 ["help"]=0 )
typeset -gA TS_RUSTUP_override_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_run_OPT=( ["-h"]=0 ["--help"]=0 ["--install"]=0 )
# TS_RUSTUP_run positional args: toolchain command
typeset -gA TS_RUSTUP_which_OPT=( ["-h"]=0 ["--help"]=0 ["--toolchain"]=1 )
typeset -gA TS_RUSTUP_doc_OPT=( ["--alloc"]=0 ["--book"]=0 ["--cargo"]=0 ["--core"]=0 ["--edition-guide"]=0 ["--embedded-book"]=0 ["-h"]=0 ["--help"]=0 ["--nomicon"]=0 ["--path"]=0 ["--proc_macro"]=0 ["--reference"]=0 ["--rust-by-example"]=0 ["--rustc"]=0 ["--rustdoc"]=0 ["--std"]=0 ["--test"]=0 ["--unstable-book"]=0 ["--toolchain"]=1 )
# TS_RUSTUP_doc positional args: topic
typeset -gA TS_RUSTUP_man_OPT=( ["-h"]=0 ["--help"]=0 ["--toolchain"]=1 )
typeset -gA TS_RUSTUP_self_update_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_self_uninstall_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_self_upgrade_data_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
typeset -gA TS_RUSTUP_self_SUB=( ["update"]=1 ["uninstall"]=1 ["upgrade-data"]=1 ["help"]=0 )
typeset -gA TS_RUSTUP_self_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_set_auto_self_update_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
# TS_RUSTUP_set_auto_self_update positional args: auto_self_update_mode
typeset -gA TS_RUSTUP_set_default_host_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
# TS_RUSTUP_set_default_host positional args: host_triple
typeset -gA TS_RUSTUP_set_SUB=( ["auto-self-update"]=1 ["default-host"]=1 )
typeset -gA TS_RUSTUP_set_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_RUSTUP_completions_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_RUSTUP_completions positional args: shell command
typeset -gA TS_RUSTUP_SUB=( ["show"]=1 ["update"]=1 ["check"]=1 ["default"]=1 ["target"]=1 ["toolchain"]=1 ["component"]=1 ["override"]=1 ["run"]=1 ["which"]=1 ["doc"]=1 ["man"]=1 ["self"]=1 ["set"]=1 ["completions"]=1 ["help"]=0 )
typeset -gA TS_RUSTUP_OPT=( ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 )
# TS_RUSTUP positional args: toolchain
