# nf-core/fastquorum: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0dev - [date]

Initial release of nf-core/fastquorum, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [PR #36](https://github.com/nf-core/fastquorum/pull/36) - Added significant documentation, along with `publishDir` module config
- [PR #33](https://github.com/nf-core/fastquorum/pull/33) - Add high-throughout mode (via `--mode ht`), with R&D mode via `--mode rd` being the default.
- [PR #30](https://github.com/nf-core/fastquorum/pull/30) - Update to nf-core template v2.14.1
- [PR #30](https://github.com/nf-core/fastquorum/pull/30) - Add tests using [nf-core/test-datasets PR #1200](https://github.com/nf-core/test-datasets/pull/1200)
- [PR #14](https://github.com/nf-core/fastquorum/pull/14) - Add mulled container for docker/singularity

### `Fixed`

- [PR #32](https://github.com/nf-core/fastquorum/pull/32) - Remove duplicate line in README
- [PR #18](https://github.com/nf-core/fastquorum/pull/18) - Fix pipeline when `strategy` is not 'Paired'
- [PR #7](https://github.com/nf-core/fastquorum/pull/7) - Add missing samtools conda requirement
- [PR #8](https://github.com/nf-core/fastquorum/pull/8) - Make it work locally

### `Dependencies`

### `Deprecated`

### `Removed`

- [PR #30](https://github.com/nf-core/fastquorum/pull/30) - Params `enable_conda` was removed
