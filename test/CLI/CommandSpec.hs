module CLI.CommandSpec (spec) where

import CLI.Command (Command (..), parseCommand)
import Data.Either (isLeft)
import Test.Hspec

spec :: Spec
spec = do
  describe "parseCommand (Section 113)" $ do
    it "parses each known subcommand" $ do
      parseCommand ["validate"] `shouldBe` Right Validate
      parseCommand ["analyze"]  `shouldBe` Right Analyze
      parseCommand ["plan"]     `shouldBe` Right Plan
      parseCommand ["run"]      `shouldBe` Right Run
    it "rejects missing, unknown, or extra arguments" $ do
      parseCommand []                    `shouldSatisfy` isLeft
      parseCommand ["resume"]             `shouldSatisfy` isLeft
      parseCommand ["validate", "extra"]  `shouldSatisfy` isLeft
