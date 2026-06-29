# Changelog — sierrapy

## [Unreleased]

- Removed local fail-fast CDS validation (length, stop codons); sequences are
  always sent to Sierra unless the FASTA or request is invalid
- Added: surface Sierra `validationResults` on stderr and as `validation` rows
  in the summary CSV while still writing full results

## [2026-06-17] — Initial skill
- Tool version: SierraPy 0.4.3 (check with `sierrapy --version`)
- Skill version: 1.0.0
- Added: initial SKILL.md, reference.md, patterns.md, environment.yaml
- Added: `translate_and_query.py` pipeline (FASTA validation, Sierra query, JSON + summary CSV)
