-- | Section 35: a total order as an explicit value (Section 0.5's
-- dependency inversion applied to ordering), rather than an implicit
-- 'Ord' constraint threaded everywhere (Section 1.8).
--
-- /Corrected design (Section 5.9)/: the original 'mkOrder' accepted
-- an arbitrary @a -> a -> Ordering@, whose total-order laws (Section
-- 35) could not be checked -- the one place in the kernel still
-- taking an opaque function, inconsistent with Akshara.Transform's
-- discipline of a small, closed, named set of constructors. Every
-- call site in this project was exactly @mkOrder compare@ (lifting
-- an existing 'Ord' instance), confirmed by grep across the whole
-- tree -- so 'fromOrd' loses nothing any current code needs, while
-- requiring 'Ord a' means the total-order laws are now exactly
-- 'Ord''s own documented contract, the same trust already placed in
-- every derived 'Ord' instance elsewhere in this project (e.g.
-- 'Akshara.Analysis.Cardinality.Cardinality').
module Akshara.Order
  ( Order
  , fromOrd
  , compareBy
  ) where

-- | Opaque. The only constructor is 'fromOrd'.
newtype Order a = Order (a -> a -> Ordering)

-- | Lift an existing 'Ord' instance. Total-order laws are exactly
-- 'Ord''s own contract, not independently re-verified here.
fromOrd :: Ord a => Order a
fromOrd = Order compare

-- | Compare two values under the given 'Order'.
compareBy :: Order a -> a -> a -> Ordering
compareBy (Order cmp) = cmp
