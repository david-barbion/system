#/bin/bash

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
      elif wait "$pid"; then
        debug "$pid exited with zero exit status."
      else
        debug "$pid exited with non-zero exit status."
        ((++errors))
      fi
    done
    # exit when no child remains
    (("$#" > 0)) || break
    # TODO: how to interrupt this sleep when a child terminates?
    sleep ${WAITALL_DELAY:-1}
   done
  # return 0 if no child exited with error else 1
  ((errors == 0))
}

debug() { echo "DEBUG: $*" >&2; }

# start few childs
pids=""
for t in 3 5 4; do 
  sleep "$t" &
  pids="$pids $!"
done

# wait for all childs to exit
waitall $pids

# here all child have exited
