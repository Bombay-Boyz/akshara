-- | Stage 14 (Section 110): a second adapter, same 'Verify.Class'
-- boundary -- exercises 'Failed' genuinely (missing/unreadable file).
module Verify.Formats.FileContent
  ( ReferencePath
  , mkReferencePath
  , fileContentVerifierHandle
  ) where

import Control.Exception (IOException, try)
import qualified Data.ByteString as BS
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Errors (VerificationFailure (..))

-- | Opaque: non-emptiness enforced once, at construction.
newtype ReferencePath = ReferencePath FilePath deriving (Eq, Show)

-- | Rejects an empty path.
mkReferencePath :: FilePath -> Either VerificationFailure ReferencePath
mkReferencePath p
  | null p    = Left (MalformedTargetHash "reference path must not be empty")
  | otherwise = Right (ReferencePath p)

-- | Accepted iff candidate bytes equal the file's bytes exactly. A
-- read failure is 'Failed', never silently 'Rejected'.
fileContentVerifierHandle :: ReferencePath -> VerifierHandle VerificationFailure IO BS.ByteString
fileContentVerifierHandle (ReferencePath path) = VerifierHandle $ \candidate -> do
  result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
  pure $ case result of
    Left err      -> Failed (MalformedTargetHash (show err))
    Right content -> if content == candidate then Accepted else Rejected
