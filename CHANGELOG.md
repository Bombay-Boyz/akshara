# Changelog

## 0.1.0.0 - unreleased

- Initial kernel through Stage 15 (Sections 0-15, Akshara.md): typed
  search calculus, finite enumeration/analysis/planning/partitioning,
  parallel runtime, checkpoint/resume, two verifier adapters
  (SaltedSha256, FileContent), CLI (validate/analyze/plan/run).
- Known limitation: Runtime.parallelFindCanonical's worker scaling is
  bottlenecked on Akshara.Partition's eager materialisation (see
  docs/adr/0001-parallel-partition-bottleneck.md).
