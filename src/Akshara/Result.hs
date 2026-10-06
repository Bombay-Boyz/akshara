{-# LANGUAGE DataKinds #-}

-- | Section 90: the any/canonical distinction lives in the type, via
-- a phantom 'SolverKind' index (Section 3.4's technique), so a caller
-- cannot mistake an uninvestigated 'findAny' result for a canonical
-- one -- a compile error, not a convention.
--
-- /Deliberate scope limit (Section 5.9 ADR)/: 'ExhaustiveSolve'
-- (Section 83) and the 'Failed'/'Inconclusive' constructors (Sections
-- 86-88) are not yet defined. Each becomes reachable only once
-- something actually produces it -- a verifier (Stage 12) for
-- 'Failed', a runtime cancellation/resource policy (Stage 10) for
-- 'Inconclusive' -- and Section 0.7 forbids adding either speculatively.
module Akshara.Result
  ( SolverKind (..)
  , MinimalityProof
  , AksharaResult (..)
  , findMinimalWithProof
  ) where

import Akshara.Order (Order, compareBy)

data SolverKind = AnySolve | CanonicalSolve

-- | Opaque: constructible only by 'findMinimalWithProof' below, the
-- one place Section 35's well-foundedness obligation is actually
-- discharged (Section 3.3's smart-constructor discipline, applied to
-- a proof rather than a value). Carries no content beyond the fact
-- of having been produced by that fold -- the fold itself is the proof.
newtype MinimalityProof = UnsafeMinimalityProof ()

data AksharaResult (k :: SolverKind) a where
  FoundAny       :: a -> AksharaResult 'AnySolve a
  FoundCanonical :: a -> MinimalityProof -> AksharaResult 'CanonicalSolve a
  Exhausted      :: AksharaResult k a

-- | Section 35's well-foundedness obligation over a finite, already-
-- materialised solution list: the candidate that is <= every other
-- element under the given order, found and proven in the same strict
-- left fold -- no separate re-verification step that could ever
-- disagree with how the minimum was found. 'Nothing' iff the list is
-- empty, in which case there is nothing to be canonical.
findMinimalWithProof :: Order a -> [a] -> Maybe (a, MinimalityProof)
findMinimalWithProof ord = foldl' step Nothing
  where
    step Nothing x = Just (x, UnsafeMinimalityProof ())
    step acc@(Just (best, _)) x
      | compareBy ord x best == LT = Just (x, UnsafeMinimalityProof ())
      | otherwise                  = acc
