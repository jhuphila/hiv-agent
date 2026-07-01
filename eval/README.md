# eval/

Evaluation framework for the HIV agent. This directory holds everything needed to run
and score an evaluation round; the step-by-step run procedure lives in
`../docs/eval-protocol.md`.

## What the agent is measured on

The research question concerns the accuracy, cost-efficiency, and instruction adherence
of the agent across prompt/skill configurations. Evaluation is **offline**: fixed tasks
with known answers, graded in a controlled setting. (A lightweight usability / "does it
actually work" check with lab members could be a possible later supplement, but not part of the
core offline rounds.)

## Contents


| Path                   | Purpose                                                                                                                                                                     |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `output_skeleton.md`   | The template the analysis agent fills in as its deliverable. Structured tables (factual layer) + prose summary (faithfulness layer) + provenance section (adherence layer). |
| `rubric.md`            | The general grading rubric. Two layers kept separate: **A = outcome/factual** (vs. gold), **B = process/behavioral** (tool use, adherence, faithfulness, honesty).          |
| `tasks/`               | The task suite. One file per task, each with an ID, instruction, the gold file it grades against, and any instance-specific success criteria.                               |
| `metrics_schema.md`    | Column definitions for the metrics CSV.                                                                                                                                     |
| `metrics_template.csv` | Empty CSV with headers, copied per round.                                                                                                                                   |
| `runs/`                | One subfolder per evaluation round: agent outputs, judge reports, filled metrics CSV.                                                                                       |




## Ground truth

Factual grading is always against `../results/gold/<name>.json`, produced by `make gold`
(which calls `sierrapy fasta` directly). This is independent of the wrapper script, so a
bug in `translate_and_query.py` cannot contaminate both the answer key and the agent's
output. `../results/pipeline-gold/` exists only as a regression check on the wrapper and
is **not** used as evaluation ground truth.

## How factual scoring stays per-task without a bespoke rubric per task

The general rubric supplies the *structure*; each task's **gold JSON** supplies the
*answer key*; each task's spec in `tasks/` supplies any *behavioral* success criteria
(e.g. "must surface the frameshift warning and must not fabricate downstream calls").
The judge identifies the task by the ID the human includes in the analysis prompt, loads
that task's spec + gold, and grades accordingly.

## Judge caveat

The `hiv-eval` Cursor skill applies the rubric as an **assistant to human grading**, not
a replacement. At least one task per round should be human-re-graded against gold to
catch judge drift or bias.