---
name: hiv-eval
description: >-
  Judge a completed HIV drug-resistance analysis run against sierra-direct gold,
  using the run's exported artifacts (filled skeleton, structured JSON/CSV, and
  chat transcript) collected in eval/runs/. Grades factual accuracy (mutations,
  resistance, subtype) and behavior (constraint adherence, faithfulness, summary
  quality, provenance, scope) on a 0-5 scale, after an unscored tool-execution
  validity gate. Use when the user says evaluate this run, grade the
  agent, judge this HIV resistance analysis, score against gold, or invokes
  hiv-eval for a run folder.
disable-model-invocation: true
---

# HIV Eval Judge

Act as a **Judge** grading a **completed** agent analysis run. The analysis agent ran
in a separate, isolated workspace; its artifacts were exported into a run folder under
`eval/runs/<task_id>/<round>/<model>_run<n>/`. You grade those exported artifacts — you are
**not** grading an agent that ran earlier in this conversation.

> **`eval/rubric.md` is the single source of truth for what the criteria mean** — the 0-5
> anchors, the A/B criteria definitions, the entailment rule for B4, the validity gate, and
> the adherence taxonomy all live there. **Read it before scoring.** This skill tells you
> *how to run a grading*: which artifact feeds which criterion, where files are, what order
> to work in, and what to emit. It deliberately does not restate the rubric — if this file
> and the rubric ever disagree, the rubric wins.

## Judge humility

You are an **assistant to human grading**, not a replacement. Your scores should be
spot-checked by a human. LLM judges can carry bias — state limitations when uncertain.
Do not invent a `make` target for running the judge; evaluation is a human-driven
procedure documented in `docs/eval-protocol.md`.

## Ground truth

- **Sole factual ground truth:** `results/gold/<name>.json` (from `make gold` →
  `sierrapy fasta` directly — **not** `translate_and_query.py`).
- **Never use** `results/pipeline-gold/` as the evaluation answer key (regression
  reference only).
- **Never re-derive** mutations, positions, resistance levels, or subtypes by hand.
  Read them only from the gold JSON and from the agent's exported output artifacts.

## Run artifacts → where to look

The run folder `eval/runs/<task_id>/<round>/<model>_run<n>/` contains:

| Artifact | Primary evidence for |
|----------|----------------------|
| `*_sierra.json` — agent's structured Sierra output | **Layer A** (A1–A5), vs. gold |
| `*_summary.csv` — agent's per-sequence summary | Layer A support / cross-check |
| `<label>_output.md` — the filled output skeleton (prose + tables) | **B2, B3, B4, B5, B6, B8** |
| `<label>_transcript.md` — the exported chat transcript | **B4, B7, B8** — and anything the agent produced outside the skeleton |
| `run_meta.json` — `results_empty_at_start`, `sierra_json_mtime` | **Unscored** validity gate |

**The table says where evidence usually lives — it is not a restriction.** Grade the
agent's **complete output**, considering every artifact together.

**This matters especially for B4, B5, B6, and B8.** The output skeleton has a fixed shape
(tables in Sections 2–5, a short summary in Section 6, provenance in Section 7). When a task
prompt asks for something the skeleton has no slot for — e.g. a clinical recommendation, an
interpretation, an extended explanation — **the agent will often answer in the chat instead,
where only the transcript captures it.** A faithful-looking Section 6 does not exempt an
agent from unsupported claims it made in the transcript. Read both. If the skeleton is clean
but the transcript contains out-of-domain claims, B4 is scored on the claims.

**Two rules that remain firm:**

1. **Layer A is graded from the *structured* output (`*_sierra.json`) vs. gold — never from
   prose.** If prose and structured output disagree, that is a **B4** problem, not a Layer A
   adjustment.
2. **Record which artifact(s) drove each score** in the report's `Source` column, so a human
   can trace any score back to its evidence. If a score was driven by the transcript rather
   than the skeleton, say so explicitly.

## Reference files

| File | Purpose |
|------|---------|
| `eval/rubric.md` | **Authoritative**: criteria, 0-5 anchors, B4 entailment rule, validity gate, taxonomy |
| `eval/tasks/<id>.md` | Per-task instructions, applicable criteria, instance-specific success criteria |
| `results/gold/<name>.json` | Factual answer key named in the task spec |
| `eval/output_skeleton.md` | Template the analyzed agent was asked to fill |
| `eval/metrics_template.csv` | CSV headers / column order for the one-row summary |
| `eval/metrics_schema.md` | Column definitions for the metrics CSV |
| `docs/eval-protocol.md` | Human-driven evaluation round procedure |

