#!/bin/bash

# TODO
# Should also be checking if they exist first / if they are files
# Change files to hardlinks and only do soft links for dirs

# ln -s linkname target-dir
DIR=$(readlink -f "$0" | sed -E 's#/[^/]*$##')
# echo located files: $DIR

_check(){
  type "$@" &>/dev/null
}

# Set functions to print debug info
_set_debug() {
  if test $# -eq 0; then
  _ENV_DEBUG="TRUE${_ENV_DEBUG/#/:}"
  fi
  while test $# -gt 0; do
    egrep -w "$1" <<<"${_ENV_DEBUG}" ||
    _ENV_DEBUG="${1}${_ENV_DEBUG/#/:}"
    shift
  done
  export _ENV_DEBUG
}
# Set functions to NOT print debug info
_unset_debug() {
  if test $# -eq 0; then
    test "${_ENV_DEBUG}" &&
    echo "_ENV_DEBUG=${_ENV_DEBUG}" &&
    echo "unset _ENV_DEBUG"
    unset _ENV_DEBUG
  else
    local pattern="$(printf %s "${@/#/|}" | sed -E 's/^.(.*)/(\1)/' )"
    export _ENV_DEBUG="$(
      sed -E -e 's/:'"$pattern"'://g' -e 's/:+/:/g' -e 's/(^:|:$)//g' <<<":$(echo "${_ENV_DEBUG}" | sed 's/:/::/g'):"
    )"
  fi
}
# Check if a function should print debug info
_do_debug() {
  local pattern="$(printf %s "TRUE${@/#/|}" | sed -E 's/^.(.*)/(\1)/' )"
  &>/dev/null egrep -w "$pattern" <<<"$_ENV_DEBUG"
}
_unset_debug
_set_debug ln mv

# when _ENV_DEBUG is has a value, _run prints the command
# also prints the return value if non-zero
_run() {
	local cmd_=("$@")
  local error_code
  if _do_debug _run "${cmd_[0]}"; then
    local env_prompt=$( echo $PS1 | sed -E 's/\$.*//' | sed -E 's#\)[^)]*$#)#' | sed -E 's#[^)]*(\([^)]*\))#\1#g' | grep "(" )
    >&2 printf '\e[35m%s > %s\e[0m\n' "${env_prompt}" "${cmd_[*]}"
  fi
	eval "${cmd_[@]}"
  error_code=$?
  if _do_debug _run "${cmd_[0]}"; then
    test ${error_code} -eq 0 ||
      >&2 printf '\e[31mERROR_CODE %d\e[0m\n' ${error_code}
  fi
  return "${error_code}"
}

_backup_file() {
  local bkup_suffix
  for f in "$@"; do
    bkup_suffix=''
    while { test -e "${f}${bkup_suffix}" || test -h "${f}${bkup_suffix}"; }  do
      bkup_suffix="~$(date +$DATE_FORMAT)-$RANDOM"
    done
    {
      test -e "$f" ||
      test -h "$f"
    } &&
      _run mv "$f" "${f}${bkup_suffix}"
  done
}
_test_same() {
  local file="$(realpath "$1" 2>/dev/null)"
  shift
  for arg in "$@"; do
   [[ "$(realpath "$arg" 2>/dev/null)" = "${file}" ]] || return $?
  done
}

# Install shyaml for parsing yaml
_check shyaml || {
  { _check pip && pip install shyaml; } ||
  { _check brew && brew install shyaml; } ||
  { _check pip3 && pip3 install shyaml; }
}
# file with linked valued
fyaml="$DIR/linked-files.yaml"

# Check that shyaml is intalled
if _check shyaml && test -e "$fyaml"; then
  keys_=$(cat "$fyaml" | shyaml 'keys')
  # loop over keys => shell programs
  while read k; do
    _check "$k" &&
    # loop over sub-keys=> = source filenames
    while read f; do
      dest_="$(eval "echo $(cat "$fyaml" | shyaml get-value "$k.$f.to")")"
      src_="$DIR/$(cat "$fyaml" | shyaml get-value "$k.$f.from")"
      # Backup any existing files if they are different
      _test_same "$src_" "$dest_" ||
        _backup_file "$dest_"
      # Confirm the src exists and the dest file does not exist
      _run test -e "$src_" &&
      ! test -e "$dest_" &&
      _run ln -s "$src_" "$dest_"
    done < <(cat "$fyaml" | shyaml keys "$k")
  done < <(echo "$keys_")
else

  >&2 echo "Unable to read links from '$fyaml'"
  test -d "$HOME/.env-files" ||
    ln -s "$DIR"  "$HOME/.env-files"

  if _check bash ; then
  test -e "$HOME/.bashrc" ||
    ln -s "$DIR/src/bashrc"      "$HOME/.bashrc"
  test -e "$HOME/.bash_profile" ||
    ln -s "$DIR/src/bash.profile"      "$HOME/.bash_profile"
  test -e "$HOME/.profile" ||
    ln -s "$DIR/src/profile"      "$HOME/.profile"
    test -e "$HOME/.iterm2_shell_integration.bash" ||
      ln -s "$DIR/src/iterm2_shell_integration.bash" "$HOME/.iterm2_shell_integration.bash"
  fi
  if _check zsh ; then
  test -e "$HOME/.zshrc" ||
    ln -s "$DIR/src/zshrc"       "$HOME/.zshrc"
    test -e "$HOME/.iterm2_shell_integration.zsh" ||
      ln -s "$DIR/src/iterm2_shell_integration.zsh" "$HOME/.iterm2_shell_integration.zsh"
  fi
  if _check git ; then
  test -e "$HOME/.gitconfig" ||
    ln -s "$DIR/src/git.config"       "$HOME/.gitconfig"
  fi
  if _check sh; then
    test -e "$HOME/.rc" ||
      ln -s "$DIR/src/rc"         "$HOME/.rc"
  fi
fi
unset -f _check
