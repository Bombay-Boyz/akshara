module Akshara.PartitionSpec (spec) where

import Akshara.Enumeration (enumerate)
import Akshara.Partition (PartitionCount, mkPartitionCount, partition, reconstruct)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRight)
import Akshara.Transform (Transform (UnifyT))
import Data.Either (isLeft)
import qualified Data.List.NonEmpty as NE
import Test.Hspec
import Test.QuickCheck

withPartitionCount :: Int -> (PartitionCount -> Expectation) -> Expectation
withPartitionCount n = withRight (mkPartitionCount n)

boolE :: AksharaExpr Bool
boolE = MapT UnifyT (Sum (Pure False) (Pure True))

-- | A small finite domain of known cardinality 8 (2 x 2 x 2).
cube :: AksharaExpr (Bool, (Bool, Bool))
cube = Product boolE (Product boolE boolE)

spec :: Spec
spec = do
  describe "mkPartitionCount (Section 64)" $ do
    it "rejects zero" $ mkPartitionCount 0 `shouldSatisfy` isLeft
    it "rejects a negative count" $ mkPartitionCount (-2) `shouldSatisfy` isLeft

  describe "partition (Section 39)" $ do
    it "requested count matches NonEmpty length" $
      withPartitionCount 3 $ \pc ->
        NE.length (partition pc cube) `shouldBe` 3

    it "coverage: region lengths sum to the domain's cardinality" $
      withPartitionCount 3 $ \pc ->
        sum (map length (NE.toList (partition pc cube)))
          `shouldBe` length (enumerate cube)

    it "reconstruction equals the original enumeration (Section 39; since \
       \regions are contiguous non-overlapping slices by construction, \
       \this equality also witnesses disjointness)" $
      withPartitionCount 3 $ \pc ->
        reconstruct (partition pc cube) `shouldBe` enumerate cube

    it "is deterministic: two calls on the same inputs agree" $
      withPartitionCount 3 $ \pc ->
        partition pc cube `shouldBe` partition pc cube

    it "reconstruction holds for any valid partition count" $
      forAll (choose (1, 9)) $ \n ->
        either
          (const (property False))
          (\pc -> reconstruct (partition pc cube) === enumerate cube)
          (mkPartitionCount n)
