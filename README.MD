# HIV Agent

A [Cursor Agent](https://docs.cursor.com/agent/overview) project for HIV-1 *pol* sequence analysis. The workflow loads FASTA input, queries [Stanford HIVDB Sierra](https://hivdb.stanford.edu/) for alignment and mutation calling, and writes structured resistance summaries — without hand-translating DNA or inferring HIVDB positions manually.

The project pairs a focused **sierrapy** agent skill (HIV-specific) with the shared **[damlab-skills](https://github.com/DamLabResources/damlab-skills)** library (general bioinformatics CLI tools) so agents can run reproducible analyses from FASTA input through tabular results.

## What it does

1. **Load** HIV FASTA sequences from `data/`.
2. **Query** Stanford HIVDB via [sierrapy](https://github.com/hivdb/sierrapy) for *pol* gene alignment, subtype assignment, mutation calling, and antiretroviral resistance interpretation. Sequences are sent to Sierra as-is; the pipeline does not block on local CDS checks.
3. **Write** machine-readable outputs under `results/`:
   - `*_sierra.json` — raw Sierra `sequenceAnalysis` JSON (including `validationResults`)
   - `*_summary.csv` — flattened genes, mutations, drug susceptibility scores, and Sierra validation messages

Mutation positions, HIVDB numbering, resistance levels, and sequence-quality warnings always come from Sierra — not from generic translation or local pre-checks.

## Project layout

```
hiv-agent/
├── data/                          # Input FASTA files (*.fasta, *.fa, *.fas, *.fna)
├── results/                       # Pipeline outputs (JSON + CSV)
├── environment.yaml               # Conda env: hiv-agent (python, biopython, sierrapy)
├── Makefile                       # install, test, clean targets
├── skills/
│   └── damlab-skills/             # Git submodule — general bioinformatics skills
└── .cursor/
    └── skills/sierrapy/           # HIV-specific skill + translate_and_query.py
```

| Path | Purpose |
|------|---------|
| `data/` | Place HIV *pol* (or other coding) FASTA files here before running the pipeline. |
| `results/` | JSON and summary CSV written per input file stem (e.g. `my_sequences_sierra.json`). |
| `.cursor/skills/sierrapy/` | Sierra pipeline script, Cursor skill docs, and `translate_and_query.py`. |
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
- `data/test_sequences.fasta` — additional clinical-style sequences

Sequences should ordinarily be HIV *pol* nucleotide coding sequences, but the pipeline does not enforce length, reading frame, or stop-codon rules locally. Sierra evaluates input and reports issues in `validationResults`.

### 2. Run the Sierra pipeline

Process every FASTA in `data/`:

```bash
conda run -n hiv-agent python .cursor/skills/sierrapy/translate_and_query.py \
  --data-dir data --results-dir results
```

Process a single file:

```bash
conda run -n hiv-agent python .cursor/skills/sierrapy/translate_and_query.py \
  --input data/my_sequences.fasta --results-dir results
```

Default `--data-dir` and `--results-dir` resolve relative to the project root when omitted. Pass explicit paths if you run the script from another working directory.

### 3. Inspect results

For input `data/my_sequences.fasta`, the pipeline writes:

| File | Contents |
|------|----------|
| `results/my_sequences_sierra.json` | Full Sierra analysis per sequence |
| `results/my_sequences_summary.csv` | Flattened table with `record_type` = `validation`, `gene`, `mutation`, or `drug_score` |

Sierra validation messages (e.g. frameshifts) are printed to stderr during the run and included as `validation` rows in the CSV. Alignment and resistance results are still written when Sierra returns them.

Summary CSV columns include `sequence_id`, `subtype`, `gene`, `position`, `mutation`, `drug_class`, `drug`, `score`, and `level` (Sierra validation severity or susceptibility tier, depending on `record_type`).

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

Full flag reference: [.cursor/skills/sierrapy/reference.md](.cursor/skills/sierrapy/reference.md).

Low-level alternative (raw JSON only, no summary CSV):

```bash
conda run -n hiv-agent sierrapy fasta data/my_sequences.fasta
```

Prefer `translate_and_query.py` for project workflows.

## Using with Cursor

This repo is set up as a **project-local agent workspace**:

- **sierrapy** lives in `.cursor/skills/sierrapy/` so Cursor agents automatically discover HIV resistance workflows.
- Agents are instructed to place FASTA in `data/`, run `translate_and_query.py`, and read mutations, drug scores, and Sierra validation messages only from `results/` — never to manually translate or number mutations.
- Skill documentation: [.cursor/skills/sierrapy/SKILL.md](.cursor/skills/sierrapy/SKILL.md)

Add the pipeline script to your terminal allowlist (Cursor → Settings → Features → Terminal):

```bash
readlink -f "$(pwd)/.cursor/skills/sierrapy/translate_and_query.py"
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
- **Content:** Intended for HIV *pol* nucleotide sequences, but not pre-validated locally

The pipeline only rejects invalid requests (missing files, empty FASTA, unreachable API after retries). Sequence-quality issues such as frameshifts, missing genes, or stop codons are reported by Sierra in `validationResults`, printed to stderr, and written to the summary CSV as `validation` rows.

## Output reference

### Summary CSV `record_type` values

| `record_type` | Meaning |
|---------------|---------|
| `validation` | Sierra `validationResults` message (`level` = severity, `mutation` = message text) |
| `gene` | Aligned gene span (PR, RT, IN, etc.) with `first_aa`, `last_aa`, `gene_length` |
| `mutation` | HIVDB mutation call at `position` in `gene` |
| `drug_score` | Antiretroviral susceptibility for a `drug` in a `drug_class` |

### JSON

`results/*_sierra.json` contains the full Sierra response per sequence, including `validationResults`, `alignedGeneSequences`, `drugResistance`, subtype text, and related fields. Use the CSV for tabular analysis; use JSON when you need the complete API payload.

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

Changelog for the sierrapy skill: [.cursor/skills/sierrapy/CHANGELOG.md](.cursor/skills/sierrapy/CHANGELOG.md).

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
