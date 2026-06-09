#!/usr/bin/env bash
# OCToPUS setup wizard — generates config/config.yaml interactively
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║        OCToPUS Setup Wizard           ║"
echo "  ║  16S rRNA Amplicon Pipeline Config    ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ── helpers ──────────────────────────────────────────────────────────────────

ask() {
    # ask <varname> <prompt> [default]
    local varname="$1" prompt="$2" default="${3:-}"
    local val=""
    while true; do
        if [ -n "$default" ]; then
            read -rp "  $prompt [$default]: " val
            val="${val:-$default}"
        else
            read -rp "  $prompt: " val
        fi
        [ -n "$val" ] && break
        echo -e "  ${RED}Cannot be empty.${NC}"
    done
    printf -v "$varname" '%s' "$val"
}

ask_yn() {
    # ask_yn <prompt> — returns 0 (yes) or 1 (no)
    local prompt="$1" ans
    while true; do
        read -rp "  $prompt [y/n]: " ans
        case "$ans" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo -e "  ${RED}Enter y or n.${NC}" ;;
        esac
    done
}

ask_int() {
    local varname="$1" prompt="$2" default="$3" val
    while true; do
        read -rp "  $prompt [$default]: " val
        val="${val:-$default}"
        [[ "$val" =~ ^[0-9]+$ ]] && break
        echo -e "  ${RED}Must be a number.${NC}"
    done
    printf -v "$varname" '%s' "$val"
}

check_file() {
    local path="$1"
    [ -f "$path" ] && [ -s "$path" ]
}

# ── run_id ───────────────────────────────────────────────────────────────────

echo -e "\n${YELLOW}[1/6] Run identifier${NC}"
echo "  Output goes to results/<run_id>/. Use a short, descriptive name."
ask RUN_ID "Run ID (e.g. study1, pilot_run)" "my_run"

# ── samples.tsv ──────────────────────────────────────────────────────────────

echo -e "\n${YELLOW}[2/6] Samples file${NC}"
echo "  Tab-separated: SampleID<TAB>R1.fastq<TAB>R2.fastq"
echo "  Template: config/samples.tsv.example"
ask SAMPLES_PATH "Path to samples TSV" "config/samples.tsv"

# ── SILVA reference ───────────────────────────────────────────────────────────

echo -e "\n${YELLOW}[3/6] SILVA reference (silva.nr_v132.align)${NC}"

# Auto-detect common locations
SILVA_CANDIDATES=(
    "data/silva.nr_v132.align"
    "$HOME/silva.nr_v132.align"
    "$HOME/data/silva.nr_v132.align"
    "/data/silva.nr_v132.align"
    "/opt/silva/silva.nr_v132.align"
)
SILVA_FOUND=""
for c in "${SILVA_CANDIDATES[@]}"; do
    if check_file "$c"; then
        SILVA_FOUND="$c"
        break
    fi
done

if [ -n "$SILVA_FOUND" ]; then
    echo -e "  ${GREEN}Auto-detected:${NC} $SILVA_FOUND"
    if ask_yn "Use this SILVA reference?"; then
        SILVA_PATH="$SILVA_FOUND"
    else
        SILVA_FOUND=""
    fi
fi

if [ -z "$SILVA_FOUND" ]; then
    echo "  Download: http://www.mothur.org/wiki/Silva_reference_files"
    echo "  After download, place at data/silva.nr_v132.align (or any path)."
    while true; do
        ask SILVA_PATH "Full path to silva.nr_v132.align"
        if check_file "$SILVA_PATH"; then
            echo -e "  ${GREEN}✓ Found${NC}"
            break
        else
            echo -e "  ${RED}File not found or empty: $SILVA_PATH${NC}"
            if ask_yn "Enter a different path?"; then
                continue
            else
                echo -e "  ${YELLOW}Warning: path saved but file not found. Pipeline will fail at align.seqs.${NC}"
                break
            fi
        fi
    done
fi

# ── USEARCH ──────────────────────────────────────────────────────────────────

echo -e "\n${YELLOW}[4/6] USEARCH 8.1.1861${NC}"
echo "  Free 32-bit binary — license prevents redistribution."
echo "  Download: http://www.drive5.com/usearch/"

