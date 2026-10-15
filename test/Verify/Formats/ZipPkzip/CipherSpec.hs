module Verify.Formats.ZipPkzip.CipherSpec (spec) where

import qualified Data.ByteString.Char8 as BSC
import Numeric (showHex)
import Test.Hspec
import Verify.Formats.ZipPkzip.Cipher (crc32)

spec :: Spec
spec =
  -- | The universally-published CRC-32 (IEEE 802.3) check value: the
  -- CRC-32 of the nine ASCII bytes "123456789" is 0xCBF43926. Every
  -- correct implementation of this exact algorithm produces this
  -- exact value; this is THE standard self-test cited in essentially
  -- every CRC-32 reference and implementation, not a value specific
  -- to this project.
  describe "crc32 (Section 5.7: known-prior-art check value)" $
    it "matches the standard CRC-32 check value for \"123456789\"" $
      let got = crc32 (BSC.pack "123456789")
       in showHex got "" `shouldBe` "cbf43926"
