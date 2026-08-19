#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input directory> -f <input file> -t <transcripts file>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing the input VCF files."
    echo "  -n    VCF directory with the interested flies."
    echo "  -f    Input VCF file name."
    echo "  -t    Transcripts file name."
    echo "  -h    Display this help message and exit."
}

# Parsing command-line arguments
while getopts ":i:n:f:t:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        n ) namesdir=$OPTARG ;;
        f ) inname=$OPTARG ;;
        t ) transcripts=$OPTARG ;;
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
if [ -z "$indir" ] || [ -z "$namesdir" ] || [ -z "$inname" ] || [ -z "$transcripts" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi

echo -e "Input directory: $indir"
echo -e "VCF names directory: $namesdir"
echo -e "Input file: $inname"
echo -e "Transcripts file: $transcripts"
echo ""

base=$(basename "$inname" .vcf.gz)

# Transcript filter
echo "1. Filtering by transcript"
if bash ./src/step9_postann/filter_transcripts.sh "$indir" "$inname" "$transcripts"; then
    echo "Transcript filtering completed"
else
    echo "Error filtering transcripts" >&2
    exit 1
fi
echo ""

# Annotation table
echo "2. Creating annotation table"
if python ./src/step9_postann/filter_ann_variants_v2.py "$indir" "${base}.transcript.vcf.gz" "$transcripts"; then
    echo "Annotation table created"
else
    echo "Error creating annotation table" >&2
    exit 1
fi
echo ""

# Genotype table
echo "3. Creating genotype table"
if bash ./src/step9_postann/genotype_table.sh "$indir" "$namesdir" "${base}.transcript.vcf.gz"; then
    echo "Genotype table created"
else
    echo "Error creating genotype table" >&2
    exit 1
fi
echo ""

# Variant ID and Sample ID
echo "4. Editing variant ID and sample ID in VCF"
transcript_vcf="${indir}/${base}.transcript.vcf.gz"
setid_vcf="${indir}/${base}.setid.vcf.gz"
reheader_vcf="${indir}/${base}.transcript.setid.reheader.vcf.gz"

if bcftools annotate --set-id '%CHROM:%POS-%REF-%ALT' "$transcript_vcf" | bgzip > "$setid_vcf"; then
    echo "Variant ID set"
else
    echo "Error setting variant ID" >&2
    exit 1
fi

if bcftools reheader -s "${indir}/names.txt" "$setid_vcf" > "$reheader_vcf"; then
    echo "Reheader completed"
else
    echo "Error performing reheader" >&2
    exit 1
fi
echo ""

echo "Process completed successfully."

