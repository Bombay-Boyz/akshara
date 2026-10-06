-- | Section 42: cardinality, computed structurally (no enumeration)
-- rather than by counting an enumerate'd list -- that's the actual
-- value Analysis adds over Enumeration.
--
-- /Deliberate scope limit (Section 5.9 ADR)/: only 'Exactly' exists.
-- 'map' preserves list length for any total function, so every
-- 'MapT' in the current kernel is exactly cardinality-preserving --
-- there is no live path to AtLeast/AtMost/Unknown until Host Mode
-- (Section 10) or an infinite construct (Section 67) exists. Adding
-- those constructors now, with nothing that could ever produce them,
-- would be the same dead-branch mistake Stage 6 avoided with
-- 'Inconclusive'/'Failed'.
module Akshara.Analysis.Cardinality
  ( Cardinality
  , unExactly
  , analyzeCardinality
  ) where

import Akshara.Syntax (AksharaExpr (..))

-- | Opaque, unlike 'Akshara.Domain.Length': nothing here takes
-- arbitrary external input needing validation (Section 3.3's
-- motivation for a smart constructor). The only producer is
-- 'analyzeCardinality', which is nonnegative by construction --
-- structural induction, not a runtime check.
newtype Cardinality = Exactly Int deriving (Eq, Ord, Show)

unExactly :: Cardinality -> Int
unExactly (Exactly n) = n

-- | Empty |-> 0; Pure |-> 1; Sum/Product add/multiply (Section 27);
-- MapT preserves (the fact argued above). Total: structural
-- recursion, no enumeration performed.
analyzeCardinality :: AksharaExpr a -> Cardinality
analyzeCardinality Empty         = Exactly 0
analyzeCardinality (Pure _)      = Exactly 1
analyzeCardinality (Sum l r)     =
  Exactly (unExactly (analyzeCardinality l) + unExactly (analyzeCardinality r))
analyzeCardinality (Product l r) =
  Exactly (unExactly (analyzeCardinality l) * unExactly (analyzeCardinality r))
analyzeCardinality (MapT _ e)    = analyzeCardinality e
