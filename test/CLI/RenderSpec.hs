{-# LANGUAGE DataKinds #-}

module CLI.RenderSpec (spec) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Analysis.Depth (analyzeDepth, unDepth)
import Akshara.Result (AksharaResult (..), SolverKind (AnySolve))
import Akshara.TestSupport (withRight)
import CLI.Example (exampleDomain)
import CLI.Render (renderAnalyze, renderPlan, renderRun, renderValidate)
import Data.List (isInfixOf)
import Test.Hspec
import Verify.Errors (SaltedSha256Error (..))

spec :: Spec
spec = do
  describe "renderValidate" $ do
    it "reports OK on True" $
      renderValidate True `shouldBe` "validate: OK (domain and target hash constructed)"
    it "reports FAILED on False" $
      renderValidate False `shouldBe` "validate: FAILED (see error above)"

  describe "renderAnalyze / renderPlan (Section 2.8)" $
    it "embed the actual cardinality and depth, not placeholder text" $
      withRight exampleDomain $ \domain -> do
        let expectedCardinality = show (unExactly (analyzeCardinality domain))
            expectedDepth = show (unDepth (analyzeDepth domain))
        renderAnalyze domain `shouldSatisfy` (expectedCardinality `isInfixOf`)
        renderAnalyze domain `shouldSatisfy` (expectedDepth `isInfixOf`)
        renderPlan domain `shouldSatisfy` (expectedCardinality `isInfixOf`)
        renderPlan domain `shouldSatisfy` (expectedDepth `isInfixOf`)

  describe "renderRun (Section 178: Found/Exhausted/Failed stay distinct)" $ do
    it "renders FoundAny" $
      renderRun (Right (FoundAny "bc") :: Either SaltedSha256Error (AksharaResult 'AnySolve String))
        `shouldBe` "run: FOUND \"bc\""
    it "renders Exhausted" $
      renderRun (Right Exhausted :: Either SaltedSha256Error (AksharaResult 'AnySolve String))
        `shouldBe` "run: EXHAUSTED (no candidate accepted)"
    it "renders a Failed verifier outcome distinctly" $
      renderRun
        ( Left (InvalidTargetHash "x")
            :: Either SaltedSha256Error (AksharaResult 'AnySolve String)
        )
        `shouldBe` "run: verifier FAILED: InvalidTargetHash \"x\""
