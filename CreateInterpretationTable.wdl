version 1.0
## Copyright CMG@KIGM, Ales Maver

# WORKFLOW DEFINITION 
workflow CreateInterpretationTable {
  input {
    File input_vcf

    String SnpEff_docker = "alesmaver/snpeff_v43:latest"
    String R_docker = "alesmaver/r-base"
  }  

  File makeXSLSXoutputs_Rscript = "/home/ales/FastqToVCFPipeline/makeXLSXoutputs.R"
  String sample_basename = basename(input_vcf, ".annotated.vcf.gz")

  # Get snpEff and dbNSFP annotations
    call GenerateVariantTable {
    input:
      input_vcf = input_vcf,
      sample_basename = sample_basename,
      docker = SnpEff_docker
  }

  # Get snpEff and dbNSFP annotations
    call GenerateXLSX {
    input:
      RARE_FUNCTIONAL = GenerateVariantTable.RARE_FUNCTIONAL,
      HET_DOMINANT = GenerateVariantTable.HET_DOMINANT,
      COMPHET_RECESSIVE = GenerateVariantTable.COMPHET_RECESSIVE,
      HOM_RECESSIVE = GenerateVariantTable.HOM_RECESSIVE,
      CLINVAR_PATHOGENIC = GenerateVariantTable.CLINVAR_PATHOGENIC,
      CLINVAR_FILTERED = GenerateVariantTable.CLINVAR_FILTERED,
      CLINVAR_ALL = GenerateVariantTable.CLINVAR_ALL,
      sample_basename = sample_basename,
      makeXSLSXoutputs_Rscript = makeXSLSXoutputs_Rscript,
      docker = R_docker
  }
 
  # Outputs that will be retained when execution is complete
  output {
    File XLSX_OUTPUT = GenerateXLSX.XLSX_OUTPUT
  }
}

