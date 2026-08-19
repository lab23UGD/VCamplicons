#!/bin/bash

# Function to display usage information
usage() {
    echo -e "Usage: $0 -i <input directory> -g <genotype table> -a <annotation table>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing the genotype and annotation tables."
    echo "  -g    Genotype table file name."
    echo "  -a    Annotation table file name."
    echo "  -h    Display this help message and exit."
}

# Parsing command-line arguments
while getopts ":i:g:a:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        g ) geno_table=$OPTARG ;;
        a ) ann_table=$OPTARG ;;
        h ) usage
            exit 0 ;;
        \? ) echo "Invalid option: -$OPTARG" 1>&2
             usage
             exit 1 ;;
        : ) echo "Option -$OPTARG requires an argument." 1>&2
            usage
            exit 1 ;;
    esac
done

# Debugging output
echo "indir: $indir"
echo "geno_table: $geno_table"
echo "ann_table: $ann_table"

# Check if all required arguments are provided
if [ -z "$indir" ] || [ -z "$geno_table" ] || [ -z "$ann_table" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi

# Check if input directory exists
if [ ! -d "$indir" ]; then
    echo "Error: Input directory ${indir} does not exist." >&2
    exit 1
fi

# Check if genotype table file exists
if [ ! -f "${indir}/${geno_table}" ]; then
    echo "Error: Genotype table file ${indir}/${geno_table} does not exist." >&2
    exit 1
fi

# Check if annotation table file exists
if [ ! -f "${indir}/${ann_table}" ]; then
    echo "Error: Annotation table file ${indir}/${ann_table} does not exist." >&2
    exit 1
fi

# Run the Python script with the provided tables
python ./src/step10_checkvariants.py "${indir}/${geno_table}" "${indir}/${ann_table}"

# Check if the Python script succeeded
if [ $? -ne 0 ]; then
    echo "Error: Python script execution failed." >&2
    exit 1
fi

echo "Variant checking completed successfully."

