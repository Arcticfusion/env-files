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
_HOMEBREW_EXEC="$( realpath "/opt/homebrew/bin/brew" 2>/dev/null)"

# User specific executables do not have sudo privileges
test -z "$_HOMEBREW_EXEC" && _HOMEBREW_EXEC="$(realpath /${USER}/Applications/homebrew/bin/brew)"
test -z "$_HOMEBREW_EXEC" && _HOMEBREW_EXEC="$(realpath /${USER}/Applications/bin/brew)"
test -z "$_HOMEBREW_EXEC" && _HOMEBREW_EXEC="$(realpath /${USER}/Applications/bin/homebrew/bin/brew)"
test -z "$_HOMEBREW_EXEC" && _HOMEBREW_EXEC="$(realpath /${USER}/Applications/sbin/brew)"
test -z "$_HOMEBREW_EXEC" && _HOMEBREW_EXEC="$(realpath /${USER}/Applications/sbin/homebrew/bin/brew)"
test -z "$_HOMEBREW_EXEC" && _HOMEBREW_EXEC="/sandbox/${USER}/tools/homebrew/bin/brew"

test -e "${_HOMEBREW_EXEC}" &&
  eval "$("$_HOMEBREW_EXEC" shellenv)" ||
  errcho "Unable to find 'homebrew' executable"

# HOMEBREW SH END
unset _HOMEBREW_SH_INIT
