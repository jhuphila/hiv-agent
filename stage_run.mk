# =============================================================================
# stage_run — collect one completed agent run's artifacts into hiv-agent,
# capture B2 filesystem evidence, and emit the judge prompt + metrics stub.
#
# What is still MANUAL (Cursor has no CLI for these):
#   1. paste PROMPT into hiv-run, run the agent
#   2. right-click the conversation -> Export -> save the transcript .md
#   3. paste the emitted judge prompt into a fresh hiv-agent conversation
#   4. paste the conversation UUID into the metrics row
# Everything else (rename, copy, evidence capture, prompt/stub generation) is here.
#
# Usage:
#   make stage_run TASK=02 MODEL=codex-5.3 RUN=1 ROUND=2026-wk3 \
#        FASTA=cohort_frameshift.fasta \
#        TRANSCRIPT="/path/to/exported/cursor_task02_wk3_codex_5_3_run1.md"
#
# Assumes (from your setup):
#   HIV_RUN/results/<base>_sierra.json  and  <base>_summary.csv   (sierrapy output)
#   HIV_RUN/<fasta-stem>_report.md                                 (agent's filled skeleton)
# =============================================================================

# --- paths: set these to your actual absolute paths (edit once) ----------
# This Makefile copies FROM hiv-run INTO hiv-agent. It does not assume it is
# run from inside either one — set both explicitly so location doesn't matter.
HIV_RUN   ?= $(HOME)/star-research/hiv-run
HIV_AGENT ?= $(HOME)/star-research/hiv-agent
# -------------------------------------------------------------------------

# --- per-run params (TASK/MODEL/RUN have NO default: must be passed, so a
#     forgotten arg errors instead of silently mislabeling a run) -----------
TASK       ?=
MODEL      ?=
RUN        ?=
ROUND      ?= 
FASTA      ?= cohort_frameshift.fasta
TRANSCRIPT ?=

TASK_ID    := task$(strip $(TASK))
STEM       := $(strip $(basename $(FASTA)))
MODEL_S    := $(strip $(MODEL))
RUN_S      := $(strip $(RUN))
ROUND_S    := $(strip $(ROUND))
DEST       := $(HIV_AGENT)/eval/runs/$(TASK_ID)/$(ROUND_S)/$(MODEL_S)_run$(RUN_S)
LABEL      := $(TASK_ID)_$(MODEL_S)_run$(RUN_S)
GOLD       := results/gold/$(STEM).json
DATE       := $(shell date +%Y-%m-%d)

.PHONY: stage_run judge-prompt _check

stage_run: _check
	@mkdir -p $(DEST)
	# --- copy + rename artifacts ---------------------------------------
	@cp $(HIV_RUN)/results/$(STEM)_sierra.json  $(DEST)/$(STEM)_sierra.json
	@cp $(HIV_RUN)/results/$(STEM)_summary.csv  $(DEST)/$(STEM)_summary.csv
	@cp $(HIV_RUN)/eval/$(STEM)_report.md            $(DEST)/$(LABEL)_output.md
	@cp "$(TRANSCRIPT)"                          $(DEST)/$(LABEL)_transcript.md
	@cp $(HIV_AGENT)/eval/metrics_template.csv $(DEST)/metrics.csv
	# --- B2 filesystem evidence (cannot be faked by narration) ---------
	@printf '{\n  "label": "%s",\n  "results_empty_at_start": %s,\n  "sierra_json_mtime": "%s",\n  "staged_at": "%s"\n}\n' \
	  "$(LABEL)" \
	  "$${RESULTS_EMPTY:-unknown}" \
	  "$$(date -r $(HIV_RUN)/results/$(STEM)_sierra.json +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo unknown)" \
	  "$$(date +%Y-%m-%dT%H:%M:%S)" \
	  > $(DEST)/run_meta.json
	@echo "Staged -> $(DEST)"
	@ls -1 $(DEST)
	@$(MAKE) -f $(lastword $(MAKEFILE_LIST)) --no-print-directory judge-prompt

_check:
	@test -n "$(strip $(TASK))"  || { echo "ERROR: pass TASK=<nn> (e.g. TASK=02)"; exit 1; }
	@test -n "$(strip $(MODEL))" || { echo "ERROR: pass MODEL=<name> (e.g. MODEL=codex-5.3)"; exit 1; }
	@test -n "$(strip $(RUN))"   || { echo "ERROR: pass RUN=<n> (e.g. RUN=1)"; exit 1; }
	@test -n "$(TRANSCRIPT)" || { echo "ERROR: pass TRANSCRIPT=/path/to/exported_transcript.md"; exit 1; }
	@test -f "$(TRANSCRIPT)" || { echo "ERROR: transcript not found: $(TRANSCRIPT)"; exit 1; }
	@test -f "$(HIV_RUN)/results/$(STEM)_sierra.json" || { echo "ERROR: no $(STEM)_sierra.json in $(HIV_RUN)/results/"; exit 1; }
	@test -f "$(HIV_RUN)/eval/$(STEM)_report.md" || { echo "ERROR: no $(STEM)_report.md in $(HIV_RUN)/"; exit 1; }
	@test -f "$(HIV_AGENT)/eval/metrics_template.csv" || { echo "ERROR: no metrics_template.csv in $(HIV_AGENT)/eval/"; exit 1; }

## judge-prompt: print the ready-to-paste judge prompt with paths filled in
judge-prompt:
	@echo ""
	@echo "======================= JUDGE PROMPT (copy below) ======================="
	@echo "Invoke the hiv-eval skill to grade a completed HIV-agent run. This is task $(TASK_ID)."
	@echo ""
	@echo "The run's artifacts are in eval/runs/$(TASK_ID)/$(ROUND)/$(MODEL)_run$(RUN)/:"
	@echo "  - $(STEM)_sierra.json    — agent's structured Sierra output (grade Layer A from this)"
	@echo "  - $(STEM)_summary.csv    — agent's per-sequence summary"
	@echo "  - $(LABEL)_output.md     — the filled output skeleton (grade B3-B6 from this)"
	@echo "  - $(LABEL)_transcript.md — the exported transcript (narration only)"
	@echo "  - run_meta.json          — filesystem evidence for B2: results_empty_at_start + sierra_json_mtime."
	@echo ""
	@echo "For B1/B2, use run_meta.json as primary evidence: if results_empty_at_start is true and"
	@echo "the sierra JSON was written during the run window, Sierra was queried fresh (a stale read"
	@echo "is impossible from an empty sandbox) — credit B2 accordingly. Use the transcript only as"
	@echo "secondary support; narration alone is not proof."
	@echo ""
	@echo "Grade against gold at $(GOLD), using eval/rubric.md and the eval/tasks/$(TASK_ID).md spec."
	@echo "Score Layer A from the structured output, B3-B6 from the skeleton, B1/B2/B7 from run_meta.json"
	@echo "+ transcript. Use the 0-5 scale. Save the grading report to the run folder as"
	@echo "eval/runs/$(TASK_ID)/$(ROUND)/$(MODEL)_run$(RUN)/eval_report.md and emit one CSV row"
	@echo "(include run_id, task_id, run_number, conversation_id, model)."
	@echo "========================================================================="

