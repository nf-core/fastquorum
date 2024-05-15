process FGBIO_FILTERCONSENSUSREADS {
    tag "$meta.id"
    label 'process_medium_mem'

    conda "bioconda::fgbio=2.0.2 bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-69f5207f538e4de9ef3bae6f9a95c5af56a88ab8:82d3ec41f9f1227f7183d344be46f73365efa704-0' :
        'quay.io/biocontainers/mulled-v2-69f5207f538e4de9ef3bae6f9a95c5af56a88ab8:82d3ec41f9f1227f7183d344be46f73365efa704-0' }"

    input:
    tuple val(meta), path(consensus_bam)
    tuple val(genome), path(fasta)
    val(min_reads)
    val(min_baseq)
    val(max_base_error_rate)

    output:
    tuple val(meta), path("*.cons.filtered.bam")       , emit: bam
    path "versions.yml"                                , emit: versions

    script:
    def fgbio_args = task.ext.fgbio_args ?: ''
    def samtools_args = task.ext.samtools_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 8
    if (!task.memory) {
        log.info '[fgbio FilterConsensusReads] Available memory not known - defaulting to 8GB. Specify process memory requirements to change this.'
    } else {
        mem_gb = task.memory.giga
    }

    """
    fgbio \\
        -Xmx${mem_gb}g \\
        --tmp-dir=. \\
        --compression=0 \\
        FilterConsensusReads \\
        --input $consensus_bam \\
        --output /dev/stdout \\
        --ref ${fasta} \\
        --min-reads ${min_reads} \\
        --min-base-quality ${min_baseq} \\
        --max-base-error-rate ${max_base_error_rate} \\
        $fgbio_args \\
        | samtools sort \\
        --threads ${task.cpus} \\
        -o ${prefix}.cons.filtered.bam##idx##${prefix}.cons.filtered.bam.bai \\
        --write-index \\
        $samtools_args;

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
    END_VERSIONS
    """
}
