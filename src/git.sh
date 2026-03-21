#!/bin/sh
name_="git.sh"
if ! [ -n "$_GIT_SH_INIT" ]; then
  export _GIT_SH_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# GIT SH BEGIN
CURRENT_GIT_COMMAND=""
if [ "${TERM_PROGRAM}" = "vscode" ] && checkt code; then
  export GIT_EDITOR="code --wait"
else
  export GIT_EDITOR=vim
fi

get_repo_directory () { git rev-parse --show-toplevel; }
alias rdir='git rev-parse --show-toplevel'
quiet unalias rname
rname () { basename "$(rdir)"; }
master_branch_name () {
  m_branches=($(git branch --list main master Main Master MAIN MASTER | cut -c3- ))
  test ${#m_branches[@]} -eq 0 &&
    errcho "No master or main branch found in repo $(rname)" &&
    return 10
  test ${#m_branches[@]} -gt 1 &&
    errcho "Multiple master branches found in repo $(rname): (${m_branches[*]})" &&
    return 11
  echo "${m_branches}"
}
branch_name () { git branch --show-current; }

# Using python virtual environments for git repos
{ checkt python3 || checkt python; } &&
venva () {
  local repo_dir=$(get_repo_directory)
  {
    test -d "${repo_dir}/.venv/bin" && source "${repo_dir}/.venv/bin/activate"
  } || {
    test -d "${repo_dir}/.venv/Scripts" && source "${repo_dir}/.venv/Scripts/activate"
  } &&
    ercho "Activated python virtual environment" ||
    errcho "No virtual environment found in repo: ${repo_dir}"
}
{ checkt python3 || checkt python; } &&
gvenv () {
  # Activate virtual environment in the repo directory
  # Generate if it does not exist
  local repo_dir=$(get_repo_directory)
  test -d "${repo_dir}/.venv" || {
    python3 -m venv "${repo_dir}/.venv" && \
    ercho "Created python virtual environment in repo: ${repo_dir}/.venv"
  }
  venva
}

# Get the last tagged version number
pversion () {
  git log "$@" --decorate |
    grep '^commit.*tag:' |
    sed -E 's/.*\((.*)\).*/\1/' |
    sed 's/, /\n/g' |
    grep tag |
    sed 's/tag: //' |
    egrep -m1 '^(v.?)?[0-9]+(\.[0-9]+)+$'
}

# REVIEW: May want to change this to use git config --global user.name,
#         and check if I actually want this to be the default
export GIT_USER_DEFAULT="${USER}"
gu () {
  test $# -eq 0 &&
    echo "GIT_USER_DEFAULT=${GIT_USER_DEFAULT}" ||
    export GIT_USER_DEFAULT="$*"
}

# Pull, Push, & Fetch
gp () {
  git pull &&
    test -n "$(git status | grep 'git push')" &&
    git push "$@"
    ercho "$(rname) Syncing Done"
}
alias gpull='git pull'
alias gpl='git pull'
alias gpush='git push'
alias gph='git push'
alias gip='git pull && git push --'
alias gpuf='git push -f'
alias gfet='git fetch'
alias getch='git fetch'
alias gforce='git push -f'
alias gforced='gforce; gforce upstream --'

# Logs & Status
alias glog='git log HEAD~1..HEAD'
alias glogs='git log'
alias gitl='git log'
alias gits='git status'
alias gs='git status'

# Remotes
alias grems="git remote -v"
alias grem='git remote'
alias gradd="git remote add" #name #url
alias grpush='git push --set-upstream origin' #branch_name

# Differences
alias gdif='git diff'
alias gitd='git diff'
alias gid='git diff'
alias gids='git diff --compact-summary'
alias glod='git diff --compact-summary HEAD~1'
alias glas='git diff --compact-summary HEAD~1'
alias glast='git diff --compact-summary HEAD~1; git diff HEAD~1'

# Branches
alias gib='git branch'
alias gb='git branch'
alias b="git branch"
bhead () {
  local num_commits=1
  test $# -gt 0 && is_pos_int $1 && num_commits=$1
  local cmd="git log HEAD~${num_commits}..HEAD --oneline"
  if test $num_commits -eq 1; then
    >&2 echo "## Last Commit ##"
  elif test $num_commits -gt 1; then
    >&2 echo "## Last $num_commits Commits ##"
  fi
  >&2 eval "$cmd"
  eval "$cmd" | cut -f1 -d' ' | tr '\n' ' ' | sed 's/.$/\n/'
}

# Stashes
alias stash='git stash --keep-index push'
alias gash='git stash push'
alias gpop='git stash pop'

# Staging & Rebasing
alias gadd='git add'
alias gapp='git add -p'
alias gcp='git cherry-pick'
alias grmc='git reset --hard HEAD~1'
alias gfin='git rebase --continue'
alias gskip='git rebase --skip'
alias gmend='git rebase --amend'
quiet unalias gbase
gbase () {
  is_uint "$1" || return $?
  local n_=$1 && shift
  git rebase "HEAD~$n_" --onto "$@"
}
gmodified () {
  git status |
    egrep '\W+modified:' | tr '\t' ' ' |
    sed -E 's# *modified: *(.*) *$#\1#'
}
alias gmod='gmodified'

# Checkout
alias gitch='git checkout'
alias gch='git checkout'
alias gm='git switch $(master_branch_name)'
alias gl='git switch $USER/local'
quiet unalias gt
gt () {
  test $# -gt 0 &&
    ticket="$(getTicket "$1")" && shift 1 ||
    ticket="$(getTicket 1)"
  t_branches=($(git branch --list | grep "${ticket}"))
  test ${#t_branches[@]} -eq 0 && errcho "No branch found for ${ticket}" && return 10
  test ${#t_branches[@]} -gt 1 && {
    test $# -gt 0 && 
    is_uint "$1" && test $1 -lt ${#t_branches[@]} || {
      errcho "Multiple branches found for ${ticket}: (${t_branches[*]})" &&
      return 11
    }
    branch="${t_branches[$1]}"
  } || branch="${t_branches[0]}"
  git switch "${branch}"
}
alias bt="gt"
alias branchName=branch_name
grup () {
  local curr=$(branch_name)
  git push --set-upstream origin "$curr"
}
remaster () {
  local num_commits=1
  if test $# -gt 0; then
    is_uint $1 &&
      num_commits=$1 &&
      shift
  fi
  local current_branch="$(branch_name)"
  local master="$(master_branch_name)"
  local upstream="$(git remote | egrep '^(upstream|origin)$'| head -n1)"
  local edited_files=($(gmodified))
  # Double check how cherry pick works, this may be dropping commits
  local curr_commit=$(git log HEAD~${num_commits}..HEAD --oneline |
                      cut -f1 -d' ' | tr '\n' ' ' | sed 's/.$/\n/')
#   run git whatchanged $curr_commit
#   echo returning early for testing
#   return 0

  git stash push "${edited_files[@]}" &&
    git checkout "${master}" &&
    git pull "${upstream}" "${master}" &&
    git checkout "${current_branch}" &&
    run git reset --hard "${master}" &&
    run git cherry-pick ${curr_commit} &&
    git push -f origin "${current_branch}" &&
    test -n "${edited_files_string}" &&
    git stash pop ||
    echo 'use `git reflog` to find the commit to `git reset --hard "HEAD@{n}"` to if necessary'
  return $?
}
testtag () {
  local val=1
  is_uint "$1" && test $1 -gt 0 && val=$1
  echo "$(pversion)_$(getTicket $val)"
}
btag () {
  git tag $(ttag "$1") HEAD
}
rtag(){
  local remote_=origin tags_=()
  local tagged_=$(git log -n1 --decorate | head -n1 | egrep -o 'tag: [^,) ]+' | head -n2 | sed 's/tag: *//')
  while test $# -gt 0; do
    quiet egrep "^$1$" <(git remote) && remote_="$1" && shift && continue
    is_uint $1 && test $1 -gt 0 && tags_+=("$(ttag $1)") && shift && continue
    >&2 warcho "[$0]\tUnable to proccess argument '$1'" && shift
  done
  test "${tags_[@]}" || tags_+=("$(ttag 1)")
  for t in "${tags_[@]}"; do
    quiet egrep -w "^$t$" <(echo "${tagged_[@]}") ||
      run git tag "$t" HEAD
    run git push "$remote_" "$t"
  done
}
grset() {
  git fetch --quiet origin
  git branch --set-upstream-to="origin/$(branch_name)";} # Change this to ask for the remote name / maybe the url
cammit() {
if [[ $# > 0 ]]; then
    git commit -am "$*"
  else
    git commit -a
  fi
}
commit() {
  if [[ $# > 0 ]]; then
    git commit -m "$*"
  else
    git commit
  fi
}
addmit() {
    git add "$1"
    shift
    if [[ $# > 0 ]]; then
        git commit -m "$*"
    else
        git commit
    fi
}
recommit() {
  local old_message="$(git log -1 | sed '1,4d' | sed 's/^    //')"
  local repo_dir="$(rdir)"
  local files="$(git diff --numstat HEAD~1 HEAD | cut -f3 | sed -E 's#^(.+)$#"'"$repo_dir/"'\1"#' | tr '\n' ' ' )"
  git reset HEAD~1 &&
  eval git add $files &&
  git commit -m "$old_message"
}
branch() {
  local branchName="${USER}/$(echo "$*" | sed -E 's#[^a-zA-Z0-9_/.~\-]+#-#g' | tr ' ' '-' )"
  local repoName=$(git remote -v | grep push | egrep '^origin' | cut -f2 | cut -f1 -d' ' | sed 's#ssh://##')
  test -z "${repoName}" && eercho "No Remote Repo"
  echo -n "Create new branch '${branchName}' on '${repoName}' ([Y]| N ): "
  read answer
  test -z "${answer}" \
    || test "${answer}" == "Y"* \
    || test "${answer}" == "y"*  && \
    git checkout -b  "${branchName}" && \
    git push --set-upstream origin "${branchName}"
  unset answer
}

quiet unalias gload
gload () {
  git stash
  git pull &&
  git stash pop
}
combo () {
  local num_=1 stashed
  test $# -gt 0 &&
    is_uint "$1" &&
    test $1 -ge $num_ &&
    num_=$1
  git stash push | grep -v "No local changes" && stashed=1 || unset stashed
  git rebase -i "HEAD~$num_"
  test $stashed && git stash pop
}
gsquash () {
  local num_=2
  test $# -gt 0 &&
    is_uint "$1" &&
    test $1 -ge $num_ &&
    num_=$1
  git rebase -i "HEAD~$num_"
}
combot () {
  local num_=2
  is_uint "$1" && test $1 -ge $num_ && num_=$1 && shift 1
  commit "Updated $(date +'%d %h %Y' )\n\n$*"
  git rebase -i "HEAD~$num_"
}
cambot () {
  local num_=2
  is_uint "$1" && test $1 -ge $num_ && num_=$1 && shift 1
  cammit "$@"
  git rebase -i "HEAD~$num_"
}

# GIT SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tgit.sh is Initialised"
unset _GIT_SH_INIT
