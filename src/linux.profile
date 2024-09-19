#!/bin/sh

name_="linux.profile"
if ! [ -n "$_LINUX_PROFILE_INIT" ]; then
  export _LINUX_PROFILE_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# LINUX SH START


# LINUX PROFILE END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tlinux.profile is Initialised"
unset _LINUX_PROFILE_INIT
