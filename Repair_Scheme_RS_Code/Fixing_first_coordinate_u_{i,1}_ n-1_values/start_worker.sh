#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Worker Launcher for Distributed RS Repair Computations
# ============================================================
#
# This script launches parallel Magma workers 
#
# Variable-fixing strategy: Fix the first entry u_{j,1} of each helper vector u_j.
#
# The script:
#   1. Reads the computation parameters from parameters.mag.
#   2. Creates or reuses a job directory across batches.
#   3. Generates an individual Magma script for each worker.
#   4. Launches workers in parallel.
#   5. Records worker logs and wall-clock execution time.
#
# The manager invokes this script for each batch.
# ============================================================

MAX="${SLURM_CPUS_PER_TASK:-1}"               # number of workers
CMDLINE="${CMDLINE:-magma -b worker.mag}"

# read parameters from parameters.mag into bash vars 
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"
echo "Read parameters: q=$q t=$t k=$k n=$n l=$l port_num=$port_num"

# Path to original MAGMA script
MAGMA_SCRIPT="worker.mag"

# Create or reuse a job folder
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
