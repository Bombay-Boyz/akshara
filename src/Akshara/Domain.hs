-- | Sections 26-27: finite sequence domains Sigma^n and Sigma^(m..n).
module Akshara.Domain
  ( Length
  , mkLength
  , Range
  , mkRange
  , alphabetOf
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

-- | Section 48's alphabet concept, made general: a domain of exactly
-- the given symbols, in the given order, via the same Sum+UnifyT
-- fold Akshara.Domain.sequenceRange already uses to combine
-- same-typed alternatives. Rejects an empty list -- there is no
-- domain to search over zero symbols. Structural recursion on the
-- list, depth bounded by charset size (typically tens of
-- characters) -- negligible against the exponential cardinality
-- growth from length, by the same argument ADR 0002 already
-- establishes for sequenceRange's own chain.
alphabetOf :: (Eq a, Show a) => [a] -> Either DomainError (AksharaExpr a)
alphabetOf []       = Left EmptyAlphabet
alphabetOf [x]      = Right (Pure x)
alphabetOf (x : xs) = fmap (\rest -> MapT UnifyT (Sum (Pure x) rest)) (alphabetOf xs)

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
