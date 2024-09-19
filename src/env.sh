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

# Move initialisation of env files to this file

# ENV SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tenv.sh is Initialised"
unset _ENV_SH_INIT
