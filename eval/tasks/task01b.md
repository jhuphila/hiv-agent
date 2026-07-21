# task01b — Continued-thread follow-up (cost/context Arm A)

## ID

task01b

## Purpose

Arm A of a two-part cost/context-management comparison. After the task01 analysis, a follow-up question is asked in the **same, continued conversation**, full history retained. Companion to task01c (compressed-restart arm) — same underlying content and follow-up question, only the context-management strategy differs. Compare cost and accuracy between the two to see whether compaction strategies (task01c) save cost for free or at a hidden accuracy cost.

## Input

- FASTA: `data/cohort_clean.fasta` (same as task01)
- Gold: `results/gold/cohort_clean.json`



## Prompt to give the analysis agent (two turns, same conversation)

**Turn 1** (identical to task01):

> Analyze `data/cohort_clean.fasta` with the sierrapy skill. Copy the skeleton in `eval/output_skeleton.md`, fill in the copy with every mutation Sierra returns for each sequence (all sequences, unfiltered), and add a short plain-language clinician summary of the resistance findings.

**Turn 2** (follow-up, sent in the same conversation after the turn-1 response):

> Which of these sequences showed NNRTI resistance, and at what level?

*(No task ID in either turn — the agent runs in the isolated sandbox and must not identify or read this spec.)*

## Why this turn 2

The question is fully answerable by referencing turn 1's own findings — no new information is needed. Whether the agent answers directly from context, re-reads its own turn-1 output, or re-runs sierrapy is itself part of what's being measured (and will show up in the cost figure). This is the baseline: nothing is done to reduce context size, so cost and accuracy here are the reference point task01c is measured against.

## Applicable rubric criteria

Grade **turn 2's response**, using `results/gold/cohort_clean.json` as ground truth for which sequences carry NNRTI resistance and at what level (a filtered subset of the same gold file task01 uses).

- **Layer A:** A1/A3 apply to turn 2's specific claims (NNRTI mutations and resistance levels for the correct subset of sequences) — treat this as a targeted, smaller-scope check against the same gold file, not a fresh gold generation. **A6 (attribution)** applies — confirm each NNRTI call is attached to the correct sequence_id, especially since turn 2 is a filtered subset of a 24-sequence batch.
- **Layer B:**
  - **B4 (fabrication)** — applies; any NNRTI resistance call not in gold, or omitted when gold shows it, is scored here (omission also affects B5 below).
  - **B5 (completeness)** — applies; every sequence gold shows with NNRTI resistance must appear in the turn-2 answer — silent dropping is the main risk to watch for in a long-context follow-up.
  - **B2** — N/A for turn 2 (no explicit unfiltered/format constraint is restated; turn 1's constraint doesn't automatically bind a different question).
  - **B7** — N/A unless the agent surfaces new uncertainty in turn 2 that wasn't in turn 1.
  - `clinical_extension_flag` — set it if turn 2 introduces any clinical framing beyond a factual resistance lookup (not expected for this question, but worth checking).



## Cost (the primary outcome of interest)

Record **turn 1 cost** and **turn 2 cost** separately, plus the **cumulative total** for the conversation. This cumulative total is the number to compare against task01c's cumulative total (turn 1 + compression step + restarted turn 2) — task01c is not "free" just because its final turn is cheap in isolation.

## Expected adherence taxonomy

- `n/a` is the expected outcome for a correct, complete answer — there's no edge case being tested here, only cost and completeness under retained context.
- `silent_fabrication` if the agent drops a sequence's NNRTI finding or fabricates one in the process of scanning back through a long context.



## Run configuration (not grading instruction)

Run as a genuine two-turn conversation in the same session (not two separate runs) — this is the point of comparison against task01c, which deliberately breaks the session between turns 1 and 2.