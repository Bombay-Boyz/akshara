{- | Section 39: Partition -- coverage, disjointness, determinism,
reconstruction.

/ADR 0001, second attempt, also reverted (Section 5.9)/: computed
regions via Akshara.Indexed's per-element random access over
[lo,hi) instead of slicing a materialised enumerate. Benchmark
showed this ~8x SLOWER (120ms vs 14-17ms), not faster. Root cause,
now understood rather than just observed: 'indexed' redoes
analyzeCardinality work and re-walks shared subtrees on every
single element it looks up -- O(cardinality x depth) total across
a region, strictly worse than one O(cardinality) enumerate pass.
Lazy partitioning needs per-region *enumeration* that shares work
across a region's elements (e.g. a cursor/skip operation on
Akshara.Enumeration itself), not per-element indexed lookups. Not
attempted again this session -- two reverted attempts in hardening
is the point to stop and design on paper before writing more code
(Section 5.8). Akshara.Indexed is left in place (it is correct, by
its own oracle test) but Partition does not use it.
-}
module Akshara.Partition (
  PartitionCount,
  mkPartitionCount,
  unPartitionCount,
  partition,
  reconstruct,
) where

import Akshara.Enumeration (enumerate)
import Akshara.Errors (PartitionError (..))
import Akshara.Syntax (AksharaExpr)
import Data.List (mapAccumL)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NE

newtype PartitionCount = UnsafePartitionCount Int deriving (Eq, Show)

mkPartitionCount :: Int -> Either PartitionError PartitionCount
mkPartitionCount n
  | n <= 0 = Left (NonPositivePartitionCount n)
  | otherwise = Right (UnsafePartitionCount n)

unPartitionCount :: PartitionCount -> Int
unPartitionCount (UnsafePartitionCount n) = n

chunkSizes :: Int -> Int -> [Int]
chunkSizes total k =
  let (q, r) = total `divMod` k
   in replicate r (q + 1) ++ replicate (k - r) q

partition :: PartitionCount -> AksharaExpr a -> NonEmpty [a]
partition (UnsafePartitionCount k) e =
  case snd (mapAccumL step (enumerate e) (chunkSizes (length (enumerate e)) k)) of
    (c : cs) -> c :| cs
    [] -> [] :| []
  where
    step rest n = let (c, rest') = splitAt n rest in (rest', c)

reconstruct :: NonEmpty [a] -> [a]
reconstruct = concat . NE.toList
