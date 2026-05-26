# Termy spec-highlight: zsh assoc arrays for command "deno"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_DENO_SUB / TS_DENO_OPT / nested TS_DENO_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_DENO_bench_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--allow-read"]=1 ["--allow-write"]=1 ["--allow-net"]=1 ["--unsafely-ignore-certificate-errors"]=1 ["--allow-env"]=1 ["--allow-run"]=1 ["--allow-ffi"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["--ignore"]=1 ["--filter"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--allow-hrtime"]=0 ["-A"]=0 ["--allow-all"]=0 ["--prompt"]=0 ["--no-prompt"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["--watch"]=0 ["--no-clear-screen"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_bench positional args: files script_arg
typeset -gA TS_DENO_bundle_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--watch"]=0 ["--no-clear-screen"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_bundle positional args: source_file out_file
typeset -gA TS_DENO_cache_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_cache positional args: file
typeset -gA TS_DENO_check_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--remote"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_check positional args: file
typeset -gA TS_DENO_compile_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--allow-read"]=1 ["--allow-write"]=1 ["--allow-net"]=1 ["--unsafely-ignore-certificate-errors"]=1 ["--allow-env"]=1 ["--allow-run"]=1 ["--allow-ffi"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["-o"]=1 ["--output"]=1 ["--target"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--allow-hrtime"]=0 ["-A"]=0 ["--allow-all"]=0 ["--prompt"]=0 ["--no-prompt"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_compile positional args: script_arg
typeset -gA TS_DENO_completions_OPT=( ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_completions positional args: shell
typeset -gA TS_DENO_coverage_OPT=( ["--ignore"]=1 ["--include"]=1 ["--exclude"]=1 ["--output"]=1 ["-L"]=1 ["--log-level"]=1 ["--lcov"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_coverage positional args: files
typeset -gA TS_DENO_doc_OPT=( ["--import-map"]=1 ["-r"]=1 ["--reload"]=1 ["-L"]=1 ["--log-level"]=1 ["--json"]=0 ["--private"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_doc positional args: source_file filter
typeset -gA TS_DENO_eval_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--inspect"]=1 ["--inspect-brk"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["--ext"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["-T"]=0 ["--ts"]=0 ["-p"]=0 ["--print"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_eval positional args: code_arg
typeset -gA TS_DENO_fmt_OPT=( ["-c"]=1 ["--config"]=1 ["--ext"]=1 ["--ignore"]=1 ["--options-line-width"]=1 ["--options-indent-width"]=1 ["--options-prose-wrap"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-config"]=0 ["--check"]=0 ["--watch"]=0 ["--no-clear-screen"]=0 ["--options-use-tabs"]=0 ["--options-single-quote"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_fmt positional args: files
typeset -gA TS_DENO_init_OPT=( ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_init positional args: dir
typeset -gA TS_DENO_info_OPT=( ["-r"]=1 ["--reload"]=1 ["--cert"]=1 ["--location"]=1 ["--no-check"]=1 ["-c"]=1 ["--config"]=1 ["--import-map"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-config"]=0 ["--json"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_info positional args: file
typeset -gA TS_DENO_install_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--allow-read"]=1 ["--allow-write"]=1 ["--allow-net"]=1 ["--unsafely-ignore-certificate-errors"]=1 ["--allow-env"]=1 ["--allow-run"]=1 ["--allow-ffi"]=1 ["--inspect"]=1 ["--inspect-brk"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["-n"]=1 ["--name"]=1 ["--root"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--allow-hrtime"]=0 ["-A"]=0 ["--allow-all"]=0 ["--prompt"]=0 ["--no-prompt"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["-f"]=0 ["--force"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_install positional args: cmd
typeset -gA TS_DENO_uninstall_OPT=( ["--root"]=1 ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_uninstall positional args: name
typeset -gA TS_DENO_lsp_OPT=( ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DENO_lint_OPT=( ["--rules-tags"]=1 ["--rules-include"]=1 ["--rules-exclude"]=1 ["-c"]=1 ["--config"]=1 ["--ignore"]=1 ["-L"]=1 ["--log-level"]=1 ["--rules"]=0 ["--no-config"]=0 ["--json"]=0 ["--watch"]=0 ["--no-clear-screen"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_lint positional args: files
typeset -gA TS_DENO_repl_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--inspect"]=1 ["--inspect-brk"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["--eval-file"]=1 ["--eval"]=1 ["--unsafely-ignore-certificate-errors"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DENO_run_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--allow-read"]=1 ["--allow-write"]=1 ["--allow-net"]=1 ["--unsafely-ignore-certificate-errors"]=1 ["--allow-env"]=1 ["--allow-run"]=1 ["--allow-ffi"]=1 ["--inspect"]=1 ["--inspect-brk"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["--watch"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--allow-hrtime"]=0 ["-A"]=0 ["--allow-all"]=0 ["--prompt"]=0 ["--no-prompt"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["--no-clear-screen"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_run positional args: script_arg
typeset -gA TS_DENO_task_OPT=( ["-c"]=1 ["--config"]=1 ["--cwd"]=1 ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_task positional args: task_name task_args
typeset -gA TS_DENO_test_OPT=( ["--import-map"]=1 ["-c"]=1 ["--config"]=1 ["--no-check"]=1 ["--check"]=1 ["-r"]=1 ["--reload"]=1 ["--lock"]=1 ["--cert"]=1 ["--allow-read"]=1 ["--allow-write"]=1 ["--allow-net"]=1 ["--unsafely-ignore-certificate-errors"]=1 ["--allow-env"]=1 ["--allow-run"]=1 ["--allow-ffi"]=1 ["--inspect"]=1 ["--inspect-brk"]=1 ["--location"]=1 ["--v8-flags"]=1 ["--seed"]=1 ["--ignore"]=1 ["--fail-fast"]=1 ["--filter"]=1 ["--shuffle"]=1 ["--coverage"]=1 ["-j"]=1 ["--jobs"]=1 ["-L"]=1 ["--log-level"]=1 ["--no-remote"]=0 ["--no-config"]=0 ["--lock-write"]=0 ["--allow-hrtime"]=0 ["-A"]=0 ["--allow-all"]=0 ["--prompt"]=0 ["--no-prompt"]=0 ["--cached-only"]=0 ["--enable-testing-features-do-not-use"]=0 ["--compat"]=0 ["--no-run"]=0 ["--trace-ops"]=0 ["--doc"]=0 ["--allow-none"]=0 ["--parallel"]=0 ["--watch"]=0 ["--no-clear-screen"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_test positional args: files script_arg
typeset -gA TS_DENO_types_OPT=( ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DENO_upgrade_OPT=( ["--version"]=1 ["--output"]=1 ["--cert"]=1 ["-L"]=1 ["--log-level"]=1 ["--dry-run"]=0 ["-f"]=0 ["--force"]=0 ["--canary"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
typeset -gA TS_DENO_vendor_OPT=( ["--output"]=1 ["-c"]=1 ["--config"]=1 ["--import-map"]=1 ["--lock"]=1 ["-r"]=1 ["--reload"]=1 ["--cert"]=1 ["-L"]=1 ["--log-level"]=1 ["-f"]=0 ["--force"]=0 ["--no-config"]=0 ["-h"]=0 ["--help"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_vendor positional args: specifiers
typeset -gA TS_DENO_help_OPT=( ["-L"]=1 ["--log-level"]=1 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
# TS_DENO_help positional args: subcommand
typeset -gA TS_DENO_SUB=( ["bench"]=1 ["bundle"]=1 ["cache"]=1 ["check"]=1 ["compile"]=1 ["completions"]=1 ["coverage"]=1 ["doc"]=1 ["eval"]=1 ["fmt"]=1 ["init"]=1 ["info"]=1 ["install"]=1 ["uninstall"]=1 ["lsp"]=1 ["lint"]=1 ["repl"]=1 ["run"]=1 ["task"]=1 ["test"]=1 ["types"]=1 ["upgrade"]=1 ["vendor"]=1 ["help"]=1 )
typeset -gA TS_DENO_OPT=( ["-L"]=1 ["--log-level"]=1 ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 ["--unstable"]=0 ["-q"]=0 ["--quiet"]=0 )
