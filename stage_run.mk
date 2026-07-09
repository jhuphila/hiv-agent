# =============================================================================
# stage_run — collect one completed agent run's artifacts into hiv-agent,
# capture run_meta.json (unscored integrity evidence), and write the judge
# prompt to a .txt file.
#
# What is still MANUAL (Cursor has no CLI for these):
#   1. paste PROMPT into hiv-run, run the agent
#   2. right-click the conversation -> Export -> save the transcript .md
#   3. open the emitted judge_prompt.txt, copy it into a fresh hiv-agent conversation
#   4. paste the conversation UUID into the metrics row
#
# Usage:
#   make stage_run TASK=02 MODEL=codex-5.3 RUN=1 ROUND=2026-wk3 \
#        FASTA=cohort_frameshift.fasta \
#        TRANSCRIPT="/path/to/exported/transcript.md"
# =============================================================================

HIV_RUN   ?= $(HOME)/star-research/hiv-run
HIV_AGENT ?= $(HOME)/star-research/hiv-agent

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
REL_DEST   := eval/runs/$(TASK_ID)/$(ROUND_S)/$(MODEL_S)_run$(RUN_S)
LABEL      := $(TASK_ID)_$(MODEL_S)_run$(RUN_S)
GOLD       := results/gold/$(STEM).json

.PHONY: stage_run judge-prompt _check

stage_run: _check
	@mkdir -p $(DEST)
	@cp $(HIV_RUN)/results/$(STEM)_sierra.json  $(DEST)/$(STEM)_sierra.json
	@cp $(HIV_RUN)/results/$(STEM)_summary.csv  $(DEST)/$(STEM)_summary.csv
	@cp $(HIV_RUN)/eval/$(STEM)_report.md       $(DEST)/$(LABEL)_output.md
	@cp "$(TRANSCRIPT)"                          $(DEST)/$(LABEL)_transcript.md
	@cp $(HIV_AGENT)/eval/metrics_template.csv  $(DEST)/metrics.csv
	@printf '{\n  "label": "%s",\n  "results_empty_at_start": %s,\n  "sierra_json_mtime": "%s",\n  "staged_at": "%s"\n}\n' \
	  "$(LABEL)" \
	  "$${RESULTS_EMPTY:-unknown}" \
	  "$$(date -r $(HIV_RUN)/results/$(STEM)_sierra.json +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo unknown)" \
	  "$$(date +%Y-%m-%dT%H:%M:%S)" \
	  > $(DEST)/run_meta.json
	@$(MAKE) -f $(lastword $(MAKEFILE_LIST)) --no-print-directory judge-prompt
	@echo "Staged -> $(DEST)"
	@ls -1 $(DEST)
	@echo ""
	@echo "Judge prompt: $(DEST)/judge_prompt.txt"

_check:
	@test -n "$(strip $(TASK))"  || { echo "ERROR: pass TASK=<nn>"; exit 1; }
	@test -n "$(strip $(MODEL))" || { echo "ERROR: pass MODEL=<name>"; exit 1; }
	@test -n "$(strip $(RUN))"   || { echo "ERROR: pass RUN=<n>"; exit 1; }
	@test -n "$(TRANSCRIPT)" || { echo "ERROR: pass TRANSCRIPT=/path/to/transcript.md"; exit 1; }
	@test -f "$(TRANSCRIPT)" || { echo "ERROR: transcript not found: $(TRANSCRIPT)"; exit 1; }
	@test -f "$(HIV_RUN)/results/$(STEM)_sierra.json" || { echo "ERROR: no $(STEM)_sierra.json in $(HIV_RUN)/results/"; exit 1; }
	@test -f "$(HIV_RUN)/eval/$(STEM)_report.md" || { echo "ERROR: no $(STEM)_report.md in $(HIV_RUN)/eval/"; exit 1; }
	@test -f "$(HIV_AGENT)/eval/metrics_template.csv" || { echo "ERROR: no metrics_template.csv in $(HIV_AGENT)/eval/"; exit 1; }

## judge-prompt
judge-prompt:
	@mkdir -p $(DEST)
	@{ \
	echo "Use the hiv-eval skill to grade task $(TASK_ID)."; \
	echo ""; \
	echo "Run folder: $(REL_DEST)/"; \
	echo "Gold file:  $(GOLD)"; \
	echo ""; \
	echo "Write the report to $(REL_DEST)/eval_report.md and the CSV row to $(REL_DEST)/metrics.csv."; \
	} > $(DEST)/judge_prompt.txt