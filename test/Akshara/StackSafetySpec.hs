module Akshara.StackSafetySpec (spec) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Analysis.Depth (analyzeDepth, unDepth)
import Akshara.Enumeration (enumerate)
import Akshara.Predicate (Predicate (..), evalP)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (Compose, Identity, UnifyT), applyT)
import Test.Hspec

deepChain :: Int -> AksharaExpr Int
deepChain 0 = Pure 0
deepChain n = MapT UnifyT (Sum (Pure n) (deepChain (n - 1)))

deepNot :: Int -> Predicate Int
deepNot 0 = TrueP
deepNot n = Not (deepNot (n - 1))

deepCompose :: Int -> Transform Int Int
deepCompose 0 = Identity
deepCompose n = Compose Identity (deepCompose (n - 1))

{- | Bounded by Akshara.Domain's actual reach (ADR 0002): sequence
lengths in realistic search specifications, not an adversarial
probe. 2,000 is a generous upper bound on any plausible candidate
length; the ADR 0002 regime (50,000+) is intentionally not tested
here as a passing case -- it is documented as a known limitation.
-}
depthN :: Int
depthN = 2000

spec :: Spec
spec = do
  describe "deep Sum/MapT chains, bounded by realistic Domain usage (ADR 0002)" $ do
    it "enumerate survives depth 2,000" $
      length (enumerate (deepChain depthN)) `shouldBe` (depthN + 1)
    it "analyzeCardinality survives depth 2,000" $
      unExactly (analyzeCardinality (deepChain depthN)) `shouldBe` (depthN + 1)
    it "analyzeDepth survives depth 2,000" $
      unDepth (analyzeDepth (deepChain depthN)) `shouldBe` depthN

  describe "deep Predicate Not-chains"
    $ it "evalP survives depth 4,000"
    $ evalP (deepNot (2 * depthN)) (0 :: Int) `shouldBe` True

  describe "deep Transform Compose-chains"
    $ it "applyT survives depth 2,000"
    $ applyT (deepCompose depthN) (42 :: Int) `shouldBe` 42
