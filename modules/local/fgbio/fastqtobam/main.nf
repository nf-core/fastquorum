process FGBIO_FASTQTOBAM {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::fgbio=2.5.21"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/87/b4047e3e517b57fae311eab139a12f0887d898b7da5fceeb2a1029c73b9e3904/data'
        : 'community.wave.seqera.io/library/fgbio:2.5.21--368dab1b4f308243'}"

    input:
    tuple val(meta), path(fastqs)

    output:
    tuple val(meta), path("*.unmapped.bam"), emit: bam
    tuple val("${task.process}"), val('fgbio'), eval("fgbio --version 2>&1 | tr -d '[:cntrl:]' | sed -e 's/^.*Version: //;s/\\[.*\$//'"), topic: versions, emit: versions_fgbio

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 1
    def read_structure = "${meta.read_structure}"
    if (!task.memory) {
        log.info('[fgbio FastqToBam] Available memory not known - defaulting to 1GB. Specify process memory requirements to change this.')
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
        FastqToBam \\
        --input ${fastqs} \\
        --output "${prefix}.unmapped.bam" \\
        --read-structures ${read_structure} \\
        --sample ${meta.sample} \\
        --library ${meta.id} \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.unmapped.bam
    """
}
