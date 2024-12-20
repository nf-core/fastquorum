# nf-core/fastquorum: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/fastquorum/usage](https://nf-co.re/fastquorum/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Pipeline parameters

Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration except for parameters; see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis. Below is an example for the same sample sequenced across 3 lanes:

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2,read_structure
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,5M2S+T 5M2S+T
CONTROL_REP1,AEG588A1_S1_L003_R1_001.fastq.gz,AEG588A1_S1_L003_R2_001.fastq.gz,5M2S+T 5M2S+T
CONTROL_REP1,AEG588A1_S1_L004_R1_001.fastq.gz,AEG588A1_S1_L004_R2_001.fastq.gz,5M2S+T 5M2S+T
```

The `read_structure` must be the same for all FASTQs from the same sample.
Please see the [fgbio documentation](https://github.com/fulcrumgenomics/fgbio/wiki/Read-Structures) for detailed information on read structure syntax and formatting.

The number of FASTQs must match the number of _read segments_ in the read structure (a read structure is a space delimited string where each value is a _read segment_; see: https://github.com/fulcrumgenomics/fgbio/wiki/Read-Structures).
E.g. for paired end reads, there must be two FASTQs (R1 and R2) and two segments in the read structure (e.g. a read structure "12M+T +T" specifies a read segment "12M+T" for R1 and read segment "+T" for R2)
Additional FASTQs may be provided, for example for index reads (see [One to Four FASTQs](#one-to-four-fastqs) below).

### One to Four FASTQs

The pipeline supports samples that can have between one and four FASTQs (per sample).

It is common for the index reads (the reads that contain the sample barcodes for sample demultiplexing) to be omitted, when they do not contain any UMI or other important sequence (beyond the sample barcode).
In this case, only read one (for single-end), or both read one and read two (for paired-end), are usually provided.
Additional FASTQs can be provided in the cases where the UMI is present in the index read(s) themselves.

The sample sheet below shows four samples, each with a different number of FASTQs:

1. CONTROL1 is a single-end run, with one FASTQ (R1), and the UMI inline at the start of the read
2. CONTROL2 is a paired-end run, with two FASTQs (R1 and R2), and UMIs inline at the start of read one (R1) and read two (R2).
3. CONTROL3 is a single-indexed paired-end run, with three FASTQs, UMIs inline at the start of read one (R1) and read two, and a sample barcode in I1 (typically index1/i7)
4. CONTROL3 is a dual-indexed paired-end run, with four FASTQs, read one (R1) and (R2) containing template bases, with a sample barcode in I1 (typically index1/i7), and the UMI in I2 ((typically index2/i5)

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2,read_structure
CONTROL1,SAMPLE_S1_L001_R1_001.fastq.gz,5M2S+T
CONTROL2,SAMPLE_S1_L001_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,5M2S+T 5M2S+T
CONTROL3,SAMPLE_S1_L001_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,AEG588A1_S1_L002_I1_001.fastq.gz,5M2S+T 5M2S+T 8B
CONTROL4,SAMPLE_S1_L001_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,AEG588A1_S1_L002_I1_001.fastq.gz,AEG588A1_S1_L002_I22_001.fastq.gz,+T +T +B +M
```

### Full samplesheet

The pipeline will auto-detect whether a sample is single- or paired-end using the information provided in the samplesheet. The samplesheet can have as many columns as you desire, however, there is a strict requirement for the first four columns to match those defined in the table below.

