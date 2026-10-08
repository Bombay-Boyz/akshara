module CLI.CommandSpec (spec) where

import CLI.Command (Command (..), parseCommand)
import Data.Either (isLeft)
import Test.Hspec

spec :: Spec
spec = do
  describe "parseCommand (Section 113)" $ do
    it "parses each known subcommand" $ do
      parseCommand ["validate"] `shouldBe` Right Validate
      parseCommand ["analyze"] `shouldBe` Right Analyze
      parseCommand ["plan"] `shouldBe` Right Plan
      parseCommand ["run", "hash"] `shouldBe` Right RunHash
      parseCommand ["run", "file", "/tmp/x"] `shouldBe` Right (RunFile "/tmp/x")
    it "rejects missing, bare, unknown, or malformed arguments" $ do
      parseCommand [] `shouldSatisfy` isLeft
      parseCommand ["run"] `shouldSatisfy` isLeft
      parseCommand ["resume"] `shouldSatisfy` isLeft
      parseCommand ["validate", "x"] `shouldSatisfy` isLeft
      parseCommand ["run", "file"] `shouldSatisfy` isLeft
