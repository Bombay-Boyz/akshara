-- | Section 42: cardinality, computed structurally (no enumeration)
-- rather than by counting an enumerate'd list.
--
-- /Deliberate scope limit (Section 5.9 ADR)/: only 'Exactly' exists --
-- every constructor in the current kernel is exactly
-- cardinality-preserving or -combining, so there is no live path to
-- AtLeast/AtMost/Unknown yet.
module Akshara.Analysis.Cardinality
  ( Cardinality
  , unExactly
  , analyzeCardinality
  ) where

import Akshara.Syntax (AksharaExpr (..))

-- | Opaque: the only producer is 'analyzeCardinality', nonnegative by
-- structural induction rather than a runtime check.
newtype Cardinality = Exactly Int deriving (Eq, Ord, Show)

-- | Extract the underlying count.
unExactly :: Cardinality -> Int
unExactly (Exactly n) = n

-- | Empty ↦ 0; Pure ↦ 1; Sum/Product add/multiply (Section 27);
-- MapT preserves. Total: structural recursion, no enumeration
-- performed -- O(expression size), not O(cardinality).
analyzeCardinality :: AksharaExpr a -> Cardinality
analyzeCardinality Empty         = Exactly 0
analyzeCardinality (Pure _)      = Exactly 1
analyzeCardinality (Sum l r)     =
  Exactly (unExactly (analyzeCardinality l) + unExactly (analyzeCardinality r))
analyzeCardinality (Product l r) =
  Exactly (unExactly (analyzeCardinality l) * unExactly (analyzeCardinality r))
analyzeCardinality (MapT _ e)    = analyzeCardinality e
