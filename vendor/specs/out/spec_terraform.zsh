# Termy spec-highlight: zsh assoc arrays for command "terraform"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_TERRAFORM_SUB / TS_TERRAFORM_OPT / nested TS_TERRAFORM_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_TERRAFORM_init_OPT=( ["-upgrade"]=0 ["-lock"]=1 ["-force"]=1 ["-lock-timeout"]=1 ["-input"]=1 ["-no-color"]=0 ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_validate_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_plan_OPT=( ["-compact-warnings"]=0 ["-destroy"]=0 ["-detailed-exitcode"]=0 ["-out"]=0 ["-parallelism"]=1 ["-refresh"]=1 ["-state"]=1 ["-target"]=0 ["-var"]=1 ["-var-file"]=1 ["-lock"]=1 ["-force"]=1 ["-lock-timeout"]=1 ["-input"]=1 ["-no-color"]=0 ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_apply_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_destroy_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_console_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_fmt_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_force_unlock_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_get_OPT=( ["-update"]=0 ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_graph_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_import_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_login_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_logout_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_output_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_providers_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_refresh_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_show_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_taint_OPT=( ["-allow-missing"]=0 ["-lock"]=1 ["-lock-timeout"]=1 ["-ignore-remote-version"]=1 ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
# TS_TERRAFORM_taint positional args: address
typeset -gA TS_TERRAFORM_untaint_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_workspace_new_OPT=( ["-lock"]=1 ["-lock-timeout"]=1 ["-state"]=1 ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
# TS_TERRAFORM_workspace_new positional args: workspace_name
typeset -gA TS_TERRAFORM_workspace_show_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_workspace_list_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_workspace_delete_OPT=( ["-lock"]=1 ["-force"]=1 ["-lock-timeout"]=1 ["-input"]=1 ["-no-color"]=0 )
# TS_TERRAFORM_workspace_delete positional args: workspace_name
typeset -gA TS_TERRAFORM_workspace_SUB=( ["new"]=1 ["show"]=1 ["list"]=1 ["delete"]=1 ["select"]=0 )
typeset -gA TS_TERRAFORM_workspace_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
typeset -gA TS_TERRAFORM_SUB=( ["init"]=1 ["validate"]=1 ["plan"]=1 ["apply"]=1 ["destroy"]=1 ["console"]=1 ["fmt"]=1 ["force-unlock"]=1 ["get"]=1 ["graph"]=1 ["import"]=1 ["login"]=1 ["logout"]=1 ["output"]=1 ["providers"]=1 ["refresh"]=1 ["show"]=1 ["state"]=0 ["taint"]=1 ["untaint"]=1 ["workspace"]=1 ["-install-autocomplete"]=0 ["-uninstall-autocomplete"]=0 )
typeset -gA TS_TERRAFORM_OPT=( ["-help"]=0 ["-chdir"]=1 ["-version"]=0 )
