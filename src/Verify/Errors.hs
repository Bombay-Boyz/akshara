-- | Section 2.15: closed error vocabularies for the verifier
-- boundary -- one type per adapter (Section 33).
module Verify.Errors
  ( SaltedSha256Error (..)
  , FileContentError (..)
  , ZipPkzipError (..)
  ) where

newtype SaltedSha256Error
  = InvalidTargetHash String
  deriving (Eq, Show)

data FileContentError
  = EmptyReferencePath
  | ReferenceFileUnreadable String
  deriving (Eq, Show)

-- | Everything that can go wrong parsing or handling a
-- 'Verify.Formats.ZipPkzip.ZipTarget'.
data ZipPkzipError
  = -- | The file could not be read from disk.
    ZipFileUnreadable String
  | -- | Missing signature, or too short to be a valid local file header.
    NotAZipFile
  | -- | The entry's general-purpose bit 0 (encrypted) is not set.
    ZipEntryNotEncrypted
  | -- | General-purpose bit 6 (strong/AES encryption) is set -- a
    -- different cipher and header layout, not traditional PKZIP.
    UnsupportedEncryptionMethod
  | -- | General-purpose bit 3 (streaming / data-descriptor mode) is
    -- set -- not yet supported.
    UnsupportedStreamingMode
  | -- | A compression method other than stored (0) or deflated (8).
    UnsupportedCompressionMethod Int
  deriving (Eq, Show)
