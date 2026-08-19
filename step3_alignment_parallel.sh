#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input directory> -o <output directory> -c <coverage output directory> -a <amplicons BED file> -t <tail trim> -r <reverse tail trim> -n <number of samples> -T <number of threads>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing trimmed fastq files."
    echo "  -o    Output directory for BAM files."
    echo "  -c    Output directory for coverage files."
    echo "  -a    BED file with amplicon regions."
    echo "  -t    Suffix for the forward trimmed fastq files."
    echo "  -r    Suffix for the reverse trimmed fastq files."
    echo "  -n    Number of samples to process in parallel."
    echo "  -T    Number of threads for alignment."
    echo "  -h    Display this help message and exit."
}

# Parsing command-line arguments
while getopts ":i:o:c:a:t:r:n:T:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        o ) outdir=$OPTARG ;;
        c ) outcov=$OPTARG ;;
        a ) amplicons_bed=$OPTARG ;;
        t ) tail_trim=$OPTARG ;;
        r ) tail_trim_rev=$OPTARG ;;
        n ) num_samples=$OPTARG ;;
        T ) threads=$OPTARG ;;
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

# Check if all required arguments are provided
if [ -z "$indir" ] || [ -z "$outdir" ] || [ -z "$outcov" ] || [ -z "$amplicons_bed" ] || [ -z "$tail_trim" ] || [ -z "$tail_trim_rev" ] || [ -z "$num_samples" ] || [ -z "$threads" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi

# Ensure output directories exist
mkdir -p "$outdir"
mkdir -p "$outcov"

# Define color variables
BOLD='\033[1m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_CYAN='\033[0;96m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Reference genome file
ref="/media/scratch/FRAN/ReferenceGenome/GCA_000001405.15_GRCh38_no_alt_analysis_set-edit.fa"

# Display header information
echo -e "${MAGENTA}    _    _ _"
echo -e "${MAGENTA}   / \  | (_) __ _ _ __  _ __ ___   ___ _ __ | |_ "
echo -e "${MAGENTA}  / _ \ | | |/ _\` | '_ \| '_ \` _ \ / _ \ '_ \| __|"
echo -e "${MAGENTA} / ___ \| | | (_| | | | | | | | | |  __/ | | | |_ "
echo -e "${MAGENTA}/_/   \_\_|_|\__, |_| |_|_| |_| |_|\___|_| |_|\__|"
echo -e "${MAGENTA}             |___/      "
echo -e "${NC}" # Reset to no color
echo ""
echo "Trimmed fastqs folder: $indir"
echo "BAM folder: $outdir"
echo "Coverage folder: $outcov"
echo "Reference Genome: $ref"
echo "Threads: $threads"
echo "Amplicons BED: $amplicons_bed"
echo "Jobs (samples at the same time): $num_samples"

# Function to process a single sample
process_sample() {
    local file=$1
    local sample=$(basename "$file" "$tail_trim")

    echo ""
    echo -e "${BRIGHT_CYAN}ALIGNMENT ${sample}${NC}"
    echo ""

    if [ -e "${outcov}/${sample}.cov" ]; then
        echo "${sample} has been already aligned and coverage is calculated."
    else
        echo "R1: ${indir}/${sample}${tail_trim}"
        echo "R2: ${indir}/${sample}${tail_trim_rev}"
        echo "Running bwa-mem2 and samtools for ${sample}..."
        bwa-mem2 mem -t "$threads" "$ref" "${indir}/${sample}${tail_trim}" "${indir}/${sample}${tail_trim_rev}" \
        | samtools sort -o "${outdir}/${sample}.bam" &&
        samtools index "${outdir}/${sample}.bam" &&
        
        echo "Calculating coverage for ${sample}..."
        samtools depth -a "${outdir}/${sample}.bam" -b "$amplicons_bed" > "${outcov}/${sample}.cov"
    fi

    echo ""
    echo "DONE ${sample}"
    echo ""
}

export -f process_sample
export indir outdir outcov tail_trim tail_trim_rev amplicons_bed ref threads

# Use GNU Parallel to process samples in parallel
echo ""
echo -e "${BOLD}START script${NC}"
echo ""
echo -e "${BRIGHT_YELLOW}LOADING...${NC}"
echo ""
ls -1 "${indir}"/*"${tail_trim}" | parallel -j "$num_samples" process_sample

echo -e "${BOLD}END script${NC}"

