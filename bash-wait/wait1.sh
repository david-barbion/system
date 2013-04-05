#!/bin/bash
# + no external file
# + easy to implement
# - no return code after child execution
# - the infinite loop consumes too much CPU

# Start few childs
pids=""
for t in 3 5 4; do 
  sleep "$t" &
  pids="$pids $!"
done

# Here, pids is a string containing all child pids
# Start an infinite loop, checking for exited shilds
while true; do 
    # if pids string still contains pids, check them
    if [ -n "$pids" ] ; then
        # check each pid one by one
        for pid in $pids; do  
            echo "Checking the $pid"
            # try to send a signal to the child, if child has exited, remove its pid from pids string
            kill -0 "$pid" 2>/dev/null || pids=$(echo $pids | sed "s/\b$pid\s*//")
        done
    else
	# here all process have exited
        echo "All your process completed"
        break
    fi
done

# you go here once all process have exited
