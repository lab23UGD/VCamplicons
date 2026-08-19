# VCamplicons

Amplicon-based targeted sequencing pipeline for quality control, alignment, variant calling and annotation of paired-end Illumina data.

Developed at the Genomics and Diabetes Unit, INCLIVA Biomedical Research Institute (Valencia, Spain).

## Pipeline details

| Field | Value |
|---|---|
| **Name** | VCamplicons |
| **Version** | 1.0 |
| **Creation date** | 2024-07-31 |
| **Author** | Celeste Moya-Valera |
| **Reference build** | GRCh38 (no-alt analysis set) |

## Overview

VCamplicons runs ten sequential steps, each implemented as an independent Bash script. The master script `VCamplicons.sh` reads a configuration file and executes only the steps enabled in it, so any step can be run in isolation or the whole workflow can be run end to end. Most steps use GNU Parallel to process several samples at the same time.

| Step | Script | Purpose | Main output |
|---|---|---|---|
| **1** | `step1_QCtrim_parallel.sh` | FastQC before trimming, adapter and quality trimming with Trim Galore, FastQC after trimming | Trimmed FASTQ files, per-sample QC reports |
| **2** | `step2_multiqc.sh` | Aggregates pre- and post-trimming FastQC reports | MultiQC HTML reports |
| **3** | `step3_alignment_parallel.sh` | Alignment with bwa-mem2, sorting and indexing with SAMtools, per-base coverage over the amplicon regions | Sorted BAM files and `.cov` coverage tables |
| **4** | `step4_rmprimers.sh` | Primer clipping (placeholder, see Known limitations) | Not implemented |
| **5** | `step5_vc_parallel.sh` | Variant calling with FreeBayes restricted to the target BED, including monomorphic sites | Per-sample `.uniq.vcf.gz` |
| **6** | `step6_postvc_parallel.sh` | Splits multi-allelic sites, removes duplicates, filters by depth and genotype quality, filters by strand bias, adds allele frequency and sorts | Per-sample `*_AF_sort.vcf.gz` |
| **7** | `step7_merge_vcf.sh` | Merges all per-sample VCFs, recomputes tags, keeps sites with AF > 0 and drops non-variant records | Cohort-level VCF |
| **8** | `step8_annotation.sh` | Annotation with Ensembl VEP in offline mode (SIFT, PolyPhen, gnomAD, 1000 Genomes, HGVS, PubMed) | Annotated VCF |
| **9** | `step9_postann.sh` | Filters to the transcripts of interest, builds the annotation and genotype tables, sets variant IDs and renames samples | Annotation table, genotype table, reheadered VCF |
| **10** | `step10_checkvariants.sh` | Cross-checks the genotype and annotation tables | Final checked variant tables |

Retained variants and tables are copied at the end of the run into a timestamped results folder named after the filtering parameters used, for example `VCamplicons_results_Phred20LEN70DP50GQ60SB5_20240731_1215`.

## Requirements

Bash shell, GNU Parallel and the following tools available on `PATH`:

* FastQC
* MultiQC
* Trim Galore (expected at `src/TrimGalore/trim_galore`) with Cutadapt
* bwa-mem2
* SAMtools
* FreeBayes
* BCFtools, including the `+fill-tags` plugin
* HTSlib (`bgzip`, `tabix`)
* VCFtools (`vcf-validator`)
* Ensembl VEP with a local offline cache
* Python 3
* bamclipper (optional, only needed once step 4 is implemented)

Reference data required:

* Indexed GRCh38 FASTA (bwa-mem2 and SAMtools indexes)
* BED file with the amplicon or target regions
* Text file listing the transcripts of interest
* `names.txt` in the annotation directory, with the sample names used for the VCF reheader in step 9

## Repository structure

