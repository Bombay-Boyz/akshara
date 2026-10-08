{- | Section 2.15: closed error vocabulary for Runtime.Checkpoint,
kept in its own module separate from the logic that raises it.
-}
module Runtime.Errors (
  CheckpointError (..),
) where

data CheckpointError
  = EmptyIdentity String
  | SpecificationIdentityMismatch String String
  | PlanIdentityMismatch String String
  | PartitionCountMismatch Int Int
  deriving (Eq, Show)
