#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -d <output directory>"
    echo
    echo "Options:"
    echo "  -d    Directory containing the results for MultiQC."
    echo "  -h    Display this help message and exit."
}

# Parse command-line arguments
while getopts ":d:h" opt; do
    case ${opt} in
        d ) outdir=$OPTARG ;;
        h ) usage
            exit 0 ;;
        \? ) echo "Invalid option: -$OPTARG" >&2
             usage
             exit 1 ;;
        : ) echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1 ;;
    esac
done

# Check if the required argument is provided
if [ -z "$outdir" ]; then
    echo "Error: Missing required argument." >&2
    usage
    exit 1
fi

# Define output directories for MultiQC reports
outQC="${outdir}/outQC"

# Check if the input directory exists
if [ ! -d "$outQC" ]; then
    echo "Error: The directory ${outQC} does not exist." >&2
    exit 1
fi

# Run MultiQC on input FASTQ files
if [ -d "${outQC}/preQC" ]; then
    echo "Running MultiQC on preQC directory..."
    multiqc "${outQC}/preQC" -o "${outQC}/preQC_report"
    echo "MultiQC report for preQC saved in ${outQC}/preQC_report."
else
    echo "Warning: Directory ${outQC}/preQC does not exist. Skipping MultiQC on preQC data."
fi

# Run MultiQC on trimmed FASTQ files
if [ -d "${outQC}/postQC" ]; then
    echo "Running MultiQC on postQC directory..."
    multiqc "${outQC}/postQC" -o "${outQC}/postQC_report"
    echo "MultiQC report for postQC saved in ${outQC}/postQC_report."
else
    echo "Warning: Directory ${outQC}/postQC does not exist. Skipping MultiQC on postQC data."
fi

