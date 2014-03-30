#!/usr/bin/env bash

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
start-demo-command() {
  demo_command="${demo_input[$demo_counter]%$'\n'}"
  echo -en "\033]2;$demo_command\007";
  fast-input-mode
}

type-next-char() {
  echo -en "\033]2;Live Demo™\007";
  if [ $READLINE_POINT -lt ${#demo_command} ]; then
    READLINE_LINE+="${demo_command:$READLINE_POINT:1}"
    READLINE_POINT=${#READLINE_LINE}
    bind '\C-m:"\C-e \C-j\C-t5"'
  else
    bind '"\C-m":"\C-t3\C-t4\C-t5"'
  fi
}

finish-demo-command() {
  if [ "$demo_command" == '# THE END' ]; then
    exit
  fi
  demo_command=
  demo_counter=$((demo_counter + 1))
}

normal-input-mode() {
  # `` and \\ - Start fast input mode with next demo command:
  bind '"``":"\C-u\C-t1"'
  bind '"\\\\":"\C-u\C-t1"'
  bind '"\C-`":"\C-l\C-u\C-t1"'

  # <ENTER> - Adds a <SPACE> at end to satisfy HISTIGNORE:
  bind '"\C-m":"\C-e \C-j\C-t5"'

  # Bind command to Control-t #. Lets us do tricks:
  bind -x '"\C-t1":start-demo-command'
  bind -x '"\C-t2":type-next-char'
  bind '"\C-t3":accept-line'
  bind -x '"\C-t4":finish-demo-command'
  bind -x '"\C-t5":normal-input-mode'

  # Reset a-z to normal input:
  for k in $(echo "abcdefghijklmnopqrstuvwxyz" | grep -o .); do
    bind $k:self-insert
  done
  bind '" ":self-insert'
}

# Let any key a-z type the next input char. (Easier than typing lessons!)
fast-input-mode() {
  for k in $(echo "abcdefghijklmnopqrstuvwxyz" | grep -o .); do
    bind '"'$k'":"\C-t2"'
  done
  bind '" ":"\C-t2"'
}

#------------------------------------------------------------------------------
if [ -z "$LIVEDEMO_RUNNER" ]; then
  set +e
  HISTFILE="$LIVEDEMO_HISTORY_FILE"
  HISTIGNORE='* '
  PS1="$LIVEDEMO_REPL_PROMPT"

  normal-input-mode

  demo_counter=0
  readarray demo_input < <(cat "$LIVEDEMO_DEMO_FILE")
  clear
fi

# vim: set lisp:
