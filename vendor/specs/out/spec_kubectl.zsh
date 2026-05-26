# Termy spec-highlight: zsh assoc arrays for command "kubectl"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_KUBECTL_SUB / TS_KUBECTL_OPT / nested TS_KUBECTL_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_KUBECTL_alpha_debug_OPT=( ["--arguments-only"]=1 ["--attach"]=1 ["--container"]=1 ["--env"]=1 ["--image"]=1 ["--image-pull-policy"]=1 ["--quiet"]=1 ["-i"]=1 ["--stdin"]=1 ["--target"]=1 ["-t"]=1 ["--tty"]=1 )
typeset -gA TS_KUBECTL_alpha_SUB=( ["debug"]=1 )
typeset -gA TS_KUBECTL_annotate_OPT=( ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--resource-version"]=1 ["--dry-run"]=1 ["--field-selector"]=1 ["--local"]=0 ["--all"]=0 ["--allow-missing-template-keys"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--overwrite"]=0 ["--record"]=0 )
# TS_KUBECTL_annotate positional args: Resource_Type Resource KEY_VAL
typeset -gA TS_KUBECTL_api_resources_OPT=( ["-o"]=1 ["--output"]=1 ["--api-group"]=1 ["--cached"]=0 ["--namespaced"]=0 ["--no-headers"]=0 ["--sort-by"]=1 ["--verbs"]=1 )
typeset -gA TS_KUBECTL_apply_edit_last_applied_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--record"]=0 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--windows-line-endings"]=0 ["--field-manager"]=1 ["--show-manged-fields"]=0 )
# TS_KUBECTL_apply_edit_last_applied positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_apply_set_last_applied_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--show-manged-fields"]=0 ["--create-annotation"]=0 )
typeset -gA TS_KUBECTL_apply_view_last_applied_OPT=( ["--all"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 )
# TS_KUBECTL_apply_view_last_applied positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_apply_SUB=( ["edit-last-applied"]=1 ["set-last-applied"]=1 ["view-last-applied"]=1 )
typeset -gA TS_KUBECTL_apply_OPT=( ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--resource-version"]=1 ["--dry-run"]=1 ["--field-selector"]=1 ["--local"]=0 ["--all"]=0 ["--allow-missing-template-keys"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--overwrite"]=0 ["--record"]=0 ["--cascade"]=0 ["--field-manager"]=1 ["--force"]=0 ["--force-conflicts"]=0 ["--grace-period"]=1 ["--openapi-patch"]=0 ["--overwrite"]=0 ["--prune"]=0 ["--prune-whitelist"]=1 ["--server-side"]=0 ["--timeout"]=1 ["--validate"]=0 ["--wait"]=0 )
typeset -gA TS_KUBECTL_attach_OPT=( ["-c"]=1 ["--container"]=1 ["--pod-running-timeout"]=1 ["-i"]=0 ["--stdin"]=0 ["-t"]=0 ["--tty"]=0 )
# TS_KUBECTL_attach positional args: Running_Pods
typeset -gA TS_KUBECTL_auth_can_i_OPT=( ["-A"]=0 ["--all-namespaces"]=0 ["--list"]=0 ["--no-headers"]=0 ["-q"]=0 ["--quiet"]=0 ["--subresource"]=1 )
# TS_KUBECTL_auth_can_i positional args: VERB TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_auth_reconcile_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--remove-extra-permissions"]=0 ["--remove-extra-subjects"]=0 ["--show-managed-fields"]=0 )
typeset -gA TS_KUBECTL_auth_SUB=( ["can-i"]=1 ["reconcile"]=1 )
typeset -gA TS_KUBECTL_autoscale_OPT=( ["--allow-missing-template-keys"]=0 ["-o"]=1 ["--output"]=1 ["--record"]=0 ["-R"]=0 ["--recursive"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["--template"]=1 ["--cpu-percent"]=1 ["--generator"]=1 ["--max"]=1 ["--min"]=1 ["--name"]=1 ["--save-config"]=0 )
# TS_KUBECTL_autoscale positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_certificate_approve_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--force"]=0 )
# TS_KUBECTL_certificate_approve positional args: NAME
typeset -gA TS_KUBECTL_certificate_deny_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--force"]=0 )
# TS_KUBECTL_certificate_deny positional args: NAME
typeset -gA TS_KUBECTL_certificate_SUB=( ["approve"]=1 ["deny"]=1 )
typeset -gA TS_KUBECTL_cluster_info_dump_OPT=( ["--allow-missing-template-keys"]=0 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["-A"]=0 ["--all-namespaces"]=0 ["--namespaces"]=1 ["--output-directory"]=1 ["--pod-running-timeout"]=1 ["--show-managed-fields"]=0 )
typeset -gA TS_KUBECTL_cluster_info_SUB=( ["dump"]=1 )
typeset -gA TS_KUBECTL_config_get_contexts_OPT=( ["-o"]=1 ["--output"]=1 ["--no-headers"]=1 )
# TS_KUBECTL_config_get_contexts positional args: Context
typeset -gA TS_KUBECTL_config_set_OPT=( ["--set-raw-bytes"]=1 )
# TS_KUBECTL_config_set positional args: PROPERTY_NAME PROPERTY_VALUE
typeset -gA TS_KUBECTL_config_set_cluster_OPT=( ["--embed-certs"]=0 ["--server"]=1 ["--certificate-authority"]=1 ["--insecure-skip-tls-verify"]=1 ["--tls-server-name"]=1 )
# TS_KUBECTL_config_set_cluster positional args: NAME
typeset -gA TS_KUBECTL_config_set_context_OPT=( ["--current"]=0 ["--cluster"]=1 ["--user"]=1 ["--namespace"]=1 )
# TS_KUBECTL_config_set_context positional args: Context
typeset -gA TS_KUBECTL_config_set_credentials_OPT=( ["--client-certificate"]=1 ["--client-key"]=1 ["--token"]=1 ["--username"]=1 ["--password"]=1 ["--auth-provider"]=1 ["--auth-provider-arg"]=1 ["--embed-certs"]=0 ["--exec-api-version"]=1 ["--exec-arg"]=1 ["--exec-command"]=1 ["--exec-env"]=1 )
# TS_KUBECTL_config_set_credentials positional args: Cluster
typeset -gA TS_KUBECTL_config_view_OPT=( ["--allow-missing-template-keys"]=0 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--flatten"]=0 ["--merge"]=0 ["--minify"]=0 ["--raw"]=0 ["--show-managed-fields"]=0 )
typeset -gA TS_KUBECTL_config_SUB=( ["current-context"]=0 ["delete-cluster"]=0 ["delete-context"]=0 ["get-clusters"]=0 ["get-contexts"]=1 ["get-users"]=0 ["rename-context"]=0 ["set"]=1 ["set-cluster"]=1 ["set-context"]=1 ["set-credentials"]=1 ["unset"]=0 ["use-context"]=0 ["view"]=1 )
typeset -gA TS_KUBECTL_config_OPT=( ["--kubeconfig"]=1 )
typeset -gA TS_KUBECTL_convert_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--local"]=0 ["--output-version"]=1 ["--validate"]=0 )
typeset -gA TS_KUBECTL_cordon_OPT=( ["--dry-run"]=1 ["-l"]=1 ["--selector"]=1 )
# TS_KUBECTL_cordon positional args: Node
typeset -gA TS_KUBECTL_cp_OPT=( ["-c"]=1 ["--container"]=1 ["--no-preserve"]=1 )
typeset -gA TS_KUBECTL_create_clusterrole_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--aggregation-rule"]=1 ["--non-resource-url"]=1 ["--resource"]=1 ["--resource-name"]=1 ["--save-config"]=0 ["--validate"]=0 ["--verb"]=1 )
# TS_KUBECTL_create_clusterrole positional args: NAME
typeset -gA TS_KUBECTL_create_clusterrolebinding_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--clusterrole"]=1 ["--user"]=1 ["--group"]=1 ["--save-config"]=0 ["--serviceaccount"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_clusterrolebinding positional args: NAME
typeset -gA TS_KUBECTL_create_configmap_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--append-hash"]=0 ["--from-env-file"]=1 ["--from-file"]=1 ["--from-literal"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_configmap positional args: NAME
typeset -gA TS_KUBECTL_create_cronjob_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--image"]=1 ["--restart"]=1 ["--save-config"]=0 ["--schedule"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_cronjob positional args: NAME
typeset -gA TS_KUBECTL_create_deployment_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--image"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_deployment positional args: NAME
typeset -gA TS_KUBECTL_create_ingress_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--annotation"]=1 ["--class"]=1 ["--default-backend"]=1 ["--field-manager"]=1 ["--rule"]=1 ["--show-managed-fields"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_ingress positional args: NAME
typeset -gA TS_KUBECTL_create_job_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--from"]=1 ["--image"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_job positional args: NAME COMMAND
typeset -gA TS_KUBECTL_create_namespace_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_namespace positional args: NAME
typeset -gA TS_KUBECTL_create_poddisruptionbudget_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["-l"]=1 ["--selector"]=1 ["--max-unavailable"]=1 ["--min-available"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_poddisruptionbudget positional args: NAME
typeset -gA TS_KUBECTL_create_priorityclass_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--description"]=1 ["--global-default"]=0 ["--preemption-policy"]=1 ["--save-config"]=0 ["--validate"]=0 ["--value"]=1 )
# TS_KUBECTL_create_priorityclass positional args: NAME
typeset -gA TS_KUBECTL_create_quota_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--field-manager"]=1 ["--hard"]=1 ["--save-config"]=0 ["--scopes"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_quota positional args: NAME
typeset -gA TS_KUBECTL_create_role_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--resource"]=1 ["--resource-name"]=1 ["--save-config"]=0 ["--validate"]=0 ["--verb"]=1 )
# TS_KUBECTL_create_role positional args: NAME
typeset -gA TS_KUBECTL_create_rolebinding_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--clusterrole"]=1 ["--group"]=1 ["--role"]=1 ["--save-config"]=0 ["--serviceaccount"]=1 ["--username"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_rolebinding positional args: NAME
typeset -gA TS_KUBECTL_create_secret_docker_registry_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--append-hash"]=0 ["--docker-email"]=1 ["--docker-password"]=1 ["--docker-server"]=1 ["--docker-username"]=1 ["--from-file"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_secret_docker_registry positional args: NAME
typeset -gA TS_KUBECTL_create_secret_generic_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--append-hash"]=0 ["--from-env-file"]=1 ["--from-file"]=1 ["--from-literal"]=1 ["--save-config"]=0 ["--type"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_secret_generic positional args: NAME
typeset -gA TS_KUBECTL_create_secret_tls_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--append-hash"]=0 ["--cert"]=1 ["--key"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_secret_tls positional args: NAME
typeset -gA TS_KUBECTL_create_secret_SUB=( ["docker-registry"]=1 ["generic"]=1 ["tls"]=1 )
typeset -gA TS_KUBECTL_create_service_clusterip_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--clusterip"]=1 ["--save-config"]=0 ["--tcp"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_service_clusterip positional args: NAME
typeset -gA TS_KUBECTL_create_service_externalname_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--external-name"]=1 ["--save-config"]=0 ["--tcp"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_service_externalname positional args: NAME
typeset -gA TS_KUBECTL_create_service_loadbalancer_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--save-config"]=0 ["--tcp"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_service_loadbalancer positional args: NAME
typeset -gA TS_KUBECTL_create_service_nodeport_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--node-port"]=1 ["--save-config"]=0 ["--tcp"]=1 ["--validate"]=0 )
# TS_KUBECTL_create_service_nodeport positional args: NAME
typeset -gA TS_KUBECTL_create_service_SUB=( ["clusterip"]=1 ["externalname"]=1 ["loadbalancer"]=1 ["nodeport"]=1 )
typeset -gA TS_KUBECTL_create_serviceaccount_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["--template"]=1 ["--save-config"]=0 ["--validate"]=0 )
# TS_KUBECTL_create_serviceaccount positional args: NAME
typeset -gA TS_KUBECTL_create_SUB=( ["clusterrole"]=1 ["clusterrolebinding"]=1 ["configmap"]=1 ["cronjob"]=1 ["deployment"]=1 ["ingress"]=1 ["job"]=1 ["namespace"]=1 ["poddisruptionbudget"]=1 ["priorityclass"]=1 ["quota"]=1 ["role"]=1 ["rolebinding"]=1 ["secret"]=1 ["service"]=1 ["serviceaccount"]=1 )
typeset -gA TS_KUBECTL_create_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--record"]=0 ["--edit"]=0 ["--raw"]=0 ["--save-config"]=0 ["--validate"]=0 ["--windows-line-endings"]=0 )
typeset -gA TS_KUBECTL_delete_OPT=( ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--all"]=0 ["--field-selector"]=1 ["-A"]=0 ["--all-namespaces"]=0 ["--cascade"]=0 ["--force"]=0 ["--grace-period"]=1 ["--ignore-not-found"]=0 ["--now"]=0 ["--raw"]=0 ["--timeout"]=1 ["--wait"]=0 )
# TS_KUBECTL_delete positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_describe_OPT=( ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["-A"]=0 ["--all-namespaces"]=0 ["--show-events"]=0 )
# TS_KUBECTL_describe positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_diff_OPT=( ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-R"]=0 ["--recursive"]=0 ["--field-manager"]=1 ["--force-conflicts"]=0 ["--server-side"]=0 )
typeset -gA TS_KUBECTL_drain_OPT=( ["--dry-run"]=1 ["-l"]=1 ["--selector"]=1 ["--delete-local-data"]=0 ["--disable-eviction"]=0 ["--force"]=0 ["--grace-period"]=1 ["--ignore-daemonsets"]=0 ["--pod-selector"]=1 ["--skip-wait-for-delete-timeout"]=1 ["--timeout"]=1 )
# TS_KUBECTL_drain positional args: Node
typeset -gA TS_KUBECTL_edit_OPT=( ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--allow-missing-template-keys"]=0 ["--template"]=1 ["--record"]=0 ["--output-patch"]=1 ["--save-config"]=0 ["--validate"]=0 ["--windows-line-endings"]=0 )
# TS_KUBECTL_edit positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_exec_OPT=( ["-f"]=1 ["--filename"]=1 ["-c"]=1 ["--container"]=1 ["--pod-running-timeout"]=1 ["-i"]=0 ["--stdin"]=0 ["-t"]=0 ["--tty"]=0 )
# TS_KUBECTL_exec positional args: Running_Pods COMMAND
typeset -gA TS_KUBECTL_explain_OPT=( ["--api-version"]=1 ["--recursive"]=0 )
# TS_KUBECTL_explain positional args: Resource_Type
typeset -gA TS_KUBECTL_expose_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--record"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--cluster-ip"]=1 ["--external-ip"]=1 ["--generator"]=1 ["-l"]=1 ["--labels"]=1 ["--load-balancer-ip"]=1 ["--name"]=1 ["--overrides"]=1 ["--port"]=1 ["--protocol"]=1 ["--save-config"]=0 ["--session-affinity"]=1 ["--target-port"]=1 ["--type"]=1 )
# TS_KUBECTL_expose positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_get_OPT=( ["--allow-missing-template-keys"]=0 ["--field-selector"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["-A"]=0 ["--all-namespaces"]=0 ["--chunk-size"]=1 ["--ignore-not-found"]=0 ["-L"]=1 ["--label-columns"]=1 ["--no-headers"]=0 ["--output-watch-events"]=0 ["--raw"]=0 ["--server-print"]=0 ["--show-kind"]=0 ["--show-labels"]=0 ["--sort-by"]=1 ["-w"]=0 ["--watch"]=0 ["--watch-only"]=0 )
# TS_KUBECTL_get positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_kustomize_OPT=( ["-o"]=1 ["--output"]=1 ["--allow-id-changes"]=0 ["--enable-alpha-plugins"]=0 ["--enable-managedby-label"]=0 ["--env"]=1 ["-e"]=1 ["--load-restrictor"]=1 ["--mount"]=1 ["--network"]=0 ["--network-name"]=1 ["--reorder"]=0 )
# TS_KUBECTL_kustomize positional args: DIR
typeset -gA TS_KUBECTL_label_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["--field-selector"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["--local"]=0 ["-o"]=1 ["--output"]=1 ["--record"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--resource-version"]=1 ["--all"]=0 ["--list"]=0 ["--overwrite"]=0 )
# TS_KUBECTL_label positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_logs_OPT=( ["-l"]=1 ["--selector"]=1 ["--all-containers"]=0 ["-c"]=1 ["--container"]=1 ["-f"]=0 ["--follow"]=0 ["--ignore-errors"]=0 ["--insecure-skip-tls-verify-backend"]=0 ["--limit-bytes"]=1 ["--max-log-requests"]=1 ["--pod-running-timeout"]=1 ["--prefix"]=0 ["-p"]=0 ["--previous"]=0 ["--since"]=1 ["--since-time"]=1 ["--tail"]=1 ["--timestamps"]=0 )
# TS_KUBECTL_logs positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_patch_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["--local"]=0 ["-o"]=1 ["--output"]=1 ["--record"]=0 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["-p"]=1 ["--patch"]=1 ["--type"]=1 )
# TS_KUBECTL_patch positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_port_forward_OPT=( ["--address"]=1 ["--pod-running-timeout"]=1 )
# TS_KUBECTL_port_forward positional args: TYPE___TYPE_NAME Resource _LOCAL_PORT_REMOTE_PORT_
typeset -gA TS_KUBECTL_proxy_OPT=( ["--accept-hosts"]=1 ["--accept-paths"]=1 ["--address"]=1 ["--api-prefix"]=1 ["--disable-filter"]=0 ["--keepalive"]=1 ["-p"]=1 ["--port"]=1 ["--reject-methods"]=1 ["--reject-paths"]=1 ["-u"]=1 ["--unix-socket"]=1 ["-w"]=1 ["--www"]=1 ["-P"]=1 ["--www-prefix"]=1 )
typeset -gA TS_KUBECTL_replace_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--cascade"]=0 ["--force"]=0 ["--grace-period"]=1 ["--raw"]=1 ["--save-config"]=0 ["--timeout"]=1 ["--validate"]=0 ["--wait"]=0 )
typeset -gA TS_KUBECTL_rollout_history_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--revision"]=1 )
# TS_KUBECTL_rollout_history positional args: Deployments
typeset -gA TS_KUBECTL_rollout_pause_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 )
# TS_KUBECTL_rollout_pause positional args: Deployments
typeset -gA TS_KUBECTL_rollout_restart_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 )
# TS_KUBECTL_rollout_restart positional args: Deployments
typeset -gA TS_KUBECTL_rollout_resume_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 )
# TS_KUBECTL_rollout_resume positional args: Deployments
typeset -gA TS_KUBECTL_rollout_status_OPT=( ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-R"]=0 ["--recursive"]=0 ["--revision"]=1 ["--timeout"]=1 ["-w"]=0 ["--watch"]=0 )
# TS_KUBECTL_rollout_status positional args: Deployments
typeset -gA TS_KUBECTL_rollout_undo_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-R"]=0 ["--recursive"]=0 ["--dry-run"]=1 ["--to_revision"]=1 ["--timeout"]=1 )
# TS_KUBECTL_rollout_undo positional args: Deployments
typeset -gA TS_KUBECTL_rollout_SUB=( ["history"]=1 ["pause"]=1 ["restart"]=1 ["resume"]=1 ["status"]=1 ["undo"]=1 )
typeset -gA TS_KUBECTL_run_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["--dry-run"]=1 ["-k"]=1 ["--kustomize"]=1 ["-R"]=0 ["--recursive"]=0 ["-o"]=1 ["--output"]=1 ["--record"]=0 ["--template"]=1 ["--annotations"]=1 ["--attach"]=0 ["--cascade"]=1 ["--command"]=0 ["--env"]=1 ["--expose"]=0 ["--force"]=0 ["--grace-period"]=1 ["--hostport"]=1 ["--image"]=1 ["--image-pull-policy"]=1 ["-l"]=1 ["--labels"]=1 ["--leave-stdin-open"]=0 ["--limits"]=1 ["--overrides"]=1 ["--pod-running-timeout"]=1 ["--port"]=1 ["--quiet"]=0 ["--requests"]=1 ["--restart"]=1 ["--rm"]=0 ["--save-config"]=0 ["--serviceaccount"]=1 ["-i"]=0 ["--stdin"]=0 ["--timeout"]=1 ["-t"]=0 ["--tty"]=0 ["--wait"]=0 )
# TS_KUBECTL_run positional args: NAME
typeset -gA TS_KUBECTL_scale_OPT=( ["--allow-missing-template-keys"]=0 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["--record"]=0 ["--resource-version"]=1 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--dry-run"]=1 ["--all"]=0 ["--current-replicas"]=1 ["--replicas"]=1 ["--timeout"]=1 )
# TS_KUBECTL_scale positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_set_env_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--local"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--all"]=0 ["-c"]=1 ["--containers"]=1 ["-e"]=1 ["--env"]=1 ["--from"]=1 ["--keys"]=1 ["--list"]=0 ["--overwrite"]=0 ["--prefix"]=1 ["--resolve"]=0 )
# TS_KUBECTL_set_env positional args: TYPE___TYPE_NAME Resource KEY_VALUE
typeset -gA TS_KUBECTL_set_image_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--local"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--record"]=0 ["--all"]=0 )
# TS_KUBECTL_set_image positional args: TYPE___TYPE_NAME Resource CONTAINER_NAME_IMAGE_NAME
typeset -gA TS_KUBECTL_set_resources_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--local"]=0 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--record"]=0 ["--all"]=0 ["-c"]=1 ["--containers"]=1 ["--limits"]=1 ["--requests"]=1 )
# TS_KUBECTL_set_resources positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_set_selector_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--local"]=0 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--record"]=0 ["--resource-version"]=1 ["--all"]=1 )
# TS_KUBECTL_set_selector positional args: TYPE___TYPE_NAME Resource EXPRESSIONS
typeset -gA TS_KUBECTL_set_serviceaccount_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--local"]=0 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--record"]=0 ["--all"]=0 )
# TS_KUBECTL_set_serviceaccount positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_set_subject_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-f"]=1 ["--filename"]=1 ["-k"]=1 ["--kustomize"]=1 ["-o"]=1 ["--output"]=1 ["--local"]=0 ["-R"]=0 ["--recursive"]=0 ["--template"]=1 ["--record"]=0 ["--all"]=0 ["--group"]=1 ["--serviceaccount"]=1 )
# TS_KUBECTL_set_subject positional args: TYPE___TYPE_NAME Resource
typeset -gA TS_KUBECTL_set_SUB=( ["env"]=1 ["image"]=1 ["resources"]=1 ["selector"]=1 ["serviceaccount"]=1 ["subject"]=1 )
typeset -gA TS_KUBECTL_taint_OPT=( ["--allow-missing-template-keys"]=0 ["--dry-run"]=1 ["-o"]=1 ["--output"]=1 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--all"]=0 ["--overwrite"]=0 ["--validate"]=0 )
# TS_KUBECTL_taint positional args: Node
typeset -gA TS_KUBECTL_uncordon_OPT=( ["--dry-run"]=1 ["-l"]=1 ["--selector"]=1 )
# TS_KUBECTL_uncordon positional args: Node
typeset -gA TS_KUBECTL_version_OPT=( ["-o"]=1 ["--output"]=1 ["--client"]=0 )
typeset -gA TS_KUBECTL_wait_OPT=( ["--allow-missing-template-keys"]=0 ["--field-selector"]=1 ["-f"]=1 ["--filename"]=1 ["--local"]=0 ["-o"]=1 ["--output"]=1 ["-R"]=0 ["--recursive"]=0 ["-l"]=1 ["--selector"]=1 ["--template"]=1 ["--all"]=0 ["-A"]=1 ["--all-namespaces"]=1 ["--for"]=1 ["--timeout"]=1 )
typeset -gA TS_KUBECTL_SUB=( ["alpha"]=1 ["annotate"]=1 ["api-resources"]=1 ["api-versions"]=0 ["apply"]=1 ["attach"]=1 ["auth"]=1 ["autoscale"]=1 ["certificate"]=1 ["cluster-info"]=1 ["completion"]=0 ["config"]=1 ["convert"]=1 ["cordon"]=1 ["cp"]=1 ["create"]=1 ["delete"]=1 ["describe"]=1 ["diff"]=1 ["drain"]=1 ["edit"]=1 ["exec"]=1 ["explain"]=1 ["expose"]=1 ["get"]=1 ["kustomize"]=1 ["label"]=1 ["logs"]=1 ["patch"]=1 ["plugin"]=0 ["port-forward"]=1 ["proxy"]=1 ["replace"]=1 ["rollout"]=1 ["run"]=1 ["scale"]=1 ["set"]=1 ["taint"]=1 ["top"]=0 ["uncordon"]=1 ["version"]=1 ["wait"]=1 )
typeset -gA TS_KUBECTL_OPT=( ["-n"]=1 ["--namespace"]=1 )
