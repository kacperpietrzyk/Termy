# Termy spec-highlight: zsh assoc arrays for command "gem"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_GEM_SUB / TS_GEM_OPT / nested TS_GEM_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_GEM_install_OPT=( ["--platform"]=1 )
# TS_GEM_install positional args: GEMNAME
typeset -gA TS_GEM_cert_OPT=( ["-a"]=1 ["--add"]=1 ["-l"]=1 ["--list"]=1 ["-r"]=1 ["--remove"]=1 ["-b"]=1 ["--build"]=1 ["-C"]=1 ["--certificate"]=1 ["-K"]=1 ["--private-key"]=1 ["-A"]=1 ["--key-algorithm"]=1 ["-s"]=1 ["--sign"]=1 ["-d"]=1 ["--days"]=1 ["-R"]=0 ["--re-sign"]=0 )
typeset -gA TS_GEM_check_OPT=( ["-a"]=0 ["--alien"]=0 ["--no-alien"]=0 ["--doctor"]=0 ["--no-doctor"]=0 ["--dry-run"]=0 ["--no-dry-run"]=0 ["--gems"]=0 ["--no-gems"]=0 ["-v"]=1 ["--version"]=1 )
# TS_GEM_check positional args: GEMNAME
typeset -gA TS_GEM_cleanup_OPT=( ["-n"]=0 ["-d"]=0 ["--dry-run"]=0 ["-D"]=0 ["--check-development"]=0 ["--no-check-development"]=0 ["--user-install"]=0 ["--no-user-install"]=0 )
# TS_GEM_cleanup positional args: GEMNAME
typeset -gA TS_GEM_contents_OPT=( ["-v"]=1 ["--version"]=1 ["--all"]=0 ["-s"]=1 ["--spec-dir"]=1 ["-l"]=0 ["--lib-only"]=0 ["--no-lib-only"]=0 ["--prefix"]=0 ["--no-prefix"]=0 ["--show-install-dir"]=0 ["--no-show-install-dir"]=0 )
# TS_GEM_contents positional args: GEMNAME
typeset -gA TS_GEM_dependency_OPT=( ["-v"]=1 ["--version"]=1 ["--platform"]=1 ["--prerelease"]=0 ["--no-prerelease"]=0 ["-R"]=0 ["--reverse-dependencies"]=0 ["--no-reverse-dependencies"]=0 ["--pipe"]=0 ["-l"]=0 ["--local"]=0 ["-r"]=0 ["--remote"]=0 ["-b"]=0 ["--both"]=0 ["-B"]=1 ["--bulk-threshold"]=1 ["--clear-sources"]=0 ["-s"]=1 ["--source"]=1 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
# TS_GEM_dependency positional args: REGEXP
typeset -gA TS_GEM_fetch_OPT=( ["-v"]=1 ["--version"]=1 ["--platform"]=1 ["--prerelease"]=0 ["--no-prerelease"]=0 ["--suggestions"]=0 ["--no-suggestions"]=0 ["-B"]=1 ["--bulk-threshold"]=1 ["-s"]=1 ["--source"]=1 ["--clear-sources"]=0 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
# TS_GEM_fetch positional args: GEMNAME
typeset -gA TS_GEM_generate_index_OPT=( ["-d"]=1 ["--directory"]=1 ["--modern"]=0 ["--no-modern"]=0 ["--update"]=0 )
typeset -gA TS_GEM_info_OPT=( ["-I"]=0 ["-a"]=0 ["--all"]=0 ["-e"]=0 ["--exact"]=0 ["--prerelease"]=0 ["--no-prerelease"]=0 ["-i"]=0 ["--installed"]=0 ["-I"]=0 ["--no-installed"]=0 ["-v"]=1 ["--version"]=1 ["--versions"]=0 ["--no-versions"]=0 )
# TS_GEM_info positional args: GEMNAME
typeset -gA TS_GEM_lock_OPT=( ["-s"]=0 ["--strict"]=0 ["--no-strict"]=0 )
# TS_GEM_lock positional args: GEMNAME_VERSION
typeset -gA TS_GEM_open_OPT=( ["-e"]=1 ["--editor"]=1 ["-v"]=1 ["--version"]=1 )
# TS_GEM_open positional args: GEMNAME
typeset -gA TS_GEM_pristine_OPT=( ["--all"]=0 ["--skip"]=1 ["--extensions"]=0 ["--no-extensions"]=0 ["--only-executables"]=0 ["--only-plugins"]=0 ["-E"]=0 ["--env-shebang"]=0 ["--no-env-shebang"]=0 ["-i"]=1 ["--install-dir"]=1 ["-n"]=1 ["--bindir"]=1 ["-v"]=1 ["--version"]=1 )
# TS_GEM_pristine positional args: GEMNAME
typeset -gA TS_GEM_query_OPT=( ["-n"]=1 ["--name-matches"]=1 ["-I"]=0 ["-d"]=0 ["--details"]=0 ["--no-details"]=0 ["-a"]=0 ["--all"]=0 ["-e"]=0 ["--exact"]=0 ["--prerelease"]=0 ["--no-prerelease"]=0 ["-i"]=0 ["--installed"]=0 ["-I"]=0 ["--no-installed"]=0 ["-v"]=1 ["--version"]=1 ["--versions"]=0 ["--no-versions"]=0 ["-l"]=0 ["--local"]=0 ["-r"]=0 ["--remote"]=0 ["-b"]=0 ["--both"]=0 ["-B"]=1 ["--bulk-threshold"]=1 ["--clear-sources"]=0 ["-s"]=1 ["--source"]=1 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
typeset -gA TS_GEM_rdoc_OPT=( ["--all"]=0 ["--rdoc"]=0 ["--no-rdoc"]=0 ["--ri"]=0 ["--no-ri"]=0 ["--overwrite"]=0 ["--no-overwrite"]=0 ["-v"]=1 ["--version"]=1 )
# TS_GEM_rdoc positional args: GEMNAME
typeset -gA TS_GEM_search_OPT=( ["-I"]=0 ["-d"]=0 ["--details"]=0 ["--no-details"]=0 ["-a"]=0 ["--all"]=0 ["-e"]=0 ["--exact"]=0 ["--prerelease"]=0 ["--no-prerelease"]=0 ["-i"]=0 ["--installed"]=0 ["-I"]=0 ["--no-installed"]=0 ["-v"]=1 ["--version"]=1 ["--versions"]=0 ["--no-versions"]=0 ["-l"]=0 ["--local"]=0 ["-r"]=0 ["--remote"]=0 ["-b"]=0 ["--both"]=0 ["-B"]=1 ["--bulk-threshold"]=1 ["--clear-sources"]=0 ["-s"]=1 ["--source"]=1 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
# TS_GEM_search positional args: REGEXP
typeset -gA TS_GEM_signin_OPT=( ["--host"]=1 ["--otp"]=1 )
typeset -gA TS_GEM_sources_OPT=( ["-a"]=1 ["--add"]=1 ["-l"]=0 ["--list"]=0 ["-r"]=1 ["--remove"]=1 ["-c"]=0 ["--clear-all"]=0 ["-u"]=0 ["--update"]=0 ["-f"]=0 ["--force"]=0 ["--no-force"]=0 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
typeset -gA TS_GEM_specification_OPT=( ["-v"]=1 ["--version"]=1 ["--platform"]=1 ["--prerelease"]=0 ["--no-prerelease"]=0 ["--all"]=0 ["--ruby"]=0 ["--yaml"]=0 ["--marshal"]=0 )
# TS_GEM_specification positional args: GEMFILE FIELD
typeset -gA TS_GEM_unpack_OPT=( ["--target"]=1 ["--spec"]=0 ["-v"]=1 ["--version"]=1 )
# TS_GEM_unpack positional args: GEMNAME
typeset -gA TS_GEM_yank_OPT=( ["-v"]=1 ["--version"]=1 ["--platform"]=1 ["--host"]=1 ["-k"]=1 ["--key"]=1 ["--otp"]=1 )
# TS_GEM_yank positional args: GEM
typeset -gA TS_GEM_uninstall_OPT=( ["-a"]=0 ["--all"]=0 ["-I"]=0 ["--ignore-dependencies"]=0 ["-D"]=0 ["--check-development"]=0 ["-x"]=0 ["--executables"]=0 ["-i"]=1 ["--install-dir"]=1 ["-n"]=1 ["--bindir"]=1 ["--user-install"]=0 ["--format-executable"]=0 ["--force"]=0 ["--abort-on-dependent"]=0 ["-v"]=1 ["--version"]=1 ["--platform"]=1 ["--vendor"]=0 )
# TS_GEM_uninstall positional args: GEMNAME
typeset -gA TS_GEM_list_OPT=( ["-d"]=0 ["--details"]=0 ["--no-details"]=0 ["-u"]=0 ["--update-sources"]=0 ["--no-update-sources"]=0 ["-a"]=0 ["--all"]=0 ["-e"]=0 ["--exact"]=0 ["--prerelease"]=0 ["--no-prerelease"]=0 ["-i"]=0 ["--installed"]=0 ["-I"]=0 ["--no-installed"]=0 ["-v"]=1 ["--version"]=1 ["--versions"]=0 ["--no-versions"]=0 ["-l"]=0 ["--local"]=0 ["-r"]=0 ["--remote"]=0 ["-b"]=0 ["--both"]=0 ["-B"]=1 ["--bulk-threshold"]=1 ["--clear-sources"]=0 ["-s"]=1 ["--source"]=1 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
# TS_GEM_list positional args: REGEXP
typeset -gA TS_GEM_build_OPT=( ["--platform"]=1 ["--force"]=0 ["--strict"]=0 ["-o"]=1 ["--output"]=1 ["-C"]=1 )
# TS_GEM_build positional args: GEMSPEC_FILE
typeset -gA TS_GEM_push_OPT=( ["--host"]=1 ["-k"]=1 ["--key"]=1 ["--otp"]=1 ["-p"]=1 ["--http-proxy"]=1 ["--no-http-proxy"]=0 )
# TS_GEM_push positional args: GEM
typeset -gA TS_GEM_owner_OPT=( ["-a"]=1 ["--add"]=1 ["-r"]=1 ["--remove"]=1 ["--host"]=1 ["-k"]=1 ["--key"]=1 ["--otp"]=1 )
# TS_GEM_owner positional args: GEMNAME
typeset -gA TS_GEM_which_OPT=( ["-a"]=0 ["--all"]=0 ["-g"]=0 ["--gems-first"]=0 )
# TS_GEM_which positional args: FILE
typeset -gA TS_GEM_outdated_OPT=( ["--platform"]=1 )
typeset -gA TS_GEM_update_OPT=( ["--system"]=1 ["--platform"]=1 ["--prerelease"]=0 ["--install-dir"]=1 ["-i"]=1 ["--bindir"]=1 ["-n"]=1 ["--document"]=1 ["--build-root"]=1 ["--vendor"]=0 ["--no-document"]=0 ["-N"]=0 ["--env-shebang"]=0 ["-E"]=0 ["--force"]=0 ["-f"]=0 ["--wrappers"]=0 ["-w"]=0 ["--trust-policy"]=1 ["-P"]=1 ["--ignore-dependencies"]=0 ["--format-executable"]=0 ["--user-install"]=0 ["--development"]=0 ["--development-all"]=0 ["--conservative"]=0 ["--minimal-deps"]=0 ["--post-install-message"]=0 ["--file"]=1 ["-g"]=1 ["--without"]=1 ["--default"]=0 ["--explain"]=0 ["--lock"]=0 ["--suggestions"]=0 )
# TS_GEM_update positional args: GEMNAME
typeset -gA TS_GEM_SUB=( ["help"]=0 ["install"]=1 ["i"]=1 ["cert"]=1 ["check"]=1 ["cleanup"]=1 ["contents"]=1 ["dependency"]=1 ["environment"]=0 ["fetch"]=1 ["generate_index"]=1 ["info"]=1 ["lock"]=1 ["mirror"]=0 ["open"]=1 ["pristine"]=1 ["query"]=1 ["rdoc"]=1 ["search"]=1 ["signin"]=1 ["signout"]=0 ["sources"]=1 ["specification"]=1 ["stale"]=0 ["unpack"]=1 ["yank"]=1 ["uninstall"]=1 ["list"]=1 ["build"]=1 ["push"]=1 ["server"]=0 ["owner"]=1 ["which"]=1 ["outdated"]=1 ["update"]=1 )
typeset -gA TS_GEM_OPT=( ["--help"]=0 ["-h"]=0 ["-V"]=0 ["--verbose"]=0 ["--no-verbose"]=0 ["-q"]=0 ["--quiet"]=0 ["--silent"]=0 ["-config-file"]=1 ["--backtrace"]=0 ["--debug"]=0 ["--norc"]=0 ["-v"]=0 ["--version"]=0 )
