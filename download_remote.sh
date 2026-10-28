#!/bin/bash
# download_remote.sh -- download the latest exported results from Rivanna
# without running a job.
#
#   ./download_remote.sh corelogic                    # all result folders
#   ./download_remote.sh corelogic prices             # one result folder
#
# Accepts either the results name (corelogic) or the analysis name
# (estimate-corelogic). Syncs results/RESULTS/<name>/ on Rivanna into
# output/RESULTS/<name>/ here, replacing what was there. This is the download
# step of run_remote.sh.

set -euo pipefail

ANALYSIS="${1:?Usage: $0 RESULTS_NAME [FOLDER_NAME]}"
ONLY="${2:-}"
REMOTE="chv7bg@login.hpc.virginia.edu"
LOCAL_DIR_NAME=$(basename "$PWD")
REMOTE_DIR="\$HOME/${LOCAL_DIR_NAME}"
REMOTE_RSYNC_DIR="~/${LOCAL_DIR_NAME}"
RESULTS="${ANALYSIS#estimate-}"
LOCAL_RESULTS="./output/${RESULTS}"

if [ -n "$ONLY" ]; then
  NAMES="$ONLY"
else
  NAMES=$(ssh "$REMOTE" "ls ${REMOTE_DIR}/results/${RESULTS} 2>/dev/null" || true)
fi
if [ -z "$NAMES" ]; then
  echo "ERROR: nothing exported under results/${RESULTS}/ on remote"
  exit 1
fi

for name in $NAMES; do
  if ! ssh "$REMOTE" "[ -d ${REMOTE_DIR}/results/${RESULTS}/${name} ]"; then
    echo "ERROR: results/${RESULTS}/${name}/ not found on remote"
    exit 1
  fi
  mkdir -p "${LOCAL_RESULTS}/${name}"
  rsync -avz --delete "${REMOTE}:${REMOTE_RSYNC_DIR}/results/${RESULTS}/${name}/" "${LOCAL_RESULTS}/${name}/"
  echo "Results downloaded to ${LOCAL_RESULTS}/${name}"
done