##################
# TASK DEFINITIONS
##################
# Generate table of variants for interpretation
task GenerateVariantTable {
  input {
    # Command parameters
    File input_vcf
    String sample_basename

    # Runtime parameters
    String docker
  }

  command {
    set -e
    SNPSIFT_EXTRACTFIELDS='/home/biodocker/bin/snpEff/scripts/vcfEffOnePerLine.pl | java -jar /home/biodocker/bin/snpEff/SnpSift.jar extractFields  - CHROM POS REF ALT GEN[0].GT GEN[0].AD GEN[0].DP GEN[0].GQ "ANN[*].GENE" "Disease_name" "Categorization" Inheritance Age HPO "OMIM" "ANN[*].FEATUREID" "ANN[*].HGVS_C" "ANN[*].RANK" "ANN[*].HGVS_P" "ANN[*].IMPACT" "ANN[*].EFFECT"  SLOpopulation.AC_Het SLOpopulation.AC_Hom SLOpopulation.AC_Hemi gnomAD.AC gnomAD.AF gnomAD.nhomalt gnomADexomes.AC gnomADexomes.AF gnomADexomes.nhomalt clinvar.CLNSIG clinvar.CLNDN clinvar.CLNHGVS clinvar.CLNSIGCONF clinvar.CLNSIGINCL dbNSFP_REVEL_rankscore  dbNSFP_MetaSVM_pred dbNSFP_CADD_phred  dbNSFP_DANN_rankscore dbNSFP_SIFT_pred  dbNSFP_SIFT4G_pred  dbNSFP_Polyphen2_HDIV_pred  dbNSFP_MutationTaster_pred dbNSFP_PrimateAI_pred dbNSFP_Polyphen2_HDIV_score SpliceAI.SpliceAI dbscSNV.ada_score dbscSNV.rf_score dbNSFP_GERP___NR  dbNSFP_GERP___RS dbNSFP_Interpro_domain pLI oe_mis pRec "LOF[*].GENE" "LOF[*].GENEID" "LOF[*].NUMTR" "LOF[*].PERC" "NMD[*].GENE" "NMD[*].GENEID" "NMD[*].NUMTR" "NMD[*].PERC"'

    # Optional fields available in the VCF files, consider adding them later
    # dbNSFP_GTEx_V7_gene dbNSFP_GTEx_V7_tissue dbNSFP_Geuvadis_eQTL_target_gene dbNSFP_Aloft_Fraction_transcripts_affected  dbNSFP_Aloft_prob_Tolerant  dbNSFP_Aloft_prob_Recessive  dbNSFP_Aloft_prob_Dominant  dbNSFP_Aloft_pred dbNSFP_Aloft_Confidence 

    zcat ~{input_vcf} | java -jar /home/biodocker/bin/snpEff/SnpSift.jar filter "((( gnomAD.AF < 0.05 ) | !( exists gnomAD.AC )) & (( gnomAD.nhomalt < 10 ) | !( exists gnomAD.nhomalt )) & (( SLOpopulation.AC_Het < 100 ) | !( exists SLOpopulation.AC_Het )) & (!( exists SLOpopulation.AC_Hom ) | ( SLOpopulation.AC_Hom <= 6 ))) & (( ANN[*].IMPACT has 'MODERATE') | (ANN[*].IMPACT has 'HIGH') | (dbscSNV.ada_score > 0.5) | (dbscSNV.rf_score > 0.5))" | eval $SNPSIFT_EXTRACTFIELDS > ~{sample_basename}.RARE_FUNCTIONAL.tab

    zcat ~{input_vcf} | java -jar /home/biodocker/bin/snpEff/SnpSift.jar filter "((( gnomAD.AC < 10 ) | !( exists gnomAD.AC )) & (( SLOpopulation.AC_Het < 5 ) | !( exists SLOpopulation.AC_Het )) & (!( exists SLOpopulation.AC_Hom ) | ( SLOpopulation.AC_Hom <= 6 ))) & (( ANN[*].IMPACT has 'MODERATE') | (ANN[*].IMPACT has 'HIGH') | (dbscSNV.ada_score > 0.5) | (dbscSNV.rf_score > 0.5)) & (( Inheritance =~ '.*AD.*' ) | ( HPO =~ '.*Autosomal_dominant.*' ) | ( HPO  =~  '.*X-linked_dominant.*' )) & isHet(GEN[0].GT)" | eval $SNPSIFT_EXTRACTFIELDS > ~{sample_basename}.HET_DOMINANT.tab

    zcat ~{input_vcf} | java -jar /home/biodocker/bin/snpEff/SnpSift.jar filter "((( gnomAD.AF < 0.05 ) | !( exists gnomAD.AC )) & (( gnomAD.nhomalt < 10 ) | !( exists gnomAD.nhomalt )) & (( SLOpopulation.AC_Het < 100 ) | !( exists SLOpopulation.AC_Het )) & (!( exists SLOpopulation.AC_Hom ) | ( SLOpopulation.AC_Hom <= 6 ))) & (( ANN[*].IMPACT has 'MODERATE') | (ANN[*].IMPACT has 'HIGH') | (dbscSNV.ada_score > 0.5) | (dbscSNV.rf_score > 0.5)) & (( Inheritance =~ '.*AR.*' ) | ( Inheritance =~ '.*XL.*' ) | ( HPO =~ '.*Autosomal_recessive.*' ) | ( HPO  =~  '.*X-linked_recessive.*' )) & !(isHom(GEN[0].GT))" | eval $SNPSIFT_EXTRACTFIELDS >  ~{sample_basename}.COMPHET_RECESSIVE.tab

    zcat ~{input_vcf} | java -jar/home/biodocker/bin/snpEff/SnpSift.jar filter "((( gnomAD.AF < 0.05 ) | !( exists gnomAD.AC )) & (( gnomAD.nhomalt < 10 ) | !( exists gnomAD.nhomalt )) & (( SLOpopulation.AC_Het < 100 ) | !( exists SLOpopulation.AC_Het )) & (!( exists SLOpopulation.AC_Hom ) | ( SLOpopulation.AC_Hom <= 6 ))) & (( ANN[*].IMPACT has 'MODERATE') | (ANN[*].IMPACT has 'HIGH') | (dbscSNV.ada_score > 0.5) | (dbscSNV.rf_score > 0.5)) & (( Inheritance =~ '.*AR.*' ) | ( Inheritance =~ '.*XL.*' ) | ( HPO =~ '.*Autosomal_recessive.*' ) | ( HPO  =~  '.*X-linked_recessive.*' )) & isHom(GEN[0].GT)" | eval $SNPSIFT_EXTRACTFIELDS > ~{sample_basename}.HOM_RECESSIVE.tab

    zcat ~{input_vcf} | java -jar /home/biodocker/bin/snpEff/SnpSift.jar filter "((( gnomAD.AF < 0.05 ) | !( exists gnomAD.AC )) & (( gnomAD.nhomalt < 10 ) | !( exists gnomAD.nhomalt )) & (( SLOpopulation.AC_Het < 100 ) | !( exists SLOpopulation.AC_Het )) & (!( exists SLOpopulation.AC_Hom ) | ( SLOpopulation.AC_Hom <= 6 ))) & (( ANN[*].IMPACT has 'MODERATE') | (ANN[*].IMPACT has 'HIGH') | (dbscSNV.ada_score > 0.5) | (dbscSNV.rf_score > 0.5)) & ((clinvar.CLNSIGCONF =~ '.*Pathogenic.*') | (clinvar.CLNSIGCONF =~ '.*Likely_pathogenic.*') | (clinvar.CLNSIG =~ '.*Likely_pathogenic.*') | (clinvar.CLNSIG =~ '.*Pathogenic.*'))" | eval $SNPSIFT_EXTRACTFIELDS > ~{sample_basename}.CLINVAR_PATHOGENIC.tab

    zcat ~{input_vcf} | java -jar /home/biodocker/bin/snpEff/SnpSift.jar filter "((( gnomAD.AF < 0.05 ) | !( exists gnomAD.AC )) & (( gnomAD.nhomalt < 10 ) | !( exists gnomAD.nhomalt )) & (( SLOpopulation.AC_Het < 100 ) | !( exists SLOpopulation.AC_Het )) & (!( exists SLOpopulation.AC_Hom ) | ( SLOpopulation.AC_Hom <= 6 ))) & (( ANN[*].IMPACT has 'MODERATE') | (ANN[*].IMPACT has 'HIGH') | (dbscSNV.ada_score > 0.5) | (dbscSNV.rf_score > 0.5)) & (exists clinvar.CLNSIG)" | eval $SNPSIFT_EXTRACTFIELDS > ~{sample_basename}.CLINVAR_FILTERED.tab

    zcat ~{input_vcf} | java -jar /home/biodocker/bin/snpEff/SnpSift.jar filter "(exists clinvar.CLNSIG) & !((clinvar.CLNSIG =~ '.*Likely_benign.*') | (clinvar.CLNSIG =~ '.*Benign.*'))" | eval $SNPSIFT_EXTRACTFIELDS > ~{sample_basename}.CLINVAR_ALL.tab

    
  }
  runtime {
    docker: docker
  }
  output {
    File RARE_FUNCTIONAL = "~{sample_basename}.RARE_FUNCTIONAL.tab"
    File HET_DOMINANT = "~{sample_basename}.HET_DOMINANT.tab"
    File COMPHET_RECESSIVE = "~{sample_basename}.COMPHET_RECESSIVE.tab"
    File HOM_RECESSIVE = "~{sample_basename}.HOM_RECESSIVE.tab"
    File CLINVAR_PATHOGENIC = "~{sample_basename}.CLINVAR_PATHOGENIC.tab"
    File CLINVAR_FILTERED = "~{sample_basename}.CLINVAR_FILTERED.tab"
    File CLINVAR_ALL = "~{sample_basename}.CLINVAR_ALL.tab"

  }
}

