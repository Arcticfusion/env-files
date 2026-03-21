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
# This assumes that env.tools has updated the environment
test -n "$ENV_TOOLS" || { >&2 echo "env.tools is not initialised" && return false}

# Additional Functions
quiet alias __ls || alias __ls=ls
for f in $(__ls "$ENV_REPO/funcs") ; do
  load_env_file "funcs/$f"
done

# Testing shell functions
tf () {
  if test $@; then
    ercho "\e[32mtrue" || >&2 echo true
    return true
  else
    ercho "\e[31mfalse" || >&2 echo false
    return false
  fi
}
alias testy='tf'
alias true_false='tf'
alias trufal='tf'

# Run multiple test options for single arguments
# No tests for comparisions of multiple arguments

tests () {
  local test_opts=()
  local result=0
  local early_return=0
  local verbose=1
  local quiet_mode=1
  while getopts 'bcdefghknprstuwxzLOGSaqv' opt; do
    case $opt in
      b|c|d|e|f|g|h|k|n|p|r|s|t|u|w|x|z|L|O|G|S) test_opts+=("-$opt");;
      a) early_return=1;; # Do all Tests even if one fails
      q) quiet_mode=0;;   # Quiet mode, no text output
      v) verbose=0;;      # Verbose mode, output test commands
      ?) errcho "Invalid option: -$OPTARG" ; return 2 ;;
    esac
  done
  shift $((OPTIND -1))
  local test_cmd
  if test $verbose -eq 0; then
    test_cmd='run test'
  else
    test_cmd='test'
  fi
  if test ${#test_opts[@]} -eq 0; then
    test $verbose -eq 0 &&
      ercho "$0: No."
    eval "$test_cmd '$*'"
    result=$?
    test $quiet_mode -ne 0 && ercho "$0: Failed 'test $t_opt $arg'"
    return $?
  fi
  while test $# -gt 0; do
    arg="$1"
    shift 1
    for t_opt in "${test_opts[@]}"; do
      eval "$test_cmd $t_opt $arg"
      result=$?
      test $result -ne 0 && {
        test $quiet_mode -ne 0 && ercho "$0: Failed 'test $t_opt $arg'"
        test $early_return -eq 0 && return $result
      }
    done
  done
  return $result

}
result () { test $? -eq 0; }

# Send a file to the 'Downloads' folder of another machine
checkt ssh rsync &&
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

checkt sed realpath &&
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
        quiet echo placeholder
      fi
    # Check if
    elif quiet which "$f"; then
      quiet echo placeholder
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

NOTES_FILE="${HOME}/.notes"
note () {
  if test $# -gt 0; then
    local date_format="${DATE_FORMAT_DASHED}"
    test -n "$date_format" || date_format="${DATE_FORMAT}"
    test -n "$date_format" || date_format='%Y-%m-%d-%H%M'
    echo "$(date +"${date_format}")::$(echo "$*")" >> "${NOTES_FILE}"
  else
    checkt more &&
    more "${NOTES_FILE}" && return $?
    checkt less &&
    less "${NOTES_FILE}" && return $?
    cat "${NOTES_FILE}" || return $?
  fi
}

alias notes='"${EDITOR}" "${NOTES_FILE}"'

# Convert a .mov to a .gif
checkt ffmpeg sed &&
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
# More than just the executable that has priority in the path
# In the future add options to do an exact basename match using -iname
checkt egrep find &&
cfind () {
  local pattern=$1
  shift
  test $# -gt 0 && pattern="($(printf %s "${pattern}" "${@/#/|}"))"
  2>/dev/null find $(echo "$PATH" | tr ':' '\n') | egrep "[^/]*${pattern}[^/]*$"
}

# Show the default python version, or check if a version is installed
checkt python cfind &&
pyv () {
  test $# -eq 0 &&
    echo -n "$(realpath $(which python))" &&
    ercho -n " ${_yellow}($(python --version))" &&
    echo "" &&
    return 0
  # Assumes all python executables end with a digit
  pys=($(cfind python | grep -Ei '(python|\d)$'))
  pythons=($(
    for c in "${pys[@]}"; do
      muted "$c" --version | quiet grep '.' &&
        echo "$("$c" --version | sed 's/^python //i'):$(realpath "$c")"
    done | sort -u -t: -k1,1Vr -k2,2dif | cut -f2 -d':'
  ))
  local pattern=$1
  shift
  test $# -gt 0 && pattern="($(printf %s "${pattern}" "${@/#/|}"))"
  for p in "${pythons[@]}"; do
    py_match=$(echo "$p" | grep -E "${pattern}")
    test -n "$py_match" &&
    echo -n "$p" && 
    ercho -n " ${_yellow}($("$p" --version))" &&
    echo ""
  done
}

# Reveal a file or directory in Finder / your file explorer
checkt dirname open &&
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

# Bookmark a directory
bookmark_directory () {
  # Print bookmarked directories if no arguments provided
  test $# -gt 0 &&
    echo "BOOKMARKED_DIRECTORIES=$BOOKMARKED_DIRECTORIES" &&
    return 0
    # update this to 
  local prefix=":"
  test -z "$BOOKMARKED_DIRECTORIES" && prefix=""
  while test $# -gt 0; do
    test -d "$1" &&
      BOOKMARKED_DIRECTORIES="${BOOKMARKED_DIRECTORIES}${prefix}$(realpath "$1")" ||
      test $# -gt 0 && echo "Implement this to cd to the directory"
    shift
  done
}

remove_directory_bookmark () {
  # given a number, remove the bookmark
  # -A for delete all bookmarks
  # ask for input if no arguments given
  echo -n '' # Placeholder
}

# TOOLS SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\ttools.sh is Initialised"
unset _TOOLS_SH_INIT
