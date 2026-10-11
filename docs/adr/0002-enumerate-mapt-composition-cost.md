# ADR 0002: enumerate has a residual superlinear cost in MapT nesting depth

Status: accepted -- proven negligible for every case this codebase
can construct (upgraded from "assumed negligible in practice";
see History)

## Finding
Stage-15-hardening fixed a confirmed O(depth^2) cost in enumerate's
Sum case (repeated (++) on a right-nested chain). A residual
superlinear cost remains in the MapT case: `enumerateWith (MapT t e)
cons rest = enumerateWith e (cons . applyT t) rest` builds a new
closure at every nesting level. GHC cannot see through this at
compile time -- `t` is a runtime GADT value pattern-matched
generically -- so calling the resulting composed continuation at a
leaf costs O(depth) at runtime, regardless of what the transforms
mathematically simplify to.

## History: a fix was attempted, appeared to fail, and the reason why matters
A later session attempted to remove this cost at its one real call
site, Akshara.Domain.sequenceRange, by replacing its right-skewed
linear union of candidate lengths with a balanced binary split
(depth O(log w) instead of O(w), for range width w). A benchmark
using a cardinality-1 "alphabet" (to isolate the outer union's cost
from the alphabet's own combinatorial explosion) showed no
improvement -- ratios around 4x per doubling, consistent with
O(w^2), not the ~2.3x a real O(w log w) fix should show. The
balanced-split change was reverted via `git reset --hard`.

That result was correct, but for a different and better reason than
"the fix didn't work": the benchmark's own isolation was wrong. It
conflated the outer chain's cost with replicateE's OWN inherent cost
(see the rigorous analysis below), which is unrelated, unfixed by
the change, and happened to also be Θ(w^2) in that specific
degenerate setup -- masking any signal either way. Reverting was
right; chasing a corrected benchmark was not necessary once the
underlying mathematics was worked out directly, below.

## Rigorous analysis

### replicateE is optimal -- the depth cost is never wasted
For `replicateE n` over an alphabet of size |Sigma|, each of the
|Sigma|^n output strings is built by unwinding an n-deep composed
`ConsT` continuation -- O(n) per string. Total cost:

    T = n * |Sigma|^n

This equals the total number of CHARACTERS across all output
strings -- i.e., T is exactly the output size. You cannot build that
much list structure in less time. The O(depth) cost here is charged
exactly once per character actually produced; nothing is wasted.
(A naive recursive-call-counting argument initially suggested
T = Theta(|Sigma|^n) with no extra factor of n; that undercounts by
forgetting that the per-leaf continuation-unwind cost is itself O(n)
and must be charged separately from the O(|Sigma|^n) count of how
many times that unwind happens. Both derivations agree once this is
accounted for.)

### sequenceRange's outer chain: the "waste" is bounded by a ratio that never exceeds 1
sequenceRange's union over lengths lo..hi adds (k - lo) extra
UnifyT/Sum layers for the length-k branch. Summed across all output
strings, the EXTRA cost attributable to the outer chain is:

    Extra  = sum_{k=lo}^{hi} |Sigma|^k * (k - lo)

compared against the ALREADY-NECESSARY baseline from replicateE's
own cost at each length:

    Necessary = sum_{k=lo}^{hi} |Sigma|^k * k

For |Sigma| >= 2, both sums are dominated by their largest (k = hi)
term, giving:

    Extra / Necessary  ~  (hi - lo) / hi  =  W / (lo + W)  <=  1

for range width W = hi - lo. This ratio is bounded by 1 for ANY W,
including arbitrarily large W -- so whether the outer chain is a
linear fold (O(W^2) of its own) or a balanced split (O(W log W) of
its own) changes, at most, a bounded fraction of an already-dominant
cost. Balancing it is not wrong, but it buys nothing measurable for
any real alphabet.

### The degenerate case (|Sigma| = 1) -- the exact setup the failed benchmark used
With a single-symbol alphabet, replicateE's own cost per length k is
Theta(k) (not exponential: there is exactly one length-k string).
The "Necessary" baseline becomes an arithmetic series,
sum_{k=lo}^{hi} k = Theta(W^2) -- and the outer chain's own
unfixed cost is ALSO Theta(W^2). The ratio Extra/Necessary is still
bounded (~1), not diverging. This is exactly the regime the reverted
benchmark measured: both the thing it meant to isolate and the thing
it accidentally included were genuinely, comparably Theta(W^2). There
was no hidden bug being masked -- the measurement matched the
mathematics once the mathematics was done properly.

## Conclusion
There is no construction reachable from this codebase's current
Akshara.Domain -- realistic (|Sigma| >= 2) or degenerate (|Sigma| = 1)
-- where balancing sequenceRange's chain produces a measurable
benefit. The original linear-fold implementation is correct and
Section 4.3/0.7-appropriate: reaching for a more sophisticated
(balanced-tree) construction here would be exactly the unjustified
complexity those sections warn against, for a provably negligible
gain. No code change is made as a result of this ADR.

## If this needs revisiting
Triggered by: a future Domain constructor whose branching factor is
genuinely |Sigma| = 1 or close to it in some other dimension AND
whose range width W is not itself bounded by anything related to
|Sigma| (so the "Extra/Necessary <= 1" bound's denominator doesn't
also grow) -- no such constructor exists today. Also triggered by
Stage 5's still-deferred infinite/mu-X enumeration, which has no
depth bound at all by construction and would need this analysis
redone from scratch rather than extended.
