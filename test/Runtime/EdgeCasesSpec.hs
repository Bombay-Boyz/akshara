{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

module Runtime.EdgeCasesSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Order (mkOrder)
import Akshara.Partition (mkPartitionCount)
import Akshara.Predicate (Predicate (..))
import Akshara.Result (AksharaResult (..))
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRight)
import Akshara.Transform (Transform (UnifyT))
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
        result <- parallelFindCanonical pc (mkOrder compare) TrueP (Empty :: AksharaExpr Int)
        result `shouldBe` Exhausted

  -- \| Section 53's cancellation contract under real load, not an
  -- injected delay -- Predicate is content-blind (Stage 3's recorded
  -- limitation), so no per-candidate sleep is expressible. A large
  -- real domain is the stress instead.
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

  -- \| Documented limitation made executable: SpecificationIdentity/
  -- PlanIdentity are caller tokens, never derived from the
  -- AksharaExpr. Resuming against a genuinely different domain with
  -- matching tokens is NOT detected -- this characterises that known
  -- gap so a future change cannot silently alter it unnoticed.
  describe "checkpoint identity is token-based, not content-based (known limitation)" $
    it "resuming against a different domain with matching tokens goes undetected" $
      withRight (mkPartitionCount 2) $ \pc ->
        withRight (mkSpecificationIdentity "spec-x") $ \specId ->
          withRight (mkPlanIdentity "plan-x") $ \planId -> do
            let domainB = boolCube 4
                cp = Checkpoint specId planId (emptyFrontier pc)
            validateCheckpoint specId planId pc cp `shouldBe` Right ()
            (result, _) <- resumeParallelFindCanonical (mkOrder compare) TrueP domainB cp
            case result of
              FoundCanonical _ _ -> pure ()
              Exhausted -> expectationFailure "expected a result on a nonempty domain"
