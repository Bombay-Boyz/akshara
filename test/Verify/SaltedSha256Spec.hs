module Verify.SaltedSha256Spec (spec) where

import Akshara.TestSupport (withRight)
import Crypto.Hash (Digest, SHA256, hash)
import Data.ByteArray qualified as BA
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as BSC
import Data.Either (isLeft)
import Test.Hspec
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Formats.SaltedSha256 (mkTargetHash, saltedHashVerifierHandle)

salt :: BS.ByteString
salt = BSC.pack "test-salt"

digestBytesOf :: BS.ByteString -> BS.ByteString -> BS.ByteString
digestBytesOf s candidate = BA.convert (hash (s <> candidate) :: Digest SHA256)

correct, wrong :: BS.ByteString
correct = BSC.pack "correct-password"
wrong = BSC.pack "wrong-password"

spec :: Spec
spec = do
  describe "mkTargetHash (Sections 64, 3.3)" $ do
    it "accepts a genuine 32-byte SHA-256 digest" $
      withRight (mkTargetHash salt (digestBytesOf salt correct)) $
        \_ -> pure ()
    it "rejects a malformed (wrong-length) hash (Section 137's malformed-input test)" $
      mkTargetHash salt (BSC.pack "too-short") `shouldSatisfy` isLeft

  describe "saltedHashVerifierHandle (Sections 30-32, 137)" $ do
    it "accepts the exact candidate the target was built for (soundness, Section 31)" $
      withRight (mkTargetHash salt (digestBytesOf salt correct)) $ \target -> do
        result <- runVerifier (saltedHashVerifierHandle target) correct
        result `shouldBe` Accepted

    it "rejects a different candidate (negative test)" $
      withRight (mkTargetHash salt (digestBytesOf salt correct)) $ \target -> do
        result <- runVerifier (saltedHashVerifierHandle target) wrong
        result `shouldBe` Rejected

    it "is deterministic across repeated calls" $
      withRight (mkTargetHash salt (digestBytesOf salt correct)) $ \target -> do
        r1 <- runVerifier (saltedHashVerifierHandle target) correct
        r2 <- runVerifier (saltedHashVerifierHandle target) correct
        r1 `shouldBe` r2
