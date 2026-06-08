process FGBIO_CORRECTUMIS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/87/b4047e3e517b57fae311eab139a12f0887d898b7da5fceeb2a1029c73b9e3904/data'
        : 'community.wave.seqera.io/library/fgbio:2.5.21--368dab1b4f308243'}"

    input:
    tuple val(meta), path(bam), path(umi_file)
    val(max_mismatches)
    val(min_distance)

    output:
    tuple val(meta), path("*.corrected.bam"), emit: bam
    tuple val(meta), path("*.rejected.bam"), emit: rejects
    tuple val(meta), path("*.correct-umis-metrics.txt"), emit: metrics
    tuple val("${task.process}"), val('fgbio'), eval("fgbio --version 2>&1 | tr -d '[:cntrl:]' | sed -e 's/^.*Version: //;s/\\[.*\$//'"), topic: versions, emit: versions_fgbio

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 1
    if (!task.memory) {
        log.info('[fgbio CorrectUmis] Available memory not known - defaulting to 1GB. Specify process memory requirements to change this.')
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
        CorrectUmis \\
        --input ${bam} \\
        --output ${prefix}.corrected.bam \\
        --reject ${prefix}.rejected.bam \\
        --metrics ${prefix}.correct-umis-metrics.txt \\
        --max-mismatches ${max_mismatches} \\
        --min-distance ${min_distance} \\
        --umi-files ${umi_file} \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.corrected.bam
    touch ${prefix}.rejected.bam
    touch ${prefix}.correct-umis-metrics.txt
    """
}
