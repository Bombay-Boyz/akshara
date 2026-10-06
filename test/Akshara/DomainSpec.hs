module Akshara.DomainSpec (spec) where

import Akshara.Domain
import Akshara.Enumeration (enumerate)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRight)
import Akshara.Transform (Transform (UnifyT))
import Control.Monad (forM_)
import Data.Either (isLeft)
import Test.Hspec

withLength :: Int -> (Length -> Expectation) -> Expectation
withLength n = withRight (mkLength n)

withRange :: Length -> Length -> (Range -> Expectation) -> Expectation
withRange lo hi = withRight (mkRange lo hi)

alphabet :: AksharaExpr Char
alphabet = MapT UnifyT (Sum ab (Pure 'c'))
  where ab = MapT UnifyT (Sum (Pure 'a') (Pure 'b'))

spec :: Spec
spec = do
  describe "smart constructors (Section 64)" $ do
    it "rejects a negative length" $
      mkLength (-1) `shouldSatisfy` isLeft
    it "rejects an empty (lo > hi) range" $
      withLength 3 $ \lo3 -> withLength 1 $ \hi1 ->
        mkRange lo3 hi1 `shouldSatisfy` isLeft

  describe "replicateE : |Sigma^n| = |Sigma|^n (Section 27)" $
    it "holds for n in [0..4]" $
      forM_ [0 .. 4] $ \n ->
        withLength n $ \len ->
          length (enumerate (replicateE len alphabet)) `shouldBe` 3 ^ n

  describe "sequenceRange : |Union Sigma^k| = sum of |Sigma|^k" $
    it "holds for m..n = 1..3" $
      withLength 1 $ \lo -> withLength 3 $ \hi -> withRange lo hi $ \rng ->
        length (enumerate (sequenceRange rng alphabet)) `shouldBe` (3 + 9 + 27)