## Workflow

```
1. Get task ID (from the judge prompt / run folder name)
2. Confirm eval/tasks/<id>.md exists — if not, STOP (do not judge)
3. Read eval/rubric.md (authoritative), then the task spec; load the gold JSON it names
4. Read the run folder's artifacts (structured json/csv, filled skeleton, transcript, run_meta)
5. Check the tool-execution validity gate FIRST — if `no`, the run is invalid: STOP
6. Score Layer A (structured output vs. gold) and Layer B separately, per rubric anchors
7. Assign one adherence taxonomy tag
8. Write eval_report.md and append the CSV row -- both INTO the run folder
```

### Step 1 — Task identification (required)

The task ID comes from the judge prompt and/or the run folder name (e.g.
`eval/runs/task02/2026-wk3/opus-4.8_run1` → `task02`). The task ID is deliberately **not**
present in the analysis agent's prompt (that would let the agent read its own spec), so do
not expect to find it in the agent's instructions.

1. Read the task ID from the judge prompt or run folder path.
2. Confirm `eval/tasks/<id>.md` exists on disk.
3. Open it for instructions, applicable criteria, and instance-specific success criteria.
4. Use the gold file it names as the factual answer key.

**Do not judge without a task spec.** If you cannot proceed:

- **No task ID given** — say you could not determine the task ID and cannot grade. Do not
  guess or infer a task silently.
- **`eval/tasks/<id>.md` missing** — say there is no task criteria/instruction for you to
  judge. Do **not** produce scores, a report, or a CSV row.

Stop after that message — do not fall back to rubric-only or gold-only grading.

### Step 2 — Rubric + per-task layer

`eval/rubric.md` always applies and is authoritative. The per-task spec **refines** it:
which conditional criteria apply, the specific DRMs / subtypes / levels expected, expected
edge-case behavior and taxonomy tag, and what "complete" means for that task.

Factual scoring is always driven by the **gold JSON**, not by hand-written answers in the
spec — the spec sharpens and contextualizes; it does not replace gold.

### Step 3 — Validity gate (do this FIRST, before any scoring)

Confirm the run actually executed the pipeline. This is a **precondition**, not a criterion
(the rubric defines it fully). Evidence:

- **Structured-output fidelity** — is `*_sierra.json` genuine Sierra output? A high-fidelity
  match to gold on mutation keys and drug-score records proves execution; a model cannot
  hallucinate thousands of exact mutation keys. (Evidence of *execution* only — Layer A still
  scores the quality of that match.)
- **`run_meta.json`** — `results_empty_at_start` (nothing to reuse) and `sierra_json_mtime`
  (written during the run window).

Report `tool_execution_verified` as **`yes`** / **`no`** / **`unverified`**.
If **`no`**: the run is **invalid** — say so, emit no scores and no CSV row, and stop.
Never convert this gate into a 0-5 score.

### Step 4 — Scoring notes specific to running a grading

- Score every criterion against the anchors in `eval/rubric.md`. Do not grade on gut feel.
- Mark conditional criteria **N/A** per the task spec — never 0. (Rubric explains why.)
- **B4** grades *entailment*, not literal restatement — see the rubric's entailment note
  before scoring any prose. Record borderline phrasing **verbatim** in the judge notes.
- **B6** grades communication *of gold-supported findings*. A well-written out-of-domain
  clinical claim is penalized under B4 and **never rewarded** under B6.
- **Grade the agent's complete response, not just the skeleton.** Check the transcript for
  content the skeleton had no slot for — clinical recommendations, interpretations, answers to
  parts of the task prompt the skeleton does not cover. These are part of what the agent
  produced and are graded under B4 (faithfulness), B5 (completeness), B6 (communication), and
  B8 (scope) exactly as if they had appeared in the skeleton.
- Keep Layer A and Layer B separate. Never collapse them into one number.

## Reading gold JSON

Gold files are `sierrapy fasta` output: a JSON array of per-sequence records. Extract facts
programmatically (jq, Python, or a structured read) — do not eyeball.

Per sequence record (`inputSequence.header` = sequence ID):

| Fact | Gold path |
|------|-----------|
| Subtype | `subtypeText` (compare the primary token, e.g. `A1` from `A1 (4.82%)`) |
| Validation issues | `validationResults[]` — surface every message |
| Mutations | `alignedGeneSequences[].gene.name` + `mutations[]` → key `(seq_id, gene, position, text)`, e.g. `I13V` |
| Resistance | `drugResistance[].drugScores[]` → `(seq_id, gene, drug.name, level, text)` |

