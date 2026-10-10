{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

module Akshara.SolverSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Enumeration (enumerate)
import Akshara.Order (Order, compareBy, fromOrd)
import Akshara.Predicate (Predicate (..))
import Akshara.Result (AksharaResult (..), SolverKind (..))
import Akshara.Solver (findAny, findCanonical)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (UnifyT))
import Data.List (sortBy)
import Test.Hspec
import Test.QuickCheck

boolAlphabet :: AksharaExpr Bool
boolAlphabet = MapT UnifyT (Sum (Pure False) (Pure True))

{- | {False,True}^n via Stage 5's 'replicateE'. The total fallback to
'Empty' (never exercised: n here is always nonnegative) keeps this
helper honest without reaching for 'error' (Section 1.1).
-}
boolCube :: Int -> AksharaExpr [Bool]
boolCube n = either (const Empty) (`replicateE` boolAlphabet) (mkLength n)

lexOrder :: Order [Bool]
lexOrder = fromOrd

{- | A total stand-in for the oracle 'minimumBy' would compute --
'minimumBy' is partial on an empty list, which Section 1.1 bans.
-}
referenceMinimum :: Order a -> [a] -> Maybe a
referenceMinimum ord xs = case sortBy (compareBy ord) xs of
  (m : _) -> Just m
  [] -> Nothing

isExhausted :: AksharaResult k a -> Bool
isExhausted Exhausted = True
isExhausted _ = False

expectFoundAny :: AksharaResult 'AnySolve a -> (a -> Expectation) -> Expectation
expectFoundAny (FoundAny x) k = k x
expectFoundAny Exhausted _ = expectationFailure "expected FoundAny, got Exhausted"

expectFoundCanonical ::
  AksharaResult 'CanonicalSolve a -> (a -> Expectation) -> Expectation
expectFoundCanonical (FoundCanonical x _) k = k x
expectFoundCanonical Exhausted _ =
  expectationFailure "expected FoundCanonical, got Exhausted"

spec :: Spec
spec = do
  describe "findAny (Section 34)" $ do
    it "TrueP returns a member of the domain" $
      expectFoundAny (findAny TrueP (boolCube 2)) $ \x ->
        enumerate (boolCube 2) `shouldContain` [x]

    it "FalseP exhausts a nonempty domain" $
      isExhausted (findAny FalseP (boolCube 2)) `shouldBe` True

  describe "findCanonical (Sections 34-35, finite case)" $ do
    it "matches the reference minimum for a fixed cube" $
      expectFoundCanonical (findCanonical lexOrder TrueP (boolCube 3)) $ \x ->
        Just x `shouldBe` referenceMinimum lexOrder (enumerate (boolCube 3))

    it "FalseP exhausts a nonempty domain" $
      isExhausted (findCanonical lexOrder FalseP (boolCube 3)) `shouldBe` True

    it "agrees with the reference minimum for any cube size 0..4" $
      forAll (choose (0, 4)) $ \n ->
        let dom = boolCube n
         in case findCanonical lexOrder TrueP dom of
              FoundCanonical x _ -> Just x === referenceMinimum lexOrder (enumerate dom)
              Exhausted -> property False
