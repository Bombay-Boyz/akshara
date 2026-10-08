module Verify.EdgeCasesSpec (spec) where

import Akshara.TestSupport (withRight)
import Crypto.Hash (Digest, SHA256, hash)
import Data.ByteArray qualified as BA
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as BSC
import System.IO (hClose)
import System.IO.Temp (withSystemTempDirectory, withSystemTempFile)
import Test.Hspec
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Formats.FileContent (fileContentVerifierHandle, mkReferencePath)
import Verify.Formats.SaltedSha256 (mkTargetHash, saltedHashVerifierHandle)

digestBytesOf :: BS.ByteString -> BS.ByteString -> BS.ByteString
digestBytesOf s candidate = BA.convert (hash (s <> candidate) :: Digest SHA256)

spec :: Spec
spec = do
  describe "SaltedSha256 boundaries" $ do
    it "accepts an empty candidate against its own target hash" $
      withRight (mkTargetHash (BSC.pack "salt") (digestBytesOf (BSC.pack "salt") BS.empty)) $ \target -> do
        result <- runVerifier (saltedHashVerifierHandle target) BS.empty
        result `shouldBe` Accepted

    it "works with an empty salt" $
      withRight (mkTargetHash BS.empty (digestBytesOf BS.empty (BSC.pack "x"))) $ \target -> do
        result <- runVerifier (saltedHashVerifierHandle target) (BSC.pack "x")
        result `shouldBe` Accepted

    it "the salt actually participates: same candidate, different salt, rejects" $
      withRight (mkTargetHash (BSC.pack "salt-B") (digestBytesOf (BSC.pack "salt-A") (BSC.pack "pw"))) $ \wrongTarget -> do
        result <- runVerifier (saltedHashVerifierHandle wrongTarget) (BSC.pack "pw")
        result `shouldBe` Rejected

    it "handles a large (1 MB) candidate without error" $ do
      let bigCandidate = BS.replicate (1024 * 1024) 0x41
      withRight (mkTargetHash (BSC.pack "s") (digestBytesOf (BSC.pack "s") bigCandidate)) $ \target -> do
        result <- runVerifier (saltedHashVerifierHandle target) bigCandidate
        result `shouldBe` Accepted

  describe "FileContent adversarial and boundary paths" $ do
    it "accepts an empty candidate against an empty file" $
      withSystemTempFile "akshara-empty" $ \path h -> do
        hClose h
        withRight (mkReferencePath path) $ \ref -> do
          result <- runVerifier (fileContentVerifierHandle ref) BS.empty
          result `shouldBe` Accepted

    it "fails (not rejects) when the path is a directory" $
      withSystemTempDirectory "akshara-dir" $ \dirPath ->
        withRight (mkReferencePath dirPath) $ \ref -> do
          result <- runVerifier (fileContentVerifierHandle ref) (BSC.pack "x")
          case result of
            Failed _ -> pure ()
            other -> expectationFailure ("expected Failed, got " <> show other)
