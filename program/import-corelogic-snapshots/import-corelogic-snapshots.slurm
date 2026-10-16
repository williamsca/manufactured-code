#!/bin/bash
#SBATCH --job-name=import-corelogic-snapshots
#SBATCH --output=import-corelogic-snapshots_%j.out
#SBATCH --error=import-corelogic-snapshots_%j.err
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --account=econ-public
#SBATCH --partition=standard

# Historical CoreLogic Property Basic snapshots -> parcel x snapshot panel for a few
# counties, then aggregate tabulations. Normally launched from a local checkout by
#   ./run_remote.sh import-corelogic-snapshots [SCRIPT]
# which submits this file from program/import-corelogic-snapshots/ in ~/manufactured-code.
# With SCRIPT unset, the panel is built and then tabulated; SCRIPT=
# import-corelogic-snapshots-tabulate.R re-tabulates the latest panel only.
#
# Each script writes everything, including the licensed panel, to a new private
# directory $SNAPSHOT_RESULTS_ROOT/<name>/<job id>/ and repoints `current` there on
# success. Only aggregate CSV/JSON files are copied to
# results/import-corelogic-snapshots/<name>/ in the checkout, the only thing
# run_remote.sh downloads.

set -euo pipefail
source "$HOME/load_r.sh"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"

REPO="$(cd "$SLURM_SUBMIT_DIR/../.." && pwd)"
cd "$REPO"

ROOT="/scratch/$USER/manufactured-code/corelogic-snapshots"
SNAPSHOT_RESULTS_ROOT="${SNAPSHOT_RESULTS_ROOT:-$ROOT}"
export SNAPSHOT_SOURCE="${SNAPSHOT_SOURCE:-/project/crebe_hufl_corelogic/historic_property}"
export SNAPSHOT_DELIVERY="${SNAPSHOT_DELIVERY:-2024081[45]}"
export SNAPSHOT_COUNTIES="${SNAPSHOT_COUNTIES:-12071,12015,12005,12045,04013}"
export SNAPSHOT_DUCKDB_MEMORY="${SNAPSHOT_DUCKDB_MEMORY:-40GB}"
ALL_SCRIPTS=(
    import-corelogic-snapshots-panel.R
    import-corelogic-snapshots-tabulate.R
)

result_name() {
    local base
    base="$(basename "$1" .R)"
    echo "${base#import-corelogic-snapshots-}"
}

echo "=============================================="
echo "Job ${SLURM_JOB_ID} on ${SLURM_NODELIST} started $(date)"
echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo "SNAPSHOT_SOURCE=${SNAPSHOT_SOURCE}"
echo "SNAPSHOT_DELIVERY=${SNAPSHOT_DELIVERY}"
echo "SNAPSHOT_COUNTIES=${SNAPSHOT_COUNTIES}"
echo "=============================================="

if [ -z "${SCRIPT:-}" ]; then
    SCRIPTS=("${ALL_SCRIPTS[@]}")
else
    SCRIPTS=("$(basename "$SCRIPT")")
fi

# Fixture test of both scripts on a synthetic delivery with known answers.
Rscript program/tests/check-corelogic-snapshots.R

for script in "${SCRIPTS[@]}"; do
    if [ ! -f "program/import-corelogic-snapshots/${script}" ]; then
        echo "ERROR: program/import-corelogic-snapshots/${script} not found" >&2
        exit 1
    fi
    name="$(result_name "$script")"
    private_dir="${SNAPSHOT_RESULTS_ROOT}/${name}/${SLURM_JOB_ID}"
    export_dir="${REPO}/results/import-corelogic-snapshots/${name}"
    export SNAPSHOT_RESULTS="$private_dir"
    if [ "$name" = "tabulate" ]; then
        export SNAPSHOT_PANEL="${SNAPSHOT_PANEL:-${SNAPSHOT_RESULTS_ROOT}/panel/current/panel.parquet}"
        echo "Panel: ${SNAPSHOT_PANEL}"
    fi

    echo ""
    echo "== ${script} -> ${private_dir}  ($(date))"
    mkdir -p "$(dirname "$private_dir")"
    Rscript "program/import-corelogic-snapshots/${script}"
    ln -sfn "$SLURM_JOB_ID" "${SNAPSHOT_RESULTS_ROOT}/${name}/current"

    # Export aggregates only: no parquet, no raw extracts, no DuckDB spill.
    rm -rf "$export_dir"
    mkdir -p "$export_dir"
    find "$private_dir" -maxdepth 1 -type f \( -name '*.csv' -o -name '*.json' \) \
        -exec cp {} "$export_dir/" \;
    printf 'job: %s\ncommit: %s\nprivate_results: %s\n' "$SLURM_JOB_ID" \
        "$(git rev-parse HEAD 2>/dev/null || echo unknown)" "$private_dir" \
        > "$export_dir/remote-run.txt"
    echo "Exported $(find "$export_dir" -type f | wc -l) files to results/import-corelogic-snapshots/${name}/"
done

echo ""
echo "Job finished $(date)"
