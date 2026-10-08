module Akshara.IndexedSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Enumeration (enumerate)
import Akshara.Indexed (indexed)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (UnifyT))
import Control.Monad (forM_)
import Test.Hspec
import Test.QuickCheck

alphabet3 :: AksharaExpr Char
alphabet3 = MapT UnifyT (Sum ab (Pure 'c'))
  where
    ab = MapT UnifyT (Sum (Pure 'a') (Pure 'b'))

cubeOfSize :: Int -> AksharaExpr [Char]
cubeOfSize n = either (const Empty) (`replicateE` alphabet3) (mkLength n)

spec :: Spec
spec = do
  describe "indexed agrees with enumerate at every valid index (oracle check)" $
    it "holds for cube sizes 0..4" $
      forM_ [0 .. 4] $ \n -> do
        let xs = enumerate (cubeOfSize n)
        forM_ (zip [0 ..] xs) $ \(i, x) ->
          indexed (cubeOfSize n) i `shouldBe` Just x

  describe "out-of-range behaviour" $
    it "is Nothing at and beyond the cardinality, for any size in 0..6" $
      forAll (choose (0, 6)) $ \n ->
        let dom = cubeOfSize n
            card = length (enumerate dom)
         in indexed dom card === Nothing
