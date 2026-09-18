#!/bin/sh
# Exercises the slot-cleaner decision logic (sourced from slot-cleaner.sh in
# library mode) against ik-fork and upstream-shaped /slots payloads.
set -u
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
rm -f /tmp/slot_cleaner_prev_*
ERASE_LOG=$(mktemp)
STUCK_CYCLES=3
SLOT_SCHEMA=auto
SLOT_CLEANER_LIB=1 . "$DIR/slot-cleaner.sh"

erase_slot() { echo "$1" >> "$ERASE_LOG"; }

reset() { rm -f /tmp/slot_cleaner_prev_*; ERASES_BEFORE=$(wc -l < "$ERASE_LOG"); }
erasures() { echo $(( $(wc -l < "$ERASE_LOG") - ${1:-0} )); }

case_name() { echo "== $1 =="; }

# --- ik fork -------------------------------------------------------------

case_name "ik: stale id_task, state 0 (the original bug) — 4 cycles"
reset; SCHEMA=ik
for i in 1 2 3 4; do
  process_slots '[{"id_task":1164,"state":0,"next_token":{"has_next_token":false,"n_decoded":332}}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 0)"

case_name "ik: frozen generation, state 1 — 5 cycles"
reset; SCHEMA=ik
for i in 1 2 3 4 5; do
  process_slots '[{"id_task":2000,"state":1,"next_token":{"has_next_token":true,"n_decoded":100}}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 1)"

case_name "ik: progressing generation — 4 cycles"
reset; SCHEMA=ik
for n in 100 150 220 300; do
  process_slots "[{\"id_task\":2001,\"state\":1,\"next_token\":{\"has_next_token\":true,\"n_decoded\":$n}}]"
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 0)"

case_name "ik: prompt evaluation (has_next false) — 4 cycles"
reset; SCHEMA=ik
for i in 1 2 3 4; do
  process_slots '[{"id_task":2002,"state":1,"next_token":{"has_next_token":false,"n_decoded":0}}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 0)"

case_name "ik: single-slot idle (phantom slot 1 must never be touched)"
reset; SCHEMA=ik
for i in 1 2 3; do
  process_slots '[{"id_task":0,"state":0,"next_token":{"has_next_token":false,"n_decoded":0}}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 0)"

# --- upstream ------------------------------------------------------------

case_name "upstream: is_processing true + next_token object, frozen — 5 cycles"
reset; SCHEMA=upstream
for i in 1 2 3 4 5; do
  process_slots '[{"id":0,"id_task":7,"state":1,"is_processing":true,"next_token":{"has_next_token":true,"n_decoded":50}}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 1)"

case_name "upstream: idle (is_processing false, id_task -1) — 4 cycles"
reset; SCHEMA=upstream
for i in 1 2 3 4; do
  process_slots '[{"id":0,"id_task":-1,"state":0,"is_processing":false,"next_token":{"has_next_token":false,"n_decoded":0}}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 0)"

case_name "upstream: next_token as ARRAY, frozen — 5 cycles"
reset; SCHEMA=upstream
for i in 1 2 3 4 5; do
  process_slots '[{"id":0,"id_task":9,"state":1,"is_processing":true,"next_token":[{"has_next_token":true,"n_decoded":77}]}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 1)"

case_name "upstream: is_processing true but state absent, frozen — 5 cycles"
reset; SCHEMA=upstream
for i in 1 2 3 4 5; do
  process_slots '[{"id":0,"id_task":11,"is_processing":true,"next_token":[{"has_next_token":true,"n_decoded":12}]}]'
done
echo "  erases: $(erasures "$ERASES_BEFORE") (expected 1)"

# --- auto detection ------------------------------------------------------

case_name "auto: detect_schema"
a=$(detect_schema '[{"id_task":1,"state":1,"next_token":{"has_next_token":true}}]')
b=$(detect_schema '[{"id_task":-1,"is_processing":false,"next_token":[]}]')
c=$(detect_schema '[]')
d=$(detect_schema '[{"id":0,"id_task":-1,"is_processing":false,"next_token":{}}]')
echo "  no is_processing -> '$a' (expected ik)"
echo "  is_processing    -> '$b' (expected upstream)"
echo "  empty array      -> '$c' (expected empty)"
echo "  idle upstream    -> '$d' (expected upstream)"

echo
echo "remaining erase log:"
cat "$ERASE_LOG"
rm -f "$ERASE_LOG" /tmp/slot_cleaner_prev_*