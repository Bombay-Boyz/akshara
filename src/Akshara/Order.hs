-- | Section 35: a total order as an explicit value (Section 0.5's
-- dependency inversion applied to ordering, not just effects), rather
-- than an implicit 'Ord' constraint threaded everywhere (Section 1.8).
module Akshara.Order
  ( Order
  , mkOrder
  , compareBy
  ) where

-- | /Known limitation, recorded rather than hidden/: 'mkOrder' cannot
-- mechanically verify the total-order laws (reflexivity, antisymmetry,
-- transitivity) -- the same limitation Section 10 states for any
-- opaque Haskell function. Short of Section 3.11's Liquid Haskell
-- escalation (not justified here), the available check is property
-- testing a concrete instance (Section 0.3), done in
-- 'Akshara.SolverSpec'.
newtype Order a = Order (a -> a -> Ordering)

mkOrder :: (a -> a -> Ordering) -> Order a
mkOrder = Order

compareBy :: Order a -> a -> a -> Ordering
compareBy (Order cmp) = cmp
