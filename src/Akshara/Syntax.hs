-- | Layer A (Akshara.md Section 7): closed kernel syntax -- no
-- threads, files, sockets, or checkpoints. Section 12's minimal
-- algebra plus 'MapT' (Sections 13/15).
module Akshara.Syntax
  ( AksharaExpr (..)
  ) where

import Akshara.Transform (Transform)

data AksharaExpr a where
  -- | The empty domain: no values.
  Empty   :: AksharaExpr a
  -- | A singleton domain containing exactly the given value.
  Pure    :: a -> AksharaExpr a
  -- | The disjoint union (coproduct) of two domains.
  Sum     :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (Either a b)
  -- | The cartesian product of two domains.
  Product :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (a, b)
  -- | A symbolic transformation applied pointwise to a domain.
  MapT    :: Transform a b -> AksharaExpr a -> AksharaExpr b
