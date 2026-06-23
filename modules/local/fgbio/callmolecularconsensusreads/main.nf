process FGBIO_CALLMOLECULARCONSENSUSREADS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/fgbio:2.5.21--1afc8befe439164b'
        : 'community.wave.seqera.io/library/fgbio:2.5.21--368dab1b4f308243'}"

    input:
    tuple val(meta), path(grouped_bam)
    val min_reads
    val min_baseq

    output:
    tuple val(meta), path("*.cons.unmapped.bam"), emit: bam
    tuple val("${task.process}"), val('fgbio'), eval("fgbio --version 2>&1 | tr -d '[:cntrl:]' | sed -e 's/^.*Version: //;s/\\[.*\$//'"), topic: versions, emit: versions_fgbio

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_gb = 8
    if (!task.memory) {
        log.info('[fgbio CallMolecularConsensusReads] Available memory not known - defaulting to 8GB. Specify process memory requirements to change this.')
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
        CallMolecularConsensusReads \\
        --input ${grouped_bam} \\
        --output ${prefix}.cons.unmapped.bam \\
        --min-reads ${min_reads} \\
        --min-input-base-quality ${min_baseq} \\
        --threads ${task.cpus} \\
        ${args};
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.cons.unmapped.bam
    """
}
