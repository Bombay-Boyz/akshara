-- | Layer B (§20): enumeration as an operational interpretation,
-- distinct from denotation (Akshara.Semantics) even though Stage 4
-- requires them to agree (§21 soundness, §22 completeness) on every
-- finite closed term. Kept as its own function, not an alias for
-- 'denote' — see the Stage 4 commit message / conversation for why
-- (0.6: denote must stay the untouched oracle per §141/§142;
-- enumerate will diverge from it starting Stage 5's §25 case split).
module Akshara.Enumeration
  ( enumerate
  ) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (applyT)

-- | Part 4.1 recursion scheme: structure-preserving fold over the
-- closed finite term. Total for the same reason 'denote' is.
enumerate :: AksharaExpr a -> [a]
enumerate Empty         = []
enumerate (Pure x)      = [x]
enumerate (Sum l r)     = map Left (enumerate l) ++ map Right (enumerate r)
enumerate (Product l r) = [(x, y) | x <- enumerate l, y <- enumerate r]
enumerate (MapT t e)    = map (applyT t) (enumerate e)
