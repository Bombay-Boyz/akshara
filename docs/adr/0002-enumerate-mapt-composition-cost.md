# ADR 0002: enumerate has a residual superlinear cost in MapT nesting depth

Status: accepted, not fixed further

## Finding
Stage-15-hardening fixed a confirmed O(depth^2) cost in enumerate's
Sum case (repeated (++) on a right-nested chain; see commit fixing
Akshara.Enumeration to a CPS/difference-list form). That fix gave an
~18x improvement at depth 40,000 (124s -> 6.7s net). A residual
superlinear cost remains, consistent with MapT's continuation
(`cons . applyT t`) composing once per nesting level: measured net
cost at depth 5k/10k/20k/40k scales ~2.7x/4.6x/5.4x per doubling,
not the ~2x a linear cost would show.

## Why not fixed further
Akshara.Domain.replicateE/sequenceRange -- the only call sites in
this codebase that build deep MapT/Sum/Product chains -- bound their
nesting depth by the requested sequence length, not alphabet size.
A realistic search specification (length ranges in the tens, not
tens of thousands) never reaches the depth regime where this curve
diverges from linear. Chasing a third fix on Akshara.Enumeration in
the same session as two reverted attempts on Akshara.Partition
(ADR 0001) was judged not worth the risk of a third unverified change
(Section 5.8) for a cost with no reachable caller at realistic scale.

## If this needs revisiting
Triggered by: a future Domain constructor whose nesting depth is NOT
bounded by sequence length (e.g. a large fixed alphabet built as a
deep unbalanced Sum rather than a shallow balanced one), or Stage 5's
still-deferred infinite/mu-X enumeration, which has no depth bound at
all by construction. Either would need enumerate's MapT case
revisited -- likely applying the Transform directly to each produced
element rather than composing it into the continuation.
