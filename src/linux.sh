#!/bin/sh
name_="linux.sh"
if ! [ -n "$_LINUX_INIT" ]; then
  export _LINUX_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  >&2 echo "        unset _LINUX_INIT # Execute if this remains set in error"
  return
fi
>&2 echo "Initialising $name_"
unset name
# LINUX SH START

# Set SAND location if not set
test -z "$SAND" &&
  SAND="/sandbox/$USER"
test -d "$SAND" &&
  export SAND

# GDB on Linux Machine
gdb_path="/net/binlib/tools/gdb-10.2-u18/bin"
test -d "$gdb_path" &&
export PATH="$gdb_path:$PATH"
unset gdb_path

# Find homebrew location
test -f "${ENV_REPO}/homebrew.sh" && source "${ENV_REPO}/homebrew.sh"
other="/sandbox/${USER}/tools/homebrew/bin"
test -e "$SAND/tools/homebrew/bin/brew" &&
hbrew_exec="$SAND/tools/homebrew/bin/brew"

# Homebrew for linux - update in background
test -n "${hbrew_exec}" &&
eval "$( ${hbrew_exec} shellenv )"
update_brew () { test -n "$( env | grep BREW )" && brew update --force --quiet; }
# update_brew &
unset -f update_brew
# chmod -R go-w "$(brew --prefix)/share/zsh" &

unset hbrew_exec

# LINUX SH END
unset _LINUX_INIT
