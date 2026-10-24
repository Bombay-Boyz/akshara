{-# LANGUAGE DataKinds #-}

-- | Stage 13 (Section 91): the verifier-driven search engine --
-- sequential and parallel interpretations of the same contract
-- (Section 52: "the same specification can be interpreted as
-- enumerate(S) or parallelEnumerate(S, partitions) -- the
-- denotation is unchanged, only the operational interpretation
-- changes"). Both share 'findInRegionIO', the one short-circuiting
-- verify-and-stop-on-Accepted-or-Failed loop.
module Runtime.Engine
  ( verifiedFindAny
  , verifiedParallelFindAny
  ) where

import Akshara.Enumeration (enumerate)
import Akshara.Partition (PartitionCount, partitionRanges)
import Akshara.Result (AksharaResult (..), SolverKind (..))
import Akshara.Sized (rangeSized, sized, sizedCardinality)
import Akshara.Syntax (AksharaExpr)
import Control.Concurrent.Async (Async, async, cancel, waitAny)
import Control.Exception (bracket)
import Data.List (delete)
import Data.List.NonEmpty (toList)
import Verify.Class (Verification (..), VerifierHandle (..))

-- | Section 34 findAny, verifier-driven. Short-circuits on the
-- first Accepted or the first Failed outcome -- a Failed verifier
-- outcome terminates the search and is surfaced as Left, never
-- silently folded into Exhausted (Section 178).
findInRegionIO
  :: VerifierHandle e IO candidate -> (a -> candidate) -> [a] -> IO (Either e (Maybe a))
findInRegionIO verifier encode = go
  where
    go []       = pure (Right Nothing)
    go (x : xs) = do
      outcome <- runVerifier verifier (encode x)
      case outcome of
        Accepted   -> pure (Right (Just x))
        Rejected   -> go xs
        Failed err -> pure (Left err)

toFindAnyResult :: Either e (Maybe a) -> Either e (AksharaResult 'AnySolve a)
toFindAnyResult (Left err)       = Left err
toFindAnyResult (Right Nothing)  = Right Exhausted
toFindAnyResult (Right (Just x)) = Right (FoundAny x)

-- | Sequential: one region, the whole domain.
verifiedFindAny
  :: VerifierHandle e IO candidate
  -> (a -> candidate)
  -> AksharaExpr a
  -> IO (Either e (AksharaResult 'AnySolve a))
verifiedFindAny verifier encode e =
  toFindAnyResult <$> findInRegionIO verifier encode (enumerate e)

-- | Section 53's cancellation contract, generalised to also cancel
-- (and propagate) on the first Failed outcome, not only the first
-- Accepted one -- a verifier failure is as terminal as a find.
raceToFirstResult :: [Async (Either e (Maybe a))] -> IO (Either e (Maybe a))
raceToFirstResult [] = pure (Right Nothing)
raceToFirstResult asyncs = do
  (done, result) <- waitAny asyncs
  let remaining = delete done asyncs
  case result of
    Right (Just x) -> Right (Just x) <$ mapM_ cancel remaining
    Left err       -> Left err <$ mapM_ cancel remaining
    Right Nothing  -> raceToFirstResult remaining

-- | Parallel: each region computed independently from a Sized tree
-- (Section 5.9 / ADR 0001), inside its own async task -- never via
-- one shared, sequential enumerate.
verifiedParallelFindAny
  :: PartitionCount
  -> VerifierHandle e IO candidate
  -> (a -> candidate)
  -> AksharaExpr a
  -> IO (Either e (AksharaResult 'AnySolve a))
verifiedParallelFindAny pc verifier encode e = do
  let tree   = sized e
      ranges = toList (partitionRanges pc (sizedCardinality tree))
  result <-
    bracket
      (mapM (\(lo, hi) -> async (findInRegionIO verifier encode (rangeSized tree lo hi))) ranges)
      (mapM_ cancel)
      raceToFirstResult
  pure (toFindAnyResult result)
