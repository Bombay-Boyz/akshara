{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

module Runtime.EdgeCasesSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Order (fromOrd)
import Akshara.Partition (mkPartitionCount)
import Akshara.Predicate (Predicate (..))
import Akshara.Result (AksharaResult (..))
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRight)
import Akshara.Transform (Transform (UnifyT))
import Data.Either (isLeft)
import Runtime.Checkpoint
import Runtime.Parallel (parallelFindAny, parallelFindCanonical)
import System.Timeout (timeout)
import Test.Hspec

boolAlphabet :: AksharaExpr Bool
boolAlphabet = MapT UnifyT (Sum (Pure False) (Pure True))

boolCube :: Int -> AksharaExpr [Bool]
boolCube n = either (const Empty) (`replicateE` boolAlphabet) (mkLength n)

spec :: Spec
spec = do
  describe "parallel solvers on an Empty domain" $ do
    it "parallelFindAny exhausts regardless of worker count" $
      withRight (mkPartitionCount 4) $ \pc -> do
        result <- parallelFindAny pc TrueP (Empty :: AksharaExpr Int)
        result `shouldBe` Exhausted

    it "parallelFindCanonical exhausts regardless of worker count" $
      withRight (mkPartitionCount 4) $ \pc -> do
        result <- parallelFindCanonical pc fromOrd TrueP (Empty :: AksharaExpr Int)
        result `shouldBe` Exhausted

  describe "parallelFindAny under real load (Section 53)" $ do
    it "TrueP completes well within budget" $
      withRight (mkPartitionCount 8) $ \pc -> do
        result <- timeout 2000000 (parallelFindAny pc TrueP (boolCube 18))
        case result of
          Just (FoundAny _) -> pure ()
          _ -> expectationFailure "did not find within 2s"

    it "FalseP completes correctly on the same large domain (no hang)" $
      withRight (mkPartitionCount 8) $ \pc -> do
        result <- timeout 20000000 (parallelFindAny pc FalseP (boolCube 18))
        result `shouldBe` Just Exhausted

  -- | Section 5.9: this is the FIX of a previously-documented known
  -- limitation ("checkpoint identity is token-based, not
  -- content-based"). SpecificationIdentity is now derived from the
  -- AksharaExpr itself, so validateCheckpoint genuinely detects a
  -- resume against a different domain -- this test now demonstrates
  -- detection, where the equivalent test once demonstrated the
  -- opposite.
  describe "checkpoint identity is content-based (Section 56/57, fixed)" $
    it "validateCheckpoint rejects resuming against a genuinely different domain" $
      withRight (mkPartitionCount 2) $ \pc ->
        withRight (mkPlanIdentity "plan-x") $ \planId -> do
          let domainA    = boolCube 3
              domainB    = boolCube 4
              specIdForA = specificationIdentityOf domainA
              cp         = Checkpoint specIdForA planId (emptyFrontier pc)
          validateCheckpoint specIdForA planId pc cp `shouldBe` Right ()
          validateCheckpoint (specificationIdentityOf domainB) planId pc cp
            `shouldSatisfy` isLeft
