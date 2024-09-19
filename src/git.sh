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
export GIT_EDITOR=vim

alias rdir='git rev-parse --show-toplevel'
alias groot='rdir'
alias rname="rdir | sed 's#.*/##'"

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

export GIT_USER_DEFAULT="${USER}"
gu () {
  test $# -eq 0 &&
    echo "GIT_USER_DEFAULT=${GIT_USER_DEFAULT}" ||
    export GIT_USER_DEFAULT="$*"
}

# Pull, Push, & Fetch
# alias gp='git pull && git push'
gp () {
  git pull &&
    test -n "$(git status | grep 'git push')" &&
    git push "$@"
    ercho "$(rname) Syncing Done"
}
alias gpull='git pull'
alias gpush='git push'
alias gip='git pull && git push --'
alias gpuf='git push -f'
alias gfet='git fetch'
alias getch='git fetch'
alias gforce='git push -f'
alias glog='git log HEAD~1..HEAD'

alias gits='git status'
alias gs='git status'
alias grems="git remote -v"
alias grem='git remote'
alias gradd="git remote add" #name #url
alias grpush='git push --set-upstream origin' #branch_name

alias gdif='git diff'
alias gitd='git diff'
alias gid='git diff'
alias glod='git diff --compact-summary HEAD~1'
alias glas='git diff --compact-summary HEAD~1'
alias glast='git diff --compact-summary HEAD~1; git diff HEAD~1'

alias gib='git branch'
alias gb='git branch'
alias b="git branch"
alias gadd='git add'
alias gapp='git add -p'
alias glogs='git log'
alias gitl='git log'
alias stash='git stash --keep-index push'
alias gash='git stash push'
alias gpop='git stash pop'
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

# Checkout
alias gitch='git checkout'
alias gch='git checkout'
alias gm='git checkout master'
alias gm='git checkout $(git branch --list master main | head -n1)'
alias gl='git checkout $USER/local'
quiet unalias gt
gt () { git checkout "${GIT_USER_DEFAULT}/$(getTicket "$@")"; }
alias bt="gt"
branch_name () { git branch | egrep '^\*' | sed -e 's#^\* *##'; }
alias branchName=branch_name
grup () {
  local curr=$(branch_name)
  git push --set-upstream origin "$curr"
}
remaster () {
  local curr=$(branch_name)
  local edited_files=$( git status |
    egrep '\W+modified:' | tr '\t' ' ' |
    sed -E 's# *modified: *(.*) *$#"\1"#' |
    tr '\n' ' ' | append '\n'
  )
  local curr_commit=$(git log HEAD~1..HEAD --oneline | cut -f1 -d' ')
  eval "git stash push $edited_files" &&
    git checkout master &&
    git pull upstream master &&
    git checkout "$curr" &&
    run git reset --hard master &&
    run git cherry-pick ${curr_commit} &&
    git push -f origin "$curr" &&
    test -n "$edited_files" &&
    git stash pop
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
  git branch --set-upstream-to="origin/$1";} # Change this to take in the current branch name and ask for the remote name / maybe the url
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
  local repo_dir="$(git rev-parse --show-toplevel)"
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
  git stash push | grep -v "No local changes" && stashed=1
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
unset _GIT_SH_INIT
