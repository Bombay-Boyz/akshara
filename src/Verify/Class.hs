-- | Sections 30-33: the search engine's verifier boundary.
module Verify.Class
  ( Verification (..)
  , VerifierHandle (..)
  ) where

-- | Section 30: a verifier's outcome is not a Bool.
data Verification e
  = -- | The candidate was rejected.
    Rejected
  | -- | The candidate was accepted.
    Accepted
  | -- | Verification itself failed, for a structured, named reason.
    Failed e
  deriving (Eq, Show)

-- | Section 0.5's Handle pattern: the engine depends on this shape,
-- never on a concrete adapter module.
newtype VerifierHandle e m a = VerifierHandle
  { runVerifier :: a -> m (Verification e)
    -- ^ Verify one candidate.
  }
