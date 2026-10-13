module Main (main) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Domain (mkLength, replicateE)
import Akshara.Enumeration (enumerate)
import Akshara.Indexed (indexed)
import Akshara.Order (fromOrd)
import Akshara.Partition (mkPartitionCount, partition)
import Akshara.Predicate (Predicate (TrueP))
import Akshara.Sized (indexedSized, sized)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (UnifyT))
import Control.Monad (void)
import Criterion.Main
import Data.List.NonEmpty (NonEmpty (..))
import Runtime.Parallel (parallelFindCanonical)

alphabet3 :: AksharaExpr Char
alphabet3 = MapT UnifyT (Sum ab (Pure 'c'))
  where
    ab = MapT UnifyT (Sum (Pure 'a') (Pure 'b'))

cubeOfSize :: Int -> AksharaExpr [Char]
cubeOfSize n = either (const Empty) (`replicateE` alphabet3) (mkLength n)

partitionBenchmark :: Int -> Benchmark
partitionBenchmark k =
  bench (show k) $
    nf (either (const ([] :| [])) (`partition` cubeOfSize 10)) (mkPartitionCount k)

parallelBenchmark :: Int -> Benchmark
parallelBenchmark k =
  bench (show k)
    $ nfIO
    $ either
      (const (pure ()))
      (\pc -> void (parallelFindCanonical pc fromOrd TrueP (cubeOfSize 10)))
      (mkPartitionCount k)

-- | ADR 0001: a SINGLE lookup at a fixed index (0), at increasing
-- depth n. No cardinality/exponential term is involved -- one
-- lookup visits one root-to-leaf path only -- so this isolates
-- per-lookup cost purely as a function of depth: indexed should
-- show roughly 4x cost per depth doubling (O(n^2)); indexedSized
-- should show roughly 2x (O(n), build cost included).
indexedBenchmark :: Int -> Benchmark
indexedBenchmark n = bench (show n) $ nf (\d -> indexed (cubeOfSize d) 0) n

indexedSizedBenchmark :: Int -> Benchmark
indexedSizedBenchmark n =
  bench (show n) $ nf (\d -> indexedSized (sized (cubeOfSize d)) 0) n

main :: IO ()
main =
  defaultMain
    [ bgroup
        "enumerate : Sigma^n, |Sigma|=3"
        [bench (show n) $ nf (length . enumerate) (cubeOfSize n) | n <- [8, 10, 12]]
    , bgroup
        "analyzeCardinality : O(expr size), not O(cardinality)"
        [bench (show n) $ nf (unExactly . analyzeCardinality) (cubeOfSize n) | n <- [8, 10, 14, 18]]
    , bgroup
        "Partition.partition : double-enumerate suspect"
        [partitionBenchmark k | k <- [1, 2, 4, 8]]
    , bgroup
        "Runtime.parallelFindCanonical : worker scaling"
        [parallelBenchmark k | k <- [1, 2, 4, 8]]
    , bgroup
        "ADR 0001: indexed single-lookup cost vs depth (predicted O(depth^2))"
        [indexedBenchmark n | n <- [500, 1000, 2000, 4000]]
    , bgroup
        "ADR 0001: indexedSized single-lookup cost vs depth (predicted O(depth))"
        [indexedSizedBenchmark n | n <- [500, 1000, 2000, 4000]]
    ]
