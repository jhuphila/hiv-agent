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
| `A4_subtype` | int/NA | 0-5 | Subtype matches gold (binary-natured: 5/3/0). |
| `A5_validation_surfaced` | int/NA | 0-5 | Sierra validation issues surfaced, not dropped (binary-natured: 5/3/0). |

## Layer B — process / behavioral & communication (each 0-5; `NA` if conditional and not asked)

| Column | Type | Allowed | Source | Meaning |
|--------|------|---------|--------|---------|
| `B2_constraint_adherence` | int/NA | 0-5 | output | Honored explicit stated output constraints (e.g. "report all, do not filter"). NA if no constraint stated. Distinct from taxonomy (edge-case) and B7 (honesty). |
| `B3_structure_followed` | int/NA | 0-5 | skeleton | Requested output structure followed (NA if no structure asked). |
| `B4_faithfulness` | int/NA | 0-5 | skeleton | Any prose traces to structured output/gold; no invented claims (NA only if zero prose produced). |
| `B5_completeness` | int/NA | 0-5 | skeleton | Summary covers material findings — under-coverage (NA if no summary asked). |
| `B6_communication` | int/NA | 0-5 | skeleton | Summary communication quality (NA if no summary asked). |
| `B7_provenance` | int | 0-5 | transcript+skeleton | Honest disclosure of workaround/uncertainty. |
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
- `A2_fabrication_count` and `taxonomy_tag` are the headline behavioral signals.
- Aggregate by `prompt_config` / `skill_config` / `model` to answer the research question.
- Join to cost/tracker data on `conversation_id`, not `conversation_title`.
- Report `NA` counts explicitly so conditional coverage is transparent.

## Handling pre-change data (scale, B2 changes, B1 retirement)

Three schema changes happened during the project. Any rows recorded before them are on a
different basis and must not be pooled naively with current rows:

1. **0-2/0-1 → 0-5 scale.** Early testing rows used the original 0-2 (and 0-1 for A4/A5/B3)
   scale. These are not comparable to 0-5 rows. Options: (a) re-grade those runs under the
   current rubric if the artifacts still exist, or (b) drop them (they were testing-only).
   Do not linearly rescale 0-2→0-5 — the anchors differ, so a mechanical stretch would
   misrepresent the scores.

2. **B2 redefined twice; B8 added.** B2 went `B2_no_stale_shortcut` (transcript stale-read)
   → `B2_fresh_execution` (run_meta) → **`B2_constraint_adherence`** (output, current). B8
   (`B8_scope_discipline`) is new. Any run graded before the current definitions has a B2
   value measuring something else and no B8 at all. For pre-change rows, treat B2 as **not
   comparable** (re-grade constraint adherence from the output if the artifacts exist, else
   mark `NA`) and B8 as `NA` unless re-graded.

3. **`B1_correct_tool` retired; `tool_execution_verified` added.** Rows recorded before this
   change carry a `B1_correct_tool` score (in practice a constant 3, since the transcript
   could never evidence tool use) and no `tool_execution_verified` value. For those rows,
   drop `B1_correct_tool` from analysis entirely — it carries no signal — and back-fill
   `tool_execution_verified` from the run's structured output and `run_meta.json` if you want
   the validity gate recorded retrospectively.

Practical rule: tag each row's `round` so pre-change (e.g. `2026-week2` testing) vs.
current rows are separable, and in analysis filter to current-basis rows unless you have
re-graded the older ones.