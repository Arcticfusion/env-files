#!/bin/bash
name_="jira.sh"
if ! [ -n "$_JIRA_INIT" ]; then
  export _JIRA_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# JIRA SH START

jirat="/sandbox/$USER/jira.ticket"
test -e "$jirat" ||
  jirat="$HOME/$USER/jira.ticket"

getTicketInfo() {
  if ! test -e "$JIRA_FILE"; then
    errcho "No Jira File: JIRA_FILE='$JIRA_FILE'"
    return 1
  fi
  if test "$#" -gt 0; then
    for t in "$@"; do
      tail -n "$t" "$JIRA_FILE" | head -n 1 || errcho "'$t' is not a ticket index"
    done
  else
    tail -n 1 "$JIRA_FILE"
  fi
}
alias gti="getTicketInfo"

getTicket() {
  local tickets=$(getTicketInfo "$@")
    echo "$tickets" | cut -f1 -d';'
}

getTicketName() {
  echo "$(getTicketInfo $@)" | sed -E 's/^([^;]*;){2}//'
}

addTicket() {
  test -e "$JIRA_FILE" || return $?
  test "$#" -ge "1" || return $?
  local ticket=$(echo "$1" | egrep "^[A-Z]{2}-[0-9]{4,6}$")
  test -n "$ticket" || return $?
  shift 1
  local date_pattern='+%Y-%m-%d'
  local date_="$(date -d "$2" $date_pattern 2>/dev/null && shift 1 || date $date_pattern )"
  local name="$(echo "$*" | sed -E 's/^ *//' | sed -E 's/ *$//' | sed 's/ +/ /g' )"
  echo "$ticket;$date_;$name"
  echo "$ticket;$date_;$name" >> "$JIRA_FILE"
}

test -e "$jirat" &&
  export JIRA_FILE="$jirat" &&
  export JIRA_TICKET=$(getTicket)

# JIRA SH END
unset _JIRA_INIT
