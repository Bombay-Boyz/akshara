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
-- encrypted, stored (uncompressed), filename "f", compressed size
-- 12 (just the encryption header, no extra body). The CRC-32 and
-- header bytes are arbitrary -- this tests the PARSER only, not
-- cipher correctness, which needs a real artifact (see
-- Verify.Formats.ZipPkzip.Cipher's module Haddock).
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

spec :: Spec
spec =
  describe "mkZipTargetFromBytes (Section 5.9: real encrypted-document parsing)" $ do
    it "accepts a well-formed encrypted, stored local file header" $
      mkZipTargetFromBytes validHeaderBytes `shouldSatisfy` isRight'

    it "rejects data shorter than a minimal header" $
      mkZipTargetFromBytes (BS.take 20 validHeaderBytes) `shouldBe` Left NotAZipFile

    it "rejects a wrong signature" $
      mkZipTargetFromBytes (withByteAt 0 0xFF validHeaderBytes) `shouldBe` Left NotAZipFile

    it "rejects an entry that isn't encrypted" $
      mkZipTargetFromBytes (withByteAt 6 0x00 validHeaderBytes) `shouldBe` Left ZipEntryNotEncrypted

    it "rejects streaming mode (general purpose bit 3)" $
      mkZipTargetFromBytes (withByteAt 6 0x09 validHeaderBytes) `shouldBe` Left UnsupportedStreamingMode

    it "rejects strong/AES encryption (general purpose bit 6)" $
      mkZipTargetFromBytes (withByteAt 6 0x41 validHeaderBytes) `shouldBe` Left UnsupportedEncryptionMethod

    it "rejects an unsupported compression method" $
      mkZipTargetFromBytes (withByteAt 8 0x0C validHeaderBytes)
        `shouldBe` Left (UnsupportedCompressionMethod 12)

    it "rejects a file truncated before its declared compressed data ends" $
      mkZipTargetFromBytes (BS.take 35 validHeaderBytes) `shouldSatisfy` isLeft
  where
    isRight' = either (const False) (const True)
