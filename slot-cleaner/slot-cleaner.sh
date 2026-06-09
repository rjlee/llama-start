#!/bin/sh
apk add --no-cache curl jq >/dev/null 2>&1

declare -A prev_id_task
echo "slot-cleaner started (interval: 30s)"

while sleep 30; do
  SLOTS=$(curl -sf http://llama-server:8080/slots) || continue

  for slot in 0 1; do
    id_task=$(echo "$SLOTS" | jq -r ".[$slot].id_task")
    processing=$(echo "$SLOTS" | jq -r ".[$slot].is_processing")

    [ "$id_task" = "0" ] || [ "$processing" = "false" ] && continue

    prev="${prev_id_task[$slot]:-0}"
    if [ "$prev" = "$id_task" ]; then
      curl -s -X POST "http://llama-server:8080/slots/$slot?action=erase" \
        -H "Content-Length: 0" -o /dev/null
      echo "[$(date)] slot $slot: erased stuck task $id_task"
      prev_id_task[$slot]=0
    else
      prev_id_task[$slot]=$id_task
    fi
  done
done
