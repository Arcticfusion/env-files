#!/bin/bash
name_='bash.profile'
if ! [ -n "${_BASH_PROFILE_INIT}" ]; then
  export _BASH_PROFILE_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# BASH PROFILE START

export ENV_REPO=$(dirname $(readlink -f "$0" 2>/dev/null))
test -f "${ENV_REPO}/profile" && source "${ENV_REPO}/profile"

if [[ "$-" == *"i"* ]] && [[ -f "${ENV_REPO}/bashrc" ]]; then
  source "${ENV_REPO}/bashrc"
fi

if test -d "/sandbox/${USER}"; then

  if [ "${TMPDIR}" == "" ]; then
  TMPDIR="/sandbox/${USER}/tmp"
  test -d "${TMPDIR}" || mkdir "${TMPDIR}"
  test -n "$KEY" &&
    TMPDIR="${TMPDIR}/${KEY}" ||
    TMPDIR="${TMPDIR}/$$-$(date +'%Y%m%d-%H%m')"
  mkdir "$TMPDIR" && export TMPDIR
  fi

fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash" || true

# BASH PROFILE END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tbash.profile is Initialised"
unset _BASH_PROFILE_INIT
