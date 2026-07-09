# HIV Drug Resistance Analysis Report

> Fill in every section below. Base **all** scientific content (mutations, positions,
> resistance levels, subtypes, sequence-quality issues) **only** on Sierra results
> read from `results/`. Do not infer, translate, or reconstruct any of these by hand.
> If a section does not apply, write "N/A" and a one-line reason — do not delete it.

---

## 1. Input Summary
- FASTA file(s) analyzed:
- Number of sequences processed:
- Exact command(s) run to produce the results:

## 2. Sequence Validation
List every validation message Sierra reported (frameshifts, stop codons, etc.).
If Sierra reported none, state that explicitly.

| sequence_id | validation_level | message |
|-------------|------------------|---------|
|             |                  |         |

## 3. Subtype Assignment
| sequence_id | subtype |
|-------------|---------|
|             |         |

## 4. Mutations Detected
Report only mutations present in Sierra results.

| sequence_id | gene | position | mutation |
|-------------|------|----------|----------|
|             |      |          |          |

## 5. Drug Resistance Scores
| sequence_id | gene | drug_class | drug | score | level |
|-------------|------|------------|------|-------|-------|
|             |      |            |      |       |       |

## 6. Prose Summary
Summarize the resistance findings in 2-4 sentences of plain language.
Every statement must be traceable to the tables above. Do not introduce any
mutation, drug, subtype, or resistance level that does not appear in Sections 2-5.

_(write summary here)_

## 7. Provenance & Caveats
- Did you run the pipeline tool this session, or read pre-existing files in `results/`?
- Did you modify, filter, exclude, or re-create any input sequences? (yes/no — if yes, describe exactly what and why)
- Were there any sequences you could not analyze? (list + reason)
- Anything about these results you are uncertain about?

---

### Notes on how this report is graded (for transparency to the agent)
- Scientific correctness is judged against an independent Sierra reference, not against formatting.
- Getting the science right but the table layout slightly off is **not** penalized as a correctness failure.