#!/usr/bin/env bash

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
o,output=   Write to an output file
 
x           Debug - Turn on Bash trace (set -x) output
"

live-demo-run() {
  local demo_file= output_file= config_file= repl_prompt=
  local record_mode=false auto_play=false loop_mode=false
  local delay_time=5 clear_screen=false

  get-opts "$@"
  set-vars
  read-demo-file

  repl
}

set-vars() {
  local prompt="${LIVE_DEMO_PROMPT:-'\w > '}"
}

repl() {
  local command=
  while true; do
    get-command
    run-command
  done
}

get-command() {
  :
}

run-command() {
  :
}

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
      -o)
        output_file=$1
        shift
        ;;
      -f)
        config_file=$1
        shift
        ;;
      -d)
        delay_time=$1
        shift
        ;;
      -r) record_mode=true ;;
      -a) auto_play=true ;;
      -p) repl_prompt=true ;;
      -c) clear_screen=true ;;

      --) break ;;

      *) die "Unexpected option: $option" ;;
    esac
  done

  demo_file="$1"; shift

  if [ -n "$output_file" ]; then
    if [ -z "$demo_file" ]; then
      demo_file="$output_file"
    fi
    [ ! -e "$output_file" ] && touch "$output_file"
  fi
  [ -n "$demo_file" ] ||
    die "<demo-file> argument is required"
  [ -e "$demo_file" ] ||
    die "Demo file '$demo_file' does not exist"
}

# vim: set lisp:
