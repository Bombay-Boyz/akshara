module Akshara.SemanticsSpec (spec) where

import Akshara.Semantics (denote)
import Akshara.Syntax (AksharaExpr (..))
import Test.Hspec
import Test.QuickCheck

{- | §18's four equations on concrete closed terms, plus the
cardinality laws (§27) specialised to |D| ∈ {0,1} via Maybe.
-}
spec :: Spec
spec = do
  describe "denote (§18)" $ do
    it "Empty |-> empty set" $
      denote (Empty :: AksharaExpr Int) `shouldBe` []
    it "Pure x |-> {x}" $
      denote (Pure (5 :: Int)) `shouldBe` [5]
    it "Sum splits Left/Right" $
      denote (Sum (Pure (1 :: Int)) (Pure True))
        `shouldBe` [Left 1, Right True]
    it "Product is the cross product" $
      denote (Product (Pure (1 :: Int)) (Pure True))
        `shouldBe` [(1, True)]

  describe "cardinality" $ do
    it "Sum is additive" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
         in length (denote (Sum l r)) === length (denote l) + length (denote r)

    it "Product is multiplicative" $
      property $ \ml mr ->
        let l = maybe Empty Pure (ml :: Maybe Int)
            r = maybe Empty Pure (mr :: Maybe Bool)
         in length (denote (Product l r)) === length (denote l) * length (denote r)
