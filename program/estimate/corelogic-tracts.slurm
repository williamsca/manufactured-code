#!/bin/bash
#SBATCH --job-name=mh-cl-tracts
#SBATCH --output=corelogic-tracts_%j.out
#SBATCH --error=corelogic-tracts_%j.err
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
Rscript program/estimate/prepare-corelogic-tracts.R
