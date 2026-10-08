module Akshara.EnumerationSpec (spec) where

import Akshara.Enumeration (enumerate)
import Akshara.Semantics (denote)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (..))
import Test.Hspec
import Test.QuickCheck

{- | §78: checked by exact list equality, never up to a set/sort —
§78 itself warns that converting to a set first erases order and
multiplicity bugs, which is the whole point of testing this at all.
-}
spec :: Spec
spec = do
  describe "enumerate agrees with denote (§21 soundness, §22 completeness)" $ do
    it "on Empty" $
      enumerate (Empty :: AksharaExpr Int) `shouldBe` denote Empty
    it "on Pure" $
      enumerate (Pure (5 :: Int)) `shouldBe` denote (Pure 5)
    it "on Sum" $
      let e = Sum (Pure (1 :: Int)) (Pure True) in enumerate e `shouldBe` denote e
    it "on Product" $
      let e = Product (Pure (1 :: Int)) (Pure True) in enumerate e `shouldBe` denote e
    it "on MapT" $
      let e = MapT SumComm (Sum (Pure (1 :: Int)) (Pure True))
       in enumerate e `shouldBe` denote e

    it "for arbitrary finite Sum/MapT terms" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
            e = MapT SumComm (Sum l r)
         in enumerate e === denote e

  describe "determinism (§20's contract)" $
    it "repeated enumeration of the same term is identical" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
            e = Product l r
         in enumerate e === enumerate e
