{- | Sections 44-45: the planner, Stage 8. AksharaExpr /= AksharaPlan
(Section 45's boxed equation) -- a plan is not a search expression,
it is an executable interpretation of one, carrying the analysis
Section 8's architecture says the Planner is fed.

Section 29 is explicit that Domain, Predicate, Order and execution
policy must never be merged into one datatype -- so 'AksharaPlan'
deliberately holds only the domain and its derived structural
facts, never the predicate or order a solver is given separately.

/Deliberate scope limit (Section 5.9 ADR)/: no partition strategy,
worker count, checkpoint strategy, or verifier-placement field
(Section 44's list) -- each becomes real only once its stage (9,
10, 11, 12) gives it actual behaviour to carry. Section 91's full
engine boundary (Plan + Verifier + ExecutionPolicy -> Result) is
the eventual target, not built here: neither Verifier nor
ExecutionPolicy exists yet, so 'Akshara.Solver' still consumes
'AksharaExpr' directly rather than 'AksharaPlan'.
-}
module Akshara.Plan (
  AksharaPlan,
  planDomain,
  planCardinality,
  planDepth,
  derivePlan,
) where

import Akshara.Analysis.Cardinality (Cardinality, analyzeCardinality)
import Akshara.Analysis.Depth (Depth, analyzeDepth)
import Akshara.Syntax (AksharaExpr)

{- | Opaque: the only way to obtain one is 'derivePlan', so the
cardinality/depth fields are guaranteed to actually describe
'planDomain' -- never independently supplied and possibly stale
(Section 1.3's construction-time invariant, applied to derived
data rather than externally-validated input). The constructor is
intentionally not exported; the three fields below are, as plain
getters that can't be used to reconstruct a mismatched plan.
-}
data AksharaPlan a = AksharaPlan
  { planDomain :: AksharaExpr a
  , planCardinality :: Cardinality
  , planDepth :: Depth
  }

{- | Section 44: Specification -> ExecutionPlan. Runs Stage 7's
analyses once and bundles the result with the domain unaltered --
Section 44's closing requirement ("the plan must not alter the
mathematical meaning") holds by construction, since 'planDomain'
is exactly the expression passed in, not a copy or a rewrite.
-}
derivePlan :: AksharaExpr a -> AksharaPlan a
derivePlan e =
  AksharaPlan
    { planDomain = e
    , planCardinality = analyzeCardinality e
    , planDepth = analyzeDepth e
    }
