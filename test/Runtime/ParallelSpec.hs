{-# LANGUAGE GADTs #-}

module Runtime.ParallelSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Enumeration (enumerate)
import Akshara.Order (Order, compareBy, mkOrder)
import Akshara.Partition (mkPartitionCount)
import Akshara.Predicate (Predicate (..))
import Akshara.Result (AksharaResult (..))
import Akshara.Solver (findCanonical)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRight)
import Akshara.Transform (Transform (UnifyT))
import Control.Monad (forM_)
import Data.List (sortBy)
import Runtime.Parallel (parallelFindAny, parallelFindCanonical)
import Test.Hspec

boolAlphabet :: AksharaExpr Bool
boolAlphabet = MapT UnifyT (Sum (Pure False) (Pure True))

boolCube :: Int -> AksharaExpr [Bool]
boolCube n = either (const Empty) (`replicateE` boolAlphabet) (mkLength n)

lexOrder :: Order [Bool]
lexOrder = mkOrder compare

referenceMinimum :: Order a -> [a] -> Maybe a
referenceMinimum ord xs = case sortBy (compareBy ord) xs of
  (m : _) -> Just m
  []      -> Nothing

spec :: Spec
spec = do
  describe "parallelFindAny (Section 34/53)" $ do
    it "a match found is always a genuine domain member satisfying the predicate" $
      forM_ [1 .. 4 :: Int] $ \k ->
        withRight (mkPartitionCount k) $ \pc -> do
          result <- parallelFindAny pc TrueP (boolCube 3)
          case result of
            FoundAny x -> enumerate (boolCube 3) `shouldContain` [x]
            Exhausted  -> expectationFailure "expected FoundAny, got Exhausted"

    it "exhausts when the predicate is unsatisfiable, at every worker count" $
      forM_ [1 .. 4 :: Int] $ \k ->
        withRight (mkPartitionCount k) $ \pc -> do
          result <- parallelFindAny pc FalseP (boolCube 3)
          case result of
            Exhausted  -> pure ()
            FoundAny _ -> expectationFailure "expected Exhausted, got FoundAny"

  describe "parallelFindCanonical (Section 83: worker-count independence)" $ do
    it "agrees with the sequential reference minimum at every worker count" $
      forM_ [1 .. 8 :: Int] $ \k ->
        withRight (mkPartitionCount k) $ \pc -> do
          result <- parallelFindCanonical pc lexOrder TrueP (boolCube 3)
          case result of
            FoundCanonical x _ ->
              Just x `shouldBe` referenceMinimum lexOrder (enumerate (boolCube 3))
            Exhausted -> expectationFailure "expected FoundCanonical, got Exhausted"

    it "agrees with the sequential findCanonical solver itself" $
      forM_ [1 .. 8 :: Int] $ \k ->
        withRight (mkPartitionCount k) $ \pc -> do
          parallelResult <- parallelFindCanonical pc lexOrder TrueP (boolCube 3)
          case (parallelResult, findCanonical lexOrder TrueP (boolCube 3)) of
            (FoundCanonical x _, FoundCanonical y _) -> x `shouldBe` y
            (Exhausted, Exhausted)                   -> pure ()
            _ -> expectationFailure "parallel and sequential solvers disagree"
