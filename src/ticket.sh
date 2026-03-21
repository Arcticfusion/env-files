#!/bin/bash
name_="ticket.sh"
if ! [ -n "$_TICKET_INIT" ]; then
  export _TICKET_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# TICKET SH START

ticket_file="/sandbox/$USER/ticket"
test -e "$ticket_file" ||
  ticket_file="$HOME/.ticket"

getTicketInfo() {
  if ! test -e "$TICKET_FILE"; then
    errcho "No ticket file: TICKET_FILE='$TICKET_FILE'"
    return 1
  fi
  if test "$#" -gt 0; then
    for t in "$@"; do
      tail -n "$t" "$TICKET_FILE" | head -n 1 || errcho "'$t' is not a ticket index"
    done
  else
    tail -n 1 "$TICKET_FILE"
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
  test -e "$TICKET_FILE" || return $?
  test "$#" -ge "1" || return $?
  local ticket=$(echo "$1" | egrep "^[A-Z]{2}-[0-9]{4,6}$")
  test -n "$ticket" || return $?
  shift 1
  local date_pattern='+%Y-%m-%d'
  local date_="$(date -d "$2" $date_pattern 2>/dev/null && shift 1 || date $date_pattern )"
  local name="$(echo "$*" | sed -E 's/^ *//' | sed -E 's/ *$//' | sed 's/ +/ /g' )"
  echo "$ticket;$date_;$name"
  echo "$ticket;$date_;$name" >> "$TICKET_FILE"
}

test -e "$ticket_file" &&
  export TICKET_FILE="$ticket_file" &&
  export TICKET=$(getTicket)

# TICKET SH END
test -n "${ENV_DEBUG}" &&
  >&2 echo -e "\tticket.sh is Initialised"
unset _TICKET_INIT
