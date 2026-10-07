# ADR 0001: parallelFindCanonical is bottlenecked on partition, not search

Status: open, deliberately unfixed (Section 5.9)

## Finding (Stage 15, criterion)
Worker scaling 1->8 on parallelFindCanonical is monotonically SLOWER
(16.5ms -> 20ms), not faster. Root cause: it calls Akshara.Partition.partition
once per invocation; partition's own cost (14-17ms, confirmed by direct
benchmark) dominates the actual search work on the benchmarked domain
(cardinality 3^10). More workers can't help because the bottleneck isn't
the thing being parallelized.

## Attempted fix, reverted
Rewrote partition's two enumerate calls into one `let`-bound call.
Benchmark showed this made partition AND parallelFindCanonical slower,
reproducibly (variance <1% on re-run). Reverted. No confirmed mechanism
for why GHC's handling of the original form outperforms the explicit
let -- stated as open, not papered over.

## Real fix, not attempted
Partition/Parallel's structure is: materialise full enumeration once,
then slice. A lazy per-region enumeration (hand each worker a range to
enumerate independently, never materialising the full list) would
remove the bottleneck but is a real redesign of Akshara.Partition and
Runtime.Parallel's interaction -- deferred to a dedicated hardening pass,
not attempted under Stage 15's time/review budget after one miss already
this stage (Section 5.8: don't compound an unverified change with another).

## What ships as-is
Akshara.Partition reverted to its original two-call form (faster,
confirmed). parallelFindCanonical ships with this known scaling
limitation on the record.
