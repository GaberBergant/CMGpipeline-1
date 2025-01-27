version 1.0

workflow stripy_workflow {
    input {
        String sample_id
        File bam_file
        File? bai_file
        File reference_fasta
        File? reference_fasta_index

        String? sex  # Optional sex input, defaulting and validation happens in the task input
        String output_directory
        String reference_genome_name = "hg19"
    }

    call extract_loci {

    }

    call run_stripy {
        input:
            reference_fasta = reference_fasta,
            output_directory = output_directory,
            loci = extract_loci.loci_string,
            genome = reference_genome_name,
            sex = if defined(sex) && (sex == "male" || sex == "female") then sex else "male",
            bam_file = bam_file
    }
}

task extract_loci {

    command {
        echo "[ PREPARATION ] Downloading variant catalog JSON"
        wget "https://raw.githubusercontent.com/AlesMaver/CMGpipeline/master/ExpansionHunter_configuration/variant_catalog.json"
        unset https_proxy
        wget "https://raw.githubusercontent.com/AlesMaver/CMGpipeline/master/ExpansionHunter_configuration/variant_catalog.json"

        jq -r '[.[] | .LocusId] | join(",")' ./variant_catalog.json
    }

    output {
        String loci_string = read_string(stdout())
    }

}

task run_stripy {
    input {
        File reference_fasta
        String output_directory
        String loci
        String genome
        String sex
        File bam_file
    }

    command <<<
        set -e     

        # Constructing Docker run command (inside Docker already)
        ./batch.sh -o ${output_directory} -r ${reference_fasta} -l ${loci} -g ${genome} -s ${sex} -i ${bam_file}
    >>>

    runtime {
        docker: "gbergant/stripy_prod:2.2"
    }
}
