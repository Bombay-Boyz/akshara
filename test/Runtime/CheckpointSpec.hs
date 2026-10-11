{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

module Runtime.CheckpointSpec (spec) where

import Akshara.Domain (mkLength, replicateE)
import Akshara.Order (Order, fromOrd)
import Akshara.Partition (mkPartitionCount)
import Akshara.Predicate (Predicate (..))
import Akshara.Result (AksharaResult (..))
import Akshara.Solver (findCanonical)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.TestSupport (withRightSpec)
import Akshara.Transform (Transform (UnifyT))
import Data.Either (isLeft)
import Runtime.Checkpoint
import Test.Hspec

boolAlphabet :: AksharaExpr Bool
boolAlphabet = MapT UnifyT (Sum (Pure False) (Pure True))

boolCube :: Int -> AksharaExpr [Bool]
boolCube n = either (const Empty) (`replicateE` boolAlphabet) (mkLength n)

lexOrder :: Order [Bool]
lexOrder = fromOrd

spec :: Spec
spec = do
  describe "specificationIdentityOf (Section 5.9: content-derived, not a caller token)" $ do
    it "two structurally-identical domains get equal identities" $
      specificationIdentityOf (boolCube 3) `shouldBe` specificationIdentityOf (boolCube 3)
    it "two structurally-different domains get different identities" $
      specificationIdentityOf (boolCube 3) `shouldNotBe` specificationIdentityOf (boolCube 4)

  describe "identity smart constructors (Section 64)" $
    it "rejects an empty PlanIdentity" $
      mkPlanIdentity "" `shouldSatisfy` isLeft

  describe "validateCheckpoint (Section 56/57/118: no silent resume against a mismatch)" $
    withRightSpec (mkPlanIdentity "plan-a") $ \planA ->
      withRightSpec (mkPlanIdentity "plan-b") $ \planB ->
        withRightSpec (mkPartitionCount 2) $ \pc2 ->
          withRightSpec (mkPartitionCount 3) $ \pc3 ->
            let specA = specificationIdentityOf (boolCube 3)
                specB = specificationIdentityOf (boolCube 4)
                cp :: Checkpoint Bool
                cp = Checkpoint specA planA (emptyFrontier pc2)
             in do
                  it "accepts matching identities and partition count" $
                    validateCheckpoint specA planA pc2 cp `shouldBe` Right ()
                  it "rejects a specification identity mismatch" $
                    validateCheckpoint specB planA pc2 cp `shouldSatisfy` isLeft
                  it "rejects a plan identity mismatch" $
                    validateCheckpoint specA planB pc2 cp `shouldSatisfy` isLeft
                  it "rejects a partition count mismatch" $
                    validateCheckpoint specA planA pc3 cp `shouldSatisfy` isLeft

  -- | Known limitation (Section 5.9): this tests idempotent resume of
  -- an already-fully-completed frontier, not a genuine mid-flight
  -- interrupt-and-persist-to-disk cycle (Section 81's fuller test).
  describe "resumeParallelFindCanonical (Section 53/55)" $
    withRightSpec (mkPartitionCount 4) $ \pc ->
      withRightSpec (mkPlanIdentity "canonical-v1") $ \planId ->
        let dom     = boolCube 3
            specId  = specificationIdentityOf dom
            freshCp = Checkpoint specId planId (emptyFrontier pc)
         in do
              it "a fresh (never-started) resume agrees with the sequential solver" $ do
                (result, _) <- resumeParallelFindCanonical lexOrder TrueP dom freshCp
                case (result, findCanonical lexOrder TrueP dom) of
                  (FoundCanonical x _, FoundCanonical y _) -> x `shouldBe` y
                  (Exhausted, Exhausted) -> pure ()
                  _ -> expectationFailure "resumed and sequential solvers disagree"

              it "resuming an already-completed frontier is idempotent" $ do
                (_, doneFrontier) <- resumeParallelFindCanonical lexOrder TrueP dom freshCp
                let doneCp = Checkpoint specId planId doneFrontier
                (result1, frontier1) <- resumeParallelFindCanonical lexOrder TrueP dom doneCp
                (result2, frontier2) <- resumeParallelFindCanonical lexOrder TrueP dom doneCp
                case (result1, result2) of
                  (FoundCanonical x _, FoundCanonical y _) -> x `shouldBe` y
                  (Exhausted, Exhausted) -> pure ()
                  _ -> expectationFailure "repeated resumes of a completed frontier disagree"
                frontier1 `shouldBe` frontier2
