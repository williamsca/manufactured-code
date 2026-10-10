#!/bin/bash
# run_remote.sh -- run program/ANALYSIS/ANALYSIS.slurm on Rivanna and download
# its aggregate results.
#
#   ./run_remote.sh corelogic                               # all scripts, in order
#   ./run_remote.sh corelogic estimate-corelogic-prices.R   # one script
#
# Workflow: edit, commit and `git push`, then run this. It resets the Rivanna
# checkout (~/manufactured-code, cloned on first use) to origin/main, submits
# the job, waits, checks the final Slurm state, and rsyncs
# results/ANALYSIS/<name>/ on Rivanna into output/ANALYSIS/<name>/ here,
# replacing what was there. The job decides what is exported; for CoreLogic
# that is aggregate CSV/PDF/PNG/JSON only, never licensed records.
#
# Local CORELOGIC_BUILD, CORELOGIC_REFERENCE, CORELOGIC_PB_SOURCE and
# CORELOGIC_TRACTS, if set, are forwarded to the job to override its defaults.
# ALLOW_UNPUSHED=1 skips the check that local code matches origin/main.

set -euo pipefail

ANALYSIS="${1:?Usage: $0 ANALYSIS_NAME [SCRIPT_NAME]}"
SCRIPT="${2:-}"
REMOTE="chv7bg@login.hpc.virginia.edu"
REPO_URL="https://github.com/williamsca/manufactured-code.git"
LOCAL_DIR_NAME=$(basename "$PWD")
REMOTE_DIR="\$HOME/${LOCAL_DIR_NAME}"
REMOTE_RSYNC_DIR="~/${LOCAL_DIR_NAME}"
LOCAL_RESULTS="./output/${ANALYSIS}"
FORWARD_VARS=(CORELOGIC_BUILD CORELOGIC_REFERENCE CORELOGIC_PB_SOURCE CORELOGIC_TRACTS)

if [ ! -f "program/${ANALYSIS}/${ANALYSIS}.slurm" ]; then
  echo "ERROR: program/${ANALYSIS}/${ANALYSIS}.slurm not found (run from the repo root)."
  exit 1
fi
if [ -n "$SCRIPT" ] && [ ! -f "program/${ANALYSIS}/$(basename "$SCRIPT")" ]; then
  echo "ERROR: program/${ANALYSIS}/$(basename "$SCRIPT") not found."
  exit 1
fi

# 0. The job runs origin/main, so refuse to run if the code it sources differs
# locally -- otherwise the results would silently come from older code.
if [ "${ALLOW_UNPUSHED:-0}" != "1" ]; then
  git fetch -q origin main
  CODE_PATHS=("program/${ANALYSIS}" program/lib program/tests)
  if ! git diff --quiet origin/main -- "${CODE_PATHS[@]}" ||
     [ -n "$(git ls-files --others --exclude-standard -- "${CODE_PATHS[@]}")" ]; then
    echo "ERROR: local ${CODE_PATHS[*]} differ from origin/main:"
    git diff --stat origin/main -- "${CODE_PATHS[@]}" || true
    git ls-files --others --exclude-standard -- "${CODE_PATHS[@]}" | sed 's/^/  untracked: /'
    echo "Commit and push first, or set ALLOW_UNPUSHED=1 to run origin/main anyway."
    exit 1
  fi
fi

# A transient ssh failure is not a finished job: check ssh's own exit status
# before reading its output, tolerate a run of failures, and require two
# consecutive clean "not in the queue" readings before believing the job is
# gone (squeue can briefly not list a job that is still being scheduled).
POLL_INTERVAL="${POLL_INTERVAL:-30}"
POLL_MAX_SSH_FAILURES="${POLL_MAX_SSH_FAILURES:-20}"

wait_for_job() {
  local job_id="$1"
  local ssh_failures=0
  local gone_streak=0
  local squeue_out
  local rc

  while true; do
    set +e
    squeue_out=$(ssh -o BatchMode=yes -o ConnectTimeout=30 "$REMOTE" \
      "squeue -j ${job_id} -h -o %T" 2>/dev/null)
    rc=$?
    set -e

    if [ "$rc" -ne 0 ]; then
      ssh_failures=$((ssh_failures + 1))
      gone_streak=0
      echo "  poll: ssh failed (rc=${rc}); ${ssh_failures}/${POLL_MAX_SSH_FAILURES} consecutive failures"
      if [ "$ssh_failures" -ge "$POLL_MAX_SSH_FAILURES" ]; then
        echo "ERROR: lost contact with ${REMOTE} while polling job ${job_id}."
        echo "The job may still be running.  Check with:"
        echo "  ssh ${REMOTE} \"squeue -j ${job_id}\""
        echo "Results were NOT downloaded."
        exit 1
      fi
      sleep "$POLL_INTERVAL"
      continue
    fi

    ssh_failures=0

    if [ -z "$squeue_out" ]; then
      gone_streak=$((gone_streak + 1))
      [ "$gone_streak" -ge 2 ] && break
    else
      gone_streak=0
    fi

    sleep "$POLL_INTERVAL"
  done
}

