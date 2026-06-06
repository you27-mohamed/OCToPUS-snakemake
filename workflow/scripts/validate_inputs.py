#!/usr/bin/env python3
"""Pre-flight validation for OCToPUS Snakemake pipeline.

Usage: python workflow/scripts/validate_inputs.py <config.yaml> <samples.tsv>

Runs all 12 checks and collects every error before reporting.
Exits 1 if any check fails, 0 if all pass.
"""
import sys
import os
import subprocess
from pathlib import Path

import yaml
import jsonschema

SCHEMA_PATH = Path("workflow/schemas/config.schema.yaml")


def check_cmd(cmd, args=("--version",)):
    """Return (ok, output_str). ok=True if exit code 0."""
    try:
        result = subprocess.run(
            [cmd, *args], capture_output=True, text=True, timeout=10
        )
        return result.returncode == 0, (result.stdout + result.stderr).strip()
    except FileNotFoundError:
        return False, ""
    except subprocess.TimeoutExpired:
        return False, "timed out"


def run(config_path, samples_path):
    errors = []
    total_checks = 12

    # --- config.yaml checks (1-3) ---
    config = None

    # Check 1: config exists
    if not Path(config_path).exists():
        errors.append((
            f"Config file not found: {config_path}",
            "Copy config/config.yaml.example to config/config.yaml and fill in your paths"
        ))
    else:
        # Check 2: valid YAML
        try:
            with open(config_path) as f:
                config = yaml.safe_load(f)
        except yaml.YAMLError as e:
            errors.append((f"config.yaml is not valid YAML: {e}", "Fix YAML syntax errors in config/config.yaml"))

    # Check 3: schema validation (runs even if config failed to load)
    if not SCHEMA_PATH.exists():
        errors.append((
            f"Schema file not found: {SCHEMA_PATH}",
            "Ensure workflow/schemas/config.schema.yaml exists in the repo"
        ))
    elif config is not None:
        try:
            schema = yaml.safe_load(SCHEMA_PATH.read_text())
            jsonschema.validate(config, schema)
        except jsonschema.ValidationError as e:
            field = e.path[-1] if e.path else "unknown field"
            errors.append((
                f"config.yaml validation error at '{field}': {e.message}",
                f"Fix '{field}' in config/config.yaml"
            ))
        except Exception as e:
            errors.append((f"Schema validation failed: {e}", "Check workflow/schemas/config.schema.yaml"))

    # --- samples.tsv checks (4-6) ---
    # Check 4: samples.tsv exists
    if not Path(samples_path).exists():
        errors.append((
            f"Samples file not found: {samples_path}",
            "Copy config/samples.tsv.example to config/samples.tsv and fill in your sample paths"
        ))
    else:
        # Check 5+6: parse and validate each sample's files
        sample_files_ok = True
        try:
            with open(samples_path) as f:
                for lineno, raw in enumerate(f, 1):
                    line = raw.rstrip("\n")
                    if line.startswith("#") or not line.strip():
                        continue
                    parts = line.split("\t")
                    if len(parts) != 3:
                        errors.append((
                            f"samples.tsv line {lineno}: expected 3 tab-separated columns, got {len(parts)}",
                            "Format: SampleID<TAB>R1.fastq<TAB>R2.fastq"
                        ))
                        sample_files_ok = False
                        continue
                    sample, r1, r2 = [p.strip() for p in parts]
                    for label, fpath in [("R1", r1), ("R2", r2)]:
                        p = Path(fpath)
                        if not p.exists():
                            errors.append((
                                f"Sample '{sample}' {label} not found: {fpath}",
                                f"Check samples.tsv line {lineno}"
                            ))
                            sample_files_ok = False
                        elif p.stat().st_size == 0:
                            errors.append((
                                f"Sample '{sample}' {label} is empty: {fpath}",
                                f"Check samples.tsv line {lineno}"
                            ))
                            sample_files_ok = False
        except Exception as e:
            errors.append((f"Failed to read samples.tsv: {e}", "Check file encoding and format"))

    # --- Reference FASTA check (7) ---
    # Independent of samples.tsv — runs even if samples.tsv check failed
    ref = (config or {}).get("reference", "")
    if not ref:
        errors.append(("'reference' not set in config.yaml", "Set reference: /full/path/to/silva.bacteria.fasta"))
    else:
        p = Path(ref)
        if not p.exists():
            errors.append((f"Reference FASTA not found: {ref}", "Download SILVA from http://www.mothur.org/wiki/Silva_reference_files"))
        elif p.stat().st_size == 0:
            errors.append((f"Reference FASTA is empty: {ref}", "Re-download the SILVA reference file"))

    # --- USEARCH checks (8-9) ---
    usearch = (config or {}).get("usearch", "")
    if not usearch:
        errors.append(("'usearch' not set in config.yaml", "Set usearch: /full/path/to/usearch8.1.1861"))
    else:
        p = Path(usearch)
        if not p.exists():
            errors.append((f"USEARCH not found: {usearch}", "Download from http://www.drive5.com/usearch/ and update config.yaml"))
        elif not os.access(usearch, os.X_OK):
            errors.append((f"USEARCH not executable: {usearch}", f"Run: chmod +x {usearch}"))
            # Check 9 skipped — can't invoke non-executable binary
            total_checks -= 1
        else:
            # Check 9: version — only reachable if binary exists + executable
            ok, output = check_cmd(usearch, ["--version"])
            if not ok or "8.1" not in output:
                errors.append((
                    f"USEARCH version mismatch (expected 8.1.x, got: {output[:80] or 'no output'})",
                    "Download usearch8.1.1861 from http://www.drive5.com/usearch/"
                ))

    # --- Java check (10) ---
    ok, _ = check_cmd("java", ["-version"])
    if not ok:
        errors.append(("Java not found in PATH (required for WEKA/CATCh)", "Install: conda install -c conda-forge openjdk=8"))

    # --- Perl check (11) ---
    ok, _ = check_cmd("perl", ["--version"])
    if not ok:
        errors.append(("Perl not found in PATH (required for IPED, CATCh, mothur2uparse)", "Install: conda install -c conda-forge perl"))

    # --- Writable directory check (12) ---
    cwd = Path(".")
    if not os.access(cwd, os.W_OK):
        errors.append((
            f"Current directory is not writable: {cwd.resolve()}",
            "Check directory permissions — results/ will be written here"
        ))

    # --- Report ---
    if errors:
        print("[OCToPUS pre-flight FAILED]")
        for msg, fix in errors:
            print(f"  ✗ {msg}")
            print(f"    → {fix}")
        sys.exit(1)
    else:
        print(f"[OCToPUS pre-flight OK] All {total_checks} checks passed.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <config.yaml> <samples.tsv>", file=sys.stderr)
        sys.exit(1)
    run(sys.argv[1], sys.argv[2])
