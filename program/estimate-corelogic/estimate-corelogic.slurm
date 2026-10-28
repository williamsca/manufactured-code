#!/bin/bash
#SBATCH --job-name=estimate-corelogic
#SBATCH --output=estimate-corelogic_%j.out
#SBATCH --error=estimate-corelogic_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --account=econ-public
#SBATCH --partition=standard

# CoreLogic estimation on Rivanna. Normally launched from a local checkout by
#   ./run_remote.sh estimate-corelogic [SCRIPT]
# which submits this file from program/estimate-corelogic/ in ~/manufactured-code.
# With SCRIPT unset, every script runs in dependency order (~10 minutes in
# October 2026); otherwise only SCRIPT runs.
#
# Each script writes everything, including licensed record-level files and
# fitted models, to a new private directory
#   $CORELOGIC_RESULTS_ROOT/<name>/<job id>/
# and `current` in that folder is repointed to it on success. Only aggregate
# tables, figures and manifests are copied to output/corelogic/<name>/ in the
# checkout, which is the only thing run_remote.sh downloads.

set -euo pipefail
source "$HOME/load_r.sh"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"

REPO="$(cd "$SLURM_SUBMIT_DIR/../.." && pwd)"
cd "$REPO"

# Pinned inputs. Override any of them by exporting it before sbatch (or
# locally before run_remote.sh, which forwards them).
CL_ROOT="/scratch/$USER/manufactured-code"
export CORELOGIC_BUILD="${CORELOGIC_BUILD:-$CL_ROOT/corelogic/continental-v3-20261020}"
export CORELOGIC_REFERENCE="${CORELOGIC_REFERENCE:-$CL_ROOT/public-reference}"
export CORELOGIC_PB_SOURCE="${CORELOGIC_PB_SOURCE:-/scratch/$USER/research-database/licensed/curated/cl_property_basic/v2026-10-07}"
CORELOGIC_RESULTS_ROOT="${CORELOGIC_RESULTS_ROOT:-$CL_ROOT/corelogic-results}"
ALL_SCRIPTS=(
    estimate-corelogic-prices.R
    estimate-corelogic-quantities.R
)

# Short result name and synthetic known-truth check for each script.
result_name() {
    local base
    base="$(basename "$1" .R)"
    echo "${base#estimate-corelogic-}"
}
check_for() {
    case "$1" in
        prices|quantities) echo program/tests/check-corelogic-mh-only.R ;;
    esac
}

echo "=============================================="
echo "Job ${SLURM_JOB_ID} on ${SLURM_NODELIST} started $(date)"
echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo "CORELOGIC_BUILD=${CORELOGIC_BUILD}"
echo "CORELOGIC_REFERENCE=${CORELOGIC_REFERENCE}"
echo "CORELOGIC_PB_SOURCE=${CORELOGIC_PB_SOURCE}"
echo "=============================================="

if [ -z "${SCRIPT:-}" ]; then
    SCRIPTS=("${ALL_SCRIPTS[@]}")
else
    SCRIPTS=("$(basename "$SCRIPT")")
fi

for script in "${SCRIPTS[@]}"; do
    if [ ! -f "program/estimate-corelogic/${script}" ]; then
        echo "ERROR: program/estimate-corelogic/${script} not found" >&2
        exit 1
    fi
    name="$(result_name "$script")"
    check="$(check_for "$name")"
    private_dir="${CORELOGIC_RESULTS_ROOT}/${name}/${SLURM_JOB_ID}"
    export_dir="${REPO}/output/corelogic/${name}"

    echo ""
    echo "== ${script} -> ${private_dir}  ($(date))"
    if [ -n "$check" ]; then
        echo "Synthetic check: ${check}"
        Rscript "$check"
    fi
    CORELOGIC_RESULTS="$private_dir" Rscript "program/estimate-corelogic/${script}"

    # Point `current` at this run.
    ln -sfn "$SLURM_JOB_ID" "${CORELOGIC_RESULTS_ROOT}/${name}/current"

    # Export aggregates only: no parquet, rds, archived source or DuckDB spill.
    rm -rf "$export_dir"
    mkdir -p "$export_dir"
    find "$private_dir" -maxdepth 1 -type f \
        \( -name '*.csv' -o -name '*.pdf' -o -name '*.png' -o -name '*.json' -o -name '*.tex' \) \
        -exec cp {} "$export_dir/" \;
    printf 'job: %s\ncommit: %s\nprivate_results: %s\n' "$SLURM_JOB_ID" \
        "$(git rev-parse HEAD 2>/dev/null || echo unknown)" "$private_dir" \
        > "$export_dir/remote-run.txt"
    echo "Exported $(find "$export_dir" -type f | wc -l) files to output/corelogic/${name}/"
done

echo ""
echo "Job finished $(date)"
