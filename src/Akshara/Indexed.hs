-- | Stage-15-hardening (ADR 0001): random access into an
-- enumeration by index, without materialising a prefix.
--
-- /Corrected complexity claim (Section 5.9: no claim without proof)/.
-- This previously claimed O(depth) per lookup. That was false, and
-- the false claim was never caught because nothing benchmarked
-- 'indexed' in isolation against its own stated cost -- only against
-- 'Akshara.Partition's eager method, where it lost badly for a
-- reason not yet traced at the time.
--
-- The actual cost, derived by hand: at each 'Sum'/'Product' level,
-- 'indexed' calls 'Akshara.Analysis.Cardinality.analyzeCardinality'
-- on a child, which is itself O(that child's expression size) --
-- recomputed FRESH at every recursive level, never cached. For a
-- depth-n chain, this gives the recurrence C(k) = Theta(k) + C(k-1),
-- solving to C(k) = Theta(k^2) for ONE lookup -- not O(depth).
-- Computing a full m-element region this way costs Theta(m * n^2)
-- total, against Theta(n * |Sigma|^n) for eagerly enumerating the
-- whole domain once -- a factor-of-n regression, which is why the
-- first attempt to use this for lazy per-region partitioning
-- (Runtime.Parallel) was measured at roughly 8x slower, not faster,
-- for n=10. This function is correct (oracle-tested against
-- Akshara.Enumeration.enumerate) but its complexity claim was wrong,
-- and 'Akshara.Partition' does not use it as a result.
--
-- A genuine O(depth) version needs cardinality cached once, bottom
-- up, at construction -- not recomputed per lookup. That is a
-- different, not-yet-built type (a cardinality-annotated AST), not
-- a fix to this function as written.
module Akshara.Indexed
  ( indexed
  ) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (applyT)

-- | The i-th element (0-based) of this expression's enumeration, in
-- the same order 'Akshara.Enumeration.enumerate' produces, or
-- Nothing if i is out of range. Total. O(depth^2) per call on a
-- depth-n chain -- see the module Haddock for the derivation; this
-- is NOT O(depth) despite the shape of the recursion looking like it
-- should be.
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
