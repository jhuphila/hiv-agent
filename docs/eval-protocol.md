# HIV Agent Evaluation Protocol

This is the human-driven procedure for running one evaluation round. Because the
analysis agent runs interactively in Cursor (Agent mode), the round is **not** a
single scriptable `make` target — it is a documented sequence a person carries out.
An API-based automation arm would be required to make this fully scriptable; until
then, this protocol is the source of truth.

## Prerequisites
- `hiv-agent` conda env installed (`make install`).
- Gold answer keys built for every FASTA under test (`make gold`).
- The task suite present under `eval/tasks/`, each task with an ID and a matching
  gold file named in its spec.

## One evaluation round

### 1. Pick the configuration under test
Record, before running anything:
- Which model is driving the analysis agent.
- Which prompt structure / skill configuration is being tested (this is the
  independent variable for the round).
- Which task IDs from `eval/tasks/` are in scope for this round.

### 2. Clear stale outputs (anti-shortcut)
Archive or remove prior `results/` analysis outputs so the agent is forced to query
Sierra fresh rather than reading a previous run's files. Do **not** touch
`results/gold/` — that is the answer key, not an analysis output.

### 3. Run the analysis agent (Agent mode)
For each in-scope task:
- Start the prompt with the task ID (e.g. "Task 03: ...") so the judge can later
  identify it unambiguously.
- Let the agent complete the task and produce its filled-in output skeleton
  (see `eval/output_skeleton.md`).
- Do not coach the agent past the task prompt — improvisation is data.

### 4. Switch to the judge (same window)
- Switch the model in the same Cursor window.
- Invoke the `hiv-eval` skill: e.g. "Evaluate this analysis against gold."
- The judge loads the task spec + gold, applies the rubric, and emits a grading
  report plus a one-row CSV summary.

### 5. Record results
- Paste the judge's one-row summary into the round's metrics CSV
  (`eval/runs/<round>/metrics.csv`, schema in `eval/metrics_schema.md`).
- Save the agent's raw output and the judge's full report under
  `eval/runs/<round>/`.
- Spot-check the judge: for at least one task per round, a human re-grades against
  gold to check the judge is not drifting. LLM judges can carry bias and must be
  validated, not trusted blindly.

### 6. Repeat across configurations
To answer the research question, hold the task suite fixed and vary one factor at a
time (prompt structure, skill config, model). Each (configuration × task) cell is one
recorded run.

## Notes
- Factual ground truth is always `results/gold/` (sierra-direct), never the wrapper
  script's output. `pipeline-gold` is a regression check only.
- Outcome (factual) and process (behavioral) scores are kept separate; do not collapse
  them into a single number.
- The Section-7 / provenance sub-experiment (running tasks with and without the
  provenance prompt) is an optional controlled comparison on a subset of tasks, not a
  default part of every round.