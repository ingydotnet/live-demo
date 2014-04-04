#!/usr/bin/env bash

# Default title 'LiveDemo™ — git-hub - All Your GitHub int the Terminal
# Warn on ctl-d (before exiting live-demo).
# ++ - adds last command to the history
# == - replaces last command in history with current one
# -- - delete last command in history
# Adding remaining lines to history on exit
# \s - save history to demo file
# \g - prompt for command # to goto
# Look for config next to demo-file
# Maybe put live-demo into a single file (bin/live-demo)
  # Put config inside demo file
# Support http:// demo files
# Make a colorful prompt
# Find cool/fun terminal apps like cowsay and sl
# Support special meta commands in demo input file

set -e

OPTIONS_SPEC="\
live-demo [<option>...] <file.demo>

Options:
--
h           Show the command summary
 
r,record    Save new commands
a,auto      Play demo automatically
l,loop      Replay the demo at the end
d,delay=    Seconds to pause between autoplay commands
c,clear     Clear screen screen before each command
p,prompt=   Shell prompt to use
f,config=   Config file location
g,goto=     Start demo at a certain number
 
x           Debug - Turn on Bash trace (set -x) output
"

live-demo-run() {
  local demo_file= history_file= config_file= repl_prompt=
  local record_mode=false auto_play=false loop_mode=false
  local delay_time=5 clear_screen=false slow_type=true
  local demo_input=() demo_counter= goto_number=1

  get-opts "$@"

  export LIVEDEMO_DEMO_FILE="$demo_file"
  export LIVEDEMO_HISTORY_FILE="$history_file"
  export LIVEDEMO_REPL_PROMPT="$repl_prompt"
  export INPUTRC=/dev/null

  $BASH --rcfile $BASH_SOURCE
}

#------------------------------------------------------------------------------
get-opts() {
  [ $# -eq 0 ] && set -- --help

  eval "$(
    echo "$OPTIONS_SPEC" |
      git rev-parse --parseopt -- "$@" ||
    echo exit $?
  )"

  while [ $# -gt 0 ]; do
    local option="$1"; shift
    case "$option" in
      -f) config_file=$1; shift ;;
      -d) delay_time=$1; shift ;;
      -s) goto_number=$1; shift ;;
      -r) record_mode=true ;;
      -a) auto_play=true ;;
      -c) clear_screen=true ;;

      --) break ;;

      *) die "Unexpected option: $option" ;;
    esac
  done

  demo_file="$1"; shift
  [ -n "$demo_file" ] ||
    die "<demo-file> required"
  [ $# == 0 ] ||
    die "Unknown arguments '$@'"

  # Initialize variables:
  repl_prompt="${LIVEDEMO_PROMPT:-\w \!> }"
  config_file="${LIVEDEMO_CONFIG:-$HOME/.live-demo/config}"

  history_file=$demo_file.$$.history

  [ -n "$demo_file" ] ||
    die "<demo-file> argument is required"
  [ -e "$demo_file" ] ||
    die "Demo file '$demo_file' does not exist"
}

#------------------------------------------------------------------------------

# LiveDemo gets its magics from clever readline key bindings:
setup-key-bindings() {
  # Bind command to Control-t #. Lets us do tricks:
  bind -x '"\C-t1":start-demo-command'
  bind -x '"\C-t2":type-next-char'
  bind '"\C-t3":accept-line'
  bind -x '"\C-t4":finish-demo-command'
  bind -x '"\C-t5":normal-input-mode'

  fast_keys=($(
    echo "abcdefghijklmnopqrstuvwxyz1234567890;,." | grep -o .
  ))

  normal-input-mode
}

start-demo-command() {
  demo_command="${demo_input[$demo_counter]%$'\n'}"
  title-preview-and-insert
  fast-input-mode
}

type-next-char() {
  title-insert
  if [ $READLINE_POINT -lt ${#demo_command} ]; then
    READLINE_LINE+="${demo_command:$READLINE_POINT:1}"
    READLINE_POINT=${#READLINE_LINE}
    bind-enter-normal
  else
    bind-enter-demo
  fi
}

finish-demo-command() {
  if [ $READLINE_POINT -lt ${#demo_command} ]; then
    demo_counter=$((demo_counter + 1))
  fi
  demo_command=
  if [ $demo_counter -ge ${#demo_input[@]} ]; then
    exit 0
  fi
}

normal-input-mode() {
  title-reset

  # <SPACE><SPACE> - Start fast input mode with next demo command:
  bind '"  ":"\C-u\C-t1"'

  bind-enter-normal

  # Reset keys to normal input:
  for k in ${fast_keys[@]}; do
    bind $k:self-insert
  done
}

# Press any keys to type. (Easier than typing lessons!)
fast-input-mode() {
  # Remove double-space binding during fast input mode.
  bind -r "  "
  # bind '"  ":self-insert'

  # Let any key [a-z\ ] type the next input char:
  for k in ${fast_keys[@]}; do
    bind '"'$k'":"\C-t2"'
  done
}

# Put the command in the terminal title for a sneak preview.
title-preview-and-insert() {
  echo -en "\033]2;$demo_command\007";
  (( sleep 1; title-insert; ) & ) 2> /dev/null
}

title-reset() {
  echo -en "\033]2;Live Demo™\007";
}

title-insert() {
  echo -en "\033]2;-- INSERT --\007";
}

# Adds a <SPACE> at end to satisfy HISTIGNORE.
# (normal commands not added to demo history)
bind-enter-normal() {
  bind '\C-m:"\C-e \C-j\C-t5"'
}

bind-enter-demo() {
  bind '"\C-m":"\C-t3\C-t4\C-t5"'
}

# XXX Not working yet. Need to restart bash in current state.
confirm-exit() {
  $LIVEDEMO_DONE && exit 0
  echo -n 'Really exit LiveDemo™? [yN] '
  read line
  if [[ "$line" =~ [yY] ]]; then
    exit
  fi
  $BASH --rcfile $BASH_SOURCE
}

#------------------------------------------------------------------------------
if [ -z "$LIVEDEMO_RUNNER" ]; then
  set +e
  HISTFILE="$LIVEDEMO_HISTORY_FILE"
  HISTIGNORE='* '
  PS1="$LIVEDEMO_REPL_PROMPT"

  # export LIVEDEMO_DONE=false
  # trap confirm-exit EXIT

  setup-key-bindings

  demo_counter=0
  readarray demo_input < <(cat "$LIVEDEMO_DEMO_FILE")
  clear
fi

# vim: set lisp:
