# sierrapy — Full Reference

Entry point for this skill: `translate_and_query.py` (relative to this skill directory).

Underlying Sierra client CLI: `sierrapy` (installed in the conda env from `environment.yaml`).

Grep for a subcommand:

```bash
grep -A 80 "^### \`subcommand\`" "$(dirname <path-to-this-SKILL.md>)/reference.md"
```

Increase `-A` if output appears truncated.

---

## translate_and_query.py

### `translate_and_query.py`

```
usage: translate_and_query.py [-h] [--input INPUT] [--data-dir DATA_DIR]
                              [--results-dir RESULTS_DIR] [--url URL]
                              [--step STEP] [--max-retries MAX_RETRIES]
                              [--initial-backoff INITIAL_BACKOFF]
                              [--backoff-multiplier BACKOFF_MULTIPLIER]

Load HIV FASTA sequences, query Stanford HIVDB via sierrapy, and write JSON
plus summary CSV to results/. Sierra validationResults are surfaced in stderr
and as `validation` rows in the summary CSV.

options:
  -h, --help            show this help message and exit
  --input INPUT         FASTA file to process. If omitted, all FASTA files in
                        --data-dir are used.
  --data-dir DATA_DIR   Directory to scan for FASTA files when --input is not
                        set (default: data/).
  --results-dir RESULTS_DIR
                        Directory for JSON and CSV output (default: results/).
  --url URL             Optional Sierra GraphQL endpoint URL (default:
                        Stanford HIVDB production).
  --step STEP           Number of sequences per Sierra API batch (default:
                        20).
  --max-retries MAX_RETRIES
                        Maximum retry attempts for transient network/server
                        errors.
  --initial-backoff INITIAL_BACKOFF
                        Initial retry delay in seconds (default: 5).
  --backoff-multiplier BACKOFF_MULTIPLIER
                        Exponential backoff multiplier between retries
                        (default: 2).
```

---

## sierrapy CLI

### `sierrapy`

```
Usage: sierrapy [OPTIONS] COMMAND [ARGS]...

  A Client of HIVDB Sierra GraphQL Web Service

  Default endpoint URLs:

  - HIV1: https://hivdb.stanford.edu/graphql
  - HIV2: https://hivdb.stanford.edu/hiv2/graphql
  - SARS2: https://covdb.stanford.edu/sierra-sars2/graphql

Options:
  --url TEXT                 URL of Sierra GraphQL Web Service.  [default:
                             production URL varied by virus]
  --virus [HIV1|HIV2|SARS2]  Specify virus to be analyzed.  [default: HIV1]
  --version                  Show client and the HIVDB algorithm version.
  --help                     Show this message and exit.

Commands:
  fasta          Run alignment, drug resistance and other analysis for...
  introspection  Output introspection of Sierra GraphQL web service.
  mutations      Run drug resistance and other analysis for PR, RT and/or...
  patterns       Run drug resistance and other analysis for one or more...
  recipe         Post process Sierra web service output.
  seqreads       Run alignment, drug resistance and other analysis for...
```

## Sequence input

### `fasta`

```
Usage: sierrapy fasta [OPTIONS] FASTA...

  Run alignment, drug resistance and other analysis for one or more FASTA-
  format files contained DNA sequences.

Options:
  --url TEXT                 URL of Sierra GraphQL Web Service.  [default:
                             production URL varied by virus]
  --virus [HIV1|HIV2|SARS2]  Specify virus to be analyzed.  [default: HIV1]
  -q, --query FILENAME       A file contains GraphQL fragment definition on
                             `SequenceAnalysis`.
  -o, --output FILE          File path to store the JSON result.
  --sharding INTEGER         Save JSON result files per n sequences.
  --no-sharding              Save JSON result to a single file.
  --step INTEGER             Send batch requests per n sequences.
  --skip INTEGER             Skip first n sequences.
  --total INTEGER            Total number of sequences; specify one to
                             visualize a progress bar.
  --ugly                     Output compressed JSON result.
  --help                     Show this message and exit.
```

### `seqreads`

```
Usage: sierrapy seqreads [OPTIONS] SEQREADS

  Run alignment, drug resistance and other analysis for one or more tab-
  delimited text files contained codon reads of HIV-1 pol DNA sequences.

Options:
  --url TEXT                      URL of Sierra GraphQL Web Service.
                                  [default: production URL varied by virus]
  --virus [HIV1|HIV2|SARS2]       Specify virus to be analyzed.  [default:
                                  HIV1]
  -p, --pcnt-cutoff FLOAT         Minimal prevalence cutoff for this sequence
                                  reads (range: 0-1.0)  [default: 0.1]
  -m, --mixture-cutoff FLOAT      Maximum mixture rate for this sequence reads
                                  (range: 0-1.0)  [default: 0.0005]
  -d, --min-codon-reads INTEGER   Minimal read depth applied to each codon of
                                  this sequence  [default: 1]
  -D, --min-position-reads INTEGER
                                  Minimal read depth applied to each position
                                  of this sequence  [default: 1]
  -q, --query FILENAME            A file contains GraphQL fragment definition
                                  on `SequenceAnalysis`
  --ugly                          Output compressed JSON result
  --help                          Show this message and exit.
```

