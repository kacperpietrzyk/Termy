# Termy spec-highlight: zsh assoc arrays for command "go"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_GO_SUB / TS_GO_OPT / nested TS_GO_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_GO_build_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-o"]=1 ["-i"]=0 )
# TS_GO_build positional args: packages
typeset -gA TS_GO_clean_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-i"]=0 ["-r"]=0 ["-cache"]=0 ["-testcache"]=0 ["-modcache"]=0 )
typeset -gA TS_GO_doc_OPT=( ["-all"]=0 ["-c"]=0 ["-cmd"]=0 ["-short"]=0 ["-src"]=0 ["-u"]=0 )
# TS_GO_doc positional args: package
typeset -gA TS_GO_env_OPT=( ["-json"]=0 ["-u"]=1 ["-w"]=1 )
typeset -gA TS_GO_fmt_OPT=( ["-n"]=0 ["-x"]=0 ["-mod"]=1 )
# TS_GO_fmt positional args: packages
typeset -gA TS_GO_generate_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-run"]=0 )
typeset -gA TS_GO_get_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-t"]=0 ["-u"]=1 ["-insecure"]=0 ["-d"]=0 )
# TS_GO_get positional args: url
typeset -gA TS_GO_install_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 )
# TS_GO_install positional args: packages
typeset -gA TS_GO_list_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-compiled"]=0 ["-deps"]=0 ["-f"]=1 ["-e"]=0 ["-export"]=0 ["-find"]=0 ["-test"]=0 ["-m"]=0 ["-u"]=0 ["-versions"]=0 ["-retracted"]=0 )
typeset -gA TS_GO_mod_download_OPT=( ["-json"]=0 ["-x"]=0 )
# TS_GO_mod_download positional args: modules
typeset -gA TS_GO_mod_edit_OPT=( ["-module"]=0 ["-go"]=1 ["-require"]=1 ["-droprequire"]=1 ["-exclude"]=1 ["-dropexclude"]=1 ["-replace"]=1 ["-dropreplace"]=1 ["-retract"]=1 ["-dropretract"]=1 ["-fmt"]=0 ["-print"]=0 ["-json"]=0 )
typeset -gA TS_GO_mod_tidy_OPT=( ["-e"]=0 ["-v"]=0 )
typeset -gA TS_GO_mod_vendor_OPT=( ["-e"]=0 ["-v"]=0 )
typeset -gA TS_GO_mod_why_OPT=( ["-m"]=0 ["-vendor"]=0 )
# TS_GO_mod_why positional args: packages
typeset -gA TS_GO_mod_SUB=( ["download"]=1 ["edit"]=1 ["graph"]=0 ["init"]=0 ["tidy"]=1 ["vendor"]=1 ["verify"]=0 ["why"]=1 )
typeset -gA TS_GO_work_edit_OPT=( ["-fmt"]=0 ["-use"]=1 ["-dropuse"]=1 ["-replace"]=1 ["-dropreplace"]=1 ["-go"]=1 ["-print"]=0 ["-json"]=0 )
typeset -gA TS_GO_work_use_OPT=( ["-r"]=0 )
# TS_GO_work_use positional args: moddirs
typeset -gA TS_GO_work_SUB=( ["edit"]=1 ["init"]=0 ["sync"]=0 ["use"]=1 )
typeset -gA TS_GO_run_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-exec"]=1 )
# TS_GO_run positional args: package
typeset -gA TS_GO_test_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-a"]=0 ["-p"]=1 ["-race"]=0 ["-msan"]=0 ["-work"]=0 ["-asmflags"]=1 ["-buildmode"]=1 ["-compiler"]=1 ["-gccgoflags"]=1 ["-gcflags"]=1 ["-installsuffix"]=1 ["-ldflags"]=1 ["-linkshared"]=0 ["-mod"]=1 ["-modcacherw"]=0 ["-modfile"]=1 ["-overlay"]=1 ["-pkgdir"]=1 ["-trimpath"]=0 ["-args"]=1 ["-c"]=0 ["-exec"]=1 ["-i"]=0 ["-json"]=0 ["-o"]=1 )
typeset -gA TS_GO_tool_OPT=( ["-n"]=0 )
# TS_GO_tool positional args: tool
typeset -gA TS_GO_version_OPT=( ["-m"]=0 ["-v"]=0 )
# TS_GO_version positional args: file
typeset -gA TS_GO_vet_OPT=( ["-n"]=0 ["-v"]=0 ["-x"]=0 ["-tags"]=1 ["-toolexec"]=1 ["-vettool"]=1 )
# TS_GO_vet positional args: package
typeset -gA TS_GO_SUB=( ["bug"]=0 ["build"]=1 ["clean"]=1 ["doc"]=1 ["env"]=1 ["fix"]=0 ["fmt"]=1 ["generate"]=1 ["get"]=1 ["install"]=1 ["list"]=1 ["mod"]=1 ["work"]=1 ["run"]=1 ["test"]=1 ["tool"]=1 ["version"]=1 ["vet"]=1 )
