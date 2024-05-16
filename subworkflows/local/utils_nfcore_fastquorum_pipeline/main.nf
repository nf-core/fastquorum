//
// Subworkflow with functionality specific to the nf-core/fastquorum pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )
    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    // Check input path parameters to see if they exist
    def checkPathParamList = [
        params.bwa,
        params.dict,
        params.fasta,
        params.fasta_fai

    ]

    //
    // Create channel from input file provided through params.input
    //
    Channel
        .fromSamplesheet("input")
        .map {
            // Supports up to four FASTQs.  FASTQs that are not present will be empty lists
            meta, fastq_1, fastq_2, fastq_3, fastq_4 ->
                return [ meta.id, meta, [fastq_1, fastq_2, fastq_3, fastq_4 ] ]
        }
        .map {
          // Validate a given _row_ in the sample sheet.  Does not compare runs (e.g. lanes) for a given sample across
          // rows
          validateInputSamplesheetRow(it)
        }
        .groupTuple()  // group by sample identifier
        .map {
            // Validate runs (e.g. lanes) for a given sample.
            validateInputSamplesheet(it)
        }
        .flatMap {
            // Convert back to having one item per run (not sample).  This enables us to pre-process each run
            // independently up through mapping, then merge them prior to grouping by UMI.
            meta, fastqs ->
                fastqs.collect { return [ meta, it ] }
        }
        .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:

    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs, multiqc_report.toList())
        }

        completionSummary(monochrome_logs)

        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/
//
// Check and validate pipeline parameters
//
def validateInputParameters() {
    genomeExistsError()
}

// Validates channels from input samplesheet _before_ grouping by the sample identifier
//
// Assumes that multiples runs (e.g. lanes) for a given sample have not been grouped together.  Row should be a tuple:
// 1. The unique sample identifier
// 2. The metadata for the sample
// 3. The list of FASTQs to use for the sample
//
// Validates:
// 1. The number of FASTQs matches the number of segments in the read structure.  E.g. for paired end reads, there must
//    be two FASTQs (R1 and R2), and two segments in the read structure (e.g. "12M+T" and "+T").  NB: a read structure
//    is a space delimited string where each value is a _read segment_.  See:
//    https://github.com/fulcrumgenomics/fgbio/wiki/Read-Structures
def validateInputSamplesheetRow(row) {
    def (meta, fastqs) = row[1..2]
    def num_segments = meta.read_structure.tokenize(" ").size()
    def num_fastqs = fastqs.flatten().size()
    if (num_segments < num_fastqs) {
        error("Please check input samplesheet -> Too few read structures (${num_segments}) for ${num_fastqs} FASTQs for ${meta.id}")
    } else if (num_segments > num_fastqs) {
        error("Please check input samplesheet -> Too many read structures (${num_segments}) for ${num_fastqs} FASTQs for ${meta.id}")
    }

    // NB: the collect here doesn't care which FASTQ list is empty
    return [ row[0], row[1], row[2].findAll { it -> it.size() > 0 } ]
}

//
// Validate channels from input samplesheet _after_ grouping by the sample identifier
//
// Assumes that multiple runs (e.g. lanes) for a given sample have been grouped together.  Input should be a tuple:
// 1. The unique sample identifier
// 2. The list of run-specific metadata.  NB: all runs must have the same `id` property, matching (1).
// 3. The list of run-specific FASTQs in the same order as (2).  Each run will have a list of FASTQs (e.g. paired end).
//
// Validates:
// 1. The number of FASTQs is the same across all runs.  E.g. all runs are paired end.
// 2. The read structure is the same for all runs.
//
// Returns:
// Adds the `n_samples` property to the metadata, and returns a tuple of the metadata and list of list of FASTQs.
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]
    def fastqs_per_sample_ok = fastqs.collect { it.size() }.unique().size == 1
    if (!fastqs_per_sample_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must have the same number of FASTQs: ${metas[0].id}")
    }
    def read_structures_ok = metas.collect { it.read_structure }.unique().size == 1
    if (!read_structures_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must have the same read stucture: ${metas[0].id}")
    }

    return [ metas[0] + [ n_samples: metas.size() ], fastqs ]
}

//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[ params.genome ].containsKey(attribute)) {
            return params.genomes[ params.genome ][ attribute ]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available genome keys are:\n" +
            "  ${params.genomes.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "BWA (Li 2013)",
            "FastQC (Andrews 2010),",
            "FGBio (doi: 10.5281/zenodo.10456900)",
            "MultiQC (Ewels et al. 2016)",
            "SAMtools (Li 2009)",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
            "<li>Li H. Aligning sequence reads, clone sequences and assembly contigs with BWA-MEM. arXiv. 2013 May 26. doi: 10.48550/arXiv.1303.3997<li>",
            "<li>Andrews S, (2010) FastQC, URL: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/</li>",
            "<li>Homer N, Fennell T, et al. (2024). fulcrumgenomics/fgbio: Release 2.2.1 (2.2.1). Zenodo. https://doi.org/10.5281/zenodo.10456901</li>",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>",
            "<li>Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R; 1000 Genome Project Data Processing Subgroup. The Sequence Alignment/Map format and SAMtools. Bioinformatics. 2009 Aug 15;25(16):2078-9. doi: 10.1093/bioinformatics/btp352. Epub 2009 Jun 8. PubMed PMID: 19505943; PubMed Central PMCID: PMC2723002.</li>"
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    meta["doi_text"] = meta.manifest_map.doi ? "(doi: <a href=\'https://doi.org/${meta.manifest_map.doi}\'>${meta.manifest_map.doi}</a>)" : ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "": "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()

    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
