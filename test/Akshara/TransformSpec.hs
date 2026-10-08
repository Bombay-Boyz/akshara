module Akshara.TransformSpec (spec) where

import Akshara.Semantics (denote)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (..))
import Data.Void (Void)
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = do
  describe "functor laws (§77)" $ do
    it "map id ≡ A" $
      property $ \ml mr ->
        let e =
              Sum
                (maybe Empty Pure (ml :: Maybe Int))
                (maybe Empty Pure (mr :: Maybe Bool))
         in denote (MapT Identity e) === denote e

    it "map (Compose f g) ≡ map g . map f  (fusion, §96)" $
      property $ \ml mr ->
        let e =
              Sum
                (maybe Empty Pure (ml :: Maybe Int))
                (maybe Empty Pure (mr :: Maybe Bool))
         in denote (MapT (Compose SumComm SumComm) e)
              === denote (MapT SumComm (MapT SumComm e))

  describe "Sum isomorphisms" $ do
    it "commutativity swaps Left/Right" $
      denote (MapT SumComm (Sum (Pure (1 :: Int)) (Pure True)))
        `shouldBe` [Right 1, Left True]

    it "associativity re-nests (A+B)+C to A+(B+C)" $
      denote (MapT SumAssoc (Sum (Sum (Pure (1 :: Int)) (Pure True)) (Pure 'x')))
        `shouldBe` [Left 1, Right (Left True), Right (Right 'x')]

    it "0+A ≅ A (left unit elimination)" $
      denote (MapT SumUnitElimL (Sum (Empty :: AksharaExpr Void) (Pure (7 :: Int))))
        `shouldBe` [7]

    it "A+0 ≅ A (right unit elimination)" $
      denote (MapT SumUnitElimR (Sum (Pure (7 :: Int)) (Empty :: AksharaExpr Void)))
        `shouldBe` [7]

  describe "Product isomorphism"
    $ it "associativity re-nests (A×B)×C to A×(B×C)"
    $ denote
      ( MapT
          ProductAssoc
          (Product (Product (Pure (1 :: Int)) (Pure True)) (Pure 'x'))
      )
      `shouldBe` [(1, (True, 'x'))]
