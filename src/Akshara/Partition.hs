-- | Section 39: Partition -- coverage, disjointness, determinism,
-- reconstruction. Computed by splitting the already-enumerated
-- domain, consistent with Akshara.Solver's precedent of working over
-- 'enumerate'.
--
-- /Deliberate scope limit (Section 5.9 ADR)/: Section 38's Region +
-- LowerBound structure stays out -- it has no caller until Stage 10's
-- parallel runtime.
module Akshara.Partition
  ( PartitionCount
  , mkPartitionCount
  , partition
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

-- | k nearly-equal nonnegative sizes summing to `total` (k >= 1): r of
-- the k pieces get one extra element, where (q, r) = total `divMod` k.
chunkSizes :: Int -> Int -> [Int]
chunkSizes total k =
  let (q, r) = total `divMod` k
   in replicate r (q + 1) ++ replicate (k - r) q

-- | Section 39, via Section 4.1's mapAccumL scheme.
partition :: PartitionCount -> AksharaExpr a -> NonEmpty [a]
partition (UnsafePartitionCount k) e =
  case snd (mapAccumL step (enumerate e) (chunkSizes (length (enumerate e)) k)) of
    (c : cs) -> c :| cs
    -- Unreachable: chunkSizes always returns exactly k elements, k >= 1
    -- by PartitionCount's invariant. Kept total rather than reached
    -- for 'error' (Section 1.1).
    []       -> [] :| []
  where
    step rest n = let (c, rest') = splitAt n rest in (rest', c)

reconstruct :: NonEmpty [a] -> [a]
reconstruct = concat . NE.toList
