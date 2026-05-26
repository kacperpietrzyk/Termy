# Termy spec-highlight: zsh assoc arrays for command "tmux"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_TMUX_SUB / TS_TMUX_OPT / nested TS_TMUX_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_TMUX_a_OPT=( ["-d"]=0 ["-x"]=0 ["-f"]=1 ["-c"]=1 ["-E"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_bind_OPT=( ["-n"]=0 ["-r"]=0 ["-N"]=1 ["-T"]=1 )
# TS_TMUX_bind positional args: key command arguments
typeset -gA TS_TMUX_breakp_OPT=( ["-a"]=0 ["-b"]=0 ["-d"]=0 ["-P"]=0 ["-F"]=1 ["-n"]=1 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_capturep_OPT=( ["-a"]=0 ["-e"]=0 ["-p"]=0 ["-P"]=0 ["-q"]=0 ["-C"]=0 ["-J"]=0 ["-N"]=0 ["-b"]=1 ["-E"]=1 ["-S"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_choose_buffer_OPT=( ["-N"]=0 ["-Z"]=0 ["-r"]=0 ["-F"]=1 ["-f"]=1 ["-O"]=1 ["-t"]=1 )
# TS_TMUX_choose_buffer positional args: template
typeset -gA TS_TMUX_choose_client_OPT=( ["-N"]=0 ["-r"]=0 ["-Z"]=0 ["-F"]=1 ["-f"]=1 ["-O"]=1 ["-t"]=1 )
# TS_TMUX_choose_client positional args: template
typeset -gA TS_TMUX_choose_tree_OPT=( ["-G"]=0 ["-N"]=0 ["-r"]=0 ["-s"]=0 ["-w"]=0 ["-Z"]=0 ["-F"]=1 ["-f"]=1 ["-O"]=1 ["-t"]=1 )
# TS_TMUX_choose_tree positional args: template
typeset -gA TS_TMUX_command_prompt_OPT=( ["-l"]=0 ["-i"]=0 ["-k"]=0 ["-N"]=0 ["-T"]=0 ["-W"]=0 ["-I"]=1 ["-p"]=1 ["-t"]=1 )
# TS_TMUX_command_prompt positional args: template
typeset -gA TS_TMUX_confirm_OPT=( ["-p"]=1 ["-t"]=1 )
# TS_TMUX_confirm positional args: command
typeset -gA TS_TMUX_copy_mode_OPT=( ["-e"]=0 ["-H"]=0 ["-M"]=0 ["-q"]=0 ["-u"]=0 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_deleteb_OPT=( ["-b"]=1 )
typeset -gA TS_TMUX_detach_OPT=( ["-a"]=0 ["-P"]=0 ["-E"]=1 ["-t"]=1 ["-s"]=1 )
typeset -gA TS_TMUX_menu_OPT=( ["-O"]=0 ["-c"]=1 ["-t"]=1 ["-T"]=1 ["-x"]=1 ["-y"]=1 )
# TS_TMUX_menu positional args: name key command
typeset -gA TS_TMUX_display_OPT=( ["-a"]=0 ["-I"]=0 ["-p"]=0 ["-v"]=1 ["-d"]=1 ["-t"]=1 )
# TS_TMUX_display positional args: message
typeset -gA TS_TMUX_displayp_OPT=( ["-b"]=0 ["-N"]=0 ["-d"]=1 ["-t"]=1 )
# TS_TMUX_displayp positional args: template
typeset -gA TS_TMUX_findw_OPT=( ["-i"]=0 ["-C"]=0 ["-N"]=0 ["-r"]=0 ["-T"]=0 ["-Z"]=0 ["-t"]=1 )
# TS_TMUX_findw positional args: match_string
typeset -gA TS_TMUX_has_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_joinp_OPT=( ["-b"]=1 ["-l"]=1 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_killp_OPT=( ["-a"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_kill_ses_OPT=( ["-t"]=1 ["-a"]=0 ["-C"]=0 )
typeset -gA TS_TMUX_killw_OPT=( ["-a"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_lastp_OPT=( ["-d"]=0 ["-e"]=0 ["-Z"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_last_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_linkw_OPT=( ["-a"]=0 ["-b"]=0 ["-d"]=0 ["-k"]=0 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_lsc_OPT=( ["-F"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_lscm_OPT=( ["-F"]=1 )
# TS_TMUX_lscm positional args: command
typeset -gA TS_TMUX_lsp_OPT=( ["-a"]=0 ["-s"]=0 ["-F"]=1 ["-f"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_ls_OPT=( ["-F"]=1 ["-f"]=1 )
typeset -gA TS_TMUX_lsw_OPT=( ["-a"]=0 ["-F"]=1 ["-f"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_loadb_OPT=( ["-w"]=0 ["-b"]=1 ["-t"]=1 )
# TS_TMUX_loadb positional args: path
typeset -gA TS_TMUX_lockc_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_locks_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_movew_OPT=( ["-a"]=0 ["-b"]=0 ["-r"]=0 ["-d"]=0 ["-k"]=0 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_new_OPT=( ["-A"]=0 ["-d"]=0 ["-D"]=0 ["-E"]=0 ["-P"]=0 ["-X"]=0 ["-c"]=1 ["-e"]=1 ["-f"]=1 ["-F"]=1 ["-n"]=1 ["-s"]=1 ["-t"]=1 ["-x"]=1 ["-y"]=1 )
# TS_TMUX_new positional args: shell_command
typeset -gA TS_TMUX_neww_OPT=( ["-a"]=0 ["-b"]=0 ["-d"]=0 ["-k"]=0 ["-P"]=0 ["-S"]=0 ["-c"]=1 ["-e"]=1 ["-F"]=1 ["-n"]=1 ["-t"]=1 )
# TS_TMUX_neww positional args: shell_command
typeset -gA TS_TMUX_nextl_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_next_OPT=( ["-a"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_pipep_OPT=( ["-I"]=0 ["-O"]=0 ["-o"]=0 ["-t"]=1 )
# TS_TMUX_pipep positional args: shell_command
typeset -gA TS_TMUX_prevl_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_prev_OPT=( ["-a"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_refresh_OPT=( ["-c"]=0 ["-D"]=0 ["-l"]=0 ["-L"]=0 ["-R"]=0 ["-S"]=0 ["-U"]=0 ["-A"]=1 ["-B"]=1 ["-C"]=1 ["-f"]=1 ["-t"]=1 )
# TS_TMUX_refresh positional args: adjustment
typeset -gA TS_TMUX_rename_OPT=( ["-t"]=1 )
# TS_TMUX_rename positional args: new_name
typeset -gA TS_TMUX_renamew_OPT=( ["-t"]=1 )
# TS_TMUX_renamew positional args: new_name
typeset -gA TS_TMUX_resizep_OPT=( ["-D"]=0 ["-L"]=0 ["-M"]=0 ["-R"]=0 ["-T"]=0 ["-U"]=0 ["-Z"]=0 ["-t"]=1 ["-x"]=1 ["-y"]=1 )
# TS_TMUX_resizep positional args: adjustment
typeset -gA TS_TMUX_resizew_OPT=( ["-a"]=0 ["-A"]=0 ["-D"]=0 ["-L"]=0 ["-R"]=0 ["-U"]=0 ["-t"]=1 ["-x"]=1 ["-y"]=1 )
# TS_TMUX_resizew positional args: adjustment
typeset -gA TS_TMUX_respawnp_OPT=( ["-k"]=0 ["-c"]=1 ["-e"]=1 ["-t"]=1 )
# TS_TMUX_respawnp positional args: shell_command
typeset -gA TS_TMUX_respawnw_OPT=( ["-k"]=0 ["-c"]=1 ["-e"]=1 ["-t"]=1 )
# TS_TMUX_respawnw positional args: shell_command
typeset -gA TS_TMUX_rotatew_OPT=( ["-D"]=0 ["-U"]=0 ["-Z"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_selectl_OPT=( ["-E"]=0 ["-n"]=0 ["-o"]=0 ["-p"]=0 ["-t"]=1 )
# TS_TMUX_selectl positional args: layout_name
typeset -gA TS_TMUX_selectp_OPT=( ["-D"]=0 ["-d"]=0 ["-e"]=0 ["-L"]=0 ["-l"]=0 ["-M"]=0 ["-m"]=0 ["-R"]=0 ["-U"]=0 ["-Z"]=0 ["-T"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_selectw_OPT=( ["-l"]=0 ["-n"]=0 ["-p"]=0 ["-T"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_setb_OPT=( ["-a"]=0 ["-w"]=0 ["-b"]=1 ["-t"]=1 ["-n"]=1 )
# TS_TMUX_setb positional args: data
typeset -gA TS_TMUX_showenv_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_showmsgs_OPT=( ["-T"]=0 ["-J"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_source_OPT=( ["-F"]=0 ["-n"]=0 ["-q"]=0 ["-v"]=0 )
# TS_TMUX_source positional args: path
typeset -gA TS_TMUX_splitw_OPT=( ["-b"]=0 ["-f"]=0 ["-h"]=0 ["-I"]=0 ["-v"]=0 ["-Z"]=0 ["-c"]=1 ["-e"]=1 ["-l"]=1 ["-t"]=1 ["-F"]=1 )
# TS_TMUX_splitw positional args: shell_command
typeset -gA TS_TMUX_suspendc_OPT=( ["-t"]=1 )
typeset -gA TS_TMUX_swapp_OPT=( ["-d"]=0 ["-D"]=0 ["-U"]=0 ["-Z"]=0 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_swapw_OPT=( ["-d"]=0 ["-s"]=1 ["-t"]=1 )
typeset -gA TS_TMUX_switchc_OPT=( ["-E"]=0 ["-l"]=0 ["-n"]=0 ["-p"]=0 ["-r"]=0 ["-Z"]=0 ["-c"]=1 ["-t"]=1 ["-T"]=1 )
typeset -gA TS_TMUX_unbind_OPT=( ["-a"]=0 ["-n"]=0 ["-q"]=0 ["-T"]=1 )
# TS_TMUX_unbind positional args: key
typeset -gA TS_TMUX_unlinkw_OPT=( ["-k"]=0 ["-t"]=1 )
typeset -gA TS_TMUX_wait_OPT=( ["-L"]=0 ["-U"]=0 )
# TS_TMUX_wait positional args: channel
typeset -gA TS_TMUX_SUB=( ["a"]=1 ["at"]=1 ["attach"]=1 ["attach-session"]=1 ["bind"]=1 ["bind-key"]=1 ["breakp"]=1 ["break-pane"]=1 ["capturep"]=1 ["capture-pane"]=1 ["choose-buffer"]=1 ["choose-client"]=1 ["choose-tree"]=1 ["clearhist"]=0 ["clear-history"]=0 ["clock-mode"]=0 ["command-prompt"]=1 ["confirm"]=1 ["confirm-before"]=1 ["copy-mode"]=1 ["deleteb"]=1 ["delete-buffer"]=1 ["detach"]=1 ["detach-client"]=1 ["menu"]=1 ["display-menu"]=1 ["display"]=1 ["display-message"]=1 ["displayp"]=1 ["display-panes"]=1 ["findw"]=1 ["find-window"]=1 ["has"]=1 ["has-session"]=1 ["if"]=0 ["if-shell"]=0 ["joinp"]=1 ["join-pane"]=1 ["movep"]=1 ["move-pane"]=1 ["killp"]=1 ["kill-pane"]=1 ["kill-server"]=0 ["kill-ses"]=1 ["kill-session"]=1 ["killw"]=1 ["kill-window"]=1 ["lastp"]=1 ["last-pane"]=1 ["last"]=1 ["last-window"]=1 ["linkw"]=1 ["link-window"]=1 ["lsb"]=0 ["list-buffers"]=0 ["lsc"]=1 ["list-clients"]=1 ["lscm"]=1 ["list-commands"]=1 ["lsk"]=0 ["list-keys"]=0 ["lsp"]=1 ["list-panes"]=1 ["ls"]=1 ["list-sessions"]=1 ["lsw"]=1 ["list-windows"]=1 ["loadb"]=1 ["load-buffer"]=1 ["lockc"]=1 ["lock-client"]=1 ["lock"]=0 ["lock-server"]=0 ["locks"]=1 ["lock-session"]=1 ["movew"]=1 ["move-window"]=1 ["new"]=1 ["new-session"]=1 ["neww"]=1 ["new-window"]=1 ["nextl"]=1 ["next-layout"]=1 ["next"]=1 ["next-window"]=1 ["pasteb"]=0 ["paste-buffer"]=0 ["pipep"]=1 ["pipe-pane"]=1 ["prevl"]=1 ["previous-layout"]=1 ["prev"]=1 ["previous-window"]=1 ["refresh"]=1 ["refresh-client"]=1 ["rename"]=1 ["rename-session"]=1 ["renamew"]=1 ["rename-window"]=1 ["resizep"]=1 ["resize-pane"]=1 ["resizew"]=1 ["resize-window"]=1 ["respawnp"]=1 ["respawn-pane"]=1 ["respawnw"]=1 ["respawn-window"]=1 ["rotatew"]=1 ["rotate-window"]=1 ["run"]=0 ["run-shell"]=0 ["saveb"]=0 ["save-buffer"]=0 ["selectl"]=1 ["select-layout"]=1 ["selectp"]=1 ["select-pane"]=1 ["selectw"]=1 ["select-window"]=1 ["send"]=0 ["send-keys"]=0 ["send-prefix"]=0 ["info"]=0 ["server-info"]=0 ["setb"]=1 ["set-buffer"]=1 ["setenv"]=0 ["set-environment"]=0 ["set-hook"]=0 ["set"]=0 ["set-option"]=0 ["setw"]=0 ["set-window-option"]=0 ["showb"]=0 ["show-buffer"]=0 ["showenv"]=1 ["show-environment"]=1 ["show-hooks"]=0 ["showmsgs"]=1 ["show-messages"]=1 ["show"]=0 ["show-options"]=0 ["showw"]=0 ["show-winsow-options"]=0 ["source"]=1 ["source-file"]=1 ["splitw"]=1 ["split-window"]=1 ["start"]=0 ["start-server"]=0 ["suspendc"]=1 ["suspend-client"]=1 ["swapp"]=1 ["swap-pane"]=1 ["swapw"]=1 ["swap-window"]=1 ["switchc"]=1 ["switch-client"]=1 ["unbind"]=1 ["unbind-key"]=1 ["unlinkw"]=1 ["unlink-window"]=1 ["wait"]=1 ["wait-for"]=1 )
