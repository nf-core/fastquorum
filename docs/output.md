# nf-core/fastquorum: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarizes results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

1. [Preprocessing](#preprocessing)
   1. [FastQC](#fastqc) - Raw read QC
   2. [fgbio FastqToBam](#fgbio-fastqtobam) - Fastq to BAM, extracting UMIs
   3. [BWA](#bwa-raw-reads) - Align the raw reads
2. [Grouping](#grouping)
   1. [fgbio GroupReadsByUmi](#fgbio-groupreadsbyumi) - Group raw reads by UMI (to identify reads from the same source molecule)
3. [Consensus Reads](#consensus-calling)
   1. [fgbio CallDuplexConsensusReads](#fgbio-callduplexconsensusreads) - Call duplex consensus reads for [Duplex-Sequencing][duplex-seq-link] data
   2. [fgbio CallMolecularConsensusReads](#fgbio-callduplexconsensusreads) - Call single-strand consensus reads for non-Duplex-Sequencing data
   3. [BWA](#bwa-consensus-reads) - Align the consensus reads
4. [Consensus Filtering](#consensus-filtering)
   1. [fgbio FilterConsensusReads](#fgbio-filterconsensusreads) - Filter consensus reads
5. [Quality Control and Metrics](#quality-control-and-metrics)
   1. [fgbio CollectDuplexSeqMetrics]() - QC for [Duplex-Sequencing][duplex-seq-link] data
   2. [MultiQC](#multiqc) - Present raw read QC

Note: the High Throughput version of the pipeline performs consensus calling and consensus filtering in one step, with the alignment of consensus reads occuring after filtering.
This significantly speeds up the workflow by eliminating an intermediate file (pre-filtered consensus reads) and reducing the number of consensus reads that need to be aligned (usually a minor speedup).

[duplex-seq-link]: https://en.wikipedia.org/wiki/Duplex_sequencing

## Preprocessing

### FastQC

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/preprocessing/fastqc/<sample>`**

- `*_fastqc.html`: [FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) report containing quality metrics.
- `*_fastqc.zip`: Zip archive containing the [FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) report, tab-delimited data file and plot images.

</details>

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences. For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

<!-- TODO update with example plots -->

:::note
The FastQC plots displayed in the MultiQC report shows _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality.
:::

### fgbio FastqToBam

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/preprocessing/fastqtobam/<sample>`**

- '\*.unmapped.bam`
  - the unmapped BAM produced by [`fgbio FastqToBam`](http://fulcrumgenomics.github.io/fgbio/tools/latest/FastqToBam.html).
  - the `RX` [SAM tag](https://samtools.github.io/hts-specs/SAMtags.pdf) stores the raw bases for the reads unique molecular identifier (UMI)

</details>

### BWA (raw reads)

Aligns the raw reads to the genome, and then [template-coordinate](https://www.htslib.org/doc/samtools-sort.html) sorts the reads in preparation for grouping.

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/preprocessing/align_raw_bam/<sample>`**

- '\*.mapped.bam`
  - the mapped BAM produced by:
    - aligning with [`bwa mem`](https://github.com/lh3/bwa)
    - reformatted by [`fgbio ZipperBam`](http://fulcrumgenomics.github.io/fgbio/tools/latest/ZipperBam.html) (to transfer any [SAM tags](https://samtools.github.io/hts-specs/SAMtags.pdf) from the unmapped BAM to the mapped BAM, since this is not carried forward by BWA)
    - template-coordinate sorted by [`samtools sort`](http://www.htslib.org/doc/samtools.html)
  - the `RX` [SAM tag](https://samtools.github.io/hts-specs/SAMtags.pdf) stores the raw bases for the reads unique molecular identifier (UMI)

</details>

## Grouping

### fgbio GroupReadsByUmi

Groups the reads by their UMI, identifying reads that originate from the same source molecule.

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/grouping/groupreadsbyumi/<sample>`**

- '\*.mapped.bam`
  - the group BAM produced by [`fgbio GroupReadsByUmi`](http://fulcrumgenomics.github.io/fgbio/tools/latest/GroupReadsByUmi.html)
  - the `MI` [SAM tag](https://samtools.github.io/hts-specs/SAMtags.pdf) stores the molecular identifier for the read after grouping.
- '\*.grouped-family-sizes.txt'
  - the metric produced by [`fgbio GroupReadsByUmi`](http://fulcrumgenomics.github.io/fgbio/tools/latest/GroupReadsByUmi.html) that describes the distribution of tag family sizes observed during grouping ([see this link](https://fulcrumgenomics.github.io/fgbio/metrics/latest/#tagfamilysizemetric)).

</details>

## Consensus Calling

The output for both [`fgbio CallDuplexConsensusReads`](http://fulcrumgenomics.github.io/fgbio/tools/latest/CallDuplexConsensusReads.html) and [`fgbio CallMolecularConsensusReads`](http://fulcrumgenomics.github.io/fgbio/tools/latest/CallMolecularConsensusReads.html) consensus calling tools.

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/consensus_calling/called/<sample>`**

- '\*.cons.unmapped.bam`
  - the BAM with consensus calls
  - see [this description](https://github.com/fulcrumgenomics/fgbio/wiki/Developer-Note:-Tracking-Reads-through-Grouping-and-Duplex-Consensus-Calling#consensus-calling-tags) of [SAM tag](https://samtools.github.io/hts-specs/SAMtags.pdf) added to consensus reads.

</details>

### fgbio CallDuplexConsensusReads

Calls duplex consensus reads.

### fgbio CallMolecularConsensusReads

Calls single-strand consensus reads.

## Consensus Filtering

### fgbio FilterConsensusReads

Filters consensus reads.
Two kinds of filtering are performed:

1. Masking/filtering of individual bases in reads
2. Filtering out of reads (i.e. not writing them to the output file)

See [`fgbio FilterConsensusReads`](http://fulcrumgenomics.github.io/fgbio/tools/latest/FilterConsensusReads.html) for more details.

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/consensus_filtering/filtered/<sample>`**

- '\*.cons.filtered.bam`
  - the BAM with filtered consensus calls produced by [`fgbio FilterConsensusReads`](http://fulcrumgenomics.github.io/fgbio/tools/latest/FilterConsensusReads.html)

</details>

### BWA (consensus reads)

Aligns the consensus reads to the genome.

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/filtering/align_consensus_bam/<sample>`**

- '\*.mapped.bam`
  - the mapped BAM produced by:
    - aligning with [`bwa mem`](https://github.com/lh3/bwa)
    - reformatted by [`fgbio ZipperBam`](http://fulcrumgenomics.github.io/fgbio/tools/latest/ZipperBam.html) (to transfer any [SAM tags](https://samtools.github.io/hts-specs/SAMtags.pdf) from the unmapped BAM to the mapped BAM, since this is not carried forward by BWA)
- '\*.mapped.bam.bai`
  - the mapped BAM index (high-throughput mode only)

</details>

## Quality Control and Metrics

### fgbio CollectDuplexSeqMetrics

Collect duplex sequencing specific metrics.

<details markdown="1">
<summary>Output files</summary>

**Output directory: `{outdir}/metrics/duplex_seq/<sample>`**

Metrics produced by [`fgbio CollectDuplexSeqMetrics`](http://fulcrumgenomics.github.io/fgbio/tools/latest/CollectDuplexSeqMetrics.html):

- `*.family_sizes.txt*` - metrics on the frequency of different types of families of different sizes
- `*.duplex_family_sizes.txt*`- metrics on the frequency of duplex tag families by the number of observations from each strand
- `*.duplex_yield_metrics.txt*`- summary QC metrics produced using 5%, 10%, 15%...100% of the data
- `*.umi_counts.txt*`- metrics on the frequency of observations of UMIs within reads and tag families
- `*.duplex_qc.pdf*`- a series of plots generated from the preceding metrics files for visualization
- `*.duplex_umi_counts.txt*`- (optional) metrics on the frequency of observations of duplex UMIs within reads and tag families. This file is only produced _if_ the `--duplex-umi-counts` option is used as it requires significantly more memory to track all pairs of UMIs seen when a large number of UMI sequences are present.

</details>

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter is used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
