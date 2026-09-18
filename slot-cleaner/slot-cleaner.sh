#!/bin/sh

# slot-cleaner: erase a llama-server slot whose generation has wedged.
#
# Supports two /slots payload schemas, selected by the SLOT_SCHEMA env var:
#   auto      detect from the first non-empty payload (default)
#   ik        ik-llama fork: no is_processing field; `state` is 0 when idle and
#             non-zero while busy; a finished task leaves a stale id_task behind
#   upstream  stock llama.cpp: `is_processing` boolean is authoritative; `state`
#             may be absent in newer builds; next_token is an array; idle slots
#             report id_task -1
#
# A slot is erased only when it is busy AND generating (has_next_token=true)
# AND its (id_task, n_decoded) pair has not moved for STUCK_CYCLES polls.
#
# Library mode (SLOT_CLEANER_LIB=1) defines the functions and returns so
# test-slot-cleaner.sh can exercise the decision logic without a server.

SLOT_SCHEMA="${SLOT_SCHEMA:-auto}"
STUCK_CYCLES="${STUCK_CYCLES:-3}"
INTERVAL="${INTERVAL:-30}"
SCHEMA=""

detect_schema() {
  case "$(printf '%s' "$1" | jq -r 'length' 2>/dev/null)" in
    ""|0) echo "" ;;
    *)
      if printf '%s' "$1" | jq -e 'any(.[]; has("is_processing"))' >/dev/null 2>&1; then
        echo upstream
      else
        echo ik
      fi
      ;;
  esac
}

erase_slot() {
  curl -s -X POST "http://llama-server:8080/slots/$1?action=erase" \
    -H "Content-Length: 0" -o /dev/null
}

slot_is_busy() {
  # $1 = state, $2 = is_processing
  case "$SCHEMA" in
    upstream)
      [ "$2" = "true" ] && return 0
      [ -n "$1" ] && [ "$1" != "0" ] && return 0
      return 1
      ;;
    *)
      [ -n "$1" ] && [ "$1" != "0" ] && return 0
      return 1
      ;;
  esac
}

process_slots() {
  # Normalize every reported slot to one TSV row:
  #   slot  id_task  state  is_processing  has_next_token  n_decoded
  # next_token is an object in the ik fork and an array in upstream; unwrap both.
  printf '%s' "$1" | jq -r '
    to_entries[] |
    .key as $slot |
    .value as $v |
    ($v.next_token | if type == "array" then (.[0] // {}) else (. // {}) end) as $nt |
    [
      $slot,
      ($v.id_task // ""),
      ($v.state // ""),
      ($v.is_processing // ""),
      ($nt.has_next_token // ""),
      ($nt.n_decoded // "")
    ] | join("|")
  ' | while IFS='|' read -r slot id_task state is_proc has_next n_decoded; do
    state_file=/tmp/slot_cleaner_prev_${slot}

    # Busy detection is schema-specific; skip idle slots entirely.
    if ! slot_is_busy "$state" "$is_proc"; then
      rm -f "$state_file"
      continue
    fi

    # id_task is identity only, never a busy signal: the ik fork leaves a stale
    # id after a task finishes, while upstream parks idle slots at -1.
    if [ -z "$id_task" ] || [ "$id_task" = "0" ] || [ "$id_task" = "-1" ]; then
      rm -f "$state_file"
      continue
    fi

    # Only generation wedges are actionable: during prompt evaluation
    # has_next_token is false and a long prompt must not be erased.
    if [ "$has_next" != "true" ]; then
      rm -f "$state_file"
      continue
    fi

    prev_id=""
    prev_dec=""
    prev_count=0
    if [ -f "$state_file" ]; then
      read -r prev_id prev_dec prev_count < "$state_file" 2>/dev/null || true
    fi
    case "$prev_count" in
      ''|*[!0-9]*) prev_count=0 ;;
    esac

    if [ "$prev_id" = "$id_task" ] && [ "$prev_dec" = "$n_decoded" ]; then
      prev_count=$((prev_count + 1))
    else
      prev_count=0
    fi

    if [ "$prev_count" -ge "$STUCK_CYCLES" ]; then
      erase_slot "$slot"
      echo "[$(date)] slot $slot: erased stuck task $id_task (n_decoded=$n_decoded frozen ${prev_count}x)"
      rm -f "$state_file"
    else
      echo "$id_task $n_decoded $prev_count" > "$state_file"
    fi
  done
}

# Test/library mode: define functions, do not run the loop.
if [ "${SLOT_CLEANER_LIB:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

apk add --no-cache curl jq >/dev/null 2>&1

case "$SLOT_SCHEMA" in
  ik|upstream) SCHEMA="$SLOT_SCHEMA" ;;
esac

echo "slot-cleaner started (interval: ${INTERVAL}s, schema: ${SLOT_SCHEMA})"

LOGGED_SCHEMA=""
while sleep "$INTERVAL"; do
  touch /tmp/slot-cleaner-heartbeat
  SLOTS=$(curl -sf http://llama-server:8080/slots) || continue

  # In auto mode, (re)detect on every non-empty payload so the cleaner follows
  # the server if it is swapped for one using the other schema.
  if [ "$SLOT_SCHEMA" = "auto" ]; then
    detected=$(detect_schema "$SLOTS")
    [ -n "$detected" ] && SCHEMA="$detected"
  fi
  # Without a schema we cannot tell busy from idle: never erase.
  [ -n "$SCHEMA" ] || continue

  if [ "$SCHEMA" != "$LOGGED_SCHEMA" ]; then
    echo "[$(date)] slot schema: $SCHEMA"
    LOGGED_SCHEMA="$SCHEMA"
  fi

  process_slots "$SLOTS"
done