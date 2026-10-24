{-# LANGUAGE DataKinds #-}

-- | Stage 11 (Akshara.md Sections 54-57, 107): checkpoint/resume.
module Runtime.Checkpoint
  ( SpecificationIdentity
  , specificationIdentityOf
  , PlanIdentity
  , mkPlanIdentity
  , Frontier
  , emptyFrontier
  , Checkpoint (..)
  , validateCheckpoint
  , resumeParallelFindCanonical
  ) where

import Akshara.Fingerprint (ExprFingerprint, fingerprint)
import Akshara.Order (Order)
import Akshara.Partition (PartitionCount, partitionRanges, unPartitionCount)
import Akshara.Predicate (Predicate, evalP)
import Akshara.Result (AksharaResult (..), SolverKind (..), findMinimalWithProof)
import Akshara.Sized (rangeSized, sized, sizedCardinality)
import Akshara.Syntax (AksharaExpr)
import Control.Concurrent.Async (mapConcurrently)
import Control.Exception (evaluate)
import Data.List (sortOn)
import Data.List.NonEmpty (toList)
import Data.Maybe (mapMaybe)
import Runtime.Errors (CheckpointError (..))

newtype SpecificationIdentity = SpecId ExprFingerprint deriving (Eq, Show)

specificationIdentityOf :: AksharaExpr a -> SpecificationIdentity
specificationIdentityOf = SpecId . fingerprint

newtype PlanIdentity = PlanId String deriving (Eq, Show)

mkPlanIdentity :: String -> Either CheckpointError PlanIdentity
mkPlanIdentity s
  | null s    = Left EmptyPlanIdentity
  | otherwise = Right (PlanId s)

data RegionOutcome a = RegionOutcome { regionIndex :: Int, regionWinner :: Maybe a }
  deriving (Eq, Show)

data Frontier a = Frontier
  { frontierPartitionCount :: PartitionCount
  , frontierCompleted      :: [RegionOutcome a]
  }
  deriving (Eq, Show)

emptyFrontier :: PartitionCount -> Frontier a
emptyFrontier pc = Frontier pc []

data Checkpoint a = Checkpoint
  { checkpointSpecId   :: SpecificationIdentity
  , checkpointPlanId   :: PlanIdentity
  , checkpointFrontier :: Frontier a
  }
  deriving (Eq, Show)

validateCheckpoint
  :: SpecificationIdentity -> PlanIdentity -> PartitionCount -> Checkpoint a
  -> Either CheckpointError ()
validateCheckpoint expectedSpec expectedPlan expectedPc cp
  | checkpointSpecId cp /= expectedSpec =
      Left (SpecificationIdentityMismatch (show (checkpointSpecId cp)) (show expectedSpec))
  | checkpointPlanId cp /= expectedPlan =
      Left (PlanIdentityMismatch (show (checkpointPlanId cp)) (show expectedPlan))
  | frontierPartitionCount (checkpointFrontier cp) /= expectedPc =
      Left (PartitionCountMismatch
              (unPartitionCount (frontierPartitionCount (checkpointFrontier cp)))
              (unPartitionCount expectedPc))
  | otherwise = Right ()

-- | Section 5.9 / ADR 0001: regions are now computed via Sized
-- ranges, not the eager 'partition'. A resumed search over a
-- near-complete frontier no longer pays to re-materialise ALREADY
-- Done regions at all -- 'pending' is filtered before any
-- 'rangeSized' call, so skipped work is genuinely skipped, not just
-- recomputed and discarded.
resumeParallelFindCanonical
  :: Order a -> Predicate a -> AksharaExpr a -> Checkpoint a
  -> IO (AksharaResult 'CanonicalSolve a, Frontier a)
resumeParallelFindCanonical ord p e cp = do
  let fr          = checkpointFrontier cp
      pc          = frontierPartitionCount fr
      tree        = sized e
      ranges      = zip [0 ..] (toList (partitionRanges pc (sizedCardinality tree)))
      doneIndices = map regionIndex (frontierCompleted fr)
      pending     = filter (\(i, _) -> i `notElem` doneIndices) ranges

  newOutcomes <-
    mapConcurrently
      (\(i, (lo, hi)) -> do
          winner <-
            evaluate (fmap fst (findMinimalWithProof ord (filter (evalP p) (rangeSized tree lo hi))))
          pure (RegionOutcome i winner))
      pending

  let allOutcomes = sortOn regionIndex (frontierCompleted fr ++ newOutcomes)
      newFrontier  = fr { frontierCompleted = allOutcomes }
      globalResult =
        case findMinimalWithProof ord (mapMaybe regionWinner allOutcomes) of
          Nothing         -> Exhausted
          Just (x, proof) -> FoundCanonical x proof

  pure (globalResult, newFrontier)
