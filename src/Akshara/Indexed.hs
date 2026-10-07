-- | Stage-15-hardening (ADR 0001): random access into an
-- enumeration by index, without materialising a prefix. Uses
-- Akshara.Analysis.Cardinality to skip whole subtrees -- O(depth)
-- per lookup rather than O(index).
--
-- This is what makes lazy, per-region partitioning (Runtime side)
-- possible: a region can be described as "indices [lo, hi) of this
-- AksharaExpr" and computed directly, instead of "a slice of the
-- fully materialised enumerate'd list" (the eager design ADR 0001
-- found to bottleneck Runtime.parallelFindCanonical).
module Akshara.Indexed
  ( indexed
  ) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (applyT)

-- | The i-th element (0-based) of this expression's enumeration, in
-- the same order 'Akshara.Enumeration.enumerate' produces, or
-- Nothing if i is out of range. Total: every branch either returns
-- directly or recurses on a strictly smaller subterm with a
-- re-derived in-range index (Section 4.1's structural recursion;
-- Section 2.4's bound is the expression's own finite shape, nothing
-- unbounded is threaded).
indexed :: AksharaExpr a -> Int -> Maybe a
indexed Empty    _ = Nothing
indexed (Pure x) i
  | i == 0    = Just x
  | otherwise = Nothing
indexed (Sum l r) i =
  let n = unExactly (analyzeCardinality l)
   in if i < n then Left <$> indexed l i else Right <$> indexed r (i - n)
indexed (Product l r) i =
  let n = unExactly (analyzeCardinality r)
   in if n == 0
        then Nothing
        else
          let (qi, ri) = i `divMod` n
           in (,) <$> indexed l qi <*> indexed r ri
indexed (MapT t e) i = applyT t <$> indexed e i
