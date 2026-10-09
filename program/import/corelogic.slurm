#!/bin/bash
#SBATCH --job-name=mh-corelogic
#SBATCH --output=corelogic_%j.out
#SBATCH --error=corelogic_%j.err
#SBATCH --time=06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --account=econ-public
#SBATCH --partition=standard

set -euo pipefail
source "$HOME/load_r.sh"
module load awscli/2.35.13
cd "$SLURM_SUBMIT_DIR"
export RD_HOME="${RD_HOME:-$HOME/research-database}"
export RD_CACHE_HOSTED="${RD_CACHE_HOSTED:-/scratch/$USER/research-database}"
export CORELOGIC_OUTPUT_ROOT="${CORELOGIC_OUTPUT_ROOT:-/scratch/$USER/manufactured-code/corelogic}"
export CORELOGIC_DUCKDB_MEMORY="${CORELOGIC_DUCKDB_MEMORY:-40GB}"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
Rscript program/tests/check-corelogic-databuild.R
Rscript program/import/databuild-corelogic.R "$@"
