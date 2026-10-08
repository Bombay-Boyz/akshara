{-# LANGUAGE DataKinds #-}

-- | Section 90: the any/canonical distinction lives in the type, via
-- a phantom 'SolverKind' index, so a caller cannot mistake an
-- uninvestigated 'findAny' result for a canonical one -- a compile
-- error, not a convention.
module Akshara.Result
  ( SolverKind (..)
  , MinimalityProof
  , AksharaResult (..)
  , findMinimalWithProof
  ) where

import Akshara.Order (Order, compareBy)

-- | Which kind of solver produced, or may produce, an
-- 'AksharaResult'.
data SolverKind = AnySolve | CanonicalSolve

-- | Opaque witness that Section 35's well-foundedness obligation has
-- actually been discharged (Section 3.3's smart-constructor
-- discipline, applied to a proof rather than a value). The only
-- producer is 'findMinimalWithProof'.
newtype MinimalityProof = UnsafeMinimalityProof ()
  deriving (Eq, Show)

data AksharaResult (k :: SolverKind) a where
  -- | A member of the domain found by an any-solver; not claimed to
  -- be canonical.
  FoundAny       :: a -> AksharaResult 'AnySolve a
  -- | The canonical minimum, together with the proof that no smaller
  -- solution in the searched domain exists.
  FoundCanonical :: a -> MinimalityProof -> AksharaResult 'CanonicalSolve a
  -- | The domain was exhausted with no solution found.
  Exhausted      :: AksharaResult k a

-- | Total via the wildcard: cross-constructor pairs, impossible at
-- any single fixed @k@, are simply unequal.
instance Eq a => Eq (AksharaResult k a) where
  FoundAny x         == FoundAny y         = x == y
  FoundCanonical x _ == FoundCanonical y _ = x == y
  Exhausted          == Exhausted          = True
  _                  == _                  = False

instance Show a => Show (AksharaResult k a) where
  show (FoundAny x)         = "FoundAny " <> show x
  show (FoundCanonical x _) = "FoundCanonical " <> show x <> " <proof>"
  show Exhausted            = "Exhausted"

-- | Section 35's well-foundedness obligation over a finite,
-- already-materialised solution list: the candidate that is <=
-- every other element under the given order, found and proven in the
-- same strict left fold. 'Nothing' iff the list is empty.
findMinimalWithProof :: Order a -> [a] -> Maybe (a, MinimalityProof)
findMinimalWithProof ord = foldl' step Nothing
  where
    step Nothing x = Just (x, UnsafeMinimalityProof ())
    step acc@(Just (best, _)) x
      | compareBy ord x best == LT = Just (x, UnsafeMinimalityProof ())
      | otherwise                  = acc
