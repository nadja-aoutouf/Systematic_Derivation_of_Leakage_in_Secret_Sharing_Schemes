#!/bin/bash
#SBATCH --partition=algebra
#SBATCH --cpus-per-task=64

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

# Start the manager script (manager.mag)
echo "Running manager.mag..."
magma -b manager.mag > file.consol  & 
echo "Manager completed."

# Start the worker script in the background (start_worker.sh)
echo "Starting workers..."
./start_worker.sh  # This will launch multiple worker processes
echo "Workers started."

# Optionally, wait for all worker processes to complete (if necessary)
wait

# Finish
echo "All tasks completed."