A final samplesheet file consisting of both single- and paired-end data may look something like the one below. This is for 6 samples, where `TREATMENT_REP3` has been sequenced twice.

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2,read_structure
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,5M2S+T 5M2S+T
CONTROL_REP2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz,5M2S+T 5M2S+T
CONTROL_REP3,AEG588A3_S3_L002_R1_001.fastq.gz,AEG588A3_S3_L002_R2_001.fastq.gz,5M2S+T 5M2S+T
TREATMENT_REP1,AEG588A4_S4_L003_R1_001.fastq.gz,12M+T +T
TREATMENT_REP2,AEG588A5_S5_L003_R1_001.fastq.gz,12M+T +T
TREATMENT_REP3,AEG588A6_S6_L003_R1_001.fastq.gz,12M+T +T
TREATMENT_REP3,AEG588A6_S6_L004_R1_001.fastq.gz,12M+T +T
```

| Column           | Description                                                                                                                                                                            |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`         | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1`        | Full path to FastQ file for Illumina short reads 1. File has to have the extension ".fastq", ".fq", ".fastq.gz" or ".fq.gz".                                                           |
| `fastq_2`        | Full path to FastQ file for Illumina short reads 2. File has to have the extension ".fastq", ".fq", ".fastq.gz" or ".fq.gz".                                                           |
| `fastq_3`        | Full path to FastQ file for Illumina short reads 3 (e.g. index1/i7). File has to have the extension ".fastq", ".fq", ".fastq.gz" or ".fq.gz".                                          |
| `fastq_4`        | Full path to FastQ file for Illumina short reads 4 (e.g. index2/i5). File has to have the extension ".fastq", ".fq", ".fastq.gz" or ".fq.gz".                                          |
| `read_structure` | the [`read_structure`][read-structure-link] describes how the bases in a sequencing run should be allocated into logical reads, including the unique molecular index(es)               |

[read-structure-link]: https://github.com/fulcrumgenomics/fgbio/wiki/Read-Structures

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

### Main Options

Two modes of running this pipeline are supported:

1. Research and Development (R&D): use `--mode rd` or `params.mode=rd`. This mode is desirable to be able to branch off from the pipeline and test e.g. multiple consensus calling or filtering parameters.
2. High Throughput (HT): use `--mode ht` or `params.mode=ht`. This mode is intended for high throughput production environments where performance and throughput take precedence over flexibility.

For [Duplex-Sequencing][duplex-seq-link], use `--duplex_seq true` or `params.duplex_seq=true`, indicating that reads from the same source molecule may observe either strand.
Otherwise, the pipeline will assume that reads from the same source molecule are from the same strand.
Practically speaking, the former will utilize the [`fgbio CallDuplexConsensusReads`][fgbio-call-duplex-link] tool, while the latter will utilize the [`fgbio CallMolecularConsensusReads`][fgbio-call-mol-link] tool.

[fgbio-call-duplex-link]: https://fulcrumgenomics.github.io/fgbio/tools/latest/CallDuplexConsensusReads.html
[fgbio-call-mol-link]: https://fulcrumgenomics.github.io/fgbio/tools/latest/CallMolecularConsensusReads.html
[duplex-seq-link]: https://en.wikipedia.org/wiki/Duplex_sequencing

### Grouping Options

These options pertain to the [`fgbio GroupReadsByUmi`](https://fulcrumgenomics.github.io/fgbio/tools/latest/GroupReadsByUmi.html) tool and are prefixed by `groupreadsbyumi_`.

The `--groupreadsbyumi_strategy` option overrides the tool's `--strategy` option.
By default, the `--strategy paired` is used when `--duplex_seq true`, otherwise `--strategy adjacency`.

:::warning The strategy used must match the library preparation (i.e. `Paired` for duplex-sequencing, otherwise one of `Identity`, `Edit`, or `Adjacency`).

The `groupreadsbyumi_edits` option overrides the tool's `--edits` option.
This provides the maximum number of allowable edits.

### Consensus Calling Options

These options pertain to the [`fgbio CallMolecularConsensusReads`][fgbio-call-mol-link] and [`CallDuplexConsensusReads`][fgbio-call-duplex-link] tools and are prefixed by `call_`.
The former tool processes reads from the same strand of the original source molecule, whereas the latter processes reads that originate from either strand of the original source molecule.

The `--call_min_reads` option provides the minimum read count to call a consensus, while the `--call_min_baseq` option provides the minimum input base quality to use when calling a consensus.
These two options are typically used for the High Throughput mode, matching the same value used in [Consensus Filtering](#consensus-filtering-options).

### Consensus Filtering Options

These options pertain to the [`fgbio FilterConsensusReads`](https://fulcrumgenomics.github.io/fgbio/tools/latest/FilterConsensusReads.html) tool and are prefixed by `filter_`.

The `--filter_min_reads` option provides the minimum read count to call a consensus, while the option `--filter_min_baseq` provides the minimum input base quality to use when calling a consensus.
These two options are typically used for the High Throughput mode, matching the same value used in [Consensus Calling](#consensus-calling-options).
The `--filter_min_reads` option can accept up to three values for [duplex consensus reads][duplex-seq-link].
See the tools documentation for how to use this option.

The `--filter_max_base_error_rate` option sets the maximum error rate for a single consensus base when filtering a consensus.

### Reference Genome Options

Please refer to the [nf-core website](https://nf-co.re/usage/reference_genomes) for general usage docs and guidelines regarding reference genomes.

### Explicit reference file specification (recommended)

The minimum reference genome requirement for this pipeline is a FASTA. All other files required to run the pipeline can be generated from the input FASTA.
For example, the latest reference FASTA for human can be derived from Ensembl like:

```
latest_release=$(curl -s 'http://rest.ensembl.org/info/software?content-type=application/json' | grep -o '"release":[0-9]*' | cut -d: -f2)
wget -L ftp://ftp.ensembl.org/pub/release-${latest_release}/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz
gunzip Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz
```

This FASTA can then be specified to the workflow with the `--fasta` parameter.

#### Indices

By default, BWA indices are generated dynamically by the workflow.
Since indexing is an expensive process in time and resources you should ensure that it is only done once, by retaining the indices generated from each batch of reference files:

- the `--save_reference` parameter will save your indices in your results directory

Once you have the indices from a workflow run you should save them somewhere central and reuse them in subsequent runs using custom config files or command line parameters:

- the `--fasta` parameter specifies the path to the genome FASTA
- the `--dict` parameter specifies the path to the genome sequence dictionary (see `samtools dict`)
- the `--fasta_fai` parameter specifies the path to the genome FASTA index (see `samtools faidx`)
- the `--bwa` parameter specifies the path to the directory containing the BWA index

### iGenomes (not recommended)

If the `--genome` parameter is provided (e.g. `--genome GRCh38`) then the FASTA file will be automatically obtained from AWS-iGenomes unless these have already been downloaded locally in the path specified by `--igenomes_base`.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/fastquorum --input ./samplesheet.csv --outdir ./results --genome GRCh38 -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, E.g. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/fastquorum -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh38'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/fastquorum
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/fastquorum releases page](https://github.com/nf-core/fastquorum/releases) and find the latest pipeline version - numeric only (E.g. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - E.g. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline step for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
