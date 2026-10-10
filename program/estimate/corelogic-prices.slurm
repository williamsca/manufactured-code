#!/bin/bash
#SBATCH --job-name=mh-cl-prices
#SBATCH --output=corelogic-prices_%j.out
#SBATCH --error=corelogic-prices_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --account=econ-public
#SBATCH --partition=standard
set -euo pipefail
source "$HOME/load_r.sh"
cd "$SLURM_SUBMIT_DIR"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
: "${CORELOGIC_BUILD:?Set CORELOGIC_BUILD to a verified private build}"
: "${CORELOGIC_RESULTS:?Set CORELOGIC_RESULTS to a new private results directory}"
: "${CORELOGIC_TRACTS:?Set verified private parcel-tract lookup directory}"
Rscript program/estimate/estimate-corelogic-prices.R
