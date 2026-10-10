#!/bin/bash
#SBATCH --job-name=mh-cl-share
#SBATCH --output=corelogic-share_%j.out
#SBATCH --error=corelogic-share_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --account=econ-public
#SBATCH --partition=standard
set -euo pipefail
source "$HOME/load_r.sh"
cd "$SLURM_SUBMIT_DIR"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
: "${CORELOGIC_BUILD:?Set verified build directory}"
: "${CORELOGIC_RESULTS:?Set new private results directory}"
: "${CORELOGIC_REFERENCE:?Set public reference directory}"
Rscript program/estimate/estimate-corelogic-share.R
