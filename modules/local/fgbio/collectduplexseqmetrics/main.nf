process FGBIO_COLLECTDUPLEXSEQMETRICS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/fgbio:2.5.21--1afc8befe439164b'
        : 'community.wave.seqera.io/library/fgbio:2.5.21--368dab1b4f308243'}"

    input:
    tuple val(meta), path(grouped_bam)

    output:
    tuple val(meta), path("*duplex_seq_metrics*.txt"), emit: metrics
    tuple val(meta), path("*duplex_qc.pdf"), emit: pdf
    tuple val("${task.process}"), val('fgbio'), eval("fgbio --version 2>&1 | tr -d '[:cntrl:]' | sed -e 's/^.*Version: //;s/\\[.*\$//'"), topic: versions, emit: versions_fgbio

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 8
    if (!task.memory) {
        log.info('[fgbio CollectDuplexSeqMetrics] Available memory not known - defaulting to 8GB. Specify process memory requirements to change this.')
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
        CollectDuplexSeqMetrics \\
        --input ${grouped_bam} \\
        --output ${prefix}.duplex_seq_metrics \\
        --duplex-umi-counts=true \\
        ${args};
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.duplex_seq_metrics.duplex_family_sizes.txt
    touch ${prefix}.duplex_seq_metrics.duplex_umi_counts.txt
    touch ${prefix}.duplex_seq_metrics.duplex_yield_metrics.txt
    touch ${prefix}.duplex_seq_metrics.family_sizes.txt
    touch ${prefix}.duplex_seq_metrics.umi_counts.txt
    touch ${prefix}.duplex_seq_metrics.duplex_qc.pdf
    """
}
