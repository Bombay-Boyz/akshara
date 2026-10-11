-- | Layer A (Akshara.md Section 7): closed kernel syntax -- no
-- threads, files, sockets, or checkpoints. Section 12's minimal
-- algebra plus 'MapT' (Sections 13/15).
--
-- /Corrected design (Section 5.9)/: 'Pure' now carries (Eq a, Show a)
-- as a per-constructor constraint. This is what makes genuine
-- structural content-identity (Akshara.Fingerprint) possible for any
-- AksharaExpr, without a universal, unconstrained
-- @AksharaExpr a -> AksharaExpr a -> Bool@ (Section 126 still
-- correctly forbids that). The constraint sits only on 'Pure' --
-- 'Sum'/'Product' never need their own (Either/(,) already derive
-- Eq/Show from their components), and 'Empty'/'MapT' never store a
-- leaf value at all. Every current caller already supplies concrete,
-- trivially Eq/Show-able alphabet symbols (Char, Bool), so this costs
-- nothing in practice.
module Akshara.Syntax
  ( AksharaExpr (..)
  ) where

import Akshara.Transform (Transform)

data AksharaExpr a where
  -- | The empty domain: no values.
  Empty   :: AksharaExpr a
  -- | A singleton domain containing exactly the given value. Carries
  -- (Eq a, Show a) so the value can always be rendered into a
  -- structural fingerprint without needing a universal equality on
  -- AksharaExpr itself.
  Pure    :: (Eq a, Show a) => a -> AksharaExpr a
  -- | The disjoint union (coproduct) of two domains.
  Sum     :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (Either a b)
  -- | The cartesian product of two domains.
  Product :: AksharaExpr a -> AksharaExpr b -> AksharaExpr (a, b)
  -- | A symbolic transformation applied pointwise to a domain.
  MapT    :: Transform a b -> AksharaExpr a -> AksharaExpr b
