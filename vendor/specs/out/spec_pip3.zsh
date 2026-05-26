# Termy spec-highlight: zsh assoc arrays for command "pip3"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_PIP3_SUB / TS_PIP3_OPT / nested TS_PIP3_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_PIP3_install_OPT=( ["-r"]=1 ["--requirement"]=1 )
# TS_PIP3_install positional args: package
typeset -gA TS_PIP3_download_OPT=( ["-c"]=0 ["--constraint"]=0 ["-r"]=0 ["--requirement"]=0 ["--no-deps"]=0 ["--global-option"]=0 ["--no-binary"]=0 ["--only-binary"]=1 ["--prefer-binary"]=0 ["--src"]=1 ["--pre"]=0 ["--require-hashes"]=0 ["--progress-bar"]=1 ["--no-build-isolation"]=0 ["--use-pep517"]=0 ["--ignore-requires-python"]=0 ["-d"]=1 ["--dest"]=1 ["--platform"]=1 ["--python-version"]=0 ["--implementation"]=1 ["--abi"]=1 ["--no-clean"]=0 ["-i"]=1 ["--index-url"]=1 ["--no-index"]=0 ["--extra-index-url"]=0 ["-f"]=1 ["--find-links"]=1 )
# TS_PIP3_download positional args: path
typeset -gA TS_PIP3_freeze_OPT=( ["-r"]=0 ["--requirement"]=0 ["-l"]=0 ["--local"]=0 ["--user"]=0 ["--path"]=0 ["--all"]=0 ["--exclude-editable"]=0 ["--exclude"]=1 )
typeset -gA TS_PIP3_list_OPT=( ["-o"]=0 ["--outdated"]=0 ["-u"]=0 ["--uptodate"]=0 ["-e"]=0 ["--editable"]=0 ["-l"]=0 ["--local"]=0 ["--user"]=0 ["--path"]=1 ["--pre"]=0 ["--format"]=0 ["--not-required"]=0 ["--exclude-editable"]=0 ["--include-editable"]=0 ["--exclude"]=1 ["-i"]=1 ["--index-url"]=1 ["--extra-index-url"]=0 ["--no-index"]=0 ["-f"]=1 ["--find-links"]=1 )
typeset -gA TS_PIP3_show_OPT=( ["-f"]=0 ["--files"]=0 )
typeset -gA TS_PIP3_config_OPT=( ["--editor"]=0 ["--global"]=0 ["--user"]=0 ["--site"]=0 )
typeset -gA TS_PIP3_search_OPT=( ["-i"]=0 ["--index"]=0 )
typeset -gA TS_PIP3_hash_OPT=( ["-a"]=1 ["--algorithm"]=1 )
typeset -gA TS_PIP3_debug_OPT=( ["--platform"]=1 ["--python-version"]=1 ["--implementation"]=1 )
typeset -gA TS_PIP3_SUB=( ["install"]=1 ["download"]=1 ["uninstall"]=0 ["freeze"]=1 ["list"]=1 ["show"]=1 ["check"]=0 ["config"]=1 ["search"]=1 ["cache"]=0 ["wheel"]=0 ["hash"]=1 ["completion"]=0 ["debug"]=1 ["help"]=0 )
