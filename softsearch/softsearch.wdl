version 1.0

import "https://raw.githubusercontent.com/AlesMaver/CMGpipeline/master/FastqToVCFPipeline_3.wdl" as FastqToVcf

# WORKFLOW DEFINITION 
workflow SoftSearchWF {
  input {
    File input_bam
    File input_bam_index
    File reference_fa
    File reference_fai
    Array[String] scatter_regions
    String sample_basename
  }
  
  scatter (chromosome in scatter_regions ) {
    call SoftSearch {
      input:
        input_bam = input_bam,
        input_bai = input_bam_index,
        ref_fasta=reference_fa,
        ref_fasta_index=reference_fai,
        chromosome=chromosome,
        sample_basename=sample_basename
    }
  }  
  
  call FastqToVcf.MergeVCFs as MergeVCFs {
    input:
      input_vcfs = SoftSearch.output_vcf,
      input_vcfs_indexes = SoftSearch.output_vcf_index,
      sample_basename = sample_basename,
      docker = "broadinstitute/gatk:4.2.0.0",
      gatk_path = "/gatk/gatk"
  }

  output {
    File output_cram = MergeVCFs.output_vcf
    File output_cram_index = MergeVCFs.output_vcf_index
  }
}

# SoftSearch task
task SoftSearch {
  input {
    File input_bam
    File input_bam_index
    File ref_fasta
    File ref_fasta_index
    File chromosome
    String sample_basename
  }

  command <<<
    # Generate the genome file
    awk -v OFS='\t' {'print $1,$2'} ~{ref_fasta_index} > hg19.genome

    # Perform SoftSearch
    perl softsearch/script/SoftSearch.pl -b ~{input_bam} -o ~{sample_basename}.softSearch.vcf -f ~{ref_fasta} -v -blacklist /softsearch/library/blacklist_fixed.bed -genome hg19.genome -c chr22

    bcftools view -Oz ~{sample_basename}.softSearch.vcf > ~{sample_basename}.softSearch.vcf.gz
    bcftools index ~{sample_basename}.softSearch.vcf.gz
  >>>

  runtime {
    docker: "alesmaver/softsearch"
    maxRetries: 3
    requested_memory_mb_per_core: 5000
    cpu: 2
    runtime_minutes: 360
  }
  output {
    File output_vcf = "~{sample_basename}.raw.vcf.gz"
    File output_vcf_index = "~{sample_basename}.raw.vcf.gz.tbi"
  }
}