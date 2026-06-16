process FGBIO_FILTERCONSENSUSREADS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/fgbio_samtools:b4fdf6d47eb1eb4a'
        : 'community.wave.seqera.io/library/fgbio_samtools:4f7e98e5f90057a3'}"


    input:
    tuple val(meta), path(consensus_bam)
    tuple val(genome), path(fasta)
    val min_reads
    val min_baseq
    val max_base_error_rate

    output:
    tuple val(meta), path("*.cons.filtered.bam"), emit: bam
    tuple val(meta), path("*.cons.filtered.bam.bai"), emit: bai
    tuple val("${task.process}"), val('fgbio'), eval("fgbio --version 2>&1 | tr -d '[:cntrl:]' | sed -e 's/^.*Version: //;s/\\[.*\$//'"), topic: versions, emit: versions_fgbio
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), topic: versions, emit: versions_samtools

    script:
    def fgbio_args = task.ext.fgbio_args ?: ''
    def samtools_args = task.ext.samtools_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 8
    if (!task.memory) {
        log.info('[fgbio FilterConsensusReads] Available memory not known - defaulting to 8GB. Specify process memory requirements to change this.')
    }
    else {
        mem_gb = task.memory.giga
    }

    """
    fgbio \\
        -Xmx${mem_gb}g \\
        --tmp-dir=. \\
        --compression=0 \\
        FilterConsensusReads \\
        --input ${consensus_bam} \\
        --output /dev/stdout \\
        --ref ${fasta} \\
        --min-reads ${min_reads} \\
        --min-base-quality ${min_baseq} \\
        --max-base-error-rate ${max_base_error_rate} \\
        ${fgbio_args} \\
        | samtools sort \\
        --threads ${task.cpus} \\
        -o ${prefix}.cons.filtered.bam##idx##${prefix}.cons.filtered.bam.bai \\
        --write-index \\
        ${samtools_args};
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.cons.filtered.bam
    touch ${prefix}.cons.filtered.bam.bai
    """
}
