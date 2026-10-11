-- | Section 2.15: closed error vocabulary for 'Runtime.Checkpoint'.
module Runtime.Errors
  ( CheckpointError (..)
  ) where

data CheckpointError
  = -- | A PlanIdentity token was empty. (SpecificationIdentity no
    -- longer has this failure mode -- see Runtime.Checkpoint's
    -- module Haddock.)
    EmptyPlanIdentity
  | -- | A checkpoint's specification identity didn't match what was expected.
    SpecificationIdentityMismatch String String
  | -- | A checkpoint's plan token didn't match what was expected.
    PlanIdentityMismatch String String
  | -- | A checkpoint's partition count didn't match what was expected.
    PartitionCountMismatch Int Int
  deriving (Eq, Show)
