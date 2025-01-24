version 1.0

workflow stripy_workflow {
    input {
        File input_bam
        File reference_genome
        File variant_catalog_json
        String sex
        String output_directory
        String reference_genome_name = "hg19"
    }

    call extract_loci {
        input:
            variant_catalog = variant_catalog_json
    }

    call run_stripy {
        input:
            reference = reference_genome,
            output = output_directory,
            loci = extract_loci.loci_string,
            genome = reference_genome_name,
            sex = sex,
            input_bam = input_bam
    }
}

task extract_loci {
    input {
        File variant_catalog
    }

    command {
        jq -r '[.[] | .LocusId] | join(",")' ${variant_catalog}
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
        File reference
        String output
        String loci
        String genome
        String sex
        File input_bam
    }

    command <<<
        set -e
        # Resolve paths
        reference_path=$(realpath ${reference})
        output_path=$(realpath ${output})
        input_path=$(realpath ${input_bam})

        # Path to required files for docker volumes
        ref_dir=$(dirname "${reference_path}")
        input_dir=$(dirname "${input_path}")

        # Filenames
        ref_file=$(basename "${reference_path}")
        input_file=$(basename "${input_path}")

        # Constructing Docker run command (inside Docker already)
        ./batch.sh -o /mnt/results -r /mnt/ref/${ref_file} -l ${loci} -g ${genome} -s ${sex} -i /mnt/data/${input_file}
    >>>

    runtime {
        docker: "stripy:v2.2"
        volumes: ["${ref_dir}:/mnt/ref", "${output_path}:/mnt/results", "${input_dir}:/mnt/data"]
    }
}
