#!/bin/zsh
name_="homebrew.sh"
if ! [ -n "$_HOMEBREW_SH_INIT" ]; then
  export _HOMEBREW_SH_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# HOMEBREW SH START

# This should only be called my macos.sh or linux.sh

# Select Homebrew Executable
unset _HOMEBREW_EXEC
test -x "${_HOMEBREW_EXEC}" && return
possible_brew_paths=(
  "/opt/homebrew/bin/brew"
  "/usr/local/bin/brew"
  "/usr/local/Homebrew/bin/brew"
  "/usr/bin/brew"
  "/bin/brew"
  "/${USER}/.linuxbrew/bin/brew"
  "/${USER}/Appliations/homebrew/bin/brew"
  "/${USER}/Appliations/bin/brew"
  "/${USER}/Appliations/bin/homebrew/bin/brew"
  "/${USER}/Appliations/sbin/brew"
  "/${USER}/Appliations/sbin/homebrew/bin/brew"
  "/sandbox/${USER}/tools/homebrew/bin/brew"
)
# Note: User specific executables do not have sudo privileges
for p in "${possible_brew_paths[@]}"; do
  if [ -s "$p" ] && [ -x "$p" ]; then
    _HOMEBREW_EXEC="$(realpath "$p" 2>/dev/null)" && break
  fi
done

test -x "${_HOMEBREW_EXEC}" &&
  eval "$("$_HOMEBREW_EXEC" shellenv)" ||
  errcho "Unable to find 'homebrew' executable"

brew_py_bin="$("$_HOMEBREW_EXEC" --prefix)/opt/python/libexec/bin"
test -d "${brew_py_bin}" && export PATH="${brew_py_bin}:$PATH"
unset brew_py_bin

# HOMEBREW SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\thomebrew.sh is Initialised"
unset _HOMEBREW_SH_INIT
