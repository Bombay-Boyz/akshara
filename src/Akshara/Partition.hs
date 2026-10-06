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

newtype PartitionCount = UnsafePartitionCount Int deriving (Eq, Show)

mkPartitionCount :: Int -> Either PartitionError PartitionCount
mkPartitionCount n
  | n <= 0    = Left (NonPositivePartitionCount n)
  | otherwise = Right (UnsafePartitionCount n)

-- | A plain getter -- cannot be used to reconstruct a mismatched
-- 'PartitionCount', so exporting it does not reopen the invariant.
-- Needed by Runtime.Checkpoint's identity-mismatch error messages.
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
    []       -> [] :| []
  where
    step rest n = let (c, rest') = splitAt n rest in (rest', c)

reconstruct :: NonEmpty [a] -> [a]
reconstruct = concat . NE.toList
