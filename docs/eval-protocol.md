# HIV Agent Evaluation Protocol

This is the human-driven procedure for running one evaluation round. Because the analysis agent runs interactively in Cursor (Agent mode), the round is **not** a single scriptable `make` target — it is a documented sequence a person carries out as of right now. An API-based automation arm would be required to make this fully scriptable; until then, this protocol is the source of truth.

## Key design decisions (as of 7/6/26)

Two properties of this protocol exist to prevent contamination we observed in early runs. Do not "simplify" them away:

1. **The analysis agent runs in an isolated sandbox, not in** `hiv-agent`**.** The agent is given a clean working directory (`hiv-run`, outside the `hiv-agent` tree) that contains ONLY what the task legitimately needs. It must NOT be able to see the rubric, the task spec, the gold answer key, or prior runs — the agent reading any of these invalidates the behavioral scores (it has seen the answer key to its own test). This was observed directly: an agent read `eval/tasks/task02_frameshift.md` and its "expected behavior" notes.
2. **The agent prompt does NOT contain the task ID.** Prefixing the prompt with "Task 02: ..." caused the agent to locate and read the matching spec file. The task ID is a grading-side label only — it is given to the JUDGE, never to the analysis agent.

## Prerequisites

- `hiv-agent` conda env installed (`make install`).
- Gold answer keys built for every FASTA under test (`make gold`).
- The task suite present under `eval/tasks/`, each task with an ID and a matching gold file named in its spec.
- The `sierrapy` skill available at project scope inside the sandbox (`.cursor/skills/sierrapy/SKILL.md`) — verify it resolves before running; a missing skill silently forces hand-translation and tanks B1.

## One evaluation round

### 1. Pick the configuration under test

Record, before running anything:

- Which model is driving the analysis agent.
- Which prompt structure / skill configuration is being tested (the independent variable for the round). Hold everything else constant.
- Which task IDs from `eval/tasks/` are in scope.
- The sierrapy skill version/snapshot used (so a mid-round skill edit does not become an uncontrolled variable).

### 2. Prepare the isolated sandbox (per run)

The sandbox (`hiv-run`, outside the `hiv-agent` tree) is stamped fresh for every run. It contains ONLY:

- `data/<fasta>` — the input FASTA for this task (not always `cohort_frameshift.fasta`; the input varies by task).
- `output_skeleton.md` — a blank copy of the template for the agent to fill.
- `.cursor/skills/sierrapy/` — the sierrapy skill (authoritative copy from hiv-agent).
- `PROMPT.txt` — the exact operational prompt (see step 3).

It must NOT contain: the rubric, any `eval/tasks/` spec, any `results/gold/` file, or any prior run's outputs. Wipe and recreate the sandbox between runs so no previous output can be read (this replaces the old "clear stale `results/`" step — isolation is a stronger anti-shortcut guarantee than clearing). A fresh sandbox starts with an empty `results/`, so the sierrapy pipeline's own `results/*.json`/`*.csv` outputs are always generated this run.

> Future change (not yet in effect): redirect the agent's sierrapy output to a dedicated `output/` folder rather than `results/`, to separate agent artifacts from the pipeline's default location. Until adopted, the sandbox's fresh `results/` is fine.

### 3. Run the analysis agent (Agent mode, in the sandbox)

- Open the sandbox (`hiv-run`) as its own Cursor workspace.
- Give the operational prompt from `PROMPT.txt`. It contains NO task ID and no filename that maps to a spec. Keep it byte-identical across every model in the round so model is the only variable.
- Let the agent complete the task and fill the output skeleton. The agent's sierrapy run also produces structured `.json` and `.csv` output.
- Do not coach the agent past the task prompt — improvisation is data.

### 4. Export run artifacts to the run folder

Collect into `eval/runs/<task_id>/<round>/<model>_run<n>/` (e.g. `eval/runs/task02/2026-wk3/opus-4.8_run1/`):

- the filled output skeleton (`<label>_output.md`),
- the agent's structured output (`*_sierra.json` and `*_summary.csv`),
- the exported chat transcript (`<label>_transcript.md`) — manually export from Cursor.

Record the Cursor **conversation UUID** for this run (title is unreliable in the tracker) alongside the artifacts, e.g. in the metrics row.

### 5. Run the judge (separate hiv-agent conversation)

- In `hiv-agent`, open a FRESH conversation (not a continuation) so token accounting stays clean and no prior judge context bleeds in.
- Fix the judge model to **GPT-5.5** for every evaluation, EXCEPT when the run being graded was itself produced by GPT-5.5 (avoid self-preference bias) — in that case note the exception and use the designated alternate.
- Paste the judge prompt template below, filling the run-specific fields. The `hiv-eval` skill supplies the grading rules, scale, and artifact→criterion mapping; the prompt only points at the run.

```
Invoke the hiv-eval skill to grade a completed HIV-agent run. This is task {{task_id}}.

The run's artifacts are in eval/runs/{{task_id}}/{{model}}_run{{n}}/:
- *_sierra.json  — agent's structured Sierra output
- *_summary.csv  — agent's per-sequence summary
- {{label}}_output.md — the filled output skeleton
- {{label}}_transcript.md — the exported transcript; use this for the B1/B2 tool-use
  and anti-shortcut checks. Do NOT rely on the agent's self-report.

Grade against gold at results/gold/{{gold_name}}.json, using eval/rubric.md and the
eval/tasks/{{task_id}}.md spec. Score Layer A from the structured output, B3-B6 from
the filled skeleton, B1/B2/B7 from the transcript. Use the 0-5 scale. Emit the grading
report as eval/runs/<..>/eval_report.md plus one CSV row including run_label, model, run_number, and conversation_id.

```

### 6. Record results

- Paste the judge's one-row summary into the round's metrics CSV (schema in `eval/metrics_schema.md`). Ensure the row carries identifier columns: `run_label`, `task`, `model`, `run_number`, `conversation_id`, `skill_version`.
- Keep the full judge report alongside the run's artifacts in its run folder.
- **Replicates:** run each (model × task) cell more than once (≥3 recommended) — agent behavior is stochastic, and a single run cannot distinguish a real score difference from noise.
- **Spot-check the judge:** for at least one run per round, a human re-grades against gold to confirm the judge is not drifting. LLM judges carry bias and must be validated, not trusted blindly.

### 7. Repeat across configurations

Hold everything fixed and vary ONE factor at a time (model, prompt structure, skill config). Each (configuration × task × replicate) is one recorded run. Batch runs by the variable under test so conditions stay constant within a comparison.

## Notes

- Factual ground truth is always `results/gold/` (sierra-direct), never the wrapper script's output. `pipeline-gold` is a regression check only.
- Outcome (factual) and process (behavioral) scores are kept separate; do not collapse them into a single number. All criteria use the 0-5 scale.
- **Cost:** the Cursor tracker's real-token fields (`input_tokens`) are sparsely populated; `tool_call_tokens_est` / `output_tokens_est` are character-derived estimates usable for RELATIVE comparison only. Absolute cost, if needed, comes from Cursor's usage view. State the cost-measurement method in any writeup.
- The Section-7 / provenance sub-experiment (running tasks with and without the provenance prompt) is an optional controlled comparison on a subset of tasks, not a default part of every round.
- The rubric-visibility experiment (whether the agent scores differently when it can vs. cannot see `rubric.md`) is a separate deliberate test. The default/control condition is rubric NOT visible to the agent — the sandbox already enforces this.

