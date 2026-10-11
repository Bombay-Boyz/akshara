module Akshara.FingerprintSpec (spec) where

import Akshara.Fingerprint (fingerprint)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (UnifyT))
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = do
  describe "fingerprint (Section 5.9: genuine structural content-identity)" $ do
    it "two separately-built, structurally-identical expressions fingerprint equal" $
      let e1 = Sum (Pure (1 :: Int)) (Pure (2 :: Int))
          e2 = Sum (Pure (1 :: Int)) (Pure (2 :: Int))
       in fingerprint e1 `shouldBe` fingerprint e2

    it "differing Pure leaf values fingerprint unequal" $
      let e1 = Sum (Pure (1 :: Int)) (Pure (2 :: Int))
          e2 = Sum (Pure (1 :: Int)) (Pure (3 :: Int))
       in fingerprint e1 `shouldNotBe` fingerprint e2

    it "differing shape (Sum vs Product) fingerprints unequal, same leaves" $
      fingerprint (Sum (Pure (1 :: Int)) (Pure (2 :: Int)))
        `shouldNotBe` fingerprint (Product (Pure (1 :: Int)) (Pure (2 :: Int)))

    it "distinguishes a MapT-wrapped expression from its bare inner expression" $
      fingerprint (MapT UnifyT (Sum (Pure False) (Pure True)))
        `shouldNotBe` fingerprint (Sum (Pure False) (Pure True))

    it "is deterministic: fingerprinting the same expression twice agrees" $
      property $ \ml mr ->
        let e = Sum (maybe Empty Pure (ml :: Maybe Int)) (maybe Empty Pure (mr :: Maybe Bool))
         in fingerprint e === fingerprint e
