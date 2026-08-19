#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input directory> -o <output directory> -g <genotype quality> -d <depth threshold> -n <number of samples> -t <number of threads>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing VCF files to process."
    echo "  -o    Output directory for the processed VCF files."
    echo "  -g    Genotype quality (Recommended 60)."
    echo "  -d    Depth threshold (Recommended 20 or 50)."
    echo "  -n    Number of samples to process in parallel."
    echo "  -t    Number of threads to use for bcftools."
    echo "  -h    Display this help message and exit."
}

# Parsing command-line arguments
while getopts ":i:o:g:d:n:t:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        o ) outdir=$OPTARG ;;
        g ) geno_quality=$OPTARG ;;
        d ) depth_threshold=$OPTARG ;;
        n ) num_samples=$OPTARG ;;
        t ) threads=$OPTARG ;;
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
if [ -z "$indir" ] || [ -z "$outdir" ] || [ -z "$geno_quality" ] || [ -z "$depth_threshold" ] || [ -z "$num_samples" ] || [ -z "$threads" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi

# Ensure output directory exists
# [TODO] change using mv the name to rewrite it and make it "disapear".
#if [ -d "$outdir" ];then
#mv "$outdir" "___${outdir}_$(date)"
#else

mkdir -p "$outdir"

# Define color variables
BOLD='\033[1m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_CYAN='\033[0;96m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Reference genome file
ref=$REF_GENOME

# Function to process each VCF file
process_file() {
    local file=$1
    local outdir=$2
    local ref=$3
    local threads=$4
    local depth_threshold=$5
    local geno_quality=$6

    local base=$(basename "$file" .vcf.gz)
    
    echo ""
    echo -e "${MAGENTA}SAMPLE: $base ${NC}"
    echo ""
    
    #local out_prefix="${outdir}/${base}_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort"
    local out_prefix="${outdir}/${base}"
    
    if [ -f "${out_prefix}_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort.vcf.gz" ]; then
        echo "${out_prefix}_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort.vcf.gz already exists."
        return
    fi

    # Split variants
    echo "  1. $base: split"
    if ! bcftools norm -m -any -a --threads "$threads" "$file" -Oz -o "${out_prefix}_split.vcf.gz"; then
        echo "Error splitting $file" >&2
        return
    fi

    # Remove duplicates
    echo "  2. $base: remove duplicates"
    if ! bcftools norm -d none --threads "$threads" -f "$ref" "${out_prefix}_split.vcf.gz" -Oz -o "${out_prefix}_split_normdec_nodup.vcf.gz"; then
        echo "Error removing duplicates from ${out_prefix}_split_normdec_nodup.vcf.gz" >&2
        return
    fi

    # Filter by quality and depth
    echo "  3. $base: Quality (GQ${geno_quality}) and depth (DP${depth_threshold}) filter"
    if ! bcftools filter -i "INFO/DP >= ${depth_threshold} & FORMAT/GQ >= ${geno_quality}" "${out_prefix}_split_normdec_nodup.vcf.gz" -Oz -o "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}.vcf.gz"; then
        echo "Error filtering by quality and depth" >&2
        return
    fi

    # Filter by strand bias
    echo "  4. $base: strand bias filter"
    if ! bcftools filter -i 'ALT=="."' "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}.vcf.gz" -Oz -o "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noALT.vcf.gz" || \
       ! tabix -p vcf "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noALT.vcf.gz" || \
       ! bcftools filter -i 'ALT!="."' "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}.vcf.gz" -Ou | \
       bcftools filter -i 'INFO/SAP<=5 && INFO/SRP<=5' -Oz -o "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_ALT.vcf.gz" || \
       ! tabix -p vcf "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_ALT.vcf.gz"; then
        echo "Error filtering by strand bias" >&2
        return
    fi

    # Concatenate VCF files
    echo "  5. $base: concatenate"
    if ! bcftools concat -a "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noALT.vcf.gz" "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_ALT.vcf.gz" -Oz -o "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5.vcf.gz" || \
       ! tabix -p vcf "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5.vcf.gz"; then
        echo "Error concatenating VCF files" >&2
        return
    fi

    # Add allelic frequency
    echo "  6. $base: add allelic frequency"
    if ! bcftools +fill-tags "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5.vcf.gz" -Oz -o "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF.vcf.gz" -- -t AF || \
       ! tabix -p vcf "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF.vcf.gz"; then
        echo "Error adding allelic frequency" >&2
        return
    fi

    # Sort VCF file
    echo "  7. $base: sort"
    if ! bcftools sort "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF.vcf.gz" -Oz -o "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort.vcf.gz" || \
       ! tabix -f -p vcf "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort.vcf.gz"; then
        echo "Error sorting VCF file" >&2
        return
    fi
    echo ""
}

export -f process_file

echo -e "${BOLD}START script${NC}"
echo -e "${BRIGHT_YELLOW}LOADING...${NC}"

# Process files in parallel
ls -1 "${indir}"/*uniq.vcf.gz | parallel -j "$num_samples" process_file {} "$outdir" "$ref" "$threads" "$depth_threshold" "$geno_quality"
#fi

rm *_split_normdec_nodup_filtDP20GQ60_ALT.vcf.gz* *_split_normdec_nodup_filtDP20GQ60_noALT.vcf.gz* *_split_normdec_nodup_filtDP20GQ60_noSB5_AF.vcf.gz* *_split_normdec_nodup_filtDP20GQ60_noSB5.vcf.gz* *_split_normdec_nodup_filtDP20GQ60.vcf.gz* *_split.vcf.gz* *_split_normdec_nodup.vcf.gz*

echo -e "${BOLD}END script${NC}"

# Uncomment if merging and filtering final VCF is required
# bcftools merge --force-samples $(find "$outdir" -name "*_AF_sort.vcf.gz") -Oz -o "${outdir}/merged_output_AF_sort.vcf.gz"
# bcftools view -i 'AF > 0' "${outdir}/merged_output_AF_sort.vcf.gz" -Oz -o "${outdir}/merged_output_AF0_sort.vcf.gz"
# bcftools filter -i 'ALT!="." && INFO/AC>0' "${outdir}/merged_output_AF0_sort.vcf.gz" -Oz -o "${outdir}/merged_output_freq_AF0_only_variants.vcf.gz"

