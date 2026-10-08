-- | Section 2.15: closed error vocabulary for the verifier boundary.
module Verify.Errors
  ( VerificationFailure (..)
  ) where

-- | A structured, adapter-specific verification failure (Section 30).
newtype VerificationFailure = MalformedTargetHash String
  deriving (Eq, Show)
