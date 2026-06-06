#!/usr/bin/env python3
import sys
import os
import subprocess
import yaml
import json
import jsonschema
from pathlib import Path


def load_schema(schema_path):
    with open(schema_path) as f:
        return yaml.safe_load(f)


def check_tool_in_path(cmd, version_flag="--version"):
    try:
        result = subprocess.run(
            [cmd, version_flag],
            capture_output=True, text=True, timeout=10
        )
        return result.returncode == 0, result.stdout + result.stderr
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, ""


def run(config_path, samples_path):
    errors = []
    checks_passed = 0

    # 1. config.yaml exists
    if not Path(config_path).exists():
        errors.append((
            f"Config file not found: {config_path}",
            "Copy config/config.yaml.example to config/config.yaml and fill in your paths"
        ))
        print_result(errors, checks_passed)
        return

    checks_passed += 1

    # 2. config.yaml is valid YAML
    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        errors.append((f"config.yaml is not valid YAML: {e}", "Fix syntax errors in config/config.yaml"))
        print_result(errors, checks_passed)
        return

    checks_passed += 1

    # 3. JSON schema validation
    schema_path = Path("workflow/schemas/config.schema.yaml")
    if schema_path.exists():
        schema = load_schema(schema_path)
        try:
            jsonschema.validate(config, schema)
            checks_passed += 1
        except jsonschema.ValidationError as e:
            errors.append((f"config.yaml schema error: {e.message}", f"Fix '{e.path[-1] if e.path else 'config'}' in config/config.yaml"))
    else:
        checks_passed += 1  # schema missing — skip silently

    # 4. samples.tsv exists
    if not Path(samples_path).exists():
        errors.append((
            f"Samples file not found: {samples_path}",
            "Copy config/samples.tsv.example to config/samples.tsv and fill in your sample paths"
        ))
    else:
        checks_passed += 1

        # 5 & 6. Parse samples and check R1/R2 files
        try:
            with open(samples_path) as f:
                for lineno, line in enumerate(f, 1):
                    line = line.rstrip("\n")
                    if line.startswith("#") or not line.strip():
                        continue
                    parts = line.split("\t")
                    if len(parts) != 3:
                        errors.append((
                            f"samples.tsv line {lineno}: expected 3 tab-separated columns, got {len(parts)}",
                            "Format: SampleID<TAB>R1.fastq<TAB>R2.fastq"
                        ))
                        continue
                    sample, r1, r2 = parts
                    for label, path in [("R1", r1), ("R2", r2)]:
                        p = Path(path.strip())
                        if not p.exists():
                            errors.append((
                                f"Sample '{sample}' {label} not found: {path}",
                                f"Check samples.tsv line {lineno}"
                            ))
                        elif p.stat().st_size == 0:
                            errors.append((
                                f"Sample '{sample}' {label} is empty: {path}",
                                f"Check samples.tsv line {lineno}"
                            ))
                        else:
                            checks_passed += 1
        except Exception as e:
            errors.append((f"Failed to parse samples.tsv: {e}", "Check file format and encoding"))

    # 7. Reference FASTA
    ref = config.get("reference", "")
    if not ref:
        errors.append(("'reference' not set in config.yaml", "Set reference: /full/path/to/silva.bacteria.fasta"))
    else:
        p = Path(ref)
        if not p.exists():
            errors.append((f"Reference FASTA not found: {ref}", "Download SILVA from http://www.mothur.org/wiki/Silva_reference_files"))
        elif p.stat().st_size == 0:
            errors.append((f"Reference FASTA is empty: {ref}", "Re-download the SILVA reference file"))
        else:
            checks_passed += 1

    # 8. USEARCH exists and is executable
    usearch = config.get("usearch", "")
    if not usearch:
        errors.append(("'usearch' not set in config.yaml", "Set usearch: /full/path/to/usearch8.1.1861"))
    else:
        p = Path(usearch)
        if not p.exists():
            errors.append((f"USEARCH not found at: {usearch}", "Download from http://www.drive5.com/usearch/ and update config.yaml"))
        elif not os.access(usearch, os.X_OK):
            errors.append((f"USEARCH not executable: {usearch}", f"Run: chmod +x {usearch}"))
        else:
            checks_passed += 1

            # 9. USEARCH version check
            ok, output = check_tool_in_path(usearch, "--version")
            if not ok or "8.1" not in output:
                errors.append((
                    f"USEARCH version mismatch (expected 8.1.x): {output.strip()[:80]}",
                    "Download usearch8.1.1861 from http://www.drive5.com/usearch/"
                ))
            else:
                checks_passed += 1

    # 10. Java in PATH
    ok, _ = check_tool_in_path("java", "-version")
    if not ok:
        errors.append(("Java not found in PATH", "Install Java 8: conda install -n base openjdk=8"))
    else:
        checks_passed += 1

    # 11. Perl in PATH
    ok, _ = check_tool_in_path("perl", "--version")
    if not ok:
        errors.append(("Perl not found in PATH", "Install Perl: conda install -n base perl"))
    else:
        checks_passed += 1

    # 12. Output directory parent writable
    results_parent = Path(".")
    if not os.access(results_parent, os.W_OK):
        errors.append((
            f"Working directory is not writable: {results_parent.resolve()}",
            "Check directory permissions"
        ))
    else:
        checks_passed += 1

    print_result(errors, checks_passed)


def print_result(errors, checks_passed):
    if errors:
        print("[OCToPUS pre-flight FAILED]")
        for msg, fix in errors:
            print(f"  ✗ {msg}")
            print(f"    → {fix}")
        sys.exit(1)
    else:
        print(f"[OCToPUS pre-flight OK] All {checks_passed} checks passed.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <config.yaml> <samples.tsv>")
        sys.exit(1)
    run(sys.argv[1], sys.argv[2])
