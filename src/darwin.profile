#!/bin/zsh
name_="darwin.profile"
if ! [ -n "${_DARWIN_PROFILE_INIT}" ]; then
  export _DARWIN_PROFILE_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# DARWIN PROFILE START

# format this like PATH
export SHARED_DRIVE_PATHS=""

shmount () {
  local sdrives=($(echo "${SHARED_DRIVE_PATHS}" | tr ':' '\n' ))
  echo -n "Confirm mounting of the shared drives ( Y |[N]): "
  read confirm_mount_
  if [[ "$(echo "$confirm_mount_" | upper )" = "Y"* ]]; then
    for d in "${sdrives[@]}"; do
      mountLoc="$HOME/$(echo $d | sed 's#.*/##' )"
  #    driveName="$(echo "${d}_DRIVE" | sed 's#.*/##' | sed -E 's/([^a-z0-9])+/_/gi' | upper )"
      test $( mount |
        grep "$d on " |
        sed -E 's#^.* on /#/#'  |
        sed -E 's/ *\(.*$//' ) ||
        {
          mkdir -p "$mountLoc"
          mount -vt smbfs "smb:$d" "$mountLoc" ||
          continue
        }
    done
  fi
  for d in "${sdrives[@]}"; do
    mountLoc="$HOME/$(echo $d | sed 's#.*/##' )"
    driveName="$(echo "${d}_DRIVE" | sed 's#.*/##' | sed -E 's/([^a-z0-9])+/_/gi' | upper )"
    mount | grep "$d on $mountLoc" &>/dev/null  &&
    export ${driveName}_MOUNTPOINT=${mountLoc}
  done
}

# DARWIN PROFILE END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tdarwin.profile is Initialised"
unset _DARWIN_PROFILE_INIT
