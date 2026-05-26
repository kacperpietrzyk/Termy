# Termy spec-highlight: zsh assoc arrays for command "docker-compose"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_DOCKER_COMPOSE_SUB / TS_DOCKER_COMPOSE_OPT / nested TS_DOCKER_COMPOSE_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_DOCKER_COMPOSE_build_OPT=( ["--build-arg"]=1 ["--compress"]=0 ["--force-rm"]=0 ["--memory"]=1 ["-m"]=1 ["--no-cache"]=0 ["--no-rm"]=0 ["--parallel"]=0 ["--progress"]=1 ["--pull"]=0 ["--quiet"]=0 ["-q"]=0 ["--ssh"]=1 )
# TS_DOCKER_COMPOSE_build positional args: services
typeset -gA TS_DOCKER_COMPOSE_config_OPT=( ["--format"]=1 ["--hash"]=1 ["--images"]=0 ["--no-interpolate"]=0 ["--no-normalize"]=0 ["--output"]=1 ["-o"]=1 ["--profiles"]=0 ["--quiet"]=0 ["-q"]=0 ["--resolve-image-digests"]=0 ["--services"]=0 ["--volumes"]=0 )
# TS_DOCKER_COMPOSE_config positional args: services
typeset -gA TS_DOCKER_COMPOSE_cp_OPT=( ["--all"]=0 ["--archive"]=0 ["-a"]=0 ["--follow-link"]=0 ["-L"]=0 ["--index"]=1 )
# TS_DOCKER_COMPOSE_cp positional args: source_path dest_path
typeset -gA TS_DOCKER_COMPOSE_create_OPT=( ["--build"]=0 ["--force-recreate"]=0 ["--no-build"]=0 ["--no-recreate"]=0 )
# TS_DOCKER_COMPOSE_create positional args: service
typeset -gA TS_DOCKER_COMPOSE_down_OPT=( ["--remove-orphans"]=0 ["--rmi"]=1 ["--timeout"]=1 ["-t"]=1 ["--volumes"]=0 ["-v"]=0 )
typeset -gA TS_DOCKER_COMPOSE_events_OPT=( ["--json"]=0 )
# TS_DOCKER_COMPOSE_events positional args: service
typeset -gA TS_DOCKER_COMPOSE_exec_OPT=( ["--detach"]=0 ["-d"]=0 ["--env"]=1 ["-e"]=1 ["--index"]=1 ["--interactive"]=0 ["-i"]=0 ["--no-TTY"]=0 ["-T"]=0 ["--privileged"]=0 ["--tty"]=0 ["-t"]=0 ["--user"]=1 ["-u"]=1 ["--workdir"]=1 ["-w"]=1 )
# TS_DOCKER_COMPOSE_exec positional args: service command
typeset -gA TS_DOCKER_COMPOSE_images_OPT=( ["--quiet"]=0 ["-q"]=0 )
# TS_DOCKER_COMPOSE_images positional args: service
typeset -gA TS_DOCKER_COMPOSE_kill_OPT=( ["--signal"]=1 ["-s"]=1 )
# TS_DOCKER_COMPOSE_kill positional args: service
typeset -gA TS_DOCKER_COMPOSE_logs_OPT=( ["--follow"]=0 ["-f"]=0 ["--no-color"]=0 ["--no-log-prefix"]=0 ["--since"]=1 ["--tail"]=1 ["--timestamps"]=0 ["-t"]=0 ["--until"]=1 )
# TS_DOCKER_COMPOSE_logs positional args: service
typeset -gA TS_DOCKER_COMPOSE_ls_OPT=( ["--all"]=0 ["-a"]=0 ["--filter"]=1 ["--format"]=1 ["--quiet"]=0 ["-q"]=0 )
typeset -gA TS_DOCKER_COMPOSE_port_OPT=( ["--index"]=1 ["--protocol"]=1 )
# TS_DOCKER_COMPOSE_port positional args: service private_port
typeset -gA TS_DOCKER_COMPOSE_ps_OPT=( ["--all"]=0 ["-a"]=0 ["--filter"]=1 ["--format"]=1 ["--quiet"]=0 ["-q"]=0 ["--services"]=0 ["--status"]=1 )
# TS_DOCKER_COMPOSE_ps positional args: service
typeset -gA TS_DOCKER_COMPOSE_pull_OPT=( ["--ignore-pull-failures"]=0 ["--include-deps"]=0 ["--no-parallel"]=0 ["--parallel"]=0 ["--quiet"]=0 ["-q"]=0 )
# TS_DOCKER_COMPOSE_pull positional args: service
typeset -gA TS_DOCKER_COMPOSE_push_OPT=( ["--ignore-push-failures"]=0 )
# TS_DOCKER_COMPOSE_push positional args: service
typeset -gA TS_DOCKER_COMPOSE_restart_OPT=( ["--timeout"]=1 ["-t"]=1 )
# TS_DOCKER_COMPOSE_restart positional args: service
typeset -gA TS_DOCKER_COMPOSE_rm_OPT=( ["--all"]=0 ["-a"]=0 ["--force"]=0 ["-f"]=0 ["--stop"]=0 ["-s"]=0 ["--volumes"]=0 ["-v"]=0 )
# TS_DOCKER_COMPOSE_rm positional args: service
typeset -gA TS_DOCKER_COMPOSE_run_OPT=( ["--detach"]=0 ["-d"]=0 ["--entrypoint"]=1 ["--env"]=1 ["-e"]=1 ["--interactive"]=0 ["-i"]=0 ["--label"]=1 ["-l"]=1 ["--name"]=1 ["--no-TTY"]=0 ["-T"]=0 ["--no-deps"]=0 ["--publish"]=1 ["-p"]=1 ["--quiet-pull"]=0 ["--rm"]=0 ["--service-ports"]=0 ["--tty"]=0 ["-t"]=0 ["--use-aliases"]=0 ["--user"]=1 ["-u"]=1 ["--volume"]=1 ["-v"]=1 ["--workdir"]=1 ["-w"]=1 )
# TS_DOCKER_COMPOSE_run positional args: service command
typeset -gA TS_DOCKER_COMPOSE_stop_OPT=( ["--timeout"]=1 ["-t"]=1 )
# TS_DOCKER_COMPOSE_stop positional args: service
typeset -gA TS_DOCKER_COMPOSE_up_OPT=( ["--abort-on-container-exit"]=0 ["--always-recreate-deps"]=0 ["--attach"]=1 ["--attach-dependencies"]=0 ["--build"]=0 ["--detach"]=0 ["-d"]=0 ["--exit-code-from"]=1 ["--force-recreate"]=0 ["--no-build"]=0 ["--no-color"]=0 ["--no-deps"]=0 ["--no-log-prefix"]=0 ["--no-recreate"]=0 ["--no-start"]=0 ["--quiet-pull"]=0 ["--remove-orphans"]=0 ["--renew-anon-volumes"]=0 ["-V"]=0 ["--scale"]=1 ["--timeout"]=1 ["-t"]=1 ["--wait"]=0 )
# TS_DOCKER_COMPOSE_up positional args: service
typeset -gA TS_DOCKER_COMPOSE_version_OPT=( ["--format"]=1 ["-f"]=1 ["--short"]=0 )
typeset -gA TS_DOCKER_COMPOSE_SUB=( ["build"]=1 ["config"]=1 ["convert"]=1 ["cp"]=1 ["create"]=1 ["down"]=1 ["events"]=1 ["exec"]=1 ["images"]=1 ["kill"]=1 ["logs"]=1 ["ls"]=1 ["pause"]=0 ["port"]=1 ["ps"]=1 ["pull"]=1 ["push"]=1 ["restart"]=1 ["rm"]=1 ["run"]=1 ["start"]=0 ["stop"]=1 ["top"]=0 ["unpause"]=0 ["up"]=1 ["version"]=1 )
typeset -gA TS_DOCKER_COMPOSE_OPT=( ["--ansi"]=1 ["--compatibility"]=0 ["--env-file"]=1 ["--file"]=1 ["-f"]=1 ["--no-ansi"]=0 ["--profile"]=1 ["--project-directory"]=1 ["--project-name"]=1 ["-p"]=1 ["--verbose"]=0 ["--workdir"]=1 )
