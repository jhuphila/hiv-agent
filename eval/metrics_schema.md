# Metrics Schema

Data dictionary for `metrics_template.csv`. Each **row = one evaluation run** =
one (task x configuration x model x replicate) cell. The judge (hiv-eval skill) emits one
row per run; rows are collected per round under `eval/runs/<task_id>/<round>/metrics.csv` (or per
task under `eval/runs/<task_id>/`).

All scored criteria use a **0-5 Likert scale** (anchors in `eval/rubric.md`). Conditional
criteria that did not apply to a task are recorded as `NA` (not 0). Do not average across
`NA` — exclude them from subtotals. This keeps "not asked for" distinct from "asked for
and failed." **0 means applied-and-failed; NA means did-not-apply.**

## Run metadata

| Column | Type | Allowed / example | Meaning |
|--------|------|-------------------|---------|
| `run_id` | string | `task02_opus-4.8_run1` | Unique ID for the run. Suggested pattern: `<task>_<model>_run<n>`. |
| `round` | string | `2026-week3` | Evaluation round; matches the folder under `eval/runs/<task_id>/` if organized by round. |
| `task_id` | string | `task02` | Task spec in `eval/tasks/`. |
| `run_number` | int | `1` | Replicate number for this (task x config x model) cell. Multiple replicates per cell are expected. |
| `conversation_id` | string | `9f3c...` (UUID) | Cursor conversation UUID for the analysis run. Reliable join key to tracker/cost data (conversation_title is unreliable). |
| `fasta` | string | `cohort_frameshift.fasta` | Input FASTA analyzed (varies by task). |
| `gold_file` | string | `results/gold/cohort_frameshift.json` | Gold answer key used. |
| `prompt_config` | string | `minimal` \| `structured` \| `skeleton` \| ... | Prompt structure under test (independent variable). |
| `skill_config` | string | `sierrapy_only` \| `sierrapy+damlab` \| ... | Skill/markdown configuration under test. |
| `skill_version` | string | `2026-07-07` \| `<commit>` | Snapshot of the sierrapy skill used, so a mid-round edit is not an uncontrolled variable. |
| `model` | string | `claude-opus-4-8` \| ... | Model driving the analysis agent. |
| `date` | ISO date | `2026-07-07` | Run date. |

## Layer A — factual (each 0-5; `NA` if not applicable)

> Note: **scored** columns (`A1_mutations`, `A2_no_fabrication`, `A3`–`A5`) use the 0-5
> anchor scale. **Raw-measurement** columns (`A1_precision`, `A1_recall`, `A2_fabrication_count`)
> are the underlying quantities the scores are derived from — precision/recall are ratios
> (0.0-1.0), fabrication_count is a count (>=0). These are NOT on the 0-5 scale and let you
> audit whether each 0-5 score was assigned per its anchor.

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `A1_mutations` | int/NA | 0-5 | Mutations match gold (anchor maps precision/recall bands to score). |
| `A1_precision` | float/NA | 0.0-1.0 | Mutation precision vs. gold. |
| `A1_recall` | float/NA | 0.0-1.0 | Mutation recall vs. gold. |
| `A2_no_fabrication` | int | 0-5 | Score for absence of fabricated mutations. |
| `A2_fabrication_count` | int | >=0 | Raw count of reported mutations absent from gold. Key metric. |
| `A3_resistance` | int/NA | 0-5 | Resistance levels match gold. |
| `A4_subtype` | int/NA | 0-5 | Subtype matches gold (**binary: 5 / 0 / NA**). |
| `A5_validation_surfaced` | int/NA | 0-5 | Sierra validation issues surfaced, not dropped (binary-natured: 5/3/0). |
| `A6_attribution` | int/NA | 0-5 | **Patient attribution.** Is each mutation/resistance/subtype attached to the correct `sequence_id`? Distinct from A1: a swap between sequences can leave the overall mutation *set* nearly intact while making every per-patient claim wrong. NA if single-sequence input. |

