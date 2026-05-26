# Termy spec-highlight: zsh assoc arrays for command "uv"
# Auto-generated from Fig spec — do not edit by hand
# Variable naming: TS_UV_SUB / TS_UV_OPT / nested TS_UV_<sub>_SUB etc.
# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag

typeset -gA TS_UV_run_OPT=( ["--extra"]=1 ["--all-extras"]=0 ["--no-extra"]=1 ["--no-dev"]=0 ["--group"]=1 ["--no-group"]=1 ["--only-group"]=1 ["--all-groups"]=0 ["-m"]=0 ["--module"]=0 ["--only-dev"]=0 ["--no-editable"]=0 ["--env-file"]=1 ["--no-env-file"]=0 ["--with"]=1 ["--with-editable"]=1 ["--with-requirements"]=1 ["--isolated"]=0 ["--no-sync"]=0 ["--locked"]=0 ["--frozen"]=0 ["-s"]=0 ["--script"]=0 ["--all-packages"]=0 ["--package"]=1 ["--no-project"]=0 )
# TS_UV_run positional args: command
typeset -gA TS_UV_init_OPT=( ["--name"]=1 ["--package"]=0 ["--no-package"]=0 ["--app"]=0 ["--lib"]=0 ["--script"]=0 ["--vcs"]=1 ["--build-backend"]=1 ["--no-readme"]=0 ["--author-from"]=1 ["--no-pin-python"]=0 ["--no-workspace"]=0 ["-n"]=0 ["--cache-dir"]=1 )
# TS_UV_init positional args: Path
typeset -gA TS_UV_add_OPT=( ["-r"]=1 ["--requirements"]=1 ["--dev"]=0 ["--optional"]=1 ["--group"]=1 ["--editable"]=0 ["--raw-sources"]=0 ["--rev"]=1 ["--tag"]=1 ["--branch"]=1 ["--extra"]=1 ["--no-sync"]=1 ["--locked"]=1 ["--frozen"]=1 ["--package"]=1 ["--script"]=1 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["--reinstall"]=0 ["--reinstall-package"]=1 ["--link-mode"]=1 ["--compile-bytecode"]=0 ["-C"]=1 ["--no-build-isolation"]=1 ["--no-build-isolation-package"]=1 ["--no-build"]=0 ["--no-build-package"]=1 ["--no-binary"]=0 ["--no-binary-package"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--refresh"]=0 ["--refresh-package"]=1 )
# TS_UV_add positional args: packages
typeset -gA TS_UV_remove_OPT=( ["--dev"]=0 ["--optional"]=1 ["--group"]=1 ["--no-sync"]=1 ["--locked"]=1 ["--frozen"]=1 ["--package"]=1 ["--script"]=1 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["--reinstall"]=0 ["--reinstall-package"]=1 ["--link-mode"]=1 ["--compile-bytecode"]=0 ["-C"]=1 ["--no-build-isolation"]=1 ["--no-build-isolation-package"]=1 ["--no-build"]=0 ["--no-build-package"]=1 ["--no-binary"]=0 ["--no-binary-package"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--refresh"]=0 ["--refresh-package"]=1 )
# TS_UV_remove positional args: dependencies
typeset -gA TS_UV_sync_OPT=( ["--extra"]=1 ["--all-extras"]=0 ["--no-extra"]=1 ["--no-dev"]=0 ["--only-dev"]=0 ["--group"]=1 ["--no-group"]=1 ["--only-group"]=1 ["--all-groups"]=0 ["--no-editable"]=0 ["--inexact"]=0 ["--no-install-project"]=0 ["--no-install-workspace"]=0 ["--no-install-package"]=1 ["--locked"]=1 ["--frozen"]=1 ["--all-packages"]=0 ["--package"]=1 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["--reinstall"]=0 ["--reinstall-package"]=1 ["--link-mode"]=1 ["--compile-bytecode"]=0 ["-C"]=1 ["--no-build-isolation"]=1 ["--no-build-isolation-package"]=1 ["--no-build"]=0 ["--no-build-package"]=1 ["--no-binary"]=0 ["--no-binary-package"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--refresh"]=0 ["--refresh-package"]=1 )
typeset -gA TS_UV_lock_OPT=( ["--locked"]=0 ["--frozen"]=0 ["--dry-run"]=0 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["-C"]=1 ["--no-build-isolation"]=1 ["--no-build-isolation-package"]=1 ["--no-build"]=0 ["--no-build-package"]=1 ["--no-binary"]=0 ["--no-binary-package"]=1 ["--link-mode"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--refresh"]=0 ["--refresh-package"]=1 )
typeset -gA TS_UV_export_OPT=( ["--format"]=1 ["--all-packages"]=0 ["--package"]=1 ["--prune"]=1 ["--extra"]=1 ["--all-extras"]=0 ["--no-extra"]=1 ["--no-dev"]=0 ["--only-dev"]=0 ["--group"]=1 ["--no-group"]=1 ["--only-group"]=1 ["--all-groups"]=0 ["--no-header"]=0 ["--no-editable"]=0 ["--no-hashes"]=0 ["-o"]=1 ["--no-emit-project"]=0 ["--no-emit-workspace"]=0 ["--no-emit-package"]=1 ["--locked"]=1 ["--frozen"]=1 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["-C"]=1 ["--no-build-isolation"]=1 ["--no-build-isolation-package"]=1 ["--no-build"]=0 ["--no-build-package"]=1 ["--no-binary"]=0 ["--no-binary-package"]=1 )
typeset -gA TS_UV_tree_OPT=( ["--universal"]=0 ["-d"]=1 ["--prune"]=1 ["--package"]=1 ["--no-dedupe"]=0 ["--invert"]=0 ["--outdated"]=0 ["--only-dev"]=0 ["--no-dev"]=0 ["--group"]=1 ["--no-group"]=1 ["--only-group"]=1 ["--all-groups"]=0 ["--locked"]=1 ["--frozen"]=1 ["--python-version"]=1 ["--python-platform"]=1 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["--link-mode"]=1 ["-p"]=1 ["--python"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 ["--no-cache"]=0 ["--cache-dir"]=1 ["--refresh"]=0 ["--refresh-package"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 )
typeset -gA TS_UV_tool_run_OPT=( ["--from"]=1 ["--with"]=1 ["--with-editable"]=1 ["--with-requirements"]=1 ["--isolated"]=0 )
typeset -gA TS_UV_tool_install_OPT=( ["--editable"]=0 ["--with"]=1 ["--with-editable"]=1 ["--with-requirements"]=1 ["--isolated"]=0 )
typeset -gA TS_UV_tool_upgrade_OPT=( ["--all"]=0 )
typeset -gA TS_UV_tool_list_OPT=( ["--show-paths"]=0 ["--show-version-specifiers"]=0 )
typeset -gA TS_UV_tool_uninstall_OPT=( ["--all"]=0 )
typeset -gA TS_UV_tool_dir_OPT=( ["--bin"]=0 )
typeset -gA TS_UV_tool_SUB=( ["run"]=1 ["install"]=1 ["upgrade"]=1 ["list"]=1 ["uninstall"]=1 ["update-shell"]=0 ["dir"]=1 )
typeset -gA TS_UV_tool_OPT=( ["--python-preference"]=1 ["--no-python-downloads"]=0 ["--no-cache"]=0 ["--cache-dir"]=1 )
typeset -gA TS_UV_python_list_OPT=( ["--all-versions"]=0 ["--all-platforms"]=0 ["--only-installed"]=0 )
typeset -gA TS_UV_python_install_OPT=( ["--mirror"]=1 ["--pypy-mirror"]=1 ["--reinstall"]=0 ["--force"]=0 ["--default"]=0 )
# TS_UV_python_install positional args: VERSION
typeset -gA TS_UV_python_find_OPT=( ["--no-project"]=0 ["--system"]=0 )
# TS_UV_python_find positional args: REQUEST
typeset -gA TS_UV_python_pin_OPT=( ["--resolved"]=0 ["--no-project"]=0 )
# TS_UV_python_pin positional args: REQUEST
typeset -gA TS_UV_python_dir_OPT=( ["--bin"]=0 )
typeset -gA TS_UV_python_uninstall_OPT=( ["--all"]=0 )
# TS_UV_python_uninstall positional args: VERSION
typeset -gA TS_UV_python_SUB=( ["list"]=1 ["install"]=1 ["find"]=1 ["pin"]=1 ["dir"]=1 ["uninstall"]=1 )
typeset -gA TS_UV_python_OPT=( ["--no-cache"]=0 ["--cache-dir"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 )
typeset -gA TS_UV_pip_SUB=( ["compile"]=0 ["sync"]=0 ["install"]=0 ["uninstall"]=0 ["freeze"]=0 ["list"]=0 ["show"]=0 ["tree"]=0 ["check"]=0 )
typeset -gA TS_UV_pip_OPT=( ["--no-cache"]=0 ["--cache-dir"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 )
typeset -gA TS_UV_venv_OPT=( ["-p"]=1 ["--python"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 ["--no-project"]=0 ["--seed"]=0 ["--allow-existing"]=0 ["--prompt"]=1 ["--system-site-packages"]=0 ["--relocatable"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["--exclude-newer"]=1 ["--link-mode"]=1 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--no-cache"]=0 ["--cache-dir"]=1 )
typeset -gA TS_UV_build_OPT=( ["--package"]=1 ["--all-packages"]=0 ["-o"]=1 ["--sdist"]=0 ["--wheel"]=0 ["--no-build-logs"]=0 ["--force-pep517"]=0 ["-b"]=1 ["--require-hashes"]=0 ["--no-verify-hashes"]=0 ["-p"]=1 ["--python"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 ["--index"]=1 ["--default-index"]=1 ["--index-url"]=1 ["--extra-index-url"]=1 ["--find-links"]=1 ["--no-index"]=0 ["--index-strategy"]=1 ["--keyring-provider"]=1 ["-U"]=0 ["--upgrade-package"]=1 ["--resolution"]=1 ["--prerelease"]=1 ["--exclude-newer"]=1 ["--no-sources"]=0 ["-C"]=1 ["--no-build-isolation"]=1 ["--no-build-isolation-package"]=1 ["--no-build"]=0 ["--no-build-package"]=1 ["--no-binary"]=0 ["--no-binary-package"]=1 ["--link-mode"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--refresh"]=0 ["--refresh-package"]=1 )
# TS_UV_build positional args: SOURCE
typeset -gA TS_UV_publish_OPT=( ["--publish-url"]=1 ["-u"]=1 ["-p"]=1 ["-t"]=1 ["--trusted-publishing"]=1 ["--keyring-provider"]=1 ["--check-url"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 )
# TS_UV_publish positional args: FILES
typeset -gA TS_UV_cache_SUB=( ["clean"]=0 ["prune"]=0 ["dir"]=0 )
typeset -gA TS_UV_cache_OPT=( ["--no-cache"]=0 ["--cache-dir"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 )
typeset -gA TS_UV_self_update_OPT=( ["--token"]=0 )
# TS_UV_self_update positional args: TARGET_VERSION
typeset -gA TS_UV_self_SUB=( ["update"]=1 )
typeset -gA TS_UV_self_OPT=( ["--no-cache"]=0 ["--cache-dir"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 )
typeset -gA TS_UV_version_OPT=( ["--output-format"]=1 ["--no-cache"]=0 ["--cache-dir"]=1 ["--python-preference"]=1 ["--no-python-downloads"]=0 )
typeset -gA TS_UV_help_OPT=( ["--no-pager"]=0 )
typeset -gA TS_UV_SUB=( ["run"]=1 ["init"]=1 ["add"]=1 ["remove"]=1 ["sync"]=1 ["lock"]=1 ["export"]=1 ["tree"]=1 ["tool"]=1 ["python"]=1 ["pip"]=1 ["venv"]=1 ["build"]=1 ["publish"]=1 ["cache"]=1 ["self"]=1 ["version"]=1 ["help"]=1 )
typeset -gA TS_UV_OPT=( ["-q"]=0 ["--quiet"]=0 ["-v"]=0 ["--verbose"]=0 ["--color"]=1 ["--native-tls"]=1 ["--offline"]=0 ["--allow-insecure-host"]=1 ["--no-progress"]=0 ["--directory"]=1 ["--project"]=1 ["--config-file"]=1 ["--no-config"]=0 ["-h"]=0 ["--help"]=0 ["-V"]=0 ["--version"]=0 )
