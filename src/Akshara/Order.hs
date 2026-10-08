-- | Section 35: a total order as an explicit value (Section 0.5's
-- dependency inversion applied to ordering), rather than an implicit
-- 'Ord' constraint threaded everywhere (Section 1.8).
module Akshara.Order
  ( Order
  , mkOrder
  , compareBy
  ) where

-- | /Known limitation, recorded rather than hidden/: 'mkOrder' cannot
-- mechanically verify the total-order laws (reflexivity,
-- antisymmetry, transitivity).
newtype Order a = Order (a -> a -> Ordering)

-- | Wrap a comparison function as an 'Order'. Its total-order laws
-- are not mechanically checked.
mkOrder :: (a -> a -> Ordering) -> Order a
mkOrder = Order

-- | Compare two values under the given 'Order'.
compareBy :: Order a -> a -> a -> Ordering
compareBy (Order cmp) = cmp
