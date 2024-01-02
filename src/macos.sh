#!/bin/zsh
name_='macos.sh'
if ! [ -n "${_MACOS_SH_INIT}" ]; then
  export _MACOS_SH_INIT="True"
else
  >&2 echo "Already Initialising $name_"
  return
fi
>&2 echo "Initialising $name_"
unset name_
# MACOS SH START

# Homebrew
test -f "${ENV_REPO}/homebrew.sh" && source "${ENV_REPO}/homebrew.sh"

# System Info
alias sysinfo='system_profiler SPSoftwareDataType SPHardwareDataType'
alias os='echo $(sw_vers -productName)-$(sw_vers -productVersion)-$(sw_vers -buildVersion)'

# Hidden Files Shortcuts
alias showFiles='defaults write com.apple.Finder AppleShowAllFiles true; killall Finder'
alias hideFiles='defaults write com.apple.Finder AppleShowAllFiles false; killall Finder'

test -d "/Users/$USER/Applications/bin" &&
  export PATH="/Users/$USER/Applications/bin:$PATH"
test -e "/Users/${USER}/Applications/homebrew/opt/dotnet@6/libexec" &&
  export DOTNET_ROOT="/Users/${USER}/Applications/homebrew/opt/dotnet@6/libexec"
# Dock Modifiers
# Modify Movement Speed of the Dock
dockSpeed() {
  if [ "$#" -ge 1 ]; then
  defaults write com.apple.dock autohide-time-modifier -float "$1"
  else
    defaults write com.apple.dock autohide-time-modifier
  fi
  killall Dock
}

# Modify Delay of Dock Appearing/Disappearing
dockDelay() {
  if [ "$#" -ge 1 ]; then
    defaults write com.apple.dock autohide-time-modifier -float "$1"
  else
    defaults write com.apple.dock autohide-time-modifier -float 1
  fi
  killall Dock
}

# Add spacer to the dock
# alias dockSpace="defaults write com.apple.dock persistent-apps -array-add '{\"tile-type\"=\"small-spacer-tile\";}'; killall Dock"
dockSpace ()  {
  local size=""
  if [ $# > 0]; then
    case "$1" in
    [mM1]*)
      break
    ;;
    [lL2]*)
      size="large"
    ;;
    *)
      size="small-"
    ;;
    esac
  else
    size="small-"
  fi
  defaults write com.apple.dock persistent-apps -array-add \
    "{\"tile-type\"=\"${size}spacer-tile\";}"
  killall Dock
}

# Toggle visiblity of hidden apps - this is default value
#  NOTE: a bit broken since the environment variable can be inaccurate
#        so it may not work the first time
if ! [[ "${DOCK_SHOW_HIDDEN_APPS}" == "TRUE" ]]; then
  export DOCK_SHOW_HIDDEN_APPS="FALSE"       # Default Behaviour
fi
dockShowHiddenApps() {
  if test "${DOCK_SHOW_HIDDEN_APPS}" == "TRUE"; then
    export DOCK_SHOW_HIDDEN_APPS="FALSE"
  else
    export DOCK_SHOW_HIDDEN_APPS="TRUE"
  fi
  defaults write com.apple.dock showhidden -bool "${DOCK_SHOW_HIDDEN_APPS}"
  killall Dock
}

# nproc equivalent - number of logical cores
alias nproc='sysctl -n hw.ncpu'

# MACOS SH END
unset _MACOS_SH_INIT
