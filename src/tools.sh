#!/bin/sh
name_="tools.sh"
if ! [ -n "$_TOOLS_INIT" ]; then
  export _TOOLS_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# GEN TOOLS START

cleanPATH () {
  local _host_device="${HOST}${HOSTNAME}"
  local paths_=( '$PATH' '$INFOPATH' '$MANPATH' )
  local path_=''
  for path_var in "${paths_[@]}"; do
    path_=$(eval echo $path_var | sed -E 's/:+$//' )
    path_name_=$(echo "$path_var" | sed 's/^\$//' )
    case "$_host_device" in
    DESKTOP-*) # Default Windows Machine Name
      # Windows Machine - Prioritise Linux Paths by making them firs
      _linux_path=$( echo $path_ | tr ':' '\n' | egrep -v '^/mnt' | sort | uniq )
      _windows_path=$( echo $path_ | tr ':' '\n' | egrep '^/mnt' | sort | uniq )
      eval "export $path_name_=\"$(echo -n "${_linux_path}${_windows_path}" | tr '\n' ':')\""
    ;;
    *)
      # Default Case - no extra steps needed
    ;;
    esac
    # Remove Repeats
    local _paths=$(echo -n $path_ | tr ':' '\n' )
    local _path_pattern=$(echo -n "$_paths" | sed -E 's#/$##' | sort | uniq | tr '\n' '|' | sed -E 's#^(.*[^|])\|?$#^(\1)$#' )
    local _path=""
    while read p; do
      if $(echo "$p" | egrep "$_path_pattern" &>/dev/null); then
          test -d "$p" &&
          _path="${_path}:$p";
          _path_pattern=$(echo -n "$_path_pattern" | sed -E "s#(\|?${p}|${p}\|)##")
      fi
    done < <(echo "$_paths")
    _path=$(echo -n "$_path" | sed -E 's/^://' | sed -E 's/:+$//' | sed -E 's/:+/:/g')
    eval "export $path_name_='$( echo -n "$_path")'"
  done
}


# Additional Functions
# laa - show only hidden files
# requires different implementations on zsh and bash
check_shell zsh || shopt -s extglob
check_shell zsh ||
laa() {
  if [[ $# -eq 1 ]]; then
    exec 3>&1   # This creates another writing file descriptor that points to STDOUT in this shell
    _items=$(cd ${1}; ls -d .!(|.)?* 1>&3)  # This requires extended glob
                                            # `shopt -s extglob` to enable
    unset _items
    exec 3>&- # Closes the writing file descriptor
  elif [[ $# -gt 1 ]]; then
    exec 3>&1
    for i in $@; do
        _items=$(cd $i; echo "$i:" 1>&3; ls -d .!(|.)* 1>&3)
    done
    unset _items i
    exec 3>&-
  else
    ls -d .!(|.)*
  fi
}
check_shell zsh &&
laa() {
  if [[ $# -eq 1 ]]; then
    exec 3>&1   # This creates another writing file descriptor that points to STDOUT in this shell
    _items=$(cd ${1}; ls -AFd .* 1>&3)   # This requires extended glob
                                        # `shopt -s extglob` to enable
    unset _items
    exec 3>&- # Closes the writing file descriptor
  elif [[ $# -gt 1 ]]; then
    exec 3>&1
    for i in $@; do
        _items=$(cd $i; echo "$i:" 1>&3; ls -AFd .* 1>&3)
    done
    unset _items i
    exec 3>&-
  else
    ls -AFd .*

  fi
}

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

# GEN TOOLS END
unset _TOOLS_INIT
