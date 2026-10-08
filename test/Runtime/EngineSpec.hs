module Runtime.EngineSpec (spec) where

import Akshara.Result (AksharaResult (..))
import Akshara.TestSupport (withRight)
import CLI.Example (exampleDomain, exampleTargetHash)
import Data.ByteString.Char8 qualified as BSC
import Runtime.Engine (verifiedFindAny)
import Test.Hspec
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Formats.SaltedSha256 (saltedHashVerifierHandle)

spec :: Spec
spec = do
  describe "verifiedFindAny (Sections 30, 33, 91)" $ do
    it "finds the example domain's known accepted candidate" $
      withRight exampleDomain $ \domain ->
        withRight exampleTargetHash $ \target -> do
          result <- verifiedFindAny (saltedHashVerifierHandle target) BSC.pack domain
          result `shouldBe` Right (FoundAny "bc")

    it "exhausts when nothing is accepted (an always-reject test double, Section 0.5)" $
      withRight exampleDomain $ \domain -> do
        let neverAccepts = VerifierHandle (const (pure Rejected)) :: VerifierHandle () IO [Char]
        result <- verifiedFindAny neverAccepts id domain
        result `shouldBe` Right Exhausted

    it "propagates a verifier Failed outcome rather than silently rejecting (Section 178)" $
      withRight exampleDomain $ \domain -> do
        let alwaysFails =
              VerifierHandle (const (pure (Failed "boom"))) :: VerifierHandle String IO [Char]
        result <- verifiedFindAny alwaysFails id domain
        result `shouldBe` Left "boom"
