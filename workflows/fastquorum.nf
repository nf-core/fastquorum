/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_fastquorum_pipeline'

include { ALIGN_BAM as ALIGN_RAW_BAM } from '../modules/local/align_bam/main'
include { ALIGN_BAM as ALIGN_CONSENSUS_BAM } from '../modules/local/align_bam/main'
include { FASTQC } from '../modules/nf-core/fastqc/main'
include { FGBIO_FASTQTOBAM as FASTQTOBAM } from '../modules/local/fgbio/fastqtobam/main'
include { FGBIO_CORRECTUMIS as CORRECTUMIS } from '../modules/local/fgbio/correctumis/main'
include { FGBIO_GROUPREADSBYUMI as GROUPREADSBYUMI } from '../modules/local/fgbio/groupreadsbyumi/main'
include { FGBIO_CALLMOLECULARCONSENSUSREADS as CALLMOLECULARCONSENSUSREADS } from '../modules/local/fgbio/callmolecularconsensusreads/main'
include { FGBIO_CALLDDUPLEXCONSENSUSREADS as CALLDDUPLEXCONSENSUSREADS } from '../modules/local/fgbio/callduplexconsensusreads/main'
include { FGBIO_FILTERCONSENSUSREADS as FILTERCONSENSUSREADS } from '../modules/local/fgbio/filterconsensusreads/main'
include { FGBIO_COLLECTDUPLEXSEQMETRICS as COLLECTDUPLEXSEQMETRICS } from '../modules/local/fgbio/collectduplexseqmetrics/main'
include { FGBIO_CALLANDFILTERMOLECULARCONSENSUSREADS as CALLANDFILTERMOLECULARCONSENSUSREADS } from '../modules/local/fgbio/callandfiltermolecularconsensusreads/main'
include { FGBIO_CALLANDFILTERDUPLEXCONSENSUSREADS as CALLANDFILTERDUPLEXCONSENSUSREADS } from '../modules/local/fgbio/callandfilterduplexconsensusreads/main'
include { SAMTOOLS_MERGE as MERGE_BAM } from '../modules/nf-core/samtools/merge/main'

