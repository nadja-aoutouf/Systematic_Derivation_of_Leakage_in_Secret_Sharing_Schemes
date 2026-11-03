#!/usr/bin/env bash

# ============================================================
# Worker Launcher for Distributed Tamo–Barg Repair Computations
# ============================================================
#
# This script launches parallel Magma workers for the distributed search for LERSs of Tamo–Barg codes.
#
# Main tasks:
#   1. Read the code and repair parameters.
#   2. Determine the number of available workers.
#   3. Create or reuse a job directory across batches.
#   4. Generate worker-specific Magma scripts.
#   5. Launch workers in parallel.
#   6. Record execution times and worker logs.
#
# The manager invokes this script once per batch.
# ============================================================
set -euo pipefail

trap "echo 'Stopping all workers'; kill 0" SIGTERM SIGINT

MAX="${SLURM_CPUS_PER_TASK:-1}"  # number of workers is equal to CPUs per task in SLURM
CMDLINE="${CMDLINE:-magma -b worker.mag}"

# read parameters from parameters.mag into bash vars 
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"
echo "Read parameters: q=$q t=$t k=$k n=$n r=$r l=$l e=$e port_num=$port_num"

# Path to original MAGMA script
MAGMA_SCRIPT="worker.mag"

# choose a job folder and reuse it across batches 
# If we already saved a job folder name, use it here -f checks if the path exist to a file and -s if the file is non-empty
job_folder_name="job_folder.${SLURM_JOB_ID:-$$}.txt"   # to have a unique name per job

if [ -f "$job_folder_name" ] && [ -s "$job_folder_name" ]; then
  JOBDIR="$(cat "$job_folder_name")"
else
  # Otherwise create a new one and remember it
  JOBDIR="Job_q${q}_t${t}_n${n}_k${k}_r${r}_l${l}_e${e}_$(date +%Y%m%d_%H%M%S)"
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
