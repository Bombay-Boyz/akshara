{- | Stage 12 (Sections 107, 138): the first real verifier adapter.
Section 138's selection criteria are "clear verification semantics,
stable library support, reasonable testability, predictable
candidate representation" -- not maximum cryptographic hardness --
so a salted-hash comparison against a stable, long-unchanged
Crypto.Hash API was chosen over PBKDF2/Argon2's less-settled one.

/Stated limitation, not hidden (Section 5.9)/: this is a single
unsalted-iteration hash comparison, not a key-derivation function.
A KDF-backed adapter is a reasonable Stage 14 addition, added
alongside this one, not in place of it.

/Stated limitation (Section 58)/: the candidate lives as an
ordinary ByteString for the duration of 'runVerifier' -- not a
scrubbed/zeroed buffer. Deferred until a stage that persists
recovered secrets rather than comparing one in a single call.
-}
module Verify.Formats.SaltedSha256 (
  TargetHash,
  mkTargetHash,
  saltedHashVerifierHandle,
) where

import Crypto.Hash (Digest, SHA256, digestFromByteString, hash)
import Data.ByteArray qualified as BA
import Data.ByteString qualified as BS
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Errors (VerificationFailure (..))

{- | Opaque (Section 3.3). 'Show' is safe to derive: this carries only
the salt and the target digest, never a candidate -- the same
thing it's always safe to log about a stored password hash.
-}
data TargetHash = TargetHash
  { targetSalt :: BS.ByteString
  , targetDigest :: Digest SHA256
  }
  deriving (Show)

mkTargetHash :: BS.ByteString -> BS.ByteString -> Either VerificationFailure TargetHash
mkTargetHash salt rawHash =
  case digestFromByteString rawHash of
    Nothing -> Left (MalformedTargetHash "hash is not a valid 32-byte SHA-256 digest")
    Just d -> Right (TargetHash salt d)

{- | Section 31 soundness: Accepted only when the candidate's salted
digest equals the target exactly. 'BA.constEq' rather than the
Digest Eq instance -- extends Section 58's security posture to the
comparison itself, avoiding a timing side-channel.
-}
saltedHashVerifierHandle :: TargetHash -> VerifierHandle VerificationFailure IO BS.ByteString
saltedHashVerifierHandle target = VerifierHandle $ \candidate ->
  let computed = hash (targetSalt target <> candidate) :: Digest SHA256
   in pure $
        if BA.constEq computed (targetDigest target) then Accepted else Rejected
