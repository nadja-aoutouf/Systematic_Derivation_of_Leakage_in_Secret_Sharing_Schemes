#!/bin/bash

# ============================================================
# SLURM Launcher for Distributed Tamo–Barg Repair Computations
# ============================================================
#
# This script launches the distributed search for LERSs of Tamo–Barg locally repairable codes.
#
# Main tasks:
#   1. Request computational resources from SLURM.
#   2. Read the code and repair parameters.
#   3. Create or reuse a shared job directory.
#   4. Generate a job-specific manager script.
#   5. Execute the Magma manager and save its output.
#
# The manager subsequently launches workers through start_worker.sh and distributes tasks in batches.
#
# Usage: sbatch run_manager_worker.sh
#
# Run from the Repair_Scheme_Tamo_Barg directory.
# ============================================================

#SBATCH --partition=algebra
#SBATCH --cpus-per-task=64

set -euo pipefail

#  read parameters from parameters.mag (same trick you used in run_worker.sh) 
eval "$(
  sed -E 's://.*$::' parameters.mag \
  | sed -En 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*:=[[:space:]]*([^;]+);[[:space:]]*$/\1="\2"/p'
)"
# now we have q,t,k,n,l, port_num, etc.

#  choose/create a shared job folder name and persist it for reuse 
job_folder_name="job_folder.${SLURM_JOB_ID:-$$}.txt"

if [[ -f "$job_folder_name" && -s "$job_folder_name" ]]; then
  JOBDIR="$(cat "$job_folder_name")"
else
  JOBDIR="Job_q${q}_t${t}_n${n}_k${k}_r${r}_l${l}_e${e}_$(date +%Y%m%d_%H%M%S)"
  echo "$JOBDIR" > "$job_folder_name"
fi

mkdir -p "$JOBDIR"

#  inject JOBDIR into a copy of manager.mag and run it 
MANAGER_TEMPLATE="manager.mag"
MANAGER_SCRIPT="$JOBDIR/manager.mag"

sed -e "s|JOB_FOLDER_PLACEHOLDER|$JOBDIR|g" \
  "$MANAGER_TEMPLATE" > "$MANAGER_SCRIPT"

echo "Running manager.mag with JOBDIR=$JOBDIR ..."
magma -b "$MANAGER_SCRIPT" > "$JOBDIR/manager.consol" 2>&1
echo "Manager completed. Logs: $JOBDIR/manager.consol"

