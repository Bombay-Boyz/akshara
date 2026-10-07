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
import Verify.Errors (VerificationFailure (..))

spec :: Spec
spec = do
  describe "renderValidate" $ do
    it "reports OK on True" $
      renderValidate True `shouldBe` "validate: OK (domain and target hash constructed)"
    it "reports FAILED on False" $
      renderValidate False `shouldBe` "validate: FAILED (see error above)"

  -- | Section 2.8: checked mechanically against the real analysis
  -- functions, not against hand-computed expected numbers -- the
  -- same kind of arithmetic-by-hand mistake has already happened
  -- more than once in this project's own history.
  describe "renderAnalyze / renderPlan (Section 2.8)" $
    it "embed the actual cardinality and depth, not placeholder text" $
      withRight exampleDomain $ \domain -> do
        let expectedCardinality = show (unExactly (analyzeCardinality domain))
            expectedDepth       = show (unDepth (analyzeDepth domain))
        renderAnalyze domain `shouldSatisfy` (expectedCardinality `isInfixOf`)
        renderAnalyze domain `shouldSatisfy` (expectedDepth `isInfixOf`)
        renderPlan domain `shouldSatisfy` (expectedCardinality `isInfixOf`)
        renderPlan domain `shouldSatisfy` (expectedDepth `isInfixOf`)

  describe "renderRun (Section 178: Found/Exhausted/Failed stay distinct)" $ do
    it "renders FoundAny" $
      renderRun (Right (FoundAny "bc")) `shouldBe` "run: FOUND \"bc\""
    it "renders Exhausted" $
      renderRun (Right Exhausted :: Either VerificationFailure (AksharaResult 'AnySolve String))
        `shouldBe` "run: EXHAUSTED (no candidate accepted)"
    it "renders a Failed verifier outcome distinctly" $
      renderRun (Left (MalformedTargetHash "x")
                  :: Either VerificationFailure (AksharaResult 'AnySolve String))
        `shouldBe` "run: verifier FAILED: MalformedTargetHash \"x\""
