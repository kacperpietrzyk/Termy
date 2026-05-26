# Termy spec-highlight: zsh assoc arrays for command "fastlane"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_FASTLANE_SUB / TS_FASTLANE_OPT / nested TS_FASTLANE_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_FASTLANE_init_SUB=( ["swift"]=0 )
typeset -gA TS_FASTLANE_init_OPT=( ["-u"]=1 ["--user"]=1 )
typeset -gA TS_FASTLANE_docs_OPT=( ["-f"]=0 ["--force"]=0 )
typeset -gA TS_FASTLANE_enable_auto_complete_OPT=( ["-c"]=1 ["--custom"]=1 )
typeset -gA TS_FASTLANE_list_OPT=( ["-j"]=0 ["--json"]=0 )
typeset -gA TS_FASTLANE_new_action_OPT=( ["--name"]=1 )
typeset -gA TS_FASTLANE_socket_server_OPT=( ["-s"]=0 ["--stay_alive"]=0 ["-c"]=1 ["--connection_timeout"]=1 ["-p"]=1 ["--port"]=1 )
typeset -gA TS_FASTLANE_trigger_OPT=( ["--disable_runner_upgrades"]=0 ["--swift_server_port"]=1 )
# TS_FASTLANE_trigger positional args: lane
typeset -gA TS_FASTLANE_SUB=( ["init"]=1 ["action"]=0 ["actions"]=0 ["add_plugin"]=0 ["docs"]=1 ["enable_auto_complete"]=1 ["env"]=0 ["help"]=0 ["install_plugins"]=0 ["lanes"]=0 ["list"]=1 ["new_action"]=1 ["new_plugin"]=0 ["run"]=0 ["search_plugins"]=0 ["socket_server"]=1 ["trigger"]=1 ["update_fastlane"]=0 ["update_plugins"]=0 )
typeset -gA TS_FASTLANE_OPT=( ["--platform"]=1 ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--version"]=0 ["--verbose"]=0 ["--capture_output"]=0 ["--troubleshoot"]=0 ["--env"]=0 )
