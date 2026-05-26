# Termy spec-highlight: zsh assoc arrays for command "bundle"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_BUNDLE_SUB / TS_BUNDLE_OPT / nested TS_BUNDLE_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_BUNDLE_install_OPT=( ["--binstubs"]=1 ["--clean"]=0 ["--deployment"]=0 ["--force"]=0 ["--redownload"]=0 ["--frozen"]=0 ["--full-index"]=0 ["--gemfile"]=1 ["--jobs"]=1 ["--local"]=0 ["--no-cache"]=0 ["--no-prune"]=0 ["--path"]=1 ["--quiet"]=0 ["--retry"]=1 ["--shebang"]=1 ["--standalone"]=1 ["--system"]=0 ["--trust-policy"]=1 ["--with"]=1 ["--without"]=1 )
typeset -gA TS_BUNDLE_update_OPT=( ["--all"]=0 ["--group"]=1 ["-g"]=1 ["--source"]=1 ["--local"]=0 ["--ruby"]=0 ["--bundler"]=0 ["--full-index"]=0 ["--jobs"]=1 ["-j"]=1 ["--retry"]=1 ["--quiet"]=0 ["--force"]=0 ["--redownload"]=0 ["--patch"]=0 ["--minor"]=0 ["--major"]=0 ["--strict"]=0 ["--conservative"]=0 )
# TS_BUNDLE_update positional args: gem
typeset -gA TS_BUNDLE_exec_OPT=( ["--keep-file-descriptors"]=0 )
typeset -gA TS_BUNDLE_add_OPT=( ["--version"]=0 ["-v"]=0 ["--group"]=0 ["-g"]=0 ["--source"]=0 ["-s"]=0 ["--skip-install"]=0 ["--optimistic"]=0 ["--strict"]=0 )
typeset -gA TS_BUNDLE_binstubs_OPT=( ["--force"]=0 ["--path"]=0 ["--standalone"]=0 ["--shebang"]=0 )
typeset -gA TS_BUNDLE_check_OPT=( ["--dry-run"]=0 ["--gemfile"]=0 ["--path"]=0 )
typeset -gA TS_BUNDLE_show_OPT=( ["--paths"]=0 )
# TS_BUNDLE_show positional args: gem
typeset -gA TS_BUNDLE_outdated_OPT=( ["--local"]=0 ["--pre"]=0 ["--source"]=0 ["--strict"]=0 ["--parseable"]=0 ["--porcelain"]=0 ["--group"]=0 ["--groups"]=0 ["--update-strict"]=0 ["--minor"]=0 ["--major"]=0 ["--patch"]=0 ["--filter-major"]=0 ["--filter-minor"]=0 ["--filter-patch"]=0 ["--only-explicit"]=0 )
typeset -gA TS_BUNDLE_lock_OPT=( ["--update"]=1 ["--local"]=0 ["--print"]=0 ["--lockfile"]=1 ["--full-index"]=0 ["--add-platform"]=0 ["--remove-platform"]=0 ["--patch"]=0 ["--minor"]=0 ["--major"]=0 ["--strict"]=0 ["--conservative"]=0 )
typeset -gA TS_BUNDLE_viz_OPT=( ["--file"]=0 ["-f"]=0 ["--format"]=0 ["-F"]=0 ["--requirements"]=0 ["-R"]=0 ["--version"]=0 ["-v"]=0 ["--without"]=0 ["-W"]=0 )
typeset -gA TS_BUNDLE_init_OPT=( ["--gemspec"]=0 )
typeset -gA TS_BUNDLE_gem_OPT=( ["--exe"]=0 ["-b"]=0 ["--bin"]=0 ["--no-exe"]=0 ["--coc"]=0 ["--no-coc"]=0 ["--ext"]=0 ["--no-ext"]=0 ["--mit"]=0 ["--no-mit"]=0 ["-t"]=1 ["--test"]=1 ["-e"]=1 ["--edit"]=1 )
typeset -gA TS_BUNDLE_platform_OPT=( ["--ruby"]=0 )
typeset -gA TS_BUNDLE_clean_OPT=( ["--dry-run"]=0 ["--force"]=0 )
typeset -gA TS_BUNDLE_doctor_OPT=( ["--quiet"]=0 ["--gemfile"]=1 )
typeset -gA TS_BUNDLE_SUB=( ["install"]=1 ["update"]=1 ["package"]=0 ["exec"]=1 ["config"]=0 ["help"]=0 ["add"]=1 ["binstubs"]=1 ["check"]=1 ["show"]=1 ["outdated"]=1 ["console"]=0 ["open"]=0 ["lock"]=1 ["viz"]=1 ["init"]=1 ["gem"]=1 ["platform"]=1 ["clean"]=1 ["doctor"]=1 )
typeset -gA TS_BUNDLE_OPT=( ["--no-color"]=0 ["--retry"]=0 ["-r"]=0 ["--verbose"]=0 ["-V"]=0 )
