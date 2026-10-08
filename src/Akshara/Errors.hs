-- | Section 2.15: the closed error vocabulary, in its own module,
-- separate from the domain/planning logic that raises it.
module Akshara.Errors
  ( DomainError (..)
  , PartitionError (..)
  ) where

-- | Raised by 'Akshara.Domain' 's smart constructors.
data DomainError
  = -- | A requested length was negative.
    NegativeLength Int
  | -- | A requested range's low bound exceeded its high bound.
    EmptyRange Int Int
  deriving (Eq, Show)

-- | Raised by 'Akshara.Partition' 's smart constructor: a requested
-- partition count was zero or negative.
newtype PartitionError = NonPositivePartitionCount Int
  deriving (Eq, Show)