For **A1**, compute set precision/recall on mutation keys (agent's `*_sierra.json` vs. gold).
For **A2**, count mutations the agent reported that are **absent** from gold (fabrication
count) — the key fabrication metric.

## Output — structured grading report

**Write this to `<run_folder>/eval_report.md`** — i.e. into the same run folder you graded
(`eval/runs/<task_id>/<round>/<model>_run<n>/eval_report.md`). Do not only print it to the
conversation; the report is a run artifact and must persist alongside the run's other files.

Emit it only when `eval/tasks/<id>.md` exists and grading proceeds (and the validity gate did
not return `no`).

```markdown
# HIV Eval Report — <task_id>

## Task identification
- Task ID: <id>
- Run folder: eval/runs/<task_id>/<round>/<model>_run<n>/
- Gold file: results/gold/<name>.json
- FASTA / input: <from task spec>

## Tool-execution validity gate (unscored)
- tool_execution_verified: <yes | no | unverified>
- Evidence: <structured-output fidelity; run_meta results_empty_at_start / mtime>

## Layer A — Outcome / Factual (from structured output vs. gold)
| Criterion | Score (0-5) | Notes |
|-----------|-------------|-------|
| A1 Mutations | | precision=…, recall=… |
| A2 Fabrications | | fabrication count=… |
| A3 Resistance | | |
| A4 Subtype | | or NA |
| A5 Validation | | or NA |

## Layer B — Process / Behavioral
*Source = which artifact(s) actually drove this score (skeleton / transcript / both / sierra.json).
State the real basis, not the default — if the transcript drove it, say transcript.*

| Criterion | Score (0-5) | Source | Notes |
|-----------|-------------|--------|-------|
| B2 Constraint adherence | | | honored stated constraints? |
| B3 Skeleton | | | |
| B4 Faithfulness | | | entailed vs out-of-domain; quote borderline phrasing; note if claim was made outside the skeleton |
| B5 Completeness | | | |
| B6 Communication | | | |
| B7 Provenance | | | |
| B8 Scope discipline | | | stayed in scope? |

## Adherence taxonomy
- Observed: <tag>
- Expected (per task spec): <tag or n/a>

## Cost
- <figure + source, or "not reported">

## Evidence summary
- Key matches / mismatches / fabrications (cite gold vs. agent)
- Validity gate outcome + evidence
- B2 constraint adherence and B8 scope findings (or N/A)
- Any borderline B4 phrasing, quoted verbatim
- Any substantive content the agent produced OUTSIDE the skeleton (in the transcript), and how it was scored

## Judge notes
- Uncertainties, spot-check recommendations for the human grader
```

## Output — one-row CSV summary

**Write this row into `<run_folder>/metrics.csv`** (staging pre-copies
`eval/metrics_template.csv` there, so append your row beneath the existing header and delete
the example row if present).

Match the template's header and **column order exactly**; column definitions are in
`eval/metrics_schema.md`. Use `NA` for conditional criteria that did not apply. Include the
identifier columns (`run_id`, `task_id`, `run_number`, `conversation_id`, `model`,
`skill_version`) so runs can be grouped and joined to cost data. `conversation_id` may be
unavailable from the artifacts — leave it `NA` and note that the human must fill it in.
Never average Layer A and Layer B into a single grade.

## Quick checklist

- [ ] Task ID obtained from judge prompt / run folder name
- [ ] `eval/tasks/<id>.md` exists (if not — stop; no report, no CSV row)
- [ ] `eval/rubric.md` read (authoritative for anchors, entailment rule, gate, taxonomy)
- [ ] Gold JSON loaded; facts extracted programmatically, not hand-derived
- [ ] Run artifacts read: structured json/csv, filled skeleton, transcript, run_meta
- [ ] Validity gate checked FIRST; if `no`, run invalid — stopped
- [ ] A1 precision/recall and A2 fabrication count reported
- [ ] Agent's COMPLETE response read — skeleton AND transcript (content outside the skeleton is still graded)
- [ ] Each criterion graded against rubric anchors; `Source` records which artifact actually drove it
- [ ] Conditional criteria = NA (not 0)
- [ ] Borderline B4 phrasing quoted verbatim in judge notes
- [ ] Layers A and B reported separately
- [ ] Adherence tag assigned
- [ ] `eval_report.md` written INTO the run folder (not just printed to chat)
- [ ] CSV row appended to the run folder's `metrics.csv`, matching template column order