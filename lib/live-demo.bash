#!/usr/bin/env bash

# == Bugs
# \g not resetting history #

# == ToDo

# == Maybe
# Put live-demo into a single file (bin/live-demo)
  # Put config inside demo file
# Support http:// demo files
# Make a colorful prompt

set -e

export PROMPT_COMMAND=set-prompt

OPTIONS_SPEC="\
live-demo [<option>...] <file.demo>

Options:
--
h             Show the command summary
 
p,prompt=     Set the demo prompt to use
t,time=       Number of mins/secs left in prompt
g,goto=       Start demo at the specified command number
q,quiet       Be more quiet
 
x             Debug - Turn on Bash trace (set -x) output
"

help() {
  alert \
'In Demo mode, type any alphanumeric keys to type out the command, or press
<TAB> at any point to complete the demo command.

The following key sequences can be used at any point:

    \h    Show this help screen
    \\    Toggle between Demo and Shell input modes
    \l    List all the demo commands
    \g    Goto the command number that you typed in Shell mode
    \+    Add previous shell command to history
    \-    Remove last command in the history
    \s    Save the current command list back to the demo file
    C-d   Exit the demo gracefully
    \X    Exit immediately
    \?    Show all the internal state variables

'
}

main() {
  get-opts "$@"

  export-all

  $BASH --rcfile $BASH_SOURCE
}

get-opts() {
  [ $# -eq 0 ] && set -- --help

  # Initialize variables:
  livedemo_prompt='LiveDemo™ \w \!> '
  livedemo_quiet=false

  eval "$(
    echo "$OPTIONS_SPEC" |
      git rev-parse --parseopt -- "$@" ||
    echo exit $?
  )"

  while [ $# -gt 0 ]; do
    local option="$1"; shift
    case "$option" in
      -p) livedemo_prompt=$1; shift ;;
      -g) livedemo_goto=$1; shift ;;
      -q) livedemo_quiet=true ;;
      -t)
        livedemo_countdown=$1
        livedemo_starttime=$(date +%s)
        shift ;;
      -x) set -x ;;
      --) break ;;
      *) die "Unexpected option: $option" ;;
    esac
  done

  # XXX - For OSDC.tw only:
  : ${livedemo_countdown:=30}
  livedemo_starttime=$(date +%s)

  livedemo_demo_file="$1"; shift
  [ -n "$livedemo_demo_file" ] ||
    die "<demo-file> required"
  [ $# == 0 ] ||
    die "Unknown arguments '$@'"

  [ -n "$livedemo_demo_file" ] ||
    die "<demo-file> argument is required"
  [ -e "$livedemo_demo_file" ] ||
    die "Demo file '$livedemo_demo_file' does not exist"
  livedemo_demo_file="$(abspath "$livedemo_demo_file")"
  livedemo_demo_dir="$(dirname $livedemo_demo_file)"
}

export-all() {
  export HISTFILE=/dev/null
  export HISTIGNORE='* '
  export INPUTRC=/dev/null

  for v in $(compgen -v | grep '^livedemo_'); do export $v; done

  export livedemo_running=1
}

alert() {
  alert-whiptail "$1" || echo -n "$1"
}

