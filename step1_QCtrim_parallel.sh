#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input directory> -o <output directory> -t <tail sequence R1> -r <tail sequence R2> -l < length seq > -q <quality seq> -j <threads> -n <num samples>"
    echo
    echo "Options:"
    echo "  -i    Input directory containing FASTQ files."
    echo "  -o    Output directory where results will be saved."
    echo "  -t    Tail sequence for R1 FASTQ files."
    echo "  -r    Tail sequence for R2 FASTQ files."
    echo "  -l    Sequence length (Recommended 70)"
    echo "  -q    Phred number (Recommended 20)"
    echo "  -j    Number of threads to use."
    echo "  -n    Number of samples to process in parallel."
    echo "  -h    Display this help message and exit."
}

# Parse command-line arguments
while getopts ":i:o:t:r:l:q:j:n:h" opt; do
    case ${opt} in
        i ) indir=$OPTARG ;;
        o ) outdir=$OPTARG ;;
        t ) tail_seq_R1=$OPTARG ;;
        r ) tail_seq_R2=$OPTARG ;;
        l ) len_seq=$OPTARG ;;
        q ) quality_seq=$OPTARG;; 
        j ) threads=$OPTARG ;;
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

# Check if the required arguments are provided
if [ -z "$indir" ] || [ -z "$outdir" ] || [ -z "$tail_seq_R1" ] || [ -z "$tail_seq_R2" ] || [ -z "$len_seq" ] || [ -z "$quality_seq" ]|| [ -z "$threads" ] || [ -z "$num_samples" ]; then
    echo "Error: Missing required arguments." >&2
    usage
    exit 1
fi


# Create output directories
outQC=${outdir}/outQC
mkdir -p ${outQC}/preQC
mkdir -p ${outQC}/postQC
mkdir -p ${outdir}/tmpdir

# Print script header in magenta
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
echo -e "${MAGENTA}  ___   ____                   _ "
echo -e "${MAGENTA} / _ \ / ___|   __ _ _ __   __| |"
echo -e "${MAGENTA}| | | | |      / _\` | '_ \ / _\` |"
echo -e "${MAGENTA}| |_| | |___  | (_| | | | | (_| |"
echo -e "${MAGENTA} \__\_\\____|  \__,_|_| |_|\__,_|"
echo -e "${MAGENTA}                                  "
echo -e "${MAGENTA} _____     _                     _             "
echo -e "${MAGENTA}|_   _| __(_)_ __ ___  _ __ ___ (_)_ __   __ _ "
echo -e "${MAGENTA}  | || '__| | '_ \` _ \| '_ \` _ \| | '_ \ / _\` |"
echo -e "${MAGENTA}  | || |  | | | | | | | | | | | | | | | | (_| |"
echo -e "${MAGENTA}  |_||_|  |_|_| |_| |_|_| |_| |_|_|_| |_|\__, |"
echo -e "${MAGENTA}                                         |___/ "
echo -e "${NC}" # Reset to no color

# Determine the adapter sequence based on the first sample
first_file=$(ls ${indir} | head -1)
adapter_name=$(bash src/autoadapter.sh ${indir}/"$first_file" ${outdir}/tmpdir)

case $adapter_name in
    Illumina)
        adapter_seq='AGATCGGAAGAGC'
        adapter_seq_rv=''
        ;;
    Nextera)
        adapter_seq='CTGTCTCTTATA'
        adapter_seq_rv='CTGTCTCTTATA'
        ;;
    smallRNA)
        adapter_seq='TGGAATTCTCGG'
        adapter_seq_rv=''
        ;;
    *)
        echo "Unknown adapter type: $adapter_name" >&2
        exit 1
        ;;
esac

process_sample() {
    file=$1
    sample=$(basename $file ${tail_seq_R1})

    echo -e "\n********************************************"
    echo "Processing sample: $sample"
    echo -e "********************************************\n"

    echo "Running pre-quality control..."
    fastqc --threads $threads --outdir ${outQC}/preQC ${indir}/${sample}${tail_seq_R1} ${indir}/${sample}${tail_seq_R2} &&

    echo "Trimming data..."
    echo "VALUEEEEEEEEEEEEEEEEEEEE: $quality_seq"
    ./src/TrimGalore/trim_galore --quality ${quality_seq} --gzip --length ${len_seq} -o ${outdir} --paired ${indir}/${sample}${tail_seq_R1} ${indir}/${sample}${tail_seq_R2} -j $threads &&

    echo "Running post-quality control..."
    out_name_r1=$(echo ${sample}${tail_seq_R1} | sed 's/\(.*\)\(\.f.*q\.gz\)/\1_val_1.fq.gz/')    
    out_name_r2=$(echo ${sample}${tail_seq_R2} | sed 's/\(.*\)\(\.f.*q\.gz\)/\1_val_2.fq.gz/')
    
    fastqc --threads $threads --outdir ${outQC}/postQC ${outdir}/${sample}*.fq.gz &&

    echo -e "\nDONE processing sample: $sample\n"
}

export -f process_sample
export indir outQC outdir tail_seq_R1 tail_seq_R2 quality_seq len_seq threads

# Run the process_sample function in parallel
ls -1 ${indir}/*${tail_seq_R1} | parallel -j $num_samples process_sample

