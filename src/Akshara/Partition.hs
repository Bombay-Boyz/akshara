-- | Section 39: Partition -- coverage, disjointness, determinism,
-- reconstruction.
module Akshara.Partition
  ( PartitionCount
  , mkPartitionCount
  , unPartitionCount
  , partition
  , partitionRanges
  , reconstruct
  ) where

import Akshara.Enumeration (enumerate)
import Akshara.Errors (PartitionError (..))
import Akshara.Syntax (AksharaExpr)
import Data.List (mapAccumL)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NE

newtype PartitionCount = UnsafePartitionCount Int deriving (Eq, Show)

mkPartitionCount :: Int -> Either PartitionError PartitionCount
mkPartitionCount n
  | n <= 0    = Left (NonPositivePartitionCount n)
  | otherwise = Right (UnsafePartitionCount n)

unPartitionCount :: PartitionCount -> Int
unPartitionCount (UnsafePartitionCount n) = n

chunkSizes :: Int -> Int -> [Int]
chunkSizes total k =
  let (q, r) = total `divMod` k
   in replicate r (q + 1) ++ replicate (k - r) q

-- | Eager: materialises every region via one shared enumerate. Kept
-- for existing callers/tests; Runtime.Parallel/Runtime.Engine now
-- use 'partitionRanges' instead (Section 5.9 / ADR 0001).
partition :: PartitionCount -> AksharaExpr a -> NonEmpty [a]
partition (UnsafePartitionCount k) e =
  case snd (mapAccumL step (enumerate e) (chunkSizes (length (enumerate e)) k)) of
    (c : cs) -> c :| cs
    []       -> [] :| []
  where
    step rest n = let (c, rest') = splitAt n rest in (rest', c)

-- | The k (lo, hi) index ranges a given total cardinality splits
-- into -- the index-only counterpart to 'partition', for callers
-- that materialise each region independently rather than eagerly.
partitionRanges :: PartitionCount -> Int -> NonEmpty (Int, Int)
partitionRanges (UnsafePartitionCount k) total =
  case ranges of
    (r : rs) -> r :| rs
    -- Unreachable: chunkSizes always returns exactly k elements and
    -- k >= 1 by PartitionCount's invariant. Kept total rather than
    -- reached for error.
    []       -> (0, 0) :| []
  where
    sizes  = chunkSizes total k
    starts = scanl (+) 0 sizes
    ranges = zipWith (\lo sz -> (lo, lo + sz)) starts sizes

reconstruct :: NonEmpty [a] -> [a]
reconstruct = concat . NE.toList
