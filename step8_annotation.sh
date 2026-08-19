#!/bin/bash

# ANSI color codes
BOLD='\033[1m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_CYAN='\033[0;96m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to display usage information
usage() {
    echo -e "${BOLD}Usage:${NC} $0 -i <input directory> -o <output directory> -f <input file> -n <output file>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing the VCF file."
    echo "  -o    Output directory for the processed VCF file."
    echo "  -f    Input VCF file name."
    echo "  -n    Output VCF file name."
    echo "  -h    Display this help message and exit."
}

# Parsing command-line arguments
while getopts ":i:o:f:n:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        o ) outdir=$OPTARG ;;
        f ) inname=$OPTARG ;;
        n ) outname=$OPTARG ;;
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

# Check if all required arguments are provided
if [ -z "$indir" ] || [ -z "$outdir" ] || [ -z "$inname" ] || [ -z "$outname" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi

# Banner message
echo -e "${MAGENTA}    _                      _        _   _             "
echo -e "   / \\   _ __  _ __   ___ | |_ __ _| |_(_) ___  _ __  "
echo -e "  / _ \\ | '_ \\| '_ \\ / _ \\| __/ _\` | __| |/ _ \\| '_ \\ "
echo -e " / ___ \\| | | | | | | (_) | || (_| | |_| | (_) | | | |"
echo -e "/_/   \\_\\_| |_|_| |_|\\___/ \\__\\__,_|\\__|_|\\___/|_| |_|"
echo -e "                                                      ${NC}"

# Database and reference genome paths
db_vep="dbs_tmp/vep"
ref="ReferenceGenome/GCA_000001405.15_GRCh38_no_alt_analysis_set-edit.fa"

# Display input information
echo -e "VEP folder: ${BOLD}${db_vep}${NC}"
echo -e "Reference Genome: ${BOLD}${ref}${NC}"
echo -e "Input directory: ${BOLD}${indir}${NC}"
echo -e "Output directory: ${BOLD}${outdir}${NC}"
echo -e "Input file: ${BOLD}${inname}${NC}"
echo -e "Output file: ${BOLD}${outname}${NC}"

mkdir -p $outdir

# Check if input directory exists
if [ ! -d "$indir" ]; then
    echo "Error: Input directory ${indir} does not exist." >&2
    exit 1
fi

# Check if input file exists
if [ ! -f "${indir}/${inname}" ]; then
    echo "Error: Input file ${indir}/${inname} does not exist." >&2
    exit 1
fi

# Run VEP annotation
vep --dir "$db_vep" --assembly GRCh38 --offline --sift b --polyphen b --no_stats --allow_non_variant --force_overwrite \
    -i "${indir}/${inname}" --format vcf --compress_output gzip --vcf -o "${outdir}/${outname}" --af_1kg --af_gnomad --pubmed --hgvs --fasta "$ref"

# Check if VEP command succeeded
if [ $? -ne 0 ]; then
    echo "Error: VEP annotation failed." >&2
    exit 1
fi

# Status messages
echo ""
echo -e "${BRIGHT_YELLOW}LOADING...${NC}"
echo ""
echo -e "${BRIGHT_CYAN}END of the annotation${NC}"

