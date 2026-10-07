module Verify.FileContentSpec (spec) where

import Akshara.TestSupport (withRight)
import qualified Data.ByteString.Char8 as BSC
import System.IO (hClose)
import System.IO.Temp (withSystemTempFile)
import Test.Hspec
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Formats.FileContent (fileContentVerifierHandle, mkReferencePath)

spec :: Spec
spec = do
  describe "fileContentVerifierHandle" $ do
    it "accepts a candidate matching the file exactly" $
      withSystemTempFile "akshara-ref" $ \path h -> do
        BSC.hPutStr h (BSC.pack "secret")
        hClose h
        withRight (mkReferencePath path) $ \ref -> do
          result <- runVerifier (fileContentVerifierHandle ref) (BSC.pack "secret")
          result `shouldBe` Accepted

    it "rejects a non-matching candidate" $
      withSystemTempFile "akshara-ref" $ \path h -> do
        BSC.hPutStr h (BSC.pack "secret")
        hClose h
        withRight (mkReferencePath path) $ \ref -> do
          result <- runVerifier (fileContentVerifierHandle ref) (BSC.pack "nope")
          result `shouldBe` Rejected

    it "fails (not rejects) on a missing file" $
      withRight (mkReferencePath "/nonexistent/akshara-ref-missing") $ \ref -> do
        result <- runVerifier (fileContentVerifierHandle ref) (BSC.pack "x")
        case result of
          Failed _ -> pure ()
          other    -> expectationFailure ("expected Failed, got " <> show other)
