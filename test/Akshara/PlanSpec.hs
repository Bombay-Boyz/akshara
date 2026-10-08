module Akshara.PlanSpec (spec) where

import Akshara.Analysis.Cardinality (analyzeCardinality)
import Akshara.Analysis.Depth (analyzeDepth)
import Akshara.Enumeration (enumerate)
import Akshara.Plan (derivePlan, planCardinality, planDepth, planDomain)
import Akshara.Syntax (AksharaExpr (..))
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = do
  describe "derivePlan preserves meaning (Section 44's closing requirement)" $
    it "planDomain enumerates identically to the original expression" $
      property $ \ml mr ->
        let e =
              Sum
                (maybe Empty Pure (ml :: Maybe Int))
                (maybe Empty Pure (mr :: Maybe Bool))
            p = derivePlan e
         in enumerate (planDomain p) === enumerate e

  describe "derivePlan's bundled analysis matches direct analysis (Section 2.8)" $ do
    it "planCardinality agrees with analyzeCardinality" $
      property $ \ml mr ->
        let e =
              Sum
                (maybe Empty Pure (ml :: Maybe Int))
                (maybe Empty Pure (mr :: Maybe Bool))
            p = derivePlan e
         in planCardinality p === analyzeCardinality e

    it "planDepth agrees with analyzeDepth" $
      property $ \ml mr ->
        let e =
              Sum
                (maybe Empty Pure (ml :: Maybe Int))
                (maybe Empty Pure (mr :: Maybe Bool))
            p = derivePlan e
         in planDepth p === analyzeDepth e
