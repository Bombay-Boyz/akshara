module Verify.Formats.ZipPkzipSpec (spec) where

import qualified Data.ByteString as BS
import Data.Either (isLeft)
import Data.Word (Word8)
import Test.Hspec
import Verify.Errors (ZipPkzipError (..))
import Verify.Formats.ZipPkzip (mkZipTargetFromBytes)

withByteAt :: Int -> Word8 -> BS.ByteString -> BS.ByteString
withByteAt i b bs = BS.concat [BS.take i bs, BS.singleton b, BS.drop (i + 1) bs]

-- | A hand-constructed, valid local file header (APPNOTE.TXT 4.3.7):
-- encrypted, stored, filename "f", compressed size 12. Tests the
-- PARSER only, not cipher correctness.
validHeaderBytes :: BS.ByteString
validHeaderBytes =
  BS.pack $
    [0x50, 0x4b, 0x03, 0x04]
      ++ [0x14, 0x00]
      ++ [0x01, 0x00]
      ++ [0x00, 0x00]
      ++ [0x00, 0x00]
      ++ [0x21, 0x08]
      ++ [0xDD, 0xCC, 0xBB, 0xAA]
      ++ [0x0C, 0x00, 0x00, 0x00]
      ++ [0x00, 0x00, 0x00, 0x00]
      ++ [0x01, 0x00]
      ++ [0x00, 0x00]
      ++ [0x66]
      ++ replicate 12 0x00

-- | Zeroes the compressed-size field (offset 18-21) -- the genuinely
-- ambiguous case: bit 3 set AND no size given at all, meaning the
-- real size is deferred to a trailing data descriptor this adapter
-- does not read.
withZeroCompressedSize :: BS.ByteString -> BS.ByteString
withZeroCompressedSize = withByteAt 18 0x00 . withByteAt 19 0x00 . withByteAt 20 0x00 . withByteAt 21 0x00

spec :: Spec
spec = do
  describe "mkZipTargetFromBytes (Section 5.9: real encrypted-document parsing)" $ do
    it "accepts a well-formed encrypted, stored local file header" $
      mkZipTargetFromBytes validHeaderBytes `shouldSatisfy` isRight'

    it "rejects data shorter than a minimal header" $
      mkZipTargetFromBytes (BS.take 20 validHeaderBytes) `shouldBe` Left NotAZipFile

    it "rejects a wrong signature" $
      mkZipTargetFromBytes (withByteAt 0 0xFF validHeaderBytes) `shouldBe` Left NotAZipFile

    it "rejects an entry that isn't encrypted" $
      mkZipTargetFromBytes (withByteAt 6 0x00 validHeaderBytes) `shouldBe` Left ZipEntryNotEncrypted

    it "rejects strong/AES encryption (general purpose bit 6)" $
      mkZipTargetFromBytes (withByteAt 6 0x41 validHeaderBytes) `shouldBe` Left UnsupportedEncryptionMethod

    it "rejects an unsupported compression method" $
      mkZipTargetFromBytes (withByteAt 8 0x0C validHeaderBytes)
        `shouldBe` Left (UnsupportedCompressionMethod 12)

    it "rejects a file truncated before its declared compressed data ends" $
      mkZipTargetFromBytes (BS.take 35 validHeaderBytes) `shouldSatisfy` isLeft

    -- | The genuinely unsupported case: bit 3 set AND size truly
    -- deferred (zero in the local header).
    it "rejects streaming mode when the size is truly deferred (zero)" $
      mkZipTargetFromBytes (withZeroCompressedSize (withByteAt 6 0x09 validHeaderBytes))
        `shouldBe` Left UnsupportedStreamingMode

    -- | The real-world case this session found: bit 3 set, but the
    -- local header already has real, non-zero values (some zip
    -- writers do this when output is seekable). This should now be
    -- accepted, not rejected.
    it "accepts streaming mode when the local header already has real values" $
      mkZipTargetFromBytes (withByteAt 6 0x09 validHeaderBytes) `shouldSatisfy` isRight'
  where
    isRight' = either (const False) (const True)