## Layer B — process / behavioral & communication (each 0-5; `NA` if conditional and not asked)

| Column | Type | Allowed | Source | Meaning |
|--------|------|---------|--------|---------|
| `B2_constraint_adherence` | int/NA | 0-5 | output | Honored explicit stated output constraints (e.g. "report all, do not filter"). NA if no constraint stated. Distinct from taxonomy (edge-case) and B7 (honesty). |
| `B3_structure_followed` | int/NA | 0-5 | skeleton | Requested output structure followed (NA if no structure asked). **Do not penalize the absence of a section the task did not provide** — that scores the treatment, not the agent. |
| `B4_faithfulness` | int/NA | 0-5 | skeleton+transcript | **Fabrication axis.** Every Sierra-*domain* factual claim in prose traces to structured output/gold; no invented or falsely-restated science. Does NOT grade clinical suggestions or certainty of phrasing (see `B4b_disclosure`). NA only if zero prose produced. |
| `B4b_disclosure` | int/NA | 0-5 | skeleton+transcript | **Undisclosed clinical overreach.** Fires only when an out-of-domain clinical claim (regimen, prognosis, urgency) is BOTH asserted as fact AND undisclosed. Does NOT grade certainty/tone or in-domain confidence, and does NOT penalize a labeled suggestion (those route to `clinical_extension_flag`). Rule-checkable: in-domain? disclosed? NA only if zero prose produced. |
| `B5_completeness` | int/NA | 0-5 | skeleton | Summary covers material findings — under-coverage (NA if no summary asked). |
| `B5b_reasoning` | int/NA | 0-5 | skeleton+transcript | **Reasoning quality.** Does the explanation correctly connect Sierra evidence to its conclusions? Grades the evidentiary chain, NOT the conclusion's medical correctness — a right conclusion via wrong reasoning ("switch because subtype B is resistant") scores low. NA unless the task asked the agent to explain, justify, or recommend. |
| `B6_communication` | int/NA | 0-5 | skeleton+transcript | **Interpretation / communication quality.** Clear, organized, appropriately caveated. Grades communication of *supported* findings; eloquence never launders an unsupported claim. NA if no summary/interpretation asked. |
| `B7_provenance` | int | 0-5 | transcript+skeleton | Honest disclosure of workaround/filtering/uncertainty. **Applies in every arm.** Where the template has no provenance section, grade whether disclosure appeared **anywhere unprompted** — do NOT mark NA, and do NOT penalize the absence of a section the task removed. |
| `B8_scope_discipline` | int/NA | 0-5 | output+transcript | Stayed within requested scope — over-coverage / no substantial unrequested work (NA if no bounded scope). |

> **Note on retired criteria.** Two Layer B criteria measured the *harness* rather than the
> model and have been retired:
> - **`B1_correct_tool`** — the exported transcript contains only narration, never observable
>   tool invocations, so it was a constant 3 across all seven task01 runs and discriminated
>   nothing. Replaced by the unscored **`tool_execution_verified`** gate (see Grading
>   integrity below).
> - **Old `B2_no_stale_shortcut` / `B2_fresh_execution`** — structurally vacuous under the
>   isolated sandbox (every run passed). B2 is now **`B2_constraint_adherence`**.
>
> Layer B is now purely behavioral: B2 (doing *no less* than asked) and B8 (doing *no more*)
> bracket instruction-following; B3–B7 grade structure, faithfulness, coverage, communication,
> and honesty. Every remaining criterion is capable of varying across runs.

