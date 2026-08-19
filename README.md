# VCamplicons

## Overview

This pipeline, developed by the Genomic and Diabetes Unit in Valencia, Spain, processes genomic data for quality control, trimming, alignment, variant calling, and annotation. The workflow consists of several sequential steps, executed by various shell scripts. Each step is responsible for a specific part of the data processing workflow.

## Pipeline Details
* Name: VCamplicons
* Creation Date: 2024-07-31
* Version: 1.0
* Author: Celeste Moya-Valera


## Requirements
* Bash shell
* Configuration file (config.cfg)
* Required scripts:

step1_QCtrim_parallel.sh
step2_multiqc.sh
step3_alignment_parallel.sh
step4_rmprimers.sh
step5_vc_parallel.sh
step6_postvc_parallel.sh
step7_merge_vcf.sh
step8_annotation.sh
step9_postann.sh
step10_checkvariants.sh

## Configuration
Make sure to source the configuration file config.cfg which includes important variables such as input directories, output directories, sequencing parameters, and more.
