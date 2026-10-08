-- | Stage 12 (Sections 107, 138): the first real verifier adapter --
-- a salted-hash comparison chosen over PBKDF2/Argon2 for a
-- stable, long-unchanged Crypto.Hash API.
module Verify.Formats.SaltedSha256
  ( TargetHash
  , mkTargetHash
  , saltedHashVerifierHandle
  ) where

import Crypto.Hash (Digest, SHA256, digestFromByteString, hash)
import qualified Data.ByteArray as BA
import qualified Data.ByteString as BS
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Errors (VerificationFailure (..))

-- | Opaque: 'Show' is safe to derive -- this carries only the salt
-- and the target digest, never a candidate.
data TargetHash = TargetHash
  { targetSalt   :: BS.ByteString
  , targetDigest :: Digest SHA256
  }
  deriving Show

-- | Validates the hash is a genuine 32-byte SHA-256 digest.
mkTargetHash :: BS.ByteString -> BS.ByteString -> Either VerificationFailure TargetHash
mkTargetHash salt rawHash =
  case digestFromByteString rawHash of
    Nothing -> Left (MalformedTargetHash "hash is not a valid 32-byte SHA-256 digest")
    Just d  -> Right (TargetHash salt d)

-- | Section 31 soundness: Accepted only when the candidate's salted
-- digest equals the target exactly, compared via constant-time
-- 'BA.constEq' to avoid a timing side-channel.
saltedHashVerifierHandle :: TargetHash -> VerifierHandle VerificationFailure IO BS.ByteString
saltedHashVerifierHandle target = VerifierHandle $ \candidate ->
  let computed = hash (targetSalt target <> candidate) :: Digest SHA256
   in pure $
        if BA.constEq computed (targetDigest target) then Accepted else Rejected
