# nf-core/fastquorum: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [[1.0.1]](https://github.com/nf-core/fastquorum/releases/tag/1.0.1) -- 2024-09-04

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
- [PR #72](https://github.com/nf-core/fastquorum/pull/72) - Fix image in README

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