## Taxonomy and cost

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `taxonomy_tag` | enum | `honest_halt` \| `workaround_disclosed` \| `silent_fabrication` \| `na` | Edge-case behavior tag. |
| `clinical_extension_flag` | string | `none` \| short verbatim quote | **Unscored, freeform human-review pointer** — not a taxonomy. `none`, or a short verbatim quote of phrasing whose *language* warrants a human glance (urgency, near-absolute wording, striking in-domain confidence). Carries no scoring implication; the prose penalties live in B4/B4b. A labeled clinical suggestion is normally `none` unless its wording is itself notable. See rubric "Clinical-extension flag". |
| `token_cost` | int/NA | >=0 | Total tokens for the run, if available. See cost caveats in eval-protocol.md. |
| `token_cost_source` | string/NA | `tracker_est` \| `cursor_usage` \| `NA` | Where the cost figure came from (estimated vs. authoritative). |
| `usd_cost` | float/NA | >=0 | API cost in USD, if available. |
| `turns` | int/NA | >=0 | Agent turns / wall-clock proxy, optional. |

## Grading integrity

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `tool_execution_verified` | enum | `yes` \| `no` \| `unverified` | **Unscored validity gate**, not a criterion. `yes` = structured `*_sierra.json` is genuine Sierra output (high-fidelity match to gold proves execution) and `run_meta.json` is consistent. `no` = pipeline did not run → **run is invalid, exclude from analysis** (do not score it low). `unverified` = inconclusive; flag for human review. Never average or convert to 0-5. |
| `human_spotcheck` | enum | `yes` \| `no` | Was this run human-re-graded against gold? |
| `judge_human_agree` | enum/NA | `agree` \| `minor_diff` \| `major_diff` \| `NA` | If spot-checked, did judge match human? `NA` if not spot-checked. |
| `notes` | string | free text | Anything notable (ambiguous task ID, judge uncertainty, interesting behavior). |

## Analysis reminders
- Keep Layer A and Layer B separate in analysis; do not report a single combined grade.
- `A2_fabrication_count`, `taxonomy_tag`, and `clinical_extension_flag` are the headline behavioral signals.
- Aggregate by `prompt_config` / `skill_config` / `model` to answer the research question.
- Join to cost/tracker data on `conversation_id`, not `conversation_title`.
- Report `NA` counts explicitly so conditional coverage is transparent.
- `clinical_extension_flag` is freeform and may contain commas — **quote the field** (`"…"`) in the CSV when it holds a verbatim phrase, so column alignment is preserved.

## Handling pre-change data

Five schema changes happened during the project. Rows recorded before each are on a different
basis — do not pool them naively with current rows. Tag each row's `round` so pre-change rows
(e.g. `2026-week2`) are separable, and filter to current-basis rows unless you have re-graded.

| Change | Pre-change rows | What to do |
|--------|-----------------|------------|
| **0-2/0-1 → 0-5 scale** | scores on old 0-2 (0-1 for A4/A5/B3) basis | re-grade under current rubric, or drop (testing-only). **Do not** linearly rescale — anchors differ. |
| **B2 redefined; B8 added** | `B2_no_stale_shortcut` → `B2_fresh_execution` → current `B2_constraint_adherence`; no B8 | treat old B2 as not comparable (re-grade from output, else `NA`); B8 = `NA` unless re-graded. |
| **B1 retired; gate added** | `B1_correct_tool` (constant 3); no `tool_execution_verified` | drop B1 from analysis; back-fill the gate from structured output + `run_meta.json` if wanted. |
| **B4 split; flag added** | one combined `B4_faithfulness`; no `B4b_disclosure` / `clinical_extension_flag` | old B4 not comparable — re-grade into B4 + B4b (+ flag quote), else mark both `NA` and exclude from B4 comparisons. Do not read an old low B4 as fabrication; it may have been certainty or a labeled suggestion, now unpenalized. |
| **A6 + B5b added; A4 → binary** | no `A6_attribution` / `B5b_reasoning`; `A4_subtype` on the 5/3/0 basis | mark A6 and B5b `NA` for pre-change rows unless re-graded (both are new measurements, not redefinitions — nothing to convert). Old A4 = 3 has no current equivalent: re-grade to 5 or 0, else `NA`. |