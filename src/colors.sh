# Source: https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters

# _color_pre="\e["
# _color_end="m"

_color_reset="\e[0m"

# _color_fg="\e[38;5;"
# _color_bg="\e[48;5;"

# Foreground Colours
{
  _black="\e[30m"
  _red="\e[31m"
  _green="\e[32m"
  _yellow="\e[33m"
  _blue="\e[34m"
  _magenta="\e[35m"
  _cyan="\e[36m"
  _white="\e[37m"
  _b_black="\e[90m"
  _b_red="\e[91m"
  _b_green="\e[92m"
  _b_yellow="\e[93m"
  _b_blue="\e[94m"
  _b_magenta="\e[95m"
  _b_cyan="\e[96m"
  _b_white="\e[97m"
}

# Background Colours
{
  _black_bg="\e[40m"
  _red_bg="\e[41m"
  _green_bg="\e[42m"
  _yellow_bg="\e[43m"
  _blue_bg="\e[44m"
  _magenta_bg="\e[45m"
  _cyan_bg="\e[46m"
  _white_bg="\e[47m"
  _b_black_bg="\e[100m"
  _b_red_bg="\e[101m"
  _b_green_bg="\e[102m"
  _b_yellow_bg="\e[103m"
  _b_blue_bg="\e[104m"
  _b_magenta_bg="\e[105m"
  _b_cyan_bg="\e[106m"
  _b_white_bg="\e[107m"
}

# Other Formatting
{
  _bold="\e[1m"
  _dim="\e[2m"
  _slant="\e[3m"
  _uline="\e[4m"
  _blink="\e[5m"
  _strobe="\e[6m"
  _reverse_colorscheme="\e[7m"
  _hidden="\e[8m"
  _strikeout="\e[9m"

  _bold_off="\e[21m"
  _dim_off="\e[22m"
  _slant_off="\e[23m"
  _uline_off="\e[24m"
  _blink_off="\e[25m"
  _strobe_off="\e[26m"
  _reverse_colorscheme_off="\e[27m"
  _hidden_off="\e[28m"
  _strikeout_off="\e[29m"
}

# Export environment color variables
{
  export BLACK="$_black"
  export RED="$_red"
  export GREEN="$_green"
  export YELLOW="$_yellow"
  export BLUE="$_blue"
  export MAGENTA="$_magenta"
  export CYAN="$_cyan"
  export NO_COLOR="$_color_reset"
}

# Formatting Echo Functions
{
  bold_echo ()   { echo -e "${_bold}$*${_bold_off}" ; }
  uline_echo ()  { echo -e "${_uline}$*${_uline_off}" ; }
  dim_echo ()    { echo -e "${_dim}$*${_dim_off}" ; }
  blink_echo ()  { echo -e "${_blink}$*${_blink_off}" ; }
  strobe_echo () { echo -e "${_strobe}$*${_strobe_off}" ; }
  hidden_echo () { echo -e "${_hidden}$*${_hidden_off}" ; }
}

__get_SGR_color_num () {
  local offset=30
  local black=0
  local red=1
  local green=2
  local yellow=3
  local blue=4
  local magenta=5
  local cyan=6
  local white=7
  # local specify=8
  # local default=9

  if test $# -eq 0; then
    err=$?
    >&2 echo "Usage: __get_SGR_color_num <color_name>"
    return $err
  fi
  arg=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case $arg in
    black|k)
      expr ${offset} + ${black}
    ;;
    red|r)
      expr ${offset} + ${red}
    ;;
    green|g)
      expr ${offset} + ${green}
    ;;
    yellow|y)
      expr ${offset} + ${yellow}
    ;;
    blue|b)
      expr ${offset} + ${blue}
    ;;
    magenta|m|pink|purple|p)
      expr ${offset} + ${magenta}
    ;;
    cyan|c)
      expr ${offset} + ${cyan}
    ;;
    white|w)
      expr ${offset} + ${white}
    ;;
    *)
      >&2 echo "ERROR: color '$1' is not defined"
    ;;
  esac
}

