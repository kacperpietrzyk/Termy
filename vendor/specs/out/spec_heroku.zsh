# Termy spec-highlight: zsh assoc arrays for command "heroku"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_HEROKU_SUB / TS_HEROKU_OPT / nested TS_HEROKU_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_HEROKU_auth_login_OPT=( ["--browser"]=1 ["-i"]=0 ["--interactive"]=0 ["-e"]=1 ["--expires-in"]=1 )
typeset -gA TS_HEROKU_auth_token_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_HEROKU_authorizations_OPT=( ["-j"]=0 ["--json"]=0 )
typeset -gA TS_HEROKU_authorizations_create_OPT=( ["-d"]=1 ["--description"]=1 ["-S"]=0 ["--short"]=0 ["-j"]=0 ["--json"]=0 ["-s"]=1 ["--scope"]=1 ["-e"]=1 ["--expires-in"]=1 )
typeset -gA TS_HEROKU_authorizations_info_OPT=( ["-j"]=0 ["--json"]=0 )
# TS_HEROKU_authorizations_info positional args: id
typeset -gA TS_HEROKU_authorizations_update_OPT=( ["-d"]=1 ["--description"]=1 ["--client-id"]=1 ["--client-secret"]=1 )
# TS_HEROKU_authorizations_update positional args: id
typeset -gA TS_HEROKU_autocomplete_OPT=( ["-r"]=0 ["--refresh-cache"]=0 )
# TS_HEROKU_autocomplete positional args: shell
typeset -gA TS_HEROKU_buildpacks_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_buildpacks_add_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-i"]=1 ["--index"]=1 )
# TS_HEROKU_buildpacks_add positional args: buildpack
typeset -gA TS_HEROKU_buildpacks_clear_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_buildpacks_remove_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-i"]=1 ["--index"]=1 )
# TS_HEROKU_buildpacks_remove positional args: buildpack
typeset -gA TS_HEROKU_buildpacks_search_OPT=( ["--namespace"]=1 ["--name"]=1 ["--description"]=1 )
# TS_HEROKU_buildpacks_search positional args: term
typeset -gA TS_HEROKU_buildpacks_set_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-i"]=1 ["--index"]=1 )
# TS_HEROKU_buildpacks_set positional args: buildpack
typeset -gA TS_HEROKU_ci_OPT=( ["-a"]=1 ["--app"]=1 ["--watch"]=0 ["-p"]=1 ["--pipeline"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_ci_info_OPT=( ["-a"]=1 ["--app"]=1 ["--node"]=1 ["-p"]=1 ["--pipeline"]=1 )
# TS_HEROKU_ci_info positional args: test_run
typeset -gA TS_HEROKU_ci_last_OPT=( ["-a"]=1 ["--app"]=1 ["--node"]=1 ["-p"]=1 ["--pipeline"]=1 )
typeset -gA TS_HEROKU_ci_rerun_OPT=( ["-a"]=1 ["--app"]=1 ["-p"]=1 ["--pipeline"]=1 )
# TS_HEROKU_ci_rerun positional args: number
typeset -gA TS_HEROKU_ci_run_OPT=( ["-a"]=1 ["--app"]=1 ["-p"]=1 ["--pipeline"]=1 )
typeset -gA TS_HEROKU_clients_OPT=( ["-j"]=0 ["--json"]=0 )
typeset -gA TS_HEROKU_clients_create_OPT=( ["-j"]=0 ["--json"]=0 ["-s"]=0 ["--shell"]=0 )
# TS_HEROKU_clients_create positional args: name redirect_uri
typeset -gA TS_HEROKU_clients_info_OPT=( ["-j"]=0 ["--json"]=0 ["-s"]=0 ["--shell"]=0 )
# TS_HEROKU_clients_info positional args: id
typeset -gA TS_HEROKU_clients_rotate_OPT=( ["-j"]=0 ["--json"]=0 ["-s"]=0 ["--shell"]=0 )
# TS_HEROKU_clients_rotate positional args: id
typeset -gA TS_HEROKU_clients_update_OPT=( ["-n"]=1 ["--name"]=1 ["--url"]=1 )
# TS_HEROKU_clients_update positional args: id
typeset -gA TS_HEROKU_config_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=0 ["--shell"]=0 ["-j"]=0 ["--json"]=0 )
typeset -gA TS_HEROKU_config_edit_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_config_edit positional args: key
typeset -gA TS_HEROKU_config_get_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=0 ["--shell"]=0 )
# TS_HEROKU_config_get positional args: KEY
typeset -gA TS_HEROKU_config_unset_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_domains_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-j"]=0 ["--json"]=0 ["--columns"]=1 ["--sort"]=1 ["--filter"]=1 ["--csv"]=0 ["--output"]=1 ["-x"]=0 ["--extended"]=0 ["--no-header"]=0 )
typeset -gA TS_HEROKU_domains_add_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-c"]=1 ["--cert"]=1 ["-j"]=0 ["--json"]=0 ["--wait"]=0 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_domains_add positional args: hostname
typeset -gA TS_HEROKU_domains_clear_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_domains_info_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_domains_info positional args: hostname
typeset -gA TS_HEROKU_domains_remove_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_domains_remove positional args: hostname
typeset -gA TS_HEROKU_domains_update_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["--cert"]=1 )
# TS_HEROKU_domains_update positional args: hostname
typeset -gA TS_HEROKU_domains_wait_OPT=( ["-h"]=0 ["--help"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_domains_wait positional args: hostname
typeset -gA TS_HEROKU_git_clone_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_git_clone positional args: DIRECTORY
typeset -gA TS_HEROKU_git_remote_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_labs_disable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["--confirm"]=1 )
# TS_HEROKU_labs_disable positional args: feature
typeset -gA TS_HEROKU_local_OPT=( ["-f"]=1 ["--procfile"]=1 ["-e"]=1 ["--env"]=1 ["-p"]=1 ["--port"]=1 )
# TS_HEROKU_local positional args: processname
typeset -gA TS_HEROKU_local_run_OPT=( ["-e"]=1 ["--env"]=1 ["-p"]=1 ["--port"]=1 )
typeset -gA TS_HEROKU_logs_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-n"]=1 ["--num"]=1 ["-d"]=1 ["--dyno"]=1 ["-s"]=1 ["--source"]=1 ["-t"]=0 ["--tail"]=0 ["--force-colors"]=0 )
typeset -gA TS_HEROKU_pipelines_OPT=( ["--json"]=0 )
typeset -gA TS_HEROKU_pipelines_add_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--stage"]=1 )
# TS_HEROKU_pipelines_add positional args: pipeline
typeset -gA TS_HEROKU_pipelines_connect_OPT=( ["-r"]=1 ["--repo"]=1 )
# TS_HEROKU_pipelines_connect positional args: name
typeset -gA TS_HEROKU_pipelines_create_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--stage"]=1 ["-t"]=1 ["--team"]=1 )
# TS_HEROKU_pipelines_create positional args: name
typeset -gA TS_HEROKU_pipelines_diff_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_pipelines_info_OPT=( ["--json"]=0 )
# TS_HEROKU_pipelines_info positional args: pipeline
typeset -gA TS_HEROKU_pipelines_promote_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-t"]=1 ["--to"]=1 )
typeset -gA TS_HEROKU_pipelines_remove_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_pipelines_setup_OPT=( ["-t"]=1 ["--team"]=1 ["-y"]=0 ["--yes"]=0 )
# TS_HEROKU_pipelines_setup positional args: name repo
typeset -gA TS_HEROKU_pipelines_transfer_OPT=( ["-p"]=1 ["--pipeline"]=1 ["-c"]=1 ["--confirm"]=1 )
# TS_HEROKU_pipelines_transfer positional args: owner
typeset -gA TS_HEROKU_pipelines_update_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--stage"]=1 )
typeset -gA TS_HEROKU_ps_autoscale_disable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ps_autoscale_enable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["--min"]=1 ["--max"]=1 ["--p95"]=1 ["--notifications"]=0 )
typeset -gA TS_HEROKU_ps_wait_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-t"]=1 ["--type"]=1 ["-w"]=1 ["--wait-interval"]=1 ["-R"]=0 ["--with-run"]=0 )
typeset -gA TS_HEROKU_regions_OPT=( ["--json"]=0 ["--private"]=0 ["--common"]=0 )
typeset -gA TS_HEROKU_reviewapps_disable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-p"]=1 ["--pipeline"]=1 ["--no-autodeploy"]=0 ["--no-autodestroy"]=0 ["--no-wait-for-ci"]=0 )
typeset -gA TS_HEROKU_reviewapps_enable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-p"]=1 ["--pipeline"]=1 ["--autodeploy"]=0 ["--autodestroy"]=0 ["--wait-for-ci"]=0 )
typeset -gA TS_HEROKU_run_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--size"]=1 ["--type"]=1 ["-x"]=0 ["--exit-code"]=0 ["-e"]=1 ["--env"]=1 ["--no-tty"]=0 ["--no-notify"]=0 )
typeset -gA TS_HEROKU_run_detached_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-e"]=1 ["--env"]=1 ["-s"]=1 ["--size"]=1 ["-t"]=0 ["--tail"]=0 ["--type"]=1 )
typeset -gA TS_HEROKU_sessions_OPT=( ["-j"]=0 ["--json"]=0 )
typeset -gA TS_HEROKU_status_OPT=( ["--json"]=0 )
typeset -gA TS_HEROKU_webhooks_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_webhooks_add_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-i"]=1 ["--include"]=1 ["-l"]=1 ["--level"]=1 ["-s"]=1 ["--secret"]=1 ["-t"]=1 ["--authorization"]=1 ["-u"]=1 ["--url"]=1 )
typeset -gA TS_HEROKU_webhooks_deliveries_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--status"]=1 )
typeset -gA TS_HEROKU_webhooks_deliveries_info_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_webhooks_deliveries_info positional args: id
typeset -gA TS_HEROKU_webhooks_events_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_webhooks_events_info_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_webhooks_events_info positional args: id
typeset -gA TS_HEROKU_webhooks_info_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_webhooks_info positional args: id
typeset -gA TS_HEROKU_webhooks_remove_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_webhooks_remove positional args: id
typeset -gA TS_HEROKU_webhooks_update_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 ["-i"]=1 ["--include"]=1 ["-l"]=1 ["--level"]=1 ["-s"]=1 ["--secret"]=1 ["-t"]=1 ["--authorization"]=1 ["-u"]=1 ["--url"]=1 )
# TS_HEROKU_webhooks_update positional args: id
typeset -gA TS_HEROKU_ci_config_OPT=( ["-s"]=0 ["--shell"]=0 ["--json"]=0 ["-p"]=1 ["--pipeline"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ci_config_get_OPT=( ["-s"]=0 ["--shell"]=0 ["-p"]=1 ["--pipeline"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_ci_config_get positional args: key
typeset -gA TS_HEROKU_ci_config_set_OPT=( ["-p"]=1 ["--pipeline"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ci_config_unset_OPT=( ["-p"]=1 ["--pipeline"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ci_debug_OPT=( ["--no-setup"]=0 ["-p"]=1 ["--pipeline"]=1 ["--no-cache"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ci_open_OPT=( ["-p"]=1 ["--pipeline"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_addons_OPT=( ["-A"]=0 ["--all"]=0 ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_addons_attach_OPT=( ["--as"]=1 ["--credential"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_attach positional args: addon_name
typeset -gA TS_HEROKU_addons_create_OPT=( ["--name"]=1 ["--as"]=1 ["--confirm"]=1 ["--wait"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_create positional args: service_plan
typeset -gA TS_HEROKU_addons_destroy_OPT=( ["-f"]=0 ["--force"]=0 ["-c"]=1 ["--confirm"]=1 ["--wait"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_addons_detach_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_detach positional args: attachment_name
typeset -gA TS_HEROKU_addons_docs_OPT=( ["--show-url"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_docs positional args: addon
typeset -gA TS_HEROKU_addons_downgrade_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_downgrade positional args: addon plan
typeset -gA TS_HEROKU_addons_info_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_info positional args: addon
typeset -gA TS_HEROKU_addons_open_OPT=( ["--show-url"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_open positional args: addon
typeset -gA TS_HEROKU_addons_plans_OPT=( ["--json"]=0 )
# TS_HEROKU_addons_plans positional args: service
typeset -gA TS_HEROKU_addons_rename_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_rename positional args: addon name
typeset -gA TS_HEROKU_addons_services_OPT=( ["--json"]=0 )
typeset -gA TS_HEROKU_addons_upgrade_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_upgrade positional args: addon plan
typeset -gA TS_HEROKU_addons_wait_OPT=( ["--wait-interval"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_addons_wait positional args: addon
typeset -gA TS_HEROKU_certs_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_add_OPT=( ["--bypass"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_certs_add positional args: CRT KEY
typeset -gA TS_HEROKU_certs_auto_OPT=( ["--wait"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_auto_disable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_auto_enable_OPT=( ["--wait"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_auto_refresh_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_chain_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_generate_OPT=( ["--selfsigned"]=0 ["--keysize"]=1 ["--owner"]=1 ["--country"]=1 ["--area"]=1 ["--city"]=1 ["--subject"]=1 ["--now"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_certs_generate positional args: domain
typeset -gA TS_HEROKU_certs_info_OPT=( ["--name"]=1 ["--endpoint"]=1 ["--show-domains"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_key_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_remove_OPT=( ["--name"]=1 ["--endpoint"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_certs_update_OPT=( ["--bypass"]=0 ["--name"]=1 ["--endpoint"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_certs_update positional args: CRT KEY
typeset -gA TS_HEROKU_container_login_OPT=( ["-v"]=0 ["--verbose"]=0 )
typeset -gA TS_HEROKU_container_logout_OPT=( ["-v"]=0 ["--verbose"]=0 )
typeset -gA TS_HEROKU_container_pull_OPT=( ["-v"]=0 ["--verbose"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_container_push_OPT=( ["-v"]=0 ["--verbose"]=0 ["-R"]=0 ["--recursive"]=0 ["--arg"]=1 ["--context-path"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_container_release_OPT=( ["-v"]=0 ["--verbose"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_container_rm_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_container_run_OPT=( ["-p"]=1 ["--port"]=1 ["-v"]=0 ["--verbose"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_pg_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg positional args: database
typeset -gA TS_HEROKU_pg_backups_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_pg_backups_cancel_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_cancel positional args: backup_id
typeset -gA TS_HEROKU_pg_backups_capture_OPT=( ["--wait-interval"]=1 ["-v"]=0 ["--verbose"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_capture positional args: database
typeset -gA TS_HEROKU_pg_backups_delete_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_delete positional args: backup_id
typeset -gA TS_HEROKU_pg_backups_download_OPT=( ["-o"]=1 ["--output"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_download positional args: backup_id
typeset -gA TS_HEROKU_pg_backups_info_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_info positional args: backup_id
typeset -gA TS_HEROKU_pg_backups_restore_OPT=( ["--wait-interval"]=1 ["-e"]=1 ["--extensions"]=1 ["-v"]=0 ["--verbose"]=0 ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_restore positional args: backup database
typeset -gA TS_HEROKU_pg_backups_schedule_OPT=( ["--at"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_schedule positional args: database
typeset -gA TS_HEROKU_pg_backups_schedules_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_pg_backups_unschedule_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_unschedule positional args: database
typeset -gA TS_HEROKU_pg_backups_url_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_backups_url positional args: backup_id
typeset -gA TS_HEROKU_pg_bloat_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_bloat positional args: database
typeset -gA TS_HEROKU_pg_blocking_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_blocking positional args: database
typeset -gA TS_HEROKU_pg_connection_pooling_attach_OPT=( ["--as"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_connection_pooling_attach positional args: database
typeset -gA TS_HEROKU_pg_copy_OPT=( ["--wait-interval"]=1 ["--verbose"]=0 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_copy positional args: source target
typeset -gA TS_HEROKU_pg_credentials_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_credentials positional args: database
typeset -gA TS_HEROKU_pg_credentials_create_OPT=( ["-n"]=1 ["--name"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_credentials_create positional args: database
typeset -gA TS_HEROKU_pg_credentials_destroy_OPT=( ["-n"]=1 ["--name"]=1 ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_credentials_destroy positional args: database
typeset -gA TS_HEROKU_pg_credentials_repair_default_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_credentials_repair_default positional args: database
typeset -gA TS_HEROKU_pg_credentials_rotate_OPT=( ["-n"]=1 ["--name"]=1 ["--all"]=0 ["-c"]=1 ["--confirm"]=1 ["--force"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_credentials_rotate positional args: database
typeset -gA TS_HEROKU_pg_credentials_url_OPT=( ["-n"]=1 ["--name"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_credentials_url positional args: database
typeset -gA TS_HEROKU_pg_diagnose_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_diagnose positional args: DATABASE_REPORT_ID
typeset -gA TS_HEROKU_pg_info_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_info positional args: database
typeset -gA TS_HEROKU_pg_kill_OPT=( ["-f"]=0 ["--force"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_kill positional args: pid database
typeset -gA TS_HEROKU_pg_killall_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_killall positional args: database
typeset -gA TS_HEROKU_pg_links_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_links positional args: database
typeset -gA TS_HEROKU_pg_links_create_OPT=( ["--as"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_links_create positional args: remote database
typeset -gA TS_HEROKU_pg_links_destroy_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_links_destroy positional args: database link
typeset -gA TS_HEROKU_pg_locks_OPT=( ["-t"]=0 ["--truncate"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_locks positional args: database
typeset -gA TS_HEROKU_pg_maintenance_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_maintenance positional args: database
typeset -gA TS_HEROKU_pg_maintenance_run_OPT=( ["-f"]=0 ["--force"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_maintenance_run positional args: database
typeset -gA TS_HEROKU_pg_maintenance_window_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_maintenance_window positional args: database window
typeset -gA TS_HEROKU_pg_outliers_OPT=( ["--reset"]=0 ["-t"]=0 ["--truncate"]=0 ["-n"]=1 ["--num"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_outliers positional args: database
typeset -gA TS_HEROKU_pg_promote_OPT=( ["-f"]=0 ["--force"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_promote positional args: database
typeset -gA TS_HEROKU_pg_ps_OPT=( ["-v"]=0 ["--verbose"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_ps positional args: database
typeset -gA TS_HEROKU_pg_psql_OPT=( ["-c"]=1 ["--command"]=1 ["-f"]=1 ["--file"]=1 ["--credential"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_psql positional args: database
typeset -gA TS_HEROKU_pg_pull_OPT=( ["--exclude-table-data"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_pull positional args: source target
typeset -gA TS_HEROKU_pg_push_OPT=( ["--exclude-table-data"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_push positional args: source target
typeset -gA TS_HEROKU_pg_reset_OPT=( ["-e"]=1 ["--extensions"]=1 ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_reset positional args: database
typeset -gA TS_HEROKU_pg_settings_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings positional args: database
typeset -gA TS_HEROKU_pg_settings_auto_explain_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain positional args: value database
typeset -gA TS_HEROKU_pg_settings_auto_explain_log_analyze_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain_log_analyze positional args: value database
typeset -gA TS_HEROKU_pg_settings_auto_explain_log_buffers_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain_log_buffers positional args: value database
typeset -gA TS_HEROKU_pg_settings_auto_explain_log_min_duration_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain_log_min_duration positional args: value database
typeset -gA TS_HEROKU_pg_settings_auto_explain_log_nested_statements_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain_log_nested_statements positional args: value database
typeset -gA TS_HEROKU_pg_settings_auto_explain_log_triggers_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain_log_triggers positional args: value database
typeset -gA TS_HEROKU_pg_settings_auto_explain_log_verbose_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_auto_explain_log_verbose positional args: value database
typeset -gA TS_HEROKU_pg_settings_log_lock_waits_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_log_lock_waits positional args: value database
typeset -gA TS_HEROKU_pg_settings_log_min_duration_statement_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_log_min_duration_statement positional args: value database
typeset -gA TS_HEROKU_pg_settings_log_statement_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_log_statement positional args: value database
typeset -gA TS_HEROKU_pg_settings_track_functions_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_settings_track_functions positional args: value database
typeset -gA TS_HEROKU_pg_unfollow_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_unfollow positional args: database
typeset -gA TS_HEROKU_pg_upgrade_OPT=( ["-c"]=1 ["--confirm"]=1 ["-v"]=1 ["--version"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_upgrade positional args: database
typeset -gA TS_HEROKU_pg_vacuum_stats_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_vacuum_stats positional args: database
typeset -gA TS_HEROKU_pg_wait_OPT=( ["--wait-interval"]=1 ["--no-notify"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_pg_wait positional args: database
typeset -gA TS_HEROKU_psql_OPT=( ["-c"]=1 ["--command"]=1 ["-f"]=1 ["--file"]=1 ["--credential"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_psql positional args: database
typeset -gA TS_HEROKU_redis_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis positional args: database
typeset -gA TS_HEROKU_redis_cli_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_cli positional args: database
typeset -gA TS_HEROKU_redis_credentials_OPT=( ["--reset"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_credentials positional args: database
typeset -gA TS_HEROKU_redis_info_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_info positional args: database
typeset -gA TS_HEROKU_redis_keyspace_notifications_OPT=( ["-c"]=1 ["--config"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_keyspace_notifications positional args: database
typeset -gA TS_HEROKU_redis_maintenance_OPT=( ["-w"]=1 ["--window"]=1 ["--run"]=0 ["-f"]=0 ["--force"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_maintenance positional args: database
typeset -gA TS_HEROKU_redis_maxmemory_OPT=( ["-p"]=1 ["--policy"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_maxmemory positional args: database
typeset -gA TS_HEROKU_redis_promote_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_promote positional args: database
typeset -gA TS_HEROKU_redis_stats_reset_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_stats_reset positional args: database
typeset -gA TS_HEROKU_redis_timeout_OPT=( ["-s"]=1 ["--seconds"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_timeout positional args: database
typeset -gA TS_HEROKU_redis_upgrade_OPT=( ["-c"]=1 ["--confirm"]=1 ["-v"]=1 ["--version"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_upgrade positional args: database
typeset -gA TS_HEROKU_redis_wait_OPT=( ["--wait-interval"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_redis_wait positional args: database
typeset -gA TS_HEROKU_spaces_OPT=( ["--json"]=0 ["-t"]=1 ["--team"]=1 )
typeset -gA TS_HEROKU_spaces_create_OPT=( ["-s"]=1 ["--space"]=1 ["--region"]=1 ["--cidr"]=1 ["--data-cidr"]=1 ["-t"]=1 ["--team"]=1 )
typeset -gA TS_HEROKU_spaces_destroy_OPT=( ["-s"]=1 ["--space"]=1 ["--confirm"]=1 )
typeset -gA TS_HEROKU_spaces_info_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_peering_info_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_peerings_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_peerings_accept_OPT=( ["-p"]=1 ["--pcxid"]=1 ["-s"]=1 ["--space"]=1 )
typeset -gA TS_HEROKU_spaces_peerings_destroy_OPT=( ["-p"]=1 ["--pcxid"]=1 ["-s"]=1 ["--space"]=1 ["--confirm"]=1 )
typeset -gA TS_HEROKU_spaces_ps_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_rename_OPT=( ["--from"]=1 ["--to"]=1 )
typeset -gA TS_HEROKU_spaces_topology_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_transfer_OPT=( ["--space"]=1 ["--team"]=1 )
typeset -gA TS_HEROKU_spaces_vpn_config_OPT=( ["-s"]=1 ["--space"]=1 ["-n"]=1 ["--name"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_vpn_connect_OPT=( ["-n"]=1 ["--name"]=1 ["-i"]=1 ["--ip"]=1 ["-c"]=1 ["--cidrs"]=1 ["-s"]=1 ["--space"]=1 )
typeset -gA TS_HEROKU_spaces_vpn_connections_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_spaces_vpn_destroy_OPT=( ["-s"]=1 ["--space"]=1 ["-n"]=1 ["--name"]=1 ["--confirm"]=1 )
typeset -gA TS_HEROKU_spaces_vpn_info_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 ["-n"]=1 ["--name"]=1 )
typeset -gA TS_HEROKU_spaces_vpn_update_OPT=( ["-n"]=1 ["--name"]=1 ["-c"]=1 ["--cidrs"]=1 ["-s"]=1 ["--space"]=1 )
typeset -gA TS_HEROKU_spaces_vpn_wait_OPT=( ["-s"]=1 ["--space"]=1 ["-n"]=1 ["--name"]=1 ["--json"]=0 ["-i"]=1 ["--interval"]=1 ["-t"]=1 ["--timeout"]=1 )
typeset -gA TS_HEROKU_spaces_wait_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 ["-i"]=1 ["--interval"]=1 ["-t"]=1 ["--timeout"]=1 )
typeset -gA TS_HEROKU_trusted_ips_OPT=( ["-s"]=1 ["--space"]=1 ["--json"]=0 )
typeset -gA TS_HEROKU_trusted_ips_add_OPT=( ["-s"]=1 ["--space"]=1 ["--confirm"]=1 )
# TS_HEROKU_trusted_ips_add positional args: source
typeset -gA TS_HEROKU_trusted_ips_remove_OPT=( ["--space"]=1 ["--confirm"]=1 )
# TS_HEROKU_trusted_ips_remove positional args: source
typeset -gA TS_HEROKU_access_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_access_add_OPT=( ["-p"]=1 ["--permissions"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_access_add positional args: email
typeset -gA TS_HEROKU_access_remove_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_access_remove positional args: email
typeset -gA TS_HEROKU_access_update_OPT=( ["-p"]=1 ["--permissions"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_access_update positional args: email
typeset -gA TS_HEROKU_apps_join_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_leave_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_lock_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_transfer_OPT=( ["-l"]=0 ["--locked"]=0 ["--bulk"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_apps_transfer positional args: recipient
typeset -gA TS_HEROKU_apps_unlock_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_join_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_leave_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_lock_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_members_OPT=( ["-r"]=1 ["--role"]=1 ["--pending"]=0 ["--json"]=0 ["-t"]=1 ["--team"]=1 )
typeset -gA TS_HEROKU_members_add_OPT=( ["-r"]=1 ["--role"]=1 ["-t"]=1 ["--team"]=1 )
# TS_HEROKU_members_add positional args: email
typeset -gA TS_HEROKU_members_remove_OPT=( ["-t"]=1 ["--team"]=1 )
# TS_HEROKU_members_remove positional args: email
typeset -gA TS_HEROKU_members_set_OPT=( ["-r"]=1 ["--role"]=1 ["-t"]=1 ["--team"]=1 )
# TS_HEROKU_members_set positional args: email
typeset -gA TS_HEROKU_orgs_OPT=( ["--json"]=0 ["--enterprise"]=0 )
typeset -gA TS_HEROKU_orgs_open_OPT=( ["-t"]=1 ["--team"]=1 )
typeset -gA TS_HEROKU_teams_OPT=( ["--json"]=0 )
typeset -gA TS_HEROKU_unlock_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_OPT=( ["-A"]=0 ["--all"]=0 ["--json"]=0 ["-s"]=1 ["--space"]=1 ["-p"]=0 ["--personal"]=0 ["-t"]=1 ["--team"]=1 )
typeset -gA TS_HEROKU_apps_create_OPT=( ["--addons"]=1 ["-b"]=1 ["--buildpack"]=1 ["-n"]=0 ["--no-remote"]=0 ["-r"]=1 ["--remote"]=1 ["-s"]=1 ["--stack"]=1 ["--space"]=1 ["--region"]=1 ["--json"]=0 ["-t"]=1 ["--team"]=1 )
# TS_HEROKU_apps_create positional args: app
typeset -gA TS_HEROKU_apps_destroy_OPT=( ["-c"]=1 ["--confirm"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_errors_OPT=( ["--json"]=0 ["--hours"]=1 ["--router"]=0 ["--dyno"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_favorites_OPT=( ["--json"]=0 )
typeset -gA TS_HEROKU_apps_favorites_add_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_favorites_remove_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_info_OPT=( ["-s"]=0 ["--shell"]=0 ["-j"]=0 ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_open_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_apps_open positional args: path
typeset -gA TS_HEROKU_apps_rename_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_apps_rename positional args: newname
typeset -gA TS_HEROKU_apps_stacks_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_apps_stacks_set_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_apps_stacks_set positional args: stack
typeset -gA TS_HEROKU_config_set_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_drains_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_drains_add_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_drains_add positional args: url
typeset -gA TS_HEROKU_drains_remove_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_drains_remove positional args: url
typeset -gA TS_HEROKU_dyno_kill_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_dyno_kill positional args: dyno
typeset -gA TS_HEROKU_dyno_resize_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_dyno_restart_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_dyno_restart positional args: dyno
typeset -gA TS_HEROKU_dyno_scale_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_dyno_stop_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_dyno_stop positional args: dyno
typeset -gA TS_HEROKU_features_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_features_disable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_features_disable positional args: feature
typeset -gA TS_HEROKU_features_enable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_features_enable positional args: feature
typeset -gA TS_HEROKU_features_info_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_features_info positional args: feature
typeset -gA TS_HEROKU_keys_OPT=( ["-l"]=0 ["--long"]=0 ["--json"]=0 )
typeset -gA TS_HEROKU_keys_add_OPT=( ["-y"]=0 ["--yes"]=0 )
# TS_HEROKU_keys_add positional args: key
typeset -gA TS_HEROKU_labs_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_labs_enable_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_labs_enable positional args: feature
typeset -gA TS_HEROKU_labs_info_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_labs_info positional args: feature
typeset -gA TS_HEROKU_maintenance_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_maintenance_off_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_maintenance_on_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_notifications_OPT=( ["--all"]=0 ["--json"]=0 ["--read"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ps_OPT=( ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ps_kill_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_ps_kill positional args: dyno
typeset -gA TS_HEROKU_ps_resize_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ps_restart_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_ps_restart positional args: dyno
typeset -gA TS_HEROKU_ps_scale_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ps_stop_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_ps_stop positional args: dyno
typeset -gA TS_HEROKU_ps_type_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_releases_OPT=( ["-n"]=1 ["--num"]=1 ["--json"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_releases_info_OPT=( ["--json"]=0 ["-s"]=0 ["--shell"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_releases_info positional args: release
typeset -gA TS_HEROKU_releases_output_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_releases_output positional args: release
typeset -gA TS_HEROKU_releases_rollback_OPT=( ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_releases_rollback positional args: release
typeset -gA TS_HEROKU_ps_copy_OPT=( ["-d"]=1 ["--dyno"]=1 ["-o"]=1 ["--output"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_ps_copy positional args: file
typeset -gA TS_HEROKU_ps_exec_OPT=( ["-d"]=1 ["--dyno"]=1 ["--ssh"]=0 ["--status"]=0 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_ps_forward_OPT=( ["-d"]=1 ["--dyno"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
# TS_HEROKU_ps_forward positional args: port
typeset -gA TS_HEROKU_ps_socks_OPT=( ["-d"]=1 ["--dyno"]=1 ["-a"]=1 ["--app"]=1 ["-r"]=1 ["--remote"]=1 )
typeset -gA TS_HEROKU_commands_OPT=( ["--json"]=0 ["-h"]=0 ["--help"]=0 ["--hidden"]=0 ["--tree"]=0 ["--columns"]=1 ["--sort"]=1 ["--filter"]=1 ["--csv"]=0 ["--output"]=1 ["-x"]=0 ["--extended"]=0 ["--no-truncate"]=0 ["--no-header"]=0 )
typeset -gA TS_HEROKU_update_OPT=( ["-a"]=0 ["--available"]=0 ["-v"]=1 ["--version"]=1 ["-i"]=0 ["--interactive"]=0 ["--force"]=0 )
# TS_HEROKU_update positional args: channel
typeset -gA TS_HEROKU_plugins_OPT=( ["--core"]=0 )
typeset -gA TS_HEROKU_plugins_inspect_OPT=( ["--json"]=0 ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 )
# TS_HEROKU_plugins_inspect positional args: plugin
typeset -gA TS_HEROKU_plugins_install_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 ["-f"]=0 ["--force"]=0 )
# TS_HEROKU_plugins_install positional args: plugin
typeset -gA TS_HEROKU_plugins_link_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 )
# TS_HEROKU_plugins_link positional args: path
typeset -gA TS_HEROKU_plugins_uninstall_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 )
# TS_HEROKU_plugins_uninstall positional args: plugin
typeset -gA TS_HEROKU_plugins_update_OPT=( ["-h"]=0 ["--help"]=0 ["-v"]=0 ["--verbose"]=0 )
typeset -gA TS_HEROKU_version_OPT=( ["--json"]=0 ["--verbose"]=0 )
typeset -gA TS_HEROKU_help_OPT=( ["-n"]=0 ["--nested-commands"]=0 )
# TS_HEROKU_help positional args: commands
typeset -gA TS_HEROKU_SUB=( ["auth:2fa"]=0 ["2fa"]=0 ["twofactor"]=0 ["auth:2fa:disable"]=0 ["twofactor:disable"]=0 ["2fa:disable"]=0 ["auth:login"]=1 ["login"]=1 ["auth:logout"]=0 ["logout"]=0 ["auth:token"]=1 ["auth:whoami"]=0 ["whoami"]=0 ["authorizations"]=1 ["authorizations:create"]=1 ["authorizations:info"]=1 ["authorizations:revoke"]=0 ["authorizations:destroy"]=0 ["authorizations:rotate"]=0 ["authorizations:update"]=1 ["autocomplete"]=1 ["buildpacks"]=1 ["buildpacks:add"]=1 ["buildpacks:clear"]=1 ["buildpacks:info"]=0 ["buildpacks:remove"]=1 ["buildpacks:search"]=1 ["buildpacks:set"]=1 ["buildpacks:versions"]=0 ["ci"]=1 ["ci:info"]=1 ["ci:last"]=1 ["ci:rerun"]=1 ["ci:run"]=1 ["clients"]=1 ["clients:create"]=1 ["clients:destroy"]=0 ["clients:info"]=1 ["clients:rotate"]=1 ["clients:update"]=1 ["config"]=1 ["config:edit"]=1 ["config:get"]=1 ["config:unset"]=1 ["config:remove"]=1 ["domains"]=1 ["domains:add"]=1 ["domains:clear"]=1 ["domains:info"]=1 ["domains:remove"]=1 ["domains:update"]=1 ["domains:wait"]=1 ["git:clone"]=1 ["git:remote"]=1 ["labs:disable"]=1 ["local"]=1 ["local:start"]=1 ["local:run"]=1 ["local:version"]=0 ["logs"]=1 ["pipelines"]=1 ["pipelines:add"]=1 ["pipelines:connect"]=1 ["pipelines:create"]=1 ["pipelines:destroy"]=0 ["pipelines:diff"]=1 ["pipelines:info"]=1 ["pipelines:open"]=0 ["pipelines:promote"]=1 ["pipelines:remove"]=1 ["pipelines:rename"]=0 ["pipelines:setup"]=1 ["pipelines:transfer"]=1 ["pipelines:update"]=1 ["ps:autoscale:disable"]=1 ["ps:autoscale:enable"]=1 ["ps:wait"]=1 ["regions"]=1 ["reviewapps:disable"]=1 ["reviewapps:enable"]=1 ["run"]=1 ["run:detached"]=1 ["sessions"]=1 ["sessions:destroy"]=0 ["status"]=1 ["webhooks"]=1 ["webhooks:add"]=1 ["webhooks:deliveries"]=1 ["webhooks:deliveries:info"]=1 ["webhooks:events"]=1 ["webhooks:events:info"]=1 ["webhooks:info"]=1 ["webhooks:remove"]=1 ["webhooks:update"]=1 ["ci:config"]=1 ["ci:config:get"]=1 ["ci:config:set"]=1 ["ci:config:unset"]=1 ["ci:debug"]=1 ["ci:migrate-manifest"]=0 ["ci:open"]=1 ["addons"]=1 ["addons:attach"]=1 ["addons:create"]=1 ["addons:destroy"]=1 ["addons:detach"]=1 ["addons:docs"]=1 ["addons:downgrade"]=1 ["addons:info"]=1 ["addons:open"]=1 ["addons:plans"]=1 ["addons:rename"]=1 ["addons:services"]=1 ["addons:upgrade"]=1 ["addons:wait"]=1 ["certs"]=1 ["certs:add"]=1 ["certs:auto"]=1 ["certs:auto:disable"]=1 ["certs:auto:enable"]=1 ["certs:auto:refresh"]=1 ["certs:chain"]=1 ["certs:generate"]=1 ["certs:info"]=1 ["certs:key"]=1 ["certs:remove"]=1 ["certs:update"]=1 ["container"]=0 ["container:login"]=1 ["container:logout"]=1 ["container:pull"]=1 ["container:push"]=1 ["container:release"]=1 ["container:rm"]=1 ["container:run"]=1 ["pg"]=1 ["pg:backups"]=1 ["pg:backups:cancel"]=1 ["pg:backups:capture"]=1 ["pg:backups:delete"]=1 ["pg:backups:download"]=1 ["pg:backups:info"]=1 ["pg:backups:restore"]=1 ["pg:backups:schedule"]=1 ["pg:backups:schedules"]=1 ["pg:backups:unschedule"]=1 ["pg:backups:url"]=1 ["pg:bloat"]=1 ["pg:blocking"]=1 ["pg:connection-pooling:attach"]=1 ["pg:copy"]=1 ["pg:credentials"]=1 ["pg:credentials:create"]=1 ["pg:credentials:destroy"]=1 ["pg:credentials:repair-default"]=1 ["pg:credentials:rotate"]=1 ["pg:credentials:url"]=1 ["pg:diagnose"]=1 ["pg:info"]=1 ["pg:kill"]=1 ["pg:killall"]=1 ["pg:links"]=1 ["pg:links:create"]=1 ["pg:links:destroy"]=1 ["pg:locks"]=1 ["pg:maintenance"]=1 ["pg:maintenance:run"]=1 ["pg:maintenance:window"]=1 ["pg:outliers"]=1 ["pg:promote"]=1 ["pg:ps"]=1 ["pg:psql"]=1 ["pg:pull"]=1 ["pg:push"]=1 ["pg:reset"]=1 ["pg:settings"]=1 ["pg:settings:auto-explain"]=1 ["pg:settings:auto-explain:log-analyze"]=1 ["pg:settings:auto-explain:log-buffers"]=1 ["pg:settings:auto-explain:log-min-duration"]=1 ["pg:settings:auto-explain:log-nested-statements"]=1 ["pg:settings:auto-explain:log-triggers"]=1 ["pg:settings:auto-explain:log-verbose"]=1 ["pg:settings:log-lock-waits"]=1 ["pg:settings:log-min-duration-statement"]=1 ["pg:settings:log-statement"]=1 ["pg:settings:track-functions"]=1 ["pg:unfollow"]=1 ["pg:upgrade"]=1 ["pg:vacuum-stats"]=1 ["pg:wait"]=1 ["psql"]=1 ["redis"]=1 ["redis:cli"]=1 ["redis:credentials"]=1 ["redis:info"]=1 ["redis:keyspace-notifications"]=1 ["redis:maintenance"]=1 ["redis:maxmemory"]=1 ["redis:promote"]=1 ["redis:stats-reset"]=1 ["redis:timeout"]=1 ["redis:upgrade"]=1 ["redis:wait"]=1 ["spaces"]=1 ["spaces:create"]=1 ["spaces:destroy"]=1 ["spaces:info"]=1 ["spaces:peering:info"]=1 ["spaces:peerings"]=1 ["spaces:peerings:accept"]=1 ["spaces:peerings:destroy"]=1 ["spaces:ps"]=1 ["spaces:rename"]=1 ["spaces:topology"]=1 ["spaces:transfer"]=1 ["spaces:vpn:config"]=1 ["spaces:vpn:connect"]=1 ["spaces:vpn:connections"]=1 ["spaces:vpn:destroy"]=1 ["spaces:vpn:info"]=1 ["spaces:vpn:update"]=1 ["spaces:vpn:wait"]=1 ["spaces:wait"]=1 ["trusted-ips"]=1 ["trusted-ips:add"]=1 ["trusted-ips:remove"]=1 ["access"]=1 ["access:add"]=1 ["access:remove"]=1 ["access:update"]=1 ["apps:join"]=1 ["apps:leave"]=1 ["apps:lock"]=1 ["apps:transfer"]=1 ["apps:unlock"]=1 ["join"]=1 ["leave"]=1 ["lock"]=1 ["members"]=1 ["members:add"]=1 ["members:remove"]=1 ["members:set"]=1 ["orgs"]=1 ["orgs:open"]=1 ["teams"]=1 ["unlock"]=1 ["apps"]=1 ["apps:create"]=1 ["apps:destroy"]=1 ["apps:errors"]=1 ["apps:favorites"]=1 ["apps:favorites:add"]=1 ["apps:favorites:remove"]=1 ["apps:info"]=1 ["apps:open"]=1 ["apps:rename"]=1 ["apps:stacks"]=1 ["apps:stacks:set"]=1 ["config:set"]=1 ["drains"]=1 ["drains:add"]=1 ["drains:remove"]=1 ["dyno:kill"]=1 ["dyno:resize"]=1 ["dyno:restart"]=1 ["dyno:scale"]=1 ["dyno:stop"]=1 ["features"]=1 ["features:disable"]=1 ["features:enable"]=1 ["features:info"]=1 ["keys"]=1 ["keys:add"]=1 ["keys:clear"]=0 ["keys:remove"]=0 ["labs"]=1 ["labs:enable"]=1 ["labs:info"]=1 ["maintenance"]=1 ["maintenance:off"]=1 ["maintenance:on"]=1 ["notifications"]=1 ["ps"]=1 ["ps:kill"]=1 ["ps:resize"]=1 ["ps:restart"]=1 ["ps:scale"]=1 ["ps:stop"]=1 ["ps:type"]=1 ["releases"]=1 ["releases:info"]=1 ["releases:output"]=1 ["releases:rollback"]=1 ["ps:copy"]=1 ["ps:exec"]=1 ["ps:forward"]=1 ["ps:socks"]=1 ["commands"]=1 ["update"]=1 ["plugins"]=1 ["plugins:inspect"]=1 ["plugins:install"]=1 ["plugins:add"]=1 ["plugins:link"]=1 ["plugins:uninstall"]=1 ["plugins:unlink"]=1 ["plugins:remove"]=1 ["plugins:update"]=1 ["version"]=1 ["which"]=0 ["help"]=1 )
