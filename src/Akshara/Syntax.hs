{- | Layer A (Akshara.md §7): closed kernel syntax. §12's algebra plus
'MapT' (§13/§15) — the symbolic replacement for an opaque Map.
-}
module Akshara.Syntax (
  AksharaExpr (..),
) where

import Akshara.Transform (Transform)

data AksharaExpr a where
  Empty :: AksharaExpr a
  Pure :: a -> AksharaExpr a
  Sum :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (Either a b)
  Product :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (a, b)
  MapT :: Transform a b -> AksharaExpr a -> AksharaExpr b