```
.
├── VCamplicons.sh              # Master script
├── example_config.cfg          # Configuration template
├── step1_QCtrim_parallel.sh
├── step2_multiqc.sh
├── step3_alignment_parallel.sh
├── step4_rmprimers.sh          # Placeholder
├── step5_vc_parallel.sh
├── step6_postvc_parallel.sh
├── step7_merge_vcf.sh
├── step8_annotation.sh
├── step9_postann.sh
├── step10_checkvariants.sh
├── remove_primers.sh           # Standalone bamclipper wrapper, not yet wired into step 4
└── src/
    ├── autoadapter.sh          # Adapter detection used by step 1
    ├── TrimGalore/             # Bundled Trim Galore
    ├── step9_postann/
    │   ├── filter_transcripts.sh
    │   ├── filter_ann_variants_v2.py
    │   └── genotype_table.sh
    └── step10_checkvariants.py
```

The scripts call `src/` with relative paths, so the pipeline must be launched from the repository root.

Deprecated versions (`step6_postvc_parallel_deprecated.sh`, `step7_merge_vcf_deprecated.sh`, `old_step7_merge_vcf.sh`) are kept for reference only and are not called by the workflow.

## Configuration

All user parameters live in a single configuration file, which is sourced by `VCamplicons.sh`. Copy `example_config.cfg` and edit the top section only; the bottom section derives output paths from the values above.

| Parameter | Description |
|---|---|
| `workspace` | Root directory for all outputs |
| `indir` | Directory with the raw FASTQ files |
| `threads` | Threads per job |
| `num_samples` | Number of samples processed in parallel |
| `amplicons_bed` | BED file with the amplicon or target regions |
| `tail_seq_R1`, `tail_seq_R2` | Suffixes of the forward and reverse FASTQ files |
| `transcripts_file` | List of transcripts of interest |
| `quality_seq` | Phred quality threshold for trimming (recommended 20) |
| `len_seq` | Minimum read length after trimming (recommended 70) |
| `geno_quality` | Genotype quality threshold (recommended 60) |
| `depth_threshold` | Minimum read depth (recommended 20 or 50) |
| `STEP1` to `STEP10` | Set to `True` or `False` to enable or skip each step |

FASTQ naming constraint: the read number must be the last field of the file name, for example `sample_1.fq.gz` and `sample_2.fq.gz`. Names such as `sample_1_merge.fq.gz` will break the trimmed-file suffixes expected in step 3.

## Usage

```bash
# 1. Copy and edit the configuration file
cp example_config.cfg my_run.cfg

# 2. Launch the workflow from the repository root
bash VCamplicons.sh my_run.cfg
```

To rerun a single step, set every other `STEPn` flag to `False` in the configuration file. Individual scripts can also be called directly; run any of them with `-h` to see its options, for example:

```bash
bash step6_postvc_parallel.sh -h
```

Steps 3 and 6 skip samples whose expected output already exists, so an interrupted run can be resumed without recomputing finished samples.

## Known limitations

These points are open and should be resolved before the pipeline is used on new projects.

* **Step 4 is not implemented.** `step4_rmprimers.sh` only prints a progress message. The primer-clipping logic exists as a standalone script, `remove_primers.sh`, which wraps bamclipper but is not called by the workflow and contains a hard-coded path to the bamclipper installation.
* **Reference genome path.** Steps 3, 5 and 8 hard-code the reference FASTA and the VEP cache directory, while step 6 expects an environment variable `REF_GENOME` that the configuration file does not define. Moving all reference paths into the configuration file would make the pipeline portable.
* **Undefined variable in step 7.** The `tabix` call after the tag update refers to `${out_prefix}`, which is not defined in that script. Since `VCamplicons.sh` runs with `set -e`, this can abort the run.
* **Cleanup in step 6.** The intermediate files are removed with a hard-coded `DP20GQ60` pattern executed in the current working directory rather than in the output directory, so intermediates are not cleaned when other thresholds are used.
* **Sample count.** `num_samples` controls the number of parallel jobs, not the number of samples in the run; the comment in the configuration template is misleading.
* **Reheader input.** Step 9 expects a `names.txt` file in the annotation directory; this file is not generated by the pipeline and must be provided by the user.

## Version history

**2026-02-11.** Pipeline recovered from the mochi server. The workflow is incomplete: the bamclipper step is not available as a module, although it is represented in the workflow structure.

**2024-07-31.** Version 1.0.
