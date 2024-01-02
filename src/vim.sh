#!/bin/sh
name_="vim.sh"
if ! [ -n "$_VIM_INIT" ]; then
  export _VIM_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  >&2 echo "        unset _VIM_INIT # Execute if this remains set in error"
  return
fi
>&2 echo "Initialising $name_"
unset name
# VIM SH START

# Check for and install vim extensions
# TODO

# VIM SH END
unset _VIM_INIT
