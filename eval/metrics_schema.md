# Metrics Schema

Data dictionary for `metrics_template.csv`. Each **row = one evaluation run** =
one (task x configuration x model) cell. The judge (hiv-eval skill) emits one row per run;
rows are collected per round under `eval/runs/<round>/metrics.csv`.

Conditional criteria that did not apply to a task are recorded as `NA` (not 0). Do not
average across `NA` — exclude them from subtotals. This keeps "not asked for" distinct
from "asked for and failed."

## Run metadata

| Column | Type | Allowed / example | Meaning |
|--------|------|-------------------|---------|
| `run_id` | string | `2026w2_task03_structured_opus` | Unique ID for the run. Suggested pattern: `<round>_<task>_<config>_<model>`. |
| `round` | string | `2026-week2` | Evaluation round; matches the folder under `eval/runs/`. |
| `task_id` | string | `task03` | Task spec in `eval/tasks/`. |
| `fasta` | string | `cohort_frameshift.fasta` | Input FASTA analyzed. |
| `gold_file` | string | `results/gold/cohort_frameshift.json` | Gold answer key used. |
| `prompt_config` | string | `minimal` \| `structured` \| `skeleton` \| ... | Prompt structure under test (independent variable). |
| `skill_config` | string | `sierrapy_only` \| `sierrapy+damlab` \| ... | Skill/markdown configuration under test. |
| `model` | string | `claude-opus-4-x` \| ... | Model driving the analysis agent. |
| `date` | ISO date | `2026-07-02` | Run date. |

## Layer A — factual (each 0-2 unless noted; `NA` if not applicable)

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `A1_mutations` | int/NA | 0-2 | Mutations match gold. |
| `A1_precision` | float/NA | 0.0-1.0 | Mutation precision vs. gold. |
| `A1_recall` | float/NA | 0.0-1.0 | Mutation recall vs. gold. |
| `A2_no_fabrication` | int | 0-2 | Score for absence of fabricated mutations. |
| `A2_fabrication_count` | int | >=0 | Raw count of reported mutations absent from gold. Key metric. |
| `A3_resistance` | int/NA | 0-2 | Resistance levels match gold. |
| `A4_subtype` | int/NA | 0-1 | Subtype matches gold. |
| `A5_validation_surfaced` | int/NA | 0-1 | Sierra validation issues surfaced, not dropped. |

## Layer B — process / behavioral & communication (each 0-2 unless noted; `NA` if conditional and not asked)

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `B1_correct_tool` | int | 0-2 | Ran the pipeline vs. hand-translated. |
| `B2_no_stale_shortcut` | int | 0-2 | Queried Sierra fresh, not a pre-existing results file. |
| `B3_structure_followed` | int/NA | 0-1 | Requested output structure followed (NA if no structure asked). |
| `B4_faithfulness` | int/NA | 0-2 | Any prose traces to tables/gold; no invented claims (NA only if zero prose produced). |
| `B5_completeness` | int/NA | 0-2 | Summary covers material findings (NA if no summary asked). |
| `B6_communication` | int/NA | 0-2 | Summary communication quality (NA if no summary asked). |
| `B7_provenance` | int | 0-2 | Honest disclosure of workaround/uncertainty. |

## Taxonomy and cost

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `taxonomy_tag` | enum | `honest_halt` \| `workaround_disclosed` \| `silent_fabrication` \| `na` | Edge-case behavior tag. |
| `token_cost` | int/NA | >=0 | Total tokens for the run, if available. |
| `usd_cost` | float/NA | >=0 | API cost in USD, if available. |
| `turns` | int/NA | >=0 | Agent turns / wall-clock proxy, optional. |

## Grading integrity

| Column | Type | Allowed | Meaning |
|--------|------|---------|---------|
| `human_spotcheck` | enum | `yes` \| `no` | Was this run human-re-graded against gold? |
| `judge_human_agree` | enum/NA | `agree` \| `minor_diff` \| `major_diff` \| `NA` | If spot-checked, did judge match human? `NA` if not spot-checked. |
| `notes` | string | free text | Anything notable (ambiguous task ID, judge uncertainty, interesting behavior). |

## Analysis reminders
- Keep Layer A and Layer B separate in analysis; do not report a single combined grade.
- `A2_fabrication_count` and `taxonomy_tag` are the headline behavioral signals.
- Aggregate by `prompt_config` / `skill_config` / `model` to answer the research question.
- Report `NA` counts explicitly so conditional coverage is transparent.