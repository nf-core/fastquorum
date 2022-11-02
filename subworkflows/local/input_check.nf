//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channel(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id             = row.sample
    meta.read_structure = row.read_structure

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (!file(row.fastq_2).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
    }
    if (row.fastq_umi){
        if (!file(row.fastq_umi).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> UMI FastQ file is specified in samplesheet does not exist!\n${row.fastq_2}"
        }
        fastq_list = [ file(row.fastq_1), file(row.fastq_2), file(row.fastq_umi) ]
    } else {
        fastq_list = [ file(row.fastq_1), file(row.fastq_2) ]
    }
    fastq_meta = [ meta, fastq_list ]
    return fastq_meta
}
