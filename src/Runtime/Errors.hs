-- | Section 2.15: closed error vocabulary for 'Runtime.Checkpoint'.
module Runtime.Errors
  ( CheckpointError (..)
  ) where

-- | Everything that can go wrong constructing or validating a
-- checkpoint.
data CheckpointError
  = -- | A 'SpecificationIdentity' or 'PlanIdentity' token was empty.
    EmptyIdentity String
  | -- | A checkpoint's specification token didn't match what was expected.
    SpecificationIdentityMismatch String String
  | -- | A checkpoint's plan token didn't match what was expected.
    PlanIdentityMismatch String String
  | -- | A checkpoint's partition count didn't match what was expected.
    PartitionCountMismatch Int Int
  deriving (Eq, Show)