# Leaving the queue is not the same as succeeding: an OOM kill or a non-zero
# Rscript exit both look identical to `squeue`.  Ask the accounting database
# what actually happened and surface the log tail when it went wrong.
check_job_status() {
  local job_id="$1"
  local state=""
  local attempt

  # sacct can lag a few seconds behind the job leaving the queue
  for attempt in 1 2 3 4 5; do
    state=$(ssh "$REMOTE" "sacct -j ${job_id} -X -n -o State%30" 2>/dev/null | head -n 1 | tr -d ' ' || true)
    [ -n "$state" ] && break
    sleep 5
  done

  if [ -z "$state" ]; then
    echo "WARNING: could not read job state for ${job_id} from sacct; continuing."
    return 0
  fi

  if [ "$state" = "COMPLETED" ]; then
    echo "Job ${job_id} finished with state: ${state}"
    return 0
  fi

  # A live state means polling ended early, not that the job finished; do not
  # download a results directory that is mid-write.
  case "$state" in
    RUNNING|PENDING|REQUEUED|RESIZING|SUSPENDED|CONFIGURING|COMPLETING)
      echo "ERROR: job ${job_id} is still ${state} -- polling ended early."
      echo "Nothing was downloaded.  Re-attach with:"
      echo "  ssh ${REMOTE} \"squeue -j ${job_id}\""
      exit 1
      ;;
  esac

  echo "ERROR: job ${job_id} finished with state: ${state}"
  ssh "$REMOTE" "sacct -j ${job_id} -o JobID,State,ExitCode,MaxRSS,ReqMem,Elapsed" 2>/dev/null || true

  echo ""
  echo "--- tail of ${ANALYSIS}_${job_id}.err ---"
  ssh "$REMOTE" "tail -n 40 ${REMOTE_DIR}/program/${ANALYSIS}/${ANALYSIS}_${job_id}.err 2>/dev/null" || true
  echo "--- tail of ${ANALYSIS}_${job_id}.out ---"
  ssh "$REMOTE" "tail -n 40 ${REMOTE_DIR}/program/${ANALYSIS}/${ANALYSIS}_${job_id}.out 2>/dev/null" || true

  notify-send "HPC Job FAILED" "${ANALYSIS} job ${job_id}: ${state}" 2>/dev/null || true
  exit 1
}

# 1. Bring the remote checkout to origin/main (clone on first use).
echo "Resetting remote checkout to origin/main..."
ssh "$REMOTE" "[ -d ${REMOTE_DIR}/.git ] || git clone -q ${REPO_URL} ${REMOTE_DIR}"
ssh "$REMOTE" "cd ${REMOTE_DIR} && git fetch -q origin main && git reset -q --hard origin/main && git log --oneline -1"

# 2. Clear old exports on remote to avoid stale exhibits (only if running all
# scripts; a single-script run replaces only its own subfolder).
if [ -z "$SCRIPT" ]; then
  echo "Clearing old exported results on remote..."
  ssh "$REMOTE" "rm -rf ${REMOTE_DIR}/results/${ANALYSIS}"
fi

# 3. Submit the job and capture the job ID.
EXPORTS="ALL"
[ -n "$SCRIPT" ] && EXPORTS="${EXPORTS},SCRIPT=$(basename "$SCRIPT")"
for v in "${FORWARD_VARS[@]}"; do
  if [ -n "${!v:-}" ]; then
    EXPORTS="${EXPORTS},${v}=${!v}"
  fi
done
echo "Submitting ${ANALYSIS} (${SCRIPT:-all scripts})..."
JOB_ID=$(ssh "$REMOTE" "cd ${REMOTE_DIR}/program/${ANALYSIS} && sbatch --parsable --export='${EXPORTS}' ${ANALYSIS}.slurm")
echo "Submitted job ${JOB_ID}"
echo "  log: ${REMOTE_RSYNC_DIR}/program/${ANALYSIS}/${ANALYSIS}_${JOB_ID}.out"

# 4. Poll until the job leaves the queue, then confirm it succeeded.
echo "Waiting for job to finish..."
wait_for_job "$JOB_ID"
check_job_status "$JOB_ID"

# 5. Download each exported result folder, replacing the local copy.
if [ -n "$SCRIPT" ]; then
  NAMES=$(basename "$SCRIPT" .R | sed -E "s/^(prepare|estimate)-${ANALYSIS}-//")
else
  NAMES=$(ssh "$REMOTE" "ls ${REMOTE_DIR}/results/${ANALYSIS} 2>/dev/null" || true)
fi
if [ -z "$NAMES" ]; then
  echo "Warning: nothing exported under results/${ANALYSIS}/ on remote"
  exit 1
fi
for name in $NAMES; do
  if ! ssh "$REMOTE" "[ -d ${REMOTE_DIR}/results/${ANALYSIS}/${name} ]"; then
    echo "Warning: results/${ANALYSIS}/${name}/ not found on remote"
    exit 1
  fi
  mkdir -p "${LOCAL_RESULTS}/${name}"
  rsync -avz --delete "${REMOTE}:${REMOTE_RSYNC_DIR}/results/${ANALYSIS}/${name}/" "${LOCAL_RESULTS}/${name}/"
  echo "Results downloaded to ${LOCAL_RESULTS}/${name}"
done

# 6. Desktop notification
notify-send "HPC Job Complete" "${ANALYSIS} job ${JOB_ID} finished. Results in ${LOCAL_RESULTS}" 2>/dev/null || true