USEARCH_CANDIDATES=(
    "data/usearch8.1.1861"
    "$HOME/usearch8.1.1861"
    "$HOME/bin/usearch8.1.1861"
    "/usr/local/bin/usearch8.1.1861"
)
USEARCH_FOUND=""
for c in "${USEARCH_CANDIDATES[@]}"; do
    if check_file "$c" && [ -x "$c" ]; then
        USEARCH_FOUND="$c"
        break
    fi
done

if [ -n "$USEARCH_FOUND" ]; then
    echo -e "  ${GREEN}Auto-detected:${NC} $USEARCH_FOUND"
    if ask_yn "Use this USEARCH binary?"; then
        USEARCH_PATH="$USEARCH_FOUND"
    else
        USEARCH_FOUND=""
    fi
fi

if [ -z "$USEARCH_FOUND" ]; then
    while true; do
        ask USEARCH_PATH "Full path to usearch8.1.1861"
        if [ ! -f "$USEARCH_PATH" ]; then
            echo -e "  ${RED}File not found: $USEARCH_PATH${NC}"
            ask_yn "Enter a different path?" || { echo -e "  ${YELLOW}Warning: path saved but file not found.${NC}"; break; }
        elif [ ! -x "$USEARCH_PATH" ]; then
            echo -e "  ${YELLOW}File not executable. Running: chmod +x $USEARCH_PATH${NC}"
            chmod +x "$USEARCH_PATH"
            echo -e "  ${GREEN}✓ Fixed${NC}"
            break
        else
            echo -e "  ${GREEN}✓ Found${NC}"
            break
        fi
    done
fi

# ── processors ───────────────────────────────────────────────────────────────

echo -e "\n${YELLOW}[5/6] CPU cores${NC}"
TOTAL_CORES=$(nproc 2>/dev/null || echo "4")
RECOMMENDED=$(( TOTAL_CORES > 2 ? TOTAL_CORES - 4 : 1 ))
echo "  Detected $TOTAL_CORES cores on this machine."
echo "  Recommended: leave 4 free for OS → $RECOMMENDED cores for pipeline."
ask_int PROCESSORS "Cores to use" "$RECOMMENDED"

# ── advanced params ───────────────────────────────────────────────────────────

echo -e "\n${YELLOW}[6/6] Advanced parameters${NC}"
if ask_yn "Use default OCToPUS QC parameters? (recommended for first run)"; then
    MAXAMBIG=0; MAXHOMOP=8; MINLENGTH=200; ALIGN_CRITERIA=95
    MIN_SIZE=2; IDENTITY=0.97
else
    echo ""
    ask_int MAXAMBIG    "mothur maxambig  (max ambiguous bases)"     "0"
    ask_int MAXHOMOP    "mothur maxhomop  (max homopolymer run)"     "8"
    ask_int MINLENGTH   "mothur minlength (min sequence length)"     "200"
    ask_int ALIGN_CRITERIA "mothur align_criteria (screen.seqs %)" "95"
    ask_int MIN_SIZE    "UPARSE min_size  (filter singletons)"       "2"
    ask      IDENTITY   "UPARSE identity  (OTU clustering threshold)" "0.97"
fi

# ── write config.yaml ────────────────────────────────────────────────────────

mkdir -p config

cat > config/config.yaml <<YAML
# OCToPUS Snakemake Pipeline — Configuration
# Generated by setup.sh on $(date)

run_id: "${RUN_ID}"

samples: "${SAMPLES_PATH}"

# SILVA nr_v132 reference alignment
reference: "${SILVA_PATH}"

# USEARCH 8.1.1861 binary
usearch: "${USEARCH_PATH}"

# CPU cores per tool invocation
processors: ${PROCESSORS}

mothur:
  maxambig: ${MAXAMBIG}
  maxhomop: ${MAXHOMOP}
  minlength: ${MINLENGTH}
  align_criteria: ${ALIGN_CRITERIA}

uparse:
  min_size: ${MIN_SIZE}
  identity: ${IDENTITY}
YAML

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  config/config.yaml written successfully.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo "  1. Edit config/samples.tsv  (or copy from samples.tsv.example)"
echo "  2. Validate:  python workflow/scripts/validate_inputs.py config/config.yaml config/samples.tsv"
echo "  3. Dry run:   snakemake --use-conda --cores ${PROCESSORS} --dry-run"
echo "  4. Full run:  nohup snakemake --use-conda --cores ${PROCESSORS} --resources mem_mb=14000 > run.log 2>&1 &"
echo ""
