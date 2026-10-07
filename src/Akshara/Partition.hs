-- | Section 39: Partition.
--
-- /Reverted Stage 15 attempt, recorded rather than silently undone
-- (Section 5.9)/: a "let xs = enumerate e in ..." rewrite was tried
-- here on the hypothesis that it removed a double-enumerate. The
-- benchmark showed the rewrite made this function and
-- Runtime.parallelFindCanonical both slower, reproducibly (variance
-- under 1% on re-run) -- not noise. The original two-call form is
-- restored; whatever GHC's optimizer was doing with the original
-- syntactically-duplicated enumerate calls, it was doing it better
-- than the explicit let. No confirmed mechanism for why -- that is
-- itself the honest state of this, not a closed question.
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
