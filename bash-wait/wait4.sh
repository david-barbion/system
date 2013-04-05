#/bin/bash

MAXTIMEOUT=7

# this allow to handle timeout
timedwait() {
  sleep $MAXTIMEOUT &
  sleeppid=$!
  wait $! >/dev/null 2>&1
}

# this function send SIGTERM to remaining childs
killallchilds() {
    for pid in "$@"; do
      shift
      debug "send SIGTERM to $pid"
      kill -0 "$pid" 2>/dev/null && kill $pid
    done
}

# need to pass list of child pids
waitall() {
  # Wait for children to exit and indicate whether all exited with 0 status.
  local errors=0
  # start the infinite loop
  while :; do
    debug "Processes remaining: $*"
    # test all pids
    for pid in "$@"; do
      shift
      # test if still present
      if kill -0 "$pid" 2>/dev/null; then
        # still present, remove the pid from pid list
        debug "$pid is still alive."
        set -- "$@" "$pid"
      # use wait to get back the return code of the child
      elif wait "$pid" 2>/dev/null; then
        debug "$pid exited with zero exit status."
      else
        debug "$pid exited with non-zero exit status."
        ((++errors))
      fi
    done
    # exit when no child remains
    (("$#" > 0)) || break
    # TODO: how to interrupt this sleep when a child terminates?
    timedwait
    if [ $? -eq 0 ]; then
      # timeout reached
      debug "timeout, killing remaining child"
      killallchilds $@
    fi
  done
  # return 0 if no child exited with error else 1
  ((errors == 0))
}

debug() { echo "DEBUG: $*" >&2; }

# this is called when a child exits
# this will kill the sleep process in the main waiting loop
childexit() {
  kill -0 $sleeppid 2>/dev/null && kill $sleeppid
}
# activate job monitoring
# this allow to send signal SIGCHLD on child crash/exit
set -o monitor
trap "childexit" CHLD

# start few childs
pids=""
for t in 3 5 4 100 101 102; do 
  sleep "$t" &
  pids="$pids $!"
done

# wait for all childs to exit
waitall $pids

# here all child have exited
