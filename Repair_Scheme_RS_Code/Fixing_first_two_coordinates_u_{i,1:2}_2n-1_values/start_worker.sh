#!/usr/bin/env bash

# ============================================================
# Worker Launcher for Distributed RS Repair Computations
# ============================================================
#
# Description:
#   Launches multiple Magma worker processes for a batch of repair scheme computations.
#   Each worker connects to the manager through Magma's MonitoredDistributedWorker interface.
#
#   The script:
#     1. Reads parameters from parameters.mag.
#     2. Creates or reuses the job directory.
#     3. Generates a worker-specific Magma script.
#     4. Assigns a unique worker identifier.
#     5. Launches workers concurrently.
#     6. Records worker logs and wall-clock execution time.
#
# Configuration:
#   MAX : Maximum number of worker processes. Default: 256.
#
# Dependencies:
#   - parameters.mag
#   - worker.mag
#   - repair_scheme_solver.mag
#   - Magma
#
# Output:
#   Job_<parameters>_<timestamp>/
#       worker-1.mag
#       worker-1.log
#       worker-2.mag
#       worker-2.log
#       ...
#       data_job.txt
#
# Usage:
#   This script is launched by manager.mag.
#
# ============================================================

set -euo pipefail
MAX="${MAX:-256}"               # number of workers

# =====================================================
# read parameters from parameters.mag (same trick you used in run_worker.sh): 
# extracts q, t, k, n, l, and port_num into shell variables.
# =====================================================
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"
echo "Read parameters: q=$q t=$t k=$k n=$n l=$l port_num=$port_num"

# Path to original MAGMA script
MAGMA_SCRIPT="worker.mag"

# =====================================================
# creates/chooses a job folder and reuse it across batches
# =====================================================
# If we already saved a job folder name, use it here -f checks if the path exist to a file and -s if the file is non-empty
job_folder_name="job_folder.${SLURM_JOB_ID:-$$}.txt"   # to have a unique name per job

if [ -f "$job_folder_name" ] && [ -s "$job_folder_name" ]; then
  JOBDIR="$(cat "$job_folder_name")"
else
  # Otherwise create a new one and remember it
  JOBDIR="Job_q${q}_t${t}_n${n}_k${k}_l${l}_$(date +%Y%m%d_%H%M%S)"
  echo "$JOBDIR" > "$job_folder_name"
fi

mkdir -p "$JOBDIR"

# Write worker-count once (don’t overwrite if it exists)
if [ ! -f "$JOBDIR/data_job.txt" ]; then
  echo "Number of workers: $MAX" > "$JOBDIR/data_job.txt"
fi

# helper: format seconds
fmt_dur () {
  local s=$1
  printf "%d:%02d:%02d" $((s/3600)) $(((s%3600)/60)) $((s%60))
}

# measure the wall-clock time
start=$(date +%s)


# Run one worker
run_worker () {
    i="$1"
    log_file="$JOBDIR/worker-$i.log"

    # Copy MAGMA script and replace placeholders
    WORKER_SCRIPT="$JOBDIR/worker-$i.mag"
    sed \
        -e "s|JOB_FOLDER_PLACEHOLDER|$JOBDIR|" \
        -e "s|WORKER_ID_PLACEHOLDER|$i|" \
        "$MAGMA_SCRIPT" > "$WORKER_SCRIPT"

    # Run MAGMA
    magma -b "$WORKER_SCRIPT" > "$log_file" 2>&1

}

# Launch workers in parallel
for i in $(seq 1 $MAX); do
    run_worker $i &
done
wait

# to end measuring the time to get the wall-clock time 
end=$(date +%s)
wall_clock_time=$((end - start))
{
  echo "Wall-Clock time is: $(fmt_dur $wall_clock_time) (${wall_clock_time}s)"
} >> "$JOBDIR/data_job.txt"

echo "All workers finished. Logs are in $JOBDIR"

