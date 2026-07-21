#!/usr/bin/env bash
# stage.sh — interactive front-end for stage_run.mk
#
# Instead of typing the giant one-liner, run:  ./stage.sh
# It asks you each field, remembers sensible defaults, confirms, then calls
# `make -f stage_run.mk stage_run ...` with everything filled in.
#
# Make it executable once:  chmod +x stage.sh

set -euo pipefail
MK="$(dirname "$0")/stage_run.mk"

# ---- helper: prompt with a default -----------------------------------------
ask() {   # ask VAR "Question" "default"
  local __var="$1" __q="$2" __def="${3:-}"
  local __ans
  if [[ -n "$__def" ]]; then
    read -rp "$__q [$__def]: " __ans
    __ans="${__ans:-$__def}"
  else
    read -rp "$__q: " __ans
  fi
  printf -v "$__var" '%s' "$__ans"
}

echo "=== stage a completed agent run ==="

# ---- which sandbox? --------------------------------------------------------
# 1 = hiv-run (default), 2 = hiv-run-2 — lets you run two models in parallel
# from two Cursor windows without their staging colliding.
read -rp "Which sandbox? [1=hiv-run (default), 2=hiv-run-2]: " SANDBOX_CHOICE
case "${SANDBOX_CHOICE:-1}" in
  2) HIV_RUN_DIR="$HOME/star-research/hiv-run-2" ;;
  1|"") HIV_RUN_DIR="$HOME/star-research/hiv-run" ;;
  *) echo "Unrecognized choice '$SANDBOX_CHOICE' — expected 1 or 2."; exit 1 ;;
esac
echo "Using sandbox: $HIV_RUN_DIR"
echo ""

ask TASK  "What task number? (e.g. 02)"
ask MODEL "Which model? (e.g. fable-5, opus-4.8, gpt-5.5)"
ask RUN   "Which run number?" "1"
ask ROUND "Which round?" "2026-wk3"
ask FASTA "FASTA file?" "cohort_frameshift.fasta"

# Transcript: offer a directory default so you only type the filename.
TRANSCRIPT_DIR_DEFAULT="/mnt/c/Users/jhuph/OneDrive/Documents/STAR-PROGRAM/transcripts"
ask TRANSCRIPT_DIR "Transcript folder?" "$TRANSCRIPT_DIR_DEFAULT"
ask TRANSCRIPT_FILE "Transcript filename? (just the .md name)"
TRANSCRIPT="$TRANSCRIPT_DIR/$TRANSCRIPT_FILE"

# results_empty_at_start: this is the B-integrity evidence. Ask explicitly.
ask EMPTY "Was $HIV_RUN_DIR/results/ empty before this run? (true/false)" "true"

echo ""
echo "About to stage:"
echo "  SANDBOX=$HIV_RUN_DIR"
echo "  TASK=$TASK  MODEL=$MODEL  RUN=$RUN  ROUND=$ROUND"
echo "  FASTA=$FASTA"
echo "  TRANSCRIPT=$TRANSCRIPT"
echo "  RESULTS_EMPTY=$EMPTY"
read -rp "Proceed? [y/N]: " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || { echo "aborted."; exit 1; }

RESULTS_EMPTY="$EMPTY" make -f "$MK" stage_run \
  HIV_RUN="$HIV_RUN_DIR" \
  TASK="$TASK" MODEL="$MODEL" RUN="$RUN" ROUND="$ROUND" \
  FASTA="$FASTA" TRANSCRIPT="$TRANSCRIPT"