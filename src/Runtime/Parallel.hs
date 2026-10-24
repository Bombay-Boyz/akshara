{-# LANGUAGE DataKinds #-}

-- | Stage 10 (Akshara.md Section 107): parallel runtime.
--
-- /ADR 0001 fix, wired (Section 5.9)/: regions are now computed via
-- Akshara.Sized's rangeSized over [lo,hi) ranges, never by
-- materialising the full enumeration and slicing it. Each worker
-- computes its own region independently, inside its own async task
-- -- removing the shared, sequential enumerate step that previously
-- dominated wall-clock time regardless of worker count.
module Runtime.Parallel
  ( parallelFindAny
  , parallelFindCanonical
  ) where

import Akshara.Order (Order)
import Akshara.Partition (PartitionCount, partitionRanges)
import Akshara.Predicate (Predicate, evalP)
import Akshara.Result (AksharaResult (..), SolverKind (..), findMinimalWithProof)
import Akshara.Sized (rangeSized, sized, sizedCardinality)
import Akshara.Syntax (AksharaExpr)
import Control.Concurrent.Async (Async, async, cancel, mapConcurrently, waitAny)
import Control.Exception (bracket, evaluate)
import Data.Foldable (find)
import Data.List (delete)
import Data.List.NonEmpty (toList)
import Data.Maybe (catMaybes)

findInRegion :: Predicate a -> [a] -> Maybe a
findInRegion p = find (evalP p)

raceToFirstJust :: [Async (Maybe a)] -> IO (Maybe a)
raceToFirstJust [] = pure Nothing
raceToFirstJust asyncs = do
  (done, result) <- waitAny asyncs
  let remaining = delete done asyncs
  case result of
    Just x  -> Just x <$ mapM_ cancel remaining
    Nothing -> raceToFirstJust remaining

parallelFindAny
  :: PartitionCount -> Predicate a -> AksharaExpr a -> IO (AksharaResult 'AnySolve a)
parallelFindAny pc p e =
  let tree   = sized e
      ranges = toList (partitionRanges pc (sizedCardinality tree))
   in bracket
        (mapM (\(lo, hi) -> async (evaluate (findInRegion p (rangeSized tree lo hi)))) ranges)
        (mapM_ cancel)
        (fmap (maybe Exhausted FoundAny) . raceToFirstJust)

parallelFindCanonical
  :: PartitionCount
  -> Order a
  -> Predicate a
  -> AksharaExpr a
  -> IO (AksharaResult 'CanonicalSolve a)
parallelFindCanonical pc ord p e = do
  let tree   = sized e
      ranges = toList (partitionRanges pc (sizedCardinality tree))
  localWinners <-
    mapConcurrently
      (\(lo, hi) ->
          evaluate (fmap fst (findMinimalWithProof ord (filter (evalP p) (rangeSized tree lo hi)))))
      ranges
  pure $ case findMinimalWithProof ord (catMaybes localWinners) of
    Nothing         -> Exhausted
    Just (x, proof) -> FoundCanonical x proof
