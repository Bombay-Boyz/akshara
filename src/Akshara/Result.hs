{-# LANGUAGE DataKinds #-}

{- | Section 90: the any/canonical distinction lives in the type, via
a phantom 'SolverKind' index (Section 3.4's technique).

/Newly-justified addition (Section 5.9 note, not a correction)/:
Eq/Show were omitted at Stage 6 -- tests destructured results by
hand instead. Stage 13 needs 'shouldBe' on whole results, so both
are added here now. Hand-written, not 'deriving': this GADT is not
vanilla (constructors fix the phantom index differently), so a
derived instance's behaviour is not something to trust unchecked --
same reasoning as Akshara.Predicate's hand-written Show (Stage 4).
-}
module Akshara.Result (
  SolverKind (..),
  MinimalityProof,
  AksharaResult (..),
  findMinimalWithProof,
) where

import Akshara.Order (Order, compareBy)

data SolverKind = AnySolve | CanonicalSolve

newtype MinimalityProof = UnsafeMinimalityProof ()
  deriving (Eq, Show)

data AksharaResult (k :: SolverKind) a where
  FoundAny :: a -> AksharaResult 'AnySolve a
  FoundCanonical :: a -> MinimalityProof -> AksharaResult 'CanonicalSolve a
  Exhausted :: AksharaResult k a

{- | Total via the wildcard: cross-constructor pairs (impossible at
any single, fixed k, but not relied upon to be ruled out by GHC's
refinement checker) are simply unequal.
-}
instance (Eq a) => Eq (AksharaResult k a) where
  FoundAny x == FoundAny y = x == y
  FoundCanonical x _ == FoundCanonical y _ = x == y
  Exhausted == Exhausted = True
  _ == _ = False

instance (Show a) => Show (AksharaResult k a) where
  show (FoundAny x) = "FoundAny " <> show x
  show (FoundCanonical x _) = "FoundCanonical " <> show x <> " <proof>"
  show Exhausted = "Exhausted"

findMinimalWithProof :: Order a -> [a] -> Maybe (a, MinimalityProof)
findMinimalWithProof ord = foldl' step Nothing
  where
    step Nothing x = Just (x, UnsafeMinimalityProof ())
    step acc@(Just (best, _)) x
      | compareBy ord x best == LT = Just (x, UnsafeMinimalityProof ())
      | otherwise = acc
