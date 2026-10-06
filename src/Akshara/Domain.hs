-- | §26–27: finite sequence domains Σ^n and Σ^(m..n). No new kernel
-- primitive — only Product/Sum composed via two named Transforms.
--
-- /Deliberate scope limit (5.9 ADR, in lieu of Stage 5's fair-sum/
-- fair-product machinery)/: Σ* (§26's unbounded A* = 1+A×A*) needs the
-- least-fixed-point machinery §67 defers until productivity, fairness
-- and termination are established. 'Length'/'Range' enforce
-- non-negativity and lo<=hi, so every 'AksharaExpr' this module can
-- produce is finite by construction — which is exactly why no
-- Analysis.Finiteness or §25 Diagonal-Fair case split is introduced
-- here: neither has a reachable call site yet (1.11), and won't until
-- an infinite-producing constructor exists.
module Akshara.Domain
  ( Length
  , mkLength
  , Range
  , mkRange
  , DomainError (..)
  , replicateE
  , sequenceRange
  ) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (ConsT, UnifyT))

data DomainError = NegativeLength Int | EmptyRange Int Int
  deriving (Eq, Show)

-- | §64: the one real invariant on a sequence length is non-negativity.
newtype Length = UnsafeLength Int deriving (Eq, Ord, Show)

mkLength :: Int -> Either DomainError Length
mkLength n
  | n < 0     = Left (NegativeLength n)
  | otherwise = Right (UnsafeLength n)

-- | §27's m..n, validated once; downstream code never re-checks lo<=hi (1.3).
data Range = UnsafeRange Int Int deriving (Eq, Show)

mkRange :: Length -> Length -> Either DomainError Range
mkRange (UnsafeLength lo) (UnsafeLength hi)
  | lo > hi   = Left (EmptyRange lo hi)
  | otherwise = Right (UnsafeRange lo hi)

-- | Σ^n. Part 4.1 scheme: structural recursion on an already-validated
-- non-negative count.
replicateE :: Length -> AksharaExpr a -> AksharaExpr [a]
replicateE (UnsafeLength n) a = go n
  where
    go 0 = Pure []
    go k = MapT ConsT (Product a (go (k - 1)))

-- | Union_{k=lo}^{hi} Σ^k, folded to [a] at each step via 'UnifyT'.
sequenceRange :: Range -> AksharaExpr a -> AksharaExpr [a]
sequenceRange (UnsafeRange lo hi) a = go lo
  where
    go k
      | k == hi   = replicateE (UnsafeLength k) a
      | otherwise = MapT UnifyT (Sum (replicateE (UnsafeLength k) a) (go (k + 1)))