include { MULTIQC } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FASTQUORUM {
    take:
    params // NB: must pass params; see https://github.com/nextflow-io/nextflow/issues/4982
    ch_samplesheet
    ch_bwa
    ch_dict
    ch_fasta
    ch_fasta_fai

    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()
    //
    // MODULE: Run FastQC
    //
    FASTQC(
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { meta_item -> meta_item[1] })

    //
    // MODULE: Run fgbio FastqToBam
    //
    FASTQTOBAM(ch_samplesheet)

    //
    // MODULE: Run fgbio CorrectUmis (for non-random UMIs)
    //
    FASTQTOBAM.out.bam
        .branch { meta, bam ->
            correct: meta.umi_file
            passthrough: true
        }
        .set { ch_fastqtobam }

    // Warn if UMI correction is in use with a fuzzy-matching grouping strategy
    ch_fastqtobam.correct.first().map { meta, bam ->
        if (params.groupreadsbyumi_strategy != 'Identity' &&
            !(params.groupreadsbyumi_strategy == 'Paired' && params.groupreadsbyumi_edits == 0)) {
            log.warn("UMI correction is enabled but groupreadsbyumi_strategy is " +
                     "'${params.groupreadsbyumi_strategy}' with edits=${params.groupreadsbyumi_edits}. " +
                     "Consider using 'Identity' or 'Paired' with edits=0 for corrected UMIs.")
        }
    }

    CORRECTUMIS(
        ch_fastqtobam.correct.map { meta, bam -> [meta, bam, file(meta.umi_file)] },
        params.correct_umis_max_mismatches,
        params.correct_umis_min_distance,
    )

    // Mix corrected and passthrough BAMs
    ch_unmapped_bam = CORRECTUMIS.out.bam.mix(ch_fastqtobam.passthrough)

    //
    // MODULE: Align with bwa mem
    //
    ALIGN_RAW_BAM(ch_unmapped_bam, ch_fasta, ch_fasta_fai, ch_dict, ch_bwa, "template-coordinate")

    //
    // Create a channel that:
    // 1. Groups the aligned BAMs by library identifier.  We use `groupKey` here since we know how many BAMs each
    //    library expects to have.  Typically a library has more than one BAM if it had multiple runs or lanes.
    // 2. Splits the libraries into those that have more than one BAM, and those that have exactly one BAM.  The former
    //    libraries will have their BAMs merged.
    //
    // The `n_merge_pre_consensus` is added by `validateInputSamplesheet` method in `PIPELINE_INITIALISATION` workflow
    // NB: bam is a list (of one BAM) so return just the one BAM
    bam_to_merge = ALIGN_RAW_BAM.out.bam
        .map { meta, bam ->
            def merge_meta = meta.findAll { k, _v -> !(k in ['lane', 'flowcell']) }
            [groupKey(merge_meta, meta.n_merge_pre_consensus), bam]
        }
        .groupTuple()
        .branch { meta, bam ->
            single: meta.n_merge_pre_consensus <= 1
            return [meta, bam[0]]
            multiple: meta.n_merge_pre_consensus > 1
        }

    //
    // MODULE: Run samtools merge to merge across runs/lanes for the same sample
    //
    MERGE_BAM(bam_to_merge.multiple.map { meta, bam -> [meta, bam, []] }, [[], [], [], []])

    //
    // Create a channel that contains the merged BAMs and those that did not need to be merged.
    //
    bam_all = MERGE_BAM.out.bam.mix(bam_to_merge.single)

    //
    // MODULE: Run fgbio GroupReadsByUmi
    //
    GROUPREADSBYUMI(bam_all, params.groupreadsbyumi_strategy, params.groupreadsbyumi_edits)
    ch_multiqc_files = ch_multiqc_files.mix(GROUPREADSBYUMI.out.histogram.map { meta_item -> meta_item[1] }.collect())

    if (params.duplex_seq) {
        //
        // MODULE: Run fgbio CollectDuplexSeqMetrics
        //
        COLLECTDUPLEXSEQMETRICS(GROUPREADSBYUMI.out.bam)
    }

    // TODO: duplex_seq can be inferred from the read structure, but that's out of scope for now
    if (params.mode == 'rd') {
        if (params.duplex_seq) {
            //
            // MODULE: Run fgbio CallDuplexConsensusReads
            //
            CALLDDUPLEXCONSENSUSREADS(GROUPREADSBYUMI.out.bam, params.call_min_reads, params.call_min_baseq)

            // Add the consensus BAM to the channel for downstream processing
            CALLDDUPLEXCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }
        else {
            //
            // MODULE: Run fgbio CallMolecularConsensusReads
            //
            CALLMOLECULARCONSENSUSREADS(GROUPREADSBYUMI.out.bam, params.call_min_reads, params.call_min_baseq)

            // Add the consensus BAM to the channel for downstream processing
            CALLMOLECULARCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }

        //
        // MODULE: Align with bwa mem
        //
        ALIGN_CONSENSUS_BAM(ch_consensus_bam, ch_fasta, ch_fasta_fai, ch_dict, ch_bwa, "none")

        //
        // MODULE: Run fgbio FilterConsensusReads
        //
        FILTERCONSENSUSREADS(ALIGN_CONSENSUS_BAM.out.bam, ch_fasta, params.filter_min_reads, params.filter_min_baseq, params.filter_max_base_error_rate)
    }
    else {
        if (params.duplex_seq) {
            //
            // MODULE: Run fgbio CallDuplexConsensusReads and fgbio FilterConsensusReads
            //
            CALLANDFILTERDUPLEXCONSENSUSREADS(GROUPREADSBYUMI.out.bam, ch_fasta, ch_fasta_fai, params.call_min_reads, params.call_min_baseq, params.filter_max_base_error_rate)

            // Add the consensus BAM to the channel for downstream processing
            CALLANDFILTERDUPLEXCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }
        else {
            //
            // MODULE: Run fgbio CallMolecularConsensusReads and fgbio FilterConsensusReads
            //
            CALLANDFILTERMOLECULARCONSENSUSREADS(GROUPREADSBYUMI.out.bam, ch_fasta, ch_fasta_fai, params.call_min_reads, params.call_min_baseq, params.filter_max_base_error_rate)

            // Add the consensus BAM to the channel for downstream processing
            CALLANDFILTERMOLECULARCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }

        //
        // MODULE: Align with bwa mem
        //
        ALIGN_CONSENSUS_BAM(ch_consensus_bam, ch_fasta, ch_fasta_fai, ch_dict, ch_bwa, "coordinate")
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_' + 'fastquorum_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true,
        )
    )

    MULTIQC(
        ch_multiqc_files.collect().map { files ->
            [
                [id: 'fastquorum'],
                files,
                params.multiqc_config
                    ? [file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true), file(params.multiqc_config, checkIfExists: true)]
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                params.multiqc_logo ? file(params.multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions // channel: [ path(versions.yml) ]
}
