-- | Section 2.4: the nesting depth of Sum/Product layers -- the
-- quantity a future explicit resource bound on recursive structures
-- is checked against. Same opacity reasoning as 'Cardinality': always
-- nonnegative by construction, no smart constructor needed.
module Akshara.Analysis.Depth
  ( Depth
  , unDepth
  , analyzeDepth
  ) where

import Akshara.Syntax (AksharaExpr (..))

newtype Depth = Depth Int deriving (Eq, Ord, Show)

unDepth :: Depth -> Int
unDepth (Depth n) = n

-- | 0 at every leaf; +1 per Sum/Product layer; unchanged by MapT (no
-- new layer of nesting introduced). Total: structural recursion.
analyzeDepth :: AksharaExpr a -> Depth
analyzeDepth Empty         = Depth 0
analyzeDepth (Pure _)      = Depth 0
analyzeDepth (Sum l r)     =
  Depth (1 + max (unDepth (analyzeDepth l)) (unDepth (analyzeDepth r)))
analyzeDepth (Product l r) =
  Depth (1 + max (unDepth (analyzeDepth l)) (unDepth (analyzeDepth r)))
analyzeDepth (MapT _ e)    = analyzeDepth e
