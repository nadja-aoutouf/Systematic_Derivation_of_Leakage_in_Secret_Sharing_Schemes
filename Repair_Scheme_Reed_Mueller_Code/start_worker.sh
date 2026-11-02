#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SLURM Job Script for Distributed Computations
# ============================================================
#
# This script launches the distributed computation 
#
# Variable-fixing strategy: Fix the first entry u_{j,1} of each helper vector u_j.
#
# Workflow:
#   1. SLURM allocates the requested computing resources.
#   2. The Magma manager enumerates candidate assignments.
#   3. The manager starts workers through start_worker.sh.
#   4. Workers solve the polynomial systems.
#   5. The manager finishes after all batches are processed.
#
# ============================================================
trap "echo 'Stopping all workers'; kill 0" SIGTERM SIGINT

MAX="${SLURM_CPUS_PER_TASK:-1}" # number of workers is equal to cpus
CMDLINE="${CMDLINE:-magma -b worker.mag}"

# read parameters from parameters.mag into bash vars
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"
echo "Read parameters: q=$q t=$t r=$r m=$m n=$n port_num=$port_num"

# Path to original MAGMA script
MAGMA_SCRIPT="worker.mag"

# Create a job folder
JOBDIR="Job_q${q}_t${t}_n${n}_r${r}_m${m}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$JOBDIR"

# Create a folder data_job.txt inwhich the number of workers and the wall-clock time is saved 
echo "Number of workers: $MAX" > "$JOBDIR/data_job.txt"

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
    magma -b "$WORKER_SCRIPT" > "$log_file" 2>&1 # old version
    #srun --exclusive -n1 magma -b "$WORKER_SCRIPT" > "$log_file" 2>&1. # try
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