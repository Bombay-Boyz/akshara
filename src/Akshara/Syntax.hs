-- | Layer A (Akshara.md §7): closed kernel syntax — no threads, files,
-- sockets, or checkpoints. §12's minimal algebra: 0, 1, +, ×.
module Akshara.Syntax
  ( AksharaExpr (..)
  ) where

-- | 'Empty' the empty domain; 'Pure' a singleton; 'Sum'/'Product' the
-- coproduct/product, carrier-indexed so the type always reflects the
-- shape 'Akshara.Semantics.denote' produces (§18).
data AksharaExpr a where
  Empty   :: AksharaExpr a
  Pure    :: a -> AksharaExpr a
  Sum     :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (Either a b)
  Product :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (a, b)
