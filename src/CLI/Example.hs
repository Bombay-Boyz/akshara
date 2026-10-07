-- | Stage 13's one fixed, built-in specification -- Section 49's
-- human-readable DSL is explicitly future work ("should emerge from
-- the kernel rather than designed independently"); no parser exists,
-- so this stage's "specification" is a Haskell value, not a parsed
-- file.
--
-- Alphabet {a,b,c}, length 1..3 (Section 1's demonstration domain:
-- authorized recovery of user-owned data). Deliberately tiny -- this
-- proves the pipeline is wired correctly, not that enumeration scales
-- (Stage 15's job, gated on profiling).
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

exampleDomain :: Either DomainError (AksharaExpr [Char])
exampleDomain = do
  lo  <- mkLength 1
  hi  <- mkLength 3
  rng <- mkRange lo hi
  pure (sequenceRange rng exampleAlphabet)

exampleSalt :: BS.ByteString
exampleSalt = BSC.pack "akshara-demo-salt"

-- | /Demo-only target, not a real secret, labelled as such precisely/
-- /because Section 58 cares about this distinction for anything that/
-- /is one/: the salted hash of "bc", a small member of
-- 'exampleDomain'.
exampleTargetHash :: Either VerificationFailure TargetHash
exampleTargetHash = mkTargetHash exampleSalt digestBytes
  where
    digestBytes = BA.convert (hash (exampleSalt <> BSC.pack "bc") :: Digest SHA256)
