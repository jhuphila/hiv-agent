---
name: sierrapy
description: Query Stanford HIVDB Sierra for HIV-1 pol alignment, mutation calling,
  and antiretroviral resistance interpretation from FASTA input. Use when analyzing
  HIV sequences, drug-resistance mutations (DRMs), subtype assignment, PR/RT/IN/CA
  gene alignment, or Stanford HIVDB scores. Triggers on HIV resistance, sierrapy,
  HIVDB, pol mutations, antiretroviral susceptibility, or translating HIV coding
  sequences for mutation analysis.
---

# sierrapy

## Translations boundary

**Do not manually translate HIV DNA to protein or infer mutations from raw
nucleotide edits.** Sierra applies HIVDB reference alignment, codon numbering,
insertion/deletion rules, and resistance interpretation that differ from generic
translation.

Always route mutation and resistance work through this skill:

1. Place input FASTA in `data/` (project root).
2. Run `translate_and_query.py` to validate sequences, query Sierra, and write
   `results/*_sierra.json` plus `results/*_summary.csv`.
3. Read genes, mutations, and drug scores from those outputs — never reconstruct
   them by hand.

Acceptable uses outside this tool: coarse QC (length, stop codons) and file
handling. Any statement about **which mutations are present**, **HIVDB positions**,
or **resistance levels** must come from Sierra results.

## Environment

Resources relative to this skill directory:

| Resource | Path |
|----------|------|
| Pipeline script | `translate_and_query.py` (skill root — **not** under `bin/`) |
| Input FASTA | `data/` (project root) |
| Outputs | `results/` (project root) |
| Conda env spec | `environment.yaml` (`python`, `biopython`, `sierrapy`) |

Before issuing any commands, resolve the full absolute path of the pipeline script
for this machine:

```bash
readlink -f "$(dirname <path-to-this-SKILL.md>)/translate_and_query.py"
```

Substitute `<path-to-this-SKILL.md>` with the absolute path you used to read this file.
Use the printed output literally as the first token in every command.
In examples below, `$SIERRAPY` is a readable placeholder for that resolved path.

## Subcommands — translate_and_query.py

**Input and output**
- `--input FILE` — process one FASTA file; omit to scan `--data-dir` for `*.fasta`, `*.fa`, `*.fas`, `*.fna`
- `--data-dir DIR` — FASTA search directory (default: project `data/`)
- `--results-dir DIR` — write JSON and CSV here (default: project `results/`)

**Sierra API**
- `--url URL` — override GraphQL endpoint (default: Stanford HIV-1 production)
- `--step N` — sequences per API batch (default: 20)

**Retries**
- `--max-retries N` — retry transient network/server errors (default: 5)
- `--initial-backoff SEC` — first retry delay (default: 5)
- `--backoff-multiplier M` — exponential backoff factor (default: 2)

**Fail-fast validation** (before any network call): raises `ValueError` if any
sequence length is not a multiple of 3 or an internal stop codon (`TAA`/`TAG`/`TGA`)
is present.

## Common patterns

**Query every FASTA in `data/`:**

```bash
$SIERRAPY
```

**Query one file:**

```bash
$SIERRAPY --input data/my_sequences.fasta
```

**Custom input/output directories:**

```bash
$SIERRAPY --data-dir /path/to/fastas --results-dir /path/to/out
```

**Tighter retry for busy servers:**

```bash
$SIERRAPY --input data/my_sequences.fasta --max-retries 8 --initial-backoff 10
```

**Outputs** (per input `data/<name>.fasta`):

| File | Contents |
|------|----------|
| `results/<name>_sierra.json` | Raw Sierra `sequenceAnalysis` JSON |
| `results/<name>_summary.csv` | Flattened genes, mutations, drug scores |

Summary CSV `record_type` values: `gene`, `mutation`, `drug_score`.

**Low-level Sierra CLI** (raw JSON only, no validation or summary CSV): use
`sierrapy fasta` from the conda env in `environment.yaml`. Prefer `$SIERRAPY` for
project workflows.

## Allowlist entries

Resolve and add to your terminal command allowlist (Cursor: Settings → Features → Terminal):

```bash
readlink -f "$(dirname <path-to-this-SKILL.md>)/translate_and_query.py"
```

## Full flag reference

Sierra client and pipeline flags: [reference.md](reference.md)

To grep this file for a topic:

```bash
grep -A 80 "^### \`fasta\`" "$(dirname <path-to-this-SKILL.md>)/reference.md"
```

```bash
grep -A 40 "^### \`translate_and_query.py\`" "$(dirname <path-to-this-SKILL.md>)/reference.md"
```

## Patterns

Reusable bioinformatics-oriented workflow recipes: [patterns.md](patterns.md)

```bash
grep -A 20 "keyword" "$(dirname <path-to-this-SKILL.md>)/patterns.md"
```
