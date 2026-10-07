-- | Stage 14 (Section 110): a second adapter, same Verify.Class
-- boundary. Unlike SaltedSha256, this one can genuinely reach Failed
-- (missing/unreadable file) -- Section 178's distinction finally has
-- a real adapter exercising it, not just a mock in a test.
module Verify.Formats.FileContent
  ( ReferencePath
  , mkReferencePath
  , fileContentVerifierHandle
  ) where

import Control.Exception (IOException, try)
import qualified Data.ByteString as BS
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Errors (VerificationFailure (..))

newtype ReferencePath = ReferencePath FilePath deriving (Eq, Show)

mkReferencePath :: FilePath -> Either VerificationFailure ReferencePath
mkReferencePath p
  | null p    = Left (MalformedTargetHash "reference path must not be empty")
  | otherwise = Right (ReferencePath p)

-- | Accepted iff candidate bytes equal the file's bytes exactly.
-- A read failure (missing file, permissions) is Failed, never
-- silently Rejected (Section 178).
fileContentVerifierHandle :: ReferencePath -> VerifierHandle VerificationFailure IO BS.ByteString
fileContentVerifierHandle (ReferencePath path) = VerifierHandle $ \candidate -> do
  result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
  pure $ case result of
    Left err      -> Failed (MalformedTargetHash (show err))
    Right content -> if content == candidate then Accepted else Rejected
