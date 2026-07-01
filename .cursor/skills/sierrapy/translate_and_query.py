#!/usr/bin/env python3
"""
translate_and_query.py — Load HIV pol FASTA input, query Stanford HIVDB via
sierrapy, and write raw JSON plus a summary CSV to results/.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from pathlib import Path
from typing import Any, Iterator

from Bio import SeqIO
from requests.exceptions import ConnectionError, HTTPError, Timeout
from sierrapy.fragments import HIV1_SEQUENCE_ANALYSIS_DEFAULT
from sierrapy.sierraclient import ResponseError, SierraClient


FASTA_GLOBS = ("*.fasta", "*.fa", "*.fas", "*.fna")

DEFAULT_MAX_RETRIES = 5
DEFAULT_INITIAL_BACKOFF_S = 5.0
DEFAULT_BACKOFF_MULTIPLIER = 2.0
DEFAULT_QUERY_STEP = 20

RETRYABLE_HTTP_CODES = {429, 500, 502, 503, 504}


def discover_fasta_files(data_dir: Path) -> list[Path]:
    files: list[Path] = []
    for pattern in FASTA_GLOBS:
        files.extend(data_dir.glob(pattern))
    return sorted({path.resolve() for path in files})


def load_sequences(fasta_path: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    for record in SeqIO.parse(fasta_path, "fasta"):
        sequence = str(record.seq).upper().replace("U", "T")
        records.append({"header": record.id, "sequence": sequence})
    if not records:
        raise ValueError(f"No sequences found in {fasta_path}")
    return records


def is_retryable_error(exc: BaseException) -> bool:
    if isinstance(exc, (ConnectionError, Timeout, ResponseError)):
        return True
    if isinstance(exc, HTTPError) and exc.response is not None:
        return exc.response.status_code in RETRYABLE_HTTP_CODES
    return False


def query_sierra(
    records: list[dict[str, str]],
    *,
    url: str | None,
    step: int,
    max_retries: int,
    initial_backoff_s: float,
    backoff_multiplier: float,
) -> list[dict[str, Any]]:
    client = SierraClient(url) if url else SierraClient()
    client.toggle_progress(False)
    last_error: BaseException | None = None

    for attempt in range(1, max_retries + 1):
        try:
            return client.sequence_analysis(records, HIV1_SEQUENCE_ANALYSIS_DEFAULT, step)
        except BaseException as exc:
            if not is_retryable_error(exc) or attempt == max_retries:
                raise
            last_error = exc
            delay = initial_backoff_s * (backoff_multiplier ** (attempt - 1))
            print(
                f"Sierra query failed (attempt {attempt}/{max_retries}): {exc}. "
                f"Retrying in {delay:.1f}s...",
                file=sys.stderr,
            )
            time.sleep(delay)

    raise RuntimeError("Sierra query failed") from last_error


def print_validation_results(analyses: list[dict[str, Any]]) -> None:
    for analysis in analyses:
        seq_id = analysis.get("inputSequence", {}).get("header", "")
        for validation in analysis.get("validationResults", []):
            level = validation.get("level", "NOTICE")
            message = validation.get("message", "")
            print(
                f"  Sierra {level}: [{seq_id}] {message}",
                file=sys.stderr,
            )


def iter_summary_rows(analysis: dict[str, Any]) -> Iterator[dict[str, Any]]:
    seq_id = analysis.get("inputSequence", {}).get("header", "")
    subtype = analysis.get("subtypeText", "")

    for validation in analysis.get("validationResults", []):
        yield {
            "sequence_id": seq_id,
            "subtype": subtype,
            "record_type": "validation",
            "gene": "",
            "first_aa": "",
            "last_aa": "",
            "gene_length": "",
            "position": "",
            "mutation": validation.get("message", ""),
            "drug_class": "",
            "drug": "",
            "score": "",
            "level": validation.get("level", ""),
        }

    for aligned in analysis.get("alignedGeneSequences", []):
        gene = aligned.get("gene", {}).get("name", "")
        yield {
            "sequence_id": seq_id,
            "subtype": subtype,
            "record_type": "gene",
            "gene": gene,
            "first_aa": aligned.get("firstAA", ""),
            "last_aa": aligned.get("lastAA", ""),
            "gene_length": aligned.get("gene", {}).get("length", ""),
            "position": "",
            "mutation": "",
            "drug_class": "",
            "drug": "",
            "score": "",
            "level": "",
        }

        for mutation in aligned.get("mutations", []):
            yield {
                "sequence_id": seq_id,
                "subtype": subtype,
                "record_type": "mutation",
                "gene": gene,
                "first_aa": "",
                "last_aa": "",
                "gene_length": "",
                "position": mutation.get("position", ""),
                "mutation": mutation.get("text", mutation.get("AAs", "")),
                "drug_class": "",
                "drug": "",
                "score": "",
                "level": "",
            }

    for resistance in analysis.get("drugResistance", []):
        gene = resistance.get("gene", {}).get("name", "")
        for drug_score in resistance.get("drugScores", []):
            drug = drug_score.get("drug", {})
            yield {
                "sequence_id": seq_id,
                "subtype": subtype,
                "record_type": "drug_score",
                "gene": gene,
                "first_aa": "",
                "last_aa": "",
                "gene_length": "",
                "position": "",
                "mutation": drug_score.get("text", ""),
                "drug_class": drug_score.get("drugClass", {}).get("name", ""),
                "drug": drug.get("name", drug.get("displayAbbr", "")),
                "score": drug_score.get("score", ""),
                "level": drug_score.get("level", ""),
            }


def write_summary_csv(analyses: list[dict[str, Any]], csv_path: Path) -> None:
    fieldnames = [
        "sequence_id",
        "subtype",
        "record_type",
        "gene",
        "first_aa",
        "last_aa",
        "gene_length",
        "position",
        "mutation",
        "drug_class",
        "drug",
        "score",
        "level",
    ]
    rows = [row for analysis in analyses for row in iter_summary_rows(analysis)]
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def process_fasta(
    records: list[dict[str, str]],
    fasta_path: Path,
    results_dir: Path,
    *,
    url: str | None,
    step: int,
    max_retries: int,
    initial_backoff_s: float,
    backoff_multiplier: float,
) -> tuple[Path, Path]:
    analyses = query_sierra(
        records,
        url=url,
        step=step,
        max_retries=max_retries,
        initial_backoff_s=initial_backoff_s,
        backoff_multiplier=backoff_multiplier,
    )
    print_validation_results(analyses)

    stem = fasta_path.stem
    json_path = results_dir / f"{stem}_sierra.json"
    csv_path = results_dir / f"{stem}_summary.csv"

    with json_path.open("w", encoding="utf-8") as handle:
        json.dump(analyses, handle, indent=2)
    write_summary_csv(analyses, csv_path)

    return json_path, csv_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Load HIV FASTA sequences, query Stanford HIVDB via sierrapy, "
            "and write JSON plus summary CSV to results/."
        )
    )
    parser.add_argument(
        "--input",
        type=Path,
        help="FASTA file to process. If omitted, all FASTA files in --data-dir are used.",
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path.cwd() / "data",
        help="Directory to scan for FASTA files when --input is not set (default: ./data).",
    )
    parser.add_argument(
        "--results-dir",
        type=Path,
        default=Path.cwd() / "results",
        help="Directory for JSON and CSV output (default: ./results).",
    )
    parser.add_argument(
        "--url",
        default=None,
        help="Optional Sierra GraphQL endpoint URL (default: Stanford HIVDB production).",
    )
    parser.add_argument(
        "--step",
        type=int,
        default=DEFAULT_QUERY_STEP,
        help="Number of sequences per Sierra API batch (default: 20).",
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=DEFAULT_MAX_RETRIES,
        help="Maximum retry attempts for transient network/server errors.",
    )
    parser.add_argument(
        "--initial-backoff",
        type=float,
        default=DEFAULT_INITIAL_BACKOFF_S,
        help="Initial retry delay in seconds (default: 5).",
    )
    parser.add_argument(
        "--backoff-multiplier",
        type=float,
        default=DEFAULT_BACKOFF_MULTIPLIER,
        help="Exponential backoff multiplier between retries (default: 2).",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    results_dir = args.results_dir.resolve()
    results_dir.mkdir(parents=True, exist_ok=True)

    if args.input:
        fasta_files = [args.input.resolve()]
    else:
        data_dir = args.data_dir.resolve()
        if not data_dir.is_dir():
            print(f"error: data directory not found: {data_dir}", file=sys.stderr)
            return 1
        fasta_files = discover_fasta_files(data_dir)
        if not fasta_files:
            print(
                f"error: no FASTA files found in {data_dir} "
                f"(patterns: {', '.join(FASTA_GLOBS)})",
                file=sys.stderr,
            )
            return 1

    for fasta_path in fasta_files:
        if not fasta_path.is_file():
            print(f"error: FASTA file not found: {fasta_path}", file=sys.stderr)
            return 1

        records = load_sequences(fasta_path)
        print(f"Processing {fasta_path} ({len(records)} sequence(s))...")
        json_path, csv_path = process_fasta(
            records,
            fasta_path,
            results_dir,
            url=args.url,
            step=args.step,
            max_retries=args.max_retries,
            initial_backoff_s=args.initial_backoff,
            backoff_multiplier=args.backoff_multiplier,
        )
        print(f"  Wrote {json_path}")
        print(f"  Wrote {csv_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
