#!/bin/bash
#SBATCH --partition=algebra
#SBATCH --cpus-per-task=64

# ============================================================
# Launch Distributed Reed-Solomon Repair Scheme Computations
# ============================================================
# Description:
#   Launches a distributed Magma computation on a Slurm cluster using a manager-worker architecture.
#
#   The script:
#     1. Reads the configuration from parameters.mag.
#     2. Creates a unique directory for the computation.
#     3. Generates a job-specific copy of manager.mag.
#     4. Replaces the job-directory placeholder.
#     5. Executes the manager and saves its console output.
#
# Requirements:
#   - Bash
#   - Magma
#   - Slurm workload manager
#   - Access to the configured Slurm partition
#
# Usage:
#   sbatch run_manager_worker.sh
#
# Output:
#   Job_q<q>_t<t>_n<n>_k<k>_l<l>_<timestamp>/
#       manager.mag
#       manager.consol
#
# Note:
#   Worker processes and their output directories are managed by manager.mag and start_worker.sh.
#
# ============================================================

set -euo pipefail

# =====================================================
# read parameters from parameters.mag (same trick you used in run_worker.sh): 
# extracts q, t, k, n, l, and port_num into shell variables.
# =====================================================
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"

# =====================================================
# choose/create a job directory: for example, Job_q2_t4_n14_k6_l0_20261029_150000
# =====================================================
job_folder_name="job_folder.${SLURM_JOB_ID:-$$}.txt"

if [[ -f "$job_folder_name" && -s "$job_folder_name" ]]; then
  JOBDIR="$(cat "$job_folder_name")"
else
  JOBDIR="Job_q${q}_t${t}_n${n}_k${k}_l${l}_$(date +%Y%m%d_%H%M%S)"
  echo "$JOBDIR" > "$job_folder_name"
fi

mkdir -p "$JOBDIR"

# =====================================================
# Prepares the manager: copies manager.mag into the job directory, replacing JOB_FOLDER_PLACEHOLDER
# and runs it
# =====================================================
MANAGER_TEMPLATE="manager.mag"
MANAGER_SCRIPT="$JOBDIR/manager.mag"

sed -e "s|JOB_FOLDER_PLACEHOLDER|$JOBDIR|g" \
  "$MANAGER_TEMPLATE" > "$MANAGER_SCRIPT"

echo "Running manager.mag with JOBDIR=$JOBDIR ..."
magma -b "$MANAGER_SCRIPT" > "$JOBDIR/manager.consol" 2>&1
echo "Manager completed. Logs: $JOBDIR/manager.consol"
