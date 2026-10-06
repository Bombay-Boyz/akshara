{-# LANGUAGE DataKinds #-}

-- | Stage 10 (Akshara.md Section 107): parallel runtime over an
-- already-partitioned finite domain (Section 9's Partition). Lives in
-- the Runtime namespace, never Akshara -- Section 175 bans
-- ThreadId/MVar/STM/async/forkIO from the mathematical specification
-- itself, and Sections 2.6/106 require the dependency to run this
-- direction only (Runtime depends on Akshara; never the reverse).
--
-- Uses the `async` package (Section 2.11/4.7: depend on an
-- established library rather than hand-rolling fork/wait/cancel over
-- base's primitives).
--
-- /Module-layout deviation from Appendix A (Section 5.9 ADR)/:
-- Appendix A sketches separate Runtime/Engine.hs, Scheduler.hs,
-- Worker.hs. Collapsed into one module here -- not yet enough
-- independently-varying logic to justify three files (no dynamic work
-- queue, no separate worker abstraction beyond one async task per
-- region; Section 0.1's SRP test passes for a single module: "run a
-- partitioned search across worker threads" needs no "and"). Split
-- apart once Stage 11's checkpointing or a real scheduling policy
-- gives Scheduler/Worker distinct responsibilities.
--
-- /findAny's cancellation vs findCanonical's exhaustiveness (Section
-- 53)/: 'parallelFindAny' cancels outstanding regions once a match is
-- found -- permitted unconditionally for findAny. 'parallelFindCanonical'
-- never cancels; every region is searched to completion before any
-- reduction happens. That absence of early cancellation *is* the "no
-- better candidate remains" proof Section 53 requires for canonical
-- search -- so Sections 37/38's LowerBound/Region machinery is not
-- needed to make this sound. The honest trade: this parallelizes
-- generation/verification work but cannot prune an unexplored region
-- early. Worker-count independence (Section 83) holds unconditionally
-- here precisely because the capability this stage lacks is the one
-- Section 83 names as the precondition for the stronger,
-- pruning-capable version.
module Runtime.Parallel
  ( parallelFindAny
  , parallelFindCanonical
  ) where

import Akshara.Order (Order)
import Akshara.Partition (PartitionCount, partition)
import Akshara.Predicate (Predicate, evalP)
import Akshara.Result (AksharaResult (..), SolverKind (..), findMinimalWithProof)
import Akshara.Syntax (AksharaExpr)
import Control.Concurrent.Async (Async, async, cancel, mapConcurrently, waitAny)
import Control.Exception (bracket, evaluate)
import Data.List (delete)
import Data.List.NonEmpty (toList)
import Data.Maybe (catMaybes, listToMaybe)

-- | The first match in one already-materialised region, if any.
findInRegion :: Predicate a -> [a] -> Maybe a
findInRegion p = listToMaybe . filter (evalP p)

-- | Section 53: repeatedly wait for whichever still-running region
-- finishes next. A Just cancels every remaining region and wins
-- immediately; a Nothing is discarded and the wait continues over
-- what's left. Hand-written -- no Part 4.1 combinator matches this
-- "race, keep going on a negative result" shape -- but terminates for
-- the reason Section 4.10 requires of hand-written recursion:
-- `asyncs` strictly shrinks by one every call.
raceToFirstJust :: [Async (Maybe a)] -> IO (Maybe a)
raceToFirstJust [] = pure Nothing
raceToFirstJust asyncs = do
  (done, result) <- waitAny asyncs
  let remaining = delete done asyncs
  case result of
    Just x  -> Just x <$ mapM_ cancel remaining
    Nothing -> raceToFirstJust remaining

-- | Section 34/53. 'bracket' guarantees every region's 'Async' is
-- cancelled on every exit path -- normal, early win, or exception;
-- cancelling an already-finished 'Async' is a documented no-op, so no
-- separate "did it already finish" check is needed.
parallelFindAny
  :: PartitionCount -> Predicate a -> AksharaExpr a -> IO (AksharaResult 'AnySolve a)
parallelFindAny pc p e =
  bracket
    (mapM (async . evaluate . findInRegion p) (toList (partition pc e)))
    (mapM_ cancel)
    (fmap (maybe Exhausted FoundAny) . raceToFirstJust)

-- | Section 34/35/83: min_prec(Sol(D,P)), by searching every region to
-- completion in parallel, then reducing. Sound because Sol(D,P)
-- splits over the partition's disjoint cover (Sections 9/39): min of
-- a union of disjoint parts is the min of the parts' minima.
-- 'findMinimalWithProof' (Section 35/90) discharges that obligation
-- twice -- once per region, once again across the per-region
-- champions -- rather than reusing a region-local proof token as if
-- it already certified the global claim.
parallelFindCanonical
  :: PartitionCount
  -> Order a
  -> Predicate a
  -> AksharaExpr a
  -> IO (AksharaResult 'CanonicalSolve a)
parallelFindCanonical pc ord p e = do
  localWinners <-
    mapConcurrently
      (evaluate . fmap fst . findMinimalWithProof ord . filter (evalP p))
      (toList (partition pc e))
  pure $ case findMinimalWithProof ord (catMaybes localWinners) of
    Nothing         -> Exhausted
    Just (x, proof) -> FoundCanonical x proof
