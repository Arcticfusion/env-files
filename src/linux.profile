#!/bin/sh

name_="linux.profile"
if ! [ -n "$_LINUX_PROFILE_INIT" ]; then
  export _LINUX_PROFILE_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name
# LINUX SH START


# LINUX PROFILE END
unset _LINUX_PROFILE_INIT