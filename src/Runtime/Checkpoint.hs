{-# LANGUAGE DataKinds #-}

{- | Stage 11 (Akshara.md Sections 54-57, 107): checkpoint/resume,
scoped to Runtime.Parallel's non-cancelling parallelFindCanonical
only (Section 55: "not every search is resumable -- this is
intentional").

/Deliberate scope limit (Section 5.9 ADR)/: parallelFindAny is not
made resumable. Its early cancellation (Stage 10) means "which
regions were still in flight when interrupted" is a nondeterministic
runtime fact, not a reproducible one -- Section 55 requires the
frontier itself to be reproducible, which a race's mid-flight state
is not. parallelFindCanonical never cancels (Stage 10's design), so
its frontier -- which regions are Done with which local winner,
which are still Pending -- is exactly reproducible from the
specification plus the set of completed indices.

/Deliberate scope limit (Section 5.9 ADR)/: SpecificationIdentity
and PlanIdentity are caller-supplied opaque tokens, never derived
by comparing two 'AksharaExpr' values for equality. Section 126
explicitly forbids a universal
`same :: AksharaExpr a -> AksharaExpr a -> Bool` -- Pure's payload
type has no general decidable equality (Sections 121/126), and no
normalisation pass (Section 120, deferred) exists yet to compare
canonical forms instead. Token equality is therefore the only
identity check actually available: Section 56/57's "never resume
against a silently different artifact" is honoured for whatever the
caller's tokens actually distinguish, and no stronger claim is made.
-}
module Runtime.Checkpoint (
  SpecificationIdentity,
  mkSpecificationIdentity,
  PlanIdentity,
  mkPlanIdentity,
  Frontier,
  emptyFrontier,
  Checkpoint (..),
  validateCheckpoint,
  resumeParallelFindCanonical,
) where

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

{- | Section 64-style non-empty token. Opaque: non-emptiness is the
only invariant, enforced once.
-}
newtype SpecificationIdentity = SpecId String deriving (Eq, Show)

mkSpecificationIdentity :: String -> Either CheckpointError SpecificationIdentity
mkSpecificationIdentity s
  | null s = Left (EmptyIdentity "SpecificationIdentity")
  | otherwise = Right (SpecId s)

newtype PlanIdentity = PlanId String deriving (Eq, Show)

mkPlanIdentity :: String -> Either CheckpointError PlanIdentity
mkPlanIdentity s
  | null s = Left (EmptyIdentity "PlanIdentity")
  | otherwise = Right (PlanId s)

{- | One region's outcome once computed: its index into the partition,
and its local canonical winner if one exists.
-}
data RegionOutcome a = RegionOutcome {regionIndex :: Int, regionWinner :: Maybe a}
  deriving (Eq, Show)

{- | Section 54's Frontier, specialised to the non-cancelling
canonical solver. Opaque: constructed only by 'emptyFrontier' and
'resumeParallelFindCanonical', so an index is always in range and
never duplicated -- the two things a hand-assembled Frontier could
get wrong.
-}
data Frontier a = Frontier
  { frontierPartitionCount :: PartitionCount
  , frontierCompleted :: [RegionOutcome a]
  }
  deriving (Eq, Show)

emptyFrontier :: PartitionCount -> Frontier a
emptyFrontier pc = Frontier pc []

{- | Section 54: Checkpoint = SpecificationIdentity + PlanIdentity +
Frontier. No cross-field invariant is enforced at construction --
unlike Section 1.3's usual case, a mismatched triple is not an
illegal state, only a checkpoint that does not match what it is
about to be resumed against. That check happens at the use site,
in 'validateCheckpoint', per Section 118's "validate before load."
-}
data Checkpoint a = Checkpoint
  { checkpointSpecId :: SpecificationIdentity
  , checkpointPlanId :: PlanIdentity
  , checkpointFrontier :: Frontier a
  }
  deriving (Eq, Show)

{- | Section 118: "Loads a checkpoint only after validating semantic
identity. A mismatch is an error" -- never a silent resume against
a different specification, plan, or partition scheme (Section
56/57).
-}
validateCheckpoint ::
  SpecificationIdentity ->
  PlanIdentity ->
  PartitionCount ->
  Checkpoint a ->
  Either CheckpointError ()
validateCheckpoint expectedSpec expectedPlan expectedPc cp
  | checkpointSpecId cp /= expectedSpec =
      Left (SpecificationIdentityMismatch (show (checkpointSpecId cp)) (show expectedSpec))
  | checkpointPlanId cp /= expectedPlan =
      Left (PlanIdentityMismatch (show (checkpointPlanId cp)) (show expectedPlan))
  | frontierPartitionCount (checkpointFrontier cp) /= expectedPc =
      Left
        ( PartitionCountMismatch
            (unPartitionCount (frontierPartitionCount (checkpointFrontier cp)))
            (unPartitionCount expectedPc)
        )
  | otherwise = Right ()

{- | Section 53/55: resumes parallelFindCanonical from a frontier,
computing only regions not already marked Done. Sound for the same
reason Stage 10's parallelFindCanonical is: regions are disjoint,
and min of a union of disjoint parts is the min of the parts'
minima -- so a region's recorded local winner is reused unchanged
rather than recomputed.
-}
resumeParallelFindCanonical ::
  Order a ->
  Predicate a ->
  AksharaExpr a ->
  Checkpoint a ->
  IO (AksharaResult 'CanonicalSolve a, Frontier a)
resumeParallelFindCanonical ord p e cp = do
  let fr = checkpointFrontier cp
      pc = frontierPartitionCount fr
      regions = zip [0 ..] (toList (partition pc e))
      doneIndices = map regionIndex (frontierCompleted fr)
      pending = filter (\(i, _) -> i `notElem` doneIndices) regions

  newOutcomes <-
    mapConcurrently
      ( \(i, region) -> do
          winner <- evaluate (fmap fst (findMinimalWithProof ord (filter (evalP p) region)))
          pure (RegionOutcome i winner)
      )
      pending

  let allOutcomes = sortOn regionIndex (frontierCompleted fr ++ newOutcomes)
      newFrontier = fr{frontierCompleted = allOutcomes}
      globalResult =
        case findMinimalWithProof ord (mapMaybe regionWinner allOutcomes) of
          Nothing -> Exhausted
          Just (x, proof) -> FoundCanonical x proof

  pure (globalResult, newFrontier)
