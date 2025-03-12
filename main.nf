#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/fastquorum
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/fastquorum
    Website: https://nf-co.re/fastquorum
    Slack  : https://nfcore.slack.com/channels/fastquorum
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_fastquorum_pipeline'

params.fasta     = getGenomeAttribute('fasta')
params.fasta_fai = getGenomeAttribute('fasta_fai')
params.dict      = getGenomeAttribute('dict')
params.bwa       = getGenomeAttribute('bwa')

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQUORUM              } from './workflows/fastquorum'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_fastquorum_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_fastquorum_pipeline'
include { PREPARE_GENOME          } from './subworkflows/local/prepare_genome'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_FASTQUORUM {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:
    // Initialize fasta file with meta map:
    fasta = params.fasta ? Channel.fromPath(params.fasta).map{ it -> [ [id:it.baseName], it ] }.collect() : Channel.empty()

    // Set various consensus calling and filtering parameters if not given
    if (params.duplex_seq) {
        if (params.groupreadsbyumi_strategy == '') { params.replace("groupreadsbyumi_strategy", 'Paired') }
        else if (params.groupreadsbyumi_strategy != 'Paired') {
            log.error "config groupreadsbyumi_strategy must be 'Paired' for duplex-sequencing data"
            exit 1
        }
        if (params.call_min_reads == '') { params.replace("call_min_reads", '1 1 0') }
        if (!params.filter_min_reads) { params.replace("filter_min_reads",  '3 1 1') }
    } else {
        if (params.groupreadsbyumi_strategy == '') { params.replace("groupreadsbyumi_strategy", 'Adjacency') }
        else if (params.groupreadsbyumi_strategy == 'Paired') {
            log.error "config groupreadsbyumi_strategy cannot be 'Paired' for non-duplex-sequencing data"
            exit 1
        }
        if (params.call_min_reads == '') { params.replace("call_min_reads", '1') }
        if (params.filter_min_reads == '') { params.replace("filter_min_reads", '3') }
    }

    // WORKFLOW: build indexes if needed
    PREPARE_GENOME(fasta)

    // Gather built indices or get them from the params
    // Built from the fasta file:
    dict      = params.dict         ? Channel.fromPath(params.dict).map{ it -> [ [id:'dict'], it ] }.collect()
                                    : PREPARE_GENOME.out.dict
    fasta_fai = params.fasta_fai    ? Channel.fromPath(params.fasta_fai).map{ it -> [ [id:'fai'], it ] }.collect()
                                    : PREPARE_GENOME.out.fasta_fai
    bwa       = params.bwa          ? Channel.fromPath(params.bwa).map{ it -> [ [id:'bwa'], it ] }.collect()
                                    : PREPARE_GENOME.out.bwa
    //
    // WORKFLOW: Run pipeline
    //
    FASTQUORUM (
        params,
        samplesheet,
        bwa,
        dict,
        fasta,
        fasta_fai
    )
    emit:
    multiqc_report = FASTQUORUM.out.multiqc_report // channel: /path/to/multiqc_report.html
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_FASTQUORUM (
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_FASTQUORUM.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