alert-whiptail() {
  $livedemo_quiet && return 0
  [ -n "$(which whiptail)" ] || return 1
  msg="$1"
  msg="${msg##$'\n'}"
  msg="${msg%%$'\n'}"
  local w=0 h=5
  while read -r line; do
    : $((h++))
    [ ${#line} -gt $w ] && w=${#line}
  done <<< "$msg"
  let w=$((w + 4))
  whiptail --msgbox "$msg" $h $w
}

set-prompt() {
  [ -n "$livedemo_countdown" ] || return
  local time=$(date +%s)
  local diff=$((
    livedemo_countdown * 60 -
    (time - livedemo_starttime)
  ))
  local min=$((diff / 60))
  local sec=$((diff % 60))
  local stamp
  local light_cyan="\033[1;36m"
  local reset="\033[0m"
  printf -v stamp "$light_cyan(%d:%02d)$reset " $min $sec
  echo $stamp
}

abspath() { perl -MCwd -le 'print Cwd::abs_path(shift)' "$1"; }

#------------------------------------------------------------------------------
demo-input-mode() {
  livedemo_mode=demo
  PS1="$livedemo_prompt"

  livedemo_command="${livedemo_input[$livedemo_counter]}"

  # Let any key type the next input char:
  for k in ${fast_keys[@]}; do bind '"'$k'":"\C-tN"'; done

  # \\ switches to shell input mode:
  bind '"\\\\":"\C-u\C-tB\C-tA"'

  # TAB completes demo command:
  bind '"\t":"\C-tT"'

  bind-enter-normal
}

shell-input-mode() {
  livedemo_mode=shell
  livedemo_special=false
  PS1='\w $ '

  livedemo_command=

  # Reset keys to normal input:
  for k in ${fast_keys[@]}; do bind $k:self-insert; done

  # Start demo input mode:
  bind '"\\\\":"\C-u\C-tD\C-tA"'

  # Normal tab completion:
  bind '"\t":complete'

  bind-enter-normal
}

type-next-char() {
  $livedemo_special && return
  if [[ "$livedemo_command" =~ ^[♈♥♬■🔥🌴Ⓕⓕ] ]]; then
    livedemo_special=true
    bind-enter-demo
  fi
  if [ $READLINE_POINT -lt ${#livedemo_command} ]; then
    READLINE_LINE+="${livedemo_command:$READLINE_POINT:1}"
    READLINE_POINT=${#READLINE_LINE}
    $livedemo_special || bind-enter-normal
  else
    bind-enter-demo
  fi
}

tab-complete-demo-command() {
  if [[ "$livedemo_command" =~ ^[♈♥♬■🔥🌴Ⓕⓕ] ]]; then
    livedemo_special=true
    bind-enter-demo
  fi
  READLINE_LINE="$livedemo_command"
  READLINE_POINT=${#READLINE_LINE}
  bind-enter-demo
}

finish-demo-command() {
  # [[ "$livedemo_command" =~ \;$ ]] && clear
  livedemo_counter=$((livedemo_counter + 1))
  livedemo_command=
  if [ $livedemo_counter -ge ${#livedemo_input[@]} ]; then
    livedemo_done=true
    exit 0
  fi
  demo-input-mode
  livedemo_special=false
}

check-special() {
  if $livedemo_special; then
    READLINE_LINE="$livedemo_command"
  fi
}

finish-shell-command() {
  shell_command="$READLINE_LINE"
  livedemo_special=false
}

# Adds a <SPACE> at end to satisfy HISTIGNORE.
# (normal commands not added to demo history)
bind-enter-normal() {
  bind '\C-m:"\C-tb\C-e \C-j"'
}

bind-enter-demo() {
  bind '\C-m:"\C-tS\C-tA\C-td"'
}

list-commands() {
  commands-list true
  echo -n "$output"
}

commands-list() {
  local show_marker=$1
  local i=0 line=
  output=''
  for cmd in "${livedemo_input[@]}"; do
    local marker=' '
    [ $i -eq $livedemo_counter ] && $show_marker && marker='*'
    local num=$((++i))
    printf -v line "%s%3d - %s\n" "$marker" $num "$cmd"
    output+="$line"
  done
}

add-command() {
  [ -n "$shell_command" ] || return
  local tmp=("${livedemo_input[@]}")
  livedemo_input=(
    "${tmp[@]:0:$livedemo_counter}"
    "$shell_command"
    "${tmp[@]:$livedemo_counter}"
  )
  : $((livedemo_counter++))
  shell_command=
  reset-history
}

remove-command() {
  [ $livedemo_counter -gt 0 ] || return
  local tmp=("${livedemo_input[@]}")
  livedemo_input=(
    "${tmp[@]:0:$(($livedemo_counter - 1))}"
    "${tmp[@]:$livedemo_counter}"
  )
  reset-history
}

goto-command() {
  [ "$livedemo_mode" == demo ] && return
  local num="$READLINE_LINE"
  goto $num
}

goto() {
  local num="$1"
  if [[ ! "$num" =~ ^[0-9]+$ ]] ||
    [ $num -eq 0 ] ||
    [ $num -gt ${#livedemo_input[@]} ]
  then
      echo "'$num' is not a valid goto number"
      return 1
  fi
  livedemo_counter=$((num - 1))
  reset-history
}

reset-history() {
  history -c
  for (( i = 0; i < $livedemo_counter; i++ )); do
    history -s "${livedemo_input[$i]}"
  done
  history -w
  demo-input-mode
}

save-to-demo-file() {
  rm -f $livedemo_demo_file
  for line in "${livedemo_input[@]}"; do
    echo "$line" >> $livedemo_demo_file
  done
  echo "Saved '$livedemo_demo_file'"
}

confirm-exit() {
  if ! $livedemo_done; then
    echo -n 'Really exit LiveDemo™? [yN] '
    read line
    if [[ ! "$line" =~ ^[yY]$ ]]; then
      livedemo_input_lines=
      for line in "${livedemo_input[@]}"; do
        livedemo_input_lines+="$line"$'\n'
      done
      export-all
      $BASH --rcfile $BASH_SOURCE
      exit 0
    fi
  fi
  commands-list false
  if [ "$output" != "$livedemo_original_input" ]; then
    while true; do
      echo -n 'Changes have been made. Save them? [yn] '
      read line
      [[ "$line" =~ ^[yYnN]$ ]] || continue
      if [[ "$line" =~ ^[yY]$ ]]; then
        save-to-demo-file
      fi
      break
    done
  fi
  exit 0
}

title-set() {
  echo -en "\033]2;$@\007"
}

#------------------------------------------------------------------------------
do-alert() {
  local w=0 h=5
  alert=''
  while read -r line; do
    alert="$alert$line"$'\n\n'
    h=$((h + 2))
    [ ${#line} -gt $w ] && w=${#line}
  done < "$livedemo_demo_dir/alert/$1"
  let w=$((w + 4))
  whiptail --msgbox "$alert" $h $w
  echo ">>$alert<<"
}

do-vroom() {
  (
    cd "$livedemo_demo_dir/vroom/$1"
    vroom vroom
  )
}

do-music() {
  (
    while [ $# -gt 0 ]; do
      background=false
      if [[ ! $1 =~ ^[0-9.]+$ ]]; then
        local song="$1"
        shift
        if [[ "$song" =~ \+$ ]]; then
          song="${song%+}"
          background=true
        fi
      fi
      if [[ $1 =~ ^[0-9.]+$ ]]; then
        local start=0
        start="$1"
        shift
      fi
      if [[ $1 =~ ^[0-9.]+$ ]]; then
        local length=5
        length="$1"
        shift
      fi
      local cmd=(
        mplayer "$livedemo_demo_dir/music/$song"
          -ss "$start"
          -endpos "$length"
          -really-quiet
      )
      if $background; then
        "${cmd[@]}" 2> /dev/null &
      else
        "${cmd[@]}" 2> /dev/null
      fi
    done
  )
}

do-photo() {
  geeqie -f "$livedemo_demo_dir/photo/$1" &>/dev/null
}

do-firefox() {
  firefox -no-remote -P LiveDemo -new-tab $@ &>/dev/null
#   url="$1"
#   shift
#   firefox -no-remote -P LiveDemo "$url" &>/dev/null &
#   while [ $# -gt 0 ]; do
#     url="$1"
#     shift
#     [[ "$url" =~ ^http ]] || url="http://$url"
#     firefox -P LiveDemoi "$url" &>/dev/null &
#   done
}

do-wiki() {
  :
}

do-figlet() {
  clear
  font=standard
  if [[ "$1" =~ ^- ]]; then
    font="${1#-}"
    shift
  fi
  for string; do
    figlet -f $font -W -C utf8 -c -w $(tput cols) "$string" 2>/dev/null
  done
}

do-bad-figlet() {
  clear
  font=standard
  if [[ "$1" =~ ^- ]]; then
    font="${1#-}"
    shift
  fi
  for string; do
    figlet -f $font -W -c -w $(tput cols) "$string"
  done
}

#------------------------------------------------------------------------------
# Initialize the LiveDemo™ Bash shell:
#------------------------------------------------------------------------------
if [ -n "$livedemo_running" ]; then
  set +e

  trap confirm-exit EXIT

  # LiveDemo gets its magics from clever readline key bindings:
  bind '"\C-tA":accept-line'

  bind -x '"\C-tD":demo-input-mode'
  bind -x '"\C-td":finish-demo-command'

  bind -x '"\C-tB":shell-input-mode'
  bind -x '"\C-tb":finish-shell-command'
  bind -x '"\C-tS":check-special'

  bind -x '"\C-tN":type-next-char'
  bind -x '"\C-tT":tab-complete-demo-command'

  bind '"\\+":"\C-ta\C-tA"'
  bind '"\\=":"\C-ta\C-tA"'
  bind -x '"\C-ta":add-command'

  bind '"\\-":"\C-tr\C-tA"'
  bind -x '"\C-tr":remove-command'

  bind '"\\l":"\C-u\C-j\C-tl"'
  bind -x '"\C-tl":list-commands'

  bind '"\\g":"\C-tg\C-u\C-tA"'
  bind -x '"\C-tg":goto-command'

  bind '"\\s":"\C-u\C-tA\C-ts"'
  bind -x '"\C-ts":save-to-demo-file'

  bind '"\\h":"\C-tH"'
  bind -x '"\C-tH":help'

  bind '"\\?":"\C-u\C-tBenv | grep livedemo_ | sort \C-j"'

  bind '"\\X":"\C-u\C-tBtrap EXIT\C-tA\C-lexit\C-j"'

  fast_keys=($(
    echo "abcdefghijklmnopqrstuvwxyz1234567890;,." | grep -o .
  ))

  if [ -z "$livedemo_original_input" ]; then
    startup=true
    livedemo_done=false
    livedemo_special=false
    livedemo_counter=0
    livedemo_input=()
    while read -r line; do
      livedemo_input+=("$line")
    done < "$livedemo_demo_file"
    if [ -n "$livedemo_goto" ]; then
      goto "$livedemo_goto" || exit $?
    fi
    commands-list false
    livedemo_original_input="$output"
  else
    startup=false
    livedemo_input=()
    while read -r line; do
      livedemo_input+=("$line")
    done <<< "${livedemo_input_lines%$'\n'}"
  fi

  cd $HOME

  if $startup; then
    clear
    alert "\

     Welcome to LiveDemo™

Press \h at any time for help.

"
  fi

  alias ♈='do-alert'
  alias ♥='do-vroom'
  alias ♬='do-music'
  alias ■='do-photo'
  alias 🔥='do-firefox'
  alias 🌴='do-wiki'
  alias Ⓕ='do-figlet'
  alias ⓕ='do-bad-figlet'

  demo-input-mode

  export-all
  reset-history
fi

# vim: set lisp:
