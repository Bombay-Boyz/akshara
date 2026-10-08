-- | Section 39: Partition -- coverage, disjointness, determinism,
-- reconstruction.
module Akshara.Partition
  ( PartitionCount
  , mkPartitionCount
  , unPartitionCount
  , partition
  , reconstruct
  ) where

import Akshara.Enumeration (enumerate)
import Akshara.Errors (PartitionError (..))
import Akshara.Syntax (AksharaExpr)
import Data.List (mapAccumL)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NE

-- | Opaque: non-negativity and positivity are enforced once, at
-- construction.
newtype PartitionCount = UnsafePartitionCount Int deriving (Eq, Show)

-- | Section 64: "PartitionCount > 0," enforced once.
mkPartitionCount :: Int -> Either PartitionError PartitionCount
mkPartitionCount n
  | n <= 0    = Left (NonPositivePartitionCount n)
  | otherwise = Right (UnsafePartitionCount n)

-- | A plain getter -- cannot be used to reconstruct a mismatched
-- 'PartitionCount'.
unPartitionCount :: PartitionCount -> Int
unPartitionCount (UnsafePartitionCount n) = n

-- | k nearly-equal nonnegative sizes summing to `total` (k >= 1).
chunkSizes :: Int -> Int -> [Int]
chunkSizes total k =
  let (q, r) = total `divMod` k
   in replicate r (q + 1) ++ replicate (k - r) q

-- | Section 39's partition: k contiguous, non-overlapping, covering
-- slices of the domain's enumeration.
partition :: PartitionCount -> AksharaExpr a -> NonEmpty [a]
partition (UnsafePartitionCount k) e =
  case snd (mapAccumL step (enumerate e) (chunkSizes (length (enumerate e)) k)) of
    (c : cs) -> c :| cs
    []       -> [] :| []
  where
    step rest n = let (c, rest') = splitAt n rest in (rest', c)

-- | Section 39's reconstruction requirement, made executable.
reconstruct :: NonEmpty [a] -> [a]
reconstruct = concat . NE.toList
