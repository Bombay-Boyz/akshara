module Main (main) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Domain (mkLength, replicateE)
import Akshara.Enumeration (enumerate)
import Akshara.Order (fromOrd)
import Akshara.Partition (mkPartitionCount, partition)
import Akshara.Predicate (Predicate (TrueP))
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
    ]
