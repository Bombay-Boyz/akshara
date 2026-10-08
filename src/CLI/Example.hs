-- | Stage 13's one fixed, built-in specification.
module CLI.Example
  ( exampleDomain
  , exampleTargetHash
  ) where

import Akshara.Domain (mkLength, mkRange, sequenceRange)
import Akshara.Errors (DomainError)
import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (UnifyT))
import qualified Data.ByteArray as BA
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Crypto.Hash (Digest, SHA256, hash)
import Verify.Errors (VerificationFailure)
import Verify.Formats.SaltedSha256 (TargetHash, mkTargetHash)

exampleAlphabet :: AksharaExpr Char
exampleAlphabet = MapT UnifyT (Sum ab (Pure 'c'))
  where ab = MapT UnifyT (Sum (Pure 'a') (Pure 'b'))

-- | Alphabet {a,b,c}, length 1..3.
exampleDomain :: Either DomainError (AksharaExpr [Char])
exampleDomain = do
  lo  <- mkLength 1
  hi  <- mkLength 3
  rng <- mkRange lo hi
  pure (sequenceRange rng exampleAlphabet)

exampleSalt :: BS.ByteString
exampleSalt = BSC.pack "akshara-demo-salt"

-- | The salted hash of "bc", a member of 'exampleDomain'. Demo-only,
-- not a real secret.
exampleTargetHash :: Either VerificationFailure TargetHash
exampleTargetHash = mkTargetHash exampleSalt digestBytes
  where
    digestBytes = BA.convert (hash (exampleSalt <> BSC.pack "bc") :: Digest SHA256)
