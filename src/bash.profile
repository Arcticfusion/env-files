if ! [ -n "${_BASH_PROFILE_INIT}" ]; then
  export _BASH_PROFILE_INIT="True"
else
  >&2 echo "Already Initialising ~/.bash_profile"
  return
fi
>&2 echo "Initialising bash_profile"
unset name_
# BASH PROFILE START

export ENV_REPO=$(readlink -f "$HOME/.bash_profile" 2>/dev/null | sed 's#/[^/]*$##')

if [[ -f "${ENV_REPO}/profile" ]]; then
  source "${ENV_REPO}/profile"
fi

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
unset _BASH_PROFILE_INIT
