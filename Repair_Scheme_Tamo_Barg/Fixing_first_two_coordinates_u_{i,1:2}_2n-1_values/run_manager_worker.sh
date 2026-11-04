#!/bin/bash
#SBATCH --partition=algebra
#SBATCH --cpus-per-task=64

# ============================================================
# Slurm Launcher for Distributed Tamo–Barg Repair Schemes
# ============================================================
# This script starts a distributed Magma computation for LERSs of Tamo–Barg codes.
#
# Variable-fixing strategy: Fix the first two coordinates of each helper vector u_i.
#
# Main steps:
#   1. Read the computation parameters.
#   2. Create or recover the job directory.
#   3. Generate a manager script with the job directory.
#   4. Launch the Magma distributed manager.
#   5. Save the manager console output.
#
# Usage: sbatch run_manager_worker.sh
# ============================================================

set -euo pipefail

# read parameters from parameters.mag (same trick you used in run_worker.sh)
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"
# now we have q,t,k,n,l, port_num, etc.

# choose/create a shared job folder name and persist it for reuse 
job_folder_name="job_folder.${SLURM_JOB_ID:-$$}.txt"

if [[ -f "$job_folder_name" && -s "$job_folder_name" ]]; then
  JOBDIR="$(cat "$job_folder_name")"
else
  JOBDIR="Job_q${q}_t${t}_n${n}_k${k}_r${r}_s${s}_l${l}_$(date +%Y%m%d_%H%M%S)"
  echo "$JOBDIR" > "$job_folder_name"
fi

mkdir -p "$JOBDIR"

# inject JOBDIR into a copy of manager.mag and run it 
MANAGER_TEMPLATE="manager.mag"
MANAGER_SCRIPT="$JOBDIR/manager.mag"

sed -e "s|JOB_FOLDER_PLACEHOLDER|$JOBDIR|g" \
  "$MANAGER_TEMPLATE" > "$MANAGER_SCRIPT"

echo "Running manager.mag with JOBDIR=$JOBDIR ..."
magma -b "$MANAGER_SCRIPT" > "$JOBDIR/manager.consol" 2>&1
echo "Manager completed. Logs: $JOBDIR/manager.consol"
