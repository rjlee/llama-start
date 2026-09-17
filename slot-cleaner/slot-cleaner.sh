#!/bin/sh
apk add --no-cache curl jq >/dev/null 2>&1

echo "slot-cleaner started (interval: 30s)"

while sleep 30; do
  touch /tmp/slot-cleaner-heartbeat
  SLOTS=$(curl -sf http://llama-server:8080/slots) || continue

  for slot in 0 1; do
    id_task=$(echo "$SLOTS" | jq -r ".[$slot].id_task")
    processing=$(echo "$SLOTS" | jq -r ".[$slot].is_processing")

    [ "$id_task" = "0" ] || [ "$processing" = "false" ] && continue

    state=/tmp/slot_cleaner_prev_${slot}
    prev=0
    [ -f "$state" ] && prev=$(cat "$state")

    if [ "$prev" = "$id_task" ]; then
      curl -s -X POST "http://llama-server:8080/slots/$slot?action=erase" \
        -H "Content-Length: 0" -o /dev/null
      echo "[$(date)] slot $slot: erased stuck task $id_task"
      rm -f "$state"
    else
      echo "$id_task" > "$state"
    fi
  done
done