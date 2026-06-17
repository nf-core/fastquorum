# nf-core/fastquorum: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Credits

### Enhancements & fixes

## [[2.0.0]](https://github.com/nf-core/fastquorum/releases/tag/2.0.0) -- 2026-06-16

### Credits

Special thanks to the following for their contributions to the release:

- [Charlotte Tolonen](https://github.com/cehtolonen)
- [Clint Valentine](https://github.com/clintval)
- [Nils Homer](https://github.com/nh13)
- [Simon Pearce](https://github.com/SPPearce)
- [Zach Norgaard](https://github.com/znorgaard)

### Enhancements & fixes

- [PR #123](https://github.com/nf-core/fastquorum/pull/123) - Validate read structures with the nf-fgbio plugin
- [PR #128](https://github.com/nf-core/fastquorum/pull/128) - Add icon image
- [PR #131](https://github.com/nf-core/fastquorum/pull/131) - Update to nf-core/tools template version 3.3.2
- [PR #138](https://github.com/nf-core/fastquorum/pull/138) - Ensure the PDF from CollectDuplexSeqMetrics is published
- [PR #141](https://github.com/nf-core/fastquorum/pull/141) - Fix Twist UMI docs from random to nonrandom
- [PR #142](https://github.com/nf-core/fastquorum/pull/142) - Update to nf-core/tools template version 3.5.2 with Nextflow strict syntax
- [PR #145](https://github.com/nf-core/fastquorum/pull/145) - Add non-random UMI correction via fgbio CorrectUmis, enabled by an optional `umi_file` column in the samplesheet
- [PR #147](https://github.com/nf-core/fastquorum/pull/147) - Add optional `library_id`, `lane`, and `flowcell` samplesheet columns and fix silent pre-merge output overwrites across lanes ([#146](https://github.com/nf-core/fastquorum/issues/146))
- [PR #150](https://github.com/nf-core/fastquorum/pull/150) - Update to nf-core/tools template version 4.0.2 (raise minimum Nextflow to 25.10.4; remove webhook notifications; move `CONTRIBUTING.md` to `docs/`; switch git hooks to `prek`)
- [PR #151](https://github.com/nf-core/fastquorum/pull/151) - Update nf-core modules (bwa, fastqc, multiqc, samtools) and remove the `name` field from module `environment.yml` files so the local patches are no longer needed
- [PR #152](https://github.com/nf-core/fastquorum/pull/152) - Add `environment.yml`, `meta.yml`, and container configs to local modules and recognize the `apptainer` container engine

## [[1.2.0]](https://github.com/nf-core/fastquorum/releases/tag/1.2.0) -- 2025-04-11

### Credits

Special thanks to the following for their contributions to the release:

- [Nils Homer](https://github.com/nh13)
- [Simon Pearce](https://github.com/SPPearce)
- [Zach Norgaard](https://github.com/znorgaard)

### Enhancements & fixes

- [PR #119](https://github.com/nf-core/fastquorum/pull/119) - Fix the [download pipeline action](https://github.com/nf-core/fastquorum/actions/workflows/download_pipeline.yml)
- [PR #116](https://github.com/nf-core/fastquorum/pull/116) - Format nextflow files using [nextflow format command](https://github.com/nextflow-io/nextflow/pull/5908)
- [PR #111](https://github.com/nf-core/fastquorum/pull/111) - Remove duplicated `defaultIgnoreParams` and ensure nf-tests run automatically
- [PR #110](https://github.com/nf-core/fastquorum/pull/110) - Remove the temporary use of fgbio/sortbam which was implemented in [PR #68](https://github.com/nf-core/fastquorum/pull/68) to work around a bug in `samtools merge` [samtools#2062](https://github.com/samtools/samtools/pull/2062), as this is now fixed in `samtools v1.21`
- [PR #109](https://github.com/nf-core/fastquorum/pull/109) - Fix language server warnings
- [PR #108](https://github.com/nf-core/fastquorum/pull/108) - Update to nf-core/tools template version 3.2.0
- [PR #104](https://github.com/nf-core/fastquorum/pull/104) - Update to nf-core/tools template version 3.1.1

## [[1.1.0]](https://github.com/nf-core/fastquorum/releases/tag/1.1.0) -- 2024-12-02

### Credits

Special thanks to the following for their contributions to the release:

- [Simon Pearce](https://github.com/SPPearce)
- [Zach Norgaard](https://github.com/znorgaard)

### Enhancements & fixes

- [PR #98](https://github.com/nf-core/fastquorum/pull/98) - Update nf-core modules/subworkflows to most recent versions
- [PR #93](https://github.com/nf-core/fastquorum/pull/93) - Allow non-gzipped input fastq files
- [PR #90](https://github.com/nf-core/fastquorum/pull/90) - Update dependency versions in fastquorum environments
  | Dependency | Previous Version | New Version |
  | ---------- | ---------------- | ----------- |
  | bwa | 0.7.17 | 0.7.18 |
  | fgbio | 2.0.2 | 2.4.0 |
  | samtools | 1.16.1 | 1.21 |

  | Module         | Previous SHA | New SHA |
  | -------------- | ------------ | ------- |
  | bwa/index      | e0ff65e      | 6666521 |
  | fastqc         | b49b899      | 6666521 |
  | fgbio/sortbam  | 2fc7438      | bc6d86f |
  | multiqc        | fe9614c      | cf17ca4 |
  | samtools/dict  | 3c8fd07      | b13f07b |
  | samtools/faidx | 04fbbc7      | b13f07b |
  | samtools/merge | 04fbbc7      | b13f07b |

- [PR #87](https://github.com/nf-core/fastquorum/pull/87) - Raise minimum Nextflow version to 24.04.2
- [PR #84](https://github.com/nf-core/fastquorum/pull/84) - Update to nf-core/tools template version 3.0.2
- [PR #79](https://github.com/nf-core/fastquorum/pull/79) and [PR #80](https://github.com/nf-core/fastquorum/pull/80) - Publish aligned consensus bai file

## [[1.0.1]](https://github.com/nf-core/fastquorum/releases/tag/1.0.1) -- 2024-09-10

### Credits

Special thanks to the following for their contributions to the release:

- [Nils Homer](https://github.com/nh13)
- [Simon Pearce](https://github.com/SPPearce)
- [Zach Norgaard](https://github.com/znorgaard)

### Enhancements & fixes

- [PR #51](https://github.com/nf-core/fastquorum/pull/51) - Fixes a bug where alignment and filtering where swapped in the phase 2 high-throughput diagrams (@jfy133).
- [PR #58](https://github.com/nf-core/fastquorum/pull/58) - Prepare genome steps now run only if the corresponding parameters are not passed.
- [PR #60](https://github.com/nf-core/fastquorum/pull/60) - Enable automatic escalation of memory for FilterConsensusReads.
- [PR #67](https://github.com/nf-core/fastquorum/pull/67) - Fix setting the parameters from igenomes.
- [PR #68](https://github.com/nf-core/fastquorum/pull/68) - Temporary fix to merging BAMs across lanes in template-coordinate order. Using `fgbio SortBam` after `samtools merge`. Related to [samtools#2062](https://github.com/samtools/samtools/pull/2062).
- [PR #71](https://github.com/nf-core/fastquorum/pull/71) - Add stubs to all local modules.

## [[1.0.0]](https://github.com/nf-core/fastquorum/releases/tag/1.0.0) -- 2024-05-20

Initial release of nf-core/fastquorum, created with the [nf-core](https://nf-co.re/) template.

### Credits

Special thanks to the following for their contributions to the release:

- [Nils Homer](https://github.com/nh13)
- [Simon Pearce](https://github.com/SPPearce)
- [Brent Pedersen](https://github.com/brentp)
- [Adam Talbot](https://github.com/adamrtalbot)
- [James A. Fellows Yates](https://github.com/jfy133)

Thank you to everyone else that has contributed by reporting bugs, enhancements or in any other way, shape or form.

### Enhancements & fixes

- [PR #44](https://github.com/nf-core/fastquorum/pull/38) - Updated bwa index to version 0.7.18
- [PR #38](https://github.com/nf-core/fastquorum/pull/38) - Add support for samples to have multiple runs or lanes
- [PR #38](https://github.com/nf-core/fastquorum/pull/38) - Improved sample sheet validation
- [PR #38](https://github.com/nf-core/fastquorum/pull/38) - Support one to four FASTQs per sample (e.g. when the UMI is in the index read)
- [PR #38](https://github.com/nf-core/fastquorum/pull/38) - Report the versions for all tools
- [PR #36](https://github.com/nf-core/fastquorum/pull/36) - Added significant documentation, along with `publishDir` module config
- [PR #33](https://github.com/nf-core/fastquorum/pull/33) - Add high-throughout mode (via `--mode ht`), with R&D mode via `--mode rd` being the default.
- [PR #30](https://github.com/nf-core/fastquorum/pull/30) - Update to nf-core template v2.14.1
- [PR #30](https://github.com/nf-core/fastquorum/pull/30) - Add tests using [nf-core/test-datasets PR #1200](https://github.com/nf-core/test-datasets/pull/1200)
- [PR #30](https://github.com/nf-core/fastquorum/pull/30) - Params `enable_conda` was removed
- [PR #14](https://github.com/nf-core/fastquorum/pull/14) - Add mulled container for docker/singularity
- [PR #32](https://github.com/nf-core/fastquorum/pull/32) - Remove duplicate line in README
- [PR #18](https://github.com/nf-core/fastquorum/pull/18) - Fix pipeline when `strategy` is not 'Paired'
- [PR #7](https://github.com/nf-core/fastquorum/pull/7) - Add missing samtools conda requirement
- [PR #8](https://github.com/nf-core/fastquorum/pull/8) - Make it work locally
