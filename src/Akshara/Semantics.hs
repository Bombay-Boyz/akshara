-- | §76: the trusted, intentionally simple finite oracle. §18's
-- denotational equations as a concrete list.
module Akshara.Semantics
  ( denote
  ) where

import Akshara.Syntax (AksharaExpr (..))

-- | ⟦e⟧: Empty ↦ ∅, Pure x ↦ {x}, Sum ↦ Left⟦A⟧∪Right⟦B⟧,
-- Product ↦ ⟦A⟧×⟦B⟧. Total: structural recursion on a finite closed
-- term; no Host-Mode value ever reaches here (§17).
denote :: AksharaExpr a -> [a]
denote Empty         = []
denote (Pure x)      = [x]
denote (Sum l r)     = map Left (denote l) ++ map Right (denote r)
denote (Product l r) = [(x, y) | x <- denote l, y <- denote r]
