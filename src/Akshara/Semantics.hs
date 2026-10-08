{- | §76: the trusted finite oracle. §18's equations, plus 'MapT's
(⟦MapT T e⟧ = ⟦T⟧ applied pointwise to ⟦e⟧).
-}
module Akshara.Semantics (
  denote,
) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (applyT)

denote :: AksharaExpr a -> [a]
denote Empty = []
denote (Pure x) = [x]
denote (Sum l r) = map Left (denote l) ++ map Right (denote r)
denote (Product l r) = [(x, y) | x <- denote l, y <- denote r]
denote (MapT t e) = map (applyT t) (denote e)
