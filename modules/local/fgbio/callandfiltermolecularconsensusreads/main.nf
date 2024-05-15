process FGBIO_CALLANDFILTERMOLECULARCONSENSUSREADS {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::fgbio=2.0.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fgbio:2.0.2--hdfd78af_0' :
        'quay.io/biocontainers/fgbio:2.0.2--hdfd78af_0' }"

    input:
    tuple val(meta), path(grouped_bam)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fasta_fai)
    val(min_reads)
    val(min_baseq)
    val(max_base_error_rate)

    output:
    tuple val(meta), path("*.cons.filtered.bam") , emit: bam
    path "versions.yml"                          , emit: versions

    script:
    def fgbio_call_args = task.ext.fgbio_call_args ?: ''
    def fgbio_filter_args = task.ext.fgbio_filter_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def call_mem_gb = 4
    def filter_mem_gb = 8
    if (!task.memory) {
        log.info '[fgbio CallDuplexConsensusReads] Available memory not known - defaulting to 4GB. Specify process memory requirements to change this.'
        log.info '[fgbio FilterConsensusReads] Available memory not known - defaulting to 8GB. Specify process memory requirements to change this.'
    } else {
        mem_gb = task.memory.giga
        if (mem_gb - filter_mem_gb < 4) {
            log.info 'FGBIO_CALLMOLECULARCONSENSUSREADS may not have enough memory'
        } else {
            call_mem_gb = mem_gb - filter_mem_gb
        }
    }

    """
    fgbio \\
        -Xmx${call_mem_gb}g \\
        --tmp-dir=. \\
        --async-io=true \\
        --compression=1 \\
        CallMolecularConsensusReads \\
        --input ${grouped_bam} \\
        --output /dev/stdout \\
        --min-reads ${min_reads} \\
        --min-input-base-quality ${min_baseq} \\
        --threads ${task.cpus} \\
        $fgbio_call_args |
        fgbio \\
        -Xmx${filter_mem_gb}g \\
        --tmp-dir=. \\
        --compression=0 \\
        FilterConsensusReads \\
        --input /dev/stdin \\
        --output ${prefix}.cons.filtered.bam \\
        --ref ${fasta} \\
        --min-reads ${min_reads} \\
        --min-base-quality ${min_baseq} \\
        --max-base-error-rate ${max_base_error_rate} \\
        $fgbio_filter_args;

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fgbio: \$( echo \$(fgbio --version 2>&1 | tr -d '[:cntrl:]' ) | sed -e 's/^.*Version: //;s/\\[.*\$//')
    END_VERSIONS
    """
}
