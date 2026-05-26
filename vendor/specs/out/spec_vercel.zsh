# Termy spec-highlight: zsh assoc arrays for command "vercel"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_VERCEL_SUB / TS_VERCEL_OPT / nested TS_VERCEL_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_VERCEL_dev_OPT=( ["--listen"]=0 )
typeset -gA TS_VERCEL_env_SUB=( ["add"]=0 ["rm"]=0 ["pull"]=0 ["ls"]=0 )
typeset -gA TS_VERCEL_list_OPT=( ["-m"]=1 ["--meta"]=1 )
# TS_VERCEL_list positional args: project_name
typeset -gA TS_VERCEL_rm_OPT=( ["-s"]=0 ["--safe"]=0 ["-y"]=0 ["--yes"]=0 )
# TS_VERCEL_rm positional args: deployment_url
typeset -gA TS_VERCEL_domains_SUB=( ["ls"]=0 ["inspect"]=0 ["add"]=0 ["rm"]=0 ["buy"]=0 ["move"]=0 ["transfer-in"]=0 ["verify"]=0 )
typeset -gA TS_VERCEL_dns_SUB=( ["add"]=0 )
typeset -gA TS_VERCEL_certs_SUB=( ["ls"]=0 ["issue"]=0 ["rm"]=0 )
typeset -gA TS_VERCEL_certs_OPT=( ["--challenge-only"]=0 ["--crt"]=1 ["--key"]=1 ["--ca"]=1 )
typeset -gA TS_VERCEL_secrets_SUB=( ["list"]=0 ["add"]=0 ["rename"]=0 ["remove"]=0 )
typeset -gA TS_VERCEL_logs_OPT=( ["-a"]=0 ["--all"]=0 ["-f"]=0 ["--follow"]=0 ["-n"]=1 ["--number"]=1 ["-o"]=1 ["--output"]=1 ["--since"]=1 ["-q"]=1 ["--query"]=1 ["--until"]=1 )
# TS_VERCEL_logs positional args: deployment_url
typeset -gA TS_VERCEL_teams_SUB=( ["list"]=0 ["add"]=0 ["invite"]=0 )
typeset -gA TS_VERCEL_alias_SUB=( ["set"]=0 ["rm"]=0 ["ls"]=0 )
typeset -gA TS_VERCEL_billing_SUB=( ["ls"]=0 ["add"]=0 ["rm"]=0 ["set-default"]=0 )
typeset -gA TS_VERCEL_SUB=( ["deploy"]=0 ["dev"]=1 ["env"]=1 ["init"]=0 ["list"]=1 ["ls"]=0 ["inspect"]=0 ["login"]=0 ["logout"]=0 ["switch"]=0 ["help"]=0 ["rm"]=1 ["remove"]=0 ["domains"]=1 ["dns"]=1 ["certs"]=1 ["secrets"]=1 ["logs"]=1 ["teams"]=1 ["whoami"]=0 ["alias"]=1 ["link"]=0 ["billing"]=1 )
typeset -gA TS_VERCEL_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--version"]=0 ["-V"]=0 ["--platform-version"]=0 ["-A"]=1 ["--local-config"]=1 ["-Q"]=1 ["--global-config"]=1 ["-d"]=0 ["--debug"]=0 ["-f"]=0 ["--force"]=0 ["-with-cache"]=0 ["-t"]=1 ["--token"]=1 ["-p"]=0 ["--public"]=0 ["-e"]=0 ["--env"]=0 ["-b"]=0 ["--build-env"]=0 ["-m"]=0 ["--meta"]=0 ["-C"]=0 ["--no-clipboard"]=0 ["-S"]=1 ["--scope"]=1 ["--regions"]=0 ["--prod"]=0 ["-c"]=0 ["--confirm"]=0 )
# TS_VERCEL positional args: path_to_project
