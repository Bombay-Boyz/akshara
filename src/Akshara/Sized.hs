-- | Section 5.9 / ADR 0001: a cardinality-annotated AksharaExpr.
-- Every node carries its own already-computed cardinality, so a
-- Sum/Product's child cardinality is an O(1) field read instead of
-- Akshara.Indexed's O(subtree size) recomputation at every level --
-- the standard, textbook technique for O(depth) order-statistics on
-- a tree (size-annotated nodes), not a novel invention.
--
-- /Deliberate near-duplication (Section 0.6, documented, not
-- silent)/: 'sized''s +/* arithmetic duplicates
-- Akshara.Analysis.Cardinality.analyzeCardinality's own rules,
-- rather than calling it -- calling it on each subtree from the top
-- would recompute cardinality from scratch at every node, exactly
-- Akshara.Indexed's O(depth^2) defect, reintroduced.
--
-- /Status (Section 5.9)/: proven correct and genuinely O(depth) in
-- isolation (Akshara.SizedSpec, bench/Main.hs). Not yet wired into
-- Akshara.Partition or Runtime.Parallel.
module Akshara.Sized
  ( Sized
  , sizedCardinality
  , sized
  , indexedSized
  ) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform, applyT)

-- | Opaque: the only constructor is 'sized'. Plain (non-record):
-- the shape field has no public accessor, so only 'sizedCardinality'
-- -- hand-written below, not auto-generated record syntax -- is a
-- real top-level binding to keep -Wunused-top-binds satisfied.
data Sized a = Sized Int (SizedShape a)

data SizedShape a where
  SizedEmpty   :: SizedShape a
  SizedPure    :: (Eq a, Show a) => a -> SizedShape a
  SizedSum     :: Sized a -> Sized b -> SizedShape (Either a b)
  SizedProduct :: Sized a -> Sized b -> SizedShape (a, b)
  SizedMapT    :: Transform a b -> Sized a -> SizedShape b

-- | A plain getter.
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
