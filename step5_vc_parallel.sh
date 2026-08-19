#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input directory> -v <VCF directory> -t <amplicons BED file> -n <number of samples>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing BAM files."
    echo "  -v    Output directory for VCF files."
    echo "  -t    BED file with target regions."
    echo "  -n    Number of samples to process in parallel."
    echo "  -h    Display this help message and exit."
}

# Parsing command-line arguments
while getopts ":i:v:t:n:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        v ) vcf_files=$OPTARG ;;
        t ) targets=$OPTARG ;;
        n ) num_samples=$OPTARG ;;
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
if [ -z "$indir" ] || [ -z "$vcf_files" ] || [ -z "$targets" ] || [ -z "$num_samples" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi

# Ensure VCF directory exists
mkdir -p "$vcf_files"

# Define color variables
BOLD='\033[1m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_CYAN='\033[0;96m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Reference genome file
ref="/media/scratch/FRAN/ReferenceGenome/GCA_000001405.15_GRCh38_no_alt_analysis_set-edit.fa"

# Display header information
echo -e "${MAGENTA}__     __         _             _      ____      _ _ _              "
echo -e "${MAGENTA}\ \   / /_ _ _ __(_) __ _ _ __ | |_   / ___|__ _| | (_)_ __   __ _ "
echo -e "${MAGENTA} \ \ / / _\` | '__| |/ _\` | '_ \| __| | |   / _\` | | | | '_ \ / _\` |"
echo -e "${MAGENTA}  \ V / (_| | |  | | (_| | | | | |_  | |__| (_| | | | | | | | (_| |"
echo -e "${MAGENTA}   \_/ \__,_|_|  |_|\__,_|_| |_|\__|  \____\__,_|_|_|_|_| |_|\__, |"
echo -e "${MAGENTA}                                                             |___/ "
echo -e "${NC}" # Reset to no color
echo ""
echo "BAM folder: $indir"
echo "VCF folder: $vcf_files"
echo "Reference Genome: $ref"
echo "BED file: $targets"
echo "Jobs (samples at the same time): $num_samples"

# Function to process a single BAM file
process_bam() {
    local file=$1
    local base=$(basename "$file" .bam)

    echo "Processing $file"

    if freebayes --targets "$targets" --report-monomorphic --genotype-qualities -f "$ref" --strict-vcf "$file" \
    | bgzip -c > "${vcf_files}/${base}.vcf.gz" &&
    bcftools sort "${vcf_files}/${base}.vcf.gz" -O z -o "${vcf_files}/${base}.vcf.gz" &&
    zcat "${vcf_files}/${base}.vcf.gz" | uniq | bcftools view -O z -o "${vcf_files}/${base}.uniq.vcf.gz" &&
    vcf-validator "${vcf_files}/${base}.uniq.vcf.gz" &&
    tabix -f -p vcf "${vcf_files}/${base}.uniq.vcf.gz"; then
        echo "Processing completed for $file"
    else
        echo "Error processing $file" >&2
    fi
}

export -f process_bam
export targets ref indir vcf_files

# Use GNU Parallel to process BAM files in parallel
echo -e "${BOLD}START script${NC}"
echo -e "${BRIGHT_YELLOW}LOADING...${NC}"
ls "${indir}"/*.bam | parallel -j "$num_samples" process_bam
echo -e "${BOLD}END script${NC}"

