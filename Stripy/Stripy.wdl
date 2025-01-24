version 1.0

workflow stripy_workflow {
    input {
        String sample_id
        File bam_file
        File bai_file
        File reference_fasta
        File reference_fasta_index

        String sex
        # male / female (case sensitive)

        String output_directory
        String reference_genome_name = "hg19"
    }

    call extract_loci {

    }

    call run_stripy {
        input:
            sample_id = sample_id,
            reference_fasta = reference_fasta,
            loci = extract_loci.loci_string,
            reference_genome_name = reference_genome_name,
            sex = sex,
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

    runtime {
        docker: "stedolan/jq"
    }
}

task run_stripy {
    input {
        String sample_id
        File reference_fasta
        String loci
        String reference_genome_name
        String sex
        File bam_file
    }

    command <<<
        set -e

        # Constructing Docker run command (inside Docker already)
        ./batch.sh -o ./ -r ${reference} -l ${loci} -g ${reference_genome_name} -s ${sex} -i ${bam_file}
    >>>

     output {
        File stripy_html = "~{sample_id}.hg19.cram.html"
    }

    runtime {
        docker: "stripy:v2.2"
    }
}
