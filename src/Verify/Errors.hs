-- | Section 2.15: closed error vocabulary for the verifier boundary,
-- in its own module separate from the adapter logic that raises it.
module Verify.Errors
  ( VerificationFailure (..)
  ) where

newtype VerificationFailure = MalformedTargetHash String
  deriving (Eq, Show)
