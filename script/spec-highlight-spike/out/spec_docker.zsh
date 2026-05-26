# spec-highlight-spike: zsh assoc arrays for command "docker"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_DOCKER_SUB / TS_DOCKER_OPT / nested TS_DOCKER_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_DOCKER_attach_OPT=( ["--detach-keys"]=1 ["--no-stdin"]=0 ["--sig-proxy"]=0 )
typeset -gA TS_DOCKER_build_OPT=( ["--add-host"]=1 ["--build-arg"]=1 ["--cache-from"]=1 ["--disable-content-trust"]=0 ["-f"]=1 ["--file"]=1 ["--iidfile"]=1 ["--isolation"]=1 ["--label"]=1 ["--network"]=1 ["--no-cache"]=0 ["-o"]=1 ["--output"]=1 ["--platform"]=1 ["--progress"]=1 ["--pull"]=0 ["-q"]=0 ["--quiet"]=0 ["--secret"]=1 ["--squash"]=0 ["--ssh"]=1 ["-t"]=0 ["--tag"]=0 ["--target"]=1 )
# TS_DOCKER_build positional args: path
typeset -gA TS_DOCKER_commit_OPT=( ["-a"]=1 ["--author"]=1 ["-c"]=1 ["--change"]=1 ["-m"]=1 ["--message"]=1 ["-p"]=0 ["--pause"]=0 )
# TS_DOCKER_commit positional args: container _REPOSITORY__TAG__
typeset -gA TS_DOCKER_cp_OPT=( ["-a"]=0 ["--archive"]=0 ["-L"]=0 ["--follow-link"]=0 )
# TS_DOCKER_cp positional args: CONTAINER_SRC_PATH_DEST_PATH___OR_SRC_PATH___CONTAINER_DEST_PATH
typeset -gA TS_DOCKER_create_OPT=( ["--add-host"]=1 ["-a"]=1 ["--attach"]=1 ["--blkio-weight"]=1 ["--blkio-weight-device"]=1 ["--cap-add"]=1 ["--cap-drop"]=1 ["--cgroup-parent"]=1 ["--cgroupns"]=1 ["--cidfile"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-rt-period"]=1 ["--cpu-rt-runtime"]=1 ["-c"]=1 ["--cpu-shares"]=1 ["--cpus"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["--device"]=1 ["--device-cgroup-rule"]=1 ["--device-read-bps"]=1 ["--device-read-iops"]=1 ["--device-write-bps"]=1 ["--device-write-iops"]=1 ["--disable-content-trust"]=0 ["--dns"]=1 ["--dns-option"]=1 ["--dns-search"]=1 ["--domainname"]=1 ["--entrypoint"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["--expose"]=1 ["--gpus"]=1 ["--group-add"]=1 ["--health-cmd"]=1 ["--health-interval"]=1 ["--health-retries"]=1 ["--health-start-period"]=1 ["--health-timeout"]=1 ["--help"]=0 ["-h"]=1 ["--hostname"]=1 ["--init"]=0 ["-i"]=0 ["--interactive"]=0 ["--ip"]=1 ["--ip6"]=1 ["--ipc"]=1 ["--isolation"]=1 ["--kernel-memory"]=1 ["-l"]=1 ["--label"]=1 ["--label-file"]=1 ["--link"]=1 ["--link-local-ip"]=1 ["--log-driver"]=1 ["--log-opt"]=1 ["--mac-address"]=1 ["-m"]=1 ["--memory"]=1 ["--memory-reservation"]=1 ["--memory-swap"]=1 ["--memory-swappiness"]=1 ["--mount"]=1 ["--name"]=1 ["--network"]=1 ["--network-alias"]=1 ["--no-healthcheck"]=0 ["--oom-kill-disable"]=0 ["--oom-score-adj"]=1 ["--pid"]=1 ["--pids-limit"]=1 ["--platform"]=1 ["--privileged"]=0 ["-p"]=1 ["--publish"]=1 ["-P"]=0 ["--publish-all"]=0 ["--pull"]=1 ["--read-only"]=0 ["--restart"]=1 ["--rm"]=0 ["--runtime"]=1 ["--security-opt"]=1 ["--shm-size"]=1 ["--stop-signal"]=1 ["--stop-timeout"]=1 ["--storage-opt"]=1 ["--sysctl"]=1 ["--tmpfs"]=1 ["-t"]=0 ["--tty"]=0 ["--ulimit"]=1 ["-u"]=1 ["--user"]=1 ["--userns"]=1 ["--uts"]=1 ["-v"]=1 ["--volume"]=1 ["--volume-driver"]=1 ["--volumes-from"]=1 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_create positional args: container command
typeset -gA TS_DOCKER_events_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--since"]=1 ["--until"]=1 )
typeset -gA TS_DOCKER_exec_OPT=( ["-it"]=0 ["-d"]=0 ["--detach"]=0 ["--detach-keys"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["-i"]=0 ["--interactive"]=0 ["--privileged"]=0 ["-t"]=0 ["--tty"]=0 ["-u"]=1 ["--user"]=1 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_exec positional args: container command
typeset -gA TS_DOCKER_export_OPT=( ["-o"]=1 ["--output"]=1 )
# TS_DOCKER_export positional args: container
typeset -gA TS_DOCKER_history_OPT=( ["--format"]=1 ["-H"]=0 ["--human"]=0 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_history positional args: image
typeset -gA TS_DOCKER_images_OPT=( ["-a"]=0 ["--all"]=0 ["--digests"]=0 ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_images positional args: _REPOSITORY__TAG__
typeset -gA TS_DOCKER_import_OPT=( ["-c"]=1 ["--change"]=1 ["-m"]=1 ["--message"]=1 ["--platform"]=1 )
# TS_DOCKER_import positional args: file_URL____REPOSITORY__TAG__
typeset -gA TS_DOCKER_info_OPT=( ["-f"]=1 ["--format"]=1 )
typeset -gA TS_DOCKER_inspect_OPT=( ["-f"]=1 ["--format"]=1 ["-s"]=0 ["--size"]=0 ["--type"]=1 )
# TS_DOCKER_inspect positional args: Name_or_ID
typeset -gA TS_DOCKER_kill_OPT=( ["-s"]=1 ["--signal"]=1 )
# TS_DOCKER_kill positional args: container
typeset -gA TS_DOCKER_load_OPT=( ["-i"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_login_OPT=( ["-p"]=1 ["--password"]=1 ["--password-stdin"]=0 ["-u"]=1 ["--username"]=1 )
# TS_DOCKER_login positional args: server
typeset -gA TS_DOCKER_logs_OPT=( ["--details"]=0 ["-f"]=0 ["--follow"]=0 ["--since"]=1 ["-n"]=1 ["--tail"]=1 ["-t"]=0 ["--timestamps"]=0 ["--until"]=1 )
# TS_DOCKER_logs positional args: container
typeset -gA TS_DOCKER_ps_OPT=( ["-a"]=0 ["--all"]=0 ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["-n"]=1 ["--last"]=1 ["-l"]=0 ["--latest"]=0 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 ["-s"]=0 ["--size"]=0 )
typeset -gA TS_DOCKER_pull_OPT=( ["-a"]=0 ["--all-tags"]=0 ["--disable-content-trust"]=0 ["--platform"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_pull positional args: NAME__TAG__DIGEST_
typeset -gA TS_DOCKER_push_OPT=( ["-a"]=0 ["--all-tags"]=0 ["--disable-content-trust"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_push positional args: NAME__TAG_
typeset -gA TS_DOCKER_restart_OPT=( ["-t"]=1 ["--time"]=1 )
# TS_DOCKER_restart positional args: container
typeset -gA TS_DOCKER_rm_OPT=( ["-f"]=0 ["--force"]=0 ["-l"]=0 ["--link"]=0 ["-v"]=0 ["--volumes"]=0 )
# TS_DOCKER_rm positional args: containers
typeset -gA TS_DOCKER_rmi_OPT=( ["-f"]=0 ["--force"]=0 ["--no-prune"]=0 )
# TS_DOCKER_rmi positional args: image
typeset -gA TS_DOCKER_run_OPT=( ["-it"]=0 ["--add-host"]=1 ["-a"]=1 ["--attach"]=1 ["--blkio-weight"]=1 ["--blkio-weight-device"]=1 ["--cap-add"]=1 ["--cap-drop"]=1 ["--cgroup-parent"]=1 ["--cgroupns"]=1 ["--cidfile"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-rt-period"]=1 ["--cpu-rt-runtime"]=1 ["-c"]=1 ["--cpu-shares"]=1 ["--cpus"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["-d"]=0 ["--detach"]=0 ["--detach-keys"]=1 ["--device"]=1 ["--device-cgroup-rule"]=1 ["--device-read-bps"]=1 ["--device-read-iops"]=1 ["--device-write-bps"]=1 ["--device-write-iops"]=1 ["--disable-content-trust"]=0 ["--dns"]=1 ["--dns-option"]=1 ["--dns-search"]=1 ["--domainname"]=1 ["--entrypoint"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["--expose"]=1 ["--gpus"]=1 ["--group-add"]=1 ["--health-cmd"]=1 ["--health-interval"]=1 ["--health-retries"]=1 ["--health-start-period"]=1 ["--health-timeout"]=1 ["--help"]=0 ["-h"]=1 ["--hostname"]=1 ["--init"]=0 ["-i"]=0 ["--interactive"]=0 ["--ip"]=1 ["--ip6"]=1 ["--ipc"]=1 ["--isolation"]=1 ["--kernel-memory"]=1 ["-l"]=1 ["--label"]=1 ["--label-file"]=1 ["--link"]=1 ["--link-local-ip"]=1 ["--log-driver"]=1 ["--log-opt"]=1 ["--mac-address"]=1 ["-m"]=1 ["--memory"]=1 ["--memory-reservation"]=1 ["--memory-swap"]=1 ["--memory-swappiness"]=1 ["--mount"]=1 ["--name"]=1 ["--network"]=1 ["--network-alias"]=1 ["--no-healthcheck"]=0 ["--oom-kill-disable"]=0 ["--oom-score-adj"]=1 ["--pid"]=1 ["--pids-limit"]=1 ["--platform"]=1 ["--privileged"]=0 ["-p"]=1 ["--publish"]=1 ["-P"]=0 ["--publish-all"]=0 ["--pull"]=1 ["--read-only"]=0 ["--restart"]=1 ["--rm"]=0 ["--runtime"]=1 ["--security-opt"]=1 ["--shm-size"]=1 ["--sig-proxy"]=0 ["--stop-signal"]=1 ["--stop-timeout"]=1 ["--storage-opt"]=1 ["--sysctl"]=1 ["--tmpfs"]=1 ["-t"]=0 ["--tty"]=0 ["--ulimit"]=1 ["-u"]=1 ["--user"]=1 ["--userns"]=1 ["--uts"]=1 ["-v"]=1 ["--volume"]=1 ["--volume-driver"]=1 ["--volumes-from"]=1 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_run positional args: image command
typeset -gA TS_DOCKER_save_OPT=( ["-o"]=1 ["--output"]=1 )
# TS_DOCKER_save positional args: image
typeset -gA TS_DOCKER_search_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--limit"]=1 ["--no-trunc"]=0 )
# TS_DOCKER_search positional args: TERM
typeset -gA TS_DOCKER_sbom_OPT=( ["-D"]=0 ["--debug"]=0 ["--exclude"]=1 ["--format"]=1 ["--layers"]=1 ["-o"]=1 ["--output"]=1 ["--platform"]=1 ["--quiet"]=0 ["-v"]=0 ["--version"]=0 )
# TS_DOCKER_sbom positional args: image
typeset -gA TS_DOCKER_start_OPT=( ["-a"]=0 ["--attach"]=0 ["--detach-keys"]=1 ["-i"]=0 ["--interactive"]=0 )
# TS_DOCKER_start positional args: container
typeset -gA TS_DOCKER_stats_OPT=( ["-a"]=0 ["--all"]=0 ["--format"]=1 ["--no-stream"]=0 ["--no-trunc"]=0 )
# TS_DOCKER_stats positional args: container
typeset -gA TS_DOCKER_stop_OPT=( ["-t"]=1 ["--t"]=1 )
# TS_DOCKER_stop positional args: container
typeset -gA TS_DOCKER_update_OPT=( ["--blkio-weight"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-rt-period"]=1 ["--cpu-rt-runtime"]=1 ["-c"]=1 ["--cpu-shares"]=1 ["--cpus"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["--kernel-memory"]=1 ["-m"]=1 ["--memory"]=1 ["--memory-reservation"]=1 ["--memory-swap"]=1 ["--pids-limit"]=1 ["--restart"]=1 )
# TS_DOCKER_update positional args: container
typeset -gA TS_DOCKER_version_OPT=( ["-f"]=1 ["--format"]=1 ["--kubeconfig"]=1 )
typeset -gA TS_DOCKER_builder_build_OPT=( ["--add-host"]=1 ["--build-arg"]=1 ["--cache-from"]=1 ["--disable-content-trust"]=0 ["-f"]=1 ["--file"]=1 ["--iidfile"]=1 ["--isolation"]=1 ["--label"]=1 ["--network"]=1 ["--no-cache"]=0 ["-o"]=1 ["--output"]=1 ["--platform"]=1 ["--progress"]=1 ["--pull"]=0 ["-q"]=0 ["--quiet"]=0 ["--secret"]=1 ["--squash"]=0 ["--ssh"]=1 ["-t"]=0 ["--tag"]=0 ["--target"]=1 )
# TS_DOCKER_builder_build positional args: path
typeset -gA TS_DOCKER_builder_prune_OPT=( ["-a"]=0 ["--all"]=0 ["--filter"]=1 ["-f"]=0 ["--force"]=0 ["--keep-storage"]=1 )
typeset -gA TS_DOCKER_builder_SUB=( ["build"]=1 ["prune"]=1 )
typeset -gA TS_DOCKER_config_create_OPT=( ["-l"]=1 ["--template-driver"]=1 )
# TS_DOCKER_config_create positional args: file
typeset -gA TS_DOCKER_config_inspect_OPT=( ["-f"]=1 ["--pretty"]=0 )
# TS_DOCKER_config_inspect positional args: CONFIG
typeset -gA TS_DOCKER_config_ls_OPT=( ["-f"]=1 ["--format"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_config_SUB=( ["create"]=1 ["inspect"]=1 ["ls"]=1 ["rm"]=0 )
typeset -gA TS_DOCKER_container_attach_OPT=( ["--detach-keys"]=1 ["--no-stdin"]=0 ["--sig-proxy"]=0 )
typeset -gA TS_DOCKER_container_cp_OPT=( ["-a"]=0 ["--archive"]=0 ["-L"]=0 ["--follow-link"]=0 )
# TS_DOCKER_container_cp positional args: CONTAINER_SRC_PATH_DEST_PATH___OR_SRC_PATH___CONTAINER_DEST_PATH
typeset -gA TS_DOCKER_container_create_OPT=( ["--add-host"]=1 ["-a"]=1 ["--attach"]=1 ["--blkio-weight"]=1 ["--blkio-weight-device"]=1 ["--cap-add"]=1 ["--cap-drop"]=1 ["--cgroup-parent"]=1 ["--cgroupns"]=1 ["--cidfile"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-rt-period"]=1 ["--cpu-rt-runtime"]=1 ["-c"]=1 ["--cpu-shares"]=1 ["--cpus"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["--device"]=1 ["--device-cgroup-rule"]=1 ["--device-read-bps"]=1 ["--device-read-iops"]=1 ["--device-write-bps"]=1 ["--device-write-iops"]=1 ["--disable-content-trust"]=0 ["--dns"]=1 ["--dns-option"]=1 ["--dns-search"]=1 ["--domainname"]=1 ["--entrypoint"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["--expose"]=1 ["--gpus"]=1 ["--group-add"]=1 ["--health-cmd"]=1 ["--health-interval"]=1 ["--health-retries"]=1 ["--health-start-period"]=1 ["--health-timeout"]=1 ["--help"]=0 ["-h"]=1 ["--hostname"]=1 ["--init"]=0 ["-i"]=0 ["--interactive"]=0 ["--ip"]=1 ["--ip6"]=1 ["--ipc"]=1 ["--isolation"]=1 ["--kernel-memory"]=1 ["-l"]=1 ["--label"]=1 ["--label-file"]=1 ["--link"]=1 ["--link-local-ip"]=1 ["--log-driver"]=1 ["--log-opt"]=1 ["--mac-address"]=1 ["-m"]=1 ["--memory"]=1 ["--memory-reservation"]=1 ["--memory-swap"]=1 ["--memory-swappiness"]=1 ["--mount"]=1 ["--name"]=1 ["--network"]=1 ["--network-alias"]=1 ["--no-healthcheck"]=0 ["--oom-kill-disable"]=0 ["--oom-score-adj"]=1 ["--pid"]=1 ["--pids-limit"]=1 ["--platform"]=1 ["--privileged"]=0 ["-p"]=1 ["--publish"]=1 ["-P"]=0 ["--publish-all"]=0 ["--pull"]=1 ["--read-only"]=0 ["--restart"]=1 ["--rm"]=0 ["--runtime"]=1 ["--security-opt"]=1 ["--shm-size"]=1 ["--stop-signal"]=1 ["--stop-timeout"]=1 ["--storage-opt"]=1 ["--sysctl"]=1 ["--tmpfs"]=1 ["-t"]=0 ["--tty"]=0 ["--ulimit"]=1 ["-u"]=1 ["--user"]=1 ["--userns"]=1 ["--uts"]=1 ["-v"]=1 ["--volume"]=1 ["--volume-driver"]=1 ["--volumes-from"]=1 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_container_create positional args: container command
typeset -gA TS_DOCKER_container_exec_OPT=( ["-it"]=0 ["-d"]=0 ["--detach"]=0 ["--detach-keys"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["-i"]=0 ["--interactive"]=0 ["--privileged"]=0 ["-t"]=0 ["--tty"]=0 ["-u"]=1 ["--user"]=1 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_container_exec positional args: container command
typeset -gA TS_DOCKER_container_export_OPT=( ["-o"]=1 ["--output"]=1 )
# TS_DOCKER_container_export positional args: container
typeset -gA TS_DOCKER_container_inspect_OPT=( ["-f"]=1 ["--format"]=1 ["-s"]=0 ["--size"]=0 )
# TS_DOCKER_container_inspect positional args: container
typeset -gA TS_DOCKER_container_kill_OPT=( ["-s"]=1 ["--signal"]=1 )
# TS_DOCKER_container_kill positional args: container
typeset -gA TS_DOCKER_container_logs_OPT=( ["--details"]=0 ["-f"]=0 ["--follow"]=0 ["--since"]=1 ["-n"]=1 ["--tail"]=1 ["-t"]=0 ["--timestamps"]=0 ["--until"]=1 )
# TS_DOCKER_container_logs positional args: container
typeset -gA TS_DOCKER_container_ls_OPT=( ["-a"]=0 ["--all"]=0 ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["-n"]=1 ["--last"]=1 ["-l"]=0 ["--latest"]=0 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 ["-s"]=0 ["--size"]=0 )
typeset -gA TS_DOCKER_container_prune_OPT=( ["--filter"]=1 ["-f"]=0 ["--force"]=0 )
typeset -gA TS_DOCKER_container_restart_OPT=( ["-t"]=1 ["--time"]=1 )
# TS_DOCKER_container_restart positional args: container
typeset -gA TS_DOCKER_container_rm_OPT=( ["-f"]=0 ["--force"]=0 ["-l"]=0 ["--link"]=0 ["-v"]=0 ["--volumes"]=0 )
# TS_DOCKER_container_rm positional args: containers
typeset -gA TS_DOCKER_container_run_OPT=( ["-it"]=0 ["--add-host"]=1 ["-a"]=1 ["--attach"]=1 ["--blkio-weight"]=1 ["--blkio-weight-device"]=1 ["--cap-add"]=1 ["--cap-drop"]=1 ["--cgroup-parent"]=1 ["--cgroupns"]=1 ["--cidfile"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-rt-period"]=1 ["--cpu-rt-runtime"]=1 ["-c"]=1 ["--cpu-shares"]=1 ["--cpus"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["-d"]=0 ["--detach"]=0 ["--detach-keys"]=1 ["--device"]=1 ["--device-cgroup-rule"]=1 ["--device-read-bps"]=1 ["--device-read-iops"]=1 ["--device-write-bps"]=1 ["--device-write-iops"]=1 ["--disable-content-trust"]=0 ["--dns"]=1 ["--dns-option"]=1 ["--dns-search"]=1 ["--domainname"]=1 ["--entrypoint"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["--expose"]=1 ["--gpus"]=1 ["--group-add"]=1 ["--health-cmd"]=1 ["--health-interval"]=1 ["--health-retries"]=1 ["--health-start-period"]=1 ["--health-timeout"]=1 ["--help"]=0 ["-h"]=1 ["--hostname"]=1 ["--init"]=0 ["-i"]=0 ["--interactive"]=0 ["--ip"]=1 ["--ip6"]=1 ["--ipc"]=1 ["--isolation"]=1 ["--kernel-memory"]=1 ["-l"]=1 ["--label"]=1 ["--label-file"]=1 ["--link"]=1 ["--link-local-ip"]=1 ["--log-driver"]=1 ["--log-opt"]=1 ["--mac-address"]=1 ["-m"]=1 ["--memory"]=1 ["--memory-reservation"]=1 ["--memory-swap"]=1 ["--memory-swappiness"]=1 ["--mount"]=1 ["--name"]=1 ["--network"]=1 ["--network-alias"]=1 ["--no-healthcheck"]=0 ["--oom-kill-disable"]=0 ["--oom-score-adj"]=1 ["--pid"]=1 ["--pids-limit"]=1 ["--platform"]=1 ["--privileged"]=0 ["-p"]=1 ["--publish"]=1 ["-P"]=0 ["--publish-all"]=0 ["--pull"]=1 ["--read-only"]=0 ["--restart"]=1 ["--rm"]=0 ["--runtime"]=1 ["--security-opt"]=1 ["--shm-size"]=1 ["--sig-proxy"]=0 ["--stop-signal"]=1 ["--stop-timeout"]=1 ["--storage-opt"]=1 ["--sysctl"]=1 ["--tmpfs"]=1 ["-t"]=0 ["--tty"]=0 ["--ulimit"]=1 ["-u"]=1 ["--user"]=1 ["--userns"]=1 ["--uts"]=1 ["-v"]=1 ["--volume"]=1 ["--volume-driver"]=1 ["--volumes-from"]=1 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_container_run positional args: image command
typeset -gA TS_DOCKER_container_start_OPT=( ["-a"]=0 ["--attach"]=0 ["--detach-keys"]=1 ["-i"]=0 ["--interactive"]=0 )
# TS_DOCKER_container_start positional args: container
typeset -gA TS_DOCKER_container_stats_OPT=( ["-a"]=0 ["--all"]=0 ["--format"]=1 ["--no-stream"]=0 ["--no-trunc"]=0 )
# TS_DOCKER_container_stats positional args: container
typeset -gA TS_DOCKER_container_stop_OPT=( ["-t"]=1 ["--t"]=1 )
# TS_DOCKER_container_stop positional args: container
typeset -gA TS_DOCKER_container_update_OPT=( ["--blkio-weight"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-rt-period"]=1 ["--cpu-rt-runtime"]=1 ["-c"]=1 ["--cpu-shares"]=1 ["--cpus"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["--kernel-memory"]=1 ["-m"]=1 ["--memory"]=1 ["--memory-reservation"]=1 ["--memory-swap"]=1 ["--pids-limit"]=1 ["--restart"]=1 )
# TS_DOCKER_container_update positional args: container
typeset -gA TS_DOCKER_container_SUB=( ["attach"]=1 ["cp"]=1 ["create"]=1 ["diff"]=0 ["exec"]=1 ["export"]=1 ["inspect"]=1 ["kill"]=1 ["logs"]=1 ["ls"]=1 ["pause"]=0 ["port"]=0 ["prune"]=1 ["rename"]=0 ["restart"]=1 ["rm"]=1 ["run"]=1 ["start"]=1 ["stats"]=1 ["stop"]=1 ["top"]=0 ["unpause"]=0 ["update"]=1 ["wait"]=0 )
typeset -gA TS_DOCKER_context_create_aci_OPT=( ["--description"]=1 ["-h"]=0 ["--help"]=0 ["--location"]=1 ["--resource-group"]=1 ["--subscription-id"]=1 )
# TS_DOCKER_context_create_aci positional args: CONTEXT
typeset -gA TS_DOCKER_context_create_ecs_OPT=( ["--access-keys"]=1 ["--description"]=1 ["--from-env"]=0 ["-h"]=0 ["--help"]=0 ["--local-simulation"]=0 ["--profile"]=1 )
# TS_DOCKER_context_create_ecs positional args: CONTEXT
typeset -gA TS_DOCKER_context_create_SUB=( ["aci"]=1 ["ecs"]=1 )
typeset -gA TS_DOCKER_context_create_OPT=( ["--default-stack-orchestrator"]=1 ["--description"]=1 ["--docker"]=1 ["--from"]=1 ["-h"]=0 ["--help"]=0 ["--kubernetes"]=1 )
typeset -gA TS_DOCKER_context_export_OPT=( ["-h"]=0 ["--help"]=0 ["--kubeconfig"]=0 )
# TS_DOCKER_context_export positional args: CONTEXT FILE
typeset -gA TS_DOCKER_context_import_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_DOCKER_context_import positional args: CONTEXT FILE
typeset -gA TS_DOCKER_context_inspect_OPT=( ["-f"]=1 ["-h"]=0 ["--help"]=0 )
# TS_DOCKER_context_inspect positional args: CONTEXT
typeset -gA TS_DOCKER_context_list_OPT=( ["--format"]=1 ["-h"]=0 ["--help"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_context_rm_OPT=( ["-f"]=0 ["--force"]=0 ["-h"]=0 ["--help"]=0 )
# TS_DOCKER_context_rm positional args: CONTEXT
typeset -gA TS_DOCKER_context_show_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_DOCKER_context_update_OPT=( ["--default-stack-orchestrator"]=1 ["--description"]=1 ["--docker"]=1 ["-h"]=0 ["--help"]=0 ["--kubernetes"]=1 )
# TS_DOCKER_context_update positional args: CONTEXT
typeset -gA TS_DOCKER_context_use_OPT=( ["-h"]=0 ["--help"]=0 )
# TS_DOCKER_context_use positional args: CONTEXT
typeset -gA TS_DOCKER_context_SUB=( ["create"]=1 ["export"]=1 ["import"]=1 ["inspect"]=1 ["list"]=1 ["rm"]=1 ["show"]=1 ["update"]=1 ["use"]=1 )
typeset -gA TS_DOCKER_context_OPT=( ["-h"]=0 ["--help"]=0 )
typeset -gA TS_DOCKER_image_build_OPT=( ["--add-host"]=1 ["--build-arg"]=1 ["--cache-from"]=1 ["--disable-content-trust"]=0 ["-f"]=1 ["--file"]=1 ["--iidfile"]=1 ["--isolation"]=1 ["--label"]=1 ["--network"]=1 ["--no-cache"]=0 ["-o"]=1 ["--output"]=1 ["--platform"]=1 ["--progress"]=1 ["--pull"]=0 ["-q"]=0 ["--quiet"]=0 ["--secret"]=1 ["--squash"]=0 ["--ssh"]=1 ["-t"]=0 ["--tag"]=0 ["--target"]=1 )
# TS_DOCKER_image_build positional args: path
typeset -gA TS_DOCKER_image_history_OPT=( ["--format"]=1 ["-H"]=0 ["--human"]=0 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_image_history positional args: image
typeset -gA TS_DOCKER_image_import_OPT=( ["-c"]=1 ["--change"]=1 ["-m"]=1 ["--message"]=1 ["--platform"]=1 )
# TS_DOCKER_image_import positional args: file_URL____REPOSITORY__TAG__
typeset -gA TS_DOCKER_image_inspect_OPT=( ["-f"]=1 )
# TS_DOCKER_image_inspect positional args: image
typeset -gA TS_DOCKER_image_load_OPT=( ["-i"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_image_ls_OPT=( ["-a"]=0 ["--all"]=0 ["--digests"]=0 ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_image_ls positional args: _REPOSITORY__TAG__
typeset -gA TS_DOCKER_image_prune_OPT=( ["-a"]=0 ["--all"]=0 ["--filter"]=1 ["-f"]=0 ["--force"]=0 )
typeset -gA TS_DOCKER_image_pull_OPT=( ["-a"]=0 ["--all-tags"]=0 ["--disable-content-trust"]=0 ["--platform"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_image_pull positional args: NAME__TAG__DIGEST_
typeset -gA TS_DOCKER_image_push_OPT=( ["-a"]=0 ["--all-tags"]=0 ["--disable-content-trust"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_image_push positional args: NAME__TAG_
typeset -gA TS_DOCKER_image_rm_OPT=( ["-f"]=0 ["--force"]=0 ["--no-prune"]=0 )
# TS_DOCKER_image_rm positional args: image
typeset -gA TS_DOCKER_image_save_OPT=( ["-o"]=1 ["--output"]=1 )
# TS_DOCKER_image_save positional args: image
typeset -gA TS_DOCKER_image_SUB=( ["build"]=1 ["history"]=1 ["import"]=1 ["inspect"]=1 ["load"]=1 ["ls"]=1 ["prune"]=1 ["pull"]=1 ["push"]=1 ["rm"]=1 ["save"]=1 ["tag"]=0 )
typeset -gA TS_DOCKER_network_connect_OPT=( ["--alias"]=1 ["--driver-opt"]=1 ["--ip"]=1 ["--ip6"]=1 ["--link"]=1 ["--link-local-ip"]=1 )
# TS_DOCKER_network_connect positional args: NETWORK container
typeset -gA TS_DOCKER_network_create_OPT=( ["--attachable"]=0 ["--aux-address"]=1 ["--config-from"]=1 ["--config-only"]=0 ["-d"]=1 ["--driver"]=1 ["--gateway"]=1 ["--ingress"]=0 ["--internal"]=0 ["--ip-range"]=1 ["--ipam-driver"]=1 ["--ipam-opt"]=1 ["--ipv6"]=0 ["--label"]=1 ["-o"]=1 ["--opt"]=1 ["--scope"]=1 ["--subnet"]=1 )
# TS_DOCKER_network_create positional args: NETWORK
typeset -gA TS_DOCKER_network_disconnect_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_DOCKER_network_disconnect positional args: NETWORK container
typeset -gA TS_DOCKER_network_inspect_OPT=( ["-f"]=1 ["--format"]=1 ["-v"]=0 ["--verbose"]=0 )
# TS_DOCKER_network_inspect positional args: NETWORK
typeset -gA TS_DOCKER_network_ls_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_network_prune_OPT=( ["--filter"]=1 ["-f"]=0 ["--force"]=0 )
typeset -gA TS_DOCKER_network_SUB=( ["connect"]=1 ["create"]=1 ["disconnect"]=1 ["inspect"]=1 ["ls"]=1 ["prune"]=1 ["rm"]=0 )
typeset -gA TS_DOCKER_node_inspect_OPT=( ["-f"]=1 ["--format"]=1 ["--pretty"]=0 )
# TS_DOCKER_node_inspect positional args: NODE
typeset -gA TS_DOCKER_node_ls_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_node_ps_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-resolve"]=0 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_node_ps positional args: NODE
typeset -gA TS_DOCKER_node_rm_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_DOCKER_node_rm positional args: NODE
typeset -gA TS_DOCKER_node_update_OPT=( ["--availability"]=1 ["--label-add"]=1 ["--label-rm"]=1 ["--role"]=1 )
# TS_DOCKER_node_update positional args: NODE
typeset -gA TS_DOCKER_node_SUB=( ["demote"]=0 ["inspect"]=1 ["ls"]=1 ["promote"]=0 ["ps"]=1 ["rm"]=1 ["update"]=1 )
typeset -gA TS_DOCKER_buildx_bake_OPT=( ["-f"]=1 ["--file"]=1 ["--load"]=1 ["--metadata-file"]=1 ["--no-cache"]=1 ["--print"]=1 ["--progress"]=1 ["--pull"]=1 ["--push"]=1 ["--set"]=1 )
# TS_DOCKER_buildx_bake positional args: string
typeset -gA TS_DOCKER_buildx_build_OPT=( ["--add-host"]=1 ["--allow"]=1 ["--build-arg"]=1 ["--build-context"]=1 ["--cache-from"]=1 ["--cache-to"]=1 ["--cgroup-parent"]=1 ["--compress"]=1 ["--cpu-period"]=1 ["--cpu-quota"]=1 ["--cpu-shares"]=1 ["-c"]=1 ["--cpuset-cpus"]=1 ["--cpuset-mems"]=1 ["--file"]=1 ["-f"]=1 ["--force-rm"]=1 ["--iidfile"]=1 ["--invoke"]=1 ["--isolation"]=1 ["--label"]=1 ["--load"]=1 ["--memory"]=1 ["-m"]=1 ["--memory-swap"]=1 ["--metadata-file"]=1 ["--network"]=1 ["--no-cache"]=1 ["--no-cache-filter"]=1 ["--output"]=1 ["-o"]=1 ["--platform"]=1 ["--print"]=1 ["--progress"]=1 ["--pull"]=1 ["--push"]=1 ["--quiet"]=1 ["-q"]=1 ["--rm"]=1 ["--secret"]=1 ["--security-opt"]=1 ["--shm-size"]=1 ["--squash"]=1 ["--ssh"]=1 ["--tag"]=1 ["-t"]=1 ["--target"]=1 ["--ulimit"]=1 )
# TS_DOCKER_buildx_build positional args: string
typeset -gA TS_DOCKER_buildx_create_OPT=( ["--append"]=1 ["--bootstrap"]=1 ["--buildkitd-flags"]=1 ["--config"]=1 ["--driver"]=1 ["--driver-opt"]=1 ["--leave"]=1 ["--name"]=1 ["--node"]=1 ["--platform"]=1 ["--use"]=1 )
# TS_DOCKER_buildx_create positional args: string
typeset -gA TS_DOCKER_buildx_du_OPT=( ["--filter"]=0 ["--verbose"]=0 )
# TS_DOCKER_buildx_du positional args: string
typeset -gA TS_DOCKER_buildx_imagetools_create_OPT=( ["--append"]=1 ["--dry-run"]=1 ["--file"]=1 ["-f"]=1 ["--progress"]=1 ["--tag"]=1 ["-t"]=1 )
# TS_DOCKER_buildx_imagetools_create positional args: string
typeset -gA TS_DOCKER_buildx_imagetools_inspect_OPT=( ["--format"]=1 ["--raw"]=0 )
# TS_DOCKER_buildx_imagetools_inspect positional args: string
typeset -gA TS_DOCKER_buildx_imagetools_SUB=( ["create"]=1 ["inspect"]=1 )
# TS_DOCKER_buildx_imagetools positional args: string
typeset -gA TS_DOCKER_buildx_inspect_OPT=( ["--bootstrap"]=1 )
# TS_DOCKER_buildx_inspect positional args: string
typeset -gA TS_DOCKER_buildx_prune_OPT=( ["--all"]=1 ["-a"]=1 ["--filter"]=1 ["--force"]=1 ["-f"]=1 ["--keep-storage"]=1 ["--verbose"]=1 )
# TS_DOCKER_buildx_prune positional args: string
typeset -gA TS_DOCKER_buildx_rm_OPT=( ["--all-inactive"]=1 ["--force"]=1 ["-f"]=1 ["--keep-daemon"]=1 ["--keep-state"]=1 )
# TS_DOCKER_buildx_rm positional args: string
typeset -gA TS_DOCKER_buildx_use_OPT=( ["--default"]=1 ["--global"]=1 )
# TS_DOCKER_buildx_use positional args: string
typeset -gA TS_DOCKER_buildx_SUB=( ["bake"]=1 ["build"]=1 ["create"]=1 ["du"]=1 ["imagetools"]=1 ["inspect"]=1 ["install"]=0 ["ls"]=0 ["prune"]=1 ["rm"]=1 ["stop"]=0 ["uninstall"]=0 ["use"]=1 ["version"]=0 )
typeset -gA TS_DOCKER_buildx_OPT=( ["--builder"]=1 )
typeset -gA TS_DOCKER_plugin_create_OPT=( ["--compress"]=0 )
# TS_DOCKER_plugin_create positional args: PLUGIN PLUGIN_DATA_DIR
typeset -gA TS_DOCKER_plugin_disable_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_DOCKER_plugin_disable positional args: PLUGIN
typeset -gA TS_DOCKER_plugin_enable_OPT=( ["--timeout"]=1 )
# TS_DOCKER_plugin_enable positional args: PLUGIN
typeset -gA TS_DOCKER_plugin_inspect_OPT=( ["-f"]=1 ["--format"]=1 )
# TS_DOCKER_plugin_inspect positional args: PLUGIN
typeset -gA TS_DOCKER_plugin_install_OPT=( ["--alias"]=1 ["--disable"]=0 ["--disable-content-trust"]=0 ["--grant-all-permissions"]=0 )
# TS_DOCKER_plugin_install positional args: PLUGIN KEY_VALUE
typeset -gA TS_DOCKER_plugin_ls_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_plugin_push_OPT=( ["--disable-content-trust"]=0 )
# TS_DOCKER_plugin_push positional args: PLUGIN__TAG_
typeset -gA TS_DOCKER_plugin_rm_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_DOCKER_plugin_rm positional args: PLUGIN
typeset -gA TS_DOCKER_plugin_upgrade_OPT=( ["--disable-content-trust"]=0 ["--grant-all-permissions"]=0 ["--skip-remote-check"]=0 )
# TS_DOCKER_plugin_upgrade positional args: PLUGIN REMOTE
typeset -gA TS_DOCKER_plugin_SUB=( ["create"]=1 ["disable"]=1 ["enable"]=1 ["inspect"]=1 ["install"]=1 ["ls"]=1 ["push"]=1 ["rm"]=1 ["set"]=0 ["upgrade"]=1 )
typeset -gA TS_DOCKER_secret_create_OPT=( ["-d"]=1 ["--driver"]=1 ["-l"]=1 ["--label"]=1 ["--template-driver"]=1 )
# TS_DOCKER_secret_create positional args: SECRET_NAME SECRET
typeset -gA TS_DOCKER_secret_inspect_OPT=( ["-f"]=1 ["--format"]=1 ["--pretty"]=0 )
# TS_DOCKER_secret_inspect positional args: SECRET
typeset -gA TS_DOCKER_secret_ls_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_secret_SUB=( ["create"]=1 ["inspect"]=1 ["ls"]=1 ["rm"]=0 )
typeset -gA TS_DOCKER_service_create_OPT=( ["--cap-add"]=1 ["--cap-drop"]=1 ["--config"]=1 ["--constraint"]=1 ["--container-label"]=1 ["--credential-spec"]=1 ["-d"]=0 ["--detach"]=0 ["--dns"]=1 ["--dns-option"]=1 ["--dns-search"]=1 ["--endpoint-mode"]=1 ["--entrypoint"]=1 ["-e"]=1 ["--env"]=1 ["--env-file"]=1 ["--generic-resource"]=1 ["--group"]=1 ["--health-cmd"]=1 ["--health-interval"]=1 ["--health-retries"]=1 ["--health-start-period"]=1 ["--health-timeout"]=1 ["--host"]=1 ["--hostname"]=1 ["--init"]=0 ["--isolation"]=1 ["-l"]=1 ["--label"]=1 ["--limit-cpu"]=1 ["--limit-memory"]=1 ["--limit-pids"]=1 ["--log-driver"]=1 ["--log-opt"]=1 ["--max-concurrent"]=1 ["--mode"]=1 ["--mount"]=1 ["--name"]=1 ["--network"]=1 ["--no-healthcheck"]=0 ["--no-resolve-image"]=0 ["--placement-pref"]=1 ["-p"]=1 ["--publish"]=1 ["-q"]=0 ["--quiet"]=0 ["--read-only"]=0 ["--replicas"]=1 ["--replicas-max-per-node"]=1 ["--reserve-cpu"]=1 ["--reserve-memory"]=1 ["--restart-condition"]=1 ["--restart-delay"]=1 ["--restart-max-attempts"]=1 ["--restart-window"]=1 ["--rollback-delay"]=1 ["--rollback-failure-action"]=1 ["--rollback-max-failure-ratio"]=1 ["--rollback-monitor"]=1 ["--rollback-order"]=1 ["--rollback-parallelism"]=1 ["--secret"]=1 ["--stop-grace-period"]=1 ["--stop-signal"]=1 ["--sysctl"]=1 ["-t"]=0 ["--tty"]=0 ["--ulimit"]=1 ["--update-delay"]=1 ["--update-failure-action"]=1 ["--update-max-failure-ratio"]=1 ["--update-monitor"]=1 ["--update-order"]=1 ["--update-parallelism"]=1 ["-u"]=1 ["--user"]=1 ["--with-registry-auth"]=0 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_service_create positional args: image COMMAND
typeset -gA TS_DOCKER_service_inspect_OPT=( ["-f"]=1 ["--format"]=1 ["--pretty"]=0 )
# TS_DOCKER_service_inspect positional args: SERVICE
typeset -gA TS_DOCKER_service_logs_OPT=( ["--details"]=0 ["-f"]=0 ["--follow"]=0 ["--no-resolve"]=0 ["--no-task-ids"]=0 ["--no-trunc"]=0 ["--raw"]=0 ["--since"]=1 ["-n"]=1 ["--tail"]=1 ["-t"]=0 ["--timestamps"]=0 )
# TS_DOCKER_service_logs positional args: SERVICE_OR_TASK
typeset -gA TS_DOCKER_service_ls_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_service_ps_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-resolve"]=0 ["--no-trunc"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_service_ps positional args: SERVICE
typeset -gA TS_DOCKER_service_rollback_OPT=( ["-d"]=0 ["--detach"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_service_rollback positional args: SERVICE
typeset -gA TS_DOCKER_service_scale_OPT=( ["-d"]=0 ["--detach"]=0 )
# TS_DOCKER_service_scale positional args: SERVICE_REPLICAS
typeset -gA TS_DOCKER_service_update_OPT=( ["--args"]=1 ["--cap-add"]=1 ["--cap-drop"]=1 ["--config-add"]=1 ["--config-rm"]=1 ["--constraint-add"]=1 ["--constraint-rm"]=1 ["--container-label-add"]=1 ["--container-label-rm"]=1 ["--credential-spec"]=1 ["-d"]=0 ["--detach"]=0 ["--dns-add"]=1 ["--dns-option-add"]=1 ["--dns-option-rm"]=1 ["--dns-rm"]=1 ["--dns-search-add"]=1 ["--dns-search-rm"]=1 ["--endpoint-mode"]=1 ["--entrypoint"]=1 ["--env-add"]=1 ["--env-rm"]=1 ["--force"]=0 ["--generic-resource-add"]=1 ["--generic-resource-rm"]=1 ["--group-add"]=1 ["--group-rm"]=1 ["--health-cmd"]=1 ["--health-interval"]=1 ["--health-retries"]=1 ["--health-start-period"]=1 ["--health-timeout"]=1 ["--host-add"]=1 ["--host-rm"]=1 ["--hostname"]=1 ["--image"]=1 ["--init"]=0 ["--isolation"]=1 ["--label-add"]=1 ["--label-rm"]=1 ["--limit-cpu"]=1 ["--limit-memory"]=1 ["--limit-pids"]=1 ["--log-driver"]=1 ["--log-opt"]=1 ["--max-concurrent"]=1 ["--mount-add"]=1 ["--mount-rm"]=1 ["--network-add"]=1 ["--network-rm"]=1 ["--no-healthcheck"]=0 ["--no-resolve-image"]=0 ["--placement-pref-add"]=1 ["--placement-pref-rm"]=1 ["--publish-add"]=1 ["--publish-rm"]=1 ["-q"]=0 ["--quiet"]=0 ["--read-only"]=0 ["--replicas"]=1 ["--replicas-max-per-node"]=1 ["--reserve-cpu"]=1 ["--reserve-memory"]=1 ["--restart-condition"]=1 ["--restart-delay"]=1 ["--restart-max-attempts"]=1 ["--restart-window"]=1 ["--rollback"]=0 ["--rollback-delay"]=1 ["--rollback-failure-action"]=1 ["--rollback-max-failure-ratio"]=1 ["--rollback-monitor"]=1 ["--rollback-order"]=1 ["--rollback-parallelism"]=1 ["--secret-add"]=1 ["--secret-rm"]=1 ["--stop-grace-period"]=1 ["--stop-signal"]=1 ["--sysctl-add"]=1 ["--sysctl-rm"]=1 ["-t"]=0 ["--tty"]=0 ["--ulimit-add"]=1 ["--ulimit-rm"]=1 ["--update-delay"]=1 ["--update-failure-action"]=1 ["--update-max-failure-ratio"]=1 ["--update-monitor"]=1 ["--update-order"]=1 ["--update-parallelism"]=1 ["-u"]=1 ["--user"]=1 ["--with-registry-auth"]=0 ["-w"]=1 ["--workdir"]=1 )
# TS_DOCKER_service_update positional args: SERVICE
typeset -gA TS_DOCKER_service_SUB=( ["create"]=1 ["inspect"]=1 ["logs"]=1 ["ls"]=1 ["ps"]=1 ["rm"]=0 ["rollback"]=1 ["scale"]=1 ["update"]=1 )
typeset -gA TS_DOCKER_stack_deploy_OPT=( ["-c"]=1 ["--compose-file"]=1 ["--orchestrator"]=1 ["--prune"]=0 ["--resolve-image"]=1 ["--with-registry-auth"]=0 )
# TS_DOCKER_stack_deploy positional args: STACK
typeset -gA TS_DOCKER_stack_ls_OPT=( ["--format"]=1 ["--orchestrator"]=1 )
typeset -gA TS_DOCKER_stack_ps_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--no-resolve"]=0 ["--no-trunc"]=0 ["--orchestrator"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_stack_ps positional args: STACK
typeset -gA TS_DOCKER_stack_rm_OPT=( ["--orchestrator"]=1 )
# TS_DOCKER_stack_rm positional args: STACK
typeset -gA TS_DOCKER_stack_services_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--orchestrator"]=1 ["-q"]=0 ["--quiet"]=0 )
# TS_DOCKER_stack_services positional args: STACK
typeset -gA TS_DOCKER_stack_SUB=( ["deploy"]=1 ["ls"]=1 ["ps"]=1 ["rm"]=1 ["services"]=1 )
typeset -gA TS_DOCKER_swarm_ca_OPT=( ["--ca-cert"]=1 ["--ca-key"]=1 ["--cert-expiry"]=1 ["-d"]=0 ["--detach"]=0 ["--external-ca"]=1 ["-q"]=0 ["--quiet"]=0 ["--rotate"]=0 )
typeset -gA TS_DOCKER_swarm_init_OPT=( ["--advertise-addr"]=1 ["--autolock"]=0 ["--availability"]=1 ["--cert-expiry"]=1 ["--data-path-addr"]=1 ["--data-path-port"]=1 ["--default-addr-pool"]=1 ["--default-addr-pool-mask-length"]=1 ["--dispatcher-heartbeat"]=1 ["--external-ca"]=1 ["--force-new-cluster"]=0 ["--listen-addr"]=1 ["--max-snapshots"]=1 ["--snapshot-interval"]=1 ["--task-history-limit"]=1 )
typeset -gA TS_DOCKER_swarm_join_OPT=( ["--advertise-addr"]=1 ["--availability"]=1 ["--data-path-addr"]=1 ["--listen-addr"]=1 ["--token"]=1 )
# TS_DOCKER_swarm_join positional args: HOST_PORT
typeset -gA TS_DOCKER_swarm_join_token_OPT=( ["-q"]=0 ["--quiet"]=0 ["--rotate"]=0 )
# TS_DOCKER_swarm_join_token positional args: worker_or_manager
typeset -gA TS_DOCKER_swarm_leave_OPT=( ["-f"]=0 ["--force"]=0 )
typeset -gA TS_DOCKER_swarm_unlock_key_OPT=( ["-q"]=0 ["--quiet"]=0 ["--rotate"]=0 )
typeset -gA TS_DOCKER_swarm_update_OPT=( ["--autolock"]=1 ["--cert-expiry"]=1 ["--dispatcher-heartbeat"]=1 ["--external-ca"]=1 ["--max-snapshots"]=1 ["--snapshot-interval"]=1 ["--task-history-limit"]=1 )
typeset -gA TS_DOCKER_swarm_SUB=( ["ca"]=1 ["init"]=1 ["join"]=1 ["join-token"]=1 ["leave"]=1 ["unlock"]=0 ["unlock-key"]=1 ["update"]=1 )
typeset -gA TS_DOCKER_system_prune_OPT=( ["-a"]=0 ["--all"]=0 ["--filter"]=1 ["-f"]=0 ["--force"]=0 ["--volumes"]=0 )
typeset -gA TS_DOCKER_system_df_OPT=( ["--format"]=1 ["-v"]=0 ["--verbose"]=0 )
typeset -gA TS_DOCKER_system_events_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["--since"]=1 ["--until"]=1 )
typeset -gA TS_DOCKER_system_info_OPT=( ["-f"]=1 ["--format"]=1 )
typeset -gA TS_DOCKER_system_SUB=( ["prune"]=1 ["df"]=1 ["events"]=1 ["info"]=1 )
typeset -gA TS_DOCKER_trust_inspect_OPT=( ["--pretty"]=0 )
# TS_DOCKER_trust_inspect positional args: IMAGE__TAG_
typeset -gA TS_DOCKER_trust_revoke_OPT=( ["-y"]=0 ["--yes"]=0 )
# TS_DOCKER_trust_revoke positional args: image
typeset -gA TS_DOCKER_trust_sign_OPT=( ["--local"]=0 )
# TS_DOCKER_trust_sign positional args: image
typeset -gA TS_DOCKER_trust_SUB=( ["inspect"]=1 ["revoke"]=1 ["sign"]=1 )
typeset -gA TS_DOCKER_volume_create_OPT=( ["-d"]=1 ["--driver"]=1 ["--label"]=1 ["-o"]=1 ["--opt"]=1 )
# TS_DOCKER_volume_create positional args: VOLUME
typeset -gA TS_DOCKER_volume_inspect_OPT=( ["-f"]=1 ["--format"]=1 )
# TS_DOCKER_volume_inspect positional args: VOLUME
typeset -gA TS_DOCKER_volume_ls_OPT=( ["-f"]=1 ["--filter"]=1 ["--format"]=1 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DOCKER_volume_prune_OPT=( ["--filter"]=1 ["-f"]=0 ["--force"]=0 )
typeset -gA TS_DOCKER_volume_rm_OPT=( ["-f"]=0 ["--force"]=0 )
# TS_DOCKER_volume_rm positional args: VOLUME
typeset -gA TS_DOCKER_volume_SUB=( ["create"]=1 ["inspect"]=1 ["ls"]=1 ["prune"]=1 ["rm"]=1 )
typeset -gA TS_DOCKER_SUB=( ["attach"]=1 ["build"]=1 ["commit"]=1 ["cp"]=1 ["create"]=1 ["diff"]=0 ["events"]=1 ["exec"]=1 ["export"]=1 ["history"]=1 ["images"]=1 ["import"]=1 ["info"]=1 ["inspect"]=1 ["kill"]=1 ["load"]=1 ["login"]=1 ["logout"]=0 ["logs"]=1 ["pause"]=0 ["port"]=0 ["ps"]=1 ["pull"]=1 ["push"]=1 ["rename"]=0 ["restart"]=1 ["rm"]=1 ["rmi"]=1 ["run"]=1 ["save"]=1 ["search"]=1 ["sbom"]=1 ["start"]=1 ["stats"]=1 ["stop"]=1 ["tag"]=0 ["top"]=0 ["unpause"]=0 ["update"]=1 ["version"]=1 ["wait"]=0 ["builder"]=1 ["config"]=1 ["container"]=1 ["context"]=1 ["image"]=1 ["network"]=1 ["node"]=1 ["buildx"]=1 ["plugin"]=1 ["secret"]=1 ["service"]=1 ["stack"]=1 ["swarm"]=1 ["system"]=1 ["trust"]=1 ["volume"]=1 ["compose"]=0 )
