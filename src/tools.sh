#!/bin/sh
name_="tools.sh"
if ! [ -n "$_TOOLS_SH_INIT" ]; then
  export _TOOLS_SH_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# TOOLS SH START

# Additional Functions
load_env_file 'funcs/cleanPATH.func'
load_env_file 'funcs/laa.func'

# Testing shell functions
tf () {
  if test $@; then
    ercho "\e[32mtrue" || echo true
    return true
  else
    ercho "\e[31mfalse" || echo false
    return false
  fi
}
alias testy='tf'

# Send a file to the 'Downloads' folder of another machine
send () {
  test $# -lt 2 && er=$? && ercho "Usage: send <remote> <filename> [filename...]" return 1
  local remote_="$1"
  shift 1
  local remote_paths_=( "$HOME" "/sandbox/$USER" )
  local folder_names_=( "Downloads" "downloads" )
  local dest_path_=""
  for rp in "${remote_paths_[@]}"; do
    for d in "${folder_names_[@]}"; do
      quiet ssh -q "$remote_" "[[ -d '$rp/$d' ]]" && dest_path_="$rp/$d" && break
    done
    test -n "${dest_path_}" && break
  done
  test -z "$dest_path_" && errcho "No destination folder recognised" && return 2
  for f in "$@"; do
    rsync -ravz "$f" "${remote_}:${dest_path_}/"
  done
}

rstripf() {
  sed -Ei '' 's/ +$//' $( realpath "$@" | tr '\n' ' ' )
}

info() {
  while test $# -gt 0;do
    f="$1"
    # If a file exists
    if test -e "$f"; then
      abspath="$(realpath "$(dirname "$f")")"
      test -d "$f" || abspath="${abspath}/$(basename "$f")"
      echo "Absolute Path: ${abspath}"
      # If a Directory
      if test -h "$f"; then
        fr="$(readlink "$f")"
        echo "Symbolic Link: ${f} -> ${fr}"
        f="${fr}"
        fr_path="$(realpath "$f")"
        test "${fr}" != "${fr_path}" &&
          echo "Target Absolute Path: ${fr_path}"
      fi
      if test -d "$f"; then
        echo "Directory: $f"
        ls -ldTe "$f"
      else

      fi
    # Check if
    elif quiet which "$f"; then

    else
      ercho "Unknown input: $f"
    fi

    shift
  done
}

# expands variables
var_eval () {
  result="$1"
  next_result="$(eval "echo -n ${result}" 2>/dev/null || echo "${result}")"
  while [[ "${result}" != "${next_result}" ]]; do
    result="${next_result}"
    next_result="$(eval "echo -n ${result}" 2>/dev/null || echo ${result})"
  done
  echo "${result}"
} 
# Funcions to Modify Shell Prompt
export PS1_LONG='${CONDA_PROMPT_MODIFIER}${PS1_BASE}'
export PS1_SHORT='${CONDA_PROMPT_MODIFIER}${PS1_BASE}'
unset PS1_PREV
prompt () {
  if test -n "${PS1_PREV}"; then
    export PS1="${PS1_PREV}"
    unset PS1_PREV
  else
    export PS1="$(var_eval "${PS1_LONG}")"
  fi
}
lprompt () {
  PS1_PREV="${PS1}"
  export PS1="$(var_eval "${PS1_LONG}")"
}
sprompt () {
  PS1_PREV="${PS1}"
  export PS1="$(var_eval "${PS1_SHORT}")"
}
nprompt (){
  PS1_PREV="${PS1}"
  case "${SHELL_NAME}" in
    bash)
      export PS1='# '
    ;;
    zsh)
      export PS1='%# '
    ;;
    *)
      export PS1='> '
    ;;
esac
}

NOTES_FILE="${HOME}/.notes"
note () {
  if test $# -gt 0; then
    local date_format="${DATE_FORMAT_DASHED}"
    test -n "$date_format" || date_format="${DATE_FORMAT}"
    test -n "$date_format" || date_format='%Y-%m-%d-%H%M'
    echo "$(date +"${date_format}")::$(echo "$*")" >> "${NOTES_FILE}"
  else
    more "${NOTES_FILE}"
  fi
}

alias notes='"${EDITOR}" "${NOTES_FILE}"'

# Convert a .mov to a .gif
quiet which ffmpeg &&
togif () {
  test $# -gt 0 || exit $?
  mov_file="$1"
  shift
  test $# -ge 1 &&
    gif_file="$1"
    shift
  test -z "$gif_file" &&
    gif_file="$(echo "$mov_file" | sed -E 's/\.mov$//').gif"
  test -f "$mov_file" || exit 1
  ffmpeg -i "$mov_file" -pix_fmt rgb8 -r 10 -f gif "$gif_file" "$@"
}

# Find all the executable files with this name in your path
# More than just the one that gets used
# In the future add options to do an exact basename match
cfind () {
  local first=$1
  shift
  local pattern="($(printf %s "$first" "${@/#/|}"))"
  2>/dev/null find $(echo "$PATH" | tr ':' '\n') | egrep "[^/]*${pattern}[^/]*$"
}

# Reveal a file or directory in Finder
reveal() {
  # grab the first arg or default to pwd
  local basedir=${1:-${PWD}}

  if [[ -f "$basedir" ]]; then
    # ..we passed a file, so use its containing directory
    basedir=$(dirname "$basedir")
  fi
  # basedir is a directory in now, so open will activate Finder.
  # The argument is quoted to accommodate spaces in the filename.
  open "$basedir"
}

# TOOLS SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\ttools.sh is Initialised"
unset _TOOLS_SH_INIT
