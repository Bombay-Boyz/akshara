-- | The real encrypted-document verifier: password-protected ZIP
-- files using the traditional PKZIP cipher
-- (Verify.Formats.ZipPkzip.Cipher) against a real ZIP local file
-- header.
--
-- /Scope, stated explicitly (Section 5.9)/: only the first local
-- file header is read (the common "one encrypted file in the
-- archive" case) -- the central directory is not parsed. Three
-- features are explicitly rejected rather than silently
-- mishandled: streaming mode (general purpose bit 3 -- CRC/sizes in
-- a trailing data descriptor instead of the header), strong/AES
-- encryption (bit 6 -- a different cipher and header layout
-- entirely), and any compression method other than stored or
-- deflated.
--
-- /Two-stage verification, for speed without false positives/: most
-- wrong candidates are rejected after decrypting only the 12-byte
-- encryption header and checking it against the entry's own CRC-32
-- high byte (the classic PKZIP quick-check -- roughly a 1/256
-- false-accept rate on its own, which is why it is only the FIRST
-- stage). Any candidate passing the quick check additionally
-- decrypts (and, if deflated, decompresses) the full entry and
-- confirms its CRC-32 exactly -- zero false positives on Accepted.
module Verify.Formats.ZipPkzip
  ( ZipTarget
  , mkZipTargetFromBytes
  , loadZipTarget
  , zipPkzipVerifierHandle
  ) where

import Codec.Compression.Zlib.Raw (DecompressError, decompress)
import Control.Exception (IOException, evaluate, try)
import Data.Bits (shiftL, shiftR, testBit, (.|.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import Data.Word (Word16, Word32, Word8)
import Verify.Class (Verification (..), VerifierHandle (..))
import Verify.Errors (ZipPkzipError (..))
import Verify.Formats.ZipPkzip.Cipher (Keys, crc32, decryptStream, keysFromPassword)

-- | Section 1.4: the compression methods this adapter supports, as
-- a closed type, not a raw Word16 compared against literals
-- repeatedly. Converted from the raw field exactly once, in
-- 'mkZipTargetFromBytes'; a case match over this is then provably
-- exhaustive, with no residual "impossible" branch.
data SupportedMethod = Stored | Deflated deriving (Eq, Show)

-- | Opaque: the only ways to obtain one are 'mkZipTargetFromBytes'
-- and 'loadZipTarget'.
data ZipTarget = ZipTarget
  { ztMethod           :: SupportedMethod
  , ztCrc32            :: Word32
  , ztEncryptionHeader :: BS.ByteString
  , ztCompressedData   :: BS.ByteString
  }
  deriving (Eq, Show)

-- | Little-endian field reads. Every call site below only reads
-- offsets a length check earlier in the SAME guard chain has
-- already established as in range -- Haskell's guards are tried in
-- order, each evaluated only once earlier ones are known false.
le16At :: BS.ByteString -> Int -> Word16
le16At bs off =
  fromIntegral (BS.index bs off) .|. (fromIntegral (BS.index bs (off + 1)) `shiftL` 8)

le32At :: BS.ByteString -> Int -> Word32
le32At bs off =
  fromIntegral (BS.index bs off)
    .|. (fromIntegral (BS.index bs (off + 1)) `shiftL` 8)
    .|. (fromIntegral (BS.index bs (off + 2)) `shiftL` 16)
    .|. (fromIntegral (BS.index bs (off + 3)) `shiftL` 24)

classifyMethod :: Word16 -> Either ZipPkzipError SupportedMethod
classifyMethod 0 = Right Stored
classifyMethod 8 = Right Deflated
classifyMethod m = Left (UnsupportedCompressionMethod (fromIntegral m))

-- | Parses the FIRST local file header (APPNOTE.TXT section 4.3.7)
-- out of a raw ZIP file's bytes.
mkZipTargetFromBytes :: BS.ByteString -> Either ZipPkzipError ZipTarget
mkZipTargetFromBytes raw
  | BS.length raw < 30      = Left NotAZipFile
  | signature /= 0x04034b50 = Left NotAZipFile
  | not encryptedBit        = Left ZipEntryNotEncrypted
  | strongEncryptionBit     = Left UnsupportedEncryptionMethod
  | streamedBit              = Left UnsupportedStreamingMode
  | compressedSize < 12      = Left NotAZipFile
  | BS.length raw < dataStart + fromIntegral compressedSize = Left NotAZipFile
  | otherwise =
      classifyMethod rawMethod >>= \method ->
        Right
          ZipTarget
            { ztMethod           = method
            , ztCrc32            = crc32Field
            , ztEncryptionHeader = BS.take 12 entryBytes
            , ztCompressedData   = BS.drop 12 entryBytes
            }
  where
    signature          = le32At raw 0
    gpFlag              = le16At raw 6
    rawMethod           = le16At raw 8
    crc32Field          = le32At raw 14
    compressedSize      = le32At raw 18
    fileNameLen         = le16At raw 26
    extraLen            = le16At raw 28
    encryptedBit        = testBit gpFlag 0
    streamedBit         = testBit gpFlag 3
    strongEncryptionBit = testBit gpFlag 6
    dataStart           = 30 + fromIntegral fileNameLen + fromIntegral extraLen
    entryBytes          = BS.take (fromIntegral compressedSize) (BS.drop dataStart raw)

-- | A read failure is ZipFileUnreadable, never silently treated as
-- "not a zip" (Section 178: distinct failure modes stay distinct).
loadZipTarget :: FilePath -> IO (Either ZipPkzipError ZipTarget)
loadZipTarget path = do
  result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
  pure $ case result of
    Left err    -> Left (ZipFileUnreadable (show err))
    Right bytes -> mkZipTargetFromBytes bytes

-- | Section 31 soundness: Accepted only after the FULL entry
-- decrypts (and, if deflated, decompresses) to data whose CRC-32
-- matches exactly -- the 12-byte quick check is a fast pre-filter,
-- not the final answer.
zipPkzipVerifierHandle :: ZipTarget -> VerifierHandle ZipPkzipError IO BS.ByteString
zipPkzipVerifierHandle target = VerifierHandle $ \password -> do
  let keys0                 = keysFromPassword password
      (decryptedHeader, keys1) = decryptStream keys0 (ztEncryptionHeader target)
      expectedCheckByte     = fromIntegral (ztCrc32 target `shiftR` 24) :: Word8
  case quickCheckByte decryptedHeader of
    -- Unreachable: the header is always exactly 12 bytes, by
    -- mkZipTargetFromBytes's own construction (compressedSize >= 12
    -- is checked there; BS.take 12 and decryptStream are both
    -- length-exact/length-preserving). Kept total rather than
    -- reached for error, matching Akshara.Partition's own
    -- unreachable-fallback precedent.
    Nothing -> pure Rejected
    Just b
      | b /= expectedCheckByte -> pure Rejected
      | otherwise              -> verifyFull keys1 target

-- | Total: avoids a partial index even though the header's length
-- is provably always 12 -- see the Nothing case above.
quickCheckByte :: BS.ByteString -> Maybe Word8
quickCheckByte bs
  | BS.length bs == 12 = Just (BS.index bs 11)
  | otherwise          = Nothing

verifyFull :: Keys -> ZipTarget -> IO (Verification ZipPkzipError)
verifyFull keys target = do
  let (decryptedBody, _) = decryptStream keys (ztCompressedData target)
  case ztMethod target of
    Stored -> pure (compareChecksum decryptedBody)
    Deflated -> do
      result <-
        try (evaluate (BSL.toStrict (decompress (BSL.fromStrict decryptedBody))))
          :: IO (Either DecompressError BS.ByteString)
      pure $ case result of
        -- A wrong candidate's decrypted bytes are essentially random
        -- and routinely fail to inflate as valid deflate data -- an
        -- ordinary Rejected outcome, not a system Failed one.
        Left _             -> Rejected
        Right decompressed -> compareChecksum decompressed
  where
    compareChecksum bytes
      | crc32 bytes == ztCrc32 target = Accepted
      | otherwise                     = Rejected
