#!/bin/sh
name_="env.sh"
if ! [ -n "$_ENV_SH_INIT" ]; then
  export _ENV_SH_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_

# ENV SH START

# Define the current environment
export SHELL="$(which $(ps $$ | tail -n1 | awk '{print $5}' | sed 's/^-//'))"
export SHELL_NAME="$(echo "$SHELL" | sed -E 's#(.*/)?([^/]*)sh$#\2sh#')"

test -z "${ENV_REPO}" &&
  export ENV_REPO=$(dirname $(readlink -f "$0" 2>/dev/null))
test -z "${ENV_TOOLS}" && source "${ENV_REPO}/env.tools" 
type load_env_file &>/dev/null || source "${ENV_REPO}/env.tools" 

test -e "${ENV_REPO}/iterm2_shell_integration.${SHELL_NAME}" &&
  echo   "Initialising iterm2.${SHELL_NAME}" &&
  source  "${ENV_REPO}/iterm2_shell_integration.${SHELL_NAME}" &&
  export PS1_BASE="${PS1}"

test -z "${KEY}" &&
export KEY="$(date_str)-${SHELL_NAME}-$$" ||
export KEY="${KEY}--${SHELL_NAME}-$$"

export EDITOR='vim'
export VIEWER='vim -R' # other options: more, less
alias edit='"${EDITOR}"'

# Move initialisation of env files to this file
load_env_file env.path
load_env_file env.repos

# ENV SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tenv.sh is Initialised"
unset _ENV_SH_INIT