## Mutation input

### `mutations`

```
Usage: sierrapy mutations [OPTIONS] MUTATIONS...

  Run drug resistance and other analysis for PR, RT and/or IN mutations. For
  Example:

  sierrapy mutations PR:E35E_D RT:T67- IN:M50MI

  Use command "sierrapy patterns" instead if you want to run multiple sets of
  mutations in one request.

Options:
  --url TEXT                 URL of Sierra GraphQL Web Service.  [default:
                             production URL varied by virus]
  --virus [HIV1|HIV2|SARS2]  Specify virus to be analyzed.  [default: HIV1]
  -q, --query FILENAME       A file contains GraphQL fragment definition on
                             `MutationsAnalysis`.
  -o, --output FILENAME      File path to store the JSON result.
  --ugly                     Output compressed JSON result.
  --help                     Show this message and exit.
```

### `patterns`

```
Usage: sierrapy patterns [OPTIONS] PATTERNS...

  Run drug resistance and other analysis for one or more files contains lines
  of PR, RT and/or IN mutations based on HIV-1 type B consensus. Each line is
  treated as a unique pattern. For example:

  >set1
  RT:M41L + RT:M184V + RT:L210W + RT:T215Y
  >set2
  PR:L24I + PR:M46L + PR:I54V + PR:V82A

  The following delimiters are supported: commas (,), plus signs (+),
  semicolon(;), whitespaces and tabs. The consensus sequences can be retrieved
  from HIVDB website: <https://goo.gl/ZBthkt>.

Options:
  --url TEXT                 URL of Sierra GraphQL Web Service.  [default:
                             production URL varied by virus]
  --virus [HIV1|HIV2|SARS2]  Specify virus to be analyzed.  [default: HIV1]
  -q, --query FILENAME       A file contains GraphQL fragment definition on
                             `MutationsAnalysis`.
  -o, --output FILE          File path to store the JSON result.
  --sharding INTEGER         Save JSON result files per n patterns.
  --no-sharding              Save JSON result to a single file.
  --step INTEGER             Send batch requests per n patterns.
  --skip INTEGER             Skip first n patterns.
  --total INTEGER            Total number of patterns; specify one to
                             visualize a progress bar.
  --ugly                     Output compressed JSON result.
  --help                     Show this message and exit.
```

## Post-processing and introspection

### `recipe`

```
Usage: sierrapy recipe [OPTIONS] COMMAND [ARGS]...

  Post process Sierra web service output.

Options:
  --input FILENAME   JSON result from Sierra web service.
  --output FILENAME  File path to store the result.
  --help             Show this message and exit.

Commands:
  alignment    Export aligned pol sequences from Sierra result.
  mutationtsv  Export mutation set of each sequences from Sierra result.
  sequencetsv  Export mutation set of each sequences from Sierra result.
```

### `recipe alignment`

```
Usage: sierrapy recipe alignment [OPTIONS]

  Export aligned pol sequences from Sierra result.

Options:
  --gap-handling [squeeze|hxb2strip|hxb2stripkeepins]
                                  Specify how you want the recipe to handle
                                  the gaps.
                                  
                                  Specify "squeeze" to keep every gap in the
                                  result alignment; "hxb2strip" to strip out
                                  non-HXB2 columns; "hxb2stripkeepins" to
                                  strip not non-HXB2 columns except codon
                                  insertions.
  --help                          Show this message and exit.
```

### `recipe mutationtsv`

```
Usage: sierrapy recipe mutationtsv [OPTIONS]

  Export mutation set of each sequences from Sierra result.

Options:
  --help  Show this message and exit.
```

### `recipe sequencetsv`

```
Usage: sierrapy recipe sequencetsv [OPTIONS]

  Export mutation set of each sequences from Sierra result.

Options:
  --help  Show this message and exit.
```

### `introspection`

```
Usage: sierrapy introspection [OPTIONS]

  Output introspection of Sierra GraphQL web service.

Options:
  -o, --output FILENAME  File path to store the JSON result.
  --ugly                 Output compressed JSON result.
  --help                 Show this message and exit.
```
