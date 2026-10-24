-- | Section 5.9 / ADR 0001: a cardinality-annotated AksharaExpr.
-- Every node carries its own already-computed cardinality, so a
-- Sum/Product's child cardinality is an O(1) field read instead of
-- Akshara.Indexed's O(subtree size) recomputation at every level.
--
-- /Deliberate near-duplication (Section 0.6, documented, not
-- silent)/: 'sized''s +/* arithmetic duplicates
-- Akshara.Analysis.Cardinality.analyzeCardinality's own rules,
-- rather than calling it -- calling it on each subtree from the top
-- would recompute cardinality from scratch at every node, exactly
-- Akshara.Indexed's O(depth^2) defect, reintroduced.
--
-- /Status (Section 5.9)/: proven correct and genuinely O(depth) per
-- lookup in isolation (Akshara.SizedSpec, bench/Main.hs). Now wired
-- into Akshara.Partition/Runtime.Parallel/Runtime.Engine via
-- 'rangeSized'.
module Akshara.Sized
  ( Sized
  , sizedCardinality
  , sized
  , indexedSized
  , rangeSized
  ) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform, applyT)
import Data.Maybe (mapMaybe)

data Sized a = Sized Int (SizedShape a)

data SizedShape a where
  SizedEmpty   :: SizedShape a
  SizedPure    :: (Eq a, Show a) => a -> SizedShape a
  SizedSum     :: Sized a -> Sized b -> SizedShape (Either a b)
  SizedProduct :: Sized a -> Sized b -> SizedShape (a, b)
  SizedMapT    :: Transform a b -> Sized a -> SizedShape b

sizedCardinality :: Sized a -> Int
sizedCardinality (Sized n _) = n

-- | Builds a Sized tree in one bottom-up pass, Theta(expression
-- size).
sized :: AksharaExpr a -> Sized a
sized Empty         = Sized 0 SizedEmpty
sized (Pure x)       = Sized 1 (SizedPure x)
sized (Sum l r)     =
  let l' = sized l; r' = sized r
   in Sized (sizedCardinality l' + sizedCardinality r') (SizedSum l' r')
sized (Product l r) =
  let l' = sized l; r' = sized r
   in Sized (sizedCardinality l' * sizedCardinality r') (SizedProduct l' r')
sized (MapT t e)    =
  let e' = sized e
   in Sized (sizedCardinality e') (SizedMapT t e')

-- | The i-th element (0-based), against an already-built Sized tree.
-- Genuinely O(depth): every Sum/Product's child cardinality is an
-- O(1) field read, never recomputed.
indexedSized :: Sized a -> Int -> Maybe a
indexedSized (Sized _ shape) i = case shape of
  SizedEmpty -> Nothing
  SizedPure x
    | i == 0    -> Just x
    | otherwise -> Nothing
  SizedSum l r ->
    let n = sizedCardinality l
     in if i < n then Left <$> indexedSized l i else Right <$> indexedSized r (i - n)
  SizedProduct l r ->
    let n = sizedCardinality r
     in if n == 0
          then Nothing
          else
            let (qi, ri) = i `divMod` n
             in (,) <$> indexedSized l qi <*> indexedSized r ri
  SizedMapT t e -> applyT t <$> indexedSized e i

-- | The elements at indices [lo, hi) (half-open), in order. Proven,
-- for the domains this project builds, to cost Theta(range size x
-- depth) -- which exactly matches the necessary output size for
-- Akshara.Domain.replicateE's own structure (every element is a
-- length-n list; producing m of them costs at least Theta(m x n)
-- regardless of method), so this is asymptotically optimal, not
-- merely "good enough." A fancier single-traversal range-walk was
-- considered and rejected for the same reason -- it cannot do
-- better, and would be unjustified complexity (Section 0.7) for no
-- measurable gain.
rangeSized :: Sized a -> Int -> Int -> [a]
rangeSized tree lo hi = mapMaybe (indexedSized tree) [lo .. hi - 1]
