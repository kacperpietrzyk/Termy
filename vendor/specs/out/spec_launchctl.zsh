# Termy spec-highlight: zsh assoc arrays for command "launchctl"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_LAUNCHCTL_SUB / TS_LAUNCHCTL_OPT / nested TS_LAUNCHCTL_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_LAUNCHCTL_kickstart_OPT=( ["-k"]=0 ["-p"]=0 )
# TS_LAUNCHCTL_kickstart positional args: service
typeset -gA TS_LAUNCHCTL_attach_OPT=( ["-k"]=0 ["-s"]=0 ["-x"]=0 )
# TS_LAUNCHCTL_attach positional args: service
typeset -gA TS_LAUNCHCTL_debug_OPT=( ["--program"]=1 ["--guard-malloc"]=0 ["--malloc-stack-logging"]=0 ["--malloc-nano-allocator"]=0 ["--debug-libraries"]=0 ["--introspection-libraries"]=0 ["--NSZombie"]=0 ["--32"]=0 ["--stdin"]=1 ["--stdout"]=1 ["--stderr"]=1 ["--environment"]=1 )
# TS_LAUNCHCTL_debug positional args: argv
typeset -gA TS_LAUNCHCTL_limit_OPT=( ["cpu"]=1 ["filesize"]=1 ["data"]=1 ["stack"]=1 ["core"]=1 ["rss"]=1 ["memlock"]=1 ["maxproc"]=1 ["maxfiles"]=1 )
typeset -gA TS_LAUNCHCTL_reboot_OPT=( ["system"]=0 ["userspace"]=0 ["halt"]=0 ["logout"]=0 ["apps"]=0 )
typeset -gA TS_LAUNCHCTL_load_OPT=( ["-w"]=0 ["-F"]=0 ["-S"]=1 ["-D"]=1 )
# TS_LAUNCHCTL_load positional args: path
typeset -gA TS_LAUNCHCTL_unload_OPT=( ["-w"]=0 ["-F"]=0 ["-S"]=1 ["-D"]=1 )
# TS_LAUNCHCTL_unload positional args: path
typeset -gA TS_LAUNCHCTL_submit_OPT=( ["-p"]=1 ["-o"]=1 ["-e"]=1 )
# TS_LAUNCHCTL_submit positional args: _l label command arg
typeset -gA TS_LAUNCHCTL_SUB=( ["bootstrap"]=0 ["bootout"]=0 ["enable"]=0 ["disable"]=0 ["kickstart"]=1 ["attach"]=1 ["debug"]=1 ["kill"]=0 ["blame"]=0 ["print"]=0 ["print-cache"]=0 ["print-disabled"]=0 ["plist"]=0 ["procinfo"]=0 ["hostinfo"]=0 ["resolveport"]=0 ["limit"]=1 ["runstats"]=0 ["examine"]=0 ["config"]=0 ["dumpstate"]=0 ["dumpjpcategory"]=0 ["reboot"]=1 ["load"]=1 ["unload"]=1 ["remove"]=0 ["list"]=0 ["start"]=0 ["stop"]=0 ["setenv"]=0 ["unsetenv"]=0 ["getenv"]=0 ["bsexec"]=0 ["asuser"]=0 ["submit"]=1 ["managerpid"]=0 ["manageruid"]=0 ["managername"]=0 ["error"]=0 ["variant"]=0 ["version"]=0 ["help"]=0 )
