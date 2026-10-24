module Runtime.EngineSpec (spec) where

import Akshara.Partition (mkPartitionCount)
import Akshara.Result (AksharaResult (..))
import Akshara.TestSupport (withRight)
import CLI.Example (exampleDomain, exampleTargetHash)
import qualified Data.ByteString.Char8 as BSC
import Control.Monad (forM_)
import Runtime.Engine (verifiedFindAny, verifiedParallelFindAny)
import Test.Hspec
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Formats.SaltedSha256 (saltedHashVerifierHandle)

spec :: Spec
spec = do
  describe "verifiedFindAny (sequential, Sections 30, 33, 91)" $ do
    it "finds the example domain's known accepted candidate" $
      withRight exampleDomain $ \domain ->
        withRight exampleTargetHash $ \target -> do
          result <- verifiedFindAny (saltedHashVerifierHandle target) BSC.pack domain
          result `shouldBe` Right (FoundAny "bc")

    it "exhausts when nothing is accepted" $
      withRight exampleDomain $ \domain -> do
        let neverAccepts = VerifierHandle (const (pure Rejected)) :: VerifierHandle () IO [Char]
        result <- verifiedFindAny neverAccepts id domain
        result `shouldBe` Right Exhausted

    it "propagates a verifier Failed outcome rather than silently rejecting" $
      withRight exampleDomain $ \domain -> do
        let alwaysFails =
              VerifierHandle (const (pure (Failed "boom"))) :: VerifierHandle String IO [Char]
        result <- verifiedFindAny alwaysFails id domain
        result `shouldBe` Left "boom"

  describe "verifiedParallelFindAny (Section 5.9 / ADR 0001)" $ do
    it "finds the same candidate as the sequential engine, at every worker count" $
      withRight exampleDomain $ \domain ->
        withRight exampleTargetHash $ \target ->
          forM_ [1 .. 8 :: Int] $ \k ->
            withRight (mkPartitionCount k) $ \pc -> do
              result <- verifiedParallelFindAny pc (saltedHashVerifierHandle target) BSC.pack domain
              result `shouldBe` Right (FoundAny "bc")

    it "exhausts when nothing is accepted, at every worker count" $
      withRight exampleDomain $ \domain ->
        forM_ [1 .. 8 :: Int] $ \k ->
          withRight (mkPartitionCount k) $ \pc -> do
            let neverAccepts = VerifierHandle (const (pure Rejected)) :: VerifierHandle () IO [Char]
            result <- verifiedParallelFindAny pc neverAccepts id domain
            result `shouldBe` Right Exhausted

    it "propagates a verifier Failed outcome, at every worker count" $
      withRight exampleDomain $ \domain ->
        forM_ [1 .. 8 :: Int] $ \k ->
          withRight (mkPartitionCount k) $ \pc -> do
            let alwaysFails =
                  VerifierHandle (const (pure (Failed "boom"))) :: VerifierHandle String IO [Char]
            result <- verifiedParallelFindAny pc alwaysFails id domain
            result `shouldBe` Left "boom"
