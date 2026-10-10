-- | Section 2.15: closed error vocabularies for the verifier
-- boundary -- one type per adapter (Section 33: "the adapter owns
-- the application-specific interpretation"), not one type shared
-- across adapters. 'Verification e'/'VerifierHandle e m a' are
-- already parameterised over e for exactly this reason (Section 0.2:
-- adapters are genuinely open to third parties).
--
-- /Corrected design (Section 5.9)/: an earlier version shared one
-- 'VerificationFailure' type across both adapters. That forced
-- FileContent's I/O failures and empty-path rejection through a
-- constructor named 'MalformedTargetHash' -- a hash-specific name --
-- which is exactly the stringly-typed catch-all Section 1.5 bans,
-- just smuggled through one constructor's string argument instead
-- of bare Text.
module Verify.Errors
  ( SaltedSha256Error (..)
  , FileContentError (..)
  ) where

-- | Everything that can go wrong constructing a
-- 'Verify.Formats.SaltedSha256.TargetHash'.
newtype SaltedSha256Error
  = -- | The supplied hash is not a valid 32-byte SHA-256 digest.
    InvalidTargetHash String
  deriving (Eq, Show)

-- | Everything that can go wrong with a
-- 'Verify.Formats.FileContent.ReferencePath'.
data FileContentError
  = -- | An empty path was supplied.
    EmptyReferencePath
  | -- | The reference file could not be read (missing, a directory,
    -- permissions, ...). Carries the underlying 'IOException''s
    -- rendered message.
    ReferenceFileUnreadable String
  deriving (Eq, Show)
