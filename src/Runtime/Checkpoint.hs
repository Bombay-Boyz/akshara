{-# LANGUAGE DataKinds #-}

-- | Stage 11 (Akshara.md Sections 54-57, 107): checkpoint/resume,
-- scoped to Runtime.Parallel's non-cancelling parallelFindCanonical
-- only (Section 55).
--
-- /SpecificationIdentity: corrected design (Section 5.9)/. An
-- earlier version made this a caller-supplied opaque string token,
-- reasoning (incorrectly) that Section 126's ban on a universal
-- AksharaExpr equality left no other option. That ban is real but
-- narrower than first assumed -- see Akshara.Fingerprint's module
-- Haddock. It does not forbid structural identity via type-erased
-- fingerprinting. 'specificationIdentityOf' now derives
-- SpecificationIdentity directly from the AksharaExpr -- total, no
-- failure mode -- so Section 56/57's "never resume against a
-- silently different artifact" is now actually enforced, not merely
-- honoured for whatever an arbitrary string happened to distinguish.
--
-- /PlanIdentity: still token-based, for a different and more honest
-- reason/. Not a Haskell-equality impossibility -- AksharaPlan's own
-- fields are fingerprintable/comparable now too. It's a modelling
-- gap: Section 44's full planner field list (partition strategy,
-- worker count, checkpoint strategy, verifier placement) is not yet
-- carried as data anywhere. Akshara.Plan's AksharaPlan (Stage 8)
-- carries nothing beyond what's already fully determined by the
-- domain itself -- cardinality/depth are pure functions of the
-- domain, not independent planner decisions. A PlanIdentity derived
-- from AksharaPlan's current fields would be redundant with
-- SpecificationIdentity. PlanIdentity stays an honest, freestanding
-- token until the planner carries enough independent state (a real
-- ExecutionPolicy, Section 91) to need a genuinely distinct identity.
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
import Akshara.Partition (PartitionCount, partition, unPartitionCount)
import Akshara.Predicate (Predicate, evalP)
import Akshara.Result (AksharaResult (..), SolverKind (..), findMinimalWithProof)
import Akshara.Syntax (AksharaExpr)
import Control.Concurrent.Async (mapConcurrently)
import Control.Exception (evaluate)
import Data.List (sortOn)
import Data.List.NonEmpty (toList)
import Data.Maybe (mapMaybe)
import Runtime.Errors (CheckpointError (..))

-- | Opaque: the only way to obtain one is 'specificationIdentityOf'.
-- Wraps a structural fingerprint -- two values are equal exactly
-- when the expressions they came from have the same shape, including
-- every Pure leaf's rendered value.
newtype SpecificationIdentity = SpecId ExprFingerprint deriving (Eq, Show)

-- | Derive a SpecificationIdentity directly from a specification.
-- Total: fingerprinting a well-typed AksharaExpr never fails.
specificationIdentityOf :: AksharaExpr a -> SpecificationIdentity
specificationIdentityOf = SpecId . fingerprint

-- | Still an opaque, caller-supplied, non-empty token -- see the
-- module Haddock for why this one hasn't been replaced.
newtype PlanIdentity = PlanId String deriving (Eq, Show)

mkPlanIdentity :: String -> Either CheckpointError PlanIdentity
mkPlanIdentity s
  | null s    = Left EmptyPlanIdentity
  | otherwise = Right (PlanId s)

-- | One region's outcome once computed.
data RegionOutcome a = RegionOutcome { regionIndex :: Int, regionWinner :: Maybe a }
  deriving (Eq, Show)

-- | Section 54's Frontier, specialised to the non-cancelling
-- canonical solver. Opaque: constructed only by 'emptyFrontier' and
-- 'resumeParallelFindCanonical'.
data Frontier a = Frontier
  { frontierPartitionCount :: PartitionCount
  , frontierCompleted      :: [RegionOutcome a]
  }
  deriving (Eq, Show)

emptyFrontier :: PartitionCount -> Frontier a
emptyFrontier pc = Frontier pc []

-- | Section 54: Checkpoint = SpecificationIdentity + PlanIdentity +
-- Frontier.
data Checkpoint a = Checkpoint
  { checkpointSpecId   :: SpecificationIdentity
  , checkpointPlanId   :: PlanIdentity
  , checkpointFrontier :: Frontier a
  }
  deriving (Eq, Show)

-- | Section 118: "Loads a checkpoint only after validating semantic
-- identity. A mismatch is an error." With SpecificationIdentity now
-- content-derived, this genuinely catches resuming against a
-- different domain.
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

-- | Section 53/55: resumes parallelFindCanonical from a frontier,
-- computing only regions not already marked Done.
resumeParallelFindCanonical
  :: Order a -> Predicate a -> AksharaExpr a -> Checkpoint a
  -> IO (AksharaResult 'CanonicalSolve a, Frontier a)
resumeParallelFindCanonical ord p e cp = do
  let fr          = checkpointFrontier cp
      pc          = frontierPartitionCount fr
      regions     = zip [0 ..] (toList (partition pc e))
      doneIndices = map regionIndex (frontierCompleted fr)
      pending     = filter (\(i, _) -> i `notElem` doneIndices) regions

  newOutcomes <-
    mapConcurrently
      (\(i, region) -> do
          winner <- evaluate (fmap fst (findMinimalWithProof ord (filter (evalP p) region)))
          pure (RegionOutcome i winner))
      pending

  let allOutcomes = sortOn regionIndex (frontierCompleted fr ++ newOutcomes)
      newFrontier  = fr { frontierCompleted = allOutcomes }
      globalResult =
        case findMinimalWithProof ord (mapMaybe regionWinner allOutcomes) of
          Nothing         -> Exhausted
          Just (x, proof) -> FoundCanonical x proof

  pure (globalResult, newFrontier)
