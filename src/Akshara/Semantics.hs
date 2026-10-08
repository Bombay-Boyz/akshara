-- | Section 76: the trusted, intentionally simple finite oracle.
-- Section 18's denotational equations as a concrete list.
module Akshara.Semantics
  ( denote
  ) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (applyT)

-- | ⟦e⟧: Empty ↦ ∅, Pure x ↦ {x}, Sum ↦ Left⟦A⟧∪Right⟦B⟧,
-- Product ↦ ⟦A⟧×⟦B⟧, MapT T e ↦ ⟦T⟧ applied pointwise to ⟦e⟧. Total:
-- structural recursion on a finite closed term; no Host-Mode value
-- ever reaches here (Section 17).
denote :: AksharaExpr a -> [a]
denote Empty         = []
denote (Pure x)      = [x]
denote (Sum l r)     = map Left (denote l) ++ map Right (denote r)
denote (Product l r) = [(x, y) | x <- denote l, y <- denote r]
denote (MapT t e)    = map (applyT t) (denote e)
