{- | Sections 30-33: the search engine's verifier boundary. 'VerifierHandle'
is Section 0.5's Handle pattern applied here -- the engine depends
on this shape, never on a concrete adapter module (Section 33:
"should know Candidate, Verifier, Verification," nothing more).

m is left polymorphic (Section 3.9) rather than fixed to IO, so a
pure in-memory test double can stand in for a real adapter without
rewriting anything that consumes a 'VerifierHandle'.
-}
module Verify.Class (
  Verification (..),
  VerifierHandle (..),
) where

{- | Section 30: a verifier's outcome is not a Bool. 'Failed' names a
structured, adapter-specific breakdown -- never silently folded
into 'Rejected' (Section 178's "a verifier timeout is not candidate
rejected").
-}
data Verification e
  = Rejected
  | Accepted
  | Failed e
  deriving (Eq, Show)

newtype VerifierHandle e m a = VerifierHandle
  { runVerifier :: a -> m (Verification e)
  }
