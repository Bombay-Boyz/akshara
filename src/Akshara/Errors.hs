{- | Section 2.15: the closed error vocabulary, in its own module,
separate from the domain/planning logic that raises it.
-}
module Akshara.Errors (
  DomainError (..),
  PartitionError (..),
) where

data DomainError
  = NegativeLength Int
  | EmptyRange Int Int
  deriving (Eq, Show)

newtype PartitionError = NonPositivePartitionCount Int
  deriving (Eq, Show)
