#!/bin/bash
# download_remote.sh -- download the latest exported output from Rivanna
# without running a job.
#
#   ./download_remote.sh corelogic                    # all output folders
#   ./download_remote.sh corelogic prices             # one output folder
#
# Accepts either the output name (corelogic) or the analysis name
# (estimate-corelogic). Syncs output/OUTPUT/<name>/ on Rivanna into
# output/OUTPUT/<name>/ here, replacing what was there. This is the download
# step of run_remote.sh.

set -euo pipefail

ANALYSIS="${1:?Usage: $0 output_NAME [FOLDER_NAME]}"
ONLY="${2:-}"
REMOTE="chv7bg@login.hpc.virginia.edu"
LOCAL_DIR_NAME=$(basename "$PWD")
REMOTE_DIR="\$HOME/${LOCAL_DIR_NAME}"
REMOTE_RSYNC_DIR="~/${LOCAL_DIR_NAME}"
OUTPUT="${ANALYSIS#estimate-}"
LOCAL_OUTPUT="./output/${OUTPUT}"

if [ -n "$ONLY" ]; then
  NAMES="$ONLY"
else
  NAMES=$(ssh "$REMOTE" "ls ${REMOTE_DIR}/output/${OUTPUT} 2>/dev/null" || true)
fi
if [ -z "$NAMES" ]; then
  echo "ERROR: nothing exported under output/${OUTPUT}/ on remote"
  exit 1
fi

for name in $NAMES; do
  if ! ssh "$REMOTE" "[ -d ${REMOTE_DIR}/output/${OUTPUT}/${name} ]"; then
    echo "ERROR: output/${OUTPUT}/${name}/ not found on remote"
    exit 1
  fi
  mkdir -p "${LOCAL_OUTPUT}/${name}"
  rsync -avz --delete "${REMOTE}:${REMOTE_RSYNC_DIR}/output/${OUTPUT}/${name}/" "${LOCAL_OUTPUT}/${name}/"
  echo "Output downloaded to ${LOCAL_OUTPUT}/${name}"
done
