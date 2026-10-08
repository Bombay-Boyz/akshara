{-# LANGUAGE DataKinds #-}

{- | Stage 10 (Akshara.md Section 107): parallel runtime over an
already-partitioned finite domain.
-}
module Runtime.Parallel (
  parallelFindAny,
  parallelFindCanonical,
) where

import Akshara.Order (Order)
import Akshara.Partition (PartitionCount, partition)
import Akshara.Predicate (Predicate, evalP)
import Akshara.Result (AksharaResult (..), SolverKind (..), findMinimalWithProof)
import Akshara.Syntax (AksharaExpr)
import Control.Concurrent.Async (Async, async, cancel, mapConcurrently, waitAny)
import Control.Exception (bracket, evaluate)
import Data.Foldable (find)
import Data.List (delete)
import Data.List.NonEmpty (toList)
import Data.Maybe (catMaybes)

{- | hlint: find p is the named combinator this is (Section 4.1),
not a hand-composed listToMaybe . filter.
-}
findInRegion :: Predicate a -> [a] -> Maybe a
findInRegion p = find (evalP p)

raceToFirstJust :: [Async (Maybe a)] -> IO (Maybe a)
raceToFirstJust [] = pure Nothing
raceToFirstJust asyncs = do
  (done, result) <- waitAny asyncs
  let remaining = delete done asyncs
  case result of
    Just x -> Just x <$ mapM_ cancel remaining
    Nothing -> raceToFirstJust remaining

parallelFindAny ::
  PartitionCount -> Predicate a -> AksharaExpr a -> IO (AksharaResult 'AnySolve a)
parallelFindAny pc p e =
  bracket
    (mapM (async . evaluate . findInRegion p) (toList (partition pc e)))
    (mapM_ cancel)
    (fmap (maybe Exhausted FoundAny) . raceToFirstJust)

parallelFindCanonical ::
  PartitionCount ->
  Order a ->
  Predicate a ->
  AksharaExpr a ->
  IO (AksharaResult 'CanonicalSolve a)
parallelFindCanonical pc ord p e = do
  localWinners <-
    mapConcurrently
      (evaluate . fmap fst . findMinimalWithProof ord . filter (evalP p))
      (toList (partition pc e))
  pure $ case findMinimalWithProof ord (catMaybes localWinners) of
    Nothing -> Exhausted
    Just (x, proof) -> FoundCanonical x proof
