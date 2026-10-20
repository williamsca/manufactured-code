#!/bin/bash
#SBATCH --job-name=paper-corelogic-1999
#SBATCH --output=paper-corelogic-1999_%j.out
#SBATCH --error=paper-corelogic-1999_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --account=econ-public
#SBATCH --partition=standard

# Submit from an isolated source snapshot containing .here and program/.
# Preserve private fitted models on scratch; export only aggregate exhibits.
set -euo pipefail
source "$HOME/load_r.sh"
cd "$SLURM_SUBMIT_DIR"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
export CORELOGIC_REFERENCE="/scratch/chv7bg/manufactured-code/public-reference"
export CORELOGIC_PB_SOURCE="/scratch/chv7bg/research-database/licensed/curated/cl_property_basic/v2026-10-07"
Rscript program/tests/check-corelogic-mh-only.R

for sample in baseline donut; do
    if [ "$sample" = baseline ]; then
        export CORELOGIC_BUILD="/scratch/chv7bg/manufactured-code/corelogic/continental-v3-20261020"
    else
        export CORELOGIC_BUILD="/scratch/chv7bg/manufactured-code/corelogic/continental-donut-50mi-20261020"
    fi
    for analysis in prices quantities; do
        export CORELOGIC_RESULTS="$SLURM_SUBMIT_DIR/private/$sample/$analysis"
        Rscript "program/estimate-corelogic/estimate-corelogic-$analysis.R"
        export_dir="$SLURM_SUBMIT_DIR/exports/$sample/$analysis"
        mkdir -p "$export_dir"
        find "$CORELOGIC_RESULTS" -maxdepth 1 -type f \
            \( -name '*.csv' -o -name '*.pdf' -o -name '*.png' -o -name '*.json' -o -name '*.tex' \) \
            -exec cp {} "$export_dir/" \;
        printf 'job: %s\nprivate_results: %s\nsource_snapshot: %s\n' \
            "$SLURM_JOB_ID" "$CORELOGIC_RESULTS" "$SLURM_SUBMIT_DIR" \
            > "$export_dir/remote-run.txt"
    done
done
