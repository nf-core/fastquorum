//
// Subworkflow with functionality specific to the nf-core/fastquorum pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { samplesheetToList } from 'plugin/nf-schema'
include { readStructure } from 'plugin/nf-fgbio'
include { completionEmail } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {
    take:
    version // boolean: Display version and exit
    validate_params // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir //  string: The output directory where the results will be saved
    input //  string: Path to input samplesheet
    help
    help_full
    show_hidden

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1,
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    def before_text = """
-\033[2m----------------------------------------------------\033[0m-
                                        \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                        \033[0;32m`._,._,\'\033[0m
\033[0;35m  nf-core/fastquorum ${workflow.manifest.version}\033[0m
-\033[2m----------------------------------------------------\033[0m-
"""
    def after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/', '')}" }.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/nf-core/fastquorum/blob/main/CITATIONS.md
"""
    def command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN(
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    //
    // Create channel from input file provided through params.input
    //

    // Parse samplesheet into a plain Groovy list — ordering is deterministic
    def rows = samplesheetToList(params.input, "${projectDir}/assets/schema_input.json")

    // Step 1: Compute meta.id and validate each row
    rows = rows.collect { meta, fastq_1, fastq_2, fastq_3, fastq_4 ->
        meta.id = meta.library_id != null ? meta.library_id : meta.sample
        return validateInputSamplesheetRow([meta.id, meta, [fastq_1, fastq_2, fastq_3, fastq_4]])
    }

    // Step 2: Cross-group validation (library_id constraints)
    validateLibraryIds(rows)

    // Step 3: Group by meta.id, validate within-group, and flatten to per-run items
    def processed = rows.groupBy { row -> row[0] }
        .collectMany { id, groupRows ->
            def metas = groupRows.collect { r -> r[1] }
            def fastqs = groupRows.collect { r -> r[2] }
            validateInputSamplesheet(id, metas, fastqs)
        }

    // Step 4: Create channel from the fully validated, ordered list
    channel.fromList(processed).set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {
    take:
    email // string: email address
    email_on_fail // string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir // path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url // string: hook URL for notifications
    multiqc_report // string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
    }
    else if (num_segments > num_fastqs) {
        error("Please check input samplesheet -> Too many read structures (${num_segments}) for ${num_fastqs} FASTQs for ${meta.id}")
    }

    // Validate the read structure
    meta.read_structure.tokenize(" ").each { rs->
        // If parsing the read structure fails, then a java.lang.reflect.InvocationTargetException will be thrown, with
        // the cause containing the exception produced by fgbio.
        try {
            readStructure(rs)
        } catch (java.lang.reflect.InvocationTargetException ex) {
            def message = """
                |Please check input samplesheet -> Read structure`${rs}` invalid
                |
                |   ${ex.getCause().getMessage()}
                |
                |   For more information on read structures, visit: https://github.com/fulcrumgenomics/fgbio/wiki/Read-Structures
                |
                |   Validate your read structures here: https://fulcrumgenomics.github.io/fgbio/validate-read-structure.html
                |""".stripMargin()
            error(message)
            throw ex
        }
    }

    // NB: the collect here doesn't care which FASTQ list is empty
    return [row[0], row[1], row[2].findAll { fq -> fq.size() > 0 }]
}

//
// Validate library_id constraints across all samples
//
def validateLibraryIds(rows) {
    // All-or-nothing: if any row for a sample provides library_id, all must
    rows.groupBy { row -> row[1].sample }.each { sample, sampleRows ->
        def lib_ids = sampleRows.collect { r -> r[1].library_id }
        def provided = lib_ids.findAll { v -> v != null }
        if (provided.size() > 0 && provided.size() != lib_ids.size()) {
            error("Please check input samplesheet -> if library_id is provided for any row of a sample, it must be provided for all rows: ${sample}")
        }
    }

    // Global uniqueness: library_id must not be reused across different samples
    def lib_to_sample = [:]
    rows.each { row ->
        def lib = row[1].library_id
        if (lib != null) {
            def sample = row[1].sample
            if (lib_to_sample.containsKey(lib) && lib_to_sample[lib] != sample) {
                error("Please check input samplesheet -> library_id '${lib}' is used for multiple samples: ${lib_to_sample[lib]} and ${sample}")
            }
            lib_to_sample[lib] = sample
        }
    }
}

//
// Validate channels from input samplesheet _after_ grouping by the processing unit identifier (meta.id).
//
// Validates:
// 1. The number of FASTQs is the same across all runs.
// 2. The read structure is the same for all runs.
// 3. If provided, the UMI file is the same for all runs of a sample.
// 4. Lane and flowcell follow all-or-nothing rules.
// 5. (flowcell, lane) pairs are unique when user-provided.
//
// Returns:
// A list of [meta, fastqs] tuples, one per run, with lane/flowcell assigned.
//
def validateInputSamplesheet(id, metas, fastqs) {
    def fastqs_per_sample_ok = fastqs.collect { fq -> fq.size() }.unique().size == 1
    if (!fastqs_per_sample_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must have the same number of FASTQs: ${id}")
    }
    def read_structures_ok = metas.collect { m -> m.read_structure }.unique().size == 1
    if (!read_structures_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must have the same read structure: ${id}")
    }
    def umi_files_ok = metas.collect { m -> m.umi_file }.unique().size == 1
    if (!umi_files_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must have the same umi_file: ${metas[0].id}")
    }

    // Collect per-row lane and flowcell values
    def lanes = metas.collect { m -> m.lane }
    def flowcells = metas.collect { m -> m.flowcell }

    // All-or-nothing for lane
    def provided_lanes = lanes.findAll { v -> v != null }
    if (provided_lanes.size() > 0 && provided_lanes.size() != lanes.size()) {
        error("Please check input samplesheet -> if lane is provided for any run, it must be provided for all runs: ${id}")
    }

    // All-or-nothing for flowcell
    def provided_flowcells = flowcells.findAll { v -> v != null }
    if (provided_flowcells.size() > 0 && provided_flowcells.size() != flowcells.size()) {
        error("Please check input samplesheet -> if flowcell is provided for any run, it must be provided for all runs: ${id}")
    }

    // Validate uniqueness of (flowcell, lane) pairs (only when user-provided)
    if (provided_lanes.size() > 0) {
        def fc_lane_pairs = [flowcells, lanes].transpose()
        if (fc_lane_pairs.size() != fc_lane_pairs.unique(false).size()) {
            error("Please check input samplesheet -> (flowcell, lane) pairs must be unique within a sample: ${id}")
        }
    }

    // Build shared meta from first row + n_samples count
    def shared_meta = metas[0] + [n_samples: metas.size()]

    // Expand back to per-run items with assigned lane/flowcell
    return fastqs.withIndex().collect { fq, index ->
        def lane = lanes[index] != null ? lanes[index] : (index + 1)
        def flowcell = flowcells[index]  // may be null
        def run_meta = shared_meta + [lane: lane, flowcell: flowcell]
        return [run_meta, fq]
    }
}

//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[params.genome].containsKey(attribute)) {
            return params.genomes[params.genome][attribute]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" + "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" + "  Currently, the available genome keys are:\n" + "  ${params.genomes.keySet().join(", ")}\n" + "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
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
        ".",
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
        "<li>Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R; 1000 Genome Project Data Processing Subgroup. The Sequence Alignment/Map format and SAMtools. Bioinformatics. 2009 Aug 15;25(16):2078-9. doi: 10.1093/bioinformatics/btp352. Epub 2009 Jun 8. PubMed PMID: 19505943; PubMed Central PMCID: PMC2723002.</li>",
    ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    }
    else {
        meta["doi_text"] = ""
    }
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()

    def methods_text = mqc_methods_yaml.text

    def engine = new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