# Generate table of variants for interpretation
task GenerateXLSX {
  input {
    # Command parameters
    File RARE_FUNCTIONAL
    File HET_DOMINANT
    File COMPHET_RECESSIVE
    File HOM_RECESSIVE
    File CLINVAR_PATHOGENIC
    File CLINVAR_FILTERED
    File CLINVAR_ALL
    String sample_basename

    File makeXSLSXoutputs_Rscript

    # Runtime parameters
    String docker
  }

  command {
  Rscript ~{makeXSLSXoutputs_Rscript} --sample_basename=~{sample_basename} --RARE_FUNCTIONAL=~{RARE_FUNCTIONAL} --HET_DOMINANT=~{HET_DOMINANT} --COMPHET_RECESSIVE=~{COMPHET_RECESSIVE} --HOM_RECESSIVE=~{HOM_RECESSIVE} --CLINVAR_PATHOGENIC=~{CLINVAR_PATHOGENIC} --CLINVAR_FILTERED=~{CLINVAR_FILTERED} --CLINVAR_ALL=~{CLINVAR_ALL} --XLSX_OUTPUT=~{sample_basename}.FinalReportNew.xlsx 
    
  }
  runtime {
    docker: docker
  }
  output {
    File XLSX_OUTPUT = "~{sample_basename}.FinalReportNew.xlsx"

  }
}

