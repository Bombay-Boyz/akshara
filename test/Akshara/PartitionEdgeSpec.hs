module Akshara.PartitionEdgeSpec (spec) where

import Akshara.Enumeration (enumerate)
import Akshara.Partition (mkPartitionCount, partition, reconstruct)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRight)
import qualified Data.List.NonEmpty as NE
import Test.Hspec

spec :: Spec
spec = do
  describe "partition count far exceeding cardinality" $
    it "still covers and reconstructs with mostly-empty regions" $
      withRight (mkPartitionCount 100) $ \pc -> do
        let dom = Sum (Pure (1 :: Int)) (Sum (Pure (2 :: Int)) (Pure (3 :: Int)))
        NE.length (partition pc dom) `shouldBe` 100
        reconstruct (partition pc dom) `shouldBe` enumerate dom

  describe "partitioning an Empty domain (cardinality 0)" $
    it "produces all-empty regions and reconstructs to []" $
      withRight (mkPartitionCount 5) $ \pc -> do
        let dom = Empty :: AksharaExpr Int
        reconstruct (partition pc dom) `shouldBe` enumerate dom
        reconstruct (partition pc dom) `shouldBe` ([] :: [Int])

  describe "partition count of exactly 1 (k=1 boundary)" $
    it "is the whole domain, unsplit" $
      withRight (mkPartitionCount 1) $ \pc -> do
        let dom = Sum (Pure (1 :: Int)) (Pure (2 :: Int))
        NE.head (partition pc dom) `shouldBe` enumerate dom
