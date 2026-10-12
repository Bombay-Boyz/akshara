module Akshara.SizedSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Enumeration (enumerate)
import Akshara.Indexed (indexed)
import Akshara.Sized (indexedSized, sized, sizedCardinality)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (UnifyT))
import Control.Monad (forM_)
import Test.Hspec
import Test.QuickCheck hiding (sized)

alphabet3 :: AksharaExpr Char
alphabet3 = MapT UnifyT (Sum ab (Pure 'c'))
  where
    ab = MapT UnifyT (Sum (Pure 'a') (Pure 'b'))

cubeOfSize :: Int -> AksharaExpr [Char]
cubeOfSize n = either (const Empty) (`replicateE` alphabet3) (mkLength n)

spec :: Spec
spec = do
  describe "sizedCardinality agrees with the domain's actual cardinality" $
    it "holds for cube sizes 0..4" $
      forM_ [0 .. 4] $ \n ->
        sizedCardinality (sized (cubeOfSize n)) `shouldBe` length (enumerate (cubeOfSize n))

  describe "indexedSized agrees with enumerate at every valid index (oracle check)" $
    it "holds for cube sizes 0..4" $
      forM_ [0 .. 4] $ \n -> do
        let xs   = enumerate (cubeOfSize n)
            tree = sized (cubeOfSize n)
        forM_ (zip [0 ..] xs) $ \(i, x) ->
          indexedSized tree i `shouldBe` Just x

  -- | Memoization must change performance, never the result. Checked
  -- directly against the unmemoized reference, not just against
  -- enumerate -- a bug specific to the memoization itself (e.g. a
  -- caching error) could in principle agree with enumerate's ORDER
  -- while still disagreeing with indexed on some index if both had
  -- the SAME independent bug, however unlikely; this closes that gap.
  describe "indexedSized agrees with the unmemoized indexed at every valid index" $
    it "holds for cube sizes 0..4" $
      forM_ [0 .. 4] $ \n -> do
        let dom  = cubeOfSize n
            tree = sized dom
            card = sizedCardinality tree
        forM_ [0 .. card] $ \i ->
          indexedSized tree i `shouldBe` indexed dom i

  describe "out-of-range behaviour" $
    it "is Nothing at and beyond the cardinality, for any size in 0..6" $
      forAll (choose (0, 6)) $ \n ->
        let tree = sized (cubeOfSize n)
         in indexedSized tree (sizedCardinality tree) === Nothing
