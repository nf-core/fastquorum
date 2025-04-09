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

    // To gather all QC reports for MultiQC
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    //
    // MODULE: Run FastQC
    //
    FASTQC(
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { it[1] })

    //
    // MODULE: Run fgbio FastqToBam
    //
    FASTQTOBAM(ch_samplesheet)
    ch_versions = ch_versions.mix(FASTQTOBAM.out.versions.first())

    //
    // MODULE: Align with bwa mem
    //
    ALIGN_RAW_BAM(FASTQTOBAM.out.bam, ch_fasta, ch_fasta_fai, ch_dict, ch_bwa, "template-coordinate")
    ch_versions = ch_versions.mix(ALIGN_RAW_BAM.out.versions.first())

    //
    // Create a channel that:
    // 1. Groups the aligned BAMs by sample identifier.  We use `groupKey` here since we know how many BAMs each
    //    sample expects to have.  Typically a sample has more than one BAM if it had multiple runs or lanes.
    // 2. Splits the samples into those that have more than one BAM, and those that have exactly one BAM.  The former
    //    samples will have their BAMs merged.
    //
    // The `n_samples` is added by `validateInputSamplesheet` method in `PIPELINE_INITIALISATION` workflow
    // NB: bam is a list (of one BAM) so return just the one BAM
    bam_to_merge = ALIGN_RAW_BAM.out.bam
        .map { meta, bam ->
            [groupKey(meta, meta.n_samples), bam]
        }
        .groupTuple()
        .branch { meta, bam ->
            single: meta.n_samples <= 1
            return [meta, bam[0]]
            multiple: meta.n_samples > 1
        }

    //
    // MODULE: Run samtools merge to merge across runs/lanes for the same sample
    //
    MERGE_BAM(bam_to_merge.multiple, [[], []], [[], []])
    ch_versions = ch_versions.mix(MERGE_BAM.out.versions.first())

    //
    // Create a channel that contains the merged BAMs and those that did not need to be merged.
    //
    bam_all = MERGE_BAM.out.bam.mix(bam_to_merge.single)

    //
    // MODULE: Run fgbio GroupReadsByUmi
    //
    GROUPREADSBYUMI(bam_all, params.groupreadsbyumi_strategy, params.groupreadsbyumi_edits)
    ch_multiqc_files = ch_multiqc_files.mix(GROUPREADSBYUMI.out.histogram.map { it[1] }.collect())
    ch_versions = ch_versions.mix(GROUPREADSBYUMI.out.versions.first())

    if (params.duplex_seq) {
        //
        // MODULE: Run fgbio CollectDuplexSeqMetrics
        //
        COLLECTDUPLEXSEQMETRICS(GROUPREADSBYUMI.out.bam)
        ch_versions = ch_versions.mix(COLLECTDUPLEXSEQMETRICS.out.versions.first())
    }

    // TODO: duplex_seq can be inferred from the read structure, but that's out of scope for now
    if (params.mode == 'rd') {
        if (params.duplex_seq) {
            //
            // MODULE: Run fgbio CallDuplexConsensusReads
            //
            CALLDDUPLEXCONSENSUSREADS(GROUPREADSBYUMI.out.bam, params.call_min_reads, params.call_min_baseq)
            ch_versions = ch_versions.mix(CALLDDUPLEXCONSENSUSREADS.out.versions.first())

            // Add the consensus BAM to the channel for downstream processing
            CALLDDUPLEXCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }
        else {
            //
            // MODULE: Run fgbio CallMolecularConsensusReads
            //
            CALLMOLECULARCONSENSUSREADS(GROUPREADSBYUMI.out.bam, params.call_min_reads, params.call_min_baseq)
            ch_versions = ch_versions.mix(CALLMOLECULARCONSENSUSREADS.out.versions.first())

            // Add the consensus BAM to the channel for downstream processing
            CALLMOLECULARCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }

        //
        // MODULE: Align with bwa mem
        //
        ALIGN_CONSENSUS_BAM(ch_consensus_bam, ch_fasta, ch_fasta_fai, ch_dict, ch_bwa, "none")
        ch_versions = ch_versions.mix(ALIGN_CONSENSUS_BAM.out.versions.first())

        //
        // MODULE: Run fgbio FilterConsensusReads
        //
        FILTERCONSENSUSREADS(ALIGN_CONSENSUS_BAM.out.bam, ch_fasta, params.filter_min_reads, params.filter_min_baseq, params.filter_max_base_error_rate)
        ch_versions = ch_versions.mix(FILTERCONSENSUSREADS.out.versions.first())
    }
    else {
        if (params.duplex_seq) {
            //
            // MODULE: Run fgbio CallDuplexConsensusReads and fgbio FilterConsensusReads
            //
            CALLANDFILTERDUPLEXCONSENSUSREADS(GROUPREADSBYUMI.out.bam, ch_fasta, ch_fasta_fai, params.call_min_reads, params.call_min_baseq, params.filter_max_base_error_rate)
            ch_versions = ch_versions.mix(CALLANDFILTERDUPLEXCONSENSUSREADS.out.versions.first())

            // Add the consensus BAM to the channel for downstream processing
            CALLANDFILTERDUPLEXCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }
        else {
            //
            // MODULE: Run fgbio CallMolecularConsensusReads and fgbio FilterConsensusReads
            //
            CALLANDFILTERMOLECULARCONSENSUSREADS(GROUPREADSBYUMI.out.bam, ch_fasta, ch_fasta_fai, params.call_min_reads, params.call_min_baseq, params.filter_max_base_error_rate)
            ch_versions = ch_versions.mix(CALLANDFILTERMOLECULARCONSENSUSREADS.out.versions.first())

            // Add the consensus BAM to the channel for downstream processing
            CALLANDFILTERMOLECULARCONSENSUSREADS.out.bam.set { ch_consensus_bam }
        }

        //
        // MODULE: Align with bwa mem
        //
        ALIGN_CONSENSUS_BAM(ch_consensus_bam, ch_fasta, ch_fasta_fai, ch_dict, ch_bwa, "coordinate")
        ch_versions = ch_versions.mix(ALIGN_CONSENSUS_BAM.out.versions.first())
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
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
    ch_multiqc_config = Channel.fromPath(
        "${projectDir}/assets/multiqc_config.yml",
        checkIfExists: true
    )
    ch_multiqc_custom_config = params.multiqc_config
        ? Channel.fromPath(params.multiqc_config, checkIfExists: true)
        : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo
        ? Channel.fromPath(params.multiqc_logo, checkIfExists: true)
        : Channel.empty()

    summary_params = paramsSummaryMap(
        workflow,
        parameters_schema: "nextflow_schema.json"
    )
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
    )
    ch_multiqc_custom_methods_description = params.multiqc_methods_description
        ? file(params.multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description)
    )

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true,
        )
    )

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions // channel: [ path(versions.yml) ]
}
