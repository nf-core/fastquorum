process FGBIO_FASTQTOBAM {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::fgbio=2.4.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/87/87626ef674e2f19366ae6214575a114fe80ce598e796894820550731706a84be/data' :
        'community.wave.seqera.io/library/fgbio:2.4.0--913bad9d47ff8ddc' }"

    input:
    tuple val(meta), path(fastqs)

    output:
    tuple val(meta), path("*.unmapped.bam"), emit: bam
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 1
    def read_structure = "${meta.read_structure}"
    if (!task.memory) {
        log.info '[fgbio FastqToBam] Available memory not known - defaulting to 1GB. Specify process memory requirements to change this.'
    } else {
        mem_gb = task.memory.giga
    }
    """

    fgbio \\
        -Xmx${mem_gb}g \\
        --tmp-dir=. \\
        --async-io=true \\
        --compression=1 \\
        FastqToBam \\
        --input ${fastqs} \\
        --output "${prefix}.unmapped.bam" \\
        --read-structures ${read_structure} \\
        --sample ${meta.id} \\
        --library ${meta.id} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.unmapped.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
    END_VERSIONS
    """
}
