# Termy spec-highlight: zsh assoc arrays for command "netlify"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_NETLIFY_SUB / TS_NETLIFY_OPT / nested TS_NETLIFY_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_NETLIFY_addons_auth_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_addons_auth positional args: name
typeset -gA TS_NETLIFY_addons_config_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_addons_config positional args: name
typeset -gA TS_NETLIFY_addons_create_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_addons_create positional args: name
typeset -gA TS_NETLIFY_addons_delete_OPT=( ["-f"]=0 ["--force"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_addons_delete positional args: name
typeset -gA TS_NETLIFY_addons_list_OPT=( ["--json"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_api_OPT=( ["-d"]=1 ["--data"]=1 ["--list"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_api positional args: apiMethod
typeset -gA TS_NETLIFY_build_OPT=( ["-o"]=0 ["--offline"]=0 ["--context"]=1 ["--dry"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_completion_OPT=( ["-s"]=1 ["--shell"]=1 )
typeset -gA TS_NETLIFY_completion_generate_OPT=( ["-s"]=0 ["--shell"]=0 )
typeset -gA TS_NETLIFY_completion_generate_alias_OPT=( ["-s"]=0 ["--shell"]=0 )
typeset -gA TS_NETLIFY_deploy_OPT=( ["-a"]=1 ["--auth"]=1 ["-b"]=1 ["--branch"]=1 ["-d"]=1 ["--dir"]=1 ["-f"]=1 ["--functions"]=1 ["-m"]=1 ["--message"]=1 ["-o"]=0 ["--open"]=0 ["-p"]=0 ["--prod"]=0 ["-s"]=1 ["--site"]=1 ["--alias"]=1 ["--build"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 ["--json"]=0 ["--prodIfUnlocked"]=0 ["--skip-functions-cache"]=0 ["--timeout"]=1 ["trigger"]=0 )
typeset -gA TS_NETLIFY_dev_OPT=( ["-c"]=1 ["--command"]=1 ["-d"]=1 ["--dir"]=1 ["-f"]=1 ["--functions"]=1 ["-l"]=0 ["--live"]=0 ["-o"]=0 ["--offline"]=0 ["-p"]=1 ["--port"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 ["--framework"]=1 ["--targetPort"]=1 )
typeset -gA TS_NETLIFY_dev_exec_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_dev_trace_OPT=( ["-H"]=1 ["--header"]=1 ["-X"]=1 ["--request"]=1 ["-B"]=1 ["--cookie"]=1 ["-w"]=1 ["--watch"]=1 ["--debug"]=0 )
# TS_NETLIFY_dev_trace positional args: url
typeset -gA TS_NETLIFY_env_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_env_get_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_env_import_OPT=( ["-r"]=0 ["--replaceExisting"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_env_import positional args: filename
typeset -gA TS_NETLIFY_env_list_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_env_set_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_env_set positional args: name value
typeset -gA TS_NETLIFY_env_unset_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_env_unset positional args: name
typeset -gA TS_NETLIFY_functions_build_OPT=( ["-f"]=1 ["--functions"]=1 ["-s"]=1 ["--src"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_functions_create_OPT=( ["-n"]=1 ["--name"]=1 ["-u"]=1 ["--url"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_functions_create positional args: name
typeset -gA TS_NETLIFY_functions_invoke_OPT=( ["-f"]=1 ["--functions"]=1 ["-n"]=1 ["--name"]=1 ["-p"]=1 ["--payload"]=1 ["-q"]=1 ["--querystring"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 ["--identity"]=0 ["--no-identity"]=0 ["port"]=1 )
# TS_NETLIFY_functions_invoke positional args: name
typeset -gA TS_NETLIFY_functions_list_OPT=( ["-f"]=1 ["--functions"]=1 ["-n"]=1 ["--name"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 ["--json"]=0 )
typeset -gA TS_NETLIFY_functions_serve_OPT=( ["-f"]=1 ["--functions"]=1 ["-o"]=0 ["--offline"]=0 ["-p"]=1 ["--port"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_init_OPT=( ["-m"]=0 ["--manual"]=0 ["--force"]=0 ["--gitRemoteName"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_link_OPT=( ["--gitRemoteName"]=1 ["--id"]=1 ["--name"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_lm_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_lm_info_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_lm_install_OPT=( ["-f"]=0 ["--force"]=0 )
typeset -gA TS_NETLIFY_lm_setup_OPT=( ["-f"]=0 ["--force-install"]=0 ["-s"]=0 ["--skip-install"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_login_OPT=( ["--auth"]=1 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 ["--json"]=0 ["--new"]=0 ["--silent"]=0 )
typeset -gA TS_NETLIFY_open_OPT=( ["--admin"]=0 ["--site"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_open_admin_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_open_site_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_sites_create_OPT=( ["-a"]=0 ["--account-slug"]=0 ["-c"]=0 ["--with-ci"]=0 ["-m"]=0 ["--manual"]=0 ["-n"]=0 ["--name"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_sites_delete_OPT=( ["-f"]=0 ["--force"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
# TS_NETLIFY_sites_delete positional args: siteId
typeset -gA TS_NETLIFY_sites_list_OPT=( ["--json"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_status_OPT=( ["verbose"]=0 ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_status_hooks_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_unlink_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_watch_OPT=( ["--debug"]=0 ["--httpProxy"]=1 ["--httpProxyCertificateFilename"]=1 )
typeset -gA TS_NETLIFY_SUB=( ["addons:auth"]=1 ["addon:auth"]=1 ["addons:config"]=1 ["addon:config"]=1 ["addons:create"]=1 ["addon:create"]=1 ["addons:delete"]=1 ["addon:delete"]=1 ["addons:list"]=1 ["addon:list"]=1 ["api"]=1 ["build"]=1 ["completion"]=1 ["completion:generate"]=1 ["completion:generate:alias"]=1 ["deploy"]=1 ["dev"]=1 ["dev:exec"]=1 ["dev:trace"]=1 ["env"]=1 ["env:get"]=1 ["env:import"]=1 ["env:list"]=1 ["env:set"]=1 ["env:unset"]=1 ["env:delete"]=1 ["env:remove"]=1 ["functions:build"]=1 ["function:build"]=1 ["functions:create"]=1 ["function:create"]=1 ["functions:invoke"]=1 ["function:trigger"]=1 ["functions:list"]=1 ["function:list"]=1 ["functions:serve"]=1 ["function:server"]=1 ["init"]=1 ["link"]=1 ["lm"]=1 ["lm:info"]=1 ["lm:install"]=1 ["lm:init"]=1 ["lm:setup"]=1 ["login"]=1 ["open"]=1 ["open:admin"]=1 ["open:site"]=1 ["sites:create"]=1 ["sites:delete"]=1 ["sites:list"]=1 ["status"]=1 ["status:hooks"]=1 ["unlink"]=1 ["watch"]=1 ["help"]=0 )
typeset -gA TS_NETLIFY_OPT=( ["--telemetry-disable"]=0 ["--telemetry-enable"]=0 )
