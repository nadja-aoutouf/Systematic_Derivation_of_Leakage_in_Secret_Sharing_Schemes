#!/bin/bash
#SBATCH --partition=algebra
#SBATCH --cpus-per-task=64


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