__get_SGR_bright_color_num () {
  local brighten=60
  if test $# -eq 0; then
    err=$?
    <&2 echo "Usage: __get_SGR_bright_color_num <color_name>"
    return $err
  fi
  expr $(__get_SGR_color_num "$@") + ${brighten}
}

__get_SGR_fg_color_num () {
  # option: -t brighten
  local brighten=''
  while getopts t opt; do
    case $opt in
      t) brighten=True ;;
      *) >&2 echo "ERROR: Invalid option '-$opt'" ;;
    esac
  done
  shift $((OPTIND-1))
  if test "$brighten"; then
    __get_SGR_bright_color_num "$@"
  else
    __get_SGR_color_num "$@"
  fi
}

__get_SGR_bg_color_num () {
  # option: -t brighten
  local bg_offset=10
  expr $(__get_SGR_fg_color_num "$@") + ${bg_offset}
}

__get_SGR_color () {
  # option: -t brighten, -g get_background_color
  local saved_opts=() bg=''
  while getopts tg opt; do
    case $opt in
      t) saved_opts+=($opt) ;;
      g) bg=True ;;
    esac
  done
  shift $((OPTIND-1))
  if test "$bg"; then
    echo -n '' # Placeholder
  fi

}
__color_math_help () {
  echo -e "
  -b -B             Bold ON / OFF
    --(no-)bold
  -d -D             Dim ON / OFF
  -i -I             Italise On / OFF
    --(no-)slant
  -u -U             Underline ON / OFF
    --(no-)underline
  -f -F             Blink ON / OFF (slow flashing)
    --(no-)blink
  -k -K             Strobe ON / OFF (fast flashing)
    --(no-)strobe
  -v -V             Reverse Foreground and Background Colors ON / OFF
  -c <key|num;num>  Specify color; overrides -C
                      Keys: r,g,b,y,c,m,k
  -C                Default color; overrides -c
  -t                Use Bright color
  -g                Set Background Color
  -x -X             Hidden Text
    --(no-)hide
  -s -S             Strikethrough On / OFF
    --(no-)strike


  --reset --clear   Removes any formatting
    --(no-)


"


}

color_math () {

  # Color Offset Values
  # line color only works with specify or default
  # local line=50

  # Format Options
  local bold=1
  local dim=2
  local slant=3
  local underline=4
  local blink=5
  local strobe=6
  local reverse_colorscheme=7
  local hide=8
  local strike=9

  # Format Offset Values
  local format_on=0
  local format_off=20

  local font=10
  local num_fonts=10

  # Non standard
  local overline=53
  local overline_off=55

  local superscript=73
  local subscript=74
  local sscript_off=75

  local value=0
  local is_color is_bright is_bg do_reset

  while getopts lhbrf-: FLAG; do
    case $FLAG in
    -*)
      case "${OPTARG}" in
        help)
        ;;
        reset|clear)
          do_reset=True
        ;;
        background)
          is_color=True
          is_bg=True
        ;;
        bright)
          is_color=True
          is_bright=True
        ;;
        color)
          is_color=True
        ;;
        *)
          test $OPTERR -eq 1 &&
            test ${OPTSPEC:0:1} -ne ':' &&
            >&2 echo "Unknown option --${OPTARG}"
        ;;
      esac
    ;;
    h) # help
    ;;
    esac
  done
  shift $((OPTIND-1))
}

color8 () { # 8 bit color
  # ESC[38;5;⟨n⟩m Select foreground color
  # ESC[48;5;⟨n⟩m Select background color
  #   0-  7:  standard colors (as in ESC [ 30–37 m)
  #   8- 15:  high intensity colors (as in ESC [ 90–97 m)
  #  16-231:  6 × 6 × 6 cube (216 colors): 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
  # 232-255:  grayscale from dark to light in 24 steps
  echo -n '' # Placeholder
}

color24 () { # 24 bit color
  # ESC[38;2;⟨r⟩;⟨g⟩;⟨b⟩ m Select RGB foreground color
  # ESC[48;2;⟨r⟩;⟨g⟩;⟨b⟩ m Select RGB background color
  echo -n '' # Placeholder
}
