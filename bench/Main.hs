{-# LANGUAGE BangPatterns #-}

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
import Control.Concurrent.Async (mapConcurrently)
import Control.Exception (evaluate)
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

indexedBenchmark :: Int -> Benchmark
indexedBenchmark n = bench (show n) $ nf (\d -> indexed (cubeOfSize d) 0) n

indexedSizedBenchmark :: Int -> Benchmark
indexedSizedBenchmark n =
  bench (show n) $ nf (\d -> indexedSized (sized (cubeOfSize d)) 0) n

-- | RTS diagnostic (Section 5.9 / ADR 0001). Nothing here touches
-- Akshara's domain logic -- a fixed total amount of pure CPU work
-- (strict summation, BangPatterns so no thunk buildup skews the
-- measurement itself -- Section 4.9's strictness-on-evidence, the
-- evidence being this IS a micro-benchmark where that's the whole
-- point), split into k independent async tasks. If the RTS provides
-- real multi-core parallelism, wall time should drop as k increases
-- (up to core count). If async tasks are only cooperatively
-- multiplexed onto one OS thread, wall time stays roughly flat or
-- worsens, regardless of k, because total CPU work is unchanged and
-- there is no second core to put any of it on.
heavyWork :: Int -> Int
heavyWork n = go 0 1
  where
    go !acc i
      | i > n     = acc
      | otherwise = go (acc + i) (i + 1)

totalWork :: Int
totalWork = 20000000

splitWorkBenchmark :: Int -> Benchmark
splitWorkBenchmark k =
  bench (show k) $
    nfIO (mapConcurrently (evaluate . heavyWork) (replicate k (totalWork `div` k)))

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
    , bgroup
        "RTS diagnostic: fixed CPU work split across k async tasks (not Akshara logic)"
        [splitWorkBenchmark k | k <- [1, 2, 4, 8]]
    ]
