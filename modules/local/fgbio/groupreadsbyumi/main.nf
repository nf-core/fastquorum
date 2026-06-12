process FGBIO_GROUPREADSBYUMI {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/fgbio:2.5.21--1afc8befe439164b'
        : 'community.wave.seqera.io/library/fgbio:2.5.21--368dab1b4f308243'}"

    input:
    tuple val(meta), path(mapped_bam)
    val strategy
    val edits

    output:
    tuple val(meta), path("*.grouped.bam"), emit: bam
    tuple val(meta), path("*.grouped-family-sizes.txt"), emit: histogram
    tuple val(meta), path("*.grouped-read-metrics.txt"), emit: read_metrics
    tuple val("${task.process}"), val('fgbio'), eval("fgbio --version 2>&1 | tr -d '[:cntrl:]' | sed -e 's/^.*Version: //;s/\\[.*\$//'"), topic: versions, emit: versions_fgbio

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 8
    if (!task.memory) {
        log.info('[fgbio GroupReadsByUmi] Available memory not known - defaulting to 8GB. Specify process memory requirements to change this.')
    }
    else {
        mem_gb = task.memory.giga
    }

    """
    fgbio \\
        -Xmx${mem_gb}g \\
        --tmp-dir=. \\
        --async-io=true \\
        --compression=1 \\
        GroupReadsByUmi \\
        --strategy ${strategy} \\
        --edits ${edits} \\
        --input ${mapped_bam} \\
        --output ${prefix}.grouped.bam \\
        --family-size-histogram ${prefix}.grouped-family-sizes.txt \\
        --grouping-metrics ${prefix}.grouped-read-metrics.txt \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.grouped.bam
    touch ${prefix}.grouped-family-sizes.txt
    touch ${prefix}.grouped-read-metrics.txt
    """
}
