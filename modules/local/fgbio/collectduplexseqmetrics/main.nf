process FGBIO_COLLECTDUPLEXSEQMETRICS {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::fgbio=2.4.0"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/87/87626ef674e2f19366ae6214575a114fe80ce598e796894820550731706a84be/data'
        : 'community.wave.seqera.io/library/fgbio:2.4.0--913bad9d47ff8ddc'}"

    input:
    tuple val(meta), path(grouped_bam)

    output:
    tuple val(meta), path("*duplex_seq_metrics*.txt"), emit: metrics
    tuple val(meta), path("*duplex_seq_metrics*.pdf"), emit: pdf
    path "versions.yml", emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
    END_VERSIONS
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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
    END_VERSIONS
    """
}
