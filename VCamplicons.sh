#!/bin/bash

set -e  # Exit script if any command fails

# Source the configuration file
config=$1
source $config

BOLD='\033[1m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_CYAN='\033[0;96m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BRIGHT_CYAN}__     ______    _    __  __ ____  _     ___ ____ ___  _   _ ____  ${NC}"
echo -e "${BRIGHT_CYAN}\ \   / / ___|  / \  |  \/  |  _ \| |   |_ _/ ___/ _ \| \ | / ___| ${NC}"
echo -e "${BRIGHT_CYAN} \ \ / / |     / _ \ | |\/| | |_) | |    | | |  | | | |  \| \___ \ ${NC}"
echo -e "${BRIGHT_CYAN}  \ V /| |___ / ___ \| |  | |  __/| |___ | | |__| |_| | |\  |___) |${NC}"
echo -e "${BRIGHT_CYAN}   \_/  \____/_/   \_\_|  |_|_|   |_____|___\____\___/|_| \_|____/ ${NC}"

echo ""
echo "Genomic and Diabetes Unit (Valencia, Spain)"
echo "Creation date: 2024-07-31"
echo "Version: 1.0"
echo "Author: Celeste Moya (cmoya@incliva.es)"

echo "======================================================================================="
echo "Input directory: ${indir}"
echo "Trimmed files directory: ${trim_outdir}"
echo "Tail R1: ${tail_seq_R1}"
echo "Tail R2: ${tail_seq_R2}"
echo "Threads: $threads"
echo "Jobs number: $num_samples"
echo "======================================================================================="
echo ""

###############
# MAIN SCRIPT #
###############

# Step 1: Quality Control and Trimming
if [ "$STEP1" = "True" ]; then
  echo -e "${BOLD}Starting Step 1: Quality Control and Trimming...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 1...${NC}"
  bash step1_QCtrim_parallel.sh -i "$indir" -o "$trim_outdir" -t "$tail_seq_R1" -r "$tail_seq_R2" -l "$len_seq" -q "$quality_seq" -j "$threads" -n "$num_samples"
  echo -e "${BOLD}Completed Step 1${NC}"
  echo ""
fi

# Step 2: Run MultiQC on QC Results
if [ "$STEP2" = "True" ]; then
  echo -e "${BOLD}Starting Step 2: MultiQC Analysis...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 2...${NC}"
  bash step2_multiqc.sh -d ${trim_outdir}
  echo -e "${BOLD}Completed Step 2${NC}"
  echo ""
fi

# Step 3: Alignment and Coverage Calculation
if [ "$STEP3" = "True" ]; then
  echo -e "${BOLD}Starting Step 3: Alignment and Coverage...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 3...${NC}"
  bash step3_alignment_parallel.sh -i "$trim_outdir" -o "$alignment_outdir" -c "$coverage_outdir" -a "$amplicons_bed" -t "$tail_trim" -r "$tail_trim_rev" -n "$num_samples" -T "$threads"
  echo -e "${BOLD}Completed Step 3${NC}"
  echo ""
fi

# Step 4: Remove Primers (if applicable)
if [ "$STEP4" = "True" ]; then
  echo -e "${BOLD}Starting Step 4: Remove Primers...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 4...${NC}"
  bash step4_rmprimers.sh
  echo -e "${BOLD}Completed Step 4${NC}"
  echo ""
fi

# Step 5: Variant Calling
if [ "$STEP5" = "True" ]; then
  echo -e "${BOLD}Starting Step 5: Variant Calling...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 5...${NC}"
  bash step5_vc_parallel.sh -i "$alignment_outdir" -v "$vcf_outdir" -t "$amplicons_bed" -n "$num_samples"
  echo -e "${BOLD}Completed Step 5${NC}"
fi
echo ""

# Step 6: Post-Variant Calling Processing
if [ "$STEP6" = "True" ]; then
  echo -e "${BOLD}Starting Step 6: Post-Variant Calling Processing...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 6...${NC}"
  bash step6_postvc_parallel.sh -i "$vcf_outdir" -o "$post_vc_outdir" -g $geno_quality -d $depth_threshold -n "$num_samples" -t "$threads"
  echo -e "${BOLD}Completed Step 6${NC}"
fi
echo ""

# Step 7: Merge VCF Files
if [ "$STEP7" = "True" ]; then
  echo -e "${BOLD}Starting Step 7: Merge VCF Files...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 7...${NC}"
  bash step7_merge_vcf.sh "$post_vc_outdir" "$depth_threshold" "$geno_quality"
  echo -e "${BOLD}Completed Step 7${NC}"
fi
echo ""

# Step 8: Annotation
if [ "$STEP8" = "True" ]; then
  echo -e "${BOLD}Starting Step 8: Annotation...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 8...${NC}"
  bash step8_annotation.sh -i "$post_vc_outdir" -o "$annotation_dir" -f "merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_freq_AF0_only_variants.vcf.gz" -n "merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_freq_AF0_only_variants.ann.vcf.gz"
  echo -e "${BOLD}Completed Step 8${NC}"
fi
echo ""

# Step 9: Post-Annotation Processing
if [ "$STEP9" = "True" ]; then
  echo -e "${BOLD}Starting Step 9: Post-Annotation Processing...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 9...${NC}"
  bash step9_postann.sh -i "$annotation_dir" -n "$post_vc_outdir" -f "merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_freq_AF0_only_variants.ann.vcf.gz" -t "$transcripts_file"
  echo -e "${BOLD}Completed Step 9${NC}"
fi
echo ""

# Step 10: Check Variants
if [ "$STEP10" = "True" ]; then
  echo -e "${BOLD}Starting Step 10: Check Variants...${NC}"
  echo -e "${BRIGHT_YELLOW}   Loading step 10...${NC}"
  bash step10_checkvariants.sh -i "$annotation_dir" -g "$genotype_table" -a "$annotation_table"
  echo -e "${BOLD}Completed Step 10${NC}"
fi

echo ""
echo -e "${BOLD}Saving results... Almost done!${NC}"

result_dir="${workspace}/VCamplicons_results_Phred${quality_seq}LEN${len_seq}DP${depth_threshold}GQ${geno_quality}SB5_$(date +"%Y%m%d_%H%M")"
mkdir -p ${result_dir}
cp "$annotation_dir"/"$genotype_table" "$annotation_dir"/"$annotation_table" "$annotation_dir"/"merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_freq_AF0_only_variants.ann.transcript.setid.reheader.vcf.gz" ${result_dir}

echo ""
echo -e "${BOLD}Results have been saved here: ${workspace}/VCamplicons_results${NC}"

echo ""
echo ""
echo -e "***************************************************"
echo -e "${MAGENTA}Workflow completed. Go check your results!${NC}"
echo -e "***************************************************"
