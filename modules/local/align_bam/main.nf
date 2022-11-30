process ALIGN_BAM {
    tag "$meta.id"
    label 'process_high'

    conda (params.enable_conda ? "bioconda::fgbio=2.0.2 bioconda::bwa=0.7.17 bioconda::samtools=1.16.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-69f5207f538e4de9ef3bae6f9a95c5af56a88ab8:82d3ec41f9f1227f7183d344be46f73365efa704-0' :
        'quay.io/biocontainers/mulled-v2-69f5207f538e4de9ef3bae6f9a95c5af56a88ab8:82d3ec41f9f1227f7183d344be46f73365efa704-0' }"

    input:
    tuple val(meta), path(unmapped_bam)
    path index_dir
    val sort

    output:
    tuple val(meta), path("*.mapped.bam"), emit: bam
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def samtools_fastq_args = task.ext.samtools_fastq_args ?: ''
    def samtools_sort_args = task.ext.samtools_sort_args ?: ''
    def bwa_args = task.ext.bwa_args ?: ''
    def fgbio_args = task.ext.fgbio_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def fgbio_mem_gb = 4

    if (!task.memory) {
        log.info '[fgbio ZipperBams] Available memory not known - defaulting to 4GB. Specify process memory requirements to change this.'
    } else if (fgbio_mem_gb > task.memory.giga) {
        if (task.memory.giga < 2) {
            fgbio_mem_gb = 1
        } else {
            fgbio_mem_gb = task.memory.giga - 1
        }
    }
    if (sort) {
        fgbio_zipper_bams_output = "/dev/stdout"
        fgbio_zipper_bams_compression = 0 // do not compress if samtools is consuming it
        extra_command = " | samtools sort "
        extra_command += samtools_sort_args
        extra_command += " --template-coordinate"
        extra_command += " --threads "+ task.cpus
        extra_command += " -o " + prefix + ".mapped.bam"
    } else {
        fgbio_zipper_bams_output = prefix + ".mapped.bam"
        fgbio_zipper_bams_compression = 1
        extra_command = ""
    }

    """
    # The real path to the FASTA
    FASTA=`find -L ./ -name "*.amb" | sed 's/.amb//'`

    samtools fastq ${samtools_fastq_args} ${unmapped_bam} \\
        | bwa mem ${bwa_args} -t $task.cpus -p -K 150000000 -Y \$FASTA - \\
        | fgbio -Xmx${fgbio_mem_gb}g \\
            --compression ${fgbio_zipper_bams_compression} \\
            --async-io=true \\
            ZipperBams \\
            --unmapped ${unmapped_bam} \\
            --ref \$FASTA \\
            --output ${fgbio_zipper_bams_output} \\
            --tags-to-reverse Consensus \\
            --tags-to-revcomp Consensus \\
            ${fgbio_args} \\
            ${extra_command};

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(echo \$(bwa 2>&1) | sed 's/^.*Version: //; s/Contact:.*\$//')
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
