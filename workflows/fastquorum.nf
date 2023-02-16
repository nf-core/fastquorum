/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowFastquorum.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.ref_fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Check mandatory parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }
if (params.ref_fasta) { ch_ref_fasta = Channel.fromPath(params.ref_fasta).collect() } else {
  log.error "No reference FASTA was specified (--ref_fasta)."
  exit 1
}

// The index directory is the directory that contains the FASTA
ch_ref_index_dir = ch_ref_fasta.map { it -> it.parent }

// Set various consensus calling and filtering parameters if not given
if (params.duplex_seq) {
  if (!params.groupreadsbyumi_strategy) { groupreadsbyumi_strategy = 'Paired' }
  else if (params.groupreadsbyumi_strategy != 'Paired') {
    log.error "config groupreadsbyumi_strategy must be 'Paired' for duplex-sequencing data"
    exit 1
  }
  if (!params.call_min_reads) { call_min_reads = '1 1 0' } else { call_min_reads = params.call_min_reads }
  if (!params.filter_min_reads) { filter_min_reads = '3 1 1' } else { filter_min_reads = params.filter_min_reads }
} else {
  if (!params.groupreadsbyumi_strategy) { groupreadsbyumi_strategy = 'Adjacency' }
  else if (params.groupreadsbyumi_strategy == 'Paired') {
    log.error "config groupreadsbyumi_strategy cannot be 'Paired' for non-duplex-sequencing data"
    exit 1
  } else {
	  groupreadsbyumi_strategy = params.groupreadsbyumi_strategy
  }
  if (!params.call_min_reads) { call_min_reads = '1' } else { call_min_reads = params.call_min_reads }
  if (!params.filter_min_reads) { filter_min_reads = '3' } else { filter_min_reads = params.filter_min_reads }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { ALIGN_BAM                         as ALIGN_RAW_BAM               } from '../modules/local/align_bam/main'
include { ALIGN_BAM                         as ALIGN_CONSENSUS_BAM         } from '../modules/local/align_bam/main'
include { FGBIO_FASTQTOBAM                  as FASTQTOBAM                  } from '../modules/local/fgbio/fastqtobam/main'
include { FGBIO_GROUPREADSBYUMI             as GROUPREADSBYUMI             } from '../modules/local/fgbio/groupreadsbyumi/main'
include { FGBIO_CALLMOLECULARCONSENSUSREADS as CALLMOLECULARCONSENSUSREADS } from '../modules/local/fgbio/callmolecularconsensusreads/main'
include { FGBIO_CALLDDUPLEXCONSENSUSREADS   as CALLDDUPLEXCONSENSUSREADS   } from '../modules/local/fgbio/callduplexconsensusreads/main'
include { FGBIO_FILTERCONSENSUSREADS        as FILTERCONSENSUSREADS        } from '../modules/local/fgbio/filterconsensusreads/main'
include { FGBIO_COLLECTDUPLEXSEQMETRICS     as COLLECTDUPLEXSEQMETRICS     } from '../modules/local/fgbio/collectduplexseqmetrics/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow FASTQUORUM {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        INPUT_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: Run fgbio FastqToBam
    //
    FASTQTOBAM(INPUT_CHECK.out.reads)

    //
    // MODULE: Align with bwa mem
    //
    grouped_sort = true
    ALIGN_RAW_BAM(FASTQTOBAM.out.bam, ch_ref_index_dir, grouped_sort)

    //
    // MODULE: Run fgbio GroupReadsByUmi
    //
    GROUPREADSBYUMI(ALIGN_RAW_BAM.out.bam, groupreadsbyumi_strategy, params.groupreadsbyumi_edits)

    // TODO: duplex_seq can be inferred from the read structure, but that's out of scope for now
    if (params.duplex_seq) {
        //
        // MODULE: Run fgbio CallDuplexConsensusReads
        //
        CALLDDUPLEXCONSENSUSREADS(GROUPREADSBYUMI.out.bam, call_min_reads, params.call_min_baseq)

        //
        // MODULE: Run fgbio CollecDuplexSeqMetrics
        //
        COLLECTDUPLEXSEQMETRICS(GROUPREADSBYUMI.out.bam)

        // Add the consensus BAM to the channel for downstream processing
        CALLDDUPLEXCONSENSUSREADS.out.bam.set { ch_consensus_bam }
    } else {
        //
        // MODULE: Run fgbio CallMolecularConsensusReads
        //
        CALLMOLECULARCONSENSUSREADS(GROUPREADSBYUMI.out.bam, call_min_reads, params.call_min_baseq)

        // Add the consensus BAM to the channel for downstream processing
        CALLMOLECULARCONSENSUSREADS.out.bam.set { ch_consensus_bam }
    }

    //
    // MODULE: Align with bwa mem
    //
    ALIGN_CONSENSUS_BAM(ch_consensus_bam, ch_ref_index_dir, false)

    //
    // MODULE: Run fgbio FilterConsensusReads
    //
    FILTERCONSENSUSREADS(ALIGN_CONSENSUS_BAM.out.bam, ch_ref_fasta, filter_min_reads, params.filter_min_baseq, params.filter_max_base_error_rate)

    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowFastquorum.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowFastquorum.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
