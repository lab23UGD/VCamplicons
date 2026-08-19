#!/bin/bash

indir=$1
depth_threshold=$2
geno_quality=$3

# Merge VCF files
echo "Merging VCF files..."

merged_vcf="${indir}/merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort.vcf.gz"

# Filter files that start with 'merge' and end with 'sort.vcf.gz'
vcf_files=$(find "$indir" -maxdepth 1 -type f -name '*sort.vcf.gz' ! -name 'merge*')

# Merge the files
bcftools merge --force-samples $vcf_files -Oz -o "$merged_vcf"
tabix -p vcf "$merged_vcf"

# Update tags 
echo "Updating merge VCF tags..."
update_tags_vcf="${indir}/merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF_sort_update.vcf.gz"
bcftools +fill-tags "$merged_vcf" -Oz -o "$update_tags_vcf" -- -t AF
tabix -p vcf "${out_prefix}_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF.vcf.gz"

# Filter VCF by AF > 0
echo "Filtering merged VCF by AF > 0..."
filtered_af_vcf="${indir}/merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_AF0_sort.vcf.gz"
bcftools view -i 'AF > 0' "$update_tags_vcf" -Oz -o "$filtered_af_vcf"
tabix -p vcf "$filtered_af_vcf"

# Filter to keep only variants
echo "Filtering to keep only variants..."
final_vcf="${indir}/merged_output_vc_split_normdec_nodup_filtDP${depth_threshold}GQ${geno_quality}_noSB5_freq_AF0_only_variants.vcf.gz"
bcftools filter -i 'ALT!="." && INFO/AC>0' "$filtered_af_vcf" -Oz -o "$final_vcf"
echo "Indexing... $final_vcf"
tabix -p vcf "$final_vcf"

echo "Process completed successfully."

