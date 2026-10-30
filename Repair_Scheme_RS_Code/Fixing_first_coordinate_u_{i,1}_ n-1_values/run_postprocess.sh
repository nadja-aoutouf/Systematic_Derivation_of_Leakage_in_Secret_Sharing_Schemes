#!/bin/bash

# Check if job folder name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <Job folder name>"
    exit 1
fi

job_folder=$1

# Ensure that the job folder exists
if [ ! -d "$job_folder" ]; then
    echo "Error: Job folder '$job_folder' does not exist!"
    exit 1
fi

# Navigate to the job folder
echo "Navigating to job folder: $job_folder"
cd "$job_folder" || { echo "Failed to enter job folder"; exit 1; }

# --- Generate task_list.txt with only finished tasks ---
echo "Generating task list..."

# Empty the files first
> task_list.txt
> task_uncompleted.txt

# Loop over all Task_* folders
for d in Task_*; do
    if [ -d "$d" ]; then
        if [ -f "$d/objects.mag" ]; then
            # Task finished: include in task_list.txt
            echo "$d" >> task_list.txt
        else
            # Task incomplete: log separately
            echo "$d" >> task_uncompleted.txt
        fi
    fi
done

# Check if task_list.txt is generated correctly
if [ ! -f "task_list.txt" ] || [ ! -s "task_list.txt" ]; then
    echo "Warning: No completed tasks found!"
    echo "All tasks appear incomplete. Check task_uncompleted.txt."
fi

# Go back to the original directory
cd ..

# Write the job folder to a temporary file
echo "$job_folder" > job_folder.txt

# Run the Magma script postprocess.mag
magma -b postprocess.mag > file.consol &

echo "Post-process script has finished."
