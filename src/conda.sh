#!/bin/zsh
name_="conda.sh"
if ! [ -n "${_CONDA_SH_INIT}" ]; then
  export _CONDA_SH_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  exit
fi
>&2 echo "Initialising $name_"
unset name_
# CONDA SH START
__conda__locations=( \
  "/Users/${USER}/Applications/miniconda3/base" \
  "/Users/${USER}/Applications/miniconda3" \
  '/opt/homebrew/Caskroom/miniconda/base' \
  '/opt/homebrew/Caskroom/miniconda' \
)

__conda__loc=''
for cloc in ${__conda__locations} ; do 
  quiet test -f "${cloc}/bin/conda" &&
  __conda__loc="${cloc}" &&
  break
done
if test -d "${__conda__loc}"
then
  __conda_setup="$("${__conda__loc}/bin/conda" "shell.${SHELL_NAME}" 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__conda_setup"
  else
      if [ -f "${__conda__loc}/etc/profile.d/conda.sh" ]; then
          . "${__conda__loc}/etc/profile.d/conda.sh"
      else
          export PATH="${__conda__loc}/bin:$PATH"
      fi
  fi
fi
unset __conda_setup __clonda__loc cloc __conda__locations
# old conda
# __conda_setup="$('/Users/'"${USER}"'/Applications/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/Users/${USER}/Applications/miniconda3/etc/profile.d/conda.sh" ]; then
#         . "/Users/${USER}/Applications/miniconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/Users/${USER}/Applications/miniconda3/bin:$PATH"
#     fi
# fi
# end old conda

quiet which conda || return $?

# Conda Aliases 
alias cona='conda activate'
alias cond='conda deactivate'

alias condenvs="conda env list | egrep -v '^#' | grep '.' | cut -f1 -d' '"

# Specific Aliases
test -d "${THESIS_DIR}" &&
  alias thesis='conda activate thesis; cd ${THESIS_DIR}' ||
  alias thesis='conda activate thesis'
condenvs | quiet egrep '^thesis$' ||
  unalias thesis

unset _CONDA_SH_INIT
# CONDA SH END
