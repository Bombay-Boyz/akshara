-- | The traditional PKZIP stream cipher (APPNOTE.TXT section on
-- "Traditional PKWARE Encryption") and the CRC-32 (IEEE 802.3)
-- primitive it's built on. Section 4.2: a named, published
-- algorithm, implemented and cited, not reinvented as a heuristic.
--
-- Deliberately separate from ZIP file-format parsing (this module
-- knows nothing about local file headers, compression methods, or
-- files at all) -- Section 0.1: this module's one job is "the
-- cipher," not "the file format."
--
-- /Pending validation (Section 5.9, stated not assumed)/: CRC-32 is
-- checked below against the universally-published standard check
-- value. The cipher itself is NOT yet confirmed against a real
-- PKZIP-encrypted file -- that requires an actual artifact (a zip
-- created with a real tool), not a remembered test vector, and is
-- the next concrete step once the file-parsing layer exists to read
-- one.
module Verify.Formats.ZipPkzip.Cipher
  ( crc32
  , crc32Update
  , Keys
  , keysFromPassword
  , decryptByte
  , decryptStream
  ) where

import Data.Array.Unboxed (UArray, listArray, (!))
import Data.Bits (shiftR, xor, (.&.), (.|.))
import qualified Data.ByteString as BS
import Data.Word (Word32, Word8)

-- | The standard CRC-32 (IEEE 802.3) table: for each possible byte
-- value, the table entry obtained by XOR-ing the byte in, then
-- shifting right 8 times, XOR-ing in the polynomial 0xEDB88320
-- whenever the shifted-out bit was 1. Built once; this is the
-- standard byte-wise (Sarwate) table-construction algorithm, not a
-- novel derivation.
crc32Table :: UArray Word8 Word32
crc32Table = listArray (0, 255) [step8 (fromIntegral n) 8 | n <- [0 .. 255 :: Int]]
  where
    step8 :: Word32 -> Int -> Word32
    step8 c 0 = c
    step8 c k
      | c .&. 1 == 1 = step8 ((c `shiftR` 1) `xor` 0xEDB88320) (k - 1)
      | otherwise    = step8 (c `shiftR` 1) (k - 1)

-- | One byte's worth of CRC-32 update, in the RAW (uncomplemented)
-- form the PKZIP cipher's own key schedule uses directly -- the
-- complement step below in 'crc32' is a separate, outer wrapping for
-- whole-buffer checksums, not part of this primitive.
crc32Update :: Word32 -> Word8 -> Word32
crc32Update crc byte =
  (crc `shiftR` 8) `xor` (crc32Table ! fromIntegral ((crc `xor` fromIntegral byte) .&. 0xFF))

-- | The standard CRC-32 of a whole buffer: start complemented, fold
-- 'crc32Update' over every byte, complement the result. Checked
-- against the universally-published CRC-32 check value in
-- Verify.Formats.ZipPkzip.CipherSpec.
crc32 :: BS.ByteString -> Word32
crc32 = (`xor` 0xFFFFFFFF) . BS.foldl' crc32Update 0xFFFFFFFF

-- | The cipher's three 32-bit state words. Opaque: the only way to
-- obtain one is 'keysFromPassword'.
data Keys = Keys !Word32 !Word32 !Word32

-- | The cipher's fixed initial state (APPNOTE.TXT).
initialKeys :: Keys
initialKeys = Keys 0x12345678 0x23456789 0x34567890

-- | The key-schedule's per-byte update step. Word32's own wraparound
-- arithmetic gives the required mod-2^32 behaviour; every value here
-- is explicitly typed Word32 so GHC's numeric defaulting can never
-- silently substitute Integer (which would not wrap) for one of them.
updateKeys :: Keys -> Word8 -> Keys
updateKeys (Keys k0 k1 k2) byte =
  let k0' = crc32Update k0 byte
      k1' = (k1 + (k0' .&. 0xFF)) * 134775813 + 1 :: Word32
      k2' = crc32Update k2 (fromIntegral (k1' `shiftR` 24))
   in Keys k0' k1' k2'

-- | Initialise the cipher's state from a password, by feeding every
-- byte through the key schedule in order.
keysFromPassword :: BS.ByteString -> Keys
keysFromPassword = BS.foldl' updateKeys initialKeys

-- | Decrypt one byte, returning the plaintext byte and the keys'
-- next state (the state must always be threaded forward -- the key
-- schedule is updated using the DECRYPTED byte, not the ciphertext).
decryptByte :: Keys -> Word8 -> (Word8, Keys)
decryptByte keys@(Keys _ _ k2) c =
  let temp      = (k2 .|. 2) .&. 0xFFFF :: Word32
      magicByte = fromIntegral ((temp * (temp `xor` 1)) `shiftR` 8) :: Word8
      plain     = c `xor` magicByte
   in (plain, updateKeys keys plain)

-- | Decrypt a whole byte string, threading the key state through
-- every byte (Section 4.1: mapAccumL is the named combinator for
-- "map while threading accumulator state"). Returns the plaintext
-- and the FINAL key state, since a caller decrypting a 12-byte
-- header followed by the file body must continue the SAME state,
-- never restart it.
decryptStream :: Keys -> BS.ByteString -> (BS.ByteString, Keys)
decryptStream keys0 bytes =
  let (finalKeys, plain) = BS.mapAccumL step keys0 bytes
   in (plain, finalKeys)
  where
    step k c = let (p, k') = decryptByte k c in (k', p)
