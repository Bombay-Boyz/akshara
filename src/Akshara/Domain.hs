-- | Sections 26-27: finite sequence domains Sigma^n and Sigma^(m..n).
--
-- /Ripple from Akshara.Syntax's Pure constraint (Section 5.9)/:
-- replicateE/sequenceRange each construct a Pure value internally
-- (the empty-sequence base case), so they now require (Eq a, Show a)
-- on the alphabet type -- trivially satisfied by every alphabet this
-- project actually builds.
module Akshara.Domain
  ( Length
  , mkLength
  , Range
  , mkRange
  , replicateE
  , sequenceRange
  ) where

import Akshara.Errors (DomainError (..))
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (ConsT, UnifyT))

newtype Length = UnsafeLength Int deriving (Eq, Ord, Show)

mkLength :: Int -> Either DomainError Length
mkLength n
  | n < 0     = Left (NegativeLength n)
  | otherwise = Right (UnsafeLength n)

data Range = UnsafeRange Int Int deriving (Eq, Show)

mkRange :: Length -> Length -> Either DomainError Range
mkRange (UnsafeLength lo) (UnsafeLength hi)
  | lo > hi   = Left (EmptyRange lo hi)
  | otherwise = Right (UnsafeRange lo hi)

-- | Sigma^n: the domain of exactly-length-n sequences over the given
-- alphabet.
replicateE :: (Eq a, Show a) => Length -> AksharaExpr a -> AksharaExpr [a]
replicateE (UnsafeLength n) a = go n
  where
    go 0 = Pure []
    go k = MapT ConsT (Product a (go (k - 1)))

-- | Union_{k=lo}^{hi} Sigma^k: the domain of sequences whose length
-- falls in the given range.
sequenceRange :: (Eq a, Show a) => Range -> AksharaExpr a -> AksharaExpr [a]
sequenceRange (UnsafeRange lo hi) a = go lo
  where
    go k
      | k == hi   = replicateE (UnsafeLength k) a
      | otherwise = MapT UnifyT (Sum (replicateE (UnsafeLength k) a) (go (k + 1)))
