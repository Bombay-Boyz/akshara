module Akshara.PredicateSpec (spec) where

import Akshara.Predicate (Predicate (..), evalP)
import Test.Hspec
import Test.QuickCheck

-- | Explicit generator, not an 'Arbitrary' instance — an orphan
-- instance here would violate 1.7. Structurally decreasing, so it
-- terminates for any size QuickCheck supplies (§2.4's bound
-- discipline, applied to test data as a matter of habit).
genP :: Int -> Gen (Predicate Int)
genP n
  | n <= 1    = elements [TrueP, FalseP]
  | otherwise = oneof
      [ elements [TrueP, FalseP]
      , And <$> genP (n `div` 2) <*> genP (n `div` 2)
      , Or  <$> genP (n `div` 2) <*> genP (n `div` 2)
      , Not <$> genP (n - 1)
      ]

spec :: Spec
spec = do
  let gen = sized genP :: Gen (Predicate Int)

  describe "Boolean algebra (§14)" $ do
    it "And/TrueP is left identity" $
      forAll gen $ \p x -> evalP (And TrueP p) x === evalP p x
    it "Or/FalseP is left identity" $
      forAll gen $ \p x -> evalP (Or FalseP p) x === evalP p x
    it "And/FalseP annihilates" $
      forAll gen $ \p x -> evalP (And FalseP p) x === False
    it "Or/TrueP annihilates" $
      forAll gen $ \p x -> evalP (Or TrueP p) x === True
    it "double negation" $
      forAll gen $ \p x -> evalP (Not (Not p)) x === evalP p x
    it "De Morgan (And)" $
      forAll gen $ \p -> forAll gen $ \q x ->
        evalP (Not (And p q)) x === evalP (Or (Not p) (Not q)) x
    it "De Morgan (Or)" $
      forAll gen $ \p -> forAll gen $ \q x ->
        evalP (Not (Or p q)) x === evalP (And (Not p) (Not q)) x
    it "And is associative" $
      forAll gen $ \p -> forAll gen $ \q -> forAll gen $ \r x ->
        evalP (And (And p q) r) x === evalP (And p (And q r)) x
