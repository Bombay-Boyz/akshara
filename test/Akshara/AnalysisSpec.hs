module Akshara.AnalysisSpec (spec) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Analysis.Depth (analyzeDepth, unDepth)
import Akshara.Enumeration (enumerate)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (SumComm))
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = do
  describe "analyzeCardinality agrees with enumeration (Section 76 oracle)" $ do
    it "on Empty" $
      unExactly (analyzeCardinality (Empty :: AksharaExpr Int)) `shouldBe` 0
    it "on Pure" $
      unExactly (analyzeCardinality (Pure (5 :: Int))) `shouldBe` 1
    it "for arbitrary finite Sum terms" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
            e = Sum l r
         in unExactly (analyzeCardinality e) === length (enumerate e)
    it "for arbitrary finite Product terms" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
            e = Product l r
         in unExactly (analyzeCardinality e) === length (enumerate e)

  describe "analyzeDepth (Section 2.4's resource-bound quantity)" $ do
    it "Empty and Pure are depth 0" $ do
      unDepth (analyzeDepth (Empty :: AksharaExpr Int)) `shouldBe` 0
      unDepth (analyzeDepth (Pure (1 :: Int))) `shouldBe` 0
    it "a single Sum layer is depth 1" $
      unDepth (analyzeDepth (Sum (Pure (1 :: Int)) (Pure True))) `shouldBe` 1
    it "nesting adds one layer per level" $
      unDepth (analyzeDepth (Sum (Sum (Pure (1 :: Int)) (Pure True)) (Pure 'x')))
        `shouldBe` 2
    it "MapT does not add a layer" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
            e = Sum l r
         in analyzeDepth (MapT SumComm e) === analyzeDepth e
