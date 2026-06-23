# HIV Agent

A [Cursor Agent](https://docs.cursor.com/agent/overview) project for HIV-1 *pol* sequence analysis. The workflow validates coding sequences, queries [Stanford HIVDB Sierra](https://hivdb.stanford.edu/) for alignment and mutation calling, and writes structured resistance summaries — without hand-translating DNA or inferring HIVDB positions manually.

The project pairs a focused **sierrapy** agent skill (HIV-specific) with the shared **[damlab-skills](https://github.com/DamLabResources/damlab-skills)** library (general bioinformatics CLI tools) so agents can run reproducible analyses from FASTA input through tabular results.

## What it does

1. **Validate** HIV coding sequences (length divisible by 3, no premature stop codons).
2. **Query** Stanford HIVDB via [sierrapy](https://github.com/hivdb/sierrapy) for *pol* gene alignment, subtype assignment, mutation calling, and antiretroviral resistance interpretation.
3. **Write** machine-readable outputs under `results/`:
   - `*_sierra.json` — raw Sierra `sequenceAnalysis` JSON
   - `*_summary.csv` — flattened genes, mutations, and drug susceptibility scores

Mutation positions, HIVDB numbering, and resistance levels always come from Sierra — not from generic translation.

## Project layout

```
hiv-agent/
├── data/                          # Input FASTA files (*.fasta, *.fa, *.fas, *.fna)
├── results/                       # Pipeline outputs (JSON + CSV)
├── environment.yaml               # Conda env: hiv-agent (python, biopython, sierrapy)
├── Makefile                       # install, test, clean targets
├── skills/
│   ├── sierrapy/                  # HIV-specific skill + translate_and_query.py
│   └── damlab-skills/             # Git submodule — general bioinformatics skills
└── .cursor/
    └── skills/sierrapy/           # Project-local Cursor skill (same sierrapy content)
```

| Path | Purpose |
|------|---------|
| `data/` | Place HIV *pol* (or other coding) FASTA files here before running the pipeline. |
| `results/` | JSON and summary CSV written per input file stem (e.g. `my_sequences_sierra.json`). |
| `skills/sierrapy/` | Canonical location for `translate_and_query.py` when running from the shell. |
| `.cursor/skills/sierrapy/` | Cursor-discovered project skill; agents read `SKILL.md` from here. |
| `skills/damlab-skills/` | Submodule with samtools, seqkit, csvtk, plotting, EDA, and other lab skills. |

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| [Conda](https://docs.conda.io/) or [Mamba](https://mamba.readthedocs.io/) | Used to create the `hiv-agent` environment. |
| `git` | Required to clone the repo and initialize submodules. |
| Network access | Sierra queries the Stanford HIVDB GraphQL API. |

On Windows, use **WSL2** and follow the Linux steps inside your WSL distro.

## Installation

Clone the repository and initialize submodules:

```bash
git clone <repo-url> hiv-agent
cd hiv-agent
git submodule update --init --recursive
```

Create or update the conda environment:

```bash
make install
# equivalent to:
# conda env create -f environment.yaml || conda env update -f environment.yaml
```

Activate the environment for interactive use:

```bash
conda activate hiv-agent
```

### Optional: install damlab-skills tool environments

The `damlab-skills` submodule provides additional agent skills (samtools, bedtools, seqkit, etc.). To install their conda prefix environments and link skills globally:

```bash
cd skills/damlab-skills
bash install.sh
```

See [skills/damlab-skills/INSTALL.md](skills/damlab-skills/INSTALL.md) for Cursor vs OpenClaw install options, verification, and troubleshooting.

## Quick start

### 1. Add sequences

Place one or more FASTA files in `data/`. Example files are included:

- `data/my_sequences.fasta` — HXB2 reference (*pol*)
- `data/other_sequences.fasta` — additional clinical-style sequences

Sequences must be **nucleotide coding sequences** (length a multiple of 3, no internal stop codons).

### 2. Run the Sierra pipeline

Process every FASTA in `data/`:

```bash
conda run -n hiv-agent python skills/sierrapy/translate_and_query.py
```

Process a single file:

```bash
conda run -n hiv-agent python skills/sierrapy/translate_and_query.py \
  --input data/my_sequences.fasta
```

Use `skills/sierrapy/translate_and_query.py` from the shell so default `--data-dir` and `--results-dir` resolve to the project root. If you invoke the copy under `.cursor/skills/sierrapy/`, pass explicit directories:

```bash
conda run -n hiv-agent python .cursor/skills/sierrapy/translate_and_query.py \
  --data-dir data --results-dir results
```

### 3. Inspect results

For input `data/my_sequences.fasta`, the pipeline writes:

| File | Contents |
|------|----------|
| `results/my_sequences_sierra.json` | Full Sierra analysis per sequence |
| `results/my_sequences_summary.csv` | Flattened table with `record_type` = `gene`, `mutation`, or `drug_score` |

Summary CSV columns include `sequence_id`, `subtype`, `gene`, `position`, `mutation`, `drug_class`, `drug`, `score`, and `level` (susceptibility tier).

Example mutation rows:

```csv
sequence_id,subtype,record_type,gene,position,mutation,...
B.FR.83.HXB2_LAI_IIIB_BRU.K03455,B (0.70%),mutation,PR,3,I3V,...
B.FR.83.HXB2_LAI_IIIB_BRU.K03455,B (0.70%),mutation,RT,214,F214L,...
```

## Pipeline options

```
translate_and_query.py [--input FILE] [--data-dir DIR] [--results-dir DIR]
                       [--url URL] [--step N]
                       [--max-retries N] [--initial-backoff SEC] [--backoff-multiplier M]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--input` | *(all FASTA in data-dir)* | Process one FASTA file |
| `--data-dir` | `data/` | Directory to scan when `--input` is omitted |
| `--results-dir` | `results/` | Output directory for JSON and CSV |
| `--url` | Stanford HIVDB production | Override Sierra GraphQL endpoint |
| `--step` | 20 | Sequences per API batch |
| `--max-retries` | 5 | Retries for transient network/server errors |
| `--initial-backoff` | 5 | First retry delay (seconds) |
| `--backoff-multiplier` | 2 | Exponential backoff factor |

Full flag reference: [skills/sierrapy/reference.md](skills/sierrapy/reference.md).

Low-level alternative (raw JSON only, no validation or summary CSV):

```bash
conda run -n hiv-agent sierrapy fasta data/my_sequences.fasta
```

Prefer `translate_and_query.py` for project workflows.

## Using with Cursor

This repo is set up as a **project-local agent workspace**:

- **sierrapy** lives in `.cursor/skills/sierrapy/` so Cursor agents automatically discover HIV resistance workflows.
- Agents are instructed to place FASTA in `data/`, run `translate_and_query.py`, and read mutations and drug scores only from `results/` — never to manually translate or number mutations.
- Skill documentation: [.cursor/skills/sierrapy/SKILL.md](.cursor/skills/sierrapy/SKILL.md)

Add the pipeline script to your terminal allowlist (Cursor → Settings → Features → Terminal):

```bash
readlink -f "$(pwd)/skills/sierrapy/translate_and_query.py"
```

### damlab-skills

The `skills/damlab-skills` submodule adds lab-standard skills for alignment QC, interval arithmetic, tabular data, plotting, notebooks, literature search, and more. After `bash install.sh` inside that directory, agents can use tools like `samtools`, `seqkit`, `csvtk`, and `plotting` alongside the HIV-specific sierrapy workflow.

Overview: [skills/damlab-skills/README.md](skills/damlab-skills/README.md)

## Makefile targets

```bash
make install    # Create or update the hiv-agent conda environment
make test       # Run pytest inside hiv-agent (when tests are present)
make clean      # Remove __pycache__ directories
```

## Input requirements

- **Format:** FASTA (`.fasta`, `.fa`, `.fas`, `.fna`)
- **Alphabet:** DNA (T/U accepted; U is normalized to T)
- **Reading frame:** Coding sequence — length must be divisible by 3
- **Stop codons:** No premature `TAA`, `TAG`, or `TGA` before the terminal codon

The pipeline fails fast on validation errors **before** any network call to Sierra.

## Output reference

### Summary CSV `record_type` values

| `record_type` | Meaning |
|---------------|---------|
| `gene` | Aligned gene span (PR, RT, IN, etc.) with `first_aa`, `last_aa`, `gene_length` |
| `mutation` | HIVDB mutation call at `position` in `gene` |
| `drug_score` | Antiretroviral susceptibility for a `drug` in a `drug_class` |

### JSON

`results/*_sierra.json` contains the full Sierra response per sequence, including `alignedGeneSequences`, `drugResistance`, subtype text, and related fields. Use the CSV for tabular analysis; use JSON when you need the complete API payload.

## Development

Environment specification (`environment.yaml`):

```yaml
name: hiv-agent
dependencies:
  - python =3.10
  - biopython
  - pip:
    - sierrapy
    - pytest
```

Changelog for the sierrapy skill: [skills/sierrapy/CHANGELOG.md](skills/sierrapy/CHANGELOG.md).

To run tests (when added):

```bash
make test
# or:
conda run -n hiv-agent pytest
```

## References

- [Stanford HIV Drug Resistance Database (HIVDB)](https://hivdb.stanford.edu/)
- [Sierra web interface](https://hivdb.stanford.edu/page/sierra/)
- [sierrapy Python client](https://github.com/hivdb/sierrapy)
- [Cursor Agent Skills](https://docs.cursor.com/agent/skills)
- [damlab-skills](https://github.com/DamLabResources/damlab-skills)

## License

The `skills/damlab-skills` submodule is distributed under the MIT License ([skills/damlab-skills/LICENSE](skills/damlab-skills/LICENSE)). Check individual skill changelogs for tool-specific versioning notes.
