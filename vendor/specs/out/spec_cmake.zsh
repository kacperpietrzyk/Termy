# Termy spec-highlight: zsh assoc arrays for command "cmake"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_CMAKE_SUB / TS_CMAKE_OPT / nested TS_CMAKE_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_CMAKE___build_OPT=( ["--preset"]=1 ["--list-presets"]=0 ["--parallel"]=1 ["-j"]=1 ["--target"]=1 ["-t"]=1 ["--config"]=1 ["--clean-first"]=0 ["--use-stderr"]=0 ["--verbose"]=0 ["-v"]=0 ["--"]=0 )
# TS_CMAKE___build positional args: dir
typeset -gA TS_CMAKE___install_OPT=( ["--config"]=1 ["--component"]=1 ["--default-directory-permissions"]=1 ["--prefix"]=1 ["--strip"]=0 ["--verbose"]=0 ["-v"]=0 )
# TS_CMAKE___install positional args: dir
typeset -gA TS_CMAKE__E_compare_files_OPT=( ["--ignore-eol"]=0 )
# TS_CMAKE__E_compare_files positional args: file1 file2
typeset -gA TS_CMAKE__E_env_OPT=( ["--unset"]=1 )
# TS_CMAKE__E_env positional args: key_value_pair command
typeset -gA TS_CMAKE__E_remove_OPT=( ["-f"]=0 )
# TS_CMAKE__E_remove positional args: file
typeset -gA TS_CMAKE__E_rm_OPT=( ["-r"]=0 ["-R"]=0 ["-f"]=0 )
# TS_CMAKE__E_rm positional args: file dir
typeset -gA TS_CMAKE__E_tar_OPT=( ["c"]=0 ["x"]=0 ["t"]=0 ["v"]=0 ["z"]=0 ["j"]=0 ["J"]=0 ["--zstd"]=0 ["--files-from"]=1 ["--format"]=1 ["--mtime"]=1 ["--"]=0 )
# TS_CMAKE__E_tar positional args: pathname
typeset -gA TS_CMAKE__E_SUB=( ["capabilities"]=0 ["cat"]=0 ["chdir"]=0 ["compare_files"]=1 ["copy"]=0 ["copy_directory"]=0 ["copy_if_different"]=0 ["create_symlink"]=0 ["create_hardlink"]=0 ["echo"]=0 ["echo_append"]=0 ["env"]=1 ["environment"]=0 ["false"]=0 ["make_directory"]=0 ["md5sum"]=0 ["sha1sum"]=0 ["sha224sum"]=0 ["sha226sum"]=0 ["sha384sum"]=0 ["sha512sum"]=0 ["remove"]=1 ["remove_directory"]=0 ["rm"]=1 ["server"]=0 ["sleep"]=0 ["tar"]=1 ["time"]=0 ["touch"]=0 ["touch_nocreate"]=0 ["true"]=0 )
typeset -gA TS_CMAKE_SUB=( ["--build"]=1 ["--install"]=1 ["--open"]=0 ["-P"]=0 ["-E"]=1 )
typeset -gA TS_CMAKE_OPT=( ["-S"]=1 ["--help"]=0 ["-B"]=1 ["-C"]=1 ["-D"]=1 ["-U"]=1 ["-G"]=1 ["-T"]=1 ["-A"]=1 ["toolchain"]=1 ["--install-prefix"]=1 ["-Wno-dev"]=0 ["-Wdev"]=0 ["-Werror"]=1 ["-Wno-error"]=1 ["-Wdeprecated"]=0 ["-Wno-deprecated"]=0 ["-L"]=0 ["-N"]=0 ["--graphviz"]=1 ["--system-information"]=1 ["--log-level"]=1 ["--log-context"]=0 ["--debug-trycompile"]=0 ["--debug-output"]=0 ["--debug-find"]=0 ["--trace"]=0 ["--trace-expand"]=0 ["--trace-format"]=1 ["--trace-source"]=1 ["--trace-redirect"]=1 ["--warn-uninitialized"]=0 ["--warn-unused-vars"]=0 ["--no-warn-unused-cli"]=0 ["--check-system-vars"]=0 ["--preset"]=1 ["--list-presets"]=1 )
# TS_CMAKE positional args: path_to_source___path_to_existing_build
