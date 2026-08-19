#!/bin/bash

# Script for running bamclipper -n -p -b in parallel
# Usage: ./bamclipper_parallel.sh <INPUT_DIR> <OUTPUT_DIR> <PRIMER_BED> <THREADS> <JOBS>

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Check for correct number of arguments
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <INPUT_DIR> <OUTPUT_DIR> <PRIMER_BED> <THREADS> <JOBS>"
    exit 1
fi

# Assign arguments to variables
INPUT_DIR=$1
OUTPUT_DIR=$2
PRIMER_BED=$3
THREADS=$4
JOBS=$5

# Validate input directory
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory $INPUT_DIR does not exist."
    exit 1
fi

# Validate primer BED file
if [ ! -f "$PRIMER_BED" ]; then
    echo "Error: Primer BED file $PRIMER_BED does not exist."
    exit 1
fi

# Create output directory if it does not exist
mkdir -p "$OUTPUT_DIR"

# Function to process a single BAM file
process_bam() {
    local bam_file=$1
    local output_file="$OUTPUT_DIR/$(basename "$bam_file" .bam)_clipped.bam"
    echo "Processing $bam_file with $THREADS threads..."
    /media/scratch/FRAN/TFM/bamclipper/bamclipper.sh -n "$THREADS" -p "$PRIMER_BED" -b "$bam_file" > "$output_file"
    samtools index "$output_file"
    echo "Finished processing $bam_file. Output: indexed $output_file"
}

export -f process_bam
export OUTPUT_DIR PRIMER_BED THREADS

echo "Starting bamclipper in parallel with $JOBS jobs and $THREADS threads per BAM file."
find "$INPUT_DIR" -name "*.bam" | parallel -j "$JOBS" process_bam

echo "The primers have been removed! :D"

